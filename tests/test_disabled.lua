-- tests/test_disabled.lua — the disabled state is total (slash-commands-§7): all ten steps of the
-- conformance test, driven through the kit's recording mocks.
--
-- The owned frames: the Race HUD (modules/Hud.lua, T7) and the Results window (modules/Results.lua,
-- T8) are real windows, so step 5 asserts both each one's show decision and its frame.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- slash-commands-§2's never-feature verbs: these keep answering, normally, while disabled.
local RESERVED = {
    help = true, config = true, version = true, enable = true, disable = true, debug = true,
    diagnostics = true, perf = true, get = true, set = true, list = true, reset = true, resetall = true,
}

local PERF_LINE = "Not available during a performance capture."

local function regKey(r)
    return ("%s|%s|%s|%s"):format(tostring(r.target or r.owner), r.kind, tostring(r.event), tostring(r.unit))
end

local function regKeys(inst)
    local out = {}
    for _, r in ipairs(inst.mocks.__registrations()) do out[#out + 1] = regKey(r) end
    table.sort(out)
    return out
end

--- The GAME events registered. Bus messages (kind "message": modules/Bests.lua's receiver) are left
--- out: they are not game events to fire, and steps 2+3 and the bus-receiver cases cover them.
local function eventNames(inst)
    local seen, out = {}, {}
    for _, r in ipairs(inst.mocks.__registrations()) do
        if r.event and r.kind ~= "message" and not seen[r.event] then
            seen[r.event] = true
            out[#out + 1] = r.event
        end
    end
    table.sort(out)
    return out
end

--- Baseline: enabled, both windows wanted on screen, test mode on, the SV trees watched.
local function scene()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    NS.Hud.Show()
    NS.Results.Show()
    assertTrue(NS.Preview.Start(), "the fixture needs test mode on")
    M.__watchSv("DpsRacePerfDB")
    M.__resetSvWrites()
    M.__resetPrinted()
    return inst, NS, M
end

local function refusalLine(inst)
    return inst.mocks.LibStub("LibKa0s-Slash-1.0").DISABLED_LINE_FORMAT:format("Ka0s DPS Race", "/dr enable")
end

--- The printed lines, with the chat tag stripped, so a line compares against its bare text.
local function printedBare(M)
    local out = {}
    for i, l in ipairs(M.__printed()) do out[i] = l:gsub("^|cff00ffff%[DR%]|r ", "") end
    return out
end

test("Disabled 1: enabled, the addon registers something and shows something at all", function()
    local inst, NS = scene()
    assertTrue(#regKeys(inst) > 0, "the baseline registration set is empty; nothing below can fail")
    assertTrue(NS.Hud.IsShown() and NS.Results.IsShown(), "nothing is shown to be hidden")
end)

test("Disabled 2+3: disabling through the write seam leaves NO registration behind", function()
    -- red under: drop `addon:UnregisterAllEvents()` from standDown in core/LifecycleSetup.lua
    local inst, NS = scene()
    local before = regKeys(inst)
    assertTrue(#before > 0)
    assertTrue(NS.SetByPath("enabled", false))
    local after = regKeys(inst)
    assertEqual(#after, 0, "still registered: " .. table.concat(after, ", "))
end)

--- A bus receiver on a target from NS.NewBusTarget(), counting what it hears.
local function busReceiver(NS)
    local hits = { n = 0 }
    local target = assert(NS.NewBusTarget(), "no bus target (AceEvent absent?)")
    target:RegisterMessage(NS.MSG.RUN_SAVED, function() hits.n = hits.n + 1 end)
    return hits
end

for _, arm in ipairs({ { label = "live", opts = nil }, { label = "degraded", opts = { libFiles = {} } } }) do
    test("Disabled 2+3 (" .. arm.label .. "): a module's bus receiver goes at stand-down and comes back", function()
        -- red under (degraded): make the Bus stub's StandDown in core/Bus.lua `return 0` again
        local inst = T.load(arm.opts)
        local NS = inst.NS
        local hits = busReceiver(NS)
        NS.SendBus(NS.MSG.RUN_SAVED)
        assertEqual(hits.n, 1, "the fixture's receiver never heard the bus")
        NS.RunVerb("disable")
        assertTrue(NS.IsDisabled())
        NS.SendBus(NS.MSG.RUN_SAVED)
        assertEqual(hits.n, 1, "a bus receiver fired while disabled")
        local left = regKeys(inst)
        assertEqual(#left, 0, "still registered: " .. table.concat(left, ", "))
        NS.RunVerb("enable")
        assertFalse(NS.IsStoodDown())
        NS.SendBus(NS.MSG.RUN_SAVED)
        assertEqual(hits.n, 2, "the receiver was not replayed at stand-up")
    end)
end

test("Disabled 4: no timer, ticker or OnUpdate is left armed, and none re-arms", function()
    -- red under: drop `addon:CancelAllTimers()` from standDown in core/LifecycleSetup.lua
    local inst, NS, M = scene()
    -- The baseline's own: test mode's script ticker (modules/Preview.lua).
    local baseline = #M.__timers()
    NS.addon:ScheduleTimer(function() NS.Print("timer fired") end, 5)
    assertEqual(#M.__timers(), baseline + 1, "the fixture needs one armed timer")
    assertTrue(NS.SetByPath("enabled", false))
    assertEqual(#M.__timers(), 0)
    M.__fireTimers()
    assertEqual(#M.__timers(), 0, "something re-armed itself while disabled")
    assertEqual(#M.__printed(), 0)
    assertTrue(inst ~= nil)
end)

test("Disabled 5: every display that was shown is hidden, refused at the source", function()
    -- red under: drop the IsStoodDown rung from NS.MasterVisibilityAllows in core/DpsRace.lua
    local _, NS = scene()
    local hud = assert(NS.Hud.__ui(), "the baseline never built the HUD window")
    assertTrue(hud.frame:IsShown(), "the HUD window is not on screen to be hidden")
    assertTrue(assert(NS.Results.__ui(), "the baseline never built the Results window").frame:IsShown())
    assertTrue(NS.SetByPath("enabled", false))
    assertFalse(NS.Hud.IsShown(), "the HUD still decides to show")
    assertFalse(hud.frame:IsShown(), "the HUD window stayed on screen")
    assertFalse(NS.Results.IsShown(), "the Results window still decides to show")
    assertFalse(NS.Results.__ui().frame:IsShown(), "the Results window stayed on screen")
    assertFalse(NS.Preview.IsActive(), "test mode survived the stand-down")
end)

--- Every game event of the baseline, with each target (the addon object, the HUD's event frame)
--- that held it, so a stood-down handler can be reached straight.
local function eventTargets(inst)
    local out = {}
    for _, r in ipairs(inst.mocks.__registrations()) do
        if r.event and r.kind ~= "message" then
            out[r.event] = out[r.event] or {}
            out[r.event][#out[r.event] + 1] = r.target
        end
    end
    return out
end

test("Disabled 6: every event fired anyway writes nothing, prints nothing, shows nothing", function()
    -- red under: make OnCombatChanged print or write (e.g. `NS.SetByPath("locked", true)` on combat)
    local inst, NS, M = scene()
    local events = eventNames(inst)
    local holders = eventTargets(inst)
    assertTrue(#events > 0)
    local combatEntry = false
    for _, e in ipairs(events) do if e == "PLAYER_REGEN_DISABLED" then combatEntry = true end end
    assertTrue(combatEntry, "the combat-entry event is in the baseline set")
    assertTrue(NS.SetByPath("enabled", false))
    M.__resetSvWrites()
    M.__resetPrinted()
    local shownBefore = #M.__shownFrames()
    for _, event in ipairs(events) do
        M.__fire(event)
        local reached = 0
        for _, target in ipairs(holders[event]) do reached = reached + M.__fireUnconditional(target, event) end
        assertTrue(reached >= 1, event .. " reached no handler, so its silence proves nothing")
    end
    assertEqual(#M.__svWrites(), 0, "a game event wrote SavedVariables while disabled")
    assertEqual(#M.__printed(), 0, "a game event printed while disabled")
    assertEqual(#M.__shownFrames(), shownBefore, "a game event showed a frame while disabled")
    assertFalse(NS.Hud.IsShown())
end)

--- Until T9 appends the real feature verbs every shipped verb is reserved, so a case that walks only
--- NS.COMMANDS would check the refusal path zero times. A probe feature row, appended to THIS
--- instance's table (the dispatcher holds the same table), routes through the shared handler and
--- counts its own calls: while disabled the DISPATCHER must refuse it (zero calls), under the perf
--- hold alone the dispatcher lets it through and the handler's own refusal answers.
local function addProbeVerb(NS)
    local probe = { calls = 0 }
    NS.COMMANDS[#NS.COMMANDS + 1] = { "probe", "a feature verb for the test", function()
        probe.calls = probe.calls + 1
        NS.ToggleHud()
    end }
    return probe
end

--- Walk every verb while disabled; returns how many feature (non-reserved) verbs were checked.
local function verbsWhileDisabled(NS, M, refusal)
    local features = 0
    for _, row in ipairs(NS.COMMANDS) do
        local verb = row[1]
        M.__resetPrinted()
        M.__resetSvWrites()
        local wanted = NS.Hud.wanted
        NS.Slash:OnSlash(verb)
        local out = printedBare(M)
        if RESERVED[verb] then
            -- `help` may name the disabled state above its index; refused means the line ALONE.
            assertFalse(#out == 1 and out[1] == refusal, verb .. " was refused while disabled")
        else
            features = features + 1
            assertEqual(#out, 1, verb .. ": exactly one line")
            assertEqual(out[1], refusal, verb)
            assertEqual(#M.__svWrites(), 0, verb .. " reached a write seam")
            assertEqual(NS.Hud.wanted, wanted, verb .. " acted while disabled")
        end
        if verb == "enable" then
            assertFalse(NS.IsDisabled(), "`enable` switched the addon back on")
            assertTrue(NS.SetByPath("enabled", false))
        end
    end
    return features
end

--- Under the `perf` hold alone a feature refuses with the capture line, never the disabled one.
local function verbsUnderPerfHold(NS, M)
    assertTrue(NS.SetByPath("enabled", true))
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    assertEqual(NS.StoodDownRefusal(), PERF_LINE)
    local features = 0
    for _, row in ipairs(NS.COMMANDS) do
        if not RESERVED[row[1]] then
            features = features + 1
            M.__resetPrinted()
            NS.Slash:OnSlash(row[1])
            local out = printedBare(M)
            assertEqual(#out, 1, row[1])
            assertEqual(out[1], PERF_LINE, row[1])
        end
    end
    NS.Lifecycle:Release(NS.HOLD_PERF)
    return features
end

test("Disabled 7: every verb answers while disabled; a feature verb answers one refusal line", function()
    -- red under: drop `isEnabled` from the descriptor in settings/Slash.lua (the probe's handler
    -- then runs while disabled; its own refusal would hide that, so its call count pins the gate)
    local inst, NS, M = scene()
    local probe = addProbeVerb(NS)
    local opened = 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    assertTrue(NS.SetByPath("enabled", false))

    NS.Slash:OnSlash("")
    assertEqual(opened, 1, "bare /dr opens the panel while disabled")

    assertTrue(verbsWhileDisabled(NS, M, refusalLine(inst)) >= 1, "no feature verb was exercised")
    assertEqual(probe.calls, 0, "the dispatcher let a feature verb through while disabled")
    assertTrue(opened >= 2, "`config` opened the panel")
    assertTrue(verbsUnderPerfHold(NS, M) >= 1, "no feature verb was exercised under the perf hold")
    assertEqual(probe.calls, 1, "under the perf hold alone the handler itself answers")
end)

test("Disabled 7 (degraded): the library-absent dispatcher gates a feature verb the same way", function()
    -- red under: drop the `d.isEnabled` check from the stub's OnSlash in settings/Slash.lua
    local inst = T.load{ libFiles = {} }
    local NS, M = inst.NS, inst.mocks
    NS.OpenOptionsPanel = function() end
    -- Degraded, a write to `enabled` is written through with no onChange; the verb takes the hold.
    NS.RunVerb("disable")
    assertTrue(NS.IsDisabled())
    local probeRan = false
    NS.COMMANDS[#NS.COMMANDS + 1] = { "probe", "a feature verb", function() probeRan = true end }
    M.__resetPrinted()
    NS.Slash:OnSlash("probe")
    local out = printedBare(M)
    assertFalse(probeRan, "the stub dispatched a feature verb while disabled")
    assertEqual(out[#out], refusalLine(T), "the stub's refusal is not the one disabled line")
    -- A reserved verb still answers.
    M.__resetPrinted()
    NS.Slash:OnSlash("version")
    assertTrue(#M.__printed() > 0, "version was refused while disabled")
end)

test("Disabled 8: launcher clicks and the key binding write nothing and show nothing", function()
    local inst, NS, M = scene()
    assertTrue(NS.SetByPath("enabled", false))
    local opened = 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    M.__resetSvWrites()
    local shownBefore = #M.__shownFrames()
    local obj = M.LibStub("LibDataBroker-1.1"):GetDataObjectByName("DpsRace")

    obj.OnClick(M.UIParent, "LeftButton")
    assertEqual(opened, 1, "left-click still opens the panel")

    obj.OnClick(M.UIParent, "RightButton")
    local menu = assert(M.__lastMenu, "right-click opened no menu")
    for _, entry in ipairs(menu.entries) do
        local live = entry.text == "Enabled"
        assertEqual(entry.enabled, live, entry.text .. (live and " must stay live" or " must be grayed"))
    end
    assertEqual(#M.__svWrites(), 0, "a launcher click wrote SavedVariables")
    assertEqual(#M.__shownFrames(), shownBefore, "a launcher click showed a frame")

    -- The key binding: one refusal line, no toggle.
    local refusal = refusalLine(inst)
    for _, name in ipairs({ "DpsRaceToggleHud", "DpsRaceToggleResults", "DpsRaceArmToggle" }) do
        M.__resetPrinted()
        local hudWanted, resultsWanted = NS.Hud.wanted, NS.Results.wanted
        M._G[name]:__fire("OnClick", "LeftButton", true)
        local out = printedBare(M)
        assertEqual(#out, 1, name)
        assertEqual(out[1], refusal, name)
        assertEqual(NS.Hud.wanted, hudWanted, name .. " toggled the HUD while disabled")
        assertEqual(NS.Results.wanted, resultsWanted, name .. " toggled Results while disabled")
    end
    assertEqual(#M.__svWrites(), 0)

    -- Enabled again, the perf hold alone: the capture line, never the disabled one, and no toggle.
    assertTrue(NS.SetByPath("enabled", true))
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    M.__resetPrinted()
    local wanted = NS.Hud.wanted
    M._G.DpsRaceToggleHud:__fire("OnClick", "LeftButton", true)
    local out = printedBare(M)
    assertEqual(#out, 1)
    assertEqual(out[1], PERF_LINE)
    assertEqual(NS.Hud.wanted, wanted)
    NS.Lifecycle:Release(NS.HOLD_PERF)
end)

test("Disabled 9: re-enabling restores the set FROM CURRENT STATE, not a snapshot", function()
    local inst, NS = scene()
    local on = table.concat(regKeys(inst), ",")
    assertTrue(NS.SetByPath("enabled", false))
    assertTrue(NS.SetByPath("enabled", true))
    assertEqual(table.concat(regKeys(inst), ","), on)

    -- A setting changed while disabled comes back in the rebuilt set.
    assertTrue(NS.SetByPath("enabled", false))
    assertTrue(NS.SetByPath("visibility", "inCombat"))
    assertEqual(#regKeys(inst), 0, "a write while disabled registered something")
    assertTrue(NS.SetByPath("enabled", true))
    local events = eventNames(inst)
    assertEqual(table.concat(events, ","), "PLAYER_REGEN_DISABLED,PLAYER_REGEN_ENABLED")
end)

test("Disabled 10: releasing ONE hold does not resurrect an addon the other holds down", function()
    -- red under: make NS.ApplyEnabled call NS.StandUp() directly on enable instead of releasing the
    -- `disabled` hold -- order B then comes back up while the `perf` hold is still taken.
    local inst, NS = scene()
    T.assertLatchHoldOrder{
        lifecycle  = NS.Lifecycle,
        perfHold   = NS.HOLD_PERF,
        setEnabled = function(on) assertTrue(NS.SetByPath("enabled", on)) end,
        regSet     = function() return inst.mocks.__registrations() end,
        label      = "DpsRace",
    }
end)

test("Disabled: a profile switch re-reads the stored switch while disabled", function()
    local _, NS = scene()
    assertTrue(NS.SetByPath("enabled", false))
    NS.db:SetProfile("Other")
    assertFalse(NS.IsDisabled(), "the new profile's default `enabled = true` stood the addon up")
    NS.db:SetProfile("Default")
    assertTrue(NS.IsDisabled(), "switching back re-took the hold")
end)

-- ── the race watchers (T5) ──────────────────────────────────────────────────────────────────────
-- Watchers registers nothing while idle, so the baseline scene above never sees it. These cases arm
-- and run a race first, so the meter, combat and cast events are live when the addon is disabled.

local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)

--- The rows on the Watchers frame, as "event|unit".
local function watcherRows(inst)
    local frame, out = inst.NS.Watchers.Frame(), {}
    for _, r in ipairs(inst.mocks.__registrations()) do
        if frame and r.target == frame then out[#out + 1] = tostring(r.event) .. "|" .. tostring(r.unit) end
    end
    table.sort(out)
    return out
end

test("Disabled (race): Watchers holds no registrations and Race does nothing while disabled", function()
    -- red under: drop "Watchers" from the stand-down list in core/LifecycleSetup.lua
    local f = RaceClock.new()
    local NS, M = f.NS, f.M
    assertEqual(#watcherRows(f.inst), 0, "idle: Watchers watches nothing")
    assertTrue(f:arm(30))
    local armed = watcherRows(f.inst)
    assertTrue(#armed > 0, "armed: the meter and combat events are live")
    f:start(25)
    local run = NS.Race.Current()
    assertTrue(#watcherRows(f.inst) > #armed, "running: the player's cast events join them")

    M.__resetPrinted()
    assertTrue(NS.SetByPath("enabled", false))
    assertEqual(#watcherRows(f.inst), 0, "still registered: " .. table.concat(watcherRows(f.inst), ", "))
    assertEqual(#regKeys(f.inst), 0)
    assertEqual(#M.__timers(), 0, "the buzzer or the poll survived the stand-down")
    assertEqual(NS.Race.State(), "idle")

    -- Every event fired anyway, straight at the Watchers frame, and every input called directly.
    local events = { "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_COMBAT_SESSION_UPDATED",
                     "DAMAGE_METER_RESET", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD",
                     "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
                     "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_STOP" }
    for _, event in ipairs(events) do
        assertEqual(M.__fireUnconditional(NS.Watchers.Frame(), event, "player", 25, 25), 1, event)
    end
    NS.Race.OnSessionCreated(150)
    NS.Race.OnMeterReset()
    NS.Race.OnCombatEnd(150)
    f:advance(60)
    assertEqual(run.status, "running", "the stored run was left exactly as it was")
    assertEqual(NS.Race.State(), "idle")
    assertEqual(#f.heard.buzzers, 0)
    local ok, why = NS.Race.Arm(30)
    assertFalse(ok)
    assertEqual(why, "disabled")
    assertEqual(#M.__printed(), 0, "the race printed while disabled")

    -- Standing back up resumes the stored run from its own status (spec §4.5), cast events and all.
    assertTrue(NS.SetByPath("enabled", true))
    assertEqual(NS.Race.State(), "stopping")
    assertTrue(run.flags.reloaded)
    assertTrue(#watcherRows(f.inst) > #armed)
end)

test("Disabled (race): an armed race is dropped by the stand-down and not resumed", function()
    local f = RaceClock.new()
    local NS = f.NS
    assertTrue(f:arm(30))
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    assertEqual(#watcherRows(f.inst), 0, "the perf hold took the registrations too")
    assertEqual(NS.Race.State(), "idle")
    NS.Lifecycle:Release(NS.HOLD_PERF)
    assertEqual(NS.Race.State(), "idle", "an armed run was never stored, so nothing resumes")
    assertEqual(#watcherRows(f.inst), 0)
end)

test("Disabled (race): a disabled login resumes nothing until the addon is enabled", function()
    local f = RaceClock.new{ enable = false }
    local NS = f.NS
    f.meter.SetSession(25, RaceClock.SESSION)
    NS.db.global.runs["1-1000"] = RaceClock.storedRun({ id = "1-1000", status = "stopping" })
    assertTrue(NS.SetByPath("enabled", false))
    f:enable()
    assertEqual(NS.Race.State(), "idle")
    assertEqual(NS.db.global.runs["1-1000"].status, "stopping", "untouched while disabled")
    assertTrue(NS.SetByPath("enabled", true))
    assertEqual(NS.db.global.runs["1-1000"].status, "complete", "read at the stand-up edge")
end)
