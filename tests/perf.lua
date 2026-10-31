-- tests/perf.lua — the offline scenario runner (performance-§9).
--
--   lua tests/perf.lua [--out <path>] [--label <text>]
--
-- OUTSIDE THE GREEN GATE: `lua tests/run.lua` never runs it, and no commit depends on it. It asserts
-- only deterministic quantities, bytes allocated per iteration and bracket notes per iteration, each
-- measured loop isolated by a full collect on either side with the collector stopped inside it.
-- Timings are printed for orientation only: compare scenarios within a run, never across machines.
--
-- WHY THESE SCENARIOS. The addon's per-pull cost is its four bracketed paths (core/PerfSetup.lua):
--   raceEvent    modules/Watchers.lua's handler, here a DamageDone update for the run's session
--                while RUNNING (the event that fires throughout a pull), dispatched through the
--                module's own AceEvent target exactly as the client delivers it
--   hudTick      the HUD's OnUpdate pass while RUNNING (20 Hz): the countdown and the running body
--   hudLive      one throttled live read and redraw of the breakdown, from secret meter values
--   combatEvent  the addon object's PLAYER_REGEN_* handler (core/DpsRace.lua)
-- Each is measured with capture OFF and ON. The pair is the zero-overhead evidence performance-§2
-- asks for: capture off may allocate nothing over capture on, and capture on no more than one note's
-- PAIR_SLACK over off. A fifth scenario pins the stood-down race input at 0 bytes: a disabled addon's
-- input returns before any work.
--
-- CEILINGS. Measured 2026-10-23 on Lua 5.1.5: raceEvent 0.3 bytes (the dispatch and the stamp), hudTick 928
-- (the countdown's formatted text and the running body's setters), hudLive 6384 (the meter adapter's
-- live table and the breakdown's rows; the scripted meter's secret wrappers are part of it, since
-- every value it hands out is a fresh wrapper), combatEvent 2785 (one full HUD Refresh), the
-- stood-down input 0. A ceiling sits a little above the measured figure; raise one only by
-- re-measuring and saying why: a rise is the finding.
-- Re-measured 2026-10-25 with the damage chart and the pace bar (#2, #3): hudTick 800, the same as
-- before them, since the running body's chart and pace views are cached per race (modules/Hud_Chart.lua
-- LiveViews) and its stack compared field by field; combatEvent 3376, also unchanged by them. hudLive
-- 7264 and combatEvent 3376 already stood over their ceilings before that work.
-- Resolved 2026-10-31: a measurement artifact. Measured commit by commit from 7e86054, both rose 720
-- bytes at ef6aaf1, which added no per-read addon work: it taught tests/mock_widgets.lua's SetPoint and
-- ClearAllPoints to record a fresh table per call. hudLive's other rise (+160, f3ef604) is the live-DPS
-- rungs and is real. This runner now installs the recorder quiet, so its setters allocate nothing the
-- client would not, and the figures are the addon's plus the scripted meter's: raceEvent 0.3, hudTick
-- 800, hudLive 6112, combatEvent 2225, the stood-down input 0 (Lua 5.1.5, identical over repeat runs).
-- The ceilings came DOWN to sit a little above those; hudTick's was still the 2026-10-23 headroom.

local root = (arg and arg[0] and arg[0]:match("^(.*)/tests/perf%.lua$")) or "."
package.path = root .. "/tests/?.lua;" .. package.path

local Kit     = dofile(root .. "/tests/_kit/framework.lua")
local Loader  = dofile(root .. "/tests/_kit/loader.lua")
local mockmod = assert(loadfile(root .. "/tests/wow_mock.lua"))(root)
local MockMeter = dofile(root .. "/tests/mock_meter.lua")(Kit)
Loader.addonName = "DpsRace"

local N = 2000
local USAGE = "usage: lua tests/perf.lua [--out <path>] [--label <text>]\n"

local BYTE_CEILING = {
    raceEventCaptureOff = 64, raceEventCaptureOn = 64,
    hudTickCaptureOff = 900, hudTickCaptureOn = 900,
    hudLiveCaptureOff = 6500, hudLiveCaptureOn = 6500,
    combatEventCaptureOff = 2500, combatEventCaptureOn = 2500,
    raceInputStoodDown = 0,
}
local NOTES_PER_ITER = {
    raceEventCaptureOff = 0, raceEventCaptureOn = 1,
    hudTickCaptureOff = 0, hudTickCaptureOn = 1,
    hudLiveCaptureOff = 0, hudLiveCaptureOn = 1,
    combatEventCaptureOff = 0, combatEventCaptureOn = 1,
    raceInputStoodDown = 0,
}
local PAIRS = {
    raceEventCaptureOff = "raceEventCaptureOn", hudTickCaptureOff = "hudTickCaptureOn",
    hudLiveCaptureOff = "hudLiveCaptureOn", combatEventCaptureOff = "combatEventCaptureOn",
}
local PAIR_SLACK = 64
local PAIR_NOISE = 1

local opts = { out = nil, label = "offline" }
do
    local i = 1
    while arg and arg[i] do
        local a = arg[i]
        if a == "--out" and arg[i + 1] then opts.out = arg[i + 1]; i = i + 2
        elseif a == "--label" and arg[i + 1] then opts.label = arg[i + 1]; i = i + 2
        else
            io.stderr:write("unknown argument: " .. tostring(a) .. "\n")
            io.stderr:write(USAGE)
            os.exit(2)
        end
    end
end

-- ── environment ─────────────────────────────────────────────────────────────────────────────────
-- Both load lists are DERIVED (testing-§9): the library's from LibKa0s.xml, the addon's from the TOC,
-- so this runner measures what the client loads and never a hand-kept list.

local LIB_FILES = Loader.xmlFiles(root .. "/libs/LibKa0s/LibKa0s.xml")
local ADDON_FILES = {}
for i, rel in ipairs(Loader.tocFiles(root .. "/DpsRace.toc")) do ADDON_FILES[i] = root .. "/" .. rel end

local function loadInstance(o)
    o = o or {}
    local mocks = mockmod.build()
    if o.mutate then o.mutate(mocks) end
    mocks._G = Loader.makeEnv(mocks)
    local NS = {}
    Loader.loadAll(LIB_FILES, NS, mocks)
    Loader.loadAll(ADDON_FILES, NS, mocks)
    local AceAddon = mocks.LibStub("AceAddon-3.0")
    AceAddon:InitializeAddon(NS)
    if o.enable ~= false then
        AceAddon:EnableAddon(NS)
        if mocks.__fireTimers then mocks.__fireTimers() end
    end
    return { NS = NS, mocks = mocks }
end

-- The race fixture and the widget recorder take the suites' T; these are the members they read.
local T = {
    root = root, load = loadInstance, mockMeter = MockMeter,
    secret = Kit.secret, isSecret = Kit.isSecret, reveal = Kit.reveal,
}
local RaceClock = dofile(root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(root .. "/tests/mock_widgets.lua")(T)

local f = RaceClock.new{ mutate = function(m) Widgets.install(m, { quiet = true }) end }
local NS, M = f.NS, f.M

local failures = {}
local function check(ok, msg) if not ok then failures[#failures + 1] = msg end end

check(NS.Perf.BuildRecord ~= nil, "NS.Perf is the degradation stub: every scenario would measure a stub")

-- Count the bracket's notes without allocating: a counter, not a list.
local notes = 0
local realNote = NS.Perf.Note
NS.Perf.Note = function(key, ms, parent)
    notes = notes + 1
    return realNote(key, ms, parent)
end

local results = {}

-- The warm-up and the measured loop run through this one function, at the same stack depth.
local function loop(n, fn)
    for _ = 1, n do fn() end
end

--- Run `fn` n times after a warm-up of the same length, the collector stopped inside the loop.
--- `prime` runs the same stopped-collector loop once first and keeps nothing: a table that only
--- grows while the collector is stopped (the kit's secret-wrapper registry, a timeline's stamps)
--- reaches its size there, so neither half of a pair is billed for a rehash the other escaped.
local function measure(name, n, fn, prime)
    loop(n, fn)
    if prime then
        collectgarbage("collect"); collectgarbage("stop")
        loop(n, fn)
        collectgarbage("restart")
    end
    notes = 0
    collectgarbage("collect"); collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    local t0 = os.clock()
    loop(n, fn)
    local t1 = os.clock()
    local after = collectgarbage("count")
    collectgarbage("restart")
    results[#results + 1] = {
        name = name, iterations = n, totalMs = (t1 - t0) * 1000, msPerIter = (t1 - t0) * 1000 / n,
        notesPerIter = notes / n, bytesPerIter = math.max(0, (after - before) * 1024 / n),
    }
end

--- One stopped-collector pass in each capture mode, recording nothing: a path whose first pass with
--- capture on builds something once (measured: the combat handler's first on-pass came in a third
--- lighter than every later one) is settled before either half is measured.
local function settle(fn)
    for _, on in ipairs({ false, true }) do
        NS.Perf.on = on
        collectgarbage("collect"); collectgarbage("stop")
        loop(N, fn)
        collectgarbage("restart")
    end
end

local function pair(base, fn)
    settle(fn)
    NS.Perf.on = false
    measure(base .. "CaptureOff", N, fn, true)
    NS.Perf.on = true
    measure(base .. "CaptureOn", N, fn, true)
    NS.Perf.on = false
end

-- ── the scene: a 15:00 race running on session 25, the HUD shown ────────────────────────────────

NS.Hud.Show()
check(f:arm(900), "the race did not arm")
f:start(25)
check(NS.Race.State() == "running", "the race is not running: every scenario would measure nothing")
check(NS.Hud.IsShown(), "the HUD is hidden: the tick and the live read would measure nothing")

-- The meter's call log is the fixture's, not the addon's: emptied before each scenario so a growing
-- record is never billed to the path under measurement.
local function quietMeter() for k in pairs(f.meter.calls) do f.meter.calls[k] = nil end end

-- raceEvent: a DamageDone update for the run's session, through Watchers' own AceEvent target. Each
-- is a timeline stamp (its array grows by one: amortized, and the same in both halves of the pair).
local target = NS.Watchers.EventTarget()
check(target ~= nil, "Watchers holds no event target while running")
local STAT = NS.Meter.STAT_DAMAGE_DONE
local raceRun = NS.Race.Current()
local function raceEvent()
    M.__fireUnconditional(target, "DAMAGE_METER_COMBAT_SESSION_UPDATED", STAT, 25)
end
-- The timeline's array doubles at each power of two. Grown here past 16384 stamps, its next doubling
-- (32768) lies beyond everything the settle and the pair add (8 x N), so neither half is billed for it.
for _ = 1, 16400 do raceEvent() end
quietMeter()
pair("raceEvent", raceEvent)
check(raceRun.race.sessionID == 25, "the update was not for the run's session")

-- hudTick: one OnUpdate pass of the countdown driver.
quietMeter()
pair("hudTick", NS.Hud.Tick)

-- hudLive: one live read and redraw (Hud.ReadLive, the throttle timer's callback), from secret values.
local live = NS.Hud.ReadLive
check(type(live) == "function", "the HUD exposes no live-read seam: hudLive would measure nothing")
local function hudLive()
    live()
    quietMeter()
end
if type(live) == "function" then pair("hudLive", hudLive) end

-- combatEvent: the addon object's regen handler (the HUD's show decision and refresh).
local function combatEvent() NS:OnCombatChanged("PLAYER_REGEN_DISABLED") end
pair("combatEvent", combatEvent)

-- raceInputStoodDown: the disabled addon's race input returns before any work.
check(NS.SetByPath("enabled", false), "the addon would not stand down")
measure("raceInputStoodDown", N, function() NS.Race.OnMeterUpdate(STAT, 25, 1000) end)
NS.SetByPath("enabled", true)
NS.Perf.Note = realNote

for _, r in ipairs(results) do
    local ceiling = BYTE_CEILING[r.name]
    check(ceiling ~= nil and r.bytesPerIter <= ceiling,
        ("%s allocated %.1f bytes/iter, over its %s-byte ceiling"):format(r.name, r.bytesPerIter, tostring(ceiling)))
    local want = NOTES_PER_ITER[r.name]
    check(want ~= nil and math.abs(r.notesPerIter - want) < 1e-9,
        ("%s noted %.2f times/iter, pinned at %s"):format(r.name, r.notesPerIter, tostring(want)))
end

local byName = {}
for _, r in ipairs(results) do byName[r.name] = r end
for offName, onName in pairs(PAIRS) do
    local off, on = byName[offName], byName[onName]
    check(off ~= nil and on ~= nil, ("the pair %s / %s was not measured"):format(offName, onName))
    if off and on then
        check(off.bytesPerIter <= on.bytesPerIter + PAIR_NOISE,
            ("%s allocated %.1f bytes/iter, more than %s's %.1f: the off bracket is not free"):format(
                offName, off.bytesPerIter, onName, on.bytesPerIter))
        check(on.bytesPerIter <= off.bytesPerIter + PAIR_SLACK,
            ("%s allocated %.1f bytes/iter, over %s's %.1f by more than %d"):format(
                onName, on.bytesPerIter, offName, off.bytesPerIter, PAIR_SLACK))
    end
end

-- ── report ──────────────────────────────────────────────────────────────────────────────────────

print(("Ka0s DPS Race \226\128\148 offline perf  (v%s, label '%s')"):format(tostring(NS.Version()), opts.label))
print()
-- Five columns, exactly: tests/_kit/run-automated-tests.sh counts scenarios structurally as the
-- five-field rows under this header.
print(("%-24s %8s %11s %10s %11s"):format("scenario", "iters", "ms/iter", "notes/iter", "bytes/iter"))
for _, r in ipairs(results) do
    print(("%-24s %8d %11.5f %10.2f %11.1f"):format(r.name, r.iterations, r.msPerIter, r.notesPerIter, r.bytesPerIter))
end
print()
print("timings are for orientation only \226\128\148 compare scenarios within a run, never across machines")
if #failures > 0 then
    print()
    print(("%d assertion%s FAILED:"):format(#failures, #failures == 1 and "" or "s"))
    for _, msg in ipairs(failures) do print("  - " .. msg) end
end

-- ── the record ──────────────────────────────────────────────────────────────────────────────────

local function writeRecord(path)
    local buckets = {}
    for _, r in ipairs(results) do
        buckets[r.name] = { calls = r.iterations, totalMs = r.totalMs, maxMs = r.msPerIter,
                            notesPerIter = r.notesPerIter, bytesPerIter = r.bytesPerIter }
    end
    local fh, err = io.open(path, "w")
    if not fh then
        io.stderr:write("cannot write " .. path .. ": " .. tostring(err) .. "\n")
        os.exit(2)
    end
    fh:write(NS.Perf.EncodeJSON({
        schema = 1, addon = "DpsRace", source = "offline",
        version = tostring(NS.Version()), interface = 0, timestamp = os.time(),
        label = opts.label, buckets = buckets, failures = failures,
    }), "\n")
    fh:close()
    print("wrote " .. path)
end

if opts.out then writeRecord(opts.out) end

os.exit(#failures == 0 and 0 or 1)
