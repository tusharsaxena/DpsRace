local _, NS = ...
-- modules/Results_Timeline.lua — the ability timeline (#14): a pop-out window from the Results detail's
-- *Timeline* button that sets every ability the run cast on one time axis, beside the run the detail
-- compares it with (the owner's pick of the mock, version 2, 2026-10-26).
--
-- THE LAYOUT. A legend bar (this run's date in gold, the compared run's in blue and what it is: the
-- best, the runner-up or the picked run), then one pair of lanes per ability: its name cell (icon,
-- name, its cooldown when over 15 s, "(pet)" for a pet's) beside two lanes, the top one this run's
-- casts (gold dots), the bottom one the compared run's (blue), each lane's cast count at its right.
-- Abilities with a cooldown over 15 s come first, longest first; the rest follow by count. The time
-- axis (0, the quarters, the end) is pinned under the lanes, which scroll (the mouse wheel). A dot's
-- tooltip names the spell and its time; a name's shows the client's spell tooltip and both counts.
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
-- PLAIN DATA ONLY: the stored run.casts records (plain numbers). Every position is computed from the
-- constants here and the window's stored size, never read back off a frame; Rows, Span, Ticks, DotX,
-- CooldownText and Legend are pure.

local Timeline = { wanted = false }
NS.ResultsTimeline = Timeline

local L = NS.L
local Style = NS.Style
local FONT = Style.FONT
local Tbl = NS.ResultsTable
local C = Tbl.COLORS

local DW = NS.defaults.profile.windows.timeline
Timeline.FRAME_NAME = "DpsRaceTimeline"
Timeline.WIDTH, Timeline.HEIGHT = DW.width, DW.height
Timeline.MIN_WIDTH = 600
Timeline.MIN_HEIGHT = 240

-- The mock's geometry: a 170 px name cell, the lanes, a count cell, 10 px between them; each lane 16 px,
-- 2 px between a pair's lanes and 10 px between pairs.
Timeline.PAD = 12
Timeline.NAME_W = 170
Timeline.COUNT_W = 40
Timeline.GAP = 10
Timeline.LANE_H = 16
Timeline.LANE_GAP = 2
Timeline.PAIR_GAP = 10
Timeline.PAIR_H = 2 * Timeline.LANE_H + Timeline.LANE_GAP + Timeline.PAIR_GAP
Timeline.ICON = 16
Timeline.DOT = 8            -- a cast's dot
Timeline.DOT_HIT = 12       -- its hover frame
Timeline.INSET = 4          -- a dot's radius: one at 0:00 or at the end stays inside its lane
Timeline.LEGEND_H = 26
Timeline.NOTE_H = 16
Timeline.AXIS_H = 20

-- The two runs' colors: this run gold, the compared run blue (the mock's).
Timeline.THIS = { Style.GOLD[1], Style.GOLD[2], Style.GOLD[3] }
Timeline.OTHER = { 0.35, 0.66, 1.0 }
local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"   -- a white disc, tinted
local TRACK = { 1, 1, 1, 0.06 }
local GRID = { 1, 1, 1, 0.08 }
local HEADER_H = Style.TITLE_BAR_H
local SEP = " \194\183 "

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

-- Important abilities (base cooldown over 15 s) first, the longest first; then the rest by this run's
-- count, then the compared run's; the player's before the pet's, then the id.
local function before(a, b)
    local limit = NS.Casts.IMPORTANT_MS
    local ia, ib = a.cd > limit, b.cd > limit
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

--- The axis's ticks: 0, the quarters and the end.
function Timeline.Ticks(span)
    return { 0, span / 4, span / 2, span * 3 / 4, span }
end

--- A dot's x in a lane `width` wide: INSET + clamp(t, 0, span) / span x (width - 2 x INSET). A
--- pre-pull cast sits at 0:00, one after the buzzer at the end. nil without a time or a span.
function Timeline.DotX(t, span, width)
    if type(t) ~= "number" or type(span) ~= "number" or span <= 0 then return nil end
    local inset = Timeline.INSET
    return inset + math.max(0, math.min(span, t)) / span * math.max(0, width - 2 * inset)
end

--- A row's cooldown as the name cell shows it: m:ss when over 15 s, else nothing.
function Timeline.CooldownText(row)
    if not (row and row.cd > NS.Casts.IMPORTANT_MS) then return "" end
    return NS.Format.Length(row.cd / 1000)
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

local layout

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

local function buildBody(f)
    ui.scroll = CreateFrame("ScrollFrame", nil, f)
    ui.content = CreateFrame("Frame", nil, ui.scroll)
    ui.scroll:SetScrollChild(ui.content)
    ui.scroll:EnableMouseWheel(true)
    ui.scroll:SetScript("OnMouseWheel", function(_, delta) Timeline.Scroll(delta) end)
    -- The dots' own layer over the lanes (a child frame draws over its parent's textures); the
    -- quarter lines under the dots on it.
    ui.dots = CreateFrame("Frame", nil, ui.content)
    ui.dots:SetAllPoints(ui.content)
    ui.dots:SetFrameLevel(ui.content:GetFrameLevel() + 5)
    ui.grid = {}
    for i = 1, 3 do
        ui.grid[i] = ui.dots:CreateTexture(nil, "BACKGROUND")
        ui.grid[i]:SetColorTexture(GRID[1], GRID[2], GRID[3], GRID[4])
        ui.grid[i]:SetWidth(1)
    end
    ui.pairs = NS.Pool.New()
    ui.dotPool = NS.Pool.New()
    ui.hitPool = NS.Pool.New()
    ui.empty = Style.Text(f, FONT.EMPTY, nil, "CENTER")
    ui.empty:SetPoint("CENTER", f, "CENTER", 0, 0)
    ui.axis = {}
    for i = 1, 5 do
        local justify = i == 1 and "LEFT" or (i == 5 and "RIGHT" or "CENTER")
        ui.axis[i] = Style.Text(f, FONT.CAPTION, nil, justify)
    end
end

local function onHide()
    Tbl.HideTip()
    if hiding or (ui and ui.frame:IsShown()) then return end
    -- Escape (UISpecialFrames): the player closed it.
    Timeline.wanted = false
end

local function onResized(width, height)
    if type(width) == "number" then ui.width = math.max(Timeline.MIN_WIDTH, width) end
    if type(height) == "number" then ui.height = math.max(Timeline.MIN_HEIGHT, height) end
    layout()
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
    ui = { frame = f, rows = {}, offset = 0 }
    f:Hide()
    f:SetFrameStrata(NS.Constants.LAYERS.STRATA.WINDOW)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetToplevel(true)
    buildChrome(f)
    buildLegend(f)
    buildBody(f)
    NS.ApplySkin(f)
    f:SetScript("OnHide", onHide)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, Timeline.FRAME_NAME) end
    NS.MakeResizable(f, {
        minWidth = Timeline.MIN_WIDTH, minHeight = Timeline.MIN_HEIGHT,
        onResize = onResized, onResizeStop = saveSize,
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
    pair.cd = Style.Text(pair, FONT.CAPTION, nil, "RIGHT")
    pair.laneA, pair.laneB = track(pair), track(pair)
    pair.countA = Style.Text(pair, FONT.TEXT, Timeline.THIS, "RIGHT")
    pair.countB = Style.Text(pair, FONT.TEXT, Timeline.OTHER, "RIGHT")
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
    count:SetPoint("RIGHT", pair, "TOPLEFT", laneX + laneW + Timeline.GAP + Timeline.COUNT_W, y - Timeline.LANE_H / 2)
    count:SetWidth(Timeline.COUNT_W)
end

local function fillPair(pair, row, y, g)
    pair.row = row
    pair:ClearAllPoints()
    pair:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 0, y)
    pair:SetWidth(g.cw)
    pair.icon:SetTexture(NS.HudBreakdown.SpellIcon(row.id))
    pair.name:SetText(Timeline.Name(row))
    pair.cd:SetText(Timeline.CooldownText(row))
    pair.cd:ClearAllPoints()
    pair.cd:SetPoint("RIGHT", pair, "TOPLEFT", Timeline.NAME_W, -Timeline.LANE_H / 2)
    pair.cd:SetWidth(44)
    pair.name:SetWidth(Timeline.NAME_W - Timeline.ICON - 6 - 46)
    placeLane(pair, pair.laneA, pair.countA, 0, g.laneX, g.laneW)
    placeLane(pair, pair.laneB, pair.countB, -(Timeline.LANE_H + Timeline.LANE_GAP), g.laneX, g.laneW)
    pair.countA:SetText(tostring(row.countA))
    pair.countB:SetText(ui.otherHas and tostring(row.countB) or "")
end

-- ── the dots ────────────────────────────────────────────────────────────────────────────────────

local function newHit()
    local h = CreateFrame("Frame", nil, ui.dots)
    h:SetSize(Timeline.DOT_HIT, Timeline.DOT_HIT)
    h:EnableMouse(true)
    h:SetScript("OnEnter", function(self)
        if self.cast then Tbl.BelowTip(self, Timeline.DotLines(self.cast, self.label)) end
    end)
    h:SetScript("OnLeave", Tbl.HideTip)
    return h
end

--- A dot's tooltip: the spell and its time (ResultsTips.Dot), then which run it is.
function Timeline.DotLines(cast, label)
    local lines = NS.ResultsTips.Dot(cast)
    if lines and label then lines[#lines + 1] = { label, 0.62, 0.62, 0.68 } end
    return lines
end

-- One dot at `x` along the lane whose middle is `y` (content coordinates).
local function placeDot(cast, x, y, color, label)
    local d = NS.Pool.Acquire(ui.dotPool, function() return disc(ui.dots, color, Timeline.DOT) end)
    d:SetVertexColor(color[1], color[2], color[3], 0.95)
    d:ClearAllPoints()
    d:SetPoint("CENTER", ui.dots, "TOPLEFT", x, y)
    local h = NS.Pool.Acquire(ui.hitPool, newHit)
    h.cast, h.label = cast, label
    h:ClearAllPoints()
    h:SetPoint("CENTER", ui.dots, "TOPLEFT", x, y)
    ui.drawn[#ui.drawn + 1] = { tex = d, hit = h, cast = cast, x = x, y = y, lane = color == Timeline.THIS and "a" or "b" }
end

local function laneDots(row, side, top, g)
    local times = row[side]
    local color = side == "a" and Timeline.THIS or Timeline.OTHER
    local label = side == "a" and ui.thisLabel or ui.otherLabel
    for _, t in ipairs(times) do
        local x = Timeline.DotX(t, g.span, g.laneW)
        if x then placeDot({ t = t, id = row.id, pet = row.pet }, g.laneX + x, top - Timeline.LANE_H / 2, color, label) end
    end
end

-- ── drawing ─────────────────────────────────────────────────────────────────────────────────────

-- The geometry for the window's stored size: the content's width, the lanes' left and width, the span.
local function geometry()
    local cw = math.max(100, ui.width - 2 * Timeline.PAD)
    local laneX = Timeline.NAME_W + Timeline.GAP
    local laneW = math.max(40, cw - laneX - Timeline.GAP - Timeline.COUNT_W)
    return { cw = cw, laneX = laneX, laneW = laneW, span = ui.span or 1 }
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

local function layoutAxis(g, shown)
    local ticks = Timeline.Ticks(g.span)
    for i, fs in ipairs(ui.axis) do
        fs:SetShown(shown)
        local x = Timeline.PAD + g.laneX + Timeline.DotX(ticks[i], g.span, g.laneW)
        local point = i == 1 and "BOTTOMLEFT" or (i == 5 and "BOTTOMRIGHT" or "BOTTOM")
        fs:ClearAllPoints()
        fs:SetPoint(point, ui.frame, "BOTTOMLEFT", x, 8)
        fs:SetText(NS.Format.Length(ticks[i]))
    end
    for i, line in ipairs(ui.grid) do
        line:SetShown(shown)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", ui.dots, "TOPLEFT", g.laneX + Timeline.DotX(ticks[i + 1], g.span, g.laneW), 0)
        line:SetPoint("BOTTOMLEFT", ui.dots, "BOTTOMLEFT", g.laneX + Timeline.DotX(ticks[i + 1], g.span, g.laneW), 0)
    end
end

local function layoutRows(g)
    NS.Pool.ReleaseAll(ui.pairs, function(pair) pair.row = nil end)
    NS.Pool.ReleaseAll(ui.dotPool)
    NS.Pool.ReleaseAll(ui.hitPool, function(h) h.cast, h.label = nil, nil end)
    ui.drawn = {}
    for i, row in ipairs(ui.rows) do
        local y = -(i - 1) * Timeline.PAIR_H
        fillPair(NS.Pool.Acquire(ui.pairs, newPair), row, y, g)
        laneDots(row, "a", y, g)
        laneDots(row, "b", y - Timeline.LANE_H - Timeline.LANE_GAP, g)
    end
end

-- The empty message for what is missing, or nil when there are rows to draw.
local function emptyText()
    if not ui.run then return L["Select a run in the Results window to see its timeline."] end
    if #ui.rows == 0 then return L["No casts recorded for this run."] end
    return nil
end

function layout()
    if not ui then return end
    local g = geometry()
    local top = layoutLegend(g)
    local empty = emptyText()
    ui.empty:SetText(empty or "")
    ui.empty:SetShown(empty ~= nil)
    ui.scroll:SetShown(empty == nil)
    layoutAxis(g, empty == nil)
    ui.scroll:ClearAllPoints()
    ui.scroll:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", Timeline.PAD, -(top + 8))
    ui.viewH = math.max(1, ui.height - top - 8 - Timeline.AXIS_H - 8)
    ui.scroll:SetSize(g.cw, ui.viewH)
    ui.content:SetWidth(g.cw)
    layoutRows(g)
    ui.contentH = math.max(1, #ui.rows * Timeline.PAIR_H - Timeline.PAIR_GAP)
    ui.content:SetHeight(ui.contentH)
    Timeline.Scroll(0)
end

-- Read the followed detail's run and compare target, and draw them.
local function draw()
    local run = pane and pane.run or nil
    local other, kind
    if run and pane.CompareTarget then other, kind = pane:CompareTarget(true) end
    if ui.run ~= run then ui.offset = 0 end
    ui.run, ui.other, ui.kind = run, other, kind
    ui.otherHas = Timeline.Has(other)
    ui.rows = Timeline.Has(run) and Timeline.Rows(run, other) or {}
    ui.span = Timeline.Span(run, other)
    if run then
        local this, label, note = Timeline.Legend(run, other, kind)
        ui.legendA:SetText(this)
        ui.legendB:SetText(label)
        ui.thisLabel, ui.otherLabel, ui.noteText = this, Timeline.OtherLabel(other, kind), note
        ui.note:SetText(note or "")
    end
    local scale = tonumber(NS.GetSetting("scale"))
    if scale then ui.frame:SetScale(scale) end
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
    draw()
    return true
end

--- Close the window (its close control, the Results window closing).
function Timeline.Hide()
    Timeline.wanted = false
    if ui and ui.frame:IsShown() then
        hiding = true
        ui.frame:Hide()
        hiding = false
    end
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

--- Back to the default place and size (the Master controls' Reset position).
function Timeline.ResetPosition()
    local w = store()
    if w then w.point, w.relativePoint, w.x, w.y, w.width, w.height = nil, nil, nil, nil, nil, nil end
    if ui then
        applyPlacement()
        layout()
    end
end

--- The dots drawn now, for the suites: { { tex, hit, cast, x, y, lane = "a" | "b" }, ... }.
function Timeline.Dots()
    return ui and ui.drawn or {}
end

--- The built window, for the suites (nil until first opened).
function Timeline.__ui() return ui end
