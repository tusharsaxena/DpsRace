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

**Where the build stands.** Task 1 (the scaffold) is complete: the substrate, the Master controls
tab, the Profiles page, the launcher, two Show-window key bindings, the slash surface, the
diagnostics report and the perf harness. The engine (T2 to T6) and the windows (T7 to T9) are not in
the tree yet; `modules/Placeholders.lua` holds the `NS.Hud`, `NS.Results` and `NS.Preview` surfaces
the scaffold already calls, and each later task replaces one of them. Sections below say which parts
are planned rather than present.

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
| `core/` | the namespace, constants, session state, the eight `*Setup.lua` descriptors, the message-bus names, AceAddon registration and AceDB |
| `defaults/` | `Profile.lua`, the only place a default is hardcoded |
| `modules/` | `Diagnostics.lua` (the report's sections) and `Placeholders.lua` (the stand-ins T7 to T9 replace) |
| `settings/` | the schema runtime, the slash table, the options descriptor, the General and Profiles pages |
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
| `RACE_STATE_CHANGED` | `modules/Race.lua` (T5) | `run, fromState, toState` | HUD (T7), Results (T8) |
| `RUN_SAVED` | `modules/Recorder.lua` (T3) | `run` | Bests cache and pruning (T6), Results list (T8) |
| `RUNS_CHANGED` | `modules/Recorder.lua` (T3) | none: a delete or a prune changed the store | Bests cache (T6), Results list (T8) |
| `SETTINGS_CHANGED` | `settings/Schema.lua` write seam; `core/Database.lua` on a profile change | `path, value` (`"profile", key` on a profile change) | none in the scaffold |

T5 adds `RACE_BUZZER(run)` and `RACE_RESULT(run)`. Four messages today; the Tier 2 `message-bus.md`
trigger is more than ten.

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

T9 appends the feature verbs `arm [length]`, `cancel`, `hud show|hide|toggle`, `results`, `target`,
`test`, `lock` and `unlock` (spec §6.4). The dispatch rules, the disabled gate and the live list:
[slash-dispatch.md](slash-dispatch.md).

## Event Subscriptions

All registrations go through `NS.SafeRegisterEvent` on the AceAddon object, and the set is rebuilt
from current settings on every stand-up (slash-commands-§7).

| Event | Registered | Handler | Why |
|---|---|---|---|
| `PLAYER_REGEN_DISABLED` | always while standing up | `NS:OnCombatChanged` (`core/DpsRace.lua`) | combat ends test mode; refreshes the HUD's show decision |
| `PLAYER_REGEN_ENABLED` | only while `visibility` is `inCombat` or `outOfCombat` | `NS:OnCombatChanged` | the show decision needs the leaving edge |

T5's `modules/Watchers.lua` adds the meter events (`DAMAGE_METER_*`), the combat edges and
`PLAYER_DEAD`, and registers the three `UNIT_SPELLCAST_*` events for `player` only while a run is
RUNNING or STOPPING. The pipeline from event to screen: [data-flow.md](data-flow.md).

## Taint Notes

- The addon creates no secure frame and calls no protected API. The two key-binding buttons
  (`DpsRaceToggleHud`, `DpsRaceToggleResults`) are plain, hidden and not secure (launcher-§6).
- The settings panel's combat lock is the library's (options-ui-§2): the panel refuses to open under
  lockdown, and the addon draws no page-level lock of its own.
- From T2 on, meter values may be secret (events-frames-taint-§8). Only `core/Secrets.lua` tests
  them; a frame given a secret through `SetValue` has secret geometry, so no layout reads geometry
  back off a breakdown row (spec §6.1).
- The diagnostics report is read-only and runs in combat; every value goes through `SafeToString`.

## Known Limitations

- **Scaffold only.** No HUD, Results window or race engine yet. The Show-window toggles, *Test mode*,
  *Lock frame*, *Master scale* and *Reset position* act on the placeholders in
  `modules/Placeholders.lua` and draw nothing.
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
| `slash-dispatch.md` | Present | 13 commands in `NS.COMMANDS` (eight or more) |
| `profiles.md` | Present | A Profiles page ships in the options UI (`settings/Profiles.lua`) |
| `debug.md` | Present | The diagnostics report ships (always fired) |
| `midnight-quirks.md` | Not applicable | No client-version workaround of the addon's own yet; re-check when `core/Secrets.lua` (T2) lands |
| `compat-layer.md` | Not applicable | No `core/Compat.lua` (compat's applicability condition): no version-variant call is owned |
| `message-bus.md` | Not applicable | 4 messages in `NS.MSG` (the trigger is more than ten) |
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
