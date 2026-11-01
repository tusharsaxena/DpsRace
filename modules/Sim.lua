local _, NS = ...
-- modules/Sim.lua — `/dr sim [scenario]` (B5, the owner's call, 2026-10-25): a whole sample race played
-- through the race's own views and messages (armed, running, Stop!, waiting, the result card), then the
-- Results window on the sim's run beside the sample history, so best and compare have something to
-- stand on.
--
-- The preview shell (modules/Preview.lua) owns the switch, the end conditions and the windows; this
-- file holds the scenarios and moves modules/SampleRace.lua on the clock. The phases are not scripted
-- here: the race moves itself by its plan, and the HUD picks Stop! or Waiting as it does for a real
-- race. The run lives in the sample history in memory only, and never reaches the store or NS.Race.

local Sim = {}
NS.Sim = Sim

local L = NS.L
local MockRuns = NS.MockRuns

-- The scenarios, in the order help lists them. `factor` sets the sample's DPS against the history's
-- best on its board (the player's spec, the target type, 0:30); `first` races a board with no runs.
-- `tail` and `combatEnd` are seconds after the buzzer; `sticky` holds combat past race.hintDelay.
Sim.SCENARIOS = {
    { key = "newbest", factor = 1.04, tail = 3.1, combatEnd = 4.2, desc = "beats the best" },
    { key = "behind", factor = 0.93, tail = 2.4, combatEnd = 5.2, desc = "complete, behind the best" },
    { key = "first", category = "boss", tail = 1.8, combatEnd = 3.6, desc = "the first race on its board: no best, no pace bar" },
    { key = "incomplete", factor = 0.96, status = "incomplete", endAt = 18, desc = "combat ends before the buzzer" },
    { key = "died", factor = 0.90, status = "incomplete", endAt = 12, died = true, desc = "you die mid-race" },
    { key = "flagged", factor = 0.98, tail = 2.8, combatEnd = 4.6, late = { { t = 1.4 } }, desc = "a late cast after the buzzer" },
    { key = "shared", factor = 0.99, tail = 3.4, combatEnd = 4.8, shared = true, desc = "a shared session: no chart, no pace bar" },
    { key = "sticky", factor = 0.97, tail = 2.6, sticky = true, desc = "combat holds on: the drop-combat hint" },
}
Sim.DEFAULT = "newbest"
-- How long the armed body holds before the sample race's clock starts.
Sim.ARM_HOLD = 3
-- How long the result card holds before the Results window opens on the sim's run.
Sim.RESULT_HOLD = 4
-- How long past the hint's delay a sticky combat lasts.
Sim.STICKY_EXTRA = 3
-- How often the clock moves the sample race on (the HUD's own tick, modules/Hud.lua).
Sim.TICK = 0.05

local ticker, sample, scenario, resultAt, finished, history, quiet

local function find(key)
    for _, s in ipairs(Sim.SCENARIOS) do
        if s.key == key then return s end
    end
    return nil
end

--- Whether `word` names a scenario.
function Sim.IsScenario(word) return find(word) ~= nil end

--- The scenario keys, in help order.
function Sim.Names()
    local out = {}
    for i, s in ipairs(Sim.SCENARIOS) do out[i] = s.key end
    return out
end

--- The scenario playing, or nil.
function Sim.Scenario() return scenario end

local function combatEnd(s)
    if not s.sticky then return s.combatEnd end
    return (tonumber(NS.GetSetting("race.hintDelay")) or 0) + Sim.STICKY_EXTRA
end

--- The sample race scenario `key` runs against `dataset` (MockRuns.Race's sample).
--- @param key string
--- @param dataset table  the sample history (MockRuns.Dataset's)
--- @return table sample
function Sim.Sample(key, dataset)
    local s = find(key) or find(Sim.DEFAULT)
    local category = s.category or "single"
    local runs = dataset.runs
    local best = MockRuns.BoardBest(runs, category)
    local dps = best and s.factor and best.result.dps * s.factor or MockRuns.DPS
    return MockRuns.Race({ id = "sim-" .. s.key, category = category, dps = math.floor(dps), status = s.status,
                           endAt = s.endAt, tail = s.tail, combatEnd = combatEnd(s), late = s.late, died = s.died,
                           shared = s.shared }, runs, dataset.loadouts)
end

local function cancelTicker()
    if ticker then ticker:Cancel() end
    ticker = nil
end

-- The script's end: the Results window opens on the sim's run; the HUD keeps the result card.
local function finish()
    cancelTicker()
    finished = true
    NS.Preview.OpenResults(sample.run.id)
end

--- One beat: the race moves on, the HUD hears its meter, and the card's hold runs out.
local function beat()
    if not (NS.Preview.IsActive() and sample) then return cancelTicker() end
    local Race = NS.SampleRace
    if Race.Advance() then NS.Hud.MeterUpdated() end
    local state, STATE = Race.State(), NS.Race.STATE
    -- The card was dismissed (New Race, Delete): the script is over, and nothing opens on the idle body.
    if state == STATE.IDLE then return cancelTicker() end
    if state ~= STATE.RESULT then return end
    resultAt = resultAt or GetTime()
    if GetTime() - resultAt >= Sim.RESULT_HOLD then finish() end
end
Sim.Beat = beat

-- Put the sample race at its arm and start the clock: Begin's job, and the stepper's when its Restart
-- asks for a fresh session.
local function launch(key)
    cancelTicker()
    local s = find(key) or find(Sim.DEFAULT)
    scenario = s.key
    sample, resultAt, finished = Sim.Sample(s.key, history), nil, false
    NS.SampleRace.Start(sample, Sim.ARM_HOLD)
    ticker = C_Timer.NewTicker(Sim.TICK, beat)
end

-- ── the stepper (SF-DR-8) ───────────────────────────────────────────────────────────────────────
-- LibKa0s-Sim-1.0's step window beside the race window. The race still plays on its own clock; a
-- click on a step jumps the clock to that moment (SampleRace.Skip), so the stepper skips the waits
-- and never changes what the race does. The session fakes no client answer (core/SimSetup.lua).

local STEP_MOMENTS = {
    armed = function() end,
    start = function() NS.SampleRace.Skip(0) end,
    buzzer = function() NS.SampleRace.Skip(NS.SampleRace.StopAt() or 0) end,
    result = function() NS.SampleRace.SkipToResult() end,
    results = function() if not finished then Sim.Finish() end end,
}

local function timeline(_, opts)
    local s = find(opts.scenario) or find(Sim.DEFAULT)
    local stopLabel = s.endAt and L["Combat ends"] or L["Buzzer"]
    return {
        { kind = "armed", label = L["Armed"] },
        { kind = "start", label = L["Race starts"] },
        { kind = "buzzer", label = stopLabel },
        { kind = "result", label = L["Result card"] },
        { kind = "results", label = L["Results window"] },
    }
end

local function playStep(step)
    STEP_MOMENTS[step.kind]()
    NS.Hud.MeterUpdated()
    return step.label
end

local function newSession()
    local lib = NS.SimLib
    if not (lib and lib.New) then return nil end
    local names, defs = {}, {}
    for i, s in ipairs(Sim.SCENARIOS) do
        names[i] = s.key
        defs[s.key] = { label = s.key, timeline = timeline }
    end
    return lib:New({
        name = "DpsRace",
        seam = NS.SimSeam,
        slash = NS.SLASH .. " sim",
        deliver = function() return 0 end,
        isStoodDown = function() return NS.IsStoodDown() end,
        scenarios = { names = names, defs = defs },
        -- The sample race is the world; a fresh session (the panel's Restart) plays it again.
        prepare = function(_, _, opts, ready)
            if history then launch(opts.scenario) end
            ready()
        end,
        play = playStep,
        refusal = function(opts)
            if not (opts.fromHost or history) then return L["Start the simulation with /dr sim [scenario]."] end
        end,
        stepDelay = 1,
        print = function(line) if not quiet then NS.Print(line) end end,
        panel = {
            title = function() return L["DPS Race - Simulation"] end,
            anchorTo = function() return NS.Hud.Frame() end,
        },
    })
end

--- The stepper's session, or nil with no LibKa0s-Sim-1.0.
Sim.session = newSession()
NS.SimSession = Sim.session

local function stopSession(reason)
    local session = Sim.session
    if not session then return end
    quiet = true
    if session:IsActive() then session:Stop(reason) end
    session:HidePanel()
    quiet = false
end

--- Play scenario `key` (the default when it names none) against `data`'s history. The preview
--- shell has already checked it may start.
function Sim.Begin(key, data)
    stopSession("switch")
    history = data
    local session = Sim.session
    if not session then return launch(key) end
    local s = find(key) or find(Sim.DEFAULT)
    if not session:Start({ scenario = s.key, fromHost = true }) then launch(s.key) end
    session:ShowPanel()
end

--- The script's end for the stepper's last step: the Results window on the sim's run.
function Sim.Finish()
    if sample then finish() end
end

--- Stop the script where it is (the preview's stop and switch).
function Sim.Cancel()
    cancelTicker()
    stopSession("stop")
    sample, scenario, resultAt, finished, history = nil, nil, nil, false, nil
end

--- What the sim is doing, for the diagnostics report and the suites.
function Sim.Diagnose()
    local phase = "none"
    if sample then phase = finished and "results" or NS.Hud.Diagnose().body end
    return { scenario = scenario or "none", phase = phase, ticking = ticker ~= nil }
end

--- The usage line: every scenario, the default first.
function Sim.Usage()
    return L["Usage: %s sim [%s]"]:format(NS.SLASH, table.concat(Sim.Names(), "|"))
end
