local addonName, NS = ...
-- core/ToastSetup.lua — NS.NewToast from LibKa0s-Toast-1.0: the alert-toast shell under the new-best
-- toast (modules/BestToast.lua, #5). The shell owns the queue, the lifetime (the countdown, its hover
-- pause, the close mark and the right-click), the T5 alert tier, the drag and the sound; the addon owns
-- what the toast says, when it shows, and the settings it reads.
--
-- A seam, nothing else (library-stack-§7): one file leases the major, and every descriptor it builds
-- carries this addon's folder as its skin owner. The major is vendored ALONE for now, ahead of the rest
-- of LibKa0s (docs/ARCHITECTURE.md, Documented deviations): the TOC loads libs\LibKa0s\Toast.lua after
-- LibKa0s.xml, and on v1.77.0's Core it wears Core's SKIN and close mark.
--
-- DEGRADED (the library absent): NS.NewToast answers NS.ToastStub, the instance's surface with every
-- member a no-op answering what an empty toast answers, so no toast ever shows and nothing raises.
-- test_surface_parity holds the stub to a live instance.

local Toast = LibStub and LibStub("LibKa0s-Toast-1.0", true)

--- The key the shell's Preview shows under (its own constant; the stub's stand-in when absent).
NS.TOAST_PREVIEW = Toast and Toast.PREVIEW or "preview"

-- The instance's surface, each member a no-op (docs/api/Toast/version-1-docs.md, The degradation stub).
NS.ToastStub = {
    Show = function() return false end, Dismiss = function() end, Remove = function() return 0 end,
    Clear = function() end, Hold = function() end, Release = function() end,
    Preview = function() end, Pause = function() end, Resume = function() end,
    Attach = function() end, Refresh = function() end, ResetPosition = function() end,
    Current = function() return nil end, Frame = function() return nil end,
    Stats = function() return { built = false, shown = false, waiting = 0, held = false,
        paused = false, sticky = false } end,
}

--- A toast for descriptor `d` (the library's Toast:New; `d.owner` defaults to this addon), or the
--- stub when the library is absent.
--- @param d table  the descriptor: d.build is required
--- @return table instance
function NS.NewToast(d)
    if not Toast then return NS.ToastStub end
    d.owner = d.owner or addonName
    return Toast:New(d)
end

--- Whether the seam can show anything at all.
--- @return boolean
function NS.HasToast()
    return Toast ~= nil
end
