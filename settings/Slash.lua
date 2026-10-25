local _, NS = ...
-- settings/Slash.lua — the ordered NS.COMMANDS table and the LibKa0s-Slash-1.0 descriptor; `/dr` and
-- `/dpsrace` both reach the one dispatcher.

NS.Slash = NS.Slash or {}
local Sl = NS.Slash
local L = NS.L

local function out(line) NS.Print(line) end

local cli   -- built at the bottom, once NS.COMMANDS exists; handlers reach it at CALL time
local doEnabled, doDebug, doPerf, doSetVerb
local doArm, doCancel, doHud, doResults, doTarget, doLock, doTest, doSim

--- A feature verb's handler behind the stand-down: the dispatcher refuses every feature verb while the
--- `disabled` hold is taken, and this answers the `perf` hold's line (slash-commands-§7, "Which
--- refusal, by hold") before the handler can act.
local function feature(fn)
    return function(rest)
        local line = NS.StoodDownRefusal()
        if line then return out(line) end
        return fn(rest)
    end
end

-- Positional triples {name, desc, fn}: a table of named fields is invisible to the library. The
-- reserved verbs mean the same thing in every Ka0s addon (slash-commands-§2); `diagnostics` has no
-- alias of any kind. The feature verbs (spec §6.4) follow `version`; the dispatcher refuses each of
-- them with the one line while the addon is disabled (slash-commands-§2, §7).
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
    -- Feature verbs (spec §6.4). Each handler sits behind feature(), below.
    { "arm",         L["Arm a race: /dr arm [length], e.g. 90, 1:30 or 3m"],
                                                                   feature(function(rest) doArm(rest) end) },
    { "cancel",      L["Cancel the armed or running race, or discard a pending result"],
                                                                   feature(function() doCancel() end) },
    { "hud",         L["The race HUD: /dr hud show, hide or toggle"],
                                                                   feature(function(rest) doHud(rest) end) },
    { "results",     L["Open the Results window; /dr results bests opens the bests"],
                                                                   feature(function(rest) doResults(rest) end) },
    { "target",      L["Print your target's name, creature ID and category"],
                                                                   feature(function() doTarget() end) },
    { "test",        L["Sample data in the HUD and the Results window: /dr test [armed|running|result]"],
                                                                   feature(function(rest) doTest(rest) end) },
    { "sim",         L["Play a whole sample race: /dr sim [newbest|behind|first|incomplete|died|flagged|shared]"],
                                                                   feature(function(rest) doSim(rest) end) },
    { "lock",        L["Lock the race HUD in place"],
                                                                   feature(function() doLock(true) end) },
    { "unlock",      L["Unlock the race HUD to move and resize it"],
                                                                   feature(function() doLock(false) end) },
}

--- Run one verb's handler by name: the launcher's Enabled entry reaches `enable`/`disable` through
--- here, so the menu and the verb are one handler (launcher-§2).
function NS.RunVerb(verb, rest)
    for _, entry in ipairs(NS.COMMANDS) do
        if entry[1] == verb then return entry[3](rest or "") end
    end
end

--- slash-commands-§2's thirteen reserved verbs: they answer while disabled. Named once, here, for the
--- library-absent stub's gate; the live dispatcher reads its own lib.LIVE_VERBS (pinned equal by
--- tests/test_slash.lua).
NS.SLASH_LIVE_VERBS = {
    help = true, config = true, version = true, enable = true, disable = true, debug = true,
    diagnostics = true, perf = true, get = true, set = true, list = true, reset = true, resetall = true,
}

local SlashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
local degraded = false

if not SlashLib then
    -- Degrade, never error: `/dr` is registered unconditionally, so something must answer it. The
    -- host verbs keep working; the schema CLI names the missing library. The ONE library string this
    -- stub carries is DISABLED_LINE_FORMAT, pinned by tests/test_slash.lua against the live major;
    -- every other line below is the stub's own plain wording, never a copy of the library's.
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
        stub.CliVersion = function() out(L["%s version %s"]:format(d.brandName, version())) end
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
            out(L["%s commands (reduced: the LibKa0s library is missing)"]:format(d.slash))
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
                if e[1] == verb then
                    -- The disabled gate the live dispatcher applies: a feature verb refuses with the
                    -- one line while the `disabled` hold is taken (slash-commands-§7).
                    if d.isEnabled and not d.isEnabled() and not NS.SLASH_LIVE_VERBS[verb] then
                        return out(stub.DisabledLine())
                    end
                    return e[3](rest or "")
                end
            end
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

--- A verb that writes one composed Master row (`enable`/`disable` the `enabled` row, `lock`/`unlock`
--- the `locked` row): through the seam, echoed by the CLI so the stored value is what the player reads
--- back (slash-commands-§2, §8). Degraded, the write goes through the seam's writeThrough list and is
--- acknowledged only if it landed (options-ui-§1); a written-through value runs no onChange, so the
--- caller's `react` stands in for it.
function doSetVerb(path, want, react)
    if not degraded and NS.FindSchemaRow(path) then
        cli:CliSet(path .. " " .. tostring(want))
        return
    end
    local ok, err = NS.SetByPath(path, want)
    if ok then
        if react then react(want) end
        out(L["%s = %s"]:format(path, tostring(want)))
    else
        out(tostring(err))
    end
end

function doEnabled(want)
    doSetVerb("enabled", want, NS.ApplyEnabled)
end

--- `lock` / `unlock`: the Lock frame row (slash-commands-§8).
function doLock(want)
    doSetVerb("locked", want, function(v) NS.Hud.SetLocked(v) end)
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

-- ── the feature verbs (spec §6.4) ─────────────────────────────────────────────────────────────────
-- Each reaches the race and the windows through the same handlers the HUD's buttons, the launcher and
-- the key bindings run (core/DpsRace.lua, modules/Hud.lua), never a copy. The dispatcher has already
-- refused them while disabled; a perf-held stand-down refuses inside those handlers.

--- `arm [length]`: the typed length ("90", "1:30", "3m"; 0:10 to 15:00) becomes the HUD's pick, as if
--- clicked, and is armed; with none, the HUD's own length (the last one raced, else the default).
function doArm(rest)
    local text = tostring(rest or ""):match("^%s*(.-)%s*$")
    if text ~= "" then
        local n = NS.Format.ParseLength(text)
        if not n or n < NS.Race.MIN_LENGTH or n > NS.Race.MAX_LENGTH then
            return out(NS.Format.ArmRefusal("bad_length"))
        end
        NS.Hud.Act.pickLength(n)
    end
    NS.Hud.Act.arm()
end

-- What `cancel` did, said in the state it found (Race.Cancel answers only whether it acted).
local CANCELED = {
    armed    = "Race canceled.",
    running  = "Race canceled: the run is deleted.",
    stopping = "Pending result discarded: the run is deleted.",
    result   = "Result closed. The run stays in your history.",
}

--- `cancel`: the armed or running race, or the run waiting for its result (spec §6.4).
function doCancel()
    local state = NS.Race.State()
    if not NS.Race.Cancel() then return out(L["Nothing to cancel."]) end
    out(L[CANCELED[state] or "Race canceled."])
end

local HUD_WORDS = { show = true, hide = true, toggle = true }

--- `hud show|hide|toggle`; a bare `hud` toggles.
function doHud(rest)
    local word = tostring(rest or ""):match("^%s*(%S*)"):lower()
    if word == "" then word = "toggle" end
    if not HUD_WORDS[word] then return out(L["Usage: %s hud show, %s hud hide or %s hud toggle"]:format(NS.SLASH, NS.SLASH, NS.SLASH)) end
    NS.SetHudShown(word)
end

--- `test [armed|running|result]`: a bare `test` turns test mode on or off; a state word holds that
--- HUD body still.
function doTest(rest)
    NS.ToggleTestMode(tostring(rest or ""):match("^%s*(%S*)"):lower())
end

--- `sim [scenario]`: a whole sample race; with no scenario, the default one.
function doSim(rest)
    NS.StartSim(tostring(rest or ""):match("^%s*(%S*)"):lower())
end

--- `results [bests]`.
function doResults(rest)
    local word = tostring(rest or ""):match("^%s*(%S*)"):lower()
    NS.ShowResults(word)
end

--- `target`: what the race would record about the current target (spec §4.6), so a new dummy can be
--- added to the catalog from a measurement.
function doTarget()
    if not (UnitExists and UnitExists("target")) then return out(L["No target."]) end
    local t = NS.Recorder.SnapshotTarget("target")
    local name = t.name or L["Unknown"]
    local creature = t.npcID and L["creature %d"]:format(t.npcID) or L["not a creature"]
    out(L["Target: %s \194\183 %s \194\183 category %s"]:format(name, creature, NS.Dummies.Label(t.category)))
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
