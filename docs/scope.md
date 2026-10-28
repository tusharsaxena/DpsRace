# Scope

What Ka0s DPS Race is for, and what it deliberately leaves out. The decisions behind both halves are
in the spec, sections 1, 2 and 13
([`superpowers/specs/2026-10-23-dps-race-pve-design.md`](superpowers/specs/2026-10-23-dps-race-pve-design.md)).

## What it does (v0.1.0)

- **A timed race.** The most damage in a chosen time (presets 0:30 to 5:00, custom 0:10 to 15:00)
  against any target, with known training dummies recognized from a small catalog
  (`defaults/Dummies.lua`) and the player's own list. There is no target count (DpsRace#15).
- **A frame-accurate start.** The clock starts on the new meter session, which lands on the same
  frame as the first hit (spec §2, §4.2).
- **An honest score.** Damage is the run session's total, read after combat. DPS is that total
  divided by the race length, computed from the addon's own clock. Blizzard's own DPS is stored for
  reference and never ranked (spec §5.1).
- **Flags, never voids.** Casts started after the buzzer plus a grace, damage that restarts after a
  quiet gap, a reload mid-run, a session matched by list and a death after the buzzer all flag a
  run. Incomplete and lost runs are kept but never count
  toward bests (spec §5.4).
- **A late-cast ignore list** (#8). Spells cast after the buzzer that are not really part of the
  rotation (Invisibility, Vanish, Feign Death, every hearthstone, Shadowmeld and Greater
  Invisibility by default) never flag a run. The list is a per-profile setting read when a run's
  flags are built, never frozen into the run, so an edit re-scores every stored run. It is edited
  on the Race page, with `/dr ignore`, or by a right-click on a late cast in the result card, the
  run detail, a Runs row's menu or Insights' *Late Casts*.
- **A Race HUD** with one body per state, a **Results window** with history, run detail and an
  *Insights* tab, a one-line chat share, settings, a launcher, three key bindings, slash commands and a
  diagnostics report (spec §6). The Runs list names each run's status as a boxed badge (the tag
  alone; *Spec best* names the board it tops in its tooltip), colors each preset race
  length (the Results window only), and groups by *Full* (character, class, spec, target and time;
  a new profile's default), character, class and spec, target, time, target and time, or spec, target and time.
- **Insights** (#12, in place of the Bests tab). A summary of the runs across every character,
  filtered by character, spec, target, length and date (each list faceted by the others), clean
  only or with incomplete runs: ten stat cards, then DPS run by run, a tab per target and length
  with its spec comparison and consistency, races by character (alone, by target, by length) and
  per day, the damage tail after the buzzer, the late casts and the recent new bests. DPS is only
  compared within a board; anything that spans boards is each run's percent of its board's best.
- **Your own training dummies** (#9). `/dr targetdummy add [category]` (or the Race page's
  *Training dummies* tab) counts any creature as a dummy of a category, and a built-in can be switched
  off, never recategorized. The list is a per-profile setting read when a run's category is, so an
  edit recategorizes every stored run. Each add saves what the game says about the creature
  (`global.dummies.captures`), and the catalog grows from those captures, never from guesses.
- **Auto-show and auto-arm near a training dummy** (#16), both off by default. *Show near a
  training dummy* opens the HUD while a known dummy is the target or has a nameplate up; *Arm
  on a training dummy* arms a race on targeting one out of combat and cancels it if the target moves
  off the dummies before the pull. Neither acts in an instance.
- **Test mode and the sim** (spec §6.5, B5). `/dr test` shows static sample data in the HUD and the
  Results window; `/dr sim [scenario]` plays a whole sample race (arm, race, result, then Results)
  through seven scenarios. Both draw in-memory samples and write nothing to SavedVariables.
- **A live damage chart and a pace bar** (#2, #3). The running HUD draws one column per bucket of
  the race (at most 60), each the live total the meter showed at its boundary, scaled to the board's
  best x 1.15 with its level and its average-pace diagonal, or with no best to the live total. A pace
  bar runs either side of the best's average damage by now, its tick in the middle (*Pace bar range*,
  1.5 by default: ±50%). Both are visual only: no value is ever
  compared. The result card and the Results detail draw the chart again for runs raced this session,
  and the result card shows the pace bar again: the run's final damage against the best before it.
  After the race the chart draws that best's average-pace diagonal too, on a scale that covers both.
- **Compare two runs** (#7). The Results detail sets a run beside the best on its board (the
  runner-up for the best itself) or a run picked from the Runs row menu: damage, DPS, the %
  difference and every spell matched by ID.
- **The loadout behind each run** (#6). Every new run keeps its equipped gear (slots 1 to 18, no
  shirt or tabard) and its talent loadout, each distinct set stored once. The detail draws the gear
  grid with the client's item tooltips and the talents with *View* (opens the talent tree, and posts a clickable link to chat) and *Copy*; under the compare it
  highlights the changed slots and marks a different loadout.
- **The gear view and the stats behind each run** (#17; run-record format 4). Every new run keeps
  the stats read at arm (the primary stat, stamina, armor, and every secondary and tertiary as rating
  and percent). The detail's *Gear view* lays the gear out as the character panel does, without the
  model, with each item's level and its enchant and gem marks, and the stats in the middle, against the
  compared run: changed slots, item levels, enchants and gems marked, each stat's difference.
- **The new-best toast** (#5). A complete run that beats an earlier best on its board shows a toast
  near the top of the screen, whether or not the HUD is open: the spec and board, the time, the DPS
  and the gain over the old best, and the run's flags. A board's first run does not toast. It runs on
  LibKa0s-Toast-1.0 (one at a time, timed, paused under the pointer); General > *New-best toast* turns
  it off and sets its duration, sound and scale, and test mode places it.
- **Resilience to `/reload`.** A run is stored from its first hit, and a reload at any point resumes
  it, reads it later, or settles it as lost (spec §4.5).
- **What each run cast and used** (#13, #14; run-record format 3). Every cast of the player and the
  pet from the arm to the result is kept on the race clock with each spell's base cooldown, and the
  on-use gear and consumables used are worked out from those casts, the bag counts and the buffs at
  the arm. The Runs list's *Used* column shows them as icons, the detail lists what was used and,
  under *Edit*, every candidate for the player to correct and *Save*; items the player never wants
  listed go on a hidden list (History > *Usage*). The damage chart marks each cast of an ability
  with a cooldown of 29 s or more with its icon, and the detail's *Timeline* opens every ability's casts
  in two lanes, this run's beside the compared run's.
- **Account-wide history**, so bests span alts. Runs older than *Days to keep* (90 by default, 0
  never) are pruned at login and after each saved run, never one holding a best (spec §6.3, §7; the
  owner's call, 2026-10-26).

## What it deliberately does not do

| Not done | Why |
|---|---|
| Read the combat log | Addons cannot read it in 12.0. Every number comes from `C_DamageMeter`. |
| Cut damage off exactly at the buzzer | Values captured in combat stay secret after it, so the score is the session total and the tail is shown instead (spec §2). |
| Show percentages or sort the live breakdown | Both are arithmetic on secret values (spec §6.1). Percentages appear on the result. |
| Count targets | The meter merges identical dummies into one row and no nameplate signal counts the dummies hit, so there is no count at all, typed or measured; it returns only if the client can measure it (DpsRace#15). |
| Tab completion of `/dr sim`'s scenarios | The chat box completes no addon's slash words and `LibKa0s-Slash-1.0` offers none; the help line, the usage line and an unknown word list the scenarios instead (B5.2). |
| Use target health as a start signal | Other players hitting a shared dummy fire it before your first hit (spec §2). |
| "Time to deal X damage", or a goal bar | A threshold crossing is a comparison on a secret value, and the meter keeps no timeline. Dropped 2026-10-23. |
| PvP burst races (duels, events, leaderboards) | Parked until the duel probe runs ([issue #1](https://github.com/tusharsaxena/DpsRace/issues/1)). |
| A damage chart for runs from an earlier session | A live total read in combat stays secret, and the client writes a secret to SavedVariables as `nil` (the reload probe, 2026-10-25). The chart exists only for runs raced since the last `/reload` or login (#2). |
| Damage per bucket, or a live "ahead" or "behind" | Both are arithmetic or a comparison on a secret value. The chart is cumulative and the pace bar is read by eye (#2, #3). |
| The best run's real curve behind the chart | The best has no stored curve (above), so the overlay is its average pace, a straight line (#3). |
| A damage-activity strip in the Results detail | Dropped by the owner, 2026-10-25 (#2's board C). |
| A node-by-node talent diff, or a flag for a run raced on another loadout | The owner's call, 2026-10-25 (#6): talents are compared only as a *Different loadout* mark, and a loadout is not a run-quality problem. |
| Detect usage from item cooldowns | A shared cooldown starts on items that were never used (the probe, 2026-10-26: a potion started an engineering belt's), so casts, bag counts and buffs are the signals (#13). |
| List a weapon enchant (an oil) as used | An oil has no on-use, and `GetWeaponEnchantInfo` gives an enchant ID that maps to no item; the owner's call (2026-10-26) is to list an enchant only with an on-use, and none has one (#13). |
| Share runs between players | Phase 2. The run record already stores what it would need. Comparing two of your own runs side by side shipped in the Results detail (#7). |
| Classic or any non-Retail client | Retail only: one `## Interface:` line (toc-file-§3). |
| *Show results* or *Arm last race* on the launcher's menu | The menu is `LibKa0s-Launcher-1.0`'s fixed set (launcher-§2). Both are on the HUD, a slash verb and a key binding (spec §6.4). |
| Settings for the Results window's filters | The filters, grouping and sort are view state: the window opens on the view *Save* stored in the profile, else on the current character and spec (spec §6.2). Insights keeps its own saved view the same way, else every character and spec (#12). |
