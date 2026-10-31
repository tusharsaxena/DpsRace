-- tests/test_glyphs.lua — the display-glyph guard over this addon's own Lua (LibKa0s v1.82.0, kit
-- revision 45's tests/_kit/glyphs.lua; DR-07 of Ka0sAddonsCommonTasks
-- docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-19).
--
-- Nine skins draw this addon's text in a dozen faces, and a character one of them lacks is a box in
-- that skin only. So every string literal in a tracked .lua file outside libs/ and tests/ carries only
-- characters every shipped face draws (the kit's safe set, read from their cmaps). A string drawn in
-- the mono role carries a `glyph: mono` marker; a string that is data and never drawn carries a
-- `glyph: data` marker with its reason.

local T = _G.DPSRACE_TEST
local test = T.test

test("glyphs: display strings use only characters every shipped skin face draws", function()
  -- red under: a ≈, →, ▼ or ▲ (or any other character outside the kit's safe set) in a string the
  -- addon paints in a skin face.
  T.assertDisplayGlyphs{ label = "DpsRace" }
end)
