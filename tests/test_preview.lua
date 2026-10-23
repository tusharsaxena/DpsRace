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
    assertEqual(body.w.clock.__text, "0:25.0")
    assertTrue(body.w.list:Count() > 0, "no live rows")
    assertTrue(body.w.damage.value.__text ~= "\226\128\148", "no damage figure")
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
