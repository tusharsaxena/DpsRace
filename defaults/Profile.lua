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
        -- changing one never re-grades a saved run (spec §5.2). T9 adds their schema rows and the rest
        -- of the Race page's keys.
        race = {
            grace      = 1.0,   -- s after the buzzer before a cast start is late (spec §5.2)
            restartGap = 6,     -- s of quiet after the buzzer before damage counts as restarted (§5.3)
            -- The Race HUD's own (modules/Hud.lua, T7); T9 adds their schema rows.
            defaultLength = 180,   -- s; the idle body's length until the player picks one (§4.1)
            countdownCue  = true,  -- the sound at 10, 5, 3, 2, 1 s left (§4.3)
            buzzer        = true,  -- the raid-warning STOP and its sound at the buzzer (§4.4)
            hintDelay     = 15,    -- s in combat after the buzzer before the drop-combat hint (§4.4)
            -- `lastLength` (no default): the last length picked on the HUD, remembered (§4.1). It is
            -- state the HUD writes, not a setting row.
        },
        -- The live breakdown (spec §6.3 Live breakdown page; T9 adds the rows).
        live = {
            rows    = 8,      -- spells shown, 3-15
            icons   = true,   -- spell icons
            showDps = true,   -- Blizzard's live DPS figure, labeled live
            hz      = 4,      -- live reads per second, 2-10 (spec §10)
        },
        -- The HUD's show mode (spec §6.3 General): "onArm" | "always". T9 adds the row.
        hud = { showMode = "onArm" },
        -- Window geometry (standalone-windows): each window's size; its position is written when
        -- moved. The Results window (T8) follows Master scale like the HUD.
        windows = {
            hud = { width = 300, height = 360 },
            results = { width = 1040, height = 560 },
        },
    },
    global = {
        -- 0, never the current version: AceDB strips a value equal to its default at logout and
        -- would backfill it onto a legacy account (savedvariables-§1).
        schemaVersion = 0,
        -- The run record format (spec §7). Not a migration stamp: a stored run carries its own copy.
        schema = 1,
        -- The run store, keyed by run id (modules/Recorder.lua, T3). Global: a run belongs to the
        -- installation, and a profile switch must not hide a character's history.
        runs = {},
        -- Runs to keep (spec §6.3): 0 = never prune. Above 0, the oldest runs go first and a run
        -- holding a best is always kept (modules/Recorder.lua Prune). Global like the store it
        -- bounds. T9 adds the History page's row.
        history = { keep = 0 },
        -- LibDBIcon's own table, handed straight to :Register (launcher-§3). Global, because the
        -- button belongs to the installation and a profile switch must not move it.
        minimap = { hide = false },
    },
}
