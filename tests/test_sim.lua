-- tests/test_sim.lua — modules/Sim.lua, `/dr sim [scenario]` (B5): a whole sample race through the
-- race's own views and messages, then the Results window on the sim's run beside the sample history;
-- each scenario reaches its bodies and its result, nothing reaches SavedVariables or NS.Race, and the
-- preview's end conditions end it.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local function fixture()
    local W
    local f = RaceClock.new{ mutate = function(m) W = Widgets.install(m) end }
    f.W, f.Hud, f.Preview, f.Sim, f.R = W, f.NS.Hud, f.NS.Preview, f.NS.Sim, f.NS.Results
    return f
end

local function ui(f) return assert(f.Hud.__ui(), "the HUD window was never built") end
local function current(f) return ui(f).current end

local function bare(M)
    local out = {}
    for i, l in ipairs(M.__printed()) do out[i] = (l:gsub("^|cff00ffff%[DR%]|r ", "")) end
    return out
end

local function sim(f, scenario, parked)
    assertTrue(f.Preview.Start({ mode = "sim", scenario = scenario }))
    if not parked then f.NS.SampleRace.Unpark(f.NS.Sim.ARM_HOLD) end   -- SG-DR-1: the stepper parks the arm
end

-- Play the script to its end, a tenth at a time: the bodies seen, in order.
local function play(f, secs)
    local seen, last = {}, nil
    for _ = 1, (secs or 60) * 10 do
        f.Hud.Tick()
        local key = current(f)
        if key ~= last then
            seen[#seen + 1] = key
            last = key
        end
        f:advance(0.1)
    end
    return table.concat(seen, ",")
end

local function chips(f) return ui(f).body.result.w.chips:Texts() end

test("sim: each scenario plays its bodies, then opens the Results window on its run, never storing it", function()
    local want = {
        newbest = "armed,running,stop,waiting,result", behind = "armed,running,stop,waiting,result",
        first = "armed,running,stop,waiting,result", flagged = "armed,running,stop,waiting,result",
        shared = "armed,running,stop,waiting,result", sticky = "armed,running,stop,waiting,result",
        incomplete = "armed,running,waiting,result", died = "armed,running,waiting,result",
    }
    for _, key in ipairs(T.NS.Sim.Names()) do
        local f = fixture()
        local saved = 0
        f.NS.NewBusTarget():RegisterMessage(f.NS.MSG.RUN_SAVED, function() saved = saved + 1 end)
        sim(f, key)
        assertEqual(f.Preview.Mode(), "sim", key)
        assertEqual(play(f, key == "sticky" and 80 or 60), want[key], key)
        assertEqual(f.Sim.Diagnose().phase, "results", key)
        assertEqual(f.Sim.Diagnose().ticking, false, key .. ": the script kept ticking")
        assertTrue(f.R.IsShown(), key .. ": no Results window")
        assertEqual(f.R.Selected(), "sim-" .. key, key)
        assertTrue(f.NS.ResultsSource.Get("sim-" .. key) ~= nil, key)
        assertEqual(f.NS.ResultsSource.All()[1].id, "sim-" .. key, key .. ": the newest run")
        assertEqual(f.Hud.Diagnose().events, "idle", key .. ": a sample race hears no client meter event")
        assertEqual(current(f), "result", key .. ": the HUD keeps the result card")
        assertTrue(f.Preview.IsActive(), key .. ": the sim stays on until turned off")
        assertEqual(saved, 0, key)
        assertEqual(next(f.NS.db.global.runs), nil, key .. ": a sim run reached the store")
        assertEqual(next((f.NS.db.global.loadouts or {}).gear or {}), nil, key)
        assertEqual(f.Race.State(), "idle", key .. ": the race engine moved")
    end
end)

test("sim: newbest beats the history's best: the chart and pace bar against it, a New best chip", function()
    local f = fixture()
    sim(f, "newbest")
    f:advance(3 + 10)
    local w = ui(f).body.running.w
    assertTrue(w.chart.shown)
    assertEqual(w.chart.note.__text, "vs best pace")
    assertTrue(w.pace.bar:IsShown())
    f:advance(30)
    assertEqual(current(f), "result")
    assertTrue(chips(f)[1]:find("New best +", 1, true) ~= nil, chips(f)[1])
    assertTrue(ui(f).body.result.w.pace.bar:IsShown())
    f:advance(10)
    local d = f.R.__ui().detail
    assertEqual(d.run.id, "sim-newbest")
    assertTrue(d.chartView ~= nil, "the sim's run has its chart in the detail")
    local other, kind = d:CompareTarget(true)
    assertEqual(kind, "runnerUp", "the new best compares with the old one")
    assertEqual(other.id, "sample-01")
end)

test("sim: behind finishes under the best with a minus chip", function()
    local f = fixture()
    sim(f, "behind")
    f:advance(3 + 30 + 9)
    assertEqual(current(f), "result")
    assertTrue(chips(f)[1]:find("vs best", 1, true) ~= nil and chips(f)[1]:sub(1, 1) == "-", chips(f)[1])
end)

test("sim: first races a board with no best: the chart on its own scale, no pace bar", function()
    local f = fixture()
    sim(f, "first")
    f:advance(3 + 10)
    local w = ui(f).body.running.w
    assertTrue(w.chart.shown)
    assertEqual(w.chart.note.__text, "first race on this board")
    assertFalse(w.pace.bar:IsShown(), "a pace bar with no best")
    f:advance(30)
    assertEqual(chips(f)[1], "New best")
    assertFalse(ui(f).body.result.w.pace.bar:IsShown())
end)

test("sim: shared draws no chart and no pace bar, live or on the card", function()
    local f = fixture()
    sim(f, "shared")
    f:advance(3 + 10)
    local w = ui(f).body.running.w
    assertFalse(w.chart.shown)
    assertFalse(w.pace.bar:IsShown())
    f:advance(30)
    assertEqual(current(f), "result")
    assertFalse(ui(f).body.result.w.chart.shown)
    assertFalse(ui(f).body.result.w.pace.bar:IsShown())
    f:advance(10)
    assertEqual(f.R.__ui().detail.chartView, nil, "a shared session's run has no chart")
end)

test("sim: flagged shows the late cast after the buzzer and on the card", function()
    local f = fixture()
    sim(f, "flagged")
    f:advance(3 + f.Sim.LENGTH + 2)
    f.Hud.Tick()
    assertEqual(current(f), "stop")
    local stop = ui(f).body.stop.w.chips:Texts()
    assertTrue(stop[1]:find("1 late cast", 1, true) ~= nil, stop[1])
    f:advance(10)
    assertEqual(current(f), "result")
    local found = false
    for _, text in ipairs(chips(f)) do
        if text:lower():find("late", 1, true) then found = true end
    end
    assertTrue(found, table.concat(chips(f), " | "))
end)

test("sim: incomplete and died end before the buzzer and read out of combat", function()
    for _, key in ipairs({ "incomplete", "died" }) do
        local f = fixture()
        sim(f, key)
        local endAt
        for _, s in ipairs(f.Sim.SCENARIOS) do
            if s.key == key then endAt = s.endAt end
        end
        f:advance(3 + endAt + 1)
        assertEqual(current(f), "waiting", key)
        assertEqual(ui(f).body.waiting.w.hint:IsShown(), false, key .. ": a drop-combat hint out of combat")
        f:advance(3)
        assertEqual(current(f), "result", key)
        f:advance(10)
        local run = f.NS.ResultsSource.Get("sim-" .. key)
        assertEqual(run.status, "incomplete", key)
        local top = f.NS.ResultsRuns.MaxDps(f.NS.ResultsSource.All())
        assertEqual((f.NS.ResultsRuns.Status(run, top)), key, key)
    end
end)

test("sim: the end conditions: combat, arming a real race, the switch; refused in combat and in a race", function()
    local f = fixture()
    sim(f)
    assertEqual(f.Preview.Diagnose().scenario, "newbest", "the default scenario")
    f:advance(8)
    f.M.__resetPrinted()
    f.M.__inCombat = true
    f.M.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(f.Preview.IsActive())
    assertEqual(bare(f.M)[1], "Test mode ended: you entered combat.")
    assertEqual(f.Sim.Diagnose().ticking, false)
    assertFalse(f.NS.ResultsSource.IsMock())
    f.M.__resetPrinted()
    assertFalse(f.Preview.Start({ mode = "sim" }), "a sim started in combat")
    assertEqual(#bare(f.M), 1)
    f.M.__inCombat = false

    sim(f, "behind")
    f:advance(50)
    assertTrue(f.R.IsShown())
    assertTrue(f.Race.Arm(60))
    assertFalse(f.Preview.IsActive(), "arming a real race left the sim on")
    assertFalse(f.NS.ResultsSource.IsMock())
    assertFalse(f.R.IsShown(), "the Results window the sim opened stayed open")
    f.M.__resetPrinted()
    assertFalse(f.Preview.Start({ mode = "sim" }), "a sim started during a race")
    assertEqual(#bare(f.M), 1)
    f.Race.Cancel()

    sim(f, "first")
    f:advance(5)
    assertTrue(f.NS.SetByPath("state.testMode", false))
    assertFalse(f.Preview.IsActive(), "the switch left the sim on")
    assertEqual(#f.M.__timers(), 0, "a timer outlived the sim")
end)

test("sim: closing the HUD, Reset all settings and the stand-down end a running script", function()
    local ends = {
        close = function(f) f.Hud.Act.close() end,
        resetall = function(f) f.NS.Helpers.RestoreAllDefaults() end,
        standdown = function(f) assertTrue(f.NS.SetByPath("enabled", false)) end,
    }
    for _, key in ipairs({ "close", "resetall", "standdown" }) do
        local f = fixture()
        sim(f, "newbest")
        f:advance(5)
        assertEqual(f.Sim.Diagnose().ticking, true, key .. ": the script was not ticking")
        ends[key](f)
        assertFalse(f.Preview.IsActive(), key .. " left the sim on")
        assertEqual(f.Sim.Diagnose().ticking, false, key .. ": the script kept ticking")
        assertEqual(#f.M.__timers(), 0, key .. ": a timer outlived the sim")
        assertFalse(f.NS.ResultsSource.IsMock(), key .. ": the store was not given back")
        assertEqual(next(f.NS.db.global.runs), nil, key .. ": a sim run reached the store")
    end
end)

test("sim: switching to test mode stops the script; a sim restarts in place", function()
    local f = fixture()
    sim(f, "newbest")
    f:advance(10)
    assertTrue(f.Preview.Start({ mode = "test" }))
    assertEqual(f.Preview.Mode(), "test")
    assertEqual(f.Sim.Diagnose().ticking, false)
    assertEqual(current(f), "running")
    sim(f, "died")
    assertEqual(f.Preview.Diagnose().scenario, "died")
    assertEqual(current(f), "armed", "the new sim starts at the top")
end)

test("sim: Stop Now reads as a real race's: in combat at the combat end, out of it at once; Cancel ends the sim", function()
    local f = fixture()
    sim(f, "behind")
    while current(f) ~= "stop" do f:advance(0.1) end
    ui(f).body.stop.w.stopNow:__fire("OnClick")
    assertEqual(current(f), "stop", "in combat nothing can be read")
    assertFalse(ui(f).body.stop.w.stopNow:IsEnabled(), "Stop Now, pressed, grays until the read")
    assertTrue(f.Hud.View().stopNow, "the view says it reads at the combat end")
    f:advance(5.3)
    assertEqual(current(f), "result", "read at the combat end, without the quiet")
    assertEqual(f.Race.State(), "idle", "NS.Race moved")

    local o = fixture()
    sim(o, "newbest")
    while o.NS.SampleRace.State() ~= "stopping" or o.NS.SampleRace.InCombat() do o:advance(0.1) end
    o.Hud.Act.stopNow()
    assertEqual(current(o), "result", "out of combat it reads at once")
    o:advance(o.Sim.RESULT_HOLD + 0.2)
    assertTrue(o.R.IsShown(), "the result card's hold still opens the Results window")
    assertEqual(next(o.NS.db.global.runs), nil, "a sim run reached the store")

    local g = fixture()
    sim(g, "newbest")
    while current(g) ~= "stop" do g:advance(0.1) end
    ui(g).body.stop.w.cancel:__fire("OnClick")
    assertFalse(g.Preview.IsActive(), "Cancel ends the sim")
    assertEqual(g.Sim.Diagnose().ticking, false)
end)

test("sim: the sample card's Delete asks, leaves the sample history and goes to the Arm screen", function()
    local f = fixture()
    local accept
    f.M.StaticPopup_Show = function(_, _, _, data) accept = data end
    sim(f, "newbest")
    while current(f) ~= "result" do f:advance(0.1) end
    assertTrue(ui(f).body.result.w.delete:IsEnabled(), "the card's Delete works on a sample as on a run")
    assertTrue(f.Hud.Act.delete())
    accept.onAccept(accept.id)
    assertTrue(f.R.DeleteRun(accept.id))
    assertEqual(f.NS.ResultsSource.Get("sim-newbest"), nil)
    assertEqual(current(f), "idle", "the card goes, as a real one's does")
    assertTrue(f.Preview.IsActive(), "the preview stays on")
    assertEqual(next(f.NS.db.global.runs), nil)
end)

test("sim: the sample card's Details opens its run, and Share stays refused", function()
    local f = fixture()
    sim(f, "newbest")
    while current(f) ~= "result" do f:advance(0.1) end
    local w = ui(f).body.result.w
    assertTrue(w.details:IsEnabled(), "Details works")
    f.Hud.Act.details()
    assertEqual(f.R.Selected(), "sim-newbest")
    assertFalse(w.share:IsEnabled(), "made-up numbers never reach a chat channel")
end)

test("sim: the result card draws the best's diagonal with a best before the run, and none on a first race", function()
    for key, want in pairs({ newbest = true, behind = true, first = false }) do
        local f = fixture()
        sim(f, key)
        while current(f) ~= "result" do f:advance(0.1) end
        local chart = ui(f).body.result.w.chart
        assertTrue(chart.shown, key .. ": no chart")
        for _, l in ipairs(chart.diag) do assertEqual(l:IsShown(), want, key .. ": the diagonal") end
        if want then
            local run = f.Sim and ui(f).body.result.shownRun
            assertTrue(chart.cols[1].__max > run.result.damage, key .. ": the shared max carries the headroom")
        end
    end
end)


-- ── the stepper beside the race window (SF-DR-8) ────────────────────────────────────────────────

local function stepper(f) return assert(f.NS.SimSession, "no LibKa0s-Sim-1.0 session") end

local function labels(f)
    local out = {}
    for i, st in ipairs(stepper(f):Steps()) do out[i] = st.kind end
    return table.concat(out, ",")
end

test("sim stepper: a sim starts a session whose panel docks beside the race window", function()
    local f = fixture()
    assertEqual(#f.NS.SimSeam:Unwrapped(), 0, "every Compat member is wrapped or pure")
    sim(f, "newbest")
    local s = stepper(f)
    assertTrue(s:IsActive())
    assertEqual(labels(f), "armed,start,race,buzzer,result,results")
    assertTrue(s:IsPanelShown(), "the stepper window shows with the sim")
    assertEqual(s:Status().scenario, "newbest")
    f.Preview.Stop()
    assertFalse(s:IsActive(), "turning the sim off ends the session")
    assertFalse(s:IsPanelShown())
end)

test("sim stepper: the panel's Stop ends the preview, the ticker and the sample race (SF-DR-8)", function()
    local f = fixture()
    sim(f, "newbest")
    local s = stepper(f)
    assertTrue(f.Preview.IsActive())
    assertTrue(s:Stop("stop"))
    assertFalse(f.Preview.IsActive(), "Stop on the panel turns the preview off")
    assertFalse(f.NS.Sim.Diagnose().ticking, "and the sample race stops playing")
    -- R5-DR2: as /mm sim's, the panel stays open on its idle picker.
    assertTrue(s:IsPanelShown(), "the panel's own Stop closed the panel")
    assertEqual(s:PanelRows()[1].state, "ready", "the idle panel offers Start again")
end)

-- ── R5-DR2: /dr sim opens the idle panel, as /mm sim does ─────────────────────────────────────────

test("sim panel: a bare RunVerb opens the idle panel, nothing started; Start plays the run (R5-DR2)", function()
    -- red under: /dr sim started the session from the host, so the panel opened mid-run on Resume.
    local f = fixture()
    local s = stepper(f)
    assertTrue(s:RunVerb(""))
    assertTrue(s:IsPanelShown(), "the idle panel")
    assertFalse(s:IsActive(), "a session started before Start")
    assertFalse(f.Preview.IsActive(), "the preview turned on before Start")
    assertEqual(s:PanelRows()[1].state, "ready", "the Start row waits for its press")
    f:advance(30)
    assertFalse(f.Preview.IsActive(), "something ran on an idle panel")
    assertTrue(s:RunVerb("start died"))
    assertTrue(s:IsActive())
    assertEqual(f.Preview.Mode(), "sim")
    assertEqual(f.Preview.Diagnose().scenario, "died")
    f:advance(0.1)
    assertTrue(s:Status().pos >= 1, "Start arms the run: Armed plays at once")
end)

test("sim panel: Start from test mode switches to the sim in place (R5-DR2)", function()
    -- the skeptic's trap: a prepare that called Preview's stop would end the session it is building.
    local f = fixture()
    local s = stepper(f)
    assertTrue(f.Preview.Start({ mode = "test" }))
    assertTrue(s:RunVerb(""))
    assertEqual(f.Preview.Mode(), "test", "the bare verb leaves test mode on")
    assertTrue(s:RunVerb("start newbest"))
    assertTrue(s:IsActive(), "the switch ended the session it was building")
    assertEqual(f.Preview.Mode(), "sim")
    assertEqual(current(f), "armed", "the sim's own armed body")
    assertTrue(f.Sim.Diagnose().ticking)
end)

test("sim panel: Start is refused in combat and during a real race, with Preview's line (R5-DR2)", function()
    local f = fixture()
    local s = stepper(f)
    f.M.__inCombat = true
    f.M.__resetPrinted()
    assertFalse(s:RunVerb("start newbest"))
    assertFalse(s:IsActive())
    local said = table.concat(bare(f.M), "\n")
    assertTrue(said:find("Test mode is not available in combat.", 1, true) ~= nil, said)
    f.M.__inCombat = false
    assertTrue(f.Race.Arm(60))
    assertFalse(s:RunVerb("start newbest"))
    assertFalse(f.Preview.IsActive())
    f.Race.Cancel()
end)

test("sim stepper: a restart does not end the preview (SF-DR-8)", function()
    local f = fixture()
    sim(f, "newbest")
    local s = stepper(f)
    s:Stop("restart")
    assertTrue(f.Preview.IsActive(), "the restart reason leaves the preview on")
end)

test("sim stepper: each step moves the sample race to its moment, the last opens the Results window", function()
    local f = fixture()
    sim(f, "newbest")
    local s = stepper(f)
    local Sim = f.NS.Sim
    assertEqual(f.NS.SampleRace.State(), "armed")
    assertTrue(s:Step())    -- armed: the countdown, one step delay
    assertEqual(f.NS.SampleRace.State(), "armed")
    assertTrue(s:Step())    -- the race starts
    assertEqual(f.NS.SampleRace.State(), "running")
    assertTrue(s:Step())    -- racing (R5-DR2): the race plays at real speed to its own buzzer
    assertEqual(f.NS.SampleRace.State(), "running")
    local step, code = s:Step()
    assertEqual(step, nil, "the buzzer waits out the racing step")
    assertEqual(code, "settling")
    f:advance(Sim.LENGTH + 0.5)
    assertEqual(f.NS.SampleRace.State(), "stopping", "the race reached its buzzer by itself")
    assertTrue(s:Step())    -- the buzzer
    assertEqual(f.NS.SampleRace.State(), "stopping")
    code = select(2, s:Step())
    assertEqual(code, "settling", "the result card waits for the race's own read")
    f:advance(8)
    assertEqual(f.NS.SampleRace.State(), "result", "the race read its result at real speed")
    assertTrue(s:Step())    -- the result card
    assertFalse(f.R.IsShown())
    code = select(2, s:Step())
    assertEqual(code, "settling", "the Results window waits out the card's hold")
    f:advance(Sim.RESULT_HOLD)
    assertTrue(s:Step())    -- the Results window
    assertTrue(f.R.IsShown())
    assertEqual(f.R.Selected(), "sim-newbest")
end)

test("sim stepper: an early end has no buzzer step, and switching scenarios restarts the session", function()
    local f = fixture()
    sim(f, "died")
    assertEqual(labels(f), "armed,start,race,buzzer,result,results")
    assertEqual(stepper(f):Steps()[3].label, "Racing (6 s)")
    assertEqual(stepper(f):Steps()[4].label, "Combat ends")
    sim(f, "behind")
    assertEqual(stepper(f):Status().scenario, "behind")
    assertEqual(stepper(f):Steps()[3].label, "Racing (15 s)")
    assertEqual(stepper(f):Steps()[4].label, "Buzzer")
end)


-- ── SG-DR-1, SG-SIM: the sim waits for the stepper, and its pace is the setting ───────────────────

test("sim stepper: the race holds armed until a step is played, then counts down (SG-DR-1)", function()
    local f = fixture()
    sim(f, "newbest", true)
    f:advance(f.NS.Sim.ARM_HOLD + 30)
    assertEqual(f.NS.SampleRace.State(), "armed", "nothing starts by itself")
    assertTrue(stepper(f):Step(), "the armed step")
    local d = f.NS.Sim.StepDelay()
    f:advance(d - 0.5)
    assertEqual(f.NS.SampleRace.State(), "armed")
    f:advance(1)
    assertEqual(f.NS.SampleRace.State(), "running", "the armed step starts the arm's countdown")
end)

test("sim stepper: the Armed countdown is the step delay, so Race starts lights as it ends (SG-SIM)", function()
    -- red under: ARM_HOLD (3 s) whatever the setting, so delay 5 started the race 2 s before its step.
    local f = fixture()
    f.NS.SetByPath("sim.stepDelay", 5)
    sim(f, "newbest", true)
    assertTrue(stepper(f):Step(), "the armed step")
    f:advance(4.5)
    assertEqual(f.NS.SampleRace.State(), "armed", "still counting down inside the 5 s")
    f:advance(1)
    assertEqual(f.NS.SampleRace.State(), "running")
end)

test("sim stepper: Run waits the sim.stepDelay setting between steps (SG-SIM)", function()
    local f = fixture()
    f.NS.SetByPath("sim.stepDelay", 4)
    sim(f, "newbest")
    local s = stepper(f)
    assertTrue(s:Run())
    f:advance(0.5)
    local first = s:Status().pos
    assertTrue(first >= 1, "the first step plays at once")
    f:advance(3)
    assertEqual(s:Status().pos, first, "no step inside the setting's 4 s")
    f:advance(1.5)
    assertEqual(s:Status().pos, first + 1, "the next step after it")
end)


-- ── R5-DR2: a 15 s sample race in real time ──────────────────────────────────────────────────────

-- The stepper to the moment just after its Racing step: armed, the countdown, Race starts, Racing.
local function toRacing(f, key)
    sim(f, key, true)
    local s = stepper(f)
    assertTrue(s:Step(), "the armed step")
    f:advance(f.NS.Sim.StepDelay() + 0.1)
    assertEqual(f.NS.SampleRace.State(), "running", key)
    assertTrue(s:Step(), "Race starts")
    assertTrue(s:Step(), "Racing")
    return s
end

test("sim race: an imaginary 15 s race on a 0:15 board, its history beside it (R5-DR2)", function()
    -- red under: the sample race was the 30 s board's, played three times fast.
    local f = fixture()
    local Sim, MockRuns = f.NS.Sim, f.NS.MockRuns
    assertEqual(Sim.LENGTH, 15)
    local data = Sim.Dataset()
    assertEqual(data.length, Sim.LENGTH)
    local sample = Sim.Sample("newbest", data)
    assertEqual(sample.run.race.length, 15)
    assertEqual(sample.stopAt, 15)
    assertTrue(sample.best ~= nil, "no best on the 0:15 board: Your best has nothing to show")
    assertEqual(sample.best.race.length, 15)
    assertTrue(sample.isNew, "newbest beats the board's best: the toast still shows")
    assertFalse(Sim.Sample("behind", data).isNew)
    assertEqual(Sim.Sample("first", data).best, nil, "first stays the board's first race")
    for _, key in ipairs({ "incomplete", "died" }) do
        local s = Sim.Sample(key, data)
        assertTrue(s.stopAt < 15, key .. ": its early end falls inside the race")
    end
    -- Test mode keeps the 0:30 board it always drew.
    assertEqual(MockRuns.Dataset().length, MockRuns.LENGTH)
    assertEqual(Sim.Sample("newbest", MockRuns.Dataset()).run.race.length, MockRuns.LENGTH)
end)

test("sim race: Racing plays at real speed to the buzzer, one countdown number a second (R5-DR2)", function()
    -- red under: R4-DR6 paced the race three times fast, the countdown with it.
    for _, key in ipairs({ "newbest", "died", "incomplete" }) do
        local f = fixture()
        toRacing(f, key)
        local left = f.NS.SampleRace.StopAt() - f.NS.SampleRace.Elapsed()
        f:advance(left - 0.2)
        assertEqual(f.NS.SampleRace.State(), "running", key .. ": the buzzer came early")
        f:advance(0.4)
        assertEqual(f.NS.SampleRace.State(), "stopping", key .. ": no buzzer at the race's own second")
    end
    local f = fixture()
    toRacing(f, "newbest")
    local at = {}
    for _ = 1, 160 do
        f:advance(0.1)
        local n = f.NS.Countdown.Shown()
        if n and not at[n] then at[n] = f:now() end
    end
    assertTrue(at[5] and at[1], "the final countdown played")
    local gap = (at[1] - at[5]) / 4
    assertTrue(math.abs(gap - 1) < 0.15, ("a countdown number every %.2f s"):format(gap))
    local rec = assert(f.NS.Slices.Get("sim-newbest"), "no live capture")
    assertEqual(rec.filled, rec.count, "a hole in the live chart")
end)

test("sim race: the casts keep the plan's times (R5-DR2)", function()
    local f = fixture()
    toRacing(f, "newbest")
    f:advance(20)
    local planned = {}
    for _, c in ipairs(f.Sim.Sample("newbest", f.Sim.Dataset()).plan.casts) do
        planned[math.floor(c.t * 100 + 0.5)] = true
    end
    local k = 0
    for _, c in ipairs(f.NS.Casts.Live()) do
        k = k + 1
        assertTrue(planned[math.floor(c.t * 100 + 0.5)], ("a cast at %.2f the plan never made"):format(c.t))
    end
    assertTrue(k >= 5, "the race's casts were heard")
end)

test("sim race: the gate holds the buzzer, then the read, then the card's hold (R5-DR2)", function()
    -- red under: the gate opened at the buzzer, so Result card jumped the read and the window followed in 1 s.
    local f = fixture()
    local Sim = f.NS.Sim
    sim(f, "newbest", true)
    assertTrue(Sim.Gate(), "armed: open")
    local s = toRacing(f, "newbest")
    local open, line = Sim.Gate()
    assertFalse(open, "the racing step holds the next")
    assertEqual(line, "The race is still running.")
    f:advance(Sim.LENGTH)
    assertEqual(f.NS.SampleRace.State(), "stopping")
    assertTrue(Sim.Gate(), "the buzzer step plays at the buzzer")
    assertTrue(s:Step(), "the buzzer step")
    open, line = Sim.Gate()
    assertFalse(open, "the result card waits for the read")
    assertEqual(line, "Waiting for the result.")
    local since = f.NS.SampleRace.SinceBuzzer()
    f:advance(1)
    local moved = f.NS.SampleRace.SinceBuzzer() - since
    assertTrue(math.abs(moved - 1) < 0.06, ("a second after the buzzer took %.2f race seconds"):format(moved))
    while f.NS.SampleRace.State() ~= "result" do f:advance(0.1) end
    assertTrue(Sim.Gate(), "the read opens the gate")
    assertTrue(s:Step(), "the result card")
    open = Sim.Gate()
    assertFalse(open, "the card holds before the Results window")
    f:advance(Sim.RESULT_HOLD + 0.1)
    assertTrue(Sim.Gate(), "the hold ran out")
end)

test("sim race: sticky's wait says combat holds on (R5-DR2)", function()
    local f = fixture()
    local s = toRacing(f, "sticky")
    f:advance(f.NS.Sim.LENGTH)
    assertTrue(s:Step(), "the buzzer step")
    local open, line = f.NS.Sim.Gate()
    assertFalse(open)
    assertEqual(line, "Waiting for the result (combat holds on).")
end)

test("sim race: Start plays the whole script in real time, the card held 4 s (R5-DR2)", function()
    -- red under: about 15 s end to end, the Results window a second after the card.
    local f = fixture()
    local s = stepper(f)
    assertTrue(s:RunVerb(""))
    local t0 = f:now()
    assertTrue(s:RunVerb("start newbest"))
    local cardAt, openAt
    for _ = 1, 600 do
        f:advance(0.1)
        if f.NS.SampleRace.State() == "result" and not cardAt then cardAt = f:now() - t0 end
        if f.R.IsShown() then openAt = f:now() - t0 break end
    end
    assertTrue(cardAt and openAt, "the card and the Results window came")
    local race = f.NS.Sim.LENGTH
    assertTrue(cardAt > race + 5 and cardAt < race + 10, ("the card at %.2f s"):format(cardAt))
    assertTrue(openAt - cardAt >= f.NS.Sim.RESULT_HOLD - 0.1, ("the card held %.2f s"):format(openAt - cardAt))
    assertTrue(openAt - cardAt < f.NS.Sim.RESULT_HOLD + 1.5, ("the card held %.2f s"):format(openAt - cardAt))
    assertEqual(f.R.Selected(), "sim-newbest")
    assertEqual(f.NS.SampleRace.Rate, nil, "the race clock has no pace any more")
end)
