# Summary

- **Tag:** v1.90.0 -> v1.91.0 (a local tag, commit `55bfbb4`; not a refresh), base from the provenance
  line (`CLAUDE.md:43`), confirmed by the last payload commit `bb63c8d`. Minors: Core 16 -> 17,
  CorePixel new at 1, Widgets 25 -> 26, WidgetsDropdown new at 1, WidgetsLineChart 6 -> 7,
  SkinPaintExtras 18 -> 19, SkinPaintHud new at 1, SkinAceConfirm new at 1. Kit 51 -> 51. Table in
  `01_DELTA.md`. No cross-major skew, no line-ending drift, no file removed upstream.
- **Step 0:** the roster-wide table was skipped, because the installed skill's roster regex matches
  nothing in the current `ADDONS.md` (fixed upstream in FU-DC1). This addon's own row is `ok`.
- **Span bundle:** none (3h printed nothing). **Base correction:** none. **Refresh:** none.
- **For free (class A):** the four peels, which are pure moves with no member change; and WidgetsLineChart
  minor 7's physical-pixel lines, which DpsRace does not draw (no `W.LineChart`).
- **Blocker:** the library file floor in `tests/run.lua` (`EXPECTED`). `CorePixel.lua`,
  `WidgetsDropdown.lua`, `SkinPaintHud.lua` and `SkinAceConfirm.lua` join it beside the files they were
  peeled from, in the tag's `LibKa0s.xml` order, in the re-vendor commit. The loader itself reads
  `LibKa0s.xml`, so it needed no edit. No minor pins and no stub mirrors to move.
- **Icons:** `LibKa0s icons:` line kept unchanged (29 names). The tag's `tools/prune-icons.lua` kept 31
  files and removed 5809, leaving `media/icons/` exactly as before the copy. Sets shipped are unchanged
  (Open Iconic, Phosphor), so the README credits are untouched. No provenance split, no dead stub mirror.
- **Adopted / declined:** nothing offered (decisions from the plan, no interview, no issue filed).
  **Unreached / undecided:** nothing.
- **Gate at the copy:** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 181 files (`libs/` and
  `tests/_kit/` excluded); `ka0s-bounded lua tests/run.lua` 1452 passed, 0 failed, 1 skipped (the
  diagnostics opt-out case, as before). Largest owned file 1407 lines (`modules/Hud_States.lua`), under
  the 1500 cap. No owned function changed, so the CCN 15 ceiling is unaffected.
