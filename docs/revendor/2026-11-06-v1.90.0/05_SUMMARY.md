# Summary

- **Tag:** v1.89.0 -> v1.90.0 (a local tag, commit `4485b8f`; not a refresh), base from the provenance
  line (`CLAUDE.md:43`), confirmed by the last payload commit `f382ddc`. Minors: Core 15 -> 16, Skin 16 ->
  17, SkinPaint 18 -> 19, SkinPaintExtras 17 -> 18, Widgets 23 -> 24, WidgetsAutocomplete 7 -> 8,
  OptionsAppearance 6 -> 7. Kit 51 -> 51. Table in `01_DELTA.md`. No cross-major skew, no line-ending
  drift, no file removed upstream.
- **Span bundle:** none (3h printed nothing). **Base correction:** none (Step 0 `ok`). **Refresh:** none.
- **For free (class A):** `SF1-L1`, every Widgets edge (the Results and Insights filter dropdowns, the
  search box, the shared menu and every cascade level, the autocomplete list) is one physical pixel at any
  UI scale and sub-pixel position, under every skin and with none; `SF1-L2`, a skin copy from another addon
  never writes a `keepScope` owner's Scope (DpsRace registers without it, so a copy still carries its
  Scope as before).
- **Blocker:** none. The release names no facade or stub member a host owes, and the gate at the copy
  (stubs and `tests/test_surface_parity.lua` included) is green with no host edit.
- **Icons:** `LibKa0s icons:` line kept unchanged (29 names). The tag's `tools/prune-icons.lua` kept 31
  files and removed 5809, leaving `media/icons/` exactly as before the copy (no git change under it). Sets
  shipped are unchanged (Open Iconic, Phosphor), so the README credits are untouched. No provenance
  split, no dead stub mirror.
- **Adopted / declined:** nothing offered. Decisions come from Ka0sAddonsCommonTasks
  `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/SF1_SMOKE_FEEDBACK.md` with no interview: the one new surface,
  `RegisterOwner`'s `keepScope`, is the Skin Tester's (`SF1-ST`), not this addon's. No issue filed.
  **Unreached / undecided:** nothing.
- **Gate at the copy:** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 181 files (`libs/` and
  `tests/_kit/` excluded); `ka0s-bounded lua tests/run.lua` 1448 passed, 0 failed, 1 skipped (the
  diagnostics opt-out case, as before). Largest owned file 1407 lines, under the 1500 cap. No owned
  function changed, so the CCN 15 ceiling is unaffected.
