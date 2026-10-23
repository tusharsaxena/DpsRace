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
| `core/CoreSetup.lua` | `NS.Print`, `SafeToString`, the `SafeRegister*` family, `ApplySkin`, the one `NS.MakeCloseButton` wrapper (`LibKa0s-Core-1.0`) | **load-bearing**: before anything that prints; publishes `NS.LIBKA0S_MISSING` |
| `core/Secrets.lua` | `NS.Secrets`: the LibKa0s-Compat guards with their stub arm, `PlainNumber`, `PlainString`, `PlainTruth`, `PlainEquals`, `CanAccessTable`, the bounded `SafeIterate`; the only file that inspects a possibly-secret value | **load-bearing**: `modules/Meter.lua` captures `NS.Secrets` at file scope |
| `core/Bus.lua` | `NS.MSG` names, the bus record, `NS.NewBusTarget`, `NS.SendBus` | conventional |
| `core/PoolSetup.lua` | `NS.Pool` (`LibKa0s-Pool-1.0`), for the HUD and Results rows | conventional |
| `core/LifecycleSetup.lua` | the one stand-down latch with its `disabled` and `perf` holds; `NS.StoodDownRefusal` | **load-bearing**: `LibKa0s-Perf-1.0` raises without `NS.lifecycle` |
| `core/PerfSetup.lua` | `NS.Perf` (`LibKa0s-Perf-1.0`) and its declared buckets | **load-bearing**: before any module holding `NS.Perf` as an upvalue |
| `core/DebugLogSetup.lua` | `NS.DebugLog`, the gated sink `NS.Debug` and its gates (`LibKa0s-DebugLog-1.0`) | **load-bearing**: needs `FONT_MONO`, the flag and the printer; before any `NS.Debug` call |
| `core/LauncherSetup.lua` | the LDB launcher, registered with LibDBIcon (`LibKa0s-Launcher-1.0`); the two key-binding buttons | **load-bearing**: reads `LOGO_128` and `NS.L` at file scope |
| `core/DpsRace.lua` | AceAddon registration, `OnInitialize`/`OnEnable`, the game events, the shared toggle handlers | **load-bearing**: reclaims `NS.Print` from AceConsole's embed |
| `core/Database.lua` | AceDB, the profile callbacks, the migration runner | conventional (reached at call time) |
| `defaults/Profile.lua` | the AceDB defaults tree | the defaults group |
| `defaults/Dummies.lua` | `NS.Dummies`: the measured training-dummy catalog (spec §4.6), `Lookup(npcID)`, the six `CATEGORIES` and their labels | **load-bearing**: reads `NS.L` at file scope |
| `modules/Meter.lua` | `NS.Meter`: availability, the session list, the after-combat `ReadSession(id)` (plain, sorted, or `sealed`) and the opaque `ReadLive()`; the only caller of `C_DamageMeter` | **load-bearing**: first module; resolves the meter enums at file scope |
| `modules/Recorder.lua` | `NS.Recorder`: the player, target and place snapshots (every value through `NS.Secrets`, so no secret reaches SavedVariables), `NewRun` with the scoring settings frozen in, and the run store (`Save`, `Get`, `All`, `Pending`, `Delete`, `DeleteAll`) that fires `RUN_SAVED` / `RUNS_CHANGED` | conventional (reached at call time) |
| `modules/Timeline.lua` | `NS.Timeline`: pure. `New()` gives a run's damage-update timeline (`AddDamage`, `LastDamage`, `Tail`, `RestartAt`, `QuietFor`), stamps from `GetTime()` only | conventional (reached at call time) |
| `modules/Scoring.lua` | `NS.Scoring`: pure. `IsLateCast`, `Dps` (damage over the race length, or over `endedAt` for an incomplete run), `QUIET_BEFORE_READ` and `Flags(run, nameOf?)` in display order | conventional (reached at call time) |
| `modules/Placeholders.lua` | stand-in `NS.Hud`, `NS.Results`, `NS.Preview`; T7, T8 and T9 replace them | conventional |
| `modules/Diagnostics.lua` | the sections of `/dr diagnostics` | conventional |
| `settings/Schema.lua` | `NS.Schema`, the write seam `NS.SetByPath`, `NS.GetSetting`, page filter, validation (`LibKa0s-Schema-1.0`) | **load-bearing**: `settings/General.lua` calls `NS.RegisterSchemaRows` at file scope |
| `settings/Slash.lua` | `NS.COMMANDS` and the `LibKa0s-Slash-1.0` descriptor | conventional |
| `settings/OptionsSetup.lua` | `NS.Helpers`, the `LibKa0s-Options-1.0` instance | **load-bearing**: every page file captures `NS.Helpers` at file scope |
| `settings/General.lua` | the General page (Master controls) and the landing spec `NS.LANDING` | **load-bearing**: registers first; page order is registration order |
| `settings/Profiles.lua` | the Profiles page (AceDBOptions) | registers last |

Not listed in the TOC: `Bindings.xml` (the client reads it by name; two `CLICK` bindings).

## Planned files

From the plan's file map; each lands with its task and gets a row above in the same change.

| File | Task | Job |
|---|---|---|
| `modules/Race.lua`, `modules/Watchers.lua` | T5 | state machine, clock, buzzer; event wiring |
| `modules/Bests.lua` | T6 | personal bests and prune protection |
| `modules/Format.lua`, `modules/Hud*.lua` | T7 | number formatting; the Race HUD |
| `modules/Results*.lua` | T8 | the Results window |
| `settings/Race.lua`, `Live.lua`, `History.lua`, `modules/Share.lua`, `modules/Preview.lua` | T9 | settings pages, chat share, test mode |

## Not shipped

| Path | Job |
|---|---|
| `tests/run.lua` | the runner: load list from the TOC, lifecycle kick, suite list |
| `tests/wow_mock.lua` | this addon's extender over `tests/_kit/mock_base.lua`, including the scriptable target (`M.__setTarget`) and the snapshot APIs |
| `tests/mock_meter.lua` | the scripted `C_DamageMeter`: secret while the combat restriction is on, plain after, sessions by ID |
| `tests/test_*.lua` | the suites (see [testing.md](testing.md)) |
| `probe/DpsRaceProbe/` | the pre-build measurement addon; excluded by `.luacheckrc` and `.pkgmeta` |
| `media/logos/*.png`, `*.jpg` | the editable logo sources; `.pkgmeta` excludes them |
