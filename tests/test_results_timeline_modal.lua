-- tests/test_results_timeline_modal.lua — the ability timeline as a modal over the Results window (P13,
-- modules/Results_Timeline.lua and modules/Results.lua): one strata above the window, a shown
-- StaticPopup re-raised on open; the dim cover over the Results window shown and hidden with the
-- timeline, taking the mouse and the wheel over every level of the window, closing its menu and
-- tooltip; Escape closing the timeline before the window (in either close-stack order, and with the
-- talent tree's panel open); the cover gone with the window, at stand-down and on a source switch;
-- and the timeline's opaque skin.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600
local INFERNAL, CONFLAG, INCINERATE = 1122, 17962, 29722
local SPELLS = { [INFERNAL] = 180000, [CONFLAG] = 13000, [INCINERATE] = 0 }

local function inst(mutate)
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
        if mutate then mutate(m) end
    end }
    i.R, i.TL = i.NS.Results, i.NS.ResultsTimeline
    return i
end

--- A stored-shape complete 1:00 cleave run by Lanfear (Destruction) with a few casts.
local function mkRun(NS, id, dps, fields)
    local decoded = { { t = 1, id = INFERNAL }, { t = 2, id = INCINERATE }, { t = 4, id = CONFLAG } }
    local run = {
        id = id, schema = 3, status = "complete", addon = "0.1.0", date = NOW - HOUR,
        race = { length = 60, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction" },
        target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 60, dps = dps, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = INCINERATE, dmg = dps * 50 } }, note = "",
        casts = { v = 1, list = NS.Casts.Encode(decoded), spells = SPELLS, dropped = 0 },
    }
    for k, v in pairs(fields or {}) do run[k] = v end
    return run
end

-- "this" under "best" on one board; the timeline open on "this".
local function opened(mutate, before)
    local i = inst(mutate)
    local NS = i.NS
    if before then before(i) end
    NS.db.global.runs.this = mkRun(NS, "this", 100)
    NS.db.global.runs.best = mkRun(NS, "best", 300, { date = NOW - 2 * HOUR })
    NS.Bests.Invalidate()
    i.R.ShowRun("this")
    i.R.__ui().detail.w.timeline:__fire("OnClick")
    assertTrue(i.TL.IsShown(), "the timeline opened")
    return i, i.R.__ui(), i.TL.__ui()
end

-- Blizzard's close stack (CloseSpecialWindows): each shown UISpecialFrames entry hidden, in `order`,
-- then the next frame.
local function escape(i, order)
    for _, f in ipairs(order) do
        if f:IsShown() then
            f:Hide()
            f:__fire("OnHide")
        end
    end
    i.mocks.__fireTimers()
end

local function withTree(i, shown)
    local tree = { shown = shown }
    function tree:IsShown() return self.shown end
    i.mocks.PlayerSpellsFrame = tree
    return tree
end

-- ── the layer ───────────────────────────────────────────────────────────────────────────────────

test("timeline modal: the timeline sits one strata above the Results window, the cover over its every level", function()
    local i, r, u = opened()
    local lay = i.mocks.__layers
    assertEqual(lay(r.frame).strata, "HIGH")
    assertEqual(lay(u.frame).strata, "DIALOG", "LAYERS.STRATA.MODAL, frame-layering-§1's T6")
    assertTrue(lay(u.frame).toplevel)
    assertTrue(lay(u.frame).clamped)
    local W = lay(r.frame).level
    assertEqual(lay(r.cover).level, W + i.NS.Constants.LAYERS.LEVEL.COVER)
    assertTrue(lay(r.cover).level > W + 10, "over the library grip (+10)")
    assertTrue(lay(r.cover).level > lay(r.detail.content).level, "over the detail's content")
    assertEqual(lay(r.cover).strata, "HIGH", "in the window's own strata (a popover band, not a strata jump)")
end)

test("timeline modal: opening it re-raises a shown StaticPopup (frame-layering-§4)", function()
    -- Hidden through the load: the first-run skin picker shows on the login fuse the harness fires,
    -- and it re-raises a shown popup itself (LibKa0s OptionsSkinPicker); this counts the timeline's.
    local popup = { raised = 0, shown = false }
    function popup:IsShown() return self.shown end
    function popup:Raise() self.raised = self.raised + 1 end
    local i = opened(function(m) m.StaticPopup1 = popup end, function() popup.shown = true end)
    assertEqual(popup.raised, 1, "a delete confirmation shown first stays answerable")
    i.TL.Hide()
    popup.shown = false
    i.TL.Open(i.R.__ui().detail)
    assertEqual(popup.raised, 1, "a hidden popup is left alone")
end)

-- ── the cover ───────────────────────────────────────────────────────────────────────────────────

test("timeline modal: the cover dims the Results window and takes its mouse and wheel while the timeline is open", function()
    local i, r = opened()
    assertTrue(i.R.IsCovered())
    assertTrue(r.cover:IsShown())
    assertTrue(r.cover.__mouse, "the cover takes the mouse: no hover or click reaches the window behind")
    assertTrue(r.cover.__wheel, "and the wheel: the lists behind do not scroll")
    local c = r.cover.dim.__colorTex
    assertEqual(c[1] + c[2] + c[3], 0, "black")
    assertTrue(c[4] >= 0.4 and c[4] <= 0.5, "dim, not opaque")
    r.cover:__fire("OnMouseDown", "LeftButton")
    r.cover:__fire("OnMouseUp", "LeftButton")
    assertTrue(i.TL.IsShown(), "a click on the cover does nothing")
    i.TL.Hide()
    assertFalse(i.R.IsCovered(), "closing the timeline lifts the cover")
    i.R.__ui().detail.w.timeline:__fire("OnClick")
    assertTrue(i.R.IsCovered(), "and opening it again puts it back")
    local close = i.TL.__ui().close
    if close then
        close:__fire("OnClick")
        assertFalse(i.R.IsCovered(), "its close control lifts the cover")
    end
end)

test("timeline modal: putting the cover up closes the window's menu and tooltip", function()
    local i = inst()
    local NS = i.NS
    NS.db.global.runs.this = mkRun(NS, "this", 100)
    i.R.ShowRun("this")
    local closed, tips = 0, 0
    local closeMenu, hideTip = NS.CloseMenu, NS.ResultsTable.HideTip
    NS.CloseMenu = function(...) closed = closed + 1; return closeMenu(...) end
    NS.ResultsTable.HideTip = function(...) tips = tips + 1; return hideTip(...) end
    i.R.SetCovered(true)
    NS.CloseMenu, NS.ResultsTable.HideTip = closeMenu, hideTip
    assertTrue(closed >= 1, "a filter menu would act on the window behind")
    assertTrue(tips >= 1, "a Results tooltip would show through")
end)

test("timeline modal: the cover goes with the Results window, at stand-down and on a source switch", function()
    local i, r = opened()
    i.R.Hide()
    assertFalse(i.TL.IsShown())
    assertFalse(r.cover:IsShown(), "closed with the window")
    i.R.ShowRun("this")
    assertFalse(i.R.IsCovered(), "the window comes back uncovered")
    r.detail.w.timeline:__fire("OnClick")
    assertTrue(i.R.IsCovered())
    assertTrue(i.NS.SetByPath("enabled", false))
    assertFalse(i.TL.IsShown())
    assertFalse(r.cover:IsShown(), "the stand-down lifts it")
    assertTrue(i.NS.SetByPath("enabled", true))
    i.R.ShowRun("this")
    r.detail.w.timeline:__fire("OnClick")
    assertTrue(i.R.IsCovered())
    assertTrue(i.NS.ResultsSource.Use({ runs = {} }), "test mode's sample history")
    assertFalse(i.TL.IsShown(), "the timeline followed a run the sample does not hold")
    assertFalse(i.R.IsCovered(), "a source switch lifts it")
    assertTrue(r.frame:IsShown(), "the window stays")
end)

-- ── Escape ──────────────────────────────────────────────────────────────────────────────────────

test("timeline modal: Escape closes the timeline before the Results window, in either close-stack order", function()
    local i, r, u = opened()
    escape(i, { r.frame, u.frame })
    assertFalse(i.TL.IsShown(), "the first Escape closes the timeline")
    assertTrue(i.R.wanted, "and leaves the Results window")
    assertTrue(r.frame:IsShown())
    assertFalse(i.R.IsCovered(), "uncovered once the close stack is done")
    escape(i, { r.frame, u.frame })
    assertFalse(i.R.wanted, "the second closes the window")
    assertFalse(r.frame:IsShown())
    -- The timeline first in the stack.
    i.R.ShowRun("this")
    r.detail.w.timeline:__fire("OnClick")
    escape(i, { u.frame, r.frame })
    assertFalse(i.TL.IsShown())
    assertTrue(i.R.wanted)
    assertTrue(r.frame:IsShown())
    assertFalse(i.R.IsCovered())
end)

test("timeline modal: the talent tree's panel open closes the timeline and sends the window aside", function()
    local i, r, u = opened()
    local tree = withTree(i, false)
    -- CloseWindows, then the tree shows, then the next frame.
    r.frame:Hide()
    r.frame:__fire("OnHide")
    u.frame:Hide()
    u.frame:__fire("OnHide")
    tree.shown = true
    i.mocks.__fireTimers()
    assertFalse(i.TL.IsShown())
    assertFalse(i.R.IsCovered())
    assertFalse(r.frame:IsShown(), "the window is not left over the tree")
    assertTrue(i.R.AwaitingTree(), "it waits for the tree")
    tree.shown = false
    i.mocks.__fireTimers()
    assertTrue(r.frame:IsShown(), "and comes back when the tree closes")
    assertFalse(i.TL.IsShown(), "the timeline stays closed")
end)

-- ── the skin ────────────────────────────────────────────────────────────────────────────────────

test("timeline modal: the timeline's skin is opaque, nothing of the Results window shows through", function()
    -- Under the kit's paint recorder, so the Shell's backdrop is readable.
    local i, _, u = opened(function(m) dofile(T.root .. "/tests/_kit/mock_paint.lua")(m) end)
    local NS = i.NS
    -- The skin's Shell with its fill, inner rule and divider remapped to the opaque owner tokens
    -- (DR-G1); the gear view wears the same.
    local tokens = NS.ResultsTimeline.SHELL.tokens
    assertEqual(tokens.bg, "dr.modal.bg")
    assertEqual(tokens.inner, "dr.modal.inner")
    assertEqual(tokens.divider, "dr.modal.divider")
    assertEqual(NS.ResultsGear.SHELL, NS.ResultsTimeline.SHELL)
    -- Every one opaque, in Ka0s Default and in every other skin's own entry.
    for _, name in ipairs({ "dr.modal.bg", "dr.modal.inner", "dr.modal.divider" }) do
        local def = NS.SKIN_TOKENS[name]
        assertEqual(def.default[4], 1, name .. ": Ka0s Default at alpha 1")
        for key, c in pairs(def.skins or {}) do assertEqual(c[4], 1, name .. ": " .. key .. " at alpha 1") end
        assertEqual(select(4, NS.Skin.Color(name)), 1, name .. " resolves opaque")
    end
    local r, g, b, a = u.frame:GetBackdropColor()
    local fill = NS.Skin.Token("dr.modal.bg")
    assertEqual(a, 1, "the fill drawn at alpha 1")
    assertTrue(r == fill[1] and g == fill[2] and b == fill[3], "the fill is the opaque token's")
    -- The blend keeps the shared look: the inner rule reads as it does over the shared fill.
    local bg, inner = NS.Skin.Token("win.bg"), NS.Skin.Token("win.inner")
    local want = inner[1] * inner[4] + bg[1] * (1 - inner[4])
    assertTrue(math.abs(NS.Skin.Token("dr.modal.inner")[1] - want) < 1e-9, "blended over the fill")
    assertTrue(bg[4] < 1, "the shared window fill itself is untouched")
end)
