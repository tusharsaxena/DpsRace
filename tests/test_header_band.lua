-- tests/test_header_band.lua — every DpsRace window's header on the library's title band (R5-DR1 of
-- Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND5: feedback items 3, 3a and 5, the lead's calls 3,
-- 4 and 6 in 00_PLAN.md).
--
-- Item 3: the four windows (the race HUD, Results, the ability timeline, the gear view) are
-- BackdropTemplate frames, and Shell's top band drew under the backdrop's own fill, so no skin showed
-- a header. LibKa0s R5-L2 draws it over that fill; this suite holds the host to it: each window wears
-- the band, shown, above the backdrop's Center.
-- Item 5: every header child (the title, the close mark, the title-bar controls) is anchored LEFT,
-- CENTER or RIGHT to the band's own frame (S.Band) at y 0, its vertical middle, in every skin. Before,
-- each sat at -HEADER_H/2 off the frame's top: 1 px high of a band inset 1, 2 px of one inset 2.
-- Item 3a: the HUD's title is LEFT in every skin; the other three follow the skin's `title.align`.
-- The drag strip and the Results tab strip stand on the band too, so neither overlaps it in any skin.
--
-- Headless, only the anchor shape is measurable (the kit's FontString answers no string height): a
-- LEFT, CENTER or RIGHT point on the band at y 0 IS its middle. The glyphs are the owner's smoke check.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600
local GEAR = { [1] = "|cnIQ4:|Hitem:212001::::::::80:267::6:2:10390:1540::::::|h[Hood of the Test]|h|r" }

local function inst(opts)
    opts = opts or {}
    local i = T.load{ libFiles = opts.libFiles, mutate = function(m)
        Widgets.install(m)
        if not opts.bare then dofile(T.root .. "/tests/_kit/mock_paint.lua")(m) end
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
    end }
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

--- The four windows, built and shown: { name = frame, ... } plus each one's ui table.
local function windows(i, NS)
    mkRun(NS, "this", 100)
    mkRun(NS, "best", 300, { date = NOW - 2 * HOUR })
    NS.Bests.Invalidate()
    NS.Hud.Show()
    NS.Results.ShowRun("this")
    local detail = NS.Results.__ui().detail
    detail.w.timeline:__fire("OnClick")
    local tl = NS.ResultsTimeline.__ui()
    NS.ResultsTimeline.Hide()
    i.mocks.__fireTimers()
    detail.lo.gearView:__fire("OnClick")
    return {
        { "the race HUD", NS.Hud.__ui(), { "close", "lock", "settings", "results" } },
        { "the Results window", NS.Results.__ui(), { "close", "viewToggle" } },
        { "the ability timeline", tl, { "close" } },
        { "the gear view", NS.ResultsGear.__ui(), { "close" } },
    }
end

local CENTERED = { LEFT = true, CENTER = true, RIGHT = true }

--- The anchors `r` was given since its last ClearAllPoints (the mocks record them in `__points`;
--- the base frame mock answers no GetPoint of its own).
local function points(r) return rawget(r, "__points") or {} end

--- `region`'s every point is LEFT, CENTER or RIGHT on `band`'s own point at y 0. A title may carry a
--- second point on `alt` (the drag strip, which stands on the band's rect) at y 0.
local function assertOnBand(region, band, what, alt)
    local pts = points(region)
    assertTrue(#pts >= 1 and #pts <= 2, what .. ": anchored")
    for _, pt in ipairs(pts) do
        local point, rel, relPoint, _, y = unpack(pt)
        assertTrue(CENTERED[point], ("%s: a %s point, never TOP*"):format(what, tostring(point)))
        assertEqual(relPoint, point, what .. ": to the band's own " .. tostring(point))
        assertTrue(rel == band or (alt ~= nil and rel == alt), what .. ": anchored to the band")
        assertEqual(y, 0, what .. ": y 0, the band's middle")
    end
end

--- The drag strip covers the band's rect left of the controls: its top-left on the band's, its
--- bottom-right on the band's bottom-right.
local function assertDragOnBand(drag, band, what)
    local pts = points(drag)
    assertEqual(#pts, 2, what .. ": the drag strip, two points")
    local p1, r1, q1, x1, y1 = unpack(pts[1])
    local p2, r2, q2, _, y2 = unpack(pts[2])
    assertEqual(p1 .. q1, "TOPLEFTTOPLEFT", what); assertTrue(r1 == band, what .. ": on the band")
    assertEqual(x1, 0, what); assertEqual(y1, 0, what)
    assertEqual(p2 .. q2, "BOTTOMRIGHTBOTTOMRIGHT", what); assertTrue(r2 == band, what .. ": on the band")
    assertEqual(y2, 0, what)
end

local function skins(i)
    local out = {}
    for _, def in ipairs(i.mocks.LibStub("LibKa0s-Skin-1.0"):Skins()) do out[#out + 1] = def.key end
    return out
end

test("header band: each window wears Shell's top band, shown, over its backdrop's fill", function()
    -- red under: LibKa0s before R5-L2, whose top band drew BACKGROUND -5, under the backdrop's Center.
    local i, NS = inst()
    local Skin = i.mocks.LibStub("LibKa0s-Skin-1.0")
    for _, w in ipairs(windows(i, NS)) do
        local f = w[2].frame
        local top = Skin.__regions[f] and Skin.__regions[f].top
        assertTrue(top ~= nil, w[1] .. ": a top band")
        assertTrue(top:IsShown(), w[1] .. ": shown")
        local layer, sub = top:GetDrawLayer()
        assertEqual(layer, "BACKGROUND", w[1])
        assertTrue(sub > 0, w[1] .. ": above the backdrop's Center (BACKGROUND 0)")
    end
end)

test("header band: every header child is centered on the band, in every skin", function()
    -- red under: the title and the controls at -HEADER_H/2 off the frame's TOP (1 px high of the band).
    local i, NS = inst()
    local list = windows(i, NS)
    for _, key in ipairs(skins(i)) do
        NS.ApplySkinChoice("ka0s", key)
        i.mocks.__fireTimers()
        for _, w in ipairs(list) do
            local u, what = w[2], key .. ", " .. w[1]
            local band = NS.Skin.Band(u.frame)
            assertTrue(band ~= nil, what .. ": the band")
            assertOnBand(u.frame.title, band, what .. ": the title", u.drag)
            for _, name in ipairs(w[3]) do
                assertOnBand(assert(u[name], what .. ": " .. name), band, what .. ": " .. name)
            end
            assertDragOnBand(u.drag, band, what)
        end
    end
end)

test("header band: the HUD's title is LEFT in every skin; the other titles follow title.align", function()
    -- red under: the HUD's plain title CENTER on the frame's TOP (item 3a, image 45).
    local i, NS = inst()
    local list = windows(i, NS)
    for _, key in ipairs(skins(i)) do
        NS.ApplySkinChoice("ka0s", key)
        i.mocks.__fireTimers()
        local align = NS.Skin.Token("title.align") or "CENTER"
        for n, w in ipairs(list) do
            local title, what = w[2].frame.title, key .. ", " .. w[1]
            local want = n == 1 and "LEFT" or align
            assertEqual(points(title)[1][1], want, what .. ": the title's point")
            assertEqual(rawget(title, "__justifyH"), want, what .. ": the title's justification")
        end
    end
end)

test("header band: the Results tab strip and its rule stand under the band, in every skin", function()
    -- red under: the tabs at -HEADER_H off the frame's top, over the band's last row (2 under a 2 px edge).
    local i, NS = inst()
    windows(i, NS)
    local u = NS.Results.__ui()
    for _, key in ipairs(skins(i)) do
        NS.ApplySkinChoice("ka0s", key)
        i.mocks.__fireTimers()
        local band = NS.Skin.Band(u.frame)
        for name, tab in pairs(u.tabs) do
            local p, rel, q, _, y = unpack(points(tab)[1])
            assertEqual(p .. q, "TOPLEFTBOTTOMLEFT", key .. ": the " .. name .. " tab")
            assertTrue(rel == band, key .. ": the " .. name .. " tab on the band's foot")
            assertEqual(y, 0, key .. ": flush under the band")
        end
    end
end)

test("header band: with no library each window's header stands where Shell would lay the band", function()
    -- The degraded load (no LibKa0s: S.Band answers nil, S.Header draws nothing): a host holder at
    -- inset 1 and title.height, the same anchors set once, the HUD's title LEFT and stopping at the drag.
    local i, NS = inst({ libFiles = {}, bare = true })
    for _, w in ipairs(windows(i, NS)) do
        local u = w[2]
        local band = u.frame.drBand
        assertTrue(band ~= nil, w[1] .. ": the host's band holder")
        assertOnBand(u.frame.title, band, w[1] .. ": the title", u.drag)
        for _, name in ipairs(w[3]) do
            if u[name] then assertOnBand(u[name], band, w[1] .. ": " .. name) end
        end
        assertDragOnBand(u.drag, band, w[1])
    end
    local hud = NS.Hud.__ui().frame.title
    assertEqual(#points(hud), 2, "the HUD's title is bounded on both sides")
    assertEqual(points(hud)[1][1], "LEFT")
    assertTrue(points(hud)[2][2] == NS.Hud.__ui().drag, "it stops where the drag strip does")
    assertEqual(rawget(hud, "__justifyH"), "LEFT")
end)
