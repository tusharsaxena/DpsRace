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
        -- LibDBIcon's own table, handed straight to :Register (launcher-§3). Global, because the
        -- button belongs to the installation and a profile switch must not move it.
        minimap = { hide = false },
    },
}
