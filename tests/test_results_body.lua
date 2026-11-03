-- tests/test_results_body.lua — the Results body's size follows the title band it hangs from (R5-DR1
-- follow-up of Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND5, from the R5 review).
--
-- Since R5-DR1 the tab strip and the body hang from the band's foot (S.Band). Under the EllesmereUI
-- source S.Band is flush at the top and 25 px high, but bodySize() worked the height out from
-- HEADER_H (30) and the token inset, so the Runs and Insights panes were laid 6 px shorter than the
-- body frame and left an empty strip at its foot. The size the panes are laid at must equal the
-- height the body's own anchors give it, read off the band as it is laid, in every skin and under
-- the EllesmereUI route.
--
-- Read headless off what the band and the body were told (tests/mock_widgets.lua records SetPoint
-- and SetHeight), never off a geometry read: the window makes none while it lays out.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600

local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        dofile(T.root .. "/tests/_kit/mock_paint.lua")(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
    end }
    return i, i.NS
end

local function mkRun(NS, id, dps)
    NS.db.global.runs[id] = {
        id = id, schema = 4, status = "complete", addon = "0.1.0", date = NOW - HOUR,
        race = { length = 60, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction",
                 level = 80, ilvl = 639.4 },
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 60, dps = dps, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = 29722, dmg = dps * 50 } }, note = "",
    }
end

local function pointsOf(r) return rawget(r, "__points") or {} end

local function pointNamed(r, name)
    for _, p in ipairs(pointsOf(r)) do
        if p[1] == name then return p end
    end
end

--- The band's inset (its TOPLEFT point's y, negated) and the height it was last given.
local function bandRect(band)
    local p = assert(pointNamed(band, "TOPLEFT"), "the band's TOPLEFT point")
    return -p[5], assert(rawget(band, "__height"), "the band's height")
end

--- The body's height by its anchors: TOPLEFT on the band's foot, BOTTOMRIGHT on the frame's.
local function anchoredHeight(u, band)
    local top = assert(pointNamed(u.body, "TOPLEFT"), "the body's TOPLEFT point")
    local foot = assert(pointNamed(u.body, "BOTTOMRIGHT"), "the body's BOTTOMRIGHT point")
    assertTrue(top[2] == band, "the body hangs from the band")
    assertEqual(top[3], "BOTTOMLEFT", "from the band's foot")
    local inset, h = bandRect(band)
    return u.height - (inset + h) + top[5] - foot[5]
end

--- The heights each tab's pane is laid at, recorded into `seen` as they are laid (a pane is spied
--- once; `seen` is the case's current table).
local seen = {}
local function spyPanes(u)
    for _, name in ipairs({ "runs", "insights" }) do
        local pane = u.panes[name]
        if pane and not rawget(pane, "__spied") then
            local orig = pane.Layout
            pane.__spied = true
            pane.Layout = function(self, w, h, ...)
                seen[name] = h
                return orig(self, w, h, ...)
            end
        end
    end
end

--- Each tab laid at the size the body's anchors give it.
local function assertBodyFits(i, NS, what)
    local u = NS.Results.__ui()
    local band = NS.Skin.Band(u.frame)
    local want = anchoredHeight(u, band)
    for _, name in ipairs({ "runs", "insights" }) do
        NS.Results.ShowTab(name)
        spyPanes(u)
        seen = {}
        NS.Results.ShowTab(name)
        i.mocks.__fireTimers()
        assertEqual(seen[name], want, ("%s, %s: the pane fills the body"):format(what, name))
    end
end

--- The window shown.
local function shown(NS)
    mkRun(NS, "a", 100)
    mkRun(NS, "b", 300)
    NS.Bests.Invalidate()
    NS.Results.Show()
    local u = NS.Results.__ui()
    assertTrue(NS.Skin.Band(u.frame) ~= nil, "the band")
    return u
end

test("results body: the panes fill the body under the band, in every skin", function()
    local i, NS = inst()
    shown(NS)
    for _, def in ipairs(i.mocks.LibStub("LibKa0s-Skin-1.0"):Skins()) do
        NS.ApplySkinChoice("ka0s", def.key)
        i.mocks.__fireTimers()
        assertBodyFits(i, NS, def.key)
    end
end)

test("results body: the panes fill the body under EllesmereUI's 25 px bar", function()
    -- red under: bodySize() from HEADER_H (30) and the token inset, 6 px short of a band 25 high at 0 (expected 487, got 481).
    local i, NS = inst()
    local u = shown(NS)
    local Skin = i.mocks.LibStub("LibKa0s-Skin-1.0")
    -- EllesmereUI paints the owner's Shell: S.Band lays flush and 25 high (SkinPaintExtras's
    -- bandGeometry). The Shell call itself still paints the library's way, headless. The instance
    -- is this case's own, so the route is never put back.
    Skin.__euiRoute = function(_, name)
        if name == "Shell" then return function(...) return Skin.prim.Shell(...) end end
        return nil
    end
    local inset, h = bandRect(NS.Skin.Band(u.frame))
    assertEqual(inset, 0, "flush at the top")
    assertEqual(h, 25, "EllesmereUI's bar height")
    assertBodyFits(i, NS, "eui")
end)
