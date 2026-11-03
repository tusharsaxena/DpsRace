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
    [31146] = { name = "Raider's Training Dummy",        category = "boss"        },  -- 2026-11-01, City of Ironforge, Orgrimmar, Shrine of Seven Stars, Stormwind City, The Exodar, Thunder Bluff
    [65310] = { name = "Turnip Punching Bag",            category = "boss"        },  -- 2026-11-01, Silvermoon City
    [67127] = { name = "Training Dummy",                 category = "single"      },  -- 2026-11-01, Shrine of Seven Stars
    [114832] = { name = "PvP Training Dummy",             category = "pvp"         },  -- 2026-11-01, Stormwind City
    [126781] = { name = "Training Dummy",                 category = "single"      },  -- 2026-11-01, Tiragarde Sound
    [131983] = { name = "Raider's Training Dummy",        category = "boss"        },  -- 2026-11-01, Tiragarde Sound
    [131989] = { name = "Training Dummy",                 category = "single"      },  -- 2026-11-01, Tiragarde Sound
    [131992] = { name = "Dungeoneer's Training Dummy",    category = "dungeoneer"  },  -- 2026-11-01, Tiragarde Sound
    [144078] = { name = "Dungeoneer's Training Dummy",    category = "dungeoneer"  },  -- 2026-11-01, Zuldazar
    [144081] = { name = "Training Dummy",                 category = "single"      },  -- 2026-11-01, Zuldazar
    [144082] = { name = "Training Dummy",                 category = "single"      },  -- 2026-11-01, Zuldazar
    [144085] = { name = "Training Dummy",                 category = "single"      },  -- 2026-11-01, Zuldazar
    [144086] = { name = "Raider's Training Dummy",        category = "boss"        },  -- 2026-11-01, Zuldazar
    [153285] = { name = "Training Dummy",                 category = "single"      },  -- 2026-11-01, City of Ironforge, Orgrimmar, The Exodar, Thunder Bluff
    [153292] = { name = "Training Dummy",                 category = "single"      },  -- 2026-11-01, Stormwind City
    [189617] = { name = "Boulderfist",                    category = "boss"        },  -- 2026-11-01, Valdrakken
    [189632] = { name = "Animated Duelist",               category = "boss"        },  -- 2026-11-01, Valdrakken
    [194643] = { name = "Dungeoneer's Training Dummy",    category = "dungeoneer"  },  -- 2026-11-01, Valdrakken
    [194644] = { name = "Dungeoneer's Training Dummy",    category = "dungeoneer"  },  -- 2026-11-01, Valdrakken
    [194648] = { name = "Training Dummy",                 category = "single"      },  -- 2026-11-01, Valdrakken
    [194649] = { name = "Normal Tank Dummy",              category = "single"      },  -- 2026-11-01, Valdrakken
    [196394] = { name = "Tuskarr Training Dummy",         category = "boss"        },  -- 2026-11-01, Silvermoon City
    [197833] = { name = "PvP Training Dummy",             category = "pvp"         },  -- 2026-11-01, Valdrakken
    [198594] = { name = "Cleave Training Dummy",          category = "cleave"      },  -- 2026-11-01, Valdrakken
    [199057] = { name = "Black Dragon's Challenge Dummy", category = "boss"        },  -- 2026-11-01, Silvermoon City
    [216458] = { name = "Sparring Dummy",                 category = "single"      },  -- 2026-11-01, Bel'ameth
    [219250] = { name = "PvP Training Dummy",             category = "pvp"         },  -- 2026-11-01, Dornogal
    [225976] = { name = "Normal Tank Dummy",              category = "single"      },  -- 2026-11-01, Dornogal
    [225977] = { name = "Dungeoneer's Training Dummy",    category = "dungeoneer"  },  -- 2026-11-01, Dornogal
    [225978] = { name = "Crystalmaw",                     category = "boss"        },  -- 2026-11-01, Dornogal
    [225982] = { name = "Cleave Training Dummy",          category = "cleave"      },  -- 2026-11-01, Dornogal
    [225983] = { name = "Dungeoneer's Training Dummy",    category = "dungeoneer"  },  -- 2026-11-01, Dornogal
    [225984] = { name = "Training Dummy",                 category = "single"      },  -- 2026-11-01, Dornogal
    [225985] = { name = "Kelpfist",                       category = "boss"        },  -- 2026-11-01, Dornogal
    [243166] = { name = "Normal Tank Dummy",              category = "single"      },  -- 2026-11-01, Silvermoon City
    [243167] = { name = "Dungeoneer's Training Dummy",    category = "dungeoneer"  },  -- 2026-10-23, Silvermoon
    [243168] = { name = "Dungeoneer's Training Dummy",    category = "dungeoneer"  },  -- 2026-10-23, Silvermoon
    [243205] = { name = "Reinforced Golem",               category = "boss"        },  -- 2026-10-23, Silvermoon
    [243206] = { name = "Heavyweight Golem",              category = "boss"        },  -- 2026-11-01, Silvermoon City
    [243207] = { name = "Training Dummy",                 category = "single"      },  -- 2026-11-01, Silvermoon City
    [243208] = { name = "Cleave Training Dummy",          category = "cleave"      },  -- 2026-10-23, Silvermoon
    [243211] = { name = "PvP Training Dummy",             category = "pvp"         },  -- MultiMeters, 2026-09-26
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
