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
    -- The skin the active profile names (core/SkinSetup.lua), right after the store exists: the owner
    -- registered at file load, before AceDB, and has worn Ka0s Default since. Before any page or
    -- window is built, so the first paint is already the profile's skin.
    NS.ApplySkinChoice()
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
    -- Login prune to the stored "Days to keep" (0 = never; spec §7). Never a running or stopping run,
    -- so it cannot take what Resume below carries on.
    NS.Bests.PruneToSetting()
    -- Runs a /reload left running or stopping carry on from their stored status (spec §4.5).
    NS.Race.Resume()
    -- The HUD's login decision ("always" shows it) after the race it may be showing.
    NS.Hud.Resume()
    -- Auto-show and auto-arm near a training dummy (#16): their events, from the current settings.
    NS.AutoArm.Resume()
    -- The final seconds' marks, for a race the resume left running.
    NS.Countdown.Resume()
    -- The first-run skin picker (core/SkinSetup.lua), once per session on a profile that has not
    -- closed it: two seconds in, off the login spike, on an AceTimer the stand-down cancels. The
    -- stored skin was applied in OnInitialize; in combat the show holds for PLAYER_REGEN_ENABLED.
    addon:ScheduleTimer(function() NS.MaybeShowSkinPicker() end, 2)
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
-- and the slash verb. Each refuses through the one hold-aware helper while stood down.

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

--- `/dr hud show|hide|toggle`: the HUD's own show, hide or toggle.
--- @param how string "show" | "hide" | "toggle"
function NS.SetHudShown(how)
    if refused() then return false end
    if how == "show" then NS.Hud.Show() elseif how == "hide" then NS.Hud.Hide() else NS.Hud.Toggle() end
    return true
end

--- `/dr results [insights]`: open the Results window, on the Insights tab when asked. "bests", the
--- tab's name before #12, is a silent alias (D-12 of the plan): a macro written before the rename
--- keeps working, and only "insights" is in the help and the docs.
--- @param tab string|nil "insights" (or "bests") for the Insights tab; anything else opens the window as it was
function NS.ShowResults(tab)
    if refused() then return false end
    if tab == "insights" or tab == "bests" then return NS.Results.ShowTab("insights") end
    NS.Results.Show()
    return true
end

--- The Arm or cancel key (spec §6.4): idle or on a result card, arm the HUD's length (the last one
--- raced); armed or running, cancel. A run waiting for its result is never discarded by a key press:
--- that is the HUD's Discard run or `/dr cancel`, both of which the player reads first.
function NS.ToggleArm()
    if refused() then return false end
    local S, state = NS.Race.STATE, NS.Race.State()
    if state == S.ARMED or state == S.RUNNING then return NS.Race.Cancel() end
    if state == S.STOPPING then
        NS.Print(L["A run is waiting for its result: /dr cancel discards it."])
        return false
    end
    return (NS.Hud.Act.arm())
end

function NS.ToggleLock()
    if refused() then return false end
    return NS.SetByPath("locked", NS.GetSetting("locked") ~= true)
end

-- Start the queued preview through the Test mode row's write seam, so the Master controls' checkbox
-- follows; an active preview switches in place (the row is already on, so its write would not run).
local function startQueued(opts)
    local P = NS.Preview
    P.Queue(opts)
    if P.IsActive() then return P.Start() end
    return NS.SetByPath("state.testMode", true)
end

--- `/dr test [armed|running|result]`, the Master controls' row and the launcher's entry: a bare call
--- turns test mode on or off; a state word holds that HUD body still (test mode on, or switched to).
--- @param word string|nil
function NS.ToggleTestMode(word)
    if refused() then return false end
    local P = NS.Preview
    if word == nil or word == "" then return NS.SetByPath("state.testMode", not P.IsActive()) end
    if not P.IsState(word) then
        NS.Print(L["Usage: %s test [armed|running|result]"]:format(NS.SLASH))
        return false
    end
    if P.Mode() == "test" then return P.SetState(word) end
    return startQueued({ mode = "test", state = word })
end

--- Play a whole sample race at once (the default scenario with none); an active preview switches to it
--- in place. With the library's step session it starts there and plays (the panel's Start); without
--- it, the old path through the Test mode row.
--- @param word string|nil
function NS.StartSim(word)
    if refused() then return false end
    if word == nil or word == "" then word = NS.Sim.DEFAULT end
    if not NS.Sim.IsScenario(word) then
        NS.Print(NS.Sim.Usage())
        for _, s in ipairs(NS.Sim.SCENARIOS) do NS.Print(L["  %s: %s"]:format(s.key, L[s.desc])) end
        return false
    end
    if NS.Sim.session then return NS.Sim.Open(word, true) end
    return startQueued({ mode = "sim", scenario = word })
end

--- `/dr sim [line]` (R5-DR2): the library's sim grammar, as `/mm sim`'s. A bare line prints the status
--- and the usage and opens the step panel idle (the scenario dropdown and Start); `start <scenario>`,
--- `step`, `run`, `pause`, `resume`, `restart`, `stop`, `status` and `panel` are the panel's own verbs.
--- A bare scenario word (`/dr sim died`) starts it at once, switching a live sim in place. With no
--- library session, the old path: StartSim.
--- @param line string|nil
function NS.RunSimVerb(line)
    if refused() then return false end
    line = tostring(line or "")
    local word = line:match("^%s*(%S*)"):lower()
    local session = NS.Sim.session
    if not session then return NS.StartSim(word) end
    if NS.Sim.IsScenario(word) then return NS.StartSim(word) end
    return (session:RunVerb(line)) == true
end

--- Whether Sim mode reads on (the launcher's Sim mode entry and Master controls' Sim mode box): the sim
--- window (the step panel) is shown or a sim runs (R7-SIM, the owner's round 7 rule). With no library
--- session, the preview's mode.
function NS.IsSimMode()
    local session = NS.Sim and NS.Sim.session
    if session then return session:IsPanelShown() == true or session:IsActive() == true end
    return NS.Preview ~= nil and NS.Preview.Mode() == "sim"
end

--- The Sim mode toggle. Off, it is the bare `/dr sim` (the idle sim window), so it picks no scenario and
--- the box stays ticked. On, it stops a running sim and closes the window (R7-SIM), so one untick or one
--- launcher click leaves it off. With no library session, the old path: Test mode off, or StartSim. The
--- launcher's Sim mode entry and General > Master controls' Sim mode box both call it, with
--- NS.IsSimMode as their read (R6-SIM), so the two and the verb are one act.
function NS.ToggleSim()
    local session = NS.Sim and NS.Sim.session
    if not session then
        if NS.IsSimMode() then return NS.ToggleTestMode() end
        return NS.StartSim()
    end
    if not NS.IsSimMode() then return NS.RunSimVerb("") end
    if session:IsActive() and not NS.RunSimVerb("stop") then return false end
    session:HidePanel()
    return true
end

--- Test mode's combat end, said once (preview-mode).
function NS.SayTestModeEnded()
    NS.Print(L["Test mode ended: you entered combat."])
end
