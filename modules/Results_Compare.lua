local _, NS = ...
-- modules/Results_Compare.lua — the run detail's compare (#7): a stored run beside the best on its
-- board, or beside a run the player picked from a Runs row's right-click menu (*Compare With This
-- Run*). A toggle under the score turns it on; on, the detail draws a second figure column (damage,
-- DPS, the % difference) and the breakdown matched spell by spell, each side's damage and share
-- and the difference, in place of the plain breakdown. modules/Results_Detail.lua builds and places
-- these parts through the functions here; the shell (modules/Results.lua) owns the pick.
--
-- PLAIN NUMBERS ONLY. Both runs are stored records (every figure went through NS.Secrets on its way
-- in), so they may be divided, compared and sorted. Spells, Kpis, Default and Target are pure over
-- the store, so the suites check them without drawing.
--
-- THE OTHER RUN. By default the best on the run's board (NS.Bests, the all-runs board: spec x
-- target type x race length); when the run IS that best, the runner-up on the board; with neither,
-- the toggle is disabled. A picked run wins over both while it is still stored, on any board (a
-- note says when the boards differ). The pick and the toggle are session-only view state, never
-- stored. M3's loadout diff reads the same target through the pane's CompareTarget().

local Compare = {}
NS.ResultsCompare = Compare

local Detail = NS.ResultsDetail
local L = NS.L
local Tbl = NS.ResultsTable
local C = Tbl.COLORS
local FONT = NS.Style.FONT

Compare.VALUE_W = 80        -- each figure column, in the score table and the compared breakdown
Compare.ROW_H = 15          -- one line of the score table
Compare.BAR_H = 22          -- the toggle's line
Compare.CLEAR_W = 78        -- the Clear Pick button
local DASH = "\226\128\148"
local MUTED = "|cff9e9ead%s|r"   -- the caption gray inside a figure (the Time column's tail)

-- ── pure: the comparison ────────────────────────────────────────────────────────────────────────

local function num(v) return type(v) == "number" and v or nil end

local function resultOf(run)
    local r = type(run) == "table" and run.result
    return type(r) == "table" and r or {}
end

-- A run's damage per spell id (a duplicated id adds up), skipping an entry with no id.
local function byID(run)
    local out = {}
    local spells = type(run) == "table" and type(run.spells) == "table" and run.spells or {}
    for _, s in ipairs(spells) do
        if type(s) == "table" and s.id ~= nil then out[s.id] = (out[s.id] or 0) + (num(s.dmg) or 0) end
    end
    return out
end

local function share(dmg, total)
    if dmg and total and total > 0 then return dmg / total * 100 end
    return nil
end

local function idBefore(a, b)
    if type(a) == "number" and type(b) == "number" then return a < b end
    return tostring(a) < tostring(b)
end

-- The run's damage first (a spell it never cast last), then the other's, then the id.
local function rowBefore(a, b)
    local da, db = a.dmgA or -1, b.dmgA or -1
    if da ~= db then return da > db end
    local oa, ob = a.dmgB or -1, b.dmgB or -1
    if oa ~= ob then return oa > ob end
    return idBefore(a.id, b.id)
end

--- The two runs' spells matched by id: { id, dmgA, dmgB, shareA, shareB, delta }, sorted by the run's
--- damage, then the other's. A spell on one side only has nil damage and share on the other; a
--- share is nil when its run's damage total is missing or zero. `delta` is dmgA - dmgB, a missing
--- side counting 0.
--- @param run table  the run shown (side A)
--- @param other table|nil  the run it is compared with (side B)
--- @return table rows
function Compare.Spells(run, other)
    local a, b = byID(run), byID(other)
    local ta, tb = num(resultOf(run).damage), num(resultOf(other).damage)
    local rows = {}
    local function add(id)
        local da, db = a[id], b[id]
        rows[#rows + 1] = { id = id, dmgA = da, dmgB = db, shareA = share(da, ta), shareB = share(db, tb),
                            delta = (da or 0) - (db or 0) }
    end
    for id in pairs(a) do add(id) end
    for id in pairs(b) do if a[id] == nil then add(id) end end
    table.sort(rows, rowBefore)
    return rows
end
Detail.CompareSpells = Compare.Spells

--- `a` against `b` as a percentage of `b`; nil when either is missing or `b` is not above 0.
function Compare.Pct(a, b)
    a, b = num(a), num(b)
    if not (a and b) or b <= 0 then return nil end
    return (a / b - 1) * 100
end

--- The score table's figures: each side's damage and DPS, and the % difference of each.
--- @return table { damageA, damageB, damagePct, dpsA, dpsB, dpsPct }
function Compare.Kpis(run, other)
    local ra, rb = resultOf(run), resultOf(other)
    return { damageA = num(ra.damage), damageB = num(rb.damage), damagePct = Compare.Pct(ra.damage, rb.damage),
             dpsA = num(ra.dps), dpsB = num(rb.dps), dpsPct = Compare.Pct(ra.dps, rb.dps) }
end

--- Whether a run can take part in a compare: a stored record with a result (a lost run has none).
function Compare.Usable(run)
    return type(run) == "table" and run.status ~= "lost" and type(run.result) == "table"
end

--- The default other run: the best on `run`'s board, or the runner-up on it when `run` holds the
--- best; nil with neither (the toggle is then disabled).
--- @param run table
--- @param runs table|nil  defaults to the store (the cached board)
--- @return table|nil other, string|nil kind  "best" | "runnerUp"
function Compare.Default(run, runs)
    if not Compare.Usable(run) then return nil end
    local Bests = NS.Bests
    local key = Bests.Key(run)
    local best = (runs and Bests.Compute(runs) or NS.ResultsSource.Board())[key]
    if not best then return nil end
    if best.id ~= run.id then return best, "best" end
    local rest = {}
    for _, r in ipairs(runs or NS.ResultsSource.All()) do
        if r.id ~= run.id then rest[#rest + 1] = r end
    end
    local second = Bests.Compute(rest)[key]
    if second then return second, "runnerUp" end
    return nil
end

--- The run `run` is compared with: the picked run while it is stored, usable and not `run` itself,
--- else the default.
--- @param run table
--- @param pickID string|nil
--- @return table|nil other, string|nil kind  "picked" | "best" | "runnerUp"
function Compare.Target(run, pickID)
    if not Compare.Usable(run) then return nil end
    local picked = pickID ~= nil and pickID ~= run.id and NS.ResultsSource.Get(pickID) or nil
    if Compare.Usable(picked) then return picked, "picked" end
    return Compare.Default(run)
end

--- Whether two runs sit on the same board (spec, target type, race length).
function Compare.SameBoard(a, b)
    return NS.Bests.Key(a) == NS.Bests.Key(b)
end

--- A run's short label: its date, as the row menu's title shows it.
function Compare.ShortLabel(run)
    return Tbl.Date(type(run) == "table" and run.date, "%d %b %H:%M")
end

--- The toggle's label for `kind`.
function Compare.ToggleLabel(kind, other)
    if kind == "picked" then return L["Compare vs %s"]:format(Compare.ShortLabel(other)) end
    if kind == "runnerUp" then return L["Compare vs runner-up"] end
    return L["Compare vs best"]
end

--- The other column's heading for `kind`.
function Compare.OtherLabel(kind)
    if kind == "picked" then return L["Picked"] end
    if kind == "runnerUp" then return L["Runner-up"] end
    return L["Best"]
end

-- ── text ────────────────────────────────────────────────────────────────────────────────────────

local function figure(v) return v and NS.Format.Number(v) or DASH end

local function pctText(pct) return pct and L["%+.1f%%"]:format(pct) or DASH end

--- A spell figure: its damage, then its share in the caption gray; a dash for a side without it.
function Compare.SpellFigure(dmg, pct)
    if not dmg then return DASH end
    if not pct then return NS.Format.Number(dmg) end
    return NS.Format.Number(dmg) .. " " .. MUTED:format(NS.Format.Pct(pct))
end

--- The difference in damage, signed.
function Compare.DeltaText(delta)
    if type(delta) ~= "number" or delta == 0 then return "0" end
    return (delta > 0 and "+" or "-") .. NS.Format.Number(math.abs(delta))
end

local function paint(fs, value)
    local c = (value == nil or value == 0) and C.dim or (value > 0 and C.green or C.red)
    fs:SetTextColor(c[1], c[2], c[3])
end

-- ── the parts ───────────────────────────────────────────────────────────────────────────────────

-- `frame`'s hover: the compare tooltip for `key` under it (NS.ResultsTips.Compare).
local function hover(p, frame, key)
    frame:EnableMouse(true)
    frame:HookScript("OnEnter", function(self)
        local other, kind = p:CompareTarget(true)
        local lines = NS.ResultsTips.Compare(key, p.run, other, kind)
        if lines then Tbl.BelowTip(self, lines) end
    end)
    frame:HookScript("OnLeave", Tbl.HideTip)
    return frame
end

local function buildBar(p, c, x)
    x.toggle = CreateFrame("CheckButton", nil, c, "UICheckButtonTemplate")
    x.toggle:SetSize(20, 20)
    x.toggle.label = Tbl.Text(x.toggle, FONT.TEXT)
    x.toggle.label:SetPoint("LEFT", x.toggle, "RIGHT", 1, 0)
    x.toggle:SetScript("OnClick", function() p:SetComparing(not p.comparing) end)
    hover(p, x.toggle, "toggle")
    x.clear = NS.HudStates.Button(c, L["Clear Pick"], function() if p.hooks.clearPick then p.hooks.clearPick() end end)
    x.clear:SetSize(Compare.CLEAR_W, 18)
    hover(p, x.clear, "clear")
    x.boards = Tbl.Text(c, FONT.TEXT, C.amber)
    x.boards:SetText(L["Different board: the spec, target type or race length differ."])
    x.boardsHover = CreateFrame("Frame", nil, c)
    x.boardsHover:SetAllPoints(x.boards)
    hover(p, x.boardsHover, "boards")
end

local function buildScore(p, c, x)
    x.score = Tbl.Panel(c)
    hover(p, x.score, "score")
    local f = x.score
    x.head = { Tbl.Text(f, FONT.HEADER), Tbl.Text(f, FONT.HEADER, nil, "RIGHT"), Tbl.Text(f, FONT.HEADER, nil, "RIGHT"),
               Tbl.Text(f, FONT.HEADER, nil, "RIGHT") }
    x.head[2]:SetText(L["This run"])
    x.head[4]:SetText(L["Difference"])
    x.lines = {}
    for i, label in ipairs({ L["Damage"], L["DPS"] }) do
        local line = { Tbl.Text(f, FONT.CAPTION), Tbl.Text(f, FONT.TEXT, C.text, "RIGHT"),
                       Tbl.Text(f, FONT.TEXT, C.dim, "RIGHT"), Tbl.Text(f, FONT.TEXT, C.dim, "RIGHT") }
        line[1]:SetText(label)
        x.lines[i] = line
    end
end

local function buildSpells(_, c, x)
    x.spellHost = CreateFrame("Frame", nil, c)
    x.spellHead = { Tbl.Text(x.spellHost, FONT.HEADER), Tbl.Text(x.spellHost, FONT.HEADER, nil, "RIGHT"),
                    Tbl.Text(x.spellHost, FONT.HEADER, nil, "RIGHT"), Tbl.Text(x.spellHost, FONT.HEADER, nil, "RIGHT") }
    x.spellHead[1]:SetText(L["Spell"])
    x.spellHead[2]:SetText(L["This run"])
    x.spellHead[4]:SetText(L["Difference"])
    x.rows = NS.Pool.New()
end

--- Build the compare's parts into the pane `p` (its content `c`), as `p.cmp`.
function Compare.Build(p, c)
    local x = {}
    p.cmp = x
    buildBar(p, c, x)
    buildScore(p, c, x)
    buildSpells(p, c, x)
    return x
end

--- Resolve the other run for `p.run` and paint the toggle: its label, enabled only with an other
--- run, checked while comparing; Clear Pick only while a pick is in use.
function Compare.Fill(p)
    local x = p.cmp
    local other, kind = Compare.Target(p.run, p.pickID)
    x.other, x.kind = other, kind
    x.data = other and Compare.Spells(p.run, other) or nil
    x.toggle.label:SetText(Compare.ToggleLabel(kind, other))
    local on = other ~= nil
    x.toggle:SetEnabled(on)
    local tc = on and C.text or C.dim
    x.toggle.label:SetTextColor(tc[1], tc[2], tc[3])
    x.toggle:SetChecked(p:Comparing())
    x.head[3]:SetText(Compare.OtherLabel(kind))
    x.spellHead[3]:SetText(Compare.OtherLabel(kind))
    local k = other and Compare.Kpis(p.run, other) or {}
    local values = { { k.damageA, k.damageB, k.damagePct }, { k.dpsA, k.dpsB, k.dpsPct } }
    for i, line in ipairs(x.lines) do
        local v = values[i]
        line[2]:SetText(figure(v[1]))
        line[3]:SetText(figure(v[2]))
        line[4]:SetText(pctText(v[3]))
        paint(line[4], v[3])
    end
end

-- ── layout ──────────────────────────────────────────────────────────────────────────────────────

-- The figure columns' left edges across `width`, right to left: the difference last.
local function columns(width, inset)
    local vw = Compare.VALUE_W
    local diff = width - inset - vw
    return { diff - 2 * vw, diff - vw, diff }
end

local function place(fs, parent, x, y, width)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then fs:SetWidth(width) end
end

--- The toggle's line (and the different-board note) at `y` across `cw`; answers the y beneath.
function Compare.LayoutBar(p, y, cw)
    local x = p.cmp
    place(x.toggle, p.content, 0, y)
    local picked = x.kind == "picked"
    -- Clear Pick follows the pick itself: open on the picked run, the toggle falls back to the
    -- board, but the pick still steers every other run and must stay clearable.
    local hasPick = p.pickID ~= nil and NS.ResultsSource.Get(p.pickID) ~= nil
    x.clear:SetShown(hasPick)
    if hasPick then place(x.clear, p.content, cw - Compare.CLEAR_W, y - 1) end
    y = y - Compare.BAR_H
    local differs = p:Comparing() and picked and not Compare.SameBoard(p.run, x.other)
    x.boards:SetShown(differs)
    x.boardsHover:SetShown(differs)
    if differs then
        place(x.boards, p.content, 0, y, cw)
        y = y - Compare.ROW_H - 2
    end
    return y - 2
end

local function layoutScore(p, y, cw)
    local x, rowH = p.cmp, Compare.ROW_H
    local h = 3 * rowH + 10
    place(x.score, p.content, 0, y)
    x.score:SetSize(cw, h)
    local cols, vw = columns(cw, 8), Compare.VALUE_W
    for line = 0, 2 do
        local set = line == 0 and x.head or x.lines[line]
        local ly = -5 - line * rowH
        place(set[1], x.score, 8, ly, cols[1] - 12)
        for j = 2, 4 do place(set[j], x.score, cols[j - 1], ly, vw) end
    end
    return y - h - 6
end

local function newRow(host)
    local row = CreateFrame("Frame", nil, host)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.texts = { Tbl.Text(row, FONT.TEXT, C.text), Tbl.Text(row, FONT.TEXT, C.text, "RIGHT"),
                  Tbl.Text(row, FONT.TEXT, C.dim, "RIGHT"), Tbl.Text(row, FONT.TEXT, C.dim, "RIGHT") }
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if not self.data then return end
        local _, kind = Compare.TargetOf(self.pane)
        Tbl.SpellTip(Tbl.WindowOf(self.pane.frame), self, self.data.id, NS.ResultsTips.CompareSpell(self.data, kind))
    end)
    row:SetScript("OnLeave", Tbl.HideTip)
    return row
end

local function fillRow(row, data, cw, rowH)
    local cols, vw, icon = columns(cw, 0), Compare.VALUE_W, rowH - 2
    row:SetSize(cw, rowH)
    row.icon:SetSize(icon, icon)
    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon:SetTexture(NS.HudBreakdown.SpellIcon(data.id))
    local t = row.texts
    for j, fs in ipairs(t) do
        fs:ClearAllPoints()
        if j == 1 then
            fs:SetPoint("LEFT", row, "LEFT", icon + 4, 0)
            fs:SetWidth(math.max(20, cols[1] - icon - 8))
        else
            fs:SetPoint("LEFT", row, "LEFT", cols[j - 1], 0)
            fs:SetWidth(vw)
        end
    end
    t[1]:SetText(NS.HudBreakdown.SpellName(data.id))
    t[2]:SetText(Compare.SpellFigure(data.dmgA, data.shareA))
    t[3]:SetText(Compare.SpellFigure(data.dmgB, data.shareB))
    t[4]:SetText(Compare.DeltaText(data.delta))
    paint(t[4], data.delta)
    row.data = data
end

local function layoutSpells(p, y, cw)
    local x = p.cmp
    local data = x.data or {}
    local rowH, pitch = NS.HudBreakdown.RowHeight(), NS.HudBreakdown.Pitch()
    local host = x.spellHost
    place(host, p.content, 0, y)
    host:SetSize(cw, Compare.ROW_H + math.max(1, #data * pitch))
    local cols, vw = columns(cw, 0), Compare.VALUE_W
    place(x.spellHead[1], host, 0, 0, cols[1] - 4)
    for j = 2, 4 do place(x.spellHead[j], host, cols[j - 1], 0, vw) end
    NS.Pool.ReleaseAll(x.rows, function(row) row.data = nil end)
    for i, d in ipairs(data) do
        local row = NS.Pool.Acquire(x.rows, function() return newRow(host) end)
        row.pane = p
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -Compare.ROW_H - (i - 1) * pitch)
        fillRow(row, d, cw, rowH)
    end
    return y - Compare.ROW_H - #data * pitch - 8
end

--- While comparing: the score table and the compared breakdown at `y`; answers the y beneath.
--- Not comparing: both hidden, `y` unchanged.
function Compare.LayoutCompared(p, y, cw)
    local x, on = p.cmp, p:Comparing()
    x.score:SetShown(on)
    x.spellHost:SetShown(on)
    if not on then
        NS.Pool.ReleaseAll(x.rows, function(row) row.data = nil end)
        return y
    end
    y = layoutScore(p, y, cw)
    return layoutSpells(p, y, cw)
end

--- The pane's other run and its kind (nil when there is none).
function Compare.TargetOf(p)
    local x = p and p.cmp
    if not x then return nil end
    return x.other, x.kind
end
