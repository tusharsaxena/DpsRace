local _, NS = ...
-- modules/Results_Loadout.lua — the run detail's loadout (#6): what the run was raced with, read from
-- the loadout store (modules/Loadouts.lua). A *Gear* section draws the equipped items in two columns
-- in the character frame's order, each with its quality border and item level; hovering one shows the
-- client's own item tooltip from the stored link, Shift-click links it in chat, and *Dressing Room*
-- tries the whole set on. A *Talents* line names the loadout and its hero tree, with *View* (Blizzard's
-- talent tree, read-only, through the `talentbuild` link) and *Copy* (the import string in the copy
-- window). A run stored before #6 says *Not recorded*.
--
-- UNDER THE COMPARE (#7, the pane's CompareTarget): the gear slots whose link differs from the other
-- run's are highlighted, and a *Different loadout* line shows when the two import strings differ. No
-- talent is compared node by node (the owner's call, 2026-10-25).
--
-- PLAIN DATA ONLY: links, names and strings stored out of combat. The grid is laid out from the
-- constants here, never from a size read back; ChangedSlots, Grid, LinkData and CanView are pure.

local Loadout = {}
NS.ResultsLoadout = Loadout

local L = NS.L
local Tbl = NS.ResultsTable
local C = Tbl.COLORS
local FONT = NS.Style.FONT

Loadout.PITCH = 28          -- one gear row
Loadout.ICON = 24           -- an item's icon, inside its 1px quality border
Loadout.GAP = 10            -- between the two columns
Loadout.BUTTON_H = 18
Loadout.DRESS_W = 104       -- the Dressing Room button
Loadout.TALENT_W = 56       -- View and Copy
Loadout.LINE_H = 14

-- The character frame's order: its left column (head down to the wrists, then the weapons) and its
-- right (hands down to the trinkets). The ranged slot (18) shows only when a run has an item there.
Loadout.LEFT = { 1, 2, 3, 15, 5, 9, 16, 17 }
Loadout.RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14, 18 }

local OPTIONAL = { [18] = true }
local EMPTY_BG = { 0.07, 0.07, 0.1, 1 }
local SEP = " \194\183 "

-- ── pure ────────────────────────────────────────────────────────────────────────────────────────

--- The cells the grid draws for `gear`: { slot, col, row } in the character frame's order.
--- @return table cells, number rows
function Loadout.Grid(gear)
    gear = type(gear) == "table" and gear or {}
    local cells, rows = {}, 0
    for col, slots in ipairs({ Loadout.LEFT, Loadout.RIGHT }) do
        local row = 0
        for _, slot in ipairs(slots) do
            if not OPTIONAL[slot] or gear[slot] ~= nil then
                row = row + 1
                cells[#cells + 1] = { slot = slot, col = col, row = row }
            end
        end
        if row > rows then rows = row end
    end
    return cells, rows
end

--- The slots whose item differs between two gear sets (one side empty counts); nil without both.
--- @return table|nil changed  { [slot] = true }
function Loadout.ChangedSlots(gear, other)
    if type(gear) ~= "table" or type(other) ~= "table" then return nil end
    local changed = {}
    for slot, link in pairs(gear) do
        if other[slot] ~= link then changed[slot] = true end
    end
    for slot in pairs(other) do
        if gear[slot] == nil then changed[slot] = true end
    end
    return changed
end

--- Whether two talent loadouts differ: both import strings known, and not the same.
function Loadout.TalentsDiffer(t, other)
    return type(t) == "table" and type(other) == "table" and type(t.importString) == "string"
        and type(other.importString) == "string" and t.importString ~= other.importString
end

--- An item link's name (the text in its brackets), or nil.
function Loadout.ItemName(link)
    return type(link) == "string" and link:match("|h%[(.-)%]|h") or nil
end

--- The talentbuild link's data, "talentbuild:<specID>:<level>:<importString>", or nil without a
--- string (a talentbuild link takes its spec from the string's own header).
--- @param t table|nil  a stored talent loadout
--- @param level number|nil  the character's level when it raced
function Loadout.LinkData(t, level)
    if type(t) ~= "table" or type(t.importString) ~= "string" or t.importString == "" then return nil end
    return ("talentbuild:%d:%d:%s"):format(tonumber(t.specID) or 0, tonumber(level) or 0, t.importString)
end

--- The loadout's chat hyperlink, [text] in the talent link color, or nil.
function Loadout.Hyperlink(t, level, text)
    local data = Loadout.LinkData(t, level)
    if not data then return nil end
    local label = tostring(text or (t.name or L["Talents"])):gsub("[|%[%]]", "")
    return ("|cffffd100|H%s|h[%s]|h|r"):format(data, label)
end

--- The client's loadout serialization version, or nil.
function Loadout.ClientSerial()
    local api = C_Traits
    if type(api) ~= "table" or type(api.GetLoadoutSerializationVersion) ~= "function" then return nil end
    local ok, v = pcall(api.GetLoadoutSerializationVersion)
    return ok and NS.Secrets.PlainNumber(v) or nil
end

--- Whether View can open the loadout: it has a string, and the client reads strings of its version.
--- @return boolean ok, string|nil why  "none" (no string) | "version" (written by another version)
function Loadout.CanView(t)
    if not Loadout.LinkData(t) then return false, "none" end
    local now = Loadout.ClientSerial()
    if type(t.serialVersion) == "number" and now and t.serialVersion ~= now then return false, "version" end
    return true
end

--- The talents line's text: the loadout's name, then its hero tree.
function Loadout.TalentsText(t)
    if type(t) ~= "table" then return L["Not recorded"] end
    local parts = { t.name or L["Unnamed loadout"] }
    if t.heroName then parts[#parts + 1] = t.heroName end
    return table.concat(parts, SEP)
end

-- ── the client's item data ──────────────────────────────────────────────────────────────────────

local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
    return nil
end

-- An item's icon, quality and item level from its link (the quality from the link's own color when
-- the client has not cached the item).
local function itemInfo(link)
    local api = type(C_Item) == "table" and C_Item or {}
    local q = ask(api.GetItemQualityByID, link) or tonumber(link:match("|cnIQ(%d+):") or "")
    return ask(api.GetItemIconByID, link), q, ask(api.GetDetailedItemLevelInfo, link)
end

local function qualityColor(q)
    local api = type(C_Item) == "table" and C_Item or {}
    if type(q) == "number" and type(api.GetItemQualityColor) == "function" then
        local ok, r, g, b = pcall(api.GetItemQualityColor, q)
        if ok and type(r) == "number" then return r, g, b end
    end
    return C.dim[1], C.dim[2], C.dim[3]
end

-- ── the acts ────────────────────────────────────────────────────────────────────────────────────

--- Try every item of `gear` on in the Dressing Room. Answers how many were sent.
function Loadout.DressUp(gear)
    if type(gear) ~= "table" or type(DressUpItemLink) ~= "function" then return 0 end
    local n = 0
    for _, slots in ipairs({ Loadout.LEFT, Loadout.RIGHT }) do
        for _, slot in ipairs(slots) do
            if gear[slot] and pcall(DressUpItemLink, gear[slot]) then n = n + 1 end
        end
    end
    return n
end

--- Open Blizzard's talent tree, read-only, on the loadout (the talentbuild link's own handler).
--- @return boolean opened
function Loadout.View(t, level)
    if not Loadout.CanView(t) or type(SetItemRef) ~= "function" then return false end
    local data = Loadout.LinkData(t, level)
    return (pcall(SetItemRef, data, Loadout.Hyperlink(t, level), "LeftButton"))
end

--- The loadout's import string in the copy window.
--- @return boolean shown
function Loadout.Copy(t, anchor)
    if type(t) ~= "table" or type(t.importString) ~= "string" then return false end
    if NS.ShowCopy(t.importString, L["Talent loadout"], anchor) then return true end
    NS.Print(t.importString)   -- no copy window (the library is absent): the string in chat instead
    return true
end

-- ── the parts ───────────────────────────────────────────────────────────────────────────────────

local function tip(p, owner, key, extra)
    local other = p:CompareTarget()
    local lines = NS.ResultsTips.Loadout(key, p.run, other, extra)
    if lines then Tbl.BelowTip(owner, lines) end
end

-- `frame`'s hover: the loadout tooltip for `key` (a function answers it late) under it.
local function hover(p, frame, key)
    frame:EnableMouse(true)
    if frame.SetMotionScriptsWhileDisabled then frame:SetMotionScriptsWhileDisabled(true) end
    frame:HookScript("OnEnter", function(self) tip(p, self, type(key) == "function" and key() or key) end)
    frame:HookScript("OnLeave", Tbl.HideTip)
    return frame
end

local function hoverOver(p, region, key)
    local f = CreateFrame("Frame", nil, p.content)
    f:SetAllPoints(region)
    return hover(p, f, key)
end

-- An item's hover: the client's own tooltip from the stored link, then a changed slot's note.
local function itemTip(p, cell)
    local tt = GameTooltip
    if not tt then return end
    if not cell.link then return tip(p, cell, "empty") end
    tt:SetOwner(cell, "ANCHOR_RIGHT")
    local shown = tt.SetHyperlink and pcall(tt.SetHyperlink, tt, cell.link)
    if not shown then tt:SetText(Loadout.ItemName(cell.link) or "?", 1, 1, 1, 1, true) end
    local note = cell.changed and NS.ResultsTips.Loadout("changed", p.run, p:CompareTarget(), cell.slot)
    if note then
        tt:AddLine(" ")
        for _, l in ipairs(note) do tt:AddLine(type(l) == "table" and l[1] or l, 1, 0.72, 0.29, true) end
    end
    tt:Show()
end

local function onItemClick(cell)
    local link = cell.link
    if not link then return end
    if type(HandleModifiedItemClick) == "function" then
        pcall(HandleModifiedItemClick, link)
    elseif type(IsShiftKeyDown) == "function" and IsShiftKeyDown() and type(ChatEdit_InsertLink) == "function" then
        pcall(ChatEdit_InsertLink, link)
    end
end

local function newCell(p, host)
    local cell = CreateFrame("Button", nil, host)
    cell.mark = cell:CreateTexture(nil, "BACKGROUND")
    cell.mark:SetAllPoints(cell)
    cell.mark:SetColorTexture(C.amber[1], C.amber[2], C.amber[3], 0.16)
    cell.edge = cell:CreateTexture(nil, "BORDER")
    cell.edge:SetSize(Loadout.ICON + 2, Loadout.ICON + 2)
    cell.edge:SetPoint("LEFT", cell, "LEFT", 1, 0)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetSize(Loadout.ICON, Loadout.ICON)
    cell.icon:SetPoint("CENTER", cell.edge, "CENTER", 0, 0)
    cell.ilvl = Tbl.Text(cell, FONT.TEXT, C.text, "CENTER")
    cell.ilvl:SetPoint("BOTTOM", cell.icon, "BOTTOM", 0, 1)
    cell.name = Tbl.Text(cell, FONT.TEXT, C.text)
    cell.name:SetPoint("LEFT", cell.edge, "RIGHT", 6, 0)
    if cell.RegisterForClicks then cell:RegisterForClicks("LeftButtonUp") end
    cell:SetScript("OnEnter", function(self) itemTip(p, self) end)
    cell:SetScript("OnLeave", Tbl.HideTip)
    cell:SetScript("OnClick", function(self) onItemClick(self) end)
    return cell
end

local function charLevel(p)
    local char = p.run and p.run.char
    return type(char) == "table" and char.level or nil
end

--- Build the loadout's parts into the pane `p` (its content `c`), as `p.lo`.
function Loadout.Build(p, c)
    local x = { cells = {} }
    p.lo = x
    local Button = NS.HudStates.Button
    x.title = Tbl.Text(c, FONT.HEADER)
    x.title:SetText(L["Gear"])
    x.dress = Button(c, L["Dressing Room"], function() Loadout.DressUp(x.gear) end)
    x.dress:SetSize(Loadout.DRESS_W, Loadout.BUTTON_H)
    x.none = Tbl.Text(c, FONT.TEXT, C.dim)
    x.none:SetText(L["Not recorded"])
    x.grid = CreateFrame("Frame", nil, c)
    x.talentsTitle = Tbl.Text(c, FONT.HEADER)
    x.talentsTitle:SetText(L["Talents"])
    x.talents = Tbl.Text(c, FONT.TEXT, C.text)
    x.view = Button(c, L["View"], function() Loadout.View(x.talentsData, charLevel(p)) end)
    x.copy = Button(c, L["Copy"], function() Loadout.Copy(x.talentsData, Tbl.WindowOf(p.frame)) end)
    for _, b in ipairs({ x.view, x.copy }) do b:SetSize(Loadout.TALENT_W, Loadout.BUTTON_H) end
    x.differs = Tbl.Text(c, FONT.TEXT, C.amber)
    x.differs:SetText(L["Different loadout"])
    hoverOver(p, x.title, function() return x.gear and "gear" or "none" end)
    hoverOver(p, x.none, "none")
    hover(p, x.dress, "dressUp")
    hoverOver(p, x.talentsTitle, function() return x.talentsData and "talents" or "none" end)
    hoverOver(p, x.talents, function() return x.talentsData and "talents" or "none" end)
    hover(p, x.view, function() return (Loadout.CanView(x.talentsData)) and "view" or "viewOff" end)
    hover(p, x.copy, "copy")
    x.differsHover = hoverOver(p, x.differs, "differs")
    return x
end

local function cellFor(p, x, i)
    local cell = x.cells[i]
    if not cell then
        cell = newCell(p, x.grid)
        x.cells[i] = cell
    end
    return cell
end

local function fillCell(cell, slot, link, changed)
    cell.slot, cell.link, cell.changed = slot, link, changed and true or false
    cell.mark:SetShown(cell.changed)
    if not link then
        cell.edge:SetColorTexture(EMPTY_BG[1], EMPTY_BG[2], EMPTY_BG[3], EMPTY_BG[4])
        cell.icon:SetTexture(nil)
        cell.ilvl:SetText("")
        cell.name:SetText(L["Empty"])
        cell.name:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
        return
    end
    local icon, q, ilvl = itemInfo(link)
    local r, g, b = qualityColor(q)
    cell.edge:SetColorTexture(r, g, b, 1)
    cell.icon:SetTexture(icon)
    cell.ilvl:SetText(type(ilvl) == "number" and tostring(math.floor(ilvl)) or "")
    cell.name:SetText(Loadout.ItemName(link) or "?")
    cell.name:SetTextColor(r, g, b)
end

--- Read `p.run`'s loadout (and, while comparing, the other run's) and paint the parts.
function Loadout.Fill(p)
    local x = p.lo
    local gear, talents = NS.Loadouts.Of(p.run)
    x.gear, x.talentsData = gear, talents
    local other = p:CompareTarget()
    local otherGear, otherTalents = NS.Loadouts.Of(other)
    local changed = other and Loadout.ChangedSlots(gear, otherGear) or {}
    x.cellList, x.rows = Loadout.Grid(gear)
    x.changedCount = 0
    for i, spec in ipairs(x.cellList) do
        local cell = cellFor(p, x, i)
        fillCell(cell, spec.slot, gear and gear[spec.slot], changed[spec.slot])
        if changed[spec.slot] then x.changedCount = x.changedCount + 1 end
    end
    for i = #x.cellList + 1, #x.cells do x.cells[i]:Hide() end
    x.talents:SetText(Loadout.TalentsText(talents))
    local tc = talents and C.text or C.dim
    x.talents:SetTextColor(tc[1], tc[2], tc[3])
    NS.HudStates.SetEnabled(x.view, (Loadout.CanView(talents)))
    NS.HudStates.SetEnabled(x.copy, talents ~= nil and talents.importString ~= nil)
    x.different = other ~= nil and Loadout.TalentsDiffer(talents, otherTalents)
end

local function place(region, parent, x, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
end

local function layoutGrid(p, x, y, cw)
    local colW = math.floor((cw - Loadout.GAP) / 2)
    place(x.grid, p.content, 0, y)
    x.grid:SetSize(cw, math.max(1, x.rows * Loadout.PITCH))
    for i, spec in ipairs(x.cellList) do
        local cell = x.cells[i]
        place(cell, x.grid, (spec.col - 1) * (colW + Loadout.GAP), -(spec.row - 1) * Loadout.PITCH)
        cell:SetSize(colW, Loadout.PITCH - 2)
        cell.name:SetWidth(math.max(20, colW - Loadout.ICON - 10))
        cell:Show()
    end
    return y - x.rows * Loadout.PITCH
end

local function layoutTalents(p, x, y, cw)
    local tw = Loadout.TALENT_W
    place(x.talentsTitle, p.content, 0, y)
    y = y - Loadout.LINE_H - 4
    place(x.talents, p.content, 0, y - 2)
    x.talents:SetWidth(math.max(40, cw - 2 * tw - 12))
    place(x.view, p.content, cw - 2 * tw - 4, y)
    place(x.copy, p.content, cw - tw, y)
    y = y - Loadout.BUTTON_H - 4
    x.differs:SetShown(x.different)
    x.differsHover:SetShown(x.different)
    if x.different then
        place(x.differs, p.content, 0, y)
        x.differs:SetWidth(cw)
        y = y - Loadout.LINE_H
    end
    return y
end

--- The Gear section and the Talents line at `y` across `cw`; answers the y beneath.
function Loadout.Layout(p, y, cw)
    local x = p.lo
    place(x.title, p.content, 0, y)
    local has = x.gear ~= nil
    x.dress:SetShown(has)
    if has then place(x.dress, p.content, cw - Loadout.DRESS_W, y + 2) end
    y = y - Loadout.LINE_H - 6
    x.none:SetShown(not has)
    x.grid:SetShown(has)
    if has then
        y = layoutGrid(p, x, y, cw)
    else
        place(x.none, p.content, 0, y)
        y = y - Loadout.LINE_H
    end
    return layoutTalents(p, x, y - 6, cw) - 8
end
