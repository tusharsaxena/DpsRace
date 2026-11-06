-- tests/test_column_header_rule.lua — no line above or below the Runs list's column headers (SF1-DR of
-- Ka0sAddonsCommonTasks docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/SF1_SMOKE_FEEDBACK.md, item 5: "DpsRace's
-- column headers have a gray line above and below. LootHistory's do not, and LootHistory is correct").
-- The line above was the filter bar's bottom divider, which the header row sits on; the line below was
-- the table header's own bottom divider. Both go. The header row takes the skin's SortHeaderBar, the
-- seam LootHistory's header takes (LootHistory modules/BrowserTable.lua), so a skin that sets
-- `list.header.bg` paints its band and Ka0s Default paints none.
--
-- The rules that are not against a column header stay: the Insights filter bar's (cards sit under it)
-- and the Results window's tab-strip and footer rules (tests/test_header_rule.lua).
--
-- Under the kit's paint recorder, so each frame's own textures and their anchors are readable.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()

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

local function seed(NS)
    NS.db.global.runs.r1 = {
        id = "r1", schema = 4, status = "complete", addon = "0.1.0", date = NOW - 3600,
        race = { length = 60, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction",
                 level = 80, ilvl = 639.4 },
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = 6000, dps = 100, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = 29722, dmg = 5000 } }, note = "",
    }
    NS.Bests.Invalidate()
end

local EDGE = { TOPLEFT = "top", TOPRIGHT = "top", TOP = "top",
               BOTTOMLEFT = "bottom", BOTTOMRIGHT = "bottom", BOTTOM = "bottom" }

--- How many textures of `frame` are anchored to it at its `side` edge ("top" or "bottom") with no
--- vertical offset: the shape of a rule drawn along that edge.
local function edgeRules(frame, side)
    local hits = 0
    for _, r in ipairs({ frame:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            for n = 1, r:GetNumPoints() do
                local point, rel, _, _, y = r:GetPoint(n)
                if rel == frame and EDGE[point] == side and (y or 0) == 0 then
                    hits = hits + 1
                    break
                end
            end
        end
    end
    return hits
end

local function runsPane(NS)
    seed(NS)
    NS.Results.Show()
    return assert(NS.Results.__ui().panes.runs, "the Runs tab was never built")
end

test("column header rule: no line under the Runs list's column headers", function()
    -- red under: Tbl.New's NS.Skin.Divider rule at the header's BOTTOMLEFT/BOTTOMRIGHT.
    local _, NS = inst()
    local header = runsPane(NS).list.header
    assertEqual(edgeRules(header, "bottom"), 0, "no texture along the header's bottom edge")
    assertEqual(edgeRules(header, "top"), 0, "no texture along the header's top edge")
end)

test("column header rule: no line above them (the Runs filter bar draws no bottom rule)", function()
    -- red under: buildBar's NS.Skin.Divider rule at the filter bar's bottom, which the header sits on.
    local _, NS = inst()
    local bar = assert(runsPane(NS).bar, "the Runs filter bar")
    assertEqual(edgeRules(bar, "bottom"), 0, "no texture along the filter bar's bottom edge")
end)

test("column header rule: the header row takes the skin's SortHeaderBar, LootHistory's seam", function()
    local _, NS = inst()
    local seen = {}
    local real = NS.Skin.SortHeaderBar
    NS.Skin.SortHeaderBar = function(frame, ...)
        seen[#seen + 1] = frame
        return real(frame, ...)
    end
    local header = runsPane(NS).list.header
    NS.Skin.SortHeaderBar = real
    local found = false
    for _, f in ipairs(seen) do if f == header then found = true end end
    assertTrue(found, "SortHeaderBar was handed the Runs list's header row")
end)

test("column header rule: the Insights filter bar keeps its rule (cards sit under it, not headers)", function()
    local _, NS = inst()
    seed(NS)
    NS.Results.Show()
    NS.Results.ShowTab("insights")
    local pane = assert(NS.Results.__ui().panes.insights, "the Insights tab was never built")
    assertEqual(edgeRules(pane.bar, "bottom"), 1, "the Insights filter bar's rule stays")
end)
