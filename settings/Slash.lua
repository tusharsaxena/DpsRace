local _, NS = ...
-- settings/Slash.lua — the ordered NS.COMMANDS table and the LibKa0s-Slash-1.0 descriptor; `/dr` and
-- `/dpsrace` both reach the one dispatcher.

NS.Slash = NS.Slash or {}
local Sl = NS.Slash
local L = NS.L

local function out(line) NS.Print(line) end

local cli   -- built at the bottom, once NS.COMMANDS exists; handlers reach it at CALL time
local doEnabled, doDebug, doPerf

-- Positional triples {name, desc, fn}: a table of named fields is invisible to the library. The
-- reserved verbs mean the same thing in every Ka0s addon (slash-commands-§2); `diagnostics` has no
-- alias of any kind. T9 appends the feature rows (arm, cancel, hud, results, target, test, lock,
-- unlock) after `version`.
NS.COMMANDS = {
    { "help",        L["Show this help"],                          function() cli:PrintHelp() end },
    { "config",      L["Open the settings panel"],                 function() NS.OpenOptionsPanel() end },
    { "enable",      L["Turn the addon on"],                       function() doEnabled(true) end },
    { "disable",     L["Turn the addon off without unloading it"], function() doEnabled(false) end },
    { "list",        L["List every setting"],                      function() cli:CliList() end },
    { "get",         L["Read one setting: /dr get path"],          function(rest) cli:CliGet(rest) end },
    { "set",         L["Write one setting: /dr set path value"],   function(rest) cli:CliSet(rest) end },
    { "reset",       L["Reset one setting: /dr reset path"],       function(rest) cli:CliReset(rest) end },
    { "resetall",    L["Reset every setting (asks first)"],        function() NS.ShowResetAll() end },
    { "debug",       L["Debug console; on/off set logging, diagnostics writes the report"],
                                                                   function(rest) doDebug(rest) end },
    { "diagnostics", L["Write the diagnostics report to the debug console"],
                                                                   function() NS.DebugLog:RunDiagnostics() end },
    { "perf",        L["Performance capture; try /dr perf help"], function(rest) doPerf(rest) end },
    { "version",     L["Print the addon version"],                 function() cli:CliVersion() end },
}

--- Run one verb's handler by name: the launcher's Enabled entry reaches `enable`/`disable` through
--- here, so the menu and the verb are one handler (launcher-§2).
function NS.RunVerb(verb, rest)
    for _, entry in ipairs(NS.COMMANDS) do
        if entry[1] == verb then return entry[3](rest or "") end
    end
end

local SlashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
local degraded = false

if not SlashLib then
    -- Degrade, never error: `/dr` is registered unconditionally, so something must answer it. The
    -- host verbs keep working; the schema CLI names the missing library. The ONE library string this
    -- stub carries is DISABLED_LINE_FORMAT, pinned by tests/test_slash.lua against the live major.
    degraded = true
    local MISSING = L["%s is unavailable: the LibKa0s library did not load."]
    SlashLib = { DISABLED_LINE_FORMAT = "%s is disabled \226\128\148 enable it with |cFFFFFF00%s|r" }
    Sl.__stubFormat = SlashLib.DISABLED_LINE_FORMAT
    function SlashLib.New(_, d)
        local stub = {}
        local function absent(verb) return function() out(MISSING:format(d.slash .. " " .. verb)) end end
        for _, verb in ipairs({ "List", "Get", "Set", "Reset", "ResetAll", "Profile" }) do
            stub["Cli" .. verb] = absent(verb:lower())
        end
        stub.SetRowAnnotator = function() end
        stub.ProfileSwitch = function() return false end
        stub.DisabledLine = function()
            return SlashLib.DISABLED_LINE_FORMAT:format(d.brandName, d.slash .. " enable")
        end
        local function version() return tostring(d.version and d.version() or "?") end
        stub.CliVersion = function() out(L["v%s"]:format(version())) end
        stub.LandingRows = function()
            local rows = {}
            for _, e in ipairs(d.commands) do rows[#rows + 1] = d.slash .. " " .. e[1] .. "  " .. e[2] end
            return rows
        end
        stub.HelpRows = function()
            local rows = {}
            for _, r in ipairs(stub.LandingRows()) do rows[#rows + 1] = "  " .. r end
            return rows
        end
        stub.PrintHelp = function()
            out(L["v%s slash commands"]:format(version()))
            for _, r in ipairs(stub.HelpRows()) do out(r) end
        end
        -- Minimal dispatch is the host's own routing (slash-commands-§1): split, look up, call.
        stub.OnSlash = function(_, msg)
            local raw = tostring(msg or ""):match("^%s*(.-)%s*$")
            if raw == "" then return NS.RunVerb("config") end
            local verb, rest = raw:match("^(%S+)%s*(.*)$")
            verb = verb:lower()
            verb = (d.aliases or {})[verb] or verb
            for _, e in ipairs(d.commands) do
                if e[1] == verb then return e[3](rest or "") end
            end
            out(L["unknown command '%s'"]:format(verb))
            stub.PrintHelp()
        end
        return stub
    end
end

cli = SlashLib:New({
    slash        = NS.SLASH,
    slashAliases = { NS.SLASH_LONG },
    commands     = NS.COMMANDS,                       -- passed IN, never owned by the library
    aliases      = { options = "config" },
    -- The disabled gate: every verb not on the library's live list answers the one refusal line
    -- while the `disabled` hold is taken (slash-commands-§2, §7). Not IsStoodDown: the `perf` hold
    -- alone must not print the disabled line.
    isEnabled    = function() return not NS.IsDisabled() end,
    brandName    = NS.BRAND,
    print        = function(line) out(line) end,
    version      = function() return NS.Version() end,
    get          = function(path) return NS.GetSetting(path) end,
    set          = function(path, value) return NS.SetByPath(path, value) end,   -- the single write seam
    findRow      = function(path) return NS.FindSchemaRow(path) end,
    allRows      = function() return NS.Schema end,
    applyDefault = function(row) return NS.ApplyDefault(row) end,
    bulkBegin    = function(act, scope) NS.Bulk.Begin(act, scope) end,
    bulkEnd      = function(act, scope, count, err, info) NS.Bulk.End(act, scope, count, err, info) end,
    groupKey     = function(row) return (row.page or "?") .. " \226\128\186 " .. (row.group or "?") end,
    format       = function(row, value) return NS.FormatSchemaValue(row, value) end,
    -- The dispatcher's own refusals land in the console as one `Cmd` line each (debug-logging-§4).
    debug        = function(tag, message) NS.Debug(tag, "%s", message) end,
})
Sl.__dispatcher = cli

--- `enable` / `disable`: a write to the composed `enabled` row through the seam, echoed by the CLI
--- so the stored value is what the player reads back. Degraded, the write goes through the seam's
--- writeThrough list and is acknowledged only if it landed (options-ui-§1).
function doEnabled(want)
    if not degraded and NS.FindSchemaRow("enabled") then
        cli:CliSet("enabled " .. tostring(want))
        return
    end
    local ok, err = NS.SetByPath("enabled", want)
    if ok then
        -- A written-through value runs no onChange; take the hold here so the switch still acts.
        NS.ApplyEnabled(want)
        out(L["enabled = %s"]:format(tostring(want)))
    else
        out(tostring(err))
    end
end

--- `diagnostics` is tested FIRST (debug-logging-§14), then `on`/`off`; any other word, or none,
--- toggles the WINDOW with the flag untouched. A retired `diag` is just an unknown word.
function doDebug(rest)
    if not NS.DebugLog:DebugVerb(rest) then NS.DebugLog:Toggle() end
end

--- `perf`: the reserved verb the HOST registers (performance-§4). The library returns lines.
function doPerf(rest)
    local lines = NS.Perf.OnCommand(rest)
    if type(lines) ~= "table" then return end
    for _, line in ipairs(lines) do out(line) end
end

function Sl:OnSlash(msg) return cli:OnSlash(msg) end
function Sl:PrintHelp() return cli:PrintHelp() end
function Sl:LandingRows() return cli:LandingRows() end
function Sl:DisabledLine() return cli:DisabledLine() end

--- Both chat commands on the one dispatcher, through AceConsole (never raw SLASH_*).
function Sl:Register()
    NS.addon:RegisterChatCommand(NS.SLASH:sub(2), function(msg) Sl:OnSlash(msg) end)
    NS.addon:RegisterChatCommand(NS.SLASH_LONG:sub(2), function(msg) Sl:OnSlash(msg) end)
end
