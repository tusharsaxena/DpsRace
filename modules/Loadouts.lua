local _, NS = ...
-- modules/Loadouts.lua — the loadout store (#6): each distinct gear set and talent loadout stored
-- once, in db.global.loadouts, and a run holding only their keys (run.loadout = { gear, talents }).
-- About 2 KB of item links per gear set would add up fast on every run; a run adds two short keys.
--
-- THE KEY is a small pure string hash (djb2, as eight hex digits) of a canonical form: a gear set's
-- slot:link pairs in slot order, a talent loadout's spec, hero tree, name and import string. Two
-- different sets that hash alike are told apart by their canonical form, and the later one takes the
-- next free "<hash>-<n>". Plain data only: every value went through NS.Secrets in the snapshot.
--
-- ORPHANS. A loadout no stored run refers to is dropped by Sweep: after a run is deleted, after every
-- run is deleted, after a prune removed any (modules/Recorder.lua), and when a race replaces its
-- arm-time loadout with the combat-end one (Attach). A run of a later format keeps what it refers to.

local Loadouts = {}
NS.Loadouts = Loadouts

local KINDS = { "gear", "talents" }
local SEP = "\31"   -- the unit separator: never in a link, a name or an import string

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Loadouts", fmt, ...) end
end

--- djb2 over `s`, as eight lowercase hex digits.
--- @param s string
--- @return string
function Loadouts.Hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return ("%08x"):format(h)
end

local function sortedSlots(gear)
    local slots = {}
    for slot in pairs(gear) do
        if type(slot) == "number" then slots[#slots + 1] = slot end
    end
    table.sort(slots)
    return slots
end

-- The canonical forms the key is a hash of, and that tell two sets with one hash apart.
local CANON = {}

function CANON.gear(gear)
    local parts = {}
    for _, slot in ipairs(sortedSlots(gear)) do parts[#parts + 1] = slot .. ":" .. tostring(gear[slot]) end
    return table.concat(parts, SEP)
end

function CANON.talents(t)
    return table.concat({ tostring(t.specID), tostring(t.heroSpecID), tostring(t.name), tostring(t.importString) }, SEP)
end

Loadouts.Canonical = CANON

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

--- db.global.loadouts with both buckets, or nil before the DB exists.
local function store()
    local g = NS.db and NS.db.global
    if not g then return nil end
    local s = g.loadouts
    if type(s) ~= "table" then
        s = {}
        g.loadouts = s
    end
    for _, kind in ipairs(KINDS) do
        if type(s[kind]) ~= "table" then s[kind] = {} end
    end
    return s
end

-- `value`'s key in `bucket`, storing a copy of it under a free one when no stored set is the same.
local function intern(bucket, kind, value)
    local canon = CANON[kind](value)
    local base = Loadouts.Hash(canon)
    local key, n = base, 1
    while bucket[key] ~= nil do
        if type(bucket[key]) == "table" and CANON[kind](bucket[key]) == canon then return key end
        n = n + 1
        key = base .. "-" .. n
    end
    bucket[key] = copy(value)
    return key
end

--- Store a snapshot's two halves (each once) and answer the run's reference to them.
--- @param snap table|nil  Recorder.SnapshotLoadout's answer
--- @return table|nil ref  { gear = key|nil, talents = key|nil }; nil with nothing to store
function Loadouts.Store(snap)
    local s = store()
    if not s or type(snap) ~= "table" then return nil end
    local ref, any = {}, false
    for _, kind in ipairs(KINDS) do
        if type(snap[kind]) == "table" then
            ref[kind] = intern(s[kind], kind, snap[kind])
            any = true
        end
    end
    return any and ref or nil
end

--- Give `run` the snapshot's loadout, replacing any it held; a replaced loadout no run refers to
--- any more is dropped.
--- @return boolean attached
function Loadouts.Attach(run, snap)
    if type(run) ~= "table" then return false end
    local ref = Loadouts.Store(snap)
    if not ref then return false end
    local old = run.loadout
    run.loadout = ref
    if type(old) == "table" and (old.gear ~= ref.gear or old.talents ~= ref.talents) then Loadouts.Sweep() end
    return true
end

-- Every key a stored run refers to, by kind.
local function usedKeys(runs)
    local used = { gear = {}, talents = {} }
    for _, run in pairs(runs) do
        local ref = type(run) == "table" and run.loadout
        if type(ref) == "table" then
            for _, kind in ipairs(KINDS) do
                if ref[kind] ~= nil then used[kind][ref[kind]] = true end
            end
        end
    end
    return used
end

--- Drop every stored loadout no stored run refers to.
--- @return number dropped
function Loadouts.Sweep()
    local s, runs = store(), NS.db and NS.db.global and NS.db.global.runs
    if not s or type(runs) ~= "table" then return 0 end
    local used = usedKeys(runs)
    local n = 0
    for _, kind in ipairs(KINDS) do
        for key in pairs(s[kind]) do
            if not used[kind][key] then
                s[kind][key] = nil
                n = n + 1
            end
        end
    end
    if n > 0 then debug("dropped %d orphaned loadout(s)", n) end
    return n
end

--- A run's stored gear set and talent loadout (either nil: not recorded, or a run from before #6).
--- @return table|nil gear  { [slot] = link }
--- @return table|nil talents
function Loadouts.Of(run)
    local ref = type(run) == "table" and run.loadout
    local s = type(ref) == "table" and store()
    if not s then return nil, nil end
    local gear = ref.gear ~= nil and s.gear[ref.gear] or nil
    local talents = ref.talents ~= nil and s.talents[ref.talents] or nil
    return gear, talents
end

local function sameRacer(a, b)
    local ca = type(a.char) == "table" and a.char or {}
    local cb = type(b.char) == "table" and b.char or {}
    return ca.name == cb.name and ca.realm == cb.realm and ca.specID == cb.specID
end

--- The stored run raced just before `run` by the same character on the same spec that has a gear
--- set recorded, or nil (the Spec cell's "gear changed" note).
--- @param run table
--- @param runs table|nil  newest first; defaults to Recorder.All()
--- @return table|nil
function Loadouts.Previous(run, runs)
    if type(run) ~= "table" then return nil end
    local seen = false
    for _, r in ipairs(runs or NS.Recorder.All()) do
        if r.id == run.id then
            seen = true
        elseif seen and sameRacer(r, run) and type(r.loadout) == "table" and r.loadout.gear ~= nil then
            return r
        end
    end
    return nil
end

--- Whether `run`'s gear differs from the previous run's (Previous); nil when either has none.
--- @return boolean|nil changed, table|nil previous
function Loadouts.GearChanged(run, runs)
    local ref = type(run) == "table" and run.loadout
    if type(ref) ~= "table" or ref.gear == nil then return nil end
    local prev = Loadouts.Previous(run, runs)
    if not prev then return nil end
    return prev.loadout.gear ~= ref.gear, prev
end

--- How many sets each bucket holds.
--- @return number gear, number talents
function Loadouts.Counts()
    local s = store()
    if not s then return 0, 0 end
    local g, t = 0, 0
    for _ in pairs(s.gear) do g = g + 1 end
    for _ in pairs(s.talents) do t = t + 1 end
    return g, t
end
