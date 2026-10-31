-- tests/test_bar_style.lua — the styled bars (the owner's request of 2026-10-31): one blue from one
-- source, the compare's brighter shades, and a Fill, Background and Border of their own on every bar
-- (modules/Hud_Appearance.lua's Styled, PaintTrack and PaintEdge; settings/OptionsSetup.lua's
-- NS.BarStyleRows; the v8 step in core/Database.lua).
--
-- What this pins:
--   - the pace bar's blue is every blue bar's default, by value and by opacity, each block its own copy;
--   - the compare's two defaults are the old hues, brighter, and the side rule did not move;
--   - each surface draws its own block: a change to one reaches it and no other, live;
--   - the defaults draw what shipped: the two skin tracks and no border; a table or compare track of
--     no opacity;
--   - a border draws only when asked, the skin's while its companion is on, and goes again;
--   - Defaults, a profile copy and a profile reset reach the new rows;
--   - the v8 step carries a stored fill to the detail and holds a partial swatch still.

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
    i.R, i.A = i.NS.Results, i.NS.HudAppearance
    return i
end

local function mkRun(id, dps, spells)
    return {
        id = id, schema = 1, status = "complete", addon = "0.1.0", date = NOW - 3600,
        race = { length = 180, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction" },
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 180, dps = dps, tail = 2 }, flags = { lateCasts = {} },
        spells = spells, note = "",
    }
end

-- Two runs seeded, the weaker open and compared: `d` the detail, `x` its compare parts.
local function compared(i)
    i.NS.db.global.runs.a = mkRun("a", 80, { { id = 1, dmg = 10000 }, { id = 2, dmg = 30000 } })
    i.NS.db.global.runs.b = mkRun("b", 100, { { id = 1, dmg = 20000 }, { id = 2, dmg = 20000 } })
    i.NS.Bests.Invalidate()
    i.R.ShowRun("a")
    local d = i.R.__ui().detail
    d:SetComparing(true)
    return d, d.cmp
end

local function eachBlue(profile, fn)
    fn(profile.appearance.bars, "the HUD's spell rows")
    fn(profile.appearance.pace, "the pace bar")
    fn(profile.appearance.chart, "the chart")
    fn(profile.resultsDetail.spellBars, "the detail's spell rows")
    fn(profile.resultsTable.damageBar, "the Damage bar")
    fn(profile.resultsTable.dpsBar, "the DPS bar")
end

-- ── the defaults ────────────────────────────────────────────────────────────────────────────────

test("bar style: the pace bar's blue is every blue bar's default, by value and opacity, each a copy", function()
    local P = T.NS.defaults.profile
    local pace = P.appearance.pace
    assertEqual(pace.barColor.r, 0.36, "the pace bar's own value")
    assertEqual(pace.barColor.g, 0.37)
    assertEqual(pace.barColor.b, 0.84)
    assertEqual(pace.barAlpha, 0.9)
    eachBlue(P, function(block, what)
        assertEqual(block.barColor.r, pace.barColor.r, what)
        assertEqual(block.barColor.g, pace.barColor.g, what)
        assertEqual(block.barColor.b, pace.barColor.b, what)
        assertEqual(block.barColor.a, pace.barColor.a, what)
        assertEqual(block.barAlpha, pace.barAlpha, what)
        assertEqual(block.barTexture, pace.barTexture, what)
        assertEqual(block.barTextureFromSkin, true, what)
        assertTrue(block == pace or block.barColor ~= pace.barColor, what .. " shares the table")
    end)
end)

-- A color's hue in degrees (blue or yellow here, so no wrap to handle).
local function hue(r, g, b)
    local hi, lo = math.max(r, g, b), math.min(r, g, b)
    local d = hi - lo
    if hi == r then return 60 * ((g - b) / d) end
    if hi == g then return 60 * (2 + (b - r) / d) end
    return 60 * (4 + (r - g) / d)
end

test("bar style: the compare's defaults are the old hues, brighter, opaque and flat", function()
    local C = T.NS.defaults.profile.compare
    local function check(block, r, g, b, what)
        local c = block.barColor
        assertEqual(math.floor(c.r * 255 + 0.5), r, what)
        assertEqual(math.floor(c.g * 255 + 0.5), g, what)
        assertEqual(math.floor(c.b * 255 + 0.5), b, what)
        assertEqual(block.barAlpha, 1, what)
        assertEqual(block.barTexture, "Solid", what)
        assertEqual(block.barTextureFromSkin, false, what .. ": a skin's texture would darken it")
    end
    check(C.best, 42, 70, 107, "best")
    check(C.other, 83, 69, 0, "other")
    assertTrue(math.abs(hue(C.best.barColor.r, C.best.barColor.g, C.best.barColor.b) - hue(32, 54, 82)) < 1)
    assertTrue(math.abs(hue(C.other.barColor.r, C.other.barColor.g, C.other.barColor.b) - hue(64, 53, 0)) < 1)
    assertTrue(C.best.barColor.b > 82 / 255 and C.other.barColor.r > 64 / 255, "brighter than they shipped")
end)

test("bar style: the default look keeps the skin's two tracks and draws no border", function()
    local i = inst()
    local A, Style = i.A, i.NS.Style
    local spell, pace = A.Bar(), A.Pace()
    local r, g, b, a = Style.Rgba("dr.list.track")
    assertEqual(spell.bg.r, r); assertEqual(spell.bg.g, g); assertEqual(spell.bg.b, b); assertEqual(spell.bg.a, a)
    assertEqual(A.Bar("window").bg.a, a, "the detail's the same token")
    assertEqual(pace.bg.a, select(4, Style.Rgba("dr.chart.grid")), "the pace bar's own track")
    assertEqual(spell.border, nil, "Ka0s Default's bar.borderStyle is None")
    assertEqual(pace.border, nil)
    assertEqual(A.Bar("window").border, nil)
end)

-- ── each surface its own block ──────────────────────────────────────────────────────────────────

test("bar style: the HUD's and the detail's spell rows are separate blocks, live", function()
    local i = inst()
    local A, NS = i.A, i.NS
    assertEqual(A.Bar().r, A.Bar("window").r, "they start equal")
    assertTrue(NS.SetByPath("resultsDetail.spellBars.barColor", { r = 0.1, g = 0.2, b = 0.3, a = 1 }))
    assertEqual(A.Bar("window").r, 0.1)
    assertEqual(A.Bar().r, 0.36, "the HUD's rows did not move")
    local stamp = A.stamp
    assertTrue(NS.SetByPath("appearance.bars.barColor", { r = 0.4, g = 0.5, b = 0.6, a = 1 }))
    assertTrue(A.stamp > stamp, "the row restyles")
    assertEqual(A.Bar("window").r, 0.1, "the detail's rows did not move")
end)

test("bar style: the detail's spell rows draw their block, track and border", function()
    local i = inst()
    i.NS.db.global.runs.a = mkRun("a", 80, { { id = 1, dmg = 10000 } })
    i.NS.Bests.Invalidate()
    i.R.ShowRun("a")
    local row = i.R.__ui().detail.w.list.rows[1]
    assertEqual(row.bar.__barColor[1], 0.36, "the blue")
    assertEqual(row.bar.__barColor[4], 0.9)
    assertEqual(row.track.__colorTex[4], select(4, i.NS.Style.Rgba("dr.list.track")))
    assertEqual(row.edge, nil, "no border frame until one is asked for")
    assertTrue(i.NS.SetByPath("resultsDetail.spellBars.bgFromSkin", false))
    assertTrue(i.NS.SetByPath("resultsDetail.spellBars.bgColor", { r = 0, g = 1, b = 0, a = 0.5 }))
    assertTrue(i.NS.SetByPath("resultsDetail.spellBars.barColor", { r = 1, g = 0, b = 0, a = 1 }))
    assertTrue(i.NS.SetByPath("resultsDetail.spellBars.borderStyleFromSkin", false))
    assertTrue(i.NS.SetByPath("resultsDetail.spellBars.borderStyle", "Solid"))
    assertTrue(i.NS.SetByPath("resultsDetail.spellBars.borderSize", 2))
    assertTrue(i.NS.SetByPath("resultsDetail.spellBars.borderColor", { r = 0, g = 0, b = 1, a = 1 }))
    row = i.R.__ui().detail.w.list.rows[1]
    assertEqual(row.bar.__barColor[1], 1, "live, no reload")
    assertEqual(row.track.__colorTex[2], 1)
    assertEqual(row.track.__colorTex[4], 0.5)
    assertTrue(row.edge ~= nil and row.edge:IsShown(), "the border")
    assertEqual(row.edge.__borderColor[3], 1)
    assertTrue(i.NS.SetByPath("resultsDetail.spellBars.borderSize", 0))
    assertFalse(i.R.__ui().detail.w.list.rows[1].edge:IsShown(), "no thickness, no border")
end)

test("bar style: the pace bar draws its block's track and border, keeping its green", function()
    local i = inst()
    local pace = i.NS.HudChart.NewPace(i.mocks.CreateFrame("Frame"))
    assertEqual(pace.track.__colorTex[4], select(4, i.NS.Style.Rgba("dr.chart.grid")), "painted when built")
    assertEqual(pace.behind.__barColor[3], 0.84)
    assertTrue(i.NS.SetByPath("appearance.pace.bgFromSkin", false))
    assertTrue(i.NS.SetByPath("appearance.pace.bgColor", { r = 1, g = 0, b = 0, a = 0.5 }))
    assertTrue(i.NS.SetByPath("appearance.pace.borderStyleFromSkin", false))
    assertTrue(i.NS.SetByPath("appearance.pace.borderStyle", "Solid"))
    pace:SetRange(0, 100)
    assertEqual(pace.track.__colorTex[1], 1)
    assertTrue(pace.edge:IsShown())
    assertEqual(pace.ahead.__barColor[2], 0.86, "the ahead half's green is no block's")
end)

test("bar style: the table's two bars are separate blocks; a track and a border span the cell", function()
    local i = inst()
    i.NS.db.global.runs.a = mkRun("a", 80, { { id = 1, dmg = 10000 } })
    i.NS.Bests.Invalidate()
    i.R.Show()
    local NS = i.NS
    local style = NS.ResultsRuns.BarStyle("damageBar", NS.db.global.runs.a)
    assertEqual(style.bg.a, 0, "no track by default")
    assertEqual(style.border, nil, "no border by default")
    assertTrue(NS.SetByPath("resultsTable.damageBar.bgColor", { r = 1, g = 1, b = 0, a = 0.3 }))
    assertTrue(NS.SetByPath("resultsTable.damageBar.useClassColorBorder", true))
    assertTrue(NS.SetByPath("resultsTable.damageBar.borderStyleFromSkin", false))
    assertTrue(NS.SetByPath("resultsTable.damageBar.borderStyle", "Solid"))
    style = NS.ResultsRuns.BarStyle("damageBar", NS.db.global.runs.a)
    local warlock = i.mocks.RAID_CLASS_COLORS.WARLOCK
    assertEqual(style.bg.a, 0.3)
    assertEqual(style.border.r, warlock.r, "the run's character's class")
    assertEqual(NS.ResultsRuns.BarStyle("dpsBar", NS.db.global.runs.a).bg.a, 0, "the DPS bar's own")
    assertEqual(NS.ResultsRuns.BarStyle("dpsBar", NS.db.global.runs.a).border, nil)
end)

test("bar style: a compare column draws its block; the side rule did not move", function()
    local i = inst()
    local _, x = compared(i)
    local NS = i.NS
    assertEqual(x.bars.best, "other", "the board's best holds the other column")
    local C = NS.defaults.profile.compare
    assertEqual(x.bars.looks.other.r, C.best.barColor.r, "the best's column, the best's block")
    assertEqual(x.bars.looks.this.r, C.other.barColor.r)
    assertEqual(x.lines[1].bar.__vertex[3], C.best.barColor.b)
    assertEqual(x.lines[1].bar.__vertex[4], 1)
    local track = x.lines[1].bar.tracks.other
    assertEqual(track.__colorTex[4], 0, "no track by default")
    assertTrue(NS.SetByPath("compare.best.barColor", { r = 0.5, g = 0.25, b = 0.75, a = 1 }))
    assertTrue(NS.SetByPath("compare.best.barAlpha", 0.5))
    assertTrue(NS.SetByPath("compare.best.bgFromSkin", true))
    assertTrue(NS.SetByPath("compare.other.borderStyleFromSkin", false))
    assertTrue(NS.SetByPath("compare.other.borderStyle", "Solid"))
    assertEqual(x.lines[1].bar.__vertex[1], 0.5, "live, no reload")
    assertEqual(x.lines[1].bar.__vertex[4], 0.5)
    assertEqual(track.__colorTex[4], select(4, NS.Style.Rgba("dr.list.track")), "the best's track, the skin's")
    assertEqual(x.lines[1].bar.tracks.this.__colorTex[4], 0, "the other column's own")
    assertTrue(x.lines[1].bar.tracks.this.edge:IsShown(), "the other block's border, in its column")
    assertEqual(track.edge, nil, "and none in the best's")
end)

test("bar style: a border follows the skin's bar.borderStyle while its companion is on", function()
    local i = inst()
    local NS, A = i.NS, i.A
    local real = NS.Skin.Resolve
    NS.Skin.Resolve = function(token, v, on)
        if token == "bar.borderStyle" then return "flat" end
        return real(token, v, on)
    end
    assertTrue(A.Bar().border ~= nil, "the skin's border, thickness and color the player's")
    assertEqual(A.Bar().border.size, 1)
    assertTrue(NS.SetByPath("appearance.bars.borderStyleFromSkin", false))
    assertEqual(A.Bar().border, nil, "off, the stored None")
    NS.Skin.Resolve = real
end)

test("bar style: a border key LSM cannot answer draws no border", function()
    local i = inst()
    assertTrue(i.NS.SetByPath("appearance.bars.borderStyleFromSkin", false))
    assertTrue(i.NS.SetByPath("appearance.bars.borderStyle", "No such border"))
    assertEqual(i.A.Bar().border, nil)
end)

test("bar style: a skin switch moves a skin track and leaves a swatch", function()
    local i = inst()
    local A, NS = i.A, i.NS
    local real = NS.Style.Rgba
    NS.Style.Rgba = function(c, a)
        if c == "dr.list.track" then return 0.5, 0.5, 0.5, 0.2 end
        return real(c, a)
    end
    assertEqual(A.Bar().bg.a, 0.2, "read at call time")
    assertTrue(NS.SetByPath("appearance.bars.bgFromSkin", false))
    assertEqual(A.Bar().bg.a, 0.04, "the swatch waits under the companion")
    NS.Style.Rgba = real
end)

-- ── the rows ────────────────────────────────────────────────────────────────────────────────────

test("bar style: every styled bar's media rows are composed pickers, on the page that draws them", function()
    local NS = T.NS
    local function row(path)
        for _, r in ipairs(NS.Schema) do if r.path == path then return r end end
    end
    for prefix, page in pairs({ ["appearance.bars."] = "hud", ["appearance.pace."] = "hud",
        ["resultsTable.damageBar."] = "history", ["resultsTable.dpsBar."] = "history",
        ["resultsDetail.spellBars."] = "history", ["compare.best."] = "history", ["compare.other."] = "history" }) do
        assertEqual(row(prefix .. "barTexture").dialogControl, "LSM30_Statusbar", prefix)
        assertEqual(row(prefix .. "borderStyle").dialogControl, "LSM30_Border", prefix)
        assertEqual(row(prefix .. "borderStyle").page, page, prefix)
        assertEqual(row(prefix .. "bgColor").composed, true, prefix)
        assertEqual(row(prefix .. "bgFromSkin").composed, nil, prefix .. ": the addon's own words")
        assertEqual(row(prefix .. "bgFromSkin").label, "Use the skin's background", prefix)
    end
end)

test("bar style: History holds the Run detail tab after Results table, Fill before Background and Border", function()
    local groups, subs, last = {}, {}, nil
    for _, r in ipairs(T.NS.SchemaForPage("history")) do
        if r.group ~= last then groups[#groups + 1] = r.group; last = r.group end
        if r.group == "Run detail" and subs[#subs] ~= r.subgroup then subs[#subs + 1] = r.subgroup end
    end
    assertEqual(table.concat(groups, ","), "History,Results table,Run detail,Usage")
    assertEqual(table.concat(subs, ","), table.concat({ "Spell bars", "Spell bar background", "Spell bar border",
        "Best run bar", "Best run bar background", "Best run bar border",
        "Other run bar", "Other run bar background", "Other run bar border" }, ","))
end)

test("bar style: a page's Defaults, a profile reset and a profile copy reach the new rows", function()
    local i = inst()
    local NS = i.NS
    assertTrue(NS.SetByPath("compare.other.barAlpha", 0.3))
    assertTrue(NS.SetByPath("compare.best.borderSize", 4))
    assertTrue(NS.ApplyDefault(NS.FindSchemaRow("compare.other.barAlpha")))
    assertEqual(NS.GetSetting("compare.other.barAlpha"), 1, "Defaults")
    assertTrue(NS.SetByPath("compare.other.barAlpha", 0.3))
    NS.db:SetProfile("Copy")
    assertEqual(NS.GetSetting("compare.other.barAlpha"), 1, "a new profile reads the default")
    NS.db:CopyProfile("Default")
    assertEqual(NS.GetSetting("compare.other.barAlpha"), 0.3, "a copy carries the value")
    assertEqual(NS.GetSetting("compare.best.borderSize"), 4)
    NS.db:ResetProfile()
    assertEqual(NS.GetSetting("compare.other.barAlpha"), 1, "a reset clears it")
    assertEqual(NS.GetSetting("compare.best.borderSize"), 1)
end)

-- ── the v8 step ─────────────────────────────────────────────────────────────────────────────────

local function migrated(profiles)
    local i = T.load({ init = false })
    _G.DpsRaceDB = { global = { schemaVersion = 7, schema = 4 }, profiles = profiles }
    i.mocks._G.DpsRaceDB = _G.DpsRaceDB
    i.NS:InitDB()
    i.NS:RunMigrations()
    return i
end

test("bar style: v8 copies a stored spell-bar fill to the detail, and a bare profile stays bare", function()
    local color = { r = 0.1, g = 0.2, b = 0.3, a = 1 }
    local custom = { appearance = { bars = { barTexture = "Blizzard", barTextureFromSkin = false, barAlpha = 0.5,
        barColor = color, useClassColorBar = true, rowHeight = 22 } } }
    local bare, other = {}, { appearance = { figures = { fontSize = 22 } } }
    local i = migrated({ Custom = custom, Bare = bare, Other = other })
    assertEqual(i.NS.db.global.schemaVersion, i.NS.SCHEMA_VERSION)
    local d = custom.resultsDetail.spellBars
    assertEqual(d.barTexture, "Blizzard")
    assertEqual(d.barTextureFromSkin, false)
    assertEqual(d.barAlpha, 0.5)
    assertEqual(d.useClassColorBar, true)
    assertEqual(d.barColor.g, 0.2)
    assertTrue(d.barColor ~= color, "the two blocks share no table")
    assertEqual(d.rowHeight, nil, "the row height stays the HUD's block's")
    assertEqual(custom.appearance.bars.barAlpha, 0.5, "the HUD's block keeps its own")
    assertEqual(next(bare), nil, "an untouched profile reads the new defaults")
    assertEqual(other.resultsDetail, nil)
end)

test("bar style: v8 holds a partly stripped swatch at the color the player saw", function()
    local p = { appearance = { bars = { barColor = { r = 0.9 } } },
                resultsTable = { damageBar = { barColor = { b = 0.1 } }, dpsBar = { barAlpha = 0.4 } } }
    migrated({ P = p })
    local c = p.appearance.bars.barColor
    assertEqual(c.r, 0.9); assertEqual(c.g, 0.29); assertEqual(c.b, 0.45)
    assertEqual(p.resultsDetail.spellBars.barColor.g, 0.29, "the detail's copy too")
    local t = p.resultsTable.damageBar.barColor
    assertEqual(t.r, 0.29); assertEqual(t.b, 0.1)
    assertEqual(p.resultsTable.dpsBar.barColor, nil, "no swatch stored, none written")
end)

test("bar style: v8 runs once: a later pick on the detail's block is kept", function()
    local p = { appearance = { bars = { barAlpha = 0.5 } } }
    local i = migrated({ P = p })
    p.resultsDetail.spellBars.barAlpha = 0.7
    i.NS:RunMigrations()
    assertEqual(p.resultsDetail.spellBars.barAlpha, 0.7)
end)
