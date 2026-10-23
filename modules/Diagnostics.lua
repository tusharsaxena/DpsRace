local _, NS = ...
-- modules/Diagnostics.lua — this addon's sections of `/dr diagnostics` (debug-logging-§14); the library
-- writes the markers, the identity header, the per-section pcall and the cap.

NS.Diagnostics = NS.Diagnostics or {}

local function countRuns()
    local runs = NS.db and NS.db.global and NS.db.global.runs
    local n = 0
    if type(runs) == "table" then for _ in pairs(runs) do n = n + 1 end end
    return n
end

--- Read state, never act: no hold, no event, no timer, safe in combat. `out:add` formats %s-only and
--- runs every argument through safeToString, so pass RAW values.
function NS.Diagnostics.Sections()
    local LC = NS.lifecycle
    return {
        { "identity", function(out)
            local db = NS.db
            out:add("Diag", "schema stored=%s code=%s runFormat=%s", db and db.global.schemaVersion,
                NS.SCHEMA_VERSION, db and db.global.schema)
            out:add("Diag", "profile=%s", db and db:GetCurrentProfile())
            out:add("Diag", "enabled=%s stoodDown=%s", NS.GetSetting("enabled"), LC and LC:IsDown())
            out:joined("Diag", "holds", LC and LC:Holds() or {})
        end },
        { "settings", function(out)
            out:nonDefaults(NS.Schema, NS.GetSetting, function(row) return row.default end, nil,
                { always = { "enabled" } })
        end },
        { "state", function(out)
            if LC and LC:IsDown() then
                out:add("Diag", "stood down: runtime state released")
                return
            end
            out:add("Diag", "runs stored=%s", countRuns())
            local run = NS.Race.Current()
            out:add("Diag", "race state=%s run=%s session=%s pending=%s meter=%s", NS.Race.State(),
                run and run.id, run and run.race and run.race.sessionID, #NS.Recorder.Pending(),
                (NS.Meter.IsAvailable()))
            out:add("Diag", "hud shown=%s results shown=%s testMode=%s", NS.Hud.IsShown(),
                NS.Results.IsShown(), NS.Preview.IsActive())
            local hud = NS.Hud.Diagnose()
            out:add("Diag", "hud body=%s events=%s ticking=%s locked=%s", hud.body, hud.events, hud.ticking,
                hud.locked)
            local cd = NS.Countdown.Diagnose()
            out:add("Diag", "countdown shown=%s scheduled=%s owner=%s", cd.shown, cd.scheduled, cd.owner)
            local test = NS.Preview.Diagnose()
            out:add("Diag", "test active=%s phase=%s ticking=%s", test.active, test.phase, test.ticking)
            local results = NS.Results.Diagnose()
            out:add("Diag", "results tab=%s mode=%s rows=%s selected=%s", results.tab, results.mode,
                results.rows, results.selected)
        end },
        { "rejected", function(out)
            out:list("Diag", "rejected events", NS.rejectedEvents or {})
        end },
    }
end
