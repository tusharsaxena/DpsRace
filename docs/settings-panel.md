# Settings panel

How Ka0s DPS Race is configured. The panel lives under the game's **Settings → AddOns → Ka0s DPS
Race**; `/dr` or `/dr config` opens it. It is built by `LibKa0s-Options-1.0` from the schema
(`settings/OptionsSetup.lua`), the category is registered eagerly at load and each page body is
built on first show (options-ui-§1, §5).

## Pages

| Page | Covers |
|---|---|
| *(landing)* | Logo, the TOC's notes line, and one line per slash command from `NS.COMMANDS` |
| General | Master controls: on/off, visibility, scale, lock, debug console, minimap button, test mode, the two resets; the New-best toast tab: the toast on or off, its sound, duration and scale, *Test toast*; the Skin tab: the skin this addon wears (the library's); the Keybindings tab: the three key bindings |
| Race | The Race tab along the race's timeline: the default race length, auto-arm, the countdown (cue and center numbers), the buzzer with the sticky-combat hint's delay, the scoring rules (late-cast grace, damage-restart gap) and the late-cast ignore list; the Training dummies tab: the category for new dummies, *Add your target*, your own dummies and the built-ins' switches (#9) |
| HUD | The Race HUD tab: when the HUD shows and what its running clock shows (*Display*), then the live breakdown's spell rows shown, spell icons, live DPS and live reads per second (*Live breakdown*), then the damage chart, its cooldown icons and the pace bar (*Chart and pace*); the HUD Appearance tab: the clocks', figures', spell rows' and damage chart's look |
| History | Days to keep (90 by default, 0 = never prune), the stored count, *Purge history…*; the Results table tab: the Runs list's Damage and DPS bars and their text; the Run detail tab: the detail's spell bars and the compare's two bars; the Usage tab: the hidden items |
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
setting on this profile to its addon default: Master controls, the new-best toast and the skin. Key
bindings are not changed.* (`O.KEYBINDS_UNCHANGED`, options-ui-§20). The skin's reset applies Ka0s
Default at once and sets the first-run picker's memory back, so the picker shows at the next login.

Tabs, in order: *Master controls*, *New-best toast*, *Skin*, *Keybindings*.

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
| Reset position | — | button | Puts the HUD and the Results window back at their default positions and sizes (`Hud.ResetPosition`, `Results.ResetPosition`), an open ability timeline and gear view back over the Results window (`ResultsTimeline.ResetPosition`, `ResultsGear.ResetPosition`; they store no place of their own), and the new-best toast back under the top of the screen (`BestToast.ResetPosition` clears `profile.toast.point`); the run detail's folded sections (`windows.results.collapsedSections`) stay folded |
| Reset all settings | — | button | Asks first (`DPSRACE_RESET_ALL`), then resets the current profile; run history, other profiles and the minimap button are untouched |

The *Test mode* row is the composer's, with `default = false` stamped by `settings/General.lua`, so
*Reset all settings* ends test mode (options-ui-§15); the composer emits the row without one.

#### Tab: New-best toast

The new-best toast (#5, `modules/BestToast.lua`): a toast near the top of the screen when a race sets
a new best on its board over an earlier run. One subsection heading, the tab's own name; a sentence-
case act after the rows.

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| Show a toast for a new best | `toast.enabled` | checkbox | On by default. Off drops a toast on screen and every one waiting (`BestToast.Sync`); on again while test mode is on brings its sample back |
| Play a sound | `toast.sound` | checkbox | On by default: the shell's alert sound (`SOUNDKIT.UI_EPICLOOT_TOAST`, else `RAID_WARNING`) as each toast appears; read as each shows |
| Toast duration (seconds) | `toast.duration` | slider, 3-30, step 1 | 8 by default (the shell's `DURATION`): seconds on screen, paused while the pointer is over it; starts its own line |
| Toast scale | `toast.scale` | slider, 0.5-2.0, step 0.05 | 1 by default; the toast grows and shrinks about its stored place (`BestToast.Refresh`). Not multiplied by Master scale |
| Test toast | — | button, after the rows | A sample toast (*Test <thing>*, options-ui-§21), run as a real one is: its duration, sound and scale; movable while it shows. A second click replaces it (`BestToast.Test`) |

The place is not a row: test mode shows a sample toast held still, and a drag stores it in
`profile.toast.point` (schema.md, named non-setting state); *Reset position* on Master controls clears
it.

#### Tab: Skin

The skin this addon wears (skinning-§3), per profile. The tab is the library's
(`H.AppearanceTab({ owner = "DpsRace", get = NS.SkinChoice, set = NS.WriteSkinChoice })`,
`settings/General.lua`); its key is `Appearance`, its label *Skin* (LibKa0s OptionsAppearance), and it
takes its rows' group's place in the strip: after New-best toast, before Keybindings. The addon draws
none of it. Its body, top to bottom: **Skin source** (*Ka0s skins*, or *EllesmereUI*, disabled with
the failing gate conditions listed while EllesmereUI cannot skin this addon), **Look** (the nine Ka0s
skins, three to a line, each with its swatches), **Font and texture** (a *Font* and a *Texture*
dropdown, *Skin's default (<its face>)* in a new profile), the Scope (*Ignore settings panel*, on in a new profile, and
*Ignore fonts*), **Copy to every Ka0s addon…**, and the note that skins change every visual element
and that HUD style options follow the skin unless the player sets them.

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| Skin source | `skin.source` | the library's choice grid (`skipRender`) | `ka0s` or `eui`. Ka0s to EllesmereUI applies live; EllesmereUI back to Ka0s asks for a reload (the library's) |
| Skin | `skin.skin` | the library's choice grid (`skipRender`) | One of the registered skins (`NS.SKIN_OPTIONS`); a pick repaints every window, the HUD, the toast and the library's tool windows at once, with no reload |
| Ignore settings panel | `skin.ignorePanel` | checkbox (`skipRender`) | On: this addon's settings pages keep the game's look; its windows still wear the skin |
| Ignore fonts | `skin.ignoreFonts` | checkbox (`skipRender`) | On: every string keeps its own face and size; the skin still colors it. Wins over a font override. The HUD Appearance and Results table blocks draw their own *Font* even with *Use the skin's font* on |
| Font | `skin.font` | the library's `Ka0sMedia_Font` picker, each row in its own face (`skipRender`) | A face over the skin's body, title and HUD face; `""` is the skin's own |
| Texture | `skin.texture` | the library's `Ka0sMedia_Statusbar` picker, each row showing its texture (`skipRender`) | A texture over the skin's bar texture for every bar that follows the skin; `""` is the skin's own |
| Font outline | `skin.outline` | the library's dropdown under *Reset font* / *Reset texture* (`skipRender`) | `hud` (the default since LibKa0s v1.83.0, D-10), `all` or `off`: where the skin outlines this addon's text (LibKa0s v1.82.0, D-06). *HUD text only* keeps the outline on the HUD and the toast and drops it from window text; *Off* drops it everywhere. Grayed while *Ignore fonts* is on. A font block whose *Font flags* is *From skin* follows it |
| (none) | `skin.pickerSeen` | drawn by nothing (`skipRender`) | The first-run skin picker's memory, below |

Each row's `onChange` applies only its own half (`core/SkinSetup.lua` says why), so a pick on the tab
or another addon's copy is one repaint, and `/dr set skin.skin obsidian` still repaints. The HUD's
player-styled blocks (HUD > HUD Appearance, History > Results table) follow the skin through their
own *Use the skin's font* and *Use the skin's texture* companions, below.

**The first-run skin picker** (LibKa0s OptionsSkinPicker, the owner's ruling O3). A small window
titled *Choose a skin*, with *Ka0s DPS Race* on its own line above the skin dropdown (LibKa0s v1.81.0,
R-11: the window widens to the name, never cutting it off), shown by `NS.MaybeShowSkinPicker` (`core/SkinSetup.lua`) while the
profile's `skin.pickerSeen` is false: two seconds after login (an AceTimer the stand-down cancels) and
after every profile event, never while the addon stands down, and in combat held for one
`PLAYER_REGEN_ENABLED`. A dropdown of the skins, an eye (this addon has a test mode, X6: it turns test
mode on as `/dr test` does, or shows the Results window when it is already on), a gear (opens this
tab), the Skin tab's own rows (LibKa0s v1.83.0, LK-A3: *Font*, *Texture* and *Font outline*, then the
Scope's two checkboxes), then **Apply** and **Apply to all Ka0s addons** (shown only while another Ka0s addon that uses
skins is loaded). A pick or a row's change only previews; *Apply* and the gear save it through `NS.WriteSkinChoice`, and
the close control and Escape put back what the window opened with. Apply, the gear, the close and Escape set
`skin.pickerSeen`; `NS.HideSkinPicker` (the stand-down, and first on every profile event) takes it
down without setting it.

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

Tabs, in order: *Race*, *Training dummies*.

#### Tab: Race

The page's first tab, its subsections in the order of a race. Line by line: *Default race length*;
*Arm on a training dummy*; *Countdown cue sound* alone (it fires from 10 seconds whatever the center numbers do); *Center-screen
countdown* | *Center countdown from (seconds)*; *Buzzer raid warning and sound* | *Sticky-combat hint
after (seconds)*; *Late-cast grace (seconds)* | *Damage-restart gap (seconds)*; then the *Late-cast ignore list*
heading over its blurb, the list and *Reset list*.

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| *Length* heading | | | |
| Default race length | `race.defaultLength` | dropdown | The presets 0:30, 1:00, 2:00, 3:00, 5:00 (`NS.HudStates.PRESETS`); the HUD's length until the player picks one. A change clears the remembered pick (`race.lastLength`) and redraws the HUD (`Hud.ForgetLength`) |
| *Auto-arm* heading | | | |
| Arm on a training dummy | `race.autoArm` | checkbox | Off by default (#16). On: targeting a training dummy (`defaults/Dummies.lua` and the Training dummies tab's list, `Dummies.Lookup`) out of combat, with the race idle and no test mode or sim on, arms a race at the length Arm Race would arm (`Hud.ArmLength`: the pick, else `race.lastLength`, else this default), through `Race.Arm` and every refusal it has, silently; the arm opens the HUD as a manual arm does and the first hit starts it. Targeting anything else (or nothing) out of combat before the pull cancels the race this rule armed (in combat the pull is under way, so it holds); a race that started, or one the player armed, is never canceled by it. Nothing arms over a result card, while a run waits for its result, in combat or in an instance. Works without *Show near a training dummy*. Reaction: `NS.AutoArm.Sync()` |
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
| *Late-cast ignore list* heading | | | |
| Late-cast ignore list | `race.lateIgnore` | the library's ID list (`H.IdList`, a spell kind resolved by `LateIgnore.Resolve`, two columns, the X at the left, as the Usage tab's), drawn by the tab's `afterGroup` under a one-line blurb; the row itself is `skipRender` | The spells whose late casts never flag a run (#8). *Ignore a spell* takes a spell ID, a shift-clicked link, *Hearthstone* (or any hearthstone's name, which adds 8690), or the name of a spell the character knows, a stored run cast late or the list's defaults (`LateIgnore.KnownSpells`, the add box's suggestions). The 8690 line carries *(all hearthstones, 59)* and removes every variant at once. Writes go through `LateIgnore.Ignore` / `Unignore`; the `SETTINGS_CHANGED` repaints the list whichever way the value changed (a right-click on the HUD or in the Results window, `/dr ignore`, `/dr set` or `reset`, a profile switch). Applies to every stored run, unlike the grace. *No spell is ignored: every late cast flags its run.* when empty |
| Reset list | | button (`H.InlineButtonPair`) under the list | `LateIgnore.Reset()`: the six defaults back, one write of the default (the same as `/dr reset race.lateIgnore`); the other Race rows are untouched. Its tooltip names the six |

#### Tab: Training dummies

Your own training dummies (#9, `modules/DummyList.lua`). Line by line: *Category for new dummies*
under *New dummies*; then, under *Your training dummies*, a blurb, *Add your target*, the list, the
built-ins' checkboxes and *Reset list*. The list row is `skipRender`: the tab's `afterGroup` draws it.

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| *New dummies* heading | | | |
| Category for new dummies | `race.dummyCategory` | dropdown | *Automatic* (`auto`, the default), then *Single target*, *Cleave*, *Dungeoneer*, *Boss-level*, *PvP* (`DummyList.KINDS`): the category a dummy added here or by `/dr targetdummy add` gets when none is typed. *Automatic* reads it from the name (Cleave, Dungeoneer, PvP) and a boss classification or skull level, else single (`DummyList.Infer`). Read when a dummy is added |
| *Your training dummies* heading | | | |
| Add your target | | button (`H.InlineButtonPair`) under the blurb | Reads the target (`DummyList.Read`), saves what the game says about it to `global.dummies.captures` (`DummyList.Capture`) and marks it with the category above (`DummyList.Add`); a switched-off built-in is switched back on. *Target a creature first.* with no creature targeted |
| Training dummies | `race.dummies` | the library's ID list (`H.IdList`, a creature kind resolved by `DummyList.Resolve`, the X as an icon); the row itself is `skipRender` | Your own dummies, ascending by creature ID, each *Name (id)* with the category as its suffix. *Add a creature* takes a creature ID or a captured name and adds it with the category above; the X removes it (`DummyList.Remove`). *No training dummies of your own yet.* when empty |
| One checkbox per built-in | `race.dummies` | `H.SessionCheckbox`, *Name (id) · Category*, ascending by creature ID | Ticked while the built-in counts (`Dummies.Lookup`); clearing one switches it off (`-id` in the list, its runs read as *Other*), ticking switches it back on |
| Reset list | | button (`H.InlineButtonPair`) under the checkboxes | `DummyList.Reset()`: your own dummies gone and every built-in back on, one write of the default (the same as `/dr reset race.dummies`); *Category for new dummies* is untouched |

Every write goes through `DummyList` and the seam. The `SETTINGS_CHANGED` on `race.dummies` or
`"profile"` repaints the tab whichever way the list changed (`/dr targetdummy`, `/dr set` or
`reset`, a profile switch). Applies to every stored run: a run is categorized by its creature as the
list is now.

The page's Defaults button restores every row on both tabs, the late-cast ignore list and your
training dummies among them, and its tooltip says so.

### HUD

A page of its own since 2026-10-25 (the owner's call: the two HUD tabs off General), built by
`NS.RegisterTabbedPage` in `settings/Hud.lua` and listed just above History. Its rows, paths and
defaults are the ones the two tabs had on General. The header **Defaults** button restores both
tabs on the current profile; its tooltip reads *Restore every HUD setting on this profile to its
addon default: the Race HUD tab (display, live breakdown, chart and pace) and HUD Appearance.*

Tabs, in order: *Race HUD*, *HUD Appearance*.

#### Tab: Race HUD

Every HUD setting, in three subsections. Line by line: *Show the race HUD* | *Race clock*; *Show near a
training dummy*; *Spell rows
shown* | *Show spell icons*; *Show live DPS* | *Live reads per second*; *Show damage chart* | *Show
cooldown icons*; *Show pace bar*; *Pace bar range*.

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| *Display* heading | | | |
| Show the race HUD | `hud.showMode` | dropdown | `onArm` (*When a race is armed*, the default): the HUD opens on arm and on a result, and closes again when that race is over; `always`: open from login. Choosing *Always* opens it now. The tooltip says *General visibility* on Master controls still applies: while it hides the addon, the HUD stays hidden |
| Race clock | `hud.clock` | dropdown | `both` (*Elapsed and time left*, the default): the running body's elapsed clock in green beside time left in red, each captioned; `left` (*Time left*): one big red clock; `elapsed` (*Time elapsed*): one big green clock. Test mode follows it. Reaction: `NS.Hud.Refresh()` |
| Show near a training dummy | `hud.autoShow` | checkbox | Off by default (#16). On: the HUD opens by itself (`Hud.ShowNearDummy`) while a known training dummy (the catalog or `race.dummies`) is the target or has a nameplate up, and closes again (`Hud.HideAwayFromDummy`) once none has been seen for `AutoArm.HIDE_DELAY` (3) s, only while the race is idle (an armed or running race, or a result card, holds it; the idle edge asks again). A close by the player during a dummy session keeps it closed until the session ends (the end of test mode closing a window it opened is not the player's close). An arm's or a result card's window becomes the dummy's while one is near, so the race going idle there leaves it open. A window the player opened is never closed by it. `hud.showMode` is unchanged (*Always* already wants the window), and *General visibility* still applies. Not in instances; with nameplates off only the target counts. Off closes a window it opened. Reaction: `NS.AutoArm.Sync()` |
| *Live breakdown* heading | | | |
| Spell rows shown | `live.rows` | slider 0 to 15 | Spells the running HUD lists, in Blizzard's order. 0 lists every spell: as many as fit show, and the mouse wheel scrolls through the rest (the caption reads *1-8 of 23*). The HUD result card follows it too, with the same wheel scroll |
| Show spell icons | `live.icons` | checkbox | Icons on the HUD's rows, live and on the result card |
| Show live DPS | `live.showDps` | checkbox | Blizzard's live DPS figure beside the damage |
| Live reads per second | `live.hz` | slider 2 to 10 | The coalesced live read's rate (spec §10) |
| *Chart and pace* heading | | | |
| Show damage chart | `live.chart` | checkbox | The running HUD's damage chart (#2): a column per bucket of the race (at most 60), scaled to the board's best x 1.15 with its level and average-pace diagonal, or with no best to the damage so far. Hidden on a shared session, and when it would leave fewer than three spell rows; then only the plot hides, and the *Damage profile* heading stays over the pace bar. Also gates the HUD result card's chart (with a best before the run, that best's diagonal on a max covering both the run's damage and the best's, x 1.15; Round C); the Results detail shows it whatever this says |
| Show cooldown icons | `live.castDots` | checkbox | The ability's icon (12 px) along the top of the damage chart at each cast of an ability whose base cooldown is 29 s or more (#14: the big cooldowns, an on-use trinket, a potion), at its time on the race clock (a pre-pull cast on 0:00); a later icon that would overlap the one before it drops to the first row below with room, as many rows as the plot holds (the *Chart height* and one icon row the plot keeps on top, so a single row never covers the columns), and a crowd past the last row shows as one *+n* mark whose tooltip lists each cast and its time. Live on the running HUD, on the result card and in the Results detail; in all three hovering an icon shows the game's full spell tooltip, then its time (*Cast at 0:12*), right of the window (DR-03). Off hides them in all three, and in test mode's sample charts. Reaction: `NS.Hud.Refresh()` and `NS.Results.Refresh()` |
| Show pace bar | `live.paceBar` | checkbox | The running HUD's pace bar (#3), under the *Damage profile* heading and above the plot: it runs from pace x (2 - range) to pace x range around the best's average damage by now (*Pace bar range*), its tick fixed in the middle marking *on pace*. Also gates the HUD result card's pace bar (the final damage against the best before the run: the previous best when the run just became the best), in the same place, under the heading and above the plot. Hidden with no best, on a shared session and on a lost run's card |
| Pace bar range | `live.paceRange` | slider 1.1 to 2.0, step 0.05 | How far either side of the best's pace so far the pace bar reaches (default 1.5 = ±50%): it runs from pace x (2 - range) to pace x range, the tick fixed in the middle. A value stored above 2.0 reads as 2.0. Its own line. Reaction: `NS.Hud.Refresh()` |

#### Tab: HUD Appearance

The HUD's look (the owner's call, 2026-10-24), after Race HUD on the HUD page. Every block is composed by the
library (options-ui-§16: `H.FontGroup`, `H.BarGroup`), so its rows, order and words are the
canonical ones, and its class color is the player's (`classColorSource = "player"`). Every row's
reaction is `NS.HudAppearance.Changed()`, which bumps the restyle stamp and redraws both windows.
The defaults are the look shipped before the tab existed, but for the face and texture that follow the
skin.

Every block but the two clocks is composed with `fromSkin = true` (DR-03), so the composer appends its
*Use the skin's font* (`fontFromSkin`) or *Use the skin's texture* (`barTextureFromSkin`)
companion, on by default, and grays the block's own *Font* or *Bar texture* picker while it is on.
On, the block draws the skin's `hud.font` or `bar.texture` (`HudAppearance.MediaKey`, through
`NS.Skin.Resolve`), except that while the Skin tab's *Ignore fonts* is on a font block draws its own
*Font* (the texture still follows; the grayed picker previews that stored face); off, the stored pick,
which a companion never rewrites. Each skin has its own HUD face (LibKa0s v1.83.0): Ka0s Default
Prototype, Obsidian Expressway, Azeroth Open Sans Semibold, Glass Avant Garde, High Contrast
Doris PP, Ember Emblem, WoW Midnight Segoe UI Semibold, WoW Forever Fira Sans SemiBold, WoW
Default Ka0s Friz Quadrata TT. Only the face and the
texture follow: sizes, flags, shadows and every color stay the player's (X4), with two readings the
library makes without rewriting them. Every block's *Font flags* (the clocks' too) leads with
*From skin*, the default (LibKa0s v1.82.0, D-07), which draws the Skin tab's *Font outline*: outlined
under *All text* and *HUD text only*, none under *Off*, outlined while *Ignore fonts* is on; a flag the
player picks wins. And a block drawing the skin's face draws its *Font size* at the skin's HUD scale
(D-09: Obsidian 13 for Ka0s Default's 12, Glass 11), so its text is as wide in every skin; its own face
and *Ignore fonts* draw the size as set. The two clocks have no
companion and keep their monospace face (D-15). Under Ka0s Default a following block draws Prototype
and the Ka0s Default bar (the one-time reset, schema 5 -> 6, the owner's ruling O2).

| Subsection | Schema prefix | Rows | Styles |
|---|---|---|---|
| *Elapsed clock* | `appearance.elapsed.` | the font block (*Font*, *Font size*, *Font color*, *Use class color*, *Font flags*, *Font shadow*); JetBrains Mono 26, green | the running body's elapsed clock. *Font size* is the pair's; a clock shown alone draws half again as large (its tooltip says so, through the composer's `tooltips`) |
| *Time left clock* | `appearance.left.` | the font block; JetBrains Mono 26, red | the time-left clock, the same way |
| *Live figures* | `appearance.figures.` | the font block with *Use the skin's font*; the skin's face (stored pick Friz Quadrata) 20, shadowed | the running body's *Damage* and *DPS · Live* figures. A larger size grows the KPI boxes |
| *Spell bars* | `appearance.bars.` | the bar block (*Bar texture*, *Use the skin's texture*, *Bar opacity*, *Bar color*, *Use class color*), then *Row height* (12 to 30, an `extra`); the skin's texture (stored pick solid), 90%, the pace bar's blue (0.36, 0.37, 0.84) | the HUD's spell rows' fill (live and result), and the row height of the HUD and the Results window's breakdown alike. The detail's fill is History > Run detail's |
| *Spell text* | `appearance.spellText.` | the font block with *Use the skin's font*; the skin's face (stored pick Friz Quadrata) 10, white, shadowed | the spell rows' name and amount; the share column keeps its caption gray |
| *Damage chart* | `appearance.chart.` | the bar block with *Use the skin's texture*; the skin's texture (stored pick solid), 90%, the mockup's indigo (0.36, 0.37, 0.84); then *Chart height* (40 to 160, step 2, default 80) and *Column gap* (0 to 3 px, step 1, default 0), each an `extra` | the damage chart's columns, its plot height (the columns' and the best-pace line's: the plot is one 13 px icon row taller, on top) and the space between two columns (0: one smooth area), on the HUD (running and result card) and in the Results detail |
| *Chart background* | `appearance.chart.` (`bgColor`, `useClassColorBg`) | the composed color pair (`H.ColorPair`): *Background color* (with alpha; default black at 35%, the plot's old backdrop) and *Use class color* | the damage chart plot's backdrop. A backdrop has no fill texture, so it takes a swatch and its class-color companion and nothing else (options-ui-§16, §17), under its own heading |
| *Spell bar background* | `appearance.bars.` | a *Background* set (below); the skin's track | the track behind the HUD's spell rows |
| *Spell bar border* | `appearance.bars.` | a *Border* set (below); none | a border around each HUD spell row's bar |
| *Pace bar* | `appearance.pace.` | the bar block with *Use the skin's texture*; the chart's old look (the skin's texture, stored pick solid, 90%, the same indigo): `BAR_BLUE` in `defaults/Profile.lua`, the one source of every blue bar's default | the pace bar's fill, its own block since 2026-10-25: restyling the chart's columns leaves it alone |

| *Pace bar background* | `appearance.pace.` | a *Background* set; the skin's `dr.chart.grid` track | the empty part of the pace bar |
| *Pace bar border* | `appearance.pace.` | a *Border* set; none | a border around the whole pace bar. Its green and red parts are meaning colors, no block's |

Every live breakdown and chart and pace row's reaction is `NS.Hud.Refresh()`.

**The Background and Border sets** (`NS.BarStyleRows`, `settings/OptionsSetup.lua`; a styled bar, `HudAppearance.Styled`): every bar on HUD Appearance, the Results table and the Run detail tab carries both, each under its own heading.

- *Background*: the composed color pair, *Background color* (`bgColor`, with alpha) and *Use class color* (`useClassColorBg`), then one appended row in the addon's words, *Use the skin's background* (`bgFromSkin`), which draws the surface's skin track and leaves the swatch unread. On by default where a track shipped (the spell rows, `dr.list.track`; the pace bar, `dr.chart.grid`). Off over a swatch of no opacity on the Results table and the compare, which draw no track by default; there the companion draws `dr.list.track`.
- *Border*: `H.BorderGroup` with `fromSkin = true`: *Border style*, *Border thickness (px)*, *Border color*, *Use class color*, *Use the skin's border* (`borderStyleFromSkin`, on: the skin's `bar.borderStyle`, *None* under Ka0s Default). Thickness and color stay the player's (X4). A style of *None*, a key LibSharedMedia cannot answer, or no thickness draws nothing.
- Both span the bar's whole length, the row, the cell or the compare column, not the fill. The border is a frame with no fill and no mouse, made the first time a block draws one, so it sits over the text at its edges.
- The texture and border pickers are the composer's `LSM30_*` rows, which LibKa0s v1.83.0 draws as the previewing `Ka0sMedia_*` types when SharedMediaWidgets is absent (options-ui-§23).

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
fill over the row's own stripe (no track and no border by default, 2026-10-25), from 10% of the cell (the smallest figure among the runs the filters
pass on the same target type) to 100% (that type's largest), linear between them and full when the view holds one run or one figure,
and the text over them. Every block is composed (options-ui-§16, §17): each bar's Fill, Background and
Border, then the shared Font. Each class color is the row's character's: the row describes that run
(`classColorSource = "unit"`), so *Use class color* paints a warlock's run purple whoever is logged in.
Every row's reaction is `NS.Results.Refresh()`. Each block carries its *Use the skin's ...* companion,
on by default, as HUD Appearance's do (D-16: the Results table counts as HUD style for the reset).

| Subsection | Schema prefix | Rows | Default |
|---|---|---|---|
| *Damage bar* | `resultsTable.damageBar.` | the bar block (*Bar texture*, *Use the skin's texture*, *Bar opacity*, *Bar color*, *Use class color*) | the skin's texture (stored pick solid), 90%, the pace bar's blue (0.36, 0.37, 0.84) |
| *Damage bar background*, *Damage bar border* | `resultsTable.damageBar.` | a *Background* and a *Border* set | none, each spanning the cell |
| *DPS bar* | `resultsTable.dpsBar.` | the bar block | the same as *Damage bar* |
| *DPS bar background*, *DPS bar border* | `resultsTable.dpsBar.` | a *Background* and a *Border* set | none |
| *Bar text* | `resultsTable.barText.` | the font block with *Use the skin's font* | the skin's face (stored pick Friz Quadrata) 10, white, shadowed; a dash keeps the column's muted gray |

The Runs list's rows keep the table's alternating stripe; by default the bar cells draw no background
of their own.

#### Tab: Run detail

The Results detail's bars (the owner's call, 2026-10-31). Three styled bars, each a bar block with its
*Background* and *Border* sets. Every row's reaction is `HudAppearance.Changed()`: a spell row keeps a
stamped look. Row height and the spell text stay HUD Appearance's.

| Subsection | Schema prefix | Class color | Default |
|---|---|---|---|
| *Spell bars*, *Spell bar background*, *Spell bar border* | `resultsDetail.spellBars.` | the player's | as HUD Appearance's *Spell bars*: the skin's texture, 90%, the pace bar's blue, the skin's track, no border |
| *Best run bar*, *Best run bar background*, *Best run bar border* | `compare.best.` | the column's run's character's | the skin's texture (stored pick solid) at 100%, (42, 70, 107) / 255, no track, no border |
| *Other run bar*, *Other run bar background*, *Other run bar border* | `compare.other.` | the column's run's character's | the skin's texture (stored pick solid) at 100%, (83, 69, 0) / 255, no track, no border |

*Best run bar* is the blue column and *Other run bar* the gold one, decided by `Compare.BestSide` as
before. A compare line draws both columns' tracks and borders whichever side its bar is on. *Use the
skin's texture* is **on** for the two compare bars as for every bar (the owner's call, 2026-10-31): a
skin's texture can shift the drawn shade from the swatch, and that is accepted. The Difference's green
and red are not these bars'.

#### Tab: Usage

The hidden items (P9): items the Results window's usage never lists, on any run.

| Row | Schema path | Control | Behavior |
|---|---|---|---|
| *Hidden items* heading | | | |
| Hidden items | `global.usage.hidden` | the library's ID list (`H.IdList`, `kind = "item"`, two columns, the X at the left), drawn by the tab's `afterGroup` under a one-line blurb; the row itself is `skipRender` | Account-wide (its tooltip opens *Account-wide: shared by every profile.*). Empty by default. *Hide an item* takes an item ID, a shift-clicked link or the name of an item a stored run listed (`Usage.KnownItems`, the add box's suggestions); each line is the item's icon, name and gray ID with an X that takes it off. Writes go through `Usage.Hide` / `Usage.Unhide` (the whole value through the seam); the `SETTINGS_CHANGED` redraws the Results window and repaints this list, whichever way the value changed (a right-click, `/dr set` or `reset`). The detail's right-click *Never show <item>* (in its *Usage* edit) adds to the same list. *No item is hidden.* when empty |

The page's Defaults button restores *Days to keep*, the Results table tab's rows and the hidden items; it never touches a stored run.

### Profiles

Untabbed: AceDBOptions' own table, drawn by AceConfigDialog into the library's panel. No Defaults
button. AceConfigDialog acquires its widgets past the Options proxy, so `settings/Profiles.lua` paints
the tree after every `Open` (`NS.SkinPaintAceTree`, `Skin:PaintAceTree` with this owner; nothing when
the library is absent), and it follows the skin as the other pages do. See [profiles.md](profiles.md).

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
