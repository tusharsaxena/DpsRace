-- tests/test_icon_crop.lua — every Blizzard icon this addon draws inside an edge of its own, or on
-- the race HUD, crops its art at least 0.07 per side, so the icon's own rounded native edge never
-- shows inside the black edge (R4-ZOOM of Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND4, the
-- owner's scope answer in R4_SIGNOFF.md). Style.CropIcon is the crop (Style.ICON_CROP, 0.08, the
-- chart's and the timeline's); the spell rows' S.IconBorder zoom (0.07) is pinned in
-- tests/test_skin_menus.lua. Under the kit's paint recorder, so each texture's coords are readable.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600
local MIN = 0.07
local RING = "|cnIQ4:|Hitem:212011:7364:213743:213746::::80:267::6:2:10390:1540::::::|h[Band of the Test]|h|r"
local GEAR = {
    [1] = "|cnIQ4:|Hitem:212001::::::::80:267::6:2:10390:1540::::::|h[Hood of the Test]|h|r",
    [11] = RING,
}

local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        dofile(T.root .. "/tests/_kit/mock_paint.lua")(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
        m.C_Item.GetItemIconByID = function(x) return type(x) == "number" and 5000 + x or 134400 end
    end }
    return i, i.NS
end

local function mkRun(NS, id, dps, fields)
    local run = {
        id = id, schema = 4, status = "complete", addon = "0.1.0", date = NOW - HOUR,
        race = { length = 60, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction",
                 level = 80, ilvl = 639.4 },
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 60, dps = dps, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = 29722, dmg = dps * 50 } }, note = "",
        loadout = NS.Loadouts.Store({ gear = GEAR }),
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    NS.db.global.runs[id] = run
    return run
end

--- `tex`'s crop holds at least MIN on every side.
local function cropped(tex, what)
    -- The client (and the kit) answers the 8-number form: ULx, ULy, LLx, LLy, URx, URy, LRx, LRy.
    local c = { tex:GetTexCoord() }
    local l, t, r, b = c[1], c[2], c[7], c[8]
    assertTrue(l >= MIN and t >= MIN and r <= 1 - MIN and b <= 1 - MIN,
        ("%s: crop %s,%s,%s,%s is short of %s"):format(what, tostring(l), tostring(r), tostring(t),
            tostring(b), tostring(MIN)))
end

local function opened()
    local i, NS = inst()
    mkRun(NS, "this", 100)
    mkRun(NS, "best", 300, { date = NOW - 2 * HOUR })
    NS.Bests.Invalidate()
    NS.Results.ShowRun("this")
    return i, NS
end

test("icon crop: Style.CropIcon crops 0.08 per side, the chart's and the timeline's crop", function()
    local i, NS = inst()
    assertEqual(NS.Style.ICON_CROP, 0.08)
    local tex = i.mocks.CreateFrame("Frame"):CreateTexture()
    assertEqual(NS.Style.CropIcon(tex), tex, "answers the texture")
    cropped(tex, "CropIcon")
end)

test("icon crop: the run detail's gear cells crop each item's art inside the quality edge", function()
    -- red under: the loadout grid's cell.icon at the full 0..1, so the item's own beveled edge showed
    -- inside the 1 px quality edge.
    local _, NS = opened()
    local lo = NS.Results.__ui().detail.lo
    local n = 0
    for _, cell in pairs(lo.cells) do
        if cell.link then
            n = n + 1
            cropped(cell.icon, "loadout cell " .. tostring(cell.slot))
        end
    end
    assertTrue(n >= 2, "the two items drew: " .. n)
end)

test("icon crop: the gear view crops each item's art and each enchant and gem mark", function()
    -- red under: Results_Gear's cell.icon and mark icons at the full 0..1 inside their own edges.
    local _, NS = opened()
    NS.Results.__ui().detail.lo.gearView:__fire("OnClick")
    assertTrue(NS.ResultsGear.IsShown(), "the gear view opened")
    local u = NS.ResultsGear.__ui()
    local items, marks = 0, 0
    for _, cell in pairs(u.cells) do
        if cell.link then
            items = items + 1
            cropped(cell.icon, "gear cell " .. tostring(cell.slot))
        end
        for _, m in ipairs(cell.marks or {}) do
            if m.mark then
                marks = marks + 1
                cropped(m.icon, "gear mark on " .. tostring(cell.slot))
            end
        end
    end
    assertTrue(items >= 2, "the two items drew: " .. items)
    assertTrue(marks >= 3, "the ring's enchant and two gems drew: " .. marks)
end)

test("icon crop: the HUD's Your best card crops each consumable icon in its markup", function()
    -- red under: "|T<icon>:12:12|t", the full art with its native edge on the HUD.
    local _, NS = inst()
    local markup = NS.HudBest.ConsumableIcon({ itemID = 212345, kind = "potion", n = 1 })
    local l, r, t, b = markup:match(":12:12:0:0:64:64:(%d+):(%d+):(%d+):(%d+)|t$")
    assertTrue(l ~= nil, "a cropped markup: " .. markup)
    l, r, t, b = tonumber(l) / 64, tonumber(r) / 64, tonumber(t) / 64, tonumber(b) / 64
    assertTrue(l >= MIN and t >= MIN and r <= 1 - MIN and b <= 1 - MIN, "the crop holds: " .. markup)
end)
