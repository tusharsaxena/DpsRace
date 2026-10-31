local addonName, NS = ...
-- settings/General.lua — the General page (its first tab is `Master controls`, options-ui-§15, then
-- `New-best toast` (#5), the library's Skin tab (skinning-§3), and its last `Keybindings`,
-- options-ui-§20) and the landing page's spec, NS.LANDING (options-ui-§5).

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
        NS.ResultsTimeline.ResetPosition()
        NS.ResultsGear.ResetPosition()
        NS.BestToast.ResetPosition()
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
        NS.ResultsTimeline.ApplyScale()
        NS.ResultsGear.ApplyScale()
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

-- ── New-best toast ── (#5, modules/BestToast.lua) the alert for a race that sets a new best: on or
-- off and its sound on the first line, then how long it stays and its scale; *Test toast* after the
-- rows. Duration and sound are read as each toast shows, so they need no reaction; the scale
-- re-anchors a shown toast. Its place is test mode's (drag it there), stored outside the seam.
local TOAST = L["New-best toast"]
local TD = D.toast
NS.RegisterSchemaRows({
    { path = "toast.enabled", page = PAGE, group = TOAST, subgroup = TOAST, type = "bool",
      label = L["Show a toast for a new best"], default = TD.enabled,
      tooltip = L["When a race sets a new personal best on its board (spec, dummy and length), a toast near the top of the screen says by how much, whether or not the HUD is open. A board's first run has nothing to beat and shows none. Test mode shows a sample you can drag into place."],
      onChange = function() NS.BestToast.Sync() end },
    { path = "toast.sound", page = PAGE, group = TOAST, subgroup = TOAST, type = "bool",
      label = L["Play a sound"], default = TD.sound,
      tooltip = L["Play an alert sound as the toast appears."] },
    { path = "toast.duration", page = PAGE, group = TOAST, subgroup = TOAST, type = "number",
      min = 3, max = 30, step = 1, label = L["Toast duration (seconds)"], default = TD.duration, startsLine = true,
      tooltip = L["How long the toast stays before it closes by itself. It waits while the pointer is over it, and closes at once on its X or a right-click. 3 to 30."] },
    { path = "toast.scale", page = PAGE, group = TOAST, subgroup = TOAST, type = "number",
      min = 0.5, max = 2.0, step = 0.05, label = L["Toast scale"], default = TD.scale,
      tooltip = L["The toast's size. It grows and shrinks about the place you dragged it to. 0.5 to 2.0."],
      onChange = function() NS.BestToast.Refresh() end },
})

-- ── Skin ── (skinning-§2/§3, core/SkinSetup.lua) the skin this addon wears, per profile. The tab is
-- the library's O.AppearanceTab, which draws every row below itself (its choice grids, the Scope's
-- check boxes, the Font and texture dropdowns), so each row carries `skipRender`; they stay schema
-- rows so the defaults resolve, every reset reaches them, and `/dr get|set skin.skin` validates
-- against `values`. Their group is the tab's key, so the tab takes the group's place in the strip:
-- after New-best toast, before Keybindings.
--
-- Each onChange applies ONLY its own half (core/SkinSetup.lua says why): the tab and another addon's
-- "Copy to every Ka0s addon" call Skin:SetChoice before they write, so the write is a no-op, and a
-- bare `/dr set` still repaints.
local SKIN_TAB = H.AppearanceTab({ owner = addonName, get = NS.SkinChoice, set = NS.WriteSkinChoice })
local SKIN = SKIN_TAB.key
local SD = D.skin

--- A validator for a row whose value is one of `options`' values.
local function oneOf(options)
    return function(v)
        for _, o in ipairs(options) do if o.value == v then return true end end
        return false
    end
end

NS.RegisterSchemaRows({
    { path = "skin.source", page = PAGE, group = SKIN, type = "string", skipRender = true,
      label = L["Skin source"], default = SD.source, values = NS.SKIN_SOURCE_OPTIONS,
      validate = oneOf(NS.SKIN_SOURCE_OPTIONS),
      tooltip = L["Where this addon's look comes from: the Ka0s skin chosen below, or EllesmereUI."],
      onChange = function(v) NS.ApplySkinChoice(v, nil) end },
    { path = "skin.skin", page = PAGE, group = SKIN, type = "string", skipRender = true,
      label = L["Skin"], default = SD.skin, values = NS.SKIN_OPTIONS, validate = oneOf(NS.SKIN_OPTIONS),
      tooltip = L["The Ka0s skin this addon wears. Changes every window and panel right away."],
      onChange = function(v) NS.ApplySkinChoice(nil, v) end },
    -- The Scope's two exceptions (LibKa0s-Skin-1.0 minor 5).
    { path = "skin.ignorePanel", page = PAGE, group = SKIN, type = "bool", skipRender = true,
      label = L["Ignore settings panel"], default = SD.ignorePanel,
      tooltip = L["Keep this addon's settings panel in the game's own look. Its windows still wear the skin."],
      onChange = function(v) NS.ApplySkinIgnore(v, nil) end },
    { path = "skin.ignoreFonts", page = PAGE, group = SKIN, type = "bool", skipRender = true,
      label = L["Ignore fonts"], default = SD.ignoreFonts,
      tooltip = L["Keep every font in this addon as the game draws it. The skin still colors the text."],
      onChange = function(v) NS.ApplySkinIgnore(nil, v) end },
    -- The Font and texture overrides (LibKa0s-Skin-1.0 minor 6): free text, not a list of `values`,
    -- because a media pack may register its keys after this file loads and `/dr set` takes any key;
    -- "" is the skin's own.
    { path = "skin.font", page = PAGE, group = SKIN, type = "string", skipRender = true,
      label = L["Font"], default = SD.font,
      tooltip = L["The font this addon's text uses, over the skin's own. Empty keeps the skin's."],
      onChange = function(v) NS.ApplySkinOverride(v, nil) end },
    { path = "skin.texture", page = PAGE, group = SKIN, type = "string", skipRender = true,
      label = L["Texture"], default = SD.texture,
      tooltip = L["The texture this addon's bars use, over the skin's own. Empty keeps the skin's."],
      onChange = function(v) NS.ApplySkinOverride(nil, v) end },
    -- The Font outline (LibKa0s-Skin-1.0 minor 9, ruling D-06), drawn by the tab as its "Font outline"
    -- dropdown: where the skin outlines this addon's text. The library's three modes, in its order, so
    -- `/dr set skin.outline` validates against them.
    { path = "skin.outline", page = PAGE, group = SKIN, type = "string", skipRender = true,
      label = L["Font outline"], default = SD.outline, values = NS.SKIN_OUTLINE_OPTIONS,
      validate = oneOf(NS.SKIN_OUTLINE_OPTIONS),
      tooltip = L["Where the skin outlines this addon's text: all of it, its HUD text only, or nowhere."],
      onChange = function(v) NS.ApplySkinOutline(v) end },
    -- The first-run skin picker's memory: set when the picker closes, so it shows once per profile.
    -- Drawn by nothing; a reset puts it back to false.
    { path = "skin.pickerSeen", page = PAGE, group = SKIN, type = "bool", skipRender = true,
      label = L["Skin picker seen"], default = SD.pickerSeen,
      tooltip = L["Whether the first-run skin picker was closed on this profile."] },
})

-- After the toast's rows: a sample toast, run as a real one is (one-shot, options-ui-§21's *Test <thing>*).
local function afterToast(ctx)
    H.InlineButtonPair(ctx, {
        text    = L["Test toast"],
        tooltip = L["Show a sample new-best toast with the duration, sound and scale above. Drag it to place it while it shows; Reset position (General > Master controls) puts it back."],
        onClick = function() NS.BestToast.Test() end,
    })
end

-- ── The page ────────────────────────────────────────────────────────────────────────────────────
local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
    local ctx = H.CreatePanel("DpsRaceGeneralPanel", L["General"], {
        pageKey         = PAGE,
        defaultsButton  = true,
        -- A page reset (options-ui-§13). Defaults never reaches a key: the game keeps them, not the
        -- profile (options-ui-§20).
        defaultsTooltip = L["Restore every General setting on this profile to its addon default: Master controls, the new-best toast and the skin."]
            .. " " .. H.KEYBINDS_UNCHANGED,
    })
    ctx.panel.defaultsOnClick = function() H.RestoreDefaults(PAGE, ctx) end
    -- Every page renders through the tabbed renderer, a one-tab page included (options-ui-§13). The
    -- Keybindings tab is a host tab the library draws from NS.BINDINGS; with no `before` it is the
    -- strip's last, after every schema tab (options-ui-§20).
    -- The Skin tab is keyed by its rows' group, so it takes that group's place, before Keybindings.
    local tabs = { SKIN_TAB, H.KeybindingsTab({ bindings = NS.BINDINGS }) }
    H.SetRenderer(ctx, function(c)
        H.ClearScroll(c)
        H.RenderTabbedSchema(c, PAGE, { [H.MASTER_GROUP] = masterTail, [TOAST] = afterToast }, nil, { tabs = tabs })
    end)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["General"])
end

NS.RegisterOptionsPage(PAGE, L["General"], build)

