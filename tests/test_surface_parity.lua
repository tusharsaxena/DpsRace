-- tests/test_surface_parity.lua — every degradation stub carries the surface of what it stands in for
-- (testing-§8). Each case loads the addon twice -- whole, and with the LibKa0s file list EMPTY -- and
-- compares the stub against the live surface; a trimmed name is one this addon never calls.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

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

test("parity: the degraded load keeps the late-cast ignore list: the Race page draws quietly and /dr ignore adds by ID", function()
    -- S-4 (#8): the Race page's list reaches only stubbed Helpers members, and with ResolveId stubbed
    -- to nil LateIgnore.Resolve still takes a number, a link and "hearthstone" on its own.
    local _, d = pair()
    for _, name in ipairs({ "TextRow", "IdList", "InlineButtonPair", "RefreshPanel", "ResolveId" }) do
        assertEqual(type(d.NS.Helpers[name]), "function", name .. " is not stubbed")
    end
    local panel = d.mocks.__subcategories and d.mocks.__subcategories["Race"]
    if panel then panel:__fire("OnShow") end
    assertEqual(d.NS.LateIgnore.Resolve("spell:29722"), 29722)
    assertEqual(d.NS.LateIgnore.Resolve("hearthstone"), d.NS.LateIgnore.HEARTHSTONE)
    d.NS.Slash:OnSlash("ignore add 29722")
    assertTrue(d.NS.LateIgnore.IsIgnored(29722), "the degraded /dr ignore add did not land")
    d.NS.Slash:OnSlash("ignore remove 29722")
    assertFalse(d.NS.LateIgnore.IsIgnored(29722))
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
    -- members from: grep -rhoE "DebugLog[.:][A-Za-z]+" core/ modules/ settings/ | sort -u, plus
    -- Hide, IsEnabled and SetEnabled, which the console row and the diagnostics contract reach
    local used = { "Add", "Debug", "Show", "Hide", "Toggle", "IsShown", "IsEnabled", "SetEnabled",
                   "ConsoleCheckbox", "RunDiagnostics", "DebugVerb", "DebugOnce", "DebugChanged",
                   "DebugAtEnable" }
    for _, name in ipairs(used) do
        assertEqual(type(l.NS.DebugLog[name]), "function", "live " .. name)
        assertEqual(type(d.NS.DebugLog[name]), "function", "stub " .. name)
    end
end)

--- Each named member has the same type on the live and the library-absent load: the "asserted
--- present on both arms" half of testing-§8 for a seam whose stub is not a mirror of one table.
local function bothArms(label, get, members)
    local l, d = pair()
    for name, want in pairs(members) do
        assertEqual(type(get(l.NS)[name]), want, "live " .. label .. "." .. name)
        assertEqual(type(get(d.NS)[name]), want, "stub " .. label .. "." .. name)
    end
end

test("parity: the Pool stub carries the array-shape members, on both arms", function()
    -- members from: grep -nE "^function lib\.(New|Acquire|ReleaseAll|Counts)\(" libs/LibKa0s/Pool.lua
    -- (the array shape; nothing calls NS.Pool until the T7/T8 windows, the Keyed shape is not adopted)
    bothArms("NS.Pool", function(NS) return NS.Pool end,
        { New = "function", Acquire = "function", ReleaseAll = "function", Counts = "function" })
end)

test("parity: the Perf stub carries every member this addon reads, on both arms", function()
    -- members from: grep -rhoE "Perf[.:][A-Za-z]+" core/ modules/ settings/
    bothArms("NS.Perf", function(NS) return NS.Perf end,
        { on = "boolean", Note = "function", OnCommand = "function" })
end)

test("parity: the Core seam carries every member this addon reads, on both arms", function()
    -- members from: grep -rhoE "NS\.(Print|SafeToString|IsConcatSafe|SafeRegister[A-Za-z]*|ApplySkin|SKIN|MakeCloseButton|MakeResizable)" core/ modules/ settings/
    bothArms("NS", function(NS) return NS end, {
        Print = "function", SafeToString = "function", IsConcatSafe = "function",
        SafeRegisterEvent = "function", SafeRegisterUnitEvent = "function",
        SafeRegisterEvents = "function", ApplySkin = "function", SKIN = "table",
        MakeCloseButton = "function", MakeResizable = "function",
    })
    bothArms("NS.Util", function(NS) return NS.Util end, { print = "function" })
    local l, d = pair()
    assertTrue(l.NS.Print == l.NS.Util.print, "live: NS.Print is not NS.Util.print (architecture-§2)")
    assertTrue(d.NS.Print == d.NS.Util.print, "stub: NS.Print is not NS.Util.print (architecture-§2)")
end)

test("parity: the Widgets seam answers on both arms, nil being a real answer", function()
    -- members from: grep -rhoE "NS\.(MakeDropdown|MakeTestStrip|CloseMenu|HasWidgets)" core/ modules/
    bothArms("NS", function(NS) return NS end, {
        MakeDropdown = "function", MakeTestStrip = "function", CloseMenu = "function", HasWidgets = "function",
    })
    local l, d = pair()
    assertTrue(l.NS.HasWidgets(), "the live load has no Widgets library")
    assertFalse(d.NS.HasWidgets())
    assertEqual(d.NS.MakeDropdown(d.mocks.UIParent, 100), nil, "the stub drew a dead dropdown")
    assertEqual(d.NS.MakeTestStrip(d.mocks.UIParent, "x"), nil)
    d.NS.CloseMenu()
end)

test("parity: the Media seam answers on both arms, nil being a real answer", function()
    -- members from: grep -rhoE "NS\.(Icon|MediaFont)" core/ modules/ settings/
    bothArms("NS", function(NS) return NS end, { Icon = "function", MediaFont = "function" })
    local _, d = pair()
    assertEqual(d.NS.Icon("close"), nil, "the stub invented an icon path")
    assertEqual(d.NS.MediaFont("any"), nil, "the stub invented a font path")
end)

test("parity: the Env seam answers the TOC's version on both arms", function()
    -- members from: grep -rhoE "NS\.(Meta|Version)\b" core/ modules/ settings/
    bothArms("NS", function(NS) return NS end, { Meta = "function", Version = "function" })
    local l, d = pair()
    assertEqual(d.NS.Version(), l.NS.Version(), "the stub reads a different version")
    assertEqual(d.NS.Meta("Version"), l.NS.Meta("Version"))
end)

test("parity: the Toast stub carries a live toast instance's surface, and the degraded load toasts nothing", function()
    local l, d = pair()
    assertTrue(l.NS.HasToast(), "the live load has no Toast library")
    assertFalse(d.NS.HasToast())
    assertTrue(d.NS.BestToast.Instance() == d.NS.ToastStub, "the degraded load holds the stub")
    T.assertSurfaceParity(l.NS.BestToast.Instance(), d.NS.ToastStub, "Toast instance")
    assertFalse(d.NS.BestToast.Test(), "the stub shows nothing")
    d.NS.BestToast.Sync()
    d.NS.BestToast.Suspend()
    assertFalse(d.NS.BestToast.Diagnose().shown)
end)

test("parity: the hollow composers cost the library-absent load exactly the composed rows", function()
    -- red under: make a composer in settings/OptionsSetup.lua's stub emit rows, or add a row a page
    -- declares outside a composer (options-ui-§1: pin both counts and the delta)
    local l, d = pair()
    local MASTER_CONTROLS_ROWS = 7     -- enabled, visibility, scale, locked, console, minimap, test mode
    -- HUD > HUD Appearance: four font blocks of six, the spell bars' block of four and its row height,
    -- the damage chart's block of four with its height and column gap (each an `extra`, so it goes
    -- with the block), the chart background's color pair, and the pace bar's block of four.
    local APPEARANCE_ROWS = 4 * 6 + 4 + 1 + 4 + 2 + 2 + 4
    -- History > Results table: two bar blocks of four and a font block of six.
    local RESULTS_TABLE_ROWS = 2 * 4 + 6
    -- The rows the pages declare by hand (HUD's Race HUD tab, Race, History): a
    -- degraded load keeps every one of them (History's Include talents link, #6, the 18th; HUD's
    -- Pace bar range, the 19th; Show cooldown dots, #14, the 20th; History's Hidden items, P9, the 21st;
    -- HUD's Show near a training dummy and Race's Arm on a training dummy, #16, the 22nd and 23rd;
    -- General's New-best toast tab, #5, the 24th to the 27th; Race's Late-cast ignore list, #8, the
    -- 28th; Race's Training dummies tab, #9, the 29th and 30th; General's Skin tab, the seven skin.*
    -- rows the library's tab draws, skinning-§3, the 31st to the 37th).
    local PAGE_ROWS = 37
    local COMPOSED = MASTER_CONTROLS_ROWS + APPEARANCE_ROWS + RESULTS_TABLE_ROWS
    assertEqual(#l.NS.Schema, COMPOSED + PAGE_ROWS, "the full load's row count")
    assertEqual(#d.NS.Schema, PAGE_ROWS, "the library-absent load's row count")
    assertEqual(#l.NS.Schema - #d.NS.Schema, COMPOSED, "the gap is not the rows the hollow composers drop")
    for _, row in ipairs(d.NS.Schema) do
        assertTrue(row.group ~= "Master controls", row.path .. " survived the hollow composer")
        assertTrue(row.group ~= "HUD Appearance", row.path .. " survived the hollow composer")
        assertTrue(row.group ~= "Results table", row.path .. " survived the hollow composer")
    end
    -- The look still has its defaults with no rows: the HUD reads them through NS.GetSetting.
    assertEqual(d.NS.HudAppearance.Font("elapsed").size, 26)
    assertEqual(d.NS.HudAppearance.RowHeight(), 18)
end)
