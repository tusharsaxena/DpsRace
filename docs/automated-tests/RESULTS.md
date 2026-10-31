# Automated test results

<!-- Regenerated whole by tests/_kit/run-automated-tests.sh on every run. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->
<!-- Everything here is generated EXCEPT the watch list's Disposition column. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate the run and gate the commit** (`testing-§4`).
**`perf` and `complexity` never fail a run and never block a commit** — they are recorded,
read and compared, not thresholded (`performance-§9`, `performance-§10`).

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**
(`automated-tests-§3`, *The release gate*), evaluated by `/dev-copilot:bump-version` from the
`manifest.json` the release run writes — not by this script, whose exit code is unchanged.

A `skip` is a suite that did not run at all. It is never a pass, and at the release gate it is
**NOT EVALUATED** rather than passed: install the tool and re-run. A `—` is a suite that was
not selected, which is a different fact again.

The **Tests** cell reads `passed/skipped/total`.

**Commit** is the short sha the run measured and **Tree** is whether that tree was clean at the
time. Both are read from git by the runner; neither is ever typed. A **dirty** row measured bytes
that no sha can bring back, so it is kept as an experiment honestly labeled rather than dropped —
and a release record is refused outright on a dirty tree, so no release row can be one.

A row reading `unknown` in both cells was recorded before the runner emitted them. That is what
the record holds about those runs — it is not `clean`, and it is not reconstructed from git
archaeology, for the same reason a skip is never a pass (`automated-tests-§4`).

| Run | Commit | Tree | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20261101-005723`](20261101-005723/) | `3b233e7` | clean | 0.1.0 | 0/0 | 166 | 1260/1/1261 | pass | 43740 | 5058 | 8.0 | 2.5 | 15 | 0 | **green** |
| [`20261031-223212`](20261031-223212/) | `f5b4f6d` | clean | 0.1.0 | 0/0 | 165 | 1258/1/1259 | pass | 44245 | 5113 | 8.0 | 2.5 | 15 | 0 | **green** |
| [`20261031-202021`](20261031-202021/) | `0d913d2` | clean | 0.1.0 | 0/0 | 156 | 1206/1/1207 | fail | 42513 | 4886 | 8.0 | 2.5 | 15 | 0 | **amber** |
| [`20261023-225647`](20261023-225647/) | `7e86054` | clean | 0.1.0 → 0.1.0 | 0/0 | 79 | 428/1/429 | pass | 13953 | 1819 | 7.0 | 2.4 | 15 | 0 | **green** |
| [`20261023-225205`](20261023-225205/) | `d817bdb` | clean | 0.1.0 → 0.1.0 | 0/0 | 79 | 428/1/429 | pass | 13913 | 1796 | 7.1 | 2.5 | 36 | 4 | **green** |

## Test suite

**1261 cases** — 1260 passed, 0 failed, 1 skipped. The generated inventory
[`20261101-005723/test-cases.md`](20261101-005723/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **1259 → 1261** since the previous run.

**1 case(s) reported a `skip`.** A skip is counted in the total and never in `passed`, and at
the release gate it is NOT EVALUATED rather than passed (`automated-tests-§3`).

## Lint

**0 warnings / 0 errors over 166 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 6 path(s) from it — `libs/`, `tests/_kit/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `_dev/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**9 scenarios** from `tests/perf.lua`; the measurements are in
[`20261101-005723/perf.json`](20261101-005723/perf.json).

| `scenario` | `iters` | `ms/iter` | `notes/iter` | `bytes/iter` |
|---|---|---|---|---|
| `raceEventCaptureOff` | 2000 | 0.00169 | 0.00 | 0.3 |
| `raceEventCaptureOn` | 2000 | 0.00210 | 1.00 | 0.3 |
| `hudTickCaptureOff` | 2000 | 0.01837 | 0.00 | 800.3 |
| `hudTickCaptureOn` | 2000 | 0.01733 | 1.00 | 800.3 |
| `hudLiveCaptureOff` | 2000 | 0.07582 | 0.00 | 6112.4 |
| `hudLiveCaptureOn` | 2000 | 0.07770 | 1.00 | 6112.4 |
| `combatEventCaptureOff` | 2000 | 0.08549 | 0.00 | 2224.5 |
| `combatEventCaptureOn` | 2000 | 0.08957 | 1.00 | 2224.5 |
| `raceInputStoodDown` | 2000 | 0.00012 | 0.00 | 0.0 |

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20261101-005723`](20261101-005723/) — **this run's measurement, not its diff.** Max CCN **15** across 5058
functions, **0** of them warned on; 8 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

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

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

