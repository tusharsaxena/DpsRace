-- tests/test_chart_icons.lua — the damage chart's cooldown icons (#14, modules/Hud_Chart.lua): the
-- ability's icon along the top of the plot at each cast of an ability whose base cooldown is 29 s
-- or more, a later icon that would overlap the one before it on the first row below with room, as many
-- rows as the plot's height holds, then a +n mark for a crowd on the last row. The pure positions
-- (Chart.TimeX, IconX, IconRowCount, IconRows, IconY) and selection, then the icons drawn live on the running HUD
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

-- A HUD fixture whose client knows the base cooldowns: the Infernal and Soul Fire at 29 s or
-- more, Conflagrate under it, Incinerate none.
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
    local rows, marks = Chart.IconRows({ 6, 10, 18, 30, 41, 44, 70 }, 2)
    -- 10 is 4 from 6: second row; 18 is 12 from 6: top; 30 top; 41 is 11 from 30: second;
    -- 44 is 14 from 30: top; 70 top.
    assertEqual(table.concat(rows, ","), "1,2,1,1,2,1,1")
    assertEqual(#marks, 0, "each spilled cast alone on the last row: an icon, no mark")
    assertEqual(#Chart.IconRows({}, 5), 0)
end)

-- The rows of `rows` (nil as "-") for `n` casts, and each mark as "x:row:members".
local function layout(rows, marks, n)
    local r, m = {}, {}
    for i = 1, n do r[i] = rows[i] and tostring(rows[i]) or "-" end
    for i, mk in ipairs(marks) do m[i] = ("%g:%d:%s"):format(mk.x, mk.row, table.concat(mk.members, "/")) end
    return table.concat(r, ","), table.concat(m, " ")
end

-- Every index once, in a row or in a mark: nothing dropped.
local function accounted(rows, marks, n)
    local seen = 0
    for i = 1, n do if rows[i] then seen = seen + 1 end end
    for _, mk in ipairs(marks) do
        for _, i in ipairs(mk.members) do
            assertNil(rows[i], "a cast under a mark has no icon row")
            seen = seen + 1
        end
    end
    assertEqual(seen, n, "every cast drawn as an icon or counted in a mark")
end

test("chart icons: the rows the plot holds follow its configured height, at least one", function()
    local Chart = T.NS.HudChart
    assertEqual(Chart.IconRowCount(80), 5, "the default plot: (80 - 4 + 1) / 13")
    assertEqual(Chart.IconRowCount(40), 2, "the 40 px minimum")
    assertEqual(Chart.IconRowCount(160), 12, "the 160 px maximum")
    assertEqual(Chart.IconRowCount(10), 1, "never none")
    assertEqual(Chart.IconRowCount(nil), 1)
    near(Chart.IconY(5), -(Chart.INSET + Chart.ICON / 2 + 4 * (Chart.ICON + Chart.ICON_GAP)), "the fifth row")
    assertTrue(-Chart.IconY(Chart.IconRowCount(80)) + Chart.ICON / 2 <= 80 - Chart.INSET, "the last row inside the plot")
end)

test("chart icons: the plot frame holds one icon row over the configured height, one more row in all", function()
    local Chart = T.NS.HudChart
    assertEqual(Chart.RESERVE, Chart.ICON + Chart.ICON_GAP, "one row: an icon and its gap")
    assertEqual(Chart.FrameHeight(80), 93)
    assertEqual(Chart.FrameHeight(40), 53)
    assertEqual(Chart.IconRowCount(Chart.FrameHeight(80)), 6, "the default plot: 5 rows, and the reserved one")
    assertEqual(Chart.IconRowCount(Chart.FrameHeight(40)), 3, "the 40 px minimum: 2 rows, and the reserved one")
    assertEqual(Chart.BlockHeight(80, 22), 22 + 93 + Chart.GAP + Chart.AXIS_H, "the block carries the frame")
    -- The first row's icons end above the columns' area (the configured height, from the bottom).
    local rowBottom = -Chart.IconY(1) + Chart.ICON / 2
    for _, h in ipairs({ 40, 80, 160 }) do
        local colTop = Chart.FrameHeight(h) - (h - Chart.INSET)
        assertTrue(rowBottom < colTop, ("the reserved row clears the columns at %d px"):format(h))
    end
end)

test("chart icons: the columns and the best's diagonal scale below the reserved row", function()
    local f = hud()
    local best = f.NS.Recorder.NewRun(30)
    best.status, best.result, best.date = "complete", { damage = 3000000, dps = 100000 }, 1
    f.NS.Recorder.Save(best)
    racing(f)
    local chart = body(f).w.chart
    local Chart = f.NS.HudChart
    local row = Chart.ICON + Chart.ICON_GAP
    assertEqual(chart.frameH, chart.plotH + row, "the frame: the configured height and one row on top")
    assertEqual(chart.colH, chart.plotH - 2 * Chart.INSET, "the columns keep the configured height")
    assertTrue(Chart.INSET + chart.colH <= chart.frameH - row, "the columns' top at most the frame less a row")
    local _, _, _, y1 = chart.diag[1]:GetEndPoint()
    assertTrue(y1 <= chart.frameH - row, "the diagonal's top under the reserved row")
    local p = chart.cols[1].__points[#chart.cols[1].__points]
    assertEqual(p[1], "BOTTOMLEFT", "the columns stand on the plot's bottom")
    assertEqual(p[5], Chart.INSET)
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("chart icons: three casts in one second stack on three rows of the 80 px plot", function()
    local Chart = T.NS.HudChart
    local xs = { 20, 21, 22 }
    local rows, marks = Chart.IconRows(xs, Chart.IconRowCount(80))
    local r, m = layout(rows, marks, 3)
    assertEqual(r, "1,2,3", "the potion, the trinket and Bestial Wrath each in sight")
    assertEqual(m, "")
    accounted(rows, marks, 3)
end)

test("chart icons: three casts in one second on the short plot: one icon and a +2 mark", function()
    local Chart = T.NS.HudChart
    local rows, marks = Chart.IconRows({ 20, 21, 22 }, Chart.IconRowCount(40))
    local r, m = layout(rows, marks, 3)
    assertEqual(r, "1,-,-")
    assertEqual(m, "21:2:2/3", "the mark on the last row at the first crowded cast's place, for both")
    accounted(rows, marks, 3)
end)

test("chart icons: six casts in one second: four rows and a +2 on the 80 px plot, a +5 on the short one", function()
    local Chart = T.NS.HudChart
    local xs = { 20, 20.2, 20.4, 20.6, 20.8, 21 }
    local rows, marks = Chart.IconRows(xs, Chart.IconRowCount(80))
    local r, m = layout(rows, marks, 6)
    assertEqual(r, "1,2,3,4,-,-")
    assertEqual(m, "20.8:5:5/6")
    accounted(rows, marks, 6)
    rows, marks = Chart.IconRows(xs, Chart.IconRowCount(40))
    r, m = layout(rows, marks, 6)
    assertEqual(r, "1,-,-,-,-,-")
    assertEqual(m, "20.2:2:2/3/4/5/6")
    accounted(rows, marks, 6)
    rows, marks = Chart.IconRows(xs, 1)
    r, m = layout(rows, marks, 6)
    assertEqual(r, "-,-,-,-,-,-", "one row: the whole crowd is the mark")
    assertEqual(m, "20:1:1/2/3/4/5/6")
    accounted(rows, marks, 6)
end)

test("chart icons: crowds an icon's width apart on the last row get a mark each, never overlapping", function()
    local Chart = T.NS.HudChart
    -- Two rows: 10, 25, 40, 53 and 70 take the top; 11 and 12 crowd at 11, 41 and 50 at 41 (9 apart);
    -- 71 has no room above and is alone on the last row: an icon there.
    local xs = { 10, 11, 12, 25, 40, 41, 50, 53, 70, 71 }
    local rows, marks = Chart.IconRows(xs, 2)
    local r, m = layout(rows, marks, #xs)
    assertEqual(r, "1,-,-,1,1,-,-,1,1,2")
    assertEqual(m, "11:2:2/3 41:2:6/7")
    accounted(rows, marks, #xs)
end)

test("chart icons: only casts of an ability whose base cooldown is 29 s or more get one", function()
    local NS = T.NS
    local run = { casts = { v = 1, list = "-160:6353,100:1122,200:17962,210:29722,300:5,350:7,400:6353",
                            spells = { [6353] = 45000, [1122] = 180000, [17962] = 13000, [29722] = 0,
                                       [5] = 28900, [7] = 29000 } } }
    local casts = NS.HudChart.CooldownsOf(run)
    local got = {}
    for i, c in ipairs(casts) do got[i] = c.id end
    assertEqual(table.concat(got, ","), "6353,1122,7,6353", "28.9 s gets none, exactly 29 s gets one")
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

-- Three (or `n`) long cooldowns cast in the same second, at 6 s: a potion, a trinket, Bestial Wrath
-- and more. Answers their spell IDs.
local CROWD = { 307192, 377453, 19574, 1122, 6353, 205180 }
local function crowded(f, n)
    local cds = f.M.__baseCooldowns
    for i = 1, n do cds[CROWD[i]] = 120000 end
    racing(f)
    pump(f, 1)
    for i = 1, n do cast(f, "Crowd-" .. i, CROWD[i]) end
    pump(f, 0.5)
end

-- The casts a strip draws: its icons' and every mark's members.
local function drawn(chart)
    local n = #chart:Icons()
    for _, m in ipairs(chart:Marks()) do n = n + #m.casts end
    return n
end

test("chart icons: three casts in one second are all captured and all drawn on the 80 px running chart", function()
    local f = hud()
    crowded(f, 3)
    local live = f.NS.Casts.Live()
    local heard = 0
    for _, c in ipairs(live) do
        if c.id == CROWD[1] or c.id == CROWD[2] or c.id == CROWD[3] then heard = heard + 1 end
    end
    assertEqual(heard, 3, "the capture keeps all three")
    local chart = body(f).w.chart
    assertEqual(chart.plotH, 80)
    local icons = chart:Icons()
    assertEqual(#icons, 6, "the three from before and the three in one second")
    assertEqual(#chart:Marks(), 0)
    local rows = {}
    for i = 4, 6 do rows[#rows + 1] = tostring(icons[i].row) end
    assertEqual(table.concat(rows, ","), "1,2,3", "one row each")
    for i = 4, 6 do near(icons[i].frame.__points[#icons[i].frame.__points][5], f.NS.HudChart.IconY(icons[i].row)) end
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("chart icons: on the short plot the crowd's overflow is a +n mark whose tooltip lists each cast", function()
    local f = hud()
    assertTrue(f.NS.SetByPath("appearance.chart.height", 40))
    crowded(f, 4)
    local chart = body(f).w.chart
    assertEqual(chart.plotH, 40)
    local marks = chart:Marks()
    assertEqual(#marks, 1)
    local m = marks[1]
    assertEqual(m.row, 3, "on the last row: the reserved one and the 40 px plot's two")
    assertEqual(#m.casts, 2)
    assertEqual(m.frame.text:GetText(), "+2")
    assertTrue(m.frame:IsShown() and m.frame.__mouse, "shown, and it takes the mouse")
    local p = m.frame.__points[#m.frame.__points]
    assertTrue(p[1] == "CENTER" and p[2] == chart.over and p[3] == "TOPLEFT", "on the overlay")
    near(p[4], m.x)
    near(p[5], f.NS.HudChart.IconY(3))
    assertEqual(drawn(chart), #f.NS.Casts.Live() - 2, "every cooldown drawn (the two rotational casts have none)")
    local shown = hover(f, m.frame)
    assertTrue(shown ~= nil and shown.owner == m.frame, "the tooltip under the mark")
    assertEqual(shown.lines[1], "2 cooldowns here")
    assertEqual(#shown.lines, 3)
    assertEqual(shown.lines[2], f.NS.HudBreakdown.SpellName(m.casts[1].id) .. " at 0:06")
    assertEqual(shown.lines[3], f.NS.HudBreakdown.SpellName(m.casts[2].id) .. " at 0:06")
    assertEqual(f.NS.Style.TipBullet(shown.lines, 2), f.NS.Style.BULLET, "on bullets")
    m.frame:GetScript("OnEnter")(m.frame)
    m.frame:GetScript("OnLeave")(m.frame)
    m.frame.casts = nil
    assertNil(hover(f, m.frame), "a released mark hovers to nothing")
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("chart icons: six casts in one second: nothing dropped on the 80 px plot or the short one", function()
    local f = hud()
    crowded(f, 6)
    local chart = body(f).w.chart
    local cooldowns = 3 + 6
    assertEqual(drawn(chart), cooldowns, "the 80 px plot")
    assertEqual(#chart:Marks(), 0, "six rows with the reserved one: one icon each")
    local rows = {}
    for i = 4, 9 do rows[#rows + 1] = tostring(chart:Icons()[i].row) end
    assertEqual(table.concat(rows, ","), "1,2,3,4,5,6")
    assertTrue(f.NS.SetByPath("appearance.chart.height", 40))
    pump(f, 0.5)
    assertEqual(chart.plotH, 40)
    assertEqual(drawn(chart), cooldowns, "the short plot")
    assertEqual(chart:Marks()[1].frame.text:GetText(), "+4", "two icons, then the rest on the third row")
    for _, d in ipairs(chart.markPool.free or {}) do assertFalse(d:IsShown(), "a released mark stays hidden") end
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("chart icons: the crowd's tooltip marks a pet's cast and takes nothing but a list", function()
    local Tips = T.NS.ResultsTips
    local lines = Tips.CastCrowd({ { t = 1, id = 3110, pet = true }, { t = -1.6, id = 6353 } })
    assertEqual(lines[1], "2 cooldowns here")
    assertEqual(lines[2], T.NS.HudBreakdown.SpellName(3110) .. " (pet) at 0:01")
    assertEqual(lines[3], T.NS.HudBreakdown.SpellName(6353) .. " at -0:02")
    assertNil(Tips.CastCrowd(nil))
    assertNil(Tips.CastCrowd({}))
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
