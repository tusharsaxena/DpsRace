-- tests/test_meter.lua — modules/Meter.lua against the scripted C_DamageMeter (tests/mock_meter.lua):
-- the after-combat read is plain and sorted, a sealed session refuses, the live read never touches a
-- secret, and the adapter is the only file naming the meter or the client's secret detectors.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function fresh()
    local meter
    local inst = T.load{ mutate = function(m) meter = T.mockMeter.install(m) end }
    return inst.NS, meter, inst
end

-- Probe run 8's shape (spec §7), with the spells deliberately NOT in damage order.
local RUN = {
    damage = 1539711, dps = 39479, duration = 39,
    spells = {
        { id = 133, dmg = 300000, dps = 7692 },
        { id = 11366, dmg = 900000, dps = 23076 },
        { id = 108853, dmg = 339711, dps = 8710 },
    },
    others = { { guid = "Player-1-00000002", damage = 2000000, dps = 50000 } },
}

test("meter: the stat and session constants come from the client enum", function()
    local NS = fresh()
    assertEqual(NS.Meter.STAT_DAMAGE_DONE, 0)
    assertEqual(NS.Meter.SESSION_CURRENT, 1)
end)

test("meter: the constants fall back to 0 and 1 without the enum", function()
    local inst = T.load{ mutate = function(m) m.Enum = nil end }
    assertEqual(inst.NS.Meter.STAT_DAMAGE_DONE, 0)
    assertEqual(inst.NS.Meter.SESSION_CURRENT, 1)
end)

test("meter: IsAvailable passes Blizzard's failure reason through", function()
    local NS, meter = fresh()
    local ok, reason = NS.Meter.IsAvailable()
    assertTrue(ok)
    assertNil(reason)
    meter.SetAvailable(false, "The damage meter is disabled.")
    ok, reason = NS.Meter.IsAvailable()
    assertFalse(ok)
    assertEqual(reason, "The damage meter is disabled.", "verbatim, untranslated")
end)

test("meter: IsAvailable answers false with a reason on a client without the API", function()
    local NS, meter = fresh()
    meter.Remove()
    local ok, reason = NS.Meter.IsAvailable()
    assertFalse(ok)
    assertEqual(type(reason), "string")
end)

test("meter: IsAvailable catches a raising client and reports the error", function()
    local NS, meter = fresh()
    meter.SetRaise("IsDamageMeterAvailable", "boom")
    local ok, reason = NS.Meter.IsAvailable()
    assertFalse(ok)
    assertTrue(tostring(reason):find("boom", 1, true) ~= nil)
end)

test("meter: ReadSession returns plain sorted spells after combat", function()
    local NS, meter = fresh()
    meter.SetSession(17, RUN)
    local r, err = NS.Meter.ReadSession(17)
    assertNil(err)
    assertEqual(r.damage, 1539711, "the player's own row, not the session total")
    assertEqual(r.meterDps, 39479)
    assertEqual(r.duration, 39)
    assertEqual(#r.spells, 3)
    assertEqual(r.spells[1].id, 11366)
    assertEqual(r.spells[1].dmg, 900000)
    assertEqual(r.spells[1].dps, 23076)
    assertEqual(r.spells[2].id, 108853)
    assertEqual(r.spells[3].id, 133)
    for _, sp in ipairs(r.spells) do
        assertEqual(type(sp.id), "number")
        assertEqual(type(sp.dmg), "number")
        assertEqual(type(sp.dps), "number")
    end
end)

test("meter: ReadSession reads by ID, for the player's GUID, on DamageDone", function()
    local NS, meter = fresh()
    meter.SetSession(17, RUN)
    meter.SetSession(18, { damage = 5, dps = 1, duration = 5, spells = {} })   -- 18 is now Current
    local r = NS.Meter.ReadSession(17)
    assertEqual(r.damage, 1539711, "an older session is still addressable by ID")
    local src = meter.CallsTo("GetCombatSessionSourceFromID")
    assertTrue(#src >= 1)
    local args = src[#src].args
    assertEqual(args[1], 17)
    assertEqual(args[2], NS.Meter.STAT_DAMAGE_DONE)
    assertEqual(args[3], "Player-1-00000001")
end)

test("meter: ReadSession on a sealed session returns nil,\"sealed\"", function()
    local NS, meter = fresh()
    meter.SetSession(17, RUN)
    meter.SetSecret(true)
    local r, err = NS.Meter.ReadSession(17)
    assertNil(r)
    assertEqual(err, "sealed", "in combat")

    meter.SetSecret(false)
    meter.SetSealed(17, true)
    r, err = NS.Meter.ReadSession(17)
    assertNil(r)
    assertEqual(err, "sealed", "captured in combat, still secret after it")

    meter.SetSealed(17, false)
    r = NS.Meter.ReadSession(17)
    assertEqual(r.damage, 1539711, "readable once unsealed")
end)

test("meter: ReadSession of a session the client no longer holds returns nil,\"missing\"", function()
    local NS, meter = fresh()
    local r, err = NS.Meter.ReadSession(99)
    assertNil(r)
    assertEqual(err, "missing")
    meter.SetSession(17, RUN)
    meter.RemoveSession(17)
    r, err = NS.Meter.ReadSession(17)
    assertNil(r)
    assertEqual(err, "missing")
    r, err = NS.Meter.ReadSession(nil)
    assertNil(r)
    assertEqual(err, "missing")
end)

test("meter: ReadSession catches a raising client and never throws", function()
    local NS, meter = fresh()
    meter.SetSession(17, RUN)
    meter.SetRaise("GetCombatSessionFromID", "client says no")
    local r, err = NS.Meter.ReadSession(17)
    assertNil(r)
    assertTrue(tostring(err):find("client says no", 1, true) ~= nil)
    meter.Remove()
    r, err = NS.Meter.ReadSession(17)
    assertNil(r)
    assertEqual(err, "unavailable")
end)

test("meter: ReadSession with no damage of the player's is a zero result, not an error", function()
    local NS, meter = fresh()
    meter.SetSession(17, { player = false, duration = 39, others = RUN.others })
    local r, err = NS.Meter.ReadSession(17)
    assertNil(err)
    assertEqual(r.damage, 0)
    assertEqual(r.meterDps, 0)
    assertEqual(r.duration, 39)
    assertEqual(#r.spells, 0)
end)

test("meter: live read never performs arithmetic on secrets", function()
    local NS, meter = fresh()
    meter.SetSession(17, RUN)
    meter.SetSecret(true)
    local ok, live = pcall(NS.Meter.ReadLive)
    assertTrue(ok, "ReadLive raised: " .. tostring(live))
    assertTrue(live ~= nil)
    assertTrue(T.isSecret(live.total), "total")
    assertTrue(T.isSecret(live.dps), "dps")
    assertTrue(T.isSecret(live.maxAmount), "maxAmount")
    assertEqual(#live.spells, 3)
    for i, sp in ipairs(live.spells) do
        assertTrue(T.isSecret(sp.spellID), "spell " .. i .. " spellID")
        assertTrue(T.isSecret(sp.total), "spell " .. i .. " total")
        assertTrue(T.isSecret(sp.dps), "spell " .. i .. " dps")
    end
end)

test("meter: the live read keeps Blizzard's order and reads the Current session", function()
    local NS, meter = fresh()
    meter.SetSession(17, RUN)
    local live = NS.Meter.ReadLive()
    assertEqual(T.reveal(live.total), 1539711)
    assertEqual(T.reveal(live.maxAmount), 900000)
    assertEqual(T.reveal(live.spells[1].spellID), 133, "client order, never re-sorted")
    assertEqual(T.reveal(live.spells[2].spellID), 11366)
    local calls = meter.CallsTo("GetCombatSessionSourceFromType")
    local args = calls[#calls].args
    assertEqual(args[1], NS.Meter.SESSION_CURRENT)
    assertEqual(args[2], NS.Meter.STAT_DAMAGE_DONE)
    assertEqual(args[3], "Player-1-00000001")
end)

test("meter: the live read answers nil with no session, no API or a raising client", function()
    local NS, meter = fresh()
    assertNil(NS.Meter.ReadLive(), "no Current session yet")
    meter.SetSession(17, RUN)
    meter.SetRaise("GetCombatSessionSourceFromType", "nope")
    assertNil(NS.Meter.ReadLive())
    meter.Remove()
    assertNil(NS.Meter.ReadLive())
end)

-- The live client (the owner's smoke test, 2026-10-23): the source table carries no amountPerSecond.
-- The figure then comes from the player's own row in combatSources (isLocalPlayer is readable in
-- combat, every number secret), else from the Dps meter type. Every value stays opaque.
local LIVE = {
    damage = 1539711, dps = 39479, duration = 39, sourceDps = false, localFlagPlain = true,
    spells = { { id = 133, dmg = 300000, dps = 7692 } },
    others = { { guid = "Player-1-00000002", damage = 2000000, dps = 50000 } },
}

local function liveWith(fields)
    local data = {}
    for k, v in pairs(LIVE) do data[k] = v end
    for k, v in pairs(fields or {}) do data[k] = v end
    return data
end

test("meter: live DPS is the source's own amountPerSecond when it carries one (rung a)", function()
    local NS, meter = fresh()
    meter.SetSession(17, RUN)
    meter.SetSecret(true)
    local live = NS.Meter.ReadLive()
    assertEqual(live.rung, "source")
    assertTrue(T.isSecret(live.dps))
    assertEqual(T.reveal(live.dps), 39479)
    assertEqual(#meter.CallsTo("GetCombatSessionFromType"), 0, "a further read with rung a answering")
end)

test("meter: with no source amountPerSecond, live DPS is the local row's, opaque (rung b)", function()
    local NS, meter = fresh()
    meter.SetSession(17, liveWith())
    meter.SetSecret(true)
    local ok, live = pcall(NS.Meter.ReadLive)
    assertTrue(ok, "ReadLive raised on a secret: " .. tostring(live))
    assertEqual(live.rung, "localRow")
    assertTrue(T.isSecret(live.dps), "the row's figure is passed through, still secret")
    assertEqual(T.reveal(live.dps), 39479, "the local row's, never the other source's 50000")
    assertTrue(T.isSecret(live.total))
    local calls = meter.CallsTo("GetCombatSessionFromType")
    assertEqual(calls[1].args[1], NS.Meter.SESSION_CURRENT)
    assertEqual(calls[1].args[2], NS.Meter.STAT_DAMAGE_DONE)
end)

test("meter: a local row whose flag is secret is no claim; the Dps meter type answers (rung c)", function()
    local NS, meter = fresh()
    meter.SetSession(17, liveWith({ localFlagPlain = false, dpsType = true }))
    meter.SetSecret(true)
    local ok, live = pcall(NS.Meter.ReadLive)
    assertTrue(ok, "ReadLive raised on a secret: " .. tostring(live))
    assertEqual(live.rung, "dpsType")
    assertTrue(T.isSecret(live.dps))
    assertEqual(T.reveal(live.dps), 39479)
    local calls = meter.CallsTo("GetCombatSessionSourceFromType")
    local args = calls[#calls].args
    assertEqual(args[2], NS.Meter.STAT_DPS)
    assertEqual(args[3], "Player-1-00000001")
end)

test("meter: a local row with no figure of its own falls through to the Dps meter type", function()
    local NS, meter = fresh()
    meter.SetSession(17, liveWith({ rowDps = false, dpsType = true }))
    meter.SetSecret(true)
    local live = NS.Meter.ReadLive()
    assertEqual(live.rung, "dpsType")
    assertEqual(T.reveal(live.dps), 39479)
end)

test("meter: with no rung answering, live DPS is nil and the rest of the read stands", function()
    local NS, meter = fresh()
    meter.SetSession(17, liveWith({ localFlagPlain = false }))
    meter.SetSecret(true)
    local live = NS.Meter.ReadLive()
    assertNil(live.dps)
    assertNil(live.rung)
    assertTrue(T.isSecret(live.total), "damage still shows")
    assertEqual(#live.spells, 1)
end)

test("meter: the rung that served is logged once per race, under the Meter tag", function()
    local NS, meter = fresh()
    meter.SetSession(17, liveWith())
    meter.SetSecret(true)
    local lines = {}
    NS.Debug = function(tag, fmt, ...) if tag == "Meter" then lines[#lines + 1] = fmt:format(...) end end
    NS.Meter.NewLiveRace()
    for _ = 1, 5 do NS.Meter.ReadLive() end
    local served = {}
    for _, l in ipairs(lines) do if l:find("live DPS", 1, true) then served[#served + 1] = l end end
    assertEqual(#served, 1, table.concat(served, " | "))
    assertTrue(served[1]:find("localRow", 1, true) ~= nil, served[1])
    NS.Meter.NewLiveRace()
    NS.Meter.ReadLive()
    local again = 0
    for _, l in ipairs(lines) do if l:find("live DPS", 1, true) then again = again + 1 end end
    assertEqual(again, 2, "a new race logs its rung again")
end)

test("meter: SessionIDs and HasSession track the client's list by plain ID", function()
    local NS, meter = fresh()
    meter.SetSession(17, RUN)
    meter.SetSession(18, RUN)
    meter.SetSecret(true)                        -- IDs stay readable mid-combat (spec §2)
    local ids = NS.Meter.SessionIDs()
    assertTrue(ids[17])
    assertTrue(ids[18])
    assertTrue(NS.Meter.HasSession(17))
    assertFalse(NS.Meter.HasSession(19))
    assertFalse(NS.Meter.HasSession(nil))
    meter.RemoveSession(17)
    assertFalse(NS.Meter.HasSession(17))
    meter.Remove()
    assertEqual(next(NS.Meter.SessionIDs()), nil, "no API is an empty set")
end)

-- spec §8 rule 1, enforced by there being exactly one file with each set of names in it.
local function filesNaming(pattern)
    local out = {}
    for _, path in ipairs(T.loadedAddonFiles) do
        local f = assert(io.open(T.root .. "/" .. path, "rb"))
        local body = f:read("*a")
        f:close()
        if body:find(pattern) then out[#out + 1] = path:gsub("\\", "/") end
    end
    return out
end

test("meter: modules/Meter.lua is the only file that names C_DamageMeter", function()
    local hits = filesNaming("C_DamageMeter")
    assertEqual(#hits, 1, table.concat(hits, ", "))
    assertEqual(hits[1], "modules/Meter.lua")
end)

test("meter: core/Compat.lua is the only file that names the client's secret detectors", function()
    for _, name in ipairs({ "issecretvalue", "canaccessvalue", "canaccesstable", "issecrettable" }) do
        local hits = filesNaming(name)
        assertEqual(#hits, 1, name .. ": " .. table.concat(hits, ", "))
        assertEqual(hits[1], "core/Compat.lua", name)
    end
end)

test("meter: core/Secrets.lua is the only caller of NS.Compat's secret guards", function()
    for _, name in ipairs({ "IsSecret", "CanAccess", "IsSafeKey" }) do
        local callers = {}
        for _, path in ipairs(filesNaming("Compat%." .. name)) do
            if path ~= "core/Compat.lua" then callers[#callers + 1] = path end
        end
        assertEqual(#callers, 1, name .. ": " .. table.concat(callers, ", "))
        assertEqual(callers[1], "core/Secrets.lua", name)
    end
end)
