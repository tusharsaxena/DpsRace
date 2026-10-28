local _, NS = ...
-- modules/Bests.lua — personal bests (spec §6.2, §7): one board per spec × category × race length,
-- across every character on the account, worked out from the stored runs and cached per session; the
-- delta to the best before a run; and the set of runs pruning must keep (Recorder.Prune).
--
-- PURE over plain run records: no WoW API and no meter value (every number on a stored run went
-- through NS.Secrets on its way in). Only `complete` runs count (spec §5.4: incomplete and lost
-- never do); flags inform and never void, so a flagged run holds a best unless cleanOnly asks.
--
-- THE CACHE is one board per cleanOnly value, built on first ask and dropped on RUN_SAVED and
-- RUNS_CHANGED. The same RUN_SAVED receiver prunes to `global.history.keepDays` (0 = never, spec §6.3);
-- core/DpsRace.lua's OnEnable prunes at login. The receiver is a bus target of this module's own, so
-- the latch drops it at stand-down and replays it at stand-up (slash-commands-§7).

local Bests = {}
NS.Bests = Bests

local cache = {}   -- [true|false] = board

--- The board a run belongs on: "specID|category|length".
--- @return string key
function Bests.Key(run)
    local char, target, race = run.char or {}, run.target or {}, run.race or {}
    return ("%s|%s|%s"):format(tostring(char.specID), tostring(target.category or "other"),
        tostring(race.length))
end

local function dpsOf(run)
    local result = run.result
    local dps = type(result) == "table" and result.dps or nil
    return type(dps) == "number" and dps or nil
end

--- Whether a run can hold a best at all: complete, with a score.
local function counts(run)
    return type(run) == "table" and run.status == "complete" and dpsOf(run) ~= nil
end

local function flagged(run)
    return #NS.Scoring.Flags(run) > 0
end

--- `a` ranks above `b`: higher DPS; on a tie the earlier run (it set the mark first), then the id.
local function ranksAbove(a, b)
    local da, db = dpsOf(a), dpsOf(b)
    if da ~= db then return da > db end
    local ta, tb = a.date or 0, b.date or 0
    if ta ~= tb then return ta < tb end
    return tostring(a.id) < tostring(b.id)
end

--- The best run per board.
--- @param runs table  an array of runs (any status; only complete ones count)
--- @param opts table|nil  { cleanOnly = true } leaves out every run with a flag
--- @return table board  { [key] = run }
function Bests.Compute(runs, opts)
    local cleanOnly = type(opts) == "table" and opts.cleanOnly == true
    local board = {}
    for _, run in ipairs(runs or {}) do
        if counts(run) and not (cleanOnly and flagged(run)) then
            local key = Bests.Key(run)
            local held = board[key]
            if not held or ranksAbove(run, held) then board[key] = run end
        end
    end
    return board
end

--- The cached board over the whole store (the Results window's Bests tab and the HUD's delta).
--- @param opts table|nil  as Compute
function Bests.Board(opts)
    local cleanOnly = type(opts) == "table" and opts.cleanOnly == true
    local board = cache[cleanOnly]
    if not board then
        board = Bests.Compute(NS.Recorder.All(), { cleanOnly = cleanOnly })
        cache[cleanOnly] = board
    end
    return board
end

--- Drop the cached boards; the next Board() rebuilds them from the store.
function Bests.Invalidate()
    cache = {}
end

--- `a` was raced before `b` (date, then id: the same order the store sorts by).
local function before(a, b)
    local ta, tb = a.date or 0, b.date or 0
    if ta ~= tb then return ta < tb end
    return tostring(a.id) < tostring(b.id)
end

--- `other` counts, is on `run`'s board and was raced before it.
local function isEarlierRival(other, run, key)
    if other == run or other.id == run.id or not counts(other) then return false end
    return before(other, run) and Bests.Key(other) == key
end

--- The best on `run`'s board among the runs raced BEFORE it: what Delta compares against, and what
--- the HUD result card's pace bar sets the run beside (the previous best when the run just became
--- the best). `run` itself need not count.
--- @param run table
--- @param runs table|nil  defaults to every stored run
--- @return table|nil prev
function Bests.Before(run, runs)
    if type(run) ~= "table" then return nil end
    local key, prev = Bests.Key(run), nil
    for _, other in ipairs(runs or NS.Recorder.All()) do
        if isEarlierRival(other, run, key) and (not prev or ranksAbove(other, prev)) then prev = other end
    end
    return prev
end

--- The run compared with the best on its board BEFORE it.
--- @param run table
--- @param runs table|nil  defaults to every stored run
--- @return number|nil pct  (dps / previous best dps - 1) * 100; nil with no previous best or no score
--- @return boolean isNewBest  it beats the previous best, or is the first complete run on its board
--- @return table|nil prev  the previous best it was compared with (Bests.Before), nil with none (the
---   new-best toast names its DPS, modules/BestToast.lua)
function Bests.Delta(run, runs)
    if not counts(run) then return nil, false, nil end
    local prev = Bests.Before(run, runs)
    if not prev then return nil, true, nil end
    local mine, theirs = dpsOf(run), dpsOf(prev)
    if theirs <= 0 then return nil, mine > theirs, prev end
    return (mine / theirs - 1) * 100, mine > theirs, prev
end

--- Every run holding a best on the all-runs board or the clean-only board: what pruning keeps.
--- @return table ids  { [id] = true }
function Bests.HoldingIDs(runs)
    local ids = {}
    for _, cleanOnly in ipairs({ false, true }) do
        for _, run in pairs(Bests.Compute(runs, { cleanOnly = cleanOnly })) do ids[run.id] = true end
    end
    return ids
end

--- Prune to the stored setting (0 = never). Called at OnEnable and on every RUN_SAVED, which passes
--- the saved run's id so the run just stored is never the one removed.
--- @param protect string|nil  a run id the prune keeps
--- @return number removed
function Bests.PruneToSetting(protect)
    local days = NS.GetSetting and NS.GetSetting("global.history.keepDays")
    return NS.Recorder.Prune(days, protect)
end

-- ── bus ─────────────────────────────────────────────────────────────────────────────────────────

local receiver = NS.NewBusTarget and NS.NewBusTarget()
if receiver then
    receiver:RegisterMessage(NS.MSG.RUN_SAVED, function(_, run)
        Bests.Invalidate()
        Bests.PruneToSetting(type(run) == "table" and run.id or nil)
    end)
    receiver:RegisterMessage(NS.MSG.RUNS_CHANGED, function() Bests.Invalidate() end)
end
