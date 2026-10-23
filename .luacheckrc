std = "lua51"
max_line_length = false
codes = true

-- libs/ and tests/_kit/ are byte copies of code linted in its own repo (LibKa0s); linting the copy
-- would report every finding twice and let the copy drift green. probe/ is the pre-build measurement
-- addon the spec's numbers came from: never shipped (.pkgmeta), never loaded by this addon, kept as
-- a record. The frozen docs/ bundles must never be "fixed" by a lint pass.
exclude_files = { "libs/", "tests/_kit/", "probe/", "docs/audits/", "docs/reviews/", "docs/revendor/", "_dev/" }

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

-- The published slash surface (`Sl:OnSlash`, `PrintHelp`, `LandingRows`, `DisabledLine`, `Register`)
-- is colon-called by the host and the suites and forwards to the dispatcher upvalue.
files["settings/Slash.lua"] = { ignore = { "212/self" } }

-- `NS:InitDB` / `NS:RunMigrations` are colon-called from OnInitialize and read NS.db, not the receiver.
files["core/Database.lua"] = { ignore = { "212/self" } }

-- AceEvent invokes a handler registered by method name as `self[name](self, event, ...)`.
files["core/DpsRace.lua"] = { ignore = { "212/self" } }

-- The MenuUtil fake mirrors the client's colon-called menu API (`root:CreateCheckbox`, ...).
files["tests/wow_mock.lua"] = { ignore = { "212/self", "432/self" } }
