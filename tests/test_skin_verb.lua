-- tests/test_skin_verb.lua — the reserved `skin` verb (LibKa0s v1.82.0, OptionsSkinPicker minor 3's
-- O.SkinVerb; DR-01 of Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-16):
-- a `skin` row after `config` runs NS.RunSkinVerb, which hands O.SkinVerb the first-run spec, so
-- `/dr skin` shows the picker a new profile shows whatever skin.pickerSeen says. Refused while the
-- addon is disabled (the dispatcher's gate), a gray line on every call in combat (the library's),
-- and the library-absent line without LibKa0s. LibKa0sSkinTester's tests/test_skin_verb.lua is the
-- reference this follows.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function bare(M)
    local out = {}
    for i, l in ipairs(M.__printed()) do out[i] = l:gsub("^|cff00ffff%[DR%]|r ", "") end
    return out
end

local function anyLine(lines, fragment)
    for _, l in ipairs(lines) do if l:find(fragment, 1, true) then return true end end
    return false
end

--- Logged in, the first-run picker taken down and the profile marked seen, so only the verb can
--- bring it back.
local function seenProfile(opts)
    local inst = T.load(opts)
    local NS, M = inst.NS, inst.mocks
    if NS.HideSkinPicker then NS.HideSkinPicker() end
    NS.SetByPath("skin.pickerSeen", true)
    return NS, M
end

--- Run `fn(calls)` with O.SkinPicker replaced by a recorder: each call's spec, in order.
local function spying(NS, fn)
    local O = NS.Helpers
    local real = O.SkinPicker
    local calls = {}
    O.SkinPicker = function(spec)
        calls[#calls + 1] = spec
        return { spy = true }
    end
    local ok, err = pcall(fn, calls)
    O.SkinPicker = real
    if not ok then error(err, 0) end
end

local function strings(M) return M.LibStub("LibKa0s-Options-1.0").SKIN_PICKER_STRINGS end

test("skin verb: the row sits right after config, with the library's help words", function()
    local NS, M = seenProfile()
    local at
    for i, c in ipairs(NS.COMMANDS) do
        if c[1] == "skin" then at = i end
    end
    assertTrue(at ~= nil, "a skin row")
    assertEqual(NS.COMMANDS[at - 1][1], "config", "after config")
    assertEqual(NS.COMMANDS[at][2], strings(M).VERB_HELP, "one wording for every host")
end)

test("skin verb: /dr skin shows the picker on a profile that has closed it", function()
    -- red under: no skin row (the dispatcher prints help for an unknown verb).
    local NS = seenProfile()
    spying(NS, function(calls)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 0, "a seen profile shows no first-run picker")
        NS.Slash:OnSlash("skin")
        assertEqual(#calls, 1, "the verb shows it")
        assertEqual(calls[1].owner, "DpsRace")
    end)
    assertEqual(NS.GetSetting("skin.pickerSeen"), true, "the verb writes nothing")
end)

test("skin verb: NS.RunSkinVerb hands O.SkinVerb this addon's first-run spec", function()
    local NS = seenProfile()
    local H = NS.Helpers
    local live, seen = H.SkinVerb, nil
    H.SkinVerb = function(spec) seen = spec; return nil, "queued" end
    local ok, why = NS.RunSkinVerb()
    H.SkinVerb = live
    assertTrue(type(seen) == "table", "a spec was handed over")
    local want = NS.SkinPickerSpec()
    for _, k in ipairs({ "owner", "get", "set", "page", "tab" }) do
        assertTrue(rawequal(seen[k], want[k]), "the first-run spec's " .. k)
    end
    assertEqual(ok, nil, "nothing shown")
    assertEqual(why, "queued", "the library's reason, passed on")
end)

test("skin verb: in combat every call prints the library's gray line and shows nothing", function()
    local NS, M = seenProfile()
    spying(NS, function(calls)
        local real = M.InCombatLockdown
        M.InCombatLockdown = function() return true end
        M.__resetPrinted()
        NS.Slash:OnSlash("skin")
        local first = bare(M)
        M.__resetPrinted()
        NS.Slash:OnSlash("skin")
        local second = bare(M)
        M.InCombatLockdown = real
        assertEqual(#calls, 0, "no picker mid-combat")
        assertTrue(anyLine(first, strings(M).VERB_COMBAT), "the first call says why")
        assertTrue(anyLine(second, strings(M).VERB_COMBAT), "and so does every later one")
    end)
end)

test("skin verb: refused while the addon is disabled, and no picker shows", function()
    local NS, M = seenProfile()
    NS.Slash:OnSlash("disable")
    spying(NS, function(calls)
        M.__resetPrinted()
        NS.Slash:OnSlash("skin")
        local out = bare(M)
        assertEqual(#out, 1, "one refusal line")
        assertEqual(out[1], M.LibStub("LibKa0s-Slash-1.0").DISABLED_LINE_FORMAT:format("Ka0s DPS Race", "/dr enable"))
        assertEqual(#calls, 0)
    end)
end)

test("skin verb: without LibKa0s the verb prints the library-absent line", function()
    local inst = T.load({ libFiles = {} })
    local M = inst.mocks
    M.__resetPrinted()
    inst.NS.Slash:OnSlash("skin")
    assertTrue(anyLine(bare(M), "/dr skin is unavailable: the LibKa0s library did not load."), "names the verb")
end)
