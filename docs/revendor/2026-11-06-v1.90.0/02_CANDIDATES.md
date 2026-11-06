# Candidates, LibKa0s v1.89.0 -> v1.90.0

Sources: `git -C ../LibKa0s log --oneline v1.89.0..v1.90.0`, the tag's `CHANGELOG.md` block v1.90.0,
and the `docs/api/` documents of every major whose minor moved (Core 15 -> 16, Widgets
23.5.12.6.7.5 -> 24.5.12.6.8.5, Skin 16.1.27.8.18.17.17.4.9 -> 17.1.27.8.19.18.17.4.9, Options
OptionsAppearance 6 -> 7). No contract blocker (01_DELTA 3g).

## Class A: delivered on the copy

- **One physical pixel** (CHANGELOG v1.90.0, *One physical pixel (`SF1-L1`)*;
  `docs/api/Widgets/version-24.5.12.6.8.5-docs.md`, "What a host owes: nothing"). `W.Dropdown`'s
  box, `W.SearchBox`, the shared menu and its cascade levels, and the autocomplete list now draw an
  edge one physical pixel wide at any UI scale. DpsRace gets this through its seams
  (`core/WidgetsSetup.lua`: `NS.MakeDropdown`, and `NS.OpenMenu`'s `W.ContextMenu`) with no host
  change. These are the Results window's filter dropdowns, whose 1-or-2 px edge the owner reported
  (SF1 item 4).
- **A copy leaves a `keepScope` owner's Scope alone** (CHANGELOG v1.90.0, *A copy leaves a host's
  Scope alone (`SF1-L2`)*; OptionsAppearance minor 7). When the player runs *Apply to all* from
  DpsRace, a target registered with `keepScope` (Ka0s Skin Tester, `SF1-ST`) keeps its Scope.

## Class B: host change required

- **`RegisterOwner(owner, { keepScope = true })`** (Skin minor 17;
  `docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md`, the `keepScope` option row, `Since 17`).
  It is for a host whose Scope is a documented deviation. DpsRace's registration has no such
  deviation, so it keeps taking a copied Scope like every other addon. **Not applicable.**

## Class C: whole-module adoption

None. No major is new in this range.
