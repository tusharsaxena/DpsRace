-- tests/test_preview.lua — modules/Preview.lua, test mode (spec §6.5, preview-mode): the scripted 30s
-- race on the HUD through its own render path, the test-mode strip, never a stored run, ended by
-- combat, by arming a real race, by its own switch and by the stand-down.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local function fixture()
    local W
    local f = RaceClock.new{ mutate = function(m) W = Widgets.install(m) end }
    f.W, f.Hud, f.Preview = W, f.NS.Hud, f.NS.Preview
    return f
end

local function ui(f) return assert(f.Hud.__ui(), "the HUD window was never built") end
local function current(f) return ui(f).current end

local function bare(M)
    local out = {}
    for i, l in ipairs(M.__printed()) do out[i] = (l:gsub("^|cff00ffff%[DR%]|r ", "")) end
    return out
end

test("preview: preview runs armed->running->stop->waiting->result and never writes a run", function()
    local f = fixture()
    local saved = 0
    f.NS.NewBusTarget():RegisterMessage(f.NS.MSG.RUN_SAVED, function() saved = saved + 1 end)
    assertTrue(f.Preview.Start())
    assertTrue(f.Hud.IsShown(), "test mode shows the HUD")
    local seen, last = {}, nil
    for _ = 1, 500 do
        local key = current(f)
        if key ~= last then seen[#seen + 1] = key; last = key end
        f:advance(0.1)
    end
    assertEqual(table.concat(seen, ","), "armed,running,stop,waiting,result")
    assertTrue(f.Preview.IsActive(), "test mode stays on until turned off")
    assertEqual(saved, 0)
    assertEqual(next(f.NS.db.global.runs), nil, "a test run reached the store")
    assertEqual(f.Race.State(), "idle", "the race engine never moved")
end)

test("preview: the running body counts the 30s race down with live figures", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    f:advance(f.Preview.SCRIPT[1].secs + 5)
    assertEqual(current(f), "running")
    local body = ui(f).body.running
    assertEqual(body.w.left.__text, "0:25.0")
    assertEqual(body.w.elapsed.__text, "0:05.0")
    assertTrue(body.w.list:Count() > 0, "no live rows")
    assertTrue(body.w.damage.value.__text ~= "\226\128\148", "no damage figure")
end)

test("preview: the running clock follows the Race clock setting", function()
    local f = fixture()
    f.NS.db.profile.hud.clock = "elapsed"
    assertTrue(f.Preview.Start())
    f:advance(f.Preview.SCRIPT[1].secs + 5)
    local w = ui(f).body.running.w
    assertTrue(w.clock:IsShown())
    assertFalse(w.left:IsShown())
    assertEqual(w.clock.__text, "0:05.0")
end)

test("preview: the result card is the sample run, with its chips", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    f:advance(60)
    assertEqual(current(f), "result")
    local chips = ui(f).body.result.w.chips:Texts()
    assertTrue(#chips >= 2, "no chips")
    assertTrue(chips[1]:find("New best", 1, true) ~= nil, chips[1])
end)

test("preview: the test strip says so on the display while it is on, and only then", function()
    local f = fixture()
    f.Hud.Show()
    assertTrue(f.Preview.Start())
    local strip = assert(ui(f).strip, "no test strip on the HUD")
    assertTrue(strip:IsShown())
    -- standalone-windows: one localized line saying what test mode shows and what ends it.
    assertEqual(strip.text:GetText(), "Test mode: sample numbers. Combat or Arm ends it")
    assertEqual(ui(f).frame.title.__text, "DPS Race", "one marker per mode: the strip, not the title too")
    f.Preview.Stop()
    assertFalse(strip:IsShown())
end)

test("preview: with no Widgets library the title carries the marker", function()
    local inst = T.load{ libFiles = {} }
    local NS = inst.NS
    assertTrue(NS.Preview.Start())
    local u = assert(NS.Hud.__ui())
    assertEqual(u.strip, nil)
    assertTrue(NS.Hud.TitleText():find("TEST", 1, true) ~= nil, NS.Hud.TitleText())
    NS.Preview.Stop()
    assertEqual(NS.Hud.TitleText(), "DPS Race")
end)

test("preview: arming a real race ends preview", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    f:advance(4)
    f.M.__resetPrinted()
    assertTrue(f.Race.Arm(60))
    assertFalse(f.Preview.IsActive())
    assertEqual(current(f), "armed", "the HUD shows the real race")
    assertFalse(ui(f).strip:IsShown())
    assertEqual(f.Preview.Diagnose().ticking, false, "the script kept running")
end)

test("preview: a start in combat is refused with one line; combat ends it and says so", function()
    local f = fixture()
    f.M.__inCombat = true
    f.M.__resetPrinted()
    assertFalse(f.Preview.Start())
    assertEqual(#bare(f.M), 1)
    assertFalse(f.NS.GetSetting("state.testMode"), "a refused start leaves the checkbox unticked")
    f.M.__inCombat = false
    assertTrue(f.Preview.Start())
    f.M.__resetPrinted()
    f.M.__inCombat = true
    f.M.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(f.Preview.IsActive())
    assertEqual(bare(f.M)[1], "Test mode ended: you entered combat.")
    assertEqual(f.Preview.Diagnose().ticking, false)
end)

test("preview: a start during a real race is refused", function()
    local f = fixture()
    assertTrue(f.Race.Arm(30))
    f.M.__resetPrinted()
    assertFalse(f.Preview.Start())
    assertEqual(#bare(f.M), 1)
    assertEqual(current(f), "armed")
end)

test("preview: turning it off gives the HUD back, closing it if test mode opened it", function()
    local f = fixture()
    assertFalse(f.Hud.IsShown())
    assertTrue(f.Preview.Start())
    f:advance(10)
    f.Preview.Stop()
    assertFalse(f.Hud.IsShown(), "the HUD test mode opened stayed open")
    f.Hud.Show()
    assertTrue(f.Preview.Start())
    f.Preview.Stop()
    assertTrue(f.Hud.IsShown(), "a HUD the player opened was closed")
    assertEqual(current(f), "idle")
end)

test("preview: Start again restarts the script; Reset all settings ends it", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    f:advance(45)
    assertEqual(current(f), "result")
    f.Preview.Stop()
    assertTrue(f.Preview.Start())
    assertEqual(current(f), "armed")
    f.NS.Helpers.RestoreAllDefaults()
    assertFalse(f.Preview.IsActive())
end)

test("preview: the stand-down ends it silently and cancels its timer", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    f.M.__resetPrinted()
    assertTrue(f.NS.SetByPath("enabled", false))
    assertFalse(f.Preview.IsActive())
    assertEqual(f.Preview.Diagnose().ticking, false)
    assertEqual(#f.M.__timers(), 0)
end)

--- A real 30s race read and shown: the state is RESULT and the HUD holds its card.
local function resolved(f)
    assertTrue(f:arm(30))
    f:start(25)
    f:to(129.5)
    f:update(25)
    f:to(130)
    f:advance(1)
    f:update(25)
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
end

test("preview: over a real result card its controls never touch the real race", function()
    local f = fixture()
    resolved(f)
    assertTrue(f.Preview.Start())
    f.Hud.Act.cancel()                       -- the preview's armed body's CANCEL
    assertEqual(f.Race.State(), "result", "a preview CANCEL dismissed the real result")
    assertFalse(f.Preview.IsActive(), "CANCEL in test mode ends test mode")
    assertTrue(f.Preview.Start())
    f:advance(60)
    assertEqual(current(f), "result")
    local card = ui(f).body.result.w
    assertFalse(card.again:IsEnabled(), "the sample card offers RACE AGAIN")
    assertFalse(card.details:IsEnabled(), "the sample card offers DETAILS")
    f.Hud.Act.raceAgain()
    f.Hud.Act.details()
    assertEqual(f.Race.State(), "result", "the preview's RACE AGAIN armed a real race")
    assertFalse(f.NS.Results.IsShown(), "the preview's DETAILS opened a real run")
    f.Hud.Act.close()
    assertEqual(f.Race.State(), "result", "closing the preview dismissed the real result")
    assertFalse(f.Preview.IsActive(), "closing the window test mode runs on ends it")
end)

test("preview: a HUD test mode opened is handed to the race that ended it, and closes with it", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    assertTrue(f.Race.Arm(60))
    assertTrue(f.Hud.IsShown(), "the HUD left the armed race")
    f.Race.Cancel()
    assertFalse(f.Hud.IsShown(), "onArm did not close the window after the race went back to idle")
end)

test("preview: a stand-down drops the HUD test mode opened", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    assertTrue(f.NS.SetByPath("enabled", false))
    assertTrue(f.NS.SetByPath("enabled", true))
    assertFalse(f.Hud.IsShown(), "the stand-up showed a HUD only test mode had opened")
end)

test("preview: every start and stop repaints an open panel's Test mode checkbox", function()
    local f = fixture()
    local H = assert(f.NS.Helpers, "no options helpers")
    local repaints = 0
    H.RefreshScalars = function() repaints = repaints + 1 end
    assertTrue(f.Preview.Start())
    assertEqual(repaints, 1, "the start left the checkbox as it was")
    assertTrue(f.Race.Arm(60))              -- from chat or the key, with the panel open
    assertFalse(f.Preview.IsActive())
    assertEqual(repaints, 2, "the race-armed stop left the checkbox ticked")
    assertEqual(f.NS.GetSetting("state.testMode"), false)
end)
