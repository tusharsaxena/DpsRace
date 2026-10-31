# 2026-10-31 — DPS Race bar styling

Branch `feat/2026-10-31-dpsrace-bar-styling`, in the checkout the game loads. Spec:
`docs/superpowers/specs/2026-10-31-dpsrace-bar-styling-design.md`. Gate per commit: bounded
`lua tests/run.lua` and `luacheck .`, 0/0. Each step is one commit, its box ticked in the same commit, so a
fresh session resumes at the first open box. No merge, tag, version bump or push: the lead pushes.

- [x] B1 Defaults and resolver: `BAR_BLUE`, the compare and detail blocks, background and border leaves;
  `HudAppearance.Styled`, `PaintTrack`, `PaintEdge`. Tests in `tests/test_bar_style.lua`.
- [x] B2 Surfaces: spell rows by `where`, the pace bar, the table's cells, the compare's bars and tracks.
- [x] B3 Settings: `NS.BarStyleRows`, HUD Appearance's new subsections, History's Results table rows and
  the Run detail tab, the locale.
- [x] B4 Migration v8.
- [x] B5 Docs: `settings-panel.md`, `schema.md`, `module-map.md`, smoke rows, `test-cases.md`, README badge.
- [ ] B6 Final gate: suite, luacheck, complexity through the bounded runner; a clean tree.
