local _, NS = ...
-- modules/Hud_Best.lua — the idle body's Your best card (R3-DR-4, the owner's ask of 2026-11-03,
-- Ka0sAddonsCommonTasks docs/2026-11-02-SMOKE_ROUND3/R3_ADDENDUM_DPSRACE.md, image 101): the best on
-- the board the next race would count on, shown as the mark to beat between the Target card and Arm
-- Race (modules/Hud_States.lua places it, States.IDLE_BEST_Y_PLAIN or, under the amber warning,
-- States.IDLE_BEST_Y_WARNED, through Best.Place, and sizes it, States.BEST_H).
--
-- THE BOARD is spec | target category | length (Bests.Key): the player's spec read now, the target
-- the idle body shows and the length it would arm. Its best is the cached bests board's
-- (Bests.Board, the sample history's in test mode or a sim), the same run the live chart's pace and
-- the result delta read. Nothing new is stored.
--
-- LIVE. modules/Hud.lua builds the view on every idle redraw: a length or Custom pick, a target
-- change, PLAYER_SPECIALIZATION_CHANGED and RUNS_CHANGED each redraw the idle body.
--
-- STORED NUMBERS ONLY. Every figure here is a stored run's, plain since NS.Secrets took it in, so its
-- width may be measured and its tooltip may name it, in or out of combat.

local Best = {}
NS.HudBest = Best

local L = NS.L
local Style = NS.Style
local FONT = Style.FONT

-- The DPS figure: the HUD's figures block (HUD Appearance > Live figures) at this share of its size,
-- so two lines fit the card.
local FIGURE_SCALE = 0.8
local DOT = " \194\183 "
local TOP_SPELLS = 3

local function dpsOf(run) return run.result and run.result.dps end
local function damageOf(run) return run.result and run.result.damage end

--- The view the idle body draws: { state = "noTarget" | "empty" | "best", run, spec, category, length }.
--- @param target table|nil  the idle body's target (Recorder.SnapshotTarget)
--- @param length number  the length Arm Race would arm
--- @return table
function Best.View(target, length)
    local v = { length = length }
    if type(target) ~= "table" or (target.name == nil and target.npcID == nil) then
        v.state = "noTarget"
        return v
    end
    local specID, spec = NS.Recorder.CurrentSpec()
    v.spec, v.category = spec, NS.Dummies.CategoryOf(target)
    local key = NS.Bests.Key({ char = { specID = specID }, target = target, race = { length = length } })
    v.run = NS.Bests.Board()[key]
    v.state = v.run and "best" or "empty"
    return v
end

--- The board the best is on, for the hover: spec · target category · length (the label itself reads
--- just "Your best", R4-DR3).
local function boardText(v)
    local parts = {}
    if v.spec then parts[#parts + 1] = v.spec end
    parts[#parts + 1] = NS.Dummies.Label(v.category)
    parts[#parts + 1] = NS.Format.Length(v.length)
    return table.concat(parts, DOT)
end

--- The consumables the run used (R4-DR4): every kind the usage record carries but on-use gear
--- (potions, flasks, food, augment runes, Healthstones), in the Used column's order with hidden
--- items left out (ResultsUsage.Entries). Empty when none were used or none were recorded.
local function consumables(run)
    local RU, out = NS.ResultsUsage, {}
    for _, e in ipairs(RU and RU.Entries(run) or {}) do
        if e.kind ~= "gear" then out[#out + 1] = e end
    end
    return out
end

--- "x2" past a single use, else "".
local function times(e)
    local n = tonumber(e.n) or 1
    return n > 1 and ("x" .. n) or ""
end

--- Line two: date · ilvl · the consumables' icons (12 px, at the caption line's size), each with
--- xN past one use; nothing after the ilvl when none were used.
local function lineText(run)
    local Tbl = NS.ResultsTable
    local parts = { Tbl.Date(run.date, "%d %b") }
    local char = run.char or {}
    if type(char.ilvl) == "number" then parts[#parts + 1] = L["ilvl %s"]:format(Tbl.Ilvl(char.ilvl)) end
    local icons = {}
    for _, e in ipairs(consumables(run)) do
        icons[#icons + 1] = "|T" .. tostring(NS.ResultsUsage.Icon(e)) .. ":12:12|t" .. times(e)
    end
    if #icons > 0 then parts[#parts + 1] = table.concat(icons, " ") end
    return table.concat(parts, DOT)
end

--- The hover: the board, then the whole run, as fixed lines of its stored figures.
local function tipOf(run, v)
    local Tbl, Format = NS.ResultsTable, NS.Format
    local tip = { L["Your best"],
        boardText(v),
        Tbl.Date(run.date, "%d %b %Y %H:%M"),
        L["Length: %s"]:format(Format.Length(run.race and run.race.length)),
        L["Damage: %s"]:format(Format.Number(damageOf(run))),
        L["DPS: %s"]:format(Format.Number(dpsOf(run))),
    }
    for i = 1, math.min(TOP_SPELLS, type(run.spells) == "table" and #run.spells or 0) do
        local s = run.spells[i]
        tip[#tip + 1] = ("%d. %s  %s"):format(i, NS.HudBreakdown.SpellName(s.id), Format.Number(s.dmg))
    end
    -- The consumables the card's icons stand for, by name.
    for _, e in ipairs(consumables(run)) do
        local n = times(e)
        tip[#tip + 1] = NS.ResultsUsage.InlineIcon(e) .. " " .. NS.ResultsUsage.Name(e) .. (n ~= "" and (" " .. n) or "")
    end
    tip[#tip + 1] = L["Click to open this run in Results."]
    return tip
end

local function open(card)
    local run = card.run
    local Act = NS.Hud and NS.Hud.Act
    if run and Act and Act.openBest then Act.openBest(run) end
end

--- Put the section at `y` (negative, from `parent`'s top): its caption, the card under it, both
--- spanning the body. The idle body moves it as the amber warning comes and goes (R4-DR2).
--- @param b table  Best.Build's
--- @param parent table  the idle body's frame
--- @param y number
function Best.Place(b, parent, y)
    local CAPTION_H = NS.HudStates.BEST_CAPTION_H
    b.caption:ClearAllPoints()
    b.caption:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    b.caption:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    b.card:ClearAllPoints()
    b.card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y - CAPTION_H)
    b.card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y - CAPTION_H)
end

--- Build the section into `parent` at `y` (negative, from its top): its caption, then the card.
--- @param parent table  the idle body's frame
--- @param y number
--- @return table b  { caption, card, dps, damage, line, empty }
function Best.Build(parent, y)
    local States = NS.HudStates
    local dim = States.COLORS.dim
    local CARD_H = States.BEST_CARD_H   -- the stack's, Hud_States'
    local b = {}
    b.caption = Style.Text(parent, FONT.HEADER)
    local card = States.Panel(parent, nil, "card")
    card:SetHeight(CARD_H)
    b.card = card
    Best.Place(b, parent, y)
    b.dps = Style.PlainText(card, FONT.FIGURE)
    b.dps:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -4)
    b.damage = Style.Text(card, FONT.TEXT, dim, "RIGHT")
    b.damage:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -7)
    b.line = Style.Text(card, FONT.CAPTION, dim)
    b.line:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 8, 5)
    b.line:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 5)
    b.empty = Style.Text(card, FONT.TEXT, dim)
    b.empty:SetPoint("LEFT", card, "LEFT", 8, 0)
    b.empty:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    States.AddTip(card, nil)
    card:SetScript("OnMouseUp", open)
    return b
end

-- The figure in the HUD's figures face, again after each HUD Appearance change (its stamp).
local function styleFigure(b)
    local A = NS.HudAppearance
    if not A or b.styled == A.stamp then return end
    b.styled = A.stamp
    A.ApplyFont(b.dps, A.Font("figures"), FIGURE_SCALE)
end

--- Draw `v` (Best.View's) on the section.
--- @param b table  Best.Build's
--- @param v table|nil
function Best.Update(b, v)
    if not b then return end
    v = v or { state = "noTarget" }
    b.caption:SetText(L["Your best"])
    local run = v.state == "best" and v.run or nil
    b.card.run, b.card.tip = run, run and tipOf(run, v) or nil
    b.dps:SetShown(run ~= nil)
    b.damage:SetShown(run ~= nil)
    b.line:SetShown(run ~= nil)
    b.empty:SetShown(run == nil)
    if not run then
        b.empty:SetText(v.state == "noTarget" and L["Target a dummy to see your best."]
            or L["No race yet: this one sets the mark."])
        return
    end
    styleFigure(b)
    b.dps:SetText(NS.Format.Number(dpsOf(run)))
    b.damage:SetText(NS.Format.Number(damageOf(run)))
    b.line:SetText(lineText(run))
end
