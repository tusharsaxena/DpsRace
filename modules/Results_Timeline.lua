local _, NS = ...
-- modules/Results_Timeline.lua — the ability timeline (#14): a pop-out window from the Results detail's
-- *Timeline* button that sets every ability the run cast on one time axis, beside the run the detail
-- compares it with (the owner's pick of the mock, version 2, 2026-10-26).
--
-- THE LAYOUT. A legend bar (this run's date in gold, the compared run's in blue and what it is: the
-- best, the runner-up or the picked run), then two sections under their own headings in the Results
-- detail's heading style (FONT.SECTION). *Casts* (P11, the owner's call, 2026-10-26): two icon strips on
-- the lanes' time axis, this run's above the compared run's, every cast (the pet's too) its ability's
-- icon at its time; icons too close to sit apart stack onto extra rows, this run's upward and the
-- compared run's downward (away from the line between them), and each strip grows to the most rows it
-- needs (every icon shown; past MAX_STACK rows the rest overlap the row that frees first and say so in
-- their tooltip). An icon's tooltip is the client's spell tooltip, then the cast's time and its run.
-- *By ability*: one pair of lanes per ability: its name cell (icon,
-- name, "(pet)" for a pet's, and under the name its cooldown when 29 s or more) beside two lanes, the top
-- one this run's casts (thin gold ticks, the lane's full height), the bottom one the compared run's
-- (blue), each lane's cast count just past its right end. Nothing sits between the name cell and the lanes but
-- the gap (the owner's call, 2026-10-26: a cooldown beside the lanes read as part of them). Abilities
-- with a cooldown of 29 s or more come first, longest first; the rest follow by count. The time axis (0,
-- the quarters, the end) is pinned under both sections, which scroll together (the mouse wheel), and
-- drawn again under the compared run's strip (P12). A tick's tooltip names the spell and its time; a
-- name's shows the client's spell tooltip and both counts.
--
-- ZOOM (P12, the owner's call, 2026-10-27). Three controls at the right of the *Casts* heading line
-- (zoom out, zoom in, reset) step the time axis through ZOOMS for the strips and the lanes together:
-- the time area is laid out ZOOMS[i] times the lanes' width and shown through clipping scroll frames
-- (one over the strips and their axis, one over the lanes, one over the pinned axis) that pan
-- together, the name cells and the counts staying put. Shift+mouse wheel pans; a thin bar under the
-- pinned axis shows where the view is. The view is kept as the fraction of the axis at its left edge
-- (`pos`), so a resize keeps the same moment at the left; a zoom keeps the view's middle. Zoom and pan
-- go back to 1x on another run or compare target.
--
-- WHICH RUNS. The detail's: its run, and its compare target resolved whether or not the compare is on
-- (CompareTarget(true)). Every detail draw and every compare change (a pick, Clear Pick, the toggle)
-- redraws the window while it is open. With no compared run, or one with no casts, the blue lanes
-- stay empty under a note; a run with no casts (the button is disabled for one, but the detail may
-- move to one while the window is open) shows a message in place of the lanes.
--
-- THE WINDOW is the Results window's kind (standalone-windows): a plain frame skinned through
-- NS.ApplySkin, closed through NS.MakeCloseButton, in UISpecialFrames (Escape closes it), clamped,
-- movable by its title bar and resizable, its position and size in db.profile.windows.timeline;
-- Master scale acts on it. It closes with the Results window. Built on first open.
--
-- A MODAL (P13, the owner's call, 2026-10-27: a Results tooltip showed through it). Opened from the
-- Results window, it sits one strata above it (LAYERS.STRATA.MODAL, frame-layering-§1), toplevel, and
-- re-raises a shown StaticPopup when it opens (frame-layering-§4). While it is open the Results
-- window wears its dim cover (Results.SetCovered), which takes that window's mouse; Escape closes this
-- window first (the Results window's onHide shows itself again while covered), and the cover goes
-- when this one closes. Its skin is SKIN: the shared one made fully opaque, so nothing of the Results
-- window shows through.
--
-- PLAIN DATA ONLY: the stored run.casts records (plain numbers). Every position is computed from the
-- constants here and the window's stored size, never read back off a frame; Rows, Span, Ticks, MarkX,
-- LaneGeometry, Stack, Sections, ClampPos, Rezoom, CooldownText, CooldownLine, IconLines and Legend are pure.

local Timeline = { wanted = false }
NS.ResultsTimeline = Timeline

local L = NS.L
local Style = NS.Style
local FONT = Style.FONT
local Tbl = NS.ResultsTable
local C = Tbl.COLORS

local DW = NS.defaults.profile.windows.timeline
Timeline.FRAME_NAME = "DpsRaceTimeline"
-- 980 by 560 (860 before P12: the owner asked for more room for the strips by default).
Timeline.WIDTH, Timeline.HEIGHT = DW.width, DW.height
-- 640 (was 540, P11): at 540 a 1:00 race gave the cast icons about 5 px a second, two rows for every
-- global cooldown's worth of casts; 640 gives them 7.
Timeline.MIN_WIDTH = 640
Timeline.MIN_HEIGHT = 240

-- The geometry: a 150 px name cell (the icon and the name on the top lane's line, the cooldown under
-- it), 10 px, the lanes, then each lane's count 10 px past its right end (P11: flush with the lane, not
-- out at the window's edge; 5 px until P12 read as touching it) in a 26 px cell (30 until P12: the
-- wider gap came out of it, so a 1:00 race keeps 7 px a second at the minimum width; three digits
-- still fit); each lane 16 px, 2 px between a pair's lanes and 10 px between pairs.
Timeline.PAD = 12
Timeline.NAME_W = 150
Timeline.COUNT_W = 26
Timeline.COUNT_GAP = 10
Timeline.GAP = 10
Timeline.LANE_H = 16
Timeline.LANE_GAP = 2
Timeline.PAIR_GAP = 10
Timeline.PAIR_H = 2 * Timeline.LANE_H + Timeline.LANE_GAP + Timeline.PAIR_GAP
Timeline.ICON = 16
Timeline.MARK_W = 2         -- a cast's tick, the lane's full height
Timeline.MARK_HIT = 8       -- its hover frame's width (the lane's height)
Timeline.INSET = 1          -- half a tick: one at 0:00 or at the end stays inside its lane
Timeline.LEGEND_H = 26
Timeline.NOTE_H = 16
Timeline.AXIS_H = 20
-- The *Casts* strips: 14 px icons, closer than 15 px apart they stack, on an 18 px row pitch (P12: 15
-- read as cramped), 4 px above this run's strip, 8 px between the two strips and 4 px over their own
-- axis (CASTS_AXIS_H), at most MAX_STACK rows a strip. The strips' clip reaches CLIP_PAD past the lanes
-- at each end, so an icon at 0:00 or at the end shows whole.
Timeline.CAST_ICON = 14
Timeline.CAST_PITCH = 15
Timeline.CAST_STEP = 18
Timeline.CASTS_PAD = 4
Timeline.STRIP_GAP = 8
Timeline.CASTS_AXIS_H = 16
Timeline.MAX_STACK = 12
Timeline.CLIP_PAD = 8
-- The zoom steps (the time axis's width over the lanes'), and a Shift+wheel notch: a quarter of the view.
Timeline.ZOOMS = { 1, 1.5, 2, 3, 4, 6, 8 }
Timeline.PAN = 0.25
Timeline.BAR_H = 3          -- the pan bar under the pinned axis

-- The two runs' colors: this run gold, the compared run blue (the mock's).
Timeline.THIS = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3] }
Timeline.OTHER = { 0.35, 0.66, 1.0 }
local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"   -- a white disc, tinted (the legend's swatches)
local WHITE = "Interface\\Buttons\\WHITE8x8"                      -- a cast's tick, tinted
local TRACK = { 1, 1, 1, 0.06 }
local GRID = { 1, 1, 1, 0.08 }
local HEADER_H = Style.TITLE_BAR_H
local SEP = " \194\183 "

-- The shared skin made opaque: its fill at alpha 1, and its inner border and divider blended over that
-- fill to alpha 1, so they read as they do on the other windows and nothing behind shows through.
local function opaque(c, under)
    if type(c) ~= "table" then return c end
    local a = c[4] or 1
    return { c[1] * a + under[1] * (1 - a), c[2] * a + under[2] * (1 - a), c[3] * a + under[3] * (1 - a), 1 }
end
Timeline.SKIN = {}
for k, v in pairs(NS.SKIN or {}) do Timeline.SKIN[k] = v end
if type(Timeline.SKIN.bg) == "table" then
    local bg = Timeline.SKIN.bg
    Timeline.SKIN.bg = { bg[1], bg[2], bg[3], 1 }
    Timeline.SKIN.innerBorder = opaque(Timeline.SKIN.innerBorder, bg)
    Timeline.SKIN.divider = opaque(Timeline.SKIN.divider, bg)
end

local ui        -- the built window
local pane      -- the detail pane the window follows
local hiding = false

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Timeline", fmt, ...) end
end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────────

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

--- The view's left edge, a fraction of the zoomed axis, clamped so the view stays on the axis.
function Timeline.ClampPos(pos, zoom)
    return math.max(0, math.min(1 - 1 / zoom, tonumber(pos) or 0))
end

--- The left edge after zooming from `from` to `to` about the view's middle.
function Timeline.Rezoom(pos, from, to)
    return Timeline.ClampPos((tonumber(pos) or 0) + 0.5 / from - 0.5 / to, to)
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
    if label then lines[#lines + 1] = { label, 0.62, 0.62, 0.68 } end
    if over then
        lines[#lines + 1] = { L["Too many casts here for %d rows: this icon overlaps others."]:format(Timeline.MAX_STACK), 1, 0.82, 0 }
    end
    return lines
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

-- ── stored geometry ─────────────────────────────────────────────────────────────────────────────

local function store()
    local p = NS.db and NS.db.profile
    if not p then return nil end
    p.windows = p.windows or {}
    p.windows.timeline = p.windows.timeline or {}
    return p.windows.timeline
end

local function savePosition()
    local w = store()
    if not (w and ui) then return end
    local point, _, relativePoint, x, y = ui.frame:GetPoint(1)
    if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
    w.point, w.relativePoint = point, type(relativePoint) == "string" and relativePoint or point
    w.x, w.y = math.floor(x + 0.5), math.floor(y + 0.5)
end

local function saveSize(width, height)
    local w = store()
    if not w then return end
    if type(width) == "number" then w.width = math.floor(width + 0.5) end
    if type(height) == "number" then w.height = math.floor(height + 0.5) end
end

local function storedSize()
    local w = store() or {}
    return math.max(Timeline.MIN_WIDTH, tonumber(w.width) or Timeline.WIDTH),
        math.max(Timeline.MIN_HEIGHT, tonumber(w.height) or Timeline.HEIGHT)
end

-- ── the window ──────────────────────────────────────────────────────────────────────────────────

local layout, resize

local function disc(parent, color, size, layer)
    local t = parent:CreateTexture(nil, layer or "OVERLAY")
    t:SetTexture(DISC)
    t:SetVertexColor(color[1], color[2], color[3], 0.95)
    t:SetSize(size, size)
    return t
end

local function buildChrome(f)
    f.title = Style.Text(f, FONT.TITLE, C.gold, "CENTER")
    f.title:SetPoint("CENTER", f, "TOP", 0, -HEADER_H / 2)
    f.title:SetText(L["Ability timeline"])
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(0.24, 0.24, 0.27, 0.85)
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -HEADER_H)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -HEADER_H)
    ui.controls = Style.NewStrip()
    ui.close = Style.AddToStrip(ui.controls, NS.MakeCloseButton(f, function() Timeline.Hide() end))
    if ui.close then ui.close:SetPoint("RIGHT", f, "TOPRIGHT", -6, -HEADER_H / 2) end
    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    drag:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -28, -HEADER_H)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() f:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        savePosition()
    end)
    ui.drag = drag
end

-- The legend bar: a gold disc and this run's label, a blue one and the compared run's, then the hint;
-- each anchored after the one before it. The note sits under the bar.
local function buildLegend(f)
    local y = -HEADER_H - Timeline.LEGEND_H / 2
    ui.swatchA = disc(f, Timeline.THIS, 10)
    ui.swatchA:SetPoint("LEFT", f, "TOPLEFT", Timeline.PAD, y)
    ui.legendA = Style.Text(f, FONT.TEXT, C.text)
    ui.legendA:SetPoint("LEFT", ui.swatchA, "RIGHT", 6, 0)
    ui.swatchB = disc(f, Timeline.OTHER, 10)
    ui.swatchB:SetPoint("LEFT", ui.legendA, "RIGHT", 16, 0)
    ui.legendB = Style.Text(f, FONT.TEXT, C.text)
    ui.legendB:SetPoint("LEFT", ui.swatchB, "RIGHT", 6, 0)
    ui.hint = Style.Text(f, FONT.CAPTION)
    ui.hint:SetPoint("LEFT", ui.legendB, "RIGHT", 16, 0)
    ui.hint:SetText(L["Right: casts in each lane"])
    ui.note = Style.Text(f, FONT.TEXT, C.amber)
    ui.note:SetPoint("TOPLEFT", f, "TOPLEFT", Timeline.PAD, -HEADER_H - Timeline.LEGEND_H)
    ui.legendLine = f:CreateTexture(nil, "ARTWORK")
    ui.legendLine:SetHeight(1)
    ui.legendLine:SetColorTexture(1, 1, 1, 0.08)
end

-- One *Casts* strip: its track (the lanes' faint fill), its run's name in the name cell in its color,
-- and the dim note it shows with no casts.
local function buildStrip(color)
    local s = { track = ui.content:CreateTexture(nil, "BACKGROUND") }
    s.track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
    s.label = Style.Text(ui.content, FONT.TEXT, color)
    s.label:SetWidth(Timeline.NAME_W)
    s.note = Style.Text(ui.content, FONT.CAPTION)
    return s
end

-- A clipping scroll frame on `parent` and the layer it shows (its scroll child): the layer is the
-- zoomed time area, and panning scrolls it sideways under the clip.
local function clipLayer(parent)
    local clip = CreateFrame("ScrollFrame", nil, parent)
    local layer = CreateFrame("Frame", nil, clip)
    clip:SetScrollChild(layer)
    return clip, layer
end

-- The zoom controls at the right end of the *Casts* heading line, right to left: reset, zoom out,
-- zoom in; the zoom level left of them. Over the strips' clip (a higher frame level).
local function buildZoom()
    ui.zoomStrip = Style.NewStrip()
    local level = ui.content:GetFrameLevel() + 10
    local function control(name, glyph, tip, onClick)
        local b = Style.AddToStrip(ui.zoomStrip, Style.ControlButton(ui.content, name, glyph, tip, onClick))
        b:SetFrameLevel(level)
        return b
    end
    ui.zoomReset = control("reset", "R", L["Reset zoom"], function() Timeline.ResetZoom() end)
    ui.zoomReset:SetPoint("TOPRIGHT", ui.content, "TOPRIGHT", 0, 0)
    ui.zoomOut = control(nil, "-", L["Zoom out"], function() Timeline.ZoomBy(-1) end)
    ui.zoomOut:SetPoint("RIGHT", ui.zoomReset, "LEFT", -2, 0)
    ui.zoomIn = control(nil, "+", L["Zoom in (Shift+mouse wheel scrolls along the time axis)"],
        function() Timeline.ZoomBy(1) end)
    ui.zoomIn:SetPoint("RIGHT", ui.zoomOut, "LEFT", -2, 0)
    ui.zoomText = Style.Text(ui.content, FONT.CAPTION, nil, "RIGHT")
    ui.zoomText:SetPoint("RIGHT", ui.zoomIn, "LEFT", -6, 0)
end

-- The pinned axis's clip on the window and the pan bar under it (its track and the view's thumb).
local function buildAxis(f)
    ui.axisClip, ui.axisLayer = clipLayer(f)
    ui.barTrack = f:CreateTexture(nil, "ARTWORK")
    ui.barTrack:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], 0.10)
    ui.barThumb = f:CreateTexture(nil, "OVERLAY")
    ui.barThumb:SetColorTexture(1, 1, 1, 0.35)
    ui.axis, ui.castsAxis, ui.grid = {}, {}, {}
    ui.axisPool, ui.castsAxisPool = NS.Pool.New(), NS.Pool.New()
    ui.gridPool, ui.laneGridPool = NS.Pool.New(), NS.Pool.New()
end

local function buildBody(f)
    ui.scroll = CreateFrame("ScrollFrame", nil, f)
    ui.content = CreateFrame("Frame", nil, ui.scroll)
    ui.scroll:SetScrollChild(ui.content)
    ui.scroll:EnableMouseWheel(true)
    ui.scroll:SetScript("OnMouseWheel", function(_, delta)
        if IsShiftKeyDown and IsShiftKeyDown() then Timeline.Pan(delta) else Timeline.Scroll(delta) end
    end)
    -- The time area's two clips over the content (a child frame draws over its parent's textures):
    -- the strips' (the icons, their axis) and the lanes' (the ticks); the grid lines under both.
    local level = ui.content:GetFrameLevel() + 5
    ui.castsClip, ui.castsLayer = clipLayer(ui.content)
    ui.lanesClip, ui.marks = clipLayer(ui.content)
    ui.castsClip:SetFrameLevel(level)
    ui.lanesClip:SetFrameLevel(level)
    ui.pairs = NS.Pool.New()
    ui.markPool = NS.Pool.New()
    ui.hitPool = NS.Pool.New()
    ui.iconPool = NS.Pool.New()
    ui.castsHead = Style.Text(ui.content, FONT.SECTION)
    ui.castsHead:SetText(L["Casts"])
    ui.lanesHead = Style.Text(ui.content, FONT.SECTION)
    ui.lanesHead:SetText(L["By ability"])
    ui.strips = { a = buildStrip(Timeline.THIS), b = buildStrip(Timeline.OTHER) }
    ui.empty = Style.Text(f, FONT.EMPTY, nil, "CENTER")
    ui.empty:SetPoint("CENTER", f, "CENTER", 0, 0)
    buildZoom()
    buildAxis(f)
end

-- A close-stack close, a frame later: the Results window's cover goes unless the timeline is open
-- again, and a talent tree that close made way for sends the Results window aside (its own rule).
local function settle()
    if Timeline.IsShown() then return end
    NS.Results.SetCovered(false)
    NS.Results.StepAsideForTree()
end

local function onHide()
    Tbl.HideTip()
    if hiding or (ui and ui.frame:IsShown()) then return end
    -- Escape (UISpecialFrames): the player closed it. The cover stays until the close stack is done,
    -- so the Results window, hidden by the same Escape, still sees it and shows again.
    Timeline.wanted = false
    if C_Timer and C_Timer.After then C_Timer.After(0, settle) else settle() end
end

-- Every size change, the grip's or not: the tracked size the layouts read, never under the minimums.
local function trackSize(width, height)
    if type(width) == "number" then ui.width = math.max(Timeline.MIN_WIDTH, width) end
    if type(height) == "number" then ui.height = math.max(Timeline.MIN_HEIGHT, height) end
end

local function applyPlacement()
    local f, w = ui.frame, store() or {}
    ui.width, ui.height = storedSize()
    f:ClearAllPoints()
    f:SetPoint(w.point or "CENTER", UIParent, w.relativePoint or "CENTER", w.x or 0, w.y or 0)
    f:SetSize(ui.width, ui.height)
end

local function ensureWindow()
    if ui then return ui end
    local f = CreateFrame("Frame", Timeline.FRAME_NAME, UIParent, "BackdropTemplate")
    ui = { frame = f, rows = {}, castsA = {}, castsB = {}, offset = 0, zoomI = 1, pos = 0 }
    f:Hide()
    f:SetFrameStrata(NS.Constants.LAYERS.STRATA.MODAL)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetToplevel(true)
    buildChrome(f)
    buildLegend(f)
    buildBody(f)
    NS.ApplySkin(f, Timeline.SKIN)
    f:SetScript("OnHide", onHide)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, Timeline.FRAME_NAME) end
    -- Smooth resizing (modules/Sizing.lua): while the grip is dragged only `resize` runs, once a frame;
    -- the full `layout` (every pair and tick re-pooled) runs once on release.
    NS.Sizing.MakeResizable(f, {
        minWidth = Timeline.MIN_WIDTH, minHeight = Timeline.MIN_HEIGHT,
        size = trackSize, layout = function() resize() end, redraw = function() layout() end, done = saveSize,
    })
    applyPlacement()
    debug("window built")
    return ui
end

-- ── one pair of lanes ───────────────────────────────────────────────────────────────────────────

local function track(parent)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
    t:SetHeight(Timeline.LANE_H)
    return t
end

-- The name's hover: the client's spell tooltip beside the window, then both runs' counts.
local function nameTip(pair)
    local row = pair.row
    if not (row and ui) then return end
    local lines = NS.ResultsTips.TimelineRow(row, Timeline.OtherLabel(ui.other, ui.kind))
    Tbl.SpellTip(ui.frame, pair, row.id, lines)
end

local function newPair()
    local pair = CreateFrame("Frame", nil, ui.content)
    pair:SetHeight(2 * Timeline.LANE_H + Timeline.LANE_GAP)
    pair.icon = pair:CreateTexture(nil, "ARTWORK")
    pair.icon:SetSize(Timeline.ICON, Timeline.ICON)
    pair.icon:SetPoint("LEFT", pair, "TOPLEFT", 0, -Timeline.LANE_H / 2)
    pair.name = Style.Text(pair, FONT.TEXT, C.text)
    pair.name:SetPoint("LEFT", pair.icon, "RIGHT", 6, 0)
    pair.name:SetWidth(Timeline.NAME_W - Timeline.ICON - 6)
    -- The cooldown on the bottom lane's line, under the name.
    pair.cd = Style.Text(pair, FONT.CAPTION, C.dim)
    pair.cd:SetPoint("LEFT", pair, "TOPLEFT", Timeline.ICON + 6, -(1.5 * Timeline.LANE_H + Timeline.LANE_GAP))
    pair.cd:SetWidth(Timeline.NAME_W - Timeline.ICON - 6)
    pair.laneA, pair.laneB = track(pair), track(pair)
    pair.countA = Style.Text(pair, FONT.TEXT, Timeline.THIS)
    pair.countB = Style.Text(pair, FONT.TEXT, Timeline.OTHER)
    pair.hit = CreateFrame("Frame", nil, pair)
    pair.hit:SetPoint("TOPLEFT", pair, "TOPLEFT", 0, 0)
    pair.hit:SetSize(Timeline.NAME_W, 2 * Timeline.LANE_H + Timeline.LANE_GAP)
    pair.hit:EnableMouse(true)
    pair.hit:SetScript("OnEnter", function() nameTip(pair) end)
    pair.hit:SetScript("OnLeave", Tbl.HideTip)
    return pair
end

local function placeLane(pair, lane, count, y, laneX, laneW)
    lane:ClearAllPoints()
    lane:SetPoint("TOPLEFT", pair, "TOPLEFT", laneX, y)
    lane:SetWidth(laneW)
    count:ClearAllPoints()
    count:SetPoint("LEFT", pair, "TOPLEFT", laneX + laneW + Timeline.COUNT_GAP, y - Timeline.LANE_H / 2)
    count:SetWidth(Timeline.COUNT_W)
end

local function fillPair(pair, row, y, g)
    pair.row = row
    pair:ClearAllPoints()
    pair:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 0, y)
    pair:SetWidth(g.cw)
    pair.icon:SetTexture(NS.HudBreakdown.SpellIcon(row.id))
    pair.name:SetText(Timeline.Name(row))
    pair.cd:SetText(Timeline.CooldownLine(row))
    placeLane(pair, pair.laneA, pair.countA, 0, g.laneX, g.laneW)
    placeLane(pair, pair.laneB, pair.countB, -(Timeline.LANE_H + Timeline.LANE_GAP), g.laneX, g.laneW)
    pair.countA:SetText(tostring(row.countA))
    pair.countB:SetText(ui.otherHas and tostring(row.countB) or "")
end

-- ── the cast ticks ──────────────────────────────────────────────────────────────────────────────

local function newHit()
    local h = CreateFrame("Frame", nil, ui.marks)
    h:SetSize(Timeline.MARK_HIT, Timeline.LANE_H)
    h:EnableMouse(true)
    h:SetScript("OnEnter", function(self)
        if self.cast then Tbl.BelowTip(self, Timeline.MarkLines(self.cast, self.label)) end
    end)
    h:SetScript("OnLeave", Tbl.HideTip)
    return h
end

local function newMark()
    local t = ui.marks:CreateTexture(nil, "OVERLAY")
    t:SetTexture(WHITE)
    t:SetWidth(Timeline.MARK_W)
    t:SetHeight(Timeline.LANE_H)
    return t
end

--- A tick's tooltip: the spell and its time (ResultsTips.Cast), then which run it is.
function Timeline.MarkLines(cast, label)
    local lines = NS.ResultsTips.Cast(cast)
    if lines and label then lines[#lines + 1] = { label, 0.62, 0.62, 0.68 } end
    return lines
end

-- A tick drawn now on the lanes' layer: its x and y are content coordinates as if unpanned (the
-- layer starts at the lanes' left, under the first pair).
local function putMark(d, g)
    local x, y = d.x - g.laneX, d.y + ui.sections.lanes
    d.tex:ClearAllPoints()
    d.tex:SetPoint("CENTER", ui.marks, "TOPLEFT", x, y)
    d.hit:ClearAllPoints()
    d.hit:SetPoint("CENTER", ui.marks, "TOPLEFT", x, y)
end

-- One tick at `x` along the lane whose middle is `y` (content coordinates), the lane's full height.
local function placeMark(cast, x, y, color, label, g)
    local m = NS.Pool.Acquire(ui.markPool, newMark)
    m:SetVertexColor(color[1], color[2], color[3], 0.95)
    local h = NS.Pool.Acquire(ui.hitPool, newHit)
    h.cast, h.label = cast, label
    local d = { tex = m, hit = h, cast = cast, x = x, y = y, lane = color == Timeline.THIS and "a" or "b" }
    putMark(d, g)
    ui.drawn[#ui.drawn + 1] = d
end

local function laneMarks(row, side, top, g)
    local times = row[side]
    local color = side == "a" and Timeline.THIS or Timeline.OTHER
    local label = side == "a" and ui.thisLabel or ui.otherLabel
    for _, t in ipairs(times) do
        local x = Timeline.MarkX(t, g.span, g.zoomW)
        if x then placeMark({ t = t, id = row.id, pet = row.pet }, g.laneX + x, top - Timeline.LANE_H / 2, color, label, g) end
    end
end

-- ── the cast icons (*Casts*) ────────────────────────────────────────────────────────────────────

-- An icon's hover: the client's spell tooltip beside the window, then the cast's time and its run.
local function iconTip(self)
    if not (self.cast and ui) then return end
    Tbl.SpellTip(ui.frame, self, self.cast.id, Timeline.IconLines(self.cast, self.label, self.over))
end

-- An icon: a plain frame on the strips' layer (it takes the mouse for its tooltip) holding the art.
local function newIcon()
    local f = CreateFrame("Frame", nil, ui.castsLayer)
    f:SetSize(Timeline.CAST_ICON, Timeline.CAST_ICON)
    f:EnableMouse(true)
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints(f)
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f:SetScript("OnEnter", iconTip)
    f:SetScript("OnLeave", Tbl.HideTip)
    return f
end

-- An icon drawn now on the strips' layer, which starts CLIP_PAD left of the lanes, at this run's strip.
local function putIcon(d, g)
    d.frame:ClearAllPoints()
    d.frame:SetPoint("CENTER", ui.castsLayer, "TOPLEFT", d.x - g.laneX + Timeline.CLIP_PAD, d.y + ui.sections.stripA)
end

-- Each strip's rows at this geometry: the icons' x (content coordinates, on the zoomed axis) and the
-- row each stacks onto.
local function stackOf(list, g)
    local xs = {}
    for n, c in ipairs(list) do xs[n] = g.laneX + (Timeline.MarkX(c.t, g.span, g.zoomW) or 0) end
    local rows, count, over = Timeline.Stack(xs, Timeline.CAST_PITCH, Timeline.MAX_STACK)
    return { xs = xs, rows = rows, count = count, over = over }
end

-- Row `r`'s middle, px down from the content's top: this run's strip stacks up from its bottom row,
-- the compared run's down from its top row (both away from the line between them).
local function rowMid(side, r)
    local s = ui.sections
    if side == "a" then return s.stripA + s.heightA - (r - 0.5) * Timeline.CAST_STEP end
    return s.stripB + (r - 0.5) * Timeline.CAST_STEP
end

-- The strip's track, its run's name level with its base row, and its note when it has no casts.
local function placeStrip(side, g, label, note)
    local st, top = ui.strips[side], ui.sections["strip" .. (side == "a" and "A" or "B")]
    st.track:ClearAllPoints()
    st.track:SetPoint("TOPLEFT", ui.content, "TOPLEFT", g.laneX, -top)
    st.track:SetSize(g.laneW, ui.sections["height" .. (side == "a" and "A" or "B")])
    st.label:ClearAllPoints()
    st.label:SetPoint("LEFT", ui.content, "TOPLEFT", 0, -rowMid(side, 1))
    st.label:SetText(label or "")
    st.note:ClearAllPoints()
    st.note:SetPoint("LEFT", ui.content, "TOPLEFT", g.laneX + 6, -rowMid(side, 1))
    st.note:SetText(note or "")
    st.note:SetShown(note ~= nil)
end

-- One strip's icons, from its stack.
local function stripIcons(side, list, stack, label, g)
    for n, cast in ipairs(list) do
        local f = NS.Pool.Acquire(ui.iconPool, newIcon)
        f.cast, f.label, f.over = cast, label, stack.over[n] == true
        f.tex:SetTexture(NS.HudBreakdown.SpellIcon(cast.id))
        local d = { frame = f, cast = cast, x = stack.xs[n], y = -rowMid(side, stack.rows[n]), row = stack.rows[n], side = side }
        putIcon(d, g)
        ui.icons[#ui.icons + 1] = d
    end
end

-- The note a strip shows with no casts: none for one with casts.
local function stripNote(list, side)
    if #list > 0 then return nil end
    if side == "b" and not ui.other then return L["No run to compare with"] end
    return L["No casts recorded"]
end

-- Both strips and the two headings, re-pooling every icon (a draw, a release).
local function layoutStrips(g)
    NS.Pool.ReleaseAll(ui.iconPool, function(f) f.cast, f.label, f.over = nil, nil, nil end)
    ui.icons = {}
    ui.castsHead:ClearAllPoints()
    ui.castsHead:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 0, 0)
    ui.lanesHead:ClearAllPoints()
    ui.lanesHead:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 0, -ui.sections.lanesHead)
    local otherName = ui.other and NS.ResultsCompare.OtherLabel(ui.kind) or nil
    placeStrip("a", g, L["This run"], stripNote(ui.castsA, "a"))
    placeStrip("b", g, otherName, stripNote(ui.castsB, "b"))
    stripIcons("a", ui.castsA, ui.stackA, ui.thisLabel, g)
    stripIcons("b", ui.castsB, ui.stackB, ui.otherLabel, g)
end

-- While the window is being sized: the strips' tracks to the new lane width and each icon moved along
-- its strip on the row it has (the stacking is redone on release).
local function stretchStrips(g)
    for _, side in ipairs({ "a", "b" }) do ui.strips[side].track:SetWidth(g.laneW) end
    for _, d in ipairs(ui.icons or {}) do
        d.x = g.laneX + (Timeline.MarkX(d.cast.t, g.span, g.zoomW) or 0)
        putIcon(d, g)
    end
end

-- ── the zoom ────────────────────────────────────────────────────────────────────────────────────

local function sized(f, width, height)
    f:SetWidth(width)
    f:SetHeight(height)
end

-- The time area's clips and layers at this geometry: the strips' clip from this run's strip to the
-- bottom of their axis, CLIP_PAD wider than the lanes at each end; the lanes' clip over the pairs; the
-- pinned axis's under the scrolling content. Each layer is the zoomed axis's width.
local function sizeClips(g)
    local s, pad = ui.sections, Timeline.CLIP_PAD
    local castsH = s.castsAxis + Timeline.CASTS_AXIS_H - s.stripA
    local lanesH = math.max(1, #ui.rows * Timeline.PAIR_H - Timeline.PAIR_GAP)
    ui.castsClip:ClearAllPoints()
    ui.castsClip:SetPoint("TOPLEFT", ui.content, "TOPLEFT", g.laneX - pad, -s.stripA)
    sized(ui.castsClip, g.laneW + 2 * pad, castsH)
    sized(ui.castsLayer, g.zoomW + 2 * pad, castsH)
    ui.lanesClip:ClearAllPoints()
    ui.lanesClip:SetPoint("TOPLEFT", ui.content, "TOPLEFT", g.laneX, -s.lanes)
    sized(ui.lanesClip, g.laneW, lanesH)
    sized(ui.marks, g.zoomW, lanesH)
    ui.axisClip:ClearAllPoints()
    ui.axisClip:SetPoint("BOTTOMLEFT", ui.frame, "BOTTOMLEFT", Timeline.PAD + g.laneX, 6)
    sized(ui.axisClip, g.laneW, Timeline.AXIS_H - 4)
    sized(ui.axisLayer, g.zoomW, Timeline.AXIS_H - 4)
end

-- The pan bar under the pinned axis: the lanes' width, the thumb the view's share of it at its place.
-- Shown only zoomed in.
local function placeBar(g, shown)
    local zoomed = shown and g.zoom > 1
    ui.barTrack:SetShown(zoomed)
    ui.barThumb:SetShown(zoomed)
    ui.thumbX, ui.thumbW = Timeline.PAD + g.laneX + ui.pos * g.laneW, g.laneW / g.zoom
    ui.barTrack:ClearAllPoints()
    ui.barTrack:SetPoint("BOTTOMLEFT", ui.frame, "BOTTOMLEFT", Timeline.PAD + g.laneX, 2)
    ui.barTrack:SetSize(g.laneW, Timeline.BAR_H)
    ui.barThumb:ClearAllPoints()
    ui.barThumb:SetPoint("BOTTOMLEFT", ui.frame, "BOTTOMLEFT", ui.thumbX, 2)
    ui.barThumb:SetSize(ui.thumbW, Timeline.BAR_H)
end

-- The view's left edge (`pos`) kept on the axis, and every clip panned to it together.
local function applyPan(g)
    ui.pos = Timeline.ClampPos(ui.pos, g.zoom)
    ui.hoff = ui.pos * g.zoomW
    ui.castsClip:SetHorizontalScroll(ui.hoff)
    ui.lanesClip:SetHorizontalScroll(ui.hoff)
    ui.axisClip:SetHorizontalScroll(ui.hoff)
    placeBar(g, not ui.isEmpty)
end

-- The zoom level beside the controls, and the controls dimmed at the ends of the steps.
local function placeZoom(g)
    ui.zoomText:SetText(L["%sx"]:format(("%g"):format(g.zoom)))
    local i = ui.zoomI or 1
    ui.zoomIn:SetAlpha(i < #Timeline.ZOOMS and 1 or 0.4)
    ui.zoomOut:SetAlpha(i > 1 and 1 or 0.4)
    ui.zoomReset:SetAlpha(i > 1 and 1 or 0.4)
end

-- ── drawing ─────────────────────────────────────────────────────────────────────────────────────

-- The geometry for the window's stored size and the zoom: the content's width, the lanes' left and
-- width, the zoom and the zoomed axis's width, the span.
local function geometry()
    local cw, laneX, laneW = Timeline.LaneGeometry(ui.width)
    local zoom = Timeline.ZoomAt(ui.zoomI)
    return { cw = cw, laneX = laneX, laneW = laneW, zoom = zoom, zoomW = laneW * zoom, span = ui.span or 1 }
end

local function layoutLegend(g)
    local shown = ui.run ~= nil
    for _, key in ipairs({ "swatchA", "legendA", "swatchB", "legendB", "hint" }) do ui[key]:SetShown(shown) end
    ui.note:SetShown(shown and ui.noteText ~= nil)
    ui.note:SetWidth(g.cw)
    local top = HEADER_H + Timeline.LEGEND_H + ((shown and ui.noteText) and Timeline.NOTE_H or 0)
    ui.legendLine:ClearAllPoints()
    ui.legendLine:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 1, -top)
    ui.legendLine:SetPoint("TOPRIGHT", ui.frame, "TOPRIGHT", -1, -top)
    return top + 1
end

local function newLine(layer)
    return function()
        local t = layer:CreateTexture(nil, "BACKGROUND")
        t:SetColorTexture(GRID[1], GRID[2], GRID[3], GRID[4])
        t:SetWidth(1)
        return t
    end
end

local function newLabel(layer)
    return function() return Style.Text(layer, FONT.CAPTION) end
end

-- Both axes' labels and both layers' grid lines (at each tick but the first and the last), one per
-- tick at this zoom, re-pooled (a draw, a release, a zoom).
local function buildAxes(g)
    for _, pool in ipairs({ ui.axisPool, ui.castsAxisPool, ui.gridPool, ui.laneGridPool }) do NS.Pool.ReleaseAll(pool) end
    ui.ticks = Timeline.Ticks(g.span, g.zoom)
    ui.axis, ui.castsAxis, ui.grid = {}, {}, {}
    for i, t in ipairs(ui.ticks) do
        local text = NS.Format.Length(t)
        ui.axis[i] = NS.Pool.Acquire(ui.axisPool, newLabel(ui.axisLayer))
        ui.axis[i]:SetText(text)
        ui.castsAxis[i] = NS.Pool.Acquire(ui.castsAxisPool, newLabel(ui.castsLayer))
        ui.castsAxis[i]:SetText(text)
        if i > 1 and i < #ui.ticks then
            ui.grid[#ui.grid + 1] = { t = t, casts = NS.Pool.Acquire(ui.gridPool, newLine(ui.castsLayer)),
                                      lanes = NS.Pool.Acquire(ui.laneGridPool, newLine(ui.marks)) }
        end
    end
end

-- The label at tick `i` of `n`: the first left-aligned on 0:00, the last right-aligned on the end.
local function labelPoint(i, n, side)
    local h = i == 1 and "LEFT" or (i == n and "RIGHT" or "")
    return side .. h, h == "" and "CENTER" or h
end

local function placeLabel(fs, point, justify, layer, x, y)
    fs:SetJustifyH(justify)
    fs:ClearAllPoints()
    fs:SetPoint(point, layer, "TOPLEFT", x, y)
end

-- Both axes' labels and the grid lines at this geometry (the pinned axis's on its own layer, the
-- strips' under the compared run's strip on theirs). Nothing re-pooled: a resize runs it every frame.
local function placeAxes(g, shown)
    ui.axisClip:SetShown(shown)
    local s, n, pad = ui.sections, #ui.ticks, Timeline.CLIP_PAD
    local axisY, stripsH = -(Timeline.AXIS_H - 6), s.stripB + s.heightB - s.stripA
    for i, t in ipairs(ui.ticks) do
        local x = Timeline.MarkX(t, g.span, g.zoomW)
        local point, justify = labelPoint(i, n, "BOTTOM")
        placeLabel(ui.axis[i], point, justify, ui.axisLayer, x, axisY)
        point = labelPoint(i, n, "TOP")
        placeLabel(ui.castsAxis[i], point, justify, ui.castsLayer, x + pad, -(s.castsAxis - s.stripA))
    end
    for _, line in ipairs(ui.grid) do
        local x = Timeline.MarkX(line.t, g.span, g.zoomW)
        line.casts:ClearAllPoints()
        line.casts:SetPoint("TOPLEFT", ui.castsLayer, "TOPLEFT", x + pad, 0)
        line.casts:SetHeight(stripsH)
        line.lanes:ClearAllPoints()
        line.lanes:SetPoint("TOPLEFT", ui.marks, "TOPLEFT", x, 0)
        line.lanes:SetPoint("BOTTOMLEFT", ui.marks, "BOTTOMLEFT", x, 0)
    end
end

local function layoutRows(g)
    NS.Pool.ReleaseAll(ui.pairs, function(pair) pair.row = nil end)
    NS.Pool.ReleaseAll(ui.markPool)
    NS.Pool.ReleaseAll(ui.hitPool, function(h) h.cast, h.label = nil, nil end)
    ui.drawn = {}
    for i, row in ipairs(ui.rows) do
        local y = -ui.sections.lanes - (i - 1) * Timeline.PAIR_H
        fillPair(NS.Pool.Acquire(ui.pairs, newPair), row, y, g)
        laneMarks(row, "a", y, g)
        laneMarks(row, "b", y - Timeline.LANE_H - Timeline.LANE_GAP, g)
    end
end

-- While the window is being sized: the pairs drawn now to the new lane width and each tick drawn now
-- moved along its lane, with nothing re-pooled, refilled or recolored.
local function stretchRows(g)
    for _, pair in ipairs(ui.pairs.active) do
        pair:SetWidth(g.cw)
        placeLane(pair, pair.laneA, pair.countA, 0, g.laneX, g.laneW)
        placeLane(pair, pair.laneB, pair.countB, -(Timeline.LANE_H + Timeline.LANE_GAP), g.laneX, g.laneW)
    end
    for _, d in ipairs(ui.drawn or {}) do
        d.x = g.laneX + (Timeline.MarkX(d.cast.t, g.span, g.zoomW) or 0)
        putMark(d, g)
    end
end

-- The empty message for what is missing, or nil when there are rows to draw.
local function emptyText()
    if not ui.run then return L["Select a run in the Results window to see its timeline."] end
    if #ui.rows == 0 then return L["No casts recorded for this run."] end
    return nil
end

-- Everything but the lanes: the legend, the empty message, the axes and the scroll frame.
local function layoutFrame(g)
    local top = layoutLegend(g)
    local empty = emptyText()
    ui.empty:SetText(empty or "")
    ui.empty:SetShown(empty ~= nil)
    ui.isEmpty = empty ~= nil
    ui.scroll:SetShown(not ui.isEmpty)
    placeAxes(g, not ui.isEmpty)
    ui.scroll:ClearAllPoints()
    ui.scroll:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", Timeline.PAD, -(top + 8))
    ui.viewH = math.max(1, ui.height - top - 8 - Timeline.AXIS_H - 8)
    ui.scroll:SetSize(g.cw, ui.viewH)
    ui.content:SetWidth(g.cw)
end

function layout()
    if not ui then return end
    local g = geometry()
    ui.laidW = g.cw
    ui.stackA, ui.stackB = stackOf(ui.castsA, g), stackOf(ui.castsB, g)
    ui.sections = Timeline.Sections(ui.stackA.count, ui.stackB.count)
    buildAxes(g)
    layoutFrame(g)
    layoutStrips(g)
    layoutRows(g)
    ui.contentH = math.max(1, ui.sections.lanes + #ui.rows * Timeline.PAIR_H - Timeline.PAIR_GAP)
    ui.content:SetHeight(ui.contentH)
    sizeClips(g)
    placeZoom(g)
    applyPan(g)
    Timeline.Scroll(0)
end

-- The cheap half of a resize (modules/Sizing.lua): the frame laid out at the tracked size, the lanes,
-- the strips and the clips stretched only when the width moved; layout re-pools them once, on release.
function resize()
    if not ui then return end
    if not ui.sections then return layout() end
    local g = geometry()
    local widthMoved = g.cw ~= ui.laidW
    ui.laidW = g.cw
    layoutFrame(g)
    if widthMoved then
        stretchStrips(g)
        stretchRows(g)
        sizeClips(g)
    end
    applyPan(g)
    Timeline.Scroll(0)
end

-- Another run or compare target: back to 1x, from 0:00 (the same pair redrawn keeps the view).
local function followZoom(run, other)
    local runKey, otherKey = run and (run.id or run), other and (other.id or other)
    if ui.runKey ~= runKey or ui.otherKey ~= otherKey then ui.zoomI, ui.pos = 1, 0 end
    ui.runKey, ui.otherKey = runKey, otherKey
end

-- Read the followed detail's run and compare target, and draw them.
local function draw()
    local run = pane and pane.run or nil
    local other, kind
    if run and pane.CompareTarget then other, kind = pane:CompareTarget(true) end
    if ui.run ~= run then ui.offset = 0 end
    followZoom(run, other)
    ui.run, ui.other, ui.kind = run, other, kind
    ui.otherHas = Timeline.Has(other)
    ui.rows = Timeline.Has(run) and Timeline.Rows(run, other) or {}
    ui.castsA, ui.castsB = Timeline.CastsOf(run), Timeline.CastsOf(other)
    ui.span = Timeline.Span(run, other)
    if run then
        local this, label, note = Timeline.Legend(run, other, kind)
        ui.legendA:SetText(this)
        ui.legendB:SetText(label)
        ui.thisLabel, ui.otherLabel, ui.noteText = this, Timeline.OtherLabel(other, kind), note
        ui.note:SetText(note or "")
    end
    Timeline.ApplyScale()
    layout()
    debug("drawn: %d abilities", #ui.rows)
end

-- ── the public surface ──────────────────────────────────────────────────────────────────────────

--- Open the window on the detail pane `p` (the detail's Timeline button) and follow it from now on.
--- @return boolean opened
function Timeline.Open(p)
    if NS.IsStoodDown() then return false end
    pane = p
    Timeline.wanted = true
    ensureWindow()
    ui.frame:Show()
    if ui.frame.Raise then ui.frame:Raise() end
    NS.RaiseStaticPopups()
    NS.Results.SetCovered(true)
    draw()
    return true
end

--- Close the window (its close control, the Results window closing): the Results window's cover goes.
function Timeline.Hide()
    Timeline.wanted = false
    if ui and ui.frame:IsShown() then
        hiding = true
        ui.frame:Hide()
        hiding = false
    end
    NS.Results.SetCovered(false)
end

--- Whether the window is open.
function Timeline.IsShown()
    return Timeline.wanted and ui ~= nil and ui.frame:IsShown() == true
end

--- The detail pane `p` drew a run or changed its compare target: redraw while open on it.
function Timeline.DetailChanged(p)
    if p == pane and Timeline.IsShown() then draw() end
end

--- One mouse-wheel notch (`delta` > 0 scrolls up), clamped to the lanes.
function Timeline.Scroll(delta)
    if not ui then return end
    local top = math.max(0, (ui.contentH or 0) - (ui.viewH or 0))
    ui.offset = math.max(0, math.min(top, (ui.offset or 0) - (delta or 0) * Timeline.PAIR_H))
    ui.scroll:SetVerticalScroll(ui.offset)
end

--- One Shift+wheel notch (`delta` > 0 pans toward 0:00): PAN of the view, clamped to the axis.
function Timeline.Pan(delta)
    if not ui then return end
    local zoom = Timeline.ZoomAt(ui.zoomI)
    ui.pos = Timeline.ClampPos((ui.pos or 0) - (delta or 0) * Timeline.PAN / zoom, zoom)
    applyPan(geometry())
end

-- To zoom step `i` (clamped), about the view's middle, and the full layout (the icons restack).
local function setZoom(i)
    if not ui then return false end
    i = math.max(1, math.min(#Timeline.ZOOMS, i))
    if i == ui.zoomI then return false end
    ui.pos = Timeline.Rezoom(ui.pos, Timeline.ZoomAt(ui.zoomI), Timeline.ZoomAt(i))
    ui.zoomI = i
    layout()
    debug("zoom %sx", tostring(Timeline.ZoomAt(i)))
    return true
end

--- `steps` zoom steps in (> 0) or out (< 0): the strips and the lanes together (the zoom controls).
--- @return boolean changed
function Timeline.ZoomBy(steps)
    return setZoom((ui and ui.zoomI or 1) + (steps or 0))
end

--- Back to 1x (the reset control).
--- @return boolean changed
function Timeline.ResetZoom()
    return setZoom(1)
end

--- The zoom now (1 before the window is built).
function Timeline.Zoom()
    return Timeline.ZoomAt(ui and ui.zoomI or 1)
end

--- Master scale on the window (a draw, and the scale row's reaction in settings/General.lua). Nothing
--- before the window is built: the first open applies it.
function Timeline.ApplyScale()
    local scale = tonumber(NS.GetSetting("scale"))
    if ui and scale then ui.frame:SetScale(scale) end
end

--- Back to the default place and size (the Master controls' Reset position).
function Timeline.ResetPosition()
    local w = store()
    if w then w.point, w.relativePoint, w.x, w.y, w.width, w.height = nil, nil, nil, nil, nil, nil end
    if ui then
        applyPlacement()
        layout()
    end
end

--- The cast ticks drawn now, for the suites: { { tex, hit, cast, x, y, lane = "a" | "b" }, ... }.
function Timeline.Marks()
    return ui and ui.drawn or {}
end

--- The cast icons drawn now, for the suites: { { frame, cast, x, y, row, side = "a" | "b" }, ... }.
function Timeline.Icons()
    return ui and ui.icons or {}
end

--- Where each part of the content starts now (Timeline.Sections), for the suites.
function Timeline.Layout()
    return ui and ui.sections or nil
end

--- The built window, for the suites (nil until first opened).
function Timeline.__ui() return ui end
