-- tests/test_sample_parity.lua — test mode and the sim show what a real race shows: the sample data
-- has a real fight's shape (modules/MockRuns.lua), and a sample race runs the race's own views and
-- messages (modules/SampleRace.lua). The owner's report: every compare bar full, in test mode only.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local function fixture(class)
    local W
    local f = RaceClock.new{ mutate = function(m)
        W = Widgets.install(m)
        if class then m.__context.classToken = class end
        -- What a client answers at the arm: gear and a stat, so the sample's own loadout and stats exist.
        m.GetInventoryItemLink = function(_, slot) return slot == 13 and "|Hitem:7|h[Own Trinket]|h" or nil end
        m.UnitArmor = function() return 1000, 1000 end
    end }
    f.W, f.Hud, f.Preview, f.Sim, f.R = W, f.NS.Hud, f.NS.Preview, f.NS.Sim, f.NS.Results
    f.MR = f.NS.MockRuns
    return f
end

local function ui(f) return assert(f.Hud.__ui(), "the HUD window was never built") end
local function current(f) return ui(f).current end
local function sim(f, key) assertTrue(f.Preview.Start({ mode = "sim", scenario = key })) end

local function until_(f, pred)
    for _ = 1, 800 do
        if pred() then return true end
        f:advance(0.1)
        f.Hud.Tick()
    end
    error("never reached")
end

-- The complete runs a compare sets side by side: one board's (class, target type, length).
local function comparable(runs)
    local out = {}
    for _, run in ipairs(runs) do
        if run.status == "complete" then
            local key = run.char.class .. run.target.category .. run.race.length
            out[key] = out[key] or {}
            table.insert(out[key], run)
        end
    end
    return out
end

local function rowsOf(NS, a, b)
    local C = NS.ResultsCompare
    local rows = C.Spells(a, b)
    return rows, C.BarScale(C.ScoreRows(C.Kpis(a, b)), rows)
end

-- ── the owner's report: the compare's bars ──────────────────────────────────────────────────────

test("sample parity: no two sample runs scale uniformly: a compare's bars vary, and go both ways", function()
    local f = fixture("WARLOCK")
    local groups = comparable(f.MR.Dataset().runs)
    local pairsSeen = 0
    for _, runs in pairs(groups) do
        for i = 1, #runs - 1 do
            local rows, top = rowsOf(f.NS, runs[i], runs[i + 1])
            local full, plus, minus, sizes = 0, 0, 0, {}
            for _, r in ipairs(rows) do
                if r.pct then
                    local diff, max = f.NS.ResultsCompare.Scaled(r.pct, r.delta, top)
                    if diff and math.abs(diff) >= max - 1e-9 then full = full + 1 end
                    if r.pct > 0 then plus = plus + 1 elseif r.pct < 0 then minus = minus + 1 end
                    sizes[("%.1f"):format(r.pct)] = true
                end
            end
            local distinct = 0
            for _ in pairs(sizes) do distinct = distinct + 1 end
            assertTrue(full <= 1 or full < #rows / 2, "most bars full: " .. runs[i].id .. " v " .. runs[i + 1].id)
            assertTrue(distinct >= 3, "the spells move alike: " .. runs[i].id .. " v " .. runs[i + 1].id)
            assertTrue(plus > 0 and minus > 0, "one sign only: " .. runs[i].id .. " v " .. runs[i + 1].id)
            pairsSeen = pairsSeen + 1
        end
    end
    assertTrue(pairsSeen >= 2, "too few compares to mean anything")
end)

test("sample parity: a sim's new best is not a flat factor of its history: its rows differ too", function()
    local f = fixture("WARLOCK")
    sim(f, "newbest")
    until_(f, function() return current(f) == "result" end)
    local rows = rowsOf(f.NS, f.NS.ResultsSource.Get("sim-newbest"), f.NS.ResultsSource.Get("sample-01"))
    local plus, minus = 0, 0
    for _, r in ipairs(rows) do
        if r.pct and r.pct > 0 then plus = plus + 1 elseif r.pct and r.pct < 0 then minus = minus + 1 end
    end
    assertTrue(plus > 0 and minus > 0, "+4% on every row again")
end)

test("sample parity: a spell can sit on one side of a compare only, and the shares and order differ", function()
    local f = fixture("WARLOCK")
    local data = f.MR.Dataset()
    local rows = rowsOf(f.NS, data.runs[1], data.runs[3])
    local oneSided = 0
    for _, r in ipairs(rows) do
        if r.dmgA == nil or r.dmgB == nil then oneSided = oneSided + 1 end
    end
    assertTrue(oneSided > 0, "a run that missed its cooldown has no row for it")
    local same = true
    for i, s in ipairs(data.runs[1].spells) do
        local o = data.runs[3].spells[i]
        if not o or o.id ~= s.id then same = false end
    end
    assertFalse(same, "the rank order never changes")
end)

test("sample parity: the plan is deterministic: the same id, the same fight", function()
    local f = fixture()
    local a, b = f.MR.Dataset(), f.MR.Dataset()
    for i, run in ipairs(a.runs) do
        assertEqual(#run.spells, #b.runs[i].spells, run.id)
        for j, s in ipairs(run.spells) do
            assertEqual(s.id, b.runs[i].spells[j].id, run.id)
            assertEqual(s.dmg, b.runs[i].spells[j].dmg, run.id)
        end
        if run.casts then assertEqual(run.casts.list, b.runs[i].casts.list, run.id) end
    end
end)

-- ── the record ──────────────────────────────────────────────────────────────────────────────────

test("sample parity: every sample record has the shape a race leaves", function()
    local f = fixture("WARLOCK")
    local tails = {}
    for _, run in ipairs(f.MR.Dataset().runs) do
        assertTrue(run.build ~= nil, run.id .. ": no build, as Recorder.NewRun stores one")
        assertEqual(run.race.grace, f.NS.GetSetting("race.grace"), run.id)
        if run.result then
            local sum = 0
            for i, s in ipairs(run.spells) do
                sum = sum + s.dmg
                if i > 1 then assertTrue(run.spells[i - 1].dmg >= s.dmg, run.id .. ": unsorted") end
            end
            assertEqual(sum, run.result.damage, run.id .. ": the spells sum to the damage")
            local r = run.result
            assertEqual(r.sessionDuration, math.floor(r.sessionDuration), run.id .. ": whole seconds")
            if run.flags.sharedSession then
                assertEqual(r.meterDps, nil, run.id .. ": no meter rate on a shared session")
                assertEqual(run.spells[1].dps, 0, run.id)
                assertTrue(run.race.baseline ~= nil, run.id)
            else
                assertEqual(r.meterDps, math.floor(r.damage / r.sessionDuration), run.id)
            end
            if run.status == "incomplete" then
                assertEqual(r.tail, nil, run.id .. ": an early end has no tail")
                assertEqual(r.combatEnd, nil, run.id)
                assertEqual(r.sessionDuration, math.ceil(r.endedAt), run.id)
            else
                assertTrue(r.combatEnd >= r.tail, run.id .. ": combat ended before the last damage")
                tails[r.tail] = true
            end
        end
        if run.flags.restartedAt then
            assertTrue(run.result.tail > run.flags.restartedAt, run.id .. ": a restart past the last damage")
        end
        if run.schema >= 4 and run.status ~= "lost" then
            assertTrue(run.loadout ~= nil, run.id .. ": a format-4 run has its loadout")
            assertTrue(run.stats ~= nil, run.id .. ": a format-4 run has its stats")
        end
    end
    local n = 0
    for _ in pairs(tails) do n = n + 1 end
    assertTrue(n >= 6, "the tails do not vary")
end)

test("sample parity: every spell that deals damage was cast, and every cast of damage shows in the spells", function()
    local f = fixture("WARLOCK")
    local run = f.MR.Dataset().runs[1]
    local cast, hit = {}, {}
    for _, c in ipairs(f.NS.Casts.Of(run)) do cast[c.id] = true end
    for _, s in ipairs(run.spells) do
        hit[s.id] = true
        assertTrue(cast[s.id] == true, "damage with no cast: " .. s.id)
    end
    for _, row in ipairs(f.NS.MockRotations.WARLOCK) do
        if cast[row.id] and row.hit then assertTrue(hit[row.id] == true, "a cast with no damage: " .. row.id) end
    end
end)

test("sample parity: a flagged run's late cast is in its own cast list, past the buzzer", function()
    local f = fixture("WARLOCK")
    local run = f.MR.Dataset().runs[3]
    assertEqual(#run.flags.lateCasts, 2)
    local past = 0
    for _, c in ipairs(f.NS.Casts.Of(run)) do
        if c.t > run.race.length then past = past + 1 end
    end
    assertEqual(past, 2)
end)

test("sample parity: a raised grace judges the sample's late casts as it would a race's", function()
    local f = fixture("WARLOCK")
    f.NS.db.profile.race.grace = 5
    assertEqual(#f.MR.Dataset().runs[3].flags.lateCasts, 0)
end)

test("sample parity: the player draws their own class's rotation; every class has one", function()
    for class, rows in pairs(fixture().NS.MockRotations) do
        local f = fixture(class)
        assertEqual(f.MR.Player().class, class)
        local own = {}
        for _, row in ipairs(rows) do own[row.id] = true end
        for _, s in ipairs(f.MR.Dataset().runs[1].spells) do
            assertTrue(own[s.id] == true, class .. " drew a stranger's spell " .. s.id)
        end
    end
end)

test("sample parity: a made-up character carries its own trinket, bags and gear, not the player's", function()
    local f = fixture("WARLOCK")
    local data = f.MR.Dataset()
    local alt = data.runs[11]
    assertEqual(alt.char.name, "Sampleblade")
    assertEqual(alt.usage.used[1].itemID, 212454)
    local gear = f.NS.ResultsSource.Use(data) and f.NS.ResultsSource.LoadoutOf(alt)
    assertTrue(gear[16]:find("Sample Greatsword", 1, true) ~= nil)
    f.NS.ResultsSource.Restore()
end)

test("sample parity: loadout b changes a slot, never empties it", function()
    local f = fixture()
    f.M.GetInventoryItemLink = function(_, slot) return slot == 14 and "|Hitem:1|h[a]|h" or nil end
    local sets = f.MR.Loadouts()
    assertTrue(sets.gear["sample-b"][14] ~= nil)
    assertTrue(sets.gear["sample-b"][14] ~= sets.gear["sample-a"][14])
end)

-- ── the race: one path ──────────────────────────────────────────────────────────────────────────

test("sample parity: the running figures are the meter's shape: nothing before the first hit, rows that move", function()
    local f = fixture("WARLOCK")
    sim(f, "newbest")
    local Race = f.NS.SampleRace
    assertEqual(Race.ReadLive(), nil, "no live read while armed")
    until_(f, function() return Race.State() == "running" end)
    assertEqual(f.MR.LiveAt(f.Sim and select(2, f.MR.Run({ id = "x", char = f.MR.Player(), category = "single",
        length = 30, dps = 1000 })), 0), nil, "the meter has no row before the first hit")
    local tops, last, tops_n = {}, nil, 0
    while Race.State() == "running" do
        f:advance(1)
        local live = Race.ReadLive()
        if live then
            if last then assertTrue(live.total >= last, "the total went down") end
            last = live.total
            assertEqual(live.maxAmount, live.spells[1].total, "maxAmount is the top spell's")
            local rate = live.total / math.max(1, math.ceil(f.Hud.View().elapsed or 1))
            assertTrue(live.dps <= rate + 1, "the rate is the meter's")
            if not tops[live.spells[1].spellID] then tops[live.spells[1].spellID], tops_n = true, tops_n + 1 end
        end
    end
    assertTrue(tops_n >= 2, "the top spell never changed")
end)

test("sample parity: the running chart and the card's are the same buckets, short of the final at the buzzer", function()
    local f = fixture("WARLOCK")
    sim(f, "newbest")
    until_(f, function() return f.NS.SampleRace.Elapsed() and f.NS.SampleRace.Elapsed() >= 20 end)
    local rec = f.NS.Slices.Get("sim-newbest")
    local mid = {}
    for i = 1, 15 do mid[i] = rec.values[i] end
    until_(f, function() return current(f) == "result" end)
    local after = f.NS.HudChart.ResultView(f.NS.SampleRace.Current())
    for i = 1, 15 do assertEqual(after.values[i], mid[i], "bucket " .. i) end
    assertTrue(after.values[30] < f.NS.SampleRace.Current().result.damage, "the tail still counts after the buzzer")
end)

test("sample parity: the run joins the sample history at its start and resolves in place", function()
    local f = fixture("WARLOCK")
    sim(f, "newbest")
    assertEqual(f.NS.ResultsSource.Get("sim-newbest"), nil, "armed: not yet")
    until_(f, function() return f.NS.SampleRace.State() == "running" end)
    local run = f.NS.ResultsSource.Get("sim-newbest")
    assertEqual(run.status, "running")
    assertEqual(run.result, nil, "nothing to read yet")
    assertTrue(run.build ~= nil and run.stats ~= nil and run.loadout ~= nil, "the run has what a race's has")
    until_(f, function() return current(f) == "result" end)
    assertEqual(f.NS.ResultsSource.Get("sim-newbest"), run, "the same record")
    assertEqual(run.status, "complete")
end)

test("sample parity: a run that ended early shows Combat Ended, with no tail and no buzzer", function()
    local f = fixture("WARLOCK")
    sim(f, "incomplete")
    until_(f, function() return current(f) == "waiting" end)
    local v = f.Hud.View()
    assertTrue(v.endedEarly, "the waiting body's early end")
    assertEqual(v.sinceBuzzer, nil)
    assertEqual(v.endedAt, 18)
    assertFalse(v.inCombat)
    assertEqual(ui(f).body.waiting.w.tail.label.__text, "Combat Ended")
end)

test("sample parity: complete runs go out of combat before the read, and the hint waits for its delay", function()
    local f = fixture("WARLOCK")
    sim(f, "sticky")
    until_(f, function() return current(f) == "waiting" end)
    assertEqual(f.Hud.View().hint, nil, "no hint before race.hintDelay")
    until_(f, function() return f.Hud.View().hint ~= nil end)
    local _, delay = nil, f.NS.GetSetting("race.hintDelay")
    assertTrue(f.Hud.View().sinceBuzzer >= delay)
    until_(f, function() return not f.NS.SampleRace.InCombat() end)
    f.Hud.Tick()
    assertEqual(current(f), "waiting", "out of combat, the read waits for the quiet")
    assertEqual(f.Hud.View().hint, nil)
    until_(f, function() return current(f) == "result" end)
end)

test("sample parity: the race's messages reach the buzzer, the chat lines and the toast, and no RUN_SAVED", function()
    local f = fixture("WARLOCK")
    local sent = {}
    local bus = f.NS.NewBusTarget()
    for _, name in ipairs({ "RACE_BUZZER", "RACE_RESULT", "RUN_SAVED" }) do
        bus:RegisterMessage(f.NS.MSG[name], function() sent[name] = (sent[name] or 0) + 1 end)
    end
    f.M.__resetPrinted()
    sim(f, "newbest")
    until_(f, function() return current(f) == "result" end)
    assertEqual(sent.RACE_BUZZER, 1)
    assertEqual(sent.RACE_RESULT, 1)
    assertEqual(sent.RUN_SAVED, nil)
    local text = table.concat(f.M.__printed(), "\n")
    assertTrue(text:find("Armed:", 1, true) ~= nil, "the armed line")
    assertTrue(text:find("new best", 1, true) ~= nil, "the result line, against the sample history")
    local stats = f.NS.BestToast.Instance():Stats()
    assertEqual(stats.key, "sim-newbest", "the new-best toast, the real path")
    assertFalse(stats.sticky == true)
    f.Preview.Stop()
    assertEqual(f.NS.BestToast.Instance():Stats().key, nil, "gone with the sim")
end)

test("sample parity: a sim neither ends itself on its own arm nor arms AutoArm's rule", function()
    local f = fixture("WARLOCK")
    sim(f, "newbest")
    assertTrue(f.Preview.IsActive(), "its own ARMED ended it")
    assertEqual(f.Race.State(), "idle")
    assertEqual(f.Sim.Diagnose().ticking, true)
end)

test("sample parity: the sample card honors Show spell icons, and every setting while it is held", function()
    local f = fixture("WARLOCK")
    assertTrue(f.Preview.Start({ mode = "test", state = "result" }))
    assertTrue(f.Hud.View().icons)
    assertTrue(f.NS.SetByPath("live.icons", false))
    f.Hud.Refresh()
    assertFalse(f.Hud.View().icons, "the setting holds on the sample card")
    assertTrue(f.Preview.SetState("running"))
    local lo = f.Hud.View().pace.lo
    assertTrue(f.NS.SetByPath("live.paceRange", 2))
    f.Hud.Refresh()
    assertTrue(f.Hud.View().pace.lo ~= lo, "a held body reads the pace range anew")
end)

test("sample parity: a change to the sample history reaches the card, as RUNS_CHANGED does a real one", function()
    local f = fixture("WARLOCK")
    sim(f, "newbest")
    until_(f, function() return current(f) == "result" end)
    local before = f.Hud.View().delta
    assertTrue(f.R.DeleteRun("sample-01"))
    assertTrue(f.Hud.View().delta ~= before, "the delta names the best still before the run")
    assertTrue(f.R.DeleteRun("sim-newbest"))
    assertEqual(current(f), "idle", "the card over a deleted run goes")
    assertEqual(f.Race.State(), "idle")
end)

test("sample parity: a sim's card dismissed by New Race or Delete opens no Results window after it", function()
    local function card()
        local f = fixture("WARLOCK")
        sim(f, "newbest")
        until_(f, function() return current(f) == "result" end)
        f.R.Hide()
        return f
    end
    local f = card()
    assertTrue(f.Hud.Act.newRace())
    assertEqual(current(f), "idle")
    f:advance(f.Sim.RESULT_HOLD + 1)
    assertFalse(f.R.wanted == true, "the script's end opened over the idle body")
    assertTrue(f.Preview.IsActive(), "New Race on the card keeps the preview")
    assertEqual(f.Sim.Diagnose().ticking, false, "a script with nothing left kept ticking")

    local g = card()
    assertTrue(g.R.DeleteRun("sim-newbest"))
    assertEqual(current(g), "idle")
    local shown
    local real = g.R.ShowRun
    g.R.ShowRun = function(id) shown = id; return real(id) end
    g:advance(g.Sim.RESULT_HOLD + 1)
    assertEqual(shown, nil, "the script's end asked for a deleted run")
    assertFalse(g.R.wanted == true)
end)

test("sample parity: a held state's history is the same moment's: the board, the row and the card agree", function()
    local f = fixture("WARLOCK")
    local Source = f.NS.ResultsSource
    local function key() return f.NS.Bests.Key(Source.Get("sample-01")) end
    assertTrue(f.Preview.Start({ mode = "test", state = "running" }))
    assertEqual(Source.Get("sim-newbest").status, "running")
    assertEqual(Source.Board()[key()].id, "sample-01", "nothing beats the best yet")

    assertTrue(f.Preview.SetState("result"))
    assertEqual(Source.Get("sim-newbest").status, "complete")
    assertEqual(Source.Board()[key()].id, "sim-newbest", "the board kept the running moment's best")
    assertEqual(f.NS.Bests.Board()[key()].id, "sim-newbest")
    assertEqual(Source.Board().id, f.NS.Bests.Compute(Source.All()).id)
    assertTrue(f.Hud.View().isNew == true, "the card's a new best, as the board says")

    assertTrue(f.Preview.SetState("running"))
    assertEqual(Source.Get("sim-newbest").status, "running")
    assertEqual(Source.Board()[key()].id, "sample-01", "a run in progress holds no best")

    assertTrue(f.Preview.SetState("armed"))
    assertEqual(Source.Get("sim-newbest"), nil, "armed: not yet, as a sim's")
    assertEqual(Source.Board()[key()].id, "sample-01")

    assertTrue(f.Preview.SetState("result"))
    assertEqual(Source.Board()[key()].id, "sim-newbest", "back on the card")
end)

test("sample parity: a state switch redraws an open Results window on the moment held", function()
    local f = fixture("WARLOCK")
    assertTrue(f.Preview.Start({ mode = "test", state = "running" }))
    assertTrue(f.R.IsShown())
    local drawn, real = nil, f.R.OnSourceChanged
    f.R.OnSourceChanged = function(...)
        local r = f.NS.ResultsSource.Get("sim-newbest")
        drawn = r and r.status
        return real(...)
    end
    assertTrue(f.Preview.SetState("result"))
    assertEqual(drawn, "complete", "the window's last draw had the running row")
    f.R.OnSourceChanged = real
end)

test("sample parity: the HUD's reads go through its throttle: live.hz bounds them", function()
    local f = fixture("WARLOCK")
    f.NS.db.profile.live.hz = 2
    local reads, real = 0, f.NS.SampleRace.ReadLive
    f.NS.SampleRace.ReadLive = function() reads = reads + 1; return real() end
    sim(f, "newbest")
    until_(f, function() return f.NS.SampleRace.State() == "running" end)
    reads = 0
    f:advance(10)
    assertTrue(reads >= 15 and reads <= 32, "reads in 10s at 2 Hz plus the boundaries: " .. reads)
    f.NS.SampleRace.ReadLive = real
end)

test("sample parity: a held race reads nothing and holds no timer; the sim's timers end with it", function()
    local f = fixture("WARLOCK")
    assertTrue(f.Preview.Start())
    assertEqual(#f.M.__timers(), 0, "a frozen race holds no timer")
    assertEqual(f.NS.Countdown.Diagnose().scheduled, 0)
    f.Preview.Stop()
    assertEqual(f.NS.Slices.Get("sim-newbest"), nil, "its buckets go with it")
    assertEqual(f.NS.Casts.Collecting(), false)
end)

test("sample parity: arming a real race from under a sim keeps that race's cast list", function()
    local f = fixture("WARLOCK")
    sim(f, "newbest")
    f:advance(5)
    assertTrue(f.Race.Arm(30))
    assertFalse(f.Preview.IsActive())
    assertTrue(f.NS.Casts.Collecting(), "the real race's capture was reset")
end)
