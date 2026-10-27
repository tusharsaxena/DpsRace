local _, NS = ...
-- modules/Stats.lua — the character's stats a run was raced with (#17): read at the arm (out of
-- combat, beside the loadout snapshot), stored on the run as run.stats (run-record format 4), and
-- grouped for the gear view (modules/Results_Gear.lua) with the deltas against the compared run.
--
-- WHAT IS READ. The spec's primary stat (its index from GetSpecializationInfo's sixth answer, its
-- value from UnitStat), stamina and armor; crit, haste, mastery and versatility, each as its rating
-- (GetCombatRating) and its percent (GetCritChance, GetHaste, GetMasteryEffect, and versatility's
-- GetCombatRatingBonus plus GetVersatilityBonus); leech, avoidance and speed, each as its rating and
-- its percent (GetLifesteal, GetAvoidance, GetSpeed). Every client function is read bare at CALL time
-- and pcall'd.
--
-- SECRETS. The arm is refused in combat, so every value is expected plain; each still passes through
-- NS.Secrets.PlainNumber, and a sealed one is absent from the record (never compared, never stored).
-- Nothing readable at all answers nil, and the run carries no stats.
--
-- THE RECORD is a small plain table: { v = 1, primaryStat, primary, stamina, armor, <key>Rating and
-- <key> (the percent) for crit, haste, mastery, vers, leech, avoidance and speed }. Ratings and the
-- three plain values are whole numbers, percents two decimals. A run from before format 4 has none
-- and the gear view shows dashes. Groups, Text and Delta are pure.

local Stats = {}
NS.Stats = Stats

local Secrets = NS.Secrets
local L = NS.L

Stats.VERSION = 1

-- The client's combat-rating indices (the CR_* globals, read at call time; these when absent).
Stats.CR = {
    crit = { "CR_CRIT_MELEE", 9 }, haste = { "CR_HASTE_MELEE", 18 }, mastery = { "CR_MASTERY", 26 },
    vers = { "CR_VERSATILITY_DAMAGE_DONE", 29 }, leech = { "CR_LIFESTEAL", 17 },
    avoidance = { "CR_AVOIDANCE", 21 }, speed = { "CR_SPEED", 14 },
}
local STAMINA = 3   -- LE_UNIT_STAT_STAMINA

-- The primary stats by UnitStat index.
Stats.PRIMARY = { [1] = "Strength", [2] = "Agility", [4] = "Intellect" }

-- The gear view's groups, in the character panel's order. `rated` rows show a rating and a percent.
Stats.GROUPS = {
    { key = "primary", title = "Primary", rows = { "primary", "stamina", "armor" } },
    { key = "secondary", title = "Secondary", rated = true, rows = { "crit", "haste", "mastery", "vers" } },
    { key = "tertiary", title = "Tertiary", rated = true, rows = { "leech", "avoidance", "speed" } },
}
Stats.LABELS = {
    stamina = "Stamina", armor = "Armor", crit = "Critical Strike", haste = "Haste", mastery = "Mastery",
    vers = "Versatility", leech = "Leech", avoidance = "Avoidance", speed = "Speed",
}

local DASH = "\226\128\148"
local SEP = " \194\183 "

local function passResults(ok, ...)
    if ok then return ... end
    return nil
end

local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    return passResults(pcall(fn, ...))
end

local function whole(v)
    v = Secrets.PlainNumber(v)
    return v and math.floor(v + 0.5) or nil
end

local function pct(v)
    v = Secrets.PlainNumber(v)
    return v and math.floor(v * 100 + 0.5) / 100 or nil
end

local function ratingIndex(key)
    local cr = Stats.CR[key]
    local v = _G[cr[1]]
    return type(v) == "number" and v or cr[2]
end

-- ── the capture ─────────────────────────────────────────────────────────────────────────────────

-- The spec's primary stat index (1, 2 or 4), or nil.
local function primaryIndex()
    local Compat = NS.Compat
    local specIndex = Secrets.PlainNumber(ask(Compat.GetSpecialization))
    if not specIndex then return nil end
    local idx = Secrets.PlainNumber(select(6, ask(Compat.GetSpecializationInfo, specIndex)))
    return Stats.PRIMARY[idx] and idx or nil
end

-- A UnitStat index's effective value (UnitStat's second answer).
local function unitStat(index)
    return whole(select(2, ask(UnitStat, "player", index)))
end

-- Each percent's reader.
local PERCENT = {
    crit = function() return ask(GetCritChance) end,
    haste = function() return ask(GetHaste) end,
    mastery = function() return ask(GetMasteryEffect) end,
    vers = function()
        local cr = ratingIndex("vers")
        local a = Secrets.PlainNumber(ask(GetCombatRatingBonus, cr))
        local b = Secrets.PlainNumber(ask(GetVersatilityBonus, cr))
        if not (a or b) then return nil end
        return (a or 0) + (b or 0)
    end,
    leech = function() return ask(GetLifesteal) end,
    avoidance = function() return ask(GetAvoidance) end,
    speed = function() return ask(GetSpeed) end,
}

--- The player's stats now (at the arm, out of combat), or nil with nothing readable.
--- @return table|nil stats  the record (see the header)
function Stats.Snapshot()
    local s = { primaryStat = primaryIndex() }
    s.primary = s.primaryStat and unitStat(s.primaryStat) or nil
    s.stamina = unitStat(STAMINA)
    s.armor = whole(select(2, ask(UnitArmor, "player")))
    for key, read in pairs(PERCENT) do
        s[key .. "Rating"] = whole(ask(GetCombatRating, ratingIndex(key)))
        s[key] = pct(read())
    end
    if next(s) == nil then return nil end
    s.v = Stats.VERSION
    return s
end

--- A run's stats record, or nil (a run from before format 4, or nothing was readable).
function Stats.Of(run)
    local s = type(run) == "table" and run.stats or nil
    return type(s) == "table" and s or nil
end

-- ── the display ─────────────────────────────────────────────────────────────────────────────────

--- A whole number with thousands separators ("12,345").
function Stats.Grouped(n)
    local s = tostring(math.floor(math.abs(n) + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (n < 0 and "-" or "") .. out
end

local function pctText(p, signed)
    return (signed and p >= 0 and "+" or "") .. ("%.2f%%"):format(p)
end

local function numText(n, signed)
    return (signed and n >= 0 and "+" or "") .. Stats.Grouped(n)
end

-- One row's value text: a rated row "1,234 · 25.30%", either half alone, else the plain value.
local function valueText(s, key, rated, signed)
    if not rated then return s[key] and numText(s[key], signed) or nil end
    local r, p = s[key .. "Rating"], s[key]
    if r and p then return numText(r, signed) .. SEP .. pctText(p, signed) end
    if p then return pctText(p, signed) end
    return r and numText(r, signed) or nil
end

--- A row's label: the primary stat's name for `primary`.
function Stats.Label(key, s)
    if key == "primary" then
        local name = s and Stats.PRIMARY[s.primaryStat]
        return L[name or "Primary stat"]
    end
    return L[Stats.LABELS[key] or key]
end

--- A row's value text, or a dash without one.
function Stats.Text(s, key, rated)
    return type(s) == "table" and valueText(s, key, rated) or DASH
end

-- The difference of field `f` between two records, or nil when either lacks it.
local function diff(s, o, f)
    if type(s[f]) ~= "number" or type(o[f]) ~= "number" then return nil end
    return math.floor((s[f] - o[f]) * 100 + 0.5) / 100
end

--- A row's delta against `o` (the compared run's stats): its text and its sign (1 better, -1 worse,
--- 0 the same; the percent decides a rated row), or nil when either side lacks the value or the two
--- runs' primary stats differ.
--- @return string|nil text, number|nil sign
function Stats.Delta(s, o, key, rated)
    if type(s) ~= "table" or type(o) ~= "table" then return nil end
    if key == "primary" and s.primaryStat ~= o.primaryStat then return nil end
    local d = { [key] = diff(s, o, key) }
    if rated then d[key .. "Rating"] = diff(s, o, key .. "Rating") end
    local text = valueText(d, key, rated, true)
    if not text then return nil end
    local by = d[key] or d[key .. "Rating"]
    return text, by > 0 and 1 or (by < 0 and -1 or 0)
end

--- The gear view's stats column: each group's title and rows ({ key, label, text, delta, sign }).
--- @param s table|nil  this run's stats
--- @param o table|nil  the compared run's
--- @return table groups
function Stats.Groups(s, o)
    local out = {}
    for _, g in ipairs(Stats.GROUPS) do
        local rows = {}
        for _, key in ipairs(g.rows) do
            local delta, sign = Stats.Delta(s, o, key, g.rated)
            rows[#rows + 1] = { key = key, label = Stats.Label(key, s), text = Stats.Text(s, key, g.rated),
                                delta = delta, sign = sign }
        end
        out[#out + 1] = { key = g.key, title = L[g.title], rows = rows }
    end
    return out
end
