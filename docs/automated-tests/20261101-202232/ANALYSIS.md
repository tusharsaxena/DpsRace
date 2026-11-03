# Analysis — 20261101-202232

- **Addon:** DpsRace 0.1.0
- **Verdict:** amber (per [`manifest.json`](manifest.json))
- **Commit:** 5bfa6e5 (feat/2026-11-01-full-skinning)
- **Previous run:** 20261101-145106

## Headline

Lint and tests pass on the re-cut LibKa0s v1.85.0 with the kit's skin gate adopted. Perf fails one pair assertion, which is the harness and not the path: see *What moved*. The next run records the harness fix.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-145106 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 168 files | [`lint.txt`](lint.txt) | unchanged file count: one suite out, one fixture in |
| tests | pass | 1352 passed, 1 skipped, 0 failed, 1353 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1295 -> 1353 cases |
| perf | fail | 9 scenarios, 1 assertion failed | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | combatEventCaptureOff 2224.5 -> 1241.4 bytes/iter; every other scenario's bytes unchanged |
| complexity | pass | 0 warnings, max CCN 15 | [`complexity.txt`](complexity.txt) | 44703 -> 44989 NLOC, 5174 -> 5251 functions, avg NLOC 8.0 -> 7.9, avg tokens 78.5 -> 78.0, avg CCN 2.5 held |

## What moved

- **perf:** `combatEventCaptureOn` read 2224.5 bytes/iter, as before, and its off half read 1241.4, so the on half stood more than 64 over it. A per-iteration probe, outside this bundle, showed one step of the 2000 dropping 1917.8 KB, about the whole gap (983 bytes x 2000). The path did not get cheaper: a large table rehashed with the collector stopped, inside that half. Which table was not identified.
- **tests:** the kit's `test_skin_values` and `test_skin_switch` in, `test_skin_literals` out, new cases in `test_skin_flip` and `test_skin_menus`. The one skip is the standing diagnostics contract case.
- **complexity:** nothing above CCN 15.

## Actions

`tests/perf.lua`'s `measure` is fixed in the commit after this one and recorded by the next run.
