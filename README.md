# Ka0s DPS Race

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.5-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-811%2F811_passing-green)

DPS Race turns a training dummy into a stopwatch. You pick a length and arm the race, and the clock starts on the exact frame your first hit lands. A buzzer tells you when to stop. A few seconds after combat drops, you get your DPS and a breakdown of every ability that went into it.

Each run is saved with your spec, item level and the dummy you hit, which makes it easy to check whether that new trinket or rotation change actually helped. Bests are kept per spec, dummy type and race length, across all your characters. The numbers come from Blizzard's built-in damage meter, so you don't need Details or any other meter running.

## Usage

Open the race window with `/dr hud show`, pick a length (presets from 30 seconds to 5 minutes, or type your own between 10 seconds and 15 minutes), target a dummy and press Arm. The window fills in the dummy's type. You have to be out of combat to arm, because the race starts on a fresh fight. Pre-pot and pre-cast as you would on a real pull: nothing counts until your first hit lands, and from then on the window shows the time elapsed in green beside the time left in red, to a tenth of a second, along with your top abilities as they climb. The HUD settings page can show just one of the two clocks instead. Under the figures, the *Damage profile* chart draws your damage as it builds over the race, with your spells under their own *Spell breakdown* heading below it. Once the board has a best, the chart is scaled to that run, with a faint solid line for its average pace, and a pace bar under the heading shows your damage against that pace, with a tick in the middle where you'd be level with it: red from your fill to the tick when you're behind, green past the tick when you're ahead (a live number isn't possible: the game won't let an addon do math on the meter's figures in combat) (the HUD page's *Pace bar range* sets how far either side of the best's pace the bar reaches: at the default 1.5 it runs from half the best's damage so far to half again, ±50%). The chart and the bar only draw what the game shows them; they never work out whether you're ahead.

In the last ten seconds a big countdown pops up in the middle of the screen, the way a pull timer does, with a tick each second (only you see it; the Race settings page can start it later, at 3 to 10 seconds, or turn it off). When the buzzer goes, stop. Anything already in flight still counts, so a DoT that ticks after the buzzer is yours. Start a new cast more than a second late, though, and the run gets a flag for it (it isn't thrown out). The dummies that hit back tend to hold you in combat long after you've stopped; walk away, or Feign Death, Vanish or Shadowmeld if your class has one, and the result appears once combat drops. You can close the window while you wait. If you'd rather not wait out your DoTs, *Stop Now* takes the result as it reads at that moment (in combat, the moment combat drops), and *Cancel* throws the race away without saving it.

The result card shows your damage and DPS, how far you are above or below your best, the pace bar again (your final damage against the best you had before this run), the damage chart with that best's average pace as a faint line, and your abilities, as many as *Spell rows shown* lists on the live HUD (0 lists them all and scrolls). Race again from there, open the run in the Results window, delete it (after a confirmation), or post a one-line summary to chat (the History settings page can add your talents link to it, so others can click it open). The Results window opens from the chart button on the race window's title bar, from `/dr results`, or from a key binding, and it keeps your runs for 90 days by default (*Days to keep* on the History settings page; 0 keeps them all), never removing a run that holds a best. Each run shows its time with the DoT tail after the buzzer (*2:00 +11.1s*), how far its DPS sits from the best run in its group (*Delta*; with no grouping, the best in the list), and a status tag like *Spec best*, *Complete*, *Flagged* or *Incomplete* (hover *Spec best* to see the dummy type and length it is the best for, *cleave · 2:00*). Each preset race length has its own color in the Results window. It opens on your current character in every spec, newest first, grouped by character, class, spec, dummy type and time together (*Full*). Filter by character, spec, dummy type, length or date, group the list another way (by character, by class and spec, by dummy type, by time, by dummy type and time, or by spec, dummy type and time) or not at all, and press *Save* to keep that view for next time. Hovering a cell shows what's behind the number. Click a run to see its full breakdown, its damage chart (for runs you raced since your last reload or login; the game won't let the live numbers be saved) and a timeline of when the buzzer went, when your damage stopped and when combat ended; right-click it to add a note, share it or delete it. Under the run's damage and DPS, a *Delta* box shows the same figure as its *Delta* cell in the list, measured against the same group (or the whole list with no grouping, or the run's spec, dummy type and length when your filters hide it). The top run of its group shows how far it leads the next one instead, with a *New best* trophy beside it, and both change as soon as you change the filters or the grouping. The detail also shows the gear you wore and the talent loadout you raced with: hover an item for its tooltip, shift-click to link it, try the set on in the Dressing Room, open the talents in Blizzard's own tree with *View* (it also posts them to your chat as a link; the Results window steps aside while the tree is open and comes back when you close it), or *Copy* the import string for Wowhead or Raidbots. Runs from before this was added say *Not recorded*. The *Compare vs best* button sets the run beside the best on its board (or the runner-up, if this run is the best): damage, DPS and every spell side by side with the difference, the gear slots that changed, and a *Different loadout* mark when the talents differ. To compare with any other run, right-click that run and pick *Compare With This Run*; the pick lasts until you clear it, reload or log out. If you only want the list, the arrow in the title bar folds the detail away. The Bests tab has your top run for each spec, dummy type and length.

Each run also records what you cast and what you used. The Results window's *Used* column shows small icons for the trinkets, other on-use gear and consumables a run used, gear first (hover for each one's icon, name and when it went off). The run's detail has a *Usage* section listing what the run used; press *Edit* to see every on-use item and consumable you carried when you armed, with what the addon spotted already ticked, tick or untick anything it got wrong and press *Save*. It works this out from your casts, your bag counts and the buffs you had when you armed, so a flask or *Well Fed* counts from before the pull (weapon oils are not listed: they have no on-use). An item you never want to see there, a tabard or a Healthstone, say, can be hidden: right-click it while editing and pick *Never show*, or add it on the *Usage* tab of the History settings page, where you can also take it off the list again. On the damage chart, live and afterwards, a small icon of the ability marks each cast of one with a cooldown over 15 seconds: your big cooldowns, trinkets and potions (*Show cooldown icons* on the HUD settings page turns them off). Two casts close together stack, the later one just below. Hover one, on the race window or in the Results window, to see what it was and when. The detail's *Timeline* button opens the ability timeline: every ability you cast, each with two lanes, this run's casts as thin gold ticks above the compared run's in blue (the best, or a run you picked), each long cooldown's length under its name, with the cast counts at the right and the long cooldowns at the top. Runs from before this was added have no usage or timeline.

The race window can be moved and resized, and locked once you're happy with it. If it opened by itself for a race, it closes again once you dismiss the result; a window you opened stays put, and the HUD settings page can keep it open all the time. The HUD Appearance tab on the HUD page sets the fonts of both race clocks and the live figures, the spell bars' texture, color, height and text, and the damage chart's look and height. To arrange it without a dummy nearby, turn on test mode with `/dr test`: the race window holds still on a made-up race (`/dr test armed`, `running` or `result` picks which screen), and the Results window opens on a made-up history of runs, so you can see every list, tab and run detail without racing first. A strip across the top of each window says the numbers are samples. To watch a whole made-up race play out instead, from the arm to the result and then into the Results window, use `/dr sim`; `/dr sim behind`, `first`, `incomplete`, `died`, `flagged` or `shared` plays the other endings (`/dr sim` with a word it doesn't know lists them). Both switch off when you enter combat, arm a real race, close the race window or type `/dr test` again, and nothing from either is saved: your own history comes back as it was. The minimap button opens the settings on a left-click, and a right-click lets you switch the addon on or off, lock the window, toggle test mode or show the window. You can also bind keys to toggle the race window (*Toggle race HUD*) and the Results window (*Toggle results window*), and one to arm a race or cancel it (*Arm or cancel race*). Set them in Options -> Keybindings -> Ka0s DPS Race, or in General > Keybindings in this addon's settings; both show the same keys, and a key set in one appears in the other.

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

The debug console uses [JetBrains Mono](https://www.jetbrains.com/lp/mono/), licensed under the SIL Open Font License 1.1. The window controls and the debug console draw icons from [Open Iconic](https://github.com/iconic/open-iconic) by Waybury (MIT), and the Results window's status tags draw their icons (trophy, check, flag, x, skull, ghost) from [Phosphor](https://github.com/phosphor-icons/core) (MIT). Only the icons this addon draws are included, each set with its license file beside it.
