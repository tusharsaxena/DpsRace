local _, NS = ...
-- modules/MockRuns.lua — the sample data test mode and the sim draw (B5, the owner's call, 2026-10-25):
-- a made-up run history for the Results window, and a made-up race for the HUD with the figures each
-- of its bodies reads.
--
-- MADE FRESH, KEPT IN MEMORY, NEVER STORED. Every table here is built on the call, from the player's
-- own name, spec, place and loadout (read out of combat: test mode and the sim refuse to start in
-- it) plus two made-up characters. Nothing is written to NS.db: the Results window reads the history
-- through modules/Results_Source.lua's sample seam, and the HUD draws the race through Hud.Render.
-- Every number is plain, so the history sorts, ranks and charts as a stored one does.

local MockRuns = {}
NS.MockRuns = MockRuns

local L = NS.L

-- The HUD's sample race: its length, the DoT tail after its buzzer, the grace in force, and how long
-- the Stop! phase holds before Waiting (the waiting body counts on from it).
MockRuns.LENGTH = 30
MockRuns.TAIL = 3.1
MockRuns.GRACE = 1.0
MockRuns.STOP_SECS = 3
-- The best a board-less sample races at (the first race on its board has nothing to beat).
MockRuns.DPS = 147600

-- Each class's sample breakdown: each spell's share of the damage, in the order Blizzard would list
-- it. Names and icons come from C_Spell, as for a real run.
local SPELLS = {
    WARLOCK = {
        { id = 5740, share = 0.276 },     -- Rain of Fire
        { id = 116858, share = 0.185 },   -- Chaos Bolt
        { id = 445468, share = 0.184 },   -- Wither
        { id = 29722, share = 0.161 },    -- Incinerate
        { id = 17962, share = 0.104 },    -- Conflagrate
        { id = 17877, share = 0.052 },    -- Shadowburn
        { id = 1122, share = 0.038 },     -- Summon Infernal
    },
    PALADIN = {
        { id = 85256, share = 0.312 },    -- Templar's Verdict
        { id = 184575, share = 0.221 },   -- Blade of Justice
        { id = 255937, share = 0.168 },   -- Wake of Ashes
        { id = 20271, share = 0.142 },    -- Judgment
        { id = 53385, share = 0.097 },    -- Divine Storm
        { id = 35395, share = 0.060 },    -- Crusader Strike
    },
    MAGE = {
        { id = 11366, share = 0.334 },    -- Pyroblast
        { id = 133, share = 0.207 },      -- Fireball
        { id = 108853, share = 0.171 },   -- Fire Blast
        { id = 12654, share = 0.139 },    -- Ignite
        { id = 257541, share = 0.098 },   -- Phoenix Flames
        { id = 2120, share = 0.051 },     -- Flamestrike
    },
}
-- The player's own sample runs draw the Destruction breakdown whatever the class (the HUD's sample
-- always has).
MockRuns.SPELLS = SPELLS.WARLOCK

-- The two made-up characters beside the player, on the player's realm.
local ALTS = {
    ret  = { name = "Sampleblade", class = "PALADIN", specID = 70, spec = "Retribution", ilvl = 312.4 },
    fire = { name = "Mockflame", class = "MAGE", specID = 63, spec = "Fire", ilvl = 309.8 },
}

-- The catalog's dummy per target type (defaults/Dummies.lua), and the count raced on it.
local TARGETS = {
    single = { count = 1 }, cleave = { npcID = 243208, count = 5 }, dungeoneer = { npcID = 243167, count = 1 },
    boss = { npcID = 243205, count = 1 }, pvp = { npcID = 243211, count = 1 },
}

-- The history: every target type, all five preset lengths and every Status the Runs list draws (Max,
-- Spec best, Complete, Flagged, Incomplete, Died, Lost), with notes, loadouts and charts on some.
-- `ago` is hours before now; `loadout` names a sample set ("a", or "b": "a" with one slot changed).
local HISTORY = {
    { who = "me", cat = "single", len = 30, dps = 151200, ago = 26, loadout = "a", chart = true,
      note = "Sample note: opener with every cooldown" },
    { who = "me", cat = "single", len = 30, dps = 144900, ago = 5, loadout = "b" },
    { who = "me", cat = "single", len = 30, dps = 149800, ago = 8,
      late = { { t = 1.6, spellID = 116858 }, { t = 2.3, spellID = 29722 } } },
    { who = "me", cat = "single", len = 60, dps = 139400, ago = 30, loadout = "a", chart = true },
    { who = "me", cat = "cleave", len = 120, dps = 212300, ago = 50, note = "Sample note: five dummies in reach" },
    { who = "me", cat = "boss", len = 180, dps = 128700, ago = 72, status = "incomplete", endAt = 95 },
    { who = "me", cat = "dungeoneer", len = 300, dps = 135100, ago = 96, loadout = "a", chart = true },
    { who = "me", cat = "single", len = 60, dps = 120500, ago = 3, status = "incomplete", endAt = 41, died = true },
    { who = "me", cat = "single", len = 30, ago = 2, status = "lost" },
    { who = "me", cat = "pvp", len = 120, dps = 118200, ago = 120, restartedAt = 47.5 },
    { who = "ret", cat = "single", len = 30, dps = 163400, ago = 12, note = "Sample note: another character's best" },
    { who = "ret", cat = "cleave", len = 120, dps = 198600, ago = 60 },
    { who = "ret", cat = "boss", len = 180, dps = 141000, ago = 84, shared = true },
    { who = "fire", cat = "single", len = 60, dps = 146100, ago = 20, chart = true },
    { who = "fire", cat = "dungeoneer", len = 300, dps = 127300, ago = 110, status = "incomplete", endAt = 212 },
    { who = "fire", cat = "single", len = 30, dps = 155800, ago = 40 },
}
MockRuns.HISTORY = HISTORY

local HOUR = 3600

local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

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
    local c = copy(ALTS[who])
    c.realm = me.realm
    return c
end

local function spellsFor(who, class)
    if who == "me" then return MockRuns.SPELLS end
    return SPELLS[class] or MockRuns.SPELLS
end

--- A target of `category` as a run records it.
function MockRuns.Target(category)
    local spec = TARGETS[category] or TARGETS.single
    local d = spec.npcID and NS.Dummies.Lookup(spec.npcID)
    return { npcID = spec.npcID, name = d and d.name or L["Training Dummy"], category = category,
             count = spec.count }
end

--- The breakdown of `damage` at `dps` along `list`'s shares, highest first.
function MockRuns.Spells(list, damage, dps)
    local out = {}
    for i, s in ipairs(list) do out[i] = { id = s.id, dmg = math.floor(damage * s.share), dps = dps * s.share } end
    return out
end

-- The result of a run at `dps` for `secs` seconds (the length, or the time in combat for an
-- incomplete run): plain numbers in the stored shape.
local function resultOf(status, dps, length, endAt)
    local secs = status == "incomplete" and endAt or length
    local damage = math.floor(dps * secs)
    local result = { damage = damage, dps = dps, meterDps = math.floor(dps * 0.92), tail = MockRuns.TAIL,
                     sessionDuration = secs + MockRuns.TAIL + 2 }
    if status == "incomplete" then result.endedAt = endAt else result.combatEnd = MockRuns.TAIL + 2 end
    return result
end

--- A sample run in the stored shape (spec §7), never stored.
--- @param spec table  { id, char, category, length, dps, date, status?, endAt?, late?, died?, restartedAt?,
---                    shared?, note?, spells? }
--- @return table run
function MockRuns.Run(spec)
    local status = spec.status or "complete"
    local run = {
        id = spec.id, schema = NS.Recorder.RUN_SCHEMA, status = status, addon = NS.version, sample = true,
        date = spec.date or time(),
        race = { length = spec.length, grace = MockRuns.GRACE, restartGap = 6, startSource = "meterSession" },
        char = spec.char, target = MockRuns.Target(spec.category), where = NS.Recorder.SnapshotWhere(),
        flags = { lateCasts = spec.late or {}, reloaded = false, died = spec.died == true,
                  restartedAt = spec.restartedAt, sharedSession = spec.shared == true or nil },
        spells = {}, note = spec.note or "",
    }
    if status ~= "lost" then
        run.result = resultOf(status, spec.dps, spec.length, spec.endAt)
        run.spells = MockRuns.Spells(spec.spells or MockRuns.SPELLS, run.result.damage, spec.dps)
    end
    return run
end

--- A sample chart record (modules/Slices.lua's shape) for `run`: its damage at each bucket's end
--- boundary, a little ahead early on (an opener), up to `upTo` seconds (default the length).
--- @return table|nil rec  { count, values, length, filled }
function MockRuns.Slices(run, upTo)
    local result, length = run.result, run.race.length
    if type(result) ~= "table" then return nil end
    local count, values, filled = NS.Slices.Count(length), {}, 0
    local secs = upTo or length
    for i = 1, count do
        local at = NS.Slices.Boundary(length, count, i)
        if at > secs + 1e-6 then break end
        values[i] = math.floor(result.damage * (at / secs) ^ 0.92)
        filled = i
    end
    return { count = count, values = values, length = length, filled = filled }
end

-- The player's loadout and a variant with one slot changed, keyed as a run refers to them. Either
-- half is absent when the client could not read it.
local function loadouts()
    local snap = NS.Recorder.SnapshotLoadout() or {}
    local out = { gear = {}, talents = {} }
    if type(snap.gear) == "table" then
        local b = copy(snap.gear)
        for slot = 18, 1, -1 do
            if b[slot] then b[slot] = nil break end
        end
        out.gear["sample-a"], out.gear["sample-b"] = snap.gear, b
    end
    if type(snap.talents) == "table" then out.talents["sample-a"] = snap.talents end
    return out
end

local function refFor(name, sets)
    if not name then return nil end
    local ref = { gear = sets.gear["sample-" .. name] and "sample-" .. name or nil,
                  talents = sets.talents["sample-a"] and "sample-a" or nil }
    if ref.gear == nil and ref.talents == nil then return nil end
    return ref
end

--- The sample run history for the Results window: { runs, loadouts, slices }, built fresh.
--- @return table dataset
function MockRuns.Dataset()
    local me, now = MockRuns.Player(), time()
    local sets = loadouts()
    local data = { runs = {}, loadouts = sets, slices = {} }
    for i, h in ipairs(HISTORY) do
        local char = charFor(h.who, me)
        local run = MockRuns.Run({
            id = ("sample-%02d"):format(i), char = char, category = h.cat, length = h.len, dps = h.dps,
            date = now - h.ago * HOUR, status = h.status, endAt = h.endAt, late = h.late, died = h.died,
            restartedAt = h.restartedAt, shared = h.shared, note = h.note and L[h.note] or nil,
            spells = spellsFor(h.who, char.class),
        })
        run.loadout = refFor(h.loadout, sets)
        data.runs[i] = run
        if h.chart then data.slices[run.id] = MockRuns.Slices(run) end
    end
    return data
end

-- ── the HUD's sample race ───────────────────────────────────────────────────────────────────────

--- The live figures `elapsed` seconds in: plain numbers, in the shape Meter.ReadLive answers.
local function liveAt(sample, elapsed)
    local dps = sample.dps
    local total = math.floor(dps * elapsed)
    local live = { total = total, dps = dps, maxAmount = math.floor(total * MockRuns.SPELLS[1].share), spells = {} }
    for i, s in ipairs(MockRuns.SPELLS) do
        live.spells[i] = { spellID = s.id, total = math.floor(total * s.share), dps = dps * s.share }
    end
    return live
end

-- The running chart (#2): the damage at each whole second so far, against the best's pace as a race
-- with a best is scaled (scale A), else the live total (scale B, the first race on its board).
local function runningChart(sample, elapsed)
    local values = {}
    for i = 1, math.floor(elapsed) do values[i] = sample.dps * i end
    local chart = { count = NS.Slices.Count(MockRuns.LENGTH), values = values, length = MockRuns.LENGTH,
                    note = L["first race on this board"] }
    if sample.best then
        chart.best = sample.best.result.damage
        chart.max = chart.best * NS.HudChart.HEADROOM
        chart.note = L["vs best pace"]
    end
    return chart
end

--- A sample race for the HUD against `runs` (the sample history): the run, the best before it on
--- its board, and its delta, as the race and the result card would work them out.
--- @param spec table  { id, category?, dps, status?, endAt?, late?, died?, shared? }
--- @param runs table  the history it is raced against
--- @return table sample  { run, best, delta, isNew, dps, stopAt }
function MockRuns.Race(spec, runs)
    local run = MockRuns.Run({
        id = spec.id or "preview", char = MockRuns.Player(), category = spec.category or "single",
        length = MockRuns.LENGTH, dps = spec.dps, status = spec.status, endAt = spec.endAt, late = spec.late,
        died = spec.died, shared = spec.shared,
    })
    run.preview = true
    local sample = { run = run, dps = spec.dps, stopAt = spec.endAt or MockRuns.LENGTH, shared = spec.shared }
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

-- Each body's figures, `t` seconds into its phase.
local FIGURES = {
    armed = function() return {} end,
    running = function(s, t)
        local elapsed = math.min(t, s.stopAt)
        local f = { timeLeft = MockRuns.LENGTH - elapsed, elapsed = elapsed, live = liveAt(s, elapsed) }
        if not s.shared then f.chart = runningChart(s, elapsed) end
        if s.best then f.pace = { max = NS.HudChart.PaceMax(s.best, elapsed) } end
        return f
    end,
    stop = function(s, t)
        local late = {}
        for _, cast in ipairs(s.run.flags.lateCasts) do
            if cast.t <= t then late[#late + 1] = cast end
        end
        return { tail = math.min(t, MockRuns.TAIL), sinceBuzzer = t, inCombat = true, grace = MockRuns.GRACE,
                 lateCasts = late }
    end,
    waiting = function(_, t)
        return { tail = MockRuns.TAIL, sinceBuzzer = MockRuns.STOP_SECS + t, inCombat = true,
                 hint = L["Combat is holding. Walk out of range. Your score is safe: it waits for combat to end, however long that takes."] }
    end,
    -- The result card: the delta, the run's chart scaled to its final damage, and the pace bar (its
    -- final damage against the best before it at the buzzer), as Hud.lua's result view draws them.
    result = function(s)
        local f = { isNew = s.isNew, delta = s.delta, icons = true }
        if not s.shared then
            local rec = MockRuns.Slices(s.run, s.stopAt)
            f.chart = rec and { count = rec.count, values = rec.values, length = rec.length,
                                max = s.run.result.damage, note = "" }
        end
        if s.best then
            f.pace = { max = NS.HudChart.PaceMax(s.best, MockRuns.LENGTH), value = s.run.result.damage }
        end
        return f
    end,
}

--- The figures `key`'s body reads `t` seconds into its phase, for `sample` (MockRuns.Race's).
--- @param sample table
--- @param key string  "armed" | "running" | "stop" | "waiting" | "result"
--- @param t number
--- @return table figures
function MockRuns.Figures(sample, key, t)
    return FIGURES[key](sample, t or 0)
end
