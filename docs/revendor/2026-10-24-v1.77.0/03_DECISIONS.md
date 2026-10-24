# DpsRace: decisions

No interview. The cross-repo run's item spec pre-decides every candidate
(`Ka0sAddonsCommonTasks/docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/plan-data/items.json`, item DR-RV:
"the adoptions this run needs are the DR-KB and DR-ZS items, so record every other candidate as
'deferred (run 2026-10-24)' in the bundle and file nothing").

| # | Candidate | Decision | Source |
|---|---|---|---|
| B1 | Keybindings tab (`O.KeybindingsTab`, `O.KeybindRows`, `O.KEYBINDS_UNCHANGED`) | adopt, in item DR-KB | run bundle, item DR-KB |
| B2 | Kit `mock_bindings.lua`, `Kit.assertBindingsXml`, `Kit.keybindThroughTab` | adopt, in item DR-KB | run bundle, item DR-KB |
| B3 | Kit `mock_layers.lua` | left to item DR-ZS | run bundle, item DR-ZS |
| B4 | `O.StrataTooltip` | left to item DR-ZS | run bundle, item DR-ZS and `plan-data/accepted.json` |
| B5 | DragHandle `level` / `ApplyLevel` / `ignoreParentAlpha` | left to item DR-ZS | run bundle, item DR-ZS and `plan-data/accepted.json` |
| B6 | `Core.RaiseStaticPopups()` in a host window | deferred (run 2026-10-24) | run bundle, item DR-RV |
| C1 | Glow module | deferred (run 2026-10-24) | run bundle, item DR-RV |
| C2 | Item module | deferred (run 2026-10-24) | run bundle, item DR-RV |
| C3 | Sim module | deferred (run 2026-10-24) | run bundle, item DR-RV |

Nothing is filed as a GitHub issue: the item spec says "file nothing".
