-- tests/test_race.lua — modules/Race.lua, the race lifecycle (spec §4): arming and its refusals, the
-- clock starting on the new meter session, the session-ID capture, the buzzer, late casts after the
-- grace (§5.2), incomplete runs, the result read gated on combat end AND 2.5s of quiet (§4.5), the
-- read by session ID, the restart flag (§5.3), a meter reset, cancel, and the list fallback (§9).
--
-- Race is driven through its inputs with a fake clock (tests/race_clock.lua); Watchers is loaded but
-- never fired here, so every input is the one the case calls.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local F = dofile(T.root .. "/tests/race_clock.lua")(T)

local function near(got, want, msg)
    assertTrue(type(got) == "number" and math.abs(got - want) < 1e-6,
        (msg or "value") .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

--- Armed at 100 for `length`, started at 100 on session 25.
local function running(length)
    local f = F.new()
    assertTrue(f:arm(length or 30))
    f:start(25)
    assertEqual(f.Race.State(), "running")
    return f, f.Race.Current()
end

--- Running at 100 for 30s, the buzzer gone at 130.
local function stopping()
    local f, run = running(30)
    f:to(130)
    assertEqual(f.Race.State(), "stopping")
    return f, run
end

-- ── arming ──────────────────────────────────────────────────────────────────────────────────────

test("race: the state names are the interface's", function()
    local S = T.NS.Race.STATE
    assertEqual(S.IDLE, "idle")
    assertEqual(S.ARMED, "armed")
    assertEqual(S.RUNNING, "running")
    assertEqual(S.STOPPING, "stopping")
    assertEqual(S.RESULT, "result")
    assertEqual(T.NS.Race.State(), "idle")
    assertNil(T.NS.Race.Current())
end)

test("race: arm refuses in combat and while a run is pending", function()
    local f = F.new()
    f.M.__inCombat = true
    local ok, why = f:arm(30)
    assertFalse(ok)
    assertEqual(why, "in_combat")
    assertEqual(f.Race.State(), "idle")
    f.M.__inCombat = false

    -- Armed or running: busy.
    assertTrue(f:arm(30))
    ok, why = f:arm(30)
    assertFalse(ok)
    assertEqual(why, "busy")
    f:start(25)
    ok, why = f:arm(30)
    assertFalse(ok)
    assertEqual(why, "busy", "running")

    -- Stopping (the result is unresolved): pending, even once combat has dropped.
    f:to(130)
    assertEqual(f.Race.State(), "stopping")
    ok, why = f:arm(30)
    assertFalse(ok)
    assertEqual(why, "pending")
    f.M.__inCombat = false
    ok, why = f:arm(30)
    assertFalse(ok)
    assertEqual(why, "pending", "out of combat, still waiting for the read")
    assertEqual(#f.NS.Recorder.All(), 1, "a refusal stored nothing")
end)

test("race: arm refuses while a stored run is pending, even when idle", function()
    local f = F.new()
    f.NS.db.global.runs["1-1000"] = F.storedRun({ id = "1-1000", status = "stopping" })
    local ok, why = f:arm(30)
    assertFalse(ok)
    assertEqual(why, "pending")
end)

test("race: arm refuses when meter unavailable", function()
    local f = F.new()
    f.meter.SetAvailable(false, "Damage meter is disabled")
    local ok, why, detail = f:arm(30)
    assertFalse(ok)
    assertEqual(why, "meter_unavailable")
    assertEqual(detail, "Damage meter is disabled", "Blizzard's reason, verbatim")
    assertEqual(f.Race.State(), "idle")
    assertEqual(#f.heard.states, 0)
end)

test("race: arm refuses a length outside 10s-15:00 and arms a valid one", function()
    local f = F.new()
    for _, bad in ipairs({ 9, 901, "30", 0 }) do
        local ok, why = f:arm(bad)
        assertFalse(ok, tostring(bad))
        assertEqual(why, "bad_length", tostring(bad))
    end
    assertTrue(f:arm(10))
    assertEqual(f.Race.State(), "armed")
    assertEqual(f.Race.Current().race.length, 10)
    assertEqual(f:trail(), "idle>armed")
end)

-- ── the start ───────────────────────────────────────────────────────────────────────────────────

test("race: session created starts the clock and persists the run as running", function()
    local f = F.new()
    assertTrue(f:arm(30))
    local run = f.Race.Current()
    assertEqual(run.status, "armed")
    assertNil(f:stored(run.id), "an armed run is not stored")
    assertNil(f.Race.Elapsed())
    assertNil(f.Race.TimeLeft())

    f:advance(42)                 -- a long wait at the dummy: arming is cheap
    assertEqual(f.Race.State(), "armed")
    f.M.__inCombat = true
    f.Race.OnSessionCreated(f:now())
    assertEqual(f.Race.State(), "running")
    assertTrue(f:stored(run.id) == run, "the run is stored the moment the clock starts")
    assertEqual(run.status, "running")
    near(run.race.startedAt, 142, "the start is GetTime() at the session event")
    assertEqual(f.Race.Elapsed(), 0)
    f:advance(5)
    near(f.Race.Elapsed(), 5)
    near(f.Race.TimeLeft(), 25)
    assertNil(f.Race.SinceBuzzer())
    assertEqual(f:trail(), "idle>armed,armed>running")
end)

test("race: the target is re-read at combat start and the arm-time count is kept", function()
    local f = F.new()
    f.M.__setTarget({ guid = "Creature-0-3770-2552-1234-243208-0000ABCDEF", name = "Cleave Training Dummy" })
    assertTrue(f:arm(30, 5))
    local run = f.Race.Current()
    assertEqual(run.target.count, 5)
    -- Combat starts with the same dummy targeted, its name now sealed: the arm-time read fills it.
    f.M.__setTarget({ guid = "Creature-0-3770-2552-1234-243208-0000ABCDEF", name = T.secret("x") })
    f:start(25)
    assertEqual(run.target.npcID, 243208)
    assertEqual(run.target.name, "Cleave Training Dummy")
    assertEqual(run.target.count, 5, "the count picked at arm survives the re-read")

    -- A different dummy at combat start: the combat-start read is the one stored.
    local g = F.new()
    g.M.__setTarget({ guid = "Creature-0-3770-2552-1234-243208-0000ABCDEF", name = "Cleave Training Dummy" })
    assertTrue(g:arm(30, 5))
    g.M.__setTarget({ guid = "Creature-0-3770-2552-1234-243205-0000ABCDEF", name = "Reinforced Golem" })
    g:start(25)
    local t = g.Race.Current().target
    assertEqual(t.npcID, 243205)
    assertEqual(t.category, "boss")
    assertEqual(t.count, 1, "another target takes its own catalog count")
end)

test("race: sessionID captured from first DamageDone update with non-zero id", function()
    local f = F.new()
    f.meter.SetSession(24, F.SESSION)          -- an earlier fight's session, there at arm time
    assertTrue(f:arm(30))
    local run = f.Race.Current()
    f.M.__inCombat = true
    f.Race.OnCombatStart(100)
    f.Race.OnSessionCreated(100)
    assertNil(run.race.sessionID)
    f.Race.OnMeterUpdate(7, 25, 100)           -- another meter type
    assertNil(run.race.sessionID, "only DamageDone names the session")
    f.Race.OnMeterUpdate(0, 0, 100)
    assertNil(run.race.sessionID, "a zero id is not a session")
    f.Race.OnMeterUpdate(0, T.secret(25), 100)
    assertNil(run.race.sessionID, "a secret id is never keyed on")
    f.Race.OnMeterUpdate(0, 24, 100)
    assertNil(run.race.sessionID, "a session that existed at arm time is another fight's")
    f.Race.OnMeterUpdate(0, 25, 100.2)
    assertEqual(run.race.sessionID, 25)
    assertEqual(f:stored(run.id).race.sessionID, 25)
    f.Race.OnMeterUpdate(0, 26, 101)
    assertEqual(run.race.sessionID, 25, "the first capture holds")
end)

test("race: a DamageDone update heard just before the session event is adopted at the start", function()
    local f = F.new()
    assertTrue(f:arm(30))
    f.M.__inCombat = true
    f.Race.OnMeterUpdate(0, 25, 100)
    f.Race.OnSessionCreated(100)
    assertEqual(f.Race.Current().race.sessionID, 25)
end)

test("race: a session event heard out of combat does not start the clock", function()
    local f = F.new()
    assertTrue(f:arm(30))
    f.Race.OnSessionCreated(100)               -- a trailing update from the last fight, or a groupmate
    assertEqual(f.Race.State(), "armed", "stays armed: no regen edge and not in combat")
    f:advance(5)
    -- The real pull: the regen edge and the session event on one frame, in either order.
    f.M.__inCombat = false
    f.Race.OnSessionCreated(105)
    f.Race.OnCombatStart(105)
    assertEqual(f.Race.State(), "running", "the edge on the same frame starts it")
    near(f.Race.Elapsed(), 0)
end)

test("race: a DamageDone update for a stray session heard out of combat is never adopted at the start", function()
    local f = F.new()
    assertTrue(f:arm(30))
    -- A groupmate's pull nearby: session 31, its update, the player never in combat.
    f.Race.OnSessionCreated(100)
    f.Race.OnMeterUpdate(0, 31, 100)
    f:to(110)
    assertEqual(f.Race.State(), "armed")
    -- The real pull on session 32.
    f:start(32)
    assertEqual(f.Race.State(), "running")
    assertEqual(f.Race.Current().race.sessionID, 32, "the stray session 31 was adopted")
end)

test("race: the target is re-read at the combat that starts the clock, not an earlier one", function()
    local f = F.new()
    f.M.__setTarget({ guid = "Creature-0-3770-2552-1234-243208-0000ABCDEF", name = "Cleave Training Dummy" })
    assertTrue(f:arm(30))
    -- A stray mob aggroes the player; combat drops; the race is still armed.
    f.M.__setTarget({ guid = "Creature-0-3770-2552-1234-99999-0000ABCDEF", name = "Stray Mob" })
    f.M.__inCombat = true
    f.Race.OnCombatStart(100)
    f.M.__inCombat = false
    f.Race.OnCombatEnd(101)
    assertEqual(f.Race.State(), "armed")
    f:to(110)
    f.M.__setTarget({ guid = "Creature-0-3770-2552-1234-243205-0000ABCDEF", name = "Reinforced Golem" })
    f:start(25)
    assertEqual(f.Race.Current().target.npcID, 243205, "the stray combat's target was kept")
end)

test("race: a session event with the regen edge on an earlier frame does not start the clock", function()
    local f = F.new()
    assertTrue(f:arm(30))
    f.Race.OnCombatStart(100)
    f.Race.OnSessionCreated(101)
    assertEqual(f.Race.State(), "armed")
end)

test("race: a buzzer heard out of combat with the regen edge missed is still read", function()
    local f, run = running(30)
    f.M.__inCombat = false                     -- combat dropped, its edge never heard
    f.meter.SetSecret(false)
    f:to(140)
    assertEqual(f.Race.State(), "result", "the poll notices combat is over")
    assertTrue(run.status == "complete" or run.status == "incomplete", run.status)
    assertEqual(f.clock.live(), 0)
end)

test("race: an empowered cast held across the buzzer is never late", function()
    local f = running(30)
    local frame = f.NS.Watchers.Frame()
    f:to(129.5)                                -- Fire Breath starts charging 0.5s before the buzzer
    assertEqual(f.M.__fireUnconditional(frame, "UNIT_SPELLCAST_EMPOWER_START", "player", "Cast-1", 357208), 1)
    f:to(131.5)                                -- released 1.5s after it (grace 1.0)
    assertEqual(f.M.__fireUnconditional(frame, "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 357208), 1)
    assertEqual(#f.Race.Current().flags.lateCasts, 0, "the release was judged as an instant")
    f.M.__fireUnconditional(frame, "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 361469)
    assertEqual(#f.Race.Current().flags.lateCasts, 1, "a fresh instant after it is still judged")
end)

-- ── the buzzer ──────────────────────────────────────────────────────────────────────────────────

test("race: buzzer at start+length moves to stopping and emits RACE_BUZZER", function()
    local f, run = running(30)
    f:to(129.9)
    assertEqual(f.Race.State(), "running")
    assertEqual(#f.heard.buzzers, 0)
    near(f.Race.TimeLeft(), 0.1)
    f:to(130)
    assertEqual(f.Race.State(), "stopping")
    assertEqual(#f.heard.buzzers, 1)
    assertTrue(f.heard.buzzers[1] == run)
    assertEqual(run.status, "stopping")
    assertEqual(f:stored(run.id).status, "stopping")
    assertEqual(f.Race.TimeLeft(), 0)
    near(f.Race.SinceBuzzer(), 0)
    f:to(131.5)
    near(f.Race.SinceBuzzer(), 1.5)
    near(f.Race.Elapsed(), 31.5)
    assertEqual(f:trail(), "idle>armed,armed>running,running>stopping")
end)

-- ── late casts (spec §5.2) ──────────────────────────────────────────────────────────────────────

test("race: cast started 0.5s after buzzer is not late at grace 1.0", function()
    local f, run = stopping()
    f.Race.OnCast("start", 29722, 130.5)
    f.Race.OnCast("succeeded", 29722, 132.0)
    f.Race.OnCast("start", 348, 131.0)          -- exactly buzzer + grace: on time
    assertEqual(#run.flags.lateCasts, 0)
end)

test("race: cast started 1.4s after buzzer is recorded as late with spellID", function()
    local f, run = stopping()
    f.Race.OnCast("start", 29722, 131.4)
    f.Race.OnCast("succeeded", 29722, 133.9)    -- its finish is the same cast, not a second one
    assertEqual(#run.flags.lateCasts, 1)
    near(run.flags.lateCasts[1].t, 1.4)
    assertEqual(run.flags.lateCasts[1].spellID, 29722)
    -- An instant has no start: its success time is used.
    f.Race.OnCast("succeeded", 17962, 132.0)
    -- A channel counts at its start.
    f.Race.OnCast("channel", 5740, 134.25)
    assertEqual(#run.flags.lateCasts, 3)
    near(run.flags.lateCasts[2].t, 2.0)
    assertEqual(run.flags.lateCasts[2].spellID, 17962)
    near(run.flags.lateCasts[3].t, 4.25)
end)

test("race: cast that started before buzzer and succeeded after is not late", function()
    local f, run = running(30)
    f:to(128.5)
    f.Race.OnCast("start", 116858, f:now())
    f:to(130)
    f.Race.OnCast("succeeded", 116858, 131.5)
    assertEqual(#run.flags.lateCasts, 0)
end)

test("race: the grace in force is the run's own, not the profile's", function()
    local f, run = running(30)
    f.NS.db.profile.race.grace = 5
    f:to(130)
    f.Race.OnCast("start", 29722, 131.4)
    assertEqual(#run.flags.lateCasts, 1, "the profile changed mid-run; the run keeps 1.0")
end)

test("race: an interrupted cast leaves nothing open; a later instant of the same spell is late", function()
    local f, run = running(30)
    f.Race.OnCast("start", 11366, 129.0, "Cast-A")        -- a Pyroblast hard-cast before the buzzer
    f.Race.OnCast("interrupted", 11366, 129.6, "Cast-A")  -- moved: no success
    f:to(130)
    f.Race.OnCast("succeeded", 11366, 133.0, "Cast-B")    -- a Hot Streak instant, after the grace
    assertEqual(#run.flags.lateCasts, 1)
    near(run.flags.lateCasts[1].t, 3.0)
    assertEqual(run.flags.lateCasts[1].spellID, 11366)
end)

test("race: a cast matches its own success by castGUID, not by spell", function()
    local f, run = running(30)
    f.Race.OnCast("start", 11366, 129.0, "Cast-A")        -- its interrupt event never heard
    f:to(130)
    f.Race.OnCast("succeeded", 11366, 133.0, "Cast-B")    -- another cast of the same spell
    assertEqual(#run.flags.lateCasts, 1, "a different cast is judged on its own")
    local g, run2 = running(30)
    g.Race.OnCast("start", 116858, 128.5, "Cast-C")
    g:to(130)
    g.Race.OnCast("succeeded", 116858, 131.5, "Cast-C")
    assertEqual(#run2.flags.lateCasts, 0, "the same cast finishing is never late")
end)

test("race: secret spell IDs and castGUIDs are judged without ever being stored", function()
    local f, run = running(30)
    -- An interrupted start with a sealed identity, then an instant: the instant is judged.
    f.Race.OnCast("start", T.secret(116858), 129.5, T.secret("Cast-A"))
    f.Race.OnCast("interrupted", T.secret(116858), 129.7, T.secret("Cast-A"))
    f:to(130)
    f.Race.OnCast("succeeded", T.secret(17962), 132.0, T.secret("Cast-B"))
    assertEqual(#run.flags.lateCasts, 1, "the instant after the grace is late")
    near(run.flags.lateCasts[1].t, 2.0)
    assertNil(run.flags.lateCasts[1].spellID, "a sealed spell ID is never stored")
    -- A sealed cast begun before the buzzer and finishing after it is never late.
    local g, run2 = running(30)
    g.Race.OnCast("start", T.secret(116858), 128.5, T.secret("Cast-C"))
    g:to(130)
    g.Race.OnCast("succeeded", T.secret(116858), 131.5, T.secret("Cast-C"))
    assertEqual(#run2.flags.lateCasts, 0)
    -- A late channel with a sealed ID counts at its start; its own success is the same cast.
    g.Race.OnCast("channel", T.secret(5740), 132.0, T.secret("Cast-D"))
    g.Race.OnCast("succeeded", T.secret(5740), 132.0, T.secret("Cast-D"))
    assertEqual(#run2.flags.lateCasts, 1)
    f:combatEnd()
    f:advance(3)
    assertEqual(run.status, "complete")
    assertNil(F.findSecret(run), "a secret reached the stored run at " .. tostring(F.findSecret(run)))
end)

test("race: auto-repeat successes after the buzzer are never late casts", function()
    local f, run = stopping()
    f.Race.OnCast("succeeded", 75, 131.6)                 -- Auto Shot keeps firing on its own
    f.Race.OnCast("succeeded", 75, 134.1)
    assertEqual(#run.flags.lateCasts, 0)
    -- Sealed IDs: an auto-repeat spell active means the success is the auto-repeat's.
    f.M.C_Spell = f.M.C_Spell or {}
    local active = true
    f.M.C_Spell.IsAutoRepeatSpell = function(id) return active and id == 75 end
    f.Race.OnCast("succeeded", T.secret(75), 136.6)
    assertEqual(#run.flags.lateCasts, 0, "auto-repeat on: a sealed success is not a press")
    active = false
    f.Race.OnCast("succeeded", T.secret(34026), 137.0)
    assertEqual(#run.flags.lateCasts, 1, "auto-repeat off: a sealed instant is judged")
end)

test("race: a sealed meter type or session ID moves nothing and stores nothing", function()
    local f = F.new()
    assertTrue(f:arm(30))
    local run = f.Race.Current()
    f.M.__inCombat = true
    f.meter.SetSession(25, F.SESSION)
    f.Race.OnCombatStart(100)
    f.Race.OnSessionCreated(100)
    f.Race.OnMeterUpdate(T.secret(0), 25, 100)
    assertNil(run.race.sessionID, "a sealed meter type is not DamageDone")
    f.Race.OnMeterUpdate(T.secret(0), T.secret(25), 100)
    assertNil(run.race.sessionID)
    f.Race.OnMeterUpdate(0, 25, 100.5)
    assertEqual(run.race.sessionID, 25)
    f:to(130)
    f:to(131)
    f.Race.OnMeterUpdate(T.secret(0), 25, 131)            -- never a stamp: the tail stays at none
    f:combatEnd()
    f:advance(3)
    assertEqual(run.status, "complete")
    assertEqual(run.result.tail, 0)
    assertNil(F.findSecret(run), "a secret reached the stored run at " .. tostring(F.findSecret(run)))
end)

test("race: Watchers hands Race the castGUID and the interrupt", function()
    local f, run = running(30)
    f:to(129)
    assertTrue(f.M.__fire("UNIT_SPELLCAST_START", "player", "Cast-A", 11366) >= 1, "START is registered")
    f:to(129.6)
    assertTrue(f.M.__fire("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-A", 11366) >= 1,
        "INTERRUPTED is registered")
    f:to(133)
    f.M.__fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-B", 11366)
    assertEqual(#run.flags.lateCasts, 1)
    near(run.flags.lateCasts[1].t, 3.0)
end)

-- ── incomplete runs ─────────────────────────────────────────────────────────────────────────────

test("race: combat end before buzzer -> incomplete with endedAt", function()
    local f, run = running(60)
    f:to(120)
    f:combatEnd()
    assertEqual(f.Race.State(), "stopping", "waits for the read like any other run")
    assertEqual(run.status, "stopping")
    near(run.result.endedAt, 20)
    assertNil(f.Race.SinceBuzzer(), "no buzzer went")
    f:to(170)
    assertEqual(#f.heard.buzzers, 0, "the buzzer was canceled")
    assertEqual(f.Race.State(), "result")
    assertEqual(run.status, "incomplete")
    assertEqual(run.result.damage, F.SESSION.damage)
    near(run.result.dps, F.SESSION.damage / 20)
    near(run.result.endedAt, 20)
end)

test("race: death -> incomplete, died flag", function()
    local f, run = running(60)
    f:to(110)
    f.Race.OnDeath(f:now())
    assertTrue(run.flags.died)
    assertEqual(f.Race.State(), "stopping")
    f:to(111)
    f:combatEnd()
    f:to(115)
    assertEqual(run.status, "incomplete")
    near(run.result.endedAt, 10, "ended at the death")
    assertTrue(run.flags.died)
end)

test("race: death after the buzzer flags died and the run stays complete", function()
    local f, run = stopping()
    f.Race.OnDeath(131)
    f:combatEnd()
    f:advance(3)
    assertEqual(run.status, "complete")
    assertTrue(run.flags.died)
end)

-- ── the result read (spec §4.5) ─────────────────────────────────────────────────────────────────

test("race: result read only after combat end AND 2.5s quiet", function()
    local f, run = stopping()
    f:to(130.2)
    f:combatEnd()                      -- combat drops at buzzer + 0.2
    assertEqual(f:reads(), 0, "updates may still come: no read at the regen edge")
    f:to(131.5)
    f:update(25)                       -- the probe's late update, combat end + 1.3s
    f:to(133.9)                        -- combat end + 3.7s: the last poll (133.5) saw 2.0s of quiet
    assertEqual(f:reads(), 0, "not quiet for 2.5s yet")
    assertEqual(f.Race.State(), "stopping")
    f:to(134.0)                        -- combat end + 3.8s: the update + 2.5s, on a poll
    assertEqual(f:reads(), 1, "read at combat end + 3.8s, the first poll 2.5s quiet")
    assertEqual(f.Race.State(), "result")
    assertEqual(#f.heard.results, 1)
    assertTrue(f.heard.results[1] == run)
    assertEqual(run.status, "complete")
end)

test("race: no read while combat holds, however quiet the meter is", function()
    local f = stopping()
    f:to(200)
    assertEqual(f:reads(), 0)
    assertEqual(f.Race.State(), "stopping")
    near(f.Race.SinceBuzzer(), 70)
end)

test("race: read uses ReadSession(sessionID), never Current", function()
    local f, run = stopping()
    -- The HUD's live breakdown reads the Current session while RUNNING (its display path, spec
    -- §6.1); what this case pins is the RESULT read, from the buzzer on.
    for i = #f.meter.calls, 1, -1 do f.meter.calls[i] = nil end
    f.meter.SetSession(99, { damage = 1, dps = 1, duration = 1, spells = {} })   -- now Current
    f:combatEnd()
    f:to(133)
    assertEqual(f.Race.State(), "result")
    assertEqual(#f.meter.CallsTo("GetCombatSessionFromType"), 0)
    assertEqual(#f.meter.CallsTo("GetCombatSessionSourceFromType"), 0)
    local calls = f.meter.CallsTo("GetCombatSessionFromID")
    assertEqual(calls[1].args[1], 25)
    assertEqual(run.result.damage, F.SESSION.damage)
    near(run.result.dps, F.SESSION.damage / 30, "damage over the race length")
    assertEqual(run.result.meterDps, F.SESSION.dps, "Blizzard's figure, for reference")
    assertEqual(run.result.sessionDuration, F.SESSION.duration)
    assertEqual(#run.spells, 3)
    assertEqual(run.spells[1].id, 29722)
    assertEqual(f:stored(run.id).status, "complete")
end)

test("race: tail and combat end are stored relative to the buzzer", function()
    local f, run = stopping()
    f:to(131)
    f:update(25)
    f:to(133.17)
    f:update(25)
    f:to(137.34)
    f:combatEnd()
    f:advance(3)
    assertEqual(run.status, "complete")
    near(run.result.tail, 3.17)
    near(run.result.combatEnd, 7.34)
    assertNil(run.flags.restartedAt, "2s spacing is a tail, not a restart")
end)

test("race: restart after a 10s gap sets flags.restartedAt", function()
    local f, run = stopping()
    f:to(131)
    f:update(25)
    f:to(141)
    f:update(25)                       -- 10s of quiet, then damage again
    f:to(142)
    f:combatEnd()
    f:advance(3)
    assertEqual(run.status, "complete")
    near(run.flags.restartedAt, 11)
    near(run.result.tail, 11)
end)

test("race: updates for another session never move the timeline", function()
    local f, run = stopping()
    f:to(131)
    f:combatEnd()
    f:to(132)
    f.Race.OnMeterUpdate(0, 26, 132)   -- another session's update: not this run's quiet
    f:to(133.5)
    assertEqual(f.Race.State(), "result")
    assertEqual(run.result.tail, 0)
end)

-- ── lost runs and the meter reset ───────────────────────────────────────────────────────────────

test("race: meter reset while stopping -> lost", function()
    local f, run = stopping()
    f.Race.OnMeterReset()
    assertEqual(f.Race.State(), "result")
    assertEqual(run.status, "lost")
    assertNil(run.result, "a lost run has no result")
    assertEqual(f:stored(run.id).status, "lost", "kept, with its metadata")
    assertEqual(#f.heard.results, 1)
    assertEqual(f.clock.live(), 0, "the poll stopped")
end)

test("race: meter reset while running -> lost, and the buzzer never goes", function()
    local f, run = running(30)
    f:to(110)
    f.Race.OnMeterReset()
    assertEqual(run.status, "lost")
    f:to(140)
    assertEqual(#f.heard.buzzers, 0)
end)

test("race: meter reset while armed forgets the arm-time sessions and keeps the arm", function()
    local f = F.new()
    f.meter.SetSession(24, F.SESSION)
    assertTrue(f:arm(30))
    f.Race.OnMeterReset()
    assertEqual(f.Race.State(), "armed")
end)

test("race: a session the client no longer holds is lost at the read", function()
    local f, run = stopping()
    f.meter.RemoveSession(25)
    f:combatEnd()
    f:to(133)
    assertEqual(run.status, "lost")
end)

test("race: a read that stays sealed is retried, then lost", function()
    local f, run = stopping()
    f.meter.SetSealed(25, true)
    f:combatEnd()
    f:to(133)
    assertEqual(f.Race.State(), "stopping", "a sealed read is retried")
    f.meter.SetSealed(25, false)
    f:to(133.5)
    assertEqual(run.status, "complete")

    local g, run2 = stopping()
    g.meter.SetSealed(25, true)
    g:combatEnd()
    g:to(200)
    assertEqual(run2.status, "lost", "never readable: lost rather than waiting forever")
end)

test("race: a read that raises is lost, not a Lua error", function()
    local f, run = stopping()
    f.meter.SetRaise("GetCombatSessionFromID", "boom")
    f:combatEnd()
    f:to(133)
    assertEqual(run.status, "lost")
end)

-- ── the session-list fallback (spec §9) ─────────────────────────────────────────────────────────

test("race: a session ID never captured falls back to the newest session after arming", function()
    local f = F.new()
    f.meter.SetSession(24, { damage = 5, dps = 5, duration = 5, spells = {} })
    assertTrue(f:arm(30))
    local run = f.Race.Current()
    f.M.__inCombat = true
    f.meter.SetSession(25, F.SESSION)
    f.Race.OnCombatStart(100)
    f.Race.OnSessionCreated(100)     -- no DamageDone update ever names the session
    f:to(130)
    f:combatEnd()
    f:to(133)
    assertEqual(run.status, "complete")
    assertEqual(run.race.sessionID, 25)
    assertTrue(run.flags.sessionFromList)
    assertEqual(run.result.damage, F.SESSION.damage)
    local flags = f.NS.Scoring.Flags(run)
    assertEqual(#flags, 1, "the guessed session is shown, so the run is not clean")
    assertEqual(flags[1].key, "sessionFromList")
    assertEqual(flags[1].text, "Session matched by list")
end)

test("race: no new session at all is lost", function()
    local f = F.new()
    assertTrue(f:arm(30))
    local run = f.Race.Current()
    f.M.__inCombat = true
    f.Race.OnSessionCreated(100)
    f:to(130)
    f:combatEnd()
    f:to(133)
    assertEqual(run.status, "lost")
end)

-- ── cancel ──────────────────────────────────────────────────────────────────────────────────────

test("race: cancel in armed/running stores nothing; cancel in stopping discards", function()
    local f = F.new()
    assertTrue(f:arm(30))
    local armed = f.Race.Current()
    assertTrue(f.Race.Cancel())
    assertEqual(f.Race.State(), "idle")
    assertNil(f.Race.Current())
    assertNil(f:stored(armed.id))

    assertTrue(f:arm(30))
    local run = f.Race.Current()
    f:start(25)
    assertTrue(f:stored(run.id) ~= nil)
    assertTrue(f.Race.Cancel())
    assertNil(f:stored(run.id), "a canceled running run is removed from the store")
    f:to(140)
    assertEqual(#f.heard.buzzers, 0, "the buzzer was canceled")

    local g, run2 = stopping()
    assertTrue(g.Race.Cancel())
    assertEqual(g.Race.State(), "idle")
    assertNil(g:stored(run2.id), "discarded")
    assertEqual(g.clock.live(), 0, "no timer or poll left armed")
    assertEqual(#g.NS.Recorder.All(), 0)
    assertFalse(g.Race.Cancel(), "nothing to cancel")
end)

test("race: cancel on a result dismisses it and keeps the run; race again arms", function()
    local f, run = stopping()
    f:combatEnd()
    f:to(133)
    assertEqual(f.Race.State(), "result")
    assertTrue(f.Race.Current() == run)
    assertTrue(f:arm(30), "race again from the result card")
    assertEqual(f.Race.State(), "armed")
    assertTrue(f.Race.Cancel())
    assertEqual(f:stored(run.id).status, "complete")

    local g = stopping()
    g:combatEnd()
    g:to(133)
    assertTrue(g.Race.Cancel())
    assertEqual(g.Race.State(), "idle")
    assertEqual(#g.NS.Recorder.All(), 1)
end)

-- ── inputs out of turn ──────────────────────────────────────────────────────────────────────────

test("race: inputs in the wrong state change nothing", function()
    local f = F.new()
    f.Race.OnSessionCreated(100)
    f.Race.OnMeterUpdate(0, 25, 100)
    f.Race.OnCombatStart(100)
    f.Race.OnCombatEnd(100)
    f.Race.OnCast("start", 1, 100)
    f.Race.OnDeath(100)
    f.Race.OnMeterReset()
    assertEqual(f.Race.State(), "idle")
    assertEqual(#f.heard.states, 0)
    assertEqual(#f.NS.Recorder.All(), 0)
    -- Armed: combat without the session event leaves it armed.
    assertTrue(f:arm(30))
    f.Race.OnCombatStart(101)
    f.Race.OnCombatEnd(102)
    f.Race.OnCast("start", 1, 102)
    assertEqual(f.Race.State(), "armed")
end)

-- ── diagnostics ─────────────────────────────────────────────────────────────────────────────────

test("race: the diagnostics state section names the race state, run, session and pending count", function()
    local f, run = running(30)
    local lines = {}
    local out = { add = function(_, _, fmt, ...)
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        lines[#lines + 1] = fmt:format(unpack(args, 1, select("#", ...)))
    end }
    for _, section in ipairs(f.NS.Diagnostics.Sections()) do
        if section[1] == "state" then section[2](out) end
    end
    local want = ("race state=running run=%s session=25 pending=1 meter=true"):format(run.id)
    local found = false
    for _, l in ipairs(lines) do if l == want then found = true end end
    assertTrue(found, "no race line; got: " .. table.concat(lines, " | "))
end)
