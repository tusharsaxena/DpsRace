-- tests/test_results_delta.lua — the Results detail's Delta box and its New best badge (the owner's
-- call, 2026-10-26; modules/Results_Detail.lua over modules/Results_Runs.lua's contexts): the Runs
-- list's Delta for the run shown (its group under the view's Group by, or the whole view), the
-- group's top run's lead over its runner-up, the badge on that run alone, the redraw when the view's
-- grouping or filters change, and the fallback to the run's board for a run the filters leave out.
-- Its own suite under layout-§1's 1500-line cap; the helpers are tests/test_results.lua's.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600

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
        target = { npcID = 225983, name = "Cleave Training Dummy", category = "cleave" },
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
-- The Runs tab, flat (a new profile groups by Full): these cases group it themselves.
local function runsPane(i)
    local pane = assert(ui(i).panes.runs, "the Runs tab was never built")
    if not pane.__flat then
        pane.__flat = true
        if pane.filters.group ~= "none" then pane:SetFilter("group", "none") end
    end
    return pane
end

local function visibleIDs(pane)
    local out = {}
    for n, row in ipairs(pane.list:Visible()) do out[n] = row.run.id end
    return table.concat(out, ",")
end

-- The detail's Delta box: its figure, its color, and whether the New best badge shows.
local function deltaBox(i)
    local w = ui(i).detail.w
    return w.deltaBox.value.__text, w.deltaBox.value.__color, w.badge:IsShown()
end

test("results: the detail's Delta box: a best's lead, a non-best's Delta cell, a lone run, an incomplete run's muted figure, a lost run", function()
    local i = inst()
    seed(i, {
        mkRun("top", { result = { damage = 1, dps = 150000 } }),
        mkRun("slow", { result = { damage = 1, dps = 120000 }, date = NOW - 2 * HOUR }),
        mkRun("inc", { status = "incomplete", result = { damage = 1, dps = 180000, endedAt = 9 }, date = NOW - 3 * HOUR }),
        mkRun("lost", { status = "lost", result = NONE, date = NOW - 4 * HOUR }),
        mkRun("lone", { target = { category = "boss", count = 1 }, result = { damage = 1, dps = 90000 },
                        date = NOW - 5 * HOUR }),
    })
    i.R.Show()
    runsPane(i):SetFilter("group", "target")
    local C, DASH = i.NS.ResultsTable.COLORS, "\226\128\148"
    i.R.ShowRun("top")
    local text, color, badge = deltaBox(i)
    assertEqual(text, "+25.0%", "the group's top: its lead over the runner-up (150,000 against 120,000)")
    assertEqual(color[1], C.green[1])
    assertTrue(badge, "the New best badge on the group's top complete run")
    i.R.ShowRun("slow")
    text, color, badge = deltaBox(i)
    assertEqual(text, "-20.0%", "not the top: its Delta cell's figure")
    assertEqual(color[1], C.red[1])
    assertFalse(badge, "no badge below the top")
    i.R.ShowRun("lone")
    text, color, badge = deltaBox(i)
    assertEqual(text, DASH, "alone in its group: no runner-up to lead")
    assertEqual(color[1], C.dim[1])
    assertTrue(badge, "still its group's top")
    i.R.ShowRun("inc")
    text, color, badge = deltaBox(i)
    assertEqual(text, "+20.0%", "an incomplete run: its Delta cell's figure, above the max it never sets")
    assertEqual(color[1], C.dim[1], "the Delta cell's muted color")
    assertFalse(badge, "an incomplete run never sets the max")
    local d = ui(i).detail
    local tip = i.NS.ResultsTips.Detail("delta", d.run, d.deltaCtx)
    assertEqual(tip[2], "Against the max DPS in its group in the Runs list.")
    assertEqual(tip[4], "An incomplete run is compared, but never sets the max.")
    i.R.ShowRun("lost")
    text, color, badge = deltaBox(i)
    assertEqual(text, DASH, "a lost run: no DPS to compare")
    assertEqual(color[1], C.dim[1])
    assertFalse(badge)
    -- One of the three figures' size and look, captioned Delta; the badge beside it, as tall, no box.
    local w, D = ui(i).detail.w, i.NS.ResultsDetail
    assertEqual(w.delta, nil, "the old line is gone")
    assertEqual(w.deltaBox.label.__text, "Delta")
    assertEqual(w.deltaBox.value.__fontObject, w.dps.value.__fontObject)
    assertEqual(w.deltaBox.frame.__width, w.damage.frame.__width)
    assertEqual(w.deltaBox.frame.__height, D.KPI_H)
    assertEqual(w.badge.__height, D.KPI_H)
    assertEqual(w.badgeText.__text, "New best")
    assertEqual(w.badgeIcon.__texture, i.NS.Icon("ph:trophy"))
    assertEqual(w.badgeIcon.__vertex[3], C.blue[3], "the Status column's Spec best blue")
    assertEqual(w.badgeText.__color[1], C.blue[1])
end)

test("results: Runs.Leaders breaks a DPS tie on the earlier run, then the id; the tied runner-up reads 0.0% in green", function()
    local i = inst()
    local Runs = i.NS.ResultsRuns
    local a = mkRun("a", { result = { damage = 1, dps = 100000 }, date = NOW - HOUR })
    local b = mkRun("b", { result = { damage = 1, dps = 100000 }, date = NOW - 2 * HOUR })
    local c = mkRun("c", { result = { damage = 1, dps = 90000 } })
    local inc = mkRun("inc", { status = "incomplete", result = { damage = 1, dps = 200000 } })
    local first, second = Runs.Leaders({ a, c, inc, b })
    assertEqual(first.id, "b", "the earlier of two equal runs set the mark first")
    assertEqual(second.id, "a")
    local ctx = Runs.Context({ a, b, c, inc }, "view")
    assertEqual(ctx.top, 100000)
    assertEqual((Runs.DeltaBox(b, ctx)), "+0.0%", "a lead of nothing over the tied runner-up")
    local text, color, top = Runs.DeltaBox(a, ctx)
    assertEqual(text, "0.0%", "the tied runner-up: its Delta cell, green (level with the max)")
    for k = 1, 3 do assertEqual(color[k], i.NS.ResultsTable.COLORS.green[k]) end
    -- The top's lead is that same green: the box and the column agree.
    local _, topColor = Runs.DeltaBox(b, ctx)
    assertTrue(topColor == color, "the top's lead and the tied run's 0.0% share one green")
    assertFalse(top)
    assertEqual(select(3, Runs.DeltaBox(a, nil)), false, "no context: a dash, no badge")
    assertEqual(Runs.Leaders({}), nil)
end)

test("results: the detail's Delta box follows the Runs view's grouping and filters while the run is shown", function()
    local i = inst()
    seed(i, {
        mkRun("cleave", { result = { damage = 1, dps = 300000 } }),
        mkRun("cleave2", { result = { damage = 1, dps = 150000 }, date = NOW - 2 * HOUR }),
        mkRun("boss", { target = { category = "boss", count = 1 }, result = { damage = 1, dps = 100000 },
                        date = NOW - 3 * HOUR }),
        mkRun("boss2", { target = { category = "boss", count = 1 }, result = { damage = 1, dps = 50000 },
                         date = NOW - 4 * HOUR }),
    })
    i.R.Show()
    local pane = runsPane(i)
    i.R.ShowRun("boss")
    local d = ui(i).detail
    local text, _, badge = deltaBox(i)
    assertEqual(text, "-66.7%", "Group: None: against the whole view's max")
    assertFalse(badge)
    local tip = i.NS.ResultsTips.Detail("delta", d.run, d.deltaCtx)
    assertEqual(tip[1], "Delta")
    assertEqual(tip[2], "Against the max DPS in the Runs list's whole view.")
    assertEqual(tip[3], "The max: 300,000 DPS.")
    pane:SetFilter("group", "target")
    text, _, badge = deltaBox(i)
    assertEqual(text, "+100.0%", "regrouped: the boss-level group's top, redrawn with no click")
    assertTrue(badge)
    tip = i.NS.ResultsTips.Detail("delta", d.run, d.deltaCtx)
    assertEqual(tip[2], "This run's lead over the runner-up in its group in the Runs list.")
    assertEqual(tip[3], "The runner-up: 50,000 DPS.")
    assertEqual(tip[4], "Recomputed whenever the Runs list's filters or grouping change.")
    assertEqual(i.NS.ResultsTips.Detail("badge", d.run, d.deltaCtx)[2],
        "The highest DPS among the complete runs in its group in the Runs list.")
    pane:SetFilter("group", "none")
    assertEqual((deltaBox(i)), "-66.7%", "back to None")
    pane:SetFilter("category", "boss")
    text, _, badge = deltaBox(i)
    assertEqual(text, "+100.0%", "a filter that leaves the boss-level runs alone in view")
    assertTrue(badge)
    -- The view hands the detail its own figures, and nothing lands on a run.
    local ctx = pane:DeltaContext(d.run)
    assertEqual(ctx, d.deltaCtx)
    assertEqual(ctx.first.id, "boss")
    assertEqual(ctx.second.id, "boss2")
    for _, run in pairs(i.NS.db.global.runs) do
        for _, key in ipairs({ "delta", "top", "group", "context" }) do assertEqual(run[key], nil, key) end
    end
end)

test("results: a run the Runs filters leave out falls back to its board among every stored run", function()
    local i = inst()
    seed(i, {
        mkRun("mine", { result = { damage = 1, dps = 400000 } }),
        mkRun("mage1", { char = "mage", result = { damage = 1, dps = 300000 }, date = NOW - 2 * HOUR }),
        mkRun("mage2", { char = "mage", result = { damage = 1, dps = 200000 }, date = NOW - 3 * HOUR }),
        mkRun("mage30", { char = "mage", race = { length = 30, grace = 1 }, result = { damage = 1, dps = 900000 },
                          date = NOW - 4 * HOUR }),
    })
    i.R.Show()
    local pane = runsPane(i)
    assertEqual(visibleIDs(pane), "mine", "the mage's runs are out of the current-character view")
    i.R.ShowRun("mage2")
    local d = ui(i).detail
    assertEqual(pane:DeltaContext(d.run), nil, "not in the list")
    assertEqual(d.deltaCtx.scope, "board")
    local text, _, badge = deltaBox(i)
    assertEqual(text, "-33.3%", "against its board's top (Fire, cleave, 3:00): not Lanfear's run, not the 0:30 one")
    assertFalse(badge)
    local tip = i.NS.ResultsTips.Detail("delta", d.run, d.deltaCtx)
    assertEqual(tip[#tip], "The Runs list's filters leave this run out, so it is measured on its board.")
    i.R.ShowRun("mage1")
    text, _, badge = deltaBox(i)
    assertEqual(text, "+50.0%")
    assertTrue(badge)
    -- Shown in the list again, it reads the view's group.
    pane:SetFilter("char", "all")
    assertEqual(d.deltaCtx.scope, "view")
    assertEqual((deltaBox(i)), "-66.7%", "now against the whole view's max, the 0:30 run's 900,000")
end)
