# Profiles

Ka0s DPS Race uses AceDB profiles, and they are visible to the player on the **Profiles** settings
page (`settings/Profiles.lua`).

## What a profile holds

Everything under `db.profile`: today the Master controls (`enabled`, `visibility`, `scale`,
`locked`), the HUD's show mode and clock (`hud.*`), the Race page (`race.*`, the late-cast ignore list and your training dummies among them), the live breakdown on
HUD > Race HUD (`live.*`), the HUD's look (`appearance.*`), the Runs list's bars (`resultsTable.*`), the skin (`skin.*`: the skin and its source, the Scope, the font and texture overrides and the first-run picker's memory), *Include talents link* (`share.*`), the saved Runs and Insights views (`views.runs`, `views.insights`) and the windows' size and position (`windows.*`). See
[schema.md](schema.md) for the full list.

What a profile does **not** hold, by design:

- **Run history** (`db.global.runs`). A run belongs to the installation, so switching profiles never
  hides a character's runs, and personal bests span every character on the account.
- **The training-dummy captures** (`db.global.dummies.captures`). What the game said about a creature
  is the same on every profile; only which creatures count as dummies (`race.dummies`) is the
  profile's.
- **The minimap button** (`db.global.minimap`). It belongs to the installation; no profile switch
  moves or hides it (launcher-§3).
- **Session state**: the debug flag and test mode.

**The late-cast ignore list is per profile, and it is read, not frozen** (#8, the owner's call). Each
run keeps every late cast it recorded, and the active profile's `race.lateIgnore` decides which of them
flag it. Switching to a profile with another list re-scores the whole history at once: the Status
column's *Flagged*, *Hide flagged*, the clean-only bests board and the flags tooltips all follow. Every
cache keyed on the list listens for `SETTINGS_CHANGED("profile", key)` as well as for the row.
Pruning is account-wide (`global.history.keepDays`), so a run that holds a best only on one profile's
clean-only board can be pruned at a login on another profile; the all-runs board protects every
board's best whatever the list ([known-limitations.md](known-limitations.md)).

**Your training dummies are per profile too, and read the same way** (#9). A run keeps its creature
ID, and the active profile's `race.dummies` (with the shipped catalog) decides its category through
`Dummies.CategoryOf`. Switching to a profile with another list recategorizes the whole history: the
bests boards, the Runs and Insights filters and groupings, the target badges, the share line and the
toast follow, and auto-arm re-reads its dummies.

**The skin is per profile** (skinning-§2). Each profile wears its own `skin.*` choice, applied first
on every switch, copy or reset, before anything redraws. `skin.pickerSeen` is per profile as well, so
a new profile, and a reset one, shows the first-run skin picker once (the owner's ruling O3).

New characters start on AceDB's default per-character profile (`NS:InitDB` passes `true`).

## The page

AceDBOptions' own options table, drawn by AceConfigDialog into a container parented on the
library's panel body (never onto an AceGUI widget's frame, options-ui-§19). It is one of the two
untabbed pages and has no Defaults button (options-ui-§13). Choose, create, copy, delete and reset
are AceDBOptions' controls, unchanged; the tree AceConfigDialog draws is painted for this addon's
skin after every open (`NS.SkinPaintAceTree`).

## What happens on a change

AceDB fires `OnProfileChanged`, `OnProfileCopied` or `OnProfileReset`; all three call
`NS.OnProfileChanged` (`core/Database.lua`), which:

- logs one `[Set]` line;
- takes the first-run skin picker down without marking it seen (`NS.HideSkinPicker`), so a preview
  it had up is put back, then applies the new profile's skin, its Scope and its overrides
  (`NS.ApplySkinChoice`), which repaints every window whether or not it was ever built;
- re-reads the stored `enabled` and takes or releases the `disabled` hold, since the new profile may
  hold the other value;
- rebuilds the combat event set for the new *General visibility*;
- offers the first-run skin picker again when the new profile has not closed it
  (`NS.MaybeShowSkinPicker`; nothing while the addon is off);
- announces `SETTINGS_CHANGED("profile", key)`.

These callbacks are setup and stay live while the addon is disabled (slash-commands-§7), so
switching to a profile with the addon enabled brings it back up.

## Reset all settings

*Reset all settings* (and `/dr resetall`) is a reset of the **current profile** (options-ui-§12),
after a confirmation. Other profiles, run history and the minimap button are untouched. The skin goes
back to Ka0s Default and the first-run skin picker shows again.
