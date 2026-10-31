-- tests/test_insights.lua — the Insights tab's drawing half (#12), the renderer half of the suite:
-- LibKa0s-Charts-1.0 (LibKa0s#66, promoted from this addon's port of LootHistory's Insights tab) as
-- this addon draws through it, with a host config table (the colors, the font objects, the tooltip,
-- the panel and the pool). The library's own suite owns the major; these cases stayed through the
-- swap as the characterization of what this tab draws. Pinned here: the pure helpers (a UTF-8-safe
-- truncate, the hover text, the shrink-to-fit figure, the ranked palette), every renderer's geometry
-- and colors, every hover stating its value, the legend under the bars' track, pooled widgets reused
-- over two passes (the second pass builds nothing), the list rows' clicks, the stat card, and the
-- DpsRace host (core/ChartsSetup.lua).
-- The tab half (modules/Results_Insights.lua: the filter bar, the cards, the sections) follows it.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

--- A fresh instance with the widget recorder, a CreateFrame counter, and a host table that records
--- every tooltip it is asked for.
local function inst()
    local i = T.load{ mutate = function(m) Widgets.install(m) end }
    local base = i.mocks.CreateFrame
    i.made = 0
    i.mocks.CreateFrame = function(...)
        i.made = i.made + 1
        return base(...)
    end
    i.tips = {}
    i.host = {
        pool = i.NS.Pool,
        tip = function(owner, lines, anchor) i.tips[#i.tips + 1] = { owner = owner, lines = lines, anchor = anchor } end,
        hideTip = function() i.tips.hidden = (i.tips.hidden or 0) + 1 end,
        colors = { body = { 0.1, 0.2, 0.3 }, value = { 0.4, 0.5, 0.6 }, heading = { 0.7, 0.8, 0.9 },
                   track = { 0.11, 0.12, 0.13, 0.5 }, bar = { 0.21, 0.22, 0.23, 0.9 }, muted = { 0.31, 0.32, 0.33 },
                   axis = { 0.41, 0.42, 0.43, 0.8 }, rule = { 0.51, 0.52, 0.53, 0.35 }, caption = { 0.61, 0.62, 0.63 } },
        fonts = { label = "LabelFont", axis = "AxisFont", heading = "HeadingFont", divider = "DividerFont",
                  panelTitle = "PanelTitleFont", caption = "CaptionFont", figure = "FigureFont" },
        palette = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } },
    }
    i.Charts = i.NS.Charts
    i.content = base("Frame")
    i.ctx = i.Charts:New(i.content, i.host)
    return i
end

local function hover(frame)
    frame:GetScript("OnEnter")(frame)
end

local function lastTip(i)
    return i.tips[#i.tips]
end

local function point(region, n)
    return region.__points[n or 1]
end

local function sameColor(got, want)
    for k = 1, 3 do
        if math.abs((got[k] or -1) - want[k]) > 1e-6 then return false end
    end
    return true
end

-- ── the host seam ───────────────────────────────────────────────────────────────────────────────

test("insights charts: New fills the colors and fonts it is not given, and writes no host table", function()
    local i = inst()
    local ctx = i.Charts:New(i.content, { pool = i.NS.Pool })
    for _, key in ipairs({ "body", "value", "heading", "track", "bar", "muted", "axis", "rule", "caption" }) do
        assertEqual(type(ctx.colors[key]), "table", "a default color for " .. key)
    end
    for _, key in ipairs({ "label", "axis", "heading", "divider", "panelTitle", "caption", "figure" }) do
        assertEqual(type(ctx.fonts[key]), "string", "a default font for " .. key)
    end
    assertEqual(#ctx:paletteColor(1), 3)
    assertNil(i.host.colors.neutral)
end)

-- ── the pure helpers ────────────────────────────────────────────────────────────────────────────

test("insights charts: truncate counts glyphs, not bytes, and ends in three periods inside the cap", function()
    local C = inst().Charts
    assertEqual(C.truncate("Traxex", 16), "Traxex")
    local s, cut = C.truncate("Beast Mastery cleave", 8)
    assertEqual(s, "Beast...")
    assertTrue(cut)
    -- "Trâxex" is 6 glyphs in 7 bytes: it fits 6, and a cut never splits the â.
    assertEqual((C.truncate("Tr\195\162xex", 6)), "Tr\195\162xex")
    assertEqual((C.truncate("Tr\195\162xex the hunter", 6)), "Tr\195\162...")
    assertEqual((C.truncate(nil, 4)), "")
end)

test("insights charts: tipText states the value beside the full label", function()
    local C = inst().Charts
    assertEqual(C.tipText("Beast Mastery", "417.2k"), "Beast Mastery:  417.2k")
    assertEqual(C.tipText("Beast Mastery", nil), "Beast Mastery")
    assertEqual(C.tipText("Beast Mastery", ""), "Beast Mastery")
    assertEqual(C.tipText("", 12), "12")
end)

test("insights charts: fitFontSize shrinks only an overflowing figure, never under the floor", function()
    local C = inst().Charts
    assertEqual(C.fitFontSize(80, 100, 24, 11), 24)
    assertEqual(C.fitFontSize(200, 100, 24, 11), 12)
    assertEqual(C.fitFontSize(1000, 100, 24, 11), 11)
    assertEqual(C.fitFontSize(0, 100, 24, 11), 24)
end)

test("insights charts: the ranked palette cycles, and a map keeps one color per key", function()
    local i = inst()
    assertEqual(i.ctx:paletteColor(1), i.host.palette[1])
    assertEqual(i.ctx:paletteColor(4), i.host.palette[1])
    local m = i.ctx:paletteMap({ "boss", "cleave" })
    assertEqual(m.boss, i.host.palette[1])
    assertEqual(m.cleave, i.host.palette[2])
end)

test("insights charts: a palette getter is read at each draw, so a skin switch moves it", function()
    local i = inst()
    local a, b = { { 1, 0, 0 } }, { { 0, 0, 1 }, { 0, 1, 0 } }
    local now = a
    i.host.palette = function() return now end
    local ctx = i.Charts:New(i.content, i.host)
    assertEqual(ctx:paletteColor(1), a[1])
    now = b
    assertEqual(ctx:paletteColor(2), b[2], "the new palette, no rebuild")
    now = nil
    assertTrue(ctx:paletteColor(1) ~= nil, "a getter that answers nothing falls back to the default palette")
end)

-- ── the bar sections ────────────────────────────────────────────────────────────────────────────

local SPECS = {
    { label = "Beast Mastery", color = { 0.67, 0.83, 0.45 }, frac = 0.5, value = "417.2k" },
    { label = "Destruction", color = { 0.53, 0.53, 0.93 }, frac = 0.25, value = "342.0k",
      tip = { "Destruction", "Best 342.0k", "Avg 330.1k" } },
}

test("insights charts: a bar section scales to its longest bar and colors label and fill alike", function()
    local i = inst()
    local header = i.ctx:sectionHeader(nil, "Spec Comparison")
    local pool = i.ctx:Pool("bars")
    local y = i.ctx:renderBarSection(pool, header, SPECS, -10, 600, 8)
    local K = i.Charts.K
    assertEqual(y, -10 - K.HEADER_H - 2 * (K.BAR_H + K.BAR_GAP) - K.SECTION_GAP)
    assertEqual(point(header)[5], -10)
    local bars = pool.active
    assertEqual(#bars, 2)
    local trackW = 600 - 16 - K.LABELW - K.VALW - 12
    assertEqual(bars[1].fill.__width, trackW, "the longest bar fills the track")
    assertEqual(bars[2].fill.__width, trackW / 2)
    assertTrue(sameColor(bars[1].fill.__colorTex, SPECS[1].color))
    assertTrue(sameColor(bars[1].label.__color, SPECS[1].color))
    assertTrue(sameColor(bars[1].value.__color, i.host.colors.value))
    assertTrue(sameColor(bars[1].track.__colorTex, i.host.colors.track))
    assertEqual(bars[1].label.__fontObject, "LabelFont")
    -- The rows are not written (LootHistory normalized them in place).
    assertEqual(SPECS[1].frac, 0.5)
end)

test("insights charts: every bar's hover states its value; a row's own tip lines win", function()
    local i = inst()
    local pool = i.ctx:Pool("bars")
    i.ctx:renderBarSection(pool, i.ctx:sectionHeader(nil, "Specs"), SPECS, 0, 600, 8)
    hover(pool.active[1])
    assertEqual(lastTip(i).lines[1], "Beast Mastery:  417.2k")
    assertEqual(lastTip(i).anchor, "ANCHOR_CURSOR_RIGHT")
    hover(pool.active[2])
    assertEqual(lastTip(i).lines[3], "Avg 330.1k")
    pool.active[2]:GetScript("OnLeave")(pool.active[2])
    assertEqual(i.tips.hidden, 1)
end)

test("insights charts: an empty section hides its header and leaves the cursor where it was", function()
    local i = inst()
    local header = i.ctx:sectionHeader(nil, "Specs")
    assertEqual(i.ctx:renderBarSection(i.ctx:Pool("bars"), header, {}, -42, 600, 8), -42)
    assertFalse(header:IsShown())
    assertEqual(i.ctx:renderStrip(i.ctx:Pool("s"), header, i.ctx:strip(), {}, -42, 600, 8), -42)
    assertEqual(i.ctx:renderStackedBarSection(i.ctx:Pool("st"), header, {}, -42, 600, 8), -42)
end)

test("insights charts: a legend's chips start under the track, not the labels, and wrap", function()
    local i = inst()
    local K = i.Charts.K
    local rows = {}
    for n = 1, 6 do rows[n] = { label = "Board " .. n, color = { n / 10, 0, 0 }, value = tostring(n) } end
    local legend = i.ctx:Pool("legend")
    local y = i.ctx:renderBarSection(i.ctx:Pool("bars"), i.ctx:sectionHeader(nil, "x"), rows, 0, 600, 8, legend)
    local chips = legend.active
    assertEqual(#chips, 6)
    local x0 = 8 + K.LABELW + K.TRACK_GAP
    assertEqual(point(chips[1])[4], x0, "the first chip at the track's left edge")
    assertEqual(point(chips[2])[4], x0 + K.CHIP_W)
    -- (600 - 8 - x0) / 120 = 3 chips a line.
    assertEqual(point(chips[4])[4], x0, "the fourth chip wraps")
    assertEqual(point(chips[4])[5], point(chips[1])[5] - K.LEGEND_ROW_H)
    assertEqual(y, point(chips[4])[5] - K.LEGEND_ROW_H - K.SECTION_GAP)
    hover(chips[3])
    assertEqual(lastTip(i).lines[1], "Board 3:  3")
    assertTrue(sameColor(chips[1].sw.__colorTex, rows[1].color))
end)

test("insights charts: a sublabel draws a second, muted line, and every row of its section grows", function()
    local i = inst()
    local K = i.Charts.K
    local pool = i.ctx:Pool("bars")
    local rows = {
        { label = "Destruction", sublabel = "Cleave \194\183 2:00", color = { 0.53, 0.53, 0.93 }, frac = 1, value = "99.5%" },
        { label = "Beast Mastery", color = { 0.67, 0.83, 0.45 }, frac = 0.9, value = "95.9%" },
    }
    local y = i.ctx:renderBarSection(pool, i.ctx:sectionHeader(nil, "Consistency"), rows, 0, 600, 8)
    assertEqual(y, -K.HEADER_H - 2 * (K.BAR_H2 + K.BAR_GAP) - K.SECTION_GAP)
    local a, b = pool.active[1], pool.active[2]
    assertEqual(a.__height, K.BAR_H2)
    assertEqual(b.__height, K.BAR_H2, "the rows stay even")
    assertEqual(a.label.__text, "Destruction")
    assertEqual(a.sub.__text, "Cleave \194\183 2:00")
    assertTrue(a.sub:IsShown())
    assertTrue(sameColor(a.sub.__color, i.host.colors.muted))
    assertEqual(point(a.label)[1], "BOTTOMLEFT", "the label over the row's middle")
    assertEqual(point(a.sub)[1], "TOPLEFT", "the sublabel under it")
    assertFalse(b.sub:IsShown())
    -- Reused without a sublabel: one line, centered, the row back to BAR_H.
    i.ctx:ReleaseAll()
    i.ctx:renderBarSection(pool, i.ctx:sectionHeader(nil, "x"), { SPECS[1] }, 0, 600, 8)
    assertEqual(pool.active[1], a)
    assertEqual(a.__height, K.BAR_H)
    assertFalse(a.sub:IsShown())
    assertEqual(point(a.label)[1], "LEFT")
end)

test("insights charts: RangeScale spans the lowest worst to the highest best, opening a point", function()
    local C = inst().Charts
    local lo, hi = C.RangeScale({ { lo = 300, hi = 400 }, { lo = 280, hi = 350 } })
    assertEqual(lo, 280)
    assertEqual(hi, 400)
    lo, hi = C.RangeScale({ { lo = 200, hi = 200 } })
    assertEqual(lo, 190)
    assertEqual(hi, 210)
    lo, hi = C.RangeScale({ { lo = 0, hi = 0 } })
    assertEqual(lo, -1)
    assertEqual(hi, 1)
end)

test("insights charts: a range section draws worst to best with an average mark, on a scale it names", function()
    local i = inst()
    local K = i.Charts.K
    local pool, scale = i.ctx:Pool("range"), i.ctx:Pool("scale")
    local rows = {
        { label = "Beast Mastery", color = { 0.67, 0.83, 0.45 }, lo = 300, hi = 400, mark = 350, value = "350",
          tip = { "Beast Mastery", "Worst 300", "Avg 350", "Best 400", "4 runs" } },
        { label = "Blood", color = { 0.77, 0.12, 0.23 }, lo = 200, hi = 200, mark = 200, value = "200" },
    }
    local y = i.ctx:renderRangeSection(pool, i.ctx:sectionHeader(nil, "Consistency"), rows, -10, 600, 8, scale,
        function(v) return "v" .. v end)
    assertEqual(y, -10 - K.HEADER_H - 2 * (K.BAR_H + K.BAR_GAP) - K.RANGE_SCALE_H - K.SECTION_GAP)
    local trackW = 600 - 16 - K.LABELW - K.VALW - 12
    local a, b = pool.active[1], pool.active[2]
    -- The scale is 200 to 400: Beast Mastery's fill from its middle to the end, its mark at 3/4.
    assertEqual(point(a.fill)[4], trackW / 2)
    assertEqual(a.fill.__width, trackW / 2)
    assertEqual(point(a.mark)[4], trackW * 0.75)
    assertTrue(a.mark:IsShown())
    assertTrue(sameColor(a.mark.__colorTex, i.host.colors.body))
    assertTrue(sameColor(a.fill.__colorTex, rows[1].color))
    assertTrue(sameColor(a.label.__color, rows[1].color))
    -- One run: the narrowest fill, at the scale's start.
    assertEqual(b.fill.__width, K.RANGE_MIN_W)
    assertEqual(point(b.fill)[4], 0)
    local line = scale.active[1]
    assertEqual(line.lo.__text, "v200")
    assertEqual(line.hi.__text, "v400")
    assertEqual(point(line)[4], 8 + K.LABELW + K.TRACK_GAP, "under the track, not the labels")
    hover(a)
    assertEqual(lastTip(i).lines[3], "Avg 350")
    hover(b)
    assertEqual(lastTip(i).lines[1], "Blood:  200")
    -- No mark: hidden; no scale pool: no line; no rows: the header hides.
    i.ctx:ReleaseAll()
    rows[1].mark = nil
    local header = i.ctx:sectionHeader(nil, "x")
    y = i.ctx:renderRangeSection(pool, header, { rows[1] }, 0, 600, 8)
    assertFalse(pool.active[1].mark:IsShown())
    assertEqual(y, -K.HEADER_H - (K.BAR_H + K.BAR_GAP) - K.SECTION_GAP)
    assertEqual(i.ctx:renderRangeSection(pool, header, {}, -5, 600, 8), -5)
    assertFalse(header:IsShown())
end)

test("insights charts: a legend can start at a given edge (under a strip, not a bar track)", function()
    local i = inst()
    local legend = i.ctx:Pool("legend")
    i.ctx:renderLegend(legend, { { label = "Beast Mastery", color = { 1, 0, 0 }, value = "28 runs" } }, -40, 600, 8, 8)
    assertEqual(point(legend.active[1])[4], 8)
    assertEqual(point(legend.active[1])[5], -40)
end)

test("insights charts: a stacked bar shows one segment per share, each hover naming its value", function()
    local i = inst()
    local pool = i.ctx:Pool("stacked")
    local rows = {
        { label = "Traxex", labelColor = { 0.67, 0.83, 0.45 }, value = "28",
          segments = { { frac = 0.7, color = { 1, 0.72, 0.29 }, tip = "Cleave: 20" },
                       { frac = 0.3, color = { 0.75, 0.55, 1 }, tip = "Boss: 8" } } },
        { label = "Lanfear", value = "15", segments = { { frac = 0.5, color = { 1, 0.72, 0.29 }, tip = "Cleave: 15" } } },
    }
    i.ctx:renderStackedBarSection(pool, i.ctx:sectionHeader(nil, "x"), rows, 0, 600, 8)
    local a, b = pool.active[1], pool.active[2]
    assertEqual(#a.segs, i.Charts.K.MAX_STACK_SEGS)
    assertTrue(a.segs[1]:IsShown())
    assertTrue(a.segs[2]:IsShown())
    assertFalse(a.segs[3]:IsShown())
    assertFalse(b.segs[2]:IsShown())
    assertTrue(sameColor(b.label.__color, i.host.colors.body), "no label color: the body color")
    hover(a.segs[2])
    assertEqual(lastTip(i).lines[1], "Boss: 8")
    hover(a)
    assertEqual(lastTip(i).lines[1], "Traxex:  28")
    -- The second segment starts where the first ends.
    local trackW = 600 - 16 - i.Charts.K.LABELW - i.Charts.K.VALW - 12
    assertEqual(point(a.segs[2])[4], trackW * 0.7)
end)

-- ── the strip ───────────────────────────────────────────────────────────────────────────────────

test("insights charts: a strip draws one colored column per bucket, its hover above the column", function()
    local i = inst()
    local K = i.Charts.K
    local pool, strip = i.ctx:Pool("strip"), i.ctx:strip()
    local buckets = {
        { count = 0.5, label = "10/23", info = "Oct 23: 50%", color = { 1, 0, 0 } },
        { count = 1, label = "10/24", info = { "Oct 24", "100% of board best" } },
        { count = 0, label = "10/25", info = "Oct 25: no runs" },
    }
    local y = i.ctx:renderStrip(pool, i.ctx:sectionHeader(nil, "x"), strip, buckets, -20, 316, 8)
    assertEqual(y, -20 - K.HEADER_H - K.DAYSTRIP_H - K.STRIP_LABEL_H - K.SECTION_GAP)
    local bars = pool.active
    assertEqual(#bars, 3)
    -- 300 px over 3 buckets: the slot stops at STRIP_SLOT_MAX (48), so the columns sit side by side,
    -- each STRIP_BAR_MAX (36) wide and centered in its slot.
    assertEqual(bars[1].__width, K.STRIP_BAR_MAX)
    assertEqual(point(bars[1])[4], (K.STRIP_SLOT_MAX - K.STRIP_BAR_MAX) / 2)
    assertEqual(point(bars[2])[4], K.STRIP_SLOT_MAX + (K.STRIP_SLOT_MAX - K.STRIP_BAR_MAX) / 2)
    assertEqual(strip.axisLine.__width, 3 * K.STRIP_SLOT_MAX, "the axis line spans the columns only")
    assertEqual(bars[2].fill.__height, K.DAYSTRIP_H - 2, "the tallest column fills the strip")
    assertEqual(bars[1].fill.__height, (K.DAYSTRIP_H - 2) / 2)
    assertTrue(sameColor(bars[1].fill.__colorTex, { 1, 0, 0 }))
    assertTrue(sameColor(bars[2].fill.__colorTex, i.host.colors.bar), "no color: the host's bar")
    assertEqual(bars[1].axis.__text, "10/23")
    assertEqual(bars[1].axis.__fontObject, "AxisFont")
    hover(bars[2])
    assertEqual(lastTip(i).lines[2], "100% of board best")
    assertEqual(lastTip(i).anchor, "ANCHOR_TOP")
    assertTrue(sameColor(strip.axisLine.__colorTex, i.host.colors.axis))
end)

test("insights charts: a strip's labels are level, hung under the axis line, in the band it reserves", function()
    local i = inst()
    local K = i.Charts.K
    local pool = i.ctx:Pool("strip")
    i.ctx:renderStrip(pool, i.ctx:sectionHeader(nil, "x"), i.ctx:strip(), {
        { count = 1, label = "Oct 23", info = "a" }, { count = 2, label = "Oct 24", info = "b" },
    }, 0, 316, 8)
    local axis = pool.active[1].axis
    local p = point(axis)
    assertEqual(p[1], "TOP")
    assertEqual(p[3], "BOTTOM", "hung from the column's base")
    assertEqual(p[5], -(K.STRIP_AXIS_GAP + K.STRIP_LABEL_GAP), "below the axis line, never on a column")
    assertEqual(axis.__justifyH, "CENTER")
    -- A level label is one text line tall: the band under the axis holds it whole.
    assertTrue(K.STRIP_LABEL_H >= K.STRIP_AXIS_GAP + K.STRIP_LABEL_GAP + 10)
    assertTrue(K.STRIP_LABEL_H <= 20, "no dead space under the strip")
end)

test("insights charts: a strip takes a fixed top, and drops a label too close to another one shown", function()
    local i = inst()
    local K = i.Charts.K
    local pool, strip = i.ctx:Pool("strip"), i.ctx:strip()
    local buckets = {}
    for n = 1, 60 do buckets[n] = { count = 0.5, label = tostring(n), info = tostring(n) } end
    i.ctx:renderStrip(pool, i.ctx:sectionHeader(nil, "x"), strip, buckets, 0, 316, 8, 2)
    assertEqual(pool.active[1].fill.__height, (K.DAYSTRIP_H - 2) / 4, "0.5 of a top of 2")
    -- 300 / 60 = 5 px a slot. The first label is pulled in to 20 px (half the pitch) so it stays
    -- inside the content, and the next one shows 40 px past it, at column 13 (62.5 px).
    assertEqual(pool.active[1].axis.__text, "1")
    assertEqual(pool.active[2].axis.__text, "")
    assertEqual(pool.active[9].axis.__text, "")
    assertEqual(pool.active[13].axis.__text, "13")
    -- A run per column labels only where its day changes: two day labels on neighbors (10/23 on a
    -- one-run day, 10/24 on the ten runs after it) keep the larger day's, and the next day change far
    -- enough on shows.
    i.ctx:ReleaseAll()
    local runs = {}
    for n = 1, 40 do runs[n] = { count = 1, info = tostring(n) } end
    runs[1].label, runs[2].label, runs[12].label = "10/23", "10/24", "10/25"
    i.ctx:renderStrip(pool, i.ctx:sectionHeader(nil, "x"), strip, runs, 0, 816, 8)
    assertEqual(pool.active[1].axis.__text, "", "a one-run day 20 px before a ten-run day: dropped")
    assertEqual(pool.active[2].axis.__text, "10/24")
    assertEqual(pool.active[12].axis.__text, "10/25")
end)

test("insights charts: StripLabels keeps the label of the day with more columns, not the earlier one", function()
    local C = inst().Charts
    -- The owner's data in per-run mode: 23 Oct has one run, 24 Oct has twelve, 25 Oct has five,
    -- at about 15.5 px a slot. 24 Oct's label wins over 23 Oct's, and 25 Oct's is far enough on.
    local runs = {}
    for n = 1, 56 do runs[n] = { count = 1 } end
    runs[1].label, runs[2].label, runs[14].label = "23 Oct", "24 Oct", "25 Oct"
    local shown = C.StripLabels(runs, 15.5, 868)
    assertNil(shown[1], "23 Oct: one run, under the pitch of 24 Oct's twelve")
    assertTrue(shown[2] ~= nil and shown[14] ~= nil)
    -- Two blocks of one size keep the earlier one.
    local even = { { count = 1, label = "a" }, { count = 1, label = "b" }, { count = 1, label = "c" } }
    shown = C.StripLabels(even, 15, 300)
    assertTrue(shown[1] ~= nil)
    assertNil(shown[2])
    assertNil(shown[3], "c is 30 px past a")
    -- Columns before the first label belong to no block, and an unlabeled strip shows nothing.
    assertNil(next(C.StripLabels({ { count = 1 }, { count = 1 } }, 48, 300)))
end)

test("insights charts: StripLabels keeps the end labels inside the content on a dense strip", function()
    local C = inst().Charts
    local K = C.K
    local half = K.STRIP_LABEL_PITCH / 2
    local days = {}
    for n = 1, 90 do days[n] = { count = 1, label = tostring(n) } end
    local innerW = 886
    local slot = C.StripSlots(innerW, #days)
    local shown = C.StripLabels(days, slot, innerW)
    -- The first column's center is under 10 px: the label shifts right until its left half fits.
    assertEqual(slot / 2 + shown[1], half)
    -- Every label shown sits inside the content, and no two are under the pitch apart.
    local xs = {}
    for idx, dx in pairs(shown) do xs[#xs + 1] = (idx - 0.5) * slot + dx end
    table.sort(xs)
    assertTrue(xs[1] >= half and xs[#xs] <= innerW - half)
    for n = 2, #xs do assertTrue(xs[n] - xs[n - 1] >= K.STRIP_LABEL_PITCH) end
    -- The last column's label, when it shows, is pulled left the same way.
    local tail = {}
    for n = 1, 10 do tail[n] = { count = 1 } end
    tail[10].label = "end"
    shown = C.StripLabels(tail, 10, 100)
    assertEqual(shown[10], (100 - half) - 95)
end)

test("insights charts: a strip shifts an end label by its offset, from under its column", function()
    local i = inst()
    local K = i.Charts.K
    local pool = i.ctx:Pool("strip")
    local days = {}
    for n = 1, 90 do days[n] = { count = 1, label = tostring(n), info = "x" } end
    i.ctx:renderStrip(pool, i.ctx:sectionHeader(nil, "x"), i.ctx:strip(), days, 0, 902, 8)
    local slot = i.Charts.StripSlots(886, 90)
    local p = point(pool.active[1].axis)
    assertEqual(p[4], K.STRIP_LABEL_PITCH / 2 - slot / 2, "pulled right, inside the content")
end)

test("insights charts: StripSlots widens the columns up to a cap, and never below 2 px", function()
    local C = inst().Charts
    local K = C.K
    local slot, barW = C.StripSlots(1000, 6)
    assertEqual(slot, K.STRIP_SLOT_MAX)
    assertEqual(barW, K.STRIP_BAR_MAX)
    slot, barW = C.StripSlots(1050, 56)
    assertEqual(slot, 1050 / 56)
    assertEqual(barW, 1050 / 56 - 2)
    assertEqual(select(2, C.StripSlots(100, 100)), 2)
end)

-- ── the list panel ──────────────────────────────────────────────────────────────────────────────

test("insights charts: a list panel caps at ten rows, sized to them, each hover stating its value", function()
    local i = inst()
    local K = i.Charts.K
    local panel = i.ctx:listPanel(nil, "Late Casts")
    assertEqual(panel.title.__text, "Late Casts")
    assertTrue(sameColor(panel.title.__color, i.host.colors.heading))
    local rows = {}
    for n = 1, 12 do rows[n] = { name = "Spell " .. n, right = tostring(13 - n) } end
    rows[2].nameColor = { 0.5, 0.5, 0.5 }
    local pool = i.ctx:Pool("late")
    local h = i.ctx:renderListPanel(pool, panel, rows, -30, 280, 8)
    assertEqual(#pool.active, K.LIST_MAX)
    assertEqual(h, K.LIST_TITLE_H + K.LIST_MAX * K.LIST_ROW_H + 4)
    assertEqual(panel.__height, h)
    assertTrue(sameColor(pool.active[2].name.__color, { 0.5, 0.5, 0.5 }))
    assertTrue(sameColor(pool.active[1].name.__color, i.host.colors.body))
    hover(pool.active[3])
    assertEqual(lastTip(i).lines[1], "Spell 3:  10")
end)

test("insights charts: a list row's click is the row's own, and a reused row forgets the last one", function()
    local i = inst()
    local panel = i.ctx:listPanel(nil, "Recent New Bests")
    local pool = i.ctx:Pool("bests")
    local got = {}
    local rows = { { name = "Run A", right = "+27%", onClick = function(_, button) got[#got + 1] = button end } }
    i.ctx:renderListPanel(pool, panel, rows, 0, 280, 8)
    local row = pool.active[1]
    row:GetScript("OnMouseUp")(row, "RightButton")
    assertEqual(got[1], "RightButton")
    i.ctx:ReleaseAll()
    i.ctx:renderListPanel(pool, panel, { { name = "Run B", right = "+3%" } }, 0, 280, 8)
    assertEqual(pool.active[1], row, "the same row, reused")
    row:GetScript("OnMouseUp")(row, "LeftButton")
    assertEqual(#got, 1, "no click carried over")
end)

-- ── the pools ───────────────────────────────────────────────────────────────────────────────────

local function drawAll(i, chrome)
    local ctx = i.ctx
    ctx:renderBarSection(ctx:Pool("bars"), chrome.h1, SPECS, 0, 600, 8, ctx:Pool("legend"))
    ctx:renderStackedBarSection(ctx:Pool("stacked"), chrome.h2, {
        { label = "Traxex", value = "2", segments = { { frac = 1, color = { 1, 1, 1 }, tip = "x" } } },
    }, 0, 600, 8)
    ctx:renderStrip(ctx:Pool("strip"), chrome.h3, chrome.strip, {
        { count = 1, label = "a", info = "a" }, { count = 2, label = "b", info = "b" },
    }, 0, 600, 8)
    ctx:renderListPanel(ctx:Pool("list"), chrome.panel, { { name = "a", right = "1" }, { name = "b", right = "2" } },
        0, 280, 8)
end

test("insights charts: a second pass after ReleaseAll builds no frame; every pool comes back whole", function()
    local i = inst()
    local chrome = { h1 = i.ctx:sectionHeader(nil, "1"), h2 = i.ctx:sectionHeader(nil, "2"),
                     h3 = i.ctx:sectionHeader(nil, "3"), strip = i.ctx:strip(), panel = i.ctx:listPanel(nil, "4") }
    drawAll(i, chrome)
    local first = i.made
    assertTrue(first > 0)
    local active = {}
    for _, name in ipairs({ "bars", "legend", "stacked", "strip", "list" }) do
        local _, n = i.NS.Pool.Counts(i.ctx:Pool(name))
        active[name] = n
    end
    i.ctx:ReleaseAll()
    for name, n in pairs(active) do
        local free, out = i.NS.Pool.Counts(i.ctx:Pool(name))
        assertEqual(free, n, name .. " parked")
        assertEqual(out, 0, name .. " released")
    end
    i.made = 0
    drawAll(i, chrome)
    assertEqual(i.made, 0, "the second pass created nothing")
end)

-- ── the chrome ──────────────────────────────────────────────────────────────────────────────────

test("insights charts: a divider rules both sides of its centered title in the host's colors", function()
    local i = inst()
    local d = i.ctx:sectionDivider(nil, "Damage")
    assertEqual(d.fs.__text, "Damage")
    assertEqual(d.fs.__fontObject, "DividerFont")
    assertEqual(#d.rules, 2)
    assertTrue(sameColor(d.rules[1].__colorTex, i.host.colors.rule))
    assertEqual(i.ctx:sectionHeader(nil, "x").__fontObject, "HeadingFont")
end)

test("insights charts: a stat card is LootHistory's: the gold figure on top, centered, the caption below", function()
    local i = inst()
    local card = i.ctx:card(nil, "Races run")
    assertEqual(card.label.__text, "Races run")
    assertEqual(card.label.__fontObject, "CaptionFont")
    assertEqual(card.frame.__height, i.Charts.K.CARD_H)
    assertEqual(point(card.value)[1], "TOP", "the figure on top")
    assertEqual(point(card.label)[1], "BOTTOM", "the caption under it")
    assertEqual(card.value.__justifyH, "CENTER")
    assertEqual(card.label.__justifyH, "CENTER")
    assertTrue(sameColor(card.label.__color, i.host.colors.caption))
    i.ctx:setCard(card, "56")
    assertEqual(card.value.__text, "56")
    assertEqual(card.value.__fontObject, "FigureFont")
    assertTrue(sameColor(card.value.__color, i.host.colors.heading), "gold by default")
    hover(card.frame)
    assertEqual(lastTip(i).lines[1], "Races run:  56")
    i.ctx:setCard(card, "89%", { "Clean runs", "50 of 56" }, nil, { 0.36, 0.86, 0.46 })
    assertTrue(sameColor(card.value.__color, { 0.36, 0.86, 0.46 }), "colored when it means something")
    hover(card.frame)
    assertEqual(lastTip(i).lines[2], "50 of 56")
    i.ctx:setCard(card, "57")
    assertTrue(sameColor(card.value.__color, i.host.colors.heading), "back to gold")
end)

test("insights charts: the panel comes from the host, a plain frame without one", function()
    local i = inst()
    local made = {}
    i.host.panel = function(parent)
        local f = i.mocks.CreateFrame("Frame", nil, parent)
        made[#made + 1] = f
        return f
    end
    local ctx = i.Charts:New(i.content, i.host)
    local p = ctx:listPanel(nil, "x")
    assertEqual(made[1], p)
    assertEqual(ctx:card(nil, "y").frame, made[2])
    assertTrue(i.ctx:listPanel(nil, "z") ~= nil)
end)

-- ── the DpsRace host ────────────────────────────────────────────────────────────────────────────

test("insights charts: the DpsRace host pools through NS.Pool and draws in the window's look", function()
    local i = inst()
    local host = i.NS.ChartsHost()
    local Style, Tbl = i.NS.Style, i.NS.ResultsTable
    assertEqual(host.pool, i.NS.Pool)
    assertEqual(host.fonts.label, Style.FONT.TEXT)
    assertEqual(host.fonts.figure, Style.FONT.FIGURE)
    assertEqual(host.fonts.caption, Style.FONT.CAPTION)
    -- LootHistory's heading size (the owner's call, 2026-10-28), the list panels' titles alike.
    assertEqual(host.fonts.heading, "GameFontNormal")
    assertEqual(host.fonts.panelTitle, host.fonts.heading)
    assertEqual(host.colors.heading, Style.GOLD)
    assertEqual(host.colors.body, Tbl.COLORS.text)
    -- Every color a live skin color: the chart tokens for the track, the axis and the rule, the
    -- owner's bar blue, the skin's ranked palette; and the skin's seams for labels and textures.
    assertEqual(host.colors.track, Style.Tok("chart.track"))
    assertEqual(host.colors.axis, Style.Tok("chart.axis"))
    assertEqual(host.colors.rule, Style.Tok("section.rule"))
    assertEqual(host.colors.bar, Style.Tok("dr.chart.bar"))
    assertEqual(host.palette(), i.NS.Skin.Token("chart.series"), "the skin's palette, read when a chart draws")
    assertEqual(host.fill, Style.Fill)
    assertEqual(host.text, Style.PlainText)
    -- The window's flat panel: the skin's Panel, recorded for this owner (a skin switch repaints it).
    local p = host.panel(i.content)
    local rec = i.mocks.LibStub("LibKa0s-Skin-1.0").painted[p]
    assertTrue(rec ~= nil and rec.owner == "DpsRace" and rec.calls.Panel ~= nil, "the window's flat panel")
end)

test("insights charts: the DpsRace host's tooltip is a gold title over bulleted lines, by the cursor", function()
    local i = inst()
    local tip = { lines = {} }
    for _, m in ipairs({ "Show", "Hide" }) do tip[m] = function() end end
    function tip.SetOwner(_, owner, anchor) tip.owner, tip.anchor, tip.lines = owner, anchor, {} end
    function tip.SetText(_, text, r, g, b) tip.lines[1], tip.title = text, { r, g, b } end
    function tip.AddLine(_, text) tip.lines[#tip.lines + 1] = text end
    i.mocks.GameTooltip = tip
    local ctx = i.Charts:New(i.content, i.NS.ChartsHost())
    local pool = ctx:Pool("bars")
    ctx:renderBarSection(pool, ctx:sectionHeader(nil, "x"), SPECS, 0, 600, 8)
    hover(pool.active[2])
    assertEqual(tip.anchor, "ANCHOR_CURSOR_RIGHT")
    assertEqual(tip.lines[1], "Destruction")
    assertTrue(sameColor(tip.title, i.NS.Style.GOLD))
    assertEqual(tip.lines[2], i.NS.Style.BULLET .. "Best 342.0k")
    hover(pool.active[1])
    assertEqual(tip.lines[1], "Beast Mastery:  417.2k")
    assertNil(tip.lines[2])
end)

-- ══ the tab half (modules/Results_Insights.lua) ═════════════════════════════════════════════════
-- The tab in the Results window: built on its first show, the filter bar (faceted dropdowns with
-- counts, the two checks, Save / Reset / Clear on profile.views.insights), the cards and the
-- sections drawn from one stats pass, the section rows' clicks and menus, the empty state, the sample
-- history in test mode, a load with no library, and a resize that rebinds nothing.

local NOW = os.time()
local HOUR, DAY = 3600, 86400

local CHARS = {
    lan = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction", ilvl = 313.2 },
    mage = { name = "Kaosmage", realm = "Frostmourne", class = "MAGE", specID = 63, spec = "Fire", ilvl = 311.0 },
}

local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

--- A stored-shape run: a complete 3:00 cleave race by Lanfear. `fields` replaces any top-level field;
--- `char` names one of CHARS.
local function mkRun(id, fields)
    local run = {
        id = id, schema = 1, status = "complete", addon = "0.1.0", build = 120105, date = NOW - HOUR,
        race = { length = 180, grace = 1.0, restartGap = 6, startSource = "meterSession", sessionID = 25 },
        char = copy(CHARS.lan),
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        where = { mapID = 2393, zone = "Silvermoon City", instanceType = "none" },
        result = { damage = 27000000, dps = 150000, sessionDuration = 190, tail = 9.2, combatEnd = 7.3 },
        flags = { lateCasts = {}, reloaded = false, died = false },
        spells = { { id = 29722, dmg = 7000000, dps = 1 }, { id = 116858, dmg = 3000000, dps = 1 } },
        note = "",
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    if type(run.char) == "string" then run.char = copy(CHARS[run.char]) end
    return run
end

-- Two Destruction cleave 3:00 runs (the second a new best, +6.7%), a Fire boss 1:00 run with one
-- counted late cast (Incinerate) and one the defaults ignore (Feign Death), an incomplete run and a
-- lost one.
local function fixtureRuns()
    return {
        mkRun("a", { date = NOW - 3 * DAY }),
        mkRun("b", { date = NOW - 2 * DAY, result = { damage = 28800000, dps = 160000, tail = 4.0 } }),
        mkRun("c", { date = NOW - DAY, char = "mage", race = { length = 60, grace = 1.0 },
                     target = { npcID = 243205, name = "Golem", category = "boss" },
                     result = { damage = 7200000, dps = 120000, tail = 25 },
                     flags = { lateCasts = { { t = 1.6, spellID = 29722 }, { t = 3.0, spellID = 5384 } } } }),
        mkRun("d", { status = "incomplete", race = { length = 60, grace = 1.0 },
                     result = { damage = 1, dps = 1, endedAt = 41 } }),
        mkRun("e", { status = "lost", date = NOW - 2 * HOUR, result = nil }),
    }
end

--- A fresh instance with the widget recorder, `runs` stored, and the window open on Insights.
local function tab(runs, opts)
    opts = opts or {}
    local i = T.load{ libFiles = opts.libFiles, mutate = function(m)
        if not opts.bare then Widgets.install(m) end
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
    end }
    for _, run in ipairs(runs or fixtureRuns()) do i.NS.db.global.runs[run.id] = run end
    i.NS.Bests.Invalidate()
    i.R = i.NS.Results
    if opts.closed then return i end
    assertTrue(i.R.ShowTab("insights"))
    i.ui = i.R.__ui()
    i.pane = assert(i.ui.panes.insights)
    return i
end

local function labels(options)
    local out = {}
    for n, o in ipairs(options or {}) do out[n] = o.label end
    return table.concat(out, "|")
end

local function active(pane, name)
    return pane.ctx:Pool(name).active
end

test("insights tab: built on its first show, its tab label gold while it shows", function()
    local i = tab(nil, { closed = true })
    i.R.Show()
    local u = i.R.__ui()
    assertNil(u.panes.insights, "built before it was shown")
    assertTrue(i.R.ShowTab("insights"))
    assertTrue(u.panes.insights.frame:IsShown())
    assertEqual(u.tabs.insights.label.__color[2], i.NS.Style.GOLD[2], "the active tab is gold")
    assertEqual(u.tabs.runs.label.__color[1], 0.7, "the idle tab is gray")
end)

test("insights tab: the dropdowns list the stored runs with their counts, led by All (no Current head)", function()
    local i = tab()
    local dd = i.pane.dropdowns
    assertEqual(labels(dd.char._options), "All characters (3)|Kaosmage (1)|Lanfear (2)")
    assertEqual(labels(dd.spec._options), "All specs (3)|Destruction (2)|Fire (1)")
    assertEqual(labels(dd.length._options), "Any length (3)|1:00 (1)|3:00 (2)")
    assertEqual(dd.date._options[1].label, "All time (3)")
    assertEqual(dd.char._value, "all")
    -- Closed, a dropdown names its choices, not the runs (the owner's call, plan step V-d).
    assertEqual(dd.char.text.__text, "All characters (2)")
    assertEqual(dd.spec.text.__text, "All specs (2)")
    assertEqual(dd.length.text.__text, "Any length (2)")
    assertEqual(dd.date.text.__text, "All time", "the date ranges always number four")
    assertFalse(i.pane.filters.cleanOnly)
    assertFalse(i.pane.filters.includeIncomplete, "Include incomplete starts off (D-11)")
    assertEqual(i.pane:Count(), 3, "the lost and the incomplete run left out")
    assertEqual(i.ui.footLeft.__text, "3 runs \194\183 Click a row for details \194\183 right-click for options")
end)

test("insights tab: a filter redraws the cards, and narrows the other dropdowns (faceted)", function()
    local i = tab()
    local pane = i.pane
    assertEqual(pane.cards.runs.value.__text, "3")
    assertTrue(pane:SetFilter("spec", 63))
    assertEqual(pane:Count(), 1)
    assertEqual(pane.cards.runs.value.__text, "1", "the card redrawn")
    assertEqual(i.ui.footLeft.__text, "1 run \194\183 Click a row for details \194\183 right-click for options",
        "the footer's count follows the filter")
    assertEqual(labels(pane.dropdowns.length._options), "Any length (1)|1:00 (1)", "Fire raced 1:00 only")
    assertEqual(pane.dropdowns.spec.text.__text, "Fire", "a pick by its name alone")
    assertEqual(pane.dropdowns.length.text.__text, "Any length (1)")
    assertEqual(labels(pane.dropdowns.spec._options), "All specs (3)|Destruction (2)|Fire (1)",
        "a dropdown lists what the OTHER filters leave")
    assertFalse(pane:SetFilter("group", "none"), "not an Insights filter")
    -- A check through its click.
    pane.checks.includeIncomplete:__fire("OnClick")
    assertTrue(pane.filters.includeIncomplete)
    pane:SetFilter("spec", "all")
    assertEqual(pane:Count(), 4)
end)

test("insights tab: a selection left with no runs falls back to All; the one just changed never", function()
    local i = tab()
    local pane = i.pane
    pane:SetFilter("char", "Kaosmage-Frostmourne")
    assertEqual(pane:Count(), 1)
    pane:SetFilter("spec", 267)
    assertEqual(pane.filters.spec, 267, "kept: the dropdown just changed")
    assertEqual(pane.filters.char, "all", "Kaosmage raced no Destruction")
    assertEqual(pane:Count(), 2)
    assertNil(i.NS.db.profile.views, "a fallback never writes the saved view")
end)

test("insights tab: the cards state the ten figures, each hover naming its value", function()
    local i = tab()
    local c = i.pane.cards
    assertEqual(c.runs.value.__text, "3")
    assertEqual(c.time.value.__text, "7m 00s", "3:00 + 3:00 + 1:00")
    assertEqual(c.best.label.__text, "Best DPS \194\183 Destruction \194\183 Cleave \194\183 3:00")
    assertEqual(c.clean.value.__text, "66.7%", "the Incinerate flags its run; the Feign Death does not")
    assertEqual(c.newBests.value.__text, "1")
    assertEqual(c.chars.value.__text, "2")
    assertEqual(c.specs.value.__text, "2")
    assertEqual(c.activeDays.value.__text, "3")
    assertEqual(c.avg.value.__text, "97.9%", "(150 / 160 + 1 + 1) / 3")
    assertEqual(c.clean.frame._tip[2], "2 of 3 runs carry no flag.", "the hover states the count")
    assertEqual(c.runs.frame._tip[1], "Races run")
    assertEqual(c.activeDays.frame._tip[2], "3 days with a run.")
    -- One spec alone is one board: the raw average.
    i.pane:SetFilter("spec", 267)
    assertEqual(c.avg.label.__text, "Avg DPS")
    assertEqual(c.avg.value.__text, i.NS.Format.Number(155000))
end)

test("insights tab: a card's figure is gold, and colored where it means something", function()
    local i = tab()
    local c, C, GOLD = i.pane.cards, i.NS.ResultsTable.COLORS, i.NS.Style.GOLD
    assertTrue(sameColor(c.runs.value.__color, GOLD))
    assertTrue(sameColor(c.time.value.__color, GOLD))
    assertTrue(sameColor(c.clean.value.__color, C.red), "66.7% clean: under 70%")
    assertTrue(sameColor(c.avg.value.__color, C.green), "97.9% of board best: 90% or more")
    assertTrue(sameColor(c.newBests.value.__color, C.green), "a new best set")
    assertTrue(sameColor(c.best.value.__color, i.NS.ResultsTable.ClassColor("WARLOCK")), "the best's class color")
    -- 80% sits between the bands: gold.
    local runs = {}
    for n = 1, 5 do runs[n] = mkRun("r" .. n, { date = NOW - n * HOUR }) end
    runs[5].flags = { lateCasts = { { t = 1.6, spellID = 29722 } } }
    i = tab(runs)
    assertEqual(i.pane.cards.clean.value.__text, "80.0%")
    assertTrue(sameColor(i.pane.cards.clean.value.__color, GOLD))
    assertTrue(sameColor(i.pane.cards.newBests.value.__color, GOLD), "no new best: gold")
end)

test("insights tab: CardGrid packs four a row, and a short last row is shared out", function()
    local Insights = tab(nil, { closed = true }).NS.ResultsInsights
    local cells, rows = Insights.CardGrid(Insights.CARDS, 4)
    assertEqual(rows, 3, "ten cards, two of them wide: three full rows")
    for n, def in ipairs(Insights.CARDS) do
        if def.wide then assertEqual(cells[n].span, 2, def.key .. " spans two") end
    end
    assertEqual(cells[#cells].col + cells[#cells].span, 4, "the last row is full")
    -- Seven units: the last row's three cards share four columns.
    cells, rows = Insights.CardGrid({ {}, {}, {}, {}, {}, { wide = true } }, 4)
    assertEqual(rows, 2)
    assertEqual(cells[5].span, 4 / 3)
    assertEqual(cells[6].col, 4 / 3)
    assertEqual(cells[6].span, 8 / 3)
    assertEqual(cells[6].col + cells[6].span, 4)
    -- A wide card that does not fit moves down whole, and the row above keeps its gap filled.
    cells = Insights.CardGrid({ {}, {}, {}, { wide = true } }, 4)
    assertEqual(cells[4].row, 1)
    assertEqual(cells[4].span, 4)
    assertEqual(#Insights.CardGrid({}, 4), 0)
end)

test("insights tab: the cards fill even rows across the content, none half empty", function()
    local i = tab()
    local c = i.pane.cards
    local w = i.pane.width
    local inner = w - 16
    local function right(card) return point(card.frame)[4] + card.frame.__width end
    assertEqual(point(c.runs.frame)[5], point(c.clean.frame)[5], "one row")
    assertTrue(math.abs(right(c.clean) - (8 + inner)) <= 1, "the first row ends at the margin")
    assertTrue(math.abs(right(c.span) - (8 + inner)) <= 1, "and so does the last")
    assertEqual(point(c.best.frame)[5], point(c.span.frame)[5], "the two wide cards share the last row")
end)

test("insights tab: above 60 runs the progression is one column a day, the same day of two years apart", function()
    local runs = {}
    for n = 1, 61 do
        local year = n <= 31 and 2025 or 2026
        runs[n] = mkRun("p" .. n, { date = os.time({ year = year, month = 10, day = 25, hour = 12, min = n }) })
    end
    local i = tab(runs)
    local cols = active(i.pane, "progression")
    assertEqual(#cols, 2, "one column for 25 Oct 2025 and one for 25 Oct 2026")
    assertEqual(cols[1]._tip[2], "31 runs")
    assertEqual(cols[2]._tip[2], "30 runs")
    assertTrue(cols[1]._tip[1]:find("2025") ~= nil, "the hover names the year")
end)

test("insights tab: DPS Progression carries a legend of its specs in their class colors", function()
    local i = tab()
    local chips = active(i.pane, "progressionLegend")
    assertEqual(#chips, 2)
    assertEqual(chips[1].fs.__text, "Destruction")
    assertEqual(chips[2].fs.__text, "Fire")
    assertTrue(sameColor(chips[2].sw.__colorTex, i.NS.ResultsTable.ClassColor("MAGE")))
    assertEqual(chips[1]._tip, "Destruction:  2 runs")
    assertEqual(point(chips[1])[4], 8, "under the strip, from its left edge")
end)

test("insights tab: a section with nothing to show hides; Top Spells and Races By Length are gone", function()
    local i = tab()
    local pane, H = i.pane, i.pane.headers
    assertTrue(H.progression:IsShown())
    assertTrue(H.boards:IsShown())
    assertTrue(H.specs:IsShown())
    assertFalse(H.consistency:IsShown(), "no spec has three runs on a board")
    assertTrue(H.chars:IsShown())
    assertTrue(H.charLength:IsShown())
    assertTrue(H.tail:IsShown())
    assertNil(H.spells, "Top Spells removed (plan step V-h)")
    assertNil(H.lengths, "Races By Length became Races By Character x Length (V-g)")
    assertTrue(pane.panels.late:IsShown())
    assertTrue(pane.panels.bests:IsShown())
    pane:SetFilter("spec", 267)
    assertFalse(pane.panels.late:IsShown(), "no late cast in these runs")
    assertEqual(H.specs.__text, "Spec Comparison", "the tab names the board")
    pane:SetFilter("spec", 63)
    assertFalse(pane.panels.bests:IsShown(), "one run sets no new best")
end)

test("insights tab: a tab per target x length board, the most raced first, the pick kept while present", function()
    local i = tab()
    local pane = i.pane
    local tabs = active(pane, "boardTabs")
    assertEqual(#tabs, 2)
    assertEqual(tabs[1].label.__text, "Cleave \194\183 3:00", "the catalog's order: cleave before boss")
    assertEqual(tabs[2].label.__text, "Boss-level \194\183 1:00")
    assertEqual(pane.boardKey, "cleave|180", "the most raced board")
    assertTrue(tabs[1].underline:IsShown())
    assertFalse(tabs[2].underline:IsShown())
    assertEqual(active(pane, "specs")[1].label.__text, "Destruction")
    assertEqual(tabs[2]._tip[2], "1 run")
    tabs[2]:GetScript("OnClick")(tabs[2])
    assertEqual(pane.boardKey, "boss|60")
    local specs = active(pane, "specs")
    assertEqual(#specs, 1)
    assertEqual(specs[1].label.__text, "Fire")
    assertTrue(active(pane, "boardTabs")[2].underline:IsShown(), "the pick redrawn")
    -- Kept through a redraw that leaves it present; the most raced again once it is gone.
    pane:SetFilter("date", "30d")
    assertEqual(pane.boardKey, "boss|60")
    pane:SetFilter("cleanOnly", true)
    assertEqual(pane.boardKey, "cleave|180", "the boss run is flagged")
    assertEqual(#active(pane, "boardTabs"), 1)
end)

test("insights tab: Consistency on a board tab is a worst-to-best range per spec, the average marked", function()
    local runs = {}
    for n, v in ipairs({ 150000, 160000, 140000 }) do
        runs[n] = mkRun("r" .. n, { date = NOW - n * HOUR, result = { damage = v * 180, dps = v, tail = 5 } })
    end
    local i = tab(runs)
    local pane = i.pane
    assertTrue(pane.headers.consistency:IsShown())
    assertEqual(pane.headers.consistency.__text, "Consistency")
    local rows = active(pane, "consistency")
    assertEqual(#rows, 1)
    assertEqual(rows[1].label.__text, "Destruction")
    assertTrue(rows[1].mark:IsShown(), "the average's mark")
    assertEqual(rows[1].value.__text, "93.8%", "the average run's share of the best")
    local tip = rows[1]._tip
    assertEqual(tip[1], "Destruction")
    assertEqual(tip[2], "Best " .. i.NS.Format.Number(160000) .. " DPS")
    assertEqual(tip[4], "Worst " .. i.NS.Format.Number(140000) .. " DPS")
    assertEqual(tip[#tip], "3 runs")
    local scale = active(pane, "consistencyScale")[1]
    assertEqual(scale.lo.__text, i.NS.Format.Number(140000))
    assertEqual(scale.hi.__text, i.NS.Format.Number(160000))
end)

test("insights tab: Races By Character x Length stacks each character's races in the length colors", function()
    local i = tab()
    local pane = i.pane
    assertEqual(pane.headers.charLength.__text, "Races By Character \195\151 Length")
    local rows = active(pane, "charLength")
    assertEqual(#rows, 2)
    assertEqual(rows[1].label.__text, "Lanfear")
    assertEqual(rows[1].value.__text, "2")
    local Tbl = i.NS.ResultsTable
    assertTrue(sameColor(rows[1].segs[1].tex.__colorTex, Tbl.LengthColor(180)))
    assertEqual(rows[1].segs[1]._tip, "3:00: 2")
    local chips = active(pane, "charLengthLegend")
    assertEqual(#chips, 2)
    assertEqual(chips[1].fs.__text, "1:00", "shortest first")
    assertEqual(chips[2].fs.__text, "3:00")
end)

test("insights tab: one date format everywhere: the day, then the time where it matters", function()
    local i = tab()
    local pane, Tbl = i.pane, i.NS.ResultsTable
    local function day(t) return Tbl.Date(t, "%d %b") end
    local first, last = NOW - 3 * DAY, NOW - DAY
    assertEqual(pane.cards.span.value.__text, day(first) .. " to " .. day(last))
    assertEqual(pane.cards.best.frame._tip[3], day(NOW - 2 * DAY) .. Tbl.Date(NOW - 2 * DAY, " %H:%M"))
    local cols = active(pane, "progression")
    assertEqual(cols[1].axis.__text, day(first), "a strip label")
    assertEqual(cols[1]._tip[2], day(first) .. Tbl.Date(first, " %H:%M"))
    local perDay = active(pane, "perDay")
    assertEqual(perDay[1]._tip, day(first) .. ": 1 run")
    local best = active(pane, "bests")[1]
    assertEqual(best.name.__text:sub(1, #day(NOW - 2 * DAY)), day(NOW - 2 * DAY))
    assertEqual(best._tip[2], day(NOW - 2 * DAY) .. Tbl.Date(NOW - 2 * DAY, " %H:%M"))
end)

test("insights tab: Late Casts keeps room for the ignored spells when the counted ones pass ten", function()
    local casts = {}
    for n = 1, 12 do casts[n] = { t = 1.5, spellID = 100000 + n } end
    casts[13] = { t = 2, spellID = 5384 }
    local i = tab({ mkRun("x", { flags = { lateCasts = casts } }) })
    local rows = active(i.pane, "late")
    assertEqual(#rows, 10)
    assertTrue(rows[10].name.__text:find("(ignored)", 1, true) ~= nil, "the ignored row was cut")
    rows[10]:GetScript("OnMouseUp")(rows[10], "RightButton")
    assertTrue(i.mocks.__lastMenu ~= nil, "no way to stop ignoring it from Insights")
end)

test("insights tab: Late Casts lists the counted spells, then the ignored ones dimmed and tagged", function()
    local i = tab()
    local rows = active(i.pane, "late")
    assertEqual(#rows, 2)
    assertEqual(rows[1].name.__text, "Incinerate")
    assertEqual(rows[2].name.__text, "Feign Death (ignored)")
    local dim = i.NS.ResultsTable.COLORS.dim
    assertEqual(rows[2].name.__color[1], dim[1])
    assertTrue(rows[1]._tip[3]:find("Right%-click to ignore") ~= nil)
end)

test("insights tab: a right-click on a Late Casts row opens the ignore list's menu, which redraws the tab", function()
    local i = tab()
    local M = i.mocks
    local row = active(i.pane, "late")[1]
    row:GetScript("OnMouseUp")(row, "LeftButton")
    assertNil(M.__lastMenu, "a left click opens nothing")
    row:GetScript("OnMouseUp")(row, "RightButton")
    local menu = assert(M.__lastMenu)
    assertEqual(menu.titles[1], "Late casts")
    menu:Click("Ignore Incinerate for late casts")
    assertTrue(i.NS.LateIgnore.Set()[29722] == true)
    -- Both ignored now, Feign Death (5384) first on the tie.
    local rows = active(i.pane, "late")
    assertEqual(rows[2].name.__text, "Incinerate (ignored)", "the tab redrawn on the list's change")
    assertEqual(i.pane.cards.clean.value.__text, "100.0%")
    rows[2]:GetScript("OnMouseUp")(rows[2], "RightButton")
    M.__lastMenu:Click("Stop ignoring Incinerate")
    assertEqual(active(i.pane, "late")[1].name.__text, "Incinerate")
end)

test("insights tab: a Recent New Bests row opens its run on the Runs tab; a right-click its row menu", function()
    local i = tab()
    local rows = active(i.pane, "bests")
    assertEqual(#rows, 1)
    assertTrue(rows[1].count.__text:find("+6.7%", 1, true) ~= nil)
    rows[1]:GetScript("OnMouseUp")(rows[1], "RightButton")
    assertTrue(i.mocks.__lastMenu ~= nil and i.mocks.__lastMenu:Find("Add Note") ~= nil, "the run's row menu")
    rows[1]:GetScript("OnMouseUp")(rows[1], "LeftButton")
    assertEqual(i.R.Tab(), "runs")
    assertEqual(i.R.Selected(), "b")
end)

test("insights tab: with no run the empty state shows, and every card and section hides", function()
    local i = tab({})
    local pane = i.pane
    assertEqual(pane:Count(), 0)
    assertTrue(pane.empty:IsShown())
    assertEqual(pane.empty.__text, "No runs match these filters.")
    assertFalse(pane.cards.runs.frame:IsShown())
    assertFalse(pane.headers.progression:IsShown())
    assertFalse(pane.panels.late:IsShown())
    i.NS.db.global.runs.a = mkRun("a")
    i.NS.SendBus(i.NS.MSG.RUNS_CHANGED)
    assertFalse(pane.empty:IsShown(), "the store's change redrew the tab")
    assertTrue(pane.cards.runs.frame:IsShown())
end)

test("insights tab: Save, Clear and Reset keep the view at profile.views.insights", function()
    local i = tab()
    local pane = i.pane
    pane:SetFilter("char", "Lanfear-Frostmourne")
    pane:SetFilter("cleanOnly", true)
    assertEqual(pane:Count(), 2)
    assertTrue(pane:SaveView())
    local saved = i.NS.db.profile.views.insights
    assertEqual(saved.filters.char, "Lanfear-Frostmourne")
    assertTrue(saved.filters.cleanOnly)
    pane:SetFilter("char", "all")
    pane:ClearView()
    assertEqual(pane.filters.char, "Lanfear-Frostmourne", "Clear returns to the saved view")
    -- A new build opens on it.
    local again = i.NS.ResultsInsights.Build(i.ui.body, {})
    assertEqual(again.filters.char, "Lanfear-Frostmourne")
    assertTrue(pane:ResetView())
    assertNil(i.NS.db.profile.views, "the saved view deleted")
    assertEqual(pane.filters.char, "all")
    assertFalse(pane.filters.cleanOnly)
end)

test("insights tab: test mode fills the tab from the sample history; Save refuses and nothing is stored", function()
    local i = tab({})
    assertTrue(i.NS.Preview.Start())
    local pane = i.pane
    assertTrue(pane:Count() > 0, "no sample run on the tab")
    assertFalse(pane.empty:IsShown())
    local late = pane.stats.lateBySpell
    assertEqual(late.ignored[1] and late.ignored[1].id, 8690, "the sample's late Hearthstone, ignored")
    assertTrue(#late.counted > 0, "the Flagged sample's counted casts")
    assertTrue(#active(pane, "bests") > 0)
    for _, name in ipairs({ "progression", "boards", "specs", "chars", "charTarget", "charLength", "perDay", "tail" }) do
        assertTrue(pane.headers[name]:IsShown(), name .. " drew nothing from the samples")
    end
    -- A late-cast row offers no menu on a sample (D-7).
    local row = active(pane, "late")[1]
    row:GetScript("OnMouseUp")(row, "RightButton")
    assertNil(i.mocks.__lastMenu)
    assertFalse(pane:SaveView())
    assertFalse(pane:ResetView())
    assertNil(i.NS.db.profile.views)
    assertEqual(next(i.NS.db.global.runs), nil)
    i.NS.Preview.Stop()
    assertEqual(pane:Count(), 0, "back on the empty store")
end)

test("insights tab: the player's view comes back when test mode ends, so Save never stores the sample's fallback", function()
    local i = tab()
    local pane = i.pane
    pane:SetFilter("char", "Kaosmage-Frostmourne")
    assertTrue(pane:SaveView())
    assertTrue(i.NS.Preview.Start())
    assertEqual(pane.filters.char, "all", "the samples open wide")
    i.NS.Preview.Stop()
    assertEqual(pane.filters.char, "Kaosmage-Frostmourne", "the view the player had")
    assertEqual(pane:Count(), 1)
    -- A view never saved comes back too, and a tab first built during test mode opens on its view.
    pane:SetFilter("length", 180)
    assertTrue(i.NS.Preview.Start())
    i.NS.Preview.Stop()
    assertEqual(pane.filters.length, 180)
    local j = tab(nil, { closed = true })
    assertTrue(j.NS.Preview.Start())
    assertTrue(j.R.ShowTab("insights"))
    local late = j.R.__ui().panes.insights
    j.NS.Preview.Stop()
    assertEqual(late.filters.char, "all")
    assertEqual(late:Count(), 3, "the stock view over the store")
end)

test("insights tab: a load with no library draws no dropdown, and the tab still works", function()
    local i = tab(nil, { libFiles = {}, bare = true })
    assertEqual(next(i.pane.dropdowns), nil, "a dead dropdown was drawn")
    assertEqual(i.pane:Count(), 3)
    assertTrue(i.pane:SetFilter("spec", 63))
    assertEqual(i.pane:Count(), 1)
    i.pane:Layout(902, 400)
    assertNil(i.pane.ctx, "no chart context without the major")
end)

test("insights tab: with no library the empty state says why there are no charts", function()
    local i = tab(nil, { libFiles = {} })
    i.pane:Layout(902, 400)
    assertTrue(i.pane.empty:GetText():find("charts are unavailable", 1, true) ~= nil)
    assertTrue(i.pane.empty:IsShown())
end)

test("insights tab: Resize re-plans the bar and the scroll frame and rebinds nothing", function()
    local i = tab()
    local pane = i.pane
    local released, made = 0, 0
    local release = pane.ctx.ReleaseAll
    pane.ctx.ReleaseAll = function(...) released = released + 1; return release(...) end
    local base = i.mocks.CreateFrame
    i.mocks.CreateFrame = function(...) made = made + 1; return base(...) end
    pane:Resize(1342, 700)
    assertEqual(released, 0, "Resize released the pools")
    assertEqual(made, 0)
    assertEqual(pane.barH, 32, "one row across the expanded body")
    pane:Layout(1342, 700)
    assertEqual(released, 1)
    assertEqual(made, 0, "a second layout pass builds no frame")
end)

test("insights tab: the bar takes two rows in the collapsed window and one in the expanded, edge to edge", function()
    local Ins = tab(nil, { closed = true }).NS.ResultsInsights
    local narrow = Ins.BarPlan(902)
    assertFalse(narrow.oneRow, "the collapsed body (904 - 2) takes two rows")
    assertEqual(narrow.dropdowns.date + narrow.widths.date, 902 - 8, "the dropdowns stretch to the margin")
    assertEqual(narrow.buttons.clear, 902 - 8, "Clear under the last dropdown's right edge")
    assertTrue(narrow.checks.includeIncomplete + 128 < narrow.buttons.save - 52, "no overlap on the second row")
    local wide = Ins.BarPlan(1342)
    assertTrue(wide.oneRow)
    assertEqual(wide.buttons.clear, 1342 - 8)
    local least = Ins.BarPlan(nil)
    assertEqual(least.widths.char, 110, "no width: the least widths")
end)

test("insights tab: the wheel scrolls the content, clamped to it", function()
    local i = tab()
    local pane = i.pane
    pane:Layout(902, 300)
    assertTrue(pane.contentH > pane.viewH, "the sections run past a short window")
    pane:Scroll(-1)
    assertEqual(pane.scroll, 40)
    pane:Scroll(1000)
    assertEqual(pane.scroll, 0)
    pane:Scroll(-1000)
    assertEqual(pane.scroll, pane.contentH - pane.viewH)
end)
