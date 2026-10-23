# Common tasks

Recipes for the changes made most often in Ka0s DPS Race. Every change ends on the green gate:
`lua tests/run.lua` and `luacheck .` from the repo root ([testing.md](testing.md)). T10 adds the
feature recipes (a dummy, a flag, a HUD state) once their files exist.

## Add a setting

- Add the default to `defaults/Profile.lua` (`profile` or `global`). It is the only place a default
  is written.
- Add the row to the page file that owns it (`settings/General.lua` today): `path`, `page`, `group`
  (its tab), `label`, `desc`, `type`, `default` read from `NS.defaults`, and an `onChange` if
  something must react.
- Add `enUS` keys for the `label` **and** the `desc` in `locales/enUS.lua`.
- If the reaction registers anything, it must also be rebuilt from current settings on stand-up
  (`standUp` in `core/LifecycleSetup.lua`).
- Update [schema.md](schema.md) and [settings-panel.md](settings-panel.md); `test_schema.lua` checks
  that every row resolves and has a group and label.

## Add a settings page

- Create `settings/<Page>.lua`: build the context with `NS.Helpers.CreatePanel`, render through
  `RenderTabbedSchema`, register with `NS.RegisterOptionsPage`.
- Add its key to `VALID_PAGES` in `settings/Schema.lua`, and its TOC line after `settings/General.lua`
  and before `settings/Profiles.lua` (the page order is the registration order).

## Add a slash command

- Append a positional triple `{ "verb", L["What it does"], function(rest) … end }` to `NS.COMMANDS`
  in `settings/Slash.lua`. A feature verb calls the same handler its launcher entry or key binding
  calls, which refuses through `NS.StoodDownRefusal()` while stood down.
- Add the `enUS` key. The help index and the landing page pick the row up on their own.
- `test_disabled.lua` step 7 classifies every row, so the new verb's disabled behavior is checked
  without editing the test. Update the hub's *Slash Commands* table.

## Add a bus message

- Declare it once in `NS.MSG` (`core/Bus.lua`) as `Ka0s_DpsRace_<PascalCase>`, with a comment naming
  the sender and payload.
- Send with `NS.SendBus(NS.MSG.NAME, …)`; receive on the module's own `NS.NewBusTarget()`.
- Add the row to the hub's *Message Bus* table.

## Register a game event

- Register through `NS.SafeRegisterEvent(target, event, handler, NS.rejectedEvents)`, never
  `RegisterEvent` directly.
- Make sure stand-down drops it and stand-up re-registers it from current settings. `test_disabled`
  checks both: steps 2 and 3 assert no registration survives a disable, and step 9 asserts
  re-enabling rebuilds the set from current settings.

## Add a perf bucket

- Declare it in `buckets` in `core/PerfSetup.lua` (with `within` if it nests).
- Bracket the hot path: `local t0 = Perf.on and debugprofilestop()` … `if t0 then
  Perf.Note("key", debugprofilestop() - t0) end`. Every declared bucket must be reached by a real
  bracket. Record it in [performance.md](performance.md).

## Add a locale string

- Add `L["English text"] = "English text"` to `locales/enUS.lua`. The key is the English string.
  US spelling only (localization-§5); `test_prose` checks every tracked file.

## Add a SavedVariables migration

- Raise `NS.SCHEMA_VERSION` in `core/Database.lua` and append `{ to = N, run = function(sv) … end }`
  to `STEPS` (`perProfile = true` for a per-profile step). The step must be idempotent against a
  fresh default profile; the runner stamps the version.
- Add a row to [schema.md](schema.md#migrations) and a case to `test_schema.lua`.

## Regenerate the case inventory

- `lua tests/run.lua --list > docs/test-cases.md`, then set the README `[tests]` badge to the new
  total, in the same change (testing-§5).

## Re-vendor LibKa0s

- Use `/dev-copilot:wow-revendor-libka0s`. It copies `libs/LibKa0s/` and `tests/_kit/` from the
  library's tag, moves the `Bundles` line in root `CLAUDE.md` in the same commit, and prunes
  `media/icons/` to the `LibKa0s icons:` line. Never edit either vendored folder by hand;
  `test_vendor_sync` catches it.
