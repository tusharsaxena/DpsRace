# Analysis — 20261101-005723

- **Addon:** DpsRace 0.1.0
- **Verdict:** green (per [`manifest.json`](manifest.json)); label `v1.84.0-adoption`
- **Commit:** 3b233e7 (feat/2026-10-31-findings-remediation)
- **Previous run:** 20261031-223212

## Headline

All four suites pass on the LibKa0s v1.84.0 adoption tree: 0 warnings / 0 errors over 166 files, 1260 of
1261 cases passed with the 1 standing skip, 9 perf scenarios, and zero functions above CCN 15 with no blind
or crashed file. NLOC and function count fell because the local chart module went to the library. Perf
timings rose while allocations stayed identical, and every suite slowed with them, so that reads as a busy
host. Nothing is left to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261031-223212 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 166 files | [`lint.txt`](lint.txt) | Files 165 → 166; still 0/0 |
| tests | pass | 1260 passed, 1 skipped, 0 failed, 1261 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Total 1259 → 1261; skips unchanged at 1 |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | Scenario count unchanged; timings up, bytes and notes unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC and functions down; averages and max unchanged |

| Metric | Value |
|---|---|
| Total NLOC | 43740 |
| Functions | 5058 |
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

Every suite is a clean pass. The one skip in [`tests.txt`](tests.txt) is the standing diagnostics-contract
case for an addon that opts out of logging. DpsRace keeps the default, so the case above it holds the
contract. It is counted in the total and not in `passed`.

## What moved

- **lint:** files 165 → 166, still 0 warnings / 0 errors. The source adds `core/ChartsSetup.lua` and
  `tests/test_switched_sections.lua` and removes `modules/Results_InsightsCharts.lua`, a net of one.
- **tests:** total 1259 → 1261, passed 1258 → 1260, skipped 1 and failed 0 unchanged. Per
  [`test-cases.md`](test-cases.md), `test_switched_sections.lua` adds 3 cases and `test_insights.lua` goes
  59 → 58 as the charts move to the library.
- **perf:** `bytesPerIter` and `notesPerIter` are identical in all 9 scenarios in [`perf.json`](perf.json).
  Timings rose in most: `hudLiveCaptureOff` 0.06064 → 0.07582 ms/iter, `combatEventCaptureOn`
  0.07520 → 0.08957, `hudTickCaptureOff` 0.01525 → 0.01837; `raceEventCaptureOff` and `raceInputStoodDown`
  held. The rest of the battery slowed too (tests suite 34165 → 42589 ms, lint 1740 → 5123 ms in
  [`manifest.json`](manifest.json)), and the run shared the machine with other repos' batteries. The commit
  range changes no HUD, race or combat module, though the re-vendored library is not separately excluded.
  Read this as host load, recorded rather than proven, and compare against the next quiet run.
- **complexity:** NLOC 44245 → 43740 and functions 5113 → 5058, from the chart module's removal. Avg NLOC
  8.0, avg CCN 2.5, max CCN 15, avg tokens 78.6, warnings 0, blind 0 and crashed 0 are all unchanged. The
  band stays at 8 files with 0 over the cap; `tests/test_insights.lua` went 1225 → 1203 LOC.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `locales/enUS.lua` | 1167 | Accepted — flat string table, not logic |
| 1000–1500 (on notice) | `modules/Hud.lua` | 1114 | Accepted — cohesive window shell; bodies and rows already split out |
| 1000–1500 (on notice) | `modules/Hud_States.lua` | 1364 | Accepted — six sibling HUD bodies sharing layout helpers; split by body if it grows |
| 1000–1500 (on notice) | `modules/Results_Detail.lua` | 1227 | Accepted — one cohesive pane built of small methods |
| 1000–1500 (on notice) | `modules/Results_Runs.lua` | 1119 | Accepted — one tab: filter bar over its run list |
| 1000–1500 (on notice) | `modules/Results_Table.lua` | 1195 | Accepted — cohesive pooled table plus its cell binders |
| 1000–1500 (on notice) | `modules/Results_Timeline.lua` | 1162 | Split 2026-10-31 (FX-DR-SIZE): pure half moved to `modules/Results_TimelineData.lua`; 1162 lines, still on notice as one window of small helpers |
| 1000–1500 (on notice) | `tests/test_insights.lua` | 1203 | Accepted — case count, not tangle |

No entry is new, so no Disposition was owed this run; the runner carried all eight.

## Actions

None.
