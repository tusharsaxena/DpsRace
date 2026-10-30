-- tests/test_skin_hud.lua — the HUD's player-styled faces and textures follow the skin (DR-03;
-- skinning-§6, the owner's ruling O2, the run's X3/X4 and DpsRace D-15/D-16).
--
-- What this pins:
--   - every HUD and Results table face and texture but the two clocks' has its "Use the skin's ..."
--     companion, default on, as a schema row beside its picker, the picker governed by it;
--   - while a companion is on the block draws the skin's `hud.font` / `bar.texture` through the
--     facade, and the stored pick comes back when it is off; the stored pick is never rewritten;
--   - while Ignore fonts is on a face block draws its stored pick even with its companion on, and
--     says it is not the skin's; the textures still follow (LibKa0s v1.81.0, R-1);
--   - a skin switch restyles the blocks (Appearance.stamp) and moves the face, never a color;
--   - the v6 step puts every stored companion back on, once, keeps the picks and the colors, never
--     writes the "@skin" sentinel, and a player's later pick survives the next login.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local FOLLOWING = {
    ["appearance.figures.fontFromSkin"] = "font",
    ["appearance.spellText.fontFromSkin"] = "font",
    ["appearance.bars.barTextureFromSkin"] = "barTexture",
    ["appearance.chart.barTextureFromSkin"] = "barTexture",
    ["appearance.pace.barTextureFromSkin"] = "barTexture",
    ["resultsTable.damageBar.barTextureFromSkin"] = "barTexture",
    ["resultsTable.dpsBar.barTextureFromSkin"] = "barTexture",
    ["resultsTable.barText.fontFromSkin"] = "font",
}
local TOKEN = { font = "hud.font", barTexture = "bar.texture" }

local function rowAt(NS, path)
    for _, r in ipairs(NS.Schema) do if r.path == path then return r end end
end

local function prefixOf(path) return (path:match("^(.+%.)[^.]+$")) end

--- A skin whose `token` differs from Ka0s Default's.
local function otherSkin(Skin, token)
    local base = Skin:ResolveSkin("ka0s")[token]
    for _, def in ipairs(Skin:Skins()) do
        local v = Skin:ResolveSkin(def.key)[token]
        if def.key ~= "ka0s" and type(v) == "string" and v ~= base then return def.key, v end
    end
end

-- ── the rows and the defaults ───────────────────────────────────────────────────────────────────

test("skin hud: the defaults list every companion, on, and the full-path list matches them", function()
    local NS = T.NS
    local A = NS.HudAppearance
    local seen = 0
    for _, path in ipairs(A.FROM_SKIN_KEYS) do
        assertTrue(FOLLOWING[path] ~= nil, "an unexpected companion: " .. path)
        seen = seen + 1
    end
    for path in pairs(FOLLOWING) do
        local t = NS.defaults.profile
        for part in path:gmatch("[^.]+") do t = t[part] end
        assertEqual(t, true, path .. " defaults on (X3)")
    end
    local n = 0
    for _ in pairs(FOLLOWING) do n = n + 1 end
    assertEqual(seen, n)
end)

test("skin hud: the clocks keep their monospace face, with no companion (D-15)", function()
    local NS = T.NS
    for _, block in ipairs({ "elapsed", "left" }) do
        assertEqual(NS.defaults.profile.appearance[block].fontFromSkin, nil, block .. " default")
        assertEqual(rowAt(NS, "appearance." .. block .. ".fontFromSkin"), nil, block .. " row")
        assertEqual(rowAt(NS, "appearance." .. block .. ".font").disabledIf, nil, block .. " picker free")
    end
end)

test("skin hud: each companion is a bool row, default on, governing its picker", function()
    local NS = T.NS
    for path, leaf in pairs(FOLLOWING) do
        local r = rowAt(NS, path)
        assertTrue(r ~= nil, "no row: " .. path)
        assertEqual(r.type, "bool", path)
        assertEqual(r.default, true, path .. " default")
        assertEqual(type(r.onChange), "function", path .. " restyles")
        local picker = rowAt(NS, prefixOf(path) .. leaf)
        assertEqual(picker.disabledIf, path, path .. " governs its picker")
    end
end)

-- ── the resolution ──────────────────────────────────────────────────────────────────────────────

test("skin hud: a companion on draws the skin's face or texture, off the stored pick, never rewritten", function()
    local NS = T.load().NS
    local A = NS.HudAppearance
    for path, leaf in pairs(FOLLOWING) do
        local p = prefixOf(path)
        local stored = NS.GetSetting(p .. leaf)
        local name, on = A.MediaKey(p, leaf)
        assertEqual(name, NS.Skin.Token(TOKEN[leaf]), path .. ": the skin's")
        assertTrue(on, path .. " says it is the skin's")
        assertTrue(NS.SetByPath(path, false))
        name, on = A.MediaKey(p, leaf)
        assertEqual(name, stored, path .. ": the stored pick")
        assertFalse(on, path)
        assertEqual(NS.GetSetting(p .. leaf), stored, path .. ": the pick is never rewritten")
    end
end)

test("skin hud: Ignore fonts gives each face block its stored face, the textures still the skin's (R-1)", function()
    -- LibKa0s v1.81.0 (LK-01): while the owner ignores fonts, Resolve answers the stored face for
    -- hud.font whatever the companion says. red under: MediaKey answering the skin's face, or saying
    -- it is the skin's, while Ignore fonts is on; or the texture half dropping the skin with it.
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    local A = NS.HudAppearance
    local LSM = M.LibStub("LibSharedMedia-3.0")
    local stamp = A.stamp
    local skinFace = LSM:Fetch("font", NS.Skin.Token("hud.font"))
    assertTrue(NS.SetByPath("skin.ignoreFonts", true))
    assertTrue(A.stamp ~= stamp, "the toggle restyles the HUD live")
    for path, leaf in pairs(FOLLOWING) do
        local p = prefixOf(path)
        assertEqual(NS.GetSetting(path), true, path .. ": the companion stays on")
        local name, on = A.MediaKey(p, leaf)
        if leaf == "font" then
            assertEqual(name, NS.GetSetting(p .. leaf), path .. ": the stored face")
            assertFalse(on, path .. " says it is not the skin's")
        else
            assertEqual(name, NS.Skin.Token(TOKEN[leaf]), path .. ": the skin's texture still")
            assertTrue(on, path .. " says it is the skin's")
        end
    end
    -- Friz Quadrata by default: the mock LSM does not register it, so the shipped fallback path.
    local own = LSM:Fetch("font", NS.GetSetting("appearance.figures.font"), true) or "Fonts\\FRIZQT__.TTF"
    assertEqual(A.Font("figures").path, own, "the figures draw their own Font")
    assertTrue(own ~= skinFace, "and not the skin's face")
    assertEqual(A.Bar().texture, LSM:Fetch("statusbar", NS.Skin.Token("bar.texture")))
    -- Off again, the skin's face comes back.
    assertTrue(NS.SetByPath("skin.ignoreFonts", false))
    assertEqual((A.MediaKey("appearance.figures.", "font")), NS.Skin.Token("hud.font"))
end)

test("skin hud: under Ka0s Default the blocks draw Prototype and the Ka0s Default bar through LSM", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    local A = NS.HudAppearance
    local LSM = M.LibStub("LibSharedMedia-3.0")
    -- The HUD faces this addon's blocks follow (LibKa0s v1.82.0, D-02): Ka0s Default's Prototype,
    -- Obsidian's Expressway, WoW Forever's Fira Sans SemiBold (its body is Fira Sans Medium).
    assertEqual(NS.Skin.Token("hud.font"), "Ka0s Prototype")
    local Skin = M.LibStub("LibKa0s-Skin-1.0")
    assertEqual(Skin:ResolveSkin("obsidian")["hud.font"], "Ka0s Expressway")
    assertEqual(Skin:ResolveSkin("forever")["hud.font"], "Ka0s Fira Sans SemiBold")
    assertEqual(Skin:ResolveSkin("forever")["font.body"], "Ka0s Fira Sans Medium")
    local face = LSM:Fetch("font", NS.Skin.Token("hud.font"))
    local bar = LSM:Fetch("statusbar", NS.Skin.Token("bar.texture"))
    assertTrue(face ~= nil and bar ~= nil, "the library registers the skin's media")
    assertEqual(A.Font("figures").path, face)
    assertEqual(A.Font("spellText").path, face)
    assertEqual(A.Bar().texture, bar)
    assertEqual(A.Chart().texture, bar)
    assertEqual(A.Pace().texture, bar)
    -- The clocks stay on their own face.
    assertEqual(A.Font("elapsed").path, LSM:Fetch("font", "JetBrains Mono") or NS.Constants.FONT_MONO)
    -- Off, the stored pick: Solid is the shipped flat texture.
    assertTrue(NS.SetByPath("appearance.bars.barTextureFromSkin", false))
    assertEqual(A.Bar().texture, LSM:Fetch("statusbar", "Solid") or "Interface\\Buttons\\WHITE8x8")
end)

test("skin hud: the Results table's bar cells and their text follow the skin too (D-16)", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    local LSM = M.LibStub("LibSharedMedia-3.0")
    local style = NS.ResultsRuns.BarStyle("damageBar", { char = { class = "MAGE" } })
    assertEqual(style.texture, LSM:Fetch("statusbar", NS.Skin.Token("bar.texture")))
    assertEqual(style.font.path, LSM:Fetch("font", NS.Skin.Token("hud.font")))
end)

test("skin hud: a skin switch restyles the blocks and moves the face, never a color (X4)", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    local Skin = M.LibStub("LibKa0s-Skin-1.0")
    local key, face = otherSkin(Skin, "hud.font")
    if not key then key, face = otherSkin(Skin, "bar.texture") end
    assertTrue(key ~= nil, "no shipped skin moves hud.font or bar.texture")
    local A = NS.HudAppearance
    local before = A.Font("figures")
    local stamp = A.stamp
    NS.ApplySkinChoice("ka0s", key)
    M.__fireTimers()
    assertTrue(A.stamp > stamp, "the switch restyles the blocks")
    local name = A.MediaKey("appearance.figures.", "font")
    local tex = A.MediaKey("appearance.bars.", "barTexture")
    assertTrue(name == face or tex == face, "the blocks read the new skin's media")
    local after = A.Font("figures")
    assertEqual(("%.3f %.3f %.3f %.3f"):format(after.r, after.g, after.b, after.a),
        ("%.3f %.3f %.3f %.3f"):format(before.r, before.g, before.b, before.a), "the player's color holds")
    -- The stored size holds; the drawn one is the new skin's HUD scale of it (LibKa0s v1.82.0, D-09).
    assertEqual(NS.GetSetting("appearance.figures.fontSize"), before.size, "the player's size holds")
    assertEqual(after.size, NS.Skin.HudFontSize(before.size, true), "drawn at the skin's HUD scale")
end)

-- ── the one-time reset (O2) ─────────────────────────────────────────────────────────────────────

--- An instance over a v5 store with `profiles`, initialized and migrated.
local function migrated(profiles)
    local inst = T.load({ init = false })
    _G.DpsRaceDB = { global = { schemaVersion = 5, schema = 4 }, profiles = profiles }
    inst.mocks._G.DpsRaceDB = _G.DpsRaceDB
    inst.NS:InitDB()
    inst.NS:RunMigrations()
    return inst
end

test("skin hud: the v6 step puts every stored companion back on, keeping the picks and the colors", function()
    local off = {
        appearance = {
            figures = { font = "Arial Narrow", fontFromSkin = false, fontColor = { r = 0.1, g = 0.2, b = 0.3, a = 1 } },
            bars = { barTexture = "Blizzard", barTextureFromSkin = false, barAlpha = 0.5 },
            elapsed = { font = "Arial Narrow" },
        },
        resultsTable = { barText = { fontFromSkin = false }, dpsBar = { barTexture = "Blizzard" } },
    }
    local bare = {}
    local inst = migrated({ Old = off, Bare = bare })
    -- The store migrates on to the current version (v7, the font flags, follows; test_skin_fonts).
    assertEqual(inst.NS.db.global.schemaVersion, inst.NS.SCHEMA_VERSION)
    local a = off.appearance
    assertEqual(a.figures.fontFromSkin, true)
    assertEqual(a.bars.barTextureFromSkin, true)
    assertEqual(off.resultsTable.barText.fontFromSkin, true)
    assertEqual(a.figures.font, "Arial Narrow", "the stored face kept")
    assertEqual(a.bars.barTexture, "Blizzard", "the stored texture kept")
    assertEqual(a.figures.fontColor.b, 0.3, "the color untouched (X4)")
    assertEqual(a.bars.barAlpha, 0.5, "the alpha untouched")
    assertEqual(a.elapsed.font, "Arial Narrow", "the clock untouched (D-15)")
    assertEqual(a.elapsed.fontFromSkin, nil, "no clock companion written")
    assertEqual(off.resultsTable.dpsBar.barTexture, "Blizzard", "no sentinel in a pick")
    assertEqual(off.resultsTable.dpsBar.barTextureFromSkin, nil, "an absent companion stays absent: its default is on")
    assertEqual(next(bare), nil, "an empty profile untouched")
end)

test("skin hud: the reset runs once, and a player's later pick is kept", function()
    local p = { appearance = { spellText = { fontFromSkin = false } } }
    local inst = migrated({ Default = p })
    local NS = inst.NS
    assertEqual(p.appearance.spellText.fontFromSkin, true, "the reset ran")
    -- The player turns it off again; the next login's migration pass must not undo it.
    p.appearance.spellText.fontFromSkin = false
    NS:RunMigrations()
    assertEqual(p.appearance.spellText.fontFromSkin, false, "the reset ran twice")
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)
