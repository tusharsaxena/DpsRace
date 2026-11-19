-- tests/test_window_chrome.lua — the window chrome geometry of the HUD and the Results window
-- (WowAddonStandards v2.113.0: preview-mode's *Where the strip sits*, standalone-windows' *Window chrome
-- geometry* and *The footer*; LibKa0s#88 and #89, items AD-88-DR and AD-89-DR).
--
-- Both are windows: the HUD is a race window with a title bar, which the standard counts as a window
-- whatever the addon calls it. So each mode strip is docked by the library (`dock = "title"`) directly
-- under the title bar, above the tabs and the body, and everything below the title bar moves down by
-- the strip's `BodyOffset()` while it shows. Each window's footer is the library's `W.Footer`,
-- `FOOTER.HEIGHT` (24 px) tall, and the body ends that far above the window's bottom edge.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
local Widgets = dofile(T.root .. "/tests/mock_widgets.lua")(T)

local STRIP_H = 18   -- the library's TEST_STRIP.HEIGHT, what a shown strip measures in the client

local function fixture()
    local W
    local f = RaceClock.new{ mutate = function(m) W = Widgets.install(m) end }
    f.W, f.Hud, f.Preview, f.R = W, f.NS.Hud, f.NS.Preview, f.NS.Results
    return f
end

local function hudUi(f) return assert(f.Hud.__ui(), "the HUD window was never built") end
local function resUi(f) return assert(f.R.__ui(), "the Results window was never built") end

-- The last point named `name` a frame was given (the recorder appends; SetPoint replaces in the client).
local function lastPoint(frame, name)
    local found
    for _, p in ipairs(frame.__points or {}) do
        if p[1] == name then found = p end
    end
    return assert(found, "no " .. name .. " point")
end

-- The recorder's geometry reads answer 0; give a built strip the height it has in the client.
local function measured(strip)
    rawset(strip, "GetHeight", function() return STRIP_H end)
    return strip
end

-- A strip the library docked under `band`: it carries the dock's methods and sits flush under the band.
local function dockedUnder(strip, band, what)
    -- rawget: the recorder answers any method name, so only the dock's own fields tell it was docked.
    assertEqual(type(rawget(strip, "BodyOffset")), "function", what .. ": not docked by the library (no BodyOffset)")
    assertEqual(type(rawget(strip, "Place")), "function", what .. ": not docked by the library (no Place)")
    assertEqual(strip:IsFlipped(), false, what .. ": a window's strip never flips")
    local tl, tr = lastPoint(strip, "TOPLEFT"), lastPoint(strip, "TOPRIGHT")
    assertTrue(tl[2] == band and tl[3] == "BOTTOMLEFT" and tl[4] == 0 and tl[5] == 0,
        what .. ": not directly under the title bar")
    assertTrue(tr[2] == band and tr[3] == "BOTTOMRIGHT" and tr[4] == 0 and tr[5] == 0,
        what .. ": not full width under the title bar")
end

-- ── #88: the docked strip ──────────────────────────────────────────────────────────────────────

test("chrome: the HUD's test strip is docked under its title bar, and the content moves by its offset", function()
    local f = fixture()
    f.Hud.Show()
    assertTrue(f.Preview.Start())
    local u = hudUi(f)
    local band = f.NS.Style.Band(u.frame)
    local strip = measured(assert(u.strip, "no test strip on the HUD"))
    dockedUnder(strip, band, "the HUD's test strip")
    -- The menu that ends the mode stays: a window's strip keeps its mouse (only a HUD display's loses it).
    assertTrue(strip.__mouse ~= false, "the window strip lost its mouse")
    local top = -lastPoint(u.content, "TOPLEFT")[5]
    f.Preview.Stop()
    local bare = -lastPoint(u.content, "TOPLEFT")[5]
    assertTrue(f.Preview.Start())
    assertEqual(strip:BodyOffset(), STRIP_H)
    assertEqual(-lastPoint(u.content, "TOPLEFT")[5] - bare, STRIP_H, "the content moves down by BodyOffset")
    assertTrue(top >= bare)
    f.Preview.Stop()
end)

test("chrome: the HUD's sim strip is docked under its title bar too", function()
    local f = fixture()
    f.Hud.Show()
    assertTrue(f.Preview.Start({ mode = "sim", scenario = f.NS.Sim.DEFAULT }))
    local u = hudUi(f)
    local sim = assert(u.simStrip, "no sim strip on the HUD during a sim")
    dockedUnder(sim, f.NS.Style.Band(u.frame), "the HUD's sim strip")
    f.Preview.Stop()
end)

test("chrome: the Results strip is docked under the title bar, above the tabs, which move down with the body", function()
    local f = fixture()
    assertTrue(f.Preview.Start())
    local u = resUi(f)
    local band = f.NS.Style.Band(u.frame)
    local strip = measured(assert(u.strip, "no test strip on the Results window"))
    dockedUnder(strip, band, "the Results test strip")
    f.Preview.Stop()
    f.R.Show()
    local TAB_H = f.NS.Style.TAB_STRIP_H
    assertEqual(lastPoint(u.tabs.runs, "TOPLEFT")[5], 0, "the tabs sit flush under the band with no strip")
    assertEqual(lastPoint(u.body, "TOPLEFT")[5], -(TAB_H + 1))
    assertTrue(f.Preview.Start())
    assertEqual(strip:BodyOffset(), STRIP_H)
    for _, name in ipairs(f.R.TABS) do
        local p = lastPoint(u.tabs[name], "TOPLEFT")
        assertTrue(p[2] == band and p[5] == -STRIP_H, "the " .. name .. " tab did not move under the strip")
    end
    assertEqual(lastPoint(u.tabLine, "TOPLEFT")[5], -(TAB_H + STRIP_H), "the rule under the tabs moves with them")
    assertEqual(lastPoint(u.body, "TOPLEFT")[5], -(TAB_H + 1 + STRIP_H), "the body moves down by BodyOffset")
    f.Preview.Stop()
    assertEqual(lastPoint(u.tabs.runs, "TOPLEFT")[5], 0, "the tabs go back up when the strip hides")
end)

test("chrome: the Results sim strip is docked under the title bar", function()
    local f = fixture()
    assertTrue(f.Preview.Start({ mode = "sim", scenario = f.NS.Sim.DEFAULT }))
    f.R.Show()
    local u = resUi(f)
    dockedUnder(assert(u.simStrip, "no sim strip on the Results window"), f.NS.Style.Band(u.frame),
        "the Results sim strip")
    f.Preview.Stop()
end)

-- ── #89: the library's footer ──────────────────────────────────────────────────────────────────

-- The footer is W.Footer's: its two lines are the window's, 24 px tall, with the grip's corner.
local function libraryFooter(u, what)
    local foot = assert(u.footer, what .. ": no footer")
    assertEqual(type(rawget(foot, "SetLeft")), "function", what .. ": not the library's Footer")
    assertEqual(type(rawget(foot, "SetGrip")), "function", what .. ": not the library's Footer")
    assertEqual(foot.__height, 24, what .. ": the footer is FOOTER.HEIGHT tall")
    assertTrue(u.footLeft == foot.left and u.footRight == foot.right, what .. ": the lines are the footer's own")
    return foot
end

test("chrome: the HUD's footer is the library's, 24 px, and the content ends above it", function()
    local f = fixture()
    f.Hud.Show()
    local u = hudUi(f)
    libraryFooter(u, "the HUD")
    assertEqual(f.NS.FOOTER_HEIGHT, 24, "FOOTER.HEIGHT, read where the library publishes it")
    assertEqual(lastPoint(u.content, "BOTTOMRIGHT")[5], f.NS.FOOTER_HEIGHT + 8, "the content's gap over the footer")
    assertTrue(u.footLeft.__text ~= nil, "the footer's left line is painted")
end)

test("chrome: the Results footer is the library's, 24 px, and the body ends above it", function()
    local f = fixture()
    f.R.Show()
    local u = resUi(f)
    libraryFooter(u, "the Results window")
    assertEqual(lastPoint(u.body, "BOTTOMRIGHT")[5], f.NS.FOOTER_HEIGHT + 1, "the body ends over the footer's rule")
    assertTrue((u.footLeft.__text or ""):find("Click a row for details", 1, true) ~= nil, "the hint is kept")
end)

test("chrome: with no Widgets library each window keeps a 24 px footer with its two lines", function()
    local inst = T.load{ libFiles = {}, mutate = function(m) Widgets.install(m) end }
    local NS = inst.NS
    NS.Hud.Show()
    NS.Results.Show()
    for what, u in pairs({ HUD = NS.Hud.__ui(), Results = NS.Results.__ui() }) do
        assertTrue(u.footer ~= nil and u.footLeft ~= nil and u.footRight ~= nil, what .. ": no footer lines")
        assertEqual(u.footer.__height, 24, what)
    end
    assertEqual(NS.FOOTER_HEIGHT, 24)
end)

-- The resize grip is built on the footer (Core minor 10's `gripParent`, the pairing W.Footer's own
-- `opts.resize` makes): it sits in the footer's bottom-right corner, which is the window's, while sizing
-- still acts on the window (`frame.resizeGrip` stays on it).
local function gripOnFooter(u, what)
    local grip = assert(u.frame.resizeGrip, what .. ": no resize grip")
    local br = lastPoint(grip, "BOTTOMRIGHT")
    assertTrue(br[2] == u.footer, what .. ": the grip is not built on the footer")
end

test("chrome: the HUD's and the Results window's resize grips are built on their footers", function()
    local f = fixture()
    f.Hud.Show()
    f.R.Show()
    gripOnFooter(hudUi(f), "the HUD")
    gripOnFooter(resUi(f), "the Results window")
end)

-- The right line's inset from the footer's right edge (its last RIGHT point's x, negated).
local function rightInset(foot)
    return -lastPoint(foot.right, "RIGHT")[4]
end

test("chrome: with no Widgets library the footer's right line follows the HUD's grip", function()
    local inst = T.load{ libFiles = {}, mutate = function(m) Widgets.install(m) end }
    local NS = inst.NS
    NS.Hud.Show()
    local foot = NS.Hud.__ui().footer
    foot:SetGrip(true)
    assertEqual(rightInset(foot), 22, "clear of the grip's corner while the grip shows")
    foot:SetGrip(false)
    assertEqual(rightInset(foot), 8, "the corner back while the grip is hidden")
    foot:SetGrip(true)
    assertEqual(rightInset(foot), 22)
end)

test("chrome: with no Widgets library a footer made without grip keeps its right line at the pad", function()
    local inst = T.load{ libFiles = {}, mutate = function(m) Widgets.install(m) end }
    local NS = inst.NS
    local parent = inst.mocks.CreateFrame("Frame", nil, inst.mocks.UIParent)
    assertEqual(rightInset(NS.MakeFooter(parent)), 8, "no grip: the pad")
    assertEqual(rightInset(NS.MakeFooter(parent, { grip = true })), 22, "grip: the grip's corner")
end)
