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
    -- DR-04: the class and spec icons sit between the two halves, so the words are two strings.
    assertEqual(p.title, ("|c%sNew best:|r"):format(Tbl.Hex(Tbl.COLORS.blue)), "the words in blue")
    assertEqual(p.who, ("|c%sDestruction %s|r"):format(Tbl.Hex(Tbl.ClassColor("WARLOCK")),
        Tbl.ClassName("WARLOCK")), "spec and class in class color")
    assertEqual(p.class, "WARLOCK", "the class token, for its icon")
    assertEqual(p.specIcon, 136186, "the spec's icon, through GetSpecializationInfoByID")
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
    assertEqual(w.who:GetText(), p.who)
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

test("toast: a new best whose late casts are all ignored shows no flags line and no ignored chip", function()
    local f = fixture()
    run(f, "old", 100, 100000)
    local feign = run(f, "feign", 200, 120000, { flags = { lateCasts = { { t = 1.4, spellID = 5384 } } } })
    result(f, feign)
    assertEqual(shownKey(f), "feign")
    assertFalse(f.toast:Frame().dpsRace.flags:IsShown())
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

-- ── the layout (DR-04, Addendum 03, image-60) ────────────────────────────────────────────────────

--- The y offset of `region`'s first point (each row is anchored once, TOPLEFT on the frame).
local function topOf(region)
    local pt = region.__points and region.__points[1]
    return pt and pt[5]
end

test("toast: 25% larger, its height the named constant, every size scaled by the same factor", function()
    -- red under: the 72 px toast of the first release, or a size left unscaled.
    local f = fixture()
    local BT = f.BT
    assertEqual(BT.SCALE, 1.25)
    assertEqual(BT.HEIGHT, 90, "72 x 1.25: the height DropWatcher's toast matches (DW-05)")
    assertEqual(BT.HEIGHT, 2 * BT.PAD + BT.ROWS_H, "even padding above the first row and below the last")
    assertEqual(BT.CHIP_H, f.NS.ResultsTable.CHIP_H * BT.SCALE, "the chips 25% taller")
    assertEqual(BT.TITLE_SIZE, 12 * BT.SCALE, "the title's 12 px face, scaled")
    assertEqual(BT.TEXT_SIZE, 10 * BT.SCALE, "the text's 10 px face, scaled")
    assertTrue(BT.WIDTH >= 340 * BT.SCALE, "at least 25% wider, then widened for the trophy")
end)

test("toast: the trophy is as tall as the three rows, the rows evenly spaced and padded", function()
    local f = fixture()
    local BT = f.BT
    run(f, "old", 100, 100000)
    result(f, run(f, "new", 200, 110000))
    local w = f.toast:Frame().dpsRace
    assertEqual(BT.ROWS_H, BT.TITLE_H + BT.ROW_GAP + BT.CHIP_H + BT.ROW_GAP + BT.TEXT_H)
    assertEqual(w.icon.__width, BT.ROWS_H, "the trophy's width")
    assertEqual(w.icon.__height, BT.ROWS_H, "the trophy as tall as the headline, the tags and the DPS line")
    assertEqual(topOf(w.icon), -BT.PAD, "level with the first row")
    assertEqual(topOf(w.title), -BT.PAD, "the headline under the top padding")
    assertEqual(w.title.__height, BT.TITLE_H)
    local chipTop, detailTop = topOf(w.chips[1]), topOf(w.detail)
    assertEqual(chipTop, -(BT.PAD + BT.TITLE_H + BT.ROW_GAP), "the tags one gap under the headline")
    assertEqual(w.chips[1].__height, BT.CHIP_H)
    assertEqual(detailTop, chipTop - BT.CHIP_H - BT.ROW_GAP, "the DPS line one equal gap under the tags")
    assertEqual(w.detail.__height, BT.TEXT_H)
    assertEqual(-detailTop + BT.TEXT_H + BT.PAD, BT.HEIGHT, "the bottom padding equals the top")
    local left = BT.PAD + BT.ROWS_H + BT.GAP
    assertEqual(w.title.__points[1][4], left, "the rows start right of the trophy")
    assertEqual(w.chips[1].__points[1][4], left)
    assertEqual(w.detail.__points[1][4], left)
end)

test("toast: the class and spec icons sit beside the spec and class words", function()
    local f = fixture()
    local BT = f.BT
    run(f, "old", 100, 100000)
    result(f, run(f, "new", 200, 110000))
    local w = f.toast:Frame().dpsRace
    assertTrue(w.class:IsShown(), "the class icon")
    assertEqual(table.concat(w.class.__texCoord, ","), table.concat(f.M.CLASS_ICON_TCOORDS.WARLOCK, ","))
    assertTrue(w.spec:IsShown(), "the spec icon")
    assertEqual(w.spec.__texture, 136186)
    assertEqual(w.class.__width, BT.CLASS_ICON)
    assertEqual(w.class.__height, BT.CLASS_ICON)
    local function anchor(region) return region.__points[1] end
    assertTrue(anchor(w.class)[2] == w.title and anchor(w.class)[3] == "RIGHT", "the class icon after New best:")
    assertTrue(anchor(w.spec)[2] == w.class and anchor(w.spec)[3] == "RIGHT", "the spec icon after the class icon")
    assertTrue(anchor(w.who)[2] == w.spec and anchor(w.who)[3] == "RIGHT", "the words after the icons")
end)

test("toast: a class or spec the client cannot draw leaves no icon", function()
    local f = fixture()
    local p = f.BT.Payload({ id = "x", status = "complete", char = { class = "PALADIN", spec = "Holy" },
        target = { category = "single" }, race = { length = 60 }, result = { dps = 1 } }, nil, nil)
    assertNil(p.specIcon)
    f.BT.Instance():Show(p, { key = "x" })
    local w = f.toast:Frame().dpsRace
    assertFalse(w.class:IsShown(), "no coordinates for that class in this client")
    assertFalse(w.spec:IsShown(), "no spec ID, so no icon")
    -- red under: the hidden icons kept their fixed offsets, a 10 px hole before the words.
    local at = w.who.__points[1]
    assertTrue(at[2] == w.title and at[3] == "RIGHT", "the words close up on New best:")
    assertEqual(at[4], 4, "one icon gap after it")
end)

test("toast: a spec icon without a class icon sits one gap after New best:", function()
    local f = fixture()
    local p = f.BT.Payload({ id = "x", status = "complete", char = { class = "PALADIN", spec = "Holy" },
        target = { category = "single" }, race = { length = 60 }, result = { dps = 1 } }, nil, nil)
    p.specIcon = 136186
    f.BT.Instance():Show(p, { key = "x" })
    local w = f.toast:Frame().dpsRace
    assertTrue(w.spec:IsShown())
    local at = w.spec.__points[1]
    assertTrue(at[2] == w.title and at[3] == "RIGHT" and at[4] == 4, "the spec icon after New best:")
    assertTrue(w.who.__points[1][2] == w.spec, "the words after the spec icon")
end)

test("toast: the rows' text draws at the scaled sizes", function()
    local f = fixture()
    local BT = f.BT
    run(f, "old", 100, 100000)
    result(f, run(f, "new", 200, 110000))
    local w = f.toast:Frame().dpsRace
    local function size(fs) local _, s = fs:GetFont() return s end
    assertEqual(size(w.title), BT.TITLE_SIZE, "the headline")
    assertEqual(size(w.who), BT.TITLE_SIZE, "the spec and class")
    assertEqual(size(w.detail), BT.TEXT_SIZE, "the DPS line")
    assertEqual(size(w.chips[1].fs), BT.TEXT_SIZE, "a tag's word")
end)
