local _, NS = ...
-- modules/Results_Insights.lua — the Results window's Insights tab (#12), in place of the Bests board
-- (dropped by the owner, 2026-10-28; NS.Bests stays as a data module). LootHistory's Insights tab in
-- DpsRace's terms: a filter bar, ten stat cards and the chart sections over the runs the filters pass,
-- all fed by one stats pass (docs/superpowers/plans/2026-10-28-ignore-list-insights.md, "Insights
-- analysis", and the owner's feedback round, step V). Spec Comparison and Consistency sit under a
-- strip of board tabs, one per target x length pair, since DPS compares only within a board.
--
-- THREE FILES. modules/Results_InsightsData.lua is the pure half (the filters, the faceted options,
-- the stats pass); modules/Results_InsightsCharts.lua draws the widgets through a host table; this
-- file builds the tab, turns the stats into the renderers' rows and lays the sections out.
--
-- THE VIEW CONTRACT is the Runs tab's, so the shell (modules/Results.lua) treats both tabs alike:
-- frame, Layout, Resize, Refresh, Count, SetFilter. The shell redraws the shown tab on RUN_SAVED,
-- RUNS_CHANGED, a SETTINGS_CHANGED on the late-cast ignore list, your training dummies (#9) or the
-- profile, and a source swap
-- (test mode, a sim): Refresh re-reads NS.ResultsSource.All(), so the samples fill the tab.
--
-- THE FILTERS (D-11) open wide: every character, spec, target, length and date. Each dropdown lists
-- what the OTHER filters leave, with counts (InsightsData.Options), and a selection that no run
-- matches falls back to All (InsightsData.Normalize), the dropdown just changed never. Save / Reset /
-- Clear keep the view at profile.views.insights (named non-setting state, docs/schema.md). Closed, a
-- dropdown names the choices it holds, not the runs (InsightsData.ClosedLabel); open, each row keeps
-- its run count.
--
-- POOLED. Every widget a section draws comes from the chart context's pools: a layout pass releases
-- them all, then each section acquires what it shows, so a second pass builds no frame. Resize (the
-- grip held) re-plans the bar and the scroll frame only; the release's Layout redraws.

local Insights = {}
NS.ResultsInsights = Insights

local L = NS.L
local Tbl = NS.ResultsTable
local C = Tbl.COLORS

local FILTER_H = 32         -- one row of the filter bar
local DROPDOWNS = {         -- the bar's dropdowns, left to right, and their least widths
    { key = "char", width = 110 }, { key = "spec", width = 96 }, { key = "category", width = 96 },
    { key = "length", width = 88 }, { key = "date", width = 100 },
}
local CHECKS = {
    { key = "cleanOnly", label = "Clean only", width = 84 },
    { key = "includeIncomplete", label = "Include incomplete", width = 128 },
}
local VIEW_BUTTONS = {
    { key = "save", label = "Save", act = "SaveView",
      tip = "Save these filters as this profile's default view of Insights." },
    { key = "reset", label = "Reset", act = "ResetView",
      tip = "Delete the saved view and go back to the stock one: every character, spec, target, length and date." },
    { key = "clear", label = "Clear", act = "ClearView",
      tip = "Go back to the saved view (the stock one when none is saved). The saved view is kept." },
}
local VIEW_BUTTON_W = 52
local GAP = 6
local MARGIN = GAP + 2      -- the bar's left margin, and its right one once the dropdowns stretch

local PAD = 8               -- the content's inner margin
local CARD_COLS, CARD_GAP = 4, 8
local WHEEL_STEP = 40       -- px one notch of the mouse wheel moves
local PROGRESS_DAYS_FROM = 60   -- section A buckets by day above this many runs
local LIST_VALUE_W = { late = 48, bests = 120 }
local BOARD_TAB_W, BOARD_TAB_H = 120, 22    -- a board tab ("Boss-level · 2:00" fits)

-- ── the filter bar, planned (pure) ──────────────────────────────────────────────────────────────

-- Place the bar's controls by the dropdowns' `widths`. One row: the dropdowns, the checks, then
-- Save / Reset / Clear. Two rows: the dropdowns on the first; the checks and the buttons on the
-- second, the buttons right-aligned under the last dropdown.
local function placeBar(oneRow, widths)
    local plan = { dropdowns = {}, checks = {}, buttons = {}, widths = widths, oneRow = oneRow,
                   y = oneRow and -6 or -(FILTER_H - 2) }
    local x = MARGIN
    for _, spec in ipairs(DROPDOWNS) do
        plan.dropdowns[spec.key] = x
        x = x + widths[spec.key] + GAP
    end
    local lastRight = x - GAP
    if not oneRow then x = MARGIN end
    for _, spec in ipairs(CHECKS) do
        plan.checks[spec.key] = x
        x = x + spec.width + GAP
    end
    local right = oneRow and x + #VIEW_BUTTONS * (VIEW_BUTTON_W + GAP) - GAP or lastRight
    plan.right = math.max(right, lastRight, x - GAP)
    for i = #VIEW_BUTTONS, 1, -1 do
        plan.buttons[VIEW_BUTTONS[i].key] = right
        right = right - VIEW_BUTTON_W - GAP
    end
    return plan
end

-- The least widths grown by `extra` px between them, in proportion; the last takes the rounding.
local function stretched(extra)
    local total = 0
    for _, spec in ipairs(DROPDOWNS) do total = total + spec.width end
    local widths, given = {}, 0
    for i, spec in ipairs(DROPDOWNS) do
        local add = i == #DROPDOWNS and extra - given or math.floor(extra * spec.width / total)
        widths[spec.key] = spec.width + add
        given = given + add
    end
    return widths
end

--- The bar's plan across `width` (the window body's): one row when everything fits on it, else two
--- (the collapsed window's 904 px minimum takes two). The dropdowns take their least widths, then
--- share what is left, so the bar ends MARGIN short of its right edge. Pure: no frame is read.
--- @return table plan  { oneRow, dropdowns = { [key] = x }, widths, checks, buttons (right x), y, right }
function Insights.BarPlan(width)
    local widths = {}
    for _, spec in ipairs(DROPDOWNS) do widths[spec.key] = spec.width end
    local plan = placeBar(true, widths)
    local oneRow = type(width) == "number" and width - MARGIN >= plan.right
    if not oneRow then plan = placeBar(false, widths) end
    local extra = type(width) == "number" and math.floor(width - MARGIN - plan.right) or 0
    if extra <= 0 then return plan end
    return placeBar(oneRow, stretched(extra))
end

-- ── words ───────────────────────────────────────────────────────────────────────────────────────

local Format = NS.Format

local function specName(specID, fallback)
    return (Tbl.SpecInfo(specID, fallback)) or L["Unknown spec"]
end

-- "Beast Mastery · Cleave · 0:30": a board as the tooltips name it.
local function boardText(specID, spec, category, length)
    return L["%s \194\183 %s \194\183 %s"]:format(specName(specID, spec), NS.Dummies.Label(category or "other"),
        Format.Length(length))
end

local function runBoard(run)
    local char = run.char or {}
    return boardText(char.specID, char.spec, NS.Dummies.CategoryOf(run.target), run.race and run.race.length)
end

local function pct(x)
    return Format.Pct((x or 0) * 100)
end

-- Seconds as practice time: "1h 20m", or "12m 30s" under an hour.
local function duration(secs)
    secs = math.floor((secs or 0) + 0.5)
    local h, m = math.floor(secs / 3600), math.floor(secs % 3600 / 60)
    if h > 0 then return L["%dh %02dm"]:format(h, m) end
    return L["%dm %02ds"]:format(m, secs % 60)
end

local function dps(v)
    return Format.Number(v)
end

-- ONE DATE FORMAT (plan step V-j): the day as the Runs tab writes it ("26 Oct"), its year added
-- only when it is not this year's, and the time after it where the moment matters (a run's hover).
-- A strip's axis label is the day alone; its hover names the year.
local DAY_FMT, TIME_FMT = "%d %b", " %H:%M"

local function dayText(t)
    local text = Tbl.Date(t, DAY_FMT)
    if Tbl.Date(t, "%Y") ~= Tbl.Date(time(), "%Y") then text = text .. Tbl.Date(t, " %Y") end
    return text
end

local function whenText(t)
    return dayText(t) .. Tbl.Date(t, TIME_FMT)
end

-- ── the cards (10, LootHistory's: 4 a row, a wide one spans 2, the figure gold unless it means more)

local DASH = "\226\128\148"

-- Three even rows: the counts, then the context, then the two wide ones (Insights.CardGrid).
local CARDS = {
    { key = "runs", caption = "Races run" },
    { key = "time", caption = "Time raced" },
    { key = "avg", caption = "Avg % of board best" },
    { key = "clean", caption = "Clean runs" },
    { key = "newBests", caption = "New bests set" },
    { key = "chars", caption = "Characters" },
    { key = "specs", caption = "Specs" },
    { key = "activeDays", caption = "Active days" },
    { key = "best", caption = "Best DPS", wide = true },
    { key = "span", caption = "Date range", wide = true },
}
Insights.CARDS = CARDS

-- A share's figure color: green at GOOD_SHARE or above, red under POOR_SHARE, else the gold default.
local GOOD_SHARE, POOR_SHARE = 0.9, 0.7

local function shareColor(x)
    if x >= GOOD_SHARE then return C.green end
    if x < POOR_SHARE then return C.red end
    return nil
end

local function runsWord(n)
    return n == 1 and L["1 run"] or L["%d runs"]:format(n)
end

-- Each card's figure, its hover (lines: a title, then strings), its caption when it changes, and its
-- figure's color when it means something (nil: gold).
local CARD_FILL = {
    runs = function(t)
        return tostring(t.runs), { L["Races run"], L["The runs these filters pass."] }
    end,
    time = function(t)
        return duration(t.timeRaced), { L["Time raced"],
            L["The race lengths added up; an incomplete run counts its time in combat."] }
    end,
    best = function(t)
        local b = t.best
        if not b then return DASH, { L["Best DPS"], L["No complete run in these filters."] } end
        local board = runBoard(b.run)
        return dps(b.dps), { L["Best DPS"], board, whenText(b.run.date) },
            L["%s \194\183 %s"]:format(L["Best DPS"], board), Tbl.ClassColor(b.run.char and b.run.char.class)
    end,
    avg = function(t)
        if t.oneBoard then
            return dps(t.avgDps), { L["Avg DPS"], L["The complete runs' average, all on one board."] }, L["Avg DPS"]
        end
        if not t.avgPct then return DASH, { L["Avg % of board best"], L["No complete run in these filters."] } end
        return pct(t.avgPct), { L["Avg % of board best"],
            L["Each complete run against the best on its own board (spec, target and length), averaged."] },
            nil, shareColor(t.avgPct)
    end,
    clean = function(t)
        if t.runs == 0 then return DASH end
        return pct(t.clean / t.runs), { L["Clean runs"], L["%d of %d runs carry no flag."]:format(t.clean, t.runs),
            L["Late casts on the ignore list do not flag a run."] }, nil, shareColor(t.clean / t.runs)
    end,
    newBests = function(t)
        return tostring(t.newBests), { L["New bests set"],
            L["Runs that beat an earlier best on their board, within these filters. A board's first run does not count."] },
            nil, t.newBests > 0 and C.green or nil
    end,
    chars = function(t)
        return tostring(t.chars), { L["Characters"], L["The characters with a run in these filters."] }
    end,
    specs = function(t)
        return tostring(t.specs), { L["Specs"], L["The specs with a run in these filters."] }
    end,
    activeDays = function(t)
        return tostring(t.activeDays), { L["Active days"], L["%d days with a run."]:format(t.activeDays) }
    end,
    span = function(t)
        if not t.first then return DASH end
        local text = L["%s to %s"]:format(dayText(t.first), dayText(t.last))
        return text, { L["Date range"], text, runsWord(t.runs) }
    end,
}

-- The last row's cards share the whole row when they leave columns empty (fractional spans).
local function stretchLastRow(cells, cols)
    local lastRow, used, members = cells[#cells].row, 0, {}
    for _, c in ipairs(cells) do
        if c.row == lastRow then used, members[#members + 1] = used + c.span, c end
    end
    if used >= cols then return end
    local col = 0
    for _, c in ipairs(members) do
        c.col, c.span = col, c.span * cols / used
        col = col + c.span
    end
end

--- The cards' grid: each def's { col, row, span } across `cols` columns (a wide def spans 2, and
--- moves to the next row when it does not fit), and the number of rows. A last row left short is
--- shared out among its cards, so no row stands half empty. Pure.
--- @return table cells, number rows
function Insights.CardGrid(defs, cols)
    local cells, col, row = {}, 0, 0
    for i, def in ipairs(defs) do
        local span = def.wide and 2 or 1
        if col + span > cols then col, row = 0, row + 1 end
        cells[i] = { col = col, row = row, span = span }
        col = col + span
    end
    if #cells == 0 then return cells, 0 end
    stretchLastRow(cells, cols)
    return cells, row + 1
end

-- ── the sections, each one turning the stats into its renderer's rows ───────────────────────────

-- A: one column per run in date order, its height the run's % of its board's best (raw DPS on one
-- board), in its class color; above PROGRESS_DAYS_FROM runs, one column per day (the day's average).
local function progressionPerRun(list, raw)
    local out, lastDay = {}, nil
    for i, e in ipairs(list) do
        local run = e.run
        local day = Tbl.Date(run.date, "%Y-%m-%d")
        out[i] = { count = raw and e.dps or e.pct, color = Tbl.ClassColor(run.char and run.char.class),
                   label = day ~= lastDay and Tbl.Date(run.date, DAY_FMT) or nil,
                   info = { runBoard(run), whenText(run.date), L["%s DPS"]:format(dps(e.dps)),
                            L["%s of board best"]:format(pct(e.pct)) } }
        lastDay = day
    end
    return out
end

-- A day is keyed with its year (history can keep runs for years, docs/schema.md history.keepDays), so
-- the same date a year apart is two columns; the hover names the year.
local function progressionPerDay(list, raw)
    local out, byDay = {}, {}
    for _, e in ipairs(list) do
        local day = Tbl.Date(e.run.date, "%Y-%m-%d")
        local b = byDay[day]
        if not b then
            b = { label = Tbl.Date(e.run.date, DAY_FMT), sum = 0, n = 0, day = dayText(e.run.date) }
            byDay[day] = b
            out[#out + 1] = b
        end
        b.sum, b.n = b.sum + (raw and e.dps or e.pct), b.n + 1
    end
    for _, b in ipairs(out) do
        b.count = b.sum / b.n
        local avg = raw and L["Avg %s DPS"]:format(dps(b.count)) or L["Avg %s of board best"]:format(pct(b.count))
        b.info = { b.day, b.n == 1 and L["1 run"] or L["%d runs"]:format(b.n), avg }
    end
    return out
end

-- A's legend: one chip per spec in its class color, in the order the specs first raced, the hover
-- naming its run count. Two specs of one class share a color, so the chip's name tells them apart.
local function progressionLegend(list)
    local rows, bySpec = {}, {}
    for _, e in ipairs(list) do
        local char = e.run.char or {}
        local key = char.specID or char.spec or "?"
        local row = bySpec[key]
        if not row then
            row = { label = specName(char.specID, char.spec), color = Tbl.ClassColor(char.class), n = 0 }
            bySpec[key], rows[#rows + 1] = row, row
        end
        row.n = row.n + 1
    end
    for _, row in ipairs(rows) do row.value = row.n == 1 and L["1 run"] or L["%d runs"]:format(row.n) end
    return rows
end

local function layoutProgression(self, stats, y, w, pad)
    local list, raw = stats.progression, stats.totals.oneBoard ~= nil
    local buckets = #list > PROGRESS_DAYS_FROM and progressionPerDay(list, raw) or progressionPerRun(list, raw)
    local H = self.headers
    H.progression:SetText(raw and L["DPS Progression"] or L["DPS Progression (% of board best)"])
    y = self.ctx:renderStrip(self.ctx:Pool("progression"), H.progression, self.strips.progression, buckets,
        y, w, pad, (not raw) and 1 or nil)
    if #buckets == 0 then return y end
    return self.ctx:renderLegend(self.ctx:Pool("progressionLegend"), progressionLegend(list),
        y + NS.InsightsCharts.K.SECTION_GAP, w, pad, pad)
end

-- B, on the board tab shown: the specs side by side, by best DPS.
local function layoutSpecs(self, board, y, w, pad)
    local rows = {}
    for _, r in ipairs(board.specs) do
        local name = specName(r.specID, r.spec)
        rows[#rows + 1] = { label = name, color = Tbl.ClassColor(r.class), frac = r.best, value = dps(r.best),
                            tip = { name, L["Best %s DPS"]:format(dps(r.best)), L["Avg %s DPS"]:format(dps(r.avg)),
                                    runsWord(r.n) } }
    end
    return self.ctx:renderBarSection(self.ctx:Pool("specs"), self.headers.specs, rows, y, w, pad)
end

-- C, on the board tab shown: per spec with three runs or more, a range from its worst run to its best
-- with a mark at its average, the most consistent first (plan step V-i: shares near 100% on a 0-based
-- track all look full). The value is the average run's share of the spec's best.
local function layoutConsistency(self, board, y, w, pad)
    local rows = {}
    for _, r in ipairs(board.consistency) do
        local name = specName(r.specID, r.spec)
        rows[#rows + 1] = { label = name, color = Tbl.ClassColor(r.class), lo = r.worst, hi = r.best, mark = r.avg,
                            value = pct(r.avgPct),
                            tip = { name, L["Best %s DPS"]:format(dps(r.best)), L["Avg %s DPS"]:format(dps(r.avg)),
                                    L["Worst %s DPS"]:format(dps(r.worst)),
                                    L["Spread (CV) %s"]:format(r.cv and pct(r.cv) or DASH), runsWord(r.n) } }
    end
    return self.ctx:renderRangeSection(self.ctx:Pool("consistency"), self.headers.consistency, rows, y, w, pad,
        self.ctx:Pool("consistencyScale"), dps)
end

-- A board tab: LootHistory's tab look in the small font, gold and underlined when picked, gray when
-- not. Pooled through the chart context; the click and the hover are the bind's.
local function makeBoardTab(ctx, parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(BOARD_TAB_W, BOARD_TAB_H)
    b.label = Tbl.Text(b, Tbl.FONT.TEXT, nil, "CENTER")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.underline = b:CreateTexture(nil, "OVERLAY")
    b.underline:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
    b.underline:SetHeight(2)
    b.underline:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 8, 0)
    b.underline:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 0)
    b:SetScript("OnClick", function(self2) if self2._onClick then self2._onClick() end end)
    b:SetScript("OnEnter", function(self2) ctx:showTip(self2, self2._tip) end)
    b:SetScript("OnLeave", function() ctx.hideTip() end)
    return b
end

local function findBoard(tabs, key)
    for _, t in ipairs(tabs) do
        if t.key == key then return t end
    end
    return nil
end

-- The board tabs from the cursor, wrapping at the content's edge, and a rule under them.
local function placeBoardTabs(self, tabs, y, w, pad)
    local pool, x = self.ctx:Pool("boardTabs"), pad
    for _, t in ipairs(tabs) do
        if x > pad and x + BOARD_TAB_W > w - pad then x, y = pad, y - BOARD_TAB_H end
        local b = self.ctx:acquire(pool, makeBoardTab)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
        local on, name = t.key == self.boardKey, L["%s \194\183 %s"]:format(NS.Dummies.Label(t.category),
            Format.Length(t.length))
        local c = on and C.gold or NS.Style.TAB_IDLE
        b.label:SetText(name)
        b.label:SetTextColor(c[1], c[2], c[3])
        b.underline:SetShown(on)
        b._tip, b._onClick = { name, runsWord(t.n) }, function() self:SelectBoard(t.key) end
        x = x + BOARD_TAB_W
    end
    y = y - BOARD_TAB_H
    self.boardRule:ClearAllPoints()
    self.boardRule:SetPoint("TOPLEFT", self.content, "TOPLEFT", pad, y)
    self.boardRule:SetWidth(math.max(1, w - pad * 2))
    self.boardRule:Show()
    return y - NS.InsightsCharts.K.BAR_GAP * 2
end

-- B and C under the board tabs (plan step V-f): the tab picked while it stays present, else the most
-- raced board's. Nothing with no complete run.
local function layoutBoards(self, stats, y, w, pad)
    local tabs = stats.boardTabs
    if #tabs == 0 then return y end
    local board = findBoard(tabs, self.boardKey) or findBoard(tabs, stats.boardTop)
    self.boardKey = board.key
    y = self.ctx:placeHeader(self.headers.boards, y, pad)
    y = placeBoardTabs(self, tabs, y, w, pad)
    y = layoutSpecs(self, board, y, w, pad)
    return layoutConsistency(self, board, y, w, pad)
end

-- D: the races per character, in its class color.
local function layoutCharacters(self, stats, y, w, pad)
    local rows = {}
    for _, e in ipairs(stats.byChar) do
        rows[#rows + 1] = { label = e.name, color = Tbl.ClassColor(e.class), frac = e.n, value = tostring(e.n),
                            tip = { e.key, runsWord(e.n) } }
    end
    return self.ctx:renderBarSection(self.ctx:Pool("chars"), self.headers.chars, rows, y, w, pad)
end

-- E and F split each character's races: by target in the category colors, by length in the length
-- colors. `of` names the character entry's counts; `color` and `name` read one key.
local SPLITS = {
    charTarget = { of = "byCategory",
                   color = function(cat) return Tbl.CATEGORY_COLORS[cat] or Tbl.CATEGORY_COLORS.other end,
                   name = function(cat) return NS.Dummies.Label(cat) end },
    charLength = { of = "byLength", color = function(len) return Tbl.LengthColor(len) end,
                   name = function(len) return Format.Length(len) end },
}

-- A split section: one stacked bar per character over `keys` in order, then the keys' legend.
local function layoutSplit(self, key, chars, keys, y, w, pad)
    local split, top, rows, legend = SPLITS[key], 1, {}, {}
    for _, e in ipairs(chars) do top = math.max(top, e.n) end
    for _, e in ipairs(chars) do
        local segs = {}
        for _, k in ipairs(keys) do
            local n = e[split.of][k]
            if n then
                segs[#segs + 1] = { frac = n / top, color = split.color(k), tip = L["%s: %d"]:format(split.name(k), n) }
            end
        end
        rows[#rows + 1] = { label = e.name, labelColor = Tbl.ClassColor(e.class), value = tostring(e.n), segments = segs }
    end
    y = self.ctx:renderStackedBarSection(self.ctx:Pool(key), self.headers[key], rows, y, w, pad)
    if #rows == 0 then return y end
    for _, k in ipairs(keys) do legend[#legend + 1] = { label = split.name(k), color = split.color(k) } end
    return self.ctx:renderLegend(self.ctx:Pool(key .. "Legend"), legend, y + NS.InsightsCharts.K.SECTION_GAP, w, pad)
end

-- E: each character's races split by target.
local function layoutCharTarget(self, stats, y, w, pad)
    local E = stats.byCharTarget
    return layoutSplit(self, "charTarget", E.rows, E.categories, y, w, pad)
end

-- F: each character's races split by length (plan step V-g, in place of Races By Length).
local function layoutCharLength(self, stats, y, w, pad)
    local F = stats.byCharLength
    return layoutSplit(self, "charLength", F.rows, F.lengths, y, w, pad)
end

-- A list panel across the content, or nothing (the panel hidden) with no rows.
local function listSection(self, key, rows, y, w, pad)
    local panel = self.panels[key]
    if #rows == 0 then panel:Hide(); return y end
    local h = self.ctx:renderListPanel(self.ctx:Pool(key), panel, rows, y, w - pad * 2, pad, LIST_VALUE_W[key])
    return y - h - NS.InsightsCharts.K.SECTION_GAP
end

-- G's right-click: the ignore list's own menu (LateIgnore.Menu) over a run holding that one cast, so
-- it offers Ignore or Stop ignoring as the result card does. Never on the samples (D-7), never for
-- a cast with no spell ID (it cannot be ignored, D-5).
local function lateMenu(id)
    return function(row, button)
        if button ~= "RightButton" or NS.ResultsSource.IsMock() then return end
        NS.LateIgnore.Menu({ flags = { lateCasts = { { spellID = id } } } }, row)
    end
end

local function lateRow(e, ignored)
    local name = e.unknown and L["Unknown spell"] or NS.HudBreakdown.SpellName(e.id)
    local n = e.count == 1 and L["1 late cast"] or L["%d late casts"]:format(e.count)
    local row = { name = name, right = tostring(e.count), onClick = (not e.unknown) and lateMenu(e.id) or nil }
    if ignored then
        row.name, row.nameColor = L["%s (ignored)"]:format(name), C.dim
        row.tip = { name, n, L["On the ignore list: no flag. Right-click to stop ignoring it."] }
    elseif e.unknown then
        row.tip = { name, n, L["No spell ID was recorded, so it cannot be ignored."] }
    else
        row.tip = { name, n, L["Each one flags its run. Right-click to ignore it."] }
    end
    return row
end

-- G: the late casts by spell, the counted ones first, the ignored ones dimmed and tagged. The panel
-- shows ten rows (K.LIST_MAX); the ignored ones keep up to half of them however many spells count, so
-- the right-click that stops ignoring one is never cut off.
local function layoutLateCasts(self, stats, y, w, pad)
    local counted, ignored = stats.lateBySpell.counted, stats.lateBySpell.ignored
    local max = NS.InsightsCharts.K.LIST_MAX
    local nIgnored = math.min(#ignored, math.max(max - #counted, math.floor(max / 2)))
    local rows = {}
    for n = 1, math.min(#counted, max - nIgnored) do rows[#rows + 1] = lateRow(counted[n], false) end
    for n = 1, nIgnored do rows[#rows + 1] = lateRow(ignored[n], true) end
    return listSection(self, "late", rows, y, w, pad)
end

-- I: the races per day, the days with none included.
local function layoutPerDay(self, stats, y, w, pad)
    local buckets = {}
    for i, d in ipairs(stats.byDay) do
        buckets[i] = { count = d.n, label = Tbl.Date(d.day, DAY_FMT), info = L["%s: %s"]:format(dayText(d.day), runsWord(d.n)) }
    end
    return self.ctx:renderStrip(self.ctx:Pool("perDay"), self.headers.perDay, self.strips.perDay, buckets, y, w, pad)
end

-- J: the damage tail after the buzzer in 5 s buckets, the last open-ended.
local function layoutTail(self, stats, y, w, pad)
    local rows, any = {}, false
    for i, b in ipairs(stats.tail) do
        any = any or b.n > 0
        local label = b.hi and L["%d-%d s"]:format(b.lo, b.hi) or L["%d+ s"]:format(b.lo)
        rows[i] = { label = label, color = C.blue, frac = b.n, value = tostring(b.n),
                    tip = { label, b.n == 1 and L["1 run"] or L["%d runs"]:format(b.n),
                            L["Damage still landing after the buzzer, and counted."] } }
    end
    if not any then rows = {} end
    return self.ctx:renderBarSection(self.ctx:Pool("tail"), self.headers.tail, rows, y, w, pad)
end

-- K's clicks: the left opens the run on the Runs tab, the right its row menu.
local function bestClick(self, run)
    return function(row, button)
        local hooks = self.hooks
        if button == "RightButton" then
            if hooks.menu then hooks.menu(run, row) end
        elseif hooks.open then
            hooks.open(run)
        end
    end
end

-- K: the newest new bests first: date, spec, board, DPS and the gain over the best before.
local function layoutNewBests(self, stats, y, w, pad)
    local rows, list = {}, stats.newBests
    for i = #list, 1, -1 do
        local e = list[i]
        local run = e.run
        local gain = e.gain and L["%+.1f%%"]:format(e.gain) or DASH
        rows[#rows + 1] = {
            name = L["%s \194\183 %s"]:format(dayText(run.date), runBoard(run)),
            nameColor = Tbl.ClassColor(run.char and run.char.class),
            right = L["%s  %s"]:format(dps(e.dps), gain),
            tip = { runBoard(run), whenText(run.date),
                    L["%s DPS, up from %s"]:format(dps(e.dps), dps(e.prevDps)),
                    L["Click to open the run \194\183 right-click for options"] },
            onClick = bestClick(self, run),
        }
    end
    return listSection(self, "bests", rows, y, w, pad)
end

local SECTIONS = { layoutProgression, layoutBoards, layoutCharacters, layoutCharTarget, layoutCharLength,
                   layoutLateCasts, layoutPerDay, layoutTail, layoutNewBests }

-- The sections' headings (the list panels carry their own titles).
local HEADERS = {
    { key = "progression", title = "DPS Progression" },
    { key = "boards", title = "By Target \195\151 Length" },
    { key = "specs", title = "Spec Comparison" },
    { key = "consistency", title = "Consistency" },
    { key = "chars", title = "Races By Character" },
    { key = "charTarget", title = "Races By Character \195\151 Target" },
    { key = "charLength", title = "Races By Character \195\151 Length" },
    { key = "perDay", title = "Races Per Day" },
    { key = "tail", title = "Damage Tail After The Buzzer" },
}
local PANELS = { { key = "late", title = "Late Casts" }, { key = "bests", title = "Recent New Bests" } }

-- ── the view ────────────────────────────────────────────────────────────────────────────────────

local View = {}
View.__index = View

local function checkbox(view, parent, spec)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetSize(20, 20)
    b.label = Tbl.Text(b, Tbl.FONT.TEXT)
    b.label:SetPoint("LEFT", b, "RIGHT", 1, 0)
    Tbl.SetCheckLabel(b, L[spec.label])
    b:SetScript("OnClick", function() view:SetFilter(spec.key, not view.filters[spec.key]) end)
    b.key = spec.key
    return b
end

local function buildBar(view)
    local bar = CreateFrame("Frame", nil, view.frame)
    bar:SetPoint("TOPLEFT", view.frame, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", view.frame, "TOPRIGHT", 0, 0)
    bar:SetHeight(FILTER_H)
    local line = bar:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.24, 0.24, 0.27, 0.85)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    view.dropdowns, view.checks, view.viewButtons = {}, {}, {}
    for _, spec in ipairs(DROPDOWNS) do
        local dd = NS.MakeDropdown(bar, spec.width)
        if dd then
            dd.onSelect = function(value) view:SetFilter(spec.key, value) end
            view.dropdowns[spec.key] = dd
        end
    end
    for _, spec in ipairs(CHECKS) do view.checks[spec.key] = checkbox(view, bar, spec) end
    for _, spec in ipairs(VIEW_BUTTONS) do
        local b = NS.HudStates.Button(bar, L[spec.label], function() view[spec.act](view) end)
        b:SetWidth(VIEW_BUTTON_W)
        b.tip = { L[spec.label], L[spec.tip] }
        view.viewButtons[spec.key] = b
    end
    view.bar = bar
end

-- The scroll frame under the bar, its content, and the chrome the sections place: the cards, the
-- headings, the strips, the board tabs' rule, the list panels and the empty state.
local function buildBody(view)
    local frame = view.frame
    view.scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    view.content = CreateFrame("Frame", nil, view.scrollFrame)
    view.content:SetSize(1, 1)
    view.scrollFrame:SetScrollChild(view.content)
    view.scrollFrame:EnableMouseWheel(true)
    view.scrollFrame:SetScript("OnMouseWheel", function(_, delta) view:Scroll(delta) end)
    local ctx = NS.InsightsCharts.New(view.content, NS.InsightsCharts.Host())
    view.ctx, view.cards, view.headers, view.panels, view.chrome = ctx, {}, {}, {}, {}
    for _, def in ipairs(CARDS) do
        view.cards[def.key] = ctx:card(view.content, L[def.caption])
        view.chrome[#view.chrome + 1] = view.cards[def.key].frame
    end
    for _, def in ipairs(HEADERS) do
        view.headers[def.key] = ctx:sectionHeader(view.content, L[def.title])
        view.chrome[#view.chrome + 1] = view.headers[def.key]
    end
    view.strips = { progression = ctx:strip(view.content), perDay = ctx:strip(view.content) }
    for _, def in ipairs(PANELS) do
        view.panels[def.key] = ctx:listPanel(view.content, L[def.title])
        view.chrome[#view.chrome + 1] = view.panels[def.key]
    end
    view.chrome[#view.chrome + 1] = view.strips.progression
    view.chrome[#view.chrome + 1] = view.strips.perDay
    view.boardRule = view.content:CreateTexture(nil, "ARTWORK")
    view.boardRule:SetColorTexture(0.24, 0.24, 0.27, 0.85)
    view.boardRule:SetHeight(1)
    view.chrome[#view.chrome + 1] = view.boardRule
    view.empty = Tbl.Text(frame, Tbl.FONT.EMPTY, nil, "CENTER")
    view.empty:SetText(L["No runs match these filters."])
    view.empty:Hide()
end

--- The Insights tab in `parent`.
--- @param parent table
--- @param hooks table  { open(run), menu(run, row), count(text) }
--- @return table view
function Insights.Build(parent, hooks)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    local view = setmetatable({ frame = frame, hooks = hooks or {}, filters = {}, barH = FILTER_H, scroll = 0,
                                filtered = {} }, View)
    buildBar(view)
    buildBody(view)
    view:ApplyView(Insights.SavedView())
    return view
end

-- ── saved views (LootHistory's Save / Reset / Clear) ────────────────────────────────────────────
--   Save   stores the filters as the profile's view (profile.views.insights).
--   Reset  deletes the saved view and applies the stock one (InsightsData.DEFAULTS).
--   Clear  returns to the saved view, or the stock one when there is none; the saved view is kept.

--- The saved view, or nil.
function Insights.SavedView()
    local p = NS.db and NS.db.profile
    local views = p and p.views
    return type(views) == "table" and type(views.insights) == "table" and views.insights or nil
end

--- The view now, as a plain copy: { filters }.
function View:CaptureView()
    local filters = {}
    for k in pairs(NS.InsightsData.DEFAULTS) do filters[k] = self.filters[k] end
    return { filters = filters }
end

--- Apply `v` (CaptureView's shape), or the stock view for nil. A stored key the tab does not know is
--- dropped; a missing one takes its default. Normalize (on Refresh) falls a selection with no runs
--- back to All, in the live filters only.
function View:ApplyView(v)
    v = type(v) == "table" and v or {}
    local stored = type(v.filters) == "table" and v.filters or {}
    for k, def in pairs(NS.InsightsData.DEFAULTS) do
        local value = stored[k]
        if value == nil then value = def end
        self.filters[k] = value
    end
    if self.built then self:Redraw() end
end

-- While the window shows the sample history (test mode, a sim) Save and Reset refuse with one line,
-- so nothing the samples set reaches the profile (modules/Results_Source.lua).
local function sampleRefusal()
    if not NS.ResultsSource.IsMock() then return false end
    NS.Print(L["Not saved: the Results window is showing sample runs."])
    return true
end

-- The sample history is other characters' runs, so it opens on the stock view (all of them); the view
-- the player had comes back when the store does (the shell's OnSourceChanged). Without this, Refresh's
-- fallback over the samples would stay in the live filters after the swap back.

--- Enter (`on`) or leave the sample history's view: entering keeps the player's view to restore.
function View:SampleView(on)
    if on then
        if not self.realView then self.realView = self:CaptureView() end
        self:ApplyView(nil)
    elseif self.realView then
        local real = self.realView
        self.realView = nil
        self:ApplyView(real)
    end
end

function View:SaveView()
    if sampleRefusal() then return false end
    local p = NS.db and NS.db.profile
    if not p then return false end
    if type(p.views) ~= "table" then p.views = {} end
    p.views.insights = self:CaptureView()
    NS.Print(L["Insights view saved as default."])
    return true
end

function View:ResetView()
    if sampleRefusal() then return false end
    local p = NS.db and NS.db.profile
    if p and type(p.views) == "table" then
        p.views.insights = nil
        if next(p.views) == nil then p.views = nil end
    end
    self:ApplyView(nil)
    NS.Print(L["Insights view reset to stock defaults."])
    return true
end

function View:ClearView()
    self:ApplyView(Insights.SavedView())
end

-- ── layout ──────────────────────────────────────────────────────────────────────────────────────

-- Lay the bar out by Insights.BarPlan at `width`: re-anchored and the dropdowns re-sized, nothing
-- repainted, so Resize runs it too. Answers its height.
function View:layoutBar(width)
    local plan = Insights.BarPlan(width)
    for _, spec in ipairs(DROPDOWNS) do
        local dd = self.dropdowns[spec.key]
        if dd then
            dd:ClearAllPoints()
            dd:SetPoint("TOPLEFT", self.bar, "TOPLEFT", plan.dropdowns[spec.key], -6)
            dd:SetWidth(plan.widths[spec.key])
        end
    end
    for _, spec in ipairs(CHECKS) do
        local b = self.checks[spec.key]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.bar, "TOPLEFT", plan.checks[spec.key], plan.y)
    end
    for _, spec in ipairs(VIEW_BUTTONS) do
        local b = self.viewButtons[spec.key]
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", self.bar, "TOPLEFT", plan.buttons[spec.key], plan.y)
    end
    self.barH = plan.oneRow and FILTER_H or (2 * FILTER_H - 6)
    self.bar:SetHeight(self.barH)
    return self.barH
end

-- The scroll frame under the bar, filling the rest of the tab.
function View:placeScroll(width, height)
    self.viewH = math.max(1, height - self.barH)
    self.scrollFrame:ClearAllPoints()
    self.scrollFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -self.barH)
    self.scrollFrame:SetSize(math.max(1, width), self.viewH)
    self.empty:ClearAllPoints()
    self.empty:SetPoint("TOP", self.frame, "TOP", 0, -(self.barH + 24))
end

-- The cards on Insights.CardGrid's 4 columns from `y`; answers the cursor under them.
function View:layoutCards(y, w)
    local colW = (w - PAD * 2 - CARD_GAP * (CARD_COLS - 1)) / CARD_COLS
    local cardH = NS.InsightsCharts.K.CARD_H
    local cells, nRows = Insights.CardGrid(CARDS, CARD_COLS)
    for i, def in ipairs(CARDS) do
        local cell, card = cells[i], self.cards[def.key]
        local cw = math.floor(colW * cell.span + CARD_GAP * (cell.span - 1))
        card.frame:ClearAllPoints()
        card.frame:SetPoint("TOPLEFT", self.content, "TOPLEFT", math.floor(PAD + cell.col * (colW + CARD_GAP)),
            y - cell.row * (cardH + CARD_GAP))
        card.frame:SetWidth(cw)
        card.frame:Show()
        local value, tip, caption, color = CARD_FILL[def.key](self.stats.totals)
        card.label:SetText(caption or L[def.caption])
        self.ctx:setCard(card, value, tip, cw - 12, color)
    end
    return y - nRows * (cardH + CARD_GAP) + CARD_GAP - 14
end

--- Bind and place every section off the stats for `w`; answers the cursor under the last. With no
--- run the empty state shows and everything else hides.
function View:LayoutCharts(y, w, pad)
    self.ctx:ReleaseAll()
    for _, region in ipairs(self.chrome) do region:Hide() end
    local stats = self.stats
    if not stats or stats.totals.runs == 0 then
        self.empty:Show()
        return y
    end
    self.empty:Hide()
    y = self:layoutCards(y, w)
    for _, section in ipairs(SECTIONS) do y = section(self, stats, y, w, pad) end
    return y
end

-- Draw the content at the width laid out: the cards and the sections, then the scroll clamped.
function View:draw()
    local w = math.max(1, self.width or 1)
    self.content:SetWidth(w)
    local y = self:LayoutCharts(-PAD, w, PAD)
    self.contentH = -y + PAD
    self.content:SetHeight(math.max(1, self.contentH))
    self:Scroll(0)
end

--- Lay the tab out at `width` x `height`: the bar, the scroll frame, the cards and the sections.
function View:Layout(width, height)
    self.width, self.height = width, height
    self:layoutBar(width)
    self:placeScroll(width, height)
    self:draw()
end

--- While the window is being sized (modules/Sizing.lua): the bar re-planned and the scroll frame
--- sized, nothing rebound or redrawn; the release's Layout redraws.
function View:Resize(width, height)
    self.width, self.height = width, height
    self:layoutBar(width)
    self:placeScroll(width, height)
    self:Scroll(0)
end

--- One mouse-wheel notch (`delta` > 0 scrolls up), clamped to the content.
function View:Scroll(delta)
    local top = math.max(0, (self.contentH or 0) - (self.viewH or 0))
    self.scroll = math.max(0, math.min(top, (self.scroll or 0) - (delta or 0) * WHEEL_STEP))
    self.scrollFrame:SetVerticalScroll(self.scroll)
end

-- ── the data ────────────────────────────────────────────────────────────────────────────────────

-- Put the filters on the controls: each dropdown closed on its ClosedLabel (the choices, not the runs).
function View:paintFilters(options)
    for _, spec in ipairs(DROPDOWNS) do
        local dd, value = self.dropdowns[spec.key], self.filters[spec.key]
        if dd then
            dd:SetOptions(options[spec.key])
            dd:SelectValue(value)
            local closed = NS.InsightsData.ClosedLabel(options[spec.key], value)
            if closed then dd:SetValue(value, closed) end
        end
    end
    for _, spec in ipairs(CHECKS) do self.checks[spec.key]:SetChecked(self.filters[spec.key] == true) end
end

--- Re-read the runs: the options (a selection with no runs falls back to All, `self.keep` never),
--- the filtered runs, the stats and the footer's count. The shell lays the tab out after it.
function View:Refresh()
    local Data = NS.InsightsData
    local all = NS.ResultsSource.All()
    local f, options = Data.Normalize(all, self.filters, nil, self.keep)
    self.filters, self.keep = f, nil
    self:paintFilters(options)
    self.filtered = Data.Filter(all, f)
    self.stats = Data.Compute(self.filtered)
    self.built = true
    local n = #self.filtered
    if self.hooks.count then self.hooks.count(n == 1 and L["1 run"] or L["%d runs"]:format(n)) end
end

--- Refresh, then draw at the size laid out (a filter or a view changed while the tab shows).
function View:Redraw()
    self:Refresh()
    if self.width then self:draw() end
end

--- Set one filter and redraw: the dropdown changed keeps its value through the fallback.
function View:SetFilter(key, value)
    if NS.InsightsData.DEFAULTS[key] == nil then return false end
    self.filters[key] = value
    self.keep = key
    self:Redraw()
    return true
end

--- Show the board tab `key` (a target x length pair: "cleave|120"): kept while the filters leave it
--- present, never saved with the view.
function View:SelectBoard(key)
    self.boardKey = key
    if self.width then self:draw() end
end

--- How many runs pass the filters now.
function View:Count()
    return #self.filtered
end
