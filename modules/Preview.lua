local _, NS = ...
-- modules/Preview.lua — test mode (spec §6.5, preview-mode): a scripted 30s race on the HUD with
-- made-up numbers, Armed, Running, Stop!, Waiting and then Result, so the HUD can be placed and sized
-- without a dummy. It draws through the HUD's own bodies (NS.Hud.Render), the same render path a real
-- race takes; the HUD lays the test-mode strip over it while it is on.
--
-- Session-only and on until turned off (the Master controls' Test mode row, `/dr test`, the launcher).
-- It ENDS on combat (core/DpsRace.lua's PLAYER_REGEN_DISABLED), on arming a real race, on its own
-- switch, on Reset all settings (the row's default), on closing the HUD or its sample Cancel
-- (modules/Hud.lua's acts, which never touch the real race), and silently on the stand-down. A start is refused
-- in combat and while a real race is armed, running or waiting for its result. It never touches the
-- race engine and never writes a run: the sample run lives only in this file.

local Preview = { active = false }
NS.Preview = Preview

local L = NS.L

-- The script: each phase's body and how long it holds. The result card holds until test mode ends.
Preview.LENGTH = 30
Preview.SCRIPT = {
    { key = "armed",   secs = 3 },
    { key = "running", secs = Preview.LENGTH },
    { key = "stop",    secs = 3 },
    { key = "waiting", secs = 4 },
    { key = "result" },
}
-- How often the script redraws the clock and the live figures (the HUD's own clock runs at 20 Hz; a
-- preview needs only to look alive).
Preview.TICK = 0.1

-- The sample (a Destruction warlock on a single-target dummy): each spell's share of the damage, in
-- the order Blizzard would list it. Names and icons come from C_Spell, as for a real run.
local SPELLS = {
    { id = 5740, share = 0.276 },     -- Rain of Fire
    { id = 116858, share = 0.185 },   -- Chaos Bolt
    { id = 445468, share = 0.184 },   -- Wither
    { id = 29722, share = 0.161 },    -- Incinerate
    { id = 17962, share = 0.104 },    -- Conflagrate
    { id = 17877, share = 0.052 },    -- Shadowburn
    { id = 1122, share = 0.038 },     -- Summon Infernal
}
local DPS = 147600
local TAIL = 3.1

local ticker, phase, phaseAt, opened, run

local function debug(fmt, ...) NS.Debug("Test", fmt, ...) end

--- The sample run: the player's own name and spec, a made-up score. Built fresh on every start.
local function sampleRun()
    local char = NS.Recorder.SnapshotPlayer()
    local damage = DPS * Preview.LENGTH
    local spells = {}
    for i, s in ipairs(SPELLS) do
        spells[i] = { id = s.id, dmg = math.floor(damage * s.share), dps = DPS * s.share }
    end
    return {
        id = "preview", status = "complete", preview = true,
        race = { length = Preview.LENGTH, grace = 1.0, restartGap = 6 },
        char = char,
        target = { name = L["Training Dummy"], category = "single", count = 1 },
        result = { damage = damage, dps = DPS, meterDps = DPS * 0.92, tail = TAIL, combatEnd = TAIL + 2 },
        flags = { lateCasts = { { t = 1.4, spellID = 29722 } }, reloaded = false, died = false },
        spells = spells,
        note = "",
    }
end

--- The live figures `elapsed` seconds into the race: plain numbers, in the shape Meter.ReadLive answers.
local function liveAt(elapsed)
    local total = math.floor(DPS * elapsed)
    local live = { total = total, dps = DPS, maxAmount = math.floor(total * SPELLS[1].share), spells = {} }
    for i, s in ipairs(SPELLS) do
        live.spells[i] = { spellID = s.id, total = math.floor(total * s.share), dps = DPS * s.share }
    end
    return live
end

-- The sample's chart and pace bar (#2, #3): its damage at each whole second so far, against a made-up
-- best a little under it, scaled as a race with a best is (plain numbers; a real race's are secret).
-- The result card's chart is scaled to the sample's final damage; its pace bar sets that damage beside
-- the sample best's.
local SAMPLE_BEST = { race = { length = Preview.LENGTH }, result = { damage = DPS * Preview.LENGTH * 0.96 } }

local function sampleChart(elapsed, final)
    local values = {}
    for i = 1, math.floor(elapsed) do values[i] = DPS * i end
    local chart = { count = NS.Slices.Count(Preview.LENGTH), values = values, length = Preview.LENGTH }
    if final then
        chart.max = DPS * Preview.LENGTH
        return chart
    end
    chart.best = SAMPLE_BEST.result.damage
    chart.max = chart.best * NS.HudChart.HEADROOM
    chart.note = L["vs best pace"]
    return chart
end

-- Each body's figures, `t` seconds into its phase.
local FIGURES = {
    armed = function() return {} end,
    running = function(t)
        local elapsed = math.min(t, Preview.LENGTH)
        return { timeLeft = Preview.LENGTH - elapsed, elapsed = elapsed, live = liveAt(elapsed),
                 chart = sampleChart(elapsed), pace = { max = NS.HudChart.PaceMax(SAMPLE_BEST, elapsed) } }
    end,
    stop = function(t)
        return { tail = math.min(t, TAIL), sinceBuzzer = t, inCombat = true, grace = 1.0,
                 lateCasts = t >= 1.4 and run.flags.lateCasts or {} }
    end,
    waiting = function(t)
        local since = Preview.SCRIPT[3].secs + t
        return { tail = TAIL, sinceBuzzer = since, inCombat = true,
                  hint = L["Combat is holding. Walk out of range. Your score is safe: it waits for combat to end, however long that takes."] }
    end,
    -- The result card's pace bar: the sample's final damage against the sample best at the buzzer.
    result = function()
        return { isNew = true, delta = 2.4, icons = true, chart = sampleChart(Preview.LENGTH, true),
                 pace = { max = NS.HudChart.PaceMax(SAMPLE_BEST, Preview.LENGTH), value = DPS * Preview.LENGTH } }
    end,
}

-- The center countdown (modules/Countdown.lua) shows in the sample race's last seconds, silently, and
-- goes with its buzzer and with test mode.
local function countdown(key, figures)
    local C = NS.Countdown
    if not C then return end
    if key == "running" then C.Preview(figures.timeLeft) else C.EndPreview() end
end

local function draw(now)
    local step = Preview.SCRIPT[phase]
    local figures = FIGURES[step.key](now - phaseAt)
    NS.Hud.Render(step.key, run, figures)
    countdown(step.key, figures)
end

local function cancelTicker()
    if ticker then ticker:Cancel() end
    ticker = nil
end

--- One beat of the script: move on when the phase is over, then redraw.
local function beat()
    if not Preview.active then return cancelTicker() end
    local now = GetTime()
    local step = Preview.SCRIPT[phase]
    while step.secs and now - phaseAt >= step.secs do
        phaseAt = phaseAt + step.secs
        phase = phase + 1
        step = Preview.SCRIPT[phase]
    end
    draw(now)
    -- The result card holds still: nothing left to redraw.
    if not step.secs then cancelTicker() end
end
Preview.Beat = beat

-- A real race on screen: armed, running or waiting for its result (spec §6.5).
local function raceOn()
    local S, state = NS.Race.STATE, NS.Race.State()
    return state == S.ARMED or state == S.RUNNING or state == S.STOPPING
end

function Preview.IsActive() return Preview.active end

-- The Master controls' Test mode checkbox reads Preview.IsActive() only when a refresher runs: every
-- start and stop repaints an open panel in place (options-ui-§11, §15), whoever turned it.
local function repaintPanel()
    local H = NS.Helpers
    if H and type(H.RefreshScalars) == "function" then H.RefreshScalars() end
end

--- Turn test mode on. Refused (one line) in combat and during a real race; silent while stood down,
--- where the caller's own hold-aware refusal has already spoken.
--- @return boolean started
function Preview.Start()
    if NS.IsStoodDown() then return false end
    if UnitAffectingCombat("player") then
        NS.Print(L["Test mode is not available in combat."])
        return false
    end
    if raceOn() then
        NS.Print(L["Test mode is not available during a race."])
        return false
    end
    cancelTicker()
    Preview.active = true
    run = sampleRun()
    phase, phaseAt = 1, GetTime()
    -- Shown for the preview; closed again at the end only if the player had not opened it.
    -- Opened as the addon's own (Hud.AutoShow): a race that ends test mode inherits it, and onArm
    -- closes it with that race; the stand-down drops it (Hud.Suspend).
    opened = not NS.Hud.wanted
    if opened then NS.Hud.AutoShow() end
    draw(phaseAt)
    ticker = C_Timer.NewTicker(Preview.TICK, beat)
    repaintPanel()
    debug("test mode on")
    return true
end

--- Turn test mode off. `reason` "combat" says so once; "race" (a real race was armed) keeps the HUD
--- open for that race; any other stop is the player's own act and stays quiet.
--- @param reason string|nil
--- @return boolean stopped
function Preview.Stop(reason)
    if not Preview.active then return false end
    Preview.active = false
    cancelTicker()
    run = nil
    if NS.Countdown then NS.Countdown.EndPreview() end
    if reason == "combat" then NS.SayTestModeEnded() end
    if opened and reason ~= "race" then
        opened = false
        NS.Hud.Hide()
    else
        opened = false
        NS.Hud.Refresh()
    end
    repaintPanel()
    debug("test mode off (%s)", reason or "switch")
    return true
end

--- The stand-down ends test mode silently: the player turned the addon off, not the preview.
function Preview.Suspend()
    local was = Preview.active
    Preview.active = false
    cancelTicker()
    if NS.Countdown then NS.Countdown.EndPreview() end
    run, opened = nil, false
    if was then repaintPanel() end
end

--- What test mode is doing, for the diagnostics report and the suites.
function Preview.Diagnose()
    local step = Preview.active and Preview.SCRIPT[phase]
    return { active = Preview.active, phase = step and step.key or "none", ticking = ticker ~= nil }
end

-- Arming a real race ends test mode (spec §6.5): the HUD then shows the race.
do
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.RACE_STATE_CHANGED, function(_, _, _, to)
            if to == NS.Race.STATE.ARMED and Preview.active then
                NS.Print(L["Test mode ended: a race was armed."])
                Preview.Stop("race")
            end
        end)
    end
end
