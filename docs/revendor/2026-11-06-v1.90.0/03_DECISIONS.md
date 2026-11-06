# Decisions

There was no interview. Every decision comes from Ka0sAddonsCommonTasks
`docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/SF1_SMOKE_FEEDBACK.md`, *The items*. No GitHub issue is filed.

| Candidate | Class | Decision | Source |
|---|---|---|---|
| `RegisterOwner` `keepScope` | B | not applicable: DpsRace has no documented Scope deviation | SF1 item `SF1-ST` (the Skin Tester only) |
| Pixel edges, the copy's Scope guard | A | delivered on the copy | not a candidate |

Undecided candidates: none.

## The header ruling (SF1 item 5)

The owner ruled that DpsRace's column headers, with a grey line above and below, are wrong, and that
LootHistory's are correct. That is item `SF1-DR`, its own commit after this re-vendor (`9185b69`). It
removes the Runs filter bar's bottom divider and the table header's bottom divider, and hands the
header to `NS.Skin.SortHeaderBar`, the seam LootHistory uses.
