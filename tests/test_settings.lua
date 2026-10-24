-- tests/test_settings.lua — the settings pages (spec §6.3): the Race and History pages and the General
-- page's Race HUD tab (its Display and Live breakdown subsections), their rows' shape (default, enUS label, tooltip), the ranges
-- the spec fixes, what a write reaches, and the History page's Purge history… act.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)

local function row(NS, path) return assert(NS.FindSchemaRow(path), "no schema row " .. path) end

local function hasOwnKey(NS, s)
    return type(s) == "string" and rawget(NS.L, s) ~= nil
end

test("settings: every schema row has default, enUS label and desc", function()
    local NS = T.NS
    assertTrue(#NS.Schema > 7, "only the Master controls are declared")
    for _, r in ipairs(NS.Schema) do
        local name = tostring(r.path)
        -- A session-only row stores nothing, so it has no default to restore, except one a reset must
        -- end (Test mode, options-ui-§15).
        assertTrue(r.default ~= nil or (r.sessionOnly and r.path ~= "state.testMode"), name .. " has no default")
        assertEqual(type(r.label), "string", name .. " label")
        local desc = r.tooltip or r.desc
        assertEqual(type(desc), "string", name .. " desc")
        assertTrue(#desc > 0, name .. " desc is empty")
        -- The composed Master rows carry the library's own words; every row this addon writes is
        -- listed in the enUS table, label and tooltip both.
        if r.group ~= NS.Helpers.MASTER_GROUP then
            assertTrue(hasOwnKey(NS, r.label), name .. " label is not in locales/enUS.lua: " .. r.label)
            assertTrue(hasOwnKey(NS, desc), name .. " tooltip is not in locales/enUS.lua")
        end
    end
end)

-- The stored-setting guard (settings layout, item 020): a layout pass moves, regroups and relabels
-- rows only. Every stored path, its type, default and range is pinned here, so a key that moves, a
-- default that drifts or a row that appears or goes fails this test, not a player's profile.
local STORED = {
    -- path                     type      default  min   max    step
    ["enabled"]              = { "bool",   true },
    ["visibility"]           = { "string", "always" },
    ["scale"]                = { "number", 1,       0.5,  2,     0.05 },
    ["locked"]               = { "bool",   false },
    ["state.debugConsole"]   = { "bool",   nil },
    ["global.minimap.shown"] = { "bool",   true },
    ["state.testMode"]       = { "bool",   false },
    ["hud.showMode"]         = { "string", "onArm" },
    ["hud.clock"]            = { "string", "both" },
    ["live.rows"]            = { "number", 8,       3,    15,    1 },
    ["live.icons"]           = { "bool",   true },
    ["live.showDps"]         = { "bool",   true },
    ["live.hz"]              = { "number", 4,       2,    10,    1 },
    ["race.defaultLength"]   = { "number", 180 },
    ["race.countdownCue"]    = { "bool",   true },
    ["race.centerCountdown"] = { "bool",   true },
    ["race.finalCountdown"]  = { "number", 10,      3,    10,    1 },
    ["race.buzzer"]          = { "bool",   true },
    ["race.hintDelay"]       = { "number", 15,      5,    60,    1 },
    ["race.grace"]           = { "number", 1,       0,    5,     0.1 },
    ["race.restartGap"]      = { "number", 6,       3,    15,    1 },
    ["global.history.keep"]  = { "number", 0,       0,    10000, 1 },
}

test("settings: the stored paths, types, defaults and ranges are exactly the pinned set", function()
    local NS = T.NS
    local seen = 0
    for _, r in ipairs(NS.Schema) do
        local pin = STORED[r.path]
        assertTrue(pin ~= nil, "a stored path appeared: " .. tostring(r.path))
        seen = seen + 1
        assertEqual(r.type, pin[1], r.path .. " type")
        assertEqual(r.default, pin[2], r.path .. " default")
        assertEqual(r.min, pin[3], r.path .. " min")
        assertEqual(r.max, pin[4], r.path .. " max")
        assertEqual(r.step, pin[5], r.path .. " step")
    end
    local pinned = 0
    for _ in pairs(STORED) do pinned = pinned + 1 end
    assertEqual(seen, pinned, "a stored path went, or one is declared twice")
end)

test("settings: every row sits on a page the panel draws, and every page has a group", function()
    local NS = T.NS
    local pages = { general = true, race = true, history = true }
    for _, r in ipairs(NS.Schema) do
        assertTrue(pages[r.page] == true, tostring(r.path) .. " on page " .. tostring(r.page))
        assertEqual(type(r.group), "string", tostring(r.path))
    end
end)

test("settings: grace slider 0..5 step 0.1, restartGap 3..15, history.keep 0..10000 default 0", function()
    local NS = T.NS
    local grace = row(NS, "race.grace")
    assertEqual(grace.type, "number")
    assertEqual(grace.min, 0)
    assertEqual(grace.max, 5)
    assertEqual(grace.step, 0.1)
    assertEqual(grace.default, 1.0)
    assertEqual(grace.page, "race")
    local gap = row(NS, "race.restartGap")
    assertEqual(gap.min, 3)
    assertEqual(gap.max, 15)
    assertEqual(gap.default, 6)
    local keep = row(NS, "global.history.keep")
    assertEqual(keep.type, "number")
    assertEqual(keep.min, 0)
    assertEqual(keep.max, 10000)
    assertEqual(keep.default, 0)
    assertEqual(keep.page, "history")
    assertEqual(NS.GetSetting("global.history.keep"), 0)
end)

test("settings: the scoring sliders say they apply to new runs", function()
    local NS = T.NS
    for _, path in ipairs({ "race.grace", "race.restartGap" }) do
        local tip = row(NS, path).tooltip
        assertTrue(tip:find("Applies to new runs", 1, true) ~= nil, path)
    end
end)

test("settings: the Race page's rows, ranges and defaults", function()
    local NS = T.NS
    local length = row(NS, "race.defaultLength")
    assertEqual(length.default, 180)
    local offered = {}
    for _, v in ipairs(length.values) do offered[#offered + 1] = v.value end
    assertEqual(table.concat(offered, ","), "30,60,120,180,300")
    assertEqual(row(NS, "race.countdownCue").type, "bool")
    assertEqual(row(NS, "race.buzzer").type, "bool")
    local hint = row(NS, "race.hintDelay")
    assertEqual(hint.default, 15)
    assertTrue(hint.min <= 15 and hint.max >= 15)
end)

test("settings: the live breakdown's rows 3..15 and reads 2..10 per second, on General > Race HUD", function()
    local NS = T.NS
    local rows = row(NS, "live.rows")
    assertEqual(rows.page, "general")
    assertEqual(rows.group, "Race HUD")
    assertEqual(rows.subgroup, "Live breakdown")
    assertEqual(rows.min, 3)
    assertEqual(rows.max, 15)
    assertEqual(rows.default, 8)
    local hz = row(NS, "live.hz")
    assertEqual(hz.min, 2)
    assertEqual(hz.max, 10)
    assertEqual(hz.default, 4)
    assertEqual(row(NS, "live.icons").type, "bool")
    assertEqual(row(NS, "live.showDps").type, "bool")
end)

test("settings: a write out of range is refused and stores nothing", function()
    local inst = T.load()
    local NS = inst.NS
    local M = inst.mocks
    M.__resetPrinted()
    NS.Slash:OnSlash("set race.grace 9")
    assertEqual(NS.GetSetting("race.grace"), 5, "a slider value is clamped to its range by the CLI")
    NS.Slash:OnSlash("set live.rows 2")
    assertEqual(NS.GetSetting("live.rows"), 3)
end)

test("settings: changing grace does not alter saved runs", function()
    local inst = T.load()
    local NS = inst.NS
    local old = NS.Recorder.NewRun(30)
    old.status = "complete"
    assertTrue(NS.Recorder.Save(old))
    assertEqual(old.race.grace, 1.0)
    assertTrue(NS.SetByPath("race.grace", 2.5))
    assertTrue(NS.SetByPath("race.restartGap", 10))
    local stored = NS.Recorder.Get(old.id)
    assertEqual(stored.race.grace, 1.0, "a saved run was re-graded")
    assertEqual(stored.race.restartGap, 6)
    local fresh = NS.Recorder.NewRun(30)
    assertEqual(fresh.race.grace, 2.5, "a new run takes the setting in force")
    assertEqual(fresh.race.restartGap, 10)
end)

test("settings: a live breakdown change redraws the HUD", function()
    local inst = T.load()
    local NS = inst.NS
    local refreshed = 0
    local real = NS.Hud.Refresh
    NS.Hud.Refresh = function() refreshed = refreshed + 1 return real() end
    for _, write in ipairs({ { "live.rows", 5 }, { "live.icons", false }, { "live.showDps", false },
                             { "live.hz", 8 } }) do
        local before = refreshed
        assertTrue(NS.SetByPath(write[1], write[2]))
        assertTrue(refreshed > before, write[1] .. " did not redraw the HUD")
    end
end)

test("settings: the HUD's show mode is a General tab of its own; `always` opens the HUD", function()
    local inst = T.load()
    local NS = inst.NS
    local mode = row(NS, "hud.showMode")
    assertEqual(mode.page, "general")
    assertTrue(mode.group ~= NS.Helpers.MASTER_GROUP, "the canonical tab is not extended by hand")
    assertEqual(mode.default, "onArm")
    assertFalse(NS.Hud.IsShown())
    assertTrue(NS.SetByPath("hud.showMode", "always"))
    assertTrue(NS.Hud.IsShown(), "always shows the HUD at once")
    assertFalse(NS.SetByPath("hud.showMode", "sometimes"))
end)

test("settings: the race clock is a Race HUD row: both, left or elapsed, default both, redrawing the HUD", function()
    local inst = T.load()
    local NS = inst.NS
    local clock = row(NS, "hud.clock")
    assertEqual(clock.page, "general")
    assertEqual(clock.group, row(NS, "hud.showMode").group, "beside the show mode, on the Race HUD tab")
    assertEqual(clock.default, "both")
    assertEqual(NS.GetSetting("hud.clock"), "both")
    local offered = {}
    for _, v in ipairs(clock.values) do offered[#offered + 1] = v.value end
    assertEqual(table.concat(offered, ","), "both,left,elapsed")
    local refreshed = 0
    local real = NS.Hud.Refresh
    NS.Hud.Refresh = function() refreshed = refreshed + 1 return real() end
    assertTrue(NS.SetByPath("hud.clock", "left"))
    assertTrue(refreshed > 0, "the HUD was not redrawn")
    assertEqual(NS.db.profile.hud.clock, "left")
    assertFalse(NS.SetByPath("hud.clock", "sideways"))
    assertEqual(NS.db.profile.hud.clock, "left")
end)

test("settings: the General, Race and History pages register and render quietly", function()
    local inst = T.load()
    local M = inst.mocks
    for _, name in ipairs({ "General", "Race", "History", "Profiles" }) do
        assertTrue(M.__subcategories[name] ~= nil, name .. " is not registered")
    end
    assertTrue(M.__subcategories["Live breakdown"] == nil, "the Live breakdown page folded into General")
    M.__resetPrinted()
    for _, name in ipairs({ "General", "Race", "History" }) do
        M.__subcategories[name]:__fire("OnShow")
    end
    assertEqual(#M.__printed(), 0, "a render printed: " .. tostring(M.__printed()[1]))
end)

test("settings: the pages register in the panel's order, General first and Profiles last", function()
    local inst = T.load()
    local order = {}
    for _, ctx in ipairs(inst.NS.Helpers.__pages()) do order[#order + 1] = ctx.pageKey or ctx.key end
    assertEqual(table.concat(order, ","), "general,race,history,profiles")
end)

-- The tab's rows in drawn order: path, subgroup, label, and whether the row opens a new line.
local function tabRows(NS, page, group)
    local out = {}
    for _, r in ipairs(NS.SchemaForPage(page)) do
        if r.group == group then
            out[#out + 1] = table.concat({ r.path, tostring(r.subgroup), r.label, tostring(r.startsLine == true) }, "|")
        end
    end
    return table.concat(out, "\n")
end

test("settings: General > Race HUD draws Display, then Live breakdown, in the pinned order", function()
    local NS = T.NS
    assertEqual(tabRows(NS, "general", "Race HUD"), table.concat({
        "hud.showMode|Display|Show the race HUD|false",
        "hud.clock|Display|Race clock|false",
        "live.rows|Live breakdown|Spell rows shown|false",
        "live.icons|Live breakdown|Show spell icons|false",
        "live.showDps|Live breakdown|Show live DPS|true",
        "live.hz|Live breakdown|Live reads per second|false",
    }, "\n"))
end)

test("settings: Race is a one-tab page along the race's timeline, in the pinned order", function()
    local NS = T.NS
    for _, r in ipairs(NS.SchemaForPage("race")) do assertEqual(r.group, "Race", r.path .. " tab") end
    assertEqual(tabRows(NS, "race", "Race"), table.concat({
        "race.defaultLength|Length|Default race length|false",
        "race.countdownCue|Countdown|Countdown cue sound|true",
        "race.centerCountdown|Countdown|Center-screen countdown|true",
        "race.finalCountdown|Countdown|Center countdown from (seconds)|false",
        "race.buzzer|At the buzzer|Buzzer raid warning and sound|false",
        "race.hintDelay|At the buzzer|Sticky-combat hint after (seconds)|false",
        "race.grace|Scoring rules|Late-cast grace (seconds)|false",
        "race.restartGap|Scoring rules|Damage-restart gap (seconds)|false",
    }, "\n"))
end)

test("settings: the sticky-combat hint's tooltip states its range", function()
    local tip = row(T.NS, "race.hintDelay").tooltip
    assertTrue(tip:sub(-#"5 to 60 seconds.") == "5 to 60 seconds.", tip)
end)

test("settings: the show mode's tooltip points at General visibility", function()
    local tip = row(T.NS, "hud.showMode").tooltip
    assertTrue(tip:find("General visibility on Master controls still applies: while it hides the addon, "
        .. "the HUD stays hidden whatever this says.", 1, true) ~= nil, tip)
end)

test("settings: General's Defaults says it covers the live breakdown, and not the keys", function()
    local tip = T.mocks.__subcategories["General"].defaultsTooltip
    assertEqual(tip, "Restore every General setting on this profile to its addon default, including the "
        .. "Race HUD's live breakdown. " .. T.NS.Helpers.KEYBINDS_UNCHANGED)
end)

-- ── History: stored count, Purge history… ────────────────────────────────────────────────────────

local function seed(NS, n)
    for _ = 1, n do
        local run = NS.Recorder.NewRun(30)
        run.status = "complete"
        run.result = { damage = 100, dps = 10 }
        NS.Recorder.Save(run)
    end
end

test("settings: History says how many runs are stored", function()
    local inst = T.load()
    local NS = inst.NS
    seed(NS, 3)
    assertTrue(NS.History.StoredLine():find("3 runs", 1, true) ~= nil, NS.History.StoredLine())
    NS.db.global.runs = {}
    assertTrue(NS.History.StoredLine():find("0 runs", 1, true) ~= nil)
end)

test("settings: Purge history… asks first, then deletes through Recorder.DeleteAll", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    seed(NS, 2)
    local shown = {}
    M.StaticPopup_Show = function(name) shown[#shown + 1] = name end
    local changed = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.RUNS_CHANGED, function() changed = changed + 1 end)
    NS.History.ConfirmDeleteAll()
    assertEqual(shown[1], "DPSRACE_DELETE_ALL_RUNS")
    assertEqual(#NS.Recorder.All(), 2, "nothing goes before the player confirms")
    M.StaticPopupDialogs.DPSRACE_DELETE_ALL_RUNS.OnAccept()
    assertEqual(#NS.Recorder.All(), 0)
    assertEqual(changed, 1)
end)

test("settings: Purge history… is refused while a race is armed", function()
    local f = RaceClock.new()
    local NS, M = f.NS, f.M
    seed(NS, 1)
    local shown = 0
    M.StaticPopup_Show = function() shown = shown + 1 end
    assertTrue(NS.Race.Arm(30))
    M.__resetPrinted()
    NS.History.ConfirmDeleteAll()
    assertEqual(shown, 0)
    assertEqual(#M.__printed(), 1)
    M.StaticPopupDialogs.DPSRACE_DELETE_ALL_RUNS.OnAccept()
    assertEqual(#NS.Recorder.All(), 1, "an accept left over from before the arm still deleted")
end)

test("settings: History ends with Purge history…, after the stored count, under no heading of its own", function()
    local inst = T.load()
    local H, M = inst.NS.Helpers, inst.mocks
    local drawn = {}
    local realText, realSection, realPair = H.TextRow, H.Section, H.InlineButtonPair
    H.TextRow = function(ctx, text, ...) drawn[#drawn + 1] = "text" return realText(ctx, text, ...) end
    H.Section = function(ctx, text, ...) drawn[#drawn + 1] = "section:" .. tostring(text) return realSection(ctx, text, ...) end
    local button
    H.InlineButtonPair = function(ctx, a, ...)
        button = a
        drawn[#drawn + 1] = "button"
        return realPair(ctx, a, ...)
    end
    M.__subcategories["History"]:__fire("OnShow")
    for _, d in ipairs(drawn) do assertTrue(d ~= "section:Danger zone", "the builder still draws Danger zone") end
    assertEqual(drawn[#drawn], "button", "Purge history… is not the tab's last act")
    assertEqual(drawn[#drawn - 1], "text", "the stored count does not come just before the button")
    assertEqual(button.text, "Purge history\226\128\166")
    assertEqual(button.tooltip, "Deletes every stored run. Asks for confirmation. Personal bests go with them.")
end)

test("settings: Runs to keep says it is account-wide, and its label carries no suffix", function()
    local keep = row(T.NS, "global.history.keep")
    assertEqual(keep.label, "Runs to keep")
    assertTrue(keep.tooltip:sub(1, #"Account-wide: shared by every profile. ")
        == "Account-wide: shared by every profile. ", keep.tooltip)
end)

test("settings: lowering Runs to keep never deletes on the spot", function()
    local inst = T.load()
    local NS = inst.NS
    seed(NS, 4)
    assertTrue(NS.SetByPath("global.history.keep", 1))
    assertEqual(#NS.Recorder.All(), 4, "the prune runs at login and after a saved run (spec §7)")
end)

test("settings: the global reset confirms with options-ui-§12's one wording, verbatim", function()
    local inst = T.load()
    local d = inst.mocks.StaticPopupDialogs.DPSRACE_RESET_ALL
    assertEqual(d.text, "Reset this profile to the addon's defaults? Everything you have configured or added in it "
        .. "is discarded \226\128\148 your other profiles are not affected.")
    assertEqual(d.button1, "Yes")
    assertEqual(d.button2, "No")
    assertTrue(d.timeout == 0 and d.whileDead == true and d.hideOnEscape == true)
end)
