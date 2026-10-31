local _, NS = ...
-- modules/SampleRace.lua — a sample race on the race's own surface: the stand-in test mode and the sim
-- put where modules/Race.lua stands, so everything that draws or reacts to a race is the code that
-- draws and reacts to a real one.
--
-- WHAT IS SHARED WITH A REAL RACE. The same queries (State, Current, Elapsed, TimeLeft, SinceBuzzer,
-- StopRequested, StopNow, Cancel), so the HUD builds its views through one path. The same bus messages
-- (RACE_STATE_CHANGED, RACE_BUZZER, RACE_RESULT), so the buzzer, the countdown and its cue, the chat
-- lines and the new-best toast are the real receivers'; the one that must not act on a sample (AutoArm,
-- and Preview's end-on-arm) checks run.sample. The same captures: the plan's casts go through
-- NS.Casts, the live reads through the HUD's own throttle into NS.Slices, and the run sits in the
-- sample history from its start, as a real one sits in the store.
--
-- WHAT IS NOT. RUN_SAVED never fires and NS.Recorder never stores (Bests' receiver would prune the real
-- store). NS.Race itself never moves: it is one race, Preview starts over a real result card, and
-- a real race must never run on made-up input.
--
-- THE SCRIPT is the plan's (modules/MockRuns.lua): its casts and hits, the buzzer (or the early end),
-- and the combat end. Stop! and Waiting are not scripted: the HUD chooses between them as it does for
-- a real race, and the read waits for the same quiet after combat. Sim moves it on the clock with
-- Advance; test mode replays it silently to a moment with Hold and leaves it there, frozen.

local SampleRace = {}
NS.SampleRace = SampleRace

local STATE = NS.Race.STATE

local state = STATE.IDLE
local run, sample, plan
local origin          -- GetTime() of the race clock's zero
local held            -- the frozen race-clock moment (test mode), or nil
local silent          -- replaying: no messages
local hit, cast       -- the plan's next hit and next cast
local lastHit, inCombat, quietFrom, stopNow, buzzed, pulse

local function send(msg, ...)
    if not silent then NS.SendBus(msg, ...) end
end

local function setState(to)
    local from = state
    state = to
    send(NS.MSG.RACE_STATE_CHANGED, run, from, to)
end

local function touched()
    if not silent then NS.ResultsSource.Touched() end
end

-- ── queries (Race's) ────────────────────────────────────────────────────────────────────────────

--- Whether a sample race stands where the race does.
function SampleRace.On() return run ~= nil end

--- Whether it is frozen (test mode): no clock, no timers.
function SampleRace.Held() return held ~= nil end

function SampleRace.State() return state end

function SampleRace.Current()
    if state == STATE.IDLE then return nil end
    return run
end

local function clock()
    if held then return held end
    return GetTime() - origin
end

local function racing() return state == STATE.RUNNING or state == STATE.STOPPING end

function SampleRace.Elapsed()
    if not racing() then return nil end
    return clock()
end

function SampleRace.TimeLeft()
    if not racing() then return nil end
    if state == STATE.STOPPING then return 0 end
    return math.max(0, run.race.length - clock())
end

function SampleRace.SinceBuzzer()
    if state ~= STATE.STOPPING or not buzzed then return nil end
    return clock() - run.race.length
end

function SampleRace.StopRequested() return state == STATE.STOPPING and stopNow == true end

--- Whether the sample's character is in combat (the HUD's view reads this in place of the client's).
function SampleRace.InCombat() return inCombat == true end

--- The live read (Meter.ReadLive's shape): the HUD's own throttle and bucket capture call it.
function SampleRace.ReadLive()
    if not racing() then return nil end
    return NS.MockRuns.LiveAt(plan, math.min(clock(), run.race.length))
end

-- ── the script ──────────────────────────────────────────────────────────────────────────────────

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

-- Every cast due by `t`, heard as the client would hand it over; one past the buzzer and its grace is
-- judged late as Race.judge does.
local function hear(t)
    while plan.casts[cast] and plan.casts[cast].t <= t do
        local c = plan.casts[cast]
        NS.Casts.Hear("succeeded", c.pet and "pet" or "player", c.id, nil, origin + c.t)
        local offset = c.t - run.race.length
        if offset > 0 and not c.pet and NS.Scoring.IsLateCast(offset, run.race.grace) then
            local list = run.flags.lateCasts
            list[#list + 1] = { t = round2(offset), spellID = c.id }
        end
        cast = cast + 1
    end
end

-- Every hit due by `t`: its stamp on the run, as a DamageDone update's is.
local function land(t)
    while plan.hits[hit] and plan.hits[hit].t <= t do
        lastHit = plan.hits[hit].t
        run.race.lastDamage = lastHit
        hit, pulse = hit + 1, true
    end
end

local function begin()
    run.status, run.date = "running", time()
    run.flags.sharedSession = sample.run.flags.sharedSession
    NS.Casts.Start(origin)
    NS.ResultsSource.Put(run)
    inCombat = true
    setState(STATE.RUNNING)
end

local function stop()
    run.status = "stopping"
    touched()
    setState(STATE.STOPPING)
end

local function buzz()
    buzzed = true
    stop()
    send(NS.MSG.RACE_BUZZER, run)
end

local function endEarly()
    run.result = { endedAt = round2(sample.stopAt) }
    run.flags.died = sample.run.flags.died
    inCombat, quietFrom = false, sample.stopAt
    stop()
end

-- The read: what the finished run holds, on the run that raced.
local function read()
    local final = sample.run
    run.status, run.result, run.spells = final.status, final.result, final.spells
    run.casts, run.usage = final.casts, final.usage
    run.flags.restartedAt = final.flags.restartedAt
    NS.Casts.Stop()
    touched()
    setState(STATE.RESULT)
    send(NS.MSG.RACE_RESULT, run)
end

-- Race's rule: combat over, and the quiet after the later of the last damage and the combat end. A
-- Stop Now waives the quiet.
local function checkReady(t)
    if state ~= STATE.STOPPING or not quietFrom then return end
    if stopNow then return read() end
    local from = math.max(quietFrom, lastHit or quietFrom)
    if t - from >= NS.Scoring.QUIET_BEFORE_READ then read() end
end

local function stopping(t)
    land(t)
    hear(t)
    if inCombat and t >= sample.combatAt then inCombat, quietFrom = false, sample.combatAt end
    checkReady(t)
end

local function running(t)
    local edge = sample.stopAt
    local upTo = math.min(t, edge)
    land(upTo)
    hear(upTo)
    if t < edge then return end
    if sample.early then endEarly() else buzz() end
end

local function advance(t)
    if state == STATE.ARMED then
        hear(math.min(t, 0))
        if t < 0 then return end
        begin()
    end
    if state == STATE.RUNNING then running(t) end
    if state == STATE.STOPPING then stopping(t) end
end

-- A fresh armed record from the finished run: nothing the race has yet to read.
local function shell(final)
    local r = {}
    for k, v in pairs(final) do r[k] = v end
    r.status, r.result, r.spells, r.casts, r.usage = "armed", nil, {}, nil, nil
    r.race = {}
    for k, v in pairs(final.race) do r.race[k] = v end
    r.flags = { lateCasts = {}, reloaded = false, died = false }
    return r
end

-- Put the race at its arm, the clock's zero `lead` seconds from now, and forget any earlier one.
local function load(s, lead)
    SampleRace.Clear()
    sample, plan, run = s, s.plan, shell(s.run)
    origin = GetTime() + lead
    hit, cast, lastHit, inCombat, quietFrom, stopNow, buzzed, pulse = 1, 1, nil, false, nil, nil, nil, nil
    NS.Casts.Begin(plan.cooldowns)
    state = STATE.ARMED
end

--- Arm sample `s`; the clock starts `lead` seconds from now (the sim's Armed body), on Advance.
function SampleRace.Start(s, lead)
    load(s, lead)
    state = STATE.IDLE
    setState(STATE.ARMED)
end

--- One step of the sim's clock. Answers true when damage landed since the last step (the meter's
--- update: the HUD reads through its throttle).
--- @return boolean updated
function SampleRace.Advance()
    if not run then return false end
    pulse = false
    advance(clock())
    return pulse
end

--- Replay `s` silently to race-clock second `t` and stay there (test mode). `key` "armed" holds the
--- arm, "running" the moment `t` (its buckets captured as the live reads would have), "result" the card.
function SampleRace.Hold(s, key, t)
    load(s, 0)
    silent = true
    if key == "running" then
        held = t
        advance(t)
        local rec = 0
        while rec < math.floor(t) do
            rec = rec + 1
            NS.Slices.Capture(run, rec, (NS.MockRuns.TotalAt(plan, rec)))
        end
    elseif key == "result" then
        held = math.huge
        advance(held)
        for at = 1, run.race.length do NS.Slices.Capture(run, at, (NS.MockRuns.TotalAt(plan, at))) end
    else
        held = 0
    end
    silent = false
end

-- ── the acts (Race's) ───────────────────────────────────────────────────────────────────────────

--- *Stop Now*: as Race.StopNow, the read waits for the combat end and only waives the quiet.
--- @return boolean acted
function SampleRace.StopNow()
    if state ~= STATE.STOPPING then return false end
    stopNow = true
    if not inCombat then
        quietFrom = quietFrom or clock()
        checkReady(clock())
    end
    return true
end

--- Dismiss the sample's result card (or its race): the HUD goes back to its idle body while the
--- preview stays on.
--- @return boolean acted
function SampleRace.Cancel()
    if state == STATE.IDLE then return false end
    NS.Casts.Reset()
    setState(STATE.IDLE)
    return true
end

--- The sample race goes (the preview's stop and switch): no messages, nothing left behind.
function SampleRace.Clear()
    if run then
        NS.Slices.Forget(run.id)
        -- A real arm ended the preview: the cast list is that race's now.
        if NS.Race.State() ~= STATE.ARMED then NS.Casts.Reset() end
    end
    run, sample, plan, held, silent = nil, nil, nil, nil, nil
    state = STATE.IDLE
end
