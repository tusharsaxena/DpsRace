local _, NS = ...
-- settings/History.lua — the History page (spec §6.3): Runs to keep (0 = never prune), how many runs
-- are stored, and Delete all runs (asks first).

local L = NS.L
local PAGE = "history"
local GROUP = L["History"]
local POPUP = "DPSRACE_DELETE_ALL_RUNS"
-- Spec §7: a run is about 1 to 1.5 KB of SavedVariables; the page quotes the upper figure.
local KB_PER_RUN = 1.5

local History = {}
NS.History = History

local function storedCount()
    local runs = NS.db and NS.db.global and NS.db.global.runs
    local n = 0
    if type(runs) == "table" then for _ in pairs(runs) do n = n + 1 end end
    return n
end

--- "Stored now: 142 runs (about 213 KB of saved variables)."
function History.StoredLine()
    local n = storedCount()
    return L["Stored now: %d runs (about %d KB of saved variables)."]:format(n, math.floor(n * KB_PER_RUN + 0.5))
end

-- A run being raced or waiting for its result is the race's (spec §4.5): deleting it under the race
-- would leave the engine holding a run the store no longer has.
local function raceBusy()
    local state, S = NS.Race.State(), NS.Race.STATE
    return state == S.ARMED or state == S.RUNNING or state == S.STOPPING
end

--- Delete every stored run now (the popup's accept). Refused while a race is on.
--- @return number removed
function History.DeleteAll()
    if raceBusy() then
        NS.Print(L["Finish or cancel the race first."])
        return 0
    end
    local n = NS.Recorder.DeleteAll()
    NS.Print(L["Deleted %d runs."]:format(n))
    return n
end

--- The page's Delete all runs button: asks first, through the one popup.
function History.ConfirmDeleteAll()
    if raceBusy() then
        NS.Print(L["Finish or cancel the race first."])
        return false
    end
    StaticPopup_Show(POPUP)
    return true
end

StaticPopupDialogs[POPUP] = {
    text         = L["Delete every stored run? Your personal bests go with them. This cannot be undone."],
    button1      = L["Delete"],
    button2      = L["Cancel"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function() History.DeleteAll() end,
}

-- Runs to keep is read at login and after each saved run (spec §7); lowering it never deletes on the
-- spot, so a slip of the slider costs nothing until the player races again.
NS.RegisterSchemaRows({
    { path = "global.history.keep", page = PAGE, group = GROUP, subgroup = L["Storage"], type = "number",
      min = 0, max = 10000, step = 1, label = L["Runs to keep"], default = NS.defaults.global.history.keep,
      tooltip = L["0 keeps every run (the default). Above 0, the oldest runs are removed first, at login and after each saved run, and a run that holds a personal best is always kept. 0 to 10000."] },
})

-- After the group's rows: the stored count, then the danger zone (a heading of its own, since the tab
-- now mixes a slider with an act: options-ui-§13).
local function afterHistory(ctx)
    local H = NS.Helpers
    H.TextRow(ctx, History.StoredLine())
    H.Section(ctx, L["Danger zone"])
    H.InlineButtonPair(ctx, {
        text    = L["Delete all runs\226\128\166"],
        tooltip = L["Asks for confirmation. Personal bests go with them."],
        onClick = function() History.ConfirmDeleteAll() end,
    })
end

NS.RegisterTabbedPage({
    key             = PAGE,
    title           = L["History"],
    panelName       = "DpsRaceHistoryPanel",
    defaultsTooltip = L["Restore Runs to keep to its addon default. Stored runs are not touched."],
    afterGroup      = { [GROUP] = afterHistory },
})

-- The stored count repaints when the store changes; a hidden page is only flagged, and repaints on
-- its next show (the library's RefreshPanel).
local function repaint()
    local ctx = NS.pageCtx[PAGE]
    if ctx and NS.Helpers.RefreshPanel then NS.Helpers.RefreshPanel(ctx, true) end
end

do
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.RUNS_CHANGED, repaint)
        bus:RegisterMessage(NS.MSG.RUN_SAVED, repaint)
    end
end
