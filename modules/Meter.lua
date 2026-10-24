local _, NS = ...
-- modules/Meter.lua — the ONLY caller of C_DamageMeter (spec §8 rule 1): availability, the session
-- list, the after-combat read of one session by ID (plain numbers or "sealed") and the live read of
-- the Current session (opaque values, passed through untouched).
--
-- Two reads, two contracts:
--   * ReadSession(id) is the SCORE path. It runs after combat, converts every value through
--     NS.Secrets.PlainNumber and refuses the whole read ("sealed") if a single one is still secret:
--     a half-plain result would rank a run on a partial number. Only then are the spells sorted.
--   * ReadLive() is the DISPLAY path. It runs in combat, when every number is secret, and therefore
--     does nothing to a value but copy it into a table (and ask `== nil` of it, for the live-DPS rungs). No arithmetic, no comparison, no `#` on a
--     client table, no sort: Blizzard's order is kept. The HUD hands the values to widget setters
--     and the numeric formatter, and nothing else.
--
-- Every client call is pcall'd: a client that raises on an ID it no longer holds must cost a read,
-- never a Lua error on the race path. Globals are read bare at CALL time so the harness's scripted
-- meter (tests/mock_meter.lua) and a client that loses the namespace both reach the guards.

local Meter = {}
NS.Meter = Meter

local Secrets = NS.Secrets

-- Resolved once at load: the enums do not change mid-session. The literals are the documented values,
-- for a client that ships the namespace without the enum.
local ENUM = Enum
Meter.STAT_DAMAGE_DONE = (ENUM and ENUM.DamageMeterType and ENUM.DamageMeterType.DamageDone) or 0
Meter.SESSION_CURRENT = (ENUM and ENUM.DamageMeterSessionType and ENUM.DamageMeterSessionType.Current) or 1
-- The Dps meter type: the live DPS figure's last rung (ReadLive).
Meter.STAT_DPS = (ENUM and ENUM.DamageMeterType and ENUM.DamageMeterType.Dps) or 1

-- The reason IsAvailable gives when the client has no meter API at all (Blizzard gives none then).
local NO_API_REASON = NS.L["Blizzard's damage meter is not available on this client."]

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Meter", fmt, ...) end
end

--- Call C_DamageMeter[name](...) safely.
--- @return boolean ok, any result  ok=false with result "unavailable" when the API is absent
local function call(name, ...)
    local api = C_DamageMeter
    local fn = api and api[name]
    if type(fn) ~= "function" then return false, "unavailable" end
    local ok, a, b = pcall(fn, ...)
    if not ok then
        debug("%s raised: %s", name, a)
        return false, "error: " .. tostring(a)
    end
    return true, a, b
end

-- ---------------------------------------------------------------------------
-- Availability and the session list
-- ---------------------------------------------------------------------------

--- Whether the built-in meter is usable. The reason is Blizzard's own, verbatim (spec §9).
--- @return boolean ok, string|nil reason
function Meter.IsAvailable()
    local ok, available, reason = call("IsDamageMeterAvailable")
    if not ok then
        if available == "unavailable" then return false, NO_API_REASON end
        return false, available
    end
    if available then return true, nil end
    return false, reason
end

--- Every session the client still holds, as a set of plain IDs. An ID is plain even in combat
--- (spec §2); one that is not is skipped rather than keyed on.
--- @return table<number, boolean>
function Meter.SessionIDs()
    local out = {}
    local ok, list = call("GetAvailableCombatSessions")
    if not ok then return out end
    Secrets.SafeIterate(list, function(_, e)
        if not Secrets.CanAccessTable(e) then return end
        local id = Secrets.PlainNumber(e.sessionID)
        if id then out[id] = true end
    end)
    return out
end

--- Whether the client still holds session `id`.
--- @param id number|nil
--- @return boolean
function Meter.HasSession(id)
    if id == nil then return false end
    return Meter.SessionIDs()[id] == true
end

-- ---------------------------------------------------------------------------
-- The score path: one session by ID, after combat
-- ---------------------------------------------------------------------------

-- A read in progress: `sealed` latches the moment any present value is still secret.
local function plain(acc, v)
    if Secrets.IsSealed(v) then
        acc.sealed = true
        return nil
    end
    return Secrets.PlainNumber(v)
end

-- The player's own row in the session's sources: the local-player flag, else the GUID.
local function playerRow(session, guid)
    local row
    Secrets.SafeIterate(session.combatSources, function(_, src)
        if not Secrets.CanAccessTable(src) then return end
        if Secrets.PlainTruth(src.isLocalPlayer) or Secrets.PlainEquals(src.sourceGUID, guid) then
            row = src
            return false
        end
    end)
    return row
end

local function readSpells(acc, source)
    local spells = {}
    if not Secrets.CanAccessTable(source) then return spells end
    Secrets.SafeIterate(source.combatSpells, function(_, e)
        if not Secrets.CanAccessTable(e) then
            acc.sealed = true
            return false
        end
        local id, dmg, dps = plain(acc, e.spellID), plain(acc, e.totalAmount), plain(acc, e.amountPerSecond)
        if id then spells[#spells + 1] = { id = id, dmg = dmg or 0, dps = dps or 0 } end
    end)
    return spells
end

local function byDamage(a, b)
    if a.dmg ~= b.dmg then return a.dmg > b.dmg end
    return a.id < b.id
end

local function sessionTables(id, guid)
    local ok, session = call("GetCombatSessionFromID", id, Meter.STAT_DAMAGE_DONE)
    if not ok then return nil, nil, session end
    if session == nil then return nil, nil, "missing" end
    if not Secrets.CanAccessTable(session) then return nil, nil, "sealed" end
    local okSrc, source = call("GetCombatSessionSourceFromID", id, Meter.STAT_DAMAGE_DONE, guid, nil)
    if not okSrc then return nil, nil, source end
    if source ~= nil and not Secrets.CanAccessTable(source) then return nil, nil, "sealed" end
    return session, source, nil
end

--- Read session `id` after combat. Every value in the result is a plain number; spells are sorted by
--- damage, highest first. The player's damage is their own row's total, never the session total.
--- @param id number
--- @return table|nil result  { damage, meterDps, duration, spells = { {id, dmg, dps}, ... } }
--- @return string|nil err    "missing" | "sealed" | "unavailable" | "error: <message>"
function Meter.ReadSession(id)
    if id == nil then return nil, "missing" end
    local guid = UnitGUID("player")
    local session, source, err = sessionTables(id, guid)
    if err then return nil, err end

    local acc = { sealed = false }
    local row = playerRow(session, guid)
    local damage = row and plain(acc, row.totalAmount)
    local meterDps = row and plain(acc, row.amountPerSecond)
    local duration = plain(acc, session.durationSeconds)
    if damage == nil and source ~= nil then damage = plain(acc, source.totalAmount) end
    local spells = readSpells(acc, source)
    if acc.sealed then return nil, "sealed" end

    table.sort(spells, byDamage)
    return { damage = damage or 0, meterDps = meterDps or 0, duration = duration or 0, spells = spells }
end

-- ---------------------------------------------------------------------------
-- The target probe's read: the enemies a session's damage landed on, after combat
-- ---------------------------------------------------------------------------

-- The enemy view's meter type: the enum's, or nil on a client that does not name it (then the probe
-- reports it unavailable rather than guessing a number).
Meter.STAT_ENEMY_TAKEN = ENUM and ENUM.DamageMeterType and ENUM.DamageMeterType.EnemyDamageTaken

--- The enemies in session `id`'s EnemyDamageTaken view (modules/TargetProbe.lua, debug only): one row
--- per enemy source, plain, or "sealed" when any value still is. The probe measured identical dummies
--- merged into one row (sourceCreatureID, no GUID); this read is what checks that again.
--- @param id number
--- @return table|nil rows  { { name, creatureID, guid, damage }, ... }
--- @return string|nil err  "missing" | "sealed" | "unavailable" | "error: <message>"
function Meter.ReadEnemies(id)
    if id == nil then return nil, "missing" end
    if Meter.STAT_ENEMY_TAKEN == nil then return nil, "unavailable" end
    local ok, session = call("GetCombatSessionFromID", id, Meter.STAT_ENEMY_TAKEN)
    if not ok then return nil, session end
    if session == nil then return nil, "missing" end
    if not Secrets.CanAccessTable(session) then return nil, "sealed" end
    local acc, rows = { sealed = false }, {}
    Secrets.SafeIterate(session.combatSources, function(_, src)
        if not Secrets.CanAccessTable(src) then
            acc.sealed = true
            return false
        end
        rows[#rows + 1] = {
            name = Secrets.PlainString(src.name), creatureID = plain(acc, src.sourceCreatureID),
            guid = Secrets.PlainString(src.sourceGUID), damage = plain(acc, src.totalAmount),
        }
    end)
    if acc.sealed then return nil, "sealed" end
    return rows
end

-- ---------------------------------------------------------------------------
-- The display path: the Current session, live, opaque
-- ---------------------------------------------------------------------------

-- THE LIVE DPS FIGURE, a rung chain. The live client's source table carries no amountPerSecond (the
-- owner's smoke test, 2026-10-23), so the figure falls through, each rung an opaque copy:
--   a) "source"    the source table's own amountPerSecond;
--   b) "localRow"  the Current DamageDone session's combatSources row whose isLocalPlayer is plainly
--                  true (the probe measured the flag readable mid-combat), its amountPerSecond;
--   c) "dpsType"   the Dps meter type's source for the player: its amountPerSecond only. No probe has
--                  read that type, so its totalAmount (the DamageDone type's damage total) is never
--                  taken for a rate: a dash beats a confident wrong number (smoke C3 records it).
-- Each is the METER's rate (its total over its whole-second session duration): a live figure only.
-- The score stays ours (spec §5.1). damage / elapsed is never computed: arithmetic on a secret.
-- The rung that served is logged once per race (NewLiveRace resets it) under the Meter tag, and is
-- tried first on the next read (the 4 Hz path skips the session build of a rung that went quiet).
local loggedRung, servedRung

-- localRowDps's iterator, at file scope so no closure is made per read; it writes rowDps.
local rowDps
local function takeLocalRow(_, src)
    if not Secrets.CanAccessTable(src) then return end
    if Secrets.PlainTruth(src.isLocalPlayer) then
        rowDps = src.amountPerSecond
        return false
    end
end

local function localRowDps()
    local ok, session = call("GetCombatSessionFromType", Meter.SESSION_CURRENT, Meter.STAT_DAMAGE_DONE)
    if not ok or not Secrets.CanAccessTable(session) then return nil end
    rowDps = nil
    Secrets.SafeIterate(session.combatSources, takeLocalRow)
    local dps = rowDps
    rowDps = nil
    return dps
end

local function dpsTypeRate()
    local ok, src = call("GetCombatSessionSourceFromType", Meter.SESSION_CURRENT, Meter.STAT_DPS,
        UnitGUID("player"), nil)
    if not ok or not Secrets.CanAccessTable(src) then return nil end
    return src.amountPerSecond
end

local function sourceDps(source) return source.amountPerSecond end

local RUNGS = { { "source", sourceDps }, { "localRow", localRowDps }, { "dpsType", dpsTypeRate } }
local RUNG_FN = {}
for _, r in ipairs(RUNGS) do RUNG_FN[r[1]] = r[2] end

--- The live DPS figure (opaque) and the rung that served it, or nil, nil. The rung that served last
--- goes first; on nil the chain runs in order (skipping it).
local function liveDps(source)
    local first = servedRung and RUNG_FN[servedRung]
    if first then
        local dps = first(source)
        if dps ~= nil then return dps, servedRung end
    end
    for _, r in ipairs(RUNGS) do
        if r[1] ~= servedRung then
            local dps = r[2](source)
            if dps ~= nil then
                servedRung = r[1]
                return dps, r[1]
            end
        end
    end
    servedRung = nil
    return nil, nil
end

--- A new race: the next live read logs the rung that serves it (modules/Hud.lua, on arm).
function Meter.NewLiveRace()
    loggedRung, servedRung = nil, nil
end

--- Read the player's live breakdown from the Current session. Every value is OPAQUE (secret in
--- combat) and is only copied; spells keep Blizzard's order. `dps` is the first live-DPS rung that
--- answers (see THE LIVE DPS FIGURE above), and nil when none does; `rung` names it.
--- @return table|nil live  { total, dps, rung, maxAmount, spells = { {spellID, total, dps}, ... } }
function Meter.ReadLive()
    local ok, source = call("GetCombatSessionSourceFromType", Meter.SESSION_CURRENT,
        Meter.STAT_DAMAGE_DONE, UnitGUID("player"), nil)
    if not ok or not Secrets.CanAccessTable(source) then return nil end
    local spells = {}
    Secrets.SafeIterate(source.combatSpells, function(_, e)
        if not Secrets.CanAccessTable(e) then return end
        spells[#spells + 1] = { spellID = e.spellID, total = e.totalAmount, dps = e.amountPerSecond }
    end)
    local dps, rung = liveDps(source)
    local name = rung or "none"
    if name ~= loggedRung then
        loggedRung = name
        debug("live DPS from rung %s", name)
    end
    return { total = source.totalAmount, dps = dps, rung = rung, maxAmount = source.maxAmount,
             spells = spells }
end
