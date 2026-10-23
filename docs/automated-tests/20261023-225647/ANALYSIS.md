# Analysis — 20261023-225647

- **Addon:** DpsRace 0.1.0
- **Verdict:** green (per [`manifest.json`](manifest.json)); the release gate is met
- **Commit:** 7e86054 (feat/pve-v0.1.0)
- **Previous run:** 20261023-225205

## Headline

All four suites pass and the release gate is met: lint is clean over 79 files, 428 of 429 cases
passed with 1 standing skip, 9 perf scenarios ran, and complexity is sighted with **zero functions
above CCN 15** (max 15) and no blind or crashed file. The previous run's four warnings, all in
`probe/DpsRaceProbe/DpsRaceProbe.lua`, are gone; the probe's functions were split in 7e86054 and
nothing else moved. Nothing is left to act on before the tag.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261023-225205 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 79 files | [`lint.txt`](lint.txt) | no |
| tests | pass | 428 passed, 1 skipped, 0 failed, 429 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | no |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 9 scenarios |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | warnings 4 → 0, max CCN 36 → 15 |

| Metric | Value |
|---|---|
| Total NLOC | 13953 |
| Functions | 1819 |
| Avg NLOC / function | 7.0 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 62.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests.** The one skip is the kit's diagnostics-contract case for an addon that opts out of the
report turning logging on. This addon keeps the default, so the case does not apply and the case
before it holds the contract ([`tests.txt`](tests.txt), line 418). It is a standing skip, not a
regression.

**perf.** Every capture-off/on pair holds the zero-overhead rule: off records 0.00 notes per
iteration, on records 1.00, and the bytes per iteration are equal within each pair
([`perf.txt`](perf.txt)). `combatEvent` covers the race and meter path through the addon object's
`PLAYER_REGEN_*` handler, which runs one full HUD refresh (2784.5 bytes per iteration);
`raceInputStoodDown` pins a disabled addon's race input at 0.0 bytes. The timings are for
orientation only and are not compared across runs.

## What moved

- **lint:** unchanged, 0/0 over 79 files.
- **tests:** unchanged, 428/1/429.
- **perf:** the same 9 scenarios, all inside their ceilings. Timings are not compared across runs.
- **complexity:** warnings went from 4 to 0 and max CCN from 36 to 15. `analyzeDamageStop`,
  `summarize`, `finalizeResult` and the `/drp` dispatcher in the probe were split into helpers and a
  verb table (7e86054), which is why functions rose by 23 (1796 → 1819), total NLOC by 40
  (13913 → 13953) and avg NLOC fell from 7.1 to 7.0. The probe's LOC went from 1068 to 1140 and
  stays in the 1000–1500 band. No shipped file moved.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `probe/DpsRaceProbe/DpsRaceProbe.lua` | 1140 | Accepted — under the `layout-§1` probe/ deviation row; leaves with probe/ |

## Preview and simulation data

- **Answer:** Current
- **Asked:** 2026-10-23, by hand (first release; no bump command run)
- **Files reviewed:** `modules/Preview.lua` (test mode's scripted race); its suite `tests/test_preview.lua`
- **Commits since the previous release touching them:** not applicable, because there is no previous release
- **Note:** test mode was written for this release against the shipped HUD bodies, and nothing in it predates them.

## Actions

None. The previous run's one action (the probe's four CCN warnings) is closed by 7e86054, and the
`layout-§1` deviation row in `docs/ARCHITECTURE.md` now records that the probe was split and names
5ad52a5 as the code the measurements ran on.
