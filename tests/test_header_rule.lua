-- tests/test_header_rule.lua — no line under any window's title band (R4-SEP of Ka0sAddonsCommonTasks
-- docs/2026-11-03-SMOKE_ROUND4, the owner's sign-off: every window like the Skin Tester's showroom).
-- The race HUD and the Results window kept a `frame.divider` for Core.ApplySkin to tint, and the gear
-- view and the ability timeline drew their own rule at the title band's foot. None of the four draws
-- a texture there now. The rules lower down stay: the HUD's and the Results window's footer rule, the
-- Results tab strip's rule under its tabs, and the timeline's legend line.
--
-- Under the kit's paint recorder, so each window's own textures and their anchors are readable.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600
local GEAR = { [1] = "|cnIQ4:|Hitem:212001::::::::80:267::6:2:10390:1540::::::|h[Hood of the Test]|h|r" }

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

--- Every texture of `frame` anchored to it at the title band's foot (y = -height), with how many.
local function headerRules(frame, height)
    local hits = 0
    for _, r in ipairs({ frame:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            for n = 1, r:GetNumPoints() do
                local _, rel, _, _, y = r:GetPoint(n)
                if rel == frame and y == -height then
                    hits = hits + 1
                    break
                end
            end
        end
    end
    return hits
end

--- Every texture of `frame` anchored to `rel` (the frame itself unless named) at `y`, any point (the
--- rules that stay).
local function rulesAt(frame, y, rel)
    local hits = 0
    for _, r in ipairs({ frame:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            for n = 1, r:GetNumPoints() do
                local _, to, _, _, py = r:GetPoint(n)
                if to == (rel or frame) and py == y then
                    hits = hits + 1
                    break
                end
            end
        end
    end
    return hits
end

test("header rule: the race HUD draws no line under its title band, and keeps its footer rule", function()
    -- red under: buildHeader's f.divider at -HEADER_H (hidden by Core.ApplySkin since R4-SEP, but
    -- still made; a library-absent or older-library load would show it).
    local _, NS = inst()
    NS.Hud.Show()
    local f = assert(NS.Hud.__ui()).frame
    assertTrue(f.divider == nil, "no frame.divider for ApplySkin to tint")
    assertEqual(headerRules(f, NS.Style.TITLE_BAR_H), 0, "no texture at the title band's foot")
    assertEqual(rulesAt(f, 20), 1, "the footer rule stays")
end)

test("header rule: the Results window draws no line under its title band, and keeps the tab rule", function()
    local _, NS = inst()
    mkRun(NS, "this", 100)
    NS.Bests.Invalidate()
    NS.Results.ShowRun("this")
    local f = assert(NS.Results.__ui()).frame
    local H = NS.Style.TITLE_BAR_H
    assertTrue(f.divider == nil, "no frame.divider for ApplySkin to tint")
    assertEqual(headerRules(f, H), 0, "no texture at the title band's foot")
    -- The tab strip stands under the title band since R5-DR1, and its rule with it.
    assertEqual(rulesAt(f, -NS.Style.TAB_STRIP_H, NS.Style.Band(f)), 1, "the rule under the tabs stays")
end)

test("header rule: the ability timeline and the gear view draw no line under their title band", function()
    -- red under: buildChrome's dr.modal.divider rule at -HEADER_H in each modal.
    local i, NS = inst()
    mkRun(NS, "this", 100)
    mkRun(NS, "best", 300, { date = NOW - 2 * HOUR })
    NS.Bests.Invalidate()
    NS.Results.ShowRun("this")
    local H = NS.Style.TITLE_BAR_H
    local detail = NS.Results.__ui().detail
    detail.w.timeline:__fire("OnClick")
    assertTrue(NS.ResultsTimeline.IsShown(), "the timeline opened")
    local tl = NS.ResultsTimeline.__ui()
    assertEqual(headerRules(tl.frame, H), 0, "the timeline: no texture at the title band's foot")
    assertTrue(tl.legendLine ~= nil, "the timeline's legend line stays")
    NS.ResultsTimeline.Hide()
    i.mocks.__fireTimers()
    detail.lo.gearView:__fire("OnClick")
    assertTrue(NS.ResultsGear.IsShown(), "the gear view opened")
    assertEqual(headerRules(NS.ResultsGear.__ui().frame, H), 0, "the gear view: no texture at the title band's foot")
end)
