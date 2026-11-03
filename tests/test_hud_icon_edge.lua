-- tests/test_hud_icon_edge.lua — a HUD icon's edge stays the HUD's black, a window icon's outline
-- the window's gray (R4-HUD of Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND4,
-- R4_ADDENDUM_HUD_ICON_EDGE.md; the owner's scope answer in R4_SIGNOFF.md, "I prefer the HUD icons
-- to keep black edges"). LibKa0s R4-L4 gave S.IconBorder `opts.hud`: the edge in `icon.border`,
-- never `icon.outline`. The race HUD's spell rows (Style.IconEdge through Hud_Breakdown) and the HUD
-- chart's cooldown icons (Hud_Chart) pass it; the Results detail builds the same list and chart
-- ("window"), and it, the compare's rows and the timeline keep the window outline.
--
-- red under: `hud` never passed (the HUD edge reads icon.outline, #4D4D57 under Ka0s Default), or
-- passed unconditionally (the Results detail's icons turn black and lose the window outline).

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local INFERNAL, SOUL_FIRE = 1122, 6353

local function castRun(NS, id, dps, date)
    local casts = { { t = 1, id = INFERNAL, pet = false }, { t = 2, id = SOUL_FIRE, pet = false } }
    return {
        id = id, schema = 3, status = "complete", addon = "0.1.0", date = date,
        race = { length = 60, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction" },
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 60, dps = dps, tail = 2 }, flags = { lateCasts = {} }, note = "",
        spells = { { id = SOUL_FIRE, dmg = dps * 50 } },
        casts = { v = 1, list = NS.Casts.Encode(casts), dropped = 0,
                  spells = { [INFERNAL] = 180000, [SOUL_FIRE] = 45000 } },
    }
end

--- An instance under the kit's paint recorder (so an edge's color is readable), two runs seeded and
--- the weaker open in Results.
local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        dofile(T.root .. "/tests/_kit/mock_paint.lua")(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
    end }
    local NS = i.NS
    NS.db.global.runs.this = castRun(NS, "this", 100, NOW - 3600)
    NS.db.global.runs.best = castRun(NS, "best", 300, NOW - 7200)
    NS.Bests.Invalidate()
    NS.Results.ShowRun("this")
    return i
end

local function rgba(c) return c and ("%.3f,%.3f,%.3f,%.3f"):format(c[1], c[2], c[3], c[4] or 1) or "nil" end

--- The color the skin drew on `frame`'s top edge, "r,g,b,a".
local function edgeColor(i, frame)
    local rec = i.mocks.LibStub("LibKa0s-Skin-1.0").painted[frame]
    assertTrue(rec ~= nil and rec.calls.IconBorder ~= nil, "the frame is edged by S.IconBorder")
    local top = rec.regions.edgeTop
    assertTrue(top ~= nil, "the edge has a top")
    return rgba(top.__color)
end

local function token(i, name) return rgba(i.NS.Skin.Token(name)) end

local function hudRow(i)
    return i.NS.HudBreakdown.New(i.mocks.CreateFrame("Frame")):acquire(1, true, false)
end

local function hudChartIcon(i)
    local strip = i.NS.HudChart.New(i.mocks.CreateFrame("Frame"))
    strip:placeIcon({ t = 1, id = SOUL_FIRE }, 0, 0, 1)
    return strip:Icons()[1].frame
end

test("hud icon edge: under Ka0s Default the HUD's black and the window's gray differ", function()
    local i = inst()
    assertEqual(token(i, "icon.border"), "0.000,0.000,0.000,1.000", "the HUD edge is black")
    assertTrue(token(i, "icon.outline") ~= token(i, "icon.border"), "the window outline is not")
end)

test("hud icon edge: a race HUD spell row's icon edge is icon.border, never icon.outline", function()
    local i = inst()
    local c = edgeColor(i, hudRow(i).iconEdge)
    assertEqual(c, token(i, "icon.border"))
    assertTrue(c ~= token(i, "icon.outline"), "not the window outline")
end)

test("hud icon edge: the HUD chart's cooldown icon edge is icon.border, never icon.outline", function()
    local i = inst()
    local c = edgeColor(i, hudChartIcon(i))
    assertEqual(c, token(i, "icon.border"))
    assertTrue(c ~= token(i, "icon.outline"), "not the window outline")
end)

test("hud icon edge: the Results detail's spell rows and chart icons keep the window outline", function()
    local i = inst()
    local d = i.NS.Results.__ui().detail
    local row = d.w.list:acquire(1, true, false)
    assertEqual(edgeColor(i, row.iconEdge), token(i, "icon.outline"), "a Results detail spell row")
    d.w.chart:placeIcon({ t = 1, id = SOUL_FIRE }, 0, 0, 1)
    assertEqual(edgeColor(i, d.w.chart:Icons()[1].frame), token(i, "icon.outline"), "a Results detail chart icon")
end)

test("hud icon edge: Style.IconEdge keeps the window outline unless told it is on the HUD", function()
    local i = inst()
    local parent = i.mocks.CreateFrame("Frame")
    assertEqual(edgeColor(i, i.NS.Style.IconEdge(parent, parent:CreateTexture())), token(i, "icon.outline"),
        "a window icon (the compare's, the timeline's)")
    assertEqual(edgeColor(i, i.NS.Style.IconEdge(parent, parent:CreateTexture(), true)), token(i, "icon.border"),
        "a HUD icon")
end)

test("hud icon edge: a skin switch and back keeps the HUD edge on icon.border", function()
    local i = inst()
    local row, icon = hudRow(i), hudChartIcon(i)
    i.NS.ApplySkinChoice("ka0s", "obsidian")
    i.mocks.__fireTimers()
    assertEqual(edgeColor(i, row.iconEdge), token(i, "icon.border"), "Obsidian's HUD edge")
    i.NS.ApplySkinChoice("ka0s", "ka0s")
    i.mocks.__fireTimers()
    assertEqual(edgeColor(i, row.iconEdge), "0.000,0.000,0.000,1.000", "back on Ka0s Default: black")
    assertEqual(edgeColor(i, icon), "0.000,0.000,0.000,1.000", "the chart icon too")
end)
