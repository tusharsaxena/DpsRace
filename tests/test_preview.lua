-- tests/test_preview.lua — modules/Preview.lua, test mode (spec §6.5, preview-mode; B5): static sample
-- data in every view. The HUD holds one body still through its own render path, the Results window
-- reads the sample history (modules/MockRuns.lua) through its source seam (modules/Results_Source.lua),
-- each window says so with its strip, nothing reaches SavedVariables, and the store comes back when
-- it ends: combat, arming a real race, its own switch, closing the HUD, Reset all settings and the
-- stand-down. The sim is tests/test_sim.lua.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local function fixture()
    local W
    local f = RaceClock.new{ mutate = function(m) W = Widgets.install(m) end }
    f.W, f.Hud, f.Preview, f.R = W, f.NS.Hud, f.NS.Preview, f.NS.Results
    return f
end

local function ui(f) return assert(f.Hud.__ui(), "the HUD window was never built") end
local function current(f) return ui(f).current end
local function rui(f) return assert(f.R.__ui(), "the Results window was never built") end

local function bare(M)
    local out = {}
    for i, l in ipairs(M.__printed()) do out[i] = (l:gsub("^|cff00ffff%[DR%]|r ", "")) end
    return out
end

-- Nothing the preview drew reached SavedVariables: no run, no loadout, no saved view.
local function untouched(f)
    local g, p = f.NS.db.global, f.NS.db.profile
    assertEqual(next(g.runs), nil, "a sample run reached the store")
    local lo = g.loadouts
    assertTrue(lo == nil or (next(lo.gear or {}) == nil and next(lo.talents or {}) == nil), "a sample loadout was stored")
    assertEqual(p.views, nil, "a sample view was saved")
end

-- A real stored run, so the store and the sample history can be told apart.
local function seedReal(f)
    local run = {
        id = "real-1", schema = 2, status = "complete", date = os.time() - 60,
        race = { length = 60, grace = 1, restartGap = 6 }, char = f.NS.Recorder.SnapshotPlayer(),
        target = { name = "Training Dummy", category = "single", count = 1 },
        result = { damage = 6000000, dps = 100000 }, flags = { lateCasts = {} }, spells = {}, note = "",
    }
    f.NS.db.global.runs[run.id] = run
    f.NS.Bests.Invalidate()
    return run
end

-- ── the HUD ─────────────────────────────────────────────────────────────────────────────────────

test("preview: test mode holds the running body still with live figures, chart, pace bar and spells", function()
    local f = fixture()
    local saved = 0
    f.NS.NewBusTarget():RegisterMessage(f.NS.MSG.RUN_SAVED, function() saved = saved + 1 end)
    assertTrue(f.Preview.Start())
    assertTrue(f.Hud.IsShown(), "test mode shows the HUD")
    assertEqual(f.Preview.Mode(), "test")
    assertEqual(current(f), "running")
    local w = ui(f).body.running.w
    assertEqual(w.left.__text, "0:12.0")
    assertEqual(w.elapsed.__text, "0:18.0")
    assertTrue(w.list:Count() > 0, "no live rows")
    assertTrue(w.damage.value.__text ~= "\226\128\148", "no damage figure")
    assertTrue(w.chart.shown, "no chart")
    assertTrue(w.pace.bar:IsShown(), "no pace bar")
    assertEqual(f.Preview.Diagnose().ticking, false, "a still view holds no timer")
    f:advance(60)
    assertEqual(current(f), "running", "a still view never moves on")
    assertEqual(w.elapsed.__text, "0:18.0")
    assertEqual(saved, 0)
    untouched(f)
    assertEqual(f.Race.State(), "idle", "the race engine never moved")
end)

test("preview: the still running clock follows the Race clock setting", function()
    local f = fixture()
    f.NS.db.profile.hud.clock = "elapsed"
    assertTrue(f.Preview.Start())
    local w = ui(f).body.running.w
    assertTrue(w.clock:IsShown())
    assertFalse(w.left:IsShown())
    assertEqual(w.clock.__text, "0:18.0")
end)

test("preview: a queued state opens on that body; SetState switches armed, running and result", function()
    local f = fixture()
    assertTrue(f.Preview.Start({ mode = "test", state = "result" }))
    assertEqual(current(f), "result")
    local chips = ui(f).body.result.w.chips:Texts()
    assertTrue(chips[1]:find("New best", 1, true) ~= nil, chips[1])
    assertTrue(ui(f).body.result.w.pace.bar:IsShown(), "the sample card's pace bar")
    assertTrue(f.Preview.SetState("armed"))
    assertEqual(current(f), "armed")
    assertTrue(f.Preview.SetState("running"))
    assertEqual(current(f), "running")
    assertFalse(f.Preview.SetState("waiting"), "not a still state")
    assertEqual(current(f), "running")
    f.Preview.Stop()
    assertFalse(f.Preview.SetState("result"), "off: nothing to switch")
    -- The next start remembers the last still state.
    assertTrue(f.Preview.Start())
    assertEqual(current(f), "running")
end)

test("preview: the test strip says so on the HUD while it is on, and only then", function()
    local f = fixture()
    f.Hud.Show()
    assertTrue(f.Preview.Start())
    local strip = assert(ui(f).strip, "no test strip on the HUD")
    assertTrue(strip:IsShown())
    -- standalone-windows: one localized line saying what test mode shows and what ends it.
    assertEqual(strip.text:GetText(), "Test mode: sample numbers. Combat or Arm ends it")
    assertEqual(ui(f).frame.title.__text, "DPS Race", "one marker per mode: the strip, not the title too")
    f.Preview.Stop()
    assertFalse(strip:IsShown())
end)

test("preview: with no Widgets library each window's title carries the marker", function()
    local inst = T.load{ libFiles = {}, mutate = function(m) Widgets.install(m) end }
    local NS = inst.NS
    assertTrue(NS.Preview.Start())
    local u = assert(NS.Hud.__ui())
    assertEqual(u.strip, nil)
    assertEqual(NS.Hud.TitleText(), "DPS Race \194\183 Test", "the marker in Title Case, not a shout")
    -- The longer title sits left and stops at the drag strip, clear of the title-bar controls.
    local pts = u.frame.title.__points
    assertEqual(#pts, 2, "the title is bounded on both sides")
    assertEqual(pts[1][1], "LEFT")
    assertEqual(pts[2][1], "RIGHT")
    assertEqual(pts[2][2], u.drag, "the title stops where the drag strip does")
    assertEqual(u.frame.title.__justifyH, "LEFT")
    local r = assert(NS.Results.__ui(), "test mode opens the Results window")
    assertEqual(r.strip, nil)
    assertEqual(r.frame.title.__text, "DPS Race \226\128\148 Results \194\183 Test")
    NS.Preview.Stop()
    assertEqual(NS.Hud.TitleText(), "DPS Race")
    NS.Hud.Show()
    pts = u.frame.title.__points
    assertEqual(#pts, 1, "back to one point")
    assertEqual(pts[1][1], "CENTER", "the plain title is centered again")
    NS.Results.Show()
    assertEqual(r.frame.title.__text, "DPS Race \226\128\148 Results")
end)

-- ── the Results window ──────────────────────────────────────────────────────────────────────────

test("preview: test mode opens the Results window on the sample history, with its strip", function()
    local f = fixture()
    seedReal(f)
    assertTrue(f.Preview.Start())
    assertTrue(f.R.IsShown(), "the Results window opened")
    assertTrue(f.NS.ResultsSource.IsMock())
    local u = rui(f)
    local strip = assert(u.strip, "no test strip on the Results window")
    assertTrue(strip:IsShown())
    assertEqual(strip.text:GetText(), "Test mode: sample runs. Nothing here is saved")
    local pane = u.panes.runs
    assertEqual(pane.filters.char, "all", "the sample history opens on every character")
    assertEqual(pane.filters.spec, "all")
    assertEqual(pane:Count(), #f.NS.MockRuns.HISTORY, "every sample run listed")
    for _, run in ipairs(pane.filtered) do
        assertTrue(run.id ~= "real-1", "a stored run mixed into the sample")
    end
    assertEqual(f.NS.ResultsSource.Get("real-1"), nil, "the store is out of reach meanwhile")
end)

test("preview: the detail's Delta box and New best badge read the sample history's Runs view", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    local u = rui(f)
    local pane, Runs = u.panes.runs, f.NS.ResultsRuns
    local tops = 0
    for _, run in ipairs(pane.filtered) do
        f.R.ShowRun(run.id)
        local ctx = pane:DeltaContext(run)
        assertTrue(ctx ~= nil, run.id .. ": a listed sample run reads the view's group")
        assertEqual(u.detail.deltaCtx, ctx, run.id)
        local text, _, top = Runs.DeltaBox(run, ctx)
        assertEqual(u.detail.w.deltaBox.value.__text, text, run.id)
        assertEqual(u.detail.w.badge:IsShown(), top, run.id)
        if top then tops = tops + 1 end
    end
    assertTrue(tops > 0, "some sample run tops its group")
    untouched(f)
end)

test("preview: the sample history covers every status, target type, preset length, notes, loadouts and charts", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    local Runs, data = f.NS.ResultsRuns, f.Preview.Dataset()
    local runs = f.NS.ResultsSource.All()
    local statuses, cats, lengths, notes, loadouts = {}, {}, {}, 0, 0
    local specs = {}
    for _, run in ipairs(runs) do
        statuses[(Runs.Status(run))] = true
        cats[run.target.category] = true
        lengths[run.race.length] = true
        specs[run.char.specID or "?"] = true
        if run.note ~= "" then notes = notes + 1 end
        if run.loadout then loadouts = loadouts + 1 end
    end
    for _, key in ipairs({ "best", "complete", "flagged", "incomplete", "died", "lost" }) do
        assertTrue(statuses[key], "no sample run with the status " .. key)
    end
    for _, cat in ipairs({ "single", "cleave", "dungeoneer", "boss", "pvp" }) do assertTrue(cats[cat], cat) end
    for _, len in ipairs({ 30, 60, 120, 180, 300 }) do assertTrue(lengths[len], "no " .. len .. "s run") end
    local nSpecs = 0
    for _ in pairs(specs) do nSpecs = nSpecs + 1 end
    assertTrue(nSpecs >= 3, "several specs")
    assertTrue(notes >= 2 and notes < #runs, "notes on some")
    assertTrue(loadouts >= 2 and loadouts < #runs, "loadouts on some")
    assertTrue(next(data.slices) ~= nil, "charts on some")
end)

test("preview: the sample detail draws its chart, compare and gear; the Bests tab ranks the sample", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    assertTrue(f.R.ShowRun("sample-01"))
    local d = rui(f).detail
    assertEqual(d.run.id, "sample-01")
    assertTrue(d.chartView ~= nil, "no chart from the sample's slices")
    assertEqual(d.chartView.max, d.run.result.damage)
    local other, kind = d:CompareTarget(true)
    assertEqual(kind, "runnerUp", "the board's best compares with its runner-up")
    assertTrue(other ~= nil and other.id:find("^sample%-") ~= nil)
    assertTrue(d.lo.gear ~= nil, "no sample gear in the grid")
    assertTrue(d.lo.talentsData ~= nil, "no sample talents")
    assertTrue(f.R.ShowRun("sample-02"))
    assertTrue(f.NS.ResultsSource.GearChanged(d.run), "the variant set reads as changed gear")
    assertTrue(f.R.ShowTab("bests"))
    assertTrue(rui(f).panes.bests:Count() > 0, "no sample bests")
end)

test("preview: a note or a delete changes the sample in memory; Save view and Share refuse", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    assertEqual(f.R.SetNote("sample-02", "just a sample"), "just a sample")
    assertEqual(f.NS.ResultsSource.Get("sample-02").note, "just a sample")
    assertTrue(f.R.DeleteRun("sample-03"))
    assertEqual(f.NS.ResultsSource.Get("sample-03"), nil)
    assertEqual(rui(f).panes.runs:Count(), #f.NS.MockRuns.HISTORY - 1)
    f.M.__resetPrinted()
    assertFalse(rui(f).panes.runs:SaveView())
    assertFalse(rui(f).panes.runs:ResetView())
    assertEqual(bare(f.M)[1], "Not saved: the Results window is showing sample runs.")
    f.R.ShowRun("sample-01")
    assertFalse(rui(f).detail.w.share:IsEnabled(), "a sample run offered Share")
    untouched(f)
end)

test("preview: ending it gives the store back, the player's view and an open window kept open", function()
    local f = fixture()
    seedReal(f)
    f.R.Show()
    local pane = rui(f).panes.runs
    pane:SetFilter("length", 60)
    assertTrue(f.Preview.Start())
    assertEqual(pane.filters.length, "all", "the sample's view")
    f.R.ShowRun("sample-01")
    f.Preview.Stop()
    assertFalse(f.NS.ResultsSource.IsMock())
    assertTrue(f.R.IsShown(), "a Results window the player opened was closed")
    assertFalse(rui(f).strip:IsShown())
    assertEqual(pane.filters.length, 60, "the player's view came back")
    assertEqual(pane.filters.char, "current")
    assertEqual(f.R.Selected(), nil, "a sample selection outlived test mode")
    assertEqual(pane:Count(), 1)
    assertEqual(pane.filtered[1].id, "real-1")
end)

test("preview: a Results window test mode opened closes with it", function()
    local f = fixture()
    assertFalse(f.R.IsShown())
    assertTrue(f.Preview.Start())
    assertTrue(f.R.IsShown())
    f.Preview.Stop()
    assertFalse(f.R.IsShown(), "the Results window test mode opened stayed open")
    assertFalse(f.NS.ResultsSource.IsMock())
end)

test("preview: a Results window the player closed and reopened stays open when test mode ends", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    assertTrue(f.R.IsShown(), "test mode opened the Results window")
    f.R.Hide()
    f.R.Show()
    f.Preview.Stop()
    assertTrue(f.R.IsShown(), "the window the player reopened closed with test mode")
    assertFalse(f.NS.ResultsSource.IsMock())
    -- A later start opens it again as its own, and closes it with itself.
    f.R.Hide()
    assertTrue(f.Preview.Start())
    assertTrue(f.R.IsShown())
    f.Preview.Stop()
    assertFalse(f.R.IsShown(), "the Results window test mode opened stayed open")
end)

-- ── the end conditions ──────────────────────────────────────────────────────────────────────────

test("preview: arming a real race ends test mode and gives the Results window the store", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    f.M.__resetPrinted()
    assertTrue(f.Race.Arm(60))
    assertFalse(f.Preview.IsActive())
    assertEqual(current(f), "armed", "the HUD shows the real race")
    assertFalse(ui(f).strip:IsShown())
    assertFalse(f.NS.ResultsSource.IsMock())
    assertFalse(f.R.IsShown())
end)

test("preview: a start in combat is refused with one line; combat ends it and says so", function()
    local f = fixture()
    f.M.__inCombat = true
    f.M.__resetPrinted()
    assertFalse(f.Preview.Start())
    assertEqual(#bare(f.M), 1)
    assertFalse(f.NS.GetSetting("state.testMode"), "a refused start leaves the checkbox unticked")
    assertFalse(f.NS.ResultsSource.IsMock(), "a refused start routed the Results window")
    f.M.__inCombat = false
    assertTrue(f.Preview.Start())
    f.M.__resetPrinted()
    f.M.__inCombat = true
    f.M.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(f.Preview.IsActive())
    assertEqual(bare(f.M)[1], "Test mode ended: you entered combat.")
    assertFalse(f.NS.ResultsSource.IsMock())
end)

test("preview: a start during a real race is refused", function()
    local f = fixture()
    assertTrue(f.Race.Arm(30))
    f.M.__resetPrinted()
    assertFalse(f.Preview.Start())
    assertEqual(#bare(f.M), 1)
    assertEqual(current(f), "armed")
end)

test("preview: turning it off gives the HUD back, closing it if test mode opened it", function()
    local f = fixture()
    assertFalse(f.Hud.IsShown())
    assertTrue(f.Preview.Start())
    f.Preview.Stop()
    assertFalse(f.Hud.IsShown(), "the HUD test mode opened stayed open")
    f.Hud.Show()
    assertTrue(f.Preview.Start())
    f.Preview.Stop()
    assertTrue(f.Hud.IsShown(), "a HUD the player opened was closed")
    assertEqual(current(f), "idle")
end)

test("preview: closing the HUD ends it; Reset all settings ends it", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    f.Hud.Act.close()
    assertFalse(f.Preview.IsActive(), "closing the HUD left test mode on")
    assertFalse(f.NS.ResultsSource.IsMock())
    assertTrue(f.Preview.Start())
    f.NS.Helpers.RestoreAllDefaults()
    assertFalse(f.Preview.IsActive())
    assertFalse(f.NS.ResultsSource.IsMock())
end)

test("preview: the stand-down ends it silently and gives the store back", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    f.M.__resetPrinted()
    assertTrue(f.NS.SetByPath("enabled", false))
    assertFalse(f.Preview.IsActive())
    assertFalse(f.NS.ResultsSource.IsMock())
    assertEqual(f.Preview.Diagnose().ticking, false)
    assertEqual(#f.M.__timers(), 0)
end)

--- A real 30s race read and shown: the state is RESULT and the HUD holds its card.
local function resolved(f)
    assertTrue(f:arm(30))
    f:start(25)
    f:to(129.5)
    f:update(25)
    f:to(130)
    f:advance(1)
    f:update(25)
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
end

test("preview: over a real result card its controls never touch the real race", function()
    local f = fixture()
    resolved(f)
    assertTrue(f.Preview.Start({ mode = "test", state = "armed" }))
    f.Hud.Act.cancel()                       -- the preview's armed body's CANCEL
    assertEqual(f.Race.State(), "result", "a preview CANCEL dismissed the real result")
    assertFalse(f.Preview.IsActive(), "CANCEL in test mode ends test mode")
    assertTrue(f.Preview.Start({ mode = "test", state = "result" }))
    assertEqual(current(f), "result")
    local card = ui(f).body.result.w
    assertFalse(card.newRace:IsEnabled(), "the sample card offers NEW RACE")
    assertFalse(card.details:IsEnabled(), "the sample card offers DETAILS")
    f.Hud.Act.newRace()
    f.Hud.Act.details()
    assertEqual(f.Race.State(), "result", "the preview's NEW RACE armed a real race")
    f.Hud.Act.close()
    assertEqual(f.Race.State(), "result", "closing the preview dismissed the real result")
    assertFalse(f.Preview.IsActive(), "closing the window test mode runs on ends it")
end)

test("preview: a HUD test mode opened is handed to the race that ended it, and closes with it", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    assertTrue(f.Race.Arm(60))
    assertTrue(f.Hud.IsShown(), "the HUD left the armed race")
    f.Race.Cancel()
    assertFalse(f.Hud.IsShown(), "onArm did not close the window after the race went back to idle")
end)

test("preview: a stand-down drops the windows test mode opened", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    assertTrue(f.NS.SetByPath("enabled", false))
    assertTrue(f.NS.SetByPath("enabled", true))
    assertFalse(f.Hud.IsShown(), "the stand-up showed a HUD only test mode had opened")
end)

test("preview: every start and stop repaints an open panel's Test mode checkbox", function()
    local f = fixture()
    local H = assert(f.NS.Helpers, "no options helpers")
    local repaints = 0
    H.RefreshScalars = function() repaints = repaints + 1 end
    assertTrue(f.Preview.Start())
    assertEqual(repaints, 1, "the start left the checkbox as it was")
    assertTrue(f.Race.Arm(60))              -- from chat or the key, with the panel open
    assertFalse(f.Preview.IsActive())
    assertEqual(repaints, 2, "the race-armed stop left the checkbox ticked")
    assertEqual(f.NS.GetSetting("state.testMode"), false)
end)
