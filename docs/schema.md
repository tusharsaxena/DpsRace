# Schema

What Ka0s DPS Race persists, every default, and how each format changes (savedvariables). The hub's
*Settings Schema* section spills here, so the register of named non-setting state at the bottom is
the complete one (architecture-§5).

## SavedVariables

The TOC declares two (savedvariables-§4):

| Variable | Owner | What it holds |
|---|---|---|
| `DpsRaceDB` | AceDB (`core/Database.lua`, `NS:InitDB`) | `profiles`, `profileKeys` and `global`, below |
| `DpsRacePerfDB` | `LibKa0s-Perf-1.0` (`core/PerfSetup.lua`) | the performance-capture ring, outside the AceDB tree (performance-§5) |

## Defaults

`defaults/Profile.lua` is the only place a default is written (savedvariables-§2). Every schema
row's `default` reads from it.

### Profile (`db.profile`)

| Path | Default | Row | Notes |
|---|---|---|---|
| `enabled` | `true` | *Enable Ka0s DPS Race* | Takes or releases the latch's `disabled` hold |
| `visibility` | `"always"` | *General visibility* | `always`, `inCombat`, `outOfCombat` or `never` |
| `scale` | `1.0` | *Master scale* | The HUD window's scale (`modules/Hud.lua`): the HUD is the addon's positionable display |
| `locked` | `false` | *Lock frame* | The HUD's lock: no drag, no resize grip (`Hud.SetLocked`) |
| `race.grace` | `1.0` | none yet (T9) | Seconds after the buzzer before a cast start is late (spec §5.2); copied onto each new run |
| `race.restartGap` | `6` | none yet (T9) | Seconds of quiet after the buzzer before damage counts as restarted (spec §5.3); copied onto each new run |
| `race.defaultLength` | `180` | none yet (T9) | The HUD's race length until the player picks one (spec §4.1) |
| `race.countdownCue` | `true` | none yet (T9) | The cue sound at 10, 5, 3, 2 and 1 s left (spec §4.3) |
| `race.buzzer` | `true` | none yet (T9) | The raid-warning STOP and its sound at the buzzer (spec §4.4) |
| `race.hintDelay` | `15` | none yet (T9) | Seconds in combat after the buzzer before the HUD's drop-combat hint (spec §4.4) |
| `live.rows` | `8` | none yet (T9) | Spells in the live breakdown, 3-15 |
| `live.icons` | `true` | none yet (T9) | Spell icons on the HUD's rows |
| `live.showDps` | `true` | none yet (T9) | Blizzard's live DPS figure, labeled *live* |
| `live.hz` | `4` | none yet (T9) | Live reads per second, 2-10 (spec §10) |
| `hud.showMode` | `"onArm"` | none yet (T9) | `onArm`: the HUD opens on arm and on a result, and closes again when the race it opened for goes idle; `always`: also open at login |
| `windows.hud.width` / `.height` | `300` / `360` | none (geometry) | The HUD's size; the minimum 260x240 is the spec's, in `modules/Hud.lua` |

T9 adds the rows for `race.*`, `live.*` and `hud.showMode`; until then `NS.GetSetting` answers their
defaults. T8 adds `windows.results`.

### Global (`db.global`)

| Path | Default | What it is |
|---|---|---|
| `schemaVersion` | `0` | The migration stamp. The default is 0, never the current version, so AceDB does not strip it and backfill it onto an old account (savedvariables-§1) |
| `schema` | `1` | The run-record format (spec §7). Not a migration stamp: each stored run carries its own copy |
| `runs` | `{}` | The run store, keyed by run id. Global so a profile switch never hides a character's history and bests span alts |
| `history.keep` | `0` | *Runs to keep* (spec §6.3): 0 = never prune. Above 0, `Recorder.Prune` removes the oldest resolved runs at login and after each saved run, never one holding a best (all-runs or clean-only board) and never a running or stopping one. T9 adds the History page's row |
| `minimap` | `{ hide = false }` | LibDBIcon's own table, handed straight to `:Register` (launcher-§3) |

### Session-only (never persisted)

| State | Where | Why session-only |
|---|---|---|
| Debug logging flag | `NS.State.debug` (`core/State.lua`) | debug-logging-§5 |
| Test mode | `NS.Preview` (`modules/Placeholders.lua`, T9's `modules/Preview.lua`) | preview-mode: on until turned off, ended by combat |
| Debug console shown | the console itself, through the `state.debugConsole` row | a window toggle, not a setting |

## Migrations

`core/Database.lua` holds `NS.SCHEMA_VERSION` (the runner's target) and an ordered `STEPS` list.
`NS:RunMigrations()` runs in `OnInitialize` before anything reads `db.profile`, applies every step
whose `to` is above the stored `schemaVersion`, and stamps it after each step returns. A
profile-scoped step sets `perProfile = true` and runs once per stored profile.

| Version | Step | What it does |
|---|---|---|
| 0 → 1 | pre-versioning | Nothing: a fresh install and the first release share one shape |

Adding a step: [common-tasks.md](common-tasks.md#add-a-saved-variables-migration).

## The run record

Format 1, exactly as spec §7 lays it out (`id`, `schema`, `status`, `addon`, `build`, `date`,
`race`, `char`, `target`, `where`, `result`, `flags`, `spells`, `note`). `status` is one of
`armed` (never stored), `running`, `stopping`, `complete`, `incomplete` or `lost`. The grace and
restart gap in force are copied onto each run, so a settings change never re-grades an old one.
Spell names and icons are resolved for display and never stored. About 1 to 1.5 KB per run.

A change to the record's shape raises `global.schema` and adds a migration step that rewrites stored
runs; a reader that meets a run with a higher `schema` than it knows leaves it alone.

## Named non-setting state

State written outside the write seam, which no control sets (architecture-§5). Each has one owner
and a closed list of writers.

| Storage key | Owner | Writers |
|---|---|---|
| `global.runs` | `modules/Recorder.lua` | `Recorder.Save`, `Recorder.Delete`, `Recorder.DeleteAll`, `Recorder.Prune` (T6); a run's `note` through `Recorder.Save` from the Results detail pane (T8) |
| `global.schemaVersion` | `core/Database.lua` | `NS:RunMigrations` |
| `global.minimap` (position fields) | `core/LauncherSetup.lua` | LibDBIcon's own drag handler (a vendored library's writes); `hide` is the *Minimap button* row and goes through the seam via `NS.Launcher:SetShown` |
| `DpsRacePerfDB` | `core/PerfSetup.lua` | `LibKa0s-Perf-1.0` (`/dr perf finish`) |

| `profile.windows.hud` (`point`, `relativePoint`, `x`, `y`, `width`, `height`) | `modules/Hud.lua` | the HUD's drag stop (position) and resize grip (size); `Hud.ResetPosition` clears them (the Master controls' *Reset position*) |
| `profile.race.lastLength` | `modules/Hud.lua` | `Hud.Act.pickLength` / `customLength`: the last race length picked on the HUD, offered next (spec §4.1). No default: absent means `race.defaultLength` |

T8 adds `profile.windows.results`, owned by the Results window.
