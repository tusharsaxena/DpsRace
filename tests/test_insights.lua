-- tests/test_insights.lua — the Insights tab's drawing half (#12, modules/Results_InsightsCharts.lua),
-- the renderer half of the suite: the chart widgets ported from LootHistory's Insights tab, drawn
-- through a host config table (the colors, the font objects, the tooltip, the panel and the pool), so
-- the renderers read nothing of DpsRace's own (the owner's S-7 answer, for a later promotion into
-- LibKa0s). Pinned here: no NS read above the host section, the pure helpers (a UTF-8-safe truncate,
-- the hover text, the shrink-to-fit figure, the ranked palette), every renderer's geometry and colors,
-- every hover stating its value, the legend under the bars' track, pooled widgets reused over two
-- passes (the second pass builds nothing), the list rows' clicks, the stat card, and the DpsRace host.
-- The tab half (the filter bar, the layout, the sections) joins this file in N4.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil, assertErrorMatches =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil, T.assertErrorMatches
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local SOURCE = T.root .. "/modules/Results_InsightsCharts.lua"
local HOST_MARK = "-- ── the DpsRace host"

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
    i.Charts = i.NS.InsightsCharts
    i.content = base("Frame")
    i.ctx = i.Charts.New(i.content, i.host)
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

test("insights charts: nothing above the host section reads NS or a client global but CreateFrame", function()
    local f = assert(io.open(SOURCE, "rb"))
    local src = f:read("*a")
    f:close()
    local cut = src:find(HOST_MARK, 1, true)
    assertTrue(cut ~= nil, "the host section's marker line")
    local body = src:sub(1, cut - 1)
    -- Drop the comments, then the one line that publishes the module.
    body = body:gsub("%-%-[^\n]*", "")
    body = body:gsub("NS%.InsightsCharts = Charts", "", 1)
    assertNil(body:match("NS[%.%[:]"), "an NS read in the renderers")
    for _, name in ipairs({ "GameTooltip", "RAID_CLASS_COLORS", "_G" }) do
        assertNil(body:match("%f[%w_]" .. name .. "%f[^%w_]"), name .. " read in the renderers")
    end
end)

test("insights charts: the header names the LootHistory source commit the port came from", function()
    local f = assert(io.open(SOURCE, "rb"))
    local head = f:read(2000)
    f:close()
    assertTrue(head:find("LootHistory", 1, true) ~= nil)
    assertTrue(head:find("2319fd6", 1, true) ~= nil)
    assertTrue(head:find("AnalyticsCharts.lua", 1, true) ~= nil)
    assertTrue(head:find("AnalyticsFormat.lua", 1, true) ~= nil)
end)

test("insights charts: New wants a host pool, and fills the colors and fonts it is not given", function()
    local i = inst()
    assertErrorMatches(function() i.Charts.New(i.content, {}) end, "host.pool")
    assertErrorMatches(function() i.Charts.New(i.content) end, "host.pool")
    local ctx = i.Charts.New(i.content, { pool = i.NS.Pool })
    for _, key in ipairs({ "body", "value", "heading", "track", "bar", "muted", "axis", "rule", "caption" }) do
        assertEqual(type(ctx.colors[key]), "table", "a default color for " .. key)
    end
    for _, key in ipairs({ "label", "axis", "heading", "divider", "panelTitle", "caption", "figure" }) do
        assertEqual(type(ctx.fonts[key]), "string", "a default font for " .. key)
    end
    assertTrue(#ctx.palette >= 7)
    -- The host's own table is never written.
    assertNil(i.host.colors.neutral)
end)

-- ── the pure helpers ────────────────────────────────────────────────────────────────────────────

test("insights charts: truncate counts glyphs, not bytes, and ends in an ellipsis", function()
    local C = inst().Charts
    assertEqual(C.truncate("Traxex", 16), "Traxex")
    local s, cut = C.truncate("Beast Mastery cleave", 8)
    assertEqual(s, "Beast M\226\128\166")
    assertTrue(cut)
    -- "Trâxex" is 6 glyphs in 7 bytes: it fits 6, and a cut never splits the â.
    assertEqual((C.truncate("Tr\195\162xex", 6)), "Tr\195\162xex")
    assertEqual((C.truncate("Tr\195\162xex the hunter", 4)), "Tr\195\162\226\128\166")
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
    -- 300 px over 3 columns: 100 px a slot, the column capped at 14.
    assertEqual(point(bars[2])[4], 100)
    assertEqual(bars[1].__width, K.STRIP_BAR_MAX)
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

test("insights charts: a strip takes a fixed top, and thins its labels when the columns crowd", function()
    local i = inst()
    local pool, strip = i.ctx:Pool("strip"), i.ctx:strip()
    local buckets = {}
    for n = 1, 60 do buckets[n] = { count = 0.5, label = tostring(n), info = tostring(n) } end
    i.ctx:renderStrip(pool, i.ctx:sectionHeader(nil, "x"), strip, buckets, 0, 316, 8, 2)
    local K = i.Charts.K
    assertEqual(pool.active[1].fill.__height, (K.DAYSTRIP_H - 2) / 4, "0.5 of a top of 2")
    -- 300 / 60 = 5 px a slot: a label every third column (11 px apart at least).
    assertEqual(pool.active[1].axis.__text, "1")
    assertEqual(pool.active[2].axis.__text, "")
    assertEqual(pool.active[4].axis.__text, "4")
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

test("insights charts: a stat card's caption over its figure, the hover stating the figure", function()
    local i = inst()
    local card = i.ctx:card(nil, "Races run")
    assertEqual(card.label.__text, "Races run")
    assertEqual(card.label.__fontObject, "CaptionFont")
    assertEqual(card.frame.__height, i.Charts.K.CARD_H)
    i.ctx:setCard(card, "56")
    assertEqual(card.value.__text, "56")
    assertEqual(card.value.__fontObject, "FigureFont")
    hover(card.frame)
    assertEqual(lastTip(i).lines[1], "Races run:  56")
    i.ctx:setCard(card, "89%", { "Clean runs", "50 of 56" })
    hover(card.frame)
    assertEqual(lastTip(i).lines[2], "50 of 56")
end)

test("insights charts: the panel comes from the host, a plain frame without one", function()
    local i = inst()
    local made = {}
    i.host.panel = function(parent)
        local f = i.mocks.CreateFrame("Frame", nil, parent)
        made[#made + 1] = f
        return f
    end
    local ctx = i.Charts.New(i.content, i.host)
    local p = ctx:listPanel(nil, "x")
    assertEqual(made[1], p)
    assertEqual(ctx:card(nil, "y").frame, made[2])
    assertTrue(i.ctx:listPanel(nil, "z") ~= nil)
end)

-- ── the DpsRace host ────────────────────────────────────────────────────────────────────────────

test("insights charts: the DpsRace host pools through NS.Pool and draws in the window's look", function()
    local i = inst()
    local host = i.Charts.Host()
    local Style, Tbl = i.NS.Style, i.NS.ResultsTable
    assertEqual(host.pool, i.NS.Pool)
    assertEqual(host.fonts.label, Style.FONT.TEXT)
    assertEqual(host.fonts.figure, Style.FONT.FIGURE)
    assertEqual(host.fonts.caption, Style.FONT.CAPTION)
    assertEqual(host.colors.heading, Style.GOLD)
    assertEqual(host.colors.body, Tbl.COLORS.text)
    local p = host.panel(i.content)
    assertTrue(p.__backdropColor ~= nil, "the window's flat panel")
end)

test("insights charts: the DpsRace host's tooltip is a gold title over bulleted lines, by the cursor", function()
    local i = inst()
    local tip = { lines = {} }
    for _, m in ipairs({ "Show", "Hide" }) do tip[m] = function() end end
    function tip.SetOwner(_, owner, anchor) tip.owner, tip.anchor, tip.lines = owner, anchor, {} end
    function tip.SetText(_, text, r, g, b) tip.lines[1], tip.title = text, { r, g, b } end
    function tip.AddLine(_, text) tip.lines[#tip.lines + 1] = text end
    i.mocks.GameTooltip = tip
    local ctx = i.Charts.New(i.content, i.Charts.Host())
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
