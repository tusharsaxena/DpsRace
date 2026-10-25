-- tests/test_results_badges.lua — the Results window's boxed chips and colored group headers
-- (modules/Results_Table.lua's chips, modules/Results_Runs.lua, modules/Results_Bests.lua,
-- modules/Results_Detail.lua): the Runs list's Target and Time cells boxed in their category and
-- length colors, the Status board as two chips after Spec best and Max, the Bests Length chip, the
-- detail's target line, every width from Tbl.BadgeWidth fitting its column at the window minimums,
-- and the group headers' values in the class, category and length colors as plain text. The helpers
-- follow tests/test_results_group.lua's (layout-§1's 1500-line cap keeps them out of test_results).

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600

local function inst()
    local W
    local i = T.load{ mutate = function(m)
        W = Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
    end }
    i.W, i.R = W, i.NS.Results
    return i
end

local CHARS = {
    lan = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction", ilvl = 313.2 },
    mage = { name = "Kaosmage", realm = "Frostmourne", class = "MAGE", specID = 63, spec = "Fire", ilvl = 311.0 },
}

local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

--- A stored-shape run: a complete 3:00 cleave race (five targets) by Lanfear, an hour ago, with a
--- 9.2 s tail. `fields` replaces any top-level field; `char` names one of CHARS.
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
        spells = { { id = 29722, dmg = 7330000, dps = 1 } },
        note = "",
    }
    for k, v in pairs(fields or {}) do run[k] = v end
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

local function cellsById(pane)
    local out = {}
    for _, row in ipairs(pane.list:Visible()) do
        if row.run then out[row.run.id] = row.cells end
    end
    return out
end

local function sameColor(got, want, msg)
    assertTrue(type(got) == "table", msg .. ": no color")
    for n = 1, 3 do assertEqual(got[n], want[n], msg) end
end

-- Visible characters in a UTF-8 string (a continuation byte is never one).
local function chars(s)
    return select(2, s:gsub("[^\128-\191]", ""))
end

-- ── the Runs list's cells ───────────────────────────────────────────────────────────────────────

test("badges: the Target cell is a boxed chip in its category color, the count inside", function()
    local i = inst()
    local Tbl = i.NS.ResultsTable
    seed(i, { mkRun("a"), mkRun("b", { target = { category = "boss", count = 1 }, date = NOW - 2 * HOUR }) })
    i.R.Show()
    local pane = runsPane(i)
    local edges = {}
    for _, row in ipairs(pane.list:Visible()) do
        rawset(row.cells.target.box, "SetBackdropBorderColor", function(_, r, g, b) edges[row.run.id] = { r, g, b } end)
    end
    pane:Refresh()
    local cells = cellsById(pane)
    assertEqual(cells.a.target.fs.__text, "Cleave \195\1515", "the count stays inside the box")
    sameColor(cells.a.target.fs.__color, Tbl.CATEGORY_COLORS.cleave, "Cleave's word")
    sameColor(edges.a, Tbl.CATEGORY_COLORS.cleave, "Cleave's box")
    assertEqual(cells.b.target.fs.__text, "Boss-level")
    sameColor(edges.b, Tbl.CATEGORY_COLORS.boss, "Boss-level's box")
    assertEqual(cells.a.target.box.__width, Tbl.BadgeWidth("Cleave \195\1515", true), "the box is BadgeWidth's")
end)

test("badges: the Time cell boxes the length in its color; the tail or the end of combat follows in gray", function()
    local i = inst()
    local Tbl, C = i.NS.ResultsTable, i.NS.ResultsTable.COLORS
    seed(i, {
        mkRun("tail", { race = { length = 120, grace = 1 } }),
        mkRun("bare", { race = { length = 45, grace = 1 }, result = { damage = 1, dps = 1, tail = 0 },
                        date = NOW - 2 * HOUR }),
        mkRun("early", { status = "incomplete", result = { damage = 1, dps = 1, endedAt = 64 },
                         date = NOW - 3 * HOUR }),
    })
    i.R.Show()
    local cells = cellsById(runsPane(i))
    local t = cells.tail.time
    assertEqual(t.fs.__text, "2:00", "the length alone in the box")
    sameColor(t.fs.__color, Tbl.LengthColor(120), "2:00's word")
    assertEqual(t.trail.__text, "+9.2s", "the tail after the box")
    sameColor(t.trail.__color, C.dim, "the tail in the caption gray")
    assertTrue(t.trail:IsShown())
    local p = t.trail.__points[1]
    assertEqual(p[2], t.box, "the tail sits after the box")
    assertEqual(p[4], i.NS.ResultsTable.CHIP_GAP)
    assertFalse(cells.bare.time.trail:IsShown(), "no tail, no trail")
    sameColor(cells.bare.time.fs.__color, Tbl.LENGTH_NEUTRAL, "a custom length is neutral")
    assertEqual(cells.early.time.fs.__text, "3:00")
    assertEqual(cells.early.time.trail.__text, "at 1:04", "an early end says when combat ended")
    assertEqual(i.NS.ResultsTable.TimeTail({ status = "complete", result = { tail = 0.01 } }), nil)
end)

test("badges: Spec best and Max are the box alone; their board is in the tooltip", function()
    local i = inst()
    seed(i, {
        mkRun("top", { result = { damage = 27000000, dps = 150000 }, race = { length = 120, grace = 1 } }),
        mkRun("slow", { result = { damage = 1, dps = 1 }, race = { length = 120, grace = 1 }, date = NOW - 2 * HOUR }),
    })
    i.R.Show()
    local cells = cellsById(runsPane(i))
    local s = cells.top.status
    assertEqual(s.fs.__text, "Spec best")
    assertEqual(s.trail, nil, "no plain text after the box")
    assertEqual(s.chip1, nil, "no board chips after the box (too noisy)")
    local tip = i.NS.ResultsRuns.StatusTip(i.NS.db.global.runs.top)
    assertTrue(tip[1]:find("cleave", 1, true) ~= nil and tip[1]:find("2:00", 1, true) ~= nil,
        "the tooltip still names the board: " .. tostring(tip[1]))
end)

test("badges: a chip never runs past its column: a too-long word is cut to the box", function()
    local i = inst()
    local Tbl, Runs = i.NS.ResultsTable, i.NS.ResultsRuns
    seed(i, { mkRun("wide", { target = { category = "single", count = 20 } }) })
    i.R.Show()
    local cells = cellsById(runsPane(i))
    assertEqual(cells.wide.target.fs.__text, "Single target \195\15120")
    assertEqual(cells.wide.target.box.__width, Runs.TARGET_W, "capped at the column")
    local chip = Tbl.Chip(ui(i).frame)
    assertEqual(Tbl.SetChip(chip, "Single target", { 1, 1, 1 }, 40), 40)
    assertEqual(chip.__width, 40)
    assertEqual(Tbl.SetChip(chip, "", { 1, 1, 1 }), 0, "an empty chip is hidden")
    assertFalse(chip:IsShown())
end)

-- ── the fit ─────────────────────────────────────────────────────────────────────────────────────

test("badges: Target, Time and Status fit their widest chips (Tbl.BadgeWidth)", function()
    local i = inst()
    local NS = i.NS
    local Tbl, Runs, L = NS.ResultsTable, NS.ResultsRuns, NS.L
    local gap = Tbl.CHIP_GAP
    -- Target: every type, and every type but Single target with a two-digit count (Hud.MAX_TARGETS).
    for key in pairs(NS.Dummies.LABELS) do
        local label = NS.Dummies.Label(key)
        assertTrue(Tbl.BadgeWidth(label, true) <= Runs.TARGET_W, label .. " overflows Target")
        if key ~= "single" then
            local counted = Tbl.Badge({ category = key, count = NS.Hud.MAX_TARGETS })
            assertTrue(Tbl.BadgeWidth(counted, true) <= Runs.TARGET_W, counted .. " overflows Target")
        end
    end
    -- Time: each preset's chip, then the longest tail or an early end, after the gap.
    for _, len in ipairs(NS.HudStates.PRESETS) do
        local box = Tbl.BadgeWidth(NS.Format.Length(len), true)
        for _, tail in ipairs({ L["+%.1fs"]:format(15.9), L["at %s"]:format(NS.Format.Length(len - 1)) }) do
            assertTrue(box + gap + chars(tail) * 6 <= Runs.TIME_W, NS.Format.Length(len) .. " " .. tail .. " overflows Time")
        end
    end
    -- Status: every tag's box and icon, alone.
    for _, tag in pairs(Runs.STATUS) do
        assertTrue(Tbl.BadgeWidth(L[tag.label], true, Tbl.BADGE_ICON + 2) <= Runs.STATUS_W, tag.label .. " is cut off")
    end
    -- The Bests Length chip: a custom length's.
    local col
    for _, c in ipairs(NS.ResultsBests.Columns()) do if c.key == "length" then col = c end end
    assertTrue(col.boxed and Tbl.BadgeWidth("10:00", true) <= col.width, "Bests Length is boxed and fits")
end)

test("badges: the window minimums hold the wider columns, the Note column last and inside the list", function()
    local i = inst()
    local R, Runs = i.NS.Results, i.NS.ResultsRuns
    assertEqual(R.VIEWS.collapsed.minWidth, 834)
    assertEqual(R.VIEWS.expanded.minWidth, 1198)
    local cols = Runs.Columns()
    assertEqual(cols[#cols].key, "note", "the Note column stays at the far right")
    for _, view in ipairs({ "collapsed", "expanded" }) do
        assertTrue(i.NS.defaults.profile.windows.results[view].width >= R.VIEWS[view].minWidth,
            view .. ": the default size is under the minimum")
    end
end)

test("badges: the Bests Length column is a chip in its length color", function()
    local i = inst()
    local Tbl = i.NS.ResultsTable
    seed(i, { mkRun("a", { race = { length = 60, grace = 1 } }) })
    i.R.Show()
    i.R.ShowTab("bests")
    local pane = assert(ui(i).panes.bests)
    pane.dropdowns.category.onSelect("cleave")
    local row = assert(pane.list:Visible()[1], "no best drawn")
    assertEqual(row.cells.length.fs.__text, "1:00")
    sameColor(row.cells.length.fs.__color, Tbl.LengthColor(60), "the Bests length chip")
    assertEqual(row.cells.length.box.__width, Tbl.BadgeWidth("1:00", true))
end)

-- ── the detail ──────────────────────────────────────────────────────────────────────────────────

test("badges: the detail's target line leads with the type and length chips, laid out from their widths", function()
    local i = inst()
    local Tbl = i.NS.ResultsTable
    seed(i, { mkRun("a", { result = { damage = 1000, dps = 5.6, tail = 15.94 } }) })
    i.R.ShowRun("a")
    local d = ui(i).detail
    local a, b = d.w.metaChips[1], d.w.metaChips[2]
    assertEqual(a.fs.__text, "Cleave \195\1515")
    sameColor(a.color, Tbl.CATEGORY_COLORS.cleave, "the detail's type chip")
    assertEqual(b.fs.__text, "3:00")
    sameColor(b.color, Tbl.LengthColor(180), "the detail's length chip")
    assertEqual(d.w.meta[2].__text, "+15.9s \194\183 Cleave Training Dummy", "the tail, then the target's name")
    local wa, wb = Tbl.BadgeWidth("Cleave \195\1515", true), Tbl.BadgeWidth("3:00", true)
    assertEqual(b.__points[1][4], wa + Tbl.CHIP_GAP, "the length chip after the type chip, from config")
    assertEqual(d.w.meta[2].__points[1][4], wa + wb + 2 * Tbl.CHIP_GAP, "the text after both chips")
    local Detail = i.NS.ResultsDetail
    local _, second, _, chips = Detail.Meta(mkRun("x", { status = "incomplete", result = { endedAt = 64 } }))
    assertEqual(second, "at 1:04 \194\183 Cleave Training Dummy")
    assertEqual(chips[2][1], "3:00")
end)

test("badges: drawing the chips reads no frame's size or position back", function()
    local i = inst()
    seed(i, { mkRun("a", { result = { damage = 27000000, dps = 150000 } }) })
    i.R.ShowRun("a")
    local before = #i.W.geomReads
    runsPane(i):Refresh()
    ui(i).detail:Show(i.NS.db.global.runs.a)
    assertEqual(#i.W.geomReads, before, "a chip was laid out from a measured size")
end)

-- ── the group headers ───────────────────────────────────────────────────────────────────────────

test("badges: group headers color their value as plain text: class, target type, length", function()
    local i = inst()
    local Tbl, Runs = i.NS.ResultsTable, i.NS.ResultsRuns
    local hex = function(c) return "|c" .. Tbl.Hex(c) end
    local cleave, length = hex(Tbl.CATEGORY_COLORS.cleave), hex(Tbl.LengthColor(180))
    local class = hex(Tbl.ClassColor("WARLOCK"))
    local run = mkRun("a")
    local _, label = Runs.GROUPS.target.of(run)
    assertEqual(label, "Target: " .. cleave .. "Cleave|r", "the type in its category color, the prefix plain")
    _, label = Runs.GROUPS.targetLength.of(run)
    assertEqual(label, "Target: " .. cleave .. "Cleave|r \194\183 " .. length .. "3:00|r", "both colors")
    _, label = Runs.GROUPS.length.of(run)
    assertEqual(label, "Time: " .. length .. "3:00|r")
    _, label = Runs.GROUPS.char.of(run)
    assertEqual(label, "Character: " .. class .. "Lanfear|r")
    _, label = Runs.GROUPS.classSpec.of(run)
    assertTrue(label:find("^Class & spec: " .. class:gsub("|", "%%|")) ~= nil, "the class and spec in the class color")
    assertFalse(label:find("|T", 1, true) ~= nil, "no box or texture in a header")
    -- Drawn: the header row's label carries the colored value, its count in the gray it had.
    seed(i, { run })
    i.R.Show()
    local pane = runsPane(i)
    pane:SetFilter("group", "target")
    local header = pane.list:Visible()[1]
    assertTrue(header.groupLabel.__text:find(cleave .. "Cleave|r", 1, true) ~= nil)
    assertTrue(header.groupLabel.__text:find("|cff808080(1)|r", 1, true) ~= nil, "the count keeps its gray")
end)

test("badges: the HUD draws none of the Results chips", function()
    for _, file in ipairs({ "Hud.lua", "Hud_Appearance.lua", "Hud_Breakdown.lua", "Hud_Chart.lua", "Hud_States.lua" }) do
        local f = assert(io.open(T.root .. "/modules/" .. file, "rb"))
        local src = f:read("*a")
        f:close()
        for _, name in ipairs({ "Tbl.Chip", "SetChip", "LengthChip", "TimeTail" }) do
            assertFalse(src:find(name, 1, true) ~= nil, file .. " uses " .. name)
        end
    end
end)
