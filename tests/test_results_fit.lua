-- tests/test_results_fit.lua — the Results lists' widths against their content (modules/Results_Runs.lua,
-- modules/Results_Bests.lua, modules/Results_Table.lua): every Runs column fits the narrowest list
-- either view lays out and the Bests Flags chips fit their column (the boxed chips' own fit is
-- tests/test_results_badges.lua's). Widths are the table's own estimate (Tbl.BadgeWidth: 6 px a
-- character), never a measured one.

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

test("results: the Bests Flags chips are plain, and a two-flag best fits its column", function()
    local NS = inst().NS
    local col
    for _, c in ipairs(NS.ResultsBests.Columns()) do
        if c.key == "flags" then col = c end
    end
    assertEqual(col.boxed, nil, "only the Runs list's Status tags are boxed")
    local run = { status = "complete", flags = { lateCasts = { { t = 1.4, spellID = 29722 } }, reloaded = true } }
    local s = col.text(run)
    assertEqual(s, "1 late \194\183 Reloaded")
    assertTrue(NS.ResultsTable.BadgeWidth(s, col.boxed) <= col.width, "a two-flag chip runs past the Flags column")
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
