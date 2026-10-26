local _, NS = ...
-- modules/Results_Compare.lua — the run detail's compare (#7): a stored run beside the best on its
-- board, or beside a run the player picked from a Runs row's right-click menu (*Compare With This
-- Run*). A toggle under the score turns it on; on, the detail draws a second figure column (damage,
-- DPS, the difference as an amount and a %) and the breakdown matched spell by spell, each side's
-- damage and share and the difference, in place of the plain breakdown. modules/Results_Detail.lua builds and places
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

Compare.VALUE_W = 80        -- each figure column's least width, in the score table and the compared breakdown
-- The Difference column's least width: the amount and the % ("-710.2K -100.0%", 15 characters at
-- Tbl.BadgeWidth's 6 px and its 4 px pad), at the right of both tables; it fits the 440 px detail of
-- the expanded view at its 1344 px minimum (tests/test_compare.lua).
Compare.DIFF_W = 94
-- The flex layout (the owner's calls, 2026-10-27): the tables fill the detail at any width. The name
-- column takes NAME_SHARE of the width, at most NAME_MAX and never more than the figures leave at
-- their least; the three figure columns grow alike over the rest. In the expanded view's 416 px detail
-- that gives a spell's name about 115 px of text past its icon; a wide collapsed detail stops the name
-- at NAME_MAX and hands every further pixel to the figures.
Compare.NAME_SHARE = 0.32
Compare.NAME_MAX = 200
Compare.NAME_GAP = 4        -- between the name column and this run's
-- The line between This run and the other run, through both tables at full row height: one pixel,
-- a faint see-through gray (the owner's call, 2026-10-27: thinner and dimmer than P11's), centered in
-- the gap between the two columns.
Compare.SEP_W = 1
Compare.SEP_COLOR = { 0.5, 0.5, 0.5, 0.18 }
Compare.ROW_H = 15          -- one line of the score table
Compare.RULE_GAP = 4        -- the space above and below the rule between the two tables
Compare.BAR_H = 22          -- the toggle's line
Compare.CLEAR_W = 78        -- the Clear Pick button
Compare.GAP = 6             -- between this run's column and the other's
Compare.PAD = 4             -- a figure's inset from the edge its column's bar grows from
-- The difference bars (the owner's call, 2026-10-26): flat, muted and see-through, so the white
-- figures read over them; the Results window's soft green and soft red (the 3:00 and 0:30 length hues).
Compare.BAR_UP = { 0.56, 0.80, 0.58, 0.40 }     -- this run is higher
Compare.BAR_DOWN = { 0.86, 0.52, 0.52, 0.40 }   -- the other run is higher
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

--- The two runs' spells matched by id: { id, dmgA, dmgB, shareA, shareB, delta, pct }, sorted by the
--- run's damage, then the other's. A spell on one side only has nil damage and share on the other; a
--- share is nil when its run's damage total is missing or zero. `delta` is dmgA - dmgB, a missing
--- side counting 0; `pct` is dmgA against dmgB (Compare.Pct, a missing dmgA counting 0), nil when
--- the other run has none of it.
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
                            delta = (da or 0) - (db or 0), pct = Compare.Pct(da or 0, db) }
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

local function minus(a, b)
    a, b = num(a), num(b)
    return a and b and a - b or nil
end

--- The score table's figures: each side's damage and DPS, and the difference of each, as an amount
--- (nil when either side is missing) and as a %.
--- @return table { damageA, damageB, damageDelta, damagePct, dpsA, dpsB, dpsDelta, dpsPct }
function Compare.Kpis(run, other)
    local ra, rb = resultOf(run), resultOf(other)
    return { damageA = num(ra.damage), damageB = num(rb.damage), damageDelta = minus(ra.damage, rb.damage),
             damagePct = Compare.Pct(ra.damage, rb.damage),
             dpsA = num(ra.dps), dpsB = num(rb.dps), dpsDelta = minus(ra.dps, rb.dps), dpsPct = Compare.Pct(ra.dps, rb.dps) }
end

--- The score table's two lines as the spell rows' shape: { delta, pct } for damage, then DPS.
function Compare.ScoreRows(k)
    k = k or {}
    return { { delta = k.damageDelta, pct = k.damagePct }, { delta = k.dpsDelta, pct = k.dpsPct } }
end

--- The largest absolute `pct` across a table's rows (0 with none): the length of a full bar.
function Compare.MaxPct(rows)
    local top = 0
    for _, r in ipairs(rows or {}) do
        local p = num(r.pct)
        if p and math.abs(p) > top then top = math.abs(p) end
    end
    return top
end

--- A row's difference on its table's scale, as Compare.Bar takes it: its `pct` against `maxPct`; a
--- row with no % (the other run's figure is 0 or missing) takes the whole scale, its side from
--- `delta`. Nothing (nil, 0) when `delta` is 0 or unknown.
--- @return number|nil diff, number maxDiff
function Compare.Scaled(pct, delta, maxPct)
    delta, pct, maxPct = num(delta), num(pct), num(maxPct) or 0
    if not delta or delta == 0 then return nil, 0 end
    if pct and maxPct > 0 then return pct, maxPct end
    return delta > 0 and 1 or -1, 1
end

--- One row's difference bar: the column it sits in, "this" when `diff` is above 0 (this run is
--- higher) or "other" below it, nil when equal or unknown; and its length, `diff`'s size against
--- `maxDiff` (the table's largest) across `width`, never past it.
--- @return string|nil side, number length
function Compare.Bar(diff, maxDiff, width)
    diff, maxDiff = num(diff), num(maxDiff)
    if not (diff and maxDiff) or diff == 0 or maxDiff <= 0 then return nil, 0 end
    return diff > 0 and "this" or "other", math.min(width, width * math.abs(diff) / maxDiff)
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
    return L["Best run"]
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

-- A color escape for `c` (r, g, b in 0..1) around one %s.
local function escape(c)
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(c[1]), byte(c[2]), byte(c[3])) .. "%s|r"
end
local PCT_UP, PCT_DOWN = escape(Compare.BAR_UP), escape(Compare.BAR_DOWN)

--- The Difference cell (the owner's call, 2026-10-26): the amount, then a space and the % in the
--- bars' muted green or red ("+78.3K +2.3%"); the amount alone with no % (the other run's figure is
--- 0 or missing) or no difference; a dash with no amount. The amount takes its color from paint().
function Compare.DiffText(delta, pct)
    if type(delta) ~= "number" then return DASH end
    pct = num(pct)
    if delta == 0 or not pct then return Compare.DeltaText(delta) end
    return Compare.DeltaText(delta) .. " " .. (delta > 0 and PCT_UP or PCT_DOWN):format(pctText(pct))
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

-- Each column's justify, headers and figures alike: the name, this run (right, against the other's
-- column), the other run (left, against this run's), the difference.
Compare.JUSTIFY = { "LEFT", "RIGHT", "LEFT", "RIGHT" }

-- A table's header line: four FontStrings in `font`, justified as their columns.
local function heads(f, font, colors)
    local out = {}
    for j, justify in ipairs(Compare.JUSTIFY) do out[j] = Tbl.Text(f, font, colors and colors[j], justify) end
    return out
end

-- A difference bar under a line's figures (below the text).
local function newBar(f)
    local bar = f:CreateTexture(nil, "BORDER")
    bar:Hide()
    return bar
end

-- The line between the two runs' columns (Compare.SEP_COLOR), one per table.
local function newSep(f)
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(Tbl.WHITE)
    local c = Compare.SEP_COLOR
    sep:SetVertexColor(c[1], c[2], c[3], c[4])
    return sep
end

-- The score table (the owner's call, 2026-10-26): no box, its columns the spell table's (Compare.Cell),
-- and a faint rule under it, the window's divider gray, between its lines and the spell table's header.
local function buildScore(p, c, x)
    x.score = CreateFrame("Frame", nil, c)
    hover(p, x.score, "score")
    local f = x.score
    x.rule = f:CreateTexture(nil, "ARTWORK")
    x.rule:SetColorTexture(0.24, 0.24, 0.27, 0.85)
    x.scoreSep = newSep(f)
    x.head = heads(f, FONT.HEADER)
    x.head[2]:SetText(L["This run"])
    x.head[4]:SetText(L["Difference"])
    x.lines = {}
    for i, label in ipairs({ L["Damage"], L["DPS"] }) do
        local line = heads(f, FONT.TEXT, { nil, C.text, C.text, C.dim })
        line[1]:SetFontObject(FONT.CAPTION)
        line[1]:SetText(label)
        line.bar = newBar(f)
        x.lines[i] = line
    end
end

local function buildSpells(_, c, x)
    x.spellHost = CreateFrame("Frame", nil, c)
    x.spellHead = heads(x.spellHost, FONT.HEADER)
    x.spellHead[1]:SetText(L["Spell"])
    x.spellHead[2]:SetText(L["This run"])
    x.spellHead[4]:SetText(L["Difference"])
    x.spellSep = newSep(x.spellHost)
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
    Tbl.SetCheckLabel(x.toggle, Compare.ToggleLabel(kind, other))
    local on = other ~= nil
    x.toggle:SetEnabled(on)
    local tc = on and C.text or C.dim
    x.toggle.label:SetTextColor(tc[1], tc[2], tc[3])
    x.toggle:SetChecked(p:Comparing())
    x.head[3]:SetText(Compare.OtherLabel(kind))
    x.spellHead[3]:SetText(Compare.OtherLabel(kind))
    local k = other and Compare.Kpis(p.run, other) or {}
    local values, diffs = { { k.damageA, k.damageB }, { k.dpsA, k.dpsB } }, Compare.ScoreRows(k)
    for i, line in ipairs(x.lines) do
        local v, d = values[i], diffs[i]
        line[2]:SetText(figure(v[1]))
        line[3]:SetText(figure(v[2]))
        line[4]:SetText(Compare.DiffText(d.delta, d.pct))
        paint(line[4], d.delta)
    end
end

-- ── layout ──────────────────────────────────────────────────────────────────────────────────────

local function place(fs, parent, x, y, width)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then fs:SetWidth(width) end
end

--- The columns across `width` (the flex layout, from config): `name`, `value` (this run's and the
--- other's) and `diff` wide, and the figure columns' left edges in order, this run, the other run
--- (Compare.GAP after it) and the difference, which ends at `width`. The name keeps the rounding's
--- pixels (up to two).
--- @return table { name, value, diff, [1] this x, [2] other x, [3] difference x }
function Compare.Columns(width)
    local vw, dw = Compare.VALUE_W, Compare.DIFF_W
    local avail = width - Compare.GAP - Compare.NAME_GAP
    local name = math.min(Compare.NAME_MAX, math.floor(width * Compare.NAME_SHARE), avail - 2 * vw - dw)
    local grow = math.max(0, math.floor((avail - name - 2 * vw - dw) / 3))
    vw, dw = vw + grow, dw + grow
    name = avail - 2 * vw - dw
    local this = name + Compare.NAME_GAP
    return { name = name, value = vw, diff = dw, this, this + vw + Compare.GAP, width - dw }
end
local columns = Compare.Columns

--- The line between this run's column and the other's: its x across `width`, centered in the gap.
function Compare.SeparatorX(width)
    local cols = columns(width)
    return cols[1] + cols.value + math.floor((Compare.GAP - Compare.SEP_W) / 2)
end

--- Column `j`'s text box across `width`: its left x, width and justify, the one geometry of both
--- tables (the score table's and the spell table's headers and every line under them), so their
--- columns line up. The name column runs from the left edge to this run's; a spell row's name then
--- steps past its icon. This run's figure stops PAD short of its right edge, the other's starts PAD
--- into its column: each sits off the edge its bar grows from.
--- @return number x, number width, string justify
function Compare.Cell(j, width)
    local cols, pad = columns(width), Compare.PAD
    local vw, justify = cols.value, Compare.JUSTIFY[j]
    if j == 1 then return 0, cols.name, justify end
    if j == 2 then return cols[1], vw - pad, justify end
    if j == 3 then return cols[2] + pad, vw - pad, justify end
    return cols[3], cols.diff, justify
end

--- The separator's width at effective scale `scale`: SEP_W physical pixels in UI units (the client's
--- PixelUtil factor over the scale), so no UI scale draws it two or three pixels wide; SEP_W itself
--- where PixelUtil or a numeric scale is missing.
function Compare.SepWidth(scale)
    if not (PixelUtil and type(scale) == "number" and scale > 0) then return Compare.SEP_W end
    return Compare.SEP_W * PixelUtil.GetPixelToUIUnitFactor() / scale
end

-- A table's separator at `x` in `parent`, `h` tall from its top, one physical pixel wide. The scale is
-- the window's, not a geometry read: the width stays the config's SEP_W in physical pixels.
local function placeSep(sep, parent, x, h)
    sep:ClearAllPoints()
    sep:SetPoint("TOPLEFT", parent, "TOPLEFT", x, 0)
    sep:SetWidth(Compare.SepWidth(sep:GetEffectiveScale()))
    sep:SetHeight(h)
    sep:Show()
end

-- A header or line of four FontStrings at `y` in `parent`, each in its column's box (Compare.Cell).
local function placeLine(set, parent, y, width)
    for j = 1, 4 do
        local cx, w = Compare.Cell(j, width)
        place(set[j], parent, cx, y, w)
    end
end

-- A line's difference bar, at `y` from `point` of `parent`: in this run's column it grows left from
-- the column's right edge, in the other's right from its left edge; hidden when the runs are equal.
local function placeBar(bar, parent, point, y, h, cols, diff, maxDiff)
    local vw = cols.value
    local side, len = Compare.Bar(diff, maxDiff, vw)
    bar.side = side
    bar:SetShown(side ~= nil)
    if not side then return end
    local c = side == "this" and Compare.BAR_UP or Compare.BAR_DOWN
    bar:SetColorTexture(c[1], c[2], c[3], c[4])
    bar:ClearAllPoints()
    bar:SetPoint(point, parent, point, side == "this" and cols[1] + vw - len or cols[2], y)
    bar:SetWidth(len)
    bar:SetHeight(h)
end

--- The toggle's line (and the different-board note) at `y` across `cw`; answers the y beneath.
function Compare.LayoutBar(p, y, cw)
    local x = p.cmp
    x.toggle:Show()
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

-- The score table at `y`: its header and two lines in the spell table's columns, the rule under them.
local function layoutScore(p, y, cw)
    local x, rowH, gap = p.cmp, Compare.ROW_H, Compare.RULE_GAP
    local ruleY = -3 * rowH - gap
    place(x.score, p.content, 0, y)
    x.score:SetSize(cw, -ruleY + 1)
    local cols = columns(cw)
    local diffs = Compare.ScoreRows(x.other and Compare.Kpis(p.run, x.other))
    local maxPct = Compare.MaxPct(diffs)
    for line = 0, 2 do
        local set = line == 0 and x.head or x.lines[line]
        local ly = -line * rowH
        placeLine(set, x.score, ly, cw)
        if line > 0 then
            local d = diffs[line]
            placeBar(set.bar, x.score, "TOPLEFT", ly + 1, rowH - 1, cols, Compare.Scaled(d.pct, d.delta, maxPct))
        end
    end
    placeSep(x.scoreSep, x.score, Compare.SeparatorX(cw), 3 * rowH)
    place(x.rule, x.score, 0, ruleY, cw)
    x.rule:SetHeight(1)
    return y + ruleY - 1 - gap
end

local function newRow(host)
    local row = CreateFrame("Frame", nil, host)
    -- The stripe: the Results list's tint on every other row, down through the gap under it.
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetTexture(Tbl.WHITE)
    row.bg:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -NS.HudBreakdown.ROW_GAP)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.bar = newBar(row)
    row.texts = heads(row, FONT.TEXT, { C.text, C.text, C.text, C.dim })
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if not self.data then return end
        local _, kind = Compare.TargetOf(self.pane)
        Tbl.SpellTip(Tbl.WindowOf(self.pane.frame), self, self.data.id, NS.ResultsTips.CompareSpell(self.data, kind))
    end)
    row:SetScript("OnLeave", Tbl.HideTip)
    return row
end

local function fillRow(row, data, index, cw, rowH, maxPct)
    local cols, icon = columns(cw), rowH - 2
    row:SetSize(cw, rowH)
    row.bg:SetVertexColor(1, 1, 1, Tbl.StripeAlpha(index))
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
            local cx, w = Compare.Cell(j, cw)
            fs:SetPoint("LEFT", row, "LEFT", cx, 0)
            fs:SetWidth(w)
        end
    end
    placeBar(row.bar, row, "LEFT", 0, rowH, cols, Compare.Scaled(data.pct, data.delta, maxPct))
    t[1]:SetText(NS.HudBreakdown.SpellName(data.id))
    t[2]:SetText(Compare.SpellFigure(data.dmgA, data.shareA))
    t[3]:SetText(Compare.SpellFigure(data.dmgB, data.shareB))
    t[4]:SetText(Compare.DiffText(data.delta, data.pct))
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
    placeLine(x.spellHead, host, 0, cw)
    placeSep(x.spellSep, host, Compare.SeparatorX(cw), Compare.ROW_H + #data * pitch)
    local maxPct = Compare.MaxPct(data)
    NS.Pool.ReleaseAll(x.rows, function(row) row.data = nil end)
    for i, d in ipairs(data) do
        local row = NS.Pool.Acquire(x.rows, function() return newRow(host) end)
        row.pane = p
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -Compare.ROW_H - (i - 1) * pitch)
        fillRow(row, d, i, cw, rowH, maxPct)
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

--- The Spell breakdown folded (the detail's collapsible sections): every part of the compare hidden,
--- the toggle with them; the compare itself (on or off, the pick) is kept for the unfold.
function Compare.Fold(p)
    local x = p.cmp
    for _, part in ipairs({ x.toggle, x.clear, x.boards, x.boardsHover, x.score, x.spellHost }) do part:Hide() end
    NS.Pool.ReleaseAll(x.rows, function(row) row.data = nil end)
end

--- The pane's other run and its kind (nil when there is none).
function Compare.TargetOf(p)
    local x = p and p.cmp
    if not x then return nil end
    return x.other, x.kind
end
