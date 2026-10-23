# Smoke tests

The in-game checks no headless run can reach: real rendering, the real damage meter, taint, and
client behavior the spec could not measure ahead of time. The owner runs them once, end to end,
before a release. One pass takes about an hour on a character in Silvermoon, which has every dummy in
the catalog (spec §4.6).

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
| S3 | Open General | Two tabs: *Master controls* (rows in the standard's order) and *Race HUD* (show mode) | A screenshot |
| S4 | Look at the page order | Race, Live breakdown and History sit between General and Profiles, each a tab strip with subsection headings | A screenshot |
| S5 | On Race, drag the grace slider; hover it | It steps by 0.1 from 0 to 5; the tooltip says it applies to new runs; the length dropdown offers 0:30 to 5:00 | The values it stops at |
| S6 | On Live breakdown, set *Rows shown* to 3, then 15, with the HUD running a race | The live list shows 3 rows, then as many as fit (never under CANCEL) | A screenshot |
| S7 | On History, type 10000 into *Runs to keep*'s box | Accepted at once, without a stall; nothing is deleted on the spot | How long it froze, if it did |
| S8 | Press each page's *Defaults* button after changing one row on every page | Only that page's rows go back | Which page's rows moved |
| S9 | History: *Delete all runs…* with a race armed, then with none | Armed: one refusal line, nothing deleted. Idle: it asks first, and on accept the stored count reads 0 and the Results window empties | The chat lines |
| S10 | Open the panel in combat | Refused with a notice; it opens once combat ends | Whether any taint error followed |
| S11 | *Reset all settings* | It asks first; afterwards the minimap button keeps its state and *Test mode* is unticked | The settings that did not reset |
| S12 | Profiles: create, switch, copy and delete a profile | Each works; run history is unchanged by all of them (it is account-wide) | The Results count before and after |

## 3. Launcher, key bindings and slash

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| K1 | Look at the minimap button; hover it | The logo shows; the tooltip has the version and status, also while disabled | A screenshot |
| K2 | Left-click, then right-click the button | Left opens settings; right shows exactly *Enabled*, *Locked*, *Test mode* and *Show window* (spec §6.4: no Results or Arm entry) | The menu as drawn |
| K3 | Turn *Minimap button* off, then on | It hides, then comes back in the same place | Where it came back |
| K4 | *Key Bindings → AddOns → Ka0s DPS Race* | *Toggle race HUD*, *Toggle results window* and *Arm / cancel race* are listed, none bound | The list as shown |
| K5 | Bind all three; press each | The HUD toggles; the Results window toggles; the arm key arms the HUD's length, a second press cancels | Which key did what |
| K6 | Press the arm key while a result is pending (section 4, R8) | It discards nothing and prints one line pointing at `/dr cancel` | The line |
| K7 | `/dr arm 1:30`, `/dr cancel`, `/dr arm 0`, `/dr arm 3m`, `/dr cancel` | 1:30 arms with the *Armed* line; cancel cancels; `0` prints the length line; `3m` arms 3:00 | Each line |
| K8 | `/dr hud show`, `hide`, `toggle`, bare `/dr hud`; `/dr results`, `/dr results bests`; `/dr lock`, `/dr unlock` | Each acts and echoes once; `/dpsrace` answers the same as `/dr` | The verb that misbehaved |
| K9 | Target each catalog dummy and `/dr target` | Its name, creature ID and category print (243167/243168 Dungeoneer, 243208 Cleave, 243205 Boss-level, 243211 PvP); an uncataloged target prints *Other* | The line for each |
| K10 | Arm with `/dr arm 30` with the HUD's *Test mode* box ticked in settings | Test mode ends with one line and the settings checkbox unticks | Whether the box stayed ticked |

## 4. The race on a real dummy

Use a 0:30 race on the Reinforced Golem (243205) unless a row says otherwise. The HUD opens at
300×460 the first time (spec §6.1).

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| R1 | `/dr hud show` with no target, then target the Golem | Idle body: the five presets and *Custom*, the target card (*No target*, then the name with the *Boss-level* badge and the count stepper), *ARM RACE*, and the *LAST RESULT* and *RESULTS* links. Nothing overlaps | A screenshot |
| R2 | Target a non-dummy creature | The card warns *Unknown target: recorded as Other: name* | A screenshot |
| R3 | *Custom*: type `90`, then `1:30`, then `3m`, then `5` | The first three are accepted (1:30, 1:30, 3:00); `5` is refused with the 0:10 to 15:00 line | Each result |
| R4 | Enter combat on anything, then look at *ARM RACE* | Grayed with *Leave combat to arm*; a click prints the same line | A screenshot |
| R5 | Arm 0:30 out of combat | Armed body: 0:30 large and still, *First hit starts the clock*, the target card, *CANCEL*; the chat prints the *Armed* line | A screenshot |
| R6 | Open with a cast-time spell, then on a second run with an instant | Both times the countdown starts on the frame the first hit lands (not on the cast's start), to a tenth of a second | Debug lines tagged `Race`, and which opener failed |
| R7 | Keep attacking through the race | Running body: with *Race clock* at its default, *ELAPSED* in green on the left and *LEFT* in red on the right, each in `m:ss.t`, counting up and down together; DAMAGE and *DPS · LIVE* figures; the live rows with icon, name, bar and amount, and no percentages; the header reads *Live order · % after the race* | A screenshot at about 0:15 left |
| R7a | General → Race HUD → *Race clock*: *Time left*, then *Time elapsed*, then back to *Elapsed and time left*, during a race and in test mode; then drag the HUD to its minimum width (260) | One big red clock, then one big green clock, then the pair; the switch takes effect at once. At 260 px wide the two clocks and their captions do not touch or clip, also at 9:59.9 | A screenshot at the minimum width |
| R8 | Hear the last 10 s | With the defaults the cue sounds once a second from 10 down to 1, never twice in a second. With *Center-screen countdown* off it sounds at 10, 5, 3, 2 and 1 only. *Countdown cue* off silences it mid-race | Which seconds were silent or doubled |
| R8a | Watch the last 10 s of a 0:30 race, HUD open, then again with the HUD closed | Gold numbers 10 down to 1 pop in (grow and fade in, with a glow flash) in the middle of the screen above the character, one a second; *10* is two digits, centered; they vanish at the buzzer, and the raid-warning *STOP* still shows. Nothing is clickable through them (the mouse passes through). Nobody else in the group sees a pull timer | A screenshot of *10* and of *1*, and whether a groupmate saw anything |
| R8b | Race, Race page: *Countdown from (s)* 3, then *Center-screen countdown* off mid-countdown | The numbers start at 3. Switching it off hides the number on screen at once | |
| R8c | Cancel the race with 5 s left; drop combat with 6 s left on another run | The number on screen goes at once, and no further number or cue follows | |
| R8d | `/reload` with about 6 s left, still attacking | After the loading screen the number of the moment shows at once (silently) and the count carries on to 1 | The numbers seen after the reload |
| R8e | `/dr test`, watch the sample race's last 10 s; then end test mode during its countdown | The numbers show silently in the sample race and go with its buzzer; ending test mode clears them at once | |
| R9 | Stop on the buzzer | A raid-warning **STOP** with a sound; the HUD switches to *Stop!*: *DAMAGE STOPPED +x.xs* climbing while DoTs tick, the late-cast count, *IN COMBAT +y.ys* | A screenshot |
| R10 | Stay idle in combat on the Dungeoneer's dummy for 20 s after the buzzer | The body moves to *Waiting for combat to end* with the elapsed time and *DISCARD RUN*; after 15 s the hint appears naming only drop-combat abilities this character has (Feign Death, Vanish, Shadowmeld, Invisibility) | The hint's text and the class |
| R11 | Close the HUD while waiting, walk out of range | The result card opens by itself about 2.5 s after combat drops | How long it took |
| R12 | Read the result card | DAMAGE, DPS (damage ÷ 30.0 exactly; check with the detail), the best delta (*New best* on a first run), the flag chips, the top five spells with %, *RACE AGAIN*, *DETAILS*, *SHARE*; the chat prints the score line once | A screenshot and the score line |
| R13 | *RACE AGAIN* | Re-arms 0:30 against the same target | The armed length |
| R14 | Stop attacking at about 0:12 left and drop combat | The run becomes incomplete: the card says *Incomplete (combat ended at m:ss)* and its DPS is damage ÷ the time fought; it never appears on the Bests board | A screenshot |
| R15 | Let the Dungeoneer's dummy kill you mid-race | *Incomplete: died* on the card | A screenshot |
| R16 | Cancel while armed, and while running | Nothing is stored (the Results count does not move); the HUD returns to idle | The count before and after |
| R17 | *DISCARD RUN* while waiting | The HUD returns to idle; the run does not appear in Results | Whether it was stored |
| R18 | Close the HUD on a result card (the close button, then Escape on a fresh card) | The card is dismissed; the run stays in Results | Whether the run went |
| R19 | Reset Blizzard's damage meter from its own window while armed, then while running | Armed: the race stays armed. Running: the run becomes *Lost* and the HUD says so | The state after each |
| R20 | Turn Blizzard's damage meter off (if the client allows it) and look at the idle HUD | *ARM RACE* is grayed with the reason Blizzard gives | The reason text |
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
| W1 | Open Results after sections 4 and 5 | *RUNS* tab: every resolved run, sorted by DPS, highest first (unranked runs last); incomplete and lost rows show *incomplete* / *lost* muted in the DPS column; no running or stopping run is listed | A screenshot |
| W2 | Hover the class and spec icons | The class icon is cropped cleanly (from `CLASS_ICON_TCOORDS`), the spec icon is the spec's own (from `GetSpecializationInfoByID`); each tooltip names it | A screenshot of a bad crop |
| W3 | Open each filter dropdown and pick a value; tick *Hide flagged*, untick *Include incomplete* | The dropdowns open and filter; the checkboxes (Blizzard's stock art) toggle and filter; the count follows | The filter that did not apply |
| W4 | Sort by DPS, ilvl and date | Each sorts both ways; incomplete and lost sort last on DPS | |
| W5 | Click a run | The detail: header (character, spec, ilvl, zone and subzone, target, date, build, version), score block with meter DPS muted and the best delta, the full breakdown with %, the timing strip (buzzer, grace, tail band, late-cast ticks, combat end, restart tick), flags with explanations, note, *Share*, *Delete* | A screenshot |
| W6 | Scroll a long breakdown with the mouse wheel; drag the list's scrollbar with 20+ runs | The detail scrolls; the slider drags and the list follows | |
| W7 | Make the window narrower than 900 px and click a run | The detail replaces the list with a back control; back returns to the list with the row still selected | A screenshot |
| W8 | Type a note with a `|` in it and press Enter; reopen the run | The note is saved with `/` in place of `|`; Escape instead cancels the edit; at most 200 characters fit | The stored note |
| W9 | *Delete* a run holding a best | It asks first; on accept the run goes and the Bests board promotes the next run | The board before and after |
| W10 | *BESTS* tab | One category at a time (no *All*), starting on the first category present in catalog order. Each row: date, character, ilvl, damage, DPS and flag words (*1 LATE*, *RESTARTED*, *RELOADED*, *BY LIST*, *DIED*). *Clean runs only* drops flagged rows. Note whether starting on the first category reads well, or the newest run's category would be better | A screenshot, and the owner's view on the starting category |
| W11 | Move and resize the window, `/reload` | Position and size persist; *Master scale* scales it too | |
| W12 | Escape with the window focused; Alt-Z | Escape closes it; Alt-Z hides and shows it without counting as a close | |
| W13 | Open and use the window in combat | It opens, redraws and sorts with no taint error or blocked-action message | The error text |
| W14 | Look for the `×` (target count) and `—` (empty damage) glyphs | Both render in the client font, not as boxes | A screenshot |

## 7. Share and test mode

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| P1 | *SHARE* on the result card, then in the Results detail; double-click a row | A menu opens (Say, Party, Raid, Guild, Whisper…) with channels you are not in grayed | A screenshot |
| P2 | Pick *Say* outside an instance | The mockup's one line posts: *DPS Race 0:30 · target ×count · spec ilvl · damage · DPS (Ka0s DPS Race)*, *incomplete* added for an incomplete run, no flags | The posted line |
| P3 | Pick *Whisper* with a player targeted | A popup with an edit box opens, prefilled with the target's name; accept sends | Whether the box was there and prefilled |
| P4 | Share in combat; share during the client's chat lockdown (a boss encounter or rated PvP) | Refused with one line each; nothing posts | The lines |
| P5 | `/dr test` | Armed, Running, Stop!, Waiting and Result play on the HUD with the amber strip under the title (*Test mode: sample numbers. Combat or Arm ends it*); it holds on the result card. The sample spells show real icons and names (re-check the Preview spell IDs on this patch) | Any spell shown as *Unknown spell* or a question-mark icon |
| P6 | While test mode plays, drag and resize the HUD to its minimum (260×316) | The strip glyph and its text still fit; nothing overlaps | A screenshot |
| P7 | Enter combat during test mode | It ends with one line | |
| P8 | Start test mode, then arm a real race | Test mode ends with one line and the HUD shows the real race | |
| P9 | Leave a real result card up, start `/dr test` over it, and close the HUD | Closing ends test mode only; the real run is unaffected | The real run's state after |
| P10 | Try `/dr test` while a real race is armed | Refused with one line | |
| P11 | `/dr test` writes nothing | The Results count is the same after a full script | |

## 8. HUD sizing, disabled state, debug and performance

| ID | Do | Pass when | If it fails, report |
|---|---|---|---|
| H1 | A fresh profile's HUD during a race | 300×460, all 8 live rows visible | A screenshot |
| H2 | Drag the grip to the minimum (260×316) and look at every body (use test mode) | Arm and the links stay clear; live and result rows are capped above the buttons; nothing runs off the window | A screenshot of each body that clips |
| H3 | Move and resize the HUD, `/reload` | Position and size persist; lock stops the drag and the grip | |
| H4 | Alt-Z with the HUD shown on a result card | The card is still there when the UI comes back (a hidden parent is not a close) | |
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
| C3 | One rung of the live-DPS chain answers in combat. The live client's source table has no `amountPerSecond` (seen 2026-10-23, a Beast Mastery hunter), so expect rung `localRow`: the player's own `combatSources` row, found by its readable `isLocalPlayer` | R7 with `/dr debug on`: the console has one `Meter` line per race, *live DPS from rung …* | *DPS · LIVE* shows a number all race. `localRow` is expected; `dpsType` (the Dps meter type) also passes; `source` means the field came back; `none` with a dash fails | The rung named in the `Meter` line, and whether the figure was ever a number |
| C3a | The live figure is the meter's rate, not the score | R7 then R12 | *DPS · LIVE* moves once a second or so (the meter's whole-second duration) and may differ from the result card's DPS; the score is still damage ÷ the race length | Both figures |
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
