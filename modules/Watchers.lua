local _, NS = ...
-- modules/Watchers.lua — the race's event wiring: the meter, combat, death and the player's casts,
-- turned into modules/Race.lua's inputs with `t` from GetTime(), and every cast of the player and the
-- pet handed to modules/Casts.lua (#14) as well. Registered only while a race needs them, and never
-- while the addon is stood down.
--
-- WHAT IS REGISTERED, BY RACE STATE (spec §10: nothing runs while idle):
--   idle, result      nothing
--   armed             the meter's three events, the regen edges and PLAYER_DEAD, plus the cast list's
--                     UNIT_SPELLCAST_SUCCEEDED for `player` and `pet` and _CHANNEL_START / _CHANNEL_STOP
--                     for `player` (a pre-pull cast is heard while armed: the probe, 2026-10-26)
--   running, stopping the same, plus UNIT_SPELLCAST_START / _EMPOWER_START / _INTERRUPTED for `player`
--                     (the late-cast judging's, spec §5.2)
-- Race calls Watchers.Sync() on every transition, so the set always follows the state. Every
-- registration goes through the SafeRegister family (events-frames-taint-§1), so an event name a
-- client does not know costs only itself and lands in NS.rejectedEvents.
--
-- TWO REGISTRANTS (events-frames-taint-§1). The non-unit events ride this module's own AceEvent
-- target (AceEvent keys a registration by event and target, so the addon object's own
-- PLAYER_REGEN_DISABLED handler is never clobbered). The casts ride the unit-filter frame, whose
-- only job is RegisterUnitEvent(..., "player"[, "pet"]) and the one OnEvent that dispatches it.
--
-- STAND-DOWN (slash-commands-§7). The lifecycle's stand-down calls Watchers.Suspend(), which drops
-- every registration; Sync answers "nothing" while stood down, and the stand-up's Resume rebuilds the
-- set from the race's CURRENT state, never from a snapshot.
--
-- Event arguments are handed to Race and Casts untouched: a value that may be secret (the meter type,
-- the session ID, a spell ID, a castGUID) is only ever converted by them through NS.Secrets.

local Watchers = {}
NS.Watchers = Watchers

local Perf = NS.Perf

-- The armed set, in registration order.
local RACE_EVENTS = {
    "DAMAGE_METER_CURRENT_SESSION_UPDATED",
    "DAMAGE_METER_COMBAT_SESSION_UPDATED",
    "DAMAGE_METER_RESET",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_DEAD",
}

-- The casts, each with the units it is registered for. The cast list's (#14) from ARMED on: every
-- success of the player and the pet, and the player's channel edges (its dedupe of channel ticks).
-- The late-cast judging's from RUNNING on (a start before the buzzer is what keeps its finish on time).
-- An interrupt or a channel's stop closes the cast in flight, so a later cast is judged on its own.
-- An empowered cast (an Evoker's hold-and-release) fires EMPOWER_START, not START, and its release
-- fires SUCCEEDED with the same castGUID: it is a cast in flight like any other, so one begun before
-- the buzzer is never late. Its EMPOWER_STOP is not listened to: the SUCCEEDED that follows the
-- release closes it, and a STOP heard first would make that SUCCEEDED look like a fresh instant.
local CAPTURE_EVENTS = {
    { "UNIT_SPELLCAST_SUCCEEDED", "player", "pet" },
    { "UNIT_SPELLCAST_CHANNEL_START", "player" },
    { "UNIT_SPELLCAST_CHANNEL_STOP", "player" },
}
local JUDGE_EVENTS = {
    { "UNIT_SPELLCAST_START", "player" },
    { "UNIT_SPELLCAST_EMPOWER_START", "player" },
    { "UNIT_SPELLCAST_INTERRUPTED", "player" },
}
local CAST_KIND = {
    UNIT_SPELLCAST_START         = "start",
    UNIT_SPELLCAST_CHANNEL_START = "channel",
    UNIT_SPELLCAST_EMPOWER_START = "start",
    UNIT_SPELLCAST_SUCCEEDED     = "succeeded",
    UNIT_SPELLCAST_INTERRUPTED   = "interrupted",
    UNIT_SPELLCAST_CHANNEL_STOP  = "channelStop",
}

local target       -- this module's AceEvent target: the non-unit events (nil until a race needs it)
local frame        -- the unit-filter frame: the casts (nil until a race is first armed)
-- The set registered now: "none" | "armed" | "running".
local registered = "none"

-- ── dispatch ────────────────────────────────────────────────────────────────────────────────────

local HANDLERS = {
    DAMAGE_METER_CURRENT_SESSION_UPDATED = function(t) NS.Race.OnSessionCreated(t) end,
    DAMAGE_METER_COMBAT_SESSION_UPDATED  = function(t, statType, sessionID)
        NS.Race.OnMeterUpdate(statType, sessionID, t)
    end,
    DAMAGE_METER_RESET    = function() NS.Race.OnMeterReset() end,
    PLAYER_REGEN_DISABLED = function(t) NS.Race.OnCombatStart(t) end,
    PLAYER_REGEN_ENABLED  = function(t) NS.Race.OnCombatEnd(t) end,
    PLAYER_DEAD           = function(t) NS.Race.OnDeath(t) end,
}

-- UNIT_SPELLCAST_*(unit, castGUID, spellID). Every cast goes to the cast list (which keeps the
-- player's and the pet's); only the player's reaches the late-cast judging. The check here keeps the
-- pet's (and a widened registration's party member's) from ever being judged.
local function onCast(event, t, unit, castGUID, spellID)
    local kind = CAST_KIND[event]
    NS.Casts.Hear(kind, unit, spellID, castGUID, t)
    if unit ~= "player" then return end
    NS.Race.OnCast(kind, spellID, t, castGUID)
end

local function onEvent(_, event, ...)
    local t0 = Perf.on and debugprofilestop()
    local t = GetTime()
    local handler = HANDLERS[event]
    if handler then
        handler(t, ...)
    elseif CAST_KIND[event] then
        onCast(event, t, ...)
    end
    if t0 then Perf.Note("raceEvent", debugprofilestop() - t0) end
end

-- ── registration ────────────────────────────────────────────────────────────────────────────────

-- AceEvent hands a function handler (event, ...); the frame's OnEvent hands (frame, event, ...).
local function onAceEvent(event, ...) onEvent(nil, event, ...) end

local function ensureTarget()
    if target then return target end
    target = LibStub("AceEvent-3.0"):Embed({})
    return target
end

local function ensureFrame()
    if frame then return frame end
    frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", onEvent)
    return frame
end

local function unregisterAll()
    if target then target:UnregisterAllEvents() end
    if frame then frame:UnregisterAllEvents() end
end

-- The set the race's state asks for.
local function wanted()
    if NS.IsStoodDown() then return "none" end
    local s, S = NS.Race.State(), NS.Race.STATE
    if s == S.RUNNING or s == S.STOPPING then return "running" end
    if s == S.ARMED then return "armed" end
    return "none"
end

local function registerCasts(f, list)
    for _, row in ipairs(list) do
        NS.SafeRegisterUnitEvent(f, row[1], NS.rejectedEvents, unpack(row, 2))
    end
end

local function register(set)
    local t = ensureTarget()
    for _, event in ipairs(RACE_EVENTS) do
        NS.SafeRegisterEvent(t, event, onAceEvent, NS.rejectedEvents)
    end
    local f = ensureFrame()
    registerCasts(f, CAPTURE_EVENTS)
    if set == "running" then registerCasts(f, JUDGE_EVENTS) end
end

--- Make the registrations match the race's state (and nothing while stood down). Cheap when they
--- already do.
function Watchers.Sync()
    local want = wanted()
    if want == registered then return end
    unregisterAll()
    registered = want
    if want ~= "none" then register(want) end
end

--- The lifecycle's stand-down: every registration goes.
function Watchers.Suspend()
    unregisterAll()
    registered = "none"
end

--- The lifecycle's stand-up: rebuilt from the race's current state.
function Watchers.Resume()
    registered = "none"
    Watchers.Sync()
end

--- The unit-filter frame (nil until a race was first armed), for the disabled-state suite.
function Watchers.Frame()
    return frame
end

--- The AceEvent target for the non-unit events (nil until a race first armed), for the suites.
function Watchers.EventTarget()
    return target
end
