# Scope

What Ka0s DPS Race is for, and what it deliberately leaves out. The decisions behind both halves are
in the spec, sections 1, 2 and 13
([`superpowers/specs/2026-10-23-dps-race-pve-design.md`](superpowers/specs/2026-10-23-dps-race-pve-design.md)).
T10 completes this page once the features are in the tree.

## What it does (v0.1.0)

- **A timed race.** The most damage in a chosen time (30 s to 15 min) against any target, with
  known training dummies recognized from a small catalog (`defaults/Dummies.lua`, T3).
- **A frame-accurate start.** The clock starts on the new meter session, which lands on the same
  frame as the first hit (spec §2, §4.2).
- **An honest score.** Damage is the run session's total, read after combat. DPS is that total
  divided by the race length, computed from the addon's own clock. Blizzard's own DPS is stored for
  reference and never ranked (spec §5.1).
- **Flags, never voids.** Casts started after the buzzer plus a grace, damage that restarts after a
  quiet gap, and a reload mid-run all flag a run. Incomplete and lost runs are kept but never count
  toward bests (spec §5.4).
- **A Race HUD** with one body per state, a **Results window** with history, run detail and personal
  bests, settings, a launcher, slash commands, a test mode and a diagnostics report (spec §6).
- **Account-wide history**, so bests span alts. Nothing is pruned unless the player sets *Runs to
  keep* above 0 (spec §6.3, §7).

## What it deliberately does not do

| Not done | Why |
|---|---|
| Read the combat log | Addons cannot read it in 12.0. Every number comes from `C_DamageMeter`. |
| Cut damage off exactly at the buzzer | Values captured in combat stay secret after it, so the score is the session total and the tail is shown instead (spec §2). |
| Show percentages or sort the live breakdown | Both are arithmetic on secret values (spec §6.1). Percentages appear on the result. |
| Count targets automatically | The meter merges identical dummies into one row; the count comes from the catalog or a manual pick (spec §2). |
| Use target health as a start signal | Other players hitting a shared dummy fire it before your first hit (spec §2). |
| "Time to deal X damage", or a goal bar | A threshold crossing is a comparison on a secret value, and the meter keeps no timeline. Dropped 2026-10-23. |
| PvP burst races (duels, events, leaderboards) | Parked until the duel probe runs ([issue #1](https://github.com/tusharsaxena/DpsRace/issues/1)). |
| Share runs between players, or compare two runs side by side | Phase 2. The run record already stores what both would need. |
| Classic or any non-Retail client | Retail only: one `## Interface:` line (toc-file-§3). |
