-- tests/test_bests.lua — modules/Bests.lua and Recorder.Prune: the board key (spec × category × race
-- length), which runs count (complete only, clean-only on request), the delta against the best before
-- a run, the bests cache, and pruning that never removes a run holding a best (spec §7, Review Focus 4).

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function fresh(opts)
    local inst = T.load(opts)
    return inst.NS, inst.mocks, inst
end

--- A stored-shape run with what Bests reads: char.specID, target.category, race.length, status,
--- result.dps and flags.
local function run(id, date, dps, o)
    o = o or {}
    local status = o.status or "complete"
    return {
        id = id, date = date, status = status, schema = 1,
        race   = { length = o.length or 30 },
        char   = { name = o.name or "Lanfear", specID = o.specID or 267 },
        target = { npcID = o.npcID or 243205, category = o.category or "boss" },
        result = (status ~= "lost") and { damage = (dps or 0) * (o.length or 30), dps = dps } or nil,
        flags  = o.flags or { lateCasts = {}, reloaded = false, died = false },
    }
end

local function storeAll(NS, list)
    for _, r in ipairs(list) do NS.db.global.runs[r.id] = r end
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- ── the key and the board ───────────────────────────────────────────────────────────────────────

test("bests: Key is specID|category|length", function()
    local NS = fresh()
    assertEqual(NS.Bests.Key(run("a", 1, 100, { specID = 267, category = "boss", length = 180 })), "267|boss|180")
end)

test("bests: incomplete and lost never count", function()
    local NS = fresh()
    local runs = {
        run("lost", 3, nil, { status = "lost" }),
        run("inc", 2, 9000, { status = "incomplete" }),
        run("run", 4, 9999, { status = "running" }),
        run("ok", 1, 100),
    }
    local board = NS.Bests.Compute(runs)
    assertEqual(count(board), 1)
    assertEqual(board["267|boss|30"].id, "ok", "only a complete run holds a best, even a far lower one")
    local none = NS.Bests.Compute({ runs[1], runs[2] })
    assertEqual(count(none), 0)
end)

test("bests: the highest result.dps holds the board; a tie keeps the earlier run", function()
    local NS = fresh()
    local board = NS.Bests.Compute({ run("a", 1, 500), run("b", 2, 700), run("c", 3, 700), run("d", 4, 600) })
    assertEqual(board["267|boss|30"].id, "b")
end)

test("bests: cleanOnly excludes flagged", function()
    local NS = fresh()
    local runs = {
        run("late", 1, 900, { flags = { lateCasts = { { t = 1.4, spellID = 29722 } } } }),
        run("restart", 2, 850, { flags = { lateCasts = {}, restartedAt = 14.2 } }),
        run("reload", 3, 800, { flags = { lateCasts = {}, reloaded = true } }),
        run("died", 4, 750, { flags = { lateCasts = {}, died = true } }),
        run("byList", 6, 700, { flags = { lateCasts = {}, sessionFromList = true } }),
        run("clean", 5, 500),
    }
    assertEqual(NS.Bests.Compute(runs)["267|boss|30"].id, "late", "flags inform, never void")
    local clean = NS.Bests.Compute(runs, { cleanOnly = true })
    assertEqual(clean["267|boss|30"].id, "clean")
end)

test("bests: two Dungeoneer npcIDs share one board", function()
    local NS = fresh()
    local runs = {
        run("d1", 1, 400, { npcID = 243167, category = "dungeoneer" }),
        run("d2", 2, 600, { npcID = 243168, category = "dungeoneer" }),
    }
    local board = NS.Bests.Compute(runs)
    assertEqual(count(board), 1, "one board per category, not per creature ID")
    assertEqual(board["267|dungeoneer|30"].id, "d2")
end)

test("bests: spec, category and length each split the board", function()
    local NS = fresh()
    local board = NS.Bests.Compute({
        run("a", 1, 100), run("b", 2, 100, { specID = 265 }),
        run("c", 3, 100, { category = "single" }), run("d", 4, 100, { length = 60 }),
    })
    assertEqual(count(board), 4)
end)

test("bests: deleting a best promotes the next run", function()
    -- Review Focus 4: two characters share a spec and a category; one deletes its best.
    local NS = fresh()
    storeAll(NS, {
        run("alt", 1, 800, { name = "Altchar" }),
        run("main", 2, 900, { name = "Lanfear" }),
        run("old", 3, 300),
    })
    assertEqual(NS.Bests.Board()["267|boss|30"].id, "main")
    assertTrue(NS.Recorder.Delete("main"))
    assertEqual(NS.Bests.Board()["267|boss|30"].id, "alt", "the cache was not invalidated by RUNS_CHANGED")
end)

test("bests: the cache is invalidated by RUN_SAVED and keeps cleanOnly apart", function()
    local NS = fresh()
    storeAll(NS, { run("a", 1, 500) })
    assertEqual(NS.Bests.Board()["267|boss|30"].id, "a")
    assertTrue(NS.Recorder.Save(run("b", 2, 600, { flags = { lateCasts = {}, reloaded = true } })))
    assertEqual(NS.Bests.Board()["267|boss|30"].id, "b", "RUN_SAVED did not invalidate the cache")
    assertEqual(NS.Bests.Board({ cleanOnly = true })["267|boss|30"].id, "a")
end)

-- ── Delta ───────────────────────────────────────────────────────────────────────────────────────

test("bests: Delta reports new best and percentage vs previous best", function()
    local NS = fresh()
    local a, b, c = run("a", 1, 1000), run("b", 2, 1100), run("c", 3, 1067)
    local runs = { a, b, c }
    local pct, isNew = NS.Bests.Delta(a, runs)
    assertNil(pct, "the first run on a board has nothing to compare with")
    assertTrue(isNew, "the first complete run on a board is a new best")
    pct, isNew = NS.Bests.Delta(b, runs)
    assertTrue(math.abs(pct - 10) < 1e-9, "b vs a: +10%, got " .. tostring(pct))
    assertTrue(isNew)
    pct, isNew = NS.Bests.Delta(c, runs)
    assertTrue(math.abs(pct - (1067 / 1100 - 1) * 100) < 1e-9, "c is compared with b, the best before it")
    assertFalse(isNew)
end)

test("bests: Delta ignores later runs, other boards and runs that never count", function()
    local NS = fresh()
    local a = run("a", 1, 1000)
    local runs = {
        a, run("later", 9, 5000), run("other", 0, 9000, { length = 60 }),
        run("inc", 0, 9000, { status = "incomplete" }),
    }
    local pct, isNew = NS.Bests.Delta(a, runs)
    assertNil(pct)
    assertTrue(isNew)
    pct, isNew = NS.Bests.Delta(run("lost", 5, nil, { status = "lost" }), runs)
    assertNil(pct)
    assertFalse(isNew, "a lost run is never a best")
end)

test("bests: Delta defaults its run list to the store", function()
    local NS = fresh()
    storeAll(NS, { run("a", 1, 1000) })
    local b = run("b", 2, 900)
    local pct, isNew = NS.Bests.Delta(b)
    assertTrue(math.abs(pct + 10) < 1e-9, "got " .. tostring(pct))
    assertFalse(isNew)
end)

test("bests: HoldingIDs names the holders of the all-runs and the clean-only boards", function()
    local NS = fresh()
    local ids = NS.Bests.HoldingIDs({
        run("late", 1, 900, { flags = { lateCasts = { { t = 2, spellID = 1 } } } }),
        run("clean", 2, 500), run("slow", 3, 100), run("cleave", 4, 50, { category = "cleave" }),
    })
    assertTrue(ids.late and ids.clean and ids.cleave)
    assertNil(ids.slow)
end)

-- ── pruning ─────────────────────────────────────────────────────────────────────────────────────

test("bests: prune keep=0 removes nothing", function()
    local NS = fresh()
    storeAll(NS, { run("a", 1, 100), run("b", 2, 50), run("c", 3, 10) })
    local changed = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.RUNS_CHANGED, function() changed = changed + 1 end)
    assertEqual(NS.Recorder.Prune(0), 0)
    assertEqual(NS.Recorder.Prune(nil), 0)
    assertEqual(count(NS.db.global.runs), 3)
    assertEqual(changed, 0)
end)

test("bests: prune keeps best-holding runs", function()
    -- Review Focus 4: the oldest runs go first, but never one holding a best.
    local NS = fresh()
    storeAll(NS, {
        run("best", 1, 900),                                         -- oldest, holds the board
        run("cleave", 2, 10, { category = "cleave" }),               -- holds its own board
        run("old", 3, 100), run("mid", 4, 200), run("new", 5, 300),
    })
    local changed = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.RUNS_CHANGED, function() changed = changed + 1 end)
    assertEqual(NS.Recorder.Prune(3), 2)
    local runs = NS.db.global.runs
    assertTrue(runs.best and runs.cleave and runs.new, "a holder or the newest run was pruned")
    assertNil(runs.old)
    assertNil(runs.mid)
    assertEqual(changed, 1, "one RUNS_CHANGED per prune")
end)

test("bests: prune never removes a running or stopping run, and stops at the holders", function()
    local NS = fresh()
    storeAll(NS, {
        run("live", 0, nil, { status = "running" }), run("stop", 0, nil, { status = "stopping" }),
        run("best", 1, 900), run("lost", 2, nil, { status = "lost" }), run("inc", 3, 50, { status = "incomplete" }),
    })
    assertEqual(NS.Recorder.Prune(1), 2, "only the lost and the incomplete run may go")
    local runs = NS.db.global.runs
    assertTrue(runs.live and runs.stop and runs.best)
    assertEqual(count(runs), 3, "above keep is fine when everything left is protected")
end)

test("bests: prune runs on RUN_SAVED with the global history.keep setting", function()
    local NS = fresh()
    assertEqual(NS.GetSetting("global.history.keep"), 0, "the default is 0 = never prune")
    storeAll(NS, { run("a", 1, 900), run("b", 2, 100), run("c", 3, 200) })
    assertTrue(NS.Recorder.Save(run("d", 4, 300)))
    assertEqual(count(NS.db.global.runs), 4, "keep = 0 pruned something")
    NS.db.global.history.keep = 2
    assertTrue(NS.Recorder.Save(run("e", 5, 400)))
    local runs = NS.db.global.runs
    assertEqual(count(runs), 2)
    assertTrue(runs.a and runs.e, "kept the best and the run just saved")
end)

test("bests: prune runs at OnEnable", function()
    -- Initialized but not enabled: the store is seeded as a previous session left it, then the
    -- client's enable fires.
    local NS = fresh{ enable = false }
    NS.db.global.history.keep = 1
    storeAll(NS, { run("a", 1, 900), run("b", 2, 100), run("c", 3, 200) })
    NS:OnEnable()
    local runs = NS.db.global.runs
    assertEqual(count(runs), 1)
    assertTrue(runs.a ~= nil, "the best-holding run survived")
end)

test("bests: no prune and no cache work while disabled", function()
    local NS = fresh()
    storeAll(NS, { run("a", 1, 900), run("b", 2, 100), run("c", 3, 200) })
    NS.db.global.history.keep = 1
    assertTrue(NS.SetByPath("enabled", false))
    NS.SendBus(NS.MSG.RUN_SAVED, run("c", 3, 200))
    assertEqual(count(NS.db.global.runs), 3, "a bus receiver pruned while disabled")
end)
