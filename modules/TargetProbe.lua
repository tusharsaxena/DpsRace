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

local QUESTIONS = { "exists", "canAttack", "inCombat", "threat", "guid", "name", "level" }

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
    cur = { run = run, samples = 0, maxTagged = 0, tagged = {}, logged = {}, kinds = {} }
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
