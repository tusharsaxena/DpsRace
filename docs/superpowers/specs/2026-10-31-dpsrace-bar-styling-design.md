# DPS Race bar styling: one blue, brighter compare bars, every bar configurable

Branch `feat/2026-10-31-dpsrace-bar-styling`. The owner's request of 2026-10-31.

## The three asks

1. The HUD spell breakdown, the Results table's Damage and DPS cell bars and the Results detail's spell
   breakdown take the blue of the HUD's pace bar ("vs best pace", heading *Damage profile*).
2. The compare's yellow and blue bars get a slightly brighter shade, same hue. The percentage text and
   the rule for which side is blue stay as they are.
3. Each bar is configurable on its own: texture, color, background, border.

## Findings

- The pace bar's blue is `appearance.pace.barColor`, `{ 0.36, 0.37, 0.84, 1 }` at `barAlpha` 0.9
  (`defaults/Profile.lua`, drawn by `Pace:SetRange` in `modules/Hud_Chart.lua`). The spell rows and the
  table's two bars were `{ 0.29, 0.29, 0.45, 1 }` at 0.85. The chart's columns already carry the pace value.
- Matching means color **and** opacity: at 0.85 the same color reads differently.
- The HUD's rows and the Results detail's rows share `appearance.bars`, one block. Ask 3 splits it.
- The compare's bars are flat data hues today (`Compare.BAR_BEST`, `BAR_OTHER`), not skin colors.
- `ka0s-default.tga`, Ka0s Default's bar texture, averages 0.69 white. A compare bar following the skin's
  texture comes out darker than today's flat bar. The owner accepted that on 2026-10-31: the texture
  follows the skin even when the drawn shade differs from the one asked for.

## Design

**One source.** `defaults/Profile.lua` holds `BAR_BLUE` and `BAR_BLUE_ALPHA`. The pace, chart, spell,
detail and table blocks each take a copy from them. Blocks are independent afterwards: changing the pace
bar's swatch moves only the pace bar. A test pins that all of them hold the same value.

**Compare colors.** Today's channels times 1.3, rounded to the byte, so the hue holds to under a degree:
best `{ 42/255, 70/255, 107/255 }` (was 32, 54, 82), other `{ 83/255, 69/255, 0 }` (was 64, 53, 0).
Both are defaults in the profile tree, in `compare.best` and `compare.other`. `Compare.BAR_BEST`,
`BAR_OTHER`, `BAR_ALPHA` and `BarColor` go; `Compare.BarBlock(side, best)` answers which block a column
draws, by the same rule.

**Six blocks, each with Fill, Background and Border.**

| Surface | Prefix | Settings home |
|---|---|---|
| HUD spell breakdown | `appearance.bars.` | HUD > HUD Appearance |
| HUD pace bar | `appearance.pace.` | HUD > HUD Appearance |
| Results table Damage, DPS | `resultsTable.damageBar.`, `.dpsBar.` | History > Results table |
| Results detail spell breakdown (new) | `resultsDetail.spellBars.` | History > Run detail (new tab) |
| Compare, best run (new) | `compare.best.` | History > Run detail |
| Compare, other run (new) | `compare.other.` | History > Run detail |

The pace bar sits in the set: it already has a composed bar block and a skin track. Its green and red
parts are meaning colors and stay as they are. The damage chart keeps its own block and background.

Each block is the composed `BarGroup`, then a `ColorPair` (`bgColor`, `useClassColorBg`) with one appended
row, `bgFromSkin` (*Use the skin's background*), then a `BorderGroup` with `fromSkin = true`
(`borderStyle`, `borderSize`, `borderColor`, `useClassColorBorder`, `borderStyleFromSkin`). Pickers are the
composer's `LSM30_*` rows, which LibKa0s v1.83.0 draws as `Ka0sMedia_*` when SharedMediaWidgets is absent
(options-ui-§23). Row height and the spell text stay shared, HUD and detail, as they are today.

**The skin.** The two tracks that exist today keep following it: `bgFromSkin` defaults on for the spell
bars (`dr.list.track`) and the pace bar (`dr.chart.grid`), so their defaults draw the same pixel under every
skin. The table and the compare draw no track today (the owner's call, 2026-10-25), so `bgFromSkin` is off
and the swatch's alpha is 0 by default. Ticking the companion there draws `dr.list.track`. Every border's
`borderStyleFromSkin` defaults on (skinning-§6) and Ka0s Default's `bar.borderStyle` is *None*, so no border
draws under Ka0s Default. Thickness and border color are the player's (X4). `compare.*.barTextureFromSkin`
defaults **on** like every other bar (the owner's call, 2026-10-31), with `barTexture` *Solid* as the stored
pick. The v8 profile format never shipped, so no migration resets it.

**Where a background and border draw.** Over the bar's whole length, not the fill: the row on a spell list,
the cell on the table, and each run's column on a compare line. A compare line has both tracks, each in its
own block's look, whichever side the bar is on. The border is a click-through frame with no fill, built
only when a block has a border. It sits above the text, so a thick border can cover a text edge.

**Live.** HUD Appearance rows and the Run detail tab's rows call `HudAppearance.Changed()`, the Results
table's call `NS.Results.Refresh()`. A skin switch reaches all of them through `Changed()`.

**Secret values.** Nothing new reads a meter value or geometry: a look comes from config and the skin.

**Migration, v7 to v8, per profile.** `resultsDetail.spellBars` splits off `appearance.bars`, so a player's
stored fill (`barTexture`, `barTextureFromSkin`, `barAlpha`, `barColor`, `useClassColorBar`) is copied there,
and the detail keeps its look. AceDB strips a default per leaf, so a stored `barColor` may hold only the
channels the player moved: the step writes the old defaults into the missing channels of
`appearance.bars`, `resultsTable.damageBar` and `resultsTable.dpsBar`, so a custom color does not shift with
the new default. An untouched profile stores nothing and reads the new blue. Reset and profile copy need
nothing: every new key is a plain profile key with a schema row.

## Out of scope

Row height and spell text per surface, the Insights charts, the ability timeline's colors, the class source
of the detail's bars (the player's, as shipped).
