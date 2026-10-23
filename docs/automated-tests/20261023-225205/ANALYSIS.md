# Analysis — 20261023-225205

- **Addon:** DpsRace 0.1.0
- **Verdict:** green (the run, per [`manifest.json`](manifest.json)); the **release gate is not met** (see Headline)
- **Commit:** d817bdb (feat/pve-v0.1.0)
- **Previous run:** none — this is the first

## Headline

All four suites pass: lint clean over 79 files, 428 of 429 cases passed with 1 skip, 9 perf
scenarios inside their ceilings with every capture-off/on pair holding the zero-overhead rule, and
complexity sighted with no blind or crashed file. The tag is **not** clear: the release gate wants
zero functions above CCN 15 and this run has 4, all in `probe/DpsRaceProbe/DpsRaceProbe.lua`, the
measurement addon kept byte-for-byte under the `layout-§1` deviation row. Whether the probe leaves
the repo before the tag or a deviation row covers it is the owner's decision (Actions 1).

## Suites

| Suite | Status | Result | Artifact | Moved since previous run |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 79 files | [`lint.txt`](lint.txt) | first run |
| tests | pass | 428 passed, 1 skipped, 0 failed, 429 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | first run |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | first run |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | first run |

| Metric | Value |
|---|---|
| Total NLOC | 13913 |
| Functions | 1796 |
| Avg NLOC / function | 7.1 |
| Avg CCN | 2.5 |
| Max CCN | 36 |
| Avg tokens / function | 63.2 |
| Warnings (CCN > 15) | 4 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.02 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests.** The one skip is the kit's diagnostics-contract case for an addon that opts out of the
report turning logging on; this addon keeps the default, so the case does not apply and the case
before it holds the contract ([`tests.txt`](tests.txt)). It is a standing skip, not a regression.

**complexity.** The suite passes as a run, but its 4 warnings are what the release gate counts. All
four are in the probe: `analyzeDamageStop` (22), `summarize` (28), `finalizeResult` (32) and
`DPSRACEPROBE` (36) ([`complexity.txt`](complexity.txt)). No shipped file has a function above 15.
The probe is also the one file in the 1000–1500 band (1068 lines).

## What moved

First run — nothing to diff against; every figure above is a baseline reading.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `analyzeDamageStop` | 22 | `probe/DpsRaceProbe/DpsRaceProbe.lua` | Owner decision pending — probe kept byte-for-byte (layout-§1 row) |
| `summarize` | 28 | `probe/DpsRaceProbe/DpsRaceProbe.lua` | Owner decision pending — probe kept byte-for-byte (layout-§1 row) |
| `finalizeResult` | 32 | `probe/DpsRaceProbe/DpsRaceProbe.lua` | Owner decision pending — probe kept byte-for-byte (layout-§1 row) |
| `DPSRACEPROBE` | 36 | `probe/DpsRaceProbe/DpsRaceProbe.lua` | Owner decision pending — probe kept byte-for-byte (layout-§1 row) |

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `probe/DpsRaceProbe/DpsRaceProbe.lua` | 1068 | Accepted — under the `layout-§1` probe/ deviation row; leaves with probe/ |

## Preview and simulation data

- **Answer:** Current
- **Asked:** 2026-10-23, by hand (first release; no bump command run)
- **Files reviewed:** `modules/Preview.lua` (test mode's scripted race); its suite `tests/test_preview.lua`
- **Commits since the previous release touching them:** not applicable — there is no previous release
- **Note:** test mode was written for this release against the shipped HUD bodies; nothing in it predates them.

## Actions

1. `probe/DpsRaceProbe/DpsRaceProbe.lua`: the release gate (zero functions above CCN 15,
   automated-tests-§3) fails on the probe alone. Owner decision before the tag: move `probe/` out of
   the repo (its `layout-§1` row's re-check trigger), or ratify a `## Documented deviations` row
   covering the CCN gate for the probe. New here.
