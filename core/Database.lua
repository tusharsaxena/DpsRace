local addonName, NS = ...
-- core/Database.lua — AceDB setup, the profile callbacks and the schemaVersion migration runner.

-- The runner's target: the highest step's `to` (savedvariables-§1). Distinct from
-- `global.schema`, which is the RUN RECORD format version (spec §7) and never migrates settings.
NS.SCHEMA_VERSION = 4

-- Each step is idempotent against a fresh default profile. A profile-scoped step sets
-- `perProfile = true` and runs once for every stored profile.
local STEPS = {
    { to = 1, run = function() end },   -- 0 -> 1: pre-versioning, a no-op
    -- 1 -> 2: the run record's format 2 (#6) adds run.loadout, which a format-1 run is simply
    -- without, so no stored run is rewritten (each keeps its own `schema = 1`). Only the format stamp
    -- moves: a stored 1 would outlive the new default, since AceDB never overwrites a stored value.
    { to = 2, run = function(sv)
        local g = type(sv) == "table" and sv.global
        if type(g) == "table" and type(g.schema) == "number" and g.schema < 2 then g.schema = 2 end
    end },
    -- 2 -> 3: the run record's format 3 (#13, #14) adds run.casts and run.usage, which an older run is
    -- simply without (it reads as not recorded), so again only the format stamp moves.
    { to = 3, run = function(sv)
        local g = type(sv) == "table" and sv.global
        if type(g) == "table" and type(g.schema) == "number" and g.schema < 3 then g.schema = 3 end
    end },
    -- 3 -> 4 (UT-P14): the Results window's default view moved from expanded to collapsed. AceDB strips
    -- a value equal to its default, so a profile left in the old default stores no `view` and would
    -- read the new one: write the expanded view it was in. A profile that never stored the Results
    -- window keeps the new default. The ability timeline no longer stores its place, so drop it.
    { to = 4, perProfile = true, run = function(_sv, profile)
        local w = type(profile) == "table" and profile.windows
        if type(w) ~= "table" then return end
        if type(w.results) == "table" and w.results.view == nil then w.results.view = "expanded" end
        w.timeline = nil
    end },
}
NS.__migrationSteps = STEPS   -- test seam only

--- A profile switch, copy or reset replaces the whole profile wholesale: the stored `enabled` can
--- flip, the visibility rule can change, so re-take the hold and re-decide (slash-commands-§7: these
--- callbacks are SETUP and stay live while disabled). One line per act (debug-logging-§10).
function NS.OnProfileChanged(event, _db, key)
    NS.Debug("Set", "%s '%s'", event or "profile", key or (NS.db and NS.db:GetCurrentProfile()) or "?")
    NS.SyncEnabledHold()
    if NS.OnVisibilityChanged then NS.OnVisibilityChanged() end
    -- Announced through settings/Schema.lua, the message's one sender.
    if NS.AnnounceSettingsChanged then NS.AnnounceSettingsChanged("profile", key) end
end

function NS:InitDB()
    NS.db = LibStub("AceDB-3.0"):New(addonName .. "DB", NS.defaults, true)
    local db = NS.db
    if db.RegisterCallback then
        db.RegisterCallback(NS, "OnProfileChanged", function(event, d, key) NS.OnProfileChanged(event, d, key) end)
        db.RegisterCallback(NS, "OnProfileCopied", function(event, d, key) NS.OnProfileChanged(event, d, key) end)
        db.RegisterCallback(NS, "OnProfileReset", function(event, d) NS.OnProfileChanged(event, d) end)
    end
end

function NS:RunMigrations()
    local db = NS.db
    local g, sv = db.global, _G[addonName .. "DB"]
    for _, step in ipairs(STEPS) do
        if (g.schemaVersion or 0) < step.to then
            if step.perProfile then
                for _, profile in pairs(sv and sv.profiles or {}) do step.run(sv, profile) end
            else
                step.run(sv)
            end
            -- The runner owns the stamp; reached only if the step returned.
            g.schemaVersion = step.to
        end
    end
end
