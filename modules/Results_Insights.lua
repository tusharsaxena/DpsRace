local _, NS = ...
-- modules/Results_Insights.lua — the Results window's Insights tab (#12), in place of the Bests board
-- (dropped by the owner, 2026-10-28; NS.Bests stays as a data module). PLACEHOLDER (N1 of
-- docs/superpowers/plans/2026-10-28-ignore-list-insights.md): the pane counts the runs Insights will
-- read and shows the empty state when there are none. The cards, the charts and the filter bar land in
-- N4, which grows this file.
--
-- THE VIEW CONTRACT is the Runs tab's, so the shell (modules/Results.lua) treats both tabs alike:
-- frame, Layout, Resize, Refresh, Count. A lost run never counts (the plan's Filters notes).

local Insights = {}
NS.ResultsInsights = Insights

local L = NS.L
local Tbl = NS.ResultsTable

local View = {}
View.__index = View

--- The Insights tab in `parent`.
--- @param parent table
--- @param hooks table  { open(run), menu(run, row), count(text) }
function Insights.Build(parent, hooks)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    local view = setmetatable({ frame = frame, hooks = hooks or {}, n = 0 }, View)
    view.empty = Tbl.Text(frame, Tbl.FONT.EMPTY, nil, "CENTER")
    view.empty:SetPoint("TOP", frame, "TOP", 0, -24)
    view.empty:SetText(L["No runs match these filters."])
    view.empty:Hide()
    return view
end

function View:Layout(width, height)
    self.width, self.height = width, height
end

--- While the window is being sized (modules/Sizing.lua): the size noted, nothing redrawn.
function View:Resize(width, height)
    self.width, self.height = width, height
end

--- Re-read the runs and redraw: the count for the footer, the empty state.
function View:Refresh()
    local n = 0
    for _, run in ipairs(NS.ResultsSource.All()) do
        if run.status ~= "lost" then n = n + 1 end
    end
    self.n = n
    if self.hooks.count then self.hooks.count(n == 1 and L["1 run"] or L["%d runs"]:format(n)) end
    self.empty:SetShown(n == 0)
end

--- How many runs the tab reads now.
function View:Count()
    return self.n
end
