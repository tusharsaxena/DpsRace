local _, NS = ...
-- modules/Preview.lua — test mode and the sim's shared shell (spec §6.5, preview-mode; B5, the owner's
-- call, 2026-10-25). Two modes, one switch:
--
--   test  `/dr test [armed|running|result]`, the Master controls' Test mode row and the launcher's
--         entry: STATIC sample data in every view. The HUD holds one body still (the running body
--         by default: its clock, live figures, chart, pace bar and spells) and the Results window
--         opens on a made-up run history (modules/MockRuns.lua) so the Runs list, the Bests tab and
--         the detail (compare, chart, gear and talents) can be seen without a real history.
--   sim   `/dr sim [scenario]`: a whole sample race played through the HUD's bodies (armed, running,
--         Stop!, waiting, the result card), then the Results window on the sim's run beside the same
--         history (modules/Sim.lua holds the scenarios and the script).
--
-- Both draw through the windows' own render paths: the HUD's bodies through NS.Hud.Render, the
-- Results window through its source seam (modules/Results_Source.lua), routed to the sample history
-- while either is on and back to the store when it ends; each window lays its test-mode strip over
-- itself meanwhile.
--
-- Test mode also shows the sample race's new-best toast, held still to be dragged into place
-- (modules/BestToast.lua, #5); the sim and the end of test mode take it down.
--
-- Session-only and on until turned off. It ENDS on combat (core/DpsRace.lua's PLAYER_REGEN_DISABLED),
-- on arming a real race, on its own switch, on Reset all settings (the row's default), on closing the
-- HUD or its sample Cancel (modules/Hud.lua's acts, which never touch the real race), and silently on
-- the stand-down. A start is refused in combat and while a real race is armed, running or waiting for
-- its result. It never touches the race engine and never writes a run, a note or a view: the sample
-- lives only in memory.

local Preview = { active = false }
NS.Preview = Preview

local L = NS.L

-- The HUD bodies test mode can hold still, and the one it opens on.
Preview.STATES = { "armed", "running", "result" }
Preview.DEFAULT_STATE = "running"
-- The static running body's moment: this far into the sample race (clear of the final countdown).
Preview.STILL_AT = 18

local mode            -- "test" | "sim" while active
local state           -- the static body test mode holds
local queued          -- the next start's { mode, state | scenario }, set by the slash verbs
local opened          -- the HUD was opened by the preview (closed again at the end)
local resultsOpened   -- the Results window was opened by the preview (closed again at the end)
local dataset         -- the sample history the Results window reads meanwhile
local sample          -- the static HUD's sample race

local function debug(fmt, ...) NS.Debug("Test", fmt, ...) end

local function isState(word)
    for _, s in ipairs(Preview.STATES) do
        if s == word then return true end
    end
    return false
end
Preview.IsState = isState

-- A real race on screen: armed, running or waiting for its result (spec §6.5).
local function raceOn()
    local S, cur = NS.Race.STATE, NS.Race.State()
    return cur == S.ARMED or cur == S.RUNNING or cur == S.STOPPING
end

function Preview.IsActive() return Preview.active end

--- The mode on: "test", "sim", or nil when off.
function Preview.Mode() return Preview.active and mode or nil end

--- The sample history the Results window reads while the preview is on (nil when off).
function Preview.Dataset() return Preview.active and dataset or nil end

-- The Master controls' Test mode checkbox reads Preview.IsActive() only when a refresher runs: every
-- start and stop repaints an open panel in place (options-ui-§11, §15), whoever turned it.
local function repaintPanel()
    local H = NS.Helpers
    if H and type(H.RefreshScalars) == "function" then H.RefreshScalars() end
end

--- Draw `key`'s body with `run` and `figures` on the HUD (the sim's and the static test's one path).
--- The center countdown shows in the sim's last seconds, silently, and goes with its buzzer.
function Preview.Draw(key, run, figures)
    NS.Hud.Render(key, run, figures)
    local C = NS.Countdown
    if not C then return end
    if key == "running" and mode == "sim" then C.Preview(figures.timeLeft) else C.EndPreview() end
end

--- The Results window on the sample history, opened if it was not (and closed again at the end).
--- `id` opens that run's detail.
function Preview.OpenResults(id)
    local R = NS.Results
    if not R then return end
    if not resultsOpened then resultsOpened = not R.wanted end
    if id then R.ShowRun(id) else R.Show() end
end

--- The Results window was closed (Results.Hide or Escape): a later open is the player's own, so the
--- end of the preview no longer closes it. A sample open after this one asks again.
function Preview.ResultsClosed()
    resultsOpened = false
end

-- ── test mode: the static views ────────────────────────────────────────────────────────────────

-- The static HUD: the sample race beating the history's best on its board (the most a body draws:
-- the chart against the best's pace, the pace bar and the delta chip).
local function drawStill()
    local t = state == "running" and Preview.STILL_AT or 0
    Preview.Draw(state, sample.run, NS.MockRuns.Figures(sample, state, t))
end

local function startTest(want)
    state = isState(want) and want or (isState(state) and state or Preview.DEFAULT_STATE)
    sample = NS.Sim.Sample("newbest", dataset.runs)
    drawStill()
    Preview.OpenResults()
    -- The sample race's new-best toast, held for placing (#5).
    NS.BestToast.ShowPreview(sample)
end

--- Hold `word`'s body still on the HUD (test mode only).
--- @return boolean switched
function Preview.SetState(word)
    if not (Preview.active and mode == "test" and isState(word)) then return false end
    state = word
    drawStill()
    return true
end

-- ── the switch ─────────────────────────────────────────────────────────────────────────────────

--- What the next Start runs: { mode = "test", state = word } or { mode = "sim", scenario = key }.
--- The slash verbs queue it, then turn the Test mode row on through the write seam (or call Start
--- straight when the preview is already on and the row cannot change).
function Preview.Queue(opts)
    queued = type(opts) == "table" and opts or nil
end

local function refuse(line)
    NS.Print(line)
    return false
end

local function stopSim()
    if NS.Sim then NS.Sim.Cancel() end
    if NS.Countdown then NS.Countdown.EndPreview() end
end

--- Turn the preview on, or switch an active one to the queued mode in place. Refused (one line) in
--- combat and during a real race; silent while stood down, where the caller's own hold-aware refusal
--- has already spoken.
--- @param opts table|nil  as Queue; nil takes the queued start, else test mode's default
--- @return boolean started
function Preview.Start(opts)
    opts = opts or queued or { mode = "test" }
    queued = nil
    if NS.IsStoodDown() then return false end
    if UnitAffectingCombat("player") then return refuse(L["Test mode is not available in combat."]) end
    if raceOn() then return refuse(L["Test mode is not available during a race."]) end
    stopSim()
    local was = Preview.active
    Preview.active, mode = true, opts.mode == "sim" and "sim" or "test"
    if not was then
        -- Shown for the preview; closed again at the end only if the player had not opened it.
        -- Opened as the addon's own (Hud.AutoShow): a race that ends test mode inherits it, and onArm
        -- closes it with that race; the stand-down drops it (Hud.Suspend).
        opened = not NS.Hud.wanted
        if opened then NS.Hud.AutoShow() end
    end
    dataset = NS.MockRuns.Dataset()
    NS.ResultsSource.Use(dataset)
    if mode == "sim" then
        NS.BestToast.EndPreview()
        NS.Sim.Begin(opts.scenario, dataset)
    else
        startTest(opts.state)
    end
    repaintPanel()
    debug("%s on (%s)", mode, tostring(mode == "sim" and NS.Sim.Scenario() or state))
    return true
end

-- Give the windows back: the store to the Results window, each window closed if the preview opened
-- it. A race that ended it keeps the HUD for itself.
local function release(reason)
    if resultsOpened then NS.Results.Hide() end
    resultsOpened = false
    NS.ResultsSource.Restore()
    if opened and reason ~= "race" then
        opened = false
        NS.Hud.Hide()
    else
        opened = false
        NS.Hud.Refresh()
    end
end

--- Turn the preview off. `reason` "combat" says so once; "race" (a real race was armed) keeps the
--- HUD open for that race; any other stop is the player's own act and stays quiet.
--- @param reason string|nil
--- @return boolean stopped
function Preview.Stop(reason)
    if not Preview.active then return false end
    Preview.active = false
    stopSim()
    if reason == "combat" then NS.SayTestModeEnded() end
    local was = mode
    mode, sample, dataset = nil, nil, nil
    NS.BestToast.EndPreview()
    release(reason)
    repaintPanel()
    debug("%s off (%s)", tostring(was), reason or "switch")
    return true
end

--- The stand-down ends the preview silently: the player turned the addon off, not the preview. A
--- Results window it opened is dropped (the lifecycle hides it next), so the stand-up does not bring
--- it back.
function Preview.Suspend()
    local was = Preview.active
    Preview.active = false
    stopSim()
    if resultsOpened and NS.Results then NS.Results.wanted = false end
    mode, sample, dataset, opened, resultsOpened = nil, nil, nil, false, false
    NS.ResultsSource.Restore()
    NS.BestToast.EndPreview()
    if was then repaintPanel() end
end

--- What the preview is doing, for the diagnostics report and the suites.
function Preview.Diagnose()
    local sim = NS.Sim and NS.Sim.Diagnose() or {}
    local phase = "none"
    if Preview.active then phase = mode == "sim" and sim.phase or state end
    return { active = Preview.active, mode = Preview.Mode() or "none", phase = phase,
             scenario = Preview.active and mode == "sim" and sim.scenario or "none", ticking = sim.ticking == true }
end

-- Arming a real race ends the preview (spec §6.5): the HUD then shows the race.
do
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.RACE_STATE_CHANGED, function(_, _, _, to)
            if to == NS.Race.STATE.ARMED and Preview.active then
                NS.Print(L["Test mode ended: a race was armed."])
                Preview.Stop("race")
            end
        end)
    end
end
