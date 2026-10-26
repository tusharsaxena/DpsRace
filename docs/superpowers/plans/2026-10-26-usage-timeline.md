# 2026-10-26: Trinket and consumable usage (#13), the ability timeline (#14), pruning by age

Branch `feat/2026-10-26-usage-timeline`, from master `6f5b349`. Feasibility: the two research reports of
2026-10-26 (summarized under Findings). Mock of the timeline window:
https://claude.ai/artifact/4LKBGQSAq2ZqAFeb3eLJ6o (version 2, the owner's pick).

**Gate per commit:** `lua tests/run.lua` and `luacheck .` (0/0), each through
`~/.claude/dev-copilot/bin/ka0s-bounded`. Gate on the exit code. Every touched function stays at CCN 15 or below.

**Checkpoints:** each step is one or more commits, and its box is ticked in the step's last commit. A fresh session
resumes at the first open box. The branch is pushed after each milestone and never merged without the owner's
go-ahead. After the merge: delete every branch, stash and worktree this run created.

## Decisions (the owner, 2026-10-26)

- **Probe first, then build.** A debug-only probe settles the open client questions; the build follows its findings.
  The probe is the earlier target probes' pattern (a module that writes to the debug console under `Probe`), and its
  commits are reverted once the findings are recorded.
- **Pruning by age.** *Runs to keep* (a count) becomes *Days to keep*: default 90, 0 = never. Runs holding a best are
  never pruned. No migration (the owner resets the profile).
- **#13, usage.** Capture everything: on-use gear (trinkets and any slot with a use) and consumables (potions, flasks,
  phials, augment runes, oils, food). Signals stacked: an arm snapshot (gear, bag counts, the player's buffs), the
  player's casts during the race, and the after-combat bag and item-cooldown deltas. The Results detail lists every
  candidate, pre-ticks what was detected, and lets the player edit and save (run data, no setting).
  - **Runs table:** a column of small item icons for what was used (trinkets first), *+n* past what fits; the tooltip
    names each item, how many times and when.
- **#14, the timeline.** Capture every cast (no cap on the list).
  - **Chart (live and after the race):** a dot at each use of an *important* ability, one whose cooldown is over 15 s.
  - **Pop-out window from the Results detail:** every ability on a timeline, two lanes per ability (top: this run,
    gold; bottom: the compared run, best or picked, blue), cast counts at the right, cooldown abilities first.

## Findings carried in (research, not yet measured in game)

- The player's own `UNIT_SPELLCAST_*` payloads are documented secret only for units other than the player and the
  pet (`SecretWhenUnitSpellCastRestricted`); EllesmereUI and Details! rely on plain player spell IDs in 12.1. Smoke
  row C10 is still unrun.
- `SUCCEEDED` fires on every channel tick (EllesmereUI), against smoke row C13's assumption.
- Item cooldowns (`C_Item.GetItemCooldown`, `C_Container.GetItemCooldown`) and container reads carry no `SecretWhen*`
  flag; `C_Spell.GetSpellCooldown` / charges are secret in combat; `C_UnitAuras` getters are secret in combat (arm is
  out of combat, so an arm scan reads plain).
- The meter and the combat log carry no per-event timing: a timeline cannot be inferred from damage.
- `GetSpellBaseCooldown` is not in the generated docs: its secrecy is unknown.
- `modules/Timeline.lua` already exists (the damage-update timeline): the cast store needs another name (`Casts`).

## Steps

### P0: Plan and branch

- [x] This plan, on the branch.

### P1: Pruning by age

- [x] `history.keepDays` (default 90, 0 = never) replaces `history.keep`; `Recorder.Prune` removes resolved runs older
  than that many days, never one holding a best; the History page row; schema, docs, tests.

### P2: The probe (debug-only; reverted after the findings)

- [ ] `modules/UsageProbe.lua`, active only while debug logging is on. At arm: the equipped slots with a use
  (`GetInventoryItemID`, `C_Item.GetItemSpell`), the bag consumables (`C_Container`, `C_Item.GetItemInfoInstant`
  class/subclass, `GetItemSpell`, counts), the player's helpful auras, `GetWeaponEnchantInfo`, each value's kind. During
  the race: every `UNIT_SPELLCAST_*` for `player` and `pet` (event, spell ID kind, name, castGUID kind, time), matched
  against the arm maps; channel start/stop vs SUCCEEDED ticks; `GetSpellBaseCooldown` per new spell (kind and value)
  and `IsPlayerSpell` / `IsSpellKnownOrOverridesKnown`. After the result: bag counts and item cooldowns again (kinds and
  deltas), auras again. A summary at the end.
- [ ] Pushed; the owner runs it (one race with a trinket and a potion; one with a channel and a pet), copies the
  console.
- [ ] Findings recorded here and in memory; probe reverted.

### P3: Capture

- [ ] `modules/Casts.lua` (pure): the cast list per race (time, spell ID), channel-tick and hidden-spell filtering,
  compact encoding, important-ability selection (base cooldown over 15 s), grouping.
- [ ] `modules/Usage.lua`: the arm snapshot, matching casts, the after-combat deltas, the candidate list.
- [ ] `Race.OnCast` / Watchers route casts (player and pet) from ARMED; the run record gains `casts` and `usage`
  (`RUN_SCHEMA` 3, no rewrite of older runs).

### P4: #13 UI

- [ ] Runs table *Used* column (icons, *+n*, tooltip).
- [ ] Results detail: the usage list (pre-ticked, editable, Save).

### P5: #14 chart dots

- [ ] Dots for important abilities on the live chart, the result card and the Results detail.

### P6: #14 timeline window

- [ ] The pop-out window from the Results detail: two lanes per ability, this run vs best or picked, counts, tooltips.

### P7: Docs, smoke rows, inventory

- [ ] ARCHITECTURE, data-flow, schema, module map, known limitations, smoke rows, test inventory and README badge.

### P8: Finalize (only on the owner's go-ahead)

- [ ] Merge, push, close #13 and #14, delete this run's branches, stashes and worktrees.
