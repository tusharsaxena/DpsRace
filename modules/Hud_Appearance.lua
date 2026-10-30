local _, NS = ...
-- modules/Hud_Appearance.lua — the HUD's configured look (HUD > HUD Appearance, settings/Hud.lua):
-- the two running clocks, the live Damage and DPS figures, the spell rows' bars and text, which
-- the Results window's breakdown shares, the damage chart's columns and plot background, and the
-- pace bar's fill. Each block is a composed group (options-ui-§16) stored under
-- `appearance.<block>.`; this file turns a block into what a widget setter takes.
--
-- MEDIA BY NAME. A face or a bar texture is stored by its LibSharedMedia name, so a profile travels
-- between installs. It resolves at call time, and a name LSM does not know (a media addon removed)
-- falls back to the shipped default's path, never to nothing: SetFont on a bad path draws no text.
--
-- FOLLOWING THE SKIN (skinning-§6, DR-03). A face or a texture with a "Use the skin's ..." companion
-- (`<key>FromSkin`, the composer's `fromSkin`, default on: defaults/Profile.lua) draws the owner's skin
-- token while the companion is on, through the facade's S.Resolve, which is override-aware (the Skin
-- tab's own font or texture wins over the skin's): `hud.font` for a face, `bar.texture` for a bar.
-- While the Skin tab's Ignore fonts is on, the library answers no `hud.font` (LibKa0s v1.81.0, R-1),
-- so a face block draws its stored pick even with its companion on; the textures still follow. The
-- stored pick is never rewritten, so turning the companion off brings it back. Only the face and the
-- texture follow (X4): sizes, flags, shadows and colors stay the player's, with two library-read
-- exceptions (LibKa0s v1.82.0). FLAGS: a block's Font flags of *From skin* ("@skin", the default,
-- D-07) draws the Skin tab's Font outline through S.FontFlags, read as HUD text (hud.outline: every
-- block here is the HUD's style, the Results table's bar text included); a flag the player picks
-- draws as picked. SIZE: a block drawing the skin's HUD face draws its stored size through
-- S.HudFontSize (D-09), scaled by the skin's HUD size over Ka0s Default's so every skin's HUD text is
-- as wide as Ka0s Default's; a block on its own face, the clocks and Ignore fonts draw the stored
-- size. The stored size is never rewritten. Not S.BarTexture: it always
-- paints the skin's texture and replays it on a switch, which would override a player who unticked the
-- companion. A skin switch reaches every block through Style's one OnLooksChanged listener, which calls
-- Changed() below (modules/Style.lua). The two clocks have no companion (D-15): they stay monospace.
--
-- COLORS through LibKa0s-Core's one resolver (options-ui-§17): the swatch, or the player's class
-- color while the companion is on, the swatch's alpha kept either way. Every surface here is the
-- player's own, so the class is always the player's.
--
-- RESTYLING IS STAMPED. Changed() bumps Appearance.stamp; a row or a body compares its own stamp and
-- restyles once, not on every 4 Hz redraw. Nothing here reads a meter value or a frame's geometry.

local Appearance = {}
NS.HudAppearance = Appearance

local D = NS.defaults.profile.appearance

-- The faces and textures that stand in for a name LSM cannot answer.
local FALLBACK_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local FALLBACK_BAR = "Interface\\Buttons\\WHITE8x8"

Appearance.stamp = 0

-- The composer's *From skin* value for Font flags (LibKa0s-Skin-1.0's FROM_SKIN).
local FROM_SKIN = "@skin"

-- Each media leaf that can follow the skin: the skin token it follows. The companion is the leaf plus
-- `FromSkin`, stored beside it (OptionsCompose's naming).
local FOLLOWS = { font = "hud.font", barTexture = "bar.texture" }

--- Every font block's Font flags, by full path: the v7 step's list (core/Database.lua).
Appearance.FONT_FLAGS_KEYS = {
    "appearance.elapsed.fontFlags",
    "appearance.left.fontFlags",
    "appearance.figures.fontFlags",
    "appearance.spellText.fontFlags",
    "resultsTable.barText.fontFlags",
}

--- Every stored companion, by full path: the v6 reset's list (core/Database.lua). The clocks
--- (`appearance.elapsed`, `appearance.left`) are absent by design (D-15).
Appearance.FROM_SKIN_KEYS = {
    "appearance.figures.fontFromSkin",
    "appearance.spellText.fontFromSkin",
    "appearance.bars.barTextureFromSkin",
    "appearance.chart.barTextureFromSkin",
    "appearance.pace.barTextureFromSkin",
    "resultsTable.damageBar.barTextureFromSkin",
    "resultsTable.dpsBar.barTextureFromSkin",
    "resultsTable.barText.fontFromSkin",
}

local function setting(path)
    return NS.GetSetting and NS.GetSetting(path)
end

local function lsm()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- The path LSM holds for `name`, else nil.
local function fetch(kind, name)
    local media = lsm()
    if not media or type(name) ~= "string" then return nil end
    local ok, path = pcall(media.Fetch, media, kind, name, true)
    if ok and type(path) == "string" then return path end
    return nil
end

-- A swatch through its class-color companion. With `class` (a class token: a stored run's character)
-- the class is that one, the surface describing that character; without it, the player's, through
-- LibKa0s-Core's resolver. An unresolvable class falls through to the swatch; its alpha always holds.
local function color(stored, useClass, class)
    local core = LibStub and LibStub("LibKa0s-Core-1.0", true)
    if class ~= nil then
        local s = type(stored) == "table" and stored or {}
        local a = s.a or 1
        local c = useClass and type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[class]
        if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b, a end
        return s.r or 1, s.g or 1, s.b or 1, a
    end
    if core and core.ResolveColor then return core.ResolveColor(stored, useClass) end
    stored = type(stored) == "table" and stored or {}
    return stored.r or 1, stored.g or 1, stored.b or 1, stored.a or 1
end
Appearance.Color = color

--- The LSM name the block at `p` draws for media `leaf` ("font" | "barTexture"), and true when it is
--- the skin's: its companion is on and the skin answered. Otherwise the stored pick, false. The
--- skin is asked with no stored value, so its answer is the skin's or nothing: while the owner
--- ignores fonts the library answers nil for `hud.font` (LibKa0s v1.81.0, R-1), and a face block
--- draws its stored pick (a stray "@skin" sentinel in it names no face, so FontAt falls back to the
--- block's default). A token the skin leaves unset reads the same way.
--- @param p string  the block's prefix, with the dot
--- @param leaf string
--- @return string|nil, boolean
function Appearance.MediaKey(p, leaf)
    local stored = setting(p .. leaf)
    local token, S = FOLLOWS[leaf], NS.Skin
    if token and S and type(S.Resolve) == "function"
        and (setting(p .. leaf .. "FromSkin") == true or (stored ~= nil and stored == S.FROM_SKIN)) then
        local v = S.Resolve(token, nil, true)
        if type(v) == "string" and v ~= "" then return v, true end
    end
    return stored, false
end

--- One font block, resolved: its path, size, flags, shadow and color.
--- @param block string  "elapsed" | "left" | "figures" | "spellText"
--- @return table { path, size, flags, shadow, r, g, b, a }
function Appearance.Font(block)
    return Appearance.FontAt("appearance." .. block .. ".", D[block])
end

--- A font block stored at `p` (its prefix, with the dot), `def` its defaults; `class` as color's.
function Appearance.FontAt(p, def, class)
    local name, fromSkin = Appearance.MediaKey(p, "font")
    local path = fetch("font", name) or fetch("font", setting(p .. "font")) or fetch("font", def.font)
    if not path and def.font == "JetBrains Mono" then path = NS.Constants and NS.Constants.FONT_MONO end
    local r, g, b, a = color(setting(p .. "fontColor"), setting(p .. "useClassColorFont") == true, class)
    local S = NS.Skin
    local size = tonumber(setting(p .. "fontSize")) or def.fontSize
    if S and type(S.HudFontSize) == "function" then size = S.HudFontSize(size, fromSkin) end
    local flags = setting(p .. "fontFlags")
    if S and type(S.FontFlags) == "function" then
        flags = S.FontFlags(flags)
    elseif type(flags) ~= "string" or flags == FROM_SKIN then
        flags = "OUTLINE"
    end
    return {
        path = path or FALLBACK_FONT,
        size = size,
        flags = flags,
        shadow = setting(p .. "fontShadow") == true,
        r = r, g = g, b = b, a = a,
    }
end

--- Draw `fs` in a resolved font block. `scale` multiplies its size (a clock shown alone); `keepColor`
--- leaves the FontString's color as its caller set it.
--- @param fs table  a FontString
--- @param font table  Appearance.Font's
--- @param scale number|nil
--- @param keepColor boolean|nil
function Appearance.ApplyFont(fs, font, scale, keepColor)
    local size = math.floor(font.size * (scale or 1) + 0.5)
    -- The client answers false for a path it cannot load (an older one answers nothing at all).
    if fs:SetFont(font.path, size, font.flags) == false then fs:SetFont(FALLBACK_FONT, size, font.flags) end
    if fs.SetShadowOffset then
        fs:SetShadowOffset(font.shadow and 1 or 0, font.shadow and -1 or 0)
        if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, font.shadow and 1 or 0) end
    end
    if not keepColor then fs:SetTextColor(font.r, font.g, font.b, font.a) end
end

--- The spell bars' fill: its texture path, color and opacity.
--- @return table { texture, r, g, b, a }
function Appearance.Bar()
    return Appearance.BarAt("appearance.bars.", D.bars)
end

--- A bar block stored at `p`, `def` its defaults; `class` as color's.
function Appearance.BarAt(p, def, class)
    local r, g, b = color(setting(p .. "barColor"), setting(p .. "useClassColorBar") == true, class)
    local alpha = tonumber(setting(p .. "barAlpha")) or def.barAlpha
    return {
        texture = fetch("statusbar", Appearance.MediaKey(p, "barTexture"))
            or fetch("statusbar", setting(p .. "barTexture")) or FALLBACK_BAR,
        r = r, g = g, b = b, a = alpha,
    }
end

--- The damage chart's columns (HUD Appearance > Damage chart).
--- @return table { texture, r, g, b, a }
function Appearance.Chart()
    return Appearance.BarAt("appearance.chart.", D.chart)
end

--- The damage chart plot's background (HUD Appearance > Chart background): the swatch, or the
--- player's class color while its companion is on, the swatch's alpha kept either way.
--- @return table { r, g, b, a }
function Appearance.ChartBackground()
    local r, g, b, a = color(setting("appearance.chart.bgColor") or D.chart.bgColor,
        setting("appearance.chart.useClassColorBg") == true)
    return { r = r, g = g, b = b, a = a }
end

--- The pace bar's fill (HUD Appearance > Pace bar), its own block since 2026-10-25: styling the
--- chart's columns no longer restyles it.
--- @return table { texture, r, g, b, a }
function Appearance.Pace()
    return Appearance.BarAt("appearance.pace.", D.pace)
end

--- The spell rows' height in pixels (the breakdown's pitch adds its gap).
--- @return number
function Appearance.RowHeight()
    return tonumber(setting("appearance.bars.rowHeight")) or D.bars.rowHeight
end

--- A HUD Appearance row changed: every styled surface restyles on its next draw, and both windows
--- redraw now.
function Appearance.Changed()
    Appearance.stamp = Appearance.stamp + 1
    if NS.Hud and NS.Hud.Refresh then NS.Hud.Refresh() end
    if NS.Results and NS.Results.Refresh then NS.Results.Refresh() end
end
