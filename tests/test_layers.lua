-- tests/test_layers.lua — where every DpsRace frame sits in the client's draw order (frame-layering,
-- standard v2.88.0): the one layers table in core/Constants.lua, the Race HUD (MEDIUM, toplevel), the
-- Results window (HIGH, toplevel) with its detail pane in its own band over the list pane, the ability
-- timeline (DIALOG: a modal one strata above the Results window, toplevel), and the center-screen countdown (FULLSCREEN, mouse-disabled, below every menu).
--
-- Every case runs on a fresh instance. tests/wow_mock.lua installs the kit's frame-layer recorder
-- (tests/_kit/mock_layers.lua) on every mock, so a frame's strata, level and toplevel read back.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)

-- tests/wow_mock.lua installs the recorder on every mock.
local function inst() return T.load() end

-- ── the table ───────────────────────────────────────────────────────────────────────────────────

test("layers: one table names the addon's tiers by the standard's keys", function()
    local L = T.NS.Constants.LAYERS
    assertTrue(type(L) == "table", "NS.Constants.LAYERS exists")
    assertEqual(L.STRATA.HUD, "MEDIUM")
    assertEqual(L.STRATA.WINDOW, "HIGH")
    assertEqual(L.STRATA.MODAL, "DIALOG")
    assertEqual(L.STRATA.SCREEN_ALERT, "FULLSCREEN")
    assertEqual(L.LEVEL.DETAIL, 2)
    assertEqual(L.LEVEL.COVER, 30, "the popover band over a window's own content (frame-layering-§3)")
end)

test("layers: no strata string and no bare level number at a call site", function()
    local bad = {}
    for _, rel in ipairs(T.loadedAddonFiles) do
        if rel:match("%.lua$") and not rel:match("^libs/") then
            local fh = assert(io.open(T.root .. "/" .. rel, "r"))
            local n = 0
            for line in fh:lines() do
                n = n + 1
                if line:match('SetFrameStrata%(%s*["\']') or line:match("SetFrameLevel%(%s*%d") then
                    bad[#bad + 1] = rel .. ":" .. n
                end
            end
            fh:close()
        end
    end
    assertEqual(#bad, 0, "literal layering at " .. table.concat(bad, ", "))
end)

-- ── the windows ─────────────────────────────────────────────────────────────────────────────────

test("layers: the Race HUD is MEDIUM, toplevel and clamped", function()
    local i = inst()
    i.NS.Hud.Show()
    local f = i.NS.Hud.__ui().frame
    local l = i.mocks.__layers(f)
    assertEqual(l.strata, "MEDIUM")
    assertTrue(l.toplevel, "a click raises the HUD among MEDIUM frames (DPS-Z01)")
    assertTrue(l.clamped)
end)

test("layers: the Results window is HIGH, toplevel and clamped", function()
    local i = inst()
    i.NS.Results.Show()
    local l = i.mocks.__layers(i.NS.Results.__ui().frame)
    assertEqual(l.strata, "HIGH")
    assertTrue(l.toplevel)
    assertTrue(l.clamped)
end)

test("layers: the ability timeline is DIALOG, one strata above the Results window, toplevel and clamped", function()
    local i = inst()
    i.NS.Results.Show()
    assertTrue(i.NS.ResultsTimeline.Open(i.NS.Results.__ui().detail), "the timeline opens on the detail")
    local l = i.mocks.__layers(i.NS.ResultsTimeline.__ui().frame)
    assertEqual(l.strata, "DIALOG", "a modal opened from the HIGH Results window (P13)")
    assertTrue(l.toplevel)
    assertTrue(l.clamped)
end)

test("layers: the detail pane sits one band over the list pane, never by creation order", function()
    local i = inst()
    i.NS.Results.ShowTab("runs")
    local ui = i.NS.Results.__ui()
    local lay = i.mocks.__layers
    local W = lay(ui.frame).level
    assertEqual(lay(ui.body).level, W + 1, "the body is chrome")
    assertEqual(lay(ui.detail.frame).level, W + 3, "the detail pane is body + LEVEL.DETAIL (DPS-Z03)")
    assertEqual(lay(ui.panes.runs.frame).level, W + 2, "the Runs pane keeps body + 1")
    assertTrue(lay(ui.detail.content).level > lay(ui.detail.frame).level,
        "the detail's children are born in its raised band")
    assertTrue(lay(ui.detail.content).level <= W + 8, "content stays under the library grip (+10)")
end)

-- ── the countdown ───────────────────────────────────────────────────────────────────────────────

test("layers: the countdown is FULLSCREEN, below every menu", function()
    local f = RaceClock.new()
    assertTrue(f:arm(30))
    f:start(25)
    f:to(120)
    local u = f.NS.Countdown.__ui()
    assertTrue(u ~= nil, "the number is up")
    local l = f.M.__layers(u.frame)
    assertEqual(l.strata, "FULLSCREEN", "out of the menus' FULLSCREEN_DIALOG (DPS-Z02)")
    assertTrue(l.strata ~= "FULLSCREEN_DIALOG", "never in the popup tier")
end)
