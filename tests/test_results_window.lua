-- tests/test_results_window.lua — the Results window itself (modules/Results.lua, spec §6.2): how the shell
-- builds the Insights tab, how it follows the store, the window chrome, its wide and narrow views, the
-- lifecycle and the collection's look. Peeled out of tests/test_results.lua (layout-§1); the helpers are
-- that suite's.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600

--- A fresh instance with the widget recorder and a recording StaticPopup_Show.
local function inst(opts)
    opts = opts or {}
    local W, popups = nil, {}
    local i = T.load{ libFiles = opts.libFiles, mutate = function(m)
        if not opts.bare then W = Widgets.install(m) end
        -- The logged-in player is the seeded runs' Lanfear, in Destruction: the Runs tab opens on
        -- the current character and spec.
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function(which, _, _, data) popups[#popups + 1] = { which = which, data = data } end
    end }
    i.W, i.popups = W, popups
    i.R = i.NS.Results
    return i
end

local CHARS = {
    lan = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction", ilvl = 313.2 },
    mage = { name = "Kaosmage", realm = "Frostmourne", class = "MAGE", specID = 63, spec = "Fire", ilvl = 311.0 },
    druid = { name = "Barkskin", realm = "Frostmourne", class = "DRUID", specID = 102, spec = "Balance", ilvl = 309.4 },
}

-- A field mkRun removes (pairs never sees a nil value).
local NONE = {}

local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

--- A stored-shape run: a complete 3:00 cleave race by Lanfear, an hour ago. `fields` replaces any
--- top-level field; `char` names one of CHARS.
local function mkRun(id, fields)
    local run = {
        id = id, schema = 1, status = "complete", addon = "0.1.0", build = 120105, date = NOW - HOUR,
        race = { length = 180, grace = 1.0, restartGap = 6, startSource = "meterSession", sessionID = 25 },
        char = copy(CHARS.lan),
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        where = { mapID = 2393, zone = "Silvermoon City", subzone = "Falconwing Square", instanceType = "none" },
        result = { damage = 26560000, dps = 147555.6, meterDps = 134100, sessionDuration = 190, tail = 9.17,
                   combatEnd = 7.34 },
        flags = { lateCasts = {}, reloaded = false, died = false },
        spells = { { id = 29722, dmg = 7330000, dps = 1 }, { id = 116858, dmg = 4920000, dps = 1 } },
        note = "",
    }
    for k, v in pairs(fields or {}) do
        if v == NONE then run[k] = nil else run[k] = v end
    end
    if type(run.char) == "string" then run.char = copy(CHARS[run.char]) end
    return run
end

local function seed(i, runs)
    for _, run in ipairs(runs) do i.NS.db.global.runs[run.id] = run end
    i.NS.Bests.Invalidate()
end

local function ui(i) return assert(i.R.__ui(), "the Results window was never built") end
-- A new profile opens grouped by spec, target and time; these cases read the flat list, so the
-- pane is ungrouped the first time a case reaches it (the grouping itself is test_results_group's).
local function runsPane(i)
    local pane = assert(ui(i).panes.runs, "the Runs tab was never built")
    if not pane.__flat then
        pane.__flat = true
        if pane.filters.group ~= "none" then pane:SetFilter("group", "none") end
    end
    return pane
end
local function visible(pane) return pane.list:Visible() end

-- ── the Insights tab (#12) ──────────────────────────────────────────────────────────────────────
-- N1 renamed the Bests tab and dropped its board; the tab itself (the bar, the cards, the sections)
-- is tests/test_insights.lua's. Here: how the shell builds it, counts it and shows its empty state.

test("results: the Insights tab is built on first show, counts the runs and shows the empty state with none", function()
    local i = inst()
    seed(i, {
        mkRun("a"),
        mkRun("inc", { status = "incomplete", result = { damage = 1, dps = 1, endedAt = 9 } }),
        mkRun("gone", { status = "lost", date = NOW - 2 * HOUR }),
    })
    i.R.Show()
    assertEqual(ui(i).panes.insights, nil, "the Insights tab was built before it was shown")
    assertTrue(i.R.ShowTab("insights"))
    assertEqual(i.R.Tab(), "insights")
    local pane = assert(ui(i).panes.insights)
    assertTrue(pane.frame:IsShown())
    assertFalse(runsPane(i).frame:IsShown(), "the Runs tab still shows")
    assertEqual(pane:Count(), 1, "Include incomplete starts off (D-11)")
    assertFalse(pane.empty:IsShown(), "the empty state over runs")
    assertEqual(ui(i).footLeft.__text, "1 run \194\183 Click a row for details \194\183 right-click for options")
    pane:SetFilter("includeIncomplete", true)
    assertEqual(pane:Count(), 2, "a lost run never counts")
    for _, id in ipairs({ "a", "inc", "gone" }) do i.NS.Recorder.Delete(id) end
    assertEqual(pane:Count(), 0)
    assertTrue(pane.empty:IsShown())
    assertEqual(pane.empty.__text, "No runs match these filters.")
    assertFalse(i.R.ShowTab("bests"), "Bests is no tab name any more")
    assertEqual(i.NS.ResultsBests, nil, "the board UI is gone")
    assertEqual(i.NS.ResultsTable.ShortFlags, nil, "and its chip words with it")
    assertEqual(i.R.Tab(), "insights")
end)

test("results: a profile saved before the rename loads clean and opens Insights (D-14, no migration)", function()
    local i = T.load{ init = false, mutate = function(m) Widgets.install(m) end }
    local profile = { windows = { results = { view = "collapsed", collapsed = { width = 1000, height = 600 } } },
                      views = { runs = { char = "all", group = "none" } } }
    _G.DpsRaceDB = { global = { schemaVersion = i.NS.SCHEMA_VERSION, schema = 4 },
                     profileKeys = {}, profiles = { Default = profile } }
    i.mocks._G.DpsRaceDB = _G.DpsRaceDB
    local AceAddon = i.mocks.LibStub("AceAddon-3.0")
    AceAddon:InitializeAddon(i.NS)
    AceAddon:EnableAddon(i.NS)
    local R = i.NS.Results
    assertEqual(i.NS.db.profile.views.runs.char, "all", "the saved Runs view is read")
    assertTrue(R.ShowTab("insights"))
    assertTrue(R.__ui().panes.insights.frame:IsShown())
    assertEqual(i.NS.db.profile.views.insights, nil, "nothing written for the new tab")
    assertEqual(i.NS.db.profile.windows.results.collapsed.width, 1000, "the window keeps its size")
end)

-- ── following the store ─────────────────────────────────────────────────────────────────────────

test("results: list refreshes on RUN_SAVED", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.Show()
    local pane = runsPane(i)
    assertEqual(pane.countText, "1 run")
    i.NS.Recorder.Save(mkRun("b", { date = NOW, result = { damage = 1, dps = 999999 } }))
    assertEqual(pane.countText, "2 runs")
    assertEqual(visible(pane)[1].run.id, "b")
    i.NS.Recorder.Delete("a")
    assertEqual(pane.countText, "1 run", "RUNS_CHANGED did not redraw")
    i.R.Hide()
    i.NS.Recorder.Save(mkRun("c"))
    i.R.Show()
    assertEqual(pane.countText, "2 runs", "a hidden window came back stale")
end)

test("results: Runs opens on the current character in every spec; current character and spec are each a choice of its own", function()
    local i = inst()
    seed(i, { mkRun("mine"), mkRun("mage", { char = "mage", date = NOW - 2 * HOUR }) })
    i.R.Show()
    local pane = runsPane(i)
    assertEqual(pane.filters.char, "current")
    assertEqual(pane.filters.spec, "all", "every spec (the owner's call, 2026-10-26)")
    assertEqual(i.NS.ResultsRuns.DEFAULTS.group, "full", "grouped by Full (runsPane ungroups the pane)")
    for _, k in ipairs({ "category", "length", "date" }) do assertEqual(pane.filters[k], "all", k) end
    assertEqual(pane:Count(), 1, "only the logged-in character's run")
    local opts = i.NS.ResultsRuns.Options(i.NS.Recorder.All())
    assertEqual(opts.char[1].label, "Current character")
    assertEqual(opts.char[2].value, "all")
    assertEqual(opts.spec[1].label, "Current spec")
    pane:SetFilter("char", "all")
    pane:SetFilter("spec", "all")
    assertEqual(pane:Count(), 2)
    assertEqual(i.NS.Hud.Act.lastResult, nil, "the HUD's Last Result is gone")
end)

-- ── the window ──────────────────────────────────────────────────────────────────────────────────

test("results: the window is skinned, closable with Escape, resizable and clamped", function()
    local i = inst()
    i.R.Show()
    local u = ui(i)
    local found = false
    for _, name in ipairs(i.mocks.UISpecialFrames) do if name == "DpsRaceResults" then found = true end end
    assertTrue(found, "not in UISpecialFrames")
    assertTrue(u.frame.resizeGrip ~= nil, "no sizing grip")
    local minW, minH = u.frame:GetResizeBounds()
    -- A new profile opens collapsed (UT-P14), at that view's minimum width.
    assertEqual(i.NS.defaults.profile.windows.results.view, "collapsed")
    assertEqual(i.R.View(), "collapsed", "a new profile opens collapsed")
    assertEqual(i.R.Mode(), "narrow")
    assertEqual(minW, 904)
    assertEqual(minH, 420)
    assertEqual(u.width, 904, "a new profile opens at the minimum width")
    assertEqual(u.height, 560)
    assertEqual(u.viewToggle.iconName, "chevron-right", "collapsed: the toggle unfolds the detail")
    assertEqual(runsPane(i).barH, 2 * 32 - 6, "collapsed: the filter bar is two rows")
    -- The toggle: expanded has its own size and minimum; collapsing brings the first back.
    u.viewToggle:__fire("OnClick")
    assertEqual(i.R.View(), "expanded")
    assertEqual(i.R.Mode(), "wide")
    assertEqual((u.frame:GetResizeBounds()), 1344)
    assertEqual(u.width, 1344, "expanded opens at its minimum width")
    assertEqual(u.viewToggle.iconName, "chevron-left", "expanded: the toggle folds the detail away")
    assertEqual(runsPane(i).barH, 32, "expanded: the filter bar is one row")
    u.viewToggle:__fire("OnClick")
    assertEqual(i.R.View(), "collapsed")
    assertEqual(u.width, 904)
    -- A stored view that is neither reads as the default, collapsed.
    i.NS.db.profile.windows.results.view = "sideways"
    assertEqual(i.R.View(), "collapsed")
    i.NS.db.profile.windows.results.view = "collapsed"
    assertTrue(u.frame.innerBorder ~= nil, "the Ka0s window edge was not applied")
    assertEqual(u.frame.title.__text, "DPS Race \226\128\148 Results")
    assertEqual(u.footRight.__text, "Days to keep: 90", "the default, 90 days")
    u.close:__fire("OnClick")
    assertFalse(i.R.IsShown())
    assertFalse(u.frame:IsShown())
end)

test("results: position, size and Master scale persist; Reset position restores them", function()
    local i = inst()
    i.NS.db.profile.windows.results.view = "expanded"
    i.R.Show()
    local u = ui(i)
    rawset(u.frame, "GetPoint", function() return "TOPLEFT", nil, "BOTTOMLEFT", 40.4, 600.6 end)
    u.drag:__fire("OnDragStart")
    u.drag:__fire("OnDragStop")
    local w = i.NS.db.profile.windows.results
    assertEqual(w.point, "TOPLEFT")
    assertEqual(w.x, 40)
    assertEqual(w.y, 601)
    u.frame:__fire("OnSizeChanged", 1400, 600)
    assertEqual(u.width, 1400)
    u.frame:__fire("OnSizeChanged", 900, 600)
    assertEqual(u.width, 1344, "expanded never goes under its minimum")
    assertEqual(i.R.View(), "expanded", "a narrower window does not collapse the view")
    assertTrue(i.NS.SetByPath("scale", 1.25))
    assertEqual(u.frame.__scale, 1.25)
    w.expanded = { width = 1400, height = 600 }
    w.collapsed = { width = 950, height = 500 }
    i.NS.SetByPath("scale", 1.0)
    i.R.ResetPosition()
    assertEqual(w.point, nil)
    assertEqual(w.expanded, nil)
    assertEqual(w.collapsed, nil)
    assertEqual(u.width, 1344)
end)

test("results: collapsed, the detail replaces the list, with a back control", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.NS.db.profile.windows.results = { view = "collapsed", collapsed = { width = 850, height = 500 } }
    i.R.Show()
    assertEqual(i.R.Mode(), "narrow")
    local pane, d = runsPane(i), ui(i).detail
    assertTrue(pane.frame:IsShown())
    assertFalse(d.frame:IsShown(), "the detail shows beside a narrow list")
    visible(pane)[1]:__fire("OnClick")
    assertFalse(pane.frame:IsShown(), "the list still shows under the detail")
    assertTrue(d.frame:IsShown())
    assertTrue(d.w.back:IsShown(), "no back control")
    d.w.back:__fire("OnClick")
    assertTrue(pane.frame:IsShown())
    assertFalse(d.frame:IsShown())
    assertEqual(i.R.Selected(), "a", "going back dropped the selection")

    local j = inst()
    seed(j, { mkRun("a") })
    j.NS.db.profile.windows.results.view = "expanded"
    j.R.Show()
    assertEqual(j.R.Mode(), "wide")
    visible(runsPane(j))[1]:__fire("OnClick")
    assertTrue(runsPane(j).frame:IsShown(), "a wide window hid the list")
    assertTrue(ui(j).detail.frame:IsShown())
    assertFalse(ui(j).detail.w.back:IsShown(), "a back control beside the list")
    assertTrue(visible(runsPane(j))[1].sel:IsShown(), "the selected row is not marked")
    seed(j, { mkRun("b", { date = NOW }) })
    j.R.Refresh()
    local rowB = visible(runsPane(j))[1]
    assertEqual(rowB.run.id, "b")
    rowB:__fire("OnClick")
    assertEqual(j.R.Selected(), "b", "a click on the row selects it")
end)

test("results: hidden with its parent is not closed by the player", function()
    local i = inst()
    i.R.Show()
    ui(i).frame:__fire("OnHide")
    assertTrue(i.R.wanted, "Alt-Z closed the window for good")
    ui(i).frame:Hide()
    ui(i).frame:__fire("OnHide")
    assertFalse(i.R.wanted, "Escape did not close it")
end)

test("results: the window is no Blizzard UI panel: no UIPanelWindows, no layout attributes, no ShowUIPanel, no hook", function()
    local src = assert(io.open(T.root .. "/modules/Results.lua", "rb")):read("*a")
    assertFalse(src:find("UIPanelWindows", 1, true) ~= nil, "Results registers itself as a Blizzard UI panel")
    assertFalse(src:find("UIPanelLayout", 1, true) ~= nil, "Results sets a Blizzard UI panel layout")
    assertFalse(src:find("ShowUIPanel(", 1, true) ~= nil, "Results calls ShowUIPanel")
    assertFalse(src:find("hooksecurefunc", 1, true) ~= nil, "Results hooks a Blizzard function")
end)

test("results: the stand-down hides it and the stand-up brings it back", function()
    local i = inst()
    i.R.Show()
    assertTrue(i.NS.SetByPath("enabled", false))
    assertFalse(i.R.IsShown())
    assertFalse(ui(i).frame:IsShown())
    assertTrue(i.NS.SetByPath("enabled", true))
    assertTrue(ui(i).frame:IsShown(), "the window the player had open did not come back")
end)

test("results: the library-absent load still draws the window, with no dropdowns or close control", function()
    local i = inst{ libFiles = {}, bare = true }
    i.NS.db.global.runs.a = mkRun("a")
    i.R.Show()
    local u = ui(i)
    assertTrue(u.frame:IsShown())
    assertEqual(u.close, nil)
    assertEqual(next(u.panes.runs.dropdowns), nil, "a dead dropdown was drawn")
    assertEqual(#u.panes.runs.list:Visible(), 2, "the run under its spec + target + time header")
    assertTrue(i.R.ShowTab("insights"))
    assertEqual(u.panes.insights:Count(), 1)
end)

test("results: the diagnostics state section names the tab, the layout and the selection", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.ShowRun("a")
    local lines = {}
    local out = { add = function(_, _, fmt, ...)
        local args = { ... }
        for n = 1, select("#", ...) do args[n] = tostring(args[n]) end
        lines[#lines + 1] = fmt:format(unpack(args, 1, select("#", ...)))
    end }
    for _, section in ipairs(i.NS.Diagnostics.Sections()) do
        if section[1] == "state" then section[2](out) end
    end
    local found = false
    for _, l in ipairs(lines) do
        if l == "results tab=runs mode=narrow rows=1 selected=a" then found = true end
    end
    assertTrue(found, "no results line; got: " .. table.concat(lines, " | "))
end)

-- ── the collection's look (modules/Style.lua) ─────────────────────────────────────────────────────

test("results: a centered GameFontNormal title, Title Case tabs and headers, compact rows, small gray footers", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.Show()
    local u = ui(i)
    assertEqual(u.frame.title.__fontObject, "GameFontNormal", "the title")
    assertEqual(u.tabs.runs.label.__text, "Runs")
    assertEqual(u.tabs.insights.label.__text, "Insights")
    assertEqual(u.tabs.runs.label.__fontObject, "GameFontNormal", "a tab")
    assertEqual(u.tabs.runs.label.__color[2], 0.82, "the active tab is gold")
    assertEqual(u.tabs.insights.label.__color[1], 0.7, "an idle tab is gray")
    assertEqual(u.footLeft.__fontObject, "GameFontDisableSmall", "the footer")
    assertEqual(u.footRight.__fontObject, "GameFontDisableSmall")
    local Tbl = i.NS.ResultsTable
    assertEqual(Tbl.ROW_H, 18, "LootHistory's compact row (BrowserTable.ROW_H_DEFAULT)")
    assertEqual(Tbl.HEADER_H, 20, "LootHistory's 20px header")
    local pane = runsPane(i)
    for _, head in ipairs(pane.list.heads) do
        assertEqual(head.label.__fontObject, "GameFontNormalSmall", "a column header")
        local label = (head.label.__text or ""):gsub("|T.-|t", "")
        assertFalse(label:find("%u%u%u%u") ~= nil, "an ALL-CAPS header: " .. label)
    end
    local cells = assert(visible(pane)[1], "no row drawn").cells
    assertEqual(cells.char.fs.__fontObject, "GameFontHighlightSmall", "a cell")
    assertEqual(cells.target.fs.__fontObject, "GameFontHighlightSmall", "the badge")
    for _, b in pairs(runsPane(i).checks) do assertEqual(b.label.__fontObject, "GameFontHighlightSmall") end
    assertEqual(ui(i).footLeft.__fontObject, "GameFontDisableSmall", "the footer, where the run count is")
    assertTrue(ui(i).footLeft.__text:find(runsPane(i).countText, 1, true) == 1, "the count leads the footer")
    i.R.ShowRun("a")
    local d = ui(i).detail
    assertEqual(d.w.name.__fontObject, "GameFontHighlightLarge", "the name that heads the pane, larger (2026-10-25)")
    assertEqual(d.w.damage.label.__text, "Damage")
    assertEqual(d.w.damage.label.__fontObject, "GameFontDisableSmall", "a KPI caption")
    assertEqual(d.w.damage.value.__fontObject, "GameFontNormalHuge", "a KPI figure stays large")
    assertEqual(d.w.meterDps.label.__text, "Meter DPS")
    assertEqual(d.w.timingLabel.__text, "Timing")
    assertEqual(d.w.share.label.__text, "Share")
    assertEqual(d.w.delete.label.__text, "Delete")
    assertEqual(d.w.share.label.__fontObject, "GameFontHighlightSmall", "a button")
    assertEqual(d.w.list.rows[1].name.__fontObject, "GameFontHighlightSmall", "a breakdown row")
end)

test("results: the close control is the skin's own, never the title strip's gold (D-9)", function()
    local i = inst()
    i.R.Show()
    local close = assert(ui(i).close, "no close control")
    -- S.CloseButton through Core paints it (`close.rest`, `close.hot` under the pointer; LibKa0s's
    -- suites pin those): the strip the view toggle is on never repaints it.
    local GOLD = i.NS.Style.GOLD
    local function is(c)
        local v = close.icon.__vertex
        return v ~= nil and v[1] == c[1] and v[2] == c[2] and v[3] == c[3]
    end
    assertFalse(is(GOLD), "at rest")
    close:__fire("OnEnter")
    assertFalse(is(GOLD), "under the pointer")
    close:__fire("OnLeave")
    assertFalse(is(GOLD), "back at rest")
end)
