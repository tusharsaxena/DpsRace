local _, NS = ...
-- modules/Results_Bests.lua — the Results window's Bests tab (spec §6.2, mockup screen 09): the best
-- run per spec × category × race length across every character on the account, from NS.Bests' cached
-- board, filtered by spec and category, with Clean runs only (off by default) switching to the board
-- that leaves out every flagged run. A row opens its run's detail on the Runs tab.
--
-- ONE CATEGORY AT A TIME (mockup screen 09: "Category: Cleave"). A board row is one best per spec ×
-- category × length and the table has no target column, so mixing categories would show two rows of
-- one spec and length told apart by nothing. The category filter has no "all" choice: it starts on
-- the first category present on the board, in NS.Dummies.CATEGORIES order, and moves to it again
-- whenever the chosen one is not on the board shown (the clean-only board may lack it).

local Bests = {}
NS.ResultsBests = Bests

local L = NS.L
local Tbl = NS.ResultsTable
local C = Tbl.COLORS

Bests.DEFAULTS = { spec = "all", category = "first", cleanOnly = false }

local FILTER_H = 32
local GAP = 6

--- The board's runs that pass the spec and category filters (any order).
--- @param board table  { [key] = run } (NS.Bests.Board's)
--- @param f table  { spec, category }
--- @return table runs
function Bests.Rows(board, f)
    f = f or {}
    local spec, category = f.spec or "all", f.category or "all"
    local out = {}
    for _, run in pairs(board or {}) do
        local okSpec = spec == "all" or (run.char and run.char.specID) == spec
        local okCat = category == "all" or (run.target and run.target.category or "other") == category
        if okSpec and okCat then out[#out + 1] = run end
    end
    return out
end

--- The spec and category dropdowns' options for `board`: the specs led by their "all" entry, the
--- categories present only, in canonical order (no "all": see the header).
function Bests.Options(board)
    local specs, seenSpec, cats = {}, {}, {}
    local present = {}
    for _, run in pairs(board or {}) do
        local char = run.char or {}
        if type(char.specID) == "number" and not seenSpec[char.specID] then
            seenSpec[char.specID] = true
            specs[#specs + 1] = { value = char.specID, label = Tbl.SpecInfo(char.specID, char.spec) or tostring(char.specID) }
        end
        present[run.target and run.target.category or "other"] = true
    end
    table.sort(specs, function(a, b) return a.label < b.label end)
    table.insert(specs, 1, { value = "all", label = L["All specs"] })
    for _, key in ipairs(NS.Dummies.CATEGORIES) do
        if present[key] then cats[#cats + 1] = { value = key, label = L["Category: %s"]:format(NS.Dummies.Label(key)) } end
    end
    return { spec = specs, category = cats }
end

--- The Bests board's columns (mockup screen 09).
function Bests.Columns()
    return {
        { key = "icons", label = L["Class \194\183 Spec"], flex = true, min = 120, kind = "icons", withName = true,
          desc = false, sort = function(run) return tostring(run.char and run.char.spec or ""):lower() end },
        { key = "char", label = L["Character"], width = 130, desc = false,
          sort = function(run) return tostring(run.char and run.char.name or ""):lower() end,
          text = function(run)
              local char = run.char or {}
              return char.name or "?", Tbl.ClassColor(char.class)
          end },
        -- Boxed in its length color, as the Runs list's Time column (Tbl.LengthChip): "10:00" fits.
        { key = "length", label = L["Length"], width = 56, kind = "badge", boxed = true, desc = true,
          sort = function(run) return run.race and run.race.length end,
          text = function(run) return Tbl.LengthChip(run.race and run.race.length) end },
        { key = "ilvl", label = L["iLvl"], width = 56, desc = true,
          sort = function(run) return run.char and run.char.ilvl end,
          text = function(run) return Tbl.Ilvl(run.char and run.char.ilvl) end },
        { key = "damage", label = L["Damage"], width = 80, desc = true,
          sort = function(run) return run.result and run.result.damage end,
          text = function(run) return NS.Format.Number(run.result and run.result.damage or 0) end },
        { key = "dps", label = L["DPS"], width = 80, desc = true,
          sort = function(run) return run.result and run.result.dps end,
          text = function(run) return NS.Format.Number(run.result and run.result.dps or 0), C.green end },
        { key = "date", label = L["Date"], width = 64, desc = true,
          sort = function(run) return run.date end,
          text = function(run) return Tbl.Date(run.date, "%d %b") end },
        -- Plain chips (only the Runs list's Status tags are boxed): a two-flag best, "1 late ·
        -- Reloaded", fits the column.
        { key = "flags", label = L["Flags"], width = 110, kind = "badge",
          text = function(run) return Tbl.ShortFlags(run), C.amber end },
    }
end

local View = {}
View.__index = View

--- The Bests tab in `parent`.
--- @param parent table
--- @param hooks table  { open(run), share(run) }
function Bests.Build(parent, hooks)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    local view = setmetatable({ frame = frame, hooks = hooks or {}, filters = {}, dropdowns = {} }, View)
    for k, v in pairs(Bests.DEFAULTS) do view.filters[k] = v end
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    bar:SetHeight(FILTER_H)
    local x = GAP + 2
    for _, spec in ipairs({ { key = "spec", width = 110 }, { key = "category", width = 130 } }) do
        local dd = NS.MakeDropdown(bar, spec.width)
        if dd then
            dd:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -6)
            dd.onSelect = function(value) view:SetFilter(spec.key, value) end
            view.dropdowns[spec.key] = dd
            x = x + spec.width + GAP
        end
    end
    view.clean = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
    view.clean:SetSize(20, 20)
    view.clean:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -6)
    view.clean.label = Tbl.Text(view.clean, Tbl.FONT.TEXT)
    view.clean.label:SetPoint("LEFT", view.clean, "RIGHT", 1, 0)
    view.clean.label:SetText(L["Clean runs only"])
    view.clean:SetScript("OnClick", function() view:SetFilter("cleanOnly", not view.filters.cleanOnly) end)
    view.hint = Tbl.Text(bar, Tbl.FONT.CAPTION, nil, "RIGHT")
    view.hint:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -GAP - 2, -10)
    view.hint:SetText(L["Best per spec \195\151 category \195\151 race length, all characters"])
    view.bar = bar
    view.listHost = CreateFrame("Frame", nil, frame)
    view.listHost:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -FILTER_H)
    view.list = Tbl.New(view.listHost, Bests.Columns(), {
        sortKey = "dps", sortDesc = true,
        onClick = function(run) if view.hooks.open then view.hooks.open(run) end end,
        onRightClick = function(run, row) if view.hooks.menu then view.hooks.menu(run, row) end end,
        empty = L["No personal bests yet: finish a race to set one."],
    })
    return view
end

function View:Layout(width, height)
    self.listHost:SetSize(width, math.max(1, height - FILTER_H))
    self.list:Layout(width, math.max(1, height - FILTER_H))
end

--- Re-read the board and redraw.
-- The chosen category if it is on the board, else the first one that is (nil on an empty board).
local function resolveCategory(chosen, options)
    for _, o in ipairs(options) do
        if o.value == chosen then return chosen end
    end
    return options[1] and options[1].value or nil
end

function View:Refresh()
    local board = NS.ResultsSource.Board({ cleanOnly = self.filters.cleanOnly == true })
    local options = Bests.Options(board)
    self.filters.category = resolveCategory(self.filters.category, options.category) or Bests.DEFAULTS.category
    for key, dd in pairs(self.dropdowns) do
        dd:SetOptions(options[key])
        dd:SelectValue(self.filters[key])
    end
    self.clean:SetChecked(self.filters.cleanOnly == true)
    self.rows = Bests.Rows(board, self.filters)
    self.list:SetData(self.rows)
end

--- Set one filter and redraw.
function View:SetFilter(key, value)
    if Bests.DEFAULTS[key] == nil then return false end
    self.filters[key] = value
    self:Refresh()
    return true
end

--- How many board rows show now.
function View:Count()
    return self.rows and #self.rows or 0
end
