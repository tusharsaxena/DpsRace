local addonName, NS = ...
-- core/Database.lua — AceDB setup, the profile callbacks and the schemaVersion migration runner.

-- The runner's target: the highest step's `to` (savedvariables-§1). Distinct from
-- `global.schema`, which is the RUN RECORD format version (spec §7) and never migrates settings.
NS.SCHEMA_VERSION = 11

-- The 7 -> 8 step's facts. The Results detail's spell rows split off `appearance.bars`, so these leaves
-- of a stored block are copied to theirs; and the default fill the three blue blocks had before, for
-- the channels AceDB stripped from a stored swatch.
local SPLIT_LEAVES = { "barTexture", "barTextureFromSkin", "barAlpha", "barColor", "useClassColorBar" }
local OLD_FILL = { r = 0.29, g = 0.29, b = 0.45 }

-- A stored swatch's missing channels, from the fill it was changed from.
local function pinChannels(block)
    local c = type(block) == "table" and block.barColor
    if type(c) ~= "table" then return end
    for channel, v in pairs(OLD_FILL) do
        if c[channel] == nil then c[channel] = v end
    end
end

-- Copy a stored value: the swatch is a table, and the two blocks must not share it.
local function copyLeaf(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = x end
    return out
end

-- `appearance.bars`' stored fill onto the detail's block, where that holds nothing of its own.
local function splitDetailBars(profile, bars)
    local detail = type(profile.resultsDetail) == "table" and profile.resultsDetail or {}
    local block = type(detail.spellBars) == "table" and detail.spellBars or {}
    for _, leaf in ipairs(SPLIT_LEAVES) do
        if bars[leaf] ~= nil and block[leaf] == nil then block[leaf] = copyLeaf(bars[leaf]) end
    end
    if next(block) == nil then return end
    detail.spellBars, profile.resultsDetail = block, detail
end

-- The 5 -> 6 step's two halves. LibKa0s-Skin-1.0's ResetToSkin, or nil without the library (or a
-- library too old to carry it).
local function skinResetter()
    local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)
    if Skin and type(Skin.ResetToSkin) == "function" then return Skin.ResetToSkin end
    return nil
end

-- The stored table holding `path`'s leaf in the raw profile, and the leaf; nil where a block is absent.
local function storedBlock(profile, path)
    local block, leaf = path:match("^(.+)%.([^.]+)$")
    local t = profile
    for part in block:gmatch("[^.]+") do
        if type(t) ~= "table" then return nil end
        t = t[part]
    end
    if type(t) ~= "table" then return nil end
    return t, leaf
end

-- Every FROM_SKIN_KEYS path whose companion is STORED and off; `setDirect` turns each one on in place.
local function staleFromSkinKeys(profile, setDirect)
    local A = NS.HudAppearance
    local keys = {}
    for _, path in ipairs(A and A.FROM_SKIN_KEYS or {}) do
        local t, leaf = storedBlock(profile, path)
        if t and type(t[leaf]) == "boolean" and t[leaf] ~= true then
            keys[#keys + 1] = path
            if setDirect then t[leaf] = true end
        end
    end
    return keys
end

-- The no-library arm of NS.FollowSkinOnce: the write ResetToSkin makes for each listed key, through
-- stored tables only.
local function followByHand(profile, keys)
    for _, path in ipairs(keys) do
        local t, leaf = storedBlock(profile, path)
        if t then t[leaf] = leaf:match("FromSkin$") and true or "@skin" end
    end
end

--- The one step onto the skin (FS-DR-FLIP, the owner's rulings of 2026-11-01): existing profiles follow
--- the skin, colors and shadows included. Per profile, recorded per profile in `skin.fullSkinReset`,
--- because the account-wide stamp cannot say which profiles have been through it and following the
--- skin leaves no shape to read: the v9 step, every init (NS:RunMigrations) and every profile event,
--- so a companion turned off afterwards stays off, and a reset profile runs it against defaults that
--- change nothing a player sees. It names companions and the From skin flags
--- (HudAppearance.FULL_SKIN_KEYS), never a stored color or pick. The gate is the library's,
--- Skin.FollowOnce; the record's table is the one table it may create. Answers true when it ran.
function NS.FollowSkinOnce(profile)
    if type(profile) ~= "table" then return false end
    local keys = NS.HudAppearance.FULL_SKIN_KEYS
    local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)
    if Skin and type(Skin.FollowOnce) == "function" and type(Skin.ResetToSkin) == "function" then
        return Skin.FollowOnce(profile, keys)
    end
    if type(profile.skin) == "table" and profile.skin.fullSkinReset == true then return false end
    followByHand(profile, keys)
    if type(profile.skin) ~= "table" then profile.skin = {} end
    profile.skin.fullSkinReset = true
    return true
end

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
    -- differs from the defaults: an absent companion already reads its default, true (X3), and is
    -- left absent. (LibKa0s before v1.81.0 also wrote its "@skin" sentinel into an absent key it was
    -- handed; v1.81.0 sets a named `...FromSkin` key to true instead, R-6. The filter stays: this step
    -- already shipped and must give a profile that migrates late the same result, D-19.) Without the
    -- library the companions are set directly: they mean nothing until it loads, and then they must
    -- already say "follow".
    { to = 6, perProfile = true, run = function(_sv, profile)
        if type(profile) ~= "table" then return end
        local resetToSkin = skinResetter()
        local keys = staleFromSkinKeys(profile, not resetToSkin)
        if #keys == 0 then return end
        if resetToSkin then resetToSkin(profile, keys) end
        if NS.Debug then
            NS.Debug("Set", "migrate v6: put %d HUD face(s) and texture(s) back on the skin", #keys)
        end
    end },
    -- 6 -> 7: Font flags onto *From skin* (LibKa0s v1.82.0, D-07, Addendum 01), per profile. Each font
    -- block's `fontFlags` (modules/Hud_Appearance.lua's FONT_FLAGS_KEYS) defaulted to "" (None) and
    -- now defaults to "@skin", which draws the Skin tab's Font outline. A stored flag equal to the old
    -- default moves onto From skin; a flag the player changed (anything else) stays. An absent flag
    -- already reads the new default and is left absent. Once, through the account-wide stamp, so a
    -- None the player picks afterwards is kept.
    { to = 7, perProfile = true, run = function(_sv, profile)
        if type(profile) ~= "table" then return end
        local A = NS.HudAppearance
        local moved = 0
        for _, path in ipairs(A and A.FONT_FLAGS_KEYS or {}) do
            local block, leaf = path:match("^(.+)%.([^.]+)$")
            local t = profile
            for part in block:gmatch("[^.]+") do t = type(t) == "table" and t[part] or nil end
            if type(t) == "table" and t[leaf] == "" then
                t[leaf] = "@skin"
                moved = moved + 1
            end
        end
        if moved > 0 and NS.Debug then
            NS.Debug("Set", "migrate v7: put %d font flag(s) on From skin", moved)
        end
    end },
    -- 7 -> 8: the bar styling run (the owner's call, 2026-10-31), per profile. The spell rows' look split
    -- in two: a stored `appearance.bars` fill is copied to `resultsDetail.spellBars`, so the detail keeps
    -- it. And the blue blocks' default moved: AceDB strips a leaf equal to its default, so a stored swatch
    -- may hold only the channels the player moved, and would shift with the new default; its missing
    -- channels are written from the old one. An untouched profile stores nothing and reads the new blue.
    { to = 8, perProfile = true, run = function(_sv, profile)
        if type(profile) ~= "table" then return end
        local appearance = type(profile.appearance) == "table" and profile.appearance or {}
        local results = type(profile.resultsTable) == "table" and profile.resultsTable or {}
        pinChannels(appearance.bars)
        pinChannels(results.damageBar)
        pinChannels(results.dpsBar)
        if type(appearance.bars) == "table" then splitDetailBars(profile, appearance.bars) end
    end },
    -- 8 -> 9: the one step onto the skin (NS.FollowSkinOnce), for every stored profile; the current
    -- one meets it again at each init and profile event, where its record holds it.
    { to = 9, perProfile = true, run = function(_sv, profile) NS.FollowSkinOnce(profile) end },
    -- 9 -> 10 (SG-DR-2): the clocks joined the step's list (SF-DR-1) after a profile had already been
    -- through it, so its record held the step off and the clock blocks kept their stored mono pick with
    -- both companions off, whichever skin was worn. Turn the stored-and-off face and shadow companions
    -- on, once. The pick itself stays: it is what the clock draws with the companion off.
    { to = 10, perProfile = true, run = function(_sv, profile)
        for _, block in ipairs({ "elapsed", "left" }) do
            local b = type(profile.appearance) == "table" and profile.appearance[block]
            if type(b) == "table" then
                if b.fontFromSkin == false then b.fontFromSkin = true end
                if b.fontShadowFromSkin == false then b.fontShadowFromSkin = true end
            end
        end
    end },
    -- 10 -> 11 (R3-FRIZ): LibKa0s v1.85.0 deleted Ka0s Friz Quadrata TT (R3-L7) and WoW Default draws
    -- Ka0s Ubuntu in its place (R3-L6). Every stored string naming the deleted face, at any depth (a
    -- HUD block's or a Results row's font, the skin override), moves to its successor. Blizzard's own
    -- "Friz Quadrata TT" is another key and stays.
    { to = 11, perProfile = true, run = function(_sv, profile)
        local moved = type(profile) == "table" and NS.RetireFonts(profile) or 0
        if moved > 0 and NS.Debug then
            NS.Debug("Set", "migrate v11: moved %d Ka0s Friz Quadrata TT pick(s) to Ka0s Ubuntu", moved)
        end
    end },
}
NS.__migrationSteps = STEPS   -- test seam only

-- The shipped faces LibKa0s retired, each to its successor (R3-FRIZ; LibKa0s R3-L7).
local RETIRED_FONTS = { ["Ka0s Friz Quadrata TT"] = "Ka0s Ubuntu" }

--- Moves every string naming a retired face, at any depth of `t`, to its successor. Answers how many moved.
function NS.RetireFonts(t)
    local n = 0
    for k, v in pairs(t) do
        if type(v) == "table" then
            n = n + NS.RetireFonts(v)
        elseif RETIRED_FONTS[v] then
            t[k], n = RETIRED_FONTS[v], n + 1
        end
    end
    return n
end

--- A profile switch, copy or reset replaces the whole profile wholesale: the stored `enabled` can
--- flip, the visibility rule can change, so re-take the hold and re-decide (slash-commands-§7: these
--- callbacks are SETUP and stay live while disabled). One line per act (debug-logging-§10).
function NS.OnProfileChanged(event, _db, key)
    NS.Debug("Set", "%s '%s'", event or "profile", key or (NS.db and NS.db:GetCurrentProfile()) or "?")
    -- The first-run skin picker goes down first, unmarked (core/SkinSetup.lua), so a preview it had
    -- pending is put back before the new profile's skin is applied below.
    if NS.HideSkinPicker then NS.HideSkinPicker() end
    -- A new, copied or reset profile takes the one step onto the skin before it draws.
    if NS.db then NS.FollowSkinOnce(NS.db.profile) end
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
    NS.FollowSkinOnce(db.profile)
end
