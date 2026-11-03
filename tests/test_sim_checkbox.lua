-- tests/test_sim_checkbox.lua — General > Master controls' Sim mode checkbox (R6-SIM, LibKa0s
-- R6-SIM-L): the library's session row beside Test mode, driven by the SAME pair the launcher's Sim
-- mode entry carries (NS.IsSimMode / NS.ToggleSim), so the box, the launcher and `/dr sim` are one
-- act; it follows the live sim, and Reset all settings stops a running one.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local SIM_PATH = "state.sim"

local function simRow(NS) return assert(NS.FindSchemaRow(SIM_PATH), "no Sim mode row") end

local function indexOf(NS, path)
    for i, r in ipairs(NS.Schema) do
        if r.path == path then return i end
    end
end

local function launcherMenu(inst)
    local obj = inst.mocks.LibStub("LibDataBroker-1.1"):GetDataObjectByName("DpsRace")
    obj.OnClick(inst.mocks.UIParent, "RightButton")
    return assert(inst.mocks.__lastMenu, "the right-click opened no menu")
end

test("sim checkbox: Master controls carries a session-only Sim mode row right after Test mode", function()
    -- red under: General.lua passed no isSimMode / toggleSim, so the composer drew no row.
    local NS = T.load().NS
    local r = simRow(NS)
    assertEqual(r.label, "Sim mode")
    assertEqual(r.type, "bool")
    assertEqual(r.group, NS.Helpers.MASTER_GROUP)
    assertTrue(r.sessionOnly, "the row stores nothing")
    assertEqual(r.default, false)
    assertEqual(indexOf(NS, SIM_PATH), indexOf(NS, "state.testMode") + 1, "not beside Test mode")
end)

test("sim checkbox: the launcher's pair is the one NS pair, so the box and the launcher read alike", function()
    local inst = T.load()
    local NS = inst.NS
    assertEqual(type(NS.ToggleSim), "function", "no NS.ToggleSim for both to share")
    assertFalse(NS.GetSetting(SIM_PATH), "ticked with no sim")
    NS.StartSim()
    assertTrue(NS.GetSetting(SIM_PATH), "not ticked during a sim")
    assertTrue(launcherMenu(inst):Find("Sim mode").isSelected(), "the launcher disagrees")
end)

test("sim checkbox: ticking does what /dr sim does, unticking stops the sim", function()
    local NS = T.load().NS
    local s = NS.Sim.session
    -- A bare `/dr sim` opens the idle step panel and starts nothing; the tick is that act.
    assertTrue(NS.SetByPath(SIM_PATH, true))
    assertTrue(s:IsPanelShown(), "the tick did not open the step panel")
    assertFalse(s:IsActive(), "the tick picked a scenario the verb does not")
    assertFalse(NS.GetSetting(SIM_PATH), "ticked on an idle panel")
    assertTrue(s:RunVerb("start newbest"))
    assertTrue(NS.GetSetting(SIM_PATH), "not ticked after Start")
    -- A tick on a running sim is no toggle: it stays on.
    assertTrue(NS.SetByPath(SIM_PATH, true))
    assertTrue(s:IsActive(), "a second tick stopped the sim")
    assertTrue(NS.SetByPath(SIM_PATH, false))
    assertFalse(s:IsActive(), "the untick left the sim on")
    assertFalse(NS.Preview.IsActive(), "the untick left the preview on")
    assertFalse(NS.GetSetting(SIM_PATH))
end)

test("sim checkbox: a tick in combat starts nothing and leaves the box unticked", function()
    local inst = T.load()
    local NS = inst.NS
    inst.mocks.__inCombat = true
    -- The panel's own write is refused in combat by the library's lock; one that reaches the row is
    -- the bare verb, which starts no sim, so the box still reads off.
    NS.SetByPath(SIM_PATH, true)
    assertFalse(NS.Sim.session:IsActive(), "a sim started in combat")
    assertFalse(NS.GetSetting(SIM_PATH))
    inst.mocks.__inCombat = false
end)

test("sim checkbox: Reset all settings stops a running sim and starts none on an idle one", function()
    local NS = T.load().NS
    local s = NS.Sim.session
    NS.Helpers.RestoreAllDefaults()
    NS.Helpers.HideSkinPicker()       -- the reset profile's first-run picker (R6-PV), closed
    assertFalse(s:IsActive(), "the reset started a sim")
    assertFalse(s:IsPanelShown(), "the reset opened the step panel")
    assertTrue(s:RunVerb("start newbest"))
    NS.Helpers.RestoreAllDefaults()
    NS.Helpers.HideSkinPicker()
    assertFalse(s:IsActive(), "the reset left the sim on")
    assertFalse(NS.GetSetting(SIM_PATH))
end)

test("sim checkbox: a sim started or ended elsewhere repaints an open page with the live state", function()
    -- red under: nothing told the page when the session started or stopped by itself.
    local NS = T.load().NS
    local s = NS.Sim.session
    local seen = {}
    NS.Helpers.RefreshScalars = function() seen[#seen + 1] = NS.GetSetting(SIM_PATH) end
    assertTrue(s:RunVerb("start newbest"))          -- `/dr sim start newbest`, the page open
    assertTrue(#seen > 0, "the start repainted nothing")
    assertEqual(seen[#seen], true, "the last repaint read the sim as off")
    seen = {}
    assertTrue(s:RunVerb("stop"))
    assertTrue(#seen > 0, "the stop repainted nothing")
    assertEqual(seen[#seen], false, "the last repaint read the sim as on")
end)
