-- tests/test_casts.lua — modules/Casts.lua, the race's cast list (#14): the stored format (Encode,
-- Decode), the important-ability selection and the grouping (pure), and the capture: what is heard,
-- filtered (auto-repeat, a castGUID heard twice, a channel's ticks, a sealed spell ID) and timed on the
-- race clock.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function near(got, want, msg)
    assertTrue(type(got) == "number" and math.abs(got - want) < 1e-6,
        (msg or "value") .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- A fresh instance's Casts, with GetSpellBaseCooldown answering `cds` and counting its calls.
local function fresh(cds)
    local inst = T.load()
    local M = inst.mocks
    local calls = {}
    M.GetSpellBaseCooldown = function(id)
        calls[id] = (calls[id] or 0) + 1
        return (cds or {})[id], 1500
    end
    return inst.NS.Casts, calls, inst
end

-- ── the record format (pure) ────────────────────────────────────────────────────────────────────

test("casts: Encode writes centiseconds, a p before a pet cast, comma-joined", function()
    local Casts = T.NS.Casts
    local s = Casts.Encode({ { t = -1.6, id = 6353 }, { t = 0.004, id = 1122 }, { t = 12.345, id = 3110, pet = true } })
    assertEqual(s, "-160:6353,0:1122,1235:p3110")
    assertEqual(Casts.Encode({}), "")
    assertEqual(Casts.Encode(nil), "")
end)

test("casts: Decode reads the stored string back, skipping what does not parse", function()
    local Casts = T.NS.Casts
    local list = Casts.Decode("-160:6353,0:1122,1235:p3110,junk,7:,:9")
    assertEqual(#list, 3)
    near(list[1].t, -1.6)
    assertEqual(list[1].id, 6353)
    assertFalse(list[1].pet)
    near(list[3].t, 12.35)
    assertTrue(list[3].pet)
    assertEqual(#Casts.Decode(nil), 0)
    assertEqual(#Casts.Decode(""), 0)
    -- A round trip keeps every cast.
    local again = Casts.Decode(Casts.Encode(list))
    assertEqual(Casts.Encode(again), Casts.Encode(list))
end)

test("casts: an important ability's base cooldown is more than 15 s", function()
    local Casts = T.NS.Casts
    local spells = { [1] = 15000, [2] = 15001, [3] = 0 }
    assertFalse(Casts.IsImportant(spells, 1), "exactly 15 s is not over it")
    assertTrue(Casts.IsImportant(spells, 2))
    assertFalse(Casts.IsImportant(spells, 3))
    assertFalse(Casts.IsImportant(spells, 4), "an unknown cooldown is not important")
    assertFalse(Casts.IsImportant(nil, 2))
    local list = Casts.Filter(Casts.Decode("0:1,100:2,200:3,300:2"), spells)
    assertEqual(#list, 2)
    near(list[2].t, 3)
end)

test("casts: Important and Of read a run's record; a run without one has none", function()
    local Casts = T.NS.Casts
    local run = { casts = { v = 1, list = "-50:1122,100:29722,9000:1122", spells = { [1122] = 180000, [29722] = 0 },
                            dropped = 0 } }
    local imp = Casts.Important(run)
    assertEqual(#imp, 2)
    near(imp[1].t, -0.5)
    near(imp[2].t, 90)
    assertEqual(#Casts.Of(run), 3)
    assertNil(Casts.Of({ schema = 2 }), "a format-2 run has no cast list")
    assertEqual(#Casts.Important({ schema = 2 }), 0)
    assertEqual(#Casts.Important(nil), 0)
end)

test("casts: Group puts cooldowns first, longest first, then the rest by count", function()
    local Casts = T.NS.Casts
    local list = Casts.Decode("0:1,100:2,200:2,300:3,400:p4,500:p4,600:p4,700:5,800:2,50:1")
    local groups = Casts.Group(list, { [1] = 30000, [2] = 0, [3] = 120000, [5] = 15000 })
    local order = {}
    for i, g in ipairs(groups) do order[i] = (g.pet and "p" or "") .. g.id .. "x" .. g.count end
    assertEqual(table.concat(order, ","), "3x1,1x2,2x3,p4x3,5x1")
    assertEqual(groups[2].cd, 30000)
    near(groups[2].times[1], 0)
    near(groups[2].times[2], 0.5, "the times are in order")
    assertEqual(groups[4].cd, 0, "an unknown cooldown groups as 0")
end)

-- ── the capture ─────────────────────────────────────────────────────────────────────────────────

test("casts: nothing is heard before Begin or after Stop; other units are never heard", function()
    local Casts = fresh()
    Casts.Hear("succeeded", "player", 29722, "Cast-0", 100)
    Casts.Begin()
    Casts.Start(100)
    Casts.Hear("succeeded", "party1", 29722, "Cast-1", 101)
    Casts.Hear("succeeded", "target", 29722, "Cast-2", 101)
    Casts.Hear("start", "player", 29722, "Cast-3", 101)
    assertEqual(#Casts.Live(), 0)
    Casts.Hear("succeeded", "player", 29722, "Cast-4", 102)
    Casts.Stop()
    assertFalse(Casts.Collecting())
    Casts.Hear("succeeded", "player", 29722, "Cast-5", 103)
    local live = Casts.Live()
    assertEqual(#live, 1, "after Stop the list stays readable, and grows no more")
    near(live[1].t, 2)
    Casts.Reset()
    assertEqual(#Casts.Live(), 0)
    assertNil(Casts.Record())
end)

test("casts: times are on the race clock; a cast heard while armed is negative", function()
    local Casts = fresh({ [1122] = 180000, [29722] = 0 })
    Casts.Begin()
    Casts.Hear("succeeded", "player", 29722, "Cast-1", 98.567)
    assertEqual(#Casts.Live(), 0, "before the clock starts there is no time to give")
    assertNil(Casts.Record())
    Casts.Start(100)
    Casts.Hear("succeeded", "player", 1122, "Cast-2", 100.004)
    Casts.Hear("succeeded", "pet", 3110, "Cast-3", 101.5)
    local rec = Casts.Record()
    assertEqual(rec.v, 1)
    assertEqual(rec.list, "-143:29722,0:1122,150:p3110")
    assertEqual(rec.spells[1122], 180000)
    assertEqual(rec.spells[29722], 0)
    assertNil(rec.spells[3110], "an unknown cooldown is left out")
    assertEqual(rec.dropped, 0)
end)

test("casts: auto-repeat attacks, a castGUID heard twice and a sealed spell ID are filtered", function()
    local Casts, calls = fresh({ [1122] = 180000 })
    Casts.Begin()
    Casts.Start(100)
    for _, id in ipairs({ 75, 6603, 5019 }) do Casts.Hear("succeeded", "player", id, "Auto-" .. id, 101) end
    Casts.Hear("succeeded", "pet", 6603, "Auto-pet", 101)
    Casts.Hear("succeeded", "player", 1122, "Cast-1", 102)
    Casts.Hear("succeeded", "player", 1122, "Cast-1", 102.2)
    Casts.Hear("succeeded", "player", T.secret(29722), "Cast-2", 103)
    Casts.Hear("succeeded", "pet", T.secret(3110), T.secret("Cast-3"), 103)
    -- A sealed castGUID: no dedupe, but the cast is kept (its ID is plain).
    Casts.Hear("succeeded", "player", 1122, T.secret("Cast-4"), 104)
    Casts.Hear("succeeded", "player", 1122, T.secret("Cast-4"), 104)
    local rec = Casts.Record()
    assertEqual(rec.list, "200:1122,400:1122,400:1122")
    assertEqual(rec.dropped, 2)
    assertEqual(calls[1122], 1, "a spell's base cooldown is read once")
end)

test("casts: a channel counts once, whether its success comes before or after the channel start", function()
    local Casts = fresh()
    Casts.Begin()
    Casts.Start(100)
    -- CHANNEL_START first, then a SUCCEEDED per tick.
    Casts.Hear("channel", "player", 5740, "Ch-1", 101)
    Casts.Hear("succeeded", "player", 5740, "Ch-1a", 101)
    Casts.Hear("succeeded", "player", 5740, "Ch-1b", 102)
    Casts.Hear("succeeded", "player", 29722, "Other", 102.5)   -- another spell is never a tick
    Casts.Hear("succeeded", "pet", 5740, "Pet-1", 102.6)       -- nor the pet's
    Casts.Hear("succeeded", "player", 5740, "Ch-1c", 103)
    Casts.Hear("channelStop", "player", 5740, "Ch-1", 104)
    -- SUCCEEDED first, on the channel start's own frame.
    Casts.Hear("succeeded", "player", 5740, "Ch-2", 105)
    Casts.Hear("channel", "player", 5740, "Ch-2", 105)
    Casts.Hear("succeeded", "player", 5740, "Ch-2a", 106)
    Casts.Hear("channelStop", "player", 5740, "Ch-2", 107)
    -- After the stop, a fresh cast of it counts.
    Casts.Hear("succeeded", "player", 5740, "Ch-3", 108)
    assertEqual(Casts.Record().list, "100:5740,250:29722,260:p5740,500:5740,800:5740")
end)
