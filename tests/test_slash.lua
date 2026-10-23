-- tests/test_slash.lua — the slash descriptor: the verb table, bare /dr, help, enable/disable through
-- the seam, the debug verb, and the library-absent dispatcher.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function lines(M)
    local out = {}
    for _, l in ipairs(M.__printed()) do out[#out + 1] = l end
    return out
end

local function anyLine(M, needle)
    for _, l in ipairs(M.__printed()) do
        if l:find(needle, 1, true) then return true end
    end
    return false
end

test("slash: bare /dr opens the settings panel", function()
    local inst = T.load()
    local opened = 0
    inst.NS.OpenOptionsPanel = function() opened = opened + 1 end
    inst.NS.Slash:OnSlash("")
    assertEqual(opened, 1)
end)

test("slash: `options` is the legacy spelling of `config`", function()
    local inst = T.load()
    local opened = 0
    inst.NS.OpenOptionsPanel = function() opened = opened + 1 end
    inst.NS.Slash:OnSlash("options")
    assertEqual(opened, 1)
end)

test("slash: help lists every COMMANDS verb, in order", function()
    local inst = T.load()
    inst.mocks.__resetPrinted()
    inst.NS.Slash:OnSlash("help")
    local text = table.concat(lines(inst.mocks), "\n")
    local last = 0
    for _, row in ipairs(inst.NS.COMMANDS) do
        local at = text:find("/dr " .. row[1], 1, true)
        assertTrue(at ~= nil, "help names " .. row[1])
        assertTrue(at > last, row[1] .. " is in COMMANDS order")
        last = at
    end
end)

test("slash: the landing page's rows come from the same table", function()
    local inst = T.load()
    local rows = inst.NS.Slash:LandingRows()
    assertEqual(#rows, #inst.NS.COMMANDS)
end)

test("slash: disable and enable write the `enabled` row through the seam and echo it", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    M.__resetPrinted()
    NS.Slash:OnSlash("disable")
    assertEqual(NS.db.profile.enabled, false)
    assertTrue(NS.IsDisabled())
    assertTrue(anyLine(M, "enabled"), "the stored value is echoed")
    NS.Slash:OnSlash("enable")
    assertEqual(NS.db.profile.enabled, true)
    assertFalse(NS.IsStoodDown())
end)

test("slash: `debug on`/`off` flip the session flag; bare `debug` toggles only the window", function()
    local inst = T.load()
    local NS = inst.NS
    NS.Slash:OnSlash("debug on")
    assertTrue(NS.State.debug)
    NS.Slash:OnSlash("debug off")
    assertFalse(NS.State.debug)
    local shown = NS.DebugLog:IsShown()
    NS.Slash:OnSlash("debug")
    assertEqual(NS.DebugLog:IsShown(), not shown)
    assertFalse(NS.State.debug, "the window toggle leaves the flag alone")
    assertEqual(NS.db.profile.debug, nil, "the flag is never stored")
end)

test("slash: `perf` is the host's verb and prints the harness's lines", function()
    local inst = T.load()
    inst.mocks.__resetPrinted()
    inst.NS.Slash:OnSlash("perf")
    assertTrue(#inst.mocks.__printed() > 0)
end)

test("slash: the schema CLI reads and writes through the seam", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    NS.Slash:OnSlash("set visibility never")
    assertEqual(NS.db.profile.visibility, "never")
    M.__resetPrinted()
    NS.Slash:OnSlash("get visibility")
    assertTrue(anyLine(M, "never"))
    NS.Slash:OnSlash("reset visibility")
    assertEqual(NS.GetSetting("visibility"), "always")
end)

test("slash: `resetall` asks first, through the one popup", function()
    local inst = T.load()
    local shown = {}
    inst.mocks.StaticPopup_Show = function(name) shown[#shown + 1] = name end
    inst.NS.Slash:OnSlash("resetall")
    assertEqual(shown[1], "DPSRACE_RESET_ALL")
end)

test("slash: the stub's refusal format is byte-equal to the live library's", function()
    local degraded = T.load{ libFiles = {} }
    T.assertLibraryConstant(degraded.NS.Slash.__stubFormat, "LibKa0s-Slash-1.0", "DISABLED_LINE_FORMAT")
end)

test("slash: library absent, /dr still answers, and enable/disable still land", function()
    local inst = T.load{ libFiles = {} }
    local NS, M = inst.NS, inst.mocks
    M.__resetPrinted()
    NS.Slash:OnSlash("version")
    assertTrue(anyLine(M, "0.1.0"))
    NS.Slash:OnSlash("disable")
    assertEqual(NS.db.profile.enabled, false)
    assertTrue(NS.IsDisabled(), "the written-through switch still took the hold")
    NS.Slash:OnSlash("enable")
    assertEqual(NS.db.profile.enabled, true)
    assertFalse(NS.IsStoodDown())
    M.__resetPrinted()
    NS.Slash:OnSlash("list")
    assertTrue(anyLine(M, "LibKa0s library did not load"), "the schema CLI names the missing library")
end)

test("slash: the stub's live-verb set is the library's LIVE_VERBS, no more and no less", function()
    local lib = T.mocks.LibStub("LibKa0s-Slash-1.0")
    local want, got = {}, {}
    for _, v in ipairs(lib.LIVE_VERBS) do want[#want + 1] = v end
    for v in pairs(T.NS.SLASH_LIVE_VERBS) do got[#got + 1] = v end
    table.sort(want)
    table.sort(got)
    assertEqual(table.concat(got, ","), table.concat(want, ","))
end)

test("slash: the stub carries no library string but the refusal format", function()
    -- red under: put a copy of the library's HELP_HEADER, VERSION or UNKNOWN_COMMAND back in the stub
    local strings = T.mocks.LibStub("LibKa0s-Slash-1.0").STRINGS
    local inst = T.load{ libFiles = {} }
    local NS, M = inst.NS, inst.mocks
    M.__resetPrinted()
    for _, verb in ipairs({ "help", "version", "nosuchverb" }) do NS.Slash:OnSlash(verb) end
    local printed = table.concat(lines(M), "\n")
    for _, key in ipairs({ "HELP_HEADER", "UNKNOWN_COMMAND", "VERSION" }) do
        local pattern = "^" .. strings[key]:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", ".-") .. "$"
        for line in printed:gmatch("[^\n]+") do
            local bare = line:gsub("^|cff00ffff%[DR%]|r ", "")
            assertFalse(bare:find(pattern) ~= nil, key .. " copied into the stub: " .. bare)
        end
    end
end)
