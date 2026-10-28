-- tests/test_results_fit.lua — the Results list's widths against their content (modules/Results_Runs.lua,
-- modules/Results_Table.lua): every Runs column fits the narrowest list either view lays out, and the
-- filter bar fits both views (the boxed chips' own fit is tests/test_results_badges.lua's). Widths
-- are the table's own estimate (Tbl.BadgeWidth: 6 px a character), never a measured one.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local function inst()
    return T.load{ mutate = function(m) Widgets.install(m) end }
end

test("results: every Runs column fits the narrowest list either view lays out", function()
    local NS = inst().NS
    local Runs, R = NS.ResultsRuns, NS.Results
    for _, view in ipairs({ "collapsed", "expanded" }) do
        local body = R.VIEWS[view].minWidth - 2
        local listW = view == "expanded" and body - math.min(R.DETAIL_WIDTH, math.floor(body * 0.38)) or body
        local cols = Runs.Columns()
        local place = NS.ResultsTable.Columns(cols, listW)
        local last = place[#place]
        assertTrue(last.x + last.w + 6 + 8 <= listW, view .. ": the columns overflow the list")
        for n, col in ipairs(cols) do
            if col.flex then assertTrue(place[n].w >= col.min, view .. ": the Character column is squeezed") end
        end
    end
end)

test("results: the Runs filter bar fits inside both views' minimum width", function()
    local NS = inst().NS
    local Runs, R = NS.ResultsRuns, NS.Results
    -- The bar spans the window body (the window less its 1 px border each side), planned from the
    -- configured widths, never from a frame read.
    for view, oneRow in pairs({ expanded = true, collapsed = false }) do
        local body = R.VIEWS[view].minWidth - 2
        local plan = Runs.BarPlan(oneRow)
        assertTrue(plan.right <= body, view .. ": the filter bar runs past the window edge")
        assertTrue(plan.buttons.clear <= plan.right and plan.buttons.save < plan.buttons.clear,
            view .. ": the view buttons are out of order")
    end
end)

-- ── the filter bar fills the window (UT-P16) ────────────────────────────────────────────────────

local KEYS = { "char", "spec", "category", "length", "date", "group" }
local CONFIGURED = { char = 110, spec = 96, category = 96, length = 88, date = 100, group = 164 }

-- The plan's right edges: Group's and Clear's (a button's x is its right edge).
local function edges(plan)
    return plan.dropdowns.group + plan.widths.group, plan.buttons.clear
end

test("results: the Runs filter bar with no width, or only the room it needs, is the configured plan", function()
    local Runs = inst().NS.ResultsRuns
    for _, oneRow in ipairs({ true, false }) do
        local plan = Runs.BarPlan(oneRow)
        for _, key in ipairs(KEYS) do assertEqual(plan.widths[key], CONFIGURED[key], key .. ": configured") end
        -- Today's plan, as it was before the bar stretched.
        assertEqual(plan.dropdowns.char, 8)
        assertEqual(plan.dropdowns.group, 8 + 110 + 96 + 96 + 88 + 100 + 5 * 6)
        assertEqual(plan.right, oneRow and 1196 or 692)
        assertEqual(plan.buttons.clear, plan.right)
        for _, w in ipairs({ plan.right + 8, plan.right, 300 }) do
            local at = Runs.BarPlan(oneRow, w)
            assertEqual(at.right, plan.right, w .. ": no room past the configured plan")
            for _, key in ipairs(KEYS) do assertEqual(at.widths[key], CONFIGURED[key]) end
        end
    end
end)

test("results: the Runs filter bar ends on the window's right edge in both views, never under its widths", function()
    local NS = inst().NS
    local Runs, R = NS.ResultsRuns, NS.Results
    for view, oneRow in pairs({ expanded = true, collapsed = false }) do
        for _, body in ipairs({ R.VIEWS[view].minWidth - 2, 1600, 2001 }) do
            local plan = Runs.BarPlan(oneRow, body)
            local group, clear = edges(plan)
            local tag = view .. " at " .. body
            -- The same 8 px margin on the right as on the left.
            assertEqual(clear, body - 8, tag .. ": Clear's right edge")
            if not oneRow then assertEqual(group, body - 8, tag .. ": Group's right edge") end
            assertEqual(plan.right, body - 8)
            local x = 8
            for _, key in ipairs(KEYS) do
                assertTrue(plan.widths[key] >= CONFIGURED[key], tag .. ": " .. key .. " under its configured width")
                assertEqual(plan.dropdowns[key], x, tag .. ": " .. key .. " placed after the one before")
                x = x + plan.widths[key] + 6
            end
            -- In proportion: Group, the widest, grows the most.
            assertTrue(plan.widths.group - 164 >= plan.widths.char - 110, tag .. ": shared in proportion")
            if oneRow then
                assertTrue(plan.checks.hideFlagged == group + 6, tag .. ": the checkboxes follow Group")
            else
                assertEqual(plan.checks.hideFlagged, 8, tag .. ": the second row starts at the margin")
            end
        end
    end
end)

test("results: the Runs filter bar stretches with the window while the grip is dragged", function()
    local i = inst()
    local R = i.NS.Results
    R.Show()
    local u = R.__ui()
    local pane = u.panes.runs
    local group = pane.dropdowns.group
    local function right() return group.__points[#group.__points][4] + group.__width end
    assertEqual(u.width, 904, "a new profile opens collapsed at its minimum")
    assertEqual(right(), 902 - 8, "Group's right edge on the window's at the minimum")
    u.frame.resizeGrip:__fire("OnMouseDown", "LeftButton")
    i.mocks.__now = (i.mocks.__now or 0) + 1 / 60
    u.frame:__fire("OnSizeChanged", 1200, 600)
    assertEqual(right(), 1198 - 8, "followed the drag, before the release")
    local clear = pane.viewButtons.clear
    assertEqual(clear.__points[#clear.__points][4], 1198 - 8, "Clear under it")
    u.frame.resizeGrip:__fire("OnMouseUp")
    assertEqual(right(), 1198 - 8, "and the release")
end)
