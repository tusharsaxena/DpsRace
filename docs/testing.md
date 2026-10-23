# Testing

How to verify Ka0s DPS Race (testing-§6). What to install first is in the root
[`DEPENDENCIES.md`](../DEPENDENCIES.md); this page assumes it is done. Every command runs from the
**repo root**.

## Commands

| Command | What it does |
|---|---|
| `lua tests/run.lua` | The headless suite. Exits non-zero on any failure |
| `lua tests/run.lua -j auto` | The same, split across one worker per CPU (testing-§14) |
| `lua tests/run.lua --list > docs/test-cases.md` | Regenerates the case inventory without running anything |
| `luacheck .` | Lint, configured by `.luacheckrc`; must report 0 warnings and 0 errors |
| `luac -p path/to/file.lua` | Syntax-check one file |
| `bash tests/_kit/run-automated-tests.sh` | All four out-of-game suites, written to a dated bundle ([automated-tests/README.md](automated-tests/README.md)) |

Every run is bounded by the vendored kit as it loads (memory, time, process depth; testing-§15).

## The commit gate

Before **every** commit: `lua tests/run.lua` green **and** `luacheck .` at 0/0 (testing-§4). Work is
test-first: a failing case that pins the behavior, then the code. The runner's
`--suite lint --suite tests --no-bundle` is the same pair and writes nothing.

## The four out-of-game suites

A suite gates a **commit** and a **release** (the tag) differently, so both are named:

| Suite | Command | Gates the commit? | Gates the release (tag)? |
|---|---|---|---|
| `lint` | `luacheck .` | yes | yes |
| `tests` | `lua tests/run.lua` | yes | yes |
| `perf` | `lua tests/perf.lua` (lands in T10) | no, recorded only | yes, at `pass` (a `skip` is not evaluated) |
| `complexity` | `bash tests/_kit/run-automated-tests.sh --suite complexity` | no, recorded only | yes, at `pass` with zero functions above CCN 15 |

The release is gated on all four at `pass` plus zero functions above CCN 15, `blindFiles` at 0 and a
run on which `lizard` did not raise (automated-tests-§3). Never run raw `lizard`: it is blind in
places in Lua, and the kit's sighted shadow is what the complexity suite measures.

## How the harness is built

- **`tests/_kit/`** is the shared harness, vendored byte-identical from the LibKa0s tag named in root
  `CLAUDE.md`. Never edit it; `test_vendor_sync` fails on any drift.
- **`tests/run.lua`** loads the vendored library in `LibKa0s.xml` order and the addon in **TOC
  order** (`Loader.tocFiles`), so the harness cannot drift from what the client loads (testing-§9).
  It runs `OnInitialize` and `OnEnable` like the client, and `loadInstance` builds isolated
  instances (a library-absent load passes `libFiles = {}`).
- **`tests/wow_mock.lua`** extends `tests/_kit/mock_base.lua` with what this addon calls, including a
  scriptable target (`M.__setTarget{ guid, name, level, classification }`, any field a `Kit.secret`).
- **`tests/mock_meter.lua`** is a scripted `C_DamageMeter` built on the kit's secret wrappers
  (`Kit.secret`): `SetSecret(true)` models the combat restriction, `SetSealed(id)` a session captured
  in combat. A suite installs it through `T.load{ mutate = ... }` so the enums resolve at load.
- Every negative assertion was proven able to fail by mutating the code under test (testing-§12).

## The suites

| Suite | What it covers |
|---|---|
| `test_skeleton` | Registration, the printer, both slash commands, DB defaults, `NS.MSG`, produced interfaces, icons, file headers |
| `test_secrets` | `core/Secrets.lua`: the guards over plain, nil and secret on both arms (LibKa0s-Compat and the stub), the conversions, `SafeIterate`'s bound, nil stop and refusal |
| `test_meter` | `modules/Meter.lua` on `tests/mock_meter.lua`: availability, the plain sorted after-combat read, `sealed`, `missing`, a raising client, the opaque live read under secrets, the session list, and the one-file rules for `C_DamageMeter` and the secret detectors |
| `test_dummies` | `defaults/Dummies.lua`: the measured catalog rows, `Lookup` (known, unknown, a copy), the six categories and their labels |
| `test_recorder` | `modules/Recorder.lua`: the player, target and place snapshots (a Creature GUID's npcID, a secret GUID, a sealed re-read filled from the arm-time snapshot), `NewRun` freezing grace and restart gap, unique ids, and the store's order, `Pending` filter and bus messages |
| `test_timeline` | `modules/Timeline.lua` on the probe's measured timelines: the tail (runs 4 and 6), damage restarting after a quiet gap and not on 2s DoT ticks, the gap's start at the buzzer, `QuietFor`, out-of-order updates |
| `test_scoring` | `modules/Scoring.lua`: late-cast boundaries (exactly the grace, before the buzzer, an instant), `Dps` for complete and incomplete runs, `QUIET_BEFORE_READ`, the flag order and text, the optional spell-name resolver |
| `test_bests` | `modules/Bests.lua` and `Recorder.Prune`: the board key, incomplete and lost never counting, clean-only, the two Dungeoneer IDs on one board, a deleted best promoting the next run (Review Focus 4), the cache dropped on `RUN_SAVED` / `RUNS_CHANGED`, `Delta` against the best before a run, pruning (keep 0, best holders, running and stopping runs kept) on `RUN_SAVED`, at `OnEnable` and never while disabled |
| `test_race` | `modules/Race.lua` on a fake clock: arm refusals (combat, pending, busy, meter unavailable, length), the start on the session event, the session-ID capture (never an arm-time session), the buzzer and `RACE_BUZZER`, late-cast grace edges, incomplete and died runs, the read gated on combat end and 2.5s of quiet, the read by ID never Current, tail and restart, lost runs (reset, session gone, sealed, raising), the list fallback, cancel, the diagnostics line |
| `test_race_resume` | `Race.Resume` from `OnEnable`: running past the buzzer becomes stopping and reloaded, running before it keeps its remaining time, stopping out of combat reads at once, in combat waits, a session gone is lost, an older unresolved run is settled |
| `test_schema` | The schema's shape, the write seam, the Master controls rows, the minimap row, resets, test mode, migrations, the panel |
| `test_slash` | The dispatcher: help, aliases, enable/disable, debug, perf, the schema CLI, the library-absent load |
| `test_launcher` | The launcher object, its clicks and menu, the minimap button, the two key bindings |
| `test_disabled` | All ten steps of slash-commands-§7, a probe feature verb and a bus receiver on both load arms; the race watchers hold nothing and the race does nothing while disabled or perf-suspended, and the stand-up resumes a stored run |
| `test_surface_parity` | Each degradation stub against the live library surface it stands in for, every adopted module on both arms, and the schema row counts with the hollow-composer delta (testing-§8, options-ui-§1) |
| `test_perf_harness` | The Perf descriptor, every declared bucket reached by a real bracket, and the perf hold making the addon inert |
| `test_loadorder` | The runner's load list against a fresh TOC derivation: order, files on disk, no `libs/` path (testing-§9) |
| `test_vendor_sync` | The vendored payloads against the tag (delegates to `tests/_kit/vendor_sync.lua`) |
| kit: `test_eol`, `test_prose`, `test_layout_cap`, `test_diagnostics_contract`, `test_lizard_sighted` | Line endings, US spelling, the 1500-line cap, the diagnostics contract, the complexity sanitizer |

The remaining engine and window suites arrive with their tasks (T4 to T9; see the plan).

## Inventory and badge

[`test-cases.md`](test-cases.md) is generated by `--list` and is the authoritative pass count. When a
case is added, removed or renamed, regenerate it and update the README `[tests]` badge in the same
change (testing-§5). A declared skip is listed with its reason and counted in neither figure.

## In game

Behavior a headless run cannot reach (rendering, the real meter, taint) is covered by
[`smoke-tests.md`](smoke-tests.md), run by the owner before release.
