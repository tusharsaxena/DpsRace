# DpsRace: adoption candidates from LibKa0s v1.76.0 -> v1.77.0

Sources: `git -C ../LibKa0s log --oneline v1.76.0..v1.77.0`, the tag's `CHANGELOG.md` `## v1.77.0`
block, and the `Since` markers of the moved majors' documents at the tag
(`docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md`,
`docs/api/Widgets/version-15.1.5.3.3-docs.md`, `docs/api/testkit/version-42-docs.md`). The 3g
blocker (the Options stub's four members) is not a candidate; it is fixed in the re-vendor commit.

## A. Delivered on the re-vendor alone (not offered)

| Change | Evidence | What DpsRace gets |
|---|---|---|
| Debug console and perf panel are toplevel; a shown StaticPopup is re-raised on their `OnShow` (Core 12, DebugLog 21, PerfPanel 9) | CHANGELOG `### Core minor 12, DebugLog minor 21, PerfPanel minor 9 and SimPanel minor 6` | `/dr debug` console and `/dr perf` panel rise over the Settings panel on click, and never bury a *Reset all settings* confirmation |
| Dropdown menu and autocomplete list clamped to screen (Widgets 15, WidgetsAutocomplete 3) | CHANGELOG `### Widgets minor 15 and WidgetsAutocomplete minor 3` | every `lib.Dropdown` menu stays on screen |
| IdList suggestion list closes at combat start (OptionsIds 3, OptionsCombat 2) | Options doc, I3 and OC2 paragraph | DpsRace draws no id input; no visible effect |
| The Keybindings tab follows Options -> Keybindings (OptionsKeybinds 3) | Options doc, K3 paragraph | reaches the tab once DR-KB adds it |

## B. Host change required (candidates)

| # | Candidate | Evidence | Files it would touch | Blast radius | Recommendation |
|---|---|---|---|---|---|
| B1 | `O.KeybindingsTab(spec)` / `O.KeybindRows` / `O.KEYBINDS_UNCHANGED`: the General > Keybindings tab | Options doc, K2 paragraph and `### What a consumer owes`; CHANGELOG `### OptionsKeybinds minor 2` | `Bindings.xml`, `settings/General.lua`, the module that declares `NS.BINDINGS`, locales, tests | additive | adopt, as the run's item **DR-KB** |
| B2 | Kit revision 42: `mock_bindings.lua`, `Kit.assertBindingsXml`, `Kit.keybindThroughTab` | `docs/api/testkit/version-42-docs.md`; CHANGELOG `### Test kit revision 42` | `tests/` | additive | adopt, as part of **DR-KB** |
| B3 | Kit revision 42: `mock_layers.lua` (frame-layer recorder) | `docs/api/testkit/version-42-docs.md` | `tests/` | additive | **DR-ZS** decides (frame-layering item) |
| B4 | `O.StrataTooltip(values, strings)` for a player strata row | Options doc, C8 paragraph; CHANGELOG `### OptionsCompose minor 8` | `settings/*.lua` | additive | **DR-ZS** decides; DpsRace's accepted strata ids (`DPS-Z01..Z04`, `DPS-Z06`) govern whether a strata row exists |
| B5 | `W.DragHandle` `spec.level`, `handle:ApplyLevel()`, `spec.ignoreParentAlpha` | Widgets doc 15.1.5.3.3; CHANGELOG `### WidgetsDragHandle minor 5` | `modules/Hud.lua` and any other dragged frame | additive | **DR-ZS** decides |
| B6 | `Core.RaiseStaticPopups()` for a host's own window | CHANGELOG `### Core minor 12 ...` | `modules/*.lua` | additive | deferred (run 2026-10-24) |

## C. Whole-module adoption

| # | Major | Recorded reason | Recommendation |
|---|---|---|---|
| C1 | `LibKa0s-Glow-1.0` | none found in `docs/` | deferred (run 2026-10-24) |
| C2 | `LibKa0s-Item-1.0` | none found in `docs/` | deferred (run 2026-10-24) |
| C3 | `LibKa0s-Sim-1.0` | none found in `docs/` | deferred (run 2026-10-24) |

No GitHub search was run for recorded declines: the item spec rules that nothing is filed in this
run, so no decline needs de-duplicating against the issue store.
