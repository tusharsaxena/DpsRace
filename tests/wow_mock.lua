-- tests/wow_mock.lua — a THIN extender over the kit's tests/_kit/mock_base.lua: only the fakes this
-- addon needs and the kit does not carry (testing-§1). Plain per-key overwrite on a fresh table.
--
-- Loaded as `assert(loadfile(root .. "/tests/wow_mock.lua"))(root)`, so the kit path resolves from
-- any working directory. `build()` answers a fresh mock per call, which is what lets a suite stand a
-- whole isolated instance up per case.

local root = ... or "."
local base = dofile(root .. "/tests/_kit/mock_base.lua")

local function build()
    local M = base()
    local libs = M.__libs

    -- A NAMED frame is a global in the client, which is how a key binding's `CLICK <name>` finds its
    -- button (launcher-§6). The base records the name only; publish it the way the client does.
    local baseCreateFrame = M.CreateFrame
    M.__frameByName = {}
    M.CreateFrame = function(frameType, name, parent, template)
        local f = baseCreateFrame(frameType, name, parent, template)
        if type(name) == "string" and name ~= "" then
            M.__frameByName[name] = f
            M[name] = f
        end
        return f
    end

    -- TOC metadata, read through LibKa0s-Env-1.0 (core/EnvSetup.lua).
    M.__toc = {
        Version = "0.1.0",
        Title   = "Ka0s DPS Race",
        Notes   = "A timed DPS race against training dummies, with a live HUD, a run history and personal bests.",
    }
    M.C_AddOns = {
        GetAddOnMetadata = function(_, field) return M.__toc[field] end,
        IsAddOnLoaded    = function() return true, true end,
    }

    -- LibSharedMedia-3.0: a recording registry (core/MediaSetup.lua registers the shipped face).
    local media = { font = {}, statusbar = {}, border = {}, background = {}, sound = {} }
    libs["LibSharedMedia-3.0"] = {
        MediaType = { FONT = "font", STATUSBAR = "statusbar", BORDER = "border",
                      BACKGROUND = "background", SOUND = "sound" },
        Register  = function(_, kind, key, path)
            media[kind] = media[kind] or {}
            media[kind][key] = path
            return true
        end,
        Fetch     = function(_, kind, key) return media[kind] and media[kind][key] end,
        List      = function(_, kind)
            local out = {}
            for key in pairs(media[kind] or {}) do out[#out + 1] = key end
            table.sort(out)
            return out
        end,
        HashTable = function(_, kind) return media[kind] or {} end,
    }

    -- LibDataBroker-1.1 and LibDBIcon-1.0: the launcher's one object, registered twice (launcher-§1).
    local brokers = {}
    libs["LibDataBroker-1.1"] = {
        NewDataObject       = function(_, name, obj) brokers[name] = obj return obj end,
        GetDataObjectByName = function(_, name) return brokers[name] end,
        __objects           = brokers,
    }
    libs["LibDBIcon-1.0"] = {
        objects  = {},
        __shown  = {},
        Register = function(self, name, broker, db) self.objects[name] = { broker = broker, db = db } end,
        Refresh  = function(self, name, db)
            local o = self.objects[name]
            if o then o.db = db end
        end,
        Hide     = function(self, name) self.__shown[name] = false end,
        Show     = function(self, name) self.__shown[name] = true end,
    }

    -- The Profiles page's AceConfig trio (settings/Profiles.lua).
    libs["AceDBOptions-3.0"] = {
        GetOptionsTable = function(_, db) return { type = "group", name = "Profiles", args = {}, __db = db } end,
    }
    local registered = {}
    libs["AceConfig-3.0"] = {
        RegisterOptionsTable = function(_, name, tbl) registered[name] = tbl end,
        __registered = registered,
    }
    libs["AceConfigDialog-3.0"] = {
        Open = function(self, name, container)
            self.__opens = (self.__opens or 0) + 1
            self.__lastOpen = { name = name, container = container }
        end,
        Close = function() end,
        SetDefaultSize = function() end,
    }
    libs["AceConfigRegistry-3.0"] = {
        NotifyChange = function() end,
        RegisterOptionsTable = function() end,
    }

    -- MenuUtil: the launcher's right-click options menu (launcher-§2), recorded so a suite can read
    -- each entry's label, its enabled state and click it. A disabled entry's click calls nothing.
    M.__menus = {}
    M.MenuUtil = {
        CreateContextMenu = function(owner, generator)
            if owner == nil then error("CreateContextMenu: an owner region is required", 2) end
            local menu = { owner = owner, titles = {}, entries = {} }
            local rootDesc = {}
            function rootDesc:CreateTitle(text) menu.titles[#menu.titles + 1] = text return {} end
            function rootDesc:CreateDivider() return {} end
            function rootDesc:CreateButton(text, onClick, data)
                local entry = { text = text, setSelected = onClick, data = data, enabled = true,
                                isSelected = function() return false end }
                menu.entries[#menu.entries + 1] = entry
                local element = {}
                function element:SetEnabled(on) entry.enabled = on and true or false end
                return element
            end
            function rootDesc:CreateCheckbox(text, isSelected, setSelected, data)
                local entry = { text = text, isSelected = isSelected, setSelected = setSelected,
                                data = data, enabled = true }
                menu.entries[#menu.entries + 1] = entry
                local element = {}
                function element:SetEnabled(on) entry.enabled = on and true or false end
                function element:IsEnabled() return entry.enabled end
                return element
            end
            function menu:Find(prefix)
                for _, e in ipairs(self.entries) do
                    if e.text:sub(1, #prefix) == prefix then return e end
                end
            end
            function menu:Click(prefix)
                local e = assert(self:Find(prefix), "no menu entry " .. prefix)
                if not e.enabled then return nil end
                return e.setSelected(e.data)
            end
            generator(owner, rootDesc)
            M.__menus[#M.__menus + 1] = menu
            M.__lastMenu = menu
            return menu
        end,
    }
    M.MenuResponse = { Close = 1, Refresh = 2, Open = 3 }

    -- The run record's metadata snapshots (modules/Recorder.lua, T3): who, against what, where. The
    -- player fields extend the kit's __context; the target is one settable table, nil = no target.
    -- Every value is read at CALL time, so a case sets M.__context / M.__setTarget before snapshotting.
    M.__context.guid        = "Player-1-00000001"
    M.__context.specID      = 267
    M.__context.role        = "DAMAGER"
    M.__context.ilvl        = 313.44     -- overall (bags included)
    M.__context.ilvlEquipped = 313.16
    M.__context.race        = "Blood Elf"
    M.__context.raceToken   = "BloodElf"
    M.__context.mapID       = 2393
    M.__context.build       = 120105
    M.GetSpecializationInfo = function()
        return M.__context.specID, M.__context.spec, "", 0, M.__context.role
    end
    M.GetAverageItemLevel = function() return M.__context.ilvl, M.__context.ilvlEquipped end
    M.UnitRace = function() return M.__context.race, M.__context.raceToken end
    M.C_Map = { GetBestMapForUnit = function() return M.__context.mapID end }
    M.GetInstanceInfo = function()
        return M.__context.inInstance and "Instance" or M.__context.zone, M.__context.instanceType
    end
    M.GetBuildInfo = function() return "12.0.5", "60000", "Oct 1 2026", M.__context.build end

    -- The class and spec reference data the Results window draws a run with (modules/Results_Table.lua):
    -- a few classes' icon coordinates, colors and names, and the spec lookup by ID. Plain client tables.
    M.CLASS_ICON_TCOORDS = {
        WARLOCK = { 0.75, 1, 0.25, 0.5 }, MAGE = { 0.25, 0.5, 0, 0.25 },
        DRUID = { 0.75, 1, 0, 0.25 }, EVOKER = { 0.25, 0.5, 0.75, 1 },
    }
    M.RAID_CLASS_COLORS = {
        WARLOCK = { r = 0.53, g = 0.53, b = 0.93 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 },
        DRUID = { r = 1, g = 0.49, b = 0.04 }, EVOKER = { r = 0.2, g = 0.58, b = 0.5 },
    }
    M.LOCALIZED_CLASS_NAMES_MALE = { WARLOCK = "Warlock", MAGE = "Mage", DRUID = "Druid", EVOKER = "Evoker" }
    M.__specs = {
        [267] = { "Destruction", 136186 }, [63] = { "Fire", 135810 },
        [102] = { "Balance", 136096 }, [1467] = { "Devastation", 4511811 },
    }
    M.GetSpecializationInfoByID = function(id)
        local s = M.__specs[id]
        if not s then return nil end
        return id, s[1], "", s[2], "DAMAGER"
    end

    -- C_Timer.NewTicker, which the kit's C_Timer does not carry (modules/Race.lua's readiness poll).
    -- One queue entry per period: firing it re-queues it until canceled or out of iterations, so
    -- `M.__fireTimers()` runs one tick and `M.__timers()` sees a live ticker as armed.
    M.C_Timer.NewTicker = function(interval, fn, iterations)
        local t = { delay = interval }
        t.Cancel = function() t.cancelled = true end
        t.IsCancelled = function() return t.cancelled == true end
        local left = iterations
        t.fn = function()
            fn(t)
            if left then
                left = left - 1
                if left <= 0 then t.cancelled = true end
            end
            if not t.cancelled then M.__timers[#M.__timers + 1] = t end
        end
        M.__timers[#M.__timers + 1] = t
        return t
    end

    -- The target: { guid, name, level, classification } or nil. Any field may be a Kit.secret.
    M.__target = nil
    function M.__setTarget(t)
        M.__target = t
        M.__unitExists.target = t ~= nil
    end
    local function unitField(unit, field, playerValue)
        if unit == "player" then return playerValue end
        if unit == "target" and M.__target then return M.__target[field] end
        return nil
    end
    M.UnitGUID = function(unit) return unitField(unit, "guid", M.__context.guid) end
    M.UnitName = function(unit) return unitField(unit or "player", "name", M.__context.name) end
    M.UnitLevel = function(unit) return unitField(unit or "player", "level", M.__context.level) end
    M.UnitClassification = function(unit) return unitField(unit, "classification", "normal") end

    return M
end

return { build = build }
