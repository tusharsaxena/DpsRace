# Candidates, LibKa0s v1.83.0 -> v1.84.0

Sources: `CHANGELOG.md`'s v1.84.0 block and `docs/api/Options/version-35.4.40.2.6.1.7.13.2.3.15.9.4.3.6.5.5.1.1.1-docs.md` (lines 45-50 for the seams).

## A. Delivered on the copy

- The peels (`Skin`, `SkinDefs`, `SimPanel`, `OptionsSkinPicker`, `OptionsIds`, `OptionsWidgets`, `OptionsTabs`, `testkit/mock_base.lua`): pure moves, no public member changes.
- `O.ClearScroll` keeps the banner's refresher; this addon's banners get it with no host change.
- `DebugLogDiagnostics` minor 6: `/dr diagnostics` names Charts in its header.
- WoW Default's Friz is measured; no size moved.
- `WidgetsDragHandle` minors 9 and 10: this addon makes no `DragHandle` call, so nothing changes here.

## B. Host change required

| Candidate | Evidence | Would touch | Blast radius | Recommendation |
|---|---|---|---|---|
| `opts.beforeGroup` | Options doc, table row `beforeGroup` | `settings/OptionsSetup.lua`, `settings/History.lua` | Moves a row the page already draws | Adopt (LibKa0s#59, this addon's own ask, DPS-P17) |
| `opts.afterSubgroup` | Options doc, table row `afterSubgroup` | `settings/*.lua` | Additive | Decline: no act here hangs off a subgroup |
| `note` row | Changelog, OptionsFlow minor 2 | `settings/Race.lua`, `settings/History.lua` | Replaces `H.TextRow` calls | Decline: each `TextRow` sits inside a `skipRender` list's tail, in order with its widgets, and the stored count is live text |
| `O.PositionBlock` | Changelog, OptionsCompose minor 15 | the toast's and the center countdown's place rows | Replaces rows | Decline: the settings hold no X and Y rows to compose; the places are dragged |
| `O.PageBanner{ acts }` | Changelog, OptionsTabs minor 13 | none | Additive | Decline: this addon's pages draw no `PageBanner` |

## C. Whole module

| Candidate | Evidence | Would touch | Blast radius | Recommendation |
|---|---|---|---|---|
| `LibKa0s-Charts-1.0` | `docs/api/Charts/version-1.1-docs.md`; LibKa0s#66; this addon's deviation row in `docs/ARCHITECTURE.md` | `modules/Results_Insights.lua`, `modules/Results_InsightsCharts.lua`, `DpsRace.toc`, `tests/test_insights.lua` | Replaces a file this addon owns | Adopt (the row's own re-check trigger has fired) |
