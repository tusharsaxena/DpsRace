local _, NS = ...
-- modules/Results_Table.lua — the Results window's sortable list (spec §6.2): a header of sort
-- controls over a pooled, scrolling set of row buttons, the Runs tab's; and the
-- small helpers the window draws a run with (class and spec icons, the class color, the category badge,
-- the flag texts, the dates).
--
-- POOLED AND VIRTUAL. Only the rows that fit are drawn (LibKa0s-Pool, events-frames-taint-§6): a
-- scroll re-binds the same row frames to the next slice of the sorted list. A row never holds a run
-- of its own beyond the one it is bound to now.
--
-- LAYOUT FROM CONFIG. Every column has a configured width (one column takes what is left), every row
-- is placed from its index, and no size or position is ever read back off a frame. The window never
-- shows a meter value (only stored, plain run records), but it keeps the HUD's rule all the same.
--
-- SORTING IS ON STORED NUMBERS. A run's figures went through NS.Secrets on their way into the store,
-- so comparing them is plain Lua. A missing value sorts last whichever way the column runs; a tie
-- falls to the newer run, then the id, so the order never depends on pairs().

local Tbl = {}
NS.ResultsTable = Tbl

local L = NS.L
local Style = NS.Style
local FONT = Style.FONT

-- Compact rows under a 20px header, as LootHistory's list draws them (BrowserTable: 18px rows).
Tbl.ROW_H = 18
Tbl.HEADER_H = 20
Tbl.PAD = 6                 -- the gap between two cells, and the row's inner margin
Tbl.SCROLLBAR_W = 8
Tbl.ICON = 16
Tbl.WHEEL_ROWS = 3          -- rows one notch of the mouse wheel moves

local WHITE = "Interface\\Buttons\\WHITE8x8"
Tbl.WHITE = WHITE
-- The list's stripe: every other row faintly tinted (the skin's `dr.list.stripe`); the detail's spell
-- rows share it.
Tbl.StripeAlpha = Style.StripeAlpha
Tbl.Stripe = Style.Stripe
local CLASS_ATLAS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

-- The window's palette. The chrome and meaning colors are the HUD's live skin colors
-- (modules/Hud_States.lua). Blue and the four status hues are DATA hues (skinning rung 4: "each
-- status a distinct color", the owner's call, 2026-10-25), the same under every skin.
local HC = NS.HudStates.COLORS
local C = {
    text  = HC.text,
    dim   = HC.dim,
    gold  = Style.GOLD,
    amber = HC.amber,
    green = HC.green,
    red   = HC.red,
    blue  = { 0.40, 0.66, 1.0 },
    -- The Status tags' own hues (the owner's call, 2026-10-25: each status a distinct color).
    violet = { 0.74, 0.47, 1.0 },
    orange = { 1.0, 0.58, 0.16 },
    pink   = { 1.0, 0.42, 0.72 },
    slate  = { 0.55, 0.58, 0.64 },
}
Tbl.COLORS = C
local BADGE_ICON = 11       -- an icon inside a badge (the Status column's tags)
Tbl.BADGE_ICON = BADGE_ICON

-- The race length colors (the owner's call, 2026-10-25): the five preset lengths
-- (NS.HudStates.PRESETS) in muted ROYGBIV hues, shortest to longest, and any other length a neutral
-- gray. The Results window's only: the HUD never draws a length in these.
Tbl.LENGTH_COLORS = {
    [30]  = { 0.86, 0.52, 0.52 },   -- soft red
    [60]  = { 0.88, 0.67, 0.46 },   -- soft orange
    [120] = { 0.86, 0.81, 0.52 },   -- soft yellow
    [180] = { 0.56, 0.80, 0.58 },   -- soft green
    [300] = { 0.58, 0.66, 0.92 },   -- soft indigo
}
Tbl.LENGTH_NEUTRAL = { 0.76, 0.76, 0.80 }

-- The category badge colors (mockup screens 08-09): one hue per catalog category.
Tbl.CATEGORY_COLORS = {
    single     = { 0.56, 0.72, 1.0 },
    cleave     = { 1.0, 0.72, 0.29 },
    dungeoneer = { 1.0, 0.45, 0.45 },
    boss       = { 0.75, 0.55, 1.0 },
    pvp        = { 0.36, 0.86, 0.46 },
    other      = { 0.62, 0.62, 0.68 },
}

-- ── the run, as the window draws it ─────────────────────────────────────────────────────────────

--- A FontString in one of the shared font objects (modules/Style.lua: Style.FONT), recolored when
--- `color` is given, never wrapping.
Tbl.Text = Style.Text
Tbl.FONT = FONT

--- A flat panel (the HUD's, modules/Hud_States.lua): the skin's Panel, or its Card or Inset (`kind`),
--- the slots remapped to `tokens` ({ bg =, border = } token names; default the faint wash and edge).
Tbl.Panel = NS.HudStates.Panel

--- The class color, else the window's text color.
function Tbl.ClassColor(class)
    local colors = RAID_CLASS_COLORS
    local c = type(colors) == "table" and type(class) == "string" and colors[class]
    if type(c) == "table" and type(c.r) == "number" then return { c.r, c.g, c.b } end
    return C.text
end

--- The class's localized name, else its token.
function Tbl.ClassName(class)
    local names = LOCALIZED_CLASS_NAMES_MALE
    local name = type(names) == "table" and type(class) == "string" and names[class]
    if type(name) == "string" then return name end
    return class and tostring(class) or L["Unknown class"]
end

--- Draw `class`'s icon on `tex` from the character-creation atlas; hidden when it is unknown.
function Tbl.SetClassIcon(tex, class)
    local coords = type(CLASS_ICON_TCOORDS) == "table" and type(class) == "string" and CLASS_ICON_TCOORDS[class]
    if type(coords) ~= "table" then
        tex:Hide()
        return false
    end
    tex:SetTexture(CLASS_ATLAS)
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    tex:Show()
    return true
end

--- A spec's name and icon through GetSpecializationInfoByID, with the run's own name beneath it.
--- @return string|nil name, any icon
function Tbl.SpecInfo(specID, fallbackName)
    local api = GetSpecializationInfoByID
    if type(specID) == "number" and type(api) == "function" then
        local ok, _, name, _, icon = pcall(api, specID)
        if ok and type(name) == "string" then return name, icon end
    end
    return fallbackName, nil
end

--- A race length's color (Tbl.LENGTH_COLORS): a preset's hue, else the neutral gray. Plain numbers
--- off a stored run only.
--- @param seconds number|nil
--- @return table color
function Tbl.LengthColor(seconds)
    return type(seconds) == "number" and Tbl.LENGTH_COLORS[seconds] or Tbl.LENGTH_NEUTRAL
end

--- A color as the "aarrggbb" hex an inline |c escape takes.
--- @param color table  { r, g, b }
--- @return string
function Tbl.Hex(color)
    return ("ff%02x%02x%02x"):format(math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5),
        math.floor(color[3] * 255 + 0.5))
end

--- The category badge, "Cleave", and its color.
--- @return string text, table color
function Tbl.Badge(target)
    target = type(target) == "table" and target or {}
    local category = NS.Dummies.CategoryOf(target)
    return NS.Dummies.Label(category), Tbl.CATEGORY_COLORS[category] or Tbl.CATEGORY_COLORS.other
end

-- The flags a run carries beyond its status: incomplete and lost are what the DPS column says.
local STATUS_FLAGS = { incomplete = true, lost = true }

--- The run's flags as full text (spell names through C_Spell), its status flags left out.
--- @return table texts
function Tbl.FlagTexts(run)
    local out = {}
    for _, flag in ipairs(NS.Scoring.Flags(run, NS.HudBreakdown.SpellName)) do
        if not STATUS_FLAGS[flag.key] then out[#out + 1] = flag.text end
    end
    return out
end

--- A run's date in `fmt` (os.date's), or "" when it has none.
function Tbl.Date(t, fmt)
    if type(t) ~= "number" or type(date) ~= "function" then return "" end
    local ok, s = pcall(date, fmt, t)
    return ok and s or ""
end

--- An item level to one decimal, or a dash.
function Tbl.Ilvl(v)
    if type(v) ~= "number" then return "\226\128\148" end
    return ("%.1f"):format(v)
end

-- ── tooltips ────────────────────────────────────────────────────────────────────────────────────
-- ONE HOVER PER ROW, NOT A SPOT PER CELL: the row follows the cursor across its cells (its OnUpdate,
-- only while hovered) and shows the tooltip of the cell under it (NS.ResultsTips). The tooltip sits
-- beside the WINDOW at the row's height, on its right (LootHistory's), or on its left when the
-- screen has no room for it there. Nothing here holds a meter value, so the geometry read is free.

-- The top-level window a table sits in (the frame whose parent is UIParent).
local function windowOf(frame)
    local w = frame
    while w and w.GetParent do
        local p = w:GetParent()
        if p == nil or p == UIParent then return w end
        w = p
    end
    return frame
end

Tbl.WindowOf = windowOf

-- Lines from `first` on, each a string (light gray) or { text, r, g, b }, on bullets from two lines
-- on (modules/Style.lua).
local addLines = Style.AddTipLines

-- A geometry answer as a plain number, or nil: the HUD's live spell rows (DR-03) hand this file a
-- tooltip that may show a secret spell, and a frame that shows a secret answers secret geometry, which
-- no arithmetic or comparison may touch (core/Secrets.lua). Every read here goes through it.
local function plainGeom(frame, method)
    local fn = frame and frame[method]
    if type(fn) ~= "function" then return nil end
    return NS.Secrets.PlainNumber(fn(frame))
end

-- The shown tooltip beside `window`, level with `row`: its right, or its left without the room. A
-- geometry read that is not plain counts as nothing (level with the window's top, no width).
local function placeSide(tip, window, row)
    local dy = 0
    local rowTop, winTop = plainGeom(row, "GetTop"), plainGeom(window, "GetTop")
    if rowTop and winTop then dy = rowTop - winTop end
    local scale = plainGeom(window, "GetEffectiveScale") or 1
    local right = (plainGeom(window, "GetRight") or 0) * scale
    local room = (plainGeom(UIParent, "GetRight") or 0) * (plainGeom(UIParent, "GetEffectiveScale") or 1)
    local width = (plainGeom(tip, "GetWidth") or 0) * (plainGeom(tip, "GetEffectiveScale") or 1)
    tip:ClearAllPoints()
    if right + width + 4 <= room then
        tip:SetPoint("TOPLEFT", window, "TOPRIGHT", 4, dy)
    else
        tip:SetPoint("TOPRIGHT", window, "TOPLEFT", -4, dy)
    end
end

--- Show `lines` ({ title, line, ... }; a line is a string or { text, r, g, b }) beside `window`,
--- level with `row`.
function Tbl.SideTip(window, row, lines)
    local tip = GameTooltip
    if not tip or type(lines) ~= "table" or not lines[1] then return end
    tip:SetOwner(window, "ANCHOR_NONE")
    local r, g, b = Style.Rgb("gtip.title")
    tip:SetText(lines[1], r, g, b, 1, true)
    addLines(tip, lines, 2)
    tip:Show()
    placeSide(tip, window, row)
end

--- The client's own tooltip for spell `id`, then `lines` (each a string or { text, r, g, b }), placed
--- as SideTip places its. A spell the client cannot show gets its name instead. `id` may be SECRET
--- (the HUD's live spell rows, DR-03): it is only tested for nil, handed to the client's SetSpellByID
--- (pcall'd) and to the name lookup, never compared or type-tested, and the placement reads plain
--- geometry only.
function Tbl.SpellTip(window, row, id, lines)
    local tip = GameTooltip
    if not tip then return end
    tip:SetOwner(window, "ANCHOR_NONE")
    local shown = id ~= nil and tip.SetSpellByID and pcall(tip.SetSpellByID, tip, id)
    if shown and tip.NumLines then shown = (plainGeom(tip, "NumLines") or 0) > 0 end
    if not shown then
        local r, g, b = Style.Rgb("gtip.value")
        tip:SetText(NS.HudBreakdown.SpellName(id), r, g, b, 1, true)
    end
    if type(lines) == "table" and lines[1] then
        tip:AddLine(" ")
        addLines(tip, lines, 1)
    end
    tip:Show()
    placeSide(tip, window, row)
end

--- `lines` (a title, then strings or { text, r, g, b }) under `owner`, the column headers' way.
function Tbl.BelowTip(owner, lines)
    local tip = GameTooltip
    if not tip or type(lines) ~= "table" or not lines[1] then return end
    tip:SetOwner(owner, "ANCHOR_BOTTOM")
    local r, g, b = Style.Rgb("gtip.title")
    tip:SetText(lines[1], r, g, b, 1, true)
    addLines(tip, lines, 2)
    tip:Show()
end

local function hideTip()
    if GameTooltip then GameTooltip:Hide() end
end
Tbl.HideTip = hideTip

-- ── cells ───────────────────────────────────────────────────────────────────────────────────────

local Cells = {}

-- A text cell; a column with `bar` also draws a fill under its text, as long as its value's place
-- between the smallest and the largest in the list (Table:SetData, Tbl.BarShare), over the row's own
-- stripe (no track and no border: the owner's call, 2026-10-25). Its look is the column's
-- `barStyle(run)`: { texture, r, g, b, a, font = a resolved font }.
function Cells.text(row, col)
    local cell = { fs = Tbl.Text(row, FONT.TEXT, C.text, col.justify) }
    if col.bar then
        cell.bar = row:CreateTexture(nil, "BORDER", nil, 2)
        cell.bar:SetTexture(WHITE)
    end
    return cell
end

-- The class and spec icons, each with a hover naming it.
function Cells.icons(row)
    local cell = { class = row:CreateTexture(nil, "ARTWORK"), spec = row:CreateTexture(nil, "ARTWORK") }
    cell.class:SetSize(Tbl.ICON, Tbl.ICON)
    cell.spec:SetSize(Tbl.ICON, Tbl.ICON)
    return cell
end

-- A row of small icons (the Runs list's Used column, #13): as many as the column's configured width
-- holds (Tbl.IconsFit), each its own part (cell.icon1, ...) so a group header's showCells hides it,
-- then "+n" for the rest, or a dash when there is nothing.
function Cells.items(row, col)
    local cell = { more = Tbl.Text(row, FONT.TEXT, C.dim), dash = Tbl.Text(row, FONT.TEXT, C.dim) }
    cell.dash:SetText("\226\128\148")
    cell.slots = Tbl.IconSlots(col.width)
    for i = 1, cell.slots do
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(Tbl.ICON, Tbl.ICON)
        cell["icon" .. i] = icon
    end
    return cell
end

-- A tag: its icon (where the column names one) before its word, both in the tag's color, in a 1px box
-- tinted the tag's color, its icon inside (the Status, Target and Time columns: the owner's calls,
-- 2026-10-25). A column whose text returns chips draws up to that many more boxed chips after the tag (no column
-- uses it today); a `trail` column draws plain text after the last box (the Time column's tail).
function Cells.badge(row, col)
    local cell = { box = Style.FlatBox(row) }
    cell.box:SetHeight(Tbl.CHIP_H)
    cell.fs = Tbl.Text(cell.box, FONT.TEXT, C.amber, "CENTER")
    cell.fs:SetPoint("CENTER", cell.box, "CENTER", 0, 0)
    cell.icon = cell.box:CreateTexture(nil, "ARTWORK")
    cell.icon:SetSize(BADGE_ICON, BADGE_ICON)
    cell.icon:SetPoint("LEFT", cell.box, "LEFT", 4, 0)
    cell.icon:Hide()
    -- Each chip a part of its own (cell.chip1, ...), so a group header's showCells hides it too.
    cell.chipCount = col.chips or 0
    for i = 1, cell.chipCount do cell["chip" .. i] = Tbl.Chip(row) end
    if col.trail then cell.trail = Tbl.Text(row, FONT.TEXT, C.dim) end
    return cell
end

local function paint(fs, color)
    Style.Paint(fs, color or C.text)
end

-- A box's tint: its edge and a faint fill in `color`.
local function tint(box, color)
    Style.TintBox(box, color, Style.BADGE_EDGE_A)
end

-- ── chips ───────────────────────────────────────────────────────────────────────────────────────
-- A chip is a boxed badge with no icon: a 1px box tinted its color around its word in that color.
-- The Runs list's Target and Time cells and Status boards and the detail's header draw one. Its width is Tbl.BadgeWidth's (config, never measured).

Tbl.CHIP_H = 16
Tbl.CHIP_GAP = 4            -- the gap between two boxes, and between a box and the text after it

--- A chip in `parent`, hidden until Tbl.SetChip paints it. `scale` (the new-best toast's, DR-04) draws
--- it that much larger: its height, its word's size and its width.
function Tbl.Chip(parent, scale)
    local chip = Style.FlatBox(parent)
    chip.scale = scale
    chip:SetHeight(Tbl.CHIP_H * (scale or 1))
    chip.fs = scale and Style.ScaledText(chip, FONT.TEXT, scale, C.text, "CENTER")
        or Tbl.Text(chip, FONT.TEXT, C.text, "CENTER")
    chip.fs:SetPoint("CENTER", chip, "CENTER", 0, 0)
    chip:Hide()
    return chip
end

--- Paint `chip` with `s` in `color` and size it (Tbl.BadgeWidth, boxed), never wider than `maxW`
--- when given (its word is cut to the box). Hidden for "" or nil.
--- @return number width  0 when hidden
function Tbl.SetChip(chip, s, color, maxW)
    local on = type(s) == "string" and s ~= ""
    chip:SetShown(on)
    if not on then return 0 end
    color = color or C.text
    chip.fs:SetText(s)
    paint(chip.fs, color)
    tint(chip, color)
    local w = math.floor(Tbl.BadgeWidth(s, true) * (chip.scale or 1) + 0.5)
    if type(maxW) == "number" and w > maxW then w = math.max(14, math.floor(maxW)) end
    chip:SetWidth(w)
    chip.fs:SetWidth(w - 6)
    chip.text, chip.color, chip.w = s, color, w
    return w
end

--- A race length as its chip: "2:00" and its length color (Tbl.LengthColor).
--- @return string text, table color
function Tbl.LengthChip(length)
    return NS.Format.Length(length), Tbl.LengthColor(length)
end

--- The text after a run's time chip: the tail after the buzzer ("+9.1s"), or for a run that ended
--- before its buzzer the time combat ended ("at 1:04"); nil when there is neither. Plain numbers off
--- the stored run only.
--- @return string|nil
function Tbl.TimeTail(run)
    local result = type(run) == "table" and type(run.result) == "table" and run.result or {}
    if run.status == "incomplete" and type(result.endedAt) == "number" then
        return L["at %s"]:format(NS.Format.Length(result.endedAt))
    end
    local tail = result.tail
    if type(tail) ~= "number" or tail < 0.05 then return nil end
    return L["+%.1fs"]:format(tail)
end

local Bind = {}

Tbl.BAR_FLOOR = 0.10        -- the share of the cell the smallest value in the list draws at

--- A bar's share of its cell: linear from the list's smallest value (Tbl.BAR_FLOOR) to its largest
--- (1). One value, or every value equal, draws full; a value that is not a number draws nothing (0).
--- @return number share  0, or BAR_FLOOR..1
function Tbl.BarShare(v, min, max)
    if type(v) ~= "number" or type(min) ~= "number" or type(max) ~= "number" then return 0 end
    if max <= min then return 1 end
    local t = math.max(0, math.min(1, (v - min) / (max - min)))
    return Tbl.BAR_FLOOR + (1 - Tbl.BAR_FLOOR) * t
end

-- The bar's width: the cell's, times the run's share (Tbl.BarShare) between its group's smallest and
-- largest value (Table:measure). Plain numbers off stored runs, and the cell's width is the column
-- layout's, never a measured one.
local function bindBar(cell, col, run)
    local range = col.barRanges and col.barRanges[col.groupOf and col.groupOf(run) or true] or {}
    local share = Tbl.BarShare(col.bar(run), range.min, range.max)
    local on = share > 0
    local style = col.barStyle and col.barStyle(run)
    if style then
        cell.bar:SetTexture(style.texture or WHITE)
        cell.bar:SetVertexColor(style.r, style.g, style.b, style.a)
        -- A dash (no figure) keeps the column's muted color; a figure takes the bar text's.
        if style.font and NS.HudAppearance then NS.HudAppearance.ApplyFont(cell.fs, style.font, nil, not on) end
    end
    cell.bar:SetShown(on)
    if on then cell.bar:SetWidth(math.max(1, math.floor((cell.barW or 0) * share + 0.5))) end
end

function Bind.text(cell, col, run)
    local s, color = col.text(run)
    cell.fs:SetText(s or "")
    paint(cell.fs, color)
    if cell.bar then bindBar(cell, col, run) end
end

Tbl.ICON_GAP = 2            -- between two icons of an items cell

--- How many icons an items cell `width` px wide holds (at least one). Pure.
function Tbl.IconSlots(width)
    return math.max(1, math.floor(((width or 0) + Tbl.ICON_GAP) / (Tbl.ICON + Tbl.ICON_GAP)))
end

--- How many of `count` icons an items cell `width` px wide draws, and the "+n" after them: all of
--- them when they fit, else one slot fewer than fit and the rest counted in the last slot. Pure.
--- @return number shown, number more
function Tbl.IconsFit(count, width)
    local slots = Tbl.IconSlots(width)
    if count <= slots then return count, 0 end
    return slots - 1, count - (slots - 1)
end

-- The column's `items(run)` answers the icons ({ texture, ... }), or nil: a dash for none.
function Bind.items(cell, col, run)
    local list = col.items(run) or {}
    local shown, more = Tbl.IconsFit(#list, col.width)
    for i = 1, cell.slots do
        local icon = cell["icon" .. i]
        icon:SetShown(i <= shown)
        if i <= shown then icon:SetTexture(list[i]) end
    end
    cell.dash:SetShown(#list == 0)
    cell.more:SetShown(more > 0)
    cell.more:SetText(more > 0 and ("+" .. more) or "")
    if more > 0 then
        cell.more:ClearAllPoints()
        cell.more:SetPoint("LEFT", cell.icon1 or cell.dash, "LEFT", shown * (Tbl.ICON + Tbl.ICON_GAP), 0)
    end
end

function Bind.icons(cell, col, run)
    local char = run.char or {}
    local specName, specIcon = Tbl.SpecInfo(char.specID, char.spec)
    Tbl.SetClassIcon(cell.class, char.class)
    cell.spec:SetTexture(specIcon)
    cell.spec:SetShown(specIcon ~= nil)
    cell.specName = specName
    if col.after then col.after(cell, run) end
end

--- A badge's width from its label's length (config, never a measured width): 6 px a character (a
--- UTF-8 continuation byte adds none: "·" is one), 4 px of pad (14 in a box), plus `extra` for an
--- icon. Pure; the fit tests size columns against it.
--- @param s string
--- @param boxed boolean|nil
--- @param extra number|nil
--- @return number
function Tbl.BadgeWidth(s, boxed, extra)
    local chars = select(2, s:gsub("[^\128-\191]", ""))
    return math.floor(chars * 6 + (boxed and 14 or 4) + (extra or 0))
end

--- Set a checkbox's label (`check.label`, 1px right of the box) and widen its click area over it, so
--- a click on the words toggles it too (the owner's call, 2026-10-26). The width is the label's
--- estimate (Tbl.BadgeWidth's 6 px a character), never a measured one. `extra` px more lie between
--- the box and its words (the detail's Usage rows: an item's icon), and are clickable too. `width`
--- stands for the words' estimate when the text carries color escapes (a Usage row's dim detail).
function Tbl.SetCheckLabel(check, text, extra, width)
    text = text or ""
    check.label:SetText(text)
    check:SetHitRectInsets(0, -(1 + (extra or 0) + (width or Tbl.BadgeWidth(text, false))), 0, 0)
end

-- The tag's word beside its icon and the box's width (Tbl.BadgeWidth), never wider than the column,
-- with its tint on the box's edge and fill.
local function layoutBadge(cell, s, color, extra)
    cell.fs:ClearAllPoints()
    local w = Tbl.BadgeWidth(s, true, extra)
    if cell.w and w > cell.w then w = math.max(14, cell.w) end
    cell.fs:SetPoint("CENTER", cell.box, "CENTER", extra / 2, 0)
    cell.fs:SetWidth(math.max(1, w - 6 - extra))
    tint(cell.box, color)
    return w
end

-- The icon, tinted the tag's color, before the word: answers the room the word shifts right by.
local function bindIcon(cell, icon, color)
    local path = icon and NS.Icon(icon)
    cell.icon:SetShown(path ~= nil)
    if not path then return 0 end
    cell.icon:SetTexture(path)
    Style.Vertex(cell.icon, color, 1)
    return BADGE_ICON + 2
end

-- The chips after the tag's box, each { text, color }, left to right in what the column has left.
-- Answers the width used so far and the last box drawn (the trail sits after it).
local function bindChips(cell, chips, used)
    local last, gap = cell.box, Tbl.CHIP_GAP
    for i = 1, cell.chipCount do
        local chip, spec = cell["chip" .. i], chips and chips[i]
        local room = cell.w and (cell.w - used - gap) or nil
        local w = Tbl.SetChip(chip, spec and spec[1], spec and spec[2], room)
        if w > 0 then
            chip:ClearAllPoints()
            chip:SetPoint("LEFT", last, "RIGHT", gap, 0)
            used, last = used + gap + w, chip
        end
    end
    return used, last
end

function Bind.badge(cell, col, run)
    local s, color, icon, trail, chips = col.text(run)
    s = s or ""
    color = color or C.amber
    cell.fs:SetText(s)
    paint(cell.fs, color)
    cell.box:SetShown(s ~= "")
    local boxW = layoutBadge(cell, s, color, bindIcon(cell, icon, color))
    cell.box:SetWidth(boxW)
    local used, last = bindChips(cell, chips, boxW)
    if not cell.trail then return end
    -- The trail takes what the column has left after the last box (placeCell's width).
    cell.trail:ClearAllPoints()
    cell.trail:SetPoint("LEFT", last, "RIGHT", Tbl.CHIP_GAP, 0)
    cell.trail:SetText(trail or "")
    cell.trail:SetShown(trail ~= nil and trail ~= "")
    cell.trail:SetWidth(math.max(10, (cell.w or 0) - used - Tbl.CHIP_GAP))
end

-- Place one cell in its column, from the column's x and width alone.
local function placeCell(row, cell, col, x, w)
    local kind = col.kind or "text"
    if kind == "icons" then
        cell.class:ClearAllPoints()
        cell.class:SetPoint("LEFT", row, "LEFT", x, 0)
        cell.spec:ClearAllPoints()
        cell.spec:SetPoint("LEFT", row, "LEFT", x + Tbl.ICON + 3, 0)
    elseif kind == "badge" then
        cell.box:ClearAllPoints()
        cell.box:SetPoint("LEFT", row, "LEFT", x, 0)
        cell.w = w
    elseif kind == "items" then
        for i = 1, cell.slots do
            cell["icon" .. i]:ClearAllPoints()
            cell["icon" .. i]:SetPoint("LEFT", row, "LEFT", x + (i - 1) * (Tbl.ICON + Tbl.ICON_GAP), 0)
        end
        cell.dash:ClearAllPoints()
        cell.dash:SetPoint("LEFT", row, "LEFT", x, 0)
        cell.more:SetWidth(math.max(10, Tbl.ICON + 8))
    else
        cell.fs:ClearAllPoints()
        cell.fs:SetPoint("LEFT", row, "LEFT", x, 0)
        cell.fs:SetWidth(math.max(10, w))
        if cell.bar then
            -- The track spans the cell and a little of the gap each side; the text sits inside it.
            cell.w, cell.barW = w, w + 4
            cell.fs:ClearAllPoints()
            cell.fs:SetPoint("LEFT", row, "LEFT", x + 2, 0)
            cell.fs:SetWidth(math.max(10, w - 2))
            cell.bar:ClearAllPoints()
            cell.bar:SetPoint("TOPLEFT", row, "TOPLEFT", x - 2, -1)
            cell.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x - 2, 1)
        end
    end
end

-- ── the table ───────────────────────────────────────────────────────────────────────────────────

local Table = {}
Table.__index = Table

--- Column widths for `width`: each its configured width, the flex column what is left (never below
--- its minimum). Answers the x of each column and its width, in column order.
function Tbl.Columns(columns, width)
    local fixed, flex = 0, nil
    for _, col in ipairs(columns) do
        if col.flex then flex = col else fixed = fixed + col.width end
    end
    local inner = width - 2 * Tbl.PAD - Tbl.SCROLLBAR_W - Tbl.PAD * (#columns - 1)
    local out, x = {}, Tbl.PAD
    for i, col in ipairs(columns) do
        local w = col.width
        if col == flex then w = math.max(col.min or 40, inner - fixed) end
        out[i] = { x = x, w = w }
        x = x + w + Tbl.PAD
    end
    return out
end

-- The sort marks: the catalog's arrows inline after the label, tinted the skin's `icon.arrow` (an
-- inline texture ignores its FontString's color), Blizzard's arrows beneath them (LootHistory's).
-- Markup is a string, so both are built again on a skin change, by a listener registered here, ahead
-- of the one below that redraws every header (Style.OnLooks runs its listeners in registration order).
local ARROW_UP, ARROW_DOWN
local function buildArrows()
    local c = Style.Tok("icon.arrow")
    ARROW_UP = " " .. Style.IconMarkup("sort-up", "Interface\\Buttons\\Arrow-Up-Up", c)
    ARROW_DOWN = " " .. Style.IconMarkup("sort-down", "Interface\\Buttons\\Arrow-Down-Up", c)
end
buildArrows()
Style.OnLooks(buildArrows)

-- A column header: GameFontNormalSmall in the header gold, Title Case, the sort mark after its label.
local function newHeader(t, i, col)
    local b = CreateFrame("Button", nil, t.header)
    b:SetHeight(Tbl.HEADER_H)
    b.label = Tbl.Text(b, FONT.HEADER, Style.Tok("list.header.text"), col.justify)
    b.label:SetText(col.label or "")
    b.col = col
    if col.sort then
        b:SetScript("OnClick", function() t:SetSort(col.key) end)
    end
    -- The header's tooltip (LootHistory's): the column's name in gold, then what it shows.
    b:SetScript("OnEnter", function(self)
        local about = NS.ResultsTips and NS.ResultsTips.About(col)
        if not (GameTooltip and about) then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(col.label ~= "" and col.label or about.title or "", Style.Rgb("gtip.title"))
        local r, g, bl = Style.Rgb("gtip.body")
        GameTooltip:AddLine(about.text, r, g, bl, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", hideTip)
    t.heads[i] = b
    return b
end

local function rowBackground(row)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetTexture(WHITE)
    row.sel = row:CreateTexture(nil, "BORDER")
    row.sel:SetAllPoints(row)
    Style.Fill(row.sel, "dr.list.sel")   -- the selection and hover washes: the list's own (D-5)
    row.sel:Hide()
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    Style.Fill(hl, "dr.list.hover")
end

local function newRow(t)
    local row = CreateFrame("Button", nil, t.body)
    row:SetHeight(Tbl.ROW_H)
    if row.RegisterForClicks then row:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    rowBackground(row)
    row.cells = {}
    for i, col in ipairs(t.columns) do
        row.cells[col.key] = Cells[col.kind or "text"](row, col)
        row.cells[i] = row.cells[col.key]
    end
    -- A group header (LootHistory's): its chevron, label and count across the row; a click folds it.
    row.groupLabel = Tbl.Text(row, FONT.HEADER, Style.GOLD)
    row.groupLabel:SetPoint("LEFT", row, "LEFT", Tbl.PAD, 0)
    row.groupLabel:Hide()
    -- Left: select (a header folds its group). Right: the row's menu (LootHistory's).
    row:SetScript("OnClick", function(self, button)
        if self.group then return t:ToggleCollapse(self.group.key) end
        if not self.run then return end
        if button == "RightButton" then
            if t.onRightClick then t.onRightClick(self.run, self) end
            return
        end
        if t.onClick then t.onClick(self.run) end
    end)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta) t:Scroll(delta) end)
    row:SetScript("OnEnter", function(self)
        self.tipCol = nil
        self:SetScript("OnUpdate", function(r) t:HoverCell(r) end)
        t:HoverCell(self)
    end)
    row:SetScript("OnLeave", function(self)
        self:SetScript("OnUpdate", nil)
        self.tipCol = nil
        hideTip()
    end)
    return row
end

-- Every list ever made (weakly held), for a skin change: its header's sort mark, whose markup was
-- built again.
local tables = setmetatable({}, { __mode = "k" })
Style.OnLooks(function() for t in pairs(tables) do t:paintHeader() end end)

local function buildScrollbar(t)
    local bar = CreateFrame("Slider", nil, t.frame)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(Tbl.SCROLLBAR_W)
    bar:SetPoint("TOPRIGHT", t.frame, "TOPRIGHT", -2, -Tbl.HEADER_H - 2)
    bar:SetPoint("BOTTOMRIGHT", t.frame, "BOTTOMRIGHT", -2, 2)
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    Style.Fill(thumb, "dr.scroll.thumb")
    thumb:SetSize(Tbl.SCROLLBAR_W - 2, 28)
    bar:SetThumbTexture(thumb)
    bar:SetScript("OnValueChanged", function(_, value)
        if t.syncing then return end
        t:ScrollTo(math.floor((value or 0) + 0.5))
    end)
    t.scrollbar = bar
end

--- A sortable, scrolling list in `parent` (which it fills).
--- @param parent table
--- @param columns table  { key, label, kind = "text"|"icons"|"badge" (chips, trail)|"items" (items =
---                         fn(run) -> textures), width | flex+min, tip = fn(run) -> lines, about = header text,
---                         justify, sort = fn(run) -> value, desc = default direction, text = fn(run),
---                         bar = fn(run) -> value, barStyle = fn(run),
---                         scan = fn(list, groupOf) on SetData and SetGroup (Table:measure) }
--- @param opts table  { sortKey, sortDesc, onClick(run), onRightClick(run, row), empty = text,
---                      stripe = false for uniform rows (default: every other row faintly tinted) }
function Tbl.New(parent, columns, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    local t = setmetatable({
        frame = frame, columns = columns, heads = {}, pool = NS.Pool.New(), shown = {},
        data = {}, rows = {}, offset = 0, width = 600, height = 300,
        sortKey = opts.sortKey, sortDesc = opts.sortDesc ~= false,
        onClick = opts.onClick, onRightClick = opts.onRightClick, stripe = opts.stripe ~= false,
    }, Table)
    t.header = CreateFrame("Frame", nil, frame)
    t.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    t.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    t.header:SetHeight(Tbl.HEADER_H)
    local line = t.header:CreateTexture(nil, "ARTWORK")
    NS.Skin.Divider(line)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", t.header, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", t.header, "BOTTOMRIGHT", 0, 0)
    for i, col in ipairs(columns) do newHeader(t, i, col) end
    t.body = CreateFrame("Frame", nil, frame)
    t.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -Tbl.HEADER_H)
    t.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    t.body:EnableMouseWheel(true)
    t.body:SetScript("OnMouseWheel", function(_, delta) t:Scroll(delta) end)
    t.empty = Tbl.Text(t.body, FONT.EMPTY, nil, "CENTER")
    t.empty:SetPoint("TOP", t.body, "TOP", 0, -24)
    t.empty:SetText(opts.empty or "")
    buildScrollbar(t)
    t:paintHeader()
    tables[t] = true
    return t
end

function Table:column(key)
    for _, col in ipairs(self.columns) do if col.key == key then return col end end
end

--- The sort mark the header shows now: "" off the sorted column, else the direction's arrow.
function Table:SortMark(key)
    if key ~= self.sortKey then return "" end
    return self.sortDesc and ARROW_DOWN or ARROW_UP
end

function Table:paintHeader()
    for _, b in ipairs(self.heads) do
        b.label:SetText((b.col.label or "") .. self:SortMark(b.col.key))
    end
end

-- `a` before `b` under (key, desc): a missing value last, a tie to the newer run, then the id.
local function comparator(col, desc)
    local value = col.sort
    return function(a, b)
        local va, vb = value(a), value(b)
        if va ~= vb then
            if va == nil then return false end
            if vb == nil then return true end
            if desc then return va > vb end
            return va < vb
        end
        local da, db = a.date or 0, b.date or 0
        if da ~= db then return da > db end
        return tostring(a.id) > tostring(b.id)
    end
end

--- `list` sorted (a new array) by column `key`, descending when `desc`.
function Tbl.Sort(columns, list, key, desc)
    local out = {}
    for i, run in ipairs(list or {}) do out[i] = run end
    local col
    for _, c in ipairs(columns) do if c.key == key then col = c end end
    if col and col.sort then table.sort(out, comparator(col, desc)) end
    return out
end

--- Sort by `key`: the same column again flips the direction; a new one starts at its own default.
function Table:SetSort(key, desc)
    local col = self:column(key)
    if not (col and col.sort) then return end
    -- The grouped column's header orders the groups, as in LootHistory.
    if self.grouping and self.grouping.column == key and desc == nil then
        self.groupDesc = not self.groupDesc
        self.rows = self:group(Tbl.Sort(self.columns, self.data or {}, self.sortKey, self.sortDesc))
        return self:Bind()
    end
    if desc ~= nil then
        self.sortDesc = desc and true or false
    elseif key == self.sortKey then
        self.sortDesc = not self.sortDesc
    else
        self.sortDesc = col.desc ~= false
    end
    self.sortKey = key
    self:paintHeader()
    self.rows = self:group(Tbl.Sort(self.columns, self.data, self.sortKey, self.sortDesc))
    self:Bind()
end

--- The key of the group `run` falls in under `spec` (Table:SetGroup's shape), as Table:group keys
--- it; `true` for every run of a flat list, which is one group.
function Tbl.GroupKey(spec, run)
    if not spec then return true end
    return tostring((spec.of(run)))
end

-- Measure the list per group (the owner's call, 2026-10-26). Each bar column's scale is the
-- smallest and the largest value in the run's own group: every run of it the filters pass, folded or
-- scrolled out of view or not. A column that reads the whole list (the Runs list's Delta) sees it
-- here, with the grouping's key, before a sort. A flat list is one group. Nothing is stored on a
-- run: it is redone on every SetData and SetGroup.
function Table:measure()
    local spec = self.grouping
    local function groupOf(run) return Tbl.GroupKey(spec, run) end
    for _, col in ipairs(self.columns) do
        if col.scan then col.scan(self.data, groupOf) end
        if col.bar then
            col.groupOf = groupOf
            local ranges = {}
            for _, run in ipairs(self.data) do
                local v = col.bar(run)
                if type(v) == "number" then
                    local key = groupOf(run)
                    local r = ranges[key]
                    if not r then
                        r = { min = v, max = v }
                        ranges[key] = r
                    end
                    if v < r.min then r.min = v end
                    if v > r.max then r.max = v end
                end
            end
            col.barRanges = ranges
        end
    end
end

--- Replace the list (any order) and redraw it sorted, keeping the scroll where it can.
function Table:SetData(list)
    self.data = list or {}
    self:measure()
    self.rows = self:group(Tbl.Sort(self.columns, self.data, self.sortKey, self.sortDesc))
    self:Bind()
end

-- ── grouping (LootHistory's BrowserTableGroup) ─────────────────────────────────────────────────
-- With a grouping set, the sorted runs are partitioned into groups in first-seen order, the groups
-- ordered by their own rank (ascending; a click on the grouped column's header flips it), and each
-- group is preceded by a header entry { group = { key, label, count, collapsed } }. A collapsed group
-- emits only its header. The row sort still holds inside each group.

--- Group by `spec` ({ of = fn(run) -> key, label, rank; column = the column key it corresponds to,
--- or nil }), or nil for a flat list. Redraws.
function Table:SetGroup(spec)
    if spec ~= self.grouping then self.groupDesc = false end
    self.grouping = spec
    self:measure()
    self.rows = self:group(Tbl.Sort(self.columns, self.data or {}, self.sortKey, self.sortDesc))
    self:Bind()
end

--- Fold or unfold the group with `key`.
function Table:ToggleCollapse(key)
    self.collapsed = self.collapsed or {}
    self.collapsed[key] = (not self.collapsed[key]) or nil
    self.rows = self:group(Tbl.Sort(self.columns, self.data or {}, self.sortKey, self.sortDesc))
    self:Bind()
end

function Table:group(sorted)
    local spec = self.grouping
    if not spec then return sorted end
    self.collapsed = self.collapsed or {}
    local order, byKey = {}, {}
    for _, run in ipairs(sorted) do
        local key, label, rank = spec.of(run)
        key = tostring(key)
        local g = byKey[key]
        if not g then
            g = { key = key, label = label or key, rank = rank or label or key, runs = {} }
            byKey[key] = g
            order[#order + 1] = g
        end
        g.runs[#g.runs + 1] = run
    end
    local desc = self.groupDesc
    table.sort(order, function(a, b)
        if a.rank ~= b.rank then
            if desc then return a.rank > b.rank end
            return a.rank < b.rank
        end
        return a.key < b.key
    end)
    local out = {}
    for _, g in ipairs(order) do
        local collapsed = self.collapsed[g.key] == true
        out[#out + 1] = { group = { key = g.key, label = g.label, count = #g.runs, collapsed = collapsed } }
        if not collapsed then
            for _, run in ipairs(g.runs) do out[#out + 1] = run end
        end
    end
    return out
end

--- The column under the cursor on `row`, or nil.
function Table:columnAt(row)
    if not (self.place and GetCursorPosition and row.GetLeft) then return nil end
    local cx = GetCursorPosition() / (row:GetEffectiveScale() or 1)
    local x = cx - (row:GetLeft() or 0)
    for c, spot in ipairs(self.place) do
        if x >= spot.x - Tbl.PAD / 2 and x < spot.x + spot.w + Tbl.PAD / 2 then return c end
    end
    return nil
end

--- The tooltip lines for `entry` (a run or a group header) in column `c`, or nil.
function Table:TipLines(entry, c)
    local Tips = NS.ResultsTips
    if not (Tips and entry) then return nil end
    if entry.group then return Tips.Group(entry.group) end
    local col = self.columns[c]
    return col and Tips.Cell(col, entry)
end

--- Show the tooltip of the cell under the cursor on `row`, when it changed column.
function Table:HoverCell(row)
    local entry = row.group and { group = row.group } or row.run
    local c = row.group and 0 or self:columnAt(row)
    if c == row.tipCol then return end
    row.tipCol = c
    local lines = c and self:TipLines(entry, c)
    if lines then Tbl.SideTip(windowOf(self.frame), row, lines) else hideTip() end
end

function Table:visibleCount()
    return math.max(1, math.floor((self.height - Tbl.HEADER_H) / Tbl.ROW_H))
end

function Table:maxOffset()
    return math.max(0, #self.rows - self:visibleCount())
end

--- Scroll so the list starts at `offset` (clamped).
function Table:ScrollTo(offset)
    offset = math.max(0, math.min(self:maxOffset(), math.floor(offset or 0)))
    if offset == self.offset then return end
    self.offset = offset
    self:Bind()
end

--- One mouse-wheel notch: `delta` > 0 scrolls up.
function Table:Scroll(delta)
    self:ScrollTo(self.offset - (delta or 0) * Tbl.WHEEL_ROWS)
end

--- Bring the run with `id` into view, if it is in the list.
function Table:Reveal(id)
    for i, run in ipairs(self.rows) do
        if run.group == nil and run.id == id then
            local first, count = self.offset + 1, self:visibleCount()
            if i < first then self:ScrollTo(i - 1) elseif i >= first + count then self:ScrollTo(i - count) end
            return true
        end
    end
    return false
end

--- Mark the run with `id` as the selected one.
function Table:SetSelected(id)
    self.selected = id
    for _, row in ipairs(self.shown) do row.sel:SetShown(row.run ~= nil and row.run.id == id) end
end

function Table:placeRow(row, i)
    local y = -(i - 1) * Tbl.ROW_H
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -Tbl.SCROLLBAR_W - 2, y)
    if row.layout == self.layoutVersion then return end
    row.layout = self.layoutVersion
    for c, col in ipairs(self.columns) do
        local spot = self.place[c]
        placeCell(row, row.cells[c], col, spot.x, spot.w)
    end
end

-- Every drawn part of a row's cells, shown or hidden at once (a header row draws none of them; a run
-- row shows them all and each Bind hides what it does not draw).
local function showCells(row, on)
    for _, cell in ipairs(row.cells) do
        for _, part in pairs(cell) do
            if type(part) == "table" and part.SetShown then part:SetShown(on) end
        end
    end
end

-- The disclosure marks: the catalog's chevrons, tinted the skin's `icon.arrow` (an inline texture
-- ignores its FontString's color), Blizzard's minus and plus beneath them; built again on a skin
-- change, as the sort marks are.
local CHEVRON_OPEN, CHEVRON_SHUT
local function buildChevrons()
    local c = Style.Tok("icon.arrow")
    CHEVRON_OPEN = Style.IconMarkup("chevron-down", "Interface\\Buttons\\UI-MinusButton-Up", c)
    CHEVRON_SHUT = Style.IconMarkup("chevron-right", "Interface\\Buttons\\UI-PlusButton-Up", c)
end
buildChevrons()
Style.OnLooks(buildChevrons)

local function bindHeader(row, g)
    row.run, row.group = nil, g
    row.sel:Hide()
    showCells(row, false)
    row.groupLabel:SetText(("%s  %s  %s(%d)|r"):format(g.collapsed and CHEVRON_SHUT or CHEVRON_OPEN,
        g.label, NS.SkinEscape("text.disabled") or "", g.count))
    row.groupLabel:Show()
end

function Table:bindRow(row, run, index)
    Style.Stripe(row.bg, self.stripe and index or 1)
    if run.group then return bindHeader(row, run.group) end
    row.run, row.index, row.group = run, index, nil
    row.groupLabel:Hide()
    showCells(row, true)
    row.sel:SetShown(self.selected ~= nil and run.id == self.selected)
    for c, col in ipairs(self.columns) do Bind[col.kind or "text"](row.cells[c], col, run) end
end

function Table:syncScrollbar()
    local bar, top = self.scrollbar, self:maxOffset()
    self.syncing = true
    bar:SetMinMaxValues(0, top)
    bar:SetValue(self.offset)
    self.syncing = false
    bar:SetShown(top > 0)
end

--- Redraw the visible slice from the pool.
---
--- A redraw can run inside another (the owner's first-drag overlap, 2026-10-27): the first row an open
--- shows can resolve the window's rect, and the client runs its OnSizeChanged right there, a full
--- layout and a Bind inside this one's Acquire. That inner Bind released this one's rows and drew the
--- whole slice; carrying on would draw a second set over it that the list does not hold, which the
--- next drag leaves where it was. So each Bind counts itself, and one that finds a newer Bind ran
--- inside it stops: the newer one's rows stand.
function Table:Bind()
    local pass = (self.binds or 0) + 1
    self.binds = pass
    self.offset = math.max(0, math.min(self.offset, self:maxOffset()))
    NS.Pool.ReleaseAll(self.pool, function(row) row.run, row.group = nil, nil end)
    self.shown, self.spare = {}, {}
    local count = math.min(self:visibleCount(), #self.rows - self.offset)
    for i = 1, count do
        local row = NS.Pool.Acquire(self.pool, function() return newRow(self) end)
        if self.binds ~= pass then return end
        self:placeRow(row, i)
        self:bindRow(row, self.rows[self.offset + i], self.offset + i)
        self.shown[i] = row
    end
    self.empty:SetShown(#self.rows == 0)
    self:syncScrollbar()
end

-- The columns at `width` and the header's labels on them; a row's cells follow on its next placeRow.
function Table:placeColumns(width)
    self.width = width
    self.place = Tbl.Columns(self.columns, width)
    self.layoutVersion = (self.layoutVersion or 0) + 1
    for i, b in ipairs(self.heads) do
        local spot = self.place[i]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.header, "TOPLEFT", spot.x, 0)
        b:SetWidth(spot.w)
        b.label:ClearAllPoints()
        b.label:SetAllPoints(b)
    end
end

--- Lay the header and the rows out for `width` x `height`.
function Table:Layout(width, height)
    self.height = height
    self:placeColumns(width)
    self:Bind()
end

-- The rows shown to the count that fits now, from the offset held: a row past it hidden and kept
-- spare, a row the new height adds taken from the spares (or the pool) and bound alone.
function Table:fitRows()
    local count = math.max(0, math.min(self:visibleCount(), #self.rows - self.offset))
    self.spare = self.spare or {}
    for i = #self.shown, count + 1, -1 do
        local row = self.shown[i]
        self.shown[i] = nil
        row:Hide()
        self.spare[#self.spare + 1] = row
    end
    local pass = self.binds
    for i = #self.shown + 1, count do
        local row = table.remove(self.spare) or NS.Pool.Acquire(self.pool, function() return newRow(self) end)
        row:Show()
        -- A Bind that ran inside the Show (Table:Bind's note) drew the slice already.
        if self.binds ~= pass then return end
        self:placeRow(row, i)
        self:bindRow(row, self.rows[self.offset + i], self.offset + i)
        self.shown[i] = row
    end
end

--- While the window is being sized (modules/Sizing.lua): the columns at `width`, the rows that fit
--- `height` and the scroll range, with nothing rebound. The rows shown keep what they draw, their
--- cells re-placed when the width moved; the offset holds. The release's Layout rebinds them all.
function Table:Resize(width, height)
    if width ~= self.width then
        self:placeColumns(width)
        for i, row in ipairs(self.shown) do self:placeRow(row, i) end
    end
    self.height = height
    self:fitRows()
    self:syncScrollbar()
end

--- The rows drawn now, top down (the suites read these).
function Table:Visible()
    return self.shown
end
