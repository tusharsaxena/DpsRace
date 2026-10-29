-- tests/test_skinsetup.lua — the LibKa0s-Skin-1.0 seam (core/SkinSetup.lua, skinning-§1..§3; DR-01).
--
-- What this addon owes the skin engine, and nothing the library pins itself: the owner is
-- registered under the folder name at file load with this addon's read and write seams and its owner
-- tokens; the seven skin.* keys default to Ka0s Default and are skip-render schema rows on the Skin
-- tab; the tab is the library's, between New-best toast and Keybindings; the profile's skin is
-- applied right after AceDB exists and on every profile event; one pick from the tab, or from another
-- addon's copy, is ONE effective SetChoice (one OnLooksChanged, no reload request); every library
-- factory is handed the owner; and without the library the degraded facade answers every name the
-- live one carries, from a host copy of Ka0s Default that must equal the library's.
--
-- Every case builds its own instance, so nothing leaks between cases.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "DpsRace"
local BRAND = "Ka0s DPS Race"
local TAB = "Appearance"   -- the library's Skin tab's key (its label is "Skin")

local KEYS = {
    { "source", "ka0s" }, { "skin", "ka0s" }, { "ignorePanel", true }, { "ignoreFonts", false },
    { "font", "" }, { "texture", "" }, { "pickerSeen", false },
}

--- An enabled instance, its Skin major and a counter of this owner's looks changes and reload
--- requests.
local function setup(opts)
    local inst = T.load(opts)
    local NS, M = inst.NS, inst.mocks
    local Skin = M.LibStub("LibKa0s-Skin-1.0")
    local counts = { looks = 0, reloads = 0 }
    NS.Skin.OnLooksChanged(function() counts.looks = counts.looks + 1 end)
    Skin:OnReloadRequest(OWNER, function() counts.reloads = counts.reloads + 1 end)
    return NS, M, Skin, counts
end

local function rowOf(NS, path)
    for _, r in ipairs(NS.Schema) do if r.path == path then return r end end
end

--- Render the General page as the client does, on the Skin tab, and answer the ctx.
--- The General page builds its own ctx (settings/General.lua), so the renderer is wrapped to catch it.
local ctxOf = setmetatable({}, { __mode = "k" })
local function openTab(NS, M)
    local H = NS.Helpers
    local real, ctx = H.RenderTabbedSchema, nil
    H.RenderTabbedSchema = function(c, ...) ctx = c return real(c, ...) end
    local panel = M.__subcategories["General"]
    local ok, err = pcall(function()
        panel:Show()
        panel:__fire("OnShow")
        -- An already-drawn page is not redrawn on a show; draw it again, on the Skin tab.
        ctx = ctx or ctxOf[panel]
        assert(ctx, "the General page drew no ctx")
        ctxOf[panel] = ctx
        ctx.activeTab = TAB
        ctx._renderFn(ctx)
    end)
    H.RenderTabbedSchema = real
    assert(ok, err)
    return ctx
end

--- Every widget the tab drew, depth first.
local function flatten(ctx)
    local out = {}
    local function walk(w)
        out[#out + 1] = w
        for _, c in ipairs(w.children or {}) do walk(c) end
    end
    for _, w in ipairs(ctx.scroll.children) do walk(w) end
    return out
end

--- The Skin tab's check box (a radio choice or a Scope box) whose label ends with `name`.
local function choiceNamed(NS, M, name)
    for _, w in ipairs(flatten(openTab(NS, M))) do
        local label = tostring(w.labelText or "")
        if w.type == "CheckBox" and label:sub(-#name) == name then return w end
    end
end

local function near(a, b) return math.abs((a or 1) - (b or 1)) < 1e-6 end

-- ── the owner ────────────────────────────────────────────────────────────────────────────────────

test("skin seam: the owner is the folder name, and NS.Skin is its facade", function()
    -- red under: registering under the brand or a typo (the library keys every frame and every
    -- listener by owner), or publishing a facade of some other owner.
    local NS, _, Skin = setup()
    assertTrue(Skin:IsOwner(OWNER), "core/SkinSetup.lua did not register the owner")
    assertTrue(rawequal(NS.Skin, Skin:For(OWNER)), "NS.Skin is not Skin:For(\"" .. OWNER .. "\")")
    assertEqual(NS.Skin.owner, OWNER)
    assertEqual(Skin:OwnerLabel(OWNER), BRAND, "the copy confirmation names the addon by its brand")
end)

test("skin seam: the owner is registered at file load, before the profile store exists", function()
    -- skinning-§1: at FILE LOAD, so the EllesmereUI provider offers it before EllesmereUI dispatches.
    -- red under: RegisterOwner moved into OnInitialize or OnEnable.
    local inst = T.load({ init = false })
    assertTrue(inst.NS.db == nil, "nothing has run OnInitialize")
    assertTrue(inst.mocks.LibStub("LibKa0s-Skin-1.0"):IsOwner(OWNER), "not registered at file load")
end)

test("skin seam: the read answers Ka0s Default before the profile store exists", function()
    -- RegisterOwner calls `get` at FILE LOAD; a getter that raised there would be a Lua error on
    -- every login.
    local NS = T.load({ init = false }).NS
    local ok, source, skin = pcall(NS.SkinChoice)
    assertTrue(ok, "NS.SkinChoice raised without a store: " .. tostring(source))
    assertEqual(source, "ka0s")
    assertEqual(skin, "ka0s")
    local font, texture = NS.SkinOverride()
    assertEqual(font, false); assertEqual(texture, false)
end)

test("skin seam: Core's window edge is handed the owner", function()
    -- skinning-§1: every library factory that takes an owner is given one. red under:
    -- NS.ApplySkin = lib.ApplySkin (an owner-less call draws Ka0s Default whatever the skin).
    local NS, M = setup()
    local core = M.LibStub("LibKa0s-Core-1.0")
    local real, seen = core.ApplySkin, nil
    core.ApplySkin = function(_, _, owner) seen = owner end
    local ok, err = pcall(NS.ApplySkin, M.CreateFrame("Frame"))
    core.ApplySkin = real
    if not ok then error(err, 0) end
    assertEqual(seen, OWNER)
end)

test("skin seam: the dropdown and the test strip factories are handed the owner", function()
    -- red under: dropping `owner = addonName` from core/WidgetsSetup.lua's MakeDropdown or
    -- MakeTestStrip (the control then draws Ka0s Default whatever the skin).
    local NS, M = setup()
    local W = M.LibStub("LibKa0s-Widgets-1.0")
    local seen = {}
    local realDd, realStrip = W.Dropdown, W.TestStrip
    W.Dropdown = function(_, _, opts) seen.dropdown = opts and opts.owner end
    W.TestStrip = function(_, opts) seen.strip = opts and opts.owner end
    local ok, err = pcall(function()
        NS.MakeDropdown(M.CreateFrame("Frame"), 100)
        NS.MakeTestStrip(M.CreateFrame("Frame"), "probe")
    end)
    W.Dropdown, W.TestStrip = realDd, realStrip
    if not ok then error(err, 0) end
    assertEqual(seen.dropdown, OWNER, "MakeDropdown")
    assertEqual(seen.strip, OWNER, "MakeTestStrip")
end)

-- ── the owner tokens ─────────────────────────────────────────────────────────────────────────────

test("skin seam: every owner token is namespaced dr. and registered with the owner", function()
    -- X2, X12: addon-namespaced, never a library family. red under: a token the library refused
    -- (it answers nil through the facade) or one named outside `dr.`.
    local NS = setup()
    local n = 0
    for name, def in pairs(NS.SKIN_TOKENS) do
        n = n + 1
        assertTrue(name:sub(1, 3) == "dr.", name .. " is not in the dr. namespace")
        assertTrue(type(def.follow) == "string", name .. " follows no library token")
        assertTrue(NS.Skin.Token(name) ~= nil, name .. " was refused by the library")
    end
    assertTrue(n > 0, "no owner tokens")
end)

test("skin seam: under Ka0s Default each owner token is today's pixel", function()
    -- X1: never snapped to a near library token. red under: a `default` that drifts from the color
    -- the addon drew before the rollout.
    local NS = setup()
    local want = {
        ["dr.ahead"] = { 0.36, 0.86, 0.46, 1 }, ["dr.caution"] = { 1, 0.72, 0.29, 1 },
        ["dr.info"] = { 0.56, 0.72, 1.0, 1 }, ["dr.danger.text"] = { 1, 0.32, 0.32, 1 },
        ["dr.danger.bg"] = { 1, 0.32, 0.32, 0.08 }, ["dr.callout.bg"] = { 1, 0.72, 0.29, 0.07 },
        ["dr.modal.bg"] = { 0.06, 0.06, 0.08, 1 },
    }
    for name, c in pairs(want) do
        local r, g, b, a = NS.Skin.Color(name)
        local got = { r, g, b, a }
        for i = 1, 4 do
            assertTrue(near(got[i], c[i]), ("%s[%d]: %s, want %s"):format(name, i, tostring(got[i]), tostring(c[i])))
        end
    end
end)

test("skin seam: under another skin a wash is that skin's role color at the wash's alpha", function()
    -- The skins table: a danger fill under Obsidian is Obsidian's sem.statusBad at 0.08, never the
    -- opaque role color. red under: a wash that only `follow`s its role token.
    local NS, _, Skin = setup()
    NS.ApplySkinChoice("ka0s", "obsidian")
    local bad = Skin:ResolveSkin("obsidian")["sem.statusBad"]
    local r, g, b, a = NS.Skin.Color("dr.danger.bg")
    assertTrue(near(r, bad[1]) and near(g, bad[2]) and near(b, bad[3]), "not Obsidian's statusBad")
    assertTrue(near(a, 0.08), "the wash's alpha: " .. tostring(a))
    local _, _, _, ma = NS.Skin.Color("dr.modal.bg")
    assertTrue(near(ma, 1), "the modal fill is opaque in every skin")
end)

-- ── the keys and the rows ────────────────────────────────────────────────────────────────────────

test("skin seam: the seven skin keys default to Ka0s Default, the picker unseen", function()
    -- red under: a default other than today's look, or pickerSeen true (owner ruling O3: every
    -- profile, old and new, gets the first-run picker).
    local NS = setup()
    local p = NS.db.profile.skin
    for _, kv in ipairs(KEYS) do assertEqual(p[kv[1]], kv[2], "skin." .. kv[1]) end
end)

test("skin seam: every skin key is a skip-render schema row on the Skin tab", function()
    -- red under: a row that renders itself on top of the library's controls, or one outside the
    -- tab's group (the host tab keyed "Appearance" takes that group's place in the strip).
    local NS = setup()
    for _, kv in ipairs(KEYS) do
        local path = "skin." .. kv[1]
        local row = rowOf(NS, path)
        assertTrue(row ~= nil, path .. " is not a schema row")
        assertEqual(row.page, "general", path .. ": page")
        assertEqual(row.group, TAB, path .. ": group")
        assertTrue(row.skipRender == true, path .. ": the tab draws it, so it must be skipRender")
        assertEqual(row.default, kv[2], path .. ": default")
    end
end)

test("skin seam: the skin row's values are every registered skin, in the library's order", function()
    local NS, _, Skin = setup()
    local values = rowOf(NS, "skin.skin").values
    local skins = Skin:Skins()
    assertEqual(#values, #skins, "one value per registered skin")
    for i, def in ipairs(skins) do assertEqual(values[i].value, def.key, "value " .. i) end
    assertEqual(values[1].value, "ka0s", "Ka0s Default first")
end)

test("skin seam: /dr set refuses a skin that is not registered and applies one that is", function()
    local NS, _, Skin, counts = setup()
    NS.Slash:OnSlash("set skin.skin no-such-skin")
    assertEqual(NS.db.profile.skin.skin, "ka0s", "an unknown skin was stored")
    assertEqual(counts.looks, 0, "a refused set repainted")
    NS.Slash:OnSlash("set skin.skin obsidian")
    assertEqual(NS.db.profile.skin.skin, "obsidian", "a registered skin was refused")
    local _, applied = Skin:GetChoice(OWNER)
    assertEqual(applied, "obsidian", "a bare set must move the applied skin (the row's onChange)")
    assertEqual(counts.looks, 1, "one set, one repaint")
end)

test("skin seam: /dr set reaches an exception, and only its own half", function()
    local NS, _, Skin = setup()
    NS.Slash:OnSlash("set skin.ignoreFonts true")
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(fonts, true, "the set applied")
    assertEqual(panel, true, "the other half untouched (the default ignores the settings panel)")
end)

-- ── the tab ──────────────────────────────────────────────────────────────────────────────────────

test("skin seam: the Skin tab is the library's, after New-best toast and before Keybindings", function()
    -- skinning-§3. red under: no AppearanceTab entry in the page's tabs, or one after Keybindings.
    local NS, M = setup()
    local ctx = openTab(NS, M)
    assertEqual(ctx.activeTab, TAB)
    assertTrue(choiceNamed(NS, M, "Obsidian") ~= nil, "the tab drew no Obsidian choice")
end)

test("skin seam: one tab pick is one effective SetChoice, one repaint and no reload", function()
    -- The tab calls SetChoice first, then the write seam, which writes both rows through
    -- NS.SetByPath; each row's onChange applies only its own half and finds it applied.
    -- red under: an onChange that re-applies the whole stored pair, or a seam around the schema.
    local NS, M, Skin, counts = setup()
    local cb = choiceNamed(NS, M, "Obsidian")
    assertTrue(cb ~= nil, "the Skin tab drew no Obsidian choice")
    cb:SetValue(true); cb:__fire("OnValueChanged", true)
    assertEqual(counts.looks, 1, "one pick must repaint exactly once")
    assertEqual(counts.reloads, 0, "a Ka0s-to-Ka0s pick asks for no reload")
    local source, skin = Skin:GetChoice(OWNER)
    assertEqual(source, "ka0s")
    assertEqual(skin, "obsidian", "the pick did not move the applied skin")
    assertEqual(NS.db.profile.skin.skin, "obsidian", "the pick did not reach the profile")
end)

test("skin seam: the tab's Ignore fonts reaches the library and the profile, one repaint", function()
    local NS, M, Skin, counts = setup()
    local cb = choiceNamed(NS, M, "Ignore fonts")
    assertTrue(cb ~= nil, "the Skin tab drew no Ignore fonts box")
    cb:SetValue(true); cb:__fire("OnValueChanged", true)
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(fonts, true, "the library's exception moved")
    assertEqual(panel, true, "and the other kept")
    assertEqual(NS.db.profile.skin.ignoreFonts, true, "the profile holds it")
    assertEqual(counts.looks, 1, "one toggle repaints once")
end)

test("skin seam: another addon's copy to every Ka0s addon repaints this one once", function()
    -- The library's copy calls SetChoice for this owner, then WriteChoice, which reaches this addon's
    -- registered setter. Driven through a fake second owner.
    local NS, _, Skin, counts = setup()
    Skin:RegisterOwner("SkinProbeAddon", { label = "Skin Probe",
        get = function() return "ka0s", "ember" end, set = function() end })
    Skin:SetChoice(OWNER, "ka0s", "ember")
    assertTrue(Skin:WriteChoice(OWNER, "ka0s", "ember"), "the copy's write did not reach this addon's setter")
    assertEqual(counts.looks, 1, "a copy must repaint this addon exactly once")
    assertEqual(NS.db.profile.skin.skin, "ember", "the copy did not land in the profile")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ember")
end)

-- ── the profile: login and the profile events ────────────────────────────────────────────────────

test("skin seam: login applies the stored skin, exceptions and overrides", function()
    -- red under: no NS.ApplySkinChoice() in OnInitialize, or one that applies only the pair.
    local inst = T.load({ init = false })
    _G.DpsRaceDB = { profiles = { Default = { skin = {
        skin = "glass", ignorePanel = false, ignoreFonts = true, texture = "Blizzard" } } } }
    inst.mocks._G.DpsRaceDB = _G.DpsRaceDB
    inst.mocks.LibStub("AceAddon-3.0"):InitializeAddon(inst.NS)
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "glass", "the stored skin")
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(panel, false, "the stored panel exception")
    assertEqual(fonts, true, "the stored fonts exception")
    assertEqual(select(2, Skin:GetOverride(OWNER)), "Blizzard", "the stored texture override")
end)

test("skin seam: a profile switch applies the new profile's skin, panel built or not", function()
    -- red under: no NS.ApplySkinChoice() in core/Database.lua's NS.OnProfileChanged.
    local NS, _, Skin, counts = setup()
    local db = NS.db
    db:SetProfile("SkinProbe")
    db.profile.skin.skin = "glass"
    db:SetProfile("Default")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "back on Default, Default's skin")
    counts.looks = 0
    db:SetProfile("SkinProbe")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "glass", "the switch did not move the applied skin")
    assertEqual(counts.looks, 1, "one switch, one repaint")
end)

test("skin seam: Reset all settings puts the skin back on Ka0s Default and applies it", function()
    -- skinning-§3: a reset reaches the choice as a profile value, and re-applies it.
    local NS, _, Skin = setup()
    NS.Slash:OnSlash("set skin.skin ember")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ember")
    NS.Helpers.RestoreAllDefaults()
    assertEqual(NS.db.profile.skin.skin, "ka0s", "the stored skin reset")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "the applied skin followed")
end)

-- ── without the library ──────────────────────────────────────────────────────────────────────────

test("skin seam: the degraded facade answers every name the live facade carries", function()
    -- skinning-§1, testing-§8: without LibKa0s NS.Skin is a host table whose primitives are no-ops
    -- and whose Token / Color answer the host copy NS.SKIN_FALLBACK and the owner tokens' defaults.
    local live = T.load().NS
    local degraded = T.load({ libFiles = {} }).NS
    T.assertSurfaceParity(live.Skin, degraded.Skin, "Skin facade vs host stub", {})
    assertEqual(degraded.Skin.owner, OWNER)
    local r, g, b = degraded.SkinColor("dr.ahead")
    assertTrue(near(r, 0.36) and near(g, 0.86) and near(b, 0.46), "an owner token's default")
    assertEqual(degraded.SkinEscape("title.text"), "|cffffd100")
    assertEqual(degraded.ApplySkinChoice(), false, "nothing to apply without the library")
end)

test("skin seam: each host-copy skin token is the live library's Ka0s Default value", function()
    -- A copy that drifts from the library goes red here, so a degraded install draws Ka0s Default.
    local degraded = T.load({ libFiles = {} }).NS
    local M = T.load().mocks
    local live = M.LibStub("LibKa0s-Skin-1.0"):ResolveSkin("ka0s")
    local n = 0
    for name, c in pairs(degraded.SKIN_FALLBACK) do
        n = n + 1
        local want = live[name]
        assertTrue(type(want) == "table", name .. " is not a library color token")
        for i = 1, 4 do
            assertTrue(near(c[i], want[i]),
                ("%s[%d]: host %s, library %s"):format(name, i, tostring(c[i]), tostring(want[i])))
        end
    end
    assertTrue(n > 0, "the host copy is empty")
end)
