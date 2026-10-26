-- tests/test_chart_dots.lua — the damage chart's cooldown dots (#14, modules/Hud_Chart.lua): a gold
-- dot along the top of the plot at each cast of an ability whose base cooldown is over 15 s. The pure
-- position (Chart.DotX) and selection, then the dots drawn live on the running HUD from the race's
-- casts (no geometry read back while the columns hold secrets), on the result card and in the Results
-- detail from the run's record (with the detail's dot tooltip), in test mode, and *Show cooldown
-- dots* (live.castDots) turning them off everywhere.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local METER_EVENT = "DAMAGE_METER_COMBAT_SESSION_UPDATED"
local INFERNAL, SOUL_FIRE, CONFLAG, INCINERATE = 1122, 6353, 17962, 29722

local function near(got, want, msg)
    assertTrue(type(got) == "number" and math.abs(got - want) < 1e-6,
        (msg or "value") .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- A HUD fixture whose client knows the base cooldowns: the Infernal and Soul Fire over 15 s,
-- Conflagrate under it, Incinerate none.
local function hud()
    local W
    local f = RaceClock.new{ mutate = function(m) W = Widgets.install(m) end }
    f.W, f.Hud = W, f.NS.Hud
    f.NS.Slices.Reset()
    local cds = f.M.__baseCooldowns
    cds[INFERNAL], cds[SOUL_FIRE], cds[CONFLAG], cds[INCINERATE] = 180000, 45000, 13000, 0
    return f
end

local function body(f)
    local u = assert(f.Hud.__ui(), "the HUD window was never built")
    return u.body[u.current]
end

local function cast(f, guid, id)
    f.M.__fire("UNIT_SPELLCAST_SUCCEEDED", "player", guid, id)
end

-- `seconds` of running at 16 meter updates a second, a HUD tick on each.
local function pump(f, seconds)
    for _ = 1, math.floor(seconds * 16 + 0.5) do
        f:advance(1 / 16)
        f.M.__fire(METER_EVENT, 0, 25)
        f.Hud.Tick()
    end
end

-- Armed, a Soul Fire before the pull, then the race: the Infernal at 1 s, Conflagrate and Incinerate
-- at 2 s, Soul Fire again at 4 s. Answers the clock's start.
local function racing(f)
    assertTrue(f:arm(30))
    cast(f, "Cast-0", SOUL_FIRE)
    f:advance(1)
    f:start(25)
    local t0 = f:now()
    pump(f, 1)
    cast(f, "Cast-1", INFERNAL)
    pump(f, 1)
    cast(f, "Cast-2", CONFLAG)
    cast(f, "Cast-3", INCINERATE)
    pump(f, 2)
    cast(f, "Cast-4", SOUL_FIRE)
    pump(f, 1)
    return t0
end

local function resolved(f)
    local t0 = racing(f)
    pump(f, 25)
    f:to(t0 + 33)
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
    return f.Race.Current()
end

local function ids(dots)
    local out = {}
    for i, d in ipairs(dots) do out[i] = tostring(d.cast.id) end
    return table.concat(out, ",")
end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────────

test("chart dots: a dot's x is INSET + t / length across the width less both insets", function()
    local Chart = T.NS.HudChart
    near(Chart.DotX(0, 60, 204), 2, "the pull")
    near(Chart.DotX(30, 60, 204), 2 + 100, "half way")
    near(Chart.DotX(60, 60, 204), 202, "the buzzer")
    near(Chart.DotX(12.5, 30, 304), 2 + 12.5 / 30 * 300)
end)

test("chart dots: a pre-pull cast clamps to 0:00, one after the buzzer to the end; no length, no dot", function()
    local Chart = T.NS.HudChart
    near(Chart.DotX(-1.6, 60, 204), 2, "a cast heard while armed")
    near(Chart.DotX(64, 60, 204), 202, "a cast after the buzzer")
    assertNil(Chart.DotX(5, 0, 204))
    assertNil(Chart.DotX(5, nil, 204))
    assertNil(Chart.DotX(nil, 60, 204))
end)

test("chart dots: only casts of an ability whose base cooldown is over 15 s get one", function()
    local NS = T.NS
    local run = { casts = { v = 1, list = "-160:6353,100:1122,200:17962,210:29722,300:5,400:6353",
                            spells = { [6353] = 45000, [1122] = 180000, [17962] = 13000, [29722] = 0,
                                       [5] = 15000 } } }
    local dots = NS.HudChart.DotsOf(run)
    local got = {}
    for i, c in ipairs(dots) do got[i] = c.id end
    assertEqual(table.concat(got, ","), "6353,1122,6353", "exactly 15 s is not over it")
    assertNil(NS.HudChart.DotsOf({}), "a run with no casts recorded")
    assertNil(NS.HudChart.DotsOf({ casts = { v = 1, list = "100:29722", spells = { [29722] = 0 } } }),
        "nothing important: no dots")
end)

-- ── the running HUD ─────────────────────────────────────────────────────────────────────────────

test("chart dots: drawn live on the running HUD, along the top, with no geometry read back", function()
    local f = hud()
    racing(f)
    local chart = body(f).w.chart
    assertTrue(chart.shown, "the chart is up")
    local dots = chart:Dots()
    assertEqual(ids(dots), "6353,1122,6353", "the pre-pull Soul Fire, the Infernal and Soul Fire again")
    local Chart = f.NS.HudChart
    for _, d in ipairs(dots) do
        near(d.x, Chart.DotX(d.cast.t, 30, chart.width), "dot " .. d.cast.id)
        assertTrue(d.tex:IsShown())
        local p = d.tex.__points[1]
        assertEqual(p[1], "CENTER")
        assertTrue(p[2] == chart.over and p[3] == "TOPLEFT", "on the overlay, from the plot's top left")
        near(p[4], d.x)
        near(p[5], -(Chart.INSET + Chart.DOT / 2), "along the top")
        assertEqual(d.tex.__vertex[1], 1, "gold")
    end
    near(dots[1].x, Chart.INSET, "the pre-pull cast sits on 0:00")
    assertTrue(math.abs(dots[2].cast.t - 1) < 0.02 and math.abs(dots[3].cast.t - 4) < 0.02, "race-clock times")
    assertEqual(#f.W.SecretGeometryReads(), 0, "a geometry read on a frame holding a secret")
end)

test("chart dots: the live list is read again only when the race heard another cast", function()
    local f = hud()
    racing(f)
    local run = f.Race.Current()
    local Chart = f.NS.HudChart
    local c1 = Chart.LiveViews(run, 5, true, false, true)
    local dots = c1.dots
    assertTrue(rawequal(Chart.LiveViews(run, 6, true, false, true).dots, dots), "the same list from tick to tick")
    local chart = body(f).w.chart
    local tex = chart:Dots()[1].tex
    pump(f, 1)
    assertTrue(rawequal(chart:Dots()[1].tex, tex), "the dots were not laid again")
    cast(f, "Cast-5", INFERNAL)
    local again = Chart.LiveViews(run, 7, true, false, true).dots
    assertFalse(rawequal(again, dots), "a new cast: a new list")
    assertEqual(#again, 4)
    pump(f, 0.5)
    assertEqual(#chart:Dots(), 4, "the new dot drawn")
    assertNil(Chart.LiveViews(run, 7, true, false, false).dots, "no dots without the setting")
end)

test("chart dots: Show cooldown dots off draws none on the running HUD; on again brings them back", function()
    local f = hud()
    racing(f)
    local chart = body(f).w.chart
    assertEqual(#chart:Dots(), 3)
    assertTrue(f.NS.SetByPath("live.castDots", false))
    pump(f, 0.5)
    assertEqual(#chart:Dots(), 0, "no dots")
    for _, d in ipairs(chart.dotPool.free) do assertFalse(d:IsShown(), "a released dot stays hidden") end
    assertTrue(chart.shown, "the chart itself stays")
    assertTrue(f.NS.SetByPath("live.castDots", true))
    pump(f, 0.5)
    assertEqual(#chart:Dots(), 3)
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

-- ── after the race ──────────────────────────────────────────────────────────────────────────────

test("chart dots: the result card and the Results detail draw the run's from its record", function()
    local f = hud()
    local run = resolved(f)
    assertEqual(#f.NS.Casts.Important(run), 3)
    local card = body(f).w.chart
    assertEqual(f.Hud.__ui().current, "result")
    assertEqual(ids(card:Dots()), "6353,1122,6353", "the card")
    local R = f.NS.Results
    R.ShowRun(run.id)
    local d = R.__ui().detail.w.chart
    assertEqual(ids(d:Dots()), "6353,1122,6353", "the detail")
    for _, dot in ipairs(d:Dots()) do near(dot.x, f.NS.HudChart.DotX(dot.cast.t, 30, d.width)) end
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("chart dots: a detail dot's tooltip names the spell and when it was cast", function()
    local f = hud()
    local run = resolved(f)
    local R = f.NS.Results
    R.ShowRun(run.id)
    local chart = R.__ui().detail.w.chart
    local hits = chart.hitPool.active
    assertEqual(#hits, 3, "a hover frame over each dot")
    assertTrue(hits[1].__mouse, "it takes the mouse")
    local lines = f.NS.ResultsTips.Dot(hits[2].cast)
    assertEqual(lines[1], f.NS.HudBreakdown.SpellName(INFERNAL))
    assertEqual(lines[2], "Cast at 0:01")
    assertEqual(f.NS.ResultsTips.Dot({ t = -1.6, id = SOUL_FIRE })[2], "Cast at -0:02", "a pre-pull cast")
    assertEqual(f.NS.ResultsTips.Dot({ t = 3, id = 3110, pet = true })[1], "Spell 3110 (pet)")
    assertNil(f.NS.ResultsTips.Dot(nil))
    -- The hover shows it (the tooltip's owner is the dot's frame).
    local shown
    local real = f.NS.ResultsTable.BelowTip
    f.NS.ResultsTable.BelowTip = function(owner, l) shown = { owner = owner, lines = l } end
    hits[2]:GetScript("OnEnter")(hits[2])
    f.NS.ResultsTable.BelowTip = real
    assertTrue(shown ~= nil and shown.owner == hits[2], "the tooltip under the dot")
    assertEqual(shown.lines[2], "Cast at 0:01")
end)

test("chart dots: the HUD's dots take no mouse", function()
    local f = hud()
    racing(f)
    assertEqual(#body(f).w.chart.hitPool.active, 0, "no hover frames on the HUD")
end)

test("chart dots: Show cooldown dots off hides them on the card and in the detail too", function()
    local f = hud()
    local run = resolved(f)
    assertTrue(f.NS.SetByPath("live.castDots", false))
    assertEqual(#body(f).w.chart:Dots(), 0, "the card")
    local R = f.NS.Results
    R.ShowRun(run.id)
    local chart = R.__ui().detail.w.chart
    assertTrue(chart.shown)
    assertEqual(#chart:Dots(), 0, "the detail")
    assertEqual(#chart.hitPool.active, 0, "no hover frames either")
end)

test("chart dots: a run recorded before casts were (format 2) draws its chart with none", function()
    local f = hud()
    local run = resolved(f)
    run.casts = nil
    local R = f.NS.Results
    R.ShowRun(run.id)
    local chart = R.__ui().detail.w.chart
    assertTrue(chart.shown)
    assertEqual(#chart:Dots(), 0)
end)

-- ── test mode ───────────────────────────────────────────────────────────────────────────────────

test("chart dots: test mode draws the sample's, live up to its still moment and all on the card", function()
    local f = hud()
    assertTrue(f.NS.Preview.Start())
    local running = body(f).w.chart
    assertTrue(#running:Dots() > 0, "the sample's cooldowns so far")
    for _, d in ipairs(running:Dots()) do assertTrue(d.cast.t <= f.NS.Preview.STILL_AT, "none past the still moment") end
    f.NS.Preview.Stop()
    assertTrue(f.NS.Preview.Start({ mode = "test", state = "result" }))
    assertTrue(#body(f).w.chart:Dots() >= #running:Dots(), "the card's")
    assertTrue(f.NS.SetByPath("live.castDots", false))
    f.NS.Preview.Stop()
    assertTrue(f.NS.Preview.Start({ mode = "test", state = "result" }))
    assertEqual(#body(f).w.chart:Dots(), 0, "the setting holds in test mode")
end)

test("chart dots: test mode's chart follows Show cooldown dots while it is on screen", function()
    local f = hud()
    assertTrue(f.NS.Preview.Start())
    local chart = body(f).w.chart
    local n = #chart:Dots()
    assertTrue(n > 0, "the sample's cooldowns so far")
    local pushed = f.Hud.View().chart
    assertTrue(f.NS.SetByPath("live.castDots", false))
    f.Hud.Refresh()
    assertEqual(#chart:Dots(), 0, "the sample's dots go with the setting")
    assertTrue(chart.shown, "the chart itself stays")
    assertTrue(pushed.dots ~= nil, "the preview's own chart is not changed")
    assertTrue(f.NS.SetByPath("live.castDots", true))
    f.Hud.Refresh()
    assertEqual(#chart:Dots(), n, "on again brings them back")
end)
