# Plan: new-best toast (#5), auto-show and auto-arm near dummies (#16), gear view (#17)

Opened 2026-10-28. Branch `feat/2026-10-28-toast-autoarm-gearview` (DpsRace) and
`feat/2026-10-28-toast-1.0` (LibKa0s, in a worktree off LibKa0s master, because another session is working
in the LibKa0s checkout on `feat/2026-10-28-skin-round5`). Resumable: each step is ticked in the commit that
finishes it; a run that stops resumes at the first unticked box.

## Decisions (the owner, 2026-10-28)

- **#5 toast:** build `LibKa0s-Toast-1.0` in LibKa0s first (LibKa0s#60, from DropWatcher's
  `modules/Toast.lua`), then build #5 on it. DpsRace keeps only the content builder (the best line) and the
  trigger. A board's first complete run does not toast (`Bests.Delta` must give `isNewBest and pct ~= nil`),
  decided 2026-10-25 on the issue.
- **Partial vendor (the owner, mid-run):** do NOT re-vendor all of LibKa0s now (the owner re-vendors it later
  with the other session's work). Copy only the Toast file into `libs/LibKa0s/`, byte-identical to the
  LibKa0s branch, loaded from DpsRace's TOC (the vendored `LibKa0s.xml` stays untouched). Toast-1.0 must
  therefore run on what LibKa0s v1.77.0 ships (no dependency on v1.78.0's skin engine; optional skin hooks
  only if they degrade when absent). Recorded as a temporary documented deviation in `docs/ARCHITECTURE.md`,
  re-check trigger: the next full LibKa0s re-vendor.
- **LibKa0s release:** version v1.79.0 on the branch (CHANGELOG section, Toast file minor 1, versioning
  test), no tag, no merge, no push of master without the owner's go-ahead. v1.78.0 is still a local tag being
  extended by the other session; the release order is settled at finalize.
- **#16 auto-arm:** targeting a cataloged dummy out of combat arms a race at the last-used length; the first
  hit starts it as today; targeting something else (while armed by this rule and not started) or Cancel
  disarms. Auto-show: the HUD opens by itself near a cataloged dummy. Both opt-in, off by default.
- **#17 gear view:** paper doll, no model: character-panel slot columns with icon, quality border, item
  level, enchant and gem marks, and a stats column in the middle. All stats: primary, stamina, secondaries
  (rating and %), tertiaries (leech, avoidance, speed) and armor, captured at arm from now on (older runs
  show gear only). Compare against the detail's compared run (best or picked): changed slots marked, stat
  deltas. Replaces the Dressing Room button.

## Steps

### L: LibKa0s Toast-1.0 (worktree, branch `feat/2026-10-28-toast-1.0`)

- [ ] **L1 Toast-1.0:** the shell from LibKa0s#60: one at a time from a queue, auto-close with a hover pause,
  close mark and right-click, the T5 alert layer, drag-to-place only when the host says so (test mode),
  position, scale and sound from the host's profile; the content drawn by one host-supplied builder. Tests,
  docs/api/Toast, CONSUMERS.md, versioning, CHANGELOG v1.79.0 (unreleased). Runs on v1.77.0's surface.
- [ ] **L2 review and fixes.**

### D: DpsRace

- [x] **D0 Plan** (this file).
- [x] **D1 #16 auto-show and auto-arm:** settings (off by default), detection from the target and nameplates
  against `defaults/Dummies.lua`, auto-arm through `Race.Arm` and its blockers, the way back out, stand-down
  in instances and PvP. Tests, docs, smoke rows.
- [x] **D2 #17 stats capture and gear view:** stats captured at arm through `NS.Secrets`, stored on the run
  (schema, docs); the gear view replacing the Dressing Room; compare against best or picked. Tests, docs,
  smoke rows.
- [x] **D3 Vendor Toast-1.0 only:** copy the LibKa0s branch's Toast file into `libs/LibKa0s/`, TOC line,
  provenance note in `CLAUDE.md`, the deviation row.
- [x] **D4 #5 toast:** the trigger on `RACE_RESULT`, the content builder, the settings group (enable,
  duration, sound, scale, preview), position in the profile, test-mode placement. Tests, docs, smoke rows.
- [ ] **D5 Review and fixes** across the batch.

### P8: Finalize (only on the owner's go-ahead)

- [ ] LibKa0s: merge the Toast branch after the other session's release work, tag, push; the owner re-vendors
  all of LibKa0s (drop the deviation row then). DpsRace: merge, push, close #5, #16, #17. Delete this run's
  branches and the worktree.
