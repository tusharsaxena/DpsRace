# 2026-10-25: the damage chart, compare vs best, and loadouts

Branch `feat/2026-10-25-chart-compare-loadout`, from master `88bb82d`. It covers issues #7, #2, #3 and #6. #5 (the toast) is
skipped this run and waits for LibKa0s#60, and #4 is closed as will-not-do.

**Gate per commit:** `lua tests/run.lua` and `luacheck .` (0/0), each through
`~/.claude/dev-copilot/bin/ka0s-bounded`. Gate on the exit code, never on `| tail`. Every function stays at CCN 15 or
below.

**Checkpoints:** each step is one or more commits, and its box is ticked in the step's last commit. A fresh
session resumes at the first open box. The branch is pushed after each milestone (M1, M2, M3, M4) and is
never merged without the owner's go-ahead.

## Decisions (the owner, 2026-10-25)

- **#2:** only mockup boards A and B. Board C (the activity strip) is dropped.
  - The chart is a visual indicator and never does math on a value.
  - Secrets do not survive a `/reload`: the probe showed SavedVariables writes them as `nil`. So the
    after-the-race chart exists only for runs raced since the last reload or login, from slices held in
    memory. Stored runs from earlier sessions show no chart.
- **#3:** the live pace bar compares damage with the best's average pace. It is on by default, with a
  setting, and hidden when there is no best or on a shared session. The chart overlay is the best's
  average-pace diagonal, and only when the chart is scaled to the best.
- **#6:** the triage recommendations are accepted.
  - No flag for a loadout that differs from the best's.
  - The shirt (4) and tabard (19) slots are dropped.
  - The share line is unchanged by default. An optional *Include talents link* setting is off by default.
  - No node-level talent diff. Talents show only a *different loadout* marker. The gear compare
    highlights the slots that changed.
- **#7:** compare against the board's best, or against a run picked from the Runs row menu.

Mockup: https://claude.ai/artifact/AMWeF6JJ3z9JTLgeBaKGZJ (boards A and B).

## Steps

### M1: #7 Compare in the Results detail

- [x] M1.1 `ResultsDetail.CompareSpells(run, other)` (pure) and its headless tests.
- [x] M1.2 The detail's *vs best* / *vs picked* toggle: a second KPI column and a compared breakdown.
  The Runs row menu gets *Compare with…*, a session-only pick. Locale strings and the smoke rows.

### M2: #2 the live damage chart and #3 the pace bar

- [x] M2.1 Slice capture: the race keeps one opaque live total per bucket (at most 60), in memory only,
  keyed by run id. This is the in-session store.
- [x] M2.2 `modules/Hud_Chart.lua`: pooled vertical StatusBars in the running body.
  - Scale (A): the best's final damage × 1.15, plain, with the best line and the pace diagonal.
  - Scale (B): the current live total, secret.
  - Hidden on a shared session.
  - Settings: *Show damage chart* and *Show pace bar*.
- [x] M2.3 The #3 live pace bar: `SetMinMaxValues(0, 2 × pace)`, `SetValue(live.total)`, and a center tick.
- [x] M2.4 After the race: the HUD result card and the Results detail draw the in-session slices, scaled
  to the run's plain final damage. There is no section for runs without slices.
- [x] M2.5 Tests (the handle identity per column, no fill before its boundary, hidden on a shared
  session, pace math), docs and smoke rows.

### M3: #6 Equipment and talents

- [x] M3.1 Capture: `Recorder.SnapshotLoadout()` at arm and again at combat end, keeping the combat-end
  one.
- [x] M3.2 Storage:
  - Deduped `global.loadouts.gear[hash]` and `global.loadouts.talents[hash]`, with `run.loadout = { gear, talents }`.
  - Run-record format `schema` 1 → 2, plus a migration step.
  - Pruning and every delete drop orphaned loadouts.
- [x] M3.3 The detail:
  - **Gear grid:** quality borders, an ilvl overlay, native tooltips, shift-click to link, and *Dressing Room*.
  - **Talents:** the loadout name with *View* (the `talentbuild` link) and *Copy*. *View* is greyed out with a
    tooltip when the serialization version no longer matches.
  - **Under M1's compare:** highlight the gear slots that changed, plus the *different loadout* marker.
- [x] M3.4 The Runs table's Spec tooltip names the loadout and notes a gear change since the previous run.
  The *Include talents link* share setting.
- [x] M3.5 Tests (capture, dedupe, migration, orphan prune), docs and smoke rows.

### M4: Finish

- [x] M4.1 Docs sync: ARCHITECTURE, schema, settings-panel, data-flow, module-map, scope, the
  smoke-test pending list and the test inventory. A final review pass.
