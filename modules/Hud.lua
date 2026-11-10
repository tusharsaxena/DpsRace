local _, NS = ...
-- modules/Hud.lua — the Race HUD's shell (spec §6.1): the window, its header and footer, which body
-- shows for the race's state, the countdown driver, the live-read throttle, the countdown cue and the
-- buzzer warning. The six bodies are modules/Hud_States.lua; the spell rows modules/Hud_Breakdown.lua.
--
-- THE WINDOW is a plain, non-secure frame (standalone-windows): skinned through NS.ApplySkin, closed
-- through NS.MakeCloseButton, in UISpecialFrames, clamped, with its position and width in
-- db.profile.windows.hud (260 wide by default, the minimum: a new profile opens at it). Master scale
-- and Lock frame (the General page's `scale` and `locked` rows) act on it: it is the addon's
-- positionable display. Built on first show.
--
-- ITS SIZE (the v0.2 sizing model, Combat Trail's plan decisions D2 and D9) is `hud.sizeMode`'s:
--   "fixed" (default)  the height is Hud.FixedHeight(): the chrome plus HudStates.FixedContentHeight,
--                      the content every body takes with `hud.bars` spell rows, worked out from the
--                      configuration alone, so the window is the same whatever the race holds and
--                      whichever body shows. The library's grip (modules/Sizing.lua) sizes it, shown
--                      only in this mode and not while locked: while it is held the body on screen
--                      lays out at the dragged size with as many rows as fit, and the release stores
--                      the width (MIN_WIDTH-MAX_WIDTH) and `hud.bars`, the whole rows the height holds
--                      (MIN_BARS-MAX_BARS), and the window snaps to them.
--   "auto"             the height is the body's stack (never under the idle body's), growing with the
--                      rows up to `hud.bars`; `hud.grow` picks the edge that stays put ("down": the
--                      top, "up": the bottom).
-- In both, spells past the rows scroll with the wheel (modules/Hud_States.lua). An auto-grow window's
-- edge holds because the stored anchor is on it: a drag of the title bar, a change of the mode or the
-- edge, and any Refresh that finds the stored point off the edge re-anchor it (normalizeAnchor) to
-- TOPLEFT ("down") or BOTTOMLEFT ("up") on UIParent's BOTTOMLEFT, from the shell frame's own edges. A
-- grip release re-anchors a fixed window to TOPLEFT, so the snap keeps its top; a fixed window's
-- title-bar drag stores the client's own point, as before the model.
--
-- SHOWN = the player wants it AND the master rungs allow it (NS.MasterVisibilityAllows: stood down,
-- test mode, General visibility). `hud.showMode` "onArm" (default) shows it when a race is armed or a
-- result arrives, and hides it again when the race it opened for goes back to idle; "always" also
-- shows it at login. Auto-show (#16, `hud.autoShow`, modules/AutoArm.lua) opens it near a training
-- dummy through ShowNearDummy and closes it through HideAwayFromDummy; a race going back to idle leaves
-- that window open. The decision is IsShown(); the frame follows it in Refresh().
--
-- WHAT RUNS, AND WHEN (spec §10). While the window is shown: PLAYER_TARGET_CHANGED and the regen edges
-- (the idle target card and the Arm button's combat refusal). While it is shown AND the race is
-- RUNNING: DAMAGE_METER_COMBAT_SESSION_UPDATED, coalesced into one live read per 1/live.hz seconds
-- (4 Hz by default), never from OnUpdate, and one timer at the damage chart's next bucket boundary
-- (at most 60 a race), so the chart's buckets fill in a quiet stretch too. While shown and RUNNING or
-- STOPPING: one OnUpdate, redrawing at 20 Hz for the clock text while RUNNING and at 4 Hz while
-- STOPPING (no clock; combat may hold for minutes), the drop-combat spells asked once per race and the
-- stop chips rebuilt only on a change.
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

-- The default width is the defaults tree's (savedvariables-§2); the minimum is the spec's, and the
-- most the grip allows. The height is derived (ITS SIZE, above), never stored: the fewest rows is
-- MIN_BARS of the stack, which never goes under the idle body's (the spec's 240 could not hold it).
Hud.WIDTH = NS.defaults.profile.windows.hud.width
Hud.MIN_WIDTH = 260
Hud.MAX_WIDTH = 600
Hud.MIN_BARS, Hud.MAX_BARS = 1, 15   -- the spell rows `hud.bars` holds
-- The countdown text's refresh period (spec §10: 20 Hz).
Hud.TICK = 0.05
-- STOPPING has no clock to animate: its figures (seconds, one decimal, and the phase) redraw at 4 Hz.
Hud.STOP_TICK = 0.25
-- Abilities that drop combat, for the sticky-combat hint (spec §4.4): named only when known.
Hud.DROP_COMBAT = {
    { id = 5384, name = "Feign Death" }, { id = 1856, name = "Vanish" },
    { id = 58984, name = "Shadowmeld" }, { id = 66, name = "Invisibility" },
}
Hud.FRAME_NAME = "DpsRaceHud"

local SOUND_BUZZER = 8959    -- SOUNDKIT.RAID_WARNING
-- PLAYER_SPECIALIZATION_CHANGED: the idle body's Your best board is the spec's (R3-DR-4).
local BASE_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                      "PLAYER_SPECIALIZATION_CHANGED" }
local METER_EVENT = "DAMAGE_METER_COMBAT_SESSION_UPDATED"

local ui                       -- the built window
local events                   -- this module's AceEvent target (nil until first shown)
local registered = "none"      -- "none" | "idle" | "live"
local ticking, tickAcc = false, 0
local liveTimer, lastRead, liveData
local sliceTimer               -- the next chart bucket's boundary (modules/Slices.lua)
local hiding = false           -- true while the addon hides the frame itself
local autoShown = false        -- the window was opened by onArm, not by the player
-- The window was opened because a training dummy is near (#16, modules/AutoArm.lua's auto-show): a race
-- going back to idle leaves it open, and only HideAwayFromDummy (or the player) closes it.
local dummyShown = false
local closes = 0               -- how many times the player closed the window (AutoArm's manual-close rule)
local pick = {}                -- the idle body's choices: length, target, editing
local dropNames                -- Hud.OwnedDropSpells() for this race, asked once (reset on arm)
-- pick.target is the target of the moment only while the window is shown (the one
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

local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end

local function storedWidth()
    local w = store() or {}
    return clamp(tonumber(w.width) or Hud.WIDTH, Hud.MIN_WIDTH, Hud.MAX_WIDTH)
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

-- THE RACE ON SCREEN. While test mode or the sim is on it is the sample race (modules/SampleRace.lua):
-- the same queries, so every view below is built by one path, whichever race it shows.
local function raceNow()
    local sample = NS.SampleRace
    if previewOn() and sample and sample.On() then return sample end
    return NS.Race
end

local function sampleOn()
    return raceNow() ~= NS.Race
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
    if sampleOn() then return NS.SampleRace.InCombat() end
    return UnitAffectingCombat("player") and true or false
end

-- Seconds since the run's last damage update (the stored stamp), or since the buzzer when none came.
local function quietFor(run)
    local race = raceNow()
    local elapsed = race.Elapsed()
    local last = run and run.race and run.race.lastDamage
    if not elapsed then return 0 end
    if type(last) ~= "number" then return race.SinceBuzzer() or 0 end
    return elapsed - last
end

--- STOPPING is one state shown in two phases (spec §4): Stop! while damage may still land, Waiting
--- once the tail has gone quiet (for combat to end, or for the read); a run that ended before the
--- buzzer waits for its read.
local function stopPhase(run)
    if raceNow().SinceBuzzer() == nil then return "waiting" end
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
    v.sinceBuzzer = raceNow().SinceBuzzer()
    v.endedEarly = v.sinceBuzzer == nil
    v.endedAt = run.result and run.result.endedAt
    v.lateCasts = run.flags and run.flags.lateCasts
    v.grace = run.race and run.race.grace
    v.stopNow = raceNow().StopRequested()
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
    -- Read now (#9): the cached snapshot predates a change to your training dummies.
    if NS.Dummies.CategoryOf(target) ~= "other" then return nil end
    if target.name then return L["Unknown target: recorded as Other: %s"]:format(target.name) end
    return L["No target: the one you fight is read when combat starts."]
end

local function idleView(v)
    if not pick.target then pick.target = NS.Recorder.SnapshotTarget("target") end
    local target = pick.target
    v.target = target
    v.length = currentLength()
    v.editing = pick.editing
    v.blocker, v.detail = armBlocker()
    v.warning = targetWarning(target)
    v.best = NS.HudBest.View(target, v.length)
end

local function resultView(v)
    local run = v.run
    if run.status == "complete" then v.delta, v.isNew = NS.Bests.Delta(run) end
    -- A sample's made-up numbers never reach a chat channel.
    v.canShare = NS.Share ~= nil and type(NS.Share.Prompt) == "function" and not run.sample
    v.icons = setting("live.icons") ~= false
    -- The race's chart again (#2), when the HUD shows charts and the run has its slices this session.
    if setting("live.chart") ~= false then v.chart = NS.HudChart.ResultView(run) end
    -- The pace bar again (#3): the plain final damage against the best before the run.
    v.pace = NS.HudChart.ResultPace(run, setting("live.paceBar") ~= false)
end

local function runningView(v)
    local race = raceNow()
    v.timeLeft = race.TimeLeft()
    local length = v.run and v.run.race and v.run.race.length
    local elapsed = race.Elapsed()
    if elapsed and length then elapsed = math.min(elapsed, length) end
    v.elapsed = elapsed
    v.live = liveData
    v.chart, v.pace = NS.HudChart.LiveViews(v.run, elapsed, setting("live.chart") ~= false,
        setting("live.paceBar") ~= false, setting("live.castDots") ~= false)
end

local FILL = { idle = idleView, running = runningView, result = resultView }

local sizeView   -- the rows' window the view carries (the size, below)

local function commonView(v)
    sizeView(v)
    v.icons = setting("live.icons") ~= false
    v.showDps = setting("live.showDps") ~= false
    v.hz = setting("live.hz")
    v.clockMode = setting("hud.clock")
end

local function raceView()
    local race = raceNow()
    local state = race.State()
    local v = { state = state, run = race.Current(), inCombat = inCombat(), preview = previewOn() or nil }
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

Hud.View = raceView

-- ── the size (the v0.2 sizing model) ────────────────────────────────────────────────────────────

local function fixedMode() return setting("hud.sizeMode") ~= "auto" end

--- The spell rows `hud.bars` asks for, whole and in range.
local function bars()
    return clamp(math.floor(tonumber(setting("hud.bars")) or Hud.MIN_BARS), Hud.MIN_BARS, Hud.MAX_BARS)
end

-- The edge that stays put: "up" (the bottom) only for an auto-grow window told to grow up.
local function growEdge()
    return (not fixedMode() and setting("hud.grow") == "up") and "up" or "down"
end

-- The chrome over and under the content: the title bar, the test strip while it shows, the footer.
local function chromeHeight() return CONTENT_TOP + ((ui and ui.drop) or 0) + CONTENT_BOTTOM end

-- What the row bodies' stack is made of, from the settings: the clock mode, the chart and the pace bar.
local function stackOpts()
    return { mode = setting("hud.clock"), chart = setting("live.chart") ~= false,
             pace = setting("live.paceBar") ~= false }
end

-- A fixed window's height for `n` spell rows: the chrome and the content the configuration reserves.
local function fixedHeightFor(n)
    return chromeHeight() + NS.HudStates.FixedContentHeight(n, stackOpts())
end

--- The fixed window's height for `hud.bars` rows (the window's height in fixed mode).
--- @return number
function Hud.FixedHeight() return fixedHeightFor(bars()) end

-- The whole bars a fixed window `h` high holds, in range. The height bars() already takes keeps them
-- (with fewer rows than the idle body's height holds, several counts share one height).
local function barsFor(h)
    if math.abs(h - Hud.FixedHeight()) < 0.5 then return bars() end
    local room = h - chromeHeight() - NS.HudStates.RowsChrome(stackOpts())
    return clamp(NS.HudStates.RowCapacity(room), Hud.MIN_BARS, Hud.MAX_BARS)
end

-- Whether the grip is being dragged now and has handed on a size.
local function sizing()
    return ui ~= nil and ui.dragH ~= nil and NS.Sizing.IsSizing(ui.frame)
end

local function canResize() return not Hud.locked and fixedMode() end

-- The grip shown while it may size the window (fixed mode, not locked), and its bounds: MIN_BARS to
-- MAX_BARS rows of the stack configured now.
local function applyGrip()
    local f = ui.frame
    if f.resizeGrip then f.resizeGrip:SetShown(canResize()) end
    if type(f.SetResizeBounds) == "function" then
        f:SetResizeBounds(Hud.MIN_WIDTH, fixedHeightFor(Hud.MIN_BARS), Hud.MAX_WIDTH, fixedHeightFor(Hud.MAX_BARS))
    end
end

-- The rows' window the view carries (modules/Hud_States.lua): the bars, and a fixed window's content
-- height; while the grip is held, the dragged size's.
function sizeView(v)
    local drag = sizing()
    v.bars = drag and barsFor(ui.dragH) or bars()
    v.fitH = fixedMode() and ((drag and ui.dragH or Hud.FixedHeight()) - chromeHeight()) or nil
end

-- ── the window ──────────────────────────────────────────────────────────────────────────────────

-- The window's width and height now: the grip's while it is held, else the tracked ones.
local function windowWidth()
    if sizing() and ui.dragW then return ui.dragW end
    return (ui and ui.width) or storedWidth()
end

local function windowHeight()
    if sizing() then return ui.dragH end
    return (ui and ui.height) or Hud.FixedHeight()
end

local function contentWidth() return windowWidth() - 2 * PAD end

-- The content frame's height: the window's height less the chrome and the test strip.
local function contentHeight() return windowHeight() - chromeHeight() end

local function layoutBodies()
    local width, height = contentWidth(), contentHeight()
    for _, body in pairs(ui.body) do
        if body.Layout then body:Layout(width, height) end
    end
end

local function applyPlacement()
    local f, w = ui.frame, store() or {}
    ui.width = storedWidth()
    ui.height = ui.height or (fixedMode() and Hud.FixedHeight() or chromeHeight() + NS.HudStates.BaseContentHeight())
    f:ClearAllPoints()
    f:SetPoint(w.point or "CENTER", UIParent, w.relativePoint or "CENTER", w.x or 0, w.y or 0)
    f:SetSize(ui.width, ui.height)
    f:SetScale(setting("scale"))
    layoutBodies()
end

-- The shell frame never displays a meter value (only its descendants do), so its own anchor and its
-- edges (GetLeft, GetTop, GetBottom) are read back here, the only geometry reads in the HUD; each
-- answer is still taken only as a plain number (NS.Secrets.PlainNumber).
local function savePosition()
    local w = store()
    if not (w and ui) then return end
    local point, _, relativePoint, x, y = ui.frame:GetPoint(1)
    if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
    w.point, w.relativePoint = point, type(relativePoint) == "string" and relativePoint or point
    w.x, w.y = math.floor(x + 0.5), math.floor(y + 0.5)
end

local function edgeOf(f, name)
    local fn = f[name]
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, f)
    return ok and NS.Secrets.PlainNumber(v) or nil
end

-- Whether an anchor `point` sits on the grow edge: TOP* for "down", BOTTOM* for "up".
local function onEdge(point, edge)
    return type(point) == "string" and point:find(edge == "up" and "^BOTTOM" or "^TOP") ~= nil
end

--- Re-anchor the window on its grow edge where it stands: TOPLEFT (or BOTTOMLEFT for "up") on
--- UIParent's BOTTOMLEFT at the frame's own left and top (bottom) edge, stored in windows.hud.
--- Unless `force` (after a drag, whose anchor is the client's), a stored point already on the edge
--- is kept. Answers whether it re-anchored (false where the frame cannot say where it is).
local function normalizeAnchor(force)
    local w = store()
    if not (w and ui) then return false end
    local edge = growEdge()
    if not force and onEdge(w.point, edge) then return false end
    local f = ui.frame
    local left, y = edgeOf(f, "GetLeft"), edgeOf(f, edge == "up" and "GetBottom" or "GetTop")
    if not (left and y) then return false end
    w.point, w.relativePoint = edge == "up" and "BOTTOMLEFT" or "TOPLEFT", "BOTTOMLEFT"
    w.x, w.y = math.floor(left + 0.5), math.floor(y + 0.5)
    f:ClearAllPoints()
    f:SetPoint(w.point, UIParent, w.relativePoint, w.x, w.y)
    return true
end

-- An auto-grow window's place on its grow edge, where a Refresh finds it off the edge (an edge chosen
-- before the window was built, a profile switch). A fixed window keeps the point it has.
local function holdEdge()
    if not fixedMode() then normalizeAnchor(false) end
end

-- After a drag: `grip` (the grip's release) or an auto-grow window's title-bar drag stores the place
-- on the edge that stays put, else (or where the frame cannot say) the client's own point.
local function placeAfterDrag(grip)
    if (grip or not fixedMode()) and normalizeAnchor(true) then return end
    savePosition()
end

-- Every size change, the grip's or not: the size, in range, a drag lays out from (plain numbers only).
local function trackSize(width, height)
    width, height = NS.Secrets.PlainNumber(width), NS.Secrets.PlainNumber(height)
    if width then ui.dragW = clamp(width, Hud.MIN_WIDTH, Hud.MAX_WIDTH) end
    if height then ui.dragH = clamp(height, fixedHeightFor(Hud.MIN_BARS), fixedHeightFor(Hud.MAX_BARS)) end
end

-- The cheap half of a resize (modules/Sizing.lua): the body on screen alone, laid out at the dragged
-- size and drawn again with the rows that size holds (no meter read); the others wait for the release.
local render
local function layoutCurrent()
    local body = ui.current and ui.body[ui.current]
    if body and body.Layout then body:Layout(contentWidth(), contentHeight()) end
    render(true)
end

local function saveWidth(width)
    local w = store()
    if w and type(width) == "number" then w.width = math.floor(width + 0.5) end
end

-- The title bar on the skin's title band (Style.Header, R5-DR1): the title LEFT in every skin (item
-- 3a: the four controls crowd a centered title), and the four controls on the right: the close
-- control is the skin's own (S.CloseButton through Core, its hover `close.hot`), the other three turn
-- the accent under the pointer (one shared strip, modules/Style.lua). Each is on the band's middle.
local function buildHeader(f)
    local Style = NS.Style
    f.title = f:CreateFontString(nil, "OVERLAY", Style.FONT.TITLE)
    f.title:SetText(L["DPS Race"])
    -- No line under the title band (R4-SEP): every Ka0s window reads like the Skin Tester's showroom.
    ui.controls = Style.NewStrip()
    local close = NS.MakeCloseButton(f, function() Hud.Act.close() end)
    if close then NS.HudStates.AddTip(close, NS.HudTips.close) end
    ui.close = close
    ui.lock = Style.ControlButton(f, "unlock", "L", L["Lock or unlock the HUD"], function() Hud.Act.lock() end)
    ui.settings = Style.ControlButton(f, "settings", "S", L["Settings"], function() Hud.Act.settings() end)
    ui.results = Style.ControlButton(f, "chart", "R", L["Results"], function() Hud.Act.results() end)
    for _, b in ipairs({ ui.lock, ui.settings, ui.results }) do Style.AddToStrip(ui.controls, b) end
    -- The drag strip: the title band left of the controls.
    local drag = CreateFrame("Frame", nil, f)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() if not Hud.locked then f:StartMoving() end end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        placeAfterDrag(false)
    end)
    ui.drag = drag
    Style.Header(f, { title = f.title, align = "LEFT", drag = drag,
        right = { close, ui.lock, ui.settings, ui.results }, n = 4 })
end

local function buildFooter(f)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    NS.Skin.Divider(line)
    line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, FOOTER_H)
    line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, FOOTER_H)
    -- The footer's two lines are GameFontDisableSmall, as every Ka0s window's footer is.
    ui.footLeft = NS.Style.Text(f, NS.Style.FONT.CAPTION)
    ui.footLeft:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 5)
    ui.footRight = NS.Style.Text(f, NS.Style.FONT.CAPTION, nil, "RIGHT")
    ui.footRight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 5)
    local tips, States = NS.HudTips, NS.HudStates
    ui.footLeftTip = States.TipZone(f, ui.footLeft, tips.footLeft)
    ui.footRightTip = States.TipZone(f, ui.footRight, tips.footRight)
end

local onHide, resized

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
    -- Smooth resizing (modules/Sizing.lua): while the grip is dragged only the body on screen is laid
    -- out and drawn, once a frame; on release every body is laid out, the size stored, and the shown
    -- one drawn again at the snapped height.
    NS.Sizing.MakeResizable(f, {
        minWidth = Hud.MIN_WIDTH, minHeight = fixedHeightFor(Hud.MIN_BARS),
        canResize = function() return canResize() end,
        size = trackSize, layout = layoutCurrent, redraw = layoutBodies,
        done = function(w, h) resized(w, h) end,
    })
    applyPlacement()
    debug("window built")
    return ui
end

local function applyLock()
    NS.Style.SetControlIcon(ui.lock, Hud.locked and "lock" or "unlock", Hud.locked and "L" or "U")
    applyGrip()
end

-- ── the test-mode marker (preview-mode) ─────────────────────────────────────────────────────────
-- While test mode or the sim is on the HUD says so on the display: the library's strip under the title
-- bar, the content moved down by its height. Test mode shows the test strip and a running sim shows the
-- sim strip, never both (WFP-FIX-01). With no Widgets library there is no strip, and the title carries
-- the word instead; never both (one marker per mode).

local function simOn()
    return previewOn() and NS.Preview.Mode() == "sim"
end

-- The strip the current mode shows, nil before it is built or with no Widgets library.
local function modeStrip()
    if not ui then return nil end
    if simOn() then return ui.simStrip end
    return ui.strip
end

local function titleMarked()
    return previewOn() and not modeStrip()
end

local function titleText()
    if titleMarked() then return L["DPS Race \194\183 Test"] end
    return L["DPS Race"]
end

--- The title the window shows now, for the suites.
function Hud.TitleText() return titleText() end

local function anchorStrip(strip)
    if not strip then return strip end
    local band = NS.Style.Band(ui.frame)   -- flush under the title band, in every skin
    strip:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
    strip:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
    return strip
end

local function ensureStrip()
    if ui.stripTried then return ui.strip end
    ui.stripTried = true
    -- What test mode shows and what ends it, in one line short enough for the minimum width.
    ui.strip = anchorStrip(NS.MakeTestStrip(ui.frame, L["Test mode: sample numbers. Combat or Arm ends it"]))
    return ui.strip
end

local function ensureSimStrip()
    if ui.simStripTried then return ui.simStrip end
    ui.simStripTried = true
    ui.simStrip = anchorStrip(NS.MakeSimStrip(ui.frame, L["SIM: a scripted race, not your data. /dr sim stop ends it."]))
    return ui.simStrip
end

local function applyTestMarker()
    local on, sim = previewOn(), simOn()
    -- One strip per mode: the sim's while a sim runs, the test strip for test mode, the other hidden.
    local testStrip = (on and not sim) and ensureStrip() or ui.strip
    local simStrip = (on and sim) and ensureSimStrip() or ui.simStrip
    if testStrip then testStrip:SetShown(on and not sim) end
    if simStrip then simStrip:SetShown(on and sim) end
    local strip = sim and simStrip or testStrip
    local drop = (on and strip) and NS.TEST_STRIP_HEIGHT or 0
    if ui.drop ~= drop then
        ui.drop = drop
        ui.content:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", PAD, -(CONTENT_TOP + drop))
        layoutBodies()
    end
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

-- The window's height for `body`: a fixed window's, or an auto-grow window's stack (never under the
-- idle body's). Set only when it moved, and never while the grip owns the size.
local function fitWindow(body)
    if sizing() then return end
    local h = Hud.FixedHeight()
    if not fixedMode() then
        h = chromeHeight() + math.max(NS.HudStates.BaseContentHeight(), (body and body.needH) or 0)
    end
    if h == ui.height and ui.width == ui.sizedWidth then return end
    ui.height, ui.sizedWidth = h, ui.width
    ui.frame:SetSize(ui.width, h)
    layoutBodies()
end

--- Draw the body for the current view. `full` also redraws the live rows (a tick does not).
function render(full)
    local v = raceView()
    local body = showBody(v.key)
    body:Update(v)
    if full and body.SetLive then body:SetLive(v.live, v.bars, v.icons) end
    fitWindow(body)
    footer(v)
    return v
end

-- ── what runs while shown ───────────────────────────────────────────────────────────────────────

local function windowShown()
    return ui ~= nil and ui.frame:IsShown() == true
end

-- The release of a resize (or a hide while the grip was held): the window re-anchored where the drag
-- left it, the width and the whole bars the height holds stored, and the body on screen drawn again
-- at the snapped height (the chips wrap at the new width).
function resized(width, height)
    local w = NS.Secrets.PlainNumber(width) or ui.dragW
    local h = NS.Secrets.PlainNumber(height) or ui.dragH
    local n = h and barsFor(clamp(h, fixedHeightFor(Hud.MIN_BARS), fixedHeightFor(Hud.MAX_BARS)))
    ui.dragW, ui.dragH = nil, nil
    -- The grip has left the frame at the dragged size, which ui.height never tracked: the next
    -- fitWindow sets the size again, so a release whose rows round back to the same count snaps too.
    ui.sizedWidth = nil
    placeAfterDrag(true)
    if w then
        ui.width = clamp(math.floor(w + 0.5), Hud.MIN_WIDTH, Hud.MAX_WIDTH)
        saveWidth(ui.width)
    end
    -- A new count goes through the seam, whose row redraws the HUD; else it is drawn here.
    if n and n ~= bars() then
        NS.SetByPath("hud.bars", n)
    elseif windowShown() then
        render(true)
    end
end

-- A frozen test-mode race reads nothing: its one moment comes through Hud.Render.
local function liveWanted()
    local race = raceNow()
    if sampleOn() and race.Held() then return false end
    return windowShown() and not NS.IsStoodDown() and race.State() == S().RUNNING
end

-- The live read: the meter's, or the sample race's while it stands where the race does.
local function readMeter()
    if sampleOn() then return NS.SampleRace.ReadLive() end
    return NS.Meter.ReadLive()
end

local function cancelLive()
    if liveTimer then liveTimer:Cancel() end
    if sliceTimer then sliceTimer:Cancel() end
    liveTimer, sliceTimer = nil, nil
end

local readLive

-- THE CHART'S BUCKETS (#2). A read at or after a bucket's boundary copies its live total into the
-- bucket (modules/Slices.lua): the throttled reads above do it while damage lands, and a timer at the
-- next boundary makes sure one comes then even in a quiet stretch. The last boundary is the buzzer's
-- (onState). A boundary still unfilled is retried no faster than LIVE_RETRY.
local LIVE_RETRY = 0.1

local function scheduleSlice()
    if sliceTimer or not liveWanted() then return end
    local race = raceNow()
    local run, elapsed = race.Current(), race.Elapsed()
    local at = NS.Slices.NextBoundary(run)
    if not (at and elapsed) or at >= run.race.length then return end
    sliceTimer = C_Timer.NewTimer(math.max(LIVE_RETRY, at - elapsed), function()
        sliceTimer = nil
        if liveTimer then liveTimer:Cancel() end
        liveTimer = nil
        readLive()
    end)
end

local function capture(fresh, elapsed)
    if not fresh then return end
    local race = raceNow()
    NS.Slices.Capture(race.Current(), elapsed or race.Elapsed(), fresh.total)
end

--- One live read and redraw: the running body's figures and rows from NS.Meter.ReadLive (opaque).
function readLive()
    liveTimer = nil
    if not liveWanted() then return end
    local t0 = Perf.on and debugprofilestop()
    lastRead = GetTime()
    local fresh = readMeter()
    capture(fresh)
    liveData = fresh or liveData
    local body = ui.body.running
    if body and ui.current == "running" then
        body:SetLive(liveData, nil, setting("live.icons") ~= false)
        fitWindow(body)
    end
    scheduleSlice()
    if t0 then Perf.Note("hudLive", debugprofilestop() - t0) end
end
Hud.ReadLive = readLive

-- The buzzer: one last read fills the bucket that ends on it, while the window is on screen.
local function captureBuzzer()
    local race = raceNow()
    if not windowShown() or NS.IsStoodDown() or race.SinceBuzzer() == nil then return end
    local run = race.Current()
    if run and run.race then capture(readMeter(), run.race.length) end
end

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
    if event == "PLAYER_TARGET_CHANGED" then pick.target = nil end
    Hud.Refresh()
end

-- A sample race's updates come from its script: no client meter event is heard for it.
local function wantedEvents()
    if not windowShown() or NS.IsStoodDown() then return "none" end
    if liveWanted() and not sampleOn() then return "live" end
    return "idle"
end

local function syncEvents()
    local want = wantedEvents()
    if not liveWanted() then cancelLive() end
    if sampleOn() and liveWanted() then
        requestLive()
        scheduleSlice()
    end
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
        scheduleSlice()
    end
end

local function onUpdate(_, elapsed)
    tickAcc = tickAcc + (elapsed or 0)
    local period = raceNow().State() == S().STOPPING and Hud.STOP_TICK or Hud.TICK
    if tickAcc < period - 1e-9 then return end
    tickAcc = 0
    local t0 = Perf.on and debugprofilestop()
    render(false)
    if t0 then Perf.Note("hudTick", debugprofilestop() - t0) end
end
Hud.Tick = function() tickAcc = Hud.STOP_TICK; onUpdate(nil, 0) end

local function syncTicker()
    local race = raceNow()
    local state = race.State()
    local want = windowShown() and (state == S().RUNNING or state == S().STOPPING)
        and not (sampleOn() and race.Held())
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
    Hud.wanted, autoShown, dummyShown = false, false, false
    closes = closes + 1
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
        pick.target = nil
        ui.frame:Show()
    end
    render(true)
    applyGrip()   -- after the strip is placed: its height is in the bounds
    holdEdge()
    syncEvents()
    syncTicker()
end

--- The Window size and Grow rows' reaction: the window re-anchored on the edge that now stays put,
--- where it stands (an auto-grow window), and drawn again at its new height.
function Hud.SizeModeChanged()
    if ui then holdEdge() end
    Hud.Refresh()
end

function Hud.Show()
    Hud.wanted, autoShown, dummyShown = true, false, false
    Hud.Refresh()
end

--- Close the window. `own` true is the addon's own close (test mode giving the window back), which is
--- not the player closing it and does not count toward AutoArm's manual-close rule.
--- @param own boolean|nil
function Hud.Hide(own)
    if Hud.wanted and own ~= true then closes = closes + 1 end
    Hud.wanted, autoShown, dummyShown = false, false, false
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
    if ui then
        applyPlacement()
        holdEdge()
    end
end

--- The sample race moved to a held moment (modules/Preview.lua): its one live read, and a redraw. A
--- frozen race has no live reads of its own; the views themselves are the race's.
function Hud.Render()
    liveData = sampleOn() and readMeter() or nil
    Hud.Refresh()
end

--- A sample race's meter update (modules/SampleRace.lua through Sim): the throttled read, as the
--- client's event gets.
function Hud.MeterUpdated() requestLive() end

--- The lifecycle's stand-down: the window hides, and every registration, timer and the OnUpdate go.
--- A window the addon opened (onArm, test mode) is dropped: the race or preview it opened for is gone
--- (Race.Suspend goes to idle without a message), so the stand-up must not bring it back.
function Hud.Suspend()
    if autoShown then Hud.wanted, autoShown, dummyShown = false, false, false end
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

--- Auto-show's opening (#16, modules/AutoArm.lua): a training dummy is near. Like AutoShow, but a race
--- going back to idle leaves the window open; HideAwayFromDummy closes it. A window already wanted is
--- left open: the player's and test mode's stay theirs, and an arm's or a result card's (the addon's
--- own) is taken over by the dummy, so the onArm close at the idle edge skips it whatever order the
--- bus calls the HUD and AutoArm in.
--- @return boolean opened
function Hud.ShowNearDummy()
    if Hud.wanted then
        if autoShown and not previewOn() then dummyShown = true end
        return false
    end
    Hud.wanted, autoShown, dummyShown = true, true, true
    Hud.Refresh()
    return true
end

--- Auto-show's closing: no dummy is near any more. Only a window ShowNearDummy opened, and still the
--- addon's (the player's Show, New Race or close makes it the player's), is closed.
--- @return boolean closed
function Hud.HideAwayFromDummy()
    if not dummyShown then return false end
    Hud.wanted, autoShown, dummyShown = false, false, false
    Hud.Refresh()
    return true
end

--- Whether the window is open because a training dummy is near (ShowNearDummy's, not yet closed).
function Hud.ShownNearDummy() return dummyShown end

--- How many times the player has closed the window (the close control, Escape, Hide but not
--- Hide(true), the toggle): a
--- count that moves is a close, without the HUD knowing who asks.
function Hud.Closes() return closes end

--- The length an arm takes now: the idle body's pick, else the last one raced, else the default (what
--- Arm Race and the Arm key would arm).
function Hud.ArmLength() return currentLength() end

local function onState(_, from, to)
    local St = S()
    if to == St.ARMED then
        liveData, lastRead, dropNames = nil, nil, nil
        NS.Meter.NewLiveRace()
        pick.editing = false
        autoShow()
    end
    if from == St.RUNNING and to == St.STOPPING then captureBuzzer() end
    -- Straight from idle into a live race is the /reload (or stand-up) resume: its HUD comes back
    -- as the arm's did, and closes with the race the same way.
    if from == St.IDLE and (to == St.RUNNING or to == St.STOPPING) then autoShow() end
    if to == St.IDLE and autoShown and not dummyShown and not previewOn() and setting("hud.showMode") == "onArm" then
        Hud.wanted, autoShown = false, false
    end
    debug("race %s -> %s", tostring(from), tostring(to))
    Hud.Refresh()
end

-- The run on the result card left the store (the card's Delete, or a delete in the Results window):
-- the card is dismissed (Race.Cancel keeps nothing it could, the run is gone). After the card's own
-- Delete the HUD goes back to the Arm Race screen as New Race does, open, on the same length. Any
-- other change to the store (an earlier best deleted) redraws the card: its delta chip, pace bar and
-- the best's diagonal name the best before the run, read from the store again.
local deleting   -- the run id whose delete the card's popup accepted, for the one RUNS_CHANGED it fires
local backToIdle -- defined with the acts below

local function runsChanged(race, get)
    local accepted = deleting
    deleting = nil
    -- The idle body's Your best card reads the board a change may have moved (R3-DR-4). The bus
    -- keeps no order between its receivers, so the board is dropped here too, not only in Bests'.
    if race.State() == S().IDLE and windowShown() then
        NS.Bests.Invalidate()
        return Hud.Refresh()
    end
    if race.State() ~= S().RESULT then return end
    local run = race.Current()
    if not run then return end
    if get(run.id) ~= nil then return Hud.Refresh() end
    debug("the result card's run %s was deleted", tostring(run.id))
    if accepted == run.id then return backToIdle(run) end
    race.Cancel()
end

local function onRunsChanged() runsChanged(NS.Race, NS.Recorder.Get) end

--- The sample history changed (modules/Results_Source.lua): a sample's RUNS_CHANGED.
function Hud.SampleChanged()
    if sampleOn() then runsChanged(NS.SampleRace, NS.ResultsSource.Get) end
end

do
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.RUNS_CHANGED, function() onRunsChanged() end)
        bus:RegisterMessage(NS.MSG.RACE_STATE_CHANGED, function(_, run, from, to) onState(run, from, to) end)
        bus:RegisterMessage(NS.MSG.RACE_BUZZER, function() buzzer() end)
        bus:RegisterMessage(NS.MSG.RACE_RESULT, function()
            autoShow()
            Hud.Refresh()
        end)
        -- The late-cast ignore list (#8), the profile's, changes what the result card's flag chips
        -- (and the STOP body's count) say: the body on screen is drawn again.
        bus:RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path)
            if (path == NS.LateIgnore.PATH or path == NS.DummyList.PATH or path == "profile") and windowShown() then
                render(true)
            end
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

local function arm(length)
    local ok, reason, detail = NS.Race.Arm(length)
    if not ok then NS.Print(NS.Format.ArmRefusal(reason, detail)) end
    Hud.Refresh()
    return ok, reason
end

function Act.arm()
    -- Closed, the HUD heard no target change: the cached target may be stale.
    if not windowShown() then pick.target = nil end
    return arm(currentLength())
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

-- In test mode the bodies are the sample's: Cancel ends test mode (and the sim), never the real
-- race the preview may be covering (a result card).
function Act.cancel()
    if previewOn() then return NS.Preview.Stop() end
    return NS.Race.Cancel()
end
Act.discard = Act.cancel

--- Stop Now on the Stop! and waiting screens (Round C): the result as it reads now (Race.StopNow).
function Act.stopNow()
    local acted = raceNow().StopNow()
    Hud.Refresh()
    return acted
end

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
    local run = raceNow().Current()
    if previewOn() then return run and NS.Preview.OpenResults(run.id) end
    openRun(run)
end

--- The idle body's Your best card: its run in the Results window (the sample's in test mode).
function Act.openBest(run)
    if type(run) ~= "table" then return end
    if previewOn() then return NS.Preview.OpenResults(run.id) end
    openRun(run)
end

--- New Race: back to the Arm Race screen (the owner's call, 2026-10-24), not straight to an armed
--- race. The result card is dismissed (the run is kept), the window stays open as the player's, and
--- the idle body is set to the same length, so Arm Race repeats the race.
function backToIdle(run)
    local length = run and run.race and run.race.length or currentLength()
    local race = raceNow()
    -- Kept open through the idle edge: the onArm close is for a race that is over, not this one.
    autoShown, dummyShown = false, false
    if race.State() == S().RESULT then race.Cancel() end
    -- A sample's length is not the player's pick: nothing of it reaches the profile.
    if run and run.sample then
        Hud.Refresh()
    else
        Act.pickLength(length)
    end
    return true
end

function Act.newRace()
    return backToIdle(raceNow().Current())
end

--- Delete on the result card (Round C): the Results window's own confirmation (Results.ConfirmDelete,
--- whose Accept deletes through the source seam and Recorder.Delete); the store's RUNS_CHANGED then
--- takes the HUD back to the Arm Race screen (onRunsChanged). The card's mark is set only by that
--- popup's Accept, so a canceled popup leaves a later delete elsewhere an outside one. A sample run
--- leaves the sample history (the source's own delete, in memory).
local function markDeleting(id) deleting = id end

function Act.delete()
    local race = raceNow()
    if race.State() ~= S().RESULT then return false end
    local run, R = race.Current(), NS.Results
    if not (run and R and type(R.ConfirmDelete) == "function") then return false end
    return R.ConfirmDelete(run.id, markDeleting)
end

function Act.share()
    local run = raceNow().Current()
    if run and not run.sample and NS.Share and type(NS.Share.Prompt) == "function" then NS.Share.Prompt(run) end
end

--- What the HUD is doing, for the diagnostics report: the body on screen, the event set it holds
--- ("none" | "idle" | "live"), whether the countdown OnUpdate is attached, and the lock.
function Hud.Diagnose()
    return { body = ui and ui.current or "none", events = registered, ticking = ticking, locked = Hud.locked,
             height = windowHeight(), mode = fixedMode() and "fixed" or "auto", bars = bars() }
end

--- The HUD's window, or nil before it is first built (the stepper docks beside it, SF-DR-8).
function Hud.Frame() return ui and ui.frame or nil end

--- The built window and its bodies, for the suites (nil until first shown).
function Hud.__ui() return ui end
