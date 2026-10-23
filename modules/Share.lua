local _, NS = ...
-- modules/Share.lua — Share (spec §6.1, §6.2; mockup screen 12): one line about a run, sent to a chat
-- channel the player picks from a menu, only out of combat; and the race's own status lines in the
-- player's chat (armed, and the score when a run resolves).
--
-- A run's stored fields are plain numbers and strings (spec §7), so everything here formats plain
-- values; nothing reads the meter. Text that reaches a channel has every `|` replaced, so a name or a
-- note can never carry a chat escape into someone else's chat.

local Share = {}
NS.Share = Share

local L = NS.L

local MIDDOT = " \194\183 "
local TIMES = "\195\151"           -- the multiplication sign: "Cleave x5"
local EMDASH = " \226\128\148 "
local WHISPER_POPUP = "DPSRACE_SHARE_WHISPER"

-- The channels the menu offers, in its order, and when each is open to the player.
Share.CHANNELS = {
    { key = "SAY",     label = "Say" },
    { key = "PARTY",   label = "Party",   open = function() return IsInGroup and IsInGroup() end },
    { key = "RAID",    label = "Raid",    open = function() return IsInRaid and IsInRaid() end },
    { key = "GUILD",   label = "Guild",   open = function() return IsInGuild and IsInGuild() end },
    { key = "WHISPER", label = "Whisper\226\128\166" },
}

local function clean(s)
    return (tostring(s or ""):gsub("|", "/"))
end

--- "Cleave x5" / "Single target" / an uncataloged target's own name.
local function targetText(target)
    target = target or {}
    local text = NS.Dummies.Label(target.category)
    if (target.category == nil or target.category == "other") and target.name then text = target.name end
    if type(target.count) == "number" and target.count > 1 then text = text .. " " .. TIMES .. target.count end
    return text
end

--- "Cleave Training Dummy x5": the target by name, for the player's own lines.
local function targetName(target)
    target = target or {}
    local text = target.name or NS.Dummies.Label(target.category)
    if type(target.count) == "number" and target.count > 1 then text = text .. " " .. TIMES .. target.count end
    return text
end

local function whoText(char)
    char = char or {}
    local who = char.spec or char.class or char.name or "?"
    if type(char.ilvl) == "number" then who = who .. " " .. math.floor(char.ilvl) end
    return who
end

--- The one line a run is shared as, or nil for a run with no score (lost, or not resolved):
--- "DPS Race 3:00 · Cleave x5 · Destruction 313 · 26.56M · 147.6K DPS (Ka0s DPS Race)".
--- @param run table
--- @return string|nil
function Share.Line(run)
    local result = type(run) == "table" and run.result
    if type(result) ~= "table" or (run.status ~= "complete" and run.status ~= "incomplete") then return nil end
    local parts = {
        L["DPS Race %s"]:format(NS.Format.Length(run.race and run.race.length)),
        targetText(run.target),
        whoText(run.char),
        NS.Format.Number(result.damage or 0),
        L["%s DPS"]:format(NS.Format.Number(result.dps or 0)),
    }
    if run.status == "incomplete" then parts[#parts + 1] = L["incomplete"] end
    return clean(table.concat(parts, MIDDOT) .. " " .. L["(Ka0s DPS Race)"])
end

-- ── sending ─────────────────────────────────────────────────────────────────────────────────────

local function fighting()
    if UnitAffectingCombat and UnitAffectingCombat("player") then return true end
    if InCombatLockdown and InCombatLockdown() then return true end
    -- Midnight's chat lockdown (encounters, rated PvP): sending is refused by the client then too.
    local info = C_ChatInfo
    if info and type(info.InChatMessagingLockdown) == "function" then
        local ok, locked = pcall(info.InChatMessagingLockdown)
        if ok and locked then return true end
    end
    return false
end

local function refuseInCombat()
    NS.Print(L["You can share a run once you are out of combat."])
    return false
end

-- The send call is version-variant: core/Compat.lua owns it (compat).
local function sender()
    return NS.Compat.ChatSender()
end

--- Send `run`'s line to one channel. Refused in combat.
--- @param run table
--- @param channel string  "SAY" | "PARTY" | "RAID" | "GUILD" | "WHISPER"
--- @param target string|nil  the whisper's recipient
--- @return boolean sent
function Share.Send(run, channel, target)
    local line = Share.Line(run)
    if not line then return false end
    if fighting() then return refuseInCombat() end
    local send = sender()
    if type(send) ~= "function" then return false end
    local ok, err = pcall(send, line, channel, nil, target)
    if not ok then NS.Debug("Share", "send to %s failed: %s", channel, err) end
    return ok
end

-- The whisper's recipient: a name typed into the popup, the player target's name offered first.
local function whisperBox(dialog)
    if dialog == nil then return nil end
    if type(dialog.GetEditBox) == "function" then return dialog:GetEditBox() end
    return dialog.editBox or dialog.EditBox
end

local function acceptWhisper(dialog, run)
    local box = whisperBox(dialog)
    local name = box and box:GetText()
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return end
    Share.Send(run, "WHISPER", name)
end

StaticPopupDialogs[WHISPER_POPUP] = {
    text         = L["Whisper this run to:"],
    button1      = L["Send"],
    button2      = L["Cancel"],
    hasEditBox   = true,
    maxLetters   = 64,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnShow       = function(self)
        local box = whisperBox(self)
        local name = UnitIsPlayer and UnitIsPlayer("target") and UnitName("target")
        if box and type(name) == "string" and NS.Secrets.PlainString(name) then box:SetText(name) end
    end,
    OnAccept     = function(self, run) acceptWhisper(self, run) end,
    EditBoxOnEnterPressed = function(box, run)
        acceptWhisper(box:GetParent(), run)
        box:GetParent():Hide()
    end,
}

local function pick(run, channel)
    if channel == "WHISPER" then
        if fighting() then return refuseInCombat() end
        StaticPopup_Show(WHISPER_POPUP, nil, nil, run)
        return true
    end
    return Share.Send(run, channel)
end

--- The Share button (the HUD's result card, the Results detail, a row's double-click): a menu of
--- channels, the ones the player is not in grayed. Refused in combat with one line.
--- @param run table
--- @param owner table|nil  the region the menu opens at (the clicked control)
--- @return boolean opened
function Share.Prompt(run, owner)
    if not Share.Line(run) then
        NS.Print(L["This run has no score to share."])
        return false
    end
    if fighting() then return refuseInCombat() end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        -- No menu on this client: the line in the player's own chat, to copy by hand.
        NS.Print(Share.Line(run))
        return true
    end
    MenuUtil.CreateContextMenu(owner or UIParent, function(_, root)
        root:CreateTitle(L["Share to"])
        for _, c in ipairs(Share.CHANNELS) do
            local button = root:CreateButton(L[c.label], function() pick(run, c.key) end)
            if c.open and not c.open() then button:SetEnabled(false) end
        end
    end)
    return true
end

-- ── the race's own lines (mockup screen 12) ─────────────────────────────────────────────────────

--- "Armed: 3:00 on Cleave Training Dummy x5. First hit starts the clock."
function Share.ArmedLine(run)
    return L["Armed: %s on %s. First hit starts the clock."]:format(
        NS.Format.Length(run.race and run.race.length), targetName(run.target))
end

local function deltaText(delta, isNew)
    if isNew then
        if delta then return L["new best (+%.1f%%)"]:format(delta) end
        return L["new best"]
    end
    if delta then return L["%+.1f%% vs best"]:format(delta) end
    return nil
end

--- The score line the player sees when a run resolves:
--- "26.56M damage · 147.6K DPS in 3:00 on Cleave Training Dummy x5 — new best (+2.4%) · 1 late cast · tail +3.1s".
--- @param run table  a complete or incomplete run
--- @param delta number|nil  Bests.Delta's percentage
--- @param isNew boolean|nil  Bests.Delta's new-best answer
--- @return string
function Share.ResultLine(run, delta, isNew)
    local result = run.result or {}
    local line = L["%s damage \194\183 %s DPS in %s on %s"]:format(NS.Format.Number(result.damage or 0),
        NS.Format.Number(result.dps or 0), NS.Format.Length(run.race and run.race.length), targetName(run.target))
    local tail = {}
    tail[#tail + 1] = deltaText(delta, isNew)
    local late = run.flags and run.flags.lateCasts
    if type(late) == "table" and #late > 0 then
        tail[#tail + 1] = #late == 1 and L["1 late cast"] or L["%d late casts"]:format(#late)
    end
    if run.status == "incomplete" then tail[#tail + 1] = L["incomplete"] end
    if type(result.tail) == "number" then tail[#tail + 1] = L["tail +%.1fs"]:format(result.tail) end
    if #tail == 0 then return line end
    return line .. EMDASH .. table.concat(tail, MIDDOT)
end

local function onResult(run)
    if type(run) ~= "table" then return end
    if run.status == "lost" then
        NS.Print(L["Couldn't read the result: the run is kept as lost."])
        return
    end
    local delta, isNew
    if run.status == "complete" then delta, isNew = NS.Bests.Delta(run) end
    NS.Print(Share.ResultLine(run, delta, isNew))
end

do
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.RACE_STATE_CHANGED, function(_, run, _, to)
            if to == NS.Race.STATE.ARMED and type(run) == "table" then NS.Print(Share.ArmedLine(run)) end
        end)
        bus:RegisterMessage(NS.MSG.RACE_RESULT, function(_, run) onResult(run) end)
    end
end
