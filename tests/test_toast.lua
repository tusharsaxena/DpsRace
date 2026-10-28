-- tests/test_toast.lua — the new-best toast (#5, modules/BestToast.lua on LibKa0s-Toast-1.0 through
-- core/ToastSetup.lua): one toast per complete run that beats an earlier best on its board, whether or
-- not the HUD is shown; none for an incomplete or lost run, a run that is not a best, a board's first
-- run, or with the toast turned off. Its words, its duration and sound from the settings, test mode's
-- held sample and *Test toast*, the drag only in test mode, the stored place, and the stand-down.
--
-- Every case runs on the race fixture (tests/race_clock.lua: the fake clock fires each timer at its own
-- GetTime()), so a toast's countdown runs as the client would run it.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

-- The widget recorder dresses the toast's rows, so what they were told can be read back.
local function fixture()
    local f = RaceClock.new{ mutate = function(m) Widgets.install(m) end }
    f.BT = f.NS.BestToast
    f.toast = f.BT.Instance()
    return f
end

--- A stored-shape run on the Destruction / single-target / 60 s board.
local function run(f, id, date, dps, o)
    o = o or {}
    local status = o.status or "complete"
    local r = {
        id = id, schema = 4, status = status, date = date,
        race = { length = o.length or 60, grace = 1, restartGap = 6 },
        char = { name = "Lanfear", class = "WARLOCK", spec = "Destruction", specID = 267 },
        target = { name = "Training Dummy", category = o.category or "single", count = 1 },
        result = (status ~= "lost") and { damage = (dps or 0) * (o.length or 60), dps = dps } or nil,
        flags = o.flags or { lateCasts = {} }, spells = {}, note = "",
    }
    f.NS.db.global.runs[id] = r
    f.NS.Bests.Invalidate()
    return r
end

local function result(f, r) f.NS.SendBus(f.NS.MSG.RACE_RESULT, r) end

local function shownKey(f)
    local _, key = f.toast:Current()
    return key
end

-- ── the trigger ─────────────────────────────────────────────────────────────────────────────────

test("toast: a complete run that beats the board's best toasts once, whatever the HUD shows", function()
    local f = fixture()
    assertTrue(f.NS.SetByPath("visibility", "never"))
    run(f, "old", 100, 100000)
    local new = run(f, "new", 200, 110000)
    assertFalse(f.NS.Hud.IsShown())
    result(f, new)
    assertEqual(shownKey(f), "new", "the new best's toast is on screen under its run id")
    local frame = f.toast:Frame()
    assertTrue(frame:IsShown())
    assertEqual(frame.__strata, "HIGH", "frame-layering's T5 alert tier")
    assertTrue(frame.__mouse, "an interactive toast takes the mouse")
    assertEqual(f.toast:Stats().waiting, 0, "one toast, nothing queued behind it")
    local again = run(f, "again", 300, 120000)
    result(f, again)
    assertEqual(shownKey(f), "new", "one at a time")
    assertEqual(f.toast:Stats().waiting, 1, "the next new best waits its turn")
end)

test("toast: none for an incomplete or lost run, a run that is no best, a board's first run, or turned off", function()
    local f = fixture()
    local first = run(f, "first", 100, 100000)
    result(f, first)
    assertNil(shownKey(f), "a board's first run has nothing to beat")
    result(f, run(f, "slower", 200, 90000))
    assertNil(shownKey(f), "not a best")
    result(f, run(f, "inc", 300, 200000, { status = "incomplete" }))
    assertNil(shownKey(f), "an incomplete run never toasts")
    result(f, run(f, "lost", 400, nil, { status = "lost" }))
    assertNil(shownKey(f), "a lost run never toasts")
    assertTrue(f.NS.SetByPath("toast.enabled", false))
    result(f, run(f, "off", 500, 300000))
    assertNil(shownKey(f), "the toast is turned off")
    assertFalse(f.toast:Stats().built, "no frame was ever built")
end)

test("toast: the payload names the spec and class, the board's chips, the DPS and the gain over the old best", function()
    local f = fixture()
    local NS = f.NS
    local Tbl = NS.ResultsTable
    run(f, "old", 100, 100000)
    local new = run(f, "new", 200, 104200)
    local _, _, prev = NS.Bests.Delta(new)
    local p = f.BT.Payload(new, 4.2, prev)
    assertEqual(p.title, ("|c%sNew best:|r |c%sDestruction %s|r"):format(Tbl.Hex(Tbl.COLORS.blue),
        Tbl.Hex(Tbl.ClassColor("WARLOCK")), Tbl.ClassName("WARLOCK")), "the words in blue, spec and class in class color")
    assertEqual(p.chips[1][1], "Single target")
    assertEqual(p.chips[1][2], select(2, Tbl.Badge(new.target)), "the target chip in the Runs list's category color")
    assertEqual(p.chips[2][1], "1:00")
    assertEqual(p.chips[2][2], Tbl.LengthColor(60), "the time chip in the Runs list's length color")
    assertEqual(p.detail, ("%s DPS, +4.2%% better than previous best (%s)"):format(NS.Format.Number(104200),
        NS.Format.Number(100000)))
    assertEqual(p.detailColor, Tbl.COLORS.green, "a gain reads green")
    assertNil(p.flags, "a clean run has no flags line")
    result(f, new)
    local w = f.toast:Frame().dpsRace
    assertEqual(w.title:GetText(), p.title)
    assertEqual(w.chips[1].fs:GetText(), "Single target")
    assertEqual(w.chips[2].fs:GetText(), "1:00")
    assertTrue(w.chips[1]:IsShown() and w.chips[2]:IsShown())
    assertEqual(w.detail:GetText(), p.detail)
    assertFalse(w.flags:IsShown())
end)

test("toast: with no previous best to name, the DPS line is the DPS alone in the text color", function()
    local f = fixture()
    local new = run(f, "new", 200, 104200)
    local p = f.BT.Payload(new, nil, nil)
    assertEqual(p.detail, ("%s DPS"):format(f.NS.Format.Number(104200)))
    assertEqual(p.detailColor, f.NS.ResultsTable.COLORS.text)
end)

test("toast: a flagged run may toast, its flags on the last line as the result card words them", function()
    local f = fixture()
    run(f, "old", 100, 100000)
    local late = run(f, "late", 200, 120000, { flags = { lateCasts = { { t = 1.4, spellID = 29722 } } } })
    result(f, late)
    assertEqual(shownKey(f), "late", "the all-runs board decides: a flagged run holds a best")
    local w = f.toast:Frame().dpsRace
    assertEqual(w.flags:GetText(), "1 late cast")
    assertTrue(w.flags:IsShown())
end)

-- ── the lifetime ────────────────────────────────────────────────────────────────────────────────

test("toast: it closes after Toast duration, plays its sound only with Play a sound on", function()
    local f = fixture()
    local played = 0
    f.M.SOUNDKIT = { UI_EPICLOOT_TOAST = 12345 }
    f.M.PlaySound = function() played = played + 1 end
    assertTrue(f.NS.SetByPath("toast.duration", 5))
    run(f, "old", 100, 100000)
    result(f, run(f, "a", 200, 110000))
    assertEqual(played, 1, "the alert played as it showed")
    f:advance(4.9)
    assertEqual(shownKey(f), "a", "still up inside its duration")
    f:advance(0.2)
    assertNil(shownKey(f), "gone after Toast duration")
    assertTrue(f.NS.SetByPath("toast.sound", false))
    result(f, run(f, "b", 300, 120000))
    assertEqual(shownKey(f), "b")
    assertEqual(played, 1, "silent with Play a sound off")
end)

-- ── test mode, Test toast, the place ────────────────────────────────────────────────────────────

test("toast: test mode holds the sample race's toast, and its end takes it down", function()
    local f = fixture()
    assertTrue(f.NS.Preview.Start())
    assertEqual(shownKey(f), f.NS.TOAST_PREVIEW, "test mode shows the sample's toast")
    assertTrue(f.toast:Stats().sticky, "held for placing: no countdown")
    assertTrue(f.toast:Frame().dpsRace.title:GetText():find("New best:", 1, true) ~= nil)
    f:advance(60)
    assertEqual(shownKey(f), f.NS.TOAST_PREVIEW, "still up")
    -- Off and on again while test mode is on: the sample goes and comes back.
    assertTrue(f.NS.SetByPath("toast.enabled", false))
    assertNil(shownKey(f))
    assertTrue(f.NS.SetByPath("toast.enabled", true))
    assertEqual(shownKey(f), f.NS.TOAST_PREVIEW)
    f.NS.Preview.Stop()
    assertNil(shownKey(f), "the end of test mode takes it down")
    assertFalse(f.BT.Diagnose().preview)
end)

test("toast: Test toast queues a sample that runs its course, and a second click replaces it", function()
    local f = fixture()
    assertTrue(f.BT.Test())
    assertEqual(shownKey(f), f.BT.SAMPLE)
    assertFalse(f.toast:Stats().sticky, "a sample runs as a real toast does")
    local p = f.toast:Current()
    assertTrue(p.detail:find("+4.2%", 1, true) ~= nil, p.detail)
    f.BT.Test()
    assertEqual(f.toast:Stats().waiting, 0, "the sample replaced, not stacked")
    f:advance(f.NS.GetSetting("toast.duration") + 0.1)
    assertNil(shownKey(f))
end)

local function dragSpy(frame)
    local moved = 0
    rawset(frame, "StartMoving", function() moved = moved + 1 end)
    rawset(frame, "StopMovingOrSizing", function() end)
    return function() return moved end
end

test("toast: a real toast never moves; in test mode or as a sample it drags", function()
    local f = fixture()
    run(f, "old", 100, 100000)
    result(f, run(f, "new", 200, 110000))
    local frame = f.toast:Frame()
    local moved = dragSpy(frame)
    frame:__fire("OnDragStart", "LeftButton")
    assertEqual(moved(), 0, "a real toast outside test mode stays where it is")
    f.toast:Dismiss()
    assertTrue(f.BT.Test())
    frame:__fire("OnDragStart", "LeftButton")
    assertEqual(moved(), 1, "a sample drags")
    frame:__fire("OnDragStop")
    f.toast:Dismiss()
    assertTrue(f.NS.Preview.Start())
    frame:__fire("OnDragStart", "LeftButton")
    assertEqual(moved(), 2, "test mode's toast drags")
end)

test("toast: a drag stores the place in the profile in UIParent units; Reset position clears it", function()
    local f = fixture()
    assertTrue(f.NS.SetByPath("toast.scale", 2))
    assertTrue(f.NS.Preview.Start())
    local frame = f.toast:Frame()
    dragSpy(frame)
    rawset(frame, "GetPoint", function() return "TOPLEFT", f.M.UIParent, "TOPLEFT", 50, -40 end)
    rawset(frame, "GetScale", function() return 2 end)
    frame:__fire("OnDragStart", "LeftButton")
    frame:__fire("OnDragStop")
    local pt = f.NS.db.profile.toast.point
    assertEqual(table.concat({ pt[1], pt[2], pt[3], pt[4] }, ","), "TOPLEFT,TOPLEFT,100,-80",
        "the frame's point times its scale")
    for _, v in ipairs(pt) do assertTrue(type(v) == "string" or type(v) == "number", "plain values only") end
    f.NS.Preview.Stop()
    f.NS.BestToast.ResetPosition()
    assertNil(f.NS.db.profile.toast.point, "Reset position forgets the place")
end)

test("toast: a profile switch follows the new profile's switch: a toast up goes, test mode's comes back", function()
    local f = fixture()
    f.NS.db:SetProfile("Other")
    assertTrue(f.NS.SetByPath("toast.enabled", false))
    f.NS.db:SetProfile("Default")
    run(f, "old", 100, 100000)
    result(f, run(f, "new", 200, 110000))
    assertEqual(shownKey(f), "new")
    f.NS.db:SetProfile("Other")
    assertNil(shownKey(f), "a toast stayed up under a profile with the toast off")
    assertTrue(f.NS.Preview.Start())
    assertNil(shownKey(f), "test mode's toast with the toast off")
    f.NS.db:SetProfile("Default")
    assertTrue(f.NS.Preview.IsActive(), "the switch ended test mode")
    assertEqual(shownKey(f), f.NS.TOAST_PREVIEW, "test mode's toast not brought back")
end)

-- ── the stand-down ──────────────────────────────────────────────────────────────────────────────

test("toast: the stand-down takes the toast down and drops what waits; a result while down shows none", function()
    local f = fixture()
    run(f, "old", 100, 100000)
    result(f, run(f, "a", 200, 110000))
    result(f, run(f, "b", 300, 120000))
    assertEqual(f.toast:Stats().waiting, 1)
    assertTrue(f.NS.SetByPath("enabled", false))
    assertNil(shownKey(f), "nothing on screen")
    assertEqual(f.toast:Stats().waiting, 0, "nothing waiting")
    assertFalse(f.toast:Frame():IsShown())
    result(f, run(f, "c", 400, 130000))
    assertNil(shownKey(f), "the bus receiver is dropped while stood down")
    assertTrue(f.NS.SetByPath("enabled", true))
    result(f, run(f, "d", 500, 140000))
    assertEqual(shownKey(f), "d", "back after the stand-up")
end)
