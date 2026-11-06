Delta: LibKa0s v1.85.0 -> v1.89.0

Item `V89-DR` of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/00_PLAN.md`. The payload
comes from the pushed tag (`git -C ../LibKa0s archive v1.89.0 LibKa0s testkit tools`, extracted into a
scratch directory; tag commit `df00e5f`, `ls-remote` shows the tag on origin). Written before the copy.

## 3a. Claimed version, and the base

```
$ grep -n '[Bb]undles' CLAUDE.md
43:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0 (MIT).
$ c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit); git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0        # c = 11fe1b4
$ git log --format='%h %s' "$c..HEAD" -- CLAUDE.md
ad7ac39 REVENDOR-STD: Re-vendor the Ka0s standard v2.102.2 (quirks catalog block, new midnight-quirks.md)
```

The two agree: the base is **v1.85.0**. `ad7ac39` did not roll the line. Step 0's pre-flight for this addon
(the run's `inputs/step0-preflight.txt`) reads `DpsRace  2026-11-01-v1.85.0  base v1.84.0  vendored-before
v1.84.0@359f6eb  ok`, so there is no base correction to record.

```
$ git -C ../LibKa0s log --oneline v1.85.0..v1.89.0 | wc -l     # 24 commits: v1.86.0, v1.87.0, v1.88.0, v1.89.0
$ git -C ../LibKa0s diff --stat v1.85.0 v1.89.0 | tail -1
 83 files changed, 125301 insertions(+), 321 deletions(-)
```

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` before the copy
shows the v1.85.0 minors (`Toast` 3, `Widgets` 22, `DIAG_MINOR` 6, no IconBrowser file), which is what
the line claims. Line and bytes agree.

## 3c. Per-file minor delta (files from the tag's `LibKa0s.xml`)

Every file not listed is unchanged.

| File | old | new |
|---|---|---|
| `Toast.lua` | `LibKa0s-Toast-1.0`, 3 | 4 |
| `Widgets.lua` | `LibKa0s-Widgets-1.0`, 22 | 23 |
| `DebugLogDiagnostics.lua` | `DIAG_MINOR` 6 | 7 |
| `IconBrowserSources.lua` | (new) | `LibKa0s-IconBrowser-1.0`, 1 |
| `IconBrowserWindow.lua` | (new) | `WINDOW_MINOR` 1 |
| `IconBrowser.lua` | (new) | `BROWSER_MINOR` 1 |

No file in this addon is ahead of the tag and none is behind after the copy: no cross-major skew.

## 3d. Both diffs (before the copy)

```
$ diff -rq --strip-trailing-cr <x>/LibKa0s libs/LibKa0s | grep -v 'Only in <x>.*media/icons'
Files .../DebugLogDiagnostics.lua differ
Only in <x>/LibKa0s: IconBrowser.lua
Only in <x>/LibKa0s: IconBrowserSources.lua
Only in <x>/LibKa0s: IconBrowserWindow.lua
Files .../LibKa0s.xml differ
Files .../Toast.lua differ
Files .../Widgets.lua differ
$ diff -rq --strip-trailing-cr <x>/testkit tests/_kit
Files .../README.md differ
Files .../framework.lua differ
Files .../mock_ace.lua differ
```

The byte diff (no `--strip-trailing-cr`) prints the same lines: no line-ending drift. Under
`media/icons` the only lines are 1630 `Only in <x>/LibKa0s/media/icons…` lines, the icons this addon does
not declare (the declaration working). No `Only in libs/LibKa0s` line: nothing was removed upstream.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/`:
Media, Env, Charts, DebugLog, Compat, Core, Lifecycle, Skin (`core/Database.lua`, `core/SkinSetup.lua`,
`modules/Style.lua`), Launcher, Bus, Perf, Widgets, Sim, Pool, Toast, Schema, Slash, Options. One seam
file per major as before. **`LibKa0s-IconBrowser-1.0` has no lookup**: an unadopted module (Step 5, C).

## 3f. Kit revision

```
$ grep -n 'Kit.VERSION' <x>/testkit/framework.lua tests/_kit/framework.lua
<x>/testkit/framework.lua:20:Kit.VERSION = 51
tests/_kit/framework.lua:20:Kit.VERSION = 50
```

Kit 50 -> 51, the CallbackHandler unregister guard. The pairing rule (LibKa0s v1.9.0 or newer takes kit
revision 11 or newer in the same commit) holds by construction: both payloads move whole, together.

## 3g. Contract delta

Majors that moved a minor and that this addon looks up: **Toast**, **Widgets**, **DebugLog**.

- **Toast 3 -> 4** (`docs/api/Toast/version-3-docs.md` -> `version-4-docs.md`). Without `stack` the toast
  is the version 3 toast. The one queue rule that moves for every host (a toast sent back from the screen
  to wait drops nothing) is reached only through `Hold`, a smaller stack or `Preview` on a full stack;
  `modules/BestToast.lua` builds a one-at-a-time toast. Class A, apart from the stub below.
- **Widgets 22 -> 23** (`version-22.5.12.6.7.5-docs.md` -> `version-23.5.12.6.7.5-docs.md`). Additive
  row fields for `W.ContextMenu`; "every single-level menu, a dropdown's and a host's, is unchanged" (v23
  doc, *What changed at this version*). `core/WidgetsSetup.lua`'s in-place reopen keeps working. No
  degradation stub of this major mirrors a member (the seam answers nil or a no-op).
- **DebugLog 22.6.1.4 -> 22.7.1.4**. No member change; the `LibKa0s running:` line names IconBrowser when
  that major runs. `grep -rn 'DebugLogDiagnostics\|DIAG_MINOR' tests` finds only `tests/run.lua:23`'s
  floor list of files, which is a presence list, not a minor pin.

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` prints nothing: no
host-supplied member to rebind.

### Blockers

1. **The Toast degradation stub** (`core/ToastSetup.lua`, `NS.ToastStub`) lacks `SetStack`, `Visible` and
   `FrameFor`. `docs/api/Toast/version-4-docs.md` (*The degradation stub*, lines 201-225) lists them and
   says "A stub written against version 3 lacks `SetStack`, `Visible` and `FrameFor`, and its parity case
   reddens on the re-vendor until it gains them". The parity case is
   `tests/test_surface_parity.lua:164-172` (`T.assertSurfaceParity` of a live instance against the stub).
   **Fixed in this commit**: the stub gains the three members as the document writes them, and its
   `Stats()` gains `keys = {}` (owed since version 1 of the document and missing) plus the version 4
   fields `visible`, `visibleKeys`, `stack`, `grow`, so a diagnostics read of the degraded toast answers
   the documented shape.

No other blocker.

## 3h. Tags vendored and never recorded

```
horizon=2026-10-24
vendored: v1.77.0 v1.80.0 v1.81.0 v1.82.0 v1.83.0 v1.84.0 v1.85.0
recorded: v1.77.0 v1.80.0 v1.81.0 v1.82.0 v1.83.0 v1.84.0 v1.85.0
unrecorded: (none)
```

Empty: no span bundle.

## 3i. The icon declaration

```
$ grep -n 'LibKa0s icons:' CLAUDE.md
44:LibKa0s icons: arrow-left, chart, chat, chevron-down, chevron-left, chevron-right, chevron-up, clear, close, confirm, copy, export, eye, flag, info, lock, move, ph:check, ph:flag, ph:ghost, ph:skull, ph:trophy, ph:x, reset, settings, sort-down, sort-up, unlock, volume-high.
```

Directly under the provenance line (43), which ends its own line: no split. **Kept unchanged**, as the run
plan decides (no fact in this delta forces a change: no new library-drawn name in v1.86.0..v1.89.0 for a
surface this addon wires; the cascade's arrow is client art, `Interface\ChatFrame\ChatFrameExpandArrow`).
`chevron-right` stays until `V89A-DR` decides whether anything else draws it. Hand lists have drifted
before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`); the owner's
in-client smoke is the backstop.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v /_kit/` prints nothing. No
blocker.

## Dead stub mirrors

`grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` prints nothing, and
no `__` member was removed in this range.
