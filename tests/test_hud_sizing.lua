-- tests/test_hud_sizing.lua — the Race HUD's size model (the v0.2 sizing model, Combat Trail's plan
-- decisions D2 and D9, its task E1 and Review focus 3): `hud.sizeMode` "fixed" (the default) derives
-- the window's height from `hud.bars` and the configured parts, never from the spell count or the body
-- on screen; the grip (fixed mode only, hidden while locked) sets the width and rounds the height to a
-- whole number of rows, then stores `hud.bars` (1-15); "auto" grows the window with the rows up to
-- `hud.bars` and then scrolls, keeping the top (`hud.grow` "down", the default) or the bottom ("up") in
-- place. The rows scroll with the wheel whenever there are more spells than rows, in both modes and on
-- both the running body and the result card. Every size read here is one the code set (the widget
-- recorder's __width / __height), never a measurement of a value-bearing region.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local METER_EVENT = "DAMAGE_METER_COMBAT_SESSION_UPDATED"

--- A race fixture with the widget recorder; the clock at 100.
local function hud(opts)
    opts = opts or {}
    local f = RaceClock.new{ mutate = function(m)
        Widgets.install(m)
        if opts.mutate then opts.mutate(m) end
    end }
    f.Hud = f.NS.Hud
    for path, v in pairs(opts.set or {}) do assertTrue(f.NS.SetByPath(path, v), path) end
    return f
end

local function ui(f) return assert(f.Hud.__ui(), "the HUD window was never built") end
local function frame(f) return ui(f).frame end
local function body(f, key) local u = ui(f) return u.body[key or u.current] end

-- The chrome over and under the content (the 30px title bar + 10, the 20px footer + 8), the running
-- body's stack at the defaults (the clocks and the KPIs, 106; the Damage profile block with the pace
-- line and the plot with its icon row, 159; the Spell breakdown heading, 28; the caption and Cancel,
-- 42), the idle body's floor (Arm Race at 220, 24 tall, its refusal line and the links: 286) and the
-- rows' 20px pitch (18px rows, 2px apart).
local CHROME = 40 + 28
local RUN_TOP, PROFILE, HEADING, RUN_BOTTOM = 106, 6 + 22 + 16 + 80 + 13 + 2 + 12 + 8, 28, 42
local PACE_ONLY = 6 + 22 + 16 + 8
local BASE = 220 + 24 + 4 + 14 + 4 + 20
local function rowsH(n) return n > 0 and n * 20 - 2 or 0 end
local function fixedFor(n, profile)
    return CHROME + math.max(BASE, RUN_TOP + (profile or PROFILE) + HEADING + rowsH(n) + RUN_BOTTOM)
end

local function session(n)
    local s = { damage = 9000000, dps = 300000, duration = 30, spells = {} }
    for i = 1, n do s.spells[i] = { id = 2000 + i, dmg = 1000000 - i, dps = 1000 } end
    return s
end

--- A 0.5 s stretch at 16 meter updates a second with a countdown tick on each.
local function pump(f, seconds)
    for _ = 1, math.floor((seconds or 0.5) * 16 + 0.5) do
        f:advance(1 / 16)
        f.M.__fire(METER_EVENT, 0, 25)
        f.Hud.Tick()
    end
end

--- The HUD shown and a 30 s race running from 100 on session 25 with `n` spells (in combat, secret).
local function racing(f, n)
    f.Hud.Show()
    assertTrue(f:arm(30))
    f:start(25)
    f.meter.SetSession(25, session(n))
    f.meter.SetSecret(true)
    pump(f)
    assertEqual(ui(f).current, "running")
end

--- The run read and shown with `n` plain spells on its record.
local function resolved(f, n)
    racing(f, 3)
    f:to(129.5)
    f:update(25)
    f:to(130)
    f:advance(1)
    f:update(25)
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
    local run = f.Race.Current()
    run.spells = {}
    for i = 1, n do run.spells[i] = { id = 2000 + i, dmg = 100000 - i, dps = 1 } end
    f.Hud.Refresh()
    return run
end

-- A best on the board, so the pace bar shows too: the running body's tallest stack.
local function seedBest(f)
    local best = f.NS.Recorder.NewRun(30)
    best.status, best.result, best.date = "complete", { damage = 9000000, dps = 300000 }, 1
    f.NS.Recorder.Save(best)
end

local function count(f, key) return body(f, key).w.list:Count() end
local function firstName(f, key) return T.reveal(body(f, key).w.list.rows[1].name.__text) end
local function name(f, i) return T.reveal(f.NS.HudBreakdown.SpellName(2000 + i)) end
local function wheel(f, delta, key) body(f, key).w.rows:__fire("OnMouseWheel", delta) end

--- The grip dragged to `w` x `h` and released (the library reads the released size off the frame).
local function gripTo(f, w, h)
    local fr = frame(f)
    fr.resizeGrip:__fire("OnMouseDown", "LeftButton")
    f.M.__now = f.M.__now + 1 / 60
    fr:__fire("OnSizeChanged", w, h)
    rawset(fr, "GetWidth", function() return w end)
    rawset(fr, "GetHeight", function() return h end)
    fr.resizeGrip:__fire("OnMouseUp")
end

-- The shell frame's own edges, armed for the anchor read (the only geometry the HUD reads back).
local function edges(fr, left, top, bottom)
    rawset(fr, "GetLeft", function() return left end)
    rawset(fr, "GetTop", function() return top end)
    rawset(fr, "GetBottom", function() return bottom end)
end

local function anchor(fr) return fr.__points and fr.__points[1] end

-- ── the defaults and the rows ───────────────────────────────────────────────────────────────────

test("hud sizing: the defaults are fixed, 5 rows, grow down; live.rows and the stored height are retired", function()
    local f = hud()
    local NS = f.NS
    local d = NS.defaults.profile
    assertEqual(d.hud.sizeMode, "fixed")
    assertEqual(d.hud.bars, 5)
    assertEqual(d.hud.grow, "down")
    assertNil(d.live.rows, "live.rows retired into hud.bars")
    assertNil(d.windows.hud.height, "the height is derived, never stored")
    assertNil(NS.FindSchemaRow("live.rows"))
    local bars = NS.FindSchemaRow("hud.bars")
    assertTrue(bars ~= nil, "the Spell rows shown row")
    assertEqual(bars.min, 1)
    assertEqual(bars.max, 15)
    assertEqual(NS.Hud.MIN_BARS, 1)
    assertEqual(NS.Hud.MAX_BARS, 15)
    assertEqual(NS.Hud.MAX_WIDTH, 600)
    local mode, grow = NS.FindSchemaRow("hud.sizeMode"), NS.FindSchemaRow("hud.grow")
    assertTrue(mode ~= nil and grow ~= nil, "the Window size and Grow rows")
    assertTrue(mode.validate("fixed") and mode.validate("auto") and not mode.validate("big"))
    assertTrue(grow.validate("down") and grow.validate("up") and not grow.validate("left"))
    assertEqual(type(grow.disabledIf), "function")
    assertTrue(grow.disabledIf(grow), "Grow is drawn disabled in fixed mode")
    assertTrue(NS.SetByPath("hud.sizeMode", "auto"))
    assertFalse(grow.disabledIf(grow), "and live in auto mode")
end)

test("hud sizing: the migration drops the retired live.rows and stored height", function()
    local step
    for _, s in ipairs(T.NS.__migrationSteps) do if s.to == 12 then step = s end end
    assertTrue(step ~= nil and step.perProfile == true, "a per-profile step 12")
    local p = { live = { rows = 0, icons = false }, windows = { hud = { width = 300, height = 700, point = "TOP" } } }
    step.run({}, p)
    assertNil(p.live.rows)
    assertEqual(p.live.icons, false, "the other leaves stay")
    assertNil(p.windows.hud.height)
    assertEqual(p.windows.hud.width, 300)
    assertEqual(p.windows.hud.point, "TOP")
    step.run({}, {})   -- a profile with neither
end)

-- ── fixed mode ──────────────────────────────────────────────────────────────────────────────────

test("hud sizing: the fixed height is derived from the rows, the same with 0, 3 or 20 spells", function()
    local heights = {}
    for _, n in ipairs({ 0, 3, 20 }) do
        local f = hud()
        racing(f, n)
        local fr = frame(f)
        assertEqual(fr.__height, fixedFor(5), n .. " spells: the stack for 5 rows")
        assertEqual(fr.__height, f.Hud.FixedHeight())
        assertEqual(fr.__width, 260)
        assertEqual(count(f), math.min(n, 5), n .. " spells: at most 5 rows")
        heights[#heights + 1] = fr.__height
    end
    assertEqual(heights[1], heights[2])
    assertEqual(heights[2], heights[3])
end)

test("hud sizing: a fixed window keeps its height from the idle body through the race to the result", function()
    local f = hud()
    f.Hud.Show()
    local fr = frame(f)
    assertEqual(ui(f).current, "idle")
    assertEqual(fr.__height, fixedFor(5))
    assertTrue(f:arm(30))
    assertEqual(ui(f).current, "armed")
    assertEqual(fr.__height, fixedFor(5))
    f:start(25)
    f.meter.SetSession(25, session(9))
    f.meter.SetSecret(true)
    pump(f)
    assertEqual(fr.__height, fixedFor(5))
    f:to(129.5)
    f:update(25)
    f:to(130)
    f:advance(1)
    f:update(25)
    f:combatEnd()
    f:advance(3)
    assertEqual(ui(f).current, "result")
    assertEqual(fr.__height, fixedFor(5), "the result card in the same window")
end)

test("hud sizing: the running body with a best, a chart and every row fills the fixed window exactly", function()
    local f = hud()
    seedBest(f)
    racing(f, 9)
    local b = body(f)
    assertTrue(b.w.chart.shown, "the chart is up")
    assertTrue(b.w.pace.bar:IsShown(), "the pace bar is up")
    assertEqual(count(f), 5)
    assertEqual(frame(f).__height, CHROME + b.needH, "no blank space and no overflow")
    assertTrue(f.NS.SetByPath("hud.bars", 3))
    pump(f)
    assertEqual(count(f), 3)
    assertEqual(frame(f).__height, fixedFor(3))
    assertEqual(frame(f).__height, CHROME + b.needH)
end)

test("hud sizing: the chart and the pace bar switched off shrink the fixed height, never under the idle body", function()
    local f = hud()
    racing(f, 9)
    assertTrue(f.NS.SetByPath("live.chart", false))
    assertEqual(frame(f).__height, fixedFor(5, PACE_ONLY))
    assertEqual(count(f), 5, "the rows stay")
    assertTrue(f.NS.SetByPath("hud.bars", 1))
    pump(f)
    assertEqual(frame(f).__height, CHROME + BASE, "the idle body's floor holds")
    assertEqual(count(f), 1, "one row, and room to spare")
    assertTrue(f.NS.SetByPath("live.paceBar", false))
    assertEqual(frame(f).__height, CHROME + BASE)
end)

test("hud sizing: spells arriving mid-race keep the fixed height and the rows", function()
    local f = hud()
    racing(f, 2)
    local h = frame(f).__height
    assertEqual(count(f), 2)
    f.meter.SetSession(25, session(14))
    pump(f)
    assertEqual(count(f), 5)
    assertEqual(frame(f).__height, h)
    assertEqual(body(f).w.count.__text, "1-5 of 14")
end)

test("hud sizing: the result card fits the fixed window, its rows the bars and the wheel past them", function()
    local f = hud()
    resolved(f, 12)
    assertEqual(frame(f).__height, fixedFor(5))
    assertEqual(count(f), 5)
    local b = body(f)
    assertEqual(b.w.count.__text, "1-5 of 12")
    wheel(f, -1)
    assertEqual(b.offset, 1)
    assertEqual(firstName(f), name(f, 2))
    for _ = 1, 30 do wheel(f, -1) end
    assertEqual(b.offset, 7, "held at the last full window")
    assertEqual(b.w.count.__text, "8-12 of 12")
    for _ = 1, 30 do wheel(f, 1) end
    assertEqual(b.offset, 0)
    assertEqual(firstName(f), name(f, 1))
end)

test("hud sizing: the result card with every spell in view shows no count", function()
    local f = hud()
    resolved(f, 4)
    assertEqual(count(f), 4)
    assertEqual(body(f).w.count.__text, "")
    wheel(f, -3)
    assertEqual(body(f).offset, 0)
end)

-- The one place a fixed window's content height binds the rows (the E1 review): the result card's
-- chips wrapping to a third line (and more) at a narrow width push the stack down past the room the
-- fixed height reserves for two lines (RESULT_ROWS_TOP). Then rowsFor shows fewer rows than the bars,
-- the wheel moving over the rest, and roomForRows sets the chart aside before it leaves no row; the
-- window's height never moves. The chips' lines are forced here (their wrap is a width estimate).
local function chipLines(b, n)
    local chips = b.w.chips
    local real = chips.Set
    rawset(chips, "Set", function(self, ...) real(self, ...); self.lines = n end)
end

test("hud sizing: chips wrapping past two lines cut the result card's rows to what the fixed window holds", function()
    local f = hud()
    resolved(f, 12)
    local h = frame(f).__height
    local b = body(f)
    assertEqual(count(f), 5)
    assertEqual(b.w.count.__text, "1-5 of 12")
    chipLines(b, 4)
    f.Hud.Refresh()
    assertEqual(frame(f).__height, h, "the fixed height holds")
    assertTrue(b.w.chart.shown, "the chart still leaves a row")
    assertEqual(count(f), 4, "one row fewer than the bars")
    assertEqual(b.w.count.__text, "1-4 of 12")
    assertTrue(b.needH <= b.fitH, "the rows end inside the content")
    chipLines(b, 6)
    f.Hud.Refresh()
    assertEqual(count(f), 2)
    assertEqual(b.w.count.__text, "1-2 of 12")
    assertTrue(b.needH <= b.fitH)
    wheel(f, -1)
    assertEqual(b.offset, 1, "the wheel moves over the rest")
    assertEqual(firstName(f), name(f, 2))
    assertEqual(frame(f).__height, h)
end)

test("hud sizing: chips that leave no row under the chart set the chart aside in the fixed window", function()
    local f = hud()
    resolved(f, 12)
    local h = frame(f).__height
    local b = body(f)
    chipLines(b, 8)
    f.Hud.Refresh()
    assertFalse(b.w.chart.shown, "the plot steps aside")
    assertTrue(count(f) >= 1, "and the rows take its room")
    assertTrue(b.needH <= b.fitH)
    assertEqual(frame(f).__height, h)
end)

test("hud sizing: fewer bars with wrapped chips set the chart aside on the same draw", function()
    -- roomForRows reads the new view's fitH, not the one before it: the bars and fitH land on the body
    -- before the chart's room is asked.
    local f = hud()
    resolved(f, 12)
    local b = body(f)
    chipLines(b, 6)
    f.Hud.Refresh()
    assertTrue(b.w.chart.shown, "two rows under the chart at 5 bars")
    assertTrue(f.NS.SetByPath("hud.bars", 1))
    assertFalse(b.w.chart.shown, "the smaller window has no room for the plot and a row")
    assertTrue(count(f) >= 1, "a row shows")
    assertTrue(b.needH <= b.fitH)
end)

-- ── the grip ────────────────────────────────────────────────────────────────────────────────────

test("hud sizing: a grip release stores the width and the rounded rows, and the height snaps", function()
    local f = hud()
    racing(f, 20)
    local NS, fr = f.NS, frame(f)
    assertTrue(fr.resizeGrip ~= nil, "the HUD has the library's grip")
    assertTrue(fr.resizeGrip:IsShown())
    local base = fixedFor(0)   -- the stack with no row
    gripTo(f, 333.4, base + 7 * 20 + 9)   -- seven and a half rows
    assertEqual(NS.db.profile.hud.bars, 7, "the height rounded down to whole rows")
    assertEqual(NS.db.profile.windows.hud.width, 333)
    assertEqual(fr.__height, fixedFor(7), "snapped to the seven rows")
    assertEqual(fr.__width, 333)
    pump(f)
    assertEqual(count(f), 7)
    gripTo(f, 100, 40)
    assertEqual(NS.db.profile.hud.bars, 1, "a drag shorter than one row keeps one")
    assertEqual(NS.db.profile.windows.hud.width, NS.Hud.MIN_WIDTH, "never under the minimum width")
    pump(f)
    assertEqual(count(f), 1)
    gripTo(f, 2000, 5000)
    assertEqual(NS.db.profile.hud.bars, 15, "a window taller than 15 rows stores 15")
    assertEqual(NS.db.profile.windows.hud.width, NS.Hud.MAX_WIDTH)
    pump(f)
    assertEqual(count(f), 15)
    assertEqual(fr.__height, fixedFor(15))
end)

test("hud sizing: a height-only release that rounds back to the same rows still snaps the window", function()
    local f = hud()
    racing(f, 20)
    local NS, fr = f.NS, frame(f)
    local h = fixedFor(5) + 9   -- under one more row: still five
    fr.resizeGrip:__fire("OnMouseDown", "LeftButton")
    f.M.__now = f.M.__now + 1 / 60
    fr.__width, fr.__height = 260, h   -- the client sizes the frame while the grip is held
    fr:__fire("OnSizeChanged", 260, h)
    rawset(fr, "GetWidth", function() return 260 end)
    rawset(fr, "GetHeight", function() return h end)
    fr.resizeGrip:__fire("OnMouseUp")
    assertEqual(NS.db.profile.hud.bars, 5, "the count is unchanged")
    assertEqual(fr.__height, fixedFor(5), "snapped back to the five rows' height")
end)

test("hud sizing: a release that only moved the width keeps the rows, where the idle floor is the height", function()
    local f = hud({ set = { ["live.chart"] = false, ["hud.bars"] = 1 } })
    f.Hud.Show()
    assertEqual(frame(f).__height, CHROME + BASE, "one row under the idle body's floor")
    gripTo(f, 300, CHROME + BASE)
    assertEqual(f.NS.db.profile.hud.bars, 1, "the height the window had keeps its count")
    assertEqual(f.NS.db.profile.windows.hud.width, 300)
end)

test("hud sizing: while the grip is held the rows follow the drag and nothing is stored", function()
    local f = hud()
    racing(f, 20)
    local NS, fr = f.NS, frame(f)
    local writes = {}
    local set = NS.SetByPath
    NS.SetByPath = function(path, ...) writes[#writes + 1] = path; return set(path, ...) end
    local sets = 0
    local setSize = rawget(fr, "SetSize")
    rawset(fr, "SetSize", function(self, w, h) sets = sets + 1; return setSize(self, w, h) end)
    local reads = f:reads()
    fr.resizeGrip:__fire("OnMouseDown", "LeftButton")
    f.M.__now = f.M.__now + 1 / 60
    fr:__fire("OnSizeChanged", 300, fixedFor(9))
    assertEqual(count(f), 9, "nine rows fit the dragged height")
    assertEqual(f:reads(), reads, "the drag reads no meter")
    assertEqual(table.concat(writes, ","), "", "stored only on release")
    assertEqual(sets, 0, "the drag owns the size: no SetSize while it is held")
    rawset(fr, "GetWidth", function() return 300 end)
    rawset(fr, "GetHeight", function() return fixedFor(9) end)
    fr.resizeGrip:__fire("OnMouseUp")
    NS.SetByPath = set
    assertEqual(table.concat(writes, ","), "hud.bars", "the release stores the rows through the seam")
    assertEqual(NS.db.profile.hud.bars, 9)
    assertEqual(NS.db.profile.windows.hud.width, 300)
    assertTrue(sets >= 1, "the release snaps the window")
end)

test("hud sizing: the grip's bounds follow the parts shown", function()
    local f = hud()
    racing(f, 3)
    local fr = frame(f)
    rawset(fr, "SetResizeBounds", function(self, ...) self.__bounds = { ... } end)
    f.Hud.Refresh()
    local b = fr.__bounds
    assertEqual(b[1], 260)
    assertEqual(b[2], fixedFor(1), "one row at the least")
    assertEqual(b[3], 600)
    assertEqual(b[4], fixedFor(15), "fifteen at the most")
    assertTrue(f.NS.SetByPath("live.chart", false))
    assertEqual(fr.__bounds[4], fixedFor(15, PACE_ONLY))
end)

test("hud sizing: the grip is hidden while locked and in auto mode, and refuses a drag", function()
    local f = hud()
    racing(f, 8)
    local NS, fr = f.NS, frame(f)
    local grip = fr.resizeGrip
    assertTrue(NS.SetByPath("locked", true))
    assertFalse(grip:IsShown(), "hidden while locked")
    grip:__fire("OnMouseDown", "LeftButton")
    assertFalse(NS.Sizing.IsSizing(fr), "a locked HUD refuses the drag")
    grip:__fire("OnMouseUp")
    assertTrue(NS.SetByPath("locked", false))
    assertTrue(grip:IsShown())
    assertTrue(NS.SetByPath("hud.sizeMode", "auto"))
    assertFalse(grip:IsShown(), "auto mode sizes itself")
    grip:__fire("OnMouseDown", "LeftButton")
    assertFalse(NS.Sizing.IsSizing(fr))
    grip:__fire("OnMouseUp")
    assertTrue(NS.SetByPath("hud.sizeMode", "fixed"))
    assertTrue(grip:IsShown())
end)

-- ── the scroll ──────────────────────────────────────────────────────────────────────────────────

test("hud sizing: the wheel scrolls the live rows, clamped, and the count names them", function()
    local f = hud()
    racing(f, 12)
    local b = body(f)
    assertEqual(count(f), 5)
    assertEqual(firstName(f), name(f, 1))
    assertEqual(b.w.count.__text, "1-5 of 12")
    wheel(f, -1)
    assertEqual(b.offset, 1)
    assertEqual(firstName(f), name(f, 2))
    assertEqual(b.w.count.__text, "2-6 of 12")
    for _ = 1, 20 do wheel(f, -1) end
    assertEqual(b.offset, 7, "held at the last full window")
    assertEqual(firstName(f), name(f, 8))
    assertEqual(count(f), 5)
    assertEqual(b.w.count.__text, "8-12 of 12")
    pump(f)
    assertEqual(b.offset, 7, "a live read keeps the place")
    for _ = 1, 50 do wheel(f, 1) end
    assertEqual(b.offset, 0, "never above the first")
    assertEqual(firstName(f), name(f, 1))
end)

test("hud sizing: with every spell in view there is no scroll", function()
    local f = hud()
    racing(f, 4)
    assertEqual(count(f), 4)
    assertEqual(body(f).w.count.__text, "5 rows")
    wheel(f, -3)
    assertEqual(body(f).offset, 0)
end)

test("hud sizing: zero spells draws no row and keeps the HUD drawable in both modes", function()
    local f = hud()
    racing(f, 0)
    assertEqual(count(f), 0)
    wheel(f, -1)
    assertEqual(body(f).offset, 0)
    assertTrue(f.NS.SetByPath("hud.sizeMode", "auto"))
    local need = body(f).needH
    assertEqual(need, RUN_TOP + PROFILE - 16 + HEADING + RUN_BOTTOM, "the stack with no row (no best: no pace line)")
    assertEqual(frame(f).__height, CHROME + need)
    f.Race.Cancel()
    assertEqual(ui(f).current, "idle")
    assertEqual(frame(f).__height, CHROME + BASE, "the idle body's floor")
end)

test("hud sizing: a new race starts its rows at the top", function()
    local f = hud()
    resolved(f, 12)
    for _ = 1, 4 do wheel(f, -1) end
    assertEqual(body(f).offset, 4)
    f.Hud.Act.newRace()
    assertTrue(f:arm(30))
    f:start(26)
    f.meter.SetSession(26, session(12))
    f.meter.SetSecret(true)
    pump(f)
    assertEqual(body(f).offset, 0)
    assertEqual(firstName(f), name(f, 1))
    f.Race.Cancel()
end)

-- ── auto mode ───────────────────────────────────────────────────────────────────────────────────

test("hud sizing: auto mode grows with the rows up to the bars, then scrolls", function()
    local heights = {}
    for _, n in ipairs({ 3, 5, 12 }) do
        local f = hud({ set = { ["hud.sizeMode"] = "auto" } })
        seedBest(f)
        racing(f, n)
        local b = body(f)
        assertEqual(count(f), math.min(n, 5))
        assertEqual(frame(f).__height, CHROME + b.needH, "the window is the stack")
        heights[n] = frame(f).__height
    end
    assertEqual(heights[5] - heights[3], 2 * 20, "two more rows, two more pitches")
    assertEqual(heights[12], heights[5], "past the bars it scrolls instead of growing")
end)

test("hud sizing: auto mode grows as spells arrive mid-race", function()
    local f = hud({ set = { ["hud.sizeMode"] = "auto" } })
    seedBest(f)
    racing(f, 2)
    local h2 = frame(f).__height
    f.meter.SetSession(25, session(4))
    pump(f)
    assertEqual(count(f), 4)
    assertEqual(frame(f).__height, h2 + 2 * 20)
end)

test("hud sizing: grow down keeps the top in place, grow up the bottom", function()
    local f = hud({ set = { ["hud.sizeMode"] = "auto" } })
    racing(f, 2)
    local NS, fr, u = f.NS, frame(f), ui(f)
    edges(fr, 400.4, 700.6, 300.2)
    u.drag:__fire("OnDragStop")
    local w = NS.db.profile.windows.hud
    assertEqual(w.point, "TOPLEFT", "grow down: the top edge is the anchor")
    assertEqual(w.relativePoint, "BOTTOMLEFT")
    assertEqual(w.x, 400)
    assertEqual(w.y, 701)
    assertEqual(anchor(fr)[1], "TOPLEFT")
    assertTrue(NS.SetByPath("hud.grow", "up"))
    assertEqual(w.point, "BOTTOMLEFT", "grow up: the bottom edge is the anchor")
    assertEqual(w.relativePoint, "BOTTOMLEFT")
    assertEqual(w.y, 300)
    assertEqual(anchor(fr)[1], "BOTTOMLEFT")
    assertEqual(anchor(fr)[5], 300)
    local before = fr.__height
    f.meter.SetSession(25, session(5))
    pump(f)
    assertTrue(fr.__height ~= before, "the window grew")
    assertEqual(anchor(fr)[1], "BOTTOMLEFT", "and kept its bottom")
    assertEqual(anchor(fr)[5], 300)
end)

test("hud sizing: a stored point that already suits the grow edge is kept, and a fixed window keeps its own", function()
    local f = hud()
    racing(f, 2)
    local NS, fr = f.NS, frame(f)
    edges(fr, 10, 20, 5)
    f.Hud.Refresh()
    assertNil(NS.db.profile.windows.hud.point, "a fixed window keeps the default point, unstored")
    local w = NS.db.profile.windows.hud
    w.point, w.relativePoint, w.x, w.y = "TOPRIGHT", "TOPRIGHT", -60, -160
    assertTrue(NS.SetByPath("hud.sizeMode", "auto"))
    assertEqual(w.point, "TOPRIGHT", "already on the top edge")
    assertEqual(w.x, -60)
end)

test("hud sizing: a fixed window's title-bar drag stores the client's point, its grip release the top edge", function()
    local f = hud()
    racing(f, 2)
    local NS, fr, u = f.NS, frame(f), ui(f)
    rawset(fr, "GetPoint", function() return "CENTER", nil, "CENTER", 12.4, -30.6 end)
    edges(fr, 400.4, 700.6, 300.2)
    u.drag:__fire("OnDragStop")
    local w = NS.db.profile.windows.hud
    assertEqual(w.point, "CENTER")
    assertEqual(w.x, 12)
    gripTo(f, 300, f.Hud.FixedHeight())
    assertEqual(w.point, "TOPLEFT", "the snap keeps the top")
    assertEqual(w.relativePoint, "BOTTOMLEFT")
    assertEqual(w.x, 400)
    assertEqual(w.y, 701)
end)

test("hud sizing: switching the mode mid-race redraws without error", function()
    local f = hud()
    racing(f, 12)
    local fr = frame(f)
    local fixed = fr.__height
    assertTrue(f.NS.SetByPath("hud.sizeMode", "auto"))
    assertEqual(fr.__height, CHROME + body(f).needH)
    assertEqual(count(f), 5)
    pump(f)
    assertTrue(f.NS.SetByPath("hud.sizeMode", "fixed"))
    assertEqual(fr.__height, fixed)
    assertEqual(count(f), 5)
end)

test("hud sizing: grow up chosen before the window is built takes the bottom edge at its first show", function()
    -- The window's own frame answers its edges from the moment it is made.
    local f = hud({ set = { ["hud.sizeMode"] = "auto", ["hud.grow"] = "up" }, mutate = function(m)
        local make = m.CreateFrame
        m.CreateFrame = function(kind, frameName, ...)
            local fr = make(kind, frameName, ...)
            if frameName == "DpsRaceHud" then edges(fr, 400.4, 700.6, 300.2) end
            return fr
        end
    end })
    assertTrue(f.Hud.Frame() == nil, "the window is built on first show")
    f.Hud.Show()
    local fr = frame(f)
    local w = f.NS.db.profile.windows.hud
    assertEqual(w.point, "BOTTOMLEFT", "the stored point moved onto the grow edge")
    assertEqual(w.relativePoint, "BOTTOMLEFT")
    assertEqual(w.y, 300)
    assertEqual(anchor(fr)[1], "BOTTOMLEFT")
end)

test("hud sizing: the diagnostics name the mode, the rows and the height", function()
    local f = hud()
    f.Hud.Show()
    local d = f.Hud.Diagnose()
    assertEqual(d.mode, "fixed")
    assertEqual(d.bars, 5)
    assertEqual(d.height, fixedFor(5))
end)
