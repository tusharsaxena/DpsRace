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
| `Set` | the schema write seam, once per changed setting; `core/Database.lua` on a profile change, and the v6 migration's count of HUD faces and textures it put back on the skin |
| `Combat` | `NS:OnCombatChanged`, each combat edge |
| `Cmd` | the slash dispatcher's own refusals |
| `Cfg` | the options panel's combat lock |
| `Perf` | the performance harness |
| `Diag` | the diagnostics report |
| `Race` | `modules/Race.lua`, one line per edge (debug-logging-§8): the arm (length, newest session before it) and each refusal with its reason code; a session adopted, or ignored because it existed before the arm; the clock start; each combat-start and combat-end edge; the buzzer; an incomplete run's early end; the stopping hold and the quiet that releases the read; a still-sealed read's retry; the read's outcome (status, damage present or absent, never the figure); each late cast and a restart; the resume's decision after a `/reload`; and why a run was lost |
| `Meter` | `modules/Meter.lua`: a `C_DamageMeter` call that raised, with the error |
| `Recorder` | `modules/Recorder.lua`: a snapshot call that raised, and each prune's count with its age in days |
| `Loadouts` | `modules/Loadouts.lua`: how many orphaned gear and talent sets a sweep dropped (#6) |
| `Casts` | `modules/Casts.lua`: at the result, how many casts the race kept and how many were dropped for a sealed spell ID (#14) |
| `Timeline` | `modules/Results_Timeline.lua`: the ability timeline window built, and each draw's ability count (#14) |
| `Gear` | `modules/Results_Gear.lua`: the gear view window built, and each draw's slot count (#17) |
| `Format` | `modules/Format.lua`: the client's number formatter refused, so numbers fall back to Lua |
| `Hud` | `modules/Hud.lua`: the window built, and every race state change it drew |
| `Countdown` | `modules/Countdown.lua`: the center numbers' frame built (with the digit art or the font fallback), and a pop animation the client refused |
| `AutoArm` | `modules/AutoArm.lua`: a dummy session beginning and ending, each auto-arm (or its refusal, with the reason) and each cancel when the target moves off the dummies (#16) |
| `Results` | `modules/Results.lua`: the window and each tab built, and stepping aside for the talent tree and coming back when it closes; `modules/Results_Source.lua`: the source switched to the sample history and back |
| `Share` | `modules/Share.lua`: a chat send that failed, with the channel |
| `Test` | `modules/Preview.lua`: test mode or the sim on (with the still state or the scenario), and off with the reason |
| `Toast` | `modules/BestToast.lua`: each new best that toasts (its run id and gain), and the shell's own lines (`TOAST`: queued, shown, expired, a builder that failed) |

The library writes the latch's stand-down and stand-up edges with their holds, and the launcher's
registration lines, through the same sink.

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
- **state**: the stored run count, the loadout store's gear sets and talent loadouts with the races
  holding a damage chart this session (`loadouts gear=<n> talents=<n> chart races=<n>`), and whether the HUD, the Results window and test mode are showing, with the preview's mode (`test` or `sim`), its still state or script phase, its scenario and its ticker, and the new-best toast (`toast shown=<b> waiting=<n> key=<run id, sample or the preview's key> preview=<b>`).
- **rejected**: event names the client refused at registration (`NS.rejectedEvents`).
- The end marker, `[Diag] ==== Ka0s DPS Race diagnostics end: N line(s) ====`.

The **state** section also carries the race line: `race state=<state> run=<id> session=<id>
pending=<n> meter=<available>` (the race's state, the current run and its session, the stored runs
still running or stopping, and whether Blizzard's meter is available), and the HUD line: `hud
body=<idle|armed|running|stop|waiting|result|none> events=<none|idle|live> ticking=<bool>
locked=<bool>` (the body on screen, the event set the HUD's frame holds, whether the 20 Hz countdown
`OnUpdate` is attached), and the Results line: `results tab=<runs|insights> mode=<wide|narrow>
rows=<n> selected=<id|none>` (the tab, whether the detail sits beside the list, the rows the tab
shows (on Insights, the runs its filters pass), the run the detail shows). The HUD's trace lines carry the `Hud` tag (the window built, each
race transition it heard); the Results window's the `Results` tag (the window and each tab built, the talent tree step-aside);
`Format` says when the client's formatter is refused.

### Caps

The report stays at or under the library's `DIAG_MAX_LINES` (1200 in the vendored v1.80.0), below
the console's 3000-line buffer, so it never evicts itself. Each list is capped at
`DIAG_MAX_PER_LIST` (40). A capped report ends with `truncated: N line(s) omitted, per-list caps
hit=yes|no` and then the end marker.

### What it does not read or call

- No meter value. Nothing in the report calls `C_DamageMeter`, and every value passes through
  `SafeToString`, so a secret prints as a placeholder instead of raising.
- No protected API, no Lifecycle hold, no event registration, no timer. Sections read state only and
  never touch the debug flag.
- Nothing is redacted: the report goes to the maintainer privately (README, *Reporting a bug*).
