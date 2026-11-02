-- tests/test_skin_flip.lua — the HUD follows the skin in full (FS-DR-FLIP, causes D2, D4 and D6 of
-- Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING/): text colors, the chart's background, border
-- colors and thickness, and every shadow, each with a companion on by default, and the one step that
-- moves existing profiles (LibKa0s Options doc, Moving to, section 4).
--
-- What this pins:
--   - each new companion is a row in the addon's words, default on in both places, and no row's
--     pick still defaults to a client face or texture;
--   - Ka0s Default draws the pixels the addon drew: its own figures color, the chart's dark wash and
--     its shadows, through owner tokens that follow the skin;
--   - a skin switch moves what is DRAWN (spies on the setters), a shadow behind the stamps included;
--   - class color comes first, and the clocks' meaning colors and the bar fills stay (MC, A9);
--   - the step, over stored partial profiles: every listed companion true, picks and colors
--     byte-identical, no "@skin" but the flags named, class colors and the two ignores unchanged,
--     idempotent, and a companion turned off later stays off through every Defaults path.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local TEXT_BLOCKS = { "appearance.figures.", "appearance.spellText.", "resultsTable.barText." }
local CLOCKS = { "appearance.elapsed.", "appearance.left." }
local STYLED = { "appearance.bars.", "appearance.pace.", "resultsTable.damageBar.", "resultsTable.dpsBar.",
                 "resultsDetail.spellBars.", "compare.best.", "compare.other." }

local function defaultAt(NS, path)
    local t = NS.defaults.profile
    for part in path:gmatch("[^.]+") do t = type(t) == "table" and t[part] or nil end
    return t
end

local function rgb(r, g, b) return ("%.3f,%.3f,%.3f"):format(r, g, b) end

--- A skin other than Ka0s Default whose token `name` differs from Ka0s Default's.
local function otherSkin(inst, name)
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    local base = Skin:ResolveSkin("ka0s")[name]
    for _, def in ipairs(Skin:Skins()) do
        local v = Skin:ResolveSkin(def.key)[name]
        if def.key ~= "ka0s" and type(v) == "table"
            and (type(base) ~= "table" or rgb(v[1], v[2], v[3]) ~= rgb(base[1], base[2], base[3])) then
            return def.key
        end
    end
    error("no shipped skin moves " .. name)
end

local function switch(inst, key)
    inst.NS.ApplySkinChoice("ka0s", key)
    inst.mocks.__fireTimers()
end

--- A FontString that remembers every draw (S.HudFont lands on it: the mock has no CreateFont).
local function spyString()
    local d = {}
    return {
        drawn = d,
        GetObjectType = function() return "FontString" end,
        SetFont = function(_, face, size, flags) d.face, d.size, d.flags = face, size, flags end,
        SetShadowColor = function(_, r, g, b, a) d.sr, d.sg, d.sb, d.sa = r, g, b, a end,
        SetShadowOffset = function(_, x, y) d.x, d.y = x, y end,
        SetTextColor = function(_, r, g, b, a) d.r, d.g, d.b, d.a = r, g, b, a end,
        SetFontObject = function() end,
    }
end

-- ── the rows and the defaults ───────────────────────────────────────────────────────────────────

test("skin flip: every new companion is a row in the addon's words, on in both places", function()
    local NS = T.NS
    local function check(path, label)
        local r = NS.FindSchemaRow(path)
        assertTrue(r ~= nil, "no row: " .. path)
        assertEqual(r.type, "bool", path)
        assertEqual(r.default, true, path .. " row default")
        assertEqual(defaultAt(NS, path), true, path .. " AceDB default")
        assertEqual(r.label, label, path)
        assertEqual(r.composed, nil, path .. ": the addon's own words")
        assertEqual(type(r.onChange), "function", path .. " redraws")
    end
    for _, p in ipairs(TEXT_BLOCKS) do
        check(p .. "fontColorFromSkin", "Use the skin's color")
        check(p .. "fontShadowFromSkin", "Use the skin's shadow")
    end
    for _, p in ipairs(CLOCKS) do
        check(p .. "fontShadowFromSkin", "Use the skin's shadow")
        assertEqual(NS.FindSchemaRow(p .. "fontColorFromSkin"), nil, p .. ": a meaning color has no companion")
    end
    for _, p in ipairs(STYLED) do check(p .. "borderColorFromSkin", "Use the skin's color") end
    check("appearance.chart.bgFromSkin", "Use the skin's background")
end)

test("skin flip: a swatch stays live under its companion, and the border governs its thickness", function()
    local NS = T.NS
    assertEqual(NS.FindSchemaRow("appearance.figures.fontColor").disabledIf, nil, "options-ui-§17")
    for _, p in ipairs(STYLED) do
        assertEqual(NS.FindSchemaRow(p .. "borderColor").disabledIf, nil, p)
        assertEqual(type(NS.FindSchemaRow(p .. "borderSize").disabledIf), "function", p .. ": a skin's None defers")
    end
end)

test("skin flip: the picks' defaults are the Ka0s picks, the clocks' mono face and the fills kept", function()
    local NS = T.NS
    for _, p in ipairs(TEXT_BLOCKS) do assertEqual(defaultAt(NS, p .. "font"), "Ka0s Prototype", p) end
    for _, p in ipairs(CLOCKS) do assertEqual(defaultAt(NS, p .. "font"), "JetBrains Mono", p) end
    for _, p in ipairs(STYLED) do assertEqual(defaultAt(NS, p .. "barTexture"), "Ka0s Default", p) end
    assertEqual(defaultAt(NS, "appearance.chart.barTexture"), "Ka0s Default")
    assertEqual(NS.FindSchemaRow("appearance.bars.barColorFromSkin"), nil, "bar fills stay the owner's (A9)")
    assertEqual(NS.defaults.profile.skin.ignorePanel, true, "the settings panel stays stock")
    assertEqual(NS.defaults.profile.skin.ignoreFonts, false)
end)

-- ── what draws ──────────────────────────────────────────────────────────────────────────────────

test("skin flip: Ka0s Default draws the addon's own pixels", function()
    local NS = T.load().NS
    local A = NS.HudAppearance
    local fig = spyString()
    A.ApplyFont(fig, A.Font("figures"))
    assertEqual(rgb(fig.drawn.r, fig.drawn.g, fig.drawn.b), rgb(0.93, 0.93, 0.95), "the figures' own gray")
    assertEqual(fig.drawn.x, 1, "the shadow the block stores, though Ka0s Default's hud.shadow is off")
    assertEqual(fig.drawn.y, -1)
    assertEqual(fig.drawn.sa, 1)
    local text = spyString()
    A.ApplyFont(text, A.Font("spellText"))
    assertEqual(rgb(text.drawn.r, text.drawn.g, text.drawn.b), rgb(1, 1, 1))
    assertEqual(text.drawn.x, 1)
    local clock = spyString()
    A.ApplyFont(clock, A.Font("elapsed"))
    assertEqual(rgb(clock.drawn.r, clock.drawn.g, clock.drawn.b), rgb(0.36, 0.86, 0.46), "a meaning color")
    assertEqual(clock.drawn.x, 0, "no clock shadow under Ka0s Default")
    local bg = A.ChartBackground()
    assertEqual(rgb(bg.r, bg.g, bg.b), rgb(0, 0, 0), "the chart's dark wash")
    assertEqual(bg.a, 0.35)
end)

test("skin flip: a switch moves each text's drawn color and shadow; the clocks' color stays", function()
    local inst = T.load()
    local NS = inst.NS
    local A = NS.HudAppearance
    switch(inst, otherSkin(inst, "hud.text"))
    local Skin = NS.Skin
    local want = { Skin.HudTextColor() }
    local sx, sy, sr, sg, sb, sa = Skin.HudShadow()
    for _, block in ipairs({ "figures", "spellText" }) do
        local fs = spyString()
        A.ApplyFont(fs, A.Font(block))
        assertEqual(rgb(fs.drawn.r, fs.drawn.g, fs.drawn.b), rgb(want[1], want[2], want[3]), block .. " in hud.text")
        assertEqual(fs.drawn.x, sx, block); assertEqual(fs.drawn.y, sy, block)
        assertEqual(rgb(fs.drawn.sr, fs.drawn.sg, fs.drawn.sb), rgb(sr, sg, sb), block .. "'s shadow is the skin's")
        assertEqual(fs.drawn.sa, sa, block)
    end
    local clock = spyString()
    A.ApplyFont(clock, A.Font("left"))
    assertEqual(rgb(clock.drawn.r, clock.drawn.g, clock.drawn.b), rgb(1, 0.32, 0.32), "a meaning color stays")
    assertEqual(clock.drawn.x, sx, "a clock's shadow follows")
    local fs = spyString()
    A.ApplyFont(fs, A.FontAt("resultsTable.barText.", NS.defaults.profile.resultsTable.barText, nil, "window"))
    assertEqual(rgb(fs.drawn.r, fs.drawn.g, fs.drawn.b), rgb(want[1], want[2], want[3]), "the Runs bar text")
end)

test("skin flip: companions off draw the stored value under every skin", function()
    local inst = T.load()
    local NS = inst.NS
    local A = NS.HudAppearance
    assertTrue(NS.SetByPath("appearance.figures.fontColor", { r = 0.1, g = 0.2, b = 0.3, a = 1 }))
    assertTrue(NS.SetByPath("appearance.figures.fontColorFromSkin", false))
    assertTrue(NS.SetByPath("appearance.figures.fontShadowFromSkin", false))
    assertTrue(NS.SetByPath("appearance.figures.fontShadow", false))
    switch(inst, otherSkin(inst, "hud.text"))
    local fs = spyString()
    A.ApplyFont(fs, A.Font("figures"))
    assertEqual(rgb(fs.drawn.r, fs.drawn.g, fs.drawn.b), rgb(0.1, 0.2, 0.3))
    assertEqual(fs.drawn.x, 0, "the stored none")
    assertTrue(NS.SetByPath("appearance.figures.fontShadow", true))
    A.ApplyFont(fs, A.Font("figures"))
    assertEqual(fs.drawn.x, 1, "the stored shadow")
    assertEqual(rgb(fs.drawn.sr, fs.drawn.sg, fs.drawn.sb), rgb(0, 0, 0), "in the client's black")
end)

test("skin flip: Ignore fonts stands a followed shadow down to the stored one", function()
    local inst = T.load()
    local NS, A = inst.NS, inst.NS.HudAppearance
    switch(inst, otherSkin(inst, "hud.text"))
    assertTrue(NS.SetByPath("skin.ignoreFonts", true))
    assertTrue(NS.SetByPath("appearance.spellText.fontShadow", false))
    local fs = spyString()
    A.ApplyFont(fs, A.Font("spellText"))
    assertEqual(fs.drawn.x, 0, "the stored none")
    local r, g, b = NS.Skin.HudTextColor()
    assertEqual(rgb(fs.drawn.r, fs.drawn.g, fs.drawn.b), rgb(r, g, b), "the skin still colors it")
end)

test("skin flip: a block with its own shadow takes the skin's offset, and Ignore fonts the stored one", function()
    local inst = T.load()
    local NS, A = inst.NS, inst.NS.HudAppearance
    switch(inst, "contrast")
    assertEqual(NS.Skin.Token("hud.shadowX"), 2, "the one shipped skin with its own offset")
    local fs = spyString()
    A.ApplyFont(fs, A.Font("figures"))
    assertEqual(fs.drawn.x, 2, "the skin's offset, not the 1, -1 of a stored shadow")
    assertEqual(fs.drawn.y, -2)
    assertTrue(NS.SetByPath("skin.ignoreFonts", true))
    assertTrue(NS.SetByPath("appearance.figures.fontShadow", true))
    A.ApplyFont(fs, A.Font("figures"))
    assertEqual(fs.drawn.x, 1, "the stored shadow, not the skin's")
    assertEqual(fs.drawn.y, -1)
    assertEqual(rgb(fs.drawn.sr, fs.drawn.sg, fs.drawn.sb), rgb(0, 0, 0), "in the client's black")
end)

test("skin flip: a class color comes before every companion", function()
    local inst = T.load({ mutate = function(m) m.RAID_CLASS_COLORS = { WARLOCK = { r = 0.53, g = 0.53, b = 0.93 } } end })
    local NS, A = inst.NS, inst.NS.HudAppearance
    local want = rgb(0.53, 0.53, 0.93)
    assertTrue(NS.SetByPath("resultsTable.barText.useClassColorFont", true))
    local f = A.FontAt("resultsTable.barText.", NS.defaults.profile.resultsTable.barText, "WARLOCK", "window")
    assertEqual(rgb(f.r, f.g, f.b), want, "text")
    assertTrue(NS.SetByPath("compare.best.useClassColorBg", true))
    assertTrue(NS.SetByPath("compare.best.useClassColorBorder", true))
    assertTrue(NS.SetByPath("compare.best.bgFromSkin", true))
    assertTrue(NS.SetByPath("compare.best.borderStyleFromSkin", false))
    assertTrue(NS.SetByPath("compare.best.borderStyle", "Solid"))
    local look = A.Styled("compare.best.", NS.defaults.profile.compare.best, "WARLOCK")
    assertEqual(rgb(look.bg.r, look.bg.g, look.bg.b), want, "background")
    assertEqual(rgb(look.border.r, look.border.g, look.border.b), want, "border")
    -- The chart's class is the player's, which the mock's character leaves to the swatch: the point is
    -- that the skin's token is not what draws.
    assertTrue(NS.SetByPath("appearance.chart.bgColor", { r = 0.2, g = 0.3, b = 0.4, a = 0.6 }))
    assertTrue(NS.SetByPath("appearance.chart.useClassColorBg", true))
    local bg = A.ChartBackground()
    assertEqual(bg.a, 0.6, "the class branch: the swatch's alpha, not the skin's token")
end)

test("skin flip: a border draws the skin's color and thickness while on, the stored ones off", function()
    local inst = T.load()
    local NS, A = inst.NS, inst.NS.HudAppearance
    local p = "resultsDetail.spellBars."
    assertTrue(NS.SetByPath(p .. "borderStyleFromSkin", false))
    assertTrue(NS.SetByPath(p .. "borderStyle", "Solid"))
    assertTrue(NS.SetByPath(p .. "borderColor", { r = 0.9, g = 0.1, b = 0.1, a = 1 }))
    assertTrue(NS.SetByPath(p .. "borderSize", 4))
    local look = A.Bar("window").border
    assertEqual(rgb(look.r, look.g, look.b), rgb(0, 0, 0), "bar.border, the swatch unread")
    assertEqual(look.size, 4, "the style's companion off: the player's thickness")
    assertTrue(NS.SetByPath(p .. "borderColorFromSkin", false))
    look = A.Bar("window").border
    assertEqual(rgb(look.r, look.g, look.b), rgb(0.9, 0.1, 0.1), "the swatch")
    -- A skin's None defers, with the companion on: the stored style at the stored thickness.
    assertTrue(NS.SetByPath(p .. "borderStyleFromSkin", true))
    assertEqual(A.Bar("window").border.size, 4, "Ka0s Default's None leaves the player's")
    -- A skin that names a border: its thickness governs with the style's companion on.
    local real = NS.Skin.BarBorder
    NS.Skin.BarBorder = function(style, show, size, fromSkin)
        if fromSkin then return "Solid", true, 3 end
        return real(style, show, size, fromSkin)
    end
    assertEqual(A.Bar("window").border.size, 3, "the skin's bar.borderSize")
end)

test("skin flip: with no library a stored background draws, its companion on", function()
    -- A degraded S.Color answers an owner default, so a follow read asks S.IsEnabled first (Moving to,
    -- section 3). red under: the skin's track drawn over the player's color.
    local inst = T.load({ libFiles = {} })
    local NS, A = inst.NS, inst.NS.HudAppearance
    NS.GetSetting("appearance.bars.bgColor").r = 0.61
    NS.GetSetting("appearance.chart.bgColor").r = 0.62
    assertEqual(NS.GetSetting("appearance.bars.bgFromSkin"), true)
    assertEqual(A.Bar().bg.r, 0.61, "the spell bars' swatch")
    assertEqual(A.ChartBackground().r, 0.62, "the plot's swatch")
    assertEqual(A.Bar().border, nil, "S.BarBorder's stub answers the stored None")
end)

test("skin flip: every skin but Ka0s Default reads its own bar.bg on a followed track", function()
    local inst = T.load()
    local A = inst.NS.HudAppearance
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    local home = Skin:ResolveSkin("ka0s")["bar.bg"]
    assertEqual(rgb(A.Bar().bg.r, A.Bar().bg.g, A.Bar().bg.b), rgb(1, 1, 1), "Ka0s Default keeps its wash")
    for _, def in ipairs(Skin:Skins()) do
        local bg = Skin:ResolveSkin(def.key)["bar.bg"]
        if def.key ~= "ka0s" and rgb(bg[1], bg[2], bg[3]) ~= rgb(home[1], home[2], home[3]) then
            switch(inst, def.key)
            local b = A.Bar().bg
            assertEqual(rgb(b.r, b.g, b.b), rgb(bg[1], bg[2], bg[3]), def.key)
            b = A.Pace().bg
            assertEqual(rgb(b.r, b.g, b.b), rgb(bg[1], bg[2], bg[3]), def.key .. " pace")
            return
        end
    end
    error("no shipped skin moves bar.bg")
end)

test("skin flip: a gloss draws under a glossy skin, never over a player's texture", function()
    -- Moving to, section 6. mock_paint's StatusBars are the only ones S.BarGloss draws on.
    local installPaint = dofile(T.root .. "/tests/_kit/mock_paint.lua")
    local inst = T.load({ mutate = function(m) installPaint(m) end })
    local NS = inst.NS
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    local key
    for _, def in ipairs(Skin:Skins()) do
        if Skin:ResolveSkin(def.key)["bar.gloss"] == true then key = def.key; break end
    end
    assertTrue(key ~= nil, "a shipped skin has a gloss")
    local bar = inst.mocks.CreateFrame("StatusBar")
    bar:SetStatusBarTexture("x")
    switch(inst, key)
    local rec = function() return Skin.painted[bar] end
    NS.Skin.BarGloss(bar, true)
    local gloss = assert(rec().regions.gloss, "drawn under the skin's texture")
    assertTrue(gloss:IsShown())
    NS.Skin.BarGloss(bar, false)
    assertFalse(gloss:IsShown(), "a player's own texture stays plain")
end)

test("skin flip: the real S.BarBorder draws a shipped skin's style over a stored None", function()
    local inst = T.load()
    local A = inst.NS.HudAppearance
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    local key, tokens
    for _, def in ipairs(Skin:Skins()) do
        local t = Skin:ResolveSkin(def.key)
        if t["bar.borderStyle"] == "Solid" then key, tokens = def.key, t; break end
    end
    assertTrue(key ~= nil, "a shipped skin states a Solid bar border")
    assertEqual(A.Bar().border, nil, "Ka0s Default's None over the stored None")
    switch(inst, key)
    assertEqual(A.Bar().border.size, tokens["bar.borderSize"], "a real style wins")
end)

--- A running HUD with the recorder's widgets.
local function hud()
    local W
    local f = RaceClock.new{ mutate = function(m) W = Widgets.install(m) end }
    f.W = W
    f.NS.Slices.Reset()
    assertTrue(f:arm(30))
    f:start(25)
    f.NS.Hud.Tick()
    return f
end

local function runningBody(f)
    local u = assert(f.NS.Hud.__ui(), "the HUD window was never built")
    return u.body[u.current]
end

test("skin flip: a switch repaints the running HUD's strings and plot past their stamps", function()
    -- The stamps sit in front of S.HudFont (Moving to, section 5): the skin's looks-changed path bumps
    -- them, so a string that already drew redraws. red under: Style's listener not reaching Changed.
    local f = hud()
    local w = runningBody(f).w
    local colored, shadow, plot
    rawset(w.damage.value, "SetTextColor", function(_, r, g, b) colored = rgb(r, g, b) end)
    rawset(w.damage.value, "SetShadowColor", function(_, r, g, b) shadow = rgb(r, g, b) end)
    rawset(w.chart.plot, "SetBackdropColor", function(_, r, g, b) plot = rgb(r, g, b) end)
    local key = otherSkin(f.inst, "hud.text")
    f.NS.ApplySkinChoice("ka0s", key)
    f.M.__fireTimers()
    f.NS.Hud.Tick()
    local r, g, b = f.NS.Skin.HudTextColor()
    assertEqual(colored, rgb(r, g, b), "the figure redrew in the skin's text")
    local _, _, sr, sg, sb = f.NS.Skin.HudShadow()
    assertEqual(shadow, rgb(sr, sg, sb), "its shadow, behind the stamp, redrew")
    local tr, tg, tb = f.NS.Skin.Color("chart.track")
    assertEqual(plot, rgb(tr, tg, tb), "the plot's background follows chart.track")
end)

-- ── the step ────────────────────────────────────────────────────────────────────────────────────

local function encode(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. encode(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end

local function migrated(profiles, libFiles)
    local i = T.load({ init = false, libFiles = libFiles })
    _G.DpsRaceDB = { global = { schemaVersion = 8, schema = 4 }, profiles = profiles }
    i.mocks._G.DpsRaceDB = _G.DpsRaceDB
    i.NS:InitDB()
    i.NS:RunMigrations()
    return i
end

local function partial()
    return {
        appearance = {
            figures = { font = "Arial Narrow", fontFromSkin = false, fontColorFromSkin = false,
                        fontColor = { r = 0.1 }, fontFlags = "THICKOUTLINE", fontShadow = false },
            spellText = { useClassColorFont = true, fontColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 } },
            elapsed = { fontFlags = "OUTLINE", fontColor = { g = 0.1 }, fontShadowFromSkin = false },
            bars = { barTexture = "Blizzard", barTextureFromSkin = false, bgFromSkin = false,
                     bgColor = { r = 0.2 }, borderColor = { b = 0.3 }, borderSize = 3, borderStyle = "Solid",
                     borderStyleFromSkin = false, useClassColorBorder = true },
            chart = { bgColor = { a = 0.9 } },
        },
        resultsTable = { damageBar = { bgFromSkin = false, borderColorFromSkin = false } },
        skin = { ignorePanel = false, ignoreFonts = true },
    }
end

test("skin flip: the step moves a stored partial profile onto the skin and rewrites nothing else", function()
    local p, before = partial(), partial()
    local i = migrated({ P = p })
    local A = i.NS.HudAppearance
    assertEqual(i.NS.db.global.schemaVersion, i.NS.SCHEMA_VERSION)
    for _, path in ipairs(A.FULL_SKIN_KEYS) do
        if path:match("FromSkin$") then
            local t = p
            for part in path:gmatch("[^.]+") do t = type(t) == "table" and t[part] or nil end
            assertTrue(t == true or t == nil, path .. " follows")
        end
    end
    local a = p.appearance
    assertEqual(a.figures.fontFromSkin, true); assertEqual(a.figures.fontColorFromSkin, true)
    assertEqual(a.bars.barTextureFromSkin, true); assertEqual(a.bars.bgFromSkin, true)
    assertEqual(a.bars.borderStyleFromSkin, true); assertEqual(a.bars.borderColorFromSkin, true)
    assertEqual(a.elapsed.fontShadowFromSkin, true)
    assertEqual(p.resultsTable.damageBar.borderColorFromSkin, true)
    -- Every pick and color byte-identical.
    assertEqual(a.figures.font, "Arial Narrow")
    assertEqual(encode(a.figures.fontColor), encode(before.appearance.figures.fontColor))
    assertEqual(a.figures.fontShadow, false, "a stored shadow kept for the companion off")
    assertEqual(encode(a.bars.bgColor), encode(before.appearance.bars.bgColor))
    assertEqual(encode(a.bars.borderColor), encode(before.appearance.bars.borderColor))
    assertEqual(a.bars.barTexture, "Blizzard"); assertEqual(a.bars.borderStyle, "Solid")
    assertEqual(a.bars.borderSize, 3, "a stored thickness kept")
    assertEqual(encode(a.chart.bgColor), encode(before.appearance.chart.bgColor))
    -- The flags named, and only those.
    assertEqual(a.figures.fontFlags, "@skin", "a listed flag goes on From skin")
    assertEqual(a.elapsed.fontFlags, "OUTLINE", "a clock's picked flag stays: no reader of it is on the skin")
    assertEqual(encode(a.elapsed.fontColor), encode(before.appearance.elapsed.fontColor), "a meaning color")
    -- The A9 tracks are no companion of the step's.
    assertEqual(p.resultsTable.damageBar.bgFromSkin, false, "the owner's no-track call stands")
    -- Class colors and toggles, and the two ignores.
    assertEqual(a.spellText.useClassColorFont, true)
    assertEqual(a.bars.useClassColorBorder, true)
    assertEqual(p.skin.ignorePanel, false); assertEqual(p.skin.ignoreFonts, true)
    assertEqual(p.skin.fullSkinReset, true, "the record")
end)

test("skin flip: the list names every companion on by default, and the three flags keys", function()
    local listed = {}
    for _, path in ipairs(T.NS.HudAppearance.FULL_SKIN_KEYS) do
        assertTrue(not listed[path], path .. " is listed twice")
        listed[path] = true
    end
    local seen = 0
    local function walk(t, prefix)
        for k, v in pairs(t) do
            local path = prefix .. tostring(k)
            if type(v) == "table" then
                walk(v, path .. ".")
            elseif tostring(k):match("FromSkin$") and v == true then
                assertTrue(listed[path], path .. " is on by default and the step does not name it")
                seen = seen + 1
            end
        end
    end
    walk(T.NS.defaults.profile, "")
    local flags, rest = {}, 0
    for path in pairs(listed) do
        if path:match("%.fontFlags$") then flags[#flags + 1] = path else rest = rest + 1 end
    end
    assertEqual(rest, seen, "the list names nothing else")
    table.sort(flags)
    assertEqual(table.concat(flags, " "), "appearance.figures.fontFlags appearance.spellText.fontFlags "
        .. "resultsTable.barText.fontFlags")
end)

test("skin flip: the list names no size, class color, ignore, bar fill or clock color", function()
    for _, path in ipairs(T.NS.HudAppearance.FULL_SKIN_KEYS) do
        for _, bad in ipairs({ "fontSize", "useClassColor", "ignore", "barColor", "fontColor$", "font$" }) do
            assertFalse(path:find(bad) ~= nil, path .. " is listed")
        end
    end
end)

test("skin flip: a sub-table the profile never stored is skipped and stays absent", function()
    local bare = {}
    migrated({ Bare = bare })
    assertEqual(encode(bare), "{skin={fullSkinReset=true}}", "the record is the one table the step creates")
end)

test("skin flip: a current profile born after the stamp reached 9 takes the step at the next init", function()
    local p, other = {}, {}
    local i = T.load({ init = false })
    _G.DpsRaceDB = { global = { schemaVersion = i.NS.SCHEMA_VERSION, schema = 4 },
                     profiles = { Default = p, Other = other } }
    i.mocks._G.DpsRaceDB = _G.DpsRaceDB
    i.NS:InitDB()
    i.NS:RunMigrations()
    assertEqual(i.NS.db:GetCurrentProfile(), "Default")
    assertEqual(p.skin.fullSkinReset, true, "no ladder step ran, so this is the init's own call")
    assertEqual(encode(other), "{}", "a profile nobody is on waits for its event")
end)

test("skin flip: a second run writes nothing, on a profile event too", function()
    local p = partial()
    local i = migrated({ P = p })
    p.appearance.bars.bgFromSkin = false
    local snapshot = encode(p)
    i.NS:RunMigrations()
    i.NS.OnProfileChanged("OnProfileChanged", i.NS.db, "P")
    assertEqual(encode(p), snapshot)
end)

test("skin flip: a companion turned off afterwards stays off through every Defaults path", function()
    local p = {}
    local i = migrated({ Default = p })
    local NS = i.NS
    assertTrue(NS.SetByPath("appearance.figures.fontColorFromSkin", false))
    -- General's Defaults, the page the record's own section sits on (the pilot's bug), and History's.
    for _, page in ipairs({ "general", "history" }) do
        for _, r in ipairs(NS.SchemaForPage(page)) do NS.ApplyDefault(r) end
    end
    assertEqual(NS.db.profile.skin.fullSkinReset, true, "no Defaults walks the record")
    assertEqual(NS.FindSchemaRow("skin.fullSkinReset"), nil, "no row carries it")
    NS.OnProfileChanged("OnProfileChanged", NS.db, "Default")
    NS:RunMigrations()
    assertEqual(NS.GetSetting("appearance.figures.fontColorFromSkin"), false, "still off")
end)

test("skin flip: a new profile and a reset profile run it against defaults, seen by nobody", function()
    local i = migrated({ Default = {} })
    local NS = i.NS
    NS.db:SetProfile("New")
    assertEqual(NS.db.profile.skin.fullSkinReset, true, "a new profile takes the record on its event")
    NS.db:ResetProfile()
    assertEqual(NS.db.profile.skin.fullSkinReset, true, "a reset profile too")
    assertEqual(NS.GetSetting("appearance.figures.fontColorFromSkin"), true)
end)

test("skin flip: with the library absent the step makes the same writes and its own record", function()
    local p = partial()
    local i = migrated({ P = p }, {})
    local a = p.appearance
    assertEqual(a.figures.fontColorFromSkin, true)
    assertEqual(a.bars.bgFromSkin, true)
    assertEqual(a.figures.fontFlags, "@skin")
    assertEqual(a.figures.fontColor.r, 0.1, "the color kept")
    assertEqual(a.elapsed.fontFlags, "OUTLINE")
    assertEqual(p.skin.fullSkinReset, true)
    -- Its own gate: a companion turned off afterwards stays off, the step answering that it did not run.
    a.figures.fontColorFromSkin = false
    assertEqual(i.NS.FollowSkinOnce(p), false)
    assertEqual(a.figures.fontColorFromSkin, false, "the record holds the no-library arm too")
    local bare = {}
    migrated({ Bare = bare }, {})
    assertEqual(encode(bare), "{skin={fullSkinReset=true}}", "no table but the record's")
end)

test("skin flip: a profile already through the step meets the clocks' companions at the next one (SG-DR-2)", function()
    -- The owner's profile: the skin step ran before the clocks joined its list, so the record is set
    -- and the clock blocks still hold a stored mono pick with both companions off.
    local p = { skin = { fullSkinReset = true },
                appearance = { elapsed = { font = "JetBrains Mono", fontFromSkin = false, fontShadowFromSkin = false },
                               left = { font = "Arial Narrow", fontFromSkin = false } } }
    local i = T.load({ init = false })
    _G.DpsRaceDB = { global = { schemaVersion = 9, schema = 4 }, profiles = { Default = p } }
    i.mocks._G.DpsRaceDB = _G.DpsRaceDB
    i.NS:InitDB()
    i.NS:RunMigrations()
    assertEqual(p.appearance.elapsed.fontFromSkin, true, "the face companion on")
    assertEqual(p.appearance.elapsed.fontShadowFromSkin, true, "the shadow companion on")
    assertEqual(p.appearance.left.fontFromSkin, true)
    assertEqual(p.appearance.elapsed.font, "JetBrains Mono", "the stored pick kept")
    assertEqual(p.appearance.left.font, "Arial Narrow", "a pick of the player's kept")
    local A = i.NS.HudAppearance
    local face = i.mocks.LibStub("LibSharedMedia-3.0"):Fetch("font", i.NS.Skin.Token("hud.font"))
    assertEqual(A.Font("elapsed").path, face, "the clock draws the skin's face")
    assertEqual(A.Font("left").path, face)
end)
