local _, NS = ...
-- modules/Hud.lua — the Race HUD's shell (spec §6.1): the window, its header and footer, which body
-- shows for the race's state, the countdown driver, the live-read throttle, the countdown cue and the
-- buzzer warning. The six bodies are modules/Hud_States.lua; the spell rows modules/Hud_Breakdown.lua.
--
-- THE WINDOW is a plain, non-secure frame (standalone-windows): skinned through NS.ApplySkin, closed
-- through NS.MakeCloseButton, in UISpecialFrames, clamped, resizable (300x460, min 260x296), with its
-- position and size in db.profile.windows.hud. Master scale and Lock frame (the General page's
-- `scale` and `locked` rows) act on it: it is the addon's positionable display. Built on first show.
--
-- SHOWN = the player wants it AND the master rungs allow it (NS.MasterVisibilityAllows: stood down,
-- test mode, General visibility). `hud.showMode` "onArm" (default) shows it when a race is armed or a
-- result arrives, and hides it again when the race it opened for goes back to idle; "always" also
-- shows it at login. The decision is IsShown(); the frame follows it in Refresh().
--
-- WHAT RUNS, AND WHEN (spec §10). While the window is shown: PLAYER_TARGET_CHANGED and the regen edges
-- (the idle target card and the Arm button's combat refusal). While it is shown AND the race is
-- RUNNING: DAMAGE_METER_COMBAT_SESSION_UPDATED, coalesced into one live read per 1/live.hz seconds
-- (4 Hz by default), never from OnUpdate. While shown and RUNNING or STOPPING: one OnUpdate, redrawing
-- at 20 Hz for the clock text while RUNNING and at 4 Hz while STOPPING (no clock; combat may hold for
-- minutes), the drop-combat spells asked once per race and the stop chips rebuilt only on a change.
-- Nothing else. The buzzer's raid warning answers RACE_BUZZER, with the window closed too. The
-- countdown cue and the center-screen numbers of the last seconds are modules/Countdown.lua's.
-- Stand-down (Suspend) drops every registration, timer and the OnUpdate.
--
-- NO DECISION FROM A METER VALUE. The body for STOPPING (Stop! or Waiting) is chosen from GetTime(),
-- the stored damage-update stamp (run.race.lastDamage) and the combat flag; live values go only to
-- the bodies' widget setters and NS.Format.Number.

local Hud = { wanted = false, locked = false }
NS.Hud = Hud

local L = NS.L
local Perf = NS.Perf

-- The title bar is the collection's (modules/Style.lua: 30px, the title centered in GameFontNormal).
local HEADER_H, FOOTER_H, PAD = NS.Style.TITLE_BAR_H, 20, 12
local CONTENT_TOP = HEADER_H + 10
local CONTENT_BOTTOM = FOOTER_H + 8

-- The default size is the defaults tree's (savedvariables-§2). The minimum width is the spec's; the
-- minimum height is the chrome plus the tallest body's fixed stack (modules/Hud_States.lua), so no
-- size the grip allows clips Arm or runs a body's rows into its buttons. The spec's 240 could not
-- hold the idle body: Arm at 162 px and the links under it need 228 px of content.
Hud.WIDTH = NS.defaults.profile.windows.hud.width
Hud.HEIGHT = NS.defaults.profile.windows.hud.height
Hud.MIN_WIDTH = 260
Hud.MIN_HEIGHT = CONTENT_TOP + NS.HudStates.MinContentHeight() + CONTENT_BOTTOM
-- The countdown text's refresh period (spec §10: 20 Hz).
Hud.TICK = 0.05
-- STOPPING has no clock to animate: its figures (seconds, one decimal, and the phase) redraw at 4 Hz.
Hud.STOP_TICK = 0.25
-- Abilities that drop combat, for the sticky-combat hint (spec §4.4): named only when known.
Hud.DROP_COMBAT = {
    { id = 5384, name = "Feign Death" }, { id = 1856, name = "Vanish" },
    { id = 58984, name = "Shadowmeld" }, { id = 66, name = "Invisibility" },
}
-- The target-count stepper's ceiling (a cleave group; spec §4.1).
Hud.MAX_TARGETS = 20
Hud.FRAME_NAME = "DpsRaceHud"

local SOUND_BUZZER = 8959    -- SOUNDKIT.RAID_WARNING
local BASE_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
local METER_EVENT = "DAMAGE_METER_COMBAT_SESSION_UPDATED"

local ui                       -- the built window
local events                   -- this module's AceEvent target (nil until first shown)
local registered = "none"      -- "none" | "idle" | "live"
local ticking, tickAcc = false, 0
local liveTimer, lastRead, liveData
local hiding = false           -- true while the addon hides the frame itself
local autoShown = false        -- the window was opened by onArm, not by the player
local preview                  -- what Hud.Render pushed while test mode is on
local pick = {}                -- the idle body's choices: length, count, target, editing
local dropNames                -- Hud.OwnedDropSpells() for this race, asked once (reset on arm)
-- pick.target and pick.count are the target of the moment only while the window is shown (the one
-- time PLAYER_TARGET_CHANGED is heard): forgotten on every show and on an arm from a closed window.

local function S() return NS.Race.STATE end

local function debug(fmt, ...)
    if NS.Debug then NS.Debug("Hud", fmt, ...) end
end

-- ── settings and stored state ───────────────────────────────────────────────────────────────────

-- The shipped default for a profile path: defaults/Profile.lua is the only place a default is
-- written (savedvariables-§2), so no literal fallback lives here.
local function shipped(path)
    local node = NS.defaults and NS.defaults.profile
    for key in path:gmatch("[^.]+") do
        if type(node) ~= "table" then return nil end
        node = node[key]
    end
    return node
end

local function setting(path)
    local v = NS.GetSetting(path)
    if v == nil then return shipped(path) end
    return v
end

--- db.profile.windows.hud: position and size (standalone-windows).
local function store()
    local p = NS.db and NS.db.profile
    if not p then return nil end
    p.windows = p.windows or {}
    p.windows.hud = p.windows.hud or {}
    return p.windows.hud
end

local function storedSize()
    local w = store() or {}
    local width = math.max(Hud.MIN_WIDTH, tonumber(w.width) or Hud.WIDTH)
    local height = math.max(Hud.MIN_HEIGHT, tonumber(w.height) or Hud.HEIGHT)
    return width, height
end

--- The race length the idle body offers: the pick, else the last one raced, else the default.
local function currentLength()
    if pick.length then return pick.length end
    local p = NS.db and NS.db.profile
    local last = p and p.race and p.race.lastLength
    if type(last) == "number" then return last end
    return setting("race.defaultLength")
end

local function rememberLength(n)
    local p = NS.db and NS.db.profile
    if p and p.race then p.race.lastLength = n end
end

--- The Default race length row's reaction: a new default replaces the remembered pick, in this
--- session and the stored one, so the setting takes effect on the HUD and the Arm key.
function Hud.ForgetLength()
    pick.length = nil
    local p = NS.db and NS.db.profile
    if p and p.race then p.race.lastLength = nil end
    Hud.Refresh()
end

local function previewOn()
    return NS.Preview ~= nil and NS.Preview.IsActive() == true
end

-- ── sounds ──────────────────────────────────────────────────────────────────────────────────────

local function play(kitName, fallback)
    if type(PlaySound) ~= "function" then return end
    local id = (SOUNDKIT and SOUNDKIT[kitName]) or fallback
    pcall(PlaySound, id, "Master")
end

--- The buzzer (spec §4.4): a raid-warning STOP and a sound, when the setting allows.
local function buzzer()
    if setting("race.buzzer") == false then return end
    play("RAID_WARNING", SOUND_BUZZER)
    local notice, frame = RaidNotice_AddMessage, RaidWarningFrame
    if type(notice) ~= "function" or not frame then return end
    pcall(notice, frame, L["STOP"], ChatTypeInfo and ChatTypeInfo.RAID_WARNING)
end

-- ── the view: what the body shows ───────────────────────────────────────────────────────────────

local BODY_OF = { idle = "idle", armed = "armed", running = "running", result = "result" }

local function inCombat()
    return UnitAffectingCombat("player") and true or false
end

-- Seconds since the run's last damage update (the stored stamp), or since the buzzer when none came.
local function quietFor(run)
    local elapsed = NS.Race.Elapsed()
    local last = run and run.race and run.race.lastDamage
    if not elapsed then return 0 end
    if type(last) ~= "number" then return NS.Race.SinceBuzzer() or 0 end
    return elapsed - last
end

--- STOPPING is one state shown in two phases (spec §4): Stop! while damage may still land, Waiting
--- once the tail has gone quiet (for combat to end, or for the read); a run that ended before the
--- buzzer waits for its read.
local function stopPhase(run)
    if NS.Race.SinceBuzzer() == nil then return "waiting" end
    if quietFor(run) >= NS.Scoring.QUIET_BEFORE_READ then return "waiting" end
    return "stop"
end

local function tailOf(run)
    local last, length = run.race and run.race.lastDamage, run.race and run.race.length
    if type(last) ~= "number" or type(length) ~= "number" then return 0 end
    return math.max(0, last - length)
end

--- The names of the combat-drop abilities this character has, joined with "or" (spec §4.4).
function Hud.OwnedDropSpells()
    local known, names = IsPlayerSpell, {}
    if type(known) ~= "function" then return names end
    for _, spell in ipairs(Hud.DROP_COMBAT) do
        local ok, has = pcall(known, spell.id)
        if ok and has then
            local name = NS.HudBreakdown.SpellName(spell.id)
            if name == L["Unknown spell"] then name = L[spell.name] end
            names[#names + 1] = name
        end
    end
    return names
end

local function hintText()
    dropNames = dropNames or Hud.OwnedDropSpells()
    local names = dropNames
    if #names == 0 then return L["Combat is holding. Walk out of range. Your score is safe: it waits for combat to end, however long that takes."] end
    return L["Combat is holding. Walk out of range, or use %s. Your score is safe: it waits for combat to end, however long that takes."]
        :format(table.concat(names, L[" or "]))
end

local function stopView(v)
    local run = v.run
    v.key = stopPhase(run)
    v.tail = tailOf(run)
    v.sinceBuzzer = NS.Race.SinceBuzzer()
    v.endedEarly = v.sinceBuzzer == nil
    v.endedAt = run.result and run.result.endedAt
    v.lateCasts = run.flags and run.flags.lateCasts
    v.grace = run.race and run.race.grace
    local delay = setting("race.hintDelay")
    if v.key == "waiting" and v.inCombat and (v.sinceBuzzer or 0) >= delay then v.hint = hintText() end
end

-- Why Arm would refuse right now, for the idle body (spec §4.1, §9): the pending run first.
local function armBlocker()
    if #NS.Recorder.Pending() > 0 then return "pending" end
    if inCombat() then return "in_combat" end
    local ok, why = NS.Meter.IsAvailable()
    if not ok then return "meter_unavailable", why end
    return nil
end

local function targetWarning(target)
    if target.category ~= "other" then return nil end
    if target.name then return L["Unknown target: recorded as Other: %s"]:format(target.name) end
    return L["No target: the one you fight is read when combat starts."]
end

local function idleView(v)
    if not pick.target then pick.target = NS.Recorder.SnapshotTarget("target") end
    local target = pick.target
    v.target = target
    v.count = pick.count or target.count or 1
    v.length = currentLength()
    v.editing = pick.editing
    v.blocker, v.detail = armBlocker()
    v.warning = targetWarning(target)
end

local function resultView(v)
    local run = v.run
    if run.status == "complete" then v.delta, v.isNew = NS.Bests.Delta(run) end
    v.canShare = NS.Share ~= nil and type(NS.Share.Prompt) == "function"
    v.icons = setting("live.icons") ~= false
end

local function runningView(v)
    v.timeLeft = NS.Race.TimeLeft()
    local length = v.run and v.run.race and v.run.race.length
    local elapsed = NS.Race.Elapsed()
    if elapsed and length then elapsed = math.min(elapsed, length) end
    v.elapsed = elapsed
    v.live = liveData
end

local FILL = { idle = idleView, running = runningView, result = resultView }

local function commonView(v)
    v.rows = setting("live.rows")
    v.icons = setting("live.icons") ~= false
    v.showDps = setting("live.showDps") ~= false
    v.hz = setting("live.hz")
    v.clockMode = setting("hud.clock")
end

local function raceView()
    local state = NS.Race.State()
    local v = { state = state, run = NS.Race.Current(), inCombat = inCombat() }
    commonView(v)
    if state == S().STOPPING then
        stopView(v)
        return v
    end
    v.key = BODY_OF[state] or "idle"
    if not v.run then v.key = "idle" end
    local fill = FILL[v.key]
    if fill then fill(v) end
    return v
end

-- Test mode: the body Hud.Render pushed, its figures as given (the preview owns them).
local function previewView()
    local v = { state = preview.key, run = preview.run, inCombat = false, preview = true }
    commonView(v)
    for k, x in pairs(preview.extra or {}) do v[k] = x end
    v.key = BODY_OF[preview.key] or preview.key
    if v.key == "stopping" then v.key = "stop" end
    if v.key == "idle" then idleView(v) end
    return v
end

local function buildView()
    if previewOn() and preview then return previewView() end
    preview = nil
    return raceView()
end
Hud.View = buildView

-- ── the window ──────────────────────────────────────────────────────────────────────────────────

local function contentWidth()
    if ui and ui.width then return ui.width - 2 * PAD end
    local width = storedSize()
    return width - 2 * PAD
end

-- The content frame's height: the window's tracked height less the chrome and the test strip.
local function contentHeight()
    local height = ui and ui.height
    if not height then height = select(2, storedSize()) end
    return height - CONTENT_TOP - ((ui and ui.drop) or 0) - CONTENT_BOTTOM
end

local function layoutBodies()
    local width, height = contentWidth(), contentHeight()
    for _, body in pairs(ui.body) do
        if body.Layout then body:Layout(width, height) end
    end
end

local function applyPlacement()
    local f, w = ui.frame, store() or {}
    local width, height = storedSize()
    ui.width, ui.height = width, height
    f:ClearAllPoints()
    f:SetPoint(w.point or "CENTER", UIParent, w.relativePoint or "CENTER", w.x or 0, w.y or 0)
    f:SetSize(width, height)
    f:SetScale(setting("scale"))
    layoutBodies()
end

-- The shell frame never displays a meter value (only its descendants do), so its own anchor is
-- read back here, the one geometry read in the HUD.
local function savePosition()
    local w = store()
    if not (w and ui) then return end
    local point, _, relativePoint, x, y = ui.frame:GetPoint(1)
    if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
    w.point, w.relativePoint = point, type(relativePoint) == "string" and relativePoint or point
    w.x, w.y = math.floor(x + 0.5), math.floor(y + 0.5)
end

local function onResized(width, height)
    if type(width) == "number" then ui.width = math.max(Hud.MIN_WIDTH, width) end
    if type(height) == "number" then ui.height = math.max(Hud.MIN_HEIGHT, height) end
    layoutBodies()
end

local function saveSize(width, height)
    local w = store()
    if not w then return end
    if type(width) == "number" then w.width = math.floor(width + 0.5) end
    if type(height) == "number" then w.height = math.floor(height + 0.5) end
end

-- One title-bar control, the `slot`-th from the right edge, vertically centered in the title bar.
local function placeControl(b, f, slot)
    b:SetPoint("RIGHT", f, "TOPRIGHT", -6 - slot * NS.Style.CONTROL_PITCH, -HEADER_H / 2)
end

-- The title bar: the title centered (GameFontNormal, gold once ApplySkin tints it), the divider, and
-- the four controls on the right, each gold under the pointer (one shared strip, modules/Style.lua).
local function buildHeader(f)
    local Style = NS.Style
    f.title = f:CreateFontString(nil, "OVERLAY", Style.FONT.TITLE)
    f.title:SetPoint("CENTER", f, "TOP", 0, -HEADER_H / 2)
    f.title:SetText(L["DPS Race"])
    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetHeight(1)
    f.divider:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -HEADER_H)
    f.divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -HEADER_H)
    ui.controls = Style.NewStrip()
    local close = NS.MakeCloseButton(f, function() Hud.Act.close() end)
    if close then placeControl(close, f, 0) end
    ui.close = Style.AddToStrip(ui.controls, close)
    ui.lock = Style.ControlButton(f, "unlock", "L", L["Lock or unlock the HUD"], function() Hud.Act.lock() end)
    ui.settings = Style.ControlButton(f, "settings", "S", L["Settings"], function() Hud.Act.settings() end)
    ui.results = Style.ControlButton(f, "chart", "R", L["Results"], function() Hud.Act.results() end)
    for slot, b in ipairs({ ui.lock, ui.settings, ui.results }) do
        placeControl(b, f, slot)
        Style.AddToStrip(ui.controls, b)
    end
    -- The drag strip: the title bar left of the controls.
    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    drag:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -(8 + 4 * NS.Style.CONTROL_PITCH), -HEADER_H)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() if not Hud.locked then f:StartMoving() end end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        savePosition()
    end)
    ui.drag = drag
end

local function buildFooter(f)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(0.24, 0.24, 0.27, 0.85)
    line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, FOOTER_H)
    line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, FOOTER_H)
    -- The footer's two lines are GameFontDisableSmall, as every Ka0s window's footer is.
    ui.footLeft = NS.Style.Text(f, NS.Style.FONT.CAPTION)
    ui.footLeft:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 5)
    ui.footRight = NS.Style.Text(f, NS.Style.FONT.CAPTION, nil, "RIGHT")
    ui.footRight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 5)
end

local onHide

local function ensureWindow()
    if ui then return ui end
    local f = CreateFrame("Frame", Hud.FRAME_NAME, UIParent, "BackdropTemplate")
    ui = { frame = f, body = {} }
    f:Hide()
    f:SetFrameStrata(NS.Constants.LAYERS.STRATA.HUD)
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    buildHeader(f)
    buildFooter(f)
    ui.content = CreateFrame("Frame", nil, f)
    ui.content:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -CONTENT_TOP)
    ui.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, CONTENT_BOTTOM)
    ui.content:SetClipsChildren(true)
    NS.ApplySkin(f)
    f:SetScript("OnHide", function() onHide() end)
    -- Escape closes it with the standard close stack (standalone-windows).
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, Hud.FRAME_NAME) end
    NS.MakeResizable(f, {
        minWidth = Hud.MIN_WIDTH, minHeight = Hud.MIN_HEIGHT,
        canResize = function() return not Hud.locked end,
        onResize = onResized,
        onResizeStop = saveSize,
    })
    applyPlacement()
    debug("window built")
    return ui
end

local function applyLock()
    NS.Style.SetControlIcon(ui.lock, Hud.locked and "lock" or "unlock", Hud.locked and "L" or "U")
    local grip = ui.frame.resizeGrip
    if grip then grip:SetShown(not Hud.locked) end
end

-- ── the test-mode marker (preview-mode) ─────────────────────────────────────────────────────────
-- While test mode is on the HUD says so on the display: the library's strip under the title bar, the
-- content moved down by its height. With no Widgets library there is no strip, and the title carries
-- the word instead; never both (one marker per mode).

local function titleMarked()
    return previewOn() and not (ui and ui.strip)
end

local function titleText()
    if titleMarked() then return L["DPS Race \194\183 Test"] end
    return L["DPS Race"]
end

-- The plain title is centered. The marked one is too long to center at the minimum width without
-- reaching the controls, so it sits left and stops where the drag strip does.
local function placeTitle(marked)
    if ui.titleMarked == marked then return end
    ui.titleMarked = marked
    local t = ui.frame.title
    t:ClearAllPoints()
    if marked then
        t:SetPoint("LEFT", ui.frame, "TOPLEFT", 10, -HEADER_H / 2)
        t:SetPoint("RIGHT", ui.drag, "RIGHT", -4, 0)
        t:SetJustifyH("LEFT")
    else
        t:SetPoint("CENTER", ui.frame, "TOP", 0, -HEADER_H / 2)
        t:SetJustifyH("CENTER")
    end
end

--- The title the window shows now, for the suites.
function Hud.TitleText() return titleText() end

local function ensureStrip()
    if ui.stripTried then return ui.strip end
    ui.stripTried = true
    -- What test mode shows and what ends it, in one line short enough for the minimum width.
    local strip = NS.MakeTestStrip(ui.frame, L["Test mode: sample numbers. Combat or Arm ends it"])
    if strip then
        strip:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 1, -(HEADER_H + 1))
        strip:SetPoint("TOPRIGHT", ui.frame, "TOPRIGHT", -1, -(HEADER_H + 1))
    end
    ui.strip = strip
    return strip
end

local function applyTestMarker()
    local on = previewOn()
    local strip = on and ensureStrip() or ui.strip
    if strip then strip:SetShown(on) end
    local drop = (on and strip) and NS.TEST_STRIP_HEIGHT or 0
    if ui.drop ~= drop then
        ui.drop = drop
        ui.content:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", PAD, -(CONTENT_TOP + drop))
        layoutBodies()
    end
    placeTitle(titleMarked())
    ui.frame.title:SetText(titleText())
end

local function showBody(key)
    local body = ui.body[key]
    if not body then
        body = NS.HudStates.Build(key, ui.content)
        ui.body[key] = body
        if body.Layout then body:Layout(contentWidth(), contentHeight()) end
    end
    if ui.current ~= key then
        local old = ui.current and ui.body[ui.current]
        if old then old.frame:Hide() end
        ui.current = key
    end
    body.frame:Show()
    return body
end

local function footer(v)
    local char = (v.run and v.run.char) or NS.Recorder.SnapshotPlayer() or {}
    local parts = {}
    if char.spec then parts[#parts + 1] = char.spec end
    if char.name then parts[#parts + 1] = char.name end
    ui.footLeft:SetText(table.concat(parts, " \194\183 "))
    local right = type(char.ilvl) == "number" and L["ilvl %d"]:format(math.floor(char.ilvl)) or ""
    if v.key == "running" then right = L["live \194\183 %d Hz"]:format(v.hz) end
    if v.key == "waiting" then right = L["result pending"] end
    ui.footRight:SetText(right)
end

--- Draw the body for the current view. `full` also redraws the live rows (a tick does not).
local function render(full)
    local v = buildView()
    local body = showBody(v.key)
    body:Update(v)
    if full and body.SetLive then body:SetLive(v.live, v.rows, v.icons) end
    footer(v)
    return v
end

-- ── what runs while shown ───────────────────────────────────────────────────────────────────────

local function windowShown()
    return ui ~= nil and ui.frame:IsShown() == true
end

local function liveWanted()
    return windowShown() and not NS.IsStoodDown() and not previewOn() and NS.Race.State() == S().RUNNING
end

local function cancelLive()
    if liveTimer then liveTimer:Cancel() end
    liveTimer = nil
end

--- One live read and redraw: the running body's figures and rows from NS.Meter.ReadLive (opaque).
local function readLive()
    liveTimer = nil
    if not liveWanted() then return end
    local t0 = Perf.on and debugprofilestop()
    lastRead = GetTime()
    liveData = NS.Meter.ReadLive() or liveData
    local body = ui.body.running
    if body and ui.current == "running" then
        body:SetLive(liveData, setting("live.rows"), setting("live.icons") ~= false)
    end
    if t0 then Perf.Note("hudLive", debugprofilestop() - t0) end
end
Hud.ReadLive = readLive

--- A meter update: coalesced into at most one read per 1/live.hz seconds (spec §10).
local function requestLive()
    if liveTimer or not liveWanted() then return end
    local hz = math.max(1, tonumber(setting("live.hz")) or 1)
    local wait = 0
    if lastRead then wait = math.max(0, lastRead + 1 / hz - GetTime()) end
    liveTimer = C_Timer.NewTimer(wait, readLive)
end

-- An AceEvent function handler: (event, ...).
local function onAceEvent(event)
    if NS.IsStoodDown() then return end
    if event == METER_EVENT then return requestLive() end
    if event == "PLAYER_TARGET_CHANGED" then pick.target, pick.count = nil, nil end
    Hud.Refresh()
end

local function wantedEvents()
    if not windowShown() or NS.IsStoodDown() then return "none" end
    if liveWanted() then return "live" end
    return "idle"
end

local function syncEvents()
    local want = wantedEvents()
    if want ~= "live" then cancelLive() end
    if want == registered then return end
    if events then events:UnregisterAllEvents() end
    registered = want
    if want == "none" then return end
    -- Its own AceEvent target (events-frames-taint-§1): keyed apart from the addon object and
    -- modules/Watchers.lua, so the same PLAYER_REGEN_* on each never clobbers another's handler.
    if not events then events = LibStub("AceEvent-3.0"):Embed({}) end
    for _, event in ipairs(BASE_EVENTS) do NS.SafeRegisterEvent(events, event, onAceEvent, NS.rejectedEvents) end
    if want == "live" then
        NS.SafeRegisterEvent(events, METER_EVENT, onAceEvent, NS.rejectedEvents)
        requestLive()
    end
end

local function onUpdate(_, elapsed)
    tickAcc = tickAcc + (elapsed or 0)
    local period = NS.Race.State() == S().STOPPING and Hud.STOP_TICK or Hud.TICK
    if tickAcc < period - 1e-9 then return end
    tickAcc = 0
    local t0 = Perf.on and debugprofilestop()
    render(false)
    if t0 then Perf.Note("hudTick", debugprofilestop() - t0) end
end
Hud.Tick = function() tickAcc = Hud.STOP_TICK; onUpdate(nil, 0) end

local function syncTicker()
    local state = NS.Race.State()
    local want = windowShown() and not previewOn() and (state == S().RUNNING or state == S().STOPPING)
    if want and not ticking then
        tickAcc = 0
        ui.frame:SetScript("OnUpdate", onUpdate)
    elseif not want and ticking then
        ui.frame:SetScript("OnUpdate", nil)
    end
    ticking = want and true or false
end

local function hideWindow()
    if windowShown() then
        hiding = true
        ui.frame:Hide()
        hiding = false
    end
    syncTicker()
    syncEvents()
end

-- The frame went away by Escape or by the close control: the player closed it. A result card closed
-- is a result dismissed (the run stays in history). A frame still shown in its own right was hidden
-- with its parent (the interface hidden, a cinematic), which is not the player closing it. In test
-- mode the card on screen is the sample, not the race's: closing the window ends test mode and
-- leaves a real result card the preview covered as it was.
function onHide()
    if hiding or (ui and ui.frame:IsShown()) then return end
    Hud.wanted, autoShown = false, false
    syncTicker()
    syncEvents()
    if previewOn() then
        NS.Preview.Stop()
        return
    end
    if NS.Race.State() == S().RESULT and not NS.IsStoodDown() then NS.Race.Cancel() end
end

-- ── the public surface ──────────────────────────────────────────────────────────────────────────

--- Whether the HUD decides to show: wanted, and the master rungs allow it.
function Hud.IsShown()
    return Hud.wanted and (NS.MasterVisibilityAllows()) or false
end

--- Re-decide and redraw. The one place the frame follows the decision.
function Hud.Refresh()
    Hud.locked = NS.GetSetting("locked") == true
    if not Hud.IsShown() then return hideWindow() end
    ensureWindow()
    applyLock()
    applyTestMarker()
    ui.frame:SetScale(setting("scale"))
    if not windowShown() then
        pick.target, pick.count = nil, nil
        ui.frame:Show()
    end
    render(true)
    syncEvents()
    syncTicker()
end

function Hud.Show()
    Hud.wanted, autoShown = true, false
    Hud.Refresh()
end

function Hud.Hide()
    Hud.wanted, autoShown = false, false
    Hud.Refresh()
end

function Hud.Toggle()
    if Hud.IsShown() then Hud.Hide() else Hud.Show() end
end

--- The Lock frame row's reaction: no drag, no resize while locked.
function Hud.SetLocked(on)
    Hud.locked = on and true or false
    if ui then applyLock() end
end

--- Back to the default place and size (the Master controls' Reset position).
function Hud.ResetPosition()
    local w = store()
    if w then w.point, w.relativePoint, w.x, w.y, w.width, w.height = nil, nil, nil, nil, nil, nil end
    if ui then applyPlacement() end
end

--- Draw `state`'s body with the given run (and figures) instead of the race's: test mode's entry
--- point (modules/Preview.lua). Ignored unless test mode is on. `extra` carries the figures a body
--- reads off its view (timeLeft, live, tail, sinceBuzzer, inCombat, hint, delta, isNew ...).
--- @param state string  a Race.STATE value, or "stop" / "waiting"
--- @param run table|nil
--- @param extra table|nil
function Hud.Render(state, run, extra)
    preview = { key = state, run = run, extra = extra }
    Hud.Refresh()
end

--- The lifecycle's stand-down: the window hides, and every registration, timer and the OnUpdate go.
--- A window the addon opened (onArm, test mode) is dropped: the race or preview it opened for is gone
--- (Race.Suspend goes to idle without a message), so the stand-up must not bring it back.
function Hud.Suspend()
    if autoShown then Hud.wanted, autoShown = false, false end
    cancelLive()
    hideWindow()
    if events then events:UnregisterAllEvents() end
    registered = "none"
end

--- The stand-up (and OnEnable): "always" shows the window; then re-decide from current state.
function Hud.Resume()
    if setting("hud.showMode") == "always" then Hud.wanted = true end
    Hud.Refresh()
end

-- ── the race, heard on the bus ──────────────────────────────────────────────────────────────────

local function autoShow()
    if Hud.wanted then return end
    Hud.wanted, autoShown = true, true
end

--- Show the window as the addon's own opening, not the player's: test mode's (modules/Preview.lua).
--- A race armed while it is up inherits it, so onArm closes it when that race goes back to idle.
function Hud.AutoShow()
    autoShow()
    Hud.Refresh()
end

local function onState(_, from, to)
    local St = S()
    if to == St.ARMED then
        liveData, lastRead, dropNames = nil, nil, nil
        NS.Meter.NewLiveRace()
        pick.editing = false
        autoShow()
    end
    -- Straight from idle into a live race is the /reload (or stand-up) resume: its HUD comes back
    -- as the arm's did, and closes with the race the same way.
    if from == St.IDLE and (to == St.RUNNING or to == St.STOPPING) then autoShow() end
    if to == St.IDLE and autoShown and not previewOn() and setting("hud.showMode") == "onArm" then
        Hud.wanted, autoShown = false, false
    end
    debug("race %s -> %s", tostring(from), tostring(to))
    Hud.Refresh()
end

do
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.RACE_STATE_CHANGED, function(_, run, from, to) onState(run, from, to) end)
        bus:RegisterMessage(NS.MSG.RACE_BUZZER, function() buzzer() end)
        bus:RegisterMessage(NS.MSG.RACE_RESULT, function()
            autoShow()
            Hud.Refresh()
        end)
    end
end

-- ── the acts the bodies' buttons run ────────────────────────────────────────────────────────────

local Act = {}
Hud.Act = Act

local function openRun(run)
    local R = NS.Results
    if not (run and R) then return end
    if type(R.ShowRun) == "function" then R.ShowRun(run.id) else R.Show() end
end

local function arm(length, count)
    local ok, reason, detail = NS.Race.Arm(length, count)
    if not ok then NS.Print(NS.Format.ArmRefusal(reason, detail)) end
    Hud.Refresh()
    return ok, reason
end

function Act.arm()
    -- Closed, the HUD heard no target change: the cached target and its stepped count may be stale.
    if not windowShown() then pick.target, pick.count = nil, nil end
    return arm(currentLength(), pick.count)
end

function Act.pickLength(n)
    pick.length, pick.editing = n, false
    rememberLength(n)
    Hud.Refresh()
end

function Act.openCustom()
    pick.editing = true
    Hud.Refresh()
end

function Act.closeCustom()
    pick.editing = false
    Hud.Refresh()
end

--- A typed race length ("90", "1:30", "3m"); refused with the length line when out of range.
function Act.customLength(text)
    local n = NS.Format.ParseLength(text)
    if not n or n < NS.Race.MIN_LENGTH or n > NS.Race.MAX_LENGTH then
        NS.Print(NS.Format.ArmRefusal("bad_length"))
        return false
    end
    Act.pickLength(n)
    return true
end

function Act.stepCount(delta)
    local target = pick.target or {}
    local n = (pick.count or target.count or 1) + delta
    pick.count = math.max(1, math.min(Hud.MAX_TARGETS, n))
    Hud.Refresh()
end

-- In test mode the bodies are the sample's: Cancel and Discard Run end test mode, never the real
-- race the preview may be covering (a result card), and the sample card's Race Again and Details
-- (drawn disabled) do nothing.
function Act.cancel()
    if previewOn() then return NS.Preview.Stop() end
    return NS.Race.Cancel()
end
Act.discard = Act.cancel

function Act.close()
    -- In the client Hide runs OnHide, which is onHide; called again only if that did not happen.
    if windowShown() then ui.frame:Hide() end
    if Hud.wanted then
        if ui then onHide() else Hud.wanted = false end
    end
end

function Act.lock() return NS.ToggleLock() end
function Act.settings() return NS.OpenOptionsPanel() end
function Act.results() return NS.ToggleResults() end
function Act.details()
    if previewOn() then return false end
    openRun(NS.Race.Current())
end

--- Race Again: back to the Arm Race screen (the owner's call, 2026-10-24), not straight to an armed
--- race. The result card is dismissed (the run is kept), the window stays open as the player's, and
--- the idle body is set to the same length and target count, so Arm Race repeats the race.
function Act.raceAgain()
    if previewOn() then return false end
    local run = NS.Race.Current()
    local length = run and run.race and run.race.length or currentLength()
    local count = run and run.target and run.target.count
    -- Kept open through the idle edge: the onArm close is for a race that is over, not this one.
    autoShown = false
    if NS.Race.State() == S().RESULT then NS.Race.Cancel() end
    pick.count = count
    Act.pickLength(length)
    return true
end

function Act.share()
    local run = NS.Race.Current()
    if run and NS.Share and type(NS.Share.Prompt) == "function" then NS.Share.Prompt(run) end
end

--- What the HUD is doing, for the diagnostics report: the body on screen, the event set it holds
--- ("none" | "idle" | "live"), whether the countdown OnUpdate is attached, and the lock.
function Hud.Diagnose()
    return { body = ui and ui.current or "none", events = registered, ticking = ticking, locked = Hud.locked,
             height = (ui and ui.height) or select(2, storedSize()) }
end

--- The built window and its bodies, for the suites (nil until first shown).
function Hud.__ui() return ui end
