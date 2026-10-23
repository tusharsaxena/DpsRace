local _, NS = ...
-- settings/General.lua — the General page (its first tab is `Master controls`, options-ui-§15) and
-- the landing page's spec, NS.LANDING (options-ui-§5).

local L = NS.L
local H = NS.Helpers
local D = NS.defaults.profile
local PAGE = "general"

-- ── The landing page ────────────────────────────────────────────────────────────────────────────
-- Logo, tagline and the command list; the library draws all three pool-safely (options-ui-§19).
NS.LANDING = {
    logo     = NS.Constants.LOGO,
    notes    = function() return NS.Meta("Notes") or "" end,
    sections = { {
        heading = L["Slash Commands"],
        rows    = function() return NS.Slash:LandingRows() end,   -- from NS.COMMANDS
    } },
}

-- ── The global reset ────────────────────────────────────────────────────────────────────────────
-- options-ui-§12's one wording, verbatim. The run history is account-wide (db.global), so a profile
-- reset never reaches it; the profile is all the popup speaks of.
StaticPopupDialogs["DPSRACE_RESET_ALL"] = {
    text         = L["Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded — your other profiles are not affected."],
    button1      = L["Yes"],
    button2      = L["No"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function()
        NS.Helpers.RestoreAllDefaults()
        NS.Print(L["All settings reset to defaults."])
    end,
}

--- `Reset all settings` and `/dr resetall` both ask first, through this one popup.
function NS.ShowResetAll()
    return StaticPopup_Show("DPSRACE_RESET_ALL")
end

-- ── Master controls ─────────────────────────────────────────────────────────────────────────────
-- Composed from ONE declaration, the canonical rows in canonical order (options-ui-§15): every row
-- this addon has the state for. No Master alpha: the HUD has no opacity setting of its own.
local DEBUG_CONSOLE_PATH = "state.debugConsole"
local TEST_MODE_PATH = "state.testMode"

local masterRows, masterTail = H.MasterControls({
    page             = PAGE,
    addonName        = NS.BRAND,          -- the Enable row reads "Enable Ka0s DPS Race"
    omit             = { alpha = true },
    debugConsolePath = DEBUG_CONSOLE_PATH,
    minimapPath      = NS.MINIMAP_PATH,
    testModePath     = TEST_MODE_PATH,
    defaults         = {
        enabled    = D.enabled,
        visibility = D.visibility,
        scale      = D.scale,
        locked     = D.locked,
    },
    onResetPosition  = function()
        NS.Hud.ResetPosition()
        NS.Results.ResetPosition()
    end,
    onResetAll       = function() NS.ShowResetAll() end,
})

-- Rows whose storage is not a profile path: the console (session), test mode (session) and the
-- minimap button (LibDBIcon's own `hide`, inverted -- launcher-§3).
local ownStorage = {
    [NS.MINIMAP_PATH] = {
        get = function() return NS.Launcher:IsShown() end,
        set = function(shown) NS.Launcher:SetShown(shown and true or false) end,
    },
    [TEST_MODE_PATH] = {
        get = function() return NS.Preview.IsActive() end,
        set = function(on)
            if on then NS.Preview.Start() else NS.Preview.Stop() end
        end,
    },
}
do
    local console = NS.DebugLog:ConsoleCheckbox()
    ownStorage[DEBUG_CONSOLE_PATH] = { get = console.get, set = console.set }
end

-- Each composed row's reaction, attached here because the composer cannot know them.
local reactions = {
    enabled    = function(v) NS.ApplyEnabled(v) end,
    visibility = function() NS.OnVisibilityChanged() end,
    scale      = function()
        NS.Hud.Refresh()
        NS.Results.Refresh()
    end,
    locked     = function(v) NS.Hud.SetLocked(v) end,
}

for _, row in ipairs(masterRows) do
    row.onChange = reactions[row.path] or row.onChange
    local own = ownStorage[row.path]
    if own then row.get, row.set = own.get, own.set end
    -- options-ui-§15: Test mode "is ended by Reset all settings (the row declares default = false)".
    -- The composer (Compose minor 7) emits the row without one, so the reset's session-row walk
    -- would skip it; the host stamps it here.
    if row.path == TEST_MODE_PATH and row.default == nil then row.default = false end
end
NS.RegisterSchemaRows(masterRows)

-- ── Race HUD ────────────────────────────────────────────────────────────────────────────────────
-- Its own tab after Master controls (spec §6.3 General: show the HUD on arm only, or always). The HUD's
-- scale and lock are the Master rows above: the HUD is the addon's positionable display.
local SHOW_MODES = { onArm = true, always = true }

NS.RegisterSchemaRows({
    { path = "hud.showMode", page = PAGE, group = L["Race HUD"], type = "string",
      label = L["Show the race HUD"], default = NS.defaults.profile.hud.showMode,
      values = {
          { value = "onArm", text = L["When a race is armed"] },
          { value = "always", text = L["Always"] },
      },
      validate = function(v) return SHOW_MODES[v] == true end,
      tooltip = L["When a race is armed: the HUD opens when you arm a race or a result arrives, and closes again when that race is over. Always: it is open from login."],
      -- "always" opens it now; back to "onArm" leaves an open window open, as a player-opened one is.
      onChange = function(v)
          if v == "always" then NS.Hud.Show() end
      end },
})

-- ── The page ────────────────────────────────────────────────────────────────────────────────────
local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
    local ctx = H.CreatePanel("DpsRaceGeneralPanel", L["General"], {
        pageKey         = PAGE,
        defaultsButton  = true,
        defaultsTooltip = L["Restore every General setting on this profile to its addon default."],
    })
    ctx.panel.defaultsOnClick = function() H.RestoreDefaults(PAGE, ctx) end
    -- Every page renders through the tabbed renderer, a one-tab page included (options-ui-§13).
    H.SetRenderer(ctx, function(c)
        H.ClearScroll(c)
        H.RenderTabbedSchema(c, PAGE, { [H.MASTER_GROUP] = masterTail })
    end)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["General"])
end

NS.RegisterOptionsPage(PAGE, L["General"], build)

