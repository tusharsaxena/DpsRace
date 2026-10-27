-- tests/test_results_timeline_controls.lua — the ability timeline's P16 round (modules/Results_Timeline.lua):
-- a Casts icon's tooltip under the icon at the cursor; Ctrl+wheel zooming a step about the cursor
-- (ahead of Shift); the zoom controls read "- +"; the `?` control's mouse-controls tooltip; the controls
-- ending on the lanes' right edge; the wider gap between the two strips; and every corridor on its
-- run's dark, translucent CORRIDOR color, repainted from a /run change.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600
local FRAME = 1 / 60

local INFERNAL, SOUL_FIRE, CONFLAG, INCINERATE = 1122, 6353, 17962, 29722
local SPELLS = { [INFERNAL] = 180000, [SOUL_FIRE] = 45000, [CONFLAG] = 13000, [INCINERATE] = 0 }
local THIS = { { 1, INFERNAL }, { 2, INCINERATE }, { 30, SOUL_FIRE }, { 59, INCINERATE } }
local BEST = { { 0.5, SOUL_FIRE }, { 20, CONFLAG }, { 40, INCINERATE } }

local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
    end }
    i.R, i.TL = i.NS.Results, i.NS.ResultsTimeline
    i.NS.db.profile.windows.results.view = "expanded"
    return i
end

--- A stored-shape complete 1:00 cleave run by Lanfear (Destruction) with the casts `list` ({ t, id }).
local function mkRun(NS, id, dps, list, fields)
    local decoded = {}
    for n, c in ipairs(list) do decoded[n] = { t = c[1], id = c[2], pet = false } end
    local run = {
        id = id, schema = 3, status = "complete", addon = "0.1.0", date = NOW - HOUR,
        race = { length = 60, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction" },
        target = { npcID = 225983, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 60, dps = dps, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = INCINERATE, dmg = dps * 50 } }, note = "",
        casts = { v = 1, list = NS.Casts.Encode(decoded), spells = SPELLS, dropped = 0 },
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    return run
end

-- The timeline open on "this", compared with "best".
local function opened()
    local i = inst()
    local NS = i.NS
    for _, run in ipairs({ mkRun(NS, "this", 100, THIS), mkRun(NS, "best", 300, BEST, { date = NOW - 2 * HOUR }) }) do
        NS.db.global.runs[run.id] = run
    end
    NS.Bests.Invalidate()
    i.R.ShowRun("this")
    i.R.__ui().detail.w.timeline:__fire("OnClick")
    return i, assert(i.TL.__ui(), "the timeline was never built")
end

local function last(region) return region.__points[#region.__points] end
local function wheel(frame, delta) frame:GetScript("OnMouseWheel")(frame, delta) end
local function near(a, b, msg) assertTrue(math.abs(a - b) < 1e-9, (msg or "") .. ": " .. tostring(a) .. " vs " .. tostring(b)) end

-- The window's left edge at `left` and its scale `scale`, and the cursor at `at` of the way across the
-- lanes' view (or at the screen x `x` when `at` is nil).
local function cursor(i, u, at, x, left, scale)
    left, scale = left or 100, scale or 1
    rawset(u.frame, "GetLeft", function() return left end)
    rawset(u.frame, "GetEffectiveScale", function() return scale end)
    local _, laneX, laneW = i.TL.LaneGeometry(u.width)
    if at then x = (left + i.TL.PAD + laneX + at * laneW) * scale end
    i.mocks.GetCursorPosition = function() return x, 0 end
end

-- ── the Casts tooltip ───────────────────────────────────────────────────────────────────────────

test("timeline controls: a Casts icon's tooltip sits under the icon at the cursor, the ticks' way", function()
    local i, u = opened()
    local tip = { lines = {} }
    for _, m in ipairs({ "Show", "Hide", "ClearAllPoints", "SetPoint", "SetText" }) do tip[m] = function() end end
    function tip.SetOwner(_, owner, anchor) tip.owner, tip.anchor, tip.lines = owner, anchor, {} end
    function tip.SetSpellByID(_, id) tip.spell, tip.lines[1] = id, "the client's spell text" end
    function tip.AddLine(_, text) tip.lines[#tip.lines + 1] = text end
    function tip.NumLines() return #tip.lines end
    i.mocks.GameTooltip = tip
    local d = i.TL.Icons()[1]
    d.frame:GetScript("OnEnter")(d.frame)
    assertTrue(tip.owner == d.frame, "owned by the icon, not the window")
    assertEqual(tip.anchor, "ANCHOR_BOTTOM", "under it, as a tick's")
    assertEqual(tip.spell, d.cast.id, "the client's spell tooltip first")
    assertEqual(tip.lines[#tip.lines - 1], i.NS.Style.BULLET .. "Cast at 0:01", "then its time on a bullet")
    -- A tick's tooltip anchors the same way (BelowTip), so the two read alike.
    local mark = i.TL.Marks()[1]
    mark.hit:GetScript("OnEnter")(mark.hit)
    assertTrue(tip.owner == mark.hit and tip.anchor == "ANCHOR_BOTTOM")
    assertTrue(u.frame ~= nil)
end)

-- ── Ctrl+wheel ──────────────────────────────────────────────────────────────────────────────────

test("timeline controls: Ctrl+wheel up zooms in a step and down out a step, the buttons' steps", function()
    local i, u = opened()
    local TL = i.TL
    cursor(i, u, nil, -1000)   -- off the view: about the middle
    i.mocks.__modifiers.ctrl = true
    wheel(u.frame, 1)
    assertEqual(TL.Zoom(), TL.ZOOMS[2], "up: one step in")
    wheel(u.scroll, 1)
    assertEqual(TL.Zoom(), TL.ZOOMS[3], "over the lanes too")
    wheel(u.bar, -1)
    assertEqual(TL.Zoom(), TL.ZOOMS[2], "down over the scrollbar: one step out")
    wheel(u.frame, -1)
    wheel(u.frame, -1)
    assertEqual(TL.Zoom(), 1, "stops at 1x")
    for _ = 1, 20 do wheel(u.frame, 1) end
    assertEqual(TL.Zoom(), TL.ZOOMS[#TL.ZOOMS], "stops at the last step")
    assertEqual(u.offset, 0, "no vertical scroll")
    i.mocks.__modifiers.ctrl = false
end)

test("timeline controls: Ctrl wins over Shift; off the time area the zoom keeps the view's middle", function()
    local i, u = opened()
    local TL = i.TL
    TL.ZoomBy(2)   -- 2x
    TL.Pan(-1)
    local pos = u.pos
    cursor(i, u, nil, 0)   -- over the name cells
    i.mocks.__modifiers.ctrl, i.mocks.__modifiers.shift = true, true
    wheel(u.frame, 1)
    assertEqual(TL.Zoom(), 3, "Ctrl and Shift: a zoom, not a pan")
    near(u.pos, TL.Rezoom(pos, 2, 3), "about the middle off the time area")
    i.mocks.__modifiers.ctrl = false
    pos = u.pos
    wheel(u.frame, -1)
    assertEqual(TL.Zoom(), 3, "Shift alone pans again")
    assertTrue(u.pos > pos, "later")
    i.mocks.__modifiers.shift = false
end)

test("timeline controls: Ctrl+wheel keeps the time under the cursor where it was, clamped to the axis", function()
    local i, u = opened()
    local TL = i.TL
    TL.ZoomBy(2)   -- 2x
    TL.Pan(-1)
    i.mocks.__modifiers.ctrl = true
    for _, scale in ipairs({ 1, 0.8 }) do
        TL.ResetZoom()
        TL.ZoomBy(2)
        TL.Pan(-1)
        cursor(i, u, 0.25, nil, 140, scale)
        local before = u.pos + 0.25 / TL.Zoom()
        wheel(u.frame, 1)
        assertEqual(TL.Zoom(), 3)
        near(u.pos + 0.25 / 3, before, "the same moment a quarter across, scale " .. scale)
        wheel(u.frame, -1)
        near(u.pos + 0.25 / 2, before, "and back out")
    end
    -- At an end of the axis the view cannot follow the cursor past it: clamped.
    TL.ResetZoom()
    cursor(i, u, 1)
    wheel(u.frame, 1)
    near(u.pos, TL.PosRange(TL.Zoom()), "the cursor on the right edge at 1x: the end stays at the right")
    TL.ResetZoom()
    cursor(i, u, 0)
    wheel(u.frame, 1)
    assertEqual(u.pos, 0, "on the left edge: 0:00 stays at the left")
    i.mocks.__modifiers.ctrl = false
    -- The buttons still zoom about the middle.
    TL.ResetZoom()
    u.zoomIn:__fire("OnClick")
    near(u.pos, TL.Rezoom(0, 1, 1.5), "the + about the middle")
end)

test("timeline controls: CursorAt is how far across the lanes the cursor is, nil off them", function()
    local TL = inst().TL
    assertEqual(TL.CursorAt(150, 100, 200), 0.25)
    assertEqual(TL.CursorAt(100, 100, 200), 0)
    assertEqual(TL.CursorAt(300, 100, 200), 1)
    assertEqual(TL.CursorAt(99, 100, 200), nil, "over the name cells")
    assertEqual(TL.CursorAt(301, 100, 200), nil, "over the counts")
    assertEqual(TL.CursorAt(nil, 100, 200), nil)
    assertEqual(TL.CursorAt(150, 100, 0), nil)
    near(TL.Rezoom(0.2, 2, 4, 0), 0.2, "about the left edge: the left edge stays")
    near(TL.Rezoom(0.2, 2, 4), TL.Rezoom(0.2, 2, 4, 0.5), "the middle without")
end)

-- ── the controls ────────────────────────────────────────────────────────────────────────────────

test("timeline controls: read left to right the line is the zoom level, -, +, reset, <, >, ?", function()
    local _, u = opened()
    local order = { u.zoomText, u.zoomOut, u.zoomIn, u.zoomReset, u.scrollLeft, u.scrollRight, u.help }
    for n = 1, #order - 1 do
        local at = last(order[n])
        assertTrue(at[2] == order[n + 1] and at[3] == "LEFT", "control " .. n .. " sits left of the next")
    end
    assertEqual(u.zoomOut.glyph.__text, "-")
    assertEqual(u.zoomIn.glyph.__text, "+")
    assertEqual(u.help.glyph.__text, "?")
end)

test("timeline controls: the ? is always live, turns gold under the pointer and its tooltip lists the mouse controls on bullets", function()
    local i, u = opened()
    local B = i.NS.Style.BULLET
    local tip = { lines = {} }
    for _, m in ipairs({ "Show", "Hide", "ClearAllPoints", "SetPoint" }) do tip[m] = function() end end
    function tip.SetOwner(_, owner, anchor) tip.owner, tip.anchor, tip.lines = owner, anchor, {} end
    function tip.SetText(_, text) tip.lines[1] = text end
    function tip.AddLine(_, text) tip.lines[#tip.lines + 1] = text end
    i.mocks.GameTooltip = tip
    assertTrue(u.help:IsEnabled(), "live at 1x")
    u.help:__fire("OnClick")
    assertEqual(i.TL.Zoom(), 1, "a click does nothing")
    u.help:GetScript("OnEnter")(u.help)
    assertTrue(tip.owner == u.help and tip.anchor == "ANCHOR_TOP", "above it, the other controls' way")
    assertEqual(tip.lines[1], "Mouse controls")
    assertEqual(tip.lines[2], B .. "Mouse wheel: scroll up and down")
    assertEqual(tip.lines[3], B .. "Shift+mouse wheel: scroll left and right (zoomed in)")
    assertEqual(tip.lines[4], B .. "Ctrl+mouse wheel: zoom in and out")
    -- Its tooltip leaves the strip's hover in place: gold under the pointer, back at rest after.
    local GOLD, REST = i.NS.Style.GOLD, i.NS.Style.REST
    local function is(c)
        local v = u.help.icon.__vertex
        return v ~= nil and v[1] == c[1] and v[2] == c[2] and v[3] == c[3]
    end
    assertTrue(u.zoomStrip.hovered == u.help and is(GOLD), "gold under the pointer, like the other controls")
    u.help:__fire("OnLeave")
    assertTrue(u.zoomStrip.hovered == nil and is(REST), "back at rest")
    i.TL.ZoomBy(20)
    assertTrue(u.help:IsEnabled(), "live zoomed all the way in")
end)

test("timeline controls: the controls end on the lanes' right edge, the strips' too, through a resize", function()
    local i, u = opened()
    local TL = i.TL
    local cw, laneX, laneW = TL.LaneGeometry(u.width)
    local at = last(u.help)
    assertTrue(at[1] == "TOPRIGHT" and at[2] == u.content and at[3] == "TOPLEFT", "from the content's left")
    assertEqual(at[4], laneX + laneW, "on the lanes' right edge")
    assertTrue(at[4] < cw, "not the counts' or the window's")
    local track = last(u.strips.a.track)
    assertEqual(track[4] + u.strips.a.track.__width, at[4], "this run's strip ends there too")
    -- A drag of the grip moves them with the lanes, before the release.
    u.frame.resizeGrip:__fire("OnMouseDown", "LeftButton")
    i.mocks.__now = i.mocks.__now + FRAME
    u.frame:__fire("OnSizeChanged", 1000, 560)
    cw, laneX, laneW = TL.LaneGeometry(1000)
    assertTrue(laneX + laneW < cw)
    assertEqual(last(u.help)[4], laneX + laneW, "followed the drag")
    u.frame.resizeGrip:__fire("OnMouseUp")
    assertEqual(last(u.help)[4], laneX + laneW, "and the release")
end)

-- ── the strips ──────────────────────────────────────────────────────────────────────────────────

test("timeline controls: twice the room between the strips, the line centered, the labels on their strips", function()
    local i, u = opened()
    local TL = i.TL
    assertEqual(TL.STRIP_GAP, 16, "8 until P16")
    local s = TL.Layout()
    assertEqual(s.stripB - (s.stripA + s.heightA), 16)
    assertEqual(-last(u.divider)[5], s.stripA + s.heightA + 8, "the line in the gap's middle")
    assertEqual(-last(u.strips.a.label)[5], TL.StripMid(s, "a"))
    assertEqual(-last(u.strips.b.label)[5], TL.StripMid(s, "b"))
end)

-- ── the corridors ───────────────────────────────────────────────────────────────────────────────

local function same(c, want, msg)
    for n = 1, 4 do near(c[n], want[n], msg) end
end

test("timeline controls: every corridor wears its run's dark, translucent color", function()
    local i, u = opened()
    local TL = i.TL
    local this, other = TL.CORRIDOR.this, TL.CORRIDOR.other
    -- Dark shades of THIS's gold and OTHER's blue: the same leading channel, well under the run's own.
    assertTrue(this[1] >= this[2] and this[2] > this[3] and this[1] < TL.THIS[1] / 2, "a dark gold")
    assertTrue(other[3] > other[2] and other[2] > other[1] and other[3] < TL.OTHER[3] / 2, "a dark blue")
    assertTrue(this[4] < 1 and this[4] > 0 and other[4] < 1 and other[4] > 0, "translucent")
    same(u.strips.a.track.__colorTex, this, "this run's strip")
    same(u.strips.b.track.__colorTex, other, "the compared run's strip")
    assertTrue(#u.pairs.active > 0)
    for _, pair in ipairs(u.pairs.active) do
        same(pair.laneA.__colorTex, this, "this run's lane")
        same(pair.laneB.__colorTex, other, "the compared run's lane")
    end
end)

test("timeline controls: a /run change to CORRIDOR shows on Repaint; closed, Repaint does nothing", function()
    local i, u = opened()
    local TL = i.mocks.LibStub("AceAddon-3.0"):GetAddon("DpsRace").ResultsTimeline
    assertTrue(TL == i.TL, "the /run path reaches the module")
    TL.CORRIDOR.this = { 0.5, 0.1, 0.1, 0.8 }
    TL.CORRIDOR.other[4] = 0.2
    same(u.strips.a.track.__colorTex, { 0.30, 0.24, 0.02, 0.45 }, "nothing until the repaint")
    TL.Repaint()
    same(u.strips.a.track.__colorTex, { 0.5, 0.1, 0.1, 0.8 }, "this run's strip")
    same(u.pairs.active[1].laneA.__colorTex, { 0.5, 0.1, 0.1, 0.8 }, "this run's lanes")
    assertEqual(u.strips.b.track.__colorTex[4], 0.2, "the compared run's alpha")
    assertEqual(u.pairs.active[1].laneB.__colorTex[4], 0.2)
    TL.Hide()
    TL.CORRIDOR.this = { 0, 1, 0, 1 }
    TL.Repaint()
    same(u.strips.a.track.__colorTex, { 0.5, 0.1, 0.1, 0.8 }, "closed: untouched")
    i.R.__ui().detail.w.timeline:__fire("OnClick")
    same(u.strips.a.track.__colorTex, { 0, 1, 0, 1 }, "the next open paints from it")
    assertFalse(i.mocks.LibStub("AceAddon-3.0"):GetAddon("DpsRace").db.profile.timelineCorridor ~= nil, "nothing stored")
end)
