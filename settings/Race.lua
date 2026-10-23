local _, NS = ...
-- settings/Race.lua — the Race page (spec §6.3): the default race length, the countdown cue and the
-- buzzer, and the scoring rules a new run freezes into its own record (grace, restart gap) with the
-- sticky-combat hint's delay.

local L = NS.L
local D = NS.defaults.profile.race
local PAGE = "race"
local RACE, SCORING = L["Race"], L["Scoring rules"]

-- The race lengths the HUD offers (modules/Hud_States.lua), as a numeric dropdown: "3:00" for 180.
local function lengthValues()
    local out = {}
    for _, n in ipairs(NS.HudStates.PRESETS) do out[#out + 1] = { value = n, text = NS.Format.Length(n) } end
    return out
end

-- A new default replaces the length remembered from the last pick (the HUD redraws with it). The
-- buzzer and the hint read their rows when they fire, so they need no reaction; the cue and the center
-- countdown re-arm the race's marks (modules/Countdown.lua), so a change takes effect at once.
local function newDefault() NS.Hud.ForgetLength() end
local function rearm() NS.Countdown.Refresh() end

NS.RegisterSchemaRows({
    -- ── Race ──
    { path = "race.defaultLength", page = PAGE, group = RACE, subgroup = L["Length"], type = "number",
      label = L["Default race length"], default = D.defaultLength, values = lengthValues(),
      tooltip = L["The race length the HUD offers until you pick another. The last length you pick is remembered until you change this."],
      onChange = newDefault },
    { path = "race.countdownCue", page = PAGE, group = RACE, subgroup = L["Sounds"], type = "bool",
      label = L["Countdown cue sound"], default = D.countdownCue,
      tooltip = L["A sound at 10, 5, 3, 2 and 1 seconds left, and with each number of the center countdown. Takes effect at once, in the race in progress too."],
      onChange = rearm, startsLine = true },
    { path = "race.buzzer", page = PAGE, group = RACE, subgroup = L["Sounds"], type = "bool",
      label = L["Buzzer raid warning and sound"], default = D.buzzer,
      tooltip = L["A raid warning that says STOP, with a sound, the moment the race ends."] },
    { path = "race.centerCountdown", page = PAGE, group = RACE, subgroup = L["Final countdown"], type = "bool",
      label = L["Center-screen countdown"], default = D.centerCountdown,
      tooltip = L["Large numbers in the middle of the screen for the last seconds of the race, one a second down to 1, like a pull timer. Only you see them."],
      onChange = rearm, startsLine = true },
    { path = "race.finalCountdown", page = PAGE, group = RACE, subgroup = L["Final countdown"], type = "number",
      min = 3, max = 10, step = 1, label = L["Countdown from (s)"], default = D.finalCountdown,
      tooltip = L["How many seconds before the buzzer the center countdown starts. 3 to 10."],
      onChange = rearm },

    -- ── Scoring rules ── (spec §5.2, §5.3: a run keeps the values it was raced with)
    { path = "race.grace", page = PAGE, group = SCORING, type = "number", min = 0, max = 5, step = 0.1,
      label = L["Late-cast grace (s)"], default = D.grace,
      tooltip = L["A cast that starts later than this after the buzzer flags the run. 0 to 5 seconds. Applies to new runs. Saved runs keep the value they were raced with."] },
    { path = "race.restartGap", page = PAGE, group = SCORING, type = "number", min = 3, max = 15, step = 1,
      label = L["Damage-restart gap (s)"], default = D.restartGap,
      tooltip = L["Your damage going quiet for this long after the buzzer, then landing again, flags the run as damage restarted. 3 to 15 seconds. Applies to new runs. Saved runs keep the value they were raced with."] },
    { path = "race.hintDelay", page = PAGE, group = SCORING, type = "number", min = 5, max = 60, step = 1,
      label = L["Sticky-combat hint after (s)"], default = D.hintDelay,
      tooltip = L["How long combat may hold after the buzzer before the HUD suggests ways to drop it."],
      startsLine = true },
})

NS.RegisterTabbedPage({
    key             = PAGE,
    title           = L["Race"],
    panelName       = "DpsRaceRacePanel",
    defaultsTooltip = L["Restore every Race setting on this profile to its addon default."],
})
