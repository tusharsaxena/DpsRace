-- tests/race_clock.lua — the Race suites' fixture: an isolated instance on the scripted meter, a fake
-- clock that fires C_Timer timers and tickers at their due GetTime(), and drivers for Race's inputs.
--
-- Loaded by a suite as `dofile(T.root .. "/tests/race_clock.lua")(T)`. Not a suite itself.
--
-- THE CLOCK. The kit's C_Timer queue fires everything at once (`M.__fireTimers`), which cannot say
-- WHEN a buzzer went or a readiness poll ran. This one replaces NewTimer and NewTicker on the
-- instance's own C_Timer: each handle is due at GetTime() + delay, and `advance(dt)` / `to(t)` walk
-- the clock forward, firing every due callback at its own time, in time order. Every handle is also
-- pushed onto `M.__timers`, so the kit's live-timer survey (`M.__timers()`) still sees what is armed;
-- a fired one-shot and a canceled handle are marked `cancelled`, which is what the survey skips.

return function(T)
    local F = {}

    -- Floating tolerance for "due": half-second steps from a whole second are exact, but a sum of
    -- tenths is not.
    local EPS = 1e-9

    local function installClock(M)
        local clock = { entries = {} }

        local function newHandle(delay, interval, iterations)
            local e = { at = M.__now + delay, interval = interval, left = iterations }
            function e.Cancel() e.cancelled = true end
            function e.IsCancelled() return e.cancelled == true end
            clock.entries[#clock.entries + 1] = e
            M.__timers[#M.__timers + 1] = e
            return e
        end

        M.C_Timer.NewTimer = function(delay, fn)
            local e = newHandle(delay)
            e.fn = function() fn(e) end
            return e
        end
        M.C_Timer.NewTicker = function(interval, fn, iterations)
            local e = newHandle(interval, interval, iterations)
            e.fn = function() fn(e) end
            return e
        end

        local function nextDue(limit)
            local due
            for _, e in ipairs(clock.entries) do
                if not e.cancelled and e.at <= limit + EPS and (not due or e.at < due.at) then due = e end
            end
            return due
        end

        --- Walk the clock forward `dt` seconds, firing each due callback at its own time.
        function clock.advance(dt)
            local limit = M.__now + dt
            local due = nextDue(limit)
            while due do
                if due.at > M.__now then M.__now = due.at end
                if due.interval then
                    due.at = due.at + due.interval
                    if due.left then
                        due.left = due.left - 1
                        if due.left <= 0 then due.cancelled = true end
                    end
                else
                    due.cancelled = true
                end
                due.fn()
                due = nextDue(limit)
            end
            M.__now = limit
        end

        --- Walk the clock to the absolute time `t`.
        function clock.to(t) clock.advance(t - M.__now) end

        --- How many handles are still armed.
        function clock.live()
            local n = 0
            for _, e in ipairs(clock.entries) do if not e.cancelled then n = n + 1 end end
            return n
        end

        return clock
    end
    F.installClock = installClock

    --- What the bus says about the race, in order.
    local function listen(NS)
        local heard = { states = {}, buzzers = {}, results = {} }
        local target = assert(NS.NewBusTarget(), "no bus target")
        target:RegisterMessage(NS.MSG.RACE_STATE_CHANGED, function(_, run, from, to)
            heard.states[#heard.states + 1] = { run = run, from = from, to = to }
        end)
        if NS.MSG.RACE_BUZZER then
            target:RegisterMessage(NS.MSG.RACE_BUZZER, function(_, run)
                heard.buzzers[#heard.buzzers + 1] = run
            end)
        end
        if NS.MSG.RACE_RESULT then
            target:RegisterMessage(NS.MSG.RACE_RESULT, function(_, run)
                heard.results[#heard.results + 1] = run
            end)
        end
        return heard
    end

    --- The transitions heard so far, as "from>to,from>to".
    local function trail(heard)
        local out = {}
        for i, s in ipairs(heard.states) do out[i] = tostring(s.from) .. ">" .. tostring(s.to) end
        return table.concat(out, ",")
    end
    F.trail = trail

    -- The probe's run 8 (spec §7): the session the race fights in.
    F.SESSION = {
        damage = 1539711, dps = 39479.8, duration = 39,
        spells = {
            { id = 29722, dmg = 482113, dps = 2678.4 },
            { id = 116858, dmg = 400000, dps = 2222.2 },
            { id = 348, dmg = 300000, dps = 1666.6 },
        },
    }

    local methods = {}
    local META = { __index = methods }

    function methods:now() return self.M.__now end
    function methods:to(t) self.clock.to(t) end
    function methods:advance(dt) self.clock.advance(dt) end

    --- Arm with the given length (default 30).
    function methods:arm(length, count)
        return self.Race.Arm(length or 30, count)
    end

    --- Combat starts and the first hit lands, on one frame: the regen edge, the new meter session and
    --- the first DamageDone update for it (spec §4.2). The meter goes secret, as it does in combat.
    function methods:start(sessionID)
        sessionID = sessionID or 25
        local t = self:now()
        self.M.__inCombat = true
        self.meter.SetSession(sessionID, F.SESSION)
        self.meter.SetSecret(true)
        self.Race.OnCombatStart(t)
        self.Race.OnSessionCreated(t)
        self.Race.OnMeterUpdate(self.NS.Meter.STAT_DAMAGE_DONE, sessionID, t)
        return sessionID
    end

    --- One DamageDone update for `sessionID` (default 25) at the current time.
    function methods:update(sessionID)
        self.Race.OnMeterUpdate(self.NS.Meter.STAT_DAMAGE_DONE, sessionID or 25, self:now())
    end

    --- Combat drops: the regen edge, and the meter readable again.
    function methods:combatEnd()
        self.M.__inCombat = false
        self.meter.SetSecret(false)
        self.Race.OnCombatEnd(self:now())
    end

    function methods:stored(id) return self.NS.Recorder.Get(id) end
    function methods:reads() return #self.meter.CallsTo("GetCombatSessionFromID") end
    function methods:trail() return trail(self.heard) end

    --- A fresh instance on the scripted meter and the fake clock, its clock at 100.
    ---   opts.enable  false = initialize but do not enable (seed the store, then call f:enable())
    ---   opts.mutate  function(mocks), run after the meter and the clock are installed (the HUD
    ---                suites add their widget recorder here)
    function F.new(opts)
        opts = opts or {}
        local meter, clock
        local inst = T.load{
            enable = opts.enable,
            mutate = function(m)
                meter = T.mockMeter.install(m)
                clock = installClock(m)
                if opts.mutate then opts.mutate(m) end
            end,
        }
        local NS, M = inst.NS, inst.mocks
        M.__now = 100
        -- Stored fixtures carry 1970-era dates; never prune by age here (the prune cases set it).
        NS.db.global.history.keepDays = 0
        local f = setmetatable({ inst = inst, NS = NS, M = M, meter = meter, clock = clock,
                                 Race = NS.Race, heard = listen(NS) }, META)
        return f
    end

    --- OnEnable for an instance loaded with `enable = false`.
    function methods:enable()
        self.M.LibStub("AceAddon-3.0"):EnableAddon(self.NS)
    end

    --- The path of the first secret anywhere in `v` (a key or a value, at any depth), or nil. What a
    --- run must never carry into SavedVariables.
    function F.findSecret(v, path, seen)
        path, seen = path or "run", seen or {}
        if T.isSecret(v) then return path end
        if type(v) ~= "table" or seen[v] then return nil end
        seen[v] = true
        for k, sub in pairs(v) do
            if T.isSecret(k) then return path .. "[<secret key>]" end
            local hit = F.findSecret(sub, path .. "." .. tostring(k), seen)
            if hit then return hit end
        end
        return nil
    end

    --- A stored-shape run as a /reload leaves it (spec §7), for the resume cases.
    function F.storedRun(fields)
        local run = {
            id = "1792758447-4429", schema = 1, status = "running", addon = "0.1.0", build = 120105,
            date = 1792758447,
            race = { length = 30, grace = 1.0, restartGap = 6, startSource = "meterSession",
                     sessionID = 25, startedAt = 100 },
            char = { name = "Testchar" }, target = { category = "other", count = 1 }, where = {},
            flags = { lateCasts = {}, reloaded = false, died = false },
            spells = {}, note = "",
        }
        for k, v in pairs(fields or {}) do run[k] = v end
        return run
    end

    return F
end
