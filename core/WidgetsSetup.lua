local _, NS = ...
-- core/WidgetsSetup.lua — NS.MakeDropdown / NS.CloseMenu / NS.MakeTestStrip from LibKa0s-Widgets-1.0:
-- the Results window's filter-bar dropdowns (modules/Results_Runs.lua, modules/Results_Bests.lua) and
-- the test-mode strip a window lays over data that is not the player's.
--
-- A seam, nothing else (library-stack-§7): one file leases the major, so the art the dropdown draws
-- is resolved once, here. The library is vendored and cannot know which folder it was copied into,
-- so the chevron and the tick arrive as resolved paths from the addon's own media seam
-- (core/MediaSetup.lua); NS.Icon answering nil is a real answer, and the library falls back to the
-- Blizzard chevron and tick. No option this addon builds carries a glyph, so no glyph face is passed.
--
-- THE POPUP IS A PROCESS-WIDE SINGLETON parented to UIParent, so hiding a window does not reach it.
-- Every non-click close path of a window with a dropdown calls NS.CloseMenu(): the Results window's
-- OnHide (also the Escape path through UISpecialFrames) and its tab switch.
--
-- DEGRADED (the library absent): NS.MakeDropdown answers nil and the filter bar draws no dropdown at
-- all rather than a dead control that opens no menu; the filters stay at "all". NS.MakeTestStrip
-- answers nil; NS.CloseMenu is a no-op, because there is no menu that could be open.

local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

--- One flat-skin dropdown, or nil when the library is absent. Nil is a real answer: the caller
--- draws no control.
--- @param parent table the frame to parent it to
--- @param width number the collapsed button's width
--- @return table|nil
function NS.MakeDropdown(parent, width)
    if not W then return nil end
    return W.Dropdown(parent, width, {
        chevron = NS.Icon("chevron-down"),
        check   = NS.Icon("confirm"),
    })
end

--- Whether the dropdown seam can build anything at all.
--- @return boolean
function NS.HasWidgets()
    return W ~= nil
end

--- The test-mode strip (the library's W.TestStrip, born hidden and unanchored), or nil when the
--- library is absent. The caller anchors it and shows it. Its mark is the catalog's info icon.
--- @param parent table the frame to parent it to
--- @param text string the localized line it says
--- @return table|nil
function NS.MakeTestStrip(parent, text)
    if not W then return nil end
    return W.TestStrip(parent, { text = text, icon = NS.Icon("info") })
end

--- Close the shared popup menu behind every dropdown in the process, if one is open. Safe when none
--- ever opened, and a no-op on a degraded install.
function NS.CloseMenu()
    if W then W.CloseMenu() end
end
