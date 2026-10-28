-- tests/test_late_ignore.lua — the late-cast ignore list (#8, modules/LateIgnore.lua): the hearthstone
-- table's pins; the setting's parse, normalize and join; the read memo and the 8690 expansion; Ignore,
-- Unignore and Reset through the seam; what a typed spell resolves to (a number, a link, a hearthstone's
-- name, a default the character does not know, a degraded load); the known spells; and the read-time
-- effect on the readers: the result card's chips, the share line, the Results detail's ticks and lines,
-- the cached boards, a profile switch (the STOP body's count is in tests/test_hud.lua).

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local DEFAULT = "66,1856,5384,8690,58984,110959"
local FEIGN, VANISH, HEARTH, INCINERATE = 5384, 1856, 8690, 29722
local TOY, ASTRAL = 191329, 556   -- a toy hearthstone (also named "Hearthstone"), and a class spell

-- The client's spell names the cases read: three IDs share "Hearthstone", as in the live data.
local NAMES = {
    [FEIGN] = "Feign Death", [VANISH] = "Vanish", [HEARTH] = "Hearthstone", [TOY] = "Hearthstone",
    [401802] = "Hearthstone", [231504] = "Town Portal", [INCINERATE] = "Incinerate", [ASTRAL] = "Astral Recall",
    [66] = "Invisibility", [58984] = "Shadowmeld", [110959] = "Greater Invisibility",
}

local function named(M)
    M.C_Spell = {
        GetSpellName = function(id) return NAMES[id] end,
        GetSpellTexture = function(id) return 1000 + id end,
        -- The library's spell info: by ID any spell; by name none (the character knows none of these).
        GetSpellInfo = function(key)
            if type(key) ~= "number" or not NAMES[key] then return nil end
            return { name = NAMES[key], iconID = 1000 + key }
        end,
    }
end

local function fresh()
    local inst = T.load({ mutate = named })
    return inst.NS, inst.mocks
end

local function joined(list) return table.concat(list, ",") end

local function late(...)
    local out = {}
    for i, c in ipairs({ ... }) do out[i] = { t = c[1], spellID = c[2] } end
    return out
end

-- ── the hearthstone table ───────────────────────────────────────────────────────────────────────

test("late ignore: the hearthstone table holds 59 positive IDs, once each, with 8690, Dalaran and Garrison, never 556", function()
    local list, seen = T.NS.HEARTHSTONE_SPELLS, {}
    assertEqual(#list, 59, "the count from the build in the file's header")
    for _, id in ipairs(list) do
        assertTrue(type(id) == "number" and id >= 1 and id % 1 == 0, tostring(id))
        assertFalse(seen[id] == true, "listed twice: " .. tostring(id))
        seen[id] = true
    end
    assertEqual(list[1], HEARTH)
    assertTrue(seen[222695] and seen[171253], "the Dalaran and Garrison hearthstones")
    assertNil(seen[ASTRAL], "Astral Recall is a class spell, never a variant")
    assertTrue(T.NS.LateIgnore.IsHearthstone(TOY))
    assertFalse(T.NS.LateIgnore.IsHearthstone(FEIGN))
end)

-- ── the stored text ─────────────────────────────────────────────────────────────────────────────

test("late ignore: the setting parses sorted and once each, refuses anything else, and joins back", function()
    local LI = T.NS.LateIgnore
    assertEqual(joined(LI.Parse(" 5384, 66,5384 ,, 1856 ")), "66,1856,5384")
    assertEqual(#LI.Parse(""), 0)
    assertNil(LI.Parse("66,abc"))
    assertNil(LI.Parse("0"))
    assertNil(LI.Parse("1.5"))
    assertNil(LI.Parse(66))
    assertEqual(LI.Join({ 5384, 66 }), "66,5384")
    assertEqual(LI.Normalize("5384, 66"), "66,5384")
    assertNil(LI.Normalize("x"))
end)

test("late ignore: Normalize drops a variant while 8690 is listed and keeps it alone", function()
    local LI = T.NS.LateIgnore
    assertEqual(LI.Normalize("191329, 8690, 5384"), "5384,8690", "8690 already covers the toy")
    assertEqual(LI.Normalize("191329,5384"), "5384,191329", "on its own the variant stays")
end)

test("late ignore: the default is the profile's, and 8690 stands for every hearthstone in Set only", function()
    local NS = fresh()
    local LI = NS.LateIgnore
    assertEqual(LI.DEFAULT, NS.defaults.profile.race.lateIgnore)
    assertEqual(LI.DEFAULT, DEFAULT)
    assertEqual(NS.GetSetting(LI.PATH), DEFAULT)
    assertEqual(joined(LI.List()), DEFAULT, "one entry for the hearthstones")
    local set = LI.Set()
    for _, id in ipairs(NS.HEARTHSTONE_SPELLS) do assertTrue(set[id], "variant " .. id) end
    assertTrue(set[FEIGN] and set[VANISH])
    assertNil(set[ASTRAL])
    assertTrue(LI.Set() == set, "one parse while the text holds")
    assertTrue(LI.IsIgnored(TOY))
    assertFalse(LI.IsIgnored(nil), "a sealed cast is never ignored")
    assertFalse(LI.IsIgnored(INCINERATE))
    assertTrue(NS.SetByPath(LI.PATH, "5384"))
    assertFalse(LI.Set() == set, "a new text, a new parse")
    assertFalse(LI.IsIgnored(TOY))
end)

-- ── the writes ──────────────────────────────────────────────────────────────────────────────────

test("late ignore: Ignore, Unignore and Reset write the whole list through the seam", function()
    local NS = fresh()
    local LI = NS.LateIgnore
    local heard = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path, v)
        heard[#heard + 1] = path .. "=" .. tostring(v)
    end)
    assertTrue(LI.Ignore(INCINERATE))
    assertFalse(LI.Ignore(INCINERATE), "already ignored")
    assertFalse(LI.Ignore(TOY), "8690 already covers it")
    assertFalse(LI.Ignore(T.secret(5)), "a sealed value")
    assertFalse(LI.Ignore(0))
    assertEqual(NS.db.profile.race.lateIgnore, "66,1856,5384,8690,29722,58984,110959", "in the profile")
    assertEqual(heard[#heard], LI.PATH .. "=66,1856,5384,8690,29722,58984,110959")
    assertTrue(LI.Unignore(INCINERATE))
    assertFalse(LI.Unignore(INCINERATE))
    assertEqual(NS.GetSetting(LI.PATH), DEFAULT)
    -- A variant ignored only through 8690: its undo takes 8690 off, so it is never an undo that does nothing.
    assertEqual(LI.Covering(TOY), HEARTH)
    assertEqual(LI.Covering(FEIGN), FEIGN)
    assertNil(LI.Covering(INCINERATE))
    assertTrue(LI.Unignore(TOY))
    assertFalse(LI.IsIgnored(TOY))
    assertFalse(LI.IsIgnored(HEARTH))
    assertEqual(NS.GetSetting(LI.PATH), "66,1856,5384,58984,110959")
    -- A variant on its own, then 8690 over it: the variant folds into 8690.
    assertTrue(LI.Ignore(TOY))
    assertEqual(NS.GetSetting(LI.PATH), "66,1856,5384,58984,110959,191329")
    assertTrue(LI.Ignore(HEARTH))
    assertEqual(NS.GetSetting(LI.PATH), DEFAULT)
    assertTrue(NS.SetByPath(LI.PATH, ""))
    assertEqual(#LI.List(), 0)
    assertTrue(LI.Reset())
    assertEqual(NS.GetSetting(LI.PATH), DEFAULT)
    -- The CLI's write goes through the row's validate and normalize.
    assertFalse(NS.SetByPath(LI.PATH, "66,abc"))
    assertTrue(NS.SetByPath(LI.PATH, "5384, 191329, 8690"))
    assertEqual(NS.db.profile.race.lateIgnore, "5384,8690")
end)

-- ── what a typed spell is ───────────────────────────────────────────────────────────────────────

test("late ignore: Resolve takes a number, a link, a hearthstone's name and a default the character does not know", function()
    local NS = fresh()
    local LI = NS.LateIgnore
    local id, name, icon = LI.Resolve("5384")
    assertEqual(id, FEIGN)
    assertEqual(name, "Feign Death")
    assertEqual(icon, 1000 + FEIGN)
    assertEqual((LI.Resolve(FEIGN)), FEIGN, "a number as a number")
    assertEqual((LI.Resolve("|cff71d5ff|Hspell:1856:0|h[Vanish]|h|r")), VANISH)
    assertEqual((LI.Resolve(" hearthstone ")), HEARTH, "the word")
    assertEqual((LI.Resolve("Hearthstone")), HEARTH, "three IDs share the name: never ambiguous")
    assertEqual((LI.Resolve("town portal")), HEARTH, "a variant's own name")
    assertEqual((LI.Resolve(tostring(TOY))), TOY, "a variant by ID stays itself")
    assertEqual((LI.Resolve("Vanish")), VANISH, "a Hunter cannot look it up; the defaults are candidates")
    local none, why = LI.Resolve("Frostbolt")
    assertNil(none)
    assertEqual(why, "notFound")
    none, why = LI.Resolve("  ")
    assertNil(none)
    assertEqual(why, "empty")
    -- A spell a stored run cast late is a candidate too.
    NS.db.global.runs.a = { id = "a", date = 5, flags = { lateCasts = late({ 1.4, INCINERATE }) } }
    assertEqual((LI.Resolve("incinerate")), INCINERATE)
end)

test("late ignore: on a degraded load a number, a link and a hearthstone still resolve", function()
    local inst = T.load({ libFiles = {}, mutate = named })
    local LI = inst.NS.LateIgnore
    assertEqual((LI.Resolve("5384")), FEIGN)
    assertEqual((LI.Resolve("spell:1856")), VANISH)
    assertEqual((LI.Resolve("Hearthstone")), HEARTH)
    assertNil((LI.Resolve("Vanish")), "the name lookup is the library's")
end)

test("late ignore: the known spells are every late cast's spell, newest run first, then the defaults", function()
    local NS = fresh()
    NS.db.global.runs.a = { id = "a", date = 10, flags = { lateCasts = late({ 1.4, INCINERATE }, { 2, FEIGN }) } }
    NS.db.global.runs.b = { id = "b", date = 20, flags = { lateCasts = late({ 3, 17962 }, { 4 }) } }
    NS.db.global.runs.c = { id = "c", date = 30 }
    assertEqual(joined(NS.LateIgnore.KnownSpells()), "17962,29722,5384,66,1856,8690,58984,110959")
end)

-- ── the readers ─────────────────────────────────────────────────────────────────────────────────

local function storedRun(NS, id, date, dps, casts)
    local r = {
        id = id, date = date, status = "complete", schema = 1,
        race = { length = 30, grace = 1 }, char = { name = "Traxex", specID = 253 },
        target = { category = "boss" }, result = { damage = dps * 30, dps = dps, tail = 2 },
        flags = { lateCasts = casts or {}, reloaded = false, died = false },
    }
    NS.db.global.runs[id] = r
    return r
end

test("late ignore: the result card's chips count only the counted casts; all ignored, no chip", function()
    local NS = fresh()
    local mixed = storedRun(NS, "m", 1, 100, late({ 1.4, FEIGN }, { 2.0, INCINERATE }))
    local chips = NS.HudStates.FlagChips(mixed)
    assertEqual(#chips, 1)
    assertEqual(chips[1].text, "1 late cast")
    local feign = storedRun(NS, "f", 2, 100, late({ 1.4, FEIGN }))
    assertEqual(#NS.HudStates.FlagChips(feign), 0)
    assertTrue(NS.LateIgnore.Unignore(FEIGN))
    assertEqual(NS.HudStates.FlagChips(feign)[1].text, "1 late cast", "read time: the old run is re-scored")
    assertEqual(NS.Share.ResultLine(mixed):match("2 late casts") ~= nil, true)
end)

test("late ignore: the Results detail draws an ignored cast's tick gray and explains only the counted ones", function()
    local NS = fresh()
    local r = storedRun(NS, "m", 1, 100, late({ 1.4, FEIGN }, { 2.0, INCINERATE }))
    local m = NS.ResultsDetail.Timing(r)
    assertEqual(#m.late, 2, "every late cast keeps its tick")
    assertTrue(m.lateIgnored[1])
    assertFalse(m.lateIgnored[2])
    assertTrue(NS.ResultsDetail.Place(m, 300).lateIgnored[1])
    local lines = NS.ResultsDetail.FlagLines(r)
    assertEqual(lines[1].main, "1 late cast")
    assertTrue(lines[1].text:find("Incinerate", 1, true) ~= nil, lines[1].text)
    assertNil(lines[1].text:find("Feign Death", 1, true), lines[1].text)
    assertEqual(NS.ResultsTable.ShortFlags(r), "1 late")
end)

test("late ignore: a list change redraws the HUD and drops the cached boards and the sample's", function()
    local NS = fresh()
    storedRun(NS, "f", 1, 900, late({ 1.4, FEIGN }))
    storedRun(NS, "c", 2, 500)
    NS.Bests.Invalidate()
    assertEqual(NS.Bests.Board({ cleanOnly = true })["253|boss|30"].id, "f", "Feign Death is ignored by default")
    assertTrue(NS.LateIgnore.Unignore(FEIGN))
    assertEqual(NS.Bests.Board({ cleanOnly = true })["253|boss|30"].id, "c", "SETTINGS_CHANGED dropped the cache")
    -- The sample history's boards, while test mode's source is in place.
    local runs = { storedRun(NS, "s1", 3, 900, late({ 1.4, VANISH })), storedRun(NS, "s2", 4, 500) }
    NS.ResultsSource.Use({ runs = runs })
    assertEqual(NS.ResultsSource.Board({ cleanOnly = true })["253|boss|30"].id, "s1")
    assertTrue(NS.LateIgnore.Unignore(VANISH))
    assertEqual(NS.ResultsSource.Board({ cleanOnly = true })["253|boss|30"].id, "s2")
    NS.ResultsSource.Restore()
end)

test("late ignore: a profile switch re-scores the flags by the other profile's list and drops the clean board", function()
    local NS = fresh()
    storedRun(NS, "f", 1, 900, late({ 1.4, FEIGN }))
    storedRun(NS, "c", 2, 500)
    NS.Bests.Invalidate()
    local f = NS.db.global.runs.f
    assertFalse(NS.ResultsRuns.IsFlagged(f))
    assertEqual(NS.Bests.Board({ cleanOnly = true })["253|boss|30"].id, "f")
    NS.db:SetProfile("Other")
    assertTrue(NS.SetByPath(NS.LateIgnore.PATH, ""))
    assertTrue(NS.ResultsRuns.IsFlagged(f), "the other profile ignores nothing")
    NS.db:SetProfile("Default")
    assertFalse(NS.ResultsRuns.IsFlagged(f))
    NS.db:SetProfile("Other")
    assertTrue(NS.ResultsRuns.IsFlagged(f))
    assertEqual(NS.Bests.Board({ cleanOnly = true })["253|boss|30"].id, "c", "the switch dropped the cached board")
end)
