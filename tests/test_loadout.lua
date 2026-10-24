-- tests/test_loadout.lua — the loadout (#6): the capture (modules/Recorder.lua SnapshotLoadout: the
-- gear links without the shirt and tabard, the talent loadout, every API absent or raising), its
-- deduped store (modules/Loadouts.lua: the hash, a collision, the orphan sweep on every removal), the
-- race taking it at arm and again at its combat end, the run format 2 migration, the detail's gear
-- grid and talents line (modules/Results_Loadout.lua) with the compare's highlights, the Spec cell's
-- tooltip and the share line's optional talents link.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertNil

local F = dofile(T.root .. "/tests/race_clock.lua")(T)

local function fresh(mutate)
    local inst = T.load{ mutate = mutate }
    return inst.NS, inst.mocks, inst
end

-- ── the capture ─────────────────────────────────────────────────────────────────────────────────

test("loadout: SnapshotLoadout reads every equipped link but the shirt and the tabard", function()
    local NS, M = fresh()
    local lo = NS.Recorder.SnapshotLoadout()
    assertTrue(type(lo) == "table" and type(lo.gear) == "table")
    assertEqual(lo.gear[1], M.__gear[1])
    assertEqual(lo.gear[5], M.__gear[5])
    assertEqual(lo.gear[16], M.__gear[16])
    assertNil(lo.gear[4], "the shirt was recorded")
    assertNil(lo.gear[19], "the tabard was recorded")
    assertNil(lo.gear[2], "an empty slot is absent")
    for _, slot in ipairs(NS.Recorder.GEAR_SLOTS) do
        assertTrue(slot ~= 4 and slot ~= 19 and slot >= 1 and slot <= 18, "slot " .. slot)
    end
end)

test("loadout: SnapshotLoadout reads the talents: the saved loadout's name, the hero tree, the string", function()
    local NS = fresh()
    local t = NS.Recorder.SnapshotLoadout().talents
    assertEqual(t.specID, 267)
    assertEqual(t.configID, 7001)
    assertEqual(t.name, "Raid ST", "the player's saved loadout names it")
    assertEqual(t.heroSpecID, 58)
    assertEqual(t.heroName, "Diabolist")
    assertEqual(t.importString, "C0PAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    assertEqual(t.serialVersion, 2)
end)

test("loadout: with no saved loadout the active config's name is used", function()
    local NS, M = fresh()
    M.__talents.savedConfigID = nil
    assertEqual(NS.Recorder.SnapshotLoadout().talents.name, "Active")
end)

test("loadout: a client without the APIs, or one that raises, yields absent fields, never an error", function()
    local NS, M = fresh()
    M.GetInventoryItemLink = nil
    local lo = NS.Recorder.SnapshotLoadout()
    assertNil(lo.gear, "no inventory API, yet gear")
    assertEqual(lo.talents.name, "Raid ST")
    M.C_Traits.GenerateImportString = function() error("boom") end
    M.C_Traits.GetSubTreeInfo = nil
    lo = NS.Recorder.SnapshotLoadout()
    assertNil(lo.talents.importString)
    assertNil(lo.talents.heroName)
    assertEqual(lo.talents.heroSpecID, 58)
    M.C_ClassTalents = nil
    assertNil(NS.Recorder.SnapshotLoadout(), "nothing readable, yet a loadout")
    local NS2, M2 = fresh()
    M2.__talents = nil
    lo = NS2.Recorder.SnapshotLoadout()
    assertNil(lo.talents, "no active config, yet talents")
    assertTrue(lo.gear ~= nil)
end)

test("loadout: a secret value never reaches the snapshot", function()
    local NS, M = fresh(function(m) m.issecretvalue = function(v) return T.isSecret(v) end end)
    M.__gear[5] = T.secret(M.__gear[5])
    M.__talents.importString = T.secret("SECRET")
    local lo = NS.Recorder.SnapshotLoadout()
    assertNil(lo.gear[5], "a sealed link was stored")
    assertNil(lo.talents.importString, "a sealed import string was stored")
    assertEqual(lo.gear[1], M.__gear[1])
end)

-- ── the store ───────────────────────────────────────────────────────────────────────────────────

local function stored(NS) return NS.db.global.loadouts end

local function storedRun(NS, id, loadout, fields)
    local run = { id = id, schema = 2, status = "complete", date = 1000, race = { length = 30 },
                  result = { damage = 10, dps = 1 }, loadout = loadout }
    for k, v in pairs(fields or {}) do run[k] = v end
    NS.db.global.runs[id] = run
    return run
end

test("loadout: the hash is djb2 as eight hex digits, and pure", function()
    local NS = fresh()
    local H = NS.Loadouts.Hash
    assertEqual(H(""), "00001505", "djb2's seed, 5381")
    assertEqual(H("a"), "0002b606", "5381 * 33 + 97")
    assertEqual(H("abc"), H("abc"))
    assertTrue(H("abc") ~= H("acb"))
    assertEqual(#H(("x"):rep(5000)), 8, "a long string stays inside 32 bits")
end)

test("loadout: Store keeps each distinct set once; the run holds only the keys", function()
    local NS = fresh()
    local snap = NS.Recorder.SnapshotLoadout()
    local a = NS.Loadouts.Store(snap)
    local b = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    assertEqual(a.gear, b.gear, "the same gear stored twice")
    assertEqual(a.talents, b.talents, "the same talents stored twice")
    assertEqual(NS.Loadouts.Counts(), 1)
    assertEqual(stored(NS).gear[a.gear][16], snap.gear[16])
    snap.gear[16] = nil
    local c = NS.Loadouts.Store(snap)
    assertTrue(c.gear ~= a.gear, "different gear, one key")
    assertEqual(c.talents, a.talents)
    local g, t = NS.Loadouts.Counts()
    assertEqual(g, 2)
    assertEqual(t, 1)
    assertNil(NS.Loadouts.Store(nil))
    assertNil(NS.Loadouts.Store({}), "an empty snapshot stores nothing")
    local gearOnly = NS.Loadouts.Store({ gear = { [1] = "x" } })
    assertNil(gearOnly.talents)
end)

test("loadout: two different sets with one hash are told apart; the same set finds its own key", function()
    local NS = fresh()
    NS.Loadouts.Hash = function() return "deadbeef" end
    local a = NS.Loadouts.Store({ gear = { [1] = "one" } })
    local b = NS.Loadouts.Store({ gear = { [1] = "two" } })
    local c = NS.Loadouts.Store({ gear = { [1] = "three" } })
    assertEqual(a.gear, "deadbeef")
    assertEqual(b.gear, "deadbeef-2")
    assertEqual(c.gear, "deadbeef-3")
    assertEqual(NS.Loadouts.Store({ gear = { [1] = "two" } }).gear, "deadbeef-2", "a collided set stored again")
    assertEqual(stored(NS).gear["deadbeef-2"][1], "two")
end)

test("loadout: Of resolves a run's keys; a run without one has neither", function()
    local NS = fresh()
    local ref = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    local run = storedRun(NS, "r1", ref)
    local gear, talents = NS.Loadouts.Of(run)
    assertEqual(gear[1], stored(NS).gear[ref.gear][1])
    assertEqual(talents.name, "Raid ST")
    gear, talents = NS.Loadouts.Of(storedRun(NS, "old", nil, { schema = 1 }))
    assertNil(gear)
    assertNil(talents)
    gear = NS.Loadouts.Of({ loadout = { gear = "missing" } })
    assertNil(gear, "a key with no stored set")
end)

test("loadout: Delete, DeleteAll and Prune drop the loadouts no run refers to", function()
    local NS, M = fresh()
    local shared = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    M.__gear[1] = nil
    local own = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    storedRun(NS, "a", shared, { date = 1 })
    storedRun(NS, "b", shared, { date = 2 })
    storedRun(NS, "c", own, { date = 3 })
    assertEqual(NS.Loadouts.Counts(), 2)
    assertTrue(NS.Recorder.Delete("c"))
    assertEqual(NS.Loadouts.Counts(), 1, "the deleted run's own gear was kept")
    assertTrue(stored(NS).gear[shared.gear] ~= nil, "a set another run uses was dropped")
    -- Prune: the oldest goes, the set the newer run shares stays.
    NS.Bests.HoldingIDs = function() return {} end
    assertEqual(NS.Recorder.Prune(1), 1)
    assertEqual(NS.Loadouts.Counts(), 1)
    storedRun(NS, "d", NS.Loadouts.Store({ gear = { [2] = "d" } }), { date = 4 })
    assertEqual(NS.Recorder.Prune(1), 1)
    assertNil(stored(NS).gear[shared.gear], "the pruned run's set outlived it")
    assertEqual(NS.Loadouts.Counts(), 1)
    NS.Recorder.DeleteAll()
    local g, t = NS.Loadouts.Counts()
    assertEqual(g + t, 0, "a set outlived every run")
end)

test("loadout: a run of a later format keeps the sets it refers to", function()
    local NS = fresh()
    local ref = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    storedRun(NS, "future", ref, { schema = NS.Recorder.RUN_SCHEMA + 1 })
    assertEqual(NS.Loadouts.Sweep(), 0)
    assertEqual(NS.Loadouts.Counts(), 1)
end)

-- ── the migration ───────────────────────────────────────────────────────────────────────────────

test("loadout: the format 2 migration leaves old runs as they were, without a loadout", function()
    local inst = T.load({ init = false })
    local NS = inst.NS
    local old = { id = "old", schema = 1, status = "complete", date = 5, race = { length = 30 },
                  result = { damage = 9, dps = 0.3 }, spells = {}, note = "kept" }
    _G.DpsRaceDB = { global = { schemaVersion = 1, schema = 1, runs = { old = old } } }
    inst.mocks._G.DpsRaceDB = _G.DpsRaceDB
    NS:InitDB()
    NS:RunMigrations()
    local g = NS.db.global
    assertEqual(g.schemaVersion, 2)
    assertEqual(g.schema, 2, "the format stamp answers 2")
    local run = g.runs.old
    assertEqual(run.schema, 1, "an old run was rewritten")
    assertNil(run.loadout)
    assertEqual(run.note, "kept")
    assertNil(NS.Loadouts.Of(run))
    assertEqual(NS.Recorder.All()[1].id, "old", "a format-1 run is still listed")
    NS:RunMigrations()
    assertEqual(g.schemaVersion, 2, "the step ran twice")
end)

-- ── the race ────────────────────────────────────────────────────────────────────────────────────

test("loadout: a race keeps the combat-end loadout, not the arm-time one", function()
    local f = F.new()
    assertTrue(f:arm(30))
    local run = f.Race.Current()
    assertNil(run.loadout, "stored before the race was")
    f:start(25)
    f.M.__gear[16] = "|cnIQ4:|Hitem:999::::::::80:267::::::::|h[New Staff]|h|r"   -- swapped in combat
    f:to(130)
    f:combatEnd()
    local gear = f.NS.Loadouts.Of(run)
    assertEqual(gear[16], f.M.__gear[16], "the combat-end snapshot")
    f:advance(3)
    assertEqual(run.status, "complete")
    gear = f.NS.Loadouts.Of(f:stored(run.id))
    assertEqual(gear[16], f.M.__gear[16], "the arm-time snapshot replaced it at the read")
    assertEqual(f.NS.Loadouts.Counts(), 1, "only the kept set is stored")
end)

test("loadout: a run with no combat-end snapshot falls back to the arm-time one", function()
    local f = F.new()
    assertTrue(f:arm(30))
    local run = f.Race.Current()
    local armLink = f.M.__gear[1]
    f:start(25)
    f.M.__gear[1] = "changed"
    f.Race.OnMeterReset()
    assertEqual(run.status, "lost")
    assertEqual(f.NS.Loadouts.Of(f:stored(run.id))[1], armLink, "the lost run took no arm-time loadout")
end)

test("loadout: a second combat end in the read's wait replaces the loadout and drops the first", function()
    local f = F.new()
    assertTrue(f:arm(30))
    local run = f.Race.Current()
    f:start(25)
    f:to(130)
    f:combatEnd()
    local first = run.loadout.gear
    f.M.__inCombat = true
    f.Race.OnCombatStart(f:now())
    f.M.__gear[2] = "|cnIQ4:|Hitem:5::::::::80:267::::::::|h[Neck]|h|r"
    f:combatEnd()
    assertTrue(run.loadout.gear ~= first)
    assertNil(f.NS.db.global.loadouts.gear[first], "the replaced set outlived the replacement")
end)
