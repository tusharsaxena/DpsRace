local _, NS = ...
-- modules/Hud_States.lua — the Race HUD's six bodies (spec §6.1, mockup screens 02-07): idle, armed,
-- running, stop, waiting and result. Each is built on first show into the HUD's content frame and
-- answers Update(view) (and the running body SetLive(live, rows, icons)); modules/Hud.lua owns the
-- shell, decides which body shows and builds the view.
--
-- LAYOUT FROM CONFIG. Every position is a constant offset or an anchor; the only width a body uses is
-- the one Layout(width) hands it, which modules/Hud.lua computes from the stored window size. No body
-- reads the size or position of anything that has displayed a meter value. The chip strips measure
-- their own text (GetStringWidth on a label that only ever holds plain copy), never a value.
--
-- A body's buttons call NS.Hud.Act.* at CALL time, so the act is the shell's and a test may drive it.

local States = {}
NS.HudStates = States

local L = NS.L

local C = {
    text  = { 0.93, 0.93, 0.95 },
    dim   = { 0.62, 0.62, 0.68 },
    gold  = { 1.0, 0.82, 0.0 },
    amber = { 1.0, 0.72, 0.29 },
    red   = { 1.0, 0.32, 0.32 },
    green = { 0.36, 0.86, 0.46 },
    info  = { 0.56, 0.72, 1.0 },
}
States.COLORS = C

local FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local PANEL_BG, PANEL_EDGE = { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.10 }
local BUTTON_STYLES = {
    normal  = { bg = { 1, 1, 1, 0.05 }, edge = { 1, 1, 1, 0.16 }, text = C.text },
    primary = { bg = { 1, 0.82, 0, 0.12 }, edge = { 1, 0.82, 0, 0.75 }, text = C.gold },
    danger  = { bg = { 1, 0.32, 0.32, 0.08 }, edge = { 1, 0.32, 0.32, 0.6 }, text = C.red },
}
local BIG = 40           -- the clock and STOP
local KPI_HEIGHT = 46
local BUTTON_HEIGHT = 26
local LINK_HEIGHT = 22
local GAP = 8
-- The preset race lengths (spec §4.1), then Custom.
States.PRESETS = { 30, 60, 120, 180, 300 }
local DASH = "\226\128\148"   -- an em dash: "no figure"

local function act(name, ...)
    local fn = NS.Hud and NS.Hud.Act and NS.Hud.Act[name]
    if fn then return fn(...) end
end

-- ── widgets ─────────────────────────────────────────────────────────────────────────────────────

local function fontPath(mono)
    if mono and NS.Constants and NS.Constants.FONT_MONO then return NS.Constants.FONT_MONO end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function paintText(fs, c)
    fs:SetTextColor(c[1], c[2], c[3])
end

local function text(parent, size, color, justify, mono)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(fontPath(mono), size, "")
    paintText(fs, color or C.text)
    fs:SetJustifyH(justify or "LEFT")
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
    local t = b.selected and C.gold or s.text
    b.label:SetTextColor(t[1], t[2], t[3], on and 1 or 0.4)
end

--- A flat button: a label, a style, and a click that a disabled button never runs.
local function button(parent, label, onClick, style)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    if b.SetBackdrop then b:SetBackdrop(FLAT) end
    b:SetHeight(BUTTON_HEIGHT)
    b.style = BUTTON_STYLES[style or "normal"]
    b.label = text(b, 11, b.style.text, "CENTER")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetText(label)
    b:SetScript("OnClick", function(self)
        if self:IsEnabled() then onClick(self) end
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

--- A figure in a box: a small caps label, a value and its unit.
local function kpi(parent, label, valueColor)
    local f = panel(parent)
    f:SetHeight(KPI_HEIGHT)
    local k = { frame = f }
    k.label = text(f, 9, C.dim)
    k.label:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
    k.label:SetText(label)
    k.value = text(f, 17, valueColor or C.text, "LEFT", true)
    k.value:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 6)
    k.unit = text(f, 10, C.dim)
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

local function caption(parent, label, y)
    local fs = text(parent, 9, C.dim)
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

local function newChip(parent)
    local f = panel(parent)
    f:SetHeight(CHIP_HEIGHT)
    f.label = text(f, 9, C.text, "CENTER")
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

local CARD_HEIGHT = 52

local function targetCard(parent, y, stepper)
    local f = panel(parent)
    f:SetHeight(CARD_HEIGHT)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    local card = { frame = f }
    card.name = text(f, 13, C.text)
    card.name:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
    card.name:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    card.badge = panel(f, { 1, 0.72, 0.29, 0.08 }, { 1, 0.72, 0.29, 0.6 })
    card.badge:SetHeight(16)
    card.badge:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 7)
    card.badgeText = text(card.badge, 9, C.amber, "CENTER")
    card.badgeText:SetPoint("CENTER", card.badge, "CENTER", 0, 0)
    card.meta = text(f, 11, C.dim)
    card.meta:SetPoint("LEFT", card.badge, "RIGHT", 8, 0)
    card.npc = text(f, 10, C.dim, "RIGHT", true)
    card.npc:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 9)
    if stepper then
        card.minus = button(f, "-", function() act("stepCount", -1) end)
        card.minus:SetSize(18, 18)
        card.minus:SetPoint("LEFT", card.meta, "RIGHT", 6, 0)
        card.count = text(f, 12, C.text, "CENTER", true)
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
    local badge = (NS.Dummies.Label(target.category or "other")):upper()
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

local Builders = {}

-- IDLE: length presets, the target card, Arm (spec §6.1; screen 02).
function Builders.idle(parent)
    local body = newBody(parent, "idle")
    local f, w = body.frame, body.w
    caption(f, L["RACE LENGTH"], 0)
    w.presets = {}
    for i, n in ipairs(States.PRESETS) do
        w.presets[i] = button(f, NS.Format.Length(n), function() act("pickLength", n) end)
        w.presets[i].length = n
    end
    w.custom = button(f, L["Custom"], function() act("openCustom") end)
    w.customBox = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    w.customBox:SetAutoFocus(false)
    w.customBox:SetFont(fontPath(true), 12, "")
    w.customBox:SetJustifyH("CENTER")
    w.customBox:SetMaxLetters(6)
    w.customBox:SetScript("OnEnterPressed", function(self) act("customLength", self:GetText()) end)
    w.customBox:SetScript("OnEscapePressed", function() act("closeCustom") end)
    w.customBox:Hide()
    caption(f, L["TARGET"], -84)
    w.card = targetCard(f, -98, true)
    w.warn = text(f, 10, C.amber)
    w.warn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -154)
    w.warn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -154)
    w.arm = wideButton(body, L["ARM RACE"], function() act("arm") end, "primary", 34)
    w.arm.label:SetFont(fontPath(), 14, "")
    w.arm:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -172)
    w.arm:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -172)
    w.reason = text(f, 10, C.amber, "CENTER")
    w.reason:SetPoint("TOPLEFT", w.arm, "BOTTOMLEFT", 0, -4)
    w.reason:SetPoint("TOPRIGHT", w.arm, "BOTTOMRIGHT", 0, -4)
    local links = footerButtons(body, {
        { L["LAST RESULT"], function() act("lastResult") end },
        { L["RESULTS"], function() act("results") end, width = 72 },
    })
    w.lastResult, w.results = links[1], links[2]

    function body.Layout(self, width)
        local cell = math.floor((width - 2 * 6) / 3)
        local grid = self.w.presets
        local all = { grid[1], grid[2], grid[3], grid[4], grid[5], self.w.custom }
        for i, b in ipairs(all) do
            local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
            b:ClearAllPoints()
            b:SetSize(cell, 28)
            b:SetPoint("TOPLEFT", self.frame, "TOPLEFT", col * (cell + 6), -14 - row * 34)
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
        setEnabled(self.w.lastResult, v.hasRuns == true)
    end
    return body
end

-- ARMED: the length, unmoving, and what starts the clock (screen 03).
function Builders.armed(parent)
    local body = newBody(parent, "armed")
    local f, w = body.frame, body.w
    w.clock = text(f, BIG, C.text, "CENTER", true)
    w.clock:SetPoint("TOP", f, "TOP", 0, -4)
    w.sub = text(f, 11, C.dim, "CENTER")
    w.sub:SetPoint("TOP", f, "TOP", 0, -52)
    w.sub:SetText(L["First hit starts the clock"])
    w.card = targetCard(f, -74, false)
    w.note = text(f, 11, C.dim)
    w.note:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -136)
    w.note:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -136)
    w.note:SetText(L["Pre-cast and pre-pot as you would on a pull. The clock starts when damage lands, not when you press the button."])
    w.cancel = wideButton(body, L["CANCEL"], function() act("cancel") end)
    w.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    w.cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    function body.Update(self, v)
        local run = v.run or {}
        self.w.clock:SetText(NS.Format.Clock(run.race and run.race.length or 0))
        setTarget(self.w.card, run.target, run.target and run.target.count)
    end
    return body
end

-- RUNNING: the countdown, live damage and DPS, the live breakdown with no % (screen 04).
function Builders.running(parent)
    local body = newBody(parent, "running")
    local f, w = body.frame, body.w
    w.clock = text(f, BIG, C.text, "CENTER", true)
    w.clock:SetPoint("TOP", f, "TOP", 0, -4)
    w.damage, w.dps = kpiPair(f, -52, L["DAMAGE"], L["DPS \194\183 LIVE"])
    w.rows = CreateFrame("Frame", nil, f)
    w.rows:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -52 - KPI_HEIGHT - GAP)
    w.rows:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, BUTTON_HEIGHT + 22)
    w.list = NS.HudBreakdown.New(w.rows)
    w.order = text(f, 9, C.dim)
    w.order:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, BUTTON_HEIGHT + 8)
    w.order:SetText(L["Live order \194\183 % after the race"])
    w.count = text(f, 9, C.dim, "RIGHT")
    w.count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, BUTTON_HEIGHT + 8)
    w.cancel = wideButton(body, L["CANCEL"], function() act("cancel") end)
    w.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    w.cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    function body.Update(self, v)
        local left = v.timeLeft or 0
        self.w.clock:SetText(NS.Format.Clock(left))
        paintText(self.w.clock, left <= 10 and C.amber or C.text)
        self.w.dps.frame:SetShown(v.showDps ~= false)
        self.w.count:SetText(L["%d rows"]:format(v.rows or 0))
    end

    --- The live figures: opaque values, straight to the formatter and the rows.
    function body.SetLive(self, live, rows, icons)
        if type(live) ~= "table" then
            setKpi(self.w.damage, DASH)
            setKpi(self.w.dps, DASH)
            self.w.list:Clear()
            return
        end
        setKpi(self.w.damage, NS.Format.Number(live.total))
        if live.dps == nil then setKpi(self.w.dps, DASH) else setKpi(self.w.dps, NS.Format.Number(live.dps)) end
        self.w.list:ShowLive(live, rows or 8, icons ~= false)
    end
    return body
end

-- The two figures the stop and waiting bodies share: the tail and the time in combat since the buzzer.
local function setStopFigures(w, v)
    if v.endedEarly then
        w.tail.label:SetText(L["COMBAT ENDED AT"])
        setKpi(w.tail, NS.Format.Length(v.endedAt or 0))
    else
        w.tail.label:SetText(L["DAMAGE STOPPED"])
        setKpi(w.tail, NS.Format.Seconds(v.tail), v.unitTail)
    end
    if v.inCombat then
        w.combat.label:SetText(L["IN COMBAT"])
        setKpi(w.combat, NS.Format.Seconds(v.sinceBuzzer or 0), L["s"])
    else
        w.combat.label:SetText(L["OUT OF COMBAT"])
        setKpi(w.combat, DASH)
    end
end

-- STOP: the buzzer, the tail updating live, late casts so far, the grace (screen 05).
function Builders.stop(parent)
    local body = newBody(parent, "stop")
    local f, w = body.frame, body.w
    w.big = text(f, BIG + 8, C.red, "CENTER")
    w.big:SetPoint("TOP", f, "TOP", 0, -2)
    w.big:SetText(L["STOP"])
    w.tail, w.combat = kpiPair(f, -56, L["DAMAGE STOPPED"], L["IN COMBAT"])
    w.chips = chips(f, -56 - KPI_HEIGHT - GAP)
    w.note = text(f, 11, C.dim)
    w.note:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -56 - KPI_HEIGHT - GAP - 28)
    w.note:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -56 - KPI_HEIGHT - GAP - 28)
    function body.Layout(self, width) self.w.chips.width = width end
    function body.Update(self, v)
        v.unitTail = L["s after buzzer"]
        setStopFigures(self.w, v)
        local list, late = {}, v.lateCasts or {}
        if #late == 1 then
            list[1] = { text = L["1 late cast \194\183 +%.1fs"]:format(late[1].t or 0), color = C.amber }
        elseif #late > 1 then
            list[1] = { text = L["%d late casts \194\183 +%.1fs"]:format(#late, late[1].t or 0), color = C.amber }
        end
        list[#list + 1] = { text = L["Grace %.1fs"]:format(v.grace or 0), color = C.info }
        self.w.chips:Set(list)
        self.w.note:SetText(L["Damage still landing (DoTs, travel time) counts. Casts that start more than %.1fs after the buzzer are flagged on the result."]:format(v.grace or 0))
    end
    return body
end

-- WAITING: combat is holding; the hint, discard, close and keep waiting (screen 06).
function Builders.waiting(parent)
    local body = newBody(parent, "waiting")
    local f, w = body.frame, body.w
    w.title = text(f, 16, C.text, "CENTER")
    w.title:SetPoint("TOP", f, "TOP", 0, -10)
    w.tail, w.combat = kpiPair(f, -40, L["DAMAGE STOPPED"], L["IN COMBAT"])
    w.hint = panel(f, { 1, 0.72, 0.29, 0.07 }, { 1, 0.72, 0.29, 0.35 })
    w.hint:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -40 - KPI_HEIGHT - GAP)
    w.hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -40 - KPI_HEIGHT - GAP)
    w.hint:SetHeight(64)
    w.hintText = text(w.hint, 11, { 0.95, 0.85, 0.67 })
    w.hintText:SetPoint("TOPLEFT", w.hint, "TOPLEFT", 8, -7)
    w.hintText:SetPoint("BOTTOMRIGHT", w.hint, "BOTTOMRIGHT", -8, 7)
    w.hintText:SetJustifyV("TOP")
    local links = footerButtons(body, {
        { L["DISCARD RUN"], function() act("discard") end, "danger" },
        { L["CLOSE (KEEP WAITING)"], function() act("close") end, width = 140 },
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
    local tail = run.result and run.result.tail
    if type(tail) == "number" then list[#list + 1] = { text = L["Tail +%.1fs"]:format(tail), color = C.info } end
    return list
end

-- RESULT: damage, DPS, the delta and flag chips, the top spells with %, and the three acts (screen 07).
function Builders.result(parent)
    local body = newBody(parent, "result")
    local f, w = body.frame, body.w
    w.damage, w.dps = kpiPair(f, 0, L["DAMAGE"], L["DPS"], C.green)
    w.chips = chips(f, -KPI_HEIGHT - GAP)
    w.lost = text(f, 12, C.red)
    w.lost:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -KPI_HEIGHT - GAP - 2 * (CHIP_HEIGHT + CHIP_GAP) - 4)
    w.rows = CreateFrame("Frame", nil, f)
    w.rows:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -KPI_HEIGHT - GAP - 2 * (CHIP_HEIGHT + CHIP_GAP) - 4)
    w.rows:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, LINK_HEIGHT + GAP)
    w.list = NS.HudBreakdown.New(w.rows)
    local links = footerButtons(body, {
        { L["RACE AGAIN"], function() act("raceAgain") end, "primary" },
        { L["DETAILS"], function() act("details") end, width = 72 },
        { L["SHARE"], function() act("share") end, width = 72 },
    })
    w.again, w.details, w.share = links[1], links[2], links[3]
    function body.Layout(self, width) self.w.chips.width = width end
    function body.Update(self, v)
        local run = v.run or {}
        local result = run.result or {}
        local lost = run.status == "lost"
        setKpi(self.w.damage, lost and DASH or NS.Format.Number(result.damage or 0))
        setKpi(self.w.dps, lost and DASH or NS.Format.Number(result.dps or 0))
        self.w.chips:Set(States.ResultChips(v))
        self.w.lost:SetText(lost and L["Couldn't read the result"] or "")
        if lost then self.w.list:Clear() else self.w.list:ShowResult(run, States.RESULT_ROWS, v.icons ~= false) end
        setEnabled(self.w.share, v.canShare == true)
        -- The sample card of test mode has no run to race again or open (modules/Hud.lua Act).
        setEnabled(self.w.again, v.preview ~= true)
        setEnabled(self.w.details, v.preview ~= true)
    end
    return body
end

-- The result card's spell rows (spec §6.1: the top 5 with %).
States.RESULT_ROWS = 5

--- Build one body into `parent`.
--- @param key string  idle | armed | running | stop | waiting | result
--- @param parent table
--- @return table body  { key, frame, w, Update(view), Layout(width)?, SetLive(live, rows, icons)? }
function States.Build(key, parent)
    local builder = Builders[key]
    if not builder then return nil end
    return builder(parent)
end
