-- tests/test_results.lua — the Results window's run list (modules/Results*.lua, spec §6.2): its columns,
-- filters and sorting. The detail is tests/test_results_detail.lua's; the shell, the store and the
-- window chrome are tests/test_results_window.lua's.
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
