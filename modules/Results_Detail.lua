local _, NS = ...
-- modules/Results_Detail.lua — one run in full (spec §6.2, mockup screen 08's right-hand pane): who,
-- against what and where; the score (damage, DPS, Blizzard's meter DPS muted, the best delta); the
-- ability breakdown sorted highest first with each spell's share; the timing strip (the race, the
-- buzzer, the grace, the tail, each late cast, the end of combat); the flags with what each means;
-- the note; Share and Delete. Placed by the shell (modules/Results.lua) beside the list, or in its
-- place with a back control on a narrow window.
--
-- PLAIN NUMBERS ONLY. A stored run went through NS.Secrets on its way in, so its figures may be
-- divided and compared: the % of each spell, the strip's positions. Timing and Place are pure, so the
-- suites check the strip's geometry without drawing it; the pane draws exactly what they answer.
--
-- The content scrolls (the mouse wheel) when the breakdown is long; the three buttons stay put.
--
-- SECTION HEADINGS (the owner's call, 2026-10-25): Spell breakdown (over the compare's toggle and the
-- spell list), the chart's title, Timing, Gear, Talents, Usage, the flags box's title and Note are all
-- FONT.SECTION, a step above GameFontNormal, each on a SECTION_H line with SECTION_GAP of clear space
-- above it (the header is the only block above the first heading, so no heading sits at the very top).
--
-- THE DAMAGE CHART (#2) sits under the breakdown, for a run raced since the last /reload or login: the
-- run's in-session slices (modules/Slices.lua), drawn by modules/Hud_Chart.lua and scaled to its plain
-- final damage. A run from an earlier session, a lost run or a shared session has no section at all.
--
-- THE COMPARE (#7) sits under the score: a toggle that sets the run beside the best on its board, or
-- beside a run picked from a Runs row's menu. Its parts and its pure logic are
-- modules/Results_Compare.lua's; while it is on, its compared breakdown takes the plain one's place.
--
-- THE LOADOUT (#6) sits under the timing strip: the run's gear and talents, drawn by
-- modules/Results_Loadout.lua, which highlights what changed while the compare is on.
--
-- THE USAGE (#13) sits under the talents: what the run used, ticked as detected and editable, drawn
-- by modules/Results_Usage.lua.
--
-- EVERY ELEMENT HAS A TOOLTIP (the owner's call, 2026-10-25), its lines from modules/Results_Tips.lua:
-- a spell row shows the client's own spell tooltip beside the window, level with the row; anything
-- else shows under itself. A text or a texture takes the mouse through a hover frame laid over it.

local Detail = {}
NS.ResultsDetail = Detail

local L = NS.L
local Tbl = NS.ResultsTable
local C = Tbl.COLORS
local FONT = NS.Style.FONT

Detail.NOTE_MAX = 200       -- characters (spec §6.2)
Detail.STRIP_GAP = 3        -- the gap between the race and the after-the-buzzer segments
Detail.STRIP_RATIO = 1.2    -- the race segment's share against the after-buzzer one's 1 (mockup)
Detail.SPAN_STEP = 6        -- the after-buzzer axis runs to a multiple of this, at least two steps

local PADX = 12
local BUTTON_H = 20
local KPI_H = 46
local STRIP_H = 34
local LINE_H = 14
-- The header (the owner's call, 2026-10-25): larger class and spec icons beside a larger name.
local ICON = 28
local ICON_GAP = 4
-- Every section heading (Spell breakdown, the chart, Timing, Gear, Talents, the flags, Note) is
-- FONT.SECTION on a line of SECTION_H, SECTION_GAP under the block above it.
local SECTION_H = NS.Style.SECTION_H
local SECTION_GAP = NS.Style.SECTION_GAP
Detail.SECTION_H = SECTION_H
Detail.SECTION_GAP = SECTION_GAP
Detail.ICON = ICON
local DASH = "\226\128\148"
local RED = { 1.0, 0.32, 0.32 }
local CYAN = { 0.3, 0.85, 1.0 }
local VIOLET = { 0.78, 0.5, 1.0 }
-- Every line on the strip (grace, late cast, combat end, restart) is one shape: the combat-end line's
-- width, the grace line's height (inset from the strip's top and bottom).
local LINE_W = 2
local LINE_INSET = 4
local RACE = { 0.53, 0.53, 0.93 }

-- ── pure: the note ──────────────────────────────────────────────────────────────────────────────

--- A note as it is stored: trimmed, chat escapes neutralized, at most NOTE_MAX characters (UTF-8
--- characters, never a byte cut through one).
--- @param text any
--- @return string
function Detail.ClampNote(text)
    if type(text) ~= "string" then return "" end
    local s = text:gsub("[%c]", " "):gsub("|", "/"):match("^%s*(.-)%s*$")
    local n, cut = 0, #s
    for pos in s:gmatch("()[^\128-\191]") do
        n = n + 1
        if n > Detail.NOTE_MAX then
            cut = pos - 1
            break
        end
    end
    return s:sub(1, cut)
end

-- ── pure: the timing strip ──────────────────────────────────────────────────────────────────────

local function clamp01(x)
    if type(x) ~= "number" then return nil end
    return math.max(0, math.min(1, x))
end

-- The after-buzzer axis: long enough for every mark, in whole steps, at least two of them.
-- `marks` is a list whose entries may be nil (a mark the run does not have): walked to `n`, never
-- with ipairs, which would stop at the first hole.
local function spanFor(marks, n)
    local top = 0
    for i = 1, n do
        local v = marks[i]
        if type(v) == "number" and v > top then top = v end
    end
    local step = Detail.SPAN_STEP
    return math.max(2 * step, step * math.ceil(top / step))
end

-- The after-buzzer half of the model: the axis span, then each mark as a fraction of it.
local function afterBuzzer(m, grace, result, flags)
    local tail, late = result.tail or 0, flags.lateCasts or {}
    local marks, n = { grace, tail, result.combatEnd, flags.restartedAt }, 4
    for _, cast in ipairs(late) do
        n = n + 1
        marks[n] = cast.t
    end
    m.span = spanFor(marks, n)
    m.grace, m.tail = clamp01(grace / m.span), clamp01(tail / m.span)
    m.combatEnd = result.combatEnd and clamp01(result.combatEnd / m.span)
    m.restart = flags.restartedAt and clamp01(flags.restartedAt / m.span)
    for i, cast in ipairs(late) do
        m.late[i] = clamp01((cast.t or 0) / m.span)
        m.lateAt[i] = cast.t
    end
end

--- The strip as fractions of its two segments: the race (start to buzzer) and the time after the
--- buzzer (to `span` seconds). An incomplete run fills the race to where combat ended and marks it
--- there; it has nothing after a buzzer it never reached.
--- @param run table  a resolved run
--- @return table|nil model  nil for a run with no result (lost)
function Detail.Timing(run)
    if type(run) ~= "table" or type(run.result) ~= "table" then return nil end
    local race, result, flags = run.race or {}, run.result, run.flags or {}
    local length = type(race.length) == "number" and race.length > 0 and race.length or 1
    local m = { length = length, late = {}, lateAt = {} }
    if run.status == "incomplete" then
        m.raceFill = clamp01((result.endedAt or 0) / length)
        m.endInRace = m.raceFill
        m.span = 2 * Detail.SPAN_STEP
        return m
    end
    m.raceFill = 1
    afterBuzzer(m, race.grace or 0, result, flags)
    return m
end

--- The strip's pixel positions for `width`, from Timing's fractions: each segment's width, the
--- buzzer (the boundary), the grace line, the tail band, each late-cast tick and the end of combat.
--- @return table { raceW, postW, postX, raceFill, buzzer, grace, tailX, tailW, late = {x}, combatEnd,
---                 restart, endInRace }
function Detail.Place(model, width)
    local gap = Detail.STRIP_GAP
    local raceW = math.floor((width - gap) * Detail.STRIP_RATIO / (Detail.STRIP_RATIO + 1))
    local postW = width - gap - raceW
    local postX = raceW + gap
    local function post(f) return f and (postX + f * postW) or nil end
    local p = { raceW = raceW, postW = postW, postX = postX, buzzer = raceW, late = {} }
    p.raceFill = model.raceFill * raceW
    p.endInRace = model.endInRace and model.endInRace * raceW
    p.grace = post(model.grace)
    p.tailX, p.tailW = postX, (model.tail or 0) * postW
    p.combatEnd = post(model.combatEnd)
    p.restart = post(model.restart)
    for i, f in ipairs(model.late) do p.late[i] = post(f) end
    return p
end

-- ── pure: what the flags mean ───────────────────────────────────────────────────────────────────

local STILL_COUNTS = "The run still counts and the flag shows on the board."

local function lateLine(run)
    local parts = {}
    for i, cast in ipairs(run.flags.lateCasts) do
        local name = NS.HudBreakdown.SpellName(cast.spellID)
        parts[i] = L["%s started +%.1fs after the buzzer"]:format(tostring(name), cast.t or 0)
    end
    return L["%s (grace %.1fs)."]:format(table.concat(parts, "; "), run.race and run.race.grace or 0)
        .. " " .. L[STILL_COUNTS]
end

local EXPLAIN = {
    lateCasts = lateLine,
    restarted = function(_, text) return L["%s, after the quiet gap."]:format(text) .. " " .. L[STILL_COUNTS] end,
    reloaded = function(_, text) return text .. ". " .. L[STILL_COUNTS] end,
    sessionFromList = function()
        return L["Session matched by list: the meter session was found by its place in Blizzard's list, not by its ID."]
            .. " " .. L[STILL_COUNTS]
    end,
    sharedSession = function(_, text)
        return text .. ". " .. L["The meter kept the last fight's session open (its DoTs were still ticking), so the race landed in it."]
            .. " " .. L[STILL_COUNTS]
    end,
    died = function(_, text) return text .. "." end,
    incomplete = function(_, text) return text .. ". " .. L["It does not count toward bests."] end,
    lost = function(_, text) return text .. ". " .. L["There is no score."] end,
}

--- The run's flags with what each means, in Scoring's order: { key, short, text }.
function Detail.FlagLines(run)
    local out = {}
    for _, flag in ipairs(NS.Scoring.Flags(run, NS.HudBreakdown.SpellName)) do
        local explain = EXPLAIN[flag.key]
        out[#out + 1] = { key = flag.key, text = explain and explain(run, flag.text) or flag.text, full = flag.text }
    end
    return out
end

--- The breakdown as drawn: a copy of the run's spells, highest first, then by id.
function Detail.SortedSpells(run)
    local out = {}
    for i, s in ipairs(type(run) == "table" and run.spells or {}) do out[i] = s end
    table.sort(out, function(a, b)
        local da, db = a.dmg or 0, b.dmg or 0
        if da ~= db then return da > db end
        return (a.id or 0) < (b.id or 0)
    end)
    return out
end

--- The header's three meta lines, and the target line's two chips (the owner's call, 2026-10-25):
--- the target type in its category color (Tbl.Badge) and the race length in its
--- length color (Tbl.LengthChip), boxed as the Runs list draws them, before the line's text (the
--- tail or when combat ended, then the target's name).
--- @return string realmLine, string targetLine, string stampLine, table chips  { { text, color } x2 }
function Detail.Meta(run)
    local char, where, target = run.char or {}, run.where or {}, run.target or {}
    local place = where.zone or ""
    if where.subzone and where.subzone ~= "" then place = place .. ", " .. where.subzone end
    local first = { char.realm or "?", L["ilvl %s"]:format(Tbl.Ilvl(char.ilvl)) }
    if place ~= "" then first[#first + 1] = place end
    local second = { Tbl.TimeTail(run) }
    second[#second + 1] = target.name or L["Unknown target"]
    local badge, badgeColor = Tbl.Badge(target)
    local chips = { { badge, badgeColor }, { Tbl.LengthChip(run.race and run.race.length) } }
    local third = { Tbl.Date(run.date, "%d %b %Y %H:%M") }
    if run.build then third[#third + 1] = L["build %s"]:format(tostring(run.build)) end
    if run.addon then third[#third + 1] = "v" .. tostring(run.addon) end
    local sep = " \194\183 "
    return table.concat(first, sep), table.concat(second, sep), table.concat(third, sep), chips
end

-- ── the pane ────────────────────────────────────────────────────────────────────────────────────

local Pane = {}
Pane.__index = Pane

-- The legend's labels, in the order its items are built (Results_Tips names each by this index).
Detail.LEGEND = { L["Race"], L["Tail (damage still landing)"], L["Grace"], L["Late cast"], L["Combat ended"],
                  L["Restart"] }
-- Its two rows, by index: the bars' colors, then the lines'.
Detail.LEGEND_ROWS = { { 1, 2 }, { 3, 4, 5, 6 } }

-- ── hovers ──────────────────────────────────────────────────────────────────────────────────────

local function showTip(p, owner, key, index)
    local lines = NS.ResultsTips.Detail(key, p.run, index)
    if lines then Tbl.BelowTip(owner, lines) end
end

-- `frame`'s hover: the tooltip for `key` under it. Hooked, so a button keeps its own hover look.
local function hover(p, frame, key, index)
    frame:EnableMouse(true)
    frame:HookScript("OnEnter", function(self) showTip(p, self, type(key) == "function" and key() or key, index) end)
    frame:HookScript("OnLeave", Tbl.HideTip)
    return frame
end

-- A hover frame laid over `region` (a text or a texture, which take no mouse of their own).
local function hoverOver(p, region, key, index)
    local f = CreateFrame("Frame", nil, p.content)
    f:SetAllPoints(region)
    return hover(p, f, key, index)
end

local function kpi(parent, label, color)
    local f = Tbl.Panel(parent)
    f:SetHeight(KPI_H)
    -- LootHistory's Insights card: a GameFontNormalHuge figure over a GameFontDisableSmall caption.
    local k = { frame = f, label = Tbl.Text(f, FONT.CAPTION), value = Tbl.Text(f, FONT.FIGURE, color or C.text) }
    k.label:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
    k.label:SetText(label)
    k.value:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 5)
    return k
end

local function wrapText(parent, font, color)
    local fs = Tbl.Text(parent, font, color)
    fs:SetWordWrap(true)
    fs:SetJustifyV("TOP")
    return fs
end

local function buildHeader(p, c)
    local w = p.w
    -- The spec icon names the spec (its tooltip says spec and class): no spec text beside the name.
    w.class = c:CreateTexture(nil, "ARTWORK")
    w.class:SetSize(ICON, ICON)
    w.spec = c:CreateTexture(nil, "ARTWORK")
    w.spec:SetSize(ICON, ICON)
    w.name = Tbl.Text(c, FONT.NAME, C.text)
    w.meta = { Tbl.Text(c, FONT.TEXT, C.dim), Tbl.Text(c, FONT.TEXT, C.dim), Tbl.Text(c, FONT.TEXT, C.dim) }
    -- The target line's chips (Detail.Meta): the target type, then the race length.
    w.metaChips = { Tbl.Chip(c), Tbl.Chip(c) }
    w.damage, w.dps, w.meterDps = kpi(c, L["Damage"]), kpi(c, L["DPS"], C.green), kpi(c, L["Meter DPS"], C.dim)
    w.delta = Tbl.Text(c, FONT.TEXT, C.green)
    w.spellsTitle = Tbl.Text(c, FONT.SECTION)
    w.spellsTitle:SetText(L["Spell breakdown"])
end

local function legendItem(c, color, label)
    local item = { swatch = c:CreateTexture(nil, "ARTWORK"), fs = Tbl.Text(c, FONT.CAPTION) }
    item.swatch:SetSize(9, 9)
    item.swatch:SetColorTexture(color[1], color[2], color[3], 0.8)
    item.fs:SetText(label)
    item.text = label
    return item
end

local function stripMark(parent, color, width)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    t:SetWidth(width or LINE_W)
    return t
end

local function buildTiming(p, c)
    local w = p.w
    w.timingLabel = Tbl.Text(c, FONT.SECTION)
    w.timingLabel:SetText(L["Timing"])
    w.strip = CreateFrame("Frame", nil, c)
    w.strip:SetHeight(STRIP_H)
    w.segA = Tbl.Panel(w.strip, { 0.07, 0.07, 0.1, 1 }, { 1, 1, 1, 0.08 })
    w.segB = Tbl.Panel(w.strip, { 0.07, 0.07, 0.1, 1 }, { 1, 1, 1, 0.08 })
    -- The marks' own frame, above the segments: a child frame draws over its parent's textures
    -- whatever their layer, so marks made on the strip itself sat hidden under the opaque segments.
    w.marks = CreateFrame("Frame", nil, w.strip)
    w.marks:SetAllPoints(w.strip)
    w.marks:SetFrameLevel(w.strip:GetFrameLevel() + 2)
    local m = w.marks
    w.raceFill = stripMark(m, { RACE[1], RACE[2], RACE[3], 0.5 })
    w.tail = stripMark(m, { C.amber[1], C.amber[2], C.amber[3], 0.45 })
    w.grace = stripMark(m, { C.green[1], C.green[2], C.green[3], 0.8 })
    w.combatEnd = stripMark(m, CYAN)
    w.restart = stripMark(m, VIOLET)
    w.ticks = NS.Pool.New()
    w.axisLeft = Tbl.Text(c, FONT.CAPTION)
    w.axisMid, w.axisRight = Tbl.Text(c, FONT.CAPTION, nil, "CENTER"), Tbl.Text(c, FONT.CAPTION, nil, "RIGHT")
    w.axisRace = Tbl.Text(c, FONT.CAPTION)
    w.tailLine = Tbl.Text(c, FONT.TEXT, C.text)
    local LG = Detail.LEGEND
    w.legend = {
        legendItem(c, RACE, LG[1]), legendItem(c, C.amber, LG[2]), legendItem(c, C.green, LG[3]),
        legendItem(c, RED, LG[4]), legendItem(c, CYAN, LG[5]), legendItem(c, VIOLET, LG[6]),
    }
end

local function buildFlags(p, c)
    local w = p.w
    w.flags = Tbl.Panel(c, { 1, 0.72, 0.29, 0.06 }, { 1, 0.72, 0.29, 0.35 })
    w.flagTitle = Tbl.Text(w.flags, FONT.SECTION, { 0.95, 0.84, 0.65 })
    w.flagTitle:SetPoint("TOPLEFT", w.flags, "TOPLEFT", 9, -7)
    w.flagBody = wrapText(w.flags, FONT.TEXT, { 0.94, 0.84, 0.65 })
    w.flagBody:SetPoint("TOPLEFT", w.flags, "TOPLEFT", 9, -(7 + SECTION_H))
    w.flagBody:SetPoint("BOTTOMRIGHT", w.flags, "BOTTOMRIGHT", -9, 6)
    w.noteTitle = Tbl.Text(c, FONT.SECTION)
    w.noteTitle:SetText(L["Note"])
    w.note = wrapText(c, FONT.TEXT, C.dim)
    w.noteBox = CreateFrame("EditBox", nil, c, "BackdropTemplate")
    w.noteBox:SetAutoFocus(false)
    w.noteBox:SetFontObject(FONT.TEXT)
    w.noteBox:SetMaxLetters(Detail.NOTE_MAX)
    w.noteBox:SetHeight(20)
    if w.noteBox.SetBackdrop then
        w.noteBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        w.noteBox:SetBackdropColor(0.1, 0.1, 0.12, 0.9)
        w.noteBox:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    end
    w.noteBox:SetTextInsets(6, 6, 0, 0)
    w.noteBox:SetScript("OnEnterPressed", function(self) p:saveNote(self:GetText()) end)
    w.noteBox:SetScript("OnEscapePressed", function() p:closeNote() end)
    w.noteBox:Hide()
end

local function buildButtons(p)
    local w, f, Button = p.w, p.frame, NS.HudStates.Button
    w.back = Button(f, L["Back"], function() if p.hooks.back then p.hooks.back() end end)
    w.back:SetSize(78, BUTTON_H)
    w.back:SetPoint("TOPLEFT", f, "TOPLEFT", PADX, -8)
    w.back.label:SetPoint("CENTER", w.back, "CENTER", 6, 0)
    w.back.icon = w.back:CreateTexture(nil, "OVERLAY")
    w.back.icon:SetSize(10, 10)
    w.back.icon:SetPoint("LEFT", w.back, "LEFT", 8, 0)
    w.back.icon:SetTexture(NS.Icon("arrow-left"))
    w.addNote = Button(f, L["Add Note"], function() p:openNote() end)
    w.share = Button(f, L["Share"], function() if p.run and p.hooks.share then p.hooks.share(p.run) end end)
    w.delete = Button(f, L["Delete"], function() if p.run and p.hooks.delete then p.hooks.delete(p.run) end end, "danger")
    for i, b in ipairs({ w.addNote, w.share }) do
        b:SetSize(84, BUTTON_H)
        b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PADX + (i - 1) * 90, 8)
    end
    w.delete:SetSize(78, BUTTON_H)
    w.delete:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADX, 8)
end

-- Every element's hover but the spell rows' (the breakdown's own `tip` hook).
local function wireTips(p)
    local w = p.w
    hoverOver(p, w.class, "class")
    hoverOver(p, w.spec, "class")
    hoverOver(p, w.name, "name")
    for i, key in ipairs({ "realm", "target", "stamp" }) do hoverOver(p, w.meta[i], key) end
    for _, chip in ipairs(w.metaChips) do hover(p, chip, "target") end
    hoverOver(p, w.spellsTitle, "breakdown")
    hover(p, w.damage.frame, "damage")
    hover(p, w.dps.frame, "dps")
    hover(p, w.meterDps.frame, "meterDps")
    hoverOver(p, w.delta, "delta")
    -- Kept: the title keeps its anchors while hidden, so its hover follows the chart's visibility.
    w.chartTitleHover = hoverOver(p, w.chart.title, "chart")
    hover(p, w.chart.over, "chart")
    hoverOver(p, w.timingLabel, "strip")
    hover(p, w.strip, "strip")
    for _, axis in ipairs({ w.axisLeft, w.axisMid, w.axisRight, w.axisRace }) do hoverOver(p, axis, "strip") end
    hoverOver(p, w.tailLine, "tail")
    for i, item in ipairs(w.legend) do
        hoverOver(p, item.swatch, "legend", i)
        hoverOver(p, item.fs, "legend", i)
    end
    hover(p, w.flags, "flags")
    -- Over the note box's spot too: hidden while the box is open, so it never takes the box's clicks.
    w.noteHover = hoverOver(p, w.note, "note")
    w.noteTitleHover = hoverOver(p, w.noteTitle, function() return p.editing and "noteBox" or "note" end)
    hover(p, w.noteBox, "noteBox")
    hover(p, w.back, "back")
    hover(p, w.addNote, "addNote")
    hover(p, w.share, function() return w.share:IsEnabled() and "share" or "shareOff" end)
    hover(p, w.delete, "delete")
end

-- A spell row's hover: the client's spell tooltip, then its damage, share and place, beside the window.
local function spellTip(p, row, spell, rank)
    local count = p.run and #(p.run.spells or {}) or nil
    Tbl.SpellTip(Tbl.WindowOf(p.frame), row, spell.id, NS.ResultsTips.Spell(spell, p.run or {}, rank, count))
end

--- The detail pane in `parent`.
--- @param parent table
--- @param hooks table  { back(), share(run), delete(run), saveNote(run, text) -> stored, canShare(),
---                       clearPick() }
function Detail.Build(parent, hooks)
    local frame = Tbl.Panel(parent, { 0, 0, 0, 0.15 }, { 0.24, 0.24, 0.27, 0.85 })
    -- Its own band over the Runs pane it sits inside in wide mode (core/Constants.lua LAYERS), set
    -- before any child is built so every child is born in it.
    frame:SetFrameLevel(parent:GetFrameLevel() + NS.Constants.LAYERS.LEVEL.DETAIL)
    local p = setmetatable({ frame = frame, hooks = hooks or {}, w = {}, scroll = 0, width = 340, height = 400 }, Pane)
    p.scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    p.content = CreateFrame("Frame", nil, p.scrollFrame)
    p.scrollFrame:SetScrollChild(p.content)
    p.scrollFrame:EnableMouseWheel(true)
    p.scrollFrame:SetScript("OnMouseWheel", function(_, delta) p:Scroll(delta) end)
    p.w.empty = Tbl.Text(frame, FONT.EMPTY, nil, "CENTER")
    p.w.empty:SetPoint("CENTER", frame, "CENTER", 0, 0)
    p.w.empty:SetText(L["Select a run to see its detail."])
    local c = p.content
    buildHeader(p, c)
    NS.ResultsCompare.Build(p, c)
    p.w.list = NS.HudBreakdown.New(CreateFrame("Frame", nil, c), function(row, spell, rank) spellTip(p, row, spell, rank) end)
    p.w.chart = NS.HudChart.New(c, FONT.SECTION, SECTION_H)
    p.w.chart:SetShown(false)
    -- A cooldown dot's tooltip (#14): the spell and when it was cast.
    p.w.chart:SetDotTip(function(owner, cast) Tbl.BelowTip(owner, NS.ResultsTips.Dot(cast)) end, Tbl.HideTip)
    buildTiming(p, c)
    NS.ResultsLoadout.Build(p, c)
    NS.ResultsUsage.Build(p, c)
    buildFlags(p, c)
    buildButtons(p)
    wireTips(p)
    return p
end

-- ── drawing one run ─────────────────────────────────────────────────────────────────────────────

local function setDelta(fs, run)
    if run.status ~= "complete" then return fs:SetText("") end
    local pct, isNew = NS.ResultsSource.Delta(run)
    if isNew then
        fs:SetText(pct and L["New best +%.1f%%"]:format(pct) or L["New best"])
        fs:SetTextColor(C.green[1], C.green[2], C.green[3])
    elseif pct then
        fs:SetText(L["%+.1f%% vs best"]:format(pct))
        fs:SetTextColor(RED[1], RED[2], RED[3])
    else
        fs:SetText("")
    end
end

function Pane:fillHeader(run)
    local w, char = self.w, run.char or {}
    Tbl.SetClassIcon(w.class, char.class)
    local specName, specIcon = Tbl.SpecInfo(char.specID, char.spec)
    w.spec:SetTexture(specIcon)
    w.spec:SetShown(specIcon ~= nil)
    w.name:SetText(char.name or "?")
    local color = Tbl.ClassColor(char.class)
    w.name:SetTextColor(color[1], color[2], color[3])
    self.specName = specName   -- named by the spec icon's tooltip, never drawn beside the name
    local a, b, c, chips = Detail.Meta(run)
    w.meta[1]:SetText(a)
    w.meta[2]:SetText(b)
    w.meta[3]:SetText(c)
    -- Each chip's width (Tbl.BadgeWidth's) is kept for the layout: nothing is read back.
    self.metaChipW = {}
    for i, chip in ipairs(w.metaChips) do self.metaChipW[i] = Tbl.SetChip(chip, chips[i][1], chips[i][2]) end
end

function Pane:fillScore(run)
    local w, result = self.w, run.result or {}
    local lost = run.status == "lost"
    w.damage.value:SetText(lost and DASH or NS.Format.Number(result.damage or 0))
    w.dps.value:SetText(lost and DASH or NS.Format.Number(result.dps or 0))
    w.meterDps.value:SetText(type(result.meterDps) == "number" and NS.Format.Number(result.meterDps) or DASH)
    w.dps.label:SetText(run.status == "incomplete" and L["DPS \194\183 Incomplete"] or L["DPS"])
    setDelta(w.delta, run)
end

function Pane:fillFlags(run)
    local w = self.w
    local lines = Detail.FlagLines(run)
    self.flagLines = lines
    w.flags:SetShown(#lines > 0)
    self.flagText = ""
    if #lines == 0 then return end
    local title = #lines == 1 and L["Flag \194\183 %s"]:format(lines[1].full) or L["Flags \194\183 %d"]:format(#lines)
    w.flagTitle:SetText(title)
    local texts = {}
    for i, line in ipairs(lines) do texts[i] = line.text end
    self.flagText = table.concat(texts, "\n")
    w.flagBody:SetText(self.flagText)
end

--- Draw `run` (nil clears the pane to its prompt). The same run drawn again (a saved note or usage
--- edit, a store change) keeps the scroll and the usage ticks not saved yet; another run starts at
--- the top.
function Pane:Show(run)
    local same = run ~= nil and run == self.run
    self.run = run
    self.editing = false
    local has = type(run) == "table"
    self.scrollFrame:SetShown(has)
    self.w.empty:SetShown(not has)
    for _, key in ipairs({ "addNote", "share", "delete" }) do self.w[key]:SetShown(has) end
    if not has then return end
    self:fillHeader(run)
    self:fillScore(run)
    NS.ResultsCompare.Fill(self)
    NS.ResultsLoadout.Fill(self)
    NS.ResultsUsage.Fill(self, same)
    local spells = Detail.SortedSpells(run)
    self.w.list:ShowResult({ spells = spells, result = run.result }, #spells, true)
    self.model = Detail.Timing(run)
    self.chartView = NS.ResultsSource.ChartView(run)
    self:fillFlags(run)
    -- The note as written: its own "Note" heading says what it is.
    self.noteText = type(run.note) == "string" and run.note or ""
    self.w.note:SetText(self.noteText)
    self.w.addNote.label:SetText(run.note ~= nil and run.note ~= "" and L["Edit Note"] or L["Add Note"])
    NS.HudStates.SetEnabled(self.w.share, self.hooks.canShare and self.hooks.canShare() or false)
    if not same then self.scroll = 0 end
    self:Layout(self.width, self.height, self.narrow)
end

-- ── the compare ─────────────────────────────────────────────────────────────────────────────────

--- Whether the detail shows the compare now: the toggle on, and a run to compare with.
function Pane:Comparing()
    return self.comparing == true and self.cmp ~= nil and self.cmp.other ~= nil
end

--- The run the detail is compared with and its kind ("picked" | "best" | "runnerUp"): nil while the
--- compare is off, unless `resolved` asks for the toggle's target either way. The loadout's
--- highlights (modules/Results_Loadout.lua) read the comparison through this.
--- @param resolved boolean|nil
--- @return table|nil other, string|nil kind
function Pane:CompareTarget(resolved)
    if not (resolved or self:Comparing()) then return nil end
    return NS.ResultsCompare.TargetOf(self)
end

-- Repaint the compare's parts and lay the pane out again, the scroll kept.
function Pane:refreshCompare()
    if not self.run then return end
    NS.ResultsCompare.Fill(self)
    NS.ResultsLoadout.Fill(self)
    self:Layout(self.width, self.height, self.narrow)
end

--- The toggle: compare on or off (view state for the session, never stored).
function Pane:SetComparing(on)
    self.comparing = on and true or false
    self:refreshCompare()
end

--- Compare with run `id` (the row menu's pick) from now on, the toggle turned on; nil clears the
--- pick, back to the best on the board.
function Pane:SetPick(id)
    self.pickID = id
    if id ~= nil then self.comparing = true end
    self:refreshCompare()
end

-- ── the note ────────────────────────────────────────────────────────────────────────────────────

function Pane:openNote()
    if not self.run then return end
    self.editing = true
    self.w.noteBox:SetText(self.run.note or "")
    self:Layout(self.width, self.height, self.narrow)
    -- The box sits last in the content, under the spells and timing: scroll down to it.
    self.scroll = math.huge
    self:Scroll(0)
    self.w.noteBox:SetFocus()
end

function Pane:closeNote()
    self.editing = false
    self.w.noteBox:ClearFocus()
    self:Layout(self.width, self.height, self.narrow)
end

function Pane:saveNote(text)
    local run = self.run
    if run and self.hooks.saveNote then self.hooks.saveNote(run, text) end
    self:closeNote()
    if run then self:Show(run) end
end

-- ── layout ──────────────────────────────────────────────────────────────────────────────────────

-- Each block below places its widgets at `y` (negative, down from the content's top) across `cw`
-- and answers the y beneath it.

-- The target line: its two chips from the left (their widths Tbl.SetChip's, kept at fill), the
-- line's text after them in what is left, level with the chips' middle. A CHIP_LINE_H line.
local CHIP_LINE_H = Tbl.CHIP_H + 2

function Pane:layoutTargetLine(y, cw)
    local w, x = self.w, 0
    for i, chip in ipairs(w.metaChips) do
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
        local cwi = self.metaChipW and self.metaChipW[i] or 0
        if cwi > 0 then x = x + cwi + Tbl.CHIP_GAP end
    end
    local fs = w.meta[2]
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", self.content, "TOPLEFT", x, y - Tbl.CHIP_H / 2)
    fs:SetWidth(math.max(10, cw - x))
    return y - CHIP_LINE_H
end

function Pane:layoutHeader(y, cw)
    local w = self.w
    w.class:ClearAllPoints()
    w.class:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
    w.spec:ClearAllPoints()
    w.spec:SetPoint("TOPLEFT", self.content, "TOPLEFT", ICON + ICON_GAP, y)
    -- The name level with the icons' middle, after them.
    local nameX = 2 * (ICON + ICON_GAP) + 4
    w.name:ClearAllPoints()
    w.name:SetPoint("LEFT", self.content, "TOPLEFT", nameX, y - ICON / 2)
    w.name:SetWidth(math.max(40, cw - nameX))
    y = y - ICON - 6
    for i, fs in ipairs(w.meta) do
        if i == 2 then
            y = self:layoutTargetLine(y, cw)
        else
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
            fs:SetWidth(cw)
            y = y - LINE_H
        end
    end
    y = y - 8
    local third = math.floor((cw - 12) / 3)
    for i, k in ipairs({ w.damage, w.dps, w.meterDps }) do
        k.frame:ClearAllPoints()
        k.frame:SetPoint("TOPLEFT", self.content, "TOPLEFT", (i - 1) * (third + 6), y)
        k.frame:SetWidth(third)
    end
    y = y - KPI_H - 4
    w.delta:ClearAllPoints()
    w.delta:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
    return y - LINE_H - 4
end

-- The breakdown's heading, over the compare's toggle and the spell list (the plain or the compared).
function Pane:layoutSpellsTitle(y)
    local t = self.w.spellsTitle
    y = y - SECTION_GAP
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
    return y - SECTION_H
end

function Pane:layoutSpells(y, cw)
    local host = self.w.list.parent
    local n = self.w.list:Count()
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
    local pitch = NS.HudBreakdown.Pitch()
    host:SetSize(cw, math.max(1, n * pitch))
    return y - n * pitch - 8
end

-- The damage chart, when the run has slices this session; nothing at all when it has none.
function Pane:layoutChart(y, cw)
    local view, chart = self.chartView, self.w.chart
    chart:SetShown(view ~= nil)
    chart.over:EnableMouse(view ~= nil)
    self.w.chartTitleHover:SetShown(view ~= nil)
    if not view then return y end
    y = y - SECTION_GAP
    local Chart = NS.HudChart
    local plotH = Chart.PlotHeight()
    chart:Place(self.content, y, cw, plotH)
    chart:Draw(view)
    return y - Chart.BlockHeight(plotH, SECTION_H) - 8
end

local function placeMark(tex, strip, x, inset)
    tex:ClearAllPoints()
    tex:SetShown(x ~= nil)
    if not x then return end
    tex:SetPoint("TOPLEFT", strip, "TOPLEFT", x, -inset)
    tex:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", x, inset)
end

function Pane:layoutStripMarks(pos)
    local w = self.w
    w.segA:ClearAllPoints()
    w.segA:SetPoint("TOPLEFT", w.strip, "TOPLEFT", 0, 0)
    w.segA:SetSize(pos.raceW, STRIP_H)
    w.segB:ClearAllPoints()
    w.segB:SetPoint("TOPLEFT", w.strip, "TOPLEFT", pos.postX, 0)
    w.segB:SetSize(pos.postW, STRIP_H)
    placeMark(w.raceFill, w.strip, 0, 10)
    w.raceFill:SetWidth(math.max(1, pos.raceFill))
    placeMark(w.tail, w.strip, pos.tailW > 0 and pos.tailX or nil, 10)
    w.tail:SetWidth(math.max(1, pos.tailW))
    placeMark(w.grace, w.strip, pos.grace, LINE_INSET)
    placeMark(w.combatEnd, w.strip, pos.combatEnd or pos.endInRace, LINE_INSET)
    placeMark(w.restart, w.strip, pos.restart, LINE_INSET)
    NS.Pool.ReleaseAll(w.ticks)
    for _, x in ipairs(pos.late) do
        placeMark(NS.Pool.Acquire(w.ticks, function() return stripMark(w.marks, RED) end), w.strip, x, LINE_INSET)
    end
end

local function tailText(run)
    local result = run.result or {}
    if run.status == "incomplete" then
        return L["Combat ended at %s, before the buzzer."]:format(NS.Format.Length(result.endedAt or 0))
    end
    local s = L["Damage stopped %ss after the buzzer"]:format(NS.Format.Seconds(result.tail or 0))
    if type(result.combatEnd) == "number" then
        s = s .. " \194\183 " .. L["combat ended %ss"]:format(NS.Format.Seconds(result.combatEnd))
    end
    return s
end

-- The legend in its rows (Detail.LEGEND_ROWS), the bars' colors over the lines'; a row too long for
-- `cw` wraps onto the next line rather than run off the pane.
function Pane:layoutLegend(y, cw)
    local row = 0
    for r, indices in ipairs(Detail.LEGEND_ROWS) do
        if r > 1 then row = row + 1 end
        local x = 0
        for _, i in ipairs(indices) do
            local item = self.w.legend[i]
            local w = 14 + #item.text * 5.5
            if x > 0 and x + w > cw then x, row = 0, row + 1 end
            item.swatch:ClearAllPoints()
            item.swatch:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y - row * LINE_H - 2)
            item.fs:ClearAllPoints()
            item.fs:SetPoint("LEFT", item.swatch, "RIGHT", 4, 0)
            x = x + w + 10
        end
    end
    return y - (row + 1) * LINE_H
end

function Pane:layoutTiming(y, cw)
    local w, model = self.w, self.model
    local on = model ~= nil
    for _, key in ipairs({ "timingLabel", "strip", "axisLeft", "axisMid", "axisRight", "axisRace", "tailLine" }) do
        w[key]:SetShown(on)
    end
    for _, item in ipairs(w.legend) do item.swatch:SetShown(on); item.fs:SetShown(on) end
    if not on then return y end
    y = y - SECTION_GAP
    w.timingLabel:ClearAllPoints()
    w.timingLabel:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
    y = y - SECTION_H
    w.strip:ClearAllPoints()
    w.strip:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
    w.strip:SetWidth(cw)
    self.place = Detail.Place(model, cw)
    self:layoutStripMarks(self.place)
    y = y - STRIP_H - 4
    w.axisRace:ClearAllPoints()
    w.axisRace:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
    w.axisRace:SetText(L["0:00 \226\128\148 race %s \226\128\148 buzzer"]:format(NS.Format.Length(model.length)))
    local x0, half = self.place.postX, self.place.postW
    w.axisLeft:ClearAllPoints()
    w.axisLeft:SetPoint("TOPLEFT", self.content, "TOPLEFT", x0, y)
    w.axisLeft:SetText(L["+%ds"]:format(0))
    w.axisMid:ClearAllPoints()
    w.axisMid:SetPoint("TOP", self.content, "TOPLEFT", x0 + half / 2, y)
    w.axisMid:SetText(L["+%ds"]:format(model.span / 2))
    w.axisRight:ClearAllPoints()
    w.axisRight:SetPoint("TOPRIGHT", self.content, "TOPLEFT", x0 + half, y)
    w.axisRight:SetText(L["+%ds"]:format(model.span))
    y = y - LINE_H - 2
    w.tailLine:ClearAllPoints()
    w.tailLine:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
    w.tailLine:SetWidth(cw)
    w.tailLine:SetText(tailText(self.run))
    return self:layoutLegend(y - LINE_H - 4, cw) - 8
end

-- A wrapped block's height, estimated from its length (the pane reads no text size back).
local function wrappedLines(text, width, charW)
    local perLine = math.max(10, math.floor(width / charW))
    local n = 0
    for line in (tostring(text) .. "\n"):gmatch("(.-)\n") do n = n + math.max(1, math.ceil(#line / perLine)) end
    return n
end

function Pane:layoutFlags(y, cw)
    local w = self.w
    if (self.flagText or "") ~= "" then
        y = y - SECTION_GAP
        local h = 7 + SECTION_H + 6 + wrappedLines(self.flagText, cw - 18, 5.4) * LINE_H
        w.flags:ClearAllPoints()
        w.flags:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
        w.flags:SetSize(cw, h)
        y = y - h - 8
    end
    return self:layoutNote(y, cw)
end

-- The note under its own heading: the heading shows with a note, or while one is being written.
function Pane:layoutNote(y, cw)
    local w = self.w
    local note = self.noteText or ""
    local titled = self.editing == true or note ~= ""
    w.noteTitle:SetShown(titled)
    w.noteTitleHover:SetShown(titled)
    if titled then
        y = y - SECTION_GAP
        w.noteTitle:ClearAllPoints()
        w.noteTitle:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
        y = y - SECTION_H
    end
    w.noteBox:SetShown(self.editing == true)
    w.note:SetShown(not self.editing and note ~= "")
    w.noteHover:SetShown(not self.editing and note ~= "")
    local target = self.editing and w.noteBox or w.note
    target:ClearAllPoints()
    target:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
    target:SetWidth(cw)
    if self.editing then return y - 30 end
    if note == "" then return y end
    return y - wrappedLines(note, cw, 5.4) * LINE_H - 8
end

--- Lay the pane out for `width` x `height`; `narrow` shows the back control above the content.
function Pane:Layout(width, height, narrow)
    self.width, self.height, self.narrow = width, height, narrow and true or false
    self.w.back:SetShown(self.narrow)
    local top = self.narrow and (BUTTON_H + 16) or 10
    local cw = math.max(100, width - 2 * PADX)
    self.scrollFrame:ClearAllPoints()
    self.scrollFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PADX, -top)
    self.scrollFrame:SetSize(cw, math.max(1, height - top - BUTTON_H - 18))
    self.viewH = math.max(1, height - top - BUTTON_H - 18)
    self.content:SetWidth(cw)
    if not self.run then return end
    local y = self:layoutHeader(0, cw)
    y = self:layoutSpellsTitle(y)
    y = NS.ResultsCompare.LayoutBar(self, y, cw)
    local comparing = self:Comparing()
    self.w.list.parent:SetShown(not comparing)
    y = NS.ResultsCompare.LayoutCompared(self, y, cw)
    if not comparing then y = self:layoutSpells(y, cw) end
    y = self:layoutChart(y, cw)
    y = self:layoutTiming(y, cw)
    y = NS.ResultsLoadout.Layout(self, y, cw)
    y = NS.ResultsUsage.Layout(self, y, cw)
    y = self:layoutFlags(y, cw)
    self.contentH = -y
    self.content:SetHeight(math.max(1, self.contentH))
    self:Scroll(0)
end

--- One mouse-wheel notch (`delta` > 0 scrolls up), clamped to the content.
function Pane:Scroll(delta)
    local top = math.max(0, (self.contentH or 0) - (self.viewH or 0))
    self.scroll = math.max(0, math.min(top, (self.scroll or 0) - (delta or 0) * 3 * NS.HudBreakdown.Pitch()))
    self.scrollFrame:SetVerticalScroll(self.scroll)
end
