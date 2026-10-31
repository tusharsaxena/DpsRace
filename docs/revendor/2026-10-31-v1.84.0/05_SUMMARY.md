# Summary, LibKa0s v1.83.0 -> v1.84.0

Base v1.83.0, from the provenance line. New tag v1.84.0, local. The per-file minors are in `01_DELTA.md`. Kit revision 46 -> 47. No span bundle and no base correction.

- **Free:** see 02_CANDIDATES.md, class A.
- **Blockers:** none. The re-vendor's owed edits: the Options stub's `O.PositionBlock`, and the new files in `tests/run.lua`'s floor list.
- **Icons:** the `LibKa0s icons:` line is kept; the prune kept 28 files and removed 5812, of the three sets the copy brings. No provenance split. The README credits are unchanged: Open Iconic and Phosphor still ship and no Game-icons mark does. No dead stub mirror.
- **Adopted:** `opts.beforeGroup` and `LibKa0s-Charts-1.0`, in the `XX-ADOPT` commit.
- **Declined:** `opts.afterSubgroup`, the `note` row, `O.PositionBlock`, `O.PageBanner{ acts }`. Recorded here; no issue was filed, as the run's brief says.
- **Gate at the copy:** `ka0s-bounded luacheck .` 0/0 in 165 files; `ka0s-bounded lua tests/run.lua` 1258 passed, 0 failed, 1 skipped. The seam files in `settings/` are inside luacheck's set.
