local _, NS = ...
-- modules/Results_Bests.lua — the Results window's Bests tab (spec §6.2, mockup screen 09): the best
-- run per spec × category × race length across every character on the account, from NS.Bests' cached
-- board, filtered by spec and category, with Clean runs only (off by default) switching to the board
-- that leaves out every flagged run. A row opens its run's detail on the Runs tab.

local Bests = {}
NS.ResultsBests = Bests

local L = NS.L
local Tbl = NS.ResultsTable
local C = Tbl.COLORS

Bests.DEFAULTS = { spec = "all", category = "all", cleanOnly = false }

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

--- The spec and category dropdowns' options for `board`, each led by its "all" entry.
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
    cats[1] = { value = "all", label = L["All categories"] }
    for _, key in ipairs(NS.Dummies.CATEGORIES) do
        if present[key] then cats[#cats + 1] = { value = key, label = L["Category: %s"]:format(NS.Dummies.Label(key)) } end
    end
    return { spec = specs, category = cats }
end

--- The Bests board's columns (mockup screen 09).
function Bests.Columns()
    return {
        { key = "icons", label = L["CLS \194\183 SPEC"], flex = true, min = 120, kind = "icons", withName = true,
          desc = false, sort = function(run) return tostring(run.char and run.char.spec or ""):lower() end },
        { key = "char", label = L["CHARACTER"], width = 130, desc = false,
          sort = function(run) return tostring(run.char and run.char.name or ""):lower() end,
          text = function(run)
              local char = run.char or {}
              return char.name or "?", Tbl.ClassColor(char.class)
          end },
        { key = "length", label = L["LEN"], width = 50, justify = "RIGHT", desc = true,
          sort = function(run) return run.race and run.race.length end,
          text = function(run) return NS.Format.Length(run.race and run.race.length) end },
        { key = "ilvl", label = L["ILVL"], width = 56, justify = "RIGHT", desc = true,
          sort = function(run) return run.char and run.char.ilvl end,
          text = function(run) return Tbl.Ilvl(run.char and run.char.ilvl) end },
        { key = "damage", label = L["DAMAGE"], width = 80, justify = "RIGHT", desc = true,
          sort = function(run) return run.result and run.result.damage end,
          text = function(run) return NS.Format.Number(run.result and run.result.damage or 0) end },
        { key = "dps", label = L["DPS"], width = 80, justify = "RIGHT", desc = true,
          sort = function(run) return run.result and run.result.dps end,
          text = function(run) return NS.Format.Number(run.result and run.result.dps or 0), C.green end },
        { key = "date", label = L["DATE"], width = 64, desc = true,
          sort = function(run) return run.date end,
          text = function(run) return Tbl.Date(run.date, "%d %b") end },
        { key = "flags", label = L["FLAGS"], width = 110, kind = "badge",
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
    view.clean.label = Tbl.Text(view.clean, 11, C.text)
    view.clean.label:SetPoint("LEFT", view.clean, "RIGHT", 1, 0)
    view.clean.label:SetText(L["Clean runs only"])
    view.clean:SetScript("OnClick", function() view:SetFilter("cleanOnly", not view.filters.cleanOnly) end)
    view.hint = Tbl.Text(bar, 11, C.dim, "RIGHT")
    view.hint:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -GAP - 2, -10)
    view.hint:SetText(L["Best per spec \195\151 category \195\151 race length, all characters"])
    view.bar = bar
    view.listHost = CreateFrame("Frame", nil, frame)
    view.listHost:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -FILTER_H)
    view.list = Tbl.New(view.listHost, Bests.Columns(), {
        sortKey = "dps", sortDesc = true,
        onClick = function(run) if view.hooks.open then view.hooks.open(run) end end,
        onDoubleClick = function(run) if view.hooks.share then view.hooks.share(run) end end,
        empty = L["No personal bests yet: finish a race to set one."],
    })
    return view
end

function View:Layout(width, height)
    self.listHost:SetSize(width, math.max(1, height - FILTER_H))
    self.list:Layout(width, math.max(1, height - FILTER_H))
end

--- Re-read the board and redraw.
function View:Refresh()
    local board = NS.Bests.Board({ cleanOnly = self.filters.cleanOnly == true })
    local options = Bests.Options(board)
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
