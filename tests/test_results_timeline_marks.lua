-- tests/test_results_timeline_marks.lua — the ability timeline's cast marks (DpsRace#21,
-- modules/Results_TimelineMarks.lua): By ability draws each cast as its ability's icon by default, with
-- the Casts icon's tooltip, or as a tick line (`results.timelineMarks`, its History row and the two
-- words on the By ability heading line, which redraw an open window keeping its zoom); a player's cast
-- in PLAYER_LINE and a pet's in PET_LINE, a tick tinted and an icon edged, the Casts strips' icons
-- edged the same; the lanes' clip padded so an icon at 0:00 shows whole; the icons along a zoomed
-- axis and moved, not re-pooled, while the grip is held.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600
local FRAME = 1 / 60

-- The Infernal (3:00 cooldown), Soul Fire (45 s), Conflagrate (13 s), Incinerate (none) and the pet's
-- Firebolt (none).
local INFERNAL, SOUL_FIRE, CONFLAG, INCINERATE, FIREBOLT = 1122, 6353, 17962, 29722, 3110
local SPELLS = { [INFERNAL] = 180000, [SOUL_FIRE] = 45000, [CONFLAG] = 13000, [INCINERATE] = 0, [FIREBOLT] = 0 }
-- This run: a pre-pull Soul Fire, the pet's Firebolt twice. The best: no pet.
local THIS = { { -1.5, SOUL_FIRE }, { 1, INFERNAL }, { 2, INCINERATE }, { 4, CONFLAG }, { 5, INCINERATE },
               { 6, FIREBOLT, true }, { 9, INCINERATE }, { 12, FIREBOLT, true }, { 50, SOUL_FIRE } }
local BEST = { { 0.5, SOUL_FIRE }, { 3, CONFLAG }, { 8, INCINERATE }, { 20, CONFLAG } }

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

local function mkRun(NS, id, dps, list, fields)
    local decoded = {}
    for n, c in ipairs(list) do decoded[n] = { t = c[1], id = c[2], pet = c[3] == true } end
    local run = {
        id = id, schema = 3, status = "complete", addon = "0.1.0", date = NOW - HOUR,
        race = { length = 60, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction" },
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 60, dps = dps, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = INCINERATE, dmg = dps * 50 } }, note = "",
        casts = { v = 1, list = NS.Casts.Encode(decoded), spells = SPELLS, dropped = 0 },
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    return run
end

-- The timeline open on "this", compared with "best"; `mode` stored first when given.
local function opened(mode)
    local i = inst()
    local NS = i.NS
    if mode then NS.db.profile.results.timelineMarks = mode end
    for _, run in ipairs({ mkRun(NS, "this", 100, THIS), mkRun(NS, "best", 300, BEST, { date = NOW - 2 * HOUR }) }) do
        NS.db.global.runs[run.id] = run
    end
    NS.Bests.Invalidate()
    i.R.ShowRun("this")
    i.R.__ui().detail.w.timeline:__fire("OnClick")
    return i, assert(i.TL.__ui(), "the timeline was never built")
end

local function marksIn(i, lane, id)
    local out = {}
    for _, d in ipairs(i.TL.Marks()) do
        if d.lane == lane and (id == nil or d.cast.id == id) then out[#out + 1] = d end
    end
    return out
end

local function last(region) return region.__points[#region.__points] end
local function rgb(c) return ("%.2f,%.2f,%.2f"):format(c[1], c[2], c[3]) end

-- ── the setting ─────────────────────────────────────────────────────────────────────────────────

test("timeline marks: the caster colors are Combat Trail's palette lines, and the row defaults to icons", function()
    local i = inst()
    local TL, NS = i.TL, i.NS
    assertEqual(rgb(TL.PLAYER_LINE), "0.50,0.52,1.00")
    assertEqual(rgb(TL.PET_LINE), "0.40,0.85,0.45")
    assertTrue(TL.CasterColor(false) == TL.PLAYER_LINE and TL.CasterColor(true) == TL.PET_LINE)
    assertEqual(NS.defaults.profile.results.timelineMarks, "icon")
    assertEqual(TL.MarkMode(), "icon")
    local row = assert(NS.FindSchemaRow("results.timelineMarks"), "a schema row")
    assertEqual(row.default, "icon")
    assertEqual(row.page, "history")
    assertFalse(row.validate("foo"), "only icon or tick")
    assertTrue(row.validate("tick"))
    assertFalse(NS.SetByPath("results.timelineMarks", "foo"))
    assertTrue(NS.SetByPath("results.timelineMarks", "tick"))
    assertEqual(TL.MarkMode(), "tick")
    NS.ApplyDefault(row)
    assertEqual(NS.db.profile.results.timelineMarks, "icon", "Defaults puts icons back")
end)

-- ── icons ───────────────────────────────────────────────────────────────────────────────────────

test("timeline marks: by default every cast in By ability is its ability's icon on the lanes' layer", function()
    local i, u = opened()
    local TL = i.TL
    assertEqual(#marksIn(i, "a"), #THIS)
    assertEqual(#marksIn(i, "b"), #BEST)
    local _, laneX, laneW = TL.LaneGeometry(u.width)
    for _, d in ipairs(TL.Marks()) do
        assertEqual(d.kind, "icon")
        assertNil(d.tex, "no tick")
        assertTrue(d.frame.__parentFrame == u.marks or d.frame:GetParent() == u.marks, "on the lanes' layer")
        assertEqual(d.frame.__width, TL.LANE_ICON)
        assertEqual(d.frame.__height, TL.LANE_ICON)
        assertTrue(TL.LANE_ICON <= TL.LANE_H - 2, "inside its lane")
        assertEqual(d.frame.tex.__texture, i.NS.HudBreakdown.SpellIcon(d.cast.id))
        assertTrue(d.frame.__mouse, "it takes the mouse")
        assertEqual(d.x, laneX + TL.MarkX(d.cast.t, 60, laneW))
    end
    assertEqual(#u.markPool.active, 0, "no tick drawn")
    assertEqual(#u.hitPool.active, 0)
end)

test("timeline marks: a lane icon's tooltip is the Casts icon's for the same cast", function()
    local i, u = opened()
    local TL = i.TL
    local shown
    local real = i.NS.ResultsTable.SpellTip
    i.NS.ResultsTable.SpellTip = function(window, owner, id, lines) shown = { window = window, owner = owner, id = id, lines = lines } end
    local d = marksIn(i, "a", INFERNAL)[1]
    d.frame:GetScript("OnEnter")(d.frame)
    assertTrue(shown.window == u.frame and shown.owner == d.frame, "beside the window, level with the icon")
    assertEqual(shown.id, INFERNAL)
    local lane = shown.lines
    local strip
    for _, c in ipairs(TL.Icons()) do
        if c.side == "a" and c.cast.id == INFERNAL then
            c.frame:GetScript("OnEnter")(c.frame)
            strip = shown.lines
        end
    end
    i.NS.ResultsTable.SpellTip = real
    assertEqual(lane[1], "Cast at 0:01")
    assertEqual(lane[2][1], u.legendA.__text, "which run")
    assertEqual(#lane, #strip, "no overlap line")
    assertEqual(lane[1], strip[1])
    assertEqual(lane[2][1], strip[2][1])
    -- The pet's says so.
    local pet = marksIn(i, "a", FIREBOLT)[1]
    i.NS.ResultsTable.SpellTip = function(_, _, _, lines) shown = { lines = lines } end
    pet.frame:GetScript("OnEnter")(pet.frame)
    i.NS.ResultsTable.SpellTip = real
    assertEqual(shown.lines[1], "Cast at 0:06 (pet)")
end)

test("timeline marks: a pre-pull cast's icon sits whole inside the lanes' padded clip", function()
    local i, u = opened()
    local TL = i.TL
    local _, laneX, laneW = TL.LaneGeometry(u.width)
    local d = marksIn(i, "a", SOUL_FIRE)[1]
    assertEqual(d.cast.t, -1.5)
    local at = last(d.frame)
    assertEqual(at[4], d.x - laneX + TL.CLIP_PAD, "the layer starts CLIP_PAD left of the lanes")
    assertTrue(at[4] >= TL.LANE_ICON / 2, "its left half inside the clip")
    assertEqual(last(u.lanesClip)[4], laneX - TL.CLIP_PAD)
    assertEqual(u.lanesClip.__width, laneW + 2 * TL.CLIP_PAD)
    assertEqual(u.marks.__width, laneW + 2 * TL.CLIP_PAD)
    assertTrue(TL.CLIP_PAD < TL.GAP and TL.CLIP_PAD < TL.COUNT_GAP, "clear of the name cell and the counts")
end)

-- ── the caster colors ───────────────────────────────────────────────────────────────────────────

test("timeline marks: a player's cast is edged PLAYER_LINE and a pet's PET_LINE, in the lanes and the Casts strips", function()
    local i, u = opened()
    local TL = i.TL
    local function check()
        for _, d in ipairs(TL.Marks()) do
            local want = d.cast.pet and TL.PET_LINE or TL.PLAYER_LINE
            assertEqual(rgb(d.frame.edge.__colorTex), rgb(want), "a lane icon's edge")
            assertEqual(d.frame.edge.__width, TL.LANE_ICON + 2, "1 px each side")
        end
        local pets = 0
        for _, d in ipairs(TL.Icons()) do
            local want = d.cast.pet and TL.PET_LINE or TL.PLAYER_LINE
            assertEqual(rgb(d.frame.edge.__colorTex), rgb(want), "a Casts icon's edge")
            assertEqual(d.frame.edge.__width, TL.CAST_ICON + 2)
            if d.cast.pet then pets = pets + 1 end
        end
        assertEqual(pets, 2)
    end
    check()
    -- Pooled frames move to other casts: the best's run on top, then back.
    i.R.ShowRun("best")
    i.R.ShowRun("this")
    assertTrue(u.frame:IsShown())
    check()
end)

test("timeline marks: in tick mode a pet's tick is PET_LINE and a player's PLAYER_LINE in both lanes", function()
    local i = opened("tick")
    local TL = i.TL
    for _, d in ipairs(TL.Marks()) do
        assertEqual(d.kind, "tick")
        local want = d.cast.pet and TL.PET_LINE or TL.PLAYER_LINE
        assertEqual(rgb(d.tex.__vertex), rgb(want))
        assertEqual(d.tex.__vertex[4], TL.MARK_A)
    end
    assertEqual(rgb(marksIn(i, "a", FIREBOLT)[1].tex.__vertex), rgb(TL.PET_LINE))
    assertEqual(rgb(marksIn(i, "b", INCINERATE)[1].tex.__vertex), rgb(TL.PLAYER_LINE), "the side no longer tints")
    assertEqual(rgb(marksIn(i, "a", INCINERATE)[1].tex.__vertex), rgb(TL.PLAYER_LINE))
end)

-- ── switching ───────────────────────────────────────────────────────────────────────────────────

test("timeline marks: the setting written while the window is open redraws it as ticks, keeping the zoom", function()
    local i, u = opened()
    local TL = i.TL
    TL.ZoomBy(2)
    TL.Pan(-1)
    local pos = u.pos
    assertTrue(i.NS.SetByPath("results.timelineMarks", "tick"))
    assertEqual(TL.Zoom(), 2, "the zoom kept")
    assertEqual(u.pos, pos, "the pan kept")
    assertEqual(#TL.Marks(), #THIS + #BEST)
    assertEqual(#u.laneIconPool.active, 0, "no icon left")
    local _, laneX, laneW = TL.LaneGeometry(u.width)
    for _, d in ipairs(TL.Marks()) do
        assertEqual(d.kind, "tick")
        assertEqual(d.tex.__texture, "Interface\\Buttons\\WHITE8x8")
        assertEqual(d.tex.__width, TL.MARK_W)
        assertEqual(d.tex.__height, TL.LANE_H)
        assertTrue(d.hit.__mouse, "a hover frame")
        assertEqual(d.x, laneX + TL.MarkX(d.cast.t, 60, 2 * laneW))
    end
    local shown
    local real = i.NS.ResultsTable.SideTip
    i.NS.ResultsTable.SideTip = function(_, _, lines) shown = lines end
    local dot = marksIn(i, "a", INFERNAL)[1]
    dot.hit:GetScript("OnEnter")(dot.hit)
    i.NS.ResultsTable.SideTip = real
    assertEqual(shown[2], "Cast at 0:01", "the tick's tooltip")
    assertTrue(i.NS.SetByPath("results.timelineMarks", "icon"))
    assertEqual(TL.Marks()[1].kind, "icon", "and back")
    assertEqual(TL.Zoom(), 2)
end)

test("timeline marks: the two words on the By ability heading line switch the marks", function()
    local i, u = opened()
    local TL, Style = i.TL, i.NS.Style
    assertEqual(u.marksIcons.label.__text, "Icons")
    assertEqual(u.marksTicks.label.__text, "Ticks")
    -- At the lanes' right edge, on the By ability heading's line.
    local _, laneX, laneW = TL.LaneGeometry(u.width)
    local at = last(u.marksTicks)
    assertEqual(at[1], "TOPRIGHT")
    assertEqual(at[4], laneX + laneW)
    assertEqual(at[5], -TL.Layout().lanesHead)
    local function gold(b) return b.label.__color ~= nil and rgb(b.label.__color) == rgb(Style.GOLD) end
    assertTrue(gold(u.marksIcons), "the mode shown is gold")
    assertFalse(gold(u.marksTicks))
    u.marksTicks:__fire("OnClick")
    assertEqual(i.NS.db.profile.results.timelineMarks, "tick", "written through the seam")
    assertEqual(TL.Marks()[1].kind, "tick")
    assertTrue(gold(u.marksTicks))
    assertFalse(gold(u.marksIcons))
    u.marksIcons:__fire("OnClick")
    assertEqual(TL.Marks()[1].kind, "icon")
end)

-- ── the zoom and the grip ───────────────────────────────────────────────────────────────────────

test("timeline marks: zoomed in, the icons follow the zoomed axis; a drag of the grip moves them without re-pooling", function()
    local i, u = opened()
    local NS, TL = i.NS, i.TL
    TL.ZoomBy(1)
    local zoom = TL.Zoom()
    local _, laneX, laneW = TL.LaneGeometry(u.width)
    for _, d in ipairs(TL.Marks()) do assertEqual(d.x, laneX + TL.MarkX(d.cast.t, 60, zoom * laneW)) end
    local frames = {}
    for n, d in ipairs(TL.Marks()) do frames[n] = d.frame end
    local churn = 0
    local release = NS.Pool.ReleaseAll
    rawset(NS.Pool, "ReleaseAll", function(pool, ...)
        churn = churn + 1
        return release(pool, ...)
    end)
    u.frame.resizeGrip:__fire("OnMouseDown", "LeftButton")
    for k = 1, 5 do
        i.mocks.__now = i.mocks.__now + FRAME
        u.frame:__fire("OnSizeChanged", 1000 + 20 * k, 560)
    end
    rawset(NS.Pool, "ReleaseAll", release)
    assertEqual(churn, 0, "nothing re-pooled while the grip is held")
    _, laneX, laneW = TL.LaneGeometry(u.width)
    for n, d in ipairs(TL.Marks()) do
        assertTrue(d.frame == frames[n], "the same frame")
        assertEqual(d.x, laneX + TL.MarkX(d.cast.t, 60, zoom * laneW))
        assertEqual(last(d.frame)[4], d.x - laneX + TL.CLIP_PAD)
    end
    u.frame.resizeGrip:__fire("OnMouseUp")
end)
