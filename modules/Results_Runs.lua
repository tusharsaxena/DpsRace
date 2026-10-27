local _, NS = ...
-- modules/Results_Runs.lua — the Results window's Runs tab (spec §6.2, mockup screen 08): the filter
-- bar (character, spec, category, race length, date range, Hide flagged, Include incomplete) over
-- the pooled, sortable run list. Clicking a row opens its detail (modules/Results_Detail.lua) and a
-- right-click opens its menu (Add note, Share, Delete); the shell (modules/Results.lua) places the two.
--
-- WHAT THE LIST HOLDS. Resolved runs only: complete, incomplete and lost. A running or stopping run
-- is the race's (it shows on the HUD and lands here once it is read). Include incomplete governs the
-- two runs with no ranked score (incomplete and lost); Hide flagged drops a run with any flag beyond
-- its status (late casts, a restart, a reload, a session matched by list, a death).
--
-- The filters are the session's: they are view state, not settings. Each login starts on the
-- logged-in character in every spec (the owner's call, 2026-10-26; "current" is a value of its own,
-- resolved when the filter runs), grouped by Full; everything else starts at "all".
-- Filter, Options and the columns are pure over stored run records, so the suites drive them bare.

local Runs = {}
NS.ResultsRuns = Runs

local L = NS.L
local Tbl = NS.ResultsTable

Runs.RESOLVED = { complete = true, incomplete = true, lost = true }
Runs.DEFAULTS = {
    char = "current", spec = "all", category = "all", length = "all", date = "all",
    hideFlagged = false, includeIncomplete = true, onlyBest = false,
    -- Not a filter: the list's grouping (Runs.GROUPS), view state like the filters. Runs.Filter
    -- reads no predicate for it. A new profile groups by Full: character, class, spec, target and
    -- time (the owner's call, 2026-10-25).
    group = "full",
}
Runs.DATE_RANGES = { "all", "today", "7d", "30d" }
local DAY = 86400
local DASH = "\226\128\148"

local FILTER_H = 32         -- one row of the filter bar
local DROPDOWNS = {         -- the bar's dropdowns, left to right, and their widths (their least: BarPlan)
    { key = "char", width = 110 }, { key = "spec", width = 96 }, { key = "category", width = 96 },
    { key = "length", width = 88 }, { key = "date", width = 100 }, { key = "group", width = 164 },
}
local CHECKS = {
    { key = "hideFlagged", label = "Hide flagged", width = 100 },
    { key = "includeIncomplete", label = "Include incomplete", width = 128 },
    { key = "onlyBest", label = "Only best", width = 84 },
}
-- The view buttons (LootHistory's), right-aligned on the bar's second row, Save first.
local VIEW_BUTTONS = {
    { key = "save", label = "Save", act = "SaveView",
      tip = "Save these filters, the grouping and the sort as this profile's default view of Runs." },
    { key = "reset", label = "Reset", act = "ResetView",
      tip = "Delete the saved view and go back to the stock one: your character in every spec, grouped by Full, newest first." },
    { key = "clear", label = "Clear", act = "ClearView",
      tip = "Go back to the saved view (the stock one when none is saved). The saved view is kept." },
}
local VIEW_BUTTON_W = 52
local GAP = 6
local MARGIN = GAP + 2      -- the bar's left margin, and its right one once the dropdowns stretch

-- ── pure: a run's facts, the filter, the options ────────────────────────────────────────────────

--- The character a run belongs to, as "Name-Realm".
function Runs.CharKey(run)
    local char = run.char or {}
    return ("%s-%s"):format(tostring(char.name or "?"), tostring(char.realm or "?"))
end

--- Whether the run carries a flag beyond its status (incomplete and lost are statuses here).
function Runs.IsFlagged(run)
    for _, flag in ipairs(NS.Scoring.Flags(run)) do
        if flag.key ~= "incomplete" and flag.key ~= "lost" then return true end
    end
    return false
end

--- The epoch the date filter starts at, or nil for "all".
function Runs.Since(range, now)
    now = now or time()
    if range == "7d" then return now - 7 * DAY end
    if range == "30d" then return now - 30 * DAY end
    if range ~= "today" then return nil end
    local t = date("*t", now)
    return time({ year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0 })
end

--- The logged-in character's current spec ID, or nil when the client cannot answer (then "current"
--- filters nothing).
function Runs.CurrentSpecID()
    local Compat, Secrets = NS.Compat, NS.Secrets
    if not (Compat and Secrets) then return nil end
    local okIndex, index = pcall(Compat.GetSpecialization)
    index = okIndex and Secrets.PlainNumber(index) or nil
    if not index then return nil end
    local ok, id = pcall(Compat.GetSpecializationInfo, index)
    return ok and Secrets.PlainNumber(id) or nil
end

local function charPasses(run, want)
    if want == "all" then return true end
    if want == "current" then return NS.Recorder.IsMine(run) end
    return Runs.CharKey(run) == want
end

local function specPasses(run, want)
    if want == "all" then return true end
    local id = run.char and run.char.specID
    if want == "current" then
        local mine = Runs.CurrentSpecID()
        return mine == nil or id == mine
    end
    return id == want
end

-- One predicate per filter: each answers whether the run passes it.
local PASS = {
    function(run, f) return charPasses(run, f.char) end,
    function(run, f) return specPasses(run, f.spec) end,
    function(run, f) return f.category == "all" or (run.target and run.target.category or "other") == f.category end,
    function(run, f) return f.length == "all" or (run.race and run.race.length) == f.length end,
    function(run, _, since) return since == nil or (run.date or 0) >= since end,
    function(run, f) return f.includeIncomplete or run.status == "complete" end,
    function(run, f) return not (f.hideFlagged and Runs.IsFlagged(run)) end,
    -- Only best: the runs holding their board's best now (the Status column's Best).
    function(run, f) return not f.onlyBest or Runs.HoldsBest(run) end,
}

--- The runs that pass every filter, in the order given.
--- @param runs table  run records (any status; only resolved ones can pass)
--- @param f table  the filters (Runs.DEFAULTS' shape; a missing key is its default)
--- @param now number|nil  the epoch the date range is measured from (time())
--- @return table runs
function Runs.Filter(runs, f, now)
    local given = f or {}
    f = {}
    for k, v in pairs(Runs.DEFAULTS) do f[k] = v end
    for k, v in pairs(given) do f[k] = v end
    local since = Runs.Since(f.date, now)
    local out = {}
    for _, run in ipairs(runs or {}) do
        local ok = type(run) == "table" and Runs.RESOLVED[run.status] == true
        for i = 1, #PASS do
            if not ok then break end
            ok = PASS[i](run, f, since)
        end
        if ok then out[#out + 1] = run end
    end
    return out
end

local function byLabel(a, b) return a.label < b.label end

local function charOptions(runs)
    local seen, list, names = {}, {}, {}
    for _, run in ipairs(runs) do
        local key = Runs.CharKey(run)
        if not seen[key] then
            seen[key] = true
            local name = tostring(run.char and run.char.name or "?")
            names[name] = (names[name] or 0) + 1
            list[#list + 1] = { value = key, label = name, color = Tbl.ClassColor(run.char and run.char.class) }
        end
    end
    -- Two characters of one name on different realms read as Name-Realm.
    for _, o in ipairs(list) do if names[o.label] > 1 then o.label = o.value end end
    table.sort(list, byLabel)
    return list
end

local function specOptions(runs)
    local seen, list = {}, {}
    for _, run in ipairs(runs) do
        local char = run.char or {}
        if type(char.specID) == "number" and not seen[char.specID] then
            seen[char.specID] = true
            local name = Tbl.SpecInfo(char.specID, char.spec)
            list[#list + 1] = { value = char.specID, label = name or tostring(char.specID) }
        end
    end
    table.sort(list, byLabel)
    return list
end

local function categoryOptions(runs)
    local present, list = {}, {}
    for _, run in ipairs(runs) do present[run.target and run.target.category or "other"] = true end
    for _, key in ipairs(NS.Dummies.CATEGORIES) do
        if present[key] then list[#list + 1] = { value = key, label = NS.Dummies.Label(key) } end
    end
    return list
end

local function lengthOptions(runs)
    local seen, values, list = {}, {}, {}
    for _, run in ipairs(runs) do
        local n = run.race and run.race.length
        if type(n) == "number" and not seen[n] then
            seen[n] = true
            values[#values + 1] = n
        end
    end
    table.sort(values)
    for i, n in ipairs(values) do list[i] = { value = n, label = NS.Format.Length(n) } end
    return list
end

local function withAll(label, list, current)
    table.insert(list, 1, { value = "all", label = label })
    if current then table.insert(list, 1, { value = "current", label = current }) end
    return list
end

-- ── grouping (LootHistory's Group by) ──────────────────────────────────────────────────────────
-- One entry per mode: `of(run)` answers the group's key, its header label ("Character: Lânfear")
-- and its rank (the groups' order); `column` is the column whose header flips that order.
-- THE HEADER'S VALUE IN ITS OWN COLOR (the owner's call, 2026-10-25): plain colored text, never a
-- box. A character or a class and spec in the class color, a target type in its category color
-- (Tbl.CATEGORY_COLORS), a race length in its length color (Tbl.LengthColor). The prefix ("Target:")
-- stays the header's gold and the count its gray.

--- `text` wrapped in an inline color escape of `color`.
function Runs.Colored(text, color)
    return ("|c%s%s|r"):format(Tbl.Hex(color), text)
end

local function charGroup(run)
    local char = run.char or {}
    local name = Runs.Colored(tostring(char.name or "?"), Tbl.ClassColor(char.class))
    return Runs.CharKey(run), L["Character: %s"]:format(name), tostring(char.name or "?"):lower()
end

local function classSpecGroup(run)
    local char = run.char or {}
    local class, spec = Tbl.ClassName(char.class), Tbl.SpecInfo(char.specID, char.spec)
    local label = spec and ("%s \194\183 %s"):format(class, spec) or class
    return tostring(char.class) .. "|" .. tostring(char.specID),
        L["Class & spec: %s"]:format(Runs.Colored(label, Tbl.ClassColor(char.class))), label:lower()
end

local CATEGORY_RANK = {}
for i, key in ipairs(NS.Dummies.CATEGORIES) do CATEGORY_RANK[key] = i end

-- A target type's name in its category color.
local function categoryText(category)
    return Runs.Colored(NS.Dummies.Label(category), Tbl.CATEGORY_COLORS[category] or Tbl.CATEGORY_COLORS.other)
end

local function targetGroup(run)
    local category = run.target and run.target.category or "other"
    return category, L["Target: %s"]:format(categoryText(category)), CATEGORY_RANK[category] or 99
end

-- The race length modes (the owner's call, 2026-10-25): one group per length, shortest first, the
-- time in its length color (Tbl.LengthColor). A run with no length sorts last. The keys carry their
-- mode's prefix, so a fold made in one mode never folds a group in another.
local NO_LENGTH_RANK = 1e6

local function lengthOf(run)
    local length = run.race and run.race.length
    return type(length) == "number" and length or nil
end

-- A run with no length reads as a dash, not "0:00": it groups after the longest length.
local function lengthText(length)
    return Runs.Colored(length == nil and DASH or NS.Format.Length(length), Tbl.LengthColor(length))
end

local function timeGroup(run)
    local length = lengthOf(run)
    return "length:" .. tostring(length), L["Time: %s"]:format(lengthText(length)), length or NO_LENGTH_RANK
end

-- One group per (target type, length) pair: the catalog's order, then shortest first in each type.
local function targetLengthGroup(run)
    local category = run.target and run.target.category or "other"
    local length = lengthOf(run)
    local rank = (CATEGORY_RANK[category] or 99) * (NO_LENGTH_RANK + 1) + (length or NO_LENGTH_RANK)
    return category .. "|" .. tostring(length),
        L["Target: %s"]:format(L["%s \194\183 %s"]:format(categoryText(category), lengthText(length))), rank
end

-- One group per (spec, target type, length): a best's own board (spec x dummy type x length). The
-- spec in its class color, then the type and the length in theirs; ordered by class and spec name,
-- then the catalog's order, then shortest first.
local function specTargetLengthGroup(run)
    local char = run.char or {}
    local spec = Tbl.SpecInfo(char.specID, char.spec) or Tbl.ClassName(char.class)
    local category = run.target and run.target.category or "other"
    local length = lengthOf(run)
    local key = ("%s|%s|%s|%s"):format(tostring(char.class), tostring(char.specID), category, tostring(length))
    local label = L["Spec: %s"]:format(("%s \194\183 %s \194\183 %s"):format(
        Runs.Colored(tostring(spec), Tbl.ClassColor(char.class)), categoryText(category), lengthText(length)))
    local rank = ("%s|%s|%03d|%07d"):format(tostring(Tbl.ClassName(char.class)):lower(), tostring(spec):lower(),
        CATEGORY_RANK[category] or 99, length or NO_LENGTH_RANK)
    return key, label, rank
end

-- Full (the owner's call, 2026-10-25): one group per character, class, spec, target type and length,
-- in that order. The character and the class and spec in the class color, the type and the time in
-- theirs; ordered by character name, class, spec, the catalog's order, then shortest first.
local function fullGroup(run)
    local char = run.char or {}
    local class = Tbl.ClassName(char.class)
    local spec = Tbl.SpecInfo(char.specID, char.spec) or class
    local category = run.target and run.target.category or "other"
    local length = lengthOf(run)
    local key = ("%s|%s|%s|%s|%s"):format(Runs.CharKey(run), tostring(char.class), tostring(char.specID),
        category, tostring(length))
    local color = Tbl.ClassColor(char.class)
    local label = L["Full: %s"]:format(("%s \194\183 %s \194\183 %s \194\183 %s \194\183 %s"):format(
        Runs.Colored(tostring(char.name or "?"), color), Runs.Colored(tostring(class), color),
        Runs.Colored(tostring(spec), color), categoryText(category), lengthText(length)))
    local rank = ("%s|%s|%s|%03d|%07d"):format(Runs.CharKey(run):lower(), tostring(class):lower(),
        tostring(spec):lower(), CATEGORY_RANK[category] or 99, length or NO_LENGTH_RANK)
    return key, label, rank
end

Runs.GROUPS = {
    none = nil,
    char = { of = charGroup, column = "char" },
    classSpec = { of = classSpecGroup },
    target = { of = targetGroup, column = "target" },
    length = { of = timeGroup, column = "time" },
    targetLength = { of = targetLengthGroup, column = "target" },
    specTargetLength = { of = specTargetLengthGroup },
    full = { of = fullGroup, column = "char" },
}
Runs.GROUP_ORDER = { "none", "full", "char", "classSpec", "target", "length", "targetLength", "specTargetLength" }
local GROUP_LABELS = {
    none = "Group: None", char = "Group: Character", classSpec = "Group: Class & spec", target = "Group: Target",
    length = "Group: Time", targetLength = "Group: Target + time", specTargetLength = "Group: Spec + target + time",
    full = "Group: Full",
}

--- Each dropdown's options for the resolved runs in `runs`, each list led by its "all" entry, and
--- the Group by dropdown's modes.
--- @return table { char, spec, category, length, date, group }
function Runs.Options(runs)
    local resolved = {}
    for _, run in ipairs(runs or {}) do
        if type(run) == "table" and Runs.RESOLVED[run.status] then resolved[#resolved + 1] = run end
    end
    return {
        char = withAll(L["All characters"], charOptions(resolved), L["Current character"]),
        spec = withAll(L["All specs"], specOptions(resolved), L["Current spec"]),
        category = withAll(L["All targets"], categoryOptions(resolved)),
        length = withAll(L["Any length"], lengthOptions(resolved)),
        date = {
            { value = "all", label = L["All time"] }, { value = "today", label = L["Today"] },
            { value = "7d", label = L["Last 7 days"] }, { value = "30d", label = L["Last 30 days"] },
        },
        group = (function()
            local out = {}
            for i, mode in ipairs(Runs.GROUP_ORDER) do out[i] = { value = mode, label = L[GROUP_LABELS[mode]] } end
            return out
        end)(),
    }
end

-- ── the columns ─────────────────────────────────────────────────────────────────────────────────

local C = Tbl.COLORS

-- Every run's DPS, an incomplete one's included (its damage over its time in combat); the Status
-- column says which runs rank.
local function dpsText(run)
    local result = run.result or {}
    if run.status == "lost" or type(result.dps) ~= "number" then return DASH, C.dim end
    return NS.Format.Number(result.dps), C.text
end

local function damageText(run)
    local damage = run.result and run.result.damage
    if type(damage) ~= "number" then return DASH, C.dim end
    return NS.Format.Number(damage), C.text
end

-- Only a complete run's DPS ranks: an incomplete run's is shown, but sorts after every ranked run.
local function sortDps(run)
    if run.status ~= "complete" then return nil end
    return run.result and run.result.dps
end

-- The Status tags (the owner's call, 2026-10-24), in the badge colors: one per resolved status, and
-- a complete run split three ways. Best wins over Flagged: the flag mark beside it still says why.
-- Best also draws the catalog's trophy (`ph:trophy`, declared in root CLAUDE.md) before its word.
-- Each tag is a 1px box in the tag's own hue, its icon inside before its word, and every hue is
-- distinct (the owner's calls, 2026-10-25). Spec best is the board's (spec x dummy type x length);
-- the Max tag is gone (the owner's call, 2026-10-26: Delta's 0.0% already marks each group's top
-- run). The tag is the box alone (the owner's call,
-- 2026-10-25: the board's chips after it were too noisy); the Target and Time columns beside it
-- already name the board, and the tooltip spells it out (Runs.StatusBoard).
Runs.STATUS = {
    best       = { label = "Spec best", color = C.blue, icon = "ph:trophy" },
    complete   = { label = "Complete", color = C.green, icon = "ph:check" },
    flagged    = { label = "Flagged", color = C.red, icon = "ph:flag" },
    incomplete = { label = "Incomplete", color = C.orange, icon = "ph:x" },
    died       = { label = "Died", color = C.pink, icon = "ph:skull" },
    lost       = { label = "Lost", color = C.slate, icon = "ph:ghost" },
}
local STATUS_ORDER = { best = 1, complete = 2, flagged = 3, incomplete = 4, died = 5, lost = 6 }

-- Whether `run` holds the best on its board (the all-runs board, as the Bests tab's default).
function Runs.HoldsBest(run)
    local Bests = NS.Bests
    if not (Bests and Bests.Board) then return false end
    local held = NS.ResultsSource.Board()[Bests.Key(run)]
    return held ~= nil and held.id == run.id
end

-- A run's DPS as the Delta column reads it: nil for a lost run or one with no DPS.
local function runDps(run)
    local dps = run.status ~= "lost" and run.result and run.result.dps
    return type(dps) == "number" and dps or nil
end

--- A run's status tag: its key, its label (the word in the box: "Spec best", never its board), its
--- color and its icon name.
--- @param run table
--- @return string key, string text, table color, string|nil icon
function Runs.Status(run)
    local key
    if run.status == "lost" then
        key = "lost"
    elseif run.status == "incomplete" then
        key = (type(run.flags) == "table" and run.flags.died) and "died" or "incomplete"
    elseif Runs.HoldsBest(run) then
        key = "best"
    elseif Runs.IsFlagged(run) then
        key = "flagged"
    else
        key = "complete"
    end
    local tag = Runs.STATUS[key]
    return key, L[tag.label], tag.color, tag.icon
end

-- The tags whose tooltip names their board.
local NAMES_BOARD = { best = true }

--- The board a Spec best tag names: the target type in lower case and the race length
--- ("boss-level", "2:00"), and the length's color (Tbl.LengthColor).
--- @return string target, string time, table color
function Runs.StatusBoard(run)
    local length = run.race and run.race.length
    return NS.Dummies.Label(run.target and run.target.category):lower(), NS.Format.Length(length),
        Tbl.LengthColor(length)
end

--- `runs` split by `groupOf(run)` (the table's grouping key; Results_Table's Tbl.GroupKey):
--- { [key] = { run, ... } }.
function Runs.ByGroup(runs, groupOf)
    local out = {}
    for _, run in ipairs(runs or {}) do
        local key = groupOf(run)
        out[key] = out[key] or {}
        out[key][#out[key] + 1] = run
    end
    return out
end

--- The max DPS the Delta column measures against: the highest among the complete runs in `runs`
--- (one group of the runs the filters pass). Only a complete run's DPS ranks, so an incomplete one never sets it.
--- @param runs table  run records
--- @return number|nil top  nil when no complete run with a positive DPS is in the list
function Runs.MaxDps(runs)
    local top
    for _, run in ipairs(runs or {}) do
        local dps = run.status == "complete" and runDps(run)
        if dps and dps > 0 and (top == nil or dps > top) then top = dps end
    end
    return top
end

--- How far a run's DPS sits from `top` (Runs.MaxDps over its group), as a percentage: 0 on the max run, negative below it. An incomplete run is compared too (it may read
--- above the max: it never ranks). nil for a lost run, a run with no DPS, or no max.
--- @param run table
--- @param top number|nil
--- @return number|nil pct
function Runs.Delta(run, top)
    local dps = runDps(run)
    if not dps or type(top) ~= "number" or top <= 0 then return nil end
    if dps == top then return 0 end
    return (dps / top - 1) * 100
end

-- The Delta cell: a complete run level with the max (the top, or a run tied with it) reads 0.0% in the
-- column's green, the pair of its red below the max (UT-P14, 2026-10-27; gold before), as the detail's
-- Delta box draws the top's lead.
local function deltaText(run, top)
    local pct = Runs.Delta(run, top)
    if pct == nil then return DASH, C.dim end
    if pct == 0 and run.status == "complete" then return L["%.1f%%"]:format(0), C.green end
    local color = run.status == "complete" and (pct < 0 and C.red or C.green) or C.dim
    return L["%+.1f%%"]:format(pct), color
end

-- ── the detail's Delta box (the owner's call, 2026-10-26) ───────────────────────────────────────
-- The detail reads the Delta column's own figures for the run it shows: the run's group under the
-- Runs view's current Group by (the whole filtered list with None), its max and its runner-up. A
-- context is { top, first, second, scope }: the max DPS, the complete run that sets it, the next
-- complete run below it (nil when there is none) and where they were read ("group", "view", or
-- "board" for a run the filters leave out). Nothing is stored on a run.

-- `a` ranks above `b` for the max: higher DPS; on a tie the earlier run (it set the mark first), then
-- the id, as a best's board ranks them (modules/Bests.lua).
local function leads(a, b)
    local da, db = runDps(a), runDps(b)
    if da ~= db then return da > db end
    local ta, tb = a.date or 0, b.date or 0
    if ta ~= tb then return ta < tb end
    return tostring(a.id) < tostring(b.id)
end

--- The top two complete runs in `runs` by DPS (the runs Runs.MaxDps ranks): the run that sets the
--- max and its runner-up, either nil.
--- @return table|nil first, table|nil second
function Runs.Leaders(runs)
    local first, second
    for _, run in ipairs(runs or {}) do
        local dps = run.status == "complete" and runDps(run)
        if dps and dps > 0 then
            if not first or leads(run, first) then
                first, second = run, first
            elseif not second or leads(run, second) then
                second = run
            end
        end
    end
    return first, second
end

--- One group's context (above) over `runs`.
function Runs.Context(runs, scope)
    local first, second = Runs.Leaders(runs)
    return { top = first and runDps(first), first = first, second = second, scope = scope }
end

--- The fallback for a run the Runs view does not list: its board (spec x target type x length, as
--- Bests keys it) among `runs`, every stored run.
function Runs.BoardContext(run, runs)
    local key, board = NS.Bests.Key(run), {}
    for _, other in ipairs(runs or {}) do
        if type(other) == "table" and NS.Bests.Key(other) == key then board[#board + 1] = other end
    end
    return Runs.Context(board, "board")
end

--- Whether `run` is the complete run that sets its context's max (the detail's *New best* badge).
function Runs.IsTop(run, ctx)
    local first = type(ctx) == "table" and ctx.first or nil
    return type(run) == "table" and run.status == "complete" and first ~= nil
        and (first == run or first.id == run.id)
end

--- The detail's Delta box for `run` in `ctx`: its text and color, and whether the run is its group's
--- top. Not the top: the run's Delta cell (an incomplete run's figure muted, a lost run's a muted dash,
--- as the column shows them). The top: its lead over the runner-up, green, or a dash with no runner-up.
--- @return string text, table color, boolean top
function Runs.DeltaBox(run, ctx)
    if type(ctx) ~= "table" then return DASH, C.dim, false end
    if not Runs.IsTop(run, ctx) then
        local text, color = deltaText(run, ctx.top)
        return text, color, false
    end
    local second = ctx.second and runDps(ctx.second)
    if not second or second <= 0 then return DASH, C.dim, true end
    return L["%+.1f%%"]:format((ctx.top / second - 1) * 100), C.green, true
end

--- The look of one bar column's cell for `run` (History > Results table): its fill and its text,
--- every class color the run's character's.
--- @param block string  "damageBar" | "dpsBar"
--- @return table|nil  Results_Table's barStyle shape; nil without the appearance module
function Runs.BarStyle(block, run)
    local A = NS.HudAppearance
    if not A then return nil end
    local D = NS.defaults.profile.resultsTable
    local class = run.char and run.char.class or false
    local p = "resultsTable."
    local fill = A.BarAt(p .. block .. ".", D[block], class)
    fill.font = A.FontAt(p .. "barText.", D.barText, class)
    return fill
end

--- The Delta cell's tooltip. `grouped` is whether the list is grouped (the max is its group's) or
--- flat (the max is the whole view's).
function Runs.DeltaTip(run, top, grouped)
    local pct = Runs.Delta(run, top)
    if pct == nil then
        return { DASH, run.status == "lost" and L["A lost run has no DPS to compare."]
            or (grouped and L["No complete run in this group to compare with."]
                or L["No complete run in view to compare with."]) }
    end
    local where = grouped and L["The max in this group: %s DPS."] or L["The max in view: %s DPS."]
    local lines = { L["%+.1f%% vs the max"]:format(pct), where:format(NS.ResultsTips.Grouped(top)) }
    if pct == 0 and run.status == "complete" then
        lines[1] = grouped and L["This run is the max in its group."] or L["This run is the max in view."]
    end
    if run.status ~= "complete" then lines[#lines + 1] = L["An incomplete run is compared, but never sets the max."] end
    return lines
end

local STATUS_ABOUT = {
    best = "The best run for its spec, target type and race length.",
    complete = "A complete run that holds no best.",
    flagged = "A complete run that carries a flag.",
    incomplete = "Combat ended before the buzzer. It never counts toward bests.",
    died = "You died before the buzzer. It never counts toward bests.",
    lost = "The meter's session could not be read after combat. There is no score.",
}

--- The Status cell's tooltip: the tag (with its whole board for Spec best: "Spec best:
--- boss-level · 2:00"), what it means, then every flag the run carries (what the flag column's mark
--- used to say).
function Runs.StatusTip(run)
    local key, text = Runs.Status(run)
    -- lines[1] is the title: SideTip draws it from a string.
    local lines = { text, L[STATUS_ABOUT[key]] }
    if NAMES_BOARD[key] then
        local target, time = Runs.StatusBoard(run)
        lines[1] = L["%s: %s \194\183 %s"]:format(text, target, time)
    end
    for _, flag in ipairs(Tbl.FlagTexts(run)) do lines[#lines + 1] = { flag, C.red[1], C.red[2], C.red[3] } end
    return lines
end

-- The Note column (the owner's call, 2026-10-25): the run's note cut to NOTE_CHARS characters with
-- an ellipsis, its tooltip the whole note. Sorted A to Z ignoring case; a run with no note sorts
-- last in either direction (the table's rule for a missing value).
Runs.NOTE_W = 80
-- The Used column (#13): four icons (Tbl.IconSlots), or three and "+n".
Runs.USED_W = 70
Runs.TARGET_W = 92
Runs.TIME_W = 84
Runs.STATUS_W = 92
Runs.NOTE_CHARS = 10
local ELLIPSIS = "\226\128\166"

local function noteOf(run)
    local note = type(run) == "table" and run.note
    if type(note) ~= "string" or note == "" then return nil end
    return note
end

--- The Note cell's text: the note's first NOTE_CHARS characters (UTF-8 characters, never a byte cut
--- through one), an ellipsis after them when the note is longer; "" with no note.
function Runs.NoteCell(run)
    local note = noteOf(run)
    if not note then return "" end
    local n, cut = 0, nil
    for pos in note:gmatch("()[^\128-\191]") do
        n = n + 1
        if n > Runs.NOTE_CHARS then
            cut = pos - 1
            break
        end
    end
    if not cut then return note end
    return note:sub(1, cut) .. ELLIPSIS
end

--- The Note column's sort value: the note in lower case, nil (last) with none.
function Runs.NoteSort(run)
    local note = noteOf(run)
    return note and note:lower() or nil
end

--- The Note cell's tooltip: "Note", then the whole note (wrapped by the tooltip).
function Runs.NoteTip(run)
    local note = noteOf(run)
    if not note then return { L["No note"], L["This run has no note. Add one from its detail or the row's right-click menu."] } end
    return { L["Note"], note }
end

--- The Time cell: the race length in a chip of its length color (Tbl.LengthChip), then the tail
--- after the buzzer ("+9.1s") or, for a run that ended early, when combat ended ("at 1:04"), as
--- plain caption-gray text after the box (Tbl.TimeTail).
--- @return string text, table color, nil, string|nil trail
function Runs.TimeCell(run)
    local text, color = Tbl.LengthChip(run.race and run.race.length)
    return text, color, nil, Tbl.TimeTail(run)
end

--- The Runs list's columns (mockup screen 08): date, class and spec icons, character, ilvl, target,
--- time (the length's chip and the tail), damage, DPS, delta, status (the flags are its tooltip's),
--- what was used (#13: its icons, modules/Results_Usage.lua) and the note.
--- The Delta column reads each group's max off the whole list the table is handed (its `scan`: every
--- run the filters pass, with the grouping's key), and the bars scale within each group too
--- (Results_Table's measure). A flat list is one group. `view` (optional) is the table the scan keeps
--- its figures in: the Runs view's own, which the detail's Delta box reads (View:DeltaContext).
function Runs.Columns(view)
    view = view or {}
    view.top, view.contexts, view.ids = {}, {}, {}
    view.groupOf = function() return true end
    local function topOf(run) return view.top[view.groupOf(run)] end
    return {
        { key = "date", label = L["Date"], width = 80, desc = true,
          sort = function(run) return run.date end,
          text = function(run) return Tbl.Date(run.date, "%d %b %H:%M") end },
        { key = "icons", label = L["Class"], width = 40, kind = "icons" },
        { key = "char", label = L["Character"], flex = true, min = 60, desc = false,
          sort = function(run) return tostring(run.char and run.char.name or ""):lower() end,
          text = function(run)
              local char = run.char or {}
              return char.name or "?", Tbl.ClassColor(char.class)
          end },
        { key = "ilvl", label = L["iLvl"], width = 40, desc = true,
          sort = function(run) return run.char and run.char.ilvl end,
          text = function(run) return Tbl.Ilvl(run.char and run.char.ilvl) end },
        -- Boxed in the category color; wide enough for the widest type, "Single target".
        { key = "target", label = L["Target"], width = Runs.TARGET_W, kind = "badge", boxed = true, desc = false,
          sort = function(run) return (Tbl.Badge(run.target)) end,
          text = function(run) return Tbl.Badge(run.target) end },
        -- The length boxed in its color, then the tail: "5:00" then "+15.9s" or "at 4:59".
        { key = "time", label = L["Time"], width = Runs.TIME_W, kind = "badge", boxed = true, trail = true, desc = true,
          sort = NS.Format.RunSeconds,
          text = Runs.TimeCell },
        { key = "damage", label = L["Damage"], width = 60, desc = true,
          sort = function(run) return run.result and run.result.damage end,
          bar = function(run) return run.status ~= "lost" and run.result and run.result.damage or nil end,
          barStyle = function(run) return Runs.BarStyle("damageBar", run) end,
          text = damageText },
        { key = "dps", label = L["DPS"], width = 62, desc = true,
          sort = sortDps, text = dpsText,
          bar = function(run) return run.status ~= "lost" and run.result and run.result.dps or nil end,
          barStyle = function(run) return Runs.BarStyle("dpsBar", run) end },
        { key = "delta", label = L["Delta"], width = 56, desc = true,
          -- Per group (the owner's call, 2026-10-26): each run against the max of its own group of
          -- the runs the filters pass, recomputed whenever the list or its grouping changes.
          scan = function(list, groupOf)
              view.top, view.contexts, view.ids, view.groupOf, view.grouped = {}, {}, {}, groupOf, false
              local groups = Runs.ByGroup(list, groupOf)
              for key in pairs(groups) do
                  if key ~= true then view.grouped = true end
              end
              for key, runs in pairs(groups) do
                  local ctx = Runs.Context(runs, view.grouped and "group" or "view")
                  view.top[key], view.contexts[key] = ctx.top, ctx
              end
              for _, run in ipairs(list) do view.ids[run.id] = true end
          end,
          sort = function(run) return Runs.Delta(run, topOf(run)) end,
          text = function(run) return deltaText(run, topOf(run)) end,
          tip = function(run) return Runs.DeltaTip(run, topOf(run), view.grouped) end },
        -- Wide enough for the widest tag alone: the boxed "Incomplete" with its icon.
        { key = "status", label = L["Status"], width = Runs.STATUS_W, kind = "badge", boxed = true,
          desc = false,
          sort = function(run) return STATUS_ORDER[(Runs.Status(run))] end,
          text = function(run)
              local _, text, color, icon = Runs.Status(run)
              return text, color, icon
          end,
          tip = Runs.StatusTip },
        -- What the run used (#13): the gear first, "+n" past what fits, a dash for nothing; sorted
        -- by how many, a run stored before format 3 last either way.
        { key = "used", label = L["Used"], width = Runs.USED_W, kind = "items", desc = true,
          sort = function(run) return NS.ResultsUsage.Count(run) end,
          items = function(run) return NS.ResultsUsage.Icons(run) end },
        { key = "note", label = L["Note"], width = Runs.NOTE_W, desc = false,
          sort = Runs.NoteSort, text = function(run) return Runs.NoteCell(run), C.dim end,
          tip = Runs.NoteTip },
    }
end

-- ── the view ────────────────────────────────────────────────────────────────────────────────────

local View = {}
View.__index = View

local function checkbox(view, parent, spec)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetSize(20, 20)
    b.label = Tbl.Text(b, Tbl.FONT.TEXT)
    b.label:SetPoint("LEFT", b, "RIGHT", 1, 0)
    Tbl.SetCheckLabel(b, L[spec.label])
    b:SetScript("OnClick", function() view:SetFilter(spec.key, not view.filters[spec.key]) end)
    b.key = spec.key
    return b
end

local function buildBar(view)
    local bar = CreateFrame("Frame", nil, view.frame)
    bar:SetPoint("TOPLEFT", view.frame, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", view.frame, "TOPRIGHT", 0, 0)
    bar:SetHeight(FILTER_H)
    local line = bar:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.24, 0.24, 0.27, 0.85)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    view.dropdowns, view.checks = {}, {}
    for _, spec in ipairs(DROPDOWNS) do
        local dd = NS.MakeDropdown(bar, spec.width)
        if dd then
            dd.onSelect = function(value) view:SetFilter(spec.key, value) end
            view.dropdowns[spec.key] = dd
        end
    end
    for _, spec in ipairs(CHECKS) do view.checks[spec.key] = checkbox(view, bar, spec) end
    view.viewButtons = {}
    for _, spec in ipairs(VIEW_BUTTONS) do
        local b = NS.HudStates.Button(bar, L[spec.label], function() view[spec.act](view) end)
        b:SetWidth(VIEW_BUTTON_W)
        b.tip = { L[spec.label], L[spec.tip] }   -- the shared button's own tooltip shape
        view.viewButtons[spec.key] = b
    end
    view.bar = bar
end

--- The Runs tab in `parent`.
--- @param parent table
--- @param hooks table  { select(run), share(run), selected() -> id|nil, menu(run, row), count(text),
---                       changed() after every redraw (the detail's Delta box follows it) }
--- @return table view
function Runs.Build(parent, hooks)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    local view = setmetatable({ frame = frame, hooks = hooks or {}, filters = {}, barH = FILTER_H, delta = {} }, View)
    for k, v in pairs(Runs.DEFAULTS) do view.filters[k] = v end
    buildBar(view)
    view.listHost = CreateFrame("Frame", nil, frame)
    view.list = Tbl.New(view.listHost, Runs.Columns(view.delta), {
        -- Newest first (the owner's call, 2026-10-24): the stock view's sort. A saved view (Save,
        -- below) replaces it at every login.
        sortKey = Runs.STOCK_SORT.key, sortDesc = Runs.STOCK_SORT.desc,
        onClick = function(run) if view.hooks.select then view.hooks.select(run) end end,
        onRightClick = function(run, row) if view.hooks.menu then view.hooks.menu(run, row) end end,
        empty = L["No runs match these filters."],
    })
    view:ApplyView(Runs.SavedView())
    return view
end

-- ── saved views (LootHistory's Save / Reset / Clear) ────────────────────────────────────────────
-- The Runs tab's view (its filters, its grouping and its sort) can be saved as the profile's
-- default: `profile.views.runs`, named non-setting state (docs/schema.md). Every build applies the
-- saved view, else the stock one.
--   Save   stores the current view as the saved one.
--   Reset  deletes the saved view and applies the stock one.
--   Clear  returns to the saved view, or the stock one when there is none; the saved view is kept.

Runs.STOCK_SORT = { key = "date", desc = true }

-- A saved sort on a column that was renamed: v/s Max became Delta (the owner's call, 2026-10-26).
local RENAMED_SORT = { vsMax = "delta" }

--- The saved view, or nil.
function Runs.SavedView()
    local p = NS.db and NS.db.profile
    local views = p and p.views
    return type(views) == "table" and type(views.runs) == "table" and views.runs or nil
end

--- The view now, as a plain copy.
function View:CaptureView()
    local filters = {}
    for k in pairs(Runs.DEFAULTS) do filters[k] = self.filters[k] end
    return { filters = filters, sortKey = self.list.sortKey, sortDesc = self.list.sortDesc }
end

--- Apply `v` (CaptureView's shape), or the stock view for nil. A stored key the view no longer
--- knows is dropped; a missing one takes its default.
function View:ApplyView(v)
    v = type(v) == "table" and v or {}
    local stored = type(v.filters) == "table" and v.filters or {}
    for k, def in pairs(Runs.DEFAULTS) do
        local value = stored[k]
        if value == nil then value = def end
        self.filters[k] = value
    end
    local sortKey = v.sortKey or Runs.STOCK_SORT.key
    sortKey = RENAMED_SORT[sortKey] or sortKey
    local desc = v.sortDesc
    if desc == nil then desc = Runs.STOCK_SORT.desc end
    if self.list.column and self.list:column(sortKey) then
        self.list.sortKey, self.list.sortDesc = sortKey, desc and true or false
        self.list:paintHeader()
    end
    if self.dropdowns and next(self.dropdowns) then self:Refresh() end
end

-- While the window shows the sample history (test mode, a sim) the view is the sample's: Save and
-- Reset refuse with one line, so nothing the samples set reaches the profile (modules/Results_Source.lua).
local function sampleRefusal()
    if not NS.ResultsSource.IsMock() then return false end
    NS.Print(L["Not saved: the Results window is showing sample runs."])
    return true
end

-- The sample history spans several characters and specs, so it opens on all of them; the view the
-- player had comes back when the store does (Runs.SampleView, the shell's OnSourceChanged).
Runs.SAMPLE_VIEW = { filters = { char = "all", spec = "all" } }

--- Enter (`on`) or leave the sample history's view: entering keeps the player's view to restore.
function View:SampleView(on)
    if on then
        if not self.realView then self.realView = self:CaptureView() end
        self:ApplyView(Runs.SAMPLE_VIEW)
    elseif self.realView then
        local real = self.realView
        self.realView = nil
        self:ApplyView(real)
    end
end

function View:SaveView()
    if sampleRefusal() then return false end
    local p = NS.db and NS.db.profile
    if not p then return false end
    if type(p.views) ~= "table" then p.views = {} end
    p.views.runs = self:CaptureView()
    NS.Print(L["Runs view saved as default."])
    return true
end

function View:ResetView()
    if sampleRefusal() then return false end
    local p = NS.db and NS.db.profile
    if p and type(p.views) == "table" then
        p.views.runs = nil
        if next(p.views) == nil then p.views = nil end
    end
    self:ApplyView(nil)
    NS.Print(L["Runs view reset to stock defaults."])
end

function View:ClearView()
    self:ApplyView(Runs.SavedView())
end

-- Place the bar's controls by the dropdowns' `widths` (by key). Two rows (the collapsed view): the
-- dropdowns on the first; the checkboxes and Save / Reset / Clear on the second, the buttons
-- right-aligned under the last dropdown (Group). One row (the expanded view, `oneRow`): the
-- dropdowns, the checkboxes, then the buttons.
local function placeBar(oneRow, widths)
    local plan = { dropdowns = {}, checks = {}, buttons = {}, widths = widths, y = oneRow and -6 or -(FILTER_H - 2) }
    local x = MARGIN
    for _, spec in ipairs(DROPDOWNS) do
        plan.dropdowns[spec.key] = x
        x = x + widths[spec.key] + GAP
    end
    local groupRight = x - GAP   -- the last dropdown's right edge
    if not oneRow then x = MARGIN end
    for _, spec in ipairs(CHECKS) do
        plan.checks[spec.key] = x
        x = x + spec.width + GAP
    end
    local right = oneRow and x + #VIEW_BUTTONS * (VIEW_BUTTON_W + GAP) - GAP or groupRight
    plan.right = math.max(right, groupRight, x - GAP)
    for i = #VIEW_BUTTONS, 1, -1 do
        plan.buttons[VIEW_BUTTONS[i].key] = right
        right = right - VIEW_BUTTON_W - GAP
    end
    return plan
end

-- The configured widths grown by `extra` px between them, in proportion to each (Group, the widest,
-- takes the most); the last takes the rounding, so the shares add up to `extra` exactly.
local function stretched(extra)
    local total = 0
    for _, spec in ipairs(DROPDOWNS) do total = total + spec.width end
    local widths, given = {}, 0
    for i, spec in ipairs(DROPDOWNS) do
        local add = i == #DROPDOWNS and extra - given or math.floor(extra * spec.width / total)
        widths[spec.key] = spec.width + add
        given = given + add
    end
    return widths
end

-- Plan the bar, pure (no frame is read): `width` is the bar's width, the window body's, the one the
-- shell lays the tab out at. The dropdowns take their configured widths, then share what the bar has
-- beyond them, so the bar ends MARGIN short of its right edge, as it starts MARGIN in from its left:
-- collapsed, Group's right edge there (and Clear's under it); expanded, Clear's. A width the
-- configured plan already fills, or none, answers that plan: the configured widths are the least.
-- Answers each control's left x (a button's right x), each dropdown's width, the second row's y and
-- the bar's right edge, all from the bar's left.
function Runs.BarPlan(oneRow, width)
    local widths = {}
    for _, spec in ipairs(DROPDOWNS) do widths[spec.key] = spec.width end
    local plan = placeBar(oneRow, widths)
    local extra = type(width) == "number" and math.floor(width - MARGIN - plan.right) or 0
    if extra <= 0 then return plan end
    return placeBar(oneRow, stretched(extra))
end

-- Lay the bar out by Runs.BarPlan at `width`: re-anchored and the dropdowns re-sized, nothing
-- repainted, so the cheap layout runs it too. The run count is the window footer's (hooks.count).
-- Answers its height.
function View:layoutBar(oneRow, width)
    local plan = Runs.BarPlan(oneRow, width)
    for _, spec in ipairs(DROPDOWNS) do
        local dd = self.dropdowns[spec.key]
        if dd then
            dd:ClearAllPoints()
            dd:SetPoint("TOPLEFT", self.bar, "TOPLEFT", plan.dropdowns[spec.key], -6)
            dd:SetWidth(plan.widths[spec.key])
        end
    end
    for _, spec in ipairs(CHECKS) do
        local b = self.checks[spec.key]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.bar, "TOPLEFT", plan.checks[spec.key], plan.y)
    end
    for _, spec in ipairs(VIEW_BUTTONS) do
        local b = self.viewButtons[spec.key]
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", self.bar, "TOPLEFT", plan.buttons[spec.key], plan.y)
    end
    self.oneRow = oneRow
    self.barH = oneRow and FILTER_H or (2 * FILTER_H - 6)
    self.bar:SetHeight(self.barH)
    return self.barH
end

--- Lay the tab out: the bar across `width` (one row when `oneRow`, the expanded view), the list
--- `listWidth` wide beneath it.
function View:Layout(width, height, listWidth, oneRow)
    local barH = self:layoutBar(oneRow, width)
    self.listHost:ClearAllPoints()
    self.listHost:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -barH)
    self.listHost:SetSize(listWidth or width, math.max(1, height - barH))
    self.list:Layout(listWidth or width, math.max(1, height - barH))
end

--- While the window is being sized (modules/Sizing.lua): the bar re-planned across `width` (cheap:
--- twelve controls re-anchored, six re-sized; its rows stay as the view set them), the list
--- `listWidth` wide beneath it, nothing rebound.
function View:Resize(width, height, listWidth)
    self:layoutBar(self.oneRow, width)
    local h = math.max(1, height - (self.barH or 0))
    self.listHost:SetSize(listWidth or width, h)
    self.list:Resize(listWidth or width, h)
end

--- The bar's height now (the detail pane sits beneath it).
function View:BarHeight()
    return self.barH
end

-- Put the filter values on the controls.
function View:paintFilters(options)
    for _, spec in ipairs(DROPDOWNS) do
        local dd = self.dropdowns[spec.key]
        if dd then
            dd:SetOptions(options[spec.key])
            dd:SelectValue(self.filters[spec.key])
        end
    end
    for _, spec in ipairs(CHECKS) do self.checks[spec.key]:SetChecked(self.filters[spec.key] == true) end
end

--- Re-read the store and redraw: options, filtered list, count, selection.
function View:Refresh()
    local all = NS.ResultsSource.All()
    self:paintFilters(Runs.Options(all))
    self.filtered = Runs.Filter(all, self.filters)
    local n = #self.filtered
    self.countText = n == 1 and L["1 run"] or L["%d runs"]:format(n)
    if self.hooks.count then self.hooks.count(self.countText) end
    self.list.selected = self.hooks.selected and self.hooks.selected() or nil
    self.list:SetData(self.filtered)
    self.list:SetGroup(Runs.GROUPS[self.filters.group or "none"])
    if self.hooks.changed then self.hooks.changed() end
end

--- What the Delta column measured `run` against (Runs.Context's shape: its group under the grouping
--- now, or the whole view with none), or nil when the filters leave the run out of the list.
function View:DeltaContext(run)
    local d = self.delta
    if type(run) ~= "table" or not (d.ids and d.ids[run.id]) then return nil end
    return d.contexts[d.groupOf(run)]
end

--- Set one filter and redraw.
function View:SetFilter(key, value)
    if Runs.DEFAULTS[key] == nil then return false end
    self.filters[key] = value
    self:Refresh()
    return true
end

--- How many runs pass the filters now.
function View:Count()
    return self.filtered and #self.filtered or 0
end
