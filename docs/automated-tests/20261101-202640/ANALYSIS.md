# Analysis — 20261101-202640

- **Addon:** DpsRace 0.1.0
- **Verdict:** red (per [`manifest.json`](manifest.json))
- **Commit:** see [`manifest.json`](manifest.json)
- **Previous run:** 20261101-202232

## Headline

Perf passes on the fixed harness. Tests fail one case, the line-ending gate, on the previous bundle's `ANALYSIS.md`: that file was written with bare LF over a CRLF-declared path. No addon code is involved.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-202232 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 168 files | [`lint.txt`](lint.txt) | unchanged |
| tests | fail | 1351 passed, 1 failed, 1 skipped, 1353 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | the eol case failed |
| perf | pass | 9 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | combatEventCaptureOff 1241.4 -> 2223.4 bytes/iter, the other scenarios unchanged |
| complexity | pass | 0 warnings, max CCN 15 | [`complexity.txt`](complexity.txt) | 44989 -> 44995 NLOC |

## Actions

The working copy of that `ANALYSIS.md` takes the declared CRLF, its content unchanged. The next run records the result.
