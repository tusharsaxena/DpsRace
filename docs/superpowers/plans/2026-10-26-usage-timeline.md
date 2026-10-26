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

## Design (binding for P3 to P6; decided 2026-10-26 from the findings)

### Capture: `modules/Casts.lua` (`NS.Casts`)

- **Source:** `UNIT_SPELLCAST_SUCCEEDED` for units `player` and `pet`, from **ARMED** through STOPPING (the
  existing late-cast path in `Race.OnCast` / `modules/Watchers.lua` keeps its own behavior; casts are routed to
  `Casts` in addition). `UNIT_SPELLCAST_CHANNEL_START` / `_STOP` for `player` only feed a dedupe: a SUCCEEDED for the
  spell of an open channel is ignored until its CHANNEL_STOP.
- **Filter:** the spell ID through `Secrets.PlainNumber` (a non-plain ID is dropped and counted in
  `run.casts.dropped`); auto-repeat attacks dropped (`Casts.AUTO = { [75] Auto Shot, [6603] Auto Attack, [5019]
  Shoot }`); a castGUID heard twice is counted once.
- **Time:** each cast's `GetTime()`; stored as seconds from the race clock's start (`t`, negative for a pre-pull cast
  heard while ARMED), rounded to 0.01 s.
- **Base cooldown:** the first time a spell ID is seen, `GetSpellBaseCooldown(id)` through `Secrets.PlainNumber`
  (ms, plain in combat per the probe); kept per spell.
- **Stored:** `run.casts = { v = 1, list = "<cs>:<id>,<cs>:p<id>,...", spells = { [id] = cdMs }, dropped = n }`,
  where `<cs>` is `t` in integer centiseconds and a `p` marks a pet cast. `Casts.Encode` / `Casts.Decode` (pure)
  turn the list into `{ { t = seconds, id = n, pet = bool }, ... }`. No cap on the list (the owner's call).
- **Important:** `Casts.IMPORTANT_MS = 15000`; an important cast is one whose spell's base cooldown is **more than**
  15 s. `Casts.Important(run)` answers the decoded important casts.
- **Live:** `Casts.Live()` answers the current race's in-memory list (same shape as Decode) for the HUD chart.

### Usage: `modules/Usage.lua` (`NS.Usage`)

- **Snapshot at ARMED** (out of combat, everything plain): equipped slots 1-19 whose item has a use spell
  (`GetInventoryItemID`, `C_Item.GetItemSpell`); bag consumables (`C_Container`, bags 0-5, `C_Item.GetItemInfoInstant`
  class 0) with their total count, subclass and use spell; the helpful auras' spell IDs and names
  (`C_UnitAuras.GetAuraDataByIndex(..., "HELPFUL")`); the weapon enchants (`GetWeaponEnchantInfo`). Held in memory on
  the race until the result.
- **After the result** (the record path, out of combat): bag counts again.
- **Detection** (in order; each entry records its source):
  - a cast whose spell is an on-use slot's spell -> that gear item used at each cast's `t` (`src = "cast"`);
  - a cast whose spell is a bag consumable's spell -> that item used at each `t` (`src = "cast"`);
  - a bag consumable whose count dropped with no matching cast -> used `n` times, time unknown (`src = "bag"`);
  - an aura at the arm whose spell ID equals a bag consumable's spell (a flask or phial) -> used, active at the
    start (`src = "buff"`);
  - an aura at the arm named `L["Well Fed"]` -> a food entry with no item, active at the start (`src = "buff"`);
  - an active weapon enchant -> an enchant entry with its enchant ID, no item (`src = "enchant"`).
  - The item-cooldown compare is NOT used (false positives, per the probe).
- **Kinds:** `gear`, `potion` (subclass 1), `flask` (subclasses 2 and 3), `food` (5), `other` (8, 0 and the rest),
  `enchant`.
- **Stored:** `run.usage = { v = 1, used = { { itemID?, kind, slot?, times = { t, ... }?, n, src, enchantID? } },
  candidates = { { itemID, kind, slot? } }, edited = bool }`. Candidates are every on-use gear item and every bag
  consumable with a use spell, at the arm.
- **Edit:** `Usage.SetUsed(run, list)` replaces `used` with the player's ticks (an untouched detected entry keeps its
  times and source; a newly ticked one is `src = "manual"`, `n = 1`, no time), sets `edited = true`, and fires
  `RUNS_CHANGED`. On the sample history it changes the sample in memory only (as notes do).

### Record format

- `Recorder.RUN_SCHEMA` 3; a schema step 2 -> 3 that only raises `global.schema` (no stored run is rewritten). A run
  without `casts` / `usage` reads as *Not recorded*. Only plain values are stored.
- `modules/MockRuns.lua` / the sim carry sample casts and usage, so `/dr test` and `/dr sim` show every new view.

### #13 UI

- **Runs table column** `used` (*Used*), before *Note*: up to as many item icons as fit (gear first, then
  consumables), then *+n*; a dash when nothing. Its tooltip lists each entry: name, how many times, and the times
  (`m:ss`), *active at the start*, or *time unknown*. Sorted by the number of entries.
- **Results detail** *Usage* section (a FONT.SECTION heading like the others): one row per candidate and per detected
  entry with no candidate (food, enchant): checkbox (clickable label, `Tbl.SetCheckLabel`), icon, name, a dim detail
  (`x2 at 0:09, 1:12`, *active at the start*, *time unknown*), detected ones pre-ticked; *Save* (enabled only when the
  ticks changed) writes `Usage.SetUsed`. *Not recorded* for an older run.

### #14 chart dots

- `Hud_Chart`'s Strip draws a small round gold dot per important cast along the top of the plot at
  `x = INSET + clamp(t, 0, length) / length * (width - 2 * INSET)`: plain geometry only (`t` and `length` plain, the
  width from config). Live on the running HUD (`Casts.Live()`), on the result card and in the Results detail
  (`run.casts`). A new setting `live.castDots` (bool, default on; HUD page, with the chart rows): *Show cooldown dots*.
  In the Results detail a dot's tooltip names the spell and its time.

### #14 timeline window: `modules/Results_Timeline.lua`

- A pop-out window (the Ka0s window skin like the Results window; movable, Escape closes, its position saved under
  `profile.windows.timeline`) titled *Ability timeline*, opened by a *Timeline* button in the Results detail (disabled
  for a run without casts) and redrawn when the detail's run or compare target changes.
- Layout: the mock's version 2: a legend bar (this run's date in gold, the compared run's in blue and what it is:
  best, runner-up or picked), then per ability one name cell (icon, name, its cooldown when over 15 s, *(pet)* for a
  pet ability) beside **two lanes**: the top lane this run's casts (gold dots), the bottom lane the compared run's
  (blue), each lane's cast count at the right, then a time axis (0, quarters, the end). Abilities over 15 s first (by
  cooldown, longest first), then the rest by count. A scroll for many abilities. A dot's tooltip names the spell and
  its time. The compared run is the detail's compare target (`CompareTarget(true)`); with none, or one with no casts,
  its lanes stay empty under a note.

## Steps

### P0: Plan and branch

- [x] This plan, on the branch.

### P1: Pruning by age

- [x] `history.keepDays` (default 90, 0 = never) replaces `history.keep`; `Recorder.Prune` removes resolved runs older
  than that many days, never one holding a best; the History page row; schema, docs, tests.

## Probe findings (measured 2026-10-26, client 12.1.5 build 70575, BM Hunter, open world, one 1:00 race)

- **Casts are plain in combat.** Every `UNIT_SPELLCAST_*` spell ID and castGUID for `player` and `pet` was a plain
  number / string mid-combat (smoke C10 confirmed for the open world; instances were not tested, by the owner's call).
- **SUCCEEDED is the press that went off.** Spamming a key on cooldown fires `FAILED` (Kill Command: 16 SENT/SUCC,
  40 FAIL); `SENT` precedes `SUCC` for player casts and once went unanswered. Count `SUCCEEDED` only.
- **Pet casts arrive as unit `pet`** (Claw, Growl, Tendon Rip) with plain IDs; `IsPlayerSpell` is false for them.
- **Auto Shot (75) fires SUCCEEDED on every shot** (22 in a minute): auto-repeat attacks must be filtered out.
- **No channel was cast**, so the per-tick SUCCEEDED behavior is still unmeasured: dedupe defensively (ignore a
  SUCCEEDED for the spell of an open CHANNEL_START until its CHANNEL_STOP).
- **A pre-pull cast is heard while ARMED** (Wild Thrash SENT/SUCC on the clock's own frame): listen from the arm.
- **`GetSpellBaseCooldown` is plain in and out of combat** (ms): Bestial Wrath 90000, Spatial Rift 180000, Feign Death
  30000, trinket 120000, potion 300000, Wild Thrash 8000, Tendon Rip 10000, Kill Command 500 (charges), Barbed Shot /
  Cobra Shot / Auto Shot 0. "Important" (over 15 s) reads correctly from it. `C_Spell.GetSpellCooldown` is secret in
  combat (as documented).
- **On-use gear:** `C_Item.GetItemSpell` names each slot's use spell (trinket, engineering belt, tabard); the trinket's
  cast SUCCEEDED with exactly that spell ID. Both cooldown readers are plain after combat, but the **cooldown compare
  gives a false positive**: the belt's Nitro Boosts showed a cooldown started when the potion was drunk (shared
  cooldown). Casts are the source of truth; the cooldown delta is not used.
- **Consumables:** bag counts are plain after combat (Potion of Recklessness 146 -> 145); the potion's cast matched its
  item spell. Item class 0 subclasses seen: 1 potion, 3 flask, 8 other (oil, augment-style stones, battle standard),
  0 generic. A flask's buff spell equals its item spell (1235108). Auras are plain at the arm and after combat.
- **Weapon enchant** reads plain at the arm (`GetWeaponEnchantInfo`: enchant id 8051); the enchant id does not map to
  the oil item, so it is listed as a weapon enchant and the player ticks the oil.
- **No food buff or augment rune was active**, so their detection stays a rule (the *Well Fed* aura name) to verify in
  the build's smoke rows.

### P2: The probe (debug-only; reverted after the findings)

- [x] `modules/UsageProbe.lua`, active only while debug logging is on. At arm: the equipped slots with a use
  (`GetInventoryItemID`, `C_Item.GetItemSpell`), the bag consumables (`C_Container`, `C_Item.GetItemInfoInstant`
  class/subclass, `GetItemSpell`, counts), the player's helpful auras, `GetWeaponEnchantInfo`, each value's kind. During
  the race: every `UNIT_SPELLCAST_*` for `player` and `pet` (event, spell ID kind, name, castGUID kind, time), matched
  against the arm maps; channel start/stop vs SUCCEEDED ticks; `GetSpellBaseCooldown` per new spell (kind and value)
  and `IsPlayerSpell` / `IsSpellKnownOrOverridesKnown`. After the result: bag counts and item cooldowns again (kinds and
  deltas), auras again. A summary at the end.
- [x] Pushed; the owner runs it (one race with a trinket and a potion; one with a channel and a pet), copies the
  console.
- [x] Findings recorded here and in memory; probe reverted.

### P3: Capture

- [x] `modules/Casts.lua` (pure): the cast list per race (time, spell ID), channel-tick and hidden-spell filtering,
  compact encoding, important-ability selection (base cooldown over 15 s), grouping.
- [x] `modules/Usage.lua`: the arm snapshot, matching casts, the after-combat deltas, the candidate list.
- [x] `Race.OnCast` / Watchers route casts (player and pet) from ARMED; the run record gains `casts` and `usage`
  (`RUN_SCHEMA` 3, no rewrite of older runs).
- P3 notes: an open channel's FIRST SUCCEEDED counts (the rest until CHANNEL_STOP are ticks), so a channel whose
  SUCCEEDED follows its CHANNEL_START is still recorded once; a SUCCEEDED heard on the CHANNEL_START's own frame
  counts as that first one. A run resumed after a `/reload` stores neither list (both are in memory until the
  result). The armed set registers SUCCEEDED (`player`, `pet`) and the player's CHANNEL_START / _STOP; START,
  EMPOWER_START and INTERRUPTED join from RUNNING, as before. `Casts.Group`, `Casts.Live` / `LiveSpells` and
  `ResultsSource.Touched` (a sample run's usage edit) are in place for P4 to P6.

### P4: #13 UI

- [x] Runs table *Used* column (icons, *+n*, tooltip).
- [x] Results detail: the usage list (pre-ticked, editable, Save).
- P4 notes: the column (`used`, 70 px: four 16 px icons, or three and *+n*) raised the window minimums
  to 904 collapsed and 1264 expanded (from 834 and 1198); the defaults (980, 1340) still clear them. A
  cell tooltip is no longer cut at eight lines (a run may list more entries). The *Usage* section sits
  under *Talents*; its pure parts and its rows live in `modules/Results_Usage.lua`, its tooltips in
  `Results_Tips` (`CELL.used`, `Tips.Usage`). `Tbl.SetCheckLabel` takes an `extra` width so the icon
  between the box and the name is clickable too. Food and a weapon enchant have no item: their icons
  are Well Fed's (`Spell_Misc_Food`) and the enchanting trade's (`Trade_Engraving`). The detail now
  keeps its scroll when the same run is redrawn (a Save, a note, a store change), so Save does not jump
  the pane to the top.
- [x] P4 review fixes: `Usage.SetUsed` matches each tick to its own detected entry (by slot too, never one
  entry twice), so the same oil on both hands or a pair of one on-use item stay two entries. An unticked
  food or weapon enchant joins `candidates` with no item (`{ kind, slot?, enchantID? }`), so its row
  stays and the untick can be undone; ticked again it keeps the source it was detected with (`buff`,
  `enchant`) rather than `manual`, since only detection ever lists one (a deviation from "a newly
  ticked one is manual", in its spirit). A same-run redraw keeps the ticks not saved yet; a time that
  rounds to the pull reads 0:00, not -0:00.

### P5: #14 chart dots

- [x] Dots for important abilities on the live chart, the result card and the Results detail.
- P5 notes: the view carries `dots` (`Chart.DotsOf(run)` after the race, `Casts.Filter(Casts.Live(),
  Casts.LiveSpells())` live, re-read only when `Casts.Size()` or the run changed); `Strip:drawDots` lays
  them again only when the list, its size, the length or the geometry changed. The disc is the client's
  round portrait mask tinted gold, 6 px, centered `INSET + 3` px under the plot's top. The Results
  detail's dots get a pooled 10 px hover frame each (`Strip:SetDotTip`; `ResultsTips.Dot`: the spell,
  *(pet)* for a pet's, and *Cast at m:ss*); the HUD's take no mouse. *Show cooldown dots* hides them in
  the Results detail as well as on the HUD (the design names only the HUD page for the row; the chart
  itself shows in the detail whatever *Show damage chart* says), and its change refreshes both windows.
  `/dr test` draws the sample run's dots (live up to the still moment).

### P6: #14 timeline window

- [x] The pop-out window from the Results detail: two lanes per ability, this run vs best or picked, counts, tooltips.
- P6 notes: `modules/Results_Timeline.lua` (`NS.ResultsTimeline`); its pure parts are `Rows`, `Span`, `Ticks`,
  `DotX`, `CooldownText`, `Name` and `Legend`. The *Timeline* button (72 px) sits after *Share* in the
  detail's bottom row, clear of *Delete* on the 360 px pane; its tooltip says why when it is grayed (a run
  with no casts list, or an empty one). The detail tells the window on every draw and every compare change
  (`DetailChanged`), and the window reads `CompareTarget(true)`, so the compare toggle itself changes
  nothing. Beyond the design: the window is resizable as well as movable (`windows.timeline` keeps its
  size too, default 860 x 480, minimum 600 x 240) and General > *Reset position* resets it; it closes with
  the Results window; the axis runs to the longer of the two races (a picked run may be on another board);
  a row's cooldown is this run's, else the compared run's (for an ability only that run cast); the rest
  order by this run's count, then the compared run's, the player's before the pet's; a dot's tooltip adds
  a third line naming its run, and a name's hover shows the client's spell tooltip with the cooldown and
  both counts (`ResultsTips.TimelineRow`). With no compared run the blue lanes carry no count. The axis is
  pinned under the scrolling lanes, the quarter lines drawn once over the whole content. No run in the
  detail reads *Select a run in the Results window to see its timeline.*; a run with no casts *No casts
  recorded for this run.*

### P7: Docs, smoke rows, inventory

- [x] ARCHITECTURE, data-flow, schema, module map, known limitations, smoke rows, test inventory and README badge.
- P7 notes: also scope.md (the new *What it does* bullet, *Days to keep* in place of *Runs to keep*,
  two *not done* rows: the item-cooldown compare and naming a weapon enchant's oil), settings-panel.md
  (*Reset position* and Master scale reach the timeline), debug.md (the `Casts` and `Timeline` tags)
  and testing.md (the five new suites). One test was added so the hub's frame-layering claim holds:
  `test_layers` pins the ability timeline at HIGH, toplevel and clamped (734 cases). The README's
  stale cleave target-count sentence (the count was removed on 2026-10-26) and *it keeps every run*
  were corrected with the usage paragraph. Smoke row SM-DR-UT22 (new) checks *Days to keep*; UT1 now
  also checks the `[Casts]` debug line.

### P9: The owner's first test round (2026-10-26)

- [x] **Timeline window:** casts as thin vertical ticks (the lane's full height; gold this run, blue the compared
  run) instead of dots; an ability's cooldown as a small gray line under its name, not beside the lanes; the window
  narrowed to fit.
- [x] **Chart marks:** the important casts on the damage chart (live, result card, detail) as small ability icons
  along the top of the plot, a second row when two would overlap, with a tooltip (spell and time) instead of dots.
- [x] **Gear header:** the run's item level as light-gray subtext right after the *Gear* heading.
- [ ] **Usage:**
  - no weapon enchants (or any enchant) unless the enchant has an on-use effect;
  - the section shows only what was used; an *Edit* button next to *Save* switches to every candidate with ticks,
    and *Save* keeps the edit;
  - a hidden-items list (item IDs; a settings row, and *Never show this item* on a right-click in edit mode) whose
    items never appear in the section, the *Used* column or its tooltip;
  - the *Used* column's tooltip shows each item's icon.
- [ ] **Tooltips:** every multi-line tooltip the addon draws itself puts each line after the title on a bullet
  (the vendored LibKa0s settings tooltips keep their format).
- [ ] **Compare vs best:** *This run* right-aligned, *Best run* (renamed from *Best*) left-aligned, the headers aligned
  with their columns; one bar per row, in the column of whichever run is higher, growing outward from the edge the two
  columns share, its length that row's difference against the table's largest, muted green when this run is higher
  and muted red when the compared run is; in the score table and the spell rows.

### P8: Finalize (only on the owner's go-ahead)

- [ ] Merge, push, close #13 and #14, delete this run's branches, stashes and worktrees.
