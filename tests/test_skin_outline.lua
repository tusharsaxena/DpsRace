-- tests/test_skin_outline.lua — the font outline (LibKa0s v1.82.0, Skin minor 9; DR-01 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-06): stored as skin.outline
-- ("all", the default, "hud", "off"), written only through the skin write seam (NS.WriteSkinChoice's
-- `media.outline`), and applied with Skin:SetOutline at load, on every profile event and on the row's
-- own write. LibKa0sSkinTester's tests/test_skin_outline.lua is the reference this follows.
--
-- Every case builds its own instance, so nothing leaks between cases.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "DpsRace"

local function setup(opts)
    local inst = T.load(opts)
    return inst.NS, inst.mocks, inst.mocks.LibStub("LibKa0s-Skin-1.0")
end

local function rowOf(NS, path)
    for _, r in ipairs(NS.Schema) do if r.path == path then return r end end
end

test("outline: a fresh profile stores All text, the library's default, and applies it", function()
    local NS, _, Skin = setup()
    assertEqual(NS.db.profile.skin.outline, "all")
    assertEqual(NS.db.profile.skin.outline, Skin.OUTLINE_DEFAULT)
    assertEqual(Skin:GetOutline(OWNER), "all")
end)

test("outline: the schema row is a skip-render Skin tab row offering the library's modes, in order", function()
    -- red under: a row the page draws on top of the library's own dropdown, or values that drift
    -- from Skin.OUTLINE_MODES (/dr set would accept a mode the library reads as "all").
    local NS, _, Skin = setup()
    local row = rowOf(NS, "skin.outline")
    assertTrue(row ~= nil, "a skin.outline row")
    assertTrue(row.skipRender == true, "the Skin tab draws it")
    assertEqual(row.group, "Appearance")
    assertEqual(row.default, "all")
    local got = {}
    for _, opt in ipairs(row.values) do got[#got + 1] = opt.value end
    assertEqual(table.concat(got, ","), table.concat(Skin.OUTLINE_MODES, ","))
end)

test("outline: the write seam stores media.outline, and leaves it alone when it is nil", function()
    -- red under: WriteSkinChoice dropping media.outline (the Skin tab's Font outline and the copy
    -- would move the look and never store it).
    local NS = setup()
    NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "hud" })
    assertEqual(NS.db.profile.skin.outline, "hud")
    NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false })
    assertEqual(NS.db.profile.skin.outline, "hud", "a media without outline leaves it")
    NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "off" })
    assertEqual(NS.db.profile.skin.outline, "off")
end)

test("outline: another addon's copy reaches the store through WriteChoice", function()
    local NS, _, Skin = setup()
    Skin:WriteChoice(OWNER, "ka0s", "ember", nil, { font = false, texture = false, outline = "off" })
    assertEqual(NS.db.profile.skin.outline, "off")
end)

test("outline: the row's write applies the mode live, and only its own half", function()
    local NS, _, Skin = setup()
    NS.Slash:OnSlash("set skin.outline hud")
    assertEqual(Skin:GetOutline(OWNER), "hud")
    assertEqual(NS.Skin.Token("font.outline"), "", "window text loses its outline")
    assertEqual(NS.Skin.Token("hud.outline"), "OUTLINE", "the HUD keeps it")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "the skin is untouched")
    NS.Slash:OnSlash("set skin.outline off")
    assertEqual(NS.Skin.Token("hud.outline"), "", "Off takes both")
    NS.Slash:OnSlash("set skin.outline all")
    assertEqual(NS.Skin.Token("font.outline"), "OUTLINE")
end)

test("outline: /dr set refuses a mode the library does not know", function()
    local NS, _, Skin = setup()
    NS.Slash:OnSlash("set skin.outline thick")
    assertEqual(NS.db.profile.skin.outline, "all")
    assertEqual(Skin:GetOutline(OWNER), "all")
end)

test("outline: the stored mode is applied at login", function()
    -- red under: ApplySkinChoice's whole-pair path not applying the stored outline.
    local inst = T.load({ init = false })
    _G.DpsRaceDB = { profiles = { Default = { skin = { outline = "off" } } } }
    inst.mocks._G.DpsRaceDB = _G.DpsRaceDB
    inst.mocks.LibStub("AceAddon-3.0"):InitializeAddon(inst.NS)
    assertEqual(inst.mocks.LibStub("LibKa0s-Skin-1.0"):GetOutline(OWNER), "off")
end)

test("outline: a profile switch applies the incoming profile's mode, and back", function()
    local NS, _, Skin = setup()
    NS.Slash:OnSlash("set skin.outline hud")
    NS.db:SetProfile("OutlineProbe")
    assertEqual(Skin:GetOutline(OWNER), "all", "the new profile keeps the default")
    NS.db:SetProfile("Default")
    assertEqual(Skin:GetOutline(OWNER), "hud", "Default's is back")
end)

test("outline: Reset all settings puts the outline back on All text and applies it", function()
    local NS, _, Skin = setup()
    NS.Slash:OnSlash("set skin.outline off")
    NS.Helpers.RestoreAllDefaults()
    assertEqual(NS.db.profile.skin.outline, "all")
    assertEqual(Skin:GetOutline(OWNER), "all")
end)

test("outline: without the library the apply seam answers false and the default still stores", function()
    local NS = T.load({ libFiles = {} }).NS
    assertEqual(NS.ApplySkinOutline("off"), false)
    assertEqual(NS.db.profile.skin.outline, "all")
end)
