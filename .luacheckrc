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

-- The stats a run was raced with (#17), read at the arm: the primary stat, stamina and armor, and
-- each rating with its percent.
files["modules/Stats.lua"] = {
    read_globals = {
        "UnitStat", "UnitArmor", "GetCombatRating", "GetCombatRatingBonus", "GetVersatilityBonus",
        "GetCritChance", "GetRangedCritChance", "GetSpellCritChance", "GetHaste", "GetMasteryEffect", "GetLifesteal", "GetAvoidance", "GetSpeed",
    },
}

-- The race restamps a run's date at the start and falls back to the epoch on resume (spec §7).
files["modules/Race.lua"] = { read_globals = { "time", "C_Spell" } }
-- The late-cast ignore list (#8): a typed spell's name and icon, the hearthstones' names, and the
-- late-cast right-click menu.
files["modules/LateIgnore.lua"] = { read_globals = { "C_Spell", "MenuUtil" } }
-- The cast list (#14): each spell's base cooldown, the first time it is cast.
files["modules/Casts.lua"] = { read_globals = { "GetSpellBaseCooldown" } }
-- What was used (#13): the on-use slots, the bags, the item data and the helpful auras, read at the
-- arm (out of combat) and the bag counts again at the result.
files["modules/Usage.lua"] = {
    read_globals = { "GetInventoryItemID", "C_Item", "C_Container", "C_UnitAuras" },
}

-- Auto-show and auto-arm (#16): the nameplates up (read again at the hide's fire) and whether the
-- player is in an instance (neither rule acts there).
files["modules/AutoArm.lua"] = { read_globals = { "C_NamePlate", "GetInstanceInfo" } }

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
files["modules/Results_Insights.lua"] = { read_globals = resultsGlobals }
-- The Insights stats pass buckets runs by local day.
files["modules/Results_InsightsData.lua"] = { read_globals = { "time", "date" } }
-- The Insights charts' DpsRace host draws its hover on the client's tooltip.
files["modules/Results_InsightsCharts.lua"] = { read_globals = { "GameTooltip" } }
files["modules/Results_Tips.lua"] = { read_globals = resultsGlobals }
-- The compare's separator: one physical pixel at any UI scale (PixelUtil's pixel-to-UI-unit factor).
files["modules/Results_Compare.lua"] = { read_globals = { "PixelUtil" } }
-- The detail's loadout (#6): the item data, the item tooltip and its modified click, the client's
-- loadout serialization version, and View's SetItemRef (it opens the tree).
files["modules/Results_Loadout.lua"] = {
    read_globals = {
        "GameTooltip", "C_Item", "C_Traits", "HandleModifiedItemClick",
        "IsShiftKeyDown", "ChatEdit_InsertLink", "SetItemRef",
    },
}
-- The gear view (#17): the item data and icons, the item tooltip and its modified click.
files["modules/Results_Gear.lua"] = {
    read_globals = { "GameTooltip", "C_Item", "HandleModifiedItemClick", "IsShiftKeyDown", "ChatEdit_InsertLink" },
}

-- What a run used (#13): the item names and icons, the client's item tooltip, and an item row's
-- right-click menu in the edit (Never show, P9).
files["modules/Results_Usage.lua"] = { read_globals = { "GameTooltip", "C_Item", "MenuUtil" } }

-- The ability timeline (#14): Shift+mouse wheel pans its zoomed time axis (P12); Ctrl+mouse wheel zooms
-- about the cursor and the `?` control draws its own tooltip (P16).
files["modules/Results_Timeline.lua"] = {
    read_globals = { "IsShiftKeyDown", "IsControlKeyDown", "GetCursorPosition", "GameTooltip" },
}

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
