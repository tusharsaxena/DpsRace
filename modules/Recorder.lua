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
-- one, nor a run still running or stopping (Race.Resume needs it). Each removal also drops the
-- loadouts (modules/Loadouts.lua) no run refers to any more.

local Recorder = {}
NS.Recorder = Recorder

local Secrets = NS.Secrets

-- The run record format (spec §7). A stored run carries its own copy; db.global.schema is the same.
-- Format 2 (#6) adds run.loadout; a format-1 run is a format-2 run without one. Format 3 (#13, #14)
-- adds run.casts and run.usage (modules/Casts.lua, modules/Usage.lua); an older run has neither and
-- reads as not recorded.
Recorder.RUN_SCHEMA = 3

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
    local Compat = NS.Compat
    local specIndex = Secrets.PlainNumber(ask(Compat.GetSpecialization))
    if not specIndex then return end
    local specID, specName, _, _, role = ask(Compat.GetSpecializationInfo, specIndex)
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

--- The catalog entry of the cataloged training dummy `unit` is (#16: the target, a nameplate), or nil:
--- no such unit, not a cataloged dummy, or a GUID that arrived secret (never parsed).
--- @param unit string
--- @return table|nil  { name, category }
function Recorder.DummyOf(unit)
    return NS.Dummies.Lookup(npcIDFromGUID(ask(UnitGUID, unit)))
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

-- ── the loadout (#6) ────────────────────────────────────────────────────────────────────────────
-- What the player raced with: every equipped item's link and the talent loadout. All of it is plain
-- data read out of combat (at arm, and at the race's combat end), so no secret reaches it; each value
-- still passes through NS.Secrets like every other snapshot. modules/Loadouts.lua stores it deduped.

-- The equipment slots a loadout records, in slot order: 1-18 without the shirt (4); the tabard (19)
-- is never read (the owner's call, 2026-10-25: both are cosmetic).
Recorder.GEAR_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

--- The equipped items' links by slot, an empty slot absent; nil with nothing equipped (or no API).
local function snapshotGear()
    local gear, any = {}, false
    for _, slot in ipairs(Recorder.GEAR_SLOTS) do
        local link = Secrets.PlainString(ask(GetInventoryItemLink, "player", slot))
        if link and link ~= "" then
            gear[slot] = link
            any = true
        end
    end
    return any and gear or nil
end

local function currentSpecID()
    local Compat = NS.Compat
    local specIndex = Secrets.PlainNumber(ask(Compat.GetSpecialization))
    if not specIndex then return nil end
    return Secrets.PlainNumber((ask(Compat.GetSpecializationInfo, specIndex)))
end

-- A trait config's name, or nil.
local function configName(traits, id)
    if type(id) ~= "number" then return nil end
    local info = ask(traits.GetConfigInfo, id)
    return type(info) == "table" and Secrets.PlainString(info.name) or nil
end

-- The hero talent tree: its SubTreeID and its name, read while its config is the active one.
local function heroOf(t, talents, traits)
    t.heroSpecID = Secrets.PlainNumber(ask(talents.GetActiveHeroTalentSpec))
    if not t.heroSpecID then return end
    local info = ask(traits.GetSubTreeInfo, t.configID, t.heroSpecID)
    t.heroName = type(info) == "table" and Secrets.PlainString(info.name) or nil
end

--- The active talent loadout: its spec, config, name (the player's saved loadout's, else the active
--- config's), hero tree, import string and the client's serialization version. nil without the APIs
--- or an active config.
local function snapshotTalents()
    local talents, traits = C_ClassTalents, C_Traits
    if type(talents) ~= "table" or type(traits) ~= "table" then return nil end
    local configID = Secrets.PlainNumber(ask(talents.GetActiveConfigID))
    if not configID then return nil end
    local specID = currentSpecID()
    local t = { specID = specID, configID = configID }
    local saved = specID and Secrets.PlainNumber(ask(talents.GetLastSelectedSavedConfigID, specID))
    t.name = configName(traits, saved) or configName(traits, configID)
    heroOf(t, talents, traits)
    t.importString = Secrets.PlainString(ask(traits.GenerateImportString, configID))
    if t.importString == "" then t.importString = nil end
    t.serialVersion = Secrets.PlainNumber(ask(traits.GetLoadoutSerializationVersion))
    return t
end

--- What the player is wearing and the talents they run, read out of combat (#6).
--- @return table|nil loadout  { gear = { [slot] = link }|nil, talents = { specID, configID, name,
---                            heroSpecID, heroName, importString, serialVersion }|nil }; nil when
---                            neither could be read
function Recorder.SnapshotLoadout()
    local gear, talents = snapshotGear(), snapshotTalents()
    if not gear and not talents then return nil end
    return { gear = gear, talents = talents }
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
--- @return table run  spec §7's shape; result is filled when the run is read
function Recorder.NewRun(length)
    local grace, restartGap = raceSettings()
    local target = Recorder.SnapshotTarget("target")
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
    NS.Loadouts.Sweep()
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
    NS.Loadouts.Sweep()
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

Recorder.DAY = 86400

--- Remove every resolved run older than `days` days (by its date, against `now`), never one holding a
--- best (all-runs or clean-only board), never one still running or stopping (spec §6.3, §7), never
--- `protect` and never the race's current run (the owner's call, 2026-10-26: pruning by age, not by
--- count). Fires RUNS_CHANGED once when anything was removed.
--- @param days number|nil  0 (never) or anything not a positive number is a no-op
--- @param protect string|nil  a run id to keep (the run just saved)
--- @param now number|nil  the epoch the age is measured from (time())
--- @return number removed
function Recorder.Prune(days, protect, now)
    local runs = store()
    days = Secrets.PlainNumber(days)
    if not runs or not days or days < 1 then return 0 end
    days = math.floor(days)
    local cutoff = (now or time()) - days * Recorder.DAY
    local holding = NS.Bests.HoldingIDs(Recorder.All())
    for id in pairs(protectedIDs(protect)) do holding[id] = true end
    local old = collect(function(status, run)
        return PRUNABLE[status] == true and type(run.date) == "number" and run.date < cutoff
    end, newerFirst)
    local n = 0
    for _, run in ipairs(old) do
        if not holding[run.id] then
            runs[run.id] = nil
            n = n + 1
        end
    end
    if n > 0 then
        debug("pruned %d run(s) older than %d days", n, days)
        NS.Loadouts.Sweep()
        NS.SendBus(NS.MSG.RUNS_CHANGED)
    end
    return n
end
