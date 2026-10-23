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
L["%s = %s"] = "%s = %s"

-- Test mode (modules/Preview.lua, core/DpsRace.lua)
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

-- The Results window (modules/Results*.lua, T8)
L["DPS Race \226\128\148 Results"] = "DPS Race \226\128\148 Results"
L["RUNS"] = "RUNS"
L["BESTS"] = "BESTS"
L["Click a row for details \194\183 double-click to share"] =
    "Click a row for details \194\183 double-click to share"
L["Runs to keep: %d"] = "Runs to keep: %d"
L["Runs to keep: 0 (never prune)"] = "Runs to keep: 0 (never prune)"
L["Delete this run? This cannot be undone, and a personal best it holds goes with it."] =
    "Delete this run? This cannot be undone, and a personal best it holds goes with it."
L["Delete"] = "Delete"
L["Cancel"] = "Cancel"
L["Unknown class"] = "Unknown class"
L["%s \195\151%d"] = "%s \195\151%d"
L["%d LATE"] = "%d LATE"
L["RESTARTED"] = "RESTARTED"
L["RELOADED"] = "RELOADED"
L["BY LIST"] = "BY LIST"
L["DIED"] = "DIED"
L["Unknown spec"] = "Unknown spec"
L["All characters"] = "All characters"
L["All specs"] = "All specs"
L["All targets"] = "All targets"
L["Any length"] = "Any length"
L["All time"] = "All time"
L["Today"] = "Today"
L["Last 7 days"] = "Last 7 days"
L["Last 30 days"] = "Last 30 days"
L["lost"] = "lost"
L["incomplete"] = "incomplete"
L["DATE"] = "DATE"
L["CLS \194\183 SPEC"] = "CLS \194\183 SPEC"
L["CHARACTER"] = "CHARACTER"
L["ILVL"] = "ILVL"
L["LEN"] = "LEN"
L["No runs match these filters."] = "No runs match these filters."
L["1 run"] = "1 run"
L["%d runs"] = "%d runs"
L["%s started +%.1fs after the buzzer"] = "%s started +%.1fs after the buzzer"
L["%s (grace %.1fs)."] = "%s (grace %.1fs)."
L["%s, after the quiet gap."] = "%s, after the quiet gap."
L["Session matched by list: the meter session was found by its place in Blizzard's list, not by its ID."] =
    "Session matched by list: the meter session was found by its place in Blizzard's list, not by its ID."
L["It does not count toward bests."] = "It does not count toward bests."
L["There is no score."] = "There is no score."
L["ilvl %s"] = "ilvl %s"
L["Unknown target"] = "Unknown target"
L["build %s"] = "build %s"
L["METER DPS"] = "METER DPS"
L["TIMING"] = "TIMING"
L["Race"] = "Race"
L["Tail (damage still landing)"] = "Tail (damage still landing)"
L["Grace"] = "Grace"
L["Late cast"] = "Late cast"
L["Combat ended"] = "Combat ended"
L["BACK"] = "BACK"
L["ADD NOTE"] = "ADD NOTE"
L["DELETE"] = "DELETE"
L["Select a run to see its detail."] = "Select a run to see its detail."
L["DPS \194\183 INCOMPLETE"] = "DPS \194\183 INCOMPLETE"
L["Flag \194\183 %s"] = "Flag \194\183 %s"
L["Flags \194\183 %d"] = "Flags \194\183 %d"
L["Note: %s"] = "Note: %s"
L["EDIT NOTE"] = "EDIT NOTE"
L["Combat ended at %s, before the buzzer."] = "Combat ended at %s, before the buzzer."
L["Damage stopped %ss after the buzzer"] = "Damage stopped %ss after the buzzer"
L["combat ended %ss"] = "combat ended %ss"
L["0:00 \226\128\148 race %s \226\128\148 buzzer"] = "0:00 \226\128\148 race %s \226\128\148 buzzer"
L["+%ds"] = "+%ds"
L["All categories"] = "All categories"
L["Category: %s"] = "Category: %s"
L["FLAGS"] = "FLAGS"
L["Clean runs only"] = "Clean runs only"
L["Best per spec \195\151 category \195\151 race length, all characters"] =
    "Best per spec \195\151 category \195\151 race length, all characters"
L["No personal bests yet: finish a race to set one."] = "No personal bests yet: finish a race to set one."
L["Hide flagged"] = "Hide flagged"
L["Include incomplete"] = "Include incomplete"
L["The run still counts and the flag shows on the board."] =
    "The run still counts and the flag shows on the board."

-- Key bindings: the Arm / cancel key (core/LauncherSetup.lua, core/DpsRace.lua)
L["Arm / cancel race"] = "Arm / cancel race"
L["A run is waiting for its result: /dr cancel discards it."] =
    "A run is waiting for its result: /dr cancel discards it."

-- Feature verbs (settings/Slash.lua, spec §6.4)
L["Arm a race: /dr arm [length], e.g. 90, 1:30 or 3m"] = "Arm a race: /dr arm [length], e.g. 90, 1:30 or 3m"
L["Cancel the armed or running race, or discard a pending result"] =
    "Cancel the armed or running race, or discard a pending result"
L["The race HUD: /dr hud show, hide or toggle"] = "The race HUD: /dr hud show, hide or toggle"
L["Open the Results window; /dr results bests opens the bests"] =
    "Open the Results window; /dr results bests opens the bests"
L["Print your target's name, creature ID and category"] = "Print your target's name, creature ID and category"
L["Turn test mode on or off"] = "Turn test mode on or off"
L["Lock the race HUD in place"] = "Lock the race HUD in place"
L["Unlock the race HUD to move and resize it"] = "Unlock the race HUD to move and resize it"
L["Nothing to cancel."] = "Nothing to cancel."
L["Race canceled."] = "Race canceled."
L["Race canceled: the run is deleted."] = "Race canceled: the run is deleted."
L["Pending result discarded: the run is deleted."] = "Pending result discarded: the run is deleted."
L["Result closed. The run stays in your history."] = "Result closed. The run stays in your history."
L["Usage: %s hud show, %s hud hide or %s hud toggle"] = "Usage: %s hud show, %s hud hide or %s hud toggle"
L["No target."] = "No target."
L["Unknown"] = "Unknown"
L["creature %d"] = "creature %d"
L["not a creature"] = "not a creature"
L["Target: %s \194\183 %s \194\183 category %s"] = "Target: %s \194\183 %s \194\183 category %s"

-- General page: the Race HUD tab (settings/General.lua)
L["Race HUD"] = "Race HUD"
L["Show the race HUD"] = "Show the race HUD"
L["When a race is armed"] = "When a race is armed"
L["Always"] = "Always"
L["When a race is armed: the HUD opens when you arm a race or a result arrives, and closes again when that race is over. Always: it is open from login."] =
    "When a race is armed: the HUD opens when you arm a race or a result arrives, and closes again when that race is over. Always: it is open from login."

-- Race page (settings/Race.lua)
L["Scoring rules"] = "Scoring rules"
L["Length"] = "Length"
L["Sounds"] = "Sounds"
L["Default race length"] = "Default race length"
L["The race length the HUD offers until you pick another. The last length you pick is remembered until you change this."] =
    "The race length the HUD offers until you pick another. The last length you pick is remembered until you change this."
L["Countdown cue (10, 5, 3, 2, 1)"] = "Countdown cue (10, 5, 3, 2, 1)"
L["A sound at 10, 5, 3, 2 and 1 seconds left. Switching it off silences the race in progress; switching it on takes effect from the next race."] =
    "A sound at 10, 5, 3, 2 and 1 seconds left. Switching it off silences the race in progress; switching it on takes effect from the next race."
L["Buzzer raid warning and sound"] = "Buzzer raid warning and sound"
L["A raid warning that says STOP, with a sound, the moment the race ends."] =
    "A raid warning that says STOP, with a sound, the moment the race ends."
L["Late-cast grace (s)"] = "Late-cast grace (s)"
L["A cast that starts later than this after the buzzer flags the run. 0 to 5 seconds. Applies to new runs. Saved runs keep the value they were raced with."] =
    "A cast that starts later than this after the buzzer flags the run. 0 to 5 seconds. Applies to new runs. Saved runs keep the value they were raced with."
L["Damage-restart gap (s)"] = "Damage-restart gap (s)"
L["Your damage going quiet for this long after the buzzer, then landing again, flags the run as damage restarted. 3 to 15 seconds. Applies to new runs. Saved runs keep the value they were raced with."] =
    "Your damage going quiet for this long after the buzzer, then landing again, flags the run as damage restarted. 3 to 15 seconds. Applies to new runs. Saved runs keep the value they were raced with."
L["Sticky-combat hint after (s)"] = "Sticky-combat hint after (s)"
L["How long combat may hold after the buzzer before the HUD suggests ways to drop it."] =
    "How long combat may hold after the buzzer before the HUD suggests ways to drop it."
L["Restore every Race setting on this profile to its addon default."] =
    "Restore every Race setting on this profile to its addon default."

-- Live breakdown page (settings/Live.lua)
L["Live breakdown"] = "Live breakdown"
L["Rows"] = "Rows"
L["Display"] = "Display"
L["Rows shown"] = "Rows shown"
L["How many spells the running HUD lists, in the order Blizzard's meter gives them. 3 to 15."] =
    "How many spells the running HUD lists, in the order Blizzard's meter gives them. 3 to 15."
L["Live reads per second"] = "Live reads per second"
L["How often the running HUD reads the meter while damage is landing. 2 to 10."] =
    "How often the running HUD reads the meter while damage is landing. 2 to 10."
L["Show spell icons"] = "Show spell icons"
L["Draw each spell's icon on the HUD's rows."] = "Draw each spell's icon on the HUD's rows."
L["Show live DPS"] = "Show live DPS"
L["Show Blizzard's live DPS figure beside the damage while the race runs. Your score is damage divided by the race length."] =
    "Show Blizzard's live DPS figure beside the damage while the race runs. Your score is damage divided by the race length."
L["Restore every Live breakdown setting on this profile to its addon default."] =
    "Restore every Live breakdown setting on this profile to its addon default."

-- History page (settings/History.lua)
L["History"] = "History"
L["Storage"] = "Storage"
L["Runs to keep"] = "Runs to keep"
L["0 keeps every run (the default). Above 0, the oldest runs are removed first, at login and after each saved run, and a run that holds a personal best is always kept. 0 to 10000."] =
    "0 keeps every run (the default). Above 0, the oldest runs are removed first, at login and after each saved run, and a run that holds a personal best is always kept. 0 to 10000."
L["Stored now: %d runs (about %d KB of saved variables)."] = "Stored now: %d runs (about %d KB of saved variables)."
L["Danger zone"] = "Danger zone"
L["Delete all runs\226\128\166"] = "Delete all runs\226\128\166"
L["Asks for confirmation. Personal bests go with them."] = "Asks for confirmation. Personal bests go with them."
L["Restore Runs to keep to its addon default. Stored runs are not touched."] =
    "Restore Runs to keep to its addon default. Stored runs are not touched."
L["Delete every stored run? Your personal bests go with them. This cannot be undone."] =
    "Delete every stored run? Your personal bests go with them. This cannot be undone."
L["Finish or cancel the race first."] = "Finish or cancel the race first."
L["Deleted %d runs."] = "Deleted %d runs."

-- Share and the race's chat lines (modules/Share.lua, mockup screen 12)
L["DPS Race %s"] = "DPS Race %s"
L["%s DPS"] = "%s DPS"
L["(Ka0s DPS Race)"] = "(Ka0s DPS Race)"
L["Share to"] = "Share to"
L["Say"] = "Say"
L["Party"] = "Party"
L["Raid"] = "Raid"
L["Guild"] = "Guild"
L["Whisper\226\128\166"] = "Whisper\226\128\166"
L["Whisper this run to:"] = "Whisper this run to:"
L["Send"] = "Send"
L["You can share a run once you are out of combat."] = "You can share a run once you are out of combat."
L["This run has no score to share."] = "This run has no score to share."
L["Armed: %s on %s. First hit starts the clock."] = "Armed: %s on %s. First hit starts the clock."
L["%s damage \194\183 %s DPS in %s on %s"] = "%s damage \194\183 %s DPS in %s on %s"
L["new best (+%.1f%%)"] = "new best (+%.1f%%)"
L["new best"] = "new best"
L["tail +%.1fs"] = "tail +%.1fs"
L["Couldn't read the result: the run is kept as lost."] = "Couldn't read the result: the run is kept as lost."

-- Test mode (modules/Preview.lua, the HUD's marker in modules/Hud.lua)
L["Test mode is not available in combat."] = "Test mode is not available in combat."
L["Test mode is not available during a race."] = "Test mode is not available during a race."
L["Test mode ended: a race was armed."] = "Test mode ended: a race was armed."
L["Test mode: these numbers are not yours"] = "Test mode: these numbers are not yours"
L["DPS Race \194\183 TEST"] = "DPS Race \194\183 TEST"
L["Training Dummy"] = "Training Dummy"
