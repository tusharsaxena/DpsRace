# Ka0s DPS Race

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.5-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-402%2F402_passing-green)

DPS Race turns a training dummy into a stopwatch. You pick a length and arm the race, and the clock starts on the exact frame your first hit lands. A buzzer tells you when to stop. A few seconds after combat drops, you get your DPS and a breakdown of every ability that went into it.

Each run is saved with your spec, item level and the dummy you hit, which makes it easy to check whether that new trinket or rotation change actually helped. Bests are kept per spec, dummy type and race length, across all your characters. The numbers come from Blizzard's built-in damage meter, so you don't need Details or any other meter running.

## Usage

Open the race window, choose a length (30 seconds up to 15 minutes, with presets for the common ones), target a dummy and press Arm. You have to be out of combat to arm, because the race starts on a fresh fight. Pre-pot and pre-cast as you would on a real pull: nothing counts until your first hit lands, and from then on the window counts down to a tenth of a second and shows your top abilities as they climb.

When the buzzer goes, stop. Anything already in flight still counts, so a DoT that ticks after the buzzer is yours. Start a new cast more than a second late, though, and the run gets a flag for it (it isn't thrown out). The dummies that hit back tend to hold you in combat long after you've stopped; walk away, or Feign Death, Vanish or Shadowmeld if your class has one, and the result appears once combat drops. You can close the window while you wait.

The result card shows your damage and DPS, how far you are above or below your best, and your top five abilities. Race again from there, or open the run in the Results window, or post a one-line summary to chat. The Results window keeps every run you've ever done. Filter it by character, spec, dummy type, length or date, sort it by DPS or item level, and open any run to see its full breakdown and a timeline of when the buzzer went, when your damage stopped and when combat ended. The Bests tab has your top run for each spec, dummy type and length.

The race window can be moved and resized, and locked once you're happy with it. To arrange it without a dummy nearby, turn on test mode: it plays a short made-up race with a strip across the top saying the numbers aren't yours, and it switches off the moment you enter combat. The minimap button opens the settings on a left-click, and a right-click lets you switch the addon on or off, lock the window, toggle test mode or show the window. You can also bind keys to show the race window and the Results window, and one to arm a race or cancel it, under Key Bindings, AddOns, Ka0s DPS Race.

Everything else is on the addon's page under Settings → AddOns, and `/dr` (or `/dpsrace`) on its own opens it. `/dr help` prints the full command list.

## How the race works

- Arming takes a snapshot of your character and your target. If the target is a known training dummy, its type is filled in for you. Any other target works too and is saved as "Other".
- Your first hit starts a new fight in Blizzard's damage meter. That moment starts the clock, and the run is saved right away, so a `/reload` mid-race doesn't lose it.
- The buzzer goes off at exactly the race length, measured by the addon's own clock.
- Once you're out of combat and your damage has been quiet for a couple of seconds, the addon reads that fight's totals from the meter.
- Your DPS is your total damage divided by the race length, so a three-minute race is always divided by 180 seconds. If combat drops before the buzzer, the run is marked incomplete and divided by the time you actually fought.
- Runs can pick up flags: casts after the buzzer, damage that started again after a long pause, or a reload during the race. Flagged runs still count, and the flag stays visible. Incomplete runs, and runs whose fight couldn't be read, never count toward your bests.

## FAQ

| Question | Answer |
|---|---|
| Why doesn't the live breakdown show percentages? | During combat the game hides the actual numbers from addons. An addon can draw a bar or print an amount, but it can't divide one number by another. You get the percentages on the result card, once the fight is over. |
| Why is my DPS different from what the damage meter says? | Blizzard's meter divides by the whole fight, including the seconds you spend waiting for a dummy to drop combat. DPS Race divides by the race length you chose, which is the fair comparison between runs. The meter's own figure is saved with the run if you want it. |
| Does damage after the buzzer count? | Yes. Damage that's already on its way, like DoTs ticking and casts landing, counts. The result shows how long after the buzzer your damage kept landing. Starting new casts after the buzzer earns a flag. |
| Why won't it let me arm? | You're in combat, a previous run is still waiting for its result, or Blizzard's damage meter isn't available. The window tells you which. |
| The dummy keeps me in combat forever. What do I do? | Walk out of its range, or use an ability that drops combat. The run waits for you, and you can close the window in the meantime. |
| Does it work on things that aren't dummies? | Yes. Any target works. Known dummies just get their type filled in so your bests are grouped properly. |
| Are my runs shared with anyone? | No. Everything stays in your own saved variables unless you post a summary to chat yourself. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| The window says the damage meter is unavailable | Switch on Blizzard's built-in damage meter. The window shows the reason the game gave. |
| A run shows as "Waiting for result" for a long time | You're still in combat. Leave combat and the result appears a couple of seconds later. |
| A run shows as "Lost" | The fight was cleared from the meter before it could be read, for example by a meter reset or a logout while waiting. The run is kept, but has no score. |
| I can't find the race window | `/dr hud show`. |
| The settings panel won't open | It doesn't open in combat. Try again once combat ends. |
| Something looks wrong and I want to report it | Follow [Reporting a bug](#reporting-a-bug) below. |

## Reporting a bug

- Type `/dr debug on` and reproduce the bug.
- Type `/dr diagnostics`.
- If the debug window isn't open, open it with `/dr debug`. Press **Copy**, copy the entire output, and include it with your bug report.

The report is added after the debug trace in the same window, so one copy carries both.

## Issues and feature requests

Please raise them on GitHub rather than in comments:
<https://github.com/tusharsaxena/DpsRace/issues>

## Version History

| Version | Date | Highlights |
|---|---|---|
| 0.1.0 | Unreleased | - First release: timed DPS races against training dummies, with a live race window, run history and personal bests |

## Credits

The debug console uses [JetBrains Mono](https://www.jetbrains.com/lp/mono/), licensed under the SIL Open Font License 1.1. The window controls and the debug console draw icons from [Open Iconic](https://github.com/iconic/open-iconic) by Waybury (MIT). Only the icons this addon draws are included, each set with its license file beside it.
