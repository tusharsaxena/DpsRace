-- tests/test_launcher.lua — the launcher descriptor (one LDB object, registered twice), its menu
-- toggles onto the shared handlers, and the two Show-window key bindings (launcher-§1/§2/§6).

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function broker(inst)
    return inst.mocks.LibStub("LibDataBroker-1.1"):GetDataObjectByName("DpsRace")
end

local function openMenu(inst)
    local obj = broker(inst)
    obj.OnClick(inst.mocks.UIParent, "RightButton")
    return assert(inst.mocks.__lastMenu, "the right-click opened no menu")
end

test("launcher: one object named for the folder, labeled with the brand, wearing the logo", function()
    local inst = T.load()
    local obj = broker(inst)
    assertEqual(type(obj), "table")
    assertEqual(obj.type, "launcher")
    assertEqual(obj.label, "Ka0s DPS Race")
    assertEqual(obj.icon, "Interface\\AddOns\\DpsRace\\media\\logos\\dpsrace.logo.128.tga")
    local icon = inst.mocks.LibStub("LibDBIcon-1.0")
    assertEqual(icon.objects.DpsRace.broker, obj, "the minimap button is the SAME object")
    assertEqual(icon.objects.DpsRace.db, inst.NS.db.global.minimap, "LibDBIcon shares the stored table")
end)

test("launcher: left-click opens the settings panel", function()
    local inst = T.load()
    local opened = 0
    inst.NS.OpenOptionsPanel = function() opened = opened + 1 end
    broker(inst).OnClick(inst.mocks.UIParent, "LeftButton")
    assertEqual(opened, 1)
end)

test("launcher: right-click lists Enabled, Locked, Test mode and Show window, in that order", function()
    local inst = T.load()
    local menu = openMenu(inst)
    local labels = {}
    for i, e in ipairs(menu.entries) do labels[i] = e.text end
    assertEqual(table.concat(labels, "|"), "Enabled|Locked|Test mode|Show window")
    assertEqual(menu.titles[1], "Ka0s DPS Race")
end)

test("launcher: each menu toggle runs the shared handler", function()
    local inst = T.load()
    local NS = inst.NS
    openMenu(inst):Click("Locked")
    assertEqual(NS.db.profile.locked, true)
    openMenu(inst):Click("Test mode")
    assertTrue(NS.Preview.IsActive())
    openMenu(inst):Click("Show window")
    assertTrue(NS.Hud.IsShown())
    openMenu(inst):Click("Enabled")
    assertEqual(NS.db.profile.enabled, false)
    assertTrue(NS.IsDisabled())
end)

test("launcher: the Minimap button row hides and shows the real button", function()
    local inst = T.load()
    local icon = inst.mocks.LibStub("LibDBIcon-1.0")
    inst.NS.SetByPath(inst.NS.MINIMAP_PATH, false)
    assertEqual(icon.__shown.DpsRace, false)
    inst.NS.SetByPath(inst.NS.MINIMAP_PATH, true)
    assertEqual(icon.__shown.DpsRace, true)
end)

test("bindings: both Show-window buttons exist, plain and hidden, with their labels", function()
    local inst = T.load()
    local env = inst.mocks._G
    for _, name in ipairs({ "DpsRaceToggleHud", "DpsRaceToggleResults" }) do
        local b = env[name]
        assertEqual(type(b), "table", name)
        assertFalse(b:IsShown(), name .. " is hidden")
        assertEqual(type(env["BINDING_NAME_CLICK " .. name .. ":LeftButton"]), "string", name .. " label")
    end
    assertEqual(env.BINDING_HEADER_DPSRACE, "Ka0s DPS Race")
end)

test("bindings: a key press runs the same toggle the menu does", function()
    local inst = T.load()
    local env = inst.mocks._G
    env.DpsRaceToggleHud:__fire("OnClick", "LeftButton", true)
    assertTrue(inst.NS.Hud.IsShown())
    env.DpsRaceToggleResults:__fire("OnClick", "LeftButton", true)
    assertTrue(inst.NS.Results.IsShown())
end)

test("bindings: Bindings.xml names exactly the two buttons, with no default key", function()
    local f = assert(io.open(T.root .. "/Bindings.xml", "r"))
    local body = f:read("*a")
    f:close()
    assertTrue(body:find('CLICK DpsRaceToggleHud:LeftButton', 1, true) ~= nil)
    assertTrue(body:find('CLICK DpsRaceToggleResults:LeftButton', 1, true) ~= nil)
    assertEqual(body:find("default=", 1, true), nil)
    local _, headers = body:gsub('header="', "")
    assertEqual(headers, 1, "header on the first binding only")
end)
