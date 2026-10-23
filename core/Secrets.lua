local _, NS = ...
-- core/Secrets.lua — the ONLY file that inspects a value that may be secret (spec §8 rule 1): the
-- LibKa0s-Compat guards with their stub arm, plain-number conversion and the bounded array walk.
--
-- THE CONTRACT (WoW 12.0 secret values), measured by the probe (spec §2): while the Combat addon
-- restriction is active, meter numbers, spell IDs, GUIDs and the isLocalPlayer flag arrive
-- SECRET, and a value captured then STAYS secret after combat. Tainted code may store one, pass it,
-- put it in a table VALUE, hand it to a widget setter or NumericRuleFormatter:FormatNumber, and
-- string.format it. It may NOT do arithmetic on it, compare it, truth-test a secret boolean, key a
-- table with it, apply `#` to it or index it. A NON-boolean secret may be tested for nil-ness, which
-- is the one operation SafeIterate leans on.
--
-- Everywhere else in the addon a meter value is an opaque handle. A module that needs to know
-- something about one asks this file; modules/Meter.lua asks on the read path, and nothing on the
-- live path asks at all.
--
-- DEGRADATION: every member is correct with the secrets system ABSENT (an older client, the headless
-- harness): nothing is secret, everything is accessible, iteration is plain ipairs semantics.
--
-- No perf brackets here: core/PerfSetup.lua loads after this file, and a per-value NS lookup is the
-- cost the perf contract forbids. Callers carry the brackets.

local Secrets = {}
NS.Secrets = Secrets

-- ---------------------------------------------------------------------------
-- The three guards: LibKa0s-Compat-1.0's, with the stub arm.
-- ---------------------------------------------------------------------------
--
-- THE GUARD ARM is a deliberate, documented duplication (LibKa0s docs/api/Compat/version-1-docs.md,
-- "Guards: the stub re-implements the body"). "The library is missing" is not "the client has no
-- secrets system": a stub answering IsSecret -> false on a 12.x client would send a secret into a
-- comparison mid-pull, on exactly the degraded path the stub exists to survive. The client globals
-- are read BARE and at CALL time, as the library reads them, so the harness's mock reaches both arms.

local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

local function isSecretStub(v)
    local fn = issecretvalue
    if not fn then return false end
    return fn(v) and true or false
end

local function canAccessStub(v)
    local fn = canaccessvalue
    if fn then return fn(v) and true or false end
    return not isSecretStub(v)
end

local function isSafeKeyStub(v)
    if isSecretStub(v) then return false end
    return v ~= nil
end

--- Whether `v` is a secret value. False on a client without the secrets system.
--- @param v any
--- @return boolean
Secrets.IsSecret = CompatLib and CompatLib.IsSecret or isSecretStub

--- Whether this context may look at `v`: the question that decides whether arithmetic or a
--- comparison on it is legal. A plain value always answers true.
--- @param v any
--- @return boolean
Secrets.CanAccess = CompatLib and CompatLib.CanAccess or canAccessStub

--- Whether `v` may be a table KEY right now (not secret, not nil).
--- @param v any
--- @return boolean
Secrets.IsSafeKey = CompatLib and CompatLib.IsSafeKey or isSafeKeyStub

-- ---------------------------------------------------------------------------
-- Value conversion
-- ---------------------------------------------------------------------------

--- Whether `v` is present but may not be looked at: secret, or inaccessible to this context. nil is
--- absent, not sealed. modules/Meter.lua asks this to tell "the session is still sealed" apart from
--- "the field is missing".
--- @param v any
--- @return boolean
function Secrets.IsSealed(v)
    if Secrets.IsSecret(v) then return true end
    return not Secrets.CanAccess(v)
end

--- `v` as a plain Lua number, or nil when it is nil, secret, inaccessible or not a number. The
--- secret test runs FIRST, so a secret never meets type() on a client where type() answers its
--- underlying type.
--- @param v any
--- @return number|nil
function Secrets.PlainNumber(v)
    if Secrets.IsSealed(v) then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

--- True only when `v` is accessible and truthy. `if src.isLocalPlayer then` raises on a secret
--- boolean; an inaccessible flag reads as "no claim" (false), the safe answer for every caller.
--- @param v any
--- @return boolean
function Secrets.PlainTruth(v)
    if Secrets.IsSealed(v) then return false end
    return v and true or false
end

--- True only when both operands are accessible and equal. One sealed operand answers false without
--- the comparison ever running.
--- @param a any
--- @param b any
--- @return boolean
function Secrets.PlainEquals(a, b)
    if Secrets.IsSealed(a) or Secrets.IsSealed(b) then return false end
    return a == b
end

-- ---------------------------------------------------------------------------
-- Table inspection
-- ---------------------------------------------------------------------------

--- Whether this context may read the CONTENTS of `t`. A non-table answers false. Without the client
--- globals every table is readable.
--- @param t any
--- @return boolean
function Secrets.CanAccessTable(t)
    if type(t) ~= "table" then return false end
    local can = canaccesstable
    if can then return can(t) and true or false end
    local isSecretTable = issecrettable
    if isSecretTable then return not isSecretTable(t) end
    return true
end

-- Hard ceiling on one walk. `#` is forbidden on a secret and a table dense past any sane length would
-- spin the client; 512 is far beyond any real spell list or session list.
local ITERATION_LIMIT = 512
Secrets.ITERATION_LIMIT = ITERATION_LIMIT

--- Walk a possibly-secret array, calling `fn(i, e)` per entry; `fn` may return false to stop.
---
--- Never applies `#` and never uses ipairs; refuses an inaccessible table (answers 0); stops at the
--- first nil (a nil-ness test, the one operation legal on a non-boolean secret); bounded at 512;
--- never inspects the entry it hands to `fn`.
--- @param arr table|nil
--- @param fn function
--- @return number count  how many entries were visited
function Secrets.SafeIterate(arr, fn)
    if type(fn) ~= "function" or not Secrets.CanAccessTable(arr) then return 0 end
    local count = 0
    for i = 1, ITERATION_LIMIT do
        local e = arr[i]
        if e == nil then break end
        count = i
        if fn(i, e) == false then break end
    end
    return count
end
