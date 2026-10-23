# Settings panel

How Ka0s DPS Race is configured. The panel lives under the game's **Settings → AddOns → Ka0s DPS
Race**; `/dr` or `/dr config` opens it. It is built by `LibKa0s-Options-1.0` from the schema
(`settings/OptionsSetup.lua`), the category is registered eagerly at load and each page body is
built on first show (options-ui-§1, §5).

## Pages

| Page | Covers |
|---|---|
| *(landing)* | Logo, the TOC's notes line, and one line per slash command from `NS.COMMANDS` |
| General | Master controls: on/off, visibility, scale, lock, debug console, minimap button, test mode, the two resets |
| Profiles | AceDB profiles: choose, create, copy, delete, reset |

T9 adds the **Race**, **Live breakdown** and **History** pages (spec §6.3).

## The tree (page → tab → row)

Every page except the landing page and Profiles renders through the tabbed renderer, a one-tab page
included (options-ui-§13). Every row carries a `group`, which is its tab.

### Landing page

Untabbed, drawn by the library's `BuildLandingPage` from `NS.LANDING` (`settings/General.lua`):
the 300 px logo `media/logos/dpsrace.logo.tga`, the notes, and a *Slash Commands* heading over
`NS.Slash:LandingRows()`.

### General

The header **Defaults** button restores every General row on the current profile, except the
minimap row (launcher-§3).

#### Tab: Master controls

Composed by the library's `MasterControls` from one declaration, in canonical order
(options-ui-§15). *Master alpha* is omitted: the HUD has no opacity setting.

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| Enable Ka0s DPS Race | `enabled` | checkbox | Off takes the latch's `disabled` hold: every event, message, timer and window goes down (slash-commands-§7) |
| General visibility | `visibility` | dropdown | `always`, `inCombat`, `outOfCombat`, `never`; also decides whether `PLAYER_REGEN_ENABLED` is registered |
| Master scale | `scale` | slider | The Race HUD window's scale (`Hud.Refresh`) |
| Lock frame | `locked` | checkbox | The Race HUD's lock: no drag, no resize grip (`Hud.SetLocked`) |
| Debug console | `state.debugConsole` | checkbox, session-only | Shows or hides the console; does not change the logging flag |
| Minimap button | `global.minimap.shown` | checkbox | Reads and writes LibDBIcon's inverted `global.minimap.hide`; no reset touches it |
| Test mode | `state.testMode` | checkbox, session-only | Starts or stops the preview; refused in combat, ended by combat |
| Reset position | — | button | Puts the HUD back at its default position and size (`Hud.ResetPosition`) |
| Reset all settings | — | button | Asks first (`DPSRACE_RESET_ALL`), then resets the current profile; run history, other profiles and the minimap button are untouched |

### Profiles

Untabbed: AceDBOptions' own table, drawn by AceConfigDialog into the library's panel. No Defaults
button. See [profiles.md](profiles.md).

## The launcher and the key bindings

| Surface | What it does |
|---|---|
| Minimap button / broker row | One LibDataBroker launcher (`core/LauncherSetup.lua`, launcher-§1). Left-click always opens this panel; right-click opens the options menu. The tooltip is the library's status tooltip |
| Options menu entries | **Enabled** (`/dr enable` / `disable`), **Locked** (`NS.ToggleLock`, the *Lock frame* row), **Test mode** (`NS.ToggleTestMode`, the *Test mode* row), **Show window** (`NS.ToggleHud`, the race HUD). While disabled, only *Enabled* stays clickable; the rest are grayed and write nothing (launcher-§2) |
| Key binding: *Toggle race HUD* | `CLICK DpsRaceToggleHud:LeftButton`, under **Key Bindings → AddOns → Ka0s DPS Race**. Presses the same `NS.ToggleHud` the *Show window* entry runs (launcher-§6) |
| Key binding: *Toggle results window* | `CLICK DpsRaceToggleResults:LeftButton`, same category. Runs `NS.ToggleResults` |

Neither binding has a default key. Both refuse with the one disabled line while the addon is off,
and with the capture line under a perf run, exactly as the verbs do (slash-commands-§7). The button
names are permanent: renaming one unbinds every player's key.

## Mapping to the schema

Every control reads through `NS.GetSetting(path)` and writes through `NS.SetByPath(path, value)`,
the same seam `/dr set path value` uses, so the panel and the CLI cannot drift apart. A row's
`onChange` is its reaction (`settings/General.lua`, the `reactions` table). Rows whose storage is
not a profile path carry their own `get`/`set`: the debug console, test mode and the minimap button.
The table above is derived from `NS.Schema`; `lua tests/run.lua` pins its row order
(`test_schema.lua`).
