local addonName, NS = ...
-- core/Database.lua — AceDB setup, the profile callbacks and the schemaVersion migration runner.

-- The runner's target: the highest step's `to` (savedvariables-§1). Distinct from
-- `global.schema`, which is the RUN RECORD format version (spec §7) and never migrates settings.
NS.SCHEMA_VERSION = 6

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
    -- 4 -> 5: the run record's format 4 (#17) adds run.stats, which an older run is simply without
    -- (the gear view shows dashes), so only the format stamp moves.
    { to = 5, run = function(sv)
        local g = type(sv) == "table" and sv.global
        if type(g) == "table" and type(g.schema) == "number" and g.schema < 4 then g.schema = 4 end
    end },
    -- 5 -> 6: the one-time reset onto the skin (skinning-§6, the owner's ruling O2), per profile.
    -- Every HUD and Results table face and texture follows the skin again, once, for every player:
    -- each stored "Use the skin's ..." companion (modules/Hud_Appearance.lua's FROM_SKIN_KEYS) is set
    -- back on through LibKa0s-Skin-1.0's ResetToSkin. The stored picks are kept (a companion off
    -- brings them back) and the colors, sizes, flags and shadows are never touched (X4). The
    -- account-wide stamp is what makes it once: a player who unticks a companion afterwards keeps that
    -- pick, because this step never runs again.
    --
    -- ONLY A STORED COMPANION IS NAMED. The runner hands the RAW profile, which holds only what
    -- differs from the defaults: an absent companion already reads its default, true (X3); and
    -- ResetToSkin, handed a key that is absent, cannot tell it is a bool and writes its "@skin"
    -- sentinel into it. Without the library the companions are set directly: they mean nothing until
    -- it loads, and then they must already say "follow".
    { to = 6, perProfile = true, run = function(_sv, profile)
        if type(profile) ~= "table" then return end
        local A = NS.HudAppearance
        local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)
        local resetToSkin = Skin and type(Skin.ResetToSkin) == "function" and Skin.ResetToSkin
        local keys = {}
        for _, path in ipairs(A and A.FROM_SKIN_KEYS or {}) do
            local block, leaf = path:match("^(.+)%.([^.]+)$")
            local t = profile
            for part in block:gmatch("[^.]+") do t = type(t) == "table" and t[part] or nil end
            if type(t) == "table" and type(t[leaf]) == "boolean" and t[leaf] ~= true then
                keys[#keys + 1] = path
                if not resetToSkin then t[leaf] = true end
            end
        end
        if resetToSkin and #keys > 0 then resetToSkin(profile, keys) end
        if #keys > 0 and NS.Debug then
            NS.Debug("Set", "migrate v6: put %d HUD face(s) and texture(s) back on the skin", #keys)
        end
    end },
}
NS.__migrationSteps = STEPS   -- test seam only

--- A profile switch, copy or reset replaces the whole profile wholesale: the stored `enabled` can
--- flip, the visibility rule can change, so re-take the hold and re-decide (slash-commands-§7: these
--- callbacks are SETUP and stay live while disabled). One line per act (debug-logging-§10).
function NS.OnProfileChanged(event, _db, key)
    NS.Debug("Set", "%s '%s'", event or "profile", key or (NS.db and NS.db:GetCurrentProfile()) or "?")
    -- The first-run skin picker goes down first, unmarked (core/SkinSetup.lua), so a preview it had
    -- pending is put back before the new profile's skin is applied below.
    if NS.HideSkinPicker then NS.HideSkinPicker() end
    -- FIRST, before anything redraws: the new profile's skin (core/SkinSetup.lua). Skin:SetChoice
    -- repaints every recorded frame of this owner and fires OnLooksChanged whether or not a window
    -- was ever built, so the skin cannot depend on one.
    if NS.ApplySkinChoice then NS.ApplySkinChoice() end
    NS.SyncEnabledHold()
    if NS.OnVisibilityChanged then NS.OnVisibilityChanged() end
    -- The first-run skin picker: a new or reset profile starts from the defaults, `pickerSeen` false,
    -- so it shows again over the new profile's skin; one that has seen it stays down. After the
    -- hold, so a profile with the addon switched off shows nothing.
    if NS.MaybeShowSkinPicker then NS.MaybeShowSkinPicker() end
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
