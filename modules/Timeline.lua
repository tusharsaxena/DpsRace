local _, NS = ...
-- modules/Timeline.lua — the run session's damage-update timeline (spec §5.3): when your damage
-- stopped after the buzzer (the tail), whether it landed again after a quiet gap (damage restarted)
-- and how long it has been quiet (the 2.5s wait before the result read, spec §4.5).
--
-- PURE. No WoW API, no meter value: a timeline holds only GetTime() stamps that Race records when a
-- DAMAGE_METER_COMBAT_SESSION_UPDATED arrives for the run's session (spec §8 rule 2: decisions come
-- from events and the clock, never from a meter number). One timeline per run; it is not persisted:
-- after a /reload Race starts a fresh one from the run's last stamp (run.race.lastDamage).

local Timeline = {}
NS.Timeline = Timeline

local methods = {}
local META = { __index = methods }

--- A new, empty timeline.
function Timeline.New()
    return setmetatable({ times = {}, n = 0 }, META)
end

--- Record one damage update at time `t` (GetTime()). Updates normally arrive in order; a late one
--- is placed where it belongs, so the stamps stay sorted. A non-number is ignored.
function methods:AddDamage(t)
    if type(t) ~= "number" then return end
    local times, n = self.times, self.n
    local i = n
    while i > 0 and times[i] > t do
        times[i + 1] = times[i]
        i = i - 1
    end
    times[i + 1] = t
    self.n = n + 1
end

--- The time of the latest damage update, or nil when there is none.
function methods:LastDamage()
    return self.times[self.n]
end

--- Seconds from the buzzer to the last damage update after it; 0 when nothing landed after it.
function methods:Tail(buzzer)
    local last = self.times[self.n]
    if last and last > buzzer then return last - buzzer end
    return 0
end

--- The offset from the buzzer of the first damage update after it that follows a quiet stretch of at
--- least `gap` seconds. The stretch starts at the previous update or the buzzer, whichever is later.
--- nil when the damage never restarted.
function methods:RestartAt(buzzer, gap)
    local prev = buzzer
    local times = self.times
    for i = 1, self.n do
        local t = times[i]
        if t > buzzer then
            if t - prev >= gap then return t - buzzer end
            prev = t
        end
    end
    return nil
end

--- Seconds since the last damage update at `now`; math.huge when there has been none.
function methods:QuietFor(now)
    local last = self.times[self.n]
    if not last then return math.huge end
    return now - last
end
