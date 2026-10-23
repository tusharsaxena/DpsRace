-- tests/test_race_resume.lua — modules/Race.lua's Resume (spec §4.5 "After a /reload"): OnEnable finds
-- the runs left running or stopping and carries each on from its stored status. A run past its buzzer
-- becomes stopping and flagged reloaded, one before it keeps running with the time it has left, a
-- stopping run out of combat is read at once, and a run whose session is gone becomes lost. None of
-- them is left hanging in `running`.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local F = dofile(T.root .. "/tests/race_clock.lua")(T)

local function near(got, want, msg)
    assertTrue(type(got) == "number" and math.abs(got - want) < 1e-6,
        (msg or "value") .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

--- An instance initialized but not enabled, `run` in its store and session 25 in the meter (unless
--- `noSession`), the clock at `now`; then OnEnable, which resumes.
local function reload(run, opts)
    opts = opts or {}
    local f = F.new{ enable = false }
    f.M.__now = opts.now or 100
    f.M.__inCombat = opts.inCombat and true or false
    if not opts.noSession then f.meter.SetSession(25, F.SESSION) end
    f.NS.db.global.runs[run.id] = run
    f:enable()
    return f
end

test("resume: running past buzzer becomes stopping+reloaded", function()
    local run = F.storedRun({ status = "running" })      -- started at 100, 30s
    local f = reload(run, { now = 145, inCombat = true })
    assertEqual(f.Race.State(), "stopping", "never left hanging in running")
    assertTrue(f.Race.Current() == run)
    assertEqual(run.status, "stopping")
    assertTrue(run.flags.reloaded)
    near(f.Race.SinceBuzzer(), 15)
    assertEqual(f:reads(), 0, "still in combat: wait for the regen edge")
    assertEqual(f:trail(), "idle>stopping")

    f:combatEnd()
    f:advance(3)                       -- the regen edge, then the 2.5s quiet
    assertEqual(f.Race.State(), "result")
    assertEqual(run.status, "complete")
    assertEqual(run.result.damage, F.SESSION.damage)
    near(run.result.dps, F.SESSION.damage / 30)
    assertTrue(run.flags.reloaded)
end)

test("resume: running before buzzer keeps running with remaining time", function()
    local run = F.storedRun({ status = "running" })
    local f = reload(run, { now = 110, inCombat = true })
    assertEqual(f.Race.State(), "running")
    near(f.Race.TimeLeft(), 20)
    near(f.Race.Elapsed(), 10)
    assertFalse(run.flags.reloaded, "nothing after the buzzer was missed")
    f:to(129.9)
    assertEqual(#f.heard.buzzers, 0)
    f:to(130)
    assertEqual(f.Race.State(), "stopping")
    assertEqual(#f.heard.buzzers, 1)
    f.Race.OnCast("start", 29722, 131.4)
    assertEqual(#run.flags.lateCasts, 1, "cast tracking is back on")
end)

test("resume: stopping out of combat reads immediately", function()
    local run = F.storedRun({ status = "stopping" })
    local f = reload(run, { now = 160, inCombat = false })
    assertEqual(f.Race.State(), "result")
    assertEqual(run.status, "complete")
    assertEqual(run.result.damage, F.SESSION.damage)
    assertEqual(#f.heard.results, 1)
    assertFalse(run.flags.reloaded, "a stopping run is not re-flagged")
    assertEqual(f.clock.live(), 0, "nothing left polling")
end)

test("resume: stopping in combat waits for the regen edge", function()
    local run = F.storedRun({ status = "stopping" })
    local f = reload(run, { now = 160, inCombat = true })
    assertEqual(f.Race.State(), "stopping")
    f:advance(10)
    assertEqual(f:reads(), 0)
    f:combatEnd()
    f:advance(3)                       -- the regen edge, then the 2.5s quiet
    assertEqual(run.status, "complete")
end)

test("resume: an incomplete run waiting for its read stays incomplete", function()
    local run = F.storedRun({ status = "stopping", result = { endedAt = 12 } })
    local f = reload(run, { now = 160 })
    assertEqual(run.status, "incomplete")
    near(run.result.dps, F.SESSION.damage / 12)
    assertTrue(f.Race.State() == "result")
end)

test("resume: session gone becomes lost", function()
    for _, status in ipairs({ "running", "stopping" }) do
        local run = F.storedRun({ status = status })
        local f = reload(run, { now = 145, noSession = true })
        assertEqual(run.status, "lost", status)
        assertNil(run.result, status)
        assertEqual(f.Race.State(), "result", status)
        assertEqual(#f.heard.results, 1, status .. ": the HUD hears it")
        assertEqual(f.NS.Recorder.Get(run.id).status, "lost", status .. ": kept")
    end
end)

test("resume: an older unresolved run is settled as lost; the newest is carried on", function()
    local f = F.new{ enable = false }
    f.M.__now = 145
    f.M.__inCombat = true
    f.meter.SetSession(25, F.SESSION)
    local old = F.storedRun({ id = "1-1000", status = "stopping", date = 1000 })
    local new = F.storedRun({ id = "2-2000", status = "running", date = 2000 })
    f.NS.db.global.runs[old.id], f.NS.db.global.runs[new.id] = old, new
    f:enable()
    assertEqual(old.status, "lost")
    assertTrue(f.Race.Current() == new)
    assertEqual(f.Race.State(), "stopping")
end)

test("resume: nothing stored leaves the race idle and touches nothing", function()
    local f = F.new{ enable = false }
    f:enable()
    assertEqual(f.Race.State(), "idle")
    assertEqual(#f.heard.states, 0)
end)

test("resume: running before the buzzer with combat already over is incomplete and read at once", function()
    local run = F.storedRun({ status = "running" })      -- started at 100, 30s
    local f = reload(run, { now = 110, inCombat = false })
    assertEqual(f.Race.State(), "result", "combat ended unseen: never left waiting for an edge")
    assertEqual(run.status, "incomplete")
    near(run.result.endedAt, 10, "ended no later than the resume")
    near(run.result.dps, F.SESSION.damage / 10)
    assertEqual(f.clock.live(), 0, "no buzzer and no poll left armed")
    assertTrue(f:arm(30), "a new race can be armed")
end)

test("resume: a stand-down mid-run whose combat ends unseen never hangs in stopping", function()
    local f = F.new()
    assertTrue(f:arm(30))
    local run = f.Race.Current()
    f:start(25)
    f:to(110)
    f.NS.ApplyEnabled(false)
    f.M.__inCombat = false                 -- combat drops while nothing is listening
    f.meter.SetSecret(false)
    f:to(115)
    f.NS.ApplyEnabled(true)
    f:advance(600)
    assertEqual(f.Race.State(), "result")
    assertEqual(run.status, "incomplete")
    assertEqual(f.clock.live(), 0, "nothing left polling")
end)
