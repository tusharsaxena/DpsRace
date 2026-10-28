-- tests/test_dummy_list.lua — your own training dummies (#9, modules/DummyList.lua): the row's parse
-- and normalize, the writes (add, remove, switch a built-in off and back on), the effective catalog
-- Dummies.Lookup answers, the read-time category of a stored run, inference, the captures, and the
-- `/dr targetdummy` verb.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local GOLEM = 243205                 -- a built-in (boss)
local BOAR = 99999                   -- not a dummy
local BOAR_GUID = "Creature-0-3770-2552-1234-99999-0000ABCDEF"
local GOLEM_GUID = "Creature-0-3770-2552-1234-243205-0000ABCDEF"

local function fresh(mutate)
    local inst = T.load({ mutate = mutate })
    return inst.NS, inst.mocks
end

-- ── the stored text ─────────────────────────────────────────────────────────────────────────────

test("dummy list: Parse reads entries and hides, ascending, the last of an ID winning", function()
    local DL = T.NS.DummyList
    local e = DL.Parse(" 300:Cleave , -243205, 12:single, 300:boss ")
    assertEqual(#e, 3)
    assertEqual(e[1].id, 12); assertEqual(e[1].category, "single")
    assertEqual(e[2].id, 300); assertEqual(e[2].category, "boss")
    assertEqual(e[3].id, 243205); assertTrue(e[3].hidden)
    assertEqual(#DL.Parse(""), 0)
    assertNil(DL.Parse("300"), "an entry needs a category")
    assertNil(DL.Parse("300:other"), "other is no category a dummy can have")
    assertNil(DL.Parse("abc:single"))
    assertNil(DL.Parse("0:single"))
    assertNil(DL.Parse(42))
end)

test("dummy list: Normalize drops a custom entry for a built-in and a hide of a non-built-in", function()
    local DL = T.NS.DummyList
    assertEqual(DL.Normalize("300:cleave,243205:single,-12,-243205"), "300:cleave,-243205")
    assertNil(DL.Normalize("300"))
    assertEqual(DL.Normalize(""), "")
end)

test("dummy list: the row refuses what does not parse and stores what it normalizes", function()
    local NS = fresh()
    assertFalse(NS.SetByPath("race.dummies", "300") and true or false)
    assertTrue(NS.SetByPath("race.dummies", "300:Cleave, 243205:boss"))
    assertEqual(NS.db.profile.race.dummies, "300:cleave")
end)

-- ── the effective catalog ───────────────────────────────────────────────────────────────────────

test("dummy list: Add marks a creature, Lookup answers it, Remove takes it off", function()
    local NS = fresh()
    local DL, D = NS.DummyList, NS.Dummies
    assertNil(D.Lookup(BOAR))
    assertEqual(DL.Add(BOAR, "cleave"), "added")
    assertEqual(NS.db.profile.race.dummies, "99999:cleave")
    assertEqual(D.Lookup(BOAR).category, "cleave")
    assertNil(D.Lookup(BOAR).name, "never captured: no name")
    assertNil(DL.Add(BOAR, "cleave"), "the same again changes nothing")
    assertEqual(DL.Add(BOAR, "single"), "changed")
    assertEqual(D.Lookup(BOAR).category, "single")
    assertNil(DL.Add(BOAR, "other"), "no such category")
    assertEqual(DL.Remove(BOAR), "removed")
    assertNil(D.Lookup(BOAR))
    assertNil(DL.Remove(BOAR), "nothing left to remove")
    assertEqual(NS.db.profile.race.dummies, "")
end)

test("dummy list: a built-in is switched off and back on, never recategorized", function()
    local NS = fresh()
    local DL, D = NS.DummyList, NS.Dummies
    assertNil(DL.Add(GOLEM, "single"), "a built-in that is on changes nothing")
    assertEqual(D.Lookup(GOLEM).category, "boss")
    assertEqual(DL.Remove(GOLEM), "hidden")
    assertNil(D.Lookup(GOLEM))
    assertEqual(D.BuiltIn(GOLEM).category, "boss", "the shipped catalog is untouched")
    assertNil(DL.Remove(GOLEM), "already off")
    assertEqual(DL.Add(GOLEM, "single"), "restored")
    assertEqual(D.Lookup(GOLEM).category, "boss", "the catalog's category comes back")
    assertEqual(NS.db.profile.race.dummies, "")
end)

test("dummy list: Reset clears the list; a profile switch reads the other profile's", function()
    local NS = fresh()
    NS.DummyList.Add(BOAR, "pvp")
    NS.DummyList.Remove(GOLEM)
    assertTrue(NS.DummyList.Reset())
    assertEqual(NS.db.profile.race.dummies, "")
    assertEqual(NS.Dummies.Lookup(GOLEM).category, "boss")
    NS.DummyList.Add(BOAR, "pvp")
    NS.db:SetProfile("Other")
    assertNil(NS.Dummies.Lookup(BOAR), "the other profile has no list")
end)

test("dummy list: CategoryOf reads a stored target by its creature as the list is now", function()
    local NS = fresh()
    local D = NS.Dummies
    local boar = { npcID = BOAR, name = "Angry Boar", category = "other" }
    local golem = { npcID = GOLEM, name = "Reinforced Golem", category = "boss" }
    assertEqual(D.CategoryOf(boar), "other")
    NS.DummyList.Add(BOAR, "cleave")
    assertEqual(D.CategoryOf(boar), "cleave")
    NS.DummyList.Remove(GOLEM)
    assertEqual(D.CategoryOf(golem), "other")
    assertEqual(D.CategoryOf({ category = "single" }), "single", "no creature ID: the recorded category")
    assertEqual(D.CategoryOf({}), "other")
    assertEqual(D.CategoryOf(nil), "other")
end)

test("dummy list: a new snapshot of a listed creature is categorized and auto-arm sees it", function()
    local NS, M = fresh()
    M.__setTarget({ guid = BOAR_GUID, name = "Angry Boar", level = 10 })
    assertEqual(NS.Recorder.SnapshotTarget("target").category, "other")
    assertNil(NS.Recorder.DummyOf("target"))
    NS.DummyList.Add(BOAR, "single")
    assertEqual(NS.Recorder.SnapshotTarget("target").category, "single")
    assertEqual(NS.Recorder.DummyOf("target").category, "single")
end)

-- ── the category a new dummy gets ───────────────────────────────────────────────────────────────

test("dummy list: Infer reads a name word, then a boss classification or skull level, else single", function()
    local I = T.NS.DummyList.Infer
    assertEqual(I({ name = "Cleave Training Dummy" }), "cleave")
    assertEqual(I({ name = "Dungeoneer's Training Dummy" }), "dungeoneer")
    assertEqual(I({ name = "PvP Training Dummy" }), "pvp")
    assertEqual(I({ name = "Raider's Training Dummy", level = -1 }), "boss")
    assertEqual(I({ name = "Big Dummy", classification = "worldboss" }), "boss")
    assertEqual(I({ name = "Training Dummy", level = 80 }), "single")
    assertEqual(I(nil), "single")
end)

test("dummy list: CategoryFor takes a typed word, else the row, and auto infers", function()
    local NS = fresh()
    local CF = NS.DummyList.CategoryFor
    local t = { name = "Cleave Training Dummy" }
    assertEqual(CF(t, "boss"), "boss")
    assertEqual(CF(t, "Boss-level"), "boss", "the label works too")
    assertEqual(CF(t, nil), "cleave", "auto")
    assertTrue(NS.SetByPath("race.dummyCategory", "pvp"))
    assertEqual(CF(t, ""), "pvp")
    assertEqual(CF(t, "single"), "single")
end)

-- ── the captures ────────────────────────────────────────────────────────────────────────────────

test("dummy list: Read and Capture keep what the game says, by map, and count the captures", function()
    local NS, M = fresh()
    M.__context.mapID, M.__context.zone, M.__context.subZone = 2393, "Silvermoon City", "Training Grounds"
    M.__context.mapX, M.__context.mapY = 0.41237, 0.6
    M.__setTarget({ guid = BOAR_GUID, name = "Angry Boar", level = 82, classification = "elite",
                    healthMax = 5000000, creatureType = "Mechanical", pvp = false, faction = "Neutral",
                    reaction = 4 })
    local r = NS.DummyList.Read("target")
    assertEqual(r.npcID, BOAR)
    assertEqual(r.health, 5000000)
    assertEqual(r.creatureType, "Mechanical")
    assertFalse(r.pvp)
    assertEqual(r.x, 41.24); assertEqual(r.y, 60)
    local c = NS.DummyList.Capture(r)
    assertEqual(c.count, 1)
    assertEqual(c.name, "Angry Boar")
    assertEqual(c.places[2393].zone, "Silvermoon City")
    assertEqual(c.places[2393].subzone, "Training Grounds")
    assertEqual(NS.db.global.dummies.captures[BOAR], c, "global, by creature ID")
    M.__context.mapID, M.__context.zone = 84, "Stormwind City"
    NS.DummyList.Capture(NS.DummyList.Read("target"))
    assertEqual(c.count, 2)
    assertTrue(c.places[84] ~= nil and c.places[2393] ~= nil, "one line per map")
    assertEqual(NS.DummyList.NameOf(BOAR), "Angry Boar")
end)

test("dummy list: a sealed field is left out of the read, and a player is no creature", function()
    local NS, M = fresh()
    M.__setTarget({ guid = BOAR_GUID, name = "Angry Boar", healthMax = T.secret(5), pvp = T.secret(true) })
    local r = NS.DummyList.Read("target")
    assertNil(r.health)
    assertNil(r.pvp)
    M.__setTarget({ guid = "Player-1-00000002", name = "Someone" })
    assertNil(NS.DummyList.Read("target"))
    M.__setTarget(nil)
    assertNil(NS.DummyList.Read("target"))
end)

test("dummy list: Resolve takes an ID or a captured or cataloged name", function()
    local NS, M = fresh()
    local R = NS.DummyList.Resolve
    assertEqual(R("99999"), BOAR)
    assertEqual(R(" reinforced golem "), GOLEM)
    local id, why = R("Angry Boar")
    assertNil(id); assertEqual(why, "notFound")
    M.__setTarget({ guid = BOAR_GUID, name = "Angry Boar" })
    NS.DummyList.Capture(NS.DummyList.Read("target"))
    assertEqual(R("angry boar"), BOAR)
    assertEqual(select(2, R("  ")), "empty")
    assertEqual(select(2, R("0")), "notFound")
end)

test("dummy list: a captured custom dummy answers its captured name", function()
    local NS, M = fresh()
    M.__setTarget({ guid = BOAR_GUID, name = "Angry Boar" })
    NS.DummyList.Capture(NS.DummyList.Read("target"))
    NS.DummyList.Add(BOAR, "single")
    assertEqual(NS.Dummies.Lookup(BOAR).name, "Angry Boar")
    M.__setTarget({ guid = GOLEM_GUID, name = "Reinforced Golem" })
    assertEqual(NS.Dummies.Lookup(GOLEM).name, "Reinforced Golem")
end)

-- ── read time (T2): the readers follow the list ─────────────────────────────────────────────────

local function storedRun(NS, id, npcID, category)
    local r = {
        id = id, date = os.time() - 60, status = "complete", schema = 1,
        race = { length = 30, grace = 1 }, char = { name = "Traxex", specID = 253, class = "HUNTER" },
        target = { npcID = npcID, name = "Angry Boar", category = category },
        result = { damage = 3000, dps = 100, tail = 2 },
        flags = { lateCasts = {}, reloaded = false, died = false },
    }
    NS.db.global.runs[id] = r
    return r
end

test("dummy list: a stored run moves boards when its creature is added, and back when removed", function()
    local NS = fresh()
    local r = storedRun(NS, "b", BOAR, "other")
    NS.Bests.Invalidate()
    assertEqual(NS.Bests.Board({})["253|other|30"].id, "b")
    NS.DummyList.Add(BOAR, "cleave")
    assertNil(NS.Bests.Board({})["253|other|30"], "the change dropped the cached board")
    assertEqual(NS.Bests.Board({})["253|cleave|30"].id, "b")
    assertEqual(NS.Bests.Key(r), "253|cleave|30")
    assertEqual((NS.ResultsTable.Badge(r.target)), "Cleave")
    NS.DummyList.Remove(BOAR)
    assertEqual(NS.Bests.Board({})["253|other|30"].id, "b")
end)

test("dummy list: switching a built-in off sends its runs to Other; a run with no creature ID keeps its own", function()
    local NS = fresh()
    storedRun(NS, "g", GOLEM, "boss")
    storedRun(NS, "s", nil, "boss")
    NS.Bests.Invalidate()
    NS.DummyList.Remove(GOLEM)
    local board = NS.Bests.Board({})
    assertEqual(board["253|other|30"].id, "g")
    assertEqual(board["253|boss|30"].id, "s", "a sealed creature keeps the recorded category")
end)
