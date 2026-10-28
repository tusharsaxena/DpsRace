local _, NS = ...
-- modules/Results_Source.lua — where the Results window reads its runs (B5, 2026-10-25): the store, or
-- while test mode or a sim is on, an in-memory sample history (modules/MockRuns.lua) that is never
-- written anywhere.
--
-- ONE SEAM. Every Results file asks this module, never NS.Recorder, NS.Bests or NS.Loadouts, for the
-- runs it lists, a run by id, the bests board (Spec best and the compare), a run's loadout, its chart, and to store a
-- note or delete a run. With no sample history in place each answer is the store's own (the same
-- function, called at call time, so a suite's stub on NS.Bests or NS.Recorder still reaches the
-- window). With one in place (Source.Use) the answers come from it, and a note or a delete changes it
-- in memory only.
--
-- THE SAMPLE HISTORY is a plain table: `runs` (an array, any order), `loadouts` ({ gear = { [key] =
-- set }, talents = { [key] = loadout } }, keyed as a stored run's `loadout` refers to them) and
-- `slices` ({ [run id] = { count, values, length, filled } }: plain numbers, a sample curve). It never
-- reaches SavedVariables: nothing here writes NS.db, and the Results window's own writers (Save view,
-- Share) refuse while it is shown (modules/Results.lua, modules/Results_Runs.lua).

local Source = {}
NS.ResultsSource = Source

local mock        -- the sample history in place, or nil
local boards = {} -- the sample's bests boards, by cleanOnly (Spec best reads the all-runs one); dropped on a change

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Results", fmt, ...) end
end

-- Newest first; a date tie breaks on the id, as Recorder.All sorts the store.
local function newerFirst(a, b)
    local da, db = a.date or 0, b.date or 0
    if da ~= db then return da > db end
    return tostring(a.id) > tostring(b.id)
end

-- The shell redraws on every change of source or sample (modules/Results.lua).
local function changed(swapped)
    boards = {}
    local R = NS.Results
    if R and type(R.OnSourceChanged) == "function" then R.OnSourceChanged(swapped) end
end

--- Whether the window reads the sample history now.
function Source.IsMock()
    return mock ~= nil
end

--- Read `dataset` instead of the store until Restore. A second Use replaces the first.
--- @param dataset table  { runs, loadouts, slices }
function Source.Use(dataset)
    if type(dataset) ~= "table" then return false end
    dataset.runs = type(dataset.runs) == "table" and dataset.runs or {}
    dataset.loadouts = type(dataset.loadouts) == "table" and dataset.loadouts or {}
    dataset.slices = type(dataset.slices) == "table" and dataset.slices or {}
    mock = dataset
    debug("source: sample history (%d runs)", #dataset.runs)
    changed(true)
    return true
end

--- Back to the store. Answers whether a sample history was in place.
function Source.Restore()
    if not mock then return false end
    mock = nil
    debug("source: the store")
    changed(true)
    return true
end

--- Add `run` (and its chart record) to the sample history in place: the sim's run (modules/Sim.lua).
--- @return boolean added
function Source.Add(run, slices)
    if not mock or type(run) ~= "table" then return false end
    mock.runs[#mock.runs + 1] = run
    if type(slices) == "table" then mock.slices[run.id] = slices end
    changed(false)
    return true
end

--- Every run the window lists, newest first (a fresh array).
function Source.All()
    if not mock then return NS.Recorder.All() end
    local out = {}
    for i, run in ipairs(mock.runs) do out[i] = run end
    table.sort(out, newerFirst)
    return out
end

--- The run with this id, or nil.
function Source.Get(id)
    if not mock then return NS.Recorder.Get(id) end
    if id == nil then return nil end
    for _, run in ipairs(mock.runs) do
        if run.id == id then return run end
    end
    return nil
end

--- Drop the sample's bests boards without a redraw: the late-cast ignore list (#8) or the profile
--- changed, so the clean-only board's flags may have (modules/Results.lua calls it, then redraws).
function Source.Invalidate()
    boards = {}
end

--- The bests board (NS.Bests.Board's shape).
--- @param opts table|nil  { cleanOnly = true }
function Source.Board(opts)
    if not mock then return NS.Bests.Board(opts) end
    local cleanOnly = type(opts) == "table" and opts.cleanOnly == true
    local board = boards[cleanOnly]
    if not board then
        board = NS.Bests.Compute(mock.runs, { cleanOnly = cleanOnly })
        boards[cleanOnly] = board
    end
    return board
end

--- A run's gear set and talent loadout (NS.Loadouts.Of's answers).
function Source.LoadoutOf(run)
    if not mock then return NS.Loadouts.Of(run) end
    local ref = type(run) == "table" and run.loadout
    if type(ref) ~= "table" then return nil, nil end
    local gear = ref.gear ~= nil and (mock.loadouts.gear or {})[ref.gear] or nil
    local talents = ref.talents ~= nil and (mock.loadouts.talents or {})[ref.talents] or nil
    return gear, talents
end

--- Whether a run's gear differs from the same racer's previous run (NS.Loadouts.GearChanged's).
function Source.GearChanged(run)
    if not mock then return NS.Loadouts.GearChanged(run) end
    return NS.Loadouts.GearChanged(run, Source.All())
end

-- A sample run's chart: its record scaled to its plain final damage, as HudChart.ResultView draws a
-- stored run's in-session slices (none for a lost run or a shared session), against the sample's best
-- before it (HudChart.WithBest: the diagonal and the shared max), with its cooldown icons.
local function mockChart(run)
    local rec = type(run) == "table" and mock.slices[run.id]
    if type(rec) ~= "table" or run.status == "lost" then return nil end
    if type(run.flags) == "table" and run.flags.sharedSession then return nil end
    local damage = type(run.result) == "table" and run.result.damage
    if type(damage) ~= "number" or damage <= 0 then return nil end
    local view = { count = rec.count, values = rec.values, length = rec.length, max = damage, note = "",
                   cooldowns = NS.HudChart.CooldownsOf(run) }
    return NS.HudChart.WithBest(view, run, NS.Bests.Before(run, mock.runs))
end

--- The after-the-race chart's view for `run`, or nil (NS.HudChart.ResultView's).
function Source.ChartView(run)
    if not mock then return NS.HudChart.ResultView(run) end
    return mockChart(run)
end

--- Store a note (already clamped). The sample's note lives in memory.
--- @return boolean stored
function Source.SetNote(id, note)
    if not mock then return NS.Recorder.SetNote(id, note) end
    local run = Source.Get(id)
    if not run then return false end
    run.note = note
    changed(false)
    return true
end

--- A sample run changed in memory (its usage ticks, modules/Usage.lua SetUsed): redraw, as a note does.
function Source.Touched()
    if mock then changed(false) end
end

--- Delete a run. A sample run leaves the sample history only.
--- @return boolean removed
function Source.Delete(id)
    if not mock then return NS.Recorder.Delete(id) end
    for i, run in ipairs(mock.runs) do
        if run.id == id then
            table.remove(mock.runs, i)
            mock.slices[id] = nil
            changed(false)
            return true
        end
    end
    return false
end
