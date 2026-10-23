local _, NS = ...
-- defaults/Dummies.lua — the training-dummy catalog (spec §4.6): creature ID -> name, category and
-- default target count, plus the six categories personal bests are grouped by.

-- A row is added from a MEASUREMENT (a probe run or `/dpsrace target`), never guessed. The count is
-- metadata only and never scored; 243208's group size is open item O7, so it ships as 1 and the
-- player adjusts it before arming.
local L = NS.L

local Dummies = {}
NS.Dummies = Dummies

-- The order is the display order (filters, the bests board). "other" is any target not cataloged.
Dummies.CATEGORIES = { "single", "cleave", "dungeoneer", "boss", "pvp", "other" }

Dummies.LABELS = {
    single     = L["Single target"],
    cleave     = L["Cleave"],
    dungeoneer = L["Dungeoneer"],
    boss       = L["Boss-level"],
    pvp        = L["PvP"],
    other      = L["Other"],
}

-- Keyed by creature ID (the sixth field of a Creature GUID, as a number).
Dummies.BY_ID = {
    [243167] = { name = "Dungeoneer's Training Dummy", category = "dungeoneer", count = 1 },  -- 2026-10-23, Silvermoon
    [243168] = { name = "Dungeoneer's Training Dummy", category = "dungeoneer", count = 1 },  -- 2026-10-23, Silvermoon
    [243208] = { name = "Cleave Training Dummy",       category = "cleave",     count = 1 },  -- 2026-10-23; count is O7
    [243205] = { name = "Reinforced Golem",            category = "boss",       count = 1 },  -- 2026-10-23, Silvermoon
    [243211] = { name = "PvP Training Dummy",          category = "pvp",        count = 1 },  -- MultiMeters, 2026-09-26
}

--- The catalog entry for a creature ID, as a fresh copy (a caller may edit it freely).
--- @param npcID number|nil  a plain number; nil or a secret answers nil
--- @return table|nil  { name, category, count }
function Dummies.Lookup(npcID)
    -- A secret as a table key raises in the client: refuse anything that may not be one.
    if not NS.Secrets.IsSafeKey(npcID) then return nil end
    local d = Dummies.BY_ID[npcID]
    if not d then return nil end
    return { name = d.name, category = d.category, count = d.count }
end

--- The display label of a category key; an unknown key labels as Other.
--- @param category string|nil
--- @return string
function Dummies.Label(category)
    return Dummies.LABELS[category] or Dummies.LABELS.other
end
