local _, NS = ...
-- modules/Results_InsightsCharts.lua — the Insights tab's drawing half (#12): the pooled chart widgets
-- (bars, stacked bars, strip columns, list rows, legend chips), the section chrome (headings, dividers,
-- list panels, stat cards) and the render* methods the tab's layout walks. modules/Results_Insights.lua
-- lays the sections out; modules/Results_InsightsData.lua computes what they show.
--
-- PORTED FROM LOOTHISTORY at commit 2319fd6: the factories and renderers from
-- modules/AnalyticsCharts.lua, the layout constants and pure helpers from modules/AnalyticsFormat.lua.
-- The names are LootHistory's, so a later promotion into LibKa0s can diff the two copies (DpsRace is
-- the second consumer of these shapes, and the owner named BankLedger as a third: docs/ARCHITECTURE.md,
-- Documented deviations, library-stack-§7). What the port changed:
--   - No skin. LootHistory reads every color from its skin tokens and repaints on a skin switch
--     (Analytics:Reskin); here the colors come from the host and are painted once per bind.
--   - The renderers are methods on a context made by Charts.New(content, host), not on a module
--     singleton, and the factories take that context.
--   - truncate counts UTF-8 glyphs, not bytes (character names carry "â").
--   - The rows are not written: a bar section scales each row by the longest, in place of
--     LootHistory's normalizing `row.frac` in the caller's table.
--   - A row may carry its own `tip` (a string, or lines: a title, then strings), in place of the
--     label and value; a strip column its own `color`; a list row an `onClick`. renderStrip takes an
--     optional fixed top.
--   - A divider's title takes a larger font object from the host, not 1.5x the size read back.
--   - Added: a stat card (Results_Detail.lua's kpi() shape) and setCard; dropped: the per-character
--     companion and its stack builder (LootHistory's own data shape: the caller builds the rows).
--
-- HOST-AGNOSTIC (the owner's S-7 answer, 2026-10-28). Nothing above the host section at the end of
-- this file reads NS or a client global but CreateFrame: the colors, the font objects, the tooltip,
-- the panel and the pool all come from the one host config table handed to Charts.New:
--   host.pool     a pool API: New(), Acquire(pool, factory), ReleaseAll(pool) (LibKa0s-Pool-1.0's)
--   host.panel    function(parent) -> a bordered frame (list panels, cards); a plain frame without
--   host.tip      function(owner, lines, anchor): show `lines` (a title, then strings) at `anchor`
--   host.hideTip  function()
--   host.colors   { body, value, muted, heading, caption, rule, track, bar, axis } as { r, g, b[, a] }
--   host.fonts    { label, axis, heading, divider, panelTitle, caption, figure }: font object names
--   host.palette  the ranked palette, a list of { r, g, b }
-- Any color, font or palette left out takes LootHistory's Ka0s Default value. tests/test_insights.lua
-- fails on an NS read above the host section. Charts.Host() is DpsRace's own table.
--
-- POOLED. Every widget a render draws comes from a pool the context names (ctx:Pool(name)), and
-- ctx:ReleaseAll() parks them all, so a layout pass after the first builds no frame.

local Charts = {}
NS.InsightsCharts = Charts

-- ── constants (AnalyticsFormat.lua's, plus the names the port's literals got) ───────────────────

local K = {
    BAR_H = 16, BAR_GAP = 3, SECTION_GAP = 16,
    HEADER_H = 18,          -- a section heading's line, above its first bar
    TRACK_GAP = 6,          -- between a bar's label column and its track
    DAYSTRIP_H = 46,
    STRIP_LABEL_H = 44,     -- reserved space under a strip for the rotated x-axis labels
    STRIP_AXIS_GAP = 2,     -- gap between the column bases and the separator line
    STRIP_LABEL_GAP = 7,    -- gap between the separator line and the label text
    LABEL_X_ADJUST = -2,    -- nudge to visually center the rotated label under the column
    STRIP_BAR_MAX = 14,     -- a strip column's widest
    STRIP_LABEL_PITCH = 11, -- the least room between two axis labels; closer ones are thinned out
    LIST_ROW_H = 16, LIST_MAX = 10,
    LIST_TITLE_H = 20,      -- a list panel's title band, above its first row
    LABELW = 108, VALW = 92,   -- fixed label/value columns in a horizontal bar; the track fills the rest
    LABEL_MAXCHARS = 16,    -- cap a bar or row label to this many glyphs (+ ellipsis) so it fits LABELW
    LEGEND_MAXCHARS = 13,   -- cap a legend chip's label to this many glyphs (+ ellipsis) to fit the chip
    MAX_STACK_SEGS = 9,     -- segment ceiling per stacked bar
    CHIP_W = 120, CHIP_H = 14, LEGEND_ROW_H = 16,
    DIVIDER_H = 26,
    CARD_H = 46,            -- Results_Detail.lua's KPI_H
    MIN_HEADLINE_SIZE = 11, -- floor for a card's shrink-to-fit figure
}
Charts.K = K

local ELLIPSIS = "\226\128\166"

-- Ka0s Default's values (LibKa0s SkinDefs.lua, the tokens LootHistory's charts read), for any color,
-- font or palette a host leaves out.
local DEFAULT_COLORS = {
    body = { 0.9, 0.9, 0.9 }, value = { 0.8, 0.8, 0.82 }, muted = { 0.7, 0.7, 0.72 },
    heading = { 1, 0.82, 0 }, caption = { 0.5, 0.5, 0.5 }, rule = { 1, 0.82, 0, 0.35 },
    track = { 1, 1, 1, 0.06 }, bar = { 0.40, 0.60, 0.95, 0.9 }, axis = { 0.45, 0.45, 0.5, 0.8 },
}
local DEFAULT_FONTS = {
    label = "GameFontHighlightSmall", axis = "GameFontDisableSmall", heading = "GameFontNormal",
    divider = "GameFontNormalLarge", panelTitle = "GameFontNormalSmall", caption = "GameFontDisableSmall",
    figure = "GameFontNormalHuge",
}
-- LootHistory's ranked palette (chart.series): three seven-hue ramps, inverse VIBGYOR, so neighbors in
-- a sorted chart never share a hue.
local DEFAULT_PALETTE = {
    { 0.90, 0.25, 0.25 }, { 0.95, 0.55, 0.15 }, { 0.88, 0.82, 0.22 }, { 0.35, 0.75, 0.38 },
    { 0.28, 0.55, 0.90 }, { 0.42, 0.38, 0.82 }, { 0.72, 0.42, 0.86 },
    { 0.97, 0.58, 0.58 }, { 0.98, 0.76, 0.50 }, { 0.94, 0.90, 0.55 }, { 0.60, 0.87, 0.63 },
    { 0.58, 0.76, 0.97 }, { 0.68, 0.64, 0.92 }, { 0.86, 0.68, 0.94 },
    { 0.62, 0.18, 0.18 }, { 0.70, 0.40, 0.10 }, { 0.60, 0.56, 0.12 }, { 0.18, 0.52, 0.28 },
    { 0.15, 0.38, 0.66 }, { 0.28, 0.24, 0.58 }, { 0.50, 0.28, 0.62 },
}

-- ── the pure helpers ────────────────────────────────────────────────────────────────────────────

--- Cap `text` at `maxChars` glyphs with a trailing ellipsis. Counts UTF-8 glyphs, so a cut never
--- splits one.
--- @return string, boolean  the text, and whether it was cut
function Charts.truncate(text, maxChars)
    text = text == nil and "" or tostring(text)
    local n, cut = 0, nil
    for start in text:gmatch("()[^\128-\191][\128-\191]*") do
        n = n + 1
        if n == maxChars then cut = start end
    end
    if n <= maxChars then return text, false end
    return text:sub(1, cut - 1) .. ELLIPSIS, true
end

--- Hover text for a chart element: the FULL (untruncated) label plus the value it encodes, so a
--- tooltip always states the number as well as the name. Label-only when the element has no value.
function Charts.tipText(label, value)
    label = label or ""
    if value == nil or value == "" then return label end
    if label == "" then return tostring(value) end
    return label .. ":  " .. tostring(value)
end

--- Shrink a figure's font only when its rendered string would overflow, never under `minSize`.
function Charts.fitFontSize(stringWidth, maxWidth, baseSize, minSize)
    if not stringWidth or stringWidth <= 0 or stringWidth <= maxWidth then return baseSize end
    return math.max(minSize, baseSize * maxWidth / stringWidth)
end

local function merged(defaults, given)
    local out = {}
    for k, v in pairs(defaults) do out[k] = v end
    if type(given) == "table" then
        for k, v in pairs(given) do out[k] = v end
    end
    return out
end

local function paint(fs, c) fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
local function fillColor(tex, c, a) tex:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1) end

local function text(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function noop() end

local function plainPanel(parent)
    return CreateFrame("Frame", nil, parent, "BackdropTemplate")
end

-- ── the context ─────────────────────────────────────────────────────────────────────────────────

local Ctx = {}
Ctx.__index = Ctx

--- A chart context drawing into `content` through `host` (the header lists its fields).
--- @param content table  the frame every section anchors to
--- @param host table  the host config; `pool` is required
--- @return table
function Charts.New(content, host)
    if type(host) ~= "table" or type(host.pool) ~= "table" then
        error("InsightsCharts.New: host.pool is required", 2)
    end
    local palette = type(host.palette) == "table" and host.palette[1] and host.palette or DEFAULT_PALETTE
    return setmetatable({
        content = content, poolApi = host.pool, pools = {}, poolOrder = {},
        colors = merged(DEFAULT_COLORS, host.colors), fonts = merged(DEFAULT_FONTS, host.fonts),
        palette = palette, panel = host.panel or plainPanel,
        tip = host.tip or noop, hideTip = host.hideTip or noop,
    }, Ctx)
end

--- The pool called `name`, made on first ask. ReleaseAll parks every pool made here.
function Ctx:Pool(name)
    local pool = self.pools[name]
    if not pool then
        pool = self.poolApi.New()
        self.pools[name] = pool
        self.poolOrder[#self.poolOrder + 1] = pool
    end
    return pool
end

--- Park every pooled widget (a layout pass starts here).
function Ctx:ReleaseAll()
    for _, pool in ipairs(self.poolOrder) do self.poolApi.ReleaseAll(pool) end
end

function Ctx:acquire(pool, factory, parent)
    return self.poolApi.Acquire(pool, function() return factory(self, parent or self.content) end)
end

--- Show `tip` (a string, or lines: a title, then strings) for `owner`; nothing for an empty one.
function Ctx:showTip(owner, tip, anchor)
    if tip == nil or tip == "" then return end
    if type(tip) ~= "table" then tip = { tostring(tip) } end
    self.tip(owner, tip, anchor or "ANCHOR_CURSOR_RIGHT")
end

--- The palette color at 1-based `rank` (cycles).
function Ctx:paletteColor(rank)
    return self.palette[((rank - 1) % #self.palette) + 1]
end

--- { key -> palette color } by position in `orderedKeys`, so a key keeps one color across charts.
function Ctx:paletteMap(orderedKeys)
    local m = {}
    for i, k in ipairs(orderedKeys or {}) do m[k] = self:paletteColor(i) end
    return m
end

-- A frame whose hover shows its `_tip`.
local function hoverable(ctx, f, anchor)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self2) ctx:showTip(self2, self2._tip, anchor) end)
    f:SetScript("OnLeave", function() ctx.hideTip() end)
end

-- ── the factories ───────────────────────────────────────────────────────────────────────────────

-- A horizontal bar row's frame: fixed label (left) + value (right), the track between them.
local function barFrame(ctx, parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(K.BAR_H)
    bar.label = text(bar, ctx.fonts.label, "LEFT")
    bar.track = bar:CreateTexture(nil, "BACKGROUND")
    fillColor(bar.track, ctx.colors.track)
    bar.value = text(bar, ctx.fonts.label, "RIGHT")
    hoverable(ctx, bar)
    return bar
end

local function makeBar(ctx, parent)
    local bar = barFrame(ctx, parent)
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    return bar
end

-- A single horizontal bar split into colored segments. Each segment is a mouse-enabled frame (not a
-- bare texture) so it carries its own hover; its texture fills it.
local function makeStackedBar(ctx, parent)
    local bar = barFrame(ctx, parent)
    bar.segs = {}
    for i = 1, K.MAX_STACK_SEGS do
        local seg = CreateFrame("Frame", nil, bar)
        seg.tex = seg:CreateTexture(nil, "ARTWORK")
        seg.tex:SetAllPoints(seg)
        hoverable(ctx, seg)
        bar.segs[i] = seg
    end
    return bar
end

-- One vertical column in a strip, with its rotated axis label under the strip's axis line.
local function makeStripBar(ctx, parent)
    local f = CreateFrame("Frame", nil, parent)
    f.fill = f:CreateTexture(nil, "ARTWORK")
    f.fill:SetPoint("BOTTOM", 0, 0)
    f.axis = text(f, ctx.fonts.axis, "LEFT")
    f.axis:SetRotation(math.pi / 2)
    paint(f.axis, ctx.colors.muted)
    hoverable(ctx, f, "ANCHOR_TOP")
    return f
end

-- A ranked-list row: name (left) + count or value (right). A click goes to the row's `_onClick`.
local function makeListRow(ctx, parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(K.LIST_ROW_H)
    r.name = text(r, ctx.fonts.label, "LEFT")
    r.name:SetPoint("LEFT", 4, 0)
    r.count = text(r, ctx.fonts.label, "RIGHT")
    r.count:SetPoint("RIGHT", -4, 0)
    hoverable(ctx, r)
    r:SetScript("OnMouseUp", function(self2, button)
        if self2._onClick then self2._onClick(self2, button) end
    end)
    return r
end

-- A legend chip: color swatch + label.
local function makeSwatch(ctx, parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(K.CHIP_H)
    f.sw = f:CreateTexture(nil, "ARTWORK")
    f.sw:SetSize(10, 10)
    f.sw:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.fs = text(f, ctx.fonts.label, "LEFT")
    f.fs:SetPoint("LEFT", f.sw, "RIGHT", 4, 0)
    paint(f.fs, ctx.colors.value)
    hoverable(ctx, f)
    return f
end

-- ── the chrome ──────────────────────────────────────────────────────────────────────────────────

--- A section heading in the heading font and color; the caller (or a renderer) places it.
function Ctx:sectionHeader(parent, title)
    local fs = text(parent or self.content, self.fonts.heading, "LEFT")
    fs:SetText(title)
    paint(fs, self.colors.heading)
    return fs
end

--- A full-width divider: a centered title flanked by two rules. The caller anchors its TOPLEFT.
function Ctx:sectionDivider(parent, title)
    local f = CreateFrame("Frame", nil, parent or self.content)
    f:SetHeight(K.DIVIDER_H)
    local fs = text(f, self.fonts.divider, "CENTER")
    fs:SetPoint("CENTER", f, "CENTER", 0, 0)
    paint(fs, self.colors.heading)
    fs:SetText(title)
    local rules = {}
    for i = 1, 2 do
        rules[i] = f:CreateTexture(nil, "ARTWORK")
        fillColor(rules[i], self.colors.rule)
        rules[i]:SetHeight(1.25)
    end
    -- The rules fill the space either side of the centered title (an 8px gap).
    rules[1]:SetPoint("LEFT", f, "LEFT", 0, 0)
    rules[1]:SetPoint("RIGHT", fs, "LEFT", -8, 0)
    rules[2]:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    rules[2]:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.fs, f.rules = fs, rules
    return f
end

--- A list panel: the host's panel with its title in the heading color.
function Ctx:listPanel(parent, title)
    local p = self.panel(parent or self.content)
    local t = text(p, self.fonts.panelTitle, "LEFT")
    t:SetPoint("TOPLEFT", 6, -5)
    paint(t, self.colors.heading)
    t:SetText(title)
    p.title = t
    return p
end

--- A strip's frame (the columns and the axis line hang off it).
function Ctx:strip(parent)
    return CreateFrame("Frame", nil, parent or self.content)
end

--- A stat card: a small caption over a large figure, on the host's panel (Results_Detail.lua's
--- kpi()). Its hover states the figure (setCard).
--- @return table  { frame, label, value, caption }
function Ctx:card(parent, caption, color)
    local f = self.panel(parent or self.content)
    f:SetHeight(K.CARD_H)
    local label = text(f, self.fonts.caption, "LEFT")
    paint(label, self.colors.caption)
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
    label:SetText(caption)
    local value = text(f, self.fonts.figure, "LEFT")
    paint(value, color or self.colors.body)
    value:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 5)
    hoverable(self, f)
    return { frame = f, label = label, value = value, caption = caption }
end

-- Shrink `fs` to fit `maxW` (its font object's own size when it fits).
local function fitFigure(fs, maxW)
    local file, size, flags = fs:GetFont()
    if type(size) ~= "number" then return end
    local fit = Charts.fitFontSize(fs:GetStringWidth(), maxW, size, K.MIN_HEADLINE_SIZE)
    if fit ~= size then fs:SetFont(file, fit, flags) end
end

--- Set a card's figure and its hover (`tip`, else "caption: figure"); `maxW` shrinks an overflowing
--- figure to fit.
function Ctx:setCard(card, value, tip, maxW)
    card.value:SetFontObject(self.fonts.figure)
    card.value:SetText(value)
    card.frame._tip = tip or Charts.tipText(card.caption, value)
    if maxW then fitFigure(card.value, maxW) end
end

-- ── the renderers ───────────────────────────────────────────────────────────────────────────────

-- Place a section's heading at the cursor and return the cursor under it.
function Ctx:placeHeader(header, y, pad)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", self.content, "TOPLEFT", pad, y)
    header:Show()
    return y - K.HEADER_H
end

-- Lay out a bar row's label, value and track; returns the track's width.
local function placeTrack(bar, content, pad, y, barW)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
    bar:SetWidth(barW)
    bar.label:ClearAllPoints(); bar.label:SetPoint("LEFT", 0, 0); bar.label:SetWidth(K.LABELW)
    bar.value:ClearAllPoints(); bar.value:SetPoint("RIGHT", 0, 0); bar.value:SetWidth(K.VALW)
    local trackW = math.max(1, barW - K.LABELW - K.VALW - 12)
    bar.track:ClearAllPoints()
    bar.track:SetPoint("LEFT", K.LABELW + K.TRACK_GAP, 0)
    bar.track:SetSize(trackW, K.BAR_H - 4)
    return trackW
end

-- A bar row's words: the truncated label in `labelColor`, the value, and the hover.
function Ctx:bindBarText(bar, row, labelColor)
    bar._tip = row.tip or Charts.tipText(row.label, row.value)
    bar.label:SetText((Charts.truncate(row.label, K.LABEL_MAXCHARS)))
    paint(bar.label, labelColor)
    bar.value:SetText(row.value)
    paint(bar.value, self.colors.value)
end

local function longest(rows)
    local top = 0
    for _, row in ipairs(rows) do
        if (row.frac or 0) > top then top = row.frac end
    end
    return top
end

--- A horizontal-bar section: the heading, then one bar per row, the longest filling the track. rows:
--- ordered { label, color = {r,g,b}, labelColor = {r,g,b}|nil, frac (>= 0), value = string, tip }.
--- The label takes its bar's color unless the row gives one, so single bars are self-legending.
--- `legendPool` (optional) draws a legend of the rows under the bars. Skipped when rows is empty.
--- @return number  the cursor under the section
function Ctx:renderBarSection(pool, header, rows, y, w, pad, legendPool)
    if #rows == 0 then header:Hide(); return y end
    local top = longest(rows)
    y = self:placeHeader(header, y, pad)
    for _, row in ipairs(rows) do
        local bar = self:acquire(pool, makeBar)
        fillColor(bar.fill, row.color, 0.95)
        self:bindBarText(bar, row, row.labelColor or row.color)
        local trackW = placeTrack(bar, self.content, pad, y, w - pad * 2)
        local frac = top > 0 and (row.frac or 0) / top or 0
        bar.fill:ClearAllPoints()
        bar.fill:SetPoint("LEFT", bar.track, "LEFT", 0, 0)
        bar.fill:SetSize(math.max(1, trackW * math.min(1, frac)), K.BAR_H - 4)
        y = y - (K.BAR_H + K.BAR_GAP)
    end
    if legendPool then
        local leg = {}
        for i, row in ipairs(rows) do leg[i] = { label = row.label, color = row.color, value = row.value } end
        return self:renderLegend(legendPool, leg, y, w, pad)
    end
    return y - K.SECTION_GAP
end

-- Lay a stacked bar's segments along its track, hiding the unused ones.
local function placeSegments(bar, trackW, segments)
    local x = 0
    for i = 1, #bar.segs do
        local seg, sd = bar.segs[i], segments[i]
        if sd and sd.frac and sd.frac > 0 then
            local segW = math.max(1, trackW * math.min(1, sd.frac))
            seg:ClearAllPoints()
            seg:SetPoint("LEFT", bar.track, "LEFT", x, 0)
            seg:SetSize(segW, K.BAR_H - 4)
            fillColor(seg.tex, sd.color, 0.95)
            seg._tip = sd.tip
            seg:Show()
            x = x + segW
        else
            seg:Hide()
        end
    end
end

--- A section of horizontal STACKED bars. rows: ordered { label, labelColor|nil, value, tip,
--- segments = { { frac (0..1 of the track), color = {r,g,b}, tip }, ... } }. The fracs are already
--- relative to the longest row (the caller divides by the largest total). Skipped when rows is empty.
--- @return number  the cursor under the section
function Ctx:renderStackedBarSection(pool, header, rows, y, w, pad)
    if #rows == 0 then header:Hide(); return y end
    y = self:placeHeader(header, y, pad)
    for _, row in ipairs(rows) do
        local bar = self:acquire(pool, makeStackedBar)
        self:bindBarText(bar, row, row.labelColor or self.colors.body)
        placeSegments(bar, placeTrack(bar, self.content, pad, y, w - pad * 2), row.segments or {})
        y = y - (K.BAR_H + K.BAR_GAP)
    end
    return y - K.SECTION_GAP
end

--- A wrapped legend of swatch + label chips, starting at the track's left edge (under the bars, not
--- their labels). rows: { { label, color = {r,g,b}, value|nil } }. A long label is cut with an
--- ellipsis; the hover shows it whole, with the value.
--- @return number  the cursor under the legend
function Ctx:renderLegend(pool, rows, y, w, pad)
    local x0 = pad + K.LABELW + K.TRACK_GAP
    local x, rowY = x0, y
    for _, row in ipairs(rows) do
        if x + K.CHIP_W > w - pad then x = x0; rowY = rowY - K.LEGEND_ROW_H end
        local chip = self:acquire(pool, makeSwatch)
        fillColor(chip.sw, row.color, 0.95)
        chip._tip = row.tip or Charts.tipText(row.label, row.value)
        chip.fs:SetWidth(K.CHIP_W - 16)
        chip.fs:SetText((Charts.truncate(row.label, K.LEGEND_MAXCHARS)))
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, rowY)
        chip:SetWidth(K.CHIP_W)
        x = x + K.CHIP_W
    end
    return rowY - K.LEGEND_ROW_H - K.SECTION_GAP
end

-- A strip column's rotated label: its top a gap below the axis line, hanging straight down, so
-- labels of different lengths all start at the line; centered on the column.
local function placeAxisLabel(f, label, barW)
    if not label then
        f.axis:SetText("")
        f.axis:Hide()
        return
    end
    f.axis:SetText(label)
    local tw = f.axis:GetStringWidth() or 0
    f.axis:ClearAllPoints()
    f.axis:SetPoint("CENTER", f, "BOTTOMLEFT", barW / 2 + K.LABEL_X_ADJUST,
        -(tw / 2) - K.STRIP_AXIS_GAP - K.STRIP_LABEL_GAP)
    f.axis:Show()
end

-- The axis line under a strip's columns, spanning the strip a small gap below their bases.
function Ctx:placeAxisLine(strip)
    strip.axisLine = strip.axisLine or strip:CreateTexture(nil, "ARTWORK")
    fillColor(strip.axisLine, self.colors.axis)
    strip.axisLine:ClearAllPoints()
    strip.axisLine:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, -K.STRIP_AXIS_GAP)
    strip.axisLine:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, -K.STRIP_AXIS_GAP)
    strip.axisLine:SetHeight(1)
    strip.axisLine:Show()
end

local function tallest(buckets, top)
    if top then return top end
    top = 1
    for _, b in ipairs(buckets) do
        if b.count > top then top = b.count end
    end
    return top
end

--- A strip of vertical columns, one per bucket: { count, label|nil, info (the hover: a string or
--- lines), color|nil }. A column's height is its count over `top` (the largest count, at least 1,
--- when nil); a zero column is a faint stub. Labels thin out when the columns crowd.
--- @return number  the cursor under the strip and its labels
function Ctx:renderStrip(pool, header, strip, buckets, y, w, pad, top)
    if #buckets == 0 then header:Hide(); strip:Hide(); return y end
    y = self:placeHeader(header, y, pad)
    local innerW = w - pad * 2
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", self.content, "TOPLEFT", pad, y)
    strip:SetSize(innerW, K.DAYSTRIP_H)
    strip:Show()
    local slot = innerW / #buckets
    local barW = math.max(2, math.min(K.STRIP_BAR_MAX, slot - 2))
    local stride = math.max(1, math.ceil(K.STRIP_LABEL_PITCH / slot))
    top = tallest(buckets, top)
    self:placeAxisLine(strip)
    for i, b in ipairs(buckets) do
        local f = self:acquire(pool, makeStripBar, strip)
        f:SetParent(strip)
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", (i - 1) * slot, 0)
        f:SetSize(barW, K.DAYSTRIP_H)
        f.fill:SetSize(barW, math.max(1, math.min(1, b.count / top) * (K.DAYSTRIP_H - 2)))
        fillColor(f.fill, b.color or self.colors.bar)
        f.fill:SetAlpha(b.count == 0 and 0.12 or 0.9)
        f._tip = b.info
        placeAxisLabel(f, (i - 1) % stride == 0 and b.label or nil, barW)
    end
    return y - K.DAYSTRIP_H - K.STRIP_LABEL_H - K.SECTION_GAP
end

--- A ranked list panel. rows: { name, nameColor = {r,g,b}|nil, right (string), tip, onClick }, capped
--- at ten. `rightW` sizes the value column (48 without). A row's click is its own: a reused row
--- forgets the last one's.
--- @return number  the panel's height
function Ctx:renderListPanel(pool, panel, rows, y, colW, pad, rightW)
    rightW = rightW or 48
    local n = math.min(K.LIST_MAX, #rows)
    local panelH = K.LIST_TITLE_H + math.max(n, 1) * K.LIST_ROW_H + 4
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", self.content, "TOPLEFT", pad, y)
    panel:SetSize(colW, panelH)
    panel:Show()
    for i = 1, n do
        local row = rows[i]
        local r = self:acquire(pool, makeListRow, panel)
        r:SetParent(panel)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -K.LIST_TITLE_H - (i - 1) * K.LIST_ROW_H)
        r:SetWidth(colW - 8)
        r.name:SetWidth(math.max(1, colW - 8 - rightW - 6))
        r.name:SetText(row.name)
        paint(r.name, row.nameColor or self.colors.body)
        r.count:SetWidth(rightW)
        r.count:SetText(row.right)
        paint(r.count, self.colors.value)
        r._tip = row.tip or Charts.tipText(row.name, row.right)
        r._onClick = row.onClick
    end
    return panelH
end

-- ── the DpsRace host ────────────────────────────────────────────────────────────────────────────
-- The one part of this file that reads NS (at CALL time): the Results window's look as a host table.
-- A promotion into LibKa0s leaves this section behind, and each consumer keeps its own.

-- A gold title over the lines, bulleted from two (Style.AddTipLines), by the cursor.
local function cursorTip(owner, lines, anchor)
    local tip = GameTooltip
    if not tip then return end
    local gold = NS.Style.GOLD
    tip:SetOwner(owner, anchor)
    tip:SetText(lines[1], gold[1], gold[2], gold[3], 1, true)
    NS.Style.AddTipLines(tip, lines, 2)
    tip:Show()
end

--- The host table for DpsRace's Results window: NS.Pool, the window's flat panel, its tooltip, its
--- colors (modules/Results_Table.lua's COLORS) and font objects (modules/Style.lua's FONT). The ranked
--- palette is the default. The meaning colors (class, category, length) are the rows' own, chosen by
--- the caller.
--- @return table
function Charts.Host()
    local Style, Tbl = NS.Style, NS.ResultsTable
    local C, F = Tbl.COLORS, Style.FONT
    return {
        pool = NS.Pool,
        panel = function(parent) return Tbl.Panel(parent) end,
        tip = cursorTip,
        hideTip = Tbl.HideTip,
        colors = {
            body = C.text, value = C.text, muted = C.dim, heading = C.gold, caption = C.dim,
            rule = { C.gold[1], C.gold[2], C.gold[3], 0.35 }, bar = C.blue,
        },
        fonts = {
            label = F.TEXT, axis = F.CAPTION, heading = F.SECTION, divider = F.SECTION,
            panelTitle = F.HEADER, caption = F.CAPTION, figure = F.FIGURE,
        },
    }
end
