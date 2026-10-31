-- tests/test_hud_window.lua — the Race HUD's window (modules/Hud.lua, spec §6.1): lock, scale, position,
-- visibility, the stand-down, the collection's look and HUD Appearance. Peeled out of tests/test_hud.lua
-- (layout-§1); the helpers are that suite's.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local METER_EVENT = "DAMAGE_METER_COMBAT_SESSION_UPDATED"

--- A race fixture with the widget recorder; the clock at 100.
local function hud(opts)
    opts = opts or {}
    local W
    local f = RaceClock.new{ enable = opts.enable, mutate = function(m)
        W = Widgets.install(m)
        if opts.mutate then opts.mutate(m) end
    end }
    f.W, f.Hud = W, f.NS.Hud
    return f
end

local function ui(f) return assert(f.Hud.__ui(), "the HUD window was never built") end
local function current(f) return ui(f).current end
local function body(f) local u = ui(f) return u.body[u.current] end

--- One OnUpdate pass of the countdown driver (what the client runs at 20 Hz).
local function tick(f) f.Hud.Tick() end

--- Armed, the clock running from 100 with session 25 (in combat, the meter secret).
local function running(f, length)
    assertTrue(f:arm(length or 30))
    f:start(25)
    assertEqual(f.Race.State(), "running")
end

--- Drive 2.5s of running at 16 meter updates a second with a countdown tick on each.
local function pump(f, seconds)
    local steps = math.floor(seconds * 16 + 0.5)
    for _ = 1, steps do
        f:advance(1 / 16)
        f.M.__fire(METER_EVENT, 0, 25)
        tick(f)
    end
end

-- The window's chrome above and below the content (title bar + gap, footer + gap) and each body's
-- fixed stack around its spell rows, as laid out in modules/Hud.lua and modules/Hud_States.lua.
-- The 30px title bar + 10, the 20px footer + 8; 18px rows on a 20px pitch; 20px buttons.
local CHROME, PITCH = 40 + 28, 20
-- The rows' top: the KPIs (and the chips), then the Spell breakdown heading (Round C): its 22px line
-- and the 6px that, with the GAP above, makes the shared 14px of clear space.
local BREAKDOWN = 6 + 22
local RUNNING_TOP, RUNNING_BOTTOM = 106 + BREAKDOWN, 42
local RESULT_TOP, RESULT_BOTTOM = 80 + BREAKDOWN, 28   -- under one chip line (Chips:Bottom)

local function session(n)
    local s = { damage = 9000000, dps = 300000, duration = 30, spells = {} }
    for i = 1, n do s.spells[i] = { id = 2000 + i, dmg = 1000000 - i, dps = 1000 } end
    return s
end

-- ── the window ──────────────────────────────────────────────────────────────────────────────────

test("hud: the window is skinned, closable with Escape, resizable and clamped", function()
    local f = hud()
    f.Hud.Show()
    local u = ui(f)
    local found = false
    for _, name in ipairs(f.M.UISpecialFrames) do if name == "DpsRaceHud" then found = true end end
    assertTrue(found, "not in UISpecialFrames")
    assertTrue(u.frame.resizeGrip ~= nil, "no sizing grip")
    assertTrue(u.close ~= nil, "no close control")
    assertTrue(u.frame.innerBorder ~= nil, "the Ka0s window edge was not applied")
    assertEqual(u.frame.title.__text, "DPS Race")
    u.close:__fire("OnClick")
    assertFalse(f.Hud.IsShown())
    assertFalse(u.frame:IsShown())
end)

test("hud: Lock frame, Master scale and Reset position act on the window", function()
    local f = hud()
    f.Hud.Show()
    local u = ui(f)
    assertTrue(f.NS.SetByPath("locked", true))
    assertTrue(f.Hud.locked)
    assertFalse(u.frame.resizeGrip:IsShown(), "the grip shows while locked")
    assertEqual(u.lock.iconName, "lock")
    assertTrue(f.NS.SetByPath("locked", false))
    assertTrue(u.frame.resizeGrip:IsShown())
    assertEqual(u.lock.iconName, "unlock")
    assertTrue(f.NS.SetByPath("scale", 1.5))
    assertEqual(u.frame.__scale, 1.5)

    local w = f.NS.db.profile.windows.hud
    w.point, w.x, w.y, w.width = "TOPLEFT", 40, -60, 420
    f.Hud.ResetPosition()
    assertEqual(w.point, nil)
    assertEqual(w.x, nil)
    assertEqual(w.width, nil)
end)

test("hud: dragging is refused while locked and the position is stored when it ends", function()
    local f = hud()
    f.Hud.Show()
    local u = ui(f)
    local moved = 0
    rawset(u.frame, "StartMoving", function() moved = moved + 1 end)
    rawset(u.frame, "GetPoint", function() return "TOPLEFT", nil, "BOTTOMLEFT", 123.4, 456.6 end)
    f.NS.SetByPath("locked", true)
    u.drag:__fire("OnDragStart")
    assertEqual(moved, 0)
    f.NS.SetByPath("locked", false)
    u.drag:__fire("OnDragStart")
    u.drag:__fire("OnDragStop")
    assertEqual(moved, 1)
    local w = f.NS.db.profile.windows.hud
    assertEqual(w.point, "TOPLEFT")
    assertEqual(w.relativePoint, "BOTTOMLEFT")
    assertEqual(w.x, 123)
    assertEqual(w.y, 457)
end)

test("hud: General visibility and the stand-down hide it at the source", function()
    local f = hud()
    f.Hud.Show()
    assertTrue(ui(f).frame:IsShown())
    assertTrue(f.NS.SetByPath("visibility", "never"))
    assertFalse(f.Hud.IsShown())
    assertFalse(ui(f).frame:IsShown())
    assertTrue(f.NS.SetByPath("visibility", "always"))
    assertTrue(ui(f).frame:IsShown())
end)

test("hud: onArm shows it on arm and hides it when the race it opened for is canceled", function()
    local f = hud()
    assertFalse(f.Hud.IsShown())
    assertTrue(f:arm(30))
    assertTrue(f.Hud.IsShown(), "arming did not show the HUD")
    f.Race.Cancel()
    assertFalse(f.Hud.IsShown(), "onArm left the window up after the cancel")

    f.Hud.Show()
    assertTrue(f:arm(30))
    f.Race.Cancel()
    assertTrue(f.Hud.IsShown(), "a window the player opened was closed for them")
end)

test("hud: showMode always shows it at login", function()
    local f = hud{ enable = false }
    f.NS.db.profile.hud.showMode = "always"
    f:enable()
    assertTrue(f.Hud.IsShown())
    assertTrue(ui(f).frame:IsShown())
end)

test("hud: a race resumed after a /reload shows the HUD under onArm", function()
    for _, case in ipairs({ { now = 110, want = "running" }, { now = 145, want = "stopping" } }) do
        local f = hud{ enable = false }
        f.M.__now, f.M.__inCombat = case.now, true
        f.meter.SetSession(25, RaceClock.SESSION)
        local run = RaceClock.storedRun({ status = "running" })
        f.NS.db.global.runs[run.id] = run
        f:enable()
        assertEqual(f.Race.State(), case.want)
        assertTrue(f.Hud.IsShown(), case.want .. ": the countdown or the wait is hidden after the reload")
        f.Race.Cancel()
        assertFalse(f.Hud.IsShown(), case.want .. ": the window the resume opened outlived its race")
    end
end)

test("hud: a result arriving while the window is closed opens it", function()
    local f = hud()
    running(f, 30)
    f.Hud.Hide()
    f:to(131)
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
    assertTrue(f.Hud.IsShown())
    assertEqual(current(f), "result")
end)

test("hud: test mode's sample race draws through the race's own view, only while it is on", function()
    local f = hud()
    f.Hud.Show()
    assertTrue(f.NS.Preview.Start({ mode = "test", state = "result" }))
    assertEqual(current(f), "result")
    assertTrue(body(f).w.chips:Texts()[1]:find("New best +", 1, true) ~= nil)
    assertTrue(f.NS.Preview.SetState("running"))
    assertEqual(current(f), "running")
    assertEqual(body(f).w.left.__text, "0:12.0")
    assertEqual(body(f).w.elapsed.__text, "0:18.0")
    f.NS.Preview.Stop()
    assertEqual(current(f), "idle", "test mode off: back to the race's own state")
end)

test("hud: the stand-down drops every registration, timer and the OnUpdate", function()
    local f = hud()
    running(f, 30)
    pump(f, 0.5)
    assertTrue(#f.M.__timers() > 0)
    assertTrue(f.NS.SetByPath("enabled", false))
    assertEqual(#f.M.__timers(), 0, "a cue, a live read or the OnUpdate survived")
    assertEqual(#f.M.__registrations(), 0)
    assertFalse(ui(f).frame:IsShown())
end)

test("hud: hidden with its parent is not closed by the player", function()
    local f = hud()
    f.Hud.Show()
    local frame = ui(f).frame
    frame:__fire("OnHide")          -- the interface hidden: the frame is still shown in its own right
    assertTrue(f.Hud.wanted, "Alt-Z closed the HUD for good")
end)

test("hud: the library-absent load still draws the HUD without a grip or a close control", function()
    local inst = T.load{ libFiles = {} }
    local NS = inst.NS
    NS.Hud.Show()
    local u = assert(NS.Hud.__ui())
    assertTrue(u.frame:IsShown())
    assertEqual(u.close, nil)
    assertEqual(u.current, "idle")
end)

test("hud: the diagnostics state section names the body, the event set and the countdown driver", function()
    local f = hud()
    running(f, 30)
    local lines = {}
    local out = { add = function(_, _, fmt, ...)
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        lines[#lines + 1] = fmt:format(unpack(args, 1, select("#", ...)))
    end }
    for _, section in ipairs(f.NS.Diagnostics.Sections()) do
        if section[1] == "state" then section[2](out) end
    end
    local found = false
    for _, l in ipairs(lines) do
        if l == "hud body=running events=live ticking=true locked=false" then found = true end
    end
    assertTrue(found, "no hud line; got: " .. table.concat(lines, " | "))
end)
-- ── the collection's look (modules/Style.lua) ─────────────────────────────────────────────────────

-- A run of four or more capitals in a label (texture markup stripped): an ALL-CAPS word. STOP is the
-- one shout the HUD keeps, as big as the clock; DPS is an abbreviation.
local function shouts(s)
    if type(s) ~= "string" then return false end
    s = s:gsub("|T.-|t", "")
    for word in s:gmatch("%u%u%u%u+") do
        if word ~= "STOP" then return true end
    end
    return false
end

local function shouting(W)
    local out = {}
    for _, o in ipairs(W.objects) do
        if shouts(o.__text) then out[#out + 1] = o.__text end
    end
    return out
end

test("hud: labels take the collection's font objects; the clocks and KPI figures stay large", function()
    local f = hud()
    f.Hud.Show()
    local u, F = ui(f), f.NS.Style.FONT
    assertEqual(u.frame.title.__fontObject, "GameFontNormal", "the title")
    assertEqual(F.TITLE, "GameFontNormal")
    assertEqual(u.footLeft.__fontObject, "GameFontDisableSmall", "the footer")
    assertEqual(u.footRight.__fontObject, "GameFontDisableSmall")
    local w = body(f).w
    assertEqual(w.lengthCap.__fontObject, "GameFontNormalSmall", "a section label is a header")
    assertEqual(w.lengthCap.__text, "Race Length")
    assertEqual(w.targetCap.__text, "Target")
    assertEqual(w.presets[1].label.__fontObject, "GameFontHighlightSmall", "a preset button")
    assertEqual(w.results.label.__fontObject, "GameFontHighlightSmall", "a link button")
    assertEqual(w.results.label.__text, "Results")
    assertEqual(w.lastResult, nil, "no Last Result button")
    assertEqual(w.arm.label.__text, "Arm Race")
    assertEqual(w.card.name.__fontObject, "GameFontHighlight", "the target's name")
    assertEqual(w.card.badgeText.__fontObject, "GameFontHighlightSmall")
    running(f, 30)
    f.meter.SetSession(25, session(5))
    f.meter.SetSecret(true)
    pump(f, 0.5)
    w = body(f).w
    assertEqual(w.damage.label.__fontObject, "GameFontDisableSmall", "a KPI caption")
    assertEqual(w.damage.label.__text, "Damage")
    assertEqual(w.dps.label.__text, "DPS \194\183 Live")
    assertEqual(w.damage.value.__fontObject, "GameFontNormalHuge", "a KPI figure stays large")
    assertEqual(w.elapsed.__font.size, f.NS.HudStates.CLOCK_PAIR_SIZE, "the clock pair keeps its size")
    assertEqual(w.clock.__font.size, 40, "the single clock keeps its size")
    assertEqual(w.cancel.label.__text, "Cancel")
    local row = assert(w.list.rows[1], "no live row")
    assertEqual(row.name.__fontObject, "GameFontHighlightSmall", "a spell row")
    assertEqual(row.amount.__fontObject, "GameFontHighlightSmall")
    assertEqual(f.NS.HudBreakdown.ROW_HEIGHT, 18, "LootHistory's compact row")
end)

test("hud: no body shouts in capitals (Title Case labels and buttons, Sentence case prose)", function()
    local f = hud()
    f.Hud.Show()
    running(f, 30)
    f.meter.SetSession(25, session(5))
    pump(f, 0.5)
    f:to(129.9)
    f:update(25)
    f:to(130)
    tick(f)
    assertEqual(current(f), "stop")
    f:advance(3)
    tick(f)
    assertEqual(current(f), "waiting")
    f:combatEnd()
    f:advance(3)
    assertEqual(current(f), "result")
    local loud = shouting(f.W)
    assertEqual(#loud, 0, "ALL CAPS: " .. table.concat(loud, " | "))
    local w = body(f).w
    assertEqual(w.newRace.label.__text, "New Race")
    assertEqual(w.details.label.__text, "Details")
    assertEqual(w.share.label.__text, "Share")
end)

test("hud: a title-bar control turns gold under the pointer and back at rest, a late leave included", function()
    local f = hud()
    f.Hud.Show()
    local u = ui(f)
    local GOLD, REST = f.NS.Style.GOLD, f.NS.Style.REST
    local function is(b, c)
        local v = b.icon.__vertex
        return v ~= nil and v[1] == c[1] and v[2] == c[2] and v[3] == c[3] and (v[4] == nil or v[4] == 1)
    end
    local controls = { u.lock, u.settings, u.results }
    for _, b in ipairs(controls) do assertTrue(is(b, REST), "a control is not at rest") end
    u.results:__fire("OnEnter")
    assertTrue(is(u.results, GOLD), "the hovered control is gold")
    assertTrue(is(u.settings, REST) and is(u.lock, REST), "only the hovered one")
    assertTrue(f.M.GameTooltip:IsShown(), "the tooltip stays")
    -- The pointer moves to the next control and the old control's leave arrives after its enter.
    u.settings:__fire("OnEnter")
    u.results:__fire("OnLeave")
    assertTrue(is(u.settings, GOLD), "a late leave took the gold off the control under the pointer")
    assertTrue(is(u.results, REST))
    u.settings:__fire("OnLeave")
    for _, b in ipairs(controls) do assertTrue(is(b, REST), "back at rest") end
    -- The close control is the skin's own (D-9: S.CloseButton through Core, its hover `close.hot`,
    -- which LibKa0s's own suites pin): not on the strip, so never the strip's gold.
    assertFalse(is(u.close, GOLD), "the close control at rest")
    u.close:__fire("OnEnter")
    assertFalse(is(u.close, GOLD), "the close control is not the strip's gold under the pointer")
    assertTrue(is(u.lock, REST) and is(u.settings, REST) and is(u.results, REST), "the strip unmoved")
    u.close:__fire("OnLeave")
    -- Lock swaps the padlock's art, not its tint.
    f.Hud.SetLocked(true)
    u.lock:__fire("OnEnter")
    assertEqual(u.lock.iconName, "lock")
    assertTrue(is(u.lock, GOLD))
end)

test("hud: the minimum size still holds every body after the compact restyle", function()
    local f = hud()
    f.NS.db.profile.windows.hud.width = 1
    f.NS.db.profile.windows.hud.height = 1
    f.Hud.Show()
    assertEqual(f.Hud.Diagnose().height, f.Hud.MIN_HEIGHT)
    local States = f.NS.HudStates
    local content = f.Hud.MIN_HEIGHT - CHROME
    assertTrue(content >= States.IDLE_ARM_Y + States.ARM_HEIGHT + 4 + 14 + 4 + 20, "idle")
    assertTrue(content >= RUNNING_TOP + 3 * PITCH - 2 + RUNNING_BOTTOM, "running with three rows")
    assertTrue(content >= RESULT_TOP + 3 * PITCH - 2 + RESULT_BOTTOM, "result with three rows")
end)

-- ── HUD Appearance (HUD > HUD Appearance, modules/Hud_Appearance.lua) ─────────────────────────────

test("hud: the running clocks, figures and spell rows take their HUD Appearance blocks", function()
    local f = hud()
    f.Hud.Show()
    running(f, 30)
    f.meter.SetSession(25, session(4))
    f.meter.SetSecret(true)
    pump(f, 0.5)
    local w = body(f).w
    -- The defaults are the shipped look: the monospace clocks at 26, green and red.
    assertEqual(w.elapsed.__font.size, 26)
    assertEqual(w.elapsed.__font.path, f.NS.Constants.FONT_MONO)
    assertEqual(w.elapsed.__color[1], 0.36)
    assertEqual(w.left.__color[1], 1.0)
    assertEqual(w.damage.value.__font.size, 20)
    local row = w.list.rows[1]
    assertEqual(row.__height, 18)
    -- The spell bars follow the skin (DR-03, X5): Ka0s Default's own bar texture.
    assertEqual(tostring(row.bar.__barTexture):lower(), "interface\\addons\\dpsrace\\libs\\libka0s\\media\\textures\\ka0s-default",
        "the skin's bar.texture")
    assertEqual(row.bar.__barColor[4], 0.9)
    assertEqual(row.name.__font.size, 10)

    -- From here the HUD only restyles and draws live values: it measures nothing.
    for i = #f.W.geomReads, 1, -1 do f.W.geomReads[i] = nil end
    assertTrue(f.NS.SetByPath("appearance.elapsed.fontSize", 32))
    assertTrue(f.NS.SetByPath("appearance.elapsed.fontFlags", "OUTLINE"))
    assertTrue(f.NS.SetByPath("appearance.figures.fontShadow", false))
    assertTrue(f.NS.SetByPath("appearance.bars.rowHeight", 24))
    assertTrue(f.NS.SetByPath("appearance.bars.barColor", { r = 0.1, g = 0.2, b = 0.3, a = 1 }))
    pump(f, 0.5)
    w = body(f).w
    assertEqual(w.elapsed.__font.size, 32)
    assertEqual(w.elapsed.__font.flags, "OUTLINE")
    assertEqual(w.damage.value.__shadow[1], 0, "the shadow is off")
    row = w.list.rows[1]
    assertEqual(row.__height, 24)
    assertEqual(row.bar.__barColor[1], 0.1)
    assertEqual(row.bar.__barColor[4], 0.9, "the bar opacity is its own row")
    -- The stack moved down for the taller clock: the KPIs at 26 + 32, the rows under them.
    local p = w.damage.frame.__points[1]
    assertEqual(p[5], -58)
    assertEqual(body(f).kpiBottom, 58 + 46 + 8)
    -- The chart sits between the KPIs and the rows, at its configured height (no best: no pace bar).
    -- Damage profile (6 + 22), the 80px plot and its 13px icon row, its 2 + 12 time labels and 8, then
    -- Spell breakdown.
    assertEqual(body(f).rowsTop, 58 + 46 + 8 + (6 + 22 + 80 + 13 + 2 + 12 + 8) + BREAKDOWN)
    assertEqual(#f.W.geomReads, 0, "nothing measured")
end)

test("hud: a clock shown alone draws half again as large, in its block's color", function()
    local f = hud()
    f.NS.db.profile.hud.clock = "elapsed"
    f.Hud.Show()
    running(f, 30)
    pump(f, 0.5)
    local w = body(f).w
    assertEqual(w.clock.__font.size, 40)
    assertEqual(w.clock.__color[1], 0.36, "the elapsed block's green")
    assertEqual(w.damage.frame.__points[1][5], -52, "the shipped layout at the defaults")
end)

test("hud: a bar's class color companion takes the player's class, the swatch's opacity kept", function()
    local f = hud()
    f.NS.db.profile.appearance.bars.useClassColorBar = true
    f.Hud.Show()
    running(f, 30)
    f.meter.SetSession(25, session(2))
    f.meter.SetSecret(true)
    f.NS.HudAppearance.Changed()
    pump(f, 0.5)
    local fill = f.NS.HudAppearance.Bar()
    local _, class = f.M.UnitClass("player")
    local cr = assert(f.M.RAID_CLASS_COLORS[class], "the mock player has a class color")
    assertEqual(fill.r, cr.r)
    assertEqual(fill.a, 0.9)
    assertEqual(body(f).w.list.rows[1].bar.__barColor[1], cr.r)
end)
