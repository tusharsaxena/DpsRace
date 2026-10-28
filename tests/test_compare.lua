-- tests/test_compare.lua — the run detail's compare (modules/Results_Compare.lua, #7): the pure spell
-- match (matching by id, one-sided spells, the order, zero totals), the figures and their % difference,
-- the other run (the best on the board, the runner-up when the run holds it, a picked run, none), and
-- the detail drawing it: the toggle, the score table, the compared breakdown, the row menu's pick,
-- Clear Pick, the different-board note, the tooltips and both views.
--
-- Every case runs on a fresh instance with the widget recorder (tests/mock_widgets.lua). Runs are
-- seeded straight into the store in spec §7's shape.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600
local DASH = "\226\128\148"

local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
    end }
    i.R, i.Cmp = i.NS.Results, i.NS.ResultsCompare
    return i
end

--- A stored-shape complete 3:00 cleave run by Lanfear (Destruction). `dps` sets the score; `fields`
--- replaces any top-level field.
local function mkRun(id, dps, fields)
    local run = {
        id = id, schema = 1, status = "complete", addon = "0.1.0", date = NOW - HOUR,
        race = { length = 180, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction" },
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 180, dps = dps, tail = 2 },
        flags = { lateCasts = {} },
        spells = { { id = 29722, dmg = dps * 100 }, { id = 116858, dmg = dps * 80 } },
        note = "",
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    return run
end

local function seed(i, runs)
    for _, run in ipairs(runs) do i.NS.db.global.runs[run.id] = run end
    i.NS.Bests.Invalidate()
end

local function detail(i) return assert(i.R.__ui(), "the window was never built").detail end

local function ids(rows)
    local out = {}
    for n, r in ipairs(rows) do out[n] = tostring(r.id) end
    return table.concat(out, ",")
end

-- ── pure: the spell match ───────────────────────────────────────────────────────────────────────

test("compare: CompareSpells matches by id, with each side's damage, share and the difference", function()
    local i = inst()
    local a = { result = { damage = 1000 }, spells = { { id = 1, dmg = 600 }, { id = 2, dmg = 400 } } }
    local b = { result = { damage = 2000 }, spells = { { id = 2, dmg = 500 }, { id = 1, dmg = 1500 } } }
    local rows = i.NS.ResultsDetail.CompareSpells(a, b)
    assertEqual(i.NS.ResultsDetail.CompareSpells, i.Cmp.Spells, "the detail's name for the same function")
    assertEqual(ids(rows), "1,2")
    assertEqual(rows[1].dmgA, 600)
    assertEqual(rows[1].dmgB, 1500)
    assertEqual(rows[1].shareA, 60)
    assertEqual(rows[1].shareB, 75)
    assertEqual(rows[1].delta, -900)
    assertEqual(rows[2].shareB, 25)
    assertEqual(rows[2].delta, -100)
    assertTrue(math.abs(rows[1].pct + 60) < 1e-9, "600 against 1500: the % of the other's damage")
    assertTrue(math.abs(rows[2].pct + 20) < 1e-9)
end)

test("compare: a spell on one side only has nil damage and share on the other", function()
    local i = inst()
    local a = { result = { damage = 100 }, spells = { { id = 1, dmg = 70 }, { id = 3, dmg = 30 } } }
    local b = { result = { damage = 100 }, spells = { { id = 1, dmg = 50 }, { id = 2, dmg = 50 } } }
    local rows = i.Cmp.Spells(a, b)
    assertEqual(ids(rows), "1,3,2", "the run's spells first, a spell it never cast after")
    assertEqual(rows[2].dmgB, nil, "the other never cast spell 3")
    assertEqual(rows[2].shareB, nil)
    assertEqual(rows[2].delta, 30, "a missing side counts 0 in the difference")
    assertEqual(rows[2].pct, nil, "no % against a spell the other never cast")
    assertEqual(rows[3].dmgA, nil, "this run never cast spell 2")
    assertEqual(rows[3].shareA, nil)
    assertEqual(rows[3].delta, -50)
    assertEqual(rows[3].pct, -100, "a spell this run never cast is all lost")
    local none = i.Cmp.Spells(a, nil)
    assertEqual(ids(none), "1,3", "no other run: the run's spells alone")
    assertEqual(none[1].dmgB, nil)
end)

test("compare: rows sort by the run's damage, then the other's, then the id", function()
    local i = inst()
    local a = { result = { damage = 100 }, spells = { { id = 9, dmg = 10 }, { id = 5, dmg = 40 }, { id = 7, dmg = 10 },
                                                    { id = 8, dmg = 10 } } }
    local b = { result = { damage = 100 }, spells = { { id = 7, dmg = 30 }, { id = 4, dmg = 5 }, { id = 6, dmg = 60 },
                                                    { id = 8, dmg = 30 } } }
    -- 5 (40); then 7, 8 and 9 tie on 10: the other's 30, 30 and nothing; 7 before 8 on the id; then
    -- the other's own spells by their damage, 6 (60) before 4 (5).
    assertEqual(ids(i.Cmp.Spells(a, b)), "5,7,8,9,6,4")
end)

test("compare: a zero or missing damage total leaves the shares nil; duplicated ids add up", function()
    local i = inst()
    local a = { result = { damage = 0 }, spells = { { id = 1, dmg = 0 } } }
    local b = { spells = { { id = 1, dmg = 10 }, { id = 1, dmg = 5 }, { dmg = 99 } } }
    local rows = i.Cmp.Spells(a, b)
    assertEqual(#rows, 1, "an entry with no id was matched")
    assertEqual(rows[1].shareA, nil, "a share of a zero total")
    assertEqual(rows[1].shareB, nil, "a share with no total")
    assertEqual(rows[1].dmgB, 15, "a duplicated id is one spell")
    assertEqual(rows[1].delta, -15)
    assertEqual(#i.Cmp.Spells({}, {}), 0, "two runs with no spells")
end)

test("compare: the figures and their % difference; none against a zero or missing figure", function()
    local i = inst()
    local k = i.Cmp.Kpis(mkRun("a", 110), mkRun("b", 100))
    assertEqual(k.dpsA, 110)
    assertEqual(k.dpsB, 100)
    assertTrue(math.abs(k.dpsPct - 10) < 1e-9)
    assertTrue(math.abs(k.damagePct - 10) < 1e-9)
    assertEqual(i.Cmp.Pct(5, 0), nil)
    assertEqual(i.Cmp.Pct(nil, 5), nil)
    assertEqual(i.Cmp.Pct(5, "x"), nil)
    assertEqual(i.Cmp.SpellFigure(nil, nil), DASH, "a side without the spell shows a dash")
    assertEqual(i.Cmp.SpellFigure(1500, nil), "1.5K", "no share without a total")
    assertEqual(i.Cmp.DeltaText(0), "0")
    assertEqual(i.Cmp.DeltaText(2500), "+2.5K")
    assertEqual(k.damageDelta, 1800, "the damage difference as an amount")
    assertEqual(k.dpsDelta, 10)
    assertEqual(i.Cmp.Kpis(mkRun("a", 110), nil).dpsDelta, nil, "no amount without the other run")
end)

test("compare: the Difference cell is the amount, then the % in the bars' muted green or red", function()
    local i = inst()
    local Cmp = i.Cmp
    -- The escapes are the bars' own colors (Compare.BAR_UP / BAR_DOWN) as hex.
    assertEqual(Cmp.DiffText(78300, 2.34), "+78.3K |cff8fcc94+2.3%|r", "ahead: the % in the soft green")
    assertEqual(Cmp.DiffText(-710200, -14.44), "-710.2K |cffdb8585-14.4%|r", "behind: the % in the soft red")
    assertEqual(Cmp.DiffText(5000, nil), "+5.0K", "no % against an other figure of 0 or missing")
    assertEqual(Cmp.DiffText(0, 0), "0", "no difference: no %")
    assertEqual(Cmp.DiffText(nil, 3), DASH, "no amount: a dash")
    local up, down = Cmp.BAR_UP, Cmp.BAR_DOWN
    assertEqual(("%02x%02x%02x"):format(math.floor(up[1] * 255 + 0.5), math.floor(up[2] * 255 + 0.5),
        math.floor(up[3] * 255 + 0.5)), "8fcc94")
    assertEqual(("%02x%02x%02x"):format(math.floor(down[1] * 255 + 0.5), math.floor(down[2] * 255 + 0.5),
        math.floor(down[3] * 255 + 0.5)), "db8585")
end)

-- ── pure: the other run ─────────────────────────────────────────────────────────────────────────

test("compare: the default is the best on the run's board; for the best itself, the runner-up", function()
    local i = inst()
    local best, mid, low = mkRun("best", 300), mkRun("mid", 200), mkRun("low", 100)
    local otherBoard = mkRun("other", 900, { race = { length = 60, grace = 1 } })
    seed(i, { best, mid, low, otherBoard })
    local other, kind = i.Cmp.Default(low)
    assertEqual(other.id, "best")
    assertEqual(kind, "best")
    other, kind = i.Cmp.Default(best)
    assertEqual(other.id, "mid", "the best compares with the runner-up on its board")
    assertEqual(kind, "runnerUp")
    assertEqual(i.Cmp.Default(otherBoard), nil, "alone on its board: nothing to compare with")
    local inc = mkRun("inc", 50, { status = "incomplete" })
    seed(i, { inc })
    assertEqual(i.Cmp.Default(inc).id, "best", "an incomplete run compares with its board's best")
    assertEqual(i.Cmp.Default(mkRun("lost", 1, { status = "lost", result = false })), nil, "a lost run has no score")
    local runs = { best, low }
    assertEqual(i.Cmp.Default(best, runs).id, "low", "over a given list")
end)

test("compare: a picked run wins while it is stored and not the run itself", function()
    local i = inst()
    local best, low = mkRun("best", 300), mkRun("low", 100)
    local other = mkRun("other", 900, { race = { length = 60, grace = 1 } })
    seed(i, { best, low, other })
    local pick, kind = i.Cmp.Target(low, "other")
    assertEqual(pick.id, "other", "a pick on another board is allowed")
    assertEqual(kind, "picked")
    assertFalse(i.Cmp.SameBoard(low, other))
    assertTrue(i.Cmp.SameBoard(low, best))
    assertEqual(i.Cmp.Target(low, "low").id, "best", "the run picked against itself")
    assertEqual(i.Cmp.Target(low, "gone").id, "best", "a pick no longer stored")
    assertEqual(i.Cmp.ToggleLabel("best"), "Compare vs best")
    assertEqual(i.Cmp.ToggleLabel("runnerUp"), "Compare vs runner-up")
    assertEqual(i.Cmp.ToggleLabel("picked", other), "Compare vs " .. os.date("%d %b %H:%M", other.date))
end)

-- ── the detail ──────────────────────────────────────────────────────────────────────────────────

test("compare: the toggle sets the run beside the best: the score table and the compared breakdown", function()
    local i = inst()
    seed(i, { mkRun("best", 300), mkRun("low", 100) })
    i.R.ShowRun("low")
    local d = detail(i)
    local x = d.cmp
    assertTrue(x.toggle:IsEnabled())
    assertEqual(x.toggle.label.__text, "Compare vs best")
    local Tbl = i.NS.ResultsTable
    assertEqual(x.toggle.__hitInsets[2], -(1 + Tbl.BadgeWidth("Compare vs best", false)),
        "a click on the words toggles it too: the click area runs over the label")
    assertFalse(d:Comparing(), "the compare starts off")
    assertEqual(d:CompareTarget(), nil, "no target while off")
    assertEqual(d:CompareTarget(true).id, "best", "the toggle's target, asked for either way")
    assertFalse(x.score:IsShown())
    assertTrue(d.w.list.parent:IsShown())
    x.toggle:__fire("OnClick")
    assertTrue(d:Comparing())
    local other, kind = d:CompareTarget()
    assertEqual(other.id, "best")
    assertEqual(kind, "best")
    assertTrue(x.score:IsShown())
    assertFalse(d.w.list.parent:IsShown(), "the plain breakdown still shows under the compared one")
    assertEqual(x.head[3].__text, "Best run")
    assertEqual(x.lines[1][2].__text, "18.0K", "this run's damage")
    assertEqual(x.lines[1][3].__text, "54.0K", "the best's damage")
    assertEqual(x.lines[1][4].__text, "-36.0K |cffdb8585-66.7%|r", "the damage difference, then its %")
    assertEqual(x.lines[2][4].__text, "-200 |cffdb8585-66.7%|r", "the DPS difference, then its %")
    assertEqual(x.lines[2][4].__color[1], 1.0, "a slower run's difference is red")
    local _, active = i.NS.Pool.Counts(x.rows)
    assertEqual(active, 2, "one compared row per spell")
    local rows = x.rows.active
    assertEqual(rows[1].texts[1].__text, "Incinerate")
    assertEqual(rows[1].texts[2].__text, "10.0K |cff9e9ead55.6%|r", "the damage, then its share in the caption gray")
    assertEqual(rows[1].texts[3].__text, "30.0K |cff9e9ead55.6%|r")
    assertEqual(rows[1].texts[4].__text, "-20.0K |cffdb8585-66.7%|r")
    local red = i.NS.ResultsTable.COLORS.red
    assertEqual(rows[1].texts[4].__color[1], red[1], "the amount in the table's red")
    assertEqual(rows[1].texts[4].__color[2], red[2])
    x.toggle:__fire("OnClick")
    assertFalse(d:Comparing())
    assertFalse(x.score:IsShown())
    assertTrue(d.w.list.parent:IsShown(), "the plain breakdown is back")
    _, active = i.NS.Pool.Counts(x.rows)
    assertEqual(active, 0, "the compared rows were left drawn")
end)

test("compare: This run right, Best run left; each header at its column's x, width and justify", function()
    local i = inst()
    seed(i, { mkRun("best", 300), mkRun("low", 100) })
    i.R.ShowRun("low")
    local d = detail(i)
    d:SetComparing(true)
    local x = d.cmp
    assertEqual(x.head[3].__text, "Best run", "the compared column's name")
    assertEqual(x.spellHead[3].__text, "Best run")
    local justify = { "LEFT", "RIGHT", "LEFT", "RIGHT" }
    local function same(head, cell, j, what)
        assertEqual(head.__justifyH, justify[j], what .. " header " .. j .. "'s justify")
        assertEqual(cell.__justifyH, justify[j], what .. " column " .. j .. "'s justify")
        assertEqual(head.__points[1][4], cell.__points[1][4], what .. " column " .. j .. ": the header's x")
        assertEqual(head.__width, cell.__width, what .. " column " .. j .. ": the header's width")
    end
    for j = 2, 4 do
        same(x.head[j], x.lines[1][j], j, "score")
        same(x.head[j], x.lines[2][j], j, "score")
        same(x.spellHead[j], x.rows.active[1].texts[j], j, "spell")
    end
    local thisX, thisW = x.spellHead[2].__points[1][4], x.spellHead[2].__width
    assertTrue(x.spellHead[3].__points[1][4] > thisX + thisW, "the two runs' columns overlap")
end)

test("compare: the score table has no box, its columns are the spell table's, and a rule sits between them", function()
    for _, view in ipairs({ "expanded", "collapsed" }) do
        local i = inst()
        seed(i, { mkRun("best", 300), mkRun("low", 100) })
        i.NS.db.profile.windows.results = { view = view }
        i.R.ShowRun("low")
        local d = detail(i)
        d:SetComparing(true)
        local x, Cmp = d.cmp, i.Cmp
        local cw = d.content.__width
        assertEqual(x.score.__template, nil, view .. ": the score table is drawn in a backdrop box (Tbl.Panel)")
        -- Both tables hang off the pane's left edge, so a column's x is the same number in each.
        assertEqual(x.score.__points[1][4], 0, view .. ": the score table's left edge")
        assertEqual(x.spellHost.__points[1][4], 0, view .. ": the spell table's left edge")
        for j = 2, 4 do
            local cx, w, justify = Cmp.Cell(j, cw)
            for _, fs in ipairs({ x.head[j], x.lines[1][j], x.lines[2][j], x.spellHead[j], x.rows.active[1].texts[j] }) do
                assertEqual(fs.__points[1][4], cx, view .. ": column " .. j .. "'s x differs between the tables")
                assertEqual(fs.__width, w, view .. ": column " .. j .. "'s width differs between the tables")
                assertEqual(fs.__justifyH, justify, view .. ": column " .. j .. "'s justify differs between the tables")
            end
        end
        assertEqual(x.head[1].__points[1][4], x.spellHead[1].__points[1][4], view .. ": the name columns' x")
        assertEqual(x.head[1].__width, x.spellHead[1].__width, view .. ": the name columns' width")
        -- The rule: one pixel, across the table, under the DPS line and above the spell header.
        local rule = x.rule
        assertTrue(rule:IsShown(), view .. ": no rule between the tables")
        assertEqual(rule.__height, 1)
        assertEqual(rule.__width, cw, view .. ": the rule runs across the table")
        assertEqual(rule.__points[1][2], x.score)
        local ruleY = rule.__points[1][5]
        -- A score line's figures sit on its middle (a LEFT anchor), so the line's bottom is half its height lower.
        local dpsBottom = x.lines[2][2].__points[1][5] - Cmp.ScoreLineH() / 2
        assertTrue(ruleY < dpsBottom, view .. ": the rule runs through the DPS line")
        local scoreY, hostY = x.score.__points[1][5], x.spellHost.__points[1][5]
        assertTrue(hostY < scoreY + ruleY - 1, view .. ": the spell header sits on the rule")
        assertTrue(x.lines[1].bar:IsShown(), view .. ": the score table's bars are gone")
    end
end)

test("compare: one bar per row, on the higher run's side, its length the row's % difference against the table's", function()
    local i = inst()
    local low = mkRun("low", 100, { spells = { { id = 1, dmg = 10000 }, { id = 2, dmg = 30000 }, { id = 3, dmg = 500 },
                                               { id = 4, dmg = 800 } } })
    local best = mkRun("best", 300, { spells = { { id = 1, dmg = 30000 }, { id = 2, dmg = 24000 }, { id = 3, dmg = 500 } } })
    seed(i, { best, low })
    i.R.ShowRun("low")
    local d = detail(i)
    d:SetComparing(true)
    local x, Cmp = d.cmp, i.Cmp
    local vw = Cmp.Columns(d.content.__width).value   -- each run's column at the detail's width
    local byID = {}
    for _, row in ipairs(x.rows.active) do byID[row.data.id] = row end
    -- The spell table: 30000 vs 24000 (+25%), 10000 vs 30000 (-66.7%, the largest), 500 vs 500, and
    -- 800 against nothing (no %: the whole scale).
    local up, down, even, only = byID[2].bar, byID[1].bar, byID[3].bar, byID[4].bar
    assertEqual(up.side, "this", "this run is higher: the bar sits in its column")
    assertEqual(down.side, "other", "the best is higher: the bar sits in its column")
    assertFalse(even:IsShown(), "a bar for an equal row")
    assertTrue(up:IsShown() and down:IsShown())
    assertEqual(down.__width, vw, "the largest difference fills its column")
    assertTrue(math.abs(up.__width - vw * 25 / (200 / 3)) < 1e-9, "the length is the %'s share of the largest %")
    assertEqual(only.side, "this")
    assertEqual(only.__width, vw, "a row with no % takes the whole scale")
    assertEqual(byID[4].texts[4].__text, "+800", "and shows no %")
    -- This run's bar ends at its column's right edge; the other's starts at its column's left edge.
    local tx, tw = byID[2].texts[2].__points[1][4], byID[2].texts[2].__width
    assertEqual(up.__points[1][4] + up.__width, tx + tw + Cmp.PAD, "this run's bar grows left from its right edge")
    assertEqual(down.__points[1][4], byID[1].texts[3].__points[1][4] - Cmp.PAD,
        "the best's bar grows right from its left edge")
    -- The score table: its own scale, damage and DPS both -66.7%, so both fill the column.
    local dmg = x.lines[1].bar
    assertEqual(dmg.side, "other")
    assertEqual(dmg.__width, vw, "the table's largest % fills its column")
    assertEqual(x.lines[2].bar.side, "other")
    assertEqual(x.lines[2].bar.__width, vw)
    -- The pure parts.
    assertEqual(Cmp.Bar(0, 5, vw), nil, "equal runs draw no bar")
    assertEqual(Cmp.Bar(5, 0, vw), nil)
    local side, len = Cmp.Bar(-9, 3, vw)
    assertEqual(side, "other")
    assertEqual(len, vw, "a bar never runs past its column")
    assertEqual(Cmp.MaxPct({ { pct = 3 }, { pct = -7 }, {} }), 7)
    assertEqual(Cmp.MaxPct({}), 0)
    local diff, scale = Cmp.Scaled(-2.5, -100, 10)
    assertEqual(diff, -2.5)
    assertEqual(scale, 10)
    assertEqual(select(2, Cmp.Bar(-2.5, 10, vw)), vw / 4, "-2.5% against a 10% table: a quarter of the column")
    diff, scale = Cmp.Scaled(nil, -40, 10)
    assertEqual(diff, -1)
    assertEqual(scale, 1, "no %: the whole scale, on the delta's side")
    assertEqual(Cmp.Scaled(nil, 0, 10), nil, "no difference: no bar")
    diff, scale = Cmp.Scaled(nil, 40, 0)
    assertEqual(diff / scale, 1, "no % anywhere in the table: still the whole column")
end)

test("compare: the Difference column fits the detail at both views' minimum widths, with nothing clipped", function()
    local W = "-710.2K -100.0%"   -- the widest likely cell: a six-figure amount and a three-digit %
    for _, view in ipairs({ "expanded", "collapsed" }) do
        local i = inst()
        seed(i, { mkRun("best", 300), mkRun("low", 100) })
        -- Each view opens at its minimum width (its default; tests/test_schema.lua pins the two equal).
        i.NS.db.profile.windows.results = { view = view }
        i.R.ShowRun("low")
        local d = detail(i)
        d:SetComparing(true)
        local x, Cmp, Tbl = d.cmp, i.Cmp, i.NS.ResultsTable
        local cw = d.content.__width
        assertTrue(cw and cw > 0, view .. ": the detail's content width")
        if view == "expanded" then
            assertEqual(cw, i.R.DETAIL_WIDTH - 24, "expanded: the 440 px detail less its pads")
        end
        assertTrue(Tbl.BadgeWidth(W) <= Cmp.DIFF_W, view .. ": the widest Difference runs past its column")
        local function fits(fs, right, what)
            local plain = fs.__text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            assertTrue(Tbl.BadgeWidth(plain) <= fs.__width, view .. ": " .. what .. " is clipped")
            assertTrue(fs.__points[1][4] + fs.__width <= right, view .. ": " .. what .. " runs past the pane")
        end
        for n = 1, 2 do fits(x.lines[n][4], cw, "score line " .. n .. "'s Difference") end
        for _, row in ipairs(x.rows.active) do fits(row.texts[4], cw, "a spell's Difference") end
        fits(x.head[4], cw, "the score header")
        fits(x.spellHead[4], cw, "the spell header")
        assertTrue(x.lines[1][1].__width >= Tbl.BadgeWidth("Damage"), view .. ": the score table's names are squeezed")
        assertTrue(x.rows.active[1].texts[1].__width >= 40, view .. ": the spell names are squeezed")
    end
end)

test("compare: the best compares with the runner-up; a run alone on its board has the toggle disabled", function()
    local i = inst()
    seed(i, { mkRun("best", 300), mkRun("low", 100), mkRun("solo", 500, { race = { length = 60, grace = 1 } }) })
    i.R.ShowRun("best")
    local d = detail(i)
    assertEqual(d.cmp.toggle.label.__text, "Compare vs runner-up")
    d:SetComparing(true)
    assertEqual(d.cmp.head[3].__text, "Runner-up")
    assertEqual(d.cmp.lines[2][4].__text, "+200 |cff8fcc94+200.0%|r")
    assertEqual(d.cmp.lines[2][4].__color[2], i.NS.ResultsTable.COLORS.green[2], "the amount in the table's green")
    i.R.ShowRun("solo")
    assertFalse(d.cmp.toggle:IsEnabled(), "nothing to compare with, and the toggle is live")
    assertFalse(d:Comparing(), "comparing with nothing")
    assertFalse(d.cmp.score:IsShown())
    assertTrue(d.w.list.parent:IsShown())
end)

test("compare: the row menu's pick, the different-board note and Clear Pick", function()
    local i = inst()
    local other = mkRun("other", 900, { race = { length = 60, grace = 1 }, date = NOW - 2 * HOUR })
    seed(i, { mkRun("best", 300), mkRun("low", 100), other, mkRun("lost", 1, { status = "lost", result = false }) })
    i.R.ShowRun("low")
    local d = detail(i)
    assertFalse(d.cmp.clear:IsShown(), "Clear Pick with no pick")
    -- The menu's entry: live on another run, grayed on the run in the detail and on a lost one.
    assertTrue(i.R.RowMenu(other, d.frame))
    local menu = i.mocks.__lastMenu
    assertTrue(menu:Find("Compare With This Run").enabled)
    i.R.RowMenu(i.NS.Recorder.Get("low"), d.frame)
    assertFalse(i.mocks.__lastMenu:Find("Compare With This Run").enabled, "comparing a run with itself")
    i.R.RowMenu(i.NS.Recorder.Get("lost"), d.frame)
    assertFalse(i.mocks.__lastMenu:Find("Compare With This Run").enabled, "a lost run has nothing to compare")
    menu:Click("Compare With This Run")
    assertEqual(i.R.Pick(), "other")
    assertEqual(i.R.Selected(), "low", "the pick changed the run in the detail")
    assertTrue(d:Comparing(), "picking turns the compare on")
    assertEqual(d:CompareTarget().id, "other")
    assertEqual(d.cmp.toggle.label.__text, "Compare vs " .. os.date("%d %b %H:%M", other.date))
    assertEqual(d.cmp.head[3].__text, "Picked")
    assertTrue(d.cmp.clear:IsShown())
    assertTrue(d.cmp.boards:IsShown(), "the boards differ and no note says so")
    -- The pick holds across runs; on the same board the note goes.
    i.R.ShowRun("best")
    assertEqual(d:CompareTarget().id, "other")
    i.R.CompareWith("low")
    assertEqual(d:CompareTarget().id, "low")
    assertFalse(d.cmp.boards:IsShown(), "a note for runs on one board")
    d.cmp.clear:__fire("OnClick")
    assertEqual(i.R.Pick(), nil)
    assertEqual(d.cmp.toggle.label.__text, "Compare vs runner-up", "clearing returns to the board")
    assertFalse(d.cmp.clear:IsShown())
    -- A picked run deleted: back to the board's best.
    i.R.CompareWith("other")
    i.R.ShowRun("low")
    i.NS.Recorder.Delete("other")
    assertEqual(d:CompareTarget().id, "best")
    assertFalse(i.R.CompareWith("lost"), "a lost run picked")
    -- The picked run opened itself: the toggle falls back to the board, Clear Pick still shows.
    i.R.CompareWith("best")
    i.R.ShowRun("best")
    assertTrue(d.cmp.clear:IsShown(), "no way to clear the pick from the picked run")
    d.cmp.clear:__fire("OnClick")
    assertEqual(i.R.Pick(), nil)
    assertFalse(d.cmp.clear:IsShown())
end)

test("compare: the toggle, Clear Pick, the note, the score table and each compared row have tooltips", function()
    local i = inst()
    local other = mkRun("other", 900, { race = { length = 60, grace = 1 } })
    seed(i, { mkRun("best", 300), mkRun("low", 100), other })
    local Tips = i.NS.ResultsTips
    local low, best = i.NS.Recorder.Get("low"), i.NS.Recorder.Get("best")
    for _, key in ipairs({ "toggle", "clear", "score" }) do
        local lines = Tips.Compare(key, low, best, "best")
        assertTrue(type(lines) == "table" and type(lines[1]) == "string", key .. " has a tooltip")
    end
    assertEqual(Tips.Compare("boards", low, other, "picked")[1], "Different board")
    assertEqual(Tips.Compare("score", low, best, "best")[2], "Damage: 18,000 against 54,000 (-66.7%)")
    assertTrue(Tips.Compare("toggle", low, nil)[2]:find("No other complete run", 1, true) ~= nil,
        "the disabled toggle says why")
    local lost = mkRun("lostTip", 1, { status = "lost", result = false })
    assertEqual(Tips.Compare("toggle", lost, nil)[2], "This run has no score to compare (it was lost).",
        "a lost run's toggle names the real reason")
    local row = i.Cmp.Spells(low, best)[1]
    local lines = Tips.CompareSpell(row, "best")
    assertEqual(lines[1][1], "This run: 10,000 damage (55.6%)")
    assertEqual(lines[2], "Best run: 30,000 damage (55.6%)")
    assertEqual(lines[3], "Difference: -20,000")
    assertEqual(Tips.CompareSpell({ id = 1, dmgB = 5, delta = -5 }, "picked")[1][1], "This run: not cast")

    -- Drawn: the score table's hover under itself, a row's beside the window after the spell.
    local shown = {}
    i.mocks.GameTooltip = setmetatable({}, { __index = function(_, k)
        return function(_, a, b)
            if k == "SetOwner" then shown = { owner = a, anchor = b } end
            if k == "SetSpellByID" then shown.spell = a end
            if k == "NumLines" then return 4 end
            if k == "GetWidth" or k == "GetEffectiveScale" then return 1 end
        end
    end })
    i.mocks.UIParent = { GetRight = function() return 1920 end, GetEffectiveScale = function() return 1 end }
    i.R.ShowRun("low")
    local d = detail(i)
    d:SetComparing(true)
    local window = i.NS.ResultsTable.WindowOf(d.frame)
    window.GetRight = function() return 1200 end
    window.GetTop = function() return 800 end
    window.GetEffectiveScale = function() return 1 end
    d.cmp.score:__fire("OnEnter")
    assertEqual(shown.owner, d.cmp.score)
    assertEqual(shown.anchor, "ANCHOR_BOTTOM")
    d.cmp.rows.active[1]:__fire("OnEnter")
    assertEqual(shown.spell, 29722, "a compared row shows its spell's tooltip")
    assertEqual(shown.anchor, "ANCHOR_NONE")
end)

test("compare: the collapsed view draws the compare in the list's place; no number is read off a frame", function()
    local i = inst()
    seed(i, { mkRun("best", 300), mkRun("low", 100) })
    i.NS.db.profile.windows.results = { view = "collapsed" }
    i.R.ShowRun("low")
    local d = detail(i)
    assertTrue(d.frame:IsShown())
    assertTrue(d.narrow, "the collapsed view's detail")
    local reads = #i.mocks.__widgets.geomReads
    d:SetComparing(true)
    assertTrue(d.cmp.score:IsShown())
    local _, active = i.NS.Pool.Counts(d.cmp.rows)
    assertEqual(active, 2)
    assertEqual(#i.mocks.__widgets.geomReads, reads, "the compare read a size or a position back")
    assertTrue(d.contentH > 0)
    -- Back to the expanded view: the compare stays on and draws again at the detail's width.
    i.R.SetView("expanded")
    i.R.ShowRun("low")
    assertTrue(d:Comparing(), "the view switch turned the compare off")
    _, active = i.NS.Pool.Counts(d.cmp.rows)
    assertEqual(active, 2)
end)

-- ── the flex columns, the separator and the stripes ─────────────────────────────────────────────

test("compare: the columns flex with the width: the name column a share of it up to its cap, the figures the rest", function()
    local i = inst()
    local Cmp = i.Cmp
    assertEqual(i.R.DETAIL_WIDTH, 440, "the expanded view's detail")
    local function check(width, name, value, diff)
        local c = Cmp.Columns(width)
        assertEqual(c.name, name, width .. ": the name column")
        assertEqual(c.value, value, width .. ": each run's column")
        assertEqual(c.diff, diff, width .. ": the Difference column")
        assertEqual(c[1], name + Cmp.NAME_GAP, width .. ": this run's x")
        assertEqual(c[2], c[1] + value + Cmp.GAP, width .. ": the other run's x")
        assertEqual(c[3], c[2] + value, width .. ": the Difference's x")
        assertEqual(c[3] + diff, width, width .. ": the table fills its width")
        assertEqual(Cmp.SeparatorX(width), c[1] + value + 2, width .. ": the separator, centered in the gap")
    end
    -- The expanded minimum's detail (440 less its pads): the name its share (the owner's 2026-10-27
    -- call: P11's 152 px was too wide), the figures a little past their least.
    check(i.R.DETAIL_WIDTH - 24, 134, Cmp.VALUE_W + 6, Cmp.DIFF_W + 6)
    check(440, 140, Cmp.VALUE_W + 12, Cmp.DIFF_W + 12)
    -- A spell's name there keeps about 115 px of text past its icon (Cell's x less the icon and its pads).
    local text = Cmp.Columns(i.R.DETAIL_WIDTH - 24)[1] - (i.NS.HudBreakdown.RowHeight() - 2) - 8
    assertTrue(text >= 110 and text <= 120, "the expanded view's name text: " .. text)
    -- A 1200 px collapsed detail (1176 of content): the name at its cap (and the rounding's pixel), the
    -- figures every other pixel, grown alike.
    check(1176, Cmp.NAME_MAX + 1, Cmp.VALUE_W + 237, Cmp.DIFF_W + 237)
    -- Between: the name at its cap, the figures grown alike.
    local c = Cmp.Columns(700)
    assertTrue(c.name >= Cmp.NAME_MAX and c.name < Cmp.NAME_MAX + 3, "the name at its most (and the rounding's pixels)")
    assertEqual(c.value - Cmp.VALUE_W, c.diff - Cmp.DIFF_W, "the figure columns grow alike")
    assertTrue(c.value > Cmp.VALUE_W)
    -- Too narrow for the share: the figures keep their least and the name what they leave.
    check(340, 340 - Cmp.GAP - Cmp.NAME_GAP - 2 * Cmp.VALUE_W - Cmp.DIFF_W, Cmp.VALUE_W, Cmp.DIFF_W)
end)

test("compare: a 1200 px collapsed detail draws both tables across its width, a separator between the runs", function()
    for _, case in ipairs({ { view = "expanded", cw = 416 }, { view = "collapsed", cw = 1176 } }) do
        local i = inst()
        seed(i, { mkRun("best", 300), mkRun("low", 100) })
        i.NS.db.profile.windows.results = { view = case.view, collapsed = { width = 1202, height = 560 } }
        i.R.ShowRun("low")
        local d = detail(i)
        d:SetComparing(true)
        local x, Cmp = d.cmp, i.Cmp
        local cw = d.content.__width
        assertEqual(cw, case.cw, case.view .. ": the detail's content width")
        local cols = Cmp.Columns(cw)
        local row = x.rows.active[1]
        for j = 2, 4 do
            local cx, w = Cmp.Cell(j, cw)
            assertEqual(x.spellHead[j].__points[1][4], cx, case.view .. ": column " .. j .. "'s x")
            assertEqual(x.spellHead[j].__width, w, case.view .. ": column " .. j .. "'s width")
            assertEqual(row.texts[j].__points[1][4], cx, case.view .. ": a row's column " .. j)
            assertEqual(x.lines[1][j].__points[1][4], cx, case.view .. ": the score table shares column " .. j)
        end
        assertEqual(row.texts[4].__points[1][4] + row.texts[4].__width, cw, case.view .. ": Difference at the right edge")
        assertEqual(x.head[1].__width, cols.name, case.view .. ": the score table's name column")
        assertEqual(row.texts[1].__width, cols[1] - (i.NS.HudBreakdown.RowHeight() - 2) - 8, case.view .. ": a spell's name column")
        -- The separator: one per table, the same x, through every line at full height.
        local sx = Cmp.SeparatorX(cw)
        -- One pixel and faint (the owner's 2026-10-27 call: P11's line read too heavy).
        assertEqual(Cmp.SEP_W, 1)
        assertTrue(Cmp.SEP_COLOR[4] >= 0.15 and Cmp.SEP_COLOR[4] <= 0.2, "the separator's alpha, dim")
        for _, t in ipairs({ { x.scoreSep, x.score, Cmp.ROW_H + 2 * Cmp.ScoreLineH() }, { x.spellSep, x.spellHost,
                Cmp.ROW_H + #x.data * i.NS.HudBreakdown.Pitch() } }) do
            local sep, parent, h = t[1], t[2], t[3]
            assertTrue(sep:IsShown(), case.view .. ": no separator")
            assertEqual(sep.__points[1][2], parent)
            assertEqual(sep.__points[1][4], sx, case.view .. ": the separator's x")
            assertEqual(sep.__width, Cmp.SEP_W)
            assertEqual(sep.__height, h, case.view .. ": the separator's height")
            assertEqual(sep.__vertex[1], Cmp.SEP_COLOR[1], case.view .. ": the separator's gray")
            assertEqual(sep.__vertex[4], Cmp.SEP_COLOR[4], case.view .. ": the separator's alpha")
        end
        local thisRight = x.spellHead[2].__points[1][4] + x.spellHead[2].__width + Cmp.PAD
        assertTrue(sx >= thisRight and sx + Cmp.SEP_W <= x.spellHead[3].__points[1][4] - Cmp.PAD,
            case.view .. ": the separator sits between the runs' columns")
    end
end)

test("compare: the separator draws one physical pixel wide at any UI scale, not one UI unit", function()
    local i = inst()
    seed(i, { mkRun("best", 300), mkRun("low", 100) })
    i.R.ShowRun("low")
    local d = detail(i)
    d:SetComparing(true)
    local x, Cmp = d.cmp, i.Cmp
    -- No PixelUtil (or no numeric scale): the config's SEP_W as it stands.
    assertEqual(Cmp.SepWidth(0.64), Cmp.SEP_W)
    -- A 1440p screen: one physical pixel is 768 / 1440 UI units at scale 1, more at a smaller scale.
    local factor = 768 / 1440
    i.mocks.PixelUtil = { GetPixelToUIUnitFactor = function() return factor end }
    assertEqual(Cmp.SepWidth(nil), Cmp.SEP_W, "a missing scale")
    for _, scale in ipairs({ 0.64, 1, 1.15 }) do
        assertTrue(math.abs(Cmp.SepWidth(scale) * scale / factor - Cmp.SEP_W) < 1e-9, scale .. ": not one pixel")
        for _, sep in ipairs({ x.scoreSep, x.spellSep }) do
            rawset(sep, "GetEffectiveScale", function() return scale end)
        end
        i.R.ShowRun("low")
        assertTrue(d:Comparing())
        for _, sep in ipairs({ x.scoreSep, x.spellSep }) do
            assertTrue(sep:IsShown())
            -- The drawn width in physical pixels: the UI width times the scale, over the factor.
            local px = sep.__width * scale / factor
            assertTrue(math.abs(px - 1) < 1e-9, scale .. ": the separator draws " .. px .. " physical pixels")
        end
    end
end)

test("compare: Damage and DPS in the spell names' white, each after a game icon at the spell icons' size and x", function()
    local cases = { { view = "expanded" }, { view = "collapsed" }, { view = "expanded", rowHeight = 26 },
        { view = "expanded", rowHeight = 30 } }
    for _, case in ipairs(cases) do
        local i = inst()
        seed(i, { mkRun("best", 300), mkRun("low", 100) })
        i.NS.db.profile.windows.results = { view = case.view }
        if case.rowHeight then i.NS.db.profile.appearance.bars.rowHeight = case.rowHeight end
        i.R.ShowRun("low")
        local d = detail(i)
        d:SetComparing(true)
        local x, Cmp = d.cmp, i.Cmp
        local what = case.view .. (case.rowHeight and " at a " .. case.rowHeight .. " px row" or "")
        local row = x.rows.active[1]
        local name, side = row.texts[1], i.NS.HudBreakdown.RowHeight() - 2
        assertEqual(Cmp.IconSize(), side, what .. ": the spell icons' size")
        assertEqual(row.icon.__width, side)
        assertEqual(row.icon.__points[1][4], 0, what .. ": a spell icon's x")
        local icons = { "Interface\\Icons\\Ability_DualWield", "Interface\\Icons\\INV_Misc_PocketWatch_01" }
        assertEqual(Cmp.DAMAGE_ICON, icons[1], "crossed swords for Damage")
        assertEqual(Cmp.DPS_ICON, icons[2], "a pocket watch for DPS")
        for n, label in ipairs({ "Damage", "DPS" }) do
            local line = x.lines[n]
            local fs, icon = line[1], line.icon
            assertEqual(fs.__text, label)
            -- The spell names' white and font, not the caption gray.
            assertEqual(fs.__fontObject, name.__fontObject, what .. ": " .. label .. "'s font")
            for c = 1, 3 do assertEqual(fs.__color[c], name.__color[c], what .. ": " .. label .. "'s color") end
            assertEqual(fs.__color[1], i.NS.ResultsTable.COLORS.text[1], label .. " is not the spell names' white")
            -- The icon: a plain built-in texture, the spell icons' size, at the spell icons' x with the
            -- label 4 px past it, so the label starts where a spell's name does.
            assertEqual(icon.__texture, icons[n], what .. ": " .. label .. "'s icon")
            assertTrue(icon:IsShown(), what .. ": " .. label .. "'s icon is hidden")
            assertEqual(icon.__width, side, what .. ": " .. label .. "'s icon width")
            assertEqual(icon.__height, side, what .. ": " .. label .. "'s icon height")
            local pt = icon.__points[1]
            assertEqual(pt[1], "LEFT"); assertEqual(pt[2], x.score); assertEqual(pt[3], "TOPLEFT")
            assertEqual(pt[4], row.icon.__points[1][4], what .. ": " .. label .. "'s icon x")
            assertEqual(fs.__points[1][4] - 4 - side, pt[4], what .. ": " .. label .. " starts 4 px past its icon")
            -- Centered on its own line, as a spell row's icon and name are: the icon, the label and the
            -- figures share the line's middle, and the icon stays inside the line (never above its top,
            -- in the header, or below its bottom).
            local lineH = Cmp.ScoreLineH()
            local top = -Cmp.ROW_H - (n - 1) * lineH
            assertEqual(pt[5], top - lineH / 2, what .. ": " .. label .. "'s icon on its line's middle")
            for j = 1, 4 do
                assertEqual(line[j].__points[1][1], "LEFT", what .. ": " .. label .. " column " .. j .. "'s anchor")
                assertEqual(line[j].__points[1][5], pt[5], what .. ": " .. label .. " column " .. j .. " off its icon's middle")
            end
            assertTrue(pt[5] + side / 2 <= top, what .. ": " .. label .. "'s icon runs above its line")
            assertTrue(pt[5] - side / 2 >= top - lineH, what .. ": " .. label .. "'s icon runs below its line")
            local bar = line.bar.__points[1]
            assertEqual(bar[5], top, what .. ": " .. label .. "'s bar starts at its line's top")
            assertEqual(line.bar.__height, lineH - 1, what .. ": " .. label .. "'s bar height")
            assertEqual(fs.__points[1][4], name.__points[1][4], what .. ": " .. label .. " starts where a spell's name does")
            assertEqual(fs.__width, name.__width, what .. ": " .. label .. "'s width")
        end
        -- The lines make room for the icons: one line's icon never reaches into the next.
        local lineH = Cmp.ScoreLineH()
        assertTrue(lineH >= side + 1 and lineH >= Cmp.ROW_H, what .. ": the score lines overlap their icons")
        assertEqual(x.lines[1][2].__points[1][5] - x.lines[2][2].__points[1][5], lineH, what .. ": the line pitch")
    end
end)

test("compare: every spell row alternates the Results list's stripe, compared and plain", function()
    local i = inst()
    local spells = {}
    for n = 1, 5 do spells[n] = { id = 1000 + n, dmg = 6000 - n * 1000 } end
    seed(i, { mkRun("best", 300), mkRun("low", 100, { spells = spells }) })
    i.R.ShowRun("low")
    local d = detail(i)
    local alpha = i.NS.ResultsTable.STRIPE_ALPHA
    assertTrue(alpha > 0)
    -- Plain: the breakdown list's rows, top down.
    assertTrue(d.w.list.parent:IsShown())
    assertEqual(d.w.list:Count(), 5)
    for n, row in ipairs(d.w.list.rows) do
        assertEqual(row.stripe.__vertex[4], n % 2 == 0 and alpha or 0, "plain row " .. n .. "'s stripe")
    end
    -- Compared: the matched rows, top down (by y).
    d:SetComparing(true)
    local rows = {}
    for _, row in ipairs(d.cmp.rows.active) do rows[#rows + 1] = row end
    table.sort(rows, function(a, b) return a.__points[1][5] > b.__points[1][5] end)
    assertEqual(#rows, 7, "the run's five spells and the best's two")
    for n, row in ipairs(rows) do
        assertEqual(row.bg.__vertex[4], n % 2 == 0 and alpha or 0, "compared row " .. n .. "'s stripe")
    end
    -- The HUD's list draws none.
    local hudList = i.NS.HudBreakdown.New(i.mocks.CreateFrame("Frame"))
    hudList:ShowResult({ spells = spells, result = { damage = 20000 } }, 5, true)
    for _, row in ipairs(hudList.rows) do assertEqual(row.stripe, nil, "a HUD row has a stripe") end
end)
