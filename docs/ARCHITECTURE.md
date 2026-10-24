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
pool, message bus, settings schema) come from the vendored `LibKa0s` v1.77.0; this addon holds one
setup file per module, each a descriptor plus a degradation stub (anti-pattern #47).

**What ships in v0.1.0.** Three layers, each listening on the message bus to the one below:

- **The engine** decides. `modules/Meter.lua` reads `C_DamageMeter`; `modules/Timeline.lua` and
  `modules/Scoring.lua` are pure timing and scoring; `modules/Race.lua` is the state machine
  (idle, armed, running, stopping, result) driven by `modules/Watchers.lua`'s events and
  `GetTime()`; `modules/Recorder.lua` snapshots and stores runs; `modules/Bests.lua` works out
  personal bests and protects them from pruning.
- **The UI** draws. The Race HUD (`modules/Hud*.lua`, numbers through `modules/Format.lua`), the
  Results window (`modules/Results*.lua`), the chat share (`modules/Share.lua`) and test mode
  (`modules/Preview.lua`). None of them decides anything from a meter value.
- **The shell** configures and reaches. The settings pages, the slash verbs, the launcher and three
  key bindings, the stand-down latch, the perf harness and the diagnostics report.

The design and every rule's reason are in the spec; [scope.md](scope.md) says what is in and out.

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
| `modules/` | the engine (`Meter`, `Recorder`, `Timeline`, `Scoring`, `Bests`, `Race`, `Watchers`), the shared look of both windows (`Style`), the Race HUD (`Format`, `Hud_Appearance`, `Hud_Breakdown`, `Hud_States`, `Hud`), the final seconds (`Countdown`), the Results window (`Results_Table`, `Results_Runs`, `Results_Detail`, `Results_Bests`, `Results`), `Share` (the one-line share and the race's chat lines), `Preview` (test mode) and `Diagnostics.lua` (the report's sections) |
| `settings/` | the schema runtime, the slash table, the options descriptor, and the pages in panel order: General, Race, HUD, History, Profiles |
| `tests/` | the headless harness on the vendored `tests/_kit/` |

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
| `RACE_STATE_CHANGED` | `modules/Race.lua` | `run, fromState, toState`, sent after the state moved | `modules/Hud.lua`: the body for the state, the onArm show and hide; `modules/Countdown.lua`: the final seconds' marks (armed on RUNNING, canceled on leaving it); `modules/Share.lua`: the *Armed* chat line; `modules/Preview.lua`: arming ends test mode |
| `RACE_BUZZER` | `modules/Race.lua` | `run`: the buzzer went, the run is now `stopping` | `modules/Hud.lua`: the raid-warning STOP and its sound (`race.buzzer`), with or without the window |
| `RACE_RESULT` | `modules/Race.lua` | `run`: resolved as `complete`, `incomplete` or `lost` | `modules/Hud.lua`: opens the window on the result card; `modules/Share.lua`: the score line in the player's chat |
| `RUN_SAVED` | `modules/Recorder.lua` | `run`: sent at the start, the session capture, the buzzer and the result | `modules/Bests.lua`: drops the bests cache and prunes to `global.history.keep`; `modules/Results.lua`: redraws the shown tab and detail (a hidden window redraws on its next show); `settings/History.lua`: repaints the stored count |
| `RUNS_CHANGED` | `modules/Recorder.lua` | none: a delete, a prune or a note changed the store | `modules/Bests.lua`: drops the bests cache; `modules/Results.lua`: redraws, dropping a selection whose run is gone; `settings/History.lua`: repaints the stored count |
| `SETTINGS_CHANGED` | `settings/Schema.lua` (`NS.AnnounceSettingsChanged`: the write seam's tail, and `core/Database.lua`'s profile callbacks call it on a profile change) | `path, value` (`"profile", key` on a profile change) | `modules/Results.lua`: the footer's *Runs to keep* on `global.history.keep` |

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

The launcher (`core/LauncherSetup.lua`) and the three key bindings (`Bindings.xml`: *Toggle race
HUD*, *Toggle results window*, *Arm or cancel race*, all in the addon's own category
`BINDING_HEADER_DPSRACE` with no header, launcher-§6) call the same handlers as the verbs, in
`core/DpsRace.lua`. `NS.BINDINGS` (`core/LauncherSetup.lua`) declares them once, in `Bindings.xml`'s
order; the General page's last tab, *Keybindings*, is the library's `O.KeybindingsTab` drawn from
it (options-ui-§20), so a key set there or in Options -> Keybindings shows in both. The launcher's right-click menu is `LibKa0s-Launcher-1.0`'s fixed set
(launcher-§2: Enabled, Locked, Test mode, Show window), so the Results window is reached from the
HUD's title bar, `/dr results` or its key (spec §6.4).

## Event Subscriptions

All registrations go through `NS.SafeRegisterEvent` on the AceAddon object, and the set is rebuilt
from current settings on every stand-up (slash-commands-§7).

| Event | Registered | Handler | Why |
|---|---|---|---|
| `PLAYER_REGEN_DISABLED` | always while standing up | `NS:OnCombatChanged` (`core/DpsRace.lua`) | combat ends test mode; refreshes the HUD's show decision |
| `PLAYER_REGEN_ENABLED` | only while `visibility` is `inCombat` or `outOfCombat` | `NS:OnCombatChanged` | the show decision needs the leaving edge |

`modules/Watchers.lua` registers, through the same `SafeRegister*` family, only while a race needs
it: the non-unit events on its own AceEvent target (keyed apart from the addon object, so the shared
`PLAYER_REGEN_*` never clobber one another's handler), and the player's casts on a unit-filter frame
whose only job is `RegisterUnitEvent(..., "player")` (events-frames-taint-§1's carve-out). Nothing is registered while the race is idle or showing a result, and nothing
while the addon is stood down: the stand-down calls `Watchers.Suspend()`, and the stand-up's
`Watchers.Resume()` rebuilds the set from the race's current state.

| Event | Registered | Handler | Why |
|---|---|---|---|
| `DAMAGE_METER_CURRENT_SESSION_UPDATED` | ARMED, RUNNING, STOPPING | `Race.OnSessionCreated` | the clock starts on the new session, in combat or with the regen edge on the same frame (spec §4.2); the first DamageDone update heard in combat starts it too (`Race.OnMeterUpdate`), for a session the meter made out of combat |
| `DAMAGE_METER_COMBAT_SESSION_UPDATED` | ARMED, RUNNING, STOPPING | `Race.OnMeterUpdate` | names the run's session; each update is a timeline stamp (tail, restart, quiet) |
| `DAMAGE_METER_RESET` | ARMED, RUNNING, STOPPING | `Race.OnMeterReset` | a run in progress becomes `lost` |
| `PLAYER_REGEN_DISABLED` / `_ENABLED` | ARMED, RUNNING, STOPPING | `Race.OnCombatStart` / `OnCombatEnd` | the target re-read; incomplete before the buzzer; the read's combat gate |
| `PLAYER_DEAD` | ARMED, RUNNING, STOPPING | `Race.OnDeath` | the `died` flag; incomplete before the buzzer |
| `UNIT_SPELLCAST_START` / `_CHANNEL_START` / `_EMPOWER_START` / `_SUCCEEDED` / `_INTERRUPTED` / `_CHANNEL_STOP` (`player`, the unit-filter frame) | RUNNING, STOPPING | `Race.OnCast` (with the castGUID) | late casts after the grace (spec §5.2); an empowered cast is in flight from its start; an interrupt or a channel's stop closes the cast in flight |

`modules/Hud.lua` registers on its own AceEvent target only while the HUD window is on screen; hidden,
stood down or in test mode it holds nothing (spec §10). Its other timed work is not an event: the
countdown text is one `OnUpdate` on the window, attached only while the race is RUNNING (20 Hz) or
STOPPING (4 Hz: no clock, and combat may hold for minutes), and that is all.
`Hud.Suspend()` drops all of it at the stand-down.

`modules/Countdown.lua` registers no game event: the race's final seconds are one `C_Timer` per
whole second still ahead (10 down to 1), armed when the race runs and canceled when it leaves
RUNNING, each playing the countdown cue once and showing its center-screen number on the module's
own frame. `Countdown.Suspend()` drops them at the stand-down.

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

## Frame layering

Every strata and level the addon sets reads one table, `NS.Constants.LAYERS` in
`core/Constants.lua` (frame-layering-§5); its header comment is the addon's whole stack, so it is not
copied here. The tiers by the standard's keys: `HUD` (the Race HUD, MEDIUM, toplevel), `WINDOW` (the
Results window, HIGH, toplevel) and `SCREEN_ALERT` (the center-screen countdown, FULLSCREEN,
mouse-disabled, below the library's FULLSCREEN_DIALOG menus), with one level band, `LEVEL.DETAIL`, that
lifts the Results detail pane over the Runs pane it sits inside. The StaticPopups, the debug console,
the perf panel, the dropdown menu and the tooltips are Blizzard's or the library's. `test_layers` pins
each frame's strata, level and toplevel.

## Taint Notes

- The addon creates no secure frame and calls no protected API. The three key-binding buttons
  (`DpsRaceToggleHud`, `DpsRaceToggleResults`, `DpsRaceArmToggle`) are plain, hidden and not secure
  (launcher-§6).
- Share sends one chat line from a menu click (a hardware event), through `NS.Compat.ChatSender()` (`C_ChatInfo.SendChatMessage`)
  with the old global beneath it, and only out of combat and out of the client's chat lockdown. The
  line is plain text with every `|` replaced, so no chat escape reaches a channel.
- The settings panel's combat lock is the library's (options-ui-§2): the panel refuses to open under
  lockdown, and the addon draws no page-level lock of its own.
- Meter values may be secret (events-frames-taint-§8). Only `core/Secrets.lua` tests them. The
  client's detectors live in the compat family's root, `core/Compat.lua` (LibKa0s-Compat-1.0's
  guards with their stub, and the table detector's ladder), whose guards `core/Secrets.lua` alone
  calls; `.luacheckrc` scopes the detectors to `core/Compat.lua`, `C_DamageMeter` to
  `modules/Meter.lua`, and `test_meter` scans for both fences.
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
- The center-screen countdown (`modules/Countdown.lua`) draws on its own plain frame with its own
  textures cut from Blizzard's BigGold digit sheet. It never calls `C_PartyInfo.DoCountdown` (that
  broadcasts a pull timer to the group) nor any `TimerTracker` handler, and `test_countdown` scans for both.
- The diagnostics report is read-only and runs in combat; every value goes through `SafeToString`.

## Known Limitations

- **Lowering *Runs to keep* deletes nothing on the spot.** The prune runs at login and after each
  saved run (spec §7), so a slip of the slider costs nothing until the next race.
- **The Results window's Runs view is the saved one, else the stock one.** Its filters, grouping
  and sort open on what *Save* stored in the profile (`profile.views.runs`), else on *Current
  character*, *Current spec*, no grouping and newest first; *Reset* deletes the saved view and
  *Clear* returns to it. They are view state, not settings: no schema row, and the profile reset
  takes them with the profile.
- **The live breakdown can never show percentages or sort** (spec §6.1): both are arithmetic on
  secret values. This is a client limit, not a gap to close.
- **Unmeasured client behavior** is tracked as the spec's open items O1 to O7 (spec §12) and the
  client assumptions C1 to C26, and closes in the owner's smoke-test pass
  ([smoke-tests.md](smoke-tests.md), section 9). Live DPS, for one, is a rung chain in
  `Meter.ReadLive` (the source's `amountPerSecond`, else the player's own `combatSources` row, else
  the Dps meter type); the live client measured on 2026-10-23 lacks the first, and a client with no
  rung answering shows a dash for the whole race (C3).
- **With both the castGUID and the spell ID sealed, an instant pressed while another cast is in
  flight** (and no interrupt was heard) is taken as that cast finishing, and is not judged. Casting
  normally interrupts the cast in flight, so this is rare (`Race.OnCast`).
- **A `/reload` loses the run's in-memory timeline.** The tail and the restart check resume from
  `race.lastDamage`, the last update heard before the reload; a restart already heard is already on
  the run. A running run resumed out of combat before its buzzer takes the resume time as its end,
  an upper bound, because the real combat edge was missed.
- **The cleave group's target count is 1** until it is counted in game (O7); the HUD's stepper
  sets it per run in the meantime.
- **A pull that carries on the last fight's session is netted, not separated.** When the meter
  makes no new session for a race (the last fight's DoTs kept its session open), the run is flagged
  `sharedSession` and what that session held at the arm is taken off the total and each spell. DoT
  ticks that land between the arm and the pull still count, and a run with no arm-time read (it
  failed, or the pull carried on an older session than the newest) keeps the whole total, which its
  flag says.
- **The HUD's minimum height is set at the default look.** A taller *Row height*, or larger clock or
  figure fonts, leave fewer spell rows at the minimum height; the window can be made taller.
- **No exact cutoff at the buzzer.** Damage that lands after it counts, because meter values captured
  in combat stay secret (spec §2, §5.1).

## Documentation map

Frozen and generated stores are named once each and not enumerated: `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`,
`docs/revendor/<date>-v<tag>/`, `docs/superpowers/` and `docs/investigations/` (documentation-§3).
Of those, `docs/automated-tests/<run>/`, `docs/revendor/<date>-v<tag>/` and `docs/superpowers/`
exist today; `docs/superpowers/` holds the spec and the plan.

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
| `midnight-quirks.md` | Not applicable | No client-version workaround of the addon's own: the secret guards are LibKa0s-Compat-1.0's, routed from `core/Compat.lua`, and the shims there are API ladders, not behavior workarounds; re-check when one is added |
| [`compat-layer.md`](compat-layer.md) | Present | `core/Compat.lua` publishes four hand-written shims (`CanAccessTable`, `ChatSender`, `NewNumberFormatter`, `PopupEditBox`); the trigger is three or more |
| `message-bus.md` | Not applicable | 6 messages in `NS.MSG` (the trigger is more than ten) |
| `known-limitations.md` | Not applicable | Known Limitations above is under ~60 lines |
| `taint.md` | Not applicable | Taint Notes above is under ~60 lines |

### Verification and record (documentation-§3)

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate; the suite checkpoints |
| `smoke-tests.md` | The owner's end-of-run in-game checklist: every HUD state, reload, restart, Results, settings, slash, launcher, bindings, test mode, and every client assumption with its pass criterion |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The addon performance page |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated by the runner, never hand-edited apart from the watch list's `Disposition` column (automated-tests-§4). Written by the first runner bundle, before the v0.1.0 tag |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `brainstorm/mockup/README.md` | The UX mockups (`screens/*.png`, `index.html`): the visual reference for every window |

## Documented deviations

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `standalone-windows` | The close control is built through the one wrapper (`NS.MakeCloseButton`, the catalog's `close` mark, gray at rest) but its hover tint is the header gold, not the library's red: `modules/Style.lua` hooks the control's enter and leave (after the library's own) and repaints it with the HUD's other title-bar controls. The wrapper, the mark, the grep gate and the rest color are unchanged | The owner asked on 2026-10-24 for every title-bar control, close included, to turn gold under the pointer as MultiMeters' strip does; a red close beside three gold controls reads as two hover rules in one strip. The four-condition decline does not apply: the library still draws the control | 2026-10-24 | `LibKa0s-Core-1.0` `MakeCloseButton` takes a hover color, or the standard names the hover tint of a host's title-bar strip; or the owner prefers the red back |

### Files over the 1500-line cap

Nothing is over the cap today, and nothing is in the 1000–1500 on-notice band. The largest file is
`modules/Hud.lua` at 916 lines (layout-§1).
