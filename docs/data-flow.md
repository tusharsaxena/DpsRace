# Data flow

How Ka0s DPS Race works, as pipelines: trigger in, processing, what the player ends up seeing. This
is the engineer counterpart to the README's *How the race works*; the two describe one pipeline at
two levels and must not contradict each other. The race pipeline is summarized from the spec (§4,
§5) and the code that implements it.

## Load and enable

- **File load.** The TOC loads `locales/` → `core/` → `defaults/` → `modules/` → `settings/`. Each
  `core/*Setup.lua` builds its `LibKa0s` instance from a descriptor, or installs its degradation stub
  when the library is absent. Settings pages register their rows and builders; nothing is drawn.
- **`OnInitialize`** (`core/DpsRace.lua`): AceDB (`NS:InitDB`), migrations (`NS:RunMigrations`), the
  stored `enabled` takes or releases the `disabled` hold (`NS.SyncEnabledHold`), the launcher
  registers, the settings category registers eagerly, and `/dr` and `/dpsrace` register.
- **`OnEnable`**: if the latch is down, nothing; otherwise `NS.RegisterGameEvents()` registers the
  combat events the current settings need, `NS.Bests.PruneToSetting()` prunes the store to
  `global.history.keepDays` (0 = never), and `NS.Race.Resume()` carries on the runs a `/reload`
  interrupted (spec §4.5). The stand-up edge calls the same `Resume`.

## A setting changes

- The panel, `/dr set`, the launcher menu or a key binding calls `NS.SetByPath(path, value)`.
- The schema runtime validates, stores (profile or global by the path's first segment, or the row's
  own `set`), runs the row's `onChange`, logs one `[Set]` line, and announces
  `SETTINGS_CHANGED(path, value)` for stored rows.
- A profile switch, copy or reset (`NS.OnProfileChanged`) re-syncs the `disabled` hold, rebuilds the
  event set and announces `SETTINGS_CHANGED("profile", key)`.

## Standing down and up

One latch (`core/LifecycleSetup.lua`, `LibKa0s-Lifecycle-1.0`) with two holds: `disabled` (the
*Enable* row) and `perf` (a capture's suspended arm). The first hold taken runs `standDown`: every
event, message and timer on the addon object is unregistered or canceled, every bus receiver is
dropped, and each feature module's `Suspend` runs. Releasing the last hold runs `standUp`, which
rebuilds from current state rather than from a snapshot. While down, every verb still answers; a
feature handler prints the one refusal line `NS.StoodDownRefusal()` picks (slash-commands-§7).

## Combat edges (the addon object)

`PLAYER_REGEN_DISABLED` → `NS:OnCombatChanged` → test mode ends (and says so once) → the HUD
re-decides whether it can show. `PLAYER_REGEN_ENABLED` is registered only when *General visibility*
depends on combat. The handler is the `combatEvent` perf bucket.

## The race (spec §4 and §5)

`modules/Watchers.lua` turns each client event into one `NS.Race.On*` input with `GetTime()`;
`modules/Race.lua` decides. Every transition sends `RACE_STATE_CHANGED(run, from, to)`.

- **Arm** (`Race.Arm(length, count)`, out of combat only): refused with `busy` (armed or running),
  `pending` (a run is stopping, or a stored run is unresolved), `bad_length`, `in_combat`,
  `meter_unavailable` (with Blizzard's reason) or `disabled`. Otherwise `Recorder.NewRun` snapshots
  the player, target and place and reads the stats onto the run (`Stats.Snapshot`, #17: the primary
  stat, stamina, armor and every rating with its percent, each through `NS.Secrets`, a sealed one
  absent), `Recorder.SnapshotLoadout` reads the gear links and the talent
  loadout into memory as the fallback (#6), `Casts.Begin()` starts the race's cast list and
  `Usage.Snapshot()` reads what could be used into memory (#13, #14; below), the session IDs the client holds are remembered (they belong to
  earlier fights and are never this run's), and nothing is stored yet. Watchers registers the meter,
  combat and death events, and the cast list's: every `UNIT_SPELLCAST_SUCCEEDED` of the player and
  the pet, and the player's channel start and stop (a pre-pull cast is heard while armed). The newest of those IDs is kept on the run as `race.armMaxSession`, so
  a run resumed after a `/reload` (which loses the set) still never adopts an earlier fight's session.
- **Start**: the first `DAMAGE_METER_CURRENT_SESSION_UPDATED` after arming while the player is in
  combat, or with `PLAYER_REGEN_DISABLED` on the same frame in either order (one heard out of
  combat, such as a trailing update from the last fight, leaves the race armed, and a DamageDone
  update heard out of combat is adopted only if the clock starts on its own frame). The clock also
  starts on the first DamageDone `DAMAGE_METER_COMBAT_SESSION_UPDATED` heard in combat (or on the
  regen edge's own frame) while armed: the meter can make the run's session out of combat (a DoT
  left on the dummies, an opener landing a frame before the edge), and then no session event ever
  pairs with the edge (the owner's report, 2026-10-24: a second race stayed armed). A pull that
  carries on a session that existed at the arm is adopted and flagged `sharedSession`. What that
  session held at the arm (read then, out of combat, `race.baseline`) is netted off the total and
  each spell at the read, and the meter's own rate is dropped. A fresh session heard later replaces
  the shared one. The start time is `GetTime()` at that event; `run.date` is restamped, `run.race.startedAt` is the clock's start, and
  the run is written to SavedVariables as `running`; `Casts.Start(t)` makes it the cast list's zero and drops every cast heard more than `Casts.PREPULL` (10) s before it. A `C_Timer.NewTimer` is the
  buzzer. The session ID comes from the first `DAMAGE_METER_COMBAT_SESSION_UPDATED` of type
  DamageDone with a non-zero, plain ID that was not there at arm time. The combat-start edge re-reads
  the target (`Recorder.SnapshotTarget("target", armTimeTarget)`); that read is the one stored. A
  combat that ends while still armed (it never started the clock) clears the re-read, so the combat
  that does start it reads the target again.
  Watchers adds the late-cast judging's own cast events (the player's start, empower start and
  interrupt; the success and the channel edges are registered from the arm, and `Race.OnCast` judges
  them only from here on); an empowered cast is in flight from its start, like any other.
- **Running**: the HUD counts down (`Race.TimeLeft()`) and shows the live breakdown, read through
  `modules/Meter.lua` at the configured rate, with every value opaque. Every DamageDone update for
  the run's session is a stamp on its `Timeline`, and its offset from the start is kept on the run as
  `race.lastDamage` (a resumed run's fresh timeline starts from it). Combat dropping or a death before the buzzer cancels
  the buzzer and records `result.endedAt` (seconds from the start): the run will be `incomplete`.
- **Buzzer** at start + length: the run moves to `stopping` and `RACE_BUZZER(run)` is sent. A cast
  that starts (or an instant that succeeds) later than buzzer + grace is a late cast,
  `{ t = offset, spellID }` on `flags.lateCasts` (`spellID` nil when the event's ID was secret); a
  cast started before the buzzer is never late. One cast is tracked in flight, matched to its own
  success by castGUID (else spell ID, else assumed) and cleared by its interrupt, so a stale start
  never swallows a later instant. An auto-repeat success (Auto Shot, Shoot; with a sealed ID, any
  success while one is repeating) is never a press. A 0.5 s `C_Timer.NewTicker` polls for
  readiness, only in this state; a poll that finds the player out of combat with no regen edge heard
  starts the quiet itself, so a missed edge never leaves a run waiting. The race's combat end (the
  regen edge, out of combat) also re-reads the loadout and stores it on the run through
  `Loadouts.Attach` (deduped in `global.loadouts`, the run holding only the keys): exactly what raced,
  bar a weapon swapped in combat. A later combat end in the wait replaces it.
- **Ready to read**: combat has ended **and** 2.5 s have passed since the later of the combat end and
  the last DamageDone update for the session (updates land up to 1.3 s after combat drops). The
  session is read by its ID through `Meter.ReadSession`, never as "current", into plain numbers. A
  run with no captured ID falls back to the newest session created after the arm and is flagged
  `sessionFromList` (spec §9). A `sharedSession` run is netted against its `race.baseline` here. A
  `sealed` read is retried for 10 s; a missing session, a raise or a
  meter reset makes the run `lost` (kept, with no result). *Stop Now* on the Stop! or waiting screen
  (`Race.StopNow`, Round C) waives the 2.5 s of quiet, never the combat end: out of combat the read
  runs on the press, in combat it runs on the regen edge (nothing is readable before), and a sealed
  read retries on the poll as ever. Damage that lands after the read is not counted. The decision is
  the press, the combat flag and `GetTime()`, never a meter value. A run resolved with no combat-end
  loadout takes the arm-time one; a run resumed after a /reload or a stand-down has neither, and
  takes a fresh snapshot when it resolves out of combat.
- **Result**: DPS is damage ÷ race length (÷ `endedAt` for an incomplete run); `result.tail`,
  `result.combatEnd` and `flags.restartedAt` are measured from the buzzer (the restart is flagged on
  the run the moment its update arrives, so a `/reload` after it keeps it); the cast list and what
  was used are put on the run (below; a lost run gets them too); the run is saved
  (`RUN_SAVED`) and `RACE_RESULT(run)` is sent. Watchers drops every registration. `Race.Cancel()`
  dismisses the card; `Race.Arm` races again.
- **Cancel** before the result discards the run: an armed one was never stored, a running or
  stopping one is deleted from the store (the HUD's *Cancel* on the running, Stop! and waiting
  screens, `/dr cancel`). The cast list goes with it (`Casts.Reset()`, as at the stand-down).
- **Resume** (`OnEnable` and the stand-up): the logged-in character's newest stored `running` or
  `stopping` run is carried on (`Recorder.Pending` holds only this character's runs; another
  character's waits for its own login). Its session gone: `lost`. Running, before its buzzer and in
  combat: running, with the buzzer re-armed for the time left. Running, before its buzzer and out of
  combat (combat dropped while nothing listened): `incomplete`, `endedAt` = the time at the resume,
  read at once. Any run past its buzzer and not yet read (stored `running` or `stopping`): `stopping`
  with `flags.reloaded`, because what was cast during the reload went unseen. Out of combat: read at
  once; in combat: wait for the regen edge. The restart check never measures a gap across the
  loading screen: the first update after the resume counts its quiet from the resume. An older
  unresolved run is settled as `lost`. The
  stand-down (disabled or a perf capture) drops the in-memory race and its timers and keeps the stored
  run, so the stand-up resumes it exactly like a `/reload`.
- **The cast list** (#14, `modules/Casts.lua`): from the arm to the result Watchers hands every cast
  event to `Casts.Hear`, and the player's to `Race.OnCast` as well. Only a success of `player` or
  `pet` is kept: its spell ID through `Secrets.PlainNumber` (a sealed one is dropped and counted), an
  auto-repeat attack skipped (`Casts.AUTO`: Auto Shot, Auto Attack, Shoot), a castGUID heard twice
  counted once, and while a player channel is open (its `CHANNEL_START` to `CHANNEL_STOP`) only that
  channel's first success kept. Each cast is held at its `GetTime()` and measured from the clock's
  start, so one heard while armed is negative; the first cast of a spell asks
  `GetSpellBaseCooldown` once. At the clock's start (and again at the record) only the casts of the
  last `Casts.PREPULL` (10) s before it are kept, so the usage, the chart and the timeline read one
  list; the player's earlier ones are counted by spell (`Casts.Early()`, in memory) for the usage's bag
  compare. The running HUD reads `Casts.Live()` and `LiveSpells()`; at the result `Casts.Record()` is
  stored as `run.casts` (`{ v, list, spells, dropped }`, [schema.md](schema.md)).
- **What was used** (#13, `modules/Usage.lua`): `Usage.Snapshot()` at the arm (out of combat) holds
  the equipped slots with a use spell, the bag consumables with one and their counts, and the helpful
  auras on the race (`cur.usageSnap`). At the result (the record path is out
  of combat) `Usage.Build(snap, Casts.Decode(list), Usage.BagCounts(), Casts.Early())` is stored as `run.usage`
  (a lost run too, at its loss). It detects, in order: a cast of an on-use slot's or a consumable's
  spell (`cast`, at each cast's time), a consumable whose count dropped with no cast (`bag`, time
  unknown; nothing when the bags could not be read whole, and a drop the early casts of its spell
  explain given back first), an aura at the arm that is a bag consumable's own spell (a flask or phial: `buff`)
  or *Well Fed* (food, no item: `buff`). No weapon enchant is read (an oil has no on-use; the owner's
  call, 2026-10-26). The candidates are every on-use item and bag consumable at the arm. The item-cooldown compare
  is not used (a shared cooldown gave the probe a false positive). A run resumed after a `/reload` or
  the stand-down has neither list: both were in memory.

## Bests and pruning (spec §6.2, §7)

- **Bests** are worked out, never stored: `Bests.Compute(runs, opts)` keeps the highest
  `result.dps` per `specID|category|length` board, over `complete` runs only (`cleanOnly` drops
  flagged ones). `Bests.Board(opts)` caches it per session; the cache is dropped on `RUN_SAVED` and
  `RUNS_CHANGED`, so a deleted best promotes the next run for free. `Bests.Delta(run)` compares a run
  with the best on its board before it.
- **The detail's compare** (#7, `modules/Results_Compare.lua`) reads the same cached board:
  `ResultsCompare.Default(run)` is the best on the run's board, or the runner-up on it when the run
  holds the best; a run picked from a Runs row's menu wins while it is stored. Both runs are stored
  records, so `CompareSpells` divides and sorts plain numbers; nothing is stored.
- **The detail's loadout** (#6): `Loadouts.Of(run)` resolves the run's keys into its stored gear set
  and talent loadout; `ResultsLoadout.Fill` draws the grid from the links (the item data from
  `C_Item`, the tooltip from the link itself) and the talents line. While the compare is on it reads
  the other run's the same way and highlights the slots whose link differs, and marks a different
  import string. *View* opens the talent tree through `SetItemRef` with the `talentbuild` link (an accepted taint risk, ARCHITECTURE.md Taint Notes) and also prints the link to the player's own chat window (`NS.Print`), where a click opens the tree again. Nothing is stored.
- **Pruning** (`Recorder.Prune(days, protect, now)`) runs at `OnEnable` and on every `RUN_SAVED`, only when
  `global.history.keepDays` is above 0 (90 by default). It removes every resolved run older than that many days, never one
  holding a best on either board, never a `running` or `stopping` run, never the run that `RUN_SAVED`
  just stored and never the race's current run (the one on the result card), and fires `RUNS_CHANGED`
  once. While stood down the bus receiver is dropped, so nothing prunes. A prune that removed any run,
  `Recorder.Delete` and `Recorder.DeleteAll` then drop every loadout no stored run refers to
  (`Loadouts.Sweep`).

No decision in this pipeline reads a meter value in combat: every transition comes from an event or
`GetTime()` (spec §8, rule 2).

## The Race HUD (spec §6.1)

`modules/Hud.lua` hears the race on its own bus target and draws it; it decides nothing about the
race.

- **Which body**: `RACE_STATE_CHANGED` → `Hud.Refresh()` builds a view from `Race.State()`,
  `Race.Current()` and the race's clock queries: idle, armed, running and result map one to one.
  STOPPING is one state shown in two phases: *Stop!* while the run's last DamageDone stamp
  (`run.race.lastDamage`) is under 2.5 s old, then *Waiting* (for combat to end, or for the read); a
  run that ended before the buzzer waits from the start. The live tail is `lastDamage − length`, the
  time in combat `Race.SinceBuzzer()`. After `race.hintDelay` seconds in combat past the buzzer the
  waiting body names the drop-combat spells `IsPlayerSpell` says the character has. Both phases carry
  *Stop Now* (`Race.StopNow`) and *Cancel* (`Race.Cancel`) across the foot, the same width; after *Stop
  Now* in combat the button grays and the waiting title reads *Reading when combat ends*.
- **Showing**: `IsShown()` = wanted and `NS.MasterVisibilityAllows()`. With `hud.showMode = "onArm"`
  the window opens on arm and on `RACE_RESULT`, and closes again when the race it opened for goes
  back to idle; the player's own Show/Hide/close wins. Closing a result card (the × or Escape)
  dismisses it through `Race.Cancel()`; the run stays stored.
- **The clock**: one `OnUpdate` on the window, only while it is shown and the race RUNNING (20 Hz)
  or STOPPING (4 Hz, `Hud.STOP_TICK`: no clock there), redraws the body (`hudTick`). The stop body
  rebuilds its chips only when the late casts or the grace change, and the sticky-combat hint asks
  `IsPlayerSpell` once per race. The countdown turns amber at 10 s left.
- **The live breakdown**: while shown and RUNNING the HUD's frame holds
  `DAMAGE_METER_COMBAT_SESSION_UPDATED`; an update arms one `C_Timer` for the next free slot at
  `live.hz`, which calls `Meter.ReadLive()` and hands every opaque value to the KPIs and the pooled
  rows (`hudLive`): bars by `SetMinMaxValues(0, maxAmount)` / `SetValue(total)` (the first row's
  total when there is no `maxAmount`), amounts by `Format.Number`, names and icons by `C_Spell`, in
  Blizzard's order, `live.rows` of them, no %. `live.rows` 0 is every spell: as many as fit the
  window are drawn, and the mouse wheel moves a plain offset over the rest (MultiMeters' model: the
  slice is redrawn from the offset, nothing is measured, and the count is the length of the addon's
  own copy of the list). The rows, the clocks and the figures take their look from HUD > HUD
  Appearance (`modules/Hud_Appearance.lua`), restyled once per change, never per read. The live DPS figure is the first rung of `Meter.ReadLive`'s chain to answer (the source's `amountPerSecond`, the local `combatSources` row's, the Dps meter type's), copied opaque; with none, a dash.
- **The damage chart and the pace bar** (#2, #3; `modules/Slices.lua`, `modules/Hud_Chart.lua`):
  every fresh `Meter.ReadLive()` while RUNNING also goes to `Slices.Capture(run, elapsed, total)`,
  with `elapsed` from `GetTime()`. The race has min(60, length) buckets; the first read at or after a
  bucket's boundary copies its `total` handle into it (one noticed more than a second late, or on a
  shared session, leaves it empty). A `C_Timer` at the next boundary forces a read in a quiet
  stretch, and the RUNNING → STOPPING edge at the buzzer makes one last read for the bucket ending
  there. The running body's view (`HudChart.LiveViews`) carries the buckets and the scale: the
  board's best (`Bests.Board()[Bests.Key(run)]`) x 1.15 with its level and pace diagonal, or with no
  best the live total itself; and the pace bar's ends (`HudChart.PaceBounds`), with
  `pace = best.damage x elapsed / best.length` and `m = live.paceRange` (1.1-2.0): `lo = pace x (2 - m)`,
  `hi = max(pace x m, lo + 1)`, its tick fixed in the middle of the bar's configured width (Round C). A
  live total outside the range is the StatusBar's to clamp, empty or full; nothing compares it. Both sit under the *Damage
  profile* heading, the pace bar directly under it and above the plot, and *Spell breakdown* heads the
  rows (Round C; laid out from config by `HudStates.ProfileHeight` and `BREAKDOWN_H`).
  On each live read the columns get `SetMinMaxValues(scale)` / `SetValue(bucket)` and the pace bar
  `SetValue(total)`; on each 20 Hz redraw the pace bar's plain range follows the clock. Both hide on
  `flags.sharedSession`; the pace bar with no best; the chart when it would leave fewer than three
  spell rows (only the plot steps aside: the *Damage profile* heading stays over the pace bar). Nothing is computed from a value. After the race the result card draws the pace bar
  again (`HudChart.ResultPace`), all plain: `SetMinMaxValues(PaceBounds(prev, run.race.length))` and
  `SetValue(run.result.damage)`, where `prev` is `Bests.Before(run)`, the best on the board raced
  before the run (what the delta chip names, so the previous best when the run just became the best).
  It hides when *Show pace bar* is off, on a lost run, on a shared session and with no earlier best.
- **The result card**: plain numbers from the read: damage, DPS, the best delta
  (`Bests.Delta(run)`: *New best +2.4%*, or *−3.2% vs best*), one chip per flag (the full
  `Scoring.Flags` text is its tooltip), the time chip, the spells with their share (as many as *Spell rows shown*, or all of them, wheel-scrolled, at 0), and *New Race*
  (back to the Arm Race screen on the run's length and count), *Details* (`NS.Results.ShowRun`), *Share*
  (`NS.Share.Prompt`) and *Delete*, one row of equal widths (`HudStates.RowWidths`: the card's width
  less a 4 px gap between two, split four ways). *Delete* asks through the Results window's own
  confirmation (`Results.ConfirmDelete`, `DPSRACE_DELETE_RUN`), whose Accept deletes through
  `ResultsSource.Delete` → `Recorder.Delete`; the HUD hears `RUNS_CHANGED`, and once the card's run has
  left the store it dismisses the card (`Race.Cancel()`), going back to the Arm Race screen, open, after
  its own Delete. The card's own Delete is known by the popup's Accept (`ConfirmDelete`'s `onAccept`
  marks the run just before the delete), so a canceled popup leaves a later delete in the Results
  window an outside one. Any other store change (an earlier best deleted) redraws the card, so its
  delta chip, pace bar and diagonal follow the store. Between the chips and the spells, with *Show damage chart* on, the race's chart
  again: `HudChart.ResultView(run)` (through `Slices.Drawable`: scored, not shared, with buckets this
  session). With a best before the run (`Bests.Before(run)`, as the pace bar) `HudChart.WithBest` draws
  that best's faint gray diagonal (one 2px line at 40%) from 0:00 to its damage at the run's length, and the plot's max (the
  columns' too) is max(`result.damage`, that) x 1.15; without one each column is scaled to the plain
  `result.damage`, no diagonal. All plain numbers.
- **The cooldown icons** (#14, *Show cooldown icons*, `live.castDots`): the running chart's view
  carries the race's important casts so far as `cooldowns` (`Casts.Filter(Casts.Live(),
  Casts.LiveSpells())`: a base cooldown of 29 s or more), read again only when `Casts.Size()` or the run
  changed, so the 20 Hz redraw builds nothing. `Strip:drawIcons` lays a pooled 12 px frame with the
  spell's icon (`HudBreakdown.SpellIcon` on the cast's plain ID) along the top of the plot, centered
  at `HudChart.IconX(t, length, width)`: `TimeX` = INSET + clamp(t, 0, length) / length x (width - 2
  x INSET), held half an icon inside either edge. `HudChart.IconRows` drops an icon closer than its
  width to the last one on its row to the first row below with room (`IconY`), on as many rows as
  the plot frame holds (`IconRowCount` on `FrameHeight`: the configured height plus `RESERVE`, one
  icon row on top, so 6 at 80 px and 3 at the 40 px minimum). The columns and the best's diagonal
  scale within the configured height below that reserved row, so one row of icons never covers
  them; the rows past it stack down over the columns as before. A cast
  with no room above sits on the last row, alone as an icon, or with others crowded there as one
  pooled *+n* mark at the first one's x, its hover (`ResultsTips.CastCrowd`) listing each cast and
  its time on bullets, so no cast is dropped. Plain numbers on the configured width and height,
  laid again only when the list, its size, the length or the geometry changed.
  After the race the result card and the Results detail draw `HudChart.CooldownsOf(run)`
  (`Casts.Important` on the stored record). Every icon takes the mouse, on the running HUD too, and
  shows `ResultsTips.Cast` under it (the spell and *Cast at m:ss*). With the setting off no chart
  draws any.
- **The final seconds** (`modules/Countdown.lua`): one `C_Timer` per whole second still ahead (10
  down to 1) is armed when the race runs, from `Race.TimeLeft()`, and all are canceled when it
  leaves RUNNING. Each mark reads its rows as it fires: the cue sound once (`race.countdownCue`, at
  a cue mark 10, 5, 3, 2, 1 or a second of the numbers), then the center-screen number
  (`race.centerCountdown`, within `race.finalCountdown`). A change to any of the three re-arms the
  marks (`Countdown.Refresh`); a resume mid-window shows the number of the moment at once, silently.
  `RACE_BUZZER` raises the raid warning *STOP* and its sound (`race.buzzer`, `modules/Hud.lua`).
  None of it needs the HUD window.
- **Who opened the window**: the player (`Hud.Show`, the toggle) or the addon (an arm or a result
  under `onArm`, and test mode through `Hud.AutoShow`). Only an addon-opened window closes by itself
  when its race goes back to idle, and the stand-down (`Hud.Suspend`) drops it, because
  `Race.Suspend` ends the race without a message and the stand-up must not reopen it.
- **Near a training dummy** (#16, `modules/AutoArm.lua`, both rows off by default): registered on its
  own AceEvent target only while a row is on and the addon stands up. *Auto-show* (`hud.autoShow`):
  `PLAYER_TARGET_CHANGED` and `NAME_PLATE_UNIT_ADDED` / `_REMOVED` keep the set of cataloged dummies'
  plates (`Recorder.DummyOf`: the unit's GUID through `NS.Secrets`, its creature ID looked up in
  `defaults/Dummies.lua`; a secret GUID is no dummy) and the target; while either holds one a dummy
  session runs and `Hud.ShowNearDummy()` opens the window if nothing else wants it. With none left a
  `C_Timer` of `AutoArm.HIDE_DELAY` (3) s is armed (the next dummy cancels it); at its fire the
  nameplates are scanned again (`C_NamePlate.GetNamePlates`) and, still none, the session ends and
  `Hud.HideAwayFromDummy()` closes the window it opened, only while the race is idle (the idle edge on
  `RACE_STATE_CHANGED` asks again). A race going idle leaves that window open. A close by the player
  in a session (`Hud.Closes()` moved) keeps it closed until the session ends. *Auto-arm*
  (`race.autoArm`): a target change to a cataloged dummy, out of combat, the race idle and no test
  mode or sim on, calls `Race.Arm(Hud.ArmLength())` with every refusal it has, silently; the arm opens
  the HUD as a manual arm does. While that run is still ARMED, a target change to anything else (or
  none) calls `Race.Cancel()`; a run leaving ARMED (started, canceled) is no longer the rule's. Neither
  rule acts in an instance (`GetInstanceInfo`'s type other than `none`), and `PLAYER_ENTERING_WORLD`
  re-decides after each loading screen.
- **Arm from the idle body**: the length picked (a preset, or a typed `90`, `1:30`, `3m`; the last
  one is remembered as `race.lastLength`) go to `Race.Arm`; a
  refusal prints `Format.ArmRefusal(reason, detail)`, and the Arm button is grayed with the same line
  while a run is pending, in combat or with the meter unavailable.

## The Results window (spec §6.2)

The window reads stored run records only: every number on one went through `NS.Secrets` on its way
into the store, so sorting, percentages and the timing strip are plain Lua. It holds no game event
or `OnUpdate`; its only timers are the talent tree's step-aside (a one-frame `C_Timer.After(0)`
look after a close-stack close, then a `Results.TREE_POLL` ticker while the tree is up; ARCHITECTURE.md
Taint Notes, B4.1) and, only while its grip is dragged, the one-frame `C_Timer.After(0)` that
coalesces a second size change in a frame (`modules/Sizing.lua`).

- **Resizing** (`modules/Sizing.lua`, [performance.md](performance.md#window-sizing)): while the grip
  is held the window lays out cheaply at most once a frame (the list's `Table:Resize`: columns,
  headers, the rows the new height adds or drops, the scroll range; the detail's `Resize`: its
  scroll frame), from the size `OnSizeChanged` hands it, never a frame read; the release runs the
  full layout once (every row rebound, the detail drawn again) and stores the view's size.
- **Opening**: `NS.ToggleResults` (the key binding, the HUD's Results control), `Results.ShowRun(id)`
  (the HUD's *Details*, a Bests row), `Results.EditNote(id)` (a row menu's *Add Note*: the run with its note box focused) or `Results.ShowTab(name)`. `IsShown()` =
  wanted and not stood down; General visibility does not apply to it. Each tab is built the first
  time it shows.
- **The Runs tab**: `Recorder.All()` → `ResultsRuns.Options` fills the six dropdowns from the runs
  present → `ResultsRuns.Filter` keeps the resolved runs (complete, incomplete, lost) that pass the
  bar (*Only best* keeps the runs holding their board's best; *Group* is not a filter but the list's grouping, LootHistory's model: `Table:SetGroup` partitions the sorted runs under folding headers) → `ResultsTable` measures per group (`Table:measure` on every `SetData` and `SetGroup`: the *Delta* column's max DPS and the Damage and DPS bars' range, each the run's own group's under the current *Group by*, the whole list with *None*; nothing is stored on a run), scales the bars linearly from 10% to 100% of that range, sorts them (newest first in the stock view; the tab opens on the saved view, `profile.views.runs`, else the stock one; on DPS an unranked run sorts last; a tie to the newer
  run) and binds the visible slice to pooled rows. A click selects a run; a right-click opens its menu (`Results.RowMenu`: Add Note, Share with the channels as a submenu through `Share.FillMenu`, *Compare With This Run* (`Results.CompareWith`: the session-only pick the detail's compare reads), Delete behind its confirmation).
- **The detail**: `ResultsDetail` draws the selected run: header, score and its *Delta* box, the
  breakdown (`SortedSpells`, with each spell's share through `NS.HudBreakdown`), the timing strip
  (`Timing` → `Place`: the race, the buzzer, the grace, the tail, each late cast, the end of combat),
  the flags (`FlagLines`, over `Scoring.Flags` with spell names through `C_Spell`), the note. Under
  the breakdown, for a run raced since the last `/reload` or login, the damage chart
  (`HudChart.ResultView`, the in-session buckets scaled to `result.damage`, or with a best before the
  run its diagonal on the shared max, as on the result card); a run without buckets has no section. In the expanded view it sits beside the list; in the collapsed view (the default, UT-P14) it replaces the list with a back control. Only the title bar's toggle switches the view, never the width. The header's
  target line leads with two chips (`Detail.Meta`): the target type in its category color and the
  race length in its length color (`ResultsTable.LengthChip`), then `ResultsTable.TimeTail` (the DoT
  tail, *+11.1s*, or when an incomplete run's combat ended, *at 1:04*) and the target's name.
- **The detail's Delta box** (the owner's call, 2026-10-26): the Runs list's *Delta* for the run, not
  `Bests.Delta` (the best that stood when it was raced, which only the HUD's result card and the
  share line still read). The column's scan (`Table:measure` → its `scan`) keeps one context per
  group of the runs the filters pass (`ResultsRuns.Context`: the max DPS, the complete run that sets
  it and the runner-up, `Leaders` breaking a tie to the earlier run) and which runs it listed, on the
  Runs view, never on a run. The detail asks through the shell's `deltaContext` hook
  (`View:DeltaContext`); a run the filters leave out (opened from the HUD, a Bests row) gets its board
  among every run the source holds (`BoardContext`: spec x target type x length, `Bests.Key`), the
  sample history's in test mode. `DeltaBox` answers the figure: the group's top complete run's lead
  over the runner-up in green (a dash with none), any other run's own *Delta* cell (an incomplete
  run's figure muted, as the column shows it, and a lost run's a muted dash); the top complete run
  alone gets the *New best* badge beside the box.
  Every `View:Refresh` (a filter, *Group by*, a saved view applied, a store change) calls the view's
  `changed` hook, and the shell redraws the box and the badge (`Pane:RefreshDelta`).
- **Writes**: *Add note* → `Results.SetNote` → `ResultsDetail.ClampNote` (200 characters) →
  `Recorder.SetNote` (`RUNS_CHANGED`, never `RUN_SAVED`: that one prunes, and a typed note must not
  delete runs). The *Usage* section's *Save* → `Usage.SetUsed` (`RUNS_CHANGED`, likewise). *Delete* → `Results.ConfirmDelete` → the `DPSRACE_DELETE_RUN` popup →
  `Results.DeleteRun` → `Recorder.Delete` (`RUNS_CHANGED`).
- **What was used** (#13, `modules/Results_Usage.lua`): the Runs list's *Used* column draws
  `ResultsUsage.Icons(run)` (the gear first, as many 16 px icons as the 70 px column holds, else one
  fewer and *+n*; a dash for nothing or no record), sorts by `Count` (a run with no record last) and
  names each entry, its icon first, and when in its tooltip (`CELL.used`). The detail's *Usage*
  section, under *Talents*, lists `UsedRows` (what was used, gear first; *Nothing used* when empty).
  *Edit* switches it to `Rows` (each candidate with the entry it stands for, then each used entry no
  candidate stands for: food), the used ones ticked, with *Save* beside *Edit*. *Save*, live only
  while the ticks differ from the stored list, calls `Usage.SetUsed(run, ResultsUsage.Edits(...))`
  (the ticks, then each used entry the edit does not list: a hidden item's) and leaves the edit: each
  tick keeps the detected entry it matches (by item, and by slot, never one entry twice), a new tick
  is `manual` (used once, no time; food ticked again keeps its detected source), an unticked food
  joins the candidates so its row stays, and the record is marked `edited`; a sample run changes in
  memory only (`ResultsSource.Touched`). *Edit* again, or another run, leaves the edit unsaved; a
  redraw of the same run keeps the scroll, the edit and its ticks not saved yet (`ResultsUsage.Carry`,
  by each row's item). A run with no `usage` reads *Not recorded*.
- **The hidden items** (P9, `global.usage.hidden`): `Usage.Shown(e)` leaves out a hidden item and an
  old record's `enchant` entry everywhere `ResultsUsage` lists (`Entries`, so the Used column, its
  tooltip and its sort; `Rows`; `UsedRows`). The list is written whole through `NS.SetByPath` by
  `Usage.Hide` / `Usage.Unhide`: from the History page's *Usage* tab (the library's ID list) and from
  a right-click on an item's row in the edit (*Never show <item>*, `ResultsUsage.RowMenu`). The
  `SETTINGS_CHANGED` it sends redraws the Results window (`Results.lua`'s bus receiver). Detection
  still records a hidden item, so un-hiding it brings it back on every run.
- **The ability timeline** (#14, `modules/Results_Timeline.lua`): the detail's *Timeline* button,
  live for a run with a non-empty cast list, opens a pop-out window on the detail pane. It draws
  `Rows(run, other)`: one row per ability and caster across both runs (a base cooldown of 29 s or more
  first, longest first, then by this run's count, then the other's, the player's before the pet's),
  each with two lanes, this run's casts as thin gold ticks above the compared run's as blue, each lane's
  count just past its right end (`COUNT_GAP`), over an axis to the longer of the two races (`Span`, `Ticks`),
  drawn again under the *Casts* strips.
  Above the lanes (under a *Casts* heading; the lanes under *By ability*) two strips on the same axis,
  this run's over the compared run's, draw every cast (`CastsOf`, the pet's too) as its ability's icon,
  stacked onto extra rows where icons would overlap (`Stack`; this run's upward, the other's downward,
  each strip `StripHeight` tall for its rows, at most `MAX_STACK`); `Sections` places the parts. The compared run
  is `ResultsDetail.CompareTarget(true)` (the best, the runner-up or the picked run, whether or not
  the compare is on); with none, or one with no casts, its lanes stay empty under a note. Every
  position is `MarkX` on the window's tracked size and the zoom: the controls at the right of the *Casts*
  heading line step `ZOOMS` (1x to 8x), which lays the strips' and the lanes' time area out that many
  times the lanes' width in clipping scroll frames that pan together (zoomed in, Shift+wheel and the scroll
  arrows after the zoom controls, `Pan`, a quarter of the view a step, and the scrollbar along the window's bottom, `ScrollTo`, whose thumb is the view's share), kept
  as the fraction of the axis at the view's left (`ClampPos`, which snaps a value a rounding error short of an end onto it, and `Rezoom`,
  about the view's middle for a button and about the moment under the cursor for Ctrl+wheel: the cursor less the window's left edge, `CursorAt`, the one
  geometry read, and no meter value near it); the arrows are live only zoomed in on drawn lanes; another run or compare target
  goes back to 1x. The detail calls `ResultsTimeline.DetailChanged`
  on every draw and compare change, so the window follows the run, a pick and *Clear Pick*; it closes
  with the Results window. Every open places it exactly over the Results window, that window's anchor
  and its size in the view shown (`Results.Placement`); nothing of its place or size is stored.
- **The gear view** (#17, `modules/Results_Gear.lua`): the *Gear view* button at the right of the
  detail's *Gear* heading (shown for a run with gear) opens a modal on the detail pane, centered over
  the Results window (`CenterOver` on `Results.Placement`) at the size its content takes (`Size`). It
  reads `ResultsSource.LoadoutOf` for this run and the compared run (`CompareTarget(true)`, as the
  timeline does) and lays the slots out from `Cells` (the character panel's columns, the weapons under
  the middle); each slot's marks come from its stored link (`ParseLink`: the enchant and gem IDs),
  and `SlotDiff` against the compared run's slot gives its tint (another item), its item level's color
  and its marks' amber edge (`Marks`; nothing is marked when the compared run has no gear). The middle
  column is `Stats.Groups(Stats.Of(run), Stats.Of(other))`: each value's text and its delta, a dash
  for a run with no `stats`. The detail calls `ResultsGear.DetailChanged` beside the timeline's, so the
  view follows the run and the compare; it closes with the Results window.
- **The Bests tab**: `Bests.Board({ cleanOnly })` → `ResultsBests.Rows` (spec and category) → the
  same list widget. *Clean runs only* switches to the clean board. One category shows at a time (no
  *All categories*: the table has no target column, so two boards of one spec and length would read
  alike); it starts on the first category present, in `NS.Dummies.CATEGORIES` order.
- **Following the store**: `RUN_SAVED` and `RUNS_CHANGED` redraw the shown tab and the detail (a
  selection whose run is gone is dropped); a hidden window redraws in full on its next show.
  `SETTINGS_CHANGED` for `global.history.keepDays` redraws the footer.

## Share and the race's chat lines (spec §6.1, §6.2; mockup screen 12)

- **Share**: the HUD's result card and the Results detail call `Share.Prompt(run)`; a Results row's
  right-click menu fills its *Share* submenu with the same channels through `Share.FillMenu`. A run with no score (lost) prints one line and opens nothing; in combat, or in
  the client's chat lockdown, one line refuses. Otherwise a `MenuUtil` context menu offers Say, Party,
  Raid, Guild and Whisper…, the channels the player is not in grayed. A pick re-checks combat and
  sends `Share.Line(run)` (*DPS Race 3:00 · Cleave · Destruction 313 · 26.56M · 147.6K DPS (Ka0s
  DPS Race)*) through `NS.Compat.ChatSender()` (`C_ChatInfo.SendChatMessage`); Whisper asks for a name first
  (`DPSRACE_SHARE_WHISPER`, the player target's name offered). The line is plain text, every `|`
  replaced.
- **The race's own lines**, in the player's chat only: `RACE_STATE_CHANGED` to armed prints
  `Share.ArmedLine(run)` (*Armed: 3:00 on Cleave Training Dummy. First hit starts the clock.*), so
  every surface that arms says so once; `RACE_RESULT` prints `Share.ResultLine(run, Bests.Delta(run))`
  (*26.56M damage · 147.6K DPS in 3:00 on … — new best (+2.4%) · 1 late cast · tail +3.1s*), or that
  a lost run could not be read.
- **The new-best toast** (#5, `modules/BestToast.lua`): `RACE_RESULT` with a `complete` run asks
  `Bests.Delta(run)`; only a new best with a gain (a previous best on the board, so never a board's
  first run) queues one toast under the run's id, through LibKa0s-Toast-1.0 (`core/ToastSetup.lua`),
  whatever the HUD shows. Its payload is plain text off the stored run and the previous best (Delta's
  third return): *New best: Destruction (Single target)*, *1:00 · 104.2K DPS, +4.2% over 100.0K*, and
  the run's flags as the result card's chips word them. The shell shows one at a time for
  `toast.duration` seconds (paused under the pointer), plays the alert with `toast.sound`, and closes on
  its X or a right-click. Test mode holds the sample race's toast (`BestToast.ShowPreview`, from
  `modules/Preview.lua`) until it ends; only that toast and *Test toast*'s sample move, and a drag
  stores `profile.toast.point`. The stand-down clears it (`BestToast.Suspend`).

## Test mode and the sim (spec §6.5, preview-mode; B5)

- **On**: the Master controls' *Test mode* row (`state.testMode`), `/dr test` and the launcher's *Test
  mode* entry all reach `NS.ToggleTestMode` → the row's `set` → `Preview.Start()`. `/dr test <armed|running|result>`
  and `/dr sim [scenario]` queue their start (`Preview.Queue`) and turn the same row on through the
  seam (`NS.StartSim` for the sim, both in `core/DpsRace.lua`), so the checkbox follows; with the
  preview already on they switch it in place (`Preview.Start` again, or `Preview.SetState` for a still
  body). A start is refused with one line in combat and while a real race is armed, running or waiting
  for its result; the checkbox reads `Preview.IsActive()`, so a refused start leaves it unticked.
- **The sample**: every start builds a fresh sample history (`MockRuns.Dataset()`: 16 runs on the
  player and two made-up characters, every Status, target type and preset length, notes, loadouts
  from the player's own `Recorder.SnapshotLoadout()`, sample chart records, and sample casts and
  usage (`MockRuns.Usage`: a class's cast pattern, and usage detected by `Usage.Build` from the
  player's own snapshot; one run raced before format 3 has neither)) and routes the
  Results window to it (`ResultsSource.Use`). Every Results file reads through that seam, so the
  window draws the sample as it draws the store: the Runs view opens on every character and spec,
  the Bests tab, the detail's compare, chart (with its cooldown icons), gear, talents and usage, and
  the ability timeline. A note, a usage edit or a delete changes the sample in memory; Share, *Save* and *Reset* refuse. Nothing is written to `NS.db`.
- **test** (`Preview.Mode() == "test"`): static. The HUD holds one body still, drawn by
  `NS.Hud.Render(state, run, figures)` (the HUD's own bodies): running by default, 18 s into a sample
  0:30 race beating the history's best on its board (`Sim.Sample("newbest")`: the clock, live figures,
  the chart against the best's pace, the pace bar and the spells), or armed or the result card. No
  timer runs. The Results window opens on the sample.
- **sim** (`Preview.Mode() == "sim"`, `modules/Sim.lua`): the scenario's sample race (`newbest`,
  `behind`, `first`, `incomplete`, `died`, `flagged`, `shared`; its DPS set against the history's best
  on its board) plays Armed 3 s → Running 30 s → Stop! 3 s → Waiting 4 s → Result 4 s (a run that ends
  before its buzzer goes Running → Waiting out of combat → Result), then joins the sample history
  (`ResultsSource.Add`, with its chart record unless shared) and the Results window opens on it while
  the HUD keeps the card. One `C_Timer` ticker at 10 Hz advances it and stops at the Results step. The
  running body and the card draw the chart and the pace bar against that best (scale B and no pace bar
  for `first`, neither for `shared`), the center countdown shows silently in its last seconds, and the
  card's delta is `Bests.Delta` against the sample history. *Stop Now* on its Stop! or waiting body
  jumps the script to the result card (`Sim.SkipToResult`); *Cancel* ends the sim.
- **The marker**: while either is on, `Hud.Refresh` lays the library's test-mode strip (*Test mode:
  sample numbers. Combat or Arm ends it*: what it shows and what ends it, standalone-windows) under the title bar and moves the content down by its height; with no
  Widgets library the title reads *DPS Race · Test* instead, never both. The Results window lays its
  own under its tabs while it reads the sample (*Test mode: sample runs. Nothing here is saved*), or
  titles itself *DPS Race — Results · Test*.
- **Off**: its own switch, *Reset all settings* (the row's `default = false`), combat
  (`PLAYER_REGEN_DISABLED` → `Preview.Stop("combat")`, said once) and arming a real race (its bus
  receiver → `Preview.Stop("race")`, said once, the HUD left open for the race). The Results window
  goes back to the store (`ResultsSource.Restore`: the selection and the pick dropped, the player's
  Runs view restored); each window the preview opened is closed again, except the HUD for a race.
  Closing the HUD (its X or Escape) and the sample bodies'
  Cancel ends it too, through `Hud.Act`, and never reaches `Race.Cancel`: a start is
  allowed over a real result card, which the preview covers and leaves as it was; the sample card's
  New Race, Details and Delete are drawn disabled. The stand-down ends it silently (`Preview.Suspend`).
