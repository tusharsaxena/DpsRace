local _, NS = ...
-- modules/Results.lua — the Results window's shell (spec §6.2, mockup screens 08-09): the window, its
-- title bar, the Runs / Bests tab strip with lazily built tabs, where the run detail sits, the footer,
-- and the window's public surface (Show, Hide, Toggle, ShowRun, ShowTab). The tabs are
-- modules/Results_Runs.lua and modules/Results_Bests.lua; the detail pane modules/Results_Detail.lua;
-- the shared list modules/Results_Table.lua.
--
-- THE WINDOW is a plain, non-secure frame (standalone-windows): skinned through NS.ApplySkin, closed
-- through NS.MakeCloseButton, in UISpecialFrames, clamped, movable by its title bar and resizable
-- (1040x560 by default, 760x420 at least), with its position and size in db.profile.windows.results.
-- Master scale acts on it as on the HUD; Lock frame does not (it is the HUD's, the positionable
-- display), and neither does General visibility: this is a browser the player opens on purpose.
-- Built on first show; each tab is built the first time it is shown.
--
-- WIDE OR NARROW. From 900px wide the detail sits beside the list (screen 08); below it the detail
-- replaces the list, with a back control (spec §6.2).
--
-- WHAT RUNS. Nothing while hidden but its bus receiver: RUN_SAVED and RUNS_CHANGED redraw the shown
-- tab (a hidden one redraws in full on its next show), SETTINGS_CHANGED redraws the footer. No game
-- event, no timer, no OnUpdate.
-- The receiver is a target of this module's own, so the latch drops it at stand-down.

local Results = { wanted = false }
NS.Results = Results

local L = NS.L

Results.WIDTH = NS.defaults.profile.windows.results.width
Results.HEIGHT = NS.defaults.profile.windows.results.height
Results.MIN_WIDTH, Results.MIN_HEIGHT = 760, 420
Results.NARROW = 900            -- below this width the detail replaces the list
Results.DETAIL_WIDTH = 360      -- the detail pane's width when it sits beside the list
Results.FRAME_NAME = "DpsRaceResults"
Results.TABS = { "runs", "bests" }

local HEADER_H, TAB_H, FOOTER_H = 28, 30, 24
local C = NS.ResultsTable.COLORS

local ui                 -- the built window
local tab = "runs"       -- the tab shown
local selected           -- the run id the detail shows
local detailOpen = false -- narrow windows: the detail replaces the list
local hiding = false     -- true while the addon hides the frame itself

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Results", fmt, ...) end
end

-- ── stored geometry ─────────────────────────────────────────────────────────────────────────────

local function store()
    local p = NS.db and NS.db.profile
    if not p then return nil end
    p.windows = p.windows or {}
    p.windows.results = p.windows.results or {}
    return p.windows.results
end

local function storedSize()
    local w = store() or {}
    return math.max(Results.MIN_WIDTH, tonumber(w.width) or Results.WIDTH),
        math.max(Results.MIN_HEIGHT, tonumber(w.height) or Results.HEIGHT)
end

local function savePosition()
    local w = store()
    if not (w and ui) then return end
    local point, _, relativePoint, x, y = ui.frame:GetPoint(1)
    if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
    w.point, w.relativePoint = point, type(relativePoint) == "string" and relativePoint or point
    w.x, w.y = math.floor(x + 0.5), math.floor(y + 0.5)
end

local function saveSize(width, height)
    local w = store()
    if not w then return end
    if type(width) == "number" then w.width = math.floor(width + 0.5) end
    if type(height) == "number" then w.height = math.floor(height + 0.5) end
end

-- ── the parts ───────────────────────────────────────────────────────────────────────────────────

local function run(id)
    return id and NS.Recorder.Get(id) or nil
end

local function canShare()
    return NS.Share ~= nil and type(NS.Share.Prompt) == "function"
end

local function share(r)
    if r and canShare() then NS.Share.Prompt(r) end
end

local layout, renderTab, renderDetail

local function selectRun(r)
    selected = r and r.id or nil
    detailOpen = selected ~= nil
    renderDetail()
    if ui and ui.panes.runs then ui.panes.runs.list:SetSelected(selected) end
    layout()
end

local function buildTab(name)
    local pane = ui.panes[name]
    if pane then return pane end
    if name == "runs" then
        pane = NS.ResultsRuns.Build(ui.body, {
            select = selectRun, share = share, selected = function() return selected end,
        })
    else
        pane = NS.ResultsBests.Build(ui.body, {
            open = function(r) Results.ShowRun(r.id) end, share = share,
        })
    end
    ui.panes[name] = pane
    debug("tab %s built", name)
    return pane
end

local function tabButton(name, label, i)
    local b = CreateFrame("Button", nil, ui.frame)
    b:SetSize(80, TAB_H)
    b:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 8 + (i - 1) * 84, -HEADER_H)
    b.label = NS.ResultsTable.Text(b, 12, C.dim, "CENTER")
    b.label:SetAllPoints(b)
    b.label:SetText(label)
    b.underline = b:CreateTexture(nil, "OVERLAY")
    b.underline:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
    b.underline:SetHeight(2)
    b.underline:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 6, 0)
    b.underline:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 0)
    b:SetScript("OnClick", function() Results.ShowTab(name) end)
    ui.tabs[name] = b
end

local function buildChrome(f)
    f.title = NS.ResultsTable.Text(f, 13, C.gold)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    f.title:SetText(L["DPS Race \226\128\148 Results"])
    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetHeight(1)
    f.divider:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -HEADER_H)
    f.divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -HEADER_H)
    ui.close = NS.MakeCloseButton(f, function() Results.Hide() end)
    if ui.close then ui.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5) end
    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    drag:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -28, -HEADER_H)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() f:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        savePosition()
    end)
    ui.drag = drag
    tabButton("runs", L["RUNS"], 1)
    tabButton("bests", L["BESTS"], 2)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(0.24, 0.24, 0.27, 0.85)
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -HEADER_H - TAB_H)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -HEADER_H - TAB_H)
end

local function buildFooter(f)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(0.24, 0.24, 0.27, 0.85)
    line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, FOOTER_H)
    line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, FOOTER_H)
    ui.footLeft = NS.ResultsTable.Text(f, 10, C.dim)
    ui.footLeft:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 7)
    ui.footLeft:SetText(L["Click a row for details \194\183 double-click to share"])
    ui.footRight = NS.ResultsTable.Text(f, 10, C.dim, "RIGHT")
    ui.footRight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 7)
end

local onHide

local function onResized(width, height)
    if type(width) == "number" then ui.width = math.max(Results.MIN_WIDTH, width) end
    if type(height) == "number" then ui.height = math.max(Results.MIN_HEIGHT, height) end
    layout()
end

local function applyPlacement()
    local f, w = ui.frame, store() or {}
    ui.width, ui.height = storedSize()
    f:ClearAllPoints()
    f:SetPoint(w.point or "CENTER", UIParent, w.relativePoint or "CENTER", w.x or 0, w.y or 0)
    f:SetSize(ui.width, ui.height)
end

local function ensureWindow()
    if ui then return ui end
    local f = CreateFrame("Frame", Results.FRAME_NAME, UIParent, "BackdropTemplate")
    ui = { frame = f, tabs = {}, panes = {} }
    f:Hide()
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetToplevel(true)
    buildChrome(f)
    buildFooter(f)
    ui.body = CreateFrame("Frame", nil, f)
    ui.body:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -(HEADER_H + TAB_H + 1))
    ui.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, FOOTER_H + 1)
    ui.detail = NS.ResultsDetail.Build(ui.body, {
        back = function() Results.Back() end,
        share = share,
        delete = function(r) Results.ConfirmDelete(r.id) end,
        saveNote = function(r, text) return Results.SetNote(r.id, text) end,
        canShare = canShare,
    })
    NS.ApplySkin(f)
    f:SetScript("OnHide", function() onHide() end)
    -- Escape closes it with the standard close stack (standalone-windows).
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, Results.FRAME_NAME) end
    NS.MakeResizable(f, {
        minWidth = Results.MIN_WIDTH, minHeight = Results.MIN_HEIGHT,
        onResize = onResized, onResizeStop = saveSize,
    })
    applyPlacement()
    debug("window built")
    return ui
end

-- ── layout and drawing ──────────────────────────────────────────────────────────────────────────

--- "wide" (the detail beside the list) or "narrow" (the detail in its place), for the width now.
function Results.Mode()
    local width = ui and ui.width or storedSize()
    return width >= Results.NARROW and "wide" or "narrow"
end

local function bodySize()
    return ui.width - 2, ui.height - HEADER_H - TAB_H - FOOTER_H - 2
end

local function layoutRuns(pane, width, height)
    local detail, mode = ui.detail, Results.Mode()
    detail.frame:ClearAllPoints()
    if mode == "wide" then
        local dw = math.min(Results.DETAIL_WIDTH, math.floor(width * 0.38))
        pane.frame:Show()
        pane:Layout(width, height, width - dw)
        local barH = pane:BarHeight()
        detail.frame:SetPoint("TOPRIGHT", ui.body, "TOPRIGHT", 0, -barH)
        detail.frame:SetSize(dw, height - barH)
        detail.frame:Show()
        detail:Layout(dw, height - barH, false)
        return
    end
    pane.frame:SetShown(not detailOpen)
    detail.frame:SetShown(detailOpen)
    if detailOpen then
        detail.frame:SetPoint("TOPLEFT", ui.body, "TOPLEFT", 0, 0)
        detail.frame:SetSize(width, height)
        detail:Layout(width, height, true)
    else
        pane:Layout(width, height, width)
    end
end

function layout()
    if not ui then return end
    local width, height = bodySize()
    local pane = ui.panes[tab]
    if not pane then return end
    if tab == "runs" then return layoutRuns(pane, width, height) end
    ui.detail.frame:Hide()
    pane:Layout(width, height)
end

local function paintTabs()
    for _, name in ipairs(Results.TABS) do
        local b, on = ui.tabs[name], name == tab
        local c = on and C.gold or C.dim
        b.label:SetTextColor(c[1], c[2], c[3])
        b.underline:SetShown(on)
        local pane = ui.panes[name]
        if pane then pane.frame:SetShown(on) end
    end
end

local function footer()
    -- GetSetting answers the shipped default itself (settings/Schema.lua); no second literal here.
    local keep = tonumber(NS.GetSetting("global.history.keep"))
    ui.footRight:SetText(keep and keep > 0 and L["Runs to keep: %d"]:format(keep) or L["Runs to keep: 0 (never prune)"])
end

function renderDetail()
    if not ui then return end
    if selected and not run(selected) then selected, detailOpen = nil, false end
    ui.detail:Show(run(selected))
end

function renderTab()
    local pane = buildTab(tab)
    paintTabs()
    pane:Refresh()
    if tab == "runs" then
        renderDetail()
        if selected then pane.list:Reveal(selected) end
    end
    layout()
    footer()
end

local function windowShown()
    return ui ~= nil and ui.frame:IsShown() == true
end

local function hideWindow()
    if windowShown() then
        hiding = true
        ui.frame:Hide()
        hiding = false
    end
    NS.CloseMenu()
end

-- The frame went away by Escape (UISpecialFrames): the player closed it. A frame still shown in its
-- own right was hidden with its parent (Alt-Z), which is not the player closing it.
function onHide()
    NS.CloseMenu()
    if hiding or (ui and ui.frame:IsShown()) then return end
    Results.wanted = false
end

-- ── the public surface ──────────────────────────────────────────────────────────────────────────

--- Whether the window decides to show: wanted, and the addon standing up.
function Results.IsShown()
    return Results.wanted and not NS.IsStoodDown()
end

--- Re-decide and redraw. The one place the frame follows the decision.
function Results.Refresh()
    if not Results.IsShown() then return hideWindow() end
    ensureWindow()
    local scale = tonumber(NS.GetSetting("scale"))
    if scale then ui.frame:SetScale(scale) end
    if not windowShown() then ui.frame:Show() end
    renderTab()
end

function Results.Show()
    Results.wanted = true
    Results.Refresh()
end

function Results.Hide()
    Results.wanted = false
    Results.Refresh()
end

function Results.Toggle()
    if Results.IsShown() then Results.Hide() else Results.Show() end
end

--- Open the window on `name` ("runs" | "bests").
function Results.ShowTab(name)
    if name ~= "runs" and name ~= "bests" then return false end
    if name ~= tab then NS.CloseMenu() end
    tab = name
    Results.Show()
    return true
end

--- Open the window on the Runs tab with `id`'s detail (the HUD's Details and Last result, a Bests
--- row). A run the filters hide still opens; an id no longer stored opens the list alone.
function Results.ShowRun(id)
    selected = run(id) and id or nil
    detailOpen = selected ~= nil
    return Results.ShowTab("runs")
end

--- The narrow window's back control: the list again, the selection kept.
function Results.Back()
    detailOpen = false
    layout()
end

--- The run the detail shows, or nil.
function Results.Selected()
    return selected
end

--- The tab shown.
function Results.Tab()
    return tab
end

--- Back to the default place and size (the Master controls' Reset position).
function Results.ResetPosition()
    local w = store()
    if w then w.point, w.relativePoint, w.x, w.y, w.width, w.height = nil, nil, nil, nil, nil, nil end
    if ui then
        applyPlacement()
        layout()
    end
end

-- ── the acts the detail's buttons run ───────────────────────────────────────────────────────────

StaticPopupDialogs["DPSRACE_DELETE_RUN"] = {
    text         = L["Delete this run? This cannot be undone, and a personal best it holds goes with it."],
    button1      = L["Delete"],
    button2      = L["Cancel"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function(_, data) Results.DeleteRun(data) end,
}

--- Ask before deleting a run (spec §6.2); the popup's Accept deletes it.
function Results.ConfirmDelete(id)
    if not run(id) then return false end
    StaticPopup_Show("DPSRACE_DELETE_RUN", nil, nil, id)
    return true
end

--- Delete a run from the store (Recorder.Delete fires RUNS_CHANGED, which redraws the window).
function Results.DeleteRun(id)
    if selected == id then selected, detailOpen = nil, false end
    return NS.Recorder.Delete(id)
end

--- Store a run's note (trimmed, at most 200 characters) and answer what was stored.
function Results.SetNote(id, text)
    local r = run(id)
    if not r then return nil end
    -- Through Recorder.SetNote, not Save: RUN_SAVED would prune the store for a typed note.
    NS.Recorder.SetNote(id, NS.ResultsDetail.ClampNote(text))
    return r.note
end

--- The lifecycle's stand-down: the window hides (it decides not to show while stood down).
function Results.Suspend()
    hideWindow()
end

--- The stand-up: back on screen if the player had it open.
function Results.Resume()
    Results.Refresh()
end

--- What the window is doing, for the diagnostics report.
function Results.Diagnose()
    local pane = ui and ui.panes[tab]
    return { tab = tab, selected = selected or "none", rows = pane and pane:Count() or 0, mode = Results.Mode() }
end

--- The built window, for the suites (nil until first shown).
function Results.__ui() return ui end

-- ── the store, heard on the bus ─────────────────────────────────────────────────────────────────

-- A hidden window draws nothing: its next show redraws in full.
local function onStoreChanged()
    if windowShown() then renderTab() end
end

do
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.RUN_SAVED, onStoreChanged)
        bus:RegisterMessage(NS.MSG.RUNS_CHANGED, onStoreChanged)
        bus:RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path)
            if windowShown() and path == "global.history.keep" then footer() end
        end)
    end
end
