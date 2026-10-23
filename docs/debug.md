# Debug

The debug surfaces of Ka0s DPS Race: the console, the logging flag, and the diagnostics report
(debug-logging-§14). The console itself is `LibKa0s-DebugLog-1.0`'s, built from the descriptor in
`core/DebugLogSetup.lua`; its window, buffer, formatting, scrollbar and Copy/Clear are the library's
and are documented there.

## The console and the flag

| Command | Effect |
|---|---|
| `/dr debug on` / `off` | Turns logging on or off. The flag is `NS.State.debug`: session-only, never saved, off after every `/reload` |
| `/dr debug` | Shows or hides the console window. The flag is untouched |
| `/dr debug diagnostics` | Runs the diagnostics report (below); checked before `on` and `off` |
| *Debug console* checkbox | On the General page's Master controls tab: the same window toggle |

Trace lines go through the gated sink `NS.Debug(tag, fmt, …)`, which costs nothing while the flag is
off. Repeating paths use `NS.DebugChanged` or `NS.DebugOnce`, and state written at enable uses
`NS.DebugAtEnable` (debug-logging-§8, §9).

## Tags

| Tag | Written by |
|---|---|
| `Init` | the console, once, when logging turns on: version, schema, profile, stored run count |
| `Set` | the schema write seam, once per changed setting; `core/Database.lua` on a profile change |
| `Combat` | `NS:OnCombatChanged`, each combat edge |
| `Cmd` | the slash dispatcher's own refusals |
| `Cfg` | the options panel's combat lock |
| `Perf` | the performance harness |
| `Diag` | the diagnostics report |

The library writes the latch's stand-down and stand-up edges with their holds, and the launcher's
registration lines, through the same sink. The engine and windows add their own tags with their
tasks (`Race`, `Meter`, `Hud` and so on).

## The diagnostics report

**Two forms, and no third:** `/dr diagnostics` and `/dr debug diagnostics` (the long `/dpsrace`
alias reaches both). There is no `diag` or `dump`; those are ordinary unknown words.

- **It appends.** The report is written after whatever the console holds, so the trace a player just
  reproduced stays above it, and one **Copy** carries both. Nothing clears the console.
- **It turns debug logging on for the session.** This addon keeps the library's default (no
  `diagnosticsEnablesLogging = false`): if the flag was off, the run turns it on before writing, so
  the next reproduction is traced. Nothing turns it back off; a `/reload` does.
- **It writes ungated**, through the library's raw path, so it lands in full whatever the flag says.
- **It works while disabled or stood down**, and in combat. A section whose runtime state was
  released says `stood down: runtime state released` instead of printing empty data.
- **It reveals the console** if hidden, then prints one chat line naming the line count and **Copy**.
- **Library absent:** the stub prints `/dr diagnostics is unavailable: the LibKa0s library did not
  load.` and writes nothing.

### What it contains, in order

- The begin marker, `[Diag] ==== Ka0s DPS Race diagnostics begin ====`.
- The library's identity header: version, client build and interface, locale, the running LibKa0s
  minors, the debug flag, combat state, and this addon's `[Init]` summary.
- **identity** (`modules/Diagnostics.lua`): stored and code schema version, run-record format,
  active profile, stored `enabled`, stood-down state and the latch's holds.
- **settings**: every setting that differs from its default as `path = value (default)`, plus
  `enabled` always.
- **state**: the stored run count and whether the HUD, the Results window and test mode are showing.
- **rejected**: event names the client refused at registration (`NS.rejectedEvents`).
- The end marker, `[Diag] ==== Ka0s DPS Race diagnostics end: N line(s) ====`.

The **state** section also carries the race line: `race state=<state> run=<id> session=<id>
pending=<n> meter=<available>` (the race's state, the current run and its session, the stored runs
still running or stopping, and whether Blizzard's meter is available), and the HUD line: `hud
body=<idle|armed|running|stop|waiting|result|none> events=<none|idle|live> ticking=<bool>
locked=<bool>` (the body on screen, the event set the HUD's frame holds, whether the 20 Hz countdown
`OnUpdate` is attached), and the Results line: `results tab=<runs|bests> mode=<wide|narrow>
rows=<n> selected=<id|none>` (the tab, whether the detail sits beside the list, the rows the tab
shows, the run the detail shows). The HUD's trace lines carry the `Hud` tag (the window built, each
race transition it heard); the Results window's the `Results` tag (the window and each tab built);
`Format` says when the client's formatter is refused.

### Caps

The report stays at or under the library's `DIAG_MAX_LINES` (1200 in the vendored v1.76.0), below
the console's 3000-line buffer, so it never evicts itself. Each list is capped at
`DIAG_MAX_PER_LIST` (40). A capped report ends with `truncated: N line(s) omitted, per-list caps
hit=yes|no` and then the end marker.

### What it does not read or call

- No meter value. Nothing in the report calls `C_DamageMeter`, and every value passes through
  `SafeToString`, so a secret prints as a placeholder instead of raising.
- No protected API, no Lifecycle hold, no event registration, no timer. Sections read state only and
  never touch the debug flag.
- Nothing is redacted: the report goes to the maintainer privately (README, *Reporting a bug*).
