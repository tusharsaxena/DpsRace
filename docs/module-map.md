# Module map

Every authored file, its one-line job, and the load order. Vendored code (`libs/`, `tests/_kit/`)
is not listed: it is a byte copy of its upstream (library-stack-§7). Every authored `.lua` opens with
the namespace bootstrap and, beneath it, a comment naming its path and purpose (documentation-§9).

## Load order

The TOC (`DpsRace.toc`) loads `libs/` → `locales/` → `core/` → `defaults/` → `modules/` →
`settings/` (layout-§1, toc-file-§5). Inside `core/` there is no fixed prefix: files are ordered by
what each resolves at **file scope**, and every load-bearing position carries a `# LOAD-BEARING:`
comment at its TOC line saying what. Positions without one are conventional and may move within
their group. The headless runner reads its file list from the TOC (`Loader.tocFiles`), so it cannot
drift from what the client loads (testing-§9).

## Shipped files, in TOC order

| File | Job | Position |
|---|---|---|
| `libs\…` (Ace3, LibStub, CallbackHandler, LibSharedMedia, LibDataBroker, LibDBIcon) | vendored libraries | first; `libs\LibKa0s\LibKa0s.xml` is one line, after Ace3 |
| `locales/enUS.lua` | `NS.L`, the canonical locale | **load-bearing**: `core/LauncherSetup.lua` and every `settings/` file read `NS.L` at file scope |
| `core/Namespace.lua` | `NS.PREFIX`, `NS.name`, `NS.BRAND`, `NS.SLASH`/`SLASH_LONG`, the version fallback | **load-bearing**: everything below reads these |
| `core/MediaSetup.lua` | `NS.Icon`, `NS.MediaFont`; the one `RegisterLSM` call (`LibKa0s-Media-1.0`) | **load-bearing**: `core/Constants.lua` resolves `FONT_MONO` from it |
| `core/Constants.lua` | `FONT_MONO`, `LOGO_128`, `LOGO` | conventional |
| `core/State.lua` | session-only state (`NS.State.debug`) | conventional |
| `core/EnvSetup.lua` | `NS.Meta`, `NS.Version` (`LibKa0s-Env-1.0`) | **load-bearing**: resolves `NS.version` at file scope; `core/PerfSetup.lua` calls `NS.Version()` |
| `core/CoreSetup.lua` | `NS.Print`, `SafeToString`, the `SafeRegister*` family, `ApplySkin`, `MakeResizable`, the one `NS.MakeCloseButton` wrapper (`LibKa0s-Core-1.0`) | **load-bearing**: before anything that prints; publishes `NS.LIBKA0S_MISSING` |
| `core/Secrets.lua` | `NS.Secrets`: the LibKa0s-Compat guards with their stub arm, `PlainNumber`, `PlainString`, `PlainTruth`, `PlainEquals`, `CanAccessTable`, the bounded `SafeIterate`; the only file that inspects a possibly-secret value | **load-bearing**: `modules/Meter.lua` captures `NS.Secrets` at file scope |
| `core/Bus.lua` | `NS.MSG` names, the bus record, `NS.NewBusTarget`, `NS.SendBus` | conventional |
| `core/PoolSetup.lua` | `NS.Pool` (`LibKa0s-Pool-1.0`), for the HUD and Results rows | conventional |
| `core/WidgetsSetup.lua` | `NS.MakeDropdown`, `NS.CloseMenu`, `NS.MakeTestStrip`, `NS.TEST_STRIP_HEIGHT`, `NS.HasWidgets` (`LibKa0s-Widgets-1.0`): the Results filter bars' dropdowns, with the catalog's `chevron-down` and `confirm` marks, and the HUD's test-mode strip; nil (no control) when the library is absent | conventional (reached at call time) |
| `core/LifecycleSetup.lua` | the one stand-down latch with its `disabled` and `perf` holds; `NS.StoodDownRefusal` | **load-bearing**: `LibKa0s-Perf-1.0` raises without `NS.lifecycle` |
| `core/PerfSetup.lua` | `NS.Perf` (`LibKa0s-Perf-1.0`) and its declared buckets | **load-bearing**: before any module holding `NS.Perf` as an upvalue |
| `core/DebugLogSetup.lua` | `NS.DebugLog`, the gated sink `NS.Debug` and its gates (`LibKa0s-DebugLog-1.0`) | **load-bearing**: needs `FONT_MONO`, the flag and the printer; before any `NS.Debug` call |
| `core/LauncherSetup.lua` | the LDB launcher, registered with LibDBIcon (`LibKa0s-Launcher-1.0`); the three key-binding buttons (the two Show-window keys and *Arm / cancel race*) | **load-bearing**: reads `LOGO_128` and `NS.L` at file scope |
| `core/DpsRace.lua` | AceAddon registration, `OnInitialize`/`OnEnable`, the game events, the shared handlers the launcher, the key bindings and the verbs run (`ToggleHud`, `ToggleResults`, `ToggleLock`, `ToggleTestMode`, `ToggleArm`, `SetHudShown`, `ShowResults`) | **load-bearing**: reclaims `NS.Print` from AceConsole's embed |
| `core/Database.lua` | AceDB, the profile callbacks, the migration runner | conventional (reached at call time) |
| `defaults/Profile.lua` | the AceDB defaults tree | the defaults group |
| `defaults/Dummies.lua` | `NS.Dummies`: the measured training-dummy catalog (spec §4.6), `Lookup(npcID)`, the six `CATEGORIES` and their labels | **load-bearing**: reads `NS.L` at file scope |
| `modules/Meter.lua` | `NS.Meter`: availability, the session list, the after-combat `ReadSession(id)` (plain, sorted, or `sealed`) and the opaque `ReadLive()`; the only caller of `C_DamageMeter` | **load-bearing**: first module; resolves the meter enums at file scope |
| `modules/Recorder.lua` | `NS.Recorder`: the player, target and place snapshots (every value through `NS.Secrets`, so no secret reaches SavedVariables), `NewRun` with the scoring settings frozen in, and the run store (`Save`, `SetNote`, `Get`, `All`, `Pending`, `Delete`, `DeleteAll`, `Prune(keep, protect?)`) that fires `RUN_SAVED` / `RUNS_CHANGED`; `Prune` never removes a best-holding, running or stopping run, the `protect` id or the race's current run | conventional (reached at call time) |
| `modules/Timeline.lua` | `NS.Timeline`: pure. `New()` gives a run's damage-update timeline (`AddDamage`, `LastDamage`, `Tail`, `RestartAt`, `QuietFor`), stamps from `GetTime()` only | conventional (reached at call time) |
| `modules/Scoring.lua` | `NS.Scoring`: pure. `IsLateCast`, `Dps` (damage over the race length, or over `endedAt` for an incomplete run), `QUIET_BEFORE_READ` and `Flags(run, nameOf?)` in display order | conventional (reached at call time) |
| `modules/Bests.lua` | `NS.Bests`: pure over stored runs. `Key(run)` (`specID|category|length`), `Compute(runs, opts)` (complete runs only, `cleanOnly` drops flagged ones), the cached `Board(opts)`, `Delta(run, runs?)` against the best before the run, `HoldingIDs(runs)` (both boards) and `PruneToSetting(protect?)`; its bus receiver drops the cache on `RUN_SAVED` / `RUNS_CHANGED` and prunes on `RUN_SAVED`, protecting the run just saved | **load-bearing**: builds its bus receiver at file scope (`core/Bus.lua`) |
| `modules/Race.lua` | `NS.Race`: the lifecycle state machine (`STATE`, `Arm`, `Cancel`, `Elapsed`, `TimeLeft`, `SinceBuzzer`), the buzzer timer, the 0.5s readiness poll while stopping, late casts, the read by session ID (with the session-list fallback), `Suspend` and the `/reload` `Resume`; sends `RACE_STATE_CHANGED`, `RACE_BUZZER`, `RACE_RESULT` | conventional (reached at call time) |
| `modules/Watchers.lua` | `NS.Watchers`: the race's event frame. `Sync()` registers the meter, combat, death and (from RUNNING) the player's cast events for the race's state, nothing while idle or stood down; dispatches each to a `Race.On*` input with `GetTime()` | after `modules/Race.lua` by convention (reached at call time) |
| `modules/Format.lua` | `NS.Format`: the one secret-safe number formatter (`Number`, over the client's `C_StringUtil` formatter, `AbbreviateNumbers` beneath it), `Clock` (`m:ss.t`), `Length`, `Pct`, `Seconds`, `ParseLength` (`90`, `1:30`, `3m`) and `ArmRefusal` (the line for each `Race.Arm` reason) | conventional (reached at call time) |
| `modules/Hud_Breakdown.lua` | `NS.HudBreakdown`: the HUD's pooled spell rows, placed from their index; `ShowLive` (opaque values, Blizzard's order, no %) and `ShowResult` (plain, with %); `SpellName` / `SpellIcon` through `C_Spell` | conventional (reached at call time) |
| `modules/Hud_States.lua` | `NS.HudStates`: the six bodies (idle, armed, running, stop, waiting, result), their widgets, the result chips (`ResultChips`) | conventional (reached at call time) |
| `modules/Hud.lua` | `NS.Hud`: the Race HUD window (skin, close, Escape, resize, lock, scale, stored position), which body shows, the 20 Hz countdown `OnUpdate`, the coalesced 4 Hz live read, the countdown cue and the buzzer's raid warning; `Show`/`Hide`/`Toggle`/`IsShown`/`SetLocked`/`ResetPosition`/`Refresh`/`Render`/`Suspend`/`Resume` and the buttons' acts (`Hud.Act`) | **load-bearing**: builds its bus receiver at file scope (`core/Bus.lua`) and reads `NS.defaults` for its size |
| `modules/Results_Table.lua` | `NS.ResultsTable`: the Results window's sortable list (header of sort controls over pooled, scrolling row buttons, laid out from configured column widths; `Sort` is pure) and the helpers both tabs draw a run with (class and spec icons with name tooltips, class color, category badge, flag texts and chip words, dates) | after `modules/Hud_States.lua` (reached at call time); **load-bearing** for the three files below, which capture `NS.ResultsTable` at file scope |
| `modules/Results_Runs.lua` | `NS.ResultsRuns`: the Runs tab. Pure `Filter` (character, spec, category, length, date range, Hide flagged, Include incomplete; resolved runs only), `Options`, `Since`, `Columns`; the filter bar and the list | after `modules/Results_Table.lua` |
| `modules/Results_Detail.lua` | `NS.ResultsDetail`: the run detail pane (header, score with the best delta, the breakdown sorted with %, the timing strip, the flags with what each means, the note, Share, Delete, the narrow window's back control). Pure `Timing`, `Place`, `FlagLines`, `SortedSpells`, `Meta`, `ClampNote` (200 characters) | after `modules/Results_Table.lua`; captures `NS.HudBreakdown`'s row pitch at file scope |
| `modules/Results_Bests.lua` | `NS.ResultsBests`: the Bests tab over `NS.Bests.Board` (spec and category filters, *Clean runs only*); pure `Rows`, `Options`, `Columns` | after `modules/Results_Table.lua` |
| `modules/Results.lua` | `NS.Results`: the Results window (skin, close, Escape, resize, Master scale, stored position), the lazily built tabs, wide or narrow placement of the detail, the footer, the delete confirmation; `Show`/`Hide`/`Toggle`/`IsShown`/`ShowRun`/`ShowTab`/`Back`/`Selected`/`Tab`/`Mode`/`ConfirmDelete`/`DeleteRun`/`SetNote`/`ResetPosition`/`Refresh`/`Suspend`/`Resume`/`Diagnose` | **load-bearing**: builds its bus receiver at file scope (`core/Bus.lua`) and reads `NS.defaults` for its size |
| `modules/Share.lua` | `NS.Share`: `Line(run)` (the one-line share, mockup screen 12; nil for a run with no score), `Prompt(run, owner?)` (the channel menu: say, party, raid, guild, whisper, the ones the player is not in grayed; refused in combat), `Send`, `CHANNELS`, and the race's own chat lines `ArmedLine` / `ResultLine`, printed on `RACE_STATE_CHANGED` (armed) and `RACE_RESULT` | **load-bearing**: builds its bus receiver at file scope (`core/Bus.lua`) |
| `modules/Preview.lua` | `NS.Preview`: test mode. `Start` (refused in combat and during a race) / `Stop(reason?)` / `IsActive` / `Suspend` / `Diagnose`, the scripted 30s race (`SCRIPT`, `LENGTH`, `TICK`) drawn through `NS.Hud.Render`; ends on arming a real race | **load-bearing**: builds its bus receiver at file scope (`core/Bus.lua`) |
| `modules/Diagnostics.lua` | the sections of `/dr diagnostics` | conventional |
| `settings/Schema.lua` | `NS.Schema`, the write seam `NS.SetByPath`, `NS.GetSetting`, page filter, validation (`LibKa0s-Schema-1.0`) | **load-bearing**: `settings/General.lua` calls `NS.RegisterSchemaRows` at file scope |
| `settings/Slash.lua` | `NS.COMMANDS` and the `LibKa0s-Slash-1.0` descriptor | conventional |
| `settings/OptionsSetup.lua` | `NS.Helpers`, the `LibKa0s-Options-1.0` instance; `NS.RegisterTabbedPage(spec)`, the one builder of the Race, Live breakdown and History pages, and `NS.pageCtx` | **load-bearing**: every page file captures `NS.Helpers` at file scope and the three pages call `NS.RegisterTabbedPage` at file scope |
| `settings/General.lua` | the General page (Master controls, then the Race HUD tab: `hud.showMode`) and the landing spec `NS.LANDING` | **load-bearing**: registers first; page order is registration order |
| `settings/Race.lua` | the Race page: default race length, countdown cue, buzzer, and the scoring rules (grace, restart gap, hint delay) | after `settings/General.lua` (page order); reads `NS.HudStates.PRESETS` and `NS.Format` at file scope |
| `settings/Live.lua` | the Live breakdown page: rows shown, live reads per second, spell icons, live DPS | after `settings/Race.lua` (page order) |
| `settings/History.lua` | the History page: Runs to keep, the stored count, *Delete all runs…* (`NS.History`: `StoredLine`, `ConfirmDeleteAll`, `DeleteAll`) | after `settings/Live.lua` (page order); builds its bus receiver at file scope |
| `settings/Profiles.lua` | the Profiles page (AceDBOptions) | registers last |

Not listed in the TOC: `Bindings.xml` (the client reads it by name; three `CLICK` bindings: the two
Show-window keys and *Arm / cancel race*).

## Not shipped

| Path | Job |
|---|---|
| `tests/run.lua` | the runner: load list from the TOC, lifecycle kick, suite list |
| `tests/wow_mock.lua` | this addon's extender over `tests/_kit/mock_base.lua`, including the scriptable target (`M.__setTarget`) and the snapshot APIs |
| `tests/mock_meter.lua` | the scripted `C_DamageMeter`: secret while the combat restriction is on, plain after, sessions by ID |
| `tests/race_clock.lua` | the Race suites' fixture: an instance on the scripted meter, a fake clock that fires `C_Timer` timers and tickers at their due `GetTime()`, and drivers for Race's inputs |
| `tests/mock_widgets.lua` | the HUD and Results suites' widget recorder: distinct font strings and textures that remember their text, values and textures, which objects were handed a secret, every geometry read, and the client seams the HUD draws through (the number formatter, `C_Spell`, sounds, the raid warning, known spells) |
| `tests/prose_waivers.lua` | the US-spelling gate's per-file, per-word waivers (the kit's own spelling of its timer-cancel field) |
| `tests/test_*.lua` | the suites (see [testing.md](testing.md)) |
| `probe/DpsRaceProbe/` | the pre-build measurement addon; excluded by `.luacheckrc` and `.pkgmeta` |
| `media/logos/*.png`, `*.jpg` | the editable logo sources; `.pkgmeta` excludes them |
