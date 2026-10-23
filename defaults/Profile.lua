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
