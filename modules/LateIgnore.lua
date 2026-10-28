local _, NS = ...
-- modules/LateIgnore.lua — the late-cast ignore list (#8): the spells a cast after the grace never
-- flags (Feign Death, Vanish, a hearthstone out of the fight). One plain string of spell IDs, the
-- profile's `race.lateIgnore`, written WHOLE through the seam (NS.SetByPath), as the Usage tab's hidden
-- items are (modules/Usage.lua), so the CLI's get/set/reset and the page's Defaults reach it like any
-- row.
--
-- READ TIME. A run keeps every late cast it recorded (modules/Race.lua judge); Scoring.Flags reads this
-- list each time it builds a run's flags, so a change re-scores every stored run, and a profile switch
-- re-scores them by the other profile's list. Caches keyed on the flags listen for SETTINGS_CHANGED on
-- PATH and on "profile" (core/Database.lua). This file posts nothing on the bus: the seam announces.
--
-- THE HEARTHSTONE. 8690 in the list stands for every hearthstone variant (defaults/Hearthstones.lua):
-- one entry, expanded only in Set(). A variant can also be listed on its own while 8690 is not.
-- A late cast stored with no spell ID (a sealed one) is never ignored.

local LateIgnore = {}
NS.LateIgnore = LateIgnore

LateIgnore.PATH = "race.lateIgnore"
--- The list a new profile starts with (defaults/Profile.lua, the one place it is written).
LateIgnore.DEFAULT = NS.defaults.profile.race.lateIgnore
--- The spell that stands for every hearthstone variant.
LateIgnore.HEARTHSTONE = 8690

local HEARTH = LateIgnore.HEARTHSTONE
local HEARTH_SET = {}
for _, id in ipairs(NS.HEARTHSTONE_SPELLS or {}) do HEARTH_SET[id] = true end

--- Whether `id` is one of the hearthstone variants (8690 among them).
function LateIgnore.IsHearthstone(id)
    return HEARTH_SET[id] == true
end

-- ── the stored text ─────────────────────────────────────────────────────────────────────────────

--- The spell IDs in `text` ("5384, 1856"), ascending and each once; nil when `text` is not a string
--- or holds anything but positive whole numbers between the commas. Pure.
--- @return table|nil ids
function LateIgnore.Parse(text)
    if type(text) ~= "string" then return nil end
    local ids, seen = {}, {}
    for token in (text .. ","):gmatch("([^,]*),") do
        local word = token:match("^%s*(.-)%s*$")
        if word ~= "" then
            local id = word:match("^%d+$") and tonumber(word)
            if not id or id < 1 then return nil end
            if not seen[id] then seen[id], ids[#ids + 1] = true, id end
        end
    end
    table.sort(ids)
    return ids
end

-- `ids` without the hearthstone variants 8690 already covers (a fresh array, order kept).
local function compact(ids)
    local whole = false
    for _, id in ipairs(ids) do
        if id == HEARTH then whole = true end
    end
    local out = {}
    for _, id in ipairs(ids) do
        if not whole or id == HEARTH or not HEARTH_SET[id] then out[#out + 1] = id end
    end
    return out
end

--- The stored text for `ids`: ascending, comma-separated ("66,1856"). Sorts `ids` in place.
function LateIgnore.Join(ids)
    table.sort(ids)
    local words = {}
    for i, id in ipairs(ids) do words[i] = tostring(id) end
    return table.concat(words, ",")
end

--- The row's normalize: `text` as Join writes it, with any variant 8690 covers dropped, or nil
--- (refused) when it does not parse.
function LateIgnore.Normalize(text)
    local ids = LateIgnore.Parse(text)
    return ids and LateIgnore.Join(compact(ids)) or nil
end

-- The parsed list of the last stored text and its expanded set, so the flags of a whole run list
-- are judged against one parse.
local listText, listIds, listSet

local function read()
    local text = NS.GetSetting(LateIgnore.PATH)
    if text ~= listText or not listIds then
        listText, listIds, listSet = text, compact(LateIgnore.Parse(text) or {}), {}
        for _, id in ipairs(listIds) do
            listSet[id] = true
            if id == HEARTH then
                for variant in pairs(HEARTH_SET) do listSet[variant] = true end
            end
        end
    end
    return listIds, listSet
end

--- The listed spell IDs, ascending, 8690 standing for every hearthstone. A copy.
function LateIgnore.List()
    local out = {}
    for i, id in ipairs((read())) do out[i] = id end
    return out
end

--- The ignored spells as a set, { [spellID] = true }, with 8690 expanded to every hearthstone. Read
--- only: it is the cached set, the same table until the stored text changes.
function LateIgnore.Set()
    local _, set = read()
    return set
end

--- Whether a late cast of `id` is ignored. A cast with no spell ID (sealed) never is.
--- @param id number|nil
--- @param set table|nil  LateIgnore.Set() (read now when nil)
function LateIgnore.IsIgnored(id, set)
    if type(id) ~= "number" then return false end
    return (set or LateIgnore.Set())[id] == true
end

--- The list's entry that ignores `id`: `id` itself, or 8690 for a variant listed only through it; nil
--- when `id` is not ignored.
function LateIgnore.Covering(id)
    if not LateIgnore.IsIgnored(id) then return nil end
    for _, listed in ipairs((read())) do
        if listed == id then return id end
    end
    return HEARTH
end

-- ── the writes ──────────────────────────────────────────────────────────────────────────────────

local function write(ids)
    return NS.SetByPath(LateIgnore.PATH, LateIgnore.Join(compact(ids)))
end

local function plainId(id)
    if NS.Secrets and NS.Secrets.PlainNumber then id = NS.Secrets.PlainNumber(id) end
    return type(id) == "number" and id >= 1 and id % 1 == 0 and id or nil
end

--- Ignore `id`'s late casts (8690: every hearthstone's).
--- @return boolean changed
function LateIgnore.Ignore(id)
    id = plainId(id)
    if not id or LateIgnore.IsIgnored(id) then return false end
    local ids = LateIgnore.List()
    ids[#ids + 1] = id
    return write(ids) and true or false
end

--- Count `id`'s late casts again. A variant ignored only through 8690 takes 8690 off the list: there is
--- no other way to count it, and it is never an undo that does nothing.
--- @return boolean changed
function LateIgnore.Unignore(id)
    local covering = LateIgnore.Covering(id)
    if not covering then return false end
    local ids = {}
    for _, listed in ipairs((read())) do
        if listed ~= covering then ids[#ids + 1] = listed end
    end
    return write(ids) and true or false
end

--- Back to the six defaults (one write of the default, as `/dr reset race.lateIgnore` does).
--- @return boolean written
function LateIgnore.Reset()
    return NS.SetByPath(LateIgnore.PATH, LateIgnore.DEFAULT) and true or false
end

-- ── what a typed spell is ───────────────────────────────────────────────────────────────────────

local function spellName(id)
    local api = C_Spell and C_Spell.GetSpellName
    if type(api) ~= "function" then return nil end
    local ok, name = pcall(api, id)
    return ok and type(name) == "string" and name or nil
end

local function spellIcon(id)
    local api = C_Spell and C_Spell.GetSpellTexture
    if type(api) ~= "function" then return nil end
    local ok, icon = pcall(api, id)
    return ok and icon or nil
end

--- One spell as a line names it: "Feign Death (5384)", "Hearthstone, all variants (8690)" for 8690,
--- "Unknown spell (424242)" when the client cannot name it. The slash verb's words (settings/Slash.lua).
function LateIgnore.Label(id)
    local name = spellName(id) or NS.L["Unknown spell"]
    if id == HEARTH then return NS.L["%s, all variants (%d)"]:format(name, id) end
    return NS.L["%s (%d)"]:format(name, id)
end

-- Whether a typed name is a hearthstone's: the word itself, or any variant's name in the client's
-- locale. Several variants share a name (8690, 191329 and 401802 are all "Hearthstone"), so the
-- name lookup below would answer "ambiguous".
local function hearthByName(want)
    if want == "hearthstone" then return true end
    for id in pairs(HEARTH_SET) do
        local name = spellName(id)
        if name and name:lower() == want then return true end
    end
    return false
end

--- Typed text to a spell ID: a number, a spell link, a hearthstone's name (8690), else the options
--- library's spell lookup over `candidates` (KnownSpells by default). The first three need no
--- library, so they resolve on a degraded load too. Answers `id, name, icon` or `nil, reason`
--- ("empty", "notFound", "ambiguous"): the ID list's own resolver shape.
--- @param text string|number
--- @param candidates function|nil
function LateIgnore.Resolve(text, candidates)
    if type(text) == "number" then text = tostring(text) end
    text = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
    if text == "" then return nil, "empty" end
    local id = tonumber(text:match("^%d+$") or text:match("spell:(%d+)") or "")
    if id then
        if id < 1 then return nil, "notFound" end
        return id, spellName(id), spellIcon(id)
    end
    if hearthByName(text:lower()) then return HEARTH, spellName(HEARTH), spellIcon(HEARTH) end
    local H = NS.Helpers
    if not (H and H.ResolveId) then return nil, "notFound" end
    local found, name, icon = H.ResolveId("spell", text, candidates or LateIgnore.KnownSpells)
    if found == nil then return nil, name or "notFound" end
    return found, name, icon
end

--- The spells a typed name can match beyond the ones the character knows (the client's name lookup
--- finds only those): every spell a stored run cast late, newest run first, each once, then the
--- defaults. The hearthstones are matched by name before this list is read.
--- @return table ids
function LateIgnore.KnownSpells()
    local runs = NS.db and NS.db.global and NS.db.global.runs
    local list = {}
    for _, run in pairs(type(runs) == "table" and runs or {}) do
        local flags = type(run) == "table" and run.flags
        if type(flags) == "table" and type(flags.lateCasts) == "table" then list[#list + 1] = run end
    end
    table.sort(list, function(a, b) return (tonumber(a.date) or 0) > (tonumber(b.date) or 0) end)
    local out, seen = {}, {}
    local function add(id)
        if type(id) == "number" and not seen[id] then seen[id], out[#out + 1] = true, id end
    end
    for _, run in ipairs(list) do
        for _, cast in ipairs(run.flags.lateCasts) do add(type(cast) == "table" and cast.spellID) end
    end
    for _, id in ipairs(LateIgnore.Parse(LateIgnore.DEFAULT) or {}) do add(id) end
    return out
end
