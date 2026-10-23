local _, NS = ...
-- modules/Scoring.lua — the scoring rules (spec §5): the late-cast test with its grace (§5.2), DPS from
-- the addon's own clock (§5.1), the quiet wait before the result read (§4.5) and a run's flag set in
-- display order (§5.4).
--
-- PURE. No WoW API and no meter value: every input is a plain number already stored on the run (the
-- damage comes from Meter.ReadSession after combat). NS.L is read at CALL time for the flag text.
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

local function lateCastsText(list, nameOf)
    local parts = {}
    for i, cast in ipairs(list) do parts[i] = lateEntry(cast, nameOf) end
    local joined = table.concat(parts, ", ")
    if #list == 1 then return NS.L["1 late cast (%s)"]:format(joined) end
    return NS.L["%d late casts (%s)"]:format(#list, joined)
end

--- The run's flags as an array of { key, text }, in the order: lateCasts, restarted, reloaded,
--- sessionFromList (spec §9: the session ID was never captured), died, incomplete, lost. `nameOf(spellID) -> name|nil` is optional: the caller (the UI) resolves spell
--- names through C_Spell, so this file stays pure; without it a late cast shows its offset only.
function Scoring.Flags(run, nameOf)
    local L, out = NS.L, {}
    local flags = (type(run) == "table" and type(run.flags) == "table") and run.flags or {}
    local function add(key, text) out[#out + 1] = { key = key, text = text } end
    if type(flags.lateCasts) == "table" and #flags.lateCasts > 0 then
        add("lateCasts", lateCastsText(flags.lateCasts, nameOf))
    end
    if type(flags.restartedAt) == "number" then
        add("restarted", L["Damage restarted at +%.1fs"]:format(flags.restartedAt))
    end
    if flags.reloaded then add("reloaded", L["Reloaded mid-run: casts after the buzzer not tracked"]) end
    if flags.sessionFromList then add("sessionFromList", L["Session matched by list"]) end
    if flags.died then add("died", L["Died during the run"]) end
    local status = type(run) == "table" and run.status or nil
    if status == "incomplete" then add("incomplete", L["Incomplete: combat ended before the buzzer"]) end
    if status == "lost" then add("lost", L["Lost: the session could not be read"]) end
    return out
end
