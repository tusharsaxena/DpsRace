# Candidates, v1.85.0 -> v1.89.0

Sources: `git -C ../LibKa0s log --oneline v1.85.0..v1.89.0`, the tag's `CHANGELOG.md` blocks v1.86.0 to
v1.89.0, and the `docs/api/` documents of every major whose minor moved (Toast 3 -> 4, Widgets
22.5.12.6.7.5 -> 23.5.12.6.7.5, DebugLog 22.6.1.4 -> 22.7.1.4, IconBrowser new at 1). The Toast stub is a
blocker (`01_DELTA.md`, 3g), fixed in the re-vendor commit, and is not offered here.

## A. Delivered on the copy

- **Kit revision 51** (`CHANGELOG.md`, v1.89.0 block): `mock_ace.lua`'s CallbackHandler registry clears a
  target's entry only where one exists, so an `Unregister*` of an unregistered target during a dispatch
  no longer raises `invalid key to 'next'` or skips a registrant. Reaches every suite here unchanged.
- **DebugLogDiagnostics 7** (`docs/api/DebugLog/version-22.7.1.4-docs.md`, *What changed at this
  version*): the report's `LibKa0s running:` line names IconBrowser when that major runs in the client.
  DpsRace's `/dpsr debug` report gains the name when another addon loads the browser. No suite here pins
  the minor.
- **Toast 4 for a one-at-a-time host** (`docs/api/Toast/version-4-docs.md`, *What changed at this
  version*): without `stack` the toast is the version 3 toast, every member answering what it answered.
- **Widgets 23 for flat menus** (`docs/api/Widgets/version-23.5.12.6.7.5-docs.md`, *What changed at this
  version*): every single-level menu is unchanged; `W.CloseMenu()` now closes every cascade level, which
  `NS.CloseMenu` reaches with no change.

## B. Host change required

1. **Widgets 23 `submenu` rows for `NS.OpenMenu`.** `core/WidgetsSetup.lua:38-104` records a MenuUtil
   `fill` and draws it one level at a time: a button with a nested level reopens the one shared menu with
   the child's rows (`showLevel`), and the parent vanishes; it hand-draws `chevron-right` after the
   label. Version 23 (`version-23.5.12.6.7.5-docs.md`, the `submenu` row and "What a consumer owes: ... A
   host that faked a submenu by reopening the menu passes the whole tree as `submenu` rows instead")
   names exactly this shape. Callers with nested levels: `modules/Results.lua:772-786` (Share, Ignore for
   late casts). Touches `core/WidgetsSetup.lua`, possibly the `LibKa0s icons:` line (`chevron-right`, if
   nothing else draws it). Replaces code the addon owns (blast radius: replace, inside one seam file; the
   no-library MenuUtil path is unchanged). **Recommend adopt.**
2. **Toast 4 stack** (`stack`, `stackGrow`, `stackGap`, `SetStack`). `modules/BestToast.lua` shows one
   personal-best toast at a time. The library's own CHANGELOG v1.88.0 block and the version 4 document
   say "DpsRace's personal-best toast stays one at a time". **Settled**, not offered.

Considered and not a candidate: Widgets 23 `radio` / `selected` / `opts.check` on DpsRace's menus. Its
rows are actions, not states: LateIgnore's entries are labelled *Ignore X* / *Unignore X*
(`modules/LateIgnore.lua:283-316`), Share's are channels, the row menu's are verbs. No row represents a
current selection a tick would show.

## C. Whole-module adoption

- **`LibKa0s-IconBrowser-1.0`** (new major, v1.86.0, `docs/api/IconBrowser/`): a browsable icon chooser for
  a host whose player picks icons. DpsRace has no icon chooser; its art is fixed by the addon. **Settled**
  (run plan, owner ruling: recorded in each bundle, no issue).
