-- tests/test_format.lua — modules/Format.lua: the one secret-safe number formatter, the race clock,
-- percentages, typed race lengths and the Arm refusal copy.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local function withFormatter()
    return T.load{ mutate = function(m) Widgets.install(m) end }.NS
end

test("format: Number abbreviates through the client's formatter, secret or plain", function()
    local NS = withFormatter()
    assertEqual(NS.Format.Number(2763000), "2.76M")
    assertEqual(NS.Format.Number(761540), "761.5K")
    assertEqual(NS.Format.Number(26560000), "26.56M")
    assertEqual(NS.Format.Number(812), "812")
    assertEqual(NS.Format.Number(T.secret(130600)), "130.6K", "a secret goes to the native seam")
    assertEqual(NS.Format.Number(nil), "")
end)

test("format: Number never does Lua arithmetic on a secret when no formatter exists", function()
    local NS = T.NS      -- the shared instance: no C_StringUtil, no AbbreviateNumbers
    local s = T.secret(1539711)
    local out = NS.Format.Number(s)
    assertTrue(out == s, "the secret itself goes to SetText, untouched")
    assertEqual(NS.Format.Number(1539711), "1.53M", "a plain number is abbreviated in Lua")
    assertEqual(NS.Format.Number(1234), "1.2K")
    assertEqual(NS.Format.Number(3e9), "3.00B")
end)

test("format: a formatter that renders the check value wrongly is not used", function()
    local inst = T.load{ mutate = function(m)
        m.C_StringUtil = { CreateAbbreviatedNumberFormatter = function()
            return { SetBreakpoints = function() end, FormatNumber = function() return "nonsense" end }
        end }
    end }
    assertEqual(inst.NS.Format.Number(2763000), "2.76M", "the Lua fallback answered")
end)

test("format: Clock is m:ss.t with tenths truncated; Length is m:ss", function()
    local F = T.NS.Format
    assertEqual(F.Clock(161.34), "2:41.3")
    assertEqual(F.Clock(180), "3:00.0")
    assertEqual(F.Clock(9.99), "0:09.9")
    assertEqual(F.Clock(-1), "0:00.0")
    assertEqual(F.Length(180), "3:00")
    assertEqual(F.Length(90), "1:30")
    assertEqual(F.Length(900), "15:00")
end)

test("format: Pct and Seconds take plain numbers", function()
    local F = T.NS.Format
    assertEqual(F.Pct(27.63), "27.6%")
    assertEqual(F.Pct(nil), "")
    assertEqual(F.Seconds(3.14), "+3.1")
end)

test("format: ParseLength accepts 90, 90s, 1:30, 3m and 1m30s, and rejects anything else", function()
    local F = T.NS.Format
    assertEqual(F.ParseLength("90"), 90)
    assertEqual(F.ParseLength("90s"), 90)
    assertEqual(F.ParseLength("1:30"), 90)
    assertEqual(F.ParseLength(" 3m "), 180)
    assertEqual(F.ParseLength("1m30s"), 90)
    assertEqual(F.ParseLength("0"), 0, "the range is Race.Arm's to refuse")
    assertNil(F.ParseLength("1:75"))
    assertNil(F.ParseLength("abc"))
    assertNil(F.ParseLength(""))
    assertNil(F.ParseLength(nil))
end)

test("format: ArmRefusal maps every Race.Arm reason to its line", function()
    local F = T.NS.Format
    assertEqual(F.ArmRefusal("in_combat"), "Leave combat to arm")
    assertTrue(F.ArmRefusal("pending"):find("waiting for its result", 1, true) ~= nil)
    assertTrue(F.ArmRefusal("busy"):find("already armed", 1, true) ~= nil)
    assertTrue(F.ArmRefusal("bad_length"):find("0:10 to 15:00", 1, true) ~= nil)
    assertTrue(F.ArmRefusal("meter_unavailable", "Restricted here"):find("Restricted here", 1, true) ~= nil)
    assertEqual(F.ArmRefusal("meter_unavailable"), "Blizzard's damage meter is not available on this client.")
    assertTrue(#F.ArmRefusal("disabled") > 0)
    assertTrue(#F.ArmRefusal("something new") > 0)
end)
