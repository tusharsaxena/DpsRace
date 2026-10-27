local _, NS = ...
-- modules/Results_Gear.lua — the gear view (#17): a window from the Results detail's *Gear view* button
-- (it replaced the button that tried the set on, the owner's call, 2026-10-28) that lays the run's gear out as the
-- character panel does, without the model, with the run's stats where the model would be.
--
-- THE LAYOUT. A legend bar (this run's label and item level in gold, the compared run's in blue), then
-- three columns: on the left head, neck, shoulders, back, chest, shirt and tabard (each only when the
-- run has one: neither is recorded today, Recorder.GEAR_SLOTS) and wrists; on the right hands, waist,
-- legs, feet, both rings and both trinkets (the ranged slot under them, only when filled); main hand
-- and off hand side by side under the middle. Each slot: the item's icon in its quality's border, its
-- item level over the icon, its name beside it toward the middle, and under the name its marks: the
-- enchant's (MARK_ENCHANT) and each gem's own icon, read from the stored link (ParseLink: the enchant
-- and gem IDs after the item ID). Hovering a slot shows the client's item tooltip from the link (and
-- what differs from the compared run); Shift-click links it in chat, as the detail's grid does. The
-- middle column is Stats.Groups (modules/Stats.lua): Primary (the main stat, stamina, armor),
-- Secondary (crit, haste, mastery, versatility: rating and percent) and Tertiary (leech, avoidance,
-- speed), with dashes for a run raced before stats were recorded.
--
-- THE COMPARE. Against the run the detail compares with, resolved whether or not its compare is on
-- (CompareTarget(true)), as the ability timeline follows it: a slot whose item differs (another item,
-- or one side empty) wears the amber tint the detail's grid uses; its item level reads green when
-- higher than the compared run's and red when lower; an enchant or gems that differ on the same item
-- get an amber edge on their marks, and a missing one shows as a dim mark with that edge (Marks). Each
-- stat row shows its delta (+ green, - red, from the Results palette); none without the other run's
-- stats.
--
-- THE WINDOW is a modal of the ability timeline's kind (modules/Results_Timeline.lua): one strata above
-- the Results window (LAYERS.STRATA.MODAL), toplevel, the shared skin made opaque (its SKIN), in
-- UISpecialFrames (Escape closes it first), the Results window's dim cover up while it is open. Its size
-- is fixed by its content (Size), never resizable; every open centers it over the Results window
-- (CenterOver), movable by its title bar for as long as it is open, never stored. Master scale acts on
-- it. It closes with the Results window, at the stand-down and on a source switch.
--
-- PLAIN DATA ONLY: stored links and the run's plain stats. Every position comes from the constants
-- here (Cells, Size, Marks), never read back off a frame; ParseLink, SlotDiff, Marks, NoteLines, Cells,
-- Size and CenterOver are pure.

local Gear = { wanted = false }
NS.ResultsGear = Gear

local L = NS.L
local Style = NS.Style
local FONT = Style.FONT
local Tbl = NS.ResultsTable
local C = Tbl.COLORS

Gear.FRAME_NAME = "DpsRaceGear"
Gear.PAD = 12
Gear.LEGEND_H = 26
Gear.SLOT_W = 190         -- a slot: the icon and its name beside it
Gear.ICON = 36
Gear.PITCH = 44           -- one slot row
Gear.TEXT_GAP = 6         -- between the icon's border and the name
Gear.MID_W = 300          -- the stats column
Gear.COL_GAP = 14         -- between the columns, and between the two weapons
Gear.WEAPON_GAP = 10      -- above the weapons
Gear.MARK = 12            -- an enchant or gem mark, inside its 1px edge
Gear.MARK_GAP = 3
-- The stats column: a group's heading line, a row, the gap between groups, and its three cells.
Gear.GROUP_H = 22
Gear.STAT_H = 16
Gear.GROUP_GAP = 8
Gear.LABEL_W, Gear.VALUE_W, Gear.DELTA_W = 104, 98, 98

-- The character panel's columns. OPTIONAL slots show only when the run has an item there.
Gear.LEFT = { 1, 2, 3, 15, 5, 4, 19, 9 }
Gear.RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14, 18 }
Gear.WEAPONS = { 16, 17 }
local OPTIONAL = { [4] = true, [19] = true, [18] = true }

-- The enchant's mark: the Enchanting profession's icon. A gem's is its own icon; FALLBACK when the
-- client has none for it.
Gear.MARK_ENCHANT = "Interface\\Icons\\Trade_Engraving"
Gear.MARK_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

local HEADER_H = Style.TITLE_BAR_H
local EMPTY_BG = { 0.07, 0.07, 0.1, 1 }
local MARK_EDGE = { 0, 0, 0, 1 }
local SEP = " \194\183 "

local ui        -- the built window
local pane      -- the detail pane the window follows
local hiding = false

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Gear", fmt, ...) end
end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────────

--- An item link's parts: its item ID, its enchant ID and its gem IDs, in socket order (nil, or an
--- empty list, for none). nil for anything that is not an item link.
--- @return table|nil parts  { itemID, enchantID, gems = { id, ... } }
function Gear.ParseLink(link)
    local body = type(link) == "string" and link:match("item:([%-%d:]*)") or nil
    if not body then return nil end
    local fields, i = {}, 0
    for field in (body .. ":"):gmatch("([^:]*):") do
        i = i + 1
        fields[i] = tonumber(field)
    end
    local gems = {}
    for g = 3, 6 do
        if fields[g] and fields[g] > 0 then gems[#gems + 1] = fields[g] end
    end
    local enchant = fields[2]
    return { itemID = fields[1], enchantID = enchant and enchant > 0 and enchant or nil, gems = gems }
end

local function gemKey(parts)
    return table.concat(parts.gems, ",")
end

--- What differs in one slot between this run's and the compared run's: each side `{ link, ilvl }` (a
--- side with no link: an empty slot). `item` (another item, or one side empty), `ilvl` (1 higher, -1
--- lower, 0 the same or unknown), and on the same item `enchant` and `gems`. nil without a compared run.
--- @return table|nil diff
function Gear.SlotDiff(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return nil end
    local pa, pb = Gear.ParseLink(a.link), Gear.ParseLink(b.link)
    local d = { ilvl = 0 }
    if type(a.ilvl) == "number" and type(b.ilvl) == "number" then
        d.ilvl = a.ilvl > b.ilvl and 1 or (a.ilvl < b.ilvl and -1 or 0)
    end
    if not (pa and pb) then
        d.item = (pa ~= nil) ~= (pb ~= nil)
        return d
    end
    d.item = pa.itemID ~= pb.itemID
    if not d.item then
        d.enchant = pa.enchantID ~= pb.enchantID
        d.gems = gemKey(pa) ~= gemKey(pb)
    end
    return d
end

--- A slot's marks in order: its enchant, then each gem ({ kind, id, changed }); a missing enchant or
--- missing gems the compared run had show as one mark each with `missing`.
--- @param parts table|nil  ParseLink's
--- @param diff table|nil  SlotDiff's
--- @return table marks
function Gear.Marks(parts, diff)
    local out = {}
    if not parts then return out end
    diff = diff or {}
    if parts.enchantID then
        out[#out + 1] = { kind = "enchant", id = parts.enchantID, changed = diff.enchant == true }
    elseif diff.enchant then
        out[#out + 1] = { kind = "enchant", missing = true, changed = true }
    end
    for _, id in ipairs(parts.gems) do out[#out + 1] = { kind = "gem", id = id, changed = diff.gems == true } end
    if #parts.gems == 0 and diff.gems then out[#out + 1] = { kind = "gem", missing = true, changed = true } end
    return out
end

--- The lines a slot's tooltip adds under the item for what differs from `label`'s run (its item's name
--- `otherName`, nil for an empty slot).
--- @return table lines
function Gear.NoteLines(diff, label, otherName)
    local lines = {}
    if type(diff) ~= "table" then return lines end
    if diff.item then
        lines[#lines + 1] = otherName and L["Changed: %s wore %s."]:format(label, otherName)
            or L["Changed: %s had nothing here."]:format(label)
    end
    if diff.enchant then lines[#lines + 1] = L["The enchant differs from %s's."]:format(label) end
    if diff.gems then lines[#lines + 1] = L["The gems differ from %s's."]:format(label) end
    if diff.ilvl ~= 0 then
        lines[#lines + 1] = diff.ilvl > 0 and L["Higher item level than %s's."]:format(label)
            or L["Lower item level than %s's."]:format(label)
    end
    return lines
end

local function columnRows(gear, slots)
    local list = {}
    for _, slot in ipairs(slots) do
        if not OPTIONAL[slot] or gear[slot] ~= nil then list[#list + 1] = slot end
    end
    return list
end

--- The window's size for `gear`: three columns across, the taller side column's rows and the weapons'
--- row down.
--- @return number width, number height, number rows
function Gear.Size(gear)
    gear = type(gear) == "table" and gear or {}
    local rows = math.max(#columnRows(gear, Gear.LEFT), #columnRows(gear, Gear.RIGHT))
    local width = 2 * Gear.PAD + 2 * Gear.SLOT_W + Gear.MID_W + 2 * Gear.COL_GAP
    local height = HEADER_H + Gear.LEGEND_H + Gear.PAD + rows * Gear.PITCH + Gear.WEAPON_GAP + Gear.PITCH
        + Gear.PAD
    return width, height, rows
end

--- Every slot cell for `gear`: { slot, side ("left": the icon on its left, "right": on its right), x, y }
--- from the body's top-left (under the legend bar).
--- @return table cells
function Gear.Cells(gear)
    gear = type(gear) == "table" and gear or {}
    local width, _, rows = Gear.Size(gear)
    local cells = {}
    for i, slot in ipairs(columnRows(gear, Gear.LEFT)) do
        cells[#cells + 1] = { slot = slot, side = "left", x = Gear.PAD, y = -(i - 1) * Gear.PITCH }
    end
    for i, slot in ipairs(columnRows(gear, Gear.RIGHT)) do
        cells[#cells + 1] = { slot = slot, side = "right", x = width - Gear.PAD - Gear.SLOT_W, y = -(i - 1) * Gear.PITCH }
    end
    -- The weapons under the middle, facing each other as the character panel's do.
    local y, mid = -(rows * Gear.PITCH + Gear.WEAPON_GAP), width / 2
    cells[#cells + 1] = { slot = Gear.WEAPONS[1], side = "right", x = mid - Gear.COL_GAP / 2 - Gear.SLOT_W, y = y }
    cells[#cells + 1] = { slot = Gear.WEAPONS[2], side = "left", x = mid + Gear.COL_GAP / 2, y = y }
    return cells
end

-- How far `point`'s spot sits from a frame's center, in its width and height.
local function pointShare(point)
    local hx = point:find("LEFT") and -0.5 or (point:find("RIGHT") and 0.5 or 0)
    local hy = point:find("TOP") and 0.5 or (point:find("BOTTOM") and -0.5 or 0)
    return hx, hy
end

--- The offset that centers a `gw` x `gh` frame over one anchored at `point` (x, y) at `w` x `h`, both
--- anchored by the same point.
--- @return number x, number y
function Gear.CenterOver(point, x, y, w, h, gw, gh)
    local hx, hy = pointShare(type(point) == "string" and point or "CENTER")
    return x + hx * (gw - w), y + hy * (gh - h)
end

-- ── the client's item data ──────────────────────────────────────────────────────────────────────

local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
    return nil
end

local function itemAPI()
    return type(C_Item) == "table" and C_Item or {}
end

local function ilvlOf(link)
    return link and ask(itemAPI().GetDetailedItemLevelInfo, link) or nil
end

local function qualityColor(link)
    local api = itemAPI()
    local q = ask(api.GetItemQualityByID, link) or tonumber(link:match("|cnIQ(%d+):") or "")
    if type(q) == "number" and type(api.GetItemQualityColor) == "function" then
        local ok, r, g, b = pcall(api.GetItemQualityColor, q)
        if ok and type(r) == "number" then return r, g, b end
    end
    return C.dim[1], C.dim[2], C.dim[3]
end

local function markTexture(m)
    if m.kind == "enchant" then return Gear.MARK_ENCHANT end
    return (m.id and ask(itemAPI().GetItemIconByID, m.id)) or Gear.MARK_FALLBACK
end

-- ── the window ──────────────────────────────────────────────────────────────────────────────────

Gear.SKIN = NS.ResultsTimeline.SKIN   -- the shared skin made opaque, as the timeline wears it

local function buildChrome(f)
    f.title = Style.Text(f, FONT.TITLE, C.gold, "CENTER")
    f.title:SetPoint("CENTER", f, "TOP", 0, -HEADER_H / 2)
    f.title:SetText(L["Gear view"])
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(0.24, 0.24, 0.27, 0.85)
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -HEADER_H)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -HEADER_H)
    ui.controls = Style.NewStrip()
    ui.close = Style.AddToStrip(ui.controls, NS.MakeCloseButton(f, function() Gear.Hide() end))
    if ui.close then ui.close:SetPoint("RIGHT", f, "TOPRIGHT", -6, -HEADER_H / 2) end
    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    drag:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -28, -HEADER_H)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() f:StartMoving() end)
    -- Moved for as long as it is open: nothing stored, the next open centers it again.
    drag:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    ui.drag = drag
end

local function buildLegend(f)
    local y = -HEADER_H - Gear.LEGEND_H / 2
    ui.legendA = Style.Text(f, FONT.TEXT, C.gold)
    ui.legendA:SetPoint("LEFT", f, "TOPLEFT", Gear.PAD, y)
    ui.legendB = Style.Text(f, FONT.TEXT, C.blue, "RIGHT")
    ui.legendB:SetPoint("RIGHT", f, "TOPRIGHT", -Gear.PAD, y)
end

-- The stats column: a heading per group and a row of three cells per stat, built once (Stats.GROUPS
-- never changes) and placed from the constants.
local function buildStats(body)
    local col = CreateFrame("Frame", nil, body)
    col:SetPoint("TOPLEFT", body, "TOPLEFT", Gear.PAD + Gear.SLOT_W + Gear.COL_GAP, 0)
    col:SetSize(Gear.MID_W, 1)
    ui.statsCol, ui.groups, ui.statRows = col, {}, {}
    local y = 0
    for gi, g in ipairs(NS.Stats.GROUPS) do
        local head = Style.Text(col, FONT.SECTION)
        head:SetPoint("TOPLEFT", col, "TOPLEFT", 0, y)
        ui.groups[gi] = head
        y = y - Gear.GROUP_H
        for _, key in ipairs(g.rows) do
            local row = { key = key }
            row.label = Style.Text(col, FONT.TEXT, C.dim)
            row.label:SetPoint("TOPLEFT", col, "TOPLEFT", 0, y)
            row.label:SetWidth(Gear.LABEL_W)
            row.value = Style.Text(col, FONT.TEXT, C.text, "RIGHT")
            row.value:SetPoint("TOPLEFT", col, "TOPLEFT", Gear.LABEL_W, y)
            row.value:SetWidth(Gear.VALUE_W)
            row.delta = Style.Text(col, FONT.TEXT, C.dim, "RIGHT")
            row.delta:SetPoint("TOPLEFT", col, "TOPLEFT", Gear.LABEL_W + Gear.VALUE_W, y)
            row.delta:SetWidth(Gear.DELTA_W)
            ui.statRows[#ui.statRows + 1] = row
            y = y - Gear.STAT_H
        end
        y = y - Gear.GROUP_GAP
    end
    ui.statsNote = Style.Text(col, FONT.CAPTION)
    ui.statsNote:SetPoint("TOPLEFT", col, "TOPLEFT", 0, y)
    ui.statsNote:SetWidth(Gear.MID_W)
    ui.statsNote:SetText(L["Stats were not recorded for this run."])
end

-- A close-stack close, a frame later: the Results window's cover goes unless the view is open again.
local function settle()
    if Gear.IsShown() then return end
    NS.Results.SetCovered(false)
    NS.Results.StepAsideForTree()
end

local function onHide()
    Tbl.HideTip()
    if hiding or (ui and ui.frame:IsShown()) then return end
    -- Escape (UISpecialFrames): the player closed it. The cover stays until the close stack is done,
    -- so the Results window, hidden by the same Escape, still sees it and shows again.
    Gear.wanted = false
    if C_Timer and C_Timer.After then C_Timer.After(0, settle) else settle() end
end

local function ensureWindow()
    if ui then return ui end
    local f = CreateFrame("Frame", Gear.FRAME_NAME, UIParent, "BackdropTemplate")
    ui = { frame = f, cells = {} }
    f:Hide()
    f:SetFrameStrata(NS.Constants.LAYERS.STRATA.MODAL)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetToplevel(true)
    buildChrome(f)
    buildLegend(f)
    ui.body = CreateFrame("Frame", nil, f)
    ui.body:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(HEADER_H + Gear.LEGEND_H + Gear.PAD))
    ui.body:SetSize(1, 1)
    buildStats(ui.body)
    NS.ApplySkin(f, Gear.SKIN)
    f:SetScript("OnHide", onHide)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, Gear.FRAME_NAME) end
    debug("window built")
    return ui
end

-- ── one slot ────────────────────────────────────────────────────────────────────────────────────

-- A slot's hover: the client's own item tooltip from the stored link, then what differs.
local function slotTip(cell)
    local tt = GameTooltip
    if not tt then return end
    if not cell.link then
        return Tbl.BelowTip(cell, { L["Empty"], L["Nothing was equipped in this slot."] })
    end
    tt:SetOwner(cell, "ANCHOR_RIGHT")
    local shown = tt.SetHyperlink and pcall(tt.SetHyperlink, tt, cell.link)
    if not shown then tt:SetText(NS.ResultsLoadout.ItemName(cell.link) or "?", 1, 1, 1, 1, true) end
    if cell.notes and cell.notes[1] then
        tt:AddLine(" ")
        Style.AddTipLines(tt, cell.notes, 1, C.amber[1], C.amber[2], C.amber[3])
    end
    tt:Show()
end

local function onSlotClick(cell)
    local link = cell.link
    if not link then return end
    if type(HandleModifiedItemClick) == "function" then
        pcall(HandleModifiedItemClick, link)
    elseif type(IsShiftKeyDown) == "function" and IsShiftKeyDown() and type(ChatEdit_InsertLink) == "function" then
        pcall(ChatEdit_InsertLink, link)
    end
end

local function newMark(cell)
    local m = { edge = cell:CreateTexture(nil, "BORDER"), icon = cell:CreateTexture(nil, "ARTWORK") }
    m.edge:SetSize(Gear.MARK + 2, Gear.MARK + 2)
    m.icon:SetSize(Gear.MARK, Gear.MARK)
    m.icon:SetPoint("CENTER", m.edge, "CENTER", 0, 0)
    return m
end

local function newCell(body)
    local cell = CreateFrame("Button", nil, body)
    cell:SetSize(Gear.SLOT_W, Gear.PITCH - 4)
    cell.tint = cell:CreateTexture(nil, "BACKGROUND")
    cell.tint:SetAllPoints(cell)
    cell.tint:SetColorTexture(C.amber[1], C.amber[2], C.amber[3], 0.16)
    cell.edge = cell:CreateTexture(nil, "BORDER")
    cell.edge:SetSize(Gear.ICON + 2, Gear.ICON + 2)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetSize(Gear.ICON, Gear.ICON)
    cell.icon:SetPoint("CENTER", cell.edge, "CENTER", 0, 0)
    cell.ilvl = Style.Text(cell, FONT.TEXT, C.text, "CENTER")
    cell.ilvl:SetPoint("BOTTOM", cell.icon, "BOTTOM", 0, 2)
    cell.name = Style.Text(cell, FONT.TEXT, C.text)
    cell.name:SetWidth(Gear.SLOT_W - Gear.ICON - 2 - Gear.TEXT_GAP)
    if cell.name.SetWordWrap then cell.name:SetWordWrap(false) end   -- one line: the marks sit under it
    cell.marks = {}
    for i = 1, 5 do cell.marks[i] = newMark(cell) end
    if cell.RegisterForClicks then cell:RegisterForClicks("LeftButtonUp") end
    cell:SetScript("OnEnter", function(self) slotTip(self) end)
    cell:SetScript("OnLeave", Tbl.HideTip)
    cell:SetScript("OnClick", function(self) onSlotClick(self) end)
    return cell
end

-- The icon at the cell's outer side, the name and the marks toward the middle.
local function placeCell(cell, spec)
    local left = spec.side == "left"
    local corner, dir = left and "TOPLEFT" or "TOPRIGHT", left and 1 or -1
    local textX = Gear.ICON + 2 + Gear.TEXT_GAP
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", ui.body, "TOPLEFT", spec.x, spec.y)
    cell.edge:ClearAllPoints()
    cell.edge:SetPoint(corner, cell, corner, 0, 0)
    cell.name:ClearAllPoints()
    cell.name:SetJustifyH(left and "LEFT" or "RIGHT")
    cell.name:SetPoint(corner, cell, corner, dir * textX, -3)
    for i, m in ipairs(cell.marks) do
        m.edge:ClearAllPoints()
        m.edge:SetPoint(corner, cell, corner, dir * (textX + (i - 1) * (Gear.MARK + 2 + Gear.MARK_GAP)), -20)
    end
    cell.side = spec.side
end

local function paintMarks(cell, marks)
    for i, m in ipairs(cell.marks) do
        local mark = marks[i]
        m.edge:SetShown(mark ~= nil)
        m.icon:SetShown(mark ~= nil)
        if mark then
            local e = mark.changed and C.amber or MARK_EDGE
            m.edge:SetColorTexture(e[1], e[2], e[3], 1)
            m.icon:SetTexture(markTexture(mark))
            if m.icon.SetDesaturated then m.icon:SetDesaturated(mark.missing == true) end
            m.icon:SetAlpha(mark.missing and 0.35 or 1)
        end
        m.mark = mark
    end
end

local function ilvlColor(sign)
    if sign == 1 then return C.green end
    if sign == -1 then return C.red end
    return C.text
end

-- One slot's look: its item (or Empty), the item change's tint, the item level's color, the marks.
local function fillCell(cell, slot, link, diff, label, otherLink)
    cell.slot, cell.link, cell.diff = slot, link, diff
    cell.changed = diff ~= nil and diff.item == true
    cell.tint:SetShown(cell.changed)
    cell.notes = Gear.NoteLines(diff, label, otherLink and NS.ResultsLoadout.ItemName(otherLink))
    if not link then
        cell.edge:SetColorTexture(EMPTY_BG[1], EMPTY_BG[2], EMPTY_BG[3], EMPTY_BG[4])
        cell.icon:SetTexture(nil)
        cell.ilvl:SetText("")
        cell.name:SetText(L["Empty"])
        cell.name:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
        return paintMarks(cell, {})
    end
    local r, g, b = qualityColor(link)
    cell.edge:SetColorTexture(r, g, b, 1)
    cell.icon:SetTexture(ask(itemAPI().GetItemIconByID, link))
    local ilvl = ilvlOf(link)
    cell.ilvl:SetText(type(ilvl) == "number" and tostring(math.floor(ilvl)) or "")
    local ic = ilvlColor(diff and diff.ilvl)
    cell.ilvl:SetTextColor(ic[1], ic[2], ic[3])
    cell.name:SetText(NS.ResultsLoadout.ItemName(link) or "?")
    cell.name:SetTextColor(r, g, b)
    paintMarks(cell, Gear.Marks(Gear.ParseLink(link), diff))
end

local function cellFor(slot)
    local cell = ui.cells[slot]
    if not cell then
        cell = newCell(ui.body)
        ui.cells[slot] = cell
    end
    return cell
end

-- ── drawing ─────────────────────────────────────────────────────────────────────────────────────

local function deltaColor(sign)
    if sign == 1 then return C.green end
    if sign == -1 then return C.red end
    return C.dim
end

local function fillStats(stats, otherStats)
    local groups = NS.Stats.Groups(stats, otherStats)
    local i = 0
    for gi, g in ipairs(groups) do
        ui.groups[gi]:SetText(g.title)
        for _, r in ipairs(g.rows) do
            i = i + 1
            local row = ui.statRows[i]
            row.label:SetText(r.label)
            row.value:SetText(r.text)
            local vc = stats and C.text or C.dim
            row.value:SetTextColor(vc[1], vc[2], vc[3])
            row.delta:SetText(r.delta or "")
            local dc = deltaColor(r.sign)
            row.delta:SetTextColor(dc[1], dc[2], dc[3])
            row.data = r
        end
    end
    ui.statsNote:SetShown(stats == nil)
end

local function fillLegend(run, other, kind)
    local Compare = NS.ResultsCompare
    local parts = { L["This run"], Compare.ShortLabel(run) }
    local ilvl = NS.ResultsLoadout.IlvlText(run)
    if ilvl ~= "" then parts[#parts + 1] = ilvl end
    ui.legendA:SetText(table.concat(parts, SEP))
    ui.otherLabel = other and Compare.OtherLabel(kind) or nil
    if other then
        ui.legendB:SetText(L["vs %s"]:format(ui.otherLabel .. SEP .. Compare.ShortLabel(other)))
        ui.legendB:SetTextColor(C.blue[1], C.blue[2], C.blue[3])
    else
        ui.legendB:SetText(L["No run to compare with"])
        ui.legendB:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    end
end

-- Every slot of the layout filled and placed; a cell left from a run with more slots hides.
local function fillSlots(gear, otherGear, compared)
    local used = {}
    ui.drawn = Gear.Cells(gear)
    for _, spec in ipairs(ui.drawn) do
        local cell = cellFor(spec.slot)
        local link, otherLink = gear and gear[spec.slot], otherGear and otherGear[spec.slot]
        local diff = compared and Gear.SlotDiff({ link = link, ilvl = ilvlOf(link) },
            { link = otherLink, ilvl = ilvlOf(otherLink) }) or nil
        fillCell(cell, spec.slot, link, diff, ui.otherLabel, otherLink)
        placeCell(cell, spec)
        cell:Show()
        used[spec.slot] = true
    end
    for slot, cell in pairs(ui.cells) do
        if not used[slot] then cell:Hide() end
    end
end

-- Read the followed detail's run and compare target, and draw them.
local function draw()
    local run = pane and pane.run or nil
    local other, kind
    if run and pane.CompareTarget then other, kind = pane:CompareTarget(true) end
    ui.run, ui.other, ui.kind = run, other, kind
    local gear = NS.ResultsSource.LoadoutOf(run)
    local otherGear = other and NS.ResultsSource.LoadoutOf(other) or nil
    if run then fillLegend(run, other, kind) end
    -- A compared run with no gear recorded marks nothing (as the detail's grid, ChangedSlots).
    fillSlots(gear, otherGear, otherGear ~= nil)
    fillStats(NS.Stats.Of(run), NS.Stats.Of(other))
    ui.width, ui.height = Gear.Size(gear)
    ui.frame:SetSize(ui.width, ui.height)
    Gear.ApplyScale()
    debug("drawn: %d slots", #ui.drawn)
end

-- Centered over the Results window (its anchor and its size in the view shown).
local function applyPlacement()
    local point, relativePoint, x, y, width, height = NS.Results.Placement()
    local gw, gh = Gear.Size(NS.ResultsSource.LoadoutOf(pane and pane.run))
    local cx, cy = Gear.CenterOver(point, x, y, width, height, gw, gh)
    ui.frame:ClearAllPoints()
    ui.frame:SetPoint(point, UIParent, relativePoint, cx, cy)
end

-- ── the public surface ──────────────────────────────────────────────────────────────────────────

--- Open the view on the detail pane `p` (the detail's Gear view button) and follow it from now on.
--- @return boolean opened
function Gear.Open(p)
    if NS.IsStoodDown() then return false end
    pane = p
    Gear.wanted = true
    ensureWindow()
    applyPlacement()
    ui.frame:Show()
    if ui.frame.Raise then ui.frame:Raise() end
    NS.RaiseStaticPopups()
    NS.Results.SetCovered(true)
    draw()
    return true
end

--- Close the view (its close control, the Results window closing): the Results window's cover goes.
function Gear.Hide()
    local was = Gear.wanted
    Gear.wanted = false
    if ui and ui.frame:IsShown() then
        hiding = true
        ui.frame:Hide()
        hiding = false
    end
    if was then NS.Results.SetCovered(false) end
end

--- Whether the view is open.
function Gear.IsShown()
    return Gear.wanted and ui ~= nil and ui.frame:IsShown() == true
end

--- The detail pane `p` drew a run or changed its compare target: redraw while open on it. A pane
--- left with no run (the shown run was deleted) closes the view.
function Gear.DetailChanged(p)
    if p ~= pane or not Gear.IsShown() then return end
    if p.run == nil then return Gear.Hide() end
    draw()
end

--- Master scale on the window. Nothing before it is built: the first open applies it.
function Gear.ApplyScale()
    local scale = tonumber(NS.GetSetting("scale"))
    if ui and scale then ui.frame:SetScale(scale) end
end

--- The Master controls' Reset position: nothing is stored, so an open view centers again.
function Gear.ResetPosition()
    if Gear.IsShown() then applyPlacement() end
end

--- The slot cells drawn now, for the suites: { [slot] = cell } (shown ones only).
function Gear.SlotCells()
    local out = {}
    for slot, cell in pairs(ui and ui.cells or {}) do
        if cell:IsShown() then out[slot] = cell end
    end
    return out
end

--- The built window, for the suites (nil until first opened).
function Gear.__ui() return ui end
