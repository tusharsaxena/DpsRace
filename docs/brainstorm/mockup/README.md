# Ka0s DPS Race — UX mockups (PvE v0.1.0)

`index.html` is the interactive mockup. Open it in a browser and click the flow steps or the HUD
state buttons. The PNGs in `screens/` are static captures of every view, for quick reference. The
design spec is [`../../superpowers/specs/2026-10-23-dps-race-pve-design.md`](../../superpowers/specs/2026-10-23-dps-race-pve-design.md).

| Screen | What it shows |
|---|---|
| [01-flow](screens/01-flow.png) | The race lifecycle, and what happens when a run is incomplete, reloaded, lost or cancelled |
| [02-hud-idle](screens/02-hud-idle.png) | HUD: race length presets, target card, Arm |
| [03-hud-armed](screens/03-hud-armed.png) | HUD: armed, waiting for the first hit |
| [04-hud-running](screens/04-hud-running.png) | HUD: countdown, live damage and DPS, live breakdown (no %) |
| [05-hud-stop](screens/05-hud-stop.png) | HUD: buzzer, damage-stopped tail, late-cast flag |
| [06-hud-waiting](screens/06-hud-waiting.png) | HUD: combat holding, hint to drop combat, discard |
| [07-hud-result](screens/07-hud-result.png) | HUD: result card with best delta, flags, top spells |
| [08-results-runs-detail](screens/08-results-runs-detail.png) | Results: run history (class and spec icons, ilvl) and run detail with breakdown and timing strip |
| [09-results-bests](screens/09-results-bests.png) | Results: personal bests per spec × category × race length |
| [10-settings-race](screens/10-settings-race.png) | Settings: race and scoring rules (grace, restart gap) |
| [11-settings-history](screens/11-settings-history.png) | Settings: runs to keep (0 = never prune) |
| [12-chat](screens/12-chat.png) | Chat: help, armed, result and share lines |

To regenerate `screens/`, serve this folder and capture each view at 1280×900 with reduced motion
(the Running state then holds at 2:41.3).
