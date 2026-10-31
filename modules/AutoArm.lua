local _, NS = ...
-- modules/AutoArm.lua — the race near a training dummy (#16): Auto-show (`hud.autoShow`) opens the HUD
-- by itself while a cataloged dummy (defaults/Dummies.lua) is the target or has a nameplate up, and
-- Auto-arm (`race.autoArm`) arms a race by itself when the player targets one out of combat. Both are
-- off by default and independent of each other.
--
-- AUTO-SHOW. A DUMMY SESSION runs from the first cataloged dummy seen (the target, or a nameplate:
-- NAME_PLATE_UNIT_ADDED) until none has been seen for HIDE_DELAY seconds: the hide is a C_Timer
-- re-armed by nothing and canceled by the next dummy, so nameplates churning at the edge of their
-- range never flicker the window. At its fire the nameplates are scanned again (a plate that came up
-- in combat, its GUID secret, was not counted when it came). The window opens through
-- Hud.ShowNearDummy (only when nothing else wants it) and closes through Hud.HideAwayFromDummy, and only
-- while the race is idle: an armed or running race, or a result card, keeps it; the race's idle edge
-- asks again. THE MANUAL-CLOSE RULE: a close by the player in a session (Hud.Closes() moved since the
-- session began) keeps auto-show from opening the window again until that session ends. hud.showMode
-- is not changed by it: "always" already wants the window (auto-show then only reopens one the player
-- closed in an earlier session), and General visibility still decides whether it draws.
--
-- AUTO-ARM. PLAYER_TARGET_CHANGED to a cataloged dummy, out of combat, the race idle and no test mode
-- or sim on: Race.Arm at Hud.ArmLength() (what Arm Race would arm), through every refusal Race.Arm has
-- (pending, in combat, meter unavailable, stood down), silently: the HUD's idle body shows why. The
-- arm opens the HUD as a manual arm does. The way back out: while the run this rule armed is still
-- armed (not started), a target change out of combat to anything that is not a cataloged dummy, or
-- none, cancels it (in combat the pull is under way: the race holds ARMED until the clock starts). A
-- result card is never armed over (Race.Arm would: the race must be idle), and a race that started is
-- never disarmed.
--
-- STAND-DOWN. Neither rule acts in an instance (GetInstanceInfo's type other than "none": a dungeon,
-- raid, scenario, battleground or arena), and nothing is registered while the addon is stood down.
-- Registered only while a rule is on: the target and PLAYER_ENTERING_WORLD for either, the nameplate
-- events for auto-show. A GUID is read only through modules/Recorder.lua's DummyOf (NS.Secrets): a
-- secret one is no dummy.

local AutoArm = {}
NS.AutoArm = AutoArm

local Secrets = NS.Secrets

-- Seconds with no cataloged dummy seen before the session ends and an auto-shown window closes.
AutoArm.HIDE_DELAY = 3

local TARGET_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD" }
local PLATE_EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED" }

local events               -- this module's AceEvent target (nil until a rule is first on)
local registered = "none"  -- "none" | "target" | "plates"
local plates = {}          -- nameplate unit token -> true, for each cataloged dummy's plate
local session              -- { closes = Hud.Closes() at its start } while a dummy is near
local hideTimer            -- the session's end, while no dummy is seen
local armedRun             -- the run this rule armed, while it is armed and not started

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("AutoArm", fmt, ...) end
end

local function showOn() return NS.GetSetting("hud.autoShow") == true end
local function armOn() return NS.GetSetting("race.autoArm") == true end

local function idle() return NS.Race.State() == NS.Race.STATE.IDLE end
local function previewOn() return NS.Preview ~= nil and NS.Preview.IsActive() == true end

-- The open world only: an instance's type is anything but "none" (nil, unread, counts as open).
local function inInstance()
    local ok, _, kind = pcall(GetInstanceInfo)
    kind = ok and Secrets.PlainString(kind) or nil
    return kind ~= nil and kind ~= "none"
end

local function active()
    return not NS.IsStoodDown() and not inInstance()
end

local function isDummy(unit) return NS.Recorder.DummyOf(unit) ~= nil end

local function clearPlates()
    for unit in pairs(plates) do plates[unit] = nil end
end

-- Every nameplate up now, read again.
local function rescan()
    clearPlates()
    local api = C_NamePlate
    local ok, list = pcall(api and api.GetNamePlates)
    if not ok or type(list) ~= "table" then return end
    for _, plate in ipairs(list) do
        local unit = type(plate) == "table" and plate.namePlateUnitToken
        if Secrets.IsSafeKey(unit) and isDummy(unit) then plates[unit] = true end
    end
end

local function near()
    return isDummy("target") or next(plates) ~= nil
end

-- ── auto-show ───────────────────────────────────────────────────────────────────────────────────

local function cancelHide()
    if hideTimer then hideTimer:Cancel() end
    hideTimer = nil
end

-- The session is over: an auto-shown window closes, unless a race holds it (its idle edge asks again).
local function leave()
    cancelHide()
    if session then debug("dummy session ended") end
    session = nil
    if idle() then NS.Hud.HideAwayFromDummy() end
end

local function hideDue()
    hideTimer = nil
    rescan()
    if active() and showOn() and near() then return end
    leave()
end

local function scheduleHide()
    if hideTimer or not (session or NS.Hud.ShownNearDummy()) then return end
    hideTimer = C_Timer.NewTimer(AutoArm.HIDE_DELAY, hideDue)
end

-- Auto-show's decision, after anything that may change it.
local function decideShow()
    if not (active() and showOn()) then
        if session or NS.Hud.ShownNearDummy() then leave() end
        return
    end
    if not near() then return scheduleHide() end
    cancelHide()
    if not session then
        session = { closes = NS.Hud.Closes() }
        debug("dummy session began")
    end
    -- The player closed the window in this session: theirs to open again.
    if NS.Hud.Closes() ~= session.closes then return end
    NS.Hud.ShowNearDummy()
end

-- ── auto-arm ────────────────────────────────────────────────────────────────────────────────────

local function tryArm()
    if not (armOn() and active()) or previewOn() or not idle() then return end
    if UnitAffectingCombat("player") then return end
    local ok, reason = NS.Race.Arm(NS.Hud.ArmLength())
    if not ok then return debug("auto-arm refused: %s", tostring(reason)) end
    armedRun = NS.Race.Current()
    debug("auto-armed on a training dummy")
end

-- The target moved off the dummies: the race this rule armed goes, if it has not started. Not in
-- combat: the pull is under way (Race holds ARMED until the meter session pairs with the regen edge).
local function disarm()
    if UnitAffectingCombat("player") then return end
    local run = armedRun
    armedRun = nil
    if run and NS.Race.State() == NS.Race.STATE.ARMED and NS.Race.Current() == run then
        debug("auto-arm canceled: the target is no training dummy")
        NS.Race.Cancel()
    end
end

-- ── events ──────────────────────────────────────────────────────────────────────────────────────

local function onTarget()
    -- Auto-show first, so a window it opens is its own before an arm would claim it.
    decideShow()
    if isDummy("target") then tryArm() else disarm() end
end

local function onPlateAdded(unit)
    if not Secrets.IsSafeKey(unit) or not isDummy(unit) then return end
    plates[unit] = true
    decideShow()
end

local function onPlateRemoved(unit)
    if not Secrets.IsSafeKey(unit) or not plates[unit] then return end
    plates[unit] = nil
    decideShow()
end

local function onEnteringWorld()
    rescan()
    decideShow()
end

local HANDLERS = {
    PLAYER_TARGET_CHANGED   = onTarget,
    PLAYER_ENTERING_WORLD   = onEnteringWorld,
    NAME_PLATE_UNIT_ADDED   = onPlateAdded,
    NAME_PLATE_UNIT_REMOVED = onPlateRemoved,
}

-- An AceEvent function handler: (event, ...).
local function onAceEvent(event, ...)
    if NS.IsStoodDown() then return end
    local handler = HANDLERS[event]
    if handler then handler(...) end
end

local function wanted()
    if NS.IsStoodDown() then return "none" end
    if showOn() then return "plates" end
    if armOn() then return "target" end
    return "none"
end

local function register(set)
    -- Its own AceEvent target (events-frames-taint-§1): the HUD's PLAYER_TARGET_CHANGED is never clobbered.
    if not events then events = LibStub("AceEvent-3.0"):Embed({}) end
    for _, event in ipairs(TARGET_EVENTS) do NS.SafeRegisterEvent(events, event, onAceEvent, NS.rejectedEvents) end
    if set ~= "plates" then return end
    for _, event in ipairs(PLATE_EVENTS) do NS.SafeRegisterEvent(events, event, onAceEvent, NS.rejectedEvents) end
end

-- The race on the bus: a run leaving ARMED is no longer this rule's to cancel, and an idle race lets an
-- auto-shown window go (or come back) as the dummies say. A profile switch, copy or reset re-reads both
-- rows (their onChange does not run for it).
local function onState(run, _, to)
    if type(run) == "table" and run.sample then return end   -- a sample race is no race of this rule's
    local S = NS.Race.STATE
    if to ~= S.ARMED then armedRun = nil end
    if to == S.IDLE then decideShow() end
end

do
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.RACE_STATE_CHANGED, function(_, run, from, to) onState(run, from, to) end)
        bus:RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path)
            -- Your training dummies (#9): another creature may be one now, or no longer.
            if path == "profile" or path == NS.DummyList.PATH then AutoArm.Sync() end
        end)
    end
end

-- ── the public surface ──────────────────────────────────────────────────────────────────────────

--- Make the registrations and the window follow the two rows (their reaction, a profile change,
--- OnEnable and the stand-up). Turning auto-show off closes a window it opened; turning auto-arm off leaves an armed
--- race armed, as a manual one.
function AutoArm.Sync()
    local want = wanted()
    if want ~= registered then
        if events then events:UnregisterAllEvents() end
        registered = want
        if want ~= "none" then register(want) end
    end
    if not armOn() then armedRun = nil end
    if want == "plates" then rescan() else clearPlates() end
    decideShow()
end

--- The lifecycle's stand-down: every registration, the hide timer and the session go. The HUD drops
--- its own auto-shown window (Hud.Suspend).
function AutoArm.Suspend()
    if events then events:UnregisterAllEvents() end
    registered = "none"
    cancelHide()
    clearPlates()
    session, armedRun = nil, nil
end

--- The stand-up: rebuilt from the current settings.
function AutoArm.Resume()
    registered = "none"
    AutoArm.Sync()
end

--- What the rules hold now, for the suites and the diagnostics: the event set, the cataloged
--- nameplates up, whether a session runs (and its hide is pending), and whether a race is this rule's.
function AutoArm.Diagnose()
    local n = 0
    for _ in pairs(plates) do n = n + 1 end
    return { events = registered, plates = n, session = session ~= nil, hiding = hideTimer ~= nil,
             armed = armedRun ~= nil }
end
