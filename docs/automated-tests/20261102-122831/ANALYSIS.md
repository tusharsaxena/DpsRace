# Analysis — 20261102-122831

- **Addon:** DpsRace 0.1.0
- **Verdict:** green (per [`manifest.json`](20261102-122831/manifest.json))
- **Commit:** 4fd28e0 (feat/2026-11-01-full-skinning)
- **Previous run:** 20261102-025003

## Headline

All four suites pass after SG-DR-1 (the sim parks until the stepper plays), SG-SIM (a Race tab step-delay setting), SG-DR-2 (migration 9 -> 10 puts the clocks' stored face and shadow companions on) and SG-DR-3 (Insights opens on Overall and remembers the pick for the session).

## Suites

| Suite | Status | Result | Artifact | Moved since 20261102-025003 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 170 files | [`lint.txt`](lint.txt) | one file counted more than before (169 -> 170) |
| tests | pass | 1366 passed, 1 skipped, 0 failed, 1367 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1359 -> 1367 cases |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | timings are machine load, not comparable |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 45275 -> 45474 |

| Metric | Value |
|---|---|
| Total NLOC | 45474 |
| Functions | 5318 |
| Avg NLOC / function | 7.9 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 77.7 |
| Warnings (CCN > 15) | 0 |
| Warning rate | 0.00 / 0.00 |
| Files in the 1000-1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files | 0 |
| Crashed files | 0 |

## Complexity watch list

None. Nothing newly crossed; dispositions carried forward.

## Not measured

The in-game results of SG-DR-1 to SG-DR-3 and SG-SIM are smoke checks and are not run.
