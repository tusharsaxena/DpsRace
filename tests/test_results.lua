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

test("results: runs list columns: date, class icon, spec icon, character, ilvl, target, length, damage, DPS, flag", function()
    local i = inst()
    local run = mkRun("a", { flags = { lateCasts = { { t = 1.4, spellID = 29722 } }, reloaded = false, died = false } })
    seed(i, { run })
    i.R.Show()
    local pane = runsPane(i)
    local labels = {}
    for n, head in ipairs(pane.list.heads) do labels[n] = head.label.__text end
    assertEqual(table.concat(labels, "|"), "DATE|CLS \194\183 SPEC|CHARACTER|ILVL|TARGET|LEN|DAMAGE|DPS|")
    local row = assert(visible(pane)[1], "no row drawn")
    local c = row.cells
    assertEqual(c.date.fs.__text, os.date("%d %b %H:%M", run.date))
    assertEqual(c.icons.class.__texture, CLASS_ATLAS, "the class icon")
    assertEqual(c.icons.classSpot.tip[1], "Warlock", "the class icon's tooltip")
    assertEqual(c.icons.spec.__texture, 136186, "the spec icon")
    assertEqual(c.icons.specSpot.tip[1], "Destruction", "the spec icon's tooltip")
    assertEqual(c.char.fs.__text, "Lanfear")
    assertEqual(c.char.fs.__color[1], 0.53, "the character is class-colored")
    assertEqual(c.ilvl.fs.__text, "313.2")
    assertEqual(c.target.fs.__text, "CLEAVE \195\1515")
    assertEqual(c.length.fs.__text, "3:00")
    assertEqual(c.damage.fs.__text, "26.56M")
    assertEqual(c.dps.fs.__text, "147.5K")
    assertTrue(c.flag.icon:IsShown(), "the flag mark")
    assertTrue(c.flag.texts[1]:find("Incinerate", 1, true) ~= nil, "the flag tooltip names the spell")
end)

test("results: incomplete and lost runs say so in the DPS column", function()
    local i = inst()
    seed(i, {
        mkRun("inc", { status = "incomplete", result = { damage = 900000, dps = 10000, endedAt = 90 } }),
        mkRun("lost", { status = "lost", result = NONE, date = NOW - 2 * HOUR }),
    })
    i.R.Show()
    local rows = visible(runsPane(i))
    assertEqual(#rows, 2)
    assertEqual(rows[1].cells.dps.fs.__text, "incomplete")
    assertEqual(rows[1].cells.damage.fs.__text, "900.0K")
    assertEqual(rows[2].cells.dps.fs.__text, "lost")
    assertEqual(rows[2].cells.damage.fs.__text, "\226\128\148")
    assertFalse(rows[1].cells.flag.icon:IsShown(), "a status is not a flag")
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
    local function ids(f)
        local out = {}
        for n, run in ipairs(Runs.Filter(all, f, NOW)) do out[n] = run.id end
        return table.concat(out, ",")
    end
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
    assertEqual(options.char[1].label, "All characters")
    assertEqual(#options.char, 4)
    assertEqual(options.spec[1].label, "All specs")
    assertEqual(options.category[1].label, "All targets")
    assertEqual(options.length[1].label, "Any length")
    assertEqual(options.length[2].label, "0:30")
    assertEqual(options.date[4].label, "Last 30 days")

    -- The bar drives the same filters.
    seed(i, all)
    i.R.Show()
    local pane = runsPane(i)
    assertEqual(pane.count.__text, "5 runs")
    pane.checks.hideFlagged:__fire("OnClick")
    assertEqual(pane.count.__text, "4 runs")
    pane.checks.includeIncomplete:__fire("OnClick")
    assertEqual(pane.count.__text, "2 runs")
    pane.dropdowns.char.onSelect("Kaosmage-Frostmourne")
    assertEqual(pane.count.__text, "1 run")
    assertEqual(visibleIDs(pane), "c")
end)

test("results: sort by DPS desc default; by ilvl", function()
    local i = inst()
    seed(i, {
        mkRun("lo", { result = { damage = 1, dps = 100000 }, char = "lan" }),
        mkRun("hi", { result = { damage = 1, dps = 200000 }, char = "mage" }),
        mkRun("mid", { result = { damage = 1, dps = 150000 }, char = "druid" }),
        mkRun("inc", { status = "incomplete", result = { damage = 1, dps = 999999, endedAt = 9 } }),
    })
    i.R.Show()
    local pane = runsPane(i)
    assertEqual(visibleIDs(pane), "hi,mid,lo,inc", "an unranked run sorts last")
    local heads = pane.list.heads
    assertEqual(heads[8].label.__color[1], 1.0, "the sorted header is gold")
    assertTrue(heads[8].arrow:IsShown(), "the sorted header carries the direction mark")
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
    assertEqual(d.w.meta[2].__text, "Cleave Training Dummy \194\183 CLEAVE \195\1515 \194\183 3:00")
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
    assertEqual(d.w.dps.label.__text, "DPS \194\183 INCOMPLETE")
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
    assertEqual(runsPane(i).count.__text, "1 run", "the list did not follow the delete")
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
    assertEqual(d.w.addNote.label.__text, "ADD NOTE")
    d.w.addNote:__fire("OnClick")
    assertTrue(d.editing, "Add note opened no editor")
    d.w.noteBox:SetText(string.rep("x", 260))
    d.w.noteBox:__fire("OnEnterPressed")
    assertEqual(#i.NS.Recorder.Get("a").note, 200)
    assertEqual(saved.count, 0, "a note is not a race result: RUN_SAVED would prune the store")
    assertEqual(changed.count, 1, "the note was not announced as a store change")
    assertFalse(d.editing)
    assertEqual(d.w.addNote.label.__text, "EDIT NOTE")
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

test("results: Share is grayed without a Share module; a double-click shares", function()
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
    visible(runsPane(i))[1]:__fire("OnDoubleClick")
    assertEqual(table.concat(shared, ","), "a,a")
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
    assertEqual(top.flags.fs.__text, "1 LATE")
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
    assertEqual(pane.count.__text, "1 run")
    i.NS.Recorder.Save(mkRun("b", { date = NOW, result = { damage = 1, dps = 999999 } }))
    assertEqual(pane.count.__text, "2 runs")
    assertEqual(visible(pane)[1].run.id, "b")
    i.NS.Recorder.Delete("a")
    assertEqual(pane.count.__text, "1 run", "RUNS_CHANGED did not redraw")
    i.R.Hide()
    i.NS.Recorder.Save(mkRun("c"))
    i.R.Show()
    assertEqual(pane.count.__text, "2 runs", "a hidden window came back stale")
end)

test("results: the HUD's Last result opens the newest run's detail", function()
    local i = inst()
    seed(i, { mkRun("old", { date = NOW - DAY }), mkRun("new", { date = NOW - HOUR }) })
    i.NS.Hud.Act.lastResult()
    assertTrue(i.R.IsShown())
    assertEqual(i.R.Selected(), "new")
    assertEqual(ui(i).detail.run.id, "new")
    i.R.ShowRun("nope")
    assertEqual(i.R.Selected(), nil, "an id no longer stored opens the list alone")
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
    assertEqual(minW, 760)
    assertEqual(minH, 420)
    assertEqual(u.width, 1040)
    assertEqual(u.height, 560)
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
    u.frame:__fire("OnSizeChanged", 980, 600)
    assertEqual(u.width, 980)
    assertTrue(i.NS.SetByPath("scale", 1.25))
    assertEqual(u.frame.__scale, 1.25)
    w.width = 900
    i.NS.SetByPath("scale", 1.0)
    i.R.ResetPosition()
    assertEqual(w.point, nil)
    assertEqual(w.width, nil)
    assertEqual(u.width, 1040)
end)

test("results: below 900px wide the detail replaces the list, with a back control", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.NS.db.profile.windows.results = { width = 800, height = 500 }
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
    rowB.cells.icons.classSpot:__fire("OnMouseUp")
    assertEqual(j.R.Selected(), "b", "a click on the class icon did not select its row")
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
