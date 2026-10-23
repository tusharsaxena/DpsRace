local _, NS = ...
-- settings/Live.lua — the Live breakdown page (spec §6.3): how many spells the running HUD lists, how
-- often it reads the meter, and whether it shows spell icons and Blizzard's live DPS.

local L = NS.L
local D = NS.defaults.profile.live
local PAGE = "live"
local GROUP = L["Live breakdown"]

-- Each row is read when the HUD draws or reads, so a redraw is the whole reaction: the next live read
-- takes the new rate, and the rows and figures follow at once.
local function redraw() NS.Hud.Refresh() end

NS.RegisterSchemaRows({
    { path = "live.rows", page = PAGE, group = GROUP, subgroup = L["Rows"], type = "number",
      min = 3, max = 15, step = 1, label = L["Rows shown"], default = D.rows,
      tooltip = L["How many spells the running HUD lists, in the order Blizzard's meter gives them. 3 to 15."],
      onChange = redraw },
    { path = "live.hz", page = PAGE, group = GROUP, subgroup = L["Rows"], type = "number",
      min = 2, max = 10, step = 1, label = L["Live reads per second"], default = D.hz,
      tooltip = L["How often the running HUD reads the meter while damage is landing. 2 to 10."],
      onChange = redraw },
    { path = "live.icons", page = PAGE, group = GROUP, subgroup = L["Display"], type = "bool",
      label = L["Show spell icons"], default = D.icons,
      tooltip = L["Draw each spell's icon on the HUD's rows."],
      onChange = redraw, startsLine = true },
    { path = "live.showDps", page = PAGE, group = GROUP, subgroup = L["Display"], type = "bool",
      label = L["Show live DPS"], default = D.showDps,
      tooltip = L["Show Blizzard's live DPS figure beside the damage while the race runs. Your score is damage divided by the race length."],
      onChange = redraw },
})

NS.RegisterTabbedPage({
    key             = PAGE,
    title           = L["Live breakdown"],
    panelName       = "DpsRaceLivePanel",
    defaultsTooltip = L["Restore every Live breakdown setting on this profile to its addon default."],
})
