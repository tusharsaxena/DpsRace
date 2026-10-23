# DPS Race Probe

A throwaway addon that measures what Ka0s DPS Race can rely on. It shows a small movable
window (timer + live meter readout) and writes everything to `DpsRaceProbeDB` in
`WTF/Account/<ACCOUNT>/SavedVariables/DpsRaceProbe.lua`. Claude reads that file.

After each session: **`/reload` or log out** so the SavedVariables file is written.

## Commands

| Command | What it does |
|---|---|
| `/drp arm [sec]` | Arm a timed PvE run (default 30s). Target the dummy first. |
| `/drp duel` | Arm a duel run. Auto-arms when you *receive* a duel request. |
| `/drp stop` | End the active run now. |
| `/drp read` | Dump the meter into the active run right now. |
| `/drp partner Name-Realm` | Partner for addon-message tests (auto: duel opponent, or the targeted player at arm time). |
| `/drp ping` | Send a test addon message to the partner. |
| `/drp svtest on\|off` | Also write raw secret values to SavedVariables at the buzzer. |
| `/drp last` / `status` / `show` / `hide` / `clear` | Housekeeping. |

## Tests

### A. PvE timing (solo, any training dummy)
1. Target a single-target dummy. `/drp arm 30`.
2. Open with a **cast-time** spell. Attack until the buzzer (raid warning "STOP").
3. Stop completely. Let combat drop (walk away from the dummy if it keeps you in).
4. Read the summary in chat.
5. Repeat once opening with an **instant** spell, and once on a **cleave/AoE dummy group** hitting 3+ targets.

Answers Q2 (what `durationSeconds` measures), Q3 (whether the buzzer snapshot is readable after
combat), Q5 (meter event timing and frequency), and whether the live window can show damage and
spell names mid-fight.

### B. Duel (two players, both with the probe installed)
1. Both players: target the other, then `/drp duel` (the person receiving the request is armed automatically).
2. Duel. **The target stands still and doesn't defend.** The attacker bursts them to the duel loss.
3. Both players read the chat summary. Pings are sent automatically after `DUEL_FINISHED`, and each
   side should see `ADDON_MSG recv` from the other.
4. Swap roles and repeat once.

Answers Q1 (whether duel damage shows up in the meter, and on which side), Q4 (health/combat
events as a start signal, whether `DUEL_FINISHED` and the defeat message are clean), and Q6
(addon messages right after a duel).

If you have no second player: duel anyway with a friend who doesn't have the addon. Your side still
answers most of Q1, Q4 and Q5.

### D. When does your damage stop? (v0.2, solo)
Each run prints `TEST D` and `TEST ById` lines in its chat summary.
- **D1, clean stop:** `/drp arm 30` on a single dummy. Stop dead at the buzzer and walk away.
- **D2, DoT tail:** same, but apply all your DoTs just before the buzzer, then stop.
- **D3, contamination:** stop at the buzzer, wait about 10s **while still in combat**, then attack again
  for about 5s. Then stop and walk away. `TEST D` should say `resumed after idle gap: YES`.

### E. Pending run survives /reload (v0.2, solo)
On the Dungeoneer's Training Dummy (it hits back, so combat sticks): `/drp arm 30`. At the buzzer,
stop and **`/reload` while still in combat**. After the reload, walk away until combat drops.
The summary should print a `TEST E` line.

### C. Secrets in SavedVariables (optional, no longer needed)
`/drp svtest on`, then one short `/drp arm 15` run, then log out. Afterwards, check whether
`DpsRaceProbe.lua` still loads and what `DpsRaceProbeSecretDB` contains. `/drp svtest off` when done.

## Output

Each run in `DpsRaceProbeDB.runs[]` holds the player and target metadata, the timestamps of every
signal (`t`), the event counts, a relative-time log, full meter dumps at several moments (`reads`),
snapshot results, addon-message traffic, and a chat `summary`.
