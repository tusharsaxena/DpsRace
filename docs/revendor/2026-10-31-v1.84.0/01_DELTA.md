Delta: LibKa0s v1.83.0 -> v1.84.0

Multi-repo run (Ka0sAddonsCommonTasks `docs/2026-10-31-FINDINGS_REMEDIATION/M2_LIBRARY_RELEASE.md`). The tag v1.84.0 (e917ccd) is local to the LibKa0s checkout; `git ls-remote --tags origin v1.84.0` prints nothing.

## 3a. Claimed version

`grep -n '[Bb]undles' CLAUDE.md`: line 43, v1.83.0. `git log -1 --format=%h -- libs/LibKa0s tests/_kit`: 0d913d2, whose `CLAUDE.md` also names v1.83.0. The two agree, so the base is v1.83.0. Step 0, this addon only: the newest single-tag bundle `2026-10-24-v1.77.0` states base v1.76.0, and the provenance before 37fff10 was v1.76.0, so it is ok. The roster's other addons are their own runs' to check.

`git -C ../LibKa0s log --oneline v1.83.0..v1.84.0 | wc -l`: 26 commits. `git -C ../LibKa0s diff --stat v1.83.0 v1.84.0`: 145 files.

## 3b, 3c. Actual version, per-file minors

Loop over the tag's `LibKa0s.xml` with the `[A-Z_]*MINOR` grep. Files not listed did not move. An empty old column is a new file. No cross-major skew before the copy: `diff -rq` against the v1.83.0 extract shows only the pruned icons.

| File | v1.83.0 | v1.84.0 |
|---|---|---|
| `Schema.lua` | 2 | 3 |
| `Charts.lua` | new | 1 |
| `ChartsRender.lua` | new | 1 |
| `Skin.lua` | 10 | 11 |
| `SkinOwnerTokens.lua` | new | 1 |
| `SkinDefs.lua` | 18 | 19 |
| `SkinDefsOthers.lua` | new | 1 |
| `WidgetsDragHandle.lua` | 8 | 10 |
| `DebugLogDiagnostics.lua` | 5 | 6 |
| `Slash.lua` | 20 | 21 |
| `Options.lua` | 34 | 35 |
| `OptionsWidgets.lua` | 38 | 40 |
| `OptionsFlow.lua` | new | 2 |
| `OptionsIds.lua` | 5 | 6 |
| `OptionsIdSuggest.lua` | new | 1 |
| `OptionsTabs.lua` | 11 | 13 |
| `OptionsTabbed.lua` | new | 2 |
| `OptionsCompose.lua` | 14 | 15 |
| `OptionsSkinPicker.lua` | 4 | 5 |
| `OptionsSkinPickerRows.lua` | new | 1 |
| `SimPanel.lua` | 8 | 9 |
| `SimPanelRender.lua` | new | 1 |

## 3d. Diffs before the copy

`diff -rq <v1.83.0 extract>/LibKa0s libs/LibKa0s`: only `Only in <extract>/LibKa0s/media/icons` lines (the declaration working). `diff -rq <v1.83.0 extract>/testkit tests/_kit`: empty.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/`: Env, Media, Bus, Launcher, Compat, Lifecycle, DebugLog, Skin (`core/Database.lua`, `core/SkinSetup.lua`, `modules/Style.lua`), Perf, Pool, Toast, Widgets, Core, Options, Schema, Slash. Charts is new in this range and has no lookup yet. Sim, Glow and Item have no lookup either. Sim moved a minor (a pure peel); the other two did not move.

## 3f. Kit revision

`grep -n Kit.VERSION`: 46 -> 47, in the same commit as the payload (the pairing rule). The two payloads move together.

## 3g. Blockers

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: no sites. The API documents of the moved majors were diffed; the moved-surface sentences are additive (`Since` rows) and no host-supplied member's call site moved. No contract blocker.

Owed on the copy, the changelog's own list (not contract changes): the Options degradation stub gains `O.PositionBlock`; `tests/run.lua`'s floor list names the new files it consumes. `DebugLogDiagnostics` minor 6 names Charts in the identity header; no suite here pins minor 5.

## 3h. Tags vendored and unrecorded

The audit's listing over `docs/revendor/`: empty. No span bundle.

## 3i. Icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md`: line 44, directly under the provenance line. Kept. The Charts adoption adds no catalog name (checked at that commit).

Hand lists have drifted elsewhere, and a pruned icon still resolves to a path and draws blank, so the owner's in-client smoke is the backstop.

## 3j. Tests assuming the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v /_kit/`: none.

Dead stub mirrors: `grep -rn __releaseChrome . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: none.
