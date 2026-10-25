-- tests/test_results_tree.lua — the Results window and Blizzard's talent tree (modules/Results.lua):
-- the tree's panel open closes the window through the close stack (UISpecialFrames), the window
-- waits and comes back when the tree closes, View's step-aside, and Escape and the close control.
-- Peeled out of tests/test_results.lua (layout-§1's 1500-line cap).

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
    end }
    i.R = i.NS.Results
    return i
end

local function ui(i) return assert(i.R.__ui(), "the Results window was never built") end

-- Blizzard's close stack as the talent tree's panel open runs it: CloseSpecialWindows hides the
-- frame, then the tree shows, then the next frame comes.
local function closeStack(i, treeAfter)
    local tree = i.mocks.PlayerSpellsFrame
    ui(i).frame:Hide()
    ui(i).frame:__fire("OnHide")
    if treeAfter ~= nil then tree.shown = treeAfter end
    i.mocks.__fireTimers()
end

local function withTree(i, shown)
    local tree = { shown = shown }
    function tree:IsShown() return self.shown end
    i.mocks.PlayerSpellsFrame = tree
    return tree
end

test("results: the talent tree's panel open closes the window, and it comes back when the tree closes", function()
    local i = inst()
    local tree = withTree(i, false)
    i.R.Show()
    closeStack(i, true)
    assertFalse(i.R.wanted, "the window came back over the talent tree")
    assertFalse(ui(i).frame:IsShown())
    assertTrue(i.R.AwaitingTree(), "the window does not wait for the tree")
    i.mocks.__fireTimers()
    assertFalse(i.R.wanted, "the window came back while the tree is still up")
    tree.shown = false
    i.mocks.__fireTimers()
    assertTrue(i.R.wanted, "the window stayed closed after the tree closed")
    assertTrue(ui(i).frame:IsShown(), "the window is wanted but not shown")
    assertFalse(i.R.AwaitingTree(), "the wait outlived the tree")
end)

test("results: the player opening or closing the window ends its wait for the tree", function()
    local i = inst()
    local tree = withTree(i, false)
    i.R.Show()
    closeStack(i, true)
    assertTrue(i.R.AwaitingTree())
    i.R.Show()
    assertFalse(i.R.AwaitingTree(), "opening the window kept the wait")
    i.R.StepAsideForTree()
    assertFalse(i.R.wanted, "View's step-aside left the window over the tree")
    assertTrue(i.R.AwaitingTree())
    i.R.Hide()
    assertFalse(i.R.AwaitingTree(), "closing the window kept the wait")
    tree.shown = false
    i.mocks.__fireTimers()
    assertFalse(i.R.wanted, "a window the player closed came back after the tree")
end)

test("results: Escape with the talent tree up closes both, and the window stays closed", function()
    local i = inst()
    withTree(i, true)
    i.R.Show()
    closeStack(i, false)
    assertFalse(i.R.wanted, "Escape with the tree up did not close the window")
    assertFalse(ui(i).frame:IsShown())
end)

test("results: Escape with no talent tree closes the window for good", function()
    local i = inst()
    withTree(i, false)
    i.R.Show()
    closeStack(i, false)
    assertFalse(i.R.wanted, "the window came back with no tree")
    -- The client before the talent frame loads: no PlayerSpellsFrame at all.
    local j = inst()
    j.R.Show()
    closeStack(j)
    assertFalse(j.R.wanted, "the window came back with no talent frame loaded")
end)

test("results: the close control with the talent tree up closes the window alone", function()
    local i = inst()
    withTree(i, true)
    i.R.Show()
    -- In the client Hide runs OnHide at once, inside the window's own `hiding` bracket.
    local f = ui(i).frame
    local hide = f.Hide
    function f:Hide() hide(self); self:__fire("OnHide"); return self end
    local before = #i.mocks.__timers()
    i.R.Hide()
    assertEqual(#i.mocks.__timers(), before, "the window's own close armed the look")
    i.mocks.__fireTimers()
    assertFalse(i.R.wanted, "the close control's close was undone by the open tree")
end)
