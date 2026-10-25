-- tests/test_pace.lua — the pace bar's range and its tick (#3, 2026-10-25): *Pace bar range*
-- (live.paceRange) driving Chart.PaceMax, the on-pace tick at 1/range of the bar's configured width,
-- and the HUD result card's pace bar (the run's plain final damage against the best before it).
-- Peeled out of test_chart for layout-§1's cap.
--
-- The live cases run on the race fixture (tests/race_clock.lua) with the widget recorder
-- (tests/mock_widgets.lua), as test_chart's do.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
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
