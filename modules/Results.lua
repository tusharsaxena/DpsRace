local _, NS = ...
-- modules/Results.lua — the Results window's shell (spec §6.2, mockup screens 08-09): the window, its
-- title bar, the Runs / Bests tab strip with lazily built tabs, where the run detail sits, the footer,
-- and the window's public surface (Show, Hide, Toggle, ShowRun, ShowTab). The tabs are
-- modules/Results_Runs.lua and modules/Results_Bests.lua; the detail pane modules/Results_Detail.lua;
-- the shared list modules/Results_Table.lua.
--
-- THE WINDOW is a plain, non-secure frame (standalone-windows): skinned through NS.ApplySkin, closed
-- through NS.MakeCloseButton, in UISpecialFrames, clamped, movable by its title bar and resizable
-- in two views, each with its own size and minimum, with its position, view and sizes in
-- db.profile.windows.results.
-- Master scale acts on it as on the HUD; Lock frame does not (it is the HUD's, the positionable
-- display), and neither does General visibility: this is a browser the player opens on purpose.
-- Built on first show; each tab is built the first time it is shown.
--
-- EXPANDED OR COLLAPSED (the owner's call, 2026-10-25). Expanded, the default, sets the detail beside
-- the list (screen 08); collapsed shows the list alone, and a click puts the detail in its place, with
-- a back control (spec §6.2). Only the title bar's toggle switches them, never the width; each view
-- keeps its own size and minimum (Results.VIEWS), and the filter bar takes one row or two.
--
-- WHAT RUNS. Nothing while hidden but its bus receiver: RUN_SAVED and RUNS_CHANGED redraw the shown
-- tab (a hidden one redraws in full on its next show), SETTINGS_CHANGED redraws the footer. No game
-- event and no OnUpdate; the one timer is the one-frame look after a close-stack close (the talent
-- tree's panel open, below).
-- The receiver is a target of this module's own, so the latch drops it at stand-down.

local Results = { wanted = false }
NS.Results = Results

local L = NS.L

local DW = NS.defaults.profile.windows.results
-- Each view's minimum: collapsed holds the Runs list's columns (about 932 px with the Note column
-- and the Status column's board: 790 px of fixed columns, the Character column's 60 and the gaps,
-- pads and scrollbar) and its two-row filter bar; expanded adds the 360 px detail and lays the
-- filter bar in one row.
Results.VIEWS = {
    expanded = { width = DW.expanded.width, height = DW.expanded.height, minWidth = 1292 },
    collapsed = { width = DW.collapsed.width, height = DW.collapsed.height, minWidth = 932 },
}
Results.MIN_HEIGHT = 420
Results.DETAIL_WIDTH = 360      -- the detail pane's width when it sits beside the list
Results.FRAME_NAME = "DpsRaceResults"
Results.TABS = { "runs", "bests" }

-- The collection's title bar and tab strip (modules/Style.lua), and a footer of one small gray line.
local Style = NS.Style
local HEADER_H, TAB_H, FOOTER_H = Style.TITLE_BAR_H, Style.TAB_STRIP_H, 20
-- The footer's hint; on the Runs tab the run count goes before it.
local HINT = L["Click a row for details \194\183 right-click for options"]
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

--- The view shown: "expanded" (the default) or "collapsed".
function Results.View()
    local w = store() or {}
    return w.view == "collapsed" and "collapsed" or "expanded"
end

local function storedSize()
    local spec = Results.VIEWS[Results.View()]
    local w = (store() or {})[Results.View()]
    w = type(w) == "table" and w or {}
    return math.max(spec.minWidth, tonumber(w.width) or spec.width),
        math.max(Results.MIN_HEIGHT, tonumber(w.height) or spec.height)
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
    local view = Results.View()
    if type(w[view]) ~= "table" then w[view] = {} end
    if type(width) == "number" then w[view].width = math.floor(width + 0.5) end
    if type(height) == "number" then w[view].height = math.floor(height + 0.5) end
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
            menu = function(r, row) Results.RowMenu(r, row) end,
            -- The run count lives in the footer, before the hint (the owner's call, 2026-10-25).
            count = function(text) ui.runsCount = text end,
        })
    else
        pane = NS.ResultsBests.Build(ui.body, {
            open = function(r) Results.ShowRun(r.id) end, share = share,
            menu = function(r, row) Results.RowMenu(r, row) end,
        })
    end
    ui.panes[name] = pane
    debug("tab %s built", name)
    return pane
end

local function tabButton(name, label, i)
    -- LootHistory's tab: GameFontNormal, gold and underlined when active, gray when not.
    local b = CreateFrame("Button", nil, ui.frame)
    b:SetSize(Style.TAB_W, TAB_H)
    b:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 7 + (i - 1) * Style.TAB_PITCH, -HEADER_H)
    b.label = Style.Text(b, Style.FONT.TAB, nil, "CENTER")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetText(label)
    b.underline = b:CreateTexture(nil, "OVERLAY")
    b.underline:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
    b.underline:SetHeight(2)
    b.underline:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 8, 0)
    b.underline:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 0)
    b:SetScript("OnClick", function() Results.ShowTab(name) end)
    ui.tabs[name] = b
end

local function buildChrome(f)
    -- The title centered in the title bar (GameFontNormal, the header gold), as LootHistory's is.
    f.title = Style.Text(f, Style.FONT.TITLE, C.gold, "CENTER")
    f.title:SetPoint("CENTER", f, "TOP", 0, -HEADER_H / 2)
    f.title:SetText(L["DPS Race \226\128\148 Results"])
    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetHeight(1)
    f.divider:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -HEADER_H)
    f.divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -HEADER_H)
    -- The close control is gold under the pointer, as the HUD's controls are (modules/Style.lua).
    ui.controls = Style.NewStrip()
    ui.close = Style.AddToStrip(ui.controls, NS.MakeCloseButton(f, function() Results.Hide() end))
    if ui.close then ui.close:SetPoint("RIGHT", f, "TOPRIGHT", -6, -HEADER_H / 2) end
    -- The view toggle, left of the close control: DropWatcher's expand/collapse chevrons turned on
    -- their side, since the detail opens to the right. Expanded shows chevron-left (fold the detail
    -- away), collapsed chevron-right (open it).
    ui.viewToggle = Style.AddToStrip(ui.controls, Style.ControlButton(f, "chevron-left", "<", "",
        function() Results.ToggleView() end))
    ui.viewToggle:SetPoint("RIGHT", f, "TOPRIGHT", -6 - Style.CONTROL_PITCH, -HEADER_H / 2)
    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    drag:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -28 - Style.CONTROL_PITCH, -HEADER_H)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() f:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        savePosition()
    end)
    ui.drag = drag
    tabButton("runs", L["Runs"], 1)
    tabButton("bests", L["Bests"], 2)
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
    ui.footLeft = Style.Text(f, Style.FONT.CAPTION)
    ui.footLeft:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 5)
    ui.footLeft:SetText(HINT)
    ui.footRight = Style.Text(f, Style.FONT.CAPTION, nil, "RIGHT")
    ui.footRight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 5)
end

local onHide

local function onResized(width, height)
    if type(width) == "number" then ui.width = math.max(Results.VIEWS[Results.View()].minWidth, width) end
    if type(height) == "number" then ui.height = math.max(Results.MIN_HEIGHT, height) end
    layout()
end

-- The toggle's icon and tooltip for the view shown.
local function paintToggle()
    local b = ui and ui.viewToggle
    if not b then return end
    local expanded = Results.View() == "expanded"
    Style.SetControlIcon(b, expanded and "chevron-left" or "chevron-right", expanded and "<" or ">")
    b.tip = expanded and L["Collapse: the list alone (a click opens a run in its place)"]
        or L["Expand: the run's detail beside the list"]
    Style.PaintStrip(ui.controls)
end

-- The resize grip's minimum for the view shown.
local function applyBounds()
    local f = ui.frame
    if f.SetResizeBounds then f:SetResizeBounds(Results.VIEWS[Results.View()].minWidth, Results.MIN_HEIGHT) end
end

local function applyPlacement()
    local f, w = ui.frame, store() or {}
    ui.width, ui.height = storedSize()
    f:ClearAllPoints()
    f:SetPoint(w.point or "CENTER", UIParent, w.relativePoint or "CENTER", w.x or 0, w.y or 0)
    f:SetSize(ui.width, ui.height)
    applyBounds()
    paintToggle()
end

local function ensureWindow()
    if ui then return ui end
    local f = CreateFrame("Frame", Results.FRAME_NAME, UIParent, "BackdropTemplate")
    ui = { frame = f, tabs = {}, panes = {} }
    f:Hide()
    f:SetFrameStrata(NS.Constants.LAYERS.STRATA.WINDOW)
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
        clearPick = function() Results.ClearPick() end,
    })
    NS.ApplySkin(f)
    f:SetScript("OnHide", function() onHide() end)
    -- Escape closes it with the standard close stack (standalone-windows).
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, Results.FRAME_NAME) end
    NS.MakeResizable(f, {
        minWidth = Results.VIEWS[Results.View()].minWidth, minHeight = Results.MIN_HEIGHT,
        onResize = onResized, onResizeStop = saveSize,
    })
    applyPlacement()
    debug("window built")
    return ui
end

-- ── layout and drawing ──────────────────────────────────────────────────────────────────────────

--- "wide" (the detail beside the list: the expanded view) or "narrow" (the detail in its place:
--- the collapsed view). The view decides, never the width.
function Results.Mode()
    return Results.View() == "expanded" and "wide" or "narrow"
end

--- Switch to `view` ("expanded" | "collapsed"): its own size and minimum, the window's top-left
--- corner kept where it is, and the detail closed (a collapsed view opens on the list).
function Results.SetView(view)
    if view ~= "expanded" and view ~= "collapsed" then return false end
    local w = store()
    if not w or Results.View() == view then return false end
    w.view = view
    detailOpen = false
    if ui then
        local f = ui.frame
        local left, top = f:GetLeft(), f:GetTop()
        ui.width, ui.height = storedSize()
        applyBounds()
        f:SetSize(ui.width, ui.height)
        if type(left) == "number" and type(top) == "number" then
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            savePosition()
        end
        paintToggle()
        layout()
    end
    return true
end

--- The title bar's toggle.
function Results.ToggleView()
    return Results.SetView(Results.View() == "expanded" and "collapsed" or "expanded")
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
        pane:Layout(width, height, width - dw, true)
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
        local c = on and C.gold or Style.TAB_IDLE
        b.label:SetTextColor(c[1], c[2], c[3])
        b.underline:SetShown(on)
        local pane = ui.panes[name]
        if pane then pane.frame:SetShown(on) end
    end
end

local function footer()
    -- The Runs tab's count before its hint; the Bests tab shows the hint alone.
    local count = tab == "runs" and ui.runsCount
    ui.footLeft:SetText(count and (count .. " \194\183 " .. HINT) or HINT)
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

-- THE TALENT TREE OPENS OVER IT (the owner's call, 2026-10-25). Blizzard shows its talent frame
-- (`PlayerSpellsFrame`: the talentbuild link the detail's View posts to chat, or the N key) as a
-- "center" UI panel when no other panel is up, and FramePositionDelegate:ShowUIPanel then runs
-- CloseWindows, whose CloseSpecialWindows hides every UISpecialFrames entry: this window among
-- them, just before the tree shows. The frame stays in UISpecialFrames (standalone-windows: Escape
-- and the close stack), so the close is answered rather than prevented: a close-stack close made
-- while the tree was down looks again on the next frame, and a tree up by then is what closed it,
-- so the window comes back. Escape with the tree up closes both (the tree was up at the close), and
-- the window's own close control never gets here (it hides with `hiding` set). The one read of a
-- Blizzard frame is IsShown; nothing is hooked, shown or hidden on Blizzard's side.
local function talentTreeShown()
    local f = PlayerSpellsFrame
    return type(f) == "table" and type(f.IsShown) == "function" and f:IsShown() == true
end

local function reopenUnderTree()
    if Results.wanted or not talentTreeShown() then return end
    debug("closed by the talent tree's panel open; reopened")
    Results.Show()
end

-- The frame went away by Escape (UISpecialFrames): the player closed it. A frame still shown in its
-- own right was hidden with its parent (Alt-Z), which is not the player closing it.
function onHide()
    NS.CloseMenu()
    if hiding or (ui and ui.frame:IsShown()) then return end
    Results.wanted = false
    if not talentTreeShown() and C_Timer and C_Timer.After then C_Timer.After(0, reopenUnderTree) end
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
    if w then w.point, w.relativePoint, w.x, w.y, w.expanded, w.collapsed = nil, nil, nil, nil, nil, nil end
    if ui then
        applyPlacement()
        layout()
    end
end

-- ── the row menu ────────────────────────────────────────────────────────────────────────────────

--- Open run `id` with its note being written (the row menu's Add Note): its detail, the note box
--- focused.
function Results.EditNote(id)
    if not Results.ShowRun(id) then return false end
    if ui and ui.detail and ui.detail.openNote then ui.detail:openNote() end
    return true
end

--- Compare the run in the detail with run `id` (the row menu's *Compare With This Run*): a session-only
--- pick, never stored, that holds until it is cleared or the run is deleted. The detail opens on the
--- run it was showing with the compare on.
--- @return boolean picked
function Results.CompareWith(id)
    if not (run(id) and NS.ResultsCompare.Usable(run(id))) then return false end
    ensureWindow()
    ui.detail:SetPick(id)
    if selected then Results.ShowRun(selected) end
    return true
end

--- Clear the pick: the detail compares with the best on its run's board again.
function Results.ClearPick()
    if ui then ui.detail:SetPick(nil) end
end

--- The picked run's id, or nil.
function Results.Pick()
    return ui and ui.detail.pickID or nil
end

--- A row's right-click menu (LootHistory's): Add Note (Edit Note once it has one), Share with the
--- channels as a submenu, Compare With This Run (for the run in the detail; grayed on that run itself
--- and on a lost one), and Delete behind its confirmation.
--- @param r table  the run
--- @param owner table  the row
--- @return boolean opened
function Results.RowMenu(r, owner)
    if not (r and MenuUtil and MenuUtil.CreateContextMenu) then return false end
    MenuUtil.CreateContextMenu(owner or UIParent, function(_, root)
        root:CreateTitle(NS.ResultsTable.Date(r.date, "%d %b %H:%M"))
        local hasNote = type(r.note) == "string" and r.note ~= ""
        root:CreateButton(hasNote and L["Edit Note"] or L["Add Note"], function() Results.EditNote(r.id) end)
        local shareMenu = root:CreateButton(L["Share"])
        if canShare() and NS.Share.Line(r) then NS.Share.FillMenu(shareMenu, r) else shareMenu:SetEnabled(false) end
        local cmp = root:CreateButton(L["Compare With This Run"], function() Results.CompareWith(r.id) end)
        if r.id == selected or not NS.ResultsCompare.Usable(r) then cmp:SetEnabled(false) end
        root:CreateButton("|cffff5555" .. L["Delete"] .. "|r", function() Results.ConfirmDelete(r.id) end)
    end)
    return true
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
