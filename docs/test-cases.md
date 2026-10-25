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
- skeleton: the DB defaults load (global.runs empty, global.schema 2, schemaVersion stamped)
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

### test_scoring.lua (7)

- scoring: late cast boundaries
- scoring: QUIET_BEFORE_READ is 2.5s
- scoring: Dps complete = damage / length
- scoring: Dps incomplete = damage / endedAt
- scoring: Flags order and text
- scoring: Flags names late-cast spells through an optional resolver
- scoring: a clean complete run has no flags; lost stands alone at the end

### test_bests.lua (20)

- bests: Key is specID|category|length
- bests: incomplete and lost never count
- bests: the highest result.dps holds the board; a tie keeps the earlier run
- bests: cleanOnly excludes flagged
- bests: two Dungeoneer npcIDs share one board
- bests: spec, category and length each split the board
- bests: deleting a best promotes the next run
- bests: the cache is invalidated by RUN_SAVED and keeps cleanOnly apart
- bests: Delta reports new best and percentage vs previous best
- bests: Delta ignores later runs, other boards and runs that never count
- bests: Delta defaults its run list to the store
- bests: HoldingIDs names the holders of the all-runs and the clean-only boards
- bests: prune keep=0 removes nothing
- bests: prune keeps best-holding runs
- bests: prune never removes a running or stopping run, and stops at the holders
- bests: prune runs on RUN_SAVED with the global history.keep setting
- bests: prune never removes the run just saved, nor the race's own run
- bests: a raced run that lands below the best survives the prune its own save fires
- bests: prune runs at OnEnable
- bests: no prune and no cache work while disabled

### test_race.lua (52)

- race: the state names are the interface's
- race: arm refuses in combat and while a run is pending
- race: arm refuses while a stored run is pending, even when idle
- race: arm refuses when meter unavailable
- race: arm refuses a length outside 10s-15:00 and arms a valid one
- race: session created starts the clock and persists the run as running
- race: the target is re-read at combat start and the arm-time count is kept
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

### test_hud.lua (63)

- hud: switches body on RACE_STATE_CHANGED for all six states
- hud: a run that ended before the buzzer waits for its read on the waiting body
- hud: idle arm button disabled with reason in combat
- hud: idle Arm uses the picked length and target count; a refusal prints its line
- hud: a custom length is parsed, range-checked and selected
- hud: an unknown target is allowed and said so
- hud: a changed Default race length takes effect over the remembered pick
- hud: with no stored answer it falls back to defaults/Profile.lua, never a literal of its own
- hud: a target changed while the HUD is closed is never armed with the old count
- hud: reopening the HUD offers the target of the moment, not the one cached at close
- hud: running render raises nothing with secret values
- hud: running body shows no percentage text
- hud: live rows keep Blizzard's order and the configured count
- hud: a live read with no DPS figure shows a dash
- hud: the live DPS KPI shows a figure when the source carries no amountPerSecond (live client)
- hud: layout never calls GetWidth/GetPoint on breakdown rows
- hud: live reads stop when hud hidden or state leaves running
- hud: the stop body shows the live tail, time in combat, late casts and the grace
- hud: waiting hint appears after hintDelay and names only owned drop-combat spells
- hud: STOPPING redraws at a few Hz, and a steady stop body rebuilds nothing
- hud: the sticky-combat hint asks for the player's spells once per race
- hud: the live rows stop above the caption and CANCEL at every window height
- hud: live rows 0 shows every spell that fits and the wheel scrolls through the rest
- hud: the default window size shows every default live row under the chart and the pace bar
- hud: the result card's rows stop above its buttons at every window height
- hud: the result card follows Spell rows shown; at 0 it lists every spell and scrolls
- hud: the minimum height holds the idle body's whole stack
- hud: the result card's three buttons are chained by anchor, so they never overlap at the minimum width
- hud: Discard run on the waiting body throws the attempt away
- hud: result body shows % and the best delta chip
- hud: a first run is a new best; a slower one shows its deficit and its flags
- hud: a lost result says it could not be read
- hud: an incomplete run's chip names when combat ended, or that the player died
- hud: Race again re-arms the same length; Details and Share reach their modules
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

### test_chart.lua (24)

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
- chart: the Results detail shows the chart for a run raced this session only
- chart: the detail's title hover goes with its chart, so it never covers the section under it
- chart: a lost run has no chart on the card or in the detail
- chart: test mode draws the sample's chart against a sample best, then on its result card
- chart: test mode honors Show damage chart and Show pace bar
- chart: the diagnostics state section counts the loadout store and the races holding a chart

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
- countdown: test mode demonstrates it in its running phase, and it stops with test mode
- countdown: the test race's buzzer clears it, and the setting holds in test mode
- countdown: never broadcasts a pull timer nor drives Blizzard's TimerTracker
- countdown: the diagnostics state section names what it shows and holds

### test_layers.lua (6)

- layers: one table names the addon's tiers by the standard's keys
- layers: no strata string and no bare level number at a call site
- layers: the Race HUD is MEDIUM, toplevel and clamped
- layers: the Results window is HIGH, toplevel and clamped
- layers: the detail pane sits one band over the list pane, never by creation order
- layers: the countdown is FULLSCREEN, below every menu

### test_results.lua (50)

- results: runs list columns: date, class icon, spec icon, character, ilvl, target, time, damage, DPS, v/s Max, status, note
- results: the Note column cuts a note to 10 characters with an ellipsis, tips the whole note and sorts A to Z, none last
- results: the detail's section headings are the larger SECTION font; Spell breakdown heads the compare and the list
- results: the detail's header: 28 px class and spec icons, a larger name, no spec text; the spec icon names the spec
- results: the note shows as written under a Note heading; the heading also shows while writing one
- results: every cell and header has a tooltip; it sits right of the window, or left when there is no room
- results: the Status column tags each run; the DPS column shows every run's DPS
- results: Status is Max, Spec best, Flagged or Complete for a complete run, each with its icon
- results: race lengths take muted ROYGBIV colors for the presets and a neutral one otherwise
- results: the Time column and the Bests Length column take the length color; the tail stays gray
- results: Status tags are boxed in their hue with the icon inside
- results: the HUD never draws a race length in the Results length colors
- results: Damage and DPS carry bars from 10% (the smallest run the filters pass) to 100% (the largest)
- results: the bars take History > Results table's look, over the rows' own stripe
- results: the Damage and DPS bars run 10% to 100% within each target type
- results: v/s Max and the Max tag are per target type
- results: Group by character, class & spec or target, with folding headers
- results: Save, Reset and Clear the Runs view, and a saved view is what the window opens on
- results: Only best keeps the runs holding their board's best
- results: v/s Max is each run's distance from the max DPS among the runs the filters pass
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
- results: the live HUD's spell rows take no mouse
- results: saving a note never prunes the store
- results: Share is grayed without a Share module; a row's right-click menu notes, shares and deletes
- results: bests tab groups by spec x category x length with clean-only toggle
- results: the Bests board shows one category at a time, so a spec and length is one row
- results: list refreshes on RUN_SAVED
- results: Runs opens on the current character and spec, each a choice of its own
- results: the window is skinned, closable with Escape, resizable and clamped
- results: position, size and Master scale persist; Reset position restores them
- results: collapsed, the detail replaces the list, with a back control
- results: hidden with its parent is not closed by the player
- results: the stand-down hides it and the stand-up brings it back
- results: the library-absent load still draws the window, with no dropdowns or close control
- results: the diagnostics state section names the tab, the layout and the selection
- results: a centered GameFontNormal title, Title Case tabs and headers, compact rows, small gray footers
- results: the close control turns gold under the pointer and back to its gray

### test_results_fit.lua (3)

- results: every Runs column fits the narrowest list either view lays out
- results: the longest Status board fits after the boxed Spec best
- results: the Bests Flags chips are plain, and a two-flag best fits its column

### test_compare.lua (12)

- compare: CompareSpells matches by id, with each side's damage, share and the difference
- compare: a spell on one side only has nil damage and share on the other
- compare: rows sort by the run's damage, then the other's, then the id
- compare: a zero or missing damage total leaves the shares nil; duplicated ids add up
- compare: the figures and their % difference; none against a zero or missing figure
- compare: the default is the best on the run's board; for the best itself, the runner-up
- compare: a picked run wins while it is stored and not the run itself
- compare: the toggle sets the run beside the best: the score table and the compared breakdown
- compare: the best compares with the runner-up; a run alone on its board has the toggle disabled
- compare: the row menu's pick, the different-board note and Clear Pick
- compare: the toggle, Clear Pick, the note, the score table and each compared row have tooltips
- compare: the collapsed view draws the compare in the list's place; no number is read off a frame

### test_loadout.lua (26)

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
- loadout: a run stored before #6 says Not recorded, with nothing to view or copy
- loadout: View is grayed with a reason once the client's serialization version moved; Copy still works
- loadout: under the compare the changed slots are highlighted and a different loadout is marked
- loadout: the pure parts: changed slots, the link data, the talents text
- loadout: the copy window opens on the import string
- loadout: the Spec cell's tooltip names the loadout and notes gear changed since the previous run
- loadout: the share line takes the talents link only with Include talents link on
- loadout: Include talents link sits under Sharing on the History tab, before Storage

### test_schema.lua (15)

- schema: the load-time shape check finds no error and every stored path resolves
- schema: Master controls carries exactly the rows this addon has state for, in order
- schema: the Enable row is labeled with the brand
- schema: every row has a group, a label and a page
- schema: a write goes through the seam, reacts, and announces SETTINGS_CHANGED once
- schema: a profile change announces SETTINGS_CHANGED through the one sender
- schema: an unknown path is refused and stores nothing
- schema: the Minimap row reads SHOWN and stores LibDBIcon's inverted `hide`
- schema: Reset all settings is a profile reset and never touches the Minimap button
- schema: Test mode is a session-only checkbox over the preview
- schema: entering combat ends test mode, and says so once
- schema: General visibility changes the registration set while enabled
- schema: a migration runs once and stamps the stored version
- panel: the category registers eagerly and every page body renders on first show
- panel: the landing page is the library's, with the logo and one row per verb

### test_settings.lua (29)

- settings: every schema row has default, enUS label and desc
- settings: the stored paths, types, defaults and ranges are exactly the pinned set
- settings: HUD Appearance's chart blocks: Damage chart (bar, height, column gap), Chart background, Pace bar
- settings: every row sits on a page the panel draws, and every page has a group
- settings: grace slider 0..5 step 0.1, restartGap 3..15, history.keep 0..10000 default 0
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
- settings: the HUD page holds Race HUD then HUD Appearance; General keeps Master controls alone
- settings: HUD > Race HUD draws Display, then Live breakdown, in the pinned order
- settings: Race is a one-tab page along the race's timeline, in the pinned order
- settings: the sticky-combat hint's tooltip states its range
- settings: the show mode's tooltip points at General visibility
- settings: General's Defaults names Master controls, and not the keys or the HUD
- settings: the HUD page's Defaults names the Race HUD tab and HUD Appearance
- settings: History says how many runs are stored
- settings: Purge history… asks first, then deletes through Recorder.DeleteAll
- settings: Purge history… is refused while a race is armed
- settings: History ends with Purge history…, after the stored count, under no heading of its own
- settings: Runs to keep says it is account-wide, and its label carries no suffix
- settings: lowering Runs to keep never deletes on the spot
- settings: the global reset confirms with options-ui-§12's one wording, verbatim

### test_slash.lua (27)

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
- slash: results opens the Results window; results bests opens the bests
- slash: test turns test mode on and off through the Master controls row
- slash: lock and unlock write the Lock frame row through the seam and echo it
- slash: /dr and /dpsrace both dispatch
- slash: feature verbs answer the enable line while disabled
- slash: the Arm or cancel key arms the last length, then cancels; a pending result is kept

### test_share.lua (13)

- share: Share.Line matches the mockup format
- share: one target drops the count; an uncataloged target is named; incomplete is said
- share: a lost run has no line, and the prompt says so
- share: no chat escape survives into the line
- share: Share refuses in combat
- share: the prompt offers say, party, raid, guild and whisper; a channel you are not in is grayed
- share: a send that finds the player in combat since the menu opened is refused
- share: whisper asks for a name, then sends to it
- share: the HUD's and the Results window's Share are live now Share exists
- share: arming prints the armed line with the length and the target
- share: a result prints the score line with the delta, the flags and the tail
- share: the race's own result is printed once, when it resolves
- share: the chat sender and the number formatter are reached only through NS.Compat

### test_preview.lua (16)

- preview: preview runs armed->running->stop->waiting->result and never writes a run
- preview: the running body counts the 30s race down with live figures
- preview: the running clock follows the Race clock setting
- preview: the result card is the sample run, with its chips
- preview: the test strip says so on the display while it is on, and only then
- preview: with no Widgets library the title carries the marker
- preview: arming a real race ends preview
- preview: a start in combat is refused with one line; combat ends it and says so
- preview: a start during a real race is refused
- preview: turning it off gives the HUD back, closing it if test mode opened it
- preview: Start again restarts the script; Reset all settings ends it
- preview: the stand-down ends it silently and cancels its timer
- preview: over a real result card its controls never touch the real race
- preview: a HUD test mode opened is handed to the race that ended it, and closes with it
- preview: a stand-down drops the HUD test mode opened
- preview: every start and stop repaints an open panel's Test mode checkbox

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

### test_surface_parity.lua (15)

- parity: the degraded load still initializes, enables and answers /dr
- parity: the Options stub carries every public member of the live Helpers surface
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
- parity: the hollow composers cost the library-absent load exactly the composed rows

### test_perf_harness.lua (4)

- perf: the descriptor declares the buckets, the SavedVariable and the one latch
- perf: every declared bucket is reached by a real bracket
- perf: outside an experiment the bracket records nothing
- perf: suspend takes the perf hold and the addon is inert; resume restores it

### test_loadorder.lua (3)

- load order: the runner loaded exactly the TOC's files, in the TOC's order
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
| test_recorder.lua | 22 |
| test_timeline.lua | 10 |
| test_scoring.lua | 7 |
| test_bests.lua | 20 |
| test_race.lua | 52 |
| test_race_resume.lua | 16 |
| test_format.lua | 8 |
| test_hud.lua | 63 |
| test_chart.lua | 24 |
| test_countdown.lua | 20 |
| test_layers.lua | 6 |
| test_results.lua | 50 |
| test_results_fit.lua | 3 |
| test_compare.lua | 12 |
| test_loadout.lua | 26 |
| test_schema.lua | 15 |
| test_settings.lua | 29 |
| test_slash.lua | 27 |
| test_share.lua | 13 |
| test_preview.lua | 16 |
| test_launcher.lua | 8 |
| test_keybinds.lua | 7 |
| test_disabled.lua | 17 |
| test_surface_parity.lua | 15 |
| test_perf_harness.lua | 4 |
| test_loadorder.lua | 3 |
| test_vendor_sync.lua | 3 |
| test_eol.lua | 2 |
| test_prose.lua | 15 |
| test_layout_cap.lua | 13 |
| test_diagnostics_contract.lua | 8 |
| test_lizard_sighted.lua | 8 |
| Skipped | 1 |
| **Total** | **592** |
