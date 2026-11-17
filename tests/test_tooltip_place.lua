-- tests/test_tooltip_place.lua — where this addon's own tooltips open (AD-92-DR, LibKa0s#92;
-- WowAddonStandards standalone-windows *Tooltip placement*). Every tooltip the addon places goes
-- through LibKa0s-Tooltip-1.0: a body element's (a row, a cell, a card, a HUD tile or button, a chart
-- mark, a column header, a section heading's control) beside its window group, top level with the
-- element, 2 px off the group's right edge or, without the room, its left; a chrome element's (the
-- HUD's footer lines, a filter bar's buttons) attached and centered 2 px above it. Never the cursor,
-- never a corner offset. Driven on the kit's fake screen (tests/_kit/mock_screen.lua, revision 57)
-- through a right-fits and a right-does-not-fit layout, as the standard's Verification asks.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local TIP_W, TIP_H = 200, 80

local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
    end }
    i.scr = dofile(T.root .. "/tests/_kit/mock_screen.lua")(i.mocks, { width = 1920, height = 1080 })
    i.tip = i.scr.tooltip{ width = TIP_W, height = TIP_H }
    i.mocks.GameTooltip = i.tip
    return i
end

-- `frame` answers `l, b, w, h` (own units, scale 1) through the reads a placer makes.
local function geo(frame, l, b, w, h)
    rawset(frame, "GetLeft", function() return l end)
    rawset(frame, "GetBottom", function() return b end)
    rawset(frame, "GetRight", function() return l + w end)
    rawset(frame, "GetTop", function() return b + h end)
    rawset(frame, "GetWidth", function() return w end)
    rawset(frame, "GetHeight", function() return h end)
    rawset(frame, "GetEffectiveScale", function() return 1 end)
    return frame
end

-- A window `w` wide at `left` (300 to 700 high) and an element in it 20 high with its top at `top`.
local function layout(i, left, w, top, parentOf)
    local win = geo(i.mocks.CreateFrame("Frame", nil, i.mocks.UIParent), left, 300, w, 400)
    local el = geo(i.mocks.CreateFrame("Button", nil, parentOf or win), left + 10, top - 20, 40, 20)
    return win, el
end

-- The tooltip landed beside `win` on `side`, its top level with `el`'s, 2 px off the group's edge.
local function beside(i, win, el, side, what)
    local l, _, r, t = i.scr.rectOf(i.tip)
    assertTrue(l ~= nil, what .. ": the tooltip was not placed on the screen (the cursor or a relative anchor)")
    assertEqual(t, el:GetTop(), what .. ": its top level with the element's")
    if side == "right" then
        assertEqual(l, win:GetRight() + 2, what .. ": 2 px right of the window")
    else
        assertEqual(r, win:GetLeft() - 2, what .. ": 2 px left of the window")
    end
end

-- The tooltip landed attached and centered 2 px above `el`.
local function above(i, el, what)
    local l, b, r = i.scr.rectOf(i.tip)
    assertTrue(l ~= nil, what .. ": the tooltip was not placed on the screen")
    assertEqual(b, el:GetTop() + 2, what .. ": 2 px above the element")
    assertEqual((l + r) / 2, (el:GetLeft() + el:GetRight()) / 2, what .. ": centered on it")
end

local function owned(i, what)
    for _, e in ipairs(i.tip.__log) do
        if e.op == "SetOwner" then
            assertEqual(e.anchor, "ANCHOR_NONE", what .. ": owned at ANCHOR_NONE, never the cursor or a corner")
        end
    end
end

local function fresh(i) i.tip.__log = {} end

-- ── the shared paths (modules/Style.lua, modules/Results_Table.lua) ─────────────────────────────

test("tooltip place: SideTip opens beside the window, right when it fits and left without the room", function()
    local i = inst()
    local Tbl = i.NS.ResultsTable
    local win, row = layout(i, 100, 300, 600)
    Tbl.SideTip(win, row, { "Title", "a line" })
    beside(i, win, row, "right", "a row near the left edge")
    win, row = layout(i, 1500, 300, 500)
    fresh(i)
    Tbl.SideTip(win, row, { "Title", "a line" })
    beside(i, win, row, "left", "a row near the right edge")
    owned(i, "SideTip")
    i.scr.restore()
end)

test("tooltip place: SpellTip opens beside the window with its comparisons on the same side", function()
    local i = inst()
    local win, row = layout(i, 1500, 300, 640)
    i.NS.ResultsTable.SpellTip(win, row, 29722, { "a line" })
    beside(i, win, row, "left", "a spell row")
    assertEqual(i.tip:GetAnchorType(), "ANCHOR_LEFT", "the comparison side follows the tooltip's")
    i.scr.restore()
end)

test("tooltip place: BesideTip (a section part, a loadout or usage part) opens beside its window", function()
    local i = inst()
    local win, part = layout(i, 100, 300, 560)
    i.NS.ResultsTable.BesideTip(part, { "Title", "a line" })
    beside(i, win, part, "right", "a part's tooltip")
    owned(i, "BesideTip")
    i.scr.restore()
end)

test("tooltip place: a section heading's control (Style.ControlButton) is a body element", function()
    local i = inst()
    local win = geo(i.mocks.CreateFrame("Frame", nil, i.mocks.UIParent), 1500, 300, 300, 400)
    local b = geo(i.NS.Style.ControlButton(win, "chevron-down", "-", "Collapse this section", function() end),
        1700, 600, 16, 16)
    b:GetScript("OnEnter")(b)
    beside(i, win, b, "left", "a heading's arrow")
    owned(i, "ControlButton")
    i.scr.restore()
end)

test("tooltip place: a HUD button and tile are body elements; a filter bar's button is chrome", function()
    local i = inst()
    local States = i.NS.HudStates
    local win = geo(i.mocks.CreateFrame("Frame", nil, i.mocks.UIParent), 100, 300, 300, 400)
    local b = geo(States.Button(win, "Arm Race", function() end), 120, 400, 80, 20)
    b.tip = { "Arm Race", "a line" }
    b:GetScript("OnEnter")(b)
    beside(i, win, b, "right", "a HUD button")
    local zone = geo(States.TipZone(win, win:CreateFontString(), { "Race clock", "a line" }), 120, 600, 60, 20)
    fresh(i)
    zone:__fire("OnEnter")
    beside(i, win, zone, "right", "a HUD tile's zone")
    local bar = geo(States.Button(win, "Save", function() end), 300, 660, 60, 20)
    bar.tip, bar.tipChrome = { "Save", "a line" }, true
    fresh(i)
    bar:GetScript("OnEnter")(bar)
    above(i, bar, "a filter bar's button")
    owned(i, "HudStates")
    i.scr.restore()
end)

test("tooltip place: the Runs and Insights filter bars' buttons are chrome", function()
    local i = inst()
    i.NS.Results.Show()
    local panes = i.NS.Results.__ui().panes
    assertTrue(next(panes.runs.viewButtons) ~= nil, "the Runs bar has its buttons")
    for key, b in pairs(panes.runs.viewButtons) do assertTrue(b.tipChrome == true, "Runs bar " .. key) end
    i.NS.Results.ShowTab("insights")
    local ins = assert(i.NS.Results.__ui().panes.insights, "the Insights tab was never built")
    assertTrue(next(ins.viewButtons) ~= nil, "the Insights bar has its buttons")
    for key, b in pairs(ins.viewButtons) do assertTrue(b.tipChrome == true, "Insights bar " .. key) end
    i.scr.restore()
end)

test("tooltip place: a list's column header is a body element, beside the window", function()
    local i = inst()
    i.NS.Results.Show()
    local pane = i.NS.Results.__ui().panes.runs
    local head = pane.list.heads[1]
    local win = geo(i.NS.ResultsTable.WindowOf(head), 1500, 300, 300, 400)
    geo(head, 1510, 640, 60, 20)
    head:GetScript("OnEnter")(head)
    beside(i, win, head, "left", "a column header")
    owned(i, "the header")
    i.scr.restore()
end)

test("tooltip place: the HUD's footer lines are chrome, attached above", function()
    local i = inst()
    i.NS.Hud.Show()
    local u = i.NS.Hud.__ui()
    geo(u.frame, 100, 300, 300, 400)
    local zone = geo(u.footLeftTip, 110, 302, 120, 20)
    zone:__fire("OnEnter")
    above(i, zone, "the footer's left line")
    owned(i, "the footer")
    i.scr.restore()
end)

test("tooltip place: an Insights chart mark's tooltip goes through the Charts host's PlaceTip", function()
    local i = inst()
    local host = i.NS.ChartsHost()
    local win, mark = layout(i, 1500, 300, 620)
    local placed
    local ctx = { PlaceTip = function(_, tip, owner) placed = { tip = tip, owner = owner } end }
    host.tip(mark, { "Destruction", "Best 342.0k" }, "ANCHOR_CURSOR_RIGHT", ctx)
    assertTrue(placed ~= nil and placed.tip == i.tip and placed.owner == mark, "placed by ctx:PlaceTip on the mark")
    owned(i, "the chart host")
    -- Without a context (an older Charts), it places the body way itself.
    fresh(i)
    host.tip(mark, { "Destruction", "Best 342.0k" }, "ANCHOR_CURSOR_RIGHT")
    beside(i, win, mark, "left", "a mark with no context")
    i.scr.restore()
end)

-- ── where the library places nothing (review fixes) ────────────────────────────────────────────

-- A tooltip showing a secret spell: its width reads as a secret, so PlaceBeside places nothing.
local function secretWide(i) rawset(i.tip, "GetWidth", function() return T.secret(TIP_W) end) end

test("tooltip place: a body tooltip the library cannot measure goes beside its window, on the roomier side", function()
    -- red under: the fallback always went right of the window, so a window against the screen's right
    -- edge had its tooltip clamped back over it (body rule 3).
    local i = inst()
    secretWide(i)
    local Style = i.NS.Style
    local win, el = layout(i, 1500, 300, 620)
    Style.PlaceTip(i.tip, el, false, win)
    local p = i.tip.__point
    assertTrue(p ~= nil and p.point == "TOPRIGHT" and p.rel == win and p.relPoint == "TOPLEFT",
        "left of a window against the right edge, by a relative point")
    assertEqual(p.x, -2, "2 px off its left edge")
    assertEqual(p.y, -80, "level with the element")
    win, el = layout(i, 100, 300, 620)
    fresh(i)
    Style.PlaceTip(i.tip, el, false, win)
    p = i.tip.__point
    assertTrue(p ~= nil and p.point == "TOPLEFT" and p.rel == win and p.relPoint == "TOPRIGHT",
        "right of a window near the left edge")
    assertEqual(p.x, 2, "2 px off its right edge")
    owned(i, "the fallback")
    i.scr.restore()
end)

test("tooltip place: a body tooltip with no window to stand beside is attached above its element", function()
    local i = inst()
    secretWide(i)
    local _, el = layout(i, 1500, 300, 620)
    i.NS.Style.PlaceTip(i.tip, el, false, el)
    local p = i.tip.__point
    assertTrue(p ~= nil and p.point == "BOTTOM" and p.rel == el and p.relPoint == "TOP" and p.y == 2,
        "a plain attach 2 px above the element, never the cursor")
    i.scr.restore()
end)

test("tooltip place: an Insights board tab is chrome, its tooltip attached above it", function()
    local i = inst()
    local host = i.NS.ChartsHost()
    local _, tab = layout(i, 1500, 300, 620)
    tab.tipChrome = true
    local placed
    local ctx = { PlaceTip = function() placed = true end }
    host.tip(tab, { "Overall", "3 runs" }, "ANCHOR_CURSOR_RIGHT", ctx)
    assertTrue(placed == nil, "not placed beside the window by ctx:PlaceTip")
    above(i, tab, "a board tab")
    owned(i, "a board tab")
    i.scr.restore()
end)

test("tooltip place: an item tooltip is placed again when it grows while its element owns it", function()
    -- red under: placed once after Show, so an item whose data arrived later grew the tooltip past
    -- the clamp read at the first placement (Tooltip v1, *Replace*).
    local i = inst()
    local win, el = layout(i, 1500, 300, 400)
    i.NS.Style.PlaceItemTip(i.tip, el, win)
    beside(i, win, el, "left", "an item tooltip")
    i.tip:__size(TIP_W, 600)
    fresh(i)
    i.tip:__fire("OnSizeChanged", TIP_W, 600)
    local _, b, r, t = i.scr.rectOf(i.tip)
    assertTrue(b ~= nil and b >= 0, "the grown tooltip clamped onto the screen")
    assertEqual(t, 600, "its top moved up to keep it on the screen")
    assertEqual(r, win:GetLeft() - 2, "still 2 px left of the window")
    i.tip:__fire("OnHide")
    fresh(i)
    i.tip:__fire("OnSizeChanged", TIP_W, 80)
    assertEqual(i.scr.ops(i.tip), "", "hidden, it forgets the element")
    i.scr.restore()
end)

-- ── the guard ──────────────────────────────────────────────────────────────────────────────────

test("tooltip place: no addon file anchors a tooltip to the cursor or a corner", function()
    local bad = {}
    for _, rel in ipairs(T.loadedAddonFiles) do
        if rel:match("%.lua$") then
            local fh = assert(io.open(T.root .. "/" .. rel, "r"))
            local n = 0
            for line in fh:lines() do
                n = n + 1
                local code = line:gsub("%-%-.*$", "")
                for anchor in code:gmatch("\"(ANCHOR_[%u_]+)\"") do
                    if anchor ~= "ANCHOR_NONE" then bad[#bad + 1] = rel .. ":" .. n .. " " .. anchor end
                end
                if code:find("GetCursorPosition", 1, true) and code:find("SetPoint", 1, true) then
                    bad[#bad + 1] = rel .. ":" .. n .. " a point from the cursor"
                end
            end
            fh:close()
        end
    end
    assertEqual(table.concat(bad, ", "), "", "tooltip anchors the placement rule retires")
end)
