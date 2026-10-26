-- tests/test_results_sections.lua — the run detail's collapsible sections (UT-P10, modules/Results_Detail.lua
-- with the section modules): every section heading's arrow (chevron-down open, chevron-right folded),
-- a click on the arrow or the heading's text folding and opening it, a folded section's body hidden
-- and the sections under it moved up by the layout's own numbers, the state stored in
-- profile.windows.results.collapsedSections and read back by a rebuilt pane, kept by Reset position
-- and cleared by Reset all settings, and the note box opening a folded Note.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()

local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
    end }
    i.R, i.D = i.NS.Results, i.NS.ResultsDetail
    -- A chart for every run (the slices are this session's only): a stand-in view, drawn by a recorder.
    i.NS.ResultsSource.ChartView = function() return { count = 4, values = { 1, 2, 3, 4 }, length = 180, max = 10 } end
    return i
end

-- A complete run with a flag, a note and a usage record of one potion.
local function mkRun(id, fields)
    local run = {
        id = id, schema = 3, status = "complete", addon = "0.1.0", date = NOW - 3600,
        race = { length = 180, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction",
                 ilvl = 313.2 },
        target = { npcID = 225983, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = 26560000, dps = 147555.6, tail = 2, combatEnd = 1.5 },
        flags = { lateCasts = {}, reloaded = true },
        spells = { { id = 29722, dmg = 7330000 }, { id = 116858, dmg = 4920000 } },
        note = "Opened with Bloodlust",
        usage = { v = 1, edited = false, used = { { itemID = 211001, kind = "potion", times = { 3 }, n = 1, src = "cast" } },
                  candidates = { { itemID = 211001, kind = "potion" } } },
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    return run
end

local function seed(i, runs)
    for _, run in ipairs(runs) do i.NS.db.global.runs[run.id] = run end
    i.NS.Bests.Invalidate()
end

local function ui(i) return assert(i.R.__ui(), "the Results window was never built") end

-- The detail drawing run "a", its chart's Draw recorded rather than run.
local function open(i)
    seed(i, { mkRun("a"), mkRun("b", { date = NOW - 7200 }) })
    i.R.Show()
    local d = ui(i).detail
    d.w.chart.Draw = function(self, view) self.drawn = view end
    i.R.ShowRun("a")
    return d
end

local function y(region) return region.__points[1][5] end
local function x(region) return region.__points[1][4] end

-- Each section's heading and one part of its body.
local function parts(d)
    local w = d.w
    return {
        spells = { w.spellsTitle, w.list.parent },
        chart = { w.chart.title, w.chart.plot },
        timing = { w.timingLabel, w.strip },
        gear = { d.lo.title, d.lo.none },
        talents = { d.lo.talentsTitle, d.lo.talents },
        usage = { d.usage.title, d.usage.edit },
        flags = { w.flagTitle, w.flags },
        note = { w.noteTitle, w.note },
    }
end

test("sections: every section heading has an arrow left of its text, open and chevron-down by default", function()
    local i = inst()
    local d = open(i)
    local D = i.D
    assertEqual(table.concat(D.SECTIONS, ","), "spells,chart,timing,gear,talents,usage,flags,note")
    assertEqual(D.INDENT, D.ARROW + 2)
    local p = parts(d)
    for _, key in ipairs(D.SECTIONS) do
        local arrow, title = d.heads[key], p[key][1]
        assertTrue(arrow ~= nil, key .. " has no arrow")
        assertTrue(arrow:IsShown(), key .. "'s arrow is hidden")
        assertEqual(arrow.iconName, "chevron-down", key)
        assertEqual(arrow.icon.__texture, i.NS.Icon("chevron-down"), key .. " draws the catalog's chevron")
        assertEqual(arrow.tip, "Collapse this section", key)
        assertFalse(D.IsCollapsed(key), key)
        -- The arrow rides on the heading, 2 px before its text; the text starts INDENT in.
        local pt = arrow.__points[1]
        assertTrue(pt[1] == "RIGHT" and pt[2] == title and pt[3] == "LEFT", key .. "'s arrow is not on its heading")
        assertEqual(pt[4], -2, key)
        assertTrue(p[key][2]:IsShown(), key .. "'s body is hidden")
    end
    for _, key in ipairs(D.SECTIONS) do
        assertEqual(x(p[key][1]), D.INDENT, key .. "'s heading text is not after its arrow")
    end
end)

test("sections: the arrow and the heading's text each fold and open every section, the arrow's icon following", function()
    local i = inst()
    local d = open(i)
    local p = parts(d)
    for _, key in ipairs(i.D.SECTIONS) do
        local arrow, body = d.heads[key], p[key][2]
        arrow:__fire("OnClick")
        assertTrue(i.D.IsCollapsed(key), key .. " did not fold")
        assertEqual(i.NS.db.profile.windows.results.collapsedSections[key], true, key .. " is stored")
        assertEqual(arrow.iconName, "chevron-right", key)
        assertEqual(arrow.icon.__texture, i.NS.Icon("chevron-right"), key)
        assertEqual(arrow.tip, "Expand this section", key)
        assertTrue(p[key][1]:IsShown(), key .. "'s heading went with its body")
        assertFalse(body:IsShown(), key .. "'s body still shows")
        arrow:__fire("OnClick")
        assertFalse(i.D.IsCollapsed(key), key .. " did not open")
        assertEqual(i.NS.db.profile.windows.results.collapsedSections[key], nil, "an open section is stored as nothing")
        assertEqual(arrow.iconName, "chevron-down", key)
        assertTrue(body:IsShown(), key .. "'s body did not come back")
    end
    -- The heading's text (its hover frame, the section module's own): a left click folds and opens,
    -- a right click does nothing.
    for _, key in ipairs(i.D.SECTIONS) do
        local f = d.heads[key].click
        assertTrue(f ~= nil and f.__mouse == true, key .. "'s heading takes no click")
        f:__fire("OnMouseUp", "LeftButton")
        assertTrue(i.D.IsCollapsed(key), key .. "'s heading did not fold it")
        assertFalse(p[key][2]:IsShown(), key)
        f:__fire("OnMouseUp", "RightButton")
        assertTrue(i.D.IsCollapsed(key), key .. ": a right click toggled")
        f:__fire("OnMouseUp", "LeftButton")
        assertFalse(i.D.IsCollapsed(key), key .. "'s heading did not open it")
    end
end)

test("sections: a folded section's body is hidden, and the sections under it move up by its body's height", function()
    local i = inst()
    local d = open(i)
    local D, w = i.D, d.w
    local H, GAP = D.SECTION_H, D.SECTION_GAP
    local fullH = d.contentH
    local timingY = y(w.timingLabel)
    local chartY = y(w.chart.title)
    -- Spell breakdown folded: its heading line alone, the chart's heading SECTION_GAP under it.
    d.heads.spells:__fire("OnClick")
    assertFalse(d.cmp.toggle:IsShown(), "the compare's toggle went with the breakdown")
    assertFalse(w.list.parent:IsShown())
    assertEqual(y(w.chart.title), y(w.spellsTitle) - H - GAP, "the chart moved up under the heading")
    local moved = y(w.chart.title) - chartY
    assertTrue(moved > 0, "nothing moved")
    assertEqual(y(w.timingLabel) - timingY, moved, "every section under it moved by as much")
    assertEqual(fullH - d.contentH, moved, "the scroll range follows")
    -- The chart folded too: Timing under its heading line, the plot hidden and its hover off.
    d.heads.chart:__fire("OnClick")
    assertFalse(w.chart.plot:IsShown())
    assertTrue(w.chart.title:IsShown())
    assertFalse(w.chart.over.__mouse, "the folded plot takes no mouse")
    assertEqual(y(w.timingLabel), y(w.chart.title) - H - GAP, "Timing under the chart's heading")
    -- Timing folded: Gear under its heading, every strip hover hidden with it.
    d.heads.timing:__fire("OnClick")
    assertEqual(y(d.lo.title), y(w.timingLabel) - H - GAP, "Gear under Timing's heading")
    for _, f in ipairs(w.timingHovers) do assertFalse(f:IsShown(), "a strip hover was left over the moved sections") end
    -- Gear folded: Talents under its heading line (the line Dressing Room shares).
    d.heads.gear:__fire("OnClick")
    assertFalse(d.lo.none:IsShown())
    assertFalse(d.lo.noneHover:IsShown())
    assertEqual(y(d.lo.talentsTitle), y(d.lo.title) - math.max(H, i.NS.ResultsLoadout.BUTTON_H) - 2 - GAP)
    -- Talents folded: its line and View and Copy hidden, Usage under its heading (and the loadout's 8 px).
    d.heads.talents:__fire("OnClick")
    assertFalse(d.lo.talents:IsShown())
    assertFalse(d.lo.view:IsShown())
    assertFalse(d.lo.copy:IsShown())
    assertEqual(y(d.usage.title), y(d.lo.talentsTitle) - H - 8 - GAP, "Usage under Talents' heading")
    -- Usage folded: its rows and Edit hidden.
    d.heads.usage:__fire("OnClick")
    assertFalse(d.usage.edit:IsShown())
    for _, row in ipairs(d.usage.items) do assertFalse(row:IsShown(), "a usage row still shows") end
    -- Flags folded: its heading alone, the box under it hidden, Note under the heading.
    d.heads.flags:__fire("OnClick")
    assertTrue(w.flagTitle:IsShown())
    assertFalse(w.flags:IsShown(), "the box went with the folded section")
    assertTrue(w.flagTitleHover:IsShown(), "the heading keeps its tooltip")
    assertEqual(y(w.noteTitle), y(w.flagTitle) - H - GAP, "Note under the Flags heading")
    -- The note folded: its text and its hover hidden.
    d.heads.note:__fire("OnClick")
    assertFalse(w.note:IsShown())
    assertFalse(w.noteHover:IsShown())
    assertEqual(-d.contentH, y(w.noteTitle) - H, "the content ends under the last heading")
    -- Every section open again: the first layout's height.
    for _, key in ipairs(D.SECTIONS) do d:ToggleSection(key) end
    assertEqual(d.contentH, fullH, "the open layout came back")
    assertTrue(d.cmp.toggle:IsShown(), "the compare's toggle came back")
end)

test("sections: the folded state is the profile's, read back by a rebuilt pane and by every run", function()
    local i = inst()
    local d = open(i)
    d.heads.timing:__fire("OnClick")
    d.heads.usage:__fire("OnClick")
    -- Another run: still folded.
    i.R.ShowRun("b")
    assertFalse(d.w.strip:IsShown(), "another run opened Timing")
    assertEqual(d.heads.timing.iconName, "chevron-right")
    -- A pane built afresh on the same profile (a /reload builds the window again).
    local p = i.D.Build(ui(i).body, {})
    p:Layout(360, 500, false)
    p:Show(i.NS.db.global.runs.a)
    assertEqual(p.heads.timing.iconName, "chevron-right", "the rebuilt pane forgot Timing")
    assertEqual(p.heads.usage.iconName, "chevron-right")
    assertEqual(p.heads.gear.iconName, "chevron-down")
    assertFalse(p.w.strip:IsShown())
    assertTrue(p.lo.title:IsShown())
end)

test("sections: Reset position keeps the folded sections; a profile reset and Reset all settings clear them", function()
    local i = inst()
    local d = open(i)
    assertEqual(next(i.NS.defaults.profile.windows.results.collapsedSections), nil, "a new profile folds nothing")
    d.heads.gear:__fire("OnClick")
    i.R.ResetPosition()
    assertTrue(i.D.IsCollapsed("gear"), "Reset position opened Gear")
    i.NS.Helpers.RestoreAllDefaults()
    assertFalse(i.D.IsCollapsed("gear"), "Reset all settings kept Gear folded")
    d.heads.talents:__fire("OnClick")
    i.NS.db:ResetProfile()
    assertFalse(i.D.IsCollapsed("talents"), "the profile reset kept Talents folded")
end)

test("sections: Add Note opens a folded Note; folding the Note while writing closes the box unsaved", function()
    local i = inst()
    local d = open(i)
    d.heads.note:__fire("OnClick")
    assertFalse(d.w.note:IsShown())
    d:openNote()
    assertFalse(i.D.IsCollapsed("note"), "the box opened under a folded Note")
    assertTrue(d.w.noteBox:IsShown())
    assertEqual(d.heads.note.iconName, "chevron-down")
    d.w.noteBox:SetText("half written")
    d.heads.note:__fire("OnClick")
    assertFalse(d.editing, "the box stayed open")
    assertFalse(d.w.noteBox:IsShown())
    assertTrue(i.D.IsCollapsed("note"))
    assertEqual(i.NS.db.global.runs.a.note, "Opened with Bloodlust", "nothing was saved")
end)

test("sections: a heading the run does not draw hides its arrow", function()
    local i = inst()
    seed(i, { mkRun("c", { note = "", flags = { lateCasts = {} } }) })
    i.R.Show()
    local d = ui(i).detail
    d.w.chart.Draw = function() end
    i.NS.ResultsSource.ChartView = function() return nil end
    i.R.ShowRun("c")
    assertFalse(d.heads.chart:IsShown(), "no chart, no arrow")
    assertFalse(d.heads.note:IsShown(), "no note, no arrow")
    assertFalse(d.heads.flags:IsShown(), "no flags, no arrow")
    assertTrue(d.heads.spells:IsShown())
end)

test("sections: a lost run after a drawn one hides Timing's heading hover, so it takes no click", function()
    local i = inst()
    local d = open(i)
    local hover = d.w.timingTitleHover
    assertTrue(hover:IsShown(), "a run with a result shows Timing's heading hover")
    seed(i, { mkRun("lost", { status = "lost", result = false }) })
    i.R.ShowRun("lost")
    assertFalse(d.w.timingLabel:IsShown(), "a lost run draws no Timing")
    assertFalse(hover:IsShown(), "Timing's heading hover was left over the sections under it")
    assertFalse(d.heads.timing:IsShown(), "no Timing, no arrow")
end)

test("sections: Flags is a section heading over the yellow box; each flag's main line, detail and meaning read apart", function()
    local i = inst()
    seed(i, { mkRun("a", { flags = { lateCasts = { { t = 1.4, spellID = 29722 }, { t = 2.5, spellID = 116858 } },
                                     died = true } }) })
    i.R.Show()
    i.R.ShowRun("a")
    local d = ui(i).detail
    local D, w, F = i.D, d.w, i.NS.Style.FONT
    local H, GAP = D.SECTION_H, D.SECTION_GAP
    -- The heading: the plain word in FONT.SECTION (gold), its arrow beside it, on the content.
    assertEqual(w.flagTitle.__text, "Flags")
    assertEqual(w.flagTitle.__fontObject, F.SECTION)
    assertEqual(w.flagTitle.__color, nil, "the heading keeps the font's own gold")
    assertEqual(x(w.flagTitle), D.INDENT)
    assertTrue(d.heads.flags:IsShown())
    -- The box one heading line under it, across the content's width.
    assertEqual(y(w.flags), y(w.flagTitle) - H, "the box sits under the heading")
    assertEqual(x(w.flags), 0)
    -- The late casts: their count, then their offsets in the caption font and amber, then what they mean.
    local r1, r2 = w.flagRows[1], w.flagRows[2]
    assertEqual(r1.main.__text, "2 late casts")
    assertEqual(r1.main.__fontObject, F.SECTION, "the main line keeps the box title's size")
    assertEqual(r1.sub.__text, "+1.4s Incinerate, +2.5s Chaos Bolt")
    assertEqual(r1.sub.__fontObject, F.CAPTION)
    assertEqual(r1.body.__fontObject, F.TEXT)
    local C = i.NS.ResultsTable.COLORS
    local function rgb(fs) return table.concat({ fs.__color[1], fs.__color[2], fs.__color[3] }, ",") end
    assertEqual(rgb(r1.sub), table.concat(C.amber, ","), "the detail's own hue")
    assertTrue(rgb(r1.sub) ~= rgb(r1.main) and rgb(r1.sub) ~= rgb(r1.body), "the detail reads apart from both")
    assertTrue(r1.body.__text:find("Incinerate started +1.4s after the buzzer", 1, true) ~= nil, r1.body.__text)
    -- The three lines stacked inside the box from config.
    local P = D.FLAG_PADY
    assertEqual(y(r1.main), -P)
    assertEqual(y(r1.sub), -(P + D.FLAG_MAIN_H))
    assertEqual(y(r1.body), -(P + D.FLAG_MAIN_H + D.FLAG_SUB_H))
    assertEqual(x(r1.main), D.FLAG_PADX)
    -- Died says it all on its line: no detail, no meaning, the box's next flag FLAG_GAP down.
    assertEqual(r2.main.__text, "Died during the run")
    assertFalse(r2.sub:IsShown())
    assertFalse(r2.body:IsShown())
    assertTrue(y(r2.main) < y(r1.body) - D.FLAG_GAP, "the second flag under the first's meaning")
    -- The tooltip on the heading and on the box: Scoring's one-line texts.
    local tip = i.NS.ResultsTips.Detail("flags", i.NS.Recorder.Get("a"))
    assertEqual(tip[1], "2 flags")
    assertEqual(tip[2], "2 late casts (+1.4s Incinerate, +2.5s Chaos Bolt)")
    assertTrue(w.flagTitleHover.__mouse == true, "the heading takes the mouse")
    -- Note under the box, the gap above its heading.
    assertTrue(y(w.noteTitle) < y(w.flags) - GAP, "Note clear of the box")
    -- A run with no flags: no heading, no arrow, no box.
    seed(i, { mkRun("c", { flags = {} }) })
    i.R.ShowRun("c")
    assertFalse(w.flagTitle:IsShown())
    assertFalse(d.heads.flags:IsShown())
    assertFalse(w.flags:IsShown())
end)
