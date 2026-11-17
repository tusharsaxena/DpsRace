-- tests/test_title_bar.lua — every title-bar control of DpsRace's own windows (smoke round 1 of
-- Ka0sAddonsCommonTasks docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS, rulings 2 to 4: SR-L1, SR-L2, SR-L3).
--
-- One case per window (the race HUD, the Results window, the ability timeline, the gear view), each
-- under Ka0s Default and a second skin (each window's settings mark included, LibKa0s#86):
--   - every control shows a non-empty tooltip on hover, owned by the control, its first line in the
--     skin's `gtip.title`, placed above it (BOTTOM on its TOP; headless, the tooltip answers no size, so
--     LibKa0s-Tooltip-1.0's PlaceAttached cannot read it and the relative fallback places it), and
--     takes it down on leave;
--   - every control but the close rests in `icon.tint` and takes `text.link` under the pointer;
--   - the close X rests in `icon.tint` (`close.rest`, which follows it) and takes `close.hot`.
-- The expected colors are read from the skin's own definition (ResolveSkin), never from the host's
-- live tables, so a host that painted the wrong token goes red here.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600
local GEAR = { [1] = "|cnIQ4:|Hitem:212001::::::::80:267::6:2:10390:1540::::::|h[Hood of the Test]|h|r" }
local SKINS = { "ka0s", "obsidian" }

local function inst(opts)
    opts = opts or {}
    local i = T.load{ libFiles = opts.libFiles, mutate = function(m)
        Widgets.install(m)
        -- Real Textures and FontStrings (the kit's paint recorder), so the skin's own close painter
        -- finds its art: under the bare recorder it answers no object type and the close is never painted.
        if not opts.bare then dofile(T.root .. "/tests/_kit/mock_paint.lua")(m) end
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
    end }
    i.Skin = i.mocks.LibStub("LibKa0s-Skin-1.0", opts.libFiles ~= nil)
    return i, i.NS
end

local function mkRun(NS, id, dps, fields)
    local decoded = { { t = 1, id = 29722 }, { t = 2, id = 17962 } }
    local run = {
        id = id, schema = 4, status = "complete", addon = "0.1.0", date = NOW - HOUR,
        race = { length = 60, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction",
                 level = 80, ilvl = 639.4 },
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 60, dps = dps, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = 29722, dmg = dps * 50 } }, note = "",
        casts = { v = 1, list = NS.Casts.Encode(decoded), spells = { [29722] = 0, [17962] = 13000 }, dropped = 0 },
        loadout = NS.Loadouts.Store({ gear = GEAR }),
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    NS.db.global.runs[id] = run
    return run
end

-- Each window's ui table, shown, and the title-bar controls it draws (close first).
local OPEN = {
    hud = function(_, NS)
        NS.Hud.Show()
        return NS.Hud.__ui(), { "close", "lock", "settings", "results" }
    end,
    results = function(_, NS)
        NS.Results.Show()
        return NS.Results.__ui(), { "close", "settings", "viewToggle" }
    end,
    timeline = function(_, NS)
        mkRun(NS, "this", 100)
        mkRun(NS, "best", 300, { date = NOW - 2 * HOUR })
        NS.Bests.Invalidate()
        NS.Results.ShowRun("this")
        NS.Results.__ui().detail.w.timeline:__fire("OnClick")
        return NS.ResultsTimeline.__ui(), { "close", "settings" }
    end,
    gear = function(_, NS)
        mkRun(NS, "this", 100)
        mkRun(NS, "best", 300, { date = NOW - 2 * HOUR })
        NS.Bests.Invalidate()
        NS.Results.ShowRun("this")
        NS.Results.__ui().detail.lo.gearView:__fire("OnClick")
        return NS.ResultsGear.__ui(), { "close", "settings" }
    end,
}

-- A recording GameTooltip: its owner, lines, title color, points and shown state.
local function recordingTip(i)
    local tip = { lines = {}, points = {}, shown = false }
    function tip.SetOwner(_, owner, anchor) tip.owner, tip.anchor, tip.lines, tip.points = owner, anchor, {}, {} end
    function tip.SetText(_, text, r, g, b) tip.lines = { text }; tip.title = { r, g, b } end
    function tip.AddLine(_, text) tip.lines[#tip.lines + 1] = text end
    function tip.Show() tip.shown = true end
    function tip.Hide() tip.shown = false end
    function tip.IsOwned(_, f) return tip.owner == f end
    function tip.ClearAllPoints() tip.points = {} end
    function tip.SetPoint(_, ...) tip.points[#tip.points + 1] = { ... } end
    i.mocks.GameTooltip = tip
    return tip
end

local function rgb(c)
    if type(c) ~= "table" or c[1] == nil then return "nil" end
    return ("%.3f,%.3f,%.3f"):format(c[1], c[2], c[3])
end

--- The color `b` draws: its icon's vertex color (the catalog art), else its glyph's text color.
local function drawn(b)
    local icon = rawget(b, "icon")
    if icon and icon.__vertex then return icon.__vertex end
    local g = rawget(b, "glyph") or rawget(b, "text") or rawget(b, "label")
    return g and g.__color
end

local function checkWindow(key)
    for _, skin in ipairs(SKINS) do
        local i, NS = inst()
        local u, names = OPEN[key](i, NS)
        assertTrue(u ~= nil, key .. ": the window was never built")
        NS.ApplySkinChoice("ka0s", skin)
        i.mocks.__fireTimers()
        local def = i.Skin:ResolveSkin(skin)
        local tint, link, hot, title = def["icon.tint"], def["text.link"], def["close.hot"], def["gtip.title"]
        assertTrue(rgb(tint) ~= rgb(link), skin .. ": icon.tint and text.link tell apart")
        local tip = recordingTip(i)
        for _, name in ipairs(names) do
            local what = ("%s (%s) %s"):format(key, skin, name)
            local b = u[name]
            assertTrue(b ~= nil, what .. ": no control")
            assertEqual(rgb(drawn(b)), rgb(tint), what .. ": at rest, icon.tint")
            b:__fire("OnEnter")
            assertTrue(tip.shown and tip.owner == b, what .. ": a tooltip owned by the control")
            assertTrue(type(tip.lines[1]) == "string" and #tip.lines[1] > 0, what .. ": a non-empty tooltip")
            assertEqual(rgb(tip.title), rgb(title), what .. ": the title in gtip.title")
            local pt = tip.points[#tip.points]
            assertTrue(pt ~= nil and pt[1] == "BOTTOM" and pt[2] == b and pt[3] == "TOP", what .. ": above the control")
            assertEqual(rgb(drawn(b)), rgb(name == "close" and hot or link),
                what .. (name == "close" and ": close.hot" or ": text.link") .. " under the pointer")
            b:__fire("OnLeave")
            assertTrue(not tip.shown, what .. ": taken down on leave")
            assertEqual(rgb(drawn(b)), rgb(tint), what .. ": back at rest")
        end
    end
end

test("title bar: the race HUD's close, lock, settings and Results controls (tooltips, rest and hover)", function()
    checkWindow("hud")
end)

test("title bar: the Results window's close, settings and view toggle (tooltips, rest and hover)", function()
    checkWindow("results")
end)

test("title bar: the ability timeline's close and settings (tooltips, rest and hover)", function()
    checkWindow("timeline")
end)

test("title bar: the gear view's close and settings (tooltips, rest and hover)", function()
    checkWindow("gear")
end)

-- ── the marks are W.HeaderButtons' (LibKa0s#86, item AD-86-DR) ──────────────────────────────────
-- standalone-windows' *Title-bar controls* (WowAddonStandards v2.113.0): every window's marks are
-- LibKa0s-Widgets-1.0's HeaderButtons, right-aligned, left to right extras . settings . close, one 18 px
-- size and a 6 px gap (the library's HEADER: PAD 6 in from the corner, GAP 6 between marks), so the
-- close sits 6 in, settings 30, the first extra 54 and the next 78. The settings mark opens this
-- addon's settings through the opener its launcher registered (Core's OpenSettings("DpsRace"), filled
-- from the launcher's `openSettings`). The timeline and the gear view stand at DIALOG, over the
-- settings panel, so each hides first (`hideOnSettings`).

-- Each window's marks, left to right, as its ui table names them.
local ORDER = {
    hud = { "results", "lock", "settings", "close" },
    results = { "viewToggle", "settings", "close" },
    timeline = { "settings", "close" },
    gear = { "settings", "close" },
}

--- The x a frame's last RIGHT point on the band was given (negative: in from the right edge).
local function rightX(b)
    local x
    for _, p in ipairs(rawget(b, "__points") or {}) do
        if p[1] == "RIGHT" and p[3] == "RIGHT" then x = p[4] end
    end
    return x
end

local function checkStrip(key)
    local i, NS = inst()
    local u = OPEN[key](i, NS)
    local hb = u.frame.headerButtons
    assertTrue(type(hb) == "table", key .. ": the marks are W.HeaderButtons' (frame.headerButtons)")
    local want = ORDER[key]
    assertEqual(table.concat(hb.order, " "), table.concat(want, " "), key .. ": left to right extras . settings . close")
    assertTrue(hb.optOut == nil, key .. ": no settings opt-out")
    assertTrue(hb.settings ~= nil and hb.settings == u.settings, key .. ": the settings mark is the window's")
    assertTrue(hb.close ~= nil and hb.close == u.close, key .. ": the close is the window's own")
    for n = #want, 1, -1 do
        local name = want[n]
        local slot = #want - n
        local b = u[name]
        local x = 6 + slot * 24
        assertEqual(hb.offsets[name], -x,
            ("%s: %s at %d in from the corner"):format(key, name, x))
        assertEqual(rightX(b), -x, ("%s: %s placed on the band %d in"):format(key, name, x))
    end
end

test("title bar: the race HUD's marks are W.HeaderButtons', results . lock . settings . close", function()
    checkStrip("hud")
end)

test("title bar: the Results window's marks are W.HeaderButtons', view toggle . settings . close", function()
    checkStrip("results")
end)

test("title bar: the ability timeline's and the gear view's marks are W.HeaderButtons', settings . close", function()
    checkStrip("timeline")
    checkStrip("gear")
end)

--- Click the window's settings mark with the settings panel spied: answers how often it opened.
local function clickSettings(key, opts)
    local i, NS = inst(opts)
    local u = OPEN[key](i, NS)
    local opened = 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    assertTrue(u.settings ~= nil, key .. ": a settings mark")
    u.settings:__fire("OnClick", "LeftButton")
    i.mocks.__fireTimers()
    return opened, u, NS
end

test("title bar: each window's settings mark opens the settings through the launcher's opener", function()
    for _, key in ipairs({ "hud", "results", "timeline", "gear" }) do
        local opened = clickSettings(key)
        assertEqual(opened, 1, key .. ": the settings panel opened once")
    end
end)

test("title bar: the timeline and the gear view hide before the settings open; the HUD and Results stay", function()
    for _, key in ipairs({ "timeline", "gear" }) do
        local _, u, NS = clickSettings(key)
        assertTrue(not u.frame:IsShown(), key .. ": hidden, so it never covers the settings panel")
        assertTrue(NS.Results.__ui().frame:IsShown(), key .. ": the Results window under it stays open")
    end
    for _, key in ipairs({ "hud", "results" }) do
        local _, u = clickSettings(key)
        assertTrue(u.frame:IsShown(), key .. ": stays open beside the settings")
    end
end)

-- ── the degraded load (no LibKa0s, so no HeaderButtons) ─────────────────────────────────────────
-- The same marks are host controls on one title strip (Style.HeaderMarks' hostMarks), at the same
-- offsets (no close: nothing can make one, so settings takes the corner); the settings mark opens the panel directly (NS.OpenOptionsPanel) and draws the library's
-- own glyph for settings (HEADER_STRINGS.SETTINGS_GLYPH, "*").
local BARE = { libFiles = {}, bare = true }

test("title bar: with no library each window's settings mark opens the settings panel directly", function()
    for _, key in ipairs({ "hud", "results", "timeline", "gear" }) do
        local opened, u = clickSettings(key, BARE)
        assertTrue(u.frame.headerButtons == nil, key .. ": no W.HeaderButtons on a degraded load")
        assertEqual(opened, 1, key .. ": the settings panel opened once")
        assertEqual(u.settings.glyph:GetText(), "*", key .. ": the library's settings glyph")
    end
end)

test("title bar: with no library the timeline and the gear view still hide before the settings open", function()
    for _, key in ipairs({ "timeline", "gear" }) do
        local _, u = clickSettings(key, BARE)
        assertTrue(not u.frame:IsShown(), key .. ": hidden, so it never covers the settings panel")
    end
    for _, key in ipairs({ "hud", "results" }) do
        local _, u = clickSettings(key, BARE)
        assertTrue(u.frame:IsShown(), key .. ": stays open beside the settings")
    end
end)

test("title bar: with no library the host marks stand at the library's offsets, extras . settings . close", function()
    for _, key in ipairs({ "hud", "results", "timeline", "gear" }) do
        local i, NS = inst(BARE)
        local u = OPEN[key](i, NS)
        -- No library, no NS.MakeCloseButton: the window has no close mark, so settings takes the corner.
        assertTrue(u.close == nil, key .. ": no close on a load that cannot make one")
        local want = {}
        for _, name in ipairs(ORDER[key]) do if name ~= "close" then want[#want + 1] = name end end
        for n = #want, 1, -1 do
            local name = want[n]
            local x = 6 + (#want - n) * 24
            assertTrue(u[name] ~= nil, ("%s: a %s mark"):format(key, name))
            assertEqual(rightX(u[name]), -x, ("%s: %s placed %d in from the corner"):format(key, name, x))
        end
    end
end)

-- ── a library mark dressed with art whose next icon has no art ──────────────────────────────────
-- Style.SetControlIcon's ladder: art when the catalog answers, else the glyph. A W.HeaderButton built
-- with art has no word of its own, so the host gives it one, painted icon.tint at rest and text.link
-- under the pointer, and the art comes back when the catalog answers again.
test("title bar: a library mark's icon with no catalog art falls back to its glyph", function()
    local i, NS = inst()
    local u = OPEN.hud(i, NS)
    local b = u.lock
    assertTrue(rawget(b, "icon") ~= nil and rawget(b, "label") == nil, "the lock is a library mark dressed with art")
    NS.Style.SetControlIcon(b, "no-such-icon", "L")
    local g = rawget(b, "glyph")
    assertTrue(g ~= nil, "a glyph to fall back to")
    assertTrue(g:IsShown() and not b.icon:IsShown(), "the glyph shows, the art hides")
    assertEqual(g:GetText(), "L")
    assertEqual(rgb({ g:GetTextColor() }), rgb(NS.Style.REST), "at rest, icon.tint")
    b:__fire("OnEnter")
    assertEqual(rgb({ g:GetTextColor() }), rgb(NS.Style.LINK), "under the pointer, text.link")
    b:__fire("OnLeave")
    assertEqual(rgb({ g:GetTextColor() }), rgb(NS.Style.REST), "back at rest")
    NS.Style.SetControlIcon(b, "unlock", "U")
    assertTrue(b.icon:IsShown() and not g:IsShown(), "the art comes back when the catalog answers")
end)
