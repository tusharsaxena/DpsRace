-- tests/test_skin_menus.lua — the addon's own surfaces on the skin (FS-DR-FIX, causes A1, A2, L6 and
-- L9 of Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING/): the context menus on the shared Ka0s
-- menu, the Back button's mark, the Runs list's scroll track, the spell icons' border, and the title
-- bar and scroll bar geometry read off the skin.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local installPaint = dofile(T.root .. "/tests/_kit/mock_paint.lua")
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local function near(a, b) return math.abs(a - b) < 1e-6 end

local function kaos()
    return T.load({ kaosMenus = true, mutate = function(m)
        installPaint(m)
        m.GetCursorPosition = function() return 400, 300 end
        rawset(m.UIParent, "GetEffectiveScale", function() return 1 end)
        -- The shared menu is the library's local: remember what is built, to find and click it.
        local create, built = m.CreateFrame, {}
        m.__built = built
        m.CreateFrame = function(...)
            local f = create(...)
            built[#built + 1] = f
            return f
        end
    end })
end

--- The library's shared menu, once something has opened it.
local function sharedMenu(i)
    for _, f in ipairs(i.mocks.__built) do
        if rawget(f, "Populate") then return f end
    end
    error("the shared menu was never built")
end

--- A click on the menu's row `n`, as the client delivers it: through the row's own OnClick.
local function clickRow(i, n)
    local menu = sharedMenu(i)
    assertTrue(menu:IsShown(), "a click needs the menu open")
    menu.buttons[n]:GetScript("OnClick")(menu.buttons[n])
    return menu
end

--- A saved run, and an instance on the Ka0s menu.
local function withRun()
    local i = kaos()
    local r = { id = "a", status = "complete", date = 1000, note = "",
                race = { length = 60 }, char = {}, target = {}, result = { damage = 1, dps = 1 }, flags = {},
                spells = {} }
    i.NS.db.global.runs.a = r
    return i, r
end

local function labels(dd)
    local out = {}
    for _, o in ipairs(dd._options) do out[#out + 1] = o.label end
    return out
end

local function rowIndex(dd, text)
    for i, o in ipairs(dd._options) do
        if o.label:find(text, 1, true) then return i end
    end
    error("no row: " .. text)
end

test("skin menus: a row's right-click opens the Ka0s menu, not the client's", function()
    local i, r = withRun()
    local before = #i.mocks.__menus
    assertTrue(i.NS.Results.RowMenu(r, i.mocks.UIParent))
    assertEqual(#i.mocks.__menus, before, "the client's menu stays shut")
    local dd = i.NS.__contextDropdown()
    assertTrue(dd ~= nil and dd.__owner == "DpsRace", "the dropdown wears this addon's skin")
    local rows = table.concat(labels(dd), "|")
    assertTrue(rows:find("Add Note", 1, true) ~= nil, rows)
    assertTrue(rows:find("Compare With This Run", 1, true) ~= nil, rows)
    assertTrue(rows:find("Delete", 1, true) ~= nil, rows)
end)

test("skin menus: a button runs, a title and a disabled row do nothing", function()
    local i = kaos()
    local ran = 0
    i.NS.OpenMenu(i.mocks.UIParent, function(root)
        root:CreateTitle("Heading")
        root:CreateButton("Run", function() ran = ran + 1 end)
        root:CreateButton("Off", function() ran = ran + 10 end):SetEnabled(false)
    end)
    local dd = i.NS.__contextDropdown()
    local heading = dd._options[1].color
    local tr, tg, tb = i.NS.Skin.Color("text.heading")
    assertTrue(near(heading[1], tr) and near(heading[2], tg) and near(heading[3], tb), "a title's color")
    assertEqual(dd._options[2].color, nil, "a plain row keeps the menu's")
    assertTrue(dd._options[3].color ~= nil, "a disabled row's")
    local menu = clickRow(i, 1)
    assertTrue(menu:IsShown(), "a title leaves the menu open")
    assertEqual(#dd._options, 3)
    clickRow(i, 3)
    assertTrue(menu:IsShown(), "so does a disabled row")
    assertEqual(ran, 0)
    clickRow(i, 2)
    assertEqual(ran, 1)
    assertFalse(menu:IsShown(), "a button closes it")
end)

test("skin menus: a disabled row in a submenu stays on that submenu", function()
    local i = kaos()
    i.NS.OpenMenu(i.mocks.UIParent, function(root)
        local sub = root:CreateButton("Share")
        sub:CreateButton("Party", function() end):SetEnabled(false)
        sub:CreateButton("Raid", function() end)
    end)
    local dd = i.NS.__contextDropdown()
    clickRow(i, 1)
    assertEqual(labels(dd)[1], "Party")
    local menu = clickRow(i, 1)
    assertTrue(menu:IsShown())
    assertEqual(table.concat(labels(dd), "|"), "Party|Raid")
end)

test("skin menus: a second right-click reopens the menu on the new rows", function()
    local i = kaos()
    i.NS.OpenMenu(i.mocks.UIParent, function(root) root:CreateButton("First", function() end) end)
    local menu = sharedMenu(i)
    assertTrue(menu:IsShown())
    i.NS.OpenMenu(i.mocks.UIParent, function(root)
        root:CreateButton("Second", function() end)
        root:CreateButton("Third", function() end)
    end)
    assertTrue(menu:IsShown(), "an open one would toggle shut")
    assertEqual(table.concat(labels(i.NS.__contextDropdown()), "|"), "Second|Third")
    assertTrue(menu.buttons[2]:IsShown(), "drawn with the second fill's rows")
end)

test("skin menus: a submenu replaces the rows it drops from", function()
    local i = kaos()
    local picked
    i.NS.OpenMenu(i.mocks.UIParent, function(root)
        local sub = root:CreateButton("Share")
        sub:CreateButton("Party", function() picked = "party" end)
    end)
    local dd = i.NS.__contextDropdown()
    assertEqual(#dd._options, 1)
    assertTrue(dd._options[1].label:find("Share", 1, true) == 1)
    assertTrue(dd._options[1].label:find("|T", 1, true) ~= nil, "a mark says it opens")
    dd.onSelect(1)
    assertEqual(picked, nil)
    assertEqual(labels(dd)[1], "Party", "the channel row")
    dd.onSelect(rowIndex(dd, "Party"))
    assertEqual(picked, "party")
end)

test("skin menus: without the library the same fill reaches the client's menu", function()
    local i = T.load({ libFiles = {} })
    i.NS.__clientMenus = false
    i.NS.OpenMenu(i.mocks.UIParent, function(root) root:CreateButton("Run", function() end) end)
    assertTrue(i.mocks.__lastMenu:Find("Run") ~= nil)
end)

test("skin menus: the Back button's mark wears btn.icon and follows a switch", function()
    local i = withRun()
    local NS = i.NS
    NS.Results.ShowRun("a")
    local icon = NS.Results.__ui().detail.w.back.icon
    assertEqual(icon.__texture, NS.Icon("arrow-left"), "the catalog's arrow")
    local function tinted()
        local want, got = { NS.Skin.Color("btn.icon") }, { icon:GetVertexColor() }
        return near(got[1], want[1]) and near(got[2], want[2]) and near(got[3], want[3])
    end
    assertTrue(tinted(), "tinted under Ka0s Default")
    NS.ApplySkinChoice("ka0s", "ember")
    i.mocks.__fireTimers()
    assertTrue(tinted(), "replayed on a switch")
end)

test("skin menus: the Runs list's scroll bar has the skin's track", function()
    local i = kaos()
    local t = i.NS.ResultsTable.New(i.mocks.CreateFrame("Frame"), { { key = "a", label = "A", width = 10 } }, {})
    local c = t.scrollbar.track.__color
    local tr, tg, tb, ta = i.NS.Skin.Color("dr.scroll.track")
    assertTrue(near(c[1], tr) and near(c[2], tg) and near(c[3], tb) and near(c[4], ta), "dr.scroll.track")
end)

test("skin menus: a spell icon wears the skin's icon border", function()
    local calls = {}
    local i = kaos()
    local real = i.NS.Skin.IconBorder
    i.NS.Skin.IconBorder = function(frame, opts)
        calls[#calls + 1] = { frame = frame, fromSkin = opts and opts.fromSkin }
        return real(frame, opts)
    end
    local parent = i.mocks.CreateFrame("Frame")
    local edge = i.NS.Style.IconEdge(parent, parent:CreateTexture())
    assertEqual(#calls, 1)
    assertEqual(calls[1].frame, edge)
    assertEqual(calls[1].fromSkin, true)
end)

-- ── the icon surfaces (cause A1) ─────────────────────────────────────────────────────────────────

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

--- An instance that remembers each frame given the skin's icon border, two runs seeded, the weaker open.
local function iconSurfaces()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
    end }
    local NS = i.NS
    i.edges = {}
    local real = NS.Skin.IconBorder
    NS.Skin.IconBorder = function(frame, opts)
        assertEqual(opts and opts.fromSkin, true, "the border follows the skin")
        i.edges[#i.edges + 1] = frame
        return real(frame, opts)
    end
    NS.db.global.runs.this = castRun(NS, "this", 100, NOW - 3600)
    NS.db.global.runs.best = castRun(NS, "best", 300, NOW - 7200)
    NS.Bests.Invalidate()
    NS.Results.ShowRun("this")
    return i
end

local function edged(i, pred)
    for _, frame in ipairs(i.edges) do
        if pred(frame) then return frame end
    end
    return nil
end

test("skin menus: a spell row of the breakdown is edged, and the edge goes with its icon", function()
    local i = iconSurfaces()
    local list = i.NS.HudBreakdown.New(i.mocks.CreateFrame("Frame"))
    local row = list:acquire(1, true, false)
    assertTrue(edged(i, function(f) return f == row.iconEdge end) ~= nil, "the row's edge has the border")
    assertTrue(row.iconEdge:IsShown())
    list:Clear()
    row = list:acquire(1, false, false)
    assertFalse(row.icon:IsShown())
    assertFalse(row.iconEdge:IsShown(), "no icon, no edge")
end)

test("skin menus: the chart's, the compare's and the timeline's icons are edged", function()
    local i = iconSurfaces()
    local d = i.NS.Results.__ui().detail
    -- A chart draws from this session's slices, which a stored run has none of.
    local strip = i.NS.HudChart.New(i.mocks.CreateFrame("Frame"), i.NS.Style.FONT.TEXT, 20)
    strip:placeIcon({ t = 1, id = SOUL_FIRE }, 0, 0, 1)
    local chartIcon = strip:Icons()[1]
    assertTrue(edged(i, function(f) return f == chartIcon.frame end) ~= nil, "a chart icon")
    d:SetComparing(true)
    assertTrue(edged(i, function(f) return f:GetParent().pane ~= nil end) ~= nil, "a compare row")
    d.w.timeline:__fire("OnClick")
    local u = assert(i.NS.ResultsTimeline.__ui(), "the timeline was never built")
    assertTrue(edged(i, function(f) return f:GetParent().laneA ~= nil end) ~= nil, "a timeline row")
    assertTrue(#u.icons > 0, "the timeline draws an icon")
    assertTrue(edged(i, function(f) return f == u.icons[1].frame end) ~= nil, "a timeline cast")
end)

test("skin menus: the title bar and the scroll bar read their size off the skin", function()
    local NS = T.NS
    assertEqual(NS.Style.TITLE_BAR_H, NS.Skin.Token("title.height"))
    assertEqual(NS.ResultsTable.SCROLLBAR_W, NS.Skin.Token("scroll.width"))
    local d = T.load({ libFiles = {} }).NS
    assertEqual(d.Style.TITLE_BAR_H, 30, "the degraded load keeps the layout")
    assertEqual(d.ResultsTable.SCROLLBAR_W, 8)
    assertFalse(NS.Style.TITLE_BAR_H == nil)
end)
