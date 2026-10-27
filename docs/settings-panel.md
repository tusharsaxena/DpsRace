# Settings panel

How Ka0s DPS Race is configured. The panel lives under the game's **Settings → AddOns → Ka0s DPS
Race**; `/dr` or `/dr config` opens it. It is built by `LibKa0s-Options-1.0` from the schema
(`settings/OptionsSetup.lua`), the category is registered eagerly at load and each page body is
built on first show (options-ui-§1, §5).

## Pages

| Page | Covers |
|---|---|
| *(landing)* | Logo, the TOC's notes line, and one line per slash command from `NS.COMMANDS` |
| General | Master controls: on/off, visibility, scale, lock, debug console, minimap button, test mode, the two resets; the Keybindings tab: the three key bindings |
| Race | One tab along the race's timeline: the default race length, the countdown (cue and center numbers), the buzzer with the sticky-combat hint's delay, and the scoring rules (late-cast grace, damage-restart gap) |
| HUD | The Race HUD tab: when the HUD shows and what its running clock shows (*Display*), then the live breakdown's spell rows shown, spell icons, live DPS and live reads per second (*Live breakdown*), then the damage chart, its cooldown icons and the pace bar (*Chart and pace*); the HUD Appearance tab: the clocks', figures', spell rows' and damage chart's look |
| History | Days to keep (90 by default, 0 = never prune), the stored count, *Purge history…*; the Results table tab: the Runs list's Damage and DPS bars and their text; the Usage tab: the hidden items |
| Profiles | AceDB profiles: choose, create, copy, delete, reset |

The pages register in that order (the order the panel lists them): General first, Profiles last.
Race, HUD and History are each built by `NS.RegisterTabbedPage` (`settings/OptionsSetup.lua`), with
a page-wide **Defaults** button that restores that page's rows on the current profile. The live
breakdown had a page of its own until the settings layout pass (item 020) folded it into a Race HUD
tab on General; on 2026-10-25 that tab and HUD Appearance moved to the HUD page. No `live.*`,
`hud.*` or `appearance.*` path moved: the HUD page's Defaults restores them, and `/dr list` lists
them under `hud › Race HUD` and `hud › HUD Appearance`.

## The tree (page → tab → row)

Every page except the landing page and Profiles renders through the tabbed renderer, a one-tab page
included (options-ui-§13). Every row carries a `group`, which is its tab.

### Landing page

Untabbed, drawn by the library's `BuildLandingPage` from `NS.LANDING` (`settings/General.lua`):
the 300 px logo `media/logos/dpsrace.logo.tga`, the notes, and a *Slash Commands* heading over
`NS.Slash:LandingRows()`.

### General

The header **Defaults** button restores every General row on the current profile, except the
minimap row (launcher-§3). It never touches a key binding: its tooltip reads *Restore every General
setting on this profile to its addon default: Master controls. Key bindings are not changed.*
(`O.KEYBINDS_UNCHANGED`, options-ui-§20).

Tabs, in order: *Master controls*, *Keybindings*.

#### Tab: Master controls

Composed by the library's `MasterControls` from one declaration, in canonical order
(options-ui-§15). *Master alpha* is omitted: the HUD has no opacity setting.

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| Enable Ka0s DPS Race | `enabled` | checkbox | Off takes the latch's `disabled` hold: every event, message, timer and window goes down (slash-commands-§7) |
| General visibility | `visibility` | dropdown | `always`, `inCombat`, `outOfCombat`, `never`; also decides whether `PLAYER_REGEN_ENABLED` is registered |
| Master scale | `scale` | slider | The Race HUD's, the Results window's and the ability timeline's scale (`Hud.Refresh`, `Results.Refresh`, `ResultsTimeline.ApplyScale`) |
| Lock frame | `locked` | checkbox | The Race HUD's lock: no drag, no resize grip (`Hud.SetLocked`) |
| Debug console | `state.debugConsole` | checkbox, session-only | Shows or hides the console; does not change the logging flag |
| Minimap button | `global.minimap.shown` | checkbox | Reads and writes LibDBIcon's inverted `global.minimap.hide`; no reset touches it |
| Test mode | `state.testMode` | checkbox, session-only | Starts or stops test mode (`/dr test`: static sample data in the HUD and the Results window); ticked while `/dr sim` plays too, and unticking ends either; refused in combat, ended by combat. Every start and stop (a race armed from chat or the key included) repaints an open panel through `Helpers.RefreshScalars` |
| Reset position | — | button | Puts the HUD and the Results window back at their default positions and sizes (`Hud.ResetPosition`, `Results.ResetPosition`), and an open ability timeline back over the Results window (`ResultsTimeline.ResetPosition`; it stores no place of its own); the run detail's folded sections (`windows.results.collapsedSections`) stay folded |
| Reset all settings | — | button | Asks first (`DPSRACE_RESET_ALL`), then resets the current profile; run history, other profiles and the minimap button are untouched |

The *Test mode* row is the composer's, with `default = false` stamped by `settings/General.lua`, so
*Reset all settings* ends test mode (options-ui-§15); the composer emits the row without one.

#### Tab: Keybindings

The General page's last tab (options-ui-§20), a host tab drawn by the library's `O.KeybindingsTab`
from `NS.BINDINGS` (`core/LauncherSetup.lua`); the addon draws none of its rows. Under the library's
fixed intro, one row per binding in `Bindings.xml`'s order: *Toggle race HUD*, *Toggle results
window*, *Arm or cancel race*, each labeled with its `BINDING_NAME_` text, with one key button and
**Clear**. The button binds the action's first key and reads it; when the game's page holds a second
key it reads *<key> +1*, and its tooltip names both keys and says where the other was set. A
right-click on the button clears the first key (a second moves up); **Clear** removes every key.
Below them, the set line (*Saved for: all characters* or *this character only*) and
the outcome line. Keys are the game's, saved to the binding set in force (account or character),
never to the profile; a key set here shows in Options -> Keybindings -> Ka0s DPS Race and the other
way round. In combat nothing is bound or cleared.

### Race

#### Tab: Race

The page's only tab, its subsections in the order of a race. Line by line: *Default race length*;
*Countdown cue sound* alone (it fires from 10 seconds whatever the center numbers do); *Center-screen
countdown* | *Center countdown from (seconds)*; *Buzzer raid warning and sound* | *Sticky-combat hint
after (seconds)*; *Late-cast grace (seconds)* | *Damage-restart gap (seconds)*.

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| *Length* heading | | | |
| Default race length | `race.defaultLength` | dropdown | The presets 0:30, 1:00, 2:00, 3:00, 5:00 (`NS.HudStates.PRESETS`); the HUD's length until the player picks one. A change clears the remembered pick (`race.lastLength`) and redraws the HUD (`Hud.ForgetLength`) |
| *Countdown* heading | | | |
| Countdown cue sound | `race.countdownCue` | checkbox | The cue at 10, 5, 3, 2, 1 s left and with each center number (so every second from 10 with the defaults), once a second at most; read at each mark, and a change re-arms the marks at once (`Countdown.Refresh`) |
| Center-screen countdown | `race.centerCountdown` | checkbox | The large numbers in the middle of the screen in the last seconds; off hides a number on screen at once (`Countdown.Refresh`). Test mode follows it |
| Center countdown from (seconds) | `race.finalCountdown` | slider 3 to 10, step 1 | Seconds left when the numbers start; a change re-arms the marks (`Countdown.Refresh`) |
| *At the buzzer* heading | | | |
| Buzzer raid warning and sound | `race.buzzer` | checkbox | Read at the buzzer |
| Sticky-combat hint after (seconds) | `race.hintDelay` | slider 5 to 60 | How long combat may hold after the buzzer before the HUD's waiting body suggests ways to drop it. Not frozen into a run |
| *Scoring rules* heading | | | |
| Late-cast grace (seconds) | `race.grace` | slider 0 to 5, step 0.1 | Copied onto each new run; a saved run keeps its own (spec §5.2). The tooltip says *Applies to new runs* |
| Damage-restart gap (seconds) | `race.restartGap` | slider 3 to 15 | Copied onto each new run, as grace is (spec §5.3) |

### HUD

A page of its own since 2026-10-25 (the owner's call: the two HUD tabs off General), built by
`NS.RegisterTabbedPage` in `settings/Hud.lua` and listed just above History. Its rows, paths and
defaults are the ones the two tabs had on General. The header **Defaults** button restores both
tabs on the current profile; its tooltip reads *Restore every HUD setting on this profile to its
addon default: the Race HUD tab (display, live breakdown, chart and pace) and HUD Appearance.*

Tabs, in order: *Race HUD*, *HUD Appearance*.

#### Tab: Race HUD

Every HUD setting, in three subsections. Line by line: *Show the race HUD* | *Race clock*; *Spell rows
shown* | *Show spell icons*; *Show live DPS* | *Live reads per second*; *Show damage chart* | *Show
cooldown icons*; *Show pace bar*; *Pace bar range*.

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| *Display* heading | | | |
| Show the race HUD | `hud.showMode` | dropdown | `onArm` (*When a race is armed*, the default): the HUD opens on arm and on a result, and closes again when that race is over; `always`: open from login. Choosing *Always* opens it now. The tooltip says *General visibility* on Master controls still applies: while it hides the addon, the HUD stays hidden |
| Race clock | `hud.clock` | dropdown | `both` (*Elapsed and time left*, the default): the running body's elapsed clock in green beside time left in red, each captioned; `left` (*Time left*): one big red clock; `elapsed` (*Time elapsed*): one big green clock. Test mode follows it. Reaction: `NS.Hud.Refresh()` |
| *Live breakdown* heading | | | |
| Spell rows shown | `live.rows` | slider 0 to 15 | Spells the running HUD lists, in Blizzard's order. 0 lists every spell: as many as fit show, and the mouse wheel scrolls through the rest (the caption reads *1-8 of 23*). The HUD result card follows it too, with the same wheel scroll |
| Show spell icons | `live.icons` | checkbox | Icons on the HUD's rows, live and on the result card |
| Show live DPS | `live.showDps` | checkbox | Blizzard's live DPS figure beside the damage |
| Live reads per second | `live.hz` | slider 2 to 10 | The coalesced live read's rate (spec §10) |
| *Chart and pace* heading | | | |
| Show damage chart | `live.chart` | checkbox | The running HUD's damage chart (#2): a column per bucket of the race (at most 60), scaled to the board's best x 1.15 with its level and average-pace diagonal, or with no best to the damage so far. Hidden on a shared session, and when it would leave fewer than three spell rows; then only the plot hides, and the *Damage profile* heading stays over the pace bar. Also gates the HUD result card's chart (with a best before the run, that best's diagonal on a max covering both the run's damage and the best's, x 1.15; Round C); the Results detail shows it whatever this says |
| Show cooldown icons | `live.castDots` | checkbox | The ability's icon (12 px) along the top of the damage chart at each cast of an ability whose base cooldown is 29 s or more (#14: the big cooldowns, an on-use trinket, a potion), at its time on the race clock (a pre-pull cast on 0:00); a later icon that would overlap the one before it drops to the first row below with room, as many rows as the plot holds (the *Chart height* and one icon row the plot keeps on top, so a single row never covers the columns), and a crowd past the last row shows as one *+n* mark whose tooltip lists each cast and its time. Live on the running HUD, on the result card and in the Results detail; in all three hovering an icon names the spell and its time (*Cast at 0:12*). Off hides them in all three, and in test mode's sample charts. Reaction: `NS.Hud.Refresh()` and `NS.Results.Refresh()` |
| Show pace bar | `live.paceBar` | checkbox | The running HUD's pace bar (#3), under the *Damage profile* heading and above the plot: it runs from pace x (2 - range) to pace x range around the best's average damage by now (*Pace bar range*), its tick fixed in the middle marking *on pace*. Also gates the HUD result card's pace bar (the final damage against the best before the run: the previous best when the run just became the best), in the same place, under the heading and above the plot. Hidden with no best, on a shared session and on a lost run's card |
| Pace bar range | `live.paceRange` | slider 1.1 to 2.0, step 0.05 | How far either side of the best's pace so far the pace bar reaches (default 1.5 = ±50%): it runs from pace x (2 - range) to pace x range, the tick fixed in the middle. A value stored above 2.0 reads as 2.0. Its own line. Reaction: `NS.Hud.Refresh()` |

#### Tab: HUD Appearance

The HUD's look (the owner's call, 2026-10-24), after Race HUD on the HUD page. Every block is composed by the
library (options-ui-§16: `H.FontGroup`, `H.BarGroup`), so its rows, order and words are the
canonical ones, and its class color is the player's (`classColorSource = "player"`). Every row's
reaction is `NS.HudAppearance.Changed()`, which bumps the restyle stamp and redraws both windows.
The defaults are the look shipped before the tab existed.

| Subsection | Schema prefix | Rows | Styles |
|---|---|---|---|
| *Elapsed clock* | `appearance.elapsed.` | the font block (*Font*, *Font size*, *Font color*, *Use class color*, *Font flags*, *Font shadow*); JetBrains Mono 26, green | the running body's elapsed clock. *Font size* is the pair's; a clock shown alone draws half again as large (its tooltip says so, through the composer's `tooltips`) |
| *Time left clock* | `appearance.left.` | the font block; JetBrains Mono 26, red | the time-left clock, the same way |
| *Live figures* | `appearance.figures.` | the font block; Friz Quadrata 20, shadowed | the running body's *Damage* and *DPS · Live* figures. A larger size grows the KPI boxes |
| *Spell bars* | `appearance.bars.` | the bar block (*Bar texture*, *Bar opacity*, *Bar color*, *Use class color*), then *Row height* (12 to 30, an `extra`) | the spell rows' fill and height on the HUD (live and result) and in the Results window's breakdown |
| *Spell text* | `appearance.spellText.` | the font block; Friz Quadrata 10, white, shadowed | the spell rows' name and amount; the share column keeps its caption gray |
| *Damage chart* | `appearance.chart.` | the bar block; solid, 90%, the mockup's indigo (0.36, 0.37, 0.84); then *Chart height* (40 to 160, step 2, default 80) and *Column gap* (0 to 3 px, step 1, default 0), each an `extra` | the damage chart's columns, its plot height (the columns' and the best-pace line's: the plot is one 13 px icon row taller, on top) and the space between two columns (0: one smooth area), on the HUD (running and result card) and in the Results detail |
| *Chart background* | `appearance.chart.` (`bgColor`, `useClassColorBg`) | the composed color pair (`H.ColorPair`): *Background color* (with alpha; default black at 35%, the plot's old backdrop) and *Use class color* | the damage chart plot's backdrop. A backdrop has no fill texture, so it takes a swatch and its class-color companion and nothing else (options-ui-§16, §17), under its own heading |
| *Pace bar* | `appearance.pace.` | the bar block; the chart's old look (solid, 90%, the same indigo) | the pace bar's fill, its own block since 2026-10-25: restyling the chart's columns leaves it alone |

Every live breakdown and chart and pace row's reaction is `NS.Hud.Refresh()`.

### History

#### Tab: History

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| *Sharing* heading | | | |
| Include talents link | `share.talentsLink` | checkbox | Off by default (the owner's call, 2026-10-25): the share stays one line. On, `Share.Messages` appends the run's `talentbuild` link (`[<spec>: <loadout>]`, clickable in others' chat), in the same message when both fit in 255 bytes, else as a second message. A run with no talent string, or one whose link alone passes 255 bytes, shares the line alone. Registered before *Days to keep*, so the stored count and *Purge history…* stay under *Storage* |
| *Storage* heading | | | |
| Days to keep | `global.history.keepDays` | slider 0 to 3650 | Account-wide (its tooltip opens *Account-wide: shared by every profile.*). 90 by default: runs older than that many days are pruned, never one holding a best. 0 never prunes. The prune runs at login and after each saved run (spec §7), never on the change itself |
| *Stored now* | — | text | `NS.History.StoredLine()`: the stored count and its size at about 1.5 KB a run; repainted on `RUN_SAVED` / `RUNS_CHANGED` |
| Purge history… | — | button | The tab's last act, under no heading of its own (options-ui-§7, §21). `NS.History.ConfirmDeleteAll()`: asks first (`DPSRACE_DELETE_ALL_RUNS`), then `Recorder.DeleteAll()`, which fires `RUNS_CHANGED`. Refused while a race is armed, running or waiting for its result |

#### Tab: Results table

The Runs list's Damage and DPS cells (the owner's call, 2026-10-24, after MultiMeters' bars): a
fill over the row's own stripe (no track and no border, 2026-10-25), from 10% of the cell (the smallest figure among the runs the filters
pass on the same target type) to 100% (that type's largest), linear between them and full when the view holds one run or one figure,
and the text over them. Every block is composed (options-ui-§16, §17), in the styled-tab order Fill,
Font. Each class color is the row's character's: the row describes that run
(`classColorSource = "unit"`), so *Use class color* paints a warlock's run purple whoever is logged in.
Every row's reaction is `NS.Results.Refresh()`.

| Subsection | Schema prefix | Rows | Default |
|---|---|---|---|
| *Damage bar* | `resultsTable.damageBar.` | the bar block (*Bar texture*, *Bar opacity*, *Bar color*, *Use class color*) | solid, 85%, the spell breakdown's indigo (0.29, 0.29, 0.45) |
| *DPS bar* | `resultsTable.dpsBar.` | the bar block | the same as *Damage bar* |
| *Bar text* | `resultsTable.barText.` | the font block | Friz Quadrata 10, white, shadowed; a dash keeps the column's muted gray |

The Runs list's rows keep the table's alternating stripe; the bar cells draw no background of their
own.

#### Tab: Usage

The hidden items (P9): items the Results window's usage never lists, on any run.

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| *Hidden items* heading | | | |
| Hidden items | `global.usage.hidden` | the library's ID list (`H.IdList`, `kind = "item"`, two columns, the X at the left), drawn by the tab's `afterGroup` under a one-line blurb; the row itself is `skipRender` | Account-wide (its tooltip opens *Account-wide: shared by every profile.*). Empty by default. *Hide an item* takes an item ID, a shift-clicked link or the name of an item a stored run listed (`Usage.KnownItems`, the add box's suggestions); each line is the item's icon, name and gray ID with an X that takes it off. Writes go through `Usage.Hide` / `Usage.Unhide` (the whole value through the seam); the `SETTINGS_CHANGED` redraws the Results window and repaints this list, whichever way the value changed (a right-click, `/dr set` or `reset`). The detail's right-click *Never show <item>* (in its *Usage* edit) adds to the same list. *No item is hidden.* when empty |

The page's Defaults button restores *Days to keep*, the Results table tab's rows and the hidden items; it never touches a stored run.

### Profiles

Untabbed: AceDBOptions' own table, drawn by AceConfigDialog into the library's panel. No Defaults
button. See [profiles.md](profiles.md).

## The launcher and the key bindings

| Surface | What it does |
|---|---|
| Minimap button / broker row | One LibDataBroker launcher (`core/LauncherSetup.lua`, launcher-§1). Left-click always opens this panel; right-click opens the options menu. The tooltip is the library's status tooltip |
| Options menu entries | **Enabled** (`/dr enable` / `disable`), **Locked** (`NS.ToggleLock`, the *Lock frame* row), **Test mode** (`NS.ToggleTestMode`, the *Test mode* row), **Show window** (`NS.ToggleHud`, the race HUD). While disabled, only *Enabled* stays clickable; the rest are grayed and write nothing (launcher-§2) |
| Key binding: *Toggle race HUD* | `CLICK DpsRaceToggleHud:LeftButton`, category `BINDING_HEADER_DPSRACE`: set in **Options → Keybindings → Ka0s DPS Race**, or in **General > Keybindings** in this addon's settings. Presses the same `NS.ToggleHud` the *Show window* entry runs (launcher-§6) |
| Key binding: *Toggle results window* | `CLICK DpsRaceToggleResults:LeftButton`, same category. Runs `NS.ToggleResults` |
| Key binding: *Arm or cancel race* | `CLICK DpsRaceArmToggle:LeftButton`, same category. Runs `NS.ToggleArm`: arms the HUD's length, or cancels an armed or running race; never discards a pending result (spec §6.4) |

No binding has a default key. Each refuses with the one disabled line while the addon is off,
and with the capture line under a perf run, exactly as the verbs do (slash-commands-§7). The button
names are permanent: renaming one unbinds every player's key.

## Mapping to the schema

Every control reads through `NS.GetSetting(path)` and writes through `NS.SetByPath(path, value)`,
the same seam `/dr set path value` uses, so the panel and the CLI cannot drift apart. A row's
`onChange` is its reaction, set on the row in its page file (the Master controls' in `settings/General.lua`'s `reactions` table). Rows whose storage is
not a profile path carry their own `get`/`set`: the debug console, test mode and the minimap button.
The table above is derived from `NS.Schema`; `lua tests/run.lua` pins its row order
(`test_schema.lua`).
