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
L["Restore every General setting on this profile to its addon default, including the Race HUD's live breakdown and HUD Appearance."] =
    "Restore every General setting on this profile to its addon default, including the Race HUD's live breakdown and HUD Appearance."

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
L["Targets"] = "Targets"
L["1 target"] = "1 target"
L["%d targets"] = "%d targets"
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
L["Discard Run"] = "Discard Run"
L["Close (Keep Waiting)"] = "Close (Keep Waiting)"
L["Waiting for combat to end"] = "Waiting for combat to end"
L["Reading the result"] = "Reading the result"
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
L["Note: %s"] = "Note: %s"
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

-- General page: the Race HUD tab (settings/General.lua): Display, then Live breakdown
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
L["%+.1f%%"] = "%+.1f%%"
L["%.1f%%"] = "%.1f%%"
L["vs Best"] = "vs Best"
L["Best"] = "Best"
L["Complete"] = "Complete"
L["Flagged"] = "Flagged"
L["Incomplete"] = "Incomplete"
L["%s / %s"] = "%s / %s"
L["Time %s"] = "Time %s"
L["The race length, then how long your damage kept landing after the buzzer (DoTs, travel time). An incomplete run shows its time in combat against the length."] =
    "The race length, then how long your damage kept landing after the buzzer (DoTs, travel time). An incomplete run shows its time in combat against the length."
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

-- General page: the Race HUD tab's Live breakdown subsection (settings/General.lua)
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

-- History page (settings/History.lua)
L["History"] = "History"
L["Storage"] = "Storage"
L["Runs to keep"] = "Runs to keep"
L["Account-wide: shared by every profile. 0 keeps every run (the default). Above 0, the oldest runs are removed first, at login and after each saved run, and a run that holds a personal best is always kept. 0 to 10000."] =
    "Account-wide: shared by every profile. 0 keeps every run (the default). Above 0, the oldest runs are removed first, at login and after each saved run, and a run that holds a personal best is always kept. 0 to 10000."
L["Stored now: %d runs (about %d KB of saved variables)."] = "Stored now: %d runs (about %d KB of saved variables)."
L["Purge history\226\128\166"] = "Purge history\226\128\166"
L["Deletes every stored run. Asks for confirmation. Personal bests go with them."] =
    "Deletes every stored run. Asks for confirmation. Personal bests go with them."
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
L["Test mode: sample numbers. Combat or Arm ends it"] = "Test mode: sample numbers. Combat or Arm ends it"
L["DPS Race \194\183 Test"] = "DPS Race \194\183 Test"
L["Training Dummy"] = "Training Dummy"
