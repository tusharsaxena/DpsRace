-- tests/test_hud_tips.lua — the Race HUD's spell tooltips (DR-03, the owner's call, 2026-10-30): a
-- spell row's hover on the running body (live, its spell ID secret) and on the result card (a read
-- result's plain record) shows the client's full spell tooltip right of the HUD window, level with the
-- row, never at the cursor; the live ID reaches the client untouched and no secret geometry is read.
-- The chart's cooldown icons are tests/test_chart_icons.lua's.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local METER_EVENT = "DAMAGE_METER_COMBAT_SESSION_UPDATED"

--- A race fixture with the widget recorder; the clock at 100.
local function hud()
    local W
    local f = RaceClock.new{ mutate = function(m) W = Widgets.install(m) end }
    f.W, f.Hud = W, f.NS.Hud
    return f
end

local function ui(f) return assert(f.Hud.__ui(), "the HUD window was never built") end
local function body(f) local u = ui(f) return u.body[u.current] end

--- Armed, the clock running from 100 with session 25 (in combat, the meter secret).
local function running(f, length)
    assertTrue(f:arm(length or 30))
    f:start(25)
    assertEqual(f.Race.State(), "running")
end

local function pump(f, seconds)
    for _ = 1, math.floor(seconds * 16 + 0.5) do
        f:advance(1 / 16)
        f.M.__fire(METER_EVENT, 0, 25)
        f.Hud.Tick()
    end
end

--- The run read and shown: armed 30s, running, a tail update, the buzzer, combat over, read.
local function resolved(f)
    running(f, 30)
    f:to(129.5)
    f:update(25)
    f:to(130)
    f:advance(1)
    f:update(25)
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
    return f.Race.Current()
end

-- A recording GameTooltip; `secretWidth` makes its width a secret, as a tooltip showing a secret
-- spell would answer it. Answers the tip.
local function recordingTip(f, secretWidth)
    local tip = { lines = {} }
    for _, m in ipairs({ "Show", "Hide", "ClearAllPoints" }) do tip[m] = function() end end
    function tip.SetOwner(_, owner, anchor) tip.owner, tip.anchor, tip.lines, tip.spell = owner, anchor, {}, nil end
    function tip.SetSpellByID(_, id) tip.spell, tip.lines[1] = id, "the client's spell text" end
    function tip.SetText(_, text) tip.lines[1] = text end
    function tip.AddLine(_, text) tip.lines[#tip.lines + 1] = text end
    function tip.NumLines() return #tip.lines end
    function tip.SetPoint(_, ...) tip.placed = { ... } end
    function tip.GetWidth() return secretWidth and T.secret(300) or 300 end
    function tip.GetEffectiveScale() return 1 end
    f.M.GameTooltip = tip
    f.M.UIParent.GetRight = function() return 1920 end
    f.M.UIParent.GetEffectiveScale = function() return 1 end
    return tip
end

test("hud: a live spell row's hover shows the client's spell tooltip right of the HUD, its secret ID untouched", function()
    local f = hud()
    running(f, 30)
    pump(f, 1)
    local b = body(f)
    local row = b.w.list.rows[1]
    assertTrue(row.__mouse, "a live row takes the mouse (DR-03)")
    assertTrue(T.isSecret(row.liveID), "the row holds the meter's secret spell ID")
    local tip = recordingTip(f, true)
    local frame = ui(f).frame
    rawset(frame, "GetRight", function() return 600 end)
    row:GetScript("OnEnter")(row)
    assertTrue(tip.owner == frame and tip.anchor == "ANCHOR_NONE", "owned by the HUD, never the cursor")
    assertTrue(T.isSecret(tip.spell) and T.reveal(tip.spell) == 29722, "the secret ID handed to the client as is")
    assertEqual(#tip.lines, 1, "the client's tooltip alone: no figure of a live value")
    assertTrue(tip.placed[1] == "TOPLEFT" and tip.placed[2] == frame and tip.placed[3] == "TOPRIGHT",
        "right of the HUD, its secret width read as nothing")
    row:GetScript("OnLeave")(row)
    assertEqual(#f.W.SecretGeometryReads(), 0)
end)

test("hud: a result row's hover shows the spell tooltip right of the HUD, then its damage and share", function()
    local f = hud()
    local run = resolved(f)
    local b = body(f)
    local row = b.w.list.rows[1]
    assertTrue(row.__mouse and row.spell ~= nil, "a result row takes the mouse")
    assertNil(row.liveID, "a pooled row keeps no live ID past the race")
    local tip = recordingTip(f)
    local frame = ui(f).frame
    rawset(frame, "GetRight", function() return 600 end)
    rawset(frame, "GetTop", function() return 800 end)
    rawset(row, "GetTop", function() return 650 end)
    row:GetScript("OnEnter")(row)
    assertTrue(tip.owner == frame and tip.anchor == "ANCHOR_NONE", "owned by the HUD")
    assertEqual(tip.spell, run.spells[1].id, "the client's spell tooltip")
    assertTrue(tip.placed[1] == "TOPLEFT" and tip.placed[2] == frame and tip.placed[3] == "TOPRIGHT", "right of the HUD")
    assertEqual(tip.placed[5], -150, "level with the row")
    local want = f.NS.ResultsTips.Spell(run.spells[1], run, 1, #run.spells)
    assertEqual(#tip.lines, 2 + #want, "the spell's text, a spacer, then the run's lines")
    -- Against the screen's right edge: left of the HUD.
    rawset(frame, "GetRight", function() return 1800 end)
    row:GetScript("OnEnter")(row)
    assertTrue(tip.placed[1] == "TOPRIGHT" and tip.placed[3] == "TOPLEFT", "left of it without the room")
end)
