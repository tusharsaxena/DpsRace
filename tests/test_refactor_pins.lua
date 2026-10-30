-- tests/test_refactor_pins.lua — the behavior pinned under DR-08's complexity refactors (Ka0sAddons
-- CommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, Addendum 07: no function above CCN 15). Each
-- case covers a path of a split function that the module's own suite did not hold: the v6 step
-- without the skin library, the class-color resolver's class branch, Resolve's lowest-ID tie and its
-- typed-ID edges, and the `/dr targetdummy capture` line's every part. Written green on the code
-- before the split, so the split is shown to keep them.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local BOAR = 99999
local BOAR_GUID = "Creature-0-3770-2552-1234-99999-0000ABCDEF"

local function said(M)
    local out = {}
    for _, line in ipairs(M.__printed()) do out[#out + 1] = tostring(line) end
    return table.concat(out, "\n")
end

-- ── core/Database.lua: the v6 step ──────────────────────────────────────────────────────────────

test("pins: without the skin library the v6 step sets each stored companion on in place", function()
    local inst = T.load({ init = false })
    local NS = inst.NS
    local p = {
        appearance = { figures = { fontFromSkin = false }, bars = { barTextureFromSkin = true } },
        resultsTable = { barText = { fontFromSkin = false } },
    }
    _G.DpsRaceDB = { global = { schemaVersion = 5, schema = 4 }, profiles = { Default = p } }
    inst.mocks._G.DpsRaceDB = _G.DpsRaceDB
    NS:InitDB()
    -- The library's ResetToSkin taken away: the step's own fallback writes the companions.
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0", true)
    local saved = Skin and Skin.ResetToSkin
    if Skin then Skin.ResetToSkin = nil end
    local ok, err = pcall(NS.RunMigrations, NS)
    if Skin then Skin.ResetToSkin = saved end
    if not ok then error(err, 0) end
    assertEqual(p.appearance.figures.fontFromSkin, true)
    assertEqual(p.appearance.bars.barTextureFromSkin, true)
    assertEqual(p.resultsTable.barText.fontFromSkin, true)
end)

-- ── modules/Hud_Appearance.lua: the class-color resolver ────────────────────────────────────────

test("pins: Color with a class reads that class's color, else the swatch, the stored alpha held", function()
    local C = T.NS.HudAppearance.Color
    local r, g, b, a = C({ r = 0.1, g = 0.2, b = 0.3, a = 0.4 }, true, "MAGE")
    assertEqual(r, 0.25); assertEqual(g, 0.78); assertEqual(b, 0.92); assertEqual(a, 0.4)
    r, g, b, a = C({ r = 0.1, g = 0.2, b = 0.3, a = 0.4 }, false, "MAGE")
    assertEqual(r, 0.1); assertEqual(g, 0.2); assertEqual(b, 0.3); assertEqual(a, 0.4)
    r, g, b, a = C({ r = 0.1 }, true, "NOT_A_CLASS")
    assertEqual(r, 0.1); assertEqual(g, 1); assertEqual(b, 1); assertEqual(a, 1)
    r, g, b, a = C(nil, true, "WARLOCK")
    assertEqual(g, 0.53); assertEqual(b, 0.93)
    assertEqual(r, 0.53); assertEqual(a, 1, "no swatch: opaque")
    r, g, b, a = C("junk", false, "WARLOCK")
    assertEqual(r, 1); assertEqual(g, 1); assertEqual(b, 1); assertEqual(a, 1)
end)

-- ── modules/DummyList.lua: Resolve ──────────────────────────────────────────────────────────────

test("pins: Resolve answers the lowest ID a name is captured under, and refuses an ID past MAX_ID", function()
    local inst = T.load()
    local NS = inst.NS
    local DL = NS.DummyList
    NS.db.global.dummies = { captures = {
        [500] = { name = "Twin" }, [400] = { name = "twin" }, [450] = "junk", [460] = { name = 7 },
    } }
    assertEqual(DL.Resolve("TWIN"), 400)
    assertEqual(DL.Resolve(12), 12, "a number is typed text")
    assertEqual(DL.Resolve(tostring(DL.MAX_ID)), DL.MAX_ID)
    assertEqual(select(2, DL.Resolve(tostring(DL.MAX_ID + 1))), "notFound")
    assertEqual(select(2, DL.Resolve(nil)), "empty")
    assertEqual(select(2, DL.Resolve("-5")), "notFound", "a sign is no ID, and no name")
end)

-- ── settings/Slash.lua: the capture line ────────────────────────────────────────────────────────

test("pins: the capture line names each part it has, in order, and leaves out what it has not", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    M.__context.mapID, M.__context.zone, M.__context.subZone = 2393, "Silvermoon City", ""
    M.__context.mapX, M.__context.mapY = 0.5, 0.25
    M.__setTarget({ guid = BOAR_GUID, name = "Angry Boar", level = -1, classification = "normal",
                    healthMax = 2000, creatureType = "Beast", pvp = true })
    NS.Slash:OnSlash("targetdummy capture")
    local text = said(M)
    assertTrue(text:find("Angry Boar (99999) \194\183 skull level \194\183 ", 1, true) ~= nil, text)
    assertTrue(text:find(" \194\183 Beast \194\183 PvP flagged \194\183 Silvermoon City 50.0, 25.0", 1, true) ~= nil, text)
    assertNil(text:find("normal", 1, true), "a normal classification is not named")
    assertEqual(NS.db.global.dummies.captures[BOAR].count, 1)
end)
