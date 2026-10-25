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

--- One font block, resolved: its path, size, flags, shadow and color.
--- @param block string  "elapsed" | "left" | "figures" | "spellText"
--- @return table { path, size, flags, shadow, r, g, b, a }
function Appearance.Font(block)
    return Appearance.FontAt("appearance." .. block .. ".", D[block])
end

--- A font block stored at `p` (its prefix, with the dot), `def` its defaults; `class` as color's.
function Appearance.FontAt(p, def, class)
    local name = setting(p .. "font")
    local path = fetch("font", name) or fetch("font", def.font)
    if not path and def.font == "JetBrains Mono" then path = NS.Constants and NS.Constants.FONT_MONO end
    local r, g, b, a = color(setting(p .. "fontColor"), setting(p .. "useClassColorFont") == true, class)
    local flags = setting(p .. "fontFlags")
    return {
        path = path or FALLBACK_FONT,
        size = tonumber(setting(p .. "fontSize")) or def.fontSize,
        flags = type(flags) == "string" and flags or "",
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
        texture = fetch("statusbar", setting(p .. "barTexture")) or FALLBACK_BAR,
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
