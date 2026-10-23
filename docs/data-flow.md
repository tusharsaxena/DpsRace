# Data flow

How Ka0s DPS Race works, as pipelines: trigger in, processing, what the player ends up seeing. This
is the engineer counterpart to the README's *How the race works*; the two describe one pipeline at
two levels and must not contradict each other. The race pipeline is summarized from the spec (§4,
§5) and is completed here by T10 once T5 lands it.

## Load and enable

- **File load.** The TOC loads `locales/` → `core/` → `defaults/` → `modules/` → `settings/`. Each
  `core/*Setup.lua` builds its `LibKa0s` instance from a descriptor, or installs its degradation stub
  when the library is absent. Settings pages register their rows and builders; nothing is drawn.
- **`OnInitialize`** (`core/DpsRace.lua`): AceDB (`NS:InitDB`), migrations (`NS:RunMigrations`), the
  stored `enabled` takes or releases the `disabled` hold (`NS.SyncEnabledHold`), the launcher
  registers, the settings category registers eagerly, and `/dr` and `/dpsrace` register.
- **`OnEnable`**: if the latch is down, nothing; otherwise `NS.RegisterGameEvents()` registers the
  combat events the current settings need. T5's `Race.Resume()` runs here too, for runs a `/reload`
  interrupted (spec §4.5).

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

## The race (T5, from spec §4 and §5)

- **Arm** (out of combat only): snapshot the player, read the target, look it up in the dummy
  catalog, store nothing yet.
- **Start**: the first `DAMAGE_METER_CURRENT_SESSION_UPDATED` after arming. The start time is
  `GetTime()` at that event; the run is written to SavedVariables as `running`. The session ID comes
  from the first `DAMAGE_METER_COMBAT_SESSION_UPDATED` of type DamageDone with a non-zero ID.
- **Running**: the HUD counts down and shows the live breakdown, read through `modules/Meter.lua` at
  the configured rate, with every value opaque.
- **Buzzer** at start + length: the run moves to `stopping`; cast tracking (late casts after the
  grace) and tail tracking switch on.
- **Ready to read**: combat has ended **and** no DamageDone update for this session in the last
  2.5 s. The session is read by its ID, never as "current", into plain numbers.
- **Result**: DPS is damage ÷ race length (÷ time to combat end for an incomplete run), flags are
  attached, the run is saved (`RUN_SAVED`), bests and the HUD's result card update.

No decision in this pipeline reads a meter value in combat: every transition comes from an event or
`GetTime()` (spec §8, rule 2).
