# Smoke tests

The in-game checks no headless run can reach: real rendering, the real damage meter, taint, and
client behavior the spec could not measure ahead of time. The owner runs them once, end to end,
before a release. One pass takes about an hour on a character in Silvermoon, which has every dummy in
the catalog (spec §4.6).

## Sign-off

| Date | Build | Result |
|---|---|---|
| 2026-10-24 | 0.1.0 (branch `feat/pve-v0.1.0`, tip ef6aaf1), client 12.0.5 (120105) | Full pass by the owner: every row passed, after the smoke-pass feedback round (live DPS rungs, clock modes, center countdown, restyle, title-bar hover) |

### Pending sign-off

Rows changed for the Keybindings tab's one key button and not yet run by the owner: SM-DR-KB2
and SM-DR-KB3 (rewritten), and SM-DR-RV3 (new).

Rows for the 2026-10-24 pass (branch `feat/2026-10-24-hud-styling-status-arm`), not yet run: S3, S6,
R1, W1, W3, W4, W7, W17 and SM-DR-LY1 (rewritten), section 10, W5b and W8b (new), and W5 again for its timing strip (its marks drew under the segments; every line mark is now one size, Restart is violet, and the legend is two rows: Race and Tail, then Grace, Late cast, Combat ended and Restart).

Rows for the 2026-10-25 pass (branch `feat/2026-10-25-chart-compare-loadout`), not yet run: section 11's
SM-DR-CP1, SM-DR-CP2, SM-DR-CP3 and SM-DR-CP4 (new: the detail's compare, #7); section 12's SM-DR-CH1 to
SM-DR-CH10 (new: the damage chart and the pace bar, #2 and #3); section 13's SM-DR-LO1 to SM-DR-LO11
(new: equipment and talents, #6); S3 again (the Race HUD tab's new *Chart and pace* subsection); and
SM-DR-LY3 again (History's new *Sharing* subsection and its *Include talents link* above *Runs to
keep*).

Rows for the 2026-10-25 feedback round on the same branch (the owner's in-game test), not yet run:
section 14's SM-DR-FB1 to SM-DR-FB5 (new); SM-DR-CH1, SM-DR-CH2, SM-DR-CH7 and SM-DR-CH8 (rewritten:
no gold best line, touching columns, the new styling blocks); SM-DR-LO4 (rewritten: *View* posts a link
to chat, and the in-combat action-bar check); S3, W5 and W7 again (the new HUD Appearance blocks, the
detail's header and headings, the wider window).

Rows for the 2026-10-25 backlog (branch `feat/2026-10-25-results-badges-sim`), not yet run: section 15's
SM-DR-BL1 to SM-DR-BL4 (new: the boxed Status badges and the race length colors) and SM-DR-BL5 (new: Group
by *Duration* and *Target + duration*), SM-DR-BL6 (new: *Pace bar range*), SM-DR-BL7 and SM-DR-BL8 (new: the
result card's pace bar); W1 and W7 again (the Status badges,
the wider window minimums), W4c again (the wider *Group* dropdown), S3 again (*Pace bar range* under *Chart and
pace*), and SM-DR-CH3 (rewritten: the tick two thirds along at the default range); SM-DR-BL9 (new: the
talent tree's open no longer closes the Results window); SM-DR-BL10 to SM-DR-BL16 (new: `/dr test`'s
static sample data in the HUD and the Results window, and `/dr sim`'s scenarios and end conditions), and P5, P6, P11, R7a,
R8e, SM-DR-CH8, SM-DR-CH9 and SM-DR-BL8 (rewritten: the scripted race moved from `/dr test` to
`/dr sim`).

Rows for Round C of the same backlog (the owner's notes after testing it), not yet run: section 16's
SM-DR-RC1 (new: the detail's larger headings and the space above them), SM-DR-RC2 (new: the HUD's *Damage
profile* and *Spell breakdown* headings, the pace bar under the first, the 560 default height), and P6, H2,
SM-DR-CH1, SM-DR-CH6, SM-DR-CH10, SM-DR-FB2, SM-DR-BL7 and SM-DR-BL12 again (the chart's new name and
place, the 354 minimum); SM-DR-RC3 (new: the centered pace bar), SM-DR-CH3 and SM-DR-BL6 (rewritten: the
tick in the middle, *Pace bar range* 1.1 to 2.0) and S3 again (the slider's new bounds and tooltip);
SM-DR-RC4 to SM-DR-RC7 (new: *Stop Now* and *Cancel* on the Stop! and waiting screens, in a race and in
`/dr sim`), SM-DR-RC8 and SM-DR-RC9 (new: the result card's *Delete* and its four equal buttons),
SM-DR-RC10 (new: the best's diagonal on the chart after the race), and R10, R12, R17 and SM-DR-CH5
(rewritten: the waiting body's buttons, the card's four buttons, the chart's shared scale).

## How to run it

- Set `/console scriptErrors 1` first, and keep `/dr debug on` for the whole pass. The debug console
  (`/dr debug`) is where most failures leave their evidence.
- Work down the page in order. Sections 1 to 4 set up what the later ones use, and section 9 (client
  assumptions) is mostly answered by watching the earlier sections closely.
- Tick each row or mark it failed, with the date and the build (`/dr version`, and the client build
  from the login screen). A failure becomes a GitHub issue, named with the row ID (for example
  *R7: Stop! never shows*).
- **Every failure report carries** the row ID, what happened instead, and the output of
  `/dr diagnostics` copied from the debug console right after the failure (the report follows the
  trace in the same window, so one **Copy** carries both). The *If it fails, report* column lists
  what to add beyond that.
- A class is named where the check needs one: a Hunter (Auto Shot, Feign Death), an Evoker
  (empowered casts), any caster with a channel and a cast-time spell, and any class that can die
  to the Dungeoneer's dummy.

## 1. Load and identity

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| L1 | Log in with the addon enabled | No Lua error; the AddOns list shows *Ka0s DPS Race* with the logo icon | The error text with its stack |
| L2 | `/dr version`, then `/dpsrace version` | Both print the TOC's version (0.1.0) | Both lines |
| L3 | `/dr help` | Every command prints, the feature verbs after `version`; the settings landing page lists the same rows | The missing or extra rows |

## 2. Settings panel

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| S1 | Open *Settings → AddOns* right after login | *Ka0s DPS Race* is there before the panel was ever opened | Whether `/dr` opens it |
| S2 | Open the landing page, switch pages and come back | The logo, notes line and command list show; the logo is never drawn under the list | A screenshot |
| S3 | Open General, then HUD | General has two tabs: *Master controls* (rows in the standard's order) and *Keybindings*. HUD has two: *Race HUD* (*Display*, *Live breakdown* and *Chart and pace*) and *HUD Appearance* (its last three blocks *Damage chart*, *Chart background* and *Pace bar*) | A screenshot |
| S4 | Look at the page order | General, Race, HUD, History, Profiles: Race and History each a one-tab strip with subsection headings, HUD just above History; there is no *Live breakdown* page | A screenshot |
| S5 | On Race, drag the grace slider; hover it | It steps by 0.1 from 0 to 5; the tooltip says it applies to new runs; the length dropdown offers 0:30 to 5:00 | The values it stops at |
| S6 | On HUD > Race HUD, set *Spell rows shown* to 3, then 15, then 0, with the HUD running a race | The live list shows 3 rows, then as many as fit (never under *Cancel*); at 0 as many as fit, the caption reads *1-N of M*, and the mouse wheel scrolls the list a row a notch, stopping at either end. Let the race finish: the result card lists the same way (3 rows, as many as fit, then every spell with the wheel at 0), not a fixed top 5 | A screenshot |
| S7 | On History, type 10000 into *Runs to keep*'s box | Accepted at once, without a stall; nothing is deleted on the spot | How long it froze, if it did |
| S8 | Press each page's *Defaults* button after changing one row on every page | Only that page's rows go back | Which page's rows moved |
| S9 | History: *Purge history…* with a race armed, then with none | Armed: one refusal line, nothing deleted. Idle: it asks first, and on accept the stored count reads 0 and the Results window empties | The chat lines |
| S10 | Open the panel in combat | Refused with a notice; it opens once combat ends | Whether any taint error followed |
| S11 | *Reset all settings* | It asks first; afterwards the minimap button keeps its state and *Test mode* is unticked | The settings that did not reset |
| S12 | Profiles: create, switch, copy and delete a profile | Each works; run history is unchanged by all of them (it is account-wide) | The Results count before and after |
| SM-DR-LY1 | Open HUD > Race HUD; hover *Show the race HUD* and the page's *Defaults* | A *Display* heading over *Show the race HUD* \| *Race clock*, then a *Live breakdown* heading over *Spell rows shown* \| *Show spell icons* and *Show live DPS* \| *Live reads per second*. The show mode's tooltip ends with the *General visibility* sentence; the Defaults tooltip names the Race HUD tab (display and live breakdown) and HUD Appearance. General's Defaults tooltip names Master controls only and ends *Key bindings are not changed.* Change a live row, press the HUD page's *Defaults*: it goes back | A screenshot of the tab |
| SM-DR-LY2 | Open Race | One tab, headed *Length*, *Countdown*, *At the buzzer*, *Scoring rules* in that order: *Countdown cue sound* alone on its line, then *Center-screen countdown* \| *Center countdown from (seconds)*; *Buzzer raid warning and sound* \| *Sticky-combat hint after (seconds)* (its tooltip ends *5 to 60 seconds.*); *Late-cast grace (seconds)* \| *Damage-restart gap (seconds)*. No *Scoring rules* tab | A screenshot of the page |
| SM-DR-LY3 | Open History; hover *Runs to keep* and the last button | *Sharing* with *Include talents link*, then *Storage* with *Runs to keep*, the stored-count line, then *Purge history…* last, with no *Danger zone* heading. The slider's tooltip opens *Account-wide: shared by every profile.* The button still asks first and deletes every run on accept | A screenshot of the tab |
| SM-DR-LY4 | Before the pass, note every value on HUD > Race HUD, Race and History (or `/dr list`); after it, compare, then `/reload` and compare again | No setting is lost or changed by the new layout, `/dr list` shows the live rows under *hud › Race HUD*, and every value survives the `/reload` | The row that differs |

## 3. Launcher, key bindings and slash

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| K1 | Look at the minimap button; hover it | The logo shows; the tooltip has the version and status, also while disabled | A screenshot |
| K2 | Left-click, then right-click the button | Left opens settings; right shows exactly *Enabled*, *Locked*, *Test mode* and *Show window* (spec §6.4: no Results or Arm entry) | The menu as drawn |
| K3 | Turn *Minimap button* off, then on | It hides, then comes back in the same place | Where it came back |
| K4 | *Options → Keybindings → Ka0s DPS Race* | *Toggle race HUD*, *Toggle results window* and *Arm or cancel race* are listed, none bound | The list as shown |
| K5 | Bind all three; press each | The HUD toggles; the Results window toggles; the arm key arms the HUD's length, a second press cancels | Which key did what |
| K6 | Press the arm key while a result is pending (section 4, R8) | It discards nothing and prints one line pointing at `/dr cancel` | The line |
| K7 | `/dr arm 1:30`, `/dr cancel`, `/dr arm 0`, `/dr arm 3m`, `/dr cancel` | 1:30 arms with the *Armed* line; cancel cancels; `0` prints the length line; `3m` arms 3:00 | Each line |
| K8 | `/dr hud show`, `hide`, `toggle`, bare `/dr hud`; `/dr results`, `/dr results bests`; `/dr lock`, `/dr unlock` | Each acts and echoes once; `/dpsrace` answers the same as `/dr` | The verb that misbehaved |
| K9 | Target each catalog dummy and `/dr target` | Its name, creature ID and category print (243167/243168 Dungeoneer, 243208 Cleave, 243205 Boss-level, 243211 PvP); an uncataloged target prints *Other* | The line for each |
| K10 | Arm with `/dr arm 30` with the HUD's *Test mode* box ticked in settings | Test mode ends with one line and the settings checkbox unticks | Whether the box stayed ticked |
| SM-DR-KB1 | *Options → Keybindings*, scroll to the addons' sections | A section titled *Ka0s DPS Race* holds *Toggle race HUD*, *Toggle results window* and *Arm or cancel race*, in that order; no blank spacer row above or among them; nothing of DPS Race is left under *AddOns* | A screenshot of the section |
| SM-DR-KB2 | Bind a key with the key button in *General > Keybindings* in this addon's settings, then look in *Options → Keybindings*; bind a second key there, then reopen the tab and hover the button. Repeat with *Character Specific Keybindings* ticked | Each key shows in the other surface, in both account and character-specific modes; the button reads *<first key> +1* and its tooltip names both keys; the tab's set line names the set in force | Which surface missed which key, and the mode |
| SM-DR-KB3 | Press the bound *Toggle race HUD* key; on the tab, click a key button and press Escape; right-click a bound key button; enter combat and click a key button | The key toggles the HUD; Escape cancels the capture and the Settings window stays open; the right-click clears the first key (a second moves up); in combat the button refuses with *Key bindings can be changed after combat.* and binds nothing | The outcome line and any error |
| SM-DR-RV3 | Open *General > Keybindings*; bind *Toggle race HUD* there and press the key; then press the row's *Clear* | Each action shows one key button and *Clear*, no second key slot; the key bound there toggles the HUD; *Clear* removes every key of the action | A screenshot of the tab |

## 4. The race on a real dummy

Use a 0:30 race on the Reinforced Golem (243205) unless a row says otherwise. The HUD opens at
300×460 the first time (spec §6.1).

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| R1 | `/dr hud show` with no target, then target the Golem | Idle body: the five presets and *Custom*, the target card (*No target*, then the name with the *Boss-level* badge and the count stepper), *Arm Race*, and one *Results* button across the foot (no *Last Result*). Nothing overlaps | A screenshot |
| R2 | Target a non-dummy creature | The card warns *Unknown target: recorded as Other: name* | A screenshot |
| R3 | *Custom*: type `90`, then `1:30`, then `3m`, then `5` | The first three are accepted (1:30, 1:30, 3:00); `5` is refused with the 0:10 to 15:00 line | Each result |
| R4 | Enter combat on anything, then look at *Arm Race* | Grayed with *Leave combat to arm*; a click prints the same line | A screenshot |
| R5 | Arm 0:30 out of combat | Armed body: 0:30 large and still, *First hit starts the clock*, the target card, *Cancel*; the chat prints the *Armed* line | A screenshot |
| R6 | Open with a cast-time spell, then on a second run with an instant | Both times the countdown starts on the frame the first hit lands (not on the cast's start), to a tenth of a second | Debug lines tagged `Race`, and which opener failed |
| R7 | Keep attacking through the race | Running body: with *Race clock* at its default, *Elapsed* in green on the left and *Left* in red on the right, each in `m:ss.t`, counting up and down together; *Damage* and *DPS · Live* figures; the live rows with icon, name, bar and amount, and no percentages; the header reads *Live order · % after the race* | A screenshot at about 0:15 left |
| R7a | HUD → Race HUD → *Race clock*: *Time left*, then *Time elapsed*, then back to *Elapsed and time left*, during a race and in test mode (`/dr test`, the still running body); then drag the HUD to its minimum width (260) | One big red clock, then one big green clock, then the pair; the switch takes effect at once. At 260 px wide the two clocks and their captions do not touch or clip, also at 9:59.9 | A screenshot at the minimum width |
| R8 | Hear the last 10 s | With the defaults the cue sounds once a second from 10 down to 1, never twice in a second. With *Center-screen countdown* off it sounds at 10, 5, 3, 2 and 1 only. *Countdown cue* off silences it mid-race | Which seconds were silent or doubled |
| R8a | Watch the last 10 s of a 0:30 race, HUD open, then again with the HUD closed | Gold numbers 10 down to 1 pop in (grow and fade in, with a glow flash) in the middle of the screen above the character, one a second; *10* is two digits, centered; they vanish at the buzzer, and the raid-warning *STOP* still shows. Nothing is clickable through them (the mouse passes through). Nobody else in the group sees a pull timer | A screenshot of *10* and of *1*, and whether a groupmate saw anything |
| R8b | Race, Race page: *Center countdown from (seconds)* 3, then *Center-screen countdown* off mid-countdown | The numbers start at 3. Switching it off hides the number on screen at once | |
| R8c | Cancel the race with 5 s left; drop combat with 6 s left on another run | The number on screen goes at once, and no further number or cue follows | |
| R8d | `/reload` with about 6 s left, still attacking | After the loading screen the number of the moment shows at once (silently) and the count carries on to 1 | The numbers seen after the reload |
| R8e | `/dr sim`, watch the sample race's last 10 s; then start it again and end it with `/dr test` during its countdown; then `/dr test` and wait | The numbers show silently in the sample race and go with its buzzer; ending the sim clears them at once; `/dr test`'s still running body shows none | |
| R8f | With about 8 s left on a race, open a Results filter dropdown so the menu crosses the center-screen numbers | The menu draws over the numbers, and they still draw over any open confirmation popup or the debug console | A screenshot |
| R9 | Stop on the buzzer | A raid-warning **STOP** with a sound; the HUD switches to *Stop!*: *Damage Stopped +x.xs* climbing while DoTs tick, the late-cast count, *In Combat +y.ys* | A screenshot |
| R10 | Stay idle in combat on the Dungeoneer's dummy for 20 s after the buzzer | The body moves to *Waiting for combat to end* with the elapsed time, *Stop Now* and *Cancel*; after 15 s the hint appears naming only drop-combat abilities this character has (Feign Death, Vanish, Shadowmeld, Invisibility) | The hint's text and the class |
| R11 | Close the HUD while waiting, walk out of range | The result card opens by itself about 2.5 s after combat drops | How long it took |
| R12 | Read the result card | Damage, DPS (damage ÷ 30.0 exactly; check with the detail), the best delta (*New best* on a first run), the flag chips, the spells (as many as *Spell rows shown*, or all of them, wheel-scrolled, at 0) with %, *Race Again*, *Details*, *Share* and *Delete* in one row; the chat prints the score line once | A screenshot and the score line |
| R13 | *Race Again* | The window stays open on the *Arm Race* screen with 0:30 picked and the same target count; nothing is armed until *Arm Race* is pressed, which arms 0:30 | The screen it went to |
| R14 | Stop attacking at about 0:12 left and drop combat | The run becomes incomplete: the card says *Incomplete (combat ended at m:ss)* and its DPS is damage ÷ the time fought; it never appears on the Bests board | A screenshot |
| R15 | Let the Dungeoneer's dummy kill you mid-race | *Incomplete: died* on the card | A screenshot |
| R16 | Cancel while armed, and while running | Nothing is stored (the Results count does not move); the HUD returns to idle | The count before and after |
| R17 | *Cancel* while waiting | The HUD returns to idle; the run does not appear in Results | Whether it was stored |
| R18 | Close the HUD on a result card (the close button, then Escape on a fresh card) | The card is dismissed; the run stays in Results | Whether the run went |
| R19 | Reset Blizzard's damage meter from its own window while armed, then while running | Armed: the race stays armed. Running: the run becomes *Lost* and the HUD says so | The state after each |
| R20 | Turn Blizzard's damage meter off (if the client allows it) and look at the idle HUD | *Arm Race* is grayed with the reason Blizzard gives | The reason text |
| R21 | Set *Show HUD* to *On arm only*, close the HUD, `/dr arm 30`, race, dismiss the result | The HUD opens on arm and closes again when the race returns to idle | Whether it stayed open |
| R22 | Same with *Always*, then `/reload` | The HUD is open after the reload | |

## 5. Reload, restart and logout

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| X1 | `/reload` at 0:15 left, still attacking | The HUD comes back on the same countdown (the race's clock survived the reload); at the buzzer the run reaches Stop! and resolves normally | The countdown before and after the reload |
| X2 | **O4.** On the Dungeoneer's dummy, `/reload` 2 s after the buzzer while still in combat | After the reload the HUD is in *Waiting*; once combat drops the result reads, with the *Reloaded* chip, and the tail still counts updates heard before the reload. A loading screen longer than 6 s while DoTs tick does not raise *Restarted* | The card, and the run's detail timing strip |
| X3 | `/reload` mid-race, then drop combat before the buzzer would have gone | The run resolves as incomplete, read at once, without the *Reloaded* chip | The card |
| X4 | `/reload` while waiting out of combat, before the read | The result reads straight after the reload, with the *Reloaded* chip (the run was past its buzzer) | |
| X5 | **O3, the restart case.** Stop at the buzzer, stay in combat on the Dungeoneer's dummy for 10 s without attacking, then attack again | The result carries *Restarted +x.xs* (about +10 s), and the run still counts on the board | The card. If no chip: the debug trace, and whether damage was landing during the 10 s (a DoT) |
| X6 | **O5.** Arm and race on the Dungeoneer's dummy, log out to the character screen while waiting, log back in | Either the result reads, or the run shows *Lost* (*Couldn't read the result*) and keeps its metadata. Record which: it settles O5 | Which of the two, and the run's detail |
| X7 | Race, and while waiting for the read log out to the character screen and into **another** character | The other character is idle: no HUD resume, and *Arm* works there. Back on the first character the run resumes (or is *Lost*, per X6) | Which character resumed it |

## 6. Results window

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| W1 | Open Results after sections 4 and 5 | *Runs* tab: every resolved run, newest first (the *Date* header carries the arrow); after a `/reload` it is newest first again, whatever was sorted before. The *Time* column reads *2:00 +11.1s* (the tail in gray) or *1:04 / 2:00* for an incomplete run; the DPS column shows every run's DPS, incomplete ones included, and a dash for a lost one; the *v/s Max* column reads *0.0%* in gold on the complete run with the highest DPS among the runs the filters pass on the same target type (Cleave against Cleave, Boss-level against Boss-level), a red negative on every slower complete run, the incomplete runs' figure muted (it can read above the max), and a dash for a lost run or a view with no complete run; widening to *All characters* moves the max; the *Status* column tags each run with a boxed badge, its icon inside before the word, box and word in the tag's hue: *Max* (violet crown: the complete run with the highest DPS among the runs the filters pass, on its target type, shown only when that type's runs span more than one spec; with one spec the top run reads *Spec best*), *Spec best* (blue trophy: its spec, dummy type and length's best; *cleave · 2:00* follows the box in plain text, the time in its length color, as it does after *Max*), *Complete* (green check), *Flagged* (red flag; there is no separate flag column, the Status cell's tooltip lists the flags), *Incomplete* (orange x), *Died* (pink skull) or *Lost* (gray ghost), every hue distinct; the *Target* column is colored text with no box; every column (headers too) is left-aligned; the rows alternate their stripe; the *Damage* and *DPS* cells carry a bar in the spell breakdown's indigo, with white text and no track or border, running from 10% of the cell on the smallest figure among the runs the filters pass on the same target type to the full cell on that type's largest (Boss-level runs fill against Boss-level runs, Cleave against Cleave) (linear between them; a lone run, or equal figures, fill the cell; a lost run has none), so widening to *All characters* rescales every bar; no running or stopping run is listed | A screenshot |
| W2 | Hover the class and spec icons | The class icon is cropped cleanly (from `CLASS_ICON_TCOORDS`), the spec icon is the spec's own (from `GetSpecializationInfoByID`); each tooltip names it | A screenshot of a bad crop |
| W3 | Open Results: the character filter reads *Current character* and the spec filter *Current spec*, listing only this character's runs in their active spec (each dropdown also offers *All characters* / *All specs* and every name). Open each filter dropdown and pick a value; tick *Hide flagged*, untick *Include incomplete*, tick *Only best* (only the runs tagged *Best* stay, one per spec, dummy type and length) | The dropdowns open and filter; the checkboxes (Blizzard's stock art) toggle and filter; the count follows | The filter that did not apply |
| W4 | Sort by DPS, ilvl, date, Time and Status | Each sorts both ways; incomplete and lost sort last on DPS; Status groups Best, Complete, Flagged, Incomplete, Died, Lost | |
| W4b | Open the *Group* dropdown and pick each mode; click a group header twice; with *Group: Character*, click the *Character* header | *Group: None* is the default. Character, Class & spec and Target each split the list under gold headers (*Character: Lânfear (12)*, a chevron before the label, the count in gray); the sort still holds inside each group; a header click folds its group (chevron right) and a second unfolds it; the grouped column's header flips the groups' order; after a `/reload` the list is flat again | A screenshot of each mode |
| W4c | Set some filters, a *Group* and a sort, press *Save*; change them, press *Clear*; `/reload` and reopen; press *Reset* | The filter bar is two rows: the dropdowns, then the checkboxes and *Save* \| *Reset* \| *Clear*, right-aligned under the *Group* dropdown. The run count is in the window footer, before *Click a row for details*. *Save* prints *Runs view saved as default.*; *Clear* returns to it; after the `/reload` the window opens on it; *Reset* prints *Runs view reset to stock defaults.* and shows your character and spec, ungrouped, newest first | The chat lines |
| W4d | Hover every column header, then every cell of a row (and a group header) with the window near the right edge of the screen, then near the left | Each header shows its name in gold and what it means, under the header. Each cell shows its own tooltip (the full date and build; the spec and class; the realm, race and zone; the item level; the target's name, level, creature ID and your count; the length, the DoT tail and when combat ended; the exact damage and DPS with how DPS is worked out; v/s Max's max; the status and every flag), level with the row and beside the window: on its right, or on its left when the right has no room | A screenshot of each side |
| W5 | Click a run | The detail: header (28 px class and spec icons, the character's name large beside them with no spec text, then ilvl, zone and subzone, target, date, build, version), score block with meter DPS muted and the best delta, the *Spell breakdown* heading over the compare toggle and the full breakdown with %, the timing strip (buzzer, grace, tail band, late-cast ticks, combat end, restart tick), flags with explanations, the note under its *Note* heading, *Share*, *Delete* | A screenshot |
| W5b | In each view (expanded, then collapsed with the detail open), hover every part of the detail: the class and spec icons, the name, each meta line, the three figures, the best delta, every spell row, the Timing label, strip, axis labels and tail line, each legend item, the flags box, the note, *Back*, *Add Note*, *Share* and *Delete* | Each spell row shows the client's own spell tooltip, then its exact damage, its share of the run and its place (*#3 of 13 spells*), level with the row and beside the window (its right, or its left with no room there). Every other part shows its tooltip under itself, its title in gold. The wheel still scrolls the detail with the pointer over a spell row or a hover spot, and no tooltip appears for a spell row scrolled out of view | A screenshot of a spell tooltip, and any part with no tooltip |
| W6 | Scroll a long breakdown with the mouse wheel; drag the list's scrollbar with 20+ runs | The detail scrolls; the slider drags and the list follows | |
| W7 | Press the title bar's chevron (left of the close control), then click a run, then the chevron again | A new profile opens expanded (the detail beside the list, the filter bar on one row, the chevron pointing left). The chevron collapses it: the list alone at its own size (980 wide by default, 932 at least), the filter bar on two rows, the chevron pointing right. A click on a run puts its detail in the list's place with a back control; back returns with the row still selected. The chevron expands it again at its own size (1300 by default, 1292 at least), the window's top-left corner staying put. Resizing either view as narrow as it goes never switches it | A screenshot of each view |
| W8 | Type a note with a `|` in it and press Enter; reopen the run | The note is saved with `/` in place of `|`; Escape instead cancels the edit; at most 200 characters fit | The stored note |
| W8b | Open a run with a long breakdown, scrolled to the top, and press *Add Note* (and the row menu's *Add Note* from the list) | The detail scrolls to its foot, the note box shows there with the cursor in it, and typing goes into it | Whether the box was off-screen |
| W9 | *Delete* a run holding a best | It asks first; on accept the run goes and the Bests board promotes the next run | The board before and after |
| W10 | *Bests* tab | One category at a time (no *All*), starting on the first category present in catalog order. Each row: date, character, ilvl, damage, DPS and flag words (*1 late*, *Restarted*, *Reloaded*, *By list*, *Died*). *Clean runs only* drops flagged rows. Note whether starting on the first category reads well, or the newest run's category would be better | A screenshot, and the owner's view on the starting category |
| W11 | Move and resize the window, `/reload` | Position and size persist; *Master scale* scales it too | |
| W12 | Escape with the window focused; Alt-Z | Escape closes it; Alt-Z hides and shows it without counting as a close | |
| W13 | Open and use the window in combat | It opens, redraws and sorts with no taint error or blocked-action message | The error text |
| W14 | Look for the `×` (target count) and `—` (empty damage) glyphs | Both render in the client font, not as boxes | A screenshot |
| W15 | Open Results beside LootHistory's browser | The same look: the title centered in the title bar; *Runs* / *Bests* tabs in the normal gold font, the idle one gray; Title Case column headers small and gold with the gold sort arrow after the sorted one; compact 20 px rows in the small white font; the detail's Damage / DPS / Meter DPS figures large over small gray captions; 20 px buttons in the small white font (*Add Note*, *Share*, *Delete*), gold under the pointer; footers small and gray | A screenshot beside LootHistory |
| W16 | Hover the close control | It turns gold (not red) and back to gray on leave | |
| W17 | In the expanded view, check that every Runs column fits beside the detail with the character name readable, click a run, then open each filter dropdown over the detail | The detail beside the list draws whole (its backdrop, KPI figures, breakdown and buttons over nothing of the list), the filter menus open over it, and the resize grip still takes the drag | A screenshot |

## 7. Share and test mode

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| P1 | *Share* on the result card, then in the Results detail; right-click a row, then double-click one | A menu opens (Say, Party, Raid, Guild, Whisper…) with channels you are not in grayed. The right-click opens the row's menu: the run's date as its title, *Add Note* (*Edit Note* once it has one: it opens the run with the note box focused), *Share* with the same channels as a submenu, and *Delete* in red, which asks first. A double-click does nothing more than a click; the footer reads *Click a row for details · right-click for options* | A screenshot of each menu |
| P2 | Pick *Say* outside an instance | The mockup's one line posts: *DPS Race 0:30 · target ×count · spec ilvl · damage · DPS (Ka0s DPS Race)*, *incomplete* added for an incomplete run, no flags | The posted line |
| P3 | Pick *Whisper* with a player targeted | A popup with an edit box opens, prefilled with the target's name; accept sends | Whether the box was there and prefilled |
| P4 | Share in combat; share during the client's chat lockdown (a boss encounter or rated PvP) | Refused with one line each; nothing posts | The lines |
| P5 | `/dr sim` | Armed, Running, Stop!, Waiting and Result play on the HUD with the amber strip under the title (*Test mode: sample numbers. Combat or Arm ends it*); the result card holds, and about 4 s later the Results window opens on the sim's run. The sample spells show real icons and names in both windows, for every class in the sample history (re-check the spell IDs in `modules/MockRuns.lua` on this patch) | Any spell shown as *Unknown spell* or a question-mark icon |
| P6 | With `/dr test` on, `/dr test armed`, `/dr test running` and `/dr test result`, drag and resize the HUD to its minimum (260×354) on each | The strip glyph and its text still fit; nothing overlaps | A screenshot |
| P7 | Enter combat during test mode | It ends with one line | |
| P8 | Start test mode, then arm a real race | Test mode ends with one line and the HUD shows the real race | |
| P9 | Leave a real result card up, start `/dr test` over it, and close the HUD | Closing ends test mode only; the real run is unaffected | The real run's state after |
| P10 | Try `/dr test` while a real race is armed | Refused with one line | |
| P11 | `/dr test`, then `/dr sim` to the Results window, add a note to a sample run and delete another, then end it and `/reload` | The Results window shows your own history again with its count unchanged, no run named *Sampleblade*, *Mockflame* or *sim-…* anywhere, and none after the reload | Any sample run in your history |

## 8. HUD sizing, disabled state, debug and performance

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| H1 | A fresh profile's HUD during a race | 300×460, all 8 live rows visible | A screenshot |
| H2 | Drag the grip to the minimum (260×354) and look at every body (use test mode) | Arm and the links stay clear; live and result rows are capped above the buttons; nothing runs off the window | A screenshot of each body that clips |
| H3 | Move and resize the HUD, `/reload` | Position and size persist; lock stops the drag and the grip | |
| H4 | Alt-Z with the HUD shown on a result card | The card is still there when the UI comes back (a hidden parent is not a close) | |
| H5 | Open the HUD and LootHistory's browser side by side and walk every HUD body (test mode) | The same look: the title *DPS Race* centered in a 30 px title bar in the header gold; section labels (*Race Length*, *Target*) small and gold; buttons, presets, spell rows, chips and the target card's text in the small white font; footers and KPI captions small and gray; Title Case labels and buttons, no ALL-CAPS word but *STOP*; the race clocks, *STOP* and the Damage / DPS figures still large | A screenshot beside LootHistory |
| H6 | Hover each title-bar control in turn (Results, settings, lock, close), sliding straight from one to the next, then off the bar | The control under the pointer turns gold, the rest stay gray, all at full alpha; sliding from one to the next never leaves both gold or neither; off the bar all four are gray again; each still shows its tooltip (the close control has none). The close control is gold, not red | Which control stayed gold or never turned |
| H7 | Drag the HUD partly under another addon's MEDIUM window (or Blizzard's character frame), then click the HUD | The click brings the HUD in front of it; the Results window, the Settings panel and confirmation popups still draw over the HUD | Which frame stayed in front |
| D1 | `/dr disable` | Every right-click menu entry but *Enabled* is grayed; `/dr help`, `config`, `list` and `diagnostics` still answer; the feature verbs print the one disabled line | |
| D2 | Press each key binding while disabled | The one disabled line, nothing else | |
| D3 | `/dr enable` | Everything comes back without a `/reload`; a race armed before the disable is gone, a stored running run resumes like a reload | |
| D4 | `/dr debug on`, `/dr debug` | The console opens with `[Debug]` and `[Init]` lines | |
| D5 | `/dr diagnostics` | The report follows the trace, with begin and end markers naming *Ka0s DPS Race* and a race line; **Copy** copies it whole; it runs while disabled too | |
| D6 | `/dr perf start`, `/dr perf measure a`, race a dummy, leave combat, `/dr perf finish`, `/reload`, `/dr perf report` | A report and a JSON line print. Keep the pair for `/dev-copilot:wow-perf-analysis` if the capture is worth keeping | |

## 9. Client assumptions and open items

The build rests on client behavior nobody has measured yet. Each row names the behavior, how to see
it, and what the code does if the assumption is wrong. O1 to O7 are the spec's open items (§12). Rows
marked *(probe)* need a one-line script typed in chat; run it in combat where the row says so.

### Meter and race timing

| ID | Assumption | How to check | Pass when | If it fails, report |
|---|---|---|---|---|
| C1 | **O1.** The in-combat order of `combatSpells` | Compare the live rows' order during R7 with the result card | Note whether the live order is sorted by damage or by first use. Either passes: the header already reads *Live order* | Which order it is |
| C2 | **O2.** `C_Spell.GetSpellTexture` and `GetSpellName` accept a secret spell ID | R7's live rows | Every live row has an icon and a name. If icons are missing, the fallback is rows without icons (*Show spell icons* off) | A screenshot, and the debug trace |
| C3 | One rung of the live-DPS chain answers in combat. The live client's source table has no `amountPerSecond` (seen 2026-10-23, a Beast Mastery hunter), so expect rung `localRow`: the player's own `combatSources` row, found by its readable `isLocalPlayer` | R7 with `/dr debug on`: the console has one `Meter` line per race, *live DPS from rung …* | *DPS · Live* shows a number all race. `localRow` is expected; `dpsType` (the Dps meter type's `amountPerSecond`) also passes if the figure is near damage ÷ elapsed, not the damage total; `source` means the field came back; `none` with a dash fails | The rung named in the `Meter` line, and whether the figure was ever a number |
| C3a | The live figure is the meter's rate, not the score | R7 then R12 | *DPS · Live* moves once a second or so (the meter's whole-second duration) and may differ from the result card's DPS; the score is still damage ÷ the race length | Both figures |
| C4 | On the opening frame, the player is already in combat, or `PLAYER_REGEN_DISABLED` shares the `GetTime()` of the new-session event | R6 | The clock starts on the first hit every time, with either opener | The opener that did not start the clock, and the `Race` debug lines |
| C5 | Damage-meter session IDs only increase within a client session | `/dr diagnostics` on each of three consecutive result cards | The race line's `session=` grows each time | The three numbers |
| C6 | `GetTime()` survives a `/reload` | X1 | The countdown continues from where it was | The countdown before and after |
| C7 | **O4.** A session read after a `/reload` in combat | X2 | The run reads after the reload. The fallback is *Lost*, and the HUD says so | X2's outcome |
| C8 | **O5.** Sessions survive a logout | X6 | Record which way it went; the spec assumes not | X6's outcome |
| C9 | **O3.** The restart flag | X5 | *Restarted* is raised. If never, the flag stays quietly unused: nothing else depends on it | X5's outcome |

### Casts and late-cast judging

Use a 0:30 race and grace 1.0 s. A late cast shows as a chip on the card and as a red tick on the
detail's timing strip.

| ID | Assumption | How to check | Pass when | If it fails, report |
|---|---|---|---|---|
| C10 | The player's own `UNIT_SPELLCAST_*` spell IDs (and castGUIDs) are plain in combat | Cast one spell 2 s after the buzzer | The chip's tooltip and the detail's flags box name the spell (*+2.0s Incinerate*). Without names, judging still works by time | Whether the name showed |
| C11 | A cast started before the buzzer and finished after it is not late | Start a 2.5 s cast at 0:01 left | No late-cast flag | The flags on the card |
| C12 | **O6.** `UNIT_SPELLCAST_START` gives a usable start for every cast type, empowered included | On an Evoker, start an empowered spell before the buzzer and release it after; then start one 2 s after | First: no flag. Second: one flag. The fallback is judging empowered spells at `SUCCEEDED` | Both outcomes |
| C13 | A channel fires `UNIT_SPELLCAST_SUCCEEDED` at its start | Start a channel 2 s after the buzzer | Exactly one late cast, not two | The count |
| C14 | `UNIT_SPELLCAST_INTERRUPTED` fires only for the cast in flight | Start a cast before the buzzer, interrupt it by moving, then press an instant 2 s after the buzzer | The instant is flagged late | The flags |
| C15 | `C_Spell.IsAutoRepeatSpell(75)` reports Auto Shot repeating | On a Hunter, leave Auto Shot running past the buzzer | No late-cast flag from Auto Shot | The flags |

### Target, formatting and sound

| ID | Assumption | How to check | Pass when | If it fails, report |
|---|---|---|---|---|
| C16 | Whether the target's name, level, classification and GUID are secret at combat start *(probe)* | In combat on a dummy: `/run local t="target" print(issecretvalue(UnitName(t)), issecretvalue(UnitLevel(t)), issecretvalue(UnitClassification(t)), issecretvalue(UnitGUID(t)))` | Either answer passes (sealed fields keep the arm-time value). The detail header shows the dummy's name | The four booleans |
| C17 | **O7.** The Silvermoon cleave group's size | Count the Cleave Training Dummies in one group | Record the number; `defaults/Dummies.lua` ships 1 until then | The count |
| C18 | The client's abbreviated formatter accepts the K/M/B ladder and renders 2763000 as *2.76M* | Damage figures on the HUD and card | Numbers read like *2.76M*, *413.2K*. If not, the debug console has a `Format` line and the Lua fallback is in use | The `Format` debug line |
| C19 | Which compat rungs this client has *(probe)* | `/run print(type(SendChatMessage), type(C_StringUtil and C_StringUtil.CreateAbbreviatedNumberFormatter), type(C_StringUtil and C_StringUtil.CreateNumericRuleFormatter))` | Record the three answers. A rung reported `nil` here on the release client is a dead-rung candidate (docs/compat-layer.md) | The three answers |
| C20 | `SOUNDKIT.UI_BATTLEGROUND_COUNTDOWN_TIMER` exists | R8 | The cue is the battleground countdown tick | Whether any sound played |
| C20a | `Interface\Timer\BigTimerNumbers` (and its `Glow` sheet) loads and BigGold's layout holds on this client: 256×170 cells, four to a row, on 1024×512 | R8a, with `/dr debug on` | The console's `Countdown` line says *frame built (texture)*, and every digit 0-9 is cut cleanly, with no neighbor's edge showing. *frame built (font)* means the sheet did not load: the fallback outlined numbers show instead | The `Countdown` line, and a screenshot of a badly cut digit |
| C20b | The Scale animation (`SetScaleFrom`/`SetScaleTo`) and a texture's own Alpha animation run on this client | R8a | Each number grows in; the glow flashes and fades. A `Countdown` line *no animation: …* means the client refused one; the numbers still show, without the pop | The `Countdown` debug line |
| C21 | `RaidNotice_AddMessage` shows *STOP* | R9 | *STOP* appears in the raid-warning area with the warning sound | A screenshot |
| C22 | A frame's `OnHide` on Alt-Z or a cinematic is not the player closing it | H4 and W12; also watch a short cinematic with a result card up | The card survives | Which case dismissed it |

### Share

| ID | Assumption | How to check | Pass when | If it fails, report |
|---|---|---|---|---|
| C23 | The `MenuUtil` channel menu builds and grays channels | P1 | The menu opens with the right entries grayed | A screenshot |
| C24 | `C_ChatInfo.SendChatMessage` to *Say* from a menu click works outside an instance | P2 | The line posts | Any error, and the debug `Share` line |
| C25 | The whisper popup's edit box is reachable (`GetEditBox`, else `editBox`) | P3 | The box is prefilled and the whisper sends | Whether the box was empty |
| C26 | `InChatMessagingLockdown` is honored | P4 | Share is refused in lockdown | What happened instead |

## 10. The 2026-10-24 pass: the stuck arm, status, time, scrolling and HUD Appearance

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| SM-DR-AR1 | On the cleave dummies, race 0:30 with DoTs (a Blood DK's Blood Plague, a Warlock's Wither), let the result show, then *Race Again* and *Arm Race* at once while the DoTs still tick, and pull | The second race starts on the first hit, every time. Repeat five times | The `Race` debug lines from the arm to the pull (*held back*, *adopted as shared*, *replaces the shared session*) |
| SM-DR-AR2 | After SM-DR-AR1, open the second run's detail | Either clean (a new session), or flagged *Shared session: the damage it held at the arm was taken off*, with a damage total in line with the race (not the two races added together) | The detail's flag text and the two runs' damage |
| SM-DR-ST1 | Open the HUD result card of a complete run and of an incomplete one | A *Time 0:30 +X.Xs* chip on the complete card (the DoT tail), *Time 0:12 / 0:30* on the incomplete one | A screenshot of each |
| SM-DR-ST2 | Open the detail of each | The header's third item reads the same time as the table's *Time* cell | A screenshot |
| SM-DR-AP1 | Open HUD > HUD Appearance | Five subsections in order: *Elapsed clock*, *Time left clock*, *Live figures* (each the six-row font block: *Font* \| *Font size*, *Font color* \| *Use class color*, *Font flags* \| *Font shadow*), *Spell bars* (*Bar texture* \| *Bar opacity*, *Bar color* \| *Use class color*, then *Row height*) and *Spell text* | A screenshot of the tab |
| SM-DR-AP2 | With a race running (or test mode), change each clock's face, size, color, flags and shadow; switch *Race clock* to *Time left*, then *Time elapsed* | Each change shows at once; the KPIs and the rows move down for a larger clock and never overlap it; a lone clock draws half again as large in its own block's color | A screenshot |
| SM-DR-AP3 | Change *Live figures* | The *Damage* and *DPS · Live* figures restyle; at size 32 their boxes grow and the rows move down | A screenshot |
| SM-DR-AP4 | Change *Spell bars* (texture, opacity, color, *Use class color*, *Row height*) and *Spell text* | The HUD's live rows, the result card's rows and the Results detail's breakdown all follow; *Use class color* paints the bars in your class color with the opacity kept | Screenshots of the HUD and the detail |
| SM-DR-AP5 | Press the HUD page's *Defaults*, then `/reload` | Every HUD Appearance row returns to the shipped look (monospace green and red clocks, flat indigo bars) and survives the reload | The row that did not reset |
| SM-DR-RT1 | Open History > Results table; change each bar's texture, opacity and color, and the bar text; tick *Use class color* on one bar | A *Damage bar*, *DPS bar* and *Bar text* subsection, and no *Background*; every change shows in the open Runs list at once; the class colors are each run's character's (an alt's runs in the alt's color); History's *Defaults* puts it all back | A screenshot of the list |

## 11. The 2026-10-25 pass: compare in the Results detail (#7)

Needs at least three complete runs of one spec, target type and length (one of them the best), and one
complete run on another board (another length or target type).

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| SM-DR-CP1 | Open a run that is not the best on its board; tick *Compare vs best* under the score; untick it | Ticked: a score table (*This run*, *Best*, *Difference* over *Damage* and *DPS*, the difference green when ahead and red when behind) and, in the plain breakdown's place, every spell of both runs: its name, *This run* and *Best* (the damage, then its share in gray; a dash for a spell one side never cast) and the *Difference* in green or red, sorted by this run's damage. Unticked: the plain breakdown is back. The layout stays inside the pane, nothing overlaps, and the wheel scrolls it | A screenshot of each state |
| SM-DR-CP2 | Open the best itself, then a run alone on its board, then a lost run | The best's toggle reads *Compare vs runner-up* and compares with the next run on its board; the lone run's toggle is grayed and its tooltip says there is nothing to compare with; a lost run's toggle is grayed and its tooltip says the run has no score (it was lost) | A screenshot |
| SM-DR-CP3 | With a run open, right-click another row and pick *Compare With This Run*; then pick a run on another board; then open the picked run itself; then press *Clear Pick* | The toggle turns on and reads *Compare vs* the picked run's date, the second column is headed *Picked*; for the run on another board an amber line says the boards differ; *Clear Pick* goes back to *Compare vs best* and hides itself. The menu entry is grayed on the run already open and on a lost run. Opening the picked run itself compares it with its board, and *Clear Pick* still shows and clears the pick. After a `/reload` there is no pick and the toggle is off | A screenshot of the pick, and the chat or Lua error if any |
| SM-DR-CP4 | Hover the toggle, *Clear Pick*, the amber note, the score table and a compared spell row, in the expanded view and then the collapsed one | Each shows its tooltip under itself, titled in gold; a compared row shows the client's spell tooltip beside the window, then each side's exact damage and share and the difference; in the collapsed view the compare draws in the list's place, as wide as the window | A screenshot of each view |

## 12. The 2026-10-25 pass: the damage chart and the pace bar (#2, #3)

Needs a spec with no complete run yet on one board (say 0:30 on a single-target dummy) and, for the
best-scaled rows, a complete run on that board. Keep `/console scriptErrors 1` on: every value the
chart draws is secret in combat, so a forbidden operation shows as a Lua error at once.

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| SM-DR-CH1 | With no best on the board, arm 0:30 and race it; take a screenshot at about 0:15 left | Board B: under the KPIs, *Damage profile* in the large gold heading with *first race on this board* at its right, a dark plot with one column a second rising from the left, the columns touching with no stripe or seam between them (one smooth area), the newest column always full (the scale is your damage so far), and *0:00 / 0:15 / 0:30* under it. No gold line, no diagonal, no pace bar. *Spell breakdown* heads the spell rows under the chart, and they stop above the caption | A screenshot, and the Lua error if any |
| SM-DR-CH2 | Race the same board again (it now has a best); screenshot at about 0:15 left | Board A: the header's right reads *vs best pace*; no gold line and no *Best* label; a white dashed diagonal from the bottom-left corner up to the best's level at the right edge (near, not at, the top); the columns climb against it and stop short of the top (the scale is the best x 1.15); a column past the best clamps at the top | A screenshot |
| SM-DR-CH3 | In the same race, watch the pace bar under the *Damage profile* heading | *vs best pace* at its left, a bar with a white tick in the middle (at any *Pace bar range*); the fill sits near the tick while you keep the best's average pace, and moves smoothly as the clock runs. It never says ahead or behind and never changes color | A short clip or two screenshots |
| SM-DR-CH4 | Pull a dummy, stop, and arm again while its DoTs still tick (so the race carries the last fight's session), then race it | The run is flagged *Shared session*; while it runs there is no chart and no pace bar, and its result card has no chart either | A screenshot of the running HUD |
| SM-DR-CH5 | Let a race finish on a board with no earlier best | The result card shows the same chart between its chips and the spell rows, every column to scale against the run's final damage (the last column full or nearly so), with no diagonal; turning *Show damage chart* off removes it (with a best, see SM-DR-RC10) | A screenshot |
| SM-DR-CH6 | Open that run in the Results window (*Details*), then `/reload` and open it again | Before the reload the detail shows *Damage profile* under the breakdown, with the same columns, and its tooltip says only this session's runs have it; after the reload the section is gone and the timing strip moves up | A screenshot of each |
| SM-DR-CH7 | On HUD > Race HUD turn *Show damage chart* and *Show pace bar* off and on during a race; on HUD Appearance change *Damage chart*'s color, texture, *Chart height* and *Column gap*, *Chart background*'s color and opacity, and *Pace bar*'s color | Each takes effect on the next redraw; the chart's columns take the *Damage chart* color and texture and the pace bar keeps its own until *Pace bar* changes it; a *Column gap* of 1 to 3 opens even gaps between the columns and 0 closes them; the plot's background follows *Chart background*; a taller chart leaves fewer spell rows, and at the HUD's minimum height the chart steps aside so three rows still show | A screenshot |
| SM-DR-CH8 | `/dr test`; then `/dr sim` and watch it through to the result card | The still running body shows a chart against the sample history's best (the dashed diagonal, no gold line) and a pace bar; the sim does the same live, and its result card shows its chart | A screenshot |
| SM-DR-CH9 | With `/dr sim` playing, turn *Show damage chart* off, then *Show pace bar* off, during the running sample; let it reach the result card | The sample's chart goes when its setting goes off and its pace bar when its own does, and the sample result card has no chart; turned back on, each returns on the next redraw | A screenshot with both off |
| SM-DR-CH10 | In the Results window open a run raced this session (the chart shows), then a run from before the last `/reload` or a lost run; hover the *Timing* header where the chart's title was | Over the second run there is no *Damage profile* tooltip anywhere: the timing header shows its own | A screenshot of the tooltip |

## 13. The 2026-10-25 pass: equipment and talents (#6)

Needs a character with a saved talent loadout, a few runs from before this build (they have no
loadout), and two runs on one board raced in different gear or talents. Keep `/console scriptErrors 1`
on, and `/console taintLog 1` for SM-DR-LO4.

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| SM-DR-LO1 | Race once, then open the run in the Results window and scroll under the timing strip; hover a few items, an empty slot and the *Gear* title | *Gear* in gold with *Dressing Room* at its right; two columns in the character frame's order (head, neck, shoulders, back, chest, wrists, main hand, off hand; then hands, waist, legs, feet, both rings, both trinkets), no shirt and no tabard; each item's icon in its quality's color, its item level over the icon and its name beside it; an empty slot says *Empty*. An item's hover is the game's own item tooltip with its enchant, gems and item level; the empty slot and the title show their own tooltips | A screenshot of the grid and of one item tooltip |
| SM-DR-LO2 | Open a chat edit box and Shift-click an item in the grid; then Ctrl-click one | Shift-click puts the item's link in the edit box, and it posts as a clickable link; Ctrl-click opens it in the Dressing Room | A screenshot, and the Lua error if any |
| SM-DR-LO3 | Press *Dressing Room* | The Dressing Room opens with every item of the run tried on (weapons included) | A screenshot |
| SM-DR-LO4 | On the *Talents* line, check the name, hover *View*, then press it; click the link it posts in chat; close the tree, pull a dummy and fight it with abilities that change action-bar slots in combat (a proc that lights or swaps a button, an override such as a transform), then open your own talents (N) and change nothing | The line names your saved loadout and its hero tree (not a generic name); *View*'s tooltip says it posts a clickable link to chat; pressing it opens nothing itself and prints one tagged line, *Talents for <name>, <date>: [<loadout>] — click the link to view the tree*; clicking the link opens Blizzard's talent tree, read-only, on the run's build. Afterwards there is no *Interface action failed because of an AddOn* message and no ADDON_ACTION_BLOCKED error naming DpsRace in or after combat, and the talent frame works as usual | The taint log (`Logs/taint.log`) and the error, if any |
| SM-DR-LO5 | Press *Copy*, press Ctrl+C, then paste into the talent frame's *Import* box (or Wowhead's talent calculator) | A copy window opens over the Results window with the import string selected; the pasted string imports the same build. Escape closes the window | A screenshot |
| SM-DR-LO6 | Open a run raced before this build | *Gear* says *Not recorded* with no grid and no *Dressing Room*; the *Talents* line says *Not recorded* with *View* and *Copy* grayed; hovering *Not recorded* says why | A screenshot |
| SM-DR-LO7 | Open a run whose board's best was raced in other gear or talents and tick *Compare vs best*; untick it | Ticked: every slot whose item differs is tinted amber, and its item tooltip ends with what the best wore there; an amber *Different loadout* line shows under the talents when the builds differ. Unticked: no tint and no line | A screenshot of each state |
| SM-DR-LO8 | In the Runs tab hover the class icon of a run raced after a gear change, then of the next run in the same gear, then of a run from before this build | The first names the talent loadout and says *Gear changed since the previous run* in amber; the second names the loadout without the note; the old one says *Gear and talents: not recorded* | A screenshot of each |
| SM-DR-LO9 | On History, tick *Include talents link* under *Sharing*; share a run to Say and to a party member's whisper; untick it and share again | Ticked: the line ends with a gold *[Destruction: <loadout>]* link (or the link follows as a second message when the line is long), and clicking it, yours or a party member's, opens the read-only talent tree. Unticked: exactly the one line as before | The chat lines, and any refusal or error |
| SM-DR-LO10 | Arm a race, change a piece of gear before the first hit, then race it and open the run | The grid shows the gear you raced in (the one you changed to), not the gear at arm | A screenshot |
| SM-DR-LO11 | Arm a race, hit a dummy, then `/reload` mid-race and step away so combat ends during the loading screen; open the run once it is read | The run is read straight after the reload, and its *Gear* grid and *Talents* line show what you raced in, not *Not recorded* | A screenshot |

## 14. The 2026-10-25 feedback round: chart look, detail headings, the Note column

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| SM-DR-FB1 | Race once with a best on the board and look closely at the running chart, then the result card's and the Results detail's | The columns touch: no stripe, gap or one-pixel seam between any two, at any HUD width (resize the HUD to check); each column's top is crisp; the dashed diagonal still shows. No gold line and no *Best* text anywhere | A zoomed screenshot |
| SM-DR-FB2 | Open a run in the Results detail and scroll through it | *Spell breakdown*, *Damage profile* (this session's runs), *Timing*, *Gear*, *Talents*, the flags box's title and *Note* are all one gold heading size, larger than the column headers, with nothing overlapping under any of them; *Spell breakdown* sits above *Compare vs best* | A screenshot of each part |
| SM-DR-FB3 | Add a note to a run, then edit it; open a run with no note | The note shows as written (no *Note:* prefix) under a *Note* heading; while editing, the heading sits over the edit box; a run with no note has no heading | A screenshot |
| SM-DR-FB4 | In the Runs list, give runs notes of 4, 10 and 30 characters (one starting with a capital) and leave one without; hover each Note cell, then the *Note* header; click the header twice | The column sits after *Status*: the short notes whole, the 30-character one cut to 10 characters and an ellipsis, the empty one blank. Each cell's tooltip is *Note* then the whole note, wrapped; the header's tooltip says what the column is. Sorting is A to Z ignoring case, then Z to A, the run without a note last both times. At the window's narrowest the *Character* column is still readable | A screenshot of each sort |
| SM-DR-FB5 | Hover the detail's class icon and spec icon | The header shows no spec text beside the name; the spec icon's tooltip names the spec and the class (*Beast Mastery Hunter*) | A screenshot |

## 15. The 2026-10-25 backlog: Results badges and length colors

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| SM-DR-BL1 | Open Results with runs of every status in view (a best, a Max with two specs in view, a clean and a flagged complete run, an incomplete run, a death, a lost run) | Each *Status* cell is a 1px box tinted its hue with the icon inside, before the word: *Max*, *Spec best*, *Complete*, *Flagged*, *Incomplete*, *Died*, *Lost*, nothing else in the box. Only *Spec best* and *Max* have text after the box, *boss-level · 2:00* (the target type in lower case, then the length in its length color); nothing is cut off or overlaps the *Note* column | A screenshot |
| SM-DR-BL2 | Race at 0:30, 1:00, 2:00, 3:00, 5:00 and a custom length (0:45), then read the *Time* column, the time after a *Spec best* badge, and the Bests tab's *Length* column | 0:30 soft red, 1:00 soft orange, 2:00 soft yellow, 3:00 soft green, 5:00 soft indigo, each muted and readable on the table; 0:45 a neutral gray; the tail (*+9.1s*) stays the caption gray; the HUD's own length texts keep their usual color | A screenshot of each |
| SM-DR-BL3 | Hover a *Spec best* cell, a *Max* cell and a *Flagged* cell; hover the *Status* header; click the *Status* header twice | The title names the whole board (*Spec best: boss-level · 2:00*), then what the tag means and every flag; the header tooltip says both name their target type and length; the sort runs Max, Spec best, Complete, Flagged, Incomplete, Died, Lost and back | A screenshot of each tooltip |
| SM-DR-BL4 | Collapse the window and drag it as narrow as it goes, then expand it and do the same; open the Bests tab | At 932 (collapsed) and 1292 (expanded) every column header and cell still fits, the *Character* column readable; the Bests *Flags* chips are plain amber text with no box, a two-flag best's *1 late · Reloaded* inside its column | A screenshot at each minimum |
| SM-DR-BL5 | With runs at several lengths on two target types in view (a custom length among them), pick *Group: Duration*, then *Group: Target + duration*; fold a group in each and switch between the two; click the *Time* header in *Duration* and the *Target* header in *Target + duration*; *Save* the view and `/reload` | The dropdown shows both labels whole. *Duration* puts one gold header per length, shortest first (*Duration: 1:00 (3)*, the time in its length color, a custom length gray), the sort holding inside each; *Target + duration* puts one per pair in the catalog's target order, shortest first inside each type (*Target: Cleave · 1:00 (2)*, then *Target: Cleave · 3:00*, then *Target: Boss-level · 2:00*); a fold in one mode never folds a group in the other and is still there on switching back; the grouped column's header flips the groups' order; after the `/reload` the window opens on the saved mode | A screenshot of each mode |
| SM-DR-BL6 | With a best on the board, race it at the default *Pace bar range* (1.5), then set it to 1.1 and to 2.0 on HUD > Race HUD > *Chart and pace* during a race; hover the slider | The tick stays in the middle at every range; the fill keeps meeting the tick while you hold the best's average pace; at 1.5 the bar is empty at half the best's pace and full at half again, at 1.1 it swings across the whole bar within ±10%, at 2.0 it runs from 0 to twice the pace, each on the next redraw; the slider runs 1.1 to 2.0 in steps of 0.05, and its tooltip says how far either side of the best's pace the bar reaches, 1.5 = ±50% | A screenshot at each range |
| SM-DR-BL7 | Race a board with a best and lose to it; then race it again and beat it; then race a new board for the first time | The first two result cards show *vs best pace* and its bar under the *Damage profile* heading, above the plot, the tick where the running bar's was: losing, the fill stops short of the tick; beating it, the fill passes the tick (set against the previous best, not the new one). The first race on a board has no pace bar, and its plot sits right under the heading | A screenshot of each card |
| SM-DR-BL8 | Turn *Show pace bar* off, then on, with a result card up; race a shared-session run (SM-DR-CH4) to its result; `/dr test result`, then `/dr sim` to its result card; shrink the HUD to its minimum height on a result card with a best | Off hides the card's bar and on brings it back; the shared-session card and a lost run's card have none; the sample result card shows it; at the minimum height the bar stays, three spell rows still show, and the chart steps aside | A screenshot of the minimum-height card |
| SM-DR-BL9 | With no other Blizzard window open, open Results on a run with talents, press *Talents > View* and click the link it posts in chat; then press Escape once; open Results again, open the tree with N, and close Results with its own close control; then pull a dummy and fight it with abilities that change action-bar slots in combat (a proc that lights or swaps a button, an override) | Clicking the link opens Blizzard's talent tree on the run's build and the Results window is still on screen afterwards (it may flicker for one frame); where the two overlap the Results window draws over the tree (known limitation, B4.1: move it aside). One Escape closes both the tree and Results. With the tree open from N, Results' close control closes Results alone and it does not come back. No *Interface action failed because of an AddOn* message and no ADDON_ACTION_BLOCKED naming DpsRace in or after combat | Whether Results closed and stayed closed, the `Results` debug line *closed by the talent tree's panel open; reopened* (or its absence), and the taint log (`Logs/taint.log`) |
| SM-DR-BL10 | `/dr test` with the HUD and the Results window closed; wait a minute | The HUD opens on the running body held still at 0:18 (clock, *Damage* and *DPS* figures, the live spell rows, the chart against the best's pace and the pace bar), the test strip under its title; nothing moves. The Results window opens too, with a strip under its tabs (*Test mode: sample runs. Nothing here is saved*) and 16 sample runs on every character and spec: yours, *Sampleblade* (Retribution) and *Mockflame* (Fire); every *Status* (Max, Spec best, Complete, Flagged, Incomplete, Died, Lost); all five target types and all five preset lengths in their length colors; notes on three | A screenshot of both windows |
| SM-DR-BL11 | With test mode on, `/dr test armed`, `/dr test result`, `/dr test running`, then `/dr test stop`; then end it and `/dr test result` | Each word switches the HUD's still body in place (the result card with *New best +x%*, the pace bar and the chart; Race Again and Details grayed); `stop` prints *Usage: /dr test [armed\|running\|result]* and changes nothing; from off, `/dr test result` starts on the result card and ticks the Master controls' *Test mode* | A screenshot of the result card |
| SM-DR-BL12 | With test mode on, open your 0:30 single-target best (the one with *Sample note: opener with every cooldown*): turn its compare on, hover the Spec cell of the run five hours old, open the gear grid and press *Talents > View*, then *Dressing Room*; try *Share*, *Save* and *Reset* on the Runs view; edit a note and delete a run; open the Bests tab | The detail draws *Damage profile*, the compare against the runner-up, your own gear and talents (the link opens your build); the five-hour-old run says *Gear changed since the previous run* and its compare marks the changed slot. *Share* is grayed and the row menu's *Share* disabled; *Save* and *Reset* print *Not saved: the Results window is showing sample runs.*; the note and the delete show at once; the Bests tab lists the sample boards | A screenshot of the detail |
| SM-DR-BL13 | Start `/dr test` and end it each way in turn: enter combat, arm a real race, untick *Test mode* (Master controls) and the launcher's *Test mode*, close the HUD, *Reset all settings*, `/dr disable`. Once more with the Results window already open and filtered to one length | Each ends it (combat and arming with one line each); the Results window test mode opened closes, and one you had open stays open on your own history with your filters and sort as they were, the strip gone, no sample run selected | Which end left samples in the window |
| SM-DR-BL14 | `/dr sim` (the default, *newbest*), then `/dr sim behind`, `first`, `incomplete`, `died`, `flagged` and `shared`, each to its Results window | *newbest*: chart and pace bar against the best, *New best +4%*, Results on the sim's run (now the board's Spec best; its compare is the old best). *behind*: a red *-7% vs best*. *first*: a Boss-level 0:30 board with no best: *first race on this board*, the chart on its own scale, no pace bar. *incomplete* (18 s) and *died* (12 s): no Stop!, *Reading the result*, the card shows the run incomplete; Results tags it *Incomplete* / *Died*. *flagged*: *1 late cast* on Stop! and a late-cast chip on the card. *shared*: no chart and no pace bar, live, on the card or in the detail | A screenshot of each result card |
| SM-DR-BL15 | Type `/dr sim sideways`; start `/dr sim` in combat and with a race armed; start `/dr sim`, then `/dr test`, then `/dr sim died`; during a sim enter combat, then arm a real race | The usage line lists every scenario, then one line each with what it shows; both starts are refused with one line; `/dr test` switches the sim to the still views and `/dr sim died` starts a new sim from Armed; combat and arming end it like test mode, the Results window it opened closes | The lines printed |
| SM-DR-BL16 | `/dr help` and read the `sim` line; `/dr test`, close the Results window it opened, reopen it with `/dr results`, then `/dr test` to end it; start `/dr sim` and, while it is still racing, end it each way in turn: close the HUD, *Reset all settings*, `/dr disable` | The `sim` help line lists the same scenarios as `/dr sim sideways`; the Results window you reopened stays open on your own history; each end stops the sample race at once (no further HUD updates, no center countdown), the Results window is back on your own history, and no sim run appears in it after a `/reload` | Which end left the sample playing |

## 16. Round C: the detail's headings, the HUD's profile and the centered pace bar

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| SM-DR-RC1 | Open a run raced this session with a flag and a note in the Results detail and scroll through it; then a run from before the last `/reload` | *Spell breakdown*, the chart's heading, *Timing*, *Gear*, *Talents*, the flags box's title and *Note* are one gold heading a step larger than before (GameFontNormalLarge), each with a clear band of space above it and nothing overlapping under it; the header at the top has no extra space above it; without the chart *Timing* moves up and keeps its space | A screenshot of each part |
| SM-DR-RC2 | Reset the HUD's position and size, then race a board with a best at the default 8 *Spell rows shown* and look at the running body; let it finish to the result card; turn *Show chart* off, then *Show pace bar* off, on the card; `/dr test running` and `/dr test result`; drag the HUD to its minimum height | The HUD opens 300x560. Under the KPIs: *Damage profile* in the large gold heading (the Results detail's size) with *vs best pace* at its right, the pace bar directly under it, then the plot and its time labels; then *Spell breakdown*, the same heading, with all 8 rows under it above the caption. Each heading has a clear band of space above it. The result card stacks the same. With the chart off the heading stays over the pace bar (no note); with both off it is gone and *Spell breakdown* moves up under the chips. Test mode's views match. At the minimum (260x354) the plot steps aside and three rows still show | A screenshot of each body |
| SM-DR-RC3 | Race a board with a best at the default *Pace bar range* (1.5): open well ahead of the best's pace, then fall well behind it; finish to the result card both beating and losing to the best by more than 50%; with a *Pace bar range* saved at 3.0 by an earlier build, `/reload` | The tick sits in the middle of the bar the whole race. Far ahead the bar sits full, far behind it sits empty (no error, no flicker), and between the two it moves smoothly through the tick. The result cards' bars do the same with the run's final damage. A range saved at 3.0 draws as 2.0 (0 to twice the pace), with no Lua error on the HUD page | A screenshot ahead, behind and of each card |
| SM-DR-RC4 | Race 0:30 on a dummy with a DoT class; at the buzzer stop attacking, drop combat (walk out of range) and press *Stop Now* on the Stop! screen as soon as combat drops | Two buttons across the HUD's foot, *Stop Now* and *Cancel*, the same width as each other, each with a tooltip. The result card shows at once (no 2.5 s wait); the run is in Results with its score; the chat prints the score line once | A screenshot of the Stop! screen and the card |
| SM-DR-RC5 | Race on the Dungeoneer's dummy; after the buzzer stay in combat and press *Stop Now* on the Stop! screen, then wait on the waiting screen; then walk out of range | No Lua error and no blocked-action message, in combat. *Stop Now* grays and the waiting screen's title reads *Reading when combat ends*; the result card shows the moment combat drops, without the usual 2.5 s | The title, and how long after combat dropped the card came |
| SM-DR-RC6 | Race twice; press *Cancel* on the Stop! screen in combat on the first, on the waiting screen out of combat on the second | The HUD returns to idle each time, nothing reaches Results (the count does not move), and no error or blocked-action message shows | The count before and after |
| SM-DR-RC7 | `/dr sim`; press *Stop Now* on its Stop! screen; again on its waiting screen; then start it again and press *Cancel* on its Stop! screen | *Stop Now* jumps the sample race to its result card, which holds and opens the Results window on the sim's run as usual; *Cancel* ends the sim (the strip goes, the HUD closes if the sim opened it); nothing is stored | A screenshot of each |
| SM-DR-RC8 | On a real result card press *Delete*, choose *Cancel* in the popup; press it again and confirm; on another card open *Details* and delete that run from the Results window instead; `/dr sim` to its result card | The popup is the Results window's own (*Delete this run? ...*); *Cancel* keeps the card and the run; confirming removes the run from Results and the HUD goes to the *Arm Race* screen, open, with the same length picked. A delete from the Results window dismisses the card. On the sim's card *Delete* is grayed | The Results count before and after |
| SM-DR-RC9 | Look at the result card at the default size, then drag the HUD to its minimum width (260) | *Race Again*, *Details*, *Share* and *Delete* sit in one row, all four the same width with the same small gap, filling the card; at the minimum width every label still fits inside its button (no clipping, no overlap) | A screenshot at each width |
| SM-DR-RC10 | Race a board with a best and lose to it, finish to the result card, open *Details*; race it again and beat the best; race a new board for the first time; `/dr sim` (*newbest*) and `/dr sim first` to their result cards | With an earlier best the card's and the detail's chart draw the gray dashed diagonal (the live chart's look) from 0:00 to the best's damage at the buzzer, the plot's top 15% above the larger of the run's damage and the best's, the columns on that scale (losing: the diagonal ends above the last column; beating: below it). No earlier best (the first race, *sim first*) or a shared session: no diagonal, the last column full | A screenshot of each card and detail |
