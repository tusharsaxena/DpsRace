local _, NS = ...
-- settings/Hud.lua — the HUD page (the owner's call, 2026-10-25: the two HUD tabs off General onto a
-- page of their own, between Race and History). Two tabs, in registration order: Race HUD (what the
-- HUD shows and when, the live breakdown, the damage chart and the pace bar) and HUD Appearance (its
-- look). Same rows, same paths, same defaults as when they sat on General.

local L = NS.L
local H = NS.Helpers
local PAGE = "hud"

-- ── Race HUD ────────────────────────────────────────────────────────────────────────────────────
-- The page's first tab (spec §6.3; on General until 2026-10-25), holding every HUD behavior: Display
-- (show the HUD on arm only or always, and its clock), then Live breakdown (what the running HUD lists
-- and how often it reads the meter; the Live breakdown page folded in here, item 020), then Chart and
-- pace (#2, #3). The HUD's scale
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
    -- Auto-show (#16, modules/AutoArm.lua): its own line under the two dropdowns.
    { path = "hud.autoShow", page = PAGE, group = L["Race HUD"], subgroup = L["Display"], type = "bool",
      label = L["Show near a training dummy"], default = NS.defaults.profile.hud.autoShow, startsLine = true,
      tooltip = L["Open the HUD by itself while a known training dummy is your target or its nameplate is up, and close it again a few seconds after none is, unless a race or its result holds it. If you close it yourself, it stays closed until you leave the dummies. Not in instances. With nameplates off, only your target counts."],
      onChange = function() NS.AutoArm.Sync() end },
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

-- The damage chart (#2) and the pace bar (#3) on the running HUD: read on every redraw, so a redraw is
-- the whole reaction. Their look is HUD Appearance > Damage chart, Chart background and Pace bar. The
-- cooldown icons (#14) ride on the chart, there and in the Results window, so theirs redraws both.
local function redrawCooldowns()
    redraw()
    if NS.Results and NS.Results.Refresh then NS.Results.Refresh() end
end
NS.RegisterSchemaRows({
    { path = "live.chart", page = PAGE, group = L["Race HUD"], subgroup = L["Chart and pace"], type = "bool",
      label = L["Show damage chart"], default = LIVE.chart,
      tooltip = L["Draw your damage over the race as columns under the live figures, scaled to the best on this board (with its average pace as a faint line) or, with no best yet, to your damage so far. Hidden when the pull carried an earlier fight's session. The result card and the Results window show it again for races run since your last reload or login."],
      onChange = redraw },
    { path = "live.castDots", page = PAGE, group = L["Race HUD"], subgroup = L["Chart and pace"], type = "bool",
      label = L["Show cooldown icons"], default = LIVE.castDots,
      tooltip = L["Mark each cast of an ability with a cooldown of 29 seconds or more (your big cooldowns, trinkets and potions) with its icon along the top of the damage chart: live on the HUD, on the result card and in the Results window. Hover an icon for the spell and its time."],
      onChange = redrawCooldowns },
    { path = "live.paceBar", page = PAGE, group = L["Race HUD"], subgroup = L["Chart and pace"], type = "bool",
      label = L["Show pace bar"], default = LIVE.paceBar,
      tooltip = L["Draw a bar under the live figures against the best on this board: its tick is the best's average pace at this moment of the race. The result card shows it again after the race, your final damage against the best before the run. Hidden with no best yet, and when the pull carried an earlier fight's session."],
      onChange = redraw },
    { path = "live.paceRange", page = PAGE, group = L["Race HUD"], subgroup = L["Chart and pace"], type = "number",
      min = 1.1, max = 2.0, step = 0.05, label = L["Pace bar range"], default = LIVE.paceRange, startsLine = true,
      tooltip = L["How far either side of the best's pace the bar reaches: 1.5 = \194\17750%, empty at half the best's damage by now and full at half again. The tick in the middle is the best's pace. 1.1 to 2.0."],
      onChange = redraw },
})

-- ── HUD Appearance ──────────────────────────────────────────────────────────────────────────────
-- The HUD's look (the owner's call, 2026-10-24): its own tab after Race HUD, one subsection per styled
-- part, each a COMPOSED group (options-ui-§16: the canonical rows, the canonical words, never a
-- hand-written copy). The two clocks are two font blocks, because each has its own color; the spell
-- rows are a bar block with the row height appended after it, and a font block for their text. The
-- bars and the text style the Results window's breakdown too. Every row's reaction is the one
-- restyle (modules/Hud_Appearance.lua), read at CALL time.
--
-- FOLLOWING THE SKIN (skinning-§6, DR-03): every block but the two clocks takes the composer's
-- `fromSkin = true`, which appends its "Use the skin's font" / "Use the skin's texture" companion on a
-- line of its own, default on (defaults/Profile.lua, X3). While it is on the picker is disabled and
-- shows the skin's value; the stored pick waits for the player to turn it off. The clocks keep their
-- monospace face with no companion (D-15). Colors never follow the skin (X4). Every font block,
-- the clocks too, takes `flagsFromSkin` (LibKa0s v1.82.0, D-07): its Font flags row leads with
-- *From skin*, the default, which draws the Skin tab's Font outline.
local APPEARANCE = L["HUD Appearance"]
local AD = NS.defaults.profile.appearance
local function restyle() NS.HudAppearance.Changed() end
local PLAYER_CLASS = { source = "player" }

local function fontBlock(block, subgroup, order, tooltips, fromSkin)
    return H.FontGroup({
        prefix = "appearance." .. block .. ".", page = PAGE, group = APPEARANCE, subgroup = subgroup,
        order = order, classColor = PLAYER_CLASS, defaults = AD[block], tooltips = tooltips,
        fromSkin = fromSkin, flagsFromSkin = true,
    })
end

local CLOCK_SIZE_TIP = { fontSize = L["Height of the clock, in points, when both clocks show. A clock shown alone draws half again as large."] }
local appearanceRows = {}
local function append(rows)
    for _, r in ipairs(rows) do appearanceRows[#appearanceRows + 1] = r end
end
append(fontBlock("elapsed", L["Elapsed clock"], 100, CLOCK_SIZE_TIP))
append(fontBlock("left", L["Time left clock"], 200, CLOCK_SIZE_TIP))
append(fontBlock("figures", L["Live figures"], 300, nil, true))
append(H.BarGroup({
    prefix = "appearance.bars.", page = PAGE, group = APPEARANCE, subgroup = L["Spell bars"], order = 400,
    classColor = PLAYER_CLASS, defaults = AD.bars, fromSkin = true,
    extra = { {
        path = "appearance.bars.rowHeight", type = "number", min = 12, max = 30, step = 1,
        label = L["Row height"], default = AD.bars.rowHeight, startsLine = true,
        tooltip = L["The height of each spell row, in pixels, on the HUD and in the Results window's breakdown. Taller rows fit fewer spells in the same window."],
    } },
}))
append(fontBlock("spellText", L["Spell text"], 500, nil, true))
-- The damage chart's columns (#2): a bar block with the plot's height and the column gap after it
-- (a bar spacing, appended after the mandated four, options-ui-§16).
append(H.BarGroup({
    prefix = "appearance.chart.", page = PAGE, group = APPEARANCE, subgroup = L["Damage chart"], order = 600,
    classColor = PLAYER_CLASS, defaults = AD.chart, fromSkin = true,
    extra = { {
        path = "appearance.chart.height", type = "number", min = 40, max = 160, step = 2,
        label = L["Chart height"], default = AD.chart.height, startsLine = true,
        tooltip = L["The height of the damage chart's plot, in pixels, on the HUD and in the Results window. A taller chart leaves fewer spell rows in the same window; when even three rows would not fit, the chart steps aside."],
    }, {
        path = "appearance.chart.columnGap", type = "number", min = 0, max = 3, step = 1,
        label = L["Column gap"], default = AD.chart.columnGap,
        tooltip = L["The space between two of the damage chart's columns, in pixels. 0 draws them as one smooth area."],
    } },
}))
-- The chart plot's background: a backdrop with no fill texture, so a swatch and its class-color
-- companion and nothing else (options-ui-§16, §17), under a heading of its own.
append(H.ColorPair({
    prefix = "appearance.chart.", page = PAGE, group = APPEARANCE, subgroup = L["Chart background"], order = 700,
    key = "bgColor", companionKey = "useClassColorBg", label = L["Background color"],
    classColor = PLAYER_CLASS,
    defaults = { bgColor = AD.chart.bgColor, useClassColorBg = AD.chart.useClassColorBg },
}))
-- The pace bar (#3), its own bar block since 2026-10-25: styling the chart's columns no longer
-- restyles it.
append(H.BarGroup({
    prefix = "appearance.pace.", page = PAGE, group = APPEARANCE, subgroup = L["Pace bar"], order = 800,
    classColor = PLAYER_CLASS, defaults = AD.pace, fromSkin = true,
}))
-- The appended rows, in the addon's own words; every other row is the library's.
local OWN_WORDS = { ["appearance.bars.rowHeight"] = true, ["appearance.chart.height"] = true,
                    ["appearance.chart.columnGap"] = true }
for _, r in ipairs(appearanceRows) do
    r.onChange = restyle
    -- The library's words, not this addon's (options-ui-§21), except the appended rows.
    if not OWN_WORDS[r.path] then r.composed = true end
end
NS.RegisterSchemaRows(appearanceRows)

-- ── The page ────────────────────────────────────────────────────────────────────────────────────
NS.RegisterTabbedPage({
    key             = PAGE,
    title           = L["HUD"],
    panelName       = "DpsRaceHudPanel",
    defaultsTooltip = L["Restore every HUD setting on this profile to its addon default: the Race HUD tab (display, live breakdown, chart and pace) and HUD Appearance."],
})
