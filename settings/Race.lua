local _, NS = ...
-- settings/Race.lua — the Race page (spec §6.3), one tab along the race's timeline: the default race
-- length, auto-arm on a training dummy (#16), the countdown (cue and center numbers), the buzzer with the sticky-combat hint's delay, and
-- the scoring rules a new run freezes into its own record (grace, restart gap), and the late-cast
-- ignore list (#8), read when a run's flags are.

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
    -- One tab, its subsections in the order of a race: Length, Countdown, At the buzzer, then the
    -- Scoring rules a run freezes into its record.
    { path = "race.defaultLength", page = PAGE, group = RACE, subgroup = L["Length"], type = "number",
      label = L["Default race length"], default = D.defaultLength, values = lengthValues(),
      tooltip = L["The race length the HUD offers until you pick another. The last length you pick is remembered until you change this."],
      onChange = newDefault },
    -- ── Auto-arm ── (#16, modules/AutoArm.lua) before the race, at the length above.
    { path = "race.autoArm", page = PAGE, group = RACE, subgroup = L["Auto-arm"], type = "bool",
      label = L["Arm on a training dummy"], default = D.autoArm,
      tooltip = L["Arm a race by itself when you target a known training dummy out of combat, at the length Arm Race would use; your first hit starts it. Targeting anything else (or nothing) before the pull cancels it. Nothing arms in combat, in instances, over a result, or while a run waits for its result."],
      onChange = function() NS.AutoArm.Sync() end },
    -- ── Countdown ── the cue first, alone on its line (it fires from 10 s whatever the center
    -- numbers do), then the center numbers and where they start.
    { path = "race.countdownCue", page = PAGE, group = RACE, subgroup = L["Countdown"], type = "bool",
      label = L["Countdown cue sound"], default = D.countdownCue,
      tooltip = L["A sound at 10, 5, 3, 2 and 1 seconds left, and with each number of the center countdown. Takes effect at once, in the race in progress too."],
      onChange = rearm, startsLine = true },
    { path = "race.centerCountdown", page = PAGE, group = RACE, subgroup = L["Countdown"], type = "bool",
      label = L["Center-screen countdown"], default = D.centerCountdown,
      tooltip = L["Large numbers in the middle of the screen for the last seconds of the race, one a second down to 1, like a pull timer. Only you see them."],
      onChange = rearm, startsLine = true },
    { path = "race.finalCountdown", page = PAGE, group = RACE, subgroup = L["Countdown"], type = "number",
      min = 3, max = 10, step = 1, label = L["Center countdown from (seconds)"], default = D.finalCountdown,
      tooltip = L["How many seconds before the buzzer the center countdown starts. 3 to 10."],
      onChange = rearm },

    -- ── At the buzzer ── the race's end: the raid warning, and the sticky-combat hint after it
    -- (not a scoring rule: it is never frozen into a run).
    { path = "race.buzzer", page = PAGE, group = RACE, subgroup = L["At the buzzer"], type = "bool",
      label = L["Buzzer raid warning and sound"], default = D.buzzer,
      tooltip = L["A raid warning that says STOP, with a sound, the moment the race ends."] },
    { path = "race.hintDelay", page = PAGE, group = RACE, subgroup = L["At the buzzer"], type = "number",
      min = 5, max = 60, step = 1,
      label = L["Sticky-combat hint after (seconds)"], default = D.hintDelay,
      tooltip = L["How long combat may hold after the buzzer before the HUD suggests ways to drop it. 5 to 60 seconds."] },

    -- ── Scoring rules ── (spec §5.2, §5.3: a run keeps the values it was raced with)
    { path = "race.grace", page = PAGE, group = RACE, subgroup = SCORING, type = "number",
      min = 0, max = 5, step = 0.1,
      label = L["Late-cast grace (seconds)"], default = D.grace,
      tooltip = L["A cast that starts later than this after the buzzer flags the run. 0 to 5 seconds. Applies to new runs. Saved runs keep the value they were raced with."] },
    { path = "race.restartGap", page = PAGE, group = RACE, subgroup = SCORING, type = "number",
      min = 3, max = 15, step = 1,
      label = L["Damage-restart gap (seconds)"], default = D.restartGap,
      tooltip = L["Your damage going quiet for this long after the buzzer, then landing again, flags the run as damage restarted. 3 to 15 seconds. Applies to new runs. Saved runs keep the value they were raced with."] },

    -- ── Late-cast ignore list ── (#8, modules/LateIgnore.lua) read when a run's flags are, never
    -- frozen into a run. One plain string of spell IDs written WHOLE through the seam (the Usage tab's
    -- hidden items' shape, settings/History.lua), so the CLI's get/set/reset and the page's Defaults
    -- reach it like any row. The row carries skipRender: the tab draws it as the library's ID list.
    { path = NS.LateIgnore.PATH, page = PAGE, group = RACE, subgroup = L["Late-cast ignore list"], type = "string",
      label = L["Late-cast ignore list"], default = D.lateIgnore, skipRender = true,
      validate = function(v) return NS.LateIgnore.Parse(v) ~= nil end,
      normalize = function(v) return NS.LateIgnore.Normalize(v) end,
      tooltip = L["Spell IDs, comma-separated, whose casts after the grace never flag a run. Applies to every stored run: a run keeps its casts, so taking a spell off the list flags them again. Unlike the grace, nothing is frozen into a run. 8690 stands for every hearthstone."] },
})

-- The Late-cast ignore list's body, after the tab's rows (its heading is the row's subgroup, drawn
-- just above): a blurb, the library's ID list (an add box over one line per listed spell, each with
-- its X), then the list's own reset. The widget never writes: LateIgnore.Ignore, Unignore and Reset
-- write the whole value. 8690 is one entry that stands for every hearthstone, so its line says so.
local SPELL_KIND = { base = "spell", resolve = NS.LateIgnore.Resolve }

local function ignoreEntries()
    local LI, out = NS.LateIgnore, {}
    local suffix = L["(all hearthstones, %d)"]:format(#(NS.HEARTHSTONE_SPELLS or {}))
    for i, id in ipairs(LI.List()) do
        out[i] = { id = id, suffix = id == LI.HEARTHSTONE and suffix or nil }
    end
    return out
end

local function afterRace(ctx)
    local H, LI = NS.Helpers, NS.LateIgnore
    H.TextRow(ctx, L["Spells whose casts after the grace never flag a run, on every stored run. Taking one off flags its casts again. A right-click on a late-cast flag, on the HUD's result or in a run's detail, adds or removes its spell too."])
    H.IdList(ctx, {
        kind        = SPELL_KIND,
        label       = L["Ignore a spell"],
        tooltip     = L["A spell ID, a shift-clicked spell link, or the name of a spell a run cast late. \"Hearthstone\" adds every hearthstone."],
        emptyText   = L["No spell is ignored: every late cast flags its run."],
        entries     = ignoreEntries,
        candidates  = function() return LI.KnownSpells() end,
        onAdd       = function(id) LI.Ignore(id) end,
        onRemove    = function(id) LI.Unignore(id) end,
        removeStyle = "icon",
        columns     = 2,
    })
    -- The page's Defaults resets the grace, the restart gap and every other Race row with the list;
    -- this resets the list alone, in the one write `/dr reset race.lateIgnore` makes.
    H.InlineButtonPair(ctx, {
        text    = L["Reset list"],
        tooltip = L["Put the list back to its six defaults: Invisibility, Vanish, Feign Death, every hearthstone, Shadowmeld and Greater Invisibility. The other Race settings are not touched."],
        onClick = function() LI.Reset() end,
    })
end

NS.RegisterTabbedPage({
    key             = PAGE,
    title           = L["Race"],
    panelName       = "DpsRaceRacePanel",
    defaultsTooltip = L["Restore every Race setting on this profile to its addon default, the late-cast ignore list among them."],
    afterGroup      = { [RACE] = afterRace },
})

-- The list repaints when it changes from anywhere (the HUD's right-click, `/dr ignore`, `/dr set` or
-- `reset`) and when the profile does (another profile, another list; core/Database.lua announces
-- it as "profile"). A hidden page is only flagged, and repaints on its next show (RefreshPanel).
local function repaint()
    local ctx = NS.pageCtx[PAGE]
    if ctx and NS.Helpers.RefreshPanel then NS.Helpers.RefreshPanel(ctx, true) end
end

do
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path)
            if path == NS.LateIgnore.PATH or path == "profile" then repaint() end
        end)
    end
end
