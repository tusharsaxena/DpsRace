Delta: LibKa0s v1.77.0 -> v1.83.0 (span: v1.80.0 v1.81.0 v1.82.0 v1.83.0)

# 01 - Delta: the consolidated span bundle

Item FX-DR-DOCS of the 2026-10-31 findings remediation (Ka0sAddonsCommonTasks
`docs/2026-10-31-FINDINGS_REMEDIATION/`). It holds `01_DELTA.md` and `05_SUMMARY.md` only, because
these tags were re-vendored by run items that kept their records in their own bundles and left none
here. Nothing was re-derived against the library: this records what this repository's history shows.

## Where the tag list comes from

The `CLAUDE.md` provenance line at each commit touching `libs/LibKa0s` or `tests/_kit`:

- Recorded: v1.77.0, in `docs/revendor/2026-10-24-v1.77.0/`, the store's first bundle.
- Vendored since: v1.80.0, v1.81.0, v1.82.0 and v1.83.0. v1.78.0 and v1.79.0 were never vendored.
- `585750a` and `8cb98af` (2026-10-28) copied `LibKa0s-Toast-1.0` alone ahead of the tag, with the
  provenance line still at v1.77.0; `302c2ba` dropped that deviation.

## Vendoring commits

| Tag | Commit | Date |
|---|---|---|
| v1.80.0 | `302c2ba` DR-RV: Re-vendor LibKa0s v1.80.0 and drop the Toast-ahead deviation | 2026-10-29 |
| v1.81.0 | `78cd417` DR-RV: Re-vendor LibKa0s v1.81.0 | 2026-10-30 |
| v1.82.0 | `79eed51` DR-01: Re-vendor LibKa0s v1.82.0 with the facade and stub members it owes | 2026-10-30 |
| v1.83.0 | `5a2678f` DR-F01, then the tag's two re-cuts `8216d9c` DR-RV2 and `0d913d2` DR-RV3 | 2026-10-31 |

## Payload moved, v1.77.0 to v1.83.0

`git -C ../LibKa0s diff --stat v1.77.0 v1.83.0 -- LibKa0s testkit`: 99 files, 16652 insertions, 972
deletions, over 181 commits. New files: the Skin family (`Skin`, `SkinAce`, `SkinDefs`, `SkinEUI`,
`SkinPaint`, `SkinPaintControls`, `SkinPaintExtras`), `Toast`, `OptionsAppearance`, `OptionsMedia`,
`OptionsSkinPicker`, `OptionsSwitch`, `DebugLogWindow` and `WidgetsCopyWindow`.
