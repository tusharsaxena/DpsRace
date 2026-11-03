# Analysis — 20261101-145106

- **Addon:** DpsRace 0.1.0
- **Verdict:** green (per [`manifest.json`](manifest.json))
- **Commit:** 0252069 (feat/2026-11-01-full-skinning)
- **Previous run:** 20261101-025453

## Headline

All four suites pass on a clean tree holding LibKa0s v1.85.0, the skin flip, schema v9, the toast's sound selector and the addon's own skin fixes: 0 warnings / 0 errors over 168 files, 1294 of 1295 cases passed with the 1 standing skip, 9 perf scenarios, and zero functions above CCN 15 with no blind or crashed file. Allocation did not move in any scenario, though every HUD string now draws through `S.HudFont`: the appearance pass sits behind a stamp, so it is outside the measured loops, and timings are orientation only. Nothing is left to act on here. Smoke is owed: section 35 of `docs/smoke-tests.md`.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-025453 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 168 files | [`lint.txt`](lint.txt) | 166 -> 168 files, the two new suites |
| tests | pass | 1294 passed, 1 skipped, 0 failed, 1295 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1261 -> 1295 cases |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes and notes per iteration unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 964 NLOC and 116 functions more; averages as below |

| Metric | Value |
|---|---|
| Total NLOC | 44703 |
| Functions | 5174 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 78.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Totals rose because the addon and the vendored library grew. Avg CCN and Avg NLOC held, and Avg tokens fell from 78.6 to 78.5, so density did not rise.

## What moved

- **lint:** clean. `MenuUtil` moved out of four modules' `read_globals` into `core/WidgetsSetup.lua`'s, the one file that still calls it.
- **tests:** 34 new cases, in `test_skin_flip`, `test_skin_menus`, `test_toast` and `test_skinsetup`. The one skip is the standing diagnostics contract case.
- **perf:** every scenario's notes and bytes per iteration match the previous run, under unchanged ceilings. No pin moved.
- **complexity:** max CCN stays 15, nothing above it.

## Look changes (Step 8 of LibKa0s v1.85.0)

DpsRace hosts a test strip and no LibKa0s Sim panel, so of the host look changes the strip's two reach it: `icon.tint` on an owned strip's icon, and `gtip.title` on an owned tooltip title. The 30 high Steps title band does not. The HUD's own title bars already were 30 high and centered. The debug console and the perf panel take the library's 30 high title band. SM-DR-FS13 owes the strip check.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

The eight on-notice files are carried in `RESULTS.md` with their dispositions.

## Actions

None.
