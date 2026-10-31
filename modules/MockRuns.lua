local _, NS = ...
-- modules/MockRuns.lua — the sample data test mode and the sim draw (B5, the owner's call, 2026-10-25):
-- a made-up run history for the Results window, and a made-up race for the HUD (modules/SampleRace.lua
-- plays it through the race's own views and messages).
--
-- MADE FRESH, KEPT IN MEMORY, NEVER STORED. Every table here is built on the call, from the player's
-- own name, spec, place and loadout (read out of combat: test mode and the sim refuse to start in
-- it) plus two made-up characters. Nothing is written to NS.db: the Results window reads the history
-- through modules/Results_Source.lua's sample seam.
--
-- ONE FIGHT, ONE PLAN. A sample run is built the way a real one comes about: a PLAN of what happened
-- in the fight (its casts and every damage hit, from the class's rotation in modules/MockRotations.lua,
-- with a generator seeded from the run's id), and everything a window draws is read from that plan:
-- run.spells, run.casts, run.usage, the chart's buckets and the HUD's live figures. So each run has its
-- own spell mix (a compare has rows of different size and sign, and a spell on one side only), the
-- rows move through a race, and the curve a race draws is the curve its card keeps. The seed makes
-- it repeatable: the same run id always plans the same fight. Never math.random here.

local MockRuns = {}
NS.MockRuns = MockRuns

local L = NS.L

-- The HUD's sample race: its length, and the tail and combat end (seconds after its buzzer) a scenario
-- that names none takes.
MockRuns.LENGTH = 30
MockRuns.TAIL = 3.1
MockRuns.COMBAT_END = 4.2
-- The best a board-less sample races at (the first race on its board has nothing to beat).
MockRuns.DPS = 147600

-- How a plan varies a rotation, run to run: a spell's luck over the fight (either way), the drift of
-- its first cast (s) and of its cadence (a fraction), the chance a cast is skipped, the crit chance
-- (a crit doubles the hit), and a direct hit's flight time (s).
local LUCK, DRIFT_FROM, DRIFT_EVERY, SKIP, CRIT, TRAVEL = 0.16, 0.25, 0.06, 0.05, 0.25, 0.3
-- No hit lands before the clock: the first damage is what starts it.
local FIRST_HIT = 0.05
-- The most damage-over-time ticks a run's tail lands, their spacing target (s), and their size against
-- the spell's own hit (the tail is the end of a fight, not a second one).
local TAIL_HITS, TAIL_GAP, TAIL_SIZE = 8, 1.5, 0.4

local ROTATIONS = NS.MockRotations

-- What a sample run used (#13): its first on-use gear item at GEAR_AT and every GEAR_EVERY seconds
-- after, its first potion at POTION_AT, and a flask's buff and Well Fed on at the start. A player with
-- no consumable in the bags gets a Healthstone, used once with no cast (a bag count drop).
MockRuns.GEAR_AT, MockRuns.GEAR_EVERY, MockRuns.POTION_AT = 0.4, 120, 1.2
local HEALTHSTONE = { itemID = 5512, spellID = 6262 }
-- The sample base cooldowns of an on-use item's and a potion's spells (ms).
local GEAR_CD, POTION_CD = 120000, 300000

local function itemLink(id, name)
    return ("|Hitem:%d::::::::80:::::|h[%s]|h"):format(id, name)
end

-- The two made-up characters beside the player, on the player's realm: who they are, what they had
-- at the arm (their own trinket and bags, never the player's), and what they wore.
local ALTS = {
    ret = {
        char = { name = "Sampleblade", class = "PALADIN", specID = 70, spec = "Retribution", ilvl = 312.4 },
        snap = { gear = { { slot = 13, itemID = 212454, spellID = 443124 } },
                 bags = { [212265] = { count = 12, subclass = 1, spellID = 431932 },
                          [212283] = { count = 3, subclass = 3, spellID = 432021 } } },
        gear = { [1] = itemLink(16955, "Sample Crown"), [5] = itemLink(16958, "Sample Breastplate"),
                 [7] = itemLink(16954, "Sample Legplates"), [13] = itemLink(212454, "Sample Trinket"),
                 [16] = itemLink(17182, "Sample Greatsword") },
        talents = { specID = 70, configID = 1, name = "Sample build" },
        stats = { v = 1, primaryStat = 1, primary = 41800, stamina = 182000, armor = 44100,
                  critRating = 5120, crit = 24.31, hasteRating = 6480, haste = 21.60, masteryRating = 4380,
                  mastery = 42.15, versRating = 2310, vers = 7.11 },
    },
    fire = {
        char = { name = "Mockflame", class = "MAGE", specID = 63, spec = "Fire", ilvl = 309.8 },
        snap = { gear = { { slot = 14, itemID = 219313, spellID = 443609 } },
                 bags = { [212265] = { count = 7, subclass = 1, spellID = 431932 } } },
        gear = { [1] = itemLink(16914, "Sample Hood"), [5] = itemLink(16916, "Sample Robe"),
                 [7] = itemLink(16915, "Sample Trousers"), [14] = itemLink(219313, "Sample Idol"),
                 [16] = itemLink(19356, "Sample Staff") },
        talents = { specID = 63, configID = 2, name = "Sample build" },
        stats = { v = 1, primaryStat = 4, primary = 40600, stamina = 171000, armor = 15600,
                  critRating = 6420, crit = 31.05, hasteRating = 5960, haste = 19.87, masteryRating = 3120,
                  mastery = 27.40, versRating = 2840, vers = 8.74 },
    },
}

-- The trinket a loadout b run swapped in: one slot changed, never emptied.
local SWAP_LINK = itemLink(219314, "Sample Swapped Trinket")

-- The catalog's dummy per target type (defaults/Dummies.lua). The catalog has no single-target row
-- (a row needs a measurement), so that one stays a generic Training Dummy.
local TARGETS = {
    single = {}, cleave = { npcID = 243208 }, dungeoneer = { npcID = 243167 },
    boss = { npcID = 243205 }, pvp = { npcID = 243211 },
}

-- The history: every target type, all five preset lengths and every Status the Runs list draws (Max,
-- Spec best, Complete, Flagged, Incomplete, Died, Lost), with notes and charts on some. It spans five
-- days and several boards, so every Insights section (#12) has something to draw: the Flagged run
-- keeps its counted late casts (a `late` row with no spellID is the rotation's own spell), and a run of
-- its own carries a Hearthstone cast late, which the late-cast ignore list's defaults leave uncounted
-- (#8), so Late Casts shows an ignored spell.
-- `ago` is hours before now; `tail` and `combatEnd` are seconds after the buzzer; `loadout` "b" is
-- the player's set with one slot changed and the alternate talent (`swap`); `noMajor` missed its long
-- cooldown; `dry` drank no potion. Every run carries its casts, usage, loadout and stats (#13, #14,
-- #17) but one: `old` is a format-2 run, raced before they were recorded.
local HISTORY = {
    { who = "me", cat = "single", len = 30, dps = 151200, ago = 26, tail = 3.1, combatEnd = 4.2, chart = true,
      note = "Sample note: opener with every cooldown" },
    { who = "me", cat = "single", len = 30, dps = 144900, ago = 5, loadout = "b", tail = 2.4, combatEnd = 5.8 },
    { who = "me", cat = "single", len = 30, dps = 149800, ago = 8, tail = 6.3, combatEnd = 7.1, noMajor = true,
      late = { { t = 1.6 }, { t = 2.3 } } },
    { who = "me", cat = "single", len = 60, dps = 139400, ago = 30, tail = 1.2, combatEnd = 3.4, chart = true },
    { who = "me", cat = "cleave", len = 120, dps = 212300, ago = 50, tail = 11.6, combatEnd = 12.9, dry = true,
      note = "Sample note: five dummies in reach" },
    { who = "me", cat = "boss", len = 180, dps = 128700, ago = 72, status = "incomplete", endAt = 95 },
    { who = "me", cat = "dungeoneer", len = 300, dps = 135100, ago = 96, tail = 7.4, combatEnd = 8.2, chart = true },
    { who = "me", cat = "single", len = 60, dps = 120500, ago = 3, status = "incomplete", endAt = 41, died = true },
    { who = "me", cat = "single", len = 30, ago = 2, status = "lost" },
    { who = "me", cat = "pvp", len = 120, dps = 118200, ago = 120, restartedAt = 47.5, tail = 49.2, combatEnd = 51.0,
      old = true },
    { who = "ret", cat = "single", len = 30, dps = 163400, ago = 12, tail = 4.6, combatEnd = 6.2,
      note = "Sample note: another character's best" },
    { who = "ret", cat = "cleave", len = 120, dps = 198600, ago = 60, tail = 16.8, combatEnd = 18.1 },
    { who = "ret", cat = "boss", len = 180, dps = 141000, ago = 84, tail = 2.9, combatEnd = 4.4, shared = true, dry = true },
    { who = "fire", cat = "single", len = 60, dps = 146100, ago = 20, tail = 8.7, combatEnd = 9.6, chart = true },
    { who = "fire", cat = "dungeoneer", len = 300, dps = 127300, ago = 110, status = "incomplete", endAt = 212 },
    { who = "fire", cat = "single", len = 30, dps = 155800, ago = 40, tail = 5.2, combatEnd = 5.9, noMajor = true },
    { who = "me", cat = "cleave", len = 120, dps = 205100, ago = 74, tail = 3.8, combatEnd = 6.5,
      late = { { t = 2.1, spellID = 8690 } } },
}
MockRuns.HISTORY = HISTORY

local HOUR = 3600

local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

--- The player as a run records them, with a stand-in for whatever the client could not say.
--- @return table char
function MockRuns.Player()
    local c = copy(NS.Recorder.SnapshotPlayer())
    c.name = c.name or L["You"]
    c.class = c.class or "WARLOCK"
    c.ilvl = c.ilvl or 310.0
    return c
end

local function charFor(who, me)
    if who == "me" then return copy(me) end
    local c = copy(ALTS[who].char)
    c.realm = me.realm
    return c
end

--- A target of `category` as a run records it.
function MockRuns.Target(category)
    local spec = TARGETS[category] or TARGETS.single
    local d = spec.npcID and NS.Dummies.BuiltIn(spec.npcID)
    return { npcID = spec.npcID, name = d and d.name or L["Training Dummy"], category = category }
end

-- ── the plan: one fight ─────────────────────────────────────────────────────────────────────────

-- A repeatable generator for `id` (Park-Miller): 0 <= r() < 1, the same sequence for the same id.
local function seeded(id)
    local MOD = 2147483647
    local state = 7
    for i = 1, #tostring(id) do state = (state * 31 + tostring(id):byte(i)) % MOD end
    state = math.max(1, state)
    local function r()
        state = (state * 16807) % MOD
        return state / MOD
    end
    for _ = 1, 4 do r() end
    return r
end

local function either(r, spread) return (r() * 2 - 1) * spread end

local function rowOn(row, o)
    if row.major and o.noMajor then return false end
    if row.alt then return o.swap == true end
    if row.main then return o.swap ~= true end
    return true
end

local function addHit(plan, at, id, size, r)
    if at > plan.last then return end
    local amount = size * (r() < CRIT and 2 or 1)
    plan.hits[#plan.hits + 1] = { t = round2(math.max(FIRST_HIT, at)), id = id, amount = amount }
end

-- One cast's damage: a direct hit after its flight, or its ticks.
local function castHits(plan, row, t, size, r)
    if row.none then return end
    if not row.ticks then return addHit(plan, t + TRAVEL, row.id, size, r) end
    for i = 1, row.ticks do addHit(plan, t + i * row.gap, row.id, size, r) end
end

-- One rotation row through the fight. Its first cast is never skipped.
local function playRow(plan, row, r)
    local size = (row.hit or 0) * (1 + either(r, LUCK))
    local every = row.every * (1 + either(r, DRIFT_EVERY))
    local t, first = row.from + either(r, DRIFT_FROM), true
    if not row.passive then plan.cooldowns[row.id] = row.cd end
    while t <= plan.secs do
        if first or r() >= SKIP then
            if not row.passive then
                plan.casts[#plan.casts + 1] = { t = round2(t), id = row.id, pet = row.pet == true }
            end
            castHits(plan, row, t, size, r)
        end
        first = false
        t = t + every
    end
end

-- The spell the tail lands: the rotation's first damage-over-time spell, else its first that hits.
local function tailRow(rows, o)
    local fallback
    for _, row in ipairs(rows) do
        if row.hit and rowOn(row, o) then
            if row.ticks then return row end
            fallback = fallback or row
        end
    end
    return fallback
end

-- The damage past the buzzer: ticks up to its tail, the last exactly on it, and a restart's second
-- wave (the gap the restart flag measures) when there is one.
local function tailHits(plan, rows, o, r)
    local tail = plan.tail
    local row = tailRow(rows, o)
    if not (row and tail and tail > 0) then return end
    local fade = o.restartedAt and math.min(3, o.restartedAt / 2) or tail
    local n = math.min(TAIL_HITS, math.ceil(fade / TAIL_GAP))
    local size = row.hit * TAIL_SIZE
    for i = 1, n do addHit(plan, plan.length + fade * i / n, row.id, size, r) end
    if not o.restartedAt then return end
    addHit(plan, plan.length + o.restartedAt, row.id, size, r)
    addHit(plan, plan.length + tail, row.id, size, r)
end

-- The hits scaled to `damage` exactly (the largest takes the rounding), in time order.
local function settle(plan, damage)
    local sum = 0
    for _, h in ipairs(plan.hits) do sum = sum + h.amount end
    if sum <= 0 then return end
    local kept, top = 0, plan.hits[1]
    for _, h in ipairs(plan.hits) do
        h.amount = math.floor(h.amount * damage / sum)
        kept = kept + h.amount
        if h.amount > top.amount then top = h end
    end
    top.amount = top.amount + damage - kept
    table.sort(plan.hits, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return a.id < b.id
    end)
end

-- The late casts: at the length plus each one's offset, a row with no spellID being the rotation's
-- second spell on (the first is often a pre-pull). Past the buzzer, as the race hears them.
local function lateCasts(plan, rows, o)
    local listed = {}
    for _, row in ipairs(rows) do
        if rowOn(row, o) and not row.passive and not row.pet then listed[#listed + 1] = row.id end
    end
    for i, cast in ipairs(o.late or {}) do
        local id = cast.spellID or listed[i + 1] or listed[1]
        plan.casts[#plan.casts + 1] = { t = round2(plan.length + cast.t), id = id, pet = false }
        plan.cooldowns[id] = plan.cooldowns[id] or 0
        plan.late[#plan.late + 1] = { t = cast.t, spellID = id }
    end
end

--- The plan of one fight: what was cast and every damage hit.
--- @param o table  { id, class?, length, secs? (the time in combat, default the length), damage, tail?,
---                 restartedAt?, late?, noMajor?, swap? }
--- @return table plan  { id, length, secs, last, tail, casts, cooldowns, hits, late, rng }
function MockRuns.Plan(o)
    local rows = ROTATIONS[o.class] or ROTATIONS.WARLOCK
    local secs = o.secs or o.length
    local plan = { id = o.id, length = o.length, secs = secs, tail = secs == o.length and o.tail or nil,
                   casts = {}, cooldowns = {}, hits = {}, late = {}, rng = seeded(o.id) }
    plan.last = secs + (plan.tail or 0)
    for _, row in ipairs(rows) do
        if rowOn(row, o) then playRow(plan, row, plan.rng) end
    end
    tailHits(plan, rows, o, plan.rng)
    lateCasts(plan, rows, o)
    settle(plan, o.damage)
    return plan
end

--- What the plan's meter holds `t` seconds into the fight: the running total and each spell's.
--- @return number total, table totals  { [id] = damage }, number|nil lastAt  the last hit by then
function MockRuns.TotalAt(plan, t)
    local total, totals, lastAt = 0, {}, nil
    for _, h in ipairs(plan.hits) do
        if h.t > t then break end
        total = total + h.amount
        totals[h.id] = (totals[h.id] or 0) + h.amount
        lastAt = h.t
    end
    return total, totals, lastAt
end

local function byDamage(a, b)
    if a.dmg ~= b.dmg then return a.dmg > b.dmg end
    return a.id < b.id
end

--- The breakdown a run's meter session reads: every spell of the plan, highest first, its rate over
--- the session's whole seconds (0 on a shared session, whose rate spans both fights).
--- @param duration number  the session's whole seconds
--- @param shared boolean|nil
--- @return table spells  { { id, dmg, dps }, ... }
function MockRuns.Spells(plan, duration, shared)
    local _, totals = MockRuns.TotalAt(plan, math.huge)
    local out = {}
    for id, dmg in pairs(totals) do
        out[#out + 1] = { id = id, dmg = dmg, dps = shared and 0 or dmg / duration }
    end
    table.sort(out, byDamage)
    return out
end

--- The live figures `t` seconds in, in Meter.ReadLive's shape (the rate is the meter's: its total over
--- whole seconds); nil before the first hit, as the meter has no source row yet.
--- @return table|nil live  { total, dps, rung, maxAmount, spells = { { spellID, total, dps }, ... } }
function MockRuns.LiveAt(plan, t)
    local total, totals, lastAt = MockRuns.TotalAt(plan, t)
    if not lastAt then return nil end
    local secs = math.max(1, math.ceil(t))
    local rows = {}
    for id, dmg in pairs(totals) do rows[#rows + 1] = { id = id, dmg = dmg } end
    table.sort(rows, byDamage)
    local spells = {}
    for i, row in ipairs(rows) do
        spells[i] = { spellID = row.id, total = row.dmg, dps = row.dmg / secs }
    end
    return { total = total, dps = math.floor(total / secs), rung = "sample", maxAmount = rows[1].dmg, spells = spells }
end

-- ── the sample casts and usage (#13, #14) ───────────────────────────────────────────────────────

-- The bag consumable of `kind` with the lowest item ID, or nil.
local function firstOf(bags, kind)
    local best
    for itemID, b in pairs(bags) do
        if NS.Usage.KindOf(b.subclass) == kind and (best == nil or itemID < best) then best = itemID end
    end
    return best
end

-- The arm snapshot a sample is detected from: the player's gear and bags, with a flask's buff (when
-- the bags hold one) and Well Fed on, and a Healthstone when the bags hold no consumable.
local function sampleSnap(snap)
    local s = { gear = snap.gear or {}, bags = copy(snap.bags), auras = {} }
    if next(s.bags) == nil then
        s.bags[HEALTHSTONE.itemID] = { count = 1, subclass = 0, spellID = HEALTHSTONE.spellID }
        s.healthstone = true
    end
    local flask = firstOf(s.bags, "flask")
    if flask then s.auras[1] = { spellID = s.bags[flask].spellID } end
    s.auras[#s.auras + 1] = { name = L["Well Fed"] }
    return s
end

-- The gear's and the potion's uses as casts of their spells, into the plan. A `dry` run drank none.
local function useCasts(s, plan, dry)
    local r, list, spells = plan.rng, plan.casts, plan.cooldowns
    local gear = s.gear[1]
    if gear then
        spells[gear.spellID] = GEAR_CD
        for t = MockRuns.GEAR_AT, plan.secs, MockRuns.GEAR_EVERY do
            list[#list + 1] = { t = round2(t + r() * 0.2), id = gear.spellID, pet = false }
        end
    end
    local potion = not dry and firstOf(s.bags, "potion")
    if potion and MockRuns.POTION_AT <= plan.secs then
        spells[s.bags[potion].spellID] = POTION_CD
        list[#list + 1] = { t = round2(MockRuns.POTION_AT + r() * 0.3), id = s.bags[potion].spellID, pet = false }
    end
end

local function earlierFirst(a, b)
    if a.t ~= b.t then return a.t < b.t end
    return a.id < b.id
end

--- A sample run's cast record and usage record (the stored shapes, modules/Casts.lua and
--- modules/Usage.lua): `plan`'s casts, with what was used, detected by Usage.Build from `snap` (a
--- Usage.Snapshot, the player's own; read now when nil).
--- @param class string|nil  the rotation, with no plan
--- @param secs number  the time in combat, with no plan
--- @param snap table|nil
--- @param plan table|nil  MockRuns.Plan's; made here when nil
--- @param dry boolean|nil  no potion
--- @return table casts, table usage
function MockRuns.Usage(class, secs, snap, plan, dry)
    local s = sampleSnap(snap or NS.Usage.Snapshot())
    plan = plan or MockRuns.Plan({ id = "usage", class = class, length = secs, damage = 1 })
    useCasts(s, plan, dry)
    table.sort(plan.casts, earlierFirst)
    local after = {}
    for itemID, b in pairs(s.bags) do after[itemID] = b.count end
    if s.healthstone then after[HEALTHSTONE.itemID] = 0 end
    local casts = { v = NS.Casts.VERSION, list = NS.Casts.Encode(plan.casts), spells = plan.cooldowns, dropped = 0 }
    return casts, NS.Usage.Build(s, NS.Casts.Decode(casts.list), after)
end

-- The result of a run: plain numbers in the stored shape, as Race reads them. `result.damage` is the
-- meter's; the score is ours (Scoring.Dps) and the meter's rate is its total over its whole-second
-- session. A run that ended before its buzzer has no tail and no combat end; a shared session has no
-- meter rate.
local function resultOf(run, spec, damage)
    local result = { damage = damage }
    if run.status == "incomplete" then
        result.endedAt = spec.endAt
        result.sessionDuration = math.ceil(spec.endAt)
    else
        result.tail = spec.tail or MockRuns.TAIL
        result.combatEnd = spec.combatEnd or math.max(result.tail, MockRuns.COMBAT_END)
        result.sessionDuration = math.ceil(spec.length + result.combatEnd)
    end
    if not spec.shared then result.meterDps = math.floor(damage / result.sessionDuration) end
    run.result = result
    result.dps = NS.Scoring.Dps(damage, run)
    return result
end

-- The late casts `grace` judges late: what Race.judge would have kept.
local function judged(plan, grace)
    local out = {}
    for _, cast in ipairs(plan.late) do
        if NS.Scoring.IsLateCast(cast.t, grace) then out[#out + 1] = cast end
    end
    return out
end

--- A sample run in the stored shape (spec §7), never stored, built on Recorder.NewRun as a race's is
--- (its build, the player's grace and restart gap, the place), and the plan of its fight.
--- @param spec table  { id, char, category, length, dps, date, status?, endAt?, tail?, combatEnd?, late?,
---                    died?, restartedAt?, shared?, note?, class? (the rotation, default the
---                    character's), snap? (MockRuns.Usage's), noMajor?, swap?, dry?, old? (format 2:
---                    no casts, usage or stats) }
--- @return table run, table plan
function MockRuns.Run(spec)
    local status = spec.status or "complete"
    local run = NS.Recorder.NewRun(spec.length)
    run.id, run.sample, run.status = spec.id, true, status
    run.date = spec.date or time()
    run.char, run.target, run.note = spec.char, MockRuns.Target(spec.category), spec.note or ""
    local secs = status == "incomplete" and spec.endAt or spec.length
    local damage = status == "lost" and 1 or math.floor(spec.dps * secs)
    local plan = MockRuns.Plan({
        id = spec.id, class = spec.class or (spec.char and spec.char.class), length = spec.length, secs = secs,
        damage = damage, tail = spec.tail or MockRuns.TAIL, restartedAt = spec.restartedAt, late = spec.late,
        noMajor = spec.noMajor, swap = spec.swap,
    })
    run.flags.lateCasts = judged(plan, run.race.grace)
    run.flags.died, run.flags.restartedAt = spec.died == true, spec.restartedAt
    run.flags.sharedSession = spec.shared == true or nil
    if spec.shared then run.race.baseline = { session = 1, damage = math.floor(damage * 0.14), spells = {} } end
    if status ~= "lost" then
        local result = resultOf(run, spec, damage)
        run.spells = MockRuns.Spells(plan, result.sessionDuration, spec.shared)
    end
    if spec.old then
        run.schema, run.stats = 2, nil
    else
        run.casts, run.usage = MockRuns.Usage(nil, secs, spec.snap, plan, spec.dry)
    end
    return run, plan
end

--- A sample chart record (modules/Slices.lua's shape) for a run of the history: the plan's total at
--- each bucket's end boundary, the last at the buzzer (short of the final damage: the tail still
--- counts), as Slices.Capture would have copied them.
--- @return table|nil rec  { count, values, length, filled, next }
function MockRuns.Slices(run, plan)
    if type(run.result) ~= "table" then return nil end
    local length = run.race.length
    local count, values, filled = NS.Slices.Count(length), {}, 0
    for i = 1, count do
        local at = NS.Slices.Boundary(length, count, i)
        if at > plan.secs + 1e-6 then break end
        values[i] = (MockRuns.TotalAt(plan, at))
        filled = i
    end
    return { count = count, values = values, length = length, filled = filled, next = count + 1 }
end

-- The player's loadout and a variant with one slot changed, keyed as a run refers to them, beside each
-- made-up character's own. Either half is absent when the client could not read it.
local function loadouts()
    local snap = NS.Recorder.SnapshotLoadout() or {}
    local out = { gear = {}, talents = {} }
    for who, alt in pairs(ALTS) do
        out.gear["sample-" .. who], out.talents["sample-" .. who] = alt.gear, alt.talents
    end
    if type(snap.gear) == "table" then
        local b, slot = copy(snap.gear), snap.gear[14] and 14 or snap.gear[13] and 13 or nil
        for s = 18, 1, -1 do slot = slot or (b[s] and s or nil) end
        b[slot] = SWAP_LINK
        out.gear["sample-a"], out.gear["sample-b"] = snap.gear, b
    end
    if type(snap.talents) == "table" then out.talents["sample-a"] = snap.talents end
    return out
end
MockRuns.Loadouts = loadouts

-- The sample stats (#17): the player's own in loadout a; in loadout b (one slot changed) the same less
-- what that slot might have given, so the gear view shows its deltas. A made-up character has its own.
MockRuns.STATS_B = { primary = -310, stamina = -820, armor = -260, critRating = -140, crit = -1.17 }

local function statsFor(h, stats)
    if h.old then return nil end
    if h.who ~= "me" then return ALTS[h.who].stats end
    if not stats or h.loadout ~= "b" then return stats end
    local out = copy(stats)
    for k, d in pairs(MockRuns.STATS_B) do
        if type(out[k]) == "number" then out[k] = out[k] + d end
    end
    return out
end

local function refFor(name, sets)
    local ref = { gear = sets.gear["sample-" .. name] and "sample-" .. name or nil,
                  talents = sets.talents["sample-" .. name] and "sample-" .. name
                      or sets.talents["sample-a"] and "sample-a" or nil }
    if ref.gear == nil and ref.talents == nil then return nil end
    return ref
end

-- What a history row's character had at the arm.
local function snapFor(who, snap)
    if who == "me" then return snap end
    local alt = ALTS[who].snap
    return { gear = alt.gear, bags = copy(alt.bags), auras = {} }
end

--- The sample run history for the Results window: { runs, loadouts, slices }, built fresh.
--- @return table dataset
function MockRuns.Dataset()
    local me, now = MockRuns.Player(), time()
    local sets, snap, stats = loadouts(), NS.Usage.Snapshot(), NS.Stats.Snapshot()
    local data = { runs = {}, loadouts = sets, slices = {} }
    for i, h in ipairs(HISTORY) do
        local char = charFor(h.who, me)
        local run, plan = MockRuns.Run({
            id = ("sample-%02d"):format(i), char = char, category = h.cat, length = h.len, dps = h.dps,
            date = now - h.ago * HOUR, status = h.status, endAt = h.endAt, tail = h.tail, combatEnd = h.combatEnd,
            late = h.late, died = h.died, restartedAt = h.restartedAt, shared = h.shared,
            note = h.note and L[h.note] or nil, snap = snapFor(h.who, snap), old = h.old, noMajor = h.noMajor,
            swap = h.loadout == "b", dry = h.dry,
        })
        run.loadout = not h.old and refFor(h.who == "me" and (h.loadout or "a") or h.who, sets) or nil
        run.stats = statsFor(h, stats)
        data.runs[i] = run
        if h.chart then data.slices[run.id] = MockRuns.Slices(run, plan) end
    end
    return data
end

-- ── the HUD's sample race ───────────────────────────────────────────────────────────────────────

--- A sample race for the HUD against `runs` (the sample history): the finished run and the plan
--- modules/SampleRace.lua plays it from, the best before it on its board, and its delta.
--- @param spec table  { id, category?, dps, status?, endAt?, tail?, combatEnd?, late?, died?, shared? }
--- @param runs table  the history it is raced against
--- @param sets table|nil  the history's loadouts, for the run's own loadout ref
--- @return table sample  { run, plan, best, delta, isNew, dps, stopAt, shared, combatAt }
function MockRuns.Race(spec, runs, sets)
    local char = MockRuns.Player()
    local run, plan = MockRuns.Run({
        id = spec.id or "preview", char = char, category = spec.category or "single",
        length = MockRuns.LENGTH, dps = spec.dps, status = spec.status, endAt = spec.endAt, tail = spec.tail,
        combatEnd = spec.combatEnd, late = spec.late, died = spec.died, shared = spec.shared,
    })
    run.loadout = refFor("a", sets or loadouts())
    local sample = { run = run, plan = plan, dps = spec.dps, stopAt = spec.endAt or MockRuns.LENGTH, shared = spec.shared,
                     early = spec.endAt ~= nil, combatAt = spec.endAt or (MockRuns.LENGTH + run.result.combatEnd) }
    local best = NS.Bests.Before(run, runs)
    sample.best = (best and not spec.shared) and best or nil
    sample.delta, sample.isNew = NS.Bests.Delta(run, runs)
    return sample
end

--- The best before a board's best: what a scenario's DPS is set against (nil with no run there).
--- @return table|nil
function MockRuns.BoardBest(runs, category)
    local probe = { char = MockRuns.Player(), target = { category = category }, race = { length = MockRuns.LENGTH } }
    return NS.Bests.Compute(runs)[NS.Bests.Key(probe)]
end
