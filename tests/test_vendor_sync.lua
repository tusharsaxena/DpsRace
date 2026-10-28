-- tests/test_vendor_sync.lua — the vendored-payload gate (testing-§11): libs/LibKa0s/ and tests/_kit/
-- are exactly what LibKa0s published at the tag root CLAUDE.md names, icons pruned to its declaration.
-- DELEGATES to the kit's own gate; never a reimplementation of the comparison.
--
-- ONE TEMPORARY EXCEPTION (docs/ARCHITECTURE.md, Documented deviations, library-stack-§7): the owner
-- had LibKa0s-Toast-1.0 (`Toast.lua`) copied alone into libs/LibKa0s/ ahead of the rest, from the
-- LibKa0s branch CLAUDE.md names. The kit's file-set comparison is handed the payload without that
-- one file while the tag lacks it, and a case of its own holds the file byte for byte to the branch.
-- Once the tag carries it (the next full re-vendor) the exception fails loudly: drop it, the TOC line
-- and the deviation row together.

local T = _G.DPSRACE_TEST
local VendorSync = dofile((T.root or ".") .. "/tests/_kit/vendor_sync.lua")

local AHEAD = "Toast.lua"
local AHEAD_REFS = { "feat/2026-10-28-toast-1.0", "master" }   -- where the LibKa0s repo carries it
local SIBLING = (T.root or ".") .. "/../LibKa0s"

--- `list` (the kit's ", "-joined file set) without the ahead file.
local function without(list)
    local out = {}
    for name in tostring(list):gmatch("[^,%s]+") do
        if name ~= AHEAD then out[#out + 1] = name end
    end
    return table.concat(out, ", ")
end

local function aheadIn(list)
    for name in tostring(list):gmatch("[^,%s]+") do
        if name == AHEAD then return true end
    end
    return false
end

-- The kit's T, with the one file-set assertion of libs/LibKa0s narrowed to leave the ahead file out.
local gateT = setmetatable({}, { __index = T })
gateT.assertEqual = function(actual, expected, msg)
    local m = tostring(msg)
    if m:find("libs/LibKa0s holds the same files", 1, true) then
        T.assertFalse(aheadIn(expected), "the tag now carries " .. AHEAD
            .. ": drop this exception, the TOC's Toast.lua line and the deviation row")
        actual = without(actual)
    end
    return T.assertEqual(actual, expected, msg)
end
VendorSync.register(gateT, { root = T.root })

local function readBytes(path)
    local fh = io.open(path, "rb")
    if not fh then return nil end
    local body = fh:read("*a")
    fh:close()
    return body
end

local function siblingBlob(ref)
    if not io.popen then return nil end
    local pipe = io.popen(('git -C "%s" show "%s:LibKa0s/%s" 2>/dev/null'):format(SIBLING, ref, AHEAD), "r")
    if not pipe then return nil end
    local body = pipe:read("*a")
    pipe:close()
    return body ~= "" and body or nil
end

T.test("libs/LibKa0s/Toast.lua, vendored alone, is the LibKa0s branch's file byte for byte", function()
    local here = readBytes(T.root .. "/libs/LibKa0s/" .. AHEAD)
    T.assertTrue(here ~= nil, "libs/LibKa0s/" .. AHEAD .. " is on disk")
    local blob
    for _, ref in ipairs(AHEAD_REFS) do
        blob = blob or siblingBlob(ref)
    end
    if not blob then T.skip(SIBLING .. " carries no " .. AHEAD .. " on " .. table.concat(AHEAD_REFS, " or ")
        .. " -- the ahead file was NOT compared") end
    T.assertEqual((here or ""):gsub("\r\n", "\n"), blob, AHEAD .. " matches the LibKa0s branch -- re-copy it, do not edit it")
end)
