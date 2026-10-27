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
  `GetTime()`; `modules/Recorder.lua` snapshots and stores runs, with the gear and talents raced
  (`modules/Loadouts.lua` keeps each distinct set once), what was cast (`modules/Casts.lua`) and
  what was used (`modules/Usage.lua`); `modules/Slices.lua` holds the damage chart's buckets for this
  session only; `modules/Bests.lua` works out personal bests and protects them from pruning.
- **The UI** draws. The Race HUD (`modules/Hud*.lua`, numbers through `modules/Format.lua`, with
  the live damage chart and pace bar in `modules/Hud_Chart.lua`), the Results window
  (`modules/Results*.lua`, its run detail comparing two runs and showing the loadout and what the
  run used, with the ability timeline as its pop-out window), the chat share (`modules/Share.lua`), and test mode and the sim
  (`modules/Preview.lua`, `modules/Sim.lua`, drawing `modules/MockRuns.lua`'s in-memory sample data;
  the Results window reads it through its source seam, `modules/Results_Source.lua`). None of them
  decides anything from a meter value.
- **The shell** configures and reaches. The settings pages, the slash verbs, the launcher and three
  key bindings, the stand-down latch, the perf harness and the diagnostics report.

The design and every rule's reason are in the spec; [scope.md](scope.md) says what is in and out.
The 2026-10-25 pass ([`superpowers/plans/2026-10-25-chart-compare-loadout.md`](superpowers/plans/2026-10-25-chart-compare-loadout.md))
added the live damage chart and pace bar (#2, #3), the run detail's compare (#7), and the gear and
talents stored with each run (#6, run-record format 2).
The second 2026-10-25 pass ([`superpowers/plans/2026-10-25-results-badges-sim.md`](superpowers/plans/2026-10-25-results-badges-sim.md))
added the Runs list's boxed Status badges naming their board and the race length colors (Results
only), Group by *Time* and *Target + time*, the *Pace bar range* setting and the result
card's pace bar, the Results window's return after the talent tree's panel open, and the split of
`/dr test` (static samples in every view) from `/dr sim` (a whole scripted race), both drawing
in-memory samples and writing nothing to SavedVariables. Its Round C (the owner's notes after testing
it) renamed the chart *Damage profile* and gave the HUD its section headings, centered the pace bar's
tick, put *Stop Now* (`Race.StopNow`: the result read now, the quiet waived) and *Cancel* on the Stop!
and waiting screens, and gave the result card *Delete* in a row of four equal buttons and the best's
average-pace diagonal on the chart after the race. The owner's notes on the Results window then boxed
the Runs list's *Target* and *Time* cells and the Status board in their category and length colors
(also the Bests *Length* and the detail's target line) and colored the group headers' values as plain
text in the class, category and length colors. The talent tree step-aside branch then made the Status
cell the tag alone (its board in the tooltip), brought the window minimums to 834 collapsed and 1198
expanded, and added Group by *Spec + target + time* and *Full* (a new profile's default), renaming
*Duration* to *Time*.
The 2026-10-26 pass ([`superpowers/plans/2026-10-26-usage-timeline.md`](superpowers/plans/2026-10-26-usage-timeline.md))
records each race's casts and what it used (#13, #14, run-record format 3). From the arm to the
result `modules/Watchers.lua` hands every `UNIT_SPELLCAST_SUCCEEDED` of the player and the pet (and
the player's channel edges) to `modules/Casts.lua`, which keeps the cast list on the race clock and
each spell's base cooldown; `modules/Usage.lua` reads the on-use gear, the bag consumables and the
helpful auras at the arm, and at the result works out what was used from the casts, the bag counts
and that snapshot (no weapon enchant: an oil has no on-use). The Runs list gained a *Used* column
and the detail a *Usage* section of what was used (every detail section heading folds its section with an arrow,
the folded set in `profile.windows.results.collapsedSections`), with *Edit* to tick or untick every candidate
(`modules/Results_Usage.lua`), and a list of hidden items (`global.usage.hidden`, History > Usage)
that none of them ever shows; the damage chart marks each cast of an
ability whose base cooldown is 29 s or more with that ability's icon (*Show cooldown icons*), live and
after the race; and the detail's *Timeline* button opens the ability timeline (`modules/Results_Timeline.lua`),
every ability's casts in two lanes, this run's above the compared run's, under two strips of every cast's
icon on the same time axis (*Casts*). The same pass replaced *Runs
to keep* (a count) with *Days to keep* (90 by default, 0 never). What it stores is plain: the spell
IDs and castGUIDs pass through `NS.Secrets` (the probe measured both plain in combat), and the usage
snapshot is read out of combat.

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
| `modules/` | the engine (`Meter`, `Recorder`, `Loadouts`, `Timeline`, `Scoring`, `Bests`, `Slices`, `Casts`, `Usage`, `Race`, `Watchers`), the shared look of both windows (`Style`), smooth resizing for all three windows (`Sizing`), the Race HUD (`Format`, `Hud_Appearance`, `Hud_Breakdown`, `Hud_Chart`, `Hud_States`, `Hud`), the final seconds (`Countdown`), the Results window (`Results_Source`, `Results_Table`, `Results_Tips`, `Results_Runs`, `Results_Detail`, `Results_Compare`, `Results_Loadout`, `Results_Usage`, `Results_Timeline` (the ability timeline window), `Results_Bests`, `Results`), `Share` (the one-line share and the race's chat lines), `MockRuns` (the sample data), `Preview` (test mode and the sim's shell), `Sim` (the sim's scenarios and script) and `Diagnostics.lua` (the report's sections) |
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
| `RACE_STATE_CHANGED` | `modules/Race.lua` | `run, fromState, toState`, sent after the state moved | `modules/Hud.lua`: the body for the state, the onArm show and hide; `modules/Countdown.lua`: the final seconds' marks (armed on RUNNING, canceled on leaving it); `modules/Share.lua`: the *Armed* chat line; `modules/Preview.lua`: arming ends test mode or the sim |
| `RACE_BUZZER` | `modules/Race.lua` | `run`: the buzzer went, the run is now `stopping` | `modules/Hud.lua`: the raid-warning STOP and its sound (`race.buzzer`), with or without the window |
| `RACE_RESULT` | `modules/Race.lua` | `run`: resolved as `complete`, `incomplete` or `lost` | `modules/Hud.lua`: opens the window on the result card; `modules/Share.lua`: the score line in the player's chat |
| `RUN_SAVED` | `modules/Recorder.lua` | `run`: sent at the start, the session capture, the buzzer and the result | `modules/Bests.lua`: drops the bests cache and prunes runs older than `global.history.keepDays`; `modules/Results.lua`: redraws the shown tab and detail (a hidden window redraws on its next show); `settings/History.lua`: repaints the stored count |
| `RUNS_CHANGED` | `modules/Recorder.lua`; `modules/Usage.lua` (`SetUsed`: a run's usage ticks saved) | none: a delete, a prune, a note or a usage edit changed the store | `modules/Bests.lua`: drops the bests cache; `modules/Results.lua`: redraws, dropping a selection whose run is gone (the detail's redraw also redraws an open ability timeline); `modules/Hud.lua`: dismisses a result card whose run left the store (back to the Arm Race screen after the card's own *Delete*), and redraws the card on any other store change; `settings/History.lua`: repaints the stored count |
| `SETTINGS_CHANGED` | `settings/Schema.lua` (`NS.AnnounceSettingsChanged`: the write seam's tail, and `core/Database.lua`'s profile callbacks call it on a profile change) | `path, value` (`"profile", key` on a profile change) | `modules/Results.lua`: the footer's *Days to keep* on `global.history.keepDays`; `settings/History.lua`: repaints the Usage tab's hidden-items list on `global.usage.hidden` |

Six messages today; the Tier 2 `message-bus.md` trigger is more than ten. Race reaches its own
`modules/Watchers.lua` directly (`Watchers.Sync()` on every transition), not over the bus: the
watchers are the race's event wiring, and their registration set must follow the state on the same
call, with or without the bus library. The cast list (`modules/Casts.lua`) is fed the same way:
Watchers calls `Casts.Hear` and Race calls `Casts.Begin` / `Start` / `Stop` / `Reset`. The ability
timeline (`modules/Results_Timeline.lua`) holds no bus receiver: the detail pane tells it on every
draw and compare change (`ResultsTimeline.DetailChanged`). *Show cooldown icons* redraws through its
row's `onChange` (`Hud.Refresh`, `Results.Refresh`), not the bus.

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
| `test [armed\|running\|result]` | Static sample data in the HUD and the Results window: a bare `test` turns test mode on or off (the Master controls' *Test mode* row); a word holds that HUD body still |
| `sim [scenario]` | Play a whole sample race, then open the Results window on it; `newbest` (the default), `behind`, `first`, `incomplete`, `died`, `flagged`, `shared`; an unknown word lists them |
| `lock` / `unlock` | Write the *Lock frame* row (slash-commands-§8) |

The nine feature verbs follow `version` (spec §6.4). The dispatcher refuses each with the one
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
`PLAYER_REGEN_*` never clobber one another's handler), and the casts on a unit-filter frame whose
only job is `RegisterUnitEvent(..., "player"[, "pet"])` (events-frames-taint-§1's carve-out). Nothing is registered while the race is idle or showing a result, and nothing
while the addon is stood down: the stand-down calls `Watchers.Suspend()`, and the stand-up's
`Watchers.Resume()` rebuilds the set from the race's current state.

| Event | Registered | Handler | Why |
|---|---|---|---|
| `DAMAGE_METER_CURRENT_SESSION_UPDATED` | ARMED, RUNNING, STOPPING | `Race.OnSessionCreated` | the clock starts on the new session, in combat or with the regen edge on the same frame (spec §4.2); the first DamageDone update heard in combat starts it too (`Race.OnMeterUpdate`), for a session the meter made out of combat |
| `DAMAGE_METER_COMBAT_SESSION_UPDATED` | ARMED, RUNNING, STOPPING | `Race.OnMeterUpdate` | names the run's session; each update is a timeline stamp (tail, restart, quiet) |
| `DAMAGE_METER_RESET` | ARMED, RUNNING, STOPPING | `Race.OnMeterReset` | a run in progress becomes `lost` |
| `PLAYER_REGEN_DISABLED` / `_ENABLED` | ARMED, RUNNING, STOPPING | `Race.OnCombatStart` / `OnCombatEnd` | the target re-read; incomplete before the buzzer; the read's combat gate |
| `PLAYER_DEAD` | ARMED, RUNNING, STOPPING | `Race.OnDeath` | the `died` flag; incomplete before the buzzer |
| `UNIT_SPELLCAST_SUCCEEDED` (`player` and `pet`), `_CHANNEL_START` / `_CHANNEL_STOP` (`player`), on the unit-filter frame | ARMED, RUNNING, STOPPING | `Casts.Hear` for every cast, then `Race.OnCast` (with the castGUID) for the player's | the cast list (#14): a pre-pull cast is heard while armed (only the last 10 s before the clock starts are kept), and an open channel's ticks are deduped; from RUNNING `Race.OnCast` also judges them (it ignores a cast while armed) |
| `UNIT_SPELLCAST_START` / `_EMPOWER_START` / `_INTERRUPTED` (`player`, the unit-filter frame) | RUNNING, STOPPING | `Race.OnCast` (with the castGUID) | late casts after the grace (spec §5.2); an empowered cast is in flight from its start; an interrupt or a channel's stop closes the cast in flight |

`modules/Hud.lua` registers on its own AceEvent target only while the HUD window is on screen; hidden,
stood down or in test mode it holds nothing (spec §10). Its other timed work is not an event: the
countdown text is one `OnUpdate` on the window, attached only while the race is RUNNING (20 Hz) or
STOPPING (4 Hz: no clock, and combat may hold for minutes), and one `C_Timer` at the damage chart's
next bucket boundary while the window is shown and the race RUNNING (at most 60 a race, so a quiet
stretch still fills its bucket; one more read at the buzzer fills the last), and that is all.
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

`modules/Results.lua` registers no game event and no `OnUpdate`: it redraws from its bus receiver
(`RUN_SAVED`, `RUNS_CHANGED`, `SETTINGS_CHANGED`) and from the player's clicks, only while the window
is on screen. Its only timers are the talent tree's: a one-frame `C_Timer.After(0)` armed by `OnHide`
after a close from Blizzard's close-all-windows step (`CloseSpecialWindows`), and, while the tree is up,
a `C_Timer.NewTicker` polling it every `Results.TREE_POLL` (0.25) seconds, canceled when the tree closes
or the player opens or closes the window, so the window comes back once the tree is down (Taint Notes, B4.1).
`modules/Results_Timeline.lua` (the ability timeline) registers no game event and no `OnUpdate`: it
draws when opened and when the detail tells it. Its one timer is a one-frame `C_Timer.After(0)` armed by
its `OnHide` after a close-stack close (Escape), which lifts the Results window's dim cover once the
close stack is done and lets a talent tree that close made way for send the Results window aside.

**Window sizing.** All three windows (the Results window, the timeline and the HUD) are resized from
the library's corner grip through one pattern, `modules/Sizing.lua`: while the grip is held each size
change runs the window's cheap layout (re-anchor and resize what the new size needs, nothing rebound
or redrawn) at most once a frame, a second change in one frame waiting for a single
`C_Timer.After(0)` that only exists mid-drag; the release runs the window's full layout once and
stores the size, and so does a hide while the grip is held (no mouse-up follows one). The minimums and the stored sizes are as before; the timeline stores none (UT-P14: it opens over the Results window at that window's size every time). What runs per frame, before and
after: [performance.md](performance.md#window-sizing). A size change can also arrive in the middle of a
draw: the first row an open shows can resolve the window's rect and run its OnSizeChanged right there,
a full layout nested in the list's row loop. The Results lists' `Table:Bind` counts itself and stops
when a newer Bind ran inside it (and `fitRows` likewise), so no second set of rows is left shown that
the list does not hold, which the first drag after opening used to leave behind at the old column
positions (2026-10-27). `modules/Casts.lua` and `modules/Usage.lua`
register nothing: Watchers feeds the cast list, and Usage reads the client only at the arm and on the
record path after combat.

`modules/Preview.lua` (test mode and the sim) registers no game event either; combat ends it through
`NS:OnCombatChanged`. Test mode's views are still and hold no timer. While a sim plays its script
(`modules/Sim.lua`) it holds one `C_Timer` ticker at 10 Hz, canceled when the script opens the Results
window, when the sim ends or switches and at the stand-down. `modules/Share.lua`
and `settings/History.lua` hold only their bus receivers.

The pipeline from event to screen: [data-flow.md](data-flow.md).

## Frame layering

Every strata and level the addon sets reads one table, `NS.Constants.LAYERS` in
`core/Constants.lua` (frame-layering-§5); its header comment is the addon's whole stack, so it is not
copied here. The tiers by the standard's keys: `HUD` (the Race HUD, MEDIUM, toplevel), `WINDOW` (the
Results window, HIGH, toplevel), `MODAL` (the ability timeline, DIALOG, toplevel: opened from the Results
window, so one strata above it, and it re-raises a shown StaticPopup when it opens, frame-layering-§4) and
`SCREEN_ALERT` (the center-screen countdown, FULLSCREEN,
mouse-disabled, below the library's FULLSCREEN_DIALOG menus), with three level bands: `LEVEL.DETAIL`,
which lifts the Results detail pane over the Runs pane it sits inside, `LEVEL.CHART_OVERLAY`,
which lifts the damage chart's pace diagonal (and its cooldown icons) over its columns, and
`LEVEL.COVER` (W+30, the standard's popover band), the Results window's dim cover while the timeline is
open: a black texture at 0.45 alpha over the whole window whose frame takes the mouse and the wheel over
the grip and every content level, so nothing behind the timeline answers a hover or a click (a click on
it does nothing). Escape closes the timeline first: the close stack hides both, and the Results window's
`OnHide` shows it again while the cover is up; the cover goes a frame later. The timeline wears the
shared skin made opaque (`ResultsTimeline.SKIN`: the fill at alpha 1, the inner border and divider
blended over it to alpha 1). The StaticPopups, the debug console,
the perf panel, the dropdown menu and the tooltips are Blizzard's or the library's. `test_layers` and
`test_results_timeline_modal` pin each frame's strata, level and toplevel, and the cover.

## Taint Notes

- The addon creates no secure frame and calls no protected API. The three key-binding buttons
  (`DpsRaceToggleHud`, `DpsRaceToggleResults`, `DpsRaceArmToggle`) are plain, hidden and not secure
  (launcher-§6).
- Share sends one chat line from a menu click (a hardware event), through `NS.Compat.ChatSender()` (`C_ChatInfo.SendChatMessage`)
  with the old global beneath it, and only out of combat and out of the client's chat lockdown. The
  line is plain text with every `|` replaced, so no chat escape reaches a channel.
- The HUD's *Stop Now*, *Cancel* and *Delete* (Round C) are plain buttons on the plain HUD frame and
  call only the addon's own engine and the Results window's StaticPopup (`DPSRACE_DELETE_RUN`): no
  protected call, so all three work in combat. *Stop Now* decides from the press, the combat flag and
  `GetTime()`, never from a meter value.
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
  asks of one is `== nil`. The damage chart and the pace bar (`modules/Hud_Chart.lua`, #2, #3) are
  the same seam: each bucket's handle (`modules/Slices.lua`, copied, never inspected) and the live
  total go to `SetValue`, and a scale with no best is the live total itself through
  `SetMinMaxValues`; the pace bar's range and the pace diagonal are plain numbers from the stored
  best and `GetTime()`, and the pace bar's red and green are where the client ends each half's fill
  (the red shortfall is a texture anchored to the behind half's fill texture: no value is compared) (the result card's pace bar is all plain: a stored run's final damage against
  the best before it, and so is the chart after the race, the best's diagonal and the shared max
  included), and the columns' edges are plain config math (whole pixels from the plot's
  width and the *Column gap* setting). The HUD window is a plain non-secure frame, so it opens and redraws in
  combat (standalone-windows); its only geometry read is its own anchor on drag stop, and the shell
  never displays a value.
- The Results window is plain and non-secure too, and opens in combat. It never holds a meter value:
  it draws stored run records, whose numbers went through `NS.Secrets` on their way into the store
  (or, in test mode and the sim, `modules/MockRuns.lua`'s plain sample records),
  so its sorting, percentages and timing-strip positions are plain Lua. It still lays out from
  config; its only geometry read is its own anchor on drag stop.
- The center-screen countdown (`modules/Countdown.lua`) draws on its own plain frame with its own
  textures cut from Blizzard's BigGold digit sheet. It never calls `C_PartyInfo.DoCountdown` (that
  broadcasts a pull timer to the group) nor any `TimerTracker` handler, and `test_countdown` scans for both.
- The detail's *View* (#6) opens the talent tree from addon code, an ACCEPTED RISK (the owner's
  call, 2026-10-25). It calls `SetItemRef` with the stored `talentbuild` link, which shows the talent
  frame (`PlayerSpellsFrame`) from this addon's execution, and it also prints the same link into the
  player's own chat window (`NS.Print`). The frame's `OnShow` writes the action bars' show-grid
  state, so that state is written tainted, and a later in-combat slot change (a proc or an override)
  can fail in `Blizzard_ActionBar`'s `UpdateShownButtons` with `[ADDON_ACTION_BLOCKED] AddOn
  'DpsRace' tried to call the protected function 'MultiBarRightButton1:SetShown()'`, as the owner
  once saw in game. For a few hours on 2026-10-25 *View* only posted the chat link (a click on a chat
  link goes through Blizzard's own hyperlink handling and avoids it); the owner preferred the direct
  open, and the posted link stays as the taint-free way to open the tree. `test_loadout` pins both
  the `SetItemRef` call and the chat line; smoke row SM-DR-LO4 repeats the in-combat check. The other two paths
  that reach a Blizzard frame stay: *Dressing Room* calls `DressUpItemLink` (it opens
  `DressUpFrame`, which touches no action bar) and the gear grid's modified click goes to the
  client's own `HandleModifiedItemClick`; both remain smoke-checked (SM-DR-LO3, SM-DR-LO2). The item
  tooltips are `GameTooltip:SetHyperlink` on a stored link.
- **The Results window steps aside for the talent tree and comes back when it closes (B4.1).**
  Blizzard shows `PlayerSpellsFrame` (the *View* link's click, or the N key) through
  `ShowUIPanel`; with no other panel up its `centerOrLeft` area resolves to `center`, and
  `FramePositionDelegate:ShowUIPanel` runs `CloseWindows`, whose `CloseSpecialWindows` hides every
  `UISpecialFrames` entry, this window and the HUD among them, before the tree shows
  (`Blizzard_UIParentPanelManager`, `Blizzard_PlayerSpells`). The window stays in `UISpecialFrames`
  (standalone-windows), is never added to `UIPanelWindows`, sets no `UIPanelLayout-*` attribute and
  hooks nothing: its `OnHide` answers a close-stack close made while the tree was down with a
  one-frame `C_Timer.After(0)` look, and if the tree is up by then it waits (a `C_Timer.NewTicker`
  polling `IsShown` every `Results.TREE_POLL` seconds) and shows itself again once the tree is
  down (the owner's call, 2026-10-25: the tree on top, the window back after). When *View* opens the
  tree while another panel was already up (no close stack), `Results.StepAsideForTree` hides the
  window and waits the same way. The player opening or closing the window ends the wait. The one
  read of a Blizzard frame is `PlayerSpellsFrame:IsShown()`; `test_results_tree` pins the close
  paths and the wait, and `test_results` scans the module for `UIPanelWindows`, `UIPanelLayout`,
  `ShowUIPanel(` and `hooksecurefunc`.
- **The cast list and the usage (#13, #14) read only the player's own data, and store only plain
  values.** `modules/Casts.lua` takes each `UNIT_SPELLCAST_*` spell ID and castGUID through
  `Secrets.PlainNumber` / `PlainString` (the probe of 2026-10-26 measured both plain in combat for the
  player and the pet, in the open world); a sealed ID is dropped and counted in `casts.dropped`. A
  spell's base cooldown comes from `GetSpellBaseCooldown` (pcall'd, through `PlainNumber`; plain in
  and out of combat per the probe); `C_Spell.GetSpellCooldown`, secret in combat, is never called.
  `modules/Usage.lua` reads the gear, the bags and the auras only at the arm
  (which is refused in combat) and the bag counts again on the record path after combat, each client
  call bare at call time and pcall'd, every value through `NS.Secrets`; it does not compare item
  cooldowns. The chart's cooldown icons and the timeline's lanes and cast icons are plain geometry: a cast's plain
  time over the plain length across the configured width (`HudChart.IconX`, `ResultsTimeline.MarkX`),
  never read back off a frame. The chart's icons (C_Spell's texture for the plain stored or live ID)
  take the mouse wherever the chart is drawn, the running HUD included (a plain, non-secure frame),
  and like the timeline's hover frames show tooltips built from plain cast records (the timeline's name cell and cast icons the client's
  spell tooltip by the stored ID). The timeline window is plain and non-secure like the Results
  window, in `UISpecialFrames`, and its only geometry read is its own anchor on drag stop. Neither
  window's `UISpecialFrames` entry is ever removed or rewritten for the modal's Escape order (a write to
  that shared table from addon code would taint Blizzard's own entries): the Results window shows
  itself again from its own `OnHide` instead. Its re-raise of a shown StaticPopup is the library's
  `RaiseStaticPopups` (`Raise` only, pcall'd).
- The diagnostics report is read-only and runs in combat; every value goes through `SafeToString`.

## Known Limitations

The full list, each with its reason: [known-limitations.md](known-limitations.md). The ones that
shape the design most:

- **No exact cutoff at the buzzer**, and the live breakdown can never show percentages or sort:
  meter values captured in combat stay secret (spec §2, §5.1, §6.1).
- **The damage chart is this session's only** (#2), because a secret is written to SavedVariables
  as `nil`; the chart and the pace bar **compare by eye only** (#3), against the best's average pace.
- **Unmeasured client behavior** is the spec's open items O1 to O7 and the client assumptions C1 to
  C26, closed in the owner's smoke-test pass.
- **The Results window steps aside while the talent tree is open** (B4.1): the window is an
  on-demand browser at `HIGH` and the tree a `MEDIUM` UI panel, so the tree cannot draw over it;
  the window hides while the tree is up and comes back when it closes (the owner's call).
- **Casts and usage were measured in the open world only, and part of the usage is a rule** (#13,
  #14): a channel's ticks are deduped defensively, only the last 10 s before the pull are kept, food
  is the *Well Fed* aura's enUS name (never detected on another client language), a consumable that
  leaves the bags while armed reads as used, a pair of one on-use item is detected on its first slot
  only, and a run from before format 3 (or resumed after a `/reload`) has neither list.

## Documentation map

Frozen and generated stores are named once each and not enumerated: `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`,
`docs/revendor/<date>-v<tag>/`, `docs/superpowers/` and `docs/investigations/` (documentation-§3).
Of those, `docs/automated-tests/<run>/`, `docs/revendor/<date>-v<tag>/` and `docs/superpowers/`
exist today; `docs/superpowers/` holds the spec and the plans.

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
| `slash-dispatch.md` | Present | 22 commands in `NS.COMMANDS` (eight or more) |
| `profiles.md` | Present | A Profiles page ships in the options UI (`settings/Profiles.lua`) |
| `debug.md` | Present | The diagnostics report ships (always fired) |
| `midnight-quirks.md` | Not applicable | No client-version workaround of the addon's own: the secret guards are LibKa0s-Compat-1.0's, routed from `core/Compat.lua`, and the shims there are API ladders, not behavior workarounds; re-check when one is added |
| [`compat-layer.md`](compat-layer.md) | Present | `core/Compat.lua` publishes four hand-written shims (`CanAccessTable`, `ChatSender`, `NewNumberFormatter`, `PopupEditBox`); the trigger is three or more |
| `message-bus.md` | Not applicable | 6 messages in `NS.MSG` (the trigger is more than ten) |
| [`known-limitations.md`](known-limitations.md) | Present | Known Limitations passed ~60 lines (2026-10-25); the hub keeps a summary |
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
| `standalone-windows` (MUST persist window position and size in SavedVariables, restored on open) | The ability timeline (`modules/Results_Timeline.lua`) stores neither: every open places it exactly over the Results window, that window's anchor and its size in the view shown (`Results.Placement`), clamped to the timeline's minimums; a move or a resize lasts while it is open. `profile.windows.timeline` is gone from the defaults and nothing writes it. The Results window and the HUD persist theirs as before | The owner asked on 2026-10-27 (UT-P14, the fifth test round) for the timeline to always open centered over the Results window at that window's dimensions in its expanded or collapsed view, so it overlays it exactly. Since P13 it is a modal over the Results window (frame-layering T6), not a main window kept up on its own, and a stored place would put it off the window it covers | 2026-10-27, accepted by the owner as a deviation (not an upstream change) | The standard carves modals over their opener out of the persistence rule (then this row goes), or the timeline becomes a window kept open on its own again |
| `standalone-windows` | The close control is built through the one wrapper (`NS.MakeCloseButton`, the catalog's `close` mark, gray at rest) but its hover tint is the header gold, not the library's red: `modules/Style.lua` hooks the control's enter and leave (after the library's own) and repaints it with the HUD's other title-bar controls. The wrapper, the mark, the grep gate and the rest color are unchanged | The owner asked on 2026-10-24 for every title-bar control, close included, to turn gold under the pointer as MultiMeters' strip does; a red close beside three gold controls reads as two hover rules in one strip. The four-condition decline does not apply: the library still draws the control | 2026-10-24 | `LibKa0s-Core-1.0` `MakeCloseButton` takes a hover color, or the standard names the hover tint of a host's title-bar strip; or the owner prefers the red back |

### Files over the 1500-line cap

Nothing is over the cap today. Eight files are in the 1000–1500 on-notice band: two test files,
`tests/test_results.lua` at 1495 lines (the next Results suite goes in a new file, as
`test_results_group`, `test_results_fit`, `test_results_tree`, `test_results_badges`,
`test_results_usage`, `test_results_timeline`, `test_results_timeline_zoom`,
`test_results_timeline_modal`, `test_results_timeline_view`, `test_results_timeline_scroll`, `test_results_timeline_controls`, `test_results_delta` and
`test_results_sections` did)
and `tests/test_hud.lua` at 1413 (the waiting hint box's cases went to a new `test_hud_hint`), and
six addon files, `modules/Results_Table.lua` at 1206 lines (a Bind nested in another stops, the
first-drag fix, 2026-10-27; the spell tooltip under its owner, 2026-10-28), `modules/Results_Timeline.lua` at 1420 (the zoom and the modal, then the scrollbar and the placement over the Results window, then the scroll arrows, 2026-10-27, then Ctrl+wheel, the `?` and the corridor colors, 2026-10-28; its suite's
P12, P13, P14, P15 and P16 cases went to new `test_results_timeline_zoom`, `test_results_timeline_modal`, `test_results_timeline_view`, `test_results_timeline_scroll` and `test_results_timeline_controls` suites; the next round's window parts go to a new module), `modules/Results_Detail.lua` at 1176
(the detail's collapsible sections, 2026-10-26, and the flags box under its heading, 2026-10-27), `modules/Hud_States.lua` at 1119,
`modules/Results_Runs.lua` at 1085 (the detail's Delta box contexts, 2026-10-26; the filter bar stretched to the window, 2026-10-28) and
`modules/Hud.lua` at 1036 (layout-§1); the 2026-10-25 passes put their new parts in their own modules (`Hud_Chart`,
`Results_Compare`, `Results_Loadout`, `Slices`, `Loadouts`, then `Results_Source`, `MockRuns`, `Sim`),
and the 2026-10-26 pass its own (`Casts`, `Usage`, `Results_Usage`, `Results_Timeline`), rather than
grow these.
