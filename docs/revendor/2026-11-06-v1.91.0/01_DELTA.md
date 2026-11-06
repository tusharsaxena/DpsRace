Delta: LibKa0s v1.90.0 -> v1.91.0

Item `FU-RV-DR` of Ka0sAddonsCommonTasks `docs/2026-11-06-FOLLOWUPS_V1_91/00_PLAN.md`. The payload
comes from the tag (`git -C ../LibKa0s archive v1.91.0 LibKa0s testkit tools`, extracted into a scratch
directory; tag commit `55bfbb4`). The tag is **local**: `ls-remote` shows nothing, which is expected for
this run, and this is a new tag, not a refresh. Written before the copy.

## Step 0

Skipped as a roster-wide table. The installed skill's roster regex (`\]\(\.\./\.\./…/\)`) expects
markdown links, while `ADDONS.md` writes `` `../../<Folder>/` ``, so it matches nothing; this run fixes
it upstream (FU-DC1). For this addon alone: the newest single-tag bundle, `2026-11-06-v1.90.0`, states
base v1.89.0, and the provenance before the re-vendor commit `5a7f8f8` was v1.89.0 (`ok`). No base
correction to record.

## 3a. Claimed version, and the base

```
$ grep -n '[Bb]undles' CLAUDE.md
43:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.90.0 (MIT).
$ c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit); git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.90.0        # c = bb63c8d
```

The two agree: the base is **v1.90.0**.

```
$ git -C ../LibKa0s log --oneline v1.90.0..v1.91.0
55bfbb4 FU-L3: Release v1.91.0 adds the release run's record and its notes
1938837 FU-L3: Release v1.91.0 moves every version line to the tag and records the consumer sweep
3f7be30 FU-L2: Peel the toast stack cases out of test_toast.lua into test_toast_stack.lua
acc9640 FU-L2: Peel the confirmation box and the HUD looks out of SkinPaintExtras.lua
c1ed261 FU-L2: Peel the dropdown and its shared menu out of Widgets.lua into WidgetsDropdown.lua
d72dc4a FU-L2: Peel the pixel edges section out of Core.lua into CorePixel.lua
55d3b0f FU-L1: The line chart's axis, grid, markers, crosshair and series are physical pixels at any UI scale
f4be157 Merge feat/2026-11-06-revendor-libka0s-v1-89: ...
06d97b0 V89-FIN: Sync docs to the v1.90.0 re-vendor run
$ git -C ../LibKa0s diff --stat v1.90.0 v1.91.0 | tail -1
 62 files changed, 30753 insertions(+), 1835 deletions(-)
```

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` before the copy
shows the v1.90.0 minors (Core 16, Widgets 25, SkinPaintExtras 18, WidgetsLineChart 6, ...), which is
what the line claims. Line and bytes agree.

## 3c. Per-file minor delta (files from the tag's `LibKa0s.xml`)

Every file not listed is unchanged. An empty `old` is a file new in this range.

| File | old | new |
|---|---|---|
| `Core.lua` | `LibKa0s-Core-1.0`, 16 | 17 |
| `CorePixel.lua` | (new) | `PIXEL_MINOR` 1 |
| `SkinPaintExtras.lua` | `EXTRAS_MINOR` 18 | 19 |
| `SkinPaintHud.lua` | (new) | `HUD_MINOR` 1 |
| `SkinAceConfirm.lua` | (new) | `CONFIRM_MINOR` 1 |
| `Widgets.lua` | `LibKa0s-Widgets-1.0`, 25 | 26 |
| `WidgetsDropdown.lua` | (new) | `DROPDOWN_MINOR` 1 |
| `WidgetsLineChart.lua` | `CHART_MINOR` 6 | 7 |

No file in this addon is ahead of the tag and none is behind after the copy: no cross-major skew.

## 3d. Both diffs (before the copy)

```
$ diff -rq --strip-trailing-cr <x>/LibKa0s libs/LibKa0s | grep -v 'media/icons'
Files .../Core.lua differ
Only in <x>/LibKa0s: CorePixel.lua
Files .../LibKa0s.xml differ
Only in <x>/LibKa0s: SkinAceConfirm.lua
Files .../SkinPaintExtras.lua differ
Only in <x>/LibKa0s: SkinPaintHud.lua
Files .../Widgets.lua differ
Only in <x>/LibKa0s: WidgetsDropdown.lua
Files .../WidgetsLineChart.lua differ
$ diff -rq --strip-trailing-cr <x>/testkit tests/_kit
(nothing)
```

The byte diffs (no `--strip-trailing-cr`) print the same lines: no line-ending drift. Under `media/icons`
the only lines are `Only in <x>/LibKa0s/media/icons…`, the icons this addon does not declare. No
`Only in libs/LibKa0s` line: nothing was removed upstream.

## 3e. Consumption map

The moved majors this addon looks up: Core (`core/CoreSetup.lua:16`, `modules/Hud_Appearance.lua:180`),
Skin (`core/Database.lua:45,96`, `core/SkinSetup.lua:77`, `modules/Style.lua:300`), Widgets
(`core/WidgetsSetup.lua:22`). The other lookups are unchanged from the v1.90.0 bundle.
`LibKa0s-IconBrowser-1.0` still has no lookup (settled at v1.89.0: no chooser). DpsRace draws no
`W.LineChart`: its HUD chart is its own (`modules/Hud_Chart.lua`), and Insights uses the Charts major.

## 3f. Kit revision

```
$ grep -n 'Kit.VERSION' <x>/testkit/framework.lua tests/_kit/framework.lua
<x>/testkit/framework.lua:20:Kit.VERSION = 51
tests/_kit/framework.lua:20:Kit.VERSION = 51
```

Kit revision 51 on both sides; the payloads still move together in one commit (pairing rule).

## 3g. Contract delta

Read the tag's `CHANGELOG.md` v1.91.0 block and the three superseded documents' *Superseded by* rows
(`docs/api/Core/version-16-docs.md`, `docs/api/Widgets/version-25.6.13.6.8.5-docs.md`,
`docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md`). Core 17 / CorePixel 1, Widgets 26 /
WidgetsDropdown 1, and SkinPaintExtras 19 / SkinPaintHud 1 / SkinAceConfirm 1 are pure moves: "No member,
option or behavior changes", "No `NEEDS_*` floor rises", "No host owes a facade or stub member".
WidgetsLineChart 7 reads a host's `series[i].thickness` as physical pixels; DpsRace passes none (it draws
no `W.LineChart`).

```
$ grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit
(nothing)
```

### Blockers

- **The library file floor in `tests/run.lua`** (`EXPECTED`, lines 21-36). The loader itself is derived
  from `LibKa0s.xml` (`Loader.xmlFiles`, line 19), so the new files load with no edit, but the floor list
  names the library files this addon consumes, and the members it uses moved: `W.Dropdown`,
  `W.ContextMenu` and `W.CloseMenu` (`core/WidgetsSetup.lua:31,102,147`) to `WidgetsDropdown.lua`;
  `S.BarGloss` and `S.HudFont` (`core/SkinSetup.lua:579`) to `SkinPaintHud.lua`; the pixel edges to
  `CorePixel.lua`; the profile confirmation box to `SkinAceConfirm.lua`. The LibKa0s release names this
  fix (CHANGELOG v1.91.0, *The release*: "a host test loader or file list that names library files adds
  the four new ones"). Fixed in the re-vendor commit: the four names join the floor beside the files they
  were peeled from, in the tag's `LibKa0s.xml` order.
- **Minor pins:** none. No test in this addon pins a LibKa0s minor.
- **Stub mirrors:** none. No host stub mirrors a moved member (the peels move code between files of one
  major; no member is added or removed).

## 3h. Span bundle

The listing (vendored since the store's horizon, 2026-10-24, minus recorded) printed nothing: no span
bundle. The `tag_at` helper was run with a named variable (`rev="$1"`), since the installed skill text
shows the substituted `"Ka0s"`/`"repos:"` (fixed upstream in FU-DC1).

## 3i. Icon declaration

`CLAUDE.md:44`, directly under the provenance line, kept unchanged (29 names). No new library-drawn name
in this range. No provenance split needed.

## 3j. Tests assuming the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` prints nothing.
No dead stub mirror (`__releaseChrome`: no match).
