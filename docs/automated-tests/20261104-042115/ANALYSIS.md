# Analysis — 20261104-042115

- **Addon:** DpsRace 0.1.0
- **Verdict:** green
- **Commit:** 05ca784 (feat/2026-11-01-full-skinning), clean
- **Previous run:** 20261103-030550 (525bf53)

## Headline

All four suites pass on a clean tree at `05ca784`, the head of the round 6 work and 32 commits after the previous run (rounds 3 to 6 of the full skinning run). Lint and tests are green, with 65 more cases and 8 more linted files. One function crossed the complexity threshold for the first time: `Preview.Start`, now CCN 18, in `modules/Preview.lua`. That does not fail this run, but it must be peeled before the next tag, because the release gate allows zero functions above CCN 15.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261103-030550 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 180 files | [`lint.txt`](lint.txt) | files 172 → 180 |
| tests | pass | 1444 passed, 1 skipped, 0 failed, 1445 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 1380 → 1445 |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 9 scenarios; live-HUD and combat-event allocation up about 145 bytes/iter (see below) |
| complexity | pass (recorded, non-gating) | see below | [`complexity.txt`](complexity.txt) | max CCN 15 → 18, warnings 0 → 1; averages flat |

| Metric | Value |
|---|---|
| Total NLOC | 47572 |
| Functions | 5559 |
| Avg NLOC / function | 7.9 |
| Avg CCN | 2.5 |
| Max CCN | 18 |
| Avg tokens / function | 77.9 |
| Warnings (CCN > 15) | 1 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every value comes from `suites.complexity` in [`manifest.json`](manifest.json). `blindFiles` and `crashedFiles` are both 0, so the measurement saw every file and completed.

**complexity:** [`complexity.txt`](complexity.txt) reports `Preview.Start@160-190@./modules/Preview.lua` with NLOC 28 and CCN 18. This is a regression on this branch, not a newly measured function. Both runs were sighted (`blindFiles` 0), and the previous run's max was 15. The only commit since `525bf53` that touches `modules/Preview.lua` is `3ce0a36` (R5-DR2). It added the sim step-session branch (`opts.mode == "sim" and not opts.session and NS.Sim and NS.Sim.session`) and the `Preview.Refusal` early return. The score comes from guards and defaults that `lizard` counts as decisions, such as `opts or queued or {...}`, the `and`/`or` mode selections and the `mode == "sim"` branches. The control flow itself is not tangled. Moving the sim-session hand-off and the mode/dataset selection into two local helpers would bring it under 15 without changing behavior.

**tests:** the one skipped case is the same declared skip the previous runs carried (`diagnostics contract: an addon that opts out ...`, [`tests.txt`](tests.txt)). It is counted in the total and not in `passed`.

## What moved

- **lint:** 0/0 again; files 172 → 180.
- **tests:** 1380 → 1445 total (1379 → 1444 passed, skip 1 → 1). The cases came from the 32 commits of rounds 3 to 6: icon edge and zoom (R3-FIX, R4-ZOOM, R4-HUD, R5-ICON), the launcher and Your best card changes (R4-DR1 to R4-DR7), the windows' title band (R5-DR1, R5-WIN), `/dr sim`'s step panel and real-time sample race (R4-DR6, R5-DR2), the skin picker's test-mode preview (R6-PV) and the Master controls Sim mode box (R6-SIM). [`test-cases.md`](test-cases.md) lists them.
- **perf:** the same 9 scenarios. `bytes/iter` rose on the live-HUD and combat-event paths: `hudLiveCaptureOff`/`On` 6112.4 → 6256.4, `combatEventCaptureOff` 2222.3 → 2368.5 and `combatEventCaptureOn` 2224.5 → 2368.5. It is flat on `raceEvent*`, `hudTick*` and `raceInputStoodDown` ([`perf.txt`](perf.txt) against [`../20261103-030550/perf.txt`](../20261103-030550/perf.txt)). Each capture pair still differs by only the one note per iteration. This run does not show which commit added the roughly 145 bytes. Timings are for orientation only.
- **complexity:** NLOC 45944 → 47572, functions 5371 → 5559. Avg NLOC (7.9) and avg CCN (2.5) are unchanged, and avg tokens went from 77.8 to 77.9. Max CCN went from 15 to 18 and warnings from 0 to 1 (`Preview.Start`, above). The addon grew without getting denser on average, and one function crossed the threshold.
- **band:** still 8 files on notice and 0 over the cap. `modules/Hud_States.lua` went from 1382 to 1407 lines, the closest to the cap. `modules/Hud.lua` went from 1133 to 1102, `locales/enUS.lua` from 1198 to 1208, `modules/Results_Detail.lua` from 1227 to 1250, `modules/Results_Table.lua` from 1203 to 1211 and `modules/Results_Timeline.lua` from 1164 to 1161. `modules/Results_Runs.lua` (1119) and `tests/test_insights.lua` (1268) did not change.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `Preview.Start` | 18 | `modules/Preview.lua` | **Peel next** — new this run, from R5-DR2 (`3ce0a36`). The score is guard and default density, not tangled control flow. It blocks the release gate. |

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `locales/enUS.lua` | 1208 | Accepted — flat string table, not logic |
| 1000–1500 (on notice) | `modules/Hud.lua` | 1102 | Accepted — cohesive window shell; bodies and rows already split out |
| 1000–1500 (on notice) | `modules/Hud_States.lua` | 1407 | Accepted — six sibling HUD bodies sharing layout helpers; split by body if it grows |
| 1000–1500 (on notice) | `modules/Results_Detail.lua` | 1250 | Accepted — one cohesive pane built of small methods |
| 1000–1500 (on notice) | `modules/Results_Runs.lua` | 1119 | Accepted — one tab: filter bar over its run list |
| 1000–1500 (on notice) | `modules/Results_Table.lua` | 1211 | Accepted — cohesive pooled table plus its cell binders |
| 1000–1500 (on notice) | `modules/Results_Timeline.lua` | 1161 | Split 2026-10-31 (FX-DR-SIZE): pure half moved to `modules/Results_TimelineData.lua`; 1162 lines, still on notice as one window of small helpers |
| 1000–1500 (on notice) | `tests/test_insights.lua` | 1268 | Accepted — case count, not tangle |

The runner carried every file disposition forward unchanged. The function row arrived blank because it is new, and this run assigns it **Peel next**.

## Actions

1. `modules/Preview.lua`, `Preview.Start` (CCN 18): move the sim step-session hand-off and the mode/dataset selection into local helpers so the function is at CCN 15 or below. Pin the behavior first with the existing `/dr sim` and test-mode cases. This must happen before the next tag, because `/dev-copilot:bump-version` refuses a release with a function above CCN 15. No issue or deviation tracks it yet; it is new here.
2. `modules/Hud_States.lua` (1407 lines, 93 under the cap): it has grown in each of the last two runs. If it grows again, split it by body, as its disposition already says.
