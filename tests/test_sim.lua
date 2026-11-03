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
    f:advance(3 + 30 + 2)
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
    assertEqual(f.NS.SampleRace.State(), "armed")
    assertTrue(s:Step())    -- armed: nothing to do
    assertEqual(f.NS.SampleRace.State(), "armed")
    assertTrue(s:Step())    -- the race starts
    assertEqual(f.NS.SampleRace.State(), "running")
    assertTrue(s:Step())    -- racing (R4-DR6): the race plays fast to its own buzzer
    assertEqual(f.NS.SampleRace.State(), "running")
    local step, code = s:Step()
    assertEqual(step, nil, "the buzzer waits out the racing step")
    assertEqual(code, "settling")
    f:advance(f.NS.Sim.RACE_STEP_SECONDS + 0.5)
    assertEqual(f.NS.SampleRace.State(), "stopping", "the race reached its buzzer by itself")
    assertTrue(s:Step())    -- the buzzer: a marker now
    assertEqual(f.NS.SampleRace.State(), "stopping")
    assertTrue(s:Step())    -- the result card
    assertEqual(f.NS.SampleRace.State(), "result")
    assertFalse(f.R.IsShown())
    assertTrue(s:Step())    -- the Results window
    assertTrue(f.R.IsShown())
    assertEqual(f.R.Selected(), "sim-newbest")
end)

test("sim stepper: an early end has no buzzer step, and switching scenarios restarts the session", function()
    local f = fixture()
    sim(f, "died")
    assertEqual(labels(f), "armed,start,race,buzzer,result,results")
    assertEqual(stepper(f):Steps()[3].label, "Racing (12 s of damage in 10 s)")
    assertEqual(stepper(f):Steps()[4].label, "Combat ends")
    sim(f, "behind")
    assertEqual(stepper(f):Status().scenario, "behind")
    assertEqual(stepper(f):Steps()[3].label, "Racing (30 s of damage in 10 s)")
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


-- ── R4-DR6: the Racing step, MultiMeters' fight steps for a race ─────────────────────────────────

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

test("sim racing: the race step plays the race to its own buzzer in about 10 s, never before 9.5 (R4-DR6)", function()
    -- red under: no race step; the buzzer step jumped the clock (Skip) and the race stood still before it.
    for _, key in ipairs({ "newbest", "died", "incomplete" }) do
        local f = fixture()
        toRacing(f, key)
        local stopAt = f.NS.SampleRace.StopAt()
        assertTrue(f.NS.SampleRace.Rate() > 1, key .. ": the race clock runs fast")
        f:advance(9.5)
        assertEqual(f.NS.SampleRace.State(), "running", key .. ": the buzzer came early")
        assertTrue(f.NS.SampleRace.Elapsed() > stopAt - 2, key .. ": most of the race played in the step")
        f:advance(0.6)
        assertEqual(f.NS.SampleRace.State(), "stopping", key .. ": no buzzer after 10 s")
    end
end)

test("sim racing: every chart bucket fills, the casts keep the plan's times, the countdown runs (R4-DR6)", function()
    -- red under: Skip(30) at the buzzer step, which left buckets 2..29 late and shifted the casts heard after it.
    local f = fixture()
    toRacing(f, "newbest")
    local shown = {}
    for _ = 1, 105 do
        f:advance(0.1)
        local n = f.NS.Countdown.Shown()
        if n then shown[n] = true end
    end
    assertEqual(f.NS.SampleRace.State(), "stopping")
    local rec = assert(f.NS.Slices.Get("sim-newbest"), "no live capture")
    assertEqual(rec.filled, rec.count, "a hole in the live chart")
    assertTrue(shown[5] and shown[1], "the final countdown played inside the racing step")
    local planned = {}
    for _, c in ipairs(f.Sim.Sample("newbest", f.NS.MockRuns.Dataset()).plan.casts) do
        planned[math.floor(c.t * 100 + 0.5)] = true
    end
    local k = 0
    for _, c in ipairs(f.NS.Casts.Live()) do
        k = k + 1
        assertTrue(planned[math.floor(c.t * 100 + 0.5)], ("a cast at %.2f the plan never made"):format(c.t))
    end
    assertTrue(k >= 10, "the race's casts were heard")
end)

test("sim racing: after the buzzer the race runs at real speed, and the gate opens (R4-DR6)", function()
    local f = fixture()
    local Sim = f.NS.Sim
    sim(f, "newbest", true)
    assertTrue(Sim.Gate(), "armed: open")
    local s = toRacing(f, "newbest")
    local open, line = Sim.Gate()
    assertFalse(open, "the racing step holds the next")
    assertEqual(line, "The race is still running.")
    f:advance(Sim.RACE_STEP_SECONDS + 0.2)
    assertEqual(f.NS.SampleRace.State(), "stopping")
    assertEqual(f.NS.SampleRace.Rate(), 1, "Stop!, the tail and the read play at real speed")
    assertTrue(Sim.Gate(), "the buzzer opens the gate")
    local since = f.NS.SampleRace.SinceBuzzer()
    f:advance(1)
    local moved = f.NS.SampleRace.SinceBuzzer() - since
    assertTrue(math.abs(moved - 1) < 0.06, ("a second after the buzzer took %.2f race seconds"):format(moved))
    assertTrue(s:Step(), "the buzzer step")
    assertTrue(Sim.Gate())
end)

test("sim racing: Run plays the whole script, the racing step about 10 s of it (R4-DR6)", function()
    local f = fixture()
    sim(f, "newbest", true)
    local s = stepper(f)
    assertTrue(s:Run())
    local racingFrom, buzzerAt
    for _ = 1, 400 do
        f:advance(0.1)
        local pos = s:Status().pos
        if pos == 3 and not racingFrom then racingFrom = f:now() end
        if pos == 4 and not buzzerAt then buzzerAt = f:now() end
        if f.R.IsShown() then break end
    end
    assertTrue(racingFrom and buzzerAt, "the racing and buzzer steps played")
    local span = buzzerAt - racingFrom
    assertTrue(span >= 9.9 and span <= 10.5, ("the racing step took %.2f s"):format(span))
    assertTrue(f.R.IsShown(), "the Results window opened at the end")
    assertEqual(f.R.Selected(), "sim-newbest")
end)
