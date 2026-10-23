# Ka0s DPS Race — PvE v0.1.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship v0.1.0 of Ka0s DPS Race: a timed DPS race against training dummies, with a live HUD, a run history and personal bests. Built from `C_DamageMeter` only, and compliant with the Ka0s WoW Addon Standard from the first commit.

**Architecture:** An Ace3 addon in the standard's modular layout (`core/ defaults/ modules/ settings/ locales/`), consuming LibKa0s v1.76.0 for its shared subsystems (chat, debug console, options, slash, launcher, perf, windows, pools). The **engine** has four parts:
- one secret-safe meter adapter (`Meter`);
- pure timing and scoring logic (`Timeline`, `Scoring`, `Bests`);
- a lifecycle state machine driven only by events and `GetTime()` (`Race` + `Watchers`);
- persistence (`Recorder`).

The **UI** (HUD, Results window, settings pages) listens on the message bus and never decides anything from a meter value.

**Tech Stack:** Lua 5.1 (WoW Retail 12.0.5, Interface 120105), Ace3, LibKa0s v1.76.0, LibDataBroker / LibDBIcon / LibSharedMedia, the headless LibKa0s test kit (`lua tests/run.lua`), luacheck, lizard.

**Spec:** [`docs/superpowers/specs/2026-10-23-dps-race-pve-design.md`](../specs/2026-10-23-dps-race-pve-design.md). Mockups are in [`docs/brainstorm/mockup/`](../../brainstorm/mockup/README.md); `screens/*.png` is the visual reference for every window.

**Standard:** the local checkout `../WowAddonStandards` (v2.87.0): `NEW_ADDON.md`, `standards/STANDARDS.md`, `standards/NEW_ADDON_CONTEXT.md`. Read the context pack from there, **never copy it into the repo**. The sibling **`../MultiMeters`** is the reference implementation for the meter adapter, secret guards, window, settings and test mocks. Copy its *patterns*, never its files wholesale.

---

## Execution model (resumable, checkpointed)

- **Branch:** all work goes on `feat/pve-v0.1.0`, cut from `main`. Nothing is merged without the owner's go-ahead.
- **Milestones = workflows.** M1–M4 below each run as one workflow:
  - one implementer agent per task, in order;
  - then an adversarial review of the milestone diff;
  - then a fix pass;
  - then a push to `origin/feat/pve-v0.1.0`.
- **Commit gate (every task):** `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` exits 0, **and** `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .` is clean. Each task is one or more commits, Conventional-Commit style, ending with the session's attribution lines.
- **Checkpoint ledger:** the table below is the single source of resume truth. A task's row is ticked in the same commit that completes it. To resume, find the first unticked row and check `git log` for its commits.
- **No in-game steps during the build.** Everything verifiable headlessly is tested. Everything else lands in `docs/smoke-tests.md` for the owner's end-of-run pass (O1–O7 in the spec's §12).

### Status ledger

| Task | Milestone | Status |
|---|---|---|
| T1 Scaffold (born compliant) | M1 | [x] |
| T2 Secrets + Meter adapter | M2 | [x] |
| T3 Dummy catalog + Recorder | M2 | [x] |
| T4 Timeline + Scoring (pure) | M2 | [x] |
| T5 Race state machine + Watchers | M2 | [x] |
| T6 Bests + pruning | M2 | [x] |
| T7 Race HUD | M3 | [x] |
| T8 Results window | M3 | [x] |
| T9 Settings pages, slash verbs, Share, Preview, key bindings | M3 | [x] |
| T10 Docs, README, smoke tests, automated-test bundle | M4 | [ ] |
| T11 Whole-branch review + fixes | M4 | [ ] |

## Global Constraints

- Folder `DpsRace`. TOC `## Title: Ka0s DPS Race`. `## Interface: 120105` (one line). Author `add1kted2ka0s`. MIT. `## Version: 0.1.0`.
- SavedVariables: `DpsRaceDB` (AceDB) and `DpsRacePerfDB`.
- Slash: **`/dr` and `/dpsrace`**, both registered. The standard expects a 2–3 character slash, and `/dr` is that one.
- **`modules/Meter.lua` is the ONLY file that calls `C_DamageMeter`. `core/Secrets.lua` is the ONLY file that inspects a value that may be secret** (asks whether it is secret or accessible, or converts it to a plain number). Everywhere else, a meter value is an opaque handle passed to a widget setter or `NumericRuleFormatter:FormatNumber`.
- No decision is ever made from a meter value in combat. Decisions come only from events and `GetTime()` (spec §8 rule 2).
- Layout is computed from config. **No `GetWidth`/`GetHeight`/`GetPoint`/`GetLeft` on any frame that has received a secret** (spec §6.1).
- Every event registration goes through `NS.SafeRegisterEvent` (LibKa0s-Core).
- Every authored `.lua` opens with `local addonName, NS = ...` (or `local _, NS = ...`), then a one-line path-and-purpose comment. No file over 1500 lines.
- Scoring values, verbatim from the spec:
  - **grace default 1.0s**, range 0–5, step 0.1;
  - **restart gap default 6s**, range 3–15;
  - **quiet-before-read 2.5s** (constant);
  - **sticky-combat hint default 15s**;
  - **live reads 4 Hz** default, range 2–10;
  - **live rows default 8**, range 3–15;
  - **Runs to keep default 0 = never prune**, range 0–10000;
  - race-length presets `30, 60, 120, 180, 300` s plus custom `10–900` s.
- **DPS = damage ÷ race length** for a complete run; **÷ (combat end − start)** for an incomplete one. Blizzard's `amountPerSecond` is stored as `meterDps` and never ranked.
- Damage that lands after the buzzer counts. Late casts and restarts are **flags, never voids**. `incomplete` and `lost` runs never count toward bests.
- Vendor LibKa0s from the **tag** `v1.76.0` of `../LibKa0s`, using `git -C ../LibKa0s archive v1.76.0 LibKa0s testkit`. Its working copy is on a feature branch and must not be copied.
- Copy Ace3, LibStub, CallbackHandler, LibDataBroker-1.1, LibDBIcon-1.0, LibSharedMedia-3.0 and AceGUI-3.0-SharedMediaWidgets from `../MultiMeters/libs/`.

## Review Focus

1. **Arming in combat, or while a pending result is still waiting.** Arm must refuse with a reason. It must never start a run that could capture another fight's session. → T5 test `arm refuses in combat and while a run is pending`.
2. **The buzzer fires while a `/reload` is in progress, or a run is resumed with no session in the list.** The run must end `stopping` + `reloaded`, or `lost`. It must never hang in `running`. → T5 tests `resume: running past buzzer becomes stopping+reloaded` and `resume: session gone becomes lost`.
3. **A secret slips into arithmetic or a comparison on the live path** (for example, live DPS formatted with `%.1f`, or a `>` in the breakdown). → T2 test `live read never performs arithmetic on secrets` (opaque secret mocks that raise on arithmetic and comparison), and T7 test `hud running render raises nothing with secret values`.
4. **Two characters share a spec and category, and one deletes its best.** Bests must recompute, and pruning must never delete a run holding a best. → T6 tests `deleting a best promotes the next run` and `prune keeps best-holding runs`.
5. **Grace edges:** a cast started before the buzzer that finishes after it; a cast at exactly buzzer + grace; an instant with no START event. → T4 tests `late cast boundaries`.

---

## File map

```
DpsRace.toc · Bindings.xml · .gitattributes · .luacheckrc · .pkgmeta · LICENSE · README.md · CLAUDE.md · DEPENDENCIES.md
libs/                       vendored (T1)
locales/enUS.lua            every label/desc key (all tasks append)
core/                       scaffold setup files (T1); Secrets.lua (T2); Bus.lua message names (T1, extended in T5)
defaults/Profile.lua        profile defaults (T1, extended in T9)
defaults/Dummies.lua        dummy catalog (T3)
modules/Meter.lua           C_DamageMeter adapter (T2)
modules/Recorder.lua        metadata snapshots, run store, resume list (T3)
modules/Timeline.lua        damage-update timeline: tail, restart, quiet (T4)
modules/Scoring.lua         late-cast rule, DPS, flag set (T4)
modules/Race.lua            state machine, clock, buzzer (T5)
modules/Watchers.lua        event wiring into Race (T5)
modules/Bests.lua           personal bests, deltas, prune protection (T6)
modules/Hud.lua, Hud_States.lua, Hud_Breakdown.lua   Race HUD (T7)
modules/Results.lua, Results_Runs.lua, Results_Detail.lua, Results_Bests.lua   Results window (T8)
modules/Share.lua, modules/Preview.lua, modules/Diagnostics.lua   (T9 / T1)
settings/OptionsSetup.lua, General.lua, Race.lua, Live.lua, History.lua, Profiles.lua, Slash.lua, Schema*.lua
media/logos/dpsrace.logo.128.tga + dpsrace.logo.png   (T1 placeholder)
tests/                      run.lua, wow_mock.lua, mock_meter.lua, test_*.lua; _kit/ vendored
docs/                       ARCHITECTURE.md + tier docs (T1, completed in T10)
probe/                      unchanged, excluded from packaging by .pkgmeta
```

---

## M1 — Scaffold

### Task 1: Scaffold the addon, born compliant

**Files:** everything `NEW_ADDON.md` steps 0–7 create, under the identity above. In particular:
- `.gitattributes` (the context pack's snippet, verbatim), followed by `git add --renormalize .`, because the repo already has two commits;
- `DpsRace.toc` and the `core/*Setup.lua` files (Media, Env, Pool, Core, Lifecycle, Perf, DebugLog, Launcher);
- `core/Bus.lua`, `core/Constants.lua`, `core/Namespace.lua`, `core/Database.lua`, `core/Compat.lua` (only if a version-variant call is owned);
- `defaults/Profile.lua`, `locales/enUS.lua`;
- `settings/OptionsSetup.lua`, `settings/General.lua` (the *Master controls* tab), `settings/Profiles.lua`, `settings/Slash.lua`;
- `modules/Diagnostics.lua`, `Bindings.xml`;
- `tests/run.lua`, `tests/wow_mock.lua`, `tests/test_surface_parity.lua`, `tests/test_vendor_sync.lua`, `tests/test_disabled.lua`;
- `.luacheckrc`, `.pkgmeta` (ignores `probe/`, `docs/`, `tests/`);
- root `README.md`, the `CLAUDE.md` stub (with the LibKa0s provenance and icons lines), `DEPENDENCIES.md`;
- the `docs/` trio, the six Tier-1 docs, `docs/debug.md`, `docs/performance.md`, `docs/perf-analysis/README.md`.

**Interfaces — Produces:**
- `NS.db` (AceDB: `profile`, `global`); `NS.db.global.runs = {}` (keyed by run id); `NS.db.global.schema = 1`.
- `NS.Bus` with message constants in `NS.MSG`: `RACE_STATE_CHANGED`, `RUN_SAVED`, `RUNS_CHANGED`, `SETTINGS_CHANGED`.
- `NS.Print`, `NS.Debug(tag, msg)`, `NS.DebugOnce`, `NS.SafeRegisterEvent(frame, event)`, `NS.MakeCloseButton(parent, onClick)`, `NS.ApplySkin(frame)`, `NS.Icon(name)`, `NS.MediaFont(name)`, `NS.Perf`, `NS.Lifecycle`.
- `NS.COMMANDS` (ordered), with the scaffold rows `config`, `enable`, `disable`, `debug`, `diagnostics`, `perf`. T9 appends the feature rows.

Steps:
- [ ] **Step 1:** (The branch `feat/pve-v0.1.0` already exists and carries this plan.) Write `.gitattributes`, run `git add --renormalize .`, and commit `chore: pin line endings (.gitattributes)`.
- [ ] **Step 2:** Vendor the libraries:
  - `git -C ../LibKa0s archive v1.76.0 LibKa0s testkit | tar -x -C <scratch>`;
  - copy `LibKa0s/` to `libs/LibKa0s/` and `testkit/` to `tests/_kit/`;
  - copy the Ace3 and other libs from `../MultiMeters/libs/`;
  - prune `libs/LibKa0s/media/icons/` to the declared set: `close, copy, clear, settings, lock, unlock, chat, sort-down, sort-up, info, reset, confirm, export`, using the tag's own `tools/prune-icons.lua`.

  Commit `chore: vendor Ace3 stack and LibKa0s v1.76.0`.
- [ ] **Step 3:** Generate the placeholder logo with Pillow: a 2000×2000 PNG of a gold stopwatch with a flame on the Ka0s dark background (`#0f0f14`, gold `#ffd100`). From it make `media/logos/dpsrace.logo.png`, the 128×128 uncompressed 32-bit `dpsrace.logo.128.tga` (layout-§4 recipe), and the larger landing asset.
- [ ] **Step 4:** Write the skeleton, the setup files and the first settings page, following `NEW_ADDON.md` step 4 and the context pack's starter snippets:
  - launcher label `Ka0s DPS Race`;
  - launcher menu: Enabled · Lock HUD · Test mode · Show race HUD · Show results;
  - a key binding for each window.
- [ ] **Step 5:** Write the tests the playbook names, plus `tests/test_skeleton.lua`. That suite asserts four things: the addon registers; `/dr` and `/dpsrace` both route to the dispatcher; the DB defaults load; `NS.MSG` holds the four names. Run the commit gate. Expected: PASS, luacheck clean.
- [ ] **Step 6:** Write the docs set (`NEW_ADDON.md` steps 6–7). Feature sections stay short, each with a pointer to the spec; T10 completes them. Commit `feat: scaffold Ka0s DPS Race (born compliant)`.

---

## M2 — Engine

### Task 2: Secret guards and the meter adapter

**Files:** Create `core/Secrets.lua`, `modules/Meter.lua`, `tests/mock_meter.lua`, `tests/test_secrets.lua`, `tests/test_meter.lua`. Modify `DpsRace.toc`, `tests/run.lua`.

**Interfaces — Produces:**
- `NS.Secrets.IsSecret(v) -> boolean` · `CanAccess(v) -> boolean` · `CanAccessTable(t) -> boolean` · `PlainNumber(v) -> number|nil` · `SafeIterate(arr, fn(i, e)) -> count`. `SafeIterate` uses no `#` or `ipairs`, is bounded at 512, and stops at the first nil. The guards are the LibKa0s-Compat ones, with a stub arm (MultiMeters `core/Secrets.lua` is the pattern).
- `NS.Meter.IsAvailable() -> ok:boolean, reason:string|nil`.
- `NS.Meter.ReadLive() -> live|nil`, where `live = { total, dps, maxAmount, spells = { {spellID, total, dps}, ... } }`. Every value is opaque. It reads the Current session's DamageDone source for `UnitGUID("player")` and keeps Blizzard's order.
- `NS.Meter.ReadSession(sessionID) -> result|nil, err`, where `result = { damage, meterDps, duration, spells = { {id, dmg, dps}, ... } }`. Every value is a plain number. Spells are sorted by `dmg` descending. It returns `nil, "sealed"` if anything is still secret.
- `NS.Meter.SessionIDs() -> { [id] = true }` and `NS.Meter.HasSession(id) -> boolean`.
- `NS.Meter.STAT_DAMAGE_DONE` (from `Enum.DamageMeterType.DamageDone`, falling back to 0) and `NS.Meter.SESSION_CURRENT` (falling back to 1).

Steps:
- [ ] **Step 1:** Write `tests/mock_meter.lua`, a scripted `C_DamageMeter`:
  - `SetSession(id, {damage, dps, duration, spells})`;
  - `SetSecret(true|false)`, which wraps values in mock secrets taken from the kit's `secrets.lua` (`Kit.secret`, `Kit.installSecretValue`). These raise on arithmetic, comparison, `#` and concat-with-`table.concat`.
- [ ] **Step 2:** Write the failing tests:
  - `IsSecret/PlainNumber over plain, nil and secret`;
  - `SafeIterate stops at nil and at 512`;
  - `ReadSession returns plain sorted spells after combat`;
  - `ReadSession on a sealed session returns nil,"sealed"`;
  - `live read never performs arithmetic on secrets` (ReadLive under `SetSecret(true)` raises nothing, and every returned value `IsSecret`);
  - `IsAvailable passes Blizzard's failure reason through`.
- [ ] **Step 3:** Implement both files, using the call shapes in the spec's §3 table (MultiMeters `modules/Provider.lua` is the pattern). Add them to the TOC: `core/Secrets.lua` after `core/CoreSetup.lua`, and `modules/Meter.lua` first in `# Modules`.
- [ ] **Step 4:** Run the gate (PASS), then commit `feat(engine): secret guards and C_DamageMeter adapter`.

### Task 3: Dummy catalog and the Recorder

**Files:** Create `defaults/Dummies.lua`, `modules/Recorder.lua`, `tests/test_dummies.lua`, `tests/test_recorder.lua`.

**Interfaces:**
- Consumes: `NS.db.global.runs`, `NS.Bus`/`NS.MSG.RUN_SAVED`/`RUNS_CHANGED`.
- Produces:
  - `NS.Dummies.Lookup(npcID) -> {name, category, count}|nil`;
  - `NS.Dummies.CATEGORIES = { "single", "cleave", "dungeoneer", "boss", "pvp", "other" }`, with an `enUS` label for each;
  - `NS.Recorder.SnapshotPlayer() -> char` · `SnapshotTarget(unit) -> target` · `SnapshotWhere() -> where`. The shapes are exactly spec §7.
  - `NS.Recorder.NewRun(length, targetCount) -> run`, with `status = "armed"`, `id = time() .. "-" .. random`, `schema = 1`, and `race.grace` / `race.restartGap` copied from the profile.
  - `Save(run)`, which fires `RUN_SAVED`, and `Get(id)`.
  - `All() -> array`, newest first, excluding `armed` runs.
  - `Delete(id)` and `DeleteAll()`, which fire `RUNS_CHANGED`.
  - `Pending() -> array` of runs whose status is `running` or `stopping`.

Steps:
- [ ] **Step 1:** Seed the catalog from the spec's §4.6, verbatim:

  | Creature ID | Name | Category | Count |
  |---|---|---|---|
  | 243167 | Dungeoneer's Training Dummy | dungeoneer | 1 |
  | 243168 | Dungeoneer's Training Dummy | dungeoneer | 1 |
  | 243208 | Cleave Training Dummy | cleave | 1 (O7: the count is unmeasured) |
  | 243205 | Reinforced Golem | boss | 1 |
  | 243211 | PvP Training Dummy | pvp | 1 |

- [ ] **Step 2:** Write the failing tests:
  - `Lookup known and unknown npcID`;
  - `SnapshotTarget parses npcID from a Creature GUID and categorises unknown targets as other`;
  - `SnapshotTarget tolerates a secret GUID (records name, category other)`;
  - `NewRun copies grace and restartGap from the profile`;
  - `All orders by date desc and excludes armed`;
  - `Pending returns running and stopping only`;
  - `Delete fires RUNS_CHANGED`.
- [ ] **Step 3:** Implement both files. `SnapshotPlayer` uses `GetSpecializationInfo`, `GetAverageItemLevel` (stored to one decimal), `UnitRace` and `UnitLevel`. `SnapshotWhere` uses `C_Map.GetBestMapForUnit`, `GetZoneText`, `GetSubZoneText` and `GetInstanceInfo`.
- [ ] **Step 4:** Run the gate, then commit `feat(engine): dummy catalog and run recorder`.

### Task 4: Timeline and Scoring (pure logic)

**Files:** Create `modules/Timeline.lua`, `modules/Scoring.lua`, `tests/test_timeline.lua`, `tests/test_scoring.lua`.

**Interfaces — Produces:**
- `NS.Timeline.New() -> tl`, with these methods:
  - `tl:AddDamage(t)`;
  - `tl:LastDamage() -> t|nil`;
  - `tl:Tail(buzzer) -> seconds`: the last damage time minus the buzzer, or 0 if there is no damage after it;
  - `tl:RestartAt(buzzer, gap) -> offset|nil`: the first damage after the buzzer that follows a quiet stretch of at least `gap`, where the stretch starts at the previous damage or the buzzer, whichever is later;
  - `tl:QuietFor(now) -> seconds`: `now` minus the last damage time, or `math.huge` if there is none.
- `NS.Scoring.IsLateCast(startOffset, grace) -> boolean`: strictly `startOffset > grace`. Offsets are measured from the buzzer.
- `NS.Scoring.Dps(damage, run) -> number`: `damage / run.race.length` when `run.status == "complete"`, else `damage / run.result.endedAt`.
- `NS.Scoring.QUIET_BEFORE_READ = 2.5`.
- `NS.Scoring.Flags(run) -> array`, of `{key, text}` in the order: lateCasts, restarted, reloaded, died, incomplete, lost.

Steps:
- [ ] **Step 1:** Write the failing tests, using the probe's measured timelines as fixtures. Run 4: updates at buzzer −2.09, then +0.45, +1.04, +1.35, +2.47, +3.03, which gives tail 3.03 and no restart. Run 6: updates every ~2s up to +8.49, which gives tail 8.49 and no restart at gap 6.
  - `tail from probe run 4 = 3.03`;
  - `tail from probe run 6 = 8.49`;
  - `restart detected after 10s quiet at gap 6`;
  - `DoT ticks every 2s are not a restart`;
  - `QuietFor with no damage is huge`;
  - `late cast boundaries`: `IsLateCast(1.0, 1.0) == false`, `IsLateCast(1.01, 1.0) == true`, `IsLateCast(-0.2, 1.0) == false` (started before the buzzer), and an instant scored by its success offset;
  - `Dps complete = damage / length`;
  - `Dps incomplete = damage / endedAt`;
  - `Flags order and text`.
- [ ] **Step 2:** Implement both files: pure Lua, no WoW API.
- [ ] **Step 3:** Run the gate, then commit `feat(engine): timeline and scoring rules`.

### Task 5: Race state machine and Watchers

**Files:** Create `modules/Race.lua`, `modules/Watchers.lua`, `tests/test_race.lua`, `tests/test_race_resume.lua`. Modify `core/Bus.lua`.

**Interfaces:**
- Consumes: T2 (`Meter`), T3 (`Recorder`), T4 (`Timeline`, `Scoring`).
- Produces:
  - `NS.Race.STATE = { IDLE = "idle", ARMED = "armed", RUNNING = "running", STOPPING = "stopping", RESULT = "result" }`.
  - `NS.Race.State() -> state` · `Current() -> run|nil`.
  - `NS.Race.Arm(length, targetCount) -> ok, reason`. Reasons: `"in_combat"`, `"meter_unavailable"`, `"pending"` (a stopping run is unresolved), `"busy"`.
  - `NS.Race.Cancel()`, which in STOPPING discards the run.
  - `NS.Race.Elapsed() -> s|nil` · `TimeLeft() -> s|nil` · `SinceBuzzer() -> s|nil`.
  - `NS.Race.Resume()`, called from `OnEnable`.
  - Event inputs, called only by Watchers, with `t` from `GetTime()`:
    - `Race.OnSessionCreated(t)`;
    - `Race.OnMeterUpdate(statType, sessionID, t)`;
    - `Race.OnCombatStart(t)` / `OnCombatEnd(t)`;
    - `Race.OnCast(kind, spellID, t)`, where `kind` is `"start"`, `"channel"` or `"succeeded"`;
    - `Race.OnDeath(t)`;
    - `Race.OnMeterReset()`.
  - Bus: `RACE_STATE_CHANGED(run, from, to)`, plus T5's additions `RACE_BUZZER(run)` and `RACE_RESULT(run)`.

Steps:
- [ ] **Step 1:** Write the failing tests in `tests/test_race.lua`. They drive Race through its inputs with a fake clock; Watchers is not loaded for them.
  - `arm refuses in combat and while a run is pending`;
  - `arm refuses when meter unavailable`;
  - `session created starts the clock and persists the run as running`;
  - `sessionID captured from first DamageDone update with non-zero id`;
  - `buzzer at start+length moves to stopping and emits RACE_BUZZER`;
  - `cast started 0.5s after buzzer is not late at grace 1.0`;
  - `cast started 1.4s after buzzer is recorded as late with spellID`;
  - `cast that started before buzzer and succeeded after is not late`;
  - `combat end before buzzer -> incomplete with endedAt`;
  - `death -> incomplete, died flag`;
  - `result read only after combat end AND 2.5s quiet` (simulate an update at combat end + 1.3s and assert the read happens at +3.8s);
  - `read uses ReadSession(sessionID), never Current`;
  - `restart after a 10s gap sets flags.restartedAt`;
  - `meter reset while stopping -> lost`;
  - `cancel in armed/running stores nothing; cancel in stopping discards`.
- [ ] **Step 2:** Write the failing tests in `tests/test_race_resume.lua`:
  - `resume: running past buzzer becomes stopping+reloaded`;
  - `resume: running before buzzer keeps running with remaining time`;
  - `resume: stopping out of combat reads immediately`;
  - `resume: session gone becomes lost`.
- [ ] **Step 3:** Implement `Race.lua`. The buzzer is a `C_Timer.NewTimer`, cancelled on cancel or on combat end. Readiness is polled by a 0.5s ticker, which runs only in STOPPING. If the session ID is never captured, the run falls back to the newest session created after the start (by diffing `Meter.SessionIDs()` taken at arm against the current set) and adds the flag `sessionFromList` (spec §9).
- [ ] **Step 4:** Implement `Watchers.lua`. Through `NS.SafeRegisterEvent` it registers:
  - `DAMAGE_METER_CURRENT_SESSION_UPDATED`, `DAMAGE_METER_COMBAT_SESSION_UPDATED`, `DAMAGE_METER_RESET`;
  - `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `PLAYER_DEAD`;
  - `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_CHANNEL_START`, `UNIT_SPELLCAST_SUCCEEDED`, as unit events for `player`.

  Cast events are registered only while the state is RUNNING or STOPPING, and every registration is dropped when the run ends (performance; slash-commands-§7 disabled-state). On `OnCombatStart`, Race calls `Recorder.SnapshotTarget("target")`. Add a `test_disabled` step that asserts Watchers holds no registrations while the addon is disabled.
- [ ] **Step 5:** Run the gate, then commit `feat(engine): race lifecycle and event watchers`.

### Task 6: Bests and pruning

**Files:** Create `modules/Bests.lua`, `tests/test_bests.lua`. Modify `modules/Recorder.lua` (add `Prune`).

**Interfaces:**
- Produces:
  - `NS.Bests.Key(run) -> "specID|category|length"`.
  - `NS.Bests.Compute(runs, opts) -> { [key] = run }`. Only `complete` runs count, ranked by `result.dps`. `opts.cleanOnly` excludes runs with any flag.
  - `NS.Bests.Delta(run, runs) -> pct|nil, isNewBest`: compared with the best **before** this run.
  - `NS.Bests.HoldingIDs(runs) -> { [id] = true }`.
  - `NS.Recorder.Prune(keep) -> removedCount`. `keep == 0` is a no-op. Otherwise it removes the oldest non-holding runs until the count is at most `keep`.
- Pruning runs at `OnEnable` and on `RUN_SAVED`. The bests cache is invalidated on `RUN_SAVED` and `RUNS_CHANGED`.

Steps:
- [ ] **Step 1:** Write the failing tests:
  - `incomplete and lost never count`;
  - `cleanOnly excludes flagged`;
  - `two Dungeoneer npcIDs share one board`;
  - `deleting a best promotes the next run`;
  - `Delta reports new best and percentage vs previous best`;
  - `prune keep=0 removes nothing`;
  - `prune keeps best-holding runs`.
- [ ] **Step 2:** Implement, run the gate, and commit `feat(engine): personal bests and history pruning`.

**M2 milestone exit:** adversarial review of the M2 diff (secret-safety, lifecycle edges, resume), then fixes, then push.

---

## M3 — UI

Visual reference: `docs/brainstorm/mockup/screens/02–12*.png` and `index.html`. All windows:
- use `NS.ApplySkin` and `NS.MakeCloseButton`;
- are registered in `UISpecialFrames`;
- persist their position, size and scale in `db.profile.windows.<name>`;
- are clamped to the screen;
- pool their rows (LibKa0s-Pool).

Number text goes through one `NumericRuleFormatter` held in `modules/Format.lua`, which T7 creates.

### Task 7: Race HUD

**Files:** Create `modules/Format.lua`, `modules/Hud.lua` (shell, header, footer, state switching), `modules/Hud_States.lua` (the six bodies), `modules/Hud_Breakdown.lua` (pooled spell rows, live and result), `tests/test_hud.lua`.

**Interfaces:**
- Consumes: Race (state, timers), Meter.ReadLive, Bests.Delta, Scoring.Flags, `RACE_*` messages.
- Produces:
  - `NS.Hud.Show()`, `Hide()`, `Toggle()`, `IsShown()`, `SetLocked(bool)`;
  - `NS.Hud.Render(state, run)`, used by Preview;
  - `NS.Format.Number(v) -> string` (secret-safe), `NS.Format.Clock(seconds) -> "m:ss.t"`, `NS.Format.Pct(x) -> "27.6%"` (plain numbers only).

Steps:
- [ ] **Step 1:** Write the failing tests:
  - `hud switches body on RACE_STATE_CHANGED for all six states`;
  - `idle arm button disabled with reason in combat`;
  - `hud running render raises nothing with secret values` (the mock meter in secret mode, rendered at 4 Hz for 10 ticks);
  - `running body shows no percentage text`;
  - `result body shows % and the best delta chip`;
  - `waiting hint appears after hintDelay and names only owned drop-combat spells`. The candidates are checked with `IsPlayerSpell`: Feign Death 5384, Vanish 1856, Shadowmeld 58984, Invisibility 66;
  - `countdown cue plays at 10,5,3,2,1 and buzzer raises the raid warning only when enabled`;
  - `live reads stop when hud hidden or state leaves running`;
  - `layout never calls GetWidth/GetPoint on breakdown rows` (spy the mock frame).
- [ ] **Step 2:** Implement the HUD to the mockup:
  - default 300×360, minimum 260×240, resizable;
  - the countdown text updates from one `OnUpdate`, attached only in RUNNING and STOPPING, at 20 Hz;
  - live reads are coalesced from `DAMAGE_METER_COMBAT_SESSION_UPDATED` and throttled at `live.hz`;
  - bars use `SetMinMaxValues(0, maxAmount)` + `SetValue(total)`;
  - spell names come from `C_Spell.GetSpellName(id)` and icons from `C_Spell.GetSpellTexture(id)`, each pcall'd, with the icon left blank on failure (O2);
  - the result body shows the top 5 spells with %;
  - the buttons are Race again (`Race.Arm` with the last length), Details (`NS.Results.ShowRun(id)`), Share (`NS.Share.Prompt(run)`).
- [ ] **Step 3:** Run the gate, then commit `feat(ui): race HUD`.

### Task 8: Results window

**Files:** Create `modules/Results.lua` (shell, tab strip, lazy tabs), `modules/Results_Runs.lua` (filter bar + pooled sortable list), `modules/Results_Detail.lua` (detail pane: breakdown, timing strip, flags, note, share, delete), `modules/Results_Bests.lua`, `tests/test_results.lua`.

**Interfaces:**
- Consumes: Recorder (All/Get/Delete/Save for notes), Bests, Scoring.Flags, Share.
- Produces: `NS.Results.Show()`, `Hide()`, `Toggle()`, `ShowRun(id)`, `ShowTab("runs"|"bests")`.

Steps:
- [ ] **Step 1:** Write the failing tests:
  - `runs list columns: date, class icon, spec icon, character, ilvl, target, length, damage, DPS, flag`;
  - `filters: character, spec, category, length, date range, hide flagged, include incomplete`;
  - `sort by DPS desc default; by ilvl`;
  - `detail renders breakdown sorted with percentages`;
  - `timing strip positions buzzer, grace, tail, late casts, combat end`;
  - `delete asks confirmation then fires RUNS_CHANGED`;
  - `note limited to 200 chars`;
  - `bests tab groups by spec x category x length with clean-only toggle`;
  - `list refreshes on RUN_SAVED`.
- [ ] **Step 2:** Implement to `screens/08` and `09`:
  - default 1040×560, minimum 760×420;
  - the class icon is drawn from `CLASS_ICON_TCOORDS` on `Interface\GLUES\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES`, the spec icon from `GetSpecializationInfoByID(specID)`, and both have name tooltips;
  - below 900px wide, the detail pane replaces the list and gets a back control.
- [ ] **Step 3:** Run the gate, then commit `feat(ui): results window with history, detail and bests`.

### Task 9: Settings pages, slash verbs, Share, Preview and key bindings

**Files:** Create `settings/Race.lua`, `settings/Live.lua`, `settings/History.lua`, `modules/Share.lua`, `modules/Preview.lua`, `tests/test_settings.lua`, `tests/test_slash.lua`, `tests/test_share.lua`, `tests/test_preview.lua`. Modify `settings/General.lua`, `settings/Slash.lua`, `defaults/Profile.lua`, `locales/enUS.lua`, `Bindings.xml`.

**Interfaces:**
- Produces:
  - profile keys `race.defaultLength=180`, `race.countdownCue=true`, `race.buzzer=true`, `race.grace=1.0`, `race.restartGap=6`, `race.hintDelay=15`;
  - profile keys `live.rows=8`, `live.icons=true`, `live.showDps=true`, `live.hz=4`;
  - global key `history.keep=0`;
  - profile keys `hud.locked`, `hud.scale`, `hud.showMode="onArm"`;
  - `NS.Share.Line(run) -> string`, using the format in mockup `screens/12`;
  - `NS.Share.Prompt(run)`, a channel menu (say / party / raid / guild / whisper) that refuses in combat with a line;
  - `NS.Preview.Start()` / `Stop()` / `IsActive()`.
- `COMMANDS` rows to add: `arm [length]`, `cancel`, `hud show|hide|toggle`, `results`, `target`, `test`, `lock`, `unlock`. `arm` accepts `90`, `1:30` and `3m`.

Steps:
- [ ] **Step 1:** Write the failing tests:
  - `every schema row has default, enUS label and desc`;
  - `grace slider 0..5 step 0.1, restartGap 3..15, history.keep 0..10000 default 0`;
  - `changing grace does not alter saved runs`;
  - `slash arm parses 90, 1:30, 3m and rejects 0 and 901`;
  - `slash target prints name, npcID and category`;
  - `/dr and /dpsrace both dispatch`;
  - `feature verbs answer the enable line while disabled`;
  - `Share.Line matches the mockup format`;
  - `Share refuses in combat`;
  - `preview runs armed->running->stop->waiting->result and never writes a run`;
  - `arming a real race ends preview`.
- [ ] **Step 2:** Implement:
  - the pages use the tabbed renderer (options-ui-§13);
  - General's *Master controls* tab: Enable, General visibility, Master scale, Lock frame, Debug console, Minimap button, Test mode, Reset position, Reset all;
  - Race, Live breakdown and History pages per spec §6.3;
  - the scoring sliders carry the note *Applies to new runs.*;
  - History has *Runs to keep* and *Delete all runs…* (with confirmation);
  - Preview uses the LibKa0s `TestStrip` with the copy *Test mode: these numbers are not yours*;
  - `Bindings.xml` adds `DPSRACE_SHOW_HUD` and `DPSRACE_ARM_TOGGLE`.
- [ ] **Step 3:** Run the gate, then commit `feat(ui): settings pages, slash verbs, share and preview`.

**M3 milestone exit:** adversarial review of the M3 diff (secret-safety on UI paths, standard compliance of the windows and options, pooling and performance), then fixes, then push.

---

## M4 — Docs and release record

### Task 10: Docs, README, smoke tests and the automated-test bundle

**Files:** Modify `README.md`, `docs/ARCHITECTURE.md` and every Tier-1 and Tier-2 doc. Create `docs/smoke-tests.md` (in full), `docs/test-cases.md` (from `lua tests/run.lua --list`), and `docs/automated-tests/<stamp>/` with `RESULTS.md`.

Steps:
- [ ] **Step 1:** Write the README to documentation-§1's structure:
  - player-facing, `- ` bullet lists only, no logo, no library list;
  - Usage covers arming, the race, the buzzer rule, flags and the Results window;
  - the FAQ explains why there are no live percentages, why DPS is ours rather than the meter's, and sticky dummies;
  - Version History starts with `0.1.0`.
- [ ] **Step 2:** Write `docs/smoke-tests.md`. It holds the owner's end-of-run in-game checklist:
  - every HUD state on a real dummy;
  - O1–O7 from spec §12, each with pass/fail criteria and the fallback to note;
  - the reload-in-combat case;
  - the restart case (stop, wait 10s in combat, attack again);
  - the Results window, settings, `/dr` and `/dpsrace`, the launcher, key bindings, test mode, and disable/enable.
- [ ] **Step 3:** Complete `docs/ARCHITECTURE.md` (the hub, at most ~400 lines, including the Documentation map and the 1500-line census) and the tier docs: `scope`, `module-map`, `schema`, `settings-panel`, `data-flow`, `common-tasks`, `debug`, `performance`.
- [ ] **Step 4:** Run `tests/_kit/run-automated-tests.sh --release 0.1.0`, then write the bundle's `ANALYSIS.md` and the standing sections of `RESULTS.md`. Expected: lint, tests, perf and complexity all pass, with zero functions above CCN 15. If a function exceeds 15, split it and re-run.
- [ ] **Step 5:** Commit `docs: v0.1.0 README, docs set, smoke tests, automated-test record`, then push.

### Task 11: Whole-branch review and fixes

- [ ] **Step 1:** A fresh, independent review of `main..feat/pve-v0.1.0` against the spec and the standard. It looks for spec coverage, secret-safety, lifecycle edges, standard deviations, and dead or duplicated code.
- [ ] **Step 2:** Adversarially verify each finding, fix the confirmed ones, run the gate, commit, and push.
- [ ] **Step 3:** Hand over: the branch, test counts, the automated-test record, the smoke-test checklist, and the open items. **Do not merge.** The owner smoke-tests in-game, then gives the go-ahead.
- [ ] **Step 4 (after the go-ahead):**
  - merge into `main` with `git merge --no-ff` (versioning-git) and push; the branch name's
    `feat/<YYYY-MM-DD>-<topic>` shape is the owner's call before the merge (a rename only);
  - add the roster row to `../WowAddonStandards/standards/ADDONS.md`. That is a separate repo, so ask before committing there;
  - delete the branches, stashes and worktrees this run created.
