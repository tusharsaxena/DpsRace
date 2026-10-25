local _, NS = ...
-- modules/Sim.lua — `/dr sim [scenario]` (B5, the owner's call, 2026-10-25): a whole sample race played
-- through the HUD's bodies (armed, running, Stop!, waiting, the result card), then the Results window
-- on the sim's run beside the sample history, so best and compare have something to stand on.
--
-- The preview shell (modules/Preview.lua) owns the switch, the end conditions and the windows; this
-- file holds the scenarios and plays the script. The sim's run joins the sample history in memory
-- only (modules/Results_Source.lua) and never reaches the store or the race engine.

local Sim = {}
NS.Sim = Sim

local L = NS.L
local MockRuns = NS.MockRuns

-- The scenarios, in the order help lists them. `factor` sets the sample's DPS against the history's
-- best on its board (the player's spec, the target type, 0:30); `first` races a board with no runs.
Sim.SCENARIOS = {
    { key = "newbest", factor = 1.04, desc = "beats the best" },
    { key = "behind", factor = 0.93, desc = "complete, behind the best" },
    { key = "first", category = "boss", desc = "the first race on its board: no best, no pace bar" },
    { key = "incomplete", factor = 0.96, status = "incomplete", endAt = 18, desc = "combat ends before the buzzer" },
    { key = "died", factor = 0.90, status = "incomplete", endAt = 12, died = true, desc = "you die mid-race" },
    { key = "flagged", factor = 0.98, late = { { t = 1.4, spellID = 29722 } }, desc = "a late cast after the buzzer" },
    { key = "shared", factor = 0.99, shared = true, desc = "a shared session: no chart, no pace bar" },
}
Sim.DEFAULT = "newbest"
-- How long the result card holds before the Results window opens on the sim's run.
Sim.RESULT_HOLD = 4
-- How often the script redraws the clock and the live figures (the HUD's own clock runs at 20 Hz; a
-- sim needs only to look alive).
Sim.TICK = 0.1

local ticker, script, phase, phaseAt, sample, scenario

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

--- The sample race scenario `key` runs against `runs` (MockRuns.Race's sample).
--- @param key string
--- @param runs table  the sample history
--- @return table sample
function Sim.Sample(key, runs)
    local s = find(key) or find(Sim.DEFAULT)
    local category = s.category or "single"
    local best = MockRuns.BoardBest(runs, category)
    local dps = best and s.factor and best.result.dps * s.factor or MockRuns.DPS
    return MockRuns.Race({ id = "sim-" .. s.key, category = category, dps = math.floor(dps), status = s.status,
                           endAt = s.endAt, late = s.late, died = s.died, shared = s.shared }, runs)
end

-- The script for a scenario: each phase's body and how long it holds; `results` opens the Results
-- window and ends the script. A run that stops before its buzzer skips Stop! and reads its result
-- out of combat.
local function scriptFor(s)
    if s.status == "incomplete" then
        return { { key = "armed", secs = 3 }, { key = "running", secs = s.endAt }, { key = "waiting", secs = 3 },
                 { key = "result", secs = Sim.RESULT_HOLD }, { key = "results" } }
    end
    return { { key = "armed", secs = 3 }, { key = "running", secs = MockRuns.LENGTH },
             { key = "stop", secs = MockRuns.STOP_SECS }, { key = "waiting", secs = 4 },
             { key = "result", secs = Sim.RESULT_HOLD }, { key = "results" } }
end

local function figures(key, t)
    local f = MockRuns.Figures(sample, key, t)
    -- An incomplete run's combat is over: the waiting body reads the result, with no drop-combat hint.
    if key == "waiting" and sample.run.status == "incomplete" then f.inCombat, f.hint = false, nil end
    return f
end

local function cancelTicker()
    if ticker then ticker:Cancel() end
    ticker = nil
end

-- The script's end: the sim's run joins the sample history and the Results window opens on it; the
-- HUD keeps the result card.
local function finish()
    cancelTicker()
    local rec = not sample.shared and MockRuns.Slices(sample.run, sample.stopAt) or nil
    NS.ResultsSource.Add(sample.run, rec)
    NS.Preview.OpenResults(sample.run.id)
end

--- One beat of the script: move on when the phase is over, then redraw.
local function beat()
    if not (NS.Preview.IsActive() and script) then return cancelTicker() end
    local now = GetTime()
    local step = script[phase]
    while step.secs and now - phaseAt >= step.secs do
        phaseAt = phaseAt + step.secs
        phase = phase + 1
        step = script[phase]
    end
    if step.key == "results" then return finish() end
    NS.Preview.Draw(step.key, sample.run, figures(step.key, now - phaseAt))
end
Sim.Beat = beat

--- Play scenario `key` (the default when it names none) against `dataset`'s history. The preview
--- shell has already checked it may start.
function Sim.Begin(key, dataset)
    cancelTicker()
    local s = find(key) or find(Sim.DEFAULT)
    scenario = s.key
    sample = Sim.Sample(s.key, dataset.runs)
    script, phase, phaseAt = scriptFor(s), 1, GetTime()
    beat()
    ticker = C_Timer.NewTicker(Sim.TICK, beat)
end

--- Stop the script where it is (the preview's stop and switch).
function Sim.Cancel()
    cancelTicker()
    script, sample, scenario = nil, nil, nil
end

--- What the sim is doing, for the diagnostics report and the suites.
function Sim.Diagnose()
    local step = script and script[phase]
    return { scenario = scenario or "none", phase = step and step.key or "none", ticking = ticker ~= nil }
end

--- The usage line: every scenario, the default first.
function Sim.Usage()
    return L["Usage: %s sim [%s]"]:format(NS.SLASH, table.concat(Sim.Names(), "|"))
end
