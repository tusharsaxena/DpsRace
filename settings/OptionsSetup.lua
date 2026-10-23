local addonName, NS = ...
-- settings/OptionsSetup.lua — the LibKa0s-Options-1.0 descriptor; NS.Helpers IS the library instance.

--- Named ONCE and enforced twice -- by the library through skipRestoreAll, and by the stub's reset.
--- The global reset IS a profile reset (options-ui-§12), so the walk keeps only what a profile reset
--- cannot reach: the session rows, whose storage is their own set(). The Minimap row is vetoed out of
--- every reset (launcher-§3).
local function vetoedFromResetAll(row)
    if row.page == "profiles" or row.path == NS.MINIMAP_PATH then return true end
    return not row.sessionOnly
end

local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)

local descriptor = {
    parentTitle   = NS.BRAND,
    mainPanelName = "DpsRaceMainPanel",
    -- The FOLDER name, never a display label: the route to the library's own art (options-ui-§1).
    addonName     = addonName,

    get          = function(path) return NS.GetSetting(path) end,
    set          = function(path, value) return NS.SetByPath(path, value) end,   -- the single write seam
    applyDefault = function(row) return NS.ApplyDefault(row) end,
    allRows      = function() return NS.Schema end,
    rowsForPage  = function(pageKey) return NS.SchemaForPage(pageKey) end,

    skipRestoreAll = vetoedFromResetAll,
    resetProfile   = function()
        local db = NS.db
        if not (db and db.ResetProfile) then return false end
        db:ResetProfile()
        return true
    end,
    profilesPage = true,
    bulkBegin = function(act, scope) NS.Bulk.Begin(act, scope) end,
    bulkEnd   = function(act, scope, count, err, info) NS.Bulk.End(act, scope, count, err, info) end,

    colorDecode = function(c)
        c = type(c) == "table" and c or {}
        return c.r or 1, c.g or 1, c.b or 1, c.a or 1
    end,
    colorEncode = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end,

    -- The landing body is the LIBRARY's (options-ui-§5, §19): NS.LANDING is declared in
    -- settings/General.lua and read at render time.
    buildMain     = function(ctx) NS.Helpers.BuildLandingPage(ctx, NS.LANDING) end,
    getLSM        = function() return LibStub and LibStub("LibSharedMedia-3.0", true) end,
    -- C_Timer.After, NOT the addon's AceTimer: stand-down's CancelAllTimers would cancel a pending
    -- drag-throttle callback, leaving the widget's own `armed` flag stuck true until /reload. The
    -- panel stays live while disabled; the library keeps its own flag and ignores the return.
    scheduleTimer = function(fn, delay) C_Timer.After(delay, fn) end,
    validate      = function() NS.ValidateSchema() end,
    onAceGUI      = function(AceGUI) NS.AceGUI = AceGUI end,
    print         = function(line) NS.Print(line) end,
    -- The combat lock's refusals are the library's `Cfg` lines (debug-logging-§4).
    debug         = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,
}

if not lib then
    -- The LOAD-COMPLETING stub (options-ui-§1): every member a page file touches at load, the global
    -- reset kept real, everything else a no-op or one honest line. The composers are HOLLOW and
    -- answer {} (anti-pattern #73); no widget maker, flow engine or LAYOUT constant is copied here.
    local MISSING = NS.LIBKA0S_MISSING .. ", so the settings panel is unavailable."
    local Helpers = {}
    NS.Helpers = Helpers
    Helpers.MASTER_GROUP   = "Master controls"
    Helpers.LSMValues      = function() return function() return {} end end
    Helpers.MasterControls = function() return {}, function() end end
    Helpers.ColorPair, Helpers.FontGroup = function() return {} end, function() return {} end
    Helpers.BorderGroup, Helpers.BarGroup = function() return {} end, function() return {} end
    Helpers.RestoreAllDefaults = function()
        NS.Bulk.Run("reset", "all", function(info)
            for _, row in ipairs(NS.Schema) do
                if not vetoedFromResetAll(row) then NS.ApplyDefault(row) end
            end
            if descriptor.resetProfile() then info.profileReset = true end
        end)
    end
    for _, name in ipairs({
        "CreatePanel", "EnsureDefaultsButton", "EnsureScroll", "ClearScroll", "Section", "AddSpacer",
        "TextRow", "BuildLandingPage", "AttachTooltip", "InlineButtonPair", "RenderField", "RenderRows",
        "RenderSchema", "RenderGrid", "SessionCheckbox", "SetRenderer", "RefreshAllPanels",
        "RefreshScalars", "RefreshPanel", "RestoreDefaults", "PatchAlwaysShowScrollbar",
        "RegisterOptionsPage", "CreateOptionsPanel", "OpenOptionsPanel", "SetChromeHeight", "TabStrip",
        "PageBanner", "RenderTabbedSchema", "SelectTab", "ChoiceGrid", "IdInput", "IdList", "NavRail",
        "Drawer", "Relayout",
    }) do
        Helpers[name] = function() end
    end
    Helpers.ResolveId         = function() return nil end
    Helpers.UnnamedCandidates = function() return nil end
    Helpers.ID_NAME_HINT      = {}
    NS.RegisterOptionsPage = function() end
    NS.CreateOptionsPanel  = function() NS.Print(MISSING) end
    NS.OpenOptionsPanel    = NS.CreateOptionsPanel
    return
end

-- The LSM30 border widget's backdrop, patched once for every Ka0s addon (options-ui-§1).
lib.__PatchLSM30Border()

-- NS.Helpers IS the instance, decorated in place -- never a copy-across.
NS.Helpers = lib:New(descriptor)
local Helpers = NS.Helpers

-- The three entry points the rest of the addon calls.
NS.RegisterOptionsPage = function(key, name, builder) Helpers.RegisterOptionsPage(key, name, builder) end
NS.CreateOptionsPanel  = function() Helpers.CreateOptionsPanel() end
NS.OpenOptionsPanel    = function() Helpers.OpenOptionsPanel() end   -- the `config` verb
