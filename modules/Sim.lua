local _, NS = ...
-- modules/Sim.lua — `/dr sim` (B5, the owner's call, 2026-10-25): a whole sample race played through the
-- race's own views and messages (armed, running, Stop!, waiting, the result card), then the Results
-- window on the sim's run beside the sample history, so best and compare have something to stand on.
-- The race is an imaginary 15 s one on a 0:15 board, played in real time (R5-DR2, the owner's call).
--
-- `/dr sim` is the library's sim grammar (LibKa0s-Sim-1.0 RunVerb), as `/mm sim` is: a bare line opens
-- the step panel idle (the scenario dropdown and Start, the steps previewed, nothing run); Start (or
-- `/dr sim start <scenario>`, or the bare `/dr sim <scenario>`) starts the session, whose prepare turns
-- the preview on (Preview.Start) and arms the sample race.
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
-- best on its board (the player's spec, the target type, 0:15); `first` races a board with no runs.
-- `tail` and `combatEnd` are seconds after the buzzer; `sticky` holds combat past race.hintDelay.
Sim.SCENARIOS = {
    { key = "newbest", label = "New best", factor = 1.04, tail = 3.1, combatEnd = 4.2, desc = "beats the best" },
    { key = "behind", label = "Behind the best", factor = 0.93, tail = 2.4, combatEnd = 5.2,
      desc = "complete, behind the best" },
    { key = "first", label = "First race", category = "boss", tail = 1.8, combatEnd = 3.6,
      desc = "the first race on its board: no best, no pace bar" },
    { key = "incomplete", label = "Incomplete", factor = 0.96, status = "incomplete", endAt = 9,
      desc = "combat ends before the buzzer" },
    { key = "died", label = "You die", factor = 0.90, status = "incomplete", endAt = 6, died = true,
      desc = "you die mid-race" },
    { key = "flagged", label = "Late cast", factor = 0.98, tail = 2.8, combatEnd = 4.6, late = { { t = 1.4 } },
      desc = "a late cast after the buzzer" },
    { key = "shared", label = "Shared session", factor = 0.99, tail = 3.4, combatEnd = 4.8, shared = true,
      desc = "a shared session: no chart, no pace bar" },
    { key = "sticky", label = "Combat holds on", factor = 0.97, tail = 2.6, sticky = true,
      desc = "combat holds on: the drop-combat hint" },
}
Sim.DEFAULT = "newbest"
-- The sample race's length (R5-DR2): an imaginary 15 s race, not a preset; its history is raced on it.
Sim.LENGTH = 15
-- How long the armed body holds before the sample race's clock starts (with no step panel).
Sim.ARM_HOLD = 3
-- How long the result card holds before the Results window opens on the sim's run.
Sim.RESULT_HOLD = 4
-- How long past the hint's delay a sticky combat lasts.
Sim.STICKY_EXTRA = 3
-- How often the clock moves the sample race on (the HUD's own tick, modules/Hud.lua).
Sim.TICK = 0.05

-- The pace of a playing stepper (SG-SIM): the seconds between two steps, the `sim.stepDelay` setting.
-- The range and the validator are the row's (settings/Race.lua).
Sim.STEP_DELAY = NS.defaults.profile.sim.stepDelay
Sim.STEP_DELAY_MIN, Sim.STEP_DELAY_MAX, Sim.STEP_DELAY_STEP = 0.5, 10, 0.5

local ticker, sample, scenario, resultAt, finished, history, quiet, racing, buzzed, carded, keepPanel

--- Whether `v` is a pace the setting takes.
function Sim.ValidStepDelay(v)
    if type(v) ~= "number" or v ~= v or v < Sim.STEP_DELAY_MIN or v > Sim.STEP_DELAY_MAX then return false end
    local n = v / Sim.STEP_DELAY_STEP
    return n == math.floor(n)
end

--- The seconds between two steps now: the stored setting, read at each step, else the default.
function Sim.StepDelay()
    local v = NS.GetSetting and NS.GetSetting("sim.stepDelay")
    if Sim.ValidStepDelay(v) then return v end
    return Sim.STEP_DELAY
end

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

--- The sim's sample history: the made-up runs, their LENGTH rows raced on the sim's 0:15 board.
function Sim.Dataset() return MockRuns.Dataset({ length = Sim.LENGTH }) end

local function combatEnd(s)
    if not s.sticky then return s.combatEnd end
    return (tonumber(NS.GetSetting("race.hintDelay")) or 0) + Sim.STICKY_EXTRA
end

--- The sample race scenario `key` runs against `dataset` (MockRuns.Race's sample), on the dataset's
--- board length (the sim's Sim.LENGTH, test mode's MockRuns.LENGTH).
--- @param key string
--- @param dataset table  the sample history (MockRuns.Dataset's)
--- @return table sample
function Sim.Sample(key, dataset)
    local s = find(key) or find(Sim.DEFAULT)
    local category = s.category or "single"
    local runs, length = dataset.runs, dataset.length or MockRuns.LENGTH
    local best = MockRuns.BoardBest(runs, category, length)
    local dps = best and s.factor and best.result.dps * s.factor or MockRuns.DPS
    return MockRuns.Race({ id = "sim-" .. s.key, category = category, length = length, dps = math.floor(dps),
                           status = s.status,
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

-- Put the sample race at its arm and start the clock: Enter's job, for every start (the session's
-- prepare, its Restart's included, and the headless start).
local function launch(key)
    cancelTicker()
    local s = find(key) or find(Sim.DEFAULT)
    scenario = s.key
    sample, resultAt, finished = Sim.Sample(s.key, history), nil, false
    racing, buzzed, carded = false, false, false
    -- With the stepper open the arm is parked until its first step (SG-DR-1); without it the old hold.
    NS.SampleRace.Start(sample, Sim.ARM_HOLD, Sim.session ~= nil)
    ticker = C_Timer.NewTicker(Sim.TICK, beat)
end

-- ── the stepper (SF-DR-8) ───────────────────────────────────────────────────────────────────────
-- LibKa0s-Sim-1.0's step window beside the race window. The race plays on its own clock, in real
-- time, and by its own plan (R5-DR2). Armed releases the parked arm, its zero a step delay ahead; Race
-- starts jumps the clock to zero. Racing does not jump: the race plays to its own buzzer (or early
-- end), the countdown one number a second, and the gate (Sim.Gate) holds every later step until the
-- race has got there, as MultiMeters' fight steps hold theirs. After the Buzzer step it holds until the
-- race reads its result (Stop!, the tail, the combat end and the quiet before the read, at real speed),
-- and after the Result card step until the card has shown for RESULT_HOLD. Result card's
-- SkipToResult is left for a click ahead. The session fakes no client answer (core/SimSetup.lua).

local STEP_MOMENTS = {
    -- The countdown is one step delay, so "Race starts" lights as the clock passes zero (SG-SIM).
    armed = function() NS.SampleRace.Unpark(Sim.StepDelay()) end,
    start = function() NS.SampleRace.Skip(0) end,
    race = function()
        NS.SampleRace.Skip(0)
        racing = true
    end,
    buzzer = function()
        NS.SampleRace.Skip(NS.SampleRace.StopAt() or 0)
        buzzed = true
    end,
    result = function()
        NS.SampleRace.SkipToResult()
        if NS.SampleRace.State() == NS.Race.STATE.RESULT then resultAt = resultAt or GetTime() end
        carded = true
    end,
    results = function() if not finished then Sim.Finish() end end,
}

local function timeline(_, opts)
    local s = find(opts.scenario) or find(Sim.DEFAULT)
    local stopLabel = s.endAt and L["Combat ends"] or L["Buzzer"]
    local raceLabel = L["Racing (%d s)"]:format(s.endAt or Sim.LENGTH)
    return {
        { kind = "armed", label = L["Armed"] },
        { kind = "start", label = L["Race starts"] },
        { kind = "race", label = raceLabel },
        { kind = "buzzer", label = stopLabel },
        { kind = "result", label = L["Result card"] },
        { kind = "results", label = L["Results window"] },
    }
end

--- The stepper's gate (R5-DR2): closed, with its line, while the Racing step's race is still running,
--- while the race after the Buzzer step has yet to read its result, and while the result card after
--- its step has shown for less than RESULT_HOLD; open otherwise.
--- @return boolean open
--- @return string|nil line
function Sim.Gate()
    if not sample then return true end
    local state, STATE = NS.SampleRace.State(), NS.Race.STATE
    if racing and state == STATE.RUNNING then return false, L["The race is still running."] end
    if buzzed and state == STATE.STOPPING then
        local s = find(scenario)
        if s and s.sticky then return false, L["Waiting for the result (combat holds on)."] end
        return false, L["Waiting for the result."]
    end
    if carded and not finished and state == STATE.RESULT and resultAt and GetTime() - resultAt < Sim.RESULT_HOLD then
        return false, L["The result card holds."]
    end
    return true
end

local function playStep(step)
    STEP_MOMENTS[step.kind]()
    NS.Hud.MeterUpdated()
    return step.label
end

-- The scenario lines the library's usage ends with (an unknown word, R5-DR2).
local function usageLines()
    local out = {}
    for i, s in ipairs(Sim.SCENARIOS) do out[i] = L["  %s: %s"]:format(s.key, L[s.desc]) end
    return out
end

-- The session's prepare (Start, the panel's Start, Restart): the preview on in sim mode, the sample
-- race armed, the panel shown. Preview.Start's `session` start leaves the session it is building alone.
local function prepare(_, _, opts, ready)
    if not NS.Preview.Start({ mode = "sim", scenario = opts.scenario, session = true }) then
        return Sim.session:Stop("refused")
    end
    Sim.session:ShowPanel()
    ready()
end

local function newSession()
    local lib = NS.SimLib
    if not (lib and lib.New) then return nil end
    local names, defs = {}, {}
    for i, s in ipairs(Sim.SCENARIOS) do
        names[i] = s.key
        defs[s.key] = { label = L[s.label], timeline = timeline }
    end
    return lib:New({
        name = "DpsRace",
        seam = NS.SimSeam,
        slash = NS.SLASH .. " sim",
        deliver = function() return 0 end,
        isStoodDown = function() return NS.IsStoodDown() end,
        scenarios = { names = names, defs = defs },
        -- The sample race is the world; a fresh session (the panel's Restart) plays it again.
        prepare = prepare,
        play = playStep,
        gate = function() return Sim.Gate() end,
        -- Preview's own refusals (combat, a real race on); the library checks the stand-down after.
        refusal = function() return NS.Preview.Refusal() end,
        usage = usageLines(),
        stepDelay = function() return Sim.StepDelay() end,
        print = function(line) if not quiet then NS.Print(line) end end,
        panel = {
            title = function() return L["DPS Race - Simulation"] end,
            anchorTo = function() return NS.Hud.Frame() end,
        },
    })
end

--- The stepper's session, or nil with no LibKa0s-Sim-1.0.
Sim.session = newSession()
-- The stepper's own Stop (reason "stop") ends the preview as well: the ticker and the race are Sim's, not
-- the session's. Sim.Cancel's stopSession runs quiet and a Restart's reason is "restart", so neither re-enters.
-- The panel stays open on its idle picker, as /mm sim's does (R5-DR2); every other end hides it.
if Sim.session then
    Sim.session:OnStop(function(_, reason)
        if quiet or reason ~= "stop" or not NS.Preview.IsActive() then return end
        keepPanel = true
        NS.Preview.Stop()
        keepPanel = false
    end)
end
-- Every start and stop (the slash verb, the panel, the launcher, its own end) repaints an open
-- settings page, so Master controls' Sim mode box shows the live sim (R6-SIM, LibKa0s R6-SIM-L).
if Sim.session then
    Sim.session:AddListener(function()
        local H = NS.Helpers
        if H and type(H.RefreshScalars) == "function" then H.RefreshScalars() end
    end)
end
NS.SimSession = Sim.session

local function stopSession(reason)
    local session = Sim.session
    if not session then return end
    quiet = true
    if session:IsActive() then session:Stop(reason) end
    if not keepPanel then session:HidePanel() end
    quiet = false
end

--- Start scenario `key` (the default when it names none) through the session: a live one ends quietly
--- first, so the sim switches in place. `arm` plays it as the typed `start` does (the panel's Start);
--- without it the session waits for its first step, as the member's Start does.
--- @return boolean started
function Sim.Open(key, arm)
    local session = Sim.session
    local s = find(key) or find(Sim.DEFAULT)
    local line = NS.Preview.Refusal()
    if line then
        NS.Print(line)
        return false
    end
    stopSession("switch")
    if arm then return (session:RunVerb("start " .. s.key)) == true end
    return (session:Start({ scenario = s.key })) == true
end

--- Play scenario `key` against `data`'s history: the preview shell's sim start, which has already
--- checked it may start (and, with a session, is that session's prepare).
function Sim.Enter(key, data)
    history = data
    launch(key)
end

--- The script's end for the stepper's last step: the Results window on the sim's run.
function Sim.Finish()
    if sample then finish() end
end

--- Stop the script where it is (the preview's stop and switch). `keepSession` (the session's own
--- prepare switching the preview to it) leaves the session alone.
function Sim.Cancel(keepSession)
    cancelTicker()
    if not keepSession then stopSession("stop") end
    sample, scenario, resultAt, finished, history = nil, nil, nil, false, nil
    racing, buzzed, carded = false, false, false
end

--- What the sim is doing, for the diagnostics report and the suites.
function Sim.Diagnose()
    local phase = "none"
    if sample then phase = finished and "results" or NS.Hud.Diagnose().body end
    return { scenario = scenario or "none", phase = phase, ticking = ticker ~= nil }
end

--- The usage line with no library session (the headless path): every scenario, the default first.
function Sim.Usage()
    return L["Usage: %s sim [%s]"]:format(NS.SLASH, table.concat(Sim.Names(), "|"))
end
