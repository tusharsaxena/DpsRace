-- tests/test_loadout.lua — the loadout (#6): the capture (modules/Recorder.lua SnapshotLoadout: the
-- gear links without the shirt and tabard, the talent loadout, every API absent or raising), its
-- deduped store (modules/Loadouts.lua: the hash, a collision, the orphan sweep on every removal), the
-- race taking it at arm and again at its combat end, the run format 2 migration, the detail's gear
-- grid and talents line (modules/Results_Loadout.lua) with the compare's highlights (View posting the
-- talents link to chat, never opening a Blizzard frame itself), the Spec cell's tooltip and the share
-- line's optional talents link.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local F = dofile(T.root .. "/tests/race_clock.lua")(T)

local function fresh(mutate)
    local inst = T.load{ mutate = mutate }
    -- Stored fixtures carry 1970-era dates; never prune by age here (the prune cases set it).
    inst.NS.db.global.history.keepDays = 0
    return inst.NS, inst.mocks, inst
end

-- ── the capture ─────────────────────────────────────────────────────────────────────────────────

test("loadout: SnapshotLoadout reads every equipped link but the shirt and the tabard", function()
    local NS, M = fresh()
    local lo = NS.Recorder.SnapshotLoadout()
    assertTrue(type(lo) == "table" and type(lo.gear) == "table")
    assertEqual(lo.gear[1], M.__gear[1])
    assertEqual(lo.gear[5], M.__gear[5])
    assertEqual(lo.gear[16], M.__gear[16])
    assertNil(lo.gear[4], "the shirt was recorded")
    assertNil(lo.gear[19], "the tabard was recorded")
    assertNil(lo.gear[2], "an empty slot is absent")
    for _, slot in ipairs(NS.Recorder.GEAR_SLOTS) do
        assertTrue(slot ~= 4 and slot ~= 19 and slot >= 1 and slot <= 18, "slot " .. slot)
    end
end)

test("loadout: SnapshotLoadout reads the talents: the saved loadout's name, the hero tree, the string", function()
    local NS = fresh()
    local t = NS.Recorder.SnapshotLoadout().talents
    assertEqual(t.specID, 267)
    assertEqual(t.configID, 7001)
    assertEqual(t.name, "Raid ST", "the player's saved loadout names it")
    assertEqual(t.heroSpecID, 58)
    assertEqual(t.heroName, "Diabolist")
    assertEqual(t.importString, "C0PAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    assertEqual(t.serialVersion, 2)
end)

test("loadout: with no saved loadout the active config's name is used", function()
    local NS, M = fresh()
    M.__talents.savedConfigID = nil
    assertEqual(NS.Recorder.SnapshotLoadout().talents.name, "Active")
end)

test("loadout: a client without the APIs, or one that raises, yields absent fields, never an error", function()
    local NS, M = fresh()
    M.GetInventoryItemLink = nil
    local lo = NS.Recorder.SnapshotLoadout()
    assertNil(lo.gear, "no inventory API, yet gear")
    assertEqual(lo.talents.name, "Raid ST")
    M.C_Traits.GenerateImportString = function() error("boom") end
    M.C_Traits.GetSubTreeInfo = nil
    lo = NS.Recorder.SnapshotLoadout()
    assertNil(lo.talents.importString)
    assertNil(lo.talents.heroName)
    assertEqual(lo.talents.heroSpecID, 58)
    M.C_ClassTalents = nil
    assertNil(NS.Recorder.SnapshotLoadout(), "nothing readable, yet a loadout")
    local NS2, M2 = fresh()
    M2.__talents = nil
    lo = NS2.Recorder.SnapshotLoadout()
    assertNil(lo.talents, "no active config, yet talents")
    assertTrue(lo.gear ~= nil)
end)

test("loadout: a secret value never reaches the snapshot", function()
    local NS, M = fresh(function(m) m.issecretvalue = function(v) return T.isSecret(v) end end)
    M.__gear[5] = T.secret(M.__gear[5])
    M.__talents.importString = T.secret("SECRET")
    local lo = NS.Recorder.SnapshotLoadout()
    assertNil(lo.gear[5], "a sealed link was stored")
    assertNil(lo.talents.importString, "a sealed import string was stored")
    assertEqual(lo.gear[1], M.__gear[1])
end)

-- ── the store ───────────────────────────────────────────────────────────────────────────────────

local function stored(NS) return NS.db.global.loadouts end

local function storedRun(NS, id, loadout, fields)
    local run = { id = id, schema = 2, status = "complete", date = 1000, race = { length = 30 },
                  result = { damage = 10, dps = 1 }, loadout = loadout }
    for k, v in pairs(fields or {}) do run[k] = v end
    NS.db.global.runs[id] = run
    return run
end

test("loadout: the hash is djb2 as eight hex digits, and pure", function()
    local NS = fresh()
    local H = NS.Loadouts.Hash
    assertEqual(H(""), "00001505", "djb2's seed, 5381")
    assertEqual(H("a"), "0002b606", "5381 * 33 + 97")
    assertEqual(H("abcdef"), "f148cb7a", "a hash of 2^31 or more formats as itself")
    assertEqual(H("abc"), H("abc"))
    assertTrue(H("abc") ~= H("acb"))
    assertEqual(#H(("x"):rep(5000)), 8, "a long string stays inside 32 bits")
end)

test("loadout: Store keeps each distinct set once; the run holds only the keys", function()
    local NS = fresh()
    local snap = NS.Recorder.SnapshotLoadout()
    local a = NS.Loadouts.Store(snap)
    local b = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    assertEqual(a.gear, b.gear, "the same gear stored twice")
    assertEqual(a.talents, b.talents, "the same talents stored twice")
    assertEqual(NS.Loadouts.Counts(), 1)
    assertEqual(stored(NS).gear[a.gear][16], snap.gear[16])
    snap.gear[16] = nil
    local c = NS.Loadouts.Store(snap)
    assertTrue(c.gear ~= a.gear, "different gear, one key")
    assertEqual(c.talents, a.talents)
    local g, t = NS.Loadouts.Counts()
    assertEqual(g, 2)
    assertEqual(t, 1)
    assertNil(NS.Loadouts.Store(nil))
    assertNil(NS.Loadouts.Store({}), "an empty snapshot stores nothing")
    local gearOnly = NS.Loadouts.Store({ gear = { [1] = "x" } })
    assertNil(gearOnly.talents)
end)

test("loadout: two different sets with one hash are told apart; the same set finds its own key", function()
    local NS = fresh()
    NS.Loadouts.Hash = function() return "deadbeef" end
    local a = NS.Loadouts.Store({ gear = { [1] = "one" } })
    local b = NS.Loadouts.Store({ gear = { [1] = "two" } })
    local c = NS.Loadouts.Store({ gear = { [1] = "three" } })
    assertEqual(a.gear, "deadbeef")
    assertEqual(b.gear, "deadbeef-2")
    assertEqual(c.gear, "deadbeef-3")
    assertEqual(NS.Loadouts.Store({ gear = { [1] = "two" } }).gear, "deadbeef-2", "a collided set stored again")
    assertEqual(stored(NS).gear["deadbeef-2"][1], "two")
end)

test("loadout: Of resolves a run's keys; a run without one has neither", function()
    local NS = fresh()
    local ref = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    local run = storedRun(NS, "r1", ref)
    local gear, talents = NS.Loadouts.Of(run)
    assertEqual(gear[1], stored(NS).gear[ref.gear][1])
    assertEqual(talents.name, "Raid ST")
    gear, talents = NS.Loadouts.Of(storedRun(NS, "old", nil, { schema = 1 }))
    assertNil(gear)
    assertNil(talents)
    gear = NS.Loadouts.Of({ loadout = { gear = "missing" } })
    assertNil(gear, "a key with no stored set")
end)

test("loadout: Delete, DeleteAll and Prune drop the loadouts no run refers to", function()
    local NS, M = fresh()
    local shared = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    M.__gear[1] = nil
    local own = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    local now, DAY = 100 * 86400, 86400
    storedRun(NS, "a", shared, { date = now - 10 * DAY })
    storedRun(NS, "b", shared, { date = now - 2 * DAY })
    storedRun(NS, "c", own, { date = now - DAY })
    assertEqual(NS.Loadouts.Counts(), 2)
    assertTrue(NS.Recorder.Delete("c"))
    assertEqual(NS.Loadouts.Counts(), 1, "the deleted run's own gear was kept")
    assertTrue(stored(NS).gear[shared.gear] ~= nil, "a set another run uses was dropped")
    -- Prune: the run older than the days goes, the set the newer run shares stays.
    NS.Bests.HoldingIDs = function() return {} end
    assertEqual(NS.Recorder.Prune(5, nil, now), 1)
    assertEqual(NS.Loadouts.Counts(), 1)
    storedRun(NS, "d", NS.Loadouts.Store({ gear = { [2] = "d" } }), { date = now })
    assertEqual(NS.Recorder.Prune(1, nil, now), 1)
    assertNil(stored(NS).gear[shared.gear], "the pruned run's set outlived it")
    assertEqual(NS.Loadouts.Counts(), 1)
    NS.Recorder.DeleteAll()
    local g, t = NS.Loadouts.Counts()
    assertEqual(g + t, 0, "a set outlived every run")
end)

test("loadout: a run of a later format keeps the sets it refers to", function()
    local NS = fresh()
    local ref = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    storedRun(NS, "future", ref, { schema = NS.Recorder.RUN_SCHEMA + 1 })
    assertEqual(NS.Loadouts.Sweep(), 0)
    assertEqual(NS.Loadouts.Counts(), 1)
end)

-- ── the migration ───────────────────────────────────────────────────────────────────────────────

test("loadout: the format 2 migration leaves old runs as they were, without a loadout", function()
    local inst = T.load({ init = false })
    local NS = inst.NS
    local old = { id = "old", schema = 1, status = "complete", date = 5, race = { length = 30 },
                  result = { damage = 9, dps = 0.3 }, spells = {}, note = "kept" }
    _G.DpsRaceDB = { global = { schemaVersion = 1, schema = 1, runs = { old = old } } }
    inst.mocks._G.DpsRaceDB = _G.DpsRaceDB
    NS:InitDB()
    NS:RunMigrations()
    local g = NS.db.global
    assertEqual(g.schemaVersion, 2)
    assertEqual(g.schema, 2, "the format stamp answers 2")
    local run = g.runs.old
    assertEqual(run.schema, 1, "an old run was rewritten")
    assertNil(run.loadout)
    assertEqual(run.note, "kept")
    assertNil(NS.Loadouts.Of(run))
    assertEqual(NS.Recorder.All()[1].id, "old", "a format-1 run is still listed")
    NS:RunMigrations()
    assertEqual(g.schemaVersion, 2, "the step ran twice")
end)

-- ── the race ────────────────────────────────────────────────────────────────────────────────────

test("loadout: a race keeps the combat-end loadout, not the arm-time one", function()
    local f = F.new()
    assertTrue(f:arm(30))
    local run = f.Race.Current()
    assertNil(run.loadout, "stored before the race was")
    f:start(25)
    f.M.__gear[16] = "|cnIQ4:|Hitem:999::::::::80:267::::::::|h[New Staff]|h|r"   -- swapped in combat
    f:to(130)
    f:combatEnd()
    local gear = f.NS.Loadouts.Of(run)
    assertEqual(gear[16], f.M.__gear[16], "the combat-end snapshot")
    f:advance(3)
    assertEqual(run.status, "complete")
    gear = f.NS.Loadouts.Of(f:stored(run.id))
    assertEqual(gear[16], f.M.__gear[16], "the arm-time snapshot replaced it at the read")
    assertEqual(f.NS.Loadouts.Counts(), 1, "only the kept set is stored")
end)

test("loadout: a run with no combat-end snapshot falls back to the arm-time one", function()
    local f = F.new()
    assertTrue(f:arm(30))
    local run = f.Race.Current()
    local armLink = f.M.__gear[1]
    f:start(25)
    f.M.__gear[1] = "changed"
    f.Race.OnMeterReset()
    assertEqual(run.status, "lost")
    assertEqual(f.NS.Loadouts.Of(f:stored(run.id))[1], armLink, "the lost run took no arm-time loadout")
end)

test("loadout: a second combat end in the read's wait replaces the loadout and drops the first", function()
    local f = F.new()
    assertTrue(f:arm(30))
    local run = f.Race.Current()
    f:start(25)
    f:to(130)
    f:combatEnd()
    local first = run.loadout.gear
    f.M.__inCombat = true
    f.Race.OnCombatStart(f:now())
    f.M.__gear[2] = "|cnIQ4:|Hitem:5::::::::80:267::::::::|h[Neck]|h|r"
    f:combatEnd()
    assertTrue(run.loadout.gear ~= first)
    assertNil(f.NS.db.global.loadouts.gear[first], "the replaced set outlived the replacement")
end)

test("loadout: a run resumed after a /reload whose combat ended unheard still takes a loadout", function()
    local f = F.new()
    assertTrue(f:arm(30))
    local run = f.Race.Current()
    f:start(25)
    f:to(110)
    f.M.__inCombat = false                 -- combat drops during the reload
    local g = F.new{ enable = false }
    g.M.__now = 110
    g.M.__inCombat = false
    g.meter.SetSession(25, F.SESSION)
    g.NS.db.global.runs[run.id] = run
    g:enable()
    assertEqual(g.Race.State(), "result", "read at once, no regen edge heard")
    assertEqual(run.status, "incomplete")
    assertTrue(run.loadout ~= nil, "the run was saved without a loadout")
    assertEqual(g.NS.Loadouts.Of(run)[1], g.M.__gear[1])
end)

-- ── the detail ──────────────────────────────────────────────────────────────────────────────────

local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)
local NOW = os.time()
local STAFF = "|cnIQ4:|Hitem:777::::::::80:267::::::::|h[Better Staff]|h|r"

local function ui()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
        m.__dressed, m.__itemRefs, m.__modClicks = {}, {}, {}
        m.DressUpItemLink = function(link) m.__dressed[#m.__dressed + 1] = link end
        m.SetItemRef = function(data, text, button) m.__itemRefs[#m.__itemRefs + 1] = { data, text, button } end
        m.HandleModifiedItemClick = function(link) m.__modClicks[#m.__modClicks + 1] = link end
    end }
    return i, i.NS, i.mocks
end

local function uiRun(NS, id, dps, loadout, fields)
    local run = {
        id = id, schema = 2, status = "complete", addon = "0.1.0", date = NOW - 3600,
        race = { length = 180, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction",
                 level = 80 },
        target = { npcID = 225983, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 180, dps = dps, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = 29722, dmg = dps * 100 } }, note = "", loadout = loadout,
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    NS.db.global.runs[id] = run
    NS.Bests.Invalidate()
    return run
end

local function pane(i) return assert(i.NS.Results.__ui(), "the window was never built").detail end

local function cellOf(lo, slot)
    for _, cell in ipairs(lo.cells) do
        if cell:IsShown() and cell.slot == slot then return cell end
    end
end

test("loadout: the detail draws the gear grid in the character frame's order, and the talents line", function()
    local i, NS, M = ui()
    uiRun(NS, "r", 100, NS.Loadouts.Store(NS.Recorder.SnapshotLoadout()))
    NS.Results.ShowRun("r")
    local lo = pane(i).lo
    local cells, rows = NS.ResultsLoadout.Grid(NS.Loadouts.Of(NS.Recorder.Get("r")))
    assertEqual(#cells, 16, "eight a column; the ranged slot only when filled")
    assertEqual(rows, 8)
    assertEqual(cells[1].slot, 1)
    assertEqual(cells[9].slot, 10, "the right column starts at the hands")
    assertTrue(lo.grid:IsShown())
    assertFalse(lo.none:IsShown())
    local hood = cellOf(lo, 1)
    assertEqual(hood.name.__text, "Hood of the Test")
    assertEqual(hood.ilvl.__text, "639")
    assertEqual(hood.name.__color[1], 0.4, "the quality's color (epic, 4)")
    assertEqual(cellOf(lo, 2).name.__text, "Empty")
    assertFalse(cellOf(lo, 1).mark:IsShown(), "a highlight with no compare")
    assertEqual(lo.talents.__text, "Raid ST \194\183 Diabolist")
    assertTrue(lo.view:IsEnabled())
    assertTrue(lo.copy:IsEnabled())
    assertTrue(lo.dress:IsShown())
    lo.dress:__fire("OnClick")
    assertEqual(#M.__dressed, 3, "every equipped item tried on")
    -- View opens the tree through SetItemRef with the talentbuild link (the owner's call: the taint
    -- risk is accepted) and also posts the same link to the player's own chat window.
    local printed = {}
    local realPrint = NS.Print
    NS.Print = function(msg, ...) printed[#printed + 1] = msg; return realPrint(msg, ...) end
    lo.view:__fire("OnClick")
    NS.Print = realPrint
    assertEqual(#M.__itemRefs, 1, "View opens the tree through SetItemRef")
    assertEqual(M.__itemRefs[1][1], "talentbuild:267:80:" .. M.__talents.importString)
    assertEqual(M.__itemRefs[1][3], "LeftButton")
    assertEqual(#printed, 1, "View posts one chat line")
    assertTrue(printed[1]:find("|Htalentbuild:267:80:" .. M.__talents.importString .. "|h", 1, true) ~= nil,
        "the line carries the clickable talentbuild link")
    assertTrue(printed[1]:find("^Talents for Lanfear, ") ~= nil, "the line names the run: " .. printed[1])
    assertTrue(printed[1]:find("click the link to view the tree", 1, true) ~= nil)
    assertTrue(NS.ResultsTips.Loadout("view", NS.Recorder.Get("r"))[2]:find("chat", 1, true) ~= nil,
        "the tooltip says it posts to chat")
    local copied
    NS.ShowCopy = function(text) copied = text return true end
    lo.copy:__fire("OnClick")
    assertEqual(copied, M.__talents.importString)
    assertTrue(pane(i).contentH > 8 * NS.ResultsLoadout.PITCH, "the grid took no room")
end)

test("loadout: an item's hover is the client's own tooltip; a modified click goes to the client", function()
    local i, NS, M = ui()
    uiRun(NS, "r", 100, NS.Loadouts.Store(NS.Recorder.SnapshotLoadout()))
    local shown = {}
    M.GameTooltip = setmetatable({}, { __index = function(_, k)
        return function(_, a, b)
            if k == "SetOwner" then shown = { owner = a, anchor = b } end
            if k == "SetHyperlink" then shown.link = a end
        end
    end })
    NS.Results.ShowRun("r")
    local hood = cellOf(pane(i).lo, 1)
    hood:__fire("OnEnter")
    assertEqual(shown.owner, hood)
    assertEqual(shown.link, M.__gear[1])
    hood:__fire("OnClick")
    assertEqual(M.__modClicks[1], M.__gear[1], "Shift-click never reached the client's handler")
end)

test("loadout: a run stored before #6 says Not recorded, with nothing to view or copy", function()
    local i, NS = ui()
    uiRun(NS, "old", 100, nil, { schema = 1 })
    NS.Results.ShowRun("old")
    local lo = pane(i).lo
    assertTrue(lo.none:IsShown())
    assertEqual(lo.none.__text, "Not recorded")
    assertFalse(lo.grid:IsShown())
    assertFalse(lo.dress:IsShown())
    assertEqual(lo.talents.__text, "Not recorded")
    assertFalse(lo.view:IsEnabled())
    assertFalse(lo.copy:IsEnabled())
    assertEqual(NS.ResultsTips.Loadout("none", NS.Recorder.Get("old"))[1], "Not recorded")
end)

test("loadout: View is grayed with a reason once the client's serialization version moved; Copy still works", function()
    local i, NS, M = ui()
    uiRun(NS, "r", 100, NS.Loadouts.Store(NS.Recorder.SnapshotLoadout()))
    M.__talents.serialVersion = 3
    NS.Results.ShowRun("r")
    local lo = pane(i).lo
    assertFalse(lo.view:IsEnabled())
    assertTrue(lo.copy:IsEnabled())
    local ok, why = NS.ResultsLoadout.CanView(lo.talentsData)
    assertFalse(ok)
    assertEqual(why, "version")
    local lines = NS.ResultsTips.Loadout("viewOff", NS.Recorder.Get("r"))
    assertTrue(lines[2]:find("no longer opens", 1, true) ~= nil)
    assertFalse(NS.ResultsLoadout.View(lo.talentsData, 80), "a stale string was posted")
    assertEqual(#M.__itemRefs, 0)
end)

test("loadout: under the compare the changed slots are highlighted and a different loadout is marked", function()
    local i, NS, M = ui()
    local mine = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    M.__gear[16] = STAFF
    M.__gear[2] = "|cnIQ4:|Hitem:5::::::::80:267::::::::|h[Neck]|h|r"
    M.__talents.importString = "C0PBBBB"
    local theirs = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    uiRun(NS, "best", 300, theirs)
    uiRun(NS, "low", 100, mine)
    NS.Results.ShowRun("low")
    local p = pane(i)
    local lo = p.lo
    assertFalse(lo.differs:IsShown(), "marked before the compare")
    p:SetComparing(true)
    assertTrue(cellOf(lo, 16).mark:IsShown(), "the swapped weapon")
    assertTrue(cellOf(lo, 2).mark:IsShown(), "a slot only the other run filled")
    assertFalse(cellOf(lo, 1).mark:IsShown(), "an unchanged slot")
    assertEqual(lo.changedCount, 2)
    assertTrue(lo.differs:IsShown())
    assertEqual(NS.ResultsTips.Loadout("changed", NS.Recorder.Get("low"), NS.Recorder.Get("best"), 16)[1],
        "Changed: the other run wore Better Staff.")
    p:SetComparing(false)
    assertFalse(cellOf(lo, 16).mark:IsShown())
    assertFalse(lo.differs:IsShown())
end)

test("loadout: the pure parts: changed slots, the link data, the talents text", function()
    local NS = fresh()
    local LO = NS.ResultsLoadout
    assertNil(LO.ChangedSlots({ [1] = "a" }, nil), "a diff without the other set")
    local ch = LO.ChangedSlots({ [1] = "a", [2] = "b" }, { [1] = "a", [3] = "c" })
    assertNil(ch[1])
    assertTrue(ch[2] and ch[3])
    assertTrue(LO.TalentsDiffer({ importString = "A" }, { importString = "B" }))
    assertFalse(LO.TalentsDiffer({ importString = "A" }, { importString = "A" }))
    assertFalse(LO.TalentsDiffer({ importString = "A" }, {}), "a side with no string differs")
    assertEqual(LO.LinkData({ specID = 62, importString = "XYZ" }, 90), "talentbuild:62:90:XYZ")
    assertNil(LO.LinkData({ specID = 62 }, 90))
    assertEqual(LO.Hyperlink({ specID = 62, importString = "XYZ", name = "A|B[c]" }, 90),
        "|cffffd100|Htalentbuild:62:90:XYZ|h[ABc]|h|r", "a name's escapes reached the link")
    assertEqual(LO.TalentsText({ name = "Raid" }), "Raid")
    assertEqual(LO.TalentsText({ heroName = "Hero" }), "Unnamed loadout \194\183 Hero")
    assertEqual(LO.ItemName("|cnIQ4:|Hitem:1::|h[Thing]|h|r"), "Thing")
end)

test("loadout: the copy window opens on the import string", function()
    local NS = fresh()
    assertTrue(NS.ShowCopy("ABC", "Talent loadout"), "no copy window on a full install")
end)

-- ── the Spec cell and the share ─────────────────────────────────────────────────────────────────

local function texts(lines)
    local out = {}
    for n, l in ipairs(lines) do out[n] = type(l) == "table" and l[1] or l end
    return out
end

local function has(lines, want)
    for _, l in ipairs(texts(lines)) do if l == want then return true end end
    return false
end

test("loadout: the Spec cell's tooltip names the loadout and notes gear changed since the previous run", function()
    local _, NS, M = ui()
    local first = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    M.__gear[16] = STAFF
    local second = NS.Loadouts.Store(NS.Recorder.SnapshotLoadout())
    uiRun(NS, "a", 100, first, { date = NOW - 300 })
    uiRun(NS, "b", 100, first, { date = NOW - 200 })
    uiRun(NS, "c", 100, second, { date = NOW - 100 })
    uiRun(NS, "alt", 100, first, { date = NOW - 150, char = { name = "Other", realm = "Frostmourne", specID = 267 } })
    local col = { key = "icons" }
    local tipC = NS.ResultsTips.Cell(col, NS.Recorder.Get("c"))
    assertTrue(has(tipC, "Talents: Raid ST \194\183 Diabolist"), "the loadout is not named")
    assertTrue(has(tipC, "Gear changed since the previous run"), "a weapon swap went unnoticed")
    assertEqual(NS.Loadouts.Previous(NS.Recorder.Get("c")).id, "b", "another character's run counted")
    local tipB = NS.ResultsTips.Cell(col, NS.Recorder.Get("b"))
    assertFalse(has(tipB, "Gear changed since the previous run"), "the same set is a change")
    local tipA = NS.ResultsTips.Cell(col, NS.Recorder.Get("a"))
    assertFalse(has(tipA, "Gear changed since the previous run"), "a first run has nothing to change from")
    uiRun(NS, "old", 100, nil, { schema = 1, date = NOW - 400 })
    assertTrue(has(NS.ResultsTips.Cell(col, NS.Recorder.Get("old")), "Gear and talents: not recorded"))
end)

test("loadout: the share line takes the talents link only with Include talents link on", function()
    local _, NS, M = ui()
    local run = uiRun(NS, "r", 147600, NS.Loadouts.Store(NS.Recorder.SnapshotLoadout()))
    local line = NS.Share.Line(run)
    assertEqual(NS.db.profile.share.talentsLink, false, "on by default")
    local msgs = NS.Share.Messages(run)
    assertEqual(#msgs, 1)
    assertEqual(msgs[1], line, "the line changed with the setting off")
    assertTrue(NS.SetByPath("share.talentsLink", true))
    msgs = NS.Share.Messages(run)
    assertEqual(#msgs, 1)
    assertEqual(msgs[1], line .. " " .. NS.Share.TalentsLink(run))
    assertTrue(msgs[1]:find("|Htalentbuild:267:80:" .. M.__talents.importString .. "|h[Destruction: Raid ST]|h", 1, true) ~= nil)
    -- Too long for one message: the link follows as a second.
    M.__talents.importString = ("A"):rep(180)
    local long = uiRun(NS, "long", 147600, NS.Loadouts.Store(NS.Recorder.SnapshotLoadout()))
    assertTrue(#NS.Share.TalentsLink(long) <= NS.Share.MAX_CHAT, "the link alone must fit a message")
    msgs = NS.Share.Messages(long)
    assertEqual(#msgs, 2)
    assertEqual(msgs[1], NS.Share.Line(long))
    assertTrue(msgs[2]:find("|Htalentbuild:", 1, true) == 11, "the second message is not the link")
    -- A link too long for a message of its own is dropped, never sent cut.
    M.__talents.importString = ("A"):rep(260)
    local huge = uiRun(NS, "huge", 147600, NS.Loadouts.Store(NS.Recorder.SnapshotLoadout()))
    assertTrue(#NS.Share.TalentsLink(huge) > NS.Share.MAX_CHAT)
    msgs = NS.Share.Messages(huge)
    assertEqual(#msgs, 1)
    assertEqual(msgs[1], NS.Share.Line(huge))
    msgs = NS.Share.Messages(long)
    -- A run with no loadout shares the line alone.
    local old = uiRun(NS, "old", 100, nil, { schema = 1 })
    assertEqual(#NS.Share.Messages(old), 1)
    -- Sent: each message to the channel, in order.
    local sent = {}
    NS.Compat.ChatSender = function() return function(text, channel) sent[#sent + 1] = { text, channel } end end
    assertTrue(NS.Share.Send(long, "SAY"))
    assertEqual(#sent, 2)
    assertEqual(sent[2][1], msgs[2])
    assertEqual(sent[2][2], "SAY")
end)

test("loadout: Include talents link sits under Sharing on the History tab, before Storage", function()
    local NS = T.NS
    local order = {}
    for _, r in ipairs(NS.SchemaForPage("history")) do
        if r.group == "History" then order[#order + 1] = r.path end
    end
    assertEqual(table.concat(order, ","), "share.talentsLink,global.history.keepDays")
end)
