-- tests/test_results_timeline_scroll.lua — the ability timeline's P15 round (modules/Results_Timeline.lua):
-- the mouse wheel anywhere in the window scrolling up and down at any zoom and Shift+wheel left and
-- right while zoomed in (nothing at 1x); the scroll-left and scroll-right arrows after the reset
-- control, each panning a quarter of the view and disabled and dimmed at 1x and at its end of the axis;
-- the five heading-line controls one size; and the tooltips saying so.

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
    assertEqual(u.zoomIn.tip, "Zoom in (then Shift+mouse wheel scrolls left and right; the mouse wheel scrolls up and down)")
    assertEqual(u.zoomOut.tip, "Zoom out (the mouse wheel scrolls up and down)")
    assertEqual(u.zoomReset.tip, "Reset zoom")
    assertEqual(u.scrollLeft.tip, "Scroll left, toward 0:00 (or Shift+mouse wheel up)")
    assertEqual(u.scrollRight.tip, "Scroll right, toward the end (or Shift+mouse wheel down)")
end)

-- ── the arrows ──────────────────────────────────────────────────────────────────────────────────

test("timeline scroll: the arrows end the Casts heading line, after reset, chevrons from the catalog", function()
    local i, u = opened()
    local TL = i.TL
    local at = last(u.scrollRight)
    assertEqual(at[1], "TOPRIGHT")
    assertTrue(at[2] == u.content and at[3] == "TOPRIGHT", "the content's right end, on the heading line")
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

-- ── the control sizes ───────────────────────────────────────────────────────────────────────────

test("timeline scroll: the five heading-line controls are one size, icons and glyphs alike", function()
    local i, u = opened()
    local TL = i.TL
    for _, key in ipairs({ "zoomIn", "zoomOut", "zoomReset", "scrollLeft", "scrollRight" }) do
        local b = u[key]
        assertEqual(b.__width, TL.CONTROL, key .. ": the box's width")
        assertEqual(b.__height, TL.CONTROL, key .. ": the box's height")
        assertEqual(b.icon.__width, TL.CONTROL_ICON, key .. ": the icon's size")
        assertEqual(b.icon.__height, TL.CONTROL_ICON)
        assertEqual(b.glyph.__fontObject, TL.CONTROL_FONT, key .. ": the glyph's font")
    end
    assertTrue(TL.CONTROL_ICON < 12 and TL.CONTROL_ICON > 10, "between the old 10 px glyphs and the 12 px reset icon")
end)
