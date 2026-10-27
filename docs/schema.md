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
| `scale` | `1.0` | *Master scale* | The scale of every window: the HUD (`modules/Hud.lua`), the Results window (`modules/Results.lua`) and the ability timeline (`modules/Results_Timeline.lua`, applied on each draw) |
| `locked` | `false` | *Lock frame* | The HUD's lock: no drag, no resize grip (`Hud.SetLocked`) |
| `race.grace` | `1.0` | *Late-cast grace (seconds)*, Race page | Seconds after the buzzer before a cast start is late (spec §5.2); copied onto each new run |
| `race.restartGap` | `6` | *Damage-restart gap (seconds)*, Race page | Seconds of quiet after the buzzer before damage counts as restarted (spec §5.3); copied onto each new run |
| `race.defaultLength` | `120` | *Default race length*, Race page | The HUD's race length until the player picks one (spec §4.1) |
| `race.autoArm` | `false` | *Arm on a training dummy*, Race page (*Auto-arm*) | Targeting a cataloged training dummy out of combat arms a race at the HUD's length; targeting anything else before the pull cancels it (#16, `modules/AutoArm.lua`). Opt-in. New key: AceDB's default fills it, no migration |
| `race.countdownCue` | `true` | *Countdown cue sound*, Race page | The cue sound at 10, 5, 3, 2 and 1 s left, and with each center-screen number, once a second at most (spec §4.3) |
| `race.centerCountdown` | `true` | *Center-screen countdown*, Race page | The large numbers in the middle of the screen for the race's last seconds (spec §4.3, `modules/Countdown.lua`) |
| `race.finalCountdown` | `10` | *Center countdown from (seconds)*, Race page (3-10, step 1) | Seconds left when the center numbers start |
| `race.buzzer` | `true` | *Buzzer raid warning and sound*, Race page | The raid-warning STOP and its sound at the buzzer (spec §4.4) |
| `race.hintDelay` | `15` | *Sticky-combat hint after (seconds)*, Race page (5-60) | Seconds in combat after the buzzer before the HUD's drop-combat hint (spec §4.4) |
| `live.rows` | `8` | *Spell rows shown*, HUD page, Race HUD tab | Spells in the live breakdown, 0-15; 0 is every spell, wheel-scrolled |
| `live.icons` | `true` | *Show spell icons*, HUD page, Race HUD tab | Spell icons on the HUD's rows |
| `live.showDps` | `true` | *Show live DPS*, HUD page, Race HUD tab | Blizzard's live DPS figure, labeled *live* |
| `live.hz` | `4` | *Live reads per second*, HUD page, Race HUD tab | Live reads per second, 2-10 (spec §10) |
| `live.chart` | `true` | *Show damage chart*, HUD page, Race HUD tab | The running HUD's damage chart (#2), and the result card's after the race (against the best before the run when there is one: its diagonal and the shared max); hidden on a shared session (`modules/Hud_Chart.lua`) |
| `live.castDots` | `true` | *Show cooldown icons*, HUD page, Race HUD tab | The ability's icon along the top of the damage chart at each cast of an ability whose base cooldown is 29 s or more (#14, `Casts.IMPORTANT_MS`): live on the running HUD (`Casts.Live()`), on the result card and in the Results detail (the run's `casts`); a later icon that would overlap the one before it takes the first row below with room (as many as the plot holds: its height and the one icon row it keeps on top, over the columns), a crowd past the last row a *+n* mark listing its casts, and hovering one names the spell and its time in all three. Off hides them in all three (`modules/Hud_Chart.lua`). The path keeps the first look's name (dots) |
| `live.paceBar` | `true` | *Show pace bar*, HUD page, Race HUD tab | The running HUD's pace bar against the board's best (#3), and the result card's (the final damage against the best before the run); hidden with no best, on a shared session and on a lost run's card |
| `live.paceRange` | `1.5` | *Pace bar range*, HUD page, Race HUD tab (1.1-2.0, step 0.05) | How far either side of the best's pace so far the pace bar reaches: pace x (2 - range) to pace x range (`HudChart.PaceBounds`, Round C; 1.1-3.0 with the tick at 1/range before it, and 2 as a plain right end before 2026-10-25); the tick sits in the middle; a stored value above 2.0 is clamped at read time |
| `share.talentsLink` | `false` | *Include talents link*, History page, History tab (*Sharing*) | Appends the run's `talentbuild` link to the shared line (#6), in the same message when both fit in 255 bytes, else as a second; a run with no talent string shares the line alone (`Share.Messages`) |
| `hud.showMode` | `"onArm"` | *Show the race HUD*, HUD page, Race HUD tab | `onArm`: the HUD opens on arm and on a result, and closes again when the race it opened for goes idle; `always`: also open at login |
| `hud.clock` | `"both"` | *Race clock*, HUD page, Race HUD tab | What the running body's clock shows (spec §6.1): `both` (elapsed in green beside time left in red), `left` (time left, red) or `elapsed` (time elapsed, green) |
| `hud.autoShow` | `false` | *Show near a training dummy*, HUD page, Race HUD tab | The HUD opens by itself while a cataloged training dummy is the target or has a nameplate up, and closes a debounce after none is (#16, `modules/AutoArm.lua`). Opt-in. New key: AceDB's default fills it, no migration |
| `windows.hud.width` / `.height` | `260` / `573` | none (geometry) | The HUD's size: its minimum width (300 before 2026-10-26: a new profile and `/dr resetall` open every window at its minimum width, the owner's call; `test_schema.lua` pins each default width to its window's minimum), and tall enough for the default 8 live rows (mockup screen 04) under the *Damage profile* heading (the pace bar and the damage chart) and the *Spell breakdown* heading (460 until #2 and #3, 520 until Round C's headings, 560 until the chart's icon row on top, UT-P11); the minimum is 260x354 (`Hud.MIN_HEIGHT`: the chrome plus `HudStates.MinContentHeight()`, the tallest body's fixed stack; the spec's 240 could not hold the idle body), in `modules/Hud.lua` |
| `windows.results.view`, `.expanded`, `.collapsed` | `"collapsed"`; `{ width = 1344, height = 560 }`; `{ width = 904, height = 560 }` | none (geometry; the title bar's view toggle) | The Results window's view and each view's own size (the owner's call, 2026-10-25); a new profile opens collapsed (UT-P14, 2026-10-27; expanded before, and a stored view that is neither reads as collapsed; migration 3 → 4 keeps a profile that was in the old default expanded); each default width is that view's minimum (1340 and 980 before 2026-10-26). Each view's minimum (expanded 1344; collapsed 904; 420 high; widened with the Runs list's Note column and the boxed Target and Time chips, then narrowed when the Status column dropped its board chips, 2026-10-25, then widened by the Used column, 2026-10-26, and expanded by the 440 px detail, 2026-10-27) is `Results.VIEWS` in `modules/Results.lua`. Only the toggle switches views; a resize never does. Its scale is the Master controls' `scale` |
| `windows.results.collapsedSections` | `{}` | none (view state; the detail's heading arrows) | The run detail's folded sections (UT-P10): each folded `ResultsDetail.SECTIONS` key set to `true`, so a new profile shows every section open. Not geometry, so *Reset position* keeps it; a profile reset and *Reset all settings* empty it (`tests/test_schema.lua`) |
| `appearance.elapsed.*` / `.left.*` / `.figures.*` / `.spellText.*` | `font`, `fontSize`, `fontColor`, `useClassColorFont`, `fontFlags`, `fontShadow` (see `defaults/Profile.lua`) | the composed font blocks, HUD page, HUD Appearance tab | The running clocks, the live figures and the spell rows' text (`modules/Hud_Appearance.lua`) |
| `resultsTable.damageBar.*` / `.dpsBar.*` / `.barText.*` | the bar blocks (both the spell breakdown's indigo at 85%), the font block | the composed groups, History page, Results table tab | The Runs list's Damage and DPS bars and their text; each class color is the run's character's |
| `appearance.bars.*` | `barTexture` `"Solid"`, `barAlpha` `0.85`, `barColor`, `useClassColorBar` `false`, `rowHeight` `18` | the composed bar block and *Row height*, HUD page, HUD Appearance tab | The spell rows' fill and height, on the HUD and in the Results window's breakdown |
| `appearance.chart.*` | `barTexture` `"Solid"`, `barAlpha` `0.9`, `barColor` (the mockup's indigo, `0.36, 0.37, 0.84`), `useClassColorBar` `false`, `height` `80`, `columnGap` `0`, `bgColor` (`0, 0, 0, 0.35`), `useClassColorBg` `false` | the composed bar block with *Chart height* (40-160, step 2) and *Column gap* (0-3, step 1), and *Chart background*'s composed color pair, HUD page, HUD Appearance tab | The damage chart's columns, plot height (the columns' and the best's diagonal; the plot frame is `HudChart.RESERVE`, one 13 px icon row, taller on top: `HudChart.FrameHeight`), column gap and plot background, on the HUD and in the Results detail (`HudAppearance.Chart`, `HudAppearance.ChartBackground`, `HudChart.PlotHeight`, `HudChart.ColumnGap`). New keys need no migration: AceDB's defaults fill them |
| `appearance.pace.*` | `barTexture` `"Solid"`, `barAlpha` `0.9`, `barColor` (`0.36, 0.37, 0.84`), `useClassColorBar` `false` | the composed bar block *Pace bar*, HUD page, HUD Appearance tab | The pace bar's fill (`HudAppearance.Pace`), split from `appearance.chart` on 2026-10-25 with the chart's look as its default. The branch that added the chart never shipped, so no stored chart look is carried over |

Every `race.*`, `live.*`, `hud.showMode`, `hud.clock` and `hud.autoShow` key has its row; `race.lastLength` is state, below.

### Global (`db.global`)

| Path | Default | What it is |
|---|---|---|
| `schemaVersion` | `0` | The migration stamp. The default is 0, never the current version, so AceDB does not strip it and backfill it onto an old account (savedvariables-§1) |
| `schema` | `3` | The run-record format (spec §7). Not a migration stamp: each stored run carries its own copy. Format 2 (#6) adds `loadout`; format 3 (#13, #14) adds `casts` and `usage` |
| `runs` | `{}` | The run store, keyed by run id. Global so a profile switch never hides a character's history and bests span alts |
| `loadouts` | `{ gear = {}, talents = {} }` | The loadout store (#6, `modules/Loadouts.lua`): each distinct gear set (`{ [slot] = link }`) and talent loadout (`{ specID, configID, name, heroSpecID, heroName, importString, serialVersion }`) once, keyed by a djb2 hash of its canonical form (`<hash>-<n>` for a different set with the same hash). A run holds only the keys (`run.loadout`); a set no run refers to is dropped on every removal |
| `history.keepDays` | `90` | *Days to keep* (spec §6.3; the owner's call, 2026-10-26, replacing the run count `history.keep`): 0 = never prune. Above 0, `Recorder.Prune` removes every resolved run older than that many days at login and after each saved run, never one holding a best (all-runs or clean-only board) and never a running or stopping one. Its row is *Days to keep* on the History page (0-3650); a change prunes nothing on the spot. No migration: a stored `history.keep` is left unread |
| `usage.hidden` | `""` | The hidden items (P9, `modules/Usage.lua`): item IDs, comma-separated (`"12345,67890"`), that the Results window's usage never lists, in the detail's *Usage* section (either mode), the Runs list's *Used* column, its tooltip or its sort, on any run, sample runs included (`Usage.Shown`). One plain string written whole through the seam (a value, not a registry: architecture-§5), validated by `Usage.ParseHidden` (positive whole numbers only) and stored ascending by `Usage.NormalizeHidden`. Its writers are `Usage.Hide` / `Usage.Unhide`, from the History page's *Usage* tab and the detail's right-click *Never show <item>*; the CLI's `set` and the page's Defaults reach it like any row. Global like the run store it filters. Detection still records a hidden item, so taking it off the list brings it back |
| `minimap` | `{ hide = false }` | LibDBIcon's own table, handed straight to `:Register` (launcher-§3) |

### Session-only (never persisted)

| State | Where | Why session-only |
|---|---|---|
| Debug logging flag | `NS.State.debug` (`core/State.lua`) | debug-logging-§5 |
| Test mode and the sim | `NS.Preview` (`modules/Preview.lua`, the sim's script in `modules/Sim.lua`), through the `state.testMode` row (`default = false`, so *Reset all settings* ends it) | preview-mode: on until turned off, ended by combat, by arming a real race and by closing the HUD; its sample history and sample race (`modules/MockRuns.lua`) live in memory only: the Results window reads them through `NS.ResultsSource`, and no run, loadout, note or view from them is stored |
| Debug console shown | the console itself, through the `state.debugConsole` row | a window toggle, not a setting |
| The damage chart's slices: one opaque live total per bucket (at most 60) of each race raced this session, by run id | `modules/Slices.lua` (`Capture`, filled by `modules/Hud.lua`'s live reads, the bucket timer and the buzzer's read; read by `Slices.Get` / `Drawable` for the HUD's chart, the result card and the Results detail) | #2: a value read in combat is secret and stays so, and the client writes a secret to SavedVariables as `nil` (the reload probe, 2026-10-25). Never on the run record; a run from before the last `/reload` or login has no chart |
| The race's cast list and its usage snapshot | `modules/Casts.lua` (the raw casts, the castGUIDs heard, the open channel, each spell's base cooldown, the dropped count, the clock's start) and the race's `cur.usageSnap` (`modules/Race.lua`: `Usage.Snapshot()`'s gear, bags and auras) | #13, #14: held from the arm to the result, then stored once as `run.casts` and `run.usage`; a cancel or the stand-down drops them, so a run resumed after a `/reload` has neither |
| The *Usage* section's edit and its ticks not saved yet | the detail pane (`modules/Results_Usage.lua`: `editing`, `state`) | view state (#13, P9): *Edit* opens it; kept across a redraw of the same run (each tick by its row's item), left unsaved by *Edit* again or another run; only *Save* stores the ticks (`Usage.SetUsed`) and leaves it |
| The detail's compare: the toggle and the picked run | the detail pane (`comparing`, `pickID`, `modules/Results_Detail.lua`), set by its toggle, the row menu's *Compare With This Run* (`Results.CompareWith`) and *Clear Pick* (`Results.ClearPick`) | view state (#7): the comparison is worked out from the stored runs each time; a pick whose run is deleted falls back to the board's best |

## Migrations

`core/Database.lua` holds `NS.SCHEMA_VERSION` (the runner's target) and an ordered `STEPS` list.
`NS:RunMigrations()` runs in `OnInitialize` before anything reads `db.profile`, applies every step
whose `to` is above the stored `schemaVersion`, and stamps it after each step returns. A
profile-scoped step sets `perProfile = true` and runs once per stored profile.

| Version | Step | What it does |
|---|---|---|
| 0 → 1 | pre-versioning | Nothing: a fresh install and the first release share one shape |
| 1 → 2 | the run record's format 2 (#6) | Raises a stored `global.schema` below 2 to 2. No stored run is rewritten: format 2 only adds the optional `loadout`, so a format-1 run (keeping its own `schema = 1`) reads as one with no loadout, *Not recorded* |
| 2 → 3 | the run record's format 3 (#13, #14) | Raises a stored `global.schema` below 3 to 3. No stored run is rewritten: format 3 only adds the optional `casts` and `usage`, so an older run (keeping its own `schema`) reads as one with neither, *Not recorded* |
| 3 → 4 | the Results window's collapsed default, the timeline's dropped place (UT-P14), per profile | Writes `windows.results.view = "expanded"` into a profile that stores the Results window but no view: it was in the old default, which AceDB stripped, and would otherwise read the new collapsed one. A profile that never stored the Results window keeps the new default. Clears `windows.timeline`, which nothing reads any more |

Adding a step: [common-tasks.md](common-tasks.md#add-a-saved-variables-migration).

## The run record

Format 3: spec §7's format 1 (`id`, `schema`, `status`, `addon`, `build`, `date`, `race`, `char`,
`target`, `where`, `result`, `flags`, `spells`, `note`) plus the optional `loadout` (#6, format 2)
and the optional `casts` and `usage` (#13, #14, format 3). A run stored before format 2 keeps
`schema = 1` and has no `loadout`; one stored before format 3 keeps its `schema` and has no `casts`
or `usage`. So does a format-3 run resumed after a `/reload` (both lists are held in memory until
the result). `status` is one of `armed` (never stored), `running`, `stopping`, `complete`,
`incomplete` or `lost`. Every value is plain: each client value went through `NS.Secrets`, and a
sealed one is absent.

| Part | Fields | Written by |
|---|---|---|
| top | `id` (`time()-NNNN`), `schema`, `status`, `addon`, `build`, `date` (arm, restamped at the start) | `Recorder.NewRun`; `Race` |
| `race` | `length`, `grace`, `restartGap` (frozen at arm), `startSource`, `startedAt` (`GetTime()` at the start), `sessionID`, `armMaxSession` (the highest session ID at arm), `lastDamage` (s after the start of the last damage update) | `Recorder.NewRun`; `Race` at arm, start, capture and each update |
| `char`, `where` | the player and place snapshots | `Recorder.NewRun` (at arm) |
| `target` | `npcID`, `name`, `category`, `level`, `classification` (a run from before 2026-10-26 may still carry `count`, which nothing reads) | `Recorder.NewRun`; re-read once at combat start (`Recorder.SnapshotTarget` with the arm-time `prior`) |
| `result` | `damage`, `dps`, `meterDps`, `sessionDuration`, `tail`, `combatEnd` (s after the buzzer), `endedAt` (incomplete: s after the start); absent on a lost run | `Race` |
| `flags` | `lateCasts` (`{ t, spellID? }`), `restartedAt`, `reloaded`, `died`, `sessionFromList`, `sharedSession` (the pull carried on a session from before the arm; netted against `race.baseline`) | `Race` |
| `spells` | `{ id, dmg, dps }`, highest first | `Race`, from `Meter.ReadSession` |
| `loadout` | `gear`, `talents`: the keys of the run's gear set and talent loadout in `global.loadouts`; either may be absent (not readable), and the whole field is absent on a format-1 run | `Loadouts.Attach`, from `Race`: the snapshot at the race's combat end, else the one taken at arm |
| `casts` | `v` (1), `list` (`"<cs>:<id>,<cs>:p<id>,..."`: each cast's time in whole centiseconds from the clock's start, negative for a pre-pull cast heard while armed (only the last 10 s before the clock started, `Casts.PREPULL`), `p` before a pet's spell ID; no cap), `spells` (`{ [id] = base cooldown in ms }`, from `GetSpellBaseCooldown`; a spell whose cooldown could not be read is absent), `dropped` (successes whose spell ID was sealed). Auto-repeat attacks, a castGUID heard twice and a channel's ticks are not in the list. `Casts.Decode` reads it as `{ { t, id, pet } }`; an *important* cast is one whose base cooldown is 29 s or more (`Casts.Important`) | `Race` at the result, from `Casts.Record` (`modules/Casts.lua`, fed by `modules/Watchers.lua` from the arm) |
| `usage` | `v` (1), `used` (`{ itemID?, kind, slot?, times?, n, src }`: `kind` is `gear`, `potion`, `flask`, `food` or `other`; `src` is `cast` (at each `times` entry, s on the race clock), `bag` (a count drop with no cast, time unknown), `buff` (an aura at the arm: a flask's, or *Well Fed* for food with no item) or `manual` (ticked by the player)), `candidates` (`{ itemID?, kind, slot? }`: every on-use gear item and every bag consumable with a use spell at the arm; a food entry the player unticked joins with no item, so its row stays), `edited` (the player saved their ticks). A run stored before 2026-10-26 may also carry `kind = "enchant"` entries (`src = "enchant"`, `enchantID`, `slot`, in `used` or `candidates`): never shown (`Usage.Shown`), and dropped from `used` by the run's next save | `Race` at the result, from `Usage.Build` (`modules/Usage.lua`: the arm's snapshot, the casts, the bag counts at the result and the player's casts before the pre-pull window); `Usage.SetUsed` (the player's ticks) |
| `note` | trimmed, control characters as spaces, `\|` as `/`, at most 200 UTF-8 characters (`ResultsDetail.ClampNote`) | `Recorder.SetNote` |

The grace and restart gap in force are copied onto each run, so a settings change never re-grades an
old one. Spell and item names and icons are resolved for display and never stored. About 1 to 1.5 KB
per run before format 3; the cast list adds about 10 bytes a cast (a 2:00 race at one cast a second,
about 1.2 KB more).

A change to the record's shape raises `global.schema` and adds a migration step. The step rewrites
stored runs only when the old shape cannot be read as the new one; formats 2 and 3 only add
optional fields, so their steps (1 → 2, 2 → 3) rewrite none. A reader that meets a run with a
higher `schema` than it knows leaves it alone.

## Named non-setting state

State written outside the write seam, which no control sets (architecture-§5). Each has one owner
and a closed list of writers.

| Storage key | Owner | Writers |
|---|---|---|
| `global.runs` | `modules/Recorder.lua` | `Recorder.Save` (Race, at the start, the session capture, the buzzer and the result), `Recorder.SetNote` (the Results detail's note), `Usage.SetUsed` (a run's usage ticks, `modules/Usage.lua`), `Recorder.Delete` (the detail's *Delete*), `Recorder.DeleteAll` (the History page's *Purge history…*), `Recorder.Prune` (through `Bests.PruneToSetting`, at login and after each saved run) |
| `global.loadouts` (`gear`, `talents`) | `modules/Loadouts.lua` | `Loadouts.Store` / `Loadouts.Attach` (Race, at the race's combat end and, with no combat-end snapshot, at the result), `Loadouts.Sweep` (after `Recorder.Delete`, `Recorder.DeleteAll`, a `Recorder.Prune` that removed any run, and an `Attach` that replaced a run's loadout) |
| `global.schemaVersion` | `core/Database.lua` | `NS:RunMigrations` |
| `global.minimap` (position fields) | `core/LauncherSetup.lua` | LibDBIcon's own drag handler (a vendored library's writes); `hide` is the *Minimap button* row and goes through the seam via `NS.Launcher:SetShown` |
| `DpsRacePerfDB` | `core/PerfSetup.lua` | `LibKa0s-Perf-1.0` (`/dr perf finish`) |
| `profile.windows.hud` (`point`, `relativePoint`, `x`, `y`, `width`, `height`) | `modules/Hud.lua` | the HUD's drag stop (position) and resize grip (size); `Hud.ResetPosition` clears them (the Master controls' *Reset position*) |
| `profile.race.lastLength` | `modules/Hud.lua` | `Hud.Act.pickLength` / `customLength`, and `/dr arm <length>` through `Hud.Act.pickLength`: the last race length picked, offered next (spec §4.1). No default: absent means `race.defaultLength`. Cleared (with the HUD's session pick) when `race.defaultLength` changes, through `Hud.ForgetLength`, so a new default takes effect |
| `profile.views.runs` (`filters`, `sortKey`, `sortDesc`) | `modules/Results_Runs.lua` | the Runs tab's *Save* (`View:SaveView`, the view now) and *Reset* (`View:ResetView`, deletes it); read by every build of the tab (`Runs.SavedView`) and by *Clear*. Absent means the stock view (`Runs.DEFAULTS`, newest first, grouped by `full`, *Full*: character, class, spec, target and time, a new profile's view, the owner's call 2026-10-25). `filters.group` is a `Runs.GROUPS` mode: `none`, `full` (Full), `char`, `classSpec`, `target`, `length` (Time), `targetLength` (Target + time) or `specTargetLength` (Spec + target + time); a mode the tab no longer knows draws the list flat |
| `profile.windows.timeline` | none | nothing writes it (UT-P14): the ability timeline opens over the Results window at its place and size every time (`Results.Placement`), and a move or a resize lasts only while it is open. Before UT-P14 its drag stop and grip stored `point`, `relativePoint`, `x`, `y`, `width` and `height` there (980x560 by default); migration 3 → 4 clears them from an older profile. *Reset position* (`ResultsTimeline.ResetPosition`) puts an open timeline back over the Results window |
| `profile.windows.results` (`point`, `relativePoint`, `x`, `y`, `view`, `expanded`, `collapsed`) | `modules/Results.lua` | the window's title-bar drag stop (position), its view toggle (`Results.SetView`) and the resize grip (the shown view's size); `Results.ResetPosition` clears the position and both sizes and keeps the view (the Master controls' *Reset position*) |
| `profile.windows.results.collapsedSections` (`{ [key] = true }`) | `modules/Results_Detail.lua` | a click on a run-detail section heading's arrow or text (`Pane:ToggleSection`, `ResultsDetail.SetCollapsed`; *Add Note* opens `note`); read by every layout of the detail (`ResultsDetail.IsCollapsed`). Keys are `ResultsDetail.SECTIONS`: `spells`, `chart`, `timing`, `gear`, `talents`, `usage`, `flags`, `note`; an open section is stored as nothing. *Reset position* keeps it (no geometry); a profile reset and *Reset all settings* clear it |

The Results window's filters, sort, selected run and tab are session-only view state and are not
stored.
