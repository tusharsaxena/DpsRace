local _, NS = ...
-- modules/Placeholders.lua — the stand-in NS.Preview surface, so the launcher and the Master controls
-- have real handlers to call before test mode exists.

-- REPLACED, NOT EXTENDED. T7 replaced NS.Hud (modules/Hud.lua) and T8 NS.Results (modules/Results.lua);
-- T9 (modules/Preview.lua) replaces NS.Preview, deleting this file and its TOC line. Every member below
-- is one the scaffold already calls, so the real module owes at least this surface.

-- ── NS.Preview (test mode) ──────────────────────────────────────────────────────────────────────
-- Session-only, on until turned off, ended by combat (preview-mode). The Master controls `Test mode`
-- checkbox, the launcher's Test mode entry and (from T9) `/dr test` all reach Start/Stop.
local Preview = { active = false }
NS.Preview = Preview

function Preview.IsActive() return Preview.active end

function Preview.Start()
    if NS.IsStoodDown() then return false end
    if UnitAffectingCombat("player") then return false end
    Preview.active = true
    NS.Hud.Refresh()
    return true
end

--- `reason == "combat"` says so once; any other stop is the player's own act and stays quiet.
function Preview.Stop(reason)
    if not Preview.active then return false end
    Preview.active = false
    if reason == "combat" then NS.SayTestModeEnded() end
    NS.Hud.Refresh()
    return true
end

-- Standing down ends test mode silently: the player turned the addon off, not the preview.
function Preview.Suspend() Preview.active = false end
