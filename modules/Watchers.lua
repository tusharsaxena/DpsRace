local _, NS = ...
-- modules/Watchers.lua — the race's event wiring: the meter, combat, death and the player's casts,
-- turned into modules/Race.lua's inputs with `t` from GetTime(). Registered only while a race needs
-- them, and never while the addon is stood down.
--
-- WHAT IS REGISTERED, BY RACE STATE (spec §10: nothing runs while idle):
--   idle, result      nothing
--   armed             the meter's three events, the regen edges and PLAYER_DEAD
--   running, stopping the same, plus UNIT_SPELLCAST_START / _CHANNEL_START / _SUCCEEDED for `player`
-- Race calls Watchers.Sync() on every transition, so the set always follows the state. Every
-- registration goes through the SafeRegister family (events-frames-taint-§1), so an event name a
-- client does not know costs only itself and lands in NS.rejectedEvents.
--
-- STAND-DOWN (slash-commands-§7). The lifecycle's stand-down calls Watchers.Suspend(), which drops
-- every registration; Sync answers "nothing" while stood down, and the stand-up's Resume rebuilds the
-- set from the race's CURRENT state, never from a snapshot.
--
-- Event arguments are handed to Race untouched: a value that may be secret (the meter type, the
-- session ID, a spell ID) is only ever converted by Race through NS.Secrets.

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

-- The player's casts, from RUNNING on (a start before the buzzer is what keeps its finish on time).
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED" }
local CAST_KIND = {
    UNIT_SPELLCAST_START         = "start",
    UNIT_SPELLCAST_CHANNEL_START = "channel",
    UNIT_SPELLCAST_SUCCEEDED     = "succeeded",
}

local frame
-- The set registered now: "none" | "race" | "casts".
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

-- UNIT_SPELLCAST_*(unit, castGUID, spellID). The registration already filters to `player`; the
-- check here keeps a widened registration from scoring a party member's cast.
local function onCast(event, t, unit, _, spellID)
    if unit ~= "player" then return end
    NS.Race.OnCast(CAST_KIND[event], spellID, t)
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

local function ensureFrame()
    if frame then return frame end
    frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", onEvent)
    return frame
end

-- The set the race's state asks for.
local function wanted()
    if NS.IsStoodDown() then return "none" end
    local s, S = NS.Race.State(), NS.Race.STATE
    if s == S.RUNNING or s == S.STOPPING then return "casts" end
    if s == S.ARMED then return "race" end
    return "none"
end

local function register(set)
    local f = ensureFrame()
    for _, event in ipairs(RACE_EVENTS) do
        NS.SafeRegisterEvent(f, event, nil, NS.rejectedEvents)
    end
    if set ~= "casts" then return end
    for _, event in ipairs(CAST_EVENTS) do
        NS.SafeRegisterUnitEvent(f, event, NS.rejectedEvents, "player")
    end
end

--- Make the registrations match the race's state (and nothing while stood down). Cheap when they
--- already do.
function Watchers.Sync()
    local want = wanted()
    if want == registered then return end
    if frame then frame:UnregisterAllEvents() end
    registered = want
    if want ~= "none" then register(want) end
end

--- The lifecycle's stand-down: every registration goes.
function Watchers.Suspend()
    if frame then frame:UnregisterAllEvents() end
    registered = "none"
end

--- The lifecycle's stand-up: rebuilt from the race's current state.
function Watchers.Resume()
    registered = "none"
    Watchers.Sync()
end

--- The event frame (nil until a race first needed one), for the disabled-state suite and diagnostics.
function Watchers.Frame()
    return frame
end
