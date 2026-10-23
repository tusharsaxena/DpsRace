-- tests/prose_waivers.lua — what the kit's US-English gate MUST NOT correct here.
--
-- Read by `tests/_kit/test_prose.lua` (localization-§5). Per FILE and per WORD, never per file
-- alone: a whole-file waiver hides every OTHER British spelling in a file this repository edits.
-- Every file below is waived for one word and for nothing else, so a `colour` that lands in any of
-- them still reddens.

return {
    waived = {
        -- A LIBRARY'S FIELD NAME. The kit's timer mock (tests/_kit/mock_record.lua) marks a canceled
        -- handle with AceTimer's own field, `cancelled`, and its live-timer survey (`M.__timers()`)
        -- skips a handle by that field. The C_Timer.NewTicker fake (tests/wow_mock.lua) and the Race
        -- suites' clock (tests/race_clock.lua) spell it the way the kit reads it, or a canceled
        -- buzzer or poll would still count as armed.
        ["tests/wow_mock.lua"] = { cancelled = true },
        ["tests/race_clock.lua"] = { cancelled = true },
    },
}
