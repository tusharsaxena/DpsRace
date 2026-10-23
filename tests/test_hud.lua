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
    assertEqual(body(f).w.tail.label.__text, "COMBAT ENDED AT")
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
    assertEqual(b.w.card.badgeText.__text, "CLEAVE")
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
        assertFalse(r.event == METER_EVENT and r.target ~= f.NS.Watchers.Frame(), "the HUD still listens to the meter")
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
    assertEqual(chips[#chips], ("Tail +%.1fs"):format(run.result.tail))
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
    assertEqual(#chips, 1, "died is not shown twice")
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
    assertEqual(f.Race.State(), "armed")
    assertEqual(f.Race.Current().race.length, 30)
end)

test("hud: Share is grayed until a Share module exists", function()
    local f = hud()
    resolved(f)
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
    running(f, 30)
    f:to(121)
    f.Race.Cancel()
    f:to(131)
    assertEqual(table.concat(f.W.SoundTimes(25477), ","), "120")
end)

test("hud: the countdown turns amber in the last 10s", function()
    local f = hud()
    running(f, 30)
    f:to(115)
    tick(f)
    local clock = body(f).w.clock
    assertEqual(clock.__text, "0:15.0")
    assertEqual(clock.__color[2], 0.93)
    f:to(121.04)
    tick(f)
    assertEqual(clock.__text, "0:08.9")
    assertEqual(clock.__color[2], 0.72)
    assertEqual(ui(f).footRight.__text, "live \194\183 4 Hz")
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
    f.Hud.Render("running", nil, { timeLeft = 12.3, live = { total = 1000, dps = 50, spells = {} } })
    assertEqual(current(f), "running")
    assertEqual(body(f).w.clock.__text, "0:12.3")
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
