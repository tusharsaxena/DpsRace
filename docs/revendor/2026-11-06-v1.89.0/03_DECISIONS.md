# Decisions

Source of every decision: Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/00_PLAN.md`,
*Decisions (owner, 2026-11-06, asked upfront)*. No interview was run and no GitHub issue was filed (the
owner ruled that issues are filed only for real not-now candidates).

| Candidate | Decision | Where |
|---|---|---|
| B1. Widgets 23 `submenu` rows instead of reopening one level in place (`core/WidgetsSetup.lua:38-104`) | **adopt**, implemented in item `V89A-DR` (not in this commit) | plan, row 1 |
| B2. Toast 4 stack | **settled**: one toast at a time (library CHANGELOG v1.88.0) | plan, row 4 |
| C. IconBrowser | **settled**: no icon chooser, recorded here, no issue | plan, row 5 |

Undecided candidates the plan's table does not cover: none.
