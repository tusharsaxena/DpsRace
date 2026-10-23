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
  combat events the current settings need, and `NS.Race.Resume()` carries on the runs a `/reload`
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

## Combat edges (scaffold)

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
  combat and death events.
- **Start**: the first `DAMAGE_METER_CURRENT_SESSION_UPDATED` after arming. The start time is
  `GetTime()` at that event; `run.date` is restamped, `run.race.startedAt` is the clock's start, and
  the run is written to SavedVariables as `running`. A `C_Timer.NewTimer` is the
  buzzer. The session ID comes from the first `DAMAGE_METER_COMBAT_SESSION_UPDATED` of type
  DamageDone with a non-zero, plain ID that was not there at arm time. The combat-start edge re-reads
  the target (`Recorder.SnapshotTarget("target", armTimeTarget)`); that read is the one stored.
  Watchers adds the player's three cast events.
- **Running**: the HUD counts down (`Race.TimeLeft()`) and shows the live breakdown, read through
  `modules/Meter.lua` at the configured rate, with every value opaque. Every DamageDone update for
  the run's session is a stamp on its `Timeline`. Combat dropping or a death before the buzzer cancels
  the buzzer and records `result.endedAt` (seconds from the start): the run will be `incomplete`.
- **Buzzer** at start + length: the run moves to `stopping` and `RACE_BUZZER(run)` is sent. A cast
  that starts (or an instant that succeeds) later than buzzer + grace is a late cast,
  `{ t = offset, spellID }` on `flags.lateCasts`; a cast started before the buzzer is never late. A
  0.5 s `C_Timer.NewTicker` polls for readiness, only in this state.
- **Ready to read**: combat has ended **and** 2.5 s have passed since the later of the combat end and
  the last DamageDone update for the session (updates land up to 1.3 s after combat drops). The
  session is read by its ID through `Meter.ReadSession`, never as "current", into plain numbers. A
  run with no captured ID falls back to the newest session created after the arm and is flagged
  `sessionFromList` (spec §9). A `sealed` read is retried for 10 s; a missing session, a raise or a
  meter reset makes the run `lost` (kept, with no result).
- **Result**: DPS is damage ÷ race length (÷ `endedAt` for an incomplete run); `result.tail`,
  `result.combatEnd` and `flags.restartedAt` are measured from the buzzer; the run is saved
  (`RUN_SAVED`) and `RACE_RESULT(run)` is sent. Watchers drops every registration. `Race.Cancel()`
  dismisses the card; `Race.Arm` races again.
- **Cancel** before the result discards the run: an armed one was never stored, a running or
  stopping one is deleted from the store.
- **Resume** (`OnEnable` and the stand-up): the newest stored `running` or `stopping` run is carried
  on. Its session gone: `lost`. Running and before its buzzer: running, with the buzzer re-armed for
  the time left. Running past it: `stopping` with `flags.reloaded`. Stopping and out of combat: read
  at once; in combat: wait for the regen edge. An older unresolved run is settled as `lost`. The
  stand-down (disabled or a perf capture) drops the in-memory race and its timers and keeps the stored
  run, so the stand-up resumes it exactly like a `/reload`.

No decision in this pipeline reads a meter value in combat: every transition comes from an event or
`GetTime()` (spec §8, rule 2).
