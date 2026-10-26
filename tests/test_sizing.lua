-- tests/test_sizing.lua — smooth resizing (modules/Sizing.lua), the one pattern the Results window, the
-- ability timeline and the Race HUD size by: while the grip is held each size change runs the window's
-- cheap layout, at most once a frame (a second change in one frame waits for one C_Timer.After(0)),
-- and the release runs the full redraw once, then stores the size. A size change the grip did not start
-- redraws at once. Each window's case drives a 30-frame drag and counts its expensive path: the Runs
-- list's rebind and the detail's layout, the timeline's tick pool, the HUD bodies' layout and redraw.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local NOW = os.time()
local HOUR = 3600
local FRAME = 1 / 60

--- Count the calls to `obj[name]`, still calling through.
local function spy(obj, name)
    local s = { n = 0 }
    local orig = obj[name]
    rawset(obj, name, function(...)
        s.n = s.n + 1
        return orig(...)
    end)
    return s
end

--- The size the library reads off the frame at the release (the widget recorder answers 0 for every
--- geometry read, which the library takes for "cannot say").
local function released(frame, w, h)
    rawset(frame, "GetWidth", function() return w end)
    rawset(frame, "GetHeight", function() return h end)
end

--- `n` size changes, one a frame: the clock moves on a frame before each.
local function drag(M, frame, n, size)
    for k = 1, n do
        M.__now = M.__now + FRAME
        frame:__fire("OnSizeChanged", size(k))
    end
end

-- ── the pattern ─────────────────────────────────────────────────────────────────────────────────

local function bare()
    local i = T.load{}
    local f = i.mocks.CreateFrame("Frame", nil, i.mocks.UIParent)
    f:SetSize(400, 300)
    local c = { size = 0, layout = 0, redraw = 0, done = 0, gate = true }
    i.NS.Sizing.MakeResizable(f, {
        minWidth = 200, minHeight = 100,
        canResize = function() return c.gate end,
        size = function() c.size = c.size + 1 end,
        layout = function() c.layout = c.layout + 1 end,
        redraw = function() c.redraw = c.redraw + 1 end,
        done = function(w, h) c.done, c.w, c.h = c.done + 1, w, h end,
    })
    return i, f, c
end

test("sizing: a size change the grip did not start redraws at once", function()
    local i, f, c = bare()
    assertTrue(f.resizeGrip ~= nil, "no grip")
    f:__fire("OnSizeChanged", 500, 300)
    assertEqual(c.size, 1)
    assertEqual(c.redraw, 1)
    assertEqual(c.layout, 0)
    assertFalse(i.NS.Sizing.IsSizing(f))
end)

test("sizing: while the grip is held, one cheap layout a frame; one redraw on release", function()
    local i, f, c = bare()
    local M = i.mocks
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    assertTrue(i.NS.Sizing.IsSizing(f))
    drag(M, f, 30, function(k) return 400 + k, 300 end)
    assertEqual(c.layout, 30, "one cheap layout a frame")
    assertEqual(c.redraw, 0, "no redraw while the grip is held")
    assertEqual(c.size, 30)
    f:__setGeom(430, 300)
    f.resizeGrip:__fire("OnMouseUp")
    assertEqual(c.redraw, 1, "one redraw on release")
    assertEqual(c.done, 1)
    assertEqual(c.w, 430, "the released size is handed on to be stored")
    assertFalse(i.NS.Sizing.IsSizing(f))
end)

test("sizing: changes inside one frame coalesce into one layout now and one next frame", function()
    local i, f, c = bare()
    local M = i.mocks
    M.__now = 10
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    for k = 1, 30 do f:__fire("OnSizeChanged", 400 + k, 300) end
    assertEqual(c.layout, 1, "the first change of the frame lays out at once")
    M.__fireTimers()
    assertEqual(c.layout, 2, "the rest, once, on the next frame")
    M.__fireTimers()
    assertEqual(c.layout, 2, "nothing left queued")
    -- A deferred layout the release overtakes does not run after it.
    f:__fire("OnSizeChanged", 450, 300)
    f.resizeGrip:__fire("OnMouseUp")
    local after = c.layout
    M.__fireTimers()
    assertEqual(c.layout, after, "the release's redraw is the last word")
    assertEqual(c.redraw, 1)
end)

test("sizing: a right press or a refused gate starts no drag", function()
    local i, f, c = bare()
    f.resizeGrip:__fire("OnMouseDown", "RightButton")
    assertFalse(i.NS.Sizing.IsSizing(f))
    c.gate = false
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    assertFalse(i.NS.Sizing.IsSizing(f), "the gate refused")
    f:__fire("OnSizeChanged", 450, 300)
    assertEqual(c.redraw, 1, "a change outside a drag redraws")
    f.resizeGrip:__fire("OnMouseUp")
    assertEqual(c.done, 0, "a release that ends no drag stores nothing")
end)

test("sizing: a hide while the grip is held ends the drag as a release would", function()
    local i, f, c = bare()
    local M = i.mocks
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    drag(M, f, 5, function(k) return 400 + k, 300 + k end)
    assertEqual(c.redraw, 0)
    f:Hide()
    f:__fire("OnHide")
    assertFalse(i.NS.Sizing.IsSizing(f), "the drag outlived the hide")
    assertEqual(c.redraw, 1, "the hide redraws in full")
    assertEqual(c.done, 1)
    assertEqual(c.w, 405, "the last size the drag reached is stored")
    assertEqual(c.h, 305)
    assertEqual(f.__stopCount, 1, "sizing stopped")
    -- A plain hide, with no drag under way, does nothing.
    f:__fire("OnHide")
    assertEqual(c.redraw, 1)
    assertEqual(c.done, 1)
end)

-- ── the Results window ──────────────────────────────────────────────────────────────────────────

local function resultsInst()
    local i = T.load{ mutate = function(m)
        Widgets.install(m)
        m.__context.name, m.__context.realm = "Lanfear", "Frostmourne"
        m.GetSpecialization = function() return 1 end
        m.GetSpecializationInfo = function() return 267, "Destruction" end
        m.StaticPopup_Show = function() end
    end }
    i.R = i.NS.Results
    return i
end

--- A stored-shape complete 3:00 cleave run by Lanfear (Destruction), `n` hours ago.
local function mkRun(id, n)
    return {
        id = id, schema = 1, status = "complete", addon = "0.1.0", date = NOW - n * HOUR,
        race = { length = 180, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction" },
        target = { npcID = 225983, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = 26560000 + n, dps = 147555 + n, tail = 9 },
        flags = { lateCasts = {} }, spells = { { id = 29722, dmg = 7330000 } }, note = "",
    }
end

local function seeded()
    local i = resultsInst()
    for n = 1, 40 do i.NS.db.global.runs["r" .. n] = mkRun("r" .. n, n) end
    i.NS.Bests.Invalidate()
    i.R.ShowRun("r1")
    local u = i.R.__ui()
    u.panes.runs:SetFilter("group", "none")
    return i, u
end

test("results sizing: a 30-frame drag rebinds no row and redraws no detail until the release", function()
    local i, u = seeded()
    local list = u.panes.runs.list
    local binds, details = spy(list, "Bind"), spy(u.detail, "Layout")
    local shown = #list:Visible()
    local grip = u.frame.resizeGrip
    grip:__fire("OnMouseDown", "LeftButton")
    drag(i.mocks, u.frame, 30, function(k) return 1344 + 4 * k, 560 + 6 * k end)
    assertEqual(binds.n, 0, "a row rebound while the grip is held")
    assertEqual(details.n, 0, "the detail redrawn while the grip is held")
    assertEqual(u.width, 1464)
    assertEqual(u.height, 740)
    assertEqual(list.width, 1464 - 2 - i.R.DETAIL_WIDTH, "the columns follow the width")
    assertTrue(#list:Visible() > shown, "the taller list shows more rows")
    assertEqual(#list:Visible(), list:visibleCount(), "as many as fit")
    for n, row in ipairs(list:Visible()) do assertTrue(row.run ~= nil, "row " .. n .. " drawn") end
    released(u.frame, 1464, 740)
    grip:__fire("OnMouseUp")
    assertEqual(binds.n, 1, "one rebind on release")
    assertEqual(details.n, 1, "one detail redraw on release")
    local w = i.NS.db.profile.windows.results.expanded
    assertEqual(w.width, 1464, "the size is stored on release")
    assertEqual(w.height, 740)
end)

test("results sizing: a drag keeps the view's minimum and shrinks the list without a rebind", function()
    local i, u = seeded()
    local list = u.panes.runs.list
    local binds = spy(list, "Bind")
    local shown = #list:Visible()
    u.frame.resizeGrip:__fire("OnMouseDown", "LeftButton")
    drag(i.mocks, u.frame, 30, function() return 900, 420 end)
    assertEqual(u.width, 1344, "never under the expanded minimum")
    assertEqual(u.height, i.R.MIN_HEIGHT)
    assertTrue(#list:Visible() < shown, "the shorter list shows fewer rows")
    assertEqual(#list:Visible(), list:visibleCount())
    assertEqual(binds.n, 0)
end)

test("results sizing: the Bests tab and the collapsed view's open detail resize without a redraw", function()
    local i, u = seeded()
    assertTrue(i.R.ShowTab("bests"))
    local bests = u.panes.bests.list
    local binds = spy(bests, "Bind")
    local grip = u.frame.resizeGrip
    grip:__fire("OnMouseDown", "LeftButton")
    drag(i.mocks, u.frame, 30, function(k) return 1344 + k, 560 + k end)
    assertEqual(binds.n, 0)
    assertEqual(bests.width, 1374 - 2, "the Bests list spans the body")
    grip:__fire("OnMouseUp")
    assertEqual(binds.n, 1)
    assertTrue(i.R.ShowTab("runs"))
    assertTrue(i.R.SetView("collapsed"))
    i.R.ShowRun("r2")
    local details = spy(u.detail, "Layout")
    grip:__fire("OnMouseDown", "LeftButton")
    drag(i.mocks, u.frame, 30, function(k) return 904 + k, 560 + k end)
    assertEqual(details.n, 0, "the open detail is not redrawn per frame")
    assertEqual(u.detail.width, 934 - 2, "but it is sized to the body")
    grip:__fire("OnMouseUp")
    assertEqual(details.n, 1)
end)

-- The first drag after the window opens (the owner's fourth round, 2026-10-27). In the client a
-- size change can reach the window while a list is drawing its rows: the first row the open shows can
-- resolve the window's rect and run its OnSizeChanged right there, a full layout nested inside the
-- outer one's pool loop. Modeled here as that size change fired from inside the list's first Acquire
-- of the open's layout. The drag then re-places the rows the list holds: a row the nested draw left
-- shown but the list no longer holds stays where it was, its cells over the moved ones.

-- The x each cell was placed at (the bar column's text sits 2 px in from its column).
local function cellX(cell, col)
    local kind = col.kind or "text"
    local part = (kind == "icons" and cell.class) or (kind == "badge" and cell.box)
        or (kind == "items" and cell.dash) or cell.fs
    local p = part.__points and part.__points[1]
    if not p then return nil end
    return (kind == "text" and cell.bar) and p[4] - 2 or p[4]
end

--- Every shown row is one the list holds, and every cell it holds sits at its column's x now.
local function assertPlaced(list, label)
    local held = {}
    for n, row in ipairs(list:Visible()) do
        held[row] = true
        for c, col in ipairs(list.columns) do
            assertEqual(cellX(row.cells[c], col), list.place[c].x, ("%s: row %d, %s"):format(label, n, col.key))
        end
    end
    for _, row in ipairs(list.pool.active) do
        assertTrue(held[row] or not row:IsShown(), label .. ": a shown row the list does not hold")
    end
end

--- Reopen the window with a size change fired from inside `list`'s first Acquire of the layout.
local function reopenWithNestedSize(i, u, list)
    i.R.Hide()
    local NS, orig, armed, fired = i.NS, list.Layout, false, false
    rawset(list, "Layout", function(...)
        if not fired then armed = true end
        return orig(...)
    end)
    local acquire = NS.Pool.Acquire
    rawset(NS.Pool, "Acquire", function(pool, ...)
        local o = acquire(pool, ...)
        if armed and pool == list.pool then
            armed, fired = false, true
            u.frame:__fire("OnSizeChanged", u.width, u.height)
        end
        return o
    end)
    i.R.Show()
    rawset(NS.Pool, "Acquire", acquire)
    rawset(list, "Layout", nil)
    assertTrue(fired, "the nested size change fired")
end

local function firstDrag(i, u, list, w0, h0, label)
    assertPlaced(list, label .. " opened")
    local grip = u.frame.resizeGrip
    grip:__fire("OnMouseDown", "LeftButton")
    drag(i.mocks, u.frame, 30, function(k) return w0 + 6 * k, h0 + 6 * k end)
    assertPlaced(list, label .. " dragged")
    released(u.frame, w0 + 180, h0 + 180)
    grip:__fire("OnMouseUp")
    assertPlaced(list, label .. " released")
end

test("results sizing: the first drag after opening moves every row's cells, none left behind", function()
    local i, u = seeded()
    u.panes.runs:SetFilter("group", "full")
    local list = u.panes.runs.list
    reopenWithNestedSize(i, u, list)
    firstDrag(i, u, list, 1344, 560, "runs")
end)

test("results sizing: the Bests tab's first drag after opening leaves no row behind", function()
    local i, u = seeded()
    -- A board of ten rows: one best per race length.
    for n = 1, 10 do i.NS.db.global.runs["r" .. n].race.length = 30 * n end
    i.NS.Bests.Invalidate()
    assertTrue(i.R.ShowTab("bests"))
    local list = u.panes.bests.list
    assertTrue(#list:Visible() >= 10, "the board shows ten rows")
    reopenWithNestedSize(i, u, list)
    firstDrag(i, u, list, 1344, 560, "bests")
end)

-- The drag's own half of the guard: the cheap layout's fitRows adds the rows a taller list fits, and a
-- full rebind run inside the first added row's Show (the client draws on Show) has drawn the slice
-- already; the fit stops there instead of laying a second set of rows over the rebind's.
test("results sizing: a rebind inside a row the drag adds leaves no second row behind", function()
    local i, u = seeded()
    local NS, list = i.NS, u.panes.runs.list
    local shown, nested = #list:Visible(), 0
    local acquire = NS.Pool.Acquire
    rawset(NS.Pool, "Acquire", function(pool, ...)
        local row = acquire(pool, ...)
        if pool == list.pool and nested == 0 then
            local show = row.Show
            rawset(row, "Show", function(...)
                rawset(row, "Show", show)
                show(...)
                nested = nested + 1
                list:Bind()
            end)
        end
        return row
    end)
    local grip = u.frame.resizeGrip
    grip:__fire("OnMouseDown", "LeftButton")
    -- One frame's jump of 180 px: several rows added in one fit, the rebind inside the first.
    drag(i.mocks, u.frame, 1, function() return 1344, 740 end)
    rawset(NS.Pool, "Acquire", acquire)
    assertEqual(nested, 1, "the rebind ran inside an added row's Show")
    assertTrue(#list:Visible() > shown + 1, "the taller list shows several more rows")
    assertEqual(#list:Visible(), list:visibleCount(), "as many as fit")
    assertPlaced(list, "dragged")
    released(u.frame, 1344, 740)
    grip:__fire("OnMouseUp")
    assertPlaced(list, "released")
end)

-- ── the ability timeline ────────────────────────────────────────────────────────────────────────

local SPELLS = { [1122] = 180000, [29722] = 0 }

local function timelineRun(NS, id, dps, list, ago)
    local decoded = {}
    for n, c in ipairs(list) do decoded[n] = { t = c[1], id = c[2] } end
    return {
        id = id, schema = 3, status = "complete", addon = "0.1.0", date = NOW - ago * HOUR,
        race = { length = 60, grace = 1.0 },
        char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction" },
        target = { npcID = 225983, name = "Cleave Training Dummy", category = "cleave" },
        result = { damage = dps * 60, dps = dps, tail = 2 },
        flags = { lateCasts = {} }, spells = { { id = 29722, dmg = dps * 50 } }, note = "",
        casts = { v = 1, list = NS.Casts.Encode(decoded), spells = SPELLS, dropped = 0 },
    }
end

test("timeline sizing: a 30-frame drag moves the ticks and the cast icons and re-pools nothing until the release", function()
    local i = resultsInst()
    local NS = i.NS
    NS.db.global.runs.this = timelineRun(NS, "this", 100, { { 1, 1122 }, { 2, 29722 }, { 30, 29722 } }, 1)
    NS.db.global.runs.best = timelineRun(NS, "best", 300, { { 3, 29722 }, { 50, 29722 } }, 2)
    NS.Bests.Invalidate()
    i.R.ShowRun("this")
    i.R.__ui().detail.w.timeline:__fire("OnClick")
    local u = NS.ResultsTimeline.__ui()
    local churn, iconChurn = { n = 0 }, { n = 0 }
    local release = NS.Pool.ReleaseAll
    rawset(NS.Pool, "ReleaseAll", function(pool, ...)
        if pool == u.markPool then churn.n = churn.n + 1 end
        if pool == u.iconPool then iconChurn.n = iconChurn.n + 1 end
        return release(pool, ...)
    end)
    local grip = u.frame.resizeGrip
    grip:__fire("OnMouseDown", "LeftButton")
    drag(i.mocks, u.frame, 30, function(k) return 700 + 10 * k, 400 + k end)
    rawset(NS.Pool, "ReleaseAll", release)
    assertEqual(churn.n, 0, "the ticks re-pooled while the grip is held")
    assertEqual(u.width, 1000)
    local TL = NS.ResultsTimeline
    local _, laneX, laneW = TL.LaneGeometry(1000)
    local mark = NS.ResultsTimeline.Marks()[1]
    assertEqual(mark.x, laneX + TL.MarkX(mark.cast.t, u.span, laneW), "each tick moved along its stretched lane")
    -- The cast icons too: moved along their strip on the rows they had, none re-pooled.
    local icon = TL.Icons()[1]
    assertEqual(icon.x, laneX + TL.MarkX(icon.cast.t, u.span, laneW), "each icon moved along its stretched strip")
    assertEqual(iconChurn.n, 0, "the icons re-pooled while the grip is held")
    rawset(NS.Pool, "ReleaseAll", function(pool, ...)
        if pool == u.markPool then churn.n = churn.n + 1 end
        return release(pool, ...)
    end)
    released(u.frame, 1000, 430)
    grip:__fire("OnMouseUp")
    rawset(NS.Pool, "ReleaseAll", release)
    assertEqual(churn.n, 1, "one full redraw on release")
    assertEqual(#NS.ResultsTimeline.Icons(), 5, "the icons rebuilt on release, every cast of both runs")
    assertEqual(NS.db.profile.windows.timeline.width, 1000)
end)

-- ── the Race HUD ────────────────────────────────────────────────────────────────────────────────

test("hud sizing: a 30-frame drag lays out the body on screen alone; the release lays out all and redraws", function()
    local f = RaceClock.new{ mutate = function(m) Widgets.install(m) end }
    f.NS.Hud.Show()
    assertTrue(f:arm(30))
    local u = f.NS.Hud.__ui()
    local layouts, updates, built = {}, {}, 0
    for key, body in pairs(u.body) do
        built = built + 1
        layouts[key] = body.Layout and spy(body, "Layout") or { n = 0 }
        updates[key] = spy(body, "Update")
    end
    assertTrue(built >= 2, "the idle and the armed bodies are both built")
    local grip = u.frame.resizeGrip
    grip:__fire("OnMouseDown", "LeftButton")
    drag(f.M, u.frame, 30, function(k) return 300 + k, 400 + k end)
    for key, body in pairs(u.body) do
        local laid = (key == u.current and body.Layout) and 30 or 0
        assertEqual(layouts[key].n, laid, key .. ": laid out per frame")
        assertEqual(updates[key].n, 0, key .. ": redrawn while the grip is held")
    end
    released(u.frame, 330, 430)
    grip:__fire("OnMouseUp")
    for key, body in pairs(u.body) do
        if body.Layout then assertTrue(layouts[key].n >= 1, key .. ": not laid out on release") end
        assertEqual(updates[key].n, key == u.current and 1 or 0, key .. ": the shown body redrawn once")
    end
    assertEqual(f.NS.db.profile.windows.hud.width, 330)
end)

test("hud sizing: locked, the grip starts no drag", function()
    local f = RaceClock.new{ mutate = function(m) Widgets.install(m) end }
    f.NS.Hud.Show()
    assertTrue(f.NS.SetByPath("locked", true))
    local u = f.NS.Hud.__ui()
    u.frame.resizeGrip:__fire("OnMouseDown", "LeftButton")
    assertFalse(f.NS.Sizing.IsSizing(u.frame))
end)
