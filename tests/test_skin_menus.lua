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
    return T.load({ realMenus = true, mutate = function(m)
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

--- A click on the menu's row `n`, as the client delivers it: through the row's own OnClick, which an
--- inert row does not have.
local function clickRow(i, n)
    local menu = sharedMenu(i)
    assertTrue(menu:IsShown(), "a click needs the menu open")
    local onClick = menu.buttons[n]:GetScript("OnClick")
    if onClick then onClick(menu.buttons[n]) end
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

--- The rows W.ContextMenu was last handed, titles and buttons in order, as the record holds them.
local function labels(i)
    local out = {}
    for _, e in ipairs(i.mocks.__lastMenu.entries) do out[#out + 1] = e.text end
    return out
end

test("skin menus: a row's right-click opens the Ka0s menu, skinned for this addon", function()
    local i, r = withRun()
    local seen
    local W = i.mocks.LibStub("LibKa0s-Widgets-1.0")
    local open = W.ContextMenu
    W.ContextMenu = function(anchor, rows, opts)
        seen = opts
        return open(anchor, rows, opts)
    end
    assertTrue(i.NS.Results.RowMenu(r, i.mocks.UIParent))
    assertTrue(sharedMenu(i):IsShown())
    assertEqual(seen.owner, "DpsRace", "the menu wears this addon's skin")
    assertTrue(seen.cursor, "at the pointer")
    local rows = table.concat(labels(i), "|")
    assertTrue(rows:find("Add Note", 1, true) ~= nil, rows)
    assertTrue(rows:find("Compare With This Run", 1, true) ~= nil, rows)
    assertTrue(rows:find("Delete", 1, true) ~= nil, rows)
end)

test("skin menus: the context menu holds no test seam", function()
    local i = kaos()
    assertEqual(i.NS.__clientMenus, nil)
    assertEqual(i.NS.__contextDropdown, nil)
end)

test("skin menus: a button runs, a title and a disabled row do nothing", function()
    local i = kaos()
    local ran = 0
    i.NS.OpenMenu(i.mocks.UIParent, function(root)
        root:CreateTitle("Heading")
        root:CreateButton("Run", function() ran = ran + 1 end)
        root:CreateButton("Off", function() ran = ran + 10 end):SetEnabled(false)
    end)
    assertEqual(i.mocks.__lastMenu.titles[1], "Heading")
    local menu = clickRow(i, 1)
    assertTrue(menu:IsShown(), "a title leaves the menu open")
    clickRow(i, 3)
    assertTrue(menu:IsShown(), "so does a disabled row")
    assertEqual(ran, 0)
    clickRow(i, 2)
    assertEqual(ran, 1)
    assertFalse(menu:IsShown(), "a button closes it")
end)

--- Every W.ContextMenu call's rows, as the seam hands them to the library (the real menu opens too).
local function captureRows(i)
    local calls = {}
    local W = i.mocks.LibStub("LibKa0s-Widgets-1.0")
    local open = W.ContextMenu
    W.ContextMenu = function(anchor, rows, opts)
        calls[#calls + 1] = { rows = rows, opts = opts }
        return open(anchor, rows, opts)
    end
    return calls
end

test("skin menus: a disabled row in a submenu is a disabled row of that child", function()
    local i = kaos()
    local calls = captureRows(i)
    i.NS.OpenMenu(i.mocks.UIParent, function(root)
        local sub = root:CreateButton("Share")
        sub:CreateButton("Party", function() end):SetEnabled(false)
        sub:CreateButton("Raid", function() end)
    end)
    assertEqual(#calls, 1)
    local child = calls[1].rows[1].submenu
    assertEqual(child[1].label, "Party")
    assertTrue(child[1].disabled, "Party is grayed")
    assertEqual(child[2].label, "Raid")
    assertEqual(child[2].disabled, nil)
end)

test("skin menus: the whole tree goes to one W.ContextMenu as submenu rows, any depth (Widgets 23)", function()
    local i = kaos()
    local calls = captureRows(i)
    local picked = {}
    i.NS.OpenMenu(i.mocks.UIParent, function(root)
        root:CreateTitle("Heading")
        root:CreateButton("Plain", function() picked[#picked + 1] = "plain" end)
        local share = root:CreateButton("Share")
        share:CreateButton("Party", function() picked[#picked + 1] = "party" end)
        local deeper = share:CreateButton("More")
        deeper:CreateButton("Deep", function() picked[#picked + 1] = "deep" end)
        local off = root:CreateButton("Off")
        off:CreateButton("Hidden", function() end)
        off:SetEnabled(false)
    end)
    assertEqual(#calls, 1, "one call carries every level")
    assertEqual(calls[1].opts.owner, "DpsRace")
    assertTrue(calls[1].opts.cursor)
    local rows = calls[1].rows
    assertEqual(#rows, 4)
    assertEqual(rows[1].label, "Heading")
    assertTrue(rows[1].title)
    assertEqual(rows[2].label, "Plain")
    assertEqual(rows[2].submenu, nil, "a plain button opens nothing")
    assertEqual(rows[3].label, "Share", "no hand-drawn mark: the library draws the arrow")
    assertEqual(rows[3].onClick, nil, "a submenu row has no click of its own")
    local share = rows[3].submenu
    assertEqual(#share, 2)
    assertEqual(share[1].label, "Party")
    assertEqual(share[2].label, "More")
    assertEqual(share[2].submenu[1].label, "Deep", "two levels down")
    assertEqual(rows[4].label, "Off")
    assertTrue(rows[4].disabled, "a disabled submenu row opens nothing")
    assertEqual(rows[4].submenu[1].label, "Hidden")
    for _, r in ipairs({ rows[2], share[1], share[2].submenu[1] }) do
        assertEqual(r.radio, nil)
        assertEqual(r.selected, nil)
        assertEqual(r.keepOpen, nil)
    end
    -- Drawn by the library: Share's click opens its child beside it and the parent stays.
    local menu = sharedMenu(i)
    local onClick = menu.buttons[3]:GetScript("OnClick")
    onClick(menu.buttons[3])
    assertTrue(menu:IsShown(), "the parent stays drawn")
    local child = menu.__child
    assertTrue(child ~= nil and child:IsShown(), "the child opens beside it")
    assertEqual(child.buttons[1].fs:GetText(), "Party")
    assertEqual(#calls, 1, "no reopen of the shared menu")
    assertEqual(#picked, 0)
    child.buttons[1]:GetScript("OnClick")(child.buttons[1])
    assertEqual(table.concat(picked, ","), "party")
    assertFalse(menu:IsShown(), "a pick closes every level")
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
    assertTrue(menu:IsShown(), "cursor: a second call moves it, it never toggles shut")
    assertEqual(table.concat(labels(i), "|"), "Second|Third")
    assertTrue(menu.buttons[2]:IsShown(), "drawn with the second fill's rows")
end)

test("skin menus: without the library the same fill reaches the client's menu", function()
    local i = T.load({ libFiles = {} })
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

test("skin menus: a spell icon wears the skin's icon border, and the library zooms that icon", function()
    -- red under: a bare edge frame with no .icon, so the library's 0.07 zoom never reached the spell
    -- icon and Blizzard's own edge showed inside the 1 px outline (image 103; R3-FIX).
    local calls = {}
    local i = kaos()
    local real = i.NS.Skin.IconBorder
    i.NS.Skin.IconBorder = function(frame, opts)
        calls[#calls + 1] = { frame = frame, fromSkin = opts and opts.fromSkin, icon = opts and opts.icon }
        return real(frame, opts)
    end
    local parent = i.mocks.CreateFrame("Frame")
    local tex = parent:CreateTexture()
    local edge = i.NS.Style.IconEdge(parent, tex)
    assertEqual(#calls, 1)
    assertEqual(calls[1].frame, edge)
    assertEqual(calls[1].fromSkin, true)
    assertEqual(calls[1].icon, tex, "the icon is named, so the zoom reaches it")
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
