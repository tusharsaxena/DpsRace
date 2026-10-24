-- tests/test_results.lua — the Results window (modules/Results*.lua, spec §6.2): the run list's
-- columns, filters and sorting, the run detail (breakdown, timing strip, flags, note, delete, share),
-- the Bests tab and its clean-only board, the window chrome and its wide/narrow layouts, and how it
-- follows the store and the lifecycle.
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

test("results: runs list columns: date, class icon, spec icon, character, ilvl, target, time, damage, DPS, v/s Max, status", function()
    local i = inst()
    local run = mkRun("a", { flags = { lateCasts = { { t = 1.4, spellID = 29722 } }, reloaded = false, died = false } })
    seed(i, { run })
    i.R.Show()
    local pane = runsPane(i)
    local labels = {}
    for n, head in ipairs(pane.list.heads) do labels[n] = (head.label.__text or ""):gsub("%s*|T.-|t", "") end
    assertEqual(table.concat(labels, "|"), "Date|Class|Character|iLvl|Target|Time|Damage|DPS|v/s Max|Status", "no flag column: the Status cell carries the flags")
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
    assertEqual(c.target.fs.__text, "Cleave \195\1515")
    assertEqual(c.time.fs.__text, "3:00 |cff9e9ead+9.2s|r", "the length, then the tail in the caption gray")
    assertEqual(c.damage.fs.__text, "26.56M")
    assertEqual(c.dps.fs.__text, "147.5K")
    assertEqual(c.status.fs.__text, "Spec best (cleave)", "a best outranks its flag in the tag")
    local status = pane.list:TipLines(run, 10)
    assertEqual(status[1], "Spec best (cleave)")
    local named = false
    for _, l in ipairs(status) do
        if type(l) == "table" and l[1]:find("Incinerate", 1, true) then named = true end
    end
    assertTrue(named, "the Status tooltip carries the flag, naming the spell")
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
    assertEqual(rows[1].cells.time.fs.__text, "1:30 / 3:00")
    assertEqual(rows[2].cells.dps.fs.__text, "\226\128\148")
    assertEqual(rows[2].cells.status.fs.__text, "Lost")
    assertEqual(rows[2].cells.damage.fs.__text, "\226\128\148")
    assertEqual(rows[3].cells.status.fs.__text, "Died")
end)

test("results: Status is Max, Spec best, Flagged or Complete for a complete run, each with its icon", function()
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
    assertEqual(key, "best", "with no view max given, the board's best")
    assertEqual(text, "Spec best (cleave)", "the target type follows")
    assertEqual(bestColor, C.blue, "Spec best in blue")
    assertEqual(icon, "ph:trophy", "Spec best draws the trophy")
    local maxColor
    key, text, maxColor, icon = Runs.Status(by.top, 150000)
    assertEqual(key, "max", "the view's max outranks Spec best")
    assertEqual(text, "Max (cleave)")
    assertEqual(icon, "ph:crown")
    assertEqual(maxColor, C.violet, "Max in violet")
    i.R.Show()
    local badge, other
    for _, row in ipairs(visible(runsPane(i))) do
        if row.run.id == "top" then badge = row.cells.status end
        if row.run.id == "slow" then other = row.cells.status end
    end
    assert(badge, "the top run is drawn")
    assertEqual(badge.fs.__text, "Spec best (cleave)", "one spec in the view: its top run is its Spec best, no Max")
    assertTrue(badge.icon:IsShown(), "the icon shows before the word")
    assertEqual(badge.icon.__texture, i.NS.Icon("ph:trophy"))
    -- A second spec in the view (the mage's run): now the view-wide top is Max.
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
    assertEqual(badge.fs.__text, "Max (cleave)", "two specs in the view: the top run is Max")
    assertEqual(badge.icon.__texture, i.NS.Icon("ph:crown"))
    assertTrue(Runs.ManySpecs(i.NS.Recorder.All()))
    assertEqual(other.fs.__text, "Complete")
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
    local indigo = i.NS.defaults.profile.appearance.bars.barColor
    assertEqual(D.damageBar.barColor.r, indigo.r, "the breakdown's indigo fill")
    assertEqual(D.dpsBar.barColor.b, indigo.b, "the same fill on both bars")
    assertEqual(D.damageBar.barAlpha, 0.85)
    assertEqual(cells.damage.bar.__vertex[1], 0.29, "the indigo fill")
    assertEqual(cells.dps.bar.__vertex[3], 0.45)
    assertEqual(cells.dps.bar.__vertex[4], 0.85, "at the breakdown's opacity")
    assertEqual(cells.damage.track, nil, "no track behind the bar")
    assertEqual(cells.damage.edges, nil, "and no border")
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

test("results: the Damage and DPS bars run 10% to 100% within each target type", function()
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
    local w = {}
    for _, row in ipairs(visible(runsPane(i))) do
        local d = row.cells.damage
        w[row.run.id] = { bar = d.bar.__width, full = d.barW }
    end
    assertEqual(w.cBig.bar, w.cBig.full, "the cleave max fills its cell")
    assertEqual(w.bBig.bar, w.bBig.full, "the boss-level max fills its cell too, though cleave did more")
    assertEqual(w.bSmall.bar, math.max(1, math.floor(w.bSmall.full * 0.1 + 0.5)), "each type's min at 10%")
    assertEqual(w.cSmall.bar, w.bSmall.bar)
end)

test("results: v/s Max and the Max tag are per target type", function()
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
    local cells = {}
    for _, row in ipairs(visible(runsPane(i))) do cells[row.run.id] = row.cells end
    assertEqual(cells.cleave.vsMax.fs.__text, "0.0%")
    assertEqual(cells.cleave2.vsMax.fs.__text, "-50.0%")
    assertEqual(cells.boss.vsMax.fs.__text, "0.0%", "the boss-level max is its own")
    assertEqual(cells.boss2.vsMax.fs.__text, "-50.0%")
    assertEqual(cells.boss.status.fs.__text, "Spec best (boss-level)", "one spec per target type: no Max")
end)

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
    assertEqual(pane.filters.group, "none", "flat by default")
    local opts = Runs.Options(i.NS.Recorder.All()).group
    assertEqual(opts[1].label, "Group: None")
    assertEqual(#opts, 4)
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
    assertEqual(pane.filters.group, "none")
    assertEqual(pane.list.sortKey, "date")
    assertTrue(pane.list.sortDesc)
    -- Clear with nothing saved is the stock view too.
    pane:SetFilter("hideFlagged", true)
    pane.viewButtons.clear:__fire("OnClick")
    assertFalse(pane.filters.hideFlagged)
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
end)

test("results: v/s Max is each run's distance from the max DPS among the runs the filters pass", function()
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
    assertEqual(Runs.VsMax(by.top, top), 0)
    assertTrue(math.abs(Runs.VsMax(by.slow, top) - (120000 / 150000 - 1) * 100) < 1e-9)
    assertTrue(math.abs(Runs.VsMax(by.short, top) - -50) < 1e-9, "every board against the one max")
    assertTrue(math.abs(Runs.VsMax(by.inc, top) - 20) < 1e-9, "an incomplete run is compared, never ranked")
    assertEqual(Runs.VsMax(by.lost, top), nil)
    assertEqual(Runs.VsMax(by.slow, nil), nil, "no complete run in the view")
    assertEqual(Runs.MaxDps({ by.inc, by.lost }), nil)
    i.R.Show()
    local pane = runsPane(i)
    local labels = {}
    for n, head in ipairs(pane.list.heads) do labels[n] = (head.label.__text or ""):gsub("%s*|T.-|t", "") end
    assertEqual(labels[9], "v/s Max")
    local function cells()
        local out = {}
        for _, row in ipairs(visible(pane)) do out[row.run.id] = row.cells.vsMax.fs end
        return out
    end
    local c = cells()
    assertEqual(c.top.__text, "0.0%")
    assertEqual(c.top.__color[1], i.NS.ResultsTable.COLORS.gold[1], "the max run in gold")
    assertEqual(c.slow.__text, "-20.0%")
    assertEqual(c.slow.__color[1], 1.0, "below the max in red")
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
    pane.list:SetSort("vsMax", true)
    local order = {}
    for n, run in ipairs(pane.list.rows) do order[n] = run.id end
    assertEqual(table.concat(order, ","), "mage,inc,top,slow,short,lost")
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
    assertEqual(rawIds({}), "a,b,e", "the defaults: the logged-in character (Lanfear), in their current spec")
    assertEqual(rawIds({ char = "all" }), "a,b,e", "the current spec across characters")
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
    assertEqual(d.w.meta[2].__text, "Cleave Training Dummy \194\183 Cleave \195\1515 \194\183 3:00 +2.0s")
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
    assertEqual(d.w.flagTitle.__text, "Flags \194\183 2")
    local body = d.w.flagBody.__text
    assertTrue(body:find("Incinerate started +1.4s after the buzzer (grace 1.0s).", 1, true) ~= nil, body)
    assertTrue(body:find("Session matched by list", 1, true) ~= nil, body)
    assertTrue(body:find("The run still counts", 1, true) ~= nil, body)

    seed(i, { mkRun("b", { status = "incomplete", result = { damage = 1, dps = 1, endedAt = 60 } }) })
    i.R.ShowRun("b")
    assertTrue(d.w.flagTitle.__text:find("Incomplete", 1, true) ~= nil, d.w.flagTitle.__text)
    assertTrue(d.w.flagBody.__text:find("does not count toward bests", 1, true) ~= nil)
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
    assertEqual(i.popups[1].data, "a")
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
    assertEqual(d.w.note.__text, "Note: " .. string.rep("x", 200))
end)

test("results: saving a note never prunes the store", function()
    local i = inst()
    local runs = {}
    for n = 1, 4 do runs[n] = mkRun("r" .. n, { date = NOW - n * DAY, result = { damage = 1000 * n, dps = 10 * n } }) end
    seed(i, runs)
    i.NS.db.global.history.keep = 1         -- lowered with four stored: nothing goes until the next race
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
    assertEqual(table.concat(labels, "|"), "Add Note|Share|\124cffff5555Delete\124r")
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

-- ── the bests board ─────────────────────────────────────────────────────────────────────────────

test("results: bests tab groups by spec x category x length with clean-only toggle", function()
    local i = inst()
    seed(i, {
        mkRun("flagged", { result = { damage = 27000000, dps = 150000 },
                           flags = { lateCasts = { { t = 1.4, spellID = 29722 } } } }),
        mkRun("clean", { result = { damage = 25200000, dps = 140000 }, date = NOW - 2 * DAY }),
        mkRun("short", { race = { length = 30, grace = 1 }, result = { damage = 1500000, dps = 50000 } }),
        mkRun("fire", { char = "mage", target = { category = "single", count = 1 },
                        result = { damage = 23400000, dps = 130000 } }),
        mkRun("inc", { char = "mage", target = { category = "single", count = 1 }, status = "incomplete",
                       result = { damage = 99000000, dps = 999999, endedAt = 9 } }),
    })
    i.R.Show()
    assertEqual(ui(i).panes.bests, nil, "the Bests tab was built before it was shown")
    i.R.ShowTab("bests")
    local pane = assert(ui(i).panes.bests)
    assertFalse(runsPane(i).frame:IsShown(), "the Runs tab still shows")
    assertEqual(pane.filters.category, "single", "the first category present")
    assertEqual(visibleIDs(pane), "fire")
    pane.dropdowns.category.onSelect("cleave")
    assertEqual(pane:Count(), 2, "one row per spec x length within the category")
    assertEqual(visibleIDs(pane), "flagged,short")
    local top = visible(pane)[1].cells
    assertEqual(top.icons.fs.__text, "Destruction")
    assertEqual(top.char.fs.__text, "Lanfear")
    assertEqual(top.dps.fs.__text, "150.0K")
    assertEqual(top.flags.fs.__text, "1 late")
    assertEqual(top.date.fs.__text, os.date("%d %b", NOW - HOUR))

    pane.clean:__fire("OnClick")
    assertTrue(pane.filters.cleanOnly)
    assertEqual(visibleIDs(pane), "clean,short", "the clean board's best on that board")
    pane.dropdowns.category.onSelect("single")
    pane.dropdowns.spec.onSelect(63)
    assertEqual(visibleIDs(pane), "fire")
    pane.dropdowns.spec.onSelect("all")
    pane.dropdowns.category.onSelect("cleave")
    assertEqual(pane:Count(), 2)

    visible(pane)[1]:__fire("OnClick")
    assertEqual(i.R.Tab(), "runs", "a bests row opens its run on the Runs tab")
    assertEqual(i.R.Selected(), "clean")
end)

test("results: the Bests board shows one category at a time, so a spec and length is one row", function()
    local i = inst()
    seed(i, {
        mkRun("cleave", { result = { damage = 26500000, dps = 147000 } }),
        mkRun("single", { target = { npcID = 225984, name = "Training Dummy", category = "single", count = 1 },
                          result = { damage = 8900000, dps = 49000 } }),
    })
    i.R.ShowTab("bests")
    local pane = assert(ui(i).panes.bests)
    assertEqual(pane.filters.category, "single", "the first category on the board, in the canonical order")
    assertEqual(visibleIDs(pane), "single", "two boards of one spec and length side by side, told apart by nothing")
    local values = {}
    for n, o in ipairs(i.NS.ResultsBests.Options(i.NS.Bests.Board({})).category) do values[n] = o.value end
    assertEqual(table.concat(values, ","), "single,cleave", "an All categories choice mixes boards")
    pane.dropdowns.category.onSelect("cleave")
    assertEqual(visibleIDs(pane), "cleave")
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

test("results: Runs opens on the current character and spec, each a choice of its own", function()
    local i = inst()
    seed(i, { mkRun("mine"), mkRun("mage", { char = "mage", date = NOW - 2 * HOUR }) })
    i.R.Show()
    local pane = runsPane(i)
    assertEqual(pane.filters.char, "current")
    assertEqual(pane.filters.spec, "current")
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
    assertEqual(i.R.View(), "expanded", "a new profile opens expanded")
    assertEqual(minW, 1180)
    assertEqual(minH, 420)
    assertEqual(u.width, 1220)
    assertEqual(u.height, 560)
    -- The toggle: collapsed has its own size and minimum; expanding brings the first back.
    assertEqual(u.viewToggle.iconName, "chevron-left", "expanded: the toggle folds the detail away")
    u.viewToggle:__fire("OnClick")
    assertEqual(i.R.View(), "collapsed")
    assertEqual(i.R.Mode(), "narrow")
    assertEqual((u.frame:GetResizeBounds()), 800)
    assertEqual(u.width, 900)
    assertEqual(u.viewToggle.iconName, "chevron-right")
    assertEqual(runsPane(i).barH, 2 * 32 - 6, "collapsed: the filter bar is two rows")
    u.viewToggle:__fire("OnClick")
    assertEqual(i.R.View(), "expanded")
    assertEqual(u.width, 1220)
    assertTrue(u.frame.innerBorder ~= nil, "the Ka0s window edge was not applied")
    assertEqual(u.frame.title.__text, "DPS Race \226\128\148 Results")
    assertEqual(u.footRight.__text, "Runs to keep: 0 (never prune)")
    u.close:__fire("OnClick")
    assertFalse(i.R.IsShown())
    assertFalse(u.frame:IsShown())
end)

test("results: position, size and Master scale persist; Reset position restores them", function()
    local i = inst()
    i.R.Show()
    local u = ui(i)
    rawset(u.frame, "GetPoint", function() return "TOPLEFT", nil, "BOTTOMLEFT", 40.4, 600.6 end)
    u.drag:__fire("OnDragStart")
    u.drag:__fire("OnDragStop")
    local w = i.NS.db.profile.windows.results
    assertEqual(w.point, "TOPLEFT")
    assertEqual(w.x, 40)
    assertEqual(w.y, 601)
    u.frame:__fire("OnSizeChanged", 1300, 600)
    assertEqual(u.width, 1300)
    u.frame:__fire("OnSizeChanged", 900, 600)
    assertEqual(u.width, 1180, "expanded never goes under its minimum")
    assertEqual(i.R.View(), "expanded", "a narrower window does not collapse the view")
    assertTrue(i.NS.SetByPath("scale", 1.25))
    assertEqual(u.frame.__scale, 1.25)
    w.expanded = { width = 1300, height = 600 }
    w.collapsed = { width = 950, height = 500 }
    i.NS.SetByPath("scale", 1.0)
    i.R.ResetPosition()
    assertEqual(w.point, nil)
    assertEqual(w.expanded, nil)
    assertEqual(w.collapsed, nil)
    assertEqual(u.width, 1220)
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
    assertEqual(#u.panes.runs.list:Visible(), 1)
    i.R.ShowTab("bests")
    assertEqual(u.panes.bests:Count(), 1)
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
        if l == "results tab=runs mode=wide rows=1 selected=a" then found = true end
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
    assertEqual(u.tabs.bests.label.__text, "Bests")
    assertEqual(u.tabs.runs.label.__fontObject, "GameFontNormal", "a tab")
    assertEqual(u.tabs.runs.label.__color[2], 0.82, "the active tab is gold")
    assertEqual(u.tabs.bests.label.__color[1], 0.7, "an idle tab is gray")
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
    assertEqual(d.w.name.__fontObject, "GameFontHighlight", "the name that heads the pane")
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

test("results: the close control turns gold under the pointer and back to its gray", function()
    local i = inst()
    i.R.Show()
    local close = assert(ui(i).close, "no close control")
    local GOLD, REST = i.NS.Style.GOLD, i.NS.Style.REST
    local function is(c)
        local v = close.icon.__vertex
        return v ~= nil and v[1] == c[1] and v[2] == c[2] and v[3] == c[3]
    end
    assertTrue(is(REST), "at rest")
    close:__fire("OnEnter")
    assertTrue(is(GOLD), "under the pointer")
    close:__fire("OnLeave")
    assertTrue(is(REST), "back at rest")
end)
