-- tests/test_insights_data.lua — the Insights tab's pure half (#12, modules/Results_InsightsData.lua):
-- the filter (lost runs out, no Runs default leaking in), the faceted dropdown options with their counts,
-- the fallback to All, and the one stats pass: the cards, the boards and their % of board best, the
-- new bests, the per-character, per-length and per-day counts, the damage tail's buckets, the late
-- casts by spell with the ignored ones apart, and the spell share summed by ID. Also the Runs tab's
-- exported option lists (Runs.OptionLists, Runs.WithAll) that both tabs build on.
--
-- The fixture is shaped like the owner's data (docs/superpowers/plans/2026-10-28-ignore-list-insights.md,
-- Insights analysis), cut to nine runs: three characters, four boards, a day with no runs, a flagged run,
-- a run whose only late cast is Feign Death (clean under the default ignore list), an incomplete run
-- with a sealed late cast, a lost run and a 155 s damage tail.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FEIGN, HEARTH, INCINERATE = 5384, 8690, 29722
local BM, DESTRO, ELE = 253, 267, 262

local function day(n, hour)
    return os.time({ year = 2026, month = 10, day = 23 + n, hour = hour or 12, min = 0, sec = 0 })
end
local NOW = day(3, 23)

local CHARS = {
    hunt = { name = "Traxex", realm = "Frostmourne", class = "HUNTER", specID = BM, spec = "Beast Mastery" },
    lock = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = DESTRO, spec = "Destruction" },
    sham = { name = "Tiamat", realm = "Frostmourne", class = "SHAMAN", specID = ELE, spec = "Elemental" },
}

local function late(...)
    local out = {}
    for i, id in ipairs({ ... }) do out[i] = { t = 1 + i, spellID = id ~= false and id or nil } end
    return out
end

--- A stored-shape run: `who` names one of CHARS, then the target category, the race length, the date,
--- the DPS and the optional fields (status, tail, late casts, spells).
local function mk(id, who, category, length, date, dps, o)
    o = o or {}
    local c = CHARS[who]
    local status = o.status or "complete"
    local result
    if status == "incomplete" then
        result = { damage = dps * 12, dps = dps, endedAt = 12 }
    elseif status ~= "lost" then
        result = { damage = dps * length, dps = dps, tail = o.tail }
    end
    return {
        id = id, schema = 4, status = status, date = date,
        race = { length = length, grace = 1 },
        char = { name = c.name, realm = c.realm, class = c.class, specID = c.specID, spec = c.spec },
        target = { category = category },
        result = result,
        flags = { lateCasts = o.late or {}, reloaded = false, died = false },
        spells = o.spells or {},
    }
end

local function fixture()
    return {
        mk("h1", "hunt", "cleave", 120, day(0, 10), 400, { tail = 3,
            spells = { { id = 6603, dmg = 100 }, { id = 6603, dmg = 100 }, { id = 34026, dmg = 200 } } }),
        mk("l1", "lock", "cleave", 120, day(0, 11), 300, { tail = 21, late = late(INCINERATE, HEARTH) }),
        mk("h2", "hunt", "cleave", 120, day(1, 10), 440, { tail = 7,
            spells = { { id = 34026, dmg = 300 }, { id = 6603, dmg = 100 } } }),
        mk("h3", "hunt", "cleave", 120, day(1, 11), 420, { tail = 9.1 }),
        mk("h4", "hunt", "boss", 60, day(1, 12), 100, { tail = 12 }),
        mk("h5", "hunt", "boss", 60, day(3, 10), 125, { tail = 16, late = late(FEIGN) }),
        mk("l2", "lock", "cleave", 120, day(3, 11), 330, { tail = 4.9 }),
        mk("s1", "sham", "cleave", 30, day(3, 12), 200, { tail = 155 }),
        mk("s2", "sham", "cleave", 30, day(3, 13), 50, { status = "incomplete", late = late(false) }),
        mk("x1", "sham", "cleave", 30, day(3, 14), 0, { status = "lost" }),
    }
end

local function fresh()
    local inst = T.load()
    return inst.NS
end

local function ids(list)
    local out = {}
    for i, run in ipairs(list) do out[i] = run.id end
    return table.concat(out, ",")
end

local function near(a, b, msg)
    assertTrue(type(a) == "number" and math.abs(a - b) < 1e-6, ("%s: %s vs %s"):format(msg or "near", tostring(a), tostring(b)))
end

local function option(list, value)
    for _, o in ipairs(list) do if o.value == value then return o end end
    return nil
end

local function values(list)
    local out = {}
    for i, o in ipairs(list) do out[i] = tostring(o.value) end
    return table.concat(out, ",")
end

-- ── the Runs tab's exported lists ───────────────────────────────────────────────────────────────

test("insights: Runs.OptionLists has each list without its All head, and WithAll adds it", function()
    local NS = fresh()
    local Runs = NS.ResultsRuns
    local lists = Runs.OptionLists(fixture())
    assertEqual(#lists.char, 3)
    assertEqual(values(lists.length), "30,60,120")
    assertEqual(values(lists.category), "cleave,boss")
    assertEqual(#lists.spec, 3)
    assertEqual(values(Runs.OptionLists(fixture(), "length")), "30,60,120", "one list by its key")
    local headed = Runs.WithAll(Runs.OptionLists(fixture()).length, "Any length")
    assertEqual(headed[1].value, "all")
    assertEqual(headed[1].label, "Any length")
    assertEqual(#headed, 4, "no Current head unless one is asked for")
    local current = Runs.WithAll(Runs.OptionLists(fixture()).spec, "All specs", "Current spec")
    assertEqual(current[1].value, "current")
    assertEqual(current[2].value, "all")
    assertEqual(#Runs.DateOptions(), 4)
    assertEqual(Runs.DateOptions()[4].value, "30d")
end)

-- ── the filter ──────────────────────────────────────────────────────────────────────────────────

test("insights: Filter defaults wide, keeps lost runs out and maps Clean only to Hide flagged", function()
    local NS = fresh()
    local D, Runs = NS.InsightsData, NS.ResultsRuns
    local all = fixture()
    assertEqual(D.DEFAULTS.char, "all", "Insights is the cross-character view")
    assertFalse(D.DEFAULTS.cleanOnly)
    assertFalse(D.DEFAULTS.includeIncomplete)
    assertEqual(ids(D.Filter(all, nil, NOW)), "h1,l1,h2,h3,h4,h5,l2,s1", "complete runs of every character")
    assertEqual(ids(D.Filter(all, { includeIncomplete = true }, NOW)), "h1,l1,h2,h3,h4,h5,l2,s1,s2",
        "a lost run never counts, even with incomplete ones in")
    assertEqual(ids(D.Filter(all, { cleanOnly = true }, NOW)), "h1,h2,h3,h4,h5,l2,s1",
        "the Feign Death run is clean under the default list")
    assertEqual(ids(D.Filter(all, { spec = BM, length = 60 }, NOW)), "h4,h5")
    assertEqual(ids(D.Filter(all, { date = "today" }, NOW)), "h5,l2,s1")
    -- Parity: the same runs the Runs tab's filter passes with every key given.
    local f = { char = "all", spec = "all", category = "cleave", length = "all", date = "all",
                hideFlagged = true, includeIncomplete = false, onlyBest = false }
    assertEqual(ids(D.Filter(all, { category = "cleave", cleanOnly = true }, NOW)), ids(Runs.Filter(all, f, NOW)))
end)

-- ── the faceted options ─────────────────────────────────────────────────────────────────────────

test("insights: Options lists each facet's values among the runs every other filter passes, with counts", function()
    local NS = fresh()
    local D = NS.InsightsData
    local all = fixture()
    local o = D.Options(all, D.DEFAULTS, NOW)
    assertEqual(o.char[1].value, "all", "the All head leads")
    assertEqual(o.char[1].count, 8)
    assertEqual(#o.char, 4, "no Current character head")
    local hunt = option(o.char, "Traxex-Frostmourne")
    assertEqual(hunt.count, 5)
    assertEqual(hunt.label, "Traxex (5)")
    assertEqual(values(o.length), "all,30,60,120")
    assertEqual(option(o.length, 120).count, 5)
    -- Picking a spec narrows Length, and the spec list itself keeps every spec.
    local f = { spec = BM }
    o = D.Options(all, f, NOW)
    assertEqual(values(o.length), "all,60,120")
    assertEqual(option(o.length, 60).count, 2)
    assertEqual(#o.spec, 4, "the facet's own filter never narrows it")
    assertEqual(option(o.spec, DESTRO).count, 2)
    -- A selection that matches nothing is still offered, at 0.
    f = { spec = BM, length = 30 }
    o = D.Options(all, f, NOW)
    assertEqual(option(o.length, 30).count, 0)
    assertEqual(option(o.length, 30).label, "0:30 (0)")
    assertEqual(option(o.spec, BM).count, 0)
    -- Date: all four ranges, always, each with its count; nesting kept.
    o = D.Options(all, D.DEFAULTS, NOW)
    assertEqual(values(o.date), "all,today,7d,30d")
    assertEqual(option(o.date, "today").count, 3)
    assertEqual(option(o.date, "all").count, 8)
    o = D.Options(all, { date = "today", char = "Lanfear-Frostmourne" }, NOW)
    assertEqual(option(o.char, "Traxex-Frostmourne").count, 1, "today's Traxex run")
    assertEqual(option(o.date, "today").count, 1)
    assertEqual(option(o.date, "30d").count, 2)
    -- The checks narrow every facet: Clean only takes the flagged run out of Lanfear's count.
    o = D.Options(all, { cleanOnly = true }, NOW)
    assertEqual(option(o.char, "Lanfear-Frostmourne").count, 1)
    o = D.Options(all, { includeIncomplete = true }, NOW)
    assertEqual(option(o.char, "Tiamat-Frostmourne").count, 2, "the incomplete run, never the lost one")
end)

test("insights: Normalize sets a 0-run selection to All, never the one just changed, in bar order", function()
    local NS = fresh()
    local D = NS.InsightsData
    local all = fixture()
    local f, o = D.Normalize(all, { spec = BM, length = 30 }, NOW, "spec")
    assertEqual(f.spec, BM, "the dropdown the player changed stays")
    assertEqual(f.length, "all")
    assertEqual(option(o.length, 60).count, 2, "the options after the fallback")
    f = D.Normalize(all, { spec = BM, length = 30 }, NOW, "length")
    assertEqual(f.spec, "all")
    assertEqual(f.length, 30)
    -- Bar order with a recompute between: the character falls back first, so the spec it would have
    -- emptied is saved.
    f = D.Normalize(all, { char = "Ghost-Nowhere", spec = ELE }, NOW)
    assertEqual(f.char, "all", "a saved character with no runs left")
    assertEqual(f.spec, ELE, "kept: once the character is All, Elemental has runs")
    f = D.Normalize(all, { date = "today", char = "Tiamat-Frostmourne", length = 120 }, NOW, "char")
    assertEqual(f.char, "Tiamat-Frostmourne")
    assertEqual(f.length, "all")
    assertEqual(f.date, "today")
    local given = { char = "Ghost-Nowhere" }
    D.Normalize(all, given, NOW)
    assertEqual(given.char, "Ghost-Nowhere", "the caller's table is never written")
end)

-- ── the stats pass ──────────────────────────────────────────────────────────────────────────────

test("insights: Compute on no runs returns zero cards and empty sections", function()
    local NS = fresh()
    local s = NS.InsightsData.Compute({})
    assertEqual(s.totals.runs, 0)
    assertEqual(s.totals.timeRaced, 0)
    assertNil(s.totals.best)
    assertNil(s.totals.avgPct)
    assertEqual(s.totals.newBests, 0)
    assertEqual(#s.progression, 0)
    assertNil(s.specCompare)
    assertEqual(#s.consistency, 0)
    assertEqual(#s.byChar, 0)
    assertEqual(#s.byDay, 0)
    assertEqual(#s.lateBySpell.counted, 0)
    assertNil(s.spellShare)
    assertEqual(#s.tail, 5)
    assertEqual(s.tail[1].n, 0)
    assertEqual(#s.newBests, 0)
end)

test("insights: Compute's cards over the owner-shaped fixture", function()
    local NS = fresh()
    local D = NS.InsightsData
    local s = D.Compute(D.Filter(fixture(), nil, NOW))
    local t = s.totals
    assertEqual(t.runs, 8)
    assertEqual(t.timeRaced, 750, "the race lengths of the complete runs")
    assertEqual(t.best.run.id, "h2")
    assertEqual(t.best.dps, 440)
    near(t.avgPct, (400 / 440 + 1 + 420 / 440 + 100 / 125 + 1 + 300 / 330 + 1 + 1) / 8, "avg % of board best")
    assertNil(t.oneBoard, "four boards")
    assertEqual(t.clean, 7, "the Feign Death run is clean; the Incinerate run is not")
    assertEqual(t.newBests, 3)
    assertEqual(t.chars, 3)
    assertEqual(t.specs, 3)
    assertEqual(t.first, day(0, 10))
    assertEqual(t.last, day(3, 12))
    assertEqual(t.activeDays, 3)
    -- Time raced counts an incomplete run's time in combat.
    local wide = D.Compute(D.Filter(fixture(), { includeIncomplete = true }, NOW))
    assertEqual(wide.totals.timeRaced, 762)
    assertEqual(wide.totals.runs, 9)
    assertEqual(wide.totals.best.run.id, "h2", "an incomplete run never sets the best")
    -- One board: the raw average too.
    local one = D.Compute(D.Filter(fixture(), { spec = BM, category = "cleave", length = 120 }, NOW))
    assertEqual(one.totals.oneBoard, BM .. "|cleave|120")
    near(one.totals.avgDps, 420, "avg DPS on one board")
end)

test("insights: Compute's boards, progression, spec compare and consistency are board-relative", function()
    local NS = fresh()
    local D = NS.InsightsData
    local s = D.Compute(D.Filter(fixture(), nil, NOW))
    local bm = s.boards[BM .. "|cleave|120"]
    assertEqual(bm.n, 3)
    assertEqual(bm.best.id, "h2")
    assertEqual(bm.first.id, "h1")
    near(bm.avg, 420, "board avg")
    near(bm.cv, math.sqrt(800 / 3) / 420, "board CV")
    near(bm.pct.h1, 400 / 440, "per-run % of best")
    assertEqual(s.boards[ELE .. "|cleave|30"].n, 1)
    -- A: every complete run in date order, with its % of board best.
    assertEqual(#s.progression, 8)
    assertEqual(s.progression[1].run.id, "h1")
    assertEqual(s.progression[8].run.id, "s1")
    near(s.progression[5].pct, 0.8, "h4 against its own board")
    -- B: the most-raced (target, length) pair, specs best first.
    assertEqual(s.specCompare.category, "cleave")
    assertEqual(s.specCompare.length, 120)
    assertEqual(#s.specCompare.rows, 2)
    assertEqual(s.specCompare.rows[1].specID, BM)
    assertEqual(s.specCompare.rows[1].best, 440)
    near(s.specCompare.rows[1].avg, 420, "spec avg")
    assertEqual(s.specCompare.rows[2].specID, DESTRO)
    assertEqual(s.specCompare.rows[2].n, 2)
    -- C: boards with 3 or more runs.
    assertEqual(#s.consistency, 1)
    assertEqual(s.consistency[1].key, BM .. "|cleave|120")
    near(s.consistency[1].avgPct, (400 / 440 + 1 + 420 / 440) / 3, "consistency avg %")
end)

test("insights: Compute's new bests beat an earlier best on their board, in date order", function()
    local NS = fresh()
    local D = NS.InsightsData
    local s = D.Compute(D.Filter(fixture(), nil, NOW))
    assertEqual(#s.newBests, 3, "a board's first run never counts")
    assertEqual(s.newBests[1].run.id, "h2")
    assertEqual(s.newBests[1].prev.id, "h1")
    near(s.newBests[1].gain, 10, "h2 gain")
    assertEqual(s.newBests[2].run.id, "h5")
    near(s.newBests[2].gain, 25, "h5 gain")
    assertEqual(s.newBests[3].run.id, "l2")
    assertEqual(s.newBests[3].prev.id, "l1", "a flagged run still holds a best (flags inform, never void)")
    -- A tie does not beat the best.
    local tie = { mk("a", "hunt", "boss", 60, day(0), 100), mk("b", "hunt", "boss", 60, day(1), 100) }
    assertEqual(#D.Compute(tie).newBests, 0)
end)

test("insights: Compute's counts by character, target, length and day, gap days included", function()
    local NS = fresh()
    local D = NS.InsightsData
    local s = D.Compute(D.Filter(fixture(), nil, NOW))
    assertEqual(#s.byChar, 3)
    assertEqual(s.byChar[1].name, "Traxex")
    assertEqual(s.byChar[1].class, "HUNTER")
    assertEqual(s.byChar[1].n, 5)
    assertEqual(s.byChar[3].name, "Tiamat")
    local hunt = s.byCharTarget.rows[1]
    assertEqual(hunt.byCategory.cleave, 3)
    assertEqual(hunt.byCategory.boss, 2)
    assertEqual(table.concat(s.byCharTarget.categories, ","), "cleave,boss", "the catalog's order")
    assertEqual(#s.byLength, 3)
    assertEqual(s.byLength[1].length, 30)
    assertEqual(s.byLength[3].n, 5)
    assertEqual(#s.byDay, 4, "Oct 23 to Oct 26, the empty day included")
    assertEqual(s.byDay[1].n, 2)
    assertEqual(s.byDay[2].n, 3)
    assertEqual(s.byDay[3].n, 0)
    assertEqual(s.byDay[4].n, 3)
    assertEqual(s.byDay[3].day, day(2, 0))
end)

test("insights: Compute buckets the damage tail, the 155 s outlier in 20+", function()
    local NS = fresh()
    local D = NS.InsightsData
    local s = D.Compute(D.Filter(fixture(), nil, NOW))
    local n = {}
    for i, b in ipairs(s.tail) do n[i] = b.n end
    assertEqual(table.concat(n, ","), "2,2,1,1,2")
    assertEqual(s.tail[1].lo, 0)
    assertEqual(s.tail[1].hi, 5)
    assertEqual(s.tail[5].lo, 20)
    assertNil(s.tail[5].hi, "open-ended")
end)

test("insights: Compute lists late casts by spell, ignored apart, a sealed one as Unknown", function()
    local NS = fresh()
    local D = NS.InsightsData
    local s = D.Compute(D.Filter(fixture(), { includeIncomplete = true }, NOW))
    local byspell = s.lateBySpell
    assertEqual(#byspell.counted, 2)
    assertEqual(byspell.counted[1].id, INCINERATE)
    assertEqual(byspell.counted[1].count, 1)
    assertTrue(byspell.counted[2].unknown, "a sealed spell ID is counted, last")
    assertNil(byspell.counted[2].id)
    assertEqual(#byspell.ignored, 2)
    assertEqual(byspell.ignored[1].id, FEIGN)
    assertEqual(byspell.ignored[2].id, HEARTH)
    -- The list read at call time: stop ignoring Feign Death and it moves, and the run is flagged.
    NS.LateIgnore.Unignore(FEIGN)
    s = D.Compute(D.Filter(fixture(), nil, NOW))
    assertEqual(#s.lateBySpell.counted, 2)
    assertEqual(#s.lateBySpell.ignored, 1)
    assertEqual(s.totals.clean, 6)
    assertEqual(ids(D.Filter(fixture(), { cleanOnly = true }, NOW)), "h1,h2,h3,h4,l2,s1")
end)

test("insights: Compute's spell share is the mean of each run's share, summed by ID, one spec only", function()
    local NS = fresh()
    local D = NS.InsightsData
    assertNil(D.Compute(D.Filter(fixture(), nil, NOW)).spellShare, "three specs")
    local s = D.Compute(D.Filter(fixture(), { spec = BM }, NOW))
    local share = s.spellShare
    assertEqual(share.specID, BM)
    assertEqual(share.n, 2, "the runs with spells")
    assertEqual(#share.rows, 2)
    assertEqual(share.rows[1].id, 34026)
    near(share.rows[1].share, 0.625, "Kill Command")
    assertEqual(share.rows[2].id, 6603)
    near(share.rows[2].share, 0.375, "Auto Attack, player and pet summed")
    local none = D.Compute(D.Filter(fixture(), { spec = ELE }, NOW)).spellShare
    assertEqual(none.n, 0, "one spec with no spells recorded")
    assertEqual(#none.rows, 0)
end)
