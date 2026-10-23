# Compat layer

`core/Compat.lua` is the compat family's root and its only file (compat). It is the one file in Ka0s
DPS Race that names a version-variant or optional client API, and the one that resolves
`LibKa0s-Compat-1.0`. Every other file calls `NS.Compat.X`, never the raw global. It publishes
**three** hand-written shims, counted the way documentation-§3 counts them:

```
cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'   # 3
```

Three meets the trigger, so this page exists and the `compat-layer.md` row in
[ARCHITECTURE.md](ARCHITECTURE.md) ▸ `## Documentation map` reads *Present*.

## The hand-written shims

Each probes for a capability by presence (`type(X) == "function"`), read at call time, never by asking
which client is running. There is no `WOW_PROJECT_ID` branch anywhere in the addon.

| Shim | Question it answers | Rungs, in order | API absent | Caller |
|---|---|---|---|---|
| `CanAccessTable(t)` | May this context read the contents of table `t`? | `canaccesstable`, then `issecrettable` | `true` (no secrets system: every table is readable) | `core/Secrets.lua` only |
| `ChatSender()` | Which function sends one chat line? | `C_ChatInfo.SendChatMessage`, then the bare `SendChatMessage` (deprecated 11.2.0) | `nil`; nothing is sent | `modules/Share.lua` |
| `NewNumberFormatter()` | A new native number formatter that takes a secret | `C_StringUtil.CreateAbbreviatedNumberFormatter`, then `CreateNumericRuleFormatter` (pcall'd) | `nil`; `modules/Format.lua` abbreviates a plain number in Lua and hands a secret to `AbbreviateNumbers` | `modules/Format.lua` |

Two rungs are kept on the dead-rung rule's terms (compat): neither the bare `SendChatMessage` nor the
second `C_StringUtil` constructor has been confirmed absent on every 120105 client. The smoke tests ask
the client which one it has ([smoke-tests.md](smoke-tests.md), *Client assumptions*); a rung no
admitted client provides is deleted, not kept.

## The routed members

`IsSecret`, `CanAccess` and `IsSafeKey` are `LibKa0s-Compat-1.0`'s secret guards, routed from this root
with their library-absent stub (library-stack-§7). They are the library's, so they are not counted and
not re-documented here: their contract is the library's `docs/api/Compat/version-1-docs.md`.

The stub re-implements the guard bodies on purpose: "the library is missing" is not "the client has no
secrets system", so the stub still reads `issecretvalue` and `canaccessvalue` bare, at call time.

## Who may call the guards

The spec's first invariant (§8) is that `core/Secrets.lua` is the only file that inspects a value that
may be secret. The compat family owns the client detectors; `NS.Secrets` owns the questions asked of a
value. So:

- `core/Secrets.lua` binds `NS.Compat.IsSecret`, `CanAccess` and `IsSafeKey` at file scope (the TOC
  loads `core/Compat.lua` first and says so), and calls `NS.Compat.CanAccessTable` after its own
  table check. Its public surface (`NS.Secrets.*`) is unchanged.
- No other file reaches a guard. `tests/test_meter.lua` scans every loaded file for it, and a second
  scan pins the four client detectors to `core/Compat.lua`.
- `.luacheckrc` grants the detectors, `C_ChatInfo`, `SendChatMessage` and `C_StringUtil` to
  `core/Compat.lua` alone.
