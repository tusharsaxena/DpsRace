# Ka0s DPS Race — PvE Design

**Status:** draft for review 2026-10-23 · **Target:** v0.1.0 · **Mockup:** [`docs/brainstorm/mockup/index.html`](../../brainstorm/mockup/index.html)

A timed DPS race against training dummies for Retail (Midnight, 12.x). You pick a length, target a
dummy, and the clock starts on the frame your first hit lands. When the buzzer goes you stop, and
the addon records your damage, DPS and full ability breakdown, plus who you were (class, spec,
item level) and where (zone, dummy). Every run lands in a history that can be browsed and compared.

Every number comes from Blizzard's built-in damage meter through `C_DamageMeter`. The addon never
touches the combat log, which addons cannot read in 12.0.

---

## 1. Scope

**In scope for v0.1.0**

- The **timed race**: most damage in X time, against any target, with special handling for known dummies.
- The **Race HUD**: setup, a live timer, a live ability breakdown, the buzzer, waiting for the result, and the result card.
- The **Results window**: run history with filters, run detail with the full breakdown and timing, and personal bests.
- Settings, launcher, slash commands, a preview (test) mode, and debug logging, all following the
  [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards).

**Out of scope**

| Item | Why |
|---|---|
| PvP burst race (duels, events, leaderboards) | Parked until the duel probe runs: [issue #1](https://github.com/tusharsaxena/DpsRace/issues/1). |
| "Time to deal X damage" | Can't be measured. A threshold crossing is a comparison on a secret value, and the meter keeps no timeline. Dropped on 2026-10-23. |
| A goal bar that fills to X damage | Dropped on 2026-10-23. |
| Sharing runs between players (guild boards, sync) | Phase 2. Addon messaging hasn't been measured yet (issue #1 covers it for duels). |
| Comparing two runs side by side | Phase 2. The run record (§7) already stores everything it needs. |

## 2. What the measurements say

Two probe passes (`probe/DpsRaceProbe/`, 8 runs on 2026-10-23, Silvermoon dummies) set what this
design can promise. Each rule below rests on a measurement, not on reading the documentation.

| Finding | Consequence for the design |
|---|---|
| Combat start, the first `DAMAGE_METER_CURRENT_SESSION_UPDATED` and the first hit land on the same frame. A cast-time opener starts the clock when it lands. | **The clock starts on the new-session event** (§4.2). It is frame-accurate. |
| Meter numbers are secret during combat **and stay secret if captured then**, even after combat. | There is **no exact cutoff at the buzzer**. The score is the session total read after combat (§5). |
| After combat everything can be read: the total, and per-spell `spellID`, `totalAmount` and `amountPerSecond`, already sorted highest first. Pet spells are merged into the owner. | The result card and run detail have the full breakdown, with percentages. |
| `GetCombatSessionFromID(sessionID)` after combat matched the current session in 4 of 4 runs, and the session ID can be read mid-combat. Sessions survive `/reload`. | **A result can be read later**, so a dummy that won't drop combat only delays it (§4.5). |
| `DAMAGE_METER_COMBAT_SESSION_UPDATED(type, sessionID)` tracks real damage, DoT ticks included. It went silent when damage stopped. | The addon can show **when your damage stopped**, and can notice damage that restarts (§5.3). |
| Players cast 1–3 spells in the 0.2–2s after the buzzer in every run. | Casts after the buzzer are **flagged after a 1s grace**, never voided (§5.2). |
| The DoT tail lasted up to 9.2s (Wither). Without DoTs it was about 3s. | The tail is **accepted and displayed** on every result. There is no minimum race length. |
| `durationSeconds` is whole seconds and runs until combat drops. The meter's `amountPerSecond` is diluted by the time it takes combat to drop (22k against 73k on a dummy that hits back). | **DPS = total ÷ race length**, computed by us from our own clock. Blizzard's DPS is stored for reference only. |
| Mid-combat, spell names display, and so do numbers via `string.format`. `spellID`, names and GUIDs are secret. | The live breakdown shows icon, name, bar and amount, **but no percentages** (§6.1). |
| `EnemyDamageTaken` merges identical dummies into one row. | **The target count can't be measured.** It comes from the dummy catalog or a manual pick (§4.1). |
| On a shared dummy, other players fire the target's `UNIT_HEALTH` before your first hit. | Target health is never used as a start signal. |

## 3. Vocabulary

- **Run:** one attempt, from being armed to having a result (or being cancelled).
- **Race length:** the length chosen at arming, e.g. 3:00.
- **Buzzer:** the moment the race length runs out.
- **Grace:** the window after the buzzer in which casts are not flagged. Default 1.0s, configurable.
- **Tail:** the time from the buzzer to the last damage update of the run's session.
- **Session:** the Blizzard meter session the run created, identified by `sessionID`.
- **Flag:** a mark on a result that a rule was bent. A flagged result is kept and counts, but shows the flag.

## 4. The race lifecycle

```
          arm (out of combat)                first hit (new meter session)
  IDLE ───────────────────────────► ARMED ─────────────────────────────────► RUNNING
   ▲  ◄──────────── cancel ─────────┘                                          │
   │                                                                     buzzer (clock)
   │                                                                          ▼
   │                                    combat ends + damage quiet       ┌──────────┐
   │   ◄── dismiss / race again ── RESULT ◄──────────────────────────── │ STOPPING │
   │                                                                    └──────────┘
   │                       combat drops before the buzzer: INCOMPLETE, kept, shown as such
   └───────────────────── cancel at any point: the run is discarded, nothing is stored
```

`STOPPING` is one state the player sees in two phases: *Stop!* (the first seconds after the buzzer)
and *Waiting for result* (when combat is still holding). There is no separate state for them, because
the rules don't change between the two. Only the HUD copy does.

### 4.1 IDLE → ARMED

- **Arming needs you out of combat.** The start signal is a *new* meter session, and none is created
  while you're already in combat. The Arm button is disabled with "Leave combat to arm" until
  `PLAYER_REGEN_ENABLED`.
- Arming is also refused, with its own line, while an earlier run is still waiting for its result,
  while the damage meter is unavailable (Blizzard's reason is shown), while the addon is disabled, and
  for a length outside 10s–15:00. A refusal never starts a run that could capture another fight.
- **Sessions that existed at arm time are never the run's.** Arming records the session IDs the
  client holds and the highest of them (`race.armMaxSession`, kept on the run so a `/reload` still
  knows it). Session IDs only grow, so any ID at or below the mark belongs to an earlier fight.
- **Race length:** presets 0:30 · 1:00 · 2:00 · 3:00 · 5:00 plus custom (10s–15:00). The last choice is remembered.
- **Target:** read from `target` at arm time and **re-read when combat starts** (the probe saw
  players arm on one dummy and hit another). The combat-start read is the one stored. The creature
  ID is looked up in the dummy catalog (§4.6). An unknown target is allowed and recorded as
  *Other: \<name\>*.
- **Target count:** filled in from the catalog (single = 1, cleave = the dummy group's size). It can
  be changed before arming. It is metadata only and never scored.
- Arming takes a snapshot of the **player metadata** (§7) while everything can still be read.

### 4.2 ARMED → RUNNING (the clock starts)

- **Start signal:** the first `DAMAGE_METER_CURRENT_SESSION_UPDATED` after arming, with the player
  in combat (`UnitAffectingCombat`) or `PLAYER_REGEN_DISABLED` arriving on the same `GetTime()` frame
  in either order. A session event out of combat with no regen edge on its frame does not start the
  clock. The start time is `GetTime()` at that event, kept on the run as `race.startedAt`, and the
  run's `date` is restamped to the start.
- **Session ID:** taken from the first `DAMAGE_METER_COMBAT_SESSION_UPDATED` with `type = DamageDone`
  and a non-zero `sessionID`.
- **The run is written to SavedVariables now**, with status `running`. A `/reload` mid-run therefore
  never loses the run (§4.5).
- Pre-casting and pre-potting are fine. The clock only starts when damage lands, the same rule as a real pull.
- If combat starts with no damage of yours (a mob aggroed you), the run carries on: the session will
  contain your damage once you hit something. Cancel is one click if that wasn't intended.

### 4.3 RUNNING

- The HUD shows the time elapsed (green) and the time left (red), to a tenth of a second, side by side or either alone (a setting), and the live breakdown (§6.1).
- An optional **countdown cue** plays at 10s, 5s, 3, 2, 1 (sound only; a setting, default on).
- A **center-screen countdown**, like Blizzard's `/pull 10` or the Mythic+ start: when
  *Countdown from* seconds remain (3–10, default 10), a large number pops in (scale and fade) in the
  middle of the screen each second down to 1, and goes at the buzzer; the buzzer's raid warning
  *STOP* and its sound stay. A setting, default on. While it shows, the cue sounds with each number,
  once a second at most. It is drawn on the addon's own frame with Blizzard's BigGold digit art
  (`Interface\Timer\BigTimerNumbers`), falling back to a large outlined number; nothing is sent to
  the group (no `C_PartyInfo.DoCountdown`) and no Blizzard timer handler runs. It shows whether or
  not the HUD is open, and a `/reload` inside the window resumes on the number of the moment.
- **Combat drops before the buzzer** (you stopped attacking, died, or the dummy reset): the run
  becomes `incomplete`. It is read and stored like any other, marked *Incomplete (combat ended at
  1:42)*, and **never counts toward personal bests**. Dying shows *Incomplete: died*.

### 4.4 Buzzer → STOPPING

- At `start + raceLength`, a raid-warning **STOP**, a sound, and the HUD switches to *Stop!*
- Cast tracking switches on (§5.2).
- Tail tracking switches on (§5.3).
- The HUD shows how long combat has lasted since the buzzer. After a configurable delay (default
  15s) it adds a hint: *Combat is holding: walk away, or use Feign Death / Vanish / Shadowmeld.* The
  hint names only the abilities the player actually has.

### 4.5 STOPPING → RESULT (reading the result)

- **Ready to read** = `PLAYER_REGEN_ENABLED` has fired **and** 2.5s have passed since the later of
  that edge and the last `DamageDone` update for this session. The probe saw updates up to 1.3s after
  combat ended, so the read always waits a full 2.5s past the edge.
- A read that finds the session still sealed is retried every 0.5s for up to 10s, then the run
  becomes `lost`. A missing session, an unavailable meter or a raising call makes it `lost` at once.
- The run is read **by its session ID** (`GetCombatSessionFromID` /
  `GetCombatSessionSourceFromID` with the player's GUID), never as "the current session".
- **Sticky combat** just means waiting. The HUD can be closed (and reopened with `/dr hud show`).
  The result card opens when it's ready, and the run lands in the Results window once it is read.
- **After a `/reload`**, `OnEnable` finds runs whose status is `running` or `stopping`:
  - Only the logged-in character's runs are resumed. Another character's pending run waits for
    that character's login.
  - A run that has passed its buzzer time and was not yet read (stored `running` or `stopping`) is
    `stopping`, with the flag *Reloaded mid-run: casts after the buzzer not tracked*: whatever was
    cast during the loading screen went unseen.
  - A `running` run found out of combat before its buzzer ended early: it becomes `incomplete`, with
    `endedAt` the time of the resume (an upper bound; the real combat edge was missed), and is read
    at once. It does not carry the *Reloaded* flag, because it never reached its buzzer.
  - The run's start is `race.startedAt` when it is not in the future, else it is derived from the
    epoch `date` (after a client restart). The tail and restart tracking resume from
    `race.lastDamage`, the offset of the last damage update heard before the reload. The loading
    screen is not a gap in the damage: the first update after the resume measures its quiet from
    the resume, so a long reload while DoTs tick never raises *Damage restarted*.
  - Only the newest pending run is resumed; an older one (an anomaly, since arming refuses while one
    is pending) is settled as `lost`.
  - If the player is still in combat, the addon waits for the regen edge as usual.
  - If combat already ended, it reads the run straight away.
  - If the session is gone (a logout, or `DAMAGE_METER_RESET`), the run becomes `lost` and the HUD
    says so. A lost run is kept, with its metadata, and has no result.
- **The meter is reset mid-run** (`DAMAGE_METER_RESET`): the run becomes `lost`.

### 4.6 The dummy catalog

A small table in `defaults/Dummies.lua`, keyed by creature ID. Entries are added from a measurement
(a probe run or `/dpsrace target`), never guessed.

| Creature ID | Name | Category | Default count | Measured |
|---|---|---|---|---|
| 243167 | Dungeoneer's Training Dummy | Dungeoneer (hits back) | 1 | 2026-10-23, Silvermoon |
| 243168 | Dungeoneer's Training Dummy | Dungeoneer (hits back) | 1 | 2026-10-23, Silvermoon |
| 243208 | Cleave Training Dummy | Cleave | 1 until the group is counted in-game (O7) | 2026-10-23, Silvermoon |
| 243205 | Reinforced Golem | Boss-level (level −1) | 1 | 2026-10-23, Silvermoon |
| 243211 | PvP Training Dummy | PvP | 1 | MultiMeters, 2026-09-26 |

Categories: **Single target**, **Cleave**, **Dungeoneer**, **Boss-level**, **PvP**, **Other**.
Personal bests are grouped by category, not by creature ID, so the two Dungeoneer IDs count as one board.

`/dpsrace target` prints the current target's name, creature ID and category, so the catalog can be
extended from a measurement in seconds.

## 5. Scoring

### 5.1 The score

| Field | Definition |
|---|---|
| **Damage** | The run session's `DamageDone` total for the local player (pets merged by Blizzard), read after the result is ready. **Damage that lands after the buzzer counts.** |
| **DPS** | Damage ÷ race length (from our own clock: exactly 180.0s for a 3:00 race). For an `incomplete` run, ÷ the time from the start until combat ended. |
| Meter DPS | Blizzard's `amountPerSecond`, stored for reference and never shown as the score. |

Ranking is by DPS. For a given race length it orders runs exactly as damage does, and it lets runs
of different lengths sit side by side in the history.

### 5.2 Casts after the buzzer (flag)

- Casts are judged from the buzzer until the result is read, using `UNIT_SPELLCAST_START`,
  `UNIT_SPELLCAST_CHANNEL_START` and `UNIT_SPELLCAST_SUCCEEDED` on `player`. A cast counts at its
  **start**. An instant has no start, so its success time is used. Starts are tracked from RUNNING on,
  so the success of a cast begun before the buzzer is recognized as that cast finishing.
- One cast is in flight at a time. A success is matched to it by castGUID, else spell ID, else
  assumed; `UNIT_SPELLCAST_INTERRUPTED` and `UNIT_SPELLCAST_CHANNEL_STOP` clear it. Auto-repeat
  successes (Auto Shot, a wand's Shoot) are never a press and never late. A sealed spell ID is stored
  as absent.
- A cast that **starts later than buzzer + grace** is a *late cast*. A cast that started before the
  buzzer and finished after it is never late.
- **Grace:** default 1.0s, configurable from 0 to 5s in 0.1s steps. The grace in force is stored on
  each run, so changing the setting never re-grades old runs.
- A late cast **flags** the run: *2 late casts (+1.4s Incinerate, +2.0s Conflagrate)*. It never voids it.

### 5.3 The tail and damage that restarts

- **Tail** = the last `DamageDone` update of the run's session after the buzzer, minus the buzzer
  time. It is shown on every result: *Damage stopped +3.1s after the buzzer*. A run with no update
  after the buzzer shows *+0.0s*.
- **Damage restarted:** a `DamageDone` update for this session that arrives after a **quiet gap of
  6s or more** (configurable 3–15s), once the buzzer is past. The flag reads *Damage restarted at
  +14.2s*. The default sits well above the ~2s DoT tick spacing the probe measured.
- The restart check is inferred from the probe, not measured: test D3 never happened. It is a smoke
  test before release (§12).

### 5.4 Flags, and what they do

| Flag | Raised when | Counts toward bests? |
|---|---|---|
| Late casts | §5.2 | Yes; the flag is shown on the board |
| Damage restarted | §5.3 | Yes; the flag is shown on the board |
| Reloaded mid-run | §4.5 | Yes; the flag is shown on the board |
| Session matched by list | §9 | Yes; the flag is shown on the board |
| Died | Death after the buzzer (before it, the run is incomplete) | Yes; the flag is shown on the board |
| Incomplete | Combat ended before the buzzer | **No** |
| Lost | The session couldn't be read | **No** (there is no score) |

The Results window has a **Hide flagged** filter, and the bests board a **Clean runs only**
toggle (off by default), so anyone running a fair race can exclude flagged runs.

## 6. User interface

All windows use the Ka0s window edge (`LibKa0s-Core-1.0` `ApplySkin`) and `MakeCloseButton`
through the addon's one wrapper. They are registered in `UISpecialFrames`, and position, size and
scale persist (standalone-windows). Layouts are in the mockup.

**Style (`modules/Style.lua`).** Both windows read like the other Ka0s windows, LootHistory's
browser above all (BankLedger and MultiMeters agree on the same points):

- **Font objects, not font files.** Each label takes one of Blizzard's font objects by its role:
  the title and the tabs `GameFontNormal`; column headers and section labels (*Race Length*,
  *Target*, *Timing*) `GameFontNormalSmall` in the header gold; rows, cells, buttons, presets,
  checkboxes, chips and the target card's text `GameFontHighlightSmall`; a name that heads a card
  `GameFontHighlight`; footers, KPI captions, clock captions and axis labels
  `GameFontDisableSmall`; an empty list's message `GameFontDisableLarge`.
- **What stays large.** The HUD's race clocks (the pair at 26 px, one clock at 40 px) and *STOP*
  keep their own monospace sizes, and the KPI figures (Damage, DPS, Meter DPS) take
  `GameFontNormalHuge` over a small gray caption, as LootHistory's Insights cards do.
- **Words.** Tabs, column headers, buttons, section labels and KPI captions are Title Case
  (*Arm Race*, *Race Again*, *Add Note*, *Damage Stopped*); prose is Sentence case. No label is
  upper-cased, the category badge and the flag words included (*Cleave ×5*, *1 late*). *STOP* is
  the one capitalized shout, and it is as big as the clock.
- **Sizes.** A 30 px title bar with the title centered in it; a 26 px tab strip of 90 px tabs on a
  94 px pitch; a 20 px table header over 20 px rows; 18 px spell rows on a 20 px pitch; 20 px
  buttons (Arm alone 24 px, in `GameFontNormal`); a footer of one small gray line.
- **Colors.** The header gold (`1, 0.82, 0`) for the title, the headers, the sort arrow, the
  active tab and its underline; the idle tab gray (`0.7, 0.7, 0.72`).
- **Title-bar controls.** The HUD's Results, settings, lock and close controls, and the Results
  window's close, sit vertically centered in the title bar, gray (`0.7, 0.7, 0.72`) at rest and
  the header gold under the pointer, at full alpha in both states (MultiMeters' header controls).
  One control is hovered at a time: a leave that arrives after the next control's enter leaves
  that control gold. Tooltips stay. The close control's gold replaces the library's red (see
  `docs/ARCHITECTURE.md`, *Documented deviations*).

### 6.1 Race HUD

A compact, movable window (default 300×460, minimum 260×296, resizable). It has one body per state;
the header and footer are shared. The default height shows all 8 default live rows (mockup screen
04); the minimum height is the chrome plus the idle body's fixed stack (Arm and the links under it).
A shorter window caps the live and result rows to what fits, never drawing them under the buttons.

| State | Body |
|---|---|
| **Idle** | Race-length presets and custom · target card (name, category badge, count stepper, *Unknown target* warning) · **Arm** (disabled in combat, with the reason) · links to the last result and to the Results window. |
| **Armed** | The big race length, unmoving, with *First hit starts the clock* · target card · **Cancel**. |
| **Running** | The race clock, by the *Race clock* setting: by default the time elapsed in green beside the time left in red, each `m:ss.t` (`0:18.7` · `2:41.3`) with an *Elapsed* / *Left* caption, sized so both fit the minimum width; or one big clock, the time left in red or the time elapsed in green · total damage and live DPS (Blizzard's live figure, labelled *live*: the source's `amountPerSecond`, else the player's own `combatSources` row, else the Dps meter type; the meter's rate, never the score) · live breakdown: the top N spells (default 8, configurable 3–15) as icon, name, bar and amount · **Cancel**. |
| **Stopping: Stop!** | Large **STOP** · *Damage stopped +x.xs* updating live · late-cast counter · *In combat +y.ys*. Shown while the last damage update is under 2.5s old. |
| **Stopping: Waiting for result** | *Waiting for combat to end* (in combat) or *Reading the result* (out of it) · elapsed time · the hint (§4.4) · **Discard Run** · the HUD can be closed. A run that ended before the buzzer comes straight here and shows when combat ended. |
| **Result** | Damage · DPS · delta to personal best (*New best +2.4%*, *New best* for a board's first run, or *−3.2% vs best*; words, because the client font may lack arrow glyphs) · flag chips (short labels; each chip's tooltip is the full flag text) · top 5 spells with % · **Race Again** (re-arms with the same length) · **Details** (opens the run in the Results window) · **Share** (prints the summary to a chat channel). |

**The live breakdown never sorts and never shows percentages.** Both are arithmetic on secret
values. Bars are drawn with `SetMinMaxValues(0, maxAmount)` and `SetValue(totalAmount)`, so the
widget does the scaling. The row order is the order Blizzard returns; after combat that is
highest first, and the in-combat order is an open item (§12). Amounts are formatted by
`NumericRuleFormatter`, which accepts secrets.

**Layout rule** (from MultiMeters): a frame given a secret through `SetValue` makes its own geometry
secret. So no layout reads geometry back off a bar row. All layout comes from config.

### 6.2 Results window

The primary standalone window (default 1040×560, resizable), with a tab strip and lazy-built tabs.

- **Runs:** a filter bar (character, spec, category, race length, date range, *Hide flagged*,
  *Include incomplete*) over a pooled, sortable list. Filters are view state, not settings: each
  login starts at *All* and *All time*, with *Include incomplete* on. The list shows resolved runs
  only; a running or stopping run is the HUD's. Columns: date · **class icon · spec icon** ·
  character (class-coloured) · **ilvl** · target (category badge, count) · length · damage · DPS ·
  flags. The class and spec icons have tooltips with their names, and ilvl is sortable. Clicking a row
  opens **Run detail** in the right-hand pane. On narrow windows the detail replaces the list, with a
  back control.
- **Run detail:**
  - Header: character, spec, ilvl, zone and subzone, target, date, game build, addon version.
  - Score block: damage, DPS, meter DPS (muted), personal-best delta.
  - **Ability breakdown**, matching your screenshot: icon, name, amount, %, bar, sorted highest first.
  - **Timing strip:** a horizontal timeline from the start to the result, with the buzzer, the
    tail, each late cast as a tick, and the end of combat.
  - Flags, with their explanations.
  - Note (free text, 200 chars; stored trimmed, control characters as spaces, `|` as `/` so no chat
    escape can reach a later share) · **Share** · **Delete** (with confirmation).
- **Bests:** the best run per **spec × category × race length**, across every character on the
  account. Filters are spec and category; the category filter shows one category at a time (no
  *All*), starting on the first present in catalog order. *Clean runs only* is off by default. Each row has the date,
  character, ilvl, damage, DPS and flags. Clicking one opens its run detail.

### 6.3 Settings (options-ui)

A landing page plus subcategories, built with AceConfig, using the standard's two-column layout,
section headers and global reset.

| Page | Settings |
|---|---|
| **General** | The standard's Master controls (Enable, visibility, scale and lock, which apply to the HUD; scale applies to the Results window too; test mode; the minimap button) · a *Race HUD* tab: show HUD on arm only / always · race clock: elapsed and time left (default) / time left / time elapsed |
| **Race** | Default race length (the presets) · countdown cue (on/off) · center-screen countdown (on/off) and *Countdown from* (3–10s, default 10) · buzzer sound and raid warning (on/off) · **late-cast grace (s)** · **restart gap (s)** · sticky-combat hint delay (5–60s) |
| **Live breakdown** | Rows shown (3–15) · live reads per second (2–10) · show spell icons · show live DPS |
| **History** | **Runs to keep:** 0–10000, **default 0 = never prune**. Above 0, the oldest runs are pruned first and a run holding a best is always kept · *Delete all runs* (with confirmation) |
| **Profiles** | AceDBOptions |

Grace and restart gap carry the note *Applies to new runs. Saved runs keep the value they were raced with.*

### 6.4 Launcher, slash commands and key binding

- **Launcher** (LibDataBroker + LibDBIcon, using the addon's own logo):
  - Left-click opens settings.
  - The right-click menu is `LibKa0s-Launcher-1.0`'s fixed set (launcher-§2): *Enabled*, *Locked*,
    *Test mode* and *Show window* (the race HUD). It takes no host entries, so there is no *Show
    results* or *Arm last race* item. The Results window is reachable from the HUD's title bar,
    `/dpsrace results` and its key binding; arming is the HUD's Arm button, `/dpsrace arm` and the
    *Arm / cancel race* binding.
- **Key bindings:** *Toggle race HUD* (the standard's *Show window* binding), *Toggle results
  window* and *Arm / cancel race*. The arm key arms the HUD's length, cancels an armed or running
  race, and never discards a run that is waiting for its result (it prints a line pointing at
  `/dpsrace cancel`).
- **Slash commands**: `/dpsrace` and `/dr`, dispatched through the standard's slash library and
  registered through AceConsole, as slash-commands-§1 prescribes. `/dr` is short and another addon
  may also register it; AceConsole does not check for that, so which addon answers `/dr` is then
  the client's choice. `/dpsrace` is this addon's own and always works.

| Command | Does |
|---|---|
| `/dpsrace` | Opens settings |
| `/dpsrace help` | The command index |
| `/dpsrace arm [length]` | Arms a race. `length` is `90`, `1:30` or `3m`; without it, the last length is used |
| `/dpsrace cancel` | Cancels the armed or running race, or discards a pending result |
| `/dpsrace hud show\|hide\|toggle` | The Race HUD; a bare `hud` toggles |
| `/dpsrace results [bests]` | Opens the Results window, on the Bests tab when asked |
| `/dpsrace target` | Prints the target's name, creature ID and catalog category |
| `/dpsrace test` | Preview mode (§6.5) |
| `/dpsrace lock` / `unlock` | The HUD position |
| `/dpsrace debug …` | Debug logging (LibKa0s debug console) |

The standard's own verbs (`config`, `enable`, `disable`, `list`, `get`, `set`, `reset`, `resetall`,
`diagnostics`, `perf`, `version`) are there too; `/dpsrace help` lists them all.

### 6.5 Preview (test) mode

`/dpsrace test` runs a scripted 30s race on the HUD with made-up numbers: Armed, Running, Stop!,
Waiting, then Result, where it holds. It shows the library's `TestStrip` saying *Test mode: sample
numbers. Combat or Arm ends it*, so the layout can be arranged without a dummy. Test runs are never
written to history and never move the race engine. Test mode ends itself the moment a real race is
armed or combat starts, and is refused during a real armed, running or stopping race and in combat.
The sample race's last seconds show the center countdown (silently, when the setting is on), and it goes with the sample buzzer and with test mode. On a test result card, Cancel, Discard and closing the HUD end test mode, Race Again and Details
are grayed, and none of them reaches the real race.

## 7. Data model

AceDB, with `db.global.runs` (account-wide, so bests span alts), `db.profile` for settings, and a
schema version for migrations.

```lua
run = {
  id        = "1792758447-4429",        -- time() .. "-" .. random(1000, 9999); redrawn on a clash
  schema    = 1,
  status    = "complete",               -- running | stopping | complete | incomplete | lost
                                        -- ("armed" exists in memory only and is never stored)
  addon     = "0.1.0",  build = 120105,  -- GetBuildInfo's interface number
  date      = 1792758447,               -- epoch: stamped at arm, restamped at the start
  race      = { length = 30, grace = 1.0, restartGap = 6,    -- grace and gap frozen at arm
                startSource = "meterSession",
                startedAt = 81234.56,   -- GetTime() at the start; Resume's clock after a /reload
                sessionID = 25,         -- the captured session (or the list match, §9)
                armMaxSession = 24,     -- the highest session ID at arm: older ones are never the run's
                lastDamage = 39.17 },   -- s after the start of the last DamageDone update heard
  char      = { name = "Lânfear", realm = "Frostmourne", class = "WARLOCK",
                specID = 267, spec = "Destruction", role = "DAMAGER",
                ilvl = 313.2, ilvlOverall = 313.4,   -- equipped and overall, one decimal
                level = 90, race = "BloodElf" },
  target    = { npcID = 243205, name = "Reinforced Golem", category = "boss",  -- re-read at combat start
                count = 1, level = -1, classification = "normal" },
  where     = { mapID = 2393, zone = "Silvermoon City", subzone = "Falconwing Square",
                instanceType = "none" },
  result    = { damage = 1539711, dps = 51323.7, meterDps = 39479.8,  -- probe run 8
                sessionDuration = 39, tail = 9.17, combatEnd = 7.34,   -- s after the buzzer
                endedAt = nil },                                       -- incomplete: s after the start
  flags     = { lateCasts = { { t = 1.4, spellID = 29722 } },          -- spellID absent when sealed
                restartedAt = nil,        -- s after the buzzer
                reloaded = false, died = false,
                sessionFromList = nil },  -- true when §9's list fallback chose the session
  spells    = { { id = 29722, dmg = 482113, dps = 2678.4 }, ... },     -- sorted highest first
  note      = "",
}
```

- **Every value in the record is plain.** A field read in combat (the target re-read at combat
  start) passes through `Secrets`; a sealed field is simply absent, and a sealed re-read keeps the
  arm-time value when it is recognizably the same target. No secret ever reaches SavedVariables.
- A `lost` run keeps its metadata and has no `result`. An `incomplete` run's `result` has `endedAt`
  and no `tail` or `combatEnd`.
- A target's `name` is the client's (localized) unit name; the catalog's name is used only when the
  unit's name can't be read. An uncataloged target has `category = "other"` and `count = 1`.
- `note` is stored trimmed, with control characters as spaces and `|` as `/`, cut at 200 UTF-8
  characters (never inside one). Saving a note does not count as a saved run, so it never triggers a
  prune.
- The run is saved at the start, when its session is captured, at the buzzer and at the result, so a
  `/reload` at any point finds it.

- About 1–1.5 KB per run, so roughly 1.5 MB of SavedVariables per 1000 runs. By default nothing is
  pruned (*Runs to keep* = 0, §6.3). Pruning runs at login and after each saved run, and only when
  the setting is above 0; changing the setting prunes nothing on the spot. A prune never removes a
  running or stopping run, the run just saved, or the race's own run.
- **Personal bests are worked out** from the runs when the Results window opens, and cached per
  session. They are not stored separately, so deleting a run updates them for free. Pruning never
  removes a run that currently holds a best, on either the all-runs or the clean-only board. Ties go
  to the earlier run, then the lower id.
- Spell names and icons are resolved for display through `C_Spell` and never stored. Locale and
  patch renames then resolve themselves.

## 8. Architecture (Ka0s standard layout)

```
DpsRace/
  DpsRace.toc
  libs/        Ace3, LibStub, CallbackHandler, LibDataBroker, LibDBIcon, LibSharedMedia, LibKa0s (vendored)
  Bindings.xml the three key bindings
  locales/     enUS.lua
  core/        DpsRace.lua (AceAddon, events) · Compat.lua · Secrets.lua · Database.lua · Bus.lua ·
               the *Setup.lua descriptors (Core, Env, Lifecycle, Perf, DebugLog, Launcher, Pool, Widgets, Media)
  defaults/    Profile.lua (every default) · Dummies.lua (the catalog)
  modules/
    Meter.lua         the ONLY caller of C_DamageMeter: session-by-ID reads and the live reads (secret-safe)
    Timeline.lua      damage-update stamps: the tail, the restart, the quiet before a read (§5.3)
    Scoring.lua       the late-cast rule, DPS and the flag texts (§5)
    Race.lua          the lifecycle state machine (§4), the clock, the buzzer, cast judging, resume
    Watchers.lua      the race's event wiring, registered only while a race needs it
    Recorder.lua      metadata snapshots, the run record (§7), the run store, pruning
    Bests.lua         working out personal bests, deltas and prune protection
    Format.lua        the one secret-safe number formatter, clock and length text
    Style.lua         the look both windows share with the other Ka0s windows (§6)
    Hud.lua · Hud_States.lua · Hud_Breakdown.lua   the Race HUD, its state bodies, the spell rows (§6.1)
    Countdown.lua     the final seconds: the countdown cue and the center-screen numbers (§4.3)
    Results.lua · Results_Table.lua · Results_Runs.lua · Results_Detail.lua · Results_Bests.lua
    Share.lua         the chat summary and the race's chat lines
    Preview.lua       test mode (§6.5)
    Diagnostics.lua   the diagnostics report's sections
  settings/    Schema.lua · Slash.lua · OptionsSetup.lua · one file per page (General, Race, Live,
               History, Profiles)
  tests/       headless suites (LibKa0s test kit)
  docs/        ARCHITECTURE.md and the tier docs, testing.md, smoke-tests.md, superpowers/…
  probe/       DpsRaceProbe (not packaged)
```

Rules carried over from MultiMeters, enforced in one place each:

1. **`modules/Meter.lua` is the only caller of `C_DamageMeter`, and `core/Secrets.lua` is the only
   file that inspects a value.** Everything else treats a meter value as an opaque handle.
2. **No decision is ever made from a meter value in combat.** Decisions come from events and
   `GetTime()`: the start, the buzzer, the tail, late casts, the end of combat.
3. **Layout is computed from config, never read back off a frame** (§6.1).
4. **Event registration is isolated** (`SafeRegisterEvent`), so an event name a client doesn't know
   costs only itself.

`Race.lua` emits `RACE_STATE_CHANGED(run, from, to)`, `RACE_BUZZER(run)` and `RACE_RESULT(run)` on
the addon's message bus; `Recorder.lua` emits `RUN_SAVED(run)` and `RUNS_CHANGED`. The HUD, Results,
Bests, Share and Preview listen and never poke each other directly. Race calls the Recorder and its
own Watchers directly, because the watchers' registration set must follow the state on the same
call.

## 9. Error and edge handling

| Situation | Behaviour |
|---|---|
| `C_DamageMeter.IsDamageMeterAvailable()` returns false | The HUD shows the reason Blizzard gives and Arm is disabled. Nothing else is affected. |
| Armed, but no hit for 5 minutes | Stays armed. Arming is cheap and the HUD says what it's waiting for. |
| Target changes mid-run | Allowed. The target stored is the one read at combat start. |
| A different target is hit (e.g. a Dungeoneer instead of the Cleave group) | Allowed. The record reflects the target read at combat start. |
| Session ID never captured | The run falls back to the newest session created after the start (diffing the session list) and is flagged *Session matched by list*. |
| Reading the result raises | Caught. The run becomes `lost` with the error in the debug log, and the HUD says *Couldn't read the result*. |
| Logging out while waiting | The run becomes `lost` on the next login if the session is gone. Whether sessions survive a logout isn't measured; assumed no. |
| Inside an instance or encounter | Works the same way: the same restriction applies. Not a target use case. |

## 10. Performance

- **Live reads are throttled to 4 Hz** (configurable 2–10), and only while the HUD's Running state
  is visible. They are triggered by `DAMAGE_METER_COMBAT_SESSION_UPDATED`, coalesced, and never run
  in `OnUpdate`.
- The countdown text updates at 20 Hz from one `OnUpdate`, which is attached only while Running;
  Stopping has no clock and redraws at 4 Hz.
- Nothing runs while idle except the regen and target events.
- Perf instrumentation follows the standard's `performance` section (`/dpsrace perf`).

## 11. Testing

- **Headless suites** (LibKa0s test kit):
  - the lifecycle state machine, every transition in §4;
  - the late-cast rule (grace edges: exactly at grace, a cast started before and finished after);
  - tail and restart detection from synthetic update timelines (taken from the probe's real timelines);
  - resuming after a reload from each stored status;
  - DPS for complete and incomplete runs;
  - bests: grouping, clean-only, pruning protection;
  - `Secrets` guards with opaque secret mocks.
- **Smoke tests** (`docs/smoke-tests.md`): the in-game checks below, plus a standard UI pass.

## 12. Open items (verified during the build, not blocking the spec)

| # | Question | How to settle it | Fallback if it fails |
|---|---|---|---|
| O1 | In-combat order of `combatSpells`: sorted or insertion order? | First Running smoke test | Keep Blizzard's order and add *(live order)* to the header |
| O2 | Does `C_Spell.GetSpellTexture` accept a secret spell ID? (Names do.) | First Running smoke test | Live rows without icons; icons on the result |
| O3 | The damage-restart flag (probe test D3 never happened) | Smoke test: stop, wait 10s in combat, attack again | The flag is quietly never raised. Nothing else depends on it. |
| O4 | `/reload` **while still in combat** after the buzzer | Smoke test on the Dungeoneer's dummy | The run becomes `lost` and the HUD says so |
| O5 | Do sessions survive a logout? | Smoke test | Assumed not (§9) |
| O6 | Does `UNIT_SPELLCAST_START` give a usable start for every cast type (empowered, channels)? | Smoke test with an Evoker | Use `SUCCEEDED` for empowered spells |
| O7 | Target count for the Silvermoon cleave group | Count it in-game | Default 1, adjustable |

## 13. Decisions log

| Date | Decision |
|---|---|
| 2026-10-23 | Built on `C_DamageMeter` only (addons can't read the combat log in 12.0). |
| 2026-10-23 | Damage after the buzzer counts. Score = session total. DPS = total ÷ race length. |
| 2026-10-23 | Late casts are flagged with a 1.0s grace (configurable), never voided. |
| 2026-10-23 | The DoT tail is accepted and displayed. No minimum race length. |
| 2026-10-23 | "Time to X damage" and the goal bar are dropped. PvP is parked in issue #1. |
| 2026-10-23 | Built to the Ka0s WoW Addon Standard (Ace3, LibKa0s). |
| 2026-10-23 | History: *Runs to keep* setting, default 0 = never prune. |
| 2026-10-23 | The Results tables show class icon, spec icon and item level. |
| 2026-10-23 | Slash commands: `/dpsrace` and `/dr`. |
| 2026-10-23 | Spec synced to the shipped build (T10): the §7 record gains `race.startedAt`, `race.lastDamage`, `race.armMaxSession` and `flags.sessionFromList`, and states the note's sanitizing; arm refusals (§4.1); the start rule's same-frame edge (§4.2); the quiet measured from the later of combat end and the last update, the sealed-read retry and the resume cases (§4.5); single in-flight cast tracking and auto-repeat (§5.2); the *Session matched by list* and *Died* flags (§5.4); the result delta in words (§6.1); the filters' defaults and the Bests category filter (§6.2); the settings pages as built (§6.3); three key bindings and the extra slash forms (§6.4); test mode's strip text and refusals (§6.5); the file tree and the bus (§8); Stopping at 4 Hz (§10). |
| 2026-10-23 | The launcher's right-click menu is the standard's fixed set (launcher-§2). *Show results* and *Arm last race* are dropped from it: the library takes no host entries, and both are one HUD click, one slash verb or one key binding away. |
| 2026-10-23 | Live DPS is a rung chain (`Meter.ReadLive`): the source's `amountPerSecond`, else the `combatSources` row whose `isLocalPlayer` is readable and true, else the Dps meter type's `amountPerSecond`. The owner's smoke test (Beast Mastery hunter) found the source field absent, so *DPS · LIVE* stayed a dash. Each rung is an opaque copy; damage ÷ elapsed is never computed in combat. The Dps type's `totalAmount` is never read as a rate: no probe has measured that field, and the DamageDone type's carries the damage total (a dash beats a wrong number; smoke C3 records which rung served). The rung that served last is tried first on the next read. |
| 2026-10-23 | The HUD's default size is 300×460, so all 8 default live rows show (mockup screen 04); its minimum is 260×316, because 240 px could not hold the idle body's Arm button and links. Rows are capped to the window's height. |
| 2026-10-23 | The running clock shows the time elapsed (green) and the time left (red): both side by side by default, or either alone (`hud.clock`, General → Race HUD). The single clock no longer turns amber in the last 10s: time left is red throughout, and the final seconds have the center countdown. The armed and stop bodies keep their own clock and STOP. |
| 2026-10-23 | A center-screen final countdown (`modules/Countdown.lua`): from `race.finalCountdown` seconds left (3–10, default 10; `race.centerCountdown`, default on) a number pops in each second down to 1 on the addon's own frame, with Blizzard's BigGold digit art by texcoord and a font fallback. No pull timer is broadcast and no TimerTracker handler is called. The countdown cue moves into the same module: one timer per whole second, one sound per second at most (a cue mark inside the numbers' window sounds once), and a cue change now takes effect mid-race. |
| 2026-10-24 | The HUD and the Results window take the collection's look (§6, *Style*), after the owner's smoke test: Blizzard's font objects by role as LootHistory uses them, Title Case labels, tabs, headers and buttons with no ALL-CAPS word but *STOP*, the title centered in a 30 px title bar, LootHistory's tab strip, a 20 px header over 20 px rows with the gold sort arrow inline, 18 px spell rows and 20 px buttons. The race clocks, *STOP* and the KPI figures stay large. The HUD's minimum height is re-derived from the new stack: 260×296 (was 316). The title-bar controls turn the header gold under the pointer, one at a time (MultiMeters'); the close control's gold replaces the library's red, a deviation recorded in `docs/ARCHITECTURE.md`. |
