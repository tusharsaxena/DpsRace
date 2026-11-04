-- tests/test_sim_checkbox.lua — General > Master controls' Sim mode checkbox (R6-SIM, LibKa0s
-- R6-SIM-L): the library's session row beside Test mode, driven by the SAME pair the launcher's Sim
-- mode entry carries (NS.IsSimMode / NS.ToggleSim), so the box, the launcher and `/dr sim` are one
-- act; it follows the live sim, and Reset all settings stops a running one. R7-SIM (the owner's round 7
-- rule): the box is ticked exactly while the sim window (the step panel) is shown or a sim runs.

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
    assertTrue(NS.GetSetting(SIM_PATH), "the tick did not stay: unticked on the open idle panel")
    assertTrue(s:RunVerb("start newbest"))
    assertTrue(NS.GetSetting(SIM_PATH), "not ticked after Start")
    -- A tick on a running sim is no toggle: it stays on.
    assertTrue(NS.SetByPath(SIM_PATH, true))
    assertTrue(s:IsActive(), "a second tick stopped the sim")
    assertTrue(NS.SetByPath(SIM_PATH, false))
    assertFalse(s:IsActive(), "the untick left the sim on")
    assertFalse(NS.Preview.IsActive(), "the untick left the preview on")
    assertFalse(s:IsPanelShown(), "the untick left the sim window open")
    assertFalse(NS.GetSetting(SIM_PATH))
end)

test("sim checkbox: a tick in combat starts no sim; the box reads only the window it opened", function()
    local inst = T.load()
    local NS = inst.NS
    local s = NS.Sim.session
    inst.mocks.__inCombat = true
    -- The panel's own write is refused in combat by the library's lock, so the box stays unticked
    -- there. One that reaches the row is the bare verb, which starts no sim; since R7-SIM the box
    -- reads the window that verb opens, and nothing else.
    NS.SetByPath(SIM_PATH, true)
    assertFalse(s:IsActive(), "a sim started in combat")
    assertEqual(NS.GetSetting(SIM_PATH), s:IsPanelShown(), "the box read more than the window")
    s:HidePanel()
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
    -- The stepper's own Stop keeps its window open on the idle picker, so the box stays ticked
    -- (R7-SIM) until the window closes.
    assertTrue(s:IsPanelShown(), "the stop closed the window")
    assertEqual(seen[#seen], true, "the last repaint read the open window as off")
    seen = {}
    s:HidePanel()
    assertTrue(#seen > 0, "the window's close repainted nothing")
    assertEqual(seen[#seen], false, "the last repaint read the closed window as on")
end)

-- ── R7-SIM: ticked exactly while the sim window shows or a sim runs ──────────────────────────────

-- An instance whose named frames answer by name, as the client's globals do (the mock's CreateFrame
-- records the name only), so the sim window's frame is the one modules/Sim.lua hooks.
local function namedLoad()
    local named = {}
    local inst = T.load{ mutate = function(m)
        local create = m.CreateFrame
        m.CreateFrame = function(kind, name, ...)
            local f = create(kind, name, ...)
            if type(name) == "string" then
                named[name] = f
                m[name] = f
            end
            return f
        end
    end }
    inst.named = named
    return inst
end

local function simWindow(inst) return assert(inst.named.DpsRaceSimPanel, "the sim window was never built") end

-- The client's Hide on a shown frame runs its OnHide; the mock's Hide runs no script.
local function closeWindow(inst)
    local f = simWindow(inst)
    f:Hide()
    f:__fire("OnHide")
end

test("sim checkbox R7-SIM: the sim window open and idle reads ticked, on the box and the launcher", function()
    -- red under: isSimMode read the running session only, so `/dr sim`'s idle window read unticked.
    local inst = namedLoad()
    local NS = inst.NS
    assertTrue(NS.RunSimVerb(""))                    -- the bare `/dr sim`: the window, idle
    assertTrue(NS.Sim.session:IsPanelShown())
    assertFalse(NS.Sim.session:IsActive())
    assertTrue(NS.GetSetting(SIM_PATH), "the open idle window reads unticked")
    assertTrue(launcherMenu(inst):Find("Sim mode").isSelected(), "the launcher disagrees")
end)

test("sim checkbox R7-SIM: closing the sim window with its own close unticks the box and repaints the page", function()
    -- red under: nothing repainted on the window's hide, and the box read the session alone.
    local inst = namedLoad()
    local NS = inst.NS
    assertTrue(NS.RunSimVerb(""))
    local seen = {}
    NS.Helpers.RefreshScalars = function() seen[#seen + 1] = NS.GetSetting(SIM_PATH) end
    closeWindow(inst)
    assertFalse(NS.Sim.session:IsPanelShown())
    assertFalse(NS.GetSetting(SIM_PATH), "ticked with the window closed")
    assertTrue(#seen > 0, "the window's hide repainted nothing")
    assertEqual(seen[#seen], false, "the last repaint read the box as ticked")
    assertFalse(launcherMenu(inst):Find("Sim mode").isSelected(), "the launcher still ticks")
    -- Opened again (the window is built now), its show repaints too.
    seen = {}
    assertTrue(NS.RunSimVerb(""))
    assertTrue(#seen > 0, "the window's show repainted nothing")
    assertEqual(seen[#seen], true, "the last repaint read the box as unticked")
end)

test("sim checkbox R7-SIM: a sim running with the window hidden reads ticked", function()
    local inst = namedLoad()
    local NS = inst.NS
    local s = NS.Sim.session
    assertTrue(s:RunVerb("start newbest"))
    closeWindow(inst)
    assertTrue(s:IsActive(), "closing the window stopped the run")
    assertFalse(s:IsPanelShown())
    assertTrue(NS.GetSetting(SIM_PATH), "a run with its window hidden reads unticked")
    assertTrue(launcherMenu(inst):Find("Sim mode").isSelected(), "the launcher disagrees")
end)

test("sim checkbox R7-SIM: an untick while a sim runs stops it and hides the window; unticked after", function()
    -- red under: the stop kept the window open on its idle picker, so the box stayed ticked.
    local inst = namedLoad()
    local NS = inst.NS
    local s = NS.Sim.session
    assertTrue(s:RunVerb("start newbest"))
    assertTrue(s:IsPanelShown())
    assertTrue(NS.SetByPath(SIM_PATH, false))
    assertFalse(s:IsActive(), "the untick left the sim on")
    assertFalse(s:IsPanelShown(), "the untick left the window open")
    assertFalse(NS.Preview.IsActive())
    assertFalse(NS.GetSetting(SIM_PATH), "ticked after the untick")
    -- From the window open and idle, one untick closes it.
    assertTrue(NS.SetByPath(SIM_PATH, true))
    assertTrue(s:IsPanelShown())
    assertTrue(NS.SetByPath(SIM_PATH, false))
    assertFalse(s:IsPanelShown(), "the untick left the idle window open")
    assertFalse(NS.GetSetting(SIM_PATH))
end)
