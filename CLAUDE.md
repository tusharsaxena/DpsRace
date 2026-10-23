# CLAUDE.md — Ka0s DPS Race

**Ka0s WoW addon.** Adheres to the **Ka0s WoW Addon Standard** —
https://github.com/tusharsaxena/WowAddonStandards

## Standards compliance (read first)

This repo is built to the **Ka0s WoW Addon Standard** (URL above). All development here — features,
refactors, doc changes — MUST conform to it. The standard is the source of truth for layout, TOC
shape, the Ace substrate, schema-driven settings, slash/prefix conventions, locales, Compat,
tests/lint, and doc structure.

**If a change would deviate from the standard, STOP and flag the deviation explicitly.** Do not
silently deviate and do not silently "fix" to match. Surface it and let the user decide which of
two things it is:

1. **An accepted deviation** — this addon intentionally differs; record it as a row in
   `docs/ARCHITECTURE.md` -> `## Documented deviations`, shaped
   `| Rule | What differs | Why | Decided | Re-check trigger |`, where Rule is the `filename-§N`
   reference. That register is the single home: the reasoning may live in the issue-audit GitHub
   issue or an audit bundle and the row cites it, but a deviation not in the register is not ratified.
2. **A change to the standard itself** — the standard's definition should evolve; the update
   belongs upstream in the WowAddonStandards repo, after which this addon conforms to the new rule.

When in doubt, treat standard conformance as a hard requirement and ask.

## The rules specific to this addon

Every number this addon shows comes from Blizzard's damage meter (`C_DamageMeter`) and is a
**secret value** in combat: tainted code may not compare it, do arithmetic on it, key a table on it
or take `#` of it. Four invariants carry that (spec §8):

- **`modules/Meter.lua` is the only file that calls `C_DamageMeter`**, and **`core/Secrets.lua` is
  the only file that inspects a value that may be secret.** Everywhere else a meter value is an
  opaque handle passed to a widget setter or the native number formatter.
- **No decision is ever made from a meter value in combat.** The start, the buzzer, the tail, late
  casts and the end of combat come from events and `GetTime()`.
- **Layout is computed from config**, never read back off a frame that has received a secret.
- **Every event registration goes through `NS.SafeRegisterEvent`.**

The design is `docs/superpowers/specs/2026-10-23-dps-race-pve-design.md`, and the build plan with
its status ledger is `docs/superpowers/plans/2026-10-23-dps-race-pve-v0.1.0.md`. Read
`docs/data-flow.md` before touching the race or meter path.

Start here, then read the docs:

- **`docs/ARCHITECTURE.md`** — module map, settings schema, message bus, slash surface, event
  wiring, taint notes, known limitations, documented deviations. What this addon actually is.
- **`docs/testing.md`** — how to verify: the headless harness, lint, and the green commit gate.
- Topic detail in `docs/` as needed (`scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`,
  `data-flow.md`, `common-tasks.md`, `slash-dispatch.md`, `profiles.md`, `debug.md`,
  `performance.md`, `smoke-tests.md`).

Green gate before every commit: `lua tests/run.lua` and `luacheck .` (0/0). Never auto-stage/commit/
push and never bump the version without an explicit instruction.

Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.76.0 (MIT).
LibKa0s icons: chat, clear, close, confirm, copy, export, info, lock, reset, settings, sort-down, sort-up, unlock.
