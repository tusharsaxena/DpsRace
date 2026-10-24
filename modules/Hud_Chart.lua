local _, NS = ...
-- modules/Hud_Chart.lua — the damage chart (#2) and the pace bar (#3): a row of vertical StatusBars,
-- one per time bucket of the race (modules/Slices.lua), and one StatusBar that sets the live damage
-- against the board's best average pace. The HUD's running body draws both live; the HUD result card
-- and the Results detail draw the chart again after the race, for a run raced this session.
--
-- A VISUAL INDICATOR, NO MATH ON A VALUE. A bucket's value is the live total copied at its boundary:
-- secret in combat, and it stays secret. It goes to StatusBar:SetValue and nowhere else; the bar does
-- the comparison on screen. The scale is one of three:
--   * A, the board has a best: its plain final damage x HEADROOM, with the best's level drawn as a
--     gold line and its average pace as a dashed diagonal from 0:00 to the buzzer.
--   * B, no best yet: the current live total, itself secret (SetMinMaxValues takes a secret max),
--     so the newest column is always full. No line, no diagonal, no number.
--   * After the race: the run's plain final damage.
-- The pace bar's range is twice the best's average damage by now (plain, from GetTime()); its value is
-- the live total, and its center tick marks "on pace". It says nothing more: no ahead or behind, no
-- color chosen from the value, because comparing a secret is not allowed.
--
-- LAYOUT FROM CONFIG. Every size is the width the caller hands Place() and the configured plot height
-- (HUD > HUD Appearance > Damage chart); nothing reads a size or position back off a column. The best
-- line and the diagonal are plain geometry (Line regions) on an overlay frame one band over the
-- columns (core/Constants.lua LAYERS.LEVEL.CHART_OVERLAY).

local Chart = {}
NS.HudChart = Chart

local L = NS.L
local Style = NS.Style
local FONT = Style.FONT

Chart.HEADROOM = 1.15   -- scale A: the best's final damage plus room to pass it
Chart.HEAD_H = 14       -- the header line over the plot
Chart.AXIS_H = 12       -- the time labels under it
Chart.GAP = 2
Chart.INSET = 2         -- the plot's inner padding
Chart.COL_GAP = 1
Chart.DASHES = 16       -- dashes in the diagonal and in the best line
Chart.PACE_H = 12       -- the pace bar's line
Chart.PACE_LABEL_W = 78

local FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local PLOT_BG, PLOT_EDGE = { 0, 0, 0, 0.35 }, { 1, 1, 1, 0.10 }
local TRACK = { 1, 1, 1, 0.04 }
local BEST = { 0.79, 0.64, 0.0, 0.9 }
local DIAGONAL = { 0.9, 0.9, 0.92, 0.7 }
local TICK = { 1, 1, 1, 0.85 }

local D = NS.defaults.profile.appearance.chart

-- ── pure ────────────────────────────────────────────────────────────────────────────────────────

--- The configured plot height, in pixels.
--- @return number
function Chart.PlotHeight()
    local v = NS.GetSetting and tonumber(NS.GetSetting("appearance.chart.height"))
    return v or D.height
end

--- The chart block's whole height for a plot `plotH` tall: header, plot, gap, time labels.
--- @param plotH number
--- @return number
function Chart.BlockHeight(plotH)
    return Chart.HEAD_H + plotH + Chart.GAP + Chart.AXIS_H
end

local function shared(run)
    return type(run.flags) == "table" and run.flags.sharedSession == true
end

--- The best on `run`'s board (the board the HUD's result delta reads), when it has a plain damage
--- and length to draw from; never `run` itself.
--- @param run table
--- @return table|nil
function Chart.BestOf(run)
    if type(run) ~= "table" or not NS.Bests then return nil end
    local best = NS.Bests.Board()[NS.Bests.Key(run)]
    if type(best) ~= "table" or best == run or best.id == run.id then return nil end
    local damage = type(best.result) == "table" and best.result.damage
    local length = type(best.race) == "table" and best.race.length
    if type(damage) ~= "number" or damage <= 0 or type(length) ~= "number" or length <= 0 then return nil end
    return best
end

--- The best's average damage by `elapsed` seconds: its final damage spread evenly over its length.
--- @param best table  Chart.BestOf's
--- @param elapsed number
--- @return number
function Chart.Pace(best, elapsed)
    local length = best.race.length
    local t = math.max(0, math.min(tonumber(elapsed) or 0, length))
    return best.result.damage * t / length
end

--- The pace bar's range: twice the pace, so a half-full bar is on pace (at least 1, for 0:00).
function Chart.PaceMax(best, elapsed)
    return math.max(2 * Chart.Pace(best, elapsed), 1)
end

--- What the running body draws: the chart's view and the pace bar's, each nil when hidden. Both hide
--- on a shared session; the pace bar also with no best.
--- @param run table
--- @param elapsed number|nil
--- @param showChart boolean  live.chart
--- @param showPace boolean  live.paceBar
--- @return table|nil chart  { count, values, length, max, best, note }  (max nil: scale B, the live total)
--- @return table|nil pace  { max }
function Chart.LiveViews(run, elapsed, showChart, showPace)
    if type(run) ~= "table" or type(run.race) ~= "table" or shared(run) then return nil, nil end
    local best = Chart.BestOf(run)
    local chart, pace
    if showChart then
        local length = run.race.length
        local rec = NS.Slices.Get(run.id)
        chart = { count = NS.Slices.Count(length), values = rec and rec.values or {}, length = length,
                  note = L["first race on this board"] }
        if best then
            chart.best = best.result.damage
            chart.max = chart.best * Chart.HEADROOM
            chart.note = L["vs best pace"]
        end
    end
    if showPace and best then pace = { max = Chart.PaceMax(best, elapsed) } end
    return chart, pace
end

--- The after-the-race chart's view for `run`, or nil when it has none (modules/Slices.lua Drawable):
--- its slices scaled to its plain final damage.
--- @param run table
--- @return table|nil
function Chart.ResultView(run)
    local rec = NS.Slices.Drawable(run)
    if not rec then return nil end
    return { count = rec.count, values = rec.values, length = rec.length, max = run.result.damage, note = "" }
end

-- ── the chart ───────────────────────────────────────────────────────────────────────────────────

local Strip = {}
Strip.__index = Strip

local function dash(frame, color)
    local l = frame:CreateLine(nil, "OVERLAY")
    l:SetThickness(1)
    l:SetColorTexture(color[1], color[2], color[3], color[4])
    return l
end

--- A chart built into `parent`: its header, plot and time labels, placed by Place().
--- @param parent table
--- @return table chart
function Chart.New(parent)
    local s = setmetatable({ parent = parent, cols = {}, diag = {}, bestLine = {} }, Strip)
    s.title = Style.Text(parent, FONT.HEADER)
    s.title:SetText(L["Damage over the race"])
    s.note = Style.Text(parent, FONT.CAPTION, nil, "RIGHT")
    local plot = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if plot.SetBackdrop then
        plot:SetBackdrop(FLAT)
        plot:SetBackdropColor(PLOT_BG[1], PLOT_BG[2], PLOT_BG[3], PLOT_BG[4])
        plot:SetBackdropBorderColor(PLOT_EDGE[1], PLOT_EDGE[2], PLOT_EDGE[3], PLOT_EDGE[4])
    end
    s.plot = plot
    -- The lines' own frame, a band over the columns: a child frame draws over its parent's regions.
    s.over = CreateFrame("Frame", nil, plot)
    s.over:SetAllPoints(plot)
    s.over:SetFrameLevel(plot:GetFrameLevel() + NS.Constants.LAYERS.LEVEL.CHART_OVERLAY)
    for i = 1, Chart.DASHES do
        s.diag[i] = dash(s.over, DIAGONAL)
        s.bestLine[i] = dash(s.over, BEST)
    end
    s.bestLabel = Style.Text(s.over, FONT.CAPTION, BEST, "RIGHT")
    s.bestLabel:SetPoint("TOPRIGHT", s.over, "TOPRIGHT", -3, -2)
    s.axis = { Style.Text(parent, FONT.CAPTION), Style.Text(parent, FONT.CAPTION, nil, "CENTER"),
               Style.Text(parent, FONT.CAPTION, nil, "RIGHT") }
    return s
end

local REGIONS = { "title", "note", "plot" }

--- Show or hide every part.
function Strip:SetShown(on)
    on = on and true or false
    for _, key in ipairs(REGIONS) do self[key]:SetShown(on) end
    for _, fs in ipairs(self.axis) do fs:SetShown(on) end
    self.shown = on
end

--- Place the chart at `y` (negative, from `anchor`'s top) across `width`, its plot `plotH` tall.
--- @param anchor table
--- @param y number
--- @param width number
--- @param plotH number
function Strip:Place(anchor, y, width, plotH)
    self.width, self.plotH = width, plotH
    self.title:ClearAllPoints()
    self.title:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, y)
    self.note:ClearAllPoints()
    self.note:SetPoint("TOPRIGHT", anchor, "TOPLEFT", width, y)
    self.plot:ClearAllPoints()
    self.plot:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, y - Chart.HEAD_H)
    self.plot:SetSize(width, plotH)
    local ay = y - Chart.HEAD_H - plotH - Chart.GAP
    local points = { { "TOPLEFT", 0 }, { "TOP", width / 2 }, { "TOPRIGHT", width } }
    for i, fs in ipairs(self.axis) do
        fs:ClearAllPoints()
        fs:SetPoint(points[i][1], anchor, "TOPLEFT", points[i][2], ay)
    end
    self.geometry = nil   -- the columns and lines follow on the next Draw
end

-- The columns' look, once per HUD Appearance change.
local function restyle(col)
    local A = NS.HudAppearance
    if not A or col.stamp == A.stamp then return end
    col.stamp = A.stamp
    local fill = A.Chart()
    col:SetStatusBarTexture(fill.texture)
    col:SetStatusBarColor(fill.r, fill.g, fill.b, fill.a)
end

local function newColumn(plot)
    local col = CreateFrame("StatusBar", nil, plot)
    col:SetOrientation("VERTICAL")
    local track = col:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(col)
    track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
    return col
end

-- Lay `count` columns across the plot (from Place's width and height, never a measured size).
function Strip:layoutColumns(count)
    local key = ("%d|%s|%s"):format(count, tostring(self.width), tostring(self.plotH))
    if self.geometry == key then return end
    self.geometry = key
    local inner = (self.width or 0) - 2 * Chart.INSET
    local colW = math.max(0.5, (inner - (count - 1) * Chart.COL_GAP) / count)
    local h = math.max(1, (self.plotH or 0) - 2 * Chart.INSET)
    for i = 1, count do
        local col = self.cols[i] or newColumn(self.plot)
        self.cols[i] = col
        col:ClearAllPoints()
        col:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", Chart.INSET + (i - 1) * (colW + Chart.COL_GAP), Chart.INSET)
        col:SetSize(colW, h)
    end
    self.lines = nil
end

-- `segments` dashes from (x1, y1) to (x2, y2) on the overlay, each 60% of its step.
local function dashes(lines, over, x1, y1, x2, y2)
    local n = #lines
    for k = 1, n do
        local a, b = (k - 1) / n, (k - 0.4) / n
        local l = lines[k]
        l:SetStartPoint("BOTTOMLEFT", over, x1 + (x2 - x1) * a, y1 + (y2 - y1) * a)
        l:SetEndPoint("BOTTOMLEFT", over, x1 + (x2 - x1) * b, y1 + (y2 - y1) * b)
    end
end

local function showAll(lines, on)
    for _, l in ipairs(lines) do l:SetShown(on) end
end

-- Scale A's overlay: the best's level and its average-pace diagonal, plain geometry.
function Strip:drawBest(best)
    local on = best ~= nil
    showAll(self.diag, on)
    showAll(self.bestLine, on)
    self.bestLabel:SetShown(on)
    if not on then return end
    self.bestLabel:SetText(L["Best %s"]:format(NS.Format.Number(best)))
    if self.lines == self.geometry then return end
    self.lines = self.geometry
    local x0, y0 = Chart.INSET, Chart.INSET
    local x1 = (self.width or 0) - Chart.INSET
    local level = y0 + ((self.plotH or 0) - 2 * Chart.INSET) / Chart.HEADROOM
    dashes(self.bestLine, self.over, x0, level, x1, level)
    dashes(self.diag, self.over, x0, y0, x1, level)
end

local function fill(col, value, max)
    if value == nil or max == nil then
        col:SetMinMaxValues(0, 1)
        col:SetValue(0)
        return
    end
    col:SetMinMaxValues(0, max)
    col:SetValue(value)
end

--- Draw `view` (Chart.LiveViews' or ResultView's). `max` may be a secret (scale B): it, like each
--- bucket's value, only reaches SetMinMaxValues and SetValue.
--- @param view table  { count, values, length, max, best, note }
--- @param max any|nil  overrides view.max (scale B's live total)
function Strip:Draw(view, max)
    if max == nil then max = view.max end
    local count = view.count or 0
    self:layoutColumns(count)
    for i = 1, count do
        local col = self.cols[i]
        restyle(col)
        fill(col, view.values and view.values[i], max)
        col:Show()
    end
    for i = count + 1, #self.cols do self.cols[i]:Hide() end
    self:drawBest(view.best)
    self.note:SetText(view.note or "")
    local length = view.length or 0
    self.axis[1]:SetText(NS.Format.Length(0))
    self.axis[2]:SetText(NS.Format.Length(math.floor(length / 2)))
    self.axis[3]:SetText(NS.Format.Length(length))
end

--- The columns drawn now, for the suites.
function Strip:Columns()
    local out = {}
    for i, col in ipairs(self.cols) do
        if col:IsShown() then out[i] = col end
    end
    return out
end

-- ── the pace bar ────────────────────────────────────────────────────────────────────────────────

local Pace = {}
Pace.__index = Pace

--- The pace bar built into `parent`: its caption, the bar and the on-pace tick at its center.
--- @param parent table
--- @return table pace
function Chart.NewPace(parent)
    local p = setmetatable({}, Pace)
    p.label = Style.Text(parent, FONT.CAPTION)
    p.label:SetText(L["vs best pace"])
    p.bar = CreateFrame("StatusBar", nil, parent)
    local track = p.bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(p.bar)
    track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4] * 2)
    p.tick = p.bar:CreateTexture(nil, "OVERLAY")
    p.tick:SetColorTexture(TICK[1], TICK[2], TICK[3], TICK[4])
    p.tick:SetWidth(2)
    p.tick:SetPoint("TOP", p.bar, "TOP", 0, 2)
    p.tick:SetPoint("BOTTOM", p.bar, "BOTTOM", 0, -2)
    p.bar:SetMinMaxValues(0, 1)
    p.bar:SetValue(0)
    return p
end

function Pace:SetShown(on)
    on = on and true or false
    self.label:SetShown(on)
    self.bar:SetShown(on)
end

--- Place it at `y` (negative, from `anchor`'s top) across `width`.
function Pace:Place(anchor, y, width)
    self.label:ClearAllPoints()
    self.label:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, y)
    self.bar:ClearAllPoints()
    self.bar:SetPoint("TOPLEFT", anchor, "TOPLEFT", Chart.PACE_LABEL_W, y - 2)
    self.bar:SetSize(math.max(1, width - Chart.PACE_LABEL_W), Chart.PACE_H - 4)
end

--- The range: twice the best's pace now (plain).
function Pace:SetMax(max)
    local A = NS.HudAppearance
    if A and self.stamp ~= A.stamp then
        self.stamp = A.stamp
        local look = A.Chart()
        self.bar:SetStatusBarTexture(look.texture)
        self.bar:SetStatusBarColor(look.r, look.g, look.b, look.a)
    end
    self.bar:SetMinMaxValues(0, max)
end

--- The live total (opaque), straight to the bar; none reads empty.
function Pace:SetValue(total)
    if total == nil then return self.bar:SetValue(0) end
    self.bar:SetValue(total)
end
