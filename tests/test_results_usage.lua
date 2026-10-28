-- tests/test_results_usage.lua — what a run used (#13) in the Results window (modules/Results_Usage.lua):
-- the pure helpers (the entries' order, each entry's detail, the section's rows, the ticks and whether
-- they changed, the icons that fit a cell), the Runs list's Used column (its icons, "+n", the dash,
-- its tooltip with each item's icon, and its sort) and the run detail's Usage section (what was used,
-- then Edit: every candidate pre-ticked as used, the clickable labels, Save live only on a change and
-- writing Usage.SetUsed, Edit again leaving unsaved, Not recorded for an older run, a sample run
-- changed in memory only); the hidden items (P9: a right-click's Never show, never listed anywhere,
-- kept in the record) and an old run's enchant entry, never shown.

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
-- flask's buff and Well Fed on at the arm, and an oil's enchant on the main hand (an entry only a run
-- stored before 2026-10-26 carries: never shown). The second trinket and the Healthstone are
-- candidates too; the second trinket was not used.
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
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
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

-- The section's rows' names, joined.
local function names(x)
    local out = {}
    for n = 1, #x.rows do out[n] = x.items[n].name end
    return table.concat(out, "|")
end

-- The Usage section of run `id`, in its edit.
local function editing(i, id)
    i.R.ShowRun(id)
    local x = section(i)
    x.edit:__fire("OnClick")
    assertTrue(x.editing, "Edit did not open the edit")
    return x
end

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

test("results usage: entries list the gear first, never an old enchant; a run stored before format 3 has none", function()
    local NS = inst().NS
    local U = NS.ResultsUsage
    local u = usage()
    -- The gear stored last still leads.
    table.insert(u.used, table.remove(u.used, 1))
    local entries = U.Entries({ usage = u })
    assertEqual(#entries, 5, "the enchant entry is left out")
    assertEqual(entries[1].itemID, TRINKET, "the gear first")
    assertEqual(entries[2].itemID, POTION, "then everything else in its stored order")
    assertEqual(entries[5].kind, "food")
    assertEqual(U.Count({ usage = u }), 5)
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
    assertEqual(U.Detail({ itemID = TRINKET2, kind = "gear", n = 1, src = "manual" }), "time unknown")
    assertEqual(U.Clock(125), "2:05")
    assertEqual(U.Clock(-0.3), "0:00", "a use that rounds to the pull has no minus sign")
    assertEqual(U.Clock(-0.6), "-0:01")
end)

test("results usage: names and icons come from the item data; food has its own", function()
    local U = inst().NS.ResultsUsage
    local used = usage().used
    assertEqual(U.Name(used[1]), "Test Trinket")
    assertEqual(U.Icon(used[1]), 5000000 + TRINKET)
    assertEqual(U.InlineIcon(used[1]), "|T" .. (5000000 + TRINKET) .. ":14:14|t", "a tooltip line's icon")
    assertEqual(U.Name(used[5]), "Well Fed")
    assertEqual(U.Icon(used[5]), U.FOOD_ICON)
    assertEqual(U.Name({ itemID = 4242, kind = "other" }), "Item 4242", "an item the client has not cached")
end)

test("results usage: one row per candidate, then each detected entry no candidate stands for", function()
    local U = inst().NS.ResultsUsage
    local rows = U.Rows({ usage = usage() })
    assertEqual(#rows, 6, "five candidates, then Well Fed; never the enchant")
    local ids = {}
    for n, row in ipairs(rows) do ids[n] = tostring(row.itemID or row.kind) end
    assertEqual(table.concat(ids, ","), table.concat({ TRINKET, TRINKET2, POTION, FLASK, STONE, "food" }, ","))
    assertTrue(rows[1].entry ~= nil and rows[1].entry.n == 2, "the trinket stands for its detected entry")
    assertNil(rows[2].entry, "the second trinket was not used")
    assertNil(U.Rows({}), "not recorded")
    -- Outside the edit: what was used, gear first.
    local used = U.UsedRows({ usage = usage() })
    ids = {}
    for n, row in ipairs(used) do ids[n] = tostring(row.itemID or row.kind) end
    assertEqual(table.concat(ids, ","), table.concat({ TRINKET, POTION, STONE, FLASK, "food" }, ","))
    assertTrue(used[1].entry ~= nil)
    assertNil(U.UsedRows({}))
end)

test("results usage: the ticks follow the rows, and a change is any row ticked against what was stored", function()
    local U = inst().NS.ResultsUsage
    local rows = U.Rows({ usage = usage() })
    local state = { true, nil, true, true, true, true }
    assertFalse(U.Changed(rows, state), "the detected ticks are what is stored")
    state[2] = true
    assertTrue(U.Changed(rows, state), "a new tick")
    state[2], state[3] = nil, nil
    assertTrue(U.Changed(rows, state), "an untick")
    local ticks = U.Ticks(rows, state)
    assertEqual(#ticks, 4)
    assertEqual(ticks[1].itemID, TRINKET)
    assertEqual(ticks[1].slot, 13)
    assertEqual(ticks[2].itemID, FLASK, "the potion untick leaves it out")
    assertEqual(ticks[4].kind, "food")
    -- A redraw carries the ticks by each row, a row new since taking what it holds.
    local carried = U.Carry({ rows[1], rows[3], rows[2] }, rows, { true, true, nil })
    assertTrue(carried[1] == true and carried[2] == nil and carried[3] == true)
    carried = U.Carry({ rows[2], rows[4] }, { rows[2] }, {})
    assertTrue(carried[1] == nil and carried[2] == true, "the flask, new since, was used")
end)

test("results usage: a save keeps the used entries the edit does not list, a hidden item's", function()
    local NS = inst().NS
    local U = NS.ResultsUsage
    local run = { usage = usage() }
    NS.Usage.Hide(POTION)
    local rows = U.Rows(run)
    assertEqual(#rows, 5, "the potion is not listed")
    local list = U.Edits(run, rows, { true })
    assertEqual(#list, 2, "the trinket ticked, then the hidden potion; never the enchant")
    assertEqual(list[1].itemID, TRINKET)
    assertEqual(list[2].itemID, POTION)
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
    assertEqual(cell.more.__text, "+2", "five entries: the enchant is never shown")
    assertFalse(cell.dash:IsShown())
    for _, id in ipairs({ "b", "old" }) do
        local c = rowOf(pane, id).cells.used
        assertTrue(c.dash:IsShown(), id .. ": no dash")
        assertFalse(c.icon1:IsShown(), id .. ": an icon with nothing used")
        assertFalse(c.more:IsShown())
    end
end)

test("results usage: the Used tooltip names each entry with its icon and when, or says why there is none", function()
    local i = inst()
    -- Six entries shown and the enchant left out: the header, six lines and the hint.
    local seven = usage()
    seven.used[#seven.used + 1] = { itemID = TRINKET2, kind = "gear", slot = 14, n = 1, src = "manual" }
    seed(i, { mkRun("a", { usage = seven }), mkRun("old", { date = NOW - 9000, schema = 2, usage = false }),
              mkRun("b", { date = NOW - 7200, usage = { v = 1, used = {}, candidates = {} } }) })
    i.R.Show()
    local pane = runsPane(i)
    local n = colIndex(pane, "used")
    local lines = pane.list:TipLines(i.NS.Recorder.Get("a"), n)
    local function icon(id) return "|T" .. (5000000 + id) .. ":14:14|t " end
    assertEqual(lines[1], "6 items used")
    assertEqual(lines[2], icon(TRINKET) .. "Test Trinket: x2 at 0:09, 1:12")
    assertEqual(lines[3], icon(TRINKET2) .. "Other Trinket: time unknown", "the gear first")
    assertEqual(lines[4], icon(POTION) .. "Potion of Testing: at -0:02")
    assertEqual(lines[5], icon(STONE) .. "Healthstone: time unknown")
    assertEqual(lines[6], icon(FLASK) .. "Flask of Testing: active at the start")
    assertEqual(lines[7], "|T" .. i.NS.ResultsUsage.FOOD_ICON .. ":14:14|t Well Fed: active at the start")
    assertEqual(#lines, 8, "every entry is listed, then the hint")
    assertEqual(type(lines[8]), "table", "the hint comes last")
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

test("results usage: a row's line is the name, then a dim dot and the detail; the name alone with none", function()
    local i = inst()
    local U, Tbl = i.NS.ResultsUsage, i.NS.ResultsTable
    local dim = Tbl.Hex(Tbl.COLORS.dim)
    local line, plain = U.Line("Test Trinket", "at 0:01")
    assertEqual(line, "Test Trinket|c" .. dim .. " \194\183 at 0:01|r", "the dot and the detail in the dim color")
    assertEqual(plain, "Test Trinket \194\183 at 0:01")
    line, plain = U.Line("Other Trinket", "")
    assertEqual(line, "Other Trinket", "no dot without a detail")
    assertEqual(plain, "Other Trinket")
    assertEqual(U.Line("Well Fed", nil), "Well Fed")
    assertEqual(U.LineWidth(300, 20), 280, "to the row's right edge")
    assertEqual(U.LineWidth(30, 20), 20, "never narrower than 20 px")
end)

test("results usage: the detail follows the name on its line, cut at the row's edge, in and out of the edit", function()
    local i = inst()
    local U, Tbl = i.NS.ResultsUsage, i.NS.ResultsTable
    local dim = Tbl.Hex(Tbl.COLORS.dim)
    seed(i, { mkRun("a") })
    i.R.ShowRun("a")
    local x = section(i)
    local row = x.items[1]
    assertEqual(row.check.label.__text, "Test Trinket|c" .. dim .. " \194\183 x2 at 0:09, 1:12|r")
    assertEqual(x.items[5].check.label.__text, "Well Fed|c" .. dim .. " \194\183 active at the start|r")
    assertNil(row.detail, "no detail column")
    local cw = row.__width
    assertTrue(type(cw) == "number" and cw > 0, "the row was laid out")
    assertEqual(row.check.label.__width, cw - (U.ICON + 4), "the line runs to the row's right edge")
    -- The edit: the same line after the box and the icon, its click area never past the row.
    x.edit:__fire("OnClick")
    row = x.items[1]
    assertEqual(row.check.label.__text, "Test Trinket|c" .. dim .. " \194\183 x2 at 0:09, 1:12|r")
    assertEqual(x.items[2].check.label.__text, "Other Trinket", "an unused candidate: the name alone")
    local lineW = row.check.label.__width
    assertEqual(lineW, row.__width - (U.CHECK + 2 + U.ICON + 4))
    -- A narrow pane: the line is cut at the row's edge, and so is its click area.
    local p = ui(i).detail
    U.Layout(p, 0, 120)
    lineW = row.check.label.__width
    assertEqual(lineW, 120 - (U.CHECK + 2 + U.ICON + 4))
    assertTrue(Tbl.BadgeWidth("Test Trinket \194\183 x2 at 0:09, 1:12", false) > lineW, "the line is longer")
    assertEqual(row.check.__hitInsets[2], -(1 + 2 + U.ICON + 4 + lineW), "the click area stops at the edge")
end)

test("results usage: the detail shows what was used, each with its icon and when, Edit and no Save", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.ShowRun("a")
    local x = section(i)
    assertEqual(x.title.__text, "Usage")
    assertFalse(x.editing)
    assertEqual(#x.rows, 5)
    assertEqual(names(x), "Test Trinket|Potion of Testing|Healthstone|Flask of Testing|Well Fed",
        "the gear first; never the enchant")
    for n = 1, #x.rows do
        assertTrue(x.items[n]:IsShown(), "row " .. n .. " hidden")
        assertFalse(x.items[n].check:IsShown(), "row " .. n .. " has a box outside the edit")
    end
    assertEqual(x.items[1].detailText, "x2 at 0:09, 1:12")
    assertEqual(x.items[1].icon.__texture, 5000000 + TRINKET)
    assertTrue(x.edit:IsShown() and x.edit:IsEnabled(), "Edit")
    assertFalse(x.save:IsShown(), "Save is the edit's")
    assertFalse(x.none:IsShown())
end)

test("results usage: a run with nothing used says so in a dim line, and Edit still opens the list", function()
    local i = inst()
    local u = usage()
    u.used = {}
    seed(i, { mkRun("a", { usage = u }) })
    i.R.ShowRun("a")
    local x = section(i)
    assertTrue(x.none:IsShown())
    assertEqual(x.none.__text, "Nothing used")
    assertEqual(x.none.__color[1], i.NS.ResultsTable.COLORS.dim[1], "dim")
    assertEqual(i.NS.ResultsTips.Usage("unused", i.NS.Recorder.Get("a"))[1], "Nothing used")
    x.edit:__fire("OnClick")
    assertEqual(#x.rows, 5, "every candidate")
    assertFalse(x.none:IsShown())
end)

test("results usage: Edit lists every candidate and the extras, used ones ticked; Edit again leaves unsaved", function()
    local i = inst()
    seed(i, { mkRun("a") })
    local x = editing(i, "a")
    assertEqual(#x.rows, 6)
    assertEqual(names(x), "Test Trinket|Other Trinket|Potion of Testing|Flask of Testing|Healthstone|Well Fed")
    local ticked = {}
    for n = 1, #x.rows do
        assertTrue(x.items[n].check:IsShown(), "row " .. n .. " has no box")
        ticked[n] = x.state[n] and "x" or "-"
    end
    assertEqual(table.concat(ticked), "x-xxxx", "what was used starts ticked")
    assertEqual(x.items[2].detailText, "", "an unused candidate has no detail")
    assertTrue(x.save:IsShown(), "Save beside Edit")
    assertFalse(x.save:IsEnabled(), "nothing changed yet")
    assertTrue(x.edit.selected, "Edit reads as on")
    -- The label is clickable: the box's click area reaches over the icon and the words.
    local U = i.NS.ResultsUsage
    local inset = x.items[1].check.__hitInsets
    assertEqual(inset[2], -(1 + 2 + U.ICON + 4 + i.NS.ResultsTable.BadgeWidth("Test Trinket \194\183 x2 at 0:09, 1:12",
        false)), "over the name and its detail")
    x.items[2].check:__fire("OnClick")
    assertTrue(x.save:IsEnabled(), "a new tick")
    x.edit:__fire("OnClick")
    assertFalse(x.editing, "Edit again leaves the edit")
    assertEqual(#x.rows, 5, "what was used, as stored")
    assertFalse(x.save:IsShown())
    assertFalse(i.NS.Recorder.Get("a").usage.edited, "nothing was saved")
    x.edit:__fire("OnClick")
    assertTrue(x.state[2] == nil, "a new edit starts from the stored list")
end)

test("results usage: Save is live only while the ticks differ, writes them through SetUsed and leaves the edit", function()
    local i = inst()
    local NS = i.NS
    seed(i, { mkRun("a") })
    local changed = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.RUNS_CHANGED, function() changed = changed + 1 end)
    local x = editing(i, "a")
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
    assertEqual(#u.used, 5, "the old enchant entry is gone with the save")
    assertEqual(u.used[1].src, "cast", "the trinket kept its source")
    assertEqual(#u.used[1].times, 2, "and its times")
    assertEqual(u.used[2].itemID, TRINKET2)
    assertEqual(u.used[2].src, "manual", "a new tick")
    assertEqual(u.used[2].n, 1)
    for _, e in ipairs(u.used) do assertTrue(e.itemID ~= POTION, "the potion is still listed") end
    -- The window redrew from the bus, out of the edit: the new list.
    x = section(i)
    assertFalse(x.editing, "Save leaves the edit")
    assertFalse(x.save:IsShown())
    assertEqual(names(x), "Test Trinket|Other Trinket|Flask of Testing|Healthstone|Well Fed", "in the edit's order")
    assertEqual(x.items[2].detailText, "time unknown")
end)

test("results usage: an unticked Well Fed stays listed in the edit and can be ticked again", function()
    local i = inst()
    seed(i, { mkRun("a") })
    local x = editing(i, "a")
    x.items[6].check:__fire("OnClick")     -- untick Well Fed
    x.save:__fire("OnClick")
    x = section(i)
    assertEqual(names(x), "Test Trinket|Potion of Testing|Flask of Testing|Healthstone", "not used any more")
    x = editing(i, "a")
    assertEqual(#x.rows, 6, "its row survives the save")
    assertEqual(x.items[6].check.label.__text, "Well Fed")
    assertTrue(x.state[6] == nil, "unticked")
    x.items[6].check:__fire("OnClick")
    x.save:__fire("OnClick")
    x = editing(i, "a")
    assertEqual(#x.rows, 6)
    assertTrue(x.state[6] == true, "ticked again")
    assertEqual(x.items[6].detailText, "active at the start")
end)

test("results usage: a redraw of the same run keeps the edit and its ticks not saved yet, and the scroll", function()
    local i = inst()
    local NS = i.NS
    seed(i, { mkRun("a"), mkRun("b", { date = NOW - 7200 }) })
    local x = editing(i, "a")
    local d = ui(i).detail
    d.scroll = 40
    x.items[2].check:__fire("OnClick")     -- tick the second trinket, not saved
    NS.SendBus(NS.MSG.RUNS_CHANGED)        -- another run recorded or pruned: the same run redrawn
    x = section(i)
    assertTrue(x.editing, "still editing")
    assertTrue(x.state[2] == true, "the pending tick survives the redraw")
    assertTrue(x.save:IsEnabled(), "and Save stays live")
    assertEqual(d.scroll, 40, "the redraw keeps the scroll")
    x.save:__fire("OnClick")
    x = section(i)
    assertFalse(x.editing, "the save's own redraw leaves the edit")
    assertEqual(d.scroll, 40, "Save does not jump the pane to the top")
    x.edit:__fire("OnClick")
    x.items[3].check:__fire("OnClick")
    i.R.ShowRun("b")
    assertEqual(d.scroll, 0, "another run starts at the top")
    assertFalse(section(i).editing, "and out of the edit, unsaved")
    assertEqual(#NS.Recorder.Get("a").usage.used, 6, "the potion untick was never saved")
end)

test("results usage: a run stored before format 3 says Not recorded, with no rows, no Edit and no Save", function()
    local i = inst()
    seed(i, { mkRun("old", { schema = 2, usage = false }) })
    i.R.ShowRun("old")
    local x = section(i)
    assertTrue(x.none:IsShown())
    assertEqual(x.none.__text, "Not recorded")
    assertFalse(x.save:IsShown())
    assertFalse(x.edit:IsShown())
    assertFalse(i.NS.ResultsUsage.ToggleEdit(ui(i).detail), "nothing to edit")
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
    local x = editing(i, "s1")
    x.items[2].check:__fire("OnClick")
    x.save:__fire("OnClick")
    assertTrue(run.usage.edited)
    assertEqual(run.usage.used[2].itemID, TRINKET2)
    assertEqual(changed, 0, "no RUNS_CHANGED for a sample run")
    assertNil(next(NS.db.global.runs), "nothing reached the store")
    assertFalse(section(i).editing, "the source redrew the detail, out of the edit")
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
    -- Two lines of its own after the client's: each on a bullet (modules/Style.lua).
    assertEqual(shown.lines[2], "\226\128\162 x2 at 0:09, 1:12")
    assertEqual(shown.lines[3], "\226\128\162 Detected from its cast during the race.")
    assertNil(shown.lines[4], "no right-click hint outside the edit")
    shown = { lines = {} }
    x.items[5]:__fire("OnEnter")
    assertNil(shown.item, "food has no item")
    assertEqual(shown.text, "Well Fed")
    -- In the edit, an item's row says how to hide it.
    x.edit:__fire("OnClick")
    shown = { lines = {} }
    x.items[1].check:__fire("OnEnter")
    assertEqual(shown.lines[4], "\226\128\162 Right-click: never show this item.")
end)

-- ── the hidden items ────────────────────────────────────────────────────────────────────────────

test("results usage: a right-click in the edit offers Never show; the item leaves the edit, its ticks kept", function()
    local i = inst()
    local NS, M = i.NS, i.mocks
    seed(i, { mkRun("a") })
    i.R.ShowRun("a")
    local x = section(i)
    M.__menus = {}
    x.items[2]:__fire("OnMouseUp", "RightButton")
    assertEqual(#M.__menus, 0, "no menu outside the edit")
    x.edit:__fire("OnClick")
    x.items[2].check:__fire("OnClick")     -- tick the second trinket, not saved
    x.items[6]:__fire("OnMouseUp", "RightButton")
    assertEqual(#M.__menus, 0, "Well Fed has no item to hide")
    x.items[3].check:__fire("OnMouseUp", "LeftButton")
    assertEqual(#M.__menus, 0, "a left click opens nothing")
    x.items[3].check:__fire("OnMouseUp", "RightButton")
    local menu = M.__menus[1]
    assertTrue(menu ~= nil and menu.owner == x.items[3], "the menu on the potion's row")
    assertEqual(#menu.entries, 1)
    assertEqual(menu.entries[1].text, "Never show Potion of Testing")
    menu:Click("Never show")
    assertEqual(NS.db.global.usage.hidden, tostring(POTION))
    x = section(i)
    assertTrue(x.editing, "the redraw stays in the edit")
    assertEqual(names(x), "Test Trinket|Other Trinket|Flask of Testing|Healthstone|Well Fed")
    assertTrue(x.state[2] == true, "the pending tick survives, by its row")
    x.save:__fire("OnClick")
    local u = NS.Recorder.Get("a").usage
    local kept = false
    for _, e in ipairs(u.used) do kept = kept or (e.itemID == POTION and e.src == "cast") end
    assertTrue(kept, "the hidden potion stays in the record, with its time")
end)

test("results usage: a hidden item is never listed, in the section, the Used column or its tooltip; un-hidden it is back", function()
    local i = inst()
    local NS = i.NS
    seed(i, { mkRun("a") })
    NS.Usage.Hide(TRINKET)
    i.R.Show()
    local pane = runsPane(i)
    local cell = rowOf(pane, "a").cells.used
    assertEqual(cell.icon1.__texture, 5000000 + POTION, "the trinket's icon is gone")
    assertTrue(cell.icon4:IsShown() and not cell.more:IsShown(), "four icons fit")
    local lines = pane.list:TipLines(NS.Recorder.Get("a"), colIndex(pane, "used"))
    assertEqual(lines[1], "4 items used")
    for _, line in ipairs(lines) do
        assertTrue(type(line) ~= "string" or not line:find("Test Trinket", 1, true), "the trinket in the tooltip")
    end
    assertEqual(NS.ResultsUsage.Count(NS.Recorder.Get("a")), 4, "the sort counts what is shown")
    i.R.ShowRun("a")
    local x = section(i)
    assertEqual(names(x), "Potion of Testing|Healthstone|Flask of Testing|Well Fed")
    x.edit:__fire("OnClick")
    assertEqual(names(x), "Other Trinket|Potion of Testing|Flask of Testing|Healthstone|Well Fed",
        "nor in the edit")
    x.edit:__fire("OnClick")
    NS.Usage.Unhide(TRINKET)
    x = section(i)
    assertEqual(names(x), "Test Trinket|Potion of Testing|Healthstone|Flask of Testing|Well Fed",
        "back on the run, with its times")
    assertEqual(x.items[1].detailText, "x2 at 0:09, 1:12")
end)

test("results usage: a sample run hides the same items", function()
    local i = inst()
    local NS = i.NS
    NS.Usage.Hide(STONE)
    i.R.Show()
    NS.ResultsSource.Use({ runs = { mkRun("s1", { sample = true }) } })
    i.R.ShowRun("s1")
    assertEqual(names(section(i)), "Test Trinket|Potion of Testing|Flask of Testing|Well Fed")
    NS.ResultsSource.Restore()
end)
