-- tests/run.lua — this addon's load list, lifecycle kick and suite list, on the vendored kit
-- (testing-§1). Run from the repo root: `lua tests/run.lua` (`--list` writes docs/test-cases.md).

local root = (arg and arg[0] and arg[0]:match("^(.*)/tests/run%.lua$")) or "."
package.path = root .. "/tests/?.lua;" .. package.path

local Kit     = dofile(root .. "/tests/_kit/framework.lua")
local Loader  = dofile(root .. "/tests/_kit/loader.lua")
local mockmod = assert(loadfile(root .. "/tests/wow_mock.lua"))(root)
-- The scripted C_DamageMeter (T2), built on the kit's secret wrappers.
local MockMeter = dofile(root .. "/tests/mock_meter.lua")(Kit)

Loader.addonName = "DpsRace"

-- The vendored library's files, read out of LibKa0s.xml in its own order rather than remembered:
-- omit one and its module refuses to register, the host takes its stub, and the suite measures the
-- stub -- green, and testing nothing (testing-§9). The floor list below fails loudly if the .xml
-- ever stops naming a module this addon consumes.
local LIB_FILES = Loader.xmlFiles(root .. "/libs/LibKa0s/LibKa0s.xml")
do
    local EXPECTED = {
        "Core.lua", "Env.lua", "Lifecycle.lua", "Bus.lua", "Schema.lua", "Pool.lua", "Media.lua",
        "Widgets.lua", "DebugLog.lua", "DebugLogDiagnostics.lua", "DebugLogGates.lua",
        "Slash.lua", "SlashParse.lua", "Launcher.lua",
        "Options.lua", "OptionsRegistry.lua", "OptionsWidgets.lua", "OptionsTabs.lua",
        "OptionsCombat.lua", "OptionsCompose.lua", "OptionsScroll.lua", "OptionsKeybinds.lua",
        "Perf.lua", "PerfSampler.lua", "PerfCommands.lua", "PerfPanel.lua",
    }
    local present = {}
    for _, path in ipairs(LIB_FILES) do present[path:match("([^/]+)$")] = true end
    local missing = {}
    for _, name in ipairs(EXPECTED) do
        if not present[name] then missing[#missing + 1] = name end
    end
    assert(#missing == 0, "libs/LibKa0s/LibKa0s.xml is missing " .. table.concat(missing, ", "))
end

-- The addon's own files come from the TOC, so this runner cannot drift from what the client loads.
local ADDON_FILES = Loader.tocFiles(root .. "/DpsRace.toc")

local function rooted(list)
    local out = {}
    for i, rel in ipairs(list) do out[i] = root .. "/" .. rel end
    return out
end

--- One isolated instance: a fresh mock, a fresh NS, the client's lifecycle.
---   opts.libFiles  the LibKa0s files to load ({} = the library-absent load)
---   opts.mutate    function(mocks) run before anything loads
---   opts.init      false = load the files only (no OnInitialize)
---   opts.enable    false = initialize but do not enable
local function loadInstance(opts)
    opts = opts or {}
    local mocks = mockmod.build()
    if opts.mutate then opts.mutate(mocks) end
    -- `_G` inside a loaded chunk is the mocked environment, as in the client it is the one global table.
    mocks._G = Loader.makeEnv(mocks)
    _G.DpsRaceDB, _G.DpsRacePerfDB = nil, nil
    local NS = {}
    Loader.loadAll(opts.libFiles or LIB_FILES, NS, mocks)
    Loader.loadAll(rooted(ADDON_FILES), NS, mocks)
    if opts.init ~= false then
        local AceAddon = mocks.LibStub("AceAddon-3.0")
        AceAddon:InitializeAddon(NS)                 -- OnInitialize: DB, migrations, latch, panel
        if opts.enable ~= false then
            AceAddon:EnableAddon(NS)                 -- OnEnable: the game events
            if mocks.__fireTimers then mocks.__fireTimers() end
        end
    end
    return { NS = NS, mocks = mocks }
end

local shared = loadInstance()

local SUITES = {
    "test_skeleton",
    "test_secrets",
    "test_meter",
    "test_dummies",
    "test_recorder",
    "test_timeline",
    "test_scoring",
    "test_bests",
    "test_race",
    "test_race_resume",
    "test_format",
    "test_hud",
    "test_chart",
    "test_pace",
    "test_countdown",
    "test_layers",
    "test_results",
    "test_results_fit",
    "test_results_group",
    "test_results_delta",
    "test_results_tree",
    "test_results_badges",
    "test_compare",
    "test_loadout",
    "test_casts",
    "test_usage",
    "test_results_usage",
    "test_chart_icons",
    "test_results_timeline",
    "test_schema",
    "test_settings",
    "test_slash",
    "test_share",
    "test_preview",
    "test_sim",
    "test_launcher",
    "test_keybinds",
    "test_disabled",
    "test_surface_parity",
    "test_perf_harness",
    "test_loadorder",
    "test_vendor_sync",
    { name = "test_eol", dir = "tests/_kit/" },
    { name = "test_prose", dir = "tests/_kit/" },
    { name = "test_layout_cap", dir = "tests/_kit/" },
    { name = "test_diagnostics_contract", dir = "tests/_kit/" },
    { name = "test_lizard_sighted", dir = "tests/_kit/" },
}

-- The diagnostics contract runs against THIS addon's dispatcher (debug-logging-§14).
local contractInst
local function contract()
    contractInst = contractInst or loadInstance()
    return contractInst
end
Kit.diagnostics = {
    brand       = "Ka0s DPS Race",
    dispatch    = function(line) contract().NS.Slash:OnSlash(line) end,
    console     = function() return contract().NS.DebugLog end,
    setDebug    = function(on) contract().NS.State.debug = on and true or false end,
    setDisabled = function(off) contract().NS.SetByPath("enabled", not off) end,
}

-- The degradation stubs that mirror an INSTANCE rather than a library table are compared against
-- that instance (testing-§8).
Kit.setSurfaceSource{
    ["LibKa0s-Options-1.0"] = shared.NS.Helpers,
    ["LibKa0s-Bus-1.0"]     = shared.mocks.LibStub("LibKa0s-Bus-1.0", true),
}

_G.DPSRACE_TEST = Kit.expose{
    root             = root,
    NS               = shared.NS,
    mocks            = shared.mocks,
    load             = loadInstance,
    libFiles         = LIB_FILES,
    loadedAddonFiles = ADDON_FILES,
    Loader           = Loader,
    mockMeter        = MockMeter,
    secret           = Kit.secret,
    isSecret         = Kit.isSecret,
    reveal           = Kit.reveal,
    installSecretValue = Kit.installSecretValue,
}

Kit.run{ dir = root .. "/tests/", suites = SUITES }
