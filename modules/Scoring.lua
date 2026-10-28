local _, NS = ...
-- modules/Scoring.lua — the scoring rules (spec §5): the late-cast test with its grace (§5.2), DPS from
-- the addon's own clock (§5.1), the quiet wait before the result read (§4.5) and a run's flag set in
-- display order (§5.4).
--
-- PURE but for one injected seam. No WoW API and no meter value: every input is a plain number already
-- stored on the run (the damage comes from Meter.ReadSession after combat). NS.L is read at CALL time
-- for the flag text, and so is the late-cast ignore list (#8, NS.LateIgnore.Set()) when a caller hands
-- no `set`: a run keeps every late cast it recorded, and which of them count is decided here, each
-- time, so a change to the list re-scores every stored run.
-- Flags inform, never void: only `incomplete` and `lost` keep a run off the bests (modules/Bests.lua reads
-- run.status for that, not this list).

local Scoring = {}
NS.Scoring = Scoring

--- Seconds of no DamageDone update, after combat has ended, before the result is read (spec §4.5:
--- the probe saw updates up to 1.3s after combat dropped).
Scoring.QUIET_BEFORE_READ = 2.5

--- True when a cast that started `startOffset` seconds after the buzzer is late under `grace`.
--- Strictly later than the grace: a cast at exactly buzzer + grace is on time, and a cast that started
--- before the buzzer (a negative offset) is never late. An instant is scored by its success offset.
function Scoring.IsLateCast(startOffset, grace)
    if type(startOffset) ~= "number" or type(grace) ~= "number" then return false end
    return startOffset > grace
end

--- The score: damage / race length for a complete run, else damage / run.result.endedAt (seconds from
--- the start until combat ended). 0 when there is no damage or no positive divisor yet.
function Scoring.Dps(damage, run)
    if type(damage) ~= "number" or type(run) ~= "table" then return 0 end
    local secs
    if run.status == "complete" then
        secs = run.race and run.race.length
    else
        secs = run.result and run.result.endedAt
    end
    if type(secs) ~= "number" or secs <= 0 then return 0 end
    return damage / secs
end

-- One late cast as "+1.4s" or, when the resolver names its spell, "+1.4s Incinerate".
local function lateEntry(cast, nameOf)
    local L = NS.L
    local name
    if nameOf and cast.spellID then
        local ok, got = pcall(nameOf, cast.spellID)
        if ok and type(got) == "string" and got ~= "" then name = got end
    end
    if name then return L["+%.1fs %s"]:format(cast.t or 0, name) end
    return L["+%.1fs"]:format(cast.t or 0)
end

-- The ignore list in force: the caller's, else the stored one (an empty set before LateIgnore loads).
local function ignoreSet(set)
    if type(set) == "table" then return set end
    local LI = NS.LateIgnore
    return LI and LI.Set() or {}
end

--- A run's late casts split by the ignore list: the counted ones (they flag the run) and the ignored
--- ones, each in the recorded order. A cast with no spell ID (sealed) is always counted.
--- @param run table
--- @param set table|nil  { [spellID] = true }; NS.LateIgnore.Set() when nil
--- @return table counted
--- @return table ignored
function Scoring.SplitLate(run, set)
    local counted, ignored = {}, {}
    local flags = type(run) == "table" and run.flags
    local list = type(flags) == "table" and flags.lateCasts
    if type(list) ~= "table" then return counted, ignored end
    set = ignoreSet(set)
    for _, cast in ipairs(list) do
        local id = type(cast) == "table" and cast.spellID
        if type(id) == "number" and set[id] then
            ignored[#ignored + 1] = cast
        else
            counted[#counted + 1] = cast
        end
    end
    return counted, ignored
end

--- The ignored late casts as one line, "Ignored: +20.6s Feign Death, +3.0s Vanish", or nil when the
--- ignore list leaves none. Every flags tooltip draws it dimmed (the HUD chip, the Status cell, the
--- detail's Flags box and its timing legend), so they word it the same way.
--- @param set table|nil  as SplitLate's
--- @return string|nil
function Scoring.IgnoredText(run, nameOf, set)
    local _, ignored = Scoring.SplitLate(run, set)
    if #ignored == 0 then return nil end
    local parts = {}
    for i, cast in ipairs(ignored) do parts[i] = lateEntry(cast, nameOf) end
    return NS.L["Ignored: %s"]:format(table.concat(parts, ", "))
end

-- The late casts' flag: its text, then its count line and its offsets apart (the Results detail's
-- flags box draws those two as separate lines). `list` is the counted casts.
local function lateCastsText(list, nameOf)
    local L, parts = NS.L, {}
    for i, cast in ipairs(list) do parts[i] = lateEntry(cast, nameOf) end
    local joined = table.concat(parts, ", ")
    if #list == 1 then return L["1 late cast (%s)"]:format(joined), L["1 late cast"], joined end
    return L["%d late casts (%s)"]:format(#list, joined), L["%d late casts"]:format(#list), joined
end

-- The lateCasts flag over the counted casts, or nil when none counts (the ignore list's never do).
local function lateFlag(run, nameOf, set)
    local counted, ignored = Scoring.SplitLate(run, set)
    if #counted == 0 then return nil end
    local text, main, sub = lateCastsText(counted, nameOf)
    return { key = "lateCasts", text = text, main = main, sub = sub,
             count = #counted, casts = counted, ignored = ignored }
end

-- The shared session's text: netted when the arm kept the session's damage to take off.
local function sharedText(run)
    local L = NS.L
    local netted = type(run.race) == "table" and type(run.race.baseline) == "table"
    return netted and L["Shared session: the damage it held at the arm was taken off"]
        or L["Shared session: the total may include the fight before the arm"]
end

--- The run's flags as an array of { key, text, main?, sub? } (main and sub: the late casts' count
--- line and their offsets, the text split in two), in the order: lateCasts, restarted, reloaded,
--- sessionFromList (spec §9: the session ID was never captured), sharedSession (the pull carried on a
--- session from before the arm, modules/Race.lua share), died, incomplete, lost. `nameOf(spellID) -> name|nil` is optional: the caller (the UI) resolves spell
--- names through C_Spell, so this file stays pure; without it a late cast shows its offset only.
--- The lateCasts flag is there only when a late cast is counted (Scoring.SplitLate under `set`), and
--- also carries `count`, `casts` (the counted ones) and `ignored` (the rest). This is the one judge of
--- flagged and clean: every reader goes through it, never the run's raw list.
--- @param set table|nil  the ignore list as a set; NS.LateIgnore.Set() when nil
function Scoring.Flags(run, nameOf, set)
    local L, out = NS.L, {}
    local flags = (type(run) == "table" and type(run.flags) == "table") and run.flags or {}
    local function add(key, text, main, sub) out[#out + 1] = { key = key, text = text, main = main, sub = sub } end
    local late = lateFlag(run, nameOf, set)
    if late then out[#out + 1] = late end
    if type(flags.restartedAt) == "number" then
        add("restarted", L["Damage restarted at +%.1fs"]:format(flags.restartedAt))
    end
    if flags.reloaded then add("reloaded", L["Reloaded mid-run: casts after the buzzer not tracked"]) end
    if flags.sessionFromList then add("sessionFromList", L["Session matched by list"]) end
    if flags.sharedSession then add("sharedSession", sharedText(run)) end
    if flags.died then add("died", L["Died during the run"]) end
    local status = type(run) == "table" and run.status or nil
    if status == "incomplete" then add("incomplete", L["Incomplete: combat ended before the buzzer"]) end
    if status == "lost" then add("lost", L["Lost: the session could not be read"]) end
    return out
end
