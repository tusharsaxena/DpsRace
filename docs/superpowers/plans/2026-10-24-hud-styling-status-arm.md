# 2026-10-24 — HUD styling, run status and the stuck arm

Branch `feat/2026-10-24-hud-styling-status-arm`. Gate per commit: `lua tests/run.lua` and
`luacheck .` (0/0), run through the bounded runner. Each step is one commit, and the checkbox is ticked
in the same commit, so a fresh session resumes at the first open box.

## Decisions (the owner, 2026-10-24)

- Time: one cell. The Length column becomes **Time**: `2:00 +11.1s` (the tail dimmed) for a run past
  its buzzer, and `1:04 / 2:00` for an incomplete one. The HUD result card and the detail header use
  the same text.
- Status column tags: Complete (green), Incomplete (red), Lost (gray), Died (red), Best (gold, which
  replaces Complete on a run that holds a best) and Flagged (amber, a complete run with flags). The DPS
  column shows the DPS for every run that has one, incomplete runs included.
- Spell-bar formatting applies to the HUD (live and result card) and to the Results detail breakdown.
- The new font and bar rows sit on a new General tab, **HUD Appearance**: Clock font, Figures font,
  Spell bars.
- `live.rows = 0` means all spells. The running body scrolls with the mouse wheel through the rows
  that do not fit (MultiMeters' offset model, not a ScrollFrame).

## Steps

- [x] S1 Arm fix. The clock also starts on the first DamageDone update heard in combat while armed, so
  a session the meter created out of combat (a DoT tick, an opener landing a frame before the regen
  edge) can no longer leave the race armed. A pull that continues a session from before the arm is
  adopted and flagged `sharedSession`. The pre-arm total read at arm time is subtracted, and a fresh
  session heard later replaces the shared one.
- [x] S2 Status column, DPS for every run, the Time cell (table, detail, HUD result card), and the
  Results minimum widths.
- [x] S3 `live.rows` 0 = all, and the running body's wheel scroll.
- [x] S4 HUD Appearance: clock font, figures font, spell bars (texture, opacity, color, class color,
  row height, font). Applied to the HUD and the Results detail.
- [ ] S5 Docs (ARCHITECTURE, schema, settings-panel, data-flow, smoke-tests) and the smoke checklist.
