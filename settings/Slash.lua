local _, NS = ...
-- settings/Slash.lua — the ordered NS.COMMANDS table and the LibKa0s-Slash-1.0 descriptor; `/dr` and
-- `/dpsrace` both reach the one dispatcher.

NS.Slash = NS.Slash or {}
local Sl = NS.Slash
local L = NS.L

local function out(line) NS.Print(line) end

local cli   -- built at the bottom, once NS.COMMANDS exists; handlers reach it at CALL time
local doEnabled, doDebug, doPerf, doSetVerb
local doArm, doCancel, doHud, doResults, doTarget, doLock, doTest, doSim, doIgnore, doTargetDummy

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
    -- The reserved `skin` verb (LibKa0s v1.82.0's O.SkinVerb, ruling D-16), right after `config`: the
    -- skin picker a new profile shows, on demand (core/SkinSetup.lua's NS.RunSkinVerb). Not a live
    -- verb, so the dispatcher refuses it while disabled; behind feature() for the perf hold's line.
    { "skin",        L["Choose a skin: open the skin picker"],     feature(function() NS.RunSkinVerb() end) },
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
    { "results",     L["Open the Results window; /dr results insights opens Insights"],
                                                                   feature(function(rest) doResults(rest) end) },
    { "target",      L["Print your target's name, creature ID and category"],
                                                                   feature(function() doTarget() end) },
    { "test",        L["Sample data in the HUD and the Results window: /dr test [armed|running|result]"],
                                                                   feature(function(rest) doTest(rest) end) },
    -- The scenario list comes from modules/Sim.lua (loaded before settings/), so the help line follows it.
    { "sim",         L["Play a whole sample race: /dr sim [%s]"]:format(table.concat(NS.Sim.Names(), "|")),
                                                                   feature(function(rest) doSim(rest) end) },
    { "lock",        L["Lock the race HUD in place"],
                                                                   feature(function() doLock(true) end) },
    { "unlock",      L["Unlock the race HUD to move and resize it"],
                                                                   feature(function() doLock(false) end) },
    -- A settings verb over one row, the late-cast ignore list (#8): not behind feature(), and live
    -- while disabled (HOST_LIVE_VERBS below), as the schema CLI that writes the same row is.
    { "ignore",      L["The late-cast ignore list: /dr ignore [show|add|remove|defaults] <spell ID, link or name>"],
                                                                   function(rest) doIgnore(rest) end },
    -- Your training dummies (#9): a settings verb like `ignore` (the list is one row), live while
    -- disabled. `add` and `capture` read the target and save what the game says about it.
    { "targetdummy", L["Your training dummies: /dr targetdummy [show|add|remove|capture|defaults] [category or creature ID]"],
                                                                   function(rest) doTargetDummy(rest) end },
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

--- The host verbs that also answer while disabled, on BOTH arms: the descriptor's `liveVerbs` below
--- (the library's LIVE_VERBS plus these) and the library-absent stub's gate. `ignore` reads and writes
--- one setting, as `get`/`set` do, so the addon declines slash-commands-§2's feature-verb refusal for
--- it: a player reads and repairs settings while the addon is off.
local HOST_LIVE_VERBS = { "ignore", "targetdummy" }
local HOST_LIVE = {}
for _, verb in ipairs(HOST_LIVE_VERBS) do HOST_LIVE[verb] = true end

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
                    if d.isEnabled and not d.isEnabled() and not NS.SLASH_LIVE_VERBS[verb]
                        and not HOST_LIVE[verb] then
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

-- The live set: the library's reserved verbs, then this addon's own. The stub has no LIVE_VERBS and
-- reads NS.SLASH_LIVE_VERBS and HOST_LIVE_VERBS itself.
local liveVerbs = {}
for i, verb in ipairs(SlashLib.LIVE_VERBS or {}) do liveVerbs[i] = verb end
for _, verb in ipairs(HOST_LIVE_VERBS) do liveVerbs[#liveVerbs + 1] = verb end
Sl.LIVE_VERBS = liveVerbs

cli = SlashLib:New({
    slash        = NS.SLASH,
    slashAliases = { NS.SLASH_LONG },
    commands     = NS.COMMANDS,                       -- passed IN, never owned by the library
    aliases      = { options = "config" },
    -- The disabled gate: every verb not on the library's live list answers the one refusal line
    -- while the `disabled` hold is taken (slash-commands-§2, §7). Not IsStoodDown: the `perf` hold
    -- alone must not print the disabled line.
    isEnabled    = function() return not NS.IsDisabled() end,
    liveVerbs    = liveVerbs,
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

--- `results [insights]` (and the silent "bests" alias: core/DpsRace.lua NS.ShowResults).
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

-- ── `ignore`: the late-cast ignore list (#8, modules/LateIgnore.lua) ─────────────────────────────
-- Every write goes through LateIgnore, so through the seam: the row's validate and normalize, and
-- SETTINGS_CHANGED for the caches and the Race page.

local function ignoreUsage()
    out(L["Usage: %s ignore [show|add|remove|defaults] <spell ID, link or name>"]:format(NS.SLASH))
end

local function showIgnored()
    local ids = NS.LateIgnore.List()
    if #ids == 0 then return out(L["The late-cast ignore list is empty."]) end
    out(L["Late-cast ignore list:"])
    for _, id in ipairs(ids) do out("  " .. NS.LateIgnore.Label(id)) end
end

-- What a typed spell is, or nil after the one line that says why (none typed: the usage).
local function typedSpell(text)
    local id, reason = NS.LateIgnore.Resolve(text)
    if id then return id end
    if reason == "empty" then return ignoreUsage() end
    if reason == "ambiguous" then
        return out(L["More than one spell is named '%s'. Use its spell ID or a shift-clicked link."]:format(text))
    end
    out(L["No spell named '%s' is known. Use its spell ID or a shift-clicked link."]:format(text))
end

local IGNORE_VERBS = {
    show = showIgnored,
    add = function(text)
        local LI, id = NS.LateIgnore, typedSpell(text)
        if not id then return end
        if LI.IsIgnored(id) then return out(L["%s is already ignored."]:format(LI.Label(id))) end
        if LI.Ignore(id) then out(L["Late casts of %s no longer flag a run."]:format(LI.Label(id))) end
    end,
    remove = function(text)
        local LI, id = NS.LateIgnore, typedSpell(text)
        if not id then return end
        -- A variant ignored through 8690 takes 8690 off, so the line names what was removed.
        local covering = LI.Covering(id)
        if not covering then return out(L["%s is not on the list."]:format(LI.Label(id))) end
        if LI.Unignore(id) then out(L["Late casts of %s flag a run again."]:format(LI.Label(covering))) end
    end,
    defaults = function()
        if NS.LateIgnore.Reset() then out(L["The late-cast ignore list is back to its defaults."]) end
        showIgnored()
    end,
}

--- `ignore [show|add|remove|defaults] <spell>`; a bare `ignore` shows the list.
function doIgnore(rest)
    local word, text = tostring(rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
    word = word:lower()
    if word == "" then word = "show" end
    local fn = IGNORE_VERBS[word]
    if not fn then return ignoreUsage() end
    fn(text)
end

-- ── `targetdummy`: your training dummies (#9, modules/DummyList.lua) ─────────────────────────────
-- Every list write goes through DummyList, so through the seam; a capture goes to the global store.

local function dummyUsage()
    out(L["Usage: %s targetdummy [show|add|remove|capture|defaults] [category or creature ID]"]:format(NS.SLASH))
end

-- "Angry Boar (99999)", or "Creature 99999" when it was never captured and is no built-in.
local function dummyName(id)
    local name = NS.DummyList.NameOf(id)
    if name then return L["%s (%d)"]:format(name, id) end
    return L["Creature %d"]:format(id)
end

-- The capture as one line: what the game said, then where.
-- The capture's level part ("level 70 elite", "skull level"), or nil with no level.
local function captureLevel(r)
    if not r.level then return nil end
    local lvl = r.level == -1 and L["skull level"] or L["level %d"]:format(r.level)
    if r.classification and r.classification ~= "normal" then
        return L["%s %s"]:format(lvl, r.classification)
    end
    return lvl
end

-- The capture's place part ("Zone, Subzone 12.3, 45.6"), or nil with no zone.
local function captureWhere(r)
    local where = r.subzone and r.subzone ~= "" and r.zone and L["%s, %s"]:format(r.zone, r.subzone) or r.zone
    if where and r.x and r.y then where = L["%s %.1f, %.1f"]:format(where, r.x, r.y) end
    return where
end

local function captureLine(r)
    local parts = { dummyName(r.npcID) }
    local function add(part) if part then parts[#parts + 1] = part end end
    add(captureLevel(r))
    if r.health then add(L["%s health"]:format(NS.Format.Number(r.health))) end
    add(r.creatureType)
    if r.pvp ~= nil then add(r.pvp and L["PvP flagged"] or L["not PvP flagged"]) end
    add(captureWhere(r))
    return table.concat(parts, " \194\183 ")
end

-- The target as a creature, captured, or nil after the one line that says why.
local function capturedTarget()
    if not (UnitExists and UnitExists("target")) then return out(L["Target a creature first."]) end
    local r = NS.DummyList.Read("target")
    if not r then return out(L["Your target is not a creature, so it cannot be a training dummy."]) end
    NS.DummyList.Capture(r)
    return r
end

local function showDummies()
    local own, off = {}, {}
    for _, e in ipairs(NS.DummyList.Entries()) do
        if e.hidden then off[#off + 1] = e else own[#own + 1] = e end
    end
    local builtIn = 0
    for _ in pairs(NS.Dummies.BY_ID) do builtIn = builtIn + 1 end
    if #own == 0 then
        out(L["No training dummies of your own. Target one and type %s targetdummy add."]:format(NS.SLASH))
    else
        out(L["Your training dummies:"])
        for _, e in ipairs(own) do out(L["  %s \194\183 %s"]:format(dummyName(e.id), NS.Dummies.Label(e.category))) end
    end
    out(L["Built-in training dummies: %d, %d switched off."]:format(builtIn, #off))
    for _, e in ipairs(off) do out(L["  %s (off)"]:format(dummyName(e.id))) end
end

local DUMMY_VERBS = {
    show = showDummies,
    capture = function()
        local r = capturedTarget()
        if r then out(L["Saved: %s"]:format(captureLine(r))) end
    end,
    add = function(word)
        local DL = NS.DummyList
        if word ~= "" and not DL.CategoryWord(word) and word:lower() ~= "auto" then
            return out(L["'%s' is no category. Use single, cleave, dungeoneer, boss or pvp."]:format(word))
        end
        local r = capturedTarget()
        if not r then return end
        local category = DL.CategoryFor(r, word)
        local outcome, name = DL.Add(r.npcID, category), dummyName(r.npcID)
        out(L["Saved: %s"]:format(captureLine(r)))
        local d = NS.Dummies.Lookup(r.npcID)
        local label = NS.Dummies.Label(d and d.category or category)
        if outcome == "added" or outcome == "changed" then
            out(L["%s is a training dummy now: %s."]:format(name, label))
        elseif outcome == "restored" then
            out(L["%s is a training dummy again: %s."]:format(name, label))
        elseif NS.Dummies.BuiltIn(r.npcID) then
            out(L["%s is already a built-in training dummy: %s."]:format(name, label))
        else
            out(L["%s is already a training dummy: %s."]:format(name, label))
        end
    end,
    remove = function(text)
        local DL, id = NS.DummyList
        if text ~= "" then
            id = DL.Resolve(text)
            if not id then return out(L["No creature '%s' is known. Use its creature ID."]:format(text)) end
        else
            if not (UnitExists and UnitExists("target")) then return dummyUsage() end
            id = NS.Recorder.NpcIDOf("target")
            if not id then return out(L["Your target is not a creature, so it cannot be a training dummy."]) end
        end
        local outcome = DL.Remove(id)
        if outcome == "removed" then
            out(L["%s is no longer a training dummy."]:format(dummyName(id)))
        elseif outcome == "hidden" then
            out(L["%s, a built-in training dummy, is switched off. %s targetdummy add on it brings it back."]:format(dummyName(id), NS.SLASH))
        else
            out(L["%s is not a training dummy."]:format(dummyName(id)))
        end
    end,
    defaults = function()
        if NS.DummyList.Reset() then out(L["Your training dummies are cleared: only the built-in ones count."]) end
        showDummies()
    end,
}

--- `targetdummy [show|add|remove|capture|defaults] [category or creature ID]`; a bare verb shows the list.
function doTargetDummy(rest)
    local word, text = tostring(rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
    word = word:lower()
    if word == "" then word = "show" end
    local fn = DUMMY_VERBS[word]
    if not fn then return dummyUsage() end
    fn(text)
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
