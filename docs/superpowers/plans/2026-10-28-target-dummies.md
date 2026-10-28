# Plan: your own training dummies, captured in game (#9)

Opened 2026-10-28. Branch `feat/2026-10-28-target-dummies` (DpsRace only). Resumable: each step is ticked
in the commit that finishes it; a run that stops resumes at the first unticked box. Push to origin after
T4. No merge without the owner's go-ahead.

## Decisions

### The owner (2026-10-28)

- **The capture is a permanent feature, not a throwaway probe.** `/dr targetdummy add` on a targeted unit
  marks it as a training dummy for this profile and saves what the game says about it in SavedVariables.
  Anyone can use it, and the owner's captures from Silvermoon, Stormwind, Dornogal and the PvP dummies are
  then read out of the WTF folder to grow `defaults/Dummies.lua` (never guessed).
- **Settings can add and remove dummies.** Custom entries can be added and removed; a built-in entry can be
  switched off and restored. A built-in is never recategorized.
- **Storage: a profile setting**, one schema row, like the late-cast ignore list.
- **Read time:** a stored run's category comes from the dummy list as it is now (by the run's creature
  ID), so a change, or a profile switch, recategorizes every stored run.

### Design decisions (this plan)

- **D-1 The row.** `race.dummies`, a plain string, written WHOLE through the seam (the late-cast ignore
  list's shape): comma-separated entries, ascending by creature ID. `243300:cleave` marks creature 243300
  as a dummy of that category; `-243205` switches a built-in off. Default `""`. Normalize drops a custom
  entry for a built-in ID (no recategorizing), a hide for a non-built-in ID, and duplicates (the last one
  written wins).
- **D-2 The captures are data, not settings.** `global.dummies.captures[npcID]`: the name, level,
  classification, max health, creature type, PvP flag, faction and reaction, the first and last capture
  dates, how many captures, the addon version and client build, and `places[mapID]` = zone, subzone, the
  player's map position and date. Global, because what a creature is does not change with the profile;
  the runs store is global for the same reason. A secret field is left out, never guessed. A capture is
  written by `add` (and by `capture`, which records without marking), never by a race.
- **D-3 The effective catalog.** `Dummies.Lookup(npcID)`: a hidden built-in answers nil; a custom entry
  answers its category and its captured name (else nil name); a built-in answers as before. Every caller
  (the recorder's snapshot, auto-arm's target and nameplates, the mock runs) reads the effective catalog.
  `Dummies.BuiltIn(npcID)` reads the shipped rows alone.
- **D-4 Category for a new dummy.** `/dr targetdummy add [category]` takes a category word (single,
  cleave, dungeoneer, boss, pvp); without one it reads the row `race.dummyCategory` (default `auto`).
  `auto` infers from the name (Cleave, Dungeoneer, PvP), then a boss classification or skull level
  (`worldboss`, `-1`: boss), else single.
- **D-5 Read-time category.** `Dummies.CategoryOf(target)`: with a creature ID, the effective catalog's
  category or `other`; with none (a sealed GUID), the stored category. Every read of a stored run's
  `target.category` goes through it: the Runs and Insights filters and groupings, the bests keys, the
  table badge and tooltip, the share line and the toast. Caches listen for SETTINGS_CHANGED on the row and
  on `profile`, as they do for the ignore list.
- **D-6 The slash verb.** `/dr targetdummy [show|add|remove|capture|defaults]`. A bare verb shows the list.
  `add [category]` and `capture` act on the target; `remove [creature ID]` takes the target when no ID is
  typed, and a built-in is switched off. `defaults` clears the list. Like `ignore`, it is a settings verb
  (HOST_LIVE_VERBS): it answers while the addon is disabled.
- **D-7 The settings.** A second tab on the Race page, *Training dummies*: a blurb, the *Category for new
  dummies* row (`race.dummyCategory`), an *Add your target* button, the library's ID list over the active
  dummies (custom and built-in; the suffix names the category and marks a built-in; the X removes a custom
  entry or switches a built-in off), a second list of the switched-off built-ins whose action restores
  one, and *Reset list*. The ID list's add box takes a creature ID (or a captured name), with the category
  the row names.
- **D-8 Auto-arm** re-reads its dummies (Sync and a nameplate rescan) on a change to the row.

### Standards flags

- None expected. The row is schema-driven; the captures are a data store beside the runs store; the verb
  is declared in NS.COMMANDS and documented. `targetdummy` joins `ignore` in HOST_LIVE_VERBS, whose
  reasoning is already recorded in `docs/ARCHITECTURE.md` (Slash commands).

## Steps

- [x] **T1 The list and the captures.** `modules/DummyList.lua` (parse, normalize, the writes, the
  captures, inference), `Dummies.Lookup` over it, `Dummies.CategoryOf`, `Dummies.BuiltIn`, the two rows in
  `defaults/Profile.lua` and `settings/Race.lua`, the TOC, `tests/test_dummy_list.lua`.
- [x] **T2 Read time.** Every stored-run category read through `CategoryOf`; Bests, Results, Insights,
  HUD, AutoArm and the Race page listen on the row. Tests: a stored run moves boards when its creature is
  added, and back when removed.
- [x] **T3 The slash verb.** `targetdummy` in NS.COMMANDS and HOST_LIVE_VERBS, its handler, locale
  strings, tests in `tests/test_dummy_list.lua` (or `test_slash.lua`).
- [ ] **T4 The settings tab.** The Race page's *Training dummies* tab, the repaint on change, tests. Push.
- [ ] **T5 Docs.** ARCHITECTURE (module map, schema, slash surface, bus listeners), `docs/schema.md`,
  `docs/slash-dispatch.md`, `docs/common-tasks.md` (adding a dummy), README commands, smoke rows. Gate,
  push.
