-- tests/test_hud_tiles.lua — the Stop! and waiting screens' figure tiles (modules/Hud_States.lua, the
-- owner's call, 2026-10-28): the figure and its unit in one large string ("+9.4s"), a caption row
-- under it inside the tile, both tiles of the pair one taller height, the stack under them moved down
-- by config, and the running body's and the result card's tiles as they were.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local DASH = "\226\128\148"

--- The HUD on the race fixture with the widget recorder, shown, a 30s race running from 100.
local function racing()
    local W
    local f = RaceClock.new{ mutate = function(m) W = Widgets.install(m) end }
    f.W = W
    f.NS.Hud.Show()
    assertTrue(f:arm(30))
    f:start(25)
    return f
end

local function ui(f) return f.NS.Hud.__ui() end

--- The Stop! body 1.4s after the buzzer, damage still landing.
local function stopBody()
    local f = racing()
    f:to(130)
    f:advance(1.4)
    f:update(25)
    f.NS.Hud.Tick()
    assertEqual(ui(f).current, "stop")
    return f, ui(f).body.stop
end

--- The waiting body: combat held past the tail.
local function waitingBody()
    local f = racing()
    f:to(130)
    f:advance(16)
    f.NS.Hud.Tick()
    assertEqual(ui(f).current, "waiting")
    return f, ui(f).body.waiting
end

--- The point on `region` anchored at `point`.
local function pointAt(region, point)
    for _, p in ipairs(region.__points or {}) do
        if p[1] == point then return p end
    end
end

test("hud tiles: the Stop! tail reads +x.xs in one large string, after buzzer on the row under it", function()
    local _, b = stopBody()
    local k = b.w.tail
    assertEqual(k.label.__text, "Damage Stopped")
    assertEqual(k.value.__text, "+1.4s", "the unit in the figure's own string")
    assertEqual(k.value.__fontObject, "GameFontNormalHuge", "the s in the figure's large font")
    assertEqual(k.caption.__text, "after buzzer")
    assertEqual(k.caption.__fontObject, "GameFontDisableSmall", "the caption font")
    assertNil(k.unit, "no small tail beside the figure")
end)

test("hud tiles: the caption row sits inside the tile at the old padding, the figure a row above it", function()
    local f, b = stopBody()
    local S = f.NS.HudStates
    for _, k in ipairs({ b.w.tail, b.w.combat }) do
        local cap, val = pointAt(k.caption, "BOTTOMLEFT"), pointAt(k.value, "BOTTOMLEFT")
        assertEqual(cap[2], k.frame)
        assertEqual(cap[4], 8)
        assertEqual(cap[5], 5, "the 5 px under the figure today")
        local right = pointAt(k.caption, "BOTTOMRIGHT")
        assertEqual(right[2], k.frame, "the caption held inside the tile's right edge")
        assertEqual(right[4], -8)
        assertEqual(val[5], 5 + S.KPI_CAPTION_H)
    end
end)

test("hud tiles: both tiles of the pair are one taller height; the running and result tiles keep 46", function()
    local f, b = stopBody()
    local S = f.NS.HudStates
    assertEqual(S.KPI_HEIGHT, 46)
    assertEqual(S.KPI_CAPTIONED_HEIGHT, 46 + 14)
    assertEqual(b.w.tail.frame.__height, S.KPI_CAPTIONED_HEIGHT)
    assertEqual(b.w.combat.frame.__height, S.KPI_CAPTIONED_HEIGHT)
    local _, wb = waitingBody()
    assertEqual(wb.w.tail.frame.__height, S.KPI_CAPTIONED_HEIGHT)
    assertEqual(wb.w.combat.frame.__height, S.KPI_CAPTIONED_HEIGHT)
    local result = S.Build("result", b.frame)
    assertEqual(result.w.damage.frame.__height, S.KPI_HEIGHT)
    assertNil(result.w.damage.caption, "no caption row on the result card")
    local running = ui(f).body.running
    assertEqual(running.w.damage.frame.__height, S.KPI_HEIGHT, "the running body's tiles at the default figure size")
    assertNil(running.w.dps.caption)
end)

test("hud tiles: under the taller pair the Stop! chips and note and the waiting hint move down by config", function()
    local f, b = stopBody()
    local S = f.NS.HudStates
    assertEqual(pointAt(b.w.tail.frame, "TOPLEFT")[5], -56)
    assertEqual(S.STOP_CHIPS_Y, 56 + 60 + 8)
    assertEqual(S.STOP_NOTE_Y, 56 + 60 + 8 + 28)
    local chip = b.w.chips.shown[1]
    assertEqual(pointAt(chip, "TOPLEFT")[5], -S.STOP_CHIPS_Y, "the first chip under the pair")
    assertEqual(pointAt(b.w.note, "TOPLEFT")[5], -S.STOP_NOTE_Y)
    local _, wb = waitingBody()
    assertEqual(pointAt(wb.w.tail.frame, "TOPLEFT")[5], -40)
    assertEqual(S.WAITING_HINT_Y, 40 + 60 + 8)
    assertEqual(pointAt(wb.w.hint, "TOPLEFT")[5], -S.WAITING_HINT_Y)
end)

test("hud tiles: the right tile's caption says what its figure is in each state", function()
    local _, b = stopBody()
    assertEqual(b.w.combat.label.__text, "In Combat")
    assertEqual(b.w.combat.value.__text, "+1.4s")
    assertEqual(b.w.combat.caption.__text, "since the buzzer")
    b:Update({ inCombat = false, tail = 2.5 })
    assertEqual(b.w.combat.label.__text, "Out of Combat")
    assertEqual(b.w.combat.value.__text, DASH)
    assertEqual(b.w.combat.caption.__text, "combat ended")
    b:Update({ inCombat = false, endedEarly = true, endedAt = 64 })
    assertEqual(b.w.tail.label.__text, "Combat Ended")
    assertEqual(b.w.tail.value.__text, "1:04")
    assertEqual(b.w.tail.caption.__text, "on the race clock")
end)

test("hud tiles: the waiting screen's tiles read the same as the Stop! screen's", function()
    local _, b = waitingBody()
    assertEqual(b.w.tail.value.__text, "+0.0s", "the unit in the figure, no bare s tail (no damage after the buzzer)")
    assertEqual(b.w.tail.caption.__text, "after buzzer")
    assertEqual(b.w.combat.value.__text, "+16.0s")
    assertEqual(b.w.combat.caption.__text, "since the buzzer")
end)

test("hud tiles: the moved Stop! and waiting stacks still fit the minimum height above the foot row", function()
    local f, b = stopBody()
    local S = f.NS.HudStates
    local note = b.w.note.__text
    local noteBottom = S.STOP_NOTE_Y + S.HintLines(note, 236) * S.HINT_LINE_H
    assertTrue(noteBottom + 8 + 20 <= S.MinContentHeight(), "the note clears Stop Now and Cancel")
    local named = "Combat is holding. Walk out of range, or use Feign Death or Shadowmeld. Your score is safe: it waits for combat to end, however long that takes."
    assertTrue(S.WAITING_HINT_Y + S.HintHeight(named, 236) + 8 + 20 <= S.MinContentHeight(),
        "the tallest hint box clears the foot row")
end)

test("hud tiles: the Stop! and waiting redraws read no geometry", function()
    local f, b = stopBody()
    for i = #f.W.geomReads, 1, -1 do f.W.geomReads[i] = nil end
    f:advance(0.5)
    f.NS.Hud.Tick()
    b:Update({ inCombat = true, tail = 3, sinceBuzzer = 3 })
    assertEqual(#f.W.SecretGeometryReads(), 0)
    local _, wb = waitingBody()
    wb:Update({ inCombat = true, tail = 16, sinceBuzzer = 20 })
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)
