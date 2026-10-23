local _, NS = ...
-- modules/Results_Runs.lua — the Results window's Runs tab (spec §6.2, mockup screen 08): the filter
-- bar (character, spec, category, race length, date range, Hide flagged, Include incomplete) over
-- the pooled, sortable run list. Clicking a row opens its detail (modules/Results_Detail.lua) and a
-- double-click shares it; the shell (modules/Results.lua) places the two.
--
-- WHAT THE LIST HOLDS. Resolved runs only: complete, incomplete and lost. A running or stopping run
-- is the race's (it shows on the HUD and lands here once it is read). Include incomplete governs the
-- two runs with no ranked score (incomplete and lost); Hide flagged drops a run with any flag beyond
-- its status (late casts, a restart, a reload, a session matched by list, a death).
--
-- The filters are the session's: they are view state, not settings, and start at "all" each login.
-- Filter, Options and the columns are pure over stored run records, so the suites drive them bare.

local Runs = {}
NS.ResultsRuns = Runs

local L = NS.L
local Tbl = NS.ResultsTable

Runs.RESOLVED = { complete = true, incomplete = true, lost = true }
Runs.DEFAULTS = {
    char = "all", spec = "all", category = "all", length = "all", date = "all",
    hideFlagged = false, includeIncomplete = true,
}
Runs.DATE_RANGES = { "all", "today", "7d", "30d" }
local DAY = 86400
local DASH = "\226\128\148"

local FILTER_H = 32         -- one row of the filter bar
local DROPDOWNS = {         -- the bar's dropdowns, left to right, and their widths
    { key = "char", width = 110 }, { key = "spec", width = 96 }, { key = "category", width = 96 },
    { key = "length", width = 88 }, { key = "date", width = 100 },
}
local CHECKS = {
    { key = "hideFlagged", label = "Hide flagged", width = 100 },
    { key = "includeIncomplete", label = "Include incomplete", width = 128 },
}
local COUNT_W = 70
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

-- One predicate per filter: each answers whether the run passes it.
local PASS = {
    function(run, f) return f.char == "all" or Runs.CharKey(run) == f.char end,
    function(run, f) return f.spec == "all" or (run.char and run.char.specID) == f.spec end,
    function(run, f) return f.category == "all" or (run.target and run.target.category or "other") == f.category end,
    function(run, f) return f.length == "all" or (run.race and run.race.length) == f.length end,
    function(run, _, since) return since == nil or (run.date or 0) >= since end,
    function(run, f) return f.includeIncomplete or run.status == "complete" end,
    function(run, f) return not (f.hideFlagged and Runs.IsFlagged(run)) end,
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

local function withAll(label, list)
    table.insert(list, 1, { value = "all", label = label })
    return list
end

--- Each dropdown's options for the resolved runs in `runs`, each list led by its "all" entry.
--- @return table { char, spec, category, length, date }
function Runs.Options(runs)
    local resolved = {}
    for _, run in ipairs(runs or {}) do
        if type(run) == "table" and Runs.RESOLVED[run.status] then resolved[#resolved + 1] = run end
    end
    return {
        char = withAll(L["All characters"], charOptions(resolved)),
        spec = withAll(L["All specs"], specOptions(resolved)),
        category = withAll(L["All targets"], categoryOptions(resolved)),
        length = withAll(L["Any length"], lengthOptions(resolved)),
        date = {
            { value = "all", label = L["All time"] }, { value = "today", label = L["Today"] },
            { value = "7d", label = L["Last 7 days"] }, { value = "30d", label = L["Last 30 days"] },
        },
    }
end

-- ── the columns ─────────────────────────────────────────────────────────────────────────────────

local C = Tbl.COLORS

local function dpsText(run)
    local result = run.result or {}
    if run.status == "lost" then return L["lost"], C.dim end
    if run.status == "incomplete" then return L["incomplete"], C.dim end
    if type(result.dps) ~= "number" then return DASH, C.dim end
    return NS.Format.Number(result.dps), C.text
end

local function damageText(run)
    local damage = run.result and run.result.damage
    if type(damage) ~= "number" then return DASH, C.dim end
    return NS.Format.Number(damage), C.text
end

local function rankedDps(run)
    if run.status ~= "complete" then return nil end
    return run.result and run.result.dps
end

--- The Runs list's columns (mockup screen 08): date, class and spec icons, character, ilvl, target,
--- length, damage, DPS, flags.
function Runs.Columns()
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
        { key = "ilvl", label = L["iLvl"], width = 40, justify = "RIGHT", desc = true,
          sort = function(run) return run.char and run.char.ilvl end,
          text = function(run) return Tbl.Ilvl(run.char and run.char.ilvl) end },
        { key = "target", label = L["Target"], width = 84, kind = "badge", desc = false,
          sort = function(run) return (Tbl.Badge(run.target)) end,
          text = function(run) return Tbl.Badge(run.target) end },
        { key = "length", label = L["Length"], width = 46, justify = "RIGHT", desc = true,
          sort = function(run) return run.race and run.race.length end,
          text = function(run) return NS.Format.Length(run.race and run.race.length) end },
        { key = "damage", label = L["Damage"], width = 60, justify = "RIGHT", desc = true,
          sort = function(run) return run.result and run.result.damage end,
          text = damageText },
        { key = "dps", label = L["DPS"], width = 62, justify = "RIGHT", desc = true,
          sort = rankedDps, text = dpsText },
        { key = "flag", label = "", width = 14, kind = "flag" },
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
    view.count = Tbl.Text(bar, Tbl.FONT.CAPTION, nil, "RIGHT")
    view.count:SetWidth(COUNT_W)
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
        sortKey = "dps", sortDesc = true,
        onClick = function(run) if view.hooks.select then view.hooks.select(run) end end,
        onDoubleClick = function(run) if view.hooks.share then view.hooks.share(run) end end,
        empty = L["No runs match these filters."],
    })
    return view
end

-- Lay the bar's controls out from their configured widths: one row when they fit, else the two
-- checkboxes and the count drop to a second row. Answers the bar's height.
function View:layoutBar(width)
    local x = GAP + 2
    for _, spec in ipairs(DROPDOWNS) do
        local dd = self.dropdowns[spec.key]
        if dd then
            dd:ClearAllPoints()
            dd:SetPoint("TOPLEFT", self.bar, "TOPLEFT", x, -6)
            x = x + spec.width + GAP
        end
    end
    local need = x + CHECKS[1].width + CHECKS[2].width + COUNT_W + 2 * GAP
    local row2 = need > width
    local y = row2 and -(FILTER_H - 2) or -6
    if row2 then x = GAP + 2 end
    for _, spec in ipairs(CHECKS) do
        local b = self.checks[spec.key]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.bar, "TOPLEFT", x, y)
        x = x + spec.width + GAP
    end
    self.count:ClearAllPoints()
    self.count:SetPoint("TOPRIGHT", self.bar, "TOPRIGHT", -GAP - 2, y - 4)
    self.barH = row2 and (2 * FILTER_H - 6) or FILTER_H
    self.bar:SetHeight(self.barH)
    return self.barH
end

--- Lay the tab out: the bar across `width`, the list `listWidth` wide beneath it.
function View:Layout(width, height, listWidth)
    local barH = self:layoutBar(width)
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
    self.count:SetText(n == 1 and L["1 run"] or L["%d runs"]:format(n))
    self.list.selected = self.hooks.selected and self.hooks.selected() or nil
    self.list:SetData(self.filtered)
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
