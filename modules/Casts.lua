local _, NS = ...
-- modules/Casts.lua — the race's cast list (#14): every spell the player and the pet cast from the arm
-- to the result, with its time on the race clock, and each spell's base cooldown, stored on the run
-- (run.casts) for the chart's cooldown dots and the ability timeline. Usage (modules/Usage.lua) reads
-- the same list to tell which on-use items and consumables were used.
--
-- THE SOURCE is UNIT_SPELLCAST_SUCCEEDED for `player` and `pet`, from ARMED through STOPPING
-- (modules/Watchers.lua hands every cast event here as well as to Race.OnCast, whose late-cast judging
-- is its own). The probe (2026-10-26) measured both units' spell IDs and castGUIDs plain in combat;
-- each still passes through NS.Secrets, and a sealed spell ID is dropped and counted (`dropped`).
--
-- FILTERS. An auto-repeat attack's every swing or shot fires SUCCEEDED (Casts.AUTO: never a press); a
-- castGUID heard twice counts once; and while a player channel is open (CHANNEL_START to CHANNEL_STOP)
-- only its first SUCCEEDED counts, as a channel may fire one per tick.
--
-- TIME. Each cast is heard at GetTime() and kept raw until Race starts the clock (Casts.Start); the
-- stored `t` is seconds from that start in whole centiseconds, negative for a pre-pull cast heard while
-- armed.
--
-- THE RECORD: { v = 1, list = "<cs>:<id>,<cs>:p<id>,...", spells = { [id] = cdMs }, dropped = n },
-- `p` marking a pet cast. Every value is plain. Encode and Decode are pure; no cap on the list.

local Casts = {}
NS.Casts = Casts

local Secrets = NS.Secrets

-- The record's own format.
Casts.VERSION = 1
-- Auto-repeat attacks: Auto Shot, Auto Attack, Shoot (a wand).
Casts.AUTO = { [75] = true, [6603] = true, [5019] = true }
-- An important ability's base cooldown is MORE than this (ms): what the chart marks with a dot.
Casts.IMPORTANT_MS = 15000

-- The race's capture: on (between Begin and Stop), the raw casts { at, id, pet }, the castGUIDs seen,
-- the open player channel ({ id, counted }), each spell's base cooldown, the dropped count and the
-- clock's start (nil until Start).
local on = false
local raw, guids, channel, cooldowns, dropped, origin = {}, {}, nil, {}, 0, nil

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Casts", fmt, ...) end
end

local function passFirst(ok, v)
    if ok then return v end
    return nil
end

-- A spell's base cooldown in ms (GetSpellBaseCooldown, plain in and out of combat per the probe), or
-- nil when the client cannot say.
local function baseCooldown(id)
    local fn = GetSpellBaseCooldown
    if type(fn) ~= "function" then return nil end
    return Secrets.PlainNumber(passFirst(pcall(fn, id)))
end

-- ── the capture ─────────────────────────────────────────────────────────────────────────────────

--- A new race is armed: the list starts empty and casts are heard from now.
function Casts.Begin()
    on = true
    raw, guids, channel, cooldowns, dropped, origin = {}, {}, nil, {}, 0, nil
end

--- The race clock started at `t` (GetTime()): the zero every stored time is measured from.
function Casts.Start(t)
    if on then origin = t end
end

--- The capture ends (the result is read); the list stays readable until the next Begin or Reset.
function Casts.Stop()
    on = false
end

--- Drop everything (a cancel, a stand-down).
function Casts.Reset()
    on = false
    raw, guids, channel, cooldowns, dropped, origin = {}, {}, nil, {}, 0, nil
end

--- Whether casts are being heard now.
function Casts.Collecting()
    return on
end

-- Whether a player SUCCEEDED is a tick of the open channel (only its first counts).
local function channelTick(id)
    if not channel or channel.id ~= id then return false end
    if channel.counted then return true end
    channel.counted = true
    return false
end

-- A channel opens. A SUCCEEDED for the same spell already heard on this frame was its start.
local function openChannel(id, t)
    if not id then return end
    local last = raw[#raw]
    local counted = last ~= nil and not last.pet and last.id == id and last.at == t
    channel = { id = id, counted = counted }
end

local function add(id, pet, t)
    raw[#raw + 1] = { at = t, id = id, pet = pet }
    if cooldowns[id] == nil then cooldowns[id] = baseCooldown(id) or false end
end

-- One SUCCEEDED: filtered, deduped, then kept.
local function succeeded(unit, spellID, castGUID, t)
    local id = Secrets.PlainNumber(spellID)
    if not id then
        dropped = dropped + 1
        return
    end
    if Casts.AUTO[id] then return end
    local guid = Secrets.PlainString(castGUID)
    if guid then
        if guids[guid] then return end
        guids[guid] = true
    end
    local pet = unit == "pet"
    if not pet and channelTick(id) then return end
    add(id, pet, t)
end

--- A cast event (modules/Watchers.lua): kind "succeeded" | "channel" | "channelStop" (others are
--- ignored), the unit, the event's spell ID and castGUID (either may be secret) and `t` (GetTime()).
function Casts.Hear(kind, unit, spellID, castGUID, t)
    if not on or (unit ~= "player" and unit ~= "pet") then return end
    if kind == "succeeded" then
        succeeded(unit, spellID, castGUID, t)
    elseif unit == "player" and kind == "channel" then
        openChannel(Secrets.PlainNumber(spellID), t)
    elseif unit == "player" and kind == "channelStop" then
        channel = nil
    end
end

-- Seconds from the clock's start to `at`, to the centisecond.
local function centis(at)
    return math.floor((at - origin) * 100 + 0.5)
end

--- The current race's casts (same shape as Decode), times on the race clock; empty before the clock
--- started. What the running HUD's chart reads.
--- @return table list  { { t, id, pet }, ... }
function Casts.Live()
    local out = {}
    if not origin then return out end
    for i, c in ipairs(raw) do out[i] = { t = centis(c.at) / 100, id = c.id, pet = c.pet } end
    return out
end

--- The current race's base cooldowns, { [id] = ms } (a spell whose cooldown is unknown is absent).
function Casts.LiveSpells()
    local out = {}
    for id, ms in pairs(cooldowns) do
        if ms then out[id] = ms end
    end
    return out
end

--- The record for the current race (nil before the clock started): what Race stores as run.casts.
--- @return table|nil record  { v, list, spells, dropped }
function Casts.Record()
    if not origin then return nil end
    local rec = { v = Casts.VERSION, list = Casts.Encode(Casts.Live()), spells = Casts.LiveSpells(),
                  dropped = dropped }
    debug("%d cast(s) kept, %d dropped", #raw, dropped)
    return rec
end

-- ── the record format (pure) ────────────────────────────────────────────────────────────────────

--- A cast list as the stored string: "<cs>:<id>" per cast, "p" before a pet cast's id, comma-joined.
--- @param list table  { { t = seconds, id = n, pet = bool }, ... }
--- @return string
function Casts.Encode(list)
    local parts = {}
    for i, c in ipairs(list or {}) do
        local cs = math.floor(c.t * 100 + 0.5)
        parts[i] = ("%d:%s%d"):format(cs, c.pet and "p" or "", c.id)
    end
    return table.concat(parts, ",")
end

--- The stored string as a list, in stored order; an entry that does not parse is skipped.
--- @param s string|nil
--- @return table list  { { t = seconds, id = n, pet = bool }, ... }
function Casts.Decode(s)
    local out = {}
    if type(s) ~= "string" then return out end
    for cs, p, id in s:gmatch("(%-?%d+):(p?)(%d+)") do
        out[#out + 1] = { t = tonumber(cs) / 100, id = tonumber(id), pet = p == "p" }
    end
    return out
end

-- The record on a run, or nil (a run from before format 3, or one resumed after a /reload).
local function recordOf(run)
    local rec = type(run) == "table" and run.casts
    if type(rec) ~= "table" or type(rec.list) ~= "string" then return nil end
    return rec
end

--- A run's casts, decoded; nil when the run has none recorded.
--- @return table|nil list
function Casts.Of(run)
    local rec = recordOf(run)
    return rec and Casts.Decode(rec.list) or nil
end

--- Whether a spell is important: its base cooldown is more than IMPORTANT_MS.
--- @param spells table|nil  { [id] = ms }
function Casts.IsImportant(spells, id)
    local ms = type(spells) == "table" and spells[id]
    return type(ms) == "number" and ms > Casts.IMPORTANT_MS
end

--- The casts in `list` whose spell is important by `spells`.
--- @return table list
function Casts.Filter(list, spells)
    local out = {}
    for _, c in ipairs(list or {}) do
        if Casts.IsImportant(spells, c.id) then out[#out + 1] = c end
    end
    return out
end

--- A run's important casts (the chart's dots); empty when it has none recorded.
--- @return table list
function Casts.Important(run)
    local rec = recordOf(run)
    if not rec then return {} end
    return Casts.Filter(Casts.Decode(rec.list), rec.spells)
end

local function byImportance(a, b)
    local ia, ib = a.cd > Casts.IMPORTANT_MS, b.cd > Casts.IMPORTANT_MS
    if ia ~= ib then return ia end
    if ia and a.cd ~= b.cd then return a.cd > b.cd end
    if a.count ~= b.count then return a.count > b.count end
    if a.pet ~= b.pet then return not a.pet end
    return a.id < b.id
end

--- The casts grouped by ability (the timeline's rows): one group per spell and caster, its times in
--- order. Important abilities first, longest cooldown first; then the rest by count.
--- @return table groups  { { id, pet, cd (ms, 0 when unknown), count, times = { t, ... } }, ... }
function Casts.Group(list, spells)
    local groups, index = {}, {}
    for _, c in ipairs(list or {}) do
        local key = (c.pet and "p" or "") .. c.id
        local g = index[key]
        if not g then
            local ms = type(spells) == "table" and spells[c.id]
            g = { id = c.id, pet = c.pet == true, cd = type(ms) == "number" and ms or 0, count = 0, times = {} }
            index[key] = g
            groups[#groups + 1] = g
        end
        g.count = g.count + 1
        g.times[g.count] = c.t
    end
    for _, g in ipairs(groups) do table.sort(g.times) end
    table.sort(groups, byImportance)
    return groups
end
