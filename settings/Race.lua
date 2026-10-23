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

-- The race's own reactions: the cue is armed when a race starts running, and the buzzer and the hint
-- read their rows when they fire, so only the HUD's idle body (the length it offers) needs a redraw.
local function redraw() NS.Hud.Refresh() end

NS.RegisterSchemaRows({
    -- ── Race ──
    { path = "race.defaultLength", page = PAGE, group = RACE, subgroup = L["Length"], type = "number",
      label = L["Default race length"], default = D.defaultLength, values = lengthValues(),
      tooltip = L["The race length the HUD offers until you pick another. The last length you raced is remembered."],
      onChange = redraw },
    { path = "race.countdownCue", page = PAGE, group = RACE, subgroup = L["Sounds"], type = "bool",
      label = L["Countdown cue (10, 5, 3, 2, 1)"], default = D.countdownCue,
      tooltip = L["A sound at 10, 5, 3, 2 and 1 seconds left. Takes effect from the next race."],
      startsLine = true },
    { path = "race.buzzer", page = PAGE, group = RACE, subgroup = L["Sounds"], type = "bool",
      label = L["Buzzer raid warning and sound"], default = D.buzzer,
      tooltip = L["A raid warning that says STOP, with a sound, the moment the race ends."] },

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
