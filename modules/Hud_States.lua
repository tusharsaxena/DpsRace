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

-- The HUD's palette, every entry a live skin color (modules/Style.lua): the body text and its dim
-- gray, the header gold, and the race's meaning hues (core/SkinSetup.lua's owner tokens, whose Ka0s
-- Default values are the colors these drew before the skin engine).
local C = {
    text  = Style.Tok("dr.text"),
    dim   = Style.Tok("dr.dim"),
    gold  = Style.GOLD,
    amber = Style.Tok("dr.caution"),
    red   = Style.Tok("sem.statusBad"),
    green = Style.Tok("dr.ahead"),
    info  = Style.Tok("dr.info"),
}
States.COLORS = C

-- The flat box a KPI, a panel and a card stand in: a faint wash under a faint edge (the slot remap
-- of LibKa0s-Skin-1.0's Card and Panel, D-3).
local BOX = { bg = "list.boxDim", border = "dr.box.border" }
-- The buttons, each the skin's Button (LootHistory's bar button: a dark fill, the window's divider
-- gray for an edge, a white label that turns gold under the pointer) with the slots a style or a
-- state paints from another token: primary and danger keep a tinted box, a selected preset a gold
-- edge and label, and a disabled one its box and label faded (the dr.*.off* tokens).
local BUTTON_STYLES = {
    normal  = { on = {}, off = { bg = "dr.btn.offBg", border = "dr.btn.offBorder", disabled = "dr.btn.offText" } },
    primary = { primary = true,
                on = { bg = "dr.primary.bg", border = "dr.primary.border", hover = "dr.primary.hover" },
                off = { bg = "dr.primary.offBg", border = "dr.primary.offBorder", disabled = "dr.primary.offText" } },
    danger  = { on = { bg = "dr.danger.bg", border = "dr.danger.border", text = "dr.danger.text",
                       hover = "dr.danger.hover" },
                off = { bg = "dr.danger.offBg", border = "dr.danger.offBorder", disabled = "dr.danger.offText" } },
}
local SELECTED = {
    on = { border = "dr.sel.border", text = "btnPrimary.text", hover = "btnPrimary.text" },
    off = { bg = "dr.btn.offBg", border = "dr.primary.offBorder", disabled = "dr.primary.offText" },
}
local BIG = 40           -- the clock and STOP
-- The running body's two clocks side by side ("both"): up to seven monospace glyphs each (a race
-- of 10:00 or more reads "15:00.0"), so two fit the minimum width's 236 px of content (an advance of
-- at most 0.62 em: 2 x 7 x 0.62 x 26 + 8 = 234).
local CLOCK_PAIR = 26
States.CLOCK_PAIR_SIZE = CLOCK_PAIR
local KPI_HEIGHT = 46
-- The Stop! and waiting screens' tiles (the owner's call, 2026-10-28): the figure with its unit in one
-- large string ("+9.4s"), and under it a row in the caption font saying what it counts ("after
-- buzzer"), inside the tile. The row is KPI_CAPTION_H tall, the 5 px under it the figure's padding
-- today, so a captioned tile is that much taller and the stack under it moves down by as much.
local KPI_PAD, KPI_CAPTION_H = 5, 14
local KPI_CAPTIONED_HEIGHT = KPI_HEIGHT + KPI_CAPTION_H
States.KPI_HEIGHT, States.KPI_CAPTION_H, States.KPI_CAPTIONED_HEIGHT = KPI_HEIGHT, KPI_CAPTION_H, KPI_CAPTIONED_HEIGHT
-- The captioned pair's top on the Stop! body (under STOP) and on the waiting body (under its title).
local STOP_KPI_Y, WAITING_KPI_Y = 56, 40
States.STOP_KPI_Y, States.WAITING_KPI_Y = STOP_KPI_Y, WAITING_KPI_Y
-- Every button is LootHistory's 20px; Arm alone is a little taller, the one action of the idle body.
local BUTTON_HEIGHT = 20
local LINK_HEIGHT = 20
-- A row of equal buttons across the foot (the result card's four, the Stop! and waiting screens'
-- two): each the same width, worked out from the body's width and this gap (Round C, 2026-10-25).
-- At the minimum width's 236 px of content four are 56 px wide, room for "New Race": 48 px at the
-- 6 px a character textWidth estimates (the owner's call, 2026-10-28: "Race Again", 60 px, overflowed).
local ROW_GAP = 4
States.ROW_GAP = ROW_GAP
local GAP = 8
-- What sits under the captioned pair: the Stop! body's chips and its note one chip line (28) under
-- them, and the waiting body's hint box.
local STOP_CHIPS_Y = STOP_KPI_Y + KPI_CAPTIONED_HEIGHT + GAP
local STOP_NOTE_Y = STOP_CHIPS_Y + 28
local WAITING_HINT_Y = WAITING_KPI_Y + KPI_CAPTIONED_HEIGHT + GAP
States.STOP_CHIPS_Y, States.STOP_NOTE_Y, States.WAITING_HINT_Y = STOP_CHIPS_Y, STOP_NOTE_Y, WAITING_HINT_Y
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
-- THE HEADINGS (Round C, 2026-10-25): *Damage profile* over the pace bar and the plot, and *Spell
-- breakdown* over the rows, in the Results detail's heading role (FONT.SECTION on SECTION_H). The
-- clear space above each is the shared SECTION_GAP, less the GAP the block above already leaves.
local SECTION_H = Style.SECTION_H
local HEAD_GAP = Style.SECTION_GAP - GAP
-- The pace bar's line under the profile heading, its gap to the plot included.
local PACE_GAP = 4
-- The Spell breakdown heading's whole height, the space above it included.
local BREAKDOWN_H = HEAD_GAP + SECTION_H
States.HEAD_GAP, States.PACE_GAP, States.BREAKDOWN_H = HEAD_GAP, PACE_GAP, BREAKDOWN_H
-- The preset race lengths (spec §4.1), then Custom.
States.PRESETS = { 30, 60, 120, 180, 300 }
local DASH = "\226\128\148"   -- an em dash: "no figure"

local function act(name, ...)
    local fn = NS.Hud and NS.Hud.Act and NS.Hud.Act[name]
    if fn then return fn(...) end
end

-- ── widgets ─────────────────────────────────────────────────────────────────────────────────────

local function paintText(fs, c)
    Style.Paint(fs, c)
end

--- A label in one of the shared font objects (modules/Style.lua), recolored when `color` is given.
--- Unlike Style.Text it may wrap: a body's notes run to two lines at the minimum width.
local function text(parent, font, color, justify)
    local fs = Style.Text(parent, font, color, justify)
    fs:SetWordWrap(true)
    return fs
end

-- A race clock or STOP: the one label kept in its own monospace face and size (modules/Style.lua),
-- the skin's `font.mono` (Ka0s Default's JetBrains Mono, the shipped face), drawn again on a skin
-- change. Its color is the race's meaning, a live table the body tints it with on every draw.
local bigTexts = setmetatable({}, { __mode = "k" })   -- fs -> its size

local function monoFace()
    local name = NS.Skin.Token("font.mono")
    return (type(name) == "string" and NS.MediaFont and NS.MediaFont(name))
        or (NS.Constants and NS.Constants.FONT_MONO) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

Style.OnLooks(function()
    local face = monoFace()
    for fs, size in pairs(bigTexts) do fs:SetFont(face, size, "") end
end)

-- `styled`: a clock a HUD Appearance block restyles (the running body's), whose face is the
-- player's from its first draw and never the skin's.
local function bigText(parent, size, color, styled)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(monoFace(), size, "")
    if not styled then bigTexts[fs] = size end
    fs:SetTextColor(Style.Rgb(color))
    fs:SetJustifyH("CENTER")
    return fs
end

--- A flat box through the skin: its Panel, or with `kind` its Card (a KPI, the target card) or its
--- Inset (the detail's strip), the slots remapped to `tokens` (default BOX).
local function panel(parent, tokens, kind)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local paint = kind == "card" and NS.Skin.Card or kind == "inset" and NS.Skin.Inset or NS.Skin.Panel
    paint(f, { tokens = tokens or BOX })
    return f
end
States.Panel = panel

-- Paint `b` through the skin's Button for its style and state, only when either moved: the
-- library records the call and follows the hover and the enabled state itself.
local function paintButton(b)
    local on = b:IsEnabled() and true or false
    local key = (b.selected and "sel" or b.styleName) .. (on and ":on" or ":off")
    if b.painted == key then return end
    b.painted = key
    local s = b.selected and SELECTED or b.style
    NS.Skin.Button(b, { primary = b.style.primary and not b.selected, tokens = on and s.on or s.off })
end

local function setHot(b, on)
    b.hot = on
end

-- A button's tooltip (b.tip = { title, text, ... }), shown under the pointer, disabled or not. The
-- text is in the header gold (the client's normal tooltip color, NORMAL_FONT_COLOR); two or more
-- lines of it go on bullets (Style).
local function showTip(b)
    local tip = b.tip
    if not (tip and GameTooltip) then return end
    if type(tip) ~= "table" then tip = { tostring(tip) } end
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    GameTooltip:SetText(tip[1], Style.Rgb("gtip.value"))
    Style.AddTipLines(GameTooltip, tip, 2, Style.Rgb("gtip.title"))
    GameTooltip:Show()
end

--- A flat button: a label, a style, and a click that a disabled button never runs. Its label is
--- the skin's button text in the body face (GameFontHighlightSmall's size, `font` another's) and
--- turns the hover color under the pointer (LootHistory's bar button, the skin's Button).
local function button(parent, label, onClick, style, font)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetHeight(BUTTON_HEIGHT)
    b.styleName = style or "normal"
    b.style = BUTTON_STYLES[b.styleName]
    b.label = Style.PlainText(b, font or FONT.TEXT, "CENTER")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetText(label)
    b.text = b.label   -- the label the skin's Button paints (its `btn.text`)
    b:SetScript("OnClick", function(self)
        if self:IsEnabled() then onClick(self) end
    end)
    b:SetScript("OnEnter", function(self)
        setHot(self, true)
        showTip(self)
    end)
    b:SetScript("OnLeave", function(self)
        setHot(self, false)
        if self.tip and GameTooltip then GameTooltip:Hide() end
    end)
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

--- A figure in a box: a small caption and a large value (LootHistory's Insights card: a
--- GameFontNormalHuge figure over a GameFontDisableSmall caption). A `captioned` box is
--- KPI_CAPTIONED_HEIGHT tall, with a row under the value in the caption font (k.caption).
local function kpi(parent, label, valueColor, captioned)
    local f = panel(parent, nil, "card")
    f:SetHeight(captioned and KPI_CAPTIONED_HEIGHT or KPI_HEIGHT)
    local k = { frame = f }
    k.label = Style.Text(f, FONT.CAPTION)
    k.label:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
    k.label:SetText(label)
    -- A figure the Live figures block styles (`valueColor` false: the running body's) is a plain
    -- label the skin never paints; every other is the skin's.
    if valueColor == false then k.value = Style.PlainText(f, FONT.FIGURE)
    else k.value = Style.Text(f, FONT.FIGURE, valueColor or C.text) end
    k.value:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, KPI_PAD + (captioned and KPI_CAPTION_H or 0))
    if captioned then
        k.caption = Style.Text(f, FONT.CAPTION)
        k.caption:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, KPI_PAD)
        k.caption:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, KPI_PAD)
    end
    return k
end

local function setKpi(k, value, caption)
    k.value:SetText(value)
    if k.caption then k.caption:SetText(caption or "") end
end

--- Two KPIs side by side at `y`, halves by anchor (no width needed); `captioned` gives both the
--- caption row, so the pair keeps one height. `rightColor` false: both figures are the Live figures
--- block's (kpi).
local function kpiPair(parent, y, leftLabel, rightLabel, rightColor, captioned)
    local a = kpi(parent, leftLabel, rightColor == false and false or nil, captioned)
    local b = kpi(parent, rightLabel, rightColor, captioned)
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
-- The result card's stack sits under the chips it draws (Chips:Bottom) and above its row of buttons.
-- RESULT_ROWS_TOP is the most room they take, two lines: the lost line's place and the minimum height.
local RESULT_ROWS_TOP = KPI_HEIGHT + GAP + 2 * (CHIP_HEIGHT + CHIP_GAP) + 4
local RESULT_ROWS_BOTTOM = LINK_HEIGHT + GAP

local function newChip(parent)
    local f = Style.FlatBox(parent)
    f:SetHeight(CHIP_HEIGHT)
    f.label = Style.Text(f, FONT.TEXT, C.text, "CENTER")
    f.label:SetPoint("CENTER", f, "CENTER", 0, 0)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if not self.tip or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local r, g, b = Style.Rgb("gtip.value")
        GameTooltip:SetText(self.tip, r, g, b, 1, true)
        for _, line in ipairs(self.tipLines or {}) do GameTooltip:AddLine(line[1], line[2], line[3], line[4], true) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    -- A chip with a menu (the late casts', #8) opens it on a right-click.
    f:SetScript("OnMouseUp", function(self, mouse)
        if mouse == "RightButton" and self.menu then self.menu(self) end
    end)
    return f
end

local Chips = {}
Chips.__index = Chips

local function chips(parent, y)
    return setmetatable({ parent = parent, y = y, pool = NS.Pool.New(), width = 260, shown = {}, lines = 0 },
        Chips)
end

--- Lay out `list` ({ text, color, tip, tipLines?, menu? }) left to right, wrapping at the body's width.
--- `tipLines` follow the tip ({ text, r, g, b }); `menu(chip)` opens on a right-click.
function Chips:Set(list)
    NS.Pool.ReleaseAll(self.pool)
    self.shown = {}
    self.lines = 0
    local x, y, parent = 0, self.y, self.parent
    for i, item in ipairs(list or {}) do
        local chip = NS.Pool.Acquire(self.pool, function() return newChip(parent) end)
        local s, c = item.text, item.color or C.text
        chip.label:SetText(s)
        paintText(chip.label, c)
        Style.TintBox(chip, c, Style.CHIP_EDGE_A)
        -- Set on every acquire, nil included: a pooled chip never keeps the last item's menu.
        chip.tip, chip.text, chip.tipLines, chip.menu = item.tip, s, item.tipLines, item.menu
        local w = math.floor(textWidth(chip.label, s) + 14)
        if x > 0 and x + w > self.width then x, y = 0, y - CHIP_HEIGHT - CHIP_GAP end
        self.lines = math.floor((self.y - y) / (CHIP_HEIGHT + CHIP_GAP) + 0.5) + 1
        chip:SetWidth(w)
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        x = x + w + CHIP_GAP
        self.shown[i] = chip
    end
end

--- How far below the body's top the chips end, plus the GAP under them, as the running body's KPI
--- boxes leave theirs (body.kpiBottom); with no chip, the GAP under the row's top. Config only.
--- @return number
function Chips:Bottom()
    local n = self.lines
    local h = n > 0 and n * CHIP_HEIGHT + (n - 1) * CHIP_GAP + GAP or 0
    return -self.y + h
end

--- The chip texts drawn now, in order (the suites read these).
function Chips:Texts()
    local out = {}
    for i, chip in ipairs(self.shown) do out[i] = chip.text end
    return out
end

-- ── the target card ─────────────────────────────────────────────────────────────────────────────

local CARD_HEIGHT = 46

local function targetCard(parent, y)
    local f = panel(parent, nil, "card")
    f:SetHeight(CARD_HEIGHT)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    local card = { frame = f }
    card.name = Style.Text(f, FONT.HEADING)
    card.name:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
    card.name:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -7)
    card.badge = panel(f, { bg = "dr.callout.badge", border = "dr.callout.borderStrong" })
    card.badge:SetHeight(16)
    card.badge:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 6)
    card.badgeText = Style.Text(card.badge, FONT.TEXT, C.amber, "CENTER")
    card.badgeText:SetPoint("CENTER", card.badge, "CENTER", 0, 0)
    card.npc = Style.Text(f, FONT.CAPTION, nil, "RIGHT")
    card.npc:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
    return card
end

local function setTarget(card, target)
    target = target or {}
    card.name:SetText(target.name or L["No target"])
    local badge = NS.Dummies.Label(NS.Dummies.CategoryOf(target))
    card.badgeText:SetText(badge)
    card.badge:SetWidth(math.floor(textWidth(card.badgeText, badge) + 12))
    card.npc:SetText(type(target.npcID) == "number" and ("#%d"):format(target.npcID) or "")
end

-- ── bodies ──────────────────────────────────────────────────────────────────────────────────────

local function newBody(parent, key)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:Hide()
    return { key = key, frame = f, w = {} }
end

--- The equal buttons' width and the first one's left edge for `n` across `width` with ROW_GAP
--- between two: whole pixels, every button the same width, the odd pixels split either side. Plain
--- config math on the width Layout handed the body.
--- @param width number
--- @param n number
--- @return number each, number x0
function States.RowWidths(width, n)
    local each = math.max(1, math.floor((width - (n - 1) * ROW_GAP) / n))
    local spare = width - n * each - (n - 1) * ROW_GAP
    return each, math.max(0, math.floor(spare / 2))
end

-- Lay `buttons` out across the foot of `f`, all the same width (States.RowWidths).
local function layoutRow(buttons, f, width)
    local each, x = States.RowWidths(width, #buttons)
    for _, b in ipairs(buttons) do
        b:ClearAllPoints()
        b:SetSize(each, LINK_HEIGHT)
        b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 0)
        x = x + each + ROW_GAP
    end
end

-- A row of equal buttons across the foot of the body ({ label, onClick, style, tip }), laid out at
-- the minimum width until Layout hands the body its own.
local function footerButtons(body, specs)
    local f, out = body.frame, {}
    for i, spec in ipairs(specs) do
        local b = button(f, spec[1], spec[2], spec[3])
        b.tip = spec.tip
        out[i] = b
    end
    body.footer = out
    layoutRow(out, f, 236)
    return out
end

local function wideButton(body, label, onClick, style, height, font)
    local b = button(body.frame, label, onClick, style, font)
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
    NS.Skin.EditBox(w.customBox, { padInput = false })
    w.customBox:SetJustifyH("CENTER")
    w.customBox:SetMaxLetters(6)
    w.customBox:SetScript("OnEnterPressed", function(self) act("customLength", self:GetText()) end)
    w.customBox:SetScript("OnEscapePressed", function() act("closeCustom") end)
    w.customBox:Hide()
    w.targetCap = caption(f, L["Target"], -IDLE_TARGET_Y)
    w.card = targetCard(f, -IDLE_CARD_Y)
    w.warn = text(f, FONT.TEXT, C.amber)
    w.warn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -IDLE_WARN_Y)
    w.warn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -IDLE_WARN_Y)
    w.arm = wideButton(body, L["Arm Race"], function() act("arm") end, "primary", ARM_HEIGHT, FONT.TITLE)
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
        setTarget(self.w.card, v.target)
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
        setTarget(self.w.card, run.target)
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

-- The pace bar's line under the profile heading, or 0 without one.
local function paceLine(pace)
    return pace and (NS.HudChart.PACE_H + PACE_GAP) or 0
end

--- The Damage profile block's height: the space above its heading, the heading, the pace bar's line,
--- the plot (its frame, with the icons' row on top) and its time labels, and the GAP under it; 0 when neither the pace bar nor the plot shows.
--- @param pace boolean
--- @param chart boolean
--- @param plotH number
--- @return number
function States.ProfileHeight(pace, chart, plotH)
    if not (pace or chart) then return 0 end
    local Chart = NS.HudChart
    local h = HEAD_GAP + SECTION_H + paceLine(pace)
    if chart then h = h + Chart.FrameHeight(plotH) + Chart.GAP + Chart.AXIS_H end
    return h + GAP
end
local profileH = States.ProfileHeight

-- Place the stack under `top` (Round C): the Damage profile heading, the pace bar directly under it,
-- the plot and its time labels, then the Spell breakdown heading and the rows. Every offset is config.
-- Answers the rows' top.
local function placeStack(body, top, pace, chart, plotH)
    local w, f, width = body.w, body.frame, body.width or 236
    local head = pace or chart
    w.chart:SetParts(head, chart)
    -- No plot, no Draw: the note names the pace bar alone (it has no caption of its own).
    if not chart then w.chart:SetNote(pace and L["vs best pace"] or "") end
    if head then
        local y = top + HEAD_GAP
        w.chart:Place(f, -y, width, plotH, paceLine(pace))
        if pace then w.pace:Place(f, -(y + SECTION_H), width) end
    end
    local y = top + profileH(pace, chart, plotH) + HEAD_GAP
    w.spellsTitle:ClearAllPoints()
    w.spellsTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
    return y + SECTION_H
end

-- Whether the stack's inputs changed since it was last placed, noting them when they did: compared
-- field by field into one reused table, so the 20 Hz tick builds no key.
local function restack(body, top, paceH, chart, plotH)
    local last = body.placed
    if last and last.top == top and last.paceH == paceH and last.chart == chart and last.plotH == plotH
        and last.width == body.width and last.height == body.height then
        return false
    end
    last = last or {}
    last.top, last.paceH, last.chart, last.plotH = top, paceH, chart, plotH
    last.width, last.height = body.width, body.height
    body.placed = last
    return true
end

-- THE PACE BAR AND THE CHART (#3, #2) sit between the KPIs and the spell rows, under the Damage
-- profile heading, each only when its view is given (modules/Hud_Chart.lua LiveViews); the plot steps
-- aside when it would leave fewer than MIN_ROWS rows, the heading staying with the pace bar. Placed
-- again only when what decides the stack changed: every input is config.
local function placeExtras(body, v)
    local w, f = body.w, body.frame
    local top = body.kpiBottom or RUNNING_ROWS_TOP
    local pace = v.pace ~= nil
    local plotH = NS.HudChart.PlotHeight()
    local chart = v.chart ~= nil
        and roomForRows(body, top + profileH(pace, true, plotH) + BREAKDOWN_H, RUNNING_ROWS_BOTTOM)
    w.pace:SetShown(pace)
    body.chartView = chart and v.chart or nil
    if not restack(body, top, paceLine(pace), chart, plotH) then return end
    local y = placeStack(body, top, pace, chart, plotH)
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
    w.clock = bigText(f, BIG, C.red, true)
    w.clock:SetPoint("TOP", f, "TOP", 0, -4)
    -- "both": elapsed (green) in the left half, time left (red) in the right, a caption under each.
    -- Halves by anchor, as the KPI pair below: no width is read.
    w.elapsed = bigText(f, CLOCK_PAIR, C.green, true)
    w.elapsed:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -6)
    w.elapsed:SetPoint("TOPRIGHT", f, "TOP", -4, -6)
    w.left = bigText(f, CLOCK_PAIR, C.red, true)
    w.left:SetPoint("TOPLEFT", f, "TOP", 4, -6)
    w.left:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -6)
    w.elapsedCap = Style.Text(f, FONT.CAPTION, nil, "CENTER")
    w.elapsedCap:SetPoint("TOP", w.elapsed, "BOTTOM", 0, -3)
    w.elapsedCap:SetText(L["Elapsed"])
    w.leftCap = Style.Text(f, FONT.CAPTION, nil, "CENTER")
    w.leftCap:SetPoint("TOP", w.left, "BOTTOM", 0, -3)
    w.leftCap:SetText(L["Left"])
    w.damage, w.dps = kpiPair(f, -52, L["Damage"], L["DPS \194\183 Live"], false)
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
    w.spellsTitle = Style.Text(f, FONT.SECTION)
    w.spellsTitle:SetText(L["Spell breakdown"])
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
        if v.pace then self.w.pace:SetRange(v.pace.lo, v.pace.hi) end
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

-- The two figures the stop and waiting bodies share, each with its caption row (the owner's call,
-- 2026-10-28): the tail ("+9.4s", after buzzer) or the time in combat at an early end (into the
-- race), and the time in combat since the buzzer (since the buzzer), or a dash once combat is over
-- (combat ended). Plain numbers from GetTime(), never a meter value; the unit joins the figure's string.
local function setStopFigures(w, v)
    if v.endedEarly then
        w.tail.label:SetText(L["Combat Ended"])
        setKpi(w.tail, NS.Format.Length(v.endedAt or 0), L["into the race"])
    else
        w.tail.label:SetText(L["Damage Stopped"])
        setKpi(w.tail, NS.Format.Seconds(v.tail) .. L["s"], L["after buzzer"])
    end
    if v.inCombat then
        w.combat.label:SetText(L["In Combat"])
        setKpi(w.combat, NS.Format.Seconds(v.sinceBuzzer or 0) .. L["s"], L["since the buzzer"])
    else
        w.combat.label:SetText(L["Out of Combat"])
        setKpi(w.combat, DASH, L["combat ended"])
    end
end

-- The Stop! and waiting screens' two buttons (Round C, 2026-10-25), the same width across the foot:
-- Stop Now takes the result as it reads now (Race.StopNow), Cancel discards the run (Race.Cancel). In
-- test mode the sim's (modules/Hud.lua Act). Neither is a protected call: both work in combat.
local function stopButtons(body)
    local links = footerButtons(body, {
        { L["Stop Now"], function() act("stopNow") end, "primary",
          tip = { L["Stop Now"], L["Take the result now instead of waiting out the damage tail. Out of combat it is read at once; in combat it is read the moment combat ends, and damage up to then counts."] } },
        { L["Cancel"], function() act("cancel") end, "danger",
          tip = { L["Cancel"], L["Discard this race. Nothing is saved."] } },
    })
    body.w.stopNow, body.w.cancel = links[1], links[2]
end

-- How many of the race's late casts so far count (the ignore list's are left out, #8) and the first
-- counted one's offset. Filtered here rather than in modules/Hud.lua: test mode's and the sim's STOP
-- view (modules/MockRuns.lua) hands its raw list straight to this body.
local function countedLate(list)
    local set, n, first = NS.LateIgnore.Set(), 0, nil
    for _, cast in ipairs(type(list) == "table" and list or {}) do
        if not NS.LateIgnore.IsIgnored(cast.spellID, set) then
            n = n + 1
            first = first or cast.t
        end
    end
    return n, first or 0
end

-- STOP: the buzzer, the tail updating live, late casts so far, the grace (screen 05).
function Builders.stop(parent)
    local body = newBody(parent, "stop")
    local f, w = body.frame, body.w
    w.big = bigText(f, BIG + 8, C.red)
    w.big:SetPoint("TOP", f, "TOP", 0, -2)
    w.big:SetText(L["STOP"])
    w.tail, w.combat = kpiPair(f, -STOP_KPI_Y, L["Damage Stopped"], L["In Combat"], nil, true)
    w.chips = chips(f, -STOP_CHIPS_Y)
    w.note = text(f, FONT.TEXT, C.dim)
    w.note:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -STOP_NOTE_Y)
    w.note:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -STOP_NOTE_Y)
    stopButtons(body)
    function body.Layout(self, width)
        self.w.chips.width = width
        self.shownKey = nil   -- the chips wrap at the new width on the next redraw
        layoutRow(self.footer, self.frame, width)
    end
    function body.Update(self, v)
        setStopFigures(self.w, v)
        setEnabled(self.w.stopNow, v.stopNow ~= true)
        -- Redrawn at 4 Hz while combat may hold for minutes: the chips and the note are rebuilt
        -- only when what they say (the counted late casts, the grace) changed.
        local late, first = countedLate(v.lateCasts)
        local grace = v.grace or 0
        local key = ("%d|%.1f|%.1f"):format(late, first, grace)
        if key == self.shownKey then return end
        self.shownKey = key
        local list = {}
        if late == 1 then
            list[1] = { text = L["1 late cast \194\183 +%.1fs"]:format(first), color = C.amber }
        elseif late > 1 then
            list[1] = { text = L["%d late casts \194\183 +%.1fs"]:format(late, first), color = C.amber }
        end
        list[#list + 1] = { text = L["Grace %.1fs"]:format(grace), color = C.info }
        self.w.chips:Set(list)
        self.w.note:SetText(L["Damage still landing (DoTs, travel time) counts. Casts that start more than %.1fs after the buzzer are flagged on the result."]:format(grace))
    end
    return body
end

-- The waiting body's hint box (the owner's call, 2026-10-26: the fixed 64 px left an empty band
-- under three lines): its text's lines at the box's inner width, HINT_PADY above and below. The
-- lines are estimated, never measured: a greedy word wrap at HINT_ADVANCE px a character (the
-- Results detail's estimate for the same font, a little over its real average, so a line too many
-- rather than one too few), each line FONT.TEXT's HINT_LINE_H.
local HINT_PADX, HINT_PADY = 8, 6
local HINT_ADVANCE, HINT_LINE_H = 5.4, 12
States.HINT_PADY, States.HINT_LINE_H = HINT_PADY, HINT_LINE_H

--- How many lines `s` wraps to in `width` pixels at HINT_ADVANCE a character (plain copy, config math).
--- @param s string
--- @param width number
--- @return number
function States.HintLines(s, width)
    local perLine = math.max(1, math.floor(width / HINT_ADVANCE))
    local lines, len = 1, 0
    for word in tostring(s):gmatch("%S+") do
        local n = #word
        if len == 0 then
            len = n
        elseif len + 1 + n <= perLine then
            len = len + 1 + n
        else
            lines, len = lines + 1, n
        end
    end
    return lines
end

--- The hint box's height for `s` across a body `width` wide: its lines and the padding above and below.
--- @param s string
--- @param width number
--- @return number
function States.HintHeight(s, width)
    return States.HintLines(s, width - 2 * HINT_PADX) * HINT_LINE_H + 2 * HINT_PADY
end

-- WAITING: combat is holding; the hint, Stop Now and Cancel (screen 06; Round C).
function Builders.waiting(parent)
    local body = newBody(parent, "waiting")
    local f, w = body.frame, body.w
    w.title = Style.Text(f, FONT.TITLE, nil, "CENTER")
    w.title:SetPoint("TOP", f, "TOP", 0, -10)
    w.tail, w.combat = kpiPair(f, -WAITING_KPI_Y, L["Damage Stopped"], L["In Combat"], nil, true)
    w.hint = panel(f, { bg = "dr.callout.bg", border = "dr.callout.border" })
    w.hint:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -WAITING_HINT_Y)
    w.hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -WAITING_HINT_Y)
    w.hintText = text(w.hint, FONT.TEXT, Style.Tok("dr.callout.text"))
    w.hintText:SetPoint("TOPLEFT", w.hint, "TOPLEFT", HINT_PADX, -HINT_PADY)
    w.hintText:SetPoint("TOPRIGHT", w.hint, "TOPRIGHT", -HINT_PADX, -HINT_PADY)
    w.hintText:SetJustifyV("TOP")
    stopButtons(body)
    body.width = 236
    -- The hint box sized to its text at the body's width (States.HintHeight), never read off the label.
    function body.SizeHint(self)
        self.w.hint:SetHeight(States.HintHeight(self.hintShown or "", self.width))
    end
    function body.Layout(self, width)
        self.width = width
        layoutRow(self.footer, self.frame, width)
        self:SizeHint()
    end
    function body.Update(self, v)
        local title = L["Waiting for combat to end"]
        if not v.inCombat then
            title = L["Reading the result"]
        elseif v.stopNow then
            title = L["Reading when combat ends"]
        end
        self.w.title:SetText(title)
        setStopFigures(self.w, v)
        setEnabled(self.w.stopNow, v.stopNow ~= true)
        self.w.hint:SetShown(v.hint ~= nil)
        self.w.hintText:SetText(v.hint or "")
        if v.hint ~= self.hintShown then
            self.hintShown = v.hint
            self:SizeHint()
        end
    end
    return body
end

-- A flag's short chip label (the full text is its tooltip), from the run and its flag (the late
-- casts' count is the counted ones, Scoring.Flags).
local FLAG_CHIP = {
    lateCasts = function(_, flag)
        local n = flag.count
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

--- A run's flags as the result card's chips draw them: { text = the short label, tip = the full text },
--- in Scoring.Flags' order (the new-best toast's second line reads them too, modules/BestToast.lua).
--- @param run table
--- @return table chips
function States.FlagChips(run)
    local list = {}
    for _, flag in ipairs(NS.Scoring.Flags(run, NS.HudBreakdown.SpellName)) do
        local skip = flag.key == "died" and run.status == "incomplete"
        local short = FLAG_CHIP[flag.key]
        if short and not skip then list[#list + 1] = { key = flag.key, text = short(run, flag), tip = flag.text } end
    end
    return list
end

--- The amber the flag chips draw in, for a caller drawing them elsewhere.
States.FLAG_COLOR = C.amber

-- The late casts' right-click and tooltip lines on the result card (#8): the menu (none on the
-- test-mode card, D-7), the ignored casts dimmed and the hint. `lines` is nil with neither.
local function lateExtras(v)
    local LI, run, lines = NS.LateIgnore, v.run, {}
    local menu = v.preview ~= true and LI.Offers(run) and function(owner) LI.Menu(run, owner) end or nil
    local ignored = NS.Scoring.IgnoredText(run, NS.HudBreakdown.SpellName)
    if ignored then lines[#lines + 1] = { ignored, Style.Rgb(C.dim) } end
    if menu then lines[#lines + 1] = { L["Right-click to ignore a spell for late casts, or count it again."], Style.Rgb(C.dim) } end
    return menu, lines[1] and lines or nil
end

-- Every late cast ignored: no flag, a gray "N ignored" chip in its place that keeps the tooltip and
-- the undo (D-6). Here and not in FlagChips, which the new-best toast reads too.
local function ignoredChip(run, menu, lines)
    local _, ignored = NS.Scoring.SplitLate(run)
    if #ignored == 0 then return nil end
    return { text = L["%d ignored"]:format(#ignored), color = C.dim, menu = menu, tipLines = lines,
             tip = L["Late casts on the ignore list: they flag nothing."] }
end

--- The result card's chips: the best delta, the flags, the tail (spec §6.1).
function States.ResultChips(v)
    local run, list = v.run, {}
    if v.isNew then
        list[1] = { text = v.delta and L["New best +%.1f%%"]:format(v.delta) or L["New best"], color = C.green }
    elseif v.delta then
        list[1] = { text = L["%+.1f%% vs best"]:format(v.delta), color = C.red }
    end
    local menu, lines = lateExtras(v)
    local flags = States.FlagChips(run)
    if not (flags[1] and flags[1].key == "lateCasts") then list[#list + 1] = ignoredChip(run, menu, lines) end
    for _, chip in ipairs(flags) do
        local late = chip.key == "lateCasts"
        list[#list + 1] = { text = chip.text, color = C.amber, tip = chip.tip,
                            menu = late and menu or nil, tipLines = late and lines or nil }
    end
    -- The run's time: the length and the DoT tail, or the time in combat before the buzzer.
    if run.status ~= "lost" and type(run.result) == "table" then
        list[#list + 1] = { text = L["Time %s"]:format(NS.Format.RunTime(run)), color = C.info,
                            tip = L["The race length, then how long your damage kept landing after the buzzer (DoTs, travel time). An incomplete run shows its time in combat against the length."] }
    end
    return list
end

-- RESULT: damage, DPS, the delta and flag chips, the top spells with %, and the four acts (screen 07).
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
    w.pace = NS.HudChart.NewPace(f)
    w.pace:SetShown(false)
    w.chart = NS.HudChart.New(f)
    w.chart:SetShown(false)
    w.spellsTitle = Style.Text(f, FONT.SECTION)
    w.spellsTitle:SetText(L["Spell breakdown"])
    -- live.rows 0: every spell, the wheel moving the slice, as on the running body.
    w.rows:EnableMouseWheel(true)
    w.rows:SetScript("OnMouseWheel", function(_, delta)
        if body.rowsSetting ~= 0 or not body.shownRun then return end
        body.offset = (body.offset or 0) + (delta > 0 and -1 or 1)
        body:DrawRows()
    end)
    -- The four acts in one row, the same width each (Round C): Delete asks first (the Results
    -- window's own confirmation, modules/Hud.lua Act.delete).
    local links = footerButtons(body, {
        { L["New Race"], function() act("newRace") end, "primary" },
        { L["Details"], function() act("details") end },
        { L["Share"], function() act("share") end },
        { L["Delete"], function() act("delete") end, "danger",
          tip = { L["Delete"], L["Remove this run from history, after a confirmation. A best it holds goes with it."] } },
    })
    w.newRace, w.details, w.share, w.delete = links[1], links[2], links[3], links[4]
    -- The sample card of test mode has no run to start a new race from, open or delete (modules/Hud.lua Act).
    w.realOnly = { w.newRace, w.details, w.delete }
    function body.Layout(self, width, height)
        self.w.chips.width = width
        self.width, self.height = width, height
        layoutRow(self.footer, self.frame, width)
    end
    function body.Update(self, v)
        -- The chips first: the stack under them starts where they end.
        self.w.chips:Set(States.ResultChips(v))
        Builders.resultExtras(self, v)
        local run = v.run or {}
        local result = run.result or {}
        local lost = run.status == "lost"
        setKpi(self.w.damage, lost and DASH or NS.Format.Number(result.damage or 0))
        setKpi(self.w.dps, lost and DASH or NS.Format.Number(result.dps or 0))
        self.w.lost:SetText(lost and L["Couldn't read the result"] or "")
        self.w.spellsTitle:SetShown(not lost)
        if v.run ~= self.shownRun then self.offset = 0 end
        self.shownRun, self.rowsSetting, self.icons = (not lost) and v.run or nil, v.rows, v.icons
        if lost then self.w.list:Clear() else self:DrawRows() end
        setEnabled(self.w.share, v.canShare == true)
        for _, b in ipairs(self.w.realOnly) do setEnabled(b, v.preview ~= true) end
    end
    function body.DrawRows(self) Builders.resultRows(self) end
    return body
end

-- The result card's spell rows follow *Spell rows shown* (live.rows), as the live list does: that many
-- from the top, or with 0 every spell, as many as fit and the wheel over the rest (the owner's call,
-- 2026-10-24; the spec's top 5 is the fallback when the setting cannot answer).
States.RESULT_ROWS = 5

-- The result card's pace bar (#3) and chart (#2), between the chips and the rows, under the Damage
-- profile heading as on the running body, then the Spell breakdown heading. The pace bar is the run's
-- plain final damage against the best before it (modules/Hud_Chart.lua ResultPace), the running bar's
-- widget, range and tick; it never steps aside, so MinContentHeight carries it. The chart is the run's
-- in-session slices, scaled to its plain final damage; none for a run without slices, and it steps
-- aside when it would leave fewer than MIN_ROWS rows. Every value here is plain (a stored run).
function Builders.resultExtras(body, v)
    local w, f = body.w, body.frame
    local pace = v.pace ~= nil
    local plotH = NS.HudChart.PlotHeight()
    local top = w.chips:Bottom()
    local on = v.chart ~= nil
        and roomForRows(body, top + profileH(pace, true, plotH) + BREAKDOWN_H, RESULT_ROWS_BOTTOM)
    w.pace:SetShown(pace)
    body.rowsTop = placeStack(body, top, pace, on, plotH)
    if pace then
        w.pace:SetRange(v.pace.lo, v.pace.hi)
        w.pace:SetValue(v.pace.value)
    end
    w.rows:ClearAllPoints()
    w.rows:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -body.rowsTop)
    w.rows:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, RESULT_ROWS_BOTTOM)
    if on then w.chart:Draw(v.chart) end
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
--- the running and result bodies (each with its pace bar under the Damage profile heading, then the
--- Spell breakdown heading) with MIN_ROWS spell rows. modules/Hud.lua sets its minimum from it.
--- @return number
function States.MinContentHeight()
    local B = NS.HudBreakdown
    local rows = MIN_ROWS * (B.ROW_HEIGHT + B.ROW_GAP) - B.ROW_GAP
    local idle = IDLE_ARM_Y + ARM_HEIGHT + 4 + REASON_HEIGHT + 4 + LINK_HEIGHT
    -- The pace bar never steps aside (the plot does), so the running and result minimums carry it
    -- with its heading.
    local stack = profileH(true, false, 0) + BREAKDOWN_H + rows
    local running = RUNNING_ROWS_TOP + stack + RUNNING_ROWS_BOTTOM
    local result = RESULT_ROWS_TOP + stack + RESULT_ROWS_BOTTOM
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
