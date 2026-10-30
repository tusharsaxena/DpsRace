local _, NS = ...
-- modules/DummyList.lua — your own training dummies (#9): the creatures this profile counts as dummies
-- on top of the shipped catalog (defaults/Dummies.lua), the built-ins it switches off, and what the game
-- said about each creature `/dr targetdummy` captured.
--
-- THE ROW. One plain string, the profile's `race.dummies`, written WHOLE through the seam (NS.SetByPath)
-- as the late-cast ignore list is (modules/LateIgnore.lua), so the CLI's get/set/reset and the page's
-- Defaults reach it like any row: "243300:cleave,-243205", ascending by creature ID. `id:category` marks
-- a creature as a dummy; `-id` switches a built-in off. A built-in is never recategorized.
--
-- READ TIME. Dummies.Lookup reads this list each time it is asked, and a stored run's category is read
-- through Dummies.CategoryOf (by the run's creature ID), so a change, or a profile switch, recategorizes
-- every stored run. Caches keyed on the category listen for SETTINGS_CHANGED on PATH and on "profile".
--
-- THE CAPTURES. `global.dummies.captures[npcID]`: data, not a setting, beside the run store. Written by
-- Capture (the slash verb's `add` and `capture`), never by a race. A sealed field is left out.

local DummyList = {}
NS.DummyList = DummyList

local Secrets = NS.Secrets

DummyList.PATH = "race.dummies"
DummyList.CATEGORY_PATH = "race.dummyCategory"
DummyList.DEFAULT = NS.defaults.profile.race.dummies

--- The categories a dummy can be given ("other" is what a creature that is no dummy reads as).
DummyList.KINDS = { "single", "cleave", "dungeoneer", "boss", "pvp" }
local KIND = {}
for _, k in ipairs(DummyList.KINDS) do KIND[k] = true end

--- The largest creature ID a list entry takes: above it a number has no integer form to write back.
DummyList.MAX_ID = 2 ^ 31 - 1

local function builtIn(id) return NS.Dummies.BY_ID[id] ~= nil end

-- ── the stored text ─────────────────────────────────────────────────────────────────────────────

--- The entries in `text`, ascending by creature ID and each ID once (the last one written wins), as
--- { id, category } for a dummy and { id, hidden = true } for a switched-off built-in; nil when `text`
--- is not a string or an entry does not parse. Pure.
--- @return table|nil entries
function DummyList.Parse(text)
    if type(text) ~= "string" then return nil end
    local byId = {}
    for token in (text .. ","):gmatch("([^,]*),") do
        local word = token:match("^%s*(.-)%s*$"):lower()
        if word ~= "" then
            local hid = word:match("^%-(%d+)$")
            local num, kind = word:match("^(%d+)%s*:%s*(%a+)$")
            local id = tonumber(hid or num)
            if not id or id < 1 or id > DummyList.MAX_ID or (num and not KIND[kind]) then return nil end
            byId[id] = hid and { id = id, hidden = true } or { id = id, category = kind }
        end
    end
    local out = {}
    for _, e in pairs(byId) do out[#out + 1] = e end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- `entries` without what cannot apply: a custom entry for a built-in, a hide for a non-built-in.
local function applicable(entries)
    local out = {}
    for _, e in ipairs(entries) do
        if (e.hidden and builtIn(e.id)) or (not e.hidden and not builtIn(e.id)) then out[#out + 1] = e end
    end
    return out
end

--- The stored text for `entries`: ascending, comma-separated ("243300:cleave,-243205").
function DummyList.Join(entries)
    table.sort(entries, function(a, b) return a.id < b.id end)
    local words = {}
    for i, e in ipairs(entries) do
        words[i] = e.hidden and ("-" .. e.id) or (e.id .. ":" .. e.category)
    end
    return table.concat(words, ",")
end

--- The row's normalize: `text` as Join writes it, with what cannot apply dropped, or nil (refused) when
--- it does not parse.
function DummyList.Normalize(text)
    local entries = DummyList.Parse(text)
    return entries and DummyList.Join(applicable(entries)) or nil
end

-- The parse of the last stored text, by ID, so a run list is judged against one parse.
local listText, listById

local function read()
    local text = NS.GetSetting and NS.GetSetting(DummyList.PATH) or nil
    if text ~= listText or not listById then
        listText, listById = text, {}
        for _, e in ipairs(applicable(DummyList.Parse(text) or {})) do listById[e.id] = e end
    end
    return listById
end

--- This profile's entry for `id`, a copy: { id, category } or { id, hidden = true }; nil when the
--- profile leaves the creature as the catalog has it.
function DummyList.Entry(id)
    if not Secrets.IsSafeKey(id) then return nil end
    local e = read()[id]
    return e and { id = e.id, category = e.category, hidden = e.hidden } or nil
end

--- Every entry, ascending by ID (copies).
function DummyList.Entries()
    local out = {}
    for _, e in pairs(read()) do out[#out + 1] = { id = e.id, category = e.category, hidden = e.hidden } end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- ── the writes ──────────────────────────────────────────────────────────────────────────────────

local function write(byId)
    local entries = {}
    for _, e in pairs(byId) do entries[#entries + 1] = e end
    return NS.SetByPath(DummyList.PATH, DummyList.Join(entries)) and true or false
end

local function copy()
    local out = {}
    for id, e in pairs(read()) do out[id] = { id = e.id, category = e.category, hidden = e.hidden } end
    return out
end

local function plainId(id)
    id = Secrets.PlainNumber(id)
    return type(id) == "number" and id >= 1 and id <= DummyList.MAX_ID and id % 1 == 0 and id or nil
end

--- Mark creature `id` as a dummy of `category`. A switched-off built-in is switched back on (the
--- category is the catalog's); a built-in already on changes nothing. A custom entry takes the new
--- category.
--- @return string|nil outcome  "added" | "restored" | "changed" | nil (nothing to do or refused)
function DummyList.Add(id, category)
    id = plainId(id)
    if not id then return nil end
    local list = copy()
    if builtIn(id) then
        if not (list[id] and list[id].hidden) then return nil end
        list[id] = nil
        return write(list) and "restored" or nil
    end
    if not KIND[category] then return nil end
    local had = list[id]
    if had and had.category == category then return nil end
    list[id] = { id = id, category = category }
    return write(list) and (had and "changed" or "added") or nil
end

--- Stop counting creature `id` as a dummy: a custom entry goes, a built-in is switched off.
--- @return string|nil outcome  "removed" | "hidden" | nil (not a dummy now)
function DummyList.Remove(id)
    id = plainId(id)
    if not id then return nil end
    local list = copy()
    if builtIn(id) then
        if list[id] and list[id].hidden then return nil end
        list[id] = { id = id, hidden = true }
        return write(list) and "hidden" or nil
    end
    if not list[id] then return nil end
    list[id] = nil
    return write(list) and "removed" or nil
end

--- Back to the catalog alone (one write of the default, as `/dr reset race.dummies` does).
function DummyList.Reset()
    return NS.SetByPath(DummyList.PATH, DummyList.DEFAULT) and true or false
end

-- ── the category a new dummy gets ───────────────────────────────────────────────────────────────

-- Name words that say the category, in this order (the shipped dummies' English names).
local NAME_HINTS = { { "cleave", "cleave" }, { "dungeoneer", "dungeoneer" }, { "pvp", "pvp" } }

--- The category a creature's own details suggest: a name word (Cleave, Dungeoneer, PvP), then a boss
--- classification or a skull level, else single. Pure.
--- @param t table  { name, classification, level }
function DummyList.Infer(t)
    t = type(t) == "table" and t or {}
    local name = type(t.name) == "string" and t.name:lower() or ""
    for _, hint in ipairs(NAME_HINTS) do
        if name:find(hint[1], 1, true) then return hint[2] end
    end
    if t.classification == "worldboss" or t.level == -1 then return "boss" end
    return "single"
end

--- A typed category word as a category key ("Cleave", "boss"), or nil. "auto" answers nil too.
function DummyList.CategoryWord(word)
    word = type(word) == "string" and word:match("^%s*(.-)%s*$"):lower() or ""
    if KIND[word] then return word end
    for _, k in ipairs(DummyList.KINDS) do
        if NS.Dummies.Label(k):lower() == word then return k end
    end
    return nil
end

--- The category a new dummy gets: `word` when it names one, else the row's (race.dummyCategory), and
--- `auto` (or anything unknown) infers from `t`.
function DummyList.CategoryFor(t, word)
    local typed = DummyList.CategoryWord(word)
    if typed then return typed end
    local row = NS.GetSetting and NS.GetSetting(DummyList.CATEGORY_PATH)
    if KIND[row] then return row end
    return DummyList.Infer(t)
end

-- ── the captures ────────────────────────────────────────────────────────────────────────────────

local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c
end

local function store()
    local g = NS.db and NS.db.global
    if type(g) ~= "table" then return nil end
    g.dummies = type(g.dummies) == "table" and g.dummies or {}
    g.dummies.captures = type(g.dummies.captures) == "table" and g.dummies.captures or {}
    return g.dummies.captures
end

-- The player's position on map `mapID` as two plain fractions, or nil (no map, no API, a sealed read).
local function playerXY(mapID)
    local map = C_Map
    if not (mapID and map and map.GetPlayerMapPosition) then return nil end
    local pos = ask(map.GetPlayerMapPosition, mapID, "player")
    if type(pos) ~= "table" or type(pos.GetXY) ~= "function" then return nil end
    local ok, px, py = pcall(pos.GetXY, pos)
    if not ok then return nil end
    return Secrets.PlainNumber(px), Secrets.PlainNumber(py)
end

-- A map fraction as a percentage to two places, or nil.
local function percent(v)
    return v and math.floor(v * 10000 + 0.5) / 100 or nil
end

--- What the game says now about `unit` and where the player stands: every field a sealed read leaves
--- out. Reads only.
--- @return table|nil read  nil when the unit is no creature
function DummyList.Read(unit)
    unit = unit or "target"
    if not Secrets.PlainTruth(ask(UnitExists, unit)) then return nil end
    local id = NS.Recorder.NpcIDOf(unit)
    if not id then return nil end
    local t = NS.Recorder.SnapshotTarget(unit)
    local faction, pvp = ask(UnitFactionGroup, unit), ask(UnitIsPVP, unit)
    if Secrets.IsSealed(pvp) or type(pvp) ~= "boolean" then pvp = nil end
    local where = NS.Recorder.SnapshotWhere()
    local x, y = playerXY(where.mapID)
    return {
        npcID = id, name = t.name, level = t.level, classification = t.classification,
        health = Secrets.PlainNumber(ask(UnitHealthMax, unit)),
        creatureType = Secrets.PlainString(ask(UnitCreatureType, unit)),
        pvp = pvp,
        faction = Secrets.PlainString(faction),
        reaction = Secrets.PlainNumber(ask(UnitReaction, unit, "player")),
        mapID = where.mapID, zone = where.zone, subzone = where.subzone,
        x = percent(x), y = percent(y),
    }
end

local DETAIL_FIELDS = { "name", "level", "classification", "health", "creatureType", "pvp", "faction", "reaction" }

--- Save what the game says about a creature (`r`, a DummyList.Read) under its creature ID: the latest
--- details, the first and last dates, a count, and one line per map it was captured on.
--- @return table|nil capture  the stored record, nil with no store
function DummyList.Capture(r)
    local captures = store()
    if not (captures and type(r) == "table" and r.npcID) then return nil end
    local now = time()
    local c = captures[r.npcID] or { first = now, count = 0, places = {} }
    for _, key in ipairs(DETAIL_FIELDS) do
        if r[key] ~= nil then c[key] = r[key] end
    end
    c.last, c.count = now, (c.count or 0) + 1
    c.addon = NS.Version and NS.Version() or nil
    local _, _, _, build = ask(GetBuildInfo)
    c.build = Secrets.PlainNumber(build)
    if r.mapID then
        c.places = type(c.places) == "table" and c.places or {}
        c.places[r.mapID] = { zone = r.zone, subzone = r.subzone, x = r.x, y = r.y, date = now }
    end
    captures[r.npcID] = c
    return c
end

--- The capture of creature `id`, or nil (read only).
function DummyList.Captured(id)
    local captures = store()
    if not (captures and Secrets.IsSafeKey(id)) then return nil end
    return captures[id]
end

--- The name `id` goes by: its capture's, else the catalog's, else nil.
function DummyList.NameOf(id)
    local c = DummyList.Captured(id)
    if c and type(c.name) == "string" then return c.name end
    local d = Secrets.IsSafeKey(id) and NS.Dummies.BY_ID[id]
    return d and d.name or nil
end

-- The lowest creature ID a capture or the catalog names `want` (lowercase), or nil.
local function lowestNamed(want)
    local found
    local function consider(cid, name)
        if type(name) == "string" and name:lower() == want and (not found or cid < found) then found = cid end
    end
    for cid, c in pairs(store() or {}) do
        if type(c) == "table" then consider(cid, c.name) end
    end
    for cid, d in pairs(NS.Dummies.BY_ID) do consider(cid, d.name) end
    return found
end

-- A typed creature ID within 1..MAX_ID, `false` for digits out of range, nil for no digits.
local function typedID(text)
    local id = tonumber(text:match("^%d+$") or "")
    if not id then return nil end
    if id < 1 or id > DummyList.MAX_ID then return false end
    return id
end

--- A typed creature: a number, else a captured name (case-insensitive; the lowest ID when several
--- share it). Answers `id` or `nil, reason` ("empty", "notFound").
function DummyList.Resolve(text)
    if type(text) == "number" then text = tostring(text) end
    text = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
    if text == "" then return nil, "empty" end
    local id = typedID(text)
    if id then return id end
    if id == false then return nil, "notFound" end
    local found = lowestNamed(text:lower())
    if found then return found end
    return nil, "notFound"
end
