local addonName, NS = ...
-- core/LauncherSetup.lua — the ONE LibDataBroker launcher, registered twice (minimap button and broker
-- row) through LibKa0s-Launcher-1.0, the two Show-window key-binding buttons (launcher-§6), the
-- Arm or cancel key's button (spec §6.4), and NS.BINDINGS, the table all three are declared in.

local Launcher = LibStub and LibStub("LibKa0s-Launcher-1.0", true)
local L = NS.L

local function minimapTable()
    local db = NS.db
    return db and db.global and db.global.minimap or nil
end

-- The key bindings (launcher-§6). Each button is plain, named, hidden and NOT secure, registered for
-- the down edge only, and its click runs the SAME handler the launcher menu and the slash verb run
-- (core/DpsRace.lua), which refuses through the one hold-aware helper while stood down. The NAMES
-- ARE PERMANENT: the client stores the player's key against them, so a rename unbinds every key.
NS.TOGGLE_HUD_BUTTON     = "DpsRaceToggleHud"
NS.TOGGLE_RESULTS_BUTTON = "DpsRaceToggleResults"
-- The Arm or cancel key (spec §6.4), built the same way: a CLICK binding on a plain named button whose
-- click runs NS.ToggleArm, the handler the slash verbs share.
NS.ARM_TOGGLE_BUTTON     = "DpsRaceArmToggle"
do
    local hud = CreateFrame("Button", NS.TOGGLE_HUD_BUTTON, UIParent)
    hud:RegisterForClicks("AnyDown")
    hud:SetScript("OnClick", function() NS.ToggleHud() end)
    hud:Hide()

    local results = CreateFrame("Button", NS.TOGGLE_RESULTS_BUTTON, UIParent)
    results:RegisterForClicks("AnyDown")
    results:SetScript("OnClick", function() NS.ToggleResults() end)
    results:Hide()

    local arm = CreateFrame("Button", NS.ARM_TOGGLE_BUTTON, UIParent)
    arm:RegisterForClicks("AnyDown")
    arm:SetScript("OnClick", function() NS.ToggleArm() end)
    arm:Hide()
end
-- The ONE bindings table (launcher-§6), in Bindings.xml's order with the Show window key first: the
-- General page's Keybindings tab draws its rows from it (options-ui-§20) and the suite checks
-- Bindings.xml against it. Each command is the CLICK binding on the button above.
local function clickCommand(button) return "CLICK " .. button .. ":LeftButton" end
NS.BINDINGS = {
    { command = clickCommand(NS.TOGGLE_HUD_BUTTON),
      tooltip = L["Shows or hides the race HUD, as the launcher's Show window entry and /dr hud toggle do."] },
    { command = clickCommand(NS.TOGGLE_RESULTS_BUTTON),
      tooltip = L["Shows or hides the Results window, with its run history and insights."] },
    { command = clickCommand(NS.ARM_TOGGLE_BUTTON),
      tooltip = L["Arms a race at the HUD's length, or cancels an armed or running race. A finished race's result is kept."] },
}
-- The category's title is the brand, and it is assigned here at file scope, because the client reads
-- it when it registers the bindings (launcher-§6). The labels' global names hold a space and a
-- colon, so no identifier can spell them: rawset.
rawset(_G, "BINDING_HEADER_DPSRACE", L["Ka0s DPS Race"])
rawset(_G, "BINDING_NAME_" .. NS.BINDINGS[1].command, L["Toggle race HUD"])
rawset(_G, "BINDING_NAME_" .. NS.BINDINGS[2].command, L["Toggle results window"])
rawset(_G, "BINDING_NAME_" .. NS.BINDINGS[3].command, L["Arm or cancel race"])

if not Launcher then
    -- Degrade, never error: no button and no broker row, said once, and the Minimap button row still
    -- reads and writes LibDBIcon's own `hide` key so the setting survives the next healthy load.
    local missing = NS.LIBKA0S_MISSING .. ", so there is no minimap button and no broker plugin."
    local announced = false
    NS.Launcher = {
        Register = function()
            if not announced then
                announced = true
                NS.Print(missing)
            end
            return false
        end,
        IsRegistered = function() return false end,
        Object       = function() return nil end,
        IsShown      = function()
            local t = minimapTable()
            return not (t and t.hide)
        end,
        SetShown     = function(_, shown)
            local t = minimapTable()
            if t then t.hide = not shown end
            return false
        end,
    }
    return
end

NS.Launcher = Launcher:New({
    name    = addonName,                   -- the registration name LibDBIcon keys the position by
    icon    = NS.Constants.LOGO_128,
    label   = L["Ka0s DPS Race"],          -- the brand in plain text, never the TOC Title (launcher-§1)
    minimap = minimapTable,                -- db.global.minimap, shared with the Minimap button row
    -- Left-click ALWAYS opens the settings panel; right-click the options menu (launcher-§2). Each
    -- toggle below calls the same handler its verb or key calls -- never a copy -- and the library
    -- grays every entry but Enabled while the addon is disabled.
    openSettings   = function() NS.OpenOptionsPanel() end,
    isEnabled      = function() return not NS.IsDisabled() end,
    setEnabled     = function(on) NS.RunVerb(on and "enable" or "disable") end,
    isLocked       = function() return NS.GetSetting("locked") == true end,
    toggleLock     = function() NS.ToggleLock() end,
    isTestMode     = function() return NS.Preview ~= nil and NS.Preview.IsActive() == true end,
    toggleTestMode = function() NS.ToggleTestMode() end,
    isWindowShown  = function() return NS.Hud ~= nil and NS.Hud.IsShown() == true end,
    toggleWindow   = function() NS.ToggleHud() end,
    version        = function() return NS.Version() end,
    print          = function(line) NS.Print(line) end,
    debug          = function(tag, message) NS.Debug(tag, "%s", message) end,
    debugAtEnable  = function(tag, message) NS.DebugAtEnable(tag, "%s", message) end,
})
