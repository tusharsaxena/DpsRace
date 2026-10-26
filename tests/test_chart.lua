-- tests/test_chart.lua — the damage chart and the pace bar (#2, #3): the in-session bucket store
-- (modules/Slices.lua), the chart and pace bar widgets (modules/Hud_Chart.lua), the running HUD drawing
-- them live, the HUD result card and the Results detail drawing the chart again after the race.
--
-- The live cases run on the race fixture (tests/race_clock.lua) with the widget recorder
-- (tests/mock_widgets.lua). The meter is secret in combat, every read answering fresh opaque handles,
-- so a column is checked by IDENTITY: it must hold the very handle the first read at or after its
-- boundary answered, never a value worked out from one.

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

local function tick(f) f.Hud.Tick() end

-- Every live read the HUD makes: its race-clock time and the total it answered (an opaque handle).
local function recordReads(f)
    local reads, real = {}, f.NS.Meter.ReadLive
    f.NS.Meter.ReadLive = function()
        local live = real()
        reads[#reads + 1] = { t = f.Race.Elapsed(), total = live and live.total }
        return live
    end
    return reads
end

local function running(f, length)
    assertTrue(f:arm(length or 30))
    f:start(25)
    assertEqual(f.Race.State(), "running")
end

-- `seconds` of running at 16 meter updates a second, a countdown tick on each.
local function pump(f, seconds)
    for _ = 1, math.floor(seconds * 16 + 0.5) do
        f:advance(1 / 16)
        f.M.__fire(METER_EVENT, 0, 25)
        tick(f)
    end
end

-- The handle bucket `i` must hold: the first read at or after its boundary, when it came in time.
local function expected(reads, boundary)
    for _, r in ipairs(reads) do
        if r.t and r.t >= boundary - 1e-6 then
            if r.t - boundary <= 1.0 then return r.total end
            return nil
        end
    end
    return nil
end

-- A complete run on the board the fixture's race lands on (same spec, target and length).
local function seedBest(f, damage, length)
    local best = f.NS.Recorder.NewRun(length or 30)
    best.status, best.date = "complete", 1
    best.result = { damage = damage, dps = damage / (length or 30) }
    f.NS.Recorder.Save(best)
    return best
end

-- ── the store, pure ─────────────────────────────────────────────────────────────────────────────

test("chart: the bucket count is the length in whole seconds, at most 60", function()
    local S = T.NS.Slices
    assertEqual(S.Count(30), 30)
    assertEqual(S.Count(45.9), 45)
    assertEqual(S.Count(180), 60)
    assertEqual(S.Count(900), 60)
    assertEqual(S.Count(0.4), 1, "never none")
    assertEqual(S.Boundary(180, 60, 1), 3, "a 3:00 race: one bucket every 3 seconds")
    assertEqual(S.Boundary(180, 60, 60), 180, "the last ends on the buzzer")
end)

test("chart: a capture copies the handle into each bucket it is the first read at or after", function()
    local S = T.NS.Slices
    S.Reset()
    local run = { id = "r1", race = { length = 10 }, flags = {} }
    local h = {}
    for i = 1, 6 do h[i] = T.secret(i * 100) end
    assertEqual(S.Capture(run, 0.5, h[1]), 0, "before the first boundary: nothing")
    assertEqual(S.Capture(run, 1.0, h[2]), 1, "exactly on it")
    assertEqual(S.Capture(run, 1.3, h[3]), 0, "a later read in the same bucket changes nothing")
    local rec = S.Get("r1")
    assertTrue(rawequal(rec.values[1], h[2]), "bucket 1 holds the read at its boundary")
    -- 3.2 s: boundary 2 is 1.2 s behind (too late, left empty), boundary 3 is 0.2 s behind.
    assertEqual(S.Capture(run, 3.2, h[4]), 1)
    assertEqual(rec.values[2], nil, "a boundary noticed too late stays empty")
    assertTrue(rawequal(rec.values[3], h[4]))
    assertEqual(S.NextBoundary(run), 4)
    -- A read with no total keeps a recent boundary open for the next read.
    assertEqual(S.Capture(run, 4.1, nil), 0)
    assertEqual(S.NextBoundary(run), 4)
    assertEqual(S.Capture(run, 4.3, h[5]), 1)
    assertTrue(rawequal(rec.values[4], h[5]))
    assertEqual(rec.filled, 3)
end)

test("chart: a shared session's buckets stay empty, and the store never inspects a value", function()
    local S = T.NS.Slices
    S.Reset()
    local run = { id = "r2", race = { length = 5 }, flags = { sharedSession = true } }
    assertEqual(S.Capture(run, 1, T.secret(1)), 0)
    assertEqual(S.Get("r2").values[1], nil, "pre-arm damage cannot be netted live")
    run.flags.sharedSession = nil
    local h = T.secret(2)
    -- Every operation the kit's secret refuses (arithmetic, comparison, truth, concat) would raise here.
    local ok, err = pcall(S.Capture, run, 2, h)
    assertTrue(ok, tostring(err))
    assertTrue(rawequal(S.Get("r2").values[2], h))
end)

test("chart: Drawable answers only a scored run with slices this session", function()
    local S = T.NS.Slices
    S.Reset()
    local run = { id = "r3", status = "complete", race = { length = 5 }, flags = {}, result = { damage = 500 } }
    assertEqual(S.Drawable(run), nil, "an earlier session's run: no slices")
    S.Capture(run, 1, T.secret(1))
    assertTrue(S.Drawable(run) ~= nil)
    run.status = "lost"
    assertEqual(S.Drawable(run), nil, "a lost run")
    run.status = "incomplete"
    assertTrue(S.Drawable(run) ~= nil, "an incomplete run keeps what it captured")
    run.flags.sharedSession = true
    assertEqual(S.Drawable(run), nil, "a shared session")
    run.flags.sharedSession = nil
    run.result.damage = 0
    assertEqual(S.Drawable(run), nil, "nothing to scale to")
end)

test("chart: the pace is the best's damage spread evenly over its length", function()
    local C = T.NS.HudChart
    local best = { race = { length = 30 }, result = { damage = 3000 } }
    assertEqual(C.Pace(best, 10), 1000)
    assertEqual(C.Pace(best, 45), 3000, "clamped at the buzzer")
    assertEqual(C.Pace(best, -2), 0)
    local lo, hi = C.PaceBounds(best, 10)
    assertEqual(lo, 500, "Pace bar range 1.5 by default: half the pace")
    assertEqual(hi, 1500, "to half again: on pace in the middle")
    lo, hi = C.PaceBounds(best, 0)
    assertEqual(lo, 0)
    assertEqual(hi, 1, "a range at 0:00 all the same")
end)

test("chart: the columns sit on whole-pixel edges, touching, the configured gap taken off all but the last", function()
    local C = T.NS.HudChart
    -- The HUD's default width (300, the body's 12 px pads each side): 272 px of plot, 268 inside.
    local xs, ws = C.ColumnEdges(268, 60, 0)
    assertEqual(#xs, 60)
    local total = 0
    for i = 1, 60 do
        assertEqual(xs[i], math.floor((i - 1) * 268 / 60 + 0.5), "edge " .. i)
        assertEqual(ws[i] % 1, 0, "column " .. i .. " is whole pixels")
        if i < 60 then assertEqual(xs[i] + ws[i], xs[i + 1], "column " .. i .. " touches the next") end
        total = total + ws[i]
    end
    assertEqual(total, 268, "no pixel lost or doubled")
    assertTrue(ws[1] == 4 or ws[1] == 5, "4 or 5 px a column at 268 / 60")
    -- A gap of 2: every column but the last loses 2 px; the edges stay where they were.
    local gx, gw = C.ColumnEdges(268, 60, 2)
    assertEqual(gx[30], xs[30])
    assertEqual(gw[30], ws[30] - 2)
    assertEqual(gw[60], ws[60], "the last column keeps its span")
    -- Never narrower than 1 px.
    local _, tiny = C.ColumnEdges(30, 60, 3)
    for i = 1, 60 do assertTrue(tiny[i] >= 1) end
    assertEqual(#(C.ColumnEdges(100, 0, 0)), 0, "no columns, no edges")
end)

-- ── the running HUD ─────────────────────────────────────────────────────────────────────────────

test("chart: the columns take the Column gap setting; the plot's background its Chart background swatch", function()
    local f = hud()
    running(f, 30)
    pump(f, 1.5)
    local chart = body(f).w.chart
    for i = 1, 29 do
        assertEqual(chart.colX[i] + chart.colW[i], chart.colX[i + 1], "gap 0: column " .. i .. " touches the next")
    end
    local bg
    rawset(chart.plot, "SetBackdropColor", function(_, r, g, b, a) bg = { r, g, b, a } end)
    assertTrue(f.NS.SetByPath("appearance.chart.columnGap", 2))
    assertTrue(f.NS.SetByPath("appearance.chart.bgColor", { r = 0.1, g = 0.2, b = 0.3, a = 0.5 }))
    tick(f)
    assertEqual(chart.colX[2] - (chart.colX[1] + chart.colW[1]), 2, "the gap drawn")
    assertTrue(bg ~= nil, "the plot restyled on the change")
    assertEqual(bg[1], 0.1)
    assertEqual(bg[4], 0.5, "the swatch's alpha")
end)

test("chart: the pace bar has its own look; styling the chart's columns leaves it alone", function()
    local f = hud()
    seedBest(f, 3000000, 30)
    running(f, 30)
    pump(f, 1.5)
    local b = body(f)
    assertTrue(f.NS.SetByPath("appearance.chart.barColor", { r = 1, g = 0, b = 0, a = 1 }))
    assertTrue(f.NS.SetByPath("appearance.pace.barColor", { r = 0, g = 1, b = 0, a = 1 }))
    pump(f, 0.5)
    assertEqual(b.w.chart.cols[1].__barColor[1], 1, "the columns take the chart's color")
    assertEqual(b.w.pace.behind.__barColor[1], 0, "the pace bar does not")
    assertEqual(b.w.pace.behind.__barColor[2], 1, "the pace bar takes its own")
end)

test("chart: each column holds exactly the handle read at its boundary, and none fills early", function()
    local f = hud()
    local reads = recordReads(f)
    running(f, 30)
    pump(f, 6.5)
    local b = body(f)
    assertTrue(b.w.chart.shown, "the chart is up")
    local cols = b.w.chart.cols
    assertEqual(#cols, 30, "one column a second for a 0:30 race")
    local rec = f.NS.Slices.Get(f.Race.Current().id)
    for i = 1, 6 do
        local want = expected(reads, i)
        assertTrue(want ~= nil, "bucket " .. i .. " had a read in time")
        assertTrue(rawequal(rec.values[i], want), "the store's bucket " .. i)
        assertTrue(rawequal(cols[i].__value, want), "column " .. i .. " holds its boundary's handle")
    end
    for i = 7, 30 do
        assertEqual(rec.values[i], nil, "bucket " .. i .. " filled before its boundary")
        assertEqual(cols[i].__value, 0, "column " .. i .. " drawn before its boundary")
    end
    assertEqual(#f.W.SecretGeometryReads(), 0, "a geometry read on a frame holding a secret")
end)

test("chart: with no best the scale is the live total itself (B): no line, no diagonal, no pace bar", function()
    local f = hud()
    local reads = recordReads(f)
    running(f, 30)
    pump(f, 3.5)
    local b = body(f)
    local chart = b.w.chart
    local last = reads[#reads].total
    assertTrue(T.isSecret(chart.cols[1].__max), "the range is a secret")
    assertTrue(rawequal(chart.cols[1].__max, last), "the range is the latest live total")
    assertEqual(chart.note.__text, "first race on this board")
    assertEqual(chart.bestLine, nil, "no best line at all (the owner's call, 2026-10-25)")
    assertEqual(chart.bestLabel, nil, "no best label at all")
    for _, l in ipairs(chart.diag) do assertFalse(l:IsShown(), "a pace diagonal with no best") end
    assertFalse(b.w.pace.bar:IsShown(), "a pace bar with no best")
end)

test("chart: with a best the scale is its damage x 1.15 (A), with its pace diagonal and the pace bar", function()
    local f = hud()
    local reads = recordReads(f)
    seedBest(f, 3000000, 30)
    running(f, 30)
    pump(f, 3.5)
    local b = body(f)
    local chart = b.w.chart
    assertEqual(chart.cols[1].__max, 3000000 * 1.15, "a plain range")
    assertTrue(T.isSecret(chart.cols[1].__value), "the value is still the read's handle")
    assertEqual(chart.note.__text, "vs best pace")
    assertEqual(chart.bestLine, nil, "no gold best line")
    assertEqual(chart.bestLabel, nil, "no Best label")
    for _, l in ipairs(chart.diag) do assertTrue(l:IsShown(), "the pace diagonal") end
    -- The diagonal runs from the plot's inner corner to the best's level at the buzzer.
    local width, plotH = chart.width, chart.plotH
    local level = 2 + (plotH - 4) / 1.15
    assertEqual(#chart.diag, 1, "one solid line, not dashes (the owner's call, 2026-10-26)")
    local line = chart.diag[1]
    assertEqual(line.__thickness, 2)
    assertTrue(math.abs(line.__color[4] - 0.4) < 1e-9, "40% alpha")
    local _, _, x0, y0 = line:GetStartPoint()
    assertEqual(x0, 2)
    assertEqual(y0, 2)
    local _, _, x1, y1 = line:GetEndPoint()
    assertTrue(math.abs(x1 - (width - 2)) < 1e-6, "it runs to the plot's inner corner")
    assertTrue(math.abs(y1 - level) < 1e-6, "the diagonal climbs to the best's level")
    -- The pace bar: 0.5 to 1.5 x the best's average pace now (plain), the live total (opaque).
    local pace = b.w.pace
    assertTrue(pace.bar:IsShown())
    assertEqual(pace.label, nil, "no caption of its own: the heading's note names it")
    assertEqual(b.w.chart.note.__text, "vs best pace")
    local elapsed = f.Race.Elapsed()
    assertTrue(math.abs(pace.ahead.__max - 1.5 * 3000000 * elapsed / 30) < 1e-3, "1.5 x pace at the last redraw")
    assertTrue(math.abs(pace.behind.__min - 0.5 * 3000000 * elapsed / 30) < 1e-3, "from 0.5 x pace")
    assertTrue(rawequal(pace.behind.__value, reads[#reads].total), "the live total, untouched")
    assertTrue(pace.tick:IsShown(), "the on-pace tick")
end)

test("chart: the tick reuses the live views and rebuilds the chart's only when what decides it changes", function()
    local f = hud()
    running(f, 30)
    local run = f.Race.Current()
    local Chart = f.NS.HudChart
    local c1, p1 = Chart.LiveViews(run, 1, true, true)
    assertEqual(p1, nil, "no best: no pace bar")
    assertEqual(c1.max, nil, "scale B")
    assertTrue(rawequal(Chart.LiveViews(run, 2, true, true), c1), "the same view from tick to tick")
    -- A best saved mid-race drops the bests board: the next pass scales to it.
    seedBest(f, 3000000, 30)
    local c2, p2 = Chart.LiveViews(run, 3, true, true)
    assertFalse(rawequal(c2, c1), "rebuilt for the new best")
    assertEqual(c2.max, 3000000 * Chart.HEADROOM)
    local _, p3 = Chart.LiveViews(run, 6, true, true)
    assertTrue(rawequal(p3, p2), "one pace table")
    assertEqual(p3.lo, 0.5 * 3000000 * 6 / 30, "its ends refilled each pass")
    assertEqual(p3.hi, 1.5 * 3000000 * 6 / 30)
    -- The first bucket's capture gives the run its slices: the view follows them.
    pump(f, 1.5)
    local c4 = Chart.LiveViews(run, 7, true, true)
    assertTrue(rawequal(c4.values, f.NS.Slices.Get(run.id).values), "the run's own buckets")
end)

test("chart: hidden, with the pace bar, while the run is on a shared session", function()
    local f = hud()
    seedBest(f, 3000000, 30)
    running(f, 30)
    pump(f, 1.5)
    local b = body(f)
    assertTrue(b.w.chart.shown)
    f.Race.Current().flags.sharedSession = true
    pump(f, 1.5)
    assertFalse(b.w.chart.shown, "the chart on a shared session")
    assertFalse(b.w.pace.bar:IsShown(), "the pace bar on a shared session")
    local rec = f.NS.Slices.Get(f.Race.Current().id)
    assertEqual(rec.values[2], nil, "a bucket ended on the shared session stays empty")
end)

test("chart: Show damage chart and Show pace bar turn each off", function()
    local f = hud()
    seedBest(f, 3000000, 30)
    assertTrue(f.NS.SetByPath("live.chart", false))
    assertTrue(f.NS.SetByPath("live.paceBar", false))
    running(f, 30)
    pump(f, 1.5)
    local b = body(f)
    assertFalse(b.w.chart.shown)
    assertFalse(b.w.pace.bar:IsShown())
    assertTrue(f.NS.SetByPath("live.chart", true))
    tick(f)
    assertTrue(b.w.chart.shown, "back on the next redraw")
end)

test("chart: a quiet stretch still fills each bucket at its boundary, and the buzzer fills the last", function()
    local f = hud()
    local reads = recordReads(f)
    running(f, 30)
    -- No meter updates at all: only the bucket timers read.
    f:to(105.5)
    local rec = f.NS.Slices.Get(f.Race.Current().id)
    for i = 1, 5 do assertTrue(rawequal(rec.values[i], expected(reads, i)) and rec.values[i] ~= nil, "bucket " .. i) end
    f:to(130)
    assertEqual(f.Race.State(), "stopping")
    assertTrue(rec.values[30] ~= nil, "the buzzer's read fills the bucket that ends on it")
    assertTrue(rawequal(rec.values[30], reads[#reads].total))
    assertEqual(reads[#reads].t, 30)
    assertEqual(rec.filled, 30)
end)

test("chart: the chart steps aside at the minimum height; the rows keep their three", function()
    local f = hud()
    f.NS.db.profile.windows.hud.height = f.Hud.MIN_HEIGHT
    f.NS.db.profile.live.rows = 15
    running(f, 30)
    pump(f, 1)
    local b = body(f)
    assertFalse(b.w.chart.shown, "no room for the chart and three rows")
    assertTrue(b.w.list:Count() >= 3)
end)

test("chart: the overlay sits one band over the plot's columns", function()
    local f = hud()
    running(f, 30)
    pump(f, 1)
    local chart = body(f).w.chart
    local lay = f.M.__layers
    assertEqual(lay(chart.over).level, lay(chart.plot).level + f.NS.Constants.LAYERS.LEVEL.CHART_OVERLAY)
    assertTrue(lay(chart.cols[1]).level < lay(chart.over).level, "a column over the lines")
end)

-- ── after the race ──────────────────────────────────────────────────────────────────────────────

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

test("chart: the result card draws the race's slices to its plain final damage, and none without them", function()
    local f = hud()
    local run = resolved(f)
    local b = body(f)
    assertEqual(f.Hud.__ui().current, "result")
    assertTrue(b.w.chart.shown, "the race's chart on its result card")
    local rec = f.NS.Slices.Get(run.id)
    local col = b.w.chart.cols[10]
    assertEqual(col.__max, run.result.damage, "scaled to the plain final damage")
    assertTrue(rawequal(col.__value, rec.values[10]), "the very handle captured live")
    local BREAKDOWN = f.NS.HudStates.BREAKDOWN_H
    assertEqual(b.rowsTop, 80 + (6 + 22 + 80 + 2 + 12 + 8) + BREAKDOWN, "the rows under the chart and its heading")
    -- A /reload empties the store: the card has no chart, and its rows move back up.
    f.NS.Slices.Reset()
    f.Hud.Refresh()
    assertFalse(b.w.chart.shown)
    assertEqual(b.rowsTop, 80 + BREAKDOWN)
end)

test("chart: WithBest scales an after-the-race view to max(run, best at its length) x 1.15", function()
    local Chart = T.NS.HudChart
    local run = { id = "r", race = { length = 30 }, result = { damage = 1000 }, flags = {} }
    local best = { id = "b", race = { length = 30 }, result = { damage = 2000 } }
    local v = Chart.WithBest({ max = 1000, note = "" }, run, best)
    assertEqual(v.best, 2000, "the best's damage at this run's length: the diagonal's end")
    assertEqual(v.max, 2000 * 1.15, "the best is the larger")
    assertEqual(v.note, "vs best pace")
    v = Chart.WithBest({ max = 1000 }, run, { id = "b", race = { length = 30 }, result = { damage = 500 } })
    assertEqual(v.max, 1000 * 1.15, "the run is the larger")
    v = Chart.WithBest({ max = 1000 }, run, nil)
    assertEqual(v.max, 1000, "no best: the run's own damage, no headroom")
    assertEqual(v.best, nil, "no diagonal")
    v = Chart.WithBest({ max = 1000 }, run, run)
    assertEqual(v.best, nil, "never against itself")
    run.flags.sharedSession = true
    v = Chart.WithBest({ max = 1000 }, run, best)
    assertEqual(v.best, nil, "a shared session: no diagonal")
end)

-- Whether the diagonal ends at the level for `best` over `max` on `chart`'s plot.
local function diagonalTo(chart, best, max)
    local level = 2 + (chart.plotH - 4) * best / max
    local _, _, _, y1 = chart.diag[1]:GetEndPoint()
    return math.abs(y1 - level) < 1e-6
end

test("chart: the result card draws the earlier best's diagonal, the columns on the shared max", function()
    local f = hud()
    seedBest(f, 3000000, 30)
    local run = resolved(f)
    local b = body(f)
    local chart = b.w.chart
    assertTrue(chart.shown)
    local max = 3000000 * 1.15
    assertEqual(chart.cols[10].__max, max, "the columns use the diagonal's max")
    for _, l in ipairs(chart.diag) do assertTrue(l:IsShown(), "the best's diagonal") end
    assertTrue(diagonalTo(chart, 3000000, max), "the diagonal climbs to the best's damage at the buzzer")
    assertTrue(run.result.damage < 3000000)
    -- The detail draws the same.
    local R = f.NS.Results
    R.ShowRun(run.id)
    local d = R.__ui().detail.w.chart
    assertEqual(d.cols[1].__max, max)
    for _, l in ipairs(d.diag) do assertTrue(l:IsShown(), "the detail's diagonal") end
    assertTrue(diagonalTo(d, 3000000, max))
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("chart: the earlier best deleted while the card is up drops its diagonal and the shared max", function()
    local f = hud()
    local best = seedBest(f, 3000000, 30)
    local run = resolved(f)
    local chart = body(f).w.chart
    assertEqual(chart.cols[10].__max, 3000000 * 1.15)
    f.NS.Recorder.Delete(best.id)
    assertEqual(f.Race.State(), "result", "the card's own run is still stored")
    chart = body(f).w.chart
    for _, l in ipairs(chart.diag) do assertFalse(l:IsShown(), "the deleted best's diagonal") end
    assertEqual(chart.cols[10].__max, run.result.damage, "back on the run's own damage")
    assertEqual(body(f).w.chips:Texts()[1], "New best", "the delta chip names no best")
end)

test("chart: with no earlier best the result card and the detail draw no diagonal", function()
    local f = hud()
    local run = resolved(f)
    local chart = body(f).w.chart
    for _, l in ipairs(chart.diag) do assertFalse(l:IsShown(), "a diagonal with no earlier best") end
    assertEqual(chart.cols[10].__max, run.result.damage)
    local R = f.NS.Results
    R.ShowRun(run.id)
    for _, l in ipairs(R.__ui().detail.w.chart.diag) do assertFalse(l:IsShown()) end
end)

test("chart: the Results detail shows the chart for a run raced this session only", function()
    local f = hud()
    local run = resolved(f)
    local R = f.NS.Results
    R.ShowRun(run.id)
    local d = R.__ui().detail
    assertTrue(d.w.chart.shown, "this session's run has its chart")
    assertEqual(d.w.chart.cols[1].__max, run.result.damage)
    local lines = f.NS.ResultsTips.Detail("chart", run)
    assertEqual(lines[1], "Damage profile", "the chart has a tooltip")
    -- An earlier session's run (after a /reload): no section at all.
    f.NS.Slices.Reset()
    R.ShowRun(run.id)
    assertFalse(d.w.chart.shown, "a run from before the reload has no chart")
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("chart: the detail's title hover goes with its chart, so it never covers the section under it", function()
    local f = hud()
    local run = resolved(f)
    local R = f.NS.Results
    R.ShowRun(run.id)
    local d = R.__ui().detail
    assertTrue(d.w.chartTitleHover:IsShown(), "the title's hover while the chart shows")
    -- A run with no slices: the title keeps its old anchors, so its hover must hide with it.
    f.NS.Slices.Reset()
    R.ShowRun(run.id)
    assertFalse(d.w.chart.shown)
    assertFalse(d.w.chartTitleHover:IsShown(), "no stray chart tooltip over the timing header")
end)

test("chart: a lost run has no chart on the card or in the detail", function()
    local f = hud()
    running(f, 30)
    pump(f, 3)
    local run = f.Race.Current()
    assertTrue(f.NS.Slices.Get(run.id).filled > 0)
    f.Race.OnMeterReset()
    assertEqual(run.status, "lost")
    assertEqual(f.NS.HudChart.ResultView(run), nil)
    f.Hud.Refresh()
    assertEqual(f.Hud.__ui().current, "result", "the lost run's card")
    assertFalse(body(f).w.chart.shown, "no chart on the lost run's card")
    local R = f.NS.Results
    R.ShowRun(run.id)
    assertFalse(R.__ui().detail.w.chart.shown, "no chart in the lost run's detail")
end)

-- ── test mode ───────────────────────────────────────────────────────────────────────────────────

test("chart: test mode's still running body draws the sample's chart against the sample history's best", function()
    local f = hud()
    assertTrue(f.NS.Preview.Start())
    local b = body(f)
    assertEqual(f.Hud.__ui().current, "running")
    assertTrue(b.w.chart.shown)
    assertTrue(b.w.pace.bar:IsShown())
    assertEqual(b.w.chart.note.__text, "vs best pace")
    assertTrue(type(b.w.chart.cols[5].__value) == "number" and b.w.chart.cols[5].__value > 0, "plain sample numbers")
    local after = b.w.chart.cols[f.NS.Preview.STILL_AT + 1].__value
    assertTrue(after == nil or after == 0, "a still moment: nothing past it")
end)

test("chart: the sim draws the sample's chart live against a best, then on its result card", function()
    local f = hud()
    local Sim = f.NS.Sim
    assertTrue(f.NS.Preview.Start({ mode = "sim", scenario = "newbest" }))
    f:advance(3.2)
    Sim.Beat()
    f:advance(10)
    Sim.Beat()
    local b = body(f)
    assertEqual(f.Hud.__ui().current, "running")
    assertTrue(b.w.chart.shown)
    assertTrue(b.w.pace.bar:IsShown())
    assertEqual(b.w.chart.note.__text, "vs best pace")
    f:advance(40)
    Sim.Beat()
    assertEqual(f.Hud.__ui().current, "result")
    assertTrue(body(f).w.chart.shown, "the sample's result card has its chart")
end)

test("chart: the sim honors Show damage chart and Show pace bar", function()
    local f = hud()
    local P = f.NS.Sim
    assertTrue(f.NS.Preview.Start({ mode = "sim" }))
    f:advance(3.2)
    P.Beat()
    f:advance(10)
    P.Beat()
    local b = body(f)
    assertTrue(b.w.chart.shown)
    assertTrue(f.NS.SetByPath("live.chart", false))
    f.Hud.Refresh()
    assertFalse(b.w.chart.shown, "the sample's chart goes with the setting")
    assertTrue(b.w.pace.bar:IsShown(), "the pace bar is its own setting")
    assertTrue(f.NS.SetByPath("live.paceBar", false))
    f.Hud.Refresh()
    assertFalse(b.w.pace.bar:IsShown(), "the sample's pace bar goes with the setting")
    f:advance(40)
    P.Beat()
    assertEqual(f.Hud.__ui().current, "result")
    assertFalse(body(f).w.chart.shown, "nor on the sample's result card")
end)

-- ── diagnostics ─────────────────────────────────────────────────────────────────────────────────

test("chart: the diagnostics state section counts the loadout store and the races holding a chart", function()
    local f = hud()
    running(f, 30)
    pump(f, 2)
    local lines = {}
    local out = { add = function(_, _, fmt, ...)
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        lines[#lines + 1] = fmt:format(unpack(args, 1, select("#", ...)))
    end }
    for _, section in ipairs(f.NS.Diagnostics.Sections()) do
        if section[1] == "state" then section[2](out) end
    end
    local gear, talents = f.NS.Loadouts.Counts()
    local want = ("loadouts gear=%d talents=%d chart races=1"):format(gear, talents)
    local found = false
    for _, l in ipairs(lines) do if l == want then found = true end end
    assertTrue(found, "no loadouts line; got: " .. table.concat(lines, " | "))
end)
