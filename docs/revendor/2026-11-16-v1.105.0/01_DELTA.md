Delta: LibKa0s v1.93.0 -> v1.105.0

Recorded before anything was committed. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.105.0 LibKa0s testkit tools` (tag commit 79b1d9c, a local tag not yet on origin, which is expected for this run). Run under Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/`, item RV-DR, copy-and-bundle half of `/dev-copilot:wow-revendor-libka0s` (dev-copilot 2.10.0) only: no adoption interview and no GitHub filing (design section 5).

## Step 0 pre-flight
- Newest single-tag bundle `2026-11-07-v1.93.0` states base v1.92.0. The commit that rolled the line to v1.93.0 is d450e20, and its parent's provenance line names v1.92.0. ok.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` named v1.93.0 before the roll (CLAUDE.md:43).
- `git log -1 -- libs/LibKa0s tests/_kit` and its CLAUDE.md agree on v1.93.0.
- Payload before the copy equalled the library at v1.93.0: `diff -rq --strip-trailing-cr` of both payloads against a v1.93.0 extract printed nothing except the undeclared icons (payload-matches).
- Library range: `git -C ../LibKa0s log --oneline v1.93.0..v1.105.0` is 117 commits; `git diff --stat v1.93.0 v1.105.0` is 661 files changed. It spans the Callout, WaypointArrow, Role, the one-tab, footer and strip-dock work (v1.94.0 to v1.104.0) and this run's v1.105.0 (Tooltip major, header buttons, W.Bar, launcher extras, D:Report, console footer, Sim samples, #82/#84 skin contrast, kit 57).

## 3b/3c Per-file minors that moved (old = this addon, new = v1.105.0)
```
Core.lua  old: 17  new: 18
Tooltip.lua  old: none  new: 1
Compat.lua  old: 3  new: 4
Role.lua  old: none  new: 1
Callout.lua  old: none  new: 4
CalloutSettings.lua  old: none  new: 5
WaypointArrow.lua  old: none  new: 2
WaypointArrowSettings.lua  old: none  new: 2
Charts.lua  old: 1  new: 2
Media.lua  old: 12  new: 13
Skin.lua  old: 17  new: 18
SkinDefs.lua  old: 27  new: 28
SkinDefsOthers.lua  old: 8  new: 10
Widgets.lua  old: 26  new: 27
WidgetsDropdown.lua  old: 1  new: 2
WidgetsReorder.lua  old: 6  new: 7
WidgetsDragHandle.lua  old: 13  new: 14
WidgetsDragHandleTip.lua  old: none  new: 1
WidgetsCopyWindow.lua  old: 5  new: 6
WidgetsHeader.lua  old: none  new: 1
WidgetsBar.lua  old: none  new: 1
DebugLog.lua  old: 22  new: 23
DebugLogDiagnostics.lua  old: 7  new: 11
DebugLogWindow.lua  old: 4  new: 5
Launcher.lua  old: 9  new: 11
OptionsWidgets.lua  old: 45  new: 46
OptionsNav.lua  old: 6  new: 7
OptionsSkinPicker.lua  old: 11  new: 12
OptionsSkinPickerQueue.lua  old: none  new: 1
IconBrowserWindow.lua  old: 1  new: 2
IconBrowser.lua  old: 1  new: 2
PerfPanel.lua  old: 13  new: 14
Sim.lua  old: 2  new: 3
SimPanel.lua  old: 10  new: 11
SimPanelRender.lua  old: 3  new: 4
```
Every file not listed matched v1.93.0 before the copy, so there is no cross-major skew.

## 3d Diffs
After the copy and before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against the v1.105.0 extract printed nothing. After the prune the only differences are the undeclared icons and the voice packs (`Only in <extract>/LibKa0s/media/icons|sounds`); `tests/test_vendor_sync.lua` is green.

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' core modules settings`: 23 sites, the same as at v1.93.0 (core/Compat.lua's lookup now reads at line 28). Majors in the payload with no lookup in this addon: LibKa0s-Callout-1.0 LibKa0s-Glow-1.0 LibKa0s-IconBrowser-1.0 LibKa0s-Item-1.0 LibKa0s-Role-1.0 LibKa0s-Tooltip-1.0 LibKa0s-WaypointArrow-1.0.

## 3f Kit revision
```
old: tests/_kit/framework.lua:20:Kit.VERSION = 53
new: testkit/framework.lua:20:Kit.VERSION = 57
```
Kit revision 57 pairs with v1.105.0, and both payloads are copied whole in one commit.

## 3g Contract delta and Blockers
Read against the v1.105.0 `CHANGELOG.md` *What a consumer owes* list, intersected with the majors this addon looks up.
- `__Attach*` sites in this addon: none.
- Options instance `SideTabs` (OptionsNav minor 7, since v1.100.0): this addon's library-absent Options stub (settings/OptionsSetup.lua) is checked by name (`tests/test_surface_parity.lua`), so it went red: "SideTabs is missing (live: function)". Fixed in this commit with one no-op name in the stub's list.
- DebugLog `Report`/`Serialize` (#79): this addon's DebugLog parity case checks the members it calls, not by name; green, no stub edit.
- Sim library table `SAMPLE`/`Sample`, Widgets table `HeaderButtons`/`W.Bar` family, Compat minor 4: the parity cases here are reached-member; green, no stub edit.
- Loader list: tests/run.lua derives its library list from `LibKa0s.xml`, so the five new payload files load without a host line.
- Kit 57 frame hold: the full suite is green; no suite relied on a collected frame.
- `LIBRARY_MARKS` gains `settings`: the declaration already lists `settings`.
- Launcher name vs window `addonName` (R9 C8): core/LauncherSetup.lua:88 `name = addonName`, core/DebugLogSetup.lua:60 and core/PerfSetup.lua:24 `addonName = addonName`, so the library windows' settings mark finds this addon's settings.
- Pinned minors: no suite here pins a moved minor.

**Blockers: none** beyond the SideTabs stub member above.

## 3h Unrecorded vendored tags
```
(empty)
```
No span bundle is owed.

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: CLAUDE.md:44, directly under the provenance line. Kept as written (it already carries `settings`).

## 3j Tests that assume the whole icon folder
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: none.

## Dead stub mirrors
`grep -rn '__releaseChrome'` outside libs and the kit: none.
