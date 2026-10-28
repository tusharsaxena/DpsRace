local _, NS = ...
-- settings/Race.lua — the Race page (spec §6.3), one tab along the race's timeline: the default race
-- length, auto-arm on a training dummy (#16), the countdown (cue and center numbers), the buzzer with the sticky-combat hint's delay, and
-- the scoring rules a new run freezes into its own record (grace, restart gap), and the late-cast
-- ignore list (#8), read when a run's flags are. A second tab, Training dummies (#9), holds your own
-- dummies, read when a run's category is.

local L = NS.L
local D = NS.defaults.profile.race
local PAGE = "race"
local RACE, SCORING, DUMMIES = L["Race"], L["Scoring rules"], L["Training dummies"]

-- The race lengths the HUD offers (modules/Hud_States.lua), as a numeric dropdown: "3:00" for 180.
local function lengthValues()
    local out = {}
    for _, n in ipairs(NS.HudStates.PRESETS) do out[#out + 1] = { value = n, text = NS.Format.Length(n) } end
    return out
end

-- The categories a new dummy can get, Automatic first (the dummy list's own, modules/DummyList.lua).
local function categoryValues()
    local out = { { value = "auto", text = L["Automatic"] } }
    for _, k in ipairs(NS.DummyList.KINDS) do out[#out + 1] = { value = k, text = NS.Dummies.Label(k) } end
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

    -- ── Training dummies ── (#9, modules/DummyList.lua) its own tab: the category a new dummy gets,
    -- then the list itself, one plain string written WHOLE through the seam (the ignore list's shape),
    -- read when a run's category is, never frozen into a run. The list row carries skipRender: the tab
    -- draws it as the library's ID lists.
    { path = NS.DummyList.CATEGORY_PATH, page = PAGE, group = DUMMIES, subgroup = L["New dummies"], type = "string",
      label = L["Category for new dummies"], default = D.dummyCategory, values = categoryValues(),
      tooltip = L["The category a dummy you add gets when you name none. Automatic reads it from the name (Cleave, Dungeoneer, PvP) and a boss-level creature, else Single target."] },
    { path = NS.DummyList.PATH, page = PAGE, group = DUMMIES, subgroup = L["Your training dummies"], type = "string",
      label = L["Training dummies"], default = D.dummies, skipRender = true,
      validate = function(v) return NS.DummyList.Parse(v) ~= nil end,
      normalize = function(v) return NS.DummyList.Normalize(v) end,
      tooltip = L["Creatures counted as training dummies beyond the built-in ones, and built-ins switched off: creature ID:category, or -creature ID, comma-separated. Applies to every stored run: a run is categorized by its creature as the list is now."] },
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

-- The Training dummies tab's body (#9, modules/DummyList.lua), after its rows (the category for a new
-- dummy): a blurb, Add your target, the library's ID list over your own dummies (an add box for a
-- creature ID or a captured name, the X takes one off), a checkbox per built-in (off switches it off),
-- then the list's own reset. Nothing here writes a path: DummyList's writes write the whole row.
local DUMMY_KIND = {
    noun = "creature", plural = "creatures",
    resolve = function(text) return NS.DummyList.Resolve(text) end,
    info = function(id) return NS.DummyList.NameOf(id) end,
}

local function ownDummies()
    local out = {}
    for _, e in ipairs(NS.DummyList.Entries()) do
        if not e.hidden then
            out[#out + 1] = { id = e.id, suffix = L["\194\183 %s"]:format(NS.Dummies.Label(e.category)) }
        end
    end
    return out
end

-- The built-ins, ascending by creature ID.
local function builtInIds()
    local ids = {}
    for id in pairs(NS.Dummies.BY_ID) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

-- What Add your target says when it adds nothing: no creature to add.
local function addTarget()
    local DL = NS.DummyList
    local r = DL.Read("target")
    if not r then return NS.Print(L["Target a creature first."]) end
    DL.Capture(r)
    DL.Add(r.npcID, DL.CategoryFor(r))
end

local function afterDummies(ctx)
    local H, DL = NS.Helpers, NS.DummyList
    H.TextRow(ctx, L["Creatures a race counts as training dummies, on top of the built-in ones: auto-arm, the HUD and the target type of every stored run follow this list. Target a dummy and click Add your target, or type /dr targetdummy add; either saves what the game says about it."])
    H.InlineButtonPair(ctx, {
        text    = L["Add your target"],
        tooltip = L["Count your target as a training dummy, with the category above, and save what the game says about it (its level, health, zone and where you stand). A built-in that is switched off is switched back on."],
        onClick = addTarget,
    })
    H.IdList(ctx, {
        kind        = DUMMY_KIND,
        label       = L["Add a creature"],
        tooltip     = L["A creature ID, or the name of a creature you captured. It gets the category above."],
        emptyText   = L["No training dummies of your own yet."],
        entries     = ownDummies,
        onAdd       = function(id) DL.Add(id, DL.CategoryFor({ name = DL.NameOf(id) })) end,
        onRemove    = function(id) DL.Remove(id) end,
        removeStyle = "icon",
    })
    H.TextRow(ctx, L["Built-in training dummies. Clear one to stop counting it as a dummy."])
    for _, id in ipairs(builtInIds()) do
        local d = NS.Dummies.BuiltIn(id)
        H.SessionCheckbox(ctx, nil, 1, {
            label   = L["%s (%d) \194\183 %s"]:format(d.name, id, NS.Dummies.Label(d.category)),
            tooltip = L["Count this built-in as a training dummy. Cleared, its runs read as Other."],
            get     = function() return NS.Dummies.Lookup(id) ~= nil end,
            set     = function(on) if on then DL.Add(id) else DL.Remove(id) end end,
        })
    end
    H.InlineButtonPair(ctx, {
        text    = L["Reset list"],
        tooltip = L["Remove your own training dummies and switch every built-in back on. The category for new dummies is not touched."],
        onClick = function() DL.Reset() end,
    })
end

NS.RegisterTabbedPage({
    key             = PAGE,
    title           = L["Race"],
    panelName       = "DpsRaceRacePanel",
    defaultsTooltip = L["Restore every Race setting on this profile to its addon default, the late-cast ignore list and your training dummies among them."],
    afterGroup      = { [RACE] = afterRace, [DUMMIES] = afterDummies },
})

-- The lists repaint when they change from anywhere (the HUD's right-click, `/dr ignore`,
-- `/dr targetdummy`, `/dr set` or `reset`) and when the profile does (another profile, another list; core/Database.lua announces
-- it as "profile"). A hidden page is only flagged, and repaints on its next show (RefreshPanel).
local function repaint()
    local ctx = NS.pageCtx[PAGE]
    if ctx and NS.Helpers.RefreshPanel then NS.Helpers.RefreshPanel(ctx, true) end
end

do
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path)
            if path == NS.LateIgnore.PATH or path == NS.DummyList.PATH or path == "profile" then repaint() end
        end)
    end
end
