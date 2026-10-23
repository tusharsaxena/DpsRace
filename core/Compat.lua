local _, NS = ...
-- core/Compat.lua — the compat family's root and only file (compat): every version-variant client
-- call the addon makes outside LibKa0s's majors, and every LibKa0s-Compat-1.0 member it consumes,
-- behind NS.Compat. No other file names these APIs. The family has no other file.
--
-- Routed through LibKa0s-Compat-1.0 (library-stack-§7), each with its library-absent stub:
--   Compat.IsSecret(v)  Compat.CanAccess(v)  Compat.IsSafeKey(v)   the three secret-value guards
-- Hand-written ladders across Retail patches:
--   Compat.CanAccessTable(t)     canaccesstable, then issecrettable, then "readable"
--   Compat.ChatSender()          C_ChatInfo.SendChatMessage, then the bare global (deprecated 11.2.0)
--   Compat.NewNumberFormatter()  C_StringUtil's abbreviated-number formatter constructor, then its
--                                numeric-rule constructor
-- Every client global is read at CALL time, so a client (or the harness's mock) that adds the API
-- later is seen.
--
-- THE GUARDS HAVE ONE CALLER. core/Secrets.lua binds them at FILE SCOPE (so this file loads first)
-- and stays the only file that inspects a value that may be secret (spec §8 rule 1): no other file
-- reaches NS.Compat's guards, and tests/test_meter.lua scans for it.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat

local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

-- ---------------------------------------------------------------------------
-- The secret guards: LibKa0s-Compat-1.0's, with the stub arm
-- ---------------------------------------------------------------------------
--
-- THE GUARD ARM is a deliberate, documented duplication (LibKa0s docs/api/Compat/version-1-docs.md,
-- "Guards: the stub re-implements the body"). "The library is missing" is not "the client has no
-- secrets system": a stub answering IsSecret -> false on a 12.x client would send a secret into a
-- comparison mid-pull, on exactly the degraded path the stub exists to survive. The client globals
-- are read BARE and at CALL time, as the library reads them, so the harness's mock reaches both arms.

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
Compat.IsSecret = CompatLib and CompatLib.IsSecret or isSecretStub

--- Whether this context may look at `v`. A plain value always answers true.
--- @param v any
--- @return boolean
Compat.CanAccess = CompatLib and CompatLib.CanAccess or canAccessStub

--- Whether `v` may be a table KEY right now (not secret, not nil).
--- @param v any
--- @return boolean
Compat.IsSafeKey = CompatLib and CompatLib.IsSafeKey or isSafeKeyStub

--- Whether this context may read the CONTENTS of table `t` (the caller has checked it is a table).
--- No LibKa0s major carries it. Without either client global every table is readable.
--- @param t table
--- @return boolean
function Compat.CanAccessTable(t)
    local can = canaccesstable
    if can then return can(t) and true or false end
    local isSecretTable = issecrettable
    if isSecretTable then return not isSecretTable(t) end
    return true
end

-- ---------------------------------------------------------------------------
-- Chat and number formatting
-- ---------------------------------------------------------------------------

--- The function that sends one chat message, `(text, chatType, languageID, target)`, or nil where
--- the client has none. The caller runs it in pcall.
--- @return function|nil
function Compat.ChatSender()
    local info = C_ChatInfo
    if info and type(info.SendChatMessage) == "function" then return info.SendChatMessage end
    local bare = SendChatMessage
    if type(bare) == "function" then return bare end
    return nil
end

--- A new instance of the client's number formatter (it takes a secret and abbreviates natively), or
--- nil where the client has none or refuses to build one. modules/Format.lua sets its breakpoints.
--- @return table|nil
function Compat.NewNumberFormatter()
    local util = C_StringUtil
    local make = util and (util.CreateAbbreviatedNumberFormatter or util.CreateNumericRuleFormatter)
    if type(make) ~= "function" then return nil end
    local ok, f = pcall(make)
    if not ok then return nil end
    return f
end
