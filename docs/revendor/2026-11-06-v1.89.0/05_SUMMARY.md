# Summary

- **Tag:** v1.85.0 -> v1.89.0, base from the provenance line (`CLAUDE.md:43`), confirmed by the last payload
  commit `11fe1b4`. Minors: Toast 3 -> 4, Widgets 22 -> 23, DebugLogDiagnostics 6 -> 7, IconBrowser new
  (three files at 1). Kit 50 -> 51. Table in `01_DELTA.md`. No cross-major skew, no line-ending drift, no
  file removed upstream.
- **Span bundle:** none (3h printed nothing). **Base correction:** none (Step 0 `ok`). **Refresh:** none.
- **For free (class A):** kit 51's CallbackHandler unregister guard; the diagnostics report naming
  IconBrowser when it runs; the Toast 4 shell as the version 3 toast; Widgets 23's flat menus unchanged,
  with `W.CloseMenu()` now closing every cascade level.
- **Blocker:** the Toast degradation stub (`core/ToastSetup.lua`) gains `SetStack`, `Visible` and
  `FrameFor`, and its `Stats()` the documented `keys`, `visible`, `visibleKeys`, `stack`, `grow`
  (`docs/api/Toast/version-4-docs.md`, *The degradation stub*); held by
  `tests/test_surface_parity.lua:164`. Resolved in this commit.
- **Icons:** `LibKa0s icons:` line kept unchanged (29 names). The tag's `tools/prune-icons.lua` kept 31
  files and removed 5809, leaving `media/icons/` exactly as before the copy (no git change under it). Sets
  shipped are unchanged (Open Iconic, Phosphor), so the README credits are untouched. No provenance
  split, no dead stub mirror.
- **Adopted:** Widgets 23 `submenu` rows, in item `V89A-DR` (its own commit, not this one).
- **Settled:** Toast 4 stack (one toast at a time); IconBrowser (no icon chooser). **Declined:**
  nothing; no issue filed. **Unreached / undecided:** nothing.
- **Gate at the copy:** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 180 files (`libs/` and
  `tests/_kit/` excluded; `core/ToastSetup.lua` is checked); `ka0s-bounded lua tests/run.lua` 1448 passed,
  0 failed, 1 skipped (the diagnostics opt-out case, as before). Largest owned file 1407 lines, under the
  1500 cap.
