# Analysis — 20261031-223212

- **Addon:** DpsRace 0.1.0
- **Verdict:** green (per [`manifest.json`](manifest.json)); label `findings-remediation`
- **Commit:** f5b4f6d (feat/2026-10-31-findings-remediation)
- **Previous run:** 20261031-202021

## Headline

All four suites pass: 0 warnings / 0 errors over 165 files, 1258 of 1259 cases passed with the 1 standing
skip, 9 perf scenarios, and zero functions above CCN 15 with no blind or crashed file. The previous run's
amber is gone: perf moved fail → pass, and that move came from the test side (the mock's widget recorder),
not from a change to what the addon allocates. Nothing is left to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261031-202021 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 165 files | [`lint.txt`](lint.txt) | Files 156 → 165; still 0/0 |
| tests | pass | 1258 passed, 1 skipped, 0 failed, 1259 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Total 1207 → 1259; skips unchanged at 1 |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | fail → pass; see What moved |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 42513 → 44245; band files 10 → 8 |

**Complexity is reported in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 44245 |
| Functions | 5113 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 78.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests.** The 1 skip is a pre-existing condition, not a failure: the diagnostics-contract case for an
addon that opts out of logging. This addon keeps the default, so the case above it holds the behavior
([`tests.txt`](tests.txt)). The skip is counted in neither the passed figure nor the failed one.

## What moved

- **lint:** in scope 156 → 165 files; 0/0 did not move.
- **tests:** 1207 → 1259 cases, 1206 → 1258 passed; failures stayed 0 and skips stayed 1.
- **perf:** fail → pass, with 9 scenarios both times. Allocation moved on two scenario pairs: `hudLive`
  7264.4 → 6112.4 and `combatEvent` 3376.5 → 2224.5 bytes/iter, both down. `hudTick` (800.3), `raceEvent`
  (0.3) and `raceInputStoodDown` (0.0) did not move. Commit 9c1080a accounts for this: the mock's widget
  recorder was being billed to the scenarios, `tests/perf.lua` now installs it quiet, and the same commit
  lowered the ceilings. It is test side only, so read the drop as a corrected measurement and not as an
  addon that allocates less. Timings are orientation only and are not compared here.
- **complexity:** NLOC 42513 → 44245 and functions 4886 → 5113, so the addon grew. Avg CCN (2.5) and avg
  NLOC (8.0) did not move and avg tokens moved 79.0 → 78.6, so it did not get denser. Max CCN stayed 15 and
  warnings stayed 0. Band files 10 → 8, and over-cap files stayed 0.
- **Record:** the runner notes the previous bundle measured 0d913d2, 25 commits behind this HEAD, so every
  delta above spans that whole remediation and not one change.

## Complexity watch list

Functions `lizard` warned on:

None.

Files by `layout-§1` band:

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `locales/enUS.lua` | 1167 | Accepted — flat string table, not logic |
| 1000–1500 (on notice) | `modules/Hud.lua` | 1114 | Accepted — cohesive window shell; bodies and rows already split out |
| 1000–1500 (on notice) | `modules/Hud_States.lua` | 1364 | Accepted — six sibling HUD bodies sharing layout helpers; split by body if it grows |
| 1000–1500 (on notice) | `modules/Results_Detail.lua` | 1227 | Accepted — one cohesive pane built of small methods |
| 1000–1500 (on notice) | `modules/Results_Runs.lua` | 1119 | Accepted — one tab: filter bar over its run list |
| 1000–1500 (on notice) | `modules/Results_Table.lua` | 1195 | Accepted — cohesive pooled table plus its cell binders |
| 1000–1500 (on notice) | `modules/Results_Timeline.lua` | 1162 | Split 2026-10-31 (FX-DR-SIZE): pure half moved to `modules/Results_TimelineData.lua`; 1162 lines, still on notice as one window of small helpers |
| 1000–1500 (on notice) | `tests/test_insights.lua` | 1225 | Accepted — case count, not tangle |

No row is new, so no disposition was owed and every one is carried forward as the runner wrote it.
`tests/test_hud.lua` and `tests/test_results.lua` left the band, as their FX-DR-SIZE dispositions said
they would. `modules/Results_Timeline.lua` dropped 1449 → 1162 and stays on notice. No row has a
release-run history of being Accepted, because no release run has happened since these rows arrived.

## Actions

None. The previous run's one action, the `hudLive` and `combatEvent` ruling in `tests/perf.lua`, is
closed by 9c1080a.
