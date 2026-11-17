local addonName, NS = ...
-- core/WidgetsSetup.lua — NS.MakeDropdown / NS.CloseMenu / NS.MakeTestStrip / NS.MakeFooter / NS.ShowCopy
-- from LibKa0s-Widgets-1.0: the Results window's filter-bar dropdowns (modules/Results_Runs.lua, and
-- modules/Results_Insights.lua from N4 of the #12 plan), the test-mode strip a window docks under its
-- title bar over data that is not the player's, the windows' footer (the HUD's and the Results
-- window's), and the copy window the run detail's talent loadout opens (modules/Results_Loadout.lua).
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
-- answers false and its caller prints the text instead. NS.MakeFooter answers a bare footer of the
-- same height with the same two lines, so a degraded window still lays out and paints its status.

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
-- A row's right-click wears the skin through W.ContextMenu (Widgets minor 21), the shared Ka0s menu
-- opened at the cursor. A `fill(root)` is written against MenuUtil's own description (CreateTitle,
-- CreateButton, and on a button SetEnabled and a nested CreateButton), recorded here, then turned
-- into rows once and handed to one W.ContextMenu call: a button with a nested level is a `submenu`
-- row (Widgets minor 23, cascading menus), so its rows open beside it, any depth, while the parent
-- stays drawn, and the library draws the client's submenu arrow on it.
-- Without the library the same `fill` goes to the client's menu.

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

local menuRows

--- One W.ContextMenu row: a title, or a button with its click and its disabled state; a button with
--- a nested level is a submenu row whose child rows are that level's (the library opens them).
local function menuRow(item)
    if item.title then return { label = item.label, title = true } end
    local row = { label = item.label, disabled = item.enabled == false or nil }
    if #item.items > 0 then
        row.submenu = menuRows(item)
    else
        row.onClick = item.onClick
    end
    return row
end

--- A recorded level's rows, its nested levels as `submenu` rows.
menuRows = function(level)
    local rows = {}
    for i, item in ipairs(level.items) do rows[i] = menuRow(item) end
    return rows
end

--- True when a context menu can open: the Ka0s menu, or the client's without the library.
function NS.CanOpenMenu()
    if W then return true end
    return MenuUtil ~= nil and MenuUtil.CreateContextMenu ~= nil
end

--- A context menu at the cursor: `fill(root)` adds its rows as it would to a MenuUtil description.
--- @param owner table  the client menu's owner region
--- @param fill function
function NS.OpenMenu(owner, fill)
    if not W then
        MenuUtil.CreateContextMenu(owner, function(_, root) fill(root) end)
        return
    end
    local level = newLevel()
    fill(level)
    W.ContextMenu(owner, menuRows(level), { owner = addonName, cursor = true })
end

-- The strip's opts: its text, the catalog's info mark, this addon's skin, the menu that ends the mode
-- and, given a title bar, the library's docking (Widgets minor 27, preview-mode's *Where the strip
-- sits*): directly under that title bar, full width, placed again on every show, hide and resize. The
-- host moves what stands below the title bar by `strip:BodyOffset()` and never anchors the strip.
-- Both windows here are windows (the HUD has a title bar), so a strip always docks `dock = "title"`.
local function stripOpts(text, kind, titleBar, window)
    -- onEnd (LibKa0s Widgets minor 21, SF-F1): the strip's right-click menu ends the preview, the test
    -- mode and the sim alike (Preview.Stop stops the sim's script and its stepper too).
    local function endMode() if NS.Preview and NS.Preview.IsActive() then NS.Preview.Stop() end end
    local opts = { kind = kind, text = text, icon = NS.Icon("info"), owner = addonName, onEnd = endMode }
    if titleBar then opts.dock, opts.titleBar, opts.window = "title", titleBar, window end
    return opts
end

--- The test-mode strip (the library's W.TestStrip, born hidden), or nil when the library is absent.
--- Given `titleBar` the library docks it under that title bar; with none it is unanchored. The caller
--- shows it. Its mark is the catalog's info icon.
--- @param parent table the frame to parent it to
--- @param text string the localized line it says
--- @param titleBar table|nil the window's title band, to dock it under
--- @param window table|nil the window (the dock's `window`)
--- @return table|nil
function NS.MakeTestStrip(parent, text, titleBar, window)
    if not W then return nil end
    return W.TestStrip(parent, stripOpts(text, nil, titleBar, window))
end

--- The simulation strip: the same widget in its sim flavor (kind = "sim", the library's cyan wash), born
--- hidden and docked as NS.MakeTestStrip's, or nil when the library is absent. A running sim shows this
--- one and never the test strip (WFP-FIX-01). Its right-click menu ends the preview, the sim's script
--- and stepper with it.
--- @param parent table the frame to parent it to
--- @param text string the localized line it says
--- @param titleBar table|nil the window's title band, to dock it under
--- @param window table|nil the window (the dock's `window`)
--- @return table|nil
function NS.MakeSimStrip(parent, text, titleBar, window)
    if not W then return nil end
    return W.TestStrip(parent, stripOpts(text, "sim", titleBar, window))
end

--- A window footer's height (W.FOOTER.HEIGHT, standalone-windows' *Window chrome geometry*: 24 px under
--- every skin), read where the library publishes it; the same figure with no library.
NS.FOOTER_HEIGHT = (W and W.FOOTER and W.FOOTER.HEIGHT) or 24

-- A footer with no library (a degraded install only; with the library every footer is W.Footer, and a
-- host-built one beside it is anti-pattern #118): a bare frame of the same height along the window's
-- bottom edge with W.Footer's two lines and setters, so the window's paint runs unchanged.
local function bareFooter(parent)
    local foot = CreateFrame("Frame", nil, parent)
    foot:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    foot:SetHeight(NS.FOOTER_HEIGHT)
    -- No skin to paint from: the client's small gray font object draws the muted lines.
    foot.left = foot:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot.left:SetPoint("LEFT", foot, "LEFT", 8, 0)
    foot.right = foot:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot.right:SetPoint("RIGHT", foot, "RIGHT", -22, 0)
    foot.right:SetJustifyH("RIGHT")
    for _, fs in ipairs({ foot.left, foot.right }) do fs:SetWordWrap(false) end
    foot.SetLeft = function(self, text) self.left:SetText(type(text) == "string" and text or "") end
    foot.SetRight = function(self, text) self.right:SetText(type(text) == "string" and text or "") end
    foot.SetGrip = function() end
    return foot
end

--- A window footer (the library's W.Footer, Widgets minor 27; standalone-windows' *The footer*): no
--- fill, a hairline in the skin's `divider` along its top, FOOTER.HEIGHT tall across `parent`'s bottom
--- edge, its two lines in `text.muted`, born shown and painted for this addon's skin owner. `opts` is
--- W.Footer's (`grip = true` keeps the right line clear of the window's resize grip). With no library,
--- a bare footer of the same height with the same fields (`left`, `right`, `SetLeft`, `SetRight`,
--- `SetGrip`).
--- @param parent table the window
--- @param opts table|nil W.Footer's opts; `owner` is always this addon
--- @return table
function NS.MakeFooter(parent, opts)
    if not W or type(W.Footer) ~= "function" then return bareFooter(parent) end
    local o = {}
    for k, v in pairs(opts or {}) do o[k] = v end
    o.owner = addonName
    return W.Footer(parent, o)
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
