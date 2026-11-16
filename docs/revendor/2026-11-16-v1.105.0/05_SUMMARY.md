# 05 Summary

- The tag moved from v1.93.0 to v1.105.0. The base came from the CLAUDE.md provenance line. The kit revision moved from 53 to 57. 01_DELTA.md has the 35 files that moved a minor, 9 of them new.
- Span bundle: none. Base correction: none.
- Delivered for free (class A): the #82/#84 skin colors under every skin a `dr.*` token follows, the header marks on the library windows, the console footer and plain-text Copy, the library tooltips placed by `LibKa0s-Tooltip-1.0`, and kit 57.
- Contract blockers: the Options stub lacked `SideTabs` (red in tests/test_surface_parity.lua). It is fixed in this commit.
- `LibKa0s icons:` line: kept as written (29 names, `settings` included). The prune kept 31 icon files and removed 5809. It also removed all 362 voice-pack files, because this addon has no `LibKa0s sounds:` line. The README credits are unchanged, because Open Iconic and Phosphor both still ship and no `gi:` icon does. No provenance split was needed.
- Dead stub mirrors: none.
- Host change beyond the stub: #84's row washes (`dr.list.stripe` .08, `dr.list.hover` gold .16, `dr.list.sel` gold .26 under Ka0s Default). The reason is in 03_DECISIONS.md.
- Adopted: nothing. Declined: nothing. Owed in phase [3]: #92, #86, #88, #89, #79, #87 and #85 (02_CANDIDATES.md).
- Gate (Retail only, per CLAUDE.md): `ka0s-bounded lua tests/run.lua` passed 1509 of 1510, with 0 failed and 1 skipped (the declared diagnostics opt-out case). `ka0s-bounded luacheck .` reported 0 warnings and 0 errors in 185 files. The largest authored Lua file is modules/Hud_States.lua at 1486 lines, under the 1500 cap. docs/test-cases.md regenerated unchanged, and the README badge stays at 1509.
- Smoke owed (owner): SM-RV in the run's 06_SMOKE_TESTS.md, plus the Results list and the HUD spell rows under Ka0s Default: the stripe, hover and selected rows can be told apart at a glance.
