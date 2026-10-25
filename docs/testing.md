# Testing

How to verify Ka0s DPS Race (testing-§6). What to install first is in the root
[`DEPENDENCIES.md`](../DEPENDENCIES.md); this page assumes it is done. Every command runs from the
**repo root**.

## Commands

| Command | What it does |
|---|---|
| `lua tests/run.lua` | The headless suite. Exits non-zero on any failure |
| `lua tests/run.lua -j auto` | The same, split across one worker per CPU (testing-§14) |
| `lua tests/run.lua --list > docs/test-cases.md` | Regenerates the case inventory without running anything |
| `luacheck .` | Lint, configured by `.luacheckrc`; must report 0 warnings and 0 errors |
| `luac -p path/to/file.lua` | Syntax-check one file |
| `bash tests/_kit/run-automated-tests.sh` | All four out-of-game suites, written to a dated bundle ([automated-tests/README.md](automated-tests/README.md)) |

Every run is bounded by the vendored kit as it loads (memory, time, process depth; testing-§15).

## The commit gate

Before **every** commit: `lua tests/run.lua` green **and** `luacheck .` at 0/0 (testing-§4). Work is
test-first: a failing case that pins the behavior, then the code. The runner's
`--suite lint --suite tests --no-bundle` is the same pair and writes nothing.

## The four out-of-game suites

A suite gates a **commit** and a **release** (the tag) differently, so both are named:

| Suite | Command | Gates the commit? | Gates the release (tag)? |
|---|---|---|---|
| `lint` | `luacheck .` | yes | yes |
| `tests` | `lua tests/run.lua` | yes | yes |
| `perf` | `lua tests/perf.lua` | no, recorded only | yes, at `pass` (a `skip` is not evaluated) |
| `complexity` | `bash tests/_kit/run-automated-tests.sh --suite complexity` | no, recorded only | yes, at `pass` with zero functions above CCN 15 |

The release is gated on all four at `pass` plus zero functions above CCN 15, `blindFiles` at 0 and a
run on which `lizard` did not raise (automated-tests-§3). Never run raw `lizard`: it is blind in
places in Lua, and the kit's sighted shadow is what the complexity suite measures.

## How the harness is built

- **`tests/_kit/`** is the shared harness, vendored byte-identical from the LibKa0s tag named in root
  `CLAUDE.md`. Never edit it; `test_vendor_sync` fails on any drift.
- **`tests/run.lua`** loads the vendored library in `LibKa0s.xml` order and the addon in **TOC
  order** (`Loader.tocFiles`), so the harness cannot drift from what the client loads (testing-§9).
  It runs `OnInitialize` and `OnEnable` like the client, and `loadInstance` builds isolated
  instances (a library-absent load passes `libFiles = {}`).
- **`tests/wow_mock.lua`** extends `tests/_kit/mock_base.lua` with what this addon calls, including a
  scriptable target (`M.__setTarget{ guid, name, level, classification }`, any field a `Kit.secret`),
  and installs the kit's frame-layer recorder (`tests/_kit/mock_layers.lua`) on every mock, so a level
  set relative to a parent reads back as a number and `M.__layers(frame)` answers where a frame sits.
- **`tests/mock_meter.lua`** is a scripted `C_DamageMeter` built on the kit's secret wrappers
  (`Kit.secret`): `SetSecret(true)` models the combat restriction, `SetSealed(id)` a session captured
  in combat. A suite installs it through `T.load{ mutate = ... }` so the enums resolve at load.
- Every negative assertion was proven able to fail by mutating the code under test (testing-§12).

## The suites

| Suite | What it covers |
|---|---|
| `test_skeleton` | Registration, the printer, both slash commands, DB defaults, `NS.MSG`, produced interfaces, icons, file headers |
| `test_secrets` | `core/Secrets.lua`: the guards over plain, nil and secret on both arms (LibKa0s-Compat and `core/Compat.lua`'s stub), routed through `NS.Compat`, the table detector's two rungs, the conversions, `SafeIterate`'s bound, nil stop and refusal |
| `test_meter` | `modules/Meter.lua` on `tests/mock_meter.lua`: availability, the plain sorted after-combat read, `sealed`, `missing`, a raising client, the opaque live read under secrets, the session list, and the one-file rules for `C_DamageMeter` and the secret detectors |
| `test_dummies` | `defaults/Dummies.lua`: the measured catalog rows, `Lookup` (known, unknown, a copy), the six categories and their labels |
| `test_recorder` | `modules/Recorder.lua`: the player, target and place snapshots (a Creature GUID's npcID, a secret GUID, a sealed re-read filled from the arm-time snapshot), `NewRun` freezing grace and restart gap, unique ids, and the store's order, `Pending` filter (status and the logged-in character), a later run schema left alone, and bus messages |
| `test_timeline` | `modules/Timeline.lua` on the probe's measured timelines: the tail (runs 4 and 6), damage restarting after a quiet gap and not on 2s DoT ticks, the gap's start at the buzzer, a gap that spans a `/reload`'s resume, out-of-order updates |
| `test_scoring` | `modules/Scoring.lua`: late-cast boundaries (exactly the grace, before the buzzer, an instant), `Dps` for complete and incomplete runs, `QUIET_BEFORE_READ`, the flag order and text, the optional spell-name resolver |
| `test_bests` | `modules/Bests.lua` and `Recorder.Prune`: the board key, incomplete and lost never counting, clean-only, the two Dungeoneer IDs on one board, a deleted best promoting the next run (Review Focus 4), the cache dropped on `RUN_SAVED` / `RUNS_CHANGED`, `Delta` against the best before a run, pruning (keep 0, best holders, running and stopping runs kept) on `RUN_SAVED`, at `OnEnable` and never while disabled |
| `test_race` | `modules/Race.lua` on a fake clock: arm refusals (combat, pending, busy, meter unavailable, length), the start on the session event, the session-ID capture (never an arm-time session), the buzzer and `RACE_BUZZER`, late-cast grace edges, incomplete and died runs, the read gated on combat end and 2.5s of quiet, the read by ID never Current, tail and restart, lost runs (reset, session gone, sealed, raising), the list fallback, cancel, the diagnostics line |
| `test_race_resume` | `Race.Resume` from `OnEnable`: running past the buzzer becomes stopping and reloaded, running before it keeps its remaining time, stopping out of combat reads at once, in combat waits, a session gone is lost, an older unresolved run is settled |
| `test_format` | `modules/Format.lua`: the one formatter (the client's, checked before it is trusted; a secret never meets Lua arithmetic), the clock, length, percentage and offset text, typed race lengths, the Arm refusal lines |
| `test_hud` | The Race HUD on the race fixture with `tests/mock_widgets.lua`: the body for each of the six states, the idle Arm refusal and picks, the live breakdown under secret values at 4 Hz (no %, Blizzard's order, no geometry read, a missing DPS figure), reads stopping when hidden or past the buzzer, the stop and waiting figures and the drop-combat hint, the result card's % and best-delta and flag chips, a lost run, the countdown cue and the buzzer's raid warning, the window (Escape, close, grip, skin, lock, scale, drag, reset, visibility, onArm/always), test mode's `Render`, the stand-down, the library-absent load |
| `test_chart` | The damage chart and the pace bar (#2, #3): the bucket count and boundaries, `Slices.Capture` copying the very handle of the first read at or after each boundary (identity, never a value; none filled early; a late boundary and a shared session left empty; a nil read keeping a boundary open), `Drawable`, the pace math; on the race fixture: each column holding its boundary's handle, scale B (the live total as a secret range, no line, no diagonal, no pace bar) and scale A (the best x 1.15, its pace diagonal and no best line or label, the pace bar's range and handle), the columns' whole-pixel edges (`ColumnEdges`, touching, the gap off all but the last), *Column gap* and *Chart background* reaching the drawn chart, the pace bar's own look, hidden on a shared session, the two settings, a quiet stretch filled by the bucket timer and the last bucket by the buzzer's read, the chart stepping aside at the minimum height, the overlay's level band, the result card and the Results detail drawing the in-session slices to the plain final damage and nothing after a `/reload` or for a lost run, test mode's sample chart, no geometry read, and the diagnostics line counting the loadout store and the races holding a chart |
| `test_pace` | The pace bar's range and tick (#3, 2026-10-25): *Pace bar range* (`live.paceRange`, 1.5 by default) driving `PaceMax`, read at call time and clamped to 1.1-3.0, the tick at 1/range of the bar's configured width in whole pixels (`TickX`), the running bar's tick and range following the setting with no geometry read. Peeled out of `test_chart` for layout-§1's cap |
| `test_countdown` | `modules/Countdown.lua` on the race fixture with `tests/mock_widgets.lua`: 10..1 one per second and gone at the buzzer, its own `FULLSCREEN` mouse-off frame built lazily, the pop animation per number, the BigGold texcoords and the font fallback, `finalCountdown` 3, switched off (never built) and switched off mid-count, the HUD closed, one cue per second with no double, the cue off, cancel at 5 s left, combat ending early, the `/reload` resume at 4 s left (4, 3, 2, 1), before the window and past the buzzer, test mode's silent demonstration ending with its buzzer and with test mode, the no-pull-timer fence, the diagnostics line |
| `test_layers` | Where each frame sits (frame-layering): `NS.Constants.LAYERS` keyed by the standard's tier keys; no strata string or bare level number at an addon call site; the Race HUD MEDIUM, toplevel and clamped; the Results window HIGH, toplevel and clamped; the detail pane at body + `LEVEL.DETAIL`, over the Runs pane at body + 1, its children born in its band and under the grip; the countdown FULLSCREEN, out of the menus' strata |
| `test_results` | The Results window with `tests/mock_widgets.lua`: the run list's columns (date, class and spec icons, class-colored character, ilvl, the category badge, length, damage, DPS, the flag mark), incomplete and lost rows, every filter (pure and through the bar), sorting (date by default, DPS, ilvl, direction), pooling and scroll, the detail (breakdown sorted with %, header, the timing strip's positions, flags with spell names and the session matched by list), delete behind its confirmation, the 200-character note, Share and the row's right-click menu (Add Note, the Share submenu, Compare With This Run, Delete), the Bests board and *Clean runs only*, redraws on `RUN_SAVED` / `RUNS_CHANGED`, the *Current character* / *Current spec* defaults, every cell's and header's tooltip and the tooltip's side, the *Note* column (cut to 10 characters, its tooltip, its sort), the detail's section headings (FONT.SECTION, *Spell breakdown* over the compare, the *Note* heading, the larger header without the spec text), the *v/s Max* column per target type, the Damage and DPS bars, *Only best*, the window (Escape, close, grip, bounds, skin, drag, size, Master scale, reset), the expanded and collapsed views and their toggle, the collapsed view's back control, the stand-down, the library-absent load, the diagnostics line |
| `test_results_fit` | The Results lists' widths against their content, by the table's own estimate (`ResultsTable.BadgeWidth`, 6 px a character): every Runs column fits the narrowest list either view lays out, the longest Status board (*single target · 10:00*) fits after the boxed *Spec best*, the Bests *Flags* chips are plain with a two-flag chip inside their column, and the Runs filter bar (`ResultsRuns.BarPlan`, planned from the configured widths) ends inside both views' minimum width |
| `test_results_group` | The Runs list's *Group by* and its saved view: the character, class and spec, and target modes and their folding headers; *Duration* (one group per race length, shortest first, the time in its length color, a run with no length last, under a dash rather than *0:00*) and *Target + duration* (one group per target type and length, the catalog's order then shortest first); the fold keys (`length:60`, `cleave|60`) holding across a redraw and a mode switch, never reaching another mode; the grouped column's header flipping the groups' order; *Save*, *Reset* and *Clear*, the duration modes among the saved views. Peeled out of `test_results` for layout-§1's cap |
| `test_compare` | The run detail's compare (`modules/Results_Compare.lua`, #7): `CompareSpells` (matching by id, one-sided spells, the order, zero totals, duplicated ids), the figures and their % difference, the other run (the board's best, the runner-up for the best itself, none alone on a board, a lost run, a picked run on another board, a pick deleted), the toggle drawing the score table and the compared breakdown in the plain one's place, the row menu's *Compare With This Run* (grayed on the run shown and a lost run), the different-board note, *Clear Pick*, every part's tooltip, the collapsed view, and no geometry read |
| `test_loadout` | Equipment and talents (#6): `Recorder.SnapshotLoadout` (every equipped link but the shirt and tabard; the saved loadout's name, else the active config's; the hero tree and the import string; a client without the APIs or one that raises; no secret reaching it), the djb2 hash, `Loadouts.Store` keeping each set once and telling a hash collision apart, `Of`, the orphan sweep after `Delete`, `DeleteAll` and `Prune` (a later-format run keeping its sets), the format 2 migration leaving old runs alone, the race keeping the combat-end snapshot over the arm-time one (and a resumed run still taking one), the detail's gear grid and talents line (the client's tooltip, the modified click, *Not recorded*, *View* posting the talents link to chat and never reaching `SetItemRef`, *View* grayed on a moved serialization version, *Copy*), the compare's changed slots and *Different loadout*, the Spec cell's tooltip, and *Include talents link* on the share and on the History tab |
| `test_schema` | The schema's shape, the write seam, the Master controls rows, the minimap row, resets, test mode, migrations, the panel |
| `test_settings` | The settings pages (spec §6.3): the stored-setting guard (every stored path with its type, default and range pinned, so a layout pass cannot move a key or drift a default); every row's default, enUS label and tooltip, every row on a drawn page; the Race page (presets, cue, buzzer, grace 0-5 step 0.1, restart gap 3-15, hint delay; one tab, its row order, subsections and line starts pinned), the HUD page's Race HUD tab (`always` opens the HUD; the race clock's three modes; the live breakdown's rows 3-15, reads 2-10, icons and live DPS, each redrawing the HUD; its row order, subsections and line starts pinned; the show mode's General visibility sentence), the HUD page's two tabs in order and its Defaults tooltip, General's Defaults tooltip (Master controls, no HUD); grace not re-grading a saved run; the panel's page order and quiet renders; History's stored count, *Purge history…* last with no heading over it, behind its confirmation and refused during a race, *Runs to keep*'s account-wide lead, and *Runs to keep* never pruning on the spot |
| `test_slash` | The dispatcher: help, aliases, enable/disable, debug, perf, the schema CLI, the library-absent load; the feature verbs in order, `arm` (90, 1:30, 3m; 0 and 901 refused; the last length; a refusal line), `cancel`, `target` (name, creature ID, category), `hud show/hide/toggle`, `results [bests]`, `test`, `lock`/`unlock`, `/dr` and `/dpsrace` both dispatching, every feature verb's one disabled line, and the Arm or cancel key (never discarding a pending result) |
| `test_share` | `modules/Share.lua`: `Share.Line` against the mockup's line (count, uncataloged target, incomplete, no chat escape), a lost run, the refusal in combat (at the prompt and at the send), the channel menu with the channels the player is not in grayed, the whisper prompt, the *Armed* line and the score line printed once per result |
| `test_preview` | `modules/Preview.lua` on the race fixture with the widget recorder: the scripted race armed → running → stop → waiting → result through the HUD's bodies and never a stored run, the countdown and live figures, the result card, the test strip (and the title marker with no Widgets library), arming a real race ending it, a refused start in combat and during a race, combat ending it, the HUD it opened closed again, a restart, *Reset all settings* ending it, the stand-down |
| `test_launcher` | The launcher object, its clicks and menu, the minimap button, the three key bindings |
| `test_keybinds` | `NS.BINDINGS` in `Bindings.xml`'s order; `Bindings.xml` through the kit's `assertBindingsXml` (category, no header, no default, labels, the brand); the General page's last tab, *Keybindings*; its rows and labels; a key bound through the tab (`keybindThroughTab`) read back by `GetBindingKey`, and one set by `SetBinding` shown after `UPDATE_BINDINGS`; the combat refusal; the Defaults tooltip's *Key bindings are not changed.* |
| `test_disabled` | All ten steps of slash-commands-§7, a probe feature verb and a bus receiver on both load arms; the race watchers hold nothing and the race does nothing while disabled or perf-suspended, and the stand-up resumes a stored run |
| `test_surface_parity` | Each degradation stub against the live library surface it stands in for, every adopted module on both arms (the Widgets seam included), and the schema row counts with the hollow-composer delta (testing-§8, options-ui-§1) |
| `test_perf_harness` | The Perf descriptor, every declared bucket (`combatEvent`, `raceEvent`, `hudLive`, `hudTick`) reached by a real bracket, and the perf hold making the addon inert |
| `test_loadorder` | The runner's load list against a fresh TOC derivation: order, files on disk, no `libs/` path (testing-§9) |
| `test_vendor_sync` | The vendored payloads against the tag (delegates to `tests/_kit/vendor_sync.lua`) |
| kit: `test_eol`, `test_prose`, `test_layout_cap`, `test_diagnostics_contract`, `test_lizard_sighted` | Line endings, US spelling, the 1500-line cap, the diagnostics contract, the complexity sanitizer |


## Inventory and badge

[`test-cases.md`](test-cases.md) is generated by `--list` and is the authoritative pass count. When a
case is added, removed or renamed, regenerate it and update the README `[tests]` badge in the same
change (testing-§5). A declared skip is listed with its reason and counted in neither figure.

## In game

Behavior a headless run cannot reach (rendering, the real meter, taint) is covered by
[`smoke-tests.md`](smoke-tests.md), run by the owner before release as one end-of-run checklist.
Its section 9 lists every client assumption the build rests on, each with a pass criterion and what
to report when it fails; a failure becomes a GitHub issue named with the row's ID.
