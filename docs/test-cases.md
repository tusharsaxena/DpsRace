# Test Cases

The full inventory of every headless test case in this repo, grouped by the suite file it
lives in. The `## Totals` table below counts the cases that run: its **Total** is the
authoritative pass count, and the README test badge and any count quoted in the docs must equal
it. A declared skip is listed by name in its group and counted on the `Skipped` row, never in
Total.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.

### test_skeleton.lua (8)

- skeleton: the addon registers with AceAddon under its folder name
- skeleton: NS.Print is the tagged printer, reclaimed from AceConsole
- skeleton: /dr and /dpsrace are both registered on the one dispatcher
- skeleton: the DB defaults load (global.runs empty, global.schema 4, schemaVersion stamped)
- skeleton: NS.MSG declares the six bus names, each Ka0s_DpsRace_<PascalCase>
- skeleton: the produced interfaces exist
- skeleton: every declared icon resolves to a shipped path
- skeleton: every authored Lua file opens with the NS bootstrap and a path comment

### test_secrets.lua (11)

- secrets: IsSecret/PlainNumber over plain, nil and secret
- secrets: the guards are LibKa0s-Compat's when the library loaded
- secrets: the guards are routed through NS.Compat, the compat family's root
- secrets: CanAccessTable asks the client's table detector through NS.Compat
- secrets: the stub arm answers the same with the library absent
- secrets: without the secrets system every value is plain
- secrets: PlainTruth and PlainEquals never test a secret
- secrets: SafeIterate stops at nil and at 512
- secrets: SafeIterate never applies # or ipairs and passes secrets through untouched
- secrets: SafeIterate refuses a table this context may not read
- secrets: PlainString passes a plain string and refuses nil, a number and a secret

### test_meter.lua (26)

- meter: the stat and session constants come from the client enum
- meter: the constants fall back to 0 and 1 without the enum
- meter: IsAvailable passes Blizzard's failure reason through
- meter: IsAvailable answers false with a reason on a client without the API
- meter: IsAvailable catches a raising client and reports the error
- meter: ReadSession returns plain sorted spells after combat
- meter: ReadSession reads by ID, for the player's GUID, on DamageDone
- meter: ReadSession on a sealed session returns nil,"sealed"
- meter: ReadSession of a session the client no longer holds returns nil,"missing"
- meter: ReadSession catches a raising client and never throws
- meter: ReadSession with no damage of the player's is a zero result, not an error
- meter: live read never performs arithmetic on secrets
- meter: the live read keeps Blizzard's order and reads the Current session
- meter: the live read answers nil with no session, no API or a raising client
- meter: live DPS is the source's own amountPerSecond when it carries one (rung a)
- meter: with no source amountPerSecond, live DPS is the local row's, opaque (rung b)
- meter: a local row whose flag is secret is no claim; the Dps meter type answers (rung c)
- meter: a local row with no figure of its own falls through to the Dps meter type
- meter: the Dps meter type's totalAmount is never shown as the rate (unprobed field)
- meter: a rung that served is tried first on the next read; the chain still falls back
- meter: with no rung answering, live DPS is nil and the rest of the read stands
- meter: the rung that served is logged once per race, under the Meter tag
- meter: SessionIDs and HasSession track the client's list by plain ID
- meter: modules/Meter.lua is the only file that names C_DamageMeter
- meter: core/Compat.lua is the only file that names the client's secret detectors
- meter: core/Secrets.lua is the only caller of NS.Compat's secret guards

### test_dummies.lua (5)

- dummies: Lookup known and unknown npcID
- dummies: the catalog holds exactly the measured rows
- dummies: Lookup answers a copy, so a caller cannot edit the catalog
- dummies: six categories in order, each with an enUS label
- dummies: every cataloged category is one of the six

### test_dummy_list.lua (23)

- dummy list: Parse reads entries and hides, ascending, the last of an ID winning
- dummy list: Normalize drops a custom entry for a built-in and a hide of a non-built-in
- dummy list: the row refuses what does not parse and stores what it normalizes
- dummy list: Add marks a creature, Lookup answers it, Remove takes it off
- dummy list: a built-in is switched off and back on, never recategorized
- dummy list: Reset clears the list; a profile switch reads the other profile's
- dummy list: CategoryOf reads a stored target by its creature as the list is now
- dummy list: a new snapshot of a listed creature is categorized and auto-arm sees it
- dummy list: Infer reads a name word, then a boss classification or skull level, else single
- dummy list: CategoryFor takes a typed word, else the row, and auto infers
- dummy list: Read and Capture keep what the game says, by map, and count the captures
- dummy list: a sealed field is left out of the read, and a player is no creature
- dummy list: Resolve takes an ID or a captured or cataloged name
- dummy list: a captured custom dummy answers its captured name
- dummy list: a stored run moves boards when its creature is added, and back when removed
- dummy list: switching a built-in off sends its runs to Other; a run with no creature ID keeps its own
- targetdummy: add marks the target, captures it and says what it saved
- targetdummy: add refuses a word that is no category, no target, and a player
- targetdummy: on a built-in, add says so and captures; remove switches it off, add brings it back
- targetdummy: remove takes a typed creature ID or name; show lists yours and the switched-off
- targetdummy: capture saves without marking; an unknown word prints the usage
- targetdummy: answers while the addon is disabled, as ignore does
- dummy list: the idle HUD's unknown-target warning follows the list without a target change

### test_recorder.lua (22)

- recorder: SnapshotPlayer records who the player is (spec §7 char)
- recorder: SnapshotPlayer tolerates a client without the spec and ilvl APIs
- recorder: SnapshotPlayer reads the spec through the compat family on a C_SpecializationInfo client
- recorder: SnapshotTarget parses npcID from a Creature GUID and categorizes known dummies
- recorder: SnapshotTarget parses npcID from a Creature GUID and categorizes unknown targets as other
- recorder: SnapshotTarget on a player or with no target is other with no npcID
- recorder: SnapshotTarget tolerates a secret GUID (records name, category other)
- recorder: SnapshotTarget fills a sealed field from the prior snapshot
- recorder: SnapshotWhere records the map, zone, subzone and instance type
- recorder: NewRun copies grace and restartGap from the profile
- recorder: NewRun uses the shipped defaults (grace 1.0, restart gap 6)
- recorder: NewRun never reuses a stored id
- recorder: Save stores by id, fires RUN_SAVED, and Get reads it back
- recorder: Save refuses a run without an id
- recorder: All orders by date desc and excludes armed
- recorder: All breaks a date tie by id, so the order is stable
- recorder: Pending returns running and stopping only
- recorder: Pending holds only the logged-in character's runs
- recorder: a run written by a later schema is left alone
- recorder: Delete fires RUNS_CHANGED
- recorder: DeleteAll empties the store and fires RUNS_CHANGED
- recorder: the store is account-wide and survives a profile switch

### test_timeline.lua (10)

- timeline: tail from probe run 4 = 3.03
- timeline: tail from probe run 6 = 8.49
- timeline: restart detected after 10s quiet at gap 6
- timeline: DoT ticks every 2s are not a restart
- timeline: the quiet stretch starts at the buzzer when the last damage was before it
- timeline: a gap of exactly the setting counts as a restart
- timeline: no damage after the buzzer gives tail 0 and no restart
- timeline: a gap that spans a resume is measured from the resume
- timeline: an out-of-order or non-number update is handled
- timeline: two timelines are independent

### test_scoring.lua (9)

- scoring: late cast boundaries
- scoring: QUIET_BEFORE_READ is 2.5s
- scoring: Dps complete = damage / length
- scoring: Dps incomplete = damage / endedAt
- scoring: Flags order and text
- scoring: Flags names late-cast spells through an optional resolver
- scoring: SplitLate keeps the recorded order and splits by the ignore set; a sealed cast always counts
- scoring: Flags flags only the counted late casts and carries the count, the casts and the ignored
- scoring: a clean complete run has no flags; lost stands alone at the end

### test_bests.lua (21)

- bests: Key is specID|category|length
- bests: incomplete and lost never count
- bests: the highest result.dps holds the board; a tie keeps the earlier run
- bests: cleanOnly excludes flagged
- bests: two Dungeoneer npcIDs share one board
- bests: spec, category and length each split the board
- bests: deleting a best promotes the next run
- bests: the cache is invalidated by RUN_SAVED and keeps cleanOnly apart
- bests: a run flagged only by an ignored spell joins the clean board, and leaves it on Unignore
- bests: Delta reports new best and percentage vs previous best
- bests: Delta ignores later runs, other boards and runs that never count
- bests: Delta defaults its run list to the store
- bests: HoldingIDs names the holders of the all-runs and the clean-only boards
- bests: prune days=0 removes nothing
- bests: prune keeps best-holding runs
- bests: prune never removes a running or stopping run, and stops at the holders
- bests: prune runs on RUN_SAVED with the global history.keepDays setting
- bests: prune never removes the run just saved, nor the race's own run
- bests: a raced run that lands below the best survives the prune its own save fires
- bests: prune runs at OnEnable
- bests: no prune and no cache work while disabled

### test_late_ignore.lua (19)

- late ignore: the hearthstone table holds 59 positive IDs, once each, with 8690, Dalaran and Garrison, never 556
- late ignore: the setting parses sorted and once each, refuses anything else, and joins back
- late ignore: Normalize drops a variant while 8690 is listed and keeps it alone
- late ignore: the default is the profile's, and 8690 stands for every hearthstone in Set only
- late ignore: Ignore, Unignore and Reset write the whole list through the seam
- late ignore: Resolve takes a number, a link, a hearthstone's name and a default the character does not know
- late ignore: a variant's name resolves to that variant when it is listed on its own, else to 8690
- late ignore: on a degraded load a number, a link and a hearthstone still resolve
- late ignore: the known spells are every late cast's spell, newest run first, then the defaults
- late ignore: the result card's chips count only the counted casts; all ignored, no chip
- late ignore: the Results detail draws an ignored cast's tick gray and explains only the counted ones
- late ignore: a list change redraws the HUD and drops the cached boards and the sample's
- late ignore: a profile switch re-scores the flags by the other profile's list and drops the clean board
- late ignore: the menu offers each counted spell once, the undo for each ignored one, nothing for a sealed cast
- late ignore: the menu's entries ignore and count again through the list
- late ignore: IgnoredText names the ignored casts in one line, nil with none
- late ignore: the result card's late chip carries the menu and the dimmed lines; all ignored, a gray chip
- late ignore: the detail's flags box keeps a dimmed ignored line, also when every cast is ignored
- late ignore: every flags tooltip shows the dimmed ignored line (D-6a)

### test_late_ignore_ui.lua (3)

- late ignore ui: the detail's Flags box dims the ignored line and its right-click ignores a spell
- late ignore ui: the row menu holds an Ignore for late casts submenu only when the run has a late cast
- late ignore ui: the sample history offers no ignore menu (D-7)

### test_race.lua (58)

- race: the state names are the interface's
- race: arm refuses in combat and while a run is pending
- race: arm refuses while a stored run is pending, even when idle
- race: arm refuses when meter unavailable
- race: arm refuses a length outside 10s-15:00 and arms a valid one
- race: session created starts the clock and persists the run as running
- race: the target is re-read at combat start
- race: sessionID captured from first DamageDone update with non-zero id
- race: a DamageDone update heard just before the session event is adopted at the start
- race: a session event heard out of combat does not start the clock
- race: a DamageDone update for a stray session heard out of combat is never adopted at the start
- race: the target is re-read at the combat that starts the clock, not an earlier one
- race: a session event with the regen edge on an earlier frame does not start the clock
- race: a session made out of combat starts the clock on its first update in combat
- race: an update on the regen edge's frame, heard before the edge, starts the clock
- race: a pull that continues a session from before the arm is adopted, flagged and netted
- race: a fresh session heard after a shared start replaces the shared one
- race: an update in combat for another session never starts a stray combat's clock out of combat
- race: a buzzer heard out of combat with the regen edge missed is still read
- race: an empowered cast held across the buzzer is never late
- race: buzzer at start+length moves to stopping and emits RACE_BUZZER
- race: cast started 0.5s after buzzer is not late at grace 1.0
- race: cast started 1.4s after buzzer is recorded as late with spellID
- race: a late cast of an ignored spell is still stored raw; the list is read, never applied, at capture
- race: cast that started before buzzer and succeeded after is not late
- race: the grace in force is the run's own, not the profile's
- race: an interrupted cast leaves nothing open; a later instant of the same spell is late
- race: a cast matches its own success by castGUID, not by spell
- race: secret spell IDs and castGUIDs are judged without ever being stored
- race: auto-repeat successes after the buzzer are never late casts
- race: a sealed meter type or session ID moves nothing and stores nothing
- race: Watchers hands Race the castGUID and the interrupt
- race: combat end before buzzer -> incomplete with endedAt
- race: death -> incomplete, died flag
- race: death after the buzzer flags died and the run stays complete
- race: result read only after combat end AND 2.5s quiet
- race: no read while combat holds, however quiet the meter is
- race: read uses ReadSession(sessionID), never Current
- race: tail and combat end are stored relative to the buzzer
- race: restart after a 10s gap sets flags.restartedAt
- race: updates for another session never move the timeline
- race: meter reset while stopping -> lost
- race: meter reset while running -> lost, and the buzzer never goes
- race: meter reset while armed forgets the arm-time sessions and keeps the arm
- race: a session the client no longer holds is lost at the read
- race: a read that stays sealed is retried, then lost
- race: a read that raises is lost, not a Lua error
- race: a session ID never captured falls back to the newest session after arming
- race: no new session at all is lost
- race: cancel in armed/running stores nothing; cancel in stopping discards
- race: cancel on a result dismisses it and keeps the run; race again arms
- race: stop now acts only while stopping
- race: stop now out of combat reads at once through the normal path, the quiet waived
- race: stop now in combat reads nothing until the regen edge, then reads without the quiet
- race: stop now on a still-sealed read retries on the poll, as any read does
- race: stop now on a run that ended before the buzzer reads it as incomplete
- race: inputs in the wrong state change nothing
- race: the diagnostics state section names the race state, run, session and pending count

### test_race_resume.lua (16)

- resume: running past buzzer becomes stopping+reloaded
- resume: running before buzzer keeps running with remaining time
- resume: stopping out of combat reads immediately
- resume: stopping in combat waits for the regen edge
- resume: an incomplete run waiting for its read stays incomplete
- resume: session gone becomes lost
- resume: an older unresolved run is settled as lost; the newest is carried on
- resume: nothing stored leaves the race idle and touches nothing
- resume: running before the buzzer with combat already over is incomplete and read at once
- resume: a stand-down mid-run whose combat ends unseen never hangs in stopping
- resume: a stopping run that ended before its buzzer is not flagged reloaded
- resume: a run another character left pending is not resumed here
- resume: a reload that outlasts the restart gap while DoTs tick is not a restart
- resume: the tail and a restart heard before a /reload survive it
- resume: the stamps before a /reload keep a DoT tail across it from looking like a restart
- resume: a run with no session ID never adopts a session from before its arm

### test_format.lua (8)

- format: Number abbreviates through the client's formatter, secret or plain
- format: Number never does Lua arithmetic on a secret when no formatter exists
- format: a formatter that renders the check value wrongly is not used
- format: Clock is m:ss.t with tenths truncated; Length is m:ss
- format: Pct and Seconds take plain numbers
- format: ParseLength accepts 90, 90s, 1:30, 3m and 1m30s, and rejects anything else
- format: ArmRefusal maps every Race.Arm reason to its line
- format: RunTime is the length and the tail, or the time in combat against the length

### test_hud.lua (73)

- hud: switches body on RACE_STATE_CHANGED for all six states
- hud: a run that ended before the buzzer waits for its read on the waiting body
- hud: idle arm button disabled with reason in combat
- hud: idle Arm uses the picked length; the card has no target count; a refusal prints its line
- hud: a custom length is parsed, range-checked and selected
- hud: an unknown target is allowed and said so
- hud: a changed Default race length takes effect over the remembered pick
- hud: with no stored answer it falls back to defaults/Profile.lua, never a literal of its own
- hud: a target changed while the HUD is closed is never armed as the old one
- hud: reopening the HUD offers the target of the moment, not the one cached at close
- hud: running render raises nothing with secret values
- hud: running body shows no percentage text
- hud: live rows keep Blizzard's order and the configured count
- hud: a live read with no DPS figure shows a dash
- hud: the live DPS KPI shows a figure when the source carries no amountPerSecond (live client)
- hud: layout never calls GetWidth/GetPoint on breakdown rows
- hud: live reads stop when hud hidden or state leaves running
- hud: the stop body shows the live tail, time in combat, late casts and the grace
- hud: the stop body counts only the late casts the ignore list leaves (#8), and redraws when it changes
- hud: waiting hint appears after hintDelay and names only owned drop-combat spells
- hud: STOPPING redraws at a few Hz, and a steady stop body rebuilds nothing
- hud: the sticky-combat hint asks for the player's spells once per race
- hud: the live rows stop above the caption and CANCEL at every window height
- hud: live rows 0 shows every spell that fits and the wheel scrolls through the rest
- hud: the default window size shows every default live row under the chart and the pace bar
- hud: the result card's rows stop above its buttons at every window height
- hud: the result card follows Spell rows shown; at 0 it lists every spell and scrolls
- hud: the minimum height holds the idle body's whole stack
- hud: the equal buttons' width is whole pixels from the body's width and the gap
- hud: the result card's four buttons sit in one row, the same width each, at any width
- hud: Cancel on the waiting body throws the attempt away
- hud: the Stop! and waiting bodies carry Stop Now and Cancel, the same width, with tooltips
- hud: Stop Now out of combat takes the result at once, without the quiet
- hud: Stop Now in combat reads at the combat end and says so
- hud: Delete on the result card asks first, deletes through the store and goes back to Arm Race
- hud: a result card whose run is deleted in the Results window is dismissed
- hud: a canceled card Delete leaves a later Results-window delete of that run an outside one
- hud: the card's Delete accepted after the card has gone leaves no mark behind
- hud: result body shows % and the best delta chip
- hud: a first run is a new best; a slower one shows its deficit and its flags
- hud: a late-cast chip's right-click ignores its spell, and the gray ignored chip's undoes it (#8)
- hud: a lost result says it could not be read
- hud: an incomplete run's chip names when combat ended, or that the player died
- hud: New Race opens the Arm Race screen on the same length; Details and Share reach their modules
- hud: Share is live on a result card, and grayed without a Share module
- hud: closing a result card dismisses it and keeps the run
- hud: countdown cue plays at 10,5,3,2,1 and buzzer raises the raid warning only when enabled
- hud: the cue stops when the race is canceled
- hud: switching the cue off mid-race silences the marks still ahead
- hud: a stand-down drops a window onArm opened, so the stand-up does not bring it back
- hud: the running clock shows elapsed in green beside time left in red by default
- hud: a single-clock mode shows one big clock in its own color
- hud: the clock pair fits the minimum width; the stop body keeps its own STOP
- hud: the window is skinned, closable with Escape, resizable and clamped
- hud: Lock frame, Master scale and Reset position act on the window
- hud: dragging is refused while locked and the position is stored when it ends
- hud: General visibility and the stand-down hide it at the source
- hud: onArm shows it on arm and hides it when the race it opened for is canceled
- hud: showMode always shows it at login
- hud: a race resumed after a /reload shows the HUD under onArm
- hud: a result arriving while the window is closed opens it
- hud: Render draws a given body only while test mode is on
- hud: the stand-down drops every registration, timer and the OnUpdate
- hud: hidden with its parent is not closed by the player
- hud: the library-absent load still draws the HUD without a grip or a close control
- hud: the diagnostics state section names the body, the event set and the countdown driver
- hud: labels take the collection's font objects; the clocks and KPI figures stay large
- hud: no body shouts in capitals (Title Case labels and buttons, Sentence case prose)
- hud: a title-bar control turns gold under the pointer and back at rest, a late leave included
- hud: the minimum size still holds every body after the compact restyle
- hud: the running clocks, figures and spell rows take their HUD Appearance blocks
- hud: a clock shown alone draws half again as large, in its block's color
- hud: a bar's class color companion takes the player's class, the swatch's opacity kept

### test_hud_hint.lua (6)

- hud hint: the line estimate wraps whole words at the width
- hud hint: at the minimum width the plain hint is three lines and 6 px above and below
- hud hint: a named drop-combat ability takes the line it needs, and a wider body fewer
- hud hint: the text is inset from the box's top, never pinned to a fixed bottom
- hud hint: under the box only the foot row, on the body's bottom, clear of the box at the minimum height
- hud hint: the box resizes when the hint's text changes, and not on every redraw

### test_hud_tips.lua (3)

- hud: a live spell row's hover shows the client's spell tooltip right of the HUD, its secret ID untouched
- hud: a hovered live row's tooltip is re-run on each redraw, for the spell the row draws now
- hud: a result row's hover shows the spell tooltip right of the HUD, then its damage and share

### test_hud_tiles.lua (9)

- hud tiles: the Stop! tail reads +x.xs in one large string, after buzzer on the row under it
- hud tiles: the caption row sits inside the tile at the old padding, the figure a row above it
- hud tiles: both tiles of the pair are one taller height; the running and result tiles keep 46
- hud tiles: under the taller pair the Stop! chips and note and the waiting hint move down by config
- hud tiles: the right tile's caption says what its figure is in each state
- hud tiles: every caption fits a tile at the 260 px minimum by the 6 px a character estimate
- hud tiles: the waiting screen's tiles read the same as the Stop! screen's
- hud tiles: the moved Stop! and waiting stacks still fit the minimum height above the foot row
- hud tiles: the Stop! and waiting redraws read no geometry

### test_chart.lua (30)

- chart: the bucket count is the length in whole seconds, at most 60
- chart: a capture copies the handle into each bucket it is the first read at or after
- chart: a shared session's buckets stay empty, and the store never inspects a value
- chart: Drawable answers only a scored run with slices this session
- chart: the pace is the best's damage spread evenly over its length
- chart: the columns sit on whole-pixel edges, touching, the configured gap taken off all but the last
- chart: the columns take the Column gap setting; the plot's background its Chart background swatch
- chart: the pace bar has its own look; styling the chart's columns leaves it alone
- chart: each column holds exactly the handle read at its boundary, and none fills early
- chart: with no best the scale is the live total itself (B): no line, no diagonal, no pace bar
- chart: with a best the scale is its damage x 1.15 (A), with its pace diagonal and the pace bar
- chart: the tick reuses the live views and rebuilds the chart's only when what decides it changes
- chart: hidden, with the pace bar, while the run is on a shared session
- chart: Show damage chart and Show pace bar turn each off
- chart: a quiet stretch still fills each bucket at its boundary, and the buzzer fills the last
- chart: the chart steps aside at the minimum height; the rows keep their three
- chart: the overlay sits one band over the plot's columns
- chart: the result card draws the race's slices to its plain final damage, and none without them
- chart: WithBest scales an after-the-race view to max(run, best at its length) x 1.15
- chart: the result card draws the earlier best's diagonal, the columns on the shared max
- chart: the earlier best deleted while the card is up drops its diagonal and the shared max
- chart: with no earlier best the result card and the detail draw no diagonal
- chart: the Results detail shows the chart for a run raced this session only
- chart: the detail's title hover goes with its chart, so it never covers the section under it
- chart: a lost run has no chart on the card or in the detail
- chart: test mode's still running body draws the sample's chart against the sample history's best
- chart: the sim draws the sample's chart live against a best, then on its result card
- chart: the sim honors Show damage chart and Show pace bar
- chart: the diagnostics state section counts the loadout store and the races holding a chart
- chart: the plot is a fill with no edge (the owner's call, 2026-10-26)

### test_pace.lua (14)

- pace: Pace bar range defaults to 1.5, drives PaceBounds either side of the pace and is clamped to 1.1-2.0
- pace: the tick sits in the middle of the bar's width, in whole pixels
- pace: the running bar's tick stays in the middle while its range follows Pace bar range
- pace: the bar splits at the tick: behind fills to the pace with red to the tick, ahead fills green past it
- pace: Bests.Before is the best on the run's board raced before it, whatever the run scored
- pace: the result card sets the plain final damage against the best's pace at the buzzer
- pace: a run that just became the best is set against the previous best
- pace: no pace bar on the result card with no earlier best, and the rows move back up
- pace: Show pace bar off, a shared session and a lost run hide the result card's bar
- pace: at the minimum height the result card keeps its pace bar and three rows; the chart steps aside
- pace: the sim's result card shows the pace bar against the sample best, and honors the setting
- pace: the running body stacks Damage profile, the pace bar, the plot, then Spell breakdown
- pace: the result card stacks the same, and keeps Damage profile over the pace bar when the plot is off
- pace: the result card's stack starts under the chips it draws, as the running body's under its boxes

### test_countdown.lua (20)

- countdown: 10..1 show one per second in the last 10s, then go at the buzzer
- countdown: its own frame, center of UIParent, above everything, never taking the mouse
- countdown: each number pops in through an animation
- countdown: the digits are Blizzard's BigGold set, cut by texcoord
- countdown: without the digit art it falls back to a large outlined number
- countdown: finalCountdown 3 starts at 3
- countdown: switched off, no frame is ever built and only the cue marks sound
- countdown: switching it off mid-countdown hides the number at once
- countdown: works with the HUD window closed
- countdown: one cue per second of the numbers, never two in a second
- countdown: the cue off keeps the numbers and silences every second
- countdown: a cancel at 5s left hides it and nothing more shows or sounds
- countdown: combat ending before the buzzer hides it
- countdown: a /reload with 4s left resumes at 4 and counts 3, 2, 1
- countdown: a /reload before the window shows nothing until it opens
- countdown: a /reload past the buzzer shows nothing
- countdown: the sim demonstrates it in its running phase, and it stops with the sim
- countdown: the sim race's buzzer clears it, the setting holds in the sim, and still test mode shows none
- countdown: never broadcasts a pull timer nor drives Blizzard's TimerTracker
- countdown: the diagnostics state section names what it shows and holds

### test_autoarm.lua (30)

- autoarm: both rules are off by default and register nothing
- autoarm: each rule registers only what it needs, and turning both off drops it all
- autoshow: a dummy target opens the HUD, and leaving it closes it after the debounce
- autoshow: a dummy's nameplate opens the HUD, with no target at all
- autoshow: nameplates churning inside the debounce never close the window
- autoshow: the hide's fire scans the nameplates again before it closes
- autoshow: a secret GUID is no dummy
- autoshow: the player's close keeps it closed for the rest of the dummy session
- autoshow: a window the player opened is theirs, and never closed by leaving
- autoshow: a race or its result holds the window; the idle edge lets it go
- autoshow: a result card holds the window past the debounce
- autoshow: a race going idle near the dummy keeps the window open
- autoshow: a dummy near an arm's window takes it over, so the idle edge never closes it
- autoshow: test mode's window stays test mode's, and its end is no close by the player
- autoshow: General visibility still decides whether it draws
- autoshow: turning the rule off closes the window it opened
- autoarm: targeting a cataloged dummy out of combat arms at the HUD's length and opens it
- autoarm: a target that is no cataloged dummy arms nothing
- autoarm: Race.Arm's refusals hold, silently: in combat, pending, meter unavailable
- autoarm: no arm over a result card, nor in test mode
- autoarm: targeting anything else before the pull disarms; another dummy keeps it
- autoarm: a started race is never disarmed by a target change
- autoarm: a target change in combat before the clock starts never disarms the pull
- autoarm: a race the player armed is never the rule's to disarm
- autoarm: Cancel works as today, and the next target change to a dummy arms again
- autoarm: works alongside auto-show; the disarm leaves the dummy's window open
- autoarm: a profile switch re-reads both rows, with no /reload
- autoarm: neither rule acts in an instance or a battleground
- autoarm: entering an instance closes the dummy's window
- autoarm: stood down, nothing is registered and nothing acts; the stand-up rebuilds

### test_layers.lua (7)

- layers: one table names the addon's tiers by the standard's keys
- layers: no strata string and no bare level number at a call site
- layers: the Race HUD is MEDIUM, toplevel and clamped
- layers: the Results window is HIGH, toplevel and clamped
- layers: the ability timeline is DIALOG, one strata above the Results window, toplevel and clamped
- layers: the detail pane sits one band over the list pane, never by creation order
- layers: the countdown is FULLSCREEN, below every menu

### test_results.lua (50)

- results: runs list columns: date, class icon, spec icon, character, ilvl, target, time, damage, DPS, Delta, status, used, note
- results: the Note column cuts a note to 10 characters with an ellipsis, tips the whole note and sorts A to Z, none last
- results: the detail's section headings are the larger SECTION font; Spell breakdown heads the compare and the list
- results: every section heading has SECTION_GAP of clear space above it, the y-advances from config
- results: the detail's header: 28 px class and spec icons, a larger name, no spec text; the spec icon names the spec
- results: the note shows as written under a Note heading; the heading also shows while writing one
- results: every cell and header has a tooltip; it sits right of the window, or left when there is no room
- results: the Status column tags each run; the DPS column shows every run's DPS
- results: Status is Spec best, Flagged or Complete for a complete run, each with its icon; there is no Max tag
- results: race lengths take muted ROYGBIV colors for the presets and a neutral one otherwise
- results: the Time column takes the length color; the tail stays gray
- results: Status tags are boxed in their hue with the icon inside
- results: the HUD never draws a race length in the Results length colors
- results: Damage and DPS carry bars from 10% (the smallest run the filters pass) to 100% (the largest)
- results: the bars take History > Results table's look, over the rows' own stripe
- results: the Damage and DPS bars run 10% to 100% within each group; ungrouped, the whole view is one
- results: Delta is per group, recomputed when the grouping changes; ungrouped, the whole view is one
- results: Only best keeps the runs holding their board's best
- results: Delta is each run's distance from the max DPS among the runs the filters pass
- results: filters: character, spec, category, length, date range, hide flagged, include incomplete
- results: sort by date desc default; by DPS; by ilvl
- results: the list is pooled and scrolls through more runs than fit
- results: detail renders breakdown sorted with percentages
- results: timing strip positions buzzer, grace, tail, late casts, combat end
- results: the detail lists every spell of the run, not a capped top few
- results: the detail's spell rows follow HUD Appearance's row height
- results: detail flags name late-cast spells and the session matched by list
- results: delete asks confirmation then fires RUNS_CHANGED
- results: note limited to 200 chars
- results: opening the note scrolls its box into view
- results: every detail element has a tooltip; spells show the client's spell tooltip beside the window
- results: the timing strip's marks draw above its two segments
- results: the timing legend is two rows, the bars' colors over the lines', Restart among the lines
- results: a spell list built without a tip hook takes no mouse
- results: saving a note never prunes the store
- results: Share is grayed without a Share module; a row's right-click menu notes, shares and deletes
- results: the Insights tab is built on first show, counts the runs and shows the empty state with none
- results: a profile saved before the rename loads clean and opens Insights (D-14, no migration)
- results: list refreshes on RUN_SAVED
- results: Runs opens on the current character in every spec; current character and spec are each a choice of its own
- results: the window is skinned, closable with Escape, resizable and clamped
- results: position, size and Master scale persist; Reset position restores them
- results: collapsed, the detail replaces the list, with a back control
- results: hidden with its parent is not closed by the player
- results: the window is no Blizzard UI panel: no UIPanelWindows, no layout attributes, no ShowUIPanel, no hook
- results: the stand-down hides it and the stand-up brings it back
- results: the library-absent load still draws the window, with no dropdowns or close control
- results: the diagnostics state section names the tab, the layout and the selection
- results: a centered GameFontNormal title, Title Case tabs and headers, compact rows, small gray footers
- results: the close control is the skin's own, never the title strip's gold (D-9)

### test_results_fit.lua (5)

- results: every Runs column fits the narrowest list either view lays out
- results: the Runs filter bar fits inside both views' minimum width
- results: the Runs filter bar with no width, or only the room it needs, is the configured plan
- results: the Runs filter bar ends on the window's right edge in both views, never under its widths
- results: the Runs filter bar stretches with the window while the grip is dragged

### test_results_group.lua (6)

- results: Group by character, class & spec or target, with folding headers
- results: Group by time, and by target type and time, shortest first
- results: Save, Reset and Clear the Runs view, and a saved view is what the window opens on
- results: hovering Save, Reset or Clear shows its tooltip without an error
- results: Group by spec + target + time, one group per board, the spec in its class color
- results: Group by Full: character, class, spec, target and time, in that order

### test_results_delta.lua (4)

- results: the detail's Delta box: a best's lead, a non-best's Delta cell, a lone run, an incomplete run's muted figure, a lost run
- results: Runs.Leaders breaks a DPS tie on the earlier run, then the id; the tied runner-up reads 0.0% in green
- results: the detail's Delta box follows the Runs view's grouping and filters while the run is shown
- results: a run the Runs filters leave out falls back to its board among every stored run

### test_results_tree.lua (5)

- results: the talent tree's panel open closes the window, and it comes back when the tree closes
- results: the player opening or closing the window ends its wait for the tree
- results: Escape with the talent tree up closes both, and the window stays closed
- results: Escape with no talent tree closes the window for good
- results: the close control with the talent tree up closes the window alone

### test_results_badges.lua (10)

- badges: the Target cell is a boxed chip in its category color, the count inside
- badges: the Time cell boxes the length in its color; the tail or the end of combat follows in gray
- badges: Spec best and Max are the box alone; their board is in the tooltip
- badges: a chip never runs past its column: a too-long word is cut to the box
- badges: Target, Time and Status fit their widest chips (Tbl.BadgeWidth)
- badges: the window minimums hold the wider columns, the Note column last and inside the list
- badges: the detail's target line leads with the type and length chips, laid out from their widths
- badges: drawing the chips reads no frame's size or position back
- badges: group headers color their value as plain text: class, target type, length
- badges: the HUD draws none of the Results chips

### test_compare.lua (23)

- compare: CompareSpells matches by id, with each side's damage, share and the difference
- compare: a spell on one side only has nil damage and share on the other
- compare: rows sort by the run's damage, then the other's, then the id
- compare: a zero or missing damage total leaves the shares nil; duplicated ids add up
- compare: the figures and their % difference; none against a zero or missing figure
- compare: the Difference is two cells, the amount, then the % in the bars' muted green or red
- compare: the default is the best on the run's board; for the best itself, the runner-up
- compare: a picked run wins while it is stored and not the run itself
- compare: the toggle sets the run beside the best: the score table and the compared breakdown
- compare: This run right, Best run left; each header at its column's x, width and justify
- compare: the score table has no box, its columns are the spell table's, and a rule sits between them
- compare: one bar per row, on the higher run's side, its length the row's % difference against the table's
- compare: the Difference column fits the detail at both views' minimum widths, with nothing clipped
- compare: the % column holds a signed three-digit % with one decimal in every skin
- compare: the best compares with the runner-up; a run alone on its board has the toggle disabled
- compare: the row menu's pick, the different-board note and Clear Pick
- compare: the toggle, Clear Pick, the note, the score table and each compared row have tooltips
- compare: the collapsed view draws the compare in the list's place; no number is read off a frame
- compare: the columns flex with the width: the name column a share of it up to its cap, the figures the rest
- compare: a 1200 px collapsed detail draws both tables across its width, a separator between the runs
- compare: the separator draws one physical pixel wide at any UI scale, not one UI unit
- compare: Damage and DPS in the spell names' white, each after a game icon at the spell icons' size and x
- compare: every spell row alternates the Results list's stripe, compared and plain

### test_loadout.lua (27)

- loadout: SnapshotLoadout reads every equipped link but the shirt and the tabard
- loadout: SnapshotLoadout reads the talents: the saved loadout's name, the hero tree, the string
- loadout: with no saved loadout the active config's name is used
- loadout: a client without the APIs, or one that raises, yields absent fields, never an error
- loadout: a secret value never reaches the snapshot
- loadout: the hash is djb2 as eight hex digits, and pure
- loadout: Store keeps each distinct set once; the run holds only the keys
- loadout: two different sets with one hash are told apart; the same set finds its own key
- loadout: Of resolves a run's keys; a run without one has neither
- loadout: Delete, DeleteAll and Prune drop the loadouts no run refers to
- loadout: a run of a later format keeps the sets it refers to
- loadout: the format 2 migration leaves old runs as they were, without a loadout
- loadout: a race keeps the combat-end loadout, not the arm-time one
- loadout: a run with no combat-end snapshot falls back to the arm-time one
- loadout: a second combat end in the read's wait replaces the loadout and drops the first
- loadout: a run resumed after a /reload whose combat ended unheard still takes a loadout
- loadout: the detail draws the gear grid in the character frame's order, and the talents line
- loadout: an item's hover is the client's own tooltip; a modified click goes to the client
- loadout: the Gear heading carries the run's item level as caption subtext on its line
- loadout: a run stored before #6 says Not recorded, with nothing to view or copy
- loadout: View is grayed with a reason once the client's serialization version moved; Copy still works
- loadout: under the compare the changed slots are highlighted and a different loadout is marked
- loadout: the pure parts: changed slots, the link data, the talents text
- loadout: the copy window opens on the import string
- loadout: the Spec cell's tooltip names the loadout and notes gear changed since the previous run
- loadout: the share line takes the talents link only with Include talents link on
- loadout: Include talents link sits under Sharing on the History tab, before Storage

### test_stats.lua (9)

- stats: Snapshot reads the primary stat, stamina, armor and every rating with its percent
- stats: crit is the highest of melee, ranged and each spell school's, as the character panel shows
- stats: a secret value is stored as absent, never compared or kept
- stats: a client without the APIs, or one that raises, yields absent fields; nothing readable is nil
- stats: a new run carries the arm's stats; a run without any reads as none
- stats: the format 4 migration raises the stamp and rewrites no run
- stats: Groups lays out Primary, Secondary and Tertiary with each value's text
- stats: a run without stats shows dashes in every row
- stats: deltas against the compared run, signed, the percent deciding a rated row

### test_casts.lua (10)

- casts: Encode writes centiseconds, a p before a pet cast, comma-joined
- casts: Decode reads the stored string back, skipping what does not parse
- casts: an important ability's base cooldown is 29 s or more
- casts: Important and Of read a run's record; a run without one has none
- casts: Group puts cooldowns first, longest first, then the rest by count
- casts: nothing is heard before Begin or after Stop; other units are never heard
- casts: times are on the race clock; a cast heard while armed is negative
- casts: only the last 10 s before the clock starts are kept; the player's earlier casts are counted
- casts: auto-repeat attacks, a castGUID heard twice and a sealed spell ID are filtered
- casts: a channel counts once, whether its success comes before or after the channel start

### test_usage.lua (25)

- usage: the arm snapshot reads the on-use slots, the bag consumables and the auras, never the enchants
- usage: an unreadable bag stack makes the after counts unknown, never a false drop
- usage: a client without the APIs snapshots nothing and raises nothing
- usage: detection stacks casts, the bag drop and the arm's auras, in that order
- usage: a cast item's count drop is not counted again; unknown after counts detect no drop
- usage: a drop the casts before the pre-pull window explain is given back, never read as a use
- usage: of two items with one use spell, a cast is the one whose count dropped
- usage: the candidates are the on-use gear, then every bag consumable by item
- usage: SetUsed keeps a detected entry, adds a manual one and announces RUNS_CHANGED
- usage: SetUsed matches each tick to its own entry by slot, never one entry twice
- usage: a tick with a slot answers only an entry in that slot
- usage: an unticked food joins the candidates, once, and ticked again keeps its source; an old enchant goes
- usage: the hidden items parse from their setting, sorted and once each, and refuse anything else
- usage: Hide and Unhide write the whole list through the seam; Shown leaves out hidden items and enchants
- usage: the known items are every item the stored runs list, newest run first, each once
- usage: Watchers hears the casts from the arm, for the player and the pet
- usage: a race stores its casts and usage at the result, and nothing secret
- usage: a cast heard more than 10 s before the pull is not this race's, in the list or the usage
- usage: a lost race stores its casts and usage too, and nothing secret
- usage: a stand-down stops the cast list and drops it
- usage: a canceled race keeps nothing; the next arm starts a fresh list
- usage: a run resumed after a /reload keeps no casts and no usage
- usage: the format 3 migration raises the stamp and rewrites no run
- usage: the sample history and the sim's race carry casts and usage
- usage: a player with no consumables gets the sample Healthstone, used with no cast

### test_results_usage.lua (24)

- results usage: entries list the gear first, never an old enchant; a run stored before format 3 has none
- results usage: each entry's detail says how many times and when, or why there is no time
- results usage: names and icons come from the item data; food has its own
- results usage: one row per candidate, then each detected entry no candidate stands for
- results usage: the ticks follow the rows, and a change is any row ticked against what was stored
- results usage: a save keeps the used entries the edit does not list, a hidden item's
- results usage: an items cell draws what fits, or one fewer and +n
- results usage: the Used column draws the icons gear first, then +n; a dash for nothing or no record
- results usage: the Used tooltip names each entry with its icon and when, or says why there is none
- results usage: the Used column sorts by how many entries, a run with no record last either way
- results usage: a row's line is the name, then a dim dot and the detail; the name alone with none
- results usage: the detail follows the name on its line, cut at the row's edge, in and out of the edit
- results usage: the detail shows what was used, each with its icon and when, Edit and no Save
- results usage: a run with nothing used says so in a dim line, and Edit still opens the list
- results usage: Edit lists every candidate and the extras, used ones ticked; Edit again leaves unsaved
- results usage: Save is live only while the ticks differ, writes them through SetUsed and leaves the edit
- results usage: an unticked Well Fed stays listed in the edit and can be ticked again
- results usage: a redraw of the same run keeps the edit and its ticks not saved yet, and the scroll
- results usage: a run stored before format 3 says Not recorded, with no rows, no Edit and no Save
- results usage: a sample run's edit changes it in memory only; the store never hears it
- results usage: a row's hover is the item's own tooltip with its detail and source after it
- results usage: a right-click in the edit offers Never show; the item leaves the edit, its ticks kept
- results usage: a hidden item is never listed, in the section, the Used column or its tooltip; un-hidden it is back
- results usage: a sample run hides the same items

### test_results_sections.lua (9)

- sections: every section heading has an arrow left of its text, open and chevron-down by default
- sections: the arrow and the heading's text each fold and open every section, the arrow's icon following
- sections: a folded section's body is hidden, and the sections under it move up by its body's height
- sections: the folded state is the profile's, read back by a rebuilt pane and by every run
- sections: Reset position keeps the folded sections; a profile reset and Reset all settings clear them
- sections: Add Note opens a folded Note; folding the Note while writing closes the box unsaved
- sections: a heading the run does not draw hides its arrow
- sections: a lost run after a drawn one hides Timing's heading hover, so it takes no click
- sections: Flags is a section heading over the yellow box; each flag's main line, detail and meaning read apart

### test_chart_icons.lua (29)

- chart icons: a cast's x is INSET + t / length across the width less both insets
- chart icons: a pre-pull cast clamps to 0:00, one after the buzzer to the end; no length, no icon
- chart icons: an icon is centered on its cast's time, held inside the plot at either end
- chart icons: an icon that would overlap the one before it on the top row takes the second
- chart icons: the rows the plot holds follow its configured height, at least one
- chart icons: the plot frame holds one icon row over the configured height, one more row in all
- chart icons: the columns and the best's diagonal scale below the reserved row
- chart icons: three casts in one second stack on three rows of the 80 px plot
- chart icons: three casts in one second on the short plot: one icon and a +2 mark
- chart icons: six casts in one second: four rows and a +2 on the 80 px plot, a +5 on the short one
- chart icons: crowds an icon's width apart on the last row get a mark each, never overlapping
- chart icons: only casts of an ability whose base cooldown is 29 s or more get one
- chart icons: drawn live on the running HUD, the spell's icon along the top, no geometry read back
- chart icons: two casts close together on the running HUD stagger onto the second row
- chart icons: three casts in one second are all captured and all drawn on the 80 px running chart
- chart icons: on the short plot the crowd's overflow is a +n mark whose tooltip lists each cast
- chart icons: six casts in one second: nothing dropped on the 80 px plot or the short one
- chart icons: the crowd's tooltip marks a pet's cast and takes nothing but a list
- chart icons: a running HUD icon's tooltip names the spell and its time
- chart icons: the live list is read again only when the race heard another cast
- chart icons: Show cooldown icons off draws none on the running HUD; on again brings them back
- chart icons: the setting's row reads Show cooldown icons and keeps its stored path
- chart icons: the result card and the Results detail draw the run's from its record
- chart icons: an icon's tooltip on the card and in the detail names the spell and when it was cast
- chart icons: Show cooldown icons off hides them on the card and in the detail too
- chart icons: a run recorded before casts were (format 2) draws its chart with none
- chart icons: test mode draws the sample's, live up to its still moment and all on the card
- chart icons: the sim's running chart keeps one cooldown list until another cast is heard
- chart icons: test mode's chart follows Show cooldown icons while it is on screen

### test_results_timeline.lua (20)

- results timeline: one row per ability and caster across both runs, each run's times and counts
- results timeline: cooldowns of 29 s or more first, the longest first; then by count, the player's before the pet's
- results timeline: the axis runs to the longer race, in quarters; a tick's x is clamped inside its lane
- results timeline: the detail's Timeline button is live for a run with casts and disabled without
- results timeline: two lanes per ability, this run's gold ticks on top and the best's blue below, with counts
- results timeline: the legend names both runs; a tick's tooltip names the spell, its time and its run
- results timeline: each lane's count sits just past the lane's right end, not out at the window's edge
- results timeline: overlapping icons stack onto extra rows and the strip grows to fit them all
- results timeline: the Casts strips show every cast of both runs as its icon on the lanes' time axis
- results timeline: a strip grows with the casts stacked at one time; the lanes start under it
- results timeline: an icon's tooltip is the client's spell tooltip, then its time and its run on bullets
- results timeline: a strip with no casts shows a dim note in place of its icons
- results timeline: its minimum width is 640, so the icons get room; no stored size, it opens at the Results window's
- results timeline: it follows the detail: another run, a pick and Clear Pick redraw it
- results timeline: with no run to compare with, or one with no casts, the blue lanes stay empty under a note
- results timeline: a run with no casts or no run at all shows a message in place of the lanes
- results timeline: Escape and its close control close it, as does the Results window closing
- results timeline: it scrolls by a pair per notch; a move and a resize are never stored; Reset position puts it over the Results window
- results timeline: it follows Master scale while open
- results timeline: a stand-down hides it, and nothing opens it while stood down

### test_results_timeline_zoom.lua (7)

- timeline zoom: the Casts section is roomier: a wider row pitch than the icon, gaps around the strips
- timeline zoom: a second time axis under the compared run's strip, the same labels as the pinned one
- timeline zoom: the controls sit at the right end of the Casts heading line and step through the zooms
- timeline zoom: zoomed in, the strips and the lanes widen together and the view pans across the axis
- timeline zoom: a zoom keeps the view's middle; zoomed in, Shift+wheel pans and the wheel scrolls
- timeline zoom: a redraw of the same runs keeps the zoom; another run or compare target goes back to 1x
- timeline zoom: zoomed in, a drag of the grip keeps the view's left edge and re-pools nothing until the release

### test_results_timeline_modal.lua (8)

- timeline modal: the timeline sits one strata above the Results window, the cover over its every level
- timeline modal: opening it re-raises a shown StaticPopup (frame-layering-§4)
- timeline modal: the cover dims the Results window and takes its mouse and wheel while the timeline is open
- timeline modal: putting the cover up closes the window's menu and tooltip
- timeline modal: the cover goes with the Results window, at stand-down and on a source switch
- timeline modal: Escape closes the timeline before the Results window, in either close-stack order
- timeline modal: the talent tree's panel open closes the timeline and sends the window aside
- timeline modal: the timeline's skin is opaque, nothing of the Results window shows through

### test_results_timeline_view.lua (6)

- timeline view: the scrollbar shows only zoomed in, its thumb the view's share of the lanes' width
- timeline view: a drag of the thumb or a click on the track scrolls Casts and By ability together
- timeline view: This run and Best run sit on their strips' middles, however many rows each grew to
- timeline view: nothing between the strips but a lane pair's gap, through a resize (UT-P17)
- timeline view: it opens exactly over the Results window, expanded or collapsed, never stored
- timeline view: over a Results window smaller than its minimums, it keeps its minimums

### test_results_timeline_scroll.lua (8)

- timeline scroll: the wheel scrolls up and down at any zoom; Shift+wheel left and right only zoomed in
- timeline scroll: the zoom and arrow tooltips say how the wheel and the arrows scroll
- timeline scroll: the arrows follow reset and come before the ?, chevrons from the catalog
- timeline scroll: each arrow pans a quarter of the view, clamped to the axis
- timeline scroll: the arrows are disabled and dimmed at 1x and each at its end of the axis
- timeline scroll: the thumb dragged to the end snaps onto it, so the right arrow goes off
- timeline scroll: zoomed in on a run with no casts, the arrows stay off
- timeline scroll: the six heading-line controls and the zoom level read one size

### test_results_timeline_controls.lua (13)

- timeline controls: a Casts icon's and a By ability tick's tooltips open right of the window, level with them
- timeline controls: against the screen's right edge the tooltips open left of the window instead
- timeline controls: Ctrl+wheel up zooms in a step and down out a step, the buttons' steps
- timeline controls: Ctrl wins over Shift; off the time area the zoom keeps the view's middle
- timeline controls: Ctrl+wheel keeps the time under the cursor where it was, clamped to the axis
- timeline controls: CursorAt is how far across the lanes the cursor is, nil off them
- timeline controls: read left to right the line is the zoom level, -, +, reset, <, >, ?
- timeline controls: the ? is always live, turns gold under the pointer and its tooltip lists the mouse controls on bullets
- timeline controls: the controls end on the lanes' right edge, the strips' too, through a resize
- timeline controls: the strips sit a lane pair's gap apart, no line between, the labels on their strips
- timeline controls: the zoom level keeps its gray at 1x and runs from gold to red above it
- timeline controls: every corridor wears its run's dark, translucent color
- timeline controls: a /run change to CORRIDOR shows on Repaint; closed, Repaint does nothing

### test_results_gear.lua (13)

- gear view: ParseLink reads the item, its enchant and its gems from the stored link
- gear view: the cells follow the character panel, from the constants, the optional slots only when filled
- gear view: SlotDiff tells an item change, the item level, the enchant and the gems apart
- gear view: a slot's marks, a missing enchant or gem the compared run had, and its notes
- gear view: CenterOver centers the view over the Results window from its anchor
- gear view: a modal over the Results window: its strata, the cover, the opaque skin
- gear view: Escape closes the view first and the Results window stays
- gear view: it closes with the Results window
- gear view: each slot's item, item level and marks; Shift-click and the tooltip go to the client
- gear view: against the compared run, changed items tinted, item levels colored, enchant and gems edged
- gear view: the stats column with deltas against the compared run, dashes for a run with none
- gear view: the followed run deleted (the pane left empty) closes the view
- gear view: a run without a compared run marks nothing and says so

### test_insights_data.lua (13)

- insights: Runs.OptionLists has each list without its All head, and WithAll adds it
- insights: Filter defaults wide, keeps lost runs out and maps Clean only to Hide flagged
- insights: Options lists each facet's values among the runs every other filter passes, with counts
- insights: a closed dropdown names its choices on the All head, and a pick by its name alone
- insights: Normalize sets a 0-run selection to All, never the one just changed, in bar order
- insights: Compute on no runs returns zero cards and empty sections
- insights: Compute's cards over the owner-shaped fixture
- insights: Compute's boards and progression are board-relative
- insights: Compute's board tabs, one per target x length pair, in the catalog's order
- insights: Compute's new bests beat an earlier best on their board, in date order
- insights: Compute's counts by character, target, length and day, gap days included
- insights: Compute buckets the damage tail, the 155 s outlier in 20+
- insights: Compute lists late casts by spell, ignored apart, a sealed one as Unknown

### test_insights.lua (59)

- insights charts: nothing above the host section reads NS or a client global but CreateFrame
- insights charts: the header names the LootHistory source commit the port came from
- insights charts: New wants a host pool, and fills the colors and fonts it is not given
- insights charts: truncate counts glyphs, not bytes, and ends in an ellipsis
- insights charts: tipText states the value beside the full label
- insights charts: fitFontSize shrinks only an overflowing figure, never under the floor
- insights charts: the ranked palette cycles, and a map keeps one color per key
- insights charts: a palette getter is read at each draw, so a skin switch moves it
- insights charts: a bar section scales to its longest bar and colors label and fill alike
- insights charts: every bar's hover states its value; a row's own tip lines win
- insights charts: an empty section hides its header and leaves the cursor where it was
- insights charts: a legend's chips start under the track, not the labels, and wrap
- insights charts: a sublabel draws a second, muted line, and every row of its section grows
- insights charts: RangeScale spans the lowest worst to the highest best, opening a point
- insights charts: a range section draws worst to best with an average mark, on a scale it names
- insights charts: a legend can start at a given edge (under a strip, not a bar track)
- insights charts: a stacked bar shows one segment per share, each hover naming its value
- insights charts: a strip draws one colored column per bucket, its hover above the column
- insights charts: a strip's labels are level, hung under the axis line, in the band it reserves
- insights charts: a strip takes a fixed top, and drops a label too close to another one shown
- insights charts: StripLabels keeps the label of the day with more columns, not the earlier one
- insights charts: StripLabels keeps the end labels inside the content on a dense strip
- insights charts: a strip shifts an end label by its offset, from under its column
- insights charts: StripSlots widens the columns up to a cap, and never below 2 px
- insights charts: a list panel caps at ten rows, sized to them, each hover stating its value
- insights charts: a list row's click is the row's own, and a reused row forgets the last one
- insights charts: a second pass after ReleaseAll builds no frame; every pool comes back whole
- insights charts: a divider rules both sides of its centered title in the host's colors
- insights charts: a stat card is LootHistory's: the gold figure on top, centered, the caption below
- insights charts: the panel comes from the host, a plain frame without one
- insights charts: the DpsRace host pools through NS.Pool and draws in the window's look
- insights charts: the DpsRace host's tooltip is a gold title over bulleted lines, by the cursor
- insights tab: built on its first show, its tab label gold while it shows
- insights tab: the dropdowns list the stored runs with their counts, led by All (no Current head)
- insights tab: a filter redraws the cards, and narrows the other dropdowns (faceted)
- insights tab: a selection left with no runs falls back to All; the one just changed never
- insights tab: the cards state the ten figures, each hover naming its value
- insights tab: a card's figure is gold, and colored where it means something
- insights tab: CardGrid packs four a row, and a short last row is shared out
- insights tab: the cards fill even rows across the content, none half empty
- insights tab: above 60 runs the progression is one column a day, the same day of two years apart
- insights tab: DPS Progression carries a legend of its specs in their class colors
- insights tab: a section with nothing to show hides; Top Spells and Races By Length are gone
- insights tab: a tab per target x length board, the most raced first, the pick kept while present
- insights tab: Consistency on a board tab is a worst-to-best range per spec, the average marked
- insights tab: Races By Character x Length stacks each character's races in the length colors
- insights tab: one date format everywhere: the day, then the time where it matters
- insights tab: Late Casts keeps room for the ignored spells when the counted ones pass ten
- insights tab: Late Casts lists the counted spells, then the ignored ones dimmed and tagged
- insights tab: a right-click on a Late Casts row opens the ignore list's menu, which redraws the tab
- insights tab: a Recent New Bests row opens its run on the Runs tab; a right-click its row menu
- insights tab: with no run the empty state shows, and every card and section hides
- insights tab: Save, Clear and Reset keep the view at profile.views.insights
- insights tab: test mode fills the tab from the sample history; Save refuses and nothing is stored
- insights tab: the player's view comes back when test mode ends, so Save never stores the sample's fallback
- insights tab: a load with no library draws no dropdown, and the tab still works
- insights tab: Resize re-plans the bar and the scroll frame and rebinds nothing
- insights tab: the bar takes two rows in the collapsed window and one in the expanded, edge to edge
- insights tab: the wheel scrolls the content, clamped to it

### test_sizing.lua (13)

- sizing: a size change the grip did not start redraws at once
- sizing: while the grip is held, one cheap layout a frame; one redraw on release
- sizing: changes inside one frame coalesce into one layout now and one next frame
- sizing: a right press or a refused gate starts no drag
- sizing: a hide while the grip is held ends the drag as a release would
- results sizing: a 30-frame drag rebinds no row and redraws no detail until the release
- results sizing: a drag keeps the view's minimum and shrinks the list without a rebind
- results sizing: the Insights tab and the collapsed view's open detail resize without a redraw
- results sizing: the first drag after opening moves every row's cells, none left behind
- results sizing: a rebind inside a row the drag adds leaves no second row behind
- timeline sizing: a 30-frame drag moves the ticks and the cast icons and re-pools nothing until the release
- hud sizing: a 30-frame drag lays out the body on screen alone; the release lays out all and redraws
- hud sizing: locked, the grip starts no drag

### test_tooltips.lua (4)

- tooltips: one line under the title stays plain; the title never takes a bullet
- tooltips: two or more lines go on bullets in their own colors, a dim footer hint among them
- tooltips: after the client's spell text only the addon's own lines count, and only they take bullets
- tooltips: a shared button's { title, text, ... } follows the same rule

### test_schema.lua (18)

- schema: the load-time shape check finds no error and every stored path resolves
- schema: Master controls carries exactly the rows this addon has state for, in order
- schema: the Enable row is labeled with the brand
- schema: every row has a group, a label and a page
- schema: a write goes through the seam, reacts, and announces SETTINGS_CHANGED once
- schema: a profile change announces SETTINGS_CHANGED through the one sender
- schema: an unknown path is refused and stores nothing
- schema: the late-cast ignore list is one Race string row of spell IDs; junk is refused and stores nothing
- schema: the Minimap row reads SHOWN and stores LibDBIcon's inverted `hide`
- schema: Reset all settings is a profile reset and never touches the Minimap button
- schema: Test mode is a session-only checkbox over the preview
- schema: entering combat ends test mode, and says so once
- schema: General visibility changes the registration set while enabled
- schema: a migration runs once and stamps the stored version
- schema: migration 4 keeps an old profile's expanded view and drops the timeline's place
- panel: the category registers eagerly and every page body renders on first show
- panel: the landing page is the library's, with the logo and one row per verb
- schema: a new profile and Reset all settings open each window at its minimum width

### test_settings.lua (37)

- settings: every schema row has default, enUS label and desc
- settings: the stored paths, types, defaults and ranges are exactly the pinned set
- settings: HUD Appearance's chart blocks: Damage chart (bar, height, column gap), Chart background, Pace bar
- settings: every row sits on a page the panel draws, and every page has a group
- settings: grace slider 0..5 step 0.1, restartGap 3..15, history.keepDays 0..3650 default 90
- settings: the scoring sliders say they apply to new runs
- settings: the Race page's rows, ranges and defaults
- settings: the live breakdown's rows 0 (all) ..15 and reads 2..10 per second, on HUD > Race HUD
- settings: a write out of range is refused and stores nothing
- settings: changing grace does not alter saved runs
- settings: a live breakdown change redraws the HUD
- settings: the HUD's show mode is on the HUD page's Race HUD tab; `always` opens the HUD
- settings: the race clock is a Race HUD row: both, left or elapsed, default both, redrawing the HUD
- settings: the General, Race, HUD and History pages register and render quietly
- settings: the pages register in the panel's order, General first and Profiles last
- settings: the HUD page holds Race HUD then HUD Appearance; General holds Master controls, New-best toast, then Skin
- settings: HUD > Race HUD draws Display, then Live breakdown, in the pinned order
- settings: Race is two tabs, the race's timeline then Training dummies, in the pinned order
- settings: the sticky-combat hint's tooltip states its range
- settings: the show mode's tooltip points at General visibility
- settings: General's Defaults names Master controls, the toast and the skin, and not the keys or the HUD
- settings: the HUD page's Defaults names the Race HUD tab and HUD Appearance
- settings: History says how many runs are stored
- settings: Purge history… asks first, then deletes through Recorder.DeleteAll
- settings: Purge history… is refused while a race is armed
- settings: History ends with Purge history…, after the stored count, under no heading of its own
- settings: History's Usage tab draws the hidden items as the library's ID list, writing through Usage
- settings: History repaints when the hidden items change from anywhere, and not for other settings
- settings: Days to keep says it is account-wide, and its label carries no suffix
- settings: lowering Days to keep never deletes on the spot
- settings: the global reset confirms with options-ui-§12's one wording, verbatim
- settings: Race draws the late-cast ignore list as the library's spell ID list, writing through LateIgnore
- settings: Race's Reset list puts the six defaults back and touches no other Race setting
- settings: Race's Defaults resets the ignore list too, and its tooltip says so
- settings: Race repaints when the ignore list changes from anywhere or the profile does, and not for others
- settings: Race's Training dummies tab: the blurb, Add your target, your list, the built-ins, Reset list
- settings: Race repaints when your training dummies change from anywhere

### test_skinsetup.lua (22)

- skin seam: the owner is the folder name, and NS.Skin is its facade
- skin seam: the owner is registered at file load, before the profile store exists
- skin seam: the read answers Ka0s Default before the profile store exists
- skin seam: Core's window edge is handed the owner
- skin seam: the dropdown and the test strip factories are handed the owner
- skin seam: every owner token is namespaced dr. and registered with the owner
- skin seam: under Ka0s Default each owner token is today's pixel
- skin seam: under another skin a wash is that skin's role color at the wash's alpha
- skin seam: the eight skin keys default to Ka0s Default, the picker unseen
- skin seam: every skin key is a skip-render schema row on the Skin tab
- skin seam: the skin row's values are every registered skin, in the library's order
- skin seam: /dr set refuses a skin that is not registered and applies one that is
- skin seam: /dr set reaches an exception, and only its own half
- skin seam: the Skin tab is the library's, after New-best toast and before Keybindings
- skin seam: one tab pick is one effective SetChoice, one repaint and no reload
- skin seam: the tab's Ignore fonts reaches the library and the profile, one repaint
- skin seam: another addon's copy to every Ka0s addon repaints this one once
- skin seam: login applies the stored skin, exceptions and overrides
- skin seam: a profile switch applies the new profile's skin, panel built or not
- skin seam: Reset all settings puts the skin back on Ka0s Default and applies it
- skin seam: the degraded facade answers every name the live facade carries
- skin seam: each host-copy skin token is the live library's Ka0s Default value

### test_skin_literals.lua (3)

- no color literal outside core/SkinSetup.lua and the named allow-list
- every allow-list entry carries its reason
- the gate is falsifiable: a planted literal of each shape is reported

### test_skin.lua (12)

- skin: every owner token a source file names is registered
- skin: every owner token resolves through the facade, its Ka0s Default value under Ka0s Default
- skin: Ka0s Default draws each flat button's fill, edge and label as before, enabled and disabled
- skin: the buttons are the skin's Button, their slots remapped by token name
- skin: Ka0s Default draws the faint box, the callout and the badge as before
- skin: the live colors are Ka0s Default's own values for the HUD and the Results list
- skin: a switch moves every live color in place and re-tints what the host painted
- skin: a data hue stays the same under every skin
- skin: the escapes and the markup a token feeds keep the literals' bytes under Ka0s Default
- skin: a skin switch redraws the sorted column's arrow in the new skin's icon.arrow
- skin: the custom-length box draws the skin's input box under every skin, Ka0s Default included
- skin: the Arm Race label is opaque once enabled, in every skin (D-25, image-55..57)

### test_skin_hud.lua (10)

- skin hud: the defaults list every companion, on, and the full-path list matches them
- skin hud: the clocks keep their monospace face, with no companion (D-15)
- skin hud: each companion is a bool row, default on, governing its picker
- skin hud: a companion on draws the skin's face or texture, off the stored pick, never rewritten
- skin hud: Ignore fonts gives each face block its stored face, the textures still the skin's (R-1)
- skin hud: under Ka0s Default the blocks draw Prototype and the Ka0s Default bar through LSM
- skin hud: the Results table's bar cells and their text follow the skin too (D-16)
- skin hud: a skin switch restyles the blocks and moves the face, never a color (X4)
- skin hud: the v6 step puts every stored companion back on, keeping the picks and the colors
- skin hud: the reset runs once, and a player's later pick is kept

### test_skin_fonts.lua (12)

- skin fonts: every font block carries size, color, class color, flags and shadow
- skin fonts: every Font flags row leads with From skin and defaults to it
- skin fonts: From skin follows the Font outline; a picked flag wins
- skin fonts: the mono clocks are never outlined by the Font outline; a picked flag wins
- skin fonts: while Ignore fonts is on, From skin draws the library's stock flags
- skin fonts: the Results detail's breakdown list draws its spell rows as window text
- skin fonts: the drawn FontString takes the resolved flags
- skin fonts: without the library From skin draws the outline
- skin fonts: the v7 step moves a stored old-default flag onto From skin, and keeps a changed one
- skin fonts: the v7 step runs once, so a None picked afterwards is kept
- skin fonts: a block on the skin's face draws the skin's HUD scale; its own face the stored size
- skin fonts: the clocks keep their stored size in every skin

### test_skin_picker.lua (12)

- skin picker: the spec names this owner, its seams, the General page's Skin tab and the eye
- skin picker: an unseen profile shows it; a seen one does not
- skin picker: it shows once after login, on a two-second AceTimer the stand-down cancels
- skin picker: in combat a start waits for PLAYER_REGEN_ENABLED, once
- skin picker: the stand-down drops a held start and shows nothing while the addon is off
- skin picker: a new profile and a reset profile show it again
- skin picker: the harness login shows the library's window
- skin picker: the player's close marks it seen; this addon's own hide does not
- skin picker: a profile that has seen it takes a shown picker down, unmarked
- skin picker: the eye turns test mode on, and with it on shows the Results window
- skin picker: the Profiles page paints the tree AceConfigDialog draws, on every render
- skin picker: degraded, no picker shows and the Profiles paint is a no-op

### test_skin_outline.lua (10)

- outline: a fresh profile stores All text, the library's default, and applies it
- outline: the schema row is a skip-render Skin tab row offering the library's modes, in order
- outline: the write seam stores media.outline, and leaves it alone when it is nil
- outline: another addon's copy reaches the store through WriteChoice
- outline: the row's write applies the mode live, and only its own half
- outline: /dr set refuses a mode the library does not know
- outline: the stored mode is applied at login
- outline: a profile switch applies the incoming profile's mode, and back
- outline: Reset all settings puts the outline back on All text and applies it
- outline: without the library the apply seam answers false and the default still stores

### test_skin_verb.lua (6)

- skin verb: the row sits right after config, with the library's help words
- skin verb: /dr skin shows the picker on a profile that has closed it
- skin verb: NS.RunSkinVerb hands O.SkinVerb this addon's first-run spec
- skin verb: in combat every call prints the library's gray line and shows nothing
- skin verb: refused while the addon is disabled, and no picker shows
- skin verb: without LibKa0s the verb prints the library-absent line

### test_slash.lua (37)

- slash: bare /dr opens the settings panel
- slash: `options` is the legacy spelling of `config`
- slash: help lists every COMMANDS verb, in order
- slash: the landing page's rows come from the same table
- slash: disable and enable write the `enabled` row through the seam and echo it
- slash: `debug on`/`off` flip the session flag; bare `debug` toggles only the window
- slash: `perf` is the host's verb and prints the harness's lines
- slash: the schema CLI reads and writes through the seam
- slash: `resetall` asks first, through the one popup
- slash: the stub's refusal format is byte-equal to the live library's
- slash: library absent, /dr still answers, and enable/disable still land
- slash: the stub's live-verb set is the library's LIVE_VERBS, no more and no less
- slash: the stub carries no library string but the refusal format
- slash: the feature verbs follow `version`, in the spec's order
- slash: arm parses 90, 1:30, 3m and rejects 0 and 901
- slash: a bare arm uses the last length, and an armed length becomes the last one
- slash: arm prints the refusal line Race.Arm's reason maps to
- slash: arm then cancel goes armed and back to idle, one line each
- slash: target prints name, npcID and category
- slash: an uncataloged target reads as Other
- slash: hud show, hide and toggle; a bare hud toggles
- slash: results opens the Results window; results insights opens Insights, and bests still does
- slash: test turns test mode on and off through the Master controls row
- slash: test armed|running|result holds that HUD body still, on or switched to; another word prints the usage
- slash: sim plays the default scenario or the one named; an unknown one lists them all
- slash: the sim help line lists every scenario Sim.Names() has
- slash: lock and unlock write the Lock frame row through the seam and echo it
- slash: /dr and /dpsrace both dispatch
- slash: feature verbs answer the enable line while disabled
- slash: the Arm or cancel key arms the last length, then cancels; a pending result is kept
- slash: a bare ignore and ignore show print the list, one spell a line, 8690 as every hearthstone
- slash: ignore add takes an ID, a link or a name, and says when the spell is already ignored
- slash: ignore remove counts a spell again; a variant ignored through 8690 takes 8690 off
- slash: ignore defaults puts the six back, as reset race.lateIgnore does
- slash: ignore answers a bad word, a missing spell or a name it cannot place with one line, writing nothing
- slash: ignore is a settings verb: it answers while disabled, on both arms
- slash: the live dispatcher's live set is the library's LIVE_VERBS plus ignore and targetdummy

### test_share.lua (14)

- share: Share.Line matches the mockup format
- share: the target type is named; an uncataloged target by its own name; incomplete is said
- share: a lost run has no line, and the prompt says so
- share: no chat escape survives into the line
- share: Share refuses in combat
- share: the prompt offers say, party, raid, guild and whisper; a channel you are not in is grayed
- share: a send that finds the player in combat since the menu opened is refused
- share: whisper asks for a name, then sends to it
- share: the HUD's and the Results window's Share are live now Share exists
- share: arming prints the armed line with the length and the target
- share: a result prints the score line with the delta, the flags and the tail
- share: the score line counts only the late casts the ignore list leaves (#8)
- share: the race's own result is printed once, when it resolves
- share: the chat sender and the number formatter are reached only through NS.Compat

### test_toast.lua (19)

- toast: a complete run that beats the board's best toasts once, whatever the HUD shows
- toast: none for an incomplete or lost run, a run that is no best, a board's first run, or turned off
- toast: the payload names the spec and class, the board's chips, the DPS and the gain over the old best
- toast: with no previous best to name, the DPS line is the DPS alone in the text color
- toast: a flagged run may toast, its flags on the last line as the result card words them
- toast: a new best whose late casts are all ignored shows no flags line and no ignored chip
- toast: it closes after Toast duration, plays its sound only with Play a sound on
- toast: test mode holds the sample race's toast, and its end takes it down
- toast: Test toast queues a sample that runs its course, and a second click replaces it
- toast: a real toast never moves; in test mode or as a sample it drags
- toast: a drag stores the place in the profile in UIParent units; Reset position clears it
- toast: a profile switch follows the new profile's switch: a toast up goes, test mode's comes back
- toast: the stand-down takes the toast down and drops what waits; a result while down shows none
- toast: 25% larger, its height the named constant, every size scaled by the same factor
- toast: the trophy is as tall as the three rows, the rows evenly spaced and padded
- toast: the class and spec icons sit beside the spec and class words
- toast: a class or spec the client cannot draw leaves no icon
- toast: a spec icon without a class icon sits one gap after New best:
- toast: the rows' text draws at the scaled sizes

### test_preview.lua (23)

- preview: test mode holds the running body still with live figures, chart, pace bar and spells
- preview: the still running clock follows the Race clock setting
- preview: a queued state opens on that body; SetState switches armed, running and result
- preview: the test strip says so on the HUD while it is on, and only then
- preview: with no Widgets library each window's title carries the marker
- preview: test mode opens the Results window on the sample history, with its strip
- preview: the detail's Delta box and New best badge read the sample history's Runs view
- preview: the sample history covers every status, target type, preset length, notes, loadouts and charts
- preview: the sample detail draws its chart, compare and gear; the Insights tab counts the sample
- preview: a note or a delete changes the sample in memory; Save view and Share refuse
- preview: ending it gives the store back, the player's view and an open window kept open
- preview: a Results window test mode opened closes with it
- preview: a Results window the player closed and reopened stays open when test mode ends
- preview: arming a real race ends test mode and gives the Results window the store
- preview: a start in combat is refused with one line; combat ends it and says so
- preview: a start during a real race is refused
- preview: turning it off gives the HUD back, closing it if test mode opened it
- preview: closing the HUD ends it; Reset all settings ends it
- preview: the stand-down ends it silently and gives the store back
- preview: over a real result card its controls never touch the real race
- preview: a HUD test mode opened is handed to the race that ended it, and closes with it
- preview: a stand-down drops the windows test mode opened
- preview: every start and stop repaints an open panel's Test mode checkbox

### test_sim.lua (13)

- sim: each scenario plays its bodies, then opens the Results window on its run, never storing it
- sim: newbest beats the history's best: the chart and pace bar against it, a New best chip
- sim: behind finishes under the best with a minus chip
- sim: first races a board with no best: the chart on its own scale, no pace bar
- sim: shared draws no chart and no pace bar, live or on the card
- sim: flagged shows the late cast after the buzzer and on the card
- sim: incomplete and died end before the buzzer and read out of combat
- sim: the end conditions: combat, arming a real race, the switch; refused in combat and in a race
- sim: closing the HUD, Reset all settings and the stand-down end a running script
- sim: switching to test mode stops the script; a sim restarts in place
- sim: Stop Now on the Stop! or waiting body jumps the script to the result; Cancel ends the sim
- sim: the sample result card's Delete is grayed and does nothing
- sim: the result card draws the best's diagonal with a best before the run, and none on a first race

### test_launcher.lua (8)

- launcher: one object named for the folder, labeled with the brand, wearing the logo
- launcher: left-click opens the settings panel
- launcher: right-click lists Enabled, Locked, Test mode and Show window, in that order
- launcher: each menu toggle runs the shared handler
- launcher: the Minimap button row hides and shows the real button
- bindings: both Show-window buttons exist, plain and hidden, with their labels
- bindings: a key press runs the same toggle the menu does
- bindings: Bindings.xml names exactly the three buttons, in the addon's category, no default key

### test_keybinds.lua (7)

- keybinds: NS.BINDINGS is Bindings.xml's order, Show window first, each with a tooltip
- keybinds: Bindings.xml is the addon's own category, no header, no default, labeled
- keybinds: the General page ends in the Keybindings tab, after Master controls
- keybinds: the tab's rows are NS.BINDINGS in order, labeled as the client labels them
- keybinds: a key bound in the tab is the client's key; one set on the client's page shows
- keybinds: in combat the tab binds nothing
- keybinds: the General Defaults tooltip says it leaves key bindings alone

### test_disabled.lua (17)

- Disabled 1: enabled, the addon registers something and shows something at all
- Disabled 2+3: disabling through the write seam leaves NO registration behind
- Disabled 2+3 (live): a module's bus receiver goes at stand-down and comes back
- Disabled 2+3 (degraded): a module's bus receiver goes at stand-down and comes back
- Disabled 4: no timer, ticker or OnUpdate is left armed, and none re-arms
- Disabled 5: every display that was shown is hidden, refused at the source
- Disabled 5 (countdown): the center numbers go at the stand-down and nothing re-arms them
- Disabled 6: every event fired anyway writes nothing, prints nothing, shows nothing
- Disabled 7: every verb answers while disabled; a feature verb answers one refusal line
- Disabled 7 (degraded): the library-absent dispatcher gates a feature verb the same way
- Disabled 8: launcher clicks and the key binding write nothing and show nothing
- Disabled 9: re-enabling restores the set FROM CURRENT STATE, not a snapshot
- Disabled 10: releasing ONE hold does not resurrect an addon the other holds down
- Disabled: a profile switch re-reads the stored switch while disabled
- Disabled (race): Watchers holds no registrations and Race does nothing while disabled
- Disabled (race): an armed race is dropped by the stand-down and not resumed
- Disabled (race): a disabled login resumes nothing until the addon is enabled

### test_surface_parity.lua (17)

- parity: the degraded load still initializes, enables and answers /dr
- parity: the Options stub carries every public member of the live Helpers surface
- parity: the degraded load keeps the late-cast ignore list: the Race page draws quietly and /dr ignore adds by ID
- parity: the Bus stub carries the library surface, and its record the instance's
- parity: the Schema stub carries the runtime surface this addon binds
- parity: the Slash stub carries the live dispatcher's surface
- parity: the Lifecycle stub carries the live latch's surface
- parity: the Launcher stub carries the live launcher's surface
- parity: the DebugLog stub carries every member this addon calls
- parity: the Pool stub carries the array-shape members, on both arms
- parity: the Perf stub carries every member this addon reads, on both arms
- parity: the Core seam carries every member this addon reads, on both arms
- parity: the Widgets seam answers on both arms, nil being a real answer
- parity: the Media seam answers on both arms, nil being a real answer
- parity: the Env seam answers the TOC's version on both arms
- parity: the Toast stub carries a live toast instance's surface, and the degraded load toasts nothing
- parity: the hollow composers cost the library-absent load exactly the composed rows

### test_perf_harness.lua (4)

- perf: the descriptor declares the buckets, the SavedVariable and the one latch
- perf: every declared bucket is reached by a real bracket
- perf: outside an experiment the bracket records nothing
- perf: suspend takes the perf hold and the addon is inert; resume restores it

### test_loadorder.lua (4)

- load order: the runner loaded exactly the TOC's files, in the TOC's order
- load order: the hearthstones load before the ignore list, and the ignore list before its readers
- load order: every derived path exists on disk
- load order: no libs/ path leaked into the addon's own list

### test_vendor_sync.lua (3)

- libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
- tests/_kit is the test kit that shipped with that release
- the automated-test runner is recorded executable (100755)

### test_eol.lua (2)

- eol: every tracked file carries the terminator .gitattributes declares for it
- eol: .gitattributes is line-endings-§5's canonical body for this repo kind

### test_prose.lua (15)

- prose: no authored file carries a British spelling from localization-§5's published list
- prose: the gate carries localization-§5's two lists whole, and nothing of its own
- prose self-test: the carve-out suppresses the named generated folder, and only it
- prose self-test: a path the carve-out does not name is not covered by one that looks like it
- prose self-test: a carve-out that is not a set of path strings is a failure, not a silence
- prose self-test: a TOC's file lines are read as paths, and its directives and comments are not
- prose self-test: a .pkgmeta's ignore block is read, and the keys around it are not
- prose self-test: an ignore entry covers a path exactly, by folder, and by wildcard
- prose self-test: the carve-out admits a generated dump and refuses a file the TOC loads
- prose self-test: a waiver-file exclusion meets the same two refusals as the carve-out
- prose self-test: each list is refused on the matching rule its own scan uses
- prose self-test: the scan and the refusals read the added exclusions through one reader
- prose self-test: a narrowing is refused by what it suppresses, not by how it is written
- prose self-test: the disclosure names what each entry suppressed, and says when it is bounded
- prose self-test: a malformed waived is a failure, not a silence

### test_layout_cap.lua (13)

- layoutcap: every authored file over the 1500-line cap is named in the census
- layoutcap: no census row outlives the breach it records
- layoutcap: every over-cap census row carries one of layout-§1's three terminal states
- layoutcap: the census and the exempt set agree about which paths were exempted
- layoutcap: an empty census is written as a result rather than left standing empty
- layoutcap self-test: the parser reads the census nested under the register, and stops there
- layoutcap self-test: a census outside its register, or at the wrong level, is not read
- layoutcap self-test: an over-cap file missing from the census is reported, and an exempt one is not
- layoutcap self-test: a census row that outlives its breach is reported
- layoutcap self-test: an over-cap row that names no terminal state is reported
- layoutcap self-test: the census and the exempt set are held to naming the same paths
- layoutcap self-test: a census that states nothing is told apart from one that states none
- layoutcap self-test: the exempt set takes folders as well as paths

### test_diagnostics_contract.lua (9)

- diagnostics contract: both forms run the report
- diagnostics contract: the debug word is matched in any case
- diagnostics contract: both markers carry the brand and the end counts the report
- diagnostics contract: the report appends after what the console already holds
- diagnostics contract: the report lands with logging off and turns it on for the session
- diagnostics contract: an addon that opts out lands the report and leaves logging off (skipped: this addon keeps the default (Kit.diagnostics.enablesLogging is not false), so its report turns logging on; the case above holds it)
- diagnostics contract: with logging already on, the report writes no second enable line
- diagnostics contract: both forms run while the addon is disabled
- diagnostics contract: no other name runs the report

### test_lizard_sighted.lua (8)

- lizard sighted: every hazard lizard loses a function over is neutralized
- lizard sighted: fields, strings, comments and look-alike names come through unchanged
- lizard sighted: a method definition is rewritten to its dot form with self
- lizard sighted: no line is added or removed, CRLF included
- lizard sighted: countFunctions counts the keyword, not strings, comments or longer names
- lizard sighted: listedCounts reads the per-file table, once per file
- lizard sighted: parity names every file whose counts differ, and only those
- lizard sighted: lizard lists every function of a hazard fixture once it is sanitized

## Totals

| Suite | Cases |
|-------|------:|
| test_skeleton.lua | 8 |
| test_secrets.lua | 11 |
| test_meter.lua | 26 |
| test_dummies.lua | 5 |
| test_dummy_list.lua | 23 |
| test_recorder.lua | 22 |
| test_timeline.lua | 10 |
| test_scoring.lua | 9 |
| test_bests.lua | 21 |
| test_late_ignore.lua | 19 |
| test_late_ignore_ui.lua | 3 |
| test_race.lua | 58 |
| test_race_resume.lua | 16 |
| test_format.lua | 8 |
| test_hud.lua | 73 |
| test_hud_hint.lua | 6 |
| test_hud_tips.lua | 3 |
| test_hud_tiles.lua | 9 |
| test_chart.lua | 30 |
| test_pace.lua | 14 |
| test_countdown.lua | 20 |
| test_autoarm.lua | 30 |
| test_layers.lua | 7 |
| test_results.lua | 50 |
| test_results_fit.lua | 5 |
| test_results_group.lua | 6 |
| test_results_delta.lua | 4 |
| test_results_tree.lua | 5 |
| test_results_badges.lua | 10 |
| test_compare.lua | 23 |
| test_loadout.lua | 27 |
| test_stats.lua | 9 |
| test_casts.lua | 10 |
| test_usage.lua | 25 |
| test_results_usage.lua | 24 |
| test_results_sections.lua | 9 |
| test_chart_icons.lua | 29 |
| test_results_timeline.lua | 20 |
| test_results_timeline_zoom.lua | 7 |
| test_results_timeline_modal.lua | 8 |
| test_results_timeline_view.lua | 6 |
| test_results_timeline_scroll.lua | 8 |
| test_results_timeline_controls.lua | 13 |
| test_results_gear.lua | 13 |
| test_insights_data.lua | 13 |
| test_insights.lua | 59 |
| test_sizing.lua | 13 |
| test_tooltips.lua | 4 |
| test_schema.lua | 18 |
| test_settings.lua | 37 |
| test_skinsetup.lua | 22 |
| test_skin_literals.lua | 3 |
| test_skin.lua | 12 |
| test_skin_hud.lua | 10 |
| test_skin_fonts.lua | 12 |
| test_skin_picker.lua | 12 |
| test_skin_outline.lua | 10 |
| test_skin_verb.lua | 6 |
| test_slash.lua | 37 |
| test_share.lua | 14 |
| test_toast.lua | 19 |
| test_preview.lua | 23 |
| test_sim.lua | 13 |
| test_launcher.lua | 8 |
| test_keybinds.lua | 7 |
| test_disabled.lua | 17 |
| test_surface_parity.lua | 17 |
| test_perf_harness.lua | 4 |
| test_loadorder.lua | 4 |
| test_vendor_sync.lua | 3 |
| test_eol.lua | 2 |
| test_prose.lua | 15 |
| test_layout_cap.lua | 13 |
| test_diagnostics_contract.lua | 8 |
| test_lizard_sighted.lua | 8 |
| Skipped | 1 |
| **Total** | **1185** |
