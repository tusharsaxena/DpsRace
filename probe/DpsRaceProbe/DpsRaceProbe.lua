-- DpsRaceProbe: throwaway feasibility probe for Ka0s DPS Race.
--
-- Answers six questions in-game (see README.md):
--   Q1 does C_DamageMeter record duel damage (attacker and target side)?
--   Q2 what does a session's durationSeconds measure?
--   Q3 does a secret captured mid-combat become readable after combat?
--   Q4 is UNIT_HEALTH / UNIT_COMBAT a usable "first hit" signal, and are
--      DUEL_FINISHED and the defeat message clean (not secret)?
--   Q5 does DAMAGE_METER_CURRENT_SESSION_UPDATED fire on the first hit, how often?
--   Q6 can addon messages be sent right after a duel?
--
-- Rule of the file: no value that may be secret is ever compared, added, used as
-- a key or tostring'd. Everything that touches a game value goes through show(),
-- and every read is pcall'd. Decisions are made from events and GetTime() only.

local ADDON = ...
local PREFIX = "DPSRP"
local MAX_RUNS = 30
local MAX_LINES = 600

local DM = C_DamageMeter
local SESSION_CURRENT = (Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current) or 1
local STAT = {
    DamageDone       = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone) or 0,
    DamageTaken      = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageTaken) or 7,
    EnemyDamageTaken = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.EnemyDamageTaken) or 10,
}

local db            -- DpsRaceProbeDB
local run           -- the active run, or nil
local lastRun       -- the most recent run, kept for /drp ping after it closes
local partner       -- addon-message partner, "Name-Realm"

-------------------------------------------------------------------------------
-- Secret-safe helpers
-------------------------------------------------------------------------------

local function isSecret(v)
    if issecretvalue then
        local ok, r = pcall(issecretvalue, v)
        if ok then return r and true or false end
        return true
    end
    return false
end

local function canAccess(v)
    if canaccessvalue then
        local ok, r = pcall(canaccessvalue, v)
        if ok then return r and true or false end
        return false
    end
    return not isSecret(v)
end

local function canTable(t)
    if type(t) ~= "table" then return false end
    if canaccesstable then
        local ok, r = pcall(canaccesstable, t)
        if ok then return r and true or false end
        return false
    end
    return true
end

-- Never returns a secret: secrets become a literal marker.
local function show(v)
    if isSecret(v) then return "<secret:" .. type(v) .. ">" end
    if v == nil then return "nil" end
    if type(v) == "table" and not canTable(v) then return "<sealed table>" end
    local ok, s = pcall(tostring, v)
    return ok and s or "<tostring failed>"
end

-- A number we may do arithmetic on, or nil.
local function plainNumber(v)
    if v == nil or isSecret(v) or not canAccess(v) then return nil end
    if type(v) ~= "number" then return nil end
    local ok = pcall(function() return v + 0 end)
    return ok and v or nil
end

local function now() return GetTime() end
local function precise() return GetTimePreciseSec and GetTimePreciseSec() or GetTime() end

local function fmt(x) return x and string.format("%.3f", x) or "-" end

local function chat(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99DRP|r " .. msg)
end

-------------------------------------------------------------------------------
-- Logging
-------------------------------------------------------------------------------

local function glog(msg)
    if not db then return end
    local g = db.globalLog
    g[#g + 1] = string.format("%s %s", fmt(now()), msg)
    if #g > 400 then table.remove(g, 1) end
end

local function rlog(msg)
    glog(msg)
    if not run then return end
    local base = run.t.start or run.t.armed
    if #run.log < MAX_LINES then
        run.log[#run.log + 1] = string.format("%+8.3f %s", now() - base, msg)
    end
end

local function mark(name)
    if not run then return end
    if run.t[name] == nil then
        run.t[name] = now()
        run.tp[name] = precise()
        rlog("MARK " .. name)
    end
end

local function noteError(where, err)
    rlog("ERROR " .. where .. ": " .. show(err))
    if run then
        run.errors[where] = (run.errors[where] or 0) + 1
    end
end

-------------------------------------------------------------------------------
-- Generic dumper (discovers the shape of C_DamageMeter returns)
-------------------------------------------------------------------------------

local function dumpInto(lines, label, v, depth)
    if #lines >= 400 then return end
    if isSecret(v) then
        lines[#lines + 1] = label .. " = <secret:" .. type(v) .. ">"
        return
    end
    if type(v) ~= "table" then
        lines[#lines + 1] = label .. " = " .. show(v)
        return
    end
    if not canTable(v) then
        lines[#lines + 1] = label .. " = <sealed table>"
        return
    end
    if depth <= 0 then
        lines[#lines + 1] = label .. " = {...}"
        return
    end
    local keys = {}
    local ok, err = pcall(function()
        for k in pairs(v) do
            if #keys < 60 then keys[#keys + 1] = k end
        end
    end)
    if not ok then
        lines[#lines + 1] = label .. " = <pairs failed: " .. show(err) .. ">"
        return
    end
    pcall(table.sort, keys, function(a, b)
        if type(a) == type(b) and (type(a) == "number" or type(a) == "string") then return a < b end
        return type(a) < type(b)
    end)
    if #keys == 0 then lines[#lines + 1] = label .. " = {}" end
    for _, k in ipairs(keys) do
        local okv, child = pcall(function() return v[k] end)
        if okv then
            dumpInto(lines, label .. "." .. show(k), child, depth - 1)
        else
            lines[#lines + 1] = label .. "." .. show(k) .. " = <index failed>"
        end
    end
end

-- Iterates an array without `#` or ipairs; stops at the first nil or failure.
local function safeEach(arr, fn)
    if not canTable(arr) then return 0, "sealed" end
    local n = 0
    for i = 1, 512 do
        local ok, e = pcall(function() return arr[i] end)
        if not ok then return n, "index failed" end
        if e == nil then break end
        n = n + 1
        fn(i, e)
    end
    return n
end

-------------------------------------------------------------------------------
-- Damage meter reads
-------------------------------------------------------------------------------

local function sessionList()
    local out = {}
    if not (DM and DM.GetAvailableCombatSessions) then return out end
    local ok, list = pcall(DM.GetAvailableCombatSessions)
    if not ok then return out end
    safeEach(list, function(_, e)
        if canTable(e) then
            out[#out + 1] = { id = show(e.sessionID), name = show(e.name), dur = show(e.durationSeconds) }
        end
    end)
    return out
end

local function sessionIdSet(list)
    local s = {}
    for _, e in ipairs(list or {}) do s[e.id] = true end
    return s
end

local function readSession(stat)
    if not (DM and DM.GetCombatSessionFromType) then return nil, "no API" end
    local ok, s = pcall(DM.GetCombatSessionFromType, SESSION_CURRENT, stat)
    if not ok then return nil, show(s) end
    return s
end

local function readSource(stat, guid, creatureID)
    if not (DM and DM.GetCombatSessionSourceFromType) then return nil, "no API" end
    local ok, s = pcall(DM.GetCombatSessionSourceFromType, SESSION_CURRENT, stat, guid, creatureID)
    if not ok then return nil, show(s) end
    return s
end

local function localPlayerRow(session)
    local row
    if not canTable(session) then return nil end
    safeEach(session.combatSources, function(_, e)
        if row == nil and canTable(e) then
            local ok, isMe = pcall(function() return e.isLocalPlayer == true end)
            if ok and isMe then row = e end
        end
    end)
    return row
end

-- Full discovery dump of the Current session, for every stat we care about.
local function fullRead(label)
    if not run then return end
    local lines = {}
    lines[#lines + 1] = string.format("== read '%s' at t=%s combat=%s restricted=%s", label,
        fmt(now() - (run.t.start or run.t.armed)), show(InCombatLockdown()),
        show(C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
            and select(2, pcall(C_RestrictedActions.IsAddOnRestrictionActive,
                Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Combat or 0))))
    local ok, dur = pcall(function() return DM.GetSessionDurationSeconds(SESSION_CURRENT) end)
    lines[#lines + 1] = "GetSessionDurationSeconds(Current) = " .. (ok and show(dur) or ("error " .. show(dur)))

    local myGUID = UnitGUID("player")
    for statName, stat in pairs(STAT) do
        local s, err = readSession(stat)
        if s == nil then
            lines[#lines + 1] = statName .. ": nil " .. show(err)
        else
            -- one level for the session, then sources in detail
            local top = {}
            dumpInto(top, statName, s, 1)
            for _, l in ipairs(top) do lines[#lines + 1] = l end
            if canTable(s) then
                safeEach(s.combatSources, function(i, src)
                    dumpInto(lines, statName .. ".src[" .. i .. "]", src, 1)
                    if canTable(src) then
                        local guid, cid = src.sourceGUID, src.sourceCreatureID
                        local detail, derr = readSource(stat, guid, cid)
                        if detail == nil then
                            lines[#lines + 1] = "  detail: nil " .. show(derr)
                        else
                            dumpInto(lines, statName .. ".src[" .. i .. "].detail", detail, 4)
                        end
                    end
                end)
            end
        end
        -- Also ask for the local player by our own (non-secret) GUID.
        local mine, merr = readSource(stat, myGUID, nil)
        if mine == nil then
            lines[#lines + 1] = statName .. ".byMyGUID: nil " .. show(merr)
        else
            dumpInto(lines, statName .. ".byMyGUID", mine, 3)
        end
    end
    lines[#lines + 1] = "sessions:"
    for _, e in ipairs(sessionList()) do
        lines[#lines + 1] = string.format("  id=%s name=%s dur=%s", e.id, e.name, e.dur)
    end
    run.reads[#run.reads + 1] = lines
    rlog("READ " .. label .. " (" .. #lines .. " lines)")
end

-------------------------------------------------------------------------------
-- Q3: the snapshot of secrets at the buzzer
-------------------------------------------------------------------------------

local snap  -- runtime only: raw values, possibly secret

local function takeSnapshot()
    snap = {}
    local s = readSession(STAT.DamageDone)
    local row = localPlayerRow(s)
    if row then
        snap.total = row.totalAmount
        snap.aps = row.amountPerSecond
    end
    if canTable(s) then snap.sessionDuration = s.durationSeconds end
    local ok, d = pcall(function() return DM.GetSessionDurationSeconds(SESSION_CURRENT) end)
    if ok then snap.apiDuration = d end
    local mine = readSource(STAT.DamageDone, UnitGUID("player"), nil)
    if canTable(mine) then snap.spells = mine.combatSpells end
    snap.t = now()

    local info = {}
    for k, v in pairs(snap) do
        info[k] = { secretAtCapture = isSecret(v), value = show(v) }
    end
    info.rowFound = row ~= nil
    run.snapshot = info
    rlog("SNAPSHOT taken: rowFound=" .. show(row ~= nil) .. " totalSecret=" .. show(isSecret(snap.total)))

    if db.svtest then
        -- Deliberately hands raw (possibly secret) values to SavedVariables.
        DpsRaceProbeSecretDB = { at = date("%Y-%m-%d %H:%M:%S"), total = snap.total,
            aps = snap.aps, sessionDuration = snap.sessionDuration }
        rlog("SVTEST raw values assigned to DpsRaceProbeSecretDB")
    end
end

local function testSnapshotLater(label)
    if not (run and snap and run.snapshot) then return end
    local res = {}
    for k, v in pairs(snap) do
        if k ~= "t" and k ~= "spells" then
            local okArith, sum = pcall(function() return v + 0 end)
            res[k] = string.format("secretNow=%s canAccess=%s arith=%s value=%s",
                show(isSecret(v)), show(canAccess(v)), show(okArith),
                okArith and show(sum) or "-")
        end
    end
    if snap.spells ~= nil then
        res.spells = string.format("tableAccessibleNow=%s", show(canTable(snap.spells)))
    end
    run.snapshot["after_" .. label] = res
    rlog("SNAPSHOT retest " .. label .. ": total " .. (res.total or "n/a"))
end

-------------------------------------------------------------------------------
-- Run lifecycle
-------------------------------------------------------------------------------

local frame = CreateFrame("Frame", "DpsRaceProbeFrame", UIParent, "BackdropTemplate")
local timerFS, liveFS, statusFS
local buzzerTimer

local function targetMetaRaw()
    local m = {}
    local exists = UnitExists("target")
    m.exists = (not isSecret(exists)) and exists and true or false
    if m.exists then
        m.name = show(UnitName("target"))
        local guid = UnitGUID("target")
        m.guid = show(guid)
        if not isSecret(guid) and guid then
            local unitType, _, _, _, _, npcID = strsplit("-", guid)
            m.unitType, m.npcID = unitType, npcID
        end
        m.isPlayer = show(UnitIsPlayer("target"))
        m.level = show(UnitLevel("target"))
        m.classification = show(UnitClassification("target"))
        m.healthMax = show(UnitHealthMax("target"))
        m.health = show(UnitHealth("target"))
    end
    return m
end

local function targetMeta()
    local ok, m = pcall(targetMetaRaw)
    if ok then return m end
    return { exists = false, error = show(m) }
end

local function playerMeta()
    local m = {}
    m.name, m.realm = UnitFullName("player")
    m.class = select(2, UnitClass("player"))
    local spec = GetSpecialization and GetSpecialization()
    if spec then
        local id, specName = GetSpecializationInfo(spec)
        m.specID, m.spec = id, specName
    end
    local overall, equipped = GetAverageItemLevel()
    m.ilvl, m.ilvlEquipped = overall, equipped
    m.zone, m.subzone = GetZoneText(), GetSubZoneText()
    m.mapID = C_Map.GetBestMapForUnit("player")
    local iname, itype = GetInstanceInfo()
    m.instance, m.instanceType = iname, itype
    m.build = select(4, GetBuildInfo())
    return m
end

local function newRun(kind, duration)
    run = {
        kind = kind, duration = duration,
        date = date("%Y-%m-%d %H:%M:%S"),
        t = {}, tp = {}, counts = {}, log = {}, reads = {}, errors = {},
        id = string.format("%d-%d", time(), math.random(1000, 9999)),
        meter = { n = 0, intervals = 0, maxGap = 0 },
        dm = { timeline = {} },
        live = { ok = 0, sealed = 0, noRow = 0, spellsShown = 0 },
        player = playerMeta(), target = targetMeta(),
        sessionsBefore = sessionList(),
    }
    run.t.armed = now()
    run.tp.armed = precise()
    snap = nil
    lastRun = run
    table.insert(db.runs, run)
    while #db.runs > MAX_RUNS do table.remove(db.runs, 1) end

    pcall(function()
        if run.target.exists and UnitIsPlayer("target") then
            partner = GetUnitName("target", true)
            if partner and not partner:find("-") then partner = partner .. "-" .. GetNormalizedRealmName() end
        end
    end)
    rlog(string.format("ARMED %s duration=%s target=%s partner=%s", kind, show(duration),
        run.target.name or "none", show(partner)))
    chat(string.format("armed %s run%s. Target: %s. Partner: %s", kind,
        duration and (" (" .. duration .. "s)") or "", run.target.name or "none", partner or "none"))
    frame:Show()
end

-- Test D: when did this run's own DamageDone stop changing, relative to the buzzer,
-- and did it resume after an idle gap (contamination)?
local RESUME_GAP = 4

-- The run's own DamageDone updates after the buzzer: how many, the last, and the first resume
-- after an idle gap; updates of other types or sessions are only counted.
local function scanAfterBuzzer(timeline, buzz, sid)
    local d = { afterBuzzer = 0, otherTypesAfterBuzzer = 0, otherSessionsAfterBuzzer = 0 }
    local prev = buzz
    for _, e in ipairs(timeline) do
        if e.t > buzz then
            if e.id ~= sid then
                d.otherSessionsAfterBuzzer = d.otherSessionsAfterBuzzer + 1
            elseif e.ty ~= STAT.DamageDone then
                d.otherTypesAfterBuzzer = d.otherTypesAfterBuzzer + 1
            else
                d.afterBuzzer = d.afterBuzzer + 1
                local gap = e.t - prev
                if gap > RESUME_GAP and prev > buzz and not d.resumedAt then
                    d.resumedAt = e.t - buzz
                    d.resumeGap = gap
                end
                prev = e.t
                d.lastUpdate = e.t - buzz
            end
        end
    end
    return d
end

-- Updates per stat type over the whole run, to see which types are noise.
local function countByType(timeline, sid)
    local byType = {}
    for _, e in ipairs(timeline) do
        if e.id == sid then
            local k = tostring(e.ty)
            byType[k] = (byType[k] or 0) + 1
        end
    end
    return byType
end

local function damageStopVerdict(d)
    return string.format("damage stopped %s after buzzer (last cast %s, casts after %d); resumed after idle gap: %s",
        d.lastUpdate and string.format("+%.2fs", d.lastUpdate) or "before/at buzzer",
        d.lastCast and string.format("%+.2fs", d.lastCast) or "-", d.castsAfterBuzzer,
        d.resumedAt and string.format("YES at +%.2fs after a %.1fs gap", d.resumedAt, d.resumeGap) or "no")
end

local function analyzeDamageStop(r)
    local buzz, sid = r.t.buzzer, r.sessionID
    if not (buzz and sid) then
        r.damageStop = { verdict = "n/a (buzzer=" .. show(buzz) .. " sessionID=" .. show(sid) .. ")" }
        return
    end
    local d = scanAfterBuzzer(r.dm.timeline, buzz, sid)
    d.byType = countByType(r.dm.timeline, sid)
    d.lastCast = r.t.lastCast and (r.t.lastCast - buzz) or nil
    d.castsAfterBuzzer = r.castsAfterBuzzer or 0
    d.verdict = damageStopVerdict(d)
    r.damageStop = d
end

-- The summary's timing lines: when the run started and ended, relative to its start.
local function summaryTiming(r, out)
    local t = r.t
    local start = t.start
    local function rel(name) return (t[name] and start) and fmt(t[name] - start) or "-" end
    out[#out + 1] = string.format("[%s] %s run, %s", r.date, r.kind, r.duration and (r.duration .. "s") or "duel")
    out[#out + 1] = string.format("start=%s (first of meter/unit signals). relative: regenOn=%s firstCast=%s firstMeter=%s firstUnitCombat=%s firstHealthTarget=%s firstHealthPlayer=%s",
        start and "yes" or "NEVER", rel("regenDisabled"), rel("firstCast"), rel("firstMeterUpdate"),
        rel("firstUnitCombat"), rel("firstHealth_target"), rel("firstHealth_player"))
    out[#out + 1] = string.format("end: buzzer=%s duelFinished=%s defeatMsg=%s lastMeter=%s regenOff=%s",
        rel("buzzer"), rel("duelFinished"), rel("defeatMessage"), rel("lastMeterUpdate"), rel("regenEnabled"))
    local m = r.meter
    out[#out + 1] = string.format("meter events: %d, avg interval %s, max gap %s", m.n,
        m.n > 1 and fmt(m.intervals / (m.n - 1)) or "-", fmt(m.maxGap))
end

-- The summary's duration comparison: the meter's own duration against ours.
local function summaryDuration(r, out)
    local t = r.t
    if r.finalDuration then
        out[#out + 1] = string.format("durationSeconds(post)=%s | ours: firstMeter->lastMeter=%s regenOn->regenOff=%s firstMeter->regenOff=%s",
            r.finalDuration,
            (t.firstMeterUpdate and t.lastMeterUpdate) and fmt(t.lastMeterUpdate - t.firstMeterUpdate) or "-",
            (t.regenDisabled and t.regenEnabled) and fmt(t.regenEnabled - t.regenDisabled) or "-",
            (t.firstMeterUpdate and t.regenEnabled) and fmt(t.regenEnabled - t.firstMeterUpdate) or "-")
    end
end

-- The summary's outcome lines: the session, the result, the live display and the test verdicts.
local function summaryOutcome(r, out)
    if r.newSession ~= nil then
        out[#out + 1] = "new meter session created by this run: " .. show(r.newSession)
    end
    if r.result then
        out[#out + 1] = string.format("result: myDamageDone=%s myDamageTaken=%s doneSpells=%s takenSpells=%s",
            show(r.result.done), show(r.result.taken), show(r.result.doneSpells), show(r.result.takenSpells))
    end
    if r.snapshot and r.snapshot.after_final then
        out[#out + 1] = "snapshot after combat: total " .. (r.snapshot.after_final.total or "n/a")
    end
    out[#out + 1] = string.format("live display: ok=%d sealed=%d noRow=%d spellsShown=%d err=%s",
        r.live.ok, r.live.sealed, r.live.noRow, r.live.spellsShown, show(r.live.firstError))
    out[#out + 1] = string.format("|cffffff00TEST D|r session=%s: %s", show(r.sessionID),
        r.damageStop and r.damageStop.verdict or "-")
    out[#out + 1] = "|cffffff00TEST ById|r " .. (r.byId and r.byId.verdict or "-")
    if r.resumedAfterReload then
        out[#out + 1] = "|cffffff00TEST E|r resumed after /reload: " .. (r.reloadVerdict or "-")
    end
end

local function summarize(r)
    local out = {}
    summaryTiming(r, out)
    summaryDuration(r, out)
    summaryOutcome(r, out)
    return out
end

-- Q1: did this run create a session? Compares the session list now with the one at arm time.
local function createdSession(before, after)
    local seen = sessionIdSet(before)
    local created = false
    for _, e in ipairs(after) do if not seen[e.id] then created = true end end
    return created
end

-- The Current session's totals and spell counts for the player, as plain copies.
local function readResult()
    local res = {}
    local done = readSession(STAT.DamageDone)
    if canTable(done) then
        run.finalDuration = show(done.durationSeconds)
        local row = localPlayerRow(done)
        if row then res.done = row.totalAmount end
    end
    local taken = readSession(STAT.DamageTaken)
    local trow = localPlayerRow(taken)
    if trow then res.taken = trow.totalAmount end
    local mineDone = readSource(STAT.DamageDone, UnitGUID("player"), nil)
    if canTable(mineDone) then res.doneSpells = (safeEach(mineDone.combatSpells, function() end)) end
    local mineTaken = readSource(STAT.DamageTaken, UnitGUID("player"), nil)
    if canTable(mineTaken) then res.takenSpells = (safeEach(mineTaken.combatSpells, function() end)) end
    return res
end

-- The by-ID read's one-line verdict: its total against Current's (cur).
local function byIdVerdict(sid, b, cur)
    return string.format("id=%s inList=%s total=%s current=%s -> %s, spells=%s, duration=%s",
        show(sid), show(b.presentInList), show(b.total), show(cur),
        (b.total and cur) and (b.total == cur and "MATCH" or "MISMATCH") or "unreadable",
        show(b.spells), show(b.duration))
end

-- Read the run's own session by ID and compare with Current.
local function readById(sid, after, res)
    local b = {}
    if not (sid and DM and DM.GetCombatSessionFromID) then
        b.verdict = "no sessionID captured"
        return b
    end
    local present = false
    for _, e in ipairs(after) do if e.id == tostring(sid) then present = true end end
    b.presentInList = present
    local ok, s = pcall(DM.GetCombatSessionFromID, sid, STAT.DamageDone)
    if ok and canTable(s) then
        local row = localPlayerRow(s)
        b.total = row and plainNumber(row.totalAmount)
        b.duration = plainNumber(s.durationSeconds)
    else
        b.error = show(s)
    end
    local okSrc, src = pcall(DM.GetCombatSessionSourceFromID, sid, STAT.DamageDone, UnitGUID("player"), nil)
    if okSrc and canTable(src) then b.spells = (safeEach(src.combatSpells, function() end)) end
    b.verdict = byIdVerdict(sid, b, plainNumber(res.done))
    return b
end

local function finalizeResult()
    if not run then return end
    local after = sessionList()
    run.sessionsAfter = after
    run.newSession = createdSession(run.sessionsBefore, after)

    local res = readResult()
    -- store plain copies only
    run.result = { done = show(res.done), taken = show(res.taken),
        doneSpells = res.doneSpells, takenSpells = res.takenSpells }

    if snap then
        testSnapshotLater("final")
        local final, early = plainNumber(res.done), plainNumber(snap.total)
        if final and early then run.snapshot.overshoot = final - early end
    end

    local b = readById(run.sessionID, after, res)
    run.byId = b

    analyzeDamageStop(run)

    if run.resumedAfterReload then
        run.reloadVerdict = string.format("sessionStillListed=%s readById=%s",
            show(b.presentInList), b.total and "OK" or "FAILED")
    end
    if db.pending and db.pending.runId == run.id then db.pending = nil end
end

local function endRun(reason)
    if not run then return end
    rlog("END " .. reason)
    if buzzerTimer then buzzerTimer:Cancel(); buzzerTimer = nil end
    local ok, err = pcall(finalizeResult)
    if not ok then noteError("finalize", err) end
    run.summary = summarize(run)
    for _, l in ipairs(run.summary) do chat(l) end
    chat("Saved. /reload or log out to flush SavedVariables, then tell Claude.")
    run = nil
    statusFS:SetText("idle — /drp arm 30 | /drp duel")
end

-- After combat drops: read now, again shortly after, then close the run.
local function onCombatEnded()
    if not run or run.closing then return end
    run.closing = true
    pcall(fullRead, "regenEnabled+0")
    testSnapshotLater("regen+0")
    C_Timer.After(0.5, function() if run then pcall(fullRead, "regenEnabled+0.5") end end)
    C_Timer.After(2.5, function()
        if run then
            pcall(fullRead, "regenEnabled+2.5")
            endRun("combat ended")
        end
    end)
end

local function setStart(source)
    if not run or run.t.start then return end
    run.t.start = now()
    run.tp.start = precise()
    run.startSource = source
    rlog("START via " .. source)
    if run.kind == "pve" and run.duration then
        buzzerTimer = C_Timer.NewTimer(run.duration, function()
            if not run then return end
            mark("buzzer")
            -- Test E: what a real addon would persist to finish the run after a /reload.
            db.pending = { runId = run.id, sessionID = run.sessionID, buzzer = run.t.buzzer,
                at = date("%Y-%m-%d %H:%M:%S") }
            rlog("PENDING saved sessionID=" .. show(run.sessionID))
            local ok, err = pcall(takeSnapshot)
            if not ok then noteError("snapshot", err) end
            pcall(fullRead, "buzzer")
            PlaySound(SOUNDKIT.RAID_WARNING)
            RaidNotice_AddMessage(RaidWarningFrame, "DPS RACE PROBE: STOP!", ChatTypeInfo["RAID_WARNING"])
            chat("BUZZER — stop attacking now and let combat drop.")
        end)
    end
    -- An in-combat read a moment in, to see what is secret mid-fight.
    C_Timer.After(2, function() if run then pcall(fullRead, "start+2") end end)
end

-------------------------------------------------------------------------------
-- Live display (Q: can a live breakdown be shown from secrets?)
-------------------------------------------------------------------------------

local liveAccum, uiAccum = 0, 0

local function liveRead()
    if not run then return end
    local s = readSession(STAT.DamageDone)
    if not canTable(s) then
        run.live.sealed = run.live.sealed + 1
        liveFS:SetText("live: session sealed")
        return
    end
    local row = localPlayerRow(s)
    if not row then
        run.live.noRow = run.live.noRow + 1
        liveFS:SetText("live: no local row yet")
        return
    end
    -- string.format accepts secrets and yields a (secret) string SetText accepts.
    -- Only `== nil` is ever asked of a value here; `x and y or z` would truth-test it.
    local total, aps = row.totalAmount, row.amountPerSecond
    if total == nil then total = "-" end
    if aps == nil then aps = "-" end
    local text = string.format("dmg %s  dps %s", total, aps)
    local mine = readSource(STAT.DamageDone, UnitGUID("player"), nil)
    if canTable(mine) then
        local shown = 0
        safeEach(mine.combatSpells, function(_, sp)
            if shown < 5 and canTable(sp) then
                local label = "?"
                local okName, name = pcall(function()
                    return C_Spell.GetSpellName(sp.spellID)
                end)
                if okName and name ~= nil then label = name end
                local amt = sp.totalAmount
                if amt == nil then amt = "-" end
                text = string.format("%s\n%s  %s", text, label, amt)
                shown = shown + 1
            end
        end)
        if shown > 0 then run.live.spellsShown = run.live.spellsShown + 1 end
    end
    liveFS:SetText(text)
    run.live.ok = run.live.ok + 1
end

frame:SetScript("OnUpdate", function(_, elapsed)
    uiAccum = uiAccum + elapsed
    liveAccum = liveAccum + elapsed
    if uiAccum >= 0.05 then
        uiAccum = 0
        if run then
            local base = run.t.start
            if base then
                local e = now() - base
                local rem = run.duration and (run.duration - e) or nil
                timerFS:SetText(rem and string.format("%.2f  (left %.1f)", e, math.max(rem, 0))
                    or string.format("%.2f", e))
            else
                timerFS:SetText("waiting for first hit…")
            end
            statusFS:SetText(string.format("%s | start via %s | meter evts %d", run.kind,
                run.startSource or "-", run.meter.n))
        end
    end
    if liveAccum >= 0.5 then
        liveAccum = 0
        if run and run.t.start then
            local ok, err = pcall(liveRead)
            if not ok and run then
                run.live.firstError = run.live.firstError or show(err)
                liveFS:SetText("live: error (logged)")
            end
        end
    end
end)

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local events = {}

local function count(name)
    if run then run.counts[name] = (run.counts[name] or 0) + 1 end
end

events.ADDON_LOADED = function(name)
    if name ~= ADDON then return end
    DpsRaceProbeDB = DpsRaceProbeDB or {}
    db = DpsRaceProbeDB
    db.runs = db.runs or {}
    db.globalLog = db.globalLog or {}
    db.svtest = db.svtest or false
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    glog("loaded, build " .. show(select(4, GetBuildInfo())))

    -- Test E: re-attach a run that was waiting for combat to end when the UI reloaded.
    local p = db.pending
    if p then
        for _, r in ipairs(db.runs) do
            if r.id == p.runId then run = r end
        end
        if run then
            lastRun = run
            run.resumedAfterReload = true
            run.closing = nil
            run.sessionID = run.sessionID or p.sessionID
            rlog(string.format("RESUMED after reload: pending sessionID=%s inCombat=%s",
                show(p.sessionID), show(InCombatLockdown())))
            frame:Show()
        else
            glog("pending run " .. show(p.runId) .. " not found; dropping")
            db.pending = nil
        end
    end
end

events.PLAYER_ENTERING_WORLD = function()
    if not (run and run.resumedAfterReload and not run.closing) then return end
    -- Combat may already be over by the time the UI is back: no regen edge will come.
    C_Timer.After(1, function()
        if run and not run.closing and not InCombatLockdown() then
            rlog("RESUMED run: not in combat after reload, reading now")
            onCombatEnded()
        elseif run then
            chat("Resumed pending run " .. show(run.sessionID) .. ": waiting for combat to end. Walk away.")
        end
    end)
end

events.PLAYER_REGEN_DISABLED = function()
    count("PLAYER_REGEN_DISABLED")
    mark("regenDisabled")
    if run then
        run.targetInCombat = targetMeta()
    end
end

events.PLAYER_REGEN_ENABLED = function()
    count("PLAYER_REGEN_ENABLED")
    mark("regenEnabled")
    if run and run.t.start then onCombatEnded() end
end

events.DAMAGE_METER_CURRENT_SESSION_UPDATED = function(...)
    count("DAMAGE_METER_CURRENT_SESSION_UPDATED")
    if not run then return end
    local t = now()
    local m = run.meter
    if m.last then
        local gap = t - m.last
        m.intervals = m.intervals + gap
        if gap > m.maxGap then m.maxGap = gap end
    end
    m.last = t
    m.n = m.n + 1
    run.t.lastMeterUpdate = t
    if m.n <= 5 then rlog("DAMAGE_METER_CURRENT_SESSION_UPDATED args=" .. show(select("#", ...))) end
    mark("firstMeterUpdate")
    setStart("meter")
end

-- v2: every update is timestamped with its (stat type, session id), so the run
-- can tell when *its own* DamageDone stopped changing (test D) and which
-- session it belongs to (test E). The payload was plain mid-combat in v1.
events.DAMAGE_METER_COMBAT_SESSION_UPDATED = function(statType, sessionID)
    count("DAMAGE_METER_COMBAT_SESSION_UPDATED")
    if not run then return end
    if (run.counts.DAMAGE_METER_COMBAT_SESSION_UPDATED or 0) <= 5 then
        rlog("DAMAGE_METER_COMBAT_SESSION_UPDATED type=" .. show(statType) .. " id=" .. show(sessionID))
    end
    local ty, id = plainNumber(statType), plainNumber(sessionID)
    if run.t.start and run.sessionID == nil and ty == STAT.DamageDone and id and id ~= 0 then
        run.sessionID = id
        rlog("SESSION id=" .. id .. " captured from meter event")
    end
    local tl = run.dm.timeline
    if #tl < 6000 then
        tl[#tl + 1] = { t = now(), ty = ty or show(statType), id = id or show(sessionID) }
    else
        run.dm.dropped = (run.dm.dropped or 0) + 1
    end
end

events.DAMAGE_METER_RESET = function()
    count("DAMAGE_METER_RESET")
    rlog("DAMAGE_METER_RESET")
end

events.UNIT_HEALTH = function(unit)
    if not run then return end
    count("UNIT_HEALTH_" .. show(unit))
    local key = "firstHealth_" .. show(unit)
    if run.t[key] == nil then
        rlog(string.format("UNIT_HEALTH %s health=%s max=%s pct=%s", show(unit),
            show(UnitHealth(unit)), show(UnitHealthMax(unit)),
            UnitHealthPercent and show(select(2, pcall(UnitHealthPercent, unit))) or "n/a"))
        mark(key)
    end
    -- In a duel the clock starts on the target's own first health change.
    if run.kind == "duel" and unit == "player" then setStart("playerHealth") end
end

events.UNIT_ABSORB_AMOUNT_CHANGED = function(unit)
    if not run then return end
    count("UNIT_ABSORB_" .. show(unit))
    local key = "firstAbsorb_" .. show(unit)
    if run.t[key] == nil then
        rlog("UNIT_ABSORB_AMOUNT_CHANGED " .. show(unit) .. " absorb=" .. show(UnitGetTotalAbsorbs(unit)))
        mark(key)
    end
end

events.UNIT_COMBAT = function(unit, action, indicator, amount, school)
    if not run then return end
    count("UNIT_COMBAT_" .. show(unit))
    if (run.counts["UNIT_COMBAT_" .. show(unit)] or 0) <= 5 then
        rlog(string.format("UNIT_COMBAT %s action=%s ind=%s amount=%s school=%s", show(unit),
            show(action), show(indicator), show(amount), show(school)))
    end
    mark("firstUnitCombat")
end

events.UNIT_SPELLCAST_SUCCEEDED = function(unit, castGUID, spellID)
    if not run or unit ~= "player" then return end
    count("UNIT_SPELLCAST_SUCCEEDED")
    if (run.counts.UNIT_SPELLCAST_SUCCEEDED or 0) <= 3 or run.t.buzzer then
        rlog("UNIT_SPELLCAST_SUCCEEDED spell=" .. show(spellID))
    end
    mark("firstCast")
    run.t.lastCast = now()
    if run.t.buzzer then
        run.castsAfterBuzzer = (run.castsAfterBuzzer or 0) + 1
    end
end

events.DUEL_REQUESTED = function(name)
    glog("DUEL_REQUESTED " .. show(name))
    if not isSecret(name) and name then
        partner = name:find("-") and name or (name .. "-" .. GetNormalizedRealmName())
    end
    if not run then newRun("duel") end
    rlog("DUEL_REQUESTED from " .. show(name))
end

events.DUEL_INBOUNDS = function() rlog("DUEL_INBOUNDS") end
events.DUEL_OUTOFBOUNDS = function() rlog("DUEL_OUTOFBOUNDS") end

events.DUEL_FINISHED = function(...)
    glog("DUEL_FINISHED")
    if not run then return end
    rlog("DUEL_FINISHED args=" .. show(select("#", ...)))
    mark("duelFinished")
    pcall(fullRead, "duelFinished+0")
    C_Timer.After(1, function() if run then pcall(fullRead, "duelFinished+1") end end)
    -- Q6: addon messages right after the duel.
    for _, delay in ipairs({ 0.2, 1, 3 }) do
        C_Timer.After(delay, function() SlashCmdList.DPSRACEPROBE("ping auto+" .. delay) end)
    end
    -- If neither side entered combat, there is no regen edge to close the run.
    C_Timer.After(6, function()
        if run and not run.closing then
            pcall(fullRead, "duelFinished+6")
            endRun("duel finished, no regen edge")
        end
    end)
end

events.CHAT_MSG_SYSTEM = function(msg)
    if not run then return end
    local secret = isSecret(msg)
    rlog("CHAT_MSG_SYSTEM secret=" .. show(secret) .. " msg=" .. show(msg))
    if not secret and type(msg) == "string" and msg:lower():find("duel") then
        mark("defeatMessage")
    end
end

events.START_TIMER = function(...)
    rlog("START_TIMER " .. show((...)) .. " " .. show(select(2, ...)) .. " " .. show(select(3, ...)))
    mark("startTimer")
end

events.ADDON_RESTRICTION_STATE_CHANGED = function(rtype, state)
    rlog("RESTRICTION type=" .. show(rtype) .. " state=" .. show(state))
end

events.CHAT_MSG_ADDON = function(prefix, msg, channel, sender)
    if prefix ~= PREFIX then return end
    local line = string.format("ADDON_MSG recv from %s via %s: %s (local t=%s)",
        show(sender), show(channel), show(msg), fmt(now()))
    glog(line)
    local r = run or lastRun
    if r then
        r.addonMsgs = r.addonMsgs or {}
        r.addonMsgs[#r.addonMsgs + 1] = line
    end
    chat(line)
end

local registered, rejected = {}, {}
for name in pairs(events) do
    local ok = pcall(frame.RegisterEvent, frame, name)
    if ok then registered[#registered + 1] = name else rejected[#rejected + 1] = name end
end
-- Unit events, filtered to the two units that matter.
for _, name in ipairs({ "UNIT_HEALTH", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_COMBAT" }) do
    pcall(frame.UnregisterEvent, frame, name)
    local ok = pcall(frame.RegisterUnitEvent, frame, name, "player", "target")
    if not ok then rejected[#rejected + 1] = name .. "(unit)" end
end
pcall(frame.UnregisterEvent, frame, "UNIT_SPELLCAST_SUCCEEDED")
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")

frame:SetScript("OnEvent", function(_, event, ...)
    local fn = events[event]
    if fn then
        local ok, err = pcall(fn, ...)
        if not ok then noteError(event, err) end
    end
end)

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------

frame:SetSize(300, 150)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
frame:SetBackdropColor(0, 0, 0, 0.75)
frame:SetBackdropBorderColor(0.2, 1, 0.6, 0.8)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 8, -6)
title:SetText("DPS Race Probe")
timerFS = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
timerFS:SetPoint("TOPLEFT", 8, -24)
timerFS:SetText("-")
liveFS = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
liveFS:SetPoint("TOPLEFT", 8, -54)
liveFS:SetJustifyH("LEFT")
liveFS:SetText("")
statusFS = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
statusFS:SetPoint("BOTTOMLEFT", 8, 6)
statusFS:SetText("idle — /drp arm 30 | /drp duel")

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------

local HELP = {
    "/drp arm [sec]  — timed PvE run (default 30s). Target the dummy first.",
    "/drp duel       — arm a duel run (auto-arms when you receive a duel request)",
    "/drp stop       — end the active run now",
    "/drp read       — full meter dump into the active run",
    "/drp partner Name-Realm — addon-message partner (auto: duel opponent / targeted player)",
    "/drp ping       — send a test addon message to the partner",
    "/drp svtest on|off — also write raw secrets to SavedVariables at the buzzer",
    "/drp last       — reprint the last run summary",
    "/drp show|hide | status | clear",
}

-- One handler per verb, each given the text after the verb.
local VERBS = {}

function VERBS.arm(rest)
    if run then endRun("re-armed") end
    newRun("pve", tonumber(rest) or 30)
end

function VERBS.duel()
    if run then endRun("re-armed") end
    newRun("duel")
end

function VERBS.stop() endRun("manual stop") end

function VERBS.read()
    if run then pcall(fullRead, "manual") else chat("no active run") end
end

function VERBS.partner(rest)
    partner = rest ~= "" and rest or nil
    chat("partner = " .. show(partner))
end

function VERBS.ping(rest)
    if not partner then chat("no partner set") return end
    local tag = rest ~= "" and rest or "manual"
    local msg = string.format("ping %s t=%s", tag, fmt(now()))
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "WHISPER", partner)
    local line = string.format("ADDON_MSG send to %s [%s] ok=%s result=%s combat=%s",
        partner, tag, show(ok), show(result), show(InCombatLockdown()))
    glog(line)
    local r = run or lastRun
    if r then
        r.addonMsgs = r.addonMsgs or {}
        r.addonMsgs[#r.addonMsgs + 1] = line
    end
    chat(line)
end

function VERBS.svtest(rest)
    db.svtest = (rest == "on")
    chat("svtest = " .. show(db.svtest) .. (db.svtest and " (run this test LAST; it may break saving)" or ""))
end

function VERBS.last()
    local r = db.runs[#db.runs]
    if r and r.summary then for _, l in ipairs(r.summary) do chat(l) end else chat("no finished run") end
end

function VERBS.show() frame:Show() end

function VERBS.hide() frame:Hide() end

function VERBS.status()
    chat(string.format("runs saved: %d, active: %s, partner: %s, svtest: %s",
        #db.runs, run and run.kind or "none", show(partner), show(db.svtest)))
    chat("events registered: " .. #registered .. ", rejected: " .. (#rejected > 0 and table.concat(rejected, ", ") or "none"))
end

function VERBS.clear()
    db.runs, db.globalLog = {}, {}
    chat("cleared")
end

local function help()
    for _, l in ipairs(HELP) do chat(l) end
end

SLASH_DPSRACEPROBE1 = "/drp"
SlashCmdList.DPSRACEPROBE = function(input)
    local cmd, rest = (input or ""):match("^(%S*)%s*(.-)$")
    local handler = VERBS[cmd:lower()] or help
    handler(rest)
end
