-- tests/test_pace.lua — the pace bar's range and its tick (#3, 2026-10-25; centered in Round C):
-- *Pace bar range* (live.paceRange) driving Chart.PaceBounds, pace x (2 - m) to pace x m, the
-- on-pace tick fixed in the middle of the bar's configured width,
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

test("pace: Pace bar range defaults to 1.5, drives PaceBounds either side of the pace and is clamped to 1.1-2.0", function()
    local f = hud()
    local C = f.NS.HudChart
    local best = { race = { length = 30 }, result = { damage = 3000 } }
    assertEqual(f.NS.defaults.profile.live.paceRange, 1.5)
    assertEqual(C.PaceRange(), 1.5)
    local lo, hi = C.PaceBounds(best, 10)
    assertEqual(lo, 500, "0.5 x the best's 1000 by 0:10")
    assertEqual(hi, 1500, "1.5 x it: +-50%")
    assertTrue(f.NS.SetByPath("live.paceRange", 1.2))
    assertEqual(C.PaceRange(), 1.2)
    lo, hi = C.PaceBounds(best, 10)
    assertTrue(math.abs(lo - 800) < 1e-9 and math.abs(hi - 1200) < 1e-9, "the setting, read at call time")
    assertTrue(f.NS.SetByPath("live.paceRange", 2))
    lo, hi = C.PaceBounds(best, 10)
    assertEqual(lo, 0, "2.0: the low end at 0, never below")
    assertEqual(hi, 2000)
    lo, hi = C.PaceBounds(best, 0)
    assertEqual(lo, 0)
    assertEqual(hi, 1, "still at least lo + 1 at 0:00")
    -- A stored value outside the slider (one saved at up to 3.0 before Round C, or hand-edited) is
    -- clamped at read time.
    f.NS.db.profile.live.paceRange = 3
    assertEqual(C.PaceRange(), 2.0)
    f.NS.db.profile.live.paceRange = 9
    assertEqual(C.PaceRange(), 2.0)
    f.NS.db.profile.live.paceRange = 0.2
    assertEqual(C.PaceRange(), 1.1)
    f.NS.db.profile.live.paceRange = "x"
    assertEqual(C.PaceRange(), 1.5, "not a number: the default")
end)

test("pace: the tick sits in the middle of the bar's width, in whole pixels", function()
    local C = T.NS.HudChart
    assertEqual(C.TickX(198), 99)
    assertEqual(C.TickX(199), 100, "rounded to a whole pixel")
end)

-- ── the running HUD ─────────────────────────────────────────────────────────────────────────────

test("pace: the running bar's tick stays in the middle while its range follows Pace bar range", function()
    local f = hud()
    seedBest(f, 3000000, 30)
    running(f, 30)
    pump(f, 2)
    local b = body(f)
    local pace = b.w.pace
    assertTrue(pace.bar:IsShown())
    local barW = b.width
    assertEqual(pace.barW, barW, "the plot's whole width, from the body's configured width")
    assertEqual(pace.bar.__points[1][4], 0, "from the plot's left edge")
    assertEqual(pace.bar.__points[1][4], b.w.chart.plot.__points[1][4], "the plot's left edge")
    assertEqual(pace.barW, b.w.chart.width, "to the plot's right edge")
    assertEqual(tickX(pace), math.floor(barW / 2 + 0.5), "the middle at 1.5")
    assertTrue(f.NS.SetByPath("live.paceRange", 1.2))
    pump(f, 0.5)
    assertEqual(tickX(pace), math.floor(barW / 2 + 0.5), "still the middle at 1.2")
    local pace10 = 3000000 * f.Race.Elapsed() / 30
    assertTrue(math.abs(pace.behind.__min - 0.8 * pace10) < 1e-3, "the low end follows")
    assertTrue(math.abs(pace.ahead.__max - 1.2 * pace10) < 1e-3, "the high end follows")
    assertTrue(T.isSecret(pace.behind.__value), "the live total, straight to the bar: the bar clamps it")
    assertEqual(#f.W.SecretGeometryReads(), 0, "a geometry read on a frame holding a secret")
end)

test("pace: the bar splits at the tick: behind fills to the pace with red to the tick, ahead fills green past it", function()
    local f = hud()
    seedBest(f, 3000000, 30)
    running(f, 30)
    pump(f, 2)
    local pace = body(f).w.pace
    local x = tickX(pace)
    local function pt(region) return region.__points[1] end
    -- The halves meet at the tick, each sized from the configured width (re-placed under a spy).
    local sizes = {}
    for _, half in ipairs({ pace.behind, pace.ahead }) do
        rawset(half, "SetSize", function(self, w, h) sizes[self] = { w, h } end)
    end
    pace.tickW = nil
    pace:PlaceTick()
    assertEqual(pt(pace.behind)[4], 0)
    assertEqual(sizes[pace.behind][1], x)
    assertEqual(pt(pace.ahead)[4], x)
    assertEqual(sizes[pace.ahead][1], pace.barW - x)
    -- Each half one side of the pace: lo..pace, pace..hi; both handed the same opaque total.
    assertTrue(math.abs(pace.behind.__max - pace.ahead.__min) < 1e-9, "they meet at the pace")
    assertTrue(rawequal(pace.behind.__value, pace.ahead.__value), "one value, no comparison")
    assertTrue(T.isSecret(pace.ahead.__value))
    -- Ahead in green; the red shortfall runs from the behind fill's end to the tick.
    assertEqual(pace.ahead.__barColor[2], 0.86, "the KPI's green")
    local from, to = pace.shortfall.__points[1], pace.shortfall.__points[2]
    assertTrue(from[2] == pace.behind:GetStatusBarTexture() and from[3] == "TOPRIGHT", "from the fill's end")
    assertTrue(to[2] == pace.behind and to[3] == "BOTTOMRIGHT", "to the tick")
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

-- The KPIs, the gap, the one chip line these cases draw and the GAP under it, as the running body's
-- boxes leave theirs (modules/Hud_States.lua Chips:Bottom).
local RESULT_ROWS_TOP = 80
local BREAKDOWN = 6 + 22      -- the Spell breakdown heading and the space above it (Round C)

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
    assertEqual(pace.label, nil, "no caption: the heading's note names the bar")
    assertEqual(b.w.chart.note.__text, "vs best pace", "the heading's note")
    assertEqual(pace.barW, b.width, "the plot's whole width")
    assertEqual(pace.behind.__min, 0.5 * 1e12, "the best's damage at the run's length, less 50%")
    assertEqual(pace.ahead.__max, 1.5 * 1e12, "and plus 50%")
    assertEqual(pace.behind.__value, run.result.damage, "the plain final damage (below the range: the bar reads empty)")
    assertEqual(type(pace.behind.__value), "number")
    assertEqual(tickX(pace), math.floor(b.width / 2 + 0.5), "the same tick, in the middle")
    -- Under the Damage profile heading, above the plot: the plot and the rows move down by its line.
    assertTrue(b.w.chart.shown)
    assertEqual(b.rowsTop, RESULT_ROWS_TOP + (6 + 22 + 12 + 4 + 80 + 13 + 2 + 12 + 8) + BREAKDOWN)
    -- The range follows the setting.
    assertTrue(f.NS.SetByPath("live.paceRange", 2))
    assertEqual(pace.behind.__min, 0)
    assertEqual(pace.ahead.__max, 2 * 1e12)
    assertEqual(tickX(pace), math.floor(b.width / 2 + 0.5))
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
    assertEqual(pace.behind.__min, 1500, "0.5 x the previous best's 3000")
    assertEqual(pace.ahead.__max, 4500, "1.5 x it")
    assertEqual(pace.behind.__value, run.result.damage)
end)

test("pace: no pace bar on the result card with no earlier best, and the rows move back up", function()
    local f = hud()
    resolved(f)
    local b = body(f)
    assertFalse(b.w.pace.bar:IsShown(), "the first run on its board")
    assertEqual(b.rowsTop, RESULT_ROWS_TOP + (6 + 22 + 80 + 13 + 2 + 12 + 8) + BREAKDOWN,
        "the plot right under its heading")
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
    assertTrue(b.w.chart.title:IsShown(), "the Damage profile heading stays over the pace bar")
    assertFalse(b.w.chart.plot:IsShown())
    assertEqual(b.rowsTop, RESULT_ROWS_TOP + (6 + 22 + 12 + 4 + 8) + BREAKDOWN)
    assertTrue(b.w.list:Count() >= 3)
end)

test("pace: the sim's result card shows the pace bar against the sample best, and honors the setting", function()
    local f = hud()
    local P = f.NS.Sim
    assertTrue(f.NS.Preview.Start({ mode = "sim" }))
    f:advance(3.2)
    P.Beat()
    f:advance(41)
    P.Beat()
    assertEqual(f.Hud.__ui().current, "result")
    local pace = body(f).w.pace
    assertTrue(pace.bar:IsShown(), "the sample's result card has its pace bar")
    assertTrue(pace.behind.__value > 0 and pace.behind.__value < pace.ahead.__max, "the sample's damage inside the range")
    assertTrue(f.NS.SetByPath("live.paceBar", false))
    f.Hud.Refresh()
    assertFalse(pace.bar:IsShown(), "gone with Show pace bar")
end)

-- ── the stack (Round C) ─────────────────────────────────────────────────────────────────────────

-- `region`'s y offset (its first anchor's), down from the body's top.
local function y(region) return region.__points[1][5] end

-- Damage profile with its note, the pace bar directly under it, the plot, the time labels, then Spell
-- breakdown over the rows: every heading FONT.SECTION with the shared clear space above it.
local function assertStack(f, b, top)
    local w, F = b.w, f.NS.Style.FONT
    local title = w.chart.title
    assertEqual(title.__text, "Damage profile")
    assertEqual(title.__fontObject, F.SECTION, "the Results detail's heading role")
    assertEqual(w.spellsTitle.__text, "Spell breakdown")
    assertEqual(w.spellsTitle.__fontObject, F.SECTION)
    assertTrue(w.spellsTitle:IsShown())
    assertEqual(y(title), -(top + 6), "14px of clear space over the heading, the GAP above included")
    assertEqual(y(w.chart.note), y(title), "the note on the heading's line")
    assertEqual(y(w.pace.bar), y(title) - 22 - 2, "the pace bar directly under the heading")
    assertEqual(y(w.chart.plot), y(w.pace.bar) + 2 - 12 - 4, "the plot under the pace bar")
    assertEqual(w.chart.frameH, 80 + 13, "the plot frame: its 80px and the icon row on top")
    assertEqual(y(w.chart.axis[1]), y(w.chart.plot) - 80 - 13 - 2, "the time labels under the plot")
    assertEqual(y(w.spellsTitle), y(w.chart.axis[1]) - 12 - 8 - 6, "Spell breakdown under the time labels")
    assertEqual(-b.rowsTop, y(w.spellsTitle) - 22, "the rows under their heading")
end

test("pace: the running body stacks Damage profile, the pace bar, the plot, then Spell breakdown", function()
    local f = hud()
    seedBest(f, 3000000, 30)
    running(f, 30)
    pump(f, 2)
    local b = body(f)
    assertTrue(b.w.chart.shown and b.w.pace.bar:IsShown())
    assertStack(f, b, b.kpiBottom)
    assertEqual(b.w.chart.note.__text, "vs best pace")
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("pace: the result card stacks the same, and keeps Damage profile over the pace bar when the plot is off", function()
    local f = hud()
    seedBest(f, 1e12, 30)
    resolved(f)
    local b = body(f)
    assertTrue(b.w.chart.shown and b.w.pace.bar:IsShown())
    assertStack(f, b, RESULT_ROWS_TOP)
    assertTrue(f.NS.SetByPath("live.chart", false))
    f.Hud.Refresh()
    assertTrue(b.w.chart.title:IsShown(), "the heading stays with the pace bar")
    assertFalse(b.w.chart.plot:IsShown())
    assertEqual(b.w.chart.note.__text, "vs best pace", "the note still names the pace bar")
    assertEqual(y(b.w.spellsTitle), y(b.w.pace.bar) + 2 - 12 - 4 - 8 - 6, "Spell breakdown under the bar")
    assertTrue(f.NS.SetByPath("live.paceBar", false))
    f.Hud.Refresh()
    assertFalse(b.w.chart.title:IsShown(), "nothing to head")
    assertEqual(b.rowsTop, RESULT_ROWS_TOP + BREAKDOWN, "Spell breakdown right under the chips")
end)

test("pace: the result card's stack starts under the chips it draws, as the running body's under its boxes", function()
    local f = hud()
    seedBest(f, 1e12, 30)
    resolved(f)
    local b = body(f)
    local chips = b.w.chips
    assertEqual(chips.lines, 1, "the delta and time chips share a line")
    local top = chips:Bottom()
    assertEqual(top, 46 + 8 + 18 + 8, "the boxes, the gap, one chip line and the GAP under it: no second line held")
    assertStack(f, b, top)
    -- Chips that wrap to a second line push the stack down by that line alone.
    chips.width = 40
    chips:Set(f.NS.HudStates.ResultChips(f.Hud.View()))
    assertEqual(chips.lines, 2)
    assertEqual(chips:Bottom(), top + 18 + 5)
end)

