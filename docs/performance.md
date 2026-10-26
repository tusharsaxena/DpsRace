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
| `hudLive` | one live read and redraw in `modules/Hud.lua` (`Meter.ReadLive`, the KPIs, the pooled spell rows, the damage chart's columns and the pace bar; the read's total copied into the chart's bucket, `modules/Slices.lua`) | throttled to `live.hz` (4 Hz by default), coalesced from `DAMAGE_METER_COMBAT_SESSION_UPDATED`, plus one `C_Timer` read at each chart bucket boundary (at most 60 a race), only while the HUD is on screen and the race RUNNING, never from `OnUpdate`; one more read at the buzzer |
| `hudTick` | the HUD window's `OnUpdate` pass in `modules/Hud.lua`: the countdown text, the stop figures, the Stop!/Waiting phase, and the running body's chart and pace views (`HudChart.LiveViews`: the chart's view and the best behind it cached per race and rebuilt only when the run, the bests board, the length or the run's slices change; the pace max refilled into one reused table; the stack placed again only when a compared input changed) | 20 Hz while RUNNING, 4 Hz while STOPPING; attached only while the window is shown and the race in one of them |

The HUD's other work is not a hot path: its own AceEvent target (target and regen edges while shown)
redraws on an edge. The final seconds (`modules/Countdown.lua`) are at most ten one-shot `C_Timer`s armed when the race runs, each a sound and a texcoord change; no `OnUpdate`.

The race's own timers are one buzzer (`C_Timer.NewTimer`) while running and one 0.5 s readiness
poll (`C_Timer.NewTicker`) while stopping; neither exists while idle, and the stand-down cancels both.

While idle the addon should run nothing but the combat-edge handler, and, with the HUD on screen, its
target and regen edges.

## Window sizing

The three windows the addon owns (the Results window, the ability timeline and the Race HUD) are
resized from the library's corner grip (`NS.MakeResizable`, `LibKa0s-Core-1.0`), which runs the
window's relayout on every `OnSizeChanged`: every frame while the grip is dragged. Before the
2026-10-26 pass each window ran its full layout there, and the Results window lagged behind the
cursor (the owner's report). What one size change cost, read from the code:

| Window | Per size change, before |
|---|---|
| Results, Runs tab | the filter bar re-planned (`Runs.BarPlan`) and its controls re-anchored; the list's `Table:Layout`: the columns (`Tbl.Columns`), every header re-anchored, then `Bind`: every row released and acquired again, every cell of every visible row re-placed (the layout version moved) and bound again (`bindRow`: the texts, the boxed chips measured by `Tbl.BadgeWidth`, the class and spec icons, the bar shares), the scrollbar; then the detail's `Layout`: the header and the KPI boxes, the spell breakdown or the compare's two tables, the damage chart drawn again (`chart:Draw`: the columns and the cooldown icons), the timing strip (`Detail.Place`, its late-cast ticks re-pooled, the axis text set), the gear and talents (`ResultsLoadout.Layout`), the usage rows and the flags and note |
| Results, Bests tab | the list's `Table:Layout`, as above |
| Ability timeline | the legend and the axis, then every pair and every cast tick re-pooled: each pair refilled (its icon, name, cooldown and counts set) and each tick and its hover frame acquired, colored and anchored again |
| Race HUD | every built body's `Layout` (anchors only); nothing drawn again, so the result card's rows and chips waited for the next redraw |

Since then all three size through one pattern, `modules/Sizing.lua` (`NS.Sizing.MakeResizable`). A
window hands it its bounds and five functions: `size` (track the clamped size, on every change),
`layout` (cheap), `redraw` (the full layout it had before), `done` (on release: store the size) and the
HUD's `canResize` gate. While the grip is held, a size change runs `layout` at most once a frame:
`GetTime()` names the frame, and a second change in the same frame waits for one `C_Timer.After(0)`,
which a release overtakes. The release runs `redraw` once, then `done`; so does the window's hide while
the grip is held (Escape, Alt-Z, a stand-down), which no mouse-up follows, `done` handed the last size
the drag reached. A size change the grip did not
start (the stored size at build, a view switch, *Reset position*) runs `redraw` at once, as before.
What `layout` does per frame now:

| Window | Per frame while dragging | Once on release |
|---|---|---|
| Results | the list's `Table:Resize`: the columns and headers re-anchored and, when the width moved, the shown rows' cells re-placed (anchors only); a row the new height adds bound alone, one it drops hidden and kept spare; the offset held; the scroll range. The detail's `Resize`: its scroll frame sized and the scroll clamped, its content as it was. The filter bar not touched (only the view changes its plan) | `layout()`: every row rebound, the detail laid out and drawn, the size stored |
| Ability timeline | the legend, the axis and the scroll frame; when the width moved, each pair's lanes re-anchored, each tick moved along its lane (two anchors a tick) and each *Casts* icon along its strip on the row it had (one anchor an icon), nothing pooled, filled, colored or restacked | `layout()`: every pair, tick and cast icon re-pooled, the icons restacked for the new width, the size stored |
| Race HUD | the body on screen's `Layout` alone | every body's `Layout`, the shown body drawn again (`render(true)`: the result card's rows fit the new height, the chips wrap at the new width), the size stored |

`tests/test_sizing.lua` pins it: a 30-frame drag of each window runs its expensive path (the Runs and
Bests lists' `Bind`, the detail's `Layout`, the timeline's tick and icon pools, the HUD bodies' `Update` and the
hidden bodies' `Layout`) zero times, and the release runs it once. The offline runner
(`tests/perf.lua`) measures bytes per call of the bracketed hot paths and has no grip to drag, so the
pattern is pinned by those counts rather than by a scenario.

The debug console (`LibKa0s` `DebugLog.lua`, vendored and not edited here) passes the library only an
`onResize`: on every size change, the drag's included, it resyncs its scrollbar's range and its status
line; its message frame and scrollbar are anchored to the window and follow it on their own.

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
| `hudTick` | `Hud.Tick()`, the HUD's `OnUpdate` pass while RUNNING | the countdown redraw's per-frame cost, the cached chart and pace views included (800 bytes, as before the chart) |
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
