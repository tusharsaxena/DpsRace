-- tests/test_skin_fonts.lua — the font settings' minimum set and the HUD size scale (LibKa0s v1.82.0;
-- DR-01 of Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, rulings D-07 and D-09).
--
-- What this pins:
--   - every font block (the two clocks, the live figures, the spell text, the Results table's bar
--     text) is the composer's FontGroup with `flagsFromSkin`: its Font flags row leads with
--     *From skin* ("@skin") and defaults to it, beside size, color with its class-color companion and
--     shadow (D-07's minimum set);
--   - From skin draws through S.FontFlags, so it follows the Skin tab's Font outline (all and HUD:
--     OUTLINE; off: none) and answers OUTLINE while Ignore fonts is on; a flag the player picked wins;
--   - the v7 step moves a stored flag equal to the old default ("") onto From skin, once per profile,
--     and leaves a flag the player changed (Addendum 01);
--   - a block drawing the skin's HUD face draws its size through S.HudFontSize (scaled by the skin's
--     HUD size over Ka0s Default's), its own face or Ignore fonts the stored size, and the stored value
--     is never rewritten (D-09).

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local FROM_SKIN = "@skin"
local BLOCKS = {
    "appearance.elapsed.", "appearance.left.", "appearance.figures.", "appearance.spellText.",
    "resultsTable.barText.",
}

local function rowAt(NS, path)
    for _, r in ipairs(NS.Schema) do if r.path == path then return r end end
end

local function defaultAt(NS, path)
    local t = NS.defaults.profile
    for part in path:gmatch("[^.]+") do t = type(t) == "table" and t[part] or nil end
    return t
end

--- The resolved font of the block at prefix `p`.
local function fontOf(NS, p)
    local A = NS.HudAppearance
    local block = p:match("^appearance%.(.-)%.$")
    if block then return A.Font(block) end
    return A.FontAt(p, NS.defaults.profile.resultsTable.barText)
end

-- ── the minimum set (D-07) ──────────────────────────────────────────────────────────────────────

test("skin fonts: every font block carries size, color, class color, flags and shadow", function()
    local NS = T.NS
    for _, p in ipairs(BLOCKS) do
        for _, leaf in ipairs({ "fontSize", "fontColor", "useClassColorFont", "fontFlags", "fontShadow" }) do
            assertTrue(rowAt(NS, p .. leaf) ~= nil, p .. leaf .. " is a row")
        end
    end
end)

test("skin fonts: every Font flags row leads with From skin and defaults to it", function()
    -- red under: a FontGroup without flagsFromSkin (the row offers no From skin), or a profile
    -- default still "" (a new profile would draw no outline whatever the Skin tab says).
    local NS = T.NS
    for _, p in ipairs(BLOCKS) do
        local r = rowAt(NS, p .. "fontFlags")
        assertEqual(r.default, FROM_SKIN, p .. "fontFlags row default")
        assertEqual(defaultAt(NS, p .. "fontFlags"), FROM_SKIN, p .. "fontFlags profile default")
        assertEqual(r.sorting and r.sorting[1], FROM_SKIN, p .. "fontFlags: From skin first")
        assertEqual(r.values[FROM_SKIN], "From skin", p .. "fontFlags: the label")
    end
end)

-- ── From skin through the Font outline ──────────────────────────────────────────────────────────

test("skin fonts: From skin follows the Font outline; a picked flag wins", function()
    local NS = T.load().NS
    for _, p in ipairs(BLOCKS) do
        assertEqual(fontOf(NS, p).flags, "OUTLINE", p .. " all text: outlined")
    end
    assertTrue(NS.SetByPath("skin.outline", "hud"))
    for _, p in ipairs(BLOCKS) do
        assertEqual(fontOf(NS, p).flags, "OUTLINE", p .. " HUD text only: still outlined (HUD text)")
    end
    assertTrue(NS.SetByPath("skin.outline", "off"))
    for _, p in ipairs(BLOCKS) do
        assertEqual(fontOf(NS, p).flags, "", p .. " off: no outline")
    end
    assertTrue(NS.SetByPath("appearance.figures.fontFlags", "THICKOUTLINE"))
    assertEqual(fontOf(NS, "appearance.figures.").flags, "THICKOUTLINE", "a picked flag wins over Off")
    assertTrue(NS.SetByPath("appearance.spellText.fontFlags", ""))
    assertTrue(NS.SetByPath("skin.outline", "all"))
    assertEqual(fontOf(NS, "appearance.spellText.").flags, "", "a picked None stays None under All text")
end)

test("skin fonts: while Ignore fonts is on, From skin draws the outline", function()
    local NS = T.load().NS
    assertTrue(NS.SetByPath("skin.outline", "off"))
    assertTrue(NS.SetByPath("skin.ignoreFonts", true))
    assertEqual(fontOf(NS, "appearance.figures.").flags, "OUTLINE")
end)

test("skin fonts: the drawn FontString takes the resolved flags", function()
    local NS = T.load().NS
    local A = NS.HudAppearance
    local got
    local fs = { SetFont = function(_, _, _, flags) got = flags return true end, SetTextColor = function() end }
    A.ApplyFont(fs, A.Font("figures"))
    assertEqual(got, "OUTLINE")
end)

test("skin fonts: without the library From skin draws the outline", function()
    local NS = T.load({ libFiles = {} }).NS
    assertEqual(NS.HudAppearance.Font("figures").flags, "OUTLINE")
    assertEqual(NS.HudAppearance.Font("figures").size, NS.defaults.profile.appearance.figures.fontSize)
end)

-- ── the v7 step (Addendum 01) ───────────────────────────────────────────────────────────────────

local function migrated(profiles)
    local inst = T.load({ init = false })
    _G.DpsRaceDB = { global = { schemaVersion = 6, schema = 4 }, profiles = profiles }
    inst.mocks._G.DpsRaceDB = _G.DpsRaceDB
    inst.NS:InitDB()
    inst.NS:RunMigrations()
    return inst
end

test("skin fonts: the v7 step moves a stored old-default flag onto From skin, and keeps a changed one", function()
    local old = {
        appearance = {
            elapsed = { fontFlags = "" }, figures = { fontFlags = "" }, spellText = { fontFlags = "OUTLINE" },
            left = { fontSize = 30 },
        },
        resultsTable = { barText = { fontFlags = "" } },
    }
    local bare = {}
    local inst = migrated({ Old = old, Bare = bare })
    assertEqual(inst.NS.db.global.schemaVersion, 7)
    assertEqual(inst.NS.SCHEMA_VERSION, 7)
    assertEqual(old.appearance.elapsed.fontFlags, FROM_SKIN)
    assertEqual(old.appearance.figures.fontFlags, FROM_SKIN)
    assertEqual(old.resultsTable.barText.fontFlags, FROM_SKIN)
    assertEqual(old.appearance.spellText.fontFlags, "OUTLINE", "the player's own flag is kept")
    assertEqual(old.appearance.left.fontFlags, nil, "an absent flag stays absent: its default is From skin")
    assertEqual(old.appearance.left.fontSize, 30, "the rest untouched")
    assertEqual(next(bare), nil, "an empty profile untouched")
end)

test("skin fonts: the v7 step runs once, so a None picked afterwards is kept", function()
    local p = { appearance = { figures = { fontFlags = "" } } }
    local inst = migrated({ Default = p })
    assertEqual(p.appearance.figures.fontFlags, FROM_SKIN, "the step ran")
    p.appearance.figures.fontFlags = ""
    inst.NS:RunMigrations()
    assertEqual(p.appearance.figures.fontFlags, "", "the step ran twice")
end)

-- ── the HUD size scale (D-09) ───────────────────────────────────────────────────────────────────

test("skin fonts: a block on the skin's face draws the skin's HUD scale; its own face the stored size", function()
    -- red under: FontAt drawing the stored size under every skin (Obsidian's HUD text would run
    -- narrower than Ka0s Default's), or scaling a block that draws its own face.
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    local Skin = M.LibStub("LibKa0s-Skin-1.0")
    local obsidian = Skin:ResolveSkin("obsidian")["hud.fontSize"]
    local base = Skin:ResolveSkin("ka0s")["hud.fontSize"]
    assertTrue(obsidian ~= base, "Obsidian's HUD size differs from Ka0s Default's")
    assertTrue(NS.SetByPath("appearance.figures.fontSize", 12))
    assertTrue(NS.SetByPath("resultsTable.barText.fontSize", 12))
    assertEqual(NS.HudAppearance.Font("figures").size, 12, "Ka0s Default: as stored")
    NS.ApplySkinChoice("ka0s", "obsidian")
    local want = 12 * obsidian / base
    assertEqual(NS.HudAppearance.Font("figures").size, want, "Obsidian: scaled")
    assertEqual(fontOf(NS, "resultsTable.barText.").size, want, "the Results table's bar text too")
    assertEqual(NS.GetSetting("appearance.figures.fontSize"), 12, "the stored size is never rewritten")
    assertTrue(NS.SetByPath("appearance.figures.fontFromSkin", false))
    assertEqual(NS.HudAppearance.Font("figures").size, 12, "its own face: the stored size")
    assertTrue(NS.SetByPath("appearance.figures.fontFromSkin", true))
    assertTrue(NS.SetByPath("skin.ignoreFonts", true))
    assertEqual(NS.HudAppearance.Font("figures").size, 12, "Ignore fonts: the stored size")
end)

test("skin fonts: the clocks keep their stored size in every skin", function()
    local NS = T.load().NS
    NS.ApplySkinChoice("ka0s", "obsidian")
    assertEqual(NS.HudAppearance.Font("elapsed").size, NS.defaults.profile.appearance.elapsed.fontSize)
    assertEqual(NS.HudAppearance.Font("left").size, NS.defaults.profile.appearance.left.fontSize)
end)
