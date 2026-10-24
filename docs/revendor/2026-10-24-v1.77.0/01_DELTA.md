Delta: LibKa0s v1.76.0 -> v1.77.0

# DpsRace: the LibKa0s delta

Re-vendor of the LOCAL annotated tag `v1.77.0` (not yet pushed; created by LK-90 on the
`feat/2026-10-24-keybinds-layout-strata` run branch of LibKa0s), item DR-RV of the cross-repo run
`Ka0sAddonsCommonTasks/docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/`. Payload extracted from the tag,
never the working tree:

```sh
git -C ../LibKa0s archive v1.77.0 LibKa0s testkit tools | tar -x -C <scratch>/
```

## Step 0: pre-flight

DpsRace had no `docs/revendor/` store before this bundle (`ls docs/revendor/` -> no such
directory), so there is no earlier bundle to check and no base to correct. This is the store's
first bundle and its horizon. The other roster addons are re-vendored by their own items of the run.

## 3a. Claimed version (the base)

```sh
grep -n '[Bb]undles' CLAUDE.md
# 41:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.76.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)       # 39bb2b6
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.76.0
git log --format='%h %s' "$c..HEAD" -- CLAUDE.md               # (none)
```

The two agree. Payload check against the claimed tag:

```sh
git -C ../LibKa0s archive v1.76.0 LibKa0s testkit | tar -x -C <scratch>/claimed
diff -r --strip-trailing-cr <scratch>/claimed/LibKa0s libs/LibKa0s   # only `Only in <scratch>/claimed/LibKa0s/media/icons` lines (the undeclared icons)
diff -rq <scratch>/claimed/testkit tests/_kit                         # empty
```

**Base: v1.76.0.** Range:

```sh
git -C ../LibKa0s log --oneline v1.76.0..v1.77.0
# 78240f7 LK-90: close v1.77.0 with its release record (20261024-074358)
# 3c2bb20 LK-90: split three functions over CCN 15 that the release run found
# ea2cb09 LK-90: close v1.77.0: version block, pointers, consumers, band
# 0a5807d LK-13: Sync the Keybindings tab with Options -> Keybindings
# 9ab9d37 LK-12: Add the Keybindings tab, OptionsKeybinds minor 2
# 0b10ad3 LK-11: address review — refuse BUTTON1/BUTTON2 on the client chord route
# 88dfa8a LK-11: Add OptionsKeybinds.lua minor 1, the key binding model
# 66b7bd4 LK-20: Add O.StrataTooltip, the one shared strata-row tooltip
# 7de587b LK-04: Close the IdList suggestion list at the start of combat
# f452d69 LK-03: Clamp the dropdown menu and the autocomplete list to the screen
# dda3ff9 LK-02: Add DragHandle level offset, ApplyLevel and ignoreParentAlpha
# 665bf63 LK-01: Make the tool windows toplevel and re-raise shown StaticPopups
# 8173cdb LK-10: Kit revision 42: binding mock, layer recorder, Bindings.xml check
# 0a1683a LK-00: Open v1.77.0 with an unreleased CHANGELOG section
# 9df6df8 Merge branch 'feat/2026-10-23-sim-preview-mode-strips'
git -C ../LibKa0s diff --stat v1.76.0 v1.77.0 -- LibKa0s testkit
# 18 files changed, 1672 insertions(+), 34 deletions(-)
```

## 3b. Actual version

```sh
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

40 constants, every one at its v1.76.0 value (3c's `old:` column). Claim and fact agree.

## 3c. Per-file minor delta

Files whose minor moved (the loop over the tag's `LibKa0s/LibKa0s.xml`; every other file is
unchanged):

| File | old | new |
|---|---|---|
| Core.lua | `LibKa0s-Core-1.0` 11 | 12 |
| Widgets.lua | `LibKa0s-Widgets-1.0` 14 | 15 |
| WidgetsDragHandle.lua | `DRAG_MINOR` 4 | 5 |
| WidgetsAutocomplete.lua | `AUTOCOMPLETE_MINOR` 2 | 3 |
| DebugLog.lua | `LibKa0s-DebugLog-1.0` 20 | 21 |
| Options.lua | `LibKa0s-Options-1.0` 29 | 30 |
| OptionsIds.lua | `IDS_MINOR` 2 | 3 |
| OptionsCombat.lua | `COMBAT_MINOR` 1 | 2 |
| OptionsCompose.lua | `COMPOSE_MINOR` 7 | 8 |
| OptionsKeybinds.lua | (new file) | `KEYBINDS_MINOR` 3 |
| PerfPanel.lua | `PANEL_MINOR` 8 | 9 |
| SimPanel.lua | `SIM_PANEL_MINOR` 5 | 6 |

No file is behind: no cross-major skew.

## 3d. Diffs

Before the copy the content diff shows only the v1.77.0 changes above and the
`Only in <scratch>/LibKa0s/media/icons` lines for the icons DpsRace does not declare. After the
copy and before the prune both content diffs are empty; the results are in `05_SUMMARY.md`.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

Consumed (14): Env (`core/EnvSetup.lua`), Media (`core/MediaSetup.lua`), Launcher
(`core/LauncherSetup.lua`), Compat (`core/Compat.lua`), Lifecycle (`core/LifecycleSetup.lua`), Core
(`core/CoreSetup.lua`), DebugLog (`core/DebugLogSetup.lua`), Bus (`core/Bus.lua`), Widgets
(`core/WidgetsSetup.lua`), Pool (`core/PoolSetup.lua`), Perf (`core/PerfSetup.lua`), Options
(`settings/OptionsSetup.lua`), Schema and Slash (`settings/Schema.lua`; Slash also
`settings/Slash.lua`). Unadopted majors in the payload: **Glow, Item, Sim**.

## 3f. Kit revision

```sh
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
# <scratch>/testkit/framework.lua:20:Kit.VERSION = 42
# tests/_kit/framework.lua:20:Kit.VERSION = 41
```

Revision 41 -> 42. Both payloads are copied whole in one commit, so the pairing rule (a consumer of
v1.9.0 or newer takes kit revision 11 or newer with it) holds by construction.

## 3g. Contract delta

Majors that moved and that DpsRace consumes: Core, Widgets, DebugLog, Perf (PerfPanel), Options.
Sim moved but is not consumed.

Read: the tag's `CHANGELOG.md` `## v1.77.0` block (`### What a consumer owes`) and
`docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md` (`### What a consumer owes`, and the
K2 and C8 paragraphs at its head), against the v1.76.0 document
`docs/api/Options/version-29.2.34.2.5.9.1.7.4.2.1-docs.md`.

`__Attach*` sites in the addon:

```sh
grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit   # (none)
```

DpsRace hands the library no member through an `__Attach*` seam, so no host-supplied member's call
site can have moved. The Core, DebugLog and PerfPanel changes (toplevel tool windows, the popup
re-raise), the Widgets clamps and the OptionsIds/OptionsCombat combat close of the suggestion list
take effect with the copy; the CHANGELOG states "What a consumer owes: nothing" for each.

### Blockers

1. **The Options degradation stub owes four new instance members**: `KeybindingsTab`,
   `KeybindRows`, `KEYBINDS_UNCHANGED` (OptionsKeybinds minor 2) and `StrataTooltip`
   (OptionsCompose minor 8). Source: the tag's `CHANGELOG.md` `## v1.77.0` -> `### What a
   consumer owes`; `docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md`, `### What a
   consumer owes` ("Every Options degradation stub gains `KeybindingsTab`, `KeybindRows` and
   `KEYBINDS_UNCHANGED`") and the C8 paragraph. `Kit.assertSurfaceParity` compares
   `settings/OptionsSetup.lua`'s library-absent stub against the live instance
   (`tests/run.lua` registers `shared.NS.Helpers` as the Options surface source), so
   `tests/test_surface_parity.lua` goes red at the copy. Fixed in the re-vendor commit: the stub
   gains the four names, hollow (`KeybindingsTab` and `KeybindRows` no-ops, `StrataTooltip`
   answering an empty string, `KEYBINDS_UNCHANGED` the library's sentence).

No other contract tightened.

## 3h. Tags vendored and never recorded

No store before this bundle, so no horizon and nothing to back-fill. No span bundle.

## 3i. The icon declaration

```sh
grep -n 'LibKa0s icons:' CLAUDE.md
# 42:LibKa0s icons: arrow-left, chart, chat, chevron-down, clear, close, confirm, copy, export, flag, info, lock, reset, settings, sort-down, sort-up, unlock.
```

The next non-blank line after the provenance line, which ends its own line: no split needed.
**Decided (kept as is).** The item spec pre-decides it ("keep the 'LibKa0s icons:' declaration").
v1.77.0 adds no library-drawn name: the tag's `docs/releasing.md` table under *Library-drawn icons
are the host's to declare* is still exactly `close`, `copy`, `clear` and `info`, all four already
declared. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`); the owner's in-client smoke is the backstop, because a pruned icon
still resolves to a path and draws blank.

## 3j. Tests that assume the whole icon folder

```sh
grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'   # (none)
```

None. No blocker of this class.

Dead stub mirrors:

```sh
grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit       # (none)
```
