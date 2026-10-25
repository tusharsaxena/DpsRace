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
    NAME    = "GameFontHighlightLarge",  -- the character name heading the run detail (white, 16px)
    CAPTION = "GameFontDisableSmall",    -- footers, KPI captions, hints, axis labels (gray)
    FIGURE  = "GameFontNormalHuge",      -- a KPI figure (recolored by its caller)
    EMPTY   = "GameFontDisableLarge",    -- an empty list's message
}

-- Blizzard's header gold (NORMAL_FONT_COLOR): the title, the column headers, the active tab, the
-- sort arrows and a hovered title-bar control are all this one color.
Style.GOLD = { 1.0, 0.82, 0.0 }
-- A title-bar control at rest: the close control's own gray (LibKa0s-Core-1.0 MakeCloseButton).
Style.REST = { 0.7, 0.7, 0.72 }
-- An idle tab's label (LootHistory's tabIdle).
Style.TAB_IDLE = { 0.7, 0.7, 0.72 }

-- The title bar, the tab strip and a control slot (LootHistory and BankLedger: titleBarH 30,
-- tabStripH 26, 90px tabs on a 94px pitch; the close control's 18px slot).
Style.TITLE_BAR_H = 30
Style.TAB_STRIP_H = 26
Style.TAB_W, Style.TAB_PITCH = 90, 94
Style.CONTROL = 18
Style.CONTROL_PITCH = 22

--- A FontString in `font` (a Style.FONT value), never wrapping. `color` recolors it; nil keeps the
--- font object's own color.
--- @param parent table
--- @param font string  a font object's name
--- @param color table|nil  { r, g, b }
--- @param justify string|nil  "LEFT" (default) | "CENTER" | "RIGHT"
--- @return table
function Style.Text(parent, font, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or Style.FONT.TEXT)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

--- The texture markup for a catalog icon tinted `color`, at the line's height, with a Blizzard
--- fallback when the catalog cannot answer (an inline texture ignores its FontString's color, so the
--- tint is in the markup: LootHistory's sort arrows).
--- @param name string  a catalog icon this addon declares
--- @param fallback string  a texture path the client always has
--- @param color table  { r, g, b }
--- @return string
function Style.IconMarkup(name, fallback, color)
    local path = NS.Icon(name) or fallback
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|T%s:0:0:0:0:64:64:0:64:0:64:%d:%d:%d|t"):format(path, byte(color[1]), byte(color[2]), byte(color[3]))
end

-- ── the title-bar controls ──────────────────────────────────────────────────────────────────────
-- ONE CONTROL AT A TIME (MultiMeters' HeaderControls). A strip remembers which control the pointer
-- is on; an enter names it and repaints the strip, a leave un-names it ONLY IF IT IS STILL THE ONE
-- NAMED: frames leave in no guaranteed order, so a leave arriving after the next control's enter
-- must not take the gold off the control the pointer is on now. Full alpha in both states.

local function paintControl(b, c)
    if b.icon then b.icon:SetVertexColor(c[1], c[2], c[3], 1) end
    if b.glyph then b.glyph:SetTextColor(c[1], c[2], c[3], 1) end
end

--- Repaint every control of `strip` for the control under the pointer.
--- @param strip table  Style.NewStrip's
function Style.PaintStrip(strip)
    for _, b in ipairs(strip.controls) do paintControl(b, strip.hovered == b and Style.GOLD or Style.REST) end
end

--- A strip of title-bar controls sharing one hover state.
--- @return table strip  { controls = {}, hovered = nil }
function Style.NewStrip()
    return { controls = {} }
end

--- Add `b` to `strip`: hooked (never replacing a script the control already has, such as the close
--- control's own tint, which this repaints after) so it turns gold under the pointer.
--- @param strip table
--- @param b table  a control with an `icon` texture and/or a `glyph` FontString
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
        GameTooltip:SetText(self.tip, 1, 1, 1)
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
