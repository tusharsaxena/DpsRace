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
  `global.history.keep` (0 = never), and `NS.Race.Resume()` carries on the runs a `/reload`
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
  the player, target and place, the session IDs the client holds are remembered (they belong to
  earlier fights and are never this run's), and nothing is stored yet. Watchers registers the meter,
  combat and death events. The newest of those IDs is kept on the run as `race.armMaxSession`, so
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
  the run is written to SavedVariables as `running`. A `C_Timer.NewTimer` is the
  buzzer. The session ID comes from the first `DAMAGE_METER_COMBAT_SESSION_UPDATED` of type
  DamageDone with a non-zero, plain ID that was not there at arm time. The combat-start edge re-reads
  the target (`Recorder.SnapshotTarget("target", armTimeTarget)`); that read is the one stored. A
  combat that ends while still armed (it never started the clock) clears the re-read, so the combat
  that does start it reads the target again.
  Watchers adds the player's cast events (start, channel start, empower start, success, interrupt,
  channel stop); an empowered cast is in flight from its start, like any other.
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
  starts the quiet itself, so a missed edge never leaves a run waiting.
- **Ready to read**: combat has ended **and** 2.5 s have passed since the later of the combat end and
  the last DamageDone update for the session (updates land up to 1.3 s after combat drops). The
  session is read by its ID through `Meter.ReadSession`, never as "current", into plain numbers. A
  run with no captured ID falls back to the newest session created after the arm and is flagged
  `sessionFromList` (spec §9). A `sharedSession` run is netted against its `race.baseline` here. A
  `sealed` read is retried for 10 s; a missing session, a raise or a
  meter reset makes the run `lost` (kept, with no result).
- **Result**: DPS is damage ÷ race length (÷ `endedAt` for an incomplete run); `result.tail`,
  `result.combatEnd` and `flags.restartedAt` are measured from the buzzer (the restart is flagged on
  the run the moment its update arrives, so a `/reload` after it keeps it); the run is saved
  (`RUN_SAVED`) and `RACE_RESULT(run)` is sent. Watchers drops every registration. `Race.Cancel()`
  dismisses the card; `Race.Arm` races again.
- **Cancel** before the result discards the run: an armed one was never stored, a running or
  stopping one is deleted from the store.
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

## Bests and pruning (spec §6.2, §7)

- **Bests** are worked out, never stored: `Bests.Compute(runs, opts)` keeps the highest
  `result.dps` per `specID|category|length` board, over `complete` runs only (`cleanOnly` drops
  flagged ones). `Bests.Board(opts)` caches it per session; the cache is dropped on `RUN_SAVED` and
  `RUNS_CHANGED`, so a deleted best promotes the next run for free. `Bests.Delta(run)` compares a run
  with the best on its board before it.
- **Pruning** (`Recorder.Prune(keep, protect)`) runs at `OnEnable` and on every `RUN_SAVED`, only when
  `global.history.keep` is above 0. It removes the oldest resolved runs until `keep` remain, never one
  holding a best on either board, never a `running` or `stopping` run, never the run that `RUN_SAVED`
  just stored and never the race's current run (the one on the result card), and fires `RUNS_CHANGED`
  once. While stood down the bus receiver is dropped, so nothing prunes.

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
  waiting body names the drop-combat spells `IsPlayerSpell` says the character has.
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
- **The result card**: plain numbers from the read: damage, DPS, the best delta
  (`Bests.Delta(run)`: *New best +2.4%*, or *−3.2% vs best*), one chip per flag (the full
  `Scoring.Flags` text is its tooltip), the time chip, the spells with their share (as many as *Spell rows shown*, or all of them, wheel-scrolled, at 0), and *Race Again*
  (`Race.Arm` with the run's length and count), *Details* (`NS.Results.ShowRun`) and *Share*
  (`NS.Share.Prompt`).
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
- **Arm from the idle body**: the length picked (a preset, or a typed `90`, `1:30`, `3m`; the last
  one is remembered as `race.lastLength`) and the target count from the stepper go to `Race.Arm`; a
  refusal prints `Format.ArmRefusal(reason, detail)`, and the Arm button is grayed with the same line
  while a run is pending, in combat or with the meter unavailable.

## The Results window (spec §6.2)

The window reads stored run records only: every number on one went through `NS.Secrets` on its way
into the store, so sorting, percentages and the timing strip are plain Lua. It holds no game event,
timer or `OnUpdate`.

- **Opening**: `NS.ToggleResults` (the key binding, the HUD's Results control), `Results.ShowRun(id)`
  (the HUD's *Details*, a Bests row) or `Results.ShowTab(name)`. `IsShown()` =
  wanted and not stood down; General visibility does not apply to it. Each tab is built the first
  time it shows.
- **The Runs tab**: `Recorder.All()` → `ResultsRuns.Options` fills the five dropdowns from the runs
  present → `ResultsRuns.Filter` keeps the resolved runs (complete, incomplete, lost) that pass the
  bar (*Only best* keeps the runs holding their board's best; *Group* is not a filter but the list's grouping, LootHistory's model: `Table:SetGroup` partitions the sorted runs under folding headers) → `ResultsTable` scales the Damage and DPS bars linearly from 10% (the smallest of the runs passed) to 100% (the largest), sorts them (newest first by default, reset at every login and `/reload`; on DPS an unranked run sorts last; a tie to the newer
  run) and binds the visible slice to pooled rows. A click selects a run; a double-click shares it.
- **The detail**: `ResultsDetail` draws the selected run: header, score and `Bests.Delta(run)`, the
  breakdown (`SortedSpells`, with each spell's share through `NS.HudBreakdown`), the timing strip
  (`Timing` → `Place`: the race, the buzzer, the grace, the tail, each late cast, the end of combat),
  the flags (`FlagLines`, over `Scoring.Flags` with spell names through `C_Spell`), the note. In the expanded view (the default) it sits beside the list; in the collapsed view it replaces the list with a back control. Only the title bar's toggle switches the view, never the width. The header's
  time is `Format.RunTime`: the length and the DoT tail (*2:00 +11.1s*), or the time in combat
  against the length (*1:04 / 2:00*).
- **Writes**: *Add note* → `Results.SetNote` → `ResultsDetail.ClampNote` (200 characters) →
  `Recorder.SetNote` (`RUNS_CHANGED`, never `RUN_SAVED`: that one prunes, and a typed note must not
  delete runs). *Delete* → `Results.ConfirmDelete` → the `DPSRACE_DELETE_RUN` popup →
  `Results.DeleteRun` → `Recorder.Delete` (`RUNS_CHANGED`).
- **The Bests tab**: `Bests.Board({ cleanOnly })` → `ResultsBests.Rows` (spec and category) → the
  same list widget. *Clean runs only* switches to the clean board. One category shows at a time (no
  *All categories*: the table has no target column, so two boards of one spec and length would read
  alike); it starts on the first category present, in `NS.Dummies.CATEGORIES` order.
- **Following the store**: `RUN_SAVED` and `RUNS_CHANGED` redraw the shown tab and the detail (a
  selection whose run is gone is dropped); a hidden window redraws in full on its next show.
  `SETTINGS_CHANGED` for `global.history.keep` redraws the footer.

## Share and the race's chat lines (spec §6.1, §6.2; mockup screen 12)

- **Share**: the HUD's result card, the Results detail and a row's double-click call
  `Share.Prompt(run)`. A run with no score (lost) prints one line and opens nothing; in combat, or in
  the client's chat lockdown, one line refuses. Otherwise a `MenuUtil` context menu offers Say, Party,
  Raid, Guild and Whisper…, the channels the player is not in grayed. A pick re-checks combat and
  sends `Share.Line(run)` (*DPS Race 3:00 · Cleave ×5 · Destruction 313 · 26.56M · 147.6K DPS (Ka0s
  DPS Race)*) through `NS.Compat.ChatSender()` (`C_ChatInfo.SendChatMessage`); Whisper asks for a name first
  (`DPSRACE_SHARE_WHISPER`, the player target's name offered). The line is plain text, every `|`
  replaced.
- **The race's own lines**, in the player's chat only: `RACE_STATE_CHANGED` to armed prints
  `Share.ArmedLine(run)` (*Armed: 3:00 on Cleave Training Dummy ×5. First hit starts the clock.*), so
  every surface that arms says so once; `RACE_RESULT` prints `Share.ResultLine(run, Bests.Delta(run))`
  (*26.56M damage · 147.6K DPS in 3:00 on … — new best (+2.4%) · 1 late cast · tail +3.1s*), or that
  a lost run could not be read.

## Test mode (spec §6.5, preview-mode)

- **On**: the Master controls' *Test mode* row (`state.testMode`), `/dr test` and the launcher's *Test
  mode* entry all reach `NS.ToggleTestMode` → the row's `set` → `Preview.Start()`. A start is refused
  with one line in combat and while a real race is armed, running or waiting for its result; the
  checkbox reads `Preview.IsActive()`, so a refused start leaves it unticked.
- **The script**: a fresh sample run (the player's own name and spec, a single-target dummy, a
  made-up 147.6K DPS) plays Armed 3 s → Running 30 s → Stop! 3 s → Waiting 4 s → Result, drawn by
  `NS.Hud.Render(state, run, figures)`: the HUD's own bodies, so the layout is the real one. One
  `C_Timer` ticker at 10 Hz advances it, and stops when the result card is reached; the result card
  holds until test mode ends. The engine never moves and nothing is stored.
- **The marker**: while test mode is on, `Hud.Refresh` lays the library's test-mode strip (*Test mode:
  sample numbers. Combat or Arm ends it*: what it shows and what ends it, standalone-windows) under the title bar and moves the content down by its height; with no
  Widgets library the title reads *DPS Race · Test* instead, never both.
- **Off**: its own switch, *Reset all settings* (the row's `default = false`), combat
  (`PLAYER_REGEN_DISABLED` → `Preview.Stop("combat")`, said once) and arming a real race (its bus
  receiver → `Preview.Stop("race")`, said once, the HUD left open for the race). A HUD that test mode
  opened is closed again, except for a race. Closing the HUD (its X or Escape) and the sample bodies'
  Cancel / Discard Run end it too, through `Hud.Act`, and never reach `Race.Cancel`: a start is
  allowed over a real result card, which the preview covers and leaves as it was; the sample card's
  Race Again and Details are drawn disabled. The stand-down ends it silently (`Preview.Suspend`).
