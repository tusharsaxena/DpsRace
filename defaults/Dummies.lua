local _, NS = ...
-- defaults/Dummies.lua — the training-dummy catalog (spec §4.6): creature ID -> name and category,
-- plus the six categories personal bests are grouped by. The profile's own list (#9,
-- modules/DummyList.lua) adds to it and switches entries off; Lookup answers the two together.

-- A row is added from a MEASUREMENT (a `/dr targetdummy add` capture read out of SavedVariables, or
-- `/dr target`), never guessed. There is no
-- target count: a typed one added nothing (the owner's call, 2026-10-26), and none can be measured
-- (DpsRace#15).
local L = NS.L

local Dummies = {}
NS.Dummies = Dummies

-- The order is the display order (the Results window's filters). "other" is any target not cataloged.
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
    [243167] = { name = "Dungeoneer's Training Dummy", category = "dungeoneer" },  -- 2026-10-23, Silvermoon
    [243168] = { name = "Dungeoneer's Training Dummy", category = "dungeoneer" },  -- 2026-10-23, Silvermoon
    [243208] = { name = "Cleave Training Dummy",       category = "cleave" },      -- 2026-10-23, Silvermoon
    [243205] = { name = "Reinforced Golem",            category = "boss" },  -- 2026-10-23, Silvermoon
    [243211] = { name = "PvP Training Dummy",          category = "pvp" },  -- MultiMeters, 2026-09-26
}

--- The shipped catalog's entry for a creature ID, as a fresh copy, whatever the profile's list says.
--- @param npcID number|nil  a plain number; nil or a secret answers nil
--- @return table|nil  { name, category }
function Dummies.BuiltIn(npcID)
    -- A secret as a table key raises in the client: refuse anything that may not be one.
    if not NS.Secrets.IsSafeKey(npcID) then return nil end
    local d = Dummies.BY_ID[npcID]
    if not d then return nil end
    return { name = d.name, category = d.category }
end

--- The dummy a creature ID is now, as a fresh copy (a caller may edit it freely): the catalog, as the
--- profile's own list (modules/DummyList.lua, #9, read at CALL time) adds to it and switches it off. A
--- custom entry's name is its capture's, nil when it was never captured.
--- @param npcID number|nil  a plain number; nil or a secret answers nil
--- @return table|nil  { name, category }
function Dummies.Lookup(npcID)
    if not NS.Secrets.IsSafeKey(npcID) then return nil end
    local own = NS.DummyList and NS.DummyList.Entry(npcID)
    if own then
        if own.hidden then return nil end
        return { name = NS.DummyList.NameOf(npcID), category = own.category }
    end
    return Dummies.BuiltIn(npcID)
end

--- A stored target's category, read now (#9: read time): with a creature ID, what the dummy list makes
--- of it ("other" when it is no dummy now); with none (a GUID that arrived secret), the category the
--- run recorded.
--- @param target table|nil  a run's target
--- @return string category
function Dummies.CategoryOf(target)
    if type(target) ~= "table" then return "other" end
    if type(target.npcID) == "number" then
        local d = Dummies.Lookup(target.npcID)
        return d and d.category or "other"
    end
    return target.category or "other"
end

--- The display label of a category key; an unknown key labels as Other.
--- @param category string|nil
--- @return string
function Dummies.Label(category)
    return Dummies.LABELS[category] or Dummies.LABELS.other
end
