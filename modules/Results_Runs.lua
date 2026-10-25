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
-- logged-in character and their current spec (the owner's call, 2026-10-24: "current" is a value of
-- its own, resolved when the filter runs, so a spec swap with the window open follows at the next
-- redraw); everything else starts at "all".
-- Filter, Options and the columns are pure over stored run records, so the suites drive them bare.

local Runs = {}
NS.ResultsRuns = Runs

local L = NS.L
local Tbl = NS.ResultsTable

Runs.RESOLVED = { complete = true, incomplete = true, lost = true }
Runs.DEFAULTS = {
    char = "current", spec = "current", category = "all", length = "all", date = "all",
    hideFlagged = false, includeIncomplete = true, onlyBest = false,
    -- Not a filter: the list's grouping (Runs.GROUPS), view state like the filters. Runs.Filter
    -- reads no predicate for it.
    group = "none",
}
Runs.DATE_RANGES = { "all", "today", "7d", "30d" }
local DAY = 86400
local DASH = "\226\128\148"

local FILTER_H = 32         -- one row of the filter bar
local DROPDOWNS = {         -- the bar's dropdowns, left to right, and their widths
    { key = "char", width = 110 }, { key = "spec", width = 96 }, { key = "category", width = 96 },
    { key = "length", width = 88 }, { key = "date", width = 100 }, { key = "group", width = 136 },
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
      tip = "Delete the saved view and go back to the stock one: your character and spec, newest first." },
    { key = "clear", label = "Clear", act = "ClearView",
      tip = "Go back to the saved view (the stock one when none is saved). The saved view is kept." },
}
local VIEW_BUTTON_W = 52
local GAP = 6

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
local function charGroup(run)
    local char = run.char or {}
    local c = Tbl.ClassColor(char.class)
    local name = ("|cff%02x%02x%02x%s|r"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
        math.floor(c[3] * 255 + 0.5), tostring(char.name or "?"))
    return Runs.CharKey(run), L["Character: %s"]:format(name), tostring(char.name or "?"):lower()
end

local function classSpecGroup(run)
    local char = run.char or {}
    local class, spec = Tbl.ClassName(char.class), Tbl.SpecInfo(char.specID, char.spec)
    local label = spec and ("%s \194\183 %s"):format(class, spec) or class
    return tostring(char.class) .. "|" .. tostring(char.specID), L["Class & spec: %s"]:format(label), label:lower()
end

local CATEGORY_RANK = {}
for i, key in ipairs(NS.Dummies.CATEGORIES) do CATEGORY_RANK[key] = i end

local function targetGroup(run)
    local category = run.target and run.target.category or "other"
    return category, L["Target: %s"]:format(NS.Dummies.Label(category)), CATEGORY_RANK[category] or 99
end

Runs.GROUPS = {
    none = nil,
    char = { of = charGroup, column = "char" },
    classSpec = { of = classSpecGroup },
    target = { of = targetGroup, column = "target" },
}
Runs.GROUP_ORDER = { "none", "char", "classSpec", "target" }
local GROUP_LABELS = {
    none = "Group: None", char = "Group: Character", classSpec = "Group: Class & spec", target = "Group: Target",
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
-- distinct (the owner's calls, 2026-10-25). Max is the view's: the complete run with the highest DPS
-- the filters pass, tagged only when those runs span more than one spec (Runs.ManySpecs). Spec best
-- is the board's (spec x dummy type x length). Both name their board after the box in plain text,
-- "boss-level · 2:00", the length in its color (Runs.StatusTrail): a best depends on the target type
-- and the race length.
Runs.STATUS = {
    max        = { label = "Max", color = C.violet, icon = "ph:crown" },
    best       = { label = "Spec best", color = C.blue, icon = "ph:trophy" },
    complete   = { label = "Complete", color = C.green, icon = "ph:check" },
    flagged    = { label = "Flagged", color = C.red, icon = "ph:flag" },
    incomplete = { label = "Incomplete", color = C.orange, icon = "ph:x" },
    died       = { label = "Died", color = C.pink, icon = "ph:skull" },
    lost       = { label = "Lost", color = C.slate, icon = "ph:ghost" },
}
local STATUS_ORDER = { max = 0, best = 1, complete = 2, flagged = 3, incomplete = 4, died = 5, lost = 6 }

-- Whether `run` holds the best on its board (the all-runs board, as the Bests tab's default).
function Runs.HoldsBest(run)
    local Bests = NS.Bests
    if not (Bests and Bests.Board) then return false end
    local held = Bests.Board()[Bests.Key(run)]
    return held ~= nil and held.id == run.id
end

-- A run's DPS as the v/s Max column and the Max tag read it: nil for a lost run or one with no DPS.
local function runDps(run)
    local dps = run.status ~= "lost" and run.result and run.result.dps
    return type(dps) == "number" and dps or nil
end

--- A run's status tag: its key, its label (the word in the box: "Spec best", never its board), its
--- color and its icon name. `top` is the view's max DPS (Runs.MaxDps over the runs the filters
--- pass): the complete run holding it is Max, over Spec best.
--- @param run table
--- @param top number|nil
--- @return string key, string text, table color, string|nil icon
function Runs.Status(run, top)
    local key
    if run.status == "lost" then
        key = "lost"
    elseif run.status == "incomplete" then
        key = (type(run.flags) == "table" and run.flags.died) and "died" or "incomplete"
    elseif type(top) == "number" and runDps(run) == top then
        key = "max"
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

-- The tags that name their board after the box.
local NAMES_BOARD = { best = true, max = true }

--- The board a Spec best or Max tag names: the target type in lower case and the race length
--- ("boss-level", "2:00"), and the length's color (Tbl.LengthColor).
--- @return string target, string time, table color
function Runs.StatusBoard(run)
    local length = run.race and run.race.length
    return NS.Dummies.Label(run.target and run.target.category):lower(), NS.Format.Length(length),
        Tbl.LengthColor(length)
end

--- The plain text after a tag's box: "boss-level · 2:00", the time in its length color, for Spec
--- best and Max; nil for every other tag.
--- @param run table
--- @param key string  Runs.Status's key
--- @return string|nil
function Runs.StatusTrail(run, key)
    if not NAMES_BOARD[key] then return nil end
    local target, time, color = Runs.StatusBoard(run)
    return L["%s \194\183 %s"]:format(target, "|c" .. Tbl.Hex(color) .. time .. "|r")
end

local function categoryOf(run)
    return run.target and run.target.category or "other"
end

--- `runs` split by target category: { [category] = { run, ... } }.
function Runs.ByCategory(runs)
    local out = {}
    for _, run in ipairs(runs or {}) do
        local key = categoryOf(run)
        out[key] = out[key] or {}
        out[key][#out[key] + 1] = run
    end
    return out
end

--- Whether the complete runs in `runs` span more than one spec: only then is a view-wide Max worth a
--- tag of its own (the owner's call, 2026-10-25). Within one spec the top run is already its Spec best.
--- @param runs table  run records
--- @return boolean
function Runs.ManySpecs(runs)
    local first
    for _, run in ipairs(runs or {}) do
        local spec = run.status == "complete" and run.char and run.char.specID
        if spec ~= nil and spec ~= false then
            if first == nil then first = spec elseif spec ~= first then return true end
        end
    end
    return false
end

--- The max DPS the v/s Max column measures against: the highest among the complete runs in `runs`
--- (the runs the filters pass). Only a complete run's DPS ranks, so an incomplete one never sets it.
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

--- How far a run's DPS sits from `top` (Runs.MaxDps over the runs the filters pass), as a
--- percentage: 0 on the max run, negative below it. An incomplete run is compared too (it may read
--- above the max: it never ranks). nil for a lost run, a run with no DPS, or no max.
--- @param run table
--- @param top number|nil
--- @return number|nil pct
function Runs.VsMax(run, top)
    local dps = runDps(run)
    if not dps or type(top) ~= "number" or top <= 0 then return nil end
    if dps == top then return 0 end
    return (dps / top - 1) * 100
end

local function vsMaxText(run, top)
    local pct = Runs.VsMax(run, top)
    if pct == nil then return DASH, C.dim end
    if pct == 0 and run.status == "complete" then return L["%.1f%%"]:format(0), C.gold end
    local color = run.status == "complete" and (pct < 0 and C.red or C.green) or C.dim
    return L["%+.1f%%"]:format(pct), color
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

--- The v/s Max cell's tooltip.
function Runs.VsMaxTip(run, top)
    local pct = Runs.VsMax(run, top)
    local type_ = NS.Dummies.Label(categoryOf(run)):lower()
    if pct == nil then
        return { DASH, run.status == "lost" and L["A lost run has no DPS to compare."]
            or L["No complete run on this target type in view to compare with."] }
    end
    local lines = { L["%+.1f%% vs the max"]:format(pct),
                    L["The max for %s in this view: %s DPS."]:format(type_, NS.ResultsTips.Grouped(top)) }
    if pct == 0 and run.status == "complete" then lines[1] = L["This run is the max for %s in view."]:format(type_) end
    if run.status ~= "complete" then lines[#lines + 1] = L["An incomplete run is compared, but never sets the max."] end
    return lines
end

local STATUS_ABOUT = {
    max = "The top DPS on its target type among the runs in view, which hold more than one spec.",
    best = "The best run for its spec, target type and race length.",
    complete = "A complete run that holds no best.",
    flagged = "A complete run that carries a flag.",
    incomplete = "Combat ended before the buzzer. It never counts toward bests.",
    died = "You died before the buzzer. It never counts toward bests.",
    lost = "The meter's session could not be read after combat. There is no score.",
}

--- The Status cell's tooltip: the tag (with its whole board for Spec best and Max: "Spec best:
--- boss-level · 2:00"), what it means, then every flag the run carries (what the flag column's mark
--- used to say).
function Runs.StatusTip(run, top)
    local key, text = Runs.Status(run, top)
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
Runs.STATUS_W = 190
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

-- The tail in the caption gray, after the length (NS.Format.RunTime).
local TAIL_HEX = Tbl.Hex(C.dim)

--- The Time cell: the run's time (NS.Format.RunTime) in its race length's color (Tbl.LengthColor),
--- the tail after it kept in the caption gray.
--- @return string text, table color
function Runs.TimeCell(run)
    return NS.Format.RunTime(run, TAIL_HEX), Tbl.LengthColor(run.race and run.race.length)
end

--- The Runs list's columns (mockup screen 08): date, class and spec icons, character, ilvl, target,
--- time (the length and the tail), damage, DPS, v/s max, status (the flags are its tooltip's). The v/s Max column reads
--- its max off the whole list the table is handed (its `scan`, every run the filters pass).
function Runs.Columns()
    local view = { top = {}, maxTag = {} }
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
        { key = "target", label = L["Target"], width = 84, kind = "badge", desc = false,
          sort = function(run) return (Tbl.Badge(run.target)) end,
          text = function(run) return Tbl.Badge(run.target) end },
        { key = "time", label = L["Time"], width = 76, desc = true,
          sort = NS.Format.RunSeconds,
          text = Runs.TimeCell },
        { key = "damage", label = L["Damage"], width = 60, desc = true,
          sort = function(run) return run.result and run.result.damage end,
          bar = function(run) return run.status ~= "lost" and run.result and run.result.damage or nil end,
          barStyle = function(run) return Runs.BarStyle("damageBar", run) end,
          -- Per target type (the owner's call, 2026-10-25), as v/s Max is.
          barKey = categoryOf,
          text = damageText },
        { key = "dps", label = L["DPS"], width = 62, desc = true,
          sort = sortDps, text = dpsText,
          bar = function(run) return run.status ~= "lost" and run.result and run.result.dps or nil end,
          barStyle = function(run) return Runs.BarStyle("dpsBar", run) end,
          barKey = categoryOf },
        { key = "vsMax", label = L["v/s Max"], width = 56, desc = true,
          -- Per target type (the owner's call, 2026-10-25): each run against the max of the runs the
          -- filters pass on its own category; the Max tag only where that category spans specs.
          scan = function(list)
              view.top, view.maxTag = {}, {}
              for category, runs in pairs(Runs.ByCategory(list)) do
                  view.top[category] = Runs.MaxDps(runs)
                  view.maxTag[category] = Runs.ManySpecs(runs) and view.top[category] or nil
              end
          end,
          sort = function(run) return Runs.VsMax(run, view.top[categoryOf(run)]) end,
          text = function(run) return vsMaxText(run, view.top[categoryOf(run)]) end,
          tip = function(run) return Runs.VsMaxTip(run, view.top[categoryOf(run)]) end },
        -- Wide enough for the longest board after its box: "Spec best" then "single target · 0:30".
        { key = "status", label = L["Status"], width = Runs.STATUS_W, kind = "badge", boxed = true, trail = true,
          desc = false,
          sort = function(run) return STATUS_ORDER[(Runs.Status(run, view.maxTag[categoryOf(run)]))] end,
          text = function(run)
              local key, text, color, icon = Runs.Status(run, view.maxTag[categoryOf(run)])
              return text, color, icon, Runs.StatusTrail(run, key)
          end,
          tip = function(run) return Runs.StatusTip(run, view.maxTag[categoryOf(run)]) end },
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
    b.label:SetText(L[spec.label])
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
        b.tip = L[spec.tip]
        b:HookScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        view.viewButtons[spec.key] = b
    end
    view.bar = bar
end

--- The Runs tab in `parent`.
--- @param parent table
--- @param hooks table  { select(run), share(run), selected() -> id|nil }
--- @return table view
function Runs.Build(parent, hooks)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    local view = setmetatable({ frame = frame, hooks = hooks or {}, filters = {}, barH = FILTER_H }, View)
    for k, v in pairs(Runs.DEFAULTS) do view.filters[k] = v end
    buildBar(view)
    view.listHost = CreateFrame("Frame", nil, frame)
    view.list = Tbl.New(view.listHost, Runs.Columns(), {
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
    local desc = v.sortDesc
    if desc == nil then desc = Runs.STOCK_SORT.desc end
    if self.list.column and self.list:column(sortKey) then
        self.list.sortKey, self.list.sortDesc = sortKey, desc and true or false
        self.list:paintHeader()
    end
    if self.dropdowns and next(self.dropdowns) then self:Refresh() end
end

function View:SaveView()
    local p = NS.db and NS.db.profile
    if not p then return false end
    if type(p.views) ~= "table" then p.views = {} end
    p.views.runs = self:CaptureView()
    NS.Print(L["Runs view saved as default."])
    return true
end

function View:ResetView()
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

-- Lay the bar out from the configured widths. Two rows (the collapsed view): the dropdowns on the
-- first; the checkboxes and Save / Reset / Clear on the second, the buttons right-aligned under the
-- last dropdown (Group). One row (the expanded view, `oneRow`): the dropdowns, the checkboxes, then
-- the buttons. The run count is the window footer's (hooks.count). Answers its height.
function View:layoutBar(oneRow)
    local x = GAP + 2
    for _, spec in ipairs(DROPDOWNS) do
        local dd = self.dropdowns[spec.key]
        if dd then
            dd:ClearAllPoints()
            dd:SetPoint("TOPLEFT", self.bar, "TOPLEFT", x, -6)
            x = x + spec.width + GAP
        end
    end
    local y = oneRow and -6 or -(FILTER_H - 2)
    local groupRight = x - GAP   -- the last dropdown's right edge, from the bar's left
    if not oneRow then x = GAP + 2 end
    for _, spec in ipairs(CHECKS) do
        local b = self.checks[spec.key]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.bar, "TOPLEFT", x, y)
        x = x + spec.width + GAP
    end
    local right = groupRight
    if oneRow then right = x + #VIEW_BUTTONS * (VIEW_BUTTON_W + GAP) - GAP end
    for i = #VIEW_BUTTONS, 1, -1 do
        local b = self.viewButtons[VIEW_BUTTONS[i].key]
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", self.bar, "TOPLEFT", right, y)
        right = right - VIEW_BUTTON_W - GAP
    end
    self.barH = oneRow and FILTER_H or (2 * FILTER_H - 6)
    self.bar:SetHeight(self.barH)
    return self.barH
end

--- Lay the tab out: the bar across `width` (one row when `oneRow`, the expanded view), the list
--- `listWidth` wide beneath it.
function View:Layout(width, height, listWidth, oneRow)
    local barH = self:layoutBar(oneRow)
    self.listHost:ClearAllPoints()
    self.listHost:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -barH)
    self.listHost:SetSize(listWidth or width, math.max(1, height - barH))
    self.list:Layout(listWidth or width, math.max(1, height - barH))
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
    local all = NS.Recorder.All()
    self:paintFilters(Runs.Options(all))
    self.filtered = Runs.Filter(all, self.filters)
    local n = #self.filtered
    self.countText = n == 1 and L["1 run"] or L["%d runs"]:format(n)
    if self.hooks.count then self.hooks.count(self.countText) end
    self.list.selected = self.hooks.selected and self.hooks.selected() or nil
    self.list:SetData(self.filtered)
    self.list:SetGroup(Runs.GROUPS[self.filters.group or "none"])
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
