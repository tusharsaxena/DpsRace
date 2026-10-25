local _, NS = ...
-- defaults/Profile.lua — the AceDB defaults tree: the only place a default is hardcoded
-- (savedvariables-§2). Every schema row's `default` reads from here.

NS.defaults = {
    profile = {
        -- Master controls (settings/General.lua). The debug flag is NOT here: it is session-only
        -- (NS.State.debug, debug-logging-§5), as is test mode.
        enabled    = true,
        visibility = "always",   -- always | inCombat | outOfCombat | never
        scale      = 1.0,
        locked     = false,
        -- The scoring settings a new run freezes into its own record (modules/Recorder.lua NewRun):
        -- changing one never re-grades a saved run (spec §5.2). Their rows are on the Race page
        -- (settings/Race.lua).
        race = {
            grace      = 1.0,   -- s after the buzzer before a cast start is late (spec §5.2)
            restartGap = 6,     -- s of quiet after the buzzer before damage counts as restarted (§5.3)
            -- The Race HUD's own (modules/Hud.lua); their rows are on the Race page too.
            defaultLength = 180,   -- s; the idle body's length until the player picks one (§4.1)
            countdownCue  = true,  -- the sound at 10, 5, 3, 2, 1 s left, and each center number (§4.3)
            centerCountdown = true, -- the center-screen numbers in the last seconds (modules/Countdown.lua)
            finalCountdown  = 10,   -- s left when the numbers start, 3-10
            buzzer        = true,  -- the raid-warning STOP and its sound at the buzzer (§4.4)
            hintDelay     = 15,    -- s in combat after the buzzer before the drop-combat hint (§4.4)
            -- `lastLength` (no default): the last length picked on the HUD, remembered (§4.1). It is
            -- state the HUD writes, not a setting row.
        },
        -- The live breakdown (spec §6.3; its rows are General > Race HUD > Live breakdown,
        -- settings/General.lua).
        live = {
            rows    = 8,      -- spells shown, 1-15; 0 = every spell, wheel-scrolled
            icons   = true,   -- spell icons
            showDps = true,   -- Blizzard's live DPS figure, labeled live
            hz      = 4,      -- live reads per second, 2-10 (spec §10)
            -- The running body's damage chart (#2) and pace bar (#3), each on HUD > Race HUD > Chart
            -- and pace (settings/Hud.lua); both hide on a shared session, the pace bar with no best.
            chart   = true,
            paceBar = true,
            -- How far either side of the best's pace so far the pace bar reaches, 1.1-2.0: it runs from
            -- pace x (2 - paceRange) to pace x paceRange, its tick in the middle (Round C; 1.5 = +-50%).
            paceRange = 1.5,
        },
        -- The HUD's show mode (spec §6.3): "onArm" | "always"; and what its running clock shows (spec
        -- §6.1): "both" (elapsed in green beside time left in red) | "left" | "elapsed". Both rows are
        -- on General's Race HUD tab.
        hud = { showMode = "onArm", clock = "both" },
        -- The HUD's look (the owner's call, 2026-10-24; General > HUD Appearance, settings/General.lua,
        -- applied by modules/Hud_Appearance.lua). Each block is a composed group (options-ui-§16), so
        -- its keys are the composer's leaves. The defaults ARE the look shipped before the tab existed:
        -- the clocks in the debug console's monospace face, the figures and the spell rows in Blizzard's
        -- GameFontNormalHuge and GameFontHighlightSmall, the bars flat in the window's indigo.
        appearance = {
            -- The running clock pair. `fontSize` is the pair's; a clock shown alone draws half again
            -- as large (modules/Hud_States.lua).
            elapsed = { font = "JetBrains Mono", fontSize = 26, fontColor = { r = 0.36, g = 0.86, b = 0.46, a = 1 },
                        useClassColorFont = false, fontFlags = "", fontShadow = false },
            left    = { font = "JetBrains Mono", fontSize = 26, fontColor = { r = 1.0, g = 0.32, b = 0.32, a = 1 },
                        useClassColorFont = false, fontFlags = "", fontShadow = false },
            -- The running body's Damage and DPS live figures.
            figures = { font = "Friz Quadrata TT", fontSize = 20, fontColor = { r = 0.93, g = 0.93, b = 0.95, a = 1 },
                        useClassColorFont = false, fontFlags = "", fontShadow = true },
            -- The spell rows: the HUD's live and result lists and the Results window's breakdown.
            bars = { barTexture = "Solid", barAlpha = 0.85, barColor = { r = 0.29, g = 0.29, b = 0.45, a = 1 },
                     useClassColorBar = false, rowHeight = 18 },
            spellText = { font = "Friz Quadrata TT", fontSize = 10, fontColor = { r = 1, g = 1, b = 1, a = 1 },
                          useClassColorFont = false, fontFlags = "", fontShadow = true },
            -- The damage chart (modules/Hud_Chart.lua): its columns' fill (the mockup's brighter
            -- indigo), the plot's height in pixels, the gap between two columns in pixels (0: one
            -- smooth area), and the plot's background swatch (its composed class-color companion
            -- beside it, options-ui-§17).
            chart = { barTexture = "Solid", barAlpha = 0.9, barColor = { r = 0.36, g = 0.37, b = 0.84, a = 1 },
                      useClassColorBar = false, height = 80, columnGap = 0,
                      bgColor = { r = 0, g = 0, b = 0, a = 0.35 }, useClassColorBg = false },
            -- The pace bar's fill, its own block since 2026-10-25: the chart's look when it was split off.
            pace = { barTexture = "Solid", barAlpha = 0.9, barColor = { r = 0.36, g = 0.37, b = 0.84, a = 1 },
                     useClassColorBar = false },
        },
        -- The Results window's Runs list (History > Results table, settings/History.lua): the Damage
        -- and DPS cells' bars and their text, over the rows' own stripe. Composed groups (options-ui-§16);
        -- each class color is the run's own character's (the row describes that character). The fill is
        -- the spell breakdown's (appearance.bars): its indigo on both bars.
        resultsTable = {
            damageBar = { barTexture = "Solid", barAlpha = 0.85, barColor = { r = 0.29, g = 0.29, b = 0.45, a = 1 },
                          useClassColorBar = false },
            dpsBar    = { barTexture = "Solid", barAlpha = 0.85, barColor = { r = 0.29, g = 0.29, b = 0.45, a = 1 },
                          useClassColorBar = false },
            barText   = { font = "Friz Quadrata TT", fontSize = 10, fontColor = { r = 1, g = 1, b = 1, a = 1 },
                          useClassColorFont = false, fontFlags = "", fontShadow = true },
        },
        -- Share (modules/Share.lua): `talentsLink` appends the run's talentbuild link to the shared
        -- line (#6). Off: the line stays the one line it always was (the owner's call, 2026-10-25).
        -- Its row is History > History > Sharing (settings/History.lua).
        share = { talentsLink = false },
        -- Window geometry (standalone-windows): each window's size; its position is written when
        -- moved. The Results window follows Master scale like the HUD.
        windows = {
            -- Tall enough for all 8 live rows under the Damage profile heading (the pace bar and the
            -- damage chart, screen 04, #2) and the Spell breakdown heading (520 before Round C).
            hud = { width = 300, height = 560 },
            -- The Results window's two views (the owner's call, 2026-10-25): expanded (the detail beside
            -- the list), the default, and collapsed (the list alone). Each keeps its own size; only
            -- the title bar's toggle switches them.
            -- Widened for the Note column (2026-10-25): 1220 and 900 before it.
            results = { view = "expanded", expanded = { width = 1340, height = 560 },
                        collapsed = { width = 980, height = 560 } },
        },
    },
    global = {
        -- 0, never the current version: AceDB strips a value equal to its default at logout and
        -- would backfill it onto a legacy account (savedvariables-§1).
        schemaVersion = 0,
        -- The run record format (spec §7). Not a migration stamp: a stored run carries its own copy.
        -- Format 2 (#6) adds the run's loadout keys.
        schema = 2,
        -- The run store, keyed by run id (modules/Recorder.lua). Global: a run belongs to the
        -- installation, and a profile switch must not hide a character's history.
        runs = {},
        -- The loadout store (#6, modules/Loadouts.lua): each distinct gear set and talent loadout once,
        -- by its hash; a run holds only the keys (run.loadout). Orphans go with every removal.
        loadouts = { gear = {}, talents = {} },
        -- Runs to keep (spec §6.3): 0 = never prune. Above 0, the oldest runs go first and a run
        -- holding a best is always kept (modules/Recorder.lua Prune). Global like the store it
        -- bounds. Its row is the History page's (settings/History.lua).
        history = { keep = 0 },
        -- LibDBIcon's own table, handed straight to :Register (launcher-§3). Global, because the
        -- button belongs to the installation and a profile switch must not move it.
        minimap = { hide = false },
    },
}
