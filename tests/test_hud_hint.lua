-- tests/test_hud_hint.lua — the waiting body's sticky-combat hint box (modules/Hud_States.lua): sized
-- to its text from config (the estimated lines at the body's width, 6 px above and below), at the
-- minimum width and wider, with and without a drop-combat ability named, and the footer under it.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local PLAIN = "Combat is holding. Walk out of range. Your score is safe: it waits for combat to end, however long that takes."
local NAMED = "Combat is holding. Walk out of range, or use %s. Your score is safe: it waits for combat to end, however long that takes."

--- The HUD on the race fixture with the widget recorder, `known` spells owned, on its waiting body
--- with the hint shown (combat held past the hint delay).
local function waiting(known)
    local W
    local f = RaceClock.new{ mutate = function(m) W = Widgets.install(m) end }
    for _, id in ipairs(known or {}) do W.known[id] = true end
    f.NS.Hud.Show()
    assertTrue(f:arm(30))
    f:start(25)
    f:to(130)
    f:advance(16)
    f.NS.Hud.Tick()
    local u = f.NS.Hud.__ui()
    assertEqual(u.current, "waiting")
    local b = u.body.waiting
    assertTrue(b.w.hint:IsShown(), "the hint after the delay")
    return f, b
end

--- The point on `region` anchored at `point`.
local function pointAt(region, point)
    for _, p in ipairs(region.__points or {}) do
        if p[1] == point then return p end
    end
end

test("hud hint: the line estimate wraps whole words at the width", function()
    local S = T.NS.HudStates
    assertEqual(S.HintLines("", 220), 1, "an empty hint is one line")
    assertEqual(S.HintLines("aaaa bbbbbb", 60), 1, "eleven characters fit eleven")
    assertEqual(S.HintLines("aaaa bbbbbbb", 60), 2, "twelve wrap the second word")
    assertEqual(S.HintLines(PLAIN, 220), 3)
    assertEqual(S.HintLines(PLAIN, 360), 2)
end)

test("hud hint: at the minimum width the plain hint is three lines and 6 px above and below", function()
    local f, b = waiting()
    local S = f.NS.HudStates
    b:Layout(236, 400)
    assertEqual(b.w.hintText.__text, PLAIN)
    assertEqual(b.w.hint.__height, 3 * S.HINT_LINE_H + 2 * S.HINT_PADY)
    assertEqual(b.w.hint.__height, 48, "the old box was 64 px")
end)

test("hud hint: a named drop-combat ability takes the line it needs, and a wider body fewer", function()
    local cases = {
        { known = { 5384 }, names = "Feign Death", narrow = 4, wide = 3 },
        { known = { 5384, 58984 }, names = "Feign Death or Shadowmeld", narrow = 4, wide = 3 },
        { known = { 66, 58984 }, names = "Shadowmeld or Invisibility", narrow = 4, wide = 3 },
        { known = {}, names = nil, narrow = 3, wide = 2 },
    }
    for _, c in ipairs(cases) do
        local f, b = waiting(c.known)
        local S = f.NS.HudStates
        local want = c.names and NAMED:format(c.names) or PLAIN
        assertEqual(b.w.hintText.__text, want)
        b:Layout(236, 400)
        assertEqual(b.w.hint.__height, c.narrow * S.HINT_LINE_H + 2 * S.HINT_PADY, want)
        b:Layout(376, 400)
        assertEqual(b.w.hint.__height, c.wide * S.HINT_LINE_H + 2 * S.HINT_PADY, want .. " (wide)")
    end
end)

test("hud hint: the text is inset from the box's top, never pinned to a fixed bottom", function()
    local _, b = waiting()
    local tl, tr = pointAt(b.w.hintText, "TOPLEFT"), pointAt(b.w.hintText, "TOPRIGHT")
    assertEqual(tl[4], 8)
    assertEqual(tl[5], -6)
    assertEqual(tr[4], -8)
    assertEqual(tr[5], -6)
    assertEqual(pointAt(b.w.hintText, "BOTTOMRIGHT"), nil, "a bottom anchor would clip the text")
end)

test("hud hint: under the box only the foot row, on the body's bottom, clear of the box at the minimum height", function()
    local f, b = waiting({ 5384, 58984 })
    local S = f.NS.HudStates
    b:Layout(236, 400)
    local top = pointAt(b.w.hint, "TOPLEFT")
    assertEqual(top[5], -(40 + 46 + 8), "the box under the KPIs")
    for _, btn in ipairs({ b.w.stopNow, b.w.cancel }) do
        local p = pointAt(btn, "BOTTOMLEFT")
        assertEqual(p[2], b.frame)
        assertEqual(p[5], 0, "the buttons sit on the body's foot")
    end
    local bottom = -top[5] + b.w.hint.__height
    assertTrue(bottom + 8 <= S.MinContentHeight() - 20, "the hint box reaches the foot row at the minimum height")
end)

test("hud hint: the box resizes when the hint's text changes, and not on every redraw", function()
    local f, b = waiting()
    b:Layout(236, 400)
    assertEqual(b.w.hint.__height, 48)
    local calls = 0
    local size = b.SizeHint
    b.SizeHint = function(self) calls = calls + 1 return size(self) end
    f.NS.Hud.Tick()
    f:advance(1)
    f.NS.Hud.Tick()
    assertEqual(calls, 0, "the same hint resized the box again")
    b:Update({ inCombat = true, hint = NAMED:format("Feign Death"), tail = 1, sinceBuzzer = 20 })
    assertEqual(calls, 1)
    assertEqual(b.w.hint.__height, 60)
end)
