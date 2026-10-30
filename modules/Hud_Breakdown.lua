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
--
-- HOVER IS OPT-IN. A list built with a `tip` hook (the Results detail's, the HUD's running and result
-- bodies', DR-03) takes the mouse on its rows. A READ RESULT's row hands the hook its plain spell
-- record and rank; a LIVE row hands it only the spell's ID, which may be secret (`tip(row, nil, nil,
-- id)`): the hook passes it straight to ResultsTable.SpellTip, which never compares or type-tests it
-- and reads plain geometry only. A list built without one keeps its rows click-through.
--
-- STRIPES ARE OPT-IN TOO. A list built with a `stripe` hook (the Results detail's, the Results list's
-- tint) tints every other row by its index; the HUD passes none and draws no stripe.

local Breakdown = {}
NS.HudBreakdown = Breakdown

local L = NS.L

-- Compact rows, as LootHistory's list draws them (18px, GameFontHighlightSmall): modules/Style.lua.
-- That is the default; the height, the bar's fill and the text are the player's, HUD > HUD
-- Appearance > Spell bars and Spell text (modules/Hud_Appearance.lua), read from config at call time.
Breakdown.ROW_HEIGHT = 18
Breakdown.ROW_GAP = 2
local PCT_WIDTH = 44
local TRACK_COLOR = "dr.list.track"   -- the skin's faint track behind a bar
local FONT = NS.Style.FONT

--- The configured row height, and the pitch from one row's top to the next (both config, never a
--- measured size).
function Breakdown.RowHeight()
    local A = NS.HudAppearance
    return A and A.RowHeight() or Breakdown.ROW_HEIGHT
end

function Breakdown.Pitch()
    return Breakdown.RowHeight() + Breakdown.ROW_GAP
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

local function newRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    local bar = CreateFrame("StatusBar", nil, row)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(bar)
    NS.Style.Fill(track, TRACK_COLOR)
    row.icon, row.bar = icon, bar
    -- The spell's name and amount are the player's Spell text block (HUD Appearance): plain labels the
    -- skin never paints. The share is a caption, the skin's.
    row.name = NS.Style.PlainText(bar, FONT.TEXT, "LEFT")
    row.amount = NS.Style.PlainText(bar, FONT.TEXT, "RIGHT")
    row.pct = NS.Style.Text(bar, FONT.CAPTION, nil, "RIGHT")
    return row
end

-- The row's configured look (HUD Appearance), applied once per Changed(): its height, the icon's size
-- (the row's, less a pixel each side), the bar's fill and the spell text. The share keeps its caption
-- gray: it is a caption, not the spell's text. `where` is the list's (Breakdown.New).
local function restyle(row, where)
    local A = NS.HudAppearance
    if not A or row.stamp == A.stamp then return end
    row.stamp, row.mode = A.stamp, nil
    local h = Breakdown.RowHeight()
    row:SetHeight(h)
    row.iconSize = math.max(8, h - 2)
    row.icon:SetSize(row.iconSize, row.iconSize)
    local fill = A.Bar()
    row.bar:SetStatusBarTexture(fill.texture)
    row.bar:SetStatusBarColor(fill.r, fill.g, fill.b, fill.a)
    local text = A.Font("spellText", where)
    A.ApplyFont(row.name, text)
    A.ApplyFont(row.amount, text)
end

-- The row's anchors for its mode: with or without the icon, with or without the % column. Set only
-- when the mode changes; every anchor is relative to the row's own children, never a measured size.
local function setMode(row, icons, pct)
    local mode = (icons and "i" or "-") .. (pct and "p" or "-")
    if row.mode == mode then return end
    row.mode = mode
    local bar, name, amount, share = row.bar, row.name, row.amount, row.pct
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", row, "TOPLEFT", icons and ((row.iconSize or 16) + 3) or 0, 0)
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
--- @param tip function|nil  tip(row, spell, rank, liveID): a row's hover, a result row's plain record
---   and rank, or a live row's (possibly secret) ID alone (none: rows take no mouse)
--- @param stripe function|nil  stripe(index): the alpha of the row's tint (none: no stripes)
--- @param where string|nil  "window" for a list in the Results window: its spell text is window text
---   to the Font outline (D-06); nil: HUD text
--- @return table list
function Breakdown.New(parent, tip, stripe, where)
    return setmetatable({ parent = parent, pool = NS.Pool.New(), rows = {}, tip = tip, stripe = stripe,
        where = where }, List)
end

-- A row's stripe, made once per pooled row of a list with a `stripe` hook: the row and the gap under it.
local function paintStripe(list, row, i)
    if not row.stripe then
        row.stripe = row:CreateTexture(nil, "BACKGROUND")
        row.stripe:SetTexture("Interface\\Buttons\\WHITE8x8")
        row.stripe:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.stripe:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -Breakdown.ROW_GAP)
    end
    NS.Style.Vertex(row.stripe, "dr.list.stripe", list.stripe(i))
end

-- A row's hover, wired once per pooled row of a list with a `tip` hook.
local function wireTip(list, row)
    if row.tipWired then return end
    row.tipWired = true
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        list.hover = self
        if self.spell then
            list.tip(self, self.spell, self.rank)
        elseif self.liveID ~= nil then
            list.tip(self, nil, nil, self.liveID)
        end
    end)
    row:SetScript("OnLeave", function(self)
        if list.hover == self then list.hover = nil end
        if GameTooltip then GameTooltip:Hide() end
    end)
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
    restyle(row, self.where)
    local y = -(i - 1) * Breakdown.Pitch()
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    setMode(row, icons, pct)
    row.spell, row.rank, row.liveID = nil, nil, nil
    if self.tip then wireTip(self, row) end
    if self.stripe then paintStripe(self, row, i) end
    self.rows[i] = row
    return row
end

local function setIcon(row, icons, id)
    if not icons then return end
    row.icon:SetTexture(Breakdown.SpellIcon(id))
end

--- Draw the live breakdown: `n` spells in the order Blizzard gave them, from the one after `offset`
--- (a plain row count off the wheel, modules/Hud_States.lua). Every value is opaque and goes only to
--- a widget setter or the formatter. The bars keep the top spell's scale however far it scrolls.
--- @param live table|nil  NS.Meter.ReadLive()'s table
--- @param n number  rows to show
--- @param icons boolean
--- @param offset number|nil  spells skipped from the top (default 0)
--- @return number drawn
function List:ShowLive(live, n, icons, offset)
    self:Clear()
    if type(live) ~= "table" or type(live.spells) ~= "table" then return 0 end
    local spells = live.spells
    local first = spells[1]
    if first == nil then return 0 end
    local max = live.maxAmount
    if max == nil then max = first.total end
    offset = offset or 0
    for i = 1, n do
        local s = spells[offset + i]
        if s == nil then break end
        local row = self:acquire(i, icons, false)
        if max ~= nil then row.bar:SetMinMaxValues(0, max) end
        if s.total ~= nil then row.bar:SetValue(s.total) end
        row.name:SetText(Breakdown.SpellName(s.spellID))
        row.amount:SetText(NS.Format.Number(s.total))
        row.pct:SetText("")
        setIcon(row, icons, s.spellID)
        row.liveID = s.spellID   -- a handle for the hover only: tested for nil, never compared
    end
    self:retip()
    return #self.rows
end

-- The live list re-sorts under a resting pointer, so the hovered row's tooltip is re-run on each
-- redraw for the spell it draws now; the secret ID is never compared, only handed on. A hovered row
-- no longer drawn hides the tooltip.
function List:retip()
    local row = self.hover
    if not row or not self.tip then return end
    for i = 1, #self.rows do
        if self.rows[i] == row then
            if row.liveID ~= nil then self.tip(row, nil, nil, row.liveID) end
            return
        end
    end
    self.hover = nil
    if GameTooltip then GameTooltip:Hide() end
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
--- @param offset number|nil  spells skipped from the top (default 0), the wheel's
--- @return number drawn
function List:ShowResult(run, n, icons, offset)
    self:Clear()
    local spells = type(run) == "table" and run.spells
    if type(spells) ~= "table" or not spells[1] then return 0 end
    local result = type(run.result) == "table" and run.result or {}
    local damage = type(result.damage) == "number" and result.damage or 0
    local top = spells[1].dmg or 0
    offset = offset or 0
    for i = 1, math.min(n, #spells - offset) do
        local row = self:acquire(i, icons, true)
        fillResult(row, spells[offset + i], top, damage, icons)
        row.spell, row.rank = spells[offset + i], offset + i
    end
    return #self.rows
end
