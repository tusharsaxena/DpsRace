-- tests/test_dummies.lua — defaults/Dummies.lua: the measured catalog (spec §4.6), its lookup by
-- creature ID, and the six categories with an enUS label each.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertNil

-- Spec §4.6, verbatim. A row is added from a measurement, never guessed.
local CATALOG = {
    { 243167, "Dungeoneer's Training Dummy", "dungeoneer" },
    { 243168, "Dungeoneer's Training Dummy", "dungeoneer" },
    { 243208, "Cleave Training Dummy",       "cleave" },
    { 243205, "Reinforced Golem",            "boss" },
    { 243211, "PvP Training Dummy",          "pvp" },
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
