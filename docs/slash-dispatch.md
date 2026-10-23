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
  `set`, `reset`, `resetall`, `debug`, `diagnostics`, `perf`, `version`), which is the whole table
  today;
- a **feature** verb (T9's `arm`, `cancel`, `hud`, `results`, `target`, `test`, `lock`, `unlock`)
  prints one line, `Ka0s DPS Race is disabled — enable it with /dr enable`, and does nothing else
  (slash-commands-§2, §7).

Feature handlers are the same functions the launcher and the key bindings call
(`NS.ToggleHud`, `NS.ToggleResults`, `NS.ToggleLock`, `NS.ToggleTestMode`), and each refuses through
`NS.StoodDownRefusal()`, which picks the disabled line or the capture line by hold.

## Host verbs

| Verb | Handler | Notes |
|---|---|---|
| `enable` / `disable` | `doEnabled` | Writes the `enabled` row through the seam and echoes it; on a library-absent load writes through `writeThrough` and takes the hold itself |
| `debug` | `doDebug` | `NS.DebugLog:DebugVerb(rest)` first (`diagnostics`, `on`, `off`), else toggles the window |
| `diagnostics` | `NS.DebugLog:RunDiagnostics()` | See [debug.md](debug.md) |
| `perf` | `doPerf` | Prints the lines `NS.Perf.OnCommand(rest)` returns; see [performance.md](performance.md) |

The dispatcher's own refusals land in the console as `[Cmd]` lines through the descriptor's `debug`.

## Library absent

The stub keeps `/dr` answering: the host verbs work, the schema CLI names the missing library, and
the refusal format `DISABLED_LINE_FORMAT` is the one library string it carries, pinned byte-equal to
the live library by `test_slash`. Every other line is the stub's own wording (`version` prints
`Ka0s DPS Race version X`, `help` a plain header naming the reduced mode, and an unknown verb falls
through to the help index). The stub applies the same disabled gate as the live dispatcher: a verb
outside `NS.SLASH_LIVE_VERBS` (the library's `LIVE_VERBS`, pinned equal) answers the one refusal
line while the `disabled` hold is taken.
