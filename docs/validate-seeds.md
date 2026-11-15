# Seed validation — DPS Race

The seed-validation contract `/dev-copilot:validate-seeds DpsRace <flavor>` runs. The command
supplies the loop (clean tree, one date, status, derive, rule, apply, gate, hand-back) and its
standing rules. This file supplies DPS Race's procedure: the tool, the files it writes, the
precedent a ruling follows and the nuances of the one client. The headings below are the interface
the command reads, so keep their names.

Each run ends in a frozen bundle under `docs/seed-research/<date>-<flavor>/`. The tool is
`tools/seeds/seeds.py`; its docstring is its manual. The first run is
`docs/seed-research/2026-11-15-retail/`.

**What is validated, and what is not.**

- `defaults/Hearthstones.lua` (`NS.HEARTHSTONE_SPELLS`) is **derived**. Its header states the four
  rules it was built by on 2026-10-28, and `derive` runs exactly those rules. A re-run therefore
  reproduces the shipped list, and its candidates are what a new build adds under the same rules.
- `defaults/Dummies.lua` (`Dummies.BY_ID`) is **measured**, not derived. Its header says a row is
  added from a capture in game and never guessed, so it takes **no candidates**. Its existence and
  name check has nothing to read either, so the tool does **not** check it (see `## Notes`).

## Flavors

| Flavor | Source | Seed files | Tools |
| --- | --- | --- | --- |
| `retail` | wago.tools product `wow` (Retail live) | `defaults/Hearthstones.lua` (derived, tool-checked) | `tools/seeds/seeds.py` |

DPS Race is Retail only (the roster's Clients column; the owner's ruling of 2026-11-10: WoW Forever
has no training dummies), so there is no `forever` flavor.

## Rules

- **Only the tool writes the list's rows.** `seeds.py apply` inserts and removes rows of
  `NS.HEARTHSTONE_SPELLS`. The file's header comment is hand-written and is rolled by hand under
  `### After`.
- **Rulings are data.** They live in `tools/seeds/rulings.json`, written only by `seeds.py rule`.
  A candidate's key is `hearthstones:<id>`, ruled `accept` or `reject`. A flag's key is
  `shipped:<kind>:hearthstones:<id>`, ruled `keep` or `remove`. A ruling is never keyed by build:
  it holds until the thing it ruled on stops being proposed.
- **The four rules** (the header of `defaults/Hearthstones.lua`, as `derive_hearthstones` reads
  them):
  1. every spell with a `SpellCategories` row of `ChargeCategory` 2309, the shared hearthstone
     cooldown, at any `DifficultyID`;
  2. plus every spell with a `SpellEffect` row of `Effect` 252 (teleport) and `ImplicitTarget` 9
     (the bind point), in either target slot;
  3. plus 222695 (Dalaran) and 171253 (Garrison), by id;
  4. minus `EXCLUDED`, by id: Astral Recall 556, and the test and placeholder teleports 1, 3, 70195,
     307896, 1223998, 49493 and 188816.

  Rule 2's header adds "that a toy or an item casts". The tool does not filter on that clause:
  rule 4 already removes, by id, "the teleports home no item casts", and three shipped ids
  (191329, 431644, 1286909) have no `ItemEffect` row of their own. Only this reading reproduces the
  2026-10-28 list, so it is the one coded. Instead, every candidate carries a note of who casts it:
  a toy, an item, a spell an item casts, or nobody. A candidate no item casts is the case the
  clause meant to keep out, and it is ruled as one.
- **Precedent, in this order, never re-litigated:**
  1. a ruling already in `tools/seeds/rulings.json`;
  2. the header of `defaults/Hearthstones.lua`: Scrolls of Recall and the other consumables and
     items that send a player home on the hearthstone's cooldown are **kept** (the owner's call,
     2026-10-28), and the class spell Astral Recall 556 is **left out** (a player can add it);
  3. issue #8 (the late-cast ignore list) and `docs/common-tasks.md`, *Refresh the hearthstone list*.
- **What "accept" means here.** Accept a spell a player casts from a toy or an item that sends
  them to their bind point or to a fixed home, on the hearthstone's cooldown. The ignore list's
  8690 entry stands for every id in the list (`modules/LateIgnore.lua`), so a wrong accept makes a
  late cast of that spell stop flagging a run.
- **What to reject.** Test, placeholder and `[DNT]` spells; a teleport no item casts, unless it is
  on the hearthstone's cooldown (rule 1); a class spell. When the data is not clear, reject with
  `needs owner review: <why>`.
- **Flags.**
  - `unnamed`: the build's `SpellName` has no row for the id.
  - `renamed`: the build's name disagrees with the comment beside the id. If the spell is the
    same, fix the comment by hand. If the id was reused, remove it.
  - `unfit`: the id is named but the four rules no longer derive it.
- **Evidence.** The bundle's `raw/*.csv.gz` (each candidate's effects, category and item rows), and
  `candidates.json`, whose notes name the rule or rules that derived each id and who casts it.
- **Privacy.** No player name, realm or GUID goes into a bundle, a ruling or a commit.

## Flavor: retail

### Status

```sh
python3 tools/seeds/seeds.py status --flavor retail
```

Prints `CURRENT <build> (<bundle>)`, or `NEW <build> (last ruled <build>, <bundle>)`, comparing the
live `wow` build with the newest `*-retail` bundle.

### Freeze and derive

```sh
python3 tools/seeds/seeds.py derive --flavor retail --bundle docs/seed-research/<date>-retail --date <date> --build <build>
```

It pins `<build>` (without `--build`, the live `wow` build), fetches six tables (about 76 MB) into
the git-ignored `tools/seeds/.cache/`, and freezes them gzipped (about 12 MB) into the bundle's
`raw/`. It writes `SOURCES.md`, `DIFF.md` and `candidates.json`. `--replay` re-derives from the
bundle's own `raw/` with no network, byte for byte. **If the sentinel gate fails** (8690, 222695 or
171253 not derived), **stop**: the rules or the tables have moved, and the fix is in the tool.
Report the shipped and derived counts, the candidate count, the flag count and the unruled count.

### Rule

```sh
python3 tools/seeds/seeds.py check --bundle docs/seed-research/<date>-retail
python3 tools/seeds/seeds.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/seed-research/<date>-retail
```

`check` lists every unruled key and exits 1 while there is one. It must print `OK` after `rule`. The
TSV holds one `key<TAB>ruling<TAB>reason` line per key.

### Apply

```sh
python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-retail --date <date>
python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-retail --date <date>
```

`report` comes before `apply`, because once an id has been applied a re-derive no longer proposes
it. `apply` refuses while anything is unruled. It inserts accepted ids in ascending order after
rule 3's two fixed rows, removes ids whose flag was ruled `remove`, and keeps the file's CRLF and
every other byte. A second `apply` changes nothing.

### After

- When the list's length changed, roll the pin test in `tests/test_late_ignore.lua` (the count),
  the count in `docs/module-map.md`'s `defaults/Hearthstones.lua` row, and the count in
  `docs/smoke-tests.md` SM-DR-IL1 (*(all hearthstones, N)*).
- Roll the re-validation line in `defaults/Hearthstones.lua`'s header: the build, the date, the
  bundle.
- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundle's shape:
  - what changed between the builds;
  - what was proposed, accepted and rejected, and why;
  - what a later run should re-check.
- For each newly shipped id, add a smoke check to `docs/smoke-tests.md`'s late-cast ignore list
  section (after SM-DR-IL7, the toy hearthstone case), plus its *Pending sign-off* note. A run that
  ships nothing new adds none.

### Stage

`defaults/Hearthstones.lua`, `tools/seeds/rulings.json`, `docs/seed-research/<date>-retail`, plus
any test, smoke, doc or citation edits. Commit message:
`Seeds (retail): re-validated against <build> (<date>)`.

## Gate

```sh
~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
python3 -m pytest -q -p no:cacheprovider tools/seeds
```

luacheck must report 0 warnings and 0 errors, and every suite 0 failed. DPS Race is Retail only, so
the headless suite runs under the default kit profile alone (`clients-§6` asks for both profiles
only of a `Retail · Forever` addon).

## Notes

- **The dummy catalog has no DB2 to check against.** The client's `Creature` table holds only the
  creatures the client needs data for: 23167 rows on 12.1.5.70783 (ids 3 to 276385). None of the
  catalog's 42 ids is among them, on that build or on 12.1.5.70575. A training dummy's name reaches
  the client from the server, so no DB2 table names it, and the tool reads no `Creature` table.
  The catalog stays measured: a row is added from `/dr targetdummy add` or `/dr target`, never from
  a DB2. Re-check if a later build's `Creature` export starts carrying the dummies.
- **Bundle size.** A bundle's `raw/` is about 12 MB, most of it `SpellEffect` (7 MB gzipped).
- **A ruling outlives its candidate.** After `apply`, an accepted id stops being proposed. Its
  ruling stays in the file as provenance, and that is not an error.
- **The shared helper.** Whether the build pin, the cache, the bundle and the rulings move into a
  shared helper is LibKa0s#91. Until it decides, the tool copies Aura Master's patterns and imports
  nothing across repos.
