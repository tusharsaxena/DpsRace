-- tests/test_hud_best.lua — the idle body's Your best card (R3-DR-4, Ka0sAddonsCommonTasks
-- docs/2026-11-02-SMOKE_ROUND3/R3_ADDENDUM_DPSRACE.md, image 101; modules/Hud_Best.lua): the best on
-- the board the next race would count on (spec | target category | length, Bests.Key), the same best
-- the live chart's pace reads, set between the Target card and Arm Race.
--
-- What this pins:
--   - the section names the board, "Your best · <spec> · <category> · <length>";
--   - the card: the best's DPS (large), its damage on the right, then date · ilvl · top spell;
--   - Arm Race reads "Arm Race · beat <DPS>" while a best exists, else "Arm Race";
--   - the empty states: "No race yet: this one sets the mark." and, with no target, "Target a dummy
--     to see your best.";
--   - it swaps at once on a length, Custom, a new target, a spec change and a board change;
--   - the hover names the whole run, the click opens it in Results;
--   - nothing above it moves, and the HUD's minimum size holds.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local CLEAVE = { guid = "Creature-0-1-2-3-243208-0001", name = "Cleave Training Dummy" }
local GOLEM = { guid = "Creature-0-1-2-3-243205-0001", name = "Reinforced Golem" }
local DOT = " \194\183 "

--- A race fixture with the widget recorder and a tooltip spy; the clock at 100.
local function hud()
    local W
    local f = RaceClock.new{ mutate = function(m) W = Widgets.install(m) end }
    f.W, f.Hud, f.States = W, f.NS.Hud, f.NS.HudStates
    local tip = { lines = {} }
    function tip.SetOwner(_, owner) tip.owner, tip.lines = owner, {} end
    function tip.SetText(_, text) tip.lines[1] = text end
    function tip.AddLine(_, text) tip.lines[#tip.lines + 1] = text end
    function tip.AddDoubleLine(_, a, b) tip.lines[#tip.lines + 1] = tostring(a) .. "|" .. tostring(b) end
    function tip.Show() end
    function tip.Hide() end
    f.M.GameTooltip, f.tip = tip, tip
    return f
end

local function ui(f) return assert(f.Hud.__ui(), "the HUD window was never built") end
local function idle(f)
    local u = ui(f)
    assertEqual(u.current, "idle")
    return u.body.idle.w
end

local function target(f, t)
    f.M.__setTarget(t)
    f.M.__fire("PLAYER_TARGET_CHANGED")
end

--- A complete run on the current spec and target at `length`, stored.
local function stored(f, length, dps, opts)
    opts = opts or {}
    local run = f.NS.Recorder.NewRun(length)
    run.status = "complete"
    run.result = { damage = dps * length, dps = dps }
    run.date = opts.date or 1762128000
    run.char.ilvl = 316.4
    run.spells = opts.spells or {
        { id = 116858, dmg = dps * length * 0.5, dps = dps * 0.5 },
        { id = 29722, dmg = dps * length * 0.3, dps = dps * 0.3 },
        { id = 348, dmg = dps * length * 0.15, dps = dps * 0.15 },
        { id = 17962, dmg = dps * length * 0.05, dps = dps * 0.05 },
    }
    assertTrue(f.NS.Recorder.Save(run))
    return run
end

local function fmt(f, n) return f.NS.Format.Number(n) end

-- ── the card ────────────────────────────────────────────────────────────────────────────────────

test("hud best: the board's best sits between Target and Arm Race, and Arm Race names it", function()
    -- red under: no Your best card (the idle body of image 101: presets, Target, Arm Race).
    local f = hud()
    target(f, CLEAVE)
    local best = stored(f, 60, 153900)
    f.Hud.Show()
    local w = idle(f)
    local b = assert(w.best, "no Your best section on the idle body")
    local spec = f.M.__context.spec
    assertEqual(b.caption.__text, "Your best" .. DOT .. spec .. DOT .. "Cleave" .. DOT .. "1:00")
    assertTrue(b.card:IsShown(), "the card shows")
    assertEqual(b.dps.__text, fmt(f, 153900), "the best's DPS")
    assertEqual(b.damage.__text, fmt(f, 153900 * 60), "its damage on the right")
    local line = b.line.__text
    assertTrue(line:find(f.NS.ResultsTable.Date(best.date, "%d %b"), 1, true) == 1, "the date first: " .. line)
    assertTrue(line:find("ilvl 316.4", 1, true) ~= nil, "the item level: " .. line)
    assertTrue(line:find("Chaos Bolt", 1, true) ~= nil, "the top spell: " .. line)
    assertFalse(b.empty:IsShown(), "no empty line over a best")
    assertEqual(w.arm.label.__text, "Arm Race" .. DOT .. "beat " .. fmt(f, 153900))
end)

test("hud best: with no race on the board, the card says this one sets the mark", function()
    local f = hud()
    target(f, CLEAVE)
    stored(f, 30, 99000)                     -- another length's best is not this board's
    f.Hud.Show()
    local b = idle(f).best
    assertEqual(b.caption.__text, "Your best" .. DOT .. f.M.__context.spec .. DOT .. "Cleave" .. DOT .. "1:00")
    assertTrue(b.empty:IsShown())
    assertEqual(b.empty.__text, "No race yet: this one sets the mark.")
    assertFalse(b.dps:IsShown(), "no figure without a best")
    assertEqual(idle(f).arm.label.__text, "Arm Race")
end)

test("hud best: with no target, it asks for a dummy", function()
    local f = hud()
    target(f, nil)
    f.Hud.Show()
    local b = idle(f).best
    assertEqual(b.caption.__text, "Your best")
    assertTrue(b.empty:IsShown())
    assertEqual(b.empty.__text, "Target a dummy to see your best.")
    assertEqual(idle(f).arm.label.__text, "Arm Race")
end)

-- ── live ────────────────────────────────────────────────────────────────────────────────────────

test("hud best: it swaps at once on a length, Custom, a new target, a spec change and a board change", function()
    local f = hud()
    target(f, CLEAVE)
    local one = stored(f, 60, 153900)
    stored(f, 30, 120000)
    stored(f, 90, 110000)
    f.Hud.Show()
    local b = idle(f).best
    assertEqual(b.dps.__text, fmt(f, 153900))
    f.Hud.Act.pickLength(30)
    assertEqual(b.dps.__text, fmt(f, 120000), "a length button")
    assertTrue(b.caption.__text:find("0:30", 1, true) ~= nil)
    assertTrue(f.Hud.Act.customLength("1:30"))
    assertEqual(b.dps.__text, fmt(f, 110000), "Custom")
    f.Hud.Act.pickLength(60)
    target(f, GOLEM)
    assertTrue(b.empty:IsShown(), "a new target on another board")
    target(f, CLEAVE)
    assertEqual(b.dps.__text, fmt(f, 153900))
    local spec, specID = f.M.__context.spec, f.M.__context.specID
    f.M.__context.spec, f.M.__context.specID = "Affliction", 265
    f.M.__fire("PLAYER_SPECIALIZATION_CHANGED", "player")
    assertTrue(b.empty:IsShown(), "a spec change")
    assertTrue(b.caption.__text:find("Affliction", 1, true) ~= nil)
    f.M.__context.spec, f.M.__context.specID = spec, specID
    f.M.__fire("PLAYER_SPECIALIZATION_CHANGED", "player")
    assertEqual(b.dps.__text, fmt(f, 153900))
    assertTrue(f.NS.Recorder.Delete(one.id))
    assertTrue(b.empty:IsShown(), "the board invalidated: its best deleted")
    assertEqual(idle(f).arm.label.__text, "Arm Race")
end)

-- ── hover and click ─────────────────────────────────────────────────────────────────────────────

test("hud best: the hover names the whole run, the click opens it in Results", function()
    local f = hud()
    target(f, CLEAVE)
    local best = stored(f, 60, 153900)
    f.Hud.Show()
    local b = idle(f).best
    b.card:__fire("OnEnter")
    assertEqual(f.tip.owner, b.card)
    local all = table.concat(f.tip.lines, "\n")
    assertEqual(f.tip.lines[1], "Your best")
    for _, want in ipairs({ f.NS.ResultsTable.Date(best.date, "%d %b %Y %H:%M"), "1:00", fmt(f, 153900 * 60),
                            fmt(f, 153900), "Chaos Bolt", "Incinerate", "Immolate" }) do
        assertTrue(all:find(want, 1, true) ~= nil, "the tooltip names " .. want .. ":\n" .. all)
    end
    assertTrue(all:find("Conflagrate", 1, true) == nil, "top 3 spells only")
    local opened
    f.NS.Results = f.NS.Results or {}
    local real = f.NS.Results.ShowRun
    f.NS.Results.ShowRun = function(id) opened = id end
    b.card:__fire("OnMouseUp", "LeftButton")
    f.NS.Results.ShowRun = real
    assertEqual(opened, best.id, "the click opens the run")
end)

-- ── layout ──────────────────────────────────────────────────────────────────────────────────────

--- The y of `region`'s anchor at `point`.
local function yAt(region, point)
    for _, p in ipairs(region.__points or {}) do
        if p[1] == point then return p[5] end
    end
end

test("hud best: every launcher block sits the same gap apart, with more above Arm Race (R4-DR2)", function()
    local f = hud()
    local S = f.States
    target(f, CLEAVE)
    f.Hud.Show()
    local w = idle(f)
    -- Race Length's block ends with its second row of presets (14 + 20 + 6 + 20 = 60).
    local presetsEnd = 14 + 20 + 6 + 20
    local targetEnd = -yAt(w.card.frame, "TOPLEFT") + 46
    assertEqual(-yAt(w.targetCap, "TOPLEFT") - presetsEnd, S.BLOCK_GAP, "Race Length to Target")
    assertEqual(-yAt(w.best.caption, "TOPLEFT") - targetEnd, S.BLOCK_GAP, "Target to Your best")
    assertEqual(-yAt(w.best.caption, "TOPLEFT"), S.IDLE_BEST_Y_PLAIN)
    assertEqual(-yAt(w.best.card, "TOPLEFT"), S.IDLE_BEST_Y_PLAIN + S.BEST_CAPTION_H, "the card under its caption")
    local bestEnd = -yAt(w.best.card, "TOPLEFT") + S.BEST_CARD_H
    assertEqual(-yAt(w.arm, "TOPLEFT"), bestEnd + S.ARM_GAP, "the extra room above Arm Race")
    assertEqual(-yAt(w.arm, "TOPRIGHT"), S.IDLE_ARM_Y_PLAIN)
    -- No target: the amber warning shows under the Target card, and Your best and Arm Race step down.
    target(f, nil)
    assertTrue(w.warn.__text ~= "", "the warning shows")
    assertEqual(-yAt(w.best.caption, "TOPLEFT"), S.IDLE_BEST_Y_WARNED)
    assertEqual(-yAt(w.best.card, "TOPLEFT"), S.IDLE_BEST_Y_WARNED + S.BEST_CAPTION_H)
    assertEqual(-yAt(w.arm, "TOPLEFT"), S.IDLE_ARM_Y)
    -- A cataloged dummy again: the block moves back up.
    target(f, CLEAVE)
    assertEqual(w.warn.__text, "")
    assertEqual(-yAt(w.best.caption, "TOPLEFT"), S.IDLE_BEST_Y_PLAIN)
    assertEqual(-yAt(w.arm, "TOPLEFT"), S.IDLE_ARM_Y_PLAIN)
end)

test("hud best: nothing above it moves, it fits the width, and the minimum size holds", function()
    local f = hud()
    local S = f.States
    -- The blocks (a caption and its boxes) sit BLOCK_GAP apart, Arm Race ARM_GAP under the last
    -- (R4-DR2); under the amber warning Arm Race keeps its old place, so the minimum height holds.
    assertEqual(S.BEST_H, S.BEST_CAPTION_H + S.BEST_CARD_H, "the block: its caption and its card")
    assertEqual(S.IDLE_ARM_Y_PLAIN, S.IDLE_BEST_Y_PLAIN + S.BEST_H + S.ARM_GAP)
    assertTrue(S.ARM_GAP > S.BLOCK_GAP, "a little extra above Arm Race")
    assertTrue(S.IDLE_ARM_Y >= S.IDLE_BEST_Y_WARNED + S.BEST_H + S.BLOCK_GAP, "under the warning too")
    assertEqual(f.Hud.MIN_HEIGHT, 354, "the HUD's minimum height is unchanged")
    target(f, CLEAVE)
    stored(f, 60, 153900)
    f.Hud.Show()
    local b = idle(f).best
    -- Both sides anchored: it takes the window's width, and the line truncates instead of wrapping.
    local sides = {}
    for _, p in ipairs(b.card.__points) do sides[p[1]] = true end
    assertTrue(sides.TOPLEFT and sides.TOPRIGHT, "the card spans the body")
    assertEqual(b.line.__wrap, false, "line two truncates")
end)
