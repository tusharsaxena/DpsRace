-- tests/test_sim.lua — modules/Sim.lua, `/dr sim [scenario]` (B5): a whole sample race through the
-- HUD's bodies, then the Results window on the sim's run beside the sample history; each scenario
-- reaches its bodies and its result, nothing reaches SavedVariables or the race engine, and the
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

local function sim(f, scenario)
    assertTrue(f.Preview.Start({ mode = "sim", scenario = scenario }))
end

-- Play the script to its end, a tenth at a time: the bodies seen, in order.
local function play(f, secs)
    local seen, last = {}, nil
    for _ = 1, (secs or 60) * 10 do
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
        shared = "armed,running,stop,waiting,result",
        incomplete = "armed,running,waiting,result", died = "armed,running,waiting,result",
    }
    for _, key in ipairs(T.NS.Sim.Names()) do
        local f = fixture()
        local saved = 0
        f.NS.NewBusTarget():RegisterMessage(f.NS.MSG.RUN_SAVED, function() saved = saved + 1 end)
        sim(f, key)
        assertEqual(f.Preview.Mode(), "sim", key)
        assertEqual(play(f), want[key], key)
        assertEqual(f.Sim.Diagnose().phase, "results", key)
        assertEqual(f.Sim.Diagnose().ticking, false, key .. ": the script kept ticking")
        assertTrue(f.R.IsShown(), key .. ": no Results window")
        assertEqual(f.R.Selected(), "sim-" .. key, key)
        assertTrue(f.NS.ResultsSource.Get("sim-" .. key) ~= nil, key)
        assertEqual(f.NS.ResultsSource.All()[1].id, "sim-" .. key, key .. ": the newest run")
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
    f:advance(3 + 30 + 3 + 4 + 0.5)
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

test("sim: Stop Now on the Stop! or waiting body jumps the script to the result; Cancel ends the sim", function()
    for _, key in ipairs({ "stop", "waiting" }) do
        local f = fixture()
        sim(f, "newbest")
        local guard = 0
        while current(f) ~= key and guard < 600 do
            f:advance(0.1)
            guard = guard + 1
        end
        assertEqual(current(f), key)
        ui(f).body[key].w.stopNow:__fire("OnClick")
        assertEqual(current(f), "result", key .. ": Stop Now did not reach the result card")
        assertEqual(f.Sim.Diagnose().phase, "result")
        assertEqual(f.Race.State(), "idle", "the race engine moved")
        f:advance(f.Sim.RESULT_HOLD + 0.2)
        assertTrue(f.R.IsShown(), key .. ": the result card's hold still opens the Results window")
        assertEqual(next(f.NS.db.global.runs), nil, "a sim run reached the store")
    end
    local g = fixture()
    sim(g, "newbest")
    while current(g) ~= "stop" do g:advance(0.1) end
    ui(g).body.stop.w.cancel:__fire("OnClick")
    assertFalse(g.Preview.IsActive(), "Cancel ends the sim")
    assertEqual(g.Sim.Diagnose().ticking, false)
    assertFalse(g.Sim.SkipToResult(), "nothing to skip once it ended")
end)

