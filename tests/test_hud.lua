-- tests/test_hud.lua — the Race HUD (modules/Hud*.lua, spec §6.1): which body shows for each race
-- state, the idle Arm refusal, the live breakdown under secret values (no %, no sort, no geometry
-- read), the result card's % and best delta, the sticky-combat hint, the countdown cue and the
-- buzzer, the live-read throttle and when it stops, and the window's lock, scale, position and close.
--
-- Every case runs on the race fixture (tests/race_clock.lua: the scripted meter, the fake clock that
-- fires timers at their own GetTime()) with the widget recorder (tests/mock_widgets.lua) installed,
-- so a label's text, a bar's values and every geometry read can be asserted.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
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

local function liveReads(f) return #f.meter.CallsTo("GetCombatSessionSourceFromType") end

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

-- ── bodies ──────────────────────────────────────────────────────────────────────────────────────

test("hud: switches body on RACE_STATE_CHANGED for all six states", function()
    local f = hud()
    f.Hud.Show()
    assertEqual(current(f), "idle")
    running(f, 30)
    assertEqual(current(f), "running")
    f:to(129.9)
    f:update(25)
    f:to(130)
    assertEqual(f.Race.State(), "stopping")
    assertEqual(current(f), "stop", "just after the buzzer, damage may still land")
    f:advance(3)
    tick(f)
    assertEqual(current(f), "waiting", "the tail went quiet and combat holds")
    f:combatEnd()
    f:advance(3)
    assertEqual(current(f), "result")
    local seen = {}
    for _, s in ipairs(f.heard.states) do seen[#seen + 1] = s.to end
    assertEqual(table.concat(seen, ","), "armed,running,stopping,result")

    local g = hud()
    g.Hud.Show()
    assertTrue(g:arm(45))
    assertEqual(current(g), "armed")
    assertEqual(body(g).w.clock.__text, "0:45.0", "the length, unmoving")
end)

test("hud: a run that ended before the buzzer waits for its read on the waiting body", function()
    local f = hud()
    running(f, 30)
    f:to(110)
    f.M.__inCombat = false
    f.Race.OnCombatEnd(f:now())
    assertEqual(f.Race.State(), "stopping")
    assertEqual(current(f), "waiting")
    assertEqual(body(f).w.title.__text, "Reading the result")
    assertEqual(body(f).w.tail.label.__text, "Combat Ended")
end)

test("hud: idle arm button disabled with reason in combat", function()
    local f = hud()
    f.Hud.Show()
    local b = body(f)
    assertTrue(b.w.arm:IsEnabled(), "out of combat Arm is live")
    assertEqual(b.w.reason.__text, "")
    f.M.__inCombat = true
    f.M.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(b.w.arm:IsEnabled(), "Arm stayed live in combat")
    assertEqual(b.w.reason.__text, "Leave combat to arm")
    f.M.__inCombat = false
    f.M.__fire("PLAYER_REGEN_ENABLED")
    assertTrue(b.w.arm:IsEnabled(), "the regen edge did not re-enable Arm")

    f.meter.SetAvailable(false, "Not in this zone")
    f.Hud.Refresh()
    assertFalse(b.w.arm:IsEnabled())
    assertTrue(b.w.reason.__text:find("Not in this zone", 1, true) ~= nil, "Blizzard's reason is shown")
end)

test("hud: idle Arm uses the picked length and target count; a refusal prints its line", function()
    local f = hud()
    f.M.__setTarget({ guid = "Creature-0-1-2-3-243208-0001", name = "Cleave Training Dummy" })
    f.Hud.Show()
    local b = body(f)
    assertEqual(b.w.card.npc.__text, "#243208")
    assertEqual(b.w.card.badgeText.__text, "Cleave")
    f.Hud.Act.pickLength(60)
    f.Hud.Act.stepCount(1)
    f.Hud.Act.stepCount(1)
    assertEqual(b.w.card.count.__text, "3")
    assertTrue(f.Hud.Act.arm())
    local run = f.Race.Current()
    assertEqual(run.race.length, 60)
    assertEqual(run.target.count, 3)
    assertEqual(f.NS.db.profile.race.lastLength, 60, "the last choice is remembered")

    f.M.__resetPrinted()
    assertFalse(f.Hud.Act.arm(), "a second arm while armed")
    local lines = f.M.__printed()
    assertTrue(lines[#lines]:find("already armed", 1, true) ~= nil)
end)

test("hud: a custom length is parsed, range-checked and selected", function()
    local f = hud()
    f.Hud.Show()
    f.Hud.Act.openCustom()
    assertTrue(body(f).w.customBox:IsShown())
    assertTrue(f.Hud.Act.customLength("1:30"))
    assertEqual(f.NS.db.profile.race.lastLength, 90)
    assertEqual(body(f).w.custom.label.__text, "1:30", "the Custom button shows the picked length")
    assertFalse(body(f).w.customBox:IsShown())
    f.M.__resetPrinted()
    assertFalse(f.Hud.Act.customLength("5"))
    assertFalse(f.Hud.Act.customLength("16:00"))
    assertEqual(#f.M.__printed(), 2)
end)

test("hud: an unknown target is allowed and said so", function()
    local f = hud()
    f.M.__setTarget({ guid = "Creature-0-1-2-3-99999-0001", name = "Angry Boar" })
    f.Hud.Show()
    assertTrue(body(f).w.warn.__text:find("Other: Angry Boar", 1, true) ~= nil)
    f.M.__setTarget(nil)
    f.M.__fire("PLAYER_TARGET_CHANGED")
    assertTrue(body(f).w.warn.__text:find("No target", 1, true) ~= nil)
    assertEqual(body(f).w.card.name.__text, "No target")
end)

test("hud: a changed Default race length takes effect over the remembered pick", function()
    local f = hud()
    f.Hud.Show()
    f.Hud.Act.pickLength(60)
    assertEqual(f.Hud.View().length, 60)
    assertTrue(f.NS.SetByPath("race.defaultLength", 300))
    assertEqual(f.NS.db.profile.race.lastLength, nil, "the remembered pick outlived the new default")
    assertEqual(f.Hud.View().length, 300)
    local selected
    for _, b in ipairs(body(f).w.presets) do if b.selected then selected = b.length end end
    assertEqual(selected, 300, "the idle body still selects the old length")
    assertTrue(f.NS.ToggleArm())
    assertEqual(f.Race.Current().race.length, 300)
end)

test("hud: with no stored answer it falls back to defaults/Profile.lua, never a literal of its own", function()
    local f = hud()
    local D = f.NS.defaults.profile
    D.race.defaultLength, D.live.hz, D.live.rows = 120, 6, 5
    f.NS.GetSetting = function() return nil end      -- a degraded load: the store cannot answer
    local v = f.Hud.View()
    assertEqual(v.length, 120, "a second default for race.defaultLength")
    assertEqual(v.hz, 6, "a second default for live.hz")
    assertEqual(v.rows, 5, "a second default for live.rows")
end)

local CLEAVE = { guid = "Creature-0-1-2-3-243208-0001", name = "Cleave Training Dummy" }
local BOAR = { guid = "Creature-0-1-2-3-99999-0001", name = "Angry Boar" }

test("hud: a target changed while the HUD is closed is never armed with the old count", function()
    local f = hud()
    f.M.__setTarget(CLEAVE)
    f.Hud.Show()
    for _ = 1, 4 do f.Hud.Act.stepCount(1) end
    assertEqual(body(f).w.card.count.__text, "5")
    f.Hud.Hide()
    f.M.__setTarget(BOAR)
    f.M.__fire("PLAYER_TARGET_CHANGED")       -- nobody listens while the window is closed
    assertTrue(f.NS.ToggleArm())
    assertEqual(f.Race.Current().target.count, 1, "the stepped count of the old target was armed")
    assertEqual(f.Race.Current().target.name, "Angry Boar")
end)

test("hud: reopening the HUD offers the target of the moment, not the one cached at close", function()
    local f = hud()
    f.M.__setTarget(CLEAVE)
    f.Hud.Show()
    for _ = 1, 4 do f.Hud.Act.stepCount(1) end
    f.Hud.Hide()
    f.M.__setTarget(BOAR)
    f.M.__fire("PLAYER_TARGET_CHANGED")
    f.Hud.Show()
    assertEqual(body(f).w.card.name.__text, "Angry Boar")
    assertEqual(body(f).w.card.count.__text, "1")
    assertTrue(f.Hud.Act.arm())
    assertEqual(f.Race.Current().target.count, 1)
end)

-- ── the live breakdown ──────────────────────────────────────────────────────────────────────────

--- Drive 2.5s of running at 16 meter updates a second with a countdown tick on each.
local function pump(f, seconds)
    local steps = math.floor(seconds * 16 + 0.5)
    for _ = 1, steps do
        f:advance(1 / 16)
        f.M.__fire(METER_EVENT, 0, 25)
        tick(f)
    end
end

test("hud: running render raises nothing with secret values", function()
    local f = hud()
    running(f, 30)
    assertTrue(f.meter.secret, "the fixture's meter is secret in combat")
    local before = liveReads(f)
    pump(f, 2.5)
    local reads = liveReads(f) - before
    assertTrue(reads >= 10 and reads <= 11, "4 Hz for 2.5s, got " .. reads)
    local b = body(f)
    assertEqual(T.reveal(b.w.damage.value.__text), "1.53M")
    assertEqual(T.reveal(b.w.dps.value.__text), "39.4K", "Blizzard's live figure")
    assertEqual(b.w.list:Count(), 3)
    local row = b.w.list.rows[1]
    assertTrue(T.isSecret(row.bar.__value), "the bar was handed the secret itself")
    assertTrue(T.isSecret(row.bar.__max), "the bar's range is the secret maxAmount")
    assertEqual(T.reveal(row.name.__text), "Incinerate")
    assertEqual(T.reveal(row.icon.__texture), 1000 + 29722)
end)

test("hud: running body shows no percentage text", function()
    local f = hud()
    running(f, 30)
    pump(f, 0.5)
    local b = body(f)
    assertTrue(b.w.list:Count() > 0)
    for _, row in ipairs(b.w.list.rows) do
        assertEqual(row.pct.__text, "", "a live row shows a %")
        assertFalse(row.pct:IsShown(), "the % column is drawn while running")
        assertFalse(tostring(T.reveal(row.amount.__text)):find("%", 1, true) ~= nil)
    end
end)

test("hud: live rows keep Blizzard's order and the configured count", function()
    local f = hud()
    f.NS.db.profile.live.rows = 2
    assertTrue(f:arm(30))
    f.M.__inCombat = true
    f.meter.SetSession(25, { damage = 900, dps = 30, duration = 5, spells = {
        { id = 348, dmg = 100, dps = 1 }, { id = 29722, dmg = 500, dps = 1 }, { id = 17962, dmg = 300, dps = 1 },
    } })
    f.meter.SetSecret(true)
    f.Race.OnCombatStart(f:now())
    f.Race.OnSessionCreated(f:now())
    pump(f, 0.5)
    local rows = body(f).w.list.rows
    assertEqual(#rows, 2)
    assertEqual(T.reveal(rows[1].name.__text), "Immolate", "unsorted: the order the meter gave")
    assertEqual(T.reveal(rows[2].name.__text), "Incinerate")
    assertEqual(body(f).w.count.__text, "2 rows")
end)

test("hud: a live read with no DPS figure shows a dash", function()
    local f = hud()
    running(f, 30)
    f.NS.Meter.ReadLive = function()
        return { total = T.secret(5000), spells = { { spellID = T.secret(348), total = T.secret(5000) } } }
    end
    pump(f, 0.5)
    local b = body(f)
    assertEqual(b.w.dps.value.__text, "\226\128\148")
    assertTrue(T.isSecret(b.w.list.rows[1].bar.__max), "no maxAmount: the first row's total is the range")
end)

test("hud: the live DPS KPI shows a figure when the source carries no amountPerSecond (live client)", function()
    local f = hud()
    assertTrue(f:arm(30))
    f.M.__inCombat = true
    local data = {}
    for k, v in pairs(RaceClock.SESSION) do data[k] = v end
    data.sourceDps, data.localFlagPlain = false, true
    data.others = { { guid = "Player-1-00000002", damage = 9000000, dps = 90000 } }
    f.meter.SetSession(25, data)
    f.meter.SetSecret(true)
    f.Race.OnCombatStart(f:now())
    f.Race.OnSessionCreated(f:now())
    local ok, err = pcall(pump, f, 1)
    assertTrue(ok, "a forbidden operation on a secret: " .. tostring(err))
    local b = body(f)
    assertEqual(T.reveal(b.w.dps.value.__text), "39.4K", "the local row's figure, not a dash")
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("hud: layout never calls GetWidth/GetPoint on breakdown rows", function()
    local f = hud()
    running(f, 30)
    pump(f, 0.25)
    for i = #f.W.geomReads, 1, -1 do f.W.geomReads[i] = nil end
    pump(f, 2.5)
    f:to(130)
    tick(f)
    assertEqual(#f.W.geomReads, 0, "a geometry read while drawing live values")
    local onSecret = f.W.SecretGeometryReads()
    assertEqual(#onSecret, 0, "geometry read on a frame holding a secret: " .. table.concat(onSecret, ","))
end)

test("hud: live reads stop when hud hidden or state leaves running", function()
    local f = hud()
    running(f, 30)
    pump(f, 1)
    local shown = liveReads(f)
    assertTrue(shown > 0)
    f.Hud.Hide()
    assertFalse(ui(f).frame:IsShown())
    pump(f, 2)
    assertEqual(liveReads(f), shown, "read while hidden")
    assertEqual(#f.M.__timers() >= 0, true)
    f.Hud.Show()
    pump(f, 1)
    assertTrue(liveReads(f) > shown, "showing again did not resume the reads")
    f:to(130)
    assertEqual(f.Race.State(), "stopping")
    local again = liveReads(f)
    pump(f, 2)
    assertEqual(liveReads(f), again, "read after the buzzer")
    for _, r in ipairs(f.M.__registrations()) do
        assertFalse(r.event == METER_EVENT and r.target ~= f.NS.Watchers.EventTarget(), "the HUD still listens to the meter")
    end
end)

-- ── stop, waiting, result ───────────────────────────────────────────────────────────────────────

test("hud: the stop body shows the live tail, time in combat, late casts and the grace", function()
    local f = hud()
    running(f, 30)
    f:to(130)
    f:advance(1.4)
    f:update(25)
    f.Race.OnCast("start", 29722, f:now(), "Cast-1")
    tick(f)
    local b = body(f)
    assertEqual(current(f), "stop")
    assertEqual(b.w.tail.value.__text, "+1.4")
    assertEqual(b.w.tail.unit.__text, "s after buzzer")
    assertEqual(b.w.combat.value.__text, "+1.4")
    local chips = b.w.chips:Texts()
    assertEqual(chips[1], "1 late cast \194\183 +1.4s")
    assertEqual(chips[2], "Grace 1.0s")
end)

test("hud: waiting hint appears after hintDelay and names only owned drop-combat spells", function()
    local f = hud()
    f.W.known[5384], f.W.known[58984] = true, true
    running(f, 30)
    f:to(130)
    f:advance(14)
    tick(f)
    assertEqual(current(f), "waiting")
    local b = body(f)
    assertFalse(b.w.hint:IsShown(), "the hint before the delay")
    f:advance(1.5)
    tick(f)
    assertTrue(b.w.hint:IsShown(), "no hint after the delay")
    local text = b.w.hintText.__text
    assertTrue(text:find("Feign Death", 1, true) ~= nil, text)
    assertTrue(text:find("Shadowmeld", 1, true) ~= nil, text)
    assertFalse(text:find("Vanish", 1, true) ~= nil, "named a spell the player does not have")
    assertFalse(text:find("Invisibility", 1, true) ~= nil)
    assertEqual(ui(f).footRight.__text, "result pending")
end)

test("hud: STOPPING redraws at a few Hz, and a steady stop body rebuilds nothing", function()
    local f = hud()
    running(f, 30)
    f:to(130)
    f:advance(0.5)
    f:update(25)
    assertEqual(f.Race.State(), "stopping")
    tick(f)
    assertEqual(current(f), "stop")
    local onUpdate = assert(ui(f).frame:GetScript("OnUpdate"), "no countdown driver in STOPPING")
    local b = body(f)
    local updates, update = 0, b.Update
    b.Update = function(...) updates = updates + 1; return update(...) end
    for _ = 1, 4 do onUpdate(ui(f).frame, 0.05) end
    assertEqual(updates, 0, "STOPPING has no clock: it need not redraw at 20 Hz")
    onUpdate(ui(f).frame, 0.05)
    assertEqual(updates, 1)

    local sets, set = 0, b.w.chips.Set
    b.w.chips.Set = function(...) sets = sets + 1; return set(...) end
    for _ = 1, 10 do tick(f) end
    assertEqual(sets, 0, "the chips were rebuilt with nothing changed")
    f:advance(0.9)
    f:update(25)
    f.Race.OnCast("start", 29722, f:now(), "Cast-1")
    tick(f)
    assertEqual(sets, 1, "a new late cast did not reach the chips")
end)

test("hud: the sticky-combat hint asks for the player's spells once per race", function()
    local f = hud()
    local asked, known = 0, f.M.IsPlayerSpell
    f.M.IsPlayerSpell = function(id) asked = asked + 1; return known(id) end
    running(f, 30)
    f:to(130)
    f:advance(16)
    for _ = 1, 20 do tick(f) end
    assertTrue(body(f).w.hint:IsShown())
    assertEqual(asked, #f.Hud.DROP_COMBAT, "IsPlayerSpell on every tick")
end)

-- ── layout at every size ────────────────────────────────────────────────────────────────────────

-- The window's chrome above and below the content (title bar + gap, footer + gap) and each body's
-- fixed stack around its spell rows, as laid out in modules/Hud.lua and modules/Hud_States.lua.
-- The 30px title bar + 10, the 20px footer + 8; 18px rows on a 20px pitch; 20px buttons.
local CHROME, PITCH = 40 + 28, 20
-- The rows' top: the KPIs (and the chips), then the Spell breakdown heading (Round C): its 22px line
-- and the 6px that, with the GAP above, makes the shared 14px of clear space.
local BREAKDOWN = 6 + 22
local RUNNING_TOP, RUNNING_BOTTOM = 106 + BREAKDOWN, 42
local RESULT_TOP, RESULT_BOTTOM = 104 + BREAKDOWN, 28

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
    assertEqual(f.NS.defaults.profile.windows.hud.height, 560,
        "screen 04's rows plus the headings, the chart and the pace bar (#2, #3, Round C)")
    assertEqual(f.NS.db.profile.live.rows, 8)
    -- A best on the board, so the pace bar shows too: the tallest default stack.
    local best = f.NS.Recorder.NewRun(30)
    best.status, best.result = "complete", { damage = 9000000, dps = 300000 }
    best.date = 1
    f.NS.Recorder.Save(best)
    f.Hud.Show()
    assertEqual(f.Hud.Diagnose().height, 560)
    running(f, 30)
    f.meter.SetSession(25, session(15))
    f.meter.SetSecret(true)
    pump(f, 0.5)
    local b = body(f)
    assertTrue(b.w.chart.shown, "the chart is up")
    assertTrue(b.w.pace.bar:IsShown(), "the pace bar is up")
    assertEqual(b.w.list:Count(), 8, "all 8 rows fit at 300x560")
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

test("hud: the result card's three buttons are chained by anchor, so they never overlap at the minimum width", function()
    local f = hud{ mutate = function(m)
        local base = m.CreateFrame
        m.CreateFrame = function(...)
            local fr = base(...)
            rawset(fr, "ClearAllPoints", function(self) self.__pts = {} end)
            rawset(fr, "SetPoint", function(self, point, rel, relPoint)
                self.__pts = self.__pts or {}
                self.__pts[#self.__pts + 1] = { point, rel, relPoint }
            end)
            return fr
        end
    end }
    resolved(f)
    local w = body(f).w
    local function anchoredTo(b, point, rel, relPoint)
        for _, p in ipairs(b.__pts or {}) do
            if p[1] == point and p[2] == rel and p[3] == relPoint then return true end
        end
        return false
    end
    assertTrue(anchoredTo(w.details, "BOTTOMRIGHT", w.share, "BOTTOMLEFT"), "DETAILS is not left of SHARE")
    assertTrue(anchoredTo(w.again, "BOTTOMRIGHT", w.details, "BOTTOMLEFT"), "RACE AGAIN can run under DETAILS")
end)

test("hud: Discard run on the waiting body throws the attempt away", function()
    local f = hud()
    running(f, 30)
    local id = f.Race.Current().id
    f:to(140)
    tick(f)
    assertEqual(current(f), "waiting")
    body(f).w.discard:__fire("OnClick")
    assertEqual(f.Race.State(), "idle")
    assertEqual(f:stored(id), nil)
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

test("hud: Race again re-arms the same length; Details and Share reach their modules", function()
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
    b.w.again:__fire("OnClick")
    assertEqual(f.Race.State(), "idle", "Race Again opens the Arm Race screen, it does not arm")
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

-- ── cue and buzzer ──────────────────────────────────────────────────────────────────────────────

test("hud: countdown cue plays at 10,5,3,2,1 and buzzer raises the raid warning only when enabled", function()
    local f = hud()
    f.NS.db.profile.race.centerCountdown = false     -- the cue marks alone (tests/test_countdown.lua has both)
    f.Hud.Hide()            -- the cue and the buzzer do not need the window
    running(f, 30)
    f.Hud.Hide()
    f:to(131)
    local cues = f.W.SoundTimes(25477)
    assertEqual(table.concat(cues, ","), "120,125,127,128,129")
    assertEqual(table.concat(f.W.SoundTimes(8959), ","), "130")
    assertEqual(#f.W.notices, 1)
    assertEqual(f.W.notices[1].text, "STOP")

    local g = hud()
    g.NS.db.profile.race.countdownCue = false
    g.NS.db.profile.race.buzzer = false
    running(g, 30)
    g:to(131)
    assertEqual(#g.W.sounds, 0, "a sound played with both switched off")
    assertEqual(#g.W.notices, 0, "the raid warning with the buzzer off")
end)

test("hud: the cue stops when the race is canceled", function()
    local f = hud()
    f.NS.db.profile.race.centerCountdown = false
    running(f, 30)
    f:to(121)
    f.Race.Cancel()
    f:to(131)
    assertEqual(table.concat(f.W.SoundTimes(25477), ","), "120")
end)

test("hud: switching the cue off mid-race silences the marks still ahead", function()
    local f = hud()
    f.NS.db.profile.race.centerCountdown = false
    running(f, 30)
    f:to(121)
    assertTrue(f.NS.SetByPath("race.countdownCue", false))
    f:to(131)
    assertEqual(table.concat(f.W.SoundTimes(25477), ","), "120")
end)

test("hud: a stand-down drops a window onArm opened, so the stand-up does not bring it back", function()
    local f = hud()
    resolved(f)
    assertTrue(f.Hud.IsShown(), "the result opened the HUD")
    assertTrue(f.NS.SetByPath("enabled", false))
    assertTrue(f.NS.SetByPath("enabled", true))
    assertEqual(f.Race.State(), "idle")
    assertFalse(f.Hud.IsShown(), "the stand-up reopened a window for a race that is gone")

    local g = hud()
    g.Hud.Show()
    resolved(g)
    assertTrue(g.NS.SetByPath("enabled", false))
    assertTrue(g.NS.SetByPath("enabled", true))
    assertTrue(g.Hud.IsShown(), "a window the player opened was dropped")
end)

local GREEN, RED = { 0.36, 0.86, 0.46 }, { 1.0, 0.32, 0.32 }

local function colored(fs, c)
    return fs.__color ~= nil and fs.__color[1] == c[1] and fs.__color[2] == c[2] and fs.__color[3] == c[3]
end

test("hud: the running clock shows elapsed in green beside time left in red by default", function()
    local f = hud()
    running(f, 30)
    f:to(112.5)
    tick(f)
    local w = body(f).w
    assertFalse(w.clock:IsShown(), "the single clock beside the pair")
    assertTrue(w.elapsed:IsShown() and w.left:IsShown())
    assertEqual(w.elapsed.__text, "0:12.5")
    assertEqual(w.left.__text, "0:17.5")
    assertTrue(colored(w.elapsed, GREEN), "elapsed is green")
    assertTrue(colored(w.left, RED), "time left is red")
    assertEqual(w.elapsedCap.__text, "Elapsed")
    assertEqual(w.leftCap.__text, "Left")
    f:to(121.04)
    tick(f)
    assertEqual(w.left.__text, "0:08.9")
    assertEqual(w.elapsed.__text, "0:21.0")
    assertEqual(ui(f).footRight.__text, "live \194\183 4 Hz")
end)

test("hud: a single-clock mode shows one big clock in its own color", function()
    local f = hud()
    f.NS.db.profile.hud.clock = "left"
    running(f, 30)
    f:to(115)
    tick(f)
    local w = body(f).w
    assertTrue(w.clock:IsShown())
    assertFalse(w.elapsed:IsShown() or w.left:IsShown() or w.elapsedCap:IsShown() or w.leftCap:IsShown())
    assertEqual(w.clock.__text, "0:15.0")
    assertTrue(colored(w.clock, RED), "time left is red")
    assertTrue(f.NS.SetByPath("hud.clock", "elapsed"))
    f:to(118)
    tick(f)
    assertEqual(w.clock.__text, "0:18.0")
    assertTrue(colored(w.clock, GREEN), "elapsed is green")
end)

test("hud: the clock pair fits the minimum width; the stop body keeps its own STOP", function()
    local f = hud()
    local States = f.NS.HudStates
    -- The longest clock a race can show (m:ss.t at the longest length, "15:00.0"), an advance of
    -- at most 0.62 em per glyph, a gap between the halves.
    local glyphs = #f.NS.Format.Clock(f.NS.Race.MAX_LENGTH)
    assertTrue(glyphs >= 7, "the longest race clock has two minute digits")
    local need = 2 * glyphs * 0.62 * States.CLOCK_PAIR_SIZE + 8
    assertTrue(need <= f.Hud.MIN_WIDTH - 24, "the pair needs " .. need .. " px of the minimum content width")
    running(f, 30)
    f:to(129.9)
    f:update(25)
    f:to(130)
    tick(f)
    assertEqual(current(f), "stop")
    assertEqual(body(f).w.big.__text, "STOP")
end)

-- ── the window ──────────────────────────────────────────────────────────────────────────────────

test("hud: the window is skinned, closable with Escape, resizable and clamped", function()
    local f = hud()
    f.Hud.Show()
    local u = ui(f)
    local found = false
    for _, name in ipairs(f.M.UISpecialFrames) do if name == "DpsRaceHud" then found = true end end
    assertTrue(found, "not in UISpecialFrames")
    assertTrue(u.frame.resizeGrip ~= nil, "no sizing grip")
    assertTrue(u.close ~= nil, "no close control")
    assertTrue(u.frame.innerBorder ~= nil, "the Ka0s window edge was not applied")
    assertEqual(u.frame.title.__text, "DPS Race")
    u.close:__fire("OnClick")
    assertFalse(f.Hud.IsShown())
    assertFalse(u.frame:IsShown())
end)

test("hud: Lock frame, Master scale and Reset position act on the window", function()
    local f = hud()
    f.Hud.Show()
    local u = ui(f)
    assertTrue(f.NS.SetByPath("locked", true))
    assertTrue(f.Hud.locked)
    assertFalse(u.frame.resizeGrip:IsShown(), "the grip shows while locked")
    assertEqual(u.lock.iconName, "lock")
    assertTrue(f.NS.SetByPath("locked", false))
    assertTrue(u.frame.resizeGrip:IsShown())
    assertEqual(u.lock.iconName, "unlock")
    assertTrue(f.NS.SetByPath("scale", 1.5))
    assertEqual(u.frame.__scale, 1.5)

    local w = f.NS.db.profile.windows.hud
    w.point, w.x, w.y, w.width = "TOPLEFT", 40, -60, 420
    f.Hud.ResetPosition()
    assertEqual(w.point, nil)
    assertEqual(w.x, nil)
    assertEqual(w.width, nil)
end)

test("hud: dragging is refused while locked and the position is stored when it ends", function()
    local f = hud()
    f.Hud.Show()
    local u = ui(f)
    local moved = 0
    rawset(u.frame, "StartMoving", function() moved = moved + 1 end)
    rawset(u.frame, "GetPoint", function() return "TOPLEFT", nil, "BOTTOMLEFT", 123.4, 456.6 end)
    f.NS.SetByPath("locked", true)
    u.drag:__fire("OnDragStart")
    assertEqual(moved, 0)
    f.NS.SetByPath("locked", false)
    u.drag:__fire("OnDragStart")
    u.drag:__fire("OnDragStop")
    assertEqual(moved, 1)
    local w = f.NS.db.profile.windows.hud
    assertEqual(w.point, "TOPLEFT")
    assertEqual(w.relativePoint, "BOTTOMLEFT")
    assertEqual(w.x, 123)
    assertEqual(w.y, 457)
end)

test("hud: General visibility and the stand-down hide it at the source", function()
    local f = hud()
    f.Hud.Show()
    assertTrue(ui(f).frame:IsShown())
    assertTrue(f.NS.SetByPath("visibility", "never"))
    assertFalse(f.Hud.IsShown())
    assertFalse(ui(f).frame:IsShown())
    assertTrue(f.NS.SetByPath("visibility", "always"))
    assertTrue(ui(f).frame:IsShown())
end)

test("hud: onArm shows it on arm and hides it when the race it opened for is canceled", function()
    local f = hud()
    assertFalse(f.Hud.IsShown())
    assertTrue(f:arm(30))
    assertTrue(f.Hud.IsShown(), "arming did not show the HUD")
    f.Race.Cancel()
    assertFalse(f.Hud.IsShown(), "onArm left the window up after the cancel")

    f.Hud.Show()
    assertTrue(f:arm(30))
    f.Race.Cancel()
    assertTrue(f.Hud.IsShown(), "a window the player opened was closed for them")
end)

test("hud: showMode always shows it at login", function()
    local f = hud{ enable = false }
    f.NS.db.profile.hud.showMode = "always"
    f:enable()
    assertTrue(f.Hud.IsShown())
    assertTrue(ui(f).frame:IsShown())
end)

test("hud: a race resumed after a /reload shows the HUD under onArm", function()
    for _, case in ipairs({ { now = 110, want = "running" }, { now = 145, want = "stopping" } }) do
        local f = hud{ enable = false }
        f.M.__now, f.M.__inCombat = case.now, true
        f.meter.SetSession(25, RaceClock.SESSION)
        local run = RaceClock.storedRun({ status = "running" })
        f.NS.db.global.runs[run.id] = run
        f:enable()
        assertEqual(f.Race.State(), case.want)
        assertTrue(f.Hud.IsShown(), case.want .. ": the countdown or the wait is hidden after the reload")
        f.Race.Cancel()
        assertFalse(f.Hud.IsShown(), case.want .. ": the window the resume opened outlived its race")
    end
end)

test("hud: a result arriving while the window is closed opens it", function()
    local f = hud()
    running(f, 30)
    f.Hud.Hide()
    f:to(131)
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
    assertTrue(f.Hud.IsShown())
    assertEqual(current(f), "result")
end)

test("hud: Render draws a given body only while test mode is on", function()
    local f = hud()
    f.Hud.Show()
    assertTrue(f.NS.Preview.Start())
    local fake = RaceClock.storedRun({ status = "complete" })
    fake.result = { damage = 2000000, dps = 66666, tail = 2.5 }
    fake.spells = { { id = 348, dmg = 2000000, dps = 1 } }
    f.Hud.Render("result", fake, { isNew = true, delta = 4.2 })
    assertEqual(current(f), "result")
    assertEqual(body(f).w.chips:Texts()[1], "New best +4.2%")
    assertEqual(body(f).w.damage.value.__text, "2.00M")
    f.Hud.Render("running", nil, { timeLeft = 12.3, elapsed = 17.7, live = { total = 1000, dps = 50, spells = {} } })
    assertEqual(current(f), "running")
    assertEqual(body(f).w.left.__text, "0:12.3")
    assertEqual(body(f).w.elapsed.__text, "0:17.7")
    f.NS.Preview.Stop()
    assertEqual(current(f), "idle", "test mode off: back to the race's own state")
end)

test("hud: the stand-down drops every registration, timer and the OnUpdate", function()
    local f = hud()
    running(f, 30)
    pump(f, 0.5)
    assertTrue(#f.M.__timers() > 0)
    assertTrue(f.NS.SetByPath("enabled", false))
    assertEqual(#f.M.__timers(), 0, "a cue, a live read or the OnUpdate survived")
    assertEqual(#f.M.__registrations(), 0)
    assertFalse(ui(f).frame:IsShown())
end)

test("hud: hidden with its parent is not closed by the player", function()
    local f = hud()
    f.Hud.Show()
    local frame = ui(f).frame
    frame:__fire("OnHide")          -- the interface hidden: the frame is still shown in its own right
    assertTrue(f.Hud.wanted, "Alt-Z closed the HUD for good")
end)

test("hud: the library-absent load still draws the HUD without a grip or a close control", function()
    local inst = T.load{ libFiles = {} }
    local NS = inst.NS
    NS.Hud.Show()
    local u = assert(NS.Hud.__ui())
    assertTrue(u.frame:IsShown())
    assertEqual(u.close, nil)
    assertEqual(u.current, "idle")
end)

test("hud: the diagnostics state section names the body, the event set and the countdown driver", function()
    local f = hud()
    running(f, 30)
    local lines = {}
    local out = { add = function(_, _, fmt, ...)
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        lines[#lines + 1] = fmt:format(unpack(args, 1, select("#", ...)))
    end }
    for _, section in ipairs(f.NS.Diagnostics.Sections()) do
        if section[1] == "state" then section[2](out) end
    end
    local found = false
    for _, l in ipairs(lines) do
        if l == "hud body=running events=live ticking=true locked=false" then found = true end
    end
    assertTrue(found, "no hud line; got: " .. table.concat(lines, " | "))
end)
-- ── the collection's look (modules/Style.lua) ─────────────────────────────────────────────────────

-- A run of four or more capitals in a label (texture markup stripped): an ALL-CAPS word. STOP is the
-- one shout the HUD keeps, as big as the clock; DPS is an abbreviation.
local function shouts(s)
    if type(s) ~= "string" then return false end
    s = s:gsub("|T.-|t", "")
    for word in s:gmatch("%u%u%u%u+") do
        if word ~= "STOP" then return true end
    end
    return false
end

local function shouting(W)
    local out = {}
    for _, o in ipairs(W.objects) do
        if shouts(o.__text) then out[#out + 1] = o.__text end
    end
    return out
end

test("hud: labels take the collection's font objects; the clocks and KPI figures stay large", function()
    local f = hud()
    f.Hud.Show()
    local u, F = ui(f), f.NS.Style.FONT
    assertEqual(u.frame.title.__fontObject, "GameFontNormal", "the title")
    assertEqual(F.TITLE, "GameFontNormal")
    assertEqual(u.footLeft.__fontObject, "GameFontDisableSmall", "the footer")
    assertEqual(u.footRight.__fontObject, "GameFontDisableSmall")
    local w = body(f).w
    assertEqual(w.lengthCap.__fontObject, "GameFontNormalSmall", "a section label is a header")
    assertEqual(w.lengthCap.__text, "Race Length")
    assertEqual(w.targetCap.__text, "Target")
    assertEqual(w.presets[1].label.__fontObject, "GameFontHighlightSmall", "a preset button")
    assertEqual(w.results.label.__fontObject, "GameFontHighlightSmall", "a link button")
    assertEqual(w.results.label.__text, "Results")
    assertEqual(w.lastResult, nil, "no Last Result button")
    assertEqual(w.arm.label.__text, "Arm Race")
    assertEqual(w.card.name.__fontObject, "GameFontHighlight", "the target's name")
    assertEqual(w.card.badgeText.__fontObject, "GameFontHighlightSmall")
    running(f, 30)
    f.meter.SetSession(25, session(5))
    f.meter.SetSecret(true)
    pump(f, 0.5)
    w = body(f).w
    assertEqual(w.damage.label.__fontObject, "GameFontDisableSmall", "a KPI caption")
    assertEqual(w.damage.label.__text, "Damage")
    assertEqual(w.dps.label.__text, "DPS \194\183 Live")
    assertEqual(w.damage.value.__fontObject, "GameFontNormalHuge", "a KPI figure stays large")
    assertEqual(w.elapsed.__font.size, f.NS.HudStates.CLOCK_PAIR_SIZE, "the clock pair keeps its size")
    assertEqual(w.clock.__font.size, 40, "the single clock keeps its size")
    assertEqual(w.cancel.label.__text, "Cancel")
    local row = assert(w.list.rows[1], "no live row")
    assertEqual(row.name.__fontObject, "GameFontHighlightSmall", "a spell row")
    assertEqual(row.amount.__fontObject, "GameFontHighlightSmall")
    assertEqual(f.NS.HudBreakdown.ROW_HEIGHT, 18, "LootHistory's compact row")
end)

test("hud: no body shouts in capitals (Title Case labels and buttons, Sentence case prose)", function()
    local f = hud()
    f.Hud.Show()
    running(f, 30)
    f.meter.SetSession(25, session(5))
    pump(f, 0.5)
    f:to(129.9)
    f:update(25)
    f:to(130)
    tick(f)
    assertEqual(current(f), "stop")
    f:advance(3)
    tick(f)
    assertEqual(current(f), "waiting")
    f:combatEnd()
    f:advance(3)
    assertEqual(current(f), "result")
    local loud = shouting(f.W)
    assertEqual(#loud, 0, "ALL CAPS: " .. table.concat(loud, " | "))
    local w = body(f).w
    assertEqual(w.again.label.__text, "Race Again")
    assertEqual(w.details.label.__text, "Details")
    assertEqual(w.share.label.__text, "Share")
end)

test("hud: a title-bar control turns gold under the pointer and back at rest, a late leave included", function()
    local f = hud()
    f.Hud.Show()
    local u = ui(f)
    local GOLD, REST = f.NS.Style.GOLD, f.NS.Style.REST
    local function is(b, c)
        local v = b.icon.__vertex
        return v ~= nil and v[1] == c[1] and v[2] == c[2] and v[3] == c[3] and (v[4] == nil or v[4] == 1)
    end
    local controls = { u.close, u.lock, u.settings, u.results }
    for _, b in ipairs(controls) do assertTrue(is(b, REST), "a control is not at rest") end
    u.results:__fire("OnEnter")
    assertTrue(is(u.results, GOLD), "the hovered control is gold")
    assertTrue(is(u.settings, REST) and is(u.lock, REST) and is(u.close, REST), "only the hovered one")
    assertTrue(f.M.GameTooltip:IsShown(), "the tooltip stays")
    -- The pointer moves to the next control and the old control's leave arrives after its enter.
    u.settings:__fire("OnEnter")
    u.results:__fire("OnLeave")
    assertTrue(is(u.settings, GOLD), "a late leave took the gold off the control under the pointer")
    assertTrue(is(u.results, REST))
    u.settings:__fire("OnLeave")
    for _, b in ipairs(controls) do assertTrue(is(b, REST), "back at rest") end
    -- The close control's own hover (the library's red) is repainted gold, and back to its gray.
    u.close:__fire("OnEnter")
    assertTrue(is(u.close, GOLD), "the close control is gold under the pointer")
    u.close:__fire("OnLeave")
    assertTrue(is(u.close, REST))
    -- Lock swaps the padlock's art, not its tint.
    f.Hud.SetLocked(true)
    u.lock:__fire("OnEnter")
    assertEqual(u.lock.iconName, "lock")
    assertTrue(is(u.lock, GOLD))
end)

test("hud: the minimum size still holds every body after the compact restyle", function()
    local f = hud()
    f.NS.db.profile.windows.hud.width = 1
    f.NS.db.profile.windows.hud.height = 1
    f.Hud.Show()
    assertEqual(f.Hud.Diagnose().height, f.Hud.MIN_HEIGHT)
    local States = f.NS.HudStates
    local content = f.Hud.MIN_HEIGHT - CHROME
    assertTrue(content >= States.IDLE_ARM_Y + States.ARM_HEIGHT + 4 + 14 + 4 + 20, "idle")
    assertTrue(content >= RUNNING_TOP + 3 * PITCH - 2 + RUNNING_BOTTOM, "running with three rows")
    assertTrue(content >= RESULT_TOP + 3 * PITCH - 2 + RESULT_BOTTOM, "result with three rows")
end)

-- ── HUD Appearance (HUD > HUD Appearance, modules/Hud_Appearance.lua) ─────────────────────────────

test("hud: the running clocks, figures and spell rows take their HUD Appearance blocks", function()
    local f = hud()
    f.Hud.Show()
    running(f, 30)
    f.meter.SetSession(25, session(4))
    f.meter.SetSecret(true)
    pump(f, 0.5)
    local w = body(f).w
    -- The defaults are the shipped look: the monospace clocks at 26, green and red.
    assertEqual(w.elapsed.__font.size, 26)
    assertEqual(w.elapsed.__font.path, f.NS.Constants.FONT_MONO)
    assertEqual(w.elapsed.__color[1], 0.36)
    assertEqual(w.left.__color[1], 1.0)
    assertEqual(w.damage.value.__font.size, 20)
    local row = w.list.rows[1]
    assertEqual(row.__height, 18)
    assertEqual(tostring(row.bar.__barTexture):lower(), "interface\\buttons\\white8x8", "flat: LSM's Solid")
    assertEqual(row.bar.__barColor[4], 0.85)
    assertEqual(row.name.__font.size, 10)

    -- From here the HUD only restyles and draws live values: it measures nothing.
    for i = #f.W.geomReads, 1, -1 do f.W.geomReads[i] = nil end
    assertTrue(f.NS.SetByPath("appearance.elapsed.fontSize", 32))
    assertTrue(f.NS.SetByPath("appearance.elapsed.fontFlags", "OUTLINE"))
    assertTrue(f.NS.SetByPath("appearance.figures.fontShadow", false))
    assertTrue(f.NS.SetByPath("appearance.bars.rowHeight", 24))
    assertTrue(f.NS.SetByPath("appearance.bars.barColor", { r = 0.1, g = 0.2, b = 0.3, a = 1 }))
    pump(f, 0.5)
    w = body(f).w
    assertEqual(w.elapsed.__font.size, 32)
    assertEqual(w.elapsed.__font.flags, "OUTLINE")
    assertEqual(w.damage.value.__shadow[1], 0, "the shadow is off")
    row = w.list.rows[1]
    assertEqual(row.__height, 24)
    assertEqual(row.bar.__barColor[1], 0.1)
    assertEqual(row.bar.__barColor[4], 0.85, "the bar opacity is its own row")
    -- The stack moved down for the taller clock: the KPIs at 26 + 32, the rows under them.
    local p = w.damage.frame.__points[1]
    assertEqual(p[5], -58)
    assertEqual(body(f).kpiBottom, 58 + 46 + 8)
    -- The chart sits between the KPIs and the rows, at its configured height (no best: no pace bar).
    -- Damage profile (6 + 22), the 80px plot, its 2 + 12 time labels and 8, then Spell breakdown.
    assertEqual(body(f).rowsTop, 58 + 46 + 8 + (6 + 22 + 80 + 2 + 12 + 8) + BREAKDOWN)
    assertEqual(#f.W.geomReads, 0, "nothing measured")
end)

test("hud: a clock shown alone draws half again as large, in its block's color", function()
    local f = hud()
    f.NS.db.profile.hud.clock = "elapsed"
    f.Hud.Show()
    running(f, 30)
    pump(f, 0.5)
    local w = body(f).w
    assertEqual(w.clock.__font.size, 40)
    assertEqual(w.clock.__color[1], 0.36, "the elapsed block's green")
    assertEqual(w.damage.frame.__points[1][5], -52, "the shipped layout at the defaults")
end)

test("hud: a bar's class color companion takes the player's class, the swatch's opacity kept", function()
    local f = hud()
    f.NS.db.profile.appearance.bars.useClassColorBar = true
    f.Hud.Show()
    running(f, 30)
    f.meter.SetSession(25, session(2))
    f.meter.SetSecret(true)
    f.NS.HudAppearance.Changed()
    pump(f, 0.5)
    local fill = f.NS.HudAppearance.Bar()
    local _, class = f.M.UnitClass("player")
    local cr = assert(f.M.RAID_CLASS_COLORS[class], "the mock player has a class color")
    assertEqual(fill.r, cr.r)
    assertEqual(fill.a, 0.85)
    assertEqual(body(f).w.list.rows[1].bar.__barColor[1], cr.r)
end)
