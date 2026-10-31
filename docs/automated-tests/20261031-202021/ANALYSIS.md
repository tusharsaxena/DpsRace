# Analysis — 20261031-202021

- **Addon:** DpsRace 0.1.0
- **Verdict:** amber (per [`manifest.json`](manifest.json)); perf failed, so the tag gate is not met
- **Commit:** 0d913d2 (feat/2026-10-31-font-pickers-skin-faces)
- **Previous run:** 20261023-225647

## Headline

Lint and tests pass, so the run and the commit gates are met: 0 warnings / 0 errors over 156 files, and
1206 of 1207 cases passed with the 1 standing skip. Complexity is sighted and clean, with **zero functions
above CCN 15** (max 15), no blind or crashed file and nothing over the 1500 cap. The amber is perf: four
scenarios allocate over their byte ceilings in `tests/perf.lua`, which is a pre-existing condition that
**gates the next tag** and needs a decision before it, not before this merge.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261023-225647 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 156 files | [`lint.txt`](lint.txt) | Files 79 → 156; still 0/0 |
| tests | pass | 1206 passed, 1 skipped, 0 failed, 1207 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Total 429 → 1207; skips unchanged at 1 |
| perf | **fail** | 9 scenarios, 4 assertions failed | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | pass → fail; see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 13953 → 42513; band files 1 → 10 |

**Complexity is reported in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 42513 |
| Functions | 4886 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 79.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 10 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**perf (a pre-existing condition, not a regression from this branch's skin work).** `perf.txt` lists
`hudLiveCaptureOff` and `hudLiveCaptureOn` at 7264.4 bytes/iter over a 7000-byte ceiling, and
`combatEventCaptureOff` and `combatEventCaptureOn` at 3376.5 bytes/iter over a 3000-byte ceiling. The
comment above `BYTE_CEILING` in `tests/perf.lua` already records both figures, re-measured on 2026-10-25,
as standing over their ceilings and "still the finding". That re-measurement was never closed: neither
the ceilings nor the allocations were changed. Perf does not gate the run or the commit, and it does gate
the tag (`automated-tests-§3`).

**tests.** The 1 skip is the diagnostics-contract case for an addon that opts out of logging: this addon
keeps the default, so the case above it holds the behavior instead ([`tests.txt`](tests.txt)).

## What moved

- **lint:** in scope 79 → 156 files; 0/0 did not move.
- **tests:** 429 → 1207 cases, 428 → 1206 passed; failures stayed 0 and skips stayed 1.
- **perf:** pass → fail. Allocation moved on three scenario pairs: `hudTick` 928.3 → 800.3 bytes/iter
  (down), `hudLive` 6384.1 → 7264.4 and `combatEvent` 2784.5 → 3376.5 (both up, and now over their
  ceilings). `raceEvent` (0.3) and `raceInputStoodDown` (0.0) did not move. Timings are orientation only
  and are not compared here.
- **complexity:** the addon grew: NLOC 13953 → 42513, functions 1819 → 4886. Avg CCN moved 2.4 → 2.5, avg
  NLOC 7.0 → 8.0 and avg tokens 62.5 → 79.0, so it got slightly denser as well as larger, and the density
  stays low. Max CCN stayed 15 and warnings stayed 0.
- **Record:** the runner notes the previous bundle measured 7e86054, 289 commits behind this HEAD, so
  every delta above spans all of that work and not one change.

## Complexity watch list

Functions `lizard` warned on:

None.

Files by `layout-§1` band:

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `locales/enUS.lua` | 1149 | Accepted — flat string table, not logic |
| 1000–1500 (on notice) | `modules/Hud.lua` | 1100 | Accepted — cohesive window shell; bodies and rows already split out |
| 1000–1500 (on notice) | `modules/Hud_States.lua` | 1368 | Accepted — six sibling HUD bodies sharing layout helpers; split by body if it grows |
| 1000–1500 (on notice) | `modules/Results_Detail.lua` | 1227 | Accepted — one cohesive pane built of small methods |
| 1000–1500 (on notice) | `modules/Results_Runs.lua` | 1120 | Accepted — one tab: filter bar over its run list |
| 1000–1500 (on notice) | `modules/Results_Table.lua` | 1188 | Accepted — cohesive pooled table plus its cell binders |
| 1000–1500 (on notice) | `modules/Results_Timeline.lua` | 1449 | Accepted — one pop-out window of small helpers; near the cap, so peel before adding more |
| 1000–1500 (on notice) | `tests/test_hud.lua` | 1478 | Accepted — case count, not tangle; near the cap, so the next HUD cases start a new file |
| 1000–1500 (on notice) | `tests/test_insights.lua` | 1225 | Accepted — case count, not tangle |
| 1000–1500 (on notice) | `tests/test_results.lua` | 1478 | Accepted — case count, not tangle; near the cap, so the next Results cases start a new file |

All ten rows are new since the previous run, and the previous run's one row left with `probe/`, which
118d4a0 removed. None has a release-run history of being Accepted.

## Actions

1. `tests/perf.lua`: rule on `hudLive` and `combatEvent` before the next tag, either by cutting the
   allocation or by re-measuring and raising `BYTE_CEILING` with the reason, as that file's comment
   requires. The comment records the finding but no issue tracks it, so this is new here. The same pass
   can lower the `hudTick` ceiling, which sits well above its measured figure.
