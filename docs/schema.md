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
| `scale` | `1.0` | *Master scale* | The scale of both windows: the HUD (`modules/Hud.lua`) and the Results window (`modules/Results.lua`) |
| `locked` | `false` | *Lock frame* | The HUD's lock: no drag, no resize grip (`Hud.SetLocked`) |
| `race.grace` | `1.0` | *Late-cast grace (seconds)*, Race page | Seconds after the buzzer before a cast start is late (spec §5.2); copied onto each new run |
| `race.restartGap` | `6` | *Damage-restart gap (seconds)*, Race page | Seconds of quiet after the buzzer before damage counts as restarted (spec §5.3); copied onto each new run |
| `race.defaultLength` | `180` | *Default race length*, Race page | The HUD's race length until the player picks one (spec §4.1) |
| `race.countdownCue` | `true` | *Countdown cue sound*, Race page | The cue sound at 10, 5, 3, 2 and 1 s left, and with each center-screen number, once a second at most (spec §4.3) |
| `race.centerCountdown` | `true` | *Center-screen countdown*, Race page | The large numbers in the middle of the screen for the race's last seconds (spec §4.3, `modules/Countdown.lua`) |
| `race.finalCountdown` | `10` | *Center countdown from (seconds)*, Race page (3-10, step 1) | Seconds left when the center numbers start |
| `race.buzzer` | `true` | *Buzzer raid warning and sound*, Race page | The raid-warning STOP and its sound at the buzzer (spec §4.4) |
| `race.hintDelay` | `15` | *Sticky-combat hint after (seconds)*, Race page (5-60) | Seconds in combat after the buzzer before the HUD's drop-combat hint (spec §4.4) |
| `live.rows` | `8` | *Spell rows shown*, HUD page, Race HUD tab | Spells in the live breakdown, 0-15; 0 is every spell, wheel-scrolled |
| `live.icons` | `true` | *Show spell icons*, HUD page, Race HUD tab | Spell icons on the HUD's rows |
| `live.showDps` | `true` | *Show live DPS*, HUD page, Race HUD tab | Blizzard's live DPS figure, labeled *live* |
| `live.hz` | `4` | *Live reads per second*, HUD page, Race HUD tab | Live reads per second, 2-10 (spec §10) |
| `hud.showMode` | `"onArm"` | *Show the race HUD*, HUD page, Race HUD tab | `onArm`: the HUD opens on arm and on a result, and closes again when the race it opened for goes idle; `always`: also open at login |
| `hud.clock` | `"both"` | *Race clock*, HUD page, Race HUD tab | What the running body's clock shows (spec §6.1): `both` (elapsed in green beside time left in red), `left` (time left, red) or `elapsed` (time elapsed, green) |
| `windows.hud.width` / `.height` | `300` / `460` | none (geometry) | The HUD's size, tall enough for the default 8 live rows (mockup screen 04); the minimum is 260x296 (`Hud.MIN_HEIGHT`: the chrome plus `HudStates.MinContentHeight()`, the tallest body's fixed stack; the spec's 240 could not hold the idle body), in `modules/Hud.lua` |
| `windows.results.view`, `.expanded`, `.collapsed` | `"expanded"`; `{ width = 1220, height = 560 }`; `{ width = 900, height = 560 }` | none (geometry; the title bar's view toggle) | The Results window's view and each view's own size (the owner's call, 2026-10-25). Each view's minimum (expanded 1180, collapsed 800; 420 high) is `Results.VIEWS` in `modules/Results.lua`. Only the toggle switches views; a resize never does. Its scale is the Master controls' `scale` |
| `appearance.elapsed.*` / `.left.*` / `.figures.*` / `.spellText.*` | `font`, `fontSize`, `fontColor`, `useClassColorFont`, `fontFlags`, `fontShadow` (see `defaults/Profile.lua`) | the composed font blocks, HUD page, HUD Appearance tab | The running clocks, the live figures and the spell rows' text (`modules/Hud_Appearance.lua`) |
| `resultsTable.damageBar.*` / `.dpsBar.*` / `.barText.*` | the bar blocks (both the spell breakdown's indigo at 85%), the font block | the composed groups, History page, Results table tab | The Runs list's Damage and DPS bars and their text; each class color is the run's character's |
| `appearance.bars.*` | `barTexture` `"Solid"`, `barAlpha` `0.85`, `barColor`, `useClassColorBar` `false`, `rowHeight` `18` | the composed bar block and *Row height*, HUD page, HUD Appearance tab | The spell rows' fill and height, on the HUD and in the Results window's breakdown |

Every `race.*`, `live.*`, `hud.showMode` and `hud.clock` key has its row; `race.lastLength` is state, below.

### Global (`db.global`)

| Path | Default | What it is |
|---|---|---|
| `schemaVersion` | `0` | The migration stamp. The default is 0, never the current version, so AceDB does not strip it and backfill it onto an old account (savedvariables-§1) |
| `schema` | `1` | The run-record format (spec §7). Not a migration stamp: each stored run carries its own copy |
| `runs` | `{}` | The run store, keyed by run id. Global so a profile switch never hides a character's history and bests span alts |
| `history.keep` | `0` | *Runs to keep* (spec §6.3): 0 = never prune. Above 0, `Recorder.Prune` removes the oldest resolved runs at login and after each saved run, never one holding a best (all-runs or clean-only board) and never a running or stopping one. Its row is *Runs to keep* on the History page (0-10000); a change prunes nothing on the spot |
| `minimap` | `{ hide = false }` | LibDBIcon's own table, handed straight to `:Register` (launcher-§3) |

### Session-only (never persisted)

| State | Where | Why session-only |
|---|---|---|
| Debug logging flag | `NS.State.debug` (`core/State.lua`) | debug-logging-§5 |
| Test mode | `NS.Preview` (`modules/Preview.lua`), through the `state.testMode` row (`default = false`, so *Reset all settings* ends it) | preview-mode: on until turned off, ended by combat, by arming a real race and by closing the HUD; its sample run is never stored |
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

Format 1, exactly as spec §7 lays it out: `id`, `schema`, `status`, `addon`, `build`, `date`,
`race`, `char`, `target`, `where`, `result`, `flags`, `spells`, `note`. `status` is one of
`armed` (never stored), `running`, `stopping`, `complete`, `incomplete` or `lost`. Every value is
plain: each client value went through `NS.Secrets`, and a sealed one is absent.

| Part | Fields | Written by |
|---|---|---|
| top | `id` (`time()-NNNN`), `schema`, `status`, `addon`, `build`, `date` (arm, restamped at the start) | `Recorder.NewRun`; `Race` |
| `race` | `length`, `grace`, `restartGap` (frozen at arm), `startSource`, `startedAt` (`GetTime()` at the start), `sessionID`, `armMaxSession` (the highest session ID at arm), `lastDamage` (s after the start of the last damage update) | `Recorder.NewRun`; `Race` at arm, start, capture and each update |
| `char`, `where` | the player and place snapshots | `Recorder.NewRun` (at arm) |
| `target` | `npcID`, `name`, `category`, `count`, `level`, `classification` | `Recorder.NewRun`; re-read once at combat start (`Recorder.SnapshotTarget` with the arm-time `prior`) |
| `result` | `damage`, `dps`, `meterDps`, `sessionDuration`, `tail`, `combatEnd` (s after the buzzer), `endedAt` (incomplete: s after the start); absent on a lost run | `Race` |
| `flags` | `lateCasts` (`{ t, spellID? }`), `restartedAt`, `reloaded`, `died`, `sessionFromList`, `sharedSession` (the pull carried on a session from before the arm; netted against `race.baseline`) | `Race` |
| `spells` | `{ id, dmg, dps }`, highest first | `Race`, from `Meter.ReadSession` |
| `note` | trimmed, control characters as spaces, `\|` as `/`, at most 200 UTF-8 characters (`ResultsDetail.ClampNote`) | `Recorder.SetNote` |

The grace and restart gap in force are copied onto each run, so a settings change never re-grades an
old one. Spell names and icons are resolved for display and never stored. About 1 to 1.5 KB per run.

A change to the record's shape raises `global.schema` and adds a migration step that rewrites stored
runs; a reader that meets a run with a higher `schema` than it knows leaves it alone.

## Named non-setting state

State written outside the write seam, which no control sets (architecture-§5). Each has one owner
and a closed list of writers.

| Storage key | Owner | Writers |
|---|---|---|
| `global.runs` | `modules/Recorder.lua` | `Recorder.Save` (Race, at the start, the session capture, the buzzer and the result), `Recorder.SetNote` (the Results detail's note), `Recorder.Delete` (the detail's *Delete*), `Recorder.DeleteAll` (the History page's *Purge history…*), `Recorder.Prune` (through `Bests.PruneToSetting`, at login and after each saved run) |
| `global.schemaVersion` | `core/Database.lua` | `NS:RunMigrations` |
| `global.minimap` (position fields) | `core/LauncherSetup.lua` | LibDBIcon's own drag handler (a vendored library's writes); `hide` is the *Minimap button* row and goes through the seam via `NS.Launcher:SetShown` |
| `DpsRacePerfDB` | `core/PerfSetup.lua` | `LibKa0s-Perf-1.0` (`/dr perf finish`) |
| `profile.windows.hud` (`point`, `relativePoint`, `x`, `y`, `width`, `height`) | `modules/Hud.lua` | the HUD's drag stop (position) and resize grip (size); `Hud.ResetPosition` clears them (the Master controls' *Reset position*) |
| `profile.race.lastLength` | `modules/Hud.lua` | `Hud.Act.pickLength` / `customLength`, and `/dr arm <length>` through `Hud.Act.pickLength`: the last race length picked, offered next (spec §4.1). No default: absent means `race.defaultLength`. Cleared (with the HUD's session pick) when `race.defaultLength` changes, through `Hud.ForgetLength`, so a new default takes effect |
| `profile.views.runs` (`filters`, `sortKey`, `sortDesc`) | `modules/Results_Runs.lua` | the Runs tab's *Save* (`View:SaveView`, the view now) and *Reset* (`View:ResetView`, deletes it); read by every build of the tab (`Runs.SavedView`) and by *Clear*. Absent means the stock view (`Runs.DEFAULTS`, newest first) |
| `profile.windows.results` (`point`, `relativePoint`, `x`, `y`, `view`, `expanded`, `collapsed`) | `modules/Results.lua` | the window's title-bar drag stop (position), its view toggle (`Results.SetView`) and the resize grip (the shown view's size); `Results.ResetPosition` clears the position and both sizes and keeps the view (the Master controls' *Reset position*) |

The Results window's filters, sort, selected run and tab are session-only view state and are not
stored.
