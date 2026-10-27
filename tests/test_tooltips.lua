-- tests/test_tooltips.lua — the body of every tooltip the addon draws itself (modules/Style.lua's
-- AddTipLines, through modules/Results_Table.lua's BelowTip, SideTip and SpellTip and the shared
-- button's tooltip in modules/Hud_States.lua): two or more lines under the title go on bullets, each
-- in its own color; one line stays plain; the client's own spell text is never touched.

local T = _G.DPSRACE_TEST
local test, assertEqual = T.test, T.assertEqual
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

--- A fresh instance with the widget recorder and a GameTooltip that records each line and its color.
local function inst()
    local i = T.load{ mutate = function(m) Widgets.install(m) end }
    local tip = { lines = {}, colors = {} }
    for _, m in ipairs({ "Show", "Hide", "ClearAllPoints", "SetPoint" }) do tip[m] = function() end end
    function tip.SetOwner() tip.lines, tip.colors, tip.spell = {}, {}, nil end
    function tip.SetText(_, text) tip.lines[1] = text end
    function tip.AddLine(_, text, r, g, b)
        tip.lines[#tip.lines + 1] = text
        tip.colors[#tip.lines] = { r, g, b }
    end
    function tip.SetSpellByID(_, id) tip.spell, tip.lines[1] = id, "the client's spell text" end
    function tip.NumLines() return #tip.lines end
    function tip.GetWidth() return 300 end
    function tip.GetEffectiveScale() return 1 end
    i.mocks.GameTooltip = tip
    i.mocks.UIParent = i.mocks.UIParent or {}
    i.mocks.UIParent.GetRight = function() return 1920 end
    i.mocks.UIParent.GetEffectiveScale = function() return 1 end
    i.tip, i.B = tip, i.NS.Style.BULLET
    return i
end

test("tooltips: one line under the title stays plain; the title never takes a bullet", function()
    local i = inst()
    assertEqual(i.B, "\226\128\162 ")
    i.NS.ResultsTable.BelowTip(i.mocks.CreateFrame("Frame"), { "Title", "Only line" })
    assertEqual(i.tip.lines[1], "Title")
    assertEqual(i.tip.lines[2], "Only line")
end)

test("tooltips: two or more lines go on bullets in their own colors, a dim footer hint among them", function()
    local i = inst()
    i.NS.ResultsTable.BelowTip(i.mocks.CreateFrame("Frame"), { "Title", "First", { "Hint", 0.62, 0.62, 0.68 } })
    assertEqual(i.tip.lines[1], "Title")
    assertEqual(i.tip.lines[2], i.B .. "First")
    assertEqual(i.tip.lines[3], i.B .. "Hint", "the dim footer is a body line")
    assertEqual(i.tip.colors[2][1], 0.9, "a plain line keeps its light gray")
    assertEqual(i.tip.colors[3][1], 0.62, "a colored line keeps its color")
end)

test("tooltips: after the client's spell text only the addon's own lines count, and only they take bullets", function()
    local i = inst()
    local window = { GetTop = function() return 0 end, GetRight = function() return 0 end,
                     GetEffectiveScale = function() return 1 end }
    i.NS.ResultsTable.SpellTip(window, nil, 1122, { "Cast at 0:01" })
    assertEqual(i.tip.lines[1], "the client's spell text", "the client's text is untouched")
    assertEqual(i.tip.lines[#i.tip.lines], "Cast at 0:01", "one line of its own stays plain")
    i.NS.ResultsTable.SpellTip(window, nil, 1122, { "Cast at 0:01", "This run" })
    assertEqual(i.tip.lines[1], "the client's spell text")
    assertEqual(i.tip.lines[#i.tip.lines - 1], i.B .. "Cast at 0:01")
    assertEqual(i.tip.lines[#i.tip.lines], i.B .. "This run")
end)

test("tooltips: a shared button's { title, text, ... } follows the same rule", function()
    local i = inst()
    local b = i.NS.HudStates.Button(i.mocks.UIParent, "Go", function() end)
    b.tip = { "Go", "One", "Two" }
    b:__fire("OnEnter")
    assertEqual(i.tip.lines[1], "Go")
    assertEqual(i.tip.lines[2], i.B .. "One")
    assertEqual(i.tip.lines[3], i.B .. "Two")
    b.tip = { "Go", "One" }
    b:__fire("OnEnter")
    assertEqual(i.tip.lines[2], "One")
end)
