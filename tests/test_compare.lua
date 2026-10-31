-- tests/test_compare.lua — the run detail's compare (modules/Results_Compare.lua, #7): the pure spell
-- match (matching by id, one-sided spells, the order, zero totals), the figures and their % difference,
-- the other run (the best on the board, the runner-up when the run holds it, a picked run, none), and
-- the detail drawing it: the toggle, the score table, the compared breakdown, the row menu's pick,
-- Clear Pick, the different-board note, the tooltips and both views.
--
-- Every case runs on a fresh instance with the widget recorder (tests/mock_widgets.lua). Runs are
-- seeded straight into the store in spec §7's shape.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
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

test("compare: the Difference is two cells, the amount, then the % in its muted green or red", function()
    local i = inst()
    local Cmp = i.Cmp
    -- DR-06 (the owner's call, 2026-10-30): two columns under one header. The escapes are the bars'
    -- colors (Compare.DIFF_UP / DIFF_DOWN) as hex, which DR-F05 took off the bars and left here.
    assertEqual(Cmp.DiffAmount(78300), "+78.3K")
    assertEqual(Cmp.DiffPct(78300, 2.34), "|cff8fcc94+2.3%|r", "ahead: the % in the soft green")
    assertEqual(Cmp.DiffAmount(-710200), "-710.2K")
    assertEqual(Cmp.DiffPct(-710200, -14.44), "|cffdb8585-14.4%|r", "behind: the % in the soft red")
    assertEqual(Cmp.DiffPct(5000, nil), "", "no % against an other figure of 0 or missing")
    assertEqual(Cmp.DiffAmount(0), "0")
    assertEqual(Cmp.DiffPct(0, 0), "", "no difference: no %")
    assertEqual(Cmp.DiffAmount(nil), DASH, "no amount: a dash")
    assertEqual(Cmp.DiffPct(nil, 3), "", "and no %")
    assertTrue(Cmp.DiffText == nil, "the one-cell Difference is gone")
    local up, down = Cmp.DIFF_UP, Cmp.DIFF_DOWN
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
    assertEqual(x.lines[1][4].__text, "-36.0K", "the damage difference")
    assertEqual(x.lines[1][5].__text, "|cffdb8585-66.7%|r", "then its % in a column of its own (DR-06)")
    assertEqual(x.lines[2][4].__text, "-200", "the DPS difference")
    assertEqual(x.lines[2][5].__text, "|cffdb8585-66.7%|r")
    assertEqual(x.lines[2][4].__color[1], 1.0, "a slower run's difference is red")
    local _, active = i.NS.Pool.Counts(x.rows)
    assertEqual(active, 2, "one compared row per spell")
    local rows = x.rows.active
    assertEqual(rows[1].texts[1].__text, "Incinerate")
    assertEqual(rows[1].texts[2].__text, "10.0K |cff9e9ead55.6%|r", "the damage, then its share in the caption gray")
    assertEqual(rows[1].texts[3].__text, "30.0K |cff9e9ead55.6%|r")
    assertEqual(rows[1].texts[4].__text, "-20.0K")
    assertEqual(rows[1].texts[5].__text, "|cffdb8585-66.7%|r")
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
    local justify = { "LEFT", "RIGHT", "LEFT", "RIGHT", "RIGHT" }
    local function same(head, cell, j, what)
        assertEqual(head.__justifyH, justify[j], what .. " header " .. j .. "'s justify")
        assertEqual(cell.__justifyH, justify[j], what .. " column " .. j .. "'s justify")
        assertEqual(head.__points[1][4], cell.__points[1][4], what .. " column " .. j .. ": the header's x")
        assertEqual(head.__width, cell.__width, what .. " column " .. j .. ": the header's width")
    end
    for j = 2, 3 do
        same(x.head[j], x.lines[1][j], j, "score")
        same(x.head[j], x.lines[2][j], j, "score")
        same(x.head[j], x.rows.active[1].texts[j], j, "spell")
    end
    -- The one Difference header (DR-06): from the amount's left to the %'s right, right-aligned.
    for _, case in ipairs({ { x.head, x.lines[1] }, { x.head, x.lines[2] }, { x.head, x.rows.active[1].texts } }) do
        local head, amount, pct = case[1][4], case[2][4], case[2][5]
        assertEqual(head.__justifyH, "RIGHT")
        assertEqual(amount.__justifyH, "RIGHT", "the amount right-aligned")
        assertEqual(pct.__justifyH, "RIGHT", "the % right-aligned")
        assertEqual(head.__points[1][4], amount.__points[1][4], "the Difference header starts over the amount")
        assertEqual(head.__points[1][4] + head.__width, pct.__points[1][4] + pct.__width, "and ends over the %")
    end
    local thisX, thisW = x.head[2].__points[1][4], x.head[2].__width
    assertTrue(x.head[3].__points[1][4] > thisX + thisW, "the two runs' columns overlap")
end)

test("compare: one header row: Spell heads the first column, the first spell row hangs at the table's top", function()
    -- red under: the second header row over the spell rows (the owner's 2026-10-31 batch, DR-F03).
    for _, view in ipairs({ "expanded", "collapsed" }) do
        local i = inst()
        seed(i, { mkRun("best", 300), mkRun("low", 100) })
        i.NS.db.profile.windows.results = { view = view }
        i.R.ShowRun("low")
        local d = detail(i)
        d:SetComparing(true)
        local x = d.cmp
        assertNil(x.spellHead, view .. ": a second header row")
        assertEqual(x.head[1].__text, "Spell", view .. ": the first column's header")
        assertEqual(x.head[2].__text, "This run")
        assertEqual(x.head[4].__text, "Difference")
        assertEqual(x.head[1].__justifyH, "LEFT")
        assertEqual(x.rows.active[1].__points[1][5], 0, view .. ": the first spell row's y in its table")
        d:SetComparing(false)
        assertTrue(d.w.list.parent:IsShown(), view .. ": the plain list keeps its own form")
        assertFalse(x.score:IsShown(), view .. ": the header row goes with the compare")
    end
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
        local function sameBox(list, cx, w, justify, j)
            for _, fs in ipairs(list) do
                assertEqual(fs.__points[1][4], cx, view .. ": column " .. j .. "'s x differs between the tables")
                assertEqual(fs.__width, w, view .. ": column " .. j .. "'s width differs between the tables")
                assertEqual(fs.__justifyH, justify, view .. ": column " .. j .. "'s justify differs between the tables")
            end
        end
        for j = 2, 5 do
            local cx, w, justify = Cmp.Cell(j, cw)
            sameBox({ x.lines[1][j], x.lines[2][j], x.rows.active[1].texts[j] }, cx, w, justify, j)
        end
        for j = 2, 4 do
            local cx, w, justify = Cmp.HeadCell(j, cw)
            sameBox({ x.head[j] }, cx, w, justify, j)
        end
        assertEqual(x.head[1].__text, "Spell", view .. ": the first column's header")
        -- The rule: one pixel, across the table, under the DPS line and above the spell rows.
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
        assertTrue(hostY < scoreY + ruleY - 1, view .. ": the first spell row sits on the rule")
        assertTrue(x.lines[1].bar:IsShown(), view .. ": the score table's bars are gone")
    end
end)

test("compare: one bar per row, on the higher run's side, its length the row's % difference on the one scale", function()
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
    assertEqual(byID[4].texts[4].__text, "+800")
    assertEqual(byID[4].texts[5].__text, "", "and shows no %")
    -- This run's bar ends at its column's right edge; the other's starts at its column's left edge.
    local tx, tw = byID[2].texts[2].__points[1][4], byID[2].texts[2].__width
    assertEqual(up.__points[1][4] + up.__width, tx + tw + Cmp.PAD, "this run's bar grows left from its right edge")
    assertEqual(down.__points[1][4], byID[1].texts[3].__points[1][4] - Cmp.PAD,
        "the best's bar grows right from its left edge")
    -- The score table: on the one scale, damage and DPS both -66.7%, the spells' largest too.
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

-- A two-sided run pair for the DR-F05 bars: `this` and `other` its dps, spell 1 this run 10000 against
-- 20000 (-50%), spell 2 this run 30000 against 20000 (+50%), spell 3 this run's alone, spell 4 the
-- other's alone.
local function barPair(i, this, other)
    local a = mkRun("a", this, { spells = { { id = 1, dmg = 10000 }, { id = 2, dmg = 30000 }, { id = 3, dmg = 800 } } })
    local b = mkRun("b", other, { spells = { { id = 1, dmg = 20000 }, { id = 2, dmg = 20000 }, { id = 4, dmg = 900 } } })
    seed(i, { a, b })
    i.R.ShowRun("a")
    local d = detail(i)
    d:SetComparing(true)
    local byID = {}
    for _, row in ipairs(d.cmp.rows.active) do byID[row.data.id] = row end
    return d, byID
end

local function assertTint(i, bar, hue, what)
    local got = bar.__colorTex
    assertEqual(got[1], hue[1], what .. ": red")
    assertEqual(got[2], hue[2], what .. ": green")
    assertEqual(got[3], hue[3], what .. ": blue")
    assertEqual(got[4], i.Cmp.BAR_ALPHA, what .. ": the bars' alpha")
end

test("compare: Damage, DPS and the spells size their bars on one scale (DR-F05)", function()
    local i = inst()
    local d, byID = barPair(i, 80, 100)      -- both score lines -20%, the spell rows' -100% the largest
    local x, Cmp = d.cmp, i.Cmp
    local vw = Cmp.Columns(d.content.__width).value
    assertEqual(Cmp.BarScale({ { pct = -20 } }, { { pct = 50 }, { pct = -100 } }), 100, "the largest of both tables")
    assertEqual(Cmp.BarScale({ { pct = -20 } }, nil), 20, "no spells: the score lines' own")
    local rule = vw / 5
    assertTrue(math.abs(x.lines[1].bar.__width - rule) < 1e-9, "Damage at -20% is a fifth of a column on a 100% scale")
    assertTrue(math.abs(x.lines[2].bar.__width - rule) < 1e-9, "DPS the same")
    assertEqual(x.lines[1].bar.side, "other", "and on the higher run's side")
    assertEqual(byID[1].bar.__width, vw / 2, "a -50% spell, half the column on the same scale")
    assertEqual(byID[2].bar.__width, vw / 2, "a +50% spell the same")
    assertEqual(byID[4].bar.__width, vw, "the largest: the other run's lone spell, -100%")
    assertEqual(byID[3].bar.__width, vw, "a spell the other never cast takes the whole scale")
    assertEqual(byID[3].bar.side, "this")
end)

test("compare: the run with the more total damage is blue on every row, the other gold (DR-F05)", function()
    local i = inst()
    local gold, blue = i.NS.ResultsCompare.BAR_OTHER, i.NS.ResultsCompare.BAR_BEST
    -- The other run is best: this run's column gold, the other's blue, row by row whoever leads it.
    local d, byID = barPair(i, 80, 100)
    local x = d.cmp
    assertEqual(i.Cmp.BestSide(d.run, x.other), "other")
    assertTint(i, x.lines[1].bar, blue, "the other's Damage bar")
    assertTint(i, x.lines[2].bar, blue, "the other's DPS bar")
    assertTint(i, byID[1].bar, blue, "a spell the other leads")
    assertTint(i, byID[2].bar, gold, "a spell this run leads, in this run's column")
    assertTint(i, byID[3].bar, gold, "this run's lone spell")
    assertTint(i, byID[4].bar, blue, "the other's lone spell")
    -- This run is best: the same rows swap.
    i = inst()
    d, byID = barPair(i, 100, 80)
    x = d.cmp
    assertEqual(i.Cmp.BestSide(d.run, x.other), "this")
    assertTint(i, x.lines[1].bar, blue, "this run's Damage bar")
    assertTint(i, x.lines[2].bar, blue, "this run's DPS bar")
    assertTint(i, byID[1].bar, gold, "a spell the other leads, in the other's column")
    assertTint(i, byID[2].bar, blue, "a spell this run leads")
    -- The pure rule: one call per comparison, total damage, this run on a tie or a missing side.
    local Cmp = i.Cmp
    local function total(n) return { result = { damage = n } } end
    assertEqual(Cmp.BestSide(total(5), total(5)), "this", "an exact tie: this run")
    assertEqual(Cmp.BestSide(total(5), total(6)), "other")
    assertEqual(Cmp.BestSide(total(5), {}), "this", "a side with no damage")
    assertEqual(Cmp.BestSide({}, total(6)), "other")
    assertEqual(Cmp.BarColor("this", "this"), i.NS.ResultsCompare.BAR_BEST, "the best's side, the dark blue")
    assertEqual(Cmp.BarColor("other", "this"), i.NS.ResultsCompare.BAR_OTHER, "the other side, the dark gold")
    assertEqual(Cmp.BarColor("other", "other"), i.NS.ResultsCompare.BAR_BEST)
end)

test("compare: the column headed Best run is blue even when this run has more damage (DR-F05)", function()
    local i = inst()
    local gold, blue = i.NS.ResultsCompare.BAR_OTHER, i.NS.ResultsCompare.BAR_BEST
    -- An incomplete run ended early with more damage than the complete best: the board's best is
    -- still the other run, so the kind answers, not the totals.
    local best = mkRun("best", 100)
    local partial = mkRun("partial", 90, { status = "incomplete", result = { damage = 105 * 180, dps = 108.6, endedAt = 174 } })
    seed(i, { best, partial })
    i.R.ShowRun("partial")
    local d = detail(i)
    d:SetComparing(true)
    local x = d.cmp
    assertEqual(x.kind, "best")
    assertEqual(i.Cmp.BestSide(partial, best, x.kind), "other", "the other run holds the board")
    assertEqual(x.bars.best, "other", "the pane passes the kind")
    assertTint(i, x.lines[1].bar, gold, "this run's Damage bar, more damage but not the best")
    -- The pure rule by kind: only a picked run (or no kind) falls to the totals.
    local Cmp = i.Cmp
    local function total(n) return { result = { damage = n } } end
    assertEqual(Cmp.BestSide(total(6), total(5), "best"), "other", "the board's best, whatever the totals")
    assertEqual(Cmp.BestSide(total(5), total(5), "best"), "other", "a tie with the board's best")
    assertEqual(Cmp.BestSide(total(5), total(6), "runnerUp"), "this", "this run holds the board")
    assertEqual(Cmp.BestSide(total(5), total(6), "picked"), "other", "a pick: the totals")
    assertEqual(Cmp.BestSide(total(6), total(5), "picked"), "this")
    assertEqual(Cmp.BarColor(x.bars.best, x.bars.best), blue, "the best's column")
end)

test("compare: a picked run takes the same colors; the Difference keeps its green and red (DR-F05)", function()
    local i = inst()
    -- A picked run above this one on a different board: still total damage, not the board.
    local a = mkRun("a", 100, { spells = { { id = 1, dmg = 10000 } } })
    local b = mkRun("b", 120, { spells = { { id = 1, dmg = 20000 } }, race = { length = 60, grace = 1 },
                                result = { damage = 120 * 180, dps = 120, tail = 2 } })
    seed(i, { a, b })
    i.R.ShowRun("a")
    local d = detail(i)
    d.pickID = "b"
    d:SetComparing(true)
    local x = d.cmp
    assertEqual(x.kind, "picked")
    assertTint(i, x.lines[1].bar, i.NS.ResultsCompare.BAR_BEST, "the picked run has the more damage")
    local row = x.rows.active[1]
    -- Behind on a row: the amount in the table's red, the % in the muted red, whichever run is blue.
    assertEqual(row.texts[5].__text, "|cffdb8585-50.0%|r", "the muted red is unchanged")
    local red = i.NS.ResultsTable.COLORS.red
    assertEqual(row.texts[4].__color[1], red[1], "the amount's red")
end)

test("compare: the Difference column fits the detail at both views' minimum widths, with nothing clipped", function()
    -- The widest likely cells: a six-figure amount and a signed three-digit % with one decimal.
    local AMOUNT, PCT = "-710.2K", "-100.0%"
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
        assertTrue(Tbl.BadgeWidth(AMOUNT) + Cmp.DIFF_GAP + Cmp.PCT_W <= Cmp.DIFF_W,
            view .. ": the widest Difference runs past its column")
        local function fits(fs, right, what, text)
            local plain = (text or fs.__text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            assertTrue(Tbl.BadgeWidth(plain) <= fs.__width, view .. ": " .. what .. " is clipped")
            assertTrue(fs.__points[1][4] + fs.__width <= right, view .. ": " .. what .. " runs past the pane")
        end
        -- Two right-aligned columns (DR-06): the amount, DIFF_GAP, then the % ending at the pane's edge.
        local function pair(set, what)
            local amount, pct = set[4], set[5]
            fits(amount, cw, what .. "'s amount", AMOUNT)
            fits(pct, cw, what .. "'s %", PCT)
            assertEqual(amount.__justifyH, "RIGHT", what .. ": the amount right-aligned")
            assertEqual(pct.__justifyH, "RIGHT", what .. ": the % right-aligned")
            assertEqual(pct.__width, Cmp.PCT_W, what .. ": the % column's width")
            assertEqual(pct.__points[1][4] + pct.__width, cw, what .. ": the % ends at the pane's edge")
            assertEqual(amount.__points[1][4] + amount.__width + Cmp.DIFF_GAP, pct.__points[1][4],
                what .. ": a tight gap between the two")
        end
        for n = 1, 2 do pair(x.lines[n], "score line " .. n) end
        for _, row in ipairs(x.rows.active) do pair(row.texts, "a spell") end
        fits(x.head[4], cw, "the score header")
        -- One shared header over both columns, right-aligned over the %.
        local cols = Cmp.Columns(cw)
        for _, set in ipairs({ x.head }) do
            assertEqual(set[4].__points[1][4], cols[3], view .. ": the Difference header starts over the amount")
            assertEqual(set[4].__width, cols.diff, view .. ": and spans both columns")
            assertEqual(set[4].__justifyH, "RIGHT")
            assertNil(set[5], view .. ": no second header")
        end
        assertTrue(x.lines[1][1].__width >= Tbl.BadgeWidth("Damage"), view .. ": the score table's names are squeezed")
        assertTrue(x.rows.active[1].texts[1].__width >= 40, view .. ": the spell names are squeezed")
    end
end)

test("compare: the % column holds a signed three-digit % with one decimal in every skin", function()
    local i = inst()
    local Cmp, Tbl = i.Cmp, i.NS.ResultsTable
    -- Measured on the shipped faces at each skin's body size over Ka0s Default's (GameFontHighlightSmall,
    -- 10 px at Ka0s Default): "+100.0%" is 40.8 px at the widest (High Contrast's Atkinson), 38.0 under
    -- Ka0s Default, 33.5 under Obsidian; the outline adds about 2. The 6 px a character estimate holds them.
    for _, s in ipairs({ "+100.0%", "-100.0%" }) do
        assertTrue(Tbl.BadgeWidth(s) <= Cmp.PCT_W, s .. " runs past the % column")
    end
    assertTrue(Cmp.PCT_W >= 43, "under the widest measured skin's width with its outline")
    assertTrue(Cmp.DIFF_GAP > 0 and Cmp.DIFF_GAP <= Cmp.PAD, "a tight gap")
end)

test("compare: the best compares with the runner-up; a run alone on its board has the toggle disabled", function()
    local i = inst()
    seed(i, { mkRun("best", 300), mkRun("low", 100), mkRun("solo", 500, { race = { length = 60, grace = 1 } }) })
    i.R.ShowRun("best")
    local d = detail(i)
    assertEqual(d.cmp.toggle.label.__text, "Compare vs runner-up")
    d:SetComparing(true)
    assertEqual(d.cmp.head[3].__text, "Runner-up")
    assertEqual(d.cmp.lines[2][4].__text, "+200")
    assertEqual(d.cmp.lines[2][5].__text, "|cff8fcc94+200.0%|r")
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

    -- Drawn: every hover of the section beside the window, right of it (DR-05, the owner's call,
    -- 2026-10-30: the score table's opened under itself, over the spell table), a row's after the spell.
    local shown = {}
    i.mocks.GameTooltip = setmetatable({}, { __index = function(_, k)
        return function(_, a, b, c)
            if k == "SetOwner" then shown = { owner = a, anchor = b } end
            if k == "SetPoint" then shown.placed = { a, b, c } end
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
    local x = d.cmp
    for name, part in pairs({ toggle = x.toggle, clear = x.clear, boards = x.boardsHover, score = x.score }) do
        shown = {}
        part:__fire("OnEnter")
        assertTrue(shown.owner == window and shown.anchor == "ANCHOR_NONE", name .. ": owned by the window, not the part")
        assertTrue(shown.placed and shown.placed[1] == "TOPLEFT" and shown.placed[2] == window
            and shown.placed[3] == "TOPRIGHT", name .. ": right of the window")
    end
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
    check(i.R.DETAIL_WIDTH - 24, 135, Cmp.VALUE_W + 5, Cmp.DIFF_W + 5)
    check(440, 141, Cmp.VALUE_W + 11, Cmp.DIFF_W + 11)
    -- A spell's name there keeps about 115 px of text past its icon (Cell's x less the icon and its pads).
    local text = Cmp.Columns(i.R.DETAIL_WIDTH - 24)[1] - (i.NS.HudBreakdown.RowHeight() - 2) - 8
    assertTrue(text >= 110 and text <= 120, "the expanded view's name text: " .. text)
    -- A 1200 px collapsed detail (1176 of content): the name at its cap (and the rounding's pixels), the
    -- figures every other pixel, grown alike.
    check(1176, Cmp.NAME_MAX + 2, Cmp.VALUE_W + 236, Cmp.DIFF_W + 236)
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
        for j = 2, 5 do
            local cx = Cmp.Cell(j, cw)
            assertEqual(row.texts[j].__points[1][4], cx, case.view .. ": a row's column " .. j)
            assertEqual(x.lines[1][j].__points[1][4], cx, case.view .. ": the score table shares column " .. j)
        end
        for j = 2, 4 do
            local cx, w = Cmp.HeadCell(j, cw)
            assertEqual(x.head[j].__points[1][4], cx, case.view .. ": column " .. j .. "'s x")
            assertEqual(x.head[j].__width, w, case.view .. ": column " .. j .. "'s width")
        end
        assertEqual(row.texts[5].__points[1][4] + row.texts[5].__width, cw, case.view .. ": Difference at the right edge")
        assertEqual(x.head[1].__width, cols.name, case.view .. ": the score table's name column")
        assertEqual(row.texts[1].__width, cols[1] - (i.NS.HudBreakdown.RowHeight() - 2) - 8, case.view .. ": a spell's name column")
        -- The separator: one per table, the same x, through every line at full height.
        local sx = Cmp.SeparatorX(cw)
        -- One pixel and faint (the owner's 2026-10-27 call: P11's line read too heavy).
        assertEqual(Cmp.SEP_W, 1)
        assertTrue(Cmp.SEP_COLOR[4] >= 0.15 and Cmp.SEP_COLOR[4] <= 0.2, "the separator's alpha, dim")
        for _, t in ipairs({ { x.scoreSep, x.score, Cmp.ROW_H + 2 * Cmp.ScoreLineH() }, { x.spellSep, x.spellHost,
                #x.data * i.NS.HudBreakdown.Pitch() } }) do
            local sep, parent, h = t[1], t[2], t[3]
            assertTrue(sep:IsShown(), case.view .. ": no separator")
            assertEqual(sep.__points[1][2], parent)
            assertEqual(sep.__points[1][4], sx, case.view .. ": the separator's x")
            assertEqual(sep.__width, Cmp.SEP_W)
            assertEqual(sep.__height, h, case.view .. ": the separator's height")
            assertEqual(sep.__vertex[1], Cmp.SEP_COLOR[1], case.view .. ": the separator's gray")
            assertEqual(sep.__vertex[4], Cmp.SEP_COLOR[4], case.view .. ": the separator's alpha")
        end
        local thisRight = x.head[2].__points[1][4] + x.head[2].__width + Cmp.PAD
        assertTrue(sx >= thisRight and sx + Cmp.SEP_W <= x.head[3].__points[1][4] - Cmp.PAD,
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
    local alpha = i.NS.ResultsTable.StripeAlpha(2)   -- the skin's dr.list.stripe
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
