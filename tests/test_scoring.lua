-- tests/test_scoring.lua — modules/Scoring.lua: the late-cast rule (spec §5.2), DPS from our own
-- clock (spec §5.1), the quiet-before-read constant (spec §4.5) and the flag set (spec §5.4).

local T = _G.DPSRACE_TEST
local test, assertEqual, assertTrue, assertFalse, assertNear =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNear

local function run(status, fields)
    local r = {
        status = status,
        race = { length = 180, grace = 1.0, restartGap = 6 },
        flags = { lateCasts = {}, reloaded = false, died = false },
    }
    for k, v in pairs(fields or {}) do r[k] = v end
    return r
end

test("scoring: late cast boundaries", function()
    local S = T.NS.Scoring
    assertFalse(S.IsLateCast(1.0, 1.0), "exactly buzzer + grace is not late")
    assertTrue(S.IsLateCast(1.01, 1.0), "past buzzer + grace is late")
    assertFalse(S.IsLateCast(-0.2, 1.0), "started before the buzzer, finished after: never late")
    assertFalse(S.IsLateCast(0.5, 1.0))
    assertTrue(S.IsLateCast(1.4, 1.0))
    -- An instant has no START event: it is scored by its SUCCEEDED offset, through the same rule.
    local instantSuccess = 1.3
    assertTrue(S.IsLateCast(instantSuccess, 1.0))
    assertFalse(S.IsLateCast(0.9, 1.0))
    -- Grace 0: anything after the buzzer is late; the buzzer itself is not.
    assertFalse(S.IsLateCast(0, 0))
    assertTrue(S.IsLateCast(0.01, 0))
    assertFalse(S.IsLateCast(nil, 1.0), "no offset is never late")
end)

test("scoring: QUIET_BEFORE_READ is 2.5s", function()
    assertEqual(T.NS.Scoring.QUIET_BEFORE_READ, 2.5)
end)

test("scoring: Dps complete = damage / length", function()
    local S = T.NS.Scoring
    -- Probe run 8 (spec §7): 1539711 over a 30s race.
    local r = run("complete", { race = { length = 30 } })
    assertNear(S.Dps(1539711, r), 51323.7, 0.05)
    r.result = { endedAt = 7 }
    assertNear(S.Dps(1539711, r), 51323.7, 0.05, "a complete run ignores endedAt")
end)

test("scoring: Dps incomplete = damage / endedAt", function()
    local S = T.NS.Scoring
    local r = run("incomplete", { result = { endedAt = 40 } })
    assertNear(S.Dps(1000000, r), 25000, 1e-6)
    assertEqual(S.Dps(1000000, run("incomplete", { result = {} })), 0, "no endedAt yet: 0, not a divide by zero")
    assertEqual(S.Dps(1000000, run("incomplete", { result = { endedAt = 0 } })), 0)
    assertEqual(S.Dps(nil, run("complete")), 0, "no damage: 0")
end)

test("scoring: Flags order and text", function()
    local S, L = T.NS.Scoring, T.NS.L
    local r = run("incomplete", {
        result = { endedAt = 12.5 },
        flags = {
            lateCasts = { { t = 1.4, spellID = 29722 }, { t = 2.0, spellID = 17962 } },
            restartedAt = 14.2, reloaded = true, died = true,
        },
    })
    local f = S.Flags(r)
    local want = { "lateCasts", "restarted", "reloaded", "died", "incomplete" }
    assertEqual(#f, #want)
    for i, key in ipairs(want) do assertEqual(f[i].key, key) end
    assertEqual(f[1].text, "2 late casts (+1.4s, +2.0s)")
    assertEqual(f[2].text, "Damage restarted at +14.2s")
    assertEqual(f[3].text, "Reloaded mid-run: casts after the buzzer not tracked")
    assertEqual(f[4].text, "Died during the run")
    assertEqual(f[5].text, "Incomplete: combat ended before the buzzer")
    for _, flag in ipairs(f) do assertTrue(type(flag.text) == "string" and flag.text ~= "") end
    assertEqual(L["Damage restarted at +%.1fs"], "Damage restarted at +%.1fs", "the text is a locale key")
end)

test("scoring: Flags names late-cast spells through an optional resolver", function()
    local S = T.NS.Scoring
    local names = { [29722] = "Incinerate", [17962] = "Conflagrate" }
    local r = run("complete", { flags = {
        lateCasts = { { t = 1.4, spellID = 29722 }, { t = 2.0, spellID = 17962 }, { t = 2.6 } },
    } })
    local f = S.Flags(r, function(id) return names[id] end)
    assertEqual(f[1].text, "3 late casts (+1.4s Incinerate, +2.0s Conflagrate, +2.6s)")
    r.flags.lateCasts = { { t = 1.4, spellID = 29722 } }
    assertEqual(S.Flags(r, function() error("resolver raised") end)[1].text, "1 late cast (+1.4s)",
        "a raising resolver costs the name, never the flag")
end)

test("scoring: a clean complete run has no flags; lost stands alone at the end", function()
    local S = T.NS.Scoring
    assertEqual(#S.Flags(run("complete")), 0)
    local lost = run("lost", { flags = { lateCasts = {}, reloaded = true } })
    local f = S.Flags(lost)
    assertEqual(#f, 2)
    assertEqual(f[1].key, "reloaded")
    assertEqual(f[2].key, "lost")
    assertEqual(f[2].text, "Lost: the session could not be read")
    assertEqual(#S.Flags({}), 0, "a run with no flags table at all is clean")
end)
