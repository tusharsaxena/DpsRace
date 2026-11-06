# Candidates, LibKa0s v1.90.0 -> v1.91.0

Sources: `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0`, the tag's `CHANGELOG.md` block v1.91.0,
and the `docs/api/` documents of every major whose minor moved (Core 16 -> 17.1, Widgets
25.6.13.6.8.5 -> 26.1.6.13.7.8.5, Skin 17.1.27.8.19.18.17.4.9 -> 17.1.27.8.19.19.1.1.17.4.9). No
contract blocker beyond the file floor fixed in the re-vendor commit (01_DELTA 3g).

## Class A: delivered on the copy

- **The line chart's lines in physical pixels** (CHANGELOG v1.91.0, *The line chart's lines in
  physical pixels (`FU-L1`)*; WidgetsLineChart minor 7). Arrives on the copy, but DpsRace draws no
  `W.LineChart`, so nothing on its screens changes.
- **The four peels** (CHANGELOG v1.91.0, *The band files peeled (`FU-L2`)*): `CorePixel.lua`,
  `WidgetsDropdown.lua`, `SkinPaintHud.lua`, `SkinAceConfirm.lua`. Pure moves: "No member, option or
  behavior changes". DpsRace's dropdown, shared menu, `S.BarGloss` and `S.HudFont` keep working
  through the same seams.

## Class B: host change required

None. The release adds no member, option or row field.

## Class C: whole-module adoption

None. No major is new in this range (the new files are secondaries of existing majors).
