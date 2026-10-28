# Common tasks

Recipes for the changes made most often in Ka0s DPS Race. Every change ends on the green gate:
`lua tests/run.lua` and `luacheck .` from the repo root ([testing.md](testing.md)).

## Add a training dummy to the catalog

- Measure it first: target it in game and run `/dr target`, which prints its name, creature ID and
  current category. The catalog takes measured entries only (spec §4.6).
- Add `[npcID] = { name = "…", category = "…", count = N },` to `defaults/Dummies.lua` with a
  comment giving the date and place it was measured. `category` is one of `Dummies.CATEGORIES`
  (`single`, `cleave`, `dungeoneer`, `boss`, `pvp`, `other`); bests group by category, never by ID.
- Update the catalog table in the spec (§4.6). `test_dummies` checks every entry's shape.

## Add a flag

- Set it on the run in `modules/Race.lua`, where the event that raises it is handled
  (`run.flags.<key>`). Keep the value plain (a number, a boolean or a list of plain tables): it is
  stored as is.
- Emit it from `Scoring.Flags` (`modules/Scoring.lua`) at its place in the display order, with a
  locale key for its full text. A flag emitted there drops the run off the *Clean runs only* board
  automatically (`Bests.Compute`).
- Give it a short label in each of the three places that draw flags: the HUD's result chips
  (`FLAG_CHIP` in `modules/Hud_States.lua`), the Bests board's chip words (`SHORT` in
  `modules/Results_Table.lua`), and the detail's explanation line (`EXPLAIN` in
  `modules/Results_Detail.lua`). Add the `enUS` keys. A chip word is Sentence case, never
  upper-cased (spec §6, *Style*); `test_hud`'s capitals case fails on an ALL-CAPS word. The late
  casts' chip (`FLAG_CHIP.lateCasts`) reads the flag's `count`, the casts left after the ignore list
  (`modules/LateIgnore.lua`), never the run's raw list; any new reader of late casts goes through
  `Scoring.SplitLate` or the flag, so the ignore list applies to it.
- Add the field to spec §7 and §5.4 and to [schema.md](schema.md#the-run-record); extend the
  order case in `test_scoring` and a case in the suite of the module that raises it.

## Refresh the hearthstone list

- `defaults/Hearthstones.lua` (`NS.HEARTHSTONE_SPELLS`) is a static table per patch: the spells the
  ignore list's 8690 entry stands for (#8). Refresh it when a patch adds a hearthstone toy.
- Download SpellCategories, SpellEffect, SpellName, ItemEffect and ItemXItemEffect for the new build
  from wago.tools, and re-run the four rules in the file's header: every spell on the hearthstone
  charge category (2309); plus every teleport to the bind point (SpellEffect `Effect` 252,
  `ImplicitTarget` 9) that a toy or an item casts; plus Dalaran 222695 and Garrison 171253; minus
  Astral Recall 556 and the test and placeholder spells the header names.
- Diff the result against the table, update it and the build named in its header, and update the pin
  test in `tests/test_late_ignore.lua` (the count, 8690, 222695 and 171253 present, 556 absent). The
  Race page's *(all hearthstones, N)* suffix reads the table's length, so it follows on its own.

## Add a HUD body

- Write `Builders.<key>(parent)` in `modules/Hud_States.lua` (a `newBody`, its widgets laid out
  from config, never from a geometry read) and its `:Update(v)` for the view `modules/Hud.lua`
  hands it. If its fixed stack is taller than idle's, `MinContentHeight` must include it, and the HUD's
  minimum height follows. Draw every label through `NS.Style.Text` in the font object for its role
  (`modules/Style.lua`, spec §6 *Style*) and every button through `NS.HudStates.Button`; only a race
  clock keeps a face and size of its own.
- Map the race state (or the STOPPING phase) to the body in `modules/Hud.lua` (`BODY_OF`, or the
  stop and waiting split), give `modules/Sim.lua`'s script a step for it and `modules/MockRuns.lua`'s
  `Figures` its figures (and `Preview.STATES` the body, if test mode should hold it still).
- A live value may only reach a widget setter, `NS.Format.Number` or `C_Spell`, and may only be
  tested against `nil` (the taint notes in [ARCHITECTURE.md](ARCHITECTURE.md#taint-notes)).
  `test_hud`'s secret-render cases and its geometry-read recorder check it.

## Add a compat shim

- Add `function Compat.X(…)` to `core/Compat.lua`, probing the client API by presence and reading
  it at call time; give `core/Compat.lua`'s `.luacheckrc` block the new global and no other file.
- A `LibKa0s-Compat-1.0` member is routed instead, as `Compat.X = CompatLib and CompatLib.X or
  stub`, from the same file.
- Update the shim table in [compat-layer.md](compat-layer.md) (its count is the trigger's).

## Add a setting

- Add the default to `defaults/Profile.lua` (`profile` or `global`). It is the only place a default
  is written.
- Add the row to the page file that owns it (`settings/General.lua`, `Race.lua`, `Hud.lua` or
  `History.lua`): `path`, `page`, `group`
  (its tab), `label`, `desc`, `type`, `default` read from `NS.defaults`, and an `onChange` if
  something must react.
- Add `enUS` keys for the `label` **and** the `desc` in `locales/enUS.lua`.
- If the reaction registers anything, it must also be rebuilt from current settings on stand-up
  (`standUp` in `core/LifecycleSetup.lua`).
- Update [schema.md](schema.md) and [settings-panel.md](settings-panel.md); `test_schema.lua` checks
  that every row resolves and has a group and label, and `test_settings.lua` that every row has a
  default and both its enUS strings.

## Add a settings page

- Create `settings/<Page>.lua`: register its rows, then call `NS.RegisterTabbedPage{ key, title,
  panelName, defaultsTooltip, afterGroup? }` (`settings/OptionsSetup.lua`), which builds the panel,
  its Defaults button and the tabbed render (options-ui-§13).
- Add its key to `VALID_PAGES` in `settings/Schema.lua`, and its TOC line after `settings/General.lua`
  and before `settings/Profiles.lua` (the page order is the registration order).

## Add a slash command

- Append a positional triple `{ "verb", L["What it does"], function(rest) … end }` to `NS.COMMANDS`
  in `settings/Slash.lua`. A feature verb wraps its handler in `feature()`, which answers
  `NS.StoodDownRefusal()` under the perf hold, and calls the same handler its launcher entry or key
  binding calls.
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
  `test_vendor_sync` catches it. The re-vendor that carries LibKa0s-Toast-1.0 also drops the TOC's
  `libs\LibKa0s\Toast.lua` line, `test_vendor_sync`'s exception for it, the provenance note under
  the `Bundles` line and its deviation row in `ARCHITECTURE.md` (the gate fails until it does).
