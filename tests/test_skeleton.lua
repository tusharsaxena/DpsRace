-- tests/test_skeleton.lua — the scaffold's own contract: the addon registers, both slash commands reach
-- the one dispatcher, the DB defaults load, the bus declares its four names, and the load order holds.

local T = _G.DPSRACE_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("skeleton: the addon registers with AceAddon under its folder name", function()
    local AceAddon = T.mocks.LibStub("AceAddon-3.0")
    assertEqual(AceAddon:GetAddon("DpsRace", true), NS)
    assertEqual(NS.addon, NS)
    assertEqual(NS.name, "DpsRace")
    assertEqual(NS.version, "0.1.0")
end)

test("skeleton: NS.Print is the tagged printer, reclaimed from AceConsole", function()
    assertEqual(NS.Print, NS.Util.print)
    T.mocks.__resetPrinted()
    NS.Print("hello")
    local printed = T.mocks.__printed()
    assertEqual(#printed, 1)
    assertTrue(printed[1]:find("[DR]", 1, true) ~= nil, "the line carries the cyan [DR] tag")
end)

test("skeleton: /dr and /dpsrace are both registered on the one dispatcher", function()
    local inst = T.load()
    local AceConsole = inst.mocks.LibStub("AceConsole-3.0")
    assertTrue(AceConsole.commands["dr"] ~= nil, "/dr is registered")
    assertTrue(AceConsole.commands["dpsrace"] ~= nil, "/dpsrace is registered")

    -- Route both through the real chat commands and see the SAME dispatcher answer.
    local seen = {}
    local real = inst.NS.Slash.OnSlash
    inst.NS.Slash.OnSlash = function(self, msg)
        seen[#seen + 1] = msg
        return real(self, msg)
    end
    AceConsole:__slash("dr", "version")
    AceConsole:__slash("dpsrace", "version")
    assertEqual(#seen, 2, "both commands reached NS.Slash:OnSlash")
    assertEqual(seen[1], "version")
    assertEqual(seen[2], "version")
    local printed = inst.mocks.__printed()
    local versions = 0
    for _, line in ipairs(printed) do
        if line:find("0.1.0", 1, true) then versions = versions + 1 end
    end
    assertEqual(versions, 2, "each command printed the version once")
end)

test("skeleton: the DB defaults load (global.runs empty, global.schema 1, schemaVersion stamped)", function()
    local g = NS.db.global
    assertEqual(type(g.runs), "table")
    assertEqual(next(g.runs), nil, "runs starts empty")
    assertEqual(g.schema, 1)
    assertEqual(g.schemaVersion, NS.SCHEMA_VERSION)
    assertEqual(NS.db.profile.enabled, true)
    assertEqual(NS.db.profile.visibility, "always")
    assertEqual(g.minimap.hide, false)
end)

test("skeleton: NS.MSG declares the six bus names, each Ka0s_DpsRace_<PascalCase>", function()
    local want = { "RACE_STATE_CHANGED", "RACE_BUZZER", "RACE_RESULT", "RUN_SAVED", "RUNS_CHANGED",
                   "SETTINGS_CHANGED" }
    for _, key in ipairs(want) do
        local wire = NS.MSG[key]
        assertEqual(type(wire), "string", key .. " is declared")
        assertTrue(wire:match("^Ka0s_DpsRace_%u%a+$") ~= nil, key .. " = " .. tostring(wire))
    end
    local count = 0
    for _ in pairs(NS.MSG) do count = count + 1 end
    assertEqual(count, #want, "no other names yet")
end)

test("skeleton: the produced interfaces exist", function()
    for _, name in ipairs({ "Print", "Debug", "DebugOnce", "SafeRegisterEvent", "MakeCloseButton",
                            "ApplySkin", "Icon", "MediaFont" }) do
        assertEqual(type(NS[name]), "function", "NS." .. name)
    end
    assertEqual(type(NS.Perf), "table")
    assertEqual(type(NS.Lifecycle), "table")
    assertEqual(NS.Lifecycle, NS.lifecycle)
    assertEqual(type(NS.Pool.New), "function")
    local verbs = {}
    for i, row in ipairs(NS.COMMANDS) do verbs[row[1]] = i end
    for _, verb in ipairs({ "config", "enable", "disable", "debug", "diagnostics", "perf" }) do
        assertTrue(verbs[verb] ~= nil, "COMMANDS carries " .. verb)
    end
end)

test("skeleton: every declared icon resolves to a shipped path", function()
    for _, name in ipairs({ "close", "copy", "clear", "settings", "lock", "unlock" }) do
        local path = NS.Icon(name)
        assertEqual(type(path), "string", name)
        assertTrue(path:find("Interface\\AddOns\\DpsRace\\", 1, true) == 1, path)
    end
    assertTrue(NS.Constants.FONT_MONO:find("DpsRace", 1, true) ~= nil, "the mono face is the shipped one")
end)

test("skeleton: every authored Lua file opens with the NS bootstrap and a path comment", function()
    for _, rel in ipairs(T.loadedAddonFiles) do
        local f = assert(io.open(T.root .. "/" .. rel, "r"))
        local first = (f:read("*l") or ""):gsub("\r$", "")
        local second = (f:read("*l") or ""):gsub("\r$", "")
        f:close()
        assertTrue(first == "local addonName, NS = ..." or first == "local _, NS = ...", rel .. ": " .. first)
        assertTrue(second:find("-- " .. rel .. " ", 1, true) == 1, rel .. " line 2: " .. second)
    end
end)
