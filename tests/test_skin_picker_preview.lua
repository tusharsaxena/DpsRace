-- tests/test_skin_picker_preview.lua — the skin picker's preview (core/SkinSetup.lua's spec.preview;
-- LibKa0s OptionsSkinPicker minor 11, R6-PV of Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND6).
--
-- The owner's rule: the picker shown while the race HUD is hidden turns test mode on, the eye turns it
-- off and on, and every close puts the addon back as it was when the picker opened. What this addon
-- owes is the hook: its mode, and enter / exit / isActive / isShown through the same handler `/dr test`
-- and the launcher's Test mode entry call (NS.ToggleTestMode), so the Master controls' checkbox, the
-- launcher and the combat and race refusals stay in step. The library pins its own state machine.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

--- A fresh instance: the harness's profile has seen the picker, so none is up and test mode is off.
local function fresh(opts)
    local inst = T.load(opts)
    return inst.NS, inst.mocks
end

--- The library's window for this owner, shown by `/dr skin` (the launcher's Skin entry's act too).
local function open(NS)
    local f = NS.RunSkinVerb()
    assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
    return f
end

local function testOn(NS) return NS.Preview.Mode() == "test" end

local function assertRestored(NS, what)
    assertFalse(NS.Preview.IsActive(), what .. ": test mode stayed on")
    assertFalse(NS.Hud.IsShown(), what .. ": the HUD stayed up")
    assertFalse(NS.Results.IsShown(), what .. ": the Results window stayed up")
end

test("skin picker preview: the spec passes spec.preview in test mode, and no one-shot onPreview", function()
    -- red under: the old `onPreview = previewSkin` (the eye only entered, nothing restored).
    local NS = fresh()
    local spec = NS.SkinPickerSpec()
    assertEqual(spec.onPreview, nil, "the one-shot eye is gone")
    local p = spec.preview
    assertTrue(type(p) == "table", "no spec.preview")
    assertEqual(p.mode, "test", "DpsRace previews in test mode (00_PLAN.md call 2)")
    for _, k in ipairs({ "enter", "exit", "isActive", "isShown" }) do
        assertEqual(type(p[k]), "function", k)
    end
end)

test("skin picker preview: the hook goes through NS.ToggleTestMode, the verb's and the launcher's seam", function()
    local NS = fresh()
    local p, real, calls = NS.SkinPickerSpec().preview, NS.ToggleTestMode, 0
    NS.ToggleTestMode = function(...) calls = calls + 1 return real(...) end
    local ok, err = pcall(function()
        p.enter("eye")
        assertEqual(calls, 1, "enter did not call NS.ToggleTestMode")
        assertTrue(p.isActive(), "isActive reads test mode")
        assertTrue(p.isShown(), "isShown reads the HUD the preview showed")
        assertTrue(NS.GetSetting("state.testMode"), "the Test mode row reads on")
        p.enter("eye")
        assertEqual(calls, 1, "enter with test mode on must not toggle it off")
        p.exit("eye")
        assertEqual(calls, 2, "exit did not call NS.ToggleTestMode")
        assertFalse(p.isActive())
        p.exit("eye")
        assertEqual(calls, 2, "exit with test mode off must not toggle it on")
    end)
    NS.ToggleTestMode = real
    if not ok then error(err, 0) end
end)

test("skin picker preview: opened with the HUD hidden, the picker turns test mode on", function()
    local NS = fresh()
    assertFalse(NS.Hud.IsShown(), "the harness starts with the HUD hidden")
    assertFalse(NS.Preview.IsActive())
    local f = open(NS)
    assertTrue(testOn(NS), "the picker did not enter test mode")
    assertTrue(NS.Hud.IsShown(), "test mode shows the HUD on sample data")
    assertTrue(f.preview.lit, "the eye is lit while test mode is on")
    NS.Helpers.HideSkinPicker()
end)

test("skin picker preview: the eye turns test mode off and on again", function()
    local NS = fresh()
    local f = open(NS)
    f.preview:__fire("OnClick")
    assertFalse(NS.Preview.IsActive(), "the eye did not turn test mode off")
    assertFalse(NS.Hud.IsShown(), "test mode's end gives the HUD back")
    assertFalse(f.preview.lit, "the eye dims")
    assertTrue(f:IsShown(), "the picker stays up")
    f.preview:__fire("OnClick")
    assertTrue(testOn(NS), "the eye did not turn test mode on again")
    assertTrue(f.preview.lit)
    NS.Helpers.HideSkinPicker()
end)

local ROUTES = {
    { "Apply", function(f) f.apply:__fire("OnClick") end },
    { "the gear", function(f) f.settings:__fire("OnClick") end },
    { "the close control", function(f) f.close:__fire("OnClick") end },
    { "Escape", function(f) f:Hide(); f:__fire("OnHide") end },   -- what UISpecialFrames does
    { "O.HideSkinPicker", function(_, NS) NS.Helpers.HideSkinPicker() end },
    { "NS.HideSkinPicker (the stand-down's and a profile event's)", function(_, NS) NS.HideSkinPicker() end },
}

for _, route in ipairs(ROUTES) do
    test("skin picker preview: " .. route[1] .. " puts test mode back off", function()
        local NS = fresh()
        local f = open(NS)
        assertTrue(testOn(NS))
        route[2](f, NS)
        assertFalse(f:IsShown(), route[1] .. " did not close the picker")
        assertRestored(NS, route[1])
    end)
end

test("skin picker preview: an eye-off then a close leaves it off; an eye-on then a close turns it off", function()
    local NS = fresh()
    local f = open(NS)
    f.preview:__fire("OnClick")
    f.close:__fire("OnClick")
    assertRestored(NS, "eye off, then close")
    f = open(NS)
    f.preview:__fire("OnClick")
    f.preview:__fire("OnClick")
    assertTrue(testOn(NS))
    f.close:__fire("OnClick")
    assertRestored(NS, "eye off and on, then close")
end)

test("skin picker preview: a HUD the player has up is left alone, and so is its close", function()
    local NS = fresh()
    NS.Hud.Show()
    local f = open(NS)
    assertFalse(NS.Preview.IsActive(), "a shown HUD must not be put into test mode")
    assertFalse(f.preview.lit, "the eye is dimmed")
    f.close:__fire("OnClick")
    assertTrue(NS.Hud.IsShown(), "the player's HUD stays up after the close")
    assertFalse(NS.Preview.IsActive())
    NS.Hud.Hide()
end)

test("skin picker preview: test mode on at open, turned off by the eye, is on again after the close", function()
    local NS = fresh()
    NS.ToggleTestMode()
    assertTrue(testOn(NS))
    local f = open(NS)
    assertTrue(f.preview.lit)
    f.preview:__fire("OnClick")
    assertFalse(NS.Preview.IsActive(), "the eye did not turn the player's test mode off")
    f.close:__fire("OnClick")
    assertTrue(testOn(NS), "the close did not put the player's test mode back on")
    NS.ToggleTestMode()
end)

test("skin picker preview: a playing sim is never stopped or switched by the eye", function()
    -- red under: an enter that calls NS.ToggleTestMode() bare while the sim plays (its toggle reads the
    -- sim as on and writes test mode off, ending the sim).
    local NS = fresh()
    NS.StartSim()
    assertEqual(NS.Preview.Mode(), "sim", "the sim did not start")
    local f = open(NS)
    f.preview:__fire("OnClick")
    assertEqual(NS.Preview.Mode(), "sim", "the eye touched the sim")
    f.close:__fire("OnClick")
    assertEqual(NS.Preview.Mode(), "sim", "the close touched the sim")
    NS.Preview.Stop()
end)

test("skin picker preview: in combat the eye's start is refused and the close moves nothing", function()
    local NS, M = fresh()
    local f = open(NS)
    f.preview:__fire("OnClick")
    assertFalse(NS.Preview.IsActive())
    M.__inCombat = true
    M.__resetPrinted()
    local ok, err = pcall(function()
        f.preview:__fire("OnClick")
        assertFalse(NS.Preview.IsActive(), "test mode started in combat")
        assertFalse(f.preview.lit, "a refused start leaves the eye dimmed")
        f.close:__fire("OnClick")
        assertFalse(NS.Preview.IsActive(), "the close started test mode")
    end)
    M.__inCombat = false
    if not ok then error(err, 0) end
end)
