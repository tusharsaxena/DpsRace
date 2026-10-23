local addonName, NS = ...
-- core/PerfSetup.lua — NS.Perf, the one performance-harness instance from LibKa0s-Perf-1.0
-- (performance-§1); the reserved `perf` verb in settings/Slash.lua drives it.

local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)

if not lib then
    -- Degrade, never error: the gate, the sink and what the slash layer touches.
    NS.Perf = {
        on        = false,
        suspended = false,
        Note      = function() end,
        Open      = function() end,
        Close     = function() end,
        OnCommand = function()
            return { NS.LIBKA0S_MISSING .. ", so performance measurement is unavailable." }
        end,
    }
    return
end

NS.Perf = lib:New({
    name      = addonName,
    addonName = addonName,
    title     = NS.BRAND,
    slash     = NS.SLASH,
    sv        = "DpsRacePerfDB",     -- declared in the TOC (toc-file-§2)
    version   = NS.Version(),
    -- Declared in report order: the combat-boundary handler, the race's event handler and the
    -- HUD's two paths, each reached by a real bracket.
    buckets = {
        { key = "combatEvent" },     -- PLAYER_REGEN_* in core/DpsRace.lua
        { key = "raceEvent" },       -- every race event in modules/Watchers.lua
        { key = "hudLive" },         -- one throttled live read and redraw in modules/Hud.lua
        { key = "hudTick" },         -- the HUD's 20 Hz countdown redraw in modules/Hud.lua
    },
    -- The latch the capture's suspended arm takes its `perf` hold on. suspend/resume are NOT passed:
    -- the latch's standDown/standUp (core/LifecycleSetup.lua) are the one teardown.
    lifecycle = NS.lifecycle,
    log = function(line)
        if NS.DebugLog and NS.DebugLog.Add then NS.DebugLog:Add("Perf", line) else NS.Print(line) end
    end,
    print   = function(line) NS.Print(line) end,
    showLog = function()
        if NS.DebugLog and NS.DebugLog.Show and not NS.DebugLog:IsShown() then NS.DebugLog:Show() end
    end,
    -- No `decorate`: the library draws the step panel's close control from addonName itself
    -- (performance-§4, anti-pattern #65).
})
