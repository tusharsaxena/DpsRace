-- tests/test_secrets.lua — core/Secrets.lua: the guards over plain, nil and secret values on both arms
-- (LibKa0s-Compat and the stub), the conversions, and SafeIterate's four rules.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- Run `fn` with the kit's `issecretvalue` installed process-wide, and always put the global back.
local function withSecretValue(fn)
    local restore = T.installSecretValue()
    local ok, err = pcall(fn)
    restore()
    if not ok then error(err, 0) end
end

local function guardsAnswer(S)
    local s = T.secret(42)
    assertFalse(S.IsSecret(7), "a plain number is not secret")
    assertFalse(S.IsSecret(nil), "nil is not secret")
    assertTrue(S.IsSecret(s), "a wrapper is secret")
    assertTrue(S.CanAccess(7))
    assertTrue(S.CanAccess(nil))
    assertFalse(S.CanAccess(s), "without canaccessvalue a secret is inaccessible")
    assertEqual(S.PlainNumber(7), 7)
    assertEqual(S.PlainNumber(0), 0)
    assertNil(S.PlainNumber(nil))
    assertNil(S.PlainNumber(s), "a secret never converts")
    assertNil(S.PlainNumber("7"), "a string is not a number")
    assertTrue(S.IsSafeKey(7))
    assertFalse(S.IsSafeKey(nil))
    assertFalse(S.IsSafeKey(s))
end

test("secrets: IsSecret/PlainNumber over plain, nil and secret", function()
    withSecretValue(function() guardsAnswer(T.NS.Secrets) end)
end)

test("secrets: the guards are LibKa0s-Compat's when the library loaded", function()
    local Compat = T.mocks.LibStub("LibKa0s-Compat-1.0", true)
    assertTrue(Compat ~= nil, "LibKa0s-Compat-1.0 is in the vendored payload")
    assertEqual(T.NS.Secrets.IsSecret, Compat.IsSecret)
    assertEqual(T.NS.Secrets.CanAccess, Compat.CanAccess)
    assertEqual(T.NS.Secrets.IsSafeKey, Compat.IsSafeKey)
end)

test("secrets: the stub arm answers the same with the library absent", function()
    local inst = T.load{ libFiles = {}, init = false }
    local S = inst.NS.Secrets
    assertTrue(S ~= nil, "core/Secrets.lua loads without LibKa0s")
    withSecretValue(function() guardsAnswer(S) end)
end)

test("secrets: without the secrets system every value is plain", function()
    local S = T.NS.Secrets
    local t = {}
    assertFalse(S.IsSecret(t))
    assertTrue(S.CanAccess(t))
    assertTrue(S.CanAccessTable(t))
    assertFalse(S.CanAccessTable(nil))
    assertFalse(S.CanAccessTable(5))
end)

test("secrets: PlainTruth and PlainEquals never test a secret", function()
    withSecretValue(function()
        local S = T.NS.Secrets
        assertTrue(S.PlainTruth(true))
        assertFalse(S.PlainTruth(false))
        assertFalse(S.PlainTruth(nil))
        assertFalse(S.PlainTruth(T.secret(true)), "a secret flag is no claim")
        assertTrue(S.PlainEquals("a", "a"))
        assertFalse(S.PlainEquals("a", "b"))
        assertFalse(S.PlainEquals(T.secret("a"), T.secret("a")), "two secrets never meet ==")
        assertFalse(S.PlainEquals("a", T.secret("a")))
        assertTrue(S.IsSealed(T.secret(1)))
        assertFalse(S.IsSealed(nil), "absent is not sealed")
    end)
end)

test("secrets: SafeIterate stops at nil and at 512", function()
    local S = T.NS.Secrets
    local seen = {}
    local n = S.SafeIterate({ "a", "b", nil, "d" }, function(i, e) seen[i] = e end)
    assertEqual(n, 2, "stops at the first nil")
    assertEqual(seen[1], "a")
    assertEqual(seen[2], "b")
    assertNil(seen[4], "nothing past the hole")

    local big = {}
    for i = 1, 600 do big[i] = i end
    local calls = 0
    assertEqual(S.SafeIterate(big, function() calls = calls + 1 end), 512)
    assertEqual(calls, 512, "bounded at 512")
    assertEqual(S.ITERATION_LIMIT, 512)

    assertEqual(S.SafeIterate({ 1, 2, 3 }, function(i) return i < 2 end), 2, "false stops the walk")
    assertEqual(S.SafeIterate(nil, function() end), 0)
    assertEqual(S.SafeIterate({ 1 }, nil), 0)
end)

test("secrets: SafeIterate never applies # or ipairs and passes secrets through untouched", function()
    withSecretValue(function()
        local S = T.NS.Secrets
        -- `#` answers 0 on this table and ipairs stops at once: only an index walk sees the entries.
        local arr = setmetatable({}, {
            __len = function() error("# applied") end,
            __index = function(_, i) if i <= 3 then return T.secret(i) end end,
        })
        local got = {}
        assertEqual(S.SafeIterate(arr, function(i, e) got[i] = e end), 3)
        for i = 1, 3 do assertTrue(T.isSecret(got[i]), "entry " .. i .. " passed through") end
    end)
end)

test("secrets: SafeIterate refuses a table this context may not read", function()
    local inst = T.load{ mutate = function(m) m.canaccesstable = function() return false end end }
    local calls = 0
    assertEqual(inst.NS.Secrets.SafeIterate({ 1, 2 }, function() calls = calls + 1 end), 0)
    assertEqual(calls, 0)
    assertFalse(inst.NS.Secrets.CanAccessTable({}))
end)
