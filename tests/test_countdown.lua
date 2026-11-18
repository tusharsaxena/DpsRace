-- tests/test_countdown.lua — the race's final seconds on LibKa0s-Callout-1.0 (core/CalloutSetup.lua,
-- AD-85-DR; spec §4.3, §6.1): the center-screen numbers (race.centerCountdown, race.finalCountdown)
-- drawn by the REAL vendored call-out, counted to the race's buzzer, and the countdown cue
-- (race.countdownCue), one sound per second at most; hidden at the buzzer, on cancel, at the
-- stand-down and with test mode; the call-out's look and silence; and the seam's stub.
--
-- Re-pinned at AD-85-DR: the old module drew Blizzard's BigGold digits with a font fallback and a
-- pop animation of its own; those cases now hold the call-out's frame, text, place and color. The
-- behavior cases (which number shows when, which second sounds) are unchanged.
--
-- Every case runs on the race fixture (tests/race_clock.lua: timers fire at their own GetTime() and
-- the call-out's clock frame runs every 0.05 s) with the widget recorder (tests/mock_widgets.lua), so
-- every sound's time can be read back.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local CUE_SOUND = 25477

local function fixture(opts)
    opts = opts or {}
    local W
    local files, spoken = {}, {}
    local f = RaceClock.new{ enable = opts.enable, libFiles = opts.libFiles, mutate = function(m)
        W = Widgets.install(m)
        m.PlaySoundFile = function(file) files[#files + 1] = file; return true end
        m.C_VoiceChat = { GetTtsVoices = function() return { { voiceID = 1, name = "Voice" } } end,
                          SpeakText = function(_, text) spoken[#spoken + 1] = text end }
        if opts.mutate then opts.mutate(m) end
    end }
    f.W, f.C, f.CO, f.files, f.spoken = W, f.NS.Countdown, f.NS.Callout, files, spoken
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

local function built(f) return f.CO:Stats().built == true end

--- The whole seconds the cue sounded at. A number's cue plays on the call-out's first frame of that
--- second (the client's frame clock, 0.05 s in the fixture), a cue mark's timer on the second itself;
--- each must land within one frame of its second. Re-pinned at AD-85-DR from the exact times the
--- old per-mark timers gave.
local function cueSeconds(f)
    local out = {}
    for _, t in ipairs(f.W.SoundTimes(CUE_SOUND)) do
        local s = math.floor(t + 1e-6)
        assertTrue(t - s <= 0.05 + 1e-6, ("a cue %.3f s after its second"):format(t - s))
        out[#out + 1] = s
    end
    return table.concat(out, ",")
end

local function frameShown(f)
    return built(f) and f.CO:Frame():IsShown() == true
end

-- ── the numbers ─────────────────────────────────────────────────────────────────────────────────

test("countdown: 10..1 show one per second in the last 10s, then go at the buzzer", function()
    local f = fixture()
    running(f, 30)
    f:to(118.9)
    assertFalse(built(f), "the call-out is handed the countdown only a second before the first number")
    assertNil(shownAt(f, 119.9), "a number before the final 10s")
    assertEqual(shownAt(f, 120), 10)
    assertTrue(frameShown(f))
    assertEqual(f.CO:Frame().__name, "DpsRaceCallout")
    assertEqual(shownAt(f, 120.95), 10, "a number holds for its second")
    assertEqual(shownAt(f, 121), 9)
    assertEqual(shownAt(f, 125.5), 5)
    assertEqual(shownAt(f, 129.5), 1)
    assertNil(shownAt(f, 130), "the buzzer clears it")
    assertFalse(frameShown(f))
    assertEqual(f.Race.State(), "stopping")
    assertEqual(f.W.notices[1].text, "STOP", "the buzzer's raid warning stays")
    assertFalse(f.CO:Stats().awake, "the call-out's clock still runs after the buzzer")
end)

test("countdown: the call-out's frame, above everything, never taking the mouse; gold numbers at the old place", function()
    local f = fixture()
    running(f, 30)
    f:to(120)
    local frame = f.CO:Frame()
    assertEqual(frame.__strata, "FULLSCREEN")
    assertEqual(frame.__mouse, false)
    assertTrue(frame ~= (f.NS.Hud.__ui() or {}).frame, "not the HUD's frame")
    assertEqual(table.concat(f.CO:Get("point"), ","), "CENTER,CENTER,0,150", "where the old numbers sat")
    local r, g, b = f.CO:GetColor("number")
    assertEqual(table.concat({ r, g, b }, ","), "1,0.82,0", "the old digits' gold")
    assertEqual(f.CO:Stats().text, "10")
    assertTrue(f.CO:Locked(), "the call-out is never unlocked")
end)

test("countdown: the call-out speaks nothing: no voice pack is shipped and its voice reads off", function()
    local f = fixture()
    running(f, 30)
    f:to(131)
    assertEqual(f.CO:Get("voice"), "off")
    assertEqual(#f.files, 0, "a sound file played")
    assertEqual(#f.spoken, 0, "text to speech spoke")
end)

test("countdown: the stub carries the call-out's surface, and with no library the cue marks still sound", function()
    local f = fixture()
    T.assertSurfaceParity(f.CO, f.NS.CalloutStub, "NS.Callout")
    local g = fixture{ libFiles = {} }
    assertTrue(g.NS.Callout == g.NS.CalloutStub, "the stub stands in")
    running(g, 30)
    g:to(131)
    assertNil(g.C.Shown())
    assertEqual(cueSeconds(g), "120,125,127,128,129")
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
    assertFalse(built(f))
    assertEqual(cueSeconds(f), "120,125,127,128,129")
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
    assertEqual(cueSeconds(f), "120,121,122,123,124,125,126,127,128,129")
    local g = fixture()
    g.NS.db.profile.race.finalCountdown = 3
    running(g, 30)
    g:to(131)
    assertEqual(cueSeconds(g), "120,125,127,128,129",
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
    assertEqual(cueSeconds(f), "120,121,122,123,124,125")
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
    assertEqual(cueSeconds(f), "127,128,129")
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
    assertFalse(built(f))
end)

-- ── test mode ───────────────────────────────────────────────────────────────────────────────────

test("countdown: the sim runs the real marks in its running phase, cue included, and they stop with it", function()
    local f = fixture()
    assertTrue(f.NS.Preview.Start({ mode = "sim" }))
    f.NS.SampleRace.Unpark(f.NS.Sim.ARM_HOLD)  -- SG-DR-1: the stepper parks the arm
    local P = f.NS.Sim                          -- the sim's own 0:15 race (R5-DR2)
    local runFrom = 3                          -- the sim's armed phase
    f:advance(runFrom + P.LENGTH - 10.5)       -- 10.5s left in the sample race
    assertNil(f.C.Shown())
    f:advance(1)
    assertEqual(f.C.Shown(), 10)
    f:advance(4)
    assertEqual(f.C.Shown(), 6)
    assertEqual(#f.W.SoundTimes(CUE_SOUND), 5, "the sim's seconds cue as a race's do")
    assertTrue(f.NS.Preview.Stop())
    assertNil(f.C.Shown())
    assertFalse(frameShown(f))
end)

test("countdown: the sim race's buzzer clears it, the setting holds in the sim, and still test mode shows none", function()
    local f = fixture()
    assertTrue(f.NS.Preview.Start({ mode = "sim" }))
    f.NS.SampleRace.Unpark(f.NS.Sim.ARM_HOLD)  -- SG-DR-1: the stepper parks the arm
    local P = f.NS.Sim                          -- the sim's own 0:15 race (R5-DR2)
    f:advance(3 + P.LENGTH - 2)
    assertEqual(f.C.Shown(), 2)
    f:advance(2.5)
    assertEqual(f.NS.Preview.Diagnose().phase, "stop")
    assertNil(f.C.Shown())

    local h = fixture()
    assertTrue(h.NS.Preview.Start())
    h:advance(30)
    assertNil(h.C.Shown(), "a still running body counts nothing down")
    -- A settings row's reaction asks again: a held race is still no race of the marks'.
    h.C.Refresh()
    assertEqual(h.C.Diagnose().scheduled, 0, "a still running body armed the marks")
    assertEqual(h.C.Diagnose().owner, "none")

    local g = fixture()
    g.NS.db.profile.race.centerCountdown = false
    assertTrue(g.NS.Preview.Start({ mode = "sim" }))
    g.NS.SampleRace.Unpark(g.NS.Sim.ARM_HOLD)  -- SG-DR-1: the stepper parks the arm
    g:advance(3 + P.LENGTH - 2)
    assertNil(g.C.Shown())
    assertFalse(built(g))
end)

-- ── the fences ──────────────────────────────────────────────────────────────────────────────────

test("countdown: never broadcasts a pull timer nor drives Blizzard's TimerTracker", function()
    local fh = assert(io.open(T.root .. "/core/CalloutSetup.lua", "rb"))
    local body = fh:read("*a")
    fh:close()
    local code = body:gsub("%-%-[^\n]*", "")
    for _, name in ipairs({ "C_PartyInfo", "DoCountdown", "TimerTracker", "StartTimer_", "OnUpdate" }) do
        assertFalse(code:find(name, 1, true) ~= nil, "core/CalloutSetup.lua calls " .. name)
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
        -- Re-pinned at AD-85-DR: the call-out's one countdown is armed, where five mark timers were.
        if l == "countdown shown=6 scheduled=1 owner=race" then found = true end
    end
    assertTrue(found, "no countdown line; got: " .. table.concat(lines, " | "))
end)
