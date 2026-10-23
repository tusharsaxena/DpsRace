local _, NS = ...
-- modules/Format.lua — every number the UI draws: the one secret-safe abbreviating formatter (spec
-- §6.1), the race clock, percentages, a race length the player types, and the Arm refusal copy.
--
-- THE ONE FORMATTER. Abbreviating 2763000 to "2.76M" is a division, and a division on a secret value
-- raises in tainted code. Every live meter number is secret for the whole pull, so the live path hands
-- its values to the client's own formatter (C_StringUtil's abbreviated-number formatter, which takes a
-- secret and does the arithmetic natively) and to nothing else. This file owns the one instance:
-- built on first use, its breakpoints set and checked once, and given up for the session if the
-- client refuses them. A formatter that renders a check value wrongly is not used at all.
--
-- WHAT A RETURN VALUE IS. Format.Number answers "something FontString:SetText takes": a string, or,
-- on a client with no formatter at all, the secret itself (SetText accepts one). A caller may SetText
-- it and must do nothing else with it: no comparing, no concatenating, no measuring.
--
-- Everything else here (Clock, Pct, Seconds, Length) takes PLAIN numbers only: the race clock, a
-- read result or a stored run, never a live meter value.

local Format = {}
NS.Format = Format

local L = NS.L
local Secrets = NS.Secrets

-- The ladder, in the client's measured semantics: shown = n / (significandDivisor * fractionDivisor),
-- with log10(fractionDivisor) decimals, truncated. The mockup's figures: 761.5K, 2.76M, 26.56M.
local LADDER = {
    { breakpoint = 1, abbreviation = "", significandDivisor = 1, fractionDivisor = 1,
      abbreviationIsGlobal = false },
    { breakpoint = 1000, abbreviation = "K", significandDivisor = 100, fractionDivisor = 10,
      abbreviationIsGlobal = false },
    { breakpoint = 1000000, abbreviation = "M", significandDivisor = 10000, fractionDivisor = 100,
      abbreviationIsGlobal = false },
    { breakpoint = 1000000000, abbreviation = "B", significandDivisor = 10000000, fractionDivisor = 100,
      abbreviationIsGlobal = false },
}
-- The check a formatter must pass before it is trusted: what the ladder above renders this as.
local CHECK_VALUE, CHECK_TEXT = 2763000, "2.76M"

-- nil = not built yet, false = this client has none that works, else the instance.
local formatter

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Format", fmt, ...) end
end

local function newFormatter()
    local util = C_StringUtil
    local make = util and (util.CreateAbbreviatedNumberFormatter or util.CreateNumericRuleFormatter)
    if type(make) ~= "function" then return nil end
    local ok, f = pcall(make)
    if not ok or f == nil or type(f.SetBreakpoints) ~= "function" then return nil end
    return f
end

local function build()
    local f = newFormatter()
    if not f then return false end
    if not pcall(f.SetBreakpoints, f, LADDER) then
        debug("the client refused the breakpoints; numbers fall back")
        return false
    end
    local ok, out = pcall(f.FormatNumber, f, CHECK_VALUE)
    if not ok or out ~= CHECK_TEXT then
        debug("the formatter rendered the check value as %s; numbers fall back", tostring(out))
        return false
    end
    return f
end

local function instance()
    if formatter == nil then formatter = build() end
    return formatter or nil
end

--- Drop the formatter so the next number builds a fresh one (the harness's seam between instances).
function Format.Reset()
    formatter = nil
end

-- A plain number abbreviated in Lua, truncated as the client truncates.
local function abbreviate(n)
    local a = math.abs(n)
    local sign = n < 0 and "-" or ""
    if a >= 1e9 then return ("%s%.2fB"):format(sign, math.floor(a / 1e7) / 100) end
    if a >= 1e6 then return ("%s%.2fM"):format(sign, math.floor(a / 1e4) / 100) end
    if a >= 1e3 then return ("%s%.1fK"):format(sign, math.floor(a / 100) / 10) end
    return ("%s%d"):format(sign, math.floor(a))
end

--- A meter number as short text ("2.76M"), secret or plain. "" for nil.
--- @param v any  a number, possibly secret
--- @return any  a string, or the secret itself where no formatter exists (SetText takes either)
function Format.Number(v)
    if v == nil then return "" end
    local f = instance()
    if f then
        local ok, out = pcall(f.FormatNumber, f, v)
        if ok and out ~= nil then return out end
    end
    local plain = Secrets.PlainNumber(v)
    if plain then return abbreviate(plain) end
    local client = AbbreviateNumbers
    if type(client) == "function" then
        local ok, out = pcall(client, v)
        if ok and out ~= nil then return out end
    end
    return v
end

--- Seconds as the race clock shows them: "m:ss.t", tenths truncated ("2:41.3"). Plain numbers only.
--- @param seconds number
--- @return string
function Format.Clock(seconds)
    if type(seconds) ~= "number" or seconds < 0 then seconds = 0 end
    local tenths = math.floor(seconds * 10 + 1e-6)
    local whole = math.floor(tenths / 10)
    return ("%d:%02d.%d"):format(math.floor(whole / 60), whole % 60, tenths % 10)
end

--- A race length as "m:ss" ("3:00"). Plain numbers only.
--- @param seconds number
--- @return string
function Format.Length(seconds)
    if type(seconds) ~= "number" or seconds < 0 then seconds = 0 end
    local whole = math.floor(seconds + 0.5)
    return ("%d:%02d"):format(math.floor(whole / 60), whole % 60)
end

--- A percentage, one decimal ("27.6%"). Plain numbers only.
--- @param x number
--- @return string
function Format.Pct(x)
    if type(x) ~= "number" then return "" end
    return ("%.1f%%"):format(x)
end

--- An offset in seconds with its sign and one decimal ("+3.1"). Plain numbers only.
--- @param x number
--- @return string
function Format.Seconds(x)
    if type(x) ~= "number" then x = 0 end
    return L["+%.1f"]:format(x)
end

-- The shapes a typed race length may take: "90", "90s", "1:30", "3m", "1m30s".
local LENGTH_SHAPES = {
    { "^(%d+)$", function(n) return n end },
    { "^(%d+)s$", function(n) return n end },
    { "^(%d+)m$", function(m) return m * 60 end },
    { "^(%d+):([0-5]%d)$", function(m, s) return m * 60 + s end },
    { "^(%d+)m(%d+)s?$", function(m, s) if s < 60 then return m * 60 + s end end },
}

--- A race length typed by the player, in seconds, or nil when it is not one of the accepted shapes.
--- The range (10s-15:00) is NS.Race's to enforce: Arm answers "bad_length".
--- @param text string
--- @return number|nil
function Format.ParseLength(text)
    if type(text) ~= "string" then return nil end
    local s = text:lower():gsub("%s+", "")
    for _, shape in ipairs(LENGTH_SHAPES) do
        local a, b = s:match(shape[1])
        if a then return shape[2](tonumber(a), tonumber(b)) end
    end
    return nil
end

-- The copy for each NS.Race.Arm refusal (spec §4.1, §9).
local REFUSALS = {
    in_combat  = "Leave combat to arm",
    pending    = "A run is still waiting for its result: let it finish, or discard it.",
    busy       = "A race is already armed or running.",
    bad_length = "A race lasts from 0:10 to 15:00.",
}

--- The line that explains why NS.Race.Arm refused.
--- @param reason string  one of Arm's reason codes
--- @param detail string|nil  Blizzard's own reason, for "meter_unavailable"
--- @return string
function Format.ArmRefusal(reason, detail)
    if reason == "meter_unavailable" then
        if type(detail) == "string" and detail ~= "" then
            return L["Blizzard's damage meter is unavailable: %s"]:format(detail)
        end
        return L["Blizzard's damage meter is not available on this client."]
    end
    if reason == "disabled" then
        return (NS.StoodDownRefusal and NS.StoodDownRefusal()) or L["Ka0s DPS Race is turned off."]
    end
    local key = REFUSALS[reason]
    if key then return L[key] end
    return L["The race could not be armed."]
end
