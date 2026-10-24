local _, NS = ...
-- settings/Hud.lua — the HUD page (the owner's call, 2026-10-25: the two HUD tabs off General onto a
-- page of their own, between Race and History). Two tabs, in registration order: Race HUD (what the
-- HUD shows and when, and the live breakdown) and HUD Appearance (its look). Same rows, same paths,
-- same defaults as when they sat on General.

local L = NS.L
local H = NS.Helpers
local PAGE = "hud"

-- ── Race HUD ────────────────────────────────────────────────────────────────────────────────────
-- The page's first tab (spec §6.3; on General until 2026-10-25), holding every HUD behavior: Display
-- (show the HUD on arm only or always, and its clock), then Live breakdown (what the running HUD lists
-- and how often it reads the meter; the Live breakdown page folded in here, item 020). The HUD's scale
-- and lock are General's Master controls rows: the HUD is the addon's positionable display.
local SHOW_MODES = { onArm = true, always = true }
local CLOCK_MODES = { both = true, left = true, elapsed = true }

NS.RegisterSchemaRows({
    { path = "hud.showMode", page = PAGE, group = L["Race HUD"], subgroup = L["Display"], type = "string",
      label = L["Show the race HUD"], default = NS.defaults.profile.hud.showMode,
      values = {
          { value = "onArm", text = L["When a race is armed"] },
          { value = "always", text = L["Always"] },
      },
      validate = function(v) return SHOW_MODES[v] == true end,
      tooltip = L["When a race is armed: the HUD opens when you arm a race or a result arrives, and closes again when that race is over. Always: it is open from login. General visibility on Master controls still applies: while it hides the addon, the HUD stays hidden whatever this says."],
      -- "always" opens it now; back to "onArm" leaves an open window open, as a player-opened one is.
      onChange = function(v)
          if v == "always" then NS.Hud.Show() end
      end },
    -- The running body's clock (spec §6.1); read on every redraw, so a redraw is the whole reaction.
    { path = "hud.clock", page = PAGE, group = L["Race HUD"], subgroup = L["Display"], type = "string",
      label = L["Race clock"], default = NS.defaults.profile.hud.clock,
      values = {
          { value = "both", text = L["Elapsed and time left"] },
          { value = "left", text = L["Time left"] },
          { value = "elapsed", text = L["Time elapsed"] },
      },
      validate = function(v) return CLOCK_MODES[v] == true end,
      tooltip = L["What the HUD's clock shows while the race runs: the time elapsed in green, the time left in red, or both side by side. The armed and stop screens keep their own."],
      onChange = function() NS.Hud.Refresh() end },
})

-- The live breakdown: each row is read when the HUD draws or reads, so a redraw is the whole
-- reaction: the next live read takes the new rate, and the rows and figures follow at once. Line 1 is
-- what the spell rows show, line 2 the live figure and how often it refreshes.
local LIVE = NS.defaults.profile.live
local function redraw() NS.Hud.Refresh() end

NS.RegisterSchemaRows({
    { path = "live.rows", page = PAGE, group = L["Race HUD"], subgroup = L["Live breakdown"], type = "number",
      min = 0, max = 15, step = 1, label = L["Spell rows shown"], default = LIVE.rows,
      tooltip = L["How many spells the running HUD lists, in the order Blizzard's meter gives them. 0 lists every spell: as many as fit the window show, and the mouse wheel scrolls through the rest."],
      onChange = redraw },
    { path = "live.icons", page = PAGE, group = L["Race HUD"], subgroup = L["Live breakdown"], type = "bool",
      label = L["Show spell icons"], default = LIVE.icons,
      tooltip = L["Draw each spell's icon on the HUD's rows."],
      onChange = redraw },
    { path = "live.showDps", page = PAGE, group = L["Race HUD"], subgroup = L["Live breakdown"], type = "bool",
      label = L["Show live DPS"], default = LIVE.showDps,
      tooltip = L["Show Blizzard's live DPS figure beside the damage while the race runs. Your score is damage divided by the race length."],
      onChange = redraw, startsLine = true },
    { path = "live.hz", page = PAGE, group = L["Race HUD"], subgroup = L["Live breakdown"], type = "number",
      min = 2, max = 10, step = 1, label = L["Live reads per second"], default = LIVE.hz,
      tooltip = L["How often the running HUD reads the meter while damage is landing. 2 to 10."],
      onChange = redraw },
})

-- ── HUD Appearance ──────────────────────────────────────────────────────────────────────────────
-- The HUD's look (the owner's call, 2026-10-24): its own tab after Race HUD, one subsection per styled
-- part, each a COMPOSED group (options-ui-§16: the canonical rows, the canonical words, never a
-- hand-written copy). The two clocks are two font blocks, because each has its own color; the spell
-- rows are a bar block with the row height appended after it, and a font block for their text. The
-- bars and the text style the Results window's breakdown too. Every row's reaction is the one
-- restyle (modules/Hud_Appearance.lua), read at CALL time.
local APPEARANCE = L["HUD Appearance"]
local AD = NS.defaults.profile.appearance
local function restyle() NS.HudAppearance.Changed() end
local PLAYER_CLASS = { source = "player" }

local function fontBlock(block, subgroup, order, tooltips)
    return H.FontGroup({
        prefix = "appearance." .. block .. ".", page = PAGE, group = APPEARANCE, subgroup = subgroup,
        order = order, classColor = PLAYER_CLASS, defaults = AD[block], tooltips = tooltips,
    })
end

local CLOCK_SIZE_TIP = { fontSize = L["Height of the clock, in points, when both clocks show. A clock shown alone draws half again as large."] }
local appearanceRows = {}
local function append(rows)
    for _, r in ipairs(rows) do appearanceRows[#appearanceRows + 1] = r end
end
append(fontBlock("elapsed", L["Elapsed clock"], 100, CLOCK_SIZE_TIP))
append(fontBlock("left", L["Time left clock"], 200, CLOCK_SIZE_TIP))
append(fontBlock("figures", L["Live figures"], 300))
append(H.BarGroup({
    prefix = "appearance.bars.", page = PAGE, group = APPEARANCE, subgroup = L["Spell bars"], order = 400,
    classColor = PLAYER_CLASS, defaults = AD.bars,
    extra = { {
        path = "appearance.bars.rowHeight", type = "number", min = 12, max = 30, step = 1,
        label = L["Row height"], default = AD.bars.rowHeight, startsLine = true,
        tooltip = L["The height of each spell row, in pixels, on the HUD and in the Results window's breakdown. Taller rows fit fewer spells in the same window."],
    } },
}))
append(fontBlock("spellText", L["Spell text"], 500))
for _, r in ipairs(appearanceRows) do
    r.onChange = restyle
    -- The library's words, not this addon's (options-ui-§21), except the appended row height.
    if r.path ~= "appearance.bars.rowHeight" then r.composed = true end
end
NS.RegisterSchemaRows(appearanceRows)

-- ── The page ────────────────────────────────────────────────────────────────────────────────────
NS.RegisterTabbedPage({
    key             = PAGE,
    title           = L["HUD"],
    panelName       = "DpsRaceHudPanel",
    defaultsTooltip = L["Restore every HUD setting on this profile to its addon default: the Race HUD tab (display and live breakdown) and HUD Appearance."],
})
