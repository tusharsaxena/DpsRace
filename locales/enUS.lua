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
L["Shows or hides the Results window, with its run history and personal bests."] =
    "Shows or hides the Results window, with its run history and personal bests."
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
L["Restore every General setting on this profile to its addon default: Master controls."] =
    "Restore every General setting on this profile to its addon default: Master controls."

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
L["s after buzzer"] = "s after buzzer"
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
L["Race Again"] = "Race Again"
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
L["Bests"] = "Bests"
L["Click a row for details \194\183 right-click for options"] =
    "Click a row for details \194\183 right-click for options"
L["Days to keep: %d"] = "Days to keep: %d"
L["Days to keep: 0 (never prune)"] = "Days to keep: 0 (never prune)"
L["Delete this run? This cannot be undone, and a personal best it holds goes with it."] =
    "Delete this run? This cannot be undone, and a personal best it holds goes with it."
L["Delete"] = "Delete"
L["Cancel"] = "Cancel"
L["Unknown class"] = "Unknown class"
L["%d late"] = "%d late"
L["Restarted"] = "Restarted"
L["By list"] = "By list"
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
L["Class \194\183 Spec"] = "Class \194\183 Spec"
L["Character"] = "Character"
L["iLvl"] = "iLvl"
L["No runs match these filters."] = "No runs match these filters."
L["1 run"] = "1 run"
L["%d runs"] = "%d runs"
L["%s started +%.1fs after the buzzer"] = "%s started +%.1fs after the buzzer"
L["%s (grace %.1fs)."] = "%s (grace %.1fs)."
L["%s, after the quiet gap."] = "%s, after the quiet gap."
L["Session matched by list: the meter session was found by its place in Blizzard's list, not by its ID."] =
    "Session matched by list: the meter session was found by its place in Blizzard's list, not by its ID."
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
L["Flag \194\183 %s"] = "Flag \194\183 %s"
L["Flags \194\183 %d"] = "Flags \194\183 %d"
L["Edit Note"] = "Edit Note"
L["Combat ended at %s, before the buzzer."] = "Combat ended at %s, before the buzzer."
L["Damage stopped %ss after the buzzer"] = "Damage stopped %ss after the buzzer"
L["combat ended %ss"] = "combat ended %ss"
L["0:00 \226\128\148 race %s \226\128\148 buzzer"] = "0:00 \226\128\148 race %s \226\128\148 buzzer"
L["+%ds"] = "+%ds"
L["Category: %s"] = "Category: %s"
L["Flags"] = "Flags"
L["Clean runs only"] = "Clean runs only"
L["Best per spec \195\151 category \195\151 race length, all characters"] =
    "Best per spec \195\151 category \195\151 race length, all characters"
L["No personal bests yet: finish a race to set one."] = "No personal bests yet: finish a race to set one."
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
L["Restore Days to keep and the Results table's look to their addon defaults. Stored runs are not touched."] =
    "Restore Days to keep and the Results table's look to their addon defaults. Stored runs are not touched."
L["Results table"] = "Results table"
L["Damage bar"] = "Damage bar"
L["DPS bar"] = "DPS bar"
L["Bar text"] = "Bar text"
L["The run still counts and the flag shows on the board."] =
    "The run still counts and the flag shows on the board."

-- Key bindings: the Arm or cancel key (core/LauncherSetup.lua, core/DpsRace.lua)
L["Arm or cancel race"] = "Arm or cancel race"
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
L["Sample data in the HUD and the Results window: /dr test [armed|running|result]"] = "Sample data in the HUD and the Results window: /dr test [armed|running|result]"
L["Play a whole sample race: /dr sim [%s]"] = "Play a whole sample race: /dr sim [%s]"
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

-- HUD page: the Race HUD tab (settings/Hud.lua): Display, then Live breakdown
L["Race HUD"] = "Race HUD"
L["Display"] = "Display"
L["Show the race HUD"] = "Show the race HUD"
L["When a race is armed"] = "When a race is armed"
L["Always"] = "Always"
L["When a race is armed: the HUD opens when you arm a race or a result arrives, and closes again when that race is over. Always: it is open from login. General visibility on Master controls still applies: while it hides the addon, the HUD stays hidden whatever this says."] =
    "When a race is armed: the HUD opens when you arm a race or a result arrives, and closes again when that race is over. Always: it is open from login. General visibility on Master controls still applies: while it hides the addon, the HUD stays hidden whatever this says."
L["Race clock"] = "Race clock"
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
L["Sticky-combat hint after (seconds)"] = "Sticky-combat hint after (seconds)"
L["How long combat may hold after the buzzer before the HUD suggests ways to drop it. 5 to 60 seconds."] =
    "How long combat may hold after the buzzer before the HUD suggests ways to drop it. 5 to 60 seconds."
L["Restore every Race setting on this profile to its addon default."] =
    "Restore every Race setting on this profile to its addon default."
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
L["Mark each cast of an ability with a cooldown over 15 seconds (your big cooldowns, trinkets and potions) with its icon along the top of the damage chart: live on the HUD, on the result card and in the Results window. Hover an icon for the spell and its time."] =
    "Mark each cast of an ability with a cooldown over 15 seconds (your big cooldowns, trinkets and potions) with its icon along the top of the damage chart: live on the HUD, on the result card and in the Results window. Hover an icon for the spell and its time."
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
L["Clean run"] = "Clean run"
L["No flags: nothing happened that the result should mention."] =
    "No flags: nothing happened that the result should mention."
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
L["An icon along the top marks each cast of an ability with a cooldown over 15 seconds. Hover it for the spell and its time."] =
    "An icon along the top marks each cast of an ability with a cooldown over 15 seconds. Hover it for the spell and its time."
-- A cast's tooltip: a cooldown icon on the damage chart, a timeline tick (#14)
L["%s (pet)"] = "%s (pet)"
L["Cast at %s"] = "Cast at %s"

-- The ability timeline (#14, modules/Results_Timeline.lua), its button in the run detail and their tooltips
L["Ability timeline"] = "Ability timeline"
L["Timeline"] = "Timeline"
L["Right: casts in each lane"] = "Right: casts in each lane"
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
L["Dressing Room"] = "Dressing Room"
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
L["Try the run's gear on in the Dressing Room."] = "Try the run's gear on in the Dressing Room."
L["Hero talents: %s"] = "Hero talents: %s"
L["The talent loadout the run was raced with."] = "The talent loadout the run was raced with."
L["Open the run's talent tree, read-only, and post its link to your chat window to open again later."] =
    "Open the run's talent tree, read-only, and post its link to your chat window to open again later."
L["Only you see the link: nothing is sent to a channel."] = "Only you see the link: nothing is sent to a channel."
L["this run"] = "this run"
L["Talents for %s: %s \226\128\148 click the link to view the tree."] =
    "Talents for %s: %s \226\128\148 click the link to view the tree."
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
L["Weapon enchant (main hand)"] = "Weapon enchant (main hand)"
L["Weapon enchant (off hand)"] = "Weapon enchant (off hand)"
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
L["On the weapon when the race was armed."] = "On the weapon when the race was armed."
L["Ticked by you."] = "Ticked by you."
L["Every on-use item and consumable you had at the arm. What was detected starts ticked; tick or untick, then Save."] =
    "Every on-use item and consumable you had at the arm. What was detected starts ticked; tick or untick, then Save."
L["Casts, bag counts and the buffs at the arm are the clues; a weapon oil shows as its enchant."] =
    "Casts, bag counts and the buffs at the arm are the clues; a weapon oil shows as its enchant."
L["No on-use item or consumable was found at the arm, and nothing was detected."] =
    "No on-use item or consumable was found at the arm, and nothing was detected."
L["Keep the ticks as this run's usage. An entry the addon detected keeps its times."] =
    "Keep the ticks as this run's usage. An entry the addon detected keeps its times."
L["Not used: tick it if you did use it."] = "Not used: tick it if you did use it."
L["Enchant %d"] = "Enchant %d"
