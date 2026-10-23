local _, NS = ...
-- modules/Preview.lua — test mode (spec §6.5, preview-mode): a scripted 30s race on the HUD with
-- made-up numbers, Armed, Running, Stop!, Waiting and then Result, so the HUD can be placed and sized
-- without a dummy. It draws through the HUD's own bodies (NS.Hud.Render), the same render path a real
-- race takes; the HUD lays the test-mode strip over it while it is on.
--
-- Session-only and on until turned off (the Master controls' Test mode row, `/dr test`, the launcher).
-- It ENDS on combat (core/DpsRace.lua's PLAYER_REGEN_DISABLED), on arming a real race, on its own
-- switch, on Reset all settings (the row's default) and silently on the stand-down. A start is refused
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

-- Each body's figures, `t` seconds into its phase.
local FIGURES = {
    armed = function() return {} end,
    running = function(t)
        return { timeLeft = math.max(0, Preview.LENGTH - t), live = liveAt(math.min(t, Preview.LENGTH)) }
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
    result = function() return { isNew = true, delta = 2.4, icons = true } end,
}

local function draw(now)
    local step = Preview.SCRIPT[phase]
    NS.Hud.Render(step.key, run, FIGURES[step.key](now - phaseAt))
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
    opened = not NS.Hud.wanted
    if opened then NS.Hud.Show() end
    draw(phaseAt)
    ticker = C_Timer.NewTicker(Preview.TICK, beat)
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
    if reason == "combat" then NS.SayTestModeEnded() end
    if opened and reason ~= "race" then
        opened = false
        NS.Hud.Hide()
    else
        opened = false
        NS.Hud.Refresh()
    end
    debug("test mode off (%s)", reason or "switch")
    return true
end

--- The stand-down ends test mode silently: the player turned the addon off, not the preview.
function Preview.Suspend()
    Preview.active = false
    cancelTicker()
    run, opened = nil, false
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
