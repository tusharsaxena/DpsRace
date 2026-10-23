local _, NS = ...
-- modules/Results_Table.lua — the Results window's sortable list (spec §6.2): a header of sort
-- controls over a pooled, scrolling set of row buttons, shared by the Runs and Bests tabs; and the
-- small helpers both tabs draw a run with (class and spec icons, the class color, the category badge,
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

Tbl.ROW_H = 30
Tbl.HEADER_H = 24
Tbl.PAD = 6                 -- the gap between two cells, and the row's inner margin
Tbl.SCROLLBAR_W = 8
Tbl.ICON = 16
Tbl.WHEEL_ROWS = 3          -- rows one notch of the mouse wheel moves

local FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local WHITE = "Interface\\Buttons\\WHITE8x8"
local CLASS_ATLAS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local C = {
    text  = { 0.93, 0.93, 0.95 },
    dim   = { 0.62, 0.62, 0.68 },
    gold  = { 1.0, 0.82, 0.0 },
    amber = { 1.0, 0.72, 0.29 },
    green = { 0.36, 0.86, 0.46 },
}
Tbl.COLORS = C

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

local function fontPath()
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end
Tbl.Font = fontPath

--- A FontString with the window's face, size, color and justification, never wrapping.
function Tbl.Text(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(fontPath(), size, "")
    color = color or C.text
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

--- A flat panel (the HUD's): a 1px edge over a faint fill.
function Tbl.Panel(parent, bg, edge)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if f.SetBackdrop then
        f:SetBackdrop(FLAT)
        bg, edge = bg or { 1, 1, 1, 0.03 }, edge or { 1, 1, 1, 0.10 }
        f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        f:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
    end
    return f
end

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

--- The category badge: "CLEAVE", or "CLEAVE ×5" for a counted group, and its color.
--- @return string text, table color
function Tbl.Badge(target)
    target = type(target) == "table" and target or {}
    local category = target.category or "other"
    local text = NS.Dummies.Label(category):upper()
    if type(target.count) == "number" and target.count > 1 then
        text = L["%s \195\151%d"]:format(text, target.count)
    end
    return text, Tbl.CATEGORY_COLORS[category] or Tbl.CATEGORY_COLORS.other
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

-- Each flag's chip word on the bests board (mockup screen 09: "1 LATE").
local SHORT = {
    lateCasts = function(run) return L["%d LATE"]:format(#run.flags.lateCasts) end,
    restarted = function() return L["RESTARTED"] end,
    reloaded = function() return L["RELOADED"] end,
    sessionFromList = function() return L["BY LIST"] end,
    died = function() return L["DIED"] end,
}

--- The run's flags as chip words, joined ("1 LATE · RELOADED"), or "" for a clean run.
function Tbl.ShortFlags(run)
    local out = {}
    for _, flag in ipairs(NS.Scoring.Flags(run)) do
        local short = SHORT[flag.key]
        if short then out[#out + 1] = short(run) end
    end
    return table.concat(out, " \194\183 ")
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

local function showTip(owner, lines)
    if not GameTooltip or not lines or #lines == 0 then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(lines[1], 1, 1, 1, 1, true)
    for i = 2, #lines do GameTooltip:AddLine(lines[i], 1, 0.82, 0, true) end
    GameTooltip:Show()
end

local function hideTip()
    if GameTooltip then GameTooltip:Hide() end
end

--- A mouse-sensitive spot that shows its own `tip` (an array of lines) on hover; the caller anchors it.
--- On a list row the spot passes a click on to the row (`spot.row`), so the icons still select it.
function Tbl.TipSpot(parent)
    local spot = CreateFrame("Frame", nil, parent)
    spot:EnableMouse(true)
    spot:SetScript("OnEnter", function(self) showTip(self, self.tip) end)
    spot:SetScript("OnLeave", hideTip)
    spot:SetScript("OnMouseUp", function(self)
        local row = self.row
        local click = row and row:GetScript("OnClick")
        if click then click(row) end
    end)
    return spot
end

-- ── cells ───────────────────────────────────────────────────────────────────────────────────────

local Cells = {}

function Cells.text(row, col)
    return { fs = Tbl.Text(row, col.size or 12, C.text, col.justify) }
end

-- The class and spec icons, each with a hover naming it, and (on the bests board) the spec's name.
function Cells.icons(row, col)
    local cell = { class = row:CreateTexture(nil, "ARTWORK"), spec = row:CreateTexture(nil, "ARTWORK") }
    cell.class:SetSize(Tbl.ICON, Tbl.ICON)
    cell.spec:SetSize(Tbl.ICON, Tbl.ICON)
    cell.classSpot, cell.specSpot = Tbl.TipSpot(row), Tbl.TipSpot(row)
    cell.classSpot.row, cell.specSpot.row = row, row
    cell.classSpot:SetAllPoints(cell.class)
    cell.specSpot:SetAllPoints(cell.spec)
    if col.withName then cell.fs = Tbl.Text(row, 12, C.text) end
    return cell
end

function Cells.badge(row)
    local cell = { box = Tbl.Panel(row) }
    cell.box:SetHeight(18)
    cell.fs = Tbl.Text(cell.box, 9, C.amber, "CENTER")
    cell.fs:SetPoint("CENTER", cell.box, "CENTER", 0, 0)
    return cell
end

function Cells.flag(row)
    local cell = { icon = row:CreateTexture(nil, "ARTWORK"), glyph = Tbl.Text(row, 13, C.amber, "CENTER") }
    cell.icon:SetSize(12, 12)
    cell.icon:SetVertexColor(C.amber[1], C.amber[2], C.amber[3])
    cell.spot = Tbl.TipSpot(row)
    cell.spot.row = row
    return cell
end

local function paint(fs, color)
    color = color or C.text
    fs:SetTextColor(color[1], color[2], color[3])
end

local Bind = {}

function Bind.text(cell, col, run)
    local s, color = col.text(run)
    cell.fs:SetText(s or "")
    paint(cell.fs, color)
end

function Bind.icons(cell, col, run)
    local char = run.char or {}
    local specName, specIcon = Tbl.SpecInfo(char.specID, char.spec)
    Tbl.SetClassIcon(cell.class, char.class)
    cell.classSpot.tip = { Tbl.ClassName(char.class) }
    cell.spec:SetTexture(specIcon)
    cell.spec:SetShown(specIcon ~= nil)
    cell.specSpot.tip = { specName or L["Unknown spec"] }
    if cell.fs then
        cell.fs:SetText(specName or "")
        paint(cell.fs, Tbl.ClassColor(char.class))
    end
    cell.specName = specName
    if col.after then col.after(cell, run) end
end

function Bind.badge(cell, col, run)
    local s, color = col.text(run)
    s = s or ""
    color = color or C.amber
    cell.fs:SetText(s)
    paint(cell.fs, color)
    cell.box:SetShown(s ~= "")
    cell.box:SetWidth(math.floor(#s * 6 + 14))
    if cell.box.SetBackdropBorderColor then
        cell.box:SetBackdropBorderColor(color[1], color[2], color[3], 0.6)
        cell.box:SetBackdropColor(color[1], color[2], color[3], 0.08)
    end
end

function Bind.flag(cell, _, run)
    local texts = Tbl.FlagTexts(run)
    local on = #texts > 0
    local path = NS.Icon("flag")
    cell.icon:SetShown(on and path ~= nil)
    cell.glyph:SetShown(on and path == nil)
    if path then cell.icon:SetTexture(path) end
    cell.glyph:SetText(on and "!" or "")
    cell.spot:SetShown(on)
    cell.spot.tip = texts
    cell.texts = texts
end

-- Place one cell in its column, from the column's x and width alone.
local function placeCell(row, cell, col, x, w)
    local kind = col.kind or "text"
    if kind == "icons" then
        cell.class:ClearAllPoints()
        cell.class:SetPoint("LEFT", row, "LEFT", x, 0)
        cell.spec:ClearAllPoints()
        cell.spec:SetPoint("LEFT", row, "LEFT", x + Tbl.ICON + 3, 0)
        if cell.fs then
            cell.fs:ClearAllPoints()
            cell.fs:SetPoint("LEFT", row, "LEFT", x + 2 * Tbl.ICON + 10, 0)
            cell.fs:SetWidth(math.max(10, w - 2 * Tbl.ICON - 10))
        end
    elseif kind == "badge" then
        cell.box:ClearAllPoints()
        cell.box:SetPoint("LEFT", row, "LEFT", x, 0)
    elseif kind == "flag" then
        cell.icon:ClearAllPoints()
        cell.icon:SetPoint("LEFT", row, "LEFT", x + 2, 0)
        cell.glyph:ClearAllPoints()
        cell.glyph:SetPoint("LEFT", row, "LEFT", x + 2, 0)
        cell.spot:ClearAllPoints()
        cell.spot:SetAllPoints(cell.icon)
    else
        cell.fs:ClearAllPoints()
        cell.fs:SetPoint("LEFT", row, "LEFT", x, 0)
        cell.fs:SetWidth(math.max(10, w))
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

local function newHeader(t, i, col)
    local b = CreateFrame("Button", nil, t.header)
    b:SetHeight(Tbl.HEADER_H)
    b.label = Tbl.Text(b, 10, C.dim, col.justify)
    b.label:SetText(col.label or "")
    b.arrow = b:CreateTexture(nil, "OVERLAY")
    b.arrow:SetSize(10, 10)
    b.arrow:SetVertexColor(C.gold[1], C.gold[2], C.gold[3])
    b.arrow:Hide()
    b.col = col
    if col.sort then
        b:SetScript("OnClick", function() t:SetSort(col.key) end)
    end
    t.heads[i] = b
    return b
end

local function rowBackground(row)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetTexture(WHITE)
    row.sel = row:CreateTexture(nil, "BORDER")
    row.sel:SetAllPoints(row)
    row.sel:SetColorTexture(1, 0.82, 0, 0.10)
    row.sel:Hide()
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetColorTexture(1, 1, 1, 0.04)
end

local function newRow(t)
    local row = CreateFrame("Button", nil, t.body)
    row:SetHeight(Tbl.ROW_H)
    if row.RegisterForClicks then row:RegisterForClicks("LeftButtonUp") end
    rowBackground(row)
    row.cells = {}
    for i, col in ipairs(t.columns) do
        row.cells[col.key] = Cells[col.kind or "text"](row, col)
        row.cells[i] = row.cells[col.key]
    end
    row:SetScript("OnClick", function(self) if self.run and t.onClick then t.onClick(self.run) end end)
    row:SetScript("OnDoubleClick", function(self) if self.run and t.onDoubleClick then t.onDoubleClick(self.run) end end)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta) t:Scroll(delta) end)
    return row
end

local function buildScrollbar(t)
    local bar = CreateFrame("Slider", nil, t.frame)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(Tbl.SCROLLBAR_W)
    bar:SetPoint("TOPRIGHT", t.frame, "TOPRIGHT", -2, -Tbl.HEADER_H - 2)
    bar:SetPoint("BOTTOMRIGHT", t.frame, "BOTTOMRIGHT", -2, 2)
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 1, 1, 0.25)
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
--- @param columns table  { key, label, kind = "text"|"icons"|"badge"|"flag", width | flex+min,
---                         justify, sort = fn(run) -> value, desc = default direction, text = fn(run) }
--- @param opts table  { sortKey, sortDesc, onClick(run), onDoubleClick(run), empty = text }
function Tbl.New(parent, columns, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    local t = setmetatable({
        frame = frame, columns = columns, heads = {}, pool = NS.Pool.New(), shown = {},
        data = {}, rows = {}, offset = 0, width = 600, height = 300,
        sortKey = opts.sortKey, sortDesc = opts.sortDesc ~= false,
        onClick = opts.onClick, onDoubleClick = opts.onDoubleClick,
    }, Table)
    t.header = CreateFrame("Frame", nil, frame)
    t.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    t.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    t.header:SetHeight(Tbl.HEADER_H)
    local line = t.header:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.24, 0.24, 0.27, 0.85)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", t.header, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", t.header, "BOTTOMRIGHT", 0, 0)
    for i, col in ipairs(columns) do newHeader(t, i, col) end
    t.body = CreateFrame("Frame", nil, frame)
    t.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -Tbl.HEADER_H)
    t.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    t.body:EnableMouseWheel(true)
    t.body:SetScript("OnMouseWheel", function(_, delta) t:Scroll(delta) end)
    t.empty = Tbl.Text(t.body, 12, C.dim, "CENTER")
    t.empty:SetPoint("TOP", t.body, "TOP", 0, -24)
    t.empty:SetText(opts.empty or "")
    buildScrollbar(t)
    t:paintHeader()
    return t
end

function Table:column(key)
    for _, col in ipairs(self.columns) do if col.key == key then return col end end
end

function Table:paintHeader()
    for _, b in ipairs(self.heads) do
        local on = b.col.key == self.sortKey
        paint(b.label, on and C.gold or C.dim)
        local path = on and NS.Icon(self.sortDesc and "sort-down" or "sort-up")
        b.arrow:SetShown(path and true or false)
        if path then b.arrow:SetTexture(path) end
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
    if desc ~= nil then
        self.sortDesc = desc and true or false
    elseif key == self.sortKey then
        self.sortDesc = not self.sortDesc
    else
        self.sortDesc = col.desc ~= false
    end
    self.sortKey = key
    self:paintHeader()
    self.rows = Tbl.Sort(self.columns, self.data, self.sortKey, self.sortDesc)
    self:Bind()
end

--- Replace the list (any order) and redraw it sorted, keeping the scroll where it can.
function Table:SetData(list)
    self.data = list or {}
    self.rows = Tbl.Sort(self.columns, self.data, self.sortKey, self.sortDesc)
    self:Bind()
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
        if run.id == id then
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

function Table:bindRow(row, run, index)
    row.run, row.index = run, index
    local alt = index % 2 == 0
    row.bg:SetVertexColor(1, 1, 1, alt and 0.025 or 0)
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
function Table:Bind()
    self.offset = math.max(0, math.min(self.offset, self:maxOffset()))
    NS.Pool.ReleaseAll(self.pool, function(row) row.run = nil end)
    self.shown = {}
    local count = math.min(self:visibleCount(), #self.rows - self.offset)
    for i = 1, count do
        local row = NS.Pool.Acquire(self.pool, function() return newRow(self) end)
        self:placeRow(row, i)
        self:bindRow(row, self.rows[self.offset + i], self.offset + i)
        self.shown[i] = row
    end
    self.empty:SetShown(#self.rows == 0)
    self:syncScrollbar()
end

--- Lay the header and the rows out for `width` x `height`.
function Table:Layout(width, height)
    self.width, self.height = width, height
    self.place = Tbl.Columns(self.columns, width)
    self.layoutVersion = (self.layoutVersion or 0) + 1
    for i, b in ipairs(self.heads) do
        local spot = self.place[i]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.header, "TOPLEFT", spot.x, 0)
        b:SetWidth(spot.w)
        b.label:ClearAllPoints()
        b.label:SetAllPoints(b)
        b.arrow:ClearAllPoints()
        if b.col.justify == "RIGHT" then
            b.arrow:SetPoint("RIGHT", b, "LEFT", -2, 0)
        else
            b.arrow:SetPoint("LEFT", b, "LEFT", math.min(spot.w - 10, #(b.col.label or "") * 7 + 4), 0)
        end
    end
    self:Bind()
end

--- The rows drawn now, top down (the suites read these).
function Table:Visible()
    return self.shown
end
