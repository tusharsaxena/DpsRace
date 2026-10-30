-- tests/test_skin.lua — the windows painted through the skin (DR-02; skinning-§3, anti-pattern #107).
--
-- What this pins, beyond the literal gate (tests/test_skin_literals.lua) and the seam
-- (tests/test_skinsetup.lua):
--   - every owner token a source file names is one core/SkinSetup.lua registers, so a misspelled
--     name never resolves to nothing (the library answers nil, and a live table draws white);
--   - Ka0s Default draws the pixels these surfaces drew before the skin engine (X1): the flat
--     buttons in each style and state, the boxes, the callouts, the list washes;
--   - a skin switch moves every live color in place (the palettes keep their identity) and re-tints
--     every label and texture the host painted, with no reload;
--   - the danger, primary and selected buttons and the opaque modal are the skin's primitives with
--     their slots remapped by NAME (LibKa0s-Skin-1.0's opts.tokens), never by value.
--
-- The boxes and buttons are built under the kit's paint recorder (tests/_kit/mock_paint.lua), whose
-- frames record their backdrops and whose regions are real FontStrings and Textures, so the skin's
-- primitives paint them as they do in the client. Every case builds its own instance.

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "DpsRace"
local installPaint = dofile(T.root .. "/tests/_kit/mock_paint.lua")

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end

--- "r,g,b,a" at three decimals (alpha 1 when absent): one spelling for a drawn and a pinned color.
local function rgba(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    if r == nil then return "nil" end
    return ("%.3f,%.3f,%.3f,%.3f"):format(r, g, b, a or 1)
end

--- An instance whose every frame records its paint.
local function painted()
    local inst = T.load({ mutate = function(m) installPaint(m) end })
    inst.Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    return inst
end

--- Switch the owner's skin the way the Skin tab does, and back to Ka0s Default with `back`.
local function switch(inst, key)
    inst.NS.ApplySkinChoice("ka0s", key)
    inst.mocks.__fireTimers()
end

--- A skin other than Ka0s Default whose body text differs from it (so a switch is visible).
local function otherSkin(inst)
    local base = inst.Skin:ResolveSkin("ka0s")["text.body"]
    for _, def in ipairs(inst.Skin:Skins()) do
        local t = inst.Skin:ResolveSkin(def.key)["text.body"]
        if def.key ~= "ka0s" and type(t) == "table" and rgba(t) ~= rgba(base) then return def.key end
    end
    error("no shipped skin moves text.body")
end

-- ── the names ───────────────────────────────────────────────────────────────────────────────────

test("skin: every owner token a source file names is registered", function()
    local NS = T.load().NS
    local p = io.popen and io.popen("git -C " .. (T.root or ".") .. " ls-files 'modules/*.lua' 'settings/*.lua' 'core/*.lua'")
    assertTrue(p ~= nil, "io.popen is unavailable, so this gate cannot run")
    local missing, seen = {}, 0
    for path in p:lines() do
        local f = assert(io.open((T.root or ".") .. "/" .. path, "rb"))
        local src = f:read("*a")
        f:close()
        for name in src:gmatch('"(dr%.[%w%.]+)"') do
            seen = seen + 1
            if not NS.SKIN_TOKENS[name] then missing[#missing + 1] = path .. ": " .. name end
        end
    end
    p:close()
    assertTrue(seen > 20, "the scan found no owner token names")
    assertEqual(#missing, 0, "unregistered owner tokens:\n  " .. table.concat(missing, "\n  "))
end)

test("skin: every owner token resolves through the facade, its Ka0s Default value under Ka0s Default", function()
    local NS = T.load().NS
    for name, def in pairs(NS.SKIN_TOKENS) do
        local r, g, b, a = NS.Skin.Color(name)
        assertEqual(rgba(r, g, b, a), rgba(def.default), name)
    end
end)

-- ── Ka0s Default's pixels ───────────────────────────────────────────────────────────────────────

-- The flat button's look before the skin engine (modules/Hud_States.lua's BUTTON_STYLES and its
-- paint): fill, edge and label, enabled and disabled (fill x0.4, edge 0.25, label 0.4).
local BUTTONS = {
    normal  = { on = { { 0.1, 0.1, 0.12, 0.9 }, { 0.24, 0.24, 0.27, 0.9 }, { 1, 1, 1, 1 } },
                off = { { 0.1, 0.1, 0.12, 0.36 }, { 0.24, 0.24, 0.27, 0.25 }, { 1, 1, 1, 0.4 } } },
    primary = { on = { { 1, 0.82, 0, 0.12 }, { 1, 0.82, 0, 0.75 }, { 1, 0.82, 0, 1 } },
                off = { { 1, 0.82, 0, 0.048 }, { 1, 0.82, 0, 0.25 }, { 1, 0.82, 0, 0.4 } } },
    danger  = { on = { { 1, 0.32, 0.32, 0.08 }, { 1, 0.32, 0.32, 0.6 }, { 1, 0.32, 0.32, 1 } },
                off = { { 1, 0.32, 0.32, 0.032 }, { 1, 0.32, 0.32, 0.25 }, { 1, 0.32, 0.32, 0.4 } } },
}

test("skin: Ka0s Default draws each flat button's fill, edge and label as before, enabled and disabled", function()
    local inst = painted()
    local NS, M = inst.NS, inst.mocks
    local States = NS.HudStates
    for style, want in pairs(BUTTONS) do
        local b = States.Button(M.CreateFrame("Frame"), "x", function() end, style ~= "normal" and style or nil)
        for _, state in ipairs({ "on", "off" }) do
            States.SetEnabled(b, state == "on")
            local w = want[state]
            assertEqual(rgba(b:GetBackdropColor()), rgba(w[1]), style .. " " .. state .. ": the fill")
            assertEqual(rgba(b:GetBackdropBorderColor()), rgba(w[2]), style .. " " .. state .. ": the edge")
            assertEqual(rgba(M.__paint(b.label).textColor), rgba(w[3]), style .. " " .. state .. ": the label")
        end
    end
end)

test("skin: the buttons are the skin's Button, their slots remapped by token name", function()
    local inst = painted()
    local NS, M = inst.NS, inst.mocks
    local States = NS.HudStates
    local function opts(b)
        local rec = inst.Skin.painted[b]
        assertTrue(rec ~= nil and rec.owner == OWNER, "the button is recorded for the owner")
        return rec.calls.Button[1]
    end
    local danger = States.Button(M.CreateFrame("Frame"), "Cancel", function() end, "danger")
    local o = opts(danger)
    assertEqual(o.tokens.bg, "dr.danger.bg")
    assertEqual(o.tokens.text, "dr.danger.text")
    for _, v in pairs(o.tokens) do assertEqual(type(v), "string", "a slot names a token, never a value") end
    local primary = States.Button(M.CreateFrame("Frame"), "Arm", function() end, "primary")
    assertTrue(opts(primary).primary, "primary paints from btnPrimary.*")
    States.SetEnabled(primary, false)
    assertEqual(opts(primary).tokens.disabled, "dr.primary.offText", "a disabled button repaints its slots")
end)

test("skin: Ka0s Default draws the faint box, the callout and the badge as before", function()
    local inst = painted()
    local NS, M = inst.NS, inst.mocks
    local P = NS.HudStates.Panel
    local box = P(M.CreateFrame("Frame"))
    assertEqual(rgba(box:GetBackdropColor()), rgba(1, 1, 1, 0.03), "the faint box's fill")
    assertEqual(rgba(box:GetBackdropBorderColor()), rgba(1, 1, 1, 0.10), "the faint box's edge")
    local hint = P(M.CreateFrame("Frame"), { bg = "dr.callout.bg", border = "dr.callout.border" })
    assertEqual(rgba(hint:GetBackdropColor()), rgba(1, 0.72, 0.29, 0.07), "the waiting hint's wash")
    assertEqual(rgba(hint:GetBackdropBorderColor()), rgba(1, 0.72, 0.29, 0.35), "the waiting hint's edge")
    local card = P(M.CreateFrame("Frame"), nil, "card")
    assertEqual(rgba(card:GetBackdropColor()), rgba(1, 1, 1, 0.03), "a KPI card is the faint box too")
    assertEqual(inst.Skin.painted[card].calls.Card ~= nil, true, "drawn by the skin's Card")
end)

test("skin: the live colors are Ka0s Default's own values for the HUD and the Results list", function()
    local NS = T.load().NS
    local C, Style = NS.HudStates.COLORS, NS.Style
    assertEqual(rgba(C.text), rgba(0.93, 0.93, 0.95, 1), "the body text")
    assertEqual(rgba(C.dim), rgba(0.62, 0.62, 0.68, 1), "the dim gray")
    assertEqual(rgba(C.amber), rgba(1, 0.72, 0.29, 1), "the caution amber")
    assertEqual(rgba(C.green), rgba(0.36, 0.86, 0.46, 1), "the gain green")
    assertEqual(rgba(C.red), rgba(1, 0.32, 0.32, 1), "the loss red")
    assertEqual(rgba(C.info), rgba(0.56, 0.72, 1, 1), "the grace blue")
    assertEqual(rgba(Style.Tok("dr.list.sel")), rgba(1, 0.82, 0, 0.10), "the selection wash")
    assertEqual(rgba(Style.Tok("dr.list.hover")), rgba(1, 1, 1, 0.04), "the hover wash")
    assertTrue(near(Style.StripeAlpha(2), 0.025) and Style.StripeAlpha(1) == 0, "the stripe")
    assertEqual(rgba(Style.Tok("dr.cover.dim")), rgba(0, 0, 0, 0.45), "the timeline's dim cover")
    assertEqual(NS.ResultsTable.COLORS.text, C.text, "the Results window shares the HUD's live tables")
end)

-- ── a switch ────────────────────────────────────────────────────────────────────────────────────

test("skin: a switch moves every live color in place and re-tints what the host painted", function()
    local inst = painted()
    local NS, M = inst.NS, inst.mocks
    local Style, C = NS.Style, NS.HudStates.COLORS
    local text, dim = C.text, C.dim
    local parent = M.CreateFrame("Frame")
    local label = Style.Text(parent, Style.FONT.TEXT, C.text)
    local rule = parent:CreateTexture()
    Style.Fill(rule, "dr.chart.grid")
    local key = otherSkin(inst)
    switch(inst, key)
    local resolved = inst.Skin:ResolveSkin(key)
    assertTrue(C.text == text and C.dim == dim, "the palette keeps its tables")
    assertEqual(rgba(C.text), rgba(resolved["text.body"]), "dr.text follows the skin's text.body")
    assertEqual(rgba(C.dim), rgba(resolved["text.muted"]), "dr.dim follows the skin's text.muted")
    local tc = M.__paint(label).textColor
    assertEqual(rgba(tc[1], tc[2], tc[3]), rgba(C.text[1], C.text[2], C.text[3]), "the label re-tinted")
    assertEqual(rgba(M.__paint(rule).color), rgba(NS.Skin.Token("dr.chart.grid")), "the texture re-tinted")
    switch(inst, "ka0s")
    assertEqual(rgba(C.text), rgba(0.93, 0.93, 0.95, 1), "back on Ka0s Default")
    tc = M.__paint(label).textColor
    assertEqual(rgba(tc[1], tc[2], tc[3]), rgba(0.93, 0.93, 0.95), "the label back too")
end)

test("skin: a data hue stays the same under every skin", function()
    local inst = painted()
    local NS, M = inst.NS, inst.mocks
    local Style = NS.Style
    local label = Style.Text(M.CreateFrame("Frame"), Style.FONT.TEXT)
    local hue = NS.ResultsTable.LENGTH_COLORS[60]
    Style.Paint(label, hue)
    switch(inst, otherSkin(inst))
    local tc = M.__paint(label).textColor
    assertEqual(rgba(tc[1], tc[2], tc[3]), rgba(hue[1], hue[2], hue[3]), "a race length's hue is the data's")
    switch(inst, "ka0s")
end)

test("skin: the escapes and the markup a token feeds keep the literals' bytes under Ka0s Default", function()
    local inst = painted()
    local NS = inst.NS
    local Style = NS.Style
    local before = NS.SkinEscape("text.disabled")
    assertEqual(before, "|cff808080", "Ka0s Default's gray count, as the literal it replaced")
    local mark = Style.IconMarkup("sort-up", "x", Style.Tok("icon.arrow"))
    assertTrue(mark:find(":255:209:0|t", 1, true) ~= nil, "Ka0s Default's gold arrow: " .. mark)
    assertEqual(NS.SkinEscape("sem.danger"), "|cffff5555", "the Delete line's red, as the literal it replaced")
end)

test("skin: a skin switch redraws the sorted column's arrow in the new skin's icon.arrow", function()
    local inst = painted()
    local NS, M = inst.NS, inst.mocks
    local Style = NS.Style
    local base = inst.Skin:ResolveSkin("ka0s")["icon.arrow"]
    local key
    for _, def in ipairs(inst.Skin:Skins()) do
        local a = inst.Skin:ResolveSkin(def.key)["icon.arrow"]
        if def.key ~= "ka0s" and type(a) == "table" and rgba(a) ~= rgba(base) then key = def.key break end
    end
    assertTrue(key ~= nil, "a shipped skin moves icon.arrow")
    local t = NS.ResultsTable.New(M.CreateFrame("Frame"),
        { { key = "dps", label = "DPS", width = 60, sort = function(r) return r.dps end } },
        { sortKey = "dps", sortDesc = true })
    switch(inst, key)
    local want = "DPS " .. Style.IconMarkup("sort-down", "Interface\\Buttons\\Arrow-Down-Up", Style.Tok("icon.arrow"))
    assertEqual(t.heads[1].label:GetText(), want, "the header's arrow is the new skin's")
    switch(inst, "ka0s")
    want = "DPS " .. Style.IconMarkup("sort-down", "Interface\\Buttons\\Arrow-Down-Up", Style.Tok("icon.arrow"))
    assertEqual(t.heads[1].label:GetText(), want, "and Ka0s Default's gold again")
end)

test("skin: the custom-length box draws the skin's input box under every skin, Ka0s Default included", function()
    local inst = painted()
    local NS, M = inst.NS, inst.mocks
    local box = NS.HudStates.Build("idle", M.CreateFrame("Frame")).w.customBox
    assertTrue(M.__paint(box).backdrop ~= nil, "Ka0s Default draws its input box (the stock look is retired)")
    assertEqual(rgba(M.__paint(box).backdropBorderColor), rgba(NS.Skin.Token("input.border")),
        "Ka0s Default: the input edge at rest")
    switch(inst, otherSkin(inst))
    assertTrue(M.__paint(box).backdrop ~= nil, "another skin draws its input box")
    switch(inst, "ka0s")
    assertTrue(M.__paint(box).backdrop ~= nil, "back on Ka0s Default: still boxed")
end)
