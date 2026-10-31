# Refresh 2: the re-cut v1.84.0 without `__PatchLSM30Border`

The tag moved before it was pushed (`git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing), so this is a refresh and not a new bundle. The owner asked on 2026-11-01 for the empty stub to go, and LibKa0s `8b2293e` (LK-M4) deleted `lib.__PatchLSM30Border`.

`git -C ../LibKa0s rev-parse v1.84.0^{commit}`: old 7a8bc0f133ed118d2c79c7c5288b97964e24fae5, new b5229b876e803768322fb4d8c66be69f01c8e4a1.

## Per-file minors

3c's loop against each commit. Files not listed did not move.

| File | 7a8bc0f | b5229b8 |
|---|---|---|
| `Options.lua` | 36 | 37 |
| `OptionsDrawer.lua` | 3 | 4 |
| `OptionsMedia.lua` | 2 | 3 |

`tests/_kit/` did not change between the two commits (revision 47).

## Copy and prune

Before the copy, the payload matched 7a8bc0f file for file, apart from the pruned icons. Whole folders from the tag. `diff -r --strip-trailing-cr` before the prune printed nothing for either payload. The prune kept 28 files and removed 5812, the declaration unchanged.

## The call

No authored file or test in this repo names `__PatchLSM30Border`. The load-time call left in `293fa3b` (M3-MEDIA), so this refresh changes no host code. The one remaining match in the repo is the history comment at `libs/LibKa0s/Options.lua:46`, which is vendored and read-only.

## Blocker

None. The `LibKa0s icons:` line, the credits, the stub surfaces and the pinned minors did not need to move.

## Gate

`ka0s-bounded lua tests/run.lua`: 1260 passed, 0 failed, 1 skipped. `ka0s-bounded luacheck .`: 0 warnings, 0 errors in 166 files.
