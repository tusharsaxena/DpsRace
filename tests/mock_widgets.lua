-- tests/mock_widgets.lua — the HUD suites' widget recorder, over the kit's frames: distinct font
-- strings and textures that remember what they were told, a geometry spy, and the client seams the
-- HUD draws through (the number formatter, C_Spell, sounds, the raid warning, known spells).
--
-- Loaded by a suite as `dofile(T.root .. "/tests/mock_widgets.lua")(T)` and installed per instance
-- from a load's `mutate` (before the addon loads, so every frame the HUD makes is dressed). Not a suite.
--
-- WHY A SECOND LAYER. The kit's CreateFontString / CreateTexture answer the FRAME ITSELF (its known,
-- kept divergence), so a label's text cannot be read back and a font string that received a secret
-- cannot be told apart from its parent. Here every region is its own recorded object, and every
-- frame and region records:
--   __text / __value / __min / __max / __texture / __scale   what it was last handed
--   W.secretFrames[obj]   true once it was handed a secret (Kit.secret) by any setter
--   W.geomReads           every Get{Width,Height,Size,Point,...} call, as { frame, method }
--   __texCoord / __font / __strata / __mouse   a region's texcoords, font, strata and mouse flag
--   __fontObject   the Blizzard font object a font string was made with or handed (SetFontObject)
--   __vertex       a texture's last SetVertexColor, { r, g, b, a }
--   W.animPlays           every AnimationGroup:Play(), as { owner, t }; W.missingTextures[path] makes
--                         SetTexture answer false for that path (a texture the client cannot load)
-- A geometry read on a frame that holds a secret raises in the client (spec §6.1); the suites assert
-- the HUD makes none at all while it draws live values.
--
-- THE FORMATTER is modeled as the client measured it (MultiMeters' mock): it abbreviates only through
-- the breakpoints it was given, shown = n / (significandDivisor * fractionDivisor), truncated. It is a
-- native seam, so it may reveal a secret; nothing else here does.

return function(T)
    local Widgets = {}

    local GEOMETRY = { "GetWidth", "GetHeight", "GetSize", "GetPoint", "GetLeft", "GetRight", "GetTop",
                       "GetBottom", "GetRect", "GetCenter", "GetBoundsRect", "GetScaledRect",
                       "GetStringWidth", "GetStringHeight" }

    local SPELL_NAMES = {
        [29722] = "Incinerate", [116858] = "Chaos Bolt", [348] = "Immolate", [17962] = "Conflagrate",
        [5384] = "Feign Death", [1856] = "Vanish", [58984] = "Shadowmeld", [66] = "Invisibility",
    }

    local function decimalsFor(fractionDivisor)
        local d, n = 0, fractionDivisor or 1
        while n >= 10 do n, d = n / 10, d + 1 end
        return d
    end

    local function newFormatter()
        local f = { breakpoints = nil, calls = 0 }
        function f:SetBreakpoints(list)
            if type(list) ~= "table" then error("SetBreakpoints wants an array", 2) end
            self.breakpoints = list
        end
        function f:FormatNumber(v)
            self.calls = self.calls + 1
            local n = T.reveal(v)
            if type(n) ~= "number" then return tostring(n) end
            local best
            for _, bp in ipairs(self.breakpoints or {}) do
                if n >= (bp.breakpoint or 0) and (best == nil or bp.breakpoint >= best.breakpoint) then best = bp end
            end
            if best == nil then return tostring(n) end
            local scaled = n / ((best.significandDivisor or 1) * (best.fractionDivisor or 1))
            local d = decimalsFor(best.fractionDivisor)
            local factor = 10 ^ d
            return string.format("%." .. d .. "f", math.floor(scaled * factor + 1e-9) / factor) .. (best.abbreviation or "")
        end
        return f
    end

    --- Install on one mock build; answers the recorder.
    function Widgets.install(M)
        local W = { secretFrames = {}, geomReads = {}, sounds = {}, notices = {}, known = {}, objects = {},
                    animPlays = {}, missingTextures = {} }

        local function mark(o, ...)
            for i = 1, select("#", ...) do
                if T.isSecret((select(i, ...))) then W.secretFrames[o] = true end
            end
        end

        local dress
        local function region(parent, template)
            local r = M.__stubFrame()
            r.__parentFrame = parent
            r.__fontObject = template
            dress(r)
            return r
        end

        function dress(o)
            W.objects[#W.objects + 1] = o
            rawset(o, "SetText", function(self, v) self.__text = v; mark(self, v); return self end)
            rawset(o, "GetText", function(self) return self.__text end)
            rawset(o, "SetValue", function(self, v) self.__value = v; mark(self, v); return self end)
            rawset(o, "SetMinMaxValues", function(self, a, b)
                self.__min, self.__max = a, b
                mark(self, a, b)
                return self
            end)
            rawset(o, "SetTexture", function(self, p)
                self.__texture = p
                mark(self, p)
                if p ~= nil and W.missingTextures[p] then return false end
                return true
            end)
            rawset(o, "SetTexCoord", function(self, ...) self.__texCoord = { ... }; return self end)
            rawset(o, "SetFont", function(self, path, size, flags)
                self.__font = { path = path, size = size, flags = flags }
                return true
            end)
            rawset(o, "SetFrameStrata", function(self, strata) self.__strata = strata; return self end)
            rawset(o, "EnableMouse", function(self, on) self.__mouse = on and true or false; return self end)
            rawset(o, "CreateAnimationGroup", function(self) return W.NewAnimationGroup(self) end)
            rawset(o, "SetTextColor", function(self, r, g, b, a) self.__color = { r, g, b, a }; return self end)
            rawset(o, "SetScale", function(self, s) self.__scale = s; return self end)
            rawset(o, "SetFontObject", function(self, font) self.__fontObject = font; return self end)
            rawset(o, "SetPoint", function(self, ...)
                self.__points = self.__points or {}
                self.__points[#self.__points + 1] = { ... }
                return self
            end)
            rawset(o, "ClearAllPoints", function(self) self.__points = {}; return self end)
            rawset(o, "SetJustifyH", function(self, j) self.__justifyH = j; return self end)
            rawset(o, "SetVertexColor", function(self, r, g, b, a) self.__vertex = { r, g, b, a }; return self end)
            rawset(o, "CreateFontString", function(self, _, _, template) return region(self, template) end)
            rawset(o, "CreateTexture", function(self) return region(self) end)
            for _, name in ipairs(GEOMETRY) do
                rawset(o, name, function(self)
                    W.geomReads[#W.geomReads + 1] = { frame = self, method = name }
                    if name == "GetPoint" then return "CENTER", nil, "CENTER", 0, 0 end
                    return 0
                end)
            end
        end

        --- A recording AnimationGroup: its animations remember every setter, Play is counted.
        function W.NewAnimationGroup(owner)
            local g = { owner = owner, anims = {}, playing = false }
            local function recorder(kind)
                local a = { kind = kind, set = {} }
                return setmetatable(a, { __index = function(_, k)
                    return function(_, ...) a.set[k] = { ... }; return a end
                end })
            end
            function g:CreateAnimation(kind)
                local a = recorder(kind)
                self.anims[#self.anims + 1] = a
                return a
            end
            function g:Play()
                self.playing = true
                W.animPlays[#W.animPlays + 1] = { owner = owner, t = M.__now }
            end
            function g:Stop() self.playing = false end
            function g:IsPlaying() return self.playing end
            function g:SetToFinalAlpha() return self end
            function g:SetScript() return self end
            return g
        end

        local baseCreate = M.CreateFrame
        M.CreateFrame = function(...)
            local f = baseCreate(...)
            dress(f)
            return f
        end

        M.C_StringUtil = { CreateAbbreviatedNumberFormatter = function() return newFormatter() end }
        M.C_Spell = {
            GetSpellName = function(id)
                local n = T.reveal(id)
                local name = SPELL_NAMES[n] or ("Spell " .. tostring(n))
                if T.isSecret(id) then return T.secret(name) end
                return name
            end,
            GetSpellTexture = function(id)
                local n = T.reveal(id)
                if T.isSecret(id) then return T.secret(1000 + n) end
                return 1000 + n
            end,
        }
        M.IsPlayerSpell = function(id) return W.known[id] == true end
        M.SOUNDKIT = { RAID_WARNING = 8959, UI_BATTLEGROUND_COUNTDOWN_TIMER = 25477 }
        M.PlaySound = function(id) W.sounds[#W.sounds + 1] = { id = id, t = M.__now } end
        M.RaidWarningFrame = M.__stubFrame()
        M.ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.28, b = 0 } }
        M.RaidNotice_AddMessage = function(_, text) W.notices[#W.notices + 1] = { text = text, t = M.__now } end

        --- The sounds played with `id`, as their times.
        function W.SoundTimes(id)
            local out = {}
            for _, s in ipairs(W.sounds) do if s.id == id then out[#out + 1] = s.t end end
            return out
        end

        --- Every geometry read so far on an object that holds a secret.
        function W.SecretGeometryReads()
            local out = {}
            for _, r in ipairs(W.geomReads) do
                if W.secretFrames[r.frame] then out[#out + 1] = r.method end
            end
            return out
        end

        M.__widgets = W
        return W
    end

    return Widgets
end
