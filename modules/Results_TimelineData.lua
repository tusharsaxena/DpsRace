local _, NS = ...
-- modules/Results_TimelineData.lua — the ability timeline's pure half: the rows, the span and ticks, the
-- zoom's arithmetic, the lanes' and strips' geometry and the words its tooltips and legend carry. No frame
-- is touched here. Peeled out of modules/Results_Timeline.lua (layout-§1), which builds the table and
-- its constants and loads first; every member below lands on that same NS.ResultsTimeline.

local Timeline = NS.ResultsTimeline

local L = NS.L
local Style = NS.Style
local SEP = " \194\183 "

-- ── the rows, the zoom, the geometry ────────────────────────────────────────────────────────────────────────────────────────

--- Whether a run has casts to draw (the detail's Timeline button is live only then).
function Timeline.Has(run)
    local list = NS.Casts.Of(run)
    return list ~= nil and #list > 0
end

-- A run's casts grouped by ability (Casts.Group), or nil when it has none recorded.
local function groupsOf(run)
    local list = NS.Casts.Of(run)
    if not list then return nil end
    return NS.Casts.Group(list, run.casts.spells)
end

-- Important abilities (base cooldown 29 s or more) first, the longest first; then the rest by this run's
-- count, then the compared run's; the player's before the pet's, then the id.
local function before(a, b)
    local ia, ib = NS.Casts.IsLong(a.cd), NS.Casts.IsLong(b.cd)
    if ia ~= ib then return ia end
    if ia and a.cd ~= b.cd then return a.cd > b.cd end
    if a.countA ~= b.countA then return a.countA > b.countA end
    if a.countB ~= b.countB then return a.countB > b.countB end
    if a.pet ~= b.pet then return not a.pet end
    return a.id < b.id
end

-- Each group of `groups` into its row (made on first sight), on lane `side` ("a" this run, "b" the
-- compared run). A row's cooldown is this run's, or the compared run's when this run never cast it.
local function merge(rows, index, groups, side)
    for _, g in ipairs(groups or {}) do
        local key = (g.pet and "p" or "") .. g.id
        local row = index[key]
        if not row then
            row = { id = g.id, pet = g.pet, cd = 0, a = {}, b = {}, countA = 0, countB = 0 }
            index[key] = row
            rows[#rows + 1] = row
        end
        row[side] = g.times
        if side == "a" then row.countA = g.count else row.countB = g.count end
        if row.cd == 0 then row.cd = g.cd end
    end
end

--- The timeline's rows: one per ability (spell and caster) either run cast, with each run's times.
--- @param run table  the run shown (the top lanes)
--- @param other table|nil  the run it is compared with (the bottom lanes)
--- @return table rows  { { id, pet, cd (ms), a = { t, ... }, b = { t, ... }, countA, countB }, ... }
function Timeline.Rows(run, other)
    local rows, index = {}, {}
    merge(rows, index, groupsOf(run), "a")
    merge(rows, index, groupsOf(other), "b")
    table.sort(rows, before)
    return rows
end

local function lengthOf(run)
    local race = type(run) == "table" and run.race
    local n = type(race) == "table" and race.length
    return type(n) == "number" and n > 0 and n or 0
end

--- The axis's span in seconds: the longer race of the two (a picked run may be on another board).
function Timeline.Span(run, other)
    return math.max(1, lengthOf(run), lengthOf(other))
end

-- The round steps a zoomed axis labels in, in seconds.
local STEPS = { 1, 2, 5, 10, 15, 30, 60, 120, 300, 600 }

-- The smallest round step of `raw` seconds or more (a multiple of ten minutes past the list).
local function roundStep(raw)
    for _, step in ipairs(STEPS) do
        if step >= raw then return step end
    end
    return math.ceil(raw / 600) * 600
end

--- The axis's ticks: 0, the quarters and the end; zoomed in (`zoom` > 1), every round step that
--- leaves about a quarter of the lanes' width between labels, then the end (a step within half a step
--- of the end gives way to it).
function Timeline.Ticks(span, zoom)
    if not zoom or zoom <= 1 then return { 0, span / 4, span / 2, span * 3 / 4, span } end
    local step, out = roundStep(span / (4 * zoom)), {}
    local t = 0
    while t < span - step / 2 do
        out[#out + 1] = t
        t = t + step
    end
    out[#out + 1] = span
    return out
end

--- The zoom at step `i` of ZOOMS (clamped to the steps).
function Timeline.ZoomAt(i)
    local n = #Timeline.ZOOMS
    return Timeline.ZOOMS[math.max(1, math.min(n, tonumber(i) or 1))]
end

--- The view's left edge, a fraction of the zoomed axis, clamped so the view stays on the axis; a
--- value a rounding error short of either end (the thumb dragged there) snaps onto it.
function Timeline.ClampPos(pos, zoom)
    local hi = 1 - 1 / zoom
    pos = math.max(0, math.min(hi, tonumber(pos) or 0))
    if pos > hi - 1e-9 then return hi end
    if pos < 1e-9 then return 0 end
    return pos
end

--- The left edge after zooming from `from` to `to` about the point `at` of the way across the view
--- (0 its left edge, 1 its right; the middle without): that moment stays where it was, where it can.
function Timeline.Rezoom(pos, from, to, at)
    at = tonumber(at) or 0.5
    return Timeline.ClampPos((tonumber(pos) or 0) + at / from - at / to, to)
end

--- How far across a view `laneW` wide, its left edge at `laneLeft`, the point `x` is (0 to 1), or nil
--- off the view (a Ctrl+wheel over the names, the counts or past them zooms about the middle).
function Timeline.CursorAt(x, laneLeft, laneW)
    if type(x) ~= "number" or type(laneLeft) ~= "number" or type(laneW) ~= "number" or laneW <= 0 then return nil end
    local at = (x - laneLeft) / laneW
    if at < 0 or at > 1 then return nil end
    return at
end

--- The left edge's range at `zoom` (the scrollbar's values, 0 to this): 0 at 1x.
function Timeline.PosRange(zoom)
    return math.max(0, 1 - 1 / (tonumber(zoom) or 1))
end

--- The band the scrollbar takes at the window's bottom at `zoom`: its height and gap zoomed in, else 0.
function Timeline.BarBand(zoom)
    return (tonumber(zoom) or 1) > 1 and Timeline.SCROLL_H + Timeline.SCROLL_GAP or 0
end

--- The zoom level's color at step `i` of ZOOMS: LEVEL_REST at 1x; above it GOLD at the first step to
--- HOT at the last, in even steps between.
--- @return table  { r, g, b }
function Timeline.ZoomColor(i)
    local n = #Timeline.ZOOMS
    i = math.max(1, math.min(n, tonumber(i) or 1))
    if i <= 1 then return Timeline.LEVEL_REST end
    local f, from, to = n > 2 and (i - 2) / (n - 2) or 1, Style.GOLD, Timeline.HOT
    return { from[1] + (to[1] - from[1]) * f, from[2] + (to[2] - from[2]) * f, from[3] + (to[3] - from[3]) * f }
end

--- A cast tick's middle x in a lane `width` wide: INSET + clamp(t, 0, span) / span x (width - 2 x INSET).
--- A pre-pull cast sits at 0:00, one after the buzzer at the end. nil without a time or a span.
function Timeline.MarkX(t, span, width)
    if type(t) ~= "number" or type(span) ~= "number" or span <= 0 then return nil end
    local inset = Timeline.INSET
    return inset + math.max(0, math.min(span, t)) / span * math.max(0, width - 2 * inset)
end

--- The lanes' geometry in a window `width` wide: the content's width, the lanes' left (past the name
--- cell and the gap) and their width (all but the count cell after them, COUNT_GAP past their end).
--- @return number cw, number laneX, number laneW
function Timeline.LaneGeometry(width)
    local cw = math.max(100, (tonumber(width) or Timeline.MIN_WIDTH) - 2 * Timeline.PAD)
    local laneX = Timeline.NAME_W + Timeline.GAP
    return cw, laneX, math.max(40, cw - laneX - Timeline.COUNT_GAP - Timeline.COUNT_W)
end

-- The row whose last icon sits furthest left: the one an icon past the cap overlaps.
local function soonest(last)
    local best = 1
    for r = 2, #last do
        if last[r] < last[best] then best = r end
    end
    return best
end

--- The rows the icons at `xs` (their middles, left to right) stack onto: each on the first row whose
--- last icon is `pitch` or more to its left; past `cap` rows, on the row that frees first, overlapping.
--- @return table rows  { [n] = row (1 = the strip's base row) }
--- @return number count  the rows used (0 for no icons)
--- @return table over  { [n] = true } for each icon placed past the cap
function Timeline.Stack(xs, pitch, cap)
    local rows, last, over = {}, {}, {}
    for n, x in ipairs(xs) do
        local r = 1
        while last[r] and x - last[r] < pitch do r = r + 1 end
        if r > cap then r, over[n] = soonest(last), true end
        rows[n], last[r] = r, x
    end
    return rows, #last, over
end

--- A strip's height for `rows` rows of icons: one row at the least (an empty strip holds its note).
function Timeline.StripHeight(rows)
    return math.max(1, rows or 0) * Timeline.CAST_STEP
end

--- Where each part of the scrolling content starts, in px down from its top, for strips of `rowsA`
--- and `rowsB` rows: the *Casts* heading at 0, this run's strip CASTS_PAD under it, the compared run's,
--- their axis CASTS_PAD under it, the *By ability* heading SECTION_GAP under that and the first pair
--- of lanes under the heading.
--- @return table  { stripA, heightA, stripB, heightB, castsAxis, lanesHead, lanes }
function Timeline.Sections(rowsA, rowsB)
    local s = { stripA = Style.SECTION_H + Timeline.CASTS_PAD, heightA = Timeline.StripHeight(rowsA),
                heightB = Timeline.StripHeight(rowsB) }
    s.stripB = s.stripA + s.heightA + Timeline.STRIP_GAP
    s.castsAxis = s.stripB + s.heightB + Timeline.CASTS_PAD
    s.lanesHead = s.castsAxis + Timeline.CASTS_AXIS_H + Style.SECTION_GAP
    s.lanes = s.lanesHead + Style.SECTION_H
    return s
end

--- A strip's vertical middle, px down from the content's top (its label's line): `side` "a" this
--- run's, "b" the compared run's, in `s` (Timeline.Sections), whatever rows it grew to.
function Timeline.StripMid(s, side)
    if side == "a" then return s.stripA + s.heightA / 2 end
    return s.stripB + s.heightB / 2
end

--- What follows the client's spell tooltip on a cast icon: its time on the race clock ("(pet)" after a
--- pet's), which run it is, and, for an icon past the row cap, that it overlaps others. Nil for anything
--- but a cast.
--- @param cast table  { t, id, pet }
--- @param label string|nil  the run's label (the legend's)
--- @param over boolean|nil  placed past MAX_STACK rows
--- @return table|nil
function Timeline.IconLines(cast, label, over)
    if type(cast) ~= "table" or type(cast.id) ~= "number" then return nil end
    local at = L["Cast at %s"]:format(NS.ResultsUsage.Clock(tonumber(cast.t) or 0))
    local lines = { cast.pet and L["%s (pet)"]:format(at) or at }
    if label then lines[#lines + 1] = { label, Style.Rgb("dr.dim") } end
    if over then
        lines[#lines + 1] = { L["Too many casts here for %d rows: this icon overlaps others."]:format(Timeline.MAX_STACK), Style.Rgb("gtip.title") }
    end
    return lines
end

--- The `?` control's tooltip: its title, then the timeline's mouse controls (bullets, from two lines on).
function Timeline.HelpLines()
    return { L["Mouse controls"], L["Mouse wheel: scroll up and down"],
             L["Shift+mouse wheel: scroll left and right (zoomed in)"], L["Ctrl+mouse wheel: zoom in and out"] }
end

--- A run's casts in time order (a copy), or an empty list when it has none.
function Timeline.CastsOf(run)
    local list = NS.Casts.Of(run) or {}
    local out = {}
    for n, c in ipairs(list) do out[n] = c end
    table.sort(out, function(a, b) return (tonumber(a.t) or 0) < (tonumber(b.t) or 0) end)
    return out
end

--- A row's cooldown: m:ss when 29 s or more, else nothing.
function Timeline.CooldownText(row)
    if not (row and NS.Casts.IsLong(row.cd)) then return "" end
    return NS.Format.Length(row.cd / 1000)
end

--- The line under a row's name in its name cell: "1:30 cooldown" when 29 s or more, else nothing.
function Timeline.CooldownLine(row)
    local cd = Timeline.CooldownText(row)
    return cd ~= "" and L["%s cooldown"]:format(cd) or ""
end

--- A row's name: the spell's, "(pet)" after a pet's.
function Timeline.Name(row)
    local name = NS.HudBreakdown.SpellName(row.id)
    return row.pet and L["%s (pet)"]:format(name) or name
end

--- The compared run's label: what it is and its date ("Best · 25 Oct 01:58"), or nil with none.
function Timeline.OtherLabel(other, kind)
    if not other then return nil end
    local Compare = NS.ResultsCompare
    return Compare.OtherLabel(kind) .. SEP .. Compare.ShortLabel(other)
end

--- The legend bar's texts: this run's, the compared run's, and the note under the bar (nil with
--- nothing to say): no compared run, or one with no casts.
--- @return string this, string other, string|nil note
function Timeline.Legend(run, other, kind)
    local this = L["This run"] .. SEP .. NS.ResultsCompare.ShortLabel(run)
    local label = Timeline.OtherLabel(other, kind)
    if not label then return this, L["No run to compare with"], L["No run to compare with: the blue lanes stay empty."] end
    if not Timeline.Has(other) then
        return this, label, L["%s has no casts recorded: the blue lanes stay empty."]:format(NS.ResultsCompare.OtherLabel(kind))
    end
    return this, label, nil
end
