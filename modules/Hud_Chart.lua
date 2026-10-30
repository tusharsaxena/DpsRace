local _, NS = ...
-- modules/Hud_Chart.lua — the damage chart (#2) and the pace bar (#3): a row of vertical StatusBars,
-- one per time bucket of the race (modules/Slices.lua), and a pace bar (two StatusBars) that sets the
-- live damage against the board's best average pace. The HUD's running body draws both live; the HUD result card
-- and the Results detail draw the chart again after the race, for a run raced this session.
--
-- A VISUAL INDICATOR, NO MATH ON A VALUE. A bucket's value is the live total copied at its boundary:
-- secret in combat, and it stays secret. It goes to StatusBar:SetValue and nowhere else; the bar does
-- the comparison on screen. The scale is one of three:
--   * A, the board has a best: its plain final damage x HEADROOM, with its average pace drawn as a
--     diagonal from 0:00 to the best's level at the buzzer (no level line, no label: the owner's
--     call, 2026-10-25), one solid 2px line at 40% (the owner's call, 2026-10-26: a 1px dashed line
--     showed the Line region's stair steps at every dash).
--   * B, no best yet: the current live total, itself secret (SetMinMaxValues takes a secret max),
--     so the newest column is always full. No line, no diagonal, no number.
--   * After the race: the run's plain final damage, or with a best before the run (Bests.Before, the
--     run the result's delta and pace bar name) max(the run's damage, the best's at this run's
--     length) x HEADROOM, with the best's diagonal drawn as on scale A (Round C, 2026-10-25). Every
--     value is plain then.
-- The pace bar runs linearly from pace x (2 - m) to pace x m around the best's average damage by now
-- (m the *Pace bar range*, 1.5 by default: +-50%; plain, from GetTime()); its value is the live total,
-- and its tick, fixed in the middle of the bar, marks "on pace". The bar is two StatusBars split at
-- the tick (the owner's call, 2026-10-26): the left half runs lo to pace in the Pace look, with red
-- from its fill's end to the tick (a texture anchored to the fill texture), so behind pace shows red
-- for the shortfall; the right half runs pace to hi in green, so ahead shows green past the tick.
-- Both are handed the same value and clamp it (empty or full): we never compare it, and no color is
-- chosen from it; the color is where the fill ends, which the client draws. A number (+-x%) is not
-- possible live, because dividing a secret is not allowed. The HUD result card
-- draws it again after the race, the run's plain final damage against the best before it at the
-- buzzer (Chart.ResultPace).
--
-- THE HEADING (Round C, 2026-10-25): *Damage profile* in FONT.SECTION on a SECTION_H line, the Results
-- detail's heading role, with the view's note at its right. On the HUD the pace bar sits between the
-- heading and the plot (Place's `midH`), and the heading stays with the pace bar alone when the plot is
-- off or steps aside (SetParts). The heading's note is the bar's only caption (*vs best pace*, the
-- owner's call, 2026-10-26): the bar has no label of its own and spans the plot's width, edge to edge.
--
-- LAYOUT FROM CONFIG. Every size is the width the caller hands Place() and the configured plot height
-- (HUD > HUD Appearance > Damage chart); nothing reads a size or position back off a column. The plot
-- frame is RESERVE taller than that height, on top (the owner's third test round, 2026-10-26): one
-- row of cooldown icons (ICON and ICON_GAP) sits there, and the columns and the diagonal scale within
-- the configured height below it, so a single row of icons never covers them (Chart.FrameHeight). The
-- columns touch (the column gap defaults to 0) and read as one area over the plot's own backdrop:
-- each column's edges are whole pixels, x_i = floor(i * inner / count + 0.5), so no column is a
-- fraction wide and no seam shows between two. The diagonal is plain geometry (Line regions) on an
-- overlay frame one band over the columns (core/Constants.lua LAYERS.LEVEL.CHART_OVERLAY).
--
-- THE COOLDOWN ICONS (#14; icons for the first dots, the owner's call, 2026-10-26): the ability's own
-- icon, ICON px square, along the top of the plot at each cast of an important ability (a base
-- cooldown of 29 s or more, modules/Casts.lua), centered at x = INSET + clamp(t, 0, length) / length x
-- (width - 2 x INSET), the cast's plain race-clock time over the plain length across the width Place()
-- was handed, held inside the plot. An icon that would overlap the one placed last on its row drops to
-- the first row below with room, on as many rows as the whole plot frame holds (Chart.IconRowCount on
-- Chart.FrameHeight: 6 on the default 80 px plot, 3 on the 40 px minimum), the rows past the first
-- over the columns as before. The last row takes a cast with no room above as
-- an icon when it stands alone there, and a crowd of them as one *+n* mark at the first one's place, n
-- the casts it stands for, its hover listing each with its time (ResultsTips.CastCrowd): nothing is
-- dropped (the owner's second test round, 2026-10-26: a potion, a trinket and Bestial Wrath in one second
-- showed two icons). Pooled frames on the overlay, each icon with its art and a
-- hover everywhere the chart is drawn, the running HUD included (a plain frame): the client's full
-- spell tooltip, then its time (ResultsTips.CastAfter), beside the window it sits in, level with the
-- icon (ResultsTable.SpellTip, DR-03), a +n mark's list beside it too; moved only when the list, the length or the geometry changed. The icon is
-- C_Spell's for the cast's plain stored ID. Live from Casts.Live() (re-read only when the race heard
-- another cast), and after the race from the run's record; *Show cooldown icons* (live.castDots) turns
-- them off everywhere.

local Chart = {}
NS.HudChart = Chart

local L = NS.L
local Style = NS.Style
local FONT = Style.FONT

Chart.HEADROOM = 1.15   -- scale A: the best's final damage plus room to pass it
Chart.HEAD_H = Style.SECTION_H   -- the heading's line over the plot (FONT.SECTION)
Chart.AXIS_H = 12       -- the time labels under it
Chart.GAP = 2
Chart.INSET = 2         -- the plot's inner padding
Chart.DIAGONAL_W = 2    -- the diagonal's thickness
Chart.PACE_H = 12       -- the pace bar's line
Chart.ICON = 12         -- a cooldown icon's size (#14)
Chart.ICON_GAP = 1      -- between two rows of icons
Chart.RESERVE = Chart.ICON + Chart.ICON_GAP   -- the plot's headroom on top: one row of icons

-- The plot is a fill with no edge (the owner's call, 2026-10-26: the faint gray border is gone).
Chart.PLOT_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8" }
-- The skin's colors (core/SkinSetup.lua's owner tokens and the race's meaning hues).
local PACE_TRACK = "dr.chart.grid"     -- the pace bar's empty part
local DIAGONAL = "dr.chart.diag"       -- best's pace
local TICK = "dr.pace.tick"            -- on pace
local AHEAD = "dr.ahead"               -- the KPI's green: past the tick
local BEHIND = "sem.statusBad"         -- the KPI's red: the shortfall to the tick
local PACE_A = 0.85                    -- both halves' opacity (the bar's own, every skin)
local WHITE = "Interface\\Buttons\\WHITE8x8"
local ICON_CROP = { 0.08, 0.92, 0.08, 0.92 }   -- the icon art without its baked-in border
local MARK_BG = "handle.bg"                    -- a +n mark's square, dark under its white count

local D = NS.defaults.profile.appearance.chart
local LIVE = NS.defaults.profile.live

Chart.PACE_RANGE_MIN, Chart.PACE_RANGE_MAX = 1.1, 2.0   -- settings/Hud.lua's slider bounds (the low end >= 0)

-- ── pure ────────────────────────────────────────────────────────────────────────────────────────

--- The configured plot height, in pixels.
--- @return number
function Chart.PlotHeight()
    local v = NS.GetSetting and tonumber(NS.GetSetting("appearance.chart.height"))
    return v or D.height
end

--- The configured gap between two columns, in whole pixels (0 to 3).
--- @return number
function Chart.ColumnGap()
    local v = NS.GetSetting and tonumber(NS.GetSetting("appearance.chart.columnGap"))
    return math.max(0, math.floor(v or D.columnGap or 0))
end

--- Each column's left edge and width, in whole pixels from the plot's inner left, for `count`
--- columns across `inner` pixels with `gap` between two: the edges fall on x_i =
--- floor(i * inner / count + 0.5), a column spans to the next edge less the gap (the last keeps
--- its whole span), and none is narrower than 1. Plain config math, never a measured size.
--- @param inner number
--- @param count number
--- @param gap number|nil
--- @return table xs, table widths
function Chart.ColumnEdges(inner, count, gap)
    local xs, widths = {}, {}
    gap = gap or 0
    if count < 1 then return xs, widths end
    local function edge(i) return math.floor(i * inner / count + 0.5) end
    for i = 1, count do
        local x0, x1 = edge(i - 1), edge(i)
        xs[i] = x0
        widths[i] = math.max(1, x1 - x0 - (i < count and gap or 0))
    end
    return xs, widths
end

--- The plot frame's height for a configured plot `plotH` tall: that height (the columns' and the
--- diagonal's) plus RESERVE on top, the first row of icons' own.
--- @param plotH number
--- @return number
function Chart.FrameHeight(plotH)
    return (tonumber(plotH) or 0) + Chart.RESERVE
end

--- The chart block's whole height for a plot `plotH` tall: heading, `midH` (the HUD's pace bar line
--- between the heading and the plot), the plot frame (Chart.FrameHeight), gap, time labels.
--- @param plotH number
--- @param headH number|nil  default HEAD_H
--- @param midH number|nil  default 0
--- @return number
function Chart.BlockHeight(plotH, headH, midH)
    return (headH or Chart.HEAD_H) + (midH or 0) + Chart.FrameHeight(plotH) + Chart.GAP + Chart.AXIS_H
end

local function shared(run)
    return type(run.flags) == "table" and run.flags.sharedSession == true
end

-- `best` when it is another run with a plain damage and length to draw a pace from.
local function drawable(best, run)
    if type(best) ~= "table" or best == run or best.id == run.id then return nil end
    local damage = type(best.result) == "table" and best.result.damage
    local length = type(best.race) == "table" and best.race.length
    if type(damage) ~= "number" or damage <= 0 or type(length) ~= "number" or length <= 0 then return nil end
    return best
end

--- The best on `run`'s board (the board the HUD's result delta reads), when it has a plain damage
--- and length to draw from; never `run` itself.
--- @param run table
--- @return table|nil
function Chart.BestOf(run)
    if type(run) ~= "table" or not NS.Bests then return nil end
    return drawable(NS.Bests.Board()[NS.Bests.Key(run)], run)
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

--- The configured pace bar range (live.paceRange): how far either side of the best's pace the bar
--- reaches, clamped at read time to the slider's bounds (a value stored above 2.0 before Round C reads 2.0).
--- @return number
function Chart.PaceRange()
    local v = NS.GetSetting and tonumber(NS.GetSetting("live.paceRange"))
    return math.max(Chart.PACE_RANGE_MIN, math.min(Chart.PACE_RANGE_MAX, v or LIVE.paceRange))
end

--- The pace bar's ends around the best's pace by `elapsed`: lo = pace x (2 - m), hi = pace x m, with m
--- `range` (default the setting), so the pace sits in the middle; hi is at least lo + 1 (0:00).
--- @param best table
--- @param elapsed number
--- @param range number|nil
--- @return number lo, number hi
function Chart.PaceBounds(best, elapsed, range)
    local m = range or Chart.PaceRange()
    local pace = Chart.Pace(best, elapsed)
    local lo = pace * (2 - m)
    return lo, math.max(pace * m, lo + 1)
end

--- The on-pace tick's offset from the bar's left edge, in whole pixels: the middle of the bar. Plain
--- config math on the width Place() was handed, never a measured size.
--- @param barW number
--- @return number
function Chart.TickX(barW)
    return math.floor(barW / 2 + 0.5)
end

--- A cast's time on the chart, in pixels from the plot's left edge: INSET + clamp(t, 0, length) /
--- length x (width - 2 x INSET), so a pre-pull cast sits on 0:00 and a cast after the buzzer on the
--- end. Plain config math on the width Place() was handed; nil without a plain time and length.
--- @param t number  the cast's seconds on the race clock
--- @param length number
--- @param width number
--- @return number|nil
function Chart.TimeX(t, length, width)
    if type(t) ~= "number" or type(length) ~= "number" or length <= 0 then return nil end
    local inner = (tonumber(width) or 0) - 2 * Chart.INSET
    return Chart.INSET + math.max(0, math.min(t, length)) / length * inner
end

--- A cooldown icon's center x: the cast's time (Chart.TimeX), held so the whole icon stays inside the
--- plot (a cast at 0:00 or on the buzzer sits flush with the edge). Nil without a plain time and length.
--- @param t number
--- @param length number
--- @param width number
--- @return number|nil
function Chart.IconX(t, length, width)
    local x = Chart.TimeX(t, length, width)
    if not x then return nil end
    local half = Chart.ICON / 2
    return math.max(half, math.min(x, (tonumber(width) or 0) - half))
end

--- How many rows of icons a plot `plotH` tall holds: an icon and ICON_GAP each inside both insets, at
--- least one. Config math on the configured height, never a measured size.
--- @param plotH number
--- @return number
function Chart.IconRowCount(plotH)
    local inner = (tonumber(plotH) or 0) - 2 * Chart.INSET
    return math.max(1, math.floor((inner + Chart.ICON_GAP) / (Chart.ICON + Chart.ICON_GAP)))
end

-- The first of rows 1..n whose last icon is an icon's width or more left of `x`, or nil.
local function freeRow(last, x, n)
    for r = 1, n do
        if last[r] == nil or x - last[r] >= Chart.ICON then return r end
    end
    return nil
end

-- The indices in `spill` (in time order) in crowds: a crowd starts at its first cast and takes each
-- later one closer than an icon's width to that first.
local function crowds(xs, spill)
    local out, cur = {}, nil
    for _, i in ipairs(spill) do
        if cur and xs[i] - xs[cur[1]] < Chart.ICON then
            cur[#cur + 1] = i
        else
            cur = { i }
            out[#out + 1] = cur
        end
    end
    return out
end

--- Each icon's row for centers `xs` (in time order) on `maxRows` rows (default 2): the first row from
--- the top where the icon would not overlap the last one placed there (closer than an icon's width).
--- The last row is the overflow's: a cast with no room on the rows above sits there as an icon when no
--- other such cast is within an icon's width of it, and a crowd of them becomes one mark at the first
--- one's x, standing for every cast in it. Nothing is dropped: each index is in `rows` or in a mark.
--- @param xs table  numbers
--- @param maxRows number|nil
--- @return table rows  { [i] = row }, nil for a cast under a mark
--- @return table marks  { { x, row, members = { i, ... } }, ... }
function Chart.IconRows(xs, maxRows)
    maxRows = math.max(1, math.floor(tonumber(maxRows) or 2))
    local rows, last, spill = {}, {}, {}
    for i, x in ipairs(xs) do
        local r = freeRow(last, x, maxRows - 1)
        if r then
            rows[i], last[r] = r, x
        else
            spill[#spill + 1] = i
        end
    end
    local marks = {}
    for _, crowd in ipairs(crowds(xs, spill)) do
        if #crowd == 1 then
            rows[crowd[1]] = maxRows
        else
            marks[#marks + 1] = { x = xs[crowd[1]], row = maxRows, members = crowd }
        end
    end
    return rows, marks
end

--- A row's center y, from the plot's top (negative): the top row INSET under the edge, each next
--- an icon and ICON_GAP below the one before.
--- @param row number
--- @return number
function Chart.IconY(row)
    return -(Chart.INSET + Chart.ICON / 2 + (row - 1) * (Chart.ICON + Chart.ICON_GAP))
end

--- Whether the charts draw cooldown icons (live.castDots).
--- @return boolean
function Chart.ShowCooldowns()
    return not (NS.GetSetting and NS.GetSetting("live.castDots") == false)
end

--- A run's cooldown casts after the race (its important casts, Casts.Important), or nil when the
--- setting is off or the run has none.
--- @param run table
--- @return table|nil casts  { { t, id, pet }, ... }
function Chart.CooldownsOf(run)
    if not Chart.ShowCooldowns() or not NS.Casts then return nil end
    local casts = NS.Casts.Important(run)
    if #casts == 0 then return nil end
    return casts
end

--- What the running body draws: the chart's view and the pace bar's, each nil when hidden. Both hide
--- on a shared session; the pace bar also with no best. The chart's `cooldowns` are the race's
--- important casts so far, with `showCooldowns`.
--- @param run table
--- @param elapsed number|nil
--- @param showChart boolean  live.chart
--- @param showPace boolean  live.paceBar
--- @param showCooldowns boolean|nil  live.castDots
--- @return table|nil chart  { count, values, length, max, best, note, cooldowns }  (max nil: scale B, the live total)
--- @return table|nil pace  { lo, hi }
-- THE LIVE VIEWS ARE CACHED (the 20 Hz tick, performance-§3): the chart's view and the best behind it
-- are rebuilt only when what decides them changes. The best is looked up again only when the run or
-- the bests board changed (Bests.Board hands out a new table after every invalidation); the pace
-- table is one table, its ends refilled each pass.
local live = { pace = {} }

local function liveBest(run)
    local board = NS.Bests and NS.Bests.Board() or nil
    if live.bestRun ~= run or live.board ~= board or live.bestLength ~= run.race.length then
        live.bestRun, live.board, live.bestLength = run, board, run.race.length
        live.best = Chart.BestOf(run)
    end
    return live.best
end

local function liveChart(run, best)
    local length = run.race.length
    local rec = NS.Slices.Get(run.id)
    local values = rec and rec.values or nil
    if live.chartRun == run and live.chartBest == best and live.chartLength == length
        and live.values == values and live.chart then
        return live.chart
    end
    live.chartRun, live.chartBest, live.chartLength, live.values = run, best, length, values
    local chart = { count = NS.Slices.Count(length), values = values or {}, length = length,
                    note = L["first race on this board"] }
    if best then
        chart.best = best.result.damage
        chart.max = chart.best * Chart.HEADROOM
        chart.note = L["vs best pace"]
    end
    live.chart = chart
    return chart
end

-- The race's important casts so far: read again (Casts.Live, a new list) only when the race heard
-- another cast or a new race began, so the 20 Hz tick reuses one list.
local function liveCooldowns(run)
    local Casts = NS.Casts
    if not Casts then return nil end
    local n = Casts.Size()
    if live.cdRun ~= run or live.cdN ~= n or not live.cooldowns then
        live.cdRun, live.cdN = run, n
        live.cooldowns = Casts.Filter(Casts.Live(), Casts.LiveSpells())
    end
    return live.cooldowns
end

function Chart.LiveViews(run, elapsed, showChart, showPace, showCooldowns)
    if type(run) ~= "table" or type(run.race) ~= "table" or shared(run) then return nil, nil end
    local best = liveBest(run)
    local chart, pace
    if showChart then
        chart = liveChart(run, best)
        chart.cooldowns = showCooldowns and liveCooldowns(run) or nil
    end
    if showPace and best then
        pace = live.pace
        pace.lo, pace.hi = Chart.PaceBounds(best, elapsed)
    end
    return chart, pace
end

--- The HUD result card's pace bar (#3, 2026-10-25), or nil when it hides: the run's plain final damage
--- against the best before it (Bests.Before, the run the delta chip names, so the previous best when
--- this run just became the best) at the buzzer, the best's pace taken at the run's length through
--- PaceBounds, so the range and the tick are the running bar's. Hidden when Show pace bar is off, on a lost
--- run, on a shared session and with no earlier best.
--- @param run table
--- @param showPace boolean  live.paceBar
--- @return table|nil pace  { lo, hi, value }
function Chart.ResultPace(run, showPace)
    if not showPace or type(run) ~= "table" or run.status == "lost" or shared(run) then return nil end
    local damage = type(run.result) == "table" and run.result.damage
    local length = type(run.race) == "table" and run.race.length
    if type(damage) ~= "number" or type(length) ~= "number" or length <= 0 or not NS.Bests then return nil end
    local best = drawable(NS.Bests.Before(run), run)
    if not best then return nil end
    local lo, hi = Chart.PaceBounds(best, length)
    return { lo = lo, hi = hi, value = damage }
end

--- An after-the-race view against the best before the run (Round C, 2026-10-25): with `best` (a run
--- raced before `run` on its board, with a plain damage and length) the view gets the best's damage at
--- this run's length (`best`, the diagonal's end) and its max becomes max(the run's damage, that) x
--- HEADROOM, so the columns and the diagonal share one scale. Without one, or on a shared session, the
--- view is as given: scaled to the run's own damage, no diagonal. Plain numbers only (a stored run).
--- @param view table  { count, values, length, max, note }, max the run's plain final damage
--- @param run table
--- @param best table|nil
--- @return table view
function Chart.WithBest(view, run, best)
    best = type(run) == "table" and type(run.race) == "table" and drawable(best, run) or nil
    if not best or shared(run) then return view end
    local at = Chart.Pace(best, run.race.length)
    view.best = at
    view.max = math.max(view.max or 0, at) * Chart.HEADROOM
    view.note = L["vs best pace"]
    return view
end

--- The after-the-race chart's view for `run`, or nil when it has none (modules/Slices.lua Drawable):
--- its slices scaled to its plain final damage, against the best before it when there is one
--- (Chart.WithBest), with its cooldown casts (Chart.CooldownsOf).
--- @param run table
--- @return table|nil
function Chart.ResultView(run)
    local rec = NS.Slices.Drawable(run)
    if not rec then return nil end
    local view = { count = rec.count, values = rec.values, length = rec.length, max = run.result.damage, note = "",
                   cooldowns = Chart.CooldownsOf(run) }
    return Chart.WithBest(view, run, NS.Bests and NS.Bests.Before(run) or nil)
end

-- ── the chart ───────────────────────────────────────────────────────────────────────────────────

local Strip = {}
Strip.__index = Strip

local function newLine(frame, color)
    local l = frame:CreateLine(nil, "OVERLAY")
    l:SetThickness(Chart.DIAGONAL_W)
    Style.Fill(l, color)
    return l
end

-- The plot's backdrop: its color from HUD Appearance > Chart background, once per change (the same
-- stamp the columns read). It has no edge.
local function restylePlot(s)
    local A = NS.HudAppearance
    if not A or s.plotStamp == A.stamp or not s.plot.SetBackdropColor then return end
    s.plotStamp = A.stamp
    local bg = A.ChartBackground()
    s.plot:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
end

--- A chart built into `parent`: its heading, plot and time labels, placed by Place(). `titleFont`
--- (a Style.FONT value) sets the title's font and `headH` its line's height; both default to the
--- section heading's (FONT.SECTION on HEAD_H), which the HUD and the Results detail share.
--- @param parent table
--- @param titleFont string|nil
--- @param headH number|nil
--- @return table chart
function Chart.New(parent, titleFont, headH)
    local s = setmetatable({ parent = parent, cols = {}, diag = {}, headH = headH or Chart.HEAD_H,
                             iconPool = NS.Pool.New(), icons = {}, markPool = NS.Pool.New(), marks = {} },
                           Strip)
    s.title = Style.Text(parent, titleFont or FONT.SECTION)
    s.title:SetText(L["Damage profile"])
    s.note = Style.Text(parent, FONT.CAPTION, nil, "RIGHT")
    local plot = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if plot.SetBackdrop then
        plot:SetBackdrop(Chart.PLOT_BACKDROP)
    end
    s.plot = plot
    restylePlot(s)
    -- The diagonal's own frame, a band over the columns: a child frame draws over its parent's regions.
    s.over = CreateFrame("Frame", nil, plot)
    s.over:SetAllPoints(plot)
    s.over:SetFrameLevel(plot:GetFrameLevel() + NS.Constants.LAYERS.LEVEL.CHART_OVERLAY)
    s.diag[1] = newLine(s.over, DIAGONAL)
    s.axis = { Style.Text(parent, FONT.CAPTION), Style.Text(parent, FONT.CAPTION, nil, "CENTER"),
               Style.Text(parent, FONT.CAPTION, nil, "RIGHT") }
    return s
end

--- Show or hide the heading (its title and note) and the plot (with its time labels) apart: the HUD
--- keeps the heading over the pace bar when the plot is off or steps aside.
--- @param head boolean
--- @param plot boolean
function Strip:SetParts(head, plot)
    head, plot = head and true or false, plot and true or false
    self.title:SetShown(head)
    self.note:SetShown(head)
    self.plot:SetShown(plot)
    for _, fs in ipairs(self.axis) do fs:SetShown(plot) end
    self.shown = plot
end

--- Show or hide every part.
function Strip:SetShown(on)
    self:SetParts(on, on)
end

--- The note at the heading's right, for a heading shown without its plot (Draw sets it otherwise).
function Strip:SetNote(text)
    self.note:SetText(text or "")
end

--- Place the chart at `y` (negative, from `anchor`'s top) across `width`, its plot `plotH` tall (the
--- columns' height; the frame is Chart.FrameHeight, the icons' row on top) and `midH` (default 0)
--- under the heading's line.
--- @param anchor table
--- @param y number
--- @param width number
--- @param plotH number
--- @param midH number|nil
function Strip:Place(anchor, y, width, plotH, midH)
    self.width, self.plotH = width, plotH
    self.title:ClearAllPoints()
    self.title:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, y)
    self.note:ClearAllPoints()
    self.note:SetPoint("TOPRIGHT", anchor, "TOPLEFT", width, y)
    local py = y - self.headH - (midH or 0)
    self.plot:ClearAllPoints()
    self.plot:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, py)
    local frameH = Chart.FrameHeight(plotH)
    self.frameH = frameH
    self.plot:SetSize(width, frameH)
    local ay = py - frameH - Chart.GAP
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

-- A column: a vertical StatusBar and nothing else (no track of its own: the plot's backdrop is the
-- background, so the columns read as one area).
local function newColumn(plot)
    local col = CreateFrame("StatusBar", nil, plot)
    col:SetOrientation("VERTICAL")
    return col
end

-- Lay `count` columns across the plot (from Place's width and height and the configured gap, never a
-- measured size), each on whole-pixel edges (Chart.ColumnEdges), within the configured height from the
-- plot's bottom: the RESERVE row over them is the icons'.
function Strip:layoutColumns(count)
    local gap = Chart.ColumnGap()
    local key = ("%d|%s|%s|%d"):format(count, tostring(self.width), tostring(self.plotH), gap)
    if self.geometry == key then return end
    self.geometry = key
    local inner = math.max(0, (self.width or 0) - 2 * Chart.INSET)
    local xs, widths = Chart.ColumnEdges(inner, count, gap)
    local h = math.max(1, (self.plotH or 0) - 2 * Chart.INSET)
    self.colX, self.colW, self.colH = xs, widths, h
    for i = 1, count do
        local col = self.cols[i] or newColumn(self.plot)
        self.cols[i] = col
        col:ClearAllPoints()
        col:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", Chart.INSET + xs[i], Chart.INSET)
        col:SetSize(widths[i], h)
    end
    self.lines = nil
end

-- The line from (x1, y1) to (x2, y2) on the overlay.
local function drawLine(l, over, x1, y1, x2, y2)
    l:SetStartPoint("BOTTOMLEFT", over, x1, y1)
    l:SetEndPoint("BOTTOMLEFT", over, x2, y2)
end

local function showAll(lines, on)
    for _, l in ipairs(lines) do l:SetShown(on) end
end

-- The best's average-pace diagonal, plain geometry, from 0:00 to the best's level at the buzzer:
-- `best` over `max`, both plain whenever a best is given (scale A: max = best x HEADROOM; after the
-- race: Chart.WithBest's shared max). Moved only when the geometry or that level changed.
function Strip:drawPace(best, max)
    local on = best ~= nil
    showAll(self.diag, on)
    if not on then return end
    local key = ("%s|%s"):format(tostring(self.geometry), tostring(best / max))
    if self.lines == key then return end
    self.lines = key
    local x0, y0 = Chart.INSET, Chart.INSET
    local x1 = (self.width or 0) - Chart.INSET
    local level = y0 + ((self.plotH or 0) - 2 * Chart.INSET) * best / max
    drawLine(self.diag[1], self.over, x0, y0, x1, level)
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
    restylePlot(self)
    self:layoutColumns(count)
    for i = 1, count do
        local col = self.cols[i]
        restyle(col)
        fill(col, view.values and view.values[i], max)
        col:Show()
    end
    for i = count + 1, #self.cols do self.cols[i]:Hide() end
    self:drawPace(view.best, view.max)
    local length = view.length or 0
    self:drawIcons(view.cooldowns, length)
    self.note:SetText(view.note or "")
    self.axis[1]:SetText(NS.Format.Length(0))
    self.axis[2]:SetText(NS.Format.Length(math.floor(length / 2)))
    self.axis[3]:SetText(NS.Format.Length(length))
end

-- ── the cooldown icons ──────────────────────────────────────────────────────────────────────────

-- An icon's hover (DR-03, the owner's call, 2026-10-30): the client's full spell tooltip, then the
-- time it was cast on the race clock (modules/Results_Tips.lua CastAfter), right of the window the
-- chart sits in (the HUD or the Results window), level with the icon. The cast's ID is plain (the
-- cast events, spec §2). Both modules are read at call time (they load after this one).
local function iconEnter(icon)
    local Tbl, Tips = NS.ResultsTable, NS.ResultsTips
    if icon.cast and Tbl and Tips then
        Tbl.SpellTip(Tbl.WindowOf(icon), icon, icon.cast.id, Tips.CastAfter(icon.cast))
    end
end

local function iconLeave()
    if NS.ResultsTable then NS.ResultsTable.HideTip() end
end

-- A +n mark's hover: every cast it stands for, each with its time, on bullets, beside the window as
-- an icon's is.
local function markEnter(mark)
    local Tbl, Tips = NS.ResultsTable, NS.ResultsTips
    if mark.casts and Tbl and Tips then Tbl.SideTip(Tbl.WindowOf(mark), mark, Tips.CastCrowd(mark.casts)) end
end

-- An icon: a plain frame on the overlay (it takes the mouse for its tooltip) holding the spell's art.
local function newIcon(over)
    local f = CreateFrame("Frame", nil, over)
    f:SetSize(Chart.ICON, Chart.ICON)
    f:EnableMouse(true)
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints(f)
    f.tex:SetTexCoord(ICON_CROP[1], ICON_CROP[2], ICON_CROP[3], ICON_CROP[4])
    f:SetScript("OnEnter", iconEnter)
    f:SetScript("OnLeave", iconLeave)
    return f
end

-- A +n mark: a plain frame an icon's size on the overlay, a dark square holding the count.
local function newMark(over)
    local f = CreateFrame("Frame", nil, over)
    f:SetSize(Chart.ICON, Chart.ICON)
    f:EnableMouse(true)
    f.bg = f:CreateTexture(nil, "ARTWORK")
    f.bg:SetAllPoints(f)
    Style.Fill(f.bg, MARK_BG)
    f.text = Style.Text(f, FONT.TEXT, nil, "CENTER")
    f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
    f:SetScript("OnEnter", markEnter)
    f:SetScript("OnLeave", iconLeave)
    return f
end

-- One +n mark for `casts` centered at (x, y) from the plot's top left.
function Strip:placeMark(casts, x, y, row)
    local f = NS.Pool.Acquire(self.markPool, function() return newMark(self.over) end)
    f.casts = casts
    f.text:SetText(L["+%d"]:format(#casts))
    f:ClearAllPoints()
    f:SetPoint("CENTER", self.over, "TOPLEFT", x, y)
    self.marks[#self.marks + 1] = { frame = f, casts = casts, x = x, row = row }
end

-- One icon for `cast` centered at (x, y) from the plot's top left.
function Strip:placeIcon(cast, x, y, row)
    local f = NS.Pool.Acquire(self.iconPool, function() return newIcon(self.over) end)
    f.cast = cast
    f.tex:SetTexture(NS.HudBreakdown.SpellIcon(cast.id))
    f:ClearAllPoints()
    f:SetPoint("CENTER", self.over, "TOPLEFT", x, y)
    self.icons[#self.icons + 1] = { frame = f, cast = cast, x = x, row = row }
end

-- The icons for `casts` (plain times and IDs) over `length`, laid again only when the list, its size,
-- the length or the geometry changed: compared field by field, so the 20 Hz tick builds nothing.
function Strip:drawIcons(casts, length)
    local n = casts and #casts or 0
    if self.iconList == casts and self.iconN == n and self.iconLen == length and self.iconGeom == self.geometry then
        return
    end
    self.iconList, self.iconN, self.iconLen, self.iconGeom = casts, n, length, self.geometry
    NS.Pool.ReleaseAll(self.iconPool, function(f) f.cast = nil end)
    NS.Pool.ReleaseAll(self.markPool, function(f) f.casts = nil end)
    self.icons, self.marks = {}, {}
    local placed, xs = {}, {}
    for i = 1, n do
        local x = Chart.IconX(casts[i].t, length, self.width)
        if x then
            placed[#placed + 1], xs[#xs + 1] = casts[i], x
        end
    end
    local rows, marks = Chart.IconRows(xs, Chart.IconRowCount(Chart.FrameHeight(self.plotH)))
    for i, cast in ipairs(placed) do
        if rows[i] then self:placeIcon(cast, xs[i], Chart.IconY(rows[i]), rows[i]) end
    end
    for _, m in ipairs(marks) do
        local members = {}
        for k, i in ipairs(m.members) do members[k] = placed[i] end
        self:placeMark(members, m.x, Chart.IconY(m.row), m.row)
    end
end

--- The icons drawn now, for the suites: { { frame, cast, x, row }, ... }.
function Strip:Icons()
    return self.icons
end

--- The +n marks drawn now, for the suites: { { frame, casts, x, row }, ... }.
function Strip:Marks()
    return self.marks
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

-- The red shortfall: from the behind half's fill end to the tick. Anchored to the fill texture, so
-- the client places it from the value; re-anchored whenever the fill texture is set (the bar may
-- hand back a new region).
local function anchorShortfall(p)
    local fillTex = p.behind:GetStatusBarTexture()
    p.shortfall:ClearAllPoints()
    p.shortfall:SetPoint("TOPLEFT", fillTex, "TOPRIGHT", 0, 0)
    p.shortfall:SetPoint("BOTTOMRIGHT", p.behind, "BOTTOMRIGHT", 0, 0)
end

local function halfBar(parent)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetMinMaxValues(0, 1)
    b:SetValue(0)
    return b
end

--- The pace bar built into `parent`: the track, the behind and ahead halves split at the on-pace tick,
--- and the tick over both (placed by Place). No caption: the heading's note names it.
--- @param parent table
--- @return table pace
function Chart.NewPace(parent)
    local p = setmetatable({}, Pace)
    p.bar = CreateFrame("Frame", nil, parent)
    local track = p.bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(p.bar)
    Style.Fill(track, PACE_TRACK)
    p.behind = halfBar(p.bar)
    p.ahead = halfBar(p.bar)
    p.ahead:SetStatusBarTexture(WHITE)
    p.ahead:SetStatusBarColor(Style.Rgba(AHEAD, PACE_A))   -- again on every restyle (SetRange)
    p.shortfall = p.behind:CreateTexture(nil, "ARTWORK")
    Style.Fill(p.shortfall, BEHIND, PACE_A)
    p.behind:SetStatusBarTexture(WHITE)
    anchorShortfall(p)
    -- The tick on its own frame over both halves: a child frame draws over its parent's regions.
    p.over = CreateFrame("Frame", nil, p.bar)
    p.over:SetAllPoints(p.bar)
    p.over:SetFrameLevel(p.bar:GetFrameLevel() + 2)
    p.tick = p.over:CreateTexture(nil, "OVERLAY")
    Style.Fill(p.tick, TICK)
    p.tick:SetWidth(2)
    p.tick:SetPoint("TOP", p.bar, "TOP", 0, 2)
    p.tick:SetPoint("BOTTOM", p.bar, "BOTTOM", 0, -2)
    return p
end

function Pace:SetShown(on)
    self.bar:SetShown(on and true or false)
end

--- Place it at `y` (negative, from `anchor`'s top) across `width`: the plot's whole width, edge to edge.
function Pace:Place(anchor, y, width)
    self.bar:ClearAllPoints()
    self.bar:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, y - 2)
    self.barW = math.max(1, width)
    self.bar:SetSize(self.barW, Chart.PACE_H - 4)
    self:PlaceTick()
end

--- The on-pace tick in the middle of the bar's configured width, the behind half left of it and the
--- ahead half right of it; moved only when the width changed. Config only, never a measured size.
function Pace:PlaceTick()
    local barW = self.barW
    if not barW or self.tickW == barW then return end
    self.tickW = barW
    local x = Chart.TickX(barW)
    local h = Chart.PACE_H - 4
    self.tick:ClearAllPoints()
    self.tick:SetPoint("TOP", self.bar, "TOPLEFT", x, 2)
    self.tick:SetPoint("BOTTOM", self.bar, "BOTTOMLEFT", x, -2)
    self.behind:ClearAllPoints()
    self.behind:SetPoint("TOPLEFT", self.bar, "TOPLEFT", 0, 0)
    self.behind:SetSize(math.max(1, x), h)
    self.ahead:ClearAllPoints()
    self.ahead:SetPoint("TOPLEFT", self.bar, "TOPLEFT", x, 0)
    self.ahead:SetSize(math.max(1, barW - x), h)
end

--- The range: pace x (2 - m) to pace x m around the best's pace now (plain, Chart.PaceBounds). The
--- behind half runs lo to the middle (the pace), the ahead half the middle to hi.
function Pace:SetRange(lo, hi)
    self:PlaceTick()
    local A = NS.HudAppearance
    if A and self.stamp ~= A.stamp then
        self.stamp = A.stamp
        local look = A.Pace()
        self.behind:SetStatusBarTexture(look.texture)
        self.behind:SetStatusBarColor(look.r, look.g, look.b, look.a)
        self.ahead:SetStatusBarTexture(look.texture)
        self.ahead:SetStatusBarColor(Style.Rgba(AHEAD, PACE_A))
        anchorShortfall(self)
    end
    local mid = (lo + hi) / 2
    self.behind:SetMinMaxValues(lo, mid)
    self.ahead:SetMinMaxValues(mid, hi)
end

--- The live total (opaque), straight to both halves: each clamps it (nothing here compares it). Behind
--- pace, the behind half stops short of the tick and the red shortfall fills the rest; ahead, the
--- behind half is full and the ahead half fills green past the tick. None reads empty.
function Pace:SetValue(total)
    if total == nil then total = 0 end
    self.behind:SetValue(total)
    self.ahead:SetValue(total)
end
