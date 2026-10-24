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
