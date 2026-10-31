-- tests/test_hud.lua — the Race HUD (modules/Hud*.lua, spec §6.1): which body shows for each race
-- state, the idle Arm refusal, the live breakdown under secret values (no %, no sort, no geometry
-- read), the stop and waiting bodies, the sticky-combat hint, the countdown cue and the buzzer, and the
-- live-read throttle and when it stops. The result card and the sizes are tests/test_hud_layout.lua's;
-- the window's lock, scale, position and look are tests/test_hud_window.lua's.
--
-- Every case runs on the race fixture (tests/race_clock.lua: the scripted meter, the fake clock that
-- fires timers at their own GetTime()) with the widget recorder (tests/mock_widgets.lua) installed,
-- so a label's text, a bar's values and every geometry read can be asserted.

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

test("hud: idle Arm uses the picked length; the card has no target count; a refusal prints its line", function()
    local f = hud()
    f.M.__setTarget({ guid = "Creature-0-1-2-3-243208-0001", name = "Cleave Training Dummy" })
    f.Hud.Show()
    local b = body(f)
    assertEqual(b.w.card.npc.__text, "#243208")
    assertEqual(b.w.card.badgeText.__text, "Cleave")
    f.Hud.Act.pickLength(60)
    assertNil(b.w.card.count, "no target count stepper (DpsRace#15)")
    assertNil(b.w.card.minus)
    assertNil(f.Hud.Act.stepCount)
    assertTrue(f.Hud.Act.arm())
    local run = f.Race.Current()
    assertEqual(run.race.length, 60)
    assertNil(run.target.count, "no target count is recorded")
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
    D.race.defaultLength, D.live.hz, D.live.rows = 60, 6, 5
    f.NS.GetSetting = function() return nil end      -- a degraded load: the store cannot answer
    local v = f.Hud.View()
    assertEqual(v.length, 60, "a second default for race.defaultLength")
    assertEqual(v.hz, 6, "a second default for live.hz")
    assertEqual(v.rows, 5, "a second default for live.rows")
end)

local CLEAVE = { guid = "Creature-0-1-2-3-243208-0001", name = "Cleave Training Dummy" }
local BOAR = { guid = "Creature-0-1-2-3-99999-0001", name = "Angry Boar" }

test("hud: a target changed while the HUD is closed is never armed as the old one", function()
    local f = hud()
    f.M.__setTarget(CLEAVE)
    f.Hud.Show()
    f.Hud.Hide()
    f.M.__setTarget(BOAR)
    f.M.__fire("PLAYER_TARGET_CHANGED")       -- nobody listens while the window is closed
    assertTrue(f.NS.ToggleArm())
    assertEqual(f.Race.Current().target.name, "Angry Boar")
end)

test("hud: reopening the HUD offers the target of the moment, not the one cached at close", function()
    local f = hud()
    f.M.__setTarget(CLEAVE)
    f.Hud.Show()
    f.Hud.Hide()
    f.M.__setTarget(BOAR)
    f.M.__fire("PLAYER_TARGET_CHANGED")
    f.Hud.Show()
    assertEqual(body(f).w.card.name.__text, "Angry Boar")
    assertTrue(f.Hud.Act.arm())
    assertEqual(f.Race.Current().target.name, "Angry Boar")
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
    assertEqual(b.w.tail.value.__text, "+1.4s")
    assertEqual(b.w.tail.caption.__text, "after buzzer")
    assertEqual(b.w.combat.value.__text, "+1.4s")
    assertEqual(b.w.combat.caption.__text, "since the buzzer")
    local chips = b.w.chips:Texts()
    assertEqual(chips[1], "1 late cast \194\183 +1.4s")
    assertEqual(chips[2], "Grace 1.0s")
end)

test("hud: the stop body counts only the late casts the ignore list leaves (#8), and redraws when it changes", function()
    local f = hud()
    running(f, 30)
    f:to(130)
    f:advance(1.2)
    f:update(25)
    f.Race.OnCast("start", 5384, f:now(), "Cast-1")      -- Feign Death: ignored by default
    f:advance(0.4)
    f.Race.OnCast("start", 29722, f:now(), "Cast-2")
    tick(f)
    local b = body(f)
    assertEqual(current(f), "stop")
    assertEqual(#f.Race.Current().flags.lateCasts, 2, "the run keeps every late cast")
    assertEqual(b.w.chips:Texts()[1], "1 late cast \194\183 +1.6s")
    assertTrue(f.NS.LateIgnore.Unignore(5384))
    assertEqual(body(f).w.chips:Texts()[1], "2 late casts \194\183 +1.2s", "SETTINGS_CHANGED redrew the body")
    assertTrue(f.NS.LateIgnore.Ignore(29722))
    assertTrue(f.NS.LateIgnore.Ignore(5384))
    assertEqual(body(f).w.chips:Texts()[1], "Grace 1.0s", "all ignored: no late chip")
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
