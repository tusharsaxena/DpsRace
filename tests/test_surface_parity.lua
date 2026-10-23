-- tests/test_surface_parity.lua — every degradation stub carries the surface of what it stands in for
-- (testing-§8). Each case loads the addon twice -- whole, and with the LibKa0s file list EMPTY -- and
-- compares the stub against the live surface; a trimmed name is one this addon never calls.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local live, degraded
local function pair()
    live = live or T.load()
    degraded = degraded or T.load{ libFiles = {} }
    return live, degraded
end

test("parity: the degraded load still initializes, enables and answers /dr", function()
    local _, d = pair()
    assertEqual(d.mocks.LibStub("LibKa0s-Core-1.0", true), nil, "the library is not absent")
    assertTrue(d.NS.db ~= nil, "InitDB ran")
    d.mocks.__resetPrinted()
    d.NS.Slash:OnSlash("version")
    assertTrue(#d.mocks.__printed() > 0, "/dr version answered")
end)

test("parity: the Options stub carries every public member of the live Helpers surface", function()
    local _, d = pair()
    T.assertSurfaceParity(d.NS.Helpers, "LibKa0s-Options-1.0", {
        -- constants and composers a page reads only on a full load
        "CLASS_COLOR_NOTE", "FONT_FLAGS", "FONT_FLAGS_SORT", "VISIBILITY_SORT", "VISIBILITY_VALUES",
        "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL", "PADDING_X", "CHROME_GAP", "TAB_H",
        "BANNER_H", "PageHeader", "SubTabStrip", "AceGUI",
    })
end)

test("parity: the Bus stub carries the library surface, and its record the instance's", function()
    local l, d = pair()
    T.assertSurfaceParity(d.NS.BusLib, "LibKa0s-Bus-1.0")
    T.assertSurfaceParity(l.NS.busRecord, d.NS.busRecord, "NS.busRecord")
end)

test("parity: the Schema stub carries the runtime surface this addon binds", function()
    local l, d = pair()
    T.assertSurfaceParity(l.NS.SchemaRuntime, d.NS.SchemaRuntime, "NS.SchemaRuntime", {
        "Reindex", "Default", "SetMany", "BulkAdd", "InBulk",            -- never called by this addon
        "CountOffDefault", "ResetCounted", "ConsumeResetCount",
    })
    T.assertSurfaceParity(l.NS.__schemaLib, d.NS.__schemaLib, "NS.__schemaLib",
        { "STRINGS", "SameValue", "MAJOR", "MINOR", "MODULES" })
end)

test("parity: the Slash stub carries the live dispatcher's surface", function()
    local l, d = pair()
    T.assertSurfaceParity(l.NS.Slash.__dispatcher, d.NS.Slash.__dispatcher, "NS.Slash.__dispatcher", {
        "BuildListLines", -- the schema CLI's listing; the stub's CliList names the missing library
        "HelpHeader",     -- the stub's PrintHelp prints its own plain header
        "Text",           -- lib.STRINGS; the stub carries no library string but the refusal format
    })
end)

test("parity: the Lifecycle stub carries the live latch's surface", function()
    local l, d = pair()
    T.assertSurfaceParity(l.NS.lifecycle, d.NS.lifecycle, "NS.lifecycle")
end)

test("parity: the Launcher stub carries the live launcher's surface", function()
    local l, d = pair()
    T.assertSurfaceParity(l.NS.Launcher, d.NS.Launcher, "NS.Launcher")
end)

test("parity: the DebugLog stub carries every member this addon calls", function()
    local l, d = pair()
    local used = { "Add", "Debug", "Show", "Hide", "Toggle", "IsShown", "IsEnabled", "SetEnabled",
                   "ConsoleCheckbox", "RunDiagnostics", "DebugVerb", "DebugOnce", "DebugChanged",
                   "DebugAtEnable" }
    for _, name in ipairs(used) do
        assertEqual(type(l.NS.DebugLog[name]), "function", "live " .. name)
        assertEqual(type(d.NS.DebugLog[name]), "function", "stub " .. name)
    end
end)

test("parity: the Pool stub carries the array-shape members", function()
    local _, d = pair()
    for _, name in ipairs({ "New", "Acquire", "ReleaseAll", "Counts" }) do
        assertEqual(type(d.NS.Pool[name]), "function", name)
    end
end)
