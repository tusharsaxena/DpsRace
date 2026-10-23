# Performance

How much Ka0s DPS Race costs, and how to measure it. The harness is `LibKa0s-Perf-1.0`, built in
`core/PerfSetup.lua`; the shared capture protocol and record contract live with the library and are
not restated here (performance-§7, §8).

## What is bracketed

Each declared bucket is a hot path wrapped in the gated bracket idiom (performance-§2): one boolean
test when capture is off.

| Bucket | Path | Why it is hot |
|---|---|---|
| `combatEvent` | `NS:OnCombatChanged` in `core/DpsRace.lua` (`PLAYER_REGEN_DISABLED`, and `PLAYER_REGEN_ENABLED` when visibility needs it) | It runs on every combat edge |
| `raceEvent` | the event handler in `modules/Watchers.lua`: every meter, combat, death and cast event while a race is armed, running or stopping | `DAMAGE_METER_COMBAT_SESSION_UPDATED` and the cast events fire throughout a run |
| `hudLive` | one live read and redraw in `modules/Hud.lua` (`Meter.ReadLive`, the KPIs and the pooled spell rows) | throttled to `live.hz` (4 Hz by default), coalesced from `DAMAGE_METER_COMBAT_SESSION_UPDATED`, only while the HUD is on screen and the race RUNNING, never from `OnUpdate` |
| `hudTick` | the HUD window's `OnUpdate` pass in `modules/Hud.lua`: the countdown text, the stop figures, the Stop!/Waiting phase | 20 Hz while RUNNING, 4 Hz while STOPPING; attached only while the window is shown and the race in one of them |

The HUD's other work is not a hot path: its own AceEvent target (target and regen edges while shown)
redraws on an edge. The final seconds (`modules/Countdown.lua`) are at most ten one-shot `C_Timer`s armed when the race runs, each a sound and a texcoord change; no `OnUpdate`.

The race's own timers are one buzzer (`C_Timer.NewTimer`) while running and one 0.5 s readiness
poll (`C_Timer.NewTicker`) while stopping; neither exists while idle, and the stand-down cancels both.

While idle the addon should run nothing but the combat-edge handler, and, with the HUD on screen, its
target and regen edges.

## Taking a capture

All in game, through the reserved `perf` verb (`/dr perf help` lists the words):

- `/dr perf start [label]`: begin a run; records who and where you are.
- `/dr perf measure a`: arm experiment A, the addon active. It records only while combat lasts.
- Fight a dummy, then leave combat.
- `/dr perf measure b`: arm experiment B, the same with the addon suspended through the latch's
  `perf` hold.
- Fight the same dummy for about as long, then leave combat.
- `/dr perf finish`, `/reload`, then `/dr perf report`: prints the summary and the one JSON line.

Run both arms back to back, at the same target, somewhere quiet. While suspended the addon is inert:
every registration is dropped, and its feature verbs answer *Not available during a performance
capture.*

A capture worth keeping becomes a bundle under [`perf-analysis/`](perf-analysis/README.md), written
by `/dev-copilot:wow-perf-analysis` from the report and the JSON line.

## Reading a report

- The **buckets** are the addon's own cost, measured directly. Read them first.
- The frame-time delta between the arms is a difference of two noisy aggregates. Below about
  0.5 ms per frame on a 60 to 80 s arm it is **unresolved**, not zero (performance-§8).
- A suspended arm that reads slower than the active one means the environment moved between arms.

## Offline scenarios

`tests/perf.lua` is the offline scenario runner (performance-§9). It measures bytes allocated and
bracket notes per iteration of the hot paths, never wall-clock time, and sits outside the commit
gate. On a 15:00 race running on session 25 with the HUD shown, it measures each of the four
bracketed paths with capture off and on:

| Scenario pair | Path | What it pins |
|---|---|---|
| `raceEvent` | a DamageDone update for the run's session, through `modules/Watchers.lua`'s AceEvent target | the timeline stamp allocates next to nothing |
| `hudTick` | `Hud.Tick()`, the HUD's `OnUpdate` pass while RUNNING | the countdown redraw's per-frame cost |
| `hudLive` | `Hud.ReadLive()`, one live read and breakdown redraw from secret values | the throttled read's cost |
| `combatEvent` | `NS:OnCombatChanged`, the addon object's regen handler | one HUD refresh |

Each pair is the zero-overhead evidence: capture off allocates nothing over capture on, and capture
on at most 64 bytes (one note) over off. Every scenario has a byte ceiling and a pinned note count
(0 off, 1 on). A fifth scenario, `raceInputStoodDown`, pins a disabled addon's race input at 0 bytes.
The ceilings and their measured figures are in the file's header. Its runs are kept in
[`automated-tests/`](automated-tests/README.md), not in `perf-analysis/`.

## Complexity

Measured by the runner's sighted `complexity` suite at release (automated-tests-§3). The release is
gated on zero functions above CCN 15; the trend line is `automated-tests/RESULTS.md`.
