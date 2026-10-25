# 2026-10-25: Results badges and length colors, Group by, pace range, the talent view, test vs sim

Branch `feat/2026-10-25-results-badges-sim`, from master `da963f6`. This is the owner's backlog after the
chart, compare and loadout merge.

**Gate per commit:** `lua tests/run.lua` and `luacheck .` (0/0), each through
`~/.claude/dev-copilot/bin/ka0s-bounded`. Gate on the exit code. Every touched function stays at CCN 15 or below.

**Checkpoints:** each step is one or more commits, and its box is ticked in the step's last commit. A fresh session
resumes at the first open box. The branch is pushed after each milestone and never merged without the owner's
go-ahead.

## Decisions (the owner, 2026-10-25)

- **Status names its board.**
  - The Spec best and Max statuses carry the target type and race length.
  - Status is a boxed badge (its icon inside, the first part only: Spec best, Max, Complete, Incomplete, Flagged,
    Died, Lost).
  - Spec best and Max are followed by plain text `<target> · <time>`, the time in its length color.
- **Race length colors, in the Results view only (never the HUD).**
  - The 5 presets (0:30, 1:00, 2:00, 3:00, 5:00) take ROYGBIV hues in a muted tone.
  - A non-preset length gets a neutral color.
  - The colors apply to the Time column and to the Status column's time text.
  - Badges may reuse hues, since the length colors are muted text.
- **Group by:** add *Duration*, and *Target type + duration*.
- **Talent view:** opening the tree from the posted chat link must not close the Results window. The tree opens over it.
- **Pace bar:**
  - The max is a configurable multiple of the best's pace, default 1.5× (was 2×).
  - The post-race result card shows the pace bar too: the run's plain final damage against the best's damage.
  - It is hidden with no best or on a shared session.
- **`/dr test` vs `/dr sim`:**
  - `test` shows static mocked data in every view (the HUD and the Results window).
  - `sim` plays a whole race through the scenarios: arm, race, post-race, then Results.
  - Neither writes to SavedVariables.
- **Reminder (not code):** iterate on the comparison view and the Dressing Room with the owner.
- **Chart border:** stays the fixed faint edge, with no setting (the owner, 2026-10-25).

## Steps

### B1: Runs Status and length colors

- [x] B1.1 Length colors: a pure `lengthColor(seconds)` with muted ROYGBIV hues for the presets and a neutral color
  otherwise, used by the Time column in the Results views only.
- [x] B1.2 Status as boxed badges with the icon inside and the first part only. Spec best and Max get the
  `<target> · <time>` text after the badge, the time length-colored. Tooltips, the sort and the Bests tab stay
  consistent.

### B2: Group by

- [ ] B2.1 Group by *Duration*, and by *Target type + duration*, with ordering, labels, saved views, tests and docs.

### B3: Pace bar

- [ ] B3.1 A pace range setting (default 1.5) driving `PaceMax`. The tick sits at 1/x.
- [ ] B3.2 The pace bar on the HUD result card (plain final damage vs the best), its settings respected, test mode
  included.

### B4: The talent view over Results

- [ ] B4.1 Find why the Results window closes when the talent tree opens (UIPanel and UISpecialFrames registration,
  strata), fix it without taint, and add a smoke row.

### B5: test vs sim

- [ ] B5.1 `/dr test`: static mocked data in every view (the HUD states and the Results window's mocked runs and
  detail). No engine, no SavedVariables.
- [ ] B5.2 `/dr sim [scenario]`: the scripted full race (arm, race, post-race, Results) across the scenarios, with
  the Results window showing the sim run in memory only.

### B6: Finish

- [ ] B6.1 Docs sync (ARCHITECTURE, schema, settings-panel, slash surface, smoke rows and the pending list, the test
  inventory) and a completeness pass.
