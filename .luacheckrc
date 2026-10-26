std = "lua51"
max_line_length = false
codes = true

-- libs/ and tests/_kit/ are byte copies of code linted in its own repo (LibKa0s); linting the copy
-- would report every finding twice and let the copy drift green (lint). The frozen docs/ bundles must
-- never be "fixed" by a lint pass.
exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/", "docs/revendor/", "_dev/" }

-- No top-level `ignore`: a blanket reaches every file, including the ones with no business producing
-- the code it silences (lint). A receiver a calling convention forces gets a per-file stanza below.

read_globals = {
    "_G", "LibStub", "CreateFrame", "GetTime", "UIParent", "STANDARD_TEXT_FONT",
    "DEFAULT_CHAT_FRAME", "UISpecialFrames",
    -- the perf bracket's clock (performance-§2)
    "debugprofilestop",
    "C_Timer", "C_AddOns", "Enum", "GetLocale",
    -- combat state: InCombatLockdown() gates secure writes; UnitAffectingCombat() drives display
    "InCombatLockdown", "UnitAffectingCombat",
    "UnitGUID", "UnitName", "UnitClass",
    -- settings panel plumbing
    "Settings", "SettingsPanel", "StaticPopup_Show",
}

globals = {
    "DpsRaceDB",            -- the SavedVariables write target (the AceDB tree)
    "DpsRacePerfDB",        -- the LibKa0s-Perf capture ring, outside the AceDB tree (performance-§5)
    "StaticPopupDialogs",   -- the addon registers its named popups into this table
    "BINDING_HEADER_DPSRACE",
}

-- The test tree is linted; these are the globals it WRITES. Scoped here so no shipped file can reach
-- for the harness.
files["tests/"] = {
    globals = { "_G.DPSRACE_TEST", "_G.DpsRaceDB", "_G.DpsRacePerfDB" },
}

-- spec §8 rule 1, made a lint fact: the client's secret detectors are readable from the compat family
-- only (core/Compat.lua, whose guards core/Secrets.lua alone calls), and C_DamageMeter from
-- modules/Meter.lua only. Anywhere else, naming one is a warning.
files["modules/Meter.lua"] = { read_globals = { "C_DamageMeter" } }

-- The run record's metadata snapshots (spec §7): who, against what and where. Scoped to the one file
-- that takes them, so nothing else grows a habit of reading unit metadata the record already holds.
files["modules/Recorder.lua"] = {
    read_globals = {
        "time", "UnitExists", "UnitLevel", "UnitRace", "UnitClassification", "GetRealmName",
        "GetAverageItemLevel", "C_Map",
        -- the loadout (#6): the equipped links and the talent loadout
        "GetInventoryItemLink", "C_ClassTalents", "C_Traits",
        "GetZoneText", "GetSubZoneText", "GetInstanceInfo", "GetBuildInfo",
    },
}

-- The race restamps a run's date at the start and falls back to the epoch on resume (spec §7).
files["modules/Race.lua"] = { read_globals = { "time", "C_Spell" } }
-- The cast list (#14): each spell's base cooldown, the first time it is cast.
files["modules/Casts.lua"] = { read_globals = { "GetSpellBaseCooldown" } }
-- What was used (#13): the on-use slots, the bags, the item data, the helpful auras and the weapon
-- enchants, read at the arm (out of combat) and the bag counts again at the result.
files["modules/Usage.lua"] = {
    read_globals = { "GetInventoryItemID", "C_Item", "C_Container", "C_UnitAuras", "GetWeaponEnchantInfo" },
}

-- The compat family (compat): the version-variant client calls, and the only file that may name them.
files["core/Compat.lua"] = {
    read_globals = {
        "C_ChatInfo", "SendChatMessage", "C_StringUtil",
        "C_SpecializationInfo", "GetSpecialization", "GetSpecializationInfo",
        "issecretvalue", "canaccessvalue", "issecrettable", "canaccesstable",
    },
}

-- The Race HUD. The formatter is the client's (C_StringUtil, through NS.Compat) with
-- AbbreviateNumbers beneath it; spell names and icons come through C_Spell; the shell plays the cue and
-- the buzzer's raid warning, names the drop-combat spells the player knows and draws tooltips.
files["modules/Format.lua"] = { read_globals = { "AbbreviateNumbers" } }
files["modules/Hud_Breakdown.lua"] = { read_globals = { "C_Spell", "GameTooltip" } }
-- A stored run's character's class color (the Results table's bars), and the fallback faces.
files["modules/Hud_Appearance.lua"] = { read_globals = { "RAID_CLASS_COLORS" } }
files["modules/Hud_States.lua"] = { read_globals = { "GameTooltip" } }
-- The shared look: a title-bar control draws its tooltip.
files["modules/Style.lua"] = { read_globals = { "GameTooltip" } }
-- The final seconds' cue sound (the center numbers draw on their own frame, no client global).
files["modules/Countdown.lua"] = { read_globals = { "PlaySound", "SOUNDKIT" } }
files["modules/Hud.lua"] = {
    read_globals = {
        "IsPlayerSpell", "PlaySound", "SOUNDKIT", "RaidNotice_AddMessage", "RaidWarningFrame",
        "ChatTypeInfo",
    },
}

-- The Results window: the run dates, the class icons, colors and names, the spec names and icons,
-- tooltips. The filter's date range reads the clock (time, date) in modules/Results_Runs.lua.
local resultsGlobals = {
    "time", "date", "GameTooltip", "RAID_CLASS_COLORS", "LOCALIZED_CLASS_NAMES_MALE", "CLASS_ICON_TCOORDS",
    "GetSpecializationInfoByID", "GetCursorPosition", "UIParent", "MenuUtil",
}
-- The window's shell also reads whether Blizzard's talent frame is up (IsShown only): the tree's
-- panel open closes the window through UISpecialFrames, and the window comes back under it.
files["modules/Results.lua"] = { read_globals = { "PlayerSpellsFrame", (table.unpack or unpack)(resultsGlobals) } }
files["modules/Results_Table.lua"] = { read_globals = resultsGlobals }
files["modules/Results_Runs.lua"] = { read_globals = resultsGlobals }
files["modules/Results_Detail.lua"] = { read_globals = resultsGlobals }
files["modules/Results_Bests.lua"] = { read_globals = resultsGlobals }
files["modules/Results_Tips.lua"] = { read_globals = resultsGlobals }
-- The detail's loadout (#6): the item data, the item tooltip and its modified click, the Dressing
-- Room, the client's loadout serialization version, and View's SetItemRef (it opens the tree).
files["modules/Results_Loadout.lua"] = {
    read_globals = {
        "GameTooltip", "C_Item", "C_Traits", "DressUpItemLink", "HandleModifiedItemClick",
        "IsShiftKeyDown", "ChatEdit_InsertLink", "SetItemRef",
    },
}

-- What a run used (#13): the item names and icons, and the client's item tooltip.
files["modules/Results_Usage.lua"] = { read_globals = { "GameTooltip", "C_Item" } }

-- The sample history (B5) dates its runs back from now.
files["modules/MockRuns.lua"] = { read_globals = { "time" } }

-- Share: which channels the player is in, the chat lockdown (C_ChatInfo; the send itself is
-- NS.Compat's), the whisper popup's player-target name, and the channel menu.
files["modules/Share.lua"] = {
    read_globals = { "IsInGroup", "IsInRaid", "IsInGuild", "C_ChatInfo", "UnitIsPlayer", "MenuUtil" },
}

-- The published slash surface (`Sl:OnSlash`, `PrintHelp`, `LandingRows`, `DisabledLine`, `Register`)
-- is colon-called by the host and the suites and forwards to the dispatcher upvalue; `/dr target`
-- asks whether there is a target before it snapshots one.
files["settings/Slash.lua"] = { ignore = { "212/self" }, read_globals = { "UnitExists" } }

-- `NS:InitDB` / `NS:RunMigrations` are colon-called from OnInitialize and read NS.db, not the receiver.
files["core/Database.lua"] = { ignore = { "212/self" } }

-- AceEvent invokes a handler registered by method name as `self[name](self, event, ...)`.
files["core/DpsRace.lua"] = { ignore = { "212/self" } }

-- The MenuUtil fake mirrors the client's colon-called menu API (`root:CreateCheckbox`, ...).
files["tests/wow_mock.lua"] = { ignore = { "212/self", "432/self" } }
