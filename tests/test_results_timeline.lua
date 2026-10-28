-- tests/test_results_timeline.lua — the ability timeline (#14, modules/Results_Timeline.lua): the pure
-- rows (one per ability and caster across both runs, each run's times and counts, the order: cooldowns
-- of 29 s or more first, longest first, then by count), the axis and a cast tick's x; the detail's Timeline
-- button (disabled for a run with no casts); the window's lanes (this run's gold ticks on top, the
-- compared run's blue below, the counts just past the lanes, the pet suffix, the cooldown under the name),
-- the Casts strips above them (every cast's icon on the lanes' axis, stacked onto as many rows as
-- overlapping casts need, their tooltips, the empty note, the two headings), its legend, the
-- compare target followed as the detail's run, pick and Clear Pick change, the none and empty cases,
-- the tick tooltip, Escape,
-- closing with the Results window, a move and a resize never stored, Master scale and the stand-down.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600

-- The spells: the Infernal (3:00 cooldown), Soul Fire (45 s), Conflagrate (13 s), Incinerate (none),
-- and the pet's Firebolt (none).
local INFERNAL, SOUL_FIRE, CONFLAG, INCINERATE, FIREBOLT = 1122, 6353, 17962, 29722, 3110
local SPELLS = { [INFERNAL] = 180000, [SOUL_FIRE] = 45000, [CONFLAG] = 13000, [INCINERATE] = 0, [FIREBOLT] = 0 }

local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
    end }
    i.R, i.TL = i.NS.Results, i.NS.ResultsTimeline
    return i
end

-- A cast record from { { t, id, pet? }, ... }.
local function casts(NS, list)
    local decoded = {}
    for n, c in ipairs(list) do decoded[n] = { t = c[1], id = c[2], pet = c[3] == true } end
    return { v = 1, list = NS.Casts.Encode(decoded), spells = SPELLS, dropped = 0 }
end

-- This run's casts: the Infernal once, Soul Fire twice, Conflagrate once, Incinerate three times, the
-- pet's Firebolt twice; a pre-pull Soul Fire.
local THIS = { { -1.5, SOUL_FIRE }, { 1, INFERNAL }, { 2, INCINERATE }, { 4, CONFLAG }, { 5, INCINERATE },
               { 6, FIREBOLT, true }, { 9, INCINERATE }, { 12, FIREBOLT, true }, { 50, SOUL_FIRE } }
-- The best's: no Infernal, Soul Fire once, Conflagrate twice, Incinerate once.
local BEST = { { 0.5, SOUL_FIRE }, { 3, CONFLAG }, { 8, INCINERATE }, { 20, CONFLAG } }

--- A stored-shape complete 1:00 cleave run by Lanfear (Destruction); `list` its casts (nil: none).
local function mkRun(NS, id, dps, list, fields)
    local run = {
        id = id, schema = 3, status = "complete", addon = "0.1.0", date = NOW - HOUR,
        race = { length = 60, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction" },
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 60, dps = dps, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = INCINERATE, dmg = dps * 50 } }, note = "",
        casts = list and casts(NS, list) or nil,
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    return run
end

local function seed(i, runs)
    for _, run in ipairs(runs) do i.NS.db.global.runs[run.id] = run end
    i.NS.Bests.Invalidate()
end

-- "this" under "best" on one board.
local function board(i)
    seed(i, { mkRun(i.NS, "this", 100, THIS), mkRun(i.NS, "best", 300, BEST, { date = NOW - 2 * HOUR }) })
end

local function detail(i) return assert(i.R.__ui(), "the Results window was never built").detail end
local function win(i) return assert(i.TL.__ui(), "the timeline was never built") end

local function key(row) return (row.pet and "p" or "") .. row.id end
local function keys(rows)
    local out = {}
    for n, row in ipairs(rows) do out[n] = key(row) end
    return table.concat(out, ",")
end

-- The pairs drawn now, in order.
local function pairsOf(i) return win(i).pairs.active end

local function marksIn(i, lane, id)
    local out = {}
    for _, d in ipairs(i.TL.Marks()) do
        if d.lane == lane and (id == nil or d.cast.id == id) then out[#out + 1] = d end
    end
    return out
end

local function open(i, id)
    i.R.ShowRun(id)
    detail(i).w.timeline:__fire("OnClick")
    return win(i)
end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────────

test("results timeline: one row per ability and caster across both runs, each run's times and counts", function()
    local i = inst()
    local NS = i.NS
    local rows = i.TL.Rows(mkRun(NS, "a", 1, THIS), mkRun(NS, "b", 1, BEST))
    assertEqual(#rows, 5, "the Infernal, Soul Fire, Conflagrate, Incinerate and the pet's Firebolt")
    local by = {}
    for _, row in ipairs(rows) do by[key(row)] = row end
    assertEqual(table.concat(by[SOUL_FIRE .. ""].a, ","), "-1.5,50", "this run's times in order")
    assertEqual(table.concat(by[SOUL_FIRE .. ""].b, ","), "0.5")
    assertEqual(by[INCINERATE .. ""].countA, 3)
    assertEqual(by[INCINERATE .. ""].countB, 1)
    assertEqual(by[INFERNAL .. ""].countB, 0, "the best never cast it: an empty lane")
    assertEqual(#by[INFERNAL .. ""].b, 0)
    assertTrue(by["p" .. FIREBOLT].pet, "the pet's ability is its own row")
    assertEqual(by["p" .. FIREBOLT].countA, 2)
    -- An ability only the compared run cast is still a row, its cooldown from that run.
    local only = i.TL.Rows(mkRun(NS, "a", 1, { { 2, INCINERATE } }), mkRun(NS, "b", 1, { { 1, INFERNAL } }))
    assertEqual(keys(only), INFERNAL .. "," .. INCINERATE)
    assertEqual(only[1].countA, 0)
    assertEqual(only[1].cd, 180000)
end)

test("results timeline: cooldowns of 29 s or more first, the longest first; then by count, the player's before the pet's", function()
    local i = inst()
    local NS = i.NS
    local rows = i.TL.Rows(mkRun(NS, "a", 1, THIS), mkRun(NS, "b", 1, BEST))
    -- Conflagrate's 13 s is short of 29 s: it ranks by count (1 here, 2 in the best) after Incinerate's 3
    -- and the pet's 2.
    assertEqual(keys(rows), table.concat({ INFERNAL, SOUL_FIRE, INCINERATE, "p" .. FIREBOLT, CONFLAG }, ","))
    -- With no compared run the order stands on this run alone.
    assertEqual(keys(i.TL.Rows(mkRun(NS, "a", 1, THIS), nil)), keys(rows))
    -- A tie on this run's count goes to the compared run's.
    local tie = i.TL.Rows(mkRun(NS, "a", 1, { { 1, INCINERATE }, { 2, CONFLAG } }),
        mkRun(NS, "b", 1, { { 1, CONFLAG }, { 2, CONFLAG } }))
    assertEqual(keys(tie), CONFLAG .. "," .. INCINERATE)
    assertEqual(#i.TL.Rows(mkRun(NS, "a", 1, nil), nil), 0, "a run with no casts has no rows")
    -- The 29 s line: a 25 s cooldown ranks by count after Conflagrate (a tie on 1, the best's 0 under its
    -- 2), a 29 s one sorts with the long cooldowns after Soul Fire.
    local SHORT, EDGE = 900025, 900029
    local list, spells = { { 1, SHORT }, { 2, EDGE } }, { [SHORT] = 25000, [EDGE] = 29000 }
    for _, c in ipairs(THIS) do list[#list + 1] = c end
    for id, cd in pairs(SPELLS) do spells[id] = cd end
    local edge = mkRun(NS, "a", 1, list)
    edge.casts.spells = spells
    local ranked = i.TL.Rows(edge, mkRun(NS, "b", 1, BEST))
    assertEqual(keys(ranked),
        table.concat({ INFERNAL, SOUL_FIRE, EDGE, INCINERATE, "p" .. FIREBOLT, CONFLAG, SHORT }, ","))
    for _, row in ipairs(ranked) do
        if row.id == SHORT then assertEqual(i.TL.CooldownLine(row), "", "25 s shows no cooldown") end
        if row.id == EDGE then assertEqual(i.TL.CooldownLine(row), "0:29 cooldown", "29 s shows one") end
    end
end)

test("results timeline: the axis runs to the longer race, in quarters; a tick's x is clamped inside its lane", function()
    local i = inst()
    local NS, TL = i.NS, i.TL
    assertEqual(TL.Span(mkRun(NS, "a", 1), nil), 60)
    assertEqual(TL.Span(mkRun(NS, "a", 1), mkRun(NS, "b", 1, nil, { race = { length = 180 } })), 180)
    assertEqual(table.concat(TL.Ticks(60), ","), "0,15,30,45,60")
    assertEqual(TL.MarkX(0, 60, 402), TL.INSET)
    assertEqual(TL.MarkX(30, 60, 402), TL.INSET + 200)
    assertEqual(TL.MarkX(-2, 60, 402), TL.INSET, "a pre-pull cast sits at 0:00")
    assertEqual(TL.MarkX(64, 60, 402), 402 - TL.INSET, "a cast after the buzzer sits at the end")
    assertNil(TL.MarkX(nil, 60, 402))
    assertNil(TL.MarkX(5, 0, 402))
    assertEqual(TL.CooldownText({ cd = 180000 }), "3:00")
    assertEqual(TL.CooldownText({ cd = 28900 }), "", "28.9 s is short of 29 s")
    assertEqual(TL.CooldownText({ cd = 29000 }), "0:29", "29 s is a long cooldown")
    assertEqual(TL.CooldownLine({ cd = 90000 }), "1:30 cooldown", "the line under the name")
    assertEqual(TL.CooldownLine({ cd = 13000 }), "")
    assertEqual(TL.Name({ id = FIREBOLT, pet = true }), "Spell 3110 (pet)")
    assertEqual(TL.Name({ id = INCINERATE }), "Incinerate")
end)

-- ── the button ──────────────────────────────────────────────────────────────────────────────────

test("results timeline: the detail's Timeline button is live for a run with casts and disabled without", function()
    local i = inst()
    board(i)
    seed(i, { mkRun(i.NS, "old", 200, nil, { schema = 2, date = NOW - 3 * HOUR }),
              mkRun(i.NS, "none", 150, {}, { date = NOW - 4 * HOUR }) })
    i.R.ShowRun("this")
    local b = detail(i).w.timeline
    assertTrue(b:IsShown())
    assertEqual(b.label.__text, "Timeline")
    assertTrue(b:IsEnabled(), "a run with casts")
    i.R.ShowRun("old")
    assertFalse(b:IsEnabled(), "a run stored before casts were kept")
    i.R.ShowRun("none")
    assertFalse(b:IsEnabled(), "a run that recorded no cast")
    -- Its tooltip says why it is off.
    local lines = i.NS.ResultsTips.Detail("timelineOff", i.NS.Recorder.Get("old"))
    assertEqual(lines[1], "Timeline")
    assertTrue(i.NS.ResultsTips.Detail("timeline", i.NS.Recorder.Get("this")) ~= nil)
    i.R.ShowRun("this")
    assertTrue(b:IsEnabled())
    assertFalse(i.TL.IsShown(), "nothing opens it but the button")
    b:__fire("OnClick")
    assertTrue(i.TL.IsShown())
    assertEqual(win(i).frame.title.__text, "Ability timeline")
end)

-- ── the lanes ───────────────────────────────────────────────────────────────────────────────────

test("results timeline: two lanes per ability, this run's gold ticks on top and the best's blue below, with counts", function()
    local i = inst()
    local TL = i.TL
    board(i)
    local u = open(i, "this")
    local drawn = pairsOf(i)
    assertEqual(#drawn, 5)
    assertEqual(drawn[1].name.__text, "Spell 1122")
    assertEqual(drawn[1].cd.__text, "3:00 cooldown", "its cooldown, 29 s or more")
    assertEqual(drawn[3].name.__text, "Incinerate")
    assertEqual(drawn[3].cd.__text, "", "no cooldown shown under 29 s")
    -- The cooldown sits under the name in the name cell, on the bottom lane's line: nothing between
    -- the name cell and the lanes but the gap.
    local cdAt = drawn[1].cd.__points[#drawn[1].cd.__points]
    assertEqual(cdAt[1], "LEFT")
    assertEqual(cdAt[4], TL.ICON + 6, "aligned with the name")
    assertEqual(cdAt[5], -(1.5 * TL.LANE_H + TL.LANE_GAP), "the bottom lane's middle")
    assertTrue(TL.ICON + 6 + drawn[1].cd.__width <= TL.NAME_W, "inside the name cell")
    assertEqual(drawn[4].name.__text, "Spell 3110 (pet)")
    assertEqual(drawn[3].countA.__text, "3")
    assertEqual(drawn[3].countB.__text, "1")
    assertEqual(drawn[1].countB.__text, "0", "the best never cast the Infernal")
    -- Every cast is a tick: nine on top, four below.
    assertEqual(#marksIn(i, "a"), #THIS)
    assertEqual(#marksIn(i, "b"), #BEST)
    assertEqual(#marksIn(i, "b", INFERNAL), 0)
    -- Laid from the geometry: the lanes after the name cell, the top lane's middle and the bottom one's.
    local _, laneX, laneW = TL.LaneGeometry(u.width)
    local pairTop = -TL.Layout().lanes - 2 * TL.PAIR_H   -- Incinerate is the third pair, under the strips
    for _, d in ipairs(marksIn(i, "a", INCINERATE)) do
        assertEqual(d.x, laneX + TL.MarkX(d.cast.t, 60, laneW))
        assertEqual(d.y, pairTop - TL.LANE_H / 2)
        assertEqual(d.tex.__vertex[1], TL.THIS[1])
        -- A thin tick the lane's full height, with a hover frame a few px wider.
        assertEqual(d.tex.__texture, "Interface\\Buttons\\WHITE8x8")
        assertEqual(d.tex.__width, TL.MARK_W)
        assertEqual(d.tex.__height, TL.LANE_H)
    end
    local below = marksIn(i, "b", INCINERATE)[1]
    assertEqual(below.y, pairTop - TL.LANE_H - TL.LANE_GAP - TL.LANE_H / 2)
    assertEqual(below.tex.__vertex[3], TL.OTHER[3])
    -- The pre-pull Soul Fire clamps to 0:00.
    assertEqual(marksIn(i, "a", SOUL_FIRE)[1].x, laneX + TL.INSET)
    -- The axis: 0, the quarters and the end.
    local axis = {}
    for n, fs in ipairs(u.axis) do axis[n] = fs.__text end
    assertEqual(table.concat(axis, ","), "0:00,0:15,0:30,0:45,1:00")
    assertEqual(#i.TL.Marks(), #THIS + #BEST)
end)

test("results timeline: the legend names both runs; a tick's tooltip names the spell, its time and its run", function()
    local i = inst()
    board(i)
    local u = open(i, "this")
    local best = i.NS.Recorder.Get("best")
    assertEqual(u.legendA.__text, "This run \194\183 " .. os.date("%d %b %H:%M", NOW - HOUR))
    assertEqual(u.legendB.__text, "Best run \194\183 " .. os.date("%d %b %H:%M", best.date))
    assertFalse(u.note:IsShown(), "nothing to note")
    local dot = marksIn(i, "a", INFERNAL)[1]
    assertTrue(dot.hit.__mouse, "its hover frame takes the mouse")
    assertTrue(i.TL.MARK_HIT > i.TL.MARK_W, "the hover frame is wider than the tick")
    local shown
    -- Beside the window, level with the tick (UT-P17), not under it.
    local real, below = i.NS.ResultsTable.SideTip, i.NS.ResultsTable.BelowTip
    i.NS.ResultsTable.SideTip = function(window, row, lines) shown = { window = window, row = row, lines = lines } end
    i.NS.ResultsTable.BelowTip = function() error("a tick's tooltip went under it") end
    dot.hit:GetScript("OnEnter")(dot.hit)
    i.NS.ResultsTable.SideTip, i.NS.ResultsTable.BelowTip = real, below
    assertTrue(shown ~= nil and shown.window == u.frame and shown.row == dot.hit)
    assertEqual(shown.lines[1], "Spell 1122")
    assertEqual(shown.lines[2], "Cast at 0:01")
    assertEqual(shown.lines[3][1], u.legendA.__text, "which run")
    -- A name's tooltip: the cooldown, then both counts.
    local lines = i.NS.ResultsTips.TimelineRow(pairsOf(i)[1].row, i.TL.OtherLabel(best, "best"))
    assertEqual(lines[1][1], "Cooldown 3:00")
    assertEqual(lines[2], "This run: 1 cast")
    assertEqual(lines[3], u.legendB.__text .. ": 0 casts")
end)

-- ── the counts and the cast icons (P11) ─────────────────────────────────────────────────────────

test("results timeline: each lane's count sits just past the lane's right end, not out at the window's edge", function()
    local i = inst()
    local TL = i.TL
    board(i)
    local u = open(i, "this")
    assertTrue(TL.COUNT_GAP >= 8 and TL.COUNT_GAP <= 12, "a small gap, clear of the lane's end (P12)")
    local _, laneX, laneW = TL.LaneGeometry(u.width)
    for _, pair in ipairs(pairsOf(i)) do
        for _, count in ipairs({ pair.countA, pair.countB }) do
            local at = count.__points[#count.__points]
            assertEqual(at[1], "LEFT", "left-aligned on the lane's end")
            assertEqual(at[4], laneX + laneW + TL.COUNT_GAP)
        end
    end
    -- The lanes take the width the count cell leaves.
    assertEqual(laneX + laneW + TL.COUNT_GAP + TL.COUNT_W, u.width - 2 * TL.PAD)
end)

test("results timeline: overlapping icons stack onto extra rows and the strip grows to fit them all", function()
    local i = inst()
    local TL = i.TL
    local function same(n)
        local xs = {}
        for k = 1, n do xs[k] = 100 end
        return xs
    end
    for _, n in ipairs({ 1, 3, 6 }) do
        local rows, count, over = TL.Stack(same(n), TL.CAST_PITCH, TL.MAX_STACK)
        assertEqual(count, n, n .. " casts at one time need " .. n .. " rows")
        assertEqual(rows[n], n)
        assertNil(next(over), "none past the cap")
        assertEqual(TL.StripHeight(count), n * TL.CAST_STEP)
    end
    -- Icons a full pitch apart share a row; closer ones do not, and a freed row is reused.
    local rows, count = TL.Stack({ 0, 15, 20, 30, 45 }, TL.CAST_PITCH, TL.MAX_STACK)
    assertEqual(table.concat(rows, ","), "1,1,2,1,1")
    assertEqual(count, 2)
    -- Past the cap: every icon still drawn, the rest on the row that frees first, flagged.
    local capped, used, over = TL.Stack(same(TL.MAX_STACK + 2), TL.CAST_PITCH, TL.MAX_STACK)
    assertEqual(used, TL.MAX_STACK)
    assertEqual(#capped, TL.MAX_STACK + 2)
    assertTrue(over[TL.MAX_STACK + 1] and over[TL.MAX_STACK + 2])
    assertNil(over[TL.MAX_STACK])
    assertEqual(TL.StripHeight(0), TL.CAST_STEP, "an empty strip keeps a row for its note")
    -- The sections: the Casts heading, this run's strip, the compared run's, their axis, the By
    -- ability heading.
    local Style = i.NS.Style
    local s = TL.Sections(3, 1)
    assertEqual(s.stripA, Style.SECTION_H + TL.CASTS_PAD, "a little under the Casts heading")
    assertEqual(s.heightA, 3 * TL.CAST_STEP)
    assertEqual(s.stripB, s.stripA + s.heightA + TL.STRIP_GAP)
    assertEqual(s.castsAxis, s.stripB + s.heightB + TL.CASTS_PAD, "the strips' own axis under them")
    assertEqual(s.lanesHead, s.castsAxis + TL.CASTS_AXIS_H + Style.SECTION_GAP)
    assertEqual(s.lanes, s.lanesHead + Style.SECTION_H)
end)

test("results timeline: the Casts strips show every cast of both runs as its icon on the lanes' time axis", function()
    local i = inst()
    local TL = i.TL
    board(i)
    local u = open(i, "this")
    local a, b = {}, {}
    for _, d in ipairs(TL.Icons()) do
        local list = d.side == "a" and a or b
        list[#list + 1] = d
    end
    assertEqual(#a, #THIS, "every cast of this run, the pet's too")
    assertEqual(#b, #BEST, "every cast of the best")
    local _, laneX, laneW = TL.LaneGeometry(u.width)
    local s = TL.Layout()
    local pets = 0
    for _, d in ipairs(a) do
        assertEqual(d.x, laneX + TL.MarkX(d.cast.t, 60, laneW), "on the lanes' axis")
        assertEqual(d.frame.tex.__texture, i.NS.HudBreakdown.SpellIcon(d.cast.id))
        assertTrue(d.frame.__mouse, "it takes the mouse")
        -- This run's strip stacks up from its bottom row.
        assertEqual(d.y, -(s.stripA + s.heightA - (d.row - 0.5) * TL.CAST_STEP))
        if d.cast.pet then pets = pets + 1 end
    end
    assertEqual(pets, 2, "the pet's Firebolts")
    for _, d in ipairs(b) do
        -- The compared run's strip stacks down from its top row.
        assertEqual(d.y, -(s.stripB + (d.row - 0.5) * TL.CAST_STEP))
    end
    -- The headings: Casts over the strips, By ability over the lanes, in the section style.
    assertEqual(u.castsHead.__text, "Casts")
    assertEqual(u.castsHead.__fontObject, i.NS.Style.FONT.SECTION)
    assertEqual(u.lanesHead.__text, "By ability")
    assertEqual(u.lanesHead.__fontObject, i.NS.Style.FONT.SECTION)
    local at = u.lanesHead.__points[#u.lanesHead.__points]
    assertEqual(at[5], -s.lanesHead)
    assertTrue(s.lanesHead > s.stripB + s.heightB, "under both strips")
    -- Each strip names its run in the name cell; neither shows its empty note.
    assertEqual(u.strips.a.label.__text, "This run")
    assertEqual(u.strips.b.label.__text, "Best run")
    assertFalse(u.strips.a.note:IsShown())
    assertFalse(u.strips.b.note:IsShown())
    assertEqual(#pairsOf(i), 5, "the lanes still drawn under them")
end)

test("results timeline: a strip grows with the casts stacked at one time; the lanes start under it", function()
    local i = inst()
    local TL = i.TL
    for _, n in ipairs({ 1, 3, 6 }) do
        local list = {}
        for k = 1, n do list[k] = { 10, 100000 + k } end
        seed(i, { mkRun(i.NS, "stack" .. n, 100, list) })
        open(i, "stack" .. n)
        local s = TL.Layout()
        assertEqual(s.heightA, n * TL.CAST_STEP, n .. " overlapping casts")
        local rows = {}
        for _, d in ipairs(TL.Icons()) do if d.side == "a" then rows[#rows + 1] = d.row end end
        table.sort(rows)
        assertEqual(#rows, n)
        assertEqual(rows[n], n, "one row each")
        local pair = pairsOf(i)[1]
        assertEqual(pair.__points[#pair.__points][5], -s.lanes, "the first pair under the By ability heading")
        assertEqual(win(i).contentH, s.lanes + n * TL.PAIR_H - TL.PAIR_GAP, "the content scrolls over both")
    end
end)

test("results timeline: an icon's tooltip is the client's spell tooltip, then its time and its run on bullets", function()
    local i = inst()
    local TL = i.TL
    board(i)
    local u = open(i, "this")
    local shown
    -- Beside the window, level with the icon, a tick's way (UT-P17), not under the cursor.
    local real = i.NS.ResultsTable.SpellTip
    i.NS.ResultsTable.SpellTip = function(window, row, id, lines) shown = { window = window, owner = row, id = id, lines = lines } end
    local function hover(side, id)
        for _, d in ipairs(TL.Icons()) do
            if d.side == side and d.cast.id == id then
                d.frame:GetScript("OnEnter")(d.frame)
                return d
            end
        end
    end
    local d = hover("a", INFERNAL)
    assertTrue(shown.window == u.frame and shown.owner == d.frame, "beside the window, level with the icon")
    assertEqual(shown.id, INFERNAL, "the plain stored ID")
    assertEqual(shown.lines[1], "Cast at 0:01")
    assertEqual(shown.lines[2][1], u.legendA.__text, "which run")
    hover("a", FIREBOLT)
    assertEqual(shown.lines[1], "Cast at 0:06 (pet)")
    hover("b", CONFLAG)
    assertEqual(shown.lines[1], "Cast at 0:03")
    assertEqual(shown.lines[2][1], u.legendB.__text)
    i.NS.ResultsTable.SpellTip = real
    -- Two lines or more go on bullets (the addon's rule, Style.TipBullet); past the cap a third says
    -- the icon overlaps others.
    local lines = TL.IconLines({ t = 5, id = INFERNAL }, "This run", true)
    assertEqual(#lines, 3)
    assertEqual(lines[3][1], "Too many casts here for " .. TL.MAX_STACK .. " rows: this icon overlaps others.")
    assertEqual(i.NS.Style.TipBullet(lines, 1), i.NS.Style.BULLET)
    assertNil(TL.IconLines(nil, "x"))
end)

test("results timeline: a strip with no casts shows a dim note in place of its icons", function()
    local i = inst()
    seed(i, { mkRun(i.NS, "alone", 100, THIS) })
    local u = open(i, "alone")
    assertTrue(u.strips.b.note:IsShown())
    assertEqual(u.strips.b.note.__text, "No run to compare with")
    assertEqual(u.strips.b.note.__fontObject, i.NS.Style.FONT.CAPTION)
    assertEqual(u.strips.b.label.__text, "")
    assertFalse(u.strips.a.note:IsShown())
    assertEqual(i.TL.Layout().heightB, i.TL.CAST_STEP, "one row's height for its note")
    seed(i, { mkRun(i.NS, "oldBest", 500, nil, { schema = 2, date = NOW - 2 * HOUR }) })
    i.R.ShowRun("alone")
    assertEqual(u.strips.b.note.__text, "No casts recorded")
    assertEqual(u.strips.b.label.__text, "Best run")
    for _, d in ipairs(i.TL.Icons()) do assertEqual(d.side, "a") end
end)

test("results timeline: its minimum width is 640, so the icons get room; no stored size, it opens at the Results window's", function()
    local i = inst()
    local TL = i.TL
    assertEqual(TL.MIN_WIDTH, 640)
    assertNil(i.NS.defaults.profile.windows.timeline, "nothing of the timeline is stored (UT-P14)")
    for _, view in pairs(i.R.VIEWS) do
        assertTrue(view.minWidth >= TL.MIN_WIDTH and i.R.MIN_HEIGHT >= TL.MIN_HEIGHT, "the Results window is never smaller")
    end
    local _, _, laneW = TL.LaneGeometry(TL.MIN_WIDTH)
    assertTrue(laneW / 60 >= 7, "a 1:00 race gets 7 px a second at the minimum")
end)

-- ── the compare target, followed ────────────────────────────────────────────────────────────────

test("results timeline: it follows the detail: another run, a pick and Clear Pick redraw it", function()
    local i = inst()
    board(i)
    local other = mkRun(i.NS, "other", 900, { { 1, CONFLAG } }, { race = { length = 180, grace = 1 }, date = NOW - 5 * HOUR })
    seed(i, { other })
    local u = open(i, "this")
    assertEqual(#marksIn(i, "b"), #BEST, "the best on the board")
    -- The row menu's pick: the picked run's lanes, its label, the longer axis.
    assertTrue(i.R.CompareWith("other"))
    assertEqual(u.legendB.__text, "Picked \194\183 " .. os.date("%d %b %H:%M", other.date))
    assertEqual(#marksIn(i, "b"), 1)
    assertEqual(u.axis[5].__text, "3:00", "the picked run's race is longer")
    -- Clear Pick: back to the best.
    detail(i).cmp.clear:__fire("OnClick")
    assertEqual(#marksIn(i, "b"), #BEST)
    assertEqual(u.axis[5].__text, "1:00")
    -- The toggle does not change the target (it is resolved either way).
    detail(i):SetComparing(true)
    assertEqual(#marksIn(i, "b"), #BEST)
    -- The detail moves to the best: it compares with the runner-up, this run.
    i.R.ShowRun("best")
    assertEqual(u.legendB.__text, "Runner-up \194\183 " .. os.date("%d %b %H:%M", NOW - HOUR))
    assertEqual(#marksIn(i, "a"), #BEST)
    assertEqual(#marksIn(i, "b"), #THIS)
end)

test("results timeline: with no run to compare with, or one with no casts, the blue lanes stay empty under a note", function()
    local i = inst()
    seed(i, { mkRun(i.NS, "alone", 100, THIS) })
    local u = open(i, "alone")
    assertEqual(u.legendB.__text, "No run to compare with")
    assertTrue(u.note:IsShown())
    assertEqual(u.note.__text, "No run to compare with: the blue lanes stay empty.")
    assertEqual(#marksIn(i, "b"), 0)
    assertEqual(pairsOf(i)[1].countB.__text, "", "no count for a lane with no run")
    assertEqual(#pairsOf(i), 5, "this run's lanes still drawn")
    -- A better run on the board with no casts recorded (stored before format 3).
    seed(i, { mkRun(i.NS, "oldBest", 500, nil, { schema = 2, date = NOW - 2 * HOUR }) })
    i.R.ShowRun("alone")
    assertEqual(u.note.__text, "Best run has no casts recorded: the blue lanes stay empty.")
    assertEqual(#marksIn(i, "b"), 0)
    assertEqual(#marksIn(i, "a"), #THIS)
end)

test("results timeline: a run with no casts or no run at all shows a message in place of the lanes", function()
    local i = inst()
    board(i)
    seed(i, { mkRun(i.NS, "old", 50, nil, { schema = 2, date = NOW - 3 * HOUR }) })
    local u = open(i, "this")
    assertFalse(u.empty:IsShown())
    i.R.ShowRun("old")
    assertTrue(i.TL.IsShown(), "it stays open")
    assertTrue(u.empty:IsShown())
    assertEqual(u.empty.__text, "No casts recorded for this run.")
    assertEqual(#pairsOf(i), 0)
    assertEqual(#i.TL.Marks(), 0)
    assertFalse(u.scroll:IsShown())
    i.R.DeleteRun("old")
    assertEqual(u.empty.__text, "Select a run in the Results window to see its timeline.")
    assertFalse(u.legendA:IsShown())
end)

-- ── the window ──────────────────────────────────────────────────────────────────────────────────

test("results timeline: Escape and its close control close it, as does the Results window closing", function()
    local i = inst()
    board(i)
    local u = open(i, "this")
    local escapable = false
    for _, name in ipairs(i.mocks.UISpecialFrames) do escapable = escapable or name == i.TL.FRAME_NAME end
    assertTrue(escapable, "Escape closes it")
    u.frame:Hide()   -- the close stack's hide
    u.frame:__fire("OnHide")
    assertFalse(i.TL.IsShown())
    assertFalse(i.TL.wanted)
    detail(i).w.timeline:__fire("OnClick")
    assertTrue(i.TL.IsShown())
    i.TL.Hide()
    assertFalse(i.TL.IsShown())
    detail(i).w.timeline:__fire("OnClick")
    i.R.Hide()
    assertFalse(i.TL.IsShown(), "it follows the detail, so it goes with the window")
    -- Closed, a detail draw does not bring it back.
    i.R.ShowRun("this")
    assertFalse(i.TL.IsShown())
end)

test("results timeline: it scrolls by a pair per notch; a move and a resize are never stored; Reset position puts it over the Results window", function()
    local i = inst()
    local list = {}
    for n = 1, 30 do list[n] = { n, 100000 + n } end
    seed(i, { mkRun(i.NS, "many", 100, list) })
    local u = open(i, "many")
    assertEqual(#pairsOf(i), 30)
    assertEqual(u.offset, 0)
    i.TL.Scroll(-1)
    assertEqual(u.offset, i.TL.PAIR_H)
    i.TL.Scroll(-1000)
    assertEqual(u.offset, u.contentH - u.viewH, "clamped to the last pair")
    i.TL.Scroll(1000)
    assertEqual(u.offset, 0)
    local before = i.NS.db.profile.windows.results.point
    rawset(u.frame, "GetPoint", function() return "TOPLEFT", nil, "BOTTOMLEFT", 40.4, 600.6 end)
    u.drag:__fire("OnDragStart")
    u.drag:__fire("OnDragStop")
    u.frame:__fire("OnSizeChanged", 1000, 500)
    assertEqual(u.width, 1000)
    u.frame:__fire("OnSizeChanged", 200, 100)
    assertEqual(u.width, i.TL.MIN_WIDTH, "never under its minimum")
    assertEqual(u.height, i.TL.MIN_HEIGHT)
    assertNil(i.NS.db.profile.windows.timeline, "nothing stored")
    assertEqual(i.NS.db.profile.windows.results.point, before, "nor the Results window's")
    -- Reset position (the Results window's first, settings/General.lua): back over that window.
    i.R.ResetPosition()
    i.TL.ResetPosition()
    local _, _, _, _, rw, rh = i.R.Placement()
    assertEqual(u.width, rw)
    assertEqual(u.height, rh)
    assertNil(i.NS.db.profile.windows.timeline)
end)

test("results timeline: it follows Master scale while open", function()
    local i = inst()
    board(i)
    local u = open(i, "this")
    assertTrue(i.NS.SetByPath("scale", 1.25))
    assertEqual(u.frame.__scale, 1.25)
    -- On the Insights tab the detail draws nothing, so the scale reaction itself must reach the window.
    assertTrue(i.R.ShowTab("insights"))
    assertTrue(i.TL.IsShown(), "it stays open over the other tab")
    assertTrue(i.NS.SetByPath("scale", 0.8))
    assertEqual(u.frame.__scale, 0.8)
    i.NS.SetByPath("scale", 1.0)
end)

test("results timeline: a stand-down hides it, and nothing opens it while stood down", function()
    local i = inst()
    board(i)
    local u = open(i, "this")
    assertTrue(i.TL.IsShown())
    assertTrue(i.NS.SetByPath("enabled", false))
    assertFalse(i.TL.IsShown(), "the stand-down (Results.Suspend) closed it")
    assertFalse(u.frame:IsShown())
    assertFalse(i.TL.Open(detail(i)), "no open while stood down")
    assertFalse(u.frame:IsShown())
end)
