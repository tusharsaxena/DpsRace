-- tests/test_stats.lua — the stats a run was raced with (#17, modules/Stats.lua): the capture at the
-- arm (every value read, a secret one absent, a client without the APIs or one that raises), the run
-- carrying it (Recorder.NewRun, the race's arm), the run-record format 4 migration leaving old runs
-- alone, and the pure display: each group's rows, the dashes for a run with none, and the deltas.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

-- The client's stat APIs over one settable table; `over` replaces fields (T.secret for a sealed one).
local function statMocks(m, over)
    local v = {
        primaryStat = 4, intellect = 12345.4, stamina = 98765, armor = 4321,
        ratings = { [9] = 1234, [18] = 2345, [26] = 3456, [29] = 456, [17] = 120, [21] = 80, [14] = 60 },
        crit = 25.304, haste = 18.5, mastery = 41.256, versBonus = 3.1, versExtra = 0.5,
        leech = 1.2, avoidance = 0.8, speed = 2.05,
    }
    for k, x in pairs(over or {}) do v[k] = x end
    m.__stats = v
    m.GetSpecialization = function() return 1 end
    m.GetSpecializationInfo = function() return 267, "Destruction", "", 0, "DAMAGER", v.primaryStat end
    m.UnitStat = function(_, i)
        if i == 4 then return 1000, v.intellect, 0, 0 end
        if i == 3 then return 1000, v.stamina, 0, 0 end
        return 1, 2, 0, 0
    end
    m.UnitArmor = function() return 100, v.armor end
    m.GetCombatRating = function(i) return v.ratings[i] end
    m.GetCritChance = function() return v.crit end
    m.GetRangedCritChance = function() return v.rangedCrit end
    m.GetSpellCritChance = function(school) return v.spellCrit and v.spellCrit[school] end
    m.GetHaste = function() return v.haste end
    m.GetMasteryEffect = function() return v.mastery, 1.5 end
    m.GetCombatRatingBonus = function() return v.versBonus end
    m.GetVersatilityBonus = function() return v.versExtra end
    m.GetLifesteal = function() return v.leech end
    m.GetAvoidance = function() return v.avoidance end
    m.GetSpeed = function() return v.speed end
end

local function fresh(over)
    local inst = T.load{ mutate = function(m) statMocks(m, over) end }
    return inst.NS, inst.mocks
end

-- ── the capture ─────────────────────────────────────────────────────────────────────────────────

test("stats: Snapshot reads the primary stat, stamina, armor and every rating with its percent", function()
    local NS = fresh()
    local s = NS.Stats.Snapshot()
    assertEqual(s.v, 1)
    assertEqual(s.primaryStat, 4, "the spec's primary stat (Intellect)")
    assertEqual(s.primary, 12345, "whole numbers")
    assertEqual(s.stamina, 98765)
    assertEqual(s.armor, 4321)
    assertEqual(s.critRating, 1234)
    assertEqual(s.crit, 25.3, "percents to two decimals")
    assertEqual(s.hasteRating, 2345)
    assertEqual(s.haste, 18.5)
    assertEqual(s.masteryRating, 3456)
    assertEqual(s.mastery, 41.26)
    assertEqual(s.versRating, 456)
    assertEqual(s.vers, 3.6, "versatility's rating bonus plus its flat bonus")
    assertEqual(s.leechRating, 120)
    assertEqual(s.leech, 1.2)
    assertEqual(s.avoidanceRating, 80)
    assertEqual(s.avoidance, 0.8)
    assertEqual(s.speedRating, 60)
    assertEqual(s.speed, 2.05)
end)

test("stats: crit is the highest of melee, ranged and each spell school's, as the character panel shows", function()
    local NS = fresh({ crit = 20.1, rangedCrit = 22.5,
                       spellCrit = { [2] = 24, [3] = T.secret(99), [6] = 31.456, [7] = 30 } })
    assertEqual(NS.Stats.Snapshot().crit, 31.46, "the shadow school's crit is the panel's")
    NS = fresh({ crit = 20.1, rangedCrit = 22.5 })
    assertEqual(NS.Stats.Snapshot().crit, 22.5, "ranged over melee, no spell crit readable")
    NS = fresh({ crit = T.secret(40), spellCrit = { [2] = 18 } })
    assertEqual(NS.Stats.Snapshot().crit, 18, "a secret reading is skipped, not compared")
end)

test("stats: a secret value is stored as absent, never compared or kept", function()
    local NS = fresh({ crit = T.secret(25.3), stamina = T.secret(98765), primaryStat = T.secret(4),
                       ratings = { [9] = T.secret(1234), [18] = 2345 } })
    local s = NS.Stats.Snapshot()
    assertNil(s.crit, "a secret percent was kept")
    assertNil(s.critRating, "a secret rating was kept")
    assertNil(s.stamina, "a secret stamina was kept")
    assertNil(s.primaryStat, "a secret primary stat index was kept")
    assertNil(s.primary, "the primary stat read without its index")
    assertEqual(s.hasteRating, 2345, "the plain values stay")
    for k, v in pairs(s) do
        assertTrue(not T.isSecret(v), "a secret reached the record: " .. tostring(k))
    end
end)

test("stats: a client without the APIs, or one that raises, yields absent fields; nothing readable is nil", function()
    local NS, M = fresh()
    M.GetCritChance = function() error("boom") end
    M.UnitArmor = nil
    local s = NS.Stats.Snapshot()
    assertNil(s.crit)
    assertNil(s.armor)
    assertEqual(s.haste, 18.5)
    for _, name in ipairs({ "UnitStat", "UnitArmor", "GetCombatRating", "GetCritChance", "GetRangedCritChance",
                            "GetSpellCritChance", "GetHaste",
                            "GetMasteryEffect", "GetCombatRatingBonus", "GetVersatilityBonus", "GetLifesteal",
                            "GetAvoidance", "GetSpeed", "GetSpecialization", "GetSpecializationInfo" }) do
        M[name] = nil
    end
    assertNil(NS.Stats.Snapshot(), "nothing readable, yet a record")
end)

test("stats: a new run carries the arm's stats; a run without any reads as none", function()
    local NS = fresh()
    local run = NS.Recorder.NewRun(30)
    assertEqual(run.schema, 4)
    assertEqual(run.stats.critRating, 1234)
    assertEqual(NS.Stats.Of(run).primary, 12345)
    assertNil(NS.Stats.Of({ id = "old", schema = 3 }))
    assertNil(NS.Stats.Of(nil))
end)

test("stats: the format 4 migration raises the stamp and rewrites no run", function()
    local inst = T.load({ init = false })
    local NS = inst.NS
    local old = { id = "old", schema = 3, status = "complete", date = 5, race = { length = 30 },
                  result = { damage = 9, dps = 0.3 }, spells = {}, note = "kept" }
    _G.DpsRaceDB = { global = { schemaVersion = 4, schema = 3, runs = { old = old } } }
    inst.mocks._G.DpsRaceDB = _G.DpsRaceDB
    NS:InitDB()
    NS:RunMigrations()
    local g = NS.db.global
    assertEqual(g.schemaVersion, 5)
    assertEqual(g.schema, 4)
    assertEqual(g.runs.old.schema, 3, "an old run was rewritten")
    assertNil(g.runs.old.stats)
    NS:RunMigrations()
    assertEqual(g.schemaVersion, 5, "the step ran twice")
end)

-- ── the display ─────────────────────────────────────────────────────────────────────────────────

test("stats: Groups lays out Primary, Secondary and Tertiary with each value's text", function()
    local NS = fresh()
    local s = NS.Stats.Snapshot()
    local groups = NS.Stats.Groups(s)
    assertEqual(#groups, 3)
    assertEqual(groups[1].title, "Primary")
    assertEqual(groups[2].title, "Secondary")
    assertEqual(groups[3].title, "Tertiary")
    local p = groups[1].rows
    assertEqual(p[1].label, "Intellect", "the spec's primary stat names the row")
    assertEqual(p[1].text, "12,345")
    assertEqual(p[2].label, "Stamina")
    assertEqual(p[2].text, "98,765")
    assertEqual(p[3].label, "Armor")
    local sec = groups[2].rows
    assertEqual(#sec, 4)
    assertEqual(sec[1].label, "Critical Strike")
    assertEqual(sec[1].text, "1,234 \194\183 25.30%", "the rating and the percent")
    assertEqual(sec[4].label, "Versatility")
    local ter = groups[3].rows
    assertEqual(#ter, 3)
    assertEqual(ter[1].label, "Leech")
    assertEqual(ter[3].text, "60 \194\183 2.05%")
    assertNil(sec[1].delta, "a delta with nothing to compare with")
end)

test("stats: a run without stats shows dashes in every row", function()
    local NS = fresh()
    for _, g in ipairs(NS.Stats.Groups(nil, NS.Stats.Snapshot())) do
        for _, r in ipairs(g.rows) do
            assertEqual(r.text, "\226\128\148", r.key)
            assertNil(r.delta, r.key)
        end
    end
    assertEqual(NS.Stats.Groups(nil)[1].rows[1].label, "Primary stat")
end)

test("stats: deltas against the compared run, signed, the percent deciding a rated row", function()
    local NS = fresh()
    local s = NS.Stats.Snapshot()
    local o = {}
    for k, v in pairs(s) do o[k] = v end
    o.primary, o.critRating, o.crit, o.hasteRating, o.haste = s.primary + 300, s.critRating - 140, s.crit - 1.17,
        s.hasteRating + 10, s.haste - 0.2
    local text, sign = NS.Stats.Delta(s, o, "primary")
    assertEqual(text, "-300")
    assertEqual(sign, -1)
    text, sign = NS.Stats.Delta(s, o, "crit", true)
    assertEqual(text, "+140 \194\183 +1.17%")
    assertEqual(sign, 1)
    text, sign = NS.Stats.Delta(s, o, "haste", true)
    assertEqual(text, "-10 \194\183 +0.20%")
    assertEqual(sign, 1, "the percent decides")
    text, sign = NS.Stats.Delta(s, o, "stamina")
    assertEqual(text, "+0")
    assertEqual(sign, 0)
    o.primaryStat = 2
    assertNil(NS.Stats.Delta(s, o, "primary"), "another primary stat has no delta")
    o.mastery, o.masteryRating = nil, nil
    assertNil(NS.Stats.Delta(s, o, "mastery", true), "no delta when the other run lacks the value")
    assertEqual(NS.Stats.Grouped(-1234567), "-1,234,567")
end)
