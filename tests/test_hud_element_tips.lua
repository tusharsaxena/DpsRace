-- tests/test_hud_element_tips.lua — a tooltip on every main element of the Race HUD, in all its bodies
-- (DR-F04, the owner's batch of 2026-10-31). Each goes through the buttons' path (Hud_States' showTip,
-- States.AddTip), so its lines are the skin's gtip tokens; none reads a live value. The spell rows and
-- the chart's icons are tests/test_hud_tips.lua's and tests/test_chart_icons.lua's.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local function inst()
    local W
    local i = T.load{ mutate = function(m) W = Widgets.install(m) end }
    local tip = { lines = {}, colors = {}, shown = 0, hidden = 0 }
    function tip.SetOwner(_, owner, anchor) tip.owner, tip.anchor, tip.lines = owner, anchor, {} end
    function tip.SetText(_, text, r, g, b) tip.lines[1], tip.title = text, { r, g, b } end
    function tip.AddLine(_, text, r, g, b)
        tip.lines[#tip.lines + 1] = text
        tip.colors[#tip.lines] = { r, g, b }
    end
    function tip.Show() tip.shown = tip.shown + 1 end
    function tip.Hide() tip.hidden = tip.hidden + 1 end
    i.mocks.GameTooltip, i.tip, i.W = tip, tip, W
    return i
end

local function body(i, key)
    local parent = i.mocks.CreateFrame("Frame")
    return i.NS.HudStates.Build(key, parent)
end

-- `frame` shows a tooltip titled `title` with a body line in the skin's color, and takes it down on leave.
local function hasTip(i, frame, title, what)
    assertTrue(frame ~= nil, what .. ": no frame")
    i.tip.lines, i.tip.owner = {}, nil
    frame:__fire("OnEnter")
    assertEqual(i.tip.owner, frame, what .. ": the tooltip's owner")
    assertEqual(i.tip.lines[1], title, what .. ": the title")
    assertTrue(type(i.tip.lines[2]) == "string" and #i.tip.lines[2] > 10, what .. ": a line saying what it is")
    local want = { i.NS.Style.Rgb("gtip.title") }
    assertEqual(i.tip.colors[2][1], want[1], what .. ": the skin's tooltip color")
    local hidden = i.tip.hidden
    frame:__fire("OnLeave")
    assertEqual(i.tip.hidden, hidden + 1, what .. ": left up on leave")
end

test("hud tips: the idle body names every length, the target, Arm and Results", function()
    local i = inst()
    local w = body(i, "idle").w
    hasTip(i, w.lengthTip, "Race Length", "the caption")
    for k, b in ipairs(w.presets) do hasTip(i, b, i.NS.Format.Length(i.NS.HudStates.PRESETS[k]), "preset " .. k) end
    hasTip(i, w.custom, "Custom", "Custom")
    hasTip(i, w.customBox, "Custom length", "the custom box")
    hasTip(i, w.targetTip, "Target", "the caption")
    hasTip(i, w.card.frame, "Target", "the target card")
    hasTip(i, w.arm, "Arm Race", "Arm")
    hasTip(i, w.results, "Results", "Results")
end)

test("hud tips: the armed body names its clock, target and Cancel", function()
    local i = inst()
    local w = body(i, "armed").w
    hasTip(i, w.clockTip, "Race Length", "the clock")
    hasTip(i, w.subTip, "First hit", "the line under it")
    hasTip(i, w.card.frame, "Target", "the target card")
    hasTip(i, w.cancel, "Cancel", "Cancel")
end)

test("hud tips: the running body names its clocks, figures, chart, pace bar, headings and captions", function()
    local i = inst()
    local w = body(i, "running").w
    hasTip(i, w.clockTip, "Race clock", "the one clock")
    hasTip(i, w.elapsedTip, "Elapsed", "elapsed")
    hasTip(i, w.leftTip, "Time left", "left")
    hasTip(i, w.damage.frame, "Damage", "damage")
    hasTip(i, w.dps.frame, "DPS", "dps")
    hasTip(i, w.chart.headZones[1], "Damage profile", "the heading")
    hasTip(i, w.chart.headZones[2], "Pace bar", "the heading's note")
    hasTip(i, w.chart.over, "Damage profile", "the plot")
    hasTip(i, w.pace.over, "Pace bar", "the pace bar")
    hasTip(i, w.spellsTip, "Spell breakdown", "the heading")
    hasTip(i, w.orderTip, "Live order", "the order caption")
    hasTip(i, w.countTip, "Spell rows", "the row count")
    hasTip(i, w.cancel, "Cancel", "Cancel")
end)

test("hud tips: a clock's tooltip goes with the clock when the mode changes", function()
    local i = inst()
    local b = body(i, "running")
    local w = b.w
    b:Layout(260, 500)
    local function draw(mode)
        b:Update({ clockMode = mode, timeLeft = 5, elapsed = 25, rows = 8, run = {} })
    end
    draw("both")
    assertTrue(w.elapsedTip:IsShown())
    assertTrue(w.leftTip:IsShown())
    assertEqual(w.clockTip:IsShown(), false, "the one clock's zone over nothing")
    draw("left")
    assertEqual(w.elapsedTip:IsShown(), false, "elapsed's zone over nothing")
    assertEqual(w.leftTip:IsShown(), false, "left's zone over nothing")
    assertTrue(w.clockTip:IsShown())
    assertEqual(w.clockTip.tip[1], "Time left")
    draw("elapsed")
    assertEqual(w.clockTip.tip[1], "Elapsed")
end)

test("hud tips: the Stop! and waiting tiles say which reading they show", function()
    local i = inst()
    for _, key in ipairs({ "stop", "waiting" }) do
        local b = body(i, key)
        b:Update({ tail = 3, sinceBuzzer = 2, inCombat = true, grace = 1.5 })
        hasTip(i, b.w.tail.frame, "Damage Stopped", key .. " tail")
        hasTip(i, b.w.combat.frame, "In Combat", key .. " combat")
        b:Update({ endedEarly = true, endedAt = 12, inCombat = false, grace = 1.5 })
        hasTip(i, b.w.tail.frame, "Combat Ended", key .. " early end")
        hasTip(i, b.w.combat.frame, "Out of Combat", key .. " out of combat")
        hasTip(i, b.w.stopNow, "Stop Now", key .. " Stop Now")
        hasTip(i, b.w.cancel, "Cancel", key .. " Cancel")
    end
    hasTip(i, body(i, "stop").w.bigTip, "STOP", "STOP")
    hasTip(i, body(i, "waiting").w.titleTip, "Result pending", "the waiting title")
end)

test("hud tips: the Stop! chips and the result's verdict chip say what they count", function()
    local i = inst()
    local b = body(i, "stop")
    local got = {}
    local set = b.w.chips.Set
    b.w.chips.Set = function(self, list) got = list return set(self, list) end
    b:Update({ tail = 3, inCombat = true, grace = 1.5, lateCasts = { { spellID = 1, t = 2 } } })
    assertEqual(#got, 2)
    assertTrue(type(got[1].tip) == "string" and #got[1].tip > 10, "the late casts chip")
    assertTrue(type(got[2].tip) == "string" and #got[2].tip > 10, "the grace chip")
    local run = { status = "ok", flags = {}, result = { damage = 1, dps = 1 } }
    local States = i.NS.HudStates
    assertTrue(type(States.ResultChips({ run = run, isNew = true })[1].tip) == "string", "the new-best chip")
    assertTrue(type(States.ResultChips({ run = run, delta = -3 })[1].tip) == "string", "the behind chip")
end)

test("hud tips: the verdict chip's words hold when there was no best to beat, and on a tie", function()
    local i = inst()
    local States, Tips = i.NS.HudStates, i.NS.HudTips
    local run = { status = "ok", flags = {}, result = { damage = 1, dps = 1 } }
    local beat = States.ResultChips({ run = run, isNew = true, delta = 4.2 })[1]
    assertEqual(beat.text, "New best +4.2%")
    assertEqual(beat.tip, Tips.newBestChip)
    -- Bests.Delta's (nil, true): the first complete run on a board, or an earlier best of 0 DPS.
    local first = States.ResultChips({ run = run, isNew = true })[1]
    assertEqual(first.text, "New best")
    assertTrue(type(Tips.firstBestChip) == "string", "the words of a best with nothing to beat")
    assertEqual(first.tip, Tips.firstBestChip)
    local behind = States.ResultChips({ run = run, delta = -3 })[1]
    assertEqual(behind.tip, Tips.behindChip)
    -- Delta 0 and not new: it matched the best, so it neither fell short nor reads as a loss.
    local tied = States.ResultChips({ run = run, delta = 0 })[1]
    assertEqual(tied.text, "+0.0% vs best")
    assertTrue(type(Tips.tiedChip) == "string", "the words of a tie")
    assertEqual(tied.tip, Tips.tiedChip)
    assertTrue(tied.color ~= behind.color, "a tie is not drawn as falling short")
end)

test("hud tips: the result card names its figures, chart, pace bar, heading and four buttons", function()
    local i = inst()
    local w = body(i, "result").w
    hasTip(i, w.damage.frame, "Damage", "damage")
    hasTip(i, w.dps.frame, "DPS", "dps")
    hasTip(i, w.chart.headZones[1], "Damage profile", "the heading")
    hasTip(i, w.chart.over, "Damage profile", "the plot")
    hasTip(i, w.pace.over, "Pace bar", "the pace bar")
    hasTip(i, w.spellsTip, "Spell breakdown", "the heading")
    hasTip(i, w.newRace, "New Race", "New Race")
    hasTip(i, w.details, "Details", "Details")
    hasTip(i, w.share, "Share", "Share")
    hasTip(i, w.delete, "Delete", "Delete")
end)

test("hud tips: a heading's zone hides with its heading", function()
    local i = inst()
    local w = body(i, "result").w
    w.chart:SetParts(false, false)
    assertEqual(w.chart.headZones[1]:IsShown(), false, "the zone over a hidden heading")
    w.chart:SetParts(true, false)
    assertTrue(w.chart.headZones[1]:IsShown())
    local b = body(i, "result")
    b:Update({ run = { status = "lost" } })
    assertEqual(b.w.spellsTip:IsShown(), false, "the heading is hidden on a lost run")
end)

test("hud tips: the title bar's controls and the footer's lines", function()
    local i = inst()
    i.NS.Hud.Show()
    local u = assert(i.NS.Hud.__ui(), "the HUD window was never built")
    hasTip(i, u.close, "Close", "the close control")
    hasTip(i, u.footLeftTip, "Character", "the footer's left")
    hasTip(i, u.footRightTip, "Status", "the footer's right")
    for _, b in ipairs({ u.lock, u.settings, u.results }) do
        assertTrue(type(b.tip) == "string" and #b.tip > 0, "a title-bar control keeps its tooltip")
    end
end)

test("hud tips: hovering a live figure hands the tooltip its fixed lines and reads no geometry", function()
    -- red under: a tooltip reading the live value, which is secret for the whole pull.
    local i = inst()
    local b = body(i, "running")
    b:Layout(260, 500)
    b:SetLive({ total = T.secret(1234), dps = T.secret(99), spells = {} }, 8, true)
    local reads = #i.W.geomReads
    for _, frame in ipairs({ b.w.damage.frame, b.w.dps.frame, b.w.pace.over, b.w.chart.over }) do
        frame:__fire("OnEnter")
        for _, line in ipairs(i.tip.lines) do assertTrue(type(line) == "string", "a plain line") end
    end
    assertEqual(#i.W.geomReads, reads, "a hover measured something")
end)
