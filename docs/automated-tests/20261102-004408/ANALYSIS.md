# Analysis — 20261102-004408

- **Addon:** DpsRace 0.1.0
- **Verdict:** green (per [`manifest.json`](manifest.json))
- **Commit:** 0ce8a0a (feat/2026-11-01-full-skinning)
- **Previous run:** 20261101-202803

## Headline

All four suites pass after SF-DR-1 (the two clocks follow the skin's font): 0 warnings / 0 errors over 168 files, 1352 of 1353 cases passed with the 1 standing skip, 9 perf scenarios, nothing above CCN 15.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-202803 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 168 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 1352 passed, 1 skipped, 0 failed, 1353 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | count unchanged; the clock case now pins the font companion |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | timings differ (machine load, not comparable across runs); bytes within 1 KB of the last run |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 44995 -> 45006 |

| Metric | Value |
|---|---|
| Total NLOC | 45006 |
| Functions | 5251 |
| Avg NLOC / function | 7.9 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 78.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files | 0 |
| Crashed files | 0 |

## Complexity watch list

None.
