local _, NS = ...
-- modules/Placeholders.lua — stand-in NS.Results and NS.Preview surfaces, so the launcher, the key
-- bindings and the Master controls have real handlers to call before the windows exist.

-- REPLACED, NOT EXTENDED. T7 replaced NS.Hud (modules/Hud.lua); T8 (modules/Results.lua) replaces
-- NS.Results and T9 (modules/Preview.lua) NS.Preview; each deletes its table from this file, and the
-- last one deletes the file and its TOC line. Every member below is one the scaffold already calls,
-- so the real module owes at least this surface. They draw nothing: no frame exists until those tasks.

-- ── NS.Results ──────────────────────────────────────────────────────────────────────────────────
local Results = { wanted = false }
NS.Results = Results

function Results.IsShown() return Results.wanted and not NS.IsStoodDown() end
function Results.Show() Results.wanted = true end
function Results.Hide() Results.wanted = false end
function Results.Toggle() Results.wanted = not Results.wanted end
function Results.Suspend() end
function Results.Resume() end

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
