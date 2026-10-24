local _, NS = ...
-- modules/Hud_States.lua — the Race HUD's six bodies (spec §6.1, mockup screens 02-07): idle, armed,
-- running, stop, waiting and result. Each is built on first show into the HUD's content frame and
-- answers Update(view) (and the running body SetLive(live, rows, icons)); modules/Hud.lua owns the
-- shell, decides which body shows and builds the view.
--
-- LAYOUT FROM CONFIG. Every position is a constant offset or an anchor; the only size a body uses is
-- the one Layout(width, height) hands it, which modules/Hud.lua computes from the stored window size.
-- No body reads the size or position of anything that has displayed a meter value. The spell rows
-- are capped to what fits between a body's fixed top and bottom at that height (RowCapacity), and
-- States.MinContentHeight() is the tallest body's fixed stack, which sets the window's minimum. The chip strips measure
-- their own text (GetStringWidth on a label that only ever holds plain copy), never a value.
--
-- A body's buttons call NS.Hud.Act.* at CALL time, so the act is the shell's and a test may drive it.

local States = {}
NS.HudStates = States

local L = NS.L
local Style = NS.Style
local FONT = Style.FONT

local C = {
    text  = { 0.93, 0.93, 0.95 },
    dim   = { 0.62, 0.62, 0.68 },
    gold  = Style.GOLD,
    amber = { 1.0, 0.72, 0.29 },
    red   = { 1.0, 0.32, 0.32 },
    green = { 0.36, 0.86, 0.46 },
    info  = { 0.56, 0.72, 1.0 },
}
States.COLORS = C

local FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local PANEL_BG, PANEL_EDGE = { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.10 }
-- The plain button is LootHistory's bar button (a dark fill, the window's divider gray for an edge,
-- white GameFontHighlightSmall that turns gold under the pointer); primary and danger keep a tinted edge.
local BUTTON_STYLES = {
    normal  = { bg = { 0.1, 0.1, 0.12, 0.9 }, edge = { 0.24, 0.24, 0.27, 0.9 }, text = { 1, 1, 1 } },
    primary = { bg = { 1, 0.82, 0, 0.12 }, edge = { 1, 0.82, 0, 0.75 }, text = C.gold },
    danger  = { bg = { 1, 0.32, 0.32, 0.08 }, edge = { 1, 0.32, 0.32, 0.6 }, text = C.red },
}
local BIG = 40           -- the clock and STOP
-- The running body's two clocks side by side ("both"): up to seven monospace glyphs each (a race
-- of 10:00 or more reads "15:00.0"), so two fit the minimum width's 236 px of content (an advance of
-- at most 0.62 em: 2 x 7 x 0.62 x 26 + 8 = 234).
local CLOCK_PAIR = 26
States.CLOCK_PAIR_SIZE = CLOCK_PAIR
local KPI_HEIGHT = 46
-- Every button is LootHistory's 20px; Arm alone is a little taller, the one action of the idle body.
local BUTTON_HEIGHT = 20
local LINK_HEIGHT = 20
local GAP = 8
-- The idle body's stack, top down: the caption, two rows of presets, the target caption and card, the
-- warning line (two lines at the minimum width), then Arm and the refusal line under it.
local PRESET_TOP, PRESET_H, PRESET_GAP = 14, 20, 6
local IDLE_TARGET_Y = PRESET_TOP + 2 * PRESET_H + PRESET_GAP + 8
local IDLE_CARD_Y = IDLE_TARGET_Y + 14
local IDLE_WARN_Y = IDLE_CARD_Y + 46 + 6
local IDLE_ARM_Y, ARM_HEIGHT, REASON_HEIGHT = IDLE_WARN_Y + 28, 24, 14
States.IDLE_ARM_Y, States.ARM_HEIGHT = IDLE_ARM_Y, ARM_HEIGHT
-- The running body's rows sit between the KPIs and the caption over Cancel.
local RUNNING_ROWS_TOP = 52 + KPI_HEIGHT + GAP
local RUNNING_ROWS_BOTTOM = BUTTON_HEIGHT + 22
-- The fewest spell rows any window size may leave a body (the minimum height is set from it).
local MIN_ROWS = 3
-- The preset race lengths (spec §4.1), then Custom.
States.PRESETS = { 30, 60, 120, 180, 300 }
local DASH = "\226\128\148"   -- an em dash: "no figure"

local function act(name, ...)
    local fn = NS.Hud and NS.Hud.Act and NS.Hud.Act[name]
    if fn then return fn(...) end
end

-- ── widgets ─────────────────────────────────────────────────────────────────────────────────────

local function paintText(fs, c)
    fs:SetTextColor(c[1], c[2], c[3])
end

--- A label in one of the shared font objects (modules/Style.lua), recolored when `color` is given.
--- Unlike Style.Text it may wrap: a body's notes run to two lines at the minimum width.
local function text(parent, font, color, justify)
    local fs = Style.Text(parent, font, color, justify)
    fs:SetWordWrap(true)
    return fs
end

-- A race clock or STOP: the one label kept in its own monospace face and size (modules/Style.lua).
local function bigText(parent, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local face = NS.Constants and NS.Constants.FONT_MONO or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    fs:SetFont(face, size, "")
    paintText(fs, color)
    fs:SetJustifyH("CENTER")
    return fs
end

local function panel(parent, bg, edge)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if f.SetBackdrop then
        f:SetBackdrop(FLAT)
        bg, edge = bg or PANEL_BG, edge or PANEL_EDGE
        f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        f:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
    end
    return f
end

local function paintButton(b)
    local s, on = b.style, b:IsEnabled()
    local edge = (b.selected and C.gold) or s.edge
    b:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], on and s.bg[4] or s.bg[4] * 0.4)
    b:SetBackdropBorderColor(edge[1], edge[2], edge[3], on and (edge[4] or 1) or 0.25)
    local t = ((b.selected or (b.hot and on)) and C.gold) or s.text
    b.label:SetTextColor(t[1], t[2], t[3], on and 1 or 0.4)
end

local function setHot(b, on)
    b.hot = on
    paintButton(b)
end

--- A flat button: a label, a style, and a click that a disabled button never runs. Its label is
--- GameFontHighlightSmall and turns gold under the pointer (LootHistory's bar button).
local function button(parent, label, onClick, style)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    if b.SetBackdrop then b:SetBackdrop(FLAT) end
    b:SetHeight(BUTTON_HEIGHT)
    b.style = BUTTON_STYLES[style or "normal"]
    b.label = Style.Text(b, FONT.TEXT, b.style.text, "CENTER")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetText(label)
    b:SetScript("OnClick", function(self)
        if self:IsEnabled() then onClick(self) end
    end)
    b:SetScript("OnEnter", function(self) setHot(self, true) end)
    b:SetScript("OnLeave", function(self) setHot(self, false) end)
    paintButton(b)
    return b
end
States.Button = button

local function setEnabled(b, on)
    b:SetEnabled(on and true or false)
    paintButton(b)
end
States.SetEnabled = setEnabled

local function setSelected(b, on)
    b.selected = on and true or false
    paintButton(b)
end

--- A figure in a box: a small caption, a large value and its unit (LootHistory's Insights card: a
--- GameFontNormalHuge figure over a GameFontDisableSmall caption).
local function kpi(parent, label, valueColor)
    local f = panel(parent)
    f:SetHeight(KPI_HEIGHT)
    local k = { frame = f }
    k.label = Style.Text(f, FONT.CAPTION)
    k.label:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
    k.label:SetText(label)
    k.value = Style.Text(f, FONT.FIGURE, valueColor or C.text)
    k.value:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 5)
    k.unit = Style.Text(f, FONT.CAPTION)
    k.unit:SetPoint("BOTTOMLEFT", k.value, "BOTTOMRIGHT", 3, 1)
    return k
end

local function setKpi(k, value, unit)
    k.value:SetText(value)
    k.unit:SetText(unit or "")
end

--- Two KPIs side by side at `y`, halves by anchor (no width needed).
local function kpiPair(parent, y, leftLabel, rightLabel, rightColor)
    local a, b = kpi(parent, leftLabel), kpi(parent, rightLabel, rightColor)
    a.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    a.frame:SetPoint("TOPRIGHT", parent, "TOP", -4, y)
    b.frame:SetPoint("TOPLEFT", parent, "TOP", 4, y)
    b.frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    return a, b
end

-- A section label: header gold, Title Case (a column header's look).
local function caption(parent, label, y)
    local fs = Style.Text(parent, FONT.HEADER)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    fs:SetText(label)
    return fs
end

-- The width a plain label takes: its own measurement (it never holds a meter value), else an
-- estimate from its length, for a client or a harness that cannot answer yet.
local function textWidth(fs, s)
    local w = fs.GetStringWidth and fs:GetStringWidth()
    if type(w) == "number" and w > 0 then return w end
    return #s * 6
end

-- ── chips ───────────────────────────────────────────────────────────────────────────────────────

local CHIP_HEIGHT, CHIP_GAP = 18, 5
-- The result card's rows sit under two lines of chips and above its three buttons.
local RESULT_ROWS_TOP = KPI_HEIGHT + GAP + 2 * (CHIP_HEIGHT + CHIP_GAP) + 4
local RESULT_ROWS_BOTTOM = LINK_HEIGHT + GAP

local function newChip(parent)
    local f = panel(parent)
    f:SetHeight(CHIP_HEIGHT)
    f.label = Style.Text(f, FONT.TEXT, C.text, "CENTER")
    f.label:SetPoint("CENTER", f, "CENTER", 0, 0)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if not self.tip or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return f
end

local Chips = {}
Chips.__index = Chips

local function chips(parent, y)
    return setmetatable({ parent = parent, y = y, pool = NS.Pool.New(), width = 260, shown = {} }, Chips)
end

--- Lay out `list` ({ text, color, tip }) left to right, wrapping at the body's width.
function Chips:Set(list)
    NS.Pool.ReleaseAll(self.pool)
    self.shown = {}
    local x, y, parent = 0, self.y, self.parent
    for i, item in ipairs(list or {}) do
        local chip = NS.Pool.Acquire(self.pool, function() return newChip(parent) end)
        local s, c = item.text, item.color or C.text
        chip.label:SetText(s)
        paintText(chip.label, c)
        chip:SetBackdropBorderColor(c[1], c[2], c[3], 0.55)
        chip:SetBackdropColor(c[1], c[2], c[3], 0.08)
        chip.tip, chip.text = item.tip, s
        local w = math.floor(textWidth(chip.label, s) + 14)
        if x > 0 and x + w > self.width then x, y = 0, y - CHIP_HEIGHT - CHIP_GAP end
        chip:SetWidth(w)
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        x = x + w + CHIP_GAP
        self.shown[i] = chip
    end
end

--- The chip texts drawn now, in order (the suites read these).
function Chips:Texts()
    local out = {}
    for i, chip in ipairs(self.shown) do out[i] = chip.text end
    return out
end

-- ── the target card ─────────────────────────────────────────────────────────────────────────────

local CARD_HEIGHT = 46

local function targetCard(parent, y, stepper)
    local f = panel(parent)
    f:SetHeight(CARD_HEIGHT)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    local card = { frame = f }
    card.name = Style.Text(f, FONT.HEADING)
    card.name:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
    card.name:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -7)
    card.badge = panel(f, { 1, 0.72, 0.29, 0.08 }, { 1, 0.72, 0.29, 0.6 })
    card.badge:SetHeight(16)
    card.badge:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 6)
    card.badgeText = Style.Text(card.badge, FONT.TEXT, C.amber, "CENTER")
    card.badgeText:SetPoint("CENTER", card.badge, "CENTER", 0, 0)
    card.meta = Style.Text(f, FONT.TEXT, C.dim)
    card.meta:SetPoint("LEFT", card.badge, "RIGHT", 8, 0)
    card.npc = Style.Text(f, FONT.CAPTION, nil, "RIGHT")
    card.npc:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
    if stepper then
        card.minus = button(f, "-", function() act("stepCount", -1) end)
        card.minus:SetSize(18, 18)
        card.minus:SetPoint("LEFT", card.meta, "RIGHT", 6, 0)
        card.count = Style.Text(f, FONT.HEADING, C.text, "CENTER")
        card.count:SetWidth(22)
        card.count:SetPoint("LEFT", card.minus, "RIGHT", 2, 0)
        card.plus = button(f, "+", function() act("stepCount", 1) end)
        card.plus:SetSize(18, 18)
        card.plus:SetPoint("LEFT", card.count, "RIGHT", 2, 0)
    end
    return card
end

local function setTarget(card, target, count)
    target = target or {}
    card.name:SetText(target.name or L["No target"])
    local badge = NS.Dummies.Label(target.category or "other")
    card.badgeText:SetText(badge)
    card.badge:SetWidth(math.floor(textWidth(card.badgeText, badge) + 12))
    card.npc:SetText(type(target.npcID) == "number" and ("#%d"):format(target.npcID) or "")
    count = count or 1
    if card.count then
        card.meta:SetText(L["Targets"])
        card.count:SetText(tostring(count))
        setEnabled(card.minus, count > 1)
    elseif count == 1 then
        card.meta:SetText(L["1 target"])
    else
        card.meta:SetText(L["%d targets"]:format(count))
    end
end

-- ── bodies ──────────────────────────────────────────────────────────────────────────────────────

local function newBody(parent, key)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:Hide()
    return { key = key, frame = f, w = {} }
end

-- A full-width row of `n` buttons at the bottom of the body, spread by anchor.
local function footerButtons(body, specs)
    local f, out = body.frame, {}
    for i, spec in ipairs(specs) do
        local b = button(f, spec[1], spec[2], spec[3])
        b:SetHeight(LINK_HEIGHT)
        if i == 1 then
            b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        elseif i == #specs then
            b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        else
            b:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
        end
        b:SetWidth(spec.width or 92)
        out[i] = b
    end
    return out
end

local function wideButton(body, label, onClick, style, height)
    local b = button(body.frame, label, onClick, style)
    b:SetHeight(height or BUTTON_HEIGHT)
    return b
end

--- How many spell rows fit in `height` pixels (rows at the breakdown's pitch, the last without its gap).
--- @param height number
--- @return number
function States.RowCapacity(height)
    local B = NS.HudBreakdown
    return math.max(0, math.floor((height + B.ROW_GAP) / B.Pitch()))
end

-- `wanted` rows, or fewer: what fits between `top` and `bottom` in the height Layout handed the body.
local function rowsFor(body, top, bottom, wanted)
    wanted = wanted or 0
    if type(body.height) ~= "number" then return wanted end
    return math.min(wanted, States.RowCapacity(body.height - top - bottom))
end

local Builders = {}

-- IDLE: length presets, the target card, Arm (spec §6.1; screen 02).
function Builders.idle(parent)
    local body = newBody(parent, "idle")
    local f, w = body.frame, body.w
    w.lengthCap = caption(f, L["Race Length"], 0)
    w.presets = {}
    for i, n in ipairs(States.PRESETS) do
        w.presets[i] = button(f, NS.Format.Length(n), function() act("pickLength", n) end)
        w.presets[i].length = n
    end
    w.custom = button(f, L["Custom"], function() act("openCustom") end)
    w.customBox = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    w.customBox:SetAutoFocus(false)
    w.customBox:SetFontObject(FONT.TEXT)
    w.customBox:SetJustifyH("CENTER")
    w.customBox:SetMaxLetters(6)
    w.customBox:SetScript("OnEnterPressed", function(self) act("customLength", self:GetText()) end)
    w.customBox:SetScript("OnEscapePressed", function() act("closeCustom") end)
    w.customBox:Hide()
    w.targetCap = caption(f, L["Target"], -IDLE_TARGET_Y)
    w.card = targetCard(f, -IDLE_CARD_Y, true)
    w.warn = text(f, FONT.TEXT, C.amber)
    w.warn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -IDLE_WARN_Y)
    w.warn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -IDLE_WARN_Y)
    w.arm = wideButton(body, L["Arm Race"], function() act("arm") end, "primary", ARM_HEIGHT)
    w.arm.label:SetFontObject(FONT.TITLE)
    w.arm:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -IDLE_ARM_Y)
    w.arm:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -IDLE_ARM_Y)
    w.reason = text(f, FONT.TEXT, C.amber, "CENTER")
    w.reason:SetPoint("TOPLEFT", w.arm, "BOTTOMLEFT", 0, -4)
    w.reason:SetPoint("TOPRIGHT", w.arm, "BOTTOMRIGHT", 0, -4)
    -- The Results window, across the foot (the owner dropped Last Result, 2026-10-24).
    w.results = wideButton(body, L["Results"], function() act("results") end)
    w.results:SetHeight(LINK_HEIGHT)
    w.results:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    w.results:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    function body.Layout(self, width)
        local cell = math.floor((width - 2 * 6) / 3)
        local grid = self.w.presets
        local all = { grid[1], grid[2], grid[3], grid[4], grid[5], self.w.custom }
        for i, b in ipairs(all) do
            local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
            b:ClearAllPoints()
            b:SetSize(cell, PRESET_H)
            b:SetPoint("TOPLEFT", self.frame, "TOPLEFT", col * (cell + 6), -PRESET_TOP - row * (PRESET_H + PRESET_GAP))
        end
        self.w.customBox:ClearAllPoints()
        self.w.customBox:SetAllPoints(self.w.custom)
    end

    function body.Update(self, v)
        local isPreset = false
        for _, b in ipairs(self.w.presets) do
            setSelected(b, b.length == v.length)
            isPreset = isPreset or b.length == v.length
        end
        setSelected(self.w.custom, not isPreset)
        self.w.custom.label:SetText(isPreset and L["Custom"] or NS.Format.Length(v.length))
        self.w.customBox:SetShown(v.editing == true)
        self.w.custom:SetShown(v.editing ~= true)
        setTarget(self.w.card, v.target, v.count)
        self.w.warn:SetText(v.warning or "")
        setEnabled(self.w.arm, v.blocker == nil)
        self.w.reason:SetText(v.blocker and NS.Format.ArmRefusal(v.blocker, v.detail) or "")
    end
    return body
end

-- ARMED: the length, unmoving, and what starts the clock (screen 03).
function Builders.armed(parent)
    local body = newBody(parent, "armed")
    local f, w = body.frame, body.w
    w.clock = bigText(f, BIG, C.text)
    w.clock:SetPoint("TOP", f, "TOP", 0, -4)
    w.sub = Style.Text(f, FONT.CAPTION, nil, "CENTER")
    w.sub:SetPoint("TOP", f, "TOP", 0, -52)
    w.sub:SetText(L["First hit starts the clock"])
    w.card = targetCard(f, -74, false)
    w.note = text(f, FONT.TEXT, C.dim)
    w.note:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -128)
    w.note:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -128)
    w.note:SetText(L["Pre-cast and pre-pot as you would on a pull. The clock starts when damage lands, not when you press the button."])
    w.cancel = wideButton(body, L["Cancel"], function() act("cancel") end)
    w.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    w.cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    function body.Update(self, v)
        local run = v.run or {}
        self.w.clock:SetText(NS.Format.Clock(run.race and run.race.length or 0))
        setTarget(self.w.card, run.target, run.target and run.target.count)
    end
    return body
end

-- The running clock (hud.clock): "left" or "elapsed" is one big clock in its color; anything else is
-- "both", the pair. Plain numbers from GetTime(), never a meter value.
local PAIR = { "elapsed", "left", "elapsedCap", "leftCap" }

local function setClocks(w, v)
    local mode, left, elapsed = v.clockMode, v.timeLeft or 0, v.elapsed or 0
    local both = mode ~= "left" and mode ~= "elapsed"
    for _, key in ipairs(PAIR) do w[key]:SetShown(both) end
    w.clock:SetShown(not both)
    if both then
        w.elapsed:SetText(NS.Format.Clock(elapsed))
        w.left:SetText(NS.Format.Clock(left))
        return
    end
    -- Its color is its font block's (styleRunning), like the pair's.
    w.clock:SetText(NS.Format.Clock(mode == "elapsed" and elapsed or left))
end

-- THE RUNNING BODY'S LOOK (HUD > HUD Appearance, modules/Hud_Appearance.lua): the elapsed and the
-- time-left clocks each in their own font block, the live figures in theirs. The stack below them is
-- laid out from the configured sizes, never from a measured one: the KPI pair sits under the clocks'
-- block, and the spell rows under the KPIs. At the defaults this is the shipped layout (KPIs at 52).
-- A clock shown alone ("left" or "elapsed") draws half again as large as the pair (26 -> 40).
local SINGLE_SCALE = BIG / CLOCK_PAIR

-- The KPIs' top for the clock mode and the blocks' sizes.
local function kpiTop(both, elapsedSize, leftSize, singleSize)
    if both then return 26 + math.max(elapsedSize, leftSize) end
    return 12 + math.floor(singleSize * SINGLE_SCALE + 0.5)
end

local function placeKpi(k, f, y, h, left)
    k.frame:ClearAllPoints()
    k.frame:SetHeight(h)
    if left then
        k.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
        k.frame:SetPoint("TOPRIGHT", f, "TOP", -4, y)
    else
        k.frame:SetPoint("TOPLEFT", f, "TOP", 4, y)
        k.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, y)
    end
end

--- Restyle the running body for the clock mode, once per HUD Appearance change or mode change.
local function styleRunning(body, mode)
    local A = NS.HudAppearance
    if not A then return end
    local both = mode ~= "left" and mode ~= "elapsed"
    local key = A.stamp .. ":" .. tostring(mode)
    if body.styled == key then return end
    body.styled = key
    local w, f = body.w, body.frame
    local ef, lf, ff = A.Font("elapsed"), A.Font("left"), A.Font("figures")
    local single = mode == "elapsed" and ef or lf
    A.ApplyFont(w.elapsed, ef)
    A.ApplyFont(w.left, lf)
    A.ApplyFont(w.clock, single, SINGLE_SCALE)
    A.ApplyFont(w.damage.value, ff)
    A.ApplyFont(w.dps.value, ff)
    local top = kpiTop(both, ef.size, lf.size, single.size)
    local kpiH = math.max(KPI_HEIGHT, ff.size + 26)
    placeKpi(w.damage, f, -top, kpiH, true)
    placeKpi(w.dps, f, -top, kpiH, false)
    body.kpiBottom = top + kpiH + GAP
end

-- Whether `top` and `bottom` leave room for MIN_ROWS spell rows in the height Layout handed the body.
local function roomForRows(body, top, bottom)
    if type(body.height) ~= "number" then return true end
    return States.RowCapacity(body.height - top - bottom) >= MIN_ROWS
end

-- The chart's block (header, plot, time labels and the gap under it) at the configured plot height.
local function chartBlock()
    local plotH = NS.HudChart.PlotHeight()
    return NS.HudChart.BlockHeight(plotH) + GAP, plotH
end

-- THE PACE BAR AND THE CHART (#3, #2) sit between the KPIs and the spell rows, each only when its view
-- is given (modules/Hud_Chart.lua LiveViews); the chart steps aside when it would leave fewer than
-- MIN_ROWS rows. Placed again only when what decides the stack changed: every input is config.
local function placeExtras(body, v)
    local w, f = body.w, body.frame
    local Chart = NS.HudChart
    local top = body.kpiBottom or RUNNING_ROWS_TOP
    local paceH = v.pace and (Chart.PACE_H + GAP) or 0
    local blockH, plotH = chartBlock()
    local chart = v.chart ~= nil and roomForRows(body, top + paceH + blockH, RUNNING_ROWS_BOTTOM)
    w.pace:SetShown(v.pace ~= nil)
    w.chart:SetShown(chart)
    body.chartView = chart and v.chart or nil
    local key = table.concat({ top, paceH, tostring(chart), plotH, tostring(body.width), tostring(body.height) }, "|")
    if body.placed == key then return end
    body.placed = key
    local y, width = top, body.width or 236
    if v.pace then w.pace:Place(f, -y, width) end
    y = y + paceH
    if chart then
        w.chart:Place(f, -y, width, plotH)
        y = y + blockH
    end
    body.rowsTop = y
    w.rows:ClearAllPoints()
    w.rows:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
    w.rows:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, RUNNING_ROWS_BOTTOM)
end

-- The live draw of the chart and the pace bar: opaque values to the bars' setters only. With no best
-- the chart's scale is the live total itself (scale B). No `and`/`or` on the total: that would
-- truth-test it.
local function drawExtras(body, live)
    local total
    if type(live) == "table" then total = live.total end
    if body.paceShown then body.w.pace:SetValue(total) end
    local view = body.chartView
    if not view then return end
    local scale
    if view.max == nil then scale = total end
    body.w.chart:Draw(view, scale)
end

-- The running body's spell rows. live.rows 0 is every spell (the owner's call, 2026-10-24): as many as
-- fit are drawn and the wheel moves the window over the rest, MultiMeters' model (a plain offset from
-- a wheel event, the slice drawn from it; no ScrollFrame and nothing measured). The count is the
-- length of the addon's own copy of the spell list (Meter.ReadLive), a plain number.
local function liveTotal(body)
    local live = body.live
    if type(live) ~= "table" or type(live.spells) ~= "table" then return 0 end
    return #live.spells
end

local function liveCap(body, rows)
    local top = body.rowsTop or RUNNING_ROWS_TOP
    if rows ~= 0 then return rowsFor(body, top, RUNNING_ROWS_BOTTOM, rows) end
    local total = liveTotal(body)
    if type(body.height) ~= "number" then return total end
    return math.min(total, States.RowCapacity(body.height - top - RUNNING_ROWS_BOTTOM))
end

local function liveCount(body, rows)
    local cap = liveCap(body, rows)
    if rows ~= 0 then return L["%d rows"]:format(cap) end
    local total, offset = liveTotal(body), body.offset or 0
    if total == 0 then return L["%d rows"]:format(0) end
    return L["%d-%d of %d"]:format(offset + 1, offset + cap, total)
end

local function drawLive(body)
    local rows, total = body.rowsSetting, liveTotal(body)
    local cap = liveCap(body, rows)
    local offset = 0
    if rows == 0 then offset = math.max(0, math.min(body.offset or 0, total - cap)) end
    body.offset = offset
    body.w.list:ShowLive(body.live, cap, body.icons ~= false, offset)
    body.w.count:SetText(liveCount(body, rows))
end

-- RUNNING: the race clock (hud.clock), live damage and DPS, the live breakdown with no % (screen 04).
function Builders.running(parent)
    local body = newBody(parent, "running")
    local f, w = body.frame, body.w
    w.clock = bigText(f, BIG, C.red)
    w.clock:SetPoint("TOP", f, "TOP", 0, -4)
    -- "both": elapsed (green) in the left half, time left (red) in the right, a caption under each.
    -- Halves by anchor, as the KPI pair below: no width is read.
    w.elapsed = bigText(f, CLOCK_PAIR, C.green)
    w.elapsed:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -6)
    w.elapsed:SetPoint("TOPRIGHT", f, "TOP", -4, -6)
    w.left = bigText(f, CLOCK_PAIR, C.red)
    w.left:SetPoint("TOPLEFT", f, "TOP", 4, -6)
    w.left:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -6)
    w.elapsedCap = Style.Text(f, FONT.CAPTION, nil, "CENTER")
    w.elapsedCap:SetPoint("TOP", w.elapsed, "BOTTOM", 0, -3)
    w.elapsedCap:SetText(L["Elapsed"])
    w.leftCap = Style.Text(f, FONT.CAPTION, nil, "CENTER")
    w.leftCap:SetPoint("TOP", w.left, "BOTTOM", 0, -3)
    w.leftCap:SetText(L["Left"])
    w.damage, w.dps = kpiPair(f, -52, L["Damage"], L["DPS \194\183 Live"])
    w.rows = CreateFrame("Frame", nil, f)
    w.rows:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -RUNNING_ROWS_TOP)
    w.rows:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, RUNNING_ROWS_BOTTOM)
    -- A backstop only: the rows are already capped to the region (rowsFor), never measured.
    w.rows:SetClipsChildren(true)
    w.list = NS.HudBreakdown.New(w.rows)
    w.pace = NS.HudChart.NewPace(f)
    w.pace:SetShown(false)
    w.chart = NS.HudChart.New(f)
    w.chart:SetShown(false)
    -- live.rows 0: the wheel moves the drawn slice, a row a notch (up is toward the top).
    w.rows:EnableMouseWheel(true)
    w.rows:SetScript("OnMouseWheel", function(_, delta)
        if body.rowsSetting ~= 0 or type(body.live) ~= "table" then return end
        body.offset = (body.offset or 0) + (delta > 0 and -1 or 1)
        drawLive(body)
    end)
    w.order = Style.Text(f, FONT.CAPTION)
    w.order:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, BUTTON_HEIGHT + 8)
    w.order:SetText(L["Live order \194\183 % after the race"])
    w.count = Style.Text(f, FONT.CAPTION, nil, "RIGHT")
    w.count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, BUTTON_HEIGHT + 8)
    w.cancel = wideButton(body, L["Cancel"], function() act("cancel") end)
    w.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    w.cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    function body.Layout(self, width, height) self.width, self.height = width, height end

    function body.Update(self, v)
        styleRunning(self, v.clockMode)
        placeExtras(self, v)
        self.paceShown = v.pace ~= nil
        if v.pace then self.w.pace:SetMax(v.pace.max) end
        setClocks(self.w, v)
        self.w.dps.frame:SetShown(v.showDps ~= false)
        -- A new race scrolls back to the top.
        if v.run ~= self.run then self.run, self.offset = v.run, 0 end
        self.rowsSetting = v.rows
        self.w.count:SetText(liveCount(self, v.rows))
    end

    --- The live figures: opaque values, straight to the formatter and the rows.
    function body.SetLive(self, live, rows, icons)
        drawExtras(self, live)
        if type(live) ~= "table" then
            setKpi(self.w.damage, DASH)
            setKpi(self.w.dps, DASH)
            self.w.list:Clear()
            return
        end
        setKpi(self.w.damage, NS.Format.Number(live.total))
        if live.dps == nil then setKpi(self.w.dps, DASH) else setKpi(self.w.dps, NS.Format.Number(live.dps)) end
        self.live, self.rowsSetting, self.icons = live, rows, icons
        drawLive(self)
    end
    return body
end

-- The two figures the stop and waiting bodies share: the tail and the time in combat since the buzzer.
local function setStopFigures(w, v)
    if v.endedEarly then
        w.tail.label:SetText(L["Combat Ended"])
        setKpi(w.tail, NS.Format.Length(v.endedAt or 0))
    else
        w.tail.label:SetText(L["Damage Stopped"])
        setKpi(w.tail, NS.Format.Seconds(v.tail), v.unitTail)
    end
    if v.inCombat then
        w.combat.label:SetText(L["In Combat"])
        setKpi(w.combat, NS.Format.Seconds(v.sinceBuzzer or 0), L["s"])
    else
        w.combat.label:SetText(L["Out of Combat"])
        setKpi(w.combat, DASH)
    end
end

-- STOP: the buzzer, the tail updating live, late casts so far, the grace (screen 05).
function Builders.stop(parent)
    local body = newBody(parent, "stop")
    local f, w = body.frame, body.w
    w.big = bigText(f, BIG + 8, C.red)
    w.big:SetPoint("TOP", f, "TOP", 0, -2)
    w.big:SetText(L["STOP"])
    w.tail, w.combat = kpiPair(f, -56, L["Damage Stopped"], L["In Combat"])
    w.chips = chips(f, -56 - KPI_HEIGHT - GAP)
    w.note = text(f, FONT.TEXT, C.dim)
    w.note:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -56 - KPI_HEIGHT - GAP - 28)
    w.note:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -56 - KPI_HEIGHT - GAP - 28)
    function body.Layout(self, width)
        self.w.chips.width = width
        self.shownKey = nil   -- the chips wrap at the new width on the next redraw
    end
    function body.Update(self, v)
        v.unitTail = L["s after buzzer"]
        setStopFigures(self.w, v)
        -- Redrawn at 4 Hz while combat may hold for minutes: the chips and the note are rebuilt
        -- only when what they say (the late casts, the grace) changed.
        local late, grace = v.lateCasts or {}, v.grace or 0
        local first = late[1] and late[1].t or 0
        local key = ("%d|%.1f|%.1f"):format(#late, first, grace)
        if key == self.shownKey then return end
        self.shownKey = key
        local list = {}
        if #late == 1 then
            list[1] = { text = L["1 late cast \194\183 +%.1fs"]:format(first), color = C.amber }
        elseif #late > 1 then
            list[1] = { text = L["%d late casts \194\183 +%.1fs"]:format(#late, first), color = C.amber }
        end
        list[#list + 1] = { text = L["Grace %.1fs"]:format(grace), color = C.info }
        self.w.chips:Set(list)
        self.w.note:SetText(L["Damage still landing (DoTs, travel time) counts. Casts that start more than %.1fs after the buzzer are flagged on the result."]:format(grace))
    end
    return body
end

-- WAITING: combat is holding; the hint, discard, close and keep waiting (screen 06).
function Builders.waiting(parent)
    local body = newBody(parent, "waiting")
    local f, w = body.frame, body.w
    w.title = Style.Text(f, FONT.TITLE, nil, "CENTER")
    w.title:SetPoint("TOP", f, "TOP", 0, -10)
    w.tail, w.combat = kpiPair(f, -40, L["Damage Stopped"], L["In Combat"])
    w.hint = panel(f, { 1, 0.72, 0.29, 0.07 }, { 1, 0.72, 0.29, 0.35 })
    w.hint:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -40 - KPI_HEIGHT - GAP)
    w.hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -40 - KPI_HEIGHT - GAP)
    w.hint:SetHeight(64)
    w.hintText = text(w.hint, FONT.TEXT, { 0.95, 0.85, 0.67 })
    w.hintText:SetPoint("TOPLEFT", w.hint, "TOPLEFT", 8, -7)
    w.hintText:SetPoint("BOTTOMRIGHT", w.hint, "BOTTOMRIGHT", -8, 7)
    w.hintText:SetJustifyV("TOP")
    local links = footerButtons(body, {
        { L["Discard Run"], function() act("discard") end, "danger" },
        { L["Close (Keep Waiting)"], function() act("close") end, width = 140 },
    })
    w.discard, w.close = links[1], links[2]
    function body.Update(self, v)
        local title = L["Waiting for combat to end"]
        if not v.inCombat then title = L["Reading the result"] end
        self.w.title:SetText(title)
        v.unitTail = L["s"]
        setStopFigures(self.w, v)
        self.w.hint:SetShown(v.hint ~= nil)
        self.w.hintText:SetText(v.hint or "")
    end
    return body
end

-- A flag's short chip label (the full text is its tooltip).
local FLAG_CHIP = {
    lateCasts = function(run)
        local n = #run.flags.lateCasts
        return n == 1 and L["1 late cast"] or L["%d late casts"]:format(n)
    end,
    restarted = function(run) return L["Restarted +%.1fs"]:format(run.flags.restartedAt) end,
    reloaded = function() return L["Reloaded"] end,
    sessionFromList = function() return L["Session by list"] end,
    sharedSession = function() return L["Shared session"] end,
    incomplete = function(run)
        if run.flags.died then return L["Incomplete: died"] end
        local at = run.result and run.result.endedAt
        return L["Incomplete (combat ended at %s)"]:format(NS.Format.Length(at or 0))
    end,
    lost = function() return L["Lost"] end,
    died = function() return L["Died"] end,
}

--- The result card's chips: the best delta, the flags, the tail (spec §6.1).
function States.ResultChips(v)
    local run, list = v.run, {}
    if v.isNew then
        list[1] = { text = v.delta and L["New best +%.1f%%"]:format(v.delta) or L["New best"], color = C.green }
    elseif v.delta then
        list[1] = { text = L["%+.1f%% vs best"]:format(v.delta), color = C.red }
    end
    for _, flag in ipairs(NS.Scoring.Flags(run, NS.HudBreakdown.SpellName)) do
        local skip = flag.key == "died" and run.status == "incomplete"
        local short = FLAG_CHIP[flag.key]
        if short and not skip then list[#list + 1] = { text = short(run), color = C.amber, tip = flag.text } end
    end
    -- The run's time: the length and the DoT tail, or the time in combat before the buzzer.
    if run.status ~= "lost" and type(run.result) == "table" then
        list[#list + 1] = { text = L["Time %s"]:format(NS.Format.RunTime(run)), color = C.info,
                            tip = L["The race length, then how long your damage kept landing after the buzzer (DoTs, travel time). An incomplete run shows its time in combat against the length."] }
    end
    return list
end

-- RESULT: damage, DPS, the delta and flag chips, the top spells with %, and the three acts (screen 07).
function Builders.result(parent)
    local body = newBody(parent, "result")
    local f, w = body.frame, body.w
    w.damage, w.dps = kpiPair(f, 0, L["Damage"], L["DPS"], C.green)
    w.chips = chips(f, -KPI_HEIGHT - GAP)
    w.lost = Style.Text(f, FONT.TEXT, C.red)
    w.lost:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -RESULT_ROWS_TOP)
    w.rows = CreateFrame("Frame", nil, f)
    w.rows:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -RESULT_ROWS_TOP)
    w.rows:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, RESULT_ROWS_BOTTOM)
    w.rows:SetClipsChildren(true)
    w.list = NS.HudBreakdown.New(w.rows)
    w.chart = NS.HudChart.New(f)
    w.chart:SetShown(false)
    -- live.rows 0: every spell, the wheel moving the slice, as on the running body.
    w.rows:EnableMouseWheel(true)
    w.rows:SetScript("OnMouseWheel", function(_, delta)
        if body.rowsSetting ~= 0 or not body.shownRun then return end
        body.offset = (body.offset or 0) + (delta > 0 and -1 or 1)
        body:DrawRows()
    end)
    local links = footerButtons(body, {
        { L["Race Again"], function() act("raceAgain") end, "primary" },
        { L["Details"], function() act("details") end, width = 72 },
        { L["Share"], function() act("share") end, width = 72 },
    })
    w.again, w.details, w.share = links[1], links[2], links[3]
    -- Details sits left of Share and Race Again takes what is left, so the three never overlap at
    -- the minimum width (a centered Details would run into a fixed-width Race Again there).
    w.details:ClearAllPoints()
    w.details:SetPoint("BOTTOMRIGHT", w.share, "BOTTOMLEFT", -6, 0)
    w.again:ClearAllPoints()
    w.again:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    w.again:SetPoint("BOTTOMRIGHT", w.details, "BOTTOMLEFT", -6, 0)
    function body.Layout(self, width, height)
        self.w.chips.width = width
        self.width, self.height = width, height
    end
    function body.Update(self, v)
        Builders.resultChart(self, v.chart)
        local run = v.run or {}
        local result = run.result or {}
        local lost = run.status == "lost"
        setKpi(self.w.damage, lost and DASH or NS.Format.Number(result.damage or 0))
        setKpi(self.w.dps, lost and DASH or NS.Format.Number(result.dps or 0))
        self.w.chips:Set(States.ResultChips(v))
        self.w.lost:SetText(lost and L["Couldn't read the result"] or "")
        if v.run ~= self.shownRun then self.offset = 0 end
        self.shownRun, self.rowsSetting, self.icons = (not lost) and v.run or nil, v.rows, v.icons
        if lost then self.w.list:Clear() else self:DrawRows() end
        setEnabled(self.w.share, v.canShare == true)
        -- The sample card of test mode has no run to race again or open (modules/Hud.lua Act).
        setEnabled(self.w.again, v.preview ~= true)
        setEnabled(self.w.details, v.preview ~= true)
    end
    function body.DrawRows(self) Builders.resultRows(self) end
    return body
end

-- The result card's spell rows follow *Spell rows shown* (live.rows), as the live list does: that many
-- from the top, or with 0 every spell, as many as fit and the wheel over the rest (the owner's call,
-- 2026-10-24; the spec's top 5 is the fallback when the setting cannot answer).
States.RESULT_ROWS = 5

-- The result card's chart (#2): the run's in-session slices, scaled to its plain final damage, between
-- the chips and the rows; none for a run without slices, and it steps aside when it would leave fewer
-- than MIN_ROWS rows.
function Builders.resultChart(body, view)
    local w, f = body.w, body.frame
    local blockH, plotH = chartBlock()
    local on = view ~= nil and roomForRows(body, RESULT_ROWS_TOP + blockH, RESULT_ROWS_BOTTOM)
    w.chart:SetShown(on)
    body.rowsTop = on and (RESULT_ROWS_TOP + blockH) or RESULT_ROWS_TOP
    w.rows:ClearAllPoints()
    w.rows:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -body.rowsTop)
    w.rows:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, RESULT_ROWS_BOTTOM)
    if not on then return end
    w.chart:Place(f, -RESULT_ROWS_TOP, body.width or 236, plotH)
    w.chart:Draw(view)
end

function Builders.resultRows(body)
    local run = body.shownRun
    local spells = type(run) == "table" and type(run.spells) == "table" and run.spells or {}
    local rows = tonumber(body.rowsSetting) or States.RESULT_ROWS
    local total = #spells
    local top = body.rowsTop or RESULT_ROWS_TOP
    local cap
    if rows == 0 then
        cap = total
        if type(body.height) == "number" then
            cap = math.min(total, States.RowCapacity(body.height - top - RESULT_ROWS_BOTTOM))
        end
    else
        cap = rowsFor(body, top, RESULT_ROWS_BOTTOM, rows)
    end
    local offset = 0
    if rows == 0 then offset = math.max(0, math.min(body.offset or 0, total - cap)) end
    body.offset = offset
    body.w.list:ShowResult(run, cap, body.icons ~= false, offset)
end

--- The content height the tallest body's fixed stack needs: the idle body down to its links, and
--- the running (with its pace bar) and result bodies with MIN_ROWS spell rows. modules/Hud.lua sets its minimum from it.
--- @return number
function States.MinContentHeight()
    local B = NS.HudBreakdown
    local rows = MIN_ROWS * (B.ROW_HEIGHT + B.ROW_GAP) - B.ROW_GAP
    local idle = IDLE_ARM_Y + ARM_HEIGHT + 4 + REASON_HEIGHT + 4 + LINK_HEIGHT
    -- The pace bar never steps aside (the chart does), so the running body's minimum carries it.
    local running = RUNNING_ROWS_TOP + NS.HudChart.PACE_H + GAP + rows + RUNNING_ROWS_BOTTOM
    local result = RESULT_ROWS_TOP + rows + RESULT_ROWS_BOTTOM
    return math.max(idle, running, result)
end

--- Build one body into `parent`.
--- @param key string  idle | armed | running | stop | waiting | result
--- @param parent table
--- @return table body  { key, frame, w, Update(view), Layout(width)?, SetLive(live, rows, icons)? }
function States.Build(key, parent)
    local builder = Builders[key]
    if not builder then return nil end
    return builder(parent)
end
