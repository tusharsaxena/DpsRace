local _, NS = ...
-- modules/Race.lua — the race lifecycle (spec §4): IDLE -> ARMED -> RUNNING -> STOPPING -> RESULT, the
-- clock, the buzzer, late casts (§5.2), the tail and restart (§5.3), the result read (§4.5) and the
-- resume after a /reload.
--
-- DECISIONS COME FROM EVENTS AND GetTime() ONLY (spec §8 rule 2). Nothing here reads a meter number
-- in combat: the clock starts on the new-session event (or the first DamageDone update heard in
-- combat, when the meter made the session out of combat), the buzzer is a timer, the tail and restart are
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

-- The readiness poll's period while STOPPING (a 0.5s ticker, only in that state).
Race.POLL_INTERVAL = 0.5
-- Polls a still-sealed read is retried before the run is given up as lost (10s at 0.5s).
Race.SEALED_RETRIES = 20
-- The race-length bounds (spec §4.1: custom 10s-15:00).
Race.MIN_LENGTH, Race.MAX_LENGTH = 10, 900

local state = STATE.IDLE
-- The race in progress. Fields: run, armSet (session IDs present at arm), armTarget (the arm-time
-- target snapshot), stash / stashAt / stashHeld (a session ID heard while armed, when, and whether in
-- combat), combatAt / sessionAt (the regen edge and the session event while armed, paired on one
-- frame to start the clock), startedAt, buzzerAt, combatEndedAt (the regen edge), quietFrom (when the
-- quiet before the read starts counting), resumedAt (when a /reload's resume ran: the damage heard
-- during the loading screen is unknown, so no restart gap spans it), timeline, inFlight (the cast
-- begun and not yet finished: its plain spell ID and castGUID, either nil when sealed), buzzer,
-- ticker, sealedTries, reread, baseline (what the newest earlier session held at the arm: see
-- baselineOf), stopNow (Race.StopNow was pressed: the read waives the quiet), usageSnap (the arm's
-- usage snapshot, #13: modules/Usage.lua; nil for a run resumed after a /reload).
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
    cur = { run = run, armSet = {}, timeline = NS.Timeline.New(), sealedTries = 0 }
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

--- The run's loadout (#6): the combat-end snapshot when one was taken, else the arm-time one. A run
--- resumed after a /reload or a stand-down has neither when its combat ended unheard: out of combat,
--- a fresh snapshot is what raced, as at the regen edge.
local function keepLoadout(run)
    if run.loadout ~= nil then return end
    if cur.armLoadout then return NS.Loadouts.Attach(run, cur.armLoadout) end
    if not UnitAffectingCombat("player") then NS.Loadouts.Attach(run, NS.Recorder.SnapshotLoadout()) end
end

--- The run's casts and usage (#13, #14), at the result: the cast list heard since the arm (its last
--- Casts.PREPULL seconds before the pull on), and what was used, from the arm's snapshot, those casts,
--- the bag counts now and the casts before that window. A run resumed after a /reload heard neither
--- (both lists were in memory): it keeps none, and reads as not recorded.
local function keepUsage(run)
    local Casts = NS.Casts
    if not Casts.Collecting() then return end
    Casts.Stop()
    run.casts = Casts.Record()
    if cur.usageSnap and run.casts then
        run.usage = NS.Usage.Build(cur.usageSnap, Casts.Decode(run.casts.list), NS.Usage.BagCounts(),
            Casts.Early())
    end
end

local function lose(why)
    local run = cur.run
    keepLoadout(run)
    keepUsage(run)
    debug("run %s lost: %s", tostring(run.id), tostring(why))
    run.status = "lost"
    run.result = nil
    NS.Recorder.Save(run)
    finish()
end

--- Whether a session belongs to a fight before the arm: one the client held at arm time, or (after a
--- /reload, when that set is gone) one no newer than the newest of them, run.race.armMaxSession.
--- Session IDs only grow (the probe's ran 24, 25, ...), so the high-water mark stands in for the set.
local function beforeArm(id)
    if cur.armSet[id] then return true end
    local mark = cur.run.race.armMaxSession
    return type(mark) == "number" and id <= mark
end

--- The session to read: the captured ID, else the newest session the client created after the arm
--- (spec §9), flagged sessionFromList.
local function sessionToRead()
    local run = cur.run
    if run.race.sessionID then return run.race.sessionID end
    local best
    for id in pairs(NS.Meter.SessionIDs()) do
        if not beforeArm(id) and (best == nil or id > best) then best = id end
    end
    if best then
        run.race.sessionID = best
        run.flags.sessionFromList = true
    end
    return best
end

--- The tail and combat end, measured from the buzzer (a run that ended before the buzzer has
--- neither). The restart was flagged as its update arrived (stamp), so a /reload since keeps it.
local function timing(result)
    local buzzerAt = cur.buzzerAt
    if not buzzerAt then return end
    result.tail = round2(cur.timeline:Tail(buzzerAt))
    if cur.combatEndedAt then result.combatEnd = round2(cur.combatEndedAt - buzzerAt) end
end

--- One DamageDone update for the run's session at `t`: a stamp on the timeline, its offset from the
--- start kept on the run (run.race.lastDamage) so a /reload's fresh timeline starts from it, and,
--- past the buzzer, the restart flagged the moment it is heard (spec §5.3).
local function stamp(t)
    local run, buzzerAt = cur.run, cur.buzzerAt
    cur.timeline:AddDamage(t)
    run.race.lastDamage = round2(t - cur.startedAt)
    if buzzerAt and not run.flags.restartedAt then
        run.flags.restartedAt = round2(cur.timeline:RestartAt(buzzerAt, run.race.restartGap, cur.resumedAt))
        if run.flags.restartedAt then debug("damage restarted at +%.2f", run.flags.restartedAt) end
    end
end

--- A shared session's read, netted: the damage the session held at the arm comes off the total and
--- off each spell (summed by spell ID, since the meter may list one ID twice). The meter's own rate
--- spans both fights, so it is dropped. With no baseline (the arm-time read failed, or the pull carried
--- on an older session than the newest) only the rate goes, and the flag says the total may hold more.
local function net(data, base)
    data.meterDps = nil
    if type(base) ~= "table" or type(base.damage) ~= "number" then return end
    local held = type(base.spells) == "table" and base.spells or {}
    data.damage = math.max(0, data.damage - base.damage)
    local sums, order = {}, {}
    for _, s in ipairs(data.spells) do
        if not sums[s.id] then
            order[#order + 1] = s.id
            sums[s.id] = 0
        end
        sums[s.id] = sums[s.id] + s.dmg
    end
    local spells = {}
    for _, id in ipairs(order) do
        local dmg = sums[id] - (held[id] or 0)
        if dmg > 0 then spells[#spells + 1] = { id = id, dmg = dmg, dps = 0 } end
    end
    table.sort(spells, function(a, b)
        if a.dmg ~= b.dmg then return a.dmg > b.dmg end
        return a.id < b.id
    end)
    data.spells = spells
end

local function complete(data)
    local run = cur.run
    if run.flags.sharedSession then net(data, run.race.baseline) end
    local result = run.result or {}
    result.damage, result.meterDps, result.sessionDuration = data.damage, data.meterDps, data.duration
    timing(result)
    run.status = result.endedAt and "incomplete" or "complete"
    run.result = result
    run.spells = data.spells
    result.dps = NS.Scoring.Dps(result.damage, run)
    keepLoadout(run)
    keepUsage(run)
    debug("read session: %s, damage %s", run.status, result.damage ~= nil and "present" or "absent")
    NS.Recorder.Save(run)
    finish()
end

local function read()
    local id = sessionToRead()
    if not id then return lose("no session") end
    local data, err = NS.Meter.ReadSession(id)
    if err == "sealed" then
        cur.sealedTries = cur.sealedTries + 1
        debug("session %d still sealed (try %d)", id, cur.sealedTries)
        if cur.sealedTries < Race.SEALED_RETRIES then return end
    end
    if not data then return lose(err) end
    complete(data)
end

--- Ready to read = combat has ended AND no DamageDone update for the session in the last 2.5s. The
--- quiet counts from the later of the last update and the combat end: updates still land up to 1.3s
--- after combat drops (spec §4.5), so a run quiet since long before the regen edge still waits. A
--- *Stop now* (Race.StopNow) waives the quiet, never the combat end: the read is out of combat only.
local function checkReady(t)
    if state ~= STATE.STOPPING or not cur.quietFrom then return end
    if cur.stopNow then
        debug("stop now: reading without the quiet")
        return read()
    end
    local from, last = cur.quietFrom, cur.timeline:LastDamage()
    if last and last > from then from = last end
    if t - from < NS.Scoring.QUIET_BEFORE_READ then return end
    debug("quiet for %.2fs since %.2f: reading", t - from, from)
    read()
end

--- One readiness poll. A combat end whose regen edge was never heard (it dropped while the addon was
--- stood down, or during a /reload's loading screen) is noticed here, so no run waits forever for an
--- edge that already went: out of combat with no quiet counting yet, the quiet counts from now.
local function poll()
    if isDown() then return end
    local t = GetTime()
    if state == STATE.STOPPING and not cur.quietFrom and not UnitAffectingCombat("player") then
        debug("out of combat with no regen edge heard: the quiet counts from %.2f", t)
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
    debug("stopping: waiting for combat to end and %.1fs of quiet", NS.Scoring.QUIET_BEFORE_READ)
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
    debug("buzzer at %.2f", cur.buzzerAt)
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
    debug("combat ended before the buzzer, at +%.2f: incomplete", cur.run.result.endedAt)
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
--- @return boolean ok
--- @return string|nil reason  "in_combat" | "meter_unavailable" | "pending" | "busy" |
---                            "bad_length" | "disabled"
--- @return string|nil detail  for "meter_unavailable": Blizzard's own reason, verbatim
local function armRefusal(length)
    if isDown() then return "disabled" end
    local refusal = stateRefusal()
    if refusal then return refusal end
    if not validLength(length) then return "bad_length" end
    if UnitAffectingCombat("player") then return "in_combat" end
    local ok, why = NS.Meter.IsAvailable()
    if not ok then return "meter_unavailable", why end
    return nil
end

-- What session `id` holds now (the arm is out of combat, so the read is plain): its damage and each
-- spell's, summed by spell ID. nil when there is no such session or the read fails. Only consulted if
-- the pull carries on that session instead of making a new one (see share).
local function baselineOf(id)
    if id == nil then return nil end
    local data = NS.Meter.ReadSession(id)
    if not data then return nil end
    local spells = {}
    for _, s in ipairs(data.spells) do spells[s.id] = (spells[s.id] or 0) + s.dmg end
    return { session = id, damage = data.damage, spells = spells }
end

function Race.Arm(length)
    local refusal, detail = armRefusal(length)
    if refusal then
        debug("arm refused: %s", refusal)
        return false, refusal, detail
    end
    newRace(NS.Recorder.NewRun(length))
    cur.armTarget = cur.run.target
    -- The fallback loadout (#6), held in memory: gear can still change before the pull, so the one
    -- stored is the combat-end snapshot (OnCombatEnd), and this only when there is none.
    cur.armLoadout = NS.Recorder.SnapshotLoadout()
    -- The cast list (#14) is heard from now (a pre-pull cast counts), and what could be used (#13) is
    -- read now, out of combat, and held until the result.
    NS.Casts.Begin()
    cur.usageSnap = NS.Usage.Snapshot()
    -- Every session the client holds now belongs to an earlier fight: never this run's. The newest of
    -- them is kept on the run, so a /reload (which loses the set) still knows.
    cur.armSet = NS.Meter.SessionIDs()
    local mark
    for id in pairs(cur.armSet) do
        if mark == nil or id > mark then mark = id end
    end
    cur.run.race.armMaxSession = mark
    cur.baseline = baselineOf(mark)
    debug("armed %ds; newest session before the arm: %s", length, tostring(mark))
    setState(STATE.ARMED)
    return true
end

-- Capture the run's session, unless it existed before the arm (another fight's).
local function adopt(id)
    if beforeArm(id) then
        debug("session %d ignored: it existed before the arm", id)
        return
    end
    debug("session %d adopted", id)
    cur.run.race.sessionID = id
    NS.Recorder.Save(cur.run)
end

-- The pull carried on session `id`, which existed at the arm: the meter made no new session for it
-- (the last fight's DoTs were still ticking, so its session stayed open). It is the only session the
-- race's damage lands in, so it is adopted, flagged, and netted at the read against what it held at
-- the arm. A session made after the arm, heard later, replaces it (unshare).
local function share(id)
    local run, base = cur.run, cur.baseline
    run.race.sessionID = id
    run.flags.sharedSession = true
    run.race.baseline = (base and base.session == id) and base or nil
    debug("session %d existed before the arm: adopted as shared (%s)", id,
        run.race.baseline and "netted at the read" or "no baseline")
    NS.Recorder.Save(run)
end

local function unshare(id)
    local run = cur.run
    debug("session %d replaces the shared session %s", id, tostring(run.race.sessionID))
    run.race.sessionID = id
    run.flags.sharedSession = nil
    run.race.baseline = nil
    NS.Recorder.Save(run)
end

-- The clock starts at `t`.
local function begin(t)
    local run = cur.run
    run.status = "running"
    run.date = time()
    run.race.startedAt = t
    cur.startedAt = t
    NS.Casts.Start(t)
    -- Only an update heard in combat, or on this frame, is this pull's (see stashUpdate).
    if cur.stash and (cur.stashHeld or cur.stashAt == t) then
        adopt(cur.stash)
        if run.race.sessionID then stamp(t) end
    end
    debug("clock started at %.2f", t)
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

-- The target re-read when combat starts: the one fought, over the one armed against.
local function rereadTarget()
    local run = cur.run
    local prior = cur.armTarget or run.target or {}
    local fresh = NS.Recorder.SnapshotTarget("target", prior)
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
        -- The session event, or a DamageDone update, heard on this frame just before the edge.
        if cur.sessionAt == t or (cur.stash and cur.stashAt == t) then begin(t) end
    elseif state == STATE.STOPPING then
        cur.combatEndedAt, cur.quietFrom = nil, nil
    end
    debug("combat start at %.2f in %s", t or 0, state)
end

--- Combat ends: before the buzzer the run is incomplete; after it, the read waits for the quiet.
function Race.OnCombatEnd(t)
    if isDown() then return end
    if state == STATE.ARMED then
        -- A combat that never started the clock: the next one re-reads the target and pairs anew.
        cur.reread, cur.combatAt = nil, nil
        return
    end
    if state == STATE.RUNNING then endEarly(t) end
    if state ~= STATE.STOPPING then return end
    -- Out of combat, beside the read: exactly what raced (gear and talents cannot change in combat;
    -- a weapon swap in combat is the one exception). Replaces any earlier snapshot.
    NS.Loadouts.Attach(cur.run, NS.Recorder.SnapshotLoadout())
    debug("combat ended at %.2f: the quiet counts from it", t)
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

-- A DamageDone update heard while armed, kept for the start. One heard in combat (or on the regen
-- edge's frame) is this pull's and holds; one heard out of combat (a groupmate's pull, a trailing
-- update) counts only if the clock starts on its own frame, and a later update replaces it.
local function inCombatAt(t)
    return UnitAffectingCombat("player") or cur.combatAt == t
end

local function stashUpdate(id, t)
    if beforeArm(id) then
        debug("update for session %d held back: it existed before the arm", id)
        return
    end
    if cur.stash and cur.stashHeld then return end
    cur.stash, cur.stashAt, cur.stashHeld = id, t, inCombatAt(t) and true or false
end

-- A DamageDone update heard in combat while armed: damage is landing, so the clock starts now, whether
-- or not the session event paired with the regen edge. The meter can make the run's session out of
-- combat (a DoT left on the dummies ticks after the last fight's session closed, or the opener lands a
-- frame before the edge), and then no session event ever pairs. The update's own session is adopted;
-- one that existed at the arm is shared (see share).
local function startOnUpdate(id, t)
    begin(t)
    local run = cur.run
    if run.race.sessionID then return end
    if beforeArm(id) then share(id) else adopt(id) end
    if run.race.sessionID then stamp(t) end
end

--- A DAMAGE_METER_COMBAT_SESSION_UPDATED(statType, sessionID). The first DamageDone update with a
--- non-zero ID names the run's session (spec §4.2); every update for it is a stamp on the timeline.
function Race.OnMeterUpdate(statType, sessionID, t)
    if isDown() then return end
    local stat, id = Secrets.PlainNumber(statType), Secrets.PlainNumber(sessionID)
    if stat ~= NS.Meter.STAT_DAMAGE_DONE or not id or id == 0 then return end
    if state == STATE.ARMED then
        stashUpdate(id, t)
        if inCombatAt(t) then startOnUpdate(id, t) end
        return
    end
    if state ~= STATE.RUNNING and state ~= STATE.STOPPING then return end
    local run = cur.run
    if not run.race.sessionID then adopt(id) end
    if run.flags.sharedSession and id ~= run.race.sessionID and not beforeArm(id) then unshare(id) end
    if id == run.race.sessionID then stamp(t) end
end

-- ── casts after the buzzer (spec §5.2) ──────────────────────────────────────────────────────────

local function judge(spellID, t)
    if state ~= STATE.STOPPING or not cur.buzzerAt then return end
    local run = cur.run
    local offset = t - cur.buzzerAt
    if not NS.Scoring.IsLateCast(offset, run.race.grace) then return end
    local list = run.flags.lateCasts
    list[#list + 1] = { t = round2(offset), spellID = spellID }
    debug("late cast %s at +%.2f", tostring(spellID), offset)
end

-- Spells whose success repeats on its own once started (Auto Shot, a wand's Shoot): never a press.
Race.AUTO_REPEAT = { [75] = true, [5019] = true }

-- Whether an auto-repeat spell is repeating now: what a success with a sealed spell ID is taken as.
local function autoRepeating()
    local api = C_Spell and C_Spell.IsAutoRepeatSpell
    if type(api) ~= "function" then return false end
    for id in pairs(Race.AUTO_REPEAT) do
        local ok, on = pcall(api, id)
        if ok and Secrets.PlainTruth(on) then return true end
    end
    return false
end

-- Whether a cast event is the cast in flight's own: by castGUID when both are readable, else by
-- spell ID when both are, else assumed so (the player casts one spell at a time).
local function isInFlight(guid, id)
    local f = cur.inFlight
    if not f then return false end
    if f.guid and guid then return f.guid == guid end
    if f.id and id then return f.id == id end
    return true
end

local function onSucceeded(id, guid, t)
    if isInFlight(guid, id) then
        cur.inFlight = nil
        return
    end
    if id and Race.AUTO_REPEAT[id] then return end
    if not id and autoRepeating() then return end
    judge(id, t)
end

--- A player cast: kind "start" | "channel" | "succeeded" | "interrupted" | "channelStop", with the
--- event's spell ID and castGUID (either may be secret: each passes through NS.Secrets and only a
--- plain copy is compared or stored). A cast counts at its start; a success with no start in flight
--- (an instant) counts at its own time, and the in-flight cast's own success is that cast finishing,
--- judged already. An interrupt clears the cast in flight, so a later instant of the same spell is
--- judged; a channel's stop clears a channel. Starts are tracked from RUNNING, so a cast begun before
--- the buzzer and finished after it is never late; an auto-repeat's success is never a press.
function Race.OnCast(kind, spellID, t, castGUID)
    if isDown() or (state ~= STATE.RUNNING and state ~= STATE.STOPPING) then return end
    local id, guid = Secrets.PlainNumber(spellID), Secrets.PlainString(castGUID)
    if kind == "start" or kind == "channel" then
        cur.inFlight = { id = id, guid = guid, channel = kind == "channel" }
        judge(id, t)
    elseif kind == "succeeded" then
        onSucceeded(id, guid, t)
    elseif kind == "interrupted" or (kind == "channelStop" and cur.inFlight and cur.inFlight.channel) then
        if isInFlight(guid, id) then cur.inFlight = nil end
    end
end

--- DAMAGE_METER_RESET: a run in progress loses its session (spec §4.5).
function Race.OnMeterReset()
    if isDown() then return end
    if state == STATE.ARMED then
        cur.armSet, cur.stash, cur.stashHeld = {}, nil, nil
        cur.run.race.armMaxSession = nil
    elseif state == STATE.RUNNING or state == STATE.STOPPING then
        lose("meter reset")
    end
end

-- ── stop now ────────────────────────────────────────────────────────────────────────────────────

--- *Stop now* on the Stop! and waiting screens (Round C, 2026-10-25): take the result as it reads now
--- instead of waiting out the damage tail. It goes through the normal read (read, score, save,
--- RACE_RESULT), with the 2.5s quiet waived; damage that lands after the read is not counted. Out of
--- combat the read runs at once (a still-sealed read retries on the poll, as ever); in combat nothing
--- can be read (every meter value is secret), so the read runs on the regen edge, with no quiet after
--- it. Nothing here looks at a meter value: the decision is the press, the combat flag and GetTime().
--- @return boolean acted
function Race.StopNow()
    if isDown() or state ~= STATE.STOPPING then return false end
    cur.stopNow = true
    local t = GetTime()
    if not UnitAffectingCombat("player") then
        cur.quietFrom = cur.quietFrom or t
        debug("stop now at %.2f: reading", t)
        checkReady(t)
    else
        debug("stop now at %.2f in combat: reading at the combat end", t)
    end
    return true
end

--- Whether *Stop now* was pressed for the run waiting for its read (the HUD says it reads at the
--- combat end).
function Race.StopRequested()
    return state == STATE.STOPPING and cur.stopNow == true
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
    NS.Casts.Reset()
    setState(STATE.IDLE)
    cur = {}
    return true
end

-- ── stand-down, stand-up and the /reload resume ─────────────────────────────────────────────────

--- The lifecycle's stand-down: drop the in-memory race and its timers, silently. A run already stored
--- stays as it is, and Resume carries it on at the stand-up.
function Race.Suspend()
    cancelTimers()
    NS.Casts.Reset()
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
-- than now (the edge's real time is unknowable).
local function resumeRunning(run, now)
    local elapsed = now - cur.startedAt
    local left = run.race.length - elapsed
    if left > 0 and UnitAffectingCombat("player") then
        debug("resumed running, %.2fs left", left)
        setState(STATE.RUNNING)
        armBuzzer(left)
        return true
    end
    if left > 0 then run.result = { endedAt = round2(elapsed) } end
    run.status = "stopping"
    NS.Recorder.Save(run)
    return false
end

local function resumeRun(run, now)
    newRace(run)
    cur.startedAt = startOf(run, now)
    cur.reread, cur.resumedAt = true, now
    -- The last update before the reload, so the tail and a restart gap still measure from it.
    local last = Secrets.PlainNumber(run.race.lastDamage)
    if last then cur.timeline:AddDamage(cur.startedAt + last) end
    local id = run.race.sessionID
    if id ~= nil and not NS.Meter.HasSession(id) then return lose("session gone") end
    if run.status == "running" and resumeRunning(run, now) then return end
    -- Past its buzzer and not yet read: what was cast during the reload went unseen (spec §4.5).
    if not (run.result and run.result.endedAt) then
        cur.buzzerAt = cur.startedAt + run.race.length
        run.flags.reloaded = true
    end
    debug("resumed stopping (%s)", cur.buzzerAt and "past the buzzer, reloaded" or "incomplete")
    setState(STATE.STOPPING)
    startPolling()
    -- Combat already over (spec §4.5): read straight away. The quiet was spent during the reload.
    if not UnitAffectingCombat("player") then
        cur.quietFrom = now - NS.Scoring.QUIET_BEFORE_READ
        checkReady(now)
    end
end

--- Carry on the runs a /reload (or a stand-down) left running or stopping. Called from OnEnable and
--- from the lifecycle's stand-up. Only the logged-in character's runs are pending here (another
--- character's waits for that character). The newest is followed; an older one (two cannot be
--- pending) is settled as lost.
function Race.Resume()
    if isDown() or state ~= STATE.IDLE then return end
    local pending = NS.Recorder.Pending()
    local n = #pending
    if n == 0 then return end
    for i = 1, n - 1 do
        debug("older pending run %s settled as lost", tostring(pending[i].id))
        pending[i].status, pending[i].result = "lost", nil
        NS.Recorder.Save(pending[i])
    end
    resumeRun(pending[n], GetTime())
end
