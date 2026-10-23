local _, NS = ...
-- locales/enUS.lua — the canonical locale: NS.L with the key-is-the-string fallback (localization).

-- Keys ARE the English source string. A missing key answers itself, so a string can ship before this
-- file lists it; listing it here is still owed, because it is what a translator copies.
--
-- Never pass this table as a LibKa0s descriptor's `L`: the fallback answers EVERY key, which shadows
-- the library's own strings (the "L trap" the library documents).
local L = setmetatable({}, { __index = function(_, k) return k end })
NS.L = L

-- Identity and chrome
L["Ka0s DPS Race"] = "Ka0s DPS Race"
L["General"] = "General"
L["Profiles"] = "Profiles"
L["Slash Commands"] = "Slash Commands"

-- Key bindings (launcher-§6)
L["Toggle race HUD"] = "Toggle race HUD"
L["Toggle results window"] = "Toggle results window"

-- Shared refusals (slash-commands-§1, slash-commands-§7)
L["%s is unavailable: the LibKa0s library did not load."] = "%s is unavailable: the LibKa0s library did not load."
L["Not available during a performance capture."] = "Not available during a performance capture."

-- Master controls tab (settings/General.lua)
L["Reset this profile to the addon defaults? Every setting goes back to its shipped value. Your run history and your other profiles are not affected."] =
    "Reset this profile to the addon defaults? Every setting goes back to its shipped value. Your run history and your other profiles are not affected."
L["Yes"] = "Yes"
L["No"] = "No"
L["All settings reset to defaults."] = "All settings reset to defaults."
L["Restore every General setting on this profile to its addon default."] =
    "Restore every General setting on this profile to its addon default."

-- Slash verbs (settings/Slash.lua): the descriptions the help index and the landing page print
L["Show this help"] = "Show this help"
L["Open the settings panel"] = "Open the settings panel"
L["Turn the addon on"] = "Turn the addon on"
L["Turn the addon off without unloading it"] = "Turn the addon off without unloading it"
L["List every setting"] = "List every setting"
L["Read one setting: /dr get path"] = "Read one setting: /dr get path"
L["Write one setting: /dr set path value"] = "Write one setting: /dr set path value"
L["Reset one setting: /dr reset path"] = "Reset one setting: /dr reset path"
L["Reset every setting (asks first)"] = "Reset every setting (asks first)"
L["Debug console; on/off set logging, diagnostics writes the report"] =
    "Debug console; on/off set logging, diagnostics writes the report"
L["Write the diagnostics report to the debug console"] = "Write the diagnostics report to the debug console"
L["Performance capture; try /dr perf help"] = "Performance capture; try /dr perf help"
L["Print the addon version"] = "Print the addon version"
L["List profiles, or switch to one: profile name"] = "List profiles, or switch to one: profile name"
L["%s version %s"] = "%s version %s"
L["%s commands (reduced: the LibKa0s library is missing)"] = "%s commands (reduced: the LibKa0s library is missing)"
L["enabled = %s"] = "enabled = %s"

-- Placeholders (modules/Placeholders.lua): what the scaffold says until the real windows land
L["Test mode ended: you entered combat."] = "Test mode ended: you entered combat."

-- The meter adapter (modules/Meter.lua)
L["Blizzard's damage meter is not available on this client."] = "Blizzard's damage meter is not available on this client."

-- Dummy categories (defaults/Dummies.lua, spec §4.6)
L["Single target"] = "Single target"
L["Cleave"] = "Cleave"
L["Dungeoneer"] = "Dungeoneer"
L["Boss-level"] = "Boss-level"
L["PvP"] = "PvP"
L["Other"] = "Other"

-- Run flags (modules/Scoring.lua, spec §5.4)
L["+%.1fs"] = "+%.1fs"
L["+%.1fs %s"] = "+%.1fs %s"
L["1 late cast (%s)"] = "1 late cast (%s)"
L["%d late casts (%s)"] = "%d late casts (%s)"
L["Damage restarted at +%.1fs"] = "Damage restarted at +%.1fs"
L["Reloaded mid-run: casts after the buzzer not tracked"] = "Reloaded mid-run: casts after the buzzer not tracked"
L["Died during the run"] = "Died during the run"
L["Incomplete: combat ended before the buzzer"] = "Incomplete: combat ended before the buzzer"
L["Lost: the session could not be read"] = "Lost: the session could not be read"
