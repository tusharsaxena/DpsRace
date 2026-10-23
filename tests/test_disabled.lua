-- tests/test_disabled.lua — the disabled state is total (slash-commands-§7): all ten steps of the
-- conformance test, driven through the kit's recording mocks.
--
-- The scaffold's owned "frames" are the HUD and Results placeholders (modules/Placeholders.lua): they
-- draw nothing yet, so step 5 asserts their SHOW DECISION, which is the source the standard says a
-- hide must be enforced at. When T7/T8 build the real windows, step 5 grows to their frames.

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

local function eventNames(inst)
    local seen, out = {}, {}
    for _, r in ipairs(inst.mocks.__registrations()) do
        if r.event and not seen[r.event] then
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

test("Disabled 4: no timer, ticker or OnUpdate is left armed, and none re-arms", function()
    -- red under: drop `addon:CancelAllTimers()` from standDown in core/LifecycleSetup.lua
    local inst, NS, M = scene()
    NS.addon:ScheduleTimer(function() NS.Print("timer fired") end, 5)
    assertEqual(#M.__timers(), 1, "the fixture needs one armed timer")
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
    assertTrue(NS.SetByPath("enabled", false))
    assertFalse(NS.Hud.IsShown(), "the HUD still decides to show")
    assertFalse(NS.Results.IsShown(), "the Results window still decides to show")
    assertFalse(NS.Preview.IsActive(), "test mode survived the stand-down")
end)

test("Disabled 6: every event fired anyway writes nothing, prints nothing, shows nothing", function()
    -- red under: make OnCombatChanged print or write (e.g. `NS.SetByPath("locked", true)` on combat)
    local inst, NS, M = scene()
    local events = eventNames(inst)
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
        local reached = M.__fireUnconditional(NS, event)
        assertTrue(reached >= 1, event .. " reached no handler, so its silence proves nothing")
    end
    assertEqual(#M.__svWrites(), 0, "a game event wrote SavedVariables while disabled")
    assertEqual(#M.__printed(), 0, "a game event printed while disabled")
    assertEqual(#M.__shownFrames(), shownBefore, "a game event showed a frame while disabled")
    assertFalse(NS.Hud.IsShown())
end)

test("Disabled 7: every verb answers while disabled; a feature verb answers one refusal line", function()
    local inst, NS, M = scene()
    local opened = 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    assertTrue(NS.SetByPath("enabled", false))
    local refusal = refusalLine(inst)

    NS.Slash:OnSlash("")
    assertEqual(opened, 1, "bare /dr opens the panel while disabled")

    for _, row in ipairs(NS.COMMANDS) do
        local verb = row[1]
        M.__resetPrinted()
        M.__resetSvWrites()
        NS.Slash:OnSlash(verb)
        local out = printedBare(M)
        if RESERVED[verb] then
            -- `help` may name the disabled state above its index; refused means the line ALONE.
            assertFalse(#out == 1 and out[1] == refusal, verb .. " was refused while disabled")
        else
            assertEqual(#out, 1, verb .. ": exactly one line")
            assertEqual(out[1], refusal, verb)
            assertEqual(#M.__svWrites(), 0, verb .. " reached a write seam")
        end
        if verb == "enable" then
            assertFalse(NS.IsDisabled(), "`enable` switched the addon back on")
            assertTrue(NS.SetByPath("enabled", false))
        end
    end
    assertTrue(opened >= 2, "`config` opened the panel")

    -- Under the `perf` hold alone a feature refuses with the capture line, never the disabled one.
    assertTrue(NS.SetByPath("enabled", true))
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    assertEqual(NS.StoodDownRefusal(), PERF_LINE)
    for _, row in ipairs(NS.COMMANDS) do
        if not RESERVED[row[1]] then
            M.__resetPrinted()
            NS.Slash:OnSlash(row[1])
            local out = printedBare(M)
            assertEqual(#out, 1, row[1])
            assertEqual(out[1], PERF_LINE, row[1])
        end
    end
    NS.Lifecycle:Release(NS.HOLD_PERF)
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
    for _, name in ipairs({ "DpsRaceToggleHud", "DpsRaceToggleResults" }) do
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
