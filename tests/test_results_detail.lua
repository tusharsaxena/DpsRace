-- tests/test_results_detail.lua — the Results window's run detail (modules/Results_Detail.lua, spec §6.2):
-- the breakdown, the timing strip, the flags, the note, delete, Share and the row's menu. Peeled out of
-- tests/test_results.lua (layout-§1); the helpers are that suite's.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR, DAY = 3600, 86400

--- A fresh instance with the widget recorder and a recording StaticPopup_Show.
local function inst(opts)
    opts = opts or {}
    local W, popups = nil, {}
    local i = T.load{ libFiles = opts.libFiles, mutate = function(m)
        if not opts.bare then W = Widgets.install(m) end
        -- The logged-in player is the seeded runs' Lanfear, in Destruction: the Runs tab opens on
        -- the current character and spec.
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function(which, _, _, data) popups[#popups + 1] = { which = which, data = data } end
    end }
    i.W, i.popups = W, popups
    i.R = i.NS.Results
    return i
end

local CHARS = {
    lan = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction", ilvl = 313.2 },
    mage = { name = "Kaosmage", realm = "Frostmourne", class = "MAGE", specID = 63, spec = "Fire", ilvl = 311.0 },
    druid = { name = "Barkskin", realm = "Frostmourne", class = "DRUID", specID = 102, spec = "Balance", ilvl = 309.4 },
}

-- A field mkRun removes (pairs never sees a nil value).
local NONE = {}

local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

--- A stored-shape run: a complete 3:00 cleave race by Lanfear, an hour ago. `fields` replaces any
--- top-level field; `char` names one of CHARS.
local function mkRun(id, fields)
    local run = {
        id = id, schema = 1, status = "complete", addon = "0.1.0", build = 120105, date = NOW - HOUR,
        race = { length = 180, grace = 1.0, restartGap = 6, startSource = "meterSession", sessionID = 25 },
        char = copy(CHARS.lan),
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        where = { mapID = 2393, zone = "Silvermoon City", subzone = "Falconwing Square", instanceType = "none" },
        result = { damage = 26560000, dps = 147555.6, meterDps = 134100, sessionDuration = 190, tail = 9.17,
                   combatEnd = 7.34 },
        flags = { lateCasts = {}, reloaded = false, died = false },
        spells = { { id = 29722, dmg = 7330000, dps = 1 }, { id = 116858, dmg = 4920000, dps = 1 } },
        note = "",
    }
    for k, v in pairs(fields or {}) do
        if v == NONE then run[k] = nil else run[k] = v end
    end
    if type(run.char) == "string" then run.char = copy(CHARS[run.char]) end
    return run
end

local function seed(i, runs)
    for _, run in ipairs(runs) do i.NS.db.global.runs[run.id] = run end
    i.NS.Bests.Invalidate()
end

local function ui(i) return assert(i.R.__ui(), "the Results window was never built") end
-- A new profile opens grouped by spec, target and time; these cases read the flat list, so the
-- pane is ungrouped the first time a case reaches it (the grouping itself is test_results_group's).
local function runsPane(i)
    local pane = assert(ui(i).panes.runs, "the Runs tab was never built")
    if not pane.__flat then
        pane.__flat = true
        if pane.filters.group ~= "none" then pane:SetFilter("group", "none") end
    end
    return pane
end
local function visible(pane) return pane.list:Visible() end

local function heard(i, msg)
    local n = { count = 0 }
    i.NS.NewBusTarget():RegisterMessage(i.NS.MSG[msg], function() n.count = n.count + 1 end)
    return n
end

-- ── the run detail ──────────────────────────────────────────────────────────────────────────────

test("results: the detail's section headings are the larger SECTION font; Spell breakdown heads the compare and the list", function()
    local i = inst()
    seed(i, { mkRun("a", { note = "Opened with Bloodlust" }) })
    i.R.Show()
    i.R.ShowRun("a")
    local d = ui(i).detail
    local w, F = d.w, i.NS.Style.FONT
    assertEqual(F.SECTION, "GameFontNormalLarge", "a step above GameFontNormal (Round C, 2026-10-25)")
    assertEqual(i.NS.Style.SECTION_H, 22, "the 16px heading's line")
    assertEqual(w.spellsTitle.__text, "Spell breakdown")
    assertTrue(w.spellsTitle:IsShown())
    for name, fs in pairs({ breakdown = w.spellsTitle, chart = w.chart.title, timing = w.timingLabel,
                            gear = d.lo.title, talents = d.lo.talentsTitle, flags = w.flagTitle, note = w.noteTitle }) do
        assertEqual(fs.__fontObject, F.SECTION, name .. " heading is not FONT.SECTION")
    end
    -- Spell breakdown sits above the compare's toggle, which sits above the spell list.
    local function y(region) return region.__points[1][5] end
    assertTrue(y(w.spellsTitle) > y(d.cmp.toggle), "the heading is under the toggle")
    assertTrue(y(d.cmp.toggle) > y(w.list.parent), "the toggle is under the list")
    assertEqual(y(w.spellsTitle) - y(d.cmp.toggle), i.NS.ResultsDetail.SECTION_H, "one heading line")
    assertEqual(i.NS.ResultsTips.Detail("breakdown", i.NS.Recorder.Get("a"))[1], "Spell breakdown", "the heading's tooltip")
end)

test("results: every section heading has SECTION_GAP of clear space above it, the y-advances from config", function()
    local i = inst()
    seed(i, { mkRun("a", { note = "Opened with Bloodlust", flags = { reloaded = true } }) })
    i.R.Show()
    i.R.ShowRun("a")
    local d = ui(i).detail
    local w, D = d.w, i.NS.ResultsDetail
    local GAP, H = D.SECTION_GAP, D.SECTION_H
    assertEqual(GAP, i.NS.Style.SECTION_GAP)
    assertTrue(GAP >= 14 and GAP <= 18, "a gap the eye reads as a break")
    local function y(region) return region.__points[1][5] end
    -- Spell breakdown: the Delta box's height and its 4px under the box, then the gap.
    assertEqual(y(w.spellsTitle), y(w.deltaBox.frame) - D.KPI_H - 4 - GAP, "Spell breakdown under the header")
    -- Timing (no chart this session): under the spell list's rows and their 8px, then the gap.
    local n, pitch = w.list:Count(), i.NS.HudBreakdown.Pitch()
    assertEqual(y(w.timingLabel), y(w.list.parent) - n * pitch - 8 - GAP, "Timing under the spell rows")
    -- Talents: under the gear grid (or Not recorded), its 6px, then the gap.
    assertTrue(y(d.lo.title) < y(w.timingLabel) - H, "Gear under the timing strip")
    assertTrue(y(w.flags) < y(d.lo.talentsTitle) - H - GAP, "the flags box clear of Talents")
    assertTrue(y(w.noteTitle) <= y(w.flags) - GAP, "Note clear of the flags box")
end)

test("results: the detail's header: 28 px class and spec icons, a larger name, no spec text; the spec icon names the spec", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.Show()
    i.R.ShowRun("a")
    local w = ui(i).detail.w
    assertEqual(i.NS.ResultsDetail.ICON, 28)
    assertEqual(w.name.__fontObject, i.NS.Style.FONT.NAME)
    assertEqual(w.name.__text, "Lanfear")
    assertEqual(w.specName, nil, "the spec text beside the name is gone")
    assertEqual(i.NS.ResultsTips.Detail("class", i.NS.Recorder.Get("a"))[1], "Destruction Warlock",
        "the spec icon's tooltip names the spec and the class")
end)

test("results: the note shows as written under a Note heading; the heading also shows while writing one", function()
    local i = inst()
    seed(i, { mkRun("a", { note = "Opened with Bloodlust" }), mkRun("b", { date = NOW - 2 * HOUR }) })
    i.R.Show()
    i.R.ShowRun("a")
    local d = ui(i).detail
    local w = d.w
    assertEqual(w.note.__text, "Opened with Bloodlust", "no Note: prefix")
    assertTrue(w.noteTitle:IsShown())
    assertEqual(w.noteTitle.__text, "Note")
    assertTrue(w.noteTitle.__points[1][5] > w.note.__points[1][5], "the heading sits over the note")
    i.R.ShowRun("b")
    assertFalse(w.noteTitle:IsShown(), "a heading with no note")
    d:openNote()
    assertTrue(w.noteTitle:IsShown(), "the heading while writing a note")
    assertTrue(w.noteBox:IsShown())
    d:closeNote()
    assertFalse(w.noteTitle:IsShown())
end)

test("results: detail renders breakdown sorted with percentages", function()
    local i = inst()
    seed(i, { mkRun("a", {
        result = { damage = 1000, dps = 5.6, meterDps = 5.1, tail = 2, combatEnd = 1 },
        spells = { { id = 348, dmg = 100 }, { id = 29722, dmg = 500 }, { id = 17962, dmg = 400 } },
    }) })
    i.R.ShowRun("a")
    local d = ui(i).detail
    assertEqual(i.R.Selected(), "a")
    local rows = d.w.list.rows
    assertEqual(#rows, 3)
    assertEqual(rows[1].name.__text, "Incinerate")
    assertEqual(rows[1].pct.__text, "50.0%")
    assertEqual(rows[2].name.__text, "Conflagrate")
    assertEqual(rows[2].pct.__text, "40.0%")
    assertEqual(rows[3].name.__text, "Immolate")
    assertEqual(rows[3].pct.__text, "10.0%")
    assertEqual(rows[1].bar.__max, 500, "bars scale to the top spell")
    assertEqual(d.w.damage.value.__text, "1.0K")
    assertEqual(d.w.meterDps.value.__text, "5", "Blizzard's figure, muted")
    assertEqual(d.w.name.__text, "Lanfear")
    assertEqual(d.w.meta[1].__text, "Frostmourne \194\183 ilvl 313.2 \194\183 Silvermoon City, Falconwing Square")
    assertEqual(d.w.meta[2].__text, "+2.0s \194\183 Cleave Training Dummy")
    assertTrue(d.w.meta[3].__text:find("build 120105", 1, true) ~= nil)
    assertTrue(d.w.meta[3].__text:find("v0.1.0", 1, true) ~= nil)
end)

test("results: timing strip positions buzzer, grace, tail, late casts, combat end", function()
    local i = inst()
    local Detail = i.NS.ResultsDetail
    local run = mkRun("a", {
        result = { damage = 1, dps = 1, tail = 9, combatEnd = 7.5 },
        flags = { lateCasts = { { t = 1.5, spellID = 29722 } } },
    })
    local m = Detail.Timing(run)
    assertEqual(m.span, 12, "the after-buzzer axis runs to the next 6s step, at least 12s")
    assertEqual(m.raceFill, 1)
    assertEqual(m.grace, 1 / 12)
    assertEqual(m.tail, 0.75)
    assertEqual(m.late[1], 0.125)
    assertEqual(m.combatEnd, 0.625)
    local p = Detail.Place(m, 336)
    assertEqual(p.raceW, 181, "the race segment is 1.2 parts of 2.2")
    assertEqual(p.postX, 184)
    assertEqual(p.postW, 152)
    assertEqual(p.buzzer, 181, "the buzzer is the boundary")
    assertTrue(math.abs(p.grace - (184 + 152 / 12)) < 1e-9)
    assertEqual(p.tailX, 184)
    assertEqual(p.tailW, 114)
    assertEqual(p.late[1], 203)
    assertEqual(p.combatEnd, 279)

    run.result.tail = 14
    assertEqual(Detail.Timing(run).span, 18, "a long tail widens the axis")
    -- No combat end heard (a resumed run): the restart and the late casts still size the axis.
    local gap = mkRun("e", {
        result = { damage = 1, dps = 1, tail = 1.2 },
        flags = { lateCasts = { { t = 15, spellID = 348 } }, restartedAt = 14 },
    })
    local mg = Detail.Timing(gap)
    assertEqual(mg.span, 18, "a mark after a missing combat end was skipped")
    assertTrue(mg.restart < 1 and mg.late[1] < 1, "a mark clamped to the strip's edge")
    local inc = mkRun("b", { status = "incomplete", result = { damage = 1, dps = 1, endedAt = 90 } })
    local mi = Detail.Timing(inc)
    assertEqual(mi.raceFill, 0.5)
    assertEqual(Detail.Place(mi, 336).endInRace, 90.5, "combat ended halfway through the race")
    assertEqual(Detail.Timing(mkRun("c", { status = "lost", result = NONE })), nil, "a lost run has no timing")

    -- The pane draws exactly what Place answers.
    seed(i, { mkRun("d", {
        result = { damage = 1, dps = 1, tail = 9, combatEnd = 7.5 },
        flags = { lateCasts = { { t = 1.5, spellID = 29722 }, { t = 3, spellID = 348 } } },
    }) })
    i.R.ShowRun("d")
    local d = ui(i).detail
    assertEqual(#d.place.late, 2)
    local _, ticks = i.NS.Pool.Counts(d.w.ticks)
    assertEqual(ticks, 2, "one tick per late cast")
    assertTrue(d.w.combatEnd:IsShown())
    assertEqual(d.w.tailLine.__text, "Damage stopped +9.0s after the buzzer \194\183 combat ended +7.5s")
    assertEqual(d.w.axisRight.__text, "+12s")
end)

test("results: the detail lists every spell of the run, not a capped top few", function()
    local i = inst()
    local spells = {}
    for n = 1, 45 do spells[n] = { id = 1000 + n, dmg = 100 - n, dps = 1 } end
    seed(i, { mkRun("a", { spells = spells }) })
    i.R.ShowRun("a")
    assertEqual(#ui(i).detail.w.list.rows, 45, "the ability breakdown is the full list (spec §6.2)")
end)

test("results: the detail's spell rows follow HUD Appearance's row height", function()
    local i = inst()
    seed(i, { mkRun("a") })
    assertTrue(i.NS.SetByPath("appearance.bars.rowHeight", 24))
    i.R.ShowRun("a")
    local list = ui(i).detail.w.list
    local second = list.rows[2]
    local y
    for _, p in ipairs(second.__points or {}) do if p[1] == "TOPLEFT" then y = p[5] end end
    if y ~= nil then assertEqual(y, -26, "the second row one pitch down (24 + the 2 px gap)") end
    assertEqual(i.NS.HudBreakdown.Pitch(), 26)
end)

test("results: detail flags name late-cast spells and the session matched by list", function()
    local i = inst()
    seed(i, { mkRun("a", {
        flags = { lateCasts = { { t = 1.4, spellID = 29722 } }, sessionFromList = true },
    }) })
    i.R.ShowRun("a")
    local d = ui(i).detail
    local keys = {}
    for n, line in ipairs(d.flagLines) do keys[n] = line.key end
    assertEqual(table.concat(keys, ","), "lateCasts,sessionFromList")
    assertEqual(d.w.flagTitle.__text, "Flags")
    local rows = d.w.flagRows
    assertEqual(rows[1].main.__text, "1 late cast")
    assertEqual(rows[1].sub.__text, "+1.4s Incinerate")
    local body = rows[1].body.__text
    assertTrue(body:find("Incinerate started +1.4s after the buzzer (grace 1.0s).", 1, true) ~= nil, body)
    assertTrue(body:find("The run still counts", 1, true) ~= nil, body)
    assertEqual(rows[2].main.__text, "Session matched by list")
    assertFalse(rows[2].sub:IsShown(), "a flag with no detail line")
    assertTrue(rows[2].body.__text:find("found by its place in Blizzard's list", 1, true) ~= nil, rows[2].body.__text)

    seed(i, { mkRun("b", { status = "incomplete", result = { damage = 1, dps = 1, endedAt = 60 } }) })
    i.R.ShowRun("b")
    assertEqual(rows[1].main.__text, "Incomplete: combat ended before the buzzer")
    assertEqual(rows[1].body.__text, "It does not count toward bests.")
    assertFalse(rows[2].main:IsShown(), "the second row left from the run before is hidden")
    assertFalse(rows[2].body:IsShown())
    assertEqual(d.w.dps.label.__text, "DPS \194\183 Incomplete")
end)

test("results: delete asks confirmation then fires RUNS_CHANGED", function()
    local i = inst()
    seed(i, { mkRun("a"), mkRun("b", { date = NOW - 2 * HOUR }) })
    local changed = heard(i, "RUNS_CHANGED")
    i.R.ShowRun("a")
    local d = ui(i).detail
    d.w.delete:__fire("OnClick")
    assertEqual(#i.popups, 1, "no confirmation was asked")
    assertEqual(i.popups[1].which, "DPSRACE_DELETE_RUN")
    assertEqual(i.popups[1].data.id, "a")
    assertEqual(i.popups[1].data.onAccept, nil, "the window's own Delete marks nothing")
    assertTrue(i.NS.Recorder.Get("a") ~= nil, "deleted before the player confirmed")
    assertEqual(changed.count, 0)
    i.mocks.StaticPopupDialogs.DPSRACE_DELETE_RUN.OnAccept(nil, i.popups[1].data)
    assertEqual(i.NS.Recorder.Get("a"), nil)
    assertEqual(changed.count, 1)
    assertEqual(i.R.Selected(), nil, "the detail still names a deleted run")
    assertEqual(runsPane(i).countText, "1 run", "the list did not follow the delete")
end)

test("results: note limited to 200 chars", function()
    local i = inst()
    local Detail = i.NS.ResultsDetail
    assertEqual(#Detail.ClampNote(string.rep("a", 250)), 200)
    local accented = Detail.ClampNote(string.rep("\195\169", 250))
    assertEqual(#accented, 400, "200 characters of two bytes each, never a cut through one")
    assertEqual(Detail.ClampNote("  pulled with pots  "), "pulled with pots")
    assertEqual(Detail.ClampNote("|cffff0000red|r"), "/cffff0000red/r", "chat escapes are neutralized")
    assertEqual(Detail.ClampNote(nil), "")

    seed(i, { mkRun("a") })
    local saved, changed = heard(i, "RUN_SAVED"), heard(i, "RUNS_CHANGED")
    i.R.ShowRun("a")
    local d = ui(i).detail
    assertEqual(d.w.addNote.label.__text, "Add Note")
    d.w.addNote:__fire("OnClick")
    assertTrue(d.editing, "Add note opened no editor")
    d.w.noteBox:SetText(string.rep("x", 260))
    d.w.noteBox:__fire("OnEnterPressed")
    assertEqual(#i.NS.Recorder.Get("a").note, 200)
    assertEqual(saved.count, 0, "a note is not a race result: RUN_SAVED would prune the store")
    assertEqual(changed.count, 1, "the note was not announced as a store change")
    assertFalse(d.editing)
    assertEqual(d.w.addNote.label.__text, "Edit Note")
    assertEqual(d.w.note.__text, string.rep("x", 200), "the note as written, under its own heading")
end)

test("results: opening the note scrolls its box into view", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.ShowRun("a")
    local d = ui(i).detail
    d:Layout(340, 140, false)               -- shorter than the run's detail: the box starts below the view
    assertTrue(d.contentH > d.viewH, "the detail fits the pane; the case under test never arises")
    assertEqual(d.scroll, 0)
    d.w.addNote:__fire("OnClick")
    assertEqual(d.scroll, d.contentH - d.viewH, "the note box was left below the visible area")
end)

-- A stand-in GameTooltip that records what it was asked to show.
local function recordingTip(env)
    local tip = { lines = {} }
    for _, m in ipairs({ "Show", "Hide", "ClearAllPoints" }) do tip[m] = function() end end
    function tip.SetOwner(_, owner, anchor) tip.owner, tip.anchor, tip.lines, tip.spell = owner, anchor, {}, nil end
    function tip.SetText(_, text) tip.lines[1] = text end
    function tip.AddLine(_, text) tip.lines[#tip.lines + 1] = text end
    function tip.SetSpellByID(_, id) tip.spell = id end
    function tip.NumLines() return tip.spell and 4 or #tip.lines end
    function tip.GetWidth() return 300 end
    function tip.GetEffectiveScale() return 1 end
    function tip.SetPoint(_, point, _, rel) tip.placed = { point, rel } end
    env.GameTooltip = tip
    return tip
end

test("results: every detail element has a tooltip; spells show the client's spell tooltip beside the window", function()
    local i = inst()
    seed(i, { mkRun("a", { note = "pulled with pots", flags = { lateCasts = { { t = 1.4, spellID = 29722 } } } }) })
    i.R.ShowRun("a")
    local d, Tips = ui(i).detail, i.NS.ResultsTips
    local run = i.NS.Recorder.Get("a")
    for _, key in ipairs({ "class", "name", "realm", "target", "stamp", "damage", "dps", "meterDps", "strip",
                           "tail", "flags", "note", "noteBox", "addNote", "share", "shareOff", "delete", "back" }) do
        local lines = Tips.Detail(key, run)
        assertTrue(type(lines) == "table" and type(lines[1]) == "string", key .. " has a tooltip")
    end
    for n = 1, #i.NS.ResultsDetail.LEGEND do
        assertEqual(Tips.Detail("legend", run, n)[1], i.NS.ResultsDetail.LEGEND[n])
    end

    local tip = recordingTip(i.mocks)
    i.mocks.UIParent = { GetRight = function() return 1920 end, GetEffectiveScale = function() return 1 end }
    local window = i.NS.ResultsTable.WindowOf(d.frame)
    window.GetRight = function() return 1200 end
    window.GetTop = function() return 800 end
    window.GetEffectiveScale = function() return 1 end
    d.w.list.rows[1].GetTop = function() return 700 end
    -- A spell row: the client's spell tooltip, then the exact damage, its share and its place.
    local row = d.w.list.rows[1]
    row:__fire("OnEnter")
    assertEqual(tip.spell, 29722, "the row did not show its spell's tooltip")
    assertEqual(tip.anchor, "ANCHOR_NONE")
    assertEqual(tip.placed[1], "TOPLEFT", "the spell tooltip sits beside the window")
    assertTrue(tip.lines[2] == "\226\128\162 7,330,000 damage", "the exact damage follows the spell, on a bullet")
    assertEqual(tip.lines[4], "\226\128\162 #1 of 2 spells")
    -- The Spell breakdown heading: beside the window, as every tooltip of its section (DR-05).
    d.w.spellsTitleHover:__fire("OnEnter")
    assertTrue(tip.anchor == "ANCHOR_NONE" and tip.placed[1] == "TOPLEFT", "the breakdown heading's beside the window")
    -- Anything else: under itself.
    d.w.dps.frame:__fire("OnEnter")
    assertEqual(tip.anchor, "ANCHOR_BOTTOM")
    assertEqual(tip.owner, d.w.dps.frame)
    assertEqual(tip.lines[1], "147,556 DPS")
    d.w.delete:__fire("OnEnter")
    assertEqual(tip.lines[1], "Delete")
    -- The note's hover frame steps aside while the box is open, so it never takes the box's clicks.
    assertTrue(d.w.noteHover:IsShown())
    d.w.addNote:__fire("OnClick")
    assertFalse(d.w.noteHover:IsShown(), "the note's hover frame covers the open note box")
end)

test("results: the timing strip's marks draw above its two segments", function()
    local i = inst()
    seed(i, { mkRun("a") })
    i.R.ShowRun("a")
    local w = ui(i).detail.w
    -- A child frame draws over its parent's own textures, so marks made on the strip sat under the
    -- opaque segments: they need a frame of their own, above both.
    assertTrue(w.marks ~= nil, "the marks have no frame of their own")
    assertEqual(w.marks:GetParent(), w.strip)
    assertTrue(w.marks:GetFrameLevel() > w.segA:GetFrameLevel(), "the marks sit under the race segment")
    assertTrue(w.marks:GetFrameLevel() > w.segB:GetFrameLevel(), "the marks sit under the after-buzzer segment")
end)

test("results: the timing legend is two rows, the bars' colors over the lines', Restart among the lines", function()
    local i = inst()
    local Detail = i.NS.ResultsDetail
    local named, rows = {}, {}
    for r, indices in ipairs(Detail.LEGEND_ROWS) do
        local labels = {}
        for _, n in ipairs(indices) do
            assertEqual(named[n], nil, "a legend entry sits in two rows")
            named[n] = true
            labels[#labels + 1] = Detail.LEGEND[n]
        end
        rows[r] = table.concat(labels, "|")
    end
    assertEqual(#rows, 2)
    assertEqual(rows[1], "Race|Tail (damage still landing)")
    assertEqual(rows[2], "Grace|Late cast|Combat ended|Restart")
    for n = 1, #Detail.LEGEND do assertTrue(named[n], Detail.LEGEND[n] .. " is in no row") end
end)

test("results: a spell list built without a tip hook takes no mouse", function()
    local i = inst()
    local list = i.NS.HudBreakdown.New(i.mocks.CreateFrame("Frame"))
    list:ShowResult({ spells = { { id = 29722, dmg = 10 } }, result = { damage = 10 } }, 1, true)
    assertEqual(list.rows[1].tipWired, nil, "a list without a tip hook wired a hover")
end)

test("results: saving a note never prunes the store", function()
    local i = inst()
    local runs = {}
    for n = 1, 4 do runs[n] = mkRun("r" .. n, { date = NOW - n * DAY, result = { damage = 1000 * n, dps = 10 * n } }) end
    seed(i, runs)
    i.NS.db.global.history.keepDays = 1     -- lowered with older runs stored: nothing goes until the next race
    assertEqual(i.R.SetNote("r4", "old pull"), "old pull")
    local left = 0
    for _ in pairs(i.NS.db.global.runs) do left = left + 1 end
    assertEqual(left, 4, "typing a note deleted runs")
    assertEqual(i.NS.Recorder.Get("r4").note, "old pull")
end)

test("results: Share is grayed without a Share module; a row's right-click menu notes, shares and deletes", function()
    local i = inst()
    seed(i, { mkRun("a") })
    local module = i.NS.Share
    i.NS.Share = nil
    i.R.ShowRun("a")
    local d = ui(i).detail
    assertFalse(d.w.share:IsEnabled(), "Share is live with nothing to share through")
    assertEqual(type(module.Prompt), "function", "modules/Share.lua publishes NS.Share.Prompt")
    local shared = {}
    i.NS.Share = { Prompt = function(run) shared[#shared + 1] = run.id end }
    i.R.ShowRun("a")
    assertTrue(d.w.share:IsEnabled())
    d.w.share:__fire("OnClick")
    assertEqual(table.concat(shared, ","), "a")
    i.NS.Share = module
    -- No double-click share any more; a right-click opens the row's menu.
    local row = visible(runsPane(i))[1]
    row:__fire("OnDoubleClick")
    assertEqual(#shared, 1, "a double-click no longer shares")
    row:__fire("OnClick", "RightButton")
    local menu = i.mocks.__menus[#i.mocks.__menus]
    assert(menu, "no row menu")
    local labels = {}
    for n, e in ipairs(menu.entries) do labels[n] = e.text end
    assertEqual(table.concat(labels, "|"), "Add Note|Share|Compare With This Run|\124cffff5555Delete\124r")
    local shareEntry = menu:Find("Share")
    local channels = {}
    for n, e in ipairs(shareEntry.children) do channels[n] = e.text end
    assertEqual(table.concat(channels, "|"), "Say|Party|Raid|Guild|Whisper\226\128\166", "Share's channels as a submenu")
    menu:Click("Add Note")
    assertEqual(i.R.Selected(), "a", "Add Note opens the run")
    assertTrue(ui(i).detail.editing, "with its note box open")
    menu:Click("\124cffff5555Delete")
    assertEqual(i.popups[#i.popups].which, "DPSRACE_DELETE_RUN", "Delete asks first")
end)
