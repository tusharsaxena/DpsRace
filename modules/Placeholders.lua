local _, NS = ...
-- modules/Placeholders.lua — stand-in NS.Hud, NS.Results and NS.Preview surfaces, so the launcher, the
-- key bindings and the Master controls have real handlers to call before the windows exist.

-- REPLACED, NOT EXTENDED. T7 (modules/Hud.lua) replaces NS.Hud, T8 (modules/Results.lua) NS.Results
-- and T9 (modules/Preview.lua) NS.Preview; each deletes its table from this file, and the last one
-- deletes the file and its TOC line. Every member below is one the scaffold already calls, so the
-- real module owes at least this surface. They draw nothing: no frame exists until those tasks.

-- ── NS.Hud ──────────────────────────────────────────────────────────────────────────────────────
-- The positionable display (Lock frame, Master scale, Reset position and the Show window toggle all
-- act on it). `wanted` is the player's show/hide; the master rungs decide whether that can show.
local Hud = { wanted = false, locked = false }
NS.Hud = Hud

function Hud.IsShown()
    return Hud.wanted and (NS.MasterVisibilityAllows()) or false
end
function Hud.Show() Hud.wanted = true end
function Hud.Hide() Hud.wanted = false end
function Hud.Toggle() Hud.wanted = not Hud.wanted end
function Hud.SetLocked(on) Hud.locked = on and true or false end
function Hud.ResetPosition() end
function Hud.Refresh() end
function Hud.Suspend() end
function Hud.Resume() end

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
