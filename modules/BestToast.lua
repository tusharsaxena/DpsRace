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

local BestToast = {}
NS.BestToast = BestToast

local L = NS.L
local MIDDOT = " \194\183 "

-- The key a sample from *Test toast* queues under.
BestToast.SAMPLE = "sample"

-- The frame's geometry (the shell's frame; the close mark is the shell's, top-right, 18 px, 4 px in).
local PAD, ICON, GAP, LINE_GAP = 10, 28, 8, 4
local CLOSE_ROOM = 26                   -- the title's right inset, clear of the close mark
BestToast.WIDTH = 340
BestToast.HEIGHT = 52                   -- the title and the detail
BestToast.FLAGS_HEIGHT = 16             -- the flags' line, when the run has any
local TROPHY_FALLBACK = "Interface\\Icons\\Achievement_Dungeon_GloryoftheHero"

local toast       -- the shell's instance (or the seam's stub)
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
    if (target.category == nil or target.category == "other") and target.name then return target.name end
    return NS.Dummies.Label(target.category)
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

--- "1:00 · 104.2K DPS, +4.2% over 100.0K"; without the gain when there is no previous best to name.
local function detailText(run, pct, prev)
    local dps = field(run, "result").dps or 0
    local prevDps = field(prev, "result").dps
    local text = L["%s DPS"]:format(NS.Format.Number(dps))
    if type(pct) == "number" and type(prevDps) == "number" then
        text = L["%s DPS, %s over %s"]:format(NS.Format.Number(dps), "+" .. NS.Format.Pct(pct),
            NS.Format.Number(prevDps))
    end
    return NS.Format.Length(field(run, "race").length) .. MIDDOT .. text
end

--- What the toast says about `run`, beating `prev` by `pct` percent: plain strings only.
--- @param run table  the run (complete, with a score)
--- @param pct number|nil  Bests.Delta's percentage
--- @param prev table|nil  the previous best (Bests.Delta's third return)
--- @return table payload  { runID, title, detail, flags }
function BestToast.Payload(run, pct, prev)
    local char = field(run, "char")
    return {
        runID  = run.id,
        title  = L["New best: %s (%s)"]:format(tostring(char.spec or char.class or "?"), categoryText(run.target)),
        detail = detailText(run, pct, prev),
        flags  = flagsText(run),
    }
end

-- ── the content ─────────────────────────────────────────────────────────────────────────────────

-- The rows, made once on the shell's frame (stashed on it) and filled on every toast.
local function makeRows(frame)
    local Style = NS.Style
    local w = {}
    w.icon = frame:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(ICON, ICON)
    w.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
    w.icon:SetTexture(NS.Icon("ph:trophy") or TROPHY_FALLBACK)
    w.icon:SetVertexColor(Style.GOLD[1], Style.GOLD[2], Style.GOLD[3])
    local left = PAD + ICON + GAP
    w.title = Style.Text(frame, Style.FONT.TITLE)
    w.title:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -PAD)
    w.title:SetPoint("RIGHT", frame, "RIGHT", -CLOSE_ROOM, 0)
    w.detail = Style.Text(frame, Style.FONT.TEXT)
    w.detail:SetPoint("TOPLEFT", w.title, "BOTTOMLEFT", 0, -LINE_GAP)
    w.detail:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    w.flags = Style.Text(frame, Style.FONT.TEXT, NS.HudStates.FLAG_COLOR)
    w.flags:SetPoint("TOPLEFT", w.detail, "BOTTOMLEFT", 0, -LINE_GAP)
    w.flags:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    frame.dpsRace = w
    return w
end

--- The shell's builder: fill the rows, answer the frame's size from the constants above.
local function build(frame, p)
    if type(p) ~= "table" then return false end
    local w = frame.dpsRace or makeRows(frame)
    w.title:SetText(p.title or "")
    w.detail:SetText(p.detail or "")
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
    return toast:Show(BestToast.Payload(run, pct, prev), { key = run.id }) == true
end

do
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.RACE_RESULT, function(_, run) BestToast.OnResult(run) end)
        -- A profile switch or reset: its scale and its point.
        bus:RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path)
            if path == "profile" then BestToast.Refresh() end
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

--- Test mode ended: its toast goes.
function BestToast.EndPreview()
    preview = nil
    toast:Remove(NS.TOAST_PREVIEW)
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
