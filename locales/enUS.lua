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
L["Session matched by list"] = "Session matched by list"
L["Died during the run"] = "Died during the run"
L["Incomplete: combat ended before the buzzer"] = "Incomplete: combat ended before the buzzer"
L["Lost: the session could not be read"] = "Lost: the session could not be read"

-- Numbers and the Arm refusals (modules/Format.lua)
L["+%.1f"] = "+%.1f"
L["Leave combat to arm"] = "Leave combat to arm"
L["A run is still waiting for its result: let it finish, or discard it."] =
    "A run is still waiting for its result: let it finish, or discard it."
L["A race is already armed or running."] = "A race is already armed or running."
L["A race lasts from 0:10 to 15:00."] = "A race lasts from 0:10 to 15:00."
L["Blizzard's damage meter is unavailable: %s"] = "Blizzard's damage meter is unavailable: %s"
L["Ka0s DPS Race is turned off."] = "Ka0s DPS Race is turned off."
L["The race could not be armed."] = "The race could not be armed."

-- The Race HUD (modules/Hud.lua, Hud_States.lua, Hud_Breakdown.lua): labels, figures, chips, hints. The
-- four drop-combat names are the hint's fallback when C_Spell cannot name the spell.
L["Unknown spell"] = "Unknown spell"
L["No target"] = "No target"
L["Targets"] = "Targets"
L["1 target"] = "1 target"
L["%d targets"] = "%d targets"
L["RACE LENGTH"] = "RACE LENGTH"
L["Custom"] = "Custom"
L["TARGET"] = "TARGET"
L["ARM RACE"] = "ARM RACE"
L["LAST RESULT"] = "LAST RESULT"
L["RESULTS"] = "RESULTS"
L["First hit starts the clock"] = "First hit starts the clock"
L["Pre-cast and pre-pot as you would on a pull. The clock starts when damage lands, not when you press the button."] =
    "Pre-cast and pre-pot as you would on a pull. The clock starts when damage lands, not when you press the button."
L["CANCEL"] = "CANCEL"
L["DAMAGE"] = "DAMAGE"
L["DPS \194\183 LIVE"] = "DPS \194\183 LIVE"
L["Live order \194\183 % after the race"] = "Live order \194\183 % after the race"
L["%d rows"] = "%d rows"
L["COMBAT ENDED AT"] = "COMBAT ENDED AT"
L["DAMAGE STOPPED"] = "DAMAGE STOPPED"
L["IN COMBAT"] = "IN COMBAT"
L["s"] = "s"
L["OUT OF COMBAT"] = "OUT OF COMBAT"
L["STOP"] = "STOP"
L["s after buzzer"] = "s after buzzer"
L["1 late cast \194\183 +%.1fs"] = "1 late cast \194\183 +%.1fs"
L["%d late casts \194\183 +%.1fs"] = "%d late casts \194\183 +%.1fs"
L["Grace %.1fs"] = "Grace %.1fs"
L["Damage still landing (DoTs, travel time) counts. Casts that start more than %.1fs after the buzzer are flagged on the result."] =
    "Damage still landing (DoTs, travel time) counts. Casts that start more than %.1fs after the buzzer are flagged on the result."
L["DISCARD RUN"] = "DISCARD RUN"
L["CLOSE (KEEP WAITING)"] = "CLOSE (KEEP WAITING)"
L["Waiting for combat to end"] = "Waiting for combat to end"
L["Reading the result"] = "Reading the result"
L["1 late cast"] = "1 late cast"
L["%d late casts"] = "%d late casts"
L["Restarted +%.1fs"] = "Restarted +%.1fs"
L["Reloaded"] = "Reloaded"
L["Session by list"] = "Session by list"
L["Incomplete: died"] = "Incomplete: died"
L["Incomplete (combat ended at %s)"] = "Incomplete (combat ended at %s)"
L["Lost"] = "Lost"
L["Died"] = "Died"
L["New best +%.1f%%"] = "New best +%.1f%%"
L["New best"] = "New best"
L["%+.1f%% vs best"] = "%+.1f%% vs best"
L["Tail +%.1fs"] = "Tail +%.1fs"
L["DPS"] = "DPS"
L["RACE AGAIN"] = "RACE AGAIN"
L["DETAILS"] = "DETAILS"
L["SHARE"] = "SHARE"
L["Couldn't read the result"] = "Couldn't read the result"
L["Combat is holding. Walk out of range. Your score is safe: it waits for combat to end, however long that takes."] =
    "Combat is holding. Walk out of range. Your score is safe: it waits for combat to end, however long that takes."
L["Combat is holding. Walk out of range, or use %s. Your score is safe: it waits for combat to end, however long that takes."] =
    "Combat is holding. Walk out of range, or use %s. Your score is safe: it waits for combat to end, however long that takes."
L[" or "] = " or "
L["Unknown target: recorded as Other: %s"] = "Unknown target: recorded as Other: %s"
L["No target: the one you fight is read when combat starts."] =
    "No target: the one you fight is read when combat starts."
L["DPS Race"] = "DPS Race"
L["Lock or unlock the HUD"] = "Lock or unlock the HUD"
L["Settings"] = "Settings"
L["Results"] = "Results"
L["ilvl %d"] = "ilvl %d"
L["live \194\183 %d Hz"] = "live \194\183 %d Hz"
L["result pending"] = "result pending"
L["Feign Death"] = "Feign Death"
L["Vanish"] = "Vanish"
L["Shadowmeld"] = "Shadowmeld"
L["Invisibility"] = "Invisibility"
