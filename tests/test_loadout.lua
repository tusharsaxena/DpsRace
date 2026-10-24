-- tests/test_loadout.lua — the loadout (#6): the capture (modules/Recorder.lua SnapshotLoadout: the
-- gear links without the shirt and tabard, the talent loadout, every API absent or raising), its
-- deduped store (modules/Loadouts.lua: the hash, a collision, the orphan sweep on every removal), the
-- race taking it at arm and again at its combat end, the run format 2 migration, the detail's gear
-- grid and talents line (modules/Results_Loadout.lua) with the compare's highlights, the Spec cell's
-- tooltip and the share line's optional talents link.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertNil

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
