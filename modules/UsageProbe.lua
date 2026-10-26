local _, NS = ...
-- modules/UsageProbe.lua — a DEBUG-ONLY measurement (2026-10-26, for #13 and #14): what the client
-- tells an addon about the player's casts, on-use gear, consumables and buffs during a race, so the
-- capture can be built on measured answers. It decides nothing and stores nothing. It only writes what
-- it saw to the debug console, under the "Probe" tag. It is reverted once its findings are recorded.
--
-- WHEN. Only while debug logging is on (`/dr debug on`), from the arm to the result. Its event listener
-- is registered on the arm and dropped on the result or a cancel.
--
-- AT THE ARM (out of combat): each equipped slot with an on-use spell (GetInventoryItemID,
-- C_Item.GetItemSpell, both cooldown readers), every consumable in the bags (C_Container counts,
-- C_Item.GetItemInfoInstant class and subclass, its spell), the player's helpful auras (C_UnitAuras),
-- and GetWeaponEnchantInfo. Every answer is reported by its KIND (NS.Secrets.Kind: nil / secret /
-- sealed / a plain type) and, when plain, its value.
--
-- DURING THE RACE: every UNIT_SPELLCAST_* event for "player" and "pet" (one line each: event, time
-- since the arm and since the clock's start, the spell ID's and castGUID's kinds, the spell's name),
-- matched against the arm's on-use and consumable spells; the first time a spell is seen, its
-- GetSpellBaseCooldown, C_Spell.GetSpellCooldown, IsPlayerSpell and IsSpellKnownOrOverridesKnown.
--
-- AFTER THE RESULT (out of combat): the bag counts again (each change), both cooldown readers per on-use
-- slot (a start after the arm means used), the auras again, GetSpellBaseCooldown for every spell seen,
-- and a summary: casts per spell per event (a channel's SUCCEEDED count beside its CHANNEL_START count).

local Probe = {}
NS.UsageProbe = Probe

local Secrets = NS.Secrets

Probe.SLOTS = 19
Probe.BAGS = 5        -- the backpack (0), four bags and the reagent bag
Probe.AURAS = 40
local CONSUMABLE = 0  -- the item class of consumables (C_Item.GetItemInfoInstant)

local EVENTS = {
    "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
}
local SHORT = {
    UNIT_SPELLCAST_SENT = "SENT", UNIT_SPELLCAST_START = "START", UNIT_SPELLCAST_SUCCEEDED = "SUCC",
    UNIT_SPELLCAST_STOP = "STOP", UNIT_SPELLCAST_FAILED = "FAIL", UNIT_SPELLCAST_INTERRUPTED = "INTR",
    UNIT_SPELLCAST_CHANNEL_START = "CH_START", UNIT_SPELLCAST_CHANNEL_STOP = "CH_STOP",
    UNIT_SPELLCAST_EMPOWER_START = "EMP_START", UNIT_SPELLCAST_EMPOWER_STOP = "EMP_STOP",
}

local cur     -- the race being probed (see Probe.Start)
local events  -- the AceEvent target, built on the first arm

local function debugOn()
    return NS.State and NS.State.debug == true
end

local function log(fmt, ...)
    if NS.Debug then NS.Debug("Probe", fmt, ...) end
end

-- One call, never raising: nil when the function is missing, "error" when it raised.
local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g = pcall(fn, ...)
    if not ok then return "error" end
    return a, b, c, d, e, f, g
end

local function field(t, k)
    if not Secrets.CanAccessTable(t) then return nil end
    return t[k]
end

-- "kind" or "kind=value" for a report line: the value only when plain.
local function show(v)
    local kind = v == "error" and "error" or Secrets.Kind(v)
    if kind == "number" or kind == "string" or kind == "boolean" then return kind .. "=" .. tostring(v) end
    return kind
end

local function itemName(id)
    local name = ask(C_Item and C_Item.GetItemNameByID, id)
    return Secrets.PlainString(name) or ("item " .. tostring(id))
end

local function spellName(id)
    local name = ask(C_Spell and C_Spell.GetSpellName, id)
    return Secrets.PlainString(name) or "?"
end

-- ── the arm snapshot ────────────────────────────────────────────────────────────────────────────

local function cooldowns(slot, itemID)
    local s1, d1, e1 = ask(GetInventoryItemCooldown, "player", slot)
    local s2, d2, e2 = ask(C_Item and C_Item.GetItemCooldown, itemID)
    return { s1, d1, e1 }, { s2, d2, e2 }
end

local function cdLine(cd)
    return ("start %s dur %s enabled %s"):format(show(cd[1]), show(cd[2]), show(cd[3]))
end

local function snapshotGear()
    local gear = {}
    for slot = 1, Probe.SLOTS do
        local itemID = Secrets.PlainNumber(ask(GetInventoryItemID, "player", slot))
        if itemID then
            local sName, sID = ask(C_Item and C_Item.GetItemSpell, itemID)
            local spellID = Secrets.PlainNumber(sID)
            if spellID or slot == 13 or slot == 14 then
                local inv, item = cooldowns(slot, itemID)
                gear[slot] = { itemID = itemID, spellID = spellID }
                if spellID then cur.useSpells[spellID] = ("slot %d %s"):format(slot, itemName(itemID)) end
                log("arm gear slot %d: %s (%d) spell %s %s | inv cd %s | item cd %s", slot, itemName(itemID), itemID,
                    show(sID), show(sName), cdLine(inv), cdLine(item))
            end
        end
    end
    return gear
end

local function snapshotBags()
    local counts, seen = {}, {}
    for bag = 0, Probe.BAGS do
        local slots = Secrets.PlainNumber(ask(C_Container and C_Container.GetContainerNumSlots, bag)) or 0
        for slot = 1, slots do
            local info = ask(C_Container.GetContainerItemInfo, bag, slot)
            local itemID = Secrets.PlainNumber(field(info, "itemID"))
            local stack = field(info, "stackCount")
            if itemID then
                local _, _, _, _, _, classID, subclassID = ask(C_Item.GetItemInfoInstant, itemID)
                if Secrets.PlainNumber(classID) == CONSUMABLE then
                    counts[itemID] = (counts[itemID] or 0) + (Secrets.PlainNumber(stack) or 0)
                    if not seen[itemID] then
                        seen[itemID] = true
                        local _, sID = ask(C_Item.GetItemSpell, itemID)
                        local spellID = Secrets.PlainNumber(sID)
                        if spellID then cur.consumableSpells[spellID] = itemName(itemID) end
                        log("arm bag consumable %s (%d): subclass %s spell %s stack %s", itemName(itemID), itemID,
                            show(subclassID), show(sID), show(stack))
                    end
                end
            end
        end
    end
    return counts
end

local function scanAuras(when)
    local n = 0
    for i = 1, Probe.AURAS do
        local a = ask(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if a == nil or a == "error" then break end
        n = n + 1
        local id = field(a, "spellId")
        local plain = Secrets.PlainNumber(id)
        local match = plain and (cur.consumableSpells[plain] or cur.useSpells[plain])
        log("%s aura %d: spellId %s name %s expires %s%s", when, i, show(id), show(field(a, "name")),
            show(field(a, "expirationTime")), match and (" = " .. match) or "")
    end
    log("%s auras: %d helpful", when, n)
end

local function snapshotEnchant()
    local hasMain, mainExp, mainCharges, mainID, hasOff, offExp, offCharges = ask(GetWeaponEnchantInfo)
    log("arm weapon enchant: main %s exp %s charges %s id %s | off %s exp %s charges %s", show(hasMain),
        show(mainExp), show(mainCharges), show(mainID), show(hasOff), show(offExp), show(offCharges))
end

-- ── the casts ───────────────────────────────────────────────────────────────────────────────────

local function firstSeen(spellID)
    if cur.spells[spellID] then return end
    local baseMs, gcdMs = ask(GetSpellBaseCooldown, spellID)
    local cd = ask(C_Spell and C_Spell.GetSpellCooldown, spellID)
    cur.spells[spellID] = { name = spellName(spellID) }
    log("  first %d %s: baseCd %s gcd %s | spellCd start %s dur %s | playerSpell %s known %s", spellID,
        cur.spells[spellID].name, show(baseMs), show(gcdMs), show(field(cd, "startTime")), show(field(cd, "duration")),
        show(ask(IsPlayerSpell, spellID)), show(ask(IsSpellKnownOrOverridesKnown, spellID)))
end

local function tally(short, spellID)
    local key = short .. " " .. tostring(spellID)
    cur.tally[key] = (cur.tally[key] or 0) + 1
end

-- (event, unit, ...): SENT carries (unit, target, castGUID, spellID); the others (unit, castGUID,
-- spellID). Only the unit token is compared; the IDs are reported by kind and used only when plain.
local function onCast(event, unit, a, b, c)
    if not cur or (unit ~= "player" and unit ~= "pet") then return end
    local castGUID, spellID = a, b
    if event == "UNIT_SPELLCAST_SENT" then castGUID, spellID = b, c end
    local now = GetTime()
    local plain = Secrets.PlainNumber(spellID)
    local short = SHORT[event] or event
    local match = plain and (cur.useSpells[plain] or cur.consumableSpells[plain])
    log("%s %s +%.2f arm / %s race: spell %s guid %s %s%s", short, unit, now - cur.armAt,
        cur.startAt and ("+%.2f"):format(now - cur.startAt) or "-", show(spellID), Secrets.Kind(castGUID),
        plain and spellName(plain) or "", match and ("  << USE " .. match) or "")
    tally(short, plain or Secrets.Kind(spellID))
    if plain then firstSeen(plain) end
end

local function listen(on)
    if on then
        events = events or LibStub("AceEvent-3.0"):Embed({})
        for _, e in ipairs(EVENTS) do
            NS.SafeRegisterEvent(events, e, function(...) onCast(...) end, NS.rejectedEvents)
        end
    elseif events then
        events:UnregisterAllEvents()
    end
end

-- ── the report ──────────────────────────────────────────────────────────────────────────────────

local function bagDeltas()
    local after = snapshotBags()
    local changed = 0
    for itemID, before in pairs(cur.counts) do
        local now = after[itemID] or 0
        if now ~= before then
            changed = changed + 1
            log("after bag %s (%d): %d -> %d", itemName(itemID), itemID, before, now)
        end
    end
    for itemID, now in pairs(after) do
        if cur.counts[itemID] == nil then log("after bag new %s (%d): %d", itemName(itemID), itemID, now) end
    end
    log("after bags: %d consumable count(s) changed", changed)
end

local function gearAfter()
    for slot, g in pairs(cur.gear) do
        local inv, item = cooldowns(slot, g.itemID)
        local start = Secrets.PlainNumber(inv[1])
        local since = start and start > 0 and ("used +%.2f after arm"):format(start - cur.armAt) or "not on cooldown"
        log("after gear slot %d %s: inv cd %s | item cd %s | %s", slot, itemName(g.itemID), cdLine(inv), cdLine(item),
            since)
    end
end

local function summary()
    local keys = {}
    for key in pairs(cur.tally) do keys[#keys + 1] = key end
    table.sort(keys)
    log("summary: %d distinct (event, spell) pairs", #keys)
    for _, key in ipairs(keys) do
        local id = tonumber(key:match(" (%d+)$"))
        log("  %s x%d %s", key, cur.tally[key], id and cur.spells[id] and cur.spells[id].name or "")
    end
    for id, s in pairs(cur.spells) do
        local baseMs = ask(GetSpellBaseCooldown, id)
        log("  after baseCd %d %s: %s", id, s.name, show(baseMs))
    end
end

-- ── the lifecycle ───────────────────────────────────────────────────────────────────────────────

--- Start probing `run` at its arm (debug on). A second call while one runs is ignored.
function Probe.Start(run)
    if cur or not debugOn() then return false end
    cur = { run = run, armAt = GetTime(), useSpells = {}, consumableSpells = {}, spells = {}, tally = {} }
    log("start: arm snapshot, then every cast until the result (/dr debug off stops it at the next race)")
    local ok, err = pcall(function()
        cur.gear = snapshotGear()
        cur.counts = snapshotBags()
        scanAuras("arm")
        snapshotEnchant()
    end)
    if not ok then log("arm snapshot failed: %s", tostring(err)) end
    cur.gear, cur.counts = cur.gear or {}, cur.counts or {}
    listen(true)
    return true
end

--- The clock started.
function Probe.Running()
    if not cur then return end
    cur.startAt = GetTime()
    log("race clock started +%.2f after arm", cur.startAt - cur.armAt)
end

--- The race resolved: report what changed, then forget it.
function Probe.Report()
    if not cur then return end
    listen(false)
    local run = cur.run or {}
    log("report for run %s (%s), %s", tostring(run.id), tostring(run.status), show(GetTime() - cur.armAt))
    local ok, err = pcall(function()
        bagDeltas()
        gearAfter()
        scanAuras("after")
        summary()
    end)
    if not ok then log("report failed: %s", tostring(err)) end
    log("end of report: copy everything tagged Probe from here up to its start line")
    cur = nil
end

--- The race went idle without a result (canceled): stop and drop it.
function Probe.Discard()
    if not cur then return end
    listen(false)
    log("race canceled: nothing to report")
    cur = nil
end

--- Whether a race is being probed now (the suites).
function Probe.Active()
    return cur ~= nil
end

local receiver = NS.NewBusTarget and NS.NewBusTarget()
if receiver then
    receiver:RegisterMessage(NS.MSG.RACE_STATE_CHANGED, function(_, run, _, to)
        local S = NS.Race.STATE
        if to == S.ARMED then
            Probe.Start(run)
        elseif to == S.RUNNING then
            Probe.Running()
        elseif to == S.RESULT then
            Probe.Report()
        elseif to == S.IDLE then
            Probe.Discard()
        end
    end)
end
