local _, NS = ...
-- modules/Recorder.lua — the run record (spec §7): snapshots of who, against what and where, a new
-- run with its scoring settings frozen in, and the account-wide run store with its bus messages.
--
-- SECRETS. A snapshot can be taken in combat (Race re-reads the target at combat start, spec §4.1),
-- when a unit's GUID, name, level and classification may arrive secret. A secret must never reach
-- SavedVariables, and only core/Secrets.lua may inspect one, so every client value passes through
-- NS.Secrets.PlainString / PlainNumber / PlainTruth on its way in: a sealed field is simply absent
-- from the record. A sealed target re-read is filled from the arm-time snapshot (SnapshotTarget's
-- `prior`) when it is recognizably the same target.
--
-- Every client function is read BARE at CALL time and pcall'd: a client (or the harness) without one
-- yields an absent field, never a Lua error on the arm path.
--
-- THE STORE is db.global.runs, keyed by run id: account-wide, so a profile switch never hides a
-- character's history and bests span alts (spec §7). Save fires RUN_SAVED(run); Delete, DeleteAll and
-- Prune fire RUNS_CHANGED. Prune asks NS.Bests (CALL time) which runs hold a best, and never removes
-- one, nor a run still running or stopping (Race.Resume needs it).

local Recorder = {}
NS.Recorder = Recorder

local Secrets = NS.Secrets

-- The run record format (spec §7). A stored run carries its own copy; db.global.schema is the same.
Recorder.RUN_SCHEMA = 1

-- An id is time() .. "-" .. a four-digit random; a clash with a stored run is redrawn this many times.
local ID_ATTEMPTS = 32

-- The target fields a re-read may fill from the arm-time snapshot.
local TARGET_FIELDS = { "npcID", "name", "level", "classification" }

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Recorder", fmt, ...) end
end

local function passResults(ok, ...)
    if ok then return ... end
    debug("client call raised: %s", tostring((...)))
    return nil
end

--- Call a client function if it exists, pcall'd. Answers its results, or nothing.
local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    return passResults(pcall(fn, ...))
end

--- A plain number to one decimal, or nil.
local function round1(v)
    v = Secrets.PlainNumber(v)
    if not v then return nil end
    return math.floor(v * 10 + 0.5) / 10
end

-- ── snapshots ───────────────────────────────────────────────────────────────────────────────────

local function snapshotSpec(char)
    local specIndex = Secrets.PlainNumber(ask(GetSpecialization))
    if not specIndex then return end
    local specID, specName, _, _, role = ask(GetSpecializationInfo, specIndex)
    char.specID = Secrets.PlainNumber(specID)
    char.spec = Secrets.PlainString(specName)
    char.role = Secrets.PlainString(role)
end

--- Who the player is, read while everything is readable (at arm, out of combat).
--- @return table char  { name, realm, class, specID, spec, role, ilvl, ilvlOverall, level, race }
function Recorder.SnapshotPlayer()
    local char = {
        name  = Secrets.PlainString(ask(UnitName, "player")),
        realm = Secrets.PlainString(ask(GetRealmName)),
        level = Secrets.PlainNumber(ask(UnitLevel, "player")),
    }
    local _, classToken = ask(UnitClass, "player")
    char.class = Secrets.PlainString(classToken)
    local _, raceToken = ask(UnitRace, "player")
    char.race = Secrets.PlainString(raceToken)
    -- GetAverageItemLevel answers (overall, equipped); the record's ilvl is the equipped one.
    local overall, equipped = ask(GetAverageItemLevel)
    char.ilvl, char.ilvlOverall = round1(equipped), round1(overall)
    snapshotSpec(char)
    return char
end

--- The creature ID out of a Creature or Vehicle GUID (its sixth field), or nil: for a player, a pet,
--- no GUID, or a secret one, which is never parsed.
local function npcIDFromGUID(guid)
    guid = Secrets.PlainString(guid)
    if not guid then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(id)
end

--- Whether a fresh read `t` is the target `prior` recorded: the same creature ID, or (when the ID is
--- unreadable) the same name, or nothing readable at all (the read cannot claim a different target).
local function sameTarget(t, prior)
    if t.npcID ~= nil then return t.npcID == prior.npcID end
    if t.name ~= nil then return t.name == prior.name end
    return true
end

local function fillFromPrior(t, prior)
    if type(prior) ~= "table" or not sameTarget(t, prior) then return end
    for _, key in ipairs(TARGET_FIELDS) do
        if t[key] == nil then t[key] = prior[key] end
    end
end

--- What the unit is, categorized through the dummy catalog. A sealed field is absent; with `prior`
--- (the arm-time snapshot) a field sealed now is taken from it when the unit is the same target.
--- @param unit string|nil  default "target"
--- @param prior table|nil  an earlier SnapshotTarget result; never modified
--- @return table target  { npcID, name, category, count, level, classification }
function Recorder.SnapshotTarget(unit, prior)
    unit = unit or "target"
    local t = {}
    if Secrets.PlainTruth(ask(UnitExists, unit)) then
        t.npcID = npcIDFromGUID(ask(UnitGUID, unit))
        t.name = Secrets.PlainString(ask(UnitName, unit))
        t.level = Secrets.PlainNumber(ask(UnitLevel, unit))
        t.classification = Secrets.PlainString(ask(UnitClassification, unit))
    end
    fillFromPrior(t, prior)
    local d = NS.Dummies and NS.Dummies.Lookup(t.npcID)
    t.category = d and d.category or "other"
    t.count = d and d.count or 1
    if t.name == nil and d then t.name = d.name end
    return t
end

--- Where the player is.
--- @return table where  { mapID, zone, subzone, instanceType }
function Recorder.SnapshotWhere()
    local mapAPI = C_Map
    local mapID = mapAPI and ask(mapAPI.GetBestMapForUnit, "player")
    local _, instanceType = ask(GetInstanceInfo)
    return {
        mapID        = Secrets.PlainNumber(mapID),
        zone         = Secrets.PlainString(ask(GetZoneText)),
        subzone      = Secrets.PlainString(ask(GetSubZoneText)),
        instanceType = Secrets.PlainString(instanceType),
    }
end

-- ── the store ───────────────────────────────────────────────────────────────────────────────────

local function store()
    local db = NS.db
    return db and db.global and db.global.runs
end

local function newID()
    local runs = store() or {}
    local stamp = tostring(time())
    local id
    for _ = 1, ID_ATTEMPTS do
        id = stamp .. "-" .. math.random(1000, 9999)
        if runs[id] == nil then return id end
    end
    return id .. math.random(1000, 9999)   -- still digits-dash-digits, now eight random digits
end

-- The profile's scoring settings, else the shipped defaults (a run armed before the DB exists).
local function raceSettings()
    local p = NS.db and NS.db.profile
    local race = p and p.race
    local d = NS.defaults.profile.race
    return (race and race.grace) or d.grace, (race and race.restartGap) or d.restartGap
end

--- A new, unsaved run with status "armed": the player, target and place snapshotted now, and the
--- grace and restart gap copied from the profile so changing them never re-grades it (spec §5.2).
--- @param length number  the race length in seconds
--- @param targetCount number|nil  the armed target count; nil keeps the catalog's (else 1)
--- @return table run  spec §7's shape; result is filled when the run is read
function Recorder.NewRun(length, targetCount)
    local grace, restartGap = raceSettings()
    local target = Recorder.SnapshotTarget("target")
    if type(targetCount) == "number" and targetCount >= 1 then target.count = math.floor(targetCount) end
    local _, _, _, build = ask(GetBuildInfo)
    return {
        id     = newID(),
        schema = Recorder.RUN_SCHEMA,
        status = "armed",
        addon  = NS.version,
        build  = Secrets.PlainNumber(build),
        date   = time(),   -- the arm time; Race restamps it at the start
        race   = { length = length, grace = grace, restartGap = restartGap, startSource = "meterSession" },
        char   = Recorder.SnapshotPlayer(),
        target = target,
        where  = Recorder.SnapshotWhere(),
        flags  = { lateCasts = {}, reloaded = false, died = false },
        spells = {},
        note   = "",
    }
end

--- Store `run` under its id (replacing any earlier copy) and fire RUN_SAVED(run).
--- @return boolean saved  false for a run without an id, or before the DB exists
function Recorder.Save(run)
    local runs = store()
    if not runs or type(run) ~= "table" or not Secrets.IsSafeKey(run.id) then return false end
    runs[run.id] = run
    NS.SendBus(NS.MSG.RUN_SAVED, run)
    return true
end

--- The stored run with this id, or nil.
function Recorder.Get(id)
    local runs = store()
    if not runs or not Secrets.IsSafeKey(id) then return nil end
    return runs[id]
end

-- Newest first; a date tie breaks on the id, so the order never depends on pairs().
local function newerFirst(a, b)
    local da, db = a.date or 0, b.date or 0
    if da ~= db then return da > db end
    return tostring(a.id) > tostring(b.id)
end

-- A run written by a later version (a higher run schema than this one knows) is left alone: never
-- listed, ranked, resumed or pruned (docs/schema.md).
local function known(run)
    return type(run) == "table" and not (type(run.schema) == "number" and run.schema > Recorder.RUN_SCHEMA)
end

local function collect(keep, order)
    local out = {}
    for _, run in pairs(store() or {}) do
        if known(run) and keep(run.status, run) then out[#out + 1] = run end
    end
    table.sort(out, order)
    return out
end

--- Every stored run except an armed one, newest first.
--- @return table runs  an array; a fresh table the caller may keep
function Recorder.All()
    return collect(function(status) return status ~= "armed" end, newerFirst)
end

--- Whether a run is the logged-in character's: the same name, and the same realm when both sides
--- know it. A run (or a client) with no readable name is taken as this character's.
--- @return boolean
function Recorder.IsMine(run)
    local char = type(run) == "table" and type(run.char) == "table" and run.char or {}
    local name = Secrets.PlainString(ask(UnitName, "player"))
    if not (name and char.name) then return true end
    if name ~= char.name then return false end
    local realm = Secrets.PlainString(ask(GetRealmName))
    return not (realm and char.realm) or realm == char.realm
end

--- The logged-in character's runs a /reload left unresolved (status running or stopping), oldest
--- first: Race.Resume's list and the arm's "pending" refusal. Another character's pending run waits
--- for that character's login.
--- @return table runs
function Recorder.Pending()
    return collect(function(status, run)
        return (status == "running" or status == "stopping") and Recorder.IsMine(run)
    end, function(a, b) return newerFirst(b, a) end)
end

--- Store a run's note (already clamped by the caller). A note is not a race result: it fires
--- RUNS_CHANGED, never RUN_SAVED, whose receiver prunes the store (modules/Bests.lua).
--- @return boolean stored
function Recorder.SetNote(id, note)
    local runs = store()
    if not runs or not Secrets.IsSafeKey(id) or type(runs[id]) ~= "table" then return false end
    runs[id].note = note
    NS.SendBus(NS.MSG.RUNS_CHANGED)
    return true
end

--- Remove one run. Fires RUNS_CHANGED only when something was removed.
--- @return boolean removed
function Recorder.Delete(id)
    local runs = store()
    if not runs or not Secrets.IsSafeKey(id) or runs[id] == nil then return false end
    runs[id] = nil
    NS.SendBus(NS.MSG.RUNS_CHANGED)
    return true
end

--- Remove every run. Fires RUNS_CHANGED once when anything was removed.
--- @return number removed
function Recorder.DeleteAll()
    local runs = store()
    if not runs then return 0 end
    local n = 0
    for id in pairs(runs) do
        runs[id] = nil
        n = n + 1
    end
    if n > 0 then NS.SendBus(NS.MSG.RUNS_CHANGED) end
    return n
end

-- The statuses a prune may remove: resolved runs. A running or stopping run is Race.Resume's.
local PRUNABLE = { complete = true, incomplete = true, lost = true }

-- The runs a prune never removes besides the holders: `protect` (the run a RUN_SAVED just stored)
-- and the race's own run (the one being raced or on the result card).
local function protectedIDs(protect)
    local ids = {}
    if Secrets.IsSafeKey(protect) then ids[protect] = true end
    local current = NS.Race and NS.Race.Current and NS.Race.Current()
    if type(current) == "table" and Secrets.IsSafeKey(current.id) then ids[current.id] = true end
    return ids
end

--- Remove the oldest runs until at most `keep` are stored, never one holding a best (all-runs or
--- clean-only board), never one still running or stopping (spec §6.3, §7), never `protect` and never
--- the race's current run. With nothing left to remove the store may stay above `keep`. Fires
--- RUNS_CHANGED once when anything was removed.
--- @param keep number|nil  0 (the default) or anything not a positive number is a no-op
--- @param protect string|nil  a run id to keep (the run just saved)
--- @return number removed
function Recorder.Prune(keep, protect)
    local runs = store()
    keep = Secrets.PlainNumber(keep)
    if not runs or not keep or keep < 1 then return 0 end
    keep = math.floor(keep)
    local total = 0
    for _ in pairs(runs) do total = total + 1 end
    if total <= keep then return 0 end
    local holding = NS.Bests.HoldingIDs(Recorder.All())
    for id in pairs(protectedIDs(protect)) do holding[id] = true end
    local oldestFirst = collect(function(status) return PRUNABLE[status] == true end,
        function(a, b) return newerFirst(b, a) end)
    local n = 0
    for _, run in ipairs(oldestFirst) do
        if total - n <= keep then break end
        if not holding[run.id] then
            runs[run.id] = nil
            n = n + 1
        end
    end
    if n > 0 then
        debug("pruned %d run(s) to keep %d", n, keep)
        NS.SendBus(NS.MSG.RUNS_CHANGED)
    end
    return n
end
