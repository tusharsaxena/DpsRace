local addonName, NS = ...
-- core/Constants.lua — fixed values resolved at load: the monospace face and the logo paths.

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
