-- tests/test_results_fit.lua — the Results lists' widths against their content (modules/Results_Runs.lua,
-- modules/Results_Bests.lua, modules/Results_Table.lua): every Runs column fits the narrowest list
-- either view lays out, the longest Status board fits after its box, and the Bests Flags chips fit
-- their column. Widths are the table's own estimate (Tbl.BadgeWidth: 6 px a character), never a
-- measured one.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local function inst()
    return T.load{ mutate = function(m) Widgets.install(m) end }
end

-- Visible characters in a UTF-8 string (a continuation byte is never one).
local function chars(s)
    return select(2, s:gsub("[^\128-\191]", ""))
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

test("results: the longest Status board fits after the boxed Spec best", function()
    local NS = inst().NS
    local Tbl, L = NS.ResultsTable, NS.L
    -- The box holds the trophy and "Spec best"; the trail starts 4 px after it. The longest board is
    -- the longest category label with a custom length: "single target · 10:00".
    local box = Tbl.BadgeWidth(L["Spec best"], true, Tbl.BADGE_ICON + 2)
    local longest = ""
    for _, label in pairs(NS.Dummies.LABELS) do
        if chars(label) > chars(longest) then longest = label end
    end
    local board = L["%s \194\183 %s"]:format(longest:lower(), "10:00")
    assertEqual(board, "single target \194\183 10:00")
    assertTrue(box + 4 + chars(board) * 6 <= NS.ResultsRuns.STATUS_W, "the longest Status board is cut off")
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
