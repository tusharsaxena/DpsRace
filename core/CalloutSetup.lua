local addonName, NS = ...
-- core/CalloutSetup.lua — the race's final seconds on LibKa0s-Callout-1.0 (LibKa0s#85, AD-85-DR; spec
-- §4.3, §6.1 before it): the center-screen numbers and the countdown cue. It replaces the addon's own
-- countdown module (its own frame, the BigGold digit art and a timer per mark), which is gone.
-- When race.finalCountdown seconds remain (3-10, default 10) and race.centerCountdown is on, the
-- call-out counts down to 1 in the middle of the screen and goes at the buzzer (the HUD's raid
-- warning STOP and its sound stay where they are, in modules/Hud.lua).
--
-- THE SEAM (library-stack-§7): this one file leases the major. NS.Callout is the addon's one
-- instance; with the library absent it is NS.CalloutStub, the instance's surface with every member a
-- no-op answering what an idle call-out answers (the library's docs/api/Callout, The degradation
-- stub), so nothing shows and nothing raises. tests/test_countdown.lua holds the stub to a live one.
--
-- THE LOOK is the library's, with two values of this addon's (CALLOUT_DB below): the numbers sit
-- where the old ones did (150 px above the screen's center) and are gold, the old digits' color.
-- Nothing else is stored and nothing is written: the addon draws none of the call-out's settings and
-- never unlocks it, so the instance has no write to make (no `d.path` / `d.set`, no schema rows).
-- The voice is off: this copy ships no voice pack (no `LibKa0s sounds:` line, so `d.packs` is
-- empty and the instance reads its voice as "off").
--
-- ONE endsAt. The call-out counts down to the race's buzzer on the GetTime() clock (now plus the
-- race's TimeLeft), reading ceil(endsAt - now) on each frame, so n shows from n seconds left until
-- n - 1, exactly where the old per-mark timers flipped it. It runs an OnUpdate while it counts, so it
-- is handed the countdown only LEAD seconds before the first number: until then one C_Timer waits.
--
-- THE CUE (race.countdownCue): the battleground countdown sound at 10, 5, 3, 2 and 1 s left and with
-- each center number, once a second at most. A number's cue plays as it shows (the call-out's
-- onTick); a cue mark the numbers do not show (above the window, or the numbers off) keeps a C_Timer
-- of its own (every cue mark, with the library absent). The settings are read as each one fires.
--
-- A RESUME mid-window (a /reload, a stand-up, a setting changed mid-race) shows the number of the
-- moment at once, silently, and counts on from there. Re-arming with the same endsAt and window
-- leaves a running countdown alone, so a refresh never repeats a number.
--
-- THE SIM (modules/SampleRace.lua) runs the same countdown: its RACE_STATE_CHANGED arrives here, and
-- the race whose clock it reads is NS.SampleRace while it runs. A frozen test-mode race counts nothing.
--
-- THE STAND-DOWN: every timer canceled and the call-out suspended (no countdown, nothing shown, no
-- OnUpdate) until the stand-up resumes it. Nothing here reads a meter value: the call-out is handed a
-- GetTime() value, never a figure, and no pull timer is broadcast and no Blizzard countdown driven.

local Callout = LibStub and LibStub("LibKa0s-Callout-1.0", true)

-- The instance's surface, each member a no-op (the library's docs/api/Callout, the degradation stub).
NS.CalloutStub = {
    Countdown = function() return false end, Cancel = function() return false end,
    Running = function() return false, nil end, Show = function() return false end,
    Hide = function() end, Suspend = function() end, Resume = function() end,
    Suspended = function() return false end, Get = function() return nil end,
    Set = function() return false end, GetColor = function() return 1, 1, 1 end,
    GetGlowColor = function() return 1, 1, 1 end,
    SetColor = function() return false end, Apply = function() end, SetLocked = function() end,
    Locked = function() return true end, ResetPosition = function() end,
    Voices = function() return {} end, TtsVoices = function() return {} end,
    Frame = function() return nil end, Look = function() return {} end,
    Preview = function() return false end, TestCountdown = function() return false end,
    SettingsRows = function() return {} end, SchemaRows = function() return {}, {} end,
    SettingsTabs = function() return {} end, SettingsTab = function() return nil end,
    BuildSettings = function() return nil end,
    Stats = function() return { built = false, shown = false, running = false, awake = false,
        suspended = false, locked = true, logged = 0 } end,
}

local Countdown = {}
NS.Countdown = Countdown

-- The countdown cue's marks, in seconds left (spec §4.3).
Countdown.CUES = { 10, 5, 3, 2, 1 }
-- The numbers' window bounds (race.finalCountdown's range); also the highest cue mark.
Countdown.MIN, Countdown.MAX = 3, 10
-- The seconds before the first number that the call-out is handed the countdown.
Countdown.LEAD = 1
Countdown.FRAME_NAME = "DpsRaceCallout"
-- Where the numbers sit (the old countdown's place) and their color (the BigGold digits' gold).
Countdown.POINT = { "CENTER", "CENTER", 0, 150 }
Countdown.GOLD = { 1, 0.82, 0 }

local SOUND_CUE = 25477      -- SOUNDKIT.UI_BATTLEGROUND_COUNTDOWN_TIMER, if the table is absent
-- A whole second computed from GetTime() differences may land a hair either side of the integer.
local EPS = 1e-6

local IS_CUE = {}
for _, m in ipairs(Countdown.CUES) do IS_CUE[m] = true end

-- The call-out's settings table: read only, never written (THE LOOK, above).
local CALLOUT_DB = { point = Countdown.POINT, colors = { number = Countdown.GOLD } }

NS.Callout = Callout and Callout:New({
    name = Countdown.FRAME_NAME,
    addon = addonName,
    skin = addonName,
    packs = {},
    db = CALLOUT_DB,
    debug = function(_, msg) if NS.Debug then NS.Debug("Countdown", "%s", tostring(msg)) end end,
}) or NS.CalloutStub
local CO = NS.Callout

local lead       -- the lead-in C_Timer, while it waits
local cues = {}  -- mark -> C_Timer handle, for the cue marks the numbers do not show
local armedAt    -- the endsAt the call-out counts down to, nil while it counts nothing
local armedFrom  -- the window it was armed with
local arming     -- true while CO:Countdown runs: the number of the moment shows silently

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Countdown", fmt, ...) end
end

-- ── settings ────────────────────────────────────────────────────────────────────────────────────

local function numbersOn() return NS.GetSetting("race.centerCountdown") ~= false end
local function cueOn() return NS.GetSetting("race.countdownCue") ~= false end

--- race.finalCountdown, clamped to its range.
local function window()
    local n = math.floor(tonumber(NS.GetSetting("race.finalCountdown")) or Countdown.MAX)
    return math.max(Countdown.MIN, math.min(Countdown.MAX, n))
end

-- ── the race ────────────────────────────────────────────────────────────────────────────────────

-- The race the countdown reads: the sim's sample race while one runs, else the real one.
local function theRace()
    local sample = NS.SampleRace
    if sample and sample.On() and not sample.Held() then return sample end
    return NS.Race
end

local function racing()
    return not NS.IsStoodDown() and theRace().State() == NS.Race.STATE.RUNNING
end

local function play()
    if type(PlaySound) ~= "function" then return end
    local id = (SOUNDKIT and SOUNDKIT.UI_BATTLEGROUND_COUNTDOWN_TIMER) or SOUND_CUE
    pcall(PlaySound, id, "Master")
end

local function cancelTimers()
    if lead then lead:Cancel() end
    lead = nil
    for m, handle in pairs(cues) do
        handle:Cancel()
        cues[m] = nil
    end
end

--- Take the countdown down: every timer, and the call-out's number.
local function takeDown()
    cancelTimers()
    if armedAt then
        armedAt, armedFrom = nil, nil
        CO:Cancel()
    end
end

-- Each new number: its cue, unless it is the number of the moment shown on an arm.
local function onTick()
    if not arming and cueOn() then play() end
end

--- Hand the call-out the countdown to `at`, from `from`. Armed only when the call-out took it (the
--- stub, or a suspended instance, answers false, and Diagnose must not report a countdown then).
local function countDown(at, from)
    if armedAt then CO:Cancel() end
    arming = true
    local ok = CO:Countdown({ endsAt = at, from = from, finish = false, onTick = onTick })
    arming = false
    if ok then
        armedAt, armedFrom = at, from
        debug("counting down from %d", from)
    else
        armedAt, armedFrom = nil, nil
    end
end

--- One cue mark the numbers do not show, `m` seconds left. The settings are read as it fires.
local function cueMark(m)
    cues[m] = nil
    if racing() and cueOn() then play() end
end

-- The race's buzzer on the GetTime() clock, snapped to the microsecond so a whole second left reads
-- as that second.
local function endsAt(left)
    return math.floor((GetTime() + left) * 1e6 + 0.5) / 1e6
end

--- The lead-in's end: the call-out is handed the countdown, from the race's clock now.
local function leadDone()
    lead = nil
    local left = racing() and numbersOn() and theRace().TimeLeft()
    if left then countDown(endsAt(left), window()) end
end

--- Arm the countdown still ahead from the race's own clock: the call-out at once inside the lead,
--- else the lead-in; and a timer per cue mark the numbers will not show.
local function schedule()
    cancelTimers()
    if not racing() then return takeDown() end
    local left = theRace().TimeLeft()
    if not left then return takeDown() end
    local at = endsAt(left)
    -- Without the library no number shows, so the cue marks keep timers of their own.
    local numbers, from = numbersOn() and CO ~= NS.CalloutStub, window()
    for m = Countdown.MAX, 1, -1 do
        if IS_CUE[m] and not (numbers and m <= from) and left > m + EPS then
            cues[m] = C_Timer.NewTimer(left - m, function() cueMark(m) end)
        end
    end
    if not numbers then
        if armedAt then armedAt, armedFrom = nil, nil; CO:Cancel() end
        return
    end
    if at == armedAt and from == armedFrom and CO:Running() then return end
    if left > from + Countdown.LEAD + EPS then
        if armedAt then armedAt, armedFrom = nil, nil; CO:Cancel() end
        lead = C_Timer.NewTimer(left - from - Countdown.LEAD, leadDone)
        return
    end
    countDown(at, from)
end

-- ── the public surface ──────────────────────────────────────────────────────────────────────────

--- The number the call-out shows for the race now, or nil.
--- @return number|nil
function Countdown.Shown()
    if not armedAt then return nil end
    local running, n = CO:Running()
    return running and n or nil
end

--- The race-settings rows' reaction (race.centerCountdown, race.finalCountdown, race.countdownCue)
--- and the sim's race moving on: re-arm from the new values, or take it down.
function Countdown.Refresh()
    if racing() then schedule() else takeDown() end
end

--- The lifecycle's stand-down: every timer canceled, the call-out suspended.
function Countdown.Suspend()
    cancelTimers()
    armedAt, armedFrom = nil, nil
    CO:Suspend()
end

--- The stand-up (and OnEnable): the call-out resumed, and re-armed from the race's current state.
function Countdown.Resume()
    CO:Resume()
    if racing() then schedule() end
end

--- What it is doing, for the diagnostics report: the number shown, what is armed (the lead-in, the
--- cue marks' timers and the call-out's countdown), the owner.
function Countdown.Diagnose()
    local n = (lead and 1 or 0) + (armedAt and 1 or 0)
    for _ in pairs(cues) do n = n + 1 end
    return { shown = Countdown.Shown() or "none", scheduled = n, owner = armedAt and "race" or "none" }
end

do
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.RACE_STATE_CHANGED, function(_, _, _, to)
            if to == NS.Race.STATE.RUNNING then schedule() else takeDown() end
        end)
    end
end
