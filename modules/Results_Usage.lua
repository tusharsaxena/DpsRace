local _, NS = ...
-- modules/Results_Usage.lua — what a run used (#13), as the Results window shows it: the Runs list's
-- *Used* column (its icons, its tooltip and its sort, through modules/Results_Runs.lua and
-- modules/Results_Tips.lua) and the run detail's *Usage* section, where the player edits the list.
--
-- THE SECTION lists one row per candidate (every on-use gear item and every bag consumable with a use
-- spell at the arm) and one per detected entry with no candidate (food, a weapon enchant): a checkbox
-- whose label is clickable too (Tbl.SetCheckLabel), the item's icon and name, and a dim detail ("x2
-- at 0:09, 1:12", "active at the start", "time unknown"). What was detected starts ticked. *Save* is
-- live only while the ticks differ from the stored list, and writes them through Usage.SetUsed
-- (modules/Usage.lua), which keeps a detected entry's times and source. A sample run (test mode, the
-- sim) changes in memory only, as its note does. A run stored before format 3 says *Not recorded*.
-- An unticked food or enchant stays listed (SetUsed keeps it as a candidate), so the untick can be
-- undone; a redraw of the same run keeps the ticks not saved yet.
--
-- PLAIN DATA ONLY: the stored run.usage record (plain numbers and strings). Item names and icons are
-- the client's item data, read at call time and pcall'd. Rows are laid out from the constants here,
-- never from a size read back; Entries, Rows, Ticks, Changed, Clock and Detail are pure.

local ResultsUsage = {}
NS.ResultsUsage = ResultsUsage

local L = NS.L
local Tbl = NS.ResultsTable
local C = Tbl.COLORS
local FONT = NS.Style.FONT

ResultsUsage.ROW_H = 22      -- one row: the checkbox's height and a little air
ResultsUsage.CHECK = 20      -- the checkbox
ResultsUsage.ICON = 16       -- an item's icon, between the box and its name
ResultsUsage.SAVE_W = 64
ResultsUsage.BUTTON_H = 18
ResultsUsage.LINE_H = 14

-- The icons of an entry with no item: Well Fed's own, and the enchanting trade's for a weapon enchant.
ResultsUsage.FOOD_ICON = "Interface\\Icons\\Spell_Misc_Food"
ResultsUsage.ENCHANT_ICON = "Interface\\Icons\\Trade_Engraving"
ResultsUsage.UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local MAIN_HAND = 16

-- ── pure ────────────────────────────────────────────────────────────────────────────────────────

--- A run's usage record, or nil for a run stored before format 3 (Not recorded).
function ResultsUsage.Record(run)
    local u = type(run) == "table" and run.usage
    if type(u) ~= "table" or type(u.used) ~= "table" then return nil end
    return u
end

--- The used entries as the Used column draws them: the gear first, then everything else, each in
--- its stored order. nil when not recorded.
--- @return table|nil entries
function ResultsUsage.Entries(run)
    local u = ResultsUsage.Record(run)
    if not u then return nil end
    local gear, rest = {}, {}
    for _, e in ipairs(u.used) do
        if type(e) == "table" then
            local into = e.kind == "gear" and gear or rest
            into[#into + 1] = e
        end
    end
    for _, e in ipairs(rest) do gear[#gear + 1] = e end
    return gear
end

--- The Used column's sort value: how many entries, nil (last) when not recorded.
function ResultsUsage.Count(run)
    local entries = ResultsUsage.Entries(run)
    return entries and #entries or nil
end

--- A time on the race clock as m:ss, a pre-pull one (negative) with its minus sign; one that rounds
--- to the pull itself is 0:00, never -0:00.
function ResultsUsage.Clock(t)
    if type(t) ~= "number" then return "?" end
    if math.floor(t + 0.5) < 0 then return "-" .. NS.Format.Length(-t) end
    return NS.Format.Length(math.max(0, t))
end

local START = { buff = true, enchant = true }

--- An entry's detail: how many times and when ("x2 at 0:09, 1:12", "at 0:09"), "active at the
--- start" (a buff or an enchant on at the arm), or "time unknown" (a bag drop, a manual tick).
function ResultsUsage.Detail(e)
    if type(e) ~= "table" then return "" end
    local n = tonumber(e.n) or 1
    if type(e.times) == "table" and #e.times > 0 then
        local parts = {}
        for i, t in ipairs(e.times) do parts[i] = ResultsUsage.Clock(t) end
        local at = L["at %s"]:format(table.concat(parts, ", "))
        return n > 1 and L["x%d %s"]:format(n, at) or at
    end
    if START[e.src] then return L["active at the start"] end
    return n > 1 and L["x%d, time unknown"]:format(n) or L["time unknown"]
end

-- Whether used entry `e` is the one candidate `c` stands for: by its item (a gear candidate also by
-- its slot, when the entry has one); a candidate with no item (food or an enchant the player unticked,
-- kept by Usage.SetUsed) by its kind, an enchant also by its enchant ID and slot.
local function stands(c, e)
    if c.itemID ~= nil then
        return e.itemID == c.itemID and (c.kind ~= "gear" or e.slot == nil or e.slot == c.slot)
    end
    if e.itemID ~= nil or e.kind ~= c.kind then return false end
    return c.kind ~= "enchant" or (e.enchantID == c.enchantID and e.slot == c.slot)
end

-- The used entry a candidate stands for: the first not yet matched. Answers it and its index.
local function matchOf(used, c, matched)
    for i, e in ipairs(used) do
        if not matched[i] and type(e) == "table" and stands(c, e) then return e, i end
    end
    return nil
end

--- The Usage section's rows: one per candidate (in its stored order), each with the used entry it
--- stands for when there is one, then one per used entry no candidate stands for (food, an enchant).
--- nil when not recorded.
--- @return table|nil rows  { { itemID?, kind, slot?, enchantID?, entry? }, ... }
function ResultsUsage.Rows(run)
    local u = ResultsUsage.Record(run)
    if not u then return nil end
    local rows, matched = {}, {}
    for _, c in ipairs(type(u.candidates) == "table" and u.candidates or {}) do
        if type(c) == "table" then
            local e, i = matchOf(u.used, c, matched)
            if i then matched[i] = true end
            rows[#rows + 1] = { itemID = c.itemID, kind = c.kind, slot = c.slot, enchantID = c.enchantID, entry = e }
        end
    end
    for i, e in ipairs(u.used) do
        if not matched[i] and type(e) == "table" then
            rows[#rows + 1] = { itemID = e.itemID, kind = e.kind, slot = e.slot, enchantID = e.enchantID, entry = e }
        end
    end
    return rows
end

--- The ticks Usage.SetUsed takes for `state` ({ [row index] = true } for a ticked row), in row order.
function ResultsUsage.Ticks(rows, state)
    local out = {}
    for i, row in ipairs(rows or {}) do
        if state[i] then
            out[#out + 1] = { itemID = row.itemID, kind = row.kind, slot = row.slot, enchantID = row.enchantID }
        end
    end
    return out
end

--- Whether `state` differs from what the rows hold (a row ticked that was not used, or the reverse).
function ResultsUsage.Changed(rows, state)
    for i, row in ipairs(rows or {}) do
        if (row.entry ~= nil) ~= (state[i] == true) then return true end
    end
    return false
end

-- ── the client's item data ──────────────────────────────────────────────────────────────────────

local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
    return nil
end

local function itemApi(name)
    return type(C_Item) == "table" and C_Item[name] or nil
end

--- An entry's (or a row's) name: its item's, "Well Fed" for food with no item, the weapon enchant
--- by its hand.
function ResultsUsage.Name(e)
    if type(e) ~= "table" then return "?" end
    if e.itemID then
        return NS.Secrets.PlainString(ask(itemApi("GetItemNameByID"), e.itemID)) or L["Item %d"]:format(e.itemID)
    end
    if e.kind == "enchant" then
        return e.slot == MAIN_HAND and L["Weapon enchant (main hand)"] or L["Weapon enchant (off hand)"]
    end
    if e.kind == "food" then return L["Well Fed"] end
    return "?"
end

--- An entry's (or a row's) icon.
function ResultsUsage.Icon(e)
    if type(e) ~= "table" then return ResultsUsage.UNKNOWN_ICON end
    if e.itemID then return ask(itemApi("GetItemIconByID"), e.itemID) or ResultsUsage.UNKNOWN_ICON end
    if e.kind == "enchant" then return ResultsUsage.ENCHANT_ICON end
    if e.kind == "food" then return ResultsUsage.FOOD_ICON end
    return ResultsUsage.UNKNOWN_ICON
end

--- The Used column's icons for `run`, in Entries' order; nil when not recorded.
function ResultsUsage.Icons(run)
    local entries = ResultsUsage.Entries(run)
    if not entries then return nil end
    local out = {}
    for i, e in ipairs(entries) do out[i] = ResultsUsage.Icon(e) end
    return out
end

-- ── the section ─────────────────────────────────────────────────────────────────────────────────

local function tip(p, owner, key, extra)
    local lines = NS.ResultsTips.Usage(key, p.run, extra)
    if lines then Tbl.BelowTip(owner, lines) end
end

local function hoverOver(p, region, key)
    local f = CreateFrame("Frame", nil, p.content)
    f:SetAllPoints(region)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self) tip(p, self, type(key) == "function" and key() or key) end)
    f:SetScript("OnLeave", Tbl.HideTip)
    return f
end

-- A row's hover: the client's own item tooltip with the row's lines after it, or the lines alone.
local function rowTip(p, row)
    local tt, data = GameTooltip, row.data
    if not (tt and data) then return end
    local lines = NS.ResultsTips.Usage("row", p.run, data)
    local shown = false
    if data.itemID then
        tt:SetOwner(row, "ANCHOR_RIGHT")
        shown = tt.SetItemByID and pcall(tt.SetItemByID, tt, data.itemID)
    end
    if not shown then return Tbl.BelowTip(row, lines) end
    tt:AddLine(" ")
    for i = 2, #(lines or {}) do
        local l = lines[i]
        if type(l) == "table" then tt:AddLine(l[1], l[2], l[3], l[4], true) else tt:AddLine(l, 0.9, 0.9, 0.9, true) end
    end
    tt:Show()
end

-- Save's look: live only while the ticks differ from the stored list.
local function paintSave(x)
    NS.HudStates.SetEnabled(x.save, x.rows ~= nil and ResultsUsage.Changed(x.rows, x.state))
end

local function toggle(x, i)
    x.state[i] = not x.state[i] or nil
    x.items[i].check:SetChecked(x.state[i] == true)
    paintSave(x)
end

local function newRow(p, x, i)
    local row = CreateFrame("Frame", nil, p.content)
    row:SetHeight(ResultsUsage.ROW_H)
    row:EnableMouse(true)
    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(ResultsUsage.CHECK, ResultsUsage.CHECK)
    row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ResultsUsage.ICON, ResultsUsage.ICON)
    row.icon:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
    row.check.label = Tbl.Text(row, FONT.TEXT, C.text)
    row.check.label:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.detail = Tbl.Text(row, FONT.TEXT, C.dim)
    row.check:SetScript("OnClick", function() toggle(x, i) end)
    for _, f in ipairs({ row, row.check }) do
        f:HookScript("OnEnter", function() rowTip(p, row) end)
        f:HookScript("OnLeave", Tbl.HideTip)
    end
    return row
end

--- Build the Usage section's parts into the pane `p` (its content `c`), as `p.usage`.
function ResultsUsage.Build(p, c)
    local x = { items = {}, state = {} }
    p.usage = x
    x.title = Tbl.Text(c, FONT.SECTION)
    x.title:SetText(L["Usage"])
    x.save = NS.HudStates.Button(c, L["Save"], function() ResultsUsage.Save(p) end)
    x.save:SetSize(ResultsUsage.SAVE_W, ResultsUsage.BUTTON_H)
    x.none = Tbl.Text(c, FONT.TEXT, C.dim)
    hoverOver(p, x.title, function() return x.rows and "title" or "none" end)
    x.noneHover = hoverOver(p, x.none, function() return x.rows and "empty" or "none" end)
    x.save:HookScript("OnEnter", function(self) tip(p, self, "save") end)
    x.save:HookScript("OnLeave", Tbl.HideTip)
    return x
end

local function fillRow(row, data, ticked)
    row.data = data
    local name = ResultsUsage.Name(data)
    Tbl.SetCheckLabel(row.check, name, 2 + ResultsUsage.ICON + 4)
    row.check:SetChecked(ticked)
    row.icon:SetTexture(ResultsUsage.Icon(data))
    row.detail:SetText(data.entry and ResultsUsage.Detail(data.entry) or "")
    row.nameW = Tbl.BadgeWidth(name, false)
end

-- Whether a redraw of the same run keeps the ticks the player has not saved yet: the rows are the
-- same rows (nothing was saved since) and the ticks differ from them.
local function pending(x, rows, keep)
    if not (keep and not x.saving and x.rows and rows and #rows == #x.rows) then return false end
    return ResultsUsage.Changed(x.rows, x.state)
end

--- Read `p.run`'s usage and paint the section: every row as stored, Save off. `keep` (the same run
--- drawn again: another run recorded, a note saved) keeps the ticks not saved yet, Save still live.
function ResultsUsage.Fill(p, keep)
    local x = p.usage
    local rows = ResultsUsage.Rows(p.run)
    local held = pending(x, rows, keep)
    x.rows, x.saving = rows, nil
    if not held then x.state = {} end
    for i, data in ipairs(x.rows or {}) do
        if not held then x.state[i] = data.entry ~= nil or nil end
        x.items[i] = x.items[i] or newRow(p, x, i)
        fillRow(x.items[i], data, x.state[i] == true)
    end
    for i = #(x.rows or {}) + 1, #x.items do x.items[i]:Hide() end
    x.none:SetText(x.rows and L["Nothing to list: no on-use item or consumable was found at the arm."] or L["Not recorded"])
    paintSave(x)
end

--- Write the ticks (Usage.SetUsed); the window redraws from the bus (a stored run) or the source (a
--- sample run).
--- @return boolean stored
function ResultsUsage.Save(p)
    local x = p.usage
    if not (p.run and x.rows and ResultsUsage.Changed(x.rows, x.state)) then return false end
    -- The redraw this save causes starts from the new list, not from the ticks it just wrote.
    x.saving = true
    local stored = NS.Usage.SetUsed(p.run, ResultsUsage.Ticks(x.rows, x.state))
    if not stored then x.saving = nil end
    return stored
end

local function place(region, parent, px, py)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", px, py)
end

-- One row across `cw`: the name as wide as its estimate (never past what leaves the detail room),
-- the detail after it.
local function layoutRow(p, row, y, cw)
    local left = ResultsUsage.CHECK + 2 + ResultsUsage.ICON + 4
    local nameW = math.max(20, math.min(row.nameW or 0, cw - left - 90))
    place(row, p.content, 0, y)
    row:SetWidth(cw)
    row.check.label:SetWidth(nameW)
    row.detail:ClearAllPoints()
    row.detail:SetPoint("LEFT", row, "LEFT", left + nameW + 8, 0)
    row.detail:SetWidth(math.max(20, cw - left - nameW - 8))
    row:Show()
end

--- The Usage section at `y` across `cw`, its heading SECTION_GAP under the block above it; answers
--- the y beneath.
function ResultsUsage.Layout(p, y, cw)
    local x = p.usage
    y = y - NS.Style.SECTION_GAP
    place(x.title, p.content, 0, y)
    local n = x.rows and #x.rows or 0
    x.save:SetShown(x.rows ~= nil)
    place(x.save, p.content, cw - ResultsUsage.SAVE_W, y)
    y = y - math.max(NS.Style.SECTION_H, ResultsUsage.BUTTON_H) - 2
    x.none:SetShown(n == 0)
    x.noneHover:SetShown(n == 0)
    if n == 0 then
        place(x.none, p.content, 0, y)
        x.none:SetWidth(cw)
        return y - ResultsUsage.LINE_H - 8
    end
    for i = 1, n do layoutRow(p, x.items[i], y - (i - 1) * ResultsUsage.ROW_H, cw) end
    return y - n * ResultsUsage.ROW_H - 8
end
