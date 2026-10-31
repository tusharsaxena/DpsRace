-- tests/test_hud_layout.lua — the Race HUD's bodies at every size and the result card (modules/Hud.lua,
-- modules/Hud_States.lua, spec §6.1): which rows fit, the buttons, Stop Now and Delete, the chips, New Race
-- and Share. Peeled out of tests/test_hud.lua (layout-§1); the helpers are that suite's.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local METER_EVENT = "DAMAGE_METER_COMBAT_SESSION_UPDATED"

--- A race fixture with the widget recorder; the clock at 100.
local function hud(opts)
    opts = opts or {}
    local W
    local f = RaceClock.new{ enable = opts.enable, mutate = function(m)
        W = Widgets.install(m)
        if opts.mutate then opts.mutate(m) end
    end }
    f.W, f.Hud = W, f.NS.Hud
    return f
end

local function ui(f) return assert(f.Hud.__ui(), "the HUD window was never built") end
local function current(f) return ui(f).current end
local function body(f) local u = ui(f) return u.body[u.current] end

--- One OnUpdate pass of the countdown driver (what the client runs at 20 Hz).
local function tick(f) f.Hud.Tick() end

--- Armed, the clock running from 100 with session 25 (in combat, the meter secret).
local function running(f, length)
    assertTrue(f:arm(length or 30))
    f:start(25)
    assertEqual(f.Race.State(), "running")
end

--- The run read and shown: armed 30s, running, a tail update, the buzzer, combat over, read.
local function resolved(f)
    running(f, 30)
    f:to(129.5)
    f:update(25)
    f:to(130)
    f:advance(1)
    f:update(25)
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
    return f.Race.Current()
end

--- Drive 2.5s of running at 16 meter updates a second with a countdown tick on each.
local function pump(f, seconds)
    local steps = math.floor(seconds * 16 + 0.5)
    for _ = 1, steps do
        f:advance(1 / 16)
        f.M.__fire(METER_EVENT, 0, 25)
        tick(f)
    end
end

-- ── layout at every size ────────────────────────────────────────────────────────────────────────

-- The window's chrome above and below the content (title bar + gap, footer + gap) and each body's
-- fixed stack around its spell rows, as laid out in modules/Hud.lua and modules/Hud_States.lua.
-- The 30px title bar + 10, the 20px footer + 8; 18px rows on a 20px pitch; 20px buttons.
local CHROME, PITCH = 40 + 28, 20
-- The rows' top: the KPIs (and the chips), then the Spell breakdown heading (Round C): its 22px line
-- and the 6px that, with the GAP above, makes the shared 14px of clear space.
local BREAKDOWN = 6 + 22
local RUNNING_TOP, RUNNING_BOTTOM = 106 + BREAKDOWN, 42
local RESULT_TOP, RESULT_BOTTOM = 80 + BREAKDOWN, 28   -- under one chip line (Chips:Bottom)

local function fits(height, top, bottom)
    return math.floor((height - CHROME - top - bottom + 2) / PITCH)
end

local function session(n)
    local s = { damage = 9000000, dps = 300000, duration = 30, spells = {} }
    for i = 1, n do s.spells[i] = { id = 2000 + i, dmg = 1000000 - i, dps = 1000 } end
    return s
end

test("hud: the live rows stop above the caption and CANCEL at every window height", function()
    for _, height in ipairs({ 0, 360, 460, 700 }) do
        local f = hud()
        local h = math.max(height, f.Hud.MIN_HEIGHT)
        f.NS.db.profile.windows.hud.height = h
        f.NS.db.profile.live.rows = 15
        -- The rows alone: the chart's own share of the stack has its own case (Damage chart, below).
        f.NS.db.profile.live.chart = false
        f.Hud.Show()
        running(f, 30)
        f.meter.SetSession(25, session(15))
        f.meter.SetSecret(true)
        pump(f, 0.5)
        local want = math.min(15, fits(h, RUNNING_TOP, RUNNING_BOTTOM))
        assertTrue(want >= 3, "the minimum height leaves room for " .. want .. " rows")
        assertEqual(body(f).w.list:Count(), want, "rows drawn at height " .. h)
        assertEqual(body(f).w.count.__text, ("%d rows"):format(want))
    end
end)

test("hud: live rows 0 shows every spell that fits and the wheel scrolls through the rest", function()
    local f = hud()
    local h = f.Hud.MIN_HEIGHT
    f.NS.db.profile.windows.hud.height = h
    f.NS.db.profile.live.rows = 0
    f.Hud.Show()
    running(f, 30)
    f.meter.SetSession(25, session(20))
    f.meter.SetSecret(true)
    pump(f, 0.5)
    local b = body(f)
    local cap = fits(h, RUNNING_TOP, RUNNING_BOTTOM)
    assertEqual(b.w.list:Count(), cap, "as many rows as fit")
    assertEqual(b.w.count.__text, ("1-%d of 20"):format(cap))
    assertEqual(T.reveal(b.w.list.rows[1].name.__text), T.reveal(f.NS.HudBreakdown.SpellName(2001)))
    b.w.rows:__fire("OnMouseWheel", -1)       -- down: one row further
    assertEqual(b.w.count.__text, ("2-%d of 20"):format(cap + 1))
    for _ = 1, 40 do b.w.rows:__fire("OnMouseWheel", -1) end
    assertEqual(b.w.count.__text, ("%d-20 of 20"):format(20 - cap + 1), "clamped at the end")
    for _ = 1, 40 do b.w.rows:__fire("OnMouseWheel", 1) end
    assertEqual(b.w.count.__text, ("1-%d of 20"):format(cap), "clamped at the top")
    -- A set count never scrolls.
    f.NS.db.profile.live.rows = 3
    pump(f, 0.5)
    b.w.rows:__fire("OnMouseWheel", -1)
    assertEqual(b.w.count.__text, "3 rows")
end)

test("hud: the default window size shows every default live row under the chart and the pace bar", function()
    local f = hud()
    assertEqual(f.NS.defaults.profile.windows.hud.height, 573,
        "screen 04's rows plus the headings, the chart (its icon row too, UT-P11) and the pace bar (#2, #3, Round C)")
    assertEqual(f.NS.db.profile.live.rows, 8)
    -- A best on the board, so the pace bar shows too: the tallest default stack.
    local best = f.NS.Recorder.NewRun(30)
    best.status, best.result = "complete", { damage = 9000000, dps = 300000 }
    best.date = 1
    f.NS.Recorder.Save(best)
    f.Hud.Show()
    assertEqual(f.Hud.Diagnose().height, 573)
    running(f, 30)
    f.meter.SetSession(25, session(15))
    f.meter.SetSecret(true)
    pump(f, 0.5)
    local b = body(f)
    assertTrue(b.w.chart.shown, "the chart is up")
    assertTrue(b.w.pace.bar:IsShown(), "the pace bar is up")
    assertEqual(b.w.list:Count(), 8, "all 8 rows fit at 260x573")
end)

test("hud: the result card's rows stop above its buttons at every window height", function()
    for _, height in ipairs({ 0, 360 }) do
        local f = hud()
        local h = math.max(height, f.Hud.MIN_HEIGHT)
        f.NS.db.profile.windows.hud.height = h
        local run = resolved(f)
        run.spells = {}
        for i = 1, 8 do run.spells[i] = { id = 2000 + i, dmg = 100000 - i, dps = 1 } end
        f.Hud.Refresh()
        local want = math.min(f.NS.db.profile.live.rows, fits(h, RESULT_TOP, RESULT_BOTTOM))
        assertTrue(want >= 3)
        assertEqual(body(f).w.list:Count(), want, "rows drawn at height " .. h)
    end
end)

test("hud: the result card follows Spell rows shown; at 0 it lists every spell and scrolls", function()
    local f = hud()
    f.NS.db.profile.windows.hud.height = 700
    f.NS.db.profile.live.rows = 3
    f.NS.db.profile.live.chart = false   -- the rows alone; the card's chart has its own case
    local run = resolved(f)
    run.spells = {}
    for i = 1, 40 do run.spells[i] = { id = 2000 + i, dmg = 100000 - i, dps = 1 } end
    f.Hud.Refresh()
    local b = body(f)
    assertEqual(b.w.list:Count(), 3, "the set count")
    f.NS.db.profile.live.rows = 0
    f.Hud.Refresh()
    local cap = fits(700, RESULT_TOP, RESULT_BOTTOM)
    assertTrue(cap > 5 and cap < 40)
    assertEqual(b.w.list:Count(), cap, "as many as fit, not the top 5")
    b.w.rows:__fire("OnMouseWheel", -1)
    assertEqual(T.reveal(b.w.list.rows[1].name.__text), T.reveal(f.NS.HudBreakdown.SpellName(2002)), "one row down")
    for _ = 1, 60 do b.w.rows:__fire("OnMouseWheel", -1) end
    assertEqual(b.w.list:Count(), cap)
    assertEqual(T.reveal(b.w.list.rows[cap].name.__text), T.reveal(f.NS.HudBreakdown.SpellName(2040)), "clamped at the last spell")
end)

test("hud: the minimum height holds the idle body's whole stack", function()
    local f = hud()
    -- Arm Race at 162 and 24 tall, its refusal line (4 + 14), then 4 and the 20px links.
    local States = f.NS.HudStates
    assertEqual(States.IDLE_ARM_Y, 162)
    assertEqual(States.ARM_HEIGHT, 24)
    assertTrue(f.Hud.MIN_HEIGHT - CHROME >= 162 + 24 + 4 + 14 + 4 + 20, "Arm Race meets the links")
    assertEqual(f.Hud.MIN_HEIGHT, 354, "the minimum height, re-derived for the headings (Round C)")
    assertEqual(f.Hud.MIN_HEIGHT - CHROME, f.NS.HudStates.MinContentHeight())
    f.NS.db.profile.windows.hud.height = 200
    f.Hud.Show()
    assertEqual(f.Hud.Diagnose().height, f.Hud.MIN_HEIGHT, "a stored height below the minimum is used as is")
end)

-- A HUD whose frames record their SetSize and SetPoint calls (the widget recorder keeps neither size).
local function sizedHud()
    return hud{ mutate = function(m)
        local base = m.CreateFrame
        m.CreateFrame = function(...)
            local fr = base(...)
            rawset(fr, "SetSize", function(self, w, h) self.__size = { w, h } end)
            rawset(fr, "ClearAllPoints", function(self) self.__pts = {} end)
            rawset(fr, "SetPoint", function(self, point, rel, relPoint, x, y)
                self.__pts = self.__pts or {}
                self.__pts[#self.__pts + 1] = { point, rel, relPoint, x, y }
            end)
            return fr
        end
    end }
end

test("hud: the equal buttons' width is whole pixels from the body's width and the gap", function()
    local f = hud()
    local States = f.NS.HudStates
    assertEqual(States.ROW_GAP, 4)
    local each, x0 = States.RowWidths(236, 4)
    assertEqual(each, 56, "four at the minimum width: room for New Race")
    assertTrue(#f.NS.L["New Race"] * 6 <= each, "New Race fits at the 6 px a character estimate")
    assertEqual(x0, 0)
    each, x0 = States.RowWidths(239, 4)
    assertEqual(each, 56)
    assertEqual(x0, 1, "the odd pixels split either side")
    each = States.RowWidths(236, 2)
    assertEqual(each, 116)
end)

test("hud: the result card's four buttons sit in one row, the same width each, at any width", function()
    local f = sizedHud()
    f.Hud.Show()
    resolved(f)
    local b = body(f)
    local w = b.w
    local order = { w.newRace, w.details, w.share, w.delete }
    assertEqual(w.delete.label.__text, "Delete")
    for _, width in ipairs({ 236, 300 }) do
        b:Layout(width, 400)
        local each = f.NS.HudStates.RowWidths(width, 4)
        local lastX
        for i, btn in ipairs(order) do
            assertEqual(btn.__size[1], each, "button " .. i .. " is not the row's width at " .. width)
            local p = btn.__pts[1]
            assertEqual(p[1], "BOTTOMLEFT")
            if lastX then assertEqual(p[4] - lastX, each + 4, "the gap between buttons " .. (i - 1) .. " and " .. i) end
            lastX = p[4]
        end
        assertTrue(lastX + each <= width, "the row overruns the card")
    end
end)

test("hud: Cancel on the waiting body throws the attempt away", function()
    local f = hud()
    running(f, 30)
    local id = f.Race.Current().id
    f:to(140)
    tick(f)
    assertEqual(current(f), "waiting")
    assertEqual(body(f).w.cancel.label.__text, "Cancel")
    body(f).w.cancel:__fire("OnClick")
    assertEqual(f.Race.State(), "idle")
    assertEqual(f:stored(id), nil)
end)

test("hud: the Stop! and waiting bodies carry Stop Now and Cancel, the same width, with tooltips", function()
    local f = sizedHud()
    f.Hud.Show()
    running(f, 30)
    f:to(129.9)
    f:update(25)
    f:to(130)
    assertEqual(current(f), "stop")
    for _, key in ipairs({ "stop", "waiting" }) do
        if key == "waiting" then
            f:advance(3)
            tick(f)
        end
        assertEqual(current(f), key)
        local b = body(f)
        b:Layout(236, 300)
        assertEqual(b.w.stopNow.label.__text, "Stop Now")
        assertEqual(b.w.cancel.label.__text, "Cancel")
        assertEqual(b.w.stopNow.__size[1], b.w.cancel.__size[1], key .. ": not the same width")
        assertEqual(b.w.stopNow.__size[1], 116)
        assertTrue(b.w.stopNow.tip ~= nil and b.w.cancel.tip ~= nil, key .. ": a button without its tooltip")
        assertTrue(b.w.stopNow:IsEnabled())
    end
end)

test("hud: Stop Now out of combat takes the result at once, without the quiet", function()
    local f = hud()
    f.Hud.Show()
    running(f, 30)
    f:to(130)
    f:combatEnd()
    f:advance(0.5)
    assertEqual(f.Race.State(), "stopping", "the quiet still counting")
    body(f).w.stopNow:__fire("OnClick")
    assertEqual(f.Race.State(), "result")
    assertEqual(current(f), "result")
    assertEqual(f.Race.Current().status, "complete")
end)

test("hud: Stop Now in combat reads at the combat end and says so", function()
    local f = hud()
    f.Hud.Show()
    running(f, 30)
    f:to(140)
    tick(f)
    assertEqual(current(f), "waiting")
    body(f).w.stopNow:__fire("OnClick")
    assertEqual(f.Race.State(), "stopping", "nothing can be read in combat")
    assertEqual(body(f).w.title.__text, "Reading when combat ends")
    assertFalse(body(f).w.stopNow:IsEnabled(), "pressed once is enough")
    f:combatEnd()
    assertEqual(f.Race.State(), "result", "read on the regen edge, no quiet after it")
end)

test("hud: Delete on the result card asks first, deletes through the store and goes back to Arm Race", function()
    local popups = {}
    local f = hud{ mutate = function(m)
        m.StaticPopup_Show = function(which, _, _, data) popups[#popups + 1] = { which = which, data = data } end
    end }
    f.Hud.Show()
    local run = resolved(f)
    local b = body(f)
    assertTrue(b.w.delete:IsEnabled())
    b.w.delete:__fire("OnClick")
    assertEqual(#popups, 1)
    assertEqual(popups[1].which, "DPSRACE_DELETE_RUN", "the Results window's own confirmation")
    assertTrue(f.NS.Recorder.Get(run.id) ~= nil, "nothing is deleted before the confirmation")
    assertEqual(current(f), "result")
    f.M.StaticPopupDialogs.DPSRACE_DELETE_RUN.OnAccept(nil, popups[1].data)
    assertEqual(f.NS.Recorder.Get(run.id), nil, "deleted from the store")
    assertEqual(f.Race.State(), "idle")
    assertEqual(current(f), "idle", "back on the Arm Race screen")
    assertTrue(f.Hud.IsShown(), "the window stays open")
    local picked
    for _, p in ipairs(body(f).w.presets) do if p.selected then picked = p.length end end
    assertEqual(picked, 30, "the same length is picked")
end)

test("hud: a result card whose run is deleted in the Results window is dismissed", function()
    local f = hud()
    f.Hud.Show()
    local run = resolved(f)
    f.NS.Recorder.Delete(run.id)
    assertEqual(f.Race.State(), "idle")
    -- Another run deleted leaves the card alone.
    local g = hud()
    g.Hud.Show()
    resolved(g)
    g.NS.Recorder.Delete("no-such-run")
    g.NS.SendBus(g.NS.MSG.RUNS_CHANGED)
    assertEqual(g.Race.State(), "result")
end)

test("hud: a canceled card Delete leaves a later Results-window delete of that run an outside one", function()
    local popups = {}
    local f = hud{ mutate = function(m)
        m.StaticPopup_Show = function(which, _, _, data) popups[#popups + 1] = { which = which, data = data } end
    end }
    -- onArm (the default): the arm opens the window, so the race going back to idle closes it.
    local run = resolved(f)
    assertTrue(f.Hud.IsShown())
    body(f).w.delete:__fire("OnClick")
    assertEqual(#popups, 1)
    -- The popup is canceled (its Accept never runs); the run is then deleted in the Results window.
    f.NS.Results.DeleteRun(run.id)
    assertEqual(f.NS.Recorder.Get(run.id), nil)
    assertEqual(f.Race.State(), "idle", "the card is dismissed")
    assertFalse(f.Hud.IsShown(), "dismissed as any outside delete: the onArm HUD closes with the race")
end)

test("hud: the card's Delete accepted after the card has gone leaves no mark behind", function()
    local popups = {}
    local f = hud{ mutate = function(m)
        m.StaticPopup_Show = function(which, _, _, data) popups[#popups + 1] = { which = which, data = data } end
    end }
    f.Hud.Show()
    local first = resolved(f)
    body(f).w.delete:__fire("OnClick")
    f.Race.Cancel()
    f.M.StaticPopupDialogs.DPSRACE_DELETE_RUN.OnAccept(nil, popups[1].data)
    assertEqual(f.NS.Recorder.Get(first.id), nil, "the accepted delete still deletes")
    assertEqual(f.Race.State(), "idle")
end)

test("hud: result body shows % and the best delta chip", function()
    local f = hud()
    -- An earlier best on the same board (spec 267 · other · 30s), 80% of this run's DPS.
    local prior = RaceClock.storedRun({ id = "1000-1", status = "complete", date = 1000 })
    prior.char = { name = "Testchar", specID = 267 }
    prior.result = { damage = 1, dps = (RaceClock.SESSION.damage / 30) * 0.8 }
    f.NS.db.global.runs[prior.id] = prior
    local run = resolved(f)
    assertEqual(current(f), "result")
    local b = body(f)
    assertEqual(b.w.damage.value.__text, "1.53M")
    assertEqual(b.w.dps.value.__text, "51.3K")
    local chips = b.w.chips:Texts()
    assertEqual(chips[1], "New best +25.0%")
    assertEqual(chips[#chips], ("Time 0:30 +%.1fs"):format(run.result.tail))
    local rows = b.w.list.rows
    assertEqual(#rows, 3)
    assertEqual(rows[1].name.__text, "Incinerate")
    assertEqual(rows[1].pct.__text, ("%.1f%%"):format(482113 / RaceClock.SESSION.damage * 100))
    assertTrue(rows[1].pct:IsShown())
end)

test("hud: a first run is a new best; a slower one shows its deficit and its flags", function()
    local f = hud()
    resolved(f)
    assertEqual(body(f).w.chips:Texts()[1], "New best")

    local g = hud()
    local prior = RaceClock.storedRun({ id = "1000-1", status = "complete", date = 1000 })
    prior.char = { name = "Testchar", specID = 267 }
    prior.result = { damage = 1, dps = (RaceClock.SESSION.damage / 30) * 1.25 }
    g.NS.db.global.runs[prior.id] = prior
    running(g, 30)
    g:to(131.5)
    g.Race.OnCast("start", 29722, g:now(), "Cast-9")
    g:update(25)
    g:combatEnd()
    g:advance(3)
    local chips = body(g).w.chips:Texts()
    assertEqual(chips[1], "-20.0% vs best")
    assertEqual(chips[2], "1 late cast")
end)

-- The chip drawn now whose text starts with `prefix`, or nil.
local function chipNamed(b, prefix)
    for _, chip in ipairs(b.w.chips.shown) do
        if chip.text:sub(1, #prefix) == prefix then return chip end
    end
end

test("hud: a late-cast chip's right-click ignores its spell, and the gray ignored chip's undoes it (#8)", function()
    local f = hud()
    running(f, 30)
    f:to(131.5)
    f.Race.OnCast("start", 29722, f:now(), "Cast-9")
    f:update(25)
    f:combatEnd()
    f:advance(3)
    local chip = assert(chipNamed(body(f), "1 late cast"))
    assertTrue(type(chip.menu) == "function")
    chip:__fire("OnMouseUp", "RightButton")
    local menu = f.M.__lastMenu
    assertEqual(menu.titles[1], "Late casts")
    menu:Click("Ignore Incinerate for late casts")
    assertTrue(f.NS.LateIgnore.IsIgnored(29722))
    -- SETTINGS_CHANGED redrew the card: no flag chip, a gray one in its place that keeps the undo.
    assertNil(chipNamed(body(f), "1 late cast"))
    local gray = assert(chipNamed(body(f), "1 ignored"))
    gray:__fire("OnMouseUp", "RightButton")
    f.M.__lastMenu:Click("Stop ignoring Incinerate")
    assertFalse(f.NS.LateIgnore.IsIgnored(29722))
    assertTrue(chipNamed(body(f), "1 late cast") ~= nil)
    -- A pooled chip takes the menu of the item it draws now, none included.
    for _, c in ipairs(body(f).w.chips.shown) do
        if c.text ~= "1 late cast" then assertNil(c.menu, c.text) end
    end
    local before = #f.M.__menus
    chipNamed(body(f), "New best"):__fire("OnMouseUp", "RightButton")
    assertEqual(#f.M.__menus, before, "a chip with no menu opens none")
end)

test("hud: a lost result says it could not be read", function()
    local f = hud()
    running(f, 30)
    f.Race.OnMeterReset()
    assertEqual(f.Race.State(), "result")
    local b = body(f)
    assertEqual(b.w.lost.__text, "Couldn't read the result")
    assertEqual(b.w.damage.value.__text, "\226\128\148")
    assertEqual(b.w.list:Count(), 0)
    local chips = b.w.chips:Texts()
    assertEqual(chips[#chips], "Lost")
end)

test("hud: an incomplete run's chip names when combat ended, or that the player died", function()
    local f = hud()
    running(f, 30)
    f:to(110)
    f:combatEnd()
    f:advance(3)
    local chips = body(f).w.chips:Texts()
    assertEqual(chips[1], "Incomplete (combat ended at 0:10)")

    local g = hud()
    running(g, 30)
    g:to(112)
    g.Race.OnDeath(g:now())
    g:combatEnd()
    g:advance(3)
    chips = body(g).w.chips:Texts()
    assertEqual(chips[1], "Incomplete: died")
    assertEqual(chips[2], "Time 0:12 / 0:30", "the time in combat against the length")
    assertEqual(#chips, 2, "died is not shown twice")
end)

test("hud: New Race opens the Arm Race screen on the same length; Details and Share reach their modules", function()
    local f = hud()
    local run = resolved(f)
    local opened, shared
    f.NS.Results.ShowRun = function(id) opened = id end
    f.NS.Share = { Prompt = function(r) shared = r end }
    f.Hud.Refresh()
    local b = body(f)
    assertTrue(b.w.share:IsEnabled())
    b.w.details:__fire("OnClick")
    assertEqual(opened, run.id)
    b.w.share:__fire("OnClick")
    assertTrue(shared == run)
    b.w.newRace:__fire("OnClick")
    assertEqual(f.Race.State(), "idle", "New Race opens the Arm Race screen, it does not arm")
    assertEqual(current(f), "idle")
    assertTrue(f.Hud.IsShown(), "the window stays open")
    assertTrue(f.NS.Recorder.Get(run.id) ~= nil, "the run is kept")
    local idle = body(f).w
    local picked
    for _, p in ipairs(idle.presets) do if p.selected then picked = p.length end end
    assertEqual(picked, 30, "the same length is picked")
    idle.arm:__fire("OnClick")
    assertEqual(f.Race.State(), "armed")
    assertEqual(f.Race.Current().race.length, 30)
end)

test("hud: Share is live on a result card, and grayed without a Share module", function()
    local f = hud()
    resolved(f)
    assertTrue(body(f).w.share:IsEnabled())
    f.NS.Share = nil
    f.Hud.Refresh()
    assertFalse(body(f).w.share:IsEnabled())
end)

test("hud: closing a result card dismisses it and keeps the run", function()
    local f = hud()
    local run = resolved(f)
    local frame = ui(f).frame
    frame:Hide()
    frame:__fire("OnHide")          -- Escape, through UISpecialFrames
    assertEqual(f.Race.State(), "idle")
    assertFalse(f.Hud.wanted)
    assertTrue(f:stored(run.id) ~= nil, "the run left history")
end)
