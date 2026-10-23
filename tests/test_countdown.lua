-- tests/test_countdown.lua — modules/Countdown.lua, the race's final seconds (spec §4.3, §6.1): the
-- center-screen numbers (race.centerCountdown, race.finalCountdown) and the countdown cue
-- (race.countdownCue), one timer per mark, one sound per second at most, the Blizzard BigGold digit
-- art with its font fallback, hidden at the buzzer, on cancel, at the stand-down and with test mode.
--
-- Every case runs on the race fixture (tests/race_clock.lua: timers fire at their own GetTime()) with
-- the widget recorder (tests/mock_widgets.lua), so a texture's texcoords and every sound's time can be
-- read back.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local CUE_SOUND = 25477

local function fixture(opts)
    opts = opts or {}
    local W
    local f = RaceClock.new{ enable = opts.enable, mutate = function(m)
        W = Widgets.install(m)
        if opts.mutate then opts.mutate(m) end
    end }
    f.W, f.C = W, f.NS.Countdown
    return f
end

--- Armed and running from 100 (in combat, the meter secret), `length` seconds.
local function running(f, length)
    assertTrue(f:arm(length or 30))
    f:start(25)
    assertEqual(f.Race.State(), "running")
end

local function shownAt(f, t)
    f:to(t)
    return f.C.Shown()
end

local function frameShown(f)
    local u = f.C.__ui()
    return u ~= nil and u.frame:IsShown() == true
end

-- ── the numbers ─────────────────────────────────────────────────────────────────────────────────

test("countdown: 10..1 show one per second in the last 10s, then go at the buzzer", function()
    local f = fixture()
    running(f, 30)
    assertNil(shownAt(f, 119.9), "a number before the final 10s")
    assertNil(f.C.__ui(), "the frame is built lazily, at the first number")
    assertEqual(shownAt(f, 120), 10)
    assertTrue(frameShown(f))
    assertEqual(shownAt(f, 120.99), 10, "a number holds for its second")
    assertEqual(shownAt(f, 121), 9)
    assertEqual(shownAt(f, 125.5), 5)
    assertEqual(shownAt(f, 129.5), 1)
    assertNil(shownAt(f, 130), "the buzzer clears it")
    assertFalse(frameShown(f))
    assertEqual(f.Race.State(), "stopping")
    assertEqual(f.W.notices[1].text, "STOP", "the buzzer's raid warning stays")
end)

test("countdown: its own frame, center of UIParent, above everything, never taking the mouse", function()
    local f = fixture()
    running(f, 30)
    f:to(120)
    local u = assert(f.C.__ui())
    assertEqual(u.frame.__strata, "FULLSCREEN_DIALOG")
    assertEqual(u.frame.__mouse, false)
    assertTrue(u.frame ~= f.Hud and u.frame ~= (f.NS.Hud.__ui() or {}).frame, "not the HUD's frame")
end)

test("countdown: each number pops in through an animation", function()
    local f = fixture()
    running(f, 30)
    f:to(130)
    local frame = f.C.__ui().frame
    local pops, flashes = 0, 0
    for _, p in ipairs(f.W.animPlays) do
        if p.t >= 120 and p.t < 130 then
            if p.owner == frame then pops = pops + 1 else flashes = flashes + 1 end
        end
    end
    assertEqual(pops, 10, "one pop per number")
    assertEqual(flashes, 20, "each number flashes both glows")
end)

test("countdown: the digits are Blizzard's BigGold set, cut by texcoord", function()
    local f = fixture()
    running(f, 30)
    f:to(120)
    local u = f.C.__ui()
    assertEqual(u.mode, "texture")
    local ones, tens = u.digits[1], u.digits[2]
    assertEqual(ones.__texture, "Interface\\Timer\\BigTimerNumbers")
    assertEqual(u.glows[1].__texture, "Interface\\Timer\\BigTimerNumbersGlow")
    local h = 170 / 512
    -- "10": the ones digit 0 (column 0, row 0), the tens digit 1 (column 1, row 0).
    assertEqual(table.concat(ones.__texCoord, ","), table.concat({ 0, 0.25, 0, h }, ","))
    assertEqual(table.concat(tens.__texCoord, ","), table.concat({ 0.25, 0.5, 0, h }, ","))
    assertTrue(tens:IsShown())
    f:to(126)
    -- "4": column 0, row 1; the tens digit hidden.
    assertEqual(table.concat(ones.__texCoord, ","), table.concat({ 0, 0.25, h, 2 * h }, ","))
    assertFalse(tens:IsShown())
end)

test("countdown: without the digit art it falls back to a large outlined number", function()
    local f = fixture()
    f.W.missingTextures["Interface\\Timer\\BigTimerNumbers"] = true
    running(f, 30)
    f:to(127)
    local u = f.C.__ui()
    assertEqual(u.mode, "font")
    assertEqual(u.text.__text, "3")
    assertTrue(u.text:IsShown())
    assertTrue(tostring(u.text.__font.flags):find("OUTLINE", 1, true) ~= nil)
    assertFalse(u.digits[1]:IsShown())
end)

test("countdown: finalCountdown 3 starts at 3", function()
    local f = fixture()
    f.NS.db.profile.race.finalCountdown = 3
    running(f, 30)
    assertNil(shownAt(f, 126.9))
    assertEqual(shownAt(f, 127), 3)
    assertEqual(shownAt(f, 128), 2)
    assertEqual(shownAt(f, 129), 1)
end)

test("countdown: switched off, no frame is ever built and only the cue marks sound", function()
    local f = fixture()
    f.NS.db.profile.race.centerCountdown = false
    running(f, 30)
    f:to(131)
    assertNil(f.C.__ui())
    assertEqual(table.concat(f.W.SoundTimes(CUE_SOUND), ","), "120,125,127,128,129")
end)

test("countdown: switching it off mid-countdown hides the number at once", function()
    local f = fixture()
    running(f, 30)
    f:to(122)
    assertTrue(frameShown(f))
    assertTrue(f.NS.SetByPath("race.centerCountdown", false))
    assertFalse(frameShown(f))
    assertNil(shownAt(f, 125))
end)

test("countdown: works with the HUD window closed", function()
    local f = fixture()
    f.NS.Hud.Hide()
    running(f, 30)
    f.NS.Hud.Hide()
    assertFalse(f.NS.Hud.IsShown())
    assertEqual(shownAt(f, 124), 6)
end)

-- ── the sounds ──────────────────────────────────────────────────────────────────────────────────

test("countdown: one cue per second of the numbers, never two in a second", function()
    local f = fixture()
    running(f, 30)
    f:to(131)
    assertEqual(table.concat(f.W.SoundTimes(CUE_SOUND), ","), "120,121,122,123,124,125,126,127,128,129")
    local g = fixture()
    g.NS.db.profile.race.finalCountdown = 3
    running(g, 30)
    g:to(131)
    assertEqual(table.concat(g.W.SoundTimes(CUE_SOUND), ","), "120,125,127,128,129",
        "the cue marks and the numbers' seconds share their sounds")
end)

test("countdown: the cue off keeps the numbers and silences every second", function()
    local f = fixture()
    f.NS.db.profile.race.countdownCue = false
    running(f, 30)
    assertEqual(shownAt(f, 125), 5)
    f:to(131)
    assertEqual(#f.W.SoundTimes(CUE_SOUND), 0)
end)

-- ── the lifecycle ───────────────────────────────────────────────────────────────────────────────

test("countdown: a cancel at 5s left hides it and nothing more shows or sounds", function()
    local f = fixture()
    running(f, 30)
    f:to(125.2)
    assertEqual(f.C.Shown(), 5)
    assertTrue(f.Race.Cancel())
    assertNil(f.C.Shown())
    assertFalse(frameShown(f))
    f:to(131)
    assertNil(f.C.Shown())
    assertEqual(table.concat(f.W.SoundTimes(CUE_SOUND), ","), "120,121,122,123,124,125")
    assertEqual(f.C.Diagnose().scheduled, 0)
end)

test("countdown: combat ending before the buzzer hides it", function()
    local f = fixture()
    running(f, 30)
    f:to(123)
    assertTrue(frameShown(f))
    f.M.__inCombat = false
    f.Race.OnCombatEnd(f:now())
    assertEqual(f.Race.State(), "stopping")
    assertFalse(frameShown(f))
end)

--- An instance with `run` stored as running, resumed by OnEnable at `now`, in combat.
local function reload(run, now)
    local f = fixture{ enable = false }
    f.M.__now = now
    f.M.__inCombat = true
    f.meter.SetSession(25, RaceClock.SESSION)
    f.NS.db.global.runs[run.id] = run
    f:enable()
    return f
end

test("countdown: a /reload with 4s left resumes at 4 and counts 3, 2, 1", function()
    local f = reload(RaceClock.storedRun({ status = "running" }), 126)    -- started at 100, 30s
    assertEqual(f.Race.State(), "running")
    assertEqual(f.C.Shown(), 4, "the number of the moment shows at once")
    assertEqual(#f.W.SoundTimes(CUE_SOUND), 0, "the resume itself plays no sound")
    assertEqual(shownAt(f, 127), 3)
    assertEqual(shownAt(f, 128), 2)
    assertEqual(shownAt(f, 129), 1)
    assertNil(shownAt(f, 130))
    assertEqual(table.concat(f.W.SoundTimes(CUE_SOUND), ","), "127,128,129")
end)

test("countdown: a /reload before the window shows nothing until it opens", function()
    local f = reload(RaceClock.storedRun({ status = "running" }), 110)
    assertNil(f.C.Shown())
    assertNil(shownAt(f, 119.9))
    assertEqual(shownAt(f, 120), 10)
end)

test("countdown: a /reload past the buzzer shows nothing", function()
    local f = reload(RaceClock.storedRun({ status = "running" }), 131)
    assertEqual(f.Race.State(), "stopping")
    assertNil(f.C.Shown())
    assertNil(f.C.__ui())
end)

-- ── test mode ───────────────────────────────────────────────────────────────────────────────────

test("countdown: test mode demonstrates it in its running phase, and it stops with test mode", function()
    local f = fixture()
    assertTrue(f.NS.Preview.Start())
    local P = f.NS.Preview
    local runFrom = P.SCRIPT[1].secs
    f:advance(runFrom + P.LENGTH - 10.5)       -- 10.5s left in the sample race
    assertNil(f.C.Shown())
    f:advance(1)
    assertEqual(f.C.Shown(), 10)
    f:advance(4)
    assertEqual(f.C.Shown(), 6)
    assertEqual(#f.W.SoundTimes(CUE_SOUND), 0, "test mode plays no sound")
    assertTrue(f.NS.Preview.Stop())
    assertNil(f.C.Shown())
    assertFalse(frameShown(f))
end)

test("countdown: the test race's buzzer clears it, and the setting holds in test mode", function()
    local f = fixture()
    assertTrue(f.NS.Preview.Start())
    local P = f.NS.Preview
    f:advance(P.SCRIPT[1].secs + P.LENGTH - 2)
    assertEqual(f.C.Shown(), 2)
    f:advance(2.5)
    assertEqual(f.NS.Preview.Diagnose().phase, "stop")
    assertNil(f.C.Shown())

    local g = fixture()
    g.NS.db.profile.race.centerCountdown = false
    assertTrue(g.NS.Preview.Start())
    g:advance(P.SCRIPT[1].secs + P.LENGTH - 2)
    assertNil(g.C.Shown())
    assertNil(g.C.__ui())
end)

-- ── the fences ──────────────────────────────────────────────────────────────────────────────────

test("countdown: never broadcasts a pull timer nor drives Blizzard's TimerTracker", function()
    local fh = assert(io.open(T.root .. "/modules/Countdown.lua", "rb"))
    local body = fh:read("*a")
    fh:close()
    local code = body:gsub("%-%-[^\n]*", "")
    for _, name in ipairs({ "C_PartyInfo", "DoCountdown", "TimerTracker", "StartTimer_", "OnUpdate" }) do
        assertFalse(code:find(name, 1, true) ~= nil, "modules/Countdown.lua calls " .. name)
    end
end)

test("countdown: the diagnostics state section names what it shows and holds", function()
    local f = fixture()
    running(f, 30)
    f:to(124)
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
        if l == "countdown shown=6 scheduled=5 owner=race" then found = true end
    end
    assertTrue(found, "no countdown line; got: " .. table.concat(lines, " | "))
end)
