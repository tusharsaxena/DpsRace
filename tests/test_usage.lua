-- tests/test_usage.lua — modules/Usage.lua, what the player used (#13): the arm snapshot over the
-- client's item, bag and aura reads (no weapon enchant); detection from a snapshot, the casts and the
-- after counts (pure); the player's edit; the hidden items (the setting's parse, Hide and Unhide, what
-- is shown); the race end to end (arm to the stored record, casts and usage, nothing secret; the
-- pre-pull window, a lost race, a stand-down); the run record's format 3 migration; and the sample
-- history's casts and usage.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local F = dofile(T.root .. "/tests/race_clock.lua")(T)

local function near(got, want, msg)
    assertTrue(type(got) == "number" and math.abs(got - want) < 1e-6,
        (msg or "value") .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- The items the cases use: a trinket in slot 13, a potion, a flask and a Healthstone in the bags.
local TRINKET, TRINKET_SPELL = 190001, 400001
local POTION, POTION_SPELL = 211001, 431932
local FLASK, FLASK_SPELL = 211002, 432021
local STONE, STONE_SPELL = 5512, 6262
local ENCHANT = 8051

--- The client as the race cases see it: the trinket worn, the three consumables in the backpack
--- (the potion over two stacks), a sword in the bags (not a consumable), the flask's buff and Well
--- Fed on, an oil on the main hand (never listed: an oil has no on-use).
local function stock(M)
    M.__gear[13] = "|cnIQ4:|Hitem:" .. TRINKET .. "::::::::80:267::::::::|h[Test Trinket]|h|r"
    M.__itemSpells[TRINKET] = TRINKET_SPELL
    M.__itemSpells[POTION], M.__itemSpells[FLASK], M.__itemSpells[STONE] = POTION_SPELL, FLASK_SPELL, STONE_SPELL
    M.__itemSpells[777] = 7777
    M.__itemInfo[POTION], M.__itemInfo[FLASK], M.__itemInfo[STONE] = { 0, 1 }, { 0, 3 }, { 0, 0 }
    M.__itemInfo[777] = { 2, 7 }
    M.__bags[0] = { size = 6, [1] = { POTION, 2 }, [2] = { FLASK, 2 }, [4] = { STONE, 1 }, [5] = { POTION, 1 },
                    [6] = { 777, 1 } }
    M.__auras = { { FLASK_SPELL, "Flask of Testing" }, { 1459, "Arcane Intellect" }, { 999, "Well Fed" } }
    M.__weaponEnchant = { main = ENCHANT }
    M.__baseCooldowns = { [TRINKET_SPELL] = 120000, [POTION_SPELL] = 300000, [1122] = 180000, [29722] = 0,
                          [5740] = 8000 }
end

-- A snapshot by hand: the shape Usage.Snapshot answers.
local function snapOf()
    return {
        gear = { { slot = 13, itemID = TRINKET, spellID = TRINKET_SPELL } },
        bags = { [POTION] = { count = 3, subclass = 1, spellID = POTION_SPELL },
                 [FLASK] = { count = 2, subclass = 3, spellID = FLASK_SPELL },
                 [STONE] = { count = 1, subclass = 0, spellID = STONE_SPELL } },
        auras = { { spellID = FLASK_SPELL, name = "Flask of Testing" }, { spellID = 999, name = "Well Fed" } },
    }
end

local function kinds(list)
    local out = {}
    for i, e in ipairs(list) do out[i] = e.kind .. ":" .. e.src end
    return table.concat(out, ",")
end

-- ── the snapshot ────────────────────────────────────────────────────────────────────────────────

test("usage: the arm snapshot reads the on-use slots, the bag consumables and the auras, never the enchants", function()
    local inst = T.load({ mutate = stock })
    local snap = inst.NS.Usage.Snapshot()
    assertEqual(#snap.gear, 1, "only a slot whose item has a use")
    assertEqual(snap.gear[1].slot, 13)
    assertEqual(snap.gear[1].spellID, TRINKET_SPELL)
    assertEqual(snap.bags[POTION].count, 3, "the potion's two stacks summed")
    assertEqual(snap.bags[POTION].subclass, 1)
    assertEqual(snap.bags[FLASK].spellID, FLASK_SPELL)
    assertNil(snap.bags[777], "not a consumable")
    assertEqual(#snap.auras, 3)
    assertEqual(snap.auras[3].name, "Well Fed")
    assertNil(snap.enchants, "the oil on the main hand is not read")
    local counts = inst.NS.Usage.BagCounts()
    assertEqual(counts[POTION], 3)
    assertEqual(counts[777], 1)
end)

test("usage: an unreadable bag stack makes the after counts unknown, never a false drop", function()
    local inst = T.load({ mutate = stock })
    inst.mocks.__bags[0][4] = { STONE, T.secret(1) }
    assertNil(inst.NS.Usage.BagCounts())
    -- Without the container API at all, the same.
    inst.mocks.C_Container = nil
    assertNil(inst.NS.Usage.BagCounts())
    local snap = inst.NS.Usage.Snapshot()
    assertEqual(next(snap.bags), nil)
end)

test("usage: a client without the APIs snapshots nothing and raises nothing", function()
    local inst = T.load()
    inst.mocks.C_UnitAuras, inst.mocks.C_Container = nil, nil
    local snap = inst.NS.Usage.Snapshot()
    assertEqual(#snap.gear, 0)
    assertEqual(#snap.auras, 0)
end)

-- ── detection (pure) ────────────────────────────────────────────────────────────────────────────

test("usage: detection stacks casts, the bag drop and the arm's auras, in that order", function()
    local Usage = T.NS.Usage
    local casts = T.NS.Casts.Decode("-50:29722,300:" .. TRINKET_SPELL .. ",400:" .. POTION_SPELL .. ",9000:"
        .. TRINKET_SPELL .. ",500:p" .. TRINKET_SPELL)
    local after = { [POTION] = 2, [FLASK] = 2 }   -- the Healthstone is gone with no cast
    local used = Usage.Detect(snapOf(), casts, after)
    assertEqual(kinds(used), "gear:cast,potion:cast,other:bag,flask:buff,food:buff")
    assertEqual(used[1].itemID, TRINKET)
    assertEqual(used[1].slot, 13)
    assertEqual(used[1].n, 2, "a pet's cast of the same spell is not the player's use")
    near(used[1].times[1], 3)
    near(used[1].times[2], 90)
    assertEqual(used[2].itemID, POTION)
    near(used[2].times[1], 4)
    assertEqual(used[3].itemID, STONE)
    assertEqual(used[3].n, 1)
    assertNil(used[3].times, "a bag drop has no time")
    assertEqual(used[4].itemID, FLASK)
    assertNil(used[5].itemID, "food is the buff, no item")
end)

test("usage: a cast item's count drop is not counted again; unknown after counts detect no drop", function()
    local Usage = T.NS.Usage
    local snap = snapOf()
    snap.auras = {}
    local casts = T.NS.Casts.Decode("400:" .. POTION_SPELL)
    local used = Usage.Detect(snap, casts, { [POTION] = 2, [FLASK] = 2, [STONE] = 1 })
    assertEqual(kinds(used), "potion:cast")
    used = Usage.Detect(snap, {}, nil)
    assertEqual(#used, 0)
    -- Two of a potion gone with no cast: used twice, time unknown.
    used = Usage.Detect(snap, {}, { [POTION] = 1, [FLASK] = 2, [STONE] = 1 })
    assertEqual(kinds(used), "potion:bag")
    assertEqual(used[1].n, 2)
end)

test("usage: a drop the casts before the pre-pull window explain is given back, never read as a use", function()
    local Usage = T.NS.Usage
    local snap = snapOf()
    snap.auras = {}
    local after = { [POTION] = 2, [FLASK] = 2, [STONE] = 1 }
    assertEqual(kinds(Usage.Detect(snap, {}, after)), "potion:bag", "without the early casts")
    assertEqual(#Usage.Detect(snap, {}, after, { [POTION_SPELL] = 1 }), 0, "the potion drunk minutes before")
    -- Two gone, one drunk early: the other is still a use; more early casts than the drop give back no more.
    local used = Usage.Detect(snap, {}, { [POTION] = 1, [FLASK] = 2, [STONE] = 1 }, { [POTION_SPELL] = 1 })
    assertEqual(kinds(used), "potion:bag")
    assertEqual(used[1].n, 1)
    assertEqual(#Usage.Detect(snap, {}, after, { [POTION_SPELL] = 5, [1122] = 1 }), 0)
    assertEqual(after[POTION], 2, "the counts given are not changed")
    assertEqual(kinds(Usage.Detect(snap, {}, nil, { [POTION_SPELL] = 1 })), "", "unknown counts stay unknown")
end)

test("usage: of two items with one use spell, a cast is the one whose count dropped", function()
    local Usage = T.NS.Usage
    local snap = { gear = {}, auras = {},
                   bags = { [100] = { count = 4, subclass = 1, spellID = 55 }, [200] = { count = 4, subclass = 1, spellID = 55 } } }
    local casts = T.NS.Casts.Decode("100:55")
    local used = Usage.Detect(snap, casts, { [100] = 4, [200] = 3 })
    assertEqual(#used, 1)
    assertEqual(used[1].itemID, 200)
    used = Usage.Detect(snap, casts, nil)
    assertEqual(used[1].itemID, 100, "unknown counts: the first")
end)

test("usage: the candidates are the on-use gear, then every bag consumable by item", function()
    local Usage = T.NS.Usage
    local c = Usage.Candidates(snapOf())
    assertEqual(#c, 4)
    assertEqual(c[1].kind, "gear")
    assertEqual(c[1].slot, 13)
    assertEqual(c[2].itemID, STONE)
    assertEqual(c[2].kind, "other")
    assertEqual(c[3].kind, "potion")
    assertEqual(c[4].kind, "flask")
    assertNil(Usage.Build(nil, {}, {}))
    local rec = Usage.Build(snapOf(), {}, nil)
    assertEqual(rec.v, 1)
    assertFalse(rec.edited)
    assertEqual(#rec.candidates, 4)
end)

-- ── the edit ────────────────────────────────────────────────────────────────────────────────────

test("usage: SetUsed keeps a detected entry, adds a manual one and announces RUNS_CHANGED", function()
    local inst = T.load()
    local NS = inst.NS
    local changed = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.RUNS_CHANGED, function() changed = changed + 1 end)
    local run = { id = "r1", usage = NS.Usage.Build(snapOf(), NS.Casts.Decode("300:" .. TRINKET_SPELL), nil) }
    local trinket = run.usage.used[1]
    assertTrue(NS.Usage.SetUsed(run, {
        { itemID = TRINKET, kind = "gear", slot = 13 },
        { itemID = POTION, kind = "potion" },
        { kind = "food" },
        { itemID = T.secret(5), kind = "nonsense" },
    }))
    local used = run.usage.used
    assertEqual(#used, 4)
    assertTrue(used[1] == trinket, "the detected entry keeps its times and source")
    assertEqual(used[2].src, "manual")
    assertEqual(used[2].n, 1)
    assertNil(used[2].times)
    assertEqual(used[3].src, "buff", "the detected food")
    assertEqual(used[4].kind, "other")
    assertNil(used[4].itemID, "a sealed value is never stored")
    assertTrue(run.usage.edited)
    assertEqual(changed, 1)
    assertNil(F.findSecret(run))
    -- A sample run changes in memory only.
    local sample = { id = "s1", sample = true, usage = NS.Usage.Build(snapOf(), {}, nil) }
    assertTrue(NS.Usage.SetUsed(sample, {}))
    assertEqual(#sample.usage.used, 0)
    assertEqual(changed, 1, "no RUNS_CHANGED for a sample")
    assertFalse(NS.Usage.SetUsed({ id = "old" }, {}), "a run without usage")
end)

test("usage: SetUsed matches each tick to its own entry by slot, never one entry twice", function()
    local NS = T.load().NS
    -- A pair of one trinket, each used at its own time.
    local used = {
        { itemID = TRINKET, kind = "gear", slot = 13, times = { 5 }, n = 1, src = "cast" },
        { itemID = TRINKET, kind = "gear", slot = 14, times = { 9 }, n = 1, src = "cast" },
    }
    local run = { id = "s1", sample = true, usage = { v = 1, used = { used[1], used[2] },
        candidates = { { itemID = TRINKET, kind = "gear", slot = 13 }, { itemID = TRINKET, kind = "gear", slot = 14 } } } }
    assertTrue(NS.Usage.SetUsed(run, {
        { itemID = TRINKET, kind = "gear", slot = 14 }, { itemID = TRINKET, kind = "gear", slot = 13 },
    }))
    local out = run.usage.used
    assertEqual(#out, 2)
    assertTrue(out[1] == used[2], "the slot 14 trinket keeps its own time")
    assertTrue(out[2] == used[1], "the slot 13 trinket keeps its own time")
    -- Ticks with no slot still take each entry once.
    run.usage.used = { used[1], used[2] }
    NS.Usage.SetUsed(run, { { itemID = TRINKET, kind = "gear" }, { itemID = TRINKET, kind = "gear" } })
    assertTrue(run.usage.used[1] == used[1] and run.usage.used[2] == used[2], "one entry each")
end)

test("usage: a tick with a slot answers only an entry in that slot", function()
    local NS = T.load().NS
    -- The trinket's entry with no slot, and one in 13.
    local used = {
        { itemID = TRINKET, kind = "gear", times = { 2 }, n = 1, src = "cast" },
        { itemID = TRINKET, kind = "gear", slot = 13, times = { 5 }, n = 1, src = "cast" },
    }
    local run = { id = "s1", sample = true, usage = { v = 1, candidates = {}, used = { used[1], used[2] } } }
    NS.Usage.SetUsed(run, { { itemID = TRINKET, kind = "gear", slot = 14 }, { itemID = TRINKET, kind = "gear", slot = 13 } })
    local out = run.usage.used
    assertEqual(#out, 2)
    assertFalse(out[1] == used[1] or out[1] == used[2], "the trinket in 14 is not either one used")
    assertEqual(out[1].src, "manual")
    assertEqual(out[1].slot, 14)
    assertNil(out[1].times)
    assertTrue(out[2] == used[2], "the slot 13 tick is its own entry")
end)

test("usage: an unticked food joins the candidates, once, and ticked again keeps its source; an old enchant goes", function()
    local NS = T.load().NS
    -- A run stored before the enchants were dropped (2026-10-26) carries their entries.
    local run = { id = "s1", sample = true, usage = { v = 1, candidates = {}, used = {
        { kind = "food", n = 1, src = "buff" },
        { kind = "enchant", slot = 16, enchantID = ENCHANT, n = 1, src = "enchant" },
    } } }
    NS.Usage.SetUsed(run, {})
    local c = run.usage.candidates
    assertEqual(#c, 1, "Well Fed alone: the enchant is never listed, so it simply goes")
    assertEqual(c[1].kind, "food")
    assertNil(c[1].itemID)
    assertEqual(#run.usage.used, 0)
    NS.Usage.SetUsed(run, {})
    assertEqual(#run.usage.candidates, 1, "not listed twice")
    NS.Usage.SetUsed(run, { { kind = "food" }, { kind = "enchant", slot = 16, enchantID = ENCHANT } })
    assertEqual(run.usage.used[1].src, "buff", "food ticked again was active at the start")
    assertEqual(run.usage.used[2].kind, "other", "an enchant is no kind any more")
    assertNil(run.usage.used[2].enchantID)
end)

-- ── the hidden items ────────────────────────────────────────────────────────────────────────────

test("usage: the hidden items parse from their setting, sorted and once each, and refuse anything else", function()
    local U = T.load().NS.Usage
    assertEqual(table.concat(U.ParseHidden(" 300, 12,300 ,, 7 "), ","), "7,12,300")
    assertEqual(#U.ParseHidden(""), 0)
    assertNil(U.ParseHidden("12,abc"))
    assertNil(U.ParseHidden("12,-3"))
    assertNil(U.ParseHidden("0"))
    assertNil(U.ParseHidden("1.5"))
    assertNil(U.ParseHidden(12))
end)

test("usage: Hide and Unhide write the whole list through the seam; Shown leaves out hidden items and enchants", function()
    local NS = T.load().NS
    local U = NS.Usage
    local heard = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path, v) heard[#heard + 1] = path .. "=" .. tostring(v) end)
    assertEqual(NS.GetSetting(U.HIDDEN_PATH), "", "nothing hidden by default")
    assertTrue(U.Hide(POTION))
    assertTrue(U.Hide(STONE))
    assertFalse(U.Hide(POTION), "already hidden")
    assertFalse(U.Hide(T.secret(5)), "a sealed value")
    assertEqual(NS.db.global.usage.hidden, STONE .. "," .. POTION, "ascending, in the global store")
    assertEqual(heard[#heard], U.HIDDEN_PATH .. "=" .. STONE .. "," .. POTION)
    assertTrue(U.HiddenSet()[POTION])
    assertFalse(U.Shown({ itemID = POTION, kind = "potion" }))
    assertTrue(U.Shown({ itemID = FLASK, kind = "flask" }))
    assertTrue(U.Shown({ kind = "food" }))
    assertFalse(U.Shown({ kind = "enchant", slot = 16, enchantID = ENCHANT }), "an old record's enchant")
    assertTrue(U.Unhide(POTION))
    assertFalse(U.Unhide(POTION))
    assertEqual(table.concat(U.HiddenList(), ","), tostring(STONE))
    assertTrue(U.Shown({ itemID = POTION, kind = "potion" }))
    -- The CLI's write goes through the row's validate.
    assertFalse(NS.SetByPath(U.HIDDEN_PATH, "12,abc"))
    assertTrue(NS.SetByPath(U.HIDDEN_PATH, "6948, 201"))
    assertEqual(NS.db.global.usage.hidden, "201,6948", "stored as Hide writes it")
    assertEqual(table.concat(U.HiddenList(), ","), "201,6948")
end)

test("usage: the known items are every item the stored runs list, newest run first, each once", function()
    local NS = T.load().NS
    NS.db.global.runs.a = { id = "a", date = 10, usage = { v = 1, used = { { itemID = POTION, kind = "potion" } },
        candidates = { { itemID = TRINKET, kind = "gear", slot = 13 }, { itemID = POTION, kind = "potion" } } } }
    NS.db.global.runs.b = { id = "b", date = 20, usage = { v = 1, used = { { kind = "food" } },
        candidates = { { itemID = FLASK, kind = "flask" } } } }
    NS.db.global.runs.old = { id = "old", date = 30 }
    assertEqual(table.concat(NS.Usage.KnownItems(), ","), table.concat({ FLASK, POTION, TRINKET }, ","))
end)

-- ── the race, end to end ────────────────────────────────────────────────────────────────────────

test("usage: Watchers hears the casts from the arm, for the player and the pet", function()
    local f = F.new()
    assertTrue(f:arm(30))
    local units = f.NS.Watchers.Frame().__unitEvents
    assertEqual(table.concat(units.UNIT_SPELLCAST_SUCCEEDED, ","), "player,pet")
    assertEqual(table.concat(units.UNIT_SPELLCAST_CHANNEL_START, ","), "player")
    assertNil(units.UNIT_SPELLCAST_START, "the late-cast judging's starts wait for the clock")
    f:start(25)
    units = f.NS.Watchers.Frame().__unitEvents
    assertEqual(table.concat(units.UNIT_SPELLCAST_START, ","), "player")
    assertEqual(table.concat(units.UNIT_SPELLCAST_SUCCEEDED, ","), "player,pet")
end)

test("usage: a race stores its casts and usage at the result, and nothing secret", function()
    local f = F.new({ mutate = stock })
    local M = f.M
    local function cast(event, unit, guid, id) M.__fire("UNIT_SPELLCAST_" .. event, unit, guid, id) end
    assertTrue(f:arm(30))
    f:to(101)
    cast("SUCCEEDED", "player", "Cast-0", 29722)            -- a pre-pull cast, heard while armed
    f:to(102)
    f:start(25)
    local run = f.Race.Current()
    f:to(102.5)
    cast("SUCCEEDED", "player", "Cast-1", 1122)
    f:to(103)
    cast("SUCCEEDED", "pet", "Cast-2", 3110)
    f:to(103.5)
    cast("SUCCEEDED", "player", "Cast-3", 75)               -- Auto Shot
    f:to(104)
    cast("SUCCEEDED", "player", "Cast-1", 1122)             -- the same castGUID again
    f:to(105)
    cast("SUCCEEDED", "player", "Cast-4", TRINKET_SPELL)
    f:to(106)
    cast("SUCCEEDED", "player", "Cast-5", POTION_SPELL)
    M.__bags[0][5] = nil                                     -- the potion's second stack is gone
    f:to(106.5)
    cast("SUCCEEDED", "player", T.secret("Cast-6"), T.secret(29722))
    f:to(107)
    cast("CHANNEL_START", "player", "Cast-7", 5740)
    cast("SUCCEEDED", "player", "Cast-7a", 5740)
    f:to(108)
    cast("SUCCEEDED", "player", "Cast-7b", 5740)            -- a tick
    f:to(109)
    cast("CHANNEL_STOP", "player", "Cast-7", 5740)
    f:to(110)
    cast("SUCCEEDED", "player", "Cast-8", 5740)
    M.__bags[0][4] = nil                                     -- the Healthstone, with no cast
    f:to(134)                                                -- the buzzer went at 132
    cast("SUCCEEDED", "pet", "Cast-9", 3110)                 -- the pet after the grace: never late
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
    assertEqual(run.status, "complete")
    assertEqual(#run.flags.lateCasts, 0, "the late-cast judging heard only the player")
    assertEqual(run.schema, f.NS.Recorder.RUN_SCHEMA)

    local stored = f:stored(run.id)
    assertTrue(stored == run)
    assertEqual(run.casts.v, 1)
    assertEqual(run.casts.list, "-100:29722,50:1122,100:p3110,300:" .. TRINKET_SPELL .. ",400:" .. POTION_SPELL
        .. ",500:5740,800:5740,3200:p3110")
    assertEqual(run.casts.dropped, 1)
    assertEqual(run.casts.spells[1122], 180000)
    assertEqual(run.casts.spells[29722], 0)
    assertNil(run.casts.spells[3110])
    assertEqual(#f.NS.Casts.Important(run), 3, "the Infernal, the trinket and the potion")

    local u = run.usage
    assertEqual(u.v, 1)
    assertFalse(u.edited)
    assertEqual(kinds(u.used), "gear:cast,potion:cast,other:bag,flask:buff,food:buff", "the oil is not listed")
    near(u.used[1].times[1], 3)
    near(u.used[2].times[1], 4)
    assertEqual(u.used[3].itemID, STONE)
    assertEqual(u.used[4].itemID, FLASK)
    assertEqual(#u.candidates, 4)
    assertNil(F.findSecret(run), "a secret reached the stored run at " .. tostring(F.findSecret(run)))
end)

test("usage: a cast heard more than 10 s before the pull is not this race's, in the list or the usage", function()
    local f = F.new({ mutate = stock })
    local M = f.M
    assertTrue(f:arm(30))
    f:to(110)
    M.__fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-0", POTION_SPELL)   -- a potion, 40 s before
    M.__bags[0][5] = nil
    f:to(145)
    M.__fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 29722)          -- inside the window
    f:to(150)
    f:start(25)
    local run = f.Race.Current()
    f:to(152)
    M.__fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", TRINKET_SPELL)
    f:to(184)
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
    assertEqual(run.casts.list, "-500:29722,200:" .. TRINKET_SPELL)
    assertNil(run.casts.spells[POTION_SPELL])
    assertEqual(kinds(run.usage.used), "gear:cast,flask:buff,food:buff",
        "the early potion is neither a cast use nor a bag drop")
end)

test("usage: a lost race stores its casts and usage too, and nothing secret", function()
    local f = F.new({ mutate = stock })
    local M = f.M
    local function cast(guid, id) M.__fire("UNIT_SPELLCAST_SUCCEEDED", "player", guid, id) end
    assertTrue(f:arm(30))
    f:to(101)
    f:start(25)
    local run = f.Race.Current()
    f:to(103)
    cast("Cast-1", TRINKET_SPELL)
    f:to(104)
    cast(T.secret("Cast-2"), POTION_SPELL)
    cast("Cast-3", T.secret(1122))
    M.__bags[0][4] = nil                              -- the Healthstone, with no cast
    M.__bags[0][1] = { POTION, T.secret(1) }          -- a count the bag read cannot trust
    f:to(110)
    f.Race.OnMeterReset()
    assertEqual(run.status, "lost")
    assertTrue(f:stored(run.id) == run, "kept")
    assertEqual(run.casts.list, "200:" .. TRINKET_SPELL .. ",300:" .. POTION_SPELL)
    assertEqual(run.casts.dropped, 1)
    assertEqual(kinds(run.usage.used), "gear:cast,potion:cast,flask:buff,food:buff",
        "a sealed stack count reads the bags as unknown: no bag drop")
    assertEqual(#run.usage.candidates, 4)
    assertFalse(f.NS.Casts.Collecting())
    assertNil(F.findSecret(run), "a secret reached the stored run at " .. tostring(F.findSecret(run)))
end)

test("usage: a stand-down stops the cast list and drops it", function()
    local f = F.new()
    assertTrue(f:arm(30))
    f.M.__fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1122)
    assertTrue(f.NS.Casts.Collecting())
    assertTrue(f.NS.SetByPath("enabled", false))
    assertFalse(f.NS.Casts.Collecting(), "Race.Suspend resets the casts")
    f.NS.Casts.Hear("succeeded", "player", 1122, "Cast-2", f:now())
    f.NS.Casts.Start(f:now())
    assertEqual(f.NS.Casts.Size(), 0, "nothing heard or kept after it")
    assertNil(f.NS.Casts.Record())
end)

test("usage: a canceled race keeps nothing; the next arm starts a fresh list", function()
    local f = F.new()
    assertTrue(f:arm(30))
    f.M.__fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1122)
    assertTrue(f.Race.Cancel())
    assertFalse(f.NS.Casts.Collecting())
    assertTrue(f:arm(30))
    f:start(25)
    f:to(101)
    f.M.__fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 29722)
    f:to(130)
    f:combatEnd()
    f:advance(3)
    local run = f.Race.Current()
    assertEqual(run.casts.list, "100:29722")
    assertTrue(type(run.usage) == "table" and #run.usage.used == 0)
end)

test("usage: a run resumed after a /reload keeps no casts and no usage", function()
    local f = F.new({ enable = false })
    f.meter.SetSession(25, F.SESSION)
    f.NS.db.global.runs["1792758447-4429"] = F.storedRun({ status = "stopping" })
    f:enable()
    f:advance(1)
    local run = f.NS.Recorder.Get("1792758447-4429")
    assertTrue(run.status == "complete" or run.status == "incomplete", run.status)
    assertNil(run.casts)
    assertNil(run.usage)
end)

-- ── the record format's migration ───────────────────────────────────────────────────────────────

test("usage: the format 3 migration raises the stamp and rewrites no run", function()
    local inst = T.load({ init = false })
    local NS = inst.NS
    local old = { id = "old", schema = 2, status = "complete", date = 5, race = { length = 30 },
                  result = { damage = 9, dps = 0.3 }, spells = {}, note = "kept" }
    _G.DpsRaceDB = { global = { schemaVersion = 2, schema = 2, runs = { old = old } } }
    inst.mocks._G.DpsRaceDB = _G.DpsRaceDB
    NS:InitDB()
    NS:RunMigrations()
    local g = NS.db.global
    assertEqual(g.schemaVersion, NS.SCHEMA_VERSION)
    assertEqual(g.schema, NS.Recorder.RUN_SCHEMA, "the format stamp answers the current format")
    local run = g.runs.old
    assertEqual(run.schema, 2, "an old run was rewritten")
    assertNil(run.casts)
    assertNil(run.usage)
    assertNil(NS.Casts.Of(run), "a format-2 run reads as not recorded")
    assertEqual(NS.Recorder.All()[1].id, "old", "a format-2 run is still listed")
end)

-- ── the samples ─────────────────────────────────────────────────────────────────────────────────

test("usage: the sample history and the sim's race carry casts and usage", function()
    local inst = T.load({ mutate = function(m)
        stock(m)
        m.__context.classToken = "WARLOCK"
    end })
    local NS = inst.NS
    local data = NS.MockRuns.Dataset()
    local with, without = 0, 0
    for _, run in ipairs(data.runs) do
        if run.casts then
            with = with + 1
            assertTrue(#NS.Casts.Of(run) > 0, run.id)
            assertTrue(type(run.usage) == "table" and #run.usage.used > 0, run.id)
        else
            without = without + 1
            assertEqual(run.schema, 2, "the run without casts is the format-2 one")
            assertNil(run.usage)
        end
    end
    assertEqual(without, 1)
    assertEqual(with, #data.runs - 1)
    local mine = data.runs[1]
    assertTrue(mine.casts.list:find("p3110", 1, true) ~= nil, "the imp's casts")
    assertTrue(mine.casts.list:find("^%-1%d%d:6353") ~= nil, "a pre-pull cast first")
    assertEqual(kinds(mine.usage.used), "gear:cast,potion:cast,flask:buff,food:buff", "no enchant")
    local gearAt = mine.usage.used[1].times[1] - NS.MockRuns.GEAR_AT
    assertTrue(gearAt >= 0 and gearAt <= 0.2, "the gear's use, a little off the mark run to run")
    local sample = NS.Sim.Sample("newbest", data)
    assertTrue(#NS.Casts.Important(sample.run) > 0, "the sim's race has cooldown casts")
    assertNil(F.findSecret(data))
end)

test("usage: a player with no consumables gets the sample Healthstone, used with no cast", function()
    local inst = T.load()
    local casts, usage = inst.NS.MockRuns.Usage(nil, 30)
    assertTrue(#inst.NS.Casts.Decode(casts.list) > 0)
    assertEqual(kinds(usage.used), "other:bag,food:buff")
    assertEqual(usage.used[1].itemID, 5512)
    assertEqual(#usage.candidates, 1)
end)
