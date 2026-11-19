-- tests/test_reports.lua — the report verbs (debug-logging-§15, LibKa0s#79, the owner's ruling of
-- 2026-11-08): `/dr ignore show` and `/dr targetdummy show` write their lists to the debug console
-- through NS.DebugLog:Report, ungated, reveal a hidden console and print exactly one chat pointer. A
-- usage or refusal line inside a report verb stays in chat and writes nothing; the acknowledgment
-- `defaults` prints stays in chat beside the report. Library absent, the stub streams the report to
-- chat with no pointer.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local SPELLS = {
    [66] = "Invisibility", [1856] = "Vanish", [5384] = "Feign Death", [8690] = "Hearthstone",
    [191329] = "Hearthstone", [58984] = "Shadowmeld", [110959] = "Greater Invisibility", [29722] = "Incinerate",
}

local function spellClient(M)
    M.C_Spell = {
        GetSpellName = function(id) return SPELLS[id] end,
        GetSpellTexture = function(id) return 1000 + id end,
        GetSpellInfo = function(key)
            if type(key) ~= "number" or not SPELLS[key] then return nil end
            return { name = SPELLS[key], iconID = 1000 + key }
        end,
    }
end

local DEFAULT_LIST = {
    "Late-cast ignore list:",
    "  Invisibility (66)",
    "  Vanish (1856)",
    "  Feign Death (5384)",
    "  Hearthstone, all variants (8690)",
    "  Shadowmeld (58984)",
    "  Greater Invisibility (110959)",
}

local function fresh(opts)
    opts = opts or {}
    opts.mutate = opts.mutate or spellClient
    return T.load(opts)
end

--- `/dr <msg>`'s chat lines, without the chat tag.
local function said(inst, msg)
    inst.mocks.__resetPrinted()
    inst.NS.Slash:OnSlash(msg)
    local out = {}
    for i, l in ipairs(inst.mocks.__printed()) do out[i] = (tostring(l):gsub("^|cff00ffff%[DR%]|r ", "")) end
    return out
end

--- The console's lines under `tag`, the stamp and the tag taken off.
local function logged(inst, tag)
    local out, mark = {}, "| [" .. tag .. "] "
    for _, line in ipairs(inst.NS.DebugLog.buffer) do
        local at = line:find(mark, 1, true)
        if at then out[#out + 1] = line:sub(at + #mark) end
    end
    return out
end

local function joined(lines) return table.concat(lines, "\n") end

-- ── /dr ignore show ─────────────────────────────────────────────────────────────────────────────

test("reports: ignore show writes the list to the console, ungated, and points to it once in chat", function()
    local inst = fresh()
    local NS = inst.NS
    assertFalse(NS.DebugLog:IsEnabled(), "the fixture needs logging off")
    assertFalse(NS.DebugLog:IsShown(), "the fixture needs the console hidden")
    -- Falsification (testing-§12): written through the gated NS.Debug sink, the list never lands with
    -- logging off, and this case goes red on the body below.
    local out = said(inst, "ignore show")
    local want = { "/dr ignore show" }
    for _, l in ipairs(DEFAULT_LIST) do want[#want + 1] = l end
    assertEqual(joined(logged(inst, "Ignore")), joined(want), "the report's header, then the list")
    -- Falsification: printing the list line by line (the pre-#79 handler) gives eight chat lines here.
    assertEqual(#out, 1, joined(out))
    assertEqual(out[1], "ignore show: 8 lines written to the debug console. Use Copy to share it.")
    assertTrue(NS.DebugLog:IsShown(), "the console was not revealed")
    assertFalse(NS.DebugLog:IsEnabled(), "the report turned logging on")
end)

test("reports: a bare ignore is ignore show; an empty list is one chat line and writes nothing", function()
    local inst = fresh()
    local NS = inst.NS
    local out = said(inst, "ignore")
    assertEqual(#out, 1)
    assertEqual(out[1], "ignore show: 8 lines written to the debug console. Use Copy to share it.")
    assertTrue(NS.SetByPath("race.lateIgnore", ""))
    NS.DebugLog:Clear()
    NS.DebugLog:Hide()
    out = said(inst, "ignore show")
    assertEqual(joined(out), "The late-cast ignore list is empty.")
    assertEqual(#logged(inst, "Ignore"), 0, "a short answer wrote a report")
    assertFalse(NS.DebugLog:IsShown(), "a short answer opened the console")
end)

test("reports: ignore defaults acknowledges in chat, then reports the list", function()
    local inst = fresh()
    local NS = inst.NS
    assertTrue(NS.SetByPath("race.lateIgnore", "29722"))
    local out = said(inst, "ignore defaults")
    assertEqual(joined(out), "The late-cast ignore list is back to its defaults.\n"
        .. "ignore show: 8 lines written to the debug console. Use Copy to share it.")
    assertEqual(logged(inst, "Ignore")[2], "Late-cast ignore list:")
end)

test("reports: a usage or refusal inside ignore stays in chat and writes nothing to the console", function()
    local inst = fresh()
    local NS = inst.NS
    for _, msg in ipairs({ "ignore purge", "ignore add", "ignore add Frostbolt" }) do
        local out = said(inst, msg)
        assertEqual(#out, 1, msg)
    end
    assertEqual(#logged(inst, "Ignore"), 0, "a refusal wrote a report")
    assertFalse(NS.DebugLog:IsShown(), "a refusal opened the console")
end)

-- ── /dr targetdummy show ────────────────────────────────────────────────────────────────────────

test("reports: targetdummy show writes the list to the console with one chat pointer", function()
    local inst = fresh()
    local NS = inst.NS
    NS.DummyList.Add(99999, "single")
    local out = said(inst, "targetdummy show")
    local body = logged(inst, "Dummies")
    assertEqual(body[1], "/dr targetdummy show")
    assertEqual(body[2], "Your training dummies:")
    assertTrue(body[3]:find("Creature 99999", 1, true) ~= nil, joined(body))
    assertTrue(body[4]:find("^Built%-in training dummies: %d+, 0 switched off%.$") ~= nil, joined(body))
    assertEqual(#out, 1, joined(out))
    assertEqual(out[1], ("targetdummy show: %d lines written to the debug console. Use Copy to share it."):format(#body))
    assertTrue(NS.DebugLog:IsShown())
    assertFalse(NS.DebugLog:IsEnabled())
end)

test("reports: targetdummy defaults acknowledges in chat, then reports; a bad word is usage, no report", function()
    local inst = fresh()
    local NS = inst.NS
    NS.DummyList.Add(99999, "single")
    local out = said(inst, "targetdummy defaults")
    assertEqual(#out, 2, joined(out))
    assertEqual(out[1], "Your training dummies are cleared: only the built-in ones count.")
    assertTrue(out[2]:find("^targetdummy show: %d+ lines written to the debug console") ~= nil, out[2])
    NS.DebugLog:Clear()
    NS.DebugLog:Hide()
    out = said(inst, "targetdummy frobnicate")
    assertEqual(#out, 1)
    assertTrue(out[1]:find("Usage: /dr targetdummy", 1, true) ~= nil, out[1])
    assertEqual(#logged(inst, "Dummies"), 0)
    assertFalse(NS.DebugLog:IsShown())
end)

-- ── library absent ──────────────────────────────────────────────────────────────────────────────

test("reports: library absent, the stub streams each report to chat with no pointer", function()
    local inst = fresh({ libFiles = {} })
    local NS = inst.NS
    assertEqual(type(NS.DebugLog.Report), "function")
    assertEqual(type(NS.DebugLog.Serialize), "function")
    local out = said(inst, "ignore show")
    assertEqual(joined(out), joined(DEFAULT_LIST), "the list in chat, no header, no pointer")
    out = said(inst, "targetdummy show")
    assertTrue(out[1]:find("No training dummies of your own", 1, true) ~= nil, joined(out))
    assertFalse(joined(out):find("debug console", 1, true) ~= nil, "the stub printed a pointer")
    local lines = NS.DebugLog:Serialize({ a = 1 })
    assertEqual(#lines, 1)
end)
