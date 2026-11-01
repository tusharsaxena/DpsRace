Delta: LibKa0s v1.84.0 -> v1.85.0

Part of Ka0sAddonsCommonTasks `docs/2026-11-01-FULL_SKINNING/` (FS-DR-RV). The tag is local, cut by that run's `FS-REL` (`git -C ../LibKa0s rev-parse v1.85.0` answers the tag object 09a835c).

## Base (3a, 3b)

`grep -n '[Bb]undles' CLAUDE.md` names v1.84.0, and so does the line at `git log -1 --format=%H -- libs/LibKa0s tests/_kit` (`cd2c3f8`). No disagreement.

Newest single-tag bundle `2026-10-31-v1.84.0` states the base the history shows. No correction owed. Step 0 was run for this addon only, by hand: the skill's Step 0 mangles its args (lead's note).

## Per-file minors (3c), moved files only

`for f in LibKa0s.xml's files: grep the [A-Z_]*MINOR constant, old against tag`

| File | old | new |
|---|---|---|
| Glow.lua | 1 | 2 |
| Toast.lua | 1 | 2 |
| Skin.lua | 11 | 14 |
| SkinDefs.lua | 19 | 24 |
| SkinDefsOthers.lua | 1 | 6 |
| SkinPaint.lua | 13 | 16 |
| SkinPaintExtras.lua | 7 | 15 |
| SkinPaintControls.lua | 11 | 14 |
| SkinEUI.lua | 2 | 3 |
| SkinAce.lua | 6 | 9 |
| Widgets.lua | 17 | 20 |
| WidgetsReorder.lua | 3 | 5 |
| WidgetsDragHandle.lua | 10 | 12 |
| WidgetsLineChart.lua | 5 | 6 |
| WidgetsAutocomplete.lua | 5 | 6 |
| WidgetsCopyWindow.lua | 2 | 4 |
| DebugLogWindow.lua | 2 | 3 |
| Launcher.lua | 5 | 6 |
| OptionsWidgets.lua | 41 | 44 |
| OptionsIds.lua | 6 | 7 |
| OptionsIdList.lua | 7 | 8 |
| OptionsTabs.lua | 13 | 15 |
| OptionsCompose.lua | 16 | 17 |
| OptionsScroll.lua | 10 | 13 |
| OptionsNav.lua | 4 | 5 |
| OptionsDrawer.lua | 4 | 5 |
| OptionsKeybinds.lua | 6 | 7 |
| OptionsAppearance.lua | 5 | 6 |
| OptionsSkinPicker.lua | 5 | 7 |
| OptionsMedia.lua | 3 | 4 |
| PerfPanel.lua | 11 | 12 |
| SimPanel.lua | 9 | 10 |
| SimPanelRender.lua | 1 | 2 |

No consumer file was behind on a file the tag holds at a lower minor. No new file, no file removed.

## Diffs (3d)

`diff -r --strip-trailing-cr` of both payloads against `git archive v1.85.0`: empty after the copy, before the prune. Only the undeclared icons differ after it.

## Kit (3f)

`grep -n 'Kit.VERSION'`: 47 -> 49, carried in the same commit.

## Contract delta (3g): Blockers

- `docs/releasing.md`, *Step 8 for v1.85.0*: the Options stub owes `LabelFont` and the Skin facade `Mark`, `MarkText`, `HudTextColor`, `HudLabelColor`, `BarFillColor`, `HudShadow`, `BarGloss` and `HudFont`. Fixed in this commit, in `settings/OptionsSetup.lua` and `core/SkinSetup.lua`. `HudFont` is the one that draws (Options doc, *Moving to*, section 7), with a case in `tests/test_skinsetup.lua`.
- Kit revision 49's vendor gate: the `LibKa0s icons:` line owes `chevron-up`, `move` and `volume-high`. The other five names on the owed list were already declared. This run's bundle pre-decides the line, so it is recorded here and not asked.

`grep -rn '__Attach[A-Za-z]*'` outside `libs/` finds no host member. `grep -rn '__releaseChrome'` finds no mirror.

## Unrecorded tags (3h)

None. Every vendored tag has a bundle. No span bundle.

## Tests assuming the whole icon folder (3j)

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests` outside `_kit/`: nothing. `tests/test_skeleton.lua`'s list names declared icons only.
