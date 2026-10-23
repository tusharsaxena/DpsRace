local _, NS = ...
-- modules/Race.lua — the race lifecycle (spec §4): IDLE -> ARMED -> RUNNING -> STOPPING -> RESULT, the
-- clock, the buzzer, late casts (§5.2), the tail and restart (§5.3), the result read (§4.5) and the
-- resume after a /reload.
--
-- DECISIONS COME FROM EVENTS AND GetTime() ONLY (spec §8 rule 2). Nothing here reads a meter number
-- in combat: the clock starts on the new-session event, the buzzer is a timer, the tail and restart are
-- update STAMPS on a Timeline, and the score is read once, after combat and 2.5s of quiet, by session
-- ID through Meter.ReadSession (plain numbers or nothing). An event argument that may be secret (the
-- meter type, the session ID, a spell ID) passes through NS.Secrets.PlainNumber before it is compared.
--
-- INPUTS. modules/Watchers.lua is the only caller of the On* inputs, with `t` from GetTime(). Every
-- input, Arm and Cancel do nothing while the addon is stood down (disabled or perf-suspended): Suspend
-- drops the in-memory race and its timers, and Resume rebuilds it from the store, exactly as after a
-- /reload. A stored run is the same table as the in-memory one (Recorder.Save keeps the reference),
-- so a field set on the run is in SavedVariables at once.
--
-- OUTPUTS. RACE_STATE_CHANGED(run, from, to) on every transition, RACE_BUZZER(run) when the buzzer
-- goes and RACE_RESULT(run) when a run is resolved (complete, incomplete or lost); each is sent after
-- the state has moved, so a receiver reading Race.State() sees the new one.

local Race = {}
NS.Race = Race

local Secrets = NS.Secrets

local STATE = { IDLE = "idle", ARMED = "armed", RUNNING = "running", STOPPING = "stopping", RESULT = "result" }
Race.STATE = STATE

-- The readiness poll's period while STOPPING (plan T5: a 0.5s ticker, only in that state).
Race.POLL_INTERVAL = 0.5
-- Polls a still-sealed read is retried before the run is given up as lost (10s at 0.5s).
Race.SEALED_RETRIES = 20
-- The race-length bounds (spec §4.1: custom 10s-15:00).
Race.MIN_LENGTH, Race.MAX_LENGTH = 10, 900

local state = STATE.IDLE
-- The race in progress. Fields: run, armSet (session IDs present at arm), stash (a session ID heard
-- while armed), combatAt / sessionAt (the regen edge and the session event while armed, paired on one
-- frame to start the clock), startedAt, buzzerAt, combatEndedAt (the regen edge), quietFrom (when the quiet before
-- the read starts counting), timeline, open (spell -> start time of a cast in flight), buzzer, ticker,
-- sealedTries, reread.
local cur = {}

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Race", fmt, ...) end
end

local function isDown()
    return NS.IsStoodDown ~= nil and NS.IsStoodDown()
end

local function round2(v)
    if type(v) ~= "number" then return nil end
    return math.floor(v * 100 + 0.5) / 100
end

local function setState(to)
    local from = state
    state = to
    if NS.Watchers and NS.Watchers.Sync then NS.Watchers.Sync() end
    NS.SendBus(NS.MSG.RACE_STATE_CHANGED, cur.run, from, to)
end

local function cancelTimers()
    if cur.buzzer then cur.buzzer:Cancel() end
    if cur.ticker then cur.ticker:Cancel() end
    cur.buzzer, cur.ticker = nil, nil
end

local function newRace(run)
    cancelTimers()
    cur = { run = run, armSet = {}, open = {}, timeline = NS.Timeline.New(), sealedTries = 0 }
end

-- ── queries ─────────────────────────────────────────────────────────────────────────────────────

--- The current state (one of Race.STATE).
function Race.State()
    return state
end

--- The run being raced, or the one whose result is showing; nil when idle.
function Race.Current()
    if state == STATE.IDLE then return nil end
    return cur.run
end

local function live()
    return (state == STATE.RUNNING or state == STATE.STOPPING) and cur.startedAt ~= nil
end

--- Seconds since the clock started, while running or stopping.
function Race.Elapsed()
    if not live() then return nil end
    return GetTime() - cur.startedAt
end

--- Seconds until the buzzer while running; 0 once stopping.
function Race.TimeLeft()
    if not live() then return nil end
    if state == STATE.STOPPING then return 0 end
    return math.max(0, cur.run.race.length - (GetTime() - cur.startedAt))
end

--- Seconds since the buzzer while stopping; nil for a run that ended before it.
function Race.SinceBuzzer()
    if state ~= STATE.STOPPING or not cur.buzzerAt then return nil end
    return GetTime() - cur.buzzerAt
end

-- ── resolving a run ─────────────────────────────────────────────────────────────────────────────

--- The run is resolved: stop every timer, show the result.
local function finish()
    cancelTimers()
    setState(STATE.RESULT)
    NS.SendBus(NS.MSG.RACE_RESULT, cur.run)
end

local function lose(why)
    local run = cur.run
    debug("run %s lost: %s", tostring(run.id), tostring(why))
    run.status = "lost"
    run.result = nil
    NS.Recorder.Save(run)
    finish()
end

--- The session to read: the captured ID, else the newest session the client created after the arm
--- (spec §9), flagged sessionFromList.
local function sessionToRead()
    local run = cur.run
    if run.race.sessionID then return run.race.sessionID end
    local best
    for id in pairs(NS.Meter.SessionIDs()) do
        if not cur.armSet[id] and (best == nil or id > best) then best = id end
    end
    if best then
        run.race.sessionID = best
        run.flags.sessionFromList = true
    end
    return best
end

--- The tail, combat end and restart, all measured from the buzzer (a run that ended before the
--- buzzer has none of them).
local function timing(result)
    local run, buzzerAt = cur.run, cur.buzzerAt
    if not buzzerAt then return end
    result.tail = round2(cur.timeline:Tail(buzzerAt))
    if cur.combatEndedAt then result.combatEnd = round2(cur.combatEndedAt - buzzerAt) end
    run.flags.restartedAt = round2(cur.timeline:RestartAt(buzzerAt, run.race.restartGap))
end

local function complete(data)
    local run = cur.run
    local result = run.result or {}
    result.damage, result.meterDps, result.sessionDuration = data.damage, data.meterDps, data.duration
    timing(result)
    run.status = result.endedAt and "incomplete" or "complete"
    run.result = result
    run.spells = data.spells
    result.dps = NS.Scoring.Dps(result.damage, run)
    NS.Recorder.Save(run)
    finish()
end

local function read()
    local id = sessionToRead()
    if not id then return lose("no session") end
    local data, err = NS.Meter.ReadSession(id)
    if err == "sealed" then
        cur.sealedTries = cur.sealedTries + 1
        if cur.sealedTries < Race.SEALED_RETRIES then return end
    end
    if not data then return lose(err) end
    complete(data)
end

--- Ready to read = combat has ended AND no DamageDone update for the session in the last 2.5s. The
--- quiet counts from the later of the last update and the combat end: updates still land up to 1.3s
--- after combat drops (spec §4.5), so a run quiet since long before the regen edge still waits.
local function checkReady(t)
    if state ~= STATE.STOPPING or not cur.quietFrom then return end
    local from, last = cur.quietFrom, cur.timeline:LastDamage()
    if last and last > from then from = last end
    if t - from < NS.Scoring.QUIET_BEFORE_READ then return end
    read()
end

--- One readiness poll. A combat end whose regen edge was never heard (it dropped while the addon was
--- stood down, or during a /reload's loading screen) is noticed here, so no run waits forever for an
--- edge that already went: out of combat with no quiet counting yet, the quiet counts from now.
local function poll()
    if isDown() then return end
    local t = GetTime()
    if state == STATE.STOPPING and not cur.quietFrom and not UnitAffectingCombat("player") then
        cur.quietFrom = t
    end
    checkReady(t)
end

local function startPolling()
    if cur.ticker then return end
    cur.ticker = C_Timer.NewTicker(Race.POLL_INTERVAL, poll)
end

-- ── the buzzer ──────────────────────────────────────────────────────────────────────────────────

local function stop()
    local run = cur.run
    run.status = "stopping"
    NS.Recorder.Save(run)
    setState(STATE.STOPPING)
    startPolling()
end

local function buzz()
    cur.buzzer = nil
    if isDown() or state ~= STATE.RUNNING then return end
    -- The buzzer's own time, not the moment the timer was serviced.
    cur.buzzerAt = cur.startedAt + cur.run.race.length
    stop()
    NS.SendBus(NS.MSG.RACE_BUZZER, cur.run)
end

local function armBuzzer(delay)
    cur.buzzer = C_Timer.NewTimer(math.max(0, delay), buzz)
end

--- Combat dropped (or the player died) before the buzzer: the run will be read as incomplete.
local function endEarly(t)
    if cur.buzzer then cur.buzzer:Cancel() end
    cur.buzzer = nil
    cur.run.result = { endedAt = round2(t - cur.startedAt) }
    stop()
end

-- ── arming and the start ────────────────────────────────────────────────────────────────────────

local function validLength(length)
    return type(length) == "number" and length >= Race.MIN_LENGTH and length <= Race.MAX_LENGTH
end

-- Why the state (or the store) refuses a new arm, or nil.
local function stateRefusal()
    if state == STATE.ARMED or state == STATE.RUNNING then return "busy" end
    if state == STATE.STOPPING or #NS.Recorder.Pending() > 0 then return "pending" end
    return nil
end

--- Arm a race of `length` seconds against the current target.
--- @param length number  10-900
--- @param targetCount number|nil  the target count picked before arming (nil keeps the catalog's)
--- @return boolean ok
--- @return string|nil reason  "in_combat" | "meter_unavailable" | "pending" | "busy" |
---                            "bad_length" | "disabled"
--- @return string|nil detail  for "meter_unavailable": Blizzard's own reason, verbatim
function Race.Arm(length, targetCount)
    if isDown() then return false, "disabled" end
    local refusal = stateRefusal()
    if refusal then return false, refusal end
    if not validLength(length) then return false, "bad_length" end
    if UnitAffectingCombat("player") then return false, "in_combat" end
    local ok, why = NS.Meter.IsAvailable()
    if not ok then return false, "meter_unavailable", why end
    newRace(NS.Recorder.NewRun(length, targetCount))
    -- Every session the client holds now belongs to an earlier fight: never this run's.
    cur.armSet = NS.Meter.SessionIDs()
    setState(STATE.ARMED)
    return true
end

-- Capture the run's session, unless it existed before the arm (another fight's).
local function adopt(id)
    if cur.armSet[id] then return end
    cur.run.race.sessionID = id
    NS.Recorder.Save(cur.run)
end

-- The clock starts at `t`.
local function begin(t)
    local run = cur.run
    run.status = "running"
    run.date = time()
    run.race.startedAt = t
    cur.startedAt = t
    if cur.stash then
        adopt(cur.stash)
        if run.race.sessionID then cur.timeline:AddDamage(t) end
    end
    NS.Recorder.Save(run)
    armBuzzer(run.race.length)
    setState(STATE.RUNNING)
end

--- The clock starts: the first new meter session after arming, together with the regen edge on the
--- same frame (spec §4.2). A session event heard out of combat (a trailing update from the last fight,
--- a groupmate's pull) is not a start; it is held for the frame, in case the edge follows it.
function Race.OnSessionCreated(t)
    if isDown() or state ~= STATE.ARMED then return end
    if UnitAffectingCombat("player") or cur.combatAt == t then return begin(t) end
    cur.sessionAt = t
end

-- The armed count survives the combat-start re-read when it is the same creature; another target
-- takes its own catalog count.
local function rereadTarget()
    local run = cur.run
    local prior = run.target or {}
    local fresh = NS.Recorder.SnapshotTarget("target", prior)
    if fresh.npcID ~= nil and fresh.npcID == prior.npcID then fresh.count = prior.count or fresh.count end
    run.target = fresh
    cur.reread = true
end

--- Combat starts: the target is re-read (the stored one is the combat-start read, spec §4.1), and a
--- run waiting for its read is back in combat, so not ready.
function Race.OnCombatStart(t)
    if isDown() then return end
    if (state == STATE.ARMED or state == STATE.RUNNING) and not cur.reread then rereadTarget() end
    if state == STATE.ARMED then
        cur.combatAt = t
        if cur.sessionAt == t then begin(t) end
    elseif state == STATE.STOPPING then
        cur.combatEndedAt, cur.quietFrom = nil, nil
    end
    debug("combat start at %.2f in %s", t or 0, state)
end

--- Combat ends: before the buzzer the run is incomplete; after it, the read waits for the quiet.
function Race.OnCombatEnd(t)
    if isDown() then return end
    if state == STATE.RUNNING then endEarly(t) end
    if state ~= STATE.STOPPING then return end
    cur.combatEndedAt, cur.quietFrom = t, t
    checkReady(t)
end

--- The player died: before the buzzer the run is incomplete and marked died; after it, marked only.
function Race.OnDeath(t)
    if isDown() then return end
    if state ~= STATE.RUNNING and state ~= STATE.STOPPING then return end
    cur.run.flags.died = true
    if state == STATE.RUNNING then endEarly(t) end
end

--- A DAMAGE_METER_COMBAT_SESSION_UPDATED(statType, sessionID). The first DamageDone update with a
--- non-zero ID names the run's session (spec §4.2); every update for it is a stamp on the timeline.
function Race.OnMeterUpdate(statType, sessionID, t)
    if isDown() then return end
    local stat, id = Secrets.PlainNumber(statType), Secrets.PlainNumber(sessionID)
    if stat ~= NS.Meter.STAT_DAMAGE_DONE or not id or id == 0 then return end
    if state == STATE.ARMED then
        if not cur.armSet[id] and not cur.stash then cur.stash = id end
        return
    end
    if state ~= STATE.RUNNING and state ~= STATE.STOPPING then return end
    if not cur.run.race.sessionID then adopt(id) end
    if id == cur.run.race.sessionID then cur.timeline:AddDamage(t) end
end

-- ── casts after the buzzer (spec §5.2) ──────────────────────────────────────────────────────────

local function judge(spellID, t)
    if state ~= STATE.STOPPING or not cur.buzzerAt then return end
    local run = cur.run
    local offset = t - cur.buzzerAt
    if not NS.Scoring.IsLateCast(offset, run.race.grace) then return end
    local list = run.flags.lateCasts
    list[#list + 1] = { t = round2(offset), spellID = spellID }
end

--- A player cast: kind "start" | "channel" | "succeeded". A cast counts at its start; a success
--- with no start seen (an instant) counts at its own time, and one whose start was seen is that
--- same cast finishing, judged already. Starts are tracked from RUNNING, so a cast begun before the
--- buzzer and finished after it is never late.
function Race.OnCast(kind, spellID, t)
    if isDown() or (state ~= STATE.RUNNING and state ~= STATE.STOPPING) then return end
    local id = Secrets.PlainNumber(spellID)
    local key = id or false
    if kind == "start" or kind == "channel" then
        cur.open[key] = t
        judge(id, t)
    elseif kind == "succeeded" then
        if cur.open[key] then
            cur.open[key] = nil
        else
            judge(id, t)
        end
    end
end

--- DAMAGE_METER_RESET: a run in progress loses its session (spec §4.5).
function Race.OnMeterReset()
    if isDown() then return end
    if state == STATE.ARMED then
        cur.armSet, cur.stash = {}, nil
    elseif state == STATE.RUNNING or state == STATE.STOPPING then
        lose("meter reset")
    end
end

-- ── cancel ──────────────────────────────────────────────────────────────────────────────────────

--- Cancel the armed or running race, or discard a pending result: nothing is kept. On a result
--- card it dismisses the card and keeps the run.
--- @return boolean acted
function Race.Cancel()
    if isDown() or state == STATE.IDLE then return false end
    cancelTimers()
    local run = cur.run
    if state ~= STATE.ARMED and state ~= STATE.RESULT then NS.Recorder.Delete(run.id) end
    setState(STATE.IDLE)
    cur = {}
    return true
end

-- ── stand-down, stand-up and the /reload resume ─────────────────────────────────────────────────

--- The lifecycle's stand-down: drop the in-memory race and its timers, silently. A run already stored
--- stays as it is, and Resume carries it on at the stand-up.
function Race.Suspend()
    cancelTimers()
    cur = {}
    state = STATE.IDLE
end

-- The start on this session's clock. GetTime() survives a /reload; after a restart of the machine
-- it does not, and the stored epoch date stands in.
local function startOf(run, now)
    local s = run.race.startedAt
    if type(s) == "number" and s <= now then return s end
    return now - math.max(0, time() - (run.date or time()))
end

-- A run stored as running: still racing (true), or now waiting for its read (false). Before the
-- buzzer and out of combat, combat ended while nothing listened: the run is incomplete, ended no later
-- than now (the edge's real time is unknowable). Past the buzzer, casts after it went unseen.
local function resumeRunning(run, now)
    local elapsed = now - cur.startedAt
    local left = run.race.length - elapsed
    if left > 0 and UnitAffectingCombat("player") then
        setState(STATE.RUNNING)
        armBuzzer(left)
        return true
    end
    if left > 0 then
        run.result = { endedAt = round2(elapsed) }
    else
        run.flags.reloaded = true
    end
    run.status = "stopping"
    NS.Recorder.Save(run)
    return false
end

local function resumeRun(run, now)
    newRace(run)
    cur.startedAt = startOf(run, now)
    cur.reread = true
    local id = run.race.sessionID
    if id ~= nil and not NS.Meter.HasSession(id) then return lose("session gone") end
    if run.status == "running" and resumeRunning(run, now) then return end
    if not (run.result and run.result.endedAt) then cur.buzzerAt = cur.startedAt + run.race.length end
    setState(STATE.STOPPING)
    startPolling()
    -- Combat already over (spec §4.5): read straight away. The quiet was spent during the reload.
    if not UnitAffectingCombat("player") then
        cur.quietFrom = now - NS.Scoring.QUIET_BEFORE_READ
        checkReady(now)
    end
end

--- Carry on the runs a /reload (or a stand-down) left running or stopping. Called from OnEnable and
--- from the lifecycle's stand-up. The newest is followed; an older one (two cannot be pending) is
--- settled as lost.
function Race.Resume()
    if isDown() or state ~= STATE.IDLE then return end
    local pending = NS.Recorder.Pending()
    local n = #pending
    if n == 0 then return end
    for i = 1, n - 1 do
        pending[i].status, pending[i].result = "lost", nil
        NS.Recorder.Save(pending[i])
    end
    resumeRun(pending[n], GetTime())
end
