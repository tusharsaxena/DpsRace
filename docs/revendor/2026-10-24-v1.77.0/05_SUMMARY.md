# DpsRace: LibKa0s re-vendor summary

- **Tag:** v1.76.0 -> **v1.77.0** (local annotated tag, run branch of LibKa0s). Base taken from the
  `CLAUDE.md` provenance line (v1.76.0), confirmed by the last payload commit `39bb2b6`.
- **Per-file minors:** Core 11 -> 12, Widgets 14 -> 15, WidgetsDragHandle 4 -> 5,
  WidgetsAutocomplete 2 -> 3, DebugLog 20 -> 21, Options 29 -> 30, OptionsIds 2 -> 3, OptionsCombat
  1 -> 2, OptionsCompose 7 -> 8, OptionsKeybinds new at 3, PerfPanel 8 -> 9, SimPanel 5 -> 6. Kit
  revision 41 -> 42 (new `bindings_xml.lua`, `mock_bindings.lua`, `mock_layers.lua`).
- **Span bundle:** none (this is the store's first bundle). **Base correction:** none.
- **Delivered for free (class A):** toplevel debug console and perf panel with the StaticPopup
  re-raise; clamped dropdown menu and autocomplete list; the IdList suggestion list's combat close;
  the Keybindings tab's sync with Options -> Keybindings (reaches DpsRace once DR-KB adds the tab).
- **Contract blocker (3g):** the Options degradation stub owed `KeybindingsTab`, `KeybindRows`,
  `KEYBINDS_UNCHANGED` and `StrataTooltip` (CHANGELOG `## v1.77.0` -> `### What a consumer owes`;
  `docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md` -> `### What a consumer owes`).
  After the copy `test_surface_parity` failed ("the degraded stub diverges from the live surface in
  4 place(s)"). Resolved in the re-vendor commit: `settings/OptionsSetup.lua`'s stub gains the four,
  hollow.
- **Icons:** `LibKa0s icons:` line kept unchanged (17 names, all Open Iconic). Prune
  (`lua <scratch>/tools/prune-icons.lua .`): "17 icon(s) declared; kept 18 file(s), removed 5822",
  every removed file a catalog arrival the copy brought in and the addon does not declare (Open
  Iconic, Phosphor and Game-icons alike); no tracked icon removed. No provenance split.
- **README credits:** unchanged. Only Open Iconic ships, and its credit line is already there.
- **Dead stub mirrors:** none (`__releaseChrome` absent).
- **Refresh file:** none.
- **Adopted here:** nothing. B1 and B2 go to DR-KB; B3 to B5 to DR-ZS.
- **Deferred (run 2026-10-24), nothing filed:** B6 `Core.RaiseStaticPopups` in a host window; C1
  Glow, C2 Item, C3 Sim.
- **Diffs:** after the copy, before the prune, both content diffs and both byte diffs were empty
  (`diff -r [--strip-trailing-cr] <scratch>/LibKa0s libs/LibKa0s`, same for `testkit` and
  `tests/_kit`). After the prune the only lines are `Only in <scratch>/LibKa0s/media/icons...`.
- **Gates:** `ka0s-bounded lua tests/run.lua` after the copy: 467 passed, 1 failed (the parity
  blocker above), 1 skipped; after the stub fix: 468 passed, 0 failed, 1 skipped, 469 total.
  `ka0s-bounded luacheck .`: 0 warnings / 0 errors in 81 files. Largest authored `.lua` file:
  `tests/test_hud.lua`, 1109 lines (cap 1500). `tests/run.lua --list` leaves `docs/test-cases.md`
  unchanged.

## Re-vendor after the tag moved (M3)

- **Tag moved (LK-95, local, not pushed):** v1.77.0 was commit
  `78240f7b2d69df27b74fc9280cbfbf7b95dd4f1f` (tag object `7380d3662be0568acf9a0d224a6aef8ac6df93ce`)
  and is now commit `afae2f75cb7ff61c57156d9a3d8a6b2b9f4c5e10` (tag object
  `b2b8ee25c5f9fa26db146254bf786b366dec986b`). `git -C ../LibKa0s rev-parse v1.77.0^{}` prints the new
  commit.
- **Per-file minors that moved:** OptionsCompose 8 -> 11 (minor 9 Master controls notes, the preview
  lock and *Master opacity*; minor 10 tooltips beside labels on the group composers; minor 11
  `O.ResetAllTooltip`). Every other file in `libs/LibKa0s/` is byte-identical between the two
  commits (`git -C ../LibKa0s diff --stat 78240f7 afae2f7 -- LibKa0s testkit` names only
  `LibKa0s/OptionsCompose.lua`). Kit revision unchanged at 42; `tests/_kit/` took no change.
- **Copy:** `libs/LibKa0s/` and `tests/_kit/` copied whole from `git -C ../LibKa0s archive v1.77.0
  LibKa0s testkit tools`. Both content diffs (`diff -r --strip-trailing-cr`) empty before the prune.
  The provenance line stays `v1.77.0` (it records no sha or kit revision), and the `LibKa0s icons:`
  line is kept unchanged.
- **Icons:** `lua <scratch>/tools/prune-icons.lua .`: "17 icon(s) declared; kept 18 file(s), removed
  5822", every removed file a catalog arrival of the copy; no tracked icon removed.
- **Contract blocker:** `test_surface_parity` failed after the copy ("the degraded stub diverges from
  the live surface in 1 place(s) — ResetAllTooltip is missing (live: function)"). Resolved in the
  same commit: `settings/OptionsSetup.lua`'s Options degradation stub gains `ResetAllTooltip`,
  inert (returns "").
- **Adopted here:** nothing. DR-LY adopts the layout surfaces.
- **Standards half:** nothing. The addon's three-place standards reference is URL-only and names no
  version, so the v2.88.0 close (WS-95) leaves no drift.
- **Gates:** `ka0s-bounded lua tests/run.lua` after the copy: 480 passed, 1 failed (the parity blocker
  above), 1 skipped; after the stub fix: 481 passed, 0 failed, 1 skipped, 482 total.
  `ka0s-bounded luacheck .`: 0 warnings / 0 errors in 83 files. Largest authored `.lua` file:
  `tests/test_hud.lua`, 1109 lines (cap 1500).

## Re-vendor after the tag moved again (one key button)

- **Tag moved (LK-96, local, not pushed):** v1.77.0 was commit
  `afae2f75cb7ff61c57156d9a3d8a6b2b9f4c5e10` (tag object `b2b8ee25c5f9fa26db146254bf786b366dec986b`)
  and is now commit `2f2b2e22b4c9219cd8a4101d7e894681c7aea16e` (tag object
  `e9b126d961c2970e5b14d0566480f7c1d8b5e5e8`), the owner's one-key-button follow-up to 015.
- **Per-file minors that moved:** OptionsKeybinds 3 -> 4 (one key button and Clear per row: the
  button binds and right-click clears slot 1, reads "<first key> +N" when the action holds more, and
  its tooltip names every key; the second slot widget and the KEY1 / KEY2 words are gone, KEY,
  KEY_MORE, KEYS_ALL and KEYS_OTHER are new). Every other file in `libs/LibKa0s/` is byte-identical
  (`git -C ../LibKa0s diff --stat afae2f7 2f2b2e2 -- LibKa0s testkit tools` names
  `LibKa0s/OptionsKeybinds.lua`, `testkit/README.md` and `testkit/bindings_xml.lua`). Kit revision
  unchanged at 42; `tests/_kit/bindings_xml.lua`'s `Kit.keybindThroughTab` now drives slot 2 on a
  one-button row as the client's page sets it.
- **Copy:** `libs/LibKa0s/` and `tests/_kit/` copied whole from `git -C ../LibKa0s archive v1.77.0
  LibKa0s testkit tools`. Both content diffs (`diff -r --strip-trailing-cr`) empty before the prune.
  The provenance line stays `v1.77.0`, and the `LibKa0s icons:` line is kept unchanged.
- **Icons:** `lua <scratch>/tools/prune-icons.lua .` removed every catalog arrival of the copy and
  kept the 17 declared icons (18 files); no tracked icon removed.
- **Contract blocker:** none. `test_surface_parity` stayed green after the copy (minor 4 adds no
  public Options member), so the degradation stub is unchanged.
- **Docs:** `docs/settings-panel.md`'s Keybindings tab and the smoke rows SM-DR-KB2 and SM-DR-KB3
  describe the one key button and Clear; SM-DR-RV3 is new; all three are listed under *Pending
  sign-off*. The addon's tests drove slot 1 only, so none changed.
- **Gates:** `ka0s-bounded lua tests/run.lua`: 489 passed, 0 failed, 1 skipped, 490 total (README
  badge and `docs/test-cases.md` unchanged at 489). `ka0s-bounded luacheck .`: 0 warnings / 0 errors
  in 82 files. Largest authored `.lua` file: `tests/test_hud.lua`, 1109 lines (cap 1500).
