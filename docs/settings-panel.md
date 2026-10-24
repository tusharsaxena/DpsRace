# Settings panel

How Ka0s DPS Race is configured. The panel lives under the game's **Settings → AddOns → Ka0s DPS
Race**; `/dr` or `/dr config` opens it. It is built by `LibKa0s-Options-1.0` from the schema
(`settings/OptionsSetup.lua`), the category is registered eagerly at load and each page body is
built on first show (options-ui-§1, §5).

## Pages

| Page | Covers |
|---|---|
| *(landing)* | Logo, the TOC's notes line, and one line per slash command from `NS.COMMANDS` |
| General | Master controls: on/off, visibility, scale, lock, debug console, minimap button, test mode, the two resets; the Race HUD tab: when the HUD shows, and what its running clock shows; the Keybindings tab: the three key bindings |
| Race | The default race length, the countdown cue, the buzzer and the center-screen countdown; the scoring rules (late-cast grace, damage-restart gap) and the sticky-combat hint's delay |
| Live breakdown | The running HUD's rows shown, live reads per second, spell icons and live DPS |
| History | Runs to keep (0 = never prune), the stored count, *Delete all runs…* |
| Profiles | AceDB profiles: choose, create, copy, delete, reset |

The pages register in that order (the order the panel lists them): General first, Profiles last.
Race, Live breakdown and History are each built by `NS.RegisterTabbedPage` (`settings/OptionsSetup.lua`),
with a page-wide **Defaults** button that restores that page's rows on the current profile.

## The tree (page → tab → row)

Every page except the landing page and Profiles renders through the tabbed renderer, a one-tab page
included (options-ui-§13). Every row carries a `group`, which is its tab.

### Landing page

Untabbed, drawn by the library's `BuildLandingPage` from `NS.LANDING` (`settings/General.lua`):
the 300 px logo `media/logos/dpsrace.logo.tga`, the notes, and a *Slash Commands* heading over
`NS.Slash:LandingRows()`.

### General

The header **Defaults** button restores every General row on the current profile, except the
minimap row (launcher-§3). It never touches a key binding, and its tooltip ends *Key bindings are
not changed.* (`O.KEYBINDS_UNCHANGED`, options-ui-§20).

Tabs, in order: *Master controls*, *Race HUD*, *Keybindings*.

#### Tab: Master controls

Composed by the library's `MasterControls` from one declaration, in canonical order
(options-ui-§15). *Master alpha* is omitted: the HUD has no opacity setting.

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| Enable Ka0s DPS Race | `enabled` | checkbox | Off takes the latch's `disabled` hold: every event, message, timer and window goes down (slash-commands-§7) |
| General visibility | `visibility` | dropdown | `always`, `inCombat`, `outOfCombat`, `never`; also decides whether `PLAYER_REGEN_ENABLED` is registered |
| Master scale | `scale` | slider | The Race HUD's and the Results window's scale (`Hud.Refresh`, `Results.Refresh`) |
| Lock frame | `locked` | checkbox | The Race HUD's lock: no drag, no resize grip (`Hud.SetLocked`) |
| Debug console | `state.debugConsole` | checkbox, session-only | Shows or hides the console; does not change the logging flag |
| Minimap button | `global.minimap.shown` | checkbox | Reads and writes LibDBIcon's inverted `global.minimap.hide`; no reset touches it |
| Test mode | `state.testMode` | checkbox, session-only | Starts or stops the preview; refused in combat, ended by combat. Every start and stop (a race armed from chat or the key included) repaints an open panel through `Helpers.RefreshScalars` |
| Reset position | — | button | Puts the HUD and the Results window back at their default positions and sizes (`Hud.ResetPosition`, `Results.ResetPosition`) |
| Reset all settings | — | button | Asks first (`DPSRACE_RESET_ALL`), then resets the current profile; run history, other profiles and the minimap button are untouched |

The *Test mode* row is the composer's, with `default = false` stamped by `settings/General.lua`, so
*Reset all settings* ends test mode (options-ui-§15); the composer emits the row without one.

#### Tab: Race HUD

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| Show the race HUD | `hud.showMode` | dropdown | `onArm` (*When a race is armed*, the default): the HUD opens on arm and on a result, and closes again when that race is over; `always`: open from login. Choosing *Always* opens it now |
| Race clock | `hud.clock` | dropdown | `both` (*Elapsed and time left*, the default): the running body's elapsed clock in green beside time left in red, each captioned; `left` (*Time left*): one big red clock; `elapsed` (*Time elapsed*): one big green clock. Test mode follows it. Reaction: `NS.Hud.Refresh()` |

#### Tab: Keybindings

The General page's last tab (options-ui-§20), a host tab drawn by the library's `O.KeybindingsTab`
from `NS.BINDINGS` (`core/LauncherSetup.lua`); the addon draws none of its rows. Under the library's
fixed intro, one row per binding in `Bindings.xml`'s order: *Toggle race HUD*, *Toggle results
window*, *Arm or cancel race*, each labeled with its `BINDING_NAME_` text, with **Key 1**, **Key 2**
and **Clear**. Below them, the set line (*Saved for: all characters* or *this character only*) and
the outcome line. Keys are the game's, saved to the binding set in force (account or character),
never to the profile; a key set here shows in Options -> Keybindings -> Ka0s DPS Race and the other
way round. In combat nothing is bound or cleared.

### Race

#### Tab: Race

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| *Length* heading | | | |
| Default race length | `race.defaultLength` | dropdown | The presets 0:30, 1:00, 2:00, 3:00, 5:00 (`NS.HudStates.PRESETS`); the HUD's length until the player picks one. A change clears the remembered pick (`race.lastLength`) and redraws the HUD (`Hud.ForgetLength`) |
| *Sounds* heading | | | |
| Countdown cue sound | `race.countdownCue` | checkbox | The cue at 10, 5, 3, 2, 1 s left and with each center number (so every second from 10 with the defaults), once a second at most; read at each mark, and a change re-arms the marks at once (`Countdown.Refresh`) |
| Buzzer raid warning and sound | `race.buzzer` | checkbox | Read at the buzzer |
| *Final countdown* heading | | | |
| Center-screen countdown | `race.centerCountdown` | checkbox | The large numbers in the middle of the screen in the last seconds; off hides a number on screen at once (`Countdown.Refresh`). Test mode follows it |
| Countdown from (s) | `race.finalCountdown` | slider 3 to 10, step 1 | Seconds left when the numbers start; a change re-arms the marks (`Countdown.Refresh`) |

#### Tab: Scoring rules

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| Late-cast grace (s) | `race.grace` | slider 0 to 5, step 0.1 | Copied onto each new run; a saved run keeps its own (spec §5.2). The tooltip says *Applies to new runs* |
| Damage-restart gap (s) | `race.restartGap` | slider 3 to 15 | Copied onto each new run, as grace is (spec §5.3) |
| Sticky-combat hint after (s) | `race.hintDelay` | slider 5 to 60 | How long combat may hold after the buzzer before the HUD's waiting body suggests ways to drop it |

### Live breakdown

#### Tab: Live breakdown

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| *Rows* heading | | | |
| Rows shown | `live.rows` | slider 3 to 15 | Spells the running HUD lists, in Blizzard's order |
| Live reads per second | `live.hz` | slider 2 to 10 | The coalesced live read's rate (spec §10) |
| *Display* heading | | | |
| Show spell icons | `live.icons` | checkbox | Icons on the HUD's rows, live and on the result card |
| Show live DPS | `live.showDps` | checkbox | Blizzard's live DPS figure beside the damage |

Every row's reaction is `NS.Hud.Refresh()`.

### History

#### Tab: History

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| *Storage* heading | | | |
| Runs to keep | `global.history.keep` | slider 0 to 10000 | 0 (the default) never prunes. Above 0 the prune runs at login and after each saved run (spec §7), never on the change itself |
| *Stored now* | — | text | `NS.History.StoredLine()`: the stored count and its size at about 1.5 KB a run; repainted on `RUN_SAVED` / `RUNS_CHANGED` |
| *Danger zone* heading | | | |
| Delete all runs… | — | button | `NS.History.ConfirmDeleteAll()`: asks first (`DPSRACE_DELETE_ALL_RUNS`), then `Recorder.DeleteAll()`, which fires `RUNS_CHANGED`. Refused while a race is armed, running or waiting for its result |

The page's Defaults button restores *Runs to keep* only; it never touches a stored run.

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
`onChange` is its reaction (`settings/General.lua`, the `reactions` table). Rows whose storage is
not a profile path carry their own `get`/`set`: the debug console, test mode and the minimap button.
The table above is derived from `NS.Schema`; `lua tests/run.lua` pins its row order
(`test_schema.lua`).
