local _, NS = ...
-- modules/TargetProbe.lua — a DEBUG-ONLY measurement (2026-10-24): can the addon count the enemies a
-- race actually hits, and name them, so the Cleave count need not be the player's pick? It decides
-- nothing and stores nothing. It only writes what it saw to the debug console, under the "Probe" tag.
--
-- WHEN. Only while debug logging is on (`/dr debug on`) and a race is running or stopping. Nothing is
-- registered otherwise: the sampler is a C_Timer ticker started on RACE_STATE_CHANGED to running and
-- canceled on leaving the race, and while the addon is stood down.
--
-- WHAT IT ASKS, per enemy nameplate ("nameplate1".."nameplate40"), four times a second:
--   UnitExists, UnitCanAttack("player", plate), UnitAffectingCombat, UnitThreatSituation("player",
--   plate), UnitGUID, UnitName, UnitLevel.
-- Each answer is reported by its KIND (NS.Secrets.Kind: nil / secret / sealed / a plain type), the
-- question this probe exists to answer. A plate counts as TAGGED (you are on its threat table, so
-- you have hit it or it has you) when its threat answer is present at all: the nil test, the one
-- question the client allows of a secret (NS.Secrets.IsPresent). The highest tagged count of the race
-- is the candidate target count.
--
-- V2 (2026-10-25, after the first runs: threat is nil on every training dummy, while GUID, name, level
-- and the combat flag are all PLAIN mid-combat). Each plate is now followed by its GUID: its name,
-- level and NPC ID are taken while it is in view, the moment its combat flag turns on (seconds from
-- the clock's start), whether its health is plain and how often it dropped between samples, and how
-- many UNIT_COMBAT events it took (an AceEvent target of its own, registered only while probing). The
-- report lists every GUID seen, so the player can say which of them they hit.
--
-- AFTER THE RESULT (out of combat, so everything should be plain) it names the tagged plates through
-- NS.Recorder.SnapshotTarget (name, level, NPC ID, catalog category), and reads the meter's
-- EnemyDamageTaken view of the run's session (NS.Meter.ReadEnemies) for each enemy's name, creature
-- ID and damage taken.

local Probe = {}
NS.TargetProbe = Probe

local Secrets = NS.Secrets

Probe.INTERVAL = 0.25
Probe.PLATES = 40
-- A compact summary line every this many samples (2s at 4 Hz), so a two-minute race is ~60 lines.
Probe.SUMMARY_EVERY = 8

local QUESTIONS = { "exists", "canAttack", "inCombat", "threat", "guid", "name", "level", "health" }

local cur          -- the race being probed: { run, ticker, samples, maxTagged, tagged, kinds, firstAt }

local function debugOn()
    return NS.State and NS.State.debug == true
end

local function log(fmt, ...)
    if NS.Debug then NS.Debug("Probe", fmt, ...) end
end

local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok then return "error" end
    return v
end

-- Every answer for one plate, as raw values (never inspected here) and their kinds.
local function readPlate(token)
    local raw = {
        exists = ask(UnitExists, token),
        canAttack = ask(UnitCanAttack, "player", token),
        inCombat = ask(UnitAffectingCombat, token),
        threat = ask(UnitThreatSituation, "player", token),
        guid = ask(UnitGUID, token),
        name = ask(UnitName, token),
        level = ask(UnitLevel, token),
        health = ask(UnitHealth, token),
    }
    local kinds = {}
    for _, q in ipairs(QUESTIONS) do
        local v = raw[q]
        kinds[q] = v == "error" and "error" or Secrets.Kind(v)
    end
    return raw, kinds
end

local function kindLine(kinds)
    local parts = {}
    for _, q in ipairs(QUESTIONS) do parts[#parts + 1] = q .. "=" .. kinds[q] end
    return table.concat(parts, " ")
end

-- Tally what kind each question answered over the race: { [question] = { [kind] = n } }.
local function tally(kinds)
    for _, q in ipairs(QUESTIONS) do
        local seen = cur.kinds[q] or {}
        cur.kinds[q] = seen
        seen[kinds[q]] = (seen[kinds[q]] or 0) + 1
    end
end

-- One plate's record, by its plain GUID (nil when the GUID is not plain: then it is not followed).
local function unitFor(raw)
    local guid = Secrets.PlainString(raw.guid)
    if not guid then return nil end
    local u = cur.units[guid]
    if not u then
        u = { guid = guid, drops = 0, hits = 0, healthKind = "never" }
        cur.units[guid] = u
        cur.order[#cur.order + 1] = guid
    end
    u.name = u.name or Secrets.PlainString(raw.name)
    u.level = u.level or Secrets.PlainNumber(raw.level)
    return u
end

local function follow(token, raw, kinds, t)
    local u = unitFor(raw)
    if not u then return end
    cur.plateGUID[token] = u.guid
    if Secrets.PlainTruth(raw.inCombat) and not u.combatAt then
        u.combatAt = t
        log("%s %s (%s) entered combat at +%.2f", token, tostring(u.name), u.guid, t)
    end
    u.healthKind = kinds.health
    local hp = Secrets.PlainNumber(raw.health)
    if hp then
        if u.lastHealth and hp < u.lastHealth then u.drops = u.drops + 1 end
        u.lastHealth = hp
    end
end

local function elapsed()
    local start = cur.run and cur.run.race and cur.run.race.startedAt
    return type(start) == "number" and (GetTime() - start) or 0
end

local function sample()
    if not cur or (NS.IsStoodDown and NS.IsStoodDown()) then return Probe.Stop() end
    cur.samples = cur.samples + 1
    local plates, tagged = 0, 0
    for i = 1, Probe.PLATES do
        local token = "nameplate" .. i
        local raw, kinds = readPlate(token)
        if Secrets.PlainTruth(raw.exists) or kinds.exists == "secret" then
            plates = plates + 1
            tally(kinds)
            follow(token, raw, kinds, elapsed())
            local isTagged = kinds.threat ~= "error" and Secrets.IsPresent(raw.threat)
            if isTagged then
                tagged = tagged + 1
                cur.tagged[token] = true
            end
            if cur.samples == 1 or (isTagged and not cur.logged[token]) then
                cur.logged[token] = true
                log("%s %s tagged=%s", token, kindLine(kinds), tostring(isTagged))
            end
        end
    end
    if tagged > cur.maxTagged then
        cur.maxTagged = tagged
        log("new max: %d tagged of %d plates (sample %d)", tagged, plates, cur.samples)
    end
    if cur.samples % Probe.SUMMARY_EVERY == 0 then
        log("sample %d: plates=%d tagged=%d max=%d", cur.samples, plates, tagged, cur.maxTagged)
    end
end

--- Start probing `run` (RUNNING, debug on). A second call while one runs is ignored.
function Probe.Start(run)
    if cur or not debugOn() then return false end
    cur = { run = run, samples = 0, maxTagged = 0, tagged = {}, logged = {}, kinds = {}, units = {}, order = {},
            plateGUID = {}, hitKinds = {} }
    Probe.Listen(true)
    log("start: probing nameplates every %.2fs (/dr debug off stops it at the next race)", Probe.INTERVAL)
    sample()
    if cur then cur.ticker = C_Timer.NewTicker(Probe.INTERVAL, sample) end
    return true
end

--- Stop sampling (the race left running and stopping, or the addon stood down). The report waits for
--- the result.
function Probe.Stop()
    if cur and cur.ticker then cur.ticker:Cancel() end
    if cur then cur.ticker = nil end
    Probe.Listen(false)
end

-- UNIT_COMBAT(unit, action, indicator, amount, school): a hit on a plate followed by GUID. Only the
-- unit token is compared (plain); every other argument's kind is tallied, never its value.
local events
local function onUnitCombat(_, unit, action, _, amount)
    if not cur or type(unit) ~= "string" or not unit:find("^nameplate") then return end
    local guid = cur.plateGUID[unit]
    local u = guid and cur.units[guid]
    if u then u.hits = u.hits + 1 end
    local key = "action=" .. Secrets.Kind(action) .. " amount=" .. Secrets.Kind(amount)
    cur.hitKinds[key] = (cur.hitKinds[key] or 0) + 1
end

--- Register (true) or drop (false) the probe's UNIT_COMBAT listener.
function Probe.Listen(on)
    if on then
        events = events or LibStub("AceEvent-3.0"):Embed({})
        NS.SafeRegisterEvent(events, "UNIT_COMBAT", onUnitCombat, NS.rejectedEvents)
    elseif events then
        events:UnregisterAllEvents()
    end
end

local function kindsReport()
    for _, q in ipairs(QUESTIONS) do
        local parts = {}
        for kind, n in pairs(cur.kinds[q] or {}) do parts[#parts + 1] = ("%s:%d"):format(kind, n) end
        table.sort(parts)
        log("kinds %s: %s", q, #parts > 0 and table.concat(parts, " ") or "never asked")
    end
end

local function taggedReport()
    local tokens = {}
    for token in pairs(cur.tagged) do tokens[#tokens + 1] = token end
    table.sort(tokens)
    log("tagged plates over the race: %d (max at once %d)", #tokens, cur.maxTagged)
    for _, token in ipairs(tokens) do
        local t = NS.Recorder.SnapshotTarget(token)
        local _, kinds = readPlate(token)
        log("  %s: name=%s level=%s npcID=%s category=%s (now %s)", token, tostring(t.name), tostring(t.level),
            tostring(t.npcID), tostring(t.category), kindLine(kinds))
    end
end

local function unitsReport()
    log("units followed by GUID: %d", #cur.order)
    for _, guid in ipairs(cur.order) do
        local u = cur.units[guid]
        log("  %s level=%s guid=%s combatAt=%s health=%s drops=%d unitCombat=%d", tostring(u.name), tostring(u.level),
            guid, u.combatAt and ("+%.2f"):format(u.combatAt) or "never", u.healthKind, u.drops, u.hits)
    end
    local parts = {}
    for key, n in pairs(cur.hitKinds) do parts[#parts + 1] = ("%s:%d"):format(key, n) end
    table.sort(parts)
    log("UNIT_COMBAT on plates: %s", #parts > 0 and table.concat(parts, " ") or "none heard")
end

local function meterReport()
    local id = cur.run and cur.run.race and cur.run.race.sessionID
    local rows, err = NS.Meter.ReadEnemies(id)
    if not rows then
        log("meter EnemyDamageTaken for session %s: %s", tostring(id), tostring(err))
        return
    end
    log("meter EnemyDamageTaken for session %s: %d row(s)", tostring(id), #rows)
    for _, r in ipairs(rows) do
        log("  %s creatureID=%s guid=%s damage=%s", tostring(r.name), tostring(r.creatureID), tostring(r.guid),
            tostring(r.damage))
    end
end

--- The race resolved: report what was measured, then forget it.
function Probe.Report()
    if not cur then return end
    Probe.Stop()
    local run = cur.run or {}
    log("report for run %s (%s, %s); picked count %s", tostring(run.id), tostring(run.status),
        tostring(run.target and run.target.name), tostring(run.target and run.target.count))
    log("samples=%d", cur.samples)
    local ok, err = pcall(function()
        kindsReport()
        unitsReport()
        taggedReport()
        meterReport()
    end)
    if not ok then log("report failed: %s", tostring(err)) end
    log("end of report: copy everything tagged Probe from here up to its start line")
    cur = nil
end

--- The race went idle without a result (canceled): stop and drop it.
function Probe.Discard()
    if not cur then return end
    Probe.Stop()
    log("race canceled: nothing to report")
    cur = nil
end

--- Whether a race is being probed now (the suites).
function Probe.Active()
    return cur ~= nil
end

local receiver = NS.NewBusTarget and NS.NewBusTarget()
if receiver then
    receiver:RegisterMessage(NS.MSG.RACE_STATE_CHANGED, function(_, run, _, to)
        local S = NS.Race.STATE
        if to == S.RUNNING then
            Probe.Start(run)
        elseif to == S.RESULT then
            Probe.Report()
        elseif to == S.IDLE then
            Probe.Discard()
        end
    end)
end
