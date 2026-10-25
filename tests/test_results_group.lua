-- tests/test_results_group.lua — the Runs list's Group by (modules/Results_Runs.lua, the grouping in
-- modules/Results_Table.lua) and its saved views: every mode's headers, their order and folding, the
-- time modes' length-colored labels and stable fold keys, and Save / Reset / Clear. Peeled out of
-- tests/test_results.lua (layout-§1's 1500-line cap); the helpers are that suite's.

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
        target = { npcID = 225983, name = "Cleave Training Dummy", category = "cleave", count = 5 },
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
local function runsPane(i) return assert(ui(i).panes.runs, "the Runs tab was never built") end
local function visible(pane) return pane.list:Visible() end

test("results: Group by character, class & spec or target, with folding headers", function()
    local i = inst()
    local Runs = i.NS.ResultsRuns
    seed(i, {
        mkRun("a", { result = { damage = 1, dps = 300000 } }),
        mkRun("b", { target = { category = "boss", count = 1 }, result = { damage = 1, dps = 100000 },
                     date = NOW - 2 * HOUR }),
        mkRun("m", { char = "mage", result = { damage = 1, dps = 200000 }, date = NOW - 3 * HOUR }),
    })
    i.R.Show()
    local pane = runsPane(i)
    pane:SetFilter("char", "all")
    pane:SetFilter("spec", "all")
    assertEqual(pane.filters.group, "full", "a new profile groups by Full")
    pane:SetFilter("group", "none")
    local opts = Runs.Options(i.NS.Recorder.All()).group
    assertEqual(opts[1].label, "Group: None")
    assertEqual(opts[2].label, "Group: Full")
    assertEqual(#opts, 8)
    assertEqual(opts[8].label, "Group: Spec + target + time")
    local function shape()
        local out = {}
        for _, row in ipairs(visible(pane)) do
            out[#out + 1] = row.group and ("[" .. row.group.label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                .. " " .. row.group.count .. "]") or row.run.id
        end
        return table.concat(out, ",")
    end
    pane.dropdowns.group.onSelect("target")
    assertEqual(shape(), "[Target: Cleave 2],a,m,[Target: Boss-level 1],b", "the catalog's order, newest first inside")
    pane.dropdowns.group.onSelect("char")
    assertEqual(shape(), "[Character: Kaosmage 1],m,[Character: Lanfear 2],a,b")
    pane.dropdowns.group.onSelect("classSpec")
    assertEqual(shape(), "[Class & spec: Mage \194\183 Fire 1],m,[Class & spec: Warlock \194\183 Destruction 2],a,b")
    -- A header click folds its group; another unfolds it.
    visible(pane)[1]:__fire("OnClick")
    assertEqual(shape(), "[Class & spec: Mage \194\183 Fire 1],[Class & spec: Warlock \194\183 Destruction 2],a,b")
    visible(pane)[1]:__fire("OnClick")
    assertEqual(shape(), "[Class & spec: Mage \194\183 Fire 1],m,[Class & spec: Warlock \194\183 Destruction 2],a,b")
    -- The grouped column's header flips the groups' order.
    pane.dropdowns.group.onSelect("char")
    pane.list.heads[3]:__fire("OnClick")
    assertEqual(shape(), "[Character: Lanfear 2],a,b,[Character: Kaosmage 1],m")
    pane.dropdowns.group.onSelect("none")
    assertEqual(shape(), "a,b,m")
end)

test("results: Group by time, and by target type and time, shortest first", function()
    local i = inst()
    local Runs = i.NS.ResultsRuns
    local function len(n) return { length = n, grace = 1.0, restartGap = 6, startSource = "meterSession" } end
    local boss = { category = "boss", count = 1 }
    seed(i, {
        mkRun("c3", { result = { damage = 1, dps = 300000 } }),
        mkRun("c1", { race = len(60), date = NOW - 2 * HOUR }),
        mkRun("b3", { target = boss, date = NOW - 3 * HOUR }),
        mkRun("b2", { target = boss, race = len(120), date = NOW - 4 * HOUR }),
        mkRun("c7", { race = len(420), date = NOW - 5 * HOUR }),
    })
    i.R.Show()
    local pane = runsPane(i)
    pane:SetFilter("char", "all")
    pane:SetFilter("spec", "all")
    local opts = Runs.Options(i.NS.Recorder.All()).group
    assertEqual(opts[6].value, "length")
    assertEqual(opts[6].label, "Group: Time")
    assertEqual(opts[7].value, "targetLength")
    assertEqual(opts[7].label, "Group: Target + time")
    local function shape()
        local out = {}
        for _, row in ipairs(visible(pane)) do
            out[#out + 1] = row.group and ("[" .. row.group.label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                .. " " .. row.group.count .. "]") or row.run.id
        end
        return table.concat(out, ",")
    end
    pane.dropdowns.group.onSelect("length")
    assertEqual(shape(), "[Time: 1:00 1],c1,[Time: 2:00 1],b2,[Time: 3:00 2],c3,b3,[Time: 7:00 1],c7",
        "shortest first, newest first inside")
    -- The time wears its length color: a preset's hue, the neutral gray off the presets.
    local Tbl = i.NS.ResultsTable
    local headers = {}
    for _, row in ipairs(visible(pane)) do if row.group then headers[#headers + 1] = row.group end end
    assertEqual(headers[1].label, "Time: |c" .. Tbl.Hex(Tbl.LengthColor(60)) .. "1:00|r")
    assertEqual(headers[4].label, "Time: |c" .. Tbl.Hex(Tbl.LENGTH_NEUTRAL) .. "7:00|r")
    assertEqual(headers[1].key, "length:60", "the fold key is the mode's and the length's")
    -- The Time header flips the groups' order.
    pane.list:SetSort("time")
    assertEqual(shape(), "[Time: 7:00 1],c7,[Time: 3:00 2],c3,b3,[Time: 2:00 1],b2,[Time: 1:00 1],c1")
    pane.dropdowns.group.onSelect("targetLength")
    assertEqual(shape(), "[Target: Cleave \194\183 1:00 1],c1,[Target: Cleave \194\183 3:00 1],c3,"
        .. "[Target: Cleave \194\183 7:00 1],c7,[Target: Boss-level \194\183 2:00 1],b2,"
        .. "[Target: Boss-level \194\183 3:00 1],b3", "the catalog's order, then shortest first")
    -- A fold holds by key across a redraw and a mode round trip, and never reaches another mode.
    visible(pane)[1]:__fire("OnClick")
    assertEqual(pane.list.collapsed["cleave|60"], true)
    pane:Refresh()
    assertEqual(shape():sub(1, 34), "[Target: Cleave \194\183 1:00 1],[Target")
    pane.dropdowns.group.onSelect("length")
    assertEqual(shape():sub(1, 24), "[Time: 1:00 1],c1,[Time:", "the time mode's 1:00 is not folded")
    pane.dropdowns.group.onSelect("targetLength")
    assertEqual(visible(pane)[2].group ~= nil, true, "the pair's fold is still there")
    -- A run with no length groups last, as a dash (never "0:00"), in either mode.
    seed(i, { mkRun("x", { race = NONE, date = NOW - 6 * HOUR }) })
    pane.dropdowns.group.onSelect("length")
    local rows = visible(pane)
    assertEqual(rows[#rows - 1].group.key, "length:nil")
    assertEqual((rows[#rows - 1].group.label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")),
        "Time: \226\128\148", "a run with no length is labeled 0:00")
    assertEqual(rows[#rows].run.id, "x")
    pane.dropdowns.group.onSelect("targetLength")
    local header
    for _, row in ipairs(visible(pane)) do
        if row.group and row.group.key == "cleave|nil" then header = row.group end
    end
    assertEqual((header.label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")),
        "Target: Cleave \194\183 \226\128\148", "the pair's no-length header is labeled 0:00")
end)

test("results: Save, Reset and Clear the Runs view, and a saved view is what the window opens on", function()
    local i = inst()
    seed(i, { mkRun("a"), mkRun("m", { char = "mage", date = NOW - 2 * HOUR }) })
    i.R.Show()
    local pane = runsPane(i)
    assertEqual(pane.barH, 32, "expanded: the filter bar is one row")
    assertEqual(pane.viewButtons.save.label.__text, "Save")
    pane:SetFilter("char", "all")
    pane:SetFilter("spec", "all")
    pane:SetFilter("group", "target")
    pane.list:SetSort("dps")
    pane.viewButtons.save:__fire("OnClick")
    local saved = i.NS.db.profile.views.runs
    assertEqual(saved.filters.char, "all")
    assertEqual(saved.filters.group, "target")
    assertEqual(saved.sortKey, "dps")
    -- Clear returns to the saved view after the filters moved.
    pane:SetFilter("char", "current")
    pane:SetFilter("group", "none")
    pane.viewButtons.clear:__fire("OnClick")
    assertEqual(pane.filters.char, "all")
    assertEqual(pane.filters.group, "target")
    assertEqual(pane.list.sortKey, "dps")
    -- A rebuilt view (a new login) opens on the saved view.
    local fresh = i.NS.ResultsRuns.Build(i.mocks.UIParent)
    assertEqual(fresh.filters.char, "all")
    assertEqual(fresh.list.sortKey, "dps")
    -- Reset deletes it and applies the stock view.
    pane.viewButtons.reset:__fire("OnClick")
    assertEqual(i.NS.db.profile.views, nil)
    assertEqual(pane.filters.char, "current")
    assertEqual(pane.filters.group, "full", "the stock view groups by Full")
    assertEqual(pane.list.sortKey, "date")
    assertTrue(pane.list.sortDesc)
    -- Clear with nothing saved is the stock view too.
    pane:SetFilter("hideFlagged", true)
    pane.viewButtons.clear:__fire("OnClick")
    assertFalse(pane.filters.hideFlagged)
    -- The time modes save and come back like any other.
    pane:SetFilter("group", "targetLength")
    pane.viewButtons.save:__fire("OnClick")
    assertEqual(i.NS.db.profile.views.runs.filters.group, "targetLength")
    pane:SetFilter("group", "length")
    pane.viewButtons.clear:__fire("OnClick")
    assertEqual(pane.filters.group, "targetLength")
    assertEqual(i.NS.ResultsRuns.Build(i.mocks.UIParent).filters.group, "targetLength")
end)

test("results: hovering Save, Reset or Clear shows its tooltip without an error", function()
    -- In game the shared button's OnEnter handed GameTooltip:SetText a nil title: the view buttons
    -- set a bare string where the button reads { title, text }.
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.Show()
    local pane = runsPane(i)
    local shown = {}
    i.mocks.GameTooltip = {
        SetOwner = function() end, Show = function() end, Hide = function() end,
        AddLine = function(_, text) shown[#shown + 1] = text end,
        SetText = function(_, text)
            assertTrue(type(text) == "string", "SetText needs a string, got " .. type(text))
            shown[#shown + 1] = text
        end,
    }
    for _, key in ipairs({ "save", "reset", "clear" }) do
        local b = pane.viewButtons[key]
        assertEqual(type(b.tip), "table", key .. ": the tooltip is { title, text }")
        b:__fire("OnEnter")
    end
    assertEqual(shown[1], "Save")
    assertTrue(shown[2]:find("default view", 1, true) ~= nil, "the Save tooltip's text follows its title")
    local b = pane.viewButtons.save
    b.tip = "a bare title"
    b:__fire("OnEnter")
    assertEqual(shown[#shown], "a bare title", "a bare string tooltip still shows, as the title")
end)

test("results: Group by spec + target + time, one group per board, the spec in its class color", function()
    local i = inst()
    seed(i, {
        mkRun("a", { race = { length = 120, grace = 1 } }),
        mkRun("b", { race = { length = 60, grace = 1 }, date = NOW - HOUR }),
        mkRun("c", { race = { length = 120, grace = 1 }, date = NOW - 2 * HOUR }),
        mkRun("m", { char = "mage", race = { length = 60, grace = 1 }, date = NOW - 3 * HOUR }),
    })
    i.R.Show()
    local pane = runsPane(i)
    pane:SetFilter("char", "all")
    pane:SetFilter("spec", "all")
    pane:SetFilter("group", "specTargetLength")
    local Tbl = i.NS.ResultsTable
    local headers = {}
    for _, row in ipairs(visible(pane)) do
        if row.group then headers[#headers + 1] = row.group end
    end
    assertEqual(#headers, 3, "Destruction cleave 1:00 and 2:00, Fire cleave 1:00")
    local hex = function(c) return "|c" .. Tbl.Hex(c) end
    assertEqual(headers[1].label, "Spec: " .. hex(Tbl.ClassColor("MAGE")) .. "Fire|r \194\183 "
        .. hex(Tbl.CATEGORY_COLORS.cleave) .. "Cleave|r \194\183 " .. hex(Tbl.LengthColor(60)) .. "1:00|r",
        "classes in name order (Mage before Warlock), the spec in its class color")
    assertEqual(headers[2].count, 1)
    assertEqual(headers[3].count, 2, "the two Destruction 2:00 cleave runs share one board")
end)

test("results: Group by Full: character, class, spec, target and time, in that order", function()
    local i = inst()
    seed(i, {
        mkRun("a", { race = { length = 120, grace = 1 } }),
        mkRun("b", { race = { length = 60, grace = 1 }, date = NOW - HOUR }),
        mkRun("c", { race = { length = 120, grace = 1 }, date = NOW - 2 * HOUR }),
        mkRun("m", { char = "mage", race = { length = 60, grace = 1 }, date = NOW - 3 * HOUR }),
    })
    i.R.Show()
    local pane = runsPane(i)
    pane:SetFilter("char", "all")
    pane:SetFilter("spec", "all")
    pane:SetFilter("group", "full")
    local Tbl = i.NS.ResultsTable
    local headers = {}
    for _, row in ipairs(visible(pane)) do
        if row.group then headers[#headers + 1] = row.group end
    end
    assertEqual(#headers, 3)
    local hex = function(c) return "|c" .. Tbl.Hex(c) end
    local mage = hex(Tbl.ClassColor("MAGE"))
    assertEqual(headers[1].label, "Full: " .. mage .. "Kaosmage|r \194\183 " .. mage .. "Mage|r \194\183 "
        .. mage .. "Fire|r \194\183 " .. hex(Tbl.CATEGORY_COLORS.cleave) .. "Cleave|r \194\183 "
        .. hex(Tbl.LengthColor(60)) .. "1:00|r", "character, class, spec, target, time; Kaosmage before Lanfear")
    assertEqual(headers[3].count, 2, "Lanfear's two 2:00 cleave runs share one group")
end)
