local addonName, NS = ...
-- core/Bus.lua — every message name declared ONCE, and the record of the addon's bus receivers.

-- A misspelled literal is a message nobody receives, and nothing goes red. Through a constant the
-- same typo is a nil name at the call site (architecture-§4). The wire name is
-- Ka0s_<Addon>_<Event>, <Event> PascalCase; the SCREAMING_SNAKE key never leaks into it.
NS.MSG = {
    -- Sender: modules/Race.lua (T5). Payload: (run, fromState, toState).
    RACE_STATE_CHANGED = "Ka0s_DpsRace_RaceStateChanged",
    -- Sender: modules/Recorder.lua (T3). Payload: (run).
    RUN_SAVED          = "Ka0s_DpsRace_RunSaved",
    -- Sender: modules/Recorder.lua (T3). Payload: none -- a delete or a prune changed the store.
    RUNS_CHANGED       = "Ka0s_DpsRace_RunsChanged",
    -- Sender: settings/Schema.lua's write seam. Payload: (path, value).
    SETTINGS_CHANGED   = "Ka0s_DpsRace_SettingsChanged",
}

local Bus = LibStub and LibStub("LibKa0s-Bus-1.0", true)
if not Bus then
    -- Degrade, never error: a target is a plain AceEvent embed, and the stand-down has nothing of
    -- its own to drop (the latch's standDown still unregisters each module's messages directly).
    Bus = {
        New = function(_, d)
            return {
                name = d and d.name,
                NewTarget = function()
                    local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
                    if not AceEvent then return nil end
                    local t = {}
                    AceEvent:Embed(t)
                    return t
                end,
                StandDown = function() return 0 end,
                StandUp   = function() return 0, {} end,
            }
        end,
        Catalog = function(_, messages) return messages end,
    }
end
NS.BusLib = Bus

-- One record per addon, beside its latch: it remembers every receiver it hands out, so the latch can
-- drop their message registrations at stand-down and replay them at stand-up (slash-commands-§7).
NS.busRecord = Bus:New({
    name   = addonName,
    isDown = function() return NS.IsStoodDown ~= nil and NS.IsStoodDown() end,
})

--- A receiver of the module's OWN (CallbackHandler keys callbacks by (message, target), so two
--- modules sharing one target clobber each other -- architecture-§4).
function NS.NewBusTarget()
    return NS.busRecord:NewTarget()
end

function NS.BusStandDown()
    return NS.busRecord:StandDown()
end

function NS.BusStandUp()
    local replayed = NS.busRecord:StandUp()
    return replayed
end

--- The one sender: every message leaves through the addon object so a receiver on any target hears
--- it. Resolved at call time because core/DpsRace.lua builds NS.addon after this file loads.
function NS.SendBus(name, ...)
    local addon = NS.addon
    if addon and addon.SendMessage then addon:SendMessage(name, ...) end
end
