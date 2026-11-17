local _, NS = ...
-- core/ChartsSetup.lua — NS.Charts from LibKa0s-Charts-1.0, and NS.ChartsHost(), the Results window's
-- look as that major's host table. modules/Results_Insights.lua draws through both.

--- The major, or nil without the library: there is no drawing stub (anti-pattern #73), so the Insights
--- tab keeps its filters and its count and says the charts are unavailable.
NS.Charts = LibStub and LibStub("LibKa0s-Charts-1.0", true)

-- A gold title over the lines, bulleted from two (Style.AddTipLines). A chart mark is a body element
-- (AD-92-DR): placed by the context's PlaceTip, beside the Results window, and the library's legacy
-- `anchor` is not read; with no context (an older Charts), Style.PlaceTip places it the same way. An
-- owner marked `tipChrome` (the Insights board tabs) is chrome: attached above it (Style.PlaceTip).
local function markTip(owner, lines, _, ctx)
    local tip = GameTooltip
    if not tip then return end
    local r, g, b = NS.Style.Rgb("gtip.title")
    tip:SetOwner(owner, "ANCHOR_NONE")
    tip:SetText(lines[1], r, g, b, 1, true)
    NS.Style.AddTipLines(tip, lines, 2)
    tip:Show()
    if type(owner) == "table" and owner.tipChrome then return NS.Style.PlaceTip(tip, owner, true) end
    if type(ctx) == "table" and type(ctx.PlaceTip) == "function" then return ctx:PlaceTip(tip, owner) end
    NS.Style.PlaceTip(tip, owner)
end

--- The host table for DpsRace's Results window: NS.Pool, the window's flat panel, its tooltip, its
--- colors (modules/Results_Table.lua's COLORS and the skin's chart tokens, every one a live skin
--- color) and font objects (modules/Style.lua's FONT), its labels painted through the skin
--- (Style.Paint: the skin's faces) and its textures through Style.Fill. The ranked palette is the
--- skin's `chart.series`, read at every draw. The meaning colors (class, category, length) are the
--- rows' own, chosen by the caller. No `owner`: every look here is named, so the window's own seams
--- keep drawing it, and Style's paint already follows a skin switch.
--- @return table
function NS.ChartsHost()
    local Style, Tbl = NS.Style, NS.ResultsTable
    local C, F = Tbl.COLORS, Style.FONT
    return {
        pool = NS.Pool,
        panel = function(parent) return Tbl.Panel(parent) end,
        tip = markTip,
        hideTip = Tbl.HideTip,
        text = Style.PlainText,
        paint = function(fs, c) Style.Paint(fs, c, nil, true) end,
        fill = Style.Fill,
        palette = function() return NS.Skin.Token("chart.series") end,
        colors = {
            body = C.text, value = C.text, muted = C.dim, heading = C.gold, caption = C.dim,
            rule = Style.Tok("section.rule"), bar = Style.Tok("dr.chart.bar"),
            track = Style.Tok("chart.track"), axis = Style.Tok("chart.axis"),
        },
        fonts = {
            label = F.TEXT, axis = F.CAPTION, heading = F.CHART, divider = F.SECTION,
            panelTitle = F.CHART, caption = F.CAPTION, figure = F.FIGURE,
        },
    }
end
