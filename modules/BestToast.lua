local _, NS = ...
-- modules/BestToast.lua — the new-best toast (#5): when a race's result makes it the best on its board,
-- a toast near the top of the screen says so, whether or not the HUD is shown. The result card's
-- *New best* chip stays as it is; the toast is the alert for a player looking elsewhere.
--
-- THE TRIGGER. RACE_RESULT with run.status "complete", and Bests.Delta saying it is a new best AND
-- naming a percentage: a board's first complete run is a new best with nothing to beat, and does not
-- toast (decided 2026-10-25 on the issue). The all-runs board decides, so a flagged run may toast, and
-- its flags show on the toast's last line as the result card's chips word them. One toast per run,
-- queued under its run id. Off with *Show a toast for a new best* (`toast.enabled`).
--
-- THE SHELL is LibKa0s-Toast-1.0 through core/ToastSetup.lua: one at a time, the countdown
-- (`toast.duration`) paused under the pointer, the close mark and a right-click, the scale
-- (`toast.scale`) and the sound (`toast.sound`). This file keeps the content (the builder below), the
-- trigger and the placement rules: the toast moves only while it is test mode's or a sample's, and
-- its point is stored in `profile.toast.point` in UIParent's units (the shell hands it over; *Reset
-- position* clears it).
--
-- TEST MODE shows the sample race's toast (modules/Preview.lua: the same sample the HUD holds), sticky,
-- for placing it; the end of test mode takes it down. *Test toast* (General > New-best toast) queues a
-- sample toast that runs its course as a real one does.
--
-- PLAIN VALUES ONLY. The payload is text made from the stored run (every number on it went through
-- NS.Secrets on its way in) and the previous best's; nothing here reads the meter. The frame's size
-- is this file's constants, never read back off a FontString.
--
-- THE LAYOUT (DR-04, the owner's Addendum 03, image-60): the first release's toast 25% larger, every
-- size in it scaled by SCALE (the padding, the faces, the chips, the gaps), with three changes. The
-- trophy is as tall as the three rows (the headline, the target and time chips, the DPS line), and
-- the toast is widened by what that adds. The rows are fixed-height slots, their text centered in
-- them, one equal ROW_GAP between each pair, and the same PAD above the first and below the last.
-- The class and spec icons sit between "New best:" and the spec and class words. HEIGHT is the final
-- height, the figure DropWatcher's toast matches (DW-05).

local BestToast = {}
NS.BestToast = BestToast

local L = NS.L
local MIDDOT = " \194\183 "

-- The key a sample from *Test toast* queues under.
BestToast.SAMPLE = "sample"

-- The frame's geometry (the shell's frame; the close mark is the shell's, top-right, 18 px, 4 px in).
-- Each figure is the first release's (in the comment) times SCALE, rounded to the pixel.
local SCALE = 1.25
BestToast.SCALE = SCALE
BestToast.PAD = 13                      -- 10: every edge, so the top and bottom padding match
BestToast.GAP = 10                      -- 8: between the trophy and the rows
BestToast.ROW_GAP = 6                   -- 4: one gap between each pair of rows (a little over 5)
BestToast.TITLE_SIZE = 12 * SCALE       -- GameFontNormal's 12 px: the headline and the spec and class
BestToast.TEXT_SIZE = 10 * SCALE        -- GameFontHighlightSmall's 10 px: the chips, the DPS and flags
BestToast.TITLE_H = 17                  -- the headline's slot: its 15 px face and a pixel each side
BestToast.CHIP_H = 16 * SCALE           -- Tbl.CHIP_H's 16: the chips' row
BestToast.TEXT_H = 15                   -- the DPS line's (and the flags') slot: 12.5 px and a margin
BestToast.CLASS_ICON = 16               -- the class and spec icons, a pixel under the headline's slot
local ICON_GAP = 4                      -- between "New best:", the two icons and the words
-- The three rows, and the trophy as tall as them.
BestToast.ROWS_H = BestToast.TITLE_H + BestToast.ROW_GAP + BestToast.CHIP_H + BestToast.ROW_GAP
    + BestToast.TEXT_H
local CLOSE_ROOM = 32                   -- 26: the words' right inset, clear of the close mark
local CONTENT_W = 355                   -- 284: the rows' width right of the trophy
BestToast.WIDTH = BestToast.PAD + BestToast.ROWS_H + BestToast.GAP + CONTENT_W + BestToast.PAD
-- THE FINAL HEIGHT (72 x 1.25 = 90): the padding, the three rows and the padding. DropWatcher's
-- new-loot toast matches it (Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, DW-05).
BestToast.HEIGHT = BestToast.PAD + BestToast.ROWS_H + BestToast.PAD
BestToast.FLAGS_HEIGHT = BestToast.ROW_GAP + BestToast.TEXT_H   -- 16: the flags' line, when any
local TROPHY_FALLBACK = "Interface\\Icons\\Achievement_Dungeon_GloryoftheHero"

local toast       -- the shell's instance (or the seam's stub)
local sampleKey   -- the sim's run a real toast is up for (gone with the preview)
local preview     -- test mode's payload while it is on (shown again when the toast is turned back on)

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Toast", fmt, ...) end
end

local function setting(key) return NS.GetSetting("toast." .. key) end

local function enabled() return setting("enabled") == true end

-- ── the payload ─────────────────────────────────────────────────────────────────────────────────

--- "Cleave" / "Single target", or an uncataloged target's own name (as the share line says it).
local function categoryText(target)
    target = type(target) == "table" and target or {}
    local category = NS.Dummies.CategoryOf(target)
    if category == "other" and target.name then return target.name end
    return NS.Dummies.Label(category)
end

local function flagsText(run)
    local chips = NS.HudStates.FlagChips(run)
    if #chips == 0 then return nil end
    local words = {}
    for i, chip in ipairs(chips) do words[i] = chip.text end
    return table.concat(words, MIDDOT)
end

local function field(t, key)
    local v = type(t) == "table" and t[key] or nil
    return type(v) == "table" and v or {}
end

--- "104.2K DPS, +4.2% better than previous best (100.0K)" in the gain's green; the DPS alone, in
--- the text color, when there is no previous best to name.
--- @return string text, table color
local function detailText(run, pct, prev)
    local C = NS.ResultsTable.COLORS
    local dps = NS.Format.Number(field(run, "result").dps or 0)
    local prevDps = field(prev, "result").dps
    if type(pct) == "number" and type(prevDps) == "number" then
        local sign = pct < 0 and "" or "+"
        return L["%s DPS, %s better than previous best (%s)"]:format(dps, sign .. NS.Format.Pct(pct),
            NS.Format.Number(prevDps)), pct < 0 and C.red or C.green
    end
    return L["%s DPS"]:format(dps), C.text
end

--- "New best:" in the Spec best blue, as an escaped string.
local function titleText()
    local Tbl = NS.ResultsTable
    return ("|c%s%s|r"):format(Tbl.Hex(Tbl.COLORS.blue), L["New best:"])
end

--- The spec and the class ("Beast Mastery Hunter") in the class color, as an escaped string: the words
--- after the class and spec icons (DR-04).
local function whoText(char)
    local Tbl = NS.ResultsTable
    local class = Tbl.ClassName(char.class)
    local spec = char.spec and (tostring(char.spec) .. " " .. tostring(class or "")) or tostring(class or "?")
    return ("|c%s%s|r"):format(Tbl.Hex(Tbl.ClassColor(char.class)), (spec:gsub("%s+$", "")))
end

--- What the toast says about `run`, beating `prev` by `pct` percent: plain strings only.
--- @param run table  the run (complete, with a score)
--- @param pct number|nil  Bests.Delta's percentage
--- @param prev table|nil  the previous best (Bests.Delta's third return)
--- @return table payload  { runID, title, who, class, specIcon, chips = { { text, color } x2 },
---                          detail, detailColor, flags }
function BestToast.Payload(run, pct, prev)
    local Tbl = NS.ResultsTable
    local detail, detailColor = detailText(run, pct, prev)
    local _, targetColor = Tbl.Badge(run.target)
    local char = field(run, "char")
    local _, specIcon = Tbl.SpecInfo(char.specID, char.spec)
    return {
        runID       = run.id,
        title       = titleText(),
        -- The spec and class words, and what their two icons draw (DR-04): the class token (the
        -- character-creation atlas, Tbl.SetClassIcon) and the spec's icon (GetSpecializationInfoByID).
        who         = whoText(char),
        class       = char.class,
        specIcon    = specIcon,
        -- The target type and the race length as the Runs list's Target and Time chips color them.
        chips       = { { categoryText(run.target), targetColor },
                        { Tbl.LengthChip(field(run, "race").length) } },
        detail      = detail,
        detailColor = detailColor,
        flags       = flagsText(run),
    }
end

-- ── the content ─────────────────────────────────────────────────────────────────────────────────

--- A row's text in a slot `h` tall, its words centered in it, anchored once at `y` on the frame.
local function slotText(frame, font, color, x, y, h)
    local Style = NS.Style
    local fs = Style.ScaledText(frame, font, SCALE, color)
    fs:SetHeight(h)
    if fs.SetJustifyV then fs:SetJustifyV("MIDDLE") end
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    return fs
end

-- The rows, made once on the shell's frame (stashed on it) and filled on every toast. Every row is
-- anchored to the frame at its own y, so the gaps and the padding are the constants above and never
-- what a string measured.
local function makeRows(frame)
    local Style, B = NS.Style, BestToast
    local w = {}
    w.icon = frame:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(B.ROWS_H, B.ROWS_H)
    w.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", B.PAD, -B.PAD)
    w.icon:SetTexture(NS.Icon("ph:trophy") or TROPHY_FALLBACK)
    -- The trophy in the result card's *New best* blue (the Status column's Spec best: a data hue).
    Style.Vertex(w.icon, NS.ResultsTable.COLORS.blue, 1)
    local left = B.PAD + B.ROWS_H + B.GAP
    local chipY = -(B.PAD + B.TITLE_H + B.ROW_GAP)
    local detailY = chipY - B.CHIP_H - B.ROW_GAP
    -- The headline: "New best:", the class and spec icons, then the spec and class words. The first
    -- string has one point, so it is as wide as its words and the icons follow them.
    w.title = slotText(frame, Style.FONT.TITLE, nil, left, -B.PAD, B.TITLE_H)
    w.class = frame:CreateTexture(nil, "ARTWORK")
    w.class:SetSize(B.CLASS_ICON, B.CLASS_ICON)
    w.class:SetPoint("LEFT", w.title, "RIGHT", ICON_GAP, 0)
    w.spec = frame:CreateTexture(nil, "ARTWORK")
    w.spec:SetSize(B.CLASS_ICON, B.CLASS_ICON)
    w.spec:SetPoint("LEFT", w.class, "RIGHT", 2, 0)
    w.who = Style.ScaledText(frame, Style.FONT.TITLE, SCALE)
    w.who:SetHeight(B.TITLE_H)
    if w.who.SetJustifyV then w.who:SetJustifyV("MIDDLE") end
    w.who:SetPoint("LEFT", w.spec, "RIGHT", ICON_GAP, 0)
    w.who:SetPoint("RIGHT", frame, "RIGHT", -CLOSE_ROOM, 0)
    -- The target and time chips, boxed as the Runs list draws them (Tbl.Chip), at the toast's scale.
    w.chips = { NS.ResultsTable.Chip(frame, SCALE), NS.ResultsTable.Chip(frame, SCALE) }
    w.chips[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", left, chipY)
    w.chips[2]:SetPoint("LEFT", w.chips[1], "RIGHT", math.floor(NS.ResultsTable.CHIP_GAP * SCALE + 0.5), 0)
    w.detail = slotText(frame, Style.FONT.TEXT, nil, left, detailY, B.TEXT_H)
    w.detail:SetPoint("RIGHT", frame, "RIGHT", -B.PAD, 0)
    w.flags = slotText(frame, Style.FONT.TEXT, NS.HudStates.FLAG_COLOR, left, detailY - B.FLAGS_HEIGHT, B.TEXT_H)
    w.flags:SetPoint("RIGHT", frame, "RIGHT", -B.PAD, 0)
    frame.dpsRace = w
    return w
end

--- The class icon (the character-creation atlas) and the spec icon, each hidden when the client has
--- nothing to draw; a hidden one takes no room: each element anchors to the last one shown, so the
--- words close up on "New best:" one ICON_GAP away.
local function setIcons(frame, w, p)
    local hasClass = p.class ~= nil and NS.ResultsTable.SetClassIcon(w.class, p.class) or false
    if not hasClass then w.class:Hide() end
    local hasSpec = p.specIcon ~= nil
    w.spec:SetTexture(p.specIcon)
    w.spec:SetShown(hasSpec)
    w.spec:ClearAllPoints()
    if hasClass then
        w.spec:SetPoint("LEFT", w.class, "RIGHT", 2, 0)
    else
        w.spec:SetPoint("LEFT", w.title, "RIGHT", ICON_GAP, 0)
    end
    local last = hasSpec and w.spec or hasClass and w.class or w.title
    w.who:ClearAllPoints()
    w.who:SetPoint("LEFT", last, "RIGHT", ICON_GAP, 0)
    w.who:SetPoint("RIGHT", frame, "RIGHT", -CLOSE_ROOM, 0)
end

--- The shell's builder: fill the rows, answer the frame's size from the constants above.
local function build(frame, p)
    if type(p) ~= "table" then return false end
    local w = frame.dpsRace or makeRows(frame)
    w.title:SetText(p.title or "")
    w.who:SetText(p.who or "")
    setIcons(frame, w, p)
    local chips = type(p.chips) == "table" and p.chips or {}
    for i, chip in ipairs(w.chips) do
        local c = chips[i] or {}
        NS.ResultsTable.SetChip(chip, c[1], c[2])
    end
    w.detail:SetText(p.detail or "")
    NS.Style.Paint(w.detail, p.detailColor or NS.ResultsTable.COLORS.text)
    w.flags:SetText(p.flags or "")
    w.flags:SetShown(p.flags ~= nil)
    return BestToast.WIDTH, BestToast.HEIGHT + (p.flags and BestToast.FLAGS_HEIGHT or 0)
end

-- ── placement ───────────────────────────────────────────────────────────────────────────────────

local function store() return NS.db and NS.db.profile and NS.db.profile.toast end

-- A copy, so the shell never holds the profile's own table.
local function getPosition()
    local t = store()
    local pt = t and t.point
    if type(pt) ~= "table" then return nil end
    return { pt[1], pt[2], pt[3], pt[4] }
end

local function setPosition(pt)
    local t = store()
    if not t then return end
    if type(pt) ~= "table" then
        t.point = nil
        return
    end
    t.point = { tostring(pt[1]), tostring(pt[2] or pt[1]), tonumber(pt[3]) or 0, tonumber(pt[4]) or 0 }
end

-- The toast moves only while it is test mode's (the preview) or a sample from *Test toast*: a real
-- toast never shows in test mode (arming a race ends it), so the key is the whole rule.
local function draggable()
    local _, key = toast:Current()
    return key == BestToast.SAMPLE or key == NS.TOAST_PREVIEW
end

toast = NS.NewToast({
    name        = "DpsRaceBestToast",
    build       = build,
    width       = BestToast.WIDTH,
    height      = BestToast.HEIGHT,
    duration    = function() return setting("duration") end,
    scale       = function() return setting("scale") end,
    sound       = function() return setting("sound") end,
    draggable   = draggable,
    getPosition = getPosition,
    setPosition = setPosition,
    debug       = function(tag, fmt, ...) debug("%s " .. fmt, tag, ...) end,
})

-- ── the trigger ─────────────────────────────────────────────────────────────────────────────────

--- A resolved run: toast it when it is a new best over an earlier one.
--- @param run table
--- @return boolean shown  queued
function BestToast.OnResult(run)
    if not enabled() or type(run) ~= "table" or run.status ~= "complete" then return false end
    local pct, isNew, prev = NS.Bests.Delta(run)
    if not (isNew and pct ~= nil) then return false end
    debug("new best %s: %+.1f%%", tostring(run.id), pct)
    if run.sample then sampleKey = run.id end
    return toast:Show(BestToast.Payload(run, pct, prev), { key = run.id }) == true
end

do
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.RACE_RESULT, function(_, run) BestToast.OnResult(run) end)
        -- A profile switch or reset: its switch (a toast up goes, test mode's comes back), its scale
        -- and its point.
        bus:RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path)
            if path ~= "profile" then return end
            BestToast.Sync()
            BestToast.Refresh()
        end)
    end
end

-- ── test mode and the settings ──────────────────────────────────────────────────────────────────

--- Test mode's toast: `sample` (modules/Preview.lua's sample race: { run, delta, best }), sticky and
--- movable, until test mode ends. Nothing while the toast is turned off.
function BestToast.ShowPreview(sample)
    if type(sample) ~= "table" or type(sample.run) ~= "table" then return end
    preview = BestToast.Payload(sample.run, sample.delta, sample.best)
    if enabled() then toast:Preview(preview) end
end

--- Test mode or the sim ended: its toast goes.
function BestToast.EndPreview()
    preview = nil
    toast:Remove(NS.TOAST_PREVIEW)
    if sampleKey then toast:Remove(sampleKey) end
    sampleKey = nil
end

--- *Test toast*: a sample toast queued as a real one is (its countdown, its sound), movable while it
--- shows. A sample already waiting or on screen is replaced.
function BestToast.Test()
    local M = NS.MockRuns
    local length = M.LENGTH or 120
    local run = { id = BestToast.SAMPLE, status = "complete", char = M.Player(),
                  target = { category = "single" }, race = { length = length },
                  result = { dps = math.floor((M.DPS or 100000) * 1.042) } }
    local prev = { result = { dps = M.DPS or 100000 } }
    toast:Remove(BestToast.SAMPLE)
    return toast:Show(BestToast.Payload(run, 4.2, prev), { key = BestToast.SAMPLE })
end

--- *Show a toast for a new best* changed: off drops every toast, on brings test mode's back.
function BestToast.Sync()
    if not enabled() then
        toast:Clear()
    elseif preview and NS.Preview and NS.Preview.IsActive() then
        toast:Preview(preview)
    end
end

--- Re-read the scale and the stored point.
function BestToast.Refresh() toast:Refresh() end

--- *Reset position* (Master controls): the stored point goes, the toast goes back to the shell's.
function BestToast.ResetPosition() toast:ResetPosition() end

--- The stand-down: nothing on screen, nothing waiting.
function BestToast.Suspend()
    preview = nil
    toast:Clear()
end

--- The toast instance, for the suites.
function BestToast.Instance() return toast end

--- What the toast holds, for the diagnostics report and the suites.
function BestToast.Diagnose()
    local s = toast:Stats()
    return { shown = s.shown == true, waiting = s.waiting or 0, key = s.key, preview = preview ~= nil }
end
