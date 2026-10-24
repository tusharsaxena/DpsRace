local _, NS = ...
-- modules/Results_Tips.lua — what the Results window's tables say on hover (the owner's call,
-- 2026-10-25): a tooltip for every cell, beside the window (modules/Results_Table.lua's SideTip), and
-- one for every column header, LootHistory's way (the column's name in gold, then what it shows).
--
-- PURE OVER THE STORED RUN. Each builder takes a run record and answers its lines, { title, line, ...
-- }, a line a string or { text, r, g, b }; nothing here reads a meter or a frame. A column may carry
-- its own `tip(run)` (the Runs list's v/s Max and Status, which need the view), which wins over the
-- builder here by its key.

local Tips = {}
NS.ResultsTips = Tips

local L = NS.L
local DASH = "\226\128\148"

local function Tbl() return NS.ResultsTable end
local function C() return NS.ResultsTable.COLORS end

-- A whole number with thousands separators: "36,812,345".
local function grouped(n)
    if type(n) ~= "number" then return DASH end
    local s = ("%d"):format(math.floor(n + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""):gsub("^%-,", "-"))
end
Tips.Grouped = grouped

local function result(run) return type(run.result) == "table" and run.result or {} end

-- ── one builder per column key ──────────────────────────────────────────────────────────────────

local CELL = {}

function CELL.date(run)
    local lines = { Tbl().Date(run.date, "%A %d %B %Y, %H:%M") }
    local stamp = {}
    if run.build then stamp[#stamp + 1] = L["build %s"]:format(tostring(run.build)) end
    if run.addon then stamp[#stamp + 1] = "v" .. tostring(run.addon) end
    if #stamp > 0 then lines[#lines + 1] = table.concat(stamp, " \194\183 ") end
    return lines
end

function CELL.icons(run)
    local char = run.char or {}
    local spec = Tbl().SpecInfo(char.specID, char.spec)
    local c = Tbl().ClassColor(char.class)
    local role = char.role and L["Role: %s"]:format(char.role:sub(1, 1) .. char.role:sub(2):lower()) or nil
    return { ("%s %s"):format(spec or L["Unknown spec"], Tbl().ClassName(char.class)),
             { L["Class color"], c[1], c[2], c[3] }, role }
end

function CELL.char(run)
    local char = run.char or {}
    local lines = { ("%s-%s"):format(tostring(char.name or "?"), tostring(char.realm or "?")) }
    local who = {}
    if char.level then who[#who + 1] = L["Level %d"]:format(char.level) end
    if char.race then who[#who + 1] = tostring(char.race) end
    who[#who + 1] = Tbl().ClassName(char.class)
    lines[#lines + 1] = table.concat(who, " ")
    local where = run.where or {}
    if where.zone then
        lines[#lines + 1] = where.subzone and where.subzone ~= "" and ("%s, %s"):format(where.zone, where.subzone)
            or where.zone
    end
    return lines
end

function CELL.ilvl(run)
    local char = run.char or {}
    local lines = { L["Item level %s"]:format(Tbl().Ilvl(char.ilvl)) }
    if type(char.ilvlOverall) == "number" and char.ilvlOverall ~= char.ilvl then
        lines[#lines + 1] = L["%s overall, counting bags"]:format(Tbl().Ilvl(char.ilvlOverall))
    end
    lines[#lines + 1] = L["Equipped, read when the race was armed."]
    return lines
end

function CELL.target(run)
    local t = run.target or {}
    local lines = { t.name or L["Unknown target"] }
    lines[#lines + 1] = NS.Dummies.Label(t.category)
    local meta = {}
    if type(t.level) == "number" then meta[#meta + 1] = L["Level %d"]:format(t.level) end
    if type(t.npcID) == "number" then meta[#meta + 1] = L["creature %d"]:format(t.npcID) end
    if #meta > 0 then lines[#lines + 1] = table.concat(meta, " \194\183 ") end
    if type(t.count) == "number" then
        lines[#lines + 1] = t.count == 1 and L["1 target (your pick)"] or L["%d targets (your pick)"]:format(t.count)
    end
    return lines
end

function CELL.time(run)
    local r, length = result(run), run.race and run.race.length
    local lines = { L["Race length %s"]:format(NS.Format.Length(length)) }
    if run.status == "incomplete" and type(r.endedAt) == "number" then
        lines[#lines + 1] = { L["Combat ended at %s, before the buzzer."]:format(NS.Format.Length(r.endedAt)),
                              C().orange[1], C().orange[2], C().orange[3] }
        return lines
    end
    if type(r.tail) == "number" then
        lines[#lines + 1] = L["Your damage kept landing %.1fs after the buzzer (DoTs, travel time). It counts."]:format(r.tail)
    end
    if type(r.combatEnd) == "number" then
        lines[#lines + 1] = L["Combat ended %.1fs after the buzzer."]:format(r.combatEnd)
    end
    return lines
end

function CELL.damage(run)
    local r = result(run)
    if run.status == "lost" then return { L["Lost"], L["The session could not be read: there is no score."] } end
    local lines = { L["%s damage"]:format(grouped(r.damage)) }
    if type(r.sessionDuration) == "number" then
        lines[#lines + 1] = L["Everything the meter's session held, read after combat (%ds)."]:format(r.sessionDuration)
    end
    return lines
end

function CELL.dps(run)
    local r = result(run)
    if run.status == "lost" then return { L["Lost"], L["The session could not be read: there is no score."] } end
    local lines = { L["%s DPS"]:format(grouped(r.dps)) }
    if run.status == "incomplete" then
        lines[#lines + 1] = L["Damage over the time in combat (%s). Incomplete runs never rank."]:format(
            NS.Format.Length(r.endedAt))
    else
        lines[#lines + 1] = L["Damage over the race length (%s), your clock."]:format(
            NS.Format.Length(run.race and run.race.length))
    end
    if type(r.meterDps) == "number" then
        lines[#lines + 1] = { L["Blizzard's meter said %s (over its whole session, idle time included)."]:format(
            grouped(r.meterDps)), 0.62, 0.62, 0.68 }
    end
    return lines
end

-- The Bests board's length and flags columns.
function CELL.length(run) return CELL.time(run) end

function CELL.flags(run)
    local texts = Tbl().FlagTexts(run)
    if #texts == 0 then return { L["Clean run"], L["No flags: nothing happened that the result should mention."] } end
    local lines = { #texts == 1 and L["1 flag"] or L["%d flags"]:format(#texts) }
    for _, t in ipairs(texts) do lines[#lines + 1] = t end
    lines[#lines + 1] = { L["Flags inform; they never void a run."], 0.62, 0.62, 0.68 }
    return lines
end

--- A cell's tooltip lines: the column's own `tip`, else the builder for its key, else nil.
--- @param col table
--- @param run table
--- @return table|nil
function Tips.Cell(col, run)
    local fn = col.tip or CELL[col.key]
    if not fn then return nil end
    local ok, lines = pcall(fn, run)
    if not ok or type(lines) ~= "table" then return nil end
    -- A builder may leave holes (an absent role): close them up.
    local out = {}
    for i = 1, 8 do if lines[i] ~= nil then out[#out + 1] = lines[i] end end
    return out
end

--- A group header's tooltip.
function Tips.Group(g)
    return { g.label, g.count == 1 and L["1 run"] or L["%d runs"]:format(g.count),
             { L["Click to fold or unfold the group."], 0.62, 0.62, 0.68 } }
end

-- ── the headers ─────────────────────────────────────────────────────────────────────────────────

local ABOUT = {
    date = "When the race started. Click to sort.",
    icons = "The character's class and spec.",
    char = "Who raced. Hover a name for the realm, race and where.",
    ilvl = "Equipped item level when the race was armed.",
    target = "The dummy type the race was against, from the dummy catalog. Unlisted targets are Other.",
    time = "The race length, then how long your damage kept landing after the buzzer (DoTs, travel time). An incomplete run shows its time in combat against the length.",
    length = "The race length the best was set at.",
    damage = "Your damage for the run, read from Blizzard's meter after combat. The bar runs from the smallest run in view to the largest.",
    dps = "Damage over the race length (over the time in combat for an incomplete run). The bar runs from the smallest run in view to the largest.",
    vsMax = "How far this run's DPS is from the highest complete run in view on the same target type.",
    status = "Max: the top run on its target type in view (when more than one spec is in view). Spec best: the best for its spec, target type and length. Complete, Flagged, Incomplete, Died or Lost otherwise.",
    flags = "What happened on the run that its result should mention: late casts, a restart, a reload.",
}

--- A header's tooltip: { title, text }, or nil for a column with nothing to say.
function Tips.About(col)
    local text = col.about or ABOUT[col.key]
    if not text then return nil end
    return { title = col.label, text = L[text] }
end
