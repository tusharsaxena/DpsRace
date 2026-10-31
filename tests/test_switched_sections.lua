-- tests/test_switched_sections.lua — sections a selector does not pick (options-ui-§22, LibKa0s#67).
--
-- Race clock picks which of HUD Appearance's two clock font blocks style anything, so each is drawn
-- only while it is picked. The selector sits on the Race HUD tab and the blocks on HUD Appearance, so
-- a tab's own render reads the choice. Each case drives a real render and reads what the scroll draws.
local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

--- The HUD page, on screen, open on HUD Appearance.
local function shownPage()
    local inst = T.load()
    inst.mocks.__subcategories["HUD"]:__fire("OnShow")
    local ctx = inst.NS.pageCtx.hud
    ctx.panel:Show()
    inst.NS.Helpers.SelectTab("hud", inst.NS.L["HUD Appearance"])
    return inst, ctx
end

--- Every widget under `w`, depth first.
local function walk(w, out)
    for _, child in ipairs(w.children or {}) do
        out[#out + 1] = child
        walk(child, out)
    end
    return out
end

--- Whether a widget labeled `label` is in the page's scroll.
local function drawn(inst, ctx, label)
    for _, w in ipairs(walk(ctx.scroll, {})) do
        if w.labelText == inst.NS.L[label] or w.text == inst.NS.L[label] then return true end
    end
    return false
end

--- Choose `mode`, as the Race HUD tab's dropdown stores it, then draw HUD Appearance again.
local function choose(inst, mode)
    local H = inst.NS.Helpers
    H.SelectTab("hud", inst.NS.L["Race HUD"])
    inst.NS.SetByPath("hud.clock", mode)
    H.SelectTab("hud", inst.NS.L["HUD Appearance"])
end

test("switched sections: Race clock draws only the clock blocks it picks, and a hidden one comes back", function()
    -- red under: the clock blocks always drawn
    local inst, ctx = shownPage()
    assertEqual(inst.NS.GetSetting("hud.clock"), "both")
    assertTrue(drawn(inst, ctx, "Elapsed clock"), "both picked: the elapsed block")
    assertTrue(drawn(inst, ctx, "Time left clock"), "both picked: the time left block")
    choose(inst, "left")
    assertFalse(drawn(inst, ctx, "Elapsed clock"), "nobody picks the elapsed clock, heading included")
    assertTrue(drawn(inst, ctx, "Time left clock"))
    assertTrue(drawn(inst, ctx, "Live figures"), "the next block stays")
    choose(inst, "elapsed")
    assertTrue(drawn(inst, ctx, "Elapsed clock"), "and it comes back")
    assertFalse(drawn(inst, ctx, "Time left clock"))
    choose(inst, "both")
    assertTrue(drawn(inst, ctx, "Elapsed clock"))
    assertTrue(drawn(inst, ctx, "Time left clock"))
end)

test("switched sections: the page's Defaults on HUD Appearance brings a hidden clock block back at once", function()
    -- red under: a Defaults that only runs refreshers, so `hud.clock` returns to both with no render
    -- (its selector row is on the other tab, so this render holds no watcher for it)
    local inst, ctx = shownPage()
    choose(inst, "left")
    assertFalse(drawn(inst, ctx, "Elapsed clock"))
    ctx.panel.defaultsOnClick()
    assertEqual(inst.NS.GetSetting("hud.clock"), "both")
    assertTrue(drawn(inst, ctx, "Elapsed clock"), "with no tab change")
    assertTrue(drawn(inst, ctx, "Time left clock"))
end)

test("switched sections: a hidden clock block's rows stay in the schema, so a reset reaches them", function()
    -- red under: dropping the rows from the schema in place of `shownWhen`
    local inst = T.load()
    local NS = inst.NS
    local found = 0
    for _, row in ipairs(NS.Schema) do
        if row.path and row.path:find("^appearance%.elapsed%.") then
            found = found + 1
            assertEqual(row.shownWhen.path, "hud.clock")
        end
    end
    assertTrue(found > 0, "the elapsed block's rows")
    local size = NS.defaults.profile.appearance.elapsed.fontSize
    NS.SetByPath("hud.clock", "left")
    NS.SetByPath("appearance.elapsed.fontSize", size + 2)
    for _, row in ipairs(NS.Schema) do
        if row.path == "appearance.elapsed.fontSize" then NS.ApplyDefault(row) end
    end
    assertEqual(NS.GetSetting("appearance.elapsed.fontSize"), size)
end)
