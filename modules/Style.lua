local _, NS = ...
-- modules/Style.lua — the look the HUD and the Results window share with the other Ka0s windows
-- (LootHistory's browser is the reference; BankLedger and MultiMeters agree): Blizzard's font objects
-- for every label, the header gold, the title-bar geometry, and the title-bar controls that turn gold
-- under the pointer.
--
-- FONT OBJECTS, NOT FONT FILES. A label takes one of Blizzard's font objects (`GameFontNormal` and its
-- family), never a path and a size, so it reads at the size and weight the rest of the collection
-- uses and follows the client's own font scaling. The one exception is a figure that is meant to be
-- read across the room: the HUD's race clocks and STOP, which keep their own monospace sizes
-- (modules/Hud_States.lua), and the KPI figures, which take the large `GameFontNormalHuge` the way
-- LootHistory's Insights cards do above a small caption.
--
-- WORDS. Tabs, column headers, buttons and captions are Title Case, as LootHistory's are; prose is
-- Sentence case. Nothing is upper-cased in code: what a label says is its locale string.
--
-- STYLING ONLY. Nothing here reads a meter value or a frame's geometry; a label made here is handed
-- what its caller hands it, and the secret-value rules of the caller still hold.
--
-- THE SKIN (skinning-§3, DR-02). Every color this addon draws is a token of the owner's skin
-- (core/SkinSetup.lua's NS.Skin): a library token, or one of this addon's own `dr.*` owner tokens
-- whose Ka0s Default value is the pixel the surface drew before the skin engine. A surface reads a
-- color in one of three ways:
--
--   Style.Tok(name)    a LIVE color table { r, g, b, a, token = name }, one per token, filled from
--                      the skin and refilled IN PLACE on every skin change, so a module-level
--                      palette (`local C = { text = Style.Tok("dr.text") }`) keeps its identity and
--                      every later read sees the new skin. The palettes the HUD and the Results
--                      window share are built from these.
--   Style.Paint(fs, c) a label's color AND face through the facade's S.Text, recorded, so the
--                      library replays it on a skin switch (no host repaint owed).
--   Style.OnLooks(fn)  a host repaint for what the library does not record (a color a call site
--                      composes from a live table, markup built into a string): run after the live
--                      tables are refilled, before both windows redraw.
--
-- Labels take the skin's faces: a Blizzard font object is still the size a label is made at, and
-- S.Text keeps that size (scaled by the skin's own size over the reference), so every layout holds.

local Style = {}
NS.Style = Style

-- The line a FONT.SECTION heading takes (16px, its gap under it included), and the clear space above
-- every heading but one at the very top (the owner's call, 2026-10-25: the detail read as cramped).
-- The Results detail and the HUD's running body and result card share both.
Style.SECTION_H = 22
Style.SECTION_GAP = 14

-- The font object each role draws in (Blizzard's; the client defines every one of them).
Style.FONT = {
    TITLE   = "GameFontNormal",          -- a window's title, centered in its title bar (gold)
    TAB     = "GameFontNormal",          -- a tab label (gold when active, gray when not)
    HEADER  = "GameFontNormalSmall",     -- a column header or a section label (gold)
    TEXT    = "GameFontHighlightSmall",  -- rows, cells, buttons, checkboxes, card text (white)
    HEADING = "GameFontHighlight",       -- a name that heads a card or a pane (white, 12px)
    -- The section headings of the Results detail and the HUD (the owner's call, 2026-10-25: a step
    -- above GameFontNormal, so the sections read apart).
    SECTION = "GameFontNormalLarge",     -- a section heading (gold, 16px; HEADER is 10px)
    -- An Insights chart's heading and its list panels' titles: LootHistory's Insights headings (the
    -- owner's call, 2026-10-28: SECTION read too large there).
    CHART   = "GameFontNormal",          -- an Insights chart heading (gold, 12px)
    NAME    = "GameFontHighlightLarge",  -- the character name heading the run detail (white, 16px)
    CAPTION = "GameFontDisableSmall",    -- footers, KPI captions, hints, axis labels (gray)
    FIGURE  = "GameFontNormalHuge",      -- a KPI figure (recolored by its caller)
    EMPTY   = "GameFontDisableLarge",    -- an empty list's message
}

-- The pixel height of the two font objects a scaled surface draws at a multiple of (Style.ScaledText:
-- the new-best toast, DR-04), as the client defines them. A config table, never read off a string.
Style.FONT_SIZE = {
    GameFontNormal         = 12,
    GameFontHighlightSmall = 10,
}

-- ── live colors ─────────────────────────────────────────────────────────────────────────────────

local live = {}      -- token name -> its live color table
local looks = {}     -- the host repaints, in registration order

local function fill(t)
    local r, g, b, a = NS.Skin.Color(t.token)
    t[1], t[2], t[3], t[4] = r or 1, g or 1, b or 1, a or 1
end

--- The live color table for token `name`: { r, g, b, a, token = name }, shared by every caller and
--- refilled in place on a skin change (never replaced).
--- @param name string  a library or owner color token
--- @return table
function Style.Tok(name)
    local t = live[name]
    if not t then
        t = { token = name }
        fill(t)
        live[name] = t
    end
    return t
end

--- Refill every live color table from the skin now in force.
function Style.SyncColors()
    for _, t in pairs(live) do fill(t) end
end

--- Run `fn()` after every skin change, once the live tables hold the new skin.
--- @param fn function
--- @return function fn
function Style.OnLooks(fn)
    looks[#looks + 1] = fn
    return fn
end

-- One listener for the owner: the tables first, the host repaints next, then both windows redraw
-- (HudAppearance.Changed: the HUD bodies, the rows and the Results tabs re-read every color).
NS.Skin.OnLooksChanged(function()
    Style.SyncColors()
    for _, fn in ipairs(looks) do fn() end
    if NS.HudAppearance and NS.HudAppearance.Changed then NS.HudAppearance.Changed() end
end)

--- `c`'s r, g, b (a live table or a token name), then `a` (default the color's own alpha).
function Style.Rgba(c, a)
    if type(c) == "string" then c = Style.Tok(c) end
    return c[1], c[2], c[3], a or c[4] or 1
end

--- `c`'s r, g, b only.
function Style.Rgb(c)
    if type(c) == "string" then c = Style.Tok(c) end
    return c[1], c[2], c[3]
end

-- ── textures tinted from the skin ───────────────────────────────────────────────────────────────
-- A texture the host colors itself (a rule, a wash, a mark, an icon's tint) through these two: the
-- color is drawn now and drawn again after every skin change, from the latest call's color (a pooled
-- texture takes its next item's). `c` is a live table or a token name; a data hue (a table with no
-- token) is drawn as given and stays.

local filled = setmetatable({}, { __mode = "k" })   -- texture -> { c, a }, SetColorTexture
local vertexed = setmetatable({}, { __mode = "k" }) -- texture -> { c, a }, SetVertexColor

--- `tex`:SetColorTexture in `c`, at alpha `a` (default the color's own).
local function remember(set, tex, c, a)
    local e = set[tex]
    if e then e[1], e[2] = c, a else set[tex] = { c, a } end
end

function Style.Fill(tex, c, a)
    remember(filled, tex, c, a)
    tex:SetColorTexture(Style.Rgba(c, a))
end

--- `tex`:SetVertexColor in `c`, at alpha `a` (default the color's own).
function Style.Vertex(tex, c, a)
    remember(vertexed, tex, c, a)
    tex:SetVertexColor(Style.Rgba(c, a))
end

Style.OnLooks(function()
    for tex, v in pairs(filled) do tex:SetColorTexture(Style.Rgba(v[1], v[2])) end
    for tex, v in pairs(vertexed) do tex:SetVertexColor(Style.Rgba(v[1], v[2])) end
end)

--- A "|cffrrggbb" escape for a DATA hue `c` (no token: the same under every skin), each channel
--- rounded to the byte. A token's escape is NS.SkinEscape's.
function Style.HueEscape(c)
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(c[1]), byte(c[2]), byte(c[3]))
end

-- ── boxes tinted with a meaning color ───────────────────────────────────────────────────────────
-- A chip, a badge and a status tag tint the DATA's color (a meaning token, or a rung-4 data hue):
-- this much of it fills the box, this much draws its edge (D-4: the data's color at the surface's
-- own opacity). Painted by the host on every bind, never by a recorded primitive, so a pooled box
-- takes the next item's color.

Style.FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
Style.TINT_FILL_A, Style.CHIP_EDGE_A, Style.BADGE_EDGE_A = 0.08, 0.55, 0.6

--- A 1px box for Style.TintBox, its colors unset.
function Style.FlatBox(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if f.SetBackdrop then f:SetBackdrop(Style.FLAT) end
    return f
end

--- Tint `f` (a Style.FlatBox) with `c` (a live table, or a data hue): the fill at TINT_FILL_A, the
--- edge at `edgeA`.
function Style.TintBox(f, c, edgeA)
    if not f.SetBackdropBorderColor then return end
    f:SetBackdropBorderColor(c[1], c[2], c[3], edgeA)
    f:SetBackdropColor(c[1], c[2], c[3], Style.TINT_FILL_A)
end

-- ── the list stripe ─────────────────────────────────────────────────────────────────────────────

--- The stripe's alpha for the row at `index` (1-based): the skin's `dr.list.stripe` on every even
--- row, none on the odd.
function Style.StripeAlpha(index)
    return index % 2 == 0 and Style.Tok("dr.list.stripe")[4] or 0
end

--- Stripe `tex` (a white texture) for the row at `index`.
function Style.Stripe(tex, index)
    if index % 2 == 0 then Style.Vertex(tex, "dr.list.stripe") else Style.Vertex(tex, "dr.list.stripe", 0) end
end

-- The header gold (Ka0s Default's `text.accent`, NORMAL_FONT_COLOR): the title, the column headers,
-- the active tab, the sort arrows and a hovered title-bar control are all this one color.
Style.GOLD = Style.Tok("text.accent")
-- A title-bar control at rest: the close control's own gray (`icon.tint`).
Style.REST = Style.Tok("icon.tint")

-- The title bar, the tab strip and a control slot (LootHistory and BankLedger: titleBarH 30,
-- tabStripH 26, 90px tabs on a 94px pitch; the close control's 18px slot).
Style.TITLE_BAR_H = 30
Style.TAB_STRIP_H = 26
Style.TAB_W, Style.TAB_PITCH = 90, 94
Style.CONTROL = 18
Style.CONTROL_PITCH = 22

-- The text role each font object answers when no color is named: the gold objects are headings (the
-- skin's title face), the white ones the highlight white, the gray ones the disabled gray (Ka0s
-- Default's text.heading, text.highlight and text.disabled are those objects' own colors).
local OBJECT_ROLE = {
    GameFontNormal = "heading", GameFontNormalSmall = "heading", GameFontNormalLarge = "heading",
    GameFontNormalHuge = "heading",
    GameFontHighlight = "text.highlight", GameFontHighlightSmall = "text.highlight",
    GameFontHighlightLarge = "text.highlight",
    GameFontDisableSmall = "disabled", GameFontDisableLarge = "disabled",
}
-- A gold token on a gold font object keeps the heading role (and its title face).
local GOLD_TOKEN = { ["text.heading"] = true, ["text.accent"] = true, ["title.text"] = true }
-- The library's text roles, by the token each draws.
local TOKEN_ROLE = { ["text.body"] = "body", ["text.muted"] = "muted", ["text.disabled"] = "disabled" }

local painted = setmetatable({}, { __mode = "k" })   -- fs -> the role or token last painted
local fontOf = setmetatable({}, { __mode = "k" })    -- fs -> the font object it was made in
local tinted = setmetatable({}, { __mode = "k" })    -- fs -> the token its color is

-- The token each library role draws, for the host's own tint (below).
local ROLE_TOKEN = { body = "text.body", muted = "text.muted", heading = "text.heading",
                     disabled = "text.disabled", title = "title.text", accent = "text.accent" }

local function tint(fs, token)
    local c = Style.Tok(token)
    if c[4] == 1 then fs:SetTextColor(c[1], c[2], c[3]) else fs:SetTextColor(c[1], c[2], c[3], c[4]) end
end

-- Every painted label's color again, after a switch (the library's replay has already put the role's
-- color and face back on each; this is the same color, for a label the library cannot see).
Style.OnLooks(function() for fs, token in pairs(tinted) do tint(fs, token) end end)

--- The S.Text role for a label in font object `font` colored `color` (a live table, a token name or
--- nil for the object's own role).
function Style.Role(font, color)
    local token = type(color) == "table" and color.token or color
    local own = OBJECT_ROLE[font] or "text.highlight"
    if token == nil then return own end
    if GOLD_TOKEN[token] and own == "heading" then return "heading" end
    return TOKEN_ROLE[token] or token
end

--- Paint `fs` through the skin: its color from `color` (a live table or a token name) and the face
--- of its role, recorded by the library so a skin switch repaints it. A label already painted the
--- same way is left alone, so a 4 Hz redraw calls nothing (`force` paints it again: a caller that
--- set another font object on it since). `font` is the object it was made in (default the one
--- Style.Text or Style.PlainText made it in).
--- @param fs table
--- @param color table|string
--- @param font string|nil
--- @param force boolean|nil
function Style.Paint(fs, color, font, force)
    if type(color) == "table" and not color.token then return Style.Hue(fs, color, force) end
    local role = Style.Role(font or fontOf[fs], color)
    if painted[fs] == role and not force then return end
    painted[fs] = role
    NS.Skin.Text(fs, role)
    -- The same color by the host's hand too, kept in `tinted` so a switch tints it again: the
    -- degraded facade's Text is a no-op, and the color must not wait on the library's replay.
    local token = ROLE_TOKEN[role] or role
    tinted[fs] = token
    tint(fs, token)
end

local SkinLib = LibStub and LibStub("LibKa0s-Skin-1.0", true)

--- Color `fs` with a DATA hue `c` ({ r, g, b }, no token: a class color, a race length's or a
--- category's hue, skinning rung 4), the same under every skin. The label keeps the skin's body face
--- (S.Font) and gives up any role it was painted in, so a skin switch never puts a role's color back
--- over the hue.
--- @param fs table
--- @param c table
function Style.Hue(fs, c, force)
    if painted[fs] ~= "hue" or force then
        if painted[fs] and SkinLib then SkinLib:Untrack(fs) end
        painted[fs], tinted[fs] = "hue", nil
        NS.Skin.Font(fs)
    end
    fs:SetTextColor(c[1], c[2], c[3])
end

--- A FontString in `font` (a Style.FONT value), never wrapping, painted through the skin: `color`
--- (a live table from Style.Tok, or a token name) recolors it; nil keeps the font object's own role.
--- @param parent table
--- @param font string  a font object's name
--- @param color table|string|nil
--- @param justify string|nil  "LEFT" (default) | "CENTER" | "RIGHT"
--- @return table
function Style.Text(parent, font, color, justify)
    font = font or Style.FONT.TEXT
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fontOf[fs] = font
    Style.Paint(fs, color, font)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- The scaled copies of the font objects, by "<font>@<scale>": a font object's name, or false where the
-- client has no CreateFont (the string then carries the size itself).
local scaledFonts = {}

--- A named copy of `font` at `scale` times its Style.FONT_SIZE height, or nil. Named, so the skin's
--- Ignore fonts puts a string back on THIS object, at the scaled size, rather than on the stock one.
local function scaledFont(font, scale)
    local key = font .. "@" .. scale
    if scaledFonts[key] == nil then
        scaledFonts[key] = false
        local base, size = rawget(_G, font), Style.FONT_SIZE[font]
        if size and type(CreateFont) == "function" and type(base) == "table" and base.GetFont then
            local name = ("DpsRace_%s_%d"):format(font, math.floor(scale * 100 + 0.5))
            local obj = CreateFont(name)
            if type(obj) == "table" then
                if obj.CopyFontObject then obj:CopyFontObject(base) end
                local path, _, flags = base:GetFont()
                obj:SetFont(path or STANDARD_TEXT_FONT, size * scale, flags or "")
                scaledFonts[key] = name
            end
        end
    end
    return scaledFonts[key] or nil
end

--- Style.Text at `scale` times `font`'s height (Style.FONT_SIZE): the same role and color, so the skin
--- paints it as it paints Style.Text, keeping the scale (its face's size is read off the string). Used
--- where a whole surface is drawn larger, the new-best toast (DR-04).
--- @param parent table
--- @param font string  a Style.FONT value that Style.FONT_SIZE names
--- @param scale number
--- @param color table|string|nil
--- @param justify string|nil
--- @return table
function Style.ScaledText(parent, font, scale, color, justify)
    font = font or Style.FONT.TEXT
    local obj = scaledFont(font, scale)
    local fs = parent:CreateFontString(nil, "OVERLAY", obj or font)
    local size = Style.FONT_SIZE[font]
    if not obj and size then
        local path, _, flags = fs:GetFont()
        fs:SetFont(path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size * scale, flags or "")
    end
    fontOf[fs] = font
    Style.Paint(fs, color, font)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

--- A FontString in `font` the skin never paints: a HUD Appearance block owns its face and color
--- (modules/Hud_Appearance.lua), and a recorded S.Text would put the skin's face back over the
--- player's on every switch.
function Style.PlainText(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or Style.FONT.TEXT)
    fontOf[fs] = font or Style.FONT.TEXT
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

--- The texture markup for a catalog icon tinted `color`, at the line's height, with a Blizzard
--- fallback when the catalog cannot answer (an inline texture ignores its FontString's color, so the
--- tint is in the markup: LootHistory's sort arrows).
--- @param name string  a catalog icon this addon declares
--- @param fallback string  a texture path the client always has
--- @param color table  a live color table (Style.Tok); markup is a string, so a caller that keeps it
---                     builds it again in a Style.OnLooks repaint
--- @return string
function Style.IconMarkup(name, fallback, color)
    local path = NS.Icon(name) or fallback
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|T%s:0:0:0:0:64:64:0:64:0:64:%d:%d:%d|t"):format(path, byte(color[1]), byte(color[2]), byte(color[3]))
end

-- ── tooltip bodies ──────────────────────────────────────────────────────────────────────────────
-- BULLETS FROM TWO LINES ON (the owner's call, 2026-10-26): every tooltip the addon draws itself puts
-- each line under its title on a bullet once there are two or more of them, a dim footer hint
-- included; a single line stays plain. Each line keeps its own color. Only the addon's own lines come
-- through here: the client's spell and item text (SetSpellByID, SetItemByID, SetHyperlink) never does.

Style.BULLET = "\226\128\162 "

--- The bullet `lines[first..]` take: Style.BULLET for two or more, "" for one.
--- @param lines table
--- @param first number
--- @return string
function Style.TipBullet(lines, first)
    return #lines - first >= 1 and Style.BULLET or ""
end

--- Add `lines[first..]` to `tip`, each a string (in `r, g, b`, the skin's `gtip.body` without) or
--- { text, r, g, b }, wrapped, on a bullet when there are two or more.
--- @param tip table  GameTooltip
--- @param lines table
--- @param first number
--- @param r number|nil
--- @param g number|nil
--- @param b number|nil
function Style.AddTipLines(tip, lines, first, r, g, b)
    local bullet = Style.TipBullet(lines, first)
    if r == nil then r, g, b = Style.Rgb("gtip.body") end
    for i = first, #lines do
        local l = lines[i]
        if type(l) == "table" then tip:AddLine(bullet .. tostring(l[1]), l[2] or r, l[3] or g, l[4] or b, true)
        else tip:AddLine(bullet .. tostring(l), r, g, b, true) end
    end
end

-- ── the title-bar controls ──────────────────────────────────────────────────────────────────────
-- ONE CONTROL AT A TIME (MultiMeters' HeaderControls). A strip remembers which control the pointer
-- is on; an enter names it and repaints the strip, a leave un-names it ONLY IF IT IS STILL THE ONE
-- NAMED: frames leave in no guaranteed order, so a leave arriving after the next control's enter
-- must not take the gold off the control the pointer is on now. Full alpha in both states.

local function paintControl(b, c)
    if b.icon then b.icon:SetVertexColor(c[1], c[2], c[3], 1) end
    if b.stroke then b.stroke:SetVertexColor(c[1], c[2], c[3], 1) end
    if b.glyph then b.glyph:SetTextColor(c[1], c[2], c[3], 1) end
end

--- Repaint every control of `strip` for the control under the pointer.
--- @param strip table  Style.NewStrip's
function Style.PaintStrip(strip)
    for _, b in ipairs(strip.controls) do paintControl(b, strip.hovered == b and Style.GOLD or Style.REST) end
end

local strips = setmetatable({}, { __mode = "k" })

--- A strip of title-bar controls sharing one hover state, repainted on a skin change.
--- @return table strip  { controls = {}, hovered = nil }
function Style.NewStrip()
    local strip = { controls = {} }
    strips[strip] = true
    return strip
end

Style.OnLooks(function() for strip in pairs(strips) do Style.PaintStrip(strip) end end)

--- Add `b` to `strip`: hooked (never replacing a script the control already has, such as the close
--- control's own tint, which this repaints after) so it turns gold under the pointer.
--- @param strip table
--- @param b table  a control with an `icon` texture and/or a `glyph` FontString (and a second
---                  texture, `stroke`, tinted with the icon: the timeline's `+`)
--- @return table b
function Style.AddToStrip(strip, b)
    if not b then return nil end
    strip.controls[#strip.controls + 1] = b
    local hook = b.HookScript and "HookScript" or "SetScript"
    b[hook](b, "OnEnter", function()
        strip.hovered = b
        Style.PaintStrip(strip)
    end)
    b[hook](b, "OnLeave", function()
        if strip.hovered == b then strip.hovered = nil end
        Style.PaintStrip(strip)
    end)
    paintControl(b, Style.REST)
    return b
end

--- A title-bar control drawn from the shared catalog, a plain character beneath it when the catalog
--- cannot answer (standalone-windows), with its tooltip. Its tint is the strip's (AddToStrip).
--- @param parent table
--- @param name string  the catalog icon
--- @param glyph string  the plain character drawn when there is no icon
--- @param tip string  the tooltip
--- @param onClick function
--- @return table
function Style.ControlButton(parent, name, glyph, tip, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(Style.CONTROL, Style.CONTROL)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.icon:SetSize(12, 12)
    b.glyph = b:CreateFontString(nil, "OVERLAY", Style.FONT.TEXT)
    b.glyph:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.tip = tip
    Style.SetControlIcon(b, name, glyph)
    b:SetScript("OnClick", function() onClick() end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.tip, Style.Rgb("gtip.value"))
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
end

--- Draw `name` on a control (the glyph when the catalog has no path). The tint is left as it is.
function Style.SetControlIcon(b, name, glyph)
    local path = NS.Icon(name)
    b.icon:SetShown(path ~= nil)
    b.glyph:SetShown(path == nil)
    if path then b.icon:SetTexture(path) else b.glyph:SetText(glyph) end
    b.iconName = name
end
