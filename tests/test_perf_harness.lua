-- tests/test_perf_harness.lua — the performance harness's wiring (testing-§8, performance-§1/§6): the
-- descriptor is well-formed, every declared bucket is reached by a real bracket, and the perf hold
-- genuinely makes this addon inert.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

test("perf: the descriptor declares the buckets, the SavedVariable and the one latch", function()
    local inst = T.load()
    local NS = inst.NS
    local d = assert(NS.Perf.descriptor, "NS.Perf carries no descriptor; was the stub loaded?")
    local keys = {}
    for i, b in ipairs(d.buckets) do keys[i] = b.key end
    assertEqual(table.concat(keys, ","), "combatEvent,raceEvent")
    assertEqual(d.sv, "DpsRacePerfDB")
    assertTrue(d.lifecycle == NS.lifecycle, "the harness holds a latch other than NS.lifecycle")
    assertEqual(d.suspend, nil, "a second teardown path beside the latch (performance-§6)")
    assertEqual(d.resume, nil, "a second stand-up path beside the latch (performance-§6)")
end)

test("perf: every declared bucket is reached by a real bracket", function()
    -- red under: drop the `Perf.Note("combatEvent", ...)` line from NS:OnCombatChanged
    local inst = T.load{ mutate = function(m) T.mockMeter.install(m) end }
    local NS, M = inst.NS, inst.mocks
    local reach = {
        -- combatEvent: the combat-boundary handler, through the event the client fires.
        combatEvent = function() M.__fire("PLAYER_REGEN_DISABLED") end,
        -- raceEvent: the race watchers' handler, live once a race is armed.
        raceEvent = function()
            assert(NS.Race.Arm(30), "the fixture could not arm")
            M.__fire("DAMAGE_METER_RESET")
        end,
    }
    NS.Perf.on = true          -- inside an experiment window: what the sampler sets when one opens
    for _, b in ipairs(NS.Perf.descriptor.buckets) do
        local drive = assert(reach[b.key], b.key .. " is declared but this case has no driver for it")
        drive()
        local got = NS.Perf.__buckets()[b.key]
        assertTrue(got ~= nil and got.calls >= 1, b.key .. " recorded no sample")
    end
    NS.Perf.on = false
end)

test("perf: outside an experiment the bracket records nothing", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    assertFalse(NS.Perf.on)
    M.__fire("PLAYER_REGEN_DISABLED")
    assertEqual(NS.Perf.__buckets().combatEvent, nil)
end)

test("perf: suspend takes the perf hold and the addon is inert; resume restores it", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    assertTrue(#M.__registrations() > 0, "the baseline registers nothing; nothing below can fail")
    NS.Hud.Show()
    assertTrue(NS.Perf.Suspend())
    assertTrue(NS.Perf.suspended)
    assertTrue(NS.lifecycle:IsHeld(NS.HOLD_PERF))
    assertEqual(#M.__registrations(), 0, "a registration survived the perf hold")
    local allows, why = NS.MasterVisibilityAllows()
    assertFalse(allows)
    assertEqual(why, "suspended")
    assertFalse(NS.Hud.IsShown(), "the HUD still decides to show under the perf hold")
    assertFalse(NS.IsDisabled(), "the perf hold reads as the disabled hold")
    assertTrue(NS.Perf.Resume())
    assertFalse(NS.IsStoodDown())
    assertTrue(#M.__registrations() > 0, "resume did not rebuild the registrations")
end)
