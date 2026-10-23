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

That is the scaffold's only combat path. The spec's design budget (§10) names what later tasks add
and bracket, each in the change that adds it:

- the live breakdown read, throttled to `live.hz` (4 Hz by default), only while the HUD's Running
  body is visible, coalesced from `DAMAGE_METER_COMBAT_SESSION_UPDATED` and never run from
  `OnUpdate` (T7);
- the countdown text's one `OnUpdate` at 20 Hz, attached only while Running or Stopping (T7);
- the meter and cast event handlers (T5).

While idle the addon should run nothing but the combat-edge handler.

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

`tests/perf.lua`, the offline scenario runner, lands in T10 with the first automated-test bundle. It
measures call counts and allocation per iteration of the hot paths, never wall-clock time, sits
outside the commit gate, and ships a zero-overhead scenario proving the bracket costs nothing when
capture is off (performance-§9). Its runs are kept in
[`automated-tests/`](automated-tests/README.md), not in `perf-analysis/`.

## Complexity

Measured by the runner's sighted `complexity` suite at release (automated-tests-§3). The release is
gated on zero functions above CCN 15; the trend line is `automated-tests/RESULTS.md`.
