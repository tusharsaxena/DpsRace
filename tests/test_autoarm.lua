-- tests/test_autoarm.lua — auto-show and auto-arm near a training dummy (#16, modules/AutoArm.lua): both
-- off by default; the HUD opened by a dummy target or nameplate and closed again only after the
-- debounce, never over a race or a result, never against the player's close in the same session;
-- the race armed on targeting a cataloged dummy through Race.Arm's refusals, canceled by a target
-- change before the pull and never after it; nothing in an instance or while stood down.
--
-- Every case runs on the race fixture (tests/race_clock.lua: the scripted meter and the fake clock
-- that fires timers at their own GetTime()), the target and the nameplates from tests/wow_mock.lua.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)

local CLEAVE = { guid = "Creature-0-1-2-3-243208-0001", name = "Cleave Training Dummy" }
local GOLEM = { guid = "Creature-0-1-2-3-243205-0001", name = "Reinforced Golem" }
local BOAR = { guid = "Creature-0-1-2-3-99999-0001", name = "Angry Boar" }

--- A race fixture with the two rules set as asked (both off when not named).
local function fixture(opts)
    opts = opts or {}
    local f = RaceClock.new()
    f.Hud, f.AutoArm = f.NS.Hud, f.NS.AutoArm
    if opts.show then assertTrue(f.NS.SetByPath("hud.autoShow", true)) end
    if opts.arm then assertTrue(f.NS.SetByPath("race.autoArm", true)) end
    return f
end

local function target(f, t)
    f.M.__setTarget(t)
    f.M.__fire("PLAYER_TARGET_CHANGED")
end

local function plateUp(f, unit, t)
    f.M.__setPlate(unit, t)
    f.M.__fire("NAME_PLATE_UNIT_ADDED", unit)
end

local function plateDown(f, unit)
    f.M.__setPlate(unit, nil)
    f.M.__fire("NAME_PLATE_UNIT_REMOVED", unit)
end

local function eventsHeld(f)
    local seen = {}
    for _, r in ipairs(f.M.__registrations()) do
        if r.event then seen[r.event] = true end
    end
    return seen
end

-- ── off by default ──────────────────────────────────────────────────────────────────────────────

test("autoarm: both rules are off by default and register nothing", function()
    local f = fixture()
    assertFalse(f.NS.GetSetting("hud.autoShow"))
    assertFalse(f.NS.GetSetting("race.autoArm"))
    assertEqual(f.NS.defaults.profile.hud.autoShow, false)
    assertEqual(f.NS.defaults.profile.race.autoArm, false)
    assertEqual(f.AutoArm.Diagnose().events, "none")
    assertFalse(eventsHeld(f).NAME_PLATE_UNIT_ADDED == true)
    target(f, CLEAVE)
    plateUp(f, "nameplate1", GOLEM)
    assertEqual(f.Race.State(), "idle", "nothing armed with the rule off")
    assertFalse(f.Hud.IsShown(), "nothing shown with the rule off")
end)

test("autoarm: each rule registers only what it needs, and turning both off drops it all", function()
    local f = fixture{ arm = true }
    local held = eventsHeld(f)
    assertEqual(f.AutoArm.Diagnose().events, "target")
    assertTrue(held.PLAYER_TARGET_CHANGED and held.PLAYER_ENTERING_WORLD)
    assertFalse(held.NAME_PLATE_UNIT_ADDED == true, "auto-arm alone needs no nameplates")
    assertTrue(f.NS.SetByPath("hud.autoShow", true))
    held = eventsHeld(f)
    assertEqual(f.AutoArm.Diagnose().events, "plates")
    assertTrue(held.NAME_PLATE_UNIT_ADDED and held.NAME_PLATE_UNIT_REMOVED)
    assertTrue(f.NS.SetByPath("hud.autoShow", false))
    assertTrue(f.NS.SetByPath("race.autoArm", false))
    assertEqual(f.AutoArm.Diagnose().events, "none")
end)

-- ── auto-show ───────────────────────────────────────────────────────────────────────────────────

test("autoshow: a dummy target opens the HUD, and leaving it closes it after the debounce", function()
    local f = fixture{ show = true }
    target(f, CLEAVE)
    assertTrue(f.Hud.IsShown(), "the dummy target opened it")
    assertTrue(f.Hud.ShownNearDummy())
    target(f, BOAR)
    assertTrue(f.Hud.IsShown(), "still open inside the debounce")
    assertTrue(f.AutoArm.Diagnose().hiding)
    f:advance(f.AutoArm.HIDE_DELAY)
    assertFalse(f.Hud.IsShown(), "closed once no dummy was seen for the debounce")
    assertFalse(f.AutoArm.Diagnose().session)
end)

test("autoshow: a dummy's nameplate opens the HUD, with no target at all", function()
    local f = fixture{ show = true }
    plateUp(f, "nameplate3", GOLEM)
    assertTrue(f.Hud.IsShown())
    assertEqual(f.AutoArm.Diagnose().plates, 1)
    plateUp(f, "nameplate4", BOAR)
    assertEqual(f.AutoArm.Diagnose().plates, 1, "a creature not in the catalog is no dummy")
end)

test("autoshow: nameplates churning inside the debounce never close the window", function()
    local f = fixture{ show = true }
    plateUp(f, "nameplate1", CLEAVE)
    assertTrue(f.Hud.IsShown())
    for _ = 1, 5 do
        plateDown(f, "nameplate1")
        f:advance(f.AutoArm.HIDE_DELAY - 1)
        assertTrue(f.Hud.IsShown(), "closed while the plate was only blinking")
        plateUp(f, "nameplate1", CLEAVE)
        assertFalse(f.AutoArm.Diagnose().hiding, "the plate's return cancels the hide")
    end
    plateDown(f, "nameplate1")
    f:advance(f.AutoArm.HIDE_DELAY)
    assertFalse(f.Hud.IsShown())
end)

test("autoshow: the hide's fire scans the nameplates again before it closes", function()
    -- A plate that came up in combat with a secret GUID was never counted, but is still there.
    local f = fixture{ show = true }
    plateUp(f, "nameplate1", CLEAVE)
    f.M.__setPlate("nameplate2", CLEAVE)        -- up without its event reaching the rule
    plateDown(f, "nameplate1")
    f:advance(f.AutoArm.HIDE_DELAY)
    assertTrue(f.Hud.IsShown(), "the rescan found the dummy still up")
    assertEqual(f.AutoArm.Diagnose().plates, 1)
end)

test("autoshow: a secret GUID is no dummy", function()
    local f = fixture{ show = true }
    plateUp(f, "nameplate1", { guid = T.secret(CLEAVE.guid), name = "Cleave Training Dummy" })
    assertFalse(f.Hud.IsShown())
    assertEqual(f.AutoArm.Diagnose().plates, 0)
end)

test("autoshow: the player's close keeps it closed for the rest of the dummy session", function()
    local f = fixture{ show = true }
    plateUp(f, "nameplate1", CLEAVE)
    assertTrue(f.Hud.IsShown())
    f.Hud.Act.close()
    assertFalse(f.Hud.IsShown())
    plateUp(f, "nameplate2", GOLEM)
    target(f, CLEAVE)
    assertFalse(f.Hud.IsShown(), "auto-show fought the player's close")
    -- Away from the dummies for the debounce: the session ends, and the next one opens it again.
    target(f, nil)
    plateDown(f, "nameplate1")
    plateDown(f, "nameplate2")
    f:advance(f.AutoArm.HIDE_DELAY)
    assertFalse(f.AutoArm.Diagnose().session)
    plateUp(f, "nameplate1", CLEAVE)
    assertTrue(f.Hud.IsShown(), "a new session opens it")
end)

test("autoshow: a window the player opened is theirs, and never closed by leaving", function()
    local f = fixture{ show = true }
    f.Hud.Show()
    plateUp(f, "nameplate1", CLEAVE)
    assertFalse(f.Hud.ShownNearDummy())
    plateDown(f, "nameplate1")
    f:advance(f.AutoArm.HIDE_DELAY)
    assertTrue(f.Hud.IsShown(), "the player's window closed by itself")
end)

test("autoshow: a race or its result holds the window; the idle edge lets it go", function()
    local f = fixture{ show = true }
    target(f, CLEAVE)
    assertTrue(f:arm(30))
    target(f, BOAR)
    f:advance(f.AutoArm.HIDE_DELAY)
    assertTrue(f.Hud.IsShown(), "closed over an armed race")
    assertTrue(f.Race.Cancel())
    assertTrue(f.Hud.IsShown(), "the idle edge starts the debounce, not a close")
    f:advance(f.AutoArm.HIDE_DELAY)
    assertFalse(f.Hud.IsShown())
end)

test("autoshow: a result card holds the window past the debounce", function()
    local f = fixture{ show = true }
    target(f, CLEAVE)
    assertTrue(f:arm(30))
    f:start(25)
    f:to(130)
    f:advance(1)
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
    target(f, BOAR)
    f:advance(f.AutoArm.HIDE_DELAY * 2)
    assertTrue(f.Hud.IsShown(), "the result card closed by itself")
end)

test("autoshow: a race going idle near the dummy keeps the window open", function()
    local f = fixture{ show = true }
    target(f, CLEAVE)
    assertTrue(f:arm(30))
    assertTrue(f.Race.Cancel())
    assertTrue(f.Hud.IsShown(), "the onArm close took the dummy's window")
    f:advance(f.AutoArm.HIDE_DELAY * 2)
    assertTrue(f.Hud.IsShown())
end)

test("autoshow: General visibility still decides whether it draws", function()
    local f = fixture{ show = true }
    assertTrue(f.NS.SetByPath("visibility", "never"))
    target(f, CLEAVE)
    assertTrue(f.Hud.wanted, "auto-show wants the window")
    assertFalse(f.Hud.IsShown(), "General visibility hides it")
end)

test("autoshow: turning the rule off closes the window it opened", function()
    local f = fixture{ show = true }
    target(f, CLEAVE)
    assertTrue(f.Hud.IsShown())
    assertTrue(f.NS.SetByPath("hud.autoShow", false))
    assertFalse(f.Hud.IsShown())
end)

-- ── auto-arm ────────────────────────────────────────────────────────────────────────────────────

test("autoarm: targeting a cataloged dummy out of combat arms at the HUD's length and opens it", function()
    local f = fixture{ arm = true }
    f.NS.db.profile.race.lastLength = 60
    target(f, CLEAVE)
    assertEqual(f.Race.State(), "armed")
    assertEqual(f.Race.Current().race.length, 60, "the length Arm Race would arm")
    assertEqual(f.Race.Current().target.category, "cleave")
    assertTrue(f.Hud.IsShown(), "the arm opens the HUD as a manual arm does")
    assertFalse(f.Hud.ShownNearDummy(), "standalone: auto-show is off")
    assertTrue(f.AutoArm.Diagnose().armed)
end)

test("autoarm: a target that is no cataloged dummy arms nothing", function()
    local f = fixture{ arm = true }
    target(f, BOAR)
    assertEqual(f.Race.State(), "idle")
    target(f, nil)
    assertEqual(f.Race.State(), "idle")
end)

test("autoarm: Race.Arm's refusals hold, silently: in combat, pending, meter unavailable", function()
    local f = fixture{ arm = true }
    f.M.__inCombat = true
    target(f, CLEAVE)
    assertEqual(f.Race.State(), "idle", "armed in combat")
    f.M.__inCombat = false

    local g = fixture{ arm = true }
    g.NS.Recorder.Save(RaceClock.storedRun({ id = "pending-1", status = "stopping" }))
    g.M.__resetPrinted()
    target(g, CLEAVE)
    assertEqual(g.Race.State(), "idle", "armed over a run waiting for its result")
    assertEqual(#g.M.__printed(), 0, "a refusal printed")

    local h = fixture{ arm = true }
    h.meter.SetAvailable(false, "Unavailable here")
    target(h, CLEAVE)
    assertEqual(h.Race.State(), "idle", "armed with the meter unavailable")
end)

test("autoarm: no arm over a result card, nor in test mode", function()
    local f = fixture{ arm = true }
    assertTrue(f:arm(30))
    f:start(25)
    f:to(130)
    f:advance(1)
    f:combatEnd()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
    local shown = f.Race.Current()
    target(f, CLEAVE)
    assertEqual(f.Race.State(), "result", "armed over the result card")
    assertTrue(f.Race.Current() == shown)

    local g = fixture{ arm = true }
    assertTrue(g.NS.Preview.Start())
    target(g, CLEAVE)
    assertEqual(g.Race.State(), "idle", "armed in test mode")
    assertTrue(g.NS.Preview.IsActive(), "the arm ended test mode")
end)

test("autoarm: targeting anything else before the pull disarms; another dummy keeps it", function()
    local f = fixture{ arm = true }
    target(f, CLEAVE)
    assertEqual(f.Race.State(), "armed")
    target(f, GOLEM)
    assertEqual(f.Race.State(), "armed", "a second dummy is still a dummy")
    target(f, BOAR)
    assertEqual(f.Race.State(), "idle", "a boar disarmed it")
    assertFalse(f.AutoArm.Diagnose().armed)

    local g = fixture{ arm = true }
    target(g, CLEAVE)
    target(g, nil)
    assertEqual(g.Race.State(), "idle", "clearing the target disarmed it")
end)

test("autoarm: a started race is never disarmed by a target change", function()
    local f = fixture{ arm = true }
    target(f, CLEAVE)
    f:start(25)
    assertEqual(f.Race.State(), "running")
    assertFalse(f.AutoArm.Diagnose().armed, "a started race is no longer the rule's")
    target(f, BOAR)
    assertEqual(f.Race.State(), "running")
    target(f, nil)
    assertEqual(f.Race.State(), "running")
end)

test("autoarm: a race the player armed is never the rule's to disarm", function()
    local f = fixture{ arm = true }
    assertTrue(f:arm(30))
    target(f, BOAR)
    assertEqual(f.Race.State(), "armed")
end)

test("autoarm: Cancel works as today, and the next target change to a dummy arms again", function()
    local f = fixture{ arm = true }
    target(f, CLEAVE)
    assertTrue(f.Race.Cancel())
    assertEqual(f.Race.State(), "idle")
    target(f, GOLEM)
    assertEqual(f.Race.State(), "armed")
end)

test("autoarm: works alongside auto-show; the disarm leaves the dummy's window open", function()
    local f = fixture{ arm = true, show = true }
    target(f, CLEAVE)
    assertEqual(f.Race.State(), "armed")
    assertTrue(f.Hud.ShownNearDummy(), "auto-show claimed the window before the arm")
    plateUp(f, "nameplate1", CLEAVE)
    target(f, BOAR)
    assertEqual(f.Race.State(), "idle")
    assertTrue(f.Hud.IsShown(), "the dummy's plate is still up")
end)

-- ── stand-down ──────────────────────────────────────────────────────────────────────────────────

test("autoarm: neither rule acts in an instance or a battleground", function()
    for _, kind in ipairs({ "party", "raid", "pvp", "arena", "scenario" }) do
        local f = fixture{ arm = true, show = true }
        f.M.__context.instanceType = kind
        target(f, CLEAVE)
        plateUp(f, "nameplate1", CLEAVE)
        assertEqual(f.Race.State(), "idle", kind .. ": armed")
        assertFalse(f.Hud.IsShown(), kind .. ": shown")
    end
    local g = fixture{ arm = true }
    g.M.__context.instanceType = "none"
    target(g, CLEAVE)
    assertEqual(g.Race.State(), "armed", "the open world says none")
end)

test("autoarm: entering an instance closes the dummy's window", function()
    local f = fixture{ show = true }
    target(f, CLEAVE)
    assertTrue(f.Hud.IsShown())
    f.M.__context.instanceType = "party"
    f.M.__fire("PLAYER_ENTERING_WORLD")
    assertFalse(f.Hud.IsShown())
end)

test("autoarm: stood down, nothing is registered and nothing acts; the stand-up rebuilds", function()
    local f = fixture{ arm = true, show = true }
    target(f, CLEAVE)
    assertTrue(f.NS.SetByPath("enabled", false))
    assertEqual(f.AutoArm.Diagnose().events, "none")
    assertFalse(f.AutoArm.Diagnose().session)
    assertFalse(eventsHeld(f).PLAYER_TARGET_CHANGED == true)
    assertTrue(f.NS.SetByPath("enabled", true))
    assertEqual(f.AutoArm.Diagnose().events, "plates")
    target(f, nil)
    target(f, GOLEM)
    assertEqual(f.Race.State(), "armed")
end)
