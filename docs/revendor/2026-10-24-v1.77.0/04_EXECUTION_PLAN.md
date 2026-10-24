# DpsRace: execution plan

Nothing is adopted inside this re-vendor. The adopted candidates are implemented by the run's own
items, each test-first and in its own commit on `feat/2026-10-24-keybinds-layout-strata`:

- **DR-KB** (B1, B2): `Bindings.xml` category, `NS.BINDINGS`, the General > Keybindings tab through
  `O.KeybindingsTab`, tests on the kit's `mock_bindings.lua`, `T.assertBindingsXml` and
  `T.keybindThroughTab`.
- **DR-ZS** (B3, B4, B5 as `plan-data/accepted.json` decides): the frame-layering table and the
  accepted strata changes.

The re-vendor commit itself carries the payloads, the provenance line, the icon prune and the 3g
blocker fix (the Options stub's four members).
