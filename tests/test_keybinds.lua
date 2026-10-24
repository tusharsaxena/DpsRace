-- tests/test_keybinds.lua — the three key bindings as the player meets them (launcher-§6,
-- options-ui-§20): Bindings.xml in the addon's own category, NS.BINDINGS in file order with its
-- labels, and the General page's last tab, `Keybindings`, drawn by the library. A key bound through
-- the tab is the client's key, a key bound on the client's page shows in the tab, and combat refuses.
-- Capture, conflict and settings-window cases are the library's (testing-§8) and are not repeated.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local HUD, RESULTS, ARM =
    "CLICK DpsRaceToggleHud:LeftButton", "CLICK DpsRaceToggleResults:LeftButton", "CLICK DpsRaceArmToggle:LeftButton"
local LABELS = {
    [HUD]     = "Toggle race HUD",
    [RESULTS] = "Toggle results window",
    [ARM]     = "Arm or cancel race",
}

local ctxOf = setmetatable({}, { __mode = "k" })   -- panel -> the ctx its renderer was handed

--- Show the General page and draw it on `tab` (nil: its first), answering the strip's tab keys, the
--- Keybindings tab's row records when that tab drew, and the page's ctx.
local function showGeneral(M, NS, tab)
    local H = NS.Helpers
    local realTabs, realRows = H.RenderTabbedSchema, H.KeybindRows
    local keys, rows, ctx
    H.RenderTabbedSchema = function(c, ...)
        ctx = c
        local groups, drawn = realTabs(c, ...)
        keys = drawn
        return groups, drawn
    end
    H.KeybindRows = function(...)
        rows = realRows(...)
        return rows
    end
    local panel = M.__subcategories["General"]
    local ok, err = pcall(function()
        panel:Show()
        panel:__fire("OnShow")
        -- An already-drawn page is not redrawn on a show; draw it again, on the tab asked for.
        ctx = ctx or ctxOf[panel]
        if ctx then
            ctxOf[panel] = ctx
            ctx.activeTab = tab
            ctx._renderFn(ctx)
        end
    end)
    H.RenderTabbedSchema, H.KeybindRows = realTabs, realRows
    assert(ok, err)
    return keys, rows, ctx
end

test("keybinds: NS.BINDINGS is Bindings.xml's order, Show window first, each with a tooltip", function()
    local NS = T.NS
    assertEqual(#NS.BINDINGS, 3)
    for i, command in ipairs({ HUD, RESULTS, ARM }) do
        assertEqual(NS.BINDINGS[i].command, command)
        assertEqual(type(NS.BINDINGS[i].tooltip), "string", command)
        assertTrue(#NS.BINDINGS[i].tooltip > 0, command .. " tooltip is empty")
    end
end)

test("keybinds: Bindings.xml is the addon's own category, no header, no default, labeled", function()
    local list = T.assertBindingsXml(T.root .. "/Bindings.xml", {
        category = "BINDING_HEADER_DPSRACE",
        commands = T.NS.BINDINGS,
        brand    = T.NS.BRAND,
        globals  = T.mocks._G,
        labels   = LABELS,
    })
    assertEqual(#list, 3)
    assertEqual(T.mocks._G.BINDING_HEADER_DPSRACE, "Ka0s DPS Race")
end)

test("keybinds: the General page ends in the Keybindings tab, after Master controls", function()
    local M, NS = T.mocks, T.NS
    M.__resetPrinted()
    local keys = assert(showGeneral(M, NS, nil), "the General page drew no tab strip")
    assertEqual(keys[1], NS.Helpers.MASTER_GROUP, "Master controls stays first")
    assertEqual(keys[#keys], "Keybindings", "the Keybindings tab is the last")
    assertEqual(#M.__printed(), 0, "a render printed: " .. tostring(M.__printed()[1]))
end)

test("keybinds: the tab's rows are NS.BINDINGS in order, labeled as the client labels them", function()
    local M, NS = T.mocks, T.NS
    M.__resetPrinted()
    local _, rows = showGeneral(M, NS, "Keybindings")
    rows = assert(rows, "the Keybindings tab drew no rows")
    assertEqual(#rows, #NS.BINDINGS)
    for i, row in ipairs(rows) do
        assertEqual(row.command, NS.BINDINGS[i].command)
        assertEqual(row.label:GetText(), M._G["BINDING_NAME_" .. row.command])
        assertEqual(row.label:GetText(), LABELS[row.command])
    end
    assertEqual(#M.__printed(), 0, "a render printed: " .. tostring(M.__printed()[1]))
    showGeneral(M, NS, nil)
end)

test("keybinds: a key bound in the tab is the client's key; one set on the client's page shows", function()
    local M, NS = T.mocks, T.NS
    M.clearBindings()
    local _, rows = showGeneral(M, NS, "Keybindings")
    rows = assert(rows, "the Keybindings tab drew no rows")
    assertEqual(T.keybindThroughTab(rows[1], 1, "K", { shift = true }), M.KEY_BOUND)
    assertEqual(M.GetBindingKey(HUD), "SHIFT-K")
    assertEqual(M.__savedBindingSets[#M.__savedBindingSets], M.GetCurrentBindingSet(), "saved to the set in force")

    -- The client's own page writes through SetBinding, which fires UPDATE_BINDINGS: the tab follows.
    assertTrue(M.SetBinding("F7", ARM))
    while M.__fireTimers() > 0 do end
    assertEqual(rows[3].slots[1]:GetText(), "F7", "the tab did not follow a key set on the client's page")
    M.clearBindings()
    showGeneral(M, NS, nil)
end)

test("keybinds: in combat the tab binds nothing", function()
    local M, NS = T.mocks, T.NS
    M.clearBindings()
    local _, rows = showGeneral(M, NS, "Keybindings")
    rows = assert(rows, "the Keybindings tab drew no rows")
    local real = M.InCombatLockdown
    M.InCombatLockdown = function() return true end
    local ok, err = pcall(T.keybindThroughTab, rows[2], 1, "J")
    M.InCombatLockdown = real
    assert(ok, err)
    assertEqual(M.GetBindingKey(RESULTS), nil, "a key was bound in combat")
    assertEqual(#M.__bindingWrites, 0, "a binding API write ran in combat")
    assertEqual(rows[2].status:GetText(), M.LibStub("LibKa0s-Options-1.0").KEYBIND_STRINGS.COMBAT)
    showGeneral(M, NS, nil)
end)

test("keybinds: the General Defaults tooltip says it leaves key bindings alone", function()
    local tip = T.mocks.__subcategories["General"].defaultsTooltip
    assertEqual(type(tip), "string", "no Defaults tooltip on the General page")
    assertTrue(tip:find(T.NS.Helpers.KEYBINDS_UNCHANGED, 1, true) ~= nil, tip)
end)
