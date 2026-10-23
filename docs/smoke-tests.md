# Smoke tests

The in-game checks no headless run can reach: real rendering, the real damage meter, taint, and
client behavior the spec could not measure ahead of time. The owner runs them before a release,
on a character in a city with training dummies (Silvermoon has every dummy in the catalog).

**This is the scaffold's checklist.** It covers what exists after Task 1. T10 completes the page:
every HUD state on a real dummy, the Results window, the open items O1 to O7, the reload-in-combat
case and the restart case (spec §12, plan T10 step 2). Until then those sections are headings only.

Record each run as pass or fail with the date, the build and anything odd. A failure becomes a
GitHub issue.

## Load and identity

- The addon loads with no Lua error (`/console scriptErrors 1` first).
- The AddOns list shows *Ka0s DPS Race* with the logo icon.
- `/dr version` and `/dpsrace version` print the same version as the TOC.
- `/dr help` lists every command; the settings landing page lists the same rows.

## Settings panel

- *Settings → AddOns → Ka0s DPS Race* exists right after login, before the panel was ever opened.
- The landing page shows the logo, the notes line and the command list. Switching pages and back
  does not leave the logo drawn under the command list.
- General has two tabs, *Master controls* (the rows in canonical order) and *Race HUD*.
- Race, Live breakdown and History are listed between General and Profiles, each drawn as a tab
  strip with subsection headings; each page's Defaults button restores only its own rows.
- The Race page's grace slider steps by 0.1 from 0 to 5 and its tooltip says it applies to new runs;
  the length dropdown offers 0:30 to 5:00.
- History shows the stored count; *Delete all runs…* asks first and the Results window empties on
  accept; with a race armed it refuses with one line. A large *Runs to keep* value is typed into the
  slider's box without a stall.
- Opening the panel in combat is refused with a notice; it opens once combat ends.
- *Reset all settings* asks first; after it, the minimap button keeps its state.
- Profiles: create, switch, copy and delete a profile. Run history is unaffected (it is global).

## Launcher and key bindings

- The minimap button shows the logo. Left-click opens settings; right-click shows Enabled, Locked,
  Test mode and Show window.
- Hovering shows the version and status, also while disabled.
- *Minimap button* off hides the button; on brings it back in the same place.
- *Key Bindings → AddOns → Ka0s DPS Race* lists *Toggle race HUD*, *Toggle results window* and
  *Arm / cancel race*, with no key set. The Arm / cancel key arms the HUD's length, cancels an armed
  or running race, and only prints a line while a result is pending.

## Feature verbs, Share and test mode (T9)

- `/dr arm 1:30` arms 1:30 and prints the *Armed* line; `/dr arm 0` prints the length line;
  `/dr cancel` cancels; `/dr target` on a catalog dummy prints its creature ID and category.
- `/dr hud show|hide|toggle`, `/dr results`, `/dr results bests`, `/dr lock`, `/dr unlock` act and
  echo; `/dpsrace` answers the same as `/dr`.
- A result prints the score line once. *Share* on the result card and in the Results detail opens a
  menu (Say, Party, Raid, Guild, Whisper…) with the channels you are not in grayed; Say posts the
  mockup's line, Whisper asks for a name. In combat Share refuses with one line.
- `/dr test` plays Armed, Running, Stop!, Waiting and Result on the HUD with the amber strip under
  the title; the HUD can be dragged and resized while it plays. Entering combat ends it with one
  line; arming a real race ends it and the HUD shows the real race; *Reset all settings* unticks
  *Test mode*. The strip glyph (the info icon) and its text render at the HUD's minimum width.

## Disabled state

- `/dr disable`: every right-click menu entry but Enabled is grayed; `/dr help`, `/dr config`,
  `/dr list` and `/dr diagnostics` still answer.
- A key binding while disabled prints the one *disabled* line and does nothing else.
- `/dr enable` restores everything without a `/reload`.

## Debug and performance

- `/dr debug on`, then `/dr debug`: the console opens with `[Debug]` and `[Init]` lines.
- `/dr diagnostics` appends the report after the trace, with begin and end markers naming
  *Ka0s DPS Race*. **Copy** copies it whole. It also runs while disabled.
- `/dr perf start`, `/dr perf measure a`, fight a dummy, leave combat, `/dr perf finish`,
  `/reload`, `/dr perf report`: a report and a JSON line print. Save the pair for
  `/dev-copilot:wow-perf-analysis` if the capture is worth keeping.

## The race (T10)

Every HUD state on a real dummy; reload during a run and during the waiting phase; the restart case
(stop, wait 10 s in combat, attack again); the Results window; share; test mode end to end.

## Open items (T10)

O1 to O7 from spec §12, each with pass and fail criteria and the fallback to note:
in-combat spell order, icons from a secret spell ID, the restart flag, `/reload` in combat after the
buzzer, sessions across a logout, cast starts for empowered spells, and the cleave group's count.
