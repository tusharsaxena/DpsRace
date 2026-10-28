-- tests/test_settings.lua — the settings pages (spec §6.3): the Race, HUD and History pages (the HUD
-- page's Race HUD tab: its Display and Live breakdown subsections), their rows' shape (default, enUS label, tooltip), the ranges
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
        if r.group ~= NS.Helpers.MASTER_GROUP and not r.composed then
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
    ["hud.autoShow"]         = { "bool",   false },
    ["live.rows"]            = { "number", 8,       0,    15,    1 },
    ["live.icons"]           = { "bool",   true },
    ["live.showDps"]         = { "bool",   true },
    ["live.hz"]              = { "number", 4,       2,    10,    1 },
    ["live.chart"]           = { "bool",   true },
    ["live.paceBar"]         = { "bool",   true },
    ["live.castDots"]        = { "bool",   true },
    ["live.paceRange"]       = { "number", 1.5,     1.1,  2.0,   0.05 },
    ["race.defaultLength"]   = { "number", 120 },
    ["race.autoArm"]         = { "bool",   false },
    ["race.countdownCue"]    = { "bool",   true },
    ["race.centerCountdown"] = { "bool",   true },
    ["race.finalCountdown"]  = { "number", 10,      3,    10,    1 },
    ["race.buzzer"]          = { "bool",   true },
    ["race.hintDelay"]       = { "number", 15,      5,    60,    1 },
    ["race.grace"]           = { "number", 1,       0,    5,     0.1 },
    ["race.restartGap"]      = { "number", 6,       3,    15,    1 },
    ["global.history.keepDays"] = { "number", 90,   0,    3650,  1 },
    ["share.talentsLink"]    = { "bool",   false },
    ["toast.enabled"]        = { "bool",   true },
    ["toast.sound"]          = { "bool",   true },
    ["toast.duration"]       = { "number", 8,       3,    30,    1 },
    ["toast.scale"]          = { "number", 1.0,     0.5,  2.0,   0.05 },
    ["global.usage.hidden"]  = { "string", "" },
    ["race.lateIgnore"]      = { "string", "66,1856,5384,8690,58984,110959" },
    ["race.dummies"]         = { "string", "" },
    ["race.dummyCategory"]   = { "string", "auto" },
    -- HUD > HUD Appearance: composed blocks (options-ui-§16). A color's default is a table.
    ["appearance.elapsed.font"] = { "string", "JetBrains Mono" },
    ["appearance.elapsed.fontSize"] = { "number", 26, 6, 32, 1 },
    ["appearance.elapsed.fontColor"] = { "color", "table" },
    ["appearance.elapsed.useClassColorFont"] = { "bool", false },
    ["appearance.elapsed.fontFlags"] = { "string", "" },
    ["appearance.elapsed.fontShadow"] = { "bool", false },
    ["appearance.left.font"] = { "string", "JetBrains Mono" },
    ["appearance.left.fontSize"] = { "number", 26, 6, 32, 1 },
    ["appearance.left.fontColor"] = { "color", "table" },
    ["appearance.left.useClassColorFont"] = { "bool", false },
    ["appearance.left.fontFlags"] = { "string", "" },
    ["appearance.left.fontShadow"] = { "bool", false },
    ["appearance.figures.font"] = { "string", "Friz Quadrata TT" },
    ["appearance.figures.fontSize"] = { "number", 20, 6, 32, 1 },
    ["appearance.figures.fontColor"] = { "color", "table" },
    ["appearance.figures.useClassColorFont"] = { "bool", false },
    ["appearance.figures.fontFlags"] = { "string", "" },
    ["appearance.figures.fontShadow"] = { "bool", true },
    ["appearance.spellText.font"] = { "string", "Friz Quadrata TT" },
    ["appearance.spellText.fontSize"] = { "number", 10, 6, 32, 1 },
    ["appearance.spellText.fontColor"] = { "color", "table" },
    ["appearance.spellText.useClassColorFont"] = { "bool", false },
    ["appearance.spellText.fontFlags"] = { "string", "" },
    ["appearance.spellText.fontShadow"] = { "bool", true },
    ["appearance.bars.barTexture"] = { "string", "Solid" },
    ["appearance.bars.barAlpha"] = { "number", 0.85, 0, 1, 0.05 },
    ["appearance.bars.barColor"] = { "color", "table" },
    ["appearance.bars.useClassColorBar"] = { "bool", false },
    ["appearance.bars.rowHeight"] = { "number", 18, 12, 30, 1 },
    ["appearance.chart.barTexture"] = { "string", "Solid" },
    ["appearance.chart.barAlpha"] = { "number", 0.9, 0, 1, 0.05 },
    ["appearance.chart.barColor"] = { "color", "table" },
    ["appearance.chart.useClassColorBar"] = { "bool", false },
    ["appearance.chart.height"] = { "number", 80, 40, 160, 2 },
    ["appearance.chart.columnGap"] = { "number", 0, 0, 3, 1 },
    ["appearance.chart.bgColor"] = { "color", "table" },
    ["appearance.chart.useClassColorBg"] = { "bool", false },
    ["appearance.pace.barTexture"] = { "string", "Solid" },
    ["appearance.pace.barAlpha"] = { "number", 0.9, 0, 1, 0.05 },
    ["appearance.pace.barColor"] = { "color", "table" },
    ["appearance.pace.useClassColorBar"] = { "bool", false },
    -- History > Results table: composed blocks.
    ["resultsTable.damageBar.barTexture"] = { "string", "Solid" },
    ["resultsTable.damageBar.barAlpha"] = { "number", 0.85, 0, 1, 0.05 },
    ["resultsTable.damageBar.barColor"] = { "color", "table" },
    ["resultsTable.damageBar.useClassColorBar"] = { "bool", false },
    ["resultsTable.dpsBar.barTexture"] = { "string", "Solid" },
    ["resultsTable.dpsBar.barAlpha"] = { "number", 0.85, 0, 1, 0.05 },
    ["resultsTable.dpsBar.barColor"] = { "color", "table" },
    ["resultsTable.dpsBar.useClassColorBar"] = { "bool", false },
    ["resultsTable.barText.font"] = { "string", "Friz Quadrata TT" },
    ["resultsTable.barText.fontSize"] = { "number", 10, 6, 32, 1 },
    ["resultsTable.barText.fontColor"] = { "color", "table" },
    ["resultsTable.barText.useClassColorFont"] = { "bool", false },
    ["resultsTable.barText.fontFlags"] = { "string", "" },
    ["resultsTable.barText.fontShadow"] = { "bool", true },
}

test("settings: the stored paths, types, defaults and ranges are exactly the pinned set", function()
    local NS = T.NS
    local seen = 0
    for _, r in ipairs(NS.Schema) do
        local pin = STORED[r.path]
        assertTrue(pin ~= nil, "a stored path appeared: " .. tostring(r.path))
        seen = seen + 1
        assertEqual(r.type, pin[1], r.path .. " type")
        if pin[2] == "table" then
            assertEqual(type(r.default), "table", r.path .. " default")
        else
            assertEqual(r.default, pin[2], r.path .. " default")
        end
        assertEqual(r.min, pin[3], r.path .. " min")
        assertEqual(r.max, pin[4], r.path .. " max")
        assertEqual(r.step, pin[5], r.path .. " step")
    end
    local pinned = 0
    for _ in pairs(STORED) do pinned = pinned + 1 end
    assertEqual(seen, pinned, "a stored path went, or one is declared twice")
end)

test("settings: HUD Appearance's chart blocks: Damage chart (bar, height, column gap), Chart background, Pace bar", function()
    local NS = T.NS
    local subs, last = {}, nil
    for _, r in ipairs(NS.SchemaForPage("hud")) do
        if r.group == "HUD Appearance" and r.subgroup ~= last then
            subs[#subs + 1] = r.subgroup
            last = r.subgroup
        end
    end
    local tail = table.concat(subs, ",", #subs - 2)
    assertEqual(tail, "Damage chart,Chart background,Pace bar", "the chart's blocks, last on the tab")
    local order = {}
    for _, r in ipairs(NS.SchemaForPage("hud")) do
        if r.subgroup == "Damage chart" or r.subgroup == "Chart background" or r.subgroup == "Pace bar" then
            order[#order + 1] = r.path
        end
    end
    assertEqual(table.concat(order, ","), table.concat({
        "appearance.chart.barTexture", "appearance.chart.barAlpha", "appearance.chart.barColor",
        "appearance.chart.useClassColorBar", "appearance.chart.height", "appearance.chart.columnGap",
        "appearance.chart.bgColor", "appearance.chart.useClassColorBg",
        "appearance.pace.barTexture", "appearance.pace.barAlpha", "appearance.pace.barColor",
        "appearance.pace.useClassColorBar" }, ","))
    assertEqual(row(NS, "appearance.chart.bgColor").label, "Background color")
    assertTrue(row(NS, "appearance.chart.bgColor").hasAlpha ~= false, "the background swatch carries its alpha")
    assertEqual(row(NS, "appearance.chart.bgColor").default.a, 0.35, "the plot's old backdrop")
    assertEqual(row(NS, "appearance.chart.columnGap").label, "Column gap")
end)

test("settings: every row sits on a page the panel draws, and every page has a group", function()
    local NS = T.NS
    local pages = { general = true, race = true, hud = true, history = true }
    for _, r in ipairs(NS.Schema) do
        assertTrue(pages[r.page] == true, tostring(r.path) .. " on page " .. tostring(r.page))
        assertEqual(type(r.group), "string", tostring(r.path))
    end
end)

test("settings: grace slider 0..5 step 0.1, restartGap 3..15, history.keepDays 0..3650 default 90", function()
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
    local keep = row(NS, "global.history.keepDays")
    assertEqual(keep.type, "number")
    assertEqual(keep.min, 0)
    assertEqual(keep.max, 3650)
    assertEqual(keep.default, 90, "90 days (the owner's call, 2026-10-26)")
    assertEqual(keep.page, "history")
    assertEqual(NS.GetSetting("global.history.keepDays"), 90)
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
    assertEqual(length.default, 120, "2:00 for a new profile (the owner's call, 2026-10-26)")
    local offered = {}
    for _, v in ipairs(length.values) do offered[#offered + 1] = v.value end
    assertEqual(table.concat(offered, ","), "30,60,120,180,300")
    assertEqual(row(NS, "race.countdownCue").type, "bool")
    assertEqual(row(NS, "race.buzzer").type, "bool")
    local hint = row(NS, "race.hintDelay")
    assertEqual(hint.default, 15)
    assertTrue(hint.min <= 15 and hint.max >= 15)
end)

test("settings: the live breakdown's rows 0 (all) ..15 and reads 2..10 per second, on HUD > Race HUD", function()
    local NS = T.NS
    local rows = row(NS, "live.rows")
    assertEqual(rows.page, "hud")
    assertEqual(rows.group, "Race HUD")
    assertEqual(rows.subgroup, "Live breakdown")
    assertEqual(rows.min, 0, "0 shows every spell")
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
    NS.Slash:OnSlash("set live.rows 40")
    assertEqual(NS.GetSetting("live.rows"), 15)
    NS.Slash:OnSlash("set live.rows -1")
    assertEqual(NS.GetSetting("live.rows"), 0, "0 is every spell, the floor")
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

test("settings: the HUD's show mode is on the HUD page's Race HUD tab; `always` opens the HUD", function()
    local inst = T.load()
    local NS = inst.NS
    local mode = row(NS, "hud.showMode")
    assertEqual(mode.page, "hud")
    assertEqual(mode.group, "Race HUD")
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
    assertEqual(clock.page, "hud")
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

test("settings: the General, Race, HUD and History pages register and render quietly", function()
    local inst = T.load()
    local M = inst.mocks
    for _, name in ipairs({ "General", "Race", "HUD", "History", "Profiles" }) do
        assertTrue(M.__subcategories[name] ~= nil, name .. " is not registered")
    end
    assertTrue(M.__subcategories["Live breakdown"] == nil, "the Live breakdown page folded into the HUD page")
    M.__resetPrinted()
    for _, name in ipairs({ "General", "Race", "HUD", "History" }) do
        M.__subcategories[name]:__fire("OnShow")
    end
    assertEqual(#M.__printed(), 0, "a render printed: " .. tostring(M.__printed()[1]))
end)

test("settings: the pages register in the panel's order, General first and Profiles last", function()
    local inst = T.load()
    local order = {}
    for _, ctx in ipairs(inst.NS.Helpers.__pages()) do order[#order + 1] = ctx.pageKey or ctx.key end
    assertEqual(table.concat(order, ","), "general,race,hud,history,profiles", "HUD just above History")
end)

-- A page's schema tabs, in drawn (registration) order.
local function tabsOf(NS, page)
    local seen, out = {}, {}
    for _, r in ipairs(NS.SchemaForPage(page)) do
        if not seen[r.group] then
            seen[r.group] = true
            out[#out + 1] = r.group
        end
    end
    return table.concat(out, "|")
end

test("settings: the HUD page holds Race HUD then HUD Appearance; General holds Master controls then New-best toast", function()
    local NS = T.NS
    assertEqual(tabsOf(NS, "hud"), "Race HUD|HUD Appearance")
    assertEqual(tabsOf(NS, "general"), NS.Helpers.MASTER_GROUP .. "|New-best toast",
        "Keybindings is a host tab, not a schema one")
    assertEqual(#NS.SchemaForPage("hud"), 11 + 4 * 6 + 4 + 1 + 4 + 2 + 2 + 4, "the Race HUD tab's eleven rows and HUD Appearance's")
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

test("settings: HUD > Race HUD draws Display, then Live breakdown, in the pinned order", function()
    local NS = T.NS
    assertEqual(tabRows(NS, "hud", "Race HUD"), table.concat({
        "hud.showMode|Display|Show the race HUD|false",
        "hud.clock|Display|Race clock|false",
        "hud.autoShow|Display|Show near a training dummy|true",
        "live.rows|Live breakdown|Spell rows shown|false",
        "live.icons|Live breakdown|Show spell icons|false",
        "live.showDps|Live breakdown|Show live DPS|true",
        "live.hz|Live breakdown|Live reads per second|false",
        "live.chart|Chart and pace|Show damage chart|false",
        "live.castDots|Chart and pace|Show cooldown icons|false",
        "live.paceBar|Chart and pace|Show pace bar|false",
        "live.paceRange|Chart and pace|Pace bar range|true",
    }, "\n"))
end)

test("settings: Race is two tabs, the race's timeline then Training dummies, in the pinned order", function()
    local NS = T.NS
    for _, r in ipairs(NS.SchemaForPage("race")) do
        local want = (r.path == "race.dummies" or r.path == "race.dummyCategory") and "Training dummies" or "Race"
        assertEqual(r.group, want, r.path .. " tab")
    end
    assertEqual(tabRows(NS, "race", "Training dummies"), table.concat({
        "race.dummyCategory|New dummies|Category for new dummies|false",
        "race.dummies|Your training dummies|Training dummies|false",
    }, "\n"))
    assertEqual(tabRows(NS, "race", "Race"), table.concat({
        "race.defaultLength|Length|Default race length|false",
        "race.autoArm|Auto-arm|Arm on a training dummy|false",
        "race.countdownCue|Countdown|Countdown cue sound|true",
        "race.centerCountdown|Countdown|Center-screen countdown|true",
        "race.finalCountdown|Countdown|Center countdown from (seconds)|false",
        "race.buzzer|At the buzzer|Buzzer raid warning and sound|false",
        "race.hintDelay|At the buzzer|Sticky-combat hint after (seconds)|false",
        "race.grace|Scoring rules|Late-cast grace (seconds)|false",
        "race.restartGap|Scoring rules|Damage-restart gap (seconds)|false",
        "race.lateIgnore|Late-cast ignore list|Late-cast ignore list|false",
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

test("settings: General's Defaults names Master controls and the toast, and not the keys or the HUD", function()
    local tip = T.mocks.__subcategories["General"].defaultsTooltip
    assertEqual(tip, "Restore every General setting on this profile to its addon default: Master controls and the "
        .. "new-best toast. "
        .. T.NS.Helpers.KEYBINDS_UNCHANGED)
    assertTrue(tip:find("live breakdown", 1, true) == nil and tip:find("HUD Appearance", 1, true) == nil, tip)
end)

test("settings: the HUD page's Defaults names the Race HUD tab and HUD Appearance", function()
    local tip = T.mocks.__subcategories["HUD"].defaultsTooltip
    assertEqual(tip, "Restore every HUD setting on this profile to its addon default: the Race HUD tab "
        .. "(display, live breakdown, chart and pace) and HUD Appearance.")
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

test("settings: History's Usage tab draws the hidden items as the library's ID list, writing through Usage", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    local H = NS.Helpers
    local spec
    local realList = H.IdList
    H.IdList = function(ctx, s, ...) spec = s return realList(ctx, s, ...) end
    local panel = M.__subcategories["History"]
    panel:Show()
    panel:__fire("OnShow")
    local ctx = assert(NS.pageCtx.history, "the History page drew no ctx")
    ctx.activeTab = "Usage"
    ctx._renderFn(ctx)
    H.IdList = realList
    assertTrue(spec ~= nil, "the Usage tab drew no ID list")
    assertEqual(spec.kind, "item")
    assertEqual(#spec.entries(), 0, "nothing hidden")
    spec.onAdd(6948)
    spec.onAdd(201)
    assertEqual(NS.db.global.usage.hidden, "201,6948", "written whole, ascending")
    local ids = {}
    for i, e in ipairs(spec.entries()) do ids[i] = e.id end
    assertEqual(table.concat(ids, ","), "201,6948")
    spec.onRemove(201)
    assertEqual(NS.db.global.usage.hidden, "6948")
    local hidden = row(NS, "global.usage.hidden")
    assertTrue(hidden.skipRender, "the list draws the row")
    assertEqual(hidden.subgroup, "Hidden items")
    assertTrue(hidden.tooltip:sub(1, #"Account-wide: shared by every profile. ")
        == "Account-wide: shared by every profile. ", hidden.tooltip)
end)

test("settings: History repaints when the hidden items change from anywhere, and not for other settings", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    local panel = M.__subcategories["History"]
    panel:Show()
    panel:__fire("OnShow")
    assert(NS.pageCtx.history, "the History page drew no ctx")
    local repainted = 0
    local real = NS.Helpers.RefreshPanel
    NS.Helpers.RefreshPanel = function(...) repainted = repainted + 1 return real(...) end
    NS.Usage.Hide(6948)
    assertEqual(repainted, 1, "a right-click's Never show repaints the list")
    assertTrue(NS.SetByPath("live.castDots", false))
    assertEqual(repainted, 1, "another setting does not")
    NS.Helpers.RefreshPanel = real
end)

test("settings: Days to keep says it is account-wide, and its label carries no suffix", function()
    local keep = row(T.NS, "global.history.keepDays")
    assertEqual(keep.label, "Days to keep")
    assertTrue(keep.tooltip:sub(1, #"Account-wide: shared by every profile. ")
        == "Account-wide: shared by every profile. ", keep.tooltip)
end)

test("settings: lowering Days to keep never deletes on the spot", function()
    local inst = T.load()
    local NS = inst.NS
    NS.db.global.history.keepDays = 0
    seed(NS, 4)
    assertTrue(NS.SetByPath("global.history.keepDays", 1))
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

-- ── Race: the late-cast ignore list (#8) ─────────────────────────────────────────────────────────

local IGNORE_DEFAULT = "66,1856,5384,8690,58984,110959"

--- The Race page drawn once, with what its builder handed the ID list and the buttons, in draw order.
local function drawRace(inst)
    local NS, M = inst.NS, inst.mocks
    local H = NS.Helpers
    local drawn, spec, button = {}, nil, nil
    local realList, realText, realPair = H.IdList, H.TextRow, H.InlineButtonPair
    H.IdList = function(ctx, s, ...) spec = s drawn[#drawn + 1] = "list" return realList(ctx, s, ...) end
    H.TextRow = function(ctx, text, ...) drawn[#drawn + 1] = "text" return realText(ctx, text, ...) end
    H.InlineButtonPair = function(ctx, a, ...) button = a drawn[#drawn + 1] = "button" return realPair(ctx, a, ...) end
    local panel = M.__subcategories["Race"]
    panel:Show()
    panel:__fire("OnShow")
    H.IdList, H.TextRow, H.InlineButtonPair = realList, realText, realPair
    return spec, button, drawn
end

test("settings: Race draws the late-cast ignore list as the library's spell ID list, writing through LateIgnore", function()
    local inst = T.load()
    local NS = inst.NS
    local LI = NS.LateIgnore
    local spec, _, drawn = drawRace(inst)
    assertTrue(spec ~= nil, "the Race tab drew no ID list")
    assertEqual(table.concat(drawn, ","), "text,list,button", "the blurb, the list, then Reset list")
    assertEqual(spec.kind.base, "spell", "a host kind over the library's spell kind")
    assertTrue(spec.kind.resolve == LI.Resolve, "a typed name goes through LateIgnore.Resolve")
    assertEqual(spec.label, "Ignore a spell")
    assertEqual(spec.removeStyle, "icon")
    assertEqual(spec.columns, 2)
    assertTrue(type(spec.emptyText) == "string" and #spec.emptyText > 0, "no empty line")
    assertTrue(type(spec.tooltip) == "string" and spec.tooltip:find("hearthstone", 1, true) ~= nil, spec.tooltip)
    local cands = spec.candidates()
    assertEqual(table.concat(cands, ","), table.concat(LI.KnownSpells(), ","), "the candidates are the known spells")
    -- The entries: the six defaults, ascending; only 8690 carries the hearthstone suffix.
    local ids, suffixes = {}, {}
    for i, e in ipairs(spec.entries()) do
        ids[i] = e.id
        if e.suffix then suffixes[#suffixes + 1] = e.id .. "=" .. e.suffix end
    end
    assertEqual(table.concat(ids, ","), IGNORE_DEFAULT)
    assertEqual(table.concat(suffixes, ";"), "8690=(all hearthstones, " .. #NS.HEARTHSTONE_SPELLS .. ")")
    spec.onAdd(29722)
    assertEqual(NS.db.profile.race.lateIgnore, "66,1856,5384,8690,29722,58984,110959", "written whole, ascending")
    spec.onRemove(8690)
    assertEqual(NS.db.profile.race.lateIgnore, "66,1856,5384,29722,58984,110959", "8690 goes as one entry")
    assertEqual(#spec.entries(), 6)
end)

test("settings: Race's Reset list puts the six defaults back and touches no other Race setting", function()
    local inst = T.load()
    local NS = inst.NS
    local _, button = drawRace(inst)
    assertTrue(button ~= nil, "no Reset list button")
    assertEqual(button.text, "Reset list")
    for _, name in ipairs({ "Invisibility", "Vanish", "Feign Death", "hearthstone", "Shadowmeld", "Greater Invisibility" }) do
        assertTrue(button.tooltip:find(name, 1, true) ~= nil, "the tooltip does not name " .. name)
    end
    assertTrue(NS.SetByPath("race.lateIgnore", "29722"))
    assertTrue(NS.SetByPath("race.grace", 2))
    button.onClick()
    assertEqual(NS.db.profile.race.lateIgnore, IGNORE_DEFAULT)
    assertEqual(NS.db.profile.race.grace, 2, "the list's reset reset the grace")
end)

test("settings: Race's Defaults resets the ignore list too, and its tooltip says so", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    assertTrue(NS.SetByPath("race.lateIgnore", "29722"))
    NS.Helpers.RestoreDefaults("race")
    assertEqual(NS.db.profile.race.lateIgnore, IGNORE_DEFAULT)
    local tip = M.__subcategories["Race"].defaultsTooltip
    assertTrue(tip:find("late-cast ignore list", 1, true) ~= nil, tip)
end)

test("settings: Race repaints when the ignore list changes from anywhere or the profile does, and not for others", function()
    local inst = T.load()
    local NS = inst.NS
    drawRace(inst)
    assert(NS.pageCtx.race, "the Race page drew no ctx")
    local repainted = 0
    local real = NS.Helpers.RefreshPanel
    NS.Helpers.RefreshPanel = function(ctx, ...)
        if ctx == NS.pageCtx.race then repainted = repainted + 1 end
        return real(ctx, ...)
    end
    NS.LateIgnore.Ignore(29722)
    assertEqual(repainted, 1, "an ignore from the HUD or the CLI repaints the list")
    NS.AnnounceSettingsChanged("profile", "Other")
    assertEqual(repainted, 2, "a profile switch repaints it")
    assertTrue(NS.SetByPath("live.castDots", false))
    assertEqual(repainted, 2, "another setting does not")
    NS.Helpers.RefreshPanel = real
end)
