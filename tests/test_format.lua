-- tests/test_format.lua — modules/Format.lua: the one secret-safe number formatter, the race clock,
-- percentages, typed race lengths and the Arm refusal copy. Format.Number never draws a raw decimal
-- (Combat Trail plan v0.2 E3, its A5 ported): a plain number abbreviates in Lua; a secret goes to the
-- first client formatter that passes both the integer and the fractional check; with none trusted, to
-- AbbreviateNumbers, and the raw secret is the last resort.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)
local Formatter = dofile(T.root .. "/tests/mock_formatter.lua")(T)

-- 634/21 K: a raw per-second rate, the shape Combat Trail's live tile drew unfloored (its plan v0.2 A5).
local FRACTION = 30190.4761904

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

-- A fresh instance with the scripted constructors (`spec`, tests/mock_formatter.lua), or none.
local function fresh(spec)
    local inst = T.load{ mutate = function(m) if spec then Formatter.install(m, spec) end end }
    return inst.NS, inst.mocks, inst
end

local function logged(inst, needle)
    local n = 0
    for _, line in ipairs(inst.NS.DebugLog.buffer) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

-- The values a formatter was handed after its two checks.
local function handedAfterChecks(f)
    return #f.seen - 2
end

test("format: a plain fractional DPS abbreviates in Lua, never through the client formatter", function()
    local NS, m = fresh{ abbreviated = "raw" }
    assertEqual(NS.Format.Number(77.142857), "77", "no raw decimals")
    assertEqual(NS.Format.Number(FRACTION), "30.1K")
    assertEqual(NS.Format.Number(2763000), "2.76M")
    assertEqual(NS.Format.Number(812), "812")
    assertEqual(NS.Format.Number(nil), "")
    for _, f in ipairs(m.__formatters) do
        assertEqual(handedAfterChecks(f), 0, "a plain number never reaches " .. f.name)
    end
end)

test("format: a secret goes to a formatter that passes both checks", function()
    local NS, m = fresh{ abbreviated = "floor" }
    assertEqual(NS.Format.Number(T.secret(FRACTION)), "30.1K")
    assertEqual(NS.Format.Number(T.secret(130600)), "130.6K")
    local f = m.__formatters[1]
    assertTrue(T.isSecret(f.seen[#f.seen]), "the secret itself was handed over")
    NS.Format.Number(77.142857)
    assertEqual(handedAfterChecks(f), 2, "a plain number skips even a trusted formatter")
end)

test("format: a formatter that renders a fraction raw fails the check, and the next constructor answers", function()
    local NS, m = fresh{ abbreviated = "raw", numeric = "floor" }
    assertEqual(NS.Format.Number(T.secret(FRACTION)), "30.1K")
    assertEqual(#m.__formatters, 2, "both constructors were tried")
    assertEqual(m.__formatters[1].name, "abbreviated", "in order")
    assertEqual(handedAfterChecks(m.__formatters[1]), 0, "the raw formatter is never used")
    assertEqual(handedAfterChecks(m.__formatters[2]), 1, "the numeric-rule formatter served the secret")
end)

test("format: a secret with no trusted formatter goes to AbbreviateNumbers", function()
    local NS, m = fresh{ abbreviated = "raw", numeric = "raw", abbreviate = true }
    local s = T.secret(FRACTION)
    assertEqual(NS.Format.Number(s), "abbr")
    assertEqual(#m.__abbreviated, 1)
    assertTrue(m.__abbreviated[1] == s, "the secret itself, untouched")
end)

-- The client's formatters answer a secret with a secret string. Lua 5.1 cannot trap `out ~= nil`
-- against a wrapper (the kit's secrets.lua: `==` against a non-table never consults __eq), so the
-- case asserts it explicitly: Format's presence test on a client answer is Secrets.IsPresent, which
-- never compares the value, and no `~= nil` / `== nil` on a client answer is left in the file
-- (Combat Trail plan v0.2 F1b, its F1a ported).
test("format: a secret the client formatter answers with a secret string goes to SetText untouched", function()
    local inst = T.load{ mutate = function(m)
        Formatter.install(m, { abbreviated = "floor", abbreviate = true })
        local util = m.C_StringUtil
        local make = util.CreateAbbreviatedNumberFormatter
        util.CreateAbbreviatedNumberFormatter = function()
            local f = make()
            local plain = f.FormatNumber
            function f:FormatNumber(v)
                local out = plain(self, v)
                if T.isSecret(v) then return T.secret(out) end
                return out
            end
            return f
        end
    end }
    local NS = inst.NS
    local asked = 0
    local present = NS.Secrets.IsPresent
    NS.Secrets.IsPresent = function(v) asked = asked + 1; return present(v) end
    local out = NS.Format.Number(T.secret(FRACTION))
    NS.Secrets.IsPresent = present
    assertTrue(T.isSecret(out), "the formatter's secret string itself")
    assertEqual(T.reveal(out), "30.1K")
    assertTrue(asked >= 1, "the answer's presence asked of Secrets.IsPresent")
    local fh = assert(io.open(T.root .. "/modules/Format.lua", "rb"))
    local src = fh:read("*a")
    fh:close()
    assertTrue(not src:find("out%s*[~=]=%s*nil"), "no comparison of a client answer against nil")
end)

test("format: Secrets.IsPresent answers a secret and a plain value without comparing either", function()
    local NS = fresh()
    local restore = T.installSecretValue()
    local S = NS.Secrets
    local ok, err = pcall(function()
        assertTrue(S.IsPresent(T.secret("30.1K")), "a secret string is present")
        assertTrue(S.IsPresent(T.secret(false)), "a secret false is present")
        assertTrue(S.IsPresent("x") and S.IsPresent(0) and S.IsPresent(false), "plain values are present")
        assertTrue(not S.IsPresent(nil), "nil is absent")
    end)
    restore()
    assert(ok, err)
end)

test("format: the debug log names the path that served a number, once per change", function()
    local NS, _, inst = fresh{ abbreviated = "raw", numeric = "floor" }
    NS.State.debug = true
    NS.Format.Number(T.secret(FRACTION))
    NS.Format.Number(T.secret(FRACTION))
    assertEqual(logged(inst, "[Format] numbers served by the client formatter (CreateNumericRuleFormatter)"), 1)
    assertEqual(logged(inst, "[Format] CreateAbbreviatedNumberFormatter rendered "), 1,
        "the build names the constructor it passed over")
    NS.Format.Number(12.5)
    assertEqual(logged(inst, "[Format] numbers served by Lua (plain)"), 1)
end)

test("format: a refused or failing constructor is skipped", function()
    local inst = T.load{ mutate = function(m)
        m.C_StringUtil = {
            CreateAbbreviatedNumberFormatter = function() error("refused") end,
            CreateNumericRuleFormatter = function()
                return { SetBreakpoints = function() end, FormatNumber = function() return "nonsense" end }
            end,
        }
    end }
    local s = T.secret(5)
    assertTrue(inst.NS.Format.Number(s) == s, "neither was trusted")
    assertEqual(inst.NS.Format.Number(2763000), "2.76M")
    assertEqual(inst.NS.Format.Number(-1234), "-1.2K")
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

test("format: RunTime is the length and the tail, or the time in combat against the length", function()
    local F = T.NS.Format
    local function run(status, result, length)
        return { status = status, race = { length = length or 120 }, result = result }
    end
    assertEqual(F.RunTime(run("complete", { tail = 11.05 })), "2:00 +11.1s")
    assertEqual(F.RunTime(run("complete", { tail = 0 })), "2:00", "no tail, no suffix")
    assertEqual(F.RunTime(run("complete", {})), "2:00")
    assertEqual(F.RunTime(run("incomplete", { endedAt = 63.98 })), "1:04 / 2:00")
    assertEqual(F.RunTime(run("lost", nil)), "2:00")
    assertEqual(F.RunTime(run("complete", { tail = 6.29 }), "ff9e9ead"), "2:00 |cff9e9ead+6.3s|r",
        "the tail in its own color when one is given")
    T.assertTrue(math.abs(F.RunSeconds(run("complete", { tail = 11.05 })) - 131.05) < 1e-9)
    assertEqual(F.RunSeconds(run("incomplete", { endedAt = 63.98 })), 63.98)
    assertEqual(F.RunSeconds(run("lost", nil)), 120)
end)
