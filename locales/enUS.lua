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
L["HUD"] = "HUD"
L["Profiles"] = "Profiles"
L["Slash Commands"] = "Slash Commands"

-- Key bindings (launcher-§6)
L["Toggle race HUD"] = "Toggle race HUD"
L["Toggle results window"] = "Toggle results window"
L["Shows or hides the race HUD, as the launcher's Show window entry and /dr hud toggle do."] =
    "Shows or hides the race HUD, as the launcher's Show window entry and /dr hud toggle do."
L["Shows or hides the Results window, with its run history and insights."] =
    "Shows or hides the Results window, with its run history and insights."
L["Arms a race at the HUD's length, or cancels an armed or running race. A finished race's result is kept."] =
    "Arms a race at the HUD's length, or cancels an armed or running race. A finished race's result is kept."

-- Shared refusals (slash-commands-§1, slash-commands-§7)
L["%s is unavailable: the LibKa0s library did not load."] = "%s is unavailable: the LibKa0s library did not load."
L["Not available during a performance capture."] = "Not available during a performance capture."

-- Master controls tab (settings/General.lua)
L["Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded — your other profiles are not affected."] =
    "Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded — your other profiles are not affected."
L["Yes"] = "Yes"
L["No"] = "No"
L["All settings reset to defaults."] = "All settings reset to defaults."
L["Restore every General setting on this profile to its addon default: Master controls, the new-best toast and the skin."] =
    "Restore every General setting on this profile to its addon default: Master controls, the new-best toast and the skin."

-- Slash verbs (settings/Slash.lua): the descriptions the help index and the landing page print
L["Show this help"] = "Show this help"
L["Open the settings panel"] = "Open the settings panel"
-- The reserved `skin` verb's help: LibKa0s's SKIN_PICKER_STRINGS.VERB_HELP, one wording for every host.
L["Choose a skin: open the skin picker"] = "Choose a skin: open the skin picker"
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
L["Shared session: the damage it held at the arm was taken off"] = "Shared session: the damage it held at the arm was taken off"
L["Shared session: the total may include the fight before the arm"] =
    "Shared session: the total may include the fight before the arm"
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
L["Race Length"] = "Race Length"
L["Custom"] = "Custom"
L["Target"] = "Target"
L["Arm Race"] = "Arm Race"
L["First hit starts the clock"] = "First hit starts the clock"
L["Pre-cast and pre-pot as you would on a pull. The clock starts when damage lands, not when you press the button."] =
    "Pre-cast and pre-pot as you would on a pull. The clock starts when damage lands, not when you press the button."
L["Damage"] = "Damage"
L["DPS \194\183 Live"] = "DPS \194\183 Live"
L["Elapsed"] = "Elapsed"
L["Left"] = "Left"
L["Live order \194\183 % after the race"] = "Live order \194\183 % after the race"
L["%d rows"] = "%d rows"
L["%d-%d of %d"] = "%d-%d of %d"
L["Combat Ended"] = "Combat Ended"
L["Damage Stopped"] = "Damage Stopped"
L["In Combat"] = "In Combat"
L["s"] = "s"
L["Out of Combat"] = "Out of Combat"
L["STOP"] = "STOP"
L["after buzzer"] = "after buzzer"
L["since the buzzer"] = "since the buzzer"
L["combat ended"] = "combat ended"
L["into the race"] = "into the race"
L["1 late cast \194\183 +%.1fs"] = "1 late cast \194\183 +%.1fs"
L["%d late casts \194\183 +%.1fs"] = "%d late casts \194\183 +%.1fs"
L["Grace %.1fs"] = "Grace %.1fs"
L["Damage still landing (DoTs, travel time) counts. Casts that start more than %.1fs after the buzzer are flagged on the result."] =
    "Damage still landing (DoTs, travel time) counts. Casts that start more than %.1fs after the buzzer are flagged on the result."
L["Stop Now"] = "Stop Now"
L["Take the result now instead of waiting out the damage tail. Out of combat it is read at once; in combat it is read the moment combat ends, and damage up to then counts."] =
    "Take the result now instead of waiting out the damage tail. Out of combat it is read at once; in combat it is read the moment combat ends, and damage up to then counts."
L["Discard this race. Nothing is saved."] = "Discard this race. Nothing is saved."
L["Waiting for combat to end"] = "Waiting for combat to end"
L["Reading the result"] = "Reading the result"
L["Reading when combat ends"] = "Reading when combat ends"
L["1 late cast"] = "1 late cast"
L["%d late casts"] = "%d late casts"
L["Restarted +%.1fs"] = "Restarted +%.1fs"
L["Reloaded"] = "Reloaded"
L["Session by list"] = "Session by list"
L["Shared session"] = "Shared session"
L["Incomplete: died"] = "Incomplete: died"
L["Incomplete (combat ended at %s)"] = "Incomplete (combat ended at %s)"
L["Lost"] = "Lost"
L["Died"] = "Died"
L["New best +%.1f%%"] = "New best +%.1f%%"
L["New best"] = "New best"
L["%+.1f%% vs best"] = "%+.1f%% vs best"
L["DPS"] = "DPS"
L["New Race"] = "New Race"
L["Details"] = "Details"
L["Share"] = "Share"
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
L["Runs"] = "Runs"
L["Insights"] = "Insights"
L["Click a row for details \194\183 right-click for options"] =
    "Click a row for details \194\183 right-click for options"
L["Days to keep: %d"] = "Days to keep: %d"
L["Days to keep: 0 (never prune)"] = "Days to keep: 0 (never prune)"
L["Delete this run? This cannot be undone, and a personal best it holds goes with it."] =
    "Delete this run? This cannot be undone, and a personal best it holds goes with it."
L["Delete"] = "Delete"
L["Cancel"] = "Cancel"
L["Unknown class"] = "Unknown class"
L["Unknown spec"] = "Unknown spec"
L["All characters"] = "All characters"
L["Current character"] = "Current character"
L["Current spec"] = "Current spec"
L["All specs"] = "All specs"
L["All targets"] = "All targets"
L["Any length"] = "Any length"
L["All time"] = "All time"
L["Today"] = "Today"
L["Last 7 days"] = "Last 7 days"
L["Last 30 days"] = "Last 30 days"
L["lost"] = "lost"
L["incomplete"] = "incomplete"
L["Date"] = "Date"
L["Class"] = "Class"
L["Character"] = "Character"
L["iLvl"] = "iLvl"
L["No runs match these filters."] = "No runs match these filters."
L["1 run"] = "1 run"
L["%d runs"] = "%d runs"
L["%s started +%.1fs after the buzzer"] = "%s started +%.1fs after the buzzer"
L["%s (grace %.1fs)."] = "%s (grace %.1fs)."
L["After the quiet gap past the buzzer: a new pull."] = "After the quiet gap past the buzzer: a new pull."
L["The meter session was found by its place in Blizzard's list, not by its ID."] =
    "The meter session was found by its place in Blizzard's list, not by its ID."
L["The meter kept the last fight's session open (its DoTs were still ticking), so the race landed in it."] =
    "The meter kept the last fight's session open (its DoTs were still ticking), so the race landed in it."
L["It does not count toward bests."] = "It does not count toward bests."
L["There is no score."] = "There is no score."
L["ilvl %s"] = "ilvl %s"
L["Unknown target"] = "Unknown target"
L["build %s"] = "build %s"
L["Meter DPS"] = "Meter DPS"
L["Timing"] = "Timing"
L["Race"] = "Race"
L["Tail (damage still landing)"] = "Tail (damage still landing)"
L["Grace"] = "Grace"
L["Late cast"] = "Late cast"
L["Combat ended"] = "Combat ended"
L["Back"] = "Back"
L["Add Note"] = "Add Note"
L["Select a run to see its detail."] = "Select a run to see its detail."
L["DPS \194\183 Incomplete"] = "DPS \194\183 Incomplete"
L["Edit Note"] = "Edit Note"
L["Combat ended at %s, before the buzzer."] = "Combat ended at %s, before the buzzer."
L["Damage stopped %ss after the buzzer"] = "Damage stopped %ss after the buzzer"
L["combat ended %ss"] = "combat ended %ss"
L["0:00 \226\128\148 race %s \226\128\148 buzzer"] = "0:00 \226\128\148 race %s \226\128\148 buzzer"
L["+%ds"] = "+%ds"
L["Flags"] = "Flags"
L["Hide flagged"] = "Hide flagged"
L["Include incomplete"] = "Include incomplete"
L["Only best"] = "Only best"
L["Save"] = "Save"
L["Reset"] = "Reset"
L["Clear"] = "Clear"
L["%s \194\183 %s"] = "%s \194\183 %s"
L["%s: %s \194\183 %s"] = "%s: %s \194\183 %s"
L["Runs view saved as default."] = "Runs view saved as default."
L["Runs view reset to stock defaults."] = "Runs view reset to stock defaults."
L["Save these filters, the grouping and the sort as this profile's default view of Runs."] = "Save these filters, the grouping and the sort as this profile's default view of Runs."
L["Delete the saved view and go back to the stock one: your character in every spec, grouped by Full, newest first."] =
    "Delete the saved view and go back to the stock one: your character in every spec, grouped by Full, newest first."
L["Go back to the saved view (the stock one when none is saved). The saved view is kept."] = "Go back to the saved view (the stock one when none is saved). The saved view is kept."
L["Group: None"] = "Group: None"
L["Group: Character"] = "Group: Character"
L["Group: Class & spec"] = "Group: Class & spec"
L["Group: Target"] = "Group: Target"
L["Group: Time"] = "Group: Time"
L["Group: Target + time"] = "Group: Target + time"
L["Group: Spec + target + time"] = "Group: Spec + target + time"
L["Group: Full"] = "Group: Full"
L["Full: %s"] = "Full: %s"
L["Character: %s"] = "Character: %s"
L["Class & spec: %s"] = "Class & spec: %s"
L["Target: %s"] = "Target: %s"
L["Time: %s"] = "Time: %s"
L["Spec: %s"] = "Spec: %s"
L["Restore Days to keep, the Results table's and the Run detail's look and the hidden items to their addon defaults. Stored runs are not touched."] =
    "Restore Days to keep, the Results table's and the Run detail's look and the hidden items to their addon defaults. Stored runs are not touched."
L["Hidden items"] = "Hidden items"
L["Account-wide: shared by every profile. Item IDs, comma-separated, that the Results window's Usage never lists (the section, the Used column and its tooltip), on every run. A run that used one still records it, so taking it off the list brings it back."] =
    "Account-wide: shared by every profile. Item IDs, comma-separated, that the Results window's Usage never lists (the section, the Used column and its tooltip), on every run. A run that used one still records it, so taking it off the list brings it back."
L["Items the Results window's Usage never lists, on any run. Right-click an item in a run's Usage edit to add it here."] =
    "Items the Results window's Usage never lists, on any run. Right-click an item in a run's Usage edit to add it here."
L["Hide an item"] = "Hide an item"
L["An item ID, a shift-clicked item link, or the name of an item a run listed."] =
    "An item ID, a shift-clicked item link, or the name of an item a run listed."
L["No item is hidden."] = "No item is hidden."
L["Results table"] = "Results table"
L["Damage bar"] = "Damage bar"
L["Damage bar background"] = "Damage bar background"
L["Damage bar border"] = "Damage bar border"
L["DPS bar background"] = "DPS bar background"
L["DPS bar border"] = "DPS bar border"
L["Run detail"] = "Run detail"
L["Spell bar background"] = "Spell bar background"
L["Spell bar border"] = "Spell bar border"
L["Best run bar"] = "Best run bar"
L["Best run bar background"] = "Best run bar background"
L["Best run bar border"] = "Best run bar border"
L["Other run bar"] = "Other run bar"
L["Other run bar background"] = "Other run bar background"
L["Other run bar border"] = "Other run bar border"
L["Pace bar background"] = "Pace bar background"
L["Pace bar border"] = "Pace bar border"
L["Use the skin's background"] = "Use the skin's background"
L["Draw this bar's background in the skin's track color. The background swatch is not read while this is on."] =
    "Draw this bar's background in the skin's track color. The background swatch is not read while this is on."
L["DPS bar"] = "DPS bar"
L["Bar text"] = "Bar text"
L["The run still counts toward bests."] = "The run still counts toward bests."

-- Key bindings: the Arm or cancel key (core/LauncherSetup.lua, core/DpsRace.lua)
L["Arm or cancel race"] = "Arm or cancel race"
L["A run is waiting for its result: /dr cancel discards it."] =
    "A run is waiting for its result: /dr cancel discards it."

-- Feature verbs (settings/Slash.lua, spec §6.4)
L["Arm a race: /dr arm [length], e.g. 90, 1:30 or 3m"] = "Arm a race: /dr arm [length], e.g. 90, 1:30 or 3m"
L["Cancel the armed or running race, or discard a pending result"] =
    "Cancel the armed or running race, or discard a pending result"
L["The race HUD: /dr hud show, hide or toggle"] = "The race HUD: /dr hud show, hide or toggle"
L["Open the Results window; /dr results insights opens Insights"] =
    "Open the Results window; /dr results insights opens Insights"
L["Print your target's name, creature ID and category"] = "Print your target's name, creature ID and category"
L["Sample data in the HUD and the Results window: /dr test [armed|running|result]"] = "Sample data in the HUD and the Results window: /dr test [armed|running|result]"
L["Play a whole sample race: /dr sim [%s]"] = "Play a whole sample race: /dr sim [%s]"
L["Lock the race HUD in place"] = "Lock the race HUD in place"
L["Unlock the race HUD to move and resize it"] = "Unlock the race HUD to move and resize it"
L["The late-cast ignore list: /dr ignore [show|add|remove|defaults] <spell ID, link or name>"] =
    "The late-cast ignore list: /dr ignore [show|add|remove|defaults] <spell ID, link or name>"
L["Usage: %s ignore [show|add|remove|defaults] <spell ID, link or name>"] =
    "Usage: %s ignore [show|add|remove|defaults] <spell ID, link or name>"
L["The late-cast ignore list is empty."] = "The late-cast ignore list is empty."
L["Late-cast ignore list:"] = "Late-cast ignore list:"
L["More than one spell is named '%s'. Use its spell ID or a shift-clicked link."] =
    "More than one spell is named '%s'. Use its spell ID or a shift-clicked link."
L["No spell named '%s' is known. Use its spell ID or a shift-clicked link."] =
    "No spell named '%s' is known. Use its spell ID or a shift-clicked link."
L["%s is already ignored."] = "%s is already ignored."
L["Late casts of %s no longer flag a run."] = "Late casts of %s no longer flag a run."
L["%s is not on the list."] = "%s is not on the list."
L["Late casts of %s flag a run again."] = "Late casts of %s flag a run again."
L["The late-cast ignore list is back to its defaults."] = "The late-cast ignore list is back to its defaults."
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

-- HUD page: the Race HUD tab (settings/Hud.lua): Display, then Live breakdown
L["Race HUD"] = "Race HUD"
L["Display"] = "Display"
L["Show the race HUD"] = "Show the race HUD"
L["When a race is armed"] = "When a race is armed"
L["Always"] = "Always"
L["When a race is armed: the HUD opens when you arm a race or a result arrives, and closes again when that race is over. Always: it is open from login. General visibility on Master controls still applies: while it hides the addon, the HUD stays hidden whatever this says."] =
    "When a race is armed: the HUD opens when you arm a race or a result arrives, and closes again when that race is over. Always: it is open from login. General visibility on Master controls still applies: while it hides the addon, the HUD stays hidden whatever this says."
L["Race clock"] = "Race clock"
L["Show near a training dummy"] = "Show near a training dummy"
L["Open the HUD by itself while a known training dummy is your target or its nameplate is up, and close it again a few seconds after none is, unless a race or its result holds it. If you close it yourself, it stays closed until you leave the dummies. Not in instances. With nameplates off, only your target counts."] =
    "Open the HUD by itself while a known training dummy is your target or its nameplate is up, and close it again a few seconds after none is, unless a race or its result holds it. If you close it yourself, it stays closed until you leave the dummies. Not in instances. With nameplates off, only your target counts."
L["Elapsed and time left"] = "Elapsed and time left"
L["Time left"] = "Time left"
L["Time elapsed"] = "Time elapsed"
L["What the HUD's clock shows while the race runs: the time elapsed in green, the time left in red, or both side by side. The armed and stop screens keep their own."] =
    "What the HUD's clock shows while the race runs: the time elapsed in green, the time left in red, or both side by side. The armed and stop screens keep their own."

-- Race page (settings/Race.lua): Length, Countdown, At the buzzer, Scoring rules
L["Length"] = "Length"
L["Time"] = "Time"
L["Status"] = "Status"
L["Spec best"] = "Spec best"
L["%+.1f%%"] = "%+.1f%%"
L["%.1f%%"] = "%.1f%%"
L["Delta"] = "Delta"
L["Complete"] = "Complete"
L["Flagged"] = "Flagged"
L["Incomplete"] = "Incomplete"
L["%s / %s"] = "%s / %s"
L["at %s"] = "at %s"
L["Time %s"] = "Time %s"
L["The race length, then how long your damage kept landing after the buzzer (DoTs, travel time). An incomplete run shows when combat ended instead. Each preset length has its own color."] =
    "The race length, then how long your damage kept landing after the buzzer (DoTs, travel time). An incomplete run shows when combat ended instead. Each preset length has its own color."
L["Countdown"] = "Countdown"
L["At the buzzer"] = "At the buzzer"
L["Scoring rules"] = "Scoring rules"
L["Default race length"] = "Default race length"
L["Auto-arm"] = "Auto-arm"
L["Arm on a training dummy"] = "Arm on a training dummy"
L["Arm a race by itself when you target a known training dummy out of combat, at the length Arm Race would use; your first hit starts it. Targeting anything else (or nothing) before the pull cancels it. Nothing arms in combat, in instances, over a result, or while a run waits for its result."] =
    "Arm a race by itself when you target a known training dummy out of combat, at the length Arm Race would use; your first hit starts it. Targeting anything else (or nothing) before the pull cancels it. Nothing arms in combat, in instances, over a result, or while a run waits for its result."
L["The race length the HUD offers until you pick another. The last length you pick is remembered until you change this."] =
    "The race length the HUD offers until you pick another. The last length you pick is remembered until you change this."
L["Countdown cue sound"] = "Countdown cue sound"
L["A sound at 10, 5, 3, 2 and 1 seconds left, and with each number of the center countdown. Takes effect at once, in the race in progress too."] =
    "A sound at 10, 5, 3, 2 and 1 seconds left, and with each number of the center countdown. Takes effect at once, in the race in progress too."
L["Center-screen countdown"] = "Center-screen countdown"
L["Large numbers in the middle of the screen for the last seconds of the race, one a second down to 1, like a pull timer. Only you see them."] =
    "Large numbers in the middle of the screen for the last seconds of the race, one a second down to 1, like a pull timer. Only you see them."
L["Center countdown from (seconds)"] = "Center countdown from (seconds)"
L["How many seconds before the buzzer the center countdown starts. 3 to 10."] =
    "How many seconds before the buzzer the center countdown starts. 3 to 10."
L["Buzzer raid warning and sound"] = "Buzzer raid warning and sound"
L["A raid warning that says STOP, with a sound, the moment the race ends."] =
    "A raid warning that says STOP, with a sound, the moment the race ends."
L["Late-cast grace (seconds)"] = "Late-cast grace (seconds)"
L["A cast that starts later than this after the buzzer flags the run. 0 to 5 seconds. Applies to new runs. Saved runs keep the value they were raced with."] =
    "A cast that starts later than this after the buzzer flags the run. 0 to 5 seconds. Applies to new runs. Saved runs keep the value they were raced with."
L["Damage-restart gap (seconds)"] = "Damage-restart gap (seconds)"
L["Your damage going quiet for this long after the buzzer, then landing again, flags the run as damage restarted. 3 to 15 seconds. Applies to new runs. Saved runs keep the value they were raced with."] =
    "Your damage going quiet for this long after the buzzer, then landing again, flags the run as damage restarted. 3 to 15 seconds. Applies to new runs. Saved runs keep the value they were raced with."
L["Late-cast ignore list"] = "Late-cast ignore list"
L["Spell IDs, comma-separated, whose casts after the grace never flag a run. Applies to every stored run: a run keeps its casts, so taking a spell off the list flags them again. Unlike the grace, nothing is frozen into a run. 8690 stands for every hearthstone."] =
    "Spell IDs, comma-separated, whose casts after the grace never flag a run. Applies to every stored run: a run keeps its casts, so taking a spell off the list flags them again. Unlike the grace, nothing is frozen into a run. 8690 stands for every hearthstone."
L["(all hearthstones, %d)"] = "(all hearthstones, %d)"
L["Spells whose casts after the grace never flag a run, on every stored run. Taking one off flags its casts again. A right-click on a late-cast flag, on the HUD's result or in a run's detail, adds or removes its spell too."] =
    "Spells whose casts after the grace never flag a run, on every stored run. Taking one off flags its casts again. A right-click on a late-cast flag, on the HUD's result or in a run's detail, adds or removes its spell too."
L["Ignore a spell"] = "Ignore a spell"
L["A spell ID, a shift-clicked spell link, or the name of a spell a run cast late. \"Hearthstone\" adds every hearthstone."] =
    "A spell ID, a shift-clicked spell link, or the name of a spell a run cast late. \"Hearthstone\" adds every hearthstone."
L["No spell is ignored: every late cast flags its run."] =
    "No spell is ignored: every late cast flags its run."
L["Reset list"] = "Reset list"
L["Put the list back to its six defaults: Invisibility, Vanish, Feign Death, every hearthstone, Shadowmeld and Greater Invisibility. The other Race settings are not touched."] =
    "Put the list back to its six defaults: Invisibility, Vanish, Feign Death, every hearthstone, Shadowmeld and Greater Invisibility. The other Race settings are not touched."
L["%s, all variants (%d)"] = "%s, all variants (%d)"
L["%s (%d)"] = "%s (%d)"
-- The late-cast ignore list's actions (#8): the right-click menu, the ignored casts' lines and chip.
L["Ignored: %s"] = "Ignored: %s"
L["Late casts"] = "Late casts"
L["Ignore %s for late casts"] = "Ignore %s for late casts"
L["Stop ignoring %s"] = "Stop ignoring %s"
L["Stop ignoring all hearthstones"] = "Stop ignoring all hearthstones"
L["Ignore for late casts"] = "Ignore for late casts"
L["Right-click to ignore a spell for late casts, or count it again."] =
    "Right-click to ignore a spell for late casts, or count it again."
L["%d ignored"] = "%d ignored"
L["Late casts on the ignore list: they flag nothing."] = "Late casts on the ignore list: they flag nothing."
L["1 ignored late cast"] = "1 ignored late cast"
L["%d ignored late casts"] = "%d ignored late casts"
L["On the late-cast ignore list, so no flag. Right-click to count a spell again."] =
    "On the late-cast ignore list, so no flag. Right-click to count a spell again."
L["No flags"] = "No flags"
L["A gray tick is a spell on the late-cast ignore list: ignored, so no flag."] =
    "A gray tick is a spell on the late-cast ignore list: ignored, so no flag."
L["Sticky-combat hint after (seconds)"] = "Sticky-combat hint after (seconds)"
L["How long combat may hold after the buzzer before the HUD suggests ways to drop it. 5 to 60 seconds."] =
    "How long combat may hold after the buzzer before the HUD suggests ways to drop it. 5 to 60 seconds."
L["Restore every HUD setting on this profile to its addon default: the Race HUD tab (display, live breakdown, chart and pace) and HUD Appearance."] =
    "Restore every HUD setting on this profile to its addon default: the Race HUD tab (display, live breakdown, chart and pace) and HUD Appearance."

-- HUD page: the Race HUD tab's Live breakdown subsection (settings/Hud.lua)
L["Live breakdown"] = "Live breakdown"
L["Spell rows shown"] = "Spell rows shown"
L["How many spells the running HUD lists, in the order Blizzard's meter gives them. 0 lists every spell: as many as fit the window show, and the mouse wheel scrolls through the rest."] =
    "How many spells the running HUD lists, in the order Blizzard's meter gives them. 0 lists every spell: as many as fit the window show, and the mouse wheel scrolls through the rest."
L["Live reads per second"] = "Live reads per second"
L["HUD Appearance"] = "HUD Appearance"
L["Elapsed clock"] = "Elapsed clock"
L["Time left clock"] = "Time left clock"
L["Live figures"] = "Live figures"
L["Spell bars"] = "Spell bars"
L["Spell text"] = "Spell text"
L["Row height"] = "Row height"
L["Height of the clock, in points, when both clocks show. A clock shown alone draws half again as large."] =
    "Height of the clock, in points, when both clocks show. A clock shown alone draws half again as large."
L["The height of each spell row, in pixels, on the HUD and in the Results window's breakdown. Taller rows fit fewer spells in the same window."] =
    "The height of each spell row, in pixels, on the HUD and in the Results window's breakdown. Taller rows fit fewer spells in the same window."
L["How often the running HUD reads the meter while damage is landing. 2 to 10."] =
    "How often the running HUD reads the meter while damage is landing. 2 to 10."
L["Show spell icons"] = "Show spell icons"
L["Draw each spell's icon on the HUD's rows."] = "Draw each spell's icon on the HUD's rows."
L["Show live DPS"] = "Show live DPS"
L["Show Blizzard's live DPS figure beside the damage while the race runs. Your score is damage divided by the race length."] =
    "Show Blizzard's live DPS figure beside the damage while the race runs. Your score is damage divided by the race length."

-- HUD page: the Race HUD tab's Chart and pace subsection and HUD Appearance's Damage chart (#2, #3)
L["Chart and pace"] = "Chart and pace"
L["Show damage chart"] = "Show damage chart"
L["Draw your damage over the race as columns under the live figures, scaled to the best on this board (with its average pace as a faint line) or, with no best yet, to your damage so far. Hidden when the pull carried an earlier fight's session. The result card and the Results window show it again for races run since your last reload or login."] =
    "Draw your damage over the race as columns under the live figures, scaled to the best on this board (with its average pace as a faint line) or, with no best yet, to your damage so far. Hidden when the pull carried an earlier fight's session. The result card and the Results window show it again for races run since your last reload or login."
L["Show pace bar"] = "Show pace bar"
L["Draw a bar under the live figures against the best on this board: its tick is the best's average pace at this moment of the race. The result card shows it again after the race, your final damage against the best before the run. Hidden with no best yet, and when the pull carried an earlier fight's session."] =
    "Draw a bar under the live figures against the best on this board: its tick is the best's average pace at this moment of the race. The result card shows it again after the race, your final damage against the best before the run. Hidden with no best yet, and when the pull carried an earlier fight's session."
L["Show cooldown icons"] = "Show cooldown icons"
L["Mark each cast of an ability with a cooldown of 29 seconds or more (your big cooldowns, trinkets and potions) with its icon along the top of the damage chart: live on the HUD, on the result card and in the Results window. Hover an icon for the spell and its time."] =
    "Mark each cast of an ability with a cooldown of 29 seconds or more (your big cooldowns, trinkets and potions) with its icon along the top of the damage chart: live on the HUD, on the result card and in the Results window. Hover an icon for the spell and its time."
L["Pace bar range"] = "Pace bar range"
L["How far either side of the best's pace the bar reaches: 1.5 = \194\17750%, empty at half the best's damage by now and full at half again. The tick in the middle is the best's pace. 1.1 to 2.0."] =
    "How far either side of the best's pace the bar reaches: 1.5 = \194\17750%, empty at half the best's damage by now and full at half again. The tick in the middle is the best's pace. 1.1 to 2.0."
L["Damage chart"] = "Damage chart"
L["Chart height"] = "Chart height"
L["The height of the damage chart's plot, in pixels, on the HUD and in the Results window. A taller chart leaves fewer spell rows in the same window; when even three rows would not fit, the chart steps aside."] =
    "The height of the damage chart's plot, in pixels, on the HUD and in the Results window. A taller chart leaves fewer spell rows in the same window; when even three rows would not fit, the chart steps aside."
L["Column gap"] = "Column gap"
L["The space between two of the damage chart's columns, in pixels. 0 draws them as one smooth area."] =
    "The space between two of the damage chart's columns, in pixels. 0 draws them as one smooth area."
L["Chart background"] = "Chart background"
L["Background color"] = "Background color"
L["Pace bar"] = "Pace bar"

-- History page (settings/History.lua)
L["History"] = "History"
L["Storage"] = "Storage"
L["Days to keep"] = "Days to keep"
L["Account-wide: shared by every profile. Runs older than this many days are removed, at login and after each saved run, and a run that holds a personal best is always kept. 90 by default; 0 keeps every run. 0 to 3650."] =
    "Account-wide: shared by every profile. Runs older than this many days are removed, at login and after each saved run, and a run that holds a personal best is always kept. 90 by default; 0 keeps every run. 0 to 3650."
L["Stored now: %d runs (about %d KB of saved variables)."] = "Stored now: %d runs (about %d KB of saved variables)."
L["Purge history\226\128\166"] = "Purge history\226\128\166"
L["Deletes every stored run. Asks for confirmation. Personal bests go with them."] =
    "Deletes every stored run. Asks for confirmation. Personal bests go with them."
L["Delete every stored run? Your personal bests go with them. This cannot be undone."] =
    "Delete every stored run? Your personal bests go with them. This cannot be undone."
L["Finish or cancel the race first."] = "Finish or cancel the race first."
L["Deleted %d runs."] = "Deleted %d runs."

-- Share and the race's chat lines (modules/Share.lua, mockup screen 12)
L["DPS Race %s"] = "DPS Race %s"
L["%s DPS"] = "%s DPS"
-- The new-best toast (#5, modules/BestToast.lua; General > New-best toast).
L["New best:"] = "New best:"
L["%s DPS, %s better than previous best (%s)"] = "%s DPS, %s better than previous best (%s)"
L["New-best toast"] = "New-best toast"
L["Show a toast for a new best"] = "Show a toast for a new best"
L["When a race sets a new personal best on its board (spec, dummy and length), a toast near the top of the screen says by how much, whether or not the HUD is open. A board's first run has nothing to beat and shows none. Test mode shows a sample you can drag into place."] =
    "When a race sets a new personal best on its board (spec, dummy and length), a toast near the top of the screen says by how much, whether or not the HUD is open. A board's first run has nothing to beat and shows none. Test mode shows a sample you can drag into place."
L["Play a sound"] = "Play a sound"
L["Play an alert sound as the toast appears."] = "Play an alert sound as the toast appears."
L["Toast duration (seconds)"] = "Toast duration (seconds)"
L["How long the toast stays before it closes by itself. It waits while the pointer is over it, and closes at once on its X or a right-click. 3 to 30."] =
    "How long the toast stays before it closes by itself. It waits while the pointer is over it, and closes at once on its X or a right-click. 3 to 30."
L["Toast scale"] = "Toast scale"
L["The toast's size. It grows and shrinks about the place you dragged it to. 0.5 to 2.0."] =
    "The toast's size. It grows and shrinks about the place you dragged it to. 0.5 to 2.0."
L["Test toast"] = "Test toast"
L["Show a sample new-best toast with the duration, sound and scale above. Drag it to place it while it shows; Reset position (General > Master controls) puts it back."] =
    "Show a sample new-best toast with the duration, sound and scale above. Drag it to place it while it shows; Reset position (General > Master controls) puts it back."
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
L["Test mode: sample numbers. Combat or Arm ends it"] = "Test mode: sample numbers. Combat or Arm ends it"
L["DPS Race \194\183 Test"] = "DPS Race \194\183 Test"
L["Training Dummy"] = "Training Dummy"

-- Test mode's static views and the sim (B5: modules/Preview.lua, modules/Sim.lua, modules/MockRuns.lua,
-- the Results window's marker in modules/Results.lua, core/DpsRace.lua)
L["Usage: %s test [armed|running|result]"] = "Usage: %s test [armed|running|result]"
L["Usage: %s sim [%s]"] = "Usage: %s sim [%s]"
L["  %s: %s"] = "  %s: %s"
L["beats the best"] = "beats the best"
L["complete, behind the best"] = "complete, behind the best"
L["the first race on its board: no best, no pace bar"] = "the first race on its board: no best, no pace bar"
L["combat ends before the buzzer"] = "combat ends before the buzzer"
L["you die mid-race"] = "you die mid-race"
L["a late cast after the buzzer"] = "a late cast after the buzzer"
L["a shared session: no chart, no pace bar"] = "a shared session: no chart, no pace bar"
L["Test mode: sample runs. Nothing here is saved"] = "Test mode: sample runs. Nothing here is saved"
L["DPS Race \226\128\148 Results \194\183 Test"] = "DPS Race \226\128\148 Results \194\183 Test"
L["Not saved: the Results window is showing sample runs."] = "Not saved: the Results window is showing sample runs."
L["You"] = "You"
L["Sample note: opener with every cooldown"] = "Sample note: opener with every cooldown"
L["Sample note: five dummies in reach"] = "Sample note: five dummies in reach"
L["Sample note: another character's best"] = "Sample note: another character's best"

-- The Results window's tooltips (modules/Results_Tips.lua, modules/Results_Runs.lua)
L["Role: %s"] = "Role: %s"
L["Class color"] = "Class color"
L["Level %d"] = "Level %d"
L["Item level %s"] = "Item level %s"
L["%s overall, counting bags"] = "%s overall, counting bags"
L["Equipped, read when the race was armed."] = "Equipped, read when the race was armed."
L["Race length %s"] = "Race length %s"
L["Your damage kept landing %.1fs after the buzzer (DoTs, travel time). It counts."] =
    "Your damage kept landing %.1fs after the buzzer (DoTs, travel time). It counts."
L["Combat ended %.1fs after the buzzer."] = "Combat ended %.1fs after the buzzer."
L["The session could not be read: there is no score."] =
    "The session could not be read: there is no score."
L["%s damage"] = "%s damage"
L["Everything the meter's session held, read after combat (%ds)."] =
    "Everything the meter's session held, read after combat (%ds)."
L["Damage over the time in combat (%s). Incomplete runs never rank."] =
    "Damage over the time in combat (%s). Incomplete runs never rank."
L["Damage over the race length (%s), your clock."] = "Damage over the race length (%s), your clock."
L["Blizzard's meter said %s (over its whole session, idle time included)."] =
    "Blizzard's meter said %s (over its whole session, idle time included)."
L["1 flag"] = "1 flag"
L["%d flags"] = "%d flags"
L["Flags inform; they never void a run."] = "Flags inform; they never void a run."
L["Click to fold or unfold the group."] = "Click to fold or unfold the group."
L["When the race started. Click to sort."] = "When the race started. Click to sort."
L["The character's class and spec."] = "The character's class and spec."
L["Who raced. Hover a name for the realm, race and where."] =
    "Who raced. Hover a name for the realm, race and where."
L["Equipped item level when the race was armed."] = "Equipped item level when the race was armed."
L["The dummy type the race was against, from the dummy catalog. Unlisted targets are Other."] =
    "The dummy type the race was against, from the dummy catalog. Unlisted targets are Other."
L["The race length the best was set at. Each preset length has its own color."] = "The race length the best was set at. Each preset length has its own color."
L["Your damage for the run, read from Blizzard's meter after combat. The bar runs from the smallest run in its group to the largest (with no grouping, the whole view)."] =
    "Your damage for the run, read from Blizzard's meter after combat. The bar runs from the smallest run in its group to the largest (with no grouping, the whole view)."
L["Damage over the race length (over the time in combat for an incomplete run). The bar runs from the smallest run in its group to the largest (with no grouping, the whole view)."] =
    "Damage over the race length (over the time in combat for an incomplete run). The bar runs from the smallest run in its group to the largest (with no grouping, the whole view)."
L["How far this run's DPS is from the highest complete run in its group (with no grouping, the whole view). Recomputed whenever the filters or the grouping change."] =
    "How far this run's DPS is from the highest complete run in its group (with no grouping, the whole view). Recomputed whenever the filters or the grouping change."
L["Spec best: the best for its spec, target type and length, which its tooltip names. Complete, Flagged, Incomplete, Died or Lost otherwise."] =
    "Spec best: the best for its spec, target type and length, which its tooltip names. Complete, Flagged, Incomplete, Died or Lost otherwise."
L["What happened on the run that its result should mention: late casts, a restart, a reload."] =
    "What happened on the run that its result should mention: late casts, a restart, a reload."
L["A lost run has no DPS to compare."] = "A lost run has no DPS to compare."
L["No complete run in this group to compare with."] =
    "No complete run in this group to compare with."
L["No complete run in view to compare with."] = "No complete run in view to compare with."
L["%+.1f%% vs the max"] = "%+.1f%% vs the max"
L["The max in this group: %s DPS."] = "The max in this group: %s DPS."
L["The max in view: %s DPS."] = "The max in view: %s DPS."
L["This run is the max in its group."] = "This run is the max in its group."
L["This run is the max in view."] = "This run is the max in view."
L["An incomplete run is compared, but never sets the max."] =
    "An incomplete run is compared, but never sets the max."
L["The best run for its spec, target type and race length."] =
    "The best run for its spec, target type and race length."
L["A complete run that holds no best."] = "A complete run that holds no best."
L["A complete run that carries a flag."] = "A complete run that carries a flag."
L["Combat ended before the buzzer. It never counts toward bests."] =
    "Combat ended before the buzzer. It never counts toward bests."
L["You died before the buzzer. It never counts toward bests."] =
    "You died before the buzzer. It never counts toward bests."
L["The meter's session could not be read after combat. There is no score."] =
    "The meter's session could not be read after combat. There is no score."
L["Collapse: the list alone (a click opens a run in its place)"] = "Collapse: the list alone (a click opens a run in its place)"
L["Expand: the run's detail beside the list"] = "Expand: the run's detail beside the list"

-- The detail's section arrows (each heading folds or opens its section)
L["Collapse this section"] = "Collapse this section"
L["Expand this section"] = "Expand this section"

-- The detail's Delta box and New best badge (Tips.Detail "delta" and "badge")
L["its group in the Runs list"] = "its group in the Runs list"
L["the Runs list's whole view"] = "the Runs list's whole view"
L["its board (every run of the same spec, target type and race length)"] =
    "its board (every run of the same spec, target type and race length)"
L["The only complete run in %s: there is no runner-up to lead."] =
    "The only complete run in %s: there is no runner-up to lead."
L["This run's lead over the runner-up in %s."] = "This run's lead over the runner-up in %s."
L["The runner-up: %s DPS."] = "The runner-up: %s DPS."
L["No complete run in %s to compare with."] = "No complete run in %s to compare with."
L["Against the max DPS in %s."] = "Against the max DPS in %s."
L["The max: %s DPS."] = "The max: %s DPS."
L["The Runs list's filters leave this run out, so it is measured on its board."] =
    "The Runs list's filters leave this run out, so it is measured on its board."
L["Recomputed whenever the Runs list's filters or grouping change."] =
    "Recomputed whenever the Runs list's filters or grouping change."
L["The highest DPS among the complete runs in %s."] = "The highest DPS among the complete runs in %s."

-- The run detail's tooltips (modules/Results_Tips.lua, Tips.Detail and Tips.Spell)
L["#%d of %d spells"] = "#%d of %d spells"
L["%.1f%% of the run's damage"] = "%.1f%% of the run's damage"
L["A line of your own kept with the run: what you tried, what went wrong."] =
    "A line of your own kept with the run: what you tried, what went wrong."
L["Back to the list; the run stays selected."] = "Back to the list; the run stays selected."
L["Blizzard's damage meter: damage over its whole session, the idle time before the pull and the tail included. Shown for comparison; it never ranks."] =
    "Blizzard's damage meter: damage over its whole session, the idle time before the pull and the tail included. Shown for comparison; it never ranks."
L["Edit Note changes it; an empty note removes it."] = "Edit Note changes it; an empty note removes it."
L["Enter saves, Escape cancels. Up to %d characters."] = "Enter saves, Escape cancels. Up to %d characters."
L["Left: the race, from the start to the buzzer. Right: the seconds after the buzzer, with the grace window, the damage still landing, any late casts and the end of combat."] =
    "Left: the race, from the start to the buzzer. Right: the seconds after the buzzer, with the grace window, the damage still landing, any late casts and the end of combat."
L["Note"] = "Note"
L["Sharing is unavailable: the Share module did not load."] = "Sharing is unavailable: the Share module did not load."
L["Post the run's summary to chat: say, party, raid, guild or a whisper."] =
    "Post the run's summary to chat: say, party, raid, guild or a whisper."
L["Remove this run from history, after a confirmation. A best it holds goes with it."] =
    "Remove this run from history, after a confirmation. A best it holds goes with it."
L["The race, from the start to the buzzer (to the end of combat for an incomplete run)."] =
    "The race, from the start to the buzzer (to the end of combat for an incomplete run)."
L["Damage still landing after the buzzer (DoTs, travel time). It counts."] =
    "Damage still landing after the buzzer (DoTs, travel time). It counts."
L["Casts started this long after the buzzer carry no flag: the Race page's Late-cast grace, frozen into each run."] =
    "Casts started this long after the buzzer carry no flag: the Race page's Late-cast grace, frozen into each run."
L["A cast started after the grace window. The run counts, with a flag."] =
    "A cast started after the grace window. The run counts, with a flag."
L["When combat ended."] = "When combat ended."
L["Restart"] = "Restart"
L["Your damage started again after a quiet gap past the buzzer: a new pull. The run counts, with a flag."] =
    "Your damage started again after a quiet gap past the buzzer: a new pull. The run counts, with a flag."

-- The run detail's compare (modules/Results_Compare.lua, its tooltips in modules/Results_Tips.lua, the
-- row menu's pick in modules/Results.lua)
L["Compare With This Run"] = "Compare With This Run"
L["Compare vs best"] = "Compare vs best"
L["Compare vs runner-up"] = "Compare vs runner-up"
L["Compare vs %s"] = "Compare vs %s"
L["Clear Pick"] = "Clear Pick"
L["Different board: the spec, target type or race length differ."] =
    "Different board: the spec, target type or race length differ."
L["This run"] = "This run"
L["Best run"] = "Best run"
L["Runner-up"] = "Runner-up"
L["Picked"] = "Picked"
L["Difference"] = "Difference"
L["Spell"] = "Spell"
L["Compare"] = "Compare"
L["Sets this run beside %s: damage, DPS and every spell."] =
    "Sets this run beside %s: damage, DPS and every spell."
L["This run has no score to compare (it was lost)."] = "This run has no score to compare (it was lost)."
L["No other complete run on this run's board (same spec, target type and race length) to compare with."] =
    "No other complete run on this run's board (same spec, target type and race length) to compare with."
L["Pick another run from a row's right-click menu: Compare With This Run."] =
    "Pick another run from a row's right-click menu: Compare With This Run."
L["Compare with the best on this run's board again."] = "Compare with the best on this run's board again."
L["Different board"] = "Different board"
L["The picked run differs in spec, target type or race length, so the figures are not like for like."] =
    "The picked run differs in spec, target type or race length, so the figures are not like for like."
L["This run: %s"] = "This run: %s"
L["Picked: %s"] = "Picked: %s"
L["This run against %s"] = "This run against %s"
L["Damage: %s against %s (%s)"] = "Damage: %s against %s (%s)"
L["DPS: %s against %s (%s)"] = "DPS: %s against %s (%s)"
L["Difference: this run against the other, as a share of the other's figure."] =
    "Difference: this run against the other, as a share of the other's figure."
L["the run you picked"] = "the run you picked"
L["the runner-up on its board (this run holds the best)"] =
    "the runner-up on its board (this run holds the best)"
L["the best on its board (same spec, target type and race length)"] =
    "the best on its board (same spec, target type and race length)"
L["%s: not cast"] = "%s: not cast"
L["%s: %s damage"] = "%s: %s damage"
L["%s: %s damage (%.1f%%)"] = "%s: %s damage (%.1f%%)"
L["Difference: %s"] = "Difference: %s"

-- The damage chart and the pace bar (modules/Hud_Chart.lua, #2, #3) and the detail's chart tooltip
L["Damage profile"] = "Damage profile"
L["vs best pace"] = "vs best pace"
L["first race on this board"] = "first race on this board"
L["Your damage so far at each step of the race, captured live. With a best before this run, the faint line is that best's average pace, on the same scale."] =
    "Your damage so far at each step of the race, captured live. With a best before this run, the faint line is that best's average pace, on the same scale."
L["Only races run since your last reload or login have it: the live numbers cannot be saved."] =
    "Only races run since your last reload or login have it: the live numbers cannot be saved."
L["An icon along the top marks each cast of an ability with a cooldown of 29 seconds or more. Hover it for the spell and its time; a +n mark stands for casts too crowded to show apart."] =
    "An icon along the top marks each cast of an ability with a cooldown of 29 seconds or more. Hover it for the spell and its time; a +n mark stands for casts too crowded to show apart."
-- A cast's tooltip: a cooldown icon on the damage chart, a timeline tick (#14)
L["%s (pet)"] = "%s (pet)"
L["Cast at %s"] = "Cast at %s"
-- A +n mark on the damage chart (casts too crowded to show apart) and its tooltip
L["+%d"] = "+%d"
L["%d cooldowns here"] = "%d cooldowns here"
L["%s at %s"] = "%s at %s"

-- The ability timeline (#14, modules/Results_Timeline.lua), its button in the run detail and their tooltips
L["Ability timeline"] = "Ability timeline"
L["Timeline"] = "Timeline"
L["Right: casts in each lane"] = "Right: casts in each lane"
L["Casts"] = "Casts"
L["By ability"] = "By ability"
L["Zoom in (or Ctrl+mouse wheel up)"] = "Zoom in (or Ctrl+mouse wheel up)"
L["Zoom out (or Ctrl+mouse wheel down)"] = "Zoom out (or Ctrl+mouse wheel down)"
L["Mouse controls"] = "Mouse controls"
L["Mouse wheel: scroll up and down"] = "Mouse wheel: scroll up and down"
L["Shift+mouse wheel: scroll left and right (zoomed in)"] = "Shift+mouse wheel: scroll left and right (zoomed in)"
L["Ctrl+mouse wheel: zoom in and out"] = "Ctrl+mouse wheel: zoom in and out"
L["Reset zoom"] = "Reset zoom"
L["Scroll left, toward 0:00 (or Shift+mouse wheel up)"] = "Scroll left, toward 0:00 (or Shift+mouse wheel up)"
L["Scroll right, toward the end (or Shift+mouse wheel down)"] =
    "Scroll right, toward the end (or Shift+mouse wheel down)"
L["%sx"] = "%sx"
L["No casts recorded"] = "No casts recorded"
L["Too many casts here for %d rows: this icon overlaps others."] =
    "Too many casts here for %d rows: this icon overlaps others."
L["No run to compare with"] = "No run to compare with"
L["No run to compare with: the blue lanes stay empty."] = "No run to compare with: the blue lanes stay empty."
L["%s has no casts recorded: the blue lanes stay empty."] = "%s has no casts recorded: the blue lanes stay empty."
L["Select a run in the Results window to see its timeline."] = "Select a run in the Results window to see its timeline."
L["No casts recorded for this run."] = "No casts recorded for this run."
L["Cooldown %s"] = "Cooldown %s"
L["%s cooldown"] = "%s cooldown"
L["%s: 1 cast"] = "%s: 1 cast"
L["%s: %d casts"] = "%s: %d casts"
L["Open the ability timeline: every cast of this run beside the run it is compared with."] =
    "Open the ability timeline: every cast of this run beside the run it is compared with."
L["No casts recorded for this run: it was raced before casts were kept, or resumed after a reload."] =
    "No casts recorded for this run: it was raced before casts were kept, or resumed after a reload."

-- The run detail's gear and talents (modules/Results_Loadout.lua, #6) and their tooltips
L["Gear"] = "Gear"
L["Talents"] = "Talents"
L["Not recorded"] = "Not recorded"
L["Unnamed loadout"] = "Unnamed loadout"
L["Talent loadout"] = "Talent loadout"
L["Gear view"] = "Gear view"
L["View"] = "View"
L["Copy"] = "Copy"
L["Different loadout"] = "Different loadout"
L["Empty"] = "Empty"
L["1 item equipped when combat ended."] = "1 item equipped when combat ended."
L["%d items equipped when combat ended."] = "%d items equipped when combat ended."
L["Hover an item for its tooltip; Shift-click links it in chat."] =
    "Hover an item for its tooltip; Shift-click links it in chat."
L["This run has no gear or talents: it was raced before the addon recorded them, or the client could not read them."] =
    "This run has no gear or talents: it was raced before the addon recorded them, or the client could not read them."
L["Nothing was equipped in this slot."] = "Nothing was equipped in this slot."
L["The run's gear and stats, laid out as the character panel does, against the run the detail compares with."] =
    "The run's gear and stats, laid out as the character panel does, against the run the detail compares with."
L["Hero talents: %s"] = "Hero talents: %s"
L["The talent loadout the run was raced with."] = "The talent loadout the run was raced with."
L["Open the run's talent tree, read-only, and post its link to your chat window to open again later."] =
    "Open the run's talent tree, read-only, and post its link to your chat window to open again later."
L["Only you see the link: nothing is sent to a channel."] = "Only you see the link: nothing is sent to a channel."
L["this run"] = "this run"
L["Talents for %s: %s \226\128\148 click the link to view the tree."] =
    "Talents for %s: %s \226\128\148 click the link to view the tree."

-- The gear view (modules/Results_Gear.lua, #17) and the stats it shows (modules/Stats.lua)
L["vs %s"] = "vs %s"
L["Changed: %s wore %s."] = "Changed: %s wore %s."
L["Changed: %s had nothing here."] = "Changed: %s had nothing here."
L["The enchant differs from %s's."] = "The enchant differs from %s's."
L["The gems differ from %s's."] = "The gems differ from %s's."
L["Higher item level than %s's."] = "Higher item level than %s's."
L["Lower item level than %s's."] = "Lower item level than %s's."
L["Stats were not recorded for this run."] = "Stats were not recorded for this run."
L["Primary"] = "Primary"
L["Secondary"] = "Secondary"
L["Tertiary"] = "Tertiary"
L["Primary stat"] = "Primary stat"
L["Strength"] = "Strength"
L["Agility"] = "Agility"
L["Intellect"] = "Intellect"
L["Stamina"] = "Stamina"
L["Armor"] = "Armor"
L["Critical Strike"] = "Critical Strike"
L["Haste"] = "Haste"
L["Mastery"] = "Mastery"
L["Versatility"] = "Versatility"
L["Leech"] = "Leech"
L["Avoidance"] = "Avoidance"
L["Speed"] = "Speed"
L["Spell breakdown"] = "Spell breakdown"
L["Each spell's damage and its share of the run's, highest first. Compare sets them beside another run's."] =
    "Each spell's damage and its share of the run's, highest first. Compare sets them beside another run's."
L["No note"] = "No note"
L["This run has no note. Add one from its detail or the row's right-click menu."] =
    "This run has no note. Add one from its detail or the row's right-click menu."
L["The note you kept with the run. Click to sort."] = "The note you kept with the run. Click to sort."
L["This run has no talent string to open."] = "This run has no talent string to open."
L["The game has changed how it saves talents since this run: its loadout no longer opens. Copy still works."] =
    "The game has changed how it saves talents since this run: its loadout no longer opens. Copy still works."
L["The loadout's import string, to paste into the talent frame, Wowhead or Raidbots."] =
    "The loadout's import string, to paste into the talent frame, Wowhead or Raidbots."
L["The talents differ from %s's."] = "The talents differ from %s's."
L["Copy both strings to see the difference node by node."] = "Copy both strings to see the difference node by node."
L["Changed: the other run had nothing here."] = "Changed: the other run had nothing here."
L["Changed: the other run wore %s."] = "Changed: the other run wore %s."
L["the other run"] = "the other run"

-- The Spec cell's loadout lines and the share's talents link (#6)
L["Gear and talents: not recorded"] = "Gear and talents: not recorded"
L["Talents: %s"] = "Talents: %s"
L["Gear changed since the previous run"] = "Gear changed since the previous run"
L["Sharing"] = "Sharing"
L["Include talents link"] = "Include talents link"
L["Add the run's talent loadout to the shared line as a link others can click to see the talent tree. When the line and the link would be too long for one chat message, the link follows as a second one."] =
    "Add the run's talent loadout to the shared line as a link others can click to see the talent tree. When the line and the link would be too long for one chat message, the link follows as a second one."
-- What was used (#13): the food buff's name, matched against the helpful auras at the arm
-- (modules/Usage.lua).
L["Well Fed"] = "Well Fed"

-- The Runs list's Used column and the run detail's Usage section (#13, modules/Results_Usage.lua)
L["x%d %s"] = "x%d %s"
L["active at the start"] = "active at the start"
L["x%d, time unknown"] = "x%d, time unknown"
L["time unknown"] = "time unknown"
L["Item %d"] = "Item %d"
L["Usage"] = "Usage"
L["Nothing to list: no on-use item or consumable was found at the arm."] =
    "Nothing to list: no on-use item or consumable was found at the arm."
L["Used"] = "Used"
L["This run was raced before the addon recorded what was used."] =
    "This run was raced before the addon recorded what was used."
L["Nothing used"] = "Nothing used"
L["No on-use item or consumable was detected or ticked for this run."] =
    "No on-use item or consumable was detected or ticked for this run."
L["1 item used"] = "1 item used"
L["%d items used"] = "%d items used"
L["%s: %s"] = "%s: %s"
L["Edit the list in the run's detail."] = "Edit the list in the run's detail."
L["What the run used: on-use gear (trinkets first), then potions, flasks, food and the rest. Hover for when; sorted by how many."] =
    "What the run used: on-use gear (trinkets first), then potions, flasks, food and the rest. Hover for when; sorted by how many."
L["Detected from its cast during the race."] = "Detected from its cast during the race."
L["Detected from the bag count after the race."] = "Detected from the bag count after the race."
L["Its buff was on when the race was armed."] = "Its buff was on when the race was armed."
L["Ticked by you."] = "Ticked by you."
L["What this run used. Edit lists every on-use item and consumable you had at the arm, what was used ticked; tick or untick, then Save."] =
    "What this run used. Edit lists every on-use item and consumable you had at the arm, what was used ticked; tick or untick, then Save."
L["Casts, bag counts and the buffs at the arm are the clues. Hidden items are never listed (History settings, Usage tab)."] =
    "Casts, bag counts and the buffs at the arm are the clues. Hidden items are never listed (History settings, Usage tab)."
L["No on-use item or consumable was detected or ticked for this run. Edit to tick what you used."] =
    "No on-use item or consumable was detected or ticked for this run. Edit to tick what you used."
L["Edit"] = "Edit"
L["Leave the edit without saving."] = "Leave the edit without saving."
L["Tick or untick every on-use item and consumable you had at the arm. Right-click an item to never show it."] =
    "Tick or untick every on-use item and consumable you had at the arm. Right-click an item to never show it."
L["Right-click: never show this item."] = "Right-click: never show this item."
L["Never show %s"] = "Never show %s"
L["No on-use item or consumable was found at the arm, and nothing was detected."] =
    "No on-use item or consumable was found at the arm, and nothing was detected."
L["Keep the ticks as this run's usage. An entry the addon detected keeps its times."] =
    "Keep the ticks as this run's usage. An entry the addon detected keeps its times."
L["Not used: tick it if you did use it."] = "Not used: tick it if you did use it."

-- The Insights tab (#12, modules/Results_Insights.lua): the filter bar, the cards, the sections.
L["%s \194\183 %s \194\183 %s"] = "%s \194\183 %s \194\183 %s"
L["%dh %02dm"] = "%dh %02dm"
L["%dm %02ds"] = "%dm %02ds"
L["Races run"] = "Races run"
L["The runs these filters pass."] = "The runs these filters pass."
L["Time raced"] = "Time raced"
L["The race lengths added up; an incomplete run counts its time in combat."] =
    "The race lengths added up; an incomplete run counts its time in combat."
L["Best DPS"] = "Best DPS"
L["No complete run in these filters."] = "No complete run in these filters."
L["Avg DPS"] = "Avg DPS"
L["The complete runs' average, all on one board."] = "The complete runs' average, all on one board."
L["Avg % of board best"] = "Avg % of board best"
L["Each complete run against the best on its own board (spec, target and length), averaged."] =
    "Each complete run against the best on its own board (spec, target and length), averaged."
L["Clean runs"] = "Clean runs"
L["%d of %d runs carry no flag."] = "%d of %d runs carry no flag."
L["Late casts on the ignore list do not flag a run."] = "Late casts on the ignore list do not flag a run."
L["New bests set"] = "New bests set"
L["Runs that beat an earlier best on their board, within these filters. A board's first run does not count."] =
    "Runs that beat an earlier best on their board, within these filters. A board's first run does not count."
L["Characters"] = "Characters"
L["The characters with a run in these filters."] = "The characters with a run in these filters."
L["Specs"] = "Specs"
L["The specs with a run in these filters."] = "The specs with a run in these filters."
L["Active days"] = "Active days"
L["%s to %s"] = "%s to %s"
L["Date range"] = "Date range"
L["%d days with a run."] = "%d days with a run."
L["%s of board best"] = "%s of board best"
L["Avg %s DPS"] = "Avg %s DPS"
L["Avg %s of board best"] = "Avg %s of board best"
L["DPS Progression"] = "DPS Progression"
L["DPS Progression (% of board best)"] = "DPS Progression (% of board best)"
L["Best %s DPS"] = "Best %s DPS"
L["Worst %s DPS"] = "Worst %s DPS"
L["Spread (CV) %s"] = "Spread (CV) %s"
L["%s: %d"] = "%s: %d"
L["%s (ignored)"] = "%s (ignored)"
L["On the ignore list: no flag. Right-click to stop ignoring it."] =
    "On the ignore list: no flag. Right-click to stop ignoring it."
L["No spell ID was recorded, so it cannot be ignored."] = "No spell ID was recorded, so it cannot be ignored."
L["Each one flags its run. Right-click to ignore it."] = "Each one flags its run. Right-click to ignore it."
L["%d-%d s"] = "%d-%d s"
L["%d+ s"] = "%d+ s"
L["Damage still landing after the buzzer, and counted."] = "Damage still landing after the buzzer, and counted."
L["%s  %s"] = "%s  %s"
L["%s DPS, up from %s"] = "%s DPS, up from %s"
L["Click to open the run \194\183 right-click for options"] = "Click to open the run \194\183 right-click for options"
L["Insights view saved as default."] = "Insights view saved as default."
L["Insights view reset to stock defaults."] = "Insights view reset to stock defaults."
L["Clean only"] = "Clean only"
L["By Target \195\151 Length"] = "By Target \195\151 Length"
L["Spec Comparison"] = "Spec Comparison"
L["Consistency"] = "Consistency"
L["Races By Character"] = "Races By Character"
L["Races By Character \195\151 Target"] = "Races By Character \195\151 Target"
L["Races By Character \195\151 Length"] = "Races By Character \195\151 Length"
L["Races Per Day"] = "Races Per Day"
L["Damage Tail After The Buzzer"] = "Damage Tail After The Buzzer"
L["Late Casts"] = "Late Casts"
L["Recent New Bests"] = "Recent New Bests"
L["Save these filters as this profile's default view of Insights."] =
    "Save these filters as this profile's default view of Insights."
L["Delete the saved view and go back to the stock one: every character, spec, target, length and date."] =
    "Delete the saved view and go back to the stock one: every character, spec, target, length and date."

-- Your training dummies (#9): the Race page's Training dummies tab and /dr targetdummy.
L["Training dummies"] = "Training dummies"
L["Automatic"] = "Automatic"
L["New dummies"] = "New dummies"
L["Category for new dummies"] = "Category for new dummies"
L["The category a dummy you add gets when you name none. Automatic reads it from the name (Cleave, Dungeoneer, PvP) and a boss-level creature, else Single target."] =
    "The category a dummy you add gets when you name none. Automatic reads it from the name (Cleave, Dungeoneer, PvP) and a boss-level creature, else Single target."
L["Your training dummies"] = "Your training dummies"
L["Creatures counted as training dummies beyond the built-in ones, and built-ins switched off: creature ID:category, or -creature ID, comma-separated. Applies to every stored run: a run is categorized by its creature as the list is now."] =
    "Creatures counted as training dummies beyond the built-in ones, and built-ins switched off: creature ID:category, or -creature ID, comma-separated. Applies to every stored run: a run is categorized by its creature as the list is now."

-- /dr targetdummy (#9): show, add, remove, capture, defaults.
L["Your training dummies: /dr targetdummy [show|add|remove|capture|defaults] [category or creature ID]"] =
    "Your training dummies: /dr targetdummy [show|add|remove|capture|defaults] [category or creature ID]"
L["Usage: %s targetdummy [show|add|remove|capture|defaults] [category or creature ID]"] =
    "Usage: %s targetdummy [show|add|remove|capture|defaults] [category or creature ID]"
L["Creature %d"] = "Creature %d"
L["skull level"] = "skull level"
L["level %d"] = "level %d"
L["%s %s"] = "%s %s"
L["%s health"] = "%s health"
L["PvP flagged"] = "PvP flagged"
L["not PvP flagged"] = "not PvP flagged"
L["%s, %s"] = "%s, %s"
L["%s %.1f, %.1f"] = "%s %.1f, %.1f"
L["Target a creature first."] = "Target a creature first."
L["Your target is not a creature, so it cannot be a training dummy."] =
    "Your target is not a creature, so it cannot be a training dummy."
L["No training dummies of your own. Target one and type %s targetdummy add."] =
    "No training dummies of your own. Target one and type %s targetdummy add."
L["Your training dummies:"] = "Your training dummies:"
L["  %s \194\183 %s"] = "  %s \194\183 %s"
L["Built-in training dummies: %d, %d switched off."] = "Built-in training dummies: %d, %d switched off."
L["  %s (off)"] = "  %s (off)"
L["Saved: %s"] = "Saved: %s"
L["'%s' is no category. Use single, cleave, dungeoneer, boss or pvp."] =
    "'%s' is no category. Use single, cleave, dungeoneer, boss or pvp."
L["%s is a training dummy now: %s."] = "%s is a training dummy now: %s."
L["%s is a training dummy again: %s."] = "%s is a training dummy again: %s."
L["%s is already a built-in training dummy: %s."] = "%s is already a built-in training dummy: %s."
L["%s is already a training dummy: %s."] = "%s is already a training dummy: %s."
L["No creature '%s' is known. Use its creature ID."] = "No creature '%s' is known. Use its creature ID."
L["%s is no longer a training dummy."] = "%s is no longer a training dummy."
L["%s, a built-in training dummy, is switched off. %s targetdummy add on it brings it back."] =
    "%s, a built-in training dummy, is switched off. %s targetdummy add on it brings it back."
L["%s is not a training dummy."] = "%s is not a training dummy."
L["Your training dummies are cleared: only the built-in ones count."] =
    "Your training dummies are cleared: only the built-in ones count."

-- The Race page's Training dummies tab (#9).
L["\194\183 %s"] = "\194\183 %s"
L["Creatures a race counts as training dummies, on top of the built-in ones: auto-arm, the HUD and the target type of every stored run follow this list. Target a dummy and click Add your target, or type /dr targetdummy add; either saves what the game says about it."] =
    "Creatures a race counts as training dummies, on top of the built-in ones: auto-arm, the HUD and the target type of every stored run follow this list. Target a dummy and click Add your target, or type /dr targetdummy add; either saves what the game says about it."
L["Add your target"] = "Add your target"
L["Count your target as a training dummy, with the category above, and save what the game says about it (its level, health, zone and where you stand). A built-in that is switched off is switched back on."] =
    "Count your target as a training dummy, with the category above, and save what the game says about it (its level, health, zone and where you stand). A built-in that is switched off is switched back on."
L["Add a creature"] = "Add a creature"
L["A creature ID, or the name of a creature you captured. It gets the category above."] =
    "A creature ID, or the name of a creature you captured. It gets the category above."
L["No training dummies of your own yet."] = "No training dummies of your own yet."
L["Built-in training dummies. Clear one to stop counting it as a dummy."] =
    "Built-in training dummies. Clear one to stop counting it as a dummy."
L["%s (%d) \194\183 %s"] = "%s (%d) \194\183 %s"
L["Count this built-in as a training dummy. Cleared, its runs read as Other."] =
    "Count this built-in as a training dummy. Cleared, its runs read as Other."
L["Remove your own training dummies and switch every built-in back on. The category for new dummies is not touched."] =
    "Remove your own training dummies and switch every built-in back on. The category for new dummies is not touched."
L["Restore every Race setting on this profile to its addon default, the late-cast ignore list and your training dummies among them."] =
    "Restore every Race setting on this profile to its addon default, the late-cast ignore list and your training dummies among them."

-- The skin (skinning-§2/§3, core/SkinSetup.lua; General > Skin). The tab's own words are the library's.
L["Skin source"] = "Skin source"
L["Where this addon's look comes from: the Ka0s skin chosen below, or EllesmereUI."] =
    "Where this addon's look comes from: the Ka0s skin chosen below, or EllesmereUI."
L["Skin"] = "Skin"
L["The Ka0s skin this addon wears. Changes every window and panel right away."] =
    "The Ka0s skin this addon wears. Changes every window and panel right away."
L["Ignore settings panel"] = "Ignore settings panel"
L["Keep this addon's settings panel in the game's own look. Its windows still wear the skin."] =
    "Keep this addon's settings panel in the game's own look. Its windows still wear the skin."
L["Ignore fonts"] = "Ignore fonts"
L["Keep every font in this addon as the game draws it. The skin still colors the text."] =
    "Keep every font in this addon as the game draws it. The skin still colors the text."
L["Font"] = "Font"
L["The font this addon's text uses, over the skin's own. Empty keeps the skin's."] =
    "The font this addon's text uses, over the skin's own. Empty keeps the skin's."
L["Texture"] = "Texture"
L["The texture this addon's bars use, over the skin's own. Empty keeps the skin's."] =
    "The texture this addon's bars use, over the skin's own. Empty keeps the skin's."
L["Font outline"] = "Font outline"
L["Where the skin outlines this addon's text: all of it, its HUD text only, or nowhere."] =
    "Where the skin outlines this addon's text: all of it, its HUD text only, or nowhere."
L["Skin picker seen"] = "Skin picker seen"
L["Whether the first-run skin picker was closed on this profile."] =
    "Whether the first-run skin picker was closed on this profile."
L["Reload your interface (/reload) to finish changing the skin."] =
    "Reload your interface (/reload) to finish changing the skin."

-- The Race HUD tooltips (modules/Hud_Tips.lua, DR-F04)
L["How long the next race runs. Pick a preset or Custom; the choice stays for your next race."] =
    "How long the next race runs. Pick a preset or Custom; the choice stays for your next race."
L["Race for this long. Your bests are kept per race length, so each length has its own."] =
    "Race for this long. Your bests are kept per race length, so each length has its own."
L["Set a race length of your own. Click, then type it in."] = "Set a race length of your own. Click, then type it in."
L["Custom length"] = "Custom length"
L["Type a length from 10 seconds to 15 minutes, such as 90, 1:30 or 3m, then press Enter. Escape backs out."] =
    "Type a length from 10 seconds to 15 minutes, such as 90, 1:30 or 3m, then press Enter. Escape backs out."
L["The training dummy you have targeted, its dummy type and its NPC ID. The type decides which board the run counts on."] =
    "The training dummy you have targeted, its dummy type and its NPC ID. The type decides which board the run counts on."
L["Get this race ready. The clock starts on your first hit. When you can't arm, the line under this button says why."] =
    "Get this race ready. The clock starts on your first hit. When you can't arm, the line under this button says why."
L["Open the Results window: your runs, your bests and Insights."] = "Open the Results window: your runs, your bests and Insights."
L["The length of this race. It starts counting down when your first hit lands."] =
    "The length of this race. It starts counting down when your first hit lands."
L["First hit"] = "First hit"
L["Nothing counts until your damage lands, so pre-cast and pre-pot as you would on a pull."] =
    "Nothing counts until your damage lands, so pre-cast and pre-pot as you would on a pull."
L["The race's clock. HUD > Race clock picks what shows here."] = "The race's clock. HUD > Race clock picks what shows here."
L["How long this race has run."] = "How long this race has run."
L["How long until the buzzer."] = "How long until the buzzer."
L["Your damage so far this race, as the damage meter reports it."] =
    "Your damage so far this race, as the damage meter reports it."
L["Your damage per second so far this race, as the damage meter reports it."] =
    "Your damage per second so far this race, as the damage meter reports it."
L["How your damage built up over the race. Each column is one slice of time. The line is your best's pace where you have one, and icons mark your cooldowns: hover one for the spell."] =
    "How your damage built up over the race. Each column is one slice of time. The line is your best's pace where you have one, and icons mark your cooldowns: hover one for the spell."
L["Your damage against your best's average at this point in the race. The tick in the middle is on pace: green is ahead of it, red behind."] =
    "Your damage against your best's average at this point in the race. The tick in the middle is on pace: green is ahead of it, red behind."
L["This run's final damage against the best you had before it. The tick in the middle is level with that best: green is ahead of it, red behind."] =
    "This run's final damage against the best you had before it. The tick in the middle is level with that best: green is ahead of it, red behind."
L["Your spells in this race. Hover a row for the spell. With Spell rows shown at 0, the mouse wheel scrolls the list."] =
    "Your spells in this race. Hover a row for the spell. With Spell rows shown at 0, the mouse wheel scrolls the list."
L["This run's spells, highest damage first, with each one's share. Hover a row for the spell and its figures. With Spell rows shown at 0, the mouse wheel scrolls the list."] =
    "This run's spells, highest damage first, with each one's share. Hover a row for the spell and its figures. With Spell rows shown at 0, the mouse wheel scrolls the list."
L["Live order"] = "Live order"
L["Spells stay in the damage meter's order while the race runs. Each one's share appears on the result."] =
    "Spells stay in the damage meter's order while the race runs. Each one's share appears on the result."
L["Spell rows"] = "Spell rows"
L["How many spell rows are drawn. HUD > Spell rows shown sets it."] =
    "How many spell rows are drawn. HUD > Spell rows shown sets it."
L["The buzzer has gone: stop casting. Damage still landing counts, but a cast that starts after the grace flags the run."] =
    "The buzzer has gone: stop casting. Damage still landing counts, but a cast that starts after the grace flags the run."
L["How long after the buzzer your last damage landed, as far as the race has seen."] =
    "How long after the buzzer your last damage landed, as far as the race has seen."
L["Combat ended before the buzzer, this far into the race, so the run is incomplete."] =
    "Combat ended before the buzzer, this far into the race, so the run is incomplete."
L["How long you have stayed in combat since the buzzer. The result is read when combat ends."] =
    "How long you have stayed in combat since the buzzer. The result is read when combat ends."
L["Combat is over, so the result can be read."] = "Combat is over, so the result can be read."
L["Result pending"] = "Result pending"
L["The damage meter can only be read once combat ends, so the result waits for that. Stop Now takes it as soon as it can."] =
    "The damage meter can only be read once combat ends, so the result waits for that. Stop Now takes it as soon as it can."
L["Casts that started after the grace. The result flags them unless the spell is on the ignore list."] =
    "Casts that started after the grace. The result flags them unless the spell is on the ignore list."
L["How long after the buzzer a cast may start before it is flagged. Set it on the Race settings page."] =
    "How long after the buzzer a cast may start before it is flagged. Set it on the Race settings page."
L["This run's total damage."] = "This run's total damage."
L["This run's damage per second."] = "This run's damage per second."
L["This run beat your best on this board, by this much."] = "This run beat your best on this board, by this much."
L["This run sets the best on this board: there was no earlier DPS to beat."] =
    "This run sets the best on this board: there was no earlier DPS to beat."
L["How far this run fell short of your best on this board."] = "How far this run fell short of your best on this board."
L["This run matched your best on this board."] = "This run matched your best on this board."
L["Back to the Arm Race screen at this length. This run stays saved."] =
    "Back to the Arm Race screen at this length. This run stays saved."
L["Open this run in the Results window."] = "Open this run in the Results window."
L["Pick a chat channel and post this run's result there."] = "Pick a chat channel and post this run's result there."
L["Close"] = "Close"
L["Close the race window. A race in progress keeps running; a result card is dismissed and its run stays saved."] = "Close the race window. A race in progress keeps running; a result card is dismissed and its run stays saved."
L["The spec and character this race counts for."] = "The spec and character this race counts for."
L["Your item level. During a race, how often the figures refresh; after it, whether the result is still pending."] =
    "Your item level. During a race, how often the figures refresh; after it, whether the result is still pending."
