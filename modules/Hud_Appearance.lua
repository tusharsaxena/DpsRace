local _, NS = ...
-- modules/Hud_Appearance.lua — the HUD's configured look (HUD > HUD Appearance, settings/Hud.lua):
-- the two running clocks, the live Damage and DPS figures, the spell rows' bars and text, which
-- the Results window's breakdown shares, the damage chart's columns and plot background, and the
-- pace bar's fill. Each block is a composed group (options-ui-§16) stored under
-- `appearance.<block>.`; this file turns a block into what a widget setter takes.
--
-- A STYLED BAR (Appearance.Styled, 2026-10-31) is a bar block with a background and a border: the
-- spell rows, the pace bar, the Results table's cells and the compare's columns. Both span the bar's
-- whole length, under and over the fill. The background is its swatch, or the surface's skin track
-- while `bgFromSkin` is on (read here, so a skin switch moves it); the border is the composed border
-- group, its style and thickness following the skin's bar.borderStyle and bar.borderSize while its
-- companion is on, its color bar.border while `borderColorFromSkin` is. A class color comes before
-- both. A border that says None, or has no thickness, draws nothing.
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
-- texture have a composer companion. COLOR AND SHADOW (LibKa0s v1.85.0, FS-DR-FLIP, the owner's rulings
-- of 2026-11-01): a text block's `fontColorFromSkin` draws hud.text (the live figures their own
-- dr.figures.text, which follows it), and every block's `fontShadowFromSkin` the skin's shadow, the
-- stored swatch and shadow waiting for the companion to go off. The clocks' colors mean something and
-- have no companion; the bar fills are the owner's call (cause A9). SIZE AND FLAGS are stored, with two
-- library reads (LibKa0s v1.82.0). FLAGS: a block's Font flags of *From skin* ("@skin", the default,
-- D-07) draws the Skin tab's Font outline through S.FontFlags: as HUD text (hud.outline) on the HUD,
-- as window text (font.outline, `where` "window") in the Results window, which draws the Runs list's
-- bar text and the detail's spell rows, so *HUD text only* drops their outline (D-06). The two
-- clocks are the mono role, which the Font outline never outlines (D-06, critic C4): their From skin
-- draws no outline. A flag the player picks draws as picked. SIZE: a block drawing the skin's HUD face draws its stored size through
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

-- The surface's skin track behind `bgFromSkin`, by block prefix (default: the spell rows').
local PACE_PREFIX = "appearance.pace."
local TRACK_TOKEN, PACE_TRACK_TOKEN = "dr.list.track", "dr.chart.grid"

-- The Results detail's spell rows' block, and the leaves a skin's flat edge is called.
local DETAIL_PREFIX = "resultsDetail.spellBars."
local FLAT_EDGE = { flat = true, Solid = true }

Appearance.stamp = 0

-- The composer's *From skin* value for Font flags (LibKa0s-Skin-1.0's FROM_SKIN).
local FROM_SKIN = "@skin"

-- Each media leaf that can follow the skin: the skin token it follows. The companion is the leaf plus
-- `FromSkin`, stored beside it (OptionsCompose's naming).
local FOLLOWS = { font = "hud.font", barTexture = "bar.texture", borderStyle = "bar.borderStyle" }

--- Every font block's Font flags, by full path: the v7 step's list (core/Database.lua).
-- The clocks' blocks: the mono role, never outlined by the Font outline (D-06).
local MONO = { ["appearance.elapsed."] = true, ["appearance.left."] = true }

Appearance.FONT_FLAGS_KEYS = {
    "appearance.elapsed.fontFlags",
    "appearance.left.fontFlags",
    "appearance.figures.fontFlags",
    "appearance.spellText.fontFlags",
    "resultsTable.barText.fontFlags",
}

-- The block whose text follows an owner token of its own (its default differs from hud.text's).
local OWN_TEXT = { ["appearance.figures."] = "dr.figures.text" }

-- The blocks whose stored default is a shadow, where Ka0s Default's hud.shadow is none. Theirs is
-- dr.hud.shadow at the skin's offset, so Ka0s Default keeps its pixels; S.HudFont reads no owner token,
-- so each hands it as a stored shadow with the companion off. The clocks store none, and read the skin's.
local OWN_SHADOW = { ["appearance.figures."] = true, ["appearance.spellText."] = true,
                     ["resultsTable.barText."] = true }

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

-- What the one step onto the skin names (core/Database.lua, NS.FollowSkinOnce; LibKa0s Options doc,
-- Moving to, section 4), by full path from the profile's root: every companion, and the flags of the
-- three blocks whose reader is on S.FontFlags. Never a color, a pick, a size, a class toggle or the
-- `skin.ignore*` pair. Not the clocks' flags (their reader never asks the skin), the bar fills or the
-- Results table's and the compare's `bgFromSkin` (the owner's calls, cause A9).
local function fullSkinKeys()
    local keys = { "appearance.elapsed.fontShadowFromSkin", "appearance.left.fontShadowFromSkin" }
    local function add(p, ...)
        for _, leaf in ipairs({ ... }) do keys[#keys + 1] = p .. leaf end
    end
    for _, p in ipairs({ "appearance.figures.", "appearance.spellText.", "resultsTable.barText." }) do
        add(p, "fontFromSkin", "fontColorFromSkin", "fontShadowFromSkin", "fontFlags")
    end
    add("appearance.chart.", "barTextureFromSkin", "bgFromSkin")
    for _, p in ipairs({ "appearance.bars.", "appearance.pace.", "resultsDetail.spellBars." }) do
        add(p, "barTextureFromSkin", "bgFromSkin", "borderStyleFromSkin", "borderColorFromSkin")
    end
    for _, p in ipairs({ "resultsTable.damageBar.", "resultsTable.dpsBar.", "compare.best.", "compare.other." }) do
        add(p, "barTextureFromSkin", "borderStyleFromSkin", "borderColorFromSkin")
    end
    return keys
end
Appearance.FULL_SKIN_KEYS = fullSkinKeys()

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

-- A stored swatch's r, g, b and alpha (`alpha` when given, else its own, else 1).
local function swatch(stored, alpha)
    local s = type(stored) == "table" and stored or {}
    return s.r or 1, s.g or 1, s.b or 1, alpha or s.a or 1
end

-- The named class's RAID_CLASS_COLORS entry when it carries a color, else nil.
local function classEntry(class)
    local c = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[class]
    if type(c) == "table" and type(c.r) == "number" then return c end
    return nil
end

-- A swatch through its class-color companion. With `class` (a class token: a stored run's character)
-- the class is that one, the surface describing that character; without it, the player's, through
-- LibKa0s-Core's resolver. An unresolvable class falls through to the swatch; its alpha always holds.
local function color(stored, useClass, class)
    if class ~= nil then
        local a = type(stored) == "table" and stored.a or 1
        local c = useClass and classEntry(class)
        if c then return c.r, c.g, c.b, a end
        return swatch(stored, a)
    end
    local core = LibStub and LibStub("LibKa0s-Core-1.0", true)
    if core and core.ResolveColor then return core.ResolveColor(stored, useClass) end
    return swatch(stored)
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
--- `leaf` may also be "borderStyle" (the same seam, the skin's `bar.borderStyle`).
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
--- @param where string|nil  "window" when it draws in the Results window (S.FontFlags'); nil: HUD text
--- @return table { path, size, flags, shadow, r, g, b, a }
function Appearance.Font(block, where)
    return Appearance.FontAt("appearance." .. block .. ".", D[block], nil, where)
end

-- The flags the block at `p` draws: a picked flag as picked; From skin (or nothing stored) none on a
-- mono clock, else the Font outline through S.FontFlags as `where`'s text; without it the default
-- outline, HUD text only (D-10).
local function fontFlags(p, S, where)
    local flags = setting(p .. "fontFlags")
    local picked = type(flags) == "string" and flags ~= FROM_SKIN
    if picked then return flags end
    if MONO[p] then return "" end
    if S and type(S.FontFlags) == "function" then return S.FontFlags(flags, where) end
    return where == "window" and "" or "OUTLINE"
end

-- The text color the skin draws for the block at `p`, while its companion is on and no class color
-- comes first; else nothing, and the stored color stands. A degraded facade answers nothing.
local function skinText(p, S)
    if not S or setting(p .. "fontColorFromSkin") ~= true or setting(p .. "useClassColorFont") == true then return nil end
    local r, g, b, a = S.HudTextColor()
    if r == nil then return nil end
    if OWN_TEXT[p] then return S.Color(OWN_TEXT[p]) end
    return r, g, b, a
end

local ownShadow = {}   -- refilled per read: S.HudFont keeps nothing of it

-- What S.HudFont is handed for the block at `p`: the stored shadow and its companion, or for a block
-- with a shadow of its own, that shadow as a stored one. HudShadow's nil (Ignore fonts, or no library)
-- leaves the player's.
local function shadowOf(p, S)
    local stored, follow = setting(p .. "fontShadow") == true, setting(p .. "fontShadowFromSkin") == true
    if not (follow and OWN_SHADOW[p] and S) then return stored, follow end
    if S.HudShadow() == nil then return stored, false end
    local r, g, b, a = S.Color("dr.hud.shadow")
    if r == nil then return false, false end
    ownShadow[1], ownShadow[2] = S.Token("hud.shadowX"), S.Token("hud.shadowY")
    ownShadow[3], ownShadow[4], ownShadow[5], ownShadow[6] = r, g, b, a
    return ownShadow, false
end

--- A font block stored at `p` (its prefix, with the dot), `def` its defaults; `class` as color's;
--- `where` as Font's.
function Appearance.FontAt(p, def, class, where)
    local name, fromSkin = Appearance.MediaKey(p, "font")
    local path = fetch("font", name) or fetch("font", setting(p .. "font")) or fetch("font", def.font)
    if not path and def.font == "JetBrains Mono" then path = NS.Constants and NS.Constants.FONT_MONO end
    local S = NS.Skin
    local r, g, b, a = skinText(p, S)
    if r == nil then r, g, b, a = color(setting(p .. "fontColor"), setting(p .. "useClassColorFont") == true, class) end
    local size = tonumber(setting(p .. "fontSize")) or def.fontSize
    if S and type(S.HudFontSize) == "function" then size = S.HudFontSize(size, fromSkin) end
    local shadow, shadowFromSkin = shadowOf(p, S)
    return {
        path = path or FALLBACK_FONT,
        size = size,
        flags = fontFlags(p, S, where),
        shadow = shadow, shadowFromSkin = shadowFromSkin,
        r = r, g = g, b = b, a = a,
    }
end

local fontOpts = {}   -- refilled per call, every field: S.HudFont keeps nothing of it

--- Draw `fs` in a resolved font block, through S.HudFont: a 12.0.7 client draws only a font object's
--- shadow. `scale` multiplies its size (a clock shown alone); `keepColor` leaves the FontString's color
--- as its caller set it.
--- @param fs table  a FontString
--- @param font table  Appearance.Font's
--- @param scale number|nil
--- @param keepColor boolean|nil
function Appearance.ApplyFont(fs, font, scale, keepColor)
    fontOpts.face, fontOpts.size, fontOpts.flags = font.path, math.floor(font.size * (scale or 1) + 0.5), font.flags
    fontOpts.shadow, fontOpts.shadowFromSkin = font.shadow, font.shadowFromSkin
    NS.Skin.HudFont(fs, fontOpts)
    if not keepColor then fs:SetTextColor(font.r, font.g, font.b, font.a) end
end

--- The spell bars' look: the HUD's, or the Results detail's with `where` "window" (Breakdown.New's).
--- @param where string|nil
--- @return table Appearance.Styled's
function Appearance.Bar(where)
    if where == "window" then
        return Appearance.Styled(DETAIL_PREFIX, NS.defaults.profile.resultsDetail.spellBars)
    end
    return Appearance.Styled("appearance.bars.", D.bars)
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

-- The block's background, its class resolved as color's, a class color before the skin's track.
local function background(p, class)
    if setting(p .. "bgFromSkin") == true and setting(p .. "useClassColorBg") ~= true then
        local token = p == PACE_PREFIX and PACE_TRACK_TOKEN or TRACK_TOKEN
        local r, g, b, a = NS.Style.Rgba(token)
        return { r = r, g = g, b = b, a = a }
    end
    local r, g, b, a = color(setting(p .. "bgColor"), setting(p .. "useClassColorBg") == true, class)
    return { r = r, g = g, b = b, a = a }
end

-- The edge file a border key names, or nil for none. A key LSM cannot answer draws no border.
local function edgeFile(key)
    if key == nil or key == "None" then return nil end
    if FLAT_EDGE[key] then return FALLBACK_BAR end
    return fetch("border", key)
end

-- The block's border, or nil when it draws none.
local function border(p, class)
    local file = edgeFile((Appearance.MediaKey(p, "borderStyle")))
    local S = NS.Skin
    local stored = setting(p .. "borderSize")
    local size = tonumber(S.Resolve("bar.borderSize", stored, setting(p .. "borderStyleFromSkin") == true))
        or tonumber(stored) or 0
    if not file or size <= 0 then return nil end
    local useClass = setting(p .. "useClassColorBorder") == true
    local r, g, b, a
    if setting(p .. "borderColorFromSkin") == true and not useClass then r, g, b, a = S.Color("bar.border") end
    if r == nil then r, g, b, a = color(setting(p .. "borderColor"), useClass, class) end
    return { file = file, size = size, r = r, g = g, b = b, a = a }
end

--- A styled bar block stored at `p`: BarAt's fill, plus `bg` and `border`; `class` as color's.
--- @return table { texture, r, g, b, a, bg = { r, g, b, a }, border = { file, size, r, g, b, a } | nil }
function Appearance.Styled(p, def, class)
    local look = Appearance.BarAt(p, def, class)
    look.bg, look.border = background(p, class), border(p, class)
    return look
end

--- Paint a bar's track from a look's `bg`. Painted through its alpha, never hidden: the edge may be
--- anchored to it, and a track of no opacity draws nothing.
--- @param tex table  a Texture
--- @param bg table  a look's `bg`
function Appearance.PaintTrack(tex, bg)
    tex:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
end

--- Draw a look's `border` around `anchor`: a frame of `parent`'s kept on `holder.edge`, made the first
--- time a border draws, with no fill and no mouse. Nil hides it. The backdrop is set only when it changes.
--- @param holder table  what keeps the frame
--- @param parent table  a frame
--- @param anchor table  the frame or region it covers
--- @param look table|nil  a look's `border`
function Appearance.PaintEdge(holder, parent, anchor, look)
    local edge = holder.edge
    if not look then
        if edge then edge:Hide() end
        return
    end
    if not edge then
        edge = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        edge:SetAllPoints(anchor)
        holder.edge = edge
    end
    local key = look.file .. "@" .. look.size
    if edge.edgeKey ~= key then
        edge.edgeKey = key
        if edge.SetBackdrop then edge:SetBackdrop({ edgeFile = look.file, edgeSize = look.size }) end
    end
    if edge.SetBackdropBorderColor then edge:SetBackdropBorderColor(look.r, look.g, look.b, look.a) end
    edge:Show()
end

--- The damage chart's columns (HUD Appearance > Damage chart).
--- @return table { texture, r, g, b, a }
function Appearance.Chart()
    return Appearance.BarAt("appearance.chart.", D.chart)
end

--- The damage chart plot's background (HUD Appearance > Chart background): the swatch, or the
--- player's class color while its companion is on, the swatch's alpha kept either way; the skin's
--- (`dr.chart.bg`, which follows chart.track) while `bgFromSkin` is on and no class color comes first.
--- @return table { r, g, b, a }
function Appearance.ChartBackground()
    local useClass = setting("appearance.chart.useClassColorBg") == true
    if setting("appearance.chart.bgFromSkin") == true and not useClass then
        local r, g, b, a = NS.Style.Rgba("dr.chart.bg")
        return { r = r, g = g, b = b, a = a }
    end
    local r, g, b, a = color(setting("appearance.chart.bgColor") or D.chart.bgColor, useClass)
    return { r = r, g = g, b = b, a = a }
end

--- The pace bar's fill (HUD Appearance > Pace bar), its own block since 2026-10-25: styling the
--- chart's columns no longer restyles it.
--- @return table Appearance.Styled's
function Appearance.Pace()
    return Appearance.Styled(PACE_PREFIX, D.pace)
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
