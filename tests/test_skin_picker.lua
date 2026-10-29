-- tests/test_skin_picker.lua — the first-run skin picker (core/SkinSetup.lua; LibKa0s OptionsSkinPicker,
-- owner ruling O3) and the Profiles page's AceGUI tree painted for this owner (DR-04).
--
-- What this addon owes the picker, and nothing the library pins itself: the spec it hands O.SkinPicker
-- (its owner, its two seams, the General page's Skin tab, the eye, the close); WHEN it shows (a profile
-- whose `skin.pickerSeen` is false, once two seconds after login and after every profile event, never
-- while the addon stands down, held through combat); that only the player's close marks it seen; and
-- that the eye turns test mode on. Then the Profiles page: AceConfigDialog acquires its widgets past
-- the Options proxy, so the renderer paints the tree itself. Last, the library-absent load.
--
-- Every case builds its own instance (the harness fires the login fuse, so each one starts with the
-- picker up).

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local PATH = "skin.pickerSeen"

--- A fresh instance with the picker the login fuse showed taken down, unmarked.
local function fresh(opts)
    local inst = T.load(opts)
    if inst.NS.HideSkinPicker then inst.NS.HideSkinPicker() end
    return inst.NS, inst.mocks
end

--- Run `fn(calls)` with O.SkinPicker replaced by a recorder: each call's spec, in order.
local function spying(NS, fn)
    local O = NS.Helpers
    local real = O.SkinPicker
    local calls = {}
    O.SkinPicker = function(spec)
        calls[#calls + 1] = spec
        return { spy = true }
    end
    local ok, err = pcall(fn, calls)
    O.SkinPicker = real
    if not ok then error(err, 0) end
end

--- Run `fn` with InCombatLockdown answering `on`, whatever `fn` raised.
local function inCombat(M, fn)
    local real = M.InCombatLockdown
    M.InCombatLockdown = function() return true end
    local ok, err = pcall(fn, function() M.InCombatLockdown = function() return false end end)
    M.InCombatLockdown = real
    if not ok then error(err, 0) end
end

-- ── the key and the spec ─────────────────────────────────────────────────────────────────────────

test("skin picker: the spec names this owner, its seams, the General page's Skin tab and the eye", function()
    -- red under: a set that is not the write seam (a pick would never reach the profile), or a page
    -- key O.SelectTab does not know (the gear would open the panel on the wrong page).
    local NS, M = fresh()
    local spec = NS.SkinPickerSpec()
    assertEqual(spec.owner, "DpsRace")
    assertTrue(rawequal(spec.get, NS.SkinChoice), "get is the read seam")
    assertTrue(rawequal(spec.set, NS.WriteSkinChoice), "set is the write seam")
    assertEqual(spec.page, "general")
    assertEqual(spec.tab, "Appearance", "the Skin tab's key")
    M.__subcategories["General"]:__fire("OnShow")
    assertTrue(NS.Helpers.__panelFor("general") ~= nil, "\"general\" is the page O.SelectTab finds")
    assertEqual(type(spec.onPreview), "function")
    assertEqual(type(spec.onClose), "function")
end)

-- ── when it shows ────────────────────────────────────────────────────────────────────────────────

test("skin picker: an unseen profile shows it; a seen one does not", function()
    local NS = fresh()
    assertEqual(NS.GetSetting(PATH), false, "every profile starts unseen (O3)")
    spying(NS, function(calls)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 1, "pickerSeen false: the picker shows")
        assertEqual(calls[1].owner, "DpsRace")
        NS.SetByPath(PATH, true)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 1, "pickerSeen true: it does not show again")
    end)
end)

test("skin picker: it shows once after login, on a two-second AceTimer the stand-down cancels", function()
    -- red under: dropping the call from NS:OnEnable, or a C_Timer.After the stand-down cannot cancel.
    local inst = T.load({ enable = false })
    local NS, M = inst.NS, inst.mocks
    local before = #M.__timers
    M.LibStub("AceAddon-3.0"):EnableAddon(NS)
    local fuse
    for i = before + 1, #M.__timers do
        if M.__timers[i].delay == 2 then fuse = M.__timers[i] end
    end
    assertTrue(fuse ~= nil, "OnEnable lit no two-second fuse")
    assertTrue(fuse.timer ~= nil, "the fuse is an AceTimer (the stand-down's CancelAllTimers reaches it)")
    spying(NS, function(calls)
        fuse.fn()
        assertEqual(#calls, 1, "the login fuse shows the picker")
    end)
end)

test("skin picker: in combat a start waits for PLAYER_REGEN_ENABLED, once", function()
    local NS, M = fresh()
    spying(NS, function(calls)
        inCombat(M, function(leave)
            assertEqual(NS.MaybeShowSkinPicker(), nil)
            NS.MaybeShowSkinPicker()
            assertEqual(#calls, 0, "nothing shows in combat")
            leave()
            M.__fireEvent("PLAYER_REGEN_ENABLED")
            assertEqual(#calls, 1, "the combat edge shows it, once for two held starts")
            M.__fireEvent("PLAYER_REGEN_ENABLED")
            assertEqual(#calls, 1, "the one-shot target is gone")
        end)
    end)
end)

test("skin picker: the stand-down drops a held start and shows nothing while the addon is off", function()
    local NS, M = fresh()
    M.__resetPrinted()
    spying(NS, function(calls)
        inCombat(M, function(leave)
            NS.MaybeShowSkinPicker()
            NS.SetByPath("enabled", false)
            assertTrue(NS.IsStoodDown(), "the switch stood the addon down")
            leave()
            M.__fireEvent("PLAYER_REGEN_ENABLED")
            assertEqual(#calls, 0, "a dropped start must not fire on the combat edge")
        end)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 0, "a disabled addon shows no picker")
    end)
    assertEqual(NS.GetSetting(PATH), false, "the stand-down's hide is not the player's close")
end)

test("skin picker: a new profile and a reset profile show it again", function()
    -- red under: no call on the profile path, or one before the hold re-reads the new profile's switch.
    local NS = fresh()
    NS.SetByPath(PATH, true)
    spying(NS, function(calls)
        NS.db:SetProfile("PickerProbe")
        assertEqual(#calls, 1, "a new profile shows the picker")
        NS.SetByPath(PATH, true)
        NS.db:ResetProfile()
        assertEqual(#calls, 2, "a reset profile shows it again")
        NS.SetByPath(PATH, true)
        NS.db:SetProfile("Default")
        assertEqual(#calls, 2, "back on a profile that has seen it: no picker")
    end)
end)

-- ── the real window ──────────────────────────────────────────────────────────────────────────────

test("skin picker: the harness login shows the library's window", function()
    local inst = T.load()
    local f = inst.NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown(), "the login fuse left no picker up on an unseen profile")
end)

test("skin picker: the player's close marks it seen; this addon's own hide does not", function()
    local NS = fresh()
    local f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
    NS.HideSkinPicker()
    assertFalse(f:IsShown())
    assertEqual(NS.GetSetting(PATH), false, "a stand-down hide is not the player's close")
    f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown(), "it shows again while unseen")
    NS.Helpers.HideSkinPicker()
    assertEqual(NS.GetSetting(PATH), true, "the player's close sets pickerSeen")
    assertEqual(NS.MaybeShowSkinPicker(), nil, "and it does not show again")
end)

test("skin picker: a profile that has seen it takes a shown picker down, unmarked", function()
    local NS = fresh()
    local f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown())
    NS.db.profile.skin.pickerSeen = true
    NS.MaybeShowSkinPicker()
    assertFalse(f:IsShown(), "the picker stayed up on a profile that has seen it")
end)

test("skin picker: the eye turns test mode on, and with it on shows the Results window", function()
    local NS, M = fresh()
    M.__resetPrinted()
    NS.SkinPickerSpec().onPreview()
    assertTrue(NS.Preview.IsActive(), "the eye did not start test mode")
    assertEqual(NS.Preview.Mode(), "test")
    assertTrue(NS.Results.IsShown(), "test mode opens the Results window on sample data")
    NS.Results.Hide()
    NS.SkinPickerSpec().onPreview()
    assertTrue(NS.Preview.IsActive(), "the eye leaves test mode on")
    assertTrue(NS.Results.IsShown(), "with test mode already on, the eye still shows the window")
    NS.Preview.Stop()
end)

-- ── the Profiles page ────────────────────────────────────────────────────────────────────────────

test("skin picker: the Profiles page paints the tree AceConfigDialog draws, on every render", function()
    -- red under: dropping NS.SkinPaintAceTree from settings/Profiles.lua's renderer.
    local NS, M = fresh()
    local real, painted = NS.SkinPaintAceTree, {}
    NS.SkinPaintAceTree = function(container)
        painted[#painted + 1] = container
        return real(container)
    end
    local ok, err = pcall(function()
        local panel = M.__subcategories["Profiles"]
        assertTrue(panel ~= nil, "the Profiles page is not registered")
        panel:Show()
        panel:__fire("OnShow")
        assertEqual(#painted, 1, "the render painted no tree")
        assertTrue(type(painted[1]) == "table" and painted[1].frame ~= nil, "it paints the page's AceGUI container")
        local ctx = NS.Helpers.__panelFor("profiles")
        assertTrue(ctx ~= nil and type(ctx._renderFn) == "function", "the Profiles page has no renderer")
        ctx._renderFn(ctx)
        assertEqual(#painted, 2, "a re-render paints the fresh rows again")
    end)
    NS.SkinPaintAceTree = real
    if not ok then error(err, 0) end
end)

-- ── without the library ──────────────────────────────────────────────────────────────────────────

test("skin picker: degraded, no picker shows and the Profiles paint is a no-op", function()
    local NS = fresh({ libFiles = {} })
    assertEqual(NS.SkinPaintAceTree({}), 0, "PaintAceTree paints nothing")
    assertEqual(NS.MaybeShowSkinPicker(), nil, "no picker without the library")
    NS.HideSkinPicker()
end)
