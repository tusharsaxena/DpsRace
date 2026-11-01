local addonName, NS = ...
-- core/WidgetsSetup.lua — NS.MakeDropdown / NS.CloseMenu / NS.MakeTestStrip / NS.ShowCopy from
-- LibKa0s-Widgets-1.0: the Results window's filter-bar dropdowns (modules/Results_Runs.lua, and
-- modules/Results_Insights.lua from N4 of the #12 plan), the test-mode strip a window lays over data that is not the player's,
-- and the copy window the run detail's talent loadout opens (modules/Results_Loadout.lua).
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
-- answers nil; NS.CloseMenu is a no-op, because there is no menu that could be open; NS.ShowCopy
-- answers false and its caller prints the text instead.

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
        owner   = addonName,
    })
end

-- ── the context menus (cause A2) ─────────────────────────────────────────────────────────────────
-- A row's right-click wears the skin through the shared Ka0s menu, the one the filter dropdowns drop.
-- The library has no context menu, so this drives one hidden dropdown at the cursor: a `fill(root)` is
-- written against MenuUtil's own description (CreateTitle, CreateButton, and on a button SetEnabled and
-- a nested CreateButton), recorded here, then drawn one level at a time. That menu has no flyout, title
-- row or disabled row, so a submenu replaces the rows it drops from, a title is a row in the heading
-- color that does nothing, and a disabled row is one in the disabled color that does nothing: the
-- library hides the menu before it reports any row's click, so those two open their own level again.
-- Without the library the same `fill` goes to the client's menu.

local contextDropdown

local function contextHost()
    if contextDropdown == nil then
        contextDropdown = NS.MakeDropdown(UIParent, 1) or false
        if contextDropdown then
            contextDropdown:SetHeight(1)
            contextDropdown:SetAlpha(0)
            contextDropdown:EnableMouse(false)
        end
    end
    return contextDropdown
end

--- A level of a description: the recorder a `fill` writes to, and each button's own nested level.
local function newLevel()
    local level = { items = {} }
    function level:CreateTitle(text)
        self.items[#self.items + 1] = { label = text, title = true }
        return {}
    end
    function level:CreateButton(text, onClick)
        local sub = newLevel()
        sub.label, sub.onClick, sub.enabled = text, onClick, true
        function sub.SetEnabled(_, on) sub.enabled = on and true or false end
        self.items[#self.items + 1] = sub
        return sub
    end
    return level
end

local function rowColor(token)
    local r, g, b = NS.Skin.Color(token)
    return { r or 1, g or 1, b or 1 }
end

--- One dropdown option for each of `level`'s rows: its index, its label, a submenu's mark and the
--- color a title or a disabled row takes.
local function rowOptions(level)
    local options = {}
    for i, item in ipairs(level.items) do
        local label = item.label
        if not item.title and #item.items > 0 then
            label = label .. " " .. NS.Skin.MarkText(NS.Icon("chevron-right"), 0)
        end
        local color = (item.title and rowColor("text.heading")) or (item.enabled == false and rowColor("text.disabled"))
        options[i] = { value = i, label = label, color = color or nil }
    end
    return options
end

local function showLevel(dd, level)
    dd:SetOptions(rowOptions(level))
    dd:SetValue(nil, "")
    dd.onSelect = function(i)
        local item = level.items[i]
        if not item or item.title or item.enabled == false then return showLevel(dd, level) end
        if #item.items > 0 then return showLevel(dd, item) end
        if item.onClick then item.onClick() end
    end
    dd:GetScript("OnClick")(dd)
end

--- True when a context menu can open: the Ka0s menu, or the client's without the library.
function NS.CanOpenMenu()
    if W and not NS.__clientMenus then return true end
    return MenuUtil ~= nil and MenuUtil.CreateContextMenu ~= nil
end

--- A context menu at the cursor: `fill(root)` adds its rows as it would to a MenuUtil description.
--- @param owner table  the client menu's owner region
--- @param fill function
function NS.OpenMenu(owner, fill)
    local dd = not NS.__clientMenus and contextHost()
    if not dd then
        MenuUtil.CreateContextMenu(owner, function(_, root) fill(root) end)
        return
    end
    NS.CloseMenu()   -- an open one would toggle shut, not reopen here
    local level = newLevel()
    fill(level)
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    dd:ClearAllPoints()
    dd:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    showLevel(dd, level)
end

--- The hidden dropdown behind the Ka0s context menu, for a suite to read its rows.
function NS.__contextDropdown() return contextDropdown end

--- The strip's height, for a window laying its content out below it (the library publishes it).
NS.TEST_STRIP_HEIGHT = (W and W.TEST_STRIP and W.TEST_STRIP.HEIGHT) or 18

--- The test-mode strip (the library's W.TestStrip, born hidden and unanchored), or nil when the
--- library is absent. The caller anchors it and shows it. Its mark is the catalog's info icon.
--- @param parent table the frame to parent it to
--- @param text string the localized line it says
--- @return table|nil
function NS.MakeTestStrip(parent, text)
    if not W then return nil end
    return W.TestStrip(parent, { text = text, icon = NS.Icon("info"), owner = addonName })
end

-- The one copy window, its frame built on the first ShowCopy (the library's lazy handle), over the
-- window that asked for it.
local copyWindow, copyAnchor

--- Show `text` selected in the copy window (Ctrl+C copies it, Escape closes it), titled `title`, over
--- `anchor` when it is shown.
--- @param text string
--- @param title string
--- @param anchor table|nil  the window to center it over
--- @return boolean shown  false on a degraded install
function NS.ShowCopy(text, title, anchor)
    if not (W and W.CopyWindow) then return false end
    copyAnchor = anchor
    copyWindow = copyWindow or W.CopyWindow({
        addonName = addonName, name = "DpsRaceCopyWindow", width = 520, height = 150, title = title,
        anchorTo = function() return copyAnchor end,
    })
    if not copyWindow then return false end
    local f = copyWindow:Show(text)
    if f and f.title then f.title:SetText(title) end
    return true
end

--- Close the shared popup menu behind every dropdown in the process, if one is open. Safe when none
--- ever opened, and a no-op on a degraded install.
function NS.CloseMenu()
    if W then W.CloseMenu() end
end
