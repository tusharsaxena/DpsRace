-- tests/test_results_gear.lua — the gear view (#17, modules/Results_Gear.lua): the pure parts (the link's
-- enchant and gems, the character panel's cells and the window's size from the constants, what differs
-- in a slot, its marks and tooltip notes, the centering over the Results window), and the window opened
-- from the detail's Gear view button: a modal over the Results window (its strata, the cover, Escape
-- closing it first, closing with the window), every slot's item, level and marks, the stats column
-- with its deltas against the compared run, dashes for a run without stats, the item tooltip and its
-- Shift-click, and a redraw when the detail moves.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600
-- A ring with an enchant (7364) and two gems, and the same ring bare.
local RING = "|cnIQ4:|Hitem:212011:7364:213743:213746::::80:267::6:2:10390:1540::::::|h[Band of the Test]|h|r"
local RING_BARE = "|cnIQ4:|Hitem:212011::::::::80:267::6:2:10390:1540::::::|h[Band of the Test]|h|r"
local STAFF = "|cnIQ4:|Hitem:777::::::::80:267::::::::|h[Better Staff]|h|r"

local GEAR_A = {
    [1] = "|cnIQ4:|Hitem:212001::::::::80:267::6:2:10390:1540::::::|h[Hood of the Test]|h|r",
    [5] = "|cnIQ4:|Hitem:212005::::::::80:267::6:2:10390:1540::::::|h[Robe of the Test]|h|r",
    [11] = RING,
    [16] = "|cnIQ3:|Hitem:212016::::::::80:267::6:1:10390::::::|h[Staff of the Test]|h|r",
}

local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
        m.__modClicks = {}
        m.HandleModifiedItemClick = function(link) m.__modClicks[#m.__modClicks + 1] = link end
        -- Item levels by link (639 for anything else, the mock's own).
        m.__ilvls = {}
        local base = m.C_Item.GetDetailedItemLevelInfo
        m.C_Item.GetDetailedItemLevelInfo = function(link) return m.__ilvls[link] or base(link) end
        m.C_Item.GetItemIconByID = function(x) return type(x) == "number" and 5000 + x or 134400 end
    end }
    i.R, i.G = i.NS.Results, i.NS.ResultsGear
    return i
end

local STATS = { v = 1, primaryStat = 4, primary = 12345, stamina = 98765, armor = 4321, critRating = 1234,
                crit = 25.3, hasteRating = 2345, haste = 18.5, masteryRating = 3456, mastery = 41.26,
                versRating = 456, vers = 3.6, leechRating = 120, leech = 1.2, avoidanceRating = 80,
                avoidance = 0.8, speedRating = 60, speed = 2.05 }

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

local function mkRun(NS, id, dps, gear, fields)
    local run = {
        id = id, schema = 4, status = "complete", addon = "0.1.0", date = NOW - HOUR,
        race = { length = 60, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction",
                 level = 80, ilvl = 639.4 },
        target = { npcID = 225983, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 60, dps = dps, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = 29722, dmg = dps * 50 } }, note = "",
        loadout = gear and NS.Loadouts.Store({ gear = gear }) or nil,
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    NS.db.global.runs[id] = run
    return run
end

-- "this" (100) under "best" (300) on one board, the view opened on "this" from the detail's button.
local function opened(thisGear, bestGear, thisStats, bestStats)
    local i = inst()
    local NS = i.NS
    mkRun(NS, "this", 100, thisGear or GEAR_A, { stats = thisStats })
    mkRun(NS, "best", 300, bestGear or GEAR_A, { date = NOW - 2 * HOUR, stats = bestStats })
    NS.Bests.Invalidate()
    i.R.ShowRun("this")
    local lo = i.R.__ui().detail.lo
    assertTrue(lo.gearView:IsShown(), "the Gear view button shows for a run with gear")
    lo.gearView:__fire("OnClick")
    assertTrue(i.G.IsShown(), "the gear view opened")
    return i, i.G.__ui()
end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────────

test("gear view: ParseLink reads the item, its enchant and its gems from the stored link", function()
    local G = T.NS.ResultsGear
    local p = G.ParseLink(RING)
    assertEqual(p.itemID, 212011)
    assertEqual(p.enchantID, 7364)
    assertEqual(#p.gems, 2)
    assertEqual(p.gems[1], 213743)
    assertEqual(p.gems[2], 213746)
    p = G.ParseLink(RING_BARE)
    assertNil(p.enchantID, "no enchant")
    assertEqual(#p.gems, 0, "no gems")
    assertNil(G.ParseLink(nil))
    assertNil(G.ParseLink("|Htalentbuild:267:80:ABC|h[x]|h"), "not an item link")
end)

test("gear view: the cells follow the character panel, from the constants, the optional slots only when filled", function()
    local G = T.NS.ResultsGear
    local cells = G.Cells({})
    assertEqual(#cells, 6 + 8 + 2, "six on the left without a shirt or tabard, eight on the right, the weapons")
    local by = {}
    for _, c in ipairs(cells) do by[c.slot] = c end
    assertNil(by[4], "no shirt without one")
    assertNil(by[19], "no tabard without one")
    assertNil(by[18], "no ranged slot without one")
    assertEqual(by[1].side, "left")
    assertEqual(by[1].x, G.PAD)
    assertEqual(by[1].y, 0)
    assertEqual(by[9].y, -5 * G.PITCH, "the wrists end the left column")
    assertEqual(by[10].side, "right")
    assertEqual(by[14].y, -7 * G.PITCH, "the trinkets end the right column")
    local width, height, rows = G.Size({})
    assertEqual(rows, 8)
    assertEqual(width, 2 * G.PAD + 2 * G.SLOT_W + G.MID_W + 2 * G.COL_GAP)
    assertEqual(by[10].x, width - G.PAD - G.SLOT_W)
    assertEqual(by[16].y, -(8 * G.PITCH + G.WEAPON_GAP), "the weapons under the columns")
    assertEqual(by[16].side, "right", "the main hand faces the off hand")
    assertEqual(by[16].x + G.SLOT_W, width / 2 - G.COL_GAP / 2)
    assertEqual(by[17].x, width / 2 + G.COL_GAP / 2)
    assertEqual(height, 30 + G.LEGEND_H + G.PAD + 8 * G.PITCH + G.WEAPON_GAP + G.PITCH + G.PAD)
    -- A shirt and a tabard sit above the wrists, as the character panel's do; a ranged item adds a row.
    local withBoth = {}
    for _, c in ipairs(G.Cells({ [4] = "x", [19] = "y" })) do withBoth[c.slot] = c end
    assertEqual(withBoth[4].y, -5 * G.PITCH)
    assertEqual(withBoth[9].y, -7 * G.PITCH)
    assertEqual(select(2, G.Size({ [4] = "x", [19] = "y" })), height, "the right column is as tall")
    local _, h2, rows2 = G.Size({ [18] = "z" })
    assertEqual(rows2, 9)
    assertEqual(h2, height + G.PITCH)
end)

test("gear view: SlotDiff tells an item change, the item level, the enchant and the gems apart", function()
    local G = T.NS.ResultsGear
    local d = G.SlotDiff({ link = RING, ilvl = 645 }, { link = RING_BARE, ilvl = 639 })
    assertFalse(d.item, "the same item")
    assertTrue(d.enchant)
    assertTrue(d.gems)
    assertEqual(d.ilvl, 1)
    d = G.SlotDiff({ link = RING, ilvl = 639 }, { link = RING, ilvl = 639 })
    assertFalse(d.item or d.enchant or d.gems)
    assertEqual(d.ilvl, 0)
    d = G.SlotDiff({ link = STAFF, ilvl = 630 }, { link = RING, ilvl = 639 })
    assertTrue(d.item)
    assertNil(d.enchant, "another item: its enchant is not compared")
    assertEqual(d.ilvl, -1)
    d = G.SlotDiff({ link = nil }, { link = RING })
    assertTrue(d.item, "one side empty is a change")
    assertNil(G.SlotDiff({ link = RING }, nil), "nothing without a compared run")
end)

test("gear view: a slot's marks, a missing enchant or gem the compared run had, and its notes", function()
    local G = T.NS.ResultsGear
    local marks = G.Marks(G.ParseLink(RING))
    assertEqual(#marks, 3, "the enchant and two gems")
    assertEqual(marks[1].kind, "enchant")
    assertEqual(marks[2].kind, "gem")
    assertFalse(marks[1].changed)
    marks = G.Marks(G.ParseLink(RING_BARE), { enchant = true, gems = true })
    assertEqual(#marks, 2)
    assertTrue(marks[1].missing and marks[1].changed, "the missing enchant")
    assertTrue(marks[2].missing and marks[2].kind == "gem", "the missing gems")
    assertEqual(#G.Marks(nil), 0)
    local notes = G.NoteLines({ item = true, ilvl = -1 }, "Best", "Band of the Test")
    assertEqual(notes[1], "Changed: Best wore Band of the Test.")
    assertEqual(notes[2], "Lower item level than Best's.")
    notes = G.NoteLines({ item = false, enchant = true, gems = true, ilvl = 0 }, "Best")
    assertEqual(notes[1], "The enchant differs from Best's.")
    assertEqual(notes[2], "The gems differ from Best's.")
    assertEqual(G.NoteLines({ item = true, ilvl = 0 }, "Best")[1], "Changed: Best had nothing here.")
    assertEqual(#G.NoteLines(nil, "Best"), 0)
end)

test("gear view: CenterOver centers the view over the Results window from its anchor", function()
    local G = T.NS.ResultsGear
    local x, y = G.CenterOver("CENTER", 10, 20, 900, 560, 700, 480)
    assertEqual(x, 10)
    assertEqual(y, 20)
    x, y = G.CenterOver("TOPLEFT", 100, -50, 900, 560, 700, 480)
    assertEqual(x, 100 + 100, "half the width difference in")
    assertEqual(y, -50 - 40, "half the height difference down")
    x, y = G.CenterOver("BOTTOMRIGHT", -20, 30, 900, 560, 700, 480)
    assertEqual(x, -20 - 100)
    assertEqual(y, 30 + 40)
end)

-- ── the window ──────────────────────────────────────────────────────────────────────────────────

test("gear view: a modal over the Results window: its strata, the cover, the opaque skin", function()
    local i, u = opened()
    assertEqual(u.frame.__strata, i.NS.Constants.LAYERS.STRATA.MODAL)
    assertTrue(i.R.IsCovered(), "the Results window wears its dim cover")
    assertEqual(i.G.SKIN, i.NS.ResultsTimeline.SKIN, "the timeline's opaque skin")
    local w, h = i.G.Size(i.NS.Loadouts.Of(i.NS.Recorder.Get("this")))
    assertEqual(u.frame.__width, w)
    assertEqual(u.frame.__height, h)
    u.close:__fire("OnClick")
    assertFalse(i.G.IsShown())
    assertFalse(i.R.IsCovered(), "the cover went with it")
end)

test("gear view: Escape closes the view first and the Results window stays", function()
    local i, u = opened()
    local results = i.R.__ui().frame
    for _, f in ipairs({ results, u.frame }) do
        if f:IsShown() then
            f:Hide()
            f:__fire("OnHide")
        end
    end
    i.mocks.__fireTimers()
    assertFalse(i.G.IsShown(), "the view closed")
    assertTrue(results:IsShown(), "the Results window came back")
    assertFalse(i.R.IsCovered(), "the cover went")
end)

test("gear view: it closes with the Results window", function()
    local i = opened()
    i.R.Hide()
    assertFalse(i.G.IsShown())
end)

test("gear view: each slot's item, item level and marks; Shift-click and the tooltip go to the client", function()
    local i = opened()
    local cells = i.G.SlotCells()
    local hood, ring, neck = cells[1], cells[11], cells[2]
    assertEqual(hood.name.__text, "Hood of the Test")
    assertEqual(hood.ilvl.__text, "639")
    assertEqual(hood.side, "left")
    assertEqual(neck.name.__text, "Empty")
    assertEqual(ring.side, "right")
    assertEqual(ring.name.__justifyH, "RIGHT", "the right column reads toward the middle")
    assertTrue(ring.marks[1].icon:IsShown())
    assertEqual(ring.marks[1].icon.__texture, i.G.MARK_ENCHANT)
    assertEqual(ring.marks[2].icon.__texture, 5000 + 213743, "a gem's own icon")
    assertTrue(ring.marks[3].icon:IsShown())
    assertFalse(ring.marks[4].icon:IsShown())
    assertFalse(hood.marks[1].icon:IsShown(), "no marks on a bare item")
    assertTrue(cells[16] ~= nil and cells[17] ~= nil, "both weapon slots")
    assertNil(cells[4], "no shirt row")
    local shown = {}
    i.mocks.GameTooltip = setmetatable({}, { __index = function(_, k)
        return function(_, a)
            if k == "SetOwner" then shown.owner = a end
            if k == "SetHyperlink" then shown.link = a end
        end
    end })
    ring:__fire("OnEnter")
    assertEqual(shown.owner, ring)
    assertEqual(shown.link, RING)
    ring:__fire("OnClick")
    assertEqual(i.mocks.__modClicks[1], RING, "Shift-click never reached the client's handler")
end)

test("gear view: against the compared run, changed items tinted, item levels colored, enchant and gems edged", function()
    local best = copy(GEAR_A)
    best[11] = RING_BARE
    best[1] = "|cnIQ4:|Hitem:999001::::::::80:267::::::::|h[Old Hood]|h|r"
    local i = inst()
    i.mocks.__ilvls[GEAR_A[1]] = 645
    i.mocks.__ilvls[best[1]] = 630
    local NS = i.NS
    mkRun(NS, "this", 100, GEAR_A)
    mkRun(NS, "best", 300, best, { date = NOW - 2 * HOUR })
    NS.Bests.Invalidate()
    i.R.ShowRun("this")
    i.R.__ui().detail.lo.gearView:__fire("OnClick")
    local u, C = i.G.__ui(), NS.ResultsTable.COLORS
    assertTrue(u.legendB.__text:find("Best", 1, true) ~= nil, "the legend names the compared run")
    local cells = i.G.SlotCells()
    assertTrue(cells[1].tint:IsShown(), "another item is tinted")
    assertEqual(cells[1].ilvl.__color[1], C.green[1], "a higher item level reads green")
    assertFalse(cells[11].tint:IsShown(), "the same ring is not tinted")
    assertEqual(cells[11].marks[1].edge.__colorTex[1], C.amber[1], "the enchant that differs is edged")
    assertEqual(cells[11].notes[1], "The enchant differs from Best run's.")
    assertFalse(cells[5].tint:IsShown(), "an unchanged slot")
    assertFalse(cells[5].marks[1].edge:IsShown())
end)

test("gear view: the stats column with deltas against the compared run, dashes for a run with none", function()
    local worse = copy(STATS)
    worse.critRating, worse.crit, worse.primary = 1094, 24.13, 12500
    local i, u = opened(nil, nil, STATS, worse)
    local C = i.NS.ResultsTable.COLORS
    local rows = {}
    for _, r in ipairs(u.statRows) do rows[r.key] = r end
    assertEqual(u.groups[1].__text, "Primary")
    assertEqual(u.groups[2].__text, "Secondary")
    assertEqual(u.groups[3].__text, "Tertiary")
    assertEqual(rows.primary.label.__text, "Intellect")
    assertEqual(rows.primary.value.__text, "12,345")
    assertEqual(rows.primary.delta.__text, "-155")
    assertEqual(rows.primary.delta.__color[1], C.red[1], "a loss reads red")
    assertEqual(rows.crit.value.__text, "1,234 \194\183 25.30%")
    assertEqual(rows.crit.delta.__text, "+140 \194\183 +1.17%")
    assertEqual(rows.crit.delta.__color[1], C.green[1], "a gain reads green")
    assertFalse(u.statsNote:IsShown())
    -- The detail moves to the best (no compared run of its own beyond the runner-up): the view redraws.
    i.NS.db.global.runs.this.stats = nil
    i.R.ShowRun("this")
    assertEqual(rows.crit.value.__text, "\226\128\148", "a run without stats shows dashes")
    assertEqual(rows.crit.delta.__text, "")
    assertTrue(u.statsNote:IsShown(), "and says so")
end)

test("gear view: a run without a compared run marks nothing and says so", function()
    local i = inst()
    local NS = i.NS
    mkRun(NS, "solo", 100, GEAR_A, { stats = STATS })
    NS.Bests.Invalidate()
    i.R.ShowRun("solo")
    i.R.__ui().detail.lo.gearView:__fire("OnClick")
    local u = i.G.__ui()
    assertEqual(u.legendB.__text, "No run to compare with")
    for _, cell in pairs(i.G.SlotCells()) do assertFalse(cell.tint:IsShown(), "a tint with no compare") end
    for _, r in ipairs(u.statRows) do assertEqual(r.delta.__text, "", r.key) end
end)
