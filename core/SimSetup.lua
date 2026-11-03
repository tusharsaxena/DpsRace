local _, NS = ...
-- core/SimSetup.lua — the LibKa0s-Sim-1.0 seam (library-stack-§7, SF-DR-8). `/dr sim` plays a sample race
-- that stands where modules/Race.lua stands (modules/SampleRace.lua), so it fakes no NS.Compat answer:
-- every member is declared pure and the seam wraps nothing. The seam still has to exist, because the
-- library's session (the stepper window beside the race window) binds one. With no library NS.SimSeam is
-- the inert stub and modules/Sim.lua builds no session.

local LibSim = LibStub and LibStub("LibKa0s-Sim-1.0", true)

local function newSeamStub()
    local seam = {}
    function seam.SetProvider() end
    function seam.Live(_, fn, ...) return fn(...) end
    function seam.Keys() return {} end
    function seam.Unwrapped() return {} end
    return seam
end

NS.SimLib = LibSim
if LibSim then
    local pure = {}
    for key, member in pairs(NS.Compat) do
        if type(member) == "function" then pure[key] = true end
    end
    NS.SimSeam = LibSim:NewSeam(NS.Compat, {
        name = "DpsRace",
        pure = pure,
        debug = function(tag, fmt, ...) if NS.Debug then NS.Debug(tag, fmt, ...) end end,
    })
else
    NS.SimSeam = newSeamStub()
end
