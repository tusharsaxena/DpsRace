local _, NS = ...
-- core/Compat.lua — the compat family's root and only file (compat): every version-variant client
-- call the addon makes outside LibKa0s's majors, behind NS.Compat. No other file names these APIs.
--
-- Two members, each a ladder across Retail patches:
--   Compat.ChatSender()          C_ChatInfo.SendChatMessage, then the bare global (deprecated 11.2.0)
--   Compat.NewNumberFormatter()  C_StringUtil's abbreviated-number formatter constructor, then its
--                                numeric-rule constructor
-- Both are read at CALL time, so a client (or the harness's mock) that adds the API later is seen.
-- No LibKa0s-Compat-1.0 member is routed here: core/Secrets.lua binds that major's secret guards.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat

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
