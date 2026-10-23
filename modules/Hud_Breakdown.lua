local _, NS = ...
-- modules/Hud_Breakdown.lua — the Race HUD's spell rows (spec §6.1): pooled, laid out from config,
-- filled either LIVE (opaque values in Blizzard's order, no percentage) or from a READ RESULT (plain
-- numbers, sorted highest first, with the share of the run's damage).
--
-- THE LIVE PATH TOUCHES NO NUMBER. A live value is secret for the whole pull, so a row hands it to
-- three native seams and nowhere else: the bar's SetMinMaxValues / SetValue (the widget scales it),
-- NS.Format.Number (the client's formatter abbreviates it) and the name/icon lookups (C_Spell takes a
-- secret spell ID). No sort, no %, no comparison, no truth test: the one question asked of a live
-- value is `== nil`, which the client allows on a non-boolean secret.
--
-- NO GEOMETRY IS READ BACK. A frame handed a secret through SetValue/SetText has secret geometry
-- (MultiMeters' measured layout rule), so a row is placed from its index and the config constants
-- below, and nothing here ever asks a row, a bar or a label for its size or position.

local Breakdown = {}
NS.HudBreakdown = Breakdown

local L = NS.L

Breakdown.ROW_HEIGHT = 22
Breakdown.ROW_GAP = 2
local ICON_SIZE = 18
local PCT_WIDTH = 44
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local BAR_COLOR = { 0.29, 0.29, 0.45, 0.85 }
local TRACK_COLOR = { 1, 1, 1, 0.04 }
local NAME_COLOR = { 0.93, 0.93, 0.95 }
local DIM_COLOR = { 0.62, 0.62, 0.68 }

local function fontPath()
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

--- A spell's name through C_Spell (a secret ID is accepted; the name may come back secret, which
--- only SetText ever sees). Never stored: names resolve per locale and per patch (spec §7).
--- @param id any  a spell ID, possibly secret
--- @return any  the name, or the localized "Unknown spell"
function Breakdown.SpellName(id)
    local api = C_Spell and C_Spell.GetSpellName
    if id == nil or type(api) ~= "function" then return L["Unknown spell"] end
    local ok, name = pcall(api, id)
    if ok and name ~= nil then return name end
    return L["Unknown spell"]
end

--- A spell's icon through C_Spell, or nil: a lookup that fails leaves the icon blank (spec O2).
--- @param id any  a spell ID, possibly secret
--- @return any
function Breakdown.SpellIcon(id)
    local api = C_Spell and C_Spell.GetSpellTexture
    if id == nil or type(api) ~= "function" then return nil end
    local ok, icon = pcall(api, id)
    if ok then return icon end
    return nil
end

local function label(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(fontPath(), size, "")
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetJustifyH(justify)
    fs:SetWordWrap(false)
    return fs
end

local function newRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(Breakdown.ROW_HEIGHT)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetStatusBarTexture(BAR_TEXTURE)
    bar:SetStatusBarColor(BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3], BAR_COLOR[4])
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(bar)
    track:SetColorTexture(TRACK_COLOR[1], TRACK_COLOR[2], TRACK_COLOR[3], TRACK_COLOR[4])
    row.icon, row.bar = icon, bar
    row.name = label(bar, 11, NAME_COLOR, "LEFT")
    row.amount = label(bar, 11, NAME_COLOR, "RIGHT")
    row.pct = label(bar, 10, DIM_COLOR, "RIGHT")
    return row
end

-- The row's anchors for its mode: with or without the icon, with or without the % column. Set only
-- when the mode changes; every anchor is relative to the row's own children, never a measured size.
local function setMode(row, icons, pct)
    local mode = (icons and "i" or "-") .. (pct and "p" or "-")
    if row.mode == mode then return end
    row.mode = mode
    local bar, name, amount, share = row.bar, row.name, row.amount, row.pct
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", row, "TOPLEFT", icons and (ICON_SIZE + 3) or 0, 0)
    bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    share:ClearAllPoints()
    share:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    share:SetWidth(PCT_WIDTH)
    share:SetShown(pct)
    amount:ClearAllPoints()
    if pct then amount:SetPoint("RIGHT", share, "LEFT", -4, 0) else amount:SetPoint("RIGHT", bar, "RIGHT", -6, 0) end
    name:ClearAllPoints()
    name:SetPoint("LEFT", bar, "LEFT", 6, 0)
    name:SetPoint("RIGHT", amount, "LEFT", -6, 0)
    row.icon:SetShown(icons)
end

local List = {}
List.__index = List

--- A list of spell rows drawn into `parent`, top down.
--- @param parent table
--- @return table list
function Breakdown.New(parent)
    return setmetatable({ parent = parent, pool = NS.Pool.New(), rows = {} }, List)
end

--- Release every row.
function List:Clear()
    NS.Pool.ReleaseAll(self.pool)
    self.rows = {}
end

--- How many rows are drawn now.
function List:Count()
    return #self.rows
end

function List:acquire(i, icons, pct)
    local parent = self.parent
    local row = NS.Pool.Acquire(self.pool, function() return newRow(parent) end)
    local y = -(i - 1) * (Breakdown.ROW_HEIGHT + Breakdown.ROW_GAP)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    setMode(row, icons, pct)
    self.rows[i] = row
    return row
end

local function setIcon(row, icons, id)
    if not icons then return end
    row.icon:SetTexture(Breakdown.SpellIcon(id))
end

--- Draw the live breakdown: the first `n` spells in the order Blizzard gave them. Every value is
--- opaque and goes only to a widget setter or the formatter.
--- @param live table|nil  NS.Meter.ReadLive()'s table
--- @param n number  rows to show
--- @param icons boolean
--- @return number drawn
function List:ShowLive(live, n, icons)
    self:Clear()
    if type(live) ~= "table" or type(live.spells) ~= "table" then return 0 end
    local spells = live.spells
    local first = spells[1]
    if first == nil then return 0 end
    local max = live.maxAmount
    if max == nil then max = first.total end
    for i = 1, n do
        local s = spells[i]
        if s == nil then break end
        local row = self:acquire(i, icons, false)
        if max ~= nil then row.bar:SetMinMaxValues(0, max) end
        if s.total ~= nil then row.bar:SetValue(s.total) end
        row.name:SetText(Breakdown.SpellName(s.spellID))
        row.amount:SetText(NS.Format.Number(s.total))
        row.pct:SetText("")
        setIcon(row, icons, s.spellID)
    end
    return #self.rows
end

-- One read-result row: plain numbers, its bar scaled to the top spell, its share of `damage`.
local function fillResult(row, s, top, damage, icons)
    local dmg = s.dmg or 0
    row.bar:SetMinMaxValues(0, top > 0 and top or 1)
    row.bar:SetValue(dmg)
    row.name:SetText(Breakdown.SpellName(s.id))
    row.amount:SetText(NS.Format.Number(dmg))
    row.pct:SetText(damage > 0 and NS.Format.Pct(dmg / damage * 100) or "")
    setIcon(row, icons, s.id)
end

--- Draw a read result's top `n` spells with their share of the run's damage (plain numbers, already
--- sorted highest first by NS.Meter.ReadSession).
--- @param run table  a resolved run
--- @param n number
--- @param icons boolean
--- @return number drawn
function List:ShowResult(run, n, icons)
    self:Clear()
    local spells = type(run) == "table" and run.spells
    if type(spells) ~= "table" or not spells[1] then return 0 end
    local result = type(run.result) == "table" and run.result or {}
    local damage = type(result.damage) == "number" and result.damage or 0
    local top = spells[1].dmg or 0
    for i = 1, math.min(n, #spells) do
        fillResult(self:acquire(i, icons, true), spells[i], top, damage, icons)
    end
    return #self.rows
end
