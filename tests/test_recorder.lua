-- tests/test_recorder.lua — modules/Recorder.lua: the metadata snapshots (spec §7 shapes), a new run's
-- frozen scoring settings, and the run store (Save/Get/All/Pending/Delete/DeleteAll) with its bus
-- messages.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local GOLEM_GUID = "Creature-0-3770-2552-1234-243205-0000ABCDEF"

local function fresh(mutate)
    local inst = T.load{ mutate = mutate }
    return inst.NS, inst.mocks, inst
end

--- Count what the bus says, per message.
local function listen(NS)
    local heard = { saved = {}, changed = 0 }
    local target = assert(NS.NewBusTarget(), "no bus target")
    target:RegisterMessage(NS.MSG.RUN_SAVED, function(_, run) heard.saved[#heard.saved + 1] = run end)
    target:RegisterMessage(NS.MSG.RUNS_CHANGED, function() heard.changed = heard.changed + 1 end)
    return heard
end

--- A stored-shape run with the fields the store reads.
local function run(id, date, status)
    return { id = id, date = date, status = status, schema = 1, race = { length = 30 } }
end

-- ── snapshots ───────────────────────────────────────────────────────────────────────────────────

test("recorder: SnapshotPlayer records who the player is (spec §7 char)", function()
    local NS = fresh()
    local c = NS.Recorder.SnapshotPlayer()
    assertEqual(c.name, "Testchar")
    assertEqual(c.realm, "Testrealm")
    assertEqual(c.class, "MAGE", "the class TOKEN, not the localized name")
    assertEqual(c.specID, 267)
    assertEqual(c.spec, "Blood")
    assertEqual(c.role, "DAMAGER")
    assertEqual(c.ilvl, 313.2, "equipped item level, to one decimal")
    assertEqual(c.ilvlOverall, 313.4, "overall item level, to one decimal")
    assertEqual(c.level, 80)
    assertEqual(c.race, "BloodElf", "the race file token")
end)

test("recorder: SnapshotPlayer tolerates a client without the spec and ilvl APIs", function()
    local NS = fresh(function(m)
        m.GetSpecialization, m.GetSpecializationInfo, m.GetAverageItemLevel, m.UnitRace = nil, nil, nil, nil
    end)
    local c = NS.Recorder.SnapshotPlayer()
    assertEqual(c.name, "Testchar")
    assertNil(c.specID)
    assertNil(c.ilvl)
    assertNil(c.race)
end)

test("recorder: SnapshotTarget parses npcID from a Creature GUID and categorizes known dummies", function()
    local NS, M = fresh()
    M.__setTarget({ guid = GOLEM_GUID, name = "Reinforced Golem", level = -1, classification = "elite" })
    local t = NS.Recorder.SnapshotTarget("target")
    assertEqual(t.npcID, 243205)
    assertEqual(t.name, "Reinforced Golem")
    assertEqual(t.category, "boss")
    assertEqual(t.count, 1)
    assertEqual(t.level, -1)
    assertEqual(t.classification, "elite")
end)

test("recorder: SnapshotTarget parses npcID from a Creature GUID and categorizes unknown targets as other", function()
    local NS, M = fresh()
    M.__setTarget({ guid = "Creature-0-3770-2552-1234-99999-0000ABCDEF", name = "Angry Boar", level = 10 })
    local t = NS.Recorder.SnapshotTarget("target")
    assertEqual(t.npcID, 99999)
    assertEqual(t.name, "Angry Boar")
    assertEqual(t.category, "other")
    assertEqual(t.count, 1)
end)

test("recorder: SnapshotTarget on a player or with no target is other with no npcID", function()
    local NS, M = fresh()
    M.__setTarget({ guid = "Player-1-00000002", name = "Someone" })
    local t = NS.Recorder.SnapshotTarget("target")
    assertNil(t.npcID)
    assertEqual(t.category, "other")
    assertEqual(t.name, "Someone")
    M.__setTarget(nil)
    t = NS.Recorder.SnapshotTarget("target")
    assertNil(t.npcID)
    assertNil(t.name)
    assertEqual(t.category, "other")
    assertEqual(t.count, 1)
end)

test("recorder: SnapshotTarget tolerates a secret GUID (records name, category other)", function()
    local NS, M = fresh(function(m) m.issecretvalue = function(v) return T.isSecret(v) end end)
    M.__setTarget({ guid = T.secret(GOLEM_GUID), name = "Reinforced Golem",
                    level = T.secret(-1), classification = T.secret("elite") })
    local t = NS.Recorder.SnapshotTarget("target")
    assertNil(t.npcID, "a secret GUID is never parsed")
    assertEqual(t.name, "Reinforced Golem")
    assertEqual(t.category, "other")
    assertNil(t.level, "a secret never lands in the record")
    assertNil(t.classification)
end)

test("recorder: SnapshotTarget fills a sealed field from the prior snapshot", function()
    local NS, M = fresh(function(m) m.issecretvalue = function(v) return T.isSecret(v) end end)
    M.__setTarget({ guid = GOLEM_GUID, name = "Reinforced Golem", level = -1, classification = "elite" })
    local armed = NS.Recorder.SnapshotTarget("target")
    M.__setTarget({ guid = T.secret(GOLEM_GUID), name = T.secret("Reinforced Golem"), level = T.secret(-1) })
    local t = NS.Recorder.SnapshotTarget("target", armed)
    assertEqual(t.npcID, 243205)
    assertEqual(t.name, "Reinforced Golem")
    assertEqual(t.category, "boss")
    assertEqual(t.level, -1)
    assertTrue(t ~= armed, "a new table, never the prior one edited")
end)

test("recorder: SnapshotWhere records the map, zone, subzone and instance type", function()
    local NS = fresh()
    local w = NS.Recorder.SnapshotWhere()
    assertEqual(w.mapID, 2393)
    assertEqual(w.zone, "Silvermoon City")
    assertEqual(w.subzone, "Falconwing Square")
    assertEqual(w.instanceType, "none")
end)

-- ── NewRun ──────────────────────────────────────────────────────────────────────────────────────

test("recorder: NewRun copies grace and restartGap from the profile", function()
    local NS, M = fresh()
    M.__setTarget({ guid = GOLEM_GUID, name = "Reinforced Golem" })
    NS.db.profile.race.grace = 2.5
    NS.db.profile.race.restartGap = 9
    local r = NS.Recorder.NewRun(180, 3)
    assertEqual(r.status, "armed")
    assertEqual(r.schema, 1)
    assertEqual(r.race.length, 180)
    assertEqual(r.race.grace, 2.5)
    assertEqual(r.race.restartGap, 9)
    assertEqual(r.race.startSource, "meterSession")
    assertNil(r.race.sessionID)
    assertEqual(r.target.count, 3, "the armed count overrides the catalog's")
    assertEqual(r.target.category, "boss")
    assertEqual(r.char.name, "Testchar")
    assertEqual(r.where.zone, "Silvermoon City")
    assertEqual(r.addon, "0.1.0")
    assertEqual(r.build, 120105)
    assertEqual(type(r.date), "number")
    assertEqual(r.note, "")
    assertFalse(r.flags.reloaded)
    assertFalse(r.flags.died)
    assertEqual(#r.flags.lateCasts, 0)
    assertTrue(tostring(r.id):match("^%d+%-%d+$") ~= nil, "id = time() .. '-' .. random: " .. tostring(r.id))
    -- Changing the setting afterwards never re-grades the run (spec §5.2).
    NS.db.profile.race.grace = 0.2
    assertEqual(r.race.grace, 2.5)
end)

test("recorder: NewRun uses the shipped defaults (grace 1.0, restart gap 6)", function()
    local NS = fresh()
    local r = NS.Recorder.NewRun(30)
    assertEqual(r.race.grace, 1.0)
    assertEqual(r.race.restartGap, 6)
    assertEqual(r.target.count, 1, "no count given: the catalog's, else 1")
end)

test("recorder: NewRun never reuses a stored id", function()
    local NS = fresh()
    local seen = {}
    for _ = 1, 50 do
        local r = NS.Recorder.NewRun(30)
        r.status = "running"
        assertNil(seen[r.id], "duplicate id " .. r.id)
        seen[r.id] = true
        NS.Recorder.Save(r)
    end
end)

-- ── the store ───────────────────────────────────────────────────────────────────────────────────

test("recorder: Save stores by id, fires RUN_SAVED, and Get reads it back", function()
    local NS = fresh()
    local heard = listen(NS)
    local r = run("100-1", 100, "complete")
    assertTrue(NS.Recorder.Save(r))
    assertEqual(NS.Recorder.Get("100-1"), r)
    assertEqual(NS.db.global.runs["100-1"], r)
    assertEqual(#heard.saved, 1)
    assertEqual(heard.saved[1], r)
    assertNil(NS.Recorder.Get("nope"))
    assertNil(NS.Recorder.Get(nil))
end)

test("recorder: Save refuses a run without an id", function()
    local NS = fresh()
    local heard = listen(NS)
    assertFalse(NS.Recorder.Save({ status = "complete" }))
    assertFalse(NS.Recorder.Save(nil))
    assertEqual(#heard.saved, 0)
end)

test("recorder: All orders by date desc and excludes armed", function()
    local NS = fresh()
    NS.Recorder.Save(run("100-1", 100, "complete"))
    NS.Recorder.Save(run("300-1", 300, "incomplete"))
    NS.Recorder.Save(run("200-1", 200, "lost"))
    NS.Recorder.Save(run("400-1", 400, "armed"))
    NS.Recorder.Save(run("250-1", 250, "running"))
    local all = NS.Recorder.All()
    assertEqual(#all, 4)
    assertEqual(all[1].id, "300-1")
    assertEqual(all[2].id, "250-1")
    assertEqual(all[3].id, "200-1")
    assertEqual(all[4].id, "100-1")
end)

test("recorder: All breaks a date tie by id, so the order is stable", function()
    local NS = fresh()
    NS.Recorder.Save(run("100-1", 100, "complete"))
    NS.Recorder.Save(run("100-9", 100, "complete"))
    local all = NS.Recorder.All()
    assertEqual(all[1].id, "100-9")
    assertEqual(all[2].id, "100-1")
end)

test("recorder: Pending returns running and stopping only", function()
    local NS = fresh()
    for i, status in ipairs({ "armed", "running", "stopping", "complete", "incomplete", "lost" }) do
        NS.Recorder.Save(run(i .. "-1", 100 + i, status))
    end
    local p = NS.Recorder.Pending()
    assertEqual(#p, 2)
    local got = {}
    for _, r in ipairs(p) do got[r.status] = true end
    assertTrue(got.running)
    assertTrue(got.stopping)
    assertEqual(p[1].status, "running", "oldest first")
end)

test("recorder: Pending holds only the logged-in character's runs", function()
    local NS = fresh()
    local mine, other, nameless = run("1-1", 101, "stopping"), run("2-1", 102, "stopping"), run("3-1", 103, "running")
    mine.char = { name = "Testchar", realm = "Testrealm" }
    other.char = { name = "Otherchar", realm = "Testrealm" }
    for _, r in ipairs({ mine, other, nameless }) do NS.Recorder.Save(r) end
    local p = NS.Recorder.Pending()
    assertEqual(#p, 2)
    assertTrue(p[1] == mine and p[2] == nameless, "another character's run is not this one's to resume")
    assertFalse(NS.Recorder.IsMine({ char = { name = "Testchar", realm = "Elsewhere" } }), "same name, another realm")
end)

test("recorder: a run written by a later schema is left alone", function()
    local NS = fresh()
    local future = run("9-1", 50, "stopping")
    future.schema = NS.Recorder.RUN_SCHEMA + 1
    NS.Recorder.Save(future)
    for i = 1, 3 do NS.Recorder.Save(run(i .. "-1", 100 + i, "complete")) end
    assertEqual(#NS.Recorder.All(), 3, "listed")
    assertEqual(#NS.Recorder.Pending(), 0, "resumed")
    NS.Recorder.Prune(1)
    assertTrue(NS.Recorder.Get("9-1") ~= nil, "pruned as the oldest")
end)

test("recorder: Delete fires RUNS_CHANGED", function()
    local NS = fresh()
    NS.Recorder.Save(run("100-1", 100, "complete"))
    local heard = listen(NS)
    assertTrue(NS.Recorder.Delete("100-1"))
    assertNil(NS.Recorder.Get("100-1"))
    assertEqual(heard.changed, 1)
    assertFalse(NS.Recorder.Delete("100-1"), "already gone")
    assertEqual(heard.changed, 1, "a delete that removed nothing says nothing")
end)

test("recorder: DeleteAll empties the store and fires RUNS_CHANGED", function()
    local NS = fresh()
    NS.Recorder.Save(run("100-1", 100, "complete"))
    NS.Recorder.Save(run("200-1", 200, "complete"))
    local heard = listen(NS)
    assertEqual(NS.Recorder.DeleteAll(), 2)
    assertEqual(#NS.Recorder.All(), 0)
    assertEqual(heard.changed, 1)
end)

test("recorder: the store is account-wide and survives a profile switch", function()
    local NS = fresh()
    NS.Recorder.Save(run("100-1", 100, "complete"))
    NS.db:SetProfile("Other")
    assertTrue(NS.Recorder.Get("100-1") ~= nil)
end)
