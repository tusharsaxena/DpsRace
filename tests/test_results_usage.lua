-- tests/test_results_usage.lua — what a run used (#13) in the Results window (modules/Results_Usage.lua):
-- the pure helpers (the entries' order, each entry's detail, the section's rows, the ticks and whether
-- they changed, the icons that fit a cell), the Runs list's Used column (its icons, "+n", the dash,
-- its tooltip and its sort) and the run detail's Usage section (its rows, pre-ticked as detected, the
-- clickable labels, Save live only on a change and writing Usage.SetUsed, Not recorded for an older
-- run, and a sample run changed in memory only).

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()

-- The items the cases use: two trinkets, a potion, a flask and a Healthstone.
local TRINKET, TRINKET2, POTION, FLASK, STONE = 190001, 190002, 211001, 211002, 5512
local NAMES = { [TRINKET] = "Test Trinket", [TRINKET2] = "Other Trinket", [POTION] = "Potion of Testing",
                [FLASK] = "Flask of Testing", [STONE] = "Healthstone" }

local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
        m.C_Item.GetItemNameByID = function(id) return NAMES[id] end
        m.C_Item.GetItemIconByID = function(id) return type(id) == "number" and 5000000 + id or 134400 end
    end }
    i.R = i.NS.Results
    return i
end

-- A usage record: the trinket cast twice, the potion once, a Healthstone gone from the bags, the
-- flask's buff and Well Fed on at the arm, an oil's enchant on the main hand. The second trinket and
-- the Healthstone are candidates too; the second trinket was not used.
local function usage()
    return {
        v = 1, edited = false,
        used = {
            { itemID = TRINKET, kind = "gear", slot = 13, times = { 9.2, 72.4 }, n = 2, src = "cast" },
            { itemID = POTION, kind = "potion", times = { -1.6 }, n = 1, src = "cast" },
            { itemID = STONE, kind = "other", n = 1, src = "bag" },
            { itemID = FLASK, kind = "flask", n = 1, src = "buff" },
            { kind = "food", n = 1, src = "buff" },
            { kind = "enchant", slot = 16, enchantID = 8051, n = 1, src = "enchant" },
        },
        candidates = {
            { itemID = TRINKET, kind = "gear", slot = 13 }, { itemID = TRINKET2, kind = "gear", slot = 14 },
            { itemID = POTION, kind = "potion" }, { itemID = FLASK, kind = "flask" }, { itemID = STONE, kind = "other" },
        },
    }
end

local function mkRun(id, fields)
    local run = {
        id = id, schema = 3, status = "complete", addon = "0.1.0", date = NOW - 3600,
        race = { length = 180, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction",
                 ilvl = 313.2 },
        target = { npcID = 225983, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = 26560000, dps = 147555.6, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = 29722, dmg = 7330000 } }, note = "", usage = usage(),
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    if run.usage == false then run.usage = nil end
    return run
end

local function seed(i, runs)
    for _, run in ipairs(runs) do i.NS.db.global.runs[run.id] = run end
    i.NS.Bests.Invalidate()
end

local function ui(i) return assert(i.R.__ui(), "the Results window was never built") end
local function section(i) return ui(i).detail.usage end

-- The Runs pane ungrouped, so its rows are runs.
local function runsPane(i)
    local pane = assert(ui(i).panes.runs, "the Runs tab was never built")
    if pane.filters.group ~= "none" then pane:SetFilter("group", "none") end
    return pane
end

local function rowOf(pane, id)
    for _, row in ipairs(pane.list:Visible()) do
        if row.run and row.run.id == id then return row end
    end
end

local function colIndex(pane, key)
    for n, col in ipairs(pane.list.columns) do if col.key == key then return n end end
end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────────

test("results usage: entries list the gear first; a run stored before format 3 has none", function()
    local NS = inst().NS
    local U = NS.ResultsUsage
    local u = usage()
    -- The gear stored last still leads.
    table.insert(u.used, table.remove(u.used, 1))
    local entries = U.Entries({ usage = u })
    assertEqual(#entries, 6)
    assertEqual(entries[1].itemID, TRINKET, "the gear first")
    assertEqual(entries[2].itemID, POTION, "then everything else in its stored order")
    assertEqual(U.Count({ usage = u }), 6)
    assertNil(U.Entries({}), "no record: not recorded")
    assertNil(U.Count({}), "a run with no record sorts last")
    assertEqual(U.Count({ usage = { v = 1, used = {}, candidates = {} } }), 0)
end)

test("results usage: each entry's detail says how many times and when, or why there is no time", function()
    local U = inst().NS.ResultsUsage
    local used = usage().used
    assertEqual(U.Detail(used[1]), "x2 at 0:09, 1:12")
    assertEqual(U.Detail(used[2]), "at -0:02", "a pre-pull use keeps its minus sign")
    assertEqual(U.Detail(used[3]), "time unknown", "a bag drop")
    assertEqual(U.Detail({ itemID = STONE, kind = "other", n = 2, src = "bag" }), "x2, time unknown")
    assertEqual(U.Detail(used[4]), "active at the start", "a flask's buff at the arm")
    assertEqual(U.Detail(used[6]), "active at the start", "an enchant at the arm")
    assertEqual(U.Detail({ itemID = TRINKET2, kind = "gear", n = 1, src = "manual" }), "time unknown")
    assertEqual(U.Clock(125), "2:05")
    assertEqual(U.Clock(-0.3), "0:00", "a use that rounds to the pull has no minus sign")
    assertEqual(U.Clock(-0.6), "-0:01")
end)

test("results usage: names and icons come from the item data; food and an enchant have their own", function()
    local U = inst().NS.ResultsUsage
    local used = usage().used
    assertEqual(U.Name(used[1]), "Test Trinket")
    assertEqual(U.Icon(used[1]), 5000000 + TRINKET)
    assertEqual(U.Name(used[5]), "Well Fed")
    assertEqual(U.Icon(used[5]), U.FOOD_ICON)
    assertEqual(U.Name(used[6]), "Weapon enchant (main hand)")
    assertEqual(U.Icon(used[6]), U.ENCHANT_ICON)
    assertEqual(U.Name({ itemID = 4242, kind = "other" }), "Item 4242", "an item the client has not cached")
end)

test("results usage: one row per candidate, then each detected entry no candidate stands for", function()
    local U = inst().NS.ResultsUsage
    local rows = U.Rows({ usage = usage() })
    assertEqual(#rows, 7, "five candidates, then Well Fed and the enchant")
    local ids = {}
    for n, row in ipairs(rows) do ids[n] = tostring(row.itemID or row.kind) end
    assertEqual(table.concat(ids, ","), table.concat({ TRINKET, TRINKET2, POTION, FLASK, STONE, "food", "enchant" }, ","))
    assertTrue(rows[1].entry ~= nil and rows[1].entry.n == 2, "the trinket stands for its detected entry")
    assertNil(rows[2].entry, "the second trinket was not used")
    assertEqual(rows[7].enchantID, 8051)
    assertNil(U.Rows({}), "not recorded")
end)

test("results usage: the ticks follow the rows, and a change is any row ticked against what was stored", function()
    local U = inst().NS.ResultsUsage
    local rows = U.Rows({ usage = usage() })
    local state = { true, nil, true, true, true, true, true }
    assertFalse(U.Changed(rows, state), "the detected ticks are what is stored")
    state[2] = true
    assertTrue(U.Changed(rows, state), "a new tick")
    state[2], state[3] = nil, nil
    assertTrue(U.Changed(rows, state), "an untick")
    local ticks = U.Ticks(rows, state)
    assertEqual(#ticks, 5)
    assertEqual(ticks[1].itemID, TRINKET)
    assertEqual(ticks[1].slot, 13)
    assertEqual(ticks[2].itemID, FLASK, "the potion untick leaves it out")
    assertEqual(ticks[4].kind, "food")
    assertEqual(ticks[5].enchantID, 8051)
end)

test("results usage: an items cell draws what fits, or one fewer and +n", function()
    local Tbl = inst().NS.ResultsTable
    assertEqual(Tbl.IconSlots(70), 4, "16 px icons, 2 px apart")
    local shown, more = Tbl.IconsFit(4, 70)
    assertEqual(shown .. "+" .. more, "4+0")
    shown, more = Tbl.IconsFit(6, 70)
    assertEqual(shown .. "+" .. more, "3+3", "the last slot counts the rest")
    shown, more = Tbl.IconsFit(0, 70)
    assertEqual(shown .. "+" .. more, "0+0")
end)

-- ── the Used column ─────────────────────────────────────────────────────────────────────────────

test("results usage: the Used column draws the icons gear first, then +n; a dash for nothing or no record", function()
    local i = inst()
    local NS = i.NS
    seed(i, { mkRun("a"), mkRun("b", { date = NOW - 7200, usage = { v = 1, used = {}, candidates = {} } }),
              mkRun("old", { date = NOW - 9000, schema = 2, usage = false }) })
    i.R.Show()
    local pane = runsPane(i)
    local cols = NS.ResultsRuns.Columns()
    assertEqual(cols[#cols - 1].key, "used", "Used sits before Note")
    assertEqual(cols[#cols - 1].width, NS.ResultsRuns.USED_W)
    local cell = rowOf(pane, "a").cells.used
    assertEqual(cell.slots, 4)
    assertTrue(cell.icon1:IsShown() and cell.icon3:IsShown(), "three icons")
    assertFalse(cell.icon4:IsShown(), "the last slot holds the count")
    assertEqual(cell.icon1.__texture, 5000000 + TRINKET, "the trinket first")
    assertEqual(cell.icon2.__texture, 5000000 + POTION)
    assertTrue(cell.more:IsShown())
    assertEqual(cell.more.__text, "+3")
    assertFalse(cell.dash:IsShown())
    for _, id in ipairs({ "b", "old" }) do
        local c = rowOf(pane, id).cells.used
        assertTrue(c.dash:IsShown(), id .. ": no dash")
        assertFalse(c.icon1:IsShown(), id .. ": an icon with nothing used")
        assertFalse(c.more:IsShown())
    end
end)

test("results usage: the Used tooltip names each entry with when, or says why there is none", function()
    local i = inst()
    -- Seven entries: the header, seven lines and the hint pass the old eight-line cap.
    local seven = usage()
    seven.used[#seven.used + 1] = { itemID = TRINKET2, kind = "gear", slot = 14, n = 1, src = "manual" }
    seed(i, { mkRun("a", { usage = seven }), mkRun("old", { date = NOW - 9000, schema = 2, usage = false }),
              mkRun("b", { date = NOW - 7200, usage = { v = 1, used = {}, candidates = {} } }) })
    i.R.Show()
    local pane = runsPane(i)
    local n = colIndex(pane, "used")
    local lines = pane.list:TipLines(i.NS.Recorder.Get("a"), n)
    assertEqual(lines[1], "7 items used")
    assertEqual(lines[2], "Test Trinket: x2 at 0:09, 1:12")
    assertEqual(lines[3], "Other Trinket: time unknown", "the gear first")
    assertEqual(lines[4], "Potion of Testing: at -0:02")
    assertEqual(lines[5], "Healthstone: time unknown")
    assertEqual(lines[6], "Flask of Testing: active at the start")
    assertEqual(lines[7], "Well Fed: active at the start")
    assertEqual(lines[8], "Weapon enchant (main hand): active at the start")
    assertEqual(#lines, 9, "every entry is listed, past the old eight-line cap, then the hint")
    assertEqual(type(lines[9]), "table", "the hint comes last")
    assertEqual(pane.list:TipLines(i.NS.Recorder.Get("old"), n)[1], "Not recorded")
    assertEqual(pane.list:TipLines(i.NS.Recorder.Get("b"), n)[1], "Nothing used")
    local about = i.NS.ResultsTips.About(pane.list.columns[n])
    assertTrue(about ~= nil and about.text:find("trinkets first", 1, true) ~= nil, "the header's tooltip")
end)

test("results usage: the Used column sorts by how many entries, a run with no record last either way", function()
    local i = inst()
    local NS = i.NS
    local one = { v = 1, used = { { itemID = POTION, kind = "potion", n = 1, src = "bag" } }, candidates = {} }
    local runs = { mkRun("six"), mkRun("one", { usage = one }), mkRun("old", { usage = false }),
                   mkRun("none", { usage = { v = 1, used = {}, candidates = {} } }) }
    local order = function(desc)
        local out = {}
        for n, run in ipairs(NS.ResultsTable.Sort(NS.ResultsRuns.Columns(), runs, "used", desc)) do out[n] = run.id end
        return table.concat(out, ",")
    end
    assertEqual(order(true), "six,one,none,old")
    assertEqual(order(false), "none,one,six,old")
end)

-- ── the Usage section ───────────────────────────────────────────────────────────────────────────

test("results usage: the detail lists every candidate and the extras, detected ones ticked, Save off", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.ShowRun("a")
    local x = section(i)
    assertEqual(x.title.__text, "Usage")
    assertEqual(#x.rows, 7)
    local names, ticked = {}, {}
    for n = 1, #x.rows do
        local row = x.items[n]
        assertTrue(row:IsShown(), "row " .. n .. " hidden")
        names[n] = row.check.label.__text
        ticked[n] = x.state[n] and "x" or "-"
    end
    assertEqual(table.concat(names, "|"),
        "Test Trinket|Other Trinket|Potion of Testing|Flask of Testing|Healthstone|Well Fed|Weapon enchant (main hand)")
    assertEqual(table.concat(ticked), "x-xxxxx", "what was detected starts ticked")
    assertEqual(x.items[1].detail.__text, "x2 at 0:09, 1:12")
    assertEqual(x.items[2].detail.__text, "", "an unused candidate has no detail")
    assertEqual(x.items[1].icon.__texture, 5000000 + TRINKET)
    assertFalse(x.save:IsEnabled(), "nothing changed yet")
    assertTrue(x.save:IsShown())
    assertFalse(x.none:IsShown())
    -- The label is clickable: the box's click area reaches over the icon and the words.
    local U = i.NS.ResultsUsage
    local inset = x.items[1].check.__hitInsets
    assertEqual(inset[2], -(1 + 2 + U.ICON + 4 + i.NS.ResultsTable.BadgeWidth("Test Trinket", false)))
end)

test("results usage: Save is live only while the ticks differ, and writes them through SetUsed", function()
    local i = inst()
    local NS = i.NS
    seed(i, { mkRun("a") })
    local changed = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.RUNS_CHANGED, function() changed = changed + 1 end)
    i.R.ShowRun("a")
    local x = section(i)
    x.items[2].check:__fire("OnClick")
    assertTrue(x.save:IsEnabled(), "a new tick")
    x.items[2].check:__fire("OnClick")
    assertFalse(x.save:IsEnabled(), "back as stored")
    x.items[2].check:__fire("OnClick")     -- tick the second trinket
    x.items[3].check:__fire("OnClick")     -- untick the potion
    assertTrue(x.save:IsEnabled())
    x.save:__fire("OnClick")
    local u = NS.Recorder.Get("a").usage
    assertTrue(u.edited, "the record is marked edited")
    assertEqual(changed, 1, "RUNS_CHANGED once")
    assertEqual(#u.used, 6)
    assertEqual(u.used[1].src, "cast", "the trinket kept its source")
    assertEqual(#u.used[1].times, 2, "and its times")
    assertEqual(u.used[2].itemID, TRINKET2)
    assertEqual(u.used[2].src, "manual", "a new tick")
    assertEqual(u.used[2].n, 1)
    for _, e in ipairs(u.used) do assertTrue(e.itemID ~= POTION, "the potion is still listed") end
    -- The window redrew from the bus: the new list ticked, Save off again.
    x = section(i)
    assertTrue(x.state[2] == true and x.state[3] == nil)
    assertFalse(x.save:IsEnabled())
    assertEqual(x.items[2].detail.__text, "time unknown")
end)

test("results usage: an unticked Well Fed or enchant stays listed and can be ticked again", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.ShowRun("a")
    local x = section(i)
    x.items[6].check:__fire("OnClick")     -- untick Well Fed
    x.items[7].check:__fire("OnClick")     -- untick the enchant
    x.save:__fire("OnClick")
    x = section(i)
    assertEqual(#x.rows, 7, "both rows survive the save")
    assertEqual(x.items[6].check.label.__text, "Well Fed")
    assertEqual(x.items[7].check.label.__text, "Weapon enchant (main hand)")
    assertTrue(x.state[6] == nil and x.state[7] == nil, "unticked")
    x.items[6].check:__fire("OnClick")
    x.items[7].check:__fire("OnClick")
    x.save:__fire("OnClick")
    x = section(i)
    assertEqual(#x.rows, 7)
    assertTrue(x.state[6] == true and x.state[7] == true, "ticked again")
    assertEqual(x.items[6].detail.__text, "active at the start")
    assertEqual(x.items[7].detail.__text, "active at the start")
end)

test("results usage: a redraw of the same run keeps the ticks not saved yet, and the scroll", function()
    local i = inst()
    local NS = i.NS
    seed(i, { mkRun("a"), mkRun("b", { date = NOW - 7200 }) })
    i.R.ShowRun("a")
    local d = ui(i).detail
    d.scroll = 40
    local x = section(i)
    x.items[2].check:__fire("OnClick")     -- tick the second trinket, not saved
    NS.SendBus(NS.MSG.RUNS_CHANGED)        -- another run recorded or pruned: the same run redrawn
    x = section(i)
    assertTrue(x.state[2] == true, "the pending tick survives the redraw")
    assertTrue(x.save:IsEnabled(), "and Save stays live")
    assertEqual(d.scroll, 40, "the redraw keeps the scroll")
    x.save:__fire("OnClick")
    x = section(i)
    assertFalse(x.save:IsEnabled(), "the save's own redraw starts from the stored list")
    assertTrue(x.state[2] == true)
    assertEqual(d.scroll, 40, "Save does not jump the pane to the top")
    i.R.ShowRun("b")
    assertEqual(d.scroll, 0, "another run starts at the top")
    assertFalse(section(i).save:IsEnabled(), "and with its own ticks")
end)

test("results usage: a run stored before format 3 says Not recorded, with no rows and no Save", function()
    local i = inst()
    seed(i, { mkRun("old", { schema = 2, usage = false }) })
    i.R.ShowRun("old")
    local x = section(i)
    assertTrue(x.none:IsShown())
    assertEqual(x.none.__text, "Not recorded")
    assertFalse(x.save:IsShown())
    assertNil(x.rows)
    assertEqual(i.NS.ResultsTips.Usage("none", i.NS.Recorder.Get("old"))[1], "Not recorded")
end)

test("results usage: a sample run's edit changes it in memory only; the store never hears it", function()
    local i = inst()
    local NS = i.NS
    local run = mkRun("s1", { sample = true })
    i.R.Show()
    NS.ResultsSource.Use({ runs = { run } })
    local changed = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.RUNS_CHANGED, function() changed = changed + 1 end)
    i.R.ShowRun("s1")
    local x = section(i)
    x.items[2].check:__fire("OnClick")
    x.save:__fire("OnClick")
    assertTrue(run.usage.edited)
    assertEqual(run.usage.used[2].itemID, TRINKET2)
    assertEqual(changed, 0, "no RUNS_CHANGED for a sample run")
    assertNil(next(NS.db.global.runs), "nothing reached the store")
    assertFalse(section(i).save:IsEnabled(), "the source redrew the detail")
    NS.ResultsSource.Restore()
end)

test("results usage: a row's hover is the item's own tooltip with its detail and source after it", function()
    local i = inst()
    local M = i.mocks
    local shown = { lines = {} }
    M.GameTooltip = setmetatable({}, { __index = function(_, k)
        return function(_, a)
            if k == "SetItemByID" then shown.item = a end
            if k == "AddLine" then shown.lines[#shown.lines + 1] = a end
            if k == "SetText" then shown.text = a end
        end
    end })
    seed(i, { mkRun("a") })
    i.R.ShowRun("a")
    local x = section(i)
    x.items[1]:__fire("OnEnter")
    assertEqual(shown.item, TRINKET)
    assertEqual(shown.lines[2], "x2 at 0:09, 1:12")
    assertEqual(shown.lines[3], "Detected from its cast during the race.")
    shown = { lines = {} }
    x.items[6].check:__fire("OnEnter")
    assertNil(shown.item, "food has no item")
    assertEqual(shown.text, "Well Fed")
end)
