-- tests/test_schema.lua — the schema rows, the single write seam and the Master controls tab.

local T = _G.DPSRACE_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

test("schema: the load-time shape check finds no error and every stored path resolves", function()
    local errors, _, missing = NS.ValidateSchema()
    assertEqual(errors, 0)
    assertEqual(missing, 0)
end)

test("schema: Master controls carries exactly the rows this addon has state for, in order", function()
    local paths = {}
    for _, row in ipairs(NS.SchemaForPage("general")) do
        if row.group == NS.Helpers.MASTER_GROUP then paths[#paths + 1] = row.path end
    end
    assertEqual(table.concat(paths, ","),
        "enabled,visibility,scale,locked,state.debugConsole,global.minimap.shown,state.testMode")
    assertEqual(NS.Helpers.MASTER_GROUP, "Master controls")
end)

test("schema: the Enable row is labeled with the brand", function()
    assertEqual(NS.FindSchemaRow("enabled").label, "Enable Ka0s DPS Race")
end)

test("schema: every row has a group, a label and a page", function()
    local pages = { general = true, race = true, hud = true, history = true }
    for _, row in ipairs(NS.Schema) do
        assertEqual(type(row.group), "string", tostring(row.path))
        assertEqual(type(row.label), "string", tostring(row.path))
        assertTrue(pages[row.page] == true, tostring(row.path))
    end
end)

test("schema: a write goes through the seam, reacts, and announces SETTINGS_CHANGED once", function()
    local inst = T.load()
    local seen = {}
    inst.NS.NewBusTarget():RegisterMessage(inst.NS.MSG.SETTINGS_CHANGED, function(_, path, value)
        seen[#seen + 1] = { path, value }
    end)
    assertTrue(inst.NS.SetByPath("locked", true))
    assertEqual(inst.NS.db.profile.locked, true)
    assertEqual(inst.NS.Hud.locked, true, "the row's reaction ran")
    assertEqual(#seen, 1)
    assertEqual(seen[1][1], "locked")
    assertEqual(seen[1][2], true)
end)

test("schema: a profile change announces SETTINGS_CHANGED through the one sender", function()
    -- architecture-§4: one sender per message. core/Database.lua's profile callbacks go through
    -- settings/Schema.lua's NS.AnnounceSettingsChanged, never a SendBus of their own.
    local inst = T.load()
    local NSi, calls, seen = inst.NS, {}, 0
    local real = NSi.AnnounceSettingsChanged
    NSi.AnnounceSettingsChanged = function(path, value)
        calls[#calls + 1] = path
        return real(path, value)
    end
    NSi.NewBusTarget():RegisterMessage(NSi.MSG.SETTINGS_CHANGED, function() seen = seen + 1 end)
    NSi.db:SetProfile("Other")
    assertEqual(table.concat(calls, ","), "profile")
    assertEqual(seen, 1, "the message went out once, through the announce")
end)

test("schema: an unknown path is refused and stores nothing", function()
    local inst = T.load()
    local ok = inst.NS.SetByPath("no.such.path", 3)
    assertFalse(ok)
    assertEqual(inst.NS.db.profile.no, nil)
end)

test("schema: the Minimap row reads SHOWN and stores LibDBIcon's inverted `hide`", function()
    local inst = T.load()
    local NSi = inst.NS
    assertEqual(NSi.GetSetting(NSi.MINIMAP_PATH), true)
    assertTrue(NSi.SetByPath(NSi.MINIMAP_PATH, false))
    assertEqual(NSi.db.global.minimap.hide, true)
    assertEqual(NSi.db.global.minimap.shown, nil, "no `shown` twin is ever stored")
    assertEqual(NSi.GetSetting(NSi.MINIMAP_PATH), false)
end)

test("schema: Reset all settings is a profile reset and never touches the Minimap button", function()
    local inst = T.load()
    local NSi = inst.NS
    NSi.SetByPath("visibility", "never")
    NSi.SetByPath(NSi.MINIMAP_PATH, false)
    NSi.Helpers.RestoreAllDefaults()
    assertEqual(NSi.GetSetting("visibility"), "always")
    assertEqual(NSi.db.global.minimap.hide, true, "the minimap button stayed hidden")
end)

test("schema: Test mode is a session-only checkbox over the preview", function()
    local inst = T.load()
    local NSi = inst.NS
    local row = NSi.FindSchemaRow("state.testMode")
    assertTrue(row.sessionOnly)
    assertTrue(NSi.SetByPath("state.testMode", true))
    assertTrue(NSi.Preview.IsActive())
    assertEqual(NSi.db.profile.state, nil, "nothing stored in the profile")
    assertTrue(NSi.SetByPath("state.testMode", false))
    assertFalse(NSi.Preview.IsActive())
end)

test("schema: entering combat ends test mode, and says so once", function()
    local inst = T.load()
    local NSi, M = inst.NS, inst.mocks
    NSi.SetByPath("state.testMode", true)
    M.__resetPrinted()
    assertEqual(M.__fireEvent("PLAYER_REGEN_DISABLED"), 1)
    assertFalse(NSi.Preview.IsActive())
    assertEqual(#M.__printed(), 1)
end)

test("schema: General visibility changes the registration set while enabled", function()
    local inst = T.load()
    local NSi, M = inst.NS, inst.mocks
    local function events()
        local out = {}
        for _, r in ipairs(M.__registrations()) do
            if r.target == NSi and r.kind == "event" then out[#out + 1] = r.event end
        end
        table.sort(out)
        return table.concat(out, ",")
    end
    assertEqual(events(), "PLAYER_REGEN_DISABLED")
    NSi.SetByPath("visibility", "inCombat")
    assertEqual(events(), "PLAYER_REGEN_DISABLED,PLAYER_REGEN_ENABLED")
    NSi.SetByPath("visibility", "always")
    assertEqual(events(), "PLAYER_REGEN_DISABLED")
end)

test("schema: a migration runs once and stamps the stored version", function()
    local inst = T.load({ init = false })
    local NSi = inst.NS
    local runs = 0
    local top = NSi.SCHEMA_VERSION + 1
    NSi.__migrationSteps[#NSi.__migrationSteps + 1] = { to = top, run = function() runs = runs + 1 end }
    NSi:InitDB()
    NSi:RunMigrations()
    NSi:RunMigrations()
    assertEqual(runs, 1)
    assertEqual(NSi.db.global.schemaVersion, top)
end)

test("schema: migration 4 keeps an old profile's expanded view and drops the timeline's place", function()
    local inst = T.load({ init = false })
    local NSi = inst.NS
    local old = { windows = { results = { expanded = { width = 1400, height = 600 } },
                              timeline = { point = "CENTER", width = 980, height = 560 } } }
    local kept = { windows = { results = { view = "collapsed" } } }
    local fresh = { windows = { hud = { width = 300 } } }
    local bare = {}
    _G.DpsRaceDB = { global = { schemaVersion = 3, schema = 3 },
                     profiles = { Old = old, Kept = kept, Fresh = fresh, Bare = bare } }
    inst.mocks._G.DpsRaceDB = _G.DpsRaceDB
    NSi:InitDB()
    NSi:RunMigrations()
    assertEqual(NSi.db.global.schemaVersion, NSi.SCHEMA_VERSION)
    assertEqual(old.windows.results.view, "expanded", "the old default's stripped view is written")
    assertEqual(old.windows.results.expanded.width, 1400, "its size kept")
    assertEqual(old.windows.timeline, nil, "the timeline's unread place dropped")
    assertEqual(kept.windows.results.view, "collapsed", "a stored view kept")
    assertEqual(fresh.windows.results, nil, "a profile that never stored the Results window keeps the default")
    assertEqual(next(bare), nil, "an empty profile untouched")
    -- Idempotent: a second pass changes nothing.
    old.windows.results.view = "collapsed"
    NSi:RunMigrations()
    assertEqual(old.windows.results.view, "collapsed", "the step ran twice")
end)

test("panel: the category registers eagerly and every page body renders on first show", function()
    local inst = T.load()
    local M = inst.mocks
    assertTrue(M.__mainPanel ~= nil, "the parent category registered at OnInitialize")
    assertTrue(M.__subcategories["General"] ~= nil, "General registered")
    assertTrue(M.__subcategories["Profiles"] ~= nil, "Profiles registered")
    M.__resetPrinted()
    M.__mainPanel:__fire("OnShow")
    M.__subcategories["General"]:__fire("OnShow")
    M.__subcategories["Profiles"]:__fire("OnShow")
    assertEqual(#M.__printed(), 0, "a render printed: " .. tostring(M.__printed()[1]))
    local dialog = M.LibStub("AceConfigDialog-3.0")
    assertEqual(dialog.__lastOpen and dialog.__lastOpen.name, "DpsRace-Profiles")
end)

test("panel: the landing page is the library's, with the logo and one row per verb", function()
    local NSs = T.NS
    assertEqual(NSs.LANDING.logo, "Interface\\AddOns\\DpsRace\\media\\logos\\dpsrace.logo.tga")
    assertEqual(#NSs.LANDING.sections[1].rows(), #NSs.COMMANDS)
    assertTrue(NSs.LANDING.notes():find("training dummies", 1, true) ~= nil)
end)

test("schema: a new profile and Reset all settings open each window at its minimum width", function()
    local inst = T.load()
    local NSi = inst.NS
    local W = NSi.defaults.profile.windows
    -- defaults/Profile.lua loads before the modules, so it keeps numbers; these pin them together.
    assertEqual(W.hud.width, NSi.Hud.MIN_WIDTH, "the HUD")
    assertEqual(W.results.expanded.width, NSi.Results.VIEWS.expanded.minWidth, "Results, expanded")
    assertEqual(W.results.collapsed.width, NSi.Results.VIEWS.collapsed.minWidth, "Results, collapsed")
    assertEqual(W.hud.height, 573, "the HUD's 560 plus the chart's icon row (UT-P11)")
    assertEqual(W.results.expanded.height, 560)
    assertEqual(W.results.collapsed.height, 560)
    assertEqual(type(W.results.collapsedSections), "table", "the detail's folded sections (UT-P10)")
    assertEqual(next(W.results.collapsedSections), nil, "a new profile folds no section")
    -- Wider windows, then /dr resetall's reset: back to the minimum widths.
    local p = NSi.db.profile
    p.windows.hud.width = 400
    p.windows.results.expanded.width, p.windows.results.collapsed.width = 1500, 1100
    p.windows.results.collapsedSections.timing = true
    NSi.Helpers.RestoreAllDefaults()
    p = NSi.db.profile
    assertEqual(p.windows.hud.width, NSi.Hud.MIN_WIDTH)
    assertEqual(p.windows.results.expanded.width, NSi.Results.VIEWS.expanded.minWidth)
    assertEqual(p.windows.results.collapsed.width, NSi.Results.VIEWS.collapsed.minWidth)
    assertEqual(next(p.windows.results.collapsedSections), nil, "every section open again")
end)
