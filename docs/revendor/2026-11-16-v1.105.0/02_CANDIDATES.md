# 02 Candidates, LibKa0s v1.93.0 -> v1.105.0

Sources: `git -C ../LibKa0s log --oneline v1.93.0..v1.105.0`; LibKa0s CHANGELOG.md, the v1.94.0 to v1.105.0 blocks (v1.105.0's *What a consumer owes*); Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/03_ADOPTION_PLAN.md` and its research note R7 section 3 (site counts).

**Class A, delivered on the copy alone (smoke lines, not candidates)**
- Skin colors (#82, #84): Ka0s Default's rows are now stripe .08, hover gold .16, selection gold .26, and seven skins' `icon.hot` moved. This addon's `dr.list.*` tokens follow `list.*` under every other skin, so they take the new values there from the copy alone.
- Header marks (#86) on the library windows this addon opens: the debug console, the copy window, the perf panel, the sim panel and the skin picker carry extras, settings and close on their title band. The settings mark opens this addon's settings through its launcher.
- The debug console (#79, #90): a 24 px Widgets footer with its counter in `text.muted`; Copy hands out plain text.
- Library tooltips (#92) placed by `LibKa0s-Tooltip-1.0`: dropdown and menu entries, the sim panel's controls and step rows, Charts' default tooltip, and the minimap button's tooltip (toward the screen's center, 2 px off it).
- The sim panel's default title is `%s - SIM`; this addon sets its own title, so no player sees it.
- Kit revision 57 (frame hold while registered, opt-in `mock_screen.lua`).

**Host change made in this commit (planned, not a candidate)**
- #84 at its reported site: the owner tokens `dr.list.stripe`, `dr.list.hover` and `dr.list.sel` answer their own `default` under Ka0s Default, so the library fix did not reach them. They take the library's new Ka0s Default rows (design section 3.4, re-vendor follow-ups; items.tsv RV-DR). See 03_DECISIONS.md.

**Class B, host change required: owed in phase [3], not offered in this run**
| Issue | Surface | This addon's sites (R7 section 3) |
|---|---|---|
| LibKa0s#92 | `LibKa0s-Tooltip-1.0` placers (`PlaceBeside`, `PlaceAttached`) | 13 tooltip sites in 9 files; 3 `ANCHOR_RIGHT`, 2 `ANCHOR_NONE` |
| LibKa0s#86 | `W.HeaderButtons` title strip with a settings mark | 4 windows (Hud, Results, Results_Gear, Results_Timeline), 7 `Style.ControlButton` marks |
| LibKa0s#88 | docked test/sim strip (`dock="hud"` / `dock="title"`) | Hud test and sim `anchorStrip` (modules/Hud.lua), Results `anchorStrip` (modules/Results.lua) |
| LibKa0s#89 | `W.Footer` 24 px | the HUD's hand-built 20 px footer (modules/Hud.lua `buildFooter`) |
| LibKa0s#79 | `D:Report` / `D:Serialize` | `/dr ignore show` (settings/Slash.lua) and the results report verb |
| LibKa0s#87 | `Sim.Sample(client)` shared sample characters | the addon's own sample names in its sim and test data |
| LibKa0s#85 | Callout major | recommended adopt: replace modules/Countdown.lua |

**Class C, whole-module**: Callout (#85, above), Tooltip (#92, above). Glow, IconBrowser, Item, Role and WaypointArrow have no use here.

**Blockers (3g)**: the Options stub's `SideTabs`, fixed in the re-vendor commit.
