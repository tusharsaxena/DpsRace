-- tests/test_results_timeline_view.lua — the ability timeline's P14 round (modules/Results_Timeline.lua,
-- with Results.Placement in modules/Results.lua): the scrollbar along the window's bottom while zoomed
-- in (its thumb the view's share, a drag or a track click scrolling both sections, none at 1x; the
-- wheel's P15 rule is test_results_timeline_scroll's); the strips' labels on their middles; nothing
-- between the two strips but a lane pair's gap (P17: the P14 line is gone); and every open exactly over
-- the Results window in either view, a move or a resize never stored.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600

local INFERNAL, SOUL_FIRE, CONFLAG, INCINERATE = 1122, 6353, 17962, 29722
local SPELLS = { [INFERNAL] = 180000, [SOUL_FIRE] = 45000, [CONFLAG] = 13000, [INCINERATE] = 0 }
-- This run bunches three casts at 0:02 (three rows); the best's are apart (one row).
local THIS = { { 1, INFERNAL }, { 2, INCINERATE }, { 2, CONFLAG }, { 2, SOUL_FIRE }, { 30, SOUL_FIRE },
               { 59, INCINERATE } }
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
    -- The expanded view these cases were written against (a new profile opens collapsed, UT-P14).
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
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 60, dps = dps, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = INCINERATE, dmg = dps * 50 } }, note = "",
        casts = { v = 1, list = NS.Casts.Encode(decoded), spells = SPELLS, dropped = 0 },
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    return run
end

local function seeded()
    local i = inst()
    local NS = i.NS
    for _, run in ipairs({ mkRun(NS, "this", 100, THIS), mkRun(NS, "best", 300, BEST, { date = NOW - 2 * HOUR }) }) do
        NS.db.global.runs[run.id] = run
    end
    NS.Bests.Invalidate()
    i.R.ShowRun("this")
    return i
end

local function press(i)
    i.R.__ui().detail.w.timeline:__fire("OnClick")
    return assert(i.TL.__ui(), "the timeline was never built")
end

-- "this" under "best"; the timeline open on "this".
local function opened()
    local i = seeded()
    return i, press(i)
end

local function last(region) return region.__points[#region.__points] end
local function near(a, b, msg) assertTrue(math.abs(a - b) < 1e-9, (msg or "") .. ": " .. a .. " vs " .. b) end

-- ── the scrollbar ───────────────────────────────────────────────────────────────────────────────

test("timeline view: the scrollbar shows only zoomed in, its thumb the view's share of the lanes' width", function()
    local i, u = opened()
    local TL = i.TL
    local _, laneX, laneW = TL.LaneGeometry(u.width)
    assertFalse(u.bar:IsShown(), "none at 1x")
    local viewH1 = u.viewH
    TL.ZoomBy(2)   -- 2x
    assertTrue(u.bar:IsShown())
    assertEqual(u.bar.thumb.__width, laneW / 2, "half the track at 2x")
    assertEqual(u.bar.thumb.__height, TL.SCROLL_H)
    assertEqual(u.bar.__width, laneW, "the lanes' width")
    local at = last(u.bar)
    assertEqual(at[1], "BOTTOMLEFT")
    assertTrue(at[2] == u.frame, "on the window")
    assertEqual(at[4], TL.PAD + laneX, "under the lanes, clear of the name cells")
    assertEqual(at[5], TL.BOTTOM, "along the window's bottom")
    assertEqual(u.bar.__max, (2 - 1) * laneW, "its range: the zoomed axis past the lanes' width")
    -- The pinned axis moves up to make room, and the lanes' view shrinks by as much.
    assertEqual(last(u.axisClip)[5], TL.BOTTOM + TL.SCROLL_H + TL.SCROLL_GAP)
    assertEqual(u.viewH, viewH1 - TL.SCROLL_H - TL.SCROLL_GAP)
    TL.ZoomBy(2)   -- 4x
    assertEqual(TL.Zoom(), 4)
    assertEqual(u.bar.thumb.__width, laneW / 4, "a quarter at 4x: it shrinks as the zoom grows")
    assertEqual(u.bar.__max, 3 * laneW)
    TL.ZoomBy(-1)  -- 3x
    assertEqual(u.bar.thumb.__width, laneW / 3, "and grows back")
    TL.ResetZoom()
    assertFalse(u.bar:IsShown(), "gone at 1x")
    assertEqual(last(u.axisClip)[5], TL.BOTTOM, "the axis back down")
    assertEqual(u.viewH, viewH1)
    -- Pure: the range and the band.
    assertEqual(TL.PosRange(1), 0)
    assertEqual(TL.PosRange(4), 0.75)
    assertEqual(TL.BarBand(1), 0)
    assertEqual(TL.BarBand(1.5), TL.SCROLL_H + TL.SCROLL_GAP)
end)

test("timeline view: a drag of the thumb or a click on the track scrolls Casts and By ability together", function()
    local i, u = opened()
    local TL = i.TL
    local _, _, laneW = TL.LaneGeometry(u.width)
    TL.ZoomBy(4)   -- 4x
    assertEqual(TL.Zoom(), 4)
    local seen = {}
    for _, key in ipairs({ "castsClip", "lanesClip", "axisClip" }) do
        rawset(u[key], "SetHorizontalScroll", function(_, v) seen[key] = v end)
    end
    -- The client moves the slider (the thumb dragged, or the track clicked) and says so.
    u.bar:__fire("OnValueChanged", laneW, true)
    assertEqual(u.hoff, laneW)
    assertEqual(seen.castsClip, laneW, "the strips")
    assertEqual(seen.lanesClip, laneW, "the lanes")
    assertEqual(seen.axisClip, laneW, "the pinned axis")
    near(u.pos, 0.25, "a quarter of the zoomed axis")
    assertEqual(u.thumbX, TL.PAD + select(2, TL.LaneGeometry(u.width)) + 0.25 * laneW, "the thumb where it was put")
    u.bar:__fire("OnValueChanged", 99999, true)
    assertEqual(u.hoff, 3 * laneW, "clamped to the axis's end")
    u.bar:__fire("OnValueChanged", -5, true)
    assertEqual(u.hoff, 0)
    -- Our own moves set the slider without it scrolling back.
    local fired = 0
    rawset(u.bar, "SetValue", function(self, v)
        self.__value = v
        fired = fired + 1
        self:__fire("OnValueChanged", v, false)
    end)
    TL.Pan(-1)
    assertEqual(fired, 1)
    assertEqual(u.bar.__value, u.hoff, "the slider follows a pan")
    assertEqual(u.hoff, TL.PAN * laneW, "a notch: a quarter of the view")
end)

-- ── the strips ──────────────────────────────────────────────────────────────────────────────────

test("timeline view: This run and Best run sit on their strips' middles, however many rows each grew to", function()
    local i, u = opened()
    local TL = i.TL
    local s = TL.Layout()
    assertEqual(s.heightA, 3 * TL.CAST_STEP, "three casts bunched at 0:02: three rows")
    assertEqual(s.heightB, TL.CAST_STEP, "the best's one row")
    assertEqual(u.strips.a.label.__text, "This run")
    assertEqual(u.strips.b.label.__text, "Best run")
    local a, b = last(u.strips.a.label), last(u.strips.b.label)
    assertEqual(a[1], "LEFT")
    assertEqual(a[5], -(s.stripA + 1.5 * TL.CAST_STEP), "the middle of this run's three rows")
    assertEqual(b[5], -(s.stripB + 0.5 * TL.CAST_STEP), "the middle of the best's one")
    assertEqual(TL.StripMid(s, "a"), s.stripA + s.heightA / 2)
    assertEqual(TL.StripMid(s, "b"), s.stripB + s.heightB / 2)
end)

test("timeline view: nothing between the strips but a lane pair's gap, through a resize (UT-P17)", function()
    local i, u = opened()
    local TL = i.TL
    local s = TL.Layout()
    assertTrue(u.divider == nil and TL.DIVIDER == nil and TL.DividerY == nil, "no line between the strips")
    assertEqual(s.stripB - (s.stripA + s.heightA), TL.LANE_GAP, "the gap between a pair's lanes")
    -- No texture of the content's sits in the gap: only the two strips' tracks reach it.
    local function inGap(o)
        local at = o.__points and o.__points[#o.__points]
        return at and at[2] == u.content and type(at[5]) == "number"
            and -at[5] > s.stripA + s.heightA and -at[5] < s.stripB
    end
    for _, o in ipairs(i.mocks.__widgets.objects) do
        assertFalse(o.__parentFrame == u.content and o.__colorTex == nil and o.__vertex ~= nil and inGap(o), "a line in the gap")
    end
    -- Wider: the tracks follow, the gap stays.
    u.frame:__fire("OnSizeChanged", 1200, 560)
    local _, _, wider = TL.LaneGeometry(1200)
    assertEqual(u.strips.a.track.__width, wider)
    assertEqual(u.strips.b.track.__width, wider)
    s = TL.Layout()
    assertEqual(s.stripB - (s.stripA + s.heightA), TL.LANE_GAP)
end)

-- ── the placement ───────────────────────────────────────────────────────────────────────────────

-- The Results window at `point` (its frame's anchor) in the view shown.
local function anchorResults(i, ...)
    local args = { ... }
    rawset(i.R.__ui().frame, "GetPoint", function() return unpack(args, 1, 5) end)
end

test("timeline view: it opens exactly over the Results window, expanded or collapsed, never stored", function()
    local i = seeded()
    local R, TL = i.R, i.TL
    anchorResults(i, "TOPLEFT", nil, "BOTTOMLEFT", 120, 820)
    local _, _, _, _, rw, rh = R.Placement()
    assertEqual(rw, R.VIEWS.expanded.width)
    local u = press(i)
    local at = last(u.frame)
    assertEqual(at[1], "TOPLEFT")
    assertEqual(at[3], "BOTTOMLEFT")
    assertEqual(at[4], 120)
    assertEqual(at[5], 820)
    assertEqual(u.frame.__width, rw, "the expanded view's width")
    assertEqual(u.frame.__height, rh)
    assertEqual(u.width, rw, "and lays out at it")
    -- Moved and sized while open: nothing stored; the next open goes back over the Results window.
    rawset(u.frame, "GetPoint", function() return "CENTER", nil, "CENTER", 300, -50 end)
    u.drag:__fire("OnDragStart")
    u.drag:__fire("OnDragStop")
    u.frame:__fire("OnSizeChanged", 700, 300)
    assertNil(i.NS.db.profile.windows.timeline, "nothing stored")
    TL.Hide()
    -- The collapsed view, somewhere else and taller.
    assertTrue(R.SetView("collapsed"))
    R.ShowRun("this")
    anchorResults(i, "CENTER", nil, "CENTER", -40, 25)
    R.__ui().frame:__fire("OnSizeChanged", 1000, 640)
    press(i)
    at = last(u.frame)
    assertEqual(at[1], "CENTER")
    assertEqual(at[4], -40)
    assertEqual(at[5], 25)
    assertEqual(u.frame.__width, 1000, "the collapsed view's width as it is now")
    assertEqual(u.frame.__height, 640)
    assertEqual(u.width, 1000)
    assertNil(i.NS.db.profile.windows.timeline)
end)

test("timeline view: over a Results window smaller than its minimums, it keeps its minimums", function()
    local i = seeded()
    local TL = i.TL
    rawset(i.R, "Placement", function() return "CENTER", "CENTER", 0, 0, 300, 100 end)
    local u = press(i)
    assertEqual(u.frame.__width, TL.MIN_WIDTH)
    assertEqual(u.frame.__height, TL.MIN_HEIGHT)
end)
