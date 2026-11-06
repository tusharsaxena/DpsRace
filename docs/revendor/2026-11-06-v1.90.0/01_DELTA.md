Delta: LibKa0s v1.89.0 -> v1.90.0

Item `SF1-RV-DR` of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/SF1_SMOKE_FEEDBACK.md`.
The payload comes from the tag (`git -C ../LibKa0s archive v1.90.0 LibKa0s testkit tools`, extracted into a
scratch directory; tag commit `4485b8f`). The tag is **local**: `ls-remote` shows nothing, which is
expected for this run, and this is a new tag, not a refresh. Written before the copy.

## 3a. Claimed version, and the base

```
$ grep -n '[Bb]undles' CLAUDE.md
43:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.89.0 (MIT).
$ c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit); git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.89.0        # c = f382ddc
$ git log --format='%h %s' "$c..HEAD" -- CLAUDE.md
(nothing)
```

The two agree: the base is **v1.89.0**. Step 0 for this addon: the newest single-tag bundle,
`2026-11-06-v1.89.0`, states base v1.85.0, and the provenance before `f382ddc` was v1.85.0 (`ok`), so there
is no base correction to record.

```
$ git -C ../LibKa0s log --oneline v1.89.0..v1.90.0
4485b8f SF1-L3: Release v1.90.0 adds the release run's record and its notes
4ac9f3c SF1-L3: Release v1.90.0 moves every version line to the tag and records the consumer sweep
b9f7651 SF1-L2: RegisterOwner's keepScope, a Scope another addon's skin copy never writes
7d42f4e SF1-L1: Every Widgets edge is one physical pixel at any UI scale, with no skin and under every skin
e809ca3 Merge feat/2026-11-06-harvest-standards: ...
72733ee SYNC-DOCS: Name the IconBrowser major everywhere the docs list majors, ...
1ca12c6 LK-K3: Merge feat/2026-11-05-kit-unregister-guard (LibKa0s v1.89.0, kit revision 51)
$ git -C ../LibKa0s diff --stat v1.89.0 v1.90.0 | tail -1
 37 files changed, 35494 insertions(+), 94 deletions(-)
```

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` before the copy
shows the v1.89.0 minors (Core 15, Skin 16, Widgets 23, ...), which is what the line claims. Line and bytes
agree.

## 3c. Per-file minor delta (files from the tag's `LibKa0s.xml`)

Every file not listed is unchanged.

| File | old | new |
|---|---|---|
| `Core.lua` | `LibKa0s-Core-1.0`, 15 | 16 |
| `Skin.lua` | `LibKa0s-Skin-1.0`, 16 | 17 |
| `SkinPaint.lua` | `PAINT_MINOR` 18 | 19 |
| `SkinPaintExtras.lua` | `EXTRAS_MINOR` 17 | 18 |
| `Widgets.lua` | `LibKa0s-Widgets-1.0`, 23 | 24 |
| `WidgetsAutocomplete.lua` | `AUTOCOMPLETE_MINOR` 7 | 8 |
| `OptionsAppearance.lua` | `APPEARANCE_MINOR` 6 | 7 |

No file in this addon is ahead of the tag and none is behind after the copy: no cross-major skew.

## 3d. Both diffs (before the copy)

```
$ diff -rq --strip-trailing-cr <x>/LibKa0s libs/LibKa0s | grep -v 'Only in <x>/LibKa0s/media/icons'
Files .../Core.lua differ
Files .../OptionsAppearance.lua differ
Files .../Skin.lua differ
Files .../SkinPaint.lua differ
Files .../SkinPaintExtras.lua differ
Files .../Widgets.lua differ
Files .../WidgetsAutocomplete.lua differ
$ diff -rq --strip-trailing-cr <x>/testkit tests/_kit
(nothing)
```

The byte diffs (no `--strip-trailing-cr`) print the same lines: no line-ending drift. Under `media/icons`
the only lines are `Only in <x>/LibKa0s/media/icons…`, the icons this addon does not declare. No
`Only in libs/LibKa0s` line: nothing was removed upstream.

## 3e. Consumption map

The moved majors this addon looks up: Core (`core/CoreSetup.lua:16`, `modules/Hud_Appearance.lua:180`),
Skin (`core/Database.lua:45,96`, `core/SkinSetup.lua:77`, `modules/Style.lua:300`), Widgets
(`core/WidgetsSetup.lua:22`), Options (`settings/OptionsSetup.lua:13`). The other lookups are unchanged
from the v1.89.0 bundle. `LibKa0s-IconBrowser-1.0` still has no lookup (settled at v1.89.0: no chooser).

## 3f. Kit revision

```
$ grep -n 'Kit.VERSION *=' <x>/testkit/framework.lua tests/_kit/framework.lua
<x>/testkit/framework.lua:20:Kit.VERSION = 51
tests/_kit/framework.lua:20:Kit.VERSION = 51
```

Kit revision 51 on both sides; the payloads still move together in one commit (pairing rule).

## 3g. Contract delta

Read the tag's `CHANGELOG.md` v1.90.0 block. Core 16 adds internal `__PixelSize`, `__WatchPixels`,
`__OnPixelScale` and `__PixelBackdrop` (no member manifest moves). Widgets 24 / Autocomplete 8 give the
dropdown, search box, shared menu and autocomplete list a pixel-exact backdrop (no member or option moves).
Skin 17 adds the optional `RegisterOwner(owner, { keepScope = true })` opt-out; "No member moves, so a
host's Skin facade owes nothing". OptionsAppearance 7 makes `lib.__copySkinTo` honour it. The release
block says "No host owes a facade or stub member" and no `NEEDS_*` floor rises.

```
$ grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit
(nothing)
```

### Blockers

None found before the copy. The gate after the copy is the check (`tests/test_surface_parity.lua` and
the stubs); anything it turns red is fixed in this commit and recorded in `05_SUMMARY.md`.

## 3h. Span bundle

The listing (vendored since the store's horizon, minus recorded) printed nothing: no span bundle.

## 3i. Icon declaration

`CLAUDE.md:44`, directly under the provenance line, kept unchanged (29 names). No new library-drawn name
in this range. No provenance split needed.

## 3j. Tests assuming the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` prints nothing.
No dead stub mirror (`__releaseChrome`: no match).
