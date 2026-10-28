# Slash dispatch

How `/dr` and `/dpsrace` reach a handler. The command table itself is the hub's
[*Slash Commands*](ARCHITECTURE.md#slash-commands) section, generated from `NS.COMMANDS`; this page
covers the dispatch around it (slash-commands).

## Registration

`settings/Slash.lua` builds one `LibKa0s-Slash-1.0` dispatcher with `slash = "/dr"` and
`slashAliases = { "/dpsrace" }`, and `Sl:Register()` (called from `OnInitialize`) registers both
through AceConsole's `RegisterChatCommand`, never `SLASH_*` globals. Both reach `Sl:OnSlash`.

The spec notes that `/dr` is short and another addon may already own it; `/dpsrace` is the long form
that always works.

## Routing

- A bare `/dr` runs `config` and opens the settings panel.
- The first word is the verb, matched case-insensitively against `NS.COMMANDS`; the rest of the line
  is passed to the handler as `rest`.
- `options` is an alias of `config` (the descriptor's `aliases`). There are no other aliases, and
  `diagnostics` never gets one (debug-logging-§14).
- An unknown verb prints `unknown command` and the help index.
- `NS.RunVerb(verb, rest)` runs a row's handler by name. The launcher's *Enabled* entry uses it, so
  the menu and `/dr enable` are one handler.

## The schema CLI

`list`, `get path`, `set path value`, `reset path` and `resetall` are the library's, wired through
the descriptor's `get`, `set`, `findRow`, `allRows` and `applyDefault` onto the same write seam the
panel uses. `set` parses the value by the row's type. `resetall` asks first through the
`DPSRACE_RESET_ALL` popup.

## The disabled gate

The descriptor's `isEnabled` is `not NS.IsDisabled()`: only the `disabled` hold counts, so a perf
capture's `perf` hold alone never prints the disabled line. While disabled:

- every **reserved** verb keeps answering (`help`, `config`, `enable`, `disable`, `list`, `get`,
  `set`, `reset`, `resetall`, `debug`, `diagnostics`, `perf`, `version`), and so does the host verb
  `ignore`, which reads and writes one setting as `get` and `set` do (`HOST_LIVE_VERBS`, appended to the
  library's `LIVE_VERBS` as the descriptor's `liveVerbs`; slash-commands-§2 makes the feature-verb
  refusal a SHOULD, and declining it for a verb owes no register row);
- a **feature** verb (`arm`, `cancel`, `hud`, `results`, `target`, `test`, `sim`, `lock`, `unlock`) prints
  one line, `Ka0s DPS Race is disabled — enable it with /dr enable`, and does nothing else
  (slash-commands-§2, §7).

Every feature row's handler is wrapped in `feature()` (`settings/Slash.lua`), which answers
`NS.StoodDownRefusal()` before the handler can act. The dispatcher has already refused while
disabled, so in practice the wrapper speaks for the `perf` hold alone, with the capture line. Behind
it each verb runs the same handler the launcher, the key bindings and the HUD's buttons run, never a
copy.

## Host verbs

| Verb | Handler | Notes |
|---|---|---|
| `enable` / `disable` | `doEnabled` | Writes the `enabled` row through the seam and echoes it; on a library-absent load writes through `writeThrough` and takes the hold itself |
| `debug` | `doDebug` | `NS.DebugLog:DebugVerb(rest)` first (`diagnostics`, `on`, `off`), else toggles the window |
| `diagnostics` | `NS.DebugLog:RunDiagnostics()` | See [debug.md](debug.md) |
| `perf` | `doPerf` | Prints the lines `NS.Perf.OnCommand(rest)` returns; see [performance.md](performance.md) |
| `ignore [show\|add\|remove\|defaults] <spell>` | `doIgnore` | The late-cast ignore list (#8), dispatched from a sub-verb table (`IGNORE_VERBS`). Bare `ignore` and `show` print the list, one *Name (id)* line each (`LateIgnore.Label`; 8690 as *Hearthstone, all variants (8690)*), or *The late-cast ignore list is empty.* `add` and `remove` resolve a spell ID, a shift-clicked link or a name (`LateIgnore.Resolve`) and print one line: added, already ignored, removed, not on the list, or why the name did not resolve (unknown, or more than one spell by that name). A hearthstone's name (any variant's, in the client's locale) resolves to 8690, so `add <a variant's name>` ignores every hearthstone; a single variant is added on its own by ID or link. While 8690 is off the list, a variant listed on its own resolves by its name, so `remove <its name>` finds it. `remove` of a variant ignored only through 8690 takes 8690 off and names it. `defaults` writes the default and shows the list. Any other word prints the usage line. Every write goes through `LateIgnore` and the seam. Not behind `feature()`: it answers while disabled and under the `perf` hold, as `set` does |

## Feature verbs

| Verb | Handler | Notes |
|---|---|---|
| `arm [length]` | `doArm` | `NS.Format.ParseLength` reads `90`, `90s`, `1:30`, `3m` and `1m30s`; a length outside 0:10 to 15:00, or one it cannot read, prints `Format.ArmRefusal("bad_length")` and arms nothing. A good length becomes the HUD's pick (`Hud.Act.pickLength`, so it is remembered as the last length), then `Hud.Act.arm()` arms it with the HUD's target count; a refusal prints `Format.ArmRefusal(reason)`. With no length it arms the HUD's own (the last raced, else `race.defaultLength`). The *Armed* line is printed by `modules/Share.lua` on `RACE_STATE_CHANGED`, so every surface that arms prints it |
| `cancel` | `doCancel` | `NS.Race.Cancel()`, then one line for the state it found (canceled, discarded, result closed) or *Nothing to cancel.* |
| `hud [show\|hide\|toggle]` | `doHud` | `NS.SetHudShown(word)`; a bare `hud` toggles, any other word prints the usage line |
| `results [insights]` | `doResults` | `NS.ShowResults(word)`: `NS.Results.ShowTab("insights")` for `insights`, and for `bests` (the tab's old name, a silent alias kept so a macro still works; only `insights` is in the help); any other word, or none, `NS.Results.Show()` |
| `target` | `doTarget` | `Recorder.SnapshotTarget("target")`: `Target: <name> · creature <npcID> · category <label>`, or *No target.* |
| `test [armed\|running\|result]` | `doTest` → `NS.ToggleTestMode(word)` | A bare `test` writes `state.testMode` through the seam (on or off), so the Master controls' checkbox follows. A state word holds that HUD body still: switched in place while test mode is on, else queued (`Preview.Queue`) and started through the same row write; any other word prints *Usage: /dr test [armed\|running\|result]* |
| `sim [scenario]` | `doSim` → `NS.StartSim(word)` | Queues the scenario (`newbest` with none) and turns `state.testMode` on through the seam, or switches an active preview in place. An unknown word prints the usage line (`Sim.Usage()`, every scenario) and one line per scenario with what it shows. The chat box completes no addon's slash words, so these lines are the list |
| `lock` / `unlock` | `doLock` | Writes the `locked` row through the seam and echoes it in the `set` shape (slash-commands-§8); degraded, written through with the HUD's `SetLocked` as the reaction |

## The Arm or cancel key

`CLICK DpsRaceArmToggle:LeftButton` (`Bindings.xml`) clicks a plain hidden button whose `OnClick` runs
`NS.ToggleArm()` (`core/DpsRace.lua`): idle or on a result card it arms the HUD's length
(`Hud.Act.arm`), armed or running it cancels. A run waiting for its result is never discarded by a
key press; the key prints *A run is waiting for its result: /dr cancel discards it.* instead.

The dispatcher's own refusals land in the console as `[Cmd]` lines through the descriptor's `debug`.

## Library absent

The stub keeps `/dr` answering: the host verbs work, the schema CLI names the missing library, and
the refusal format `DISABLED_LINE_FORMAT` is the one library string it carries, pinned byte-equal to
the live library by `test_slash`. Every other line is the stub's own wording (`version` prints
`Ka0s DPS Race version X`, `help` a plain header naming the reduced mode, and an unknown verb falls
through to the help index). The stub applies the same disabled gate as the live dispatcher: a verb
outside `NS.SLASH_LIVE_VERBS` (the library's `LIVE_VERBS`, pinned equal) and `HOST_LIVE_VERBS`
(`ignore`) answers the one refusal line while the `disabled` hold is taken.
