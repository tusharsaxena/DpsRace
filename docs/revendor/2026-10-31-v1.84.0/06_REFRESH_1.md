# Refresh 1: the re-cut v1.84.0

The tag moved before it was pushed (`git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing), so this is a refresh and not a new bundle. The owner's ruling of 2026-11-01 made `Ka0sMedia_*` the only media picker (LibKa0s#73).

`git -C ../LibKa0s rev-parse v1.84.0^{commit}`: old e917ccd, new 7a8bc0f133ed118d2c79c7c5288b97964e24fae5.

## Per-file minors

3c's loop against each commit. Files not listed did not move.

| File | e917ccd | 7a8bc0f |
|---|---|---|
| `SkinAce.lua` | 5 | 6 |
| `Options.lua` | 35 | 36 |
| `OptionsWidgets.lua` | 40 | 41 |
| `OptionsCompose.lua` | 15 | 16 |
| `OptionsScroll.lua` | 9 | 10 |
| `OptionsMedia.lua` | 1 | 2 |

`tests/_kit/` did not change between the two commits (revision 47).

## Copy and prune

Whole folders from the tag. `diff -rq --strip-trailing-cr` before the prune printed nothing for either payload. The prune kept 28 files and removed 5812, the declaration unchanged.

## Blocker

The `LibKa0s icons:` line, the credits and the stub mirrors did not move. One contract moved: the composer writes `dialogControl = "Ka0sMedia_*"`, so `tests/test_bar_style.lua`'s two `LSM30_*` pins moved in this commit.

## Gate

`ka0s-bounded lua tests/run.lua`: 1260 passed, 0 failed, 1 skipped. `ka0s-bounded luacheck .`: 0 warnings, 0 errors in 166 files.
