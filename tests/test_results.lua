-- tests/test_results.lua — the Results window (modules/Results*.lua, spec §6.2): the run list's
-- columns, filters and sorting, the run detail (breakdown, timing strip, flags, note, delete, share),
-- how the shell builds the Insights tab and shows its empty state, the window chrome and its wide/narrow
-- layouts, and how it follows the store and the lifecycle.
--
-- Every case runs on a fresh instance with the widget recorder (tests/mock_widgets.lua) installed, so
-- a label's text, a texture and a tooltip's lines can be read back. Runs are seeded straight into the
-- store in spec §7's shape.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR, DAY = 3600, 86400
local CLASS_ATLAS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

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

local function visibleIDs(pane)
    local out = {}
    for n, row in ipairs(visible(pane)) do out[n] = row.run.id end
    return table.concat(out, ",")
end

local function heard(i, msg)
    local n = { count = 0 }
    i.NS.NewBusTarget():RegisterMessage(i.NS.MSG[msg], function() n.count = n.count + 1 end)
    return n
end

-- ── the run list ────────────────────────────────────────────────────────────────────────────────

test("results: runs list columns: date, class icon, spec icon, character, ilvl, target, time, damage, DPS, Delta, status, used, note", function()
    local i = inst()
    local run = mkRun("a", { flags = { lateCasts = { { t = 1.4, spellID = 29722 } }, reloaded = false, died = false } })
    seed(i, { run })
    i.R.Show()
    local pane = runsPane(i)
    local labels = {}
    for n, head in ipairs(pane.list.heads) do labels[n] = (head.label.__text or ""):gsub("%s*|T.-|t", "") end
    assertEqual(table.concat(labels, "|"), "Date|Class|Character|iLvl|Target|Time|Damage|DPS|Delta|Status|Used|Note", "no flag column: the Status cell carries the flags")
    local row = assert(visible(pane)[1], "no row drawn")
    local c = row.cells
    assertEqual(c.date.fs.__text, os.date("%d %b %H:%M", run.date))
    assertEqual(c.icons.class.__texture, CLASS_ATLAS, "the class icon")
    assertEqual(c.icons.spec.__texture, 136186, "the spec icon")
    local tip = pane.list:TipLines(run, 2)
    assertEqual(tip[1], "Destruction Warlock", "the icons' tooltip names the spec and the class")
    assertEqual(c.char.fs.__text, "Lanfear")
    assertEqual(c.char.fs.__color[1], 0.53, "the character is class-colored")
    assertEqual(c.ilvl.fs.__text, "313.2")
    assertEqual(c.target.fs.__text, "Cleave", "no target count (DpsRace#15)")
    assertEqual(c.time.fs.__text .. "|" .. c.time.trail.__text, "3:00|+9.2s", "the length's chip, then the tail")
    assertEqual(c.damage.fs.__text, "26.56M")
    assertEqual(c.dps.fs.__text, "147.5K")
    assertEqual(c.status.fs.__text, "Spec best", "a best outranks its flag in the tag; the box holds the first part only")
    assertEqual(c.status.chip1, nil, "the tag is the box alone: no board chips after it")
    local status = pane.list:TipLines(run, 10)
    assertEqual(status[1], "Spec best: cleave \194\183 3:00", "the tooltip names the whole board")
    local named = false
    for _, l in ipairs(status) do
        if type(l) == "table" and l[1]:find("Incinerate", 1, true) then named = true end
    end
    assertTrue(named, "the Status tooltip carries the flag, naming the spell")
end)

test("results: the Note column cuts a note to 10 characters with an ellipsis, tips the whole note and sorts A to Z, none last", function()
    local i = inst()
    local long = mkRun("long", { note = "Tried Bloodlust at the pull", date = 1000 })
    local short = mkRun("short", { note = "apple", date = 900 })
    local exact = mkRun("exact", { note = "0123456789", date = 800 })
    local none = mkRun("none", { date = 700 })
    seed(i, { long, short, exact, none })
    local Runs = i.NS.ResultsRuns
    assertEqual(Runs.NoteCell(long), "Tried Bloo\226\128\166", "10 characters, then the ellipsis")
    assertEqual(Runs.NoteCell(exact), "0123456789", "exactly 10: no ellipsis")
    assertEqual(Runs.NoteCell(none), "", "no note: empty")
    assertEqual(Runs.NoteCell({ note = "\195\169\195\169\195\169\195\169\195\169\195\169\195\169\195\169\195\169\195\169\195\169" }),
        "\195\169\195\169\195\169\195\169\195\169\195\169\195\169\195\169\195\169\195\169\226\128\166",
        "UTF-8 characters, never a byte cut through one")
    local tip = Runs.NoteTip(long)
    assertEqual(tip[1], "Note")
    assertEqual(tip[2], "Tried Bloodlust at the pull", "the whole note")
    assertEqual(Runs.NoteTip(none)[1], "No note")
    i.R.Show()
    local pane = runsPane(i)
    local col
    for _, c in ipairs(pane.list.columns) do if c.key == "note" then col = c end end
    assertTrue(col ~= nil, "no Note column")
    assertEqual(col.width, 80, "a fixed 80 px")
    assertTrue(i.NS.ResultsTips.About(col) ~= nil, "the Note header has a tooltip")
    local Tbl = i.NS.ResultsTable
    local function order(desc)
        local ids = {}
        for n, run in ipairs(Tbl.Sort(pane.list.columns, { long, short, exact, none }, "note", desc)) do ids[n] = run.id end
        return table.concat(ids, ",")
    end
    assertEqual(order(false), "exact,short,long,none", "A to Z ignoring case, no note last")
    assertEqual(order(true), "long,short,exact,none", "Z to A, no note still last")
end)

test("results: the detail's section headings are the larger SECTION font; Spell breakdown heads the compare and the list", function()
    local i = inst()
    seed(i, { mkRun("a", { note = "Opened with Bloodlust" }) })
    i.R.Show()
    i.R.ShowRun("a")
    local d = ui(i).detail
    local w, F = d.w, i.NS.Style.FONT
    assertEqual(F.SECTION, "GameFontNormalLarge", "a step above GameFontNormal (Round C, 2026-10-25)")
    assertEqual(i.NS.Style.SECTION_H, 22, "the 16px heading's line")
    assertEqual(w.spellsTitle.__text, "Spell breakdown")
    assertTrue(w.spellsTitle:IsShown())
    for name, fs in pairs({ breakdown = w.spellsTitle, chart = w.chart.title, timing = w.timingLabel,
                            gear = d.lo.title, talents = d.lo.talentsTitle, flags = w.flagTitle, note = w.noteTitle }) do
        assertEqual(fs.__fontObject, F.SECTION, name .. " heading is not FONT.SECTION")
    end
    -- Spell breakdown sits above the compare's toggle, which sits above the spell list.
    local function y(region) return region.__points[1][5] end
    assertTrue(y(w.spellsTitle) > y(d.cmp.toggle), "the heading is under the toggle")
    assertTrue(y(d.cmp.toggle) > y(w.list.parent), "the toggle is under the list")
    assertEqual(y(w.spellsTitle) - y(d.cmp.toggle), i.NS.ResultsDetail.SECTION_H, "one heading line")
    assertEqual(i.NS.ResultsTips.Detail("breakdown", i.NS.Recorder.Get("a"))[1], "Spell breakdown", "the heading's tooltip")
end)

test("results: every section heading has SECTION_GAP of clear space above it, the y-advances from config", function()
    local i = inst()
    seed(i, { mkRun("a", { note = "Opened with Bloodlust", flags = { reloaded = true } }) })
    i.R.Show()
    i.R.ShowRun("a")
    local d = ui(i).detail
    local w, D = d.w, i.NS.ResultsDetail
    local GAP, H = D.SECTION_GAP, D.SECTION_H
    assertEqual(GAP, i.NS.Style.SECTION_GAP)
    assertTrue(GAP >= 14 and GAP <= 18, "a gap the eye reads as a break")
    local function y(region) return region.__points[1][5] end
    -- Spell breakdown: the Delta box's height and its 4px under the box, then the gap.
    assertEqual(y(w.spellsTitle), y(w.deltaBox.frame) - D.KPI_H - 4 - GAP, "Spell breakdown under the header")
    -- Timing (no chart this session): under the spell list's rows and their 8px, then the gap.
    local n, pitch = w.list:Count(), i.NS.HudBreakdown.Pitch()
    assertEqual(y(w.timingLabel), y(w.list.parent) - n * pitch - 8 - GAP, "Timing under the spell rows")
    -- Talents: under the gear grid (or Not recorded), its 6px, then the gap.
    assertTrue(y(d.lo.title) < y(w.timingLabel) - H, "Gear under the timing strip")
    assertTrue(y(w.flags) < y(d.lo.talentsTitle) - H - GAP, "the flags box clear of Talents")
    assertTrue(y(w.noteTitle) <= y(w.flags) - GAP, "Note clear of the flags box")
end)

test("results: the detail's header: 28 px class and spec icons, a larger name, no spec text; the spec icon names the spec", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.Show()
    i.R.ShowRun("a")
    local w = ui(i).detail.w
    assertEqual(i.NS.ResultsDetail.ICON, 28)
    assertEqual(w.name.__fontObject, i.NS.Style.FONT.NAME)
    assertEqual(w.name.__text, "Lanfear")
    assertEqual(w.specName, nil, "the spec text beside the name is gone")
    assertEqual(i.NS.ResultsTips.Detail("class", i.NS.Recorder.Get("a"))[1], "Destruction Warlock",
        "the spec icon's tooltip names the spec and the class")
end)

test("results: the note shows as written under a Note heading; the heading also shows while writing one", function()
    local i = inst()
    seed(i, { mkRun("a", { note = "Opened with Bloodlust" }), mkRun("b", { date = NOW - 2 * HOUR }) })
    i.R.Show()
    i.R.ShowRun("a")
    local d = ui(i).detail
    local w = d.w
    assertEqual(w.note.__text, "Opened with Bloodlust", "no Note: prefix")
    assertTrue(w.noteTitle:IsShown())
    assertEqual(w.noteTitle.__text, "Note")
    assertTrue(w.noteTitle.__points[1][5] > w.note.__points[1][5], "the heading sits over the note")
    i.R.ShowRun("b")
    assertFalse(w.noteTitle:IsShown(), "a heading with no note")
    d:openNote()
    assertTrue(w.noteTitle:IsShown(), "the heading while writing a note")
    assertTrue(w.noteBox:IsShown())
    d:closeNote()
    assertFalse(w.noteTitle:IsShown())
end)

test("results: every cell and header has a tooltip; it sits right of the window, or left when there is no room", function()
    local i = inst()
    local run = mkRun("a", { result = { damage = 36812345, dps = 306769, meterDps = 194700, tail = 9.1,
                                        combatEnd = 11.0, sessionDuration = 131 } })
    seed(i, { run })
    i.R.Show()
    local list = runsPane(i).list
    for c, col in ipairs(list.columns) do
        local lines = list:TipLines(run, c)
        assertTrue(type(lines) == "table" and type(lines[1]) == "string", col.key .. " has a cell tooltip")
        assertTrue(i.NS.ResultsTips.About(col) ~= nil, col.key .. " has a header tooltip")
    end
    assertEqual(list:TipLines(run, 7)[1], "36,812,345 damage", "the exact damage")
    assertEqual(list:TipLines(run, 8)[1], "306,769 DPS")
    -- Placement: a stand-in tooltip, window and row with scripted geometry.
    local placed
    local tip = {}
    for _, m in ipairs({ "AddLine", "Show", "ClearAllPoints" }) do tip[m] = function() end end
    function tip.SetOwner() end
    function tip.SetText() end
    function tip.GetWidth() return 300 end
    function tip.GetEffectiveScale() return 1 end
    function tip.SetPoint(_, point, _, rel, x) placed = { point, rel, x } end
    local env = i.mocks
    env.GameTooltip = tip
    env.UIParent = { GetRight = function() return 1920 end, GetEffectiveScale = function() return 1 end }
    local window = { GetRight = function() return 1200 end, GetTop = function() return 800 end,
                     GetEffectiveScale = function() return 1 end }
    local row = { GetTop = function() return 700 end }
    i.NS.ResultsTable.SideTip(window, row, { "Title", "line" })
    assertEqual(placed[1], "TOPLEFT", "room on the right: the tooltip's left edge on the window's right")
    assertEqual(placed[2], "TOPRIGHT")
    window.GetRight = function() return 1800 end
    i.NS.ResultsTable.SideTip(window, row, { "Title", "line" })
    assertEqual(placed[1], "TOPRIGHT", "no room: on the window's left")
    assertEqual(placed[2], "TOPLEFT")
end)

test("results: the Status column tags each run; the DPS column shows every run's DPS", function()
    local i = inst()
    seed(i, {
        mkRun("inc", { status = "incomplete", result = { damage = 900000, dps = 10000, endedAt = 90 } }),
        mkRun("lost", { status = "lost", result = NONE, date = NOW - 2 * HOUR }),
        mkRun("dead", { status = "incomplete", result = { damage = 500, dps = 50, endedAt = 10 },
                        flags = { lateCasts = {}, died = true }, date = NOW - 3 * HOUR }),
    })
    i.R.Show()
    local rows = visible(runsPane(i))
    assertEqual(#rows, 3)
    local byId = {}
    for _, row in ipairs(rows) do byId[row.run.id] = row end
    rows = { byId.inc, byId.lost, byId.dead }
    assertEqual(rows[1].cells.dps.fs.__text, "10.0K", "an incomplete run's DPS is shown")
    assertEqual(rows[1].cells.damage.fs.__text, "900.0K")
    assertEqual(rows[1].cells.status.fs.__text, "Incomplete")
    assertEqual(rows[1].cells.time.fs.__text .. " " .. rows[1].cells.time.trail.__text, "3:00 at 1:30")
    assertEqual(rows[2].cells.dps.fs.__text, "\226\128\148")
    assertEqual(rows[2].cells.status.fs.__text, "Lost")
    assertEqual(rows[2].cells.damage.fs.__text, "\226\128\148")
    assertEqual(rows[3].cells.status.fs.__text, "Died")
end)

test("results: Status is Spec best, Flagged or Complete for a complete run, each with its icon; there is no Max tag", function()
    local i = inst()
    local Runs = i.NS.ResultsRuns
    seed(i, {
        mkRun("top", { result = { damage = 27000000, dps = 150000 } }),
        mkRun("slow", { result = { damage = 20000000, dps = 100000 }, date = NOW - 2 * HOUR }),
        mkRun("late", { result = { damage = 10000000, dps = 50000 }, date = NOW - 3 * HOUR,
                        flags = { lateCasts = { { t = 1.4, spellID = 29722 } } } }),
    })
    local by = {}
    for _, run in ipairs(i.NS.Recorder.All()) do by[run.id] = run end
    local C = i.NS.ResultsTable.COLORS
    local key, text, bestColor, icon = Runs.Status(by.top)
    assertEqual(key, "best", "the board's best")
    assertEqual(text, "Spec best", "the first part only: the board is the trail's")
    assertEqual(bestColor, C.blue, "Spec best in blue")
    assertEqual(icon, "ph:trophy", "Spec best draws the trophy")
    assertEqual(Runs.STATUS.max, nil, "the Max tag is gone (the owner's call, 2026-10-26)")
    i.R.Show()
    local badge, other
    for _, row in ipairs(visible(runsPane(i))) do
        if row.run.id == "top" then badge = row.cells.status end
        if row.run.id == "slow" then other = row.cells.status end
    end
    assert(badge, "the top run is drawn")
    assertEqual(badge.fs.__text, "Spec best", "its top run is its Spec best")
    assertEqual(badge.chip1, nil, "the tag is the box alone: no board after it")
    assertTrue(badge.icon:IsShown(), "the icon shows before the word")
    assertEqual(badge.icon.__texture, i.NS.Icon("ph:trophy"))
    -- A second spec in the view (the mage's run): the view-wide top is still its Spec best.
    seed(i, {
        mkRun("top", { result = { damage = 27000000, dps = 150000 } }),
        mkRun("slow", { result = { damage = 20000000, dps = 100000 }, date = NOW - 2 * HOUR }),
        mkRun("mage", { char = "mage", result = { damage = 1, dps = 90000 }, date = NOW - 4 * HOUR }),
    })
    runsPane(i):SetFilter("char", "all")
    runsPane(i):SetFilter("spec", "all")
    for _, row in ipairs(visible(runsPane(i))) do
        if row.run.id == "top" then badge = row.cells.status end
        if row.run.id == "slow" then other = row.cells.status end
    end
    assertEqual(badge.fs.__text, "Spec best", "two specs in the view: no Max tag")
    assertEqual(Runs.ManySpecs, nil)
    assertEqual(other.fs.__text, "Complete")
    assertEqual(other.chip1, nil, "no tag carries a board")
    assertEqual(other.icon.__texture, i.NS.Icon("ph:check"))
    assertEqual((Runs.Status(by.slow)), "complete")
    local lateKey, _, lateColor, lateIcon = Runs.Status(by.late)
    assertEqual(lateKey, "flagged")
    assertEqual(lateColor, C.red, "Flagged in red")
    assertEqual(lateIcon, "ph:flag")
    assertEqual((Runs.Status({ status = "lost", flags = {} })), "lost")
    -- Every tag has an icon the addon ships and a hue no other tag has.
    local seen = {}
    for k, tag in pairs(Runs.STATUS) do
        assertTrue(i.NS.Icon(tag.icon) ~= nil, k .. "'s icon is declared and shipped")
        local hue = table.concat(tag.color, ",")
        assertEqual(seen[hue], nil, k .. " shares its color with " .. tostring(seen[hue]))
        seen[hue] = k
    end
    assertEqual(Runs.STATUS.incomplete.color, C.orange, "Incomplete in orange")
end)

test("results: race lengths take muted ROYGBIV colors for the presets and a neutral one otherwise", function()
    local i = inst()
    local Tbl = i.NS.ResultsTable
    local presets = i.NS.HudStates.PRESETS
    local seen = {}
    for _, len in ipairs(presets) do
        local c = Tbl.LengthColor(len)
        assertTrue(c ~= Tbl.LENGTH_NEUTRAL, len .. "s is a preset: it has a hue")
        local hue = table.concat(c, ",")
        assertEqual(seen[hue], nil, len .. "s shares its color with " .. tostring(seen[hue]))
        seen[hue] = len
        -- Muted: no channel at full strength or near black, so it reads on the dark table.
        for _, v in ipairs(c) do assertTrue(v > 0.4 and v < 0.95, len .. "s is not muted") end
    end
    -- ROYGBIV in length order: the shortest red, the longest indigo.
    assertTrue(Tbl.LengthColor(30)[1] > Tbl.LengthColor(30)[3], "the shortest is red")
    assertTrue(Tbl.LengthColor(300)[3] > Tbl.LengthColor(300)[1], "the longest is blue")
    assertEqual(Tbl.LengthColor(45), Tbl.LENGTH_NEUTRAL, "a custom length is neutral")
    assertEqual(Tbl.LengthColor(nil), Tbl.LENGTH_NEUTRAL)
    assertEqual(Tbl.Hex({ 1, 0, 0.5 }), "ffff0080")
end)

test("results: the Time column takes the length color; the tail stays gray", function()
    local i = inst()
    seed(i, {
        mkRun("two", { race = { length = 120, grace = 1 } }),
        mkRun("odd", { race = { length = 45, grace = 1 }, result = { damage = 1, dps = 1, tail = 0 },
                       date = NOW - 2 * HOUR }),
    })
    i.R.Show()
    local Tbl = i.NS.ResultsTable
    local cells = {}
    for _, row in ipairs(visible(runsPane(i))) do cells[row.run.id] = row.cells end
    assertEqual(cells.two.time.fs.__text .. "|" .. cells.two.time.trail.__text, "2:00|+9.2s", "the tail after the box")
    local yellow = Tbl.LengthColor(120)
    assertEqual(cells.two.time.fs.__color[1], yellow[1], "2:00 in its preset hue")
    assertEqual(cells.two.time.fs.__color[3], yellow[3])
    assertEqual(cells.odd.time.fs.__color[1], Tbl.LENGTH_NEUTRAL[1], "0:45 is neutral")
end)

test("results: Status tags are boxed in their hue with the icon inside", function()
    local i = inst()
    seed(i, { mkRun("top"), mkRun("slow", { result = { damage = 1, dps = 1 }, date = NOW - 2 * HOUR }) })
    i.R.Show()
    local pane = runsPane(i)
    local edges = {}
    for _, row in ipairs(visible(pane)) do
        rawset(row.cells.status.box, "SetBackdropBorderColor", function(_, r, g, b) edges[row.run.id] = { r, g, b } end)
    end
    pane:Refresh()
    local C = i.NS.ResultsTable.COLORS
    assertEqual(edges.top and edges.top[3], C.blue[3], "Spec best's box in its blue")
    assertEqual(edges.slow and edges.slow[2], C.green[2], "Complete's box in its green")
    assertTrue(visible(pane)[1].cells.target.box.__borderColor ~= nil, "the Target tag is boxed too")
    -- The sort by Status is the tag order, unchanged by the box: Spec best before Complete.
    pane.list:SetSort("status")
    assertEqual(visibleIDs(pane), "top,slow")
end)

test("results: the HUD never draws a race length in the Results length colors", function()
    for _, file in ipairs({ "Hud.lua", "Hud_Appearance.lua", "Hud_Breakdown.lua", "Hud_Chart.lua", "Hud_States.lua" }) do
        local f = assert(io.open(T.root .. "/modules/" .. file, "rb"))
        local src = f:read("*a")
        f:close()
        assertFalse(src:find("LengthColor", 1, true) ~= nil, file .. " uses the Results length colors")
        assertFalse(src:find("LENGTH_COLORS", 1, true) ~= nil, file .. " uses the Results length colors")
    end
end)

test("results: Damage and DPS carry bars from 10% (the smallest run the filters pass) to 100% (the largest)", function()
    local i = inst()
    seed(i, {
        mkRun("big", { result = { damage = 40000000, dps = 200000 } }),
        mkRun("half", { result = { damage = 20000000, dps = 100000 }, date = NOW - 2 * HOUR }),
        mkRun("mage", { char = "mage", result = { damage = 80000000, dps = 400000 }, date = NOW - 3 * HOUR }),
        mkRun("lost", { status = "lost", result = NONE, date = NOW - 4 * HOUR }),
    })
    i.R.Show()
    local pane = runsPane(i)
    local function widths()
        local out = {}
        for _, row in ipairs(visible(pane)) do
            local d = row.cells.damage
            out[row.run.id] = { damage = d.bar.__shown ~= false and d.bar.__width or 0, w = d.barW,
                                dps = row.cells.dps.bar.__shown ~= false and row.cells.dps.bar.__width or 0,
                                dw = row.cells.dps.barW }
        end
        return out
    end
    local function at(share, cellW) return math.floor(cellW * share + 0.5) end
    local w = widths()
    assertEqual(w.big.damage, w.big.w, "the largest run the view holds fills its cell")
    assertEqual(w.half.damage, at(0.1, w.half.w), "the smallest draws at 10%")
    assertEqual(w.half.dps, at(0.1, w.half.dw))
    assertEqual(w.lost.damage, 0, "a lost run has no bar")
    -- All characters: the mage's run is now the largest, and every bar rescales between the two ends.
    pane:SetFilter("char", "all")
    pane:SetFilter("spec", "all")
    w = widths()
    assertEqual(w.mage.damage, w.mage.w)
    assertEqual(w.half.damage, at(0.1, w.half.w))
    assertEqual(w.big.damage, at(0.1 + 0.9 * (20 / 60), w.big.w), "linear between the smallest and the largest")
    -- One run in the view, or every value equal, draws full; no value draws nothing.
    local Tbl = i.NS.ResultsTable
    assertEqual(Tbl.BarShare(5, 5, 5), 1)
    assertEqual(Tbl.BarShare(7, 7, 7), 1)
    assertEqual(Tbl.BarShare(nil, 1, 9), 0)
    pane:SetFilter("char", "current")
    pane:SetFilter("onlyBest", true)
    w = widths()
    assertEqual(w.big.damage, w.big.w, "the only run in the view fills its cell")
end)

test("results: the bars take History > Results table's look, over the rows' own stripe", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.Show()
    local cells = visible(runsPane(i))[1].cells
    local D = i.NS.defaults.profile.resultsTable
    local blue = i.NS.defaults.profile.appearance.pace.barColor
    assertEqual(D.damageBar.barColor.r, blue.r, "the pace bar's blue")
    assertEqual(D.dpsBar.barColor.b, blue.b, "the same fill on both bars")
    assertEqual(D.damageBar.barAlpha, 0.9)
    assertEqual(cells.damage.bar.__vertex[1], 0.36, "the blue fill")
    assertEqual(cells.dps.bar.__vertex[3], 0.84)
    assertEqual(cells.dps.bar.__vertex[4], 0.9, "at the pace bar's opacity")
    assertEqual(cells.damage.track.__colorTex[4], 0, "no track behind the bar")
    assertEqual(cells.damage.edge, nil, "and no border")
    assertEqual(cells.damage.fs.__color[1], 1, "the text stays white")
    assertEqual(cells.damage.fs.__justifyH, "LEFT", "left-aligned")
    assertTrue(i.NS.SetByPath("resultsTable.damageBar.useClassColorBar", true))
    cells = visible(runsPane(i))[1].cells
    local warlock = i.mocks.RAID_CLASS_COLORS.WARLOCK
    assertEqual(cells.damage.bar.__vertex[1], warlock.r, "the run's character's class, Lanfear's warlock")
    assertEqual(cells.dps.bar.__vertex[1], D.dpsBar.barColor.r, "each bar its own companion")
    for _, head in ipairs(runsPane(i).list.heads) do assertEqual(head.label.__justifyH, "LEFT") end
    -- The alternating stripe is back: every other row faintly tinted.
    seed(i, { mkRun("a"), mkRun("b", { date = NOW - 2 * HOUR }) })
    runsPane(i):Refresh()
    local rows = visible(runsPane(i))
    assertEqual(#rows, 2)
    assertEqual(rows[1].bg.__vertex[4], 0)
    assertTrue(rows[2].bg.__vertex[4] > 0, "the second row striped")
end)

test("results: the Damage and DPS bars run 10% to 100% within each group; ungrouped, the whole view is one", function()
    local i = inst()
    seed(i, {
        mkRun("cBig", { result = { damage = 40000000, dps = 300000 } }),
        mkRun("cSmall", { result = { damage = 20000000, dps = 150000 }, date = NOW - 2 * HOUR }),
        mkRun("bBig", { target = { category = "boss", count = 1 }, result = { damage = 12000000, dps = 100000 },
                        date = NOW - 3 * HOUR }),
        mkRun("bSmall", { target = { category = "boss", count = 1 }, result = { damage = 6000000, dps = 50000 },
                          date = NOW - 4 * HOUR }),
    })
    i.R.Show()
    local pane = runsPane(i)
    local function widths()
        local out = {}
        for _, row in ipairs(visible(pane)) do
            if row.run then
                local d = row.cells.damage
                out[row.run.id] = { bar = d.bar.__shown ~= false and d.bar.__width or 0, full = d.barW }
            end
        end
        return out
    end
    local w = widths()
    assertEqual(w.cBig.bar, w.cBig.full, "ungrouped: the view's max fills its cell")
    assertEqual(w.bSmall.bar, math.max(1, math.floor(w.bSmall.full * 0.1 + 0.5)), "the view's min at 10%")
    assertTrue(w.bBig.bar < w.bBig.full, "the boss-level max is below the cleave max")
    -- Group by target type: each group scales on its own.
    pane:SetFilter("group", "target")
    w = widths()
    assertEqual(w.cBig.bar, w.cBig.full, "the cleave max fills its cell")
    assertEqual(w.bBig.bar, w.bBig.full, "the boss-level max fills its cell too, though cleave did more")
    assertEqual(w.bSmall.bar, math.max(1, math.floor(w.bSmall.full * 0.1 + 0.5)), "each type's min at 10%")
    assertEqual(w.cSmall.bar, w.bSmall.bar)
end)

test("results: Delta is per group, recomputed when the grouping changes; ungrouped, the whole view is one", function()
    local i = inst()
    seed(i, {
        mkRun("cleave", { result = { damage = 1, dps = 300000 } }),
        mkRun("cleave2", { result = { damage = 1, dps = 150000 }, date = NOW - 2 * HOUR }),
        mkRun("boss", { target = { category = "boss", count = 1 }, result = { damage = 1, dps = 100000 },
                        date = NOW - 3 * HOUR }),
        mkRun("boss2", { target = { category = "boss", count = 1 }, result = { damage = 1, dps = 50000 },
                         date = NOW - 4 * HOUR }),
    })
    i.R.Show()
    local pane = runsPane(i)
    local function cells()
        local out = {}
        for _, row in ipairs(visible(pane)) do if row.run then out[row.run.id] = row.cells end end
        return out
    end
    local c = cells()
    assertEqual(c.cleave.delta.fs.__text, "0.0%", "ungrouped: every run against the view's max")
    assertEqual(c.cleave2.delta.fs.__text, "-50.0%")
    assertEqual(c.boss.delta.fs.__text, "-66.7%")
    assertEqual(c.boss2.delta.fs.__text, "-83.3%")
    local Runs = i.NS.ResultsRuns
    local col = pane.list:column("delta")
    local by = {}
    for _, run in ipairs(pane.filtered) do by[run.id] = run end
    assertEqual(col.tip(by.cleave)[1], "This run is the max in view.")
    pane:SetFilter("group", "target")
    c = cells()
    assertEqual(c.cleave.delta.fs.__text, "0.0%")
    assertEqual(c.cleave2.delta.fs.__text, "-50.0%")
    assertEqual(c.boss.delta.fs.__text, "0.0%", "the boss-level group's max is its own")
    assertEqual(c.boss2.delta.fs.__text, "-50.0%")
    assertEqual(col.tip(by.boss)[1], "This run is the max in its group.")
    assertEqual(col.tip(by.boss2)[2], "The max in this group: 100,000 DPS.")
    assertEqual(c.boss.status.fs.__text, "Spec best", "no Max tag")
    -- Back to no grouping: recomputed, not kept from the grouped view.
    pane:SetFilter("group", "none")
    assertEqual(cells().boss.delta.fs.__text, "-66.7%")
    assertEqual(Runs.Delta(by.boss2, 100000), -50)
end)

test("results: Only best keeps the runs holding their board's best", function()
    local i = inst()
    seed(i, {
        mkRun("top", { result = { damage = 27000000, dps = 150000 } }),
        mkRun("slow", { result = { damage = 20000000, dps = 120000 }, date = NOW - 2 * HOUR }),
        mkRun("short", { race = { length = 30, grace = 1 }, result = { damage = 1500000, dps = 50000 },
                         date = NOW - 3 * HOUR }),
    })
    i.R.Show()
    local pane = runsPane(i)
    assertEqual(pane:Count(), 3)
    pane.checks.onlyBest:__fire("OnClick")
    assertTrue(pane.filters.onlyBest)
    assertEqual(visibleIDs(pane), "top,short", "one best per board")
    assertEqual(pane.checks.onlyBest.label.__text, "Only best")
    local Tbl = i.NS.ResultsTable
    for key, check in pairs(pane.checks) do
        assertEqual(check.__hitInsets[2], -(1 + Tbl.BadgeWidth(check.label.__text, false)), key .. ": its label clicks too")
    end
end)

test("results: Delta is each run's distance from the max DPS among the runs the filters pass", function()
    local i = inst()
    local Runs = i.NS.ResultsRuns
    seed(i, {
        mkRun("top", { result = { damage = 27000000, dps = 150000 } }),
        mkRun("slow", { result = { damage = 20000000, dps = 120000 }, date = NOW - 2 * HOUR }),
        mkRun("inc", { status = "incomplete", result = { damage = 1, dps = 180000, endedAt = 9 }, date = NOW - 3 * HOUR }),
        mkRun("lost", { status = "lost", result = NONE, date = NOW - 4 * HOUR }),
        -- Another board (30 s): it still measures against the view's max, not its own board's best.
        mkRun("short", { race = { length = 30, grace = 1 }, result = { damage = 1, dps = 75000 },
                         date = NOW - 5 * HOUR }),
        mkRun("mage", { char = "mage", result = { damage = 1, dps = 300000 }, date = NOW - 6 * HOUR }),
    })
    local all = i.NS.Recorder.All()
    local by = {}
    for _, run in ipairs(all) do by[run.id] = run end
    local mine = Runs.Filter(all, {})
    local top = Runs.MaxDps(mine)
    assertEqual(top, 150000, "the max is the complete runs' (an incomplete run never sets it)")
    assertEqual(Runs.Delta(by.top, top), 0)
    assertTrue(math.abs(Runs.Delta(by.slow, top) - (120000 / 150000 - 1) * 100) < 1e-9)
    assertTrue(math.abs(Runs.Delta(by.short, top) - -50) < 1e-9, "ungrouped: every board against the one max")
    assertTrue(math.abs(Runs.Delta(by.inc, top) - 20) < 1e-9, "an incomplete run is compared, never ranked")
    assertEqual(Runs.Delta(by.lost, top), nil)
    assertEqual(Runs.Delta(by.slow, nil), nil, "no complete run in the view")
    assertEqual(Runs.MaxDps({ by.inc, by.lost }), nil)
    i.R.Show()
    local pane = runsPane(i)
    local labels = {}
    for n, head in ipairs(pane.list.heads) do labels[n] = (head.label.__text or ""):gsub("%s*|T.-|t", "") end
    assertEqual(labels[9], "Delta")
    local function cells()
        local out = {}
        for _, row in ipairs(visible(pane)) do out[row.run.id] = row.cells.delta.fs end
        return out
    end
    local c = cells()
    assertEqual(c.top.__text, "0.0%")
    -- The max run's 0.0% in the column's green, the pair of its red below the max (UT-P14).
    local C = i.NS.ResultsTable.COLORS
    for k = 1, 3 do
        assertEqual(c.top.__color[k], C.green[k], "the max run in green")
        assertEqual(c.slow.__color[k], C.red[k], "below the max in red")
    end
    assertEqual(c.slow.__text, "-20.0%")
    assertEqual(c.short.__text, "-50.0%")
    assertEqual(c.inc.__text, "+20.0%")
    assertEqual(c.inc.__color[1], i.NS.ResultsTable.COLORS.dim[1], "an incomplete run muted")
    assertEqual(c.lost.__text, "\226\128\148")
    -- All characters: the mage's run is the max now, and every figure follows it.
    pane:SetFilter("char", "all")
    pane:SetFilter("spec", "all")
    c = cells()
    assertEqual(c.mage.__text, "0.0%")
    assertEqual(c.top.__text, "-50.0%")
    -- Its sort takes every run with a value, an incomplete one included; a lost run sorts last.
    pane.list:SetSort("delta", true)
    local order = {}
    for n, run in ipairs(pane.list.rows) do order[n] = run.id end
    assertEqual(table.concat(order, ","), "mage,inc,top,slow,short,lost")
    -- A view saved while the column was v/s Max keeps its sort on Delta.
    pane:ApplyView({ sortKey = "vsMax", sortDesc = false })
    assertEqual(pane.list.sortKey, "delta")
    assertEqual(pane.list.sortDesc, false)
end)

test("results: filters: character, spec, category, length, date range, hide flagged, include incomplete", function()
    local i = inst()
    local Runs = i.NS.ResultsRuns
    local all = {
        mkRun("a", { date = NOW - HOUR }),
        mkRun("b", { date = NOW - 10 * DAY, race = { length = 30, grace = 1 },
                     target = { category = "boss", count = 1 },
                     flags = { lateCasts = { { t = 2, spellID = 348 } } } }),
        mkRun("c", { char = "mage", date = NOW - 40 * DAY, target = { category = "single", count = 1 } }),
        mkRun("d", { char = "druid", status = "incomplete", date = NOW - 2 * HOUR,
                     target = { category = "dungeoneer", count = 1 }, result = { damage = 1, dps = 1, endedAt = 9 } }),
        mkRun("e", { status = "lost", result = NONE, date = NOW - 5 * HOUR }),
        mkRun("f", { status = "running", date = NOW }),
    }
    local function rawIds(f)
        local out = {}
        for n, run in ipairs(Runs.Filter(all, f, NOW)) do out[n] = run.id end
        return table.concat(out, ",")
    end
    -- Every other case widens the character and spec to all, then narrows by the one filter.
    local function ids(f)
        local wide = { char = "all", spec = "all" }
        for k, v in pairs(f) do wide[k] = v end
        return rawIds(wide)
    end
    assertEqual(rawIds({}), "a,b,e", "the defaults: the logged-in character (Lanfear), in every spec")
    assertEqual(rawIds({ char = "all" }), "a,b,c,d,e", "every character in every spec")
    assertEqual(rawIds({ char = "all", spec = "current" }), "a,b,e", "the current spec across characters")
    assertEqual(rawIds({ spec = "all" }), "a,b,e", "the current character in every spec")
    assertEqual(ids({}), "a,b,c,d,e", "a running run is the race's, never the list's")
    assertEqual(ids({ char = "Lanfear-Frostmourne" }), "a,b,e")
    assertEqual(ids({ spec = 63 }), "c")
    assertEqual(ids({ category = "boss" }), "b")
    assertEqual(ids({ length = 30 }), "b")
    assertEqual(ids({ date = "7d" }), "a,d,e")
    assertEqual(ids({ date = "30d" }), "a,b,d,e")
    assertEqual(ids({ hideFlagged = true }), "a,c,d,e")
    assertEqual(ids({ includeIncomplete = false }), "a,b,c")
    local midnight = Runs.Since("today", NOW)
    assertTrue(midnight <= NOW and midnight > NOW - DAY, "today starts at the last midnight")

    local options = Runs.Options(all)
    assertEqual(options.char[1].label, "Current character")
    assertEqual(options.char[2].label, "All characters")
    assertEqual(#options.char, 5)
    assertEqual(options.spec[1].label, "Current spec")
    assertEqual(options.spec[2].label, "All specs")
    assertEqual(options.category[1].label, "All targets")
    assertEqual(options.length[1].label, "Any length")
    assertEqual(options.length[2].label, "0:30")
    assertEqual(options.date[4].label, "Last 30 days")

    -- The bar drives the same filters.
    seed(i, all)
    i.R.Show()
    local pane = runsPane(i)
    assertEqual(pane.countText, "3 runs", "the current character and spec")
    pane.dropdowns.char.onSelect("all")
    pane.dropdowns.spec.onSelect("all")
    assertEqual(pane.countText, "5 runs")
    pane.checks.hideFlagged:__fire("OnClick")
    assertEqual(pane.countText, "4 runs")
    pane.checks.includeIncomplete:__fire("OnClick")
    assertEqual(pane.countText, "2 runs")
    pane.dropdowns.char.onSelect("Kaosmage-Frostmourne")
    assertEqual(pane.countText, "1 run")
    assertEqual(visibleIDs(pane), "c")
end)

test("results: sort by date desc default; by DPS; by ilvl", function()
    local i = inst()
    seed(i, {
        mkRun("lo", { result = { damage = 1, dps = 100000 }, char = "lan", date = NOW - 4 * HOUR }),
        mkRun("hi", { result = { damage = 1, dps = 200000 }, char = "mage", date = NOW - 3 * HOUR }),
        mkRun("mid", { result = { damage = 1, dps = 150000 }, char = "druid", date = NOW - 1 * HOUR }),
        mkRun("inc", { status = "incomplete", result = { damage = 1, dps = 999999, endedAt = 9 },
                       date = NOW - 2 * HOUR }),
    })
    i.R.Show()
    local pane = runsPane(i)
    pane:SetFilter("char", "all")
    pane:SetFilter("spec", "all")
    assertEqual(pane.list.sortKey, "date")
    assertTrue(pane.list.sortDesc)
    assertEqual(visibleIDs(pane), "mid,inc,hi,lo", "newest first by default")
    local heads = pane.list.heads
    assertTrue(heads[1].label.__text:find("sort-down", 1, true) ~= nil, "the Date header carries the mark")
    heads[8]:__fire("OnClick")
    assertEqual(visibleIDs(pane), "hi,mid,lo,inc", "by DPS: an unranked run sorts last")
    assertEqual(heads[8].label.__color[2], 0.82, "the header is the header gold")
    assertTrue(heads[8].label.__text:find("sort-down", 1, true) ~= nil, "the sorted header carries the direction mark")
    assertEqual(heads[7].label.__text, "Damage", "an unsorted header carries no mark")
    heads[4]:__fire("OnClick")
    assertEqual(pane.list.sortKey, "ilvl")
    local ilvls = {}
    for n, row in ipairs(visible(pane)) do ilvls[n] = row.cells.ilvl.fs.__text end
    assertEqual(table.concat(ilvls, ","), "313.2,313.2,311.0,309.4")
    heads[4]:__fire("OnClick")
    assertFalse(pane.list.sortDesc, "a second click flips the direction")
    assertEqual(visible(pane)[1].cells.ilvl.fs.__text, "309.4")
    heads[2]:__fire("OnClick")
    assertEqual(pane.list.sortKey, "ilvl", "the icons column does not sort")
end)

test("results: the list is pooled and scrolls through more runs than fit", function()
    local i = inst()
    local runs = {}
    for n = 1, 60 do runs[n] = mkRun(("r%02d"):format(n), { result = { damage = 1, dps = 1000 * n } }) end
    seed(i, runs)
    i.R.Show()
    local list = runsPane(i).list
    local shown = #list:Visible()
    assertTrue(shown > 0 and shown < 60, "every run drew a row")
    assertEqual(list:Visible()[1].run.id, "r60")
    list:Scroll(-1)
    assertEqual(list:Visible()[1].run.id, "r57", "one notch moves three rows")
    list:ScrollTo(1000)
    assertEqual(list:Visible()[#list:Visible()].run.id, "r01", "scrolled to the end")
    local free, active = i.NS.Pool.Counts(list.pool)
    assertEqual(active, shown)
    assertTrue(free + active <= shown + 1, "rows were made per run, not pooled")
end)

-- ── the run detail ──────────────────────────────────────────────────────────────────────────────

test("results: detail renders breakdown sorted with percentages", function()
    local i = inst()
    seed(i, { mkRun("a", {
        result = { damage = 1000, dps = 5.6, meterDps = 5.1, tail = 2, combatEnd = 1 },
        spells = { { id = 348, dmg = 100 }, { id = 29722, dmg = 500 }, { id = 17962, dmg = 400 } },
    }) })
    i.R.ShowRun("a")
    local d = ui(i).detail
    assertEqual(i.R.Selected(), "a")
    local rows = d.w.list.rows
    assertEqual(#rows, 3)
    assertEqual(rows[1].name.__text, "Incinerate")
    assertEqual(rows[1].pct.__text, "50.0%")
    assertEqual(rows[2].name.__text, "Conflagrate")
    assertEqual(rows[2].pct.__text, "40.0%")
    assertEqual(rows[3].name.__text, "Immolate")
    assertEqual(rows[3].pct.__text, "10.0%")
    assertEqual(rows[1].bar.__max, 500, "bars scale to the top spell")
    assertEqual(d.w.damage.value.__text, "1.0K")
    assertEqual(d.w.meterDps.value.__text, "5", "Blizzard's figure, muted")
    assertEqual(d.w.name.__text, "Lanfear")
    assertEqual(d.w.meta[1].__text, "Frostmourne \194\183 ilvl 313.2 \194\183 Silvermoon City, Falconwing Square")
    assertEqual(d.w.meta[2].__text, "+2.0s \194\183 Cleave Training Dummy")
    assertTrue(d.w.meta[3].__text:find("build 120105", 1, true) ~= nil)
    assertTrue(d.w.meta[3].__text:find("v0.1.0", 1, true) ~= nil)
end)

test("results: timing strip positions buzzer, grace, tail, late casts, combat end", function()
    local i = inst()
    local Detail = i.NS.ResultsDetail
    local run = mkRun("a", {
        result = { damage = 1, dps = 1, tail = 9, combatEnd = 7.5 },
        flags = { lateCasts = { { t = 1.5, spellID = 29722 } } },
    })
    local m = Detail.Timing(run)
    assertEqual(m.span, 12, "the after-buzzer axis runs to the next 6s step, at least 12s")
    assertEqual(m.raceFill, 1)
    assertEqual(m.grace, 1 / 12)
    assertEqual(m.tail, 0.75)
    assertEqual(m.late[1], 0.125)
    assertEqual(m.combatEnd, 0.625)
    local p = Detail.Place(m, 336)
    assertEqual(p.raceW, 181, "the race segment is 1.2 parts of 2.2")
    assertEqual(p.postX, 184)
    assertEqual(p.postW, 152)
    assertEqual(p.buzzer, 181, "the buzzer is the boundary")
    assertTrue(math.abs(p.grace - (184 + 152 / 12)) < 1e-9)
    assertEqual(p.tailX, 184)
    assertEqual(p.tailW, 114)
    assertEqual(p.late[1], 203)
    assertEqual(p.combatEnd, 279)

    run.result.tail = 14
    assertEqual(Detail.Timing(run).span, 18, "a long tail widens the axis")
    -- No combat end heard (a resumed run): the restart and the late casts still size the axis.
    local gap = mkRun("e", {
        result = { damage = 1, dps = 1, tail = 1.2 },
        flags = { lateCasts = { { t = 15, spellID = 348 } }, restartedAt = 14 },
    })
    local mg = Detail.Timing(gap)
    assertEqual(mg.span, 18, "a mark after a missing combat end was skipped")
    assertTrue(mg.restart < 1 and mg.late[1] < 1, "a mark clamped to the strip's edge")
    local inc = mkRun("b", { status = "incomplete", result = { damage = 1, dps = 1, endedAt = 90 } })
    local mi = Detail.Timing(inc)
    assertEqual(mi.raceFill, 0.5)
    assertEqual(Detail.Place(mi, 336).endInRace, 90.5, "combat ended halfway through the race")
    assertEqual(Detail.Timing(mkRun("c", { status = "lost", result = NONE })), nil, "a lost run has no timing")

    -- The pane draws exactly what Place answers.
    seed(i, { mkRun("d", {
        result = { damage = 1, dps = 1, tail = 9, combatEnd = 7.5 },
        flags = { lateCasts = { { t = 1.5, spellID = 29722 }, { t = 3, spellID = 348 } } },
    }) })
    i.R.ShowRun("d")
    local d = ui(i).detail
    assertEqual(#d.place.late, 2)
    local _, ticks = i.NS.Pool.Counts(d.w.ticks)
    assertEqual(ticks, 2, "one tick per late cast")
    assertTrue(d.w.combatEnd:IsShown())
    assertEqual(d.w.tailLine.__text, "Damage stopped +9.0s after the buzzer \194\183 combat ended +7.5s")
    assertEqual(d.w.axisRight.__text, "+12s")
end)

test("results: the detail lists every spell of the run, not a capped top few", function()
    local i = inst()
    local spells = {}
    for n = 1, 45 do spells[n] = { id = 1000 + n, dmg = 100 - n, dps = 1 } end
    seed(i, { mkRun("a", { spells = spells }) })
    i.R.ShowRun("a")
    assertEqual(#ui(i).detail.w.list.rows, 45, "the ability breakdown is the full list (spec §6.2)")
end)

test("results: the detail's spell rows follow HUD Appearance's row height", function()
    local i = inst()
    seed(i, { mkRun("a") })
    assertTrue(i.NS.SetByPath("appearance.bars.rowHeight", 24))
    i.R.ShowRun("a")
    local list = ui(i).detail.w.list
    local second = list.rows[2]
    local y
    for _, p in ipairs(second.__points or {}) do if p[1] == "TOPLEFT" then y = p[5] end end
    if y ~= nil then assertEqual(y, -26, "the second row one pitch down (24 + the 2 px gap)") end
    assertEqual(i.NS.HudBreakdown.Pitch(), 26)
end)

test("results: detail flags name late-cast spells and the session matched by list", function()
    local i = inst()
    seed(i, { mkRun("a", {
        flags = { lateCasts = { { t = 1.4, spellID = 29722 } }, sessionFromList = true },
    }) })
    i.R.ShowRun("a")
    local d = ui(i).detail
    local keys = {}
    for n, line in ipairs(d.flagLines) do keys[n] = line.key end
    assertEqual(table.concat(keys, ","), "lateCasts,sessionFromList")
    assertEqual(d.w.flagTitle.__text, "Flags")
    local rows = d.w.flagRows
    assertEqual(rows[1].main.__text, "1 late cast")
    assertEqual(rows[1].sub.__text, "+1.4s Incinerate")
    local body = rows[1].body.__text
    assertTrue(body:find("Incinerate started +1.4s after the buzzer (grace 1.0s).", 1, true) ~= nil, body)
    assertTrue(body:find("The run still counts", 1, true) ~= nil, body)
    assertEqual(rows[2].main.__text, "Session matched by list")
    assertFalse(rows[2].sub:IsShown(), "a flag with no detail line")
    assertTrue(rows[2].body.__text:find("found by its place in Blizzard's list", 1, true) ~= nil, rows[2].body.__text)

    seed(i, { mkRun("b", { status = "incomplete", result = { damage = 1, dps = 1, endedAt = 60 } }) })
    i.R.ShowRun("b")
    assertEqual(rows[1].main.__text, "Incomplete: combat ended before the buzzer")
    assertEqual(rows[1].body.__text, "It does not count toward bests.")
    assertFalse(rows[2].main:IsShown(), "the second row left from the run before is hidden")
    assertFalse(rows[2].body:IsShown())
    assertEqual(d.w.dps.label.__text, "DPS \194\183 Incomplete")
end)

test("results: delete asks confirmation then fires RUNS_CHANGED", function()
    local i = inst()
    seed(i, { mkRun("a"), mkRun("b", { date = NOW - 2 * HOUR }) })
    local changed = heard(i, "RUNS_CHANGED")
    i.R.ShowRun("a")
    local d = ui(i).detail
    d.w.delete:__fire("OnClick")
    assertEqual(#i.popups, 1, "no confirmation was asked")
    assertEqual(i.popups[1].which, "DPSRACE_DELETE_RUN")
    assertEqual(i.popups[1].data.id, "a")
    assertEqual(i.popups[1].data.onAccept, nil, "the window's own Delete marks nothing")
    assertTrue(i.NS.Recorder.Get("a") ~= nil, "deleted before the player confirmed")
    assertEqual(changed.count, 0)
    i.mocks.StaticPopupDialogs.DPSRACE_DELETE_RUN.OnAccept(nil, i.popups[1].data)
    assertEqual(i.NS.Recorder.Get("a"), nil)
    assertEqual(changed.count, 1)
    assertEqual(i.R.Selected(), nil, "the detail still names a deleted run")
    assertEqual(runsPane(i).countText, "1 run", "the list did not follow the delete")
end)

test("results: note limited to 200 chars", function()
    local i = inst()
    local Detail = i.NS.ResultsDetail
    assertEqual(#Detail.ClampNote(string.rep("a", 250)), 200)
    local accented = Detail.ClampNote(string.rep("\195\169", 250))
    assertEqual(#accented, 400, "200 characters of two bytes each, never a cut through one")
    assertEqual(Detail.ClampNote("  pulled with pots  "), "pulled with pots")
    assertEqual(Detail.ClampNote("|cffff0000red|r"), "/cffff0000red/r", "chat escapes are neutralized")
    assertEqual(Detail.ClampNote(nil), "")

    seed(i, { mkRun("a") })
    local saved, changed = heard(i, "RUN_SAVED"), heard(i, "RUNS_CHANGED")
    i.R.ShowRun("a")
    local d = ui(i).detail
    assertEqual(d.w.addNote.label.__text, "Add Note")
    d.w.addNote:__fire("OnClick")
    assertTrue(d.editing, "Add note opened no editor")
    d.w.noteBox:SetText(string.rep("x", 260))
    d.w.noteBox:__fire("OnEnterPressed")
    assertEqual(#i.NS.Recorder.Get("a").note, 200)
    assertEqual(saved.count, 0, "a note is not a race result: RUN_SAVED would prune the store")
    assertEqual(changed.count, 1, "the note was not announced as a store change")
    assertFalse(d.editing)
    assertEqual(d.w.addNote.label.__text, "Edit Note")
    assertEqual(d.w.note.__text, string.rep("x", 200), "the note as written, under its own heading")
end)

test("results: opening the note scrolls its box into view", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.ShowRun("a")
    local d = ui(i).detail
    d:Layout(340, 140, false)               -- shorter than the run's detail: the box starts below the view
    assertTrue(d.contentH > d.viewH, "the detail fits the pane; the case under test never arises")
    assertEqual(d.scroll, 0)
    d.w.addNote:__fire("OnClick")
    assertEqual(d.scroll, d.contentH - d.viewH, "the note box was left below the visible area")
end)

-- A stand-in GameTooltip that records what it was asked to show.
local function recordingTip(env)
    local tip = { lines = {} }
    for _, m in ipairs({ "Show", "Hide", "ClearAllPoints" }) do tip[m] = function() end end
    function tip.SetOwner(_, owner, anchor) tip.owner, tip.anchor, tip.lines, tip.spell = owner, anchor, {}, nil end
    function tip.SetText(_, text) tip.lines[1] = text end
    function tip.AddLine(_, text) tip.lines[#tip.lines + 1] = text end
    function tip.SetSpellByID(_, id) tip.spell = id end
    function tip.NumLines() return tip.spell and 4 or #tip.lines end
    function tip.GetWidth() return 300 end
    function tip.GetEffectiveScale() return 1 end
    function tip.SetPoint(_, point, _, rel) tip.placed = { point, rel } end
    env.GameTooltip = tip
    return tip
end

test("results: every detail element has a tooltip; spells show the client's spell tooltip beside the window", function()
    local i = inst()
    seed(i, { mkRun("a", { note = "pulled with pots", flags = { lateCasts = { { t = 1.4, spellID = 29722 } } } }) })
    i.R.ShowRun("a")
    local d, Tips = ui(i).detail, i.NS.ResultsTips
    local run = i.NS.Recorder.Get("a")
    for _, key in ipairs({ "class", "name", "realm", "target", "stamp", "damage", "dps", "meterDps", "strip",
                           "tail", "flags", "note", "noteBox", "addNote", "share", "shareOff", "delete", "back" }) do
        local lines = Tips.Detail(key, run)
        assertTrue(type(lines) == "table" and type(lines[1]) == "string", key .. " has a tooltip")
    end
    for n = 1, #i.NS.ResultsDetail.LEGEND do
        assertEqual(Tips.Detail("legend", run, n)[1], i.NS.ResultsDetail.LEGEND[n])
    end

    local tip = recordingTip(i.mocks)
    i.mocks.UIParent = { GetRight = function() return 1920 end, GetEffectiveScale = function() return 1 end }
    local window = i.NS.ResultsTable.WindowOf(d.frame)
    window.GetRight = function() return 1200 end
    window.GetTop = function() return 800 end
    window.GetEffectiveScale = function() return 1 end
    d.w.list.rows[1].GetTop = function() return 700 end
    -- A spell row: the client's spell tooltip, then the exact damage, its share and its place.
    local row = d.w.list.rows[1]
    row:__fire("OnEnter")
    assertEqual(tip.spell, 29722, "the row did not show its spell's tooltip")
    assertEqual(tip.anchor, "ANCHOR_NONE")
    assertEqual(tip.placed[1], "TOPLEFT", "the spell tooltip sits beside the window")
    assertTrue(tip.lines[2] == "\226\128\162 7,330,000 damage", "the exact damage follows the spell, on a bullet")
    assertEqual(tip.lines[4], "\226\128\162 #1 of 2 spells")
    -- The Spell breakdown heading: beside the window, as every tooltip of its section (DR-05).
    d.w.spellsTitleHover:__fire("OnEnter")
    assertTrue(tip.anchor == "ANCHOR_NONE" and tip.placed[1] == "TOPLEFT", "the breakdown heading's beside the window")
    -- Anything else: under itself.
    d.w.dps.frame:__fire("OnEnter")
    assertEqual(tip.anchor, "ANCHOR_BOTTOM")
    assertEqual(tip.owner, d.w.dps.frame)
    assertEqual(tip.lines[1], "147,556 DPS")
    d.w.delete:__fire("OnEnter")
    assertEqual(tip.lines[1], "Delete")
    -- The note's hover frame steps aside while the box is open, so it never takes the box's clicks.
    assertTrue(d.w.noteHover:IsShown())
    d.w.addNote:__fire("OnClick")
    assertFalse(d.w.noteHover:IsShown(), "the note's hover frame covers the open note box")
end)

test("results: the timing strip's marks draw above its two segments", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.ShowRun("a")
    local w = ui(i).detail.w
    -- A child frame draws over its parent's own textures, so marks made on the strip sat under the
    -- opaque segments: they need a frame of their own, above both.
    assertTrue(w.marks ~= nil, "the marks have no frame of their own")
    assertEqual(w.marks:GetParent(), w.strip)
    assertTrue(w.marks:GetFrameLevel() > w.segA:GetFrameLevel(), "the marks sit under the race segment")
    assertTrue(w.marks:GetFrameLevel() > w.segB:GetFrameLevel(), "the marks sit under the after-buzzer segment")
end)

test("results: the timing legend is two rows, the bars' colors over the lines', Restart among the lines", function()
    local i = inst()
    local Detail = i.NS.ResultsDetail
    local named, rows = {}, {}
    for r, indices in ipairs(Detail.LEGEND_ROWS) do
        local labels = {}
        for _, n in ipairs(indices) do
            assertEqual(named[n], nil, "a legend entry sits in two rows")
            named[n] = true
            labels[#labels + 1] = Detail.LEGEND[n]
        end
        rows[r] = table.concat(labels, "|")
    end
    assertEqual(#rows, 2)
    assertEqual(rows[1], "Race|Tail (damage still landing)")
    assertEqual(rows[2], "Grace|Late cast|Combat ended|Restart")
    for n = 1, #Detail.LEGEND do assertTrue(named[n], Detail.LEGEND[n] .. " is in no row") end
end)

test("results: a spell list built without a tip hook takes no mouse", function()
    local i = inst()
    local list = i.NS.HudBreakdown.New(i.mocks.CreateFrame("Frame"))
    list:ShowResult({ spells = { { id = 29722, dmg = 10 } }, result = { damage = 10 } }, 1, true)
    assertEqual(list.rows[1].tipWired, nil, "a list without a tip hook wired a hover")
end)

test("results: saving a note never prunes the store", function()
    local i = inst()
    local runs = {}
    for n = 1, 4 do runs[n] = mkRun("r" .. n, { date = NOW - n * DAY, result = { damage = 1000 * n, dps = 10 * n } }) end
    seed(i, runs)
    i.NS.db.global.history.keepDays = 1     -- lowered with older runs stored: nothing goes until the next race
    assertEqual(i.R.SetNote("r4", "old pull"), "old pull")
    local left = 0
    for _ in pairs(i.NS.db.global.runs) do left = left + 1 end
    assertEqual(left, 4, "typing a note deleted runs")
    assertEqual(i.NS.Recorder.Get("r4").note, "old pull")
end)

test("results: Share is grayed without a Share module; a row's right-click menu notes, shares and deletes", function()
    local i = inst()
    seed(i, { mkRun("a") })
    local module = i.NS.Share
    i.NS.Share = nil
    i.R.ShowRun("a")
    local d = ui(i).detail
    assertFalse(d.w.share:IsEnabled(), "Share is live with nothing to share through")
    assertEqual(type(module.Prompt), "function", "modules/Share.lua publishes NS.Share.Prompt")
    local shared = {}
    i.NS.Share = { Prompt = function(run) shared[#shared + 1] = run.id end }
    i.R.ShowRun("a")
    assertTrue(d.w.share:IsEnabled())
    d.w.share:__fire("OnClick")
    assertEqual(table.concat(shared, ","), "a")
    i.NS.Share = module
    -- No double-click share any more; a right-click opens the row's menu.
    local row = visible(runsPane(i))[1]
    row:__fire("OnDoubleClick")
    assertEqual(#shared, 1, "a double-click no longer shares")
    row:__fire("OnClick", "RightButton")
    local menu = i.mocks.__menus[#i.mocks.__menus]
    assert(menu, "no row menu")
    local labels = {}
    for n, e in ipairs(menu.entries) do labels[n] = e.text end
    assertEqual(table.concat(labels, "|"), "Add Note|Share|Compare With This Run|\124cffff5555Delete\124r")
    local shareEntry = menu:Find("Share")
    local channels = {}
    for n, e in ipairs(shareEntry.children) do channels[n] = e.text end
    assertEqual(table.concat(channels, "|"), "Say|Party|Raid|Guild|Whisper\226\128\166", "Share's channels as a submenu")
    menu:Click("Add Note")
    assertEqual(i.R.Selected(), "a", "Add Note opens the run")
    assertTrue(ui(i).detail.editing, "with its note box open")
    menu:Click("\124cffff5555Delete")
    assertEqual(i.popups[#i.popups].which, "DPSRACE_DELETE_RUN", "Delete asks first")
end)

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
