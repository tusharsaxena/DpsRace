-- tests/test_compare.lua — the run detail's compare (modules/Results_Compare.lua, #7): the pure spell
-- match (matching by id, one-sided spells, the order, zero totals), the figures and their % difference,
-- and the other run (the best on the board, the runner-up when the run holds it, a picked run, none).
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
        target = { npcID = 225983, name = "Cleave Training Dummy", category = "cleave", count = 5 },
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
    assertEqual(rows[3].dmgA, nil, "this run never cast spell 2")
    assertEqual(rows[3].shareA, nil)
    assertEqual(rows[3].delta, -50)
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
