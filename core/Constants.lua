local addonName, NS = ...
-- core/Constants.lua — fixed values resolved at load: the monospace face, the logo paths and the
-- frame-layering table.

NS.Constants = NS.Constants or {}
local C = NS.Constants

-- The debug console's face, from the shared catalog (library-stack-§8). The fallback is a REAL
-- client font, never nil: SetFont on a bad path draws nothing and raises nothing.
C.FONT_MONO = (NS.MediaFont and NS.MediaFont("JetBrains Mono")) or STANDARD_TEXT_FONT

-- The 128x128 uncompressed 32-bit logo (layout-§4): the TOC IconTexture, the minimap button and the
-- broker object's icon. Never a Blizzard icon or a file id (anti-pattern #82).
C.LOGO_128 = ("Interface\\AddOns\\%s\\media\\logos\\dpsrace.logo.128.tga"):format(addonName)

-- The settings landing page's logo: the separate, larger file in the same folder (options-ui-§5).
C.LOGO = ("Interface\\AddOns\\%s\\media\\logos\\dpsrace.logo.tga"):format(addonName)

-- THE LAYERS (frame-layering-§5). Every SetFrameStrata and SetFrameLevel in this addon reads this
-- table; no strata string and no bare level number sits at a call site. The addon's whole stack, low
-- to high, the library- and Blizzard-owned tiers it relies on included:
--
--   MEDIUM             HUD           the Race HUD (modules/Hud.lua): the addon's persistent display, a
--                                    movable window, toplevel, so a click raises it among MEDIUM peers
--   HIGH               WINDOW        the Results window (modules/Results.lua): the on-demand browser,
--                                    toplevel; Blizzard's Settings panel shares this strata, and the
--                                    last one clicked is in front
--   DIALOG             (library)     Blizzard StaticPopups (reset, delete, whisper share), the LibKa0s
--                                    debug console and perf panel (toplevel from LibKa0s v1.77.0)
--   FULLSCREEN         SCREEN_ALERT  the center-screen countdown (modules/Countdown.lua): mouse-disabled,
--                                    over every dialog, and out of the menus' strata so a menu opened
--                                    in the last ten seconds always draws over the numbers
--   FULLSCREEN_DIALOG  (library)     the LibKa0s dropdown menu (the Results filter bars)
--   TOOLTIP            (Blizzard)    GameTooltip
--
-- Levels inside a window (base W): chrome W+1 (title-bar controls, drag strip, tab buttons, body, the
-- displacing test strip), content W+2 .. W+8, the library resize grip W+10. The Results detail pane
-- is laid inside the Runs pane's rectangle in wide mode, so it is set to body + LEVEL.DETAIL (W+3) the
-- moment it is built, before its children, instead of tying the empty Runs pane (body + 1) by
-- creation order. Its deepest child then sits at W+8, still under the grip. The binding buttons and
-- the event frame draw nothing and set no layer (exempt).
C.LAYERS = {
    STRATA = { HUD = "MEDIUM", WINDOW = "HIGH", SCREEN_ALERT = "FULLSCREEN" },
    LEVEL  = { DETAIL = 2 },
}
