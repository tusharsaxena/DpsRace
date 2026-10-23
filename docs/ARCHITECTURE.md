# Ka0s DPS Race — Architecture

The engineer brief and the hub of the doc set (documentation-§3). Each section below summarizes and
links; the detail lives in the topic docs listed under [Documentation map](#documentation-map). The
design this addon is built to is
[`superpowers/specs/2026-10-23-dps-race-pve-design.md`](superpowers/specs/2026-10-23-dps-race-pve-design.md)
(the spec), and the build order is
[`superpowers/plans/2026-10-23-dps-race-pve-v0.1.0.md`](superpowers/plans/2026-10-23-dps-race-pve-v0.1.0.md)
(the plan).

## Overview

Ka0s DPS Race is a timed DPS race against training dummies for Retail (Midnight, 12.x). The player
arms a race of a chosen length, the clock starts on the frame the first hit lands, and the buzzer
ends it. The addon then reads the run's damage, DPS and ability breakdown from Blizzard's built-in
damage meter (`C_DamageMeter`), stores the run with who, where and against what, and keeps personal
bests per spec, dummy category and race length. It never reads the combat log.

It is an Ace3 addon in the standard's modular layout. The shared subsystems (chat printer, debug
console, options toolkit, slash dispatcher, launcher, performance harness, stand-down latch, widget
pool, message bus, settings schema) come from the vendored `LibKa0s` v1.76.0; this addon holds one
setup file per module, each a descriptor plus a degradation stub (anti-pattern #47).

**Where the build stands.** The scaffold (T1), the engine (T2 to T6), the Race HUD (T7,
`modules/Hud*.lua` with `modules/Format.lua`), the Results window (T8, `modules/Results*.lua`) and
the settings pages, feature verbs, Share, test mode and the Arm / cancel key (T9) are in the tree.
What is left is the release record (T10) and the whole-branch review (T11).

Four invariants carry the whole design (spec §8). They bind from the first commit that touches the
code they name:

- `modules/Meter.lua` is the only file that calls `C_DamageMeter`, and `core/Secrets.lua` is the
  only file that inspects a value that may be secret. Everywhere else a meter value is an opaque
  handle passed to a widget setter or the native number formatter.
- No decision is ever made from a meter value in combat. Decisions come from events and `GetTime()`.
- Layout is computed from config, never read back off a frame that has received a secret.
- Every event registration goes through `NS.SafeRegisterEvent` (`LibKa0s-Core-1.0`).

## Module Map

The folder load order is `libs/` → `locales/` → `core/` → `defaults/` → `modules/` → `settings/`
(layout-§1), and the TOC repeats it as `#` section headers with every load-bearing position
annotated (toc-file-§5).

| Folder | Holds |
|---|---|
| `locales/` | `enUS.lua`, the canonical locale (`NS.L`, key-is-the-string fallback) |
| `core/` | the namespace, constants, session state, the nine `*Setup.lua` descriptors, the message-bus names, AceAddon registration and AceDB |
| `defaults/` | `Profile.lua`, the only place a default is hardcoded |
| `modules/` | the engine (`Meter`, `Recorder`, `Timeline`, `Scoring`, `Bests`, `Race`, `Watchers`), the Race HUD (`Format`, `Hud_Breakdown`, `Hud_States`, `Hud`), the Results window (`Results_Table`, `Results_Runs`, `Results_Detail`, `Results_Bests`, `Results`), `Share` (the one-line share and the race's chat lines), `Preview` (test mode) and `Diagnostics.lua` (the report's sections) |
| `settings/` | the schema runtime, the slash table, the options descriptor, and the pages in panel order: General, Race, Live breakdown, History, Profiles |
| `tests/` | the headless harness on the vendored `tests/_kit/` |
| `probe/` | `DpsRaceProbe`, the measurement addon the spec's numbers came from; never loaded, never shipped |

Every file, its one-line job and why the TOC orders it as it does: [module-map.md](module-map.md).

## Settings Schema

Settings are schema-driven (architecture-§5): page files register rows into `NS.Schema`, and every
write from the panel, the slash CLI, the launcher and the key bindings goes through the one seam,
`NS.SetByPath` (`settings/Schema.lua`, over `LibKa0s-Schema-1.0`). A `global.`-prefixed path lives
in `db.global`; every other path lives in the active profile. Each stored write announces
`SETTINGS_CHANGED`. The Master controls rows are composed by the library; the minimap row stores at
LibDBIcon's own `global.minimap.hide` and is vetoed out of every reset (launcher-§3).

The SavedVariables shape, every default, the migration path, the run record's format, and the
register of named non-setting state (the run store, LibDBIcon's table, the perf ring, the migration
stamp), each with its owner module and every writer: [schema.md](schema.md).

## Message Bus

Names are declared once in `core/Bus.lua` as `NS.MSG` and sent through `NS.SendBus`
(architecture-§4). Wire names are `Ka0s_DpsRace_<PascalCase>`. Each module receives on its own
target from `NS.NewBusTarget()`, so the stand-down latch can drop and replay every receiver.

| Message | Sender | Payload | Consumers |
|---|---|---|---|
| `RACE_STATE_CHANGED` | `modules/Race.lua` | `run, fromState, toState`, sent after the state moved | `modules/Hud.lua`: the body for the state, the countdown cue's timers, the onArm show and hide; `modules/Share.lua`: the *Armed* chat line; `modules/Preview.lua`: arming ends test mode |
| `RACE_BUZZER` | `modules/Race.lua` | `run`: the buzzer went, the run is now `stopping` | `modules/Hud.lua`: the raid-warning STOP and its sound (`race.buzzer`), with or without the window |
| `RACE_RESULT` | `modules/Race.lua` | `run`: resolved as `complete`, `incomplete` or `lost` | `modules/Hud.lua`: opens the window on the result card; `modules/Share.lua`: the score line in the player's chat |
| `RUN_SAVED` | `modules/Recorder.lua` (T3) | `run` | `modules/Bests.lua`: drops the bests cache and prunes to `global.history.keep`; `modules/Results.lua`: redraws the shown tab and detail (a hidden window redraws on its next show); `settings/History.lua`: repaints the stored count |
| `RUNS_CHANGED` | `modules/Recorder.lua` (T3) | none: a delete or a prune changed the store | `modules/Bests.lua`: drops the bests cache; `modules/Results.lua`: redraws, dropping a selection whose run is gone; `settings/History.lua`: repaints the stored count |
| `SETTINGS_CHANGED` | `settings/Schema.lua` write seam; `core/Database.lua` on a profile change | `path, value` (`"profile", key` on a profile change) | `modules/Results.lua`: the footer's *Runs to keep* on `global.history.keep` |

Six messages today; the Tier 2 `message-bus.md` trigger is more than ten. Race reaches its own
`modules/Watchers.lua` directly (`Watchers.Sync()` on every transition), not over the bus: the
watchers are the race's event wiring, and their registration set must follow the state on the same
call, with or without the bus library.

## Slash Commands

`/dr` and `/dpsrace` reach one `LibKa0s-Slash-1.0` dispatcher, registered through AceConsole. A bare
`/dr` opens the settings panel; `options` is an alias of `config`. The table below is `NS.COMMANDS`
in `settings/Slash.lua`, in its declared order:

| Verb | What it does |
|---|---|
| `help` | Show this help |
| `config` | Open the settings panel |
| `enable` | Turn the addon on |
| `disable` | Turn the addon off without unloading it |
| `list` | List every setting |
| `get path` | Read one setting |
| `set path value` | Write one setting |
| `reset path` | Reset one setting |
| `resetall` | Reset every setting (asks first) |
| `debug [on\|off\|diagnostics]` | Debug console; `on`/`off` set logging, `diagnostics` writes the report |
| `diagnostics` | Write the diagnostics report to the debug console |
| `perf …` | Performance capture; `/dr perf help` |
| `version` | Print the addon version |
| `arm [length]` | Arm a race; `length` is `90`, `1:30` or `3m` (0:10 to 15:00); with none, the HUD's length |
| `cancel` | Cancel the armed or running race, or discard a pending result |
| `hud [show\|hide\|toggle]` | The race HUD; a bare `hud` toggles |
| `results [bests]` | Open the Results window, on the Bests tab when asked |
| `target` | Print the target's name, creature ID and catalog category |
| `test` | Turn test mode on or off (the Master controls' *Test mode* row) |
| `lock` / `unlock` | Write the *Lock frame* row (slash-commands-§8) |

The eight feature verbs follow `version` (spec §6.4). The dispatcher refuses each with the one
disabled line while the addon is disabled; under the `perf` hold alone each answers the capture line.
The dispatch rules, the disabled gate and the live list: [slash-dispatch.md](slash-dispatch.md).

## Event Subscriptions

All registrations go through `NS.SafeRegisterEvent` on the AceAddon object, and the set is rebuilt
from current settings on every stand-up (slash-commands-§7).

| Event | Registered | Handler | Why |
|---|---|---|---|
| `PLAYER_REGEN_DISABLED` | always while standing up | `NS:OnCombatChanged` (`core/DpsRace.lua`) | combat ends test mode; refreshes the HUD's show decision |
| `PLAYER_REGEN_ENABLED` | only while `visibility` is `inCombat` or `outOfCombat` | `NS:OnCombatChanged` | the show decision needs the leaving edge |

`modules/Watchers.lua` registers on its own frame, through the same `SafeRegister*` family, only
while a race needs it. Nothing is registered while the race is idle or showing a result, and nothing
while the addon is stood down: the stand-down calls `Watchers.Suspend()`, and the stand-up's
`Watchers.Resume()` rebuilds the set from the race's current state.

| Event | Registered | Handler | Why |
|---|---|---|---|
| `DAMAGE_METER_CURRENT_SESSION_UPDATED` | ARMED, RUNNING, STOPPING | `Race.OnSessionCreated` | the clock starts on the new session, in combat or with the regen edge on the same frame (spec §4.2) |
| `DAMAGE_METER_COMBAT_SESSION_UPDATED` | ARMED, RUNNING, STOPPING | `Race.OnMeterUpdate` | names the run's session; each update is a timeline stamp (tail, restart, quiet) |
| `DAMAGE_METER_RESET` | ARMED, RUNNING, STOPPING | `Race.OnMeterReset` | a run in progress becomes `lost` |
| `PLAYER_REGEN_DISABLED` / `_ENABLED` | ARMED, RUNNING, STOPPING | `Race.OnCombatStart` / `OnCombatEnd` | the target re-read; incomplete before the buzzer; the read's combat gate |
| `PLAYER_DEAD` | ARMED, RUNNING, STOPPING | `Race.OnDeath` | the `died` flag; incomplete before the buzzer |
| `UNIT_SPELLCAST_START` / `_CHANNEL_START` / `_SUCCEEDED` / `_INTERRUPTED` / `_CHANNEL_STOP` (`player`) | RUNNING, STOPPING | `Race.OnCast` (with the castGUID) | late casts after the grace (spec §5.2); an interrupt or a channel's stop closes the cast in flight |

`modules/Hud.lua` registers on its own event frame only while the HUD window is on screen; hidden,
stood down or in test mode it holds nothing (spec §10). Its other timed work is not an event: the
countdown text is one `OnUpdate` at 20 Hz on the window, attached only while the race is RUNNING or
STOPPING, and the countdown cue is one `C_Timer` per mark (10, 5, 3, 2, 1) armed when the race runs.
`Hud.Suspend()` drops all of it at the stand-down.

| Event | Registered | Handler | Why |
|---|---|---|---|
| `PLAYER_TARGET_CHANGED` | the window shown | `Hud.Refresh` (target re-read) | the idle target card (spec §4.1) |
| `PLAYER_REGEN_DISABLED` / `_ENABLED` | the window shown | `Hud.Refresh` | the Arm button's *Leave combat to arm* and the footer |
| `DAMAGE_METER_COMBAT_SESSION_UPDATED` | the window shown and the race RUNNING | one coalesced `Meter.ReadLive` per `1/live.hz` s | the live breakdown at 4 Hz by default, never from `OnUpdate` (spec §10) |

`modules/Results.lua` registers no game event, no timer and no `OnUpdate`: it redraws from its bus
receiver (`RUN_SAVED`, `RUNS_CHANGED`, `SETTINGS_CHANGED`) and from the player's clicks, only while
the window is on screen.

`modules/Preview.lua` (test mode) registers no game event either; combat ends it through
`NS:OnCombatChanged`. While it plays its script it holds one `C_Timer` ticker at 10 Hz, canceled when
the script reaches the result card, when test mode ends and at the stand-down. `modules/Share.lua`
and `settings/History.lua` hold only their bus receivers.

The pipeline from event to screen: [data-flow.md](data-flow.md).

## Taint Notes

- The addon creates no secure frame and calls no protected API. The three key-binding buttons
  (`DpsRaceToggleHud`, `DpsRaceToggleResults`, `DpsRaceArmToggle`) are plain, hidden and not secure
  (launcher-§6).
- Share sends one chat line from a menu click (a hardware event), through `C_ChatInfo.SendChatMessage`
  with the old global beneath it, and only out of combat and out of the client's chat lockdown. The
  line is plain text with every `|` replaced, so no chat escape reaches a channel.
- The settings panel's combat lock is the library's (options-ui-§2): the panel refuses to open under
  lockdown, and the addon draws no page-level lock of its own.
- Meter values may be secret (events-frames-taint-§8). Only `core/Secrets.lua` tests them, and
  `.luacheckrc` scopes the client's detectors to it (and `C_DamageMeter` to `modules/Meter.lua`).
  A frame given a secret through `SetValue` has secret geometry, so no layout reads geometry back
  off a breakdown row (spec §6.1). The HUD's live path hands a live value to three native seams and
  nothing else: a bar's `SetMinMaxValues`/`SetValue`, the client's number formatter
  (`modules/Format.lua`, the one instance) and `C_Spell`'s name and icon lookups; the one question it
  asks of one is `== nil`. The HUD window is a plain non-secure frame, so it opens and redraws in
  combat (standalone-windows); its only geometry read is its own anchor on drag stop, and the shell
  never displays a value.
- The Results window is plain and non-secure too, and opens in combat. It never holds a meter value:
  it draws stored run records, whose numbers went through `NS.Secrets` on their way into the store,
  so its sorting, percentages and timing-strip positions are plain Lua. It still lays out from
  config; its only geometry read is its own anchor on drag stop.
- The diagnostics report is read-only and runs in combat; every value goes through `SafeToString`.

## Known Limitations

- **The launcher menu has no *Show results* or *Arm last race* entry** (spec §6.4). The right-click
  menu is `LibKa0s-Launcher-1.0`'s fixed set in launcher-§2's one order (Enabled, Locked, Test mode,
  Show window), which takes no host entries. The Results window and arming are one key binding, one
  verb or one HUD click away.
- **Lowering *Runs to keep* deletes nothing on the spot.** The prune runs at login and after each
  saved run (spec §7), so a slip of the slider costs nothing until the next race.
- **The Results window's filters are the session's.** They start at *all* (with *Include incomplete*
  on) at every login; they are view state, not settings.
- **The live breakdown can never show percentages or sort** (spec §6.1): both are arithmetic on
  secret values. This is a client limit, not a gap to close.
- **Unmeasured client behavior** is tracked as the spec's open items O1 to O7 (spec §12) and closes
  in the owner's smoke-test pass ([smoke-tests.md](smoke-tests.md)).
- **No exact cutoff at the buzzer.** Damage that lands after it counts, because meter values captured
  in combat stay secret (spec §2, §5.1).

## Documentation map

Frozen and generated stores are named once each and not enumerated: `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`,
`docs/revendor/<date>-v<tag>/`, `docs/superpowers/` and `docs/investigations/` (documentation-§3).
Of those, only `docs/superpowers/` exists today; it holds the spec and the plan.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `ARCHITECTURE.md` | This file: the hub |
| `scope.md` | What the addon does in v0.1.0, and what it deliberately leaves out |
| `module-map.md` | Every authored file, its job, and the TOC load order with its reasons |
| `schema.md` | SavedVariables shape, defaults, migrations, the run record, named non-setting state |
| `settings-panel.md` | The `Page \| Covers` table and the page → tab → row tree, mapped to schema paths |
| `data-flow.md` | Load and enable, the write seam, the stand-down latch, and the race pipeline |
| `common-tasks.md` | Recipes for the changes most often made here |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| `slash-dispatch.md` | Present | 21 commands in `NS.COMMANDS` (eight or more) |
| `profiles.md` | Present | A Profiles page ships in the options UI (`settings/Profiles.lua`) |
| `debug.md` | Present | The diagnostics report ships (always fired) |
| `midnight-quirks.md` | Not applicable | No client-version workaround of the addon's own: `core/Secrets.lua` (T2) binds the LibKa0s-Compat guards and owns none; re-check when one is added |
| `compat-layer.md` | Not applicable | No `core/Compat.lua` (compat's applicability condition): no version-variant call is owned |
| `message-bus.md` | Not applicable | 6 messages in `NS.MSG` (the trigger is more than ten) |
| `known-limitations.md` | Not applicable | Known Limitations above is under ~60 lines |
| `taint.md` | Not applicable | Taint Notes above is under ~60 lines |

### Verification and record (documentation-§3)

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate; the suite checkpoints |
| `smoke-tests.md` | The in-game smoke-test suite (scaffold checks now; completed in T10) |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The addon performance page |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated by the runner, never hand-edited apart from the watch list's `Disposition` column (automated-tests-§4). Written by the first runner bundle (T10, before the v0.1.0 tag) |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `brainstorm/mockup/README.md` | The UX mockups (`screens/*.png`, `index.html`): the visual reference for every window |

## Documented deviations

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `layout-§1` | A non-standard root folder, `probe/`, holds `DpsRaceProbe` (1068 lines of authored Lua, a second addon). It is linted under its own scoped `.luacheckrc` stanza, ignored by `.pkgmeta` and never loaded by this addon | It is the measurement record the spec's numbers and the plan's test fixtures (T4 probe runs 4 and 6) came from; kept byte-for-byte so a disputed figure can be re-measured with the same code | 2026-10-23 | Open questions O1 to O7 closed in smoke tests, after which `probe/` moves out of this repo |

### Files over the 1500-line cap

Nothing is over the cap today.
