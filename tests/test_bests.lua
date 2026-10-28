-- tests/test_bests.lua — modules/Bests.lua and Recorder.Prune: the board key (spec × category × race
-- length), which runs count (complete only, clean-only on request), the delta against the best before
-- a run, the bests cache, and pruning that never removes a run holding a best (spec §7, Review Focus 4).

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function fresh(opts)
    local inst = T.load(opts)
    -- These fixtures carry 1970-era dates: no age prune unless a case sets one.
    inst.NS.db.global.history.keepDays = 0
    return inst.NS, inst.mocks, inst
end

local DAY = 86400
local NOW = 1000 * DAY   -- the epoch the prune cases measure age from

--- A stored-shape run with what Bests reads: char.specID, target.category, race.length, status,
--- result.dps and flags.
-- A cataloged creature per category, so the read-time category (#9) is the recorded one; single has
-- no built-in dummy, so a single-target run carries no creature ID and keeps its own.
local CATALOG_ID = { boss = 243205, cleave = 243208, dungeoneer = 243167, pvp = 243211 }

local function run(id, date, dps, o)
    o = o or {}
    local status = o.status or "complete"
    return {
        id = id, date = date, status = status, schema = 1,
        race   = { length = o.length or 30 },
        char   = { name = o.name or "Lanfear", specID = o.specID or 267 },
        target = { npcID = o.npcID or CATALOG_ID[o.category or "boss"], category = o.category or "boss" },
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

test("bests: a run flagged only by an ignored spell joins the clean board, and leaves it on Unignore", function()
    local NS = fresh()
    local feign = { lateCasts = { { t = 1.4, spellID = 5384 } }, reloaded = false, died = false }
    storeAll(NS, { run("f", 1, 900, { flags = feign }), run("c", 2, 500) })
    assertEqual(NS.Bests.Board({ cleanOnly = true })["267|boss|30"].id, "f", "Feign Death is ignored by default")
    assertTrue(NS.LateIgnore.Unignore(5384))
    assertEqual(NS.Bests.Board({ cleanOnly = true })["267|boss|30"].id, "c", "flagged again, off the clean board")
    assertEqual(NS.Bests.Board()["267|boss|30"].id, "f", "the all-runs board never asks")
end)

-- ── Delta ───────────────────────────────────────────────────────────────────────────────────────

test("bests: Delta reports new best and percentage vs previous best", function()
    local NS = fresh()
    local a, b, c = run("a", 1, 1000), run("b", 2, 1100), run("c", 3, 1067)
    local runs = { a, b, c }
    local pct, isNew, prev = NS.Bests.Delta(a, runs)
    assertNil(pct, "the first run on a board has nothing to compare with")
    assertTrue(isNew, "the first complete run on a board is a new best")
    assertNil(prev, "and names no previous best")
    pct, isNew, prev = NS.Bests.Delta(b, runs)
    assertTrue(math.abs(pct - 10) < 1e-9, "b vs a: +10%, got " .. tostring(pct))
    assertTrue(isNew)
    assertEqual(prev, a, "the third return is the previous best it was compared with")
    pct, isNew, prev = NS.Bests.Delta(c, runs)
    assertTrue(math.abs(pct - (1067 / 1100 - 1) * 100) < 1e-9, "c is compared with b, the best before it")
    assertFalse(isNew)
    assertEqual(prev, b)
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

test("bests: prune days=0 removes nothing", function()
    local NS = fresh()
    storeAll(NS, { run("a", 1, 100), run("b", 2, 50), run("c", 3, 10) })
    local changed = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.RUNS_CHANGED, function() changed = changed + 1 end)
    assertEqual(NS.Recorder.Prune(0, nil, NOW), 0)
    assertEqual(NS.Recorder.Prune(nil, nil, NOW), 0)
    assertEqual(count(NS.db.global.runs), 3)
    assertEqual(changed, 0)
end)

test("bests: prune keeps best-holding runs", function()
    -- Review Focus 4: every run older than the days goes, but never one holding a best.
    local NS = fresh()
    storeAll(NS, {
        run("best", NOW - 200 * DAY, 900),                                  -- old, holds the board
        run("cleave", NOW - 150 * DAY, 10, { category = "cleave" }),        -- old, holds its own board
        run("old", NOW - 120 * DAY, 100), run("mid", NOW - 91 * DAY, 200), run("new", NOW - 89 * DAY, 300),
    })
    local changed = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.RUNS_CHANGED, function() changed = changed + 1 end)
    assertEqual(NS.Recorder.Prune(90, nil, NOW), 2)
    local runs = NS.db.global.runs
    assertTrue(runs.best and runs.cleave and runs.new, "a holder or a run within the days was pruned")
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
    assertEqual(NS.Recorder.Prune(1, nil, NOW), 2, "only the lost and the incomplete run may go")
    local runs = NS.db.global.runs
    assertTrue(runs.live and runs.stop and runs.best)
    assertEqual(count(runs), 3, "old runs stay when each is protected")
end)

test("bests: prune runs on RUN_SAVED with the global history.keepDays setting", function()
    local inst = T.load()
    local NS = inst.NS
    assertEqual(NS.GetSetting("global.history.keepDays"), 90, "the default is 90 days")
    local now = inst.mocks.time()
    NS.db.global.history.keepDays = 0
    storeAll(NS, { run("a", now - 200 * DAY, 900), run("b", now - 100 * DAY, 100), run("c", now - DAY, 200) })
    assertTrue(NS.Recorder.Save(run("d", now, 300)))
    assertEqual(count(NS.db.global.runs), 4, "days = 0 pruned something")
    NS.db.global.history.keepDays = 90
    assertTrue(NS.Recorder.Save(run("e", now, 400)))
    local runs = NS.db.global.runs
    assertEqual(count(runs), 4, "only the run past 90 days that holds no best went")
    assertTrue(runs.a and runs.c and runs.d and runs.e and not runs.b, "kept the best and the recent runs")
end)

test("bests: prune never removes the run just saved, nor the race's own run", function()
    local NS = fresh()
    NS.db.global.history.keepDays = 1
    storeAll(NS, { run("best", 1, 900) })                 -- the older run holds the board
    assertTrue(NS.Recorder.Save(run("new", 2, 100)))      -- a slower run, just finished
    local runs = NS.db.global.runs
    assertTrue(runs.new ~= nil, "the run just saved was pruned in the same call")
    assertTrue(runs.best ~= nil)
    -- An explicit protected id, and the race's current run, are kept by a direct prune too.
    storeAll(NS, { run("x", 3, 50) })
    assertEqual(NS.Recorder.Prune(1, "new", NOW), 1)
    assertTrue(runs.new ~= nil and runs.x == nil)
end)

test("bests: a raced run that lands below the best survives the prune its own save fires", function()
    local F = dofile(T.root .. "/tests/race_clock.lua")(T)
    local f = F.new()
    f.NS.db.global.history.keepDays = 1
    local old = F.storedRun({ id = "1-1000", status = "complete", date = 1000,
                              result = { damage = 9e9, dps = 9e9 } })
    f.NS.db.global.runs[old.id] = old
    assertTrue(f:arm(30))
    local raced = f.Race.Current()
    f:start(25)
    old.char, old.target = raced.char, raced.target            -- the same board as the raced run
    assertEqual(f.NS.Bests.Key(old), f.NS.Bests.Key(raced))
    f:to(130)
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
    assertEqual(raced.status, "complete")
    assertTrue(f.NS.db.global.runs[raced.id] == raced, "the run on the result card was pruned")
end)

test("bests: prune runs at OnEnable", function()
    -- Initialized but not enabled: the store is seeded as a previous session left it, then the
    -- client's enable fires.
    local NS = fresh{ enable = false }
    NS.db.global.history.keepDays = 1
    storeAll(NS, { run("a", 1, 900), run("b", 2, 100), run("c", 3, 200) })
    NS:OnEnable()
    local runs = NS.db.global.runs
    assertEqual(count(runs), 1)
    assertTrue(runs.a ~= nil, "the best-holding run survived")
end)

test("bests: no prune and no cache work while disabled", function()
    local NS = fresh()
    storeAll(NS, { run("a", 1, 900), run("b", 2, 100), run("c", 3, 200) })
    NS.db.global.history.keepDays = 1
    assertTrue(NS.SetByPath("enabled", false))
    NS.SendBus(NS.MSG.RUN_SAVED, run("c", 3, 200))
    assertEqual(count(NS.db.global.runs), 3, "a bus receiver pruned while disabled")
end)
