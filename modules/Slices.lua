local _, NS = ...
-- modules/Slices.lua — the damage chart's in-session store (#2): one opaque live total per time
-- bucket of a race, held in memory by run id, so the HUD can draw the race's damage curve live and the
-- HUD result card and the Results detail can draw it again after the race.
--
-- THE BUCKETS are plain: min(60, the race length in whole seconds) of them, each spanning length /
-- count seconds of the race clock. On the first live read at or after a bucket's end boundary
-- (modules/Hud.lua's Meter.ReadLive cadence, plus a timer at each boundary and one last read at the
-- buzzer), that read's live total is COPIED into the bucket. The value is never inspected: no
-- arithmetic, no comparison, no truth test, never a key. The one question asked of it is `== nil`.
--
-- HONEST HOLES. A boundary that passed more than LATE seconds before the read that noticed it (the
-- HUD was closed, a /reload lost the store) leaves its bucket empty rather than fill it with a later
-- total; so does a bucket that ended while the run was on a shared session (its total carries damage
-- from before the arm, which cannot be netted live). Only the HUD's reads capture, so a race run with
-- the HUD closed has no chart.
--
-- IN MEMORY ONLY, NEVER STORED. The client writes a secret to SavedVariables as nil (the reload probe,
-- 2026-10-25, issue #2), so a run raced before the last /reload or login has no chart. Nothing here
-- writes to the run record.

local Slices = {}
NS.Slices = Slices

Slices.MAX = 60
-- How late (seconds) a read may notice a boundary and still fill its bucket.
Slices.LATE = 1.0
-- Float slack on a boundary: a timer fired AT the boundary counts as at or after it.
local EPS = 1e-6

local store = {}   -- [run id] = { length, count, values = { [i] = opaque }, next, filled }

--- The bucket count for a race of `length` seconds: one a second up to MAX.
--- @param length number
--- @return number
function Slices.Count(length)
    local n = math.floor(tonumber(length) or 0)
    return math.max(1, math.min(Slices.MAX, n))
end

--- Bucket `i`'s end boundary, in seconds of the race clock.
--- @param length number
--- @param count number
--- @param i number
--- @return number
function Slices.Boundary(length, count, i)
    return length * i / count
end

local function usable(run)
    return type(run) == "table" and run.id ~= nil and type(run.race) == "table"
        and type(run.race.length) == "number" and run.race.length > 0
end

local function recordFor(run)
    local rec = store[run.id]
    if rec then return rec end
    local length = run.race.length
    rec = { length = length, count = Slices.Count(length), values = {}, next = 1, filled = 0 }
    store[run.id] = rec
    return rec
end

local function shared(run)
    return type(run.flags) == "table" and run.flags.sharedSession == true
end

--- A live read `elapsed` seconds into `run`'s race answered `total` (opaque): copy it into every
--- bucket whose boundary it is the first read at or after. A boundary too far behind (LATE) or ended
--- on a shared session is passed with its bucket left empty; a read with no total (nil) fills nothing
--- and leaves a recent boundary for the next read.
--- @param run table
--- @param elapsed number  plain, from GetTime()
--- @param total any  the live total, possibly secret, or nil; only copied
--- @return number filled  buckets filled by this read
function Slices.Capture(run, elapsed, total)
    if not usable(run) or type(elapsed) ~= "number" then return 0 end
    local rec, n = recordFor(run), 0
    local skip = shared(run)
    while rec.next <= rec.count do
        local boundary = Slices.Boundary(rec.length, rec.count, rec.next)
        if elapsed + EPS < boundary then break end
        local recent = elapsed - boundary <= Slices.LATE
        if recent and total == nil and not skip then break end
        if recent and not skip then
            rec.values[rec.next] = total
            rec.filled = rec.filled + 1
            n = n + 1
        end
        rec.next = rec.next + 1
    end
    return n
end

--- The race-clock time of `run`'s next bucket boundary still to come, or nil when every one is done.
--- @param run table
--- @return number|nil
function Slices.NextBoundary(run)
    if not usable(run) then return nil end
    local rec = recordFor(run)
    if rec.next > rec.count then return nil end
    return Slices.Boundary(rec.length, rec.count, rec.next)
end

--- `run`'s record: { length, count, values, filled }, or nil before its first capture.
--- @param id any  a run id
--- @return table|nil
function Slices.Get(id)
    if id == nil then return nil end
    return store[id]
end

--- The record the after-the-race chart draws for `run`, or nil when there is none to draw: a lost run,
--- a run with no plain damage to scale to, a shared session, or no bucket filled this session.
--- @param run table
--- @return table|nil
function Slices.Drawable(run)
    if type(run) ~= "table" or run.status == "lost" or shared(run) then return nil end
    local result = run.result
    local damage = type(result) == "table" and result.damage
    if type(damage) ~= "number" or damage <= 0 then return nil end
    local rec = Slices.Get(run.id)
    if not rec or rec.filled == 0 then return nil end
    return rec
end

--- How many races this session hold a record (the diagnostics report).
--- @return number
function Slices.Held()
    local n = 0
    for _ in pairs(store) do n = n + 1 end
    return n
end

--- Drop every record (the suites; nothing in the addon forgets a race within a session).
function Slices.Reset()
    store = {}
end
