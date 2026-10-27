-- tests/test_results_timeline_scroll.lua — the ability timeline's P15 round (modules/Results_Timeline.lua):
-- the mouse wheel anywhere in the window scrolling up and down at any zoom and Shift+wheel left and
-- right while zoomed in (nothing at 1x); the scroll-left and scroll-right arrows after the reset
-- control, each panning a quarter of the view and disabled and dimmed at 1x and at its end of the axis;
-- the six heading-line controls and the zoom level one size (P17: `-` and `+` strokes, the `?` and the
-- level in their own font sizes); and the tooltips saying so.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600

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

-- The timeline open on `id` ("this" by default; "many" has 30 abilities, enough to scroll up and down).
local function opened(id)
    local i = inst()
    local NS = i.NS
    local list = {}
    for n = 1, 30 do list[n] = { n, 100000 + n } end
    for _, run in ipairs({ mkRun(NS, "this", 100, THIS), mkRun(NS, "best", 300, BEST, { date = NOW - 2 * HOUR }),
                           mkRun(NS, "many", 50, list, { date = NOW - 3 * HOUR }) }) do
        NS.db.global.runs[run.id] = run
    end
    NS.Bests.Invalidate()
    i.R.ShowRun(id or "this")
    i.R.__ui().detail.w.timeline:__fire("OnClick")
    return i, assert(i.TL.__ui(), "the timeline was never built")
end

local function last(region) return region.__points[#region.__points] end
local function wheel(frame, delta) frame:GetScript("OnMouseWheel")(frame, delta) end
local function near(a, b, msg) assertTrue(math.abs(a - b) < 1e-9, (msg or "") .. ": " .. a .. " vs " .. b) end

-- Record each arrow's alpha (the kit's frames forget it), then redraw so they are set.
local function spyAlpha(i, u)
    for _, b in ipairs({ u.scrollLeft, u.scrollRight }) do
        rawset(b, "SetAlpha", function(self, a) self.__alpha = a end)
    end
    i.TL.ResetZoom()
    i.TL.ZoomBy(1)
    i.TL.ResetZoom()
end

-- ── the mouse wheel ─────────────────────────────────────────────────────────────────────────────

test("timeline scroll: the wheel scrolls up and down at any zoom; Shift+wheel left and right only zoomed in", function()
    local i, u = opened("many")
    local TL = i.TL
    -- 1x: the wheel up and down, anywhere in the window.
    assertTrue(u.frame.__wheel, "the window takes the wheel")
    wheel(u.frame, -1)
    assertEqual(u.offset, TL.PAIR_H, "the wheel down scrolls down a pair")
    wheel(u.scroll, 1)
    assertEqual(u.offset, 0)
    -- 1x: Shift+wheel does nothing (nothing to pan, and Shift never scrolls up and down).
    i.mocks.__modifiers.shift = true
    wheel(u.frame, -1)
    assertEqual(u.offset, 0, "Shift+wheel at 1x: no vertical scroll")
    assertEqual(u.pos, 0, "and no pan")
    i.mocks.__modifiers.shift = false
    -- Zoomed in: the plain wheel still scrolls up and down and leaves the view.
    TL.ZoomBy(4)
    TL.Pan(1000)
    wheel(u.frame, -1)
    assertEqual(u.offset, TL.PAIR_H, "zoomed in, the wheel down still scrolls down")
    assertEqual(u.pos, 0, "and leaves the view")
    wheel(u.bar, 1)
    assertEqual(u.offset, 0, "over the scrollbar too")
    -- Zoomed in, Shift+wheel: down later (right), up earlier (left), the vertical scroll kept.
    i.mocks.__modifiers.shift = true
    wheel(u.frame, -1)
    near(u.pos, TL.PAN / 4, "Shift+wheel down: later")
    wheel(u.scroll, -1)
    near(u.pos, 2 * TL.PAN / 4, "over the lanes too")
    wheel(u.bar, 1)
    near(u.pos, TL.PAN / 4, "Shift+wheel up over the scrollbar: earlier")
    assertEqual(u.offset, 0, "no vertical scroll")
    i.mocks.__modifiers.shift = false
end)

test("timeline scroll: the zoom and arrow tooltips say how the wheel and the arrows scroll", function()
    local _, u = opened()
    assertEqual(u.zoomIn.tip, "Zoom in (or Ctrl+mouse wheel up)")
    assertEqual(u.zoomOut.tip, "Zoom out (or Ctrl+mouse wheel down)")
    assertEqual(u.zoomReset.tip, "Reset zoom")
    assertEqual(u.scrollLeft.tip, "Scroll left, toward 0:00 (or Shift+mouse wheel up)")
    assertEqual(u.scrollRight.tip, "Scroll right, toward the end (or Shift+mouse wheel down)")
end)

-- ── the arrows ──────────────────────────────────────────────────────────────────────────────────

test("timeline scroll: the arrows follow reset and come before the ?, chevrons from the catalog", function()
    local i, u = opened()
    local TL = i.TL
    local at = last(u.scrollRight)
    assertTrue(at[1] == "RIGHT" and at[2] == u.help and at[3] == "LEFT", "right before the ? (UT-P16)")
    assertEqual(at[4], -TL.SCROLL_SEP, "a group's gap apart")
    assertTrue(last(u.scrollLeft)[2] == u.scrollRight, "left before right")
    assertEqual(last(u.scrollLeft)[4], -2)
    at = last(u.zoomReset)
    assertTrue(at[2] == u.scrollLeft, "reset before the arrows")
    assertEqual(at[4], -TL.SCROLL_SEP, "a wider gap between the zoom group and the arrows")
    assertEqual(u.scrollLeft.iconName, "chevron-left")
    assertEqual(u.scrollRight.iconName, "chevron-right")
    assertEqual(u.scrollLeft.icon.__texture, i.NS.Icon("chevron-left"), "drawn from the catalog")
    assertEqual(u.scrollRight.icon.__texture, i.NS.Icon("chevron-right"))
end)

test("timeline scroll: each arrow pans a quarter of the view, clamped to the axis", function()
    local i, u = opened()
    local TL = i.TL
    local _, _, laneW = TL.LaneGeometry(u.width)
    TL.ZoomBy(4)   -- 4x
    TL.Pan(1000)
    assertEqual(u.pos, 0)
    u.scrollRight:__fire("OnClick")
    near(u.pos, TL.PAN / 4, "a quarter of the view later")
    near(u.hoff, TL.PAN * laneW, "a quarter of the lanes' width along the zoomed axis")
    u.scrollRight:__fire("OnClick")
    near(u.pos, 2 * TL.PAN / 4)
    u.scrollLeft:__fire("OnClick")
    near(u.pos, TL.PAN / 4, "and a quarter back")
    for _ = 1, 20 do u.scrollRight:__fire("OnClick") end
    near(u.pos, TL.PosRange(4), "stops at the end")
    for _ = 1, 20 do u.scrollLeft:__fire("OnClick") end
    assertEqual(u.pos, 0, "stops at 0:00")
    TL.ResetZoom()
    u.scrollRight:__fire("OnClick")
    assertEqual(u.pos, 0, "nothing at 1x")
end)

test("timeline scroll: the arrows are disabled and dimmed at 1x and each at its end of the axis", function()
    local i, u = opened()
    local TL = i.TL
    spyAlpha(i, u)
    local L, R = u.scrollLeft, u.scrollRight
    assertFalse(L:IsEnabled(), "left off at 1x")
    assertFalse(R:IsEnabled(), "right off at 1x")
    assertEqual(L.__alpha, TL.DIM)
    assertEqual(R.__alpha, TL.DIM)
    TL.ZoomBy(2)   -- 2x about the middle: room both ways
    assertTrue(L:IsEnabled() and R:IsEnabled(), "both live mid-axis")
    assertEqual(L.__alpha, 1)
    assertEqual(R.__alpha, 1)
    TL.Pan(1000)   -- 0:00
    assertFalse(L:IsEnabled(), "left off at 0:00")
    assertEqual(L.__alpha, TL.DIM)
    assertTrue(R:IsEnabled())
    TL.Pan(-1000)  -- the end
    assertTrue(L:IsEnabled())
    assertFalse(R:IsEnabled(), "right off at the end")
    assertEqual(R.__alpha, TL.DIM)
    -- The scrollbar's drag follows the same rule.
    u.bar:__fire("OnValueChanged", 0, true)
    assertFalse(L:IsEnabled(), "the thumb dragged to 0:00")
    assertTrue(R:IsEnabled())
    TL.ResetZoom()
    assertFalse(L:IsEnabled() or R:IsEnabled(), "both off back at 1x")
end)

test("timeline scroll: the thumb dragged to the end snaps onto it, so the right arrow goes off", function()
    local i, u = opened()
    local TL = i.TL
    -- At 1.5x a 512 px zoomed axis's end in pixels, divided back, lands one ulp short of the range.
    local r, zw = TL.PosRange(1.5), 512 * 1.5
    assertTrue((r * zw) / zw < r, "the rounding the snap is for")
    assertEqual(TL.ClampPos((r * zw) / zw, 1.5), r, "snapped onto the end")
    assertEqual(TL.ClampPos(1e-12, 1.5), 0, "and onto 0:00")
    TL.ZoomBy(2)
    local _, _, laneW = TL.LaneGeometry(u.width)
    TL.ScrollTo(TL.PosRange(2) * laneW * 2)
    assertEqual(u.pos, TL.PosRange(2))
    assertFalse(u.scrollRight:IsEnabled(), "right off at the dragged-to end")
end)

test("timeline scroll: zoomed in on a run with no casts, the arrows stay off", function()
    local i, u = opened()
    local TL = i.TL
    local old = mkRun(i.NS, "old", 20, {}, { schema = 2, date = NOW - 4 * HOUR })
    old.casts = nil
    i.NS.db.global.runs.old = old
    i.NS.Bests.Invalidate()
    i.R.ShowRun("old")
    TL.ZoomBy(2)   -- the zoom controls still step over an empty view
    assertTrue(u.empty:IsShown(), "nothing drawn")
    assertTrue(TL.ZoomAt(u.zoomI) > 1, "zoomed in")
    assertFalse(u.scrollLeft:IsEnabled() or u.scrollRight:IsEnabled(), "no arrows over an empty view")
    i.R.DeleteRun("old")
    TL.ZoomBy(2)
    assertFalse(u.scrollLeft:IsEnabled() or u.scrollRight:IsEnabled(), "nor with no run at all")
end)

-- ── the control sizes ───────────────────────────────────────────────────────────────────────────

test("timeline scroll: the six heading-line controls and the zoom level read one size", function()
    local i, u = opened()
    local TL = i.TL
    for _, key in ipairs({ "zoomIn", "zoomOut", "zoomReset", "scrollLeft", "scrollRight", "help" }) do
        local b = u[key]
        assertEqual(b.__width, TL.CONTROL, key .. ": the box's width")
        assertEqual(b.__height, TL.CONTROL, key .. ": the box's height")
    end
    -- The icons 11 px, a fallback glyph in CONTROL_FONT.
    for _, key in ipairs({ "zoomReset", "scrollLeft", "scrollRight", "help" }) do
        assertEqual(u[key].icon.__width, TL.CONTROL_ICON, key .. ": the icon's size")
        assertEqual(u[key].icon.__height, TL.CONTROL_ICON)
        assertEqual(u[key].glyph.__fontObject, TL.CONTROL_FONT, key .. ": the glyph's font")
    end
    assertTrue(TL.CONTROL_ICON < 12 and TL.CONTROL_ICON > 10, "between the old 10 px glyphs and the 12 px reset icon")
    -- `-` and `+` (UT-P17): strokes, not glyphs, BAR long (about the icons' size) and BAR thick.
    local len, thick = TL.BAR[1], TL.BAR[2]
    assertTrue(len >= TL.CONTROL_ICON - 2 and len <= TL.CONTROL_ICON, "about the icons' size")
    assertTrue(thick >= 1 and thick <= 2)
    for _, key in ipairs({ "zoomOut", "zoomIn" }) do
        local b = u[key]
        assertTrue(b.icon:IsShown() and not b.glyph:IsShown(), key .. ": drawn, not typed")
        assertEqual(b.icon.__width, len, key .. ": across")
        assertEqual(b.icon.__height, thick)
    end
    assertTrue(u.zoomOut.stroke == nil, "- is one stroke")
    assertEqual(u.zoomIn.stroke.__width, thick, "+ has a second, down through it")
    assertEqual(u.zoomIn.stroke.__height, len)
    -- The `?` a size smaller than the old 16 px glyph, the level larger than its 10 px caption.
    assertEqual(u.help.glyph.__font.size, TL.HELP_SIZE)
    assertEqual(u.zoomText.__font.size, TL.LEVEL_SIZE)
    assertTrue(TL.HELP_SIZE < 16 and TL.HELP_SIZE >= 12, "the ? smaller than it was")
    assertTrue(TL.LEVEL_SIZE > 10 and TL.LEVEL_SIZE <= 16, "the level larger than it was")
    -- The strokes turn gold under the pointer with the rest, and dim with their control.
    local GOLD, REST = i.NS.Style.GOLD, i.NS.Style.REST
    u.zoomIn:__fire("OnEnter")
    assertEqual(u.zoomIn.icon.__vertex[2], GOLD[2], "gold across")
    assertEqual(u.zoomIn.stroke.__vertex[2], GOLD[2], "gold down")
    u.zoomIn:__fire("OnLeave")
    assertEqual(u.zoomIn.stroke.__vertex[2], REST[2], "back at rest")
    -- Dimmed with their control (the button's alpha, which the strokes are drawn on).
    rawset(u.zoomOut, "SetAlpha", function(self, a) self.__alpha = a end)
    TL.ZoomBy(1)
    TL.ResetZoom()
    assertEqual(u.zoomOut.__alpha, TL.DIM, "- dim at 1x")
end)
