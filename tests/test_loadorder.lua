-- tests/test_loadorder.lua — the runner's load list IS the TOC's (testing-§9): fed exactly the TOC's
-- files in the TOC's order, every derived path on disk, and no libs/ path leaked in.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

test("load order: the runner loaded exactly the TOC's files, in the TOC's order", function()
    local fresh = T.Loader.tocFiles(T.root .. "/DpsRace.toc")
    local loaded = T.loadedAddonFiles
    assertTrue(#fresh > 0, "the TOC derivation is empty; nothing below can fail")
    assertEqual(#loaded, #fresh, "the runner's list and the TOC differ in length")
    for i, path in ipairs(fresh) do assertEqual(loaded[i], path, "position " .. i) end
end)

test("load order: the hearthstones load before the ignore list, and the ignore list before its readers", function()
    local at = {}
    for i, path in ipairs(T.loadedAddonFiles) do at[path:gsub("\\", "/")] = i end
    local hs, li = at["defaults/Hearthstones.lua"], at["modules/LateIgnore.lua"]
    assertTrue(hs and li and at["defaults/Profile.lua"] < li and hs < li, "the data the list reads at file scope")
    for _, reader in ipairs({ "modules/Scoring.lua", "modules/Bests.lua", "modules/Hud.lua", "settings/Race.lua" }) do
        assertTrue(li < at[reader], reader)
    end
end)

test("load order: every derived path exists on disk", function()
    for _, path in ipairs(T.loadedAddonFiles) do
        local f = io.open(T.root .. "/" .. path, "rb")
        assertTrue(f ~= nil, path .. " is in the TOC but not on disk")
        if f then f:close() end
    end
end)

test("load order: no libs/ path leaked into the addon's own list", function()
    for _, path in ipairs(T.loadedAddonFiles) do
        assertFalse(path:find("^libs[/\\]") ~= nil, path .. " is a library file in the addon's list")
    end
end)
