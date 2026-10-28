# Plan: late-cast ignore list (#8) and the Insights tab (#12)

Opened 2026-10-28. Branch `feat/2026-10-28-ignore-list-insights` (DpsRace only; LibKa0s is not touched).
Resumable: each step is ticked in the commit that finishes it; a run that stops resumes at the first unticked
box. Group I (#8) lands before group N (#12), because Insights reads flags through the ignore-aware
`Scoring.Flags`. Push to origin after I4 and after N5. No merge without the owner's go-ahead.

## Decisions

### The owner (2026-10-28)

- **#8 defaults, and only these:** Feign Death 5384, Vanish 1856, Shadowmeld 58984, Invisibility 66,
  Greater Invisibility 110959, and every Hearthstone variant (8690 plus every toy and alternate hearthstone).
- **#8 storage:** the list is a profile setting, a schema-driven list row with reset to defaults. Players add
  and remove spells by ID or name. Names resolve to IDs, so the list works in every locale.
- **#8 applies at read time:** stored runs keep their raw `flags.lateCasts`. Flags, the clean filters, bests
  and everything else skip ignored spells, so editing the list re-scores old runs. Ignored casts still show in
  the flags tooltip as a dimmed "ignored" line.
- **#8 from the HUD:** a right-click on the late-cast flag in the post-race HUD state opens a menu with
  "Ignore <spell> for late casts". The Results detail flag line offers the same.
- **#12:** rename the Results window's Bests tab to Insights. The Bests board UI (best run per spec, category
  and length) is dropped from the tab entirely. Insights follows LootHistory's Insights tab
  (`LootHistory/docs/browser.md` "Insights tab: Analytics", `LootHistory/modules/Analytics*.lua`): stat cards
  and chart sections fed by one stats pass over the filtered runs, with filter dropdowns computed from the
  data present.
- **`NS.Bests` stays** as a data module (the new-best toast, the HUD delta, the Runs tab's compare and
  HoldsBest, prune protection). Only the tab UI goes.

### Design decisions (this plan)

A critic pass (2026-10-28, read-only against the code and the owner's SavedVariables) corrected D-12, the
data-profile CV figures, the `Runs.RESOLVED` claim and the filters' dynamic rules. It added D-3's resolve and
normalize rules, D-4's profile-switch and prune notes, D-6a, S-7, Appendix A, and the missing read sites,
tooltips, dead code and smoke rows in the steps.

- **D-1 One read seam.** `Scoring.Flags(run, nameOf, set)` is the only judge of flagged vs clean. With no
  `set` it reads `NS.LateIgnore.Set()` at call time, the same way it already reads `NS.L`. Tests pass a set.
  The header comment that says PURE is rewritten to name this one injected seam.
- **D-2 Effective late casts.** New `Scoring.SplitLate(run, set) -> counted, ignored` (two arrays, raw order
  kept). The `lateCasts` flag is emitted only when `#counted > 0` and carries `count`, `casts` (counted) and
  `ignored`. Every reader that used `#run.flags.lateCasts` moves to `SplitLate` or `flag.count`.
- **D-3 Hearthstones as data.** `defaults/Hearthstones.lua` holds `NS.HEARTHSTONE_SPELLS`, the 59-ID table from
  DB2 (ChargeCategory 2309 plus the Effect 252 / target 9 teleports, plus Dalaran 222695 and Garrison
  171253). Astral Recall 556 is excluded (a class spell; players can add it). In the stored list, 8690 stands
  for all of them: one entry, one row in the UI with the suffix "(all hearthstones, 59)", removed as one.
  A single variant can also be added on its own. The IDs, their names and the sourcing are in
  **Appendix A** of this plan (the research scratch files do not survive the session).
  - `Normalize` drops a single variant ID while 8690 is in the list (8690 already covers it), and keeps it
    when 8690 is absent.
  - `Resolve` maps any name a `HEARTHSTONE_SPELLS` member carries ("Hearthstone", "Town Portal", "Scroll of
    Recall" and the toy names, in the client's locale) to 8690. Several of these names are shared by 2 or 3
    IDs (8690 / 191329 / 401802 are all "Hearthstone"), so a plain `ResolveId` would answer "ambiguous". A
    variant on its own is added by ID or link only.
  - `Unignore(id)` of a variant that is ignored only through 8690 removes 8690, and its menu entry reads
    "Stop ignoring all hearthstones", so the player is never offered an undo that does nothing.
- **D-4 Storage shape.** `profile.race.lateIgnore` is a comma-separated string of spell IDs, default
  `"66,1856,5384,8690,58984,110959"`, written whole through `NS.SetByPath`. This copies `global.usage.hidden`
  (`modules/Usage.lua:396-490`, `settings/History.lua:109-138`) so `/dr get|set|reset` and the page's
  Defaults button work with no extra code. It is profile-scoped (the owner's call) while `usage.hidden` is
  global: switching profile re-scores history. Documented in `docs/profiles.md`, not a deviation.
  - The default string is hardcoded once, in `defaults/Profile.lua` (savedvariables-§2). `LateIgnore.DEFAULT`
    reads `NS.defaults.profile.race.lateIgnore`; it is not a second literal.
  - The `race` block's comment in `defaults/Profile.lua` (:12-14) says its settings are frozen into each run
    and never re-grade a saved run. `lateIgnore` is the exception (read time, D-1), so the comment is rewritten
    to say so, and the key sits in its own commented group inside the block.
  - **Profile switch.** A profile switch, copy or reset announces `SETTINGS_CHANGED("profile", key)`
    (`core/Database.lua:47-52`), not `race.lateIgnore`. Every cache and redraw keyed on the ignore list listens
    to both paths: `race.lateIgnore` and `"profile"`.
  - **Prune protection.** `Bests.HoldingIDs` (`modules/Bests.lua:131-139`) protects the clean-only board's
    holders, and with D-1 that board depends on the profile-scoped list, while `global.history.keepDays` is
    global. A run protected under one profile can be pruned at a login on another profile. The all-runs board
    is unaffected and protects every board's best. Recorded in `docs/known-limitations.md` and
    `docs/profiles.md`; not changed.
- **D-5 A sealed spell ID is never ignored.** Late casts stored with `spellID = nil` stay counted.
- **D-6 All casts ignored.** The HUD result card shows a gray "N ignored" chip (no flag) that keeps the
  tooltip and offers "Stop ignoring <spell>". The Results detail Flags box keeps a dimmed line. This is the
  undo path, so it stays visible. The gray chip is added in `States.ResultChips`, not in `States.FlagChips`:
  `FlagChips` also feeds the new-best toast's flags line (`modules/BestToast.lua:64-66`), and the toast shows
  no "ignored" chip.
- **D-6a Every flags tooltip shows the dimmed ignored line**, not only the HUD chip and the detail box (the
  owner's wording is "the flags tooltip"). The sites are `Runs.StatusTip` (`modules/Results_Runs.lua:612-624`),
  `DETAIL.flags` (`modules/Results_Tips.lua:403-409`) and the timing strip's late-cast tick tip
  (`Results_Tips.lua:398`, which needs its own "ignored, so no flag" text). A run whose late casts are all
  ignored has no `lateCasts` flag, so these sites read `Scoring.SplitLate` for the ignored line, not the flag
  list. `Scoring.IgnoredText(run, nameOf)` returns one shared string, so the sites word it the same way.
- **D-7 No menu on samples.** The test-mode preview card (`v.preview`) and sample runs get no ignore menu.
  The STOP state (in combat) filters its count only, with no menu.
- **D-8 Slash.** `/dr ignore [list|add|remove|reset] <spell ID, link or name>`, dispatched from a sub-verb
  table (slash-commands-§3). See Standards flags, item S-1.
- **D-9 Insights files.** Three files with the `Results_` prefix: `Results_InsightsData.lua` (pure),
  `Results_InsightsCharts.lua` (renderers ported from LootHistory), `Results_Insights.lua` (the tab).
  `Results_Bests.lua` is deleted.
- **D-10 Board-relative math.** DPS compares only within a board (spec, category, length). Every figure that
  mixes boards uses "% of board best", with the board best computed over the filtered set. Raw DPS figures
  appear only when the filter resolves to one board.
- **D-11 Saved view.** Insights gets LootHistory-style Save / Reset / Clear stored at
  `profile.views.insights`, next to `views.runs` (named non-setting state, a new `docs/schema.md` row, no
  migration). Default filters: All characters, All specs, All targets, All lengths, All dates, Clean only off,
  Include incomplete off. Insights is the cross-character view, so it defaults wide where Runs defaults to the
  current character.
- **D-12 `bests` stays as a silent alias.** (Corrected by the critic pass: an earlier draft said `/dr results
  bests` was never documented. It is documented in the help line `settings/Slash.lua:53` /
  `locales/enUS.lua:307`, in `docs/ARCHITECTURE.md:189`, in `docs/slash-dispatch.md:67` and in smoke row K8.)
  `/dr results insights` opens Insights, and `/dr results bests` opens Insights too: `NS.ShowResults` maps both
  words, and only `insights` appears in help and docs. That way a player's macro keeps working. This follows
  slash-commands-§2's MAY on legacy spellings, which is written for verbs; here it is an argument, so there is
  no descriptor `aliases` entry. Reversible if the owner wants it gone.
- **D-13 No LineChart dependency in v1.** Progression is a per-run strip (ported `renderStrip`), so no
  `NS.MakeLineChart` seam is added. LibKa0s `Widgets.LineChart` stays a later option.
- **D-14 No saved-state migration.** The active tab and the Bests filters were never persisted
  (`local tab = "runs"`, `ResultsBests.DEFAULTS` view-local), so the rename needs no migration step. N1 adds
  a test that a profile written before the rename loads clean.
- **D-15 Out of scope, to file as a follow-up issue:** Disengage End (199558) is an automatic follow-up
  spell recorded as a late cast. #8 does not special-case it.

## Insights analysis

Source: the owner's SavedVariables (`DpsRace.lua`, account ADD1KTED2KA0S), read offline with scratch
scripts. No repo file was changed by the analysis.

### Data profile

- **56 runs, all complete**, 2026-10-23 to 2026-10-27, 5 active days, about 11 sessions. Run format 1 = 33,
  2 = 14, 3 = 9.
- **4 characters with runs:** Trâxex (Hunter, Beast Mastery) 28, Lânfear (Warlock, Demonology 8 and
  Destruction 7) 15, Tiamât (Shaman, Elemental) 12, Helyâ (Death Knight, Blood) 1.
- **Targets:** cleave 37 (Cleave Training Dummy), boss 18 (Reinforced Golem), other 1 (Turnip Punching Bag).
  Category and dummy are 1:1. **Lengths:** 2:00 = 30, 1:00 = 14, 0:30 = 12. One zone.
- **DPS:** 28.4k to 469.9k. Boss averages 126k and cleave 288k, a 2.3x gap, so raw cross-board averages
  mislead. Normalized to board best, the average run reaches 86.3% (Destruction 98.8%, Beast Mastery 90.6%,
  Demonology 85.9%, Elemental 68.1%). The spread within a board varies. On the 2:00 boards CV is 0.4% to 4.6%,
  except Demonology cleave 2:00 at 10.4%; at 1:00 and 0:30 it reaches 13.7% (BM boss 1:00) and 18.2% (BM cleave
  0:30). Elemental cleave 0:30 is the outlier, with CV 81% and runs averaging 40.6% of the board best, because
  of 5 junk pulls at 28k to 32k. (Critic pass, rechecked with `chk.lua` over the same file. An earlier draft
  said "CV 0.4% to 3.8%" and "81%" as if 81% were the average.)
- **Progression:** 15 runs beat an earlier best on their board. First run to best: Beast Mastery boss 1:00
  +27.7%, Demonology cleave 2:00 +27.2%, Beast Mastery cleave 0:30 +56.3%.
- **Flags:** 11 of 56 runs flagged, all for late casts (15 casts: Feign Death 7, Disengage 2, Disengage End
  2, one each of Spatial Rift, Ghost Wolf, Summon Felhunter, Burning Rush). With the #8 defaults, 5 runs
  become clean: 80% clean becomes 89%.
- **Damage tail after the buzzer:** median about 9.1 s, 54 of 56 within 20 s, outliers at 26 s and 155 s.
- **Spells:** on every run, summing to `result.damage`. 87 rows repeat a spell ID within one run (player and
  pet Auto Attack), so aggregation sums by ID.
- **Thin fields:** loadout on 23 runs (2 talent loadouts, one per spec), casts and usage on 9, stats on 0.

### Cards (8)

| Card | Real value | Why |
|---|---|---|
| Races run | 56 | The headline count. |
| Time raced | 1h 20m | Practice volume: the sum of `race.length` over complete runs, plus `result.endedAt` (or `race.length` when that is absent) for incomplete ones when Include incomplete is on. |
| Best DPS (wide) | 469.9k, BM cleave 0:30, Oct 26 | The peak, with its board in the subline. |
| Avg % of board best (Avg DPS when one board) | 86.3% | The only honest cross-board average (D-10). |
| Clean runs | 89% (50 of 56) | Ignore-aware, so it moves live when the #8 list changes. |
| New bests set | 15 | Runs that beat an earlier best on their board, so a board's first run does not count. That is the toast's rule (`BestToast.OnResult`). The difference is that the rivals come from the filtered set, while the toast compares against every stored run. With a Character filter, a run can count here although another character of the same spec held a higher best. The tooltip says "within these filters". |
| Characters / Specs | 4 / 5 | Small context; first to cut if space is short. |
| Date range / Active days (wide) | Oct 23 to Oct 27, 5 days | Span of the filtered set. |

### Sections (11, in order)

| Key | Section | Shape | Why |
|---|---|---|---|
| A | DPS Progression | Strip, one column per run in date order, height = % of board best, spec-colored; raw DPS when one board | Shows the +27% climbs and the junk pulls; buckets by day above 60 runs. |
| B | Spec Comparison (category, length) | Bars of best DPS per spec, avg in the tip | One board, specs side by side (cleave 2:00: BM 417k, Destro 342k, Ele 307k, Demo 294k, Blood 157k). Uses the filter's pair, else the most-raced pair. |
| C | Consistency By Board | Bars of avg % of board best, CV in the tip, boards with 3 or more runs | 99.5% (Destro cleave 2:00) down to 40.6% (Ele cleave 0:30). |
| D | Races By Character | Class-colored bars | LootHistory's first chart; 28 / 15 / 12 / 1. |
| E | Races By Character x Target | Stacked bars in category colors | Trâxex 20 cleave / 8 boss, and so on. |
| F | Races By Length | Bars | 30 / 14 / 12. |
| G | Late Casts | Ranked list, spell and count; ignored spells dimmed and tagged; right-click to ignore or stop ignoring | The discovery path for the #8 list. |
| H | Top Spells | Top 8 spells by damage share, summed by ID (`spells[].id`, `.dmg`) | Only when the filter resolves to one spec; otherwise a hint line. The share is the mean of each run's own share, not total damage over total damage, so the long cleave runs do not dominate. |
| I | Races Per Day | Strip with gap days | 1 / 32 / 8 / 12 / 3. |
| J | Damage Tail After The Buzzer | Bars over 0-5, 5-10, 10-15, 15-20, 20+ s | The DoT tail the owner wants shown; the 20+ bucket absorbs the 155 s run. |
| K | Recent New Bests | List: date, spec, board, DPS, gain; left-click opens the run, right-click the row menu | The route from aggregate to run. First to drop if it feels like the old board. |

### Filters

One 32 px bar: Character, Spec, Target (category), Length, Date (All, Today, 7 days, 30 days from
`Runs.DATE_RANGES`), a Clean only check and an Include incomplete check, then Save / Reset / Clear.

- **Faceted options:** each dropdown lists the values present in the runs that pass every other filter, with
  counts in the label ("Beast Mastery (28)"). The All head is always offered, and so is the current
  selection. If another change leaves a selection with 0 runs, it falls back to All.
  - **One pass.** For each run, `Options` evaluates every predicate once. A run counts toward facet k's
    options when it passes every predicate except k's, so the cost is O(runs x facets), with no
    `Runs.Filter` call per facet. `Runs.IsFlagged` (which builds `Scoring.Flags`) is memoized per run
    within one `Options` / `Compute` call, never across calls, because the ignore list can change in
    between.
  - **Date is not a value facet.** Its four ranges nest (Today within 7 days within 30 days within All), so
    all four are always listed, each with its count, and a 0-count range is shown, not hidden. Otherwise the
    bar would jump and the nesting would be lost.
  - **Fallback order.** The dropdown the player just changed is never reset. The others are checked in bar
    order (Character, Spec, Target, Length, Date). Each 0-run selection is set to All, and the options are
    recomputed before the next one is checked, so one change cannot reset a selection that the reset before
    it would have saved. A fallback changes the live filters only and never writes `profile.views.insights`.
    The same rule runs once when a saved view is applied (a saved character with no runs left falls back
    to All).
- **Clean only** uses the ignore-aware `Runs.IsFlagged`. **Include incomplete** is off by default (incomplete
  DPS is damage over time in combat).
- **Lost runs never count.** (Critic pass: an earlier draft said `Runs.RESOLVED` keeps lost runs out. It does
  not: `Runs.RESOLVED = { complete, incomplete, lost }`, `modules/Results_Runs.lua:23`.) `Runs.Filter` drops
  lost runs only when `includeIncomplete` is false (`:121`). `InsightsData.Filter` therefore removes
  `status == "lost"` before it calls `Runs.Filter`. Running and stopping runs are never in the store.
- **`Runs.Filter` merges `Runs.DEFAULTS`** (`:131-135`: `char = "current"`, `includeIncomplete = true`,
  `onlyBest = false`). `InsightsData.Filter` passes every key explicitly (`char`, `spec`, `category`, `length`,
  `date`, `hideFlagged = cleanOnly`, `includeIncomplete`, `onlyBest = false`), so a Runs default cannot leak
  into Insights. The Insights option lists offer no "Current character" or "Current spec" head:
  `Runs.WithAll(list, label)` is called without its current label.
- Recompute on `RUN_SAVED`, `RUNS_CHANGED`, a delete, a `SETTINGS_CHANGED` on `race.lateIgnore` or `"profile"`
  (D-4), and a test mode toggle. Data comes through `NS.ResultsSource.All()`, so test mode and sim show sample data.
- A dummy-name filter is not offered: dummy and category are 1:1 in the owner's data. The board key is
  category, not dummy (`Bests.Key`), so a Target filter on category matches the boards. A dummy filter can come
  later without touching the board math.

### Cut, and why

- **Total damage:** trivia, dominated by long cleave runs.
- **Median tail card:** covered by section J.
- **Flag reasons:** a single bar in this data; folded into the Clean card and section G.
- **Gear and talent comparison:** only BM has 2 or more gear sets, with n of 2 to 4 and gaps of 0.5% to 3.5%
  (noise); talents have one loadout per spec. Deferred.
- **Usage vs DPS, casts per minute:** 9 runs, and the potion is in 8 of them. Deferred.
- **Hour of day, weekday:** 5 days of data, and realm vs client time is ambiguous.
- **ilvl vs DPS, secondary stats:** ilvl barely moves; no run has stats yet.
- **Best DPS by board table:** that is the dropped Bests board in another shape.

## Standards flags

Each item is checked against the standard text at the start of its step. If one turns out to be a deviation,
stop and ask the owner (accepted deviation in `docs/ARCHITECTURE.md` `## Documented deviations`, or an
upstream change). None is ratified by this plan.

- **S-1 slash-commands-§2:** `list` and `reset` under the `ignore` noun. slash-commands-§2 reserves `list`
  and `reset` collection-wide ("MUST mean the same thing in every addon"), and `reset` there takes a schema
  path. `/dr ignore reset` resets one path (`race.lateIgnore`), so it is close to the reserved meaning;
  `/dr ignore list` lists the ignore list, not the schema. The noun sub-tree clause is written for enable and
  disable. If that reading is too narrow, the fallback is `show` and `defaults`, or a one-line clarification
  upstream. Ask before I2 ships it.
- **S-2 Scoring purity:** `Scoring.Flags` reading `NS.LateIgnore.Set()` at call time. Same pattern as `NS.L`;
  the header names the seam. Not a deviation if the header is honest.
- **S-3 options-ui-§7 headings:** the list's heading comes from a `skipRender` row carrying the subgroup,
  then `afterGroup` draws it (the History precedent). Conforms.
- **S-4 testing-§8 degraded-load stub parity:** `Helpers.ResolveId`, `IdList` and `IdInput` are already
  stubbed (`settings/OptionsSetup.lua:110-115`). Any new Helpers member needs a stub, and
  `tests/test_surface_parity.lua` is the gate that catches a missing one (add it to I2's test list). With the
  degraded stub, `ResolveId` returns nil, so `LateIgnore.Resolve` must still resolve a number, a spell link and
  "hearthstone" on its own, before it calls `ResolveId`.
- **S-5 1500-line cap:** `Hud_States.lua` is at 1157 lines and `Results_Detail.lua` at 1182. New logic goes in
  `LateIgnore.lua` and the Insights files.
- **S-6 CCN 15:** `Compute`, `Options`, `LayoutCharts` and every renderer stay small dispatch loops over
  `REDUCERS`, `FINALIZERS` and `SECTIONS` tables. Checked with
  `bash tests/_kit/run-automated-tests.sh --suite complexity`.
- **S-7 library-stack-§7 (two-consumer bar) and anti-patterns #47 / #55:** N3 ports LootHistory's
  `AnalyticsCharts.lua` / `AnalyticsFormat.lua` renderers (bar, stacked bar, strip, list panel, legend) into
  DpsRace. That makes DpsRace the second consumer of the same chart shapes, which is library-stack-§7's bar for
  promoting them into LibKa0s (as `Widgets.LineChart` was, with one consumer). A private copy is not a
  deviation by itself: #55 says duplication can be the cheaper answer, and #47 covers only what the library
  already ships, and LibKa0s ships no bar chart. But it is the drift #47 describes. **Ask the owner before N3:**
  (a) copy now and file a LibKa0s promotion issue, or (b) promote first (a LibKa0s branch, which this plan
  says it does not touch). The default, if the owner does not say, is (a), with the file header naming the
  LootHistory source commit so a later promotion can diff the two.

**Owner answers (2026-10-28):** S-1 resolved to `/dr ignore show|add|remove|defaults` (bare `/dr ignore` is `show`), so it conforms and needs no deviation row. S-7 resolved to (a): copy the renderers now, file a LibKa0s promotion issue, and record a deviation row in `docs/ARCHITECTURE.md` with the next LibKa0s re-vendor as its re-check trigger. Borderline hearthstone entries (Appendix A) stay in by default: anything on the hearthstone cooldown that sends you home counts as a variant. File D-15 (Disengage End) as a GitHub issue. Keep `/dr results bests` as a silent alias. The owner adds that BankLedger may also use the chart widget, so `Results_InsightsCharts.lua` is written host-agnostic for a clean promotion: no `NS` reads inside the renderers; colors, fonts, the tooltip function and pools are passed in by the host through one config table. The LibKa0s issue names LootHistory, DpsRace and BankLedger as consumers.

## Steps

### I: #8 late-cast ignore list

- [x] **I0 Plan** (this file).
- [ ] **I1 Core.**
  - New `defaults/Hearthstones.lua`: `NS.HEARTHSTONE_SPELLS` (the 59 IDs in Appendix A; the table starts with
    8690, 222695, 171253). Header comment with the wago.tools refresh recipe from Appendix A and the client
    build the export came from (look it up on wago.tools when writing the file; the research run did not record
    it).
  - New `modules/LateIgnore.lua` (`NS.LateIgnore`): `PATH = "race.lateIgnore"`, `DEFAULT`, `Parse`,
    `Normalize`, `Join` (copy the shape of `Usage.ParseHidden/NormalizeHidden/JoinHidden`,
    `modules/Usage.lua:396-490`); `List()` and `Set()` memoized by the stored text, with 8690 expanding to
    every hearthstone ID; `IsIgnored(id)` (nil ID returns false, D-5); `Ignore(id)`, `Unignore(id)`,
    `Reset()` through `NS.SetByPath`; `Resolve(text)` (number, spell link, "hearthstone" or the localized
    `C_Spell.GetSpellName(8690)` give 8690, as does any hearthstone-family name (D-3), else
    `Helpers.ResolveId("spell", text, KnownSpells)`); `KnownSpells()` = the IDs in stored runs' late casts
    plus the six default IDs (the hearthstone family is handled by name above). ResolveId's client name
    lookup (`C_Spell.GetSpellInfo(name)`) finds only spells the logged-in character knows, so without the
    defaults in the candidates a Hunter typing "Vanish" gets "not found" (`libs/LibKa0s/OptionsIds.lua:324-360`,
    step 4 matches names over the candidates). It posts nothing on the bus; the seam fires
    `SETTINGS_CHANGED`.
  - `defaults/Profile.lua` `race` block (line 16): `lateIgnore = "66,1856,5384,8690,58984,110959"`.
  - `modules/Scoring.lua`: add `SplitLate(run, set)`; `Flags(run, nameOf, set)` emits `lateCasts` only for
    counted casts (:71-72) with `count`, `casts`, `ignored`; `lateCastsText` (:54) takes the counted list.
    Rewrite the PURE header.
  - Switch the raw readers (every `lateCasts` hit under `modules/` is listed here):
    - `Hud_States.lua:863-871`: the STOP body filters `v.lateCasts` to the counted list there, so the STOP
      chips and the cache key `#late|first|grace` use counted casts. Filter here and not in
      `modules/Hud.lua:233`, because the test-mode / sim STOP view (`MockRuns.lua:459-466`, the `stop`
      builder) hands `v.lateCasts` raw and bypasses `Hud.lua`. One filter point covers both.
      `Hud.lua:233` stays raw.
    - `Hud_States.lua:965-966`: `FLAG_CHIP.lateCasts` takes `(run, flag)` and uses `flag.count`;
      `States.FlagChips` (:986-994) passes the flag.
    - `Results_Detail.lua:159-171` (`afterBuzzer` ticks, ignored ones gray) and `:222-228` (`lateLine`).
    - `Results_Table.lua:184` (`SHORT.lateCasts`, deleted again in N1 with its only caller).
    - `Share.lua:261-263` (the share line counts counted casts only).
    - Write and fixture sites with no change: `Race.lua:574` (capture: the raw list, all casts),
      `Recorder.lua:280` (the empty list), `MockRuns.lua:273` (sample data). `Sim.lua:24` is scenario data
      (Incinerate 29722, never ignored by default), not a read site.
  - Caches and redraws keyed on the list, all on `SETTINGS_CHANGED` with path `race.lateIgnore` **or
    `"profile"`** (D-4):
    - `modules/Bests.lua` receiver (:160-168): `Bests.Invalidate()`.
    - `modules/Results_Source.lua:23`: the test-mode sample boards cache, which is also keyed by cleanOnly,
      is dropped too.
    - `modules/Results.lua:872`: `onStoreChanged()`, as for `NS.Usage.HIDDEN_PATH`.
    - The HUD result card: `modules/Hud.lua` has no `SETTINGS_CHANGED` receiver today. Add one bus target in
      `Hud.lua` that re-renders the result body when the HUD is on the result state, and that stands down
      with the latch like the others (slash-commands-§7).
  - `DpsRace.toc`: `defaults\Hearthstones.lua` with the other defaults, `modules\LateIgnore.lua` before
    `modules\Scoring.lua` readers (after `Helpers`).
  - Tests: `tests/test_late_ignore.lua` (parse, normalize, join, memo, expansion, Ignore/Unignore/Reset,
    Resolve cases, nil ID, Bests cache invalidation), hearthstone table pins (positive integers, no
    duplicates, has 8690 / 222695 / 171253, lacks 556), `test_scoring.lua` (some, all, none ignored; order
    kept), `test_bests.lua` (a Feign-Death-only run joins the clean board and leaves it on Unignore),
    `test_race.lua` (capture still stores ignored spells raw), `test_share.lua`, `test_toast.lua`,
    `test_loadorder.lua`, and a profile-switch case: two profiles with different lists, and a switch re-scores
    `Runs.IsFlagged` and drops the Bests clean board (D-4). Resolve cases also cover "Vanish" typed on a
    character that does not know it (resolved through the default candidates), "Hearthstone" (8690, not
    ambiguous), a variant ID kept on its own, and a variant dropped by Normalize while 8690 is present.
    Gate green.
- [ ] **I2 Settings row and slash.**
  - `settings/Race.lua`: row `{ path = "race.lateIgnore", page = "race", group = RACE,
    subgroup = L["Late-cast ignore list"], type = "string", skipRender = true, validate, normalize, tooltip }`.
    Tooltip says it applies to every stored run and runs keep their casts (unlike grace, which is frozen per
    run). `afterGroup = { [RACE] = afterRace }` draws a `TextRow` and `H.IdList{ kind = { base = "spell",
    resolve = LateIgnore.Resolve, noun = ... }, label = L["Ignore a spell"], candidates =
    LateIgnore.KnownSpells, onAdd, onRemove, removeStyle = "icon", columns = 2, emptyText }`; the 8690 entry
    carries the hearthstone suffix. Repaint hook on `SETTINGS_CHANGED` like `settings/History.lua:161-178`.
    The page's `defaultsTooltip` says Defaults also resets the list. The page's Defaults also resets grace,
    restart gap and the other Race rows, so it does not satisfy the owner's "reset-to-defaults" for the list
    by itself. Under the list, add a *Reset list* button that calls `LateIgnore.Reset()` (one
    `NS.SetByPath` write of the default, so `/dr reset race.lateIgnore` does the same thing). Its tooltip
    names the six defaults.
    Grep how History's Usage list or another LibKa0s IdList host draws a list-scoped reset, and copy that if
    one exists.
  - `settings/Slash.lua` `NS.COMMANDS` (:30-66): the `ignore` row and `doIgnore` with a sub-verb table
    (bare and `show` print "Name (id)", 8690 as "Hearthstone (all variants)"; `add`, `remove` with the
    resolve messages; `defaults`; anything else prints usage). S-1 settled: show/defaults. It answers while the addon is
    disabled.
  - Locale strings in `locales/enUS.lua`.
  - Tests: `test_settings.lua` (IdList spec, Defaults resets, suffix), `test_schema.lua` (row, default,
    validate rejects junk), `test_slash.lua` (every sub-verb and bad input), `test_disabled.lua`,
    `test_surface_parity.lua` (S-4). Gate green.
- [ ] **I3 HUD and Results detail actions.**
  - `Hud_States.lua` `newChip` (:268-282): an `OnMouseUp` RightButton hook that calls `chip.menu(chip)` when
    set. Chips are pooled (`Chips:Set`, :290), so `Set` assigns `chip.menu = item.menu` (nil included) on
    every acquire. Otherwise a reused chip keeps the previous late-casts chip's menu. `ResultChips` (:1000): the late-casts chip gets `item.menu` built by a `LateIgnore.Menu(run)` helper
    (title "Late casts", one "Ignore %s for late casts" per distinct counted spell, "Stop ignoring %s" per
    ignored spell) through `MenuUtil.CreateContextMenu`, guarded when `MenuUtil` is absent. Tooltip adds
    "Right-click to ignore a spell" and dimmed `Ignored: +20.6s Feign Death` lines. The gray "N ignored" chip
    of D-6. No menu on `v.preview` (D-7). Keep the menu builder in `LateIgnore.lua` (S-5).
  - `Results_Detail.lua` `flagRow` (:502) and `buildFlags` (:512): a mouse-enabled overlay on the
    `lateCasts` row with the same menu and a hover hint; a dimmed ignored sub-line; ignored ticks drawn gray
    on the timing strip; the Flags box still shows when only ignored casts exist
    (`Results_Detail.lua:1094` `Heading("flags", has)` and `:709` read `FlagLines`, so `has` also counts
    ignored casts).
  - The other flags tooltips (D-6a): `Runs.StatusTip` (`Results_Runs.lua:612-624`), `DETAIL.flags`
    (`Results_Tips.lua:403-409`) and the late-cast tick tip (`Results_Tips.lua:398`) add the dimmed
    `Scoring.IgnoredText` line.
  - `Results.lua` `RowMenu` (:760): an "Ignore for late casts" submenu when the run has late casts.
  - Tests: `test_hud.lua` / `test_hud_tiles.lua` (chip counts, right-click builds the menu through the
    `MenuUtil` recorder in `tests/wow_mock.lua:107`, no menu on preview, STOP count filtered, redraw after an
    ignore), `test_results.lua` / `test_results_sections.lua` (`FlagLines`, `FlagTexts`, `ShortFlags`,
    Hide flagged and the Flagged badge re-scored, the detail menu, the RowMenu submenu, the StatusTip and
    `DETAIL.flags` ignored line), `test_toast.lua` (an all-ignored new best shows no flags line and no
    "ignored" chip, D-6), `test_tooltips.lua` if it pins the tip texts. Gate green.
- [ ] **I4 Docs and smoke rows, then push.**
  - `docs/ARCHITECTURE.md` (settings table, module map, flags read path), `docs/schema.md`,
    `docs/settings-panel.md`, `docs/data-flow.md`, `docs/module-map.md`, `docs/slash-dispatch.md`,
    `docs/profiles.md` (per-profile list re-scores history), `docs/common-tasks.md` (hearthstone refresh
    recipe; the late-cast chip words entry at :24 gains `LateIgnore`), `docs/known-limitations.md` (static
    table per patch, sealed IDs, automatic follow-up spells, names resolve only for known or candidate spells,
    the profile-scoped list vs global prune protection from D-4),
    `docs/test-cases.md`, `docs/testing.md` suite rows, README features and slash table.
  - `docs/smoke-tests.md`: HUD chip right-click, the ignored chip and undo, the detail flags row, the settings
    list add / remove / Defaults, `/dr ignore`, a toy hearthstone after the buzzer, and a check that the five
    defaults report the listed IDs in game (Invisibility as 66). Update C10.
  - File the D-15 follow-up issue only with the owner's OK (ask at R).
  - Gate green, commit, push the branch.

### N: #12 Insights

- [ ] **N1 Rename and drop the board UI.**
  - `modules/Results.lua`: `TABS = { "runs", "insights" }` (:48); `buildTab` else branch (:152-156) calls
    `NS.ResultsInsights.Build(ui.body, hooks)`; `tabButton("insights", L["Insights"], 2)` (:211); `ShowTab`
    check (:679-681); footer (:425-432) shows the Insights count and hint; header (:3-5) and `ShowRun` (:688)
    comments.
  - Delete `modules/Results_Bests.lua` and its TOC line (`DpsRace.toc:163`). Keep `ResultsSource.Board`
    (used by `Results_Runs.lua:405` and `Results_Compare.lua:199`).
  - `core/DpsRace.lua:121-125` `NS.ShowResults` maps `"insights"` and the legacy `"bests"` to Insights (D-12).
    `settings/Slash.lua:53` help line (and its `locales/enUS.lua:307-308` key) and the comment at :268.
  - `core/LauncherSetup.lua:47`: the toggle's tooltip says "run history and personal bests"; reword for
    Insights.
  - Comment touches: `core/WidgetsSetup.lua:3-4`, `modules/Results_Table.lua:3`, `:182`, `:314`, `:340`,
    `:373`, `modules/Results_Runs.lua:401`, `modules/Preview.lua:8`, `modules/Bests.lua:69`,
    `modules/Scoring.lua:8`, `modules/Results_Source.lua:7`, `:23`, and the file headers of
    `tests/test_results_badges.lua:2` and `tests/test_results_fit.lua:2`.
  - Dead code once the board goes. Grep each one before removing it, and remove only those with no other
    caller:
    - `Tbl.ShortFlags` and `SHORT` (`Results_Table.lua:182-199`; the only caller is `Results_Bests.lua:92`).
    - `CELL.length` and `CELL.flags` (`Results_Tips.lua:152-162`, "the Bests board's length and flags
      columns"; `CELL` is looked up by column key, and no Runs column is keyed `length` or `flags`).
    - The `withName` branch of `Cells.icons` (`Results_Table.lua:314-320`, `:503-511`).
    - The unboxed-badge path of `Cells.badge` ("the Bests Flags", :340).
    - Keep `Bests.Board({ cleanOnly = true })`, `Source.Board(opts)` and the clean board: prune protection
      (`Bests.HoldingIDs`) and the tests still use them. After N1 no window reads the clean board, which is
      expected; record that in `docs/data-flow.md`.
  - `Results.Diagnose` (:854) reports `tab`: the value becomes `"insights"`. Check `modules/Diagnostics.lua`
    and its test for a pinned `"bests"`.
  - Locales: remove `L["Bests"]`, `L["Category: %s"]`, the board hint, the "No personal bests yet" line, and
    `L["Class · Spec"]` after a raw-byte grep shows no other user. Add `L["Insights"]` and the new help line.
  - Saved state (D-14): no migration step. Add a test that a profile holding only `windows.results` and
    `views.runs` from before the rename loads and opens Insights.
  - A placeholder Insights pane (empty state only) so the window works between N1 and N4.
  - Tests: retarget `test_results.lua` (3, 417-418, 1413-1414, 1446-1449) and delete the board cases
    (1164-1222); `test_results_badges.lua` (202, 224-225); `test_results_fit.lua` (34);
    `test_preview.lua` (218-234); `test_results_timeline.lua` (606-607); `test_slash.lua` (283-290);
    `test_sizing.lua` (219-222, 316-325, rewritten for Insights), plus `test_slash.lua` for the `bests` alias
    (D-12). Gate green.
- [ ] **N2 Pure stats module.**
  - `modules/Results_Runs.lua`: export `Runs.OptionLists(runs)` (char, spec, category, length lists without
    the All heads) and `Runs.WithAll(list, label)`, refactoring `charOptions` and friends to use them.
  - New `modules/Results_InsightsData.lua` (`NS.InsightsData`, no frames): `DEFAULTS` (D-11);
    `Filter(runs, f, now)` delegating to `Runs.Filter` (`cleanOnly` to `hideFlagged`); `Options(runs, f, now)`
    faceted with counts, keeping the current selection; `Normalize(f, options)` falling back to All;
    `Compute(runs)` as one pass over `REDUCERS` then `FINALIZERS`, returning `totals` (the 8 cards), `boards`
    (best, avg, CV, n, first, per-run % of best), `progression` (section A), `specCompare` (B, with the chosen
    pair), `consistency` (C), `byChar`, `byCharTarget`, `byLength`, `lateBySpell` (counted and ignored apart,
    "Unknown" for nil IDs), `spellShare` (H, only when one spec), `byDay` (gaps included), `tail` (J buckets),
    `newBests` (K, date order, gain over the previous best). DPS figures use complete runs only; flags go
    through `Scoring.Flags` / `Runs.IsFlagged`, never the raw list.
  - TOC: after `Results_Gear`, before `Results.lua`, with the load-bearing comment.
  - `tests/test_insights_data.lua`: Filter parity, faceted options (picking a spec narrows Length; zero-match
    selection kept, then normalized), Compute on empty and on a fixture shaped like the owner's data (8 cards,
    board-relative %, new-bests count, tail buckets with a 155 s outlier, spell share summing duplicate IDs,
    late-by-spell with ignored apart, a Feign-Death-only run counted clean). Optional `tests/perf.lua`
    scenario over 1000 runs. Gate green, complexity suite clean.
- [ ] **N3 Renderers.**
  - New `modules/Results_InsightsCharts.lua` (`NS.InsightsCharts`): port from LootHistory
    `AnalyticsCharts.lua` / `AnalyticsFormat.lua` the factories `makeBar`, `makeStackedBar`, `makeStripBar`,
    `makeListRow`, `makeSwatch`; chrome `sectionHeader`, `sectionDivider`, `listPanel` (on `Tbl.Panel`);
    renderers `renderBarSection`, `renderStackedBarSection`, `renderLegend`, `renderStrip`,
    `renderListPanel`; helpers `truncate`, `tipText`, `fitFontSize`, the ranked palette; constants `K.*`.
    Colors from `Tbl.COLORS`, `Tbl.CATEGORY_COLORS`, `Tbl.LENGTH_COLORS`, `Tbl.ClassColor` and `Style`, no
    Skin module. A `card(parent, caption)` shaped like `Results_Detail.lua:407` `kpi()`. A local cursor
    tooltip helper (`GameTooltip:SetOwner(owner, "ANCHOR_CURSOR_RIGHT")` plus `Style.AddTipLines`); every
    hover states its value. All frames from `NS.Pool`.
  - Tests in `tests/test_insights.lua` (renderer half): pool reuse over two passes (the second creates
    nothing), tips carry values, legend alignment. Gate green.
- [ ] **N4 Tab, filter bar and layout.**
  - New `modules/Results_Insights.lua` (`NS.ResultsInsights`): `Build(parent, hooks{open, menu, count})`
    returning the view contract (`frame`, `Layout`, `Resize`, `Refresh`, `Count`, `SetFilter`). Filter bar
    with `NS.MakeDropdown` (Character 110, Spec 96, Target 96, Length 88, Date 100), the two checks
    (`Tbl.SetCheckLabel`), Save / Reset / Clear on `profile.views.insights` copying
    `Results_Runs.lua:833-920`; stretch with the `BarPlan` idea so it fits the 904 px collapsed minimum.
  - Below the bar: a plain ScrollFrame with wheel (the `Results_Detail.lua:623-627` pattern), a 4-column card
    grid (wide cards span 2), then a data-driven `SECTIONS` list (A to K) that `LayoutCharts` walks: release
    every pool, re-acquire, y-cursor, skip empty sections, `content:SetHeight(-y)`, one empty-state label
    ("No runs match these filters.") that hides everything. `Resize` re-plans the bar and scroll width only.
  - Section G and K rows: right-click menus (G: ignore or stop ignoring through `LateIgnore.Menu`; K: the run
    row menu); K left-click calls `hooks.open(run)`.
  - Refresh on `RUN_SAVED`, `RUNS_CHANGED`, `SETTINGS_CHANGED` for `race.lateIgnore` or `"profile"`, and test
    mode toggles.
  - `modules/MockRuns.lua`: make sure the sample history covers several boards, days, a flagged run, an
    ignored late cast and `spells`, so `/dr test` fills every section. The ignored cast goes on a run of its
    own and is a Hearthstone (8690), not Feign Death: the sample character is a Warlock (Chaos Bolt 116858 and
    Incinerate 29722 at `MockRuns.lua:119`). The existing Flagged sample keeps its counted late casts, so the
    Status column's *Flagged* sample still shows (`MockRuns.lua:110`).
  - Tests (`tests/test_insights.lua`, tab half, with `mock_widgets`): lazy build; label and gold active
    state; dropdown values from seeded runs; `SetFilter` redraws; faceted narrowing; sections hide when empty;
    empty state; K click lands on Runs with the run selected; G menu through the recorder; saved view
    round trip; test mode sample filled without Save; degraded load (`libFiles={}`) draws no dropdowns and no
    error; `Resize` does not rebind pools; `test_sizing.lua` drag case. Add the new suites to `tests/run.lua`.
    Gate green, complexity suite clean.
- [ ] **N5 Docs and smoke rows, then push.**
  - README (replace the Bests sentence with an Insights paragraph, slash table), `docs/ARCHITECTURE.md`
    (:189 and the module list), `docs/module-map.md` (:74 out, three rows in), `docs/data-flow.md` (:424,
    :476, plus the Insights flow `Source.All` to `Filter` to `Compute` to sections), `docs/performance.md`
    (:41, one pass and pooled), `docs/slash-dispatch.md` (:67), `docs/schema.md` (`views.insights`),
    `docs/testing.md` (:84, :98, :105, :112, new suites), `docs/test-cases.md` (483, 484, 829, 831, 921, 972),
    `docs/common-tasks.md:24` (the Bests board's `SHORT` chip words are gone).
  - `docs/smoke-tests.md`: retire or rewrite K8, W9 (a delete promotes the next run on "the Bests board"), W10,
    W14, W15 (the *Runs* / *Bests* tab labels), SM-DR-BL2, BL4, BL12, DL8, UT28 ("or a Bests row"), UT46; new
    rows for the
    Insights filters and faceting, cards, each section's tooltip, the empty state, resize, test mode, saved
    view, and the G right-click ignore.
  - Gate green, commit, push the branch.

### R: Review and fixes

- [ ] **R1** A review of the whole branch (`dev-copilot:review branch`), plus the standards flags above
  re-checked against the current standard text. Fix what it finds, one commit per fix, gate green after each.
  Ask the owner about S-1 if still open and about filing D-15.

### F: Finalize (only on the owner's go-ahead)

- [ ] **F1** Merge to master, push, close #8 and #12. Delete this run's branches, stashes and worktrees.

## Appendix A: hearthstone spell IDs (D-3)

Source: wago.tools DB2 CSV exports from the research run on 2026-10-28 (SpellCategories, SpellEffect, SpellName,
ItemEffect, ItemXItemEffect, ItemSparse, Toy). The client build was not recorded, so look it up when I1 writes the
file. The rules:

1. Every spell whose SpellCategories `ChargeCategory` is 2309, the shared hearthstone cooldown (8690 and the
   toys).
2. Plus every spell with SpellEffect `Effect` 252 (teleport) and `ImplicitTarget` 9 (the bind point) that a
   toy or item casts.
3. Plus Dalaran Hearthstone 222695 and Garrison Hearthstone 171253 (own cooldowns, fixed destinations).
4. Minus the class spell Astral Recall 556, and minus the other teleport-home candidates the research run
   dropped: 1 and 3 ("(OLD)"), 70195 ("[PH]"), 307896 ("TEST"), 1223998 ("[DNT]"), 49493 (Mole Machine Port
   to Hearth) and 188816 ("Teleport"). The reason for the last two was not recorded; recheck them at I1.

The 59 IDs, with the enUS names they carry today (the names are for review only; the file stores IDs):

8690 Hearthstone; 39937 There's No Place Like Home; 48129 Scroll of Recall; 54403 Scourgestone; 60320 Scroll of Recall; 60321 Scroll of Recall; 75136 Ethereal Portal; 94719 The Innkeeper's Daughter; 136508 Dark Portal; 171253 Garrison Hearthstone; 191329 Hearthstone; 222695 Dalaran Hearthstone; 231504 Town Portal; 231505 Town Portal; 278244 Greatfather Winter's Hearthstone; 278559 Headless Horseman's Hearthstone; 279066 Weary Spirit Binding Return; 279741 Scroll of Luxurious Recall; 285362 Lunar Elder's Hearthstone; 285424 Peddlefeet's Lovely Hearthstone; 286031 Noble Gardener's Hearthstone; 286331 Fire Eater's Hearthstone; 286353 Brewfest Reveler's Hearthstone; 298068 Holographic Digitalization Hearthstone; 300047 Mountebank's Colorful Cloak; 308742 Eternal Traveler's Hearthstone; 326064 Ardenweald Hearthstone; 340200 Necrolord Hearthstone; 342122 Venthyr Sinstone; 345393 Kyrian Hearthstone; 350944 Town Portal; 363799 Dominated Hearthstone; 366945 Enlightened Hearthstone; 367013 Broker Translocation Matrix; 375357 Timewalker's Hearthstone; 391042 Ohn'ir Windsage's Hearthstone; 401802 Hearthstone; 412555 Path of the Naaru; 420418 Deepdweller's Earthen Hearthstone; 422284 Hearthstone of the Flame; 431644 Stone of the Hearth; 438606 Draenic Hologem; 463481 Notorious Thread's Hearthstone; 1217281 Redeployment Module; 1220729 Explosive Hearthstone; 1240219 P.O.S.T. Master's Express Hearthstone; 1242509 Cosmic Hearthstone; 1250878 Timerunner's Hearthstone; 1254117 Lightforged Phase Beacon; 1261979 Lightcalled Hearthstone; 1270583 Naaru's Enfold; 1270814 Preyseeker's Hearthstone; 1273401 Corewarden's Hearthstone; 1286909 Mycomancer's Hearthspore; 1299014 Mycomancer's Hearthspore; 1299513 Lightveil Hearth Beacon; 1310234 Hiveborne Hearthstone; 1310840 Wood-Cursed Hearthstone; 1311934 Shadeweaver's Hearthstone; 

Borderline entries for the owner: consumables and non-hearthstone items that share the hearthstone cooldown or
teleport home. They are 48129 / 60320 / 60321 Scroll of Recall, 279741 Scroll of Luxurious Recall, 54403
Scourgestone, 75136 Ethereal Portal, 136508 Dark Portal, 300047 Mountebank's Colorful Cloak, 367013 Broker
Translocation Matrix, 412555 Path of the Naaru, 1217281 Redeployment Module, 1254117 Lightforged Phase Beacon,
1270583 Naaru's Enfold and 438606 Draenic Hologem. They are kept, because "every alternate hearthstone" reads as
everything that sends you home on the hearthstone's cooldown. Ask at R if unsure.

Refresh recipe (for `docs/common-tasks.md`): download SpellCategories, SpellEffect and SpellName for the new
build from wago.tools, re-run rules 1 to 4, diff the result against `defaults/Hearthstones.lua`, and update the
table and its pin test (the count, and that 8690 / 222695 / 171253 are present and 556 is absent).
