# Expanded Library expansion — Phase 8: end-to-end testing

**Date:** 2026-10-17 · **Branch:** `Development` (at `7d73492`; Phases 1–8 uncommitted in the working tree) · **Engine:** Godot 4.7.2 stable · **Layout:** x6 (unchanged)

**Owner decisions (asked before starting):**
- **Playtime:** an automated run with the level's guards, reported as bot time, plus one human run timed by the owner with the win-screen timer.
- **Off target:** report the gap and propose tuning; no design change in this phase.

## 1. Summary

**Two new tools.**
- **An end-to-end suite** (`tests/expanded_e2e_tests.gd`, in CI). It plays the map from the porch to a successful escape, walked with real input by `tests/e2e_walker.gd`: the move keys along a navigation path, E on what the interactor focuses, F to throw, 1–3 for slots, no teleporting during a run. It has five sections, A–E (§5).
- **The playtest bot**, updated (`tools/expanded/playtest_bot.gd`, not in CI). It plays with the level's seven guards, through the real player, for playtime. Its plans now follow the current mission: four route scripts (dock, main, passage, full), steps skipped when already done (so it resumes after a capture), and E on closed doors.
  - After two captures near the same spot it detours through other stairs and rooms; a door that refused it is a hard obstacle.
  - After every capture it checks the objectives and mission state against the checkpoint.

**One critical bug, found and fixed.** With an exit open but no manuscript, walking into the exit showed "You can't leave without the rare manuscript." and nothing stopped the player.
- This applied to the dock with the shutter up, the main entrance after the override, and the drain once cleared and its panel opened.
- Past the dock door there is no floor, so the player fell out of the level and silently respawned at the last checkpoint, losing everything since.
- **Fix** (`scripts/systems/objectives/exit_door.gd`): every walk-through exit creates an invisible wall at its threshold, 0.1 m inside the trigger's near side. It is solid only while the way is open but leaving would be refused.
  - The player still touches the trigger (and gets the message) but stays on the floor.
  - Before the lockdown the main entrance's wall is off, since it is the way in.
  - No scene change.
- **Tested** on all three exits by the suite (the player must stay at the threshold, with no respawn). Removing the wall makes the suite fail (mutation M0).

**Balance findings, proposed and not changed** (§7): one capture hotspot between the Staff Offices checkpoint and the main stair, and no checkpoint along the basement and electrical-room route.

## 2. Exact files changed

**New:**
- `tests/expanded_e2e_tests.gd` and `tests/e2e_walker.gd` (+ `.uid` files).
- `docs/expanded/expansion/phase-8-e2e.md` (this report).
- `docs/expanded/expansion/phase-8/`:
  - `playtests/runs.jsonl`, `playtests/summary.md`, `playtests/trial_main_seed1.txt`;
  - `mutation_checks.txt`;
  - `logs/` (validate, tests_final, qa_flow, map_flow, export, e2e_alone).

**Modified:**
- `scripts/systems/objectives/exit_door.gd`: the refusal wall (the fix).
- `tools/expanded/playtest_bot.gd`: rewritten planning for the current mission (perception and stealth movement unchanged).
- `tests/test_scene.gd`: registers the suite; the pass line adds "Expanded Library expansion end to end".
- `README.md`, `docs/expanded/LEVEL_LOG.md`, `docs/qa/REGRESSION_CHECKLIST.md`.
- `docs/expanded/PLAYTEST_PROTOCOL.md`: the form updated for the current mission (eight objectives, three routes, journal, captions).

No scene, asset, guard, route or objective changed.

## 3. Existing systems reused

- **Player and game:** the real player and its PlayerInteractor and PlayerInventory (E, F, 1–3), NavigationServer paths, ObjectiveManager, CheckpointManager, StealthDirector.
- **Level content:** the level's guards and their state machine, every Phase 3–7 mechanism.
- **Tools and tests:** the Phase 5 playtest bot's perception and stealth movement, `tests/test_utils.gd`. No new game system.

## 4. Acceptance criteria

| Criterion | Result | Evidence |
|---|---|---|
| Every escape route succeeds when its requirements are met | **PASS** | Suite A (dock), B (main entrance), C (hidden passage), each walked from the porch to the win screen. With guards, the bot escaped by the main entrance 5 times. Dock and passage were not completed by the bot within 45 min (§5); those failures are repeated captures, not a blocked route |
| All exits reject attempts without the mission item | **PASS (after the fix)** | Suite A, B, C: each exit, once open, refuses with the message and the player stays at its threshold. Before the fix the player fell out of the level (§1) |
| No critical softlocks or unreachable objectives remain | **PASS** | Every objective completed in A–C. The tour reached all 40 areas and stair ends. One-way doors and the card door can always be bypassed back the way you came. Bot runs that did not finish all stopped on repeated captures, never on an unreachable step |
| Checkpoints, inventory and objectives remain consistent | **PASS** | Bot: 218 captures, 218 checks, **0** violations. Suite B: a capture restores objectives and all 28 mission-state entries exactly, keeps the journal, and the undone pump can be redone |
| Navigation and backtracking work | **PASS** | Suite A tour, with the manuscript carried: every area of all 7 zones, all 5 stairs walked end to end, 4 doors opened on the way; back to the dock |
| The tutorial remains playable | **PASS** | Suite E (replayed after the Expanded Library runs, walked to its win); all tutorial suites, QA flow and map flow pass |
| The first successful run is measured against the 20–30 min target | **MEASURED (bot); human run pending** | First successful run: **11:22** game time (bot, main route). Completed bot runs: 11:22–44:14. Not a human first-timer's time (§5); the owner's timed run is pending |

## 5. Tests actually run (Linux VM, Godot 4.7.2 official)

| Run | Result |
|---|---|
| `tools/ci/validate.sh` | `CHECK SCRIPTS PASSED (133 scripts)` · `VALIDATION PASSED` |
| `tools/ci/run_tests.sh` | **All tests passed**, including the new suite and the tutorial `guard_tests` (the known timing flake did not fire in this run); exactly the 8 expected warnings; 0 script errors. 1552 s for validate + tests + QA + map flow ([`logs/tests_final.log`](phase-8/logs/tests_final.log)) |
| `tools/qa_flow.gd`, `tools/map_flow.gd` | `QA FLOW PASSED (15 checks, 4 levels loaded)`; `MAP FLOW PASSED (52 checks, 12 levels loaded, 3 cycles)` |
| `tools/ci/export_windows.sh` | `EXPORT PASSED: dist/CampusEscape3D-1.1.0-windows-x64.zip` (not run on Windows) |
| End-to-end suite alone | 0 failures, 340 s real time (before the back-gate check was added; that version then ran in the full suite) |
| Deliberate breaks (6), each running the suite ([`mutation_checks.txt`](phase-8/mutation_checks.txt)) | M0 refusal wall removed (6 failures); M1 exits let you out without the manuscript (11); M2 one-way doors open both ways: **not caught at first**, so the wrong-side check was added and it is now caught (2); M3 captures lose the journal (1); M4 guards ignore new noises while investigating (1); M5 the pump never clears the grate (4) |

**Scenario coverage.**

| # | Scenario | Where |
|---|---|---|
| 1 | Complete each of the three escape routes | Suite A, B, C; bot (main) |
| 2 | Attempt every exit without the mission item | Suite A (dock), B (main entrance), C (storm drain); also `expanded_escape_tests` |
| 3 | Solve puzzles in supported orders | A: card → tool kit → power → dock. B: rota/locker → override → pump → power. C: tool kit → circuits → pump → passage → card. Bot dock: tool kit and power before the card |
| 4 | Incorrect puzzle answers and recover | A: wrong breakers (trip, alarm, back to OFF) then right; wrong vault code then right. Also `expanded_puzzle_tests` (lockout, pump stall) |
| 5 | Circuit states in different orders | C, with the real switches: SURVEILLANCE off → SERVICE on (reboot, lock) → refused while locked → SERVICE off → breakers → unlocked again. A: breakers → SERVICE. Also `expanded_security_tests` (all 8 combinations) |
| 6 | Distractions during PATROL, INVESTIGATE and CHASE | D, thrown with F: PATROL → investigates the landing; INVESTIGATE → the search moves to the new landing; CHASE → ignored (as designed), still chasing the player |
| 7 | Documents, capture, journal persistence | B: 7 entries before, 7 after; bot: journal untouched by 218 restores |
| 8 | Checkpoint inventory and objective restoration | B: exact restore (tool kit and pump undone because they came after the checkpoint, then redone); bot: 0 violations |
| 9 | All zones, stairs, passages and shortcuts | A: the tour. B: the back gate shortcut down the staff stair. C: the east service stair, hidden panel and storm drain. A: back gate refused from the staff stair |
| 10 | Mandatory-only run | A: 0 of 3 optional until the manuscript |
| 11 | Optional objectives and their effects | B: locker (badge, bottle, patrol notes revealed; the badge opens the main entrance), pump (grate cleared, drain open), back gate (shortcut to storage) |
| 12 | Replay the original tutorial | E |

**Playtime.**

Without guards (the suite, walking only; a lower bound for the distances):

| Run | Game time | Walked |
|---|---|---|
| A, mandatory to the manuscript | 198 s | 609 m |
| B, everything optional | 312 s | 962 m |
| C, passage | 261 s | 752 m |
| E, tutorial | 35 s | 113 m |

With the level's guards (the bot; careful profile, game time; [`playtests/summary.md`](phase-8/playtests/summary.md)):
- **First successful run: main route, seed 1: 11:22**, 4 captures (trial run before the batch).
- **Batch** (13 runs):
  - main: 13:35 (3 captures), 40:21 (30), 44:14 (25);
  - full: 33:24 (13 captures);
  - not completed within the 45 min cap or 8 min without progress: dock ×2, passage ×3, full ×1;
  - 2 dock runs excluded (bot build before its locked-door fix).
- The bot knows the map, the codes and the order, and spends no time reading. A first-time player explores and reads, so they need more time than its walking, and probably handles guards better than it does, so they may need fewer captures.
- **So the bot's 11:22 does not tell whether people land in 20–30 min.** It only shows that a run below 20 min is possible for someone who knows the level. Most bot time went into captures (up to 35 per run), not walking.

**Manual tests by a person:** none were run (I cannot play). Your timed run with `docs/expanded/PLAYTEST_PROTOCOL.md` is the human data point; please send the win-screen time and captures.

## 6. Evidence

- **Suite output:** the `[expanded-e2e]` lines in [`logs/tests_final.log`](phase-8/logs/tests_final.log).
- **Bot runs:** every run in [`playtests/runs.jsonl`](phase-8/playtests/runs.jsonl), one JSON line each: route, seed, time, every capture with place and guard, state checks, events.
- **Summary table:** [`playtests/summary.md`](phase-8/playtests/summary.md).
- **Breaks:** [`mutation_checks.txt`](phase-8/mutation_checks.txt).
- **No new screenshots.** Nothing visible changed (the wall is invisible); the logs are the evidence.

## 7. Known limitations, risks and proposals (not applied)

**Capture clusters** (bot, 218 captures in valid runs):

| Place | Guard | Captures |
|---|---|---|
| Staff balcony and the top of the main stair (around (0, 4.5, 0) and (−10, 4, 10)) | GuardConnector | 57 (+13 nearby) |
| Staff corridor by the archive's front gate (5…10, 4.5, −10) | GuardArchive | 33 |
| Basement tunnel west (−15, −4, −25) and east basement (40, −4, −20) | GuardBasement | 30 |

**P1 · Staff Offices checkpoint into the connector's patrol.** After taking the card the player respawns in the Staff Offices. The next mandatory leg (down to the tool kit or the electrical room) crosses the corridor and balcony where GuardConnector and GuardArchive overlap. The bot was caught there up to 28 times in one run, and its detour search found no way out of the offices that avoids that corridor. Options for your choice:
- (a) a hiding spot or low cover on the staff balcony;
- (b) shorten or shift GuardConnector's loop off the balcony's west half;
- (c) move the Staff Offices checkpoint pad toward the stacks staff door, so the respawn faces another way out.

**P2 · No checkpoint on the basement and electrical-room side.** A player who goes for the tool kit and the electrical room first passes no checkpoint pad until Storage. Every capture by GuardBasement in the tunnel sends them back to the porch and undoes the tool kit, panel and breakers (bot dock runs: 11–14 captures, never past the card). Proposal: a checkpoint pad in the maintenance bay or the electrical room.

**P3 · Basement tunnel.** The west cluster sits at the existing low crate (TunnelCrateWest, around (−14, −4, −26)). Low cover hides only a crouched player, and GuardBasement walks the same 4 m-wide tunnel past it, so the bot was caught beside it. Proposal: a real hiding spot (a niche or locker) in the tunnel wall near that crate, as the maintenance bay and cable bay have.

**Other limitations:**
- **The bot is weaker than a person** at timing guards; its completion rate is not a difficulty measure by itself.
- **The suite runs without the level's guards** (deterministic); guards are covered by the bot and by the earlier suites.
- **CI time:** validate plus the suite took 1552 s.
  - `run_tests.sh` gives the suite 1800 s, so the margin is now about 5 minutes.
  - The Phase 5 `build.yml` timeout change (40 → 55 min) is still not applied; `.github/` is write-protected on your computer. With the new suite the job may exceed 40 minutes, so please apply it by hand.
  - I recommend also raising `run_tests.sh`'s suite timeout from 1800 to 2400 s. Not done, as it is outside this phase's agreed scope.
- **Tutorial guard-timing flake:** it did not fire in this phase's full run; the one-line test fix (Phase 6 report) still awaits your approval.
- **Windows export:** built on Linux only.

## 8. Tutorial regression

The tutorial scene and its scripts are unchanged by this phase. Its exit is not walk-through, so it gets no refusal wall. Suite E replays it to its win after the Expanded Library runs. All tutorial suites, QA flow and map flow pass.

## 9. Git

Branch `Development`, at `7d73492`. Phases 1–8 are uncommitted in the working tree, delivered to `D:\gitclone\CampusEscape3D-2` for you to review, commit and push. Nothing was committed or pushed to your repository.

## 10. Recommendation

**PASS.** Every criterion passes in automated tests after the critical exit fix. The playtime target is measured with the bot: first run 11:22, not comparable to a first-time human. Your timed run is still needed to judge 20–30 minutes.

Please decide on P1–P3 (or defer them to a later phase) and on the CI timeouts. Stop for approval before Phase 9.
