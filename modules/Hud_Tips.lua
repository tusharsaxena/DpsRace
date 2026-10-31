local _, NS = ...
-- modules/Hud_Tips.lua — the words of the Race HUD's tooltips (DR-F04, the owner's batch of
-- 2026-10-31): each main element of each body says what it is and what it does. Data only, read by
-- modules/Hud_States.lua and modules/Hud.lua, shown through Hud_States' one tooltip path (States.AddTip,
-- { title, line, ... }, the skin's gtip colors). A chip's tip is one string, as its other tips are.
--
-- FIXED WORDS, NO FIGURES. A HUD figure may be secret for the whole pull, and a tooltip reads nothing
-- off the screen: these strings never name a live value, so hovering in combat is as safe as a label.

local L = NS.L

local Tips = {
    lengthCap = { L["Race Length"], L["How long the next race runs. Pick a preset or Custom; the choice stays for your next race."] },
    preset = L["Race for this long. Your bests are kept per race length, so each length has its own."],
    custom = { L["Custom"], L["Set a race length of your own. Click, then type it in."] },
    customBox = { L["Custom length"], L["Type a length from 10 seconds to 15 minutes, such as 90, 1:30 or 3m, then press Enter. Escape backs out."] },
    target = { L["Target"], L["The training dummy you have targeted, its dummy type and its NPC ID. The type decides which board the run counts on."] },
    arm = { L["Arm Race"], L["Get this race ready. The clock starts on your first hit. When you can't arm, the line under this button says why."] },
    results = { L["Results"], L["Open the Results window: your runs, your bests and Insights."] },

    armedClock = { L["Race Length"], L["The length of this race. It starts counting down when your first hit lands."] },
    armedSub = { L["First hit"], L["Nothing counts until your damage lands, so pre-cast and pre-pot as you would on a pull."] },
    cancel = { L["Cancel"], L["Discard this race. Nothing is saved."] },

    clock = { L["Race clock"], L["The race's clock. HUD > Race clock picks what shows here."] },
    elapsed = { L["Elapsed"], L["How long this race has run."] },
    left = { L["Time left"], L["How long until the buzzer."] },
    liveDamage = { L["Damage"], L["Your damage so far this race, as the damage meter reports it."] },
    liveDps = { L["DPS"], L["Your damage per second so far this race, as the damage meter reports it."] },
    profile = { L["Damage profile"], L["How your damage built up over the race. Each column is one slice of time. The line is your best's pace where you have one, and icons mark your cooldowns: hover one for the spell."] },
    pace = { L["Pace bar"], L["Your damage against your best's average at this point in the race. The tick in the middle is on pace: green is ahead of it, red behind."] },
    resultPace = { L["Pace bar"], L["This run's final damage against the best you had before it. The tick in the middle is level with that best: green is ahead of it, red behind."] },
    liveSpells = { L["Spell breakdown"], L["Your spells in this race. Hover a row for the spell. With Spell rows shown at 0, the mouse wheel scrolls the list."] },
    resultSpells = { L["Spell breakdown"], L["This run's spells, highest damage first, with each one's share. Hover a row for the spell and its figures. With Spell rows shown at 0, the mouse wheel scrolls the list."] },
    order = { L["Live order"], L["Spells stay in the damage meter's order while the race runs. Each one's share appears on the result."] },
    count = { L["Spell rows"], L["How many spell rows are drawn. HUD > Spell rows shown sets it."] },

    stop = { L["STOP"], L["The buzzer has gone: stop casting. Damage still landing counts, but a cast that starts after the grace flags the run."] },
    damageStopped = { L["Damage Stopped"], L["How long after the buzzer your last damage landed, as far as the race has seen."] },
    combatEnded = { L["Combat Ended"], L["Combat ended before the buzzer, this far into the race, so the run is incomplete."] },
    inCombat = { L["In Combat"], L["How long you have stayed in combat since the buzzer. The result is read when combat ends."] },
    outOfCombat = { L["Out of Combat"], L["Combat is over, so the result can be read."] },
    pending = { L["Result pending"], L["The damage meter can only be read once combat ends, so the result waits for that. Stop Now takes it as soon as it can."] },
    lateChip = L["Casts that started after the grace. The result flags them unless the spell is on the ignore list."],
    graceChip = L["How long after the buzzer a cast may start before it is flagged. Set it on the Race settings page."],

    resultDamage = { L["Damage"], L["This run's total damage."] },
    resultDps = { L["DPS"], L["This run's damage per second."] },
    newBestChip = L["This run beat your best on this board, by this much."],
    behindChip = L["How far this run fell short of your best on this board."],
    newRace = { L["New Race"], L["Back to the Arm Race screen at this length. This run stays saved."] },
    details = { L["Details"], L["Open this run in the Results window."] },
    share = { L["Share"], L["Pick a chat channel and post this run's result there."] },

    close = { L["Close"], L["Close the race window. A race in progress keeps running; a result card is dismissed and its run stays saved."] },
    footLeft = { L["Character"], L["The spec and character this race counts for."] },
    footRight = { L["Status"], L["Your item level. During a race, how often the figures refresh; after it, whether the result is still pending."] },
}

NS.HudTips = Tips
