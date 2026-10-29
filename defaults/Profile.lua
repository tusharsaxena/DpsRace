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
        -- The race's settings; their rows are on the Race page (settings/Race.lua). The two scoring
        -- settings first: a new run freezes them into its own record (modules/Recorder.lua NewRun),
        -- so changing one never re-grades a saved run (spec §5.2).
        race = {
            grace      = 1.0,   -- s after the buzzer before a cast start is late (spec §5.2)
            restartGap = 6,     -- s of quiet after the buzzer before damage counts as restarted (§5.3)
            -- The late-cast ignore list (#8, modules/LateIgnore.lua): the exception. It is read when a
            -- run's flags are, never frozen into a run, so a change re-scores every stored run. Spell
            -- IDs, ascending and comma-separated; 8690 stands for every hearthstone
            -- (defaults/Hearthstones.lua). Invisibility, Vanish, Feign Death, Hearthstone,
            -- Shadowmeld, Greater Invisibility.
            lateIgnore = "66,1856,5384,8690,58984,110959",
            -- Your training dummies (#9, modules/DummyList.lua): read when a run's category is, never
            -- frozen into a run, so a change recategorizes every stored run. Entries ascending by creature
            -- ID, comma-separated: "243300:cleave" marks a creature as a dummy, "-243205" switches a
            -- built-in (defaults/Dummies.lua) off.
            dummies       = "",
            -- The category a new dummy gets when none is typed: "auto" reads it from the name and
            -- classification, else single | cleave | dungeoneer | boss | pvp.
            dummyCategory = "auto",
            -- The Race HUD's own (modules/Hud.lua); their rows are on the Race page too.
            defaultLength = 120,   -- s; the idle body's length until the player picks one (§4.1)
            countdownCue  = true,  -- the sound at 10, 5, 3, 2, 1 s left, and each center number (§4.3)
            centerCountdown = true, -- the center-screen numbers in the last seconds (modules/Countdown.lua)
            finalCountdown  = 10,   -- s left when the numbers start, 3-10
            buzzer        = true,  -- the raid-warning STOP and its sound at the buzzer (§4.4)
            hintDelay     = 15,    -- s in combat after the buzzer before the drop-combat hint (§4.4)
            -- Auto-arm (#16, modules/AutoArm.lua): targeting a cataloged training dummy out of combat
            -- arms a race at the length Arm Race would; targeting anything else before the pull
            -- cancels it. Opt-in (the owner's call, 2026-10-28).
            autoArm       = false,
            -- `lastLength` (no default): the last length picked on the HUD, remembered (§4.1). It is
            -- state the HUD writes, not a setting row.
        },
        -- The live breakdown (spec §6.3; its rows are HUD > Race HUD > Live breakdown,
        -- settings/Hud.lua).
        live = {
            rows    = 8,      -- spells shown, 1-15; 0 = every spell, wheel-scrolled
            icons   = true,   -- spell icons
            showDps = true,   -- Blizzard's live DPS figure, labeled live
            hz      = 4,      -- live reads per second, 2-10 (spec §10)
            -- The running body's damage chart (#2) and pace bar (#3), each on HUD > Race HUD > Chart
            -- and pace (settings/Hud.lua); both hide on a shared session, the pace bar with no best.
            chart   = true,
            paceBar = true,
            -- The ability's icon along the top of the chart at each cast of one whose base cooldown is 29 s
            -- or more (#14), *Show cooldown icons*: live, on the result card and in the Results detail
            -- (modules/Hud_Chart.lua). The path keeps the first look's name (dots, 2026-10-26).
            castDots = true,
            -- How far either side of the best's pace so far the pace bar reaches, 1.1-2.0: it runs from
            -- pace x (2 - paceRange) to pace x paceRange, its tick in the middle (Round C; 1.5 = +-50%).
            paceRange = 1.5,
        },
        -- The HUD's show mode (spec §6.3): "onArm" | "always"; and what its running clock shows (spec
        -- §6.1): "both" (elapsed in green beside time left in red) | "left" | "elapsed". `autoShow`
        -- (#16, modules/AutoArm.lua): the HUD opens by itself near a cataloged training dummy, opt-in
        -- (the owner's call, 2026-10-28). All three rows are on the HUD page's Race HUD tab
        -- (settings/Hud.lua).
        hud = { showMode = "onArm", clock = "both", autoShow = false },
        -- The HUD's look (the owner's call, 2026-10-24; HUD > HUD Appearance, settings/Hud.lua,
        -- applied by modules/Hud_Appearance.lua). Each block is a composed group (options-ui-§16), so
        -- its keys are the composer's leaves. The defaults ARE the look shipped before the tab existed:
        -- the clocks in the debug console's monospace face, the figures and the spell rows in Blizzard's
        -- GameFontNormalHuge and GameFontHighlightSmall, the bars flat in the window's indigo.
        --
        -- FOLLOWING THE SKIN (skinning-§6, DR-03). Each face and texture but the two clocks' has the
        -- composer's "Use the skin's ..." companion beside it (`fontFromSkin`, `barTextureFromSkin`),
        -- default ON (X3) so a new or reset profile follows the skin the way an adopted one does after
        -- the v6 reset (core/Database.lua): the skin's `hud.font` and `bar.texture`, the stored pick
        -- kept for when the player turns it off (modules/Hud_Appearance.lua). Only the face and the
        -- texture follow (X4): sizes, flags, shadows and colors stay the player's. The clocks keep
        -- their monospace face and have no companion (D-15): their layout assumes a fixed advance.
        appearance = {
            -- The running clock pair. `fontSize` is the pair's; a clock shown alone draws half again
            -- as large (modules/Hud_States.lua).
            elapsed = { font = "JetBrains Mono", fontSize = 26, fontColor = { r = 0.36, g = 0.86, b = 0.46, a = 1 },
                        useClassColorFont = false, fontFlags = "", fontShadow = false },
            left    = { font = "JetBrains Mono", fontSize = 26, fontColor = { r = 1.0, g = 0.32, b = 0.32, a = 1 },
                        useClassColorFont = false, fontFlags = "", fontShadow = false },
            -- The running body's Damage and DPS live figures.
            figures = { font = "Friz Quadrata TT", fontSize = 20, fontColor = { r = 0.93, g = 0.93, b = 0.95, a = 1 },
                        useClassColorFont = false, fontFlags = "", fontShadow = true, fontFromSkin = true },
            -- The spell rows: the HUD's live and result lists and the Results window's breakdown.
            bars = { barTexture = "Solid", barAlpha = 0.85, barColor = { r = 0.29, g = 0.29, b = 0.45, a = 1 },
                     useClassColorBar = false, rowHeight = 18, barTextureFromSkin = true },
            spellText = { font = "Friz Quadrata TT", fontSize = 10, fontColor = { r = 1, g = 1, b = 1, a = 1 },
                          useClassColorFont = false, fontFlags = "", fontShadow = true, fontFromSkin = true },
            -- The damage chart (modules/Hud_Chart.lua): its columns' fill (the mockup's brighter
            -- indigo), the plot's height in pixels, the gap between two columns in pixels (0: one
            -- smooth area), and the plot's background swatch (its composed class-color companion
            -- beside it, options-ui-§17).
            chart = { barTexture = "Solid", barAlpha = 0.9, barColor = { r = 0.36, g = 0.37, b = 0.84, a = 1 },
                      useClassColorBar = false, height = 80, columnGap = 0,
                      bgColor = { r = 0, g = 0, b = 0, a = 0.35 }, useClassColorBg = false,
                      barTextureFromSkin = true },
            -- The pace bar's fill, its own block since 2026-10-25: the chart's look when it was split off.
            pace = { barTexture = "Solid", barAlpha = 0.9, barColor = { r = 0.36, g = 0.37, b = 0.84, a = 1 },
                     useClassColorBar = false, barTextureFromSkin = true },
        },
        -- The Results window's Runs list (History > Results table, settings/History.lua): the Damage
        -- and DPS cells' bars and their text, over the rows' own stripe. Composed groups (options-ui-§16);
        -- each class color is the run's own character's (the row describes that character). The fill is
        -- the spell breakdown's (appearance.bars): its indigo on both bars. The three blocks are HUD style
        -- for the one-time reset (D-16): each face and texture has its "Use the skin's ..." companion,
        -- default on, as the HUD's blocks have.
        resultsTable = {
            damageBar = { barTexture = "Solid", barAlpha = 0.85, barColor = { r = 0.29, g = 0.29, b = 0.45, a = 1 },
                          useClassColorBar = false, barTextureFromSkin = true },
            dpsBar    = { barTexture = "Solid", barAlpha = 0.85, barColor = { r = 0.29, g = 0.29, b = 0.45, a = 1 },
                          useClassColorBar = false, barTextureFromSkin = true },
            barText   = { font = "Friz Quadrata TT", fontSize = 10, fontColor = { r = 1, g = 1, b = 1, a = 1 },
                          useClassColorFont = false, fontFlags = "", fontShadow = true, fontFromSkin = true },
        },
        -- Share (modules/Share.lua): `talentsLink` appends the run's talentbuild link to the shared
        -- line (#6). Off: the line stays the one line it always was (the owner's call, 2026-10-25).
        -- Its row is History > History > Sharing (settings/History.lua).
        share = { talentsLink = false },
        -- The new-best toast (#5, modules/BestToast.lua; General > New-best toast, settings/General.lua):
        -- on, 8 s on screen (LibKa0s-Toast-1.0's own DURATION), with its sound, at scale 1. `point`
        -- (no default): where test mode's drag put it, { point, relativePoint, x, y } in UIParent's
        -- units, written by the shell's drag stop; absent, the shell's own place under the top.
        toast = { enabled = true, duration = 8, sound = true, scale = 1.0 },
        -- The skin this addon wears (skinning-§2: per addon, per profile; core/SkinSetup.lua), on
        -- General > Skin (settings/General.lua): the source and the skin, Ka0s Default by default; the
        -- Scope's two exceptions (the settings panel left the client's, the fonts skinned); the font
        -- and texture overrides, an LSM key each, "" for the skin's own; and `pickerSeen`, false on
        -- every profile, old and new (owner ruling O3), so the first-run skin picker shows once.
        skin = { source = "ka0s", skin = "ka0s", ignorePanel = true, ignoreFonts = false,
                 font = "", texture = "", pickerSeen = false },
        -- Window geometry (standalone-windows): each window's size; its position is written when
        -- moved. The Results window follows Master scale like the HUD. A new profile (and /dr resetall)
        -- opens each window at its minimum width (the owner's call, 2026-10-26): Hud.MIN_WIDTH and
        -- Results.VIEWS[view].minWidth, pinned equal by tests/test_schema.lua.
        windows = {
            -- Tall enough for all 8 live rows under the Damage profile heading (the pace bar and the
            -- damage chart, screen 04, #2) and the Spell breakdown heading (520 before Round C; 560
            -- before the chart's icon row on top, UT-P11). 300 wide before 2026-10-26.
            hud = { width = 260, height = 573 },
            -- The Results window's two views (the owner's call, 2026-10-25): expanded (the detail beside
            -- the list) and collapsed (the list alone), the default (UT-P14, 2026-10-27; expanded before).
            -- Each keeps its own size; only the title bar's toggle switches them.
            -- 1340 and 980 wide before 2026-10-26 (1220 and 900 before the Note column, 2026-10-25).
            -- `collapsedSections` (UT-P10): the run detail's folded sections, each Detail.SECTIONS key
            -- set to true (modules/Results_Detail.lua); empty, every section open. Not geometry: Reset
            -- position keeps it; a profile reset and Reset all settings clear it.
            results = { view = "collapsed", expanded = { width = 1344, height = 560 },
                        collapsed = { width = 904, height = 560 }, collapsedSections = {} },
            -- No `timeline`: the ability timeline (#14, modules/Results_Timeline.lua) opens over the
            -- Results window at its place and size every time and stores nothing (UT-P14; 980x560 and
            -- its position were stored before).
        },
    },
    global = {
        -- 0, never the current version: AceDB strips a value equal to its default at logout and
        -- would backfill it onto a legacy account (savedvariables-§1).
        schemaVersion = 0,
        -- The run record format (spec §7). Not a migration stamp: a stored run carries its own copy.
        -- Format 2 (#6) adds the run's loadout keys; format 3 (#13, #14) its casts and usage; format 4
        -- (#17) its stats.
        schema = 4,
        -- The run store, keyed by run id (modules/Recorder.lua). Global: a run belongs to the
        -- installation, and a profile switch must not hide a character's history.
        runs = {},
        -- The loadout store (#6, modules/Loadouts.lua): each distinct gear set and talent loadout once,
        -- by its hash; a run holds only the keys (run.loadout). Orphans go with every removal.
        loadouts = { gear = {}, talents = {} },
        -- Days to keep (spec §6.3; the owner's call, 2026-10-26): runs older than this many days are
        -- pruned, 0 = never, and a run holding a best is always kept (modules/Recorder.lua Prune).
        -- Global like the store it bounds. Its row is the History page's (settings/History.lua).
        history = { keepDays = 90 },
        -- The items the Usage lists never show (P9, modules/Usage.lua): item IDs as one plain string,
        -- "12345,67890". Global like the run store it filters. Its row is the History page's Usage tab.
        usage = { hidden = "" },
        -- What the game said about each creature `/dr targetdummy` captured (#9, modules/DummyList.lua),
        -- by creature ID: data, not a setting, global because a creature is the same on every profile.
        dummies = { captures = {} },
        -- LibDBIcon's own table, handed straight to :Register (launcher-§3). Global, because the
        -- button belongs to the installation and a profile switch must not move it.
        minimap = { hide = false },
    },
}
