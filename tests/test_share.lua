-- tests/test_share.lua — modules/Share.lua: the one-line share (mockup screen 12), the channel menu
-- that refuses in combat, the whisper prompt, and the status lines the race prints to the player's
-- own chat (armed, result).

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)

--- The mockup's run: a 3:00 race on the cleave dummy, five targets, a Destruction warlock at 313.
local function sampleRun(fields)
    local run = {
        id = "1792758447-4429", status = "complete",
        race = { length = 180, grace = 1.0 },
        char = { name = "Lanfear", spec = "Destruction", ilvl = 313.2, class = "WARLOCK" },
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave", count = 5 },
        result = { damage = 26560000, dps = 147600, tail = 3.1 },
        flags = { lateCasts = { { t = 1.4, spellID = 29722 } }, reloaded = false, died = false },
        spells = {}, note = "",
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    return run
end

local function bare(M)
    local out = {}
    for i, l in ipairs(M.__printed()) do out[i] = (l:gsub("^|cff00ffff%[DR%]|r ", "")) end
    return out
end

--- An instance whose chat sends are recorded.
local function chatSpy()
    local inst = T.load()
    local sent = {}
    local function send(text, channel, _, target)
        sent[#sent + 1] = { text = text, channel = channel, target = target }
    end
    inst.mocks.SendChatMessage = send
    inst.mocks._G.SendChatMessage = send
    return inst, sent
end

test("share: Share.Line matches the mockup format", function()
    local NS = T.NS
    assertEqual(NS.Share.Line(sampleRun()),
        "DPS Race 3:00 \194\183 Cleave \195\1515 \194\183 Destruction 313 \194\183 26.56M \194\183 147.6K DPS (Ka0s DPS Race)")
end)

test("share: one target drops the count; an uncataloged target is named; incomplete is said", function()
    local NS = T.NS
    local single = sampleRun({ target = { category = "single", count = 1 } })
    assertTrue(NS.Share.Line(single):find("\194\183 Single target \194\183", 1, true) ~= nil)
    local other = sampleRun({ target = { category = "other", count = 1, name = "Angry Boar" } })
    assertTrue(NS.Share.Line(other):find("\194\183 Angry Boar \194\183", 1, true) ~= nil)
    local incomplete = sampleRun({ status = "incomplete" })
    incomplete.result.endedAt = 120
    assertTrue(NS.Share.Line(incomplete):find("DPS \194\183 incomplete (Ka0s DPS Race)", 1, true) ~= nil)
end)

test("share: a lost run has no line, and the prompt says so", function()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    local lost = sampleRun({ status = "lost", result = nil })
    assertEqual(NS.Share.Line(lost), nil)
    M.__resetPrinted()
    M.__menus = {}
    assertFalse(NS.Share.Prompt(lost))
    assertEqual(#M.__menus, 0)
    assertEqual(#bare(M), 1)
end)

test("share: no chat escape survives into the line", function()
    local NS = T.NS
    local run = sampleRun({ target = { category = "other", count = 1, name = "Evil |cffff0000Dummy|r" } })
    assertEqual(NS.Share.Line(run):find("|", 1, true), nil)
end)

test("share: Share refuses in combat", function()
    local inst = chatSpy()
    local NS, M = inst.NS, inst.mocks
    M.__inCombat = true
    M.__menus = {}
    M.__resetPrinted()
    assertFalse(NS.Share.Prompt(sampleRun()))
    assertEqual(#M.__menus, 0, "a channel menu opened in combat")
    assertEqual(bare(M)[1], "You can share a run once you are out of combat.")
end)

test("share: the prompt offers say, party, raid, guild and whisper; a channel you are not in is grayed", function()
    local inst, sent = chatSpy()
    local NS, M = inst.NS, inst.mocks
    M.__context.inGroup = false
    M.IsInGuild = function() return true end
    M.IsInRaid = function() return false end
    assertTrue(NS.Share.Prompt(sampleRun()))
    local menu = assert(M.__lastMenu)
    local texts = {}
    for _, e in ipairs(menu.entries) do texts[#texts + 1] = e.text end
    assertEqual(table.concat(texts, ","), "Say,Party,Raid,Guild,Whisper\226\128\166")
    assertFalse(menu:Find("Party").enabled)
    assertFalse(menu:Find("Raid").enabled)
    assertTrue(menu:Find("Guild").enabled)
    menu:Click("Guild")
    assertEqual(#sent, 1)
    assertEqual(sent[1].channel, "GUILD")
    assertEqual(sent[1].text, NS.Share.Line(sampleRun()))
end)

test("share: a send that finds the player in combat since the menu opened is refused", function()
    local inst, sent = chatSpy()
    local NS, M = inst.NS, inst.mocks
    assertTrue(NS.Share.Prompt(sampleRun()))
    M.__inCombat = true
    M.__lastMenu:Click("Say")
    assertEqual(#sent, 0)
end)

test("share: whisper asks for a name, then sends to it", function()
    local inst, sent = chatSpy()
    local NS, M = inst.NS, inst.mocks
    local shown = {}
    M.StaticPopup_Show = function(name, _, _, data) shown[#shown + 1] = { name = name, data = data } end
    assertTrue(NS.Share.Prompt(sampleRun()))
    M.__lastMenu:Click("Whisper")
    assertEqual(shown[1].name, "DPSRACE_SHARE_WHISPER")
    local dialog = M.StaticPopupDialogs.DPSRACE_SHARE_WHISPER
    local box = { GetText = function() return "  Thrall-Area52 " end }
    dialog.OnAccept({ editBox = box }, shown[1].data)
    assertEqual(#sent, 1)
    assertEqual(sent[1].channel, "WHISPER")
    assertEqual(sent[1].target, "Thrall-Area52")
    box.GetText = function() return "   " end
    dialog.OnAccept({ editBox = box }, shown[1].data)
    assertEqual(#sent, 1, "an empty name sends nothing")
end)

test("share: the HUD's and the Results window's Share are live now Share exists", function()
    local NS = T.NS
    assertEqual(type(NS.Share.Prompt), "function")
end)

-- ── the status lines (mockup screen 12) ──────────────────────────────────────────────────────────

test("share: arming prints the armed line with the length and the target", function()
    local f = RaceClock.new()
    f.M.__setTarget({ guid = "Creature-0-1-2-3-243208-0000000000", name = "Cleave Training Dummy" })
    f.M.__resetPrinted()
    assertTrue(f.Race.Arm(180, 5))
    assertEqual(bare(f.M)[1],
        "Armed: 3:00 on Cleave Training Dummy \195\1515. First hit starts the clock.")
end)

test("share: a result prints the score line with the delta, the flags and the tail", function()
    local NS = T.NS
    local run = sampleRun()
    local line = NS.Share.ResultLine(run, 2.4, true)
    assertEqual(line, "26.56M damage \194\183 147.6K DPS in 3:00 on Cleave Training Dummy \195\1515"
        .. " \226\128\148 new best (+2.4%) \194\183 1 late cast \194\183 tail +3.1s")
    local slower = NS.Share.ResultLine(sampleRun({ flags = { lateCasts = {} } }), -3.2, false)
    assertTrue(slower:find("\226\128\148 -3.2% vs best \194\183 tail +3.1s", 1, true) ~= nil, slower)
end)

test("share: the race's own result is printed once, when it resolves", function()
    local f = RaceClock.new()
    assertTrue(f:arm(30))
    f:start(25)
    f:to(130)
    f:advance(1)
    f:combatEnd()
    f.M.__resetPrinted()
    f:advance(3)
    assertEqual(f.Race.State(), "result")
    local out = bare(f.M)
    assertEqual(#out, 1)
    assertTrue(out[1]:find(" damage \194\183 ", 1, true) ~= nil, out[1])
end)
