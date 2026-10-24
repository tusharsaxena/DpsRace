local _, NS = ...
-- modules/Results_Compare.lua — the run detail's compare (#7): a stored run beside the best on its
-- board, or beside a run the player picked from a Runs row's right-click menu (*Compare With This
-- Run*). A toggle under the score turns it on; on, the detail draws a second figure column (damage,
-- DPS, the % difference) and the breakdown matched spell by spell, each side's damage and share
-- and the difference, in place of the plain breakdown. modules/Results_Detail.lua builds and places
-- these parts through the functions here; the shell (modules/Results.lua) owns the pick.
--
-- THIS FILE, SO FAR, is the pure half: the parts land with the toggle (plan step M1.2).
--
-- PLAIN NUMBERS ONLY. Both runs are stored records (every figure went through NS.Secrets on its way
-- in), so they may be divided, compared and sorted. Spells, Kpis, Default and Target are pure over
-- the store, so the suites check them without drawing.
--
-- THE OTHER RUN. By default the best on the run's board (NS.Bests, the all-runs board: spec x
-- target type x race length); when the run IS that best, the runner-up on the board; with neither,
-- the toggle is disabled. A picked run wins over both while it is still stored, on any board (a
-- note says when the boards differ). The pick and the toggle are session-only view state, never
-- stored. M3's loadout diff reads the same target through the pane's CompareTarget().

local Compare = {}
NS.ResultsCompare = Compare

local Detail = NS.ResultsDetail
local L = NS.L
local Tbl = NS.ResultsTable

Compare.VALUE_W = 80        -- each figure column, in the score table and the compared breakdown
Compare.ROW_H = 15          -- one line of the score table
Compare.BAR_H = 22          -- the toggle's line
Compare.CLEAR_W = 78        -- the Clear Pick button
local DASH = "\226\128\148"
local MUTED = "|cff9e9ead%s|r"   -- the caption gray inside a figure (the Time column's tail)

-- ── pure: the comparison ────────────────────────────────────────────────────────────────────────

local function num(v) return type(v) == "number" and v or nil end

local function resultOf(run)
    local r = type(run) == "table" and run.result
    return type(r) == "table" and r or {}
end

-- A run's damage per spell id (a duplicated id adds up), skipping an entry with no id.
local function byID(run)
    local out = {}
    local spells = type(run) == "table" and type(run.spells) == "table" and run.spells or {}
    for _, s in ipairs(spells) do
        if type(s) == "table" and s.id ~= nil then out[s.id] = (out[s.id] or 0) + (num(s.dmg) or 0) end
    end
    return out
end

local function share(dmg, total)
    if dmg and total and total > 0 then return dmg / total * 100 end
    return nil
end

local function idBefore(a, b)
    if type(a) == "number" and type(b) == "number" then return a < b end
    return tostring(a) < tostring(b)
end

-- The run's damage first (a spell it never cast last), then the other's, then the id.
local function rowBefore(a, b)
    local da, db = a.dmgA or -1, b.dmgA or -1
    if da ~= db then return da > db end
    local oa, ob = a.dmgB or -1, b.dmgB or -1
    if oa ~= ob then return oa > ob end
    return idBefore(a.id, b.id)
end

--- The two runs' spells matched by id: { id, dmgA, dmgB, shareA, shareB, delta }, sorted by the run's
--- damage, then the other's. A spell on one side only has nil damage and share on the other; a
--- share is nil when its run's damage total is missing or zero. `delta` is dmgA - dmgB, a missing
--- side counting 0.
--- @param run table  the run shown (side A)
--- @param other table|nil  the run it is compared with (side B)
--- @return table rows
function Compare.Spells(run, other)
    local a, b = byID(run), byID(other)
    local ta, tb = num(resultOf(run).damage), num(resultOf(other).damage)
    local rows = {}
    local function add(id)
        local da, db = a[id], b[id]
        rows[#rows + 1] = { id = id, dmgA = da, dmgB = db, shareA = share(da, ta), shareB = share(db, tb),
                            delta = (da or 0) - (db or 0) }
    end
    for id in pairs(a) do add(id) end
    for id in pairs(b) do if a[id] == nil then add(id) end end
    table.sort(rows, rowBefore)
    return rows
end
Detail.CompareSpells = Compare.Spells

--- `a` against `b` as a percentage of `b`; nil when either is missing or `b` is not above 0.
function Compare.Pct(a, b)
    a, b = num(a), num(b)
    if not (a and b) or b <= 0 then return nil end
    return (a / b - 1) * 100
end

--- The score table's figures: each side's damage and DPS, and the % difference of each.
--- @return table { damageA, damageB, damagePct, dpsA, dpsB, dpsPct }
function Compare.Kpis(run, other)
    local ra, rb = resultOf(run), resultOf(other)
    return { damageA = num(ra.damage), damageB = num(rb.damage), damagePct = Compare.Pct(ra.damage, rb.damage),
             dpsA = num(ra.dps), dpsB = num(rb.dps), dpsPct = Compare.Pct(ra.dps, rb.dps) }
end

--- Whether a run can take part in a compare: a stored record with a result (a lost run has none).
function Compare.Usable(run)
    return type(run) == "table" and run.status ~= "lost" and type(run.result) == "table"
end

--- The default other run: the best on `run`'s board, or the runner-up on it when `run` holds the
--- best; nil with neither (the toggle is then disabled).
--- @param run table
--- @param runs table|nil  defaults to the store (the cached board)
--- @return table|nil other, string|nil kind  "best" | "runnerUp"
function Compare.Default(run, runs)
    if not Compare.Usable(run) then return nil end
    local Bests = NS.Bests
    local key = Bests.Key(run)
    local best = (runs and Bests.Compute(runs) or Bests.Board())[key]
    if not best then return nil end
    if best.id ~= run.id then return best, "best" end
    local rest = {}
    for _, r in ipairs(runs or NS.Recorder.All()) do
        if r.id ~= run.id then rest[#rest + 1] = r end
    end
    local second = Bests.Compute(rest)[key]
    if second then return second, "runnerUp" end
    return nil
end

--- The run `run` is compared with: the picked run while it is stored, usable and not `run` itself,
--- else the default.
--- @param run table
--- @param pickID string|nil
--- @return table|nil other, string|nil kind  "picked" | "best" | "runnerUp"
function Compare.Target(run, pickID)
    if not Compare.Usable(run) then return nil end
    local picked = pickID ~= nil and pickID ~= run.id and NS.Recorder.Get(pickID) or nil
    if Compare.Usable(picked) then return picked, "picked" end
    return Compare.Default(run)
end

--- Whether two runs sit on the same board (spec, target type, race length).
function Compare.SameBoard(a, b)
    return NS.Bests.Key(a) == NS.Bests.Key(b)
end

--- A run's short label: its date, as the row menu's title shows it.
function Compare.ShortLabel(run)
    return Tbl.Date(type(run) == "table" and run.date, "%d %b %H:%M")
end

--- The toggle's label for `kind`.
function Compare.ToggleLabel(kind, other)
    if kind == "picked" then return L["Compare vs %s"]:format(Compare.ShortLabel(other)) end
    if kind == "runnerUp" then return L["Compare vs runner-up"] end
    return L["Compare vs best"]
end

--- The other column's heading for `kind`.
function Compare.OtherLabel(kind)
    if kind == "picked" then return L["Picked"] end
    if kind == "runnerUp" then return L["Runner-up"] end
    return L["Best"]
end

-- ── text ────────────────────────────────────────────────────────────────────────────────────────

--- A spell figure: its damage, then its share in the caption gray; a dash for a side without it.
function Compare.SpellFigure(dmg, pct)
    if not dmg then return DASH end
    if not pct then return NS.Format.Number(dmg) end
    return NS.Format.Number(dmg) .. " " .. MUTED:format(NS.Format.Pct(pct))
end

--- The difference in damage, signed.
function Compare.DeltaText(delta)
    if type(delta) ~= "number" or delta == 0 then return "0" end
    return (delta > 0 and "+" or "-") .. NS.Format.Number(math.abs(delta))
end
