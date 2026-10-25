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

-- ── the detail ──────────────────────────────────────────────────────────────────────────────────

test("compare: the toggle sets the run beside the best: the score table and the compared breakdown", function()
    local i = inst()
    seed(i, { mkRun("best", 300), mkRun("low", 100) })
    i.R.ShowRun("low")
    local d = detail(i)
    local x = d.cmp
    assertTrue(x.toggle:IsEnabled())
    assertEqual(x.toggle.label.__text, "Compare vs best")
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
    assertEqual(x.head[3].__text, "Best")
    assertEqual(x.lines[1][2].__text, "18.0K", "this run's damage")
    assertEqual(x.lines[1][3].__text, "54.0K", "the best's damage")
    assertEqual(x.lines[2][4].__text, "-66.7%", "the DPS difference")
    assertEqual(x.lines[2][4].__color[1], 1.0, "a slower run's difference is red")
    local _, active = i.NS.Pool.Counts(x.rows)
    assertEqual(active, 2, "one compared row per spell")
    local rows = x.rows.active
    assertEqual(rows[1].texts[1].__text, "Incinerate")
    assertEqual(rows[1].texts[2].__text, "10.0K |cff9e9ead55.6%|r", "the damage, then its share in the caption gray")
    assertEqual(rows[1].texts[3].__text, "30.0K |cff9e9ead55.6%|r")
    assertEqual(rows[1].texts[4].__text, "-20.0K")
    x.toggle:__fire("OnClick")
    assertFalse(d:Comparing())
    assertFalse(x.score:IsShown())
    assertTrue(d.w.list.parent:IsShown(), "the plain breakdown is back")
    _, active = i.NS.Pool.Counts(x.rows)
    assertEqual(active, 0, "the compared rows were left drawn")
end)

test("compare: the best compares with the runner-up; a run alone on its board has the toggle disabled", function()
    local i = inst()
    seed(i, { mkRun("best", 300), mkRun("low", 100), mkRun("solo", 500, { race = { length = 60, grace = 1 } }) })
    i.R.ShowRun("best")
    local d = detail(i)
    assertEqual(d.cmp.toggle.label.__text, "Compare vs runner-up")
    d:SetComparing(true)
    assertEqual(d.cmp.head[3].__text, "Runner-up")
    assertEqual(d.cmp.lines[2][4].__text, "+200.0%")
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
    assertEqual(lines[2], "Best: 30,000 damage (55.6%)")
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
