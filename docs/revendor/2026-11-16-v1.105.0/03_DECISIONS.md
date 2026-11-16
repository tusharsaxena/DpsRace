# 03 Decisions

Source: Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/` (owner rulings of 2026-11-16, design section 5). Phase [3] adoption is planned but not executed in this run, so there was no interview and no GitHub issue was filed.

- Every class B and class C candidate in 02_CANDIDATES.md is **owed in phase [3]**, tracked by the open LibKa0s adoption issues #79, #85, #86, #87, #88, #89 and #92. Under the owner's ruling Q6, the matching WowAddonStandards v2.113.0 rules bind this addon when it adopts each feature, not at this re-vendor.
- **#84, decided by the run's design (section 3.4):** DpsRace's own row washes move to the library's new Ka0s Default values, so the stripe shows under Ka0s Default. `dr.list.stripe` goes from white .025 to white .08 and `dr.list.hover` from white .04 to gold .16. `dr.list.sel` goes from gold .10 to gold .26 along with them. Without that, a hovered row (gold .16) would read stronger than the selected row (gold .10), and the library's three values were measured as a set (R5 section 3). Other skins are unchanged: each token still follows its skin's `list.*`.
