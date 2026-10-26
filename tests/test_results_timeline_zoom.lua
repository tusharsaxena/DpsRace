-- tests/test_results_timeline_zoom.lua — the ability timeline's P12 round (modules/Results_Timeline.lua):
-- the taller *Casts* section and its own time axis under the compared run's strip; the zoom controls
-- at the right of the *Casts* heading line (in, out, reset) scaling the strips and the lanes together,
-- the zoomed ticks, the pan (Shift+wheel while zoomed, UT-P15) clamped to the axis and shared by every
-- clip, the scrollbar (P14); the zoom kept across a redraw of the same runs and back to 1x on another run or compare target;
-- a drag of the grip while zoomed in keeping the view and re-pooling nothing.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600
local FRAME = 1 / 60

local INFERNAL, SOUL_FIRE, CONFLAG, INCINERATE = 1122, 6353, 17962, 29722
local SPELLS = { [INFERNAL] = 180000, [SOUL_FIRE] = 45000, [CONFLAG] = 13000, [INCINERATE] = 0 }
local THIS = { { 1, INFERNAL }, { 2, INCINERATE }, { 4, CONFLAG }, { 5, INCINERATE }, { 30, SOUL_FIRE },
               { 59, INCINERATE } }
local BEST = { { 0.5, SOUL_FIRE }, { 3, CONFLAG }, { 8, INCINERATE }, { 20, CONFLAG } }

local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
    end }
    i.R, i.TL = i.NS.Results, i.NS.ResultsTimeline
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

-- "this" under "best" on one board, and a slower run to pick; the timeline open on "this".
local function opened()
    local i = inst()
    local NS = i.NS
    for _, run in ipairs({ mkRun(NS, "this", 100, THIS), mkRun(NS, "best", 300, BEST, { date = NOW - 2 * HOUR }),
                           mkRun(NS, "other", 50, { { 1, CONFLAG } }, { date = NOW - 5 * HOUR }) }) do
        NS.db.global.runs[run.id] = run
    end
    NS.Bests.Invalidate()
    i.R.ShowRun("this")
    i.R.__ui().detail.w.timeline:__fire("OnClick")
    return i, assert(i.TL.__ui(), "the timeline was never built")
end

local function texts(list)
    local out = {}
    for n, fs in ipairs(list) do out[n] = fs.__text end
    return table.concat(out, ",")
end

local function last(region) return region.__points[#region.__points] end

-- ── the Casts section ───────────────────────────────────────────────────────────────────────────

test("timeline zoom: the Casts section is roomier: a wider row pitch than the icon, gaps around the strips", function()
    local i, u = opened()
    local TL, Style = i.TL, i.NS.Style
    assertTrue(TL.CAST_STEP >= TL.CAST_ICON + 4, "a few px between stacked rows")
    assertTrue(TL.CAST_PITCH > TL.CAST_ICON and TL.CAST_PITCH < TL.CAST_STEP, "icons stack only when they would touch")
    assertTrue(TL.STRIP_GAP >= 8, "the strips sit apart")
    local s = TL.Layout()
    assertEqual(s.stripA, Style.SECTION_H + TL.CASTS_PAD)
    assertEqual(u.contentH, s.lanes + #u.rows * TL.PAIR_H - TL.PAIR_GAP)
end)

test("timeline zoom: a second time axis under the compared run's strip, the same labels as the pinned one", function()
    local i, u = opened()
    local TL = i.TL
    assertEqual(texts(u.axis), "0:00,0:15,0:30,0:45,1:00", "the pinned axis")
    assertEqual(texts(u.castsAxis), texts(u.axis), "the Casts axis")
    local s = TL.Layout()
    local _, _, laneW = TL.LaneGeometry(u.width)
    local first, mid, endAt = last(u.castsAxis[1]), last(u.castsAxis[3]), last(u.castsAxis[5])
    assertEqual(first[1], "TOPLEFT", "0:00 left-aligned on the axis's start")
    assertEqual(mid[1], "TOP")
    assertEqual(endAt[1], "TOPRIGHT", "the end right-aligned on the axis's end")
    assertTrue(first[2] == u.castsLayer, "on the strips' layer, which pans with them")
    assertEqual(mid[4], TL.CLIP_PAD + TL.MarkX(30, 60, laneW))
    assertEqual(mid[5], -(s.castsAxis - s.stripA), "under the compared run's strip")
    assertTrue(s.castsAxis >= s.stripB + s.heightB, "below the strip")
    assertTrue(s.lanesHead >= s.castsAxis + TL.CASTS_AXIS_H, "above the By ability heading")
    -- Both axes' labels are caption text.
    assertEqual(u.castsAxis[2].__fontObject, i.NS.Style.FONT.CAPTION)
end)

-- ── the zoom ────────────────────────────────────────────────────────────────────────────────────

test("timeline zoom: the controls sit at the right end of the Casts heading line and step through the zooms", function()
    local i, u = opened()
    local TL = i.TL
    assertEqual(TL.Zoom(), 1)
    -- The scroll arrows end the line (UT-P15); reset, out and in before them, in a row.
    local at = last(u.scrollRight)
    assertEqual(at[1], "TOPRIGHT")
    assertTrue(at[2] == u.content and at[3] == "TOPRIGHT", "the content's right end, on the heading line")
    assertTrue(last(u.zoomReset)[2] == u.scrollLeft, "reset before the arrows")
    assertTrue(last(u.zoomOut)[2] == u.zoomReset and last(u.zoomIn)[2] == u.zoomOut, "in, out, reset in a row")
    assertEqual(u.zoomIn.glyph.__text, "+")
    assertEqual(u.zoomOut.glyph.__text, "-")
    assertEqual(u.zoomReset.iconName, "reset")
    assertEqual(u.zoomText.__text, "1x")
    u.zoomIn:__fire("OnClick")
    assertEqual(TL.Zoom(), 1.5)
    assertEqual(u.zoomText.__text, "1.5x")
    for _ = 1, 20 do u.zoomIn:__fire("OnClick") end
    assertEqual(TL.Zoom(), TL.ZOOMS[#TL.ZOOMS], "stops at the last step")
    assertEqual(TL.Zoom(), 8)
    assertFalse(TL.ZoomBy(1), "nothing past it")
    u.zoomOut:__fire("OnClick")
    assertEqual(TL.Zoom(), 6)
    u.zoomReset:__fire("OnClick")
    assertEqual(TL.Zoom(), 1)
    assertEqual(u.hoff, 0, "back to 0:00")
    assertFalse(TL.ZoomBy(-1), "nothing under 1x")
    assertFalse(TL.ResetZoom())
end)

test("timeline zoom: zoomed in, the strips and the lanes widen together and the view pans across the axis", function()
    local i, u = opened()
    local TL = i.TL
    local _, laneX, laneW = TL.LaneGeometry(u.width)
    TL.ZoomBy(2)   -- 2x
    assertEqual(TL.Zoom(), 2)
    local zoomW = 2 * laneW
    -- Every tick and every icon on the zoomed axis; a cast's icon and its tick share an x.
    for _, d in ipairs(TL.Marks()) do assertEqual(d.x, laneX + TL.MarkX(d.cast.t, 60, zoomW)) end
    local byT = {}
    for _, d in ipairs(TL.Marks()) do if d.lane == "a" then byT[d.cast.t] = d.x end end
    for _, d in ipairs(TL.Icons()) do
        assertEqual(d.x, laneX + TL.MarkX(d.cast.t, 60, zoomW))
        if d.side == "a" then assertEqual(d.x, byT[d.cast.t], "the icon over its tick") end
    end
    -- The layers are the zoomed axis's width, the clips the lanes'.
    assertEqual(u.marks.__width, zoomW)
    assertEqual(u.lanesClip.__width, laneW)
    assertEqual(u.castsLayer.__width, zoomW + 2 * TL.CLIP_PAD)
    assertEqual(u.castsClip.__width, laneW + 2 * TL.CLIP_PAD)
    assertEqual(u.axisLayer.__width, zoomW)
    -- The axis labels a round step apart (10 s at 2x on a 1:00 race), on both axes.
    assertEqual(texts(u.axis), "0:00,0:10,0:20,0:30,0:40,0:50,1:00")
    assertEqual(texts(u.castsAxis), texts(u.axis))
    -- Every clip pans by the same offset; the range is the zoomed width past the lanes'.
    local seen = {}
    for _, key in ipairs({ "castsClip", "lanesClip", "axisClip" }) do
        rawset(u[key], "SetHorizontalScroll", function(_, v) seen[key] = v end)
    end
    TL.Pan(1000)
    assertEqual(u.hoff, 0, "panned back to 0:00 (the zoom kept the view's middle)")
    TL.Pan(-1)
    assertEqual(u.hoff, TL.PAN / 2 * zoomW, "a notch: a quarter of the view")
    assertEqual(seen.castsClip, u.hoff)
    assertEqual(seen.lanesClip, u.hoff)
    assertEqual(seen.axisClip, u.hoff)
    TL.Pan(-1000)
    assertEqual(u.hoff, zoomW - laneW, "clamped to the axis's end")
    TL.Pan(1000)
    assertEqual(u.hoff, 0)
    -- The scrollbar: shown zoomed in, its thumb half the track at 2x.
    assertTrue(u.bar:IsShown())
    assertEqual(u.thumbW, laneW / 2)
    TL.ResetZoom()
    assertFalse(u.bar:IsShown(), "no scrollbar at 1x")
end)

test("timeline zoom: a zoom keeps the view's middle; zoomed in, Shift+wheel pans and the wheel scrolls", function()
    local i, u = opened()
    local TL = i.TL
    assertEqual(TL.Rezoom(0, 1, 2), 0.25, "1x to 2x about the middle")
    assertEqual(TL.Rezoom(0.25, 2, 1), 0)
    assertEqual(TL.Rezoom(0.5, 2, 4), 0.625)
    assertEqual(TL.ClampPos(0.9, 2), 0.5, "the view stays on the axis")
    assertEqual(TL.ClampPos(-1, 2), 0)
    local function near(a, b, msg) assertTrue(math.abs(a - b) < 1e-9, (msg or "") .. ": " .. a .. " vs " .. b) end
    u.zoomIn:__fire("OnClick")
    u.zoomIn:__fire("OnClick")   -- 2x, through 1.5x, from the middle of 1x
    near(u.pos, 0.25, "the middle kept")
    i.mocks.__modifiers.shift = true
    u.scroll:GetScript("OnMouseWheel")(u.scroll, 1)
    near(u.pos, 0.25 - TL.PAN / 2, "Shift+wheel up pans toward 0:00")
    assertEqual(u.offset, 0, "and does not scroll")
    i.mocks.__modifiers.shift = false
    u.scroll:GetScript("OnMouseWheel")(u.scroll, 1)
    near(u.pos, 0.25 - TL.PAN / 2, "the plain wheel leaves the pan (UT-P15)")
    -- The zoomed axis's steps: a round step leaving about a quarter of the lanes between labels.
    assertEqual(table.concat(TL.Ticks(60, 8), ","), "0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58,60")
    assertEqual(table.concat(TL.Ticks(180, 3), ","), "0,15,30,45,60,75,90,105,120,135,150,165,180")
    -- 1:05 at 1.5x: 15 s steps; 1:00 is within half a step of the end and gives way to it.
    assertEqual(table.concat(TL.Ticks(65, 1.5), ","), "0,15,30,45,65", "a step close to the end gives way")
    assertEqual(table.concat(TL.Ticks(60, 1), ","), "0,15,30,45,60", "1x keeps the quarters")
end)

test("timeline zoom: a redraw of the same runs keeps the zoom; another run or compare target goes back to 1x", function()
    local i, u = opened()
    local TL = i.TL
    TL.ZoomBy(3)
    TL.Pan(-1)
    local pos = u.pos
    i.R.ShowRun("this")   -- the same run redrawn
    assertEqual(TL.Zoom(), 3)
    assertEqual(u.pos, pos)
    i.R.__ui().detail:SetComparing(true)   -- the toggle keeps the target
    assertEqual(TL.Zoom(), 3)
    assertTrue(i.R.CompareWith("other"), "a pick: another compare target")
    assertEqual(TL.Zoom(), 1)
    assertEqual(u.pos, 0)
    TL.ZoomBy(2)
    i.R.ShowRun("best")   -- another run
    assertEqual(TL.Zoom(), 1)
    assertEqual(u.hoff, 0)
end)

test("timeline zoom: zoomed in, a drag of the grip keeps the view's left edge and re-pools nothing until the release", function()
    local i, u = opened()
    local NS, TL = i.NS, i.TL
    TL.ZoomBy(4)   -- 4x
    TL.Pan(-1)
    local pos = u.pos
    local churn = 0
    local release = NS.Pool.ReleaseAll
    rawset(NS.Pool, "ReleaseAll", function(pool, ...)
        churn = churn + 1
        return release(pool, ...)
    end)
    u.frame.resizeGrip:__fire("OnMouseDown", "LeftButton")
    for k = 1, 10 do
        i.mocks.__now = i.mocks.__now + FRAME
        u.frame:__fire("OnSizeChanged", 1000 + 10 * k, 560)
    end
    rawset(NS.Pool, "ReleaseAll", release)
    assertEqual(churn, 0, "nothing re-pooled while the grip is held")
    assertEqual(u.width, 1100)
    local _, laneX, laneW = TL.LaneGeometry(1100)
    assertEqual(u.pos, pos, "the same moment at the left")
    assertEqual(u.hoff, pos * 4 * laneW)
    local mark = TL.Marks()[1]
    assertEqual(mark.x, laneX + TL.MarkX(mark.cast.t, 60, 4 * laneW), "each tick along the zoomed axis")
    local icon = TL.Icons()[1]
    assertEqual(icon.x, laneX + TL.MarkX(icon.cast.t, 60, 4 * laneW))
    assertEqual(u.marks.__width, 4 * laneW, "the layers stretched with the lanes")
    assertEqual(last(u.axis[2])[4], TL.MarkX(u.ticks[2], 60, 4 * laneW), "the axis labels followed")
    u.frame.resizeGrip:__fire("OnMouseUp")
end)
