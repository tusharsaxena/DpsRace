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
| `scale` | `1.0` | *Master scale* | The HUD's scale (T7) |
| `locked` | `false` | *Lock frame* | The HUD's position lock (T7) |

T9 adds `race.*` (default length, countdown cue, buzzer, grace, restart gap, hint delay), `live.*`
(rows, icons, live DPS, read rate) and `hud.*`; T7 and T8 add `windows.<name>` geometry. Each lands
here with its task.

### Global (`db.global`)

| Path | Default | What it is |
|---|---|---|
| `schemaVersion` | `0` | The migration stamp. The default is 0, never the current version, so AceDB does not strip it and backfill it onto an old account (savedvariables-§1) |
| `schema` | `1` | The run-record format (spec §7). Not a migration stamp: each stored run carries its own copy |
| `runs` | `{}` | The run store, keyed by run id. Global so a profile switch never hides a character's history and bests span alts |
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
| `global.runs` | `modules/Recorder.lua` (T3; not in the tree yet) | `Recorder.Save`, `Recorder.Delete`, `Recorder.DeleteAll`, `Recorder.Prune` (T6); a run's `note` through `Recorder.Save` from the Results detail pane (T8) |
| `global.schemaVersion` | `core/Database.lua` | `NS:RunMigrations` |
| `global.minimap` (position fields) | `core/LauncherSetup.lua` | LibDBIcon's own drag handler (a vendored library's writes); `hide` is the *Minimap button* row and goes through the seam via `NS.Launcher:SetShown` |
| `DpsRacePerfDB` | `core/PerfSetup.lua` | `LibKa0s-Perf-1.0` (`/dr perf finish`) |

T7 and T8 add `profile.windows.<name>` (position, size and scale written by a drag or a resize),
owned by the window module that draws it.
