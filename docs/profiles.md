# Profiles

Ka0s DPS Race uses AceDB profiles, and they are visible to the player on the **Profiles** settings
page (`settings/Profiles.lua`).

## What a profile holds

Everything under `db.profile`: today the Master controls (`enabled`, `visibility`, `scale`,
`locked`), the HUD's show mode and clock (`hud.*`), the Race page (`race.*`), the live breakdown on
General > Race HUD (`live.*`) and the windows' size and position (`windows.*`). See
[schema.md](schema.md) for the full list.

What a profile does **not** hold, by design:

- **Run history** (`db.global.runs`). A run belongs to the installation, so switching profiles never
  hides a character's runs, and personal bests span every character on the account.
- **The minimap button** (`db.global.minimap`). It belongs to the installation; no profile switch
  moves or hides it (launcher-§3).
- **Session state**: the debug flag and test mode.

New characters start on AceDB's default per-character profile (`NS:InitDB` passes `true`).

## The page

AceDBOptions' own options table, drawn by AceConfigDialog into a container parented on the
library's panel body (never onto an AceGUI widget's frame, options-ui-§19). It is one of the two
untabbed pages and has no Defaults button (options-ui-§13). Choose, create, copy, delete and reset
are AceDBOptions' controls, unchanged.

## What happens on a change

AceDB fires `OnProfileChanged`, `OnProfileCopied` or `OnProfileReset`; all three call
`NS.OnProfileChanged` (`core/Database.lua`), which:

- logs one `[Set]` line;
- re-reads the stored `enabled` and takes or releases the `disabled` hold, since the new profile may
  hold the other value;
- rebuilds the combat event set for the new *General visibility*;
- announces `SETTINGS_CHANGED("profile", key)`.

These callbacks are setup and stay live while the addon is disabled (slash-commands-§7), so
switching to a profile with the addon enabled brings it back up.

## Reset all settings

*Reset all settings* (and `/dr resetall`) is a reset of the **current profile** (options-ui-§12),
after a confirmation. Other profiles, run history and the minimap button are untouched.
