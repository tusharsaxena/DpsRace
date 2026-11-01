-- tests/test_skin_menus.lua — the addon's own surfaces on the skin (FS-DR-FIX, causes A1, A2, L6 and
-- L9 of Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING/): the context menus on the shared Ka0s
-- menu, the Back button's mark, the Runs list's scroll track, the spell icons' border, and the title
-- bar and scroll bar geometry read off the skin.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local installPaint = dofile(T.root .. "/tests/_kit/mock_paint.lua")

local function near(a, b) return math.abs(a - b) < 1e-6 end

local function kaos()
    return T.load({ kaosMenus = true, mutate = function(m)
        installPaint(m)
        m.GetCursorPosition = function() return 400, 300 end
        rawset(m.UIParent, "GetEffectiveScale", function() return 1 end)
    end })
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
    dd.onSelect(1)
    dd.onSelect(3)
    assertEqual(ran, 0)
    dd.onSelect(2)
    assertEqual(ran, 1)
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

test("skin menus: the title bar and the scroll bar read their size off the skin", function()
    local NS = T.NS
    assertEqual(NS.Style.TITLE_BAR_H, NS.Skin.Token("title.height"))
    assertEqual(NS.ResultsTable.SCROLLBAR_W, NS.Skin.Token("scroll.width"))
    local d = T.load({ libFiles = {} }).NS
    assertEqual(d.Style.TITLE_BAR_H, 30, "the degraded load keeps the layout")
    assertEqual(d.ResultsTable.SCROLLBAR_W, 8)
    assertFalse(NS.Style.TITLE_BAR_H == nil)
end)
