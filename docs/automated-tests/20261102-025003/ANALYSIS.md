# Analysis — 20261102-025003

- **Addon:** DpsRace 0.1.0
- **Verdict:** green (per [`manifest.json`](manifest.json))
- **Commit:** 712a6ab (feat/2026-11-01-full-skinning)
- **Previous run:** 20261102-004408

## Headline

All four suites pass after SF-DR-3 to SF-DR-8 (Insights scoped to the board tab with an Overall tab, the ignore list and toast as Race tabs, the sim stepper window). SF-DR-9 (#70) is not built: see the note at the end.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261102-004408 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 169 files | [`lint.txt`](lint.txt) | one file added (core/SimSetup.lua) |
| tests | pass | 1358 passed, 1 skipped, 0 failed, 1359 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1353 -> 1359 cases |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | timings differ (machine load, not comparable); bytes unchanged within 1 KB |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 45006 -> 45275 |

| Metric | Value |
|---|---|
| Total NLOC | 45275 |
| Functions | 5290 |
| Avg NLOC / function | 7.9 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 77.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate | 0.00 / 0.00 |
| Files in the 1000-1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files | 0 |
| Crashed files | 0 |

## Complexity watch list

None. Nothing newly crossed; band files grew modestly (locales/enUS.lua 1186, modules/Hud.lua 1117, tests/test_insights.lua 1249), dispositions carried forward.

## Not built

SF-DR-9 is not in this run. The live Damage profile feeds secret values only to StatusBar:SetValue, and the library line chart does arithmetic on plain numbers and draws its own y axis and grid, so it cannot keep the look. Owner call needed.
