# Ka0s DPS Race — Known Limitations

What the addon cannot do, or does only approximately, and why. Split out of
[ARCHITECTURE.md](ARCHITECTURE.md) when the section passed ~60 lines (documentation-§3, Tier 2);
the hub keeps a short summary. Each entry names the client limit or the owner's decision behind it,
and the smoke row that measures it where one exists.

- **Auto-show and auto-arm see only known training dummies** (#16, `modules/AutoArm.lua`). A
  dummy is a creature ID in `defaults/Dummies.lua` or on the profile's own list (`race.dummies`, #9);
  one on neither opens the HUD nor arms until the player adds it (`/dr targetdummy add`). With enemy nameplates off no `NAME_PLATE_UNIT_ADDED`
  fires, so auto-show sees only the target. A nameplate that comes up in combat may carry a secret
  GUID and is not counted then; the hide's fire scans the nameplates again before it closes the
  window. Neither rule acts in an instance (a dungeon, raid, scenario, battleground or arena; the
  owner's stand-down rule on the issue): there a race is armed by hand. Auto-arm arms only on a
  target change: a race that ended with the dummy still targeted is armed again by retargeting it
  or by Arm Race. Auto-show decides on a dummy event (a target change, a nameplate, the race's idle
  edge): when test mode closes the window it opened beside a dummy, the window comes back on the next
  such event, not on its own (smoke rows SM-DR-TA1 to SM-DR-TA8, SM-DR-TA24 to SM-DR-TA28).
- **The late-cast ignore list judges by spell ID, from a static hearthstone table** (#8,
  `modules/LateIgnore.lua`).
  - The hearthstone variants are a table per patch (`defaults/Hearthstones.lua`, built from the
    12.1.5.70575 DB2 exports): a toy hearthstone added by a later patch flags a run until the table is
    refreshed ([common-tasks.md](common-tasks.md#refresh-the-hearthstone-list)), or until the player
    adds its spell ID.
  - A late cast stored with no spell ID (its ID arrived sealed) is never ignored: there is nothing to
    match it against, so it always counts.
  - Automatic follow-up spells are not special-cased. Disengage End (199558) is recorded as a late
    cast of its own after a late Disengage, and the player adds it to the list if they want it
    ignored.
  - A typed name resolves only to a spell the logged-in character knows (the client's own name lookup),
    a spell a stored run cast late, one of the six defaults, or a hearthstone's name. Any other spell is
    added by its spell ID or a shift-clicked link. A name two spells share (in the candidates) asks for
    the ID.
  - The list is per profile, and pruning is account-wide. A run that holds a best only on the
    clean-only board under one profile's list is not protected under another's, so a login on that
    profile can prune it. The all-runs board, which protects every board's best, does not depend on
    the list.
- **Your own training dummies are read by creature ID, now** (#9, `modules/DummyList.lua`).
  - A stored run's category is the list's as it is now (`Dummies.CategoryOf`), so switching a built-in
    off, removing a custom dummy or switching profiles moves its past runs to *Other* (and to another
    board) in Results, Insights, the bests and the share line, and adding one moves them back. A run
    whose creature ID arrived sealed keeps the category it recorded.
  - A built-in cannot be recategorized: the list only switches it off or on. A custom entry for a
    built-in ID is dropped from the stored text.
  - The sample runs (test mode, the sim) name the built-ins, so with one switched off its sample runs
    read as *Other* too.
  - Auto-arm arms only on a target change: after adding the creature already targeted, retarget it
    (or press Arm Race). A list change rescans the nameplates for auto-show at once.
  - *Automatic* infers the category from English name words (Cleave, Dungeoneer, PvP) and a boss
    classification or skull level; on another client language, or for a dummy whose name says
    nothing, it reads as Single target unless a category is typed.
  - The list is per profile, the captures are account-wide; a capture records what the game said
    then, and a field that arrived sealed is left out.
- **Lowering *Days to keep* deletes nothing on the spot.** The prune runs at login and after each
  saved run (spec §7), so a slip of the slider costs nothing until the next race.
- **The Results window's Runs view is the saved one, else the stock one.** Its filters, grouping
  and sort open on what *Save* stored in the profile (`profile.views.runs`), else on *Current
  character*, *All specs*, grouped *Full* (character, class, spec, target and time) and newest first; *Reset* deletes the saved view and
  *Clear* returns to it. They are view state, not settings: no schema row, and the profile reset
  takes them with the profile. The Insights tab keeps its own the same way (`profile.views.insights`),
  opening on every character, spec, target, length and date when none is saved.
- **The live breakdown can never show percentages or sort** (spec §6.1): both are arithmetic on
  secret values. This is a client limit, not a gap to close.
- **Unmeasured client behavior** is tracked as the spec's open items O1 to O7 (spec §12) and the
  client assumptions C1 to C26, and closes in the owner's smoke-test pass
  ([smoke-tests.md](smoke-tests.md), section 9). Live DPS, for one, is a rung chain in
  `Meter.ReadLive` (the source's `amountPerSecond`, else the player's own `combatSources` row, else
  the Dps meter type); the live client measured on 2026-10-23 lacks the first, and a client with no
  rung answering shows a dash for the whole race (C3).
- **With both the castGUID and the spell ID sealed, an instant pressed while another cast is in
  flight** (and no interrupt was heard) is taken as that cast finishing, and is not judged. Casting
  normally interrupts the cast in flight, so this is rare (`Race.OnCast`).
- **A `/reload` loses the run's in-memory timeline.** The tail and the restart check resume from
  `race.lastDamage`, the last update heard before the reload; a restart already heard is already on
  the run. A running run resumed out of combat before its buzzer takes the resume time as its end,
  an upper bound, because the real combat edge was missed.
- **A run's loadout is what was worn when combat ended** (#6). Gear and talents cannot change in
  combat, but a weapon can be swapped in it; the record holds the weapon at the combat end. The
  loadout's name is the player's last saved loadout for the spec, else the active config's (which
  may be generic); that the first is the one the player sees is a smoke row (SM-DR-LO4).
- **A stored talent string opens only on a client with its serialization version.** After a patch
  that changes it, *View* (which opens the tree and posts its link to chat) is grayed with a tooltip saying so; *Copy* still hands out the string, and
  the gear grid is unaffected. Talents are compared only as a *Different loadout* marker, never
  node by node (the owner's call, 2026-10-25).
- **There is no target count.** A count the player types added nothing, so it was removed
  (2026-10-26), and none of the client's signals can count the dummies hit: the meter merges same-type
  dummies into one row and the cleave group's nameplates are linked. It returns only if it can be
  measured ([DpsRace#15](https://github.com/tusharsaxena/DpsRace/issues/15)).
- **A pull that carries on the last fight's session is netted, not separated.** When the meter
  makes no new session for a race (the last fight's DoTs kept its session open), the run is flagged
  `sharedSession` and what that session held at the arm is taken off the total and each spell. DoT
  ticks that land between the arm and the pull still count, and a run with no arm-time read (it
  failed, or the pull carried on an older session than the newest) keeps the whole total, which its
  flag says.
- **The HUD's minimum height is set at the default look.** A taller *Row height*, or larger clock or
  figure fonts, leave fewer spell rows at the minimum height; the window can be made taller.
- **The damage chart is this session's only** (#2). Its buckets hold the live totals read in
  combat, which stay secret, and the client writes a secret to SavedVariables as `nil` (the reload
  probe, 2026-10-25). So a run raced before the last `/reload` or login shows no chart on the
  result card or in the Results detail, and a race run with the HUD closed captured none. A bucket
  is filled by the HUD's first read at or after its boundary; one noticed more than a second late
  stays empty.
- **The chart and the pace bar compare by eye only** (#3). A secret cannot be compared, so neither
  says ahead or behind, and the pace is the best's *average* (its damage spread evenly over its
  length): the best has no stored curve, so an opener-heavy best looks easy early on.
- **The compare's picked run lasts the session** (#7). *Compare With This Run* is view state, never
  stored: a `/reload` or login returns every run's compare to its board's best (the runner-up for
  the best itself). A run alone on its board has nothing to compare with until one is picked.
- **The share's talents link may need a second message** (#6). With *Include talents link* on, the
  link follows the score line as its own message when both do not fit in 255 bytes; a link longer
  than 255 bytes on its own is dropped rather than cut.
- **The Results window steps aside while the talent tree is open** (B4.1). It is an on-demand
  browser at `HIGH` (frame-layering-§1, standalone-windows), and Blizzard's `PlayerSpellsFrame` is a
  `MEDIUM` UI panel, so the tree cannot draw over it, and a runtime strata switch is forbidden
  (frame-layering-§4). So the window hides while the tree is up, the parts the tree does not cover
  included, and comes back when the tree closes (the owner's call, 2026-10-25, over a deviation that
  would put the window at `MEDIUM`). Escape with the tree up closes both at once, and the HUD (in
  `UISpecialFrames` too) is closed by the tree's open as before.
- ***Stop Now* in combat waits for combat to end** (Round C). Every meter value is secret in combat,
  so the result cannot be read there; the press waives the 2.5 s of quiet after the combat end, not
  the combat end itself, so damage dealt between the press and the combat end counts (the tooltip says
  so). Damage that lands after the read (a DoT still ticking out of combat) is not counted.
- **Casts were measured plain in the open world only** (#14; the probe of 2026-10-26, a Beast
  Mastery Hunter on client 12.1.5). The client documents the cast events as secret only for units
  other than the player and the pet, and instances were not tested (the owner's call). A spell ID that
  arrives sealed is dropped and counted in `run.casts.dropped`, so that cast is missing from the
  cooldown icons and the timeline, and an item it used falls back to the bag count (smoke rows C10,
  SM-DR-UT1).
- **A channel's ticks are deduped defensively.** No channel was cast in the probe, so whether every
  tick fires `UNIT_SPELLCAST_SUCCEEDED` is unmeasured. While a player channel is open (its
  `CHANNEL_START` to its `CHANNEL_STOP`) only its first success counts; a pet's channel is not deduped,
  as only the player's channel edges are heard (`Casts.Hear`; smoke row SM-DR-UT3).
- **An ability is *important* by its base cooldown** (`GetSpellBaseCooldown`, 29 s or more). Talents
  and haste that shorten it are not seen, and a spell with charges can report a short one (Kill
  Command read 500 ms in the probe), so it gets no cooldown icon and sorts with the rotation on the timeline.
- **A cast more than 10 s before the pull is not the race's** (#13, #14; `Casts.PREPULL`). While
  armed every cast is heard, but when the clock starts only the last 10 s are kept: an earlier one is
  in neither the cast list, the chart's icons, the timeline nor the usage, and the player's earlier
  casts of a consumable's spell explain its bag count's drop, so a potion drunk minutes before the
  pull is not read as used. A pre-pull opener cast 11 s out is dropped with it.
- **A consumable that leaves the bags while armed reads as used, its time unknown** (#13). The bag
  compare sees only the count at the arm and at the result, so a consumable sold, destroyed, traded or
  moved to the bank (or the warband bank) between the two, with no cast of its spell heard, is listed
  with `src = "bag"` and no time. The player unticks it in the detail's *Usage*.
- **Two copies of one on-use item: only the first slot's use is detected** (#13). The cast of the use
  spell names no slot, so a pair of one trinket (one item ID, one spell) counts every cast on the
  first of the two slots (slot order); the second slot's row stays unticked. The player ticks it in
  the detail's *Usage*, and each slot's row is then its own.
- **Food is detected only on an English client** (#13). The *Well Fed* aura is found by its name, the
  enUS string (`L["Well Fed"]`, which the aura's localized name never equals on another client
  language), so on a German, French or any other non-English client food is never detected, and the
  detail's *Usage* has no *Well Fed* row to tick for it.
- **Food and augment runes are detected by rule, not by measurement** (#13). No food buff or rune
  was active in the probe. Food is the *Well Fed* aura found by its name at the arm (the enUS
  string, `L["Well Fed"]`), listed with no item; a rune or any other consumable counts only through a
  cast of its use spell or a bag count that dropped. A flask or phial is matched by its buff's spell
  ID against a bag consumable's use spell, so one whose last copy was drunk (none left in the bags at
  the arm) is not found. Smoke row SM-DR-UT2.
- **A weapon oil is not listed** (#13; the owner's call, 2026-10-26). An oil has no on-use, and
  `GetWeaponEnchantInfo` gives an enchant ID that maps to no item, so no enchant is read at the arm; a
  run stored before then that recorded one never shows it. An oil still in the bags is a candidate
  (a consumable with a use spell): the player can tick it in the detail's *Usage* edit. A consumable
  used with no cast heard is listed from its bag count with no time, and one used and then restocked
  before the result reads no drop.
- **A hidden item is hidden on every run** (P9). The hidden list (History > *Usage*) is one
  account-wide set of item IDs, not per run or per character, and it hides by item: food (*Well Fed*,
  no item) cannot be hidden. A hidden item a run used stays in its record, so it is back on every run
  once taken off the list.
- **Runs raced before format 3 have no casts and no usage**, and neither does a run resumed after a
  `/reload` or a stand-down (both lists are held in memory until the result). Their *Used* cell is a
  dash (its tooltip *Not recorded*), their *Usage* section says *Not recorded*, their chart draws no
  cooldown icons and their *Timeline* button is grayed. Stored runs are never rewritten
  ([schema.md](schema.md), migration 2 → 3).
- **A board's first run never toasts, and the toast judges the all-runs board** (#5, the owner's call
  on the issue, 2026-10-25). A first run is a new best with nothing to beat, so it gets the result
  card's *New best* chip but no toast. A flagged run that beats the best still toasts (flags inform,
  never void), its flags on the toast's last line; the clean-only board is not consulted. The sim's
  results do not toast either: only a real `RACE_RESULT` does, and test mode shows its sample instead.
- **The toast is LibKa0s-Toast-1.0 vendored alone, ahead of the rest of LibKa0s** (a documented
  deviation in [ARCHITECTURE.md](ARCHITECTURE.md#documented-deviations), until the next full
  re-vendor). On v1.77.0's Core it wears Core's own window skin and close mark, not a skin owner's;
  the diagnostics report's library header does not list the Toast module until the re-vendor
  (smoke rows SM-DR-TA17 to SM-DR-TA23).
- **The gear view's stats are the ones read at the arm** (#17). They are what the character sheet said
  when the race was armed, with whatever buffs were up then (a flask, a food buff, a temporary proc);
  a buff gained or lost between the arm and the pull, or a gear change before the pull (the gear is
  re-read at the combat end, the stats are not), is not seen. A run stored before format 4 has no stats
  and the view shows dashes; stored runs are never rewritten (migration 4 → 5). A value the client
  could not read, or that arrived secret, is absent and shows as a dash.
- **The gear view shows an enchant and gems, not empty sockets** (#17). A stored item link names the
  enchant and the gems in the item, but not how many sockets it has, so an empty socket has no mark.
  The marks come from the link's IDs; the enchant's name and the gems' stats are in the item tooltip.
- **No exact cutoff at the buzzer.** Damage that lands after it counts, because meter values captured
  in combat stay secret (spec §2, §5.1).
- **The ability timeline does not scroll sideways on a tilt wheel or a touchpad's sideways swipe**
  (UT-P15, checked 2026-10-27). The client gives addons one wheel script, `OnMouseWheel(self, delta)`,
  whose delta is up (1) or down (-1) only; no script, event or binding reports a horizontal wheel
  (warcraft.wiki.gg's widget script handlers list none). Shift+wheel, the scroll arrows and the
  scrollbar move the zoomed timeline left and right instead (the `?` after the arrows lists the mouse
  controls, Ctrl+wheel's zoom too).
- **The timeline's corridor colors are not a setting** (UT-P16, the owner's call, 2026-10-28). They
  live in `ResultsTimeline.CORRIDOR` and a `/run` change to it lasts the session (`Repaint()` shows it
  on an open window); a `/reload` goes back to the defaults.
