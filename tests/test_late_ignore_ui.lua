-- tests/test_late_ignore_ui.lua — the late-cast ignore list's actions in the Results window (#8, I3):
-- the run detail's Flags box (its dimmed ignored line, its right-click menu and the re-score after a
-- pick), the run row's right-click submenu, and no menu on the sample history (D-7). The HUD result
-- card's right-click is in tests/test_hud_layout.lua; the pure halves are in tests/test_late_ignore.lua.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local FEIGN, INCINERATE = 5384, 29722

local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
    end }
    i.R = i.NS.Results
    return i
end

--- A stored complete 3:00 cleave run by Lanfear (Destruction) with these late casts ({ t, spellID }).
local function mkRun(id, casts)
    local late = {}
    for n, c in ipairs(casts or {}) do late[n] = { t = c[1], spellID = c[2] } end
    return {
        id = id, schema = 1, status = "complete", addon = "0.1.0", date = NOW - 3600,
        race = { length = 180, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction" },
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = 18000000, dps = 100000, tail = 2 },
        flags = { lateCasts = late, reloaded = false, died = false },
        spells = { { id = INCINERATE, dmg = 18000000 } },
        note = "",
    }
end

local function seed(i, runs)
    for _, run in ipairs(runs) do i.NS.db.global.runs[run.id] = run end
    i.NS.Bests.Invalidate()
end

local function detail(i) return assert(i.R.__ui(), "the window was never built").detail end

local function colored(fs, c)
    return fs.__color ~= nil and fs.__color[1] == c[1] and fs.__color[2] == c[2] and fs.__color[3] == c[3]
end

test("late ignore ui: the detail's Flags box dims the ignored line and its right-click ignores a spell", function()
    local i = inst()
    seed(i, { mkRun("m", { { 20.6, FEIGN }, { 2.0, INCINERATE } }) })
    i.R.ShowRun("m")
    local d = detail(i)
    assertTrue(d.w.flags:IsShown())
    assertEqual(d.w.flagRows[1].main:GetText(), "1 late cast")
    assertEqual(d.w.flagRows[2].main:GetText(), "1 ignored late cast")
    assertTrue(colored(d.w.flagRows[2].main, i.NS.ResultsDetail.IGNORED), "the ignored line is dimmed")
    assertFalse(colored(d.w.flagRows[1].main, i.NS.ResultsDetail.IGNORED), "the counted line is not")
    d.w.flags:__fire("OnMouseUp", "RightButton")
    local menu = i.mocks.__lastMenu
    assertEqual(menu.titles[1], "Late casts")
    menu:Click("Ignore Incinerate for late casts")
    assertTrue(i.NS.LateIgnore.IsIgnored(INCINERATE))
    -- SETTINGS_CHANGED redrew the detail: no flag left, the box kept for the undo.
    assertEqual(d.w.flagRows[1].main:GetText(), "2 ignored late casts")
    assertTrue(d.w.flags:IsShown(), "only ignored casts: the box still shows")
    assertFalse(i.NS.ResultsRuns.IsFlagged(i.NS.Recorder.Get("m")), "re-scored clean")
    d.w.flags:__fire("OnMouseUp", "RightButton")
    i.mocks.__lastMenu:Click("Stop ignoring Incinerate")
    assertFalse(i.NS.LateIgnore.IsIgnored(INCINERATE))
    assertTrue(i.NS.ResultsRuns.IsFlagged(i.NS.Recorder.Get("m")))
    -- A left click opens nothing.
    local before = #i.mocks.__menus
    d.w.flags:__fire("OnMouseUp", "LeftButton")
    assertEqual(#i.mocks.__menus, before)
end)

test("late ignore ui: the row menu holds an Ignore for late casts submenu only when the run has a late cast", function()
    local i = inst()
    local m, c = mkRun("m", { { 2.0, INCINERATE }, { 1.4, FEIGN } }), mkRun("c")
    seed(i, { m, c })
    i.R.ShowRun("m")
    assertTrue(i.R.RowMenu(m, detail(i).frame))
    local sub = i.mocks.__lastMenu:Find("Ignore for late casts")
    assertTrue(sub ~= nil)
    assertEqual(#sub.children, 2)
    assertEqual(sub.children[1].text, "Ignore Incinerate for late casts")
    assertEqual(sub.children[2].text, "Stop ignoring Feign Death")
    sub.children[1].setSelected()
    assertTrue(i.NS.LateIgnore.IsIgnored(INCINERATE))
    i.R.RowMenu(c, detail(i).frame)
    assertNil(i.mocks.__lastMenu:Find("Ignore for late casts"), "a run with no late cast")
end)

test("late ignore ui: the sample history offers no ignore menu (D-7)", function()
    local i = inst()
    local s = mkRun("s", { { 2.0, INCINERATE } })
    i.NS.ResultsSource.Use({ runs = { s } })
    i.R.ShowRun("s")
    local before = #i.mocks.__menus
    detail(i).w.flags:__fire("OnMouseUp", "RightButton")
    assertEqual(#i.mocks.__menus, before, "no menu on a sample run's flags")
    i.R.RowMenu(s, detail(i).frame)
    assertNil(i.mocks.__lastMenu:Find("Ignore for late casts"))
    i.NS.ResultsSource.Restore()
end)
