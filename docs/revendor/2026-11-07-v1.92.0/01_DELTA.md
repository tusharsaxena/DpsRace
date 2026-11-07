Delta: LibKa0s v1.91.0 -> v1.92.0

Recorded before anything was copied. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.92.0 LibKa0s testkit tools` (tag commit d690237, local annotated tag, not yet pushed). Run under the WoW Forever port, item WFP-RV-DR.

## 3a Base
- `grep -ioE 'Bundles \[LibKa0s\]\(...\) v...' CLAUDE.md` names v1.91.0.
- Last payload commit `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 96d1a57; its CLAUDE.md names v1.91.0. They agree.
- Payload today equals the library at v1.91.0: `diff -rq --strip-trailing-cr` of both payloads against a v1.91.0 extract printed nothing (payload-matches).
- Step 0 pre-flight row for this addon: DpsRace  2026-11-06-v1.91.0  base v1.90.0  vendored-before v1.90.0@96d1a57  ok. No base correction needed.
- Library range: `git -C ../LibKa0s log --oneline v1.91.0..v1.92.0` is 12 commits (WFP-LK-01 to WFP-LK-07).

## 3b/3c Per-file minors that moved (old = this addon, new = v1.92.0), 10 files
```
Compat.lua  old: 1  new: 2
Slash.lua  old: 21  new: 22
Launcher.lua  old: 7  new: 8
OptionsRegistry.lua  old: 4  new: 5
OptionsWidgets.lua  old: 44  new: 45
OptionsFlow.lua  old: 2  new: 3
OptionsTabs.lua  old: 15  new: 16
OptionsTabbed.lua  old: 2  new: 3
OptionsKeybinds.lua  old: 7  new: 8
Perf.lua  old: 15  new: 16
```
No consumer file is behind on a minor the tag did not move: every unmoved file matched in the v1.91.0 diff above, so there is no cross-major skew.

## 3d Diffs
- Pre-copy, `diff -r --strip-trailing-cr` against the v1.92.0 extract: the only differences are the files the library changed in the range (10 non-icon lines in libs/LibKa0s, plus the kit files). Post-copy the same diff, both payloads, is empty apart from the icons the addon did not declare (Step 4, below).

## 3e Consumption map
```
core/Bus.lua:23:LibStub("LibKa0s-Bus-1.0", true)
core/ChartsSetup.lua:7:LibStub("LibKa0s-Charts-1.0", true)
core/Compat.lua:27:LibStub("LibKa0s-Compat-1.0", true)
core/CoreSetup.lua:16:LibStub("LibKa0s-Core-1.0", true)
core/Database.lua:45:LibStub("LibKa0s-Skin-1.0", true)
core/Database.lua:96:LibStub("LibKa0s-Skin-1.0", true)
core/DebugLogSetup.lua:6:LibStub("LibKa0s-DebugLog-1.0", true)
core/EnvSetup.lua:4:LibStub("LibKa0s-Env-1.0", true)
core/LauncherSetup.lua:6:LibStub("LibKa0s-Launcher-1.0", true)
core/LifecycleSetup.lua:6:LibStub("LibKa0s-Lifecycle-1.0", true)
core/MediaSetup.lua:4:LibStub("LibKa0s-Media-1.0", true)
core/PerfSetup.lua:5:LibStub("LibKa0s-Perf-1.0", true)
core/PoolSetup.lua:5:LibStub("LibKa0s-Pool-1.0", true)
core/SimSetup.lua:8:LibStub("LibKa0s-Sim-1.0", true)
core/SkinSetup.lua:77:LibStub("LibKa0s-Skin-1.0", true)
core/ToastSetup.lua:14:LibStub("LibKa0s-Toast-1.0", true)
core/WidgetsSetup.lua:22:LibStub("LibKa0s-Widgets-1.0", true)
modules/Hud_Appearance.lua:180:LibStub("LibKa0s-Core-1.0", true)
modules/Style.lua:300:LibStub("LibKa0s-Skin-1.0", true)
settings/OptionsSetup.lua:13:LibStub("LibKa0s-Options-1.0", true)
settings/Schema.lua:110:LibStub("LibKa0s-Schema-1.0", true)
settings/Schema.lua:114:LibStub("LibKa0s-Slash-1.0", true)
settings/Slash.lua:104:LibStub("LibKa0s-Slash-1.0", true)
```
Majors in the payload with no lookup in this addon (unadopted, class C): LibKa0s-Glow-1.0 LibKa0s-IconBrowser-1.0 LibKa0s-Item-1.0 

## 3f Kit revision
```
old: 20:Kit.VERSION = 51
251:  t.KIT_VERSION = Kit.VERSION
new: 20:Kit.VERSION = 52
251:  t.KIT_VERSION = Kit.VERSION
```
Kit revision 52 pairs with v1.92.0 and both payloads are copied whole in one commit, which satisfies the revision-11 pairing rule by construction.

## 3g Contract delta and Blockers
Read: `git diff -U0 v1.91.0 v1.92.0 -- LibKa0s/`, removed lines only (29). Every removed line is a version constant bump or a line rewritten to read an optional `clients` field (gate applied only when a descriptor carries `clients`), plus Perf's spec-name read, which now tries `C_SpecializationInfo.GetSpecializationInfo` first and then the bare global. No surface kept its name and arguments while changing behavior for a host that does not pass `clients`. Library API docs read: docs/api/Compat/version-2-docs.md (new), Slash 22.2, Launcher 8, Perf 16.1.1.13, Options 37.5.45...4 (all additive, Since markers only).
Host-supplied members, `__Attach*` sites in this addon:
```
none
```
**Blockers: none.**

## 3h Unrecorded vendored tags
```
(empty)
```

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: 44:LibKa0s icons: arrow-left, chart, chat, chevron-down, chevron-left, chevron-right, chevron-up, clear, close, confirm, copy, export, eye, flag, info, lock, move, ph:check, ph:flag, ph:ghost, ph:skul
- Provenance line at CLAUDE.md:43; next non-blank line: 44: LibKa0s icons: arrow-left, chart, chat, chevron-down, chevro. The declaration is kept as written; no icon name changes in this run.
- README provenance line (must be absent): none

## 3j Tests that assume the whole icon folder
```
none
```

## Dead stub mirrors
`grep -rn '__releaseChrome'` outside libs and the kit: none
