local _, NS = ...
-- modules/Results_Tips.lua — what the Results window's tables say on hover (the owner's call,
-- 2026-10-25): a tooltip for every cell, beside the window (modules/Results_Table.lua's SideTip), and
-- one for every column header, LootHistory's way (the column's name in gold, then what it shows).
--
-- PURE OVER THE STORED RUN. Each builder takes a run record and answers its lines, { title, line, ...
-- }, a line a string or { text, r, g, b }; nothing here reads a meter or a frame. A column may carry
-- its own `tip(run)` (the Runs list's Delta and Status, which need the view), which wins over the
-- builder here by its key.

local Tips = {}
NS.ResultsTips = Tips

local L = NS.L
local DASH = "\226\128\148"

local function Tbl() return NS.ResultsTable end
local function C() return NS.ResultsTable.COLORS end
local function Detail() return NS.ResultsDetail end

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

-- The Spec cell's loadout lines (#6): the talents it ran, and whether the gear changed since the same
-- character's previous run on the spec. A run from before #6 says it has none.
local function loadoutLines(run, lines)
    if type(run.loadout) ~= "table" then
        lines[#lines + 1] = { L["Gear and talents: not recorded"], 0.62, 0.62, 0.68 }
        return
    end
    local _, talents = NS.ResultsSource.LoadoutOf(run)
    if talents then lines[#lines + 1] = L["Talents: %s"]:format(NS.ResultsLoadout.TalentsText(talents)) end
    local changed = NS.ResultsSource.GearChanged(run)
    if changed then lines[#lines + 1] = { L["Gear changed since the previous run"], C().amber[1], C().amber[2], C().amber[3] } end
end

function CELL.icons(run)
    local char = run.char or {}
    local spec = Tbl().SpecInfo(char.specID, char.spec)
    local c = Tbl().ClassColor(char.class)
    local role = char.role and L["Role: %s"]:format(char.role:sub(1, 1) .. char.role:sub(2):lower()) or nil
    local lines = { ("%s %s"):format(spec or L["Unknown spec"], Tbl().ClassName(char.class)),
                    { L["Class color"], c[1], c[2], c[3] } }
    if role then lines[#lines + 1] = role end
    loadoutLines(run, lines)
    return lines
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

-- What a run used (#13): each entry's name and when (modules/Results_Usage.lua).
function CELL.used(run)
    local U = NS.ResultsUsage
    local entries = U.Entries(run)
    if not entries then
        return { L["Not recorded"], L["This run was raced before the addon recorded what was used."] }
    end
    if #entries == 0 then
        return { L["Nothing used"], L["No on-use item or consumable was detected or ticked for this run."] }
    end
    local lines = { #entries == 1 and L["1 item used"] or L["%d items used"]:format(#entries) }
    for _, e in ipairs(entries) do lines[#lines + 1] = L["%s: %s"]:format(U.Name(e), U.Detail(e)) end
    lines[#lines + 1] = { L["Edit the list in the run's detail."], 0.62, 0.62, 0.68 }
    return lines
end

-- A builder's lines with any hole (an absent role) closed up, however many there are.
local function compact(lines)
    local top = 0
    for k in pairs(lines) do
        if type(k) == "number" and k > top then top = k end
    end
    local out = {}
    for i = 1, top do if lines[i] ~= nil then out[#out + 1] = lines[i] end end
    return out
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
    return compact(lines)
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
    time = "The race length, then how long your damage kept landing after the buzzer (DoTs, travel time). An incomplete run shows when combat ended instead. Each preset length has its own color.",
    length = "The race length the best was set at. Each preset length has its own color.",
    damage = "Your damage for the run, read from Blizzard's meter after combat. The bar runs from the smallest run in its group to the largest (with no grouping, the whole view).",
    dps = "Damage over the race length (over the time in combat for an incomplete run). The bar runs from the smallest run in its group to the largest (with no grouping, the whole view).",
    delta = "How far this run's DPS is from the highest complete run in its group (with no grouping, the whole view). Recomputed whenever the filters or the grouping change.",
    status = "Spec best: the best for its spec, target type and length, which its tooltip names. Complete, Flagged, Incomplete, Died or Lost otherwise.",
    flags = "What happened on the run that its result should mention: late casts, a restart, a reload.",
    used = "What the run used: on-use gear (trinkets first), then potions, flasks, food and the rest. Hover for when; sorted by how many.",
    note = "The note you kept with the run. Click to sort.",
}

--- A header's tooltip: { title, text }, or nil for a column with nothing to say.
function Tips.About(col)
    local text = col.about or ABOUT[col.key]
    if not text then return nil end
    return { title = col.label, text = L[text] }
end

-- ── the run detail ──────────────────────────────────────────────────────────────────────────────
-- The detail pane's hovers (modules/Results_Detail.lua), the same lines as the tables' where the two
-- show the same thing. The spells are the client's own spell tooltip with Tips.Spell's lines after
-- it, beside the window; everything else is under the element it names (Results_Table's BelowTip).

local function dimLine(text) return { text, 0.62, 0.62, 0.68 } end

local function joined(...)
    local out = {}
    for _, lines in ipairs({ ... }) do
        for _, l in ipairs(lines) do out[#out + 1] = l end
    end
    return out
end

local DETAIL = {}

DETAIL.class = CELL.icons
DETAIL.name = CELL.char
DETAIL.realm = CELL.ilvl
DETAIL.stamp = CELL.date
DETAIL.damage = CELL.damage
DETAIL.dps = CELL.dps

function DETAIL.target(run)
    local time = CELL.time(run)
    time[1] = dimLine(time[1])
    return joined(CELL.target(run), time)
end

function DETAIL.meterDps(run)
    local r = result(run)
    local lines = { L["Meter DPS"] }
    if type(r.meterDps) == "number" then lines[#lines + 1] = L["%s DPS"]:format(grouped(r.meterDps)) end
    lines[#lines + 1] = L["Blizzard's damage meter: damage over its whole session, the idle time before the pull and the tail included. Shown for comparison; it never ranks."]
    return lines
end

-- Where the Delta box's figures were read (a context's scope, modules/Results_Runs.lua).
local SCOPE = {
    group = "its group in the Runs list",
    view = "the Runs list's whole view",
    board = "its board (every run of the same spec, target type and race length)",
}

local function scopeOf(ctx)
    return L[SCOPE[ctx.scope] or SCOPE.view]
end

-- What the box's figure measures for a complete run: its lead over the runner-up on the top run,
-- else its distance from the max.
local function deltaAgainst(run, ctx, where)
    if NS.ResultsRuns.IsTop(run, ctx) then
        if not ctx.second then return { L["The only complete run in %s: there is no runner-up to lead."]:format(where) } end
        return { L["This run's lead over the runner-up in %s."]:format(where),
                 L["The runner-up: %s DPS."]:format(grouped(result(ctx.second).dps or 0)) }
    end
    if not ctx.top then return { L["No complete run in %s to compare with."]:format(where) } end
    return { L["Against the max DPS in %s."]:format(where), L["The max: %s DPS."]:format(grouped(ctx.top)) }
end

--- The Delta box: what its figure compares against (`ctx`, the pane's Runs.Context).
function DETAIL.delta(run, ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local lines = { L["Delta"] }
    if run.status == "lost" then
        lines[2] = L["A lost run has no DPS to compare."]
    else
        for _, line in ipairs(deltaAgainst(run, ctx, scopeOf(ctx))) do lines[#lines + 1] = line end
        if run.status ~= "complete" then lines[#lines + 1] = L["An incomplete run is compared, but never sets the max."] end
    end
    lines[#lines + 1] = ctx.scope == "board"
        and L["The Runs list's filters leave this run out, so it is measured on its board."]
        or L["Recomputed whenever the Runs list's filters or grouping change."]
    return lines
end

--- The New best badge: the run sets the max where the Delta box reads it.
function DETAIL.badge(_, ctx)
    ctx = type(ctx) == "table" and ctx or {}
    return { L["New best"], L["The highest DPS among the complete runs in %s."]:format(scopeOf(ctx)) }
end

function DETAIL.strip(run)
    local time = CELL.time(run)
    time[1] = dimLine(time[1])
    return joined({ L["Timing"],
        L["Left: the race, from the start to the buzzer. Right: the seconds after the buzzer, with the grace window, the damage still landing, any late casts and the end of combat."] },
        time)
end

DETAIL.tail = CELL.time

function DETAIL.breakdown()
    return { L["Spell breakdown"],
        L["Each spell's damage and its share of the run's, highest first. Compare sets them beside another run's."] }
end

function DETAIL.chart()
    return { L["Damage profile"],
        L["Your damage so far at each step of the race, captured live. With a best before this run, the faint line is that best's average pace, on the same scale."],
        L["A gold dot along the top marks each cast of an ability with a cooldown over 15 seconds."],
        dimLine(L["Only races run since your last reload or login have it: the live numbers cannot be saved."]) }
end

--- A cooldown dot's tooltip on the detail's chart (#14): the spell (the pet's marked) and the time it
--- was cast on the race clock; nil for anything but a cast.
--- @param cast table  { t, id, pet }
--- @return table|nil
function Tips.Dot(cast)
    if type(cast) ~= "table" or type(cast.id) ~= "number" then return nil end
    local name = NS.HudBreakdown.SpellName(cast.id)
    if cast.pet then name = L["%s (pet)"]:format(name) end
    return { name, L["Cast at %s"]:format(NS.ResultsUsage.Clock(tonumber(cast.t) or 0)) }
end

-- How many casts `label`'s lane holds.
local function castsLine(label, n)
    if n == 1 then return L["%s: 1 cast"]:format(label) end
    return L["%s: %d casts"]:format(label, n)
end

--- What follows the client's spell tooltip on a timeline row's name (#14): the ability's cooldown when
--- over 15 s, then each run's cast count (the compared run's only when there is one).
--- @param row table  one of ResultsTimeline.Rows' rows
--- @param otherLabel string|nil  the compared run's label, or nil with none
--- @return table
function Tips.TimelineRow(row, otherLabel)
    local lines = {}
    local cd = NS.ResultsTimeline.CooldownText(row)
    if cd ~= "" then lines[1] = { L["Cooldown %s"]:format(cd), 1, 0.82, 0 } end
    lines[#lines + 1] = castsLine(L["This run"], row.countA or 0)
    if otherLabel then lines[#lines + 1] = castsLine(otherLabel, row.countB or 0) end
    return lines
end

local LEGEND = {
    "The race, from the start to the buzzer (to the end of combat for an incomplete run).",
    "Damage still landing after the buzzer (DoTs, travel time). It counts.",
    "Casts started this long after the buzzer carry no flag: the Race page's Late-cast grace, frozen into each run.",
    "A cast started after the grace window. The run counts, with a flag.",
    "When combat ended.",
    "Your damage started again after a quiet gap past the buzzer: a new pull. The run counts, with a flag.",
}

function DETAIL.flags(run)
    local lines = Detail().FlagLines(run)
    if #lines == 0 then return nil end
    local out = { #lines == 1 and L["1 flag"] or L["%d flags"]:format(#lines) }
    for _, line in ipairs(lines) do out[#out + 1] = line.full end
    out[#out + 1] = dimLine(L["Flags inform; they never void a run."])
    return out
end

function DETAIL.note(run)
    if type(run.note) ~= "string" or run.note == "" then return nil end
    return { L["Note"], run.note, dimLine(L["Edit Note changes it; an empty note removes it."]) }
end

function DETAIL.noteBox()
    return { L["Note"], L["Enter saves, Escape cancels. Up to %d characters."]:format(Detail().NOTE_MAX) }
end

function DETAIL.addNote(run)
    local has = type(run.note) == "string" and run.note ~= ""
    return { has and L["Edit Note"] or L["Add Note"], L["A line of your own kept with the run: what you tried, what went wrong."] }
end

function DETAIL.share()
    return { L["Share"], L["Post the run's summary to chat: say, party, raid, guild or a whisper."] }
end

function DETAIL.shareOff()
    return { L["Share"], L["Sharing is unavailable: the Share module did not load."] }
end

function DETAIL.delete()
    return { L["Delete"], L["Remove this run from history, after a confirmation. A best it holds goes with it."] }
end

function DETAIL.back()
    return { L["Back"], L["Back to the list; the run stays selected."] }
end

function DETAIL.timeline()
    return { L["Timeline"], L["Open the ability timeline: every cast of this run beside the run it is compared with."] }
end

function DETAIL.timelineOff()
    return { L["Timeline"], dimLine(L["No casts recorded for this run: it was raced before casts were kept, or resumed after a reload."]) }
end

--- A detail element's tooltip lines (`key` names it; "legend" takes the legend's `index`, and "delta"
--- and "badge" take the Delta box's context in it), or nil.
--- @param key string
--- @param run table
--- @param index number|table|nil
--- @return table|nil
function Tips.Detail(key, run, index)
    if type(run) ~= "table" then return nil end
    if key == "legend" then
        local text = LEGEND[index]
        return text and { Detail().LEGEND[index], L[text] } or nil
    end
    local fn = DETAIL[key]
    if not fn then return nil end
    local ok, lines = pcall(fn, run, index)
    if not ok or type(lines) ~= "table" then return nil end
    local out = {}
    for i = 1, 8 do if lines[i] ~= nil then out[#out + 1] = lines[i] end end
    return out
end

--- What follows the client's spell tooltip on a breakdown row: the exact damage, its share of the
--- run's, and its place in the list.
--- @param spell table  { id, dmg }
--- @param run table
--- @param rank number|nil
--- @param count number|nil
--- @return table
function Tips.Spell(spell, run, rank, count)
    local dmg, damage = spell.dmg or 0, result(run).damage
    local lines = { { L["%s damage"]:format(grouped(dmg)), 1, 0.82, 0 } }
    if type(damage) == "number" and damage > 0 then
        lines[#lines + 1] = L["%.1f%% of the run's damage"]:format(dmg / damage * 100)
    end
    if rank and count then lines[#lines + 1] = dimLine(L["#%d of %d spells"]:format(rank, count)) end
    return lines
end

-- ── the compare ─────────────────────────────────────────────────────────────────────────────────
-- The detail's compare (modules/Results_Compare.lua): the toggle, Clear Pick, the different-board
-- note and the score table under themselves; a compared spell row after the client's spell tooltip.

local function otherName(kind)
    if kind == "picked" then return L["the run you picked"] end
    if kind == "runnerUp" then return L["the runner-up on its board (this run holds the best)"] end
    return L["the best on its board (same spec, target type and race length)"]
end

-- Who and when the other run was: "Lanfear · 25 Oct 14:02".
local function otherStamp(other)
    local char = type(other.char) == "table" and other.char or {}
    return ("%s \194\183 %s"):format(tostring(char.name or "?"), Tbl().Date(other.date, "%d %b %Y %H:%M"))
end

local function pctOf(pct) return pct and L["%+.1f%%"]:format(pct) or DASH end

local COMPARE = {}

function COMPARE.toggle(run, other, kind)
    if not NS.ResultsCompare.Usable(run) then
        return { L["Compare"], L["This run has no score to compare (it was lost)."] }
    end
    if not other then
        return { L["Compare"], L["No other complete run on this run's board (same spec, target type and race length) to compare with."] }
    end
    return { L["Compare"], L["Sets this run beside %s: damage, DPS and every spell."]:format(otherName(kind)),
             dimLine(otherStamp(other)),
             dimLine(L["Pick another run from a row's right-click menu: Compare With This Run."]) }
end

function COMPARE.clear()
    return { L["Clear Pick"], L["Compare with the best on this run's board again."] }
end

function COMPARE.boards(run, other)
    if not other then return nil end
    return { L["Different board"],
             L["The picked run differs in spec, target type or race length, so the figures are not like for like."],
             dimLine(L["This run: %s"]:format(CELL.time(run)[1])), dimLine(L["Picked: %s"]:format(CELL.time(other)[1])) }
end

function COMPARE.score(run, other, kind)
    if not other then return nil end
    local k = NS.ResultsCompare.Kpis(run, other)
    return { L["This run against %s"]:format(otherName(kind)),
             L["Damage: %s against %s (%s)"]:format(grouped(k.damageA), grouped(k.damageB), pctOf(k.damagePct)),
             L["DPS: %s against %s (%s)"]:format(grouped(k.dpsA), grouped(k.dpsB), pctOf(k.dpsPct)),
             dimLine(otherStamp(other)),
             dimLine(L["Difference: this run against the other, as a share of the other's figure."]) }
end

--- A compare part's tooltip lines (`key`: toggle, clear, boards, score), or nil.
--- @param key string
--- @param run table  the run shown
--- @param other table|nil  the run it is compared with
--- @param kind string|nil  "picked" | "best" | "runnerUp"
--- @return table|nil
function Tips.Compare(key, run, other, kind)
    local fn = COMPARE[key]
    if type(run) ~= "table" or not fn then return nil end
    local ok, lines = pcall(fn, run, other, kind)
    if not ok or type(lines) ~= "table" then return nil end
    return lines
end

local function sideLine(label, dmg, pct)
    if not dmg then return L["%s: not cast"]:format(label) end
    if not pct then return L["%s: %s damage"]:format(label, grouped(dmg)) end
    return L["%s: %s damage (%.1f%%)"]:format(label, grouped(dmg), pct)
end

--- What follows the client's spell tooltip on a compared row: each side's exact damage and share,
--- and the difference.
--- @param row table  one of ResultsCompare.Spells' rows
--- @param kind string|nil
--- @return table
function Tips.CompareSpell(row, kind)
    local delta = row.delta or 0
    local sign = delta > 0 and "+" or ""
    return { { sideLine(L["This run"], row.dmgA, row.shareA), 1, 0.82, 0 },
             sideLine(NS.ResultsCompare.OtherLabel(kind), row.dmgB, row.shareB),
             L["Difference: %s"]:format(sign .. grouped(delta)) }
end

-- ── the loadout ─────────────────────────────────────────────────────────────────────────────────
-- The detail's gear and talents (modules/Results_Loadout.lua, #6): each part under itself; an item
-- is the client's own item tooltip, with `changed`'s line after it while the compare is on.

local function loadoutOf(run)
    return NS.ResultsSource.LoadoutOf(run)
end

local function otherWho(other)
    return other and otherStamp(other) or L["the other run"]
end

local LOADOUT = {}

function LOADOUT.gear(run)
    local gear = loadoutOf(run)
    local n = 0
    for _ in pairs(gear or {}) do n = n + 1 end
    return { L["Gear"], n == 1 and L["1 item equipped when combat ended."] or L["%d items equipped when combat ended."]:format(n),
             dimLine(L["Hover an item for its tooltip; Shift-click links it in chat."]) }
end

function LOADOUT.none()
    return { L["Not recorded"],
             L["This run has no gear or talents: it was raced before the addon recorded them, or the client could not read them."] }
end

function LOADOUT.empty()
    return { L["Empty"], L["Nothing was equipped in this slot."] }
end

function LOADOUT.dressUp()
    return { L["Dressing Room"], L["Try the run's gear on in the Dressing Room."] }
end

function LOADOUT.talents(run)
    local _, t = loadoutOf(run)
    if not t then return LOADOUT.none() end
    local lines = { t.name or L["Unnamed loadout"] }
    if t.heroName then lines[#lines + 1] = L["Hero talents: %s"]:format(t.heroName) end
    lines[#lines + 1] = L["The talent loadout the run was raced with."]
    return lines
end

function LOADOUT.view()
    return { L["View"], L["Open the run's talent tree, read-only, and post its link to your chat window to open again later."],
             dimLine(L["Only you see the link: nothing is sent to a channel."]) }
end

function LOADOUT.viewOff(run)
    local _, t = loadoutOf(run)
    if not (t and t.importString) then return { L["View"], L["This run has no talent string to open."] } end
    return { L["View"], L["The game has changed how it saves talents since this run: its loadout no longer opens. Copy still works."] }
end

function LOADOUT.copy()
    return { L["Copy"], L["The loadout's import string, to paste into the talent frame, Wowhead or Raidbots."] }
end

function LOADOUT.differs(_, other)
    return { L["Different loadout"], L["The talents differ from %s's."]:format(otherWho(other)),
             dimLine(L["Copy both strings to see the difference node by node."]) }
end

function LOADOUT.changed(_, other, slot)
    local otherGear = loadoutOf(other)
    local link = otherGear and otherGear[slot]
    local name = link and NS.ResultsLoadout.ItemName(link)
    if not name then return { L["Changed: the other run had nothing here."] } end
    return { L["Changed: the other run wore %s."]:format(name) }
end

--- A loadout part's tooltip lines (`key`: gear, none, empty, dressUp, talents, view, viewOff, copy,
--- differs, changed), or nil.
--- @param key string
--- @param run table  the run shown
--- @param other table|nil  the run it is compared with
--- @param extra any  `changed`: the slot
--- @return table|nil
function Tips.Loadout(key, run, other, extra)
    local fn = LOADOUT[key]
    if type(run) ~= "table" or not fn then return nil end
    local ok, lines = pcall(fn, run, other, extra)
    if not ok or type(lines) ~= "table" then return nil end
    return lines
end

-- ── the usage ───────────────────────────────────────────────────────────────────────────────────
-- The detail's Usage section (modules/Results_Usage.lua, #13): its heading, Save and Not recorded under
-- themselves; a row after the client's item tooltip (or alone, for food and an enchant).

local SOURCE = {
    cast = "Detected from its cast during the race.",
    bag = "Detected from the bag count after the race.",
    buff = "Its buff was on when the race was armed.",
    enchant = "On the weapon when the race was armed.",
    manual = "Ticked by you.",
}

local USAGE = {}

function USAGE.title()
    return { L["Usage"], L["Every on-use item and consumable you had at the arm. What was detected starts ticked; tick or untick, then Save."],
             dimLine(L["Casts, bag counts and the buffs at the arm are the clues; a weapon oil shows as its enchant."]) }
end

function USAGE.none()
    return { L["Not recorded"], L["This run was raced before the addon recorded what was used."] }
end

function USAGE.empty()
    return { L["Usage"], L["No on-use item or consumable was found at the arm, and nothing was detected."] }
end

function USAGE.save()
    return { L["Save"], L["Keep the ticks as this run's usage. An entry the addon detected keeps its times."] }
end

function USAGE.row(_, row)
    local U = NS.ResultsUsage
    local lines = { U.Name(row) }
    local e = row.entry
    if not e then
        lines[#lines + 1] = dimLine(L["Not used: tick it if you did use it."])
        return lines
    end
    lines[#lines + 1] = { U.Detail(e), 1, 0.82, 0 }
    if SOURCE[e.src] then lines[#lines + 1] = dimLine(L[SOURCE[e.src]]) end
    if e.enchantID then lines[#lines + 1] = dimLine(L["Enchant %d"]:format(e.enchantID)) end
    return lines
end

--- A Usage part's tooltip lines (`key`: title, none, empty, save, row with `extra` the row), or nil.
--- @param key string
--- @param run table  the run shown
--- @param extra any  `row`: one of ResultsUsage.Rows' rows
--- @return table|nil
function Tips.Usage(key, run, extra)
    local fn = USAGE[key]
    if type(run) ~= "table" or not fn then return nil end
    local ok, lines = pcall(fn, run, extra)
    if not ok or type(lines) ~= "table" then return nil end
    return lines
end
