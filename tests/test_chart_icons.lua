-- tests/test_chart_icons.lua — the damage chart's cooldown icons (#14, modules/Hud_Chart.lua): the
-- ability's icon along the top of the plot at each cast of an ability whose base cooldown is over
-- 15 s, a later icon that would overlap the one before it on a second row. The pure positions
-- (Chart.TimeX, IconX, IconRows, IconY) and selection, then the icons drawn live on the running HUD
-- from the race's casts (no geometry read back while the columns hold secrets), on the result card and
-- in the Results detail from the run's record, each icon's tooltip (the spell and its time) in all
-- three, test mode, and *Show cooldown icons* (live.castDots) turning them off everywhere.

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

local function ids(icons)
    local out = {}
    for i, d in ipairs(icons) do out[i] = tostring(d.cast.id) end
    return table.concat(out, ",")
end

-- Hover `frame` with ResultsTable.BelowTip caught: answers what it was handed.
local function hover(f, frame)
    local shown
    local real = f.NS.ResultsTable.BelowTip
    f.NS.ResultsTable.BelowTip = function(owner, l) shown = { owner = owner, lines = l } end
    frame:GetScript("OnEnter")(frame)
    f.NS.ResultsTable.BelowTip = real
    return shown
end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────────

test("chart icons: a cast's x is INSET + t / length across the width less both insets", function()
    local Chart = T.NS.HudChart
    near(Chart.TimeX(0, 60, 204), 2, "the pull")
    near(Chart.TimeX(30, 60, 204), 2 + 100, "half way")
    near(Chart.TimeX(60, 60, 204), 202, "the buzzer")
    near(Chart.TimeX(12.5, 30, 304), 2 + 12.5 / 30 * 300)
end)

test("chart icons: a pre-pull cast clamps to 0:00, one after the buzzer to the end; no length, no icon", function()
    local Chart = T.NS.HudChart
    near(Chart.TimeX(-1.6, 60, 204), 2, "a cast heard while armed")
    near(Chart.TimeX(64, 60, 204), 202, "a cast after the buzzer")
    assertNil(Chart.TimeX(5, 0, 204))
    assertNil(Chart.TimeX(5, nil, 204))
    assertNil(Chart.TimeX(nil, 60, 204))
    assertNil(Chart.IconX(nil, 60, 204))
end)

test("chart icons: an icon is centered on its cast's time, held inside the plot at either end", function()
    local Chart = T.NS.HudChart
    assertEqual(Chart.ICON, 12)
    near(Chart.IconX(30, 60, 204), 102, "the middle: its time")
    near(Chart.IconX(0, 60, 204), Chart.ICON / 2, "0:00: flush with the left edge")
    near(Chart.IconX(60, 60, 204), 204 - Chart.ICON / 2, "the buzzer: flush with the right edge")
    near(Chart.IconY(1), -(Chart.INSET + Chart.ICON / 2), "the top row, under the plot's edge")
    near(Chart.IconY(2), -(Chart.INSET + Chart.ICON / 2 + Chart.ICON + Chart.ICON_GAP), "the second, just below")
end)

test("chart icons: an icon that would overlap the one before it on the top row takes the second", function()
    local Chart = T.NS.HudChart
    local rows = Chart.IconRows({ 6, 10, 18, 30, 41, 44, 70 })
    -- 10 is 4 from 6: second row; 18 is 12 from 6: top; 30 top; 41 is 11 from 30: second;
    -- 44 is 14 from 30: top; 70 top.
    assertEqual(table.concat(rows, ","), "1,2,1,1,2,1,1")
    assertEqual(table.concat(Chart.IconRows({ 50, 52, 54 }), ","), "1,2,2", "a third crowded one stays on the second")
    assertEqual(#Chart.IconRows({}), 0)
end)

test("chart icons: only casts of an ability whose base cooldown is over 15 s get one", function()
    local NS = T.NS
    local run = { casts = { v = 1, list = "-160:6353,100:1122,200:17962,210:29722,300:5,400:6353",
                            spells = { [6353] = 45000, [1122] = 180000, [17962] = 13000, [29722] = 0,
                                       [5] = 15000 } } }
    local casts = NS.HudChart.CooldownsOf(run)
    local got = {}
    for i, c in ipairs(casts) do got[i] = c.id end
    assertEqual(table.concat(got, ","), "6353,1122,6353", "exactly 15 s is not over it")
    assertNil(NS.HudChart.CooldownsOf({}), "a run with no casts recorded")
    assertNil(NS.HudChart.CooldownsOf({ casts = { v = 1, list = "100:29722", spells = { [29722] = 0 } } }),
        "nothing important: no icons")
end)

-- ── the running HUD ─────────────────────────────────────────────────────────────────────────────

test("chart icons: drawn live on the running HUD, the spell's icon along the top, no geometry read back", function()
    local f = hud()
    racing(f)
    local chart = body(f).w.chart
    assertTrue(chart.shown, "the chart is up")
    local icons = chart:Icons()
    assertEqual(ids(icons), "6353,1122,6353", "the pre-pull Soul Fire, the Infernal and Soul Fire again")
    local Chart = f.NS.HudChart
    for _, d in ipairs(icons) do
        near(d.x, Chart.IconX(d.cast.t, 30, chart.width), "icon " .. d.cast.id)
        assertTrue(d.frame:IsShown())
        assertEqual(d.frame.tex.__texture, 1000 + d.cast.id, "the spell's own icon")
        local p = d.frame.__points[#d.frame.__points]
        assertEqual(p[1], "CENTER")
        assertTrue(p[2] == chart.over and p[3] == "TOPLEFT", "on the overlay, from the plot's top left")
        near(p[4], d.x)
        near(p[5], Chart.IconY(d.row), "along the top")
    end
    near(icons[1].x, Chart.ICON / 2, "the pre-pull cast sits on 0:00, flush with the edge")
    assertEqual(icons[1].row, 1)
    assertTrue(math.abs(icons[2].cast.t - 1) < 0.02 and math.abs(icons[3].cast.t - 4) < 0.02, "race-clock times")
    assertEqual(#f.W.SecretGeometryReads(), 0, "a geometry read on a frame holding a secret")
end)

test("chart icons: two casts close together on the running HUD stagger onto the second row", function()
    local f = hud()
    racing(f)
    cast(f, "Cast-5", INFERNAL)   -- at 5 s, a second after the Soul Fire at 4 s: closer than an icon
    pump(f, 0.5)
    local chart = body(f).w.chart
    local icons = chart:Icons()
    assertEqual(ids(icons), "6353,1122,6353,1122")
    assertTrue(icons[4].x - icons[3].x < f.NS.HudChart.ICON, "they would overlap")
    assertEqual(icons[3].row, 1)
    assertEqual(icons[4].row, 2, "the later one drops a row")
    near(icons[4].frame.__points[#icons[4].frame.__points][5], f.NS.HudChart.IconY(2))
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("chart icons: a running HUD icon's tooltip names the spell and its time", function()
    local f = hud()
    racing(f)
    local icons = body(f).w.chart:Icons()
    assertTrue(icons[2].frame.__mouse, "it takes the mouse on the HUD too")
    local shown = hover(f, icons[2].frame)
    assertTrue(shown ~= nil and shown.owner == icons[2].frame, "the tooltip under the icon")
    assertEqual(shown.lines[1], f.NS.HudBreakdown.SpellName(INFERNAL))
    assertEqual(shown.lines[2], "Cast at 0:01")
    -- The real tooltip, through the client's GameTooltip, reads no geometry off a secret.
    icons[2].frame:GetScript("OnEnter")(icons[2].frame)
    icons[2].frame:GetScript("OnLeave")(icons[2].frame)
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("chart icons: the live list is read again only when the race heard another cast", function()
    local f = hud()
    racing(f)
    local run = f.Race.Current()
    local Chart = f.NS.HudChart
    local c1 = Chart.LiveViews(run, 5, true, false, true)
    local casts = c1.cooldowns
    assertTrue(rawequal(Chart.LiveViews(run, 6, true, false, true).cooldowns, casts), "the same list from tick to tick")
    local chart = body(f).w.chart
    local frame = chart:Icons()[1].frame
    pump(f, 1)
    assertTrue(rawequal(chart:Icons()[1].frame, frame), "the icons were not laid again")
    cast(f, "Cast-5", INFERNAL)
    local again = Chart.LiveViews(run, 7, true, false, true).cooldowns
    assertFalse(rawequal(again, casts), "a new cast: a new list")
    assertEqual(#again, 4)
    pump(f, 0.5)
    assertEqual(#chart:Icons(), 4, "the new icon drawn")
    assertNil(Chart.LiveViews(run, 7, true, false, false).cooldowns, "no icons without the setting")
end)

test("chart icons: Show cooldown icons off draws none on the running HUD; on again brings them back", function()
    local f = hud()
    racing(f)
    local chart = body(f).w.chart
    assertEqual(#chart:Icons(), 3)
    assertTrue(f.NS.SetByPath("live.castDots", false))
    pump(f, 0.5)
    assertEqual(#chart:Icons(), 0, "no icons")
    for _, d in ipairs(chart.iconPool.free) do assertFalse(d:IsShown(), "a released icon stays hidden") end
    assertTrue(chart.shown, "the chart itself stays")
    assertTrue(f.NS.SetByPath("live.castDots", true))
    pump(f, 0.5)
    assertEqual(#chart:Icons(), 3)
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("chart icons: the setting's row reads Show cooldown icons and keeps its stored path", function()
    local f = hud()
    local row
    for _, r in ipairs(f.NS.Schema) do
        if r.path == "live.castDots" then row = r end
    end
    assertTrue(row ~= nil, "the live.castDots row")
    assertEqual(row.label, "Show cooldown icons")
    assertTrue(row.default == true)
end)

-- ── after the race ──────────────────────────────────────────────────────────────────────────────

test("chart icons: the result card and the Results detail draw the run's from its record", function()
    local f = hud()
    local run = resolved(f)
    assertEqual(#f.NS.Casts.Important(run), 3)
    local card = body(f).w.chart
    assertEqual(f.Hud.__ui().current, "result")
    assertEqual(ids(card:Icons()), "6353,1122,6353", "the card")
    local R = f.NS.Results
    R.ShowRun(run.id)
    local d = R.__ui().detail.w.chart
    assertEqual(ids(d:Icons()), "6353,1122,6353", "the detail")
    for _, icon in ipairs(d:Icons()) do
        near(icon.x, f.NS.HudChart.IconX(icon.cast.t, 30, d.width))
        assertEqual(icon.frame.tex.__texture, 1000 + icon.cast.id)
    end
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("chart icons: an icon's tooltip on the card and in the detail names the spell and when it was cast", function()
    local f = hud()
    local run = resolved(f)
    local card = body(f).w.chart:Icons()
    assertTrue(card[2].frame.__mouse, "the card's take the mouse")
    local shown = hover(f, card[2].frame)
    assertTrue(shown ~= nil and shown.owner == card[2].frame, "the tooltip under the card's icon")
    assertEqual(shown.lines[2], "Cast at 0:01")
    local R = f.NS.Results
    R.ShowRun(run.id)
    local icons = R.__ui().detail.w.chart:Icons()
    assertEqual(#icons, 3)
    local lines = f.NS.ResultsTips.Cast(icons[2].cast)
    assertEqual(lines[1], f.NS.HudBreakdown.SpellName(INFERNAL))
    assertEqual(lines[2], "Cast at 0:01")
    assertEqual(f.NS.ResultsTips.Cast({ t = -1.6, id = SOUL_FIRE })[2], "Cast at -0:02", "a pre-pull cast")
    assertEqual(f.NS.ResultsTips.Cast({ t = 3, id = 3110, pet = true })[1], "Spell 3110 (pet)")
    assertNil(f.NS.ResultsTips.Cast(nil))
    shown = hover(f, icons[2].frame)
    assertTrue(shown ~= nil and shown.owner == icons[2].frame, "the tooltip under the detail's icon")
    assertEqual(shown.lines[2], "Cast at 0:01")
    -- A released icon hovers to nothing.
    icons[2].frame.cast = nil
    assertNil(hover(f, icons[2].frame))
end)

test("chart icons: Show cooldown icons off hides them on the card and in the detail too", function()
    local f = hud()
    local run = resolved(f)
    assertTrue(f.NS.SetByPath("live.castDots", false))
    assertEqual(#body(f).w.chart:Icons(), 0, "the card")
    local R = f.NS.Results
    R.ShowRun(run.id)
    local chart = R.__ui().detail.w.chart
    assertTrue(chart.shown)
    assertEqual(#chart:Icons(), 0, "the detail")
    assertEqual(#chart.iconPool.active, 0, "no icon frames either")
end)

test("chart icons: a run recorded before casts were (format 2) draws its chart with none", function()
    local f = hud()
    local run = resolved(f)
    run.casts = nil
    local R = f.NS.Results
    R.ShowRun(run.id)
    local chart = R.__ui().detail.w.chart
    assertTrue(chart.shown)
    assertEqual(#chart:Icons(), 0)
end)

-- ── test mode ───────────────────────────────────────────────────────────────────────────────────

test("chart icons: test mode draws the sample's, live up to its still moment and all on the card", function()
    local f = hud()
    assertTrue(f.NS.Preview.Start())
    local running = body(f).w.chart
    assertTrue(#running:Icons() > 0, "the sample's cooldowns so far")
    for _, d in ipairs(running:Icons()) do assertTrue(d.cast.t <= f.NS.Preview.STILL_AT, "none past the still moment") end
    f.NS.Preview.Stop()
    assertTrue(f.NS.Preview.Start({ mode = "test", state = "result" }))
    assertTrue(#body(f).w.chart:Icons() >= #running:Icons(), "the card's")
    assertTrue(f.NS.SetByPath("live.castDots", false))
    f.NS.Preview.Stop()
    assertTrue(f.NS.Preview.Start({ mode = "test", state = "result" }))
    assertEqual(#body(f).w.chart:Icons(), 0, "the setting holds in test mode")
end)

test("chart icons: the sim's running chart keeps one cooldown list until another cast is heard", function()
    local f = hud()
    local MR = f.NS.MockRuns
    local s = MR.Race({ dps = 150000 }, MR.Dataset().runs)
    local all = assert(f.NS.HudChart.CooldownsOf(s.run), "the sample run has no cooldowns")
    assertTrue(#all >= 2 and all[2].t > all[1].t, "two casts at different times")
    local t1, t2 = all[1].t, all[2].t
    local a = MR.Figures(s, "running", t1).chart.cooldowns
    local b = MR.Figures(s, "running", (t1 + t2) / 2).chart.cooldowns
    assertTrue(rawequal(a, b), "the same list from tick to tick")
    local c = MR.Figures(s, "running", t2).chart.cooldowns
    assertFalse(rawequal(a, c), "a new list once another cast is heard")
    assertTrue(#c > #a)
end)

test("chart icons: test mode's chart follows Show cooldown icons while it is on screen", function()
    local f = hud()
    assertTrue(f.NS.Preview.Start())
    local chart = body(f).w.chart
    local n = #chart:Icons()
    assertTrue(n > 0, "the sample's cooldowns so far")
    local pushed = f.Hud.View().chart
    assertTrue(f.NS.SetByPath("live.castDots", false))
    f.Hud.Refresh()
    assertEqual(#chart:Icons(), 0, "the sample's icons go with the setting")
    assertTrue(chart.shown, "the chart itself stays")
    assertTrue(pushed.cooldowns ~= nil, "the preview's own chart is not changed")
    assertTrue(f.NS.SetByPath("live.castDots", true))
    f.Hud.Refresh()
    assertEqual(#chart:Icons(), n, "on again brings them back")
end)
