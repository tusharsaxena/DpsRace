-- tests/test_pace.lua — the pace bar's range and its tick (#3, 2026-10-25): *Pace bar range*
-- (live.paceRange) driving Chart.PaceMax, the on-pace tick at 1/range of the bar's configured width,
-- and the HUD result card's pace bar (the run's plain final damage against the best before it).
-- Peeled out of test_chart for layout-§1's cap.
--
-- The live cases run on the race fixture (tests/race_clock.lua) with the widget recorder
-- (tests/mock_widgets.lua), as test_chart's do.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local METER_EVENT = "DAMAGE_METER_COMBAT_SESSION_UPDATED"

local function hud()
    local W
    local f = RaceClock.new{ mutate = function(m) W = Widgets.install(m) end }
    f.W, f.Hud = W, f.NS.Hud
    f.NS.Slices.Reset()
    return f
end

local function body(f)
    local u = assert(f.Hud.__ui(), "the HUD window was never built")
    return u.body[u.current]
end

local function running(f, length)
    assertTrue(f:arm(length or 30))
    f:start(25)
    assertEqual(f.Race.State(), "running")
end

local function pump(f, seconds)
    for _ = 1, math.floor(seconds * 16 + 0.5) do
        f:advance(1 / 16)
        f.M.__fire(METER_EVENT, 0, 25)
        f.Hud.Tick()
    end
end

local function seedBest(f, damage, length)
    local best = f.NS.Recorder.NewRun(length or 30)
    best.status, best.date = "complete", 1
    best.result = { damage = damage, dps = damage / (length or 30) }
    f.NS.Recorder.Save(best)
    return best
end

-- The x offset of the tick's TOP anchor, from the bar's left edge.
local function tickX(pace)
    for _, pt in ipairs(pace.tick.__points or {}) do
        if pt[1] == "TOP" then
            assertTrue(rawequal(pt[2], pace.bar), "anchored on the bar")
            assertEqual(pt[3], "TOPLEFT", "measured from the bar's left edge")
            return pt[4]
        end
    end
    return nil
end

-- ── the range, pure ─────────────────────────────────────────────────────────────────────────────

test("pace: Pace bar range defaults to 1.5, drives PaceMax and is clamped to 1.1-3.0", function()
    local f = hud()
    local C = f.NS.HudChart
    local best = { race = { length = 30 }, result = { damage = 3000 } }
    assertEqual(f.NS.defaults.profile.live.paceRange, 1.5)
    assertEqual(C.PaceRange(), 1.5)
    assertEqual(C.PaceMax(best, 10), 1500, "1.5 x the best's 1000 by 0:10")
    assertTrue(f.NS.SetByPath("live.paceRange", 2.5))
    assertEqual(C.PaceRange(), 2.5)
    assertEqual(C.PaceMax(best, 10), 2500, "the setting, read at call time")
    assertEqual(C.PaceMax(best, 0), 1, "still at least 1 at 0:00")
    -- A stored value outside the slider (hand-edited SavedVariables) is clamped.
    f.NS.db.profile.live.paceRange = 9
    assertEqual(C.PaceRange(), 3.0)
    f.NS.db.profile.live.paceRange = 0.2
    assertEqual(C.PaceRange(), 1.1)
    f.NS.db.profile.live.paceRange = "x"
    assertEqual(C.PaceRange(), 1.5, "not a number: the default")
end)

test("pace: the tick sits at 1/range of the bar's width, in whole pixels", function()
    local C = T.NS.HudChart
    assertEqual(C.TickX(198, 1.5), 132)
    assertEqual(C.TickX(198, 2), 99, "a range of 2: the center")
    assertEqual(C.TickX(198, 3), 66)
    assertEqual(C.TickX(100, 1.1), 91, "rounded to a whole pixel")
end)

-- ── the running HUD ─────────────────────────────────────────────────────────────────────────────

test("pace: the running bar's tick follows Pace bar range, laid out from the configured width", function()
    local f = hud()
    seedBest(f, 3000000, 30)
    running(f, 30)
    pump(f, 2)
    local b = body(f)
    local pace = b.w.pace
    assertTrue(pace.bar:IsShown())
    local barW = b.width - f.NS.HudChart.PACE_LABEL_W
    assertEqual(pace.barW, barW, "the bar's width from the body's configured width")
    assertEqual(tickX(pace), math.floor(barW / 1.5 + 0.5), "two thirds along at 1.5")
    assertTrue(f.NS.SetByPath("live.paceRange", 2))
    pump(f, 0.5)
    assertEqual(tickX(pace), math.floor(barW / 2 + 0.5), "the center at 2")
    local elapsed = f.Race.Elapsed()
    assertTrue(math.abs(pace.bar.__max - 2 * 3000000 * elapsed / 30) < 1e-3, "the range follows too")
    assertEqual(#f.W.SecretGeometryReads(), 0, "a geometry read on a frame holding a secret")
end)

-- ── the result card ─────────────────────────────────────────────────────────────────────────────

-- Run to the result: 30 s with updates, the buzzer, combat over, read.
local function resolved(f)
    running(f, 30)
    pump(f, 29.5)
    f:to(130)
    f:advance(1)
    f:update(25)
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
    return f.Race.Current()
end

local RESULT_ROWS_TOP = 104   -- the KPIs, the gap and two chip lines (modules/Hud_States.lua)

test("pace: Bests.Before is the best on the run's board raced before it, whatever the run scored", function()
    local B = T.NS.Bests
    local function run(id, date, dps, length)
        return { id = id, date = date, status = "complete", char = { specID = 267 },
                 target = { category = "single" }, race = { length = length or 30 },
                 result = { damage = dps * (length or 30), dps = dps } }
    end
    local a, b, c = run("a", 1, 100), run("b", 2, 300), run("c", 3, 200)
    local other = run("o", 2, 900, 60)
    local later = run("l", 9, 999)
    local mine = run("m", 5, 500)
    local runs = { a, b, c, other, later, mine }
    assertTrue(rawequal(B.Before(mine, runs), b), "the earlier best, though the run beats it")
    assertTrue(rawequal(B.Before(c, runs), b))
    assertEqual(B.Before(a, runs), nil, "the first on its board")
    mine.status = "incomplete"
    assertTrue(rawequal(B.Before(mine, runs), b), "an incomplete run still has a best before it")
    assertEqual(B.Before(nil, runs), nil)
    local pct, isNew = B.Delta(run("n", 5, 600), runs)
    assertTrue(math.abs(pct - 100) < 1e-9, "Delta still measures against it")
    assertTrue(isNew)
end)

test("pace: the result card sets the plain final damage against the best's pace at the buzzer", function()
    local f = hud()
    seedBest(f, 1e12, 30)
    local run = resolved(f)
    local b = body(f)
    assertEqual(f.Hud.__ui().current, "result")
    local pace = b.w.pace
    assertTrue(pace.bar:IsShown(), "the pace bar on the result card")
    assertEqual(pace.label.__text, "vs best pace", "the running bar's label")
    assertEqual(pace.bar.__max, 1.5 * 1e12, "Pace bar range x the best's damage at the run's length")
    assertEqual(pace.bar.__value, run.result.damage, "the plain final damage")
    assertEqual(type(pace.bar.__value), "number")
    assertEqual(tickX(pace), math.floor((b.width - f.NS.HudChart.PACE_LABEL_W) / 1.5 + 0.5), "the same tick")
    -- Between the chips and the chart: the chart and the rows move down by the bar's line.
    assertTrue(b.w.chart.shown)
    assertEqual(b.rowsTop, RESULT_ROWS_TOP + 12 + 8 + f.NS.HudChart.BlockHeight(80) + 8)
    -- The range follows the setting.
    assertTrue(f.NS.SetByPath("live.paceRange", 2))
    assertEqual(pace.bar.__max, 2 * 1e12)
    assertEqual(tickX(pace), math.floor((b.width - f.NS.HudChart.PACE_LABEL_W) / 2 + 0.5))
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("pace: a run that just became the best is set against the previous best", function()
    local f = hud()
    seedBest(f, 3000, 30)
    local run = resolved(f)
    local _, isNew = f.NS.Bests.Delta(run)
    assertTrue(isNew, "the run beat the seeded best")
    assertTrue(rawequal(f.NS.Bests.Board()[f.NS.Bests.Key(run)], run), "it holds the board now")
    local pace = body(f).w.pace
    assertTrue(pace.bar:IsShown(), "still drawn, against the best before it")
    assertEqual(pace.bar.__max, 4500, "1.5 x the previous best's 3000")
    assertEqual(pace.bar.__value, run.result.damage)
end)

test("pace: no pace bar on the result card with no earlier best, and the rows move back up", function()
    local f = hud()
    resolved(f)
    local b = body(f)
    assertFalse(b.w.pace.bar:IsShown(), "the first run on its board")
    assertEqual(b.rowsTop, RESULT_ROWS_TOP + f.NS.HudChart.BlockHeight(80) + 8, "the chart right under the chips")
end)

test("pace: Show pace bar off, a shared session and a lost run hide the result card's bar", function()
    local f = hud()
    seedBest(f, 1e12, 30)
    local run = resolved(f)
    local b = body(f)
    assertTrue(b.w.pace.bar:IsShown())
    assertTrue(f.NS.SetByPath("live.paceBar", false))
    assertFalse(b.w.pace.bar:IsShown(), "Show pace bar off")
    assertTrue(f.NS.SetByPath("live.paceBar", true))
    assertTrue(b.w.pace.bar:IsShown(), "back on the next redraw")
    run.flags.sharedSession = true
    f.Hud.Refresh()
    assertFalse(b.w.pace.bar:IsShown(), "a shared session")
    run.flags.sharedSession = nil
    local C = f.NS.HudChart
    assertTrue(C.ResultPace(run, true) ~= nil)
    run.status = "lost"
    assertEqual(C.ResultPace(run, true), nil, "a lost run")
    assertEqual(C.ResultPace({ status = "complete", race = { length = 30 }, result = {} }, true), nil,
        "no plain damage")
end)

test("pace: at the minimum height the result card keeps its pace bar and three rows; the chart steps aside", function()
    local f = hud()
    f.NS.db.profile.windows.hud.height = f.Hud.MIN_HEIGHT
    f.NS.db.profile.live.rows = 15
    seedBest(f, 1e12, 30)
    resolved(f)
    local b = body(f)
    assertTrue(b.w.pace.bar:IsShown(), "the pace bar never steps aside")
    assertFalse(b.w.chart.shown, "no room for the chart and three rows")
    assertEqual(b.rowsTop, RESULT_ROWS_TOP + 12 + 8)
    assertTrue(b.w.list:Count() >= 3)
end)

test("pace: test mode's result card shows the pace bar against the sample best, and honors the setting", function()
    local f = hud()
    local P = f.NS.Preview
    assertTrue(P.Start())
    f:advance(3.2)
    P.Beat()
    f:advance(50)
    P.Beat()
    assertEqual(f.Hud.__ui().current, "result")
    local pace = body(f).w.pace
    assertTrue(pace.bar:IsShown(), "the sample's result card has its pace bar")
    assertTrue(pace.bar.__value > 0 and pace.bar.__value < pace.bar.__max, "the sample's damage inside the range")
    assertTrue(f.NS.SetByPath("live.paceBar", false))
    f.Hud.Refresh()
    assertFalse(pace.bar:IsShown(), "gone with Show pace bar")
end)
