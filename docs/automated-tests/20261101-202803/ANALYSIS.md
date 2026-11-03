# Analysis — 20261101-202803

- **Addon:** DpsRace 0.1.0
- **Verdict:** green (per [`manifest.json`](manifest.json))
- **Commit:** 6ba5c64 (feat/2026-11-01-full-skinning)
- **Previous run:** 20261101-202640

## Headline

All four suites pass on a clean tree holding the re-cut LibKa0s v1.85.0, kit revision 50 and the adopted skin gate: 0 warnings / 0 errors over 168 files, 1352 of 1353 cases passed with the 1 standing skip, 9 perf scenarios and nothing above CCN 15.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-202640 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 168 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 1352 passed, 1 skipped, 0 failed, 1353 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | the eol case passes again |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | unchanged |

| Metric | Value |
|---|---|
| Total NLOC | 44995 |
| Functions | 5251 |
| Avg NLOC / function | 7.9 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 78.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Against the last green run, 20261101-145106, totals rose with the vendored library (44703 -> 44995 NLOC, 5174 -> 5251 functions) while Avg NLOC fell 8.0 -> 7.9 and Avg tokens 78.5 -> 78.0, with Avg CCN held at 2.5. Density did not rise.

## What moved

Since 20261101-145106, the last green run:

- **tests:** 1295 -> 1353 cases. The kit's `test_skin_values` and `test_skin_switch` replace `test_skin_literals`; the switch test runs each declared surface with the Scope cleared and, where it carries no companion, with the Scope ignored. New cases in `test_skin_flip` and `test_skin_menus`. The one skip is the standing diagnostics contract case.
- **perf:** every byte figure matches that run's under unchanged ceilings, within `combatEventCaptureOff`'s 2224.5 -> 2223.4, since `measure` now skips a step of 64 KB or more. The two runs between are explained in their own analyses. S.BarGloss adds no cost on these paths: the bars restyle behind a stamp.
- **complexity:** nothing above CCN 15.

## Look changes (Step 8 of LibKa0s v1.85.0)

At this cut no Sim file moved, `lib.TestStrip` did not move, and DpsRace hosts no Sim panel, so Step 5 names nothing new for it.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

The eight on-notice files are carried in `RESULTS.md` with their dispositions.

## Actions

None.
