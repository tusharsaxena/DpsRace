-- tests/test_chart.lua — the damage chart and the pace bar (#2, #3): the in-session bucket store
-- (modules/Slices.lua) and the running HUD's captures into it.
--
-- The live cases run on the race fixture (tests/race_clock.lua) with the widget recorder
-- (tests/mock_widgets.lua). The meter is secret in combat, every read answering fresh opaque handles,
-- so a column is checked by IDENTITY: it must hold the very handle the first read at or after its
-- boundary answered, never a value worked out from one.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local function hud()
    local W
    local f = RaceClock.new{ mutate = function(m) W = Widgets.install(m) end }
    f.W, f.Hud = W, f.NS.Hud
    f.NS.Slices.Reset()
    return f
end

-- Every live read the HUD makes: its race-clock time and the total it answered (an opaque handle).
local function recordReads(f)
    local reads, real = {}, f.NS.Meter.ReadLive
    f.NS.Meter.ReadLive = function()
        local live = real()
        reads[#reads + 1] = { t = f.Race.Elapsed(), total = live and live.total }
        return live
    end
    return reads
end

local function running(f, length)
    assertTrue(f:arm(length or 30))
    f:start(25)
    assertEqual(f.Race.State(), "running")
end

-- The handle bucket `i` must hold: the first read at or after its boundary, when it came in time.
local function expected(reads, boundary)
    for _, r in ipairs(reads) do
        if r.t and r.t >= boundary - 1e-6 then
            if r.t - boundary <= 1.0 then return r.total end
            return nil
        end
    end
    return nil
end

-- ── the store, pure ─────────────────────────────────────────────────────────────────────────────

test("chart: the bucket count is the length in whole seconds, at most 60", function()
    local S = T.NS.Slices
    assertEqual(S.Count(30), 30)
    assertEqual(S.Count(45.9), 45)
    assertEqual(S.Count(180), 60)
    assertEqual(S.Count(900), 60)
    assertEqual(S.Count(0.4), 1, "never none")
    assertEqual(S.Boundary(180, 60, 1), 3, "a 3:00 race: one bucket every 3 seconds")
    assertEqual(S.Boundary(180, 60, 60), 180, "the last ends on the buzzer")
end)

test("chart: a capture copies the handle into each bucket it is the first read at or after", function()
    local S = T.NS.Slices
    S.Reset()
    local run = { id = "r1", race = { length = 10 }, flags = {} }
    local h = {}
    for i = 1, 6 do h[i] = T.secret(i * 100) end
    assertEqual(S.Capture(run, 0.5, h[1]), 0, "before the first boundary: nothing")
    assertEqual(S.Capture(run, 1.0, h[2]), 1, "exactly on it")
    assertEqual(S.Capture(run, 1.3, h[3]), 0, "a later read in the same bucket changes nothing")
    local rec = S.Get("r1")
    assertTrue(rawequal(rec.values[1], h[2]), "bucket 1 holds the read at its boundary")
    -- 3.2 s: boundary 2 is 1.2 s behind (too late, left empty), boundary 3 is 0.2 s behind.
    assertEqual(S.Capture(run, 3.2, h[4]), 1)
    assertEqual(rec.values[2], nil, "a boundary noticed too late stays empty")
    assertTrue(rawequal(rec.values[3], h[4]))
    assertEqual(S.NextBoundary(run), 4)
    -- A read with no total keeps a recent boundary open for the next read.
    assertEqual(S.Capture(run, 4.1, nil), 0)
    assertEqual(S.NextBoundary(run), 4)
    assertEqual(S.Capture(run, 4.3, h[5]), 1)
    assertTrue(rawequal(rec.values[4], h[5]))
    assertEqual(rec.filled, 3)
end)

test("chart: a shared session's buckets stay empty, and the store never inspects a value", function()
    local S = T.NS.Slices
    S.Reset()
    local run = { id = "r2", race = { length = 5 }, flags = { sharedSession = true } }
    assertEqual(S.Capture(run, 1, T.secret(1)), 0)
    assertEqual(S.Get("r2").values[1], nil, "pre-arm damage cannot be netted live")
    run.flags.sharedSession = nil
    local h = T.secret(2)
    -- Every operation the kit's secret refuses (arithmetic, comparison, truth, concat) would raise here.
    local ok, err = pcall(S.Capture, run, 2, h)
    assertTrue(ok, tostring(err))
    assertTrue(rawequal(S.Get("r2").values[2], h))
end)

test("chart: Drawable answers only a scored run with slices this session", function()
    local S = T.NS.Slices
    S.Reset()
    local run = { id = "r3", status = "complete", race = { length = 5 }, flags = {}, result = { damage = 500 } }
    assertEqual(S.Drawable(run), nil, "an earlier session's run: no slices")
    S.Capture(run, 1, T.secret(1))
    assertTrue(S.Drawable(run) ~= nil)
    run.status = "lost"
    assertEqual(S.Drawable(run), nil, "a lost run")
    run.status = "incomplete"
    assertTrue(S.Drawable(run) ~= nil, "an incomplete run keeps what it captured")
    run.flags.sharedSession = true
    assertEqual(S.Drawable(run), nil, "a shared session")
    run.flags.sharedSession = nil
    run.result.damage = 0
    assertEqual(S.Drawable(run), nil, "nothing to scale to")
end)

test("chart: a quiet stretch still fills each bucket at its boundary, and the buzzer fills the last", function()
    local f = hud()
    local reads = recordReads(f)
    running(f, 30)
    -- No meter updates at all: only the bucket timers read.
    f:to(105.5)
    local rec = f.NS.Slices.Get(f.Race.Current().id)
    for i = 1, 5 do assertTrue(rawequal(rec.values[i], expected(reads, i)) and rec.values[i] ~= nil, "bucket " .. i) end
    f:to(130)
    assertEqual(f.Race.State(), "stopping")
    assertTrue(rec.values[30] ~= nil, "the buzzer's read fills the bucket that ends on it")
    assertTrue(rawequal(rec.values[30], reads[#reads].total))
    assertEqual(reads[#reads].t, 30)
    assertEqual(rec.filled, 30)
end)
