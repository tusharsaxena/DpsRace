local addonName, NS = ...
-- core/DpsRace.lua — AceAddon registration, the lifecycle kick, the game events the scaffold watches,
-- and the host handlers the launcher, the key bindings and the slash verbs share.

local L = NS.L
local Perf = NS.Perf

local addon = LibStub("AceAddon-3.0"):NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon

-- AceConsole's embed stamped its own :Print over NS.Print; reclaim the tagged printer every settings
-- file captured (architecture-§2: the SAME function object as NS.Util.print).
NS.Print = NS.Util.print

function NS:OnInitialize()
    self:InitDB()
    -- Before anything reads NS.db.profile (savedvariables-§1).
    self:RunMigrations()
    -- The stored switch takes its hold before OnEnable runs, so a disabled login registers nothing.
    NS.SyncEnabledHold()
    NS.Launcher:Register()
    -- EAGER category registration; the page bodies stay lazy (options-ui-§1/§5).
    NS.CreateOptionsPanel()
    NS.Slash:Register()
end

function NS:OnEnable()
    if NS.IsStoodDown() then return end
    NS.RegisterGameEvents()
    -- Login prune to the stored "Runs to keep" (0 = never; spec §7). Never a running or stopping run,
    -- so it cannot take what Resume below carries on.
    NS.Bests.PruneToSetting()
    -- Runs a /reload left running or stopping carry on from their stored status (spec §4.5).
    NS.Race.Resume()
end

-- ── Game events ─────────────────────────────────────────────────────────────────────────────────
-- Entering combat ends test mode (preview-mode). A visibility mode that depends on combat needs the
-- leaving edge too. Built from CURRENT settings every time, which is what lets a stand-up after a
-- setting changed while disabled come back with the right set (slash-commands-§7 step 9).
local function wantedEvents()
    local list = { "PLAYER_REGEN_DISABLED" }
    local vis = NS.GetSetting("visibility")
    if vis == "inCombat" or vis == "outOfCombat" then list[#list + 1] = "PLAYER_REGEN_ENABLED" end
    return list
end

function NS.RegisterGameEvents()
    addon:UnregisterEvent("PLAYER_REGEN_DISABLED")
    addon:UnregisterEvent("PLAYER_REGEN_ENABLED")
    for _, event in ipairs(wantedEvents()) do
        NS.SafeRegisterEvent(addon, event, "OnCombatChanged", NS.rejectedEvents)
    end
end

function NS:OnCombatChanged(event)
    local t0 = Perf.on and debugprofilestop()
    NS.Debug("Combat", "%s", event)
    if event == "PLAYER_REGEN_DISABLED" and NS.Preview.IsActive() then
        NS.Preview.Stop("combat")
    end
    NS.Hud.Refresh()
    if t0 then Perf.Note("combatEvent", debugprofilestop() - t0) end
end

--- The `visibility` row's reaction: rebuild the registrations (only while standing up) and re-decide.
function NS.OnVisibilityChanged()
    if not NS.IsStoodDown() then NS.RegisterGameEvents() end
    NS.Hud.Refresh()
end

--- The show decision's master rungs, in order (performance-§6: refuse at the SOURCE): stood down,
--- test mode, then General visibility. A window adds its own rungs below these.
function NS.MasterVisibilityAllows()
    if NS.IsStoodDown() then return false, NS.IsDisabled() and "disabled" or "suspended" end
    if NS.Preview.IsActive() then return true, "test" end
    local mode = NS.GetSetting("visibility")
    if mode == "never" then return false, "hidden" end
    local fighting = UnitAffectingCombat("player") and true or false
    if mode == "inCombat" and not fighting then return false, "out of combat" end
    if mode == "outOfCombat" and fighting then return false, "in combat" end
    return true, "shown"
end

-- ── Host handlers ───────────────────────────────────────────────────────────────────────────────
-- ONE handler per act, shared by every surface that performs it: the launcher menu, the key binding
-- and (from T9) the slash verb. Each refuses through the one hold-aware helper while stood down.

local function refused()
    local line = NS.StoodDownRefusal()
    if line then NS.Print(line) return true end
    return false
end

function NS.ToggleHud()
    if refused() then return false end
    NS.Hud.Toggle()
    return true
end

function NS.ToggleResults()
    if refused() then return false end
    NS.Results.Toggle()
    return true
end

function NS.ToggleLock()
    if refused() then return false end
    return NS.SetByPath("locked", NS.GetSetting("locked") ~= true)
end

function NS.ToggleTestMode()
    if refused() then return false end
    return NS.SetByPath("state.testMode", not NS.Preview.IsActive())
end

--- Test mode's combat end, said once (preview-mode).
function NS.SayTestModeEnded()
    NS.Print(L["Test mode ended: you entered combat."])
end
