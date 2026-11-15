# Analysis — Retail seed validation, 2026-11-15 (build 12.1.5.70783)

The first run of `tools/seeds/seeds.py` (contract: `docs/validate-seeds.md`). It re-derives
`defaults/Hearthstones.lua` from the live Retail build on wago.tools (product `wow`, 12.1.5.70783)
by the four rules in the file's header. The list was last built on 2026-10-28 from 12.1.5.70575,
and that run was not frozen. Every flag the run raised is ruled in `tools/seeds/rulings.json`, and
`RULINGS.md` beside this file lists each ruling with its reason. Claude made the rulings under the
contract's precedent, and they are pending the owner's review.

## Does the tool reproduce the 2026-10-28 list?

Yes, with one exception. Derived against 12.1.5.70575, the header's build, from the same six tables
(a scratch run, not frozen), the rules give 58 ids: the shipped 59 less 1310840, with no
candidates. The live build gives the same 58.

To reproduce the list, the tool reads rule 2 as *every* bind-point teleport. The header adds "that
a toy or an item casts", but three shipped ids have no `ItemEffect` row of their own:

| Id | Name | Who casts it, on 12.1.5.70783 |
| --- | --- | --- |
| `191329` | Hearthstone | no item row casts it |
| `431644` | Stone of the Hearth | no item row casts it |
| `1286909` | Mycomancer's Hearthspore | triggered by 1286908 and 1299014; an item casts 1299014, which ships |

Rule 4 also removes, by id, "the teleports home no item casts". So the 2026-10-28 list was every
bind-point teleport less rule 4's ids, and the tool codes that reading. Every candidate carries a
note of who casts it, so a later teleport with no item behind it is visible at the ruling.

## What changed in the game between the two builds

Nothing that touches the list:

| Check | 12.1.5.70575 | 12.1.5.70783 |
| --- | --- | --- |
| Rule 1 (ChargeCategory 2309) | 44 spells | 44 spells |
| Rule 2 (Effect 252, ImplicitTarget 9) | 63 spells | 63 spells |
| Derived after rules 3 and 4 | 58 | 58, the same ids |
| Shipped ids the build does not name | 1 (`1310840`) | the same 1 |
| Shipped ids whose name disagrees with the comment | 0 | 0 |
| Shipped ids the rules no longer derive (named) | 0 | 0 |
| Sentinel gate (8690, 222695, 171253) | pass | pass |

## What the run proposed

0 candidates and 1 flag.

### The flag: `1310840`, kept pending the owner

`1310840` ships as *Wood-Cursed Hearthstone*. On live 12.1.5.70783 no `SpellName` row has that id,
and none did on 12.1.5.70575. No `SpellName` or `ItemSparse` row on the live build carries the
name. There the id is a `SpellEffect` row id, an effect of *Virulent Fumes* (1291461), and not a
spell id. The Retail PTR, `wowt` 12.1.7.70892, does name it: `1310840,"Wood-Cursed Hearthstone"`.
The likeliest history is that the 2026-10-28 run read `SpellName` without `?build=`, which serves
the PTR (clients-§10), and so picked up a 12.1.7 hearthstone.

Ruled **keep**, `needs owner review`. On the live client no cast carries the id, so the entry is
inert and costs nothing. When 12.1.7 goes live it becomes a real hearthstone the list already has.
Removing it would change the pin test's count (59), and the count in the module map and in SM-DR-IL1's
*(all hearthstones, 59)*, and the next patch would then need the id back. That trade is the
owner's call, not this run's.

## The dummy catalog: not checked, and why

`defaults/Dummies.lua` is measured (its header), so it takes no candidates. The inventory
(Ka0sAddonsCommonTasks#1) expected an existence and name check against `Creature`, but that check
has nothing to read. The client's `Creature` export holds 23167 rows on 12.1.5.70783 (ids 3 to
276385), and **none** of the catalog's 42 ids is among them. The same is true on 12.1.5.70575. The
dummies it does hold are other creatures (Mechanical Training Dummy 80017, Pet Training Dummy
163534, and so on). A training dummy's name reaches the client from the server, so no DB2 names
one. The tool therefore reads no `Creature` table and raises no dummy flags: 42 `unnamed` flags
would only say that the table does not cover them.

## Changes applied

None. `apply` ran twice and changed nothing. `defaults/Hearthstones.lua` gains a hand-written
re-validation line, and its refresh recipe now points at the tool (comments only). The 59 rows, the
pin test and the smoke checks are unchanged.

## What a later run should re-check

- **`1310840` on 12.1.7.** Once the live build names it, the flag stops being raised. If the owner
  removes it first, the rules will propose it again as a candidate once 12.1.7 is live.
- **New bind-point teleports with no item behind them.** These are the case rule 2's item clause
  was meant to keep out. Read the `no item casts it` note and the spell's name, and reject test,
  `[DNT]` and `[PH]` spells, and class spells.
- **Rule 1's charge category.** If 8690 leaves ChargeCategory 2309, the sentinel gate still passes
  on rule 2, but much of the list would turn `unfit`. Read the flags before ruling.
- **`Creature` coverage.** If a later export carries the training dummies, the catalog could gain
  an existence and name check. Today it cannot.
