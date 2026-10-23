-- tests/test_timeline.lua — modules/Timeline.lua: the run session's damage-update timeline (spec §5.3),
-- its tail after the buzzer, the damage-restarted check and the quiet time before the result read.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertNil, assertNear =
    T.test, T.assertEqual, T.assertTrue, T.assertNil, T.assertNear

-- An arbitrary GetTime() for the buzzer; every fixture is written as offsets from it.
local BUZZER = 1000.0

local function timeline(offsets)
    local tl = T.NS.Timeline.New()
    for _, o in ipairs(offsets) do tl:AddDamage(BUZZER + o) end
    return tl
end

-- Probe run 4 (2026-10-23): no DoTs, damage stopped about 3s after the buzzer.
local RUN4 = { -2.09, 0.45, 1.04, 1.35, 2.47, 3.03 }
-- Probe run 6: DoT ticks about every 2s, the last at +8.49.
local RUN6 = { -5.51, -3.50, -1.52, 0.49, 2.50, 4.51, 6.49, 8.49 }

test("timeline: tail from probe run 4 = 3.03", function()
    local tl = timeline(RUN4)
    assertNear(tl:Tail(BUZZER), 3.03, 1e-6)
    assertNil(tl:RestartAt(BUZZER, 6), "no restart in run 4")
    assertNear(tl:LastDamage(), BUZZER + 3.03, 1e-6)
end)

test("timeline: tail from probe run 6 = 8.49", function()
    local tl = timeline(RUN6)
    assertNear(tl:Tail(BUZZER), 8.49, 1e-6)
    assertNil(tl:RestartAt(BUZZER, 6), "no restart at gap 6")
end)

test("timeline: restart detected after 10s quiet at gap 6", function()
    local tl = timeline({ -1.0, 0.5, 2.0, 12.0, 13.1 })
    assertNear(tl:RestartAt(BUZZER, 6), 12.0, 1e-6, "the first update after the quiet stretch")
    assertNear(tl:Tail(BUZZER), 13.1, 1e-6)
end)

test("timeline: DoT ticks every 2s are not a restart", function()
    local offsets = {}
    for i = 0, 15 do offsets[#offsets + 1] = -4 + i * 2 end   -- -4 .. +26, every 2s
    local tl = timeline(offsets)
    assertNil(tl:RestartAt(BUZZER, 3), "2s spacing never reaches the 3s minimum gap")
    assertNear(tl:Tail(BUZZER), 26, 1e-6)
end)

test("timeline: the quiet stretch starts at the buzzer when the last damage was before it", function()
    local tl = timeline({ -3.0, 7.0 })
    assertNear(tl:RestartAt(BUZZER, 6), 7.0, 1e-6, "7s from the buzzer is quiet enough")
    tl = timeline({ -3.0, 5.0 })
    assertNil(tl:RestartAt(BUZZER, 6), "5s from the buzzer is not, however long before it")
end)

test("timeline: a gap of exactly the setting counts as a restart", function()
    local tl = timeline({ 1.0, 7.0 })
    assertNear(tl:RestartAt(BUZZER, 6), 7.0, 1e-6)
end)

test("timeline: no damage after the buzzer gives tail 0 and no restart", function()
    local tl = timeline({ -9.0, -4.0, -0.5 })
    assertEqual(tl:Tail(BUZZER), 0)
    assertNil(tl:RestartAt(BUZZER, 6))
    local empty = T.NS.Timeline.New()
    assertEqual(empty:Tail(BUZZER), 0)
    assertNil(empty:RestartAt(BUZZER, 6))
    assertNil(empty:LastDamage())
end)

test("timeline: QuietFor with no damage is huge", function()
    local tl = T.NS.Timeline.New()
    assertEqual(tl:QuietFor(BUZZER), math.huge)
    tl:AddDamage(BUZZER + 1.3)
    assertNear(tl:QuietFor(BUZZER + 3.8), 2.5, 1e-6)
end)

test("timeline: an out-of-order or non-number update is handled", function()
    local tl = T.NS.Timeline.New()
    tl:AddDamage(BUZZER + 2)
    tl:AddDamage(BUZZER + 1)        -- arrives late: the last damage stays +2
    tl:AddDamage(nil)
    tl:AddDamage("soon")
    assertNear(tl:LastDamage(), BUZZER + 2, 1e-6)
    assertNear(tl:Tail(BUZZER), 2, 1e-6)
end)

test("timeline: two timelines are independent", function()
    local a, b = T.NS.Timeline.New(), T.NS.Timeline.New()
    a:AddDamage(BUZZER)
    assertNil(b:LastDamage())
    assertTrue(a:LastDamage() ~= nil)
end)
