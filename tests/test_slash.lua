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

-- ── the feature verbs (spec §6.4) ────────────────────────────────────────────────────────────────

local FEATURE_VERBS = { "arm", "cancel", "hud", "results", "target", "test", "lock", "unlock" }
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)

--- The printed lines without the chat tag.
local function bare(M)
    local out = {}
    for i, l in ipairs(M.__printed()) do out[i] = (l:gsub("^|cff00ffff%[DR%]|r ", "")) end
    return out
end

--- An instance whose Race.Arm only records what it was asked.
local function armSpy()
    local inst = T.load()
    local asked = {}
    inst.NS.Race.Arm = function(length, count)
        asked[#asked + 1] = { length = length, count = count }
        return true
    end
    return inst, asked
end

test("slash: the feature verbs follow `version`, in the spec's order", function()
    local names = {}
    for _, row in ipairs(T.NS.COMMANDS) do names[#names + 1] = row[1] end
    local joined = table.concat(names, ",")
    assertTrue(joined:find("version," .. table.concat(FEATURE_VERBS, ","), 1, true) ~= nil, joined)
end)

test("slash: arm parses 90, 1:30, 3m and rejects 0 and 901", function()
    local inst, asked = armSpy()
    local NS, M = inst.NS, inst.mocks
    for _, text in ipairs({ "90", "1:30", "3m" }) do NS.Slash:OnSlash("arm " .. text) end
    assertEqual(#asked, 3)
    assertEqual(asked[1].length, 90)
    assertEqual(asked[2].length, 90)
    assertEqual(asked[3].length, 180)
    M.__resetPrinted()
    for _, text in ipairs({ "0", "901", "soon" }) do NS.Slash:OnSlash("arm " .. text) end
    assertEqual(#asked, 3, "an out-of-range or unreadable length reached Race.Arm")
    local out = bare(M)
    assertEqual(#out, 3)
    for _, line in ipairs(out) do assertEqual(line, NS.Format.ArmRefusal("bad_length")) end
end)

test("slash: a bare arm uses the last length, and an armed length becomes the last one", function()
    local inst, asked = armSpy()
    local NS = inst.NS
    NS.Slash:OnSlash("arm")
    assertEqual(asked[1].length, 180, "no length raced yet: the default race length")
    NS.Slash:OnSlash("arm 1:30")
    NS.Slash:OnSlash("arm")
    assertEqual(asked[3].length, 90)
    assertEqual(NS.db.profile.race.lastLength, 90)
end)

test("slash: arm prints the refusal line Race.Arm's reason maps to", function()
    local f = RaceClock.new()
    local NS, M = f.NS, f.M
    M.__inCombat = true
    M.__resetPrinted()
    NS.Slash:OnSlash("arm 60")
    assertEqual(NS.Race.State(), "idle")
    assertEqual(bare(M)[1], NS.Format.ArmRefusal("in_combat"))
end)

test("slash: arm then cancel goes armed and back to idle, one line each", function()
    local f = RaceClock.new()
    local NS, M = f.NS, f.M
    M.__resetPrinted()
    NS.Slash:OnSlash("arm 60")
    assertEqual(NS.Race.State(), "armed")
    local armed = bare(M)
    assertEqual(#armed, 1)
    assertTrue(armed[1]:find("^Armed: 1:00") ~= nil, armed[1])
    M.__resetPrinted()
    NS.Slash:OnSlash("cancel")
    assertEqual(NS.Race.State(), "idle")
    assertEqual(#bare(M), 1)
    M.__resetPrinted()
    NS.Slash:OnSlash("cancel")
    assertEqual(bare(M)[1], "Nothing to cancel.")
end)

test("slash: target prints name, npcID and category", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    M.__setTarget({ guid = "Creature-0-3767-2393-123-243205-00001A2B3C", name = "Reinforced Golem" })
    M.__resetPrinted()
    NS.Slash:OnSlash("target")
    assertEqual(bare(M)[1], "Target: Reinforced Golem \194\183 creature 243205 \194\183 category Boss-level")
    M.__setTarget(nil)
    M.__resetPrinted()
    NS.Slash:OnSlash("target")
    assertEqual(bare(M)[1], "No target.")
end)

test("slash: an uncataloged target reads as Other", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    M.__setTarget({ guid = "Creature-0-1-2-3-99999-0000000000", name = "Angry Boar" })
    M.__resetPrinted()
    NS.Slash:OnSlash("target")
    assertEqual(bare(M)[1], "Target: Angry Boar \194\183 creature 99999 \194\183 category Other")
end)

test("slash: hud show, hide and toggle; a bare hud toggles", function()
    local inst = T.load()
    local NS = inst.NS
    NS.Slash:OnSlash("hud show")
    assertTrue(NS.Hud.IsShown())
    NS.Slash:OnSlash("hud hide")
    assertFalse(NS.Hud.IsShown())
    NS.Slash:OnSlash("hud toggle")
    assertTrue(NS.Hud.IsShown())
    NS.Slash:OnSlash("hud")
    assertFalse(NS.Hud.IsShown())
    inst.mocks.__resetPrinted()
    NS.Slash:OnSlash("hud sideways")
    assertTrue(bare(inst.mocks)[1]:find("/dr hud show", 1, true) ~= nil, "an unknown word prints the usage")
end)

test("slash: results opens the Results window; results bests opens the bests", function()
    local inst = T.load()
    local NS = inst.NS
    NS.Slash:OnSlash("results")
    assertTrue(NS.Results.IsShown())
    assertEqual(NS.Results.Tab(), "runs")
    NS.Slash:OnSlash("results bests")
    assertEqual(NS.Results.Tab(), "bests")
end)

test("slash: test turns test mode on and off through the Master controls row", function()
    local inst = T.load()
    local NS = inst.NS
    NS.Slash:OnSlash("test")
    assertTrue(NS.Preview.IsActive())
    assertTrue(NS.GetSetting("state.testMode"))
    NS.Slash:OnSlash("test")
    assertFalse(NS.Preview.IsActive())
end)

test("slash: lock and unlock write the Lock frame row through the seam and echo it", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    M.__resetPrinted()
    NS.Slash:OnSlash("lock")
    assertEqual(NS.db.profile.locked, true)
    assertTrue(NS.Hud.locked, "the row's reaction ran")
    assertTrue(anyLine(M, "locked"))
    NS.Slash:OnSlash("unlock")
    assertEqual(NS.db.profile.locked, false)
end)

test("slash: /dr and /dpsrace both dispatch", function()
    local inst = T.load()
    local M = inst.mocks
    local console = M.LibStub("AceConsole-3.0")
    for _, command in ipairs({ "dr", "dpsrace" }) do
        assertTrue(console.commands[command] ~= nil, "/" .. command .. " is not registered")
        M.__resetPrinted()
        console:__slash(command, "version")
        assertTrue(anyLine(M, "0.1.0"), "/" .. command .. " did not reach the dispatcher")
    end
end)

test("slash: feature verbs answer the enable line while disabled", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    assertTrue(NS.SetByPath("enabled", false))
    local refusal = NS.Slash:DisabledLine()
    for _, verb in ipairs(FEATURE_VERBS) do
        M.__resetPrinted()
        NS.Slash:OnSlash(verb .. " 60")
        local out = bare(M)
        assertEqual(#out, 1, verb)
        assertEqual(out[1], refusal, verb)
    end
    assertEqual(NS.Race.State(), "idle")
    assertFalse(NS.Preview.IsActive())
    assertFalse(NS.Hud.wanted)
    assertEqual(NS.db.profile.locked, false)
end)

test("slash: the Arm or cancel key arms the last length, then cancels; a pending result is kept", function()
    local f = RaceClock.new()
    local NS = f.NS
    local key = assert(f.M._G.DpsRaceArmToggle, "no DpsRaceArmToggle button")
    assertEqual(f.M._G["BINDING_NAME_CLICK DpsRaceArmToggle:LeftButton"], "Arm or cancel race", "its label")
    key:__fire("OnClick", "LeftButton", true)
    assertEqual(NS.Race.State(), "armed")
    key:__fire("OnClick", "LeftButton", true)
    assertEqual(NS.Race.State(), "idle")
    -- Running, then past the buzzer: the key cancels a running race but never discards a result.
    assertTrue(f:arm(30))
    f:start(25)
    f:to(130)
    assertEqual(NS.Race.State(), "stopping")
    key:__fire("OnClick", "LeftButton", true)
    assertEqual(NS.Race.State(), "stopping", "a key press discarded a pending result")
end)
