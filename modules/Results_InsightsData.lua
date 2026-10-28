local _, NS = ...
-- modules/Results_InsightsData.lua — the Insights tab's pure half (#12): its filters, the faceted
-- dropdown options with their counts, and the one stats pass that feeds the cards and the chart
-- sections (docs/superpowers/plans/2026-10-28-ignore-list-insights.md, "Insights analysis"). No frames:
-- modules/Results_Insights.lua draws what this returns.
--
-- PURE over plain run records but for what it reads at CALL time: NS.L for the option labels, date()
-- and time() for the local day a run falls on, and the late-cast ignore list through Runs.IsFlagged
-- (Scoring.Flags) and Scoring.SplitLate, never a run's raw list. So a change to the list re-scores
-- every figure here on the next call. Runs.IsFlagged is memoized per run within one Options or
-- Compute call, never across calls, because the list can change in between.
--
-- BOARD-RELATIVE (D-10). DPS compares only within a board (spec, target category, race length:
-- Bests.Key). Every figure that mixes boards is a run's % of its board's best, that best taken over
-- the runs given (the filtered set, not the whole store); raw DPS is for one board only. DPS figures
-- read complete runs only. A lost run never counts anywhere.
--
-- ONE PASS. Compute walks the runs once, handing each to every REDUCERS entry, then runs the
-- FINALIZERS over what they gathered (the boards, sorted lists, gap days). Each piece stays a small
-- function; a new section is one reducer and one finalizer.

local InsightsData = {}
NS.InsightsData = InsightsData

local L = NS.L
local Runs = NS.ResultsRuns

--- The filters a new profile opens with (D-11): every character, spec, target, length and date,
--- Clean only off, Include incomplete off. Insights is the cross-character view.
InsightsData.DEFAULTS = {
    char = "all", spec = "all", category = "all", length = "all", date = "all",
    cleanOnly = false, includeIncomplete = false,
}
--- The dropdowns in bar order: the order Normalize checks them in.
InsightsData.ORDER = { "char", "spec", "category", "length", "date" }

-- The value facets, in bar order: the "all" head's label and the value a run carries for each.
local FACETS = {
    { key = "char", head = L["All characters"], of = Runs.CharKey },
    { key = "spec", head = L["All specs"], of = function(run) return run.char and run.char.specID end },
    { key = "category", head = L["All targets"],
      of = function(run) return run.target and run.target.category or "other" end },
    { key = "length", head = L["Any length"], of = function(run) return run.race and run.race.length end },
}
local DATE = #FACETS + 1     -- the date range's slot after the value facets

local TAIL_EDGES = { 5, 10, 15, 20 }   -- section J's buckets: 0-5, 5-10, 10-15, 15-20, 20+ s
local SPELL_TOP = 8                     -- section H's rows
local CONSISTENT_MIN = 3                -- section C's least runs on a board
local MAX_DAYS = 3660                   -- section I's longest span, a guard against a stray date
local UNKNOWN = "unknown"               -- a late cast with no spell ID (sealed): counted, never ignored

-- ── the filters ─────────────────────────────────────────────────────────────────────────────────

-- `f` over DEFAULTS, as a new table: only the known keys, a missing one at its default.
local function merged(f)
    f = type(f) == "table" and f or {}
    local out = {}
    for k, def in pairs(InsightsData.DEFAULTS) do
        local v = f[k]
        if v == nil then v = def end
        out[k] = v
    end
    return out
end

-- Runs.IsFlagged, memoized for one call.
local function flaggedMemo()
    local memo = {}
    return function(run)
        local v = memo[run]
        if v == nil then
            v = Runs.IsFlagged(run)
            memo[run] = v
        end
        return v
    end
end

--- The runs that pass `f`, in the order given: Runs.Filter with every key given, so none of the Runs
--- tab's defaults (the current character, incomplete runs in) can leak in, after the lost runs are
--- taken out (Runs.Filter keeps them while incomplete runs are in).
--- @param f table|nil  DEFAULTS' shape; a missing key is its default
--- @param now number|nil  the epoch the date range is measured from (time())
function InsightsData.Filter(runs, f, now)
    f = merged(f)
    local kept = {}
    for _, run in ipairs(runs or {}) do
        if type(run) == "table" and run.status ~= "lost" then kept[#kept + 1] = run end
    end
    return Runs.Filter(kept, {
        char = f.char, spec = f.spec, category = f.category, length = f.length, date = f.date,
        hideFlagged = f.cleanOnly, includeIncomplete = f.includeIncomplete, onlyBest = false,
    }, now)
end

-- ── the faceted options ─────────────────────────────────────────────────────────────────────────

-- Whether `run` passes what no dropdown sets: resolved and not lost, and the two checks.
local function passesChecks(run, f, flagged)
    if type(run) ~= "table" or run.status == "lost" or not Runs.RESOLVED[run.status] then return false end
    if not f.includeIncomplete and run.status ~= "complete" then return false end
    return not (f.cleanOnly and flagged(run))
end

-- The one dropdown `run` fails (its slot: a FACETS index or DATE), 0 when it fails none, false when
-- it fails two or more (then it counts toward no dropdown's options).
local function missedSlot(run, f, since)
    local missed = 0
    for i, facet in ipairs(FACETS) do
        local want = f[facet.key]
        if want ~= "all" and facet.of(run) ~= want then
            if missed ~= 0 then return false end
            missed = i
        end
    end
    if since and (run.date or 0) < since then
        if missed ~= 0 then return false end
        missed = DATE
    end
    return missed
end

local function find(list, value)
    for _, o in ipairs(list) do
        if o.value == value then return o end
    end
    return nil
end

-- Each option's count among `pool`, written into its label: "Beast Mastery (28)".
local function countInto(list, pool, facet)
    local n = {}
    for _, run in ipairs(pool) do
        local v = facet.of(run)
        if v ~= nil then n[v] = (n[v] or 0) + 1 end
    end
    for _, o in ipairs(list) do
        o.count = n[o.value] or 0
        o.label = L["%s (%d)"]:format(o.label, o.count)
    end
end

-- One value facet's options: the values in `pool`, the current selection kept (at 0) when it is not
-- among them, each with its count, led by the "all" head with the pool's size.
local function facetOptions(facet, pool, runs, want)
    local list = Runs.OptionLists(pool, facet.key)
    if want ~= "all" and not find(list, want) then
        list[#list + 1] = find(Runs.OptionLists(runs, facet.key), want) or { value = want, label = tostring(want) }
    end
    countInto(list, pool, facet)
    Runs.WithAll(list, facet.head)
    list[1].count = #pool
    list[1].label = L["%s (%d)"]:format(facet.head, #pool)
    return list
end

-- The date ranges: all four, always (they nest, so a 0-count range is shown, never hidden).
local function dateOptions(pool, now)
    local list = Runs.DateOptions()
    for _, o in ipairs(list) do
        local since, n = Runs.Since(o.value, now), 0
        for _, run in ipairs(pool) do
            if since == nil or (run.date or 0) >= since then n = n + 1 end
        end
        o.count = n
        o.label = L["%s (%d)"]:format(o.label, n)
    end
    return list
end

--- Each dropdown's options under `f`, faceted: a dropdown lists the values present in the runs that
--- pass every OTHER filter, each with its count ({ value, label, count, color? }), led by its "all"
--- head (no "current" head). The current selection is always offered, at 0 when nothing matches it.
--- One pass: each run is checked against every filter once, and counts toward a dropdown when it
--- fails that dropdown's filter alone (or none).
--- @param runs table  run records (any status; lost ones never count)
--- @param f table|nil  DEFAULTS' shape
--- @param now number|nil  the epoch the date ranges are measured from
--- @return table options  { char, spec, category, length, date }
function InsightsData.Options(runs, f, now)
    f = merged(f)
    runs = runs or {}
    local flagged, since = flaggedMemo(), Runs.Since(f.date, now)
    local pools = {}
    for i = 1, DATE do pools[i] = {} end
    for _, run in ipairs(runs) do
        local missed = passesChecks(run, f, flagged) and missedSlot(run, f, since)
        if missed == 0 then
            for i = 1, DATE do pools[i][#pools[i] + 1] = run end
        elseif missed then
            pools[missed][#pools[missed] + 1] = run
        end
    end
    local out = { date = dateOptions(pools[DATE], now) }
    for i, facet in ipairs(FACETS) do out[facet.key] = facetOptions(facet, pools[i], runs, f[facet.key]) end
    return out
end

local function countOf(list, value)
    local o = find(list, value)
    return o and o.count or 0
end

--- `f` with every selection that matches no run set to "all", and the options under the result. The
--- dropdown the player just changed (`keep`) is never reset. The others are checked in bar order, and
--- the options are recomputed after each reset, so one reset cannot take a selection that the reset
--- before it would have saved. `f` itself is not written (a fallback never touches a saved view).
--- @param keep string|nil  the key of the dropdown just changed
--- @return table f, table options
function InsightsData.Normalize(runs, f, now, keep)
    f = merged(f)
    local options = InsightsData.Options(runs, f, now)
    for _, key in ipairs(InsightsData.ORDER) do
        if key ~= keep and f[key] ~= "all" and countOf(options[key], f[key]) == 0 then
            f[key] = "all"
            options = InsightsData.Options(runs, f, now)
        end
    end
    return f, options
end

-- ── the stats pass: helpers ─────────────────────────────────────────────────────────────────────

local function midnight(t)
    local d = date("*t", t)
    return time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
end

-- The next local midnight (time() normalizes day + 1, and a daylight saving change with it).
local function nextDay(t)
    local d = date("*t", t)
    return time({ year = d.year, month = d.month, day = d.day + 1, hour = 0, min = 0, sec = 0 })
end

local function size(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- The seconds a run raced: its length when complete, its time in combat otherwise.
local function runSeconds(run)
    local length = run.race and run.race.length
    length = type(length) == "number" and length or 0
    if run.status == "complete" then return length end
    local ended = run.result and run.result.endedAt
    return type(ended) == "number" and ended or length
end

local function tailBucket(tail)
    for i, edge in ipairs(TAIL_EDGES) do
        if tail < edge then return i end
    end
    return #TAIL_EDGES + 1
end

local function tally(map, casts)
    for _, cast in ipairs(casts) do
        local id = type(cast.spellID) == "number" and cast.spellID or UNKNOWN
        map[id] = (map[id] or 0) + 1
    end
end

-- What every reducer reads about one run, worked out once.
local function factsOf(run, flagged)
    local dps = type(run.result) == "table" and run.result.dps or nil
    local complete = run.status == "complete" and type(dps) == "number"
    return { complete = complete, dps = complete and dps or nil, key = NS.Bests.Key(run), flagged = flagged(run) }
end

local function charEntry(acc, run)
    local key = Runs.CharKey(run)
    local entry = acc.chars[key]
    if not entry then
        local char = run.char or {}
        entry = { key = key, name = tostring(char.name or "?"), class = char.class, n = 0, byCategory = {} }
        acc.chars[key] = entry
        acc.charList[#acc.charList + 1] = entry
    end
    return entry
end

-- ── the stats pass: reducers (one call per run each) ────────────────────────────────────────────

local REDUCERS = {
    -- The headline counts: the runs, the time raced, the clean ones, the dates and the days.
    function(acc, run, facts)
        acc.n = acc.n + 1
        acc.secs = acc.secs + runSeconds(run)
        if not facts.flagged then acc.clean = acc.clean + 1 end
        local d = run.date
        if type(d) ~= "number" then return end
        if not acc.first or d < acc.first then acc.first = d end
        if not acc.last or d > acc.last then acc.last = d end
        local day = midnight(d)
        acc.days[day] = (acc.days[day] or 0) + 1
    end,
    -- Who raced: each character with its target categories, and the specs seen.
    function(acc, run)
        local entry = charEntry(acc, run)
        local category = run.target and run.target.category or "other"
        entry.n = entry.n + 1
        entry.byCategory[category] = (entry.byCategory[category] or 0) + 1
        acc.categories[category] = true
        local spec = run.char and run.char.specID
        if spec ~= nil then acc.specs[spec] = true end
    end,
    -- The race lengths.
    function(acc, run)
        local length = run.race and run.race.length
        if type(length) == "number" then acc.lengths[length] = (acc.lengths[length] or 0) + 1 end
    end,
    -- The late casts by spell, split by the ignore list.
    function(acc, run)
        local counted, ignored = NS.Scoring.SplitLate(run, acc.set)
        tally(acc.lateCounted, counted)
        tally(acc.lateIgnored, ignored)
    end,
    -- The damage tail after the buzzer.
    function(acc, run)
        local tail = type(run.result) == "table" and run.result.tail or nil
        if type(tail) ~= "number" then return end
        local i = tailBucket(tail)
        acc.tail[i] = acc.tail[i] + 1
    end,
    -- The complete runs: every DPS figure reads these.
    function(acc, run, facts)
        if facts.complete then acc.complete[#acc.complete + 1] = { run = run, dps = facts.dps, key = facts.key } end
    end,
}

-- ── the stats pass: finalizers (once, in order) ─────────────────────────────────────────────────

-- Date order, then id: the order bests are set in (Bests' own).
local function earlier(a, b)
    local ta, tb = a.run.date or 0, b.run.date or 0
    if ta ~= tb then return ta < tb end
    return tostring(a.run.id) < tostring(b.run.id)
end

local function newBoard(e)
    local run = e.run
    local char = run.char or {}
    return { key = e.key, specID = char.specID, class = char.class, spec = char.spec,
             category = run.target and run.target.category or "other", length = run.race and run.race.length,
             n = 0, sum = 0, first = run, pct = {} }
end

-- One complete run, in date order, onto its board: a new best when it beats the board's best so far.
local function onBoard(out, e)
    local board = out.boards[e.key]
    if not board then
        board = newBoard(e)
        out.boards[e.key] = board
    elseif e.dps > board.bestDps then
        local gain = board.bestDps > 0 and (e.dps / board.bestDps - 1) * 100 or nil
        out.newBests[#out.newBests + 1] = { run = e.run, dps = e.dps, key = e.key, prev = board.best,
                                            prevDps = board.bestDps, gain = gain }
    end
    if not board.best or e.dps > board.bestDps then board.best, board.bestDps = e.run, e.dps end
    board.n, board.sum = board.n + 1, board.sum + e.dps
    local best = out.totals.best
    if not best or e.dps > best.dps then out.totals.best = { run = e.run, dps = e.dps, key = e.key } end
end

-- Each run's % of its board's best, and each board's average, spread (CV) and average %.
local function boardFigures(acc, out)
    local spread, pctSum = {}, {}
    for _, board in pairs(out.boards) do board.avg = board.sum / board.n end
    for _, e in ipairs(acc.complete) do
        local board = out.boards[e.key]
        e.pct = board.bestDps > 0 and e.dps / board.bestDps or 0
        board.pct[e.run.id] = e.pct
        spread[board] = (spread[board] or 0) + (e.dps - board.avg) ^ 2
        pctSum[board] = (pctSum[board] or 0) + e.pct
    end
    for _, board in pairs(out.boards) do
        board.cv = board.avg > 0 and math.sqrt(spread[board] / board.n) / board.avg or nil
        board.avgPct = pctSum[board] / board.n
    end
end

local CATEGORY_RANK = {}
for i, key in ipairs(NS.Dummies.CATEGORIES) do CATEGORY_RANK[key] = i end

-- Section B's pair: more runs first, then the catalog's category order, then the shorter length.
local function morePopular(a, b)
    if a.n ~= b.n then return a.n > b.n end
    local ra, rb = CATEGORY_RANK[a.category] or 99, CATEGORY_RANK[b.category] or 99
    if ra ~= rb then return ra < rb end
    return (a.length or 0) < (b.length or 0)
end

local function byBest(a, b)
    if a.best ~= b.best then return a.best > b.best end
    return tostring(a.specID) < tostring(b.specID)
end

-- B: the specs side by side on the most-raced (category, length) pair; with a Target and a Length
-- filter that is the filter's own pair.
local function specCompare(out)
    local byPair, chosen = {}, nil
    for _, board in pairs(out.boards) do
        local key = board.category .. "|" .. tostring(board.length)
        local p = byPair[key]
        if not p then
            p = { category = board.category, length = board.length, n = 0, rows = {} }
            byPair[key] = p
        end
        p.n = p.n + board.n
        p.rows[#p.rows + 1] = { specID = board.specID, class = board.class, spec = board.spec, run = board.best,
                                best = board.bestDps, avg = board.avg, n = board.n }
    end
    for _, p in pairs(byPair) do
        if not chosen or morePopular(p, chosen) then chosen = p end
    end
    if chosen then table.sort(chosen.rows, byBest) end
    out.specCompare = chosen
end

-- C: the boards with enough runs to speak of a spread, the most consistent first.
local function consistency(out)
    for _, board in pairs(out.boards) do
        if board.n >= CONSISTENT_MIN then out.consistency[#out.consistency + 1] = board end
    end
    table.sort(out.consistency, function(a, b)
        if a.avgPct ~= b.avgPct then return a.avgPct > b.avgPct end
        return a.key < b.key
    end)
end

-- The cards that read the boards: the average % of board best, and the raw average on one board.
local function boardCards(acc, out)
    local t, n, pct, dps = out.totals, #acc.complete, 0, 0
    if n == 0 then return end
    for _, e in ipairs(acc.complete) do pct, dps = pct + e.pct, dps + e.dps end
    t.avgPct = pct / n
    local key = next(out.boards)
    if next(out.boards, key) == nil then
        t.oneBoard, t.avgDps = key, dps / n
    end
end

local function byCount(a, b)
    if a.count ~= b.count then return a.count > b.count end
    if (a.id == nil) ~= (b.id == nil) then return a.id ~= nil end
    return (a.id or 0) < (b.id or 0)
end

local function lateList(map)
    local list = {}
    for id, count in pairs(map) do
        local unknown = id == UNKNOWN
        list[#list + 1] = { id = (not unknown) and id or nil, unknown = unknown or nil, count = count }
    end
    table.sort(list, byCount)
    return list
end

-- One run's damage per spell ID (player and pet rows of one ID summed) and its total.
local function runSpells(run)
    local by, total = {}, 0
    for _, s in ipairs(type(run.spells) == "table" and run.spells or {}) do
        local id, dmg = s.id, s.dmg
        if type(id) == "number" and type(dmg) == "number" and dmg > 0 then
            by[id] = (by[id] or 0) + dmg
            total = total + dmg
        end
    end
    return by, total
end

-- H: the top spells by damage share, when the runs are all one spec. The share is the mean of each
-- run's own share, so the long cleave runs do not outweigh the short ones.
local function spellShare(acc, out)
    local specID = next(acc.specs)
    if specID == nil or next(acc.specs, specID) ~= nil then return end
    local sums, n, rows = {}, 0, {}
    for _, e in ipairs(acc.complete) do
        local by, total = runSpells(e.run)
        if total > 0 then
            n = n + 1
            for id, dmg in pairs(by) do sums[id] = (sums[id] or 0) + dmg / total end
        end
    end
    for id, sum in pairs(sums) do rows[#rows + 1] = { id = id, share = sum / n } end
    table.sort(rows, function(a, b)
        if a.share ~= b.share then return a.share > b.share end
        return a.id < b.id
    end)
    for i = #rows, SPELL_TOP + 1, -1 do rows[i] = nil end
    out.spellShare = { specID = specID, n = n, rows = rows }
end

-- I: one entry per local day from the first run's to the last's, the days with no run included.
local function byDay(acc, out)
    if not acc.first then return end
    local day, last = midnight(acc.first), midnight(acc.last)
    if (last - day) / 86400 > MAX_DAYS then day = midnight(last - MAX_DAYS * 86400) end
    while day <= last do
        out.byDay[#out.byDay + 1] = { day = day, n = acc.days[day] or 0 }
        day = nextDay(day)
    end
end

local FINALIZERS = {
    -- The boards in date order, the new bests (K), the peak, then the board figures and A.
    function(acc, out)
        table.sort(acc.complete, earlier)
        for _, e in ipairs(acc.complete) do onBoard(out, e) end
        boardFigures(acc, out)
        out.progression = acc.complete
    end,
    function(_, out) specCompare(out) end,
    function(_, out) consistency(out) end,
    boardCards,
    -- The headline cards.
    function(acc, out)
        local t = out.totals
        t.runs, t.timeRaced, t.clean = acc.n, acc.secs, acc.clean
        t.chars, t.specs, t.activeDays = #acc.charList, size(acc.specs), size(acc.days)
        t.first, t.last, t.newBests = acc.first, acc.last, #out.newBests
    end,
    -- D and E: the characters, most runs first; E's categories in the catalog's order.
    function(acc, out)
        table.sort(acc.charList, function(a, b)
            if a.n ~= b.n then return a.n > b.n end
            return a.key < b.key
        end)
        out.byChar, out.byCharTarget.rows = acc.charList, acc.charList
        for _, key in ipairs(NS.Dummies.CATEGORIES) do
            if acc.categories[key] then out.byCharTarget.categories[#out.byCharTarget.categories + 1] = key end
        end
    end,
    -- F: the race lengths, shortest first.
    function(acc, out)
        for length, n in pairs(acc.lengths) do out.byLength[#out.byLength + 1] = { length = length, n = n } end
        table.sort(out.byLength, function(a, b) return a.length < b.length end)
    end,
    -- G: the late casts by spell, the counted and the ignored apart.
    function(acc, out)
        out.lateBySpell = { counted = lateList(acc.lateCounted), ignored = lateList(acc.lateIgnored) }
    end,
    spellShare,
    byDay,
    -- J: the damage tail's buckets; the last is open-ended.
    function(acc, out)
        for i, n in ipairs(acc.tail) do
            out.tail[i] = { lo = TAIL_EDGES[i - 1] or 0, hi = TAIL_EDGES[i], n = n }
        end
    end,
}

-- ── the stats pass ──────────────────────────────────────────────────────────────────────────────

local function newAcc()
    local tail = {}
    for i = 1, #TAIL_EDGES + 1 do tail[i] = 0 end
    return {
        n = 0, secs = 0, clean = 0, chars = {}, charList = {}, categories = {}, specs = {}, days = {},
        lengths = {}, lateCounted = {}, lateIgnored = {}, tail = tail, complete = {},
        set = NS.LateIgnore and NS.LateIgnore.Set() or nil,
    }
end

--- Everything the cards and the sections show, in one pass over `runs` (already filtered:
--- InsightsData.Filter).
--- @return table stats  { totals (the cards: runs, timeRaced, best { run, dps, key }, avgPct, avgDps
---   and oneBoard on one board, clean, newBests, chars, specs, first, last, activeDays), boards
---   ([Bests.Key] = { best, bestDps, avg, cv, n, first, avgPct, pct = { [run id] = share of best } }),
---   progression (A: { run, dps, key, pct } in date order), specCompare (B: { category, length, n,
---   rows } or nil), consistency (C: boards of 3 runs or more), byChar (D), byCharTarget (E: { rows,
---   categories }), byLength (F), lateBySpell (G: { counted, ignored }, each { id, unknown?, count }),
---   spellShare (H: { specID, n, rows { id, share } } when one spec, else nil), byDay (I: { day, n }),
---   tail (J: { lo, hi?, n }), newBests (K: { run, dps, key, prev, prevDps, gain } in date order) }
function InsightsData.Compute(runs)
    local flagged, acc = flaggedMemo(), newAcc()
    for _, run in ipairs(runs or {}) do
        if type(run) == "table" then
            local facts = factsOf(run, flagged)
            for i = 1, #REDUCERS do REDUCERS[i](acc, run, facts) end
        end
    end
    local out = {
        totals = { runs = 0, timeRaced = 0, clean = 0, newBests = 0, chars = 0, specs = 0, activeDays = 0 },
        boards = {}, progression = {}, consistency = {}, byChar = {}, byCharTarget = { rows = {}, categories = {} },
        byLength = {}, lateBySpell = { counted = {}, ignored = {} }, byDay = {}, tail = {}, newBests = {},
    }
    for i = 1, #FINALIZERS do FINALIZERS[i](acc, out) end
    return out
end
