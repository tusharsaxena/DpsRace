-- tests/test_dummies.lua — defaults/Dummies.lua: the measured catalog (spec §4.6), its lookup by
-- creature ID, and the six categories with an enUS label each.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertNil

-- Spec §4.6, verbatim. A row is added from a measurement, never guessed.
local CATALOG = {
    { 31146, "Raider's Training Dummy",        "boss" },
    { 65310, "Turnip Punching Bag",            "boss" },
    { 67127, "Training Dummy",                 "single" },
    { 114832, "PvP Training Dummy",             "pvp" },
    { 126781, "Training Dummy",                 "single" },
    { 131983, "Raider's Training Dummy",        "boss" },
    { 131989, "Training Dummy",                 "single" },
    { 131992, "Dungeoneer's Training Dummy",    "dungeoneer" },
    { 144078, "Dungeoneer's Training Dummy",    "dungeoneer" },
    { 144081, "Training Dummy",                 "single" },
    { 144082, "Training Dummy",                 "single" },
    { 144085, "Training Dummy",                 "single" },
    { 144086, "Raider's Training Dummy",        "boss" },
    { 153285, "Training Dummy",                 "single" },
    { 153292, "Training Dummy",                 "single" },
    { 189617, "Boulderfist",                    "boss" },
    { 189632, "Animated Duelist",               "boss" },
    { 194643, "Dungeoneer's Training Dummy",    "dungeoneer" },
    { 194644, "Dungeoneer's Training Dummy",    "dungeoneer" },
    { 194648, "Training Dummy",                 "single" },
    { 194649, "Normal Tank Dummy",              "single" },
    { 196394, "Tuskarr Training Dummy",         "boss" },
    { 197833, "PvP Training Dummy",             "pvp" },
    { 198594, "Cleave Training Dummy",          "cleave" },
    { 199057, "Black Dragon's Challenge Dummy", "boss" },
    { 216458, "Sparring Dummy",                 "single" },
    { 219250, "PvP Training Dummy",             "pvp" },
    { 225976, "Normal Tank Dummy",              "single" },
    { 225977, "Dungeoneer's Training Dummy",    "dungeoneer" },
    { 225978, "Crystalmaw",                     "boss" },
    { 225982, "Cleave Training Dummy",          "cleave" },
    { 225983, "Dungeoneer's Training Dummy",    "dungeoneer" },
    { 225984, "Training Dummy",                 "single" },
    { 225985, "Kelpfist",                       "boss" },
    { 243166, "Normal Tank Dummy",              "single" },
    { 243167, "Dungeoneer's Training Dummy",    "dungeoneer" },
    { 243168, "Dungeoneer's Training Dummy",    "dungeoneer" },
    { 243205, "Reinforced Golem",               "boss" },
    { 243206, "Heavyweight Golem",              "boss" },
    { 243207, "Training Dummy",                 "single" },
    { 243208, "Cleave Training Dummy",          "cleave" },
    { 243211, "PvP Training Dummy",             "pvp" },
}

test("dummies: Lookup known and unknown npcID", function()
    local D = T.NS.Dummies
    for _, row in ipairs(CATALOG) do
        local d = D.Lookup(row[1])
        assertTrue(d ~= nil, "cataloged: " .. row[1])
        assertEqual(d.name, row[2])
        assertEqual(d.category, row[3])
        assertNil(d.count, "no target count (DpsRace#15)")
    end
    assertNil(D.Lookup(1))
    assertNil(D.Lookup(nil))
    assertNil(D.Lookup("243205"), "the key is a number; the caller converts")
end)

test("dummies: the catalog holds exactly the measured rows", function()
    local n = 0
    for _ in pairs(T.NS.Dummies.BY_ID) do n = n + 1 end
    assertEqual(n, #CATALOG)
end)

test("dummies: Lookup answers a copy, so a caller cannot edit the catalog", function()
    local D = T.NS.Dummies
    local d = D.Lookup(243205)
    d.name = "Edited"
    assertEqual(D.Lookup(243205).name, "Reinforced Golem")
end)

test("dummies: six categories in order, each with an enUS label", function()
    local D = T.NS.Dummies
    local want = { "single", "cleave", "dungeoneer", "boss", "pvp", "other" }
    assertEqual(#D.CATEGORIES, #want)
    for i, key in ipairs(want) do assertEqual(D.CATEGORIES[i], key) end
    local labels = {
        single = "Single target", cleave = "Cleave", dungeoneer = "Dungeoneer",
        boss = "Boss-level", pvp = "PvP", other = "Other",
    }
    for key, label in pairs(labels) do
        assertEqual(D.LABELS[key], label)
        assertEqual(D.Label(key), label)
        assertEqual(T.NS.L[label], label, "the label is a locale key")
    end
    assertEqual(D.Label("nonsense"), "Other", "an unknown category labels as Other")
end)

test("dummies: every cataloged category is one of the six", function()
    local D = T.NS.Dummies
    for id, d in pairs(D.BY_ID) do
        assertTrue(D.LABELS[d.category] ~= nil, "category of " .. id)
    end
end)
