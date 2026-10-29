local addonName, NS = ...
-- core/SkinSetup.lua — the LibKa0s-Skin-1.0 seam: which skin this addon wears (skinning-§1/§3), as
-- LootHistory's core/SkinSetup.lua is, with this addon's own colors declared as owner tokens.
--
-- ── WHAT IT PUBLISHES ────────────────────────────────────────────────────────────────────────
--
--   NS.Skin                 the owner's facade, `Skin:For("DpsRace")`: the painting vocabulary
--                           (Shell, Button, Text, ...) and Token / Color / Resolve / OnLooksChanged.
--                           Every surface that draws reads its colors here.
--   NS.SkinChoice()         the stored (source, skin) pair, read through NS.GetSetting; "ka0s",
--                           "ka0s" before NS:InitDB has built the profile store.
--   NS.WriteSkinChoice(s,k,i,m) the write seam: every half through NS.SetByPath, the one seam `/dr set`
--                           and the panel already write through (architecture-§5); `i`, the Scope's
--                           `{ panel, fonts }`, writes the two exceptions, and `m`, the Font and
--                           texture section's `{ font, texture }`, the two overrides ("" for false).
--   NS.ApplySkinChoice(s,k) moves the applied skin: `Skin:SetChoice`, which resolves, repaints every
--                           frame recorded for this owner and THEN fires OnLooksChanged. No argument
--                           applies the stored pair and with it the stored exceptions and overrides
--                           (NS:OnInitialize, the profile callbacks); a nil half keeps that half (each
--                           Skin row's onChange).
--   NS.ApplySkinIgnore(p,f) moves the applied exceptions (`Skin:SetIgnore`); no argument applies the
--                           stored pair, a nil half keeps that half.
--   NS.SkinOverride()       the stored overrides: font, texture, each an LSM key or false.
--   NS.ApplySkinOverride(f,t) moves the applied overrides (`Skin:SetOverride`); no argument applies the
--                           stored pair, a nil half keeps that half, false or "" clears.
--   NS.SKIN_SOURCE_OPTIONS  the source row's values, and NS.SKIN_OPTIONS the skin row's (every
--   NS.SKIN_OPTIONS         registered skin, in the library's order). settings/General.lua reads both.
--   NS.SKIN_FALLBACK        the host copy of the Ka0s Default tokens the degraded facade answers.
--   NS.SKIN_TOKENS          this addon's owner tokens (skinning-§1): name -> { default, follow,
--                           skins }. Registered with the owner; the degraded facade answers each
--                           one's `default`.
--   NS.SkinColor(name)      a color token as a call site writes it (three components when opaque).
--   NS.SkinEscape(name)     a color token as a "|cffrrggbb" escape, rounded to the byte.
--   NS.QualityColor(q)      an item quality's r, g, b: the skin's q.* token where it sets one (a
--                           legibility override), else the client's ITEM_QUALITY_COLORS; nil for none
--                           (LootHistory's).
--
-- ── WHERE IT LOADS ───────────────────────────────────────────────────────────────────────────
--
-- After core/CoreSetup.lua, whose NS.ApplySkin the degraded facade's Shell routes to and whose
-- NS.Print the reload line uses, and before core/WidgetsSetup.lua and every module that builds a
-- frame, so NS.Skin exists for all of them. settings/General.lua reads NS.SKIN_OPTIONS at file load
-- and is far below. Nothing here reads the profile at load: RegisterOwner calls `get` once, before
-- AceDB exists, and it answers Ka0s Default; the profile's pair is applied by NS.ApplySkinChoice right
-- after NS:InitDB (core/DpsRace.lua) and on every profile callback (core/Database.lua).
--
-- ── WHY A ROW'S onChange PASSES ONE HALF ─────────────────────────────────────────────────────
--
-- The Skin tab and another addon's "Copy to every Ka0s addon" both call Skin:SetChoice FIRST and
-- write the store after, one half at a time. A row reaction that re-applied the whole stored pair
-- would apply the half-written one in between: a second repaint, to a skin the player never picked.
-- Applying only the row's own half against the applied choice makes each write a no-op (SetChoice is
-- idempotent), so a pick is ONE effective SetChoice and one repaint, while a bare
-- `/dr set skin.skin obsidian` still repaints.
--
-- Nothing skin-related keys off SETTINGS_CHANGED. A surface that has to rebuild on a skin change
-- (markup built once, a pooled row) subscribes to NS.Skin.OnLooksChanged, which fires after the new
-- skin is resolved and the recorded frames are repainted.

local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)

local SOURCE_PATH, SKIN_PATH = "skin.source", "skin.skin"
local PANEL_PATH, FONTS_PATH = "skin.ignorePanel", "skin.ignoreFonts"
local FONT_PATH, TEXTURE_PATH = "skin.font", "skin.texture"
local DEFAULT = "ka0s"

-- The Ka0s Default tokens the DEGRADED facade answers, copied from the library and limited to the
-- ones this addon reads. Both arms publish the table, so tests/test_skin.lua can hold each entry to
-- the live library's Ka0s Default value: a copy that drifts goes red there. A surface converted to a
-- token adds the token here in the same change.
NS.SKIN_FALLBACK = {
    ["win.bg"]     = { 0.06, 0.06, 0.08, 0.92 },
    ["win.border"] = { 0, 0, 0, 1 },
    ["win.inner"]  = { 0.24, 0.24, 0.27, 0.85 },
    ["title.text"] = { 1, 0.82, 0, 1 },
    ["divider"]    = { 0.24, 0.24, 0.27, 0.85 },
    -- The colors the windows read themselves (modules/Style.lua's live tables, DR-02).
    ["text.body"]        = { 0.9, 0.9, 0.9, 1 },
    ["text.muted"]       = { 0.7, 0.7, 0.72, 1 },
    ["text.heading"]     = { 1, 0.82, 0, 1 },
    ["text.accent"]      = { 1, 0.82, 0, 1 },
    ["text.disabled"]    = { 0.5, 0.5, 0.5, 1 },
    ["text.highlight"]   = { 1, 1, 1, 1 },
    ["gtip.title"]       = { 1, 0.82, 0, 1 },
    ["gtip.body"]        = { 0.9, 0.9, 0.9, 1 },
    ["gtip.value"]       = { 1, 1, 1, 1 },
    ["icon.tint"]        = { 0.7, 0.7, 0.72, 1 },
    ["icon.arrow"]       = { 1, 0.82, 0, 1 },
    ["icon.border"]      = { 0, 0, 0, 1 },
    ["tab.text"]         = { 0.7, 0.7, 0.72, 1 },
    ["tab.onText"]       = { 1, 0.82, 0, 1 },
    ["tab.onLine"]       = { 1, 0.82, 0, 1 },
    ["list.header.text"] = { 1, 0.82, 0, 1 },
    ["btnPrimary.text"]  = { 1, 0.82, 0, 1 },
    ["section.rule"]     = { 1, 0.82, 0, 0.35 },
    ["handle.bg"]        = { 0, 0, 0, 0.75 },
    ["chart.track"]      = { 1, 1, 1, 0.06 },
    ["chart.axis"]       = { 0.45, 0.45, 0.5, 0.8 },
    ["sem.statusBad"]    = { 1, 0.32, 0.32, 1 },
    ["sem.danger"]       = { 1, 1 / 3, 1 / 3, 1 },
}

-- ── the owner tokens (skinning-§1, LibKa0s-Skin-1.0 minor 7) ─────────────────────────────────
--
-- The colors DPS Race draws under Ka0s Default that no library token holds exactly (the M0
-- inventory's DR-G1 to DR-G4). Each `default` is the pixel the addon draws today (X1: never snapped
-- to a near library token), named in the addon's own `dr.` namespace (X2, X12), and each `follow` is
-- the nearest library ROLE token, so every other skin and EllesmereUI draw it in their own palette.
--
-- A WASH (a meaning color at a low alpha: the danger button's fill, the caution callout's box) would
-- follow its role token at that token's own alpha, which is opaque: a solid red button. So a wash
-- follows a quiet chrome token (under EllesmereUI, which carries no per-skin table) and carries a
-- `skins` entry of its own for every registered Ka0s skin: that skin's role color at the wash's
-- alpha. The OPAQUE MODAL (the ability timeline and the gear view, which must hide the Results
-- window under them in every skin, Glass included) is the same idea: each skin's own window fill at
-- alpha 1, with its inner rule and divider blended over that fill to alpha 1, the blend
-- modules/Results_Timeline.lua's `opaque` has always made of Core.SKIN.

local GOLD = { 1, 0.82, 0, 1 }
local RED = { 1, 0.32, 0.32 }
local AMBER = { 1, 0.72, 0.29 }

local function rgba(c, a) return { c[1], c[2], c[3], a } end

--- `c` blended over `under` to alpha 1 (the timeline's opaque()).
local function opaque(c, under)
    local a = c[4] or 1
    return { c[1] * a + under[1] * (1 - a), c[2] * a + under[2] * (1 - a), c[3] * a + under[3] * (1 - a), 1 }
end

--- A `skins` table, one entry per registered Ka0s skin other than Ka0s Default (which answers the
--- token's `default`): `make(tokens)` over that skin's resolved tokens, an entry skipped when it
--- answers nil (that skin then answers the `follow` token's value). Empty without the library.
local function perSkin(make)
    local out = {}
    if not (Skin and type(Skin.Skins) == "function" and type(Skin.ResolveSkin) == "function") then return out end
    for _, def in ipairs(Skin:Skins()) do
        if def.key ~= (Skin.DEFAULT or DEFAULT) then
            local v = make(Skin:ResolveSkin(def.key))
            if v ~= nil then out[def.key] = v end
        end
    end
    return out
end

--- The skin's `role` color at alpha `a`.
local function wash(role, a)
    return perSkin(function(t)
        local c = type(t[role]) == "table" and t[role]
        return c and rgba(c, a) or nil
    end)
end

--- The skin's window fill at alpha 1, or a token blended over it to alpha 1.
local function modal(name)
    return perSkin(function(t)
        local bg = type(t["win.bg"]) == "table" and t["win.bg"]
        if not bg then return nil end
        if name == "win.bg" then return rgba(bg, 1) end
        local c = type(t[name]) == "table" and t[name]
        return c and opaque(c, bg) or nil
    end)
end

local WIN_BG, WIN_INNER = NS.SKIN_FALLBACK["win.bg"], NS.SKIN_FALLBACK["win.inner"]

NS.SKIN_TOKENS = {
    -- DR-G4: the race's meaning hues. Ahead / gain / new best / the DPS figure; caution (late casts,
    -- warnings, the flags' details, the amber cell marks); the grace and time chips' blue.
    ["dr.ahead"]   = { default = { 0.36, 0.86, 0.46, 1 }, follow = "sem.good" },
    ["dr.caution"] = { default = rgba(AMBER, 1), follow = "sem.warn" },
    ["dr.info"]    = { default = { 0.56, 0.72, 1.0, 1 }, follow = "sem.info" },
    -- DR-G3: the caution callout (the HUD's waiting hint, the target card's badge, the run detail's
    -- flags box): an amber wash, its edge, the badge's stronger edge, and the cream text.
    ["dr.callout.bg"]           = { default = rgba(AMBER, 0.07), follow = "list.hover", skins = wash("sem.warn", 0.07) },
    ["dr.callout.border"]       = { default = rgba(AMBER, 0.35), follow = "section.rule", skins = wash("sem.warn", 0.35) },
    ["dr.callout.borderStrong"] = { default = rgba(AMBER, 0.6), follow = "section.rule", skins = wash("sem.warn", 0.6) },
    ["dr.callout.text"]         = { default = { 0.95, 0.85, 0.67, 1 }, follow = "text.headingAlt" },
    -- DR-G2: the danger button (Cancel race, Delete run): a red wash, a red edge, a red label, gold
    -- under the pointer.
    ["dr.danger.bg"]     = { default = rgba(RED, 0.08), follow = "btn.bg", skins = wash("sem.statusBad", 0.08) },
    ["dr.danger.border"] = { default = rgba(RED, 0.6), follow = "btn.border", skins = wash("sem.statusBad", 0.6) },
    ["dr.danger.text"]   = { default = rgba(RED, 1), follow = "sem.statusBad" },
    ["dr.danger.hover"]  = { default = GOLD, follow = "btn.hover" },
    -- The other buttons' slots (modules/Hud_States.lua): a primary button's gold wash and edge (gold
    -- under the pointer too), a selected preset's gold edge, and every style's disabled look, its box
    -- and label faded (fill x0.4, edge 0.25, label 0.4).
    ["dr.primary.bg"]        = { default = rgba(GOLD, 0.12), follow = "btnPrimary.bg" },
    ["dr.primary.border"]    = { default = rgba(GOLD, 0.75), follow = "btnPrimary.border" },
    ["dr.primary.hover"]     = { default = GOLD, follow = "btnPrimary.hover" },
    ["dr.sel.border"]        = { default = GOLD, follow = "btnPrimary.border" },
    ["dr.btn.offBg"]         = { default = { 0.1, 0.1, 0.12, 0.36 }, follow = "btn.bg" },
    ["dr.btn.offBorder"]     = { default = { 0.24, 0.24, 0.27, 0.25 }, follow = "btn.border" },
    ["dr.btn.offText"]       = { default = { 1, 1, 1, 0.4 }, follow = "text.disabled" },
    ["dr.primary.offBg"]     = { default = rgba(GOLD, 0.048), follow = "btnPrimary.bg" },
    ["dr.primary.offBorder"] = { default = rgba(GOLD, 0.25), follow = "btnPrimary.border" },
    ["dr.primary.offText"]   = { default = rgba(GOLD, 0.4), follow = "text.disabled" },
    ["dr.danger.offBg"]      = { default = rgba(RED, 0.032), follow = "btn.bg", skins = wash("sem.statusBad", 0.032) },
    ["dr.danger.offBorder"]  = { default = rgba(RED, 0.25), follow = "btn.border", skins = wash("sem.statusBad", 0.25) },
    ["dr.danger.offText"]    = { default = rgba(RED, 0.4), follow = "text.disabled" },
    -- The HUD's and the Results window's body text and its dim gray; the flat boxes' faint edge.
    ["dr.text"]       = { default = { 0.93, 0.93, 0.95, 1 }, follow = "text.body" },
    ["dr.dim"]        = { default = { 0.62, 0.62, 0.68, 1 }, follow = "text.muted" },
    ["dr.box.border"] = { default = { 1, 1, 1, 0.10 }, follow = "list.boxEdge" },
    -- The Results list (and the spell rows that share it): the stripe, the hover and selection
    -- washes, and the scroll thumb (D-5's values, kept).
    ["dr.list.stripe"]  = { default = { 1, 1, 1, 0.025 }, follow = "list.stripe" },
    ["dr.list.hover"]   = { default = { 1, 1, 1, 0.04 }, follow = "list.hover" },
    ["dr.list.sel"]     = { default = rgba(GOLD, 0.10), follow = "list.sel" },
    ["dr.scroll.thumb"] = { default = { 1, 1, 1, 0.25 }, follow = "scroll.thumb" },
    ["dr.list.track"]   = { default = { 1, 1, 1, 0.04 }, follow = "chart.track" },
    -- The run detail: its pane's dim wash, and the timing strip's two segments and their edge.
    ["dr.pane.bg"]       = { default = { 0, 0, 0, 0.15 }, follow = "panel.bg" },
    -- The dim cover over the Results window while the ability timeline is open (D-8's .45, kept).
    ["dr.cover.dim"]     = { default = { 0, 0, 0, 0.45 }, follow = "cover.dim" },
    -- The Insights charts' bars (D-7's blue, kept).
    ["dr.chart.bar"]     = { default = { 0.40, 0.66, 1.0, 1 }, follow = "chart.bar" },
    -- The compare's see-through line between the two runs' columns.
    ["dr.sep"]           = { default = { 0.5, 0.5, 0.5, 0.18 }, follow = "divider" },
    -- The ability timeline and the HUD's pace bar: the faint grid and the legend's faint rule, and
    -- the timeline's own scroll bar (a lighter track and thumb than the Results list's).
    ["dr.chart.grid"]      = { default = { 1, 1, 1, 0.08 }, follow = "chart.grid" },
    -- The damage chart's best-pace diagonal and the pace bar's on-pace tick (D-7's values, kept).
    ["dr.chart.diag"]      = { default = { 0.9, 0.9, 0.92, 0.4 }, follow = "chart.marker" },
    ["dr.pace.tick"]       = { default = { 1, 1, 1, 0.85 }, follow = "chart.crosshair" },
    ["dr.rule"]            = { default = { 1, 1, 1, 0.08 }, follow = "divider" },
    ["dr.scroll.track"]    = { default = { 1, 1, 1, 0.10 }, follow = "scroll.track" },
    ["dr.scroll.thumbAlt"] = { default = { 1, 1, 1, 0.35 }, follow = "scroll.thumb" },
    ["dr.strip.seg"]     = { default = { 0.07, 0.07, 0.1, 1 }, follow = "input.bg" },
    ["dr.strip.segEdge"] = { default = { 1, 1, 1, 0.08 }, follow = "input.border" },
    -- An empty gear or loadout slot's edge.
    ["dr.slot.empty"]    = { default = { 0.07, 0.07, 0.1, 1 }, follow = "input.bg" },
    -- The badge on the target card: the callout's wash a little stronger.
    ["dr.callout.badge"]        = { default = rgba(AMBER, 0.08), follow = "list.hover", skins = wash("sem.warn", 0.08) },
    -- DR-G1: the opaque modal shell (the ability timeline, the gear view).
    ["dr.modal.bg"]      = { default = rgba(WIN_BG, 1), follow = "win.bg", skins = modal("win.bg") },
    ["dr.modal.inner"]   = { default = opaque(WIN_INNER, WIN_BG), follow = "win.inner", skins = modal("win.inner") },
    ["dr.modal.divider"] = { default = opaque(NS.SKIN_FALLBACK["divider"], WIN_BG), follow = "divider",
                             skins = modal("divider") },
}

--- A color token's components AS A CALL SITE WRITES THEM: r, g, b for an opaque color and r, g, b,
--- a otherwise (the library's own text and vertex rule), so a site that passed three components
--- before it read a token still passes three on Ka0s Default. nil for a token the skin leaves alone.
--- Read through NS.Skin at call time, so it answers the live skin, or the host copy degraded.
function NS.SkinColor(name)
    local r, g, b, a = NS.Skin.Color(name)
    if r == nil then return nil end
    if a == nil or a == 1 then return r, g, b end
    return r, g, b, a
end

--- A color token as a "|cffrrggbb" escape, each channel rounded to the nearest byte (1/3 is 55),
--- so markup a call site wrote as a literal keeps its bytes on Ka0s Default. nil for a token the
--- skin leaves alone.
function NS.SkinEscape(name)
    local r, g, b = NS.Skin.Color(name)
    if r == nil then return nil end
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

-- The six qualities the skin schema names (q.poor .. q.legendary); every other quality (artifact,
-- heirloom, token) is the client's color under every skin.
local QUALITY_TOKEN = { [0] = "q.poor", "q.common", "q.uncommon", "q.rare", "q.epic", "q.legendary" }

--- An item quality's r, g, b. The q.* tokens: Ka0s Default writes the client's own colors out (since
--- LibKa0s SkinDefs minor 8), a skin may override them for legibility. nil for a quality the client
--- has no color for, so a caller keeps its own fallback.
function NS.QualityColor(q)
    local name = QUALITY_TOKEN[q]
    if name then
        local r, g, b = NS.Skin.Color(name)
        if r ~= nil then return r, g, b end
    end
    local c = ITEM_QUALITY_COLORS and q ~= nil and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return nil
end

NS.SKIN_SOURCE_OPTIONS = {
    { value = "ka0s", text = "Ka0s skins" },
    { value = "eui",  text = "EllesmereUI" },
}

-- The skin row's values: every registered skin, Ka0s Default first. Without the library the one skin
-- the degraded facade can draw.
NS.SKIN_OPTIONS = {}
if Skin and type(Skin.Skins) == "function" then
    for _, def in ipairs(Skin:Skins()) do
        NS.SKIN_OPTIONS[#NS.SKIN_OPTIONS + 1] = { value = def.key, text = def.label or def.key }
    end
end
if #NS.SKIN_OPTIONS == 0 then NS.SKIN_OPTIONS[1] = { value = DEFAULT, text = "Ka0s Default" } end

--- True once the profile store and the write seam exist (NS:InitDB, settings/Schema.lua).
local function storeReady()
    return NS.db ~= nil and type(NS.GetSetting) == "function" and type(NS.SetByPath) == "function"
end

--- The stored pair, lazily and nil-safely: Ka0s Default until the profile store exists.
function NS.SkinChoice()
    if not storeReady() then return DEFAULT, DEFAULT end
    return NS.GetSetting(SOURCE_PATH) or DEFAULT, NS.GetSetting(SKIN_PATH) or DEFAULT
end

--- A stored override as the profile keeps it: the LSM key, or "" for the skin's own (false, nil, "").
local function storedKey(v)
    if type(v) == "string" and v ~= "" then return v end
    return ""
end

--- The write seam: every half through NS.SetByPath (validate, store, the [Set] line, onChange).
function NS.WriteSkinChoice(source, skin, ignore, media)
    if not storeReady() then return end
    if source ~= nil then NS.SetByPath(SOURCE_PATH, source) end
    if skin ~= nil then NS.SetByPath(SKIN_PATH, skin) end
    if type(ignore) == "table" then
        NS.SetByPath(PANEL_PATH, ignore.panel == true)
        NS.SetByPath(FONTS_PATH, ignore.fonts == true)
    end
    if type(media) == "table" then
        NS.SetByPath(FONT_PATH, storedKey(media.font))
        NS.SetByPath(TEXTURE_PATH, storedKey(media.texture))
    end
end

--- The stored overrides, nil-safely: each an LSM key, or false for the skin's own.
function NS.SkinOverride()
    if not storeReady() then return false, false end
    local font, texture = storedKey(NS.GetSetting(FONT_PATH)), storedKey(NS.GetSetting(TEXTURE_PATH))
    return font ~= "" and font or false, texture ~= "" and texture or false
end

--- The stored exceptions, nil-safely: the settings panel left the client's, the fonts skinned
--- (the defaults) until the profile store exists.
local function storedIgnore()
    if not storeReady() then return true, false end
    return NS.GetSetting(PANEL_PATH) == true, NS.GetSetting(FONTS_PATH) == true
end

-- ── the degraded arm ─────────────────────────────────────────────────────────────────────────

if not Skin then
    local function color(name)
        local c = NS.SKIN_FALLBACK[name] or (NS.SKIN_TOKENS[name] and NS.SKIN_TOKENS[name].default)
        if c then return c[1], c[2], c[3], c[4] or 1 end
    end
    local function noop() end
    local S = { owner = addonName, apiVersion = 3, FROM_SKIN = "@skin" }
    -- Every vocabulary name answers, and a primitive with no host meaning is a no-op that never
    -- raises. The list is LibKa0s-Skin-1.0's VOCAB; tests/test_skin.lua holds this table to the live
    -- facade key for key.
    for _, name in ipairs({
        "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
        "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "SetTabSelection",
        "CloseButton", "PageButton", "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill",
        "GetAccentColor", "GetPanelColor", "GetFont",
        "TitleBar", "Divider", "Footer", "Card", "Slider", "NavItem", "Drawer", "ListRow", "MenuFrame",
        "Tooltip", "Strip", "Cover", "Text", "ChartStyle", "BarStyle", "IconBorder", "GlowColor",
        "BarTexture",
    }) do S[name] = noop end

    S.Token = function(name)
        return NS.SKIN_FALLBACK[name] or (NS.SKIN_TOKENS[name] and NS.SKIN_TOKENS[name].default)
    end
    S.Color = color
    S.Resolve = function(kind, value, fromSkin)
        if fromSkin or value == S.FROM_SKIN then return S.Token(kind) end
        return value
    end
    S.OnLooksChanged = function(fn) return fn end   -- the skin never changes without the library
    S.IsEnabled = function() return false end
    S.GetStyle = function() return "ka0s:" .. DEFAULT end
    -- The window edge is CoreSetup's degraded NS.ApplySkin: without the library the chrome degrades
    -- to nothing (standalone-windows), so the facade's Shell does too.
    S.Shell = function(frame) if NS.ApplySkin then NS.ApplySkin(frame) end end
    S.GetPanelColor = function() return color("win.bg") end
    S.GetFont = function() return STANDARD_TEXT_FONT end
    S.ChartStyle = function() return {} end
    S.BarStyle = function() return {} end

    NS.Skin = S
    function NS.ApplySkinChoice() return false, false end
    function NS.ApplySkinIgnore() return false, false end
    function NS.ApplySkinOverride() return false end
    return
end

-- ── the live seam ────────────────────────────────────────────────────────────────────────────

NS.Skin = Skin:For(addonName)
Skin:RegisterOwner(addonName, {
    label  = NS.BRAND,
    get    = NS.SkinChoice,
    set    = NS.WriteSkinChoice,
    tokens = NS.SKIN_TOKENS,
    -- A refused owner token or remap, and the EllesmereUI provider's one line, go to the debug
    -- console under the Skin tag (resolved at call time: core/DebugLogSetup.lua loads below).
    log    = function(line) if NS.Debug then NS.Debug("Skin", "%s", line) end end,
})

-- The one line a reload request earns on the path that has no popup of its own (a profile change
-- leaving an EllesmereUI that painted this session). The Skin tab raises the library's popup for its
-- own picks.
local RELOAD_LINE = NS.L and NS.L["Reload your interface (/reload) to finish changing the skin."]
    or "Reload your interface (/reload) to finish changing the skin."

function NS.ApplySkinIgnore(panel, fonts)
    if type(Skin.SetIgnore) ~= "function" then return false, false end
    if panel == nil and fonts == nil then panel, fonts = storedIgnore() end
    local changed, reload = Skin:SetIgnore(addonName, panel, fonts)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    return changed, reload
end

--- No argument applies the stored overrides; a nil half keeps that half, false or "" clears it (the
--- skin's own). A copy without SetOverride moves nothing.
function NS.ApplySkinOverride(font, texture)
    if type(Skin.SetOverride) ~= "function" then return false end
    if font == nil and texture == nil then font, texture = NS.SkinOverride() end
    return Skin:SetOverride(addonName, font, texture)
end

--- No argument applies the stored pair AND the stored exceptions and overrides (NS:OnInitialize, the
--- profile callbacks); a nil half keeps that half and leaves the rest alone (each Skin row).
function NS.ApplySkinChoice(source, skin)
    local whole = source == nil and skin == nil
    if whole then source, skin = NS.SkinChoice() end
    local changed, reload = Skin:SetChoice(addonName, source, skin)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    if whole then
        NS.ApplySkinIgnore()
        NS.ApplySkinOverride()
    end
    return changed, reload
end
