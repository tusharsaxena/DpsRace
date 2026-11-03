-- tests/test_icon_rule.lua — the icon rule (R5-ICON of Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND5,
-- feedback item 7, images 51 and 52; the lead's call 9 in 00_PLAN.md; LibKa0s docs/api/README.md
-- "Icon art: the rule"): every Blizzard icon art is cropped by at least 0.07 per side; one that stands
-- alone in a window gets a 1 px edge in `icon.outline` (S.IconBorder, fromSkin), one on a toast the
-- HUD's `icon.border` (hud = true); an inline |T icon in a tooltip line is cropped only (5:59 of 64).
--
-- The sites R4-ZOOM never reached: the Runs list's Used column and its class and spec icons, the run
-- detail's Usage list and its class and spec icons, the compare's Damage and DPS line icons, the
-- new-best toast's class and spec icons and the Used column's tooltip markup. A class icon is one cell
-- of the character-creation sheet, so its crop is 0.07 of the CELL, inside CLASS_ICON_TCOORDS, and its
-- edge leaves the coords alone (zoom = false: the library's zoom clamps in whole-texture space).
-- Under the kit's paint recorder, so each texture's coords and each edge's color are readable.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600
local MIN = 0.07
local TRINKET, POTION = 190001, 211001

local function inst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        dofile(T.root .. "/tests/_kit/mock_paint.lua")(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
        m.C_Item.GetItemIconByID = function(id) return type(id) == "number" and 5000000 + id or 134400 end
    end }
    return i, i.NS
end

local function usage()
    return {
        v = 1, edited = false,
        used = {
            { itemID = TRINKET, kind = "gear", slot = 13, times = { 9.2 }, n = 1, src = "cast" },
            { itemID = POTION, kind = "potion", times = { -1.6 }, n = 1, src = "cast" },
            { kind = "food", n = 1, src = "buff" },
        },
        candidates = { { itemID = TRINKET, kind = "gear", slot = 13 }, { itemID = POTION, kind = "potion" } },
    }
end

local function mkRun(NS, id, dps, fields)
    local run = {
        id = id, schema = 4, status = "complete", addon = "0.1.0", date = NOW - HOUR,
        race = { length = 60, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction",
                 level = 80, ilvl = 639.4 },
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 60, dps = dps, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = 29722, dmg = dps * 50 } }, note = "", usage = usage(),
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    NS.db.global.runs[id] = run
    return run
end

local function opened()
    local i, NS = inst()
    mkRun(NS, "this", 100)
    mkRun(NS, "best", 300, { date = NOW - 2 * HOUR })
    NS.Bests.Invalidate()
    NS.Results.ShowRun("this")
    return i, NS
end

local function coords(tex)
    -- The client (and the kit) answers the 8-number form: ULx, ULy, LLx, LLy, URx, URy, LRx, LRy.
    local c = { tex:GetTexCoord() }
    return c[1], c[7], c[2], c[8]
end

--- `tex`'s crop holds at least MIN on every side of the whole texture.
local function cropped(tex, what)
    local l, r, t, b = coords(tex)
    assertTrue(l >= MIN and t >= MIN and r <= 1 - MIN and b <= 1 - MIN,
        ("%s: crop %s,%s,%s,%s is short of %s"):format(what, tostring(l), tostring(r), tostring(t),
            tostring(b), tostring(MIN)))
end

--- `tex` shows `class`'s cell of the sheet, cropped at least MIN of the cell on every side and never
--- outside it.
local function cellCropped(i, tex, class, what)
    local c = i.mocks.CLASS_ICON_TCOORDS[class]
    local w, h = c[2] - c[1], c[4] - c[3]
    local l, r, t, b = coords(tex)
    local eps = 1e-9
    assertTrue(l >= c[1] + MIN * w - eps and r <= c[2] - MIN * w + eps
        and t >= c[3] + MIN * h - eps and b <= c[4] - MIN * h + eps,
        ("%s: %s,%s,%s,%s is not inside %s's cell by %s"):format(what, tostring(l), tostring(r), tostring(t),
            tostring(b), class, tostring(MIN)))
end

local function rgba(c) return c and ("%.3f,%.3f,%.3f,%.3f"):format(c[1], c[2], c[3], c[4] or 1) or "nil" end

--- The edge S.IconBorder drew on `tex` (the Texture form): its record's call and its top's color.
local function edge(i, tex, what)
    local rec = i.mocks.LibStub("LibKa0s-Skin-1.0").painted[tex]
    assertTrue(rec ~= nil and rec.calls.IconBorder ~= nil, what .. ": edged by S.IconBorder")
    local opts = rec.calls.IconBorder[1] or {}
    assertTrue(opts.fromSkin == true, what .. ": the skin's 1 px edge")
    local top = rec.regions.edgeTop
    assertTrue(top ~= nil, what .. ": the edge has a top")
    return rgba(top.__color), opts
end

local function token(i, name) return rgba(i.NS.Skin.Token(name)) end

local function outlined(i, tex, what)
    local color = edge(i, tex, what)
    assertEqual(color, token(i, "icon.outline"), what .. ": the window's gray outline, not the HUD's black")
end

local function runsRow(NS, id)
    local pane = assert(NS.Results.__ui().panes.runs, "the Runs tab")
    if pane.filters.group ~= "none" then pane:SetFilter("group", "none") end
    for _, row in ipairs(pane.list:Visible()) do
        if row.run and row.run.id == id then return row end
    end
    error("no row for " .. id)
end

test("icon rule: the Runs list's Used column crops each icon and edges it in the window outline", function()
    -- red under: Cells.items' bare textures at the full 0..1 with no edge (image 51).
    local i, NS = opened()
    NS.Results.ShowTab("runs")
    local cell = runsRow(NS, "this").cells.used
    local n = 0
    for k = 1, cell.slots do
        local icon = cell["icon" .. k]
        if icon:IsShown() then
            n = n + 1
            cropped(icon, "Used icon " .. k)
            outlined(i, icon, "Used icon " .. k)
        end
    end
    assertTrue(n >= 2, "the run's items drew: " .. n)
end)

test("icon rule: the Runs list's class and spec icons are cropped and outlined", function()
    local i, NS = opened()
    NS.Results.ShowTab("runs")
    local cell = runsRow(NS, "this").cells.icons
    cellCropped(i, cell.class, "WARLOCK", "the class icon")
    local _, opts = edge(i, cell.class, "the class icon")
    assertTrue(opts.zoom == false, "the class icon's edge leaves its cell coords alone")
    outlined(i, cell.class, "the class icon")
    cropped(cell.spec, "the spec icon")
    outlined(i, cell.spec, "the spec icon")
end)

test("icon rule: a class cell on the sheet's edge keeps its crop inside the cell", function()
    -- MAGE's cell starts at the sheet's top (0): a whole-texture 0.07 clamp would cut 28% of it.
    local i, NS = inst()
    local tex = i.mocks.CreateFrame("Frame"):CreateTexture()
    assertTrue(NS.ResultsTable.SetClassIcon(tex, "MAGE"))
    cellCropped(i, tex, "MAGE", "MAGE")
end)

test("icon rule: the run detail's class and spec icons are cropped and outlined", function()
    local i, NS = opened()
    local w = NS.Results.__ui().detail.w
    cellCropped(i, w.class, "WARLOCK", "the detail's class icon")
    outlined(i, w.class, "the detail's class icon")
    cropped(w.spec, "the detail's spec icon")
    outlined(i, w.spec, "the detail's spec icon")
end)

test("icon rule: the run detail's Usage list crops each icon and edges it in the window outline", function()
    -- red under: newRow's bare row.icon at the full 0..1 with no edge (image 52).
    local i, NS = opened()
    local x = NS.Results.__ui().detail.usage
    assertTrue(#x.rows >= 3, "the usage rows drew")
    for n = 1, #x.rows do
        cropped(x.items[n].icon, "Usage row " .. n)
        outlined(i, x.items[n].icon, "Usage row " .. n)
    end
end)

test("icon rule: the compare's Damage and DPS line icons are cropped and outlined", function()
    local i, NS = opened()
    local d = NS.Results.__ui().detail
    -- The paint recorder's separators answer no effective scale: the lines are built before the
    -- layout reads it, so the first open builds them and the scale is handed in for the second.
    pcall(d.SetComparing, d, true)
    local x = assert(d.cmp, "the compare section")
    for _, sep in ipairs({ x.scoreSep, x.spellSep }) do
        if sep then rawset(sep, "GetEffectiveScale", function() return 1 end) end
    end
    d:SetComparing(true)
    assertTrue(#x.lines >= 2, "the Damage and DPS lines")
    for n, line in ipairs(x.lines) do
        cropped(line.icon, "compare line " .. n)
        outlined(i, line.icon, "compare line " .. n)
    end
end)

test("icon rule: a tooltip line's inline icon is cropped 5:59 of 64", function()
    -- red under: "|T<icon>:14:14|t", the full art with its native edge in the Used column's tooltip.
    local _, NS = inst()
    local markup = NS.ResultsUsage.InlineIcon({ itemID = TRINKET, kind = "gear", n = 1 })
    assertEqual(markup, "|T" .. (5000000 + TRINKET) .. ":14:14:0:0:64:64:5:59:5:59|t")
end)

test("icon rule: the new-best toast's class and spec icons are cropped and edged in the HUD's border", function()
    -- red under: BestToast's bare class and spec textures: the full art, no edge.
    local i, NS = inst()
    mkRun(NS, "old", 100, { date = NOW - 2 * HOUR })
    local new = mkRun(NS, "new", 200)
    NS.Bests.Invalidate()
    NS.SendBus(NS.MSG.RACE_RESULT, new)
    local w = assert(NS.BestToast.Instance():Frame().dpsRace, "the toast's rows")
    cellCropped(i, w.class, "WARLOCK", "the toast's class icon")
    local color, opts = edge(i, w.class, "the toast's class icon")
    assertTrue(opts.hud == true and opts.zoom == false, "the HUD edge, the cell coords left alone")
    assertEqual(color, token(i, "icon.border"), "the toast's class icon: the HUD's black")
    cropped(w.spec, "the toast's spec icon")
    color, opts = edge(i, w.spec, "the toast's spec icon")
    assertTrue(opts.hud == true, "the toast's spec icon: the HUD edge")
    assertEqual(color, token(i, "icon.border"), "the toast's spec icon: the HUD's black")
end)
