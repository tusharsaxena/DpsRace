-- tests/skin_surfaces.lua — this addon's painted surfaces, declared for the kit's skin-switch test
-- (tests/_kit/test_skin_switch.lua, kit revision 50, skinning-§1). tests/run.lua sets Kit.skinSwitch
-- from it. Loaded with dofile (it registers no case of its own).
--
-- THE GRAIN IS ONE PAINTED OBJECT. The kit spies on what `build` answers and on its regions and
-- children, and a surface passes when anything under it changes, so each entry answers the object
-- that draws: a string, a texture, a bar or one small frame, never a whole window.
--
-- ONE RUNNING INSTANCE. A surface needs a HUD in a race and a Results window with a run, and the skin
-- library belongs to one instance, so one is built on the first `build` and shared. `paint` is the
-- HUD's own redraw: the running body's strings sit behind a stamp the looks-changed path bumps.
--
-- COMPANIONS. A surface behind a `FromSkin` row names it in `companion`, which excludes it from the
-- kit's ignored pass. The stored defaults have every companion on, so `companion` writes nothing a
-- later surface would see.
--
-- Not declared: A9, the clocks' colors and the bar fills the owner kept as stored, and meaning colors
-- (sem.* and the dr.ahead family), which never follow.

return function(T)
    local fixture

    local function live()
        if fixture then return fixture end
        local installPaint = dofile(T.root .. "/tests/_kit/mock_paint.lua")
        local RaceClock = dofile(T.root .. "/tests/race_clock.lua")(T)
        local f = RaceClock.new{ mutate = function(m)
            installPaint(m)
            m.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
        end }
        f.NS.Slices.Reset()
        assert(f:arm(30))
        f:start(25)
        f.NS.Hud.Tick()
        fixture = f
        return f
    end

    local function NSof() return live().NS end
    local function hudBody()
        local u = assert(NSof().Hud.__ui(), "the HUD window was never built")
        return u, u.body[u.current]
    end

    -- A saved run, shown in the Results window's detail.
    local function results()
        local f = live()
        local NS = f.NS
        NS.db.global.runs.surface = NS.db.global.runs.surface or {
            id = "surface", schema = 1, status = "complete", addon = "0.1.0", build = 120105, date = 1000,
            race = { length = 180, grace = 1.0, restartGap = 6, startSource = "meterSession", sessionID = 25 },
            char = { name = "Lanfear", realm = "Frostmourne", class = "WARLOCK", specID = 267, spec = "Destruction" },
            target = { npcID = 243208, name = "Cleave Training Dummy", category = "cleave" },
            where = { mapID = 2393, zone = "Silvermoon City", instanceType = "none" },
            result = { damage = 26560000, dps = 147555.6, meterDps = 134100, sessionDuration = 190, tail = 9.17,
                       combatEnd = 7.34 },
            flags = { lateCasts = { { offset = 2.0, spellID = 29722 } }, reloaded = false, died = false },
            spells = { { id = 29722, dmg = 7330000, dps = 1 }, { id = 116858, dmg = 4920000, dps = 1 } },
            note = "",
        }
        NS.Results.ShowRun("surface")
        return NS.Results.__ui()
    end

    local function redraw()
        NSof().Hud.Tick()
    end

    local function writeSetting(path)
        return function(on) NSof().SetByPath(path, on) end
    end

    local function pace()
        local _, b = hudBody()
        return b.w.pace
    end

    -- The pace bar draws only in a race with a best: its range is that draw.
    local function drawPace() pace():SetRange(0, 1) end

    -- One striped spell list in the detail's look, its rows drawn from the run. A row restyles on its
    -- next draw, so that draw is the list's `paint`.
    local spellList
    local function spells()
        local NS = NSof()
        results()
        if not spellList then
            local parent = live().M.CreateFrame("Frame", nil, live().M.UIParent)
            spellList = NS.HudBreakdown.New(parent, nil, "window")
        end
        spellList:ShowResult(NS.db.global.runs.surface, 2, true, 0)
        return spellList.rows[2]
    end
    local function drawSpells() spells() end

    -- A surface that opens something leaves it for `reset` to close.
    local function closeAll()
        if not fixture then return end
        local NS = fixture.NS
        NS.ResultsTimeline.Hide()
        NS.ResultsGear.Hide()
        NS.BestToast.EndPreview()
        NS.SetByPath("resultsDetail.spellBars.borderStyle", "None")
    end

    local function timeline()
        local NS = NSof()
        assert(NS.ResultsTimeline.Open(results().detail), "the timeline did not open")
        return NS.ResultsTimeline.__ui()
    end

    -- The detail's spell row with a stored border, so an edge draws under Ka0s Default's None too.
    local function bordered()
        local p = "resultsDetail.spellBars."
        NSof().SetByPath(p .. "borderStyle", "Solid")
        local row = spells()
        return row.edge
    end

    local function strip()
        local NS = NSof()
        local s = assert(NS.MakeTestStrip(results().frame, "Test mode"), "no strip")
        s:Show()
        return s
    end

    return {
        owner = "DpsRace",
        skin = function() return live().inst.mocks.LibStub("LibKa0s-Skin-1.0") end,
        reset = closeAll,
        surfaces = {
            { name = "the HUD's window shell", build = function() return (hudBody()).frame end },
            { name = "the live figures' text", paint = redraw,
              companion = writeSetting("appearance.figures.fontColorFromSkin"),
              build = function() local _, b = hudBody(); return b.w.damage.value end },
            { name = "the spells section's heading",
              build = function() local _, b = hudBody(); return b.w.spellsTitle end },
            { name = "the pace bar's track", paint = drawPace, companion = writeSetting("appearance.pace.bgFromSkin"),
              build = function() return pace().track end },
            { name = "the pace bar's behind half", paint = drawPace,
              companion = writeSetting("appearance.pace.barTextureFromSkin"),
              build = function() return pace().behind end },
            { name = "the pace bar's on-pace tick",
              build = function() return pace().tick end },
            { name = "the damage chart's plot", paint = redraw, companion = writeSetting("appearance.chart.bgFromSkin"),
              build = function() local _, b = hudBody(); return b.w.chart.plot end },
            { name = "the Cancel button",
              build = function() local _, b = hudBody(); return b.w.cancel end },
            { name = "the Results window's shell", build = function() return results().frame end },
            { name = "the Results footer", build = function() return results().footLeft end },
            { name = "the run detail's Back mark",
              build = function() return results().detail.w.back.icon end },
            { name = "the run detail's Delete button",
              build = function() return results().detail.w.delete end },
            { name = "the run detail's flags box",
              build = function() return results().detail.w.flags end },
            { name = "the timing strip's segment",
              build = function() return results().detail.w.segA end },
            { name = "a Results tab's underline",
              build = function() return results().tabs.runs.underline end },
            { name = "a spell row's track", paint = drawSpells,
              companion = writeSetting("resultsDetail.spellBars.bgFromSkin"),
              build = function() return spells().track end },
            { name = "a spell row's stripe", build = function() return spells().stripe end },
            { name = "a spell row's bar", paint = drawSpells,
              companion = writeSetting("resultsDetail.spellBars.barTextureFromSkin"),
              build = function() return spells().bar end },
            { name = "a spell row's name", paint = drawSpells,
              companion = writeSetting("appearance.spellText.fontColorFromSkin"),
              build = function() return spells().name end },
            { name = "a spell row's border", paint = drawSpells,
              companion = writeSetting("resultsDetail.spellBars.borderColorFromSkin"), build = bordered },
            { name = "a spell icon's edge", build = function() return NSof().Style.IconEdge(results().frame, results().frame) end },
            { name = "the dim cover", build = function() return timeline() and results().cover.dim end },
            { name = "the ability timeline's shell", build = function() return timeline().frame end },
            { name = "the gear view's shell", build = function()
                assert(NSof().ResultsGear.Open(results().detail), "the gear view did not open")
                return NSof().ResultsGear.__ui().frame
            end },
            { name = "a filter dropdown", build = function() return NSof().MakeDropdown(results().frame, 100) end },
            { name = "the test-mode strip", build = strip },
        },
    }
end
