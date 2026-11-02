# Analysis — 20261103-030550

- **Addon:** DpsRace 0.1.0
- **Verdict:** green
- **Commit:** 525bf53 (feat/2026-11-01-full-skinning), clean
- **Previous run:** 20261102-122831 (4fd28e0)

## Headline

All four suites pass on a clean tree at `525bf53`, the head of the smoke round 3 DpsRace items (R3-DR-1 to R3-DR-5, label in [`manifest.json`](manifest.json)). The case count rose by 13 and the linted file count by 2 (the new `modules/Hud_Best.lua` and `tests/test_hud_best.lua`); complexity averages are unchanged and nothing crossed a threshold. Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261102-122831 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 172 files | [`lint.txt`](lint.txt) | files 170 → 172 |
| tests | pass | 1379 passed, 1 skipped, 0 failed, 1380 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 1367 → 1380 |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 9 scenarios; allocation flat (see below) |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC and functions up, averages flat |

| Metric | Value |
|---|---|
| Total NLOC | 45944 |
| Functions | 5371 |
| Avg NLOC / function | 7.9 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 77.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every value is from [`manifest.json`](manifest.json)'s `suites.complexity`. `blindFiles` and `crashedFiles` are 0, so the measurement is sighted and whole.

The one skipped case is the same declared skip the previous runs carried; it is counted in the total and not in `passed` ([`tests.txt`](tests.txt)).

## What moved

- **lint:** 0/0 again; files 170 → 172.
- **tests:** 1367 → 1380 total (1366 → 1379 passed, skip 1 → 1). The new cases: the clocks' face under four skins through the real library with a CreateFont fake (R3-DR-1), the 1:00 default (R3-DR-2), auto-show on by default (R3-DR-3), the six `test_hud_best` cases (R3-DR-4), and two compare-brightness cases (R3-DR-5).
- **perf:** the same 9 scenarios. `bytes/iter` is flat on every scenario except `combatEventCaptureOff`, 2223.4 → 2222.3 ([`perf.txt`](perf.txt) against [`../20261102-122831/perf.txt`](../20261102-122831/perf.txt)). The idle body's new Your best read is not on any measured path: the scenarios drive the race, the live HUD and combat events. Timings are for orientation only.
- **complexity:** NLOC 45474 → 45944, functions 5318 → 5371; avg NLOC 7.9 and avg CCN 2.5 unchanged, avg tokens 77.7 → 77.8, max CCN 15 and 0 warnings unchanged. The addon grew; it did not get denser.
- **band:** still 8 files on notice, 0 over the cap. `modules/Hud_States.lua` is now 1382 lines (the Your best section's wiring; the card itself went into the new `modules/Hud_Best.lua`) and `modules/Hud.lua` 1133.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `locales/enUS.lua` | 1198 | Accepted — flat string table, not logic |
| 1000–1500 (on notice) | `modules/Hud.lua` | 1133 | Accepted — cohesive window shell; bodies and rows already split out |
| 1000–1500 (on notice) | `modules/Hud_States.lua` | 1382 | Accepted — six sibling HUD bodies sharing layout helpers; split by body if it grows |
| 1000–1500 (on notice) | `modules/Results_Detail.lua` | 1227 | Accepted — one cohesive pane built of small methods |
| 1000–1500 (on notice) | `modules/Results_Runs.lua` | 1119 | Accepted — one tab: filter bar over its run list |
| 1000–1500 (on notice) | `modules/Results_Table.lua` | 1203 | Accepted — cohesive pooled table plus its cell binders |
| 1000–1500 (on notice) | `modules/Results_Timeline.lua` | 1164 | Split 2026-10-31 (FX-DR-SIZE): pure half moved to `modules/Results_TimelineData.lua`; 1162 lines, still on notice as one window of small helpers |
| 1000–1500 (on notice) | `tests/test_insights.lua` | 1268 | Accepted — case count, not tangle |

Every disposition was carried forward unchanged by the runner; none is blank.

## Actions

None.
