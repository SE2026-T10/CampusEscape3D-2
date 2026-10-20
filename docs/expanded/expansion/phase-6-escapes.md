# Expanded Library expansion — Phase 6: escape routes and checkpoint reliability

**Date:** 2026-10-16 · **Branch:** `Development` (at `7d73492`; Phases 1–6 uncommitted in the working tree) · **Engine:** Godot 4.7.2 stable · **Layout:** x5

**Owner decisions (asked before building):**
- the three routes as proposed:
  - A: main entrance with a lockdown, the security master badge and the lobby badge reader;
  - B: loading dock with the tool-kit shutter release, SERVICE power and the shutter control;
  - C: the storm drain becomes the hidden maintenance passage, behind a disguised panel found through a clue;
- walk-through exit triggers (Expanded Library only);
- guard positions in the checkpoint snapshot (Expanded Library only), with a guard near or in sight of the respawn point going to its start.

## 1. Summary

**Three escape routes**, all in the existing map, reusing its doors and passages. Only one is needed, and every one requires the rare manuscript. Each exit opens when its own conditions hold; the player escapes by walking into a trigger just past the door. Without the manuscript the trigger refuses ("You can't leave without the rare manuscript.").
- **A · Main entrance** (direct but exposed):
  - Once you are inside, a lockdown panel closes the entrance; the enter_library message says so.
  - The security master badge (new; in the Office 1 security locker, code 136) and a 4 s override at the new lobby badge reader open it. Walking away or being caught interrupts the override.
  - The reader beeps and the bolts bang (noises guards hear), and a new fixed camera looks down at the reader.
- **B · Loading dock:**
  - SERVICE EXIT power;
  - the new shutter release, freed with the tool kit;
  - OPEN on the new shutter control.
- **C · Hidden maintenance passage:**
  - A false wall panel in the tunnel's existing north gap, opposite the pump room door. It has no prompt and looks like the wall until the new culvert access plan (maintenance bay) is read; then its hidden latch opens it.
  - The Phase 4 pump clears the storm drain grate.

**Completion records the route** (`ObjectiveManager.escape_route`): the win screen shows "Escape route: Main entrance / Loading dock / Hidden maintenance passage".

**Checkpoints:**
- The existing snapshot (position and facing, objectives, inventory, puzzles, circuits, doors) now also covers the exits and, in the Expanded Library, each guard's position, facing and patrol point (restored on PATROL with detection 0).
- On capture:
  - the caught screen shows (2.5 s, naming the checkpoint) and the player respawns;
  - the snapshot is restored, stamina is full and detection reset;
  - the HUD follows;
  - the journal is kept.

Full specification: [`phase-6/escape_specs.md`](phase-6/escape_specs.md).

## 2. Exact files changed

**Modified (21):**
- `scenes/level/expanded_library.tscn`, only by scripts:
  - `escape_x5.py`: `checkpoint_snapshot = true` on the 7 guards; the dock ExitDoor's walk-through properties;
  - `mission_x3.py` (updated): the enter_library, take_manuscript and escape texts.
- `scenes/level/expanded_library_expansion.tscn`: rebuilt (x5) with ids preserved. New: `Gameplay/Escape` (main entrance exit with its panel and trigger, badge reader, dock release, shutter control, dock trigger), `MaintenancePanel`, `LockerBadge`, `CulvertAccessPlan`, `CameraLobby`, the drain trigger.
- `scripts/systems/objectives/exit_door.gd`: walk-through mode (opt-in exports: trigger, panel, `unlock()`, armed-after objective, route id and name, checkpoint state). The default (E escapes) is unchanged, so the tutorial's exit behaves as before.
- `scripts/systems/objectives/access_door.gd`: hidden doors (`hidden_until_document`) and keyless latch doors.
- `scripts/npc/guard.gd`: `checkpoint_snapshot`, `respawn_clearance`, `get_checkpoint_snapshot()`, `restore_checkpoint_snapshot()`.
- `scripts/systems/checkpoints/checkpoint_manager.gd`: stores and restores guard snapshots.
- `scripts/systems/objectives/objective_manager.gd`: `escape_route` and `record_escape_route()`.
- `scripts/ui/game_menus.gd`: the escape route line on the win screen.
- `scripts/systems/inventory/item_catalog.gd`: `security_badge`.
- `tools/expanded/expansion/expansion_layout.gd`: x5; `ESCAPES`, the panel, the badge, the plan, the lobby camera, texts.
- `tools/expanded/expansion/build_expansion.gd`: `_add_escapes`, `_add_trigger`, door heights and hidden doors, camera overrides.
- `tools/expanded/expansion/mission_x3.py`: texts.
- Tests:
  - `tests/test_scene.gd`: registers the new suite;
  - `tests/expanded_puzzle_tests.gd`: routes 1–2 now use the shutter and the hidden panel and walk out;
  - `tests/expanded_security_tests.gd`: 5 cameras; the dock is walked out;
  - `tests/expanded_mission_tests.gd`: the dock keeps E-to-escape there, documented;
  - `tests/expanded_layout_expansion_tests.gd`: the walk opens the hidden panel, documented.
- Docs: `README.md`, `docs/expanded/LEVEL_LOG.md`, `docs/expanded/LAYOUT.md`, `docs/qa/REGRESSION_CHECKLIST.md`.

**New:**
- `scripts/systems/escape/badge_reader.gd`, `dock_shutter.gd` (+ `.uid`);
- `tests/expanded_escape_tests.gd` (+ `.uid`);
- `tools/expanded/expansion/escape_x5.py`, `capture_escapes.gd` (+ `.uid`);
- this report;
- `phase-6/`: `escape_specs.md`, `screens/` (14), `contact_escapes.png`, `logs/`, `mutation_checks.txt`, `guard_timing_flake.txt`.

**Not changed:** the tutorial scene, the guard scene and AI states, the navmesh, geometry, every guard's placement and route.

## 3. Existing systems reused

| Need | Reused |
|---|---|
| Exits | `ExitDoor` (walk-through is an opt-in mode); the existing dock door panel and entrance opening |
| Hidden passage | `AccessDoor` (a hidden, keyless mode); the existing tunnel gap, drain, grate and Phase 4 pump |
| Credential | `ItemCatalog` / `ItemPickup` / `PlayerInventory`; the Phase 4 security locker's reveal list |
| Tool mechanism | `ToolMechanism` (the dock release) |
| Electrical state | Phase 5 `PowerNetwork` (SERVICE EXIT) and its switch |
| Dock control | `Puzzle` / `PuzzleControl` |
| Exposure | Phase 5 `SecurityCamera` and alarm; NoiseSystem noises |
| Clue | `DocumentPickup` and the journal |
| Checkpoints | `CheckpointManager` (`checkpoint_state` group, `respawned`), `StealthDirector` capture and reset, the existing caught screen, `Player.respawn()` (facing, stamina refill) |

## 4. Acceptance criteria

| Criterion | Result | Evidence |
|---|---|---|
| All three escape routes work independently | **PASS** | escape A, B, C: each on a fresh level to the WIN state, using only its own prerequisites |
| Every route rejects completion without the mission item | **PASS** | each route opened without the manuscript, then walked through: refused with the message, no escape (A, B, C); mutation M1 caught |
| Each route has unique prerequisites | **PASS** | after every set-up step, the other two exits are checked closed (D); the badge, shutter and hidden-panel checks are each proven by a mutation (M2, M3, M4) |
| Respawn creates no duplicate items or inconsistent objectives | **PASS** | escape E: item totals unchanged over 5 captures; objectives, keypad, manuscript, puzzles and exits as stored; the puzzle suite's consistency checks |
| Guard and checkpoint states restore correctly | **PASS** | escape F: 7 of 7 guards at their stored position, facing and patrol point on PATROL with detection 0 (one was investigating at the checkpoint); the clearance rule refuses a spot near the respawn; M5 and M6 caught |
| No mandatory progression can be permanently softlocked | **PASS** | nothing consumed; the journal kept; switches reversible (SERVICE off/on closes/reopens the dock); after 5 captures the mission still ends through a route (E) |
| Completion records the route used | **PASS** | each route: `escape_route` plus the win-screen line; M7 caught |
| Capture flow: brief screen, respawn, restore, full stamina, detection reset, HUD | **PASS** | E: caught screen "CAUGHT · Back to Study Rooms…" for 2.5 s; position and facing; stamina full; status NONE; HUD header matches |
| No tutorial regression | **PASS (behaviour)**, with one known flaky test check | §5 and §8 |

## 5. Tests actually run (Linux VM, Godot 4.7.2 official)

| Run | Result |
|---|---|
| `tools/ci/validate.sh` | `CHECK SCRIPTS PASSED (125 scripts)` · `VALIDATION PASSED` |
| `tools/ci/run_tests.sh`, final | **Suite FAILED with 3 checks, all the known tutorial `guard_tests` first-wait timing** ("GuardMain waited 3.20 s at point 1, expected 3.00 s", and 2.20 vs 2.00 s for GuardRestricted and GuardEast). Every other check passed, including all Expanded Library suites and the new escape suite; exactly the 8 expected warnings. 1137 s ([`logs/tests_final.log`](phase-6/logs/tests_final.log)) |
| Earlier full runs | run 1: 28 Phase 6 fallout failures in older tests (fixed, §2); run 2: the same 3 guard-timing checks only |
| `tools/qa_flow.gd`, `tools/map_flow.gd`, run directly (run_tests.sh stops after the suite) | `QA FLOW PASSED (15 checks, 4 levels loaded)`; `MAP FLOW PASSED (52 checks, 12 levels loaded, 3 cycles)`, 0 ERROR/WARNING lines |
| `tools/ci/export_windows.sh` | `EXPORT PASSED: dist/CampusEscape3D-1.1.0-windows-x64.zip` (not run on Windows) |
| Deliberate breaks (7), each running the escape suite | all caught ([`mutation_checks.txt`](phase-6/mutation_checks.txt)): M1 trigger ignores the manuscript (7 failures), M2 reader skips the badge (2), M3 shutter ignores the release (2), M4 hidden panel needs no clue (4), M5 guards not restored (2), M6 exits forget their state (1), M7 route not recorded (8) |

**The guard timing check.** It is the pre-existing flake reported since Phase 3 of this series and in the earlier Phase 4–5 balance reports. The test starts counting before the physics steps queued at the old time scale have run, so how often it fails depends on frame timing. Measured here, `guard_tests` alone, one fresh process per run ([`guard_timing_flake.txt`](phase-6/guard_timing_flake.txt)):

| Build | Failed runs |
|---|---|
| Phase 5 as delivered | 0 of 8 |
| Phase 6 | 8 of 16 |
| Phase 6 with Phase 5's `guard.gd` | 1 of 8 |
| Phase 6 with the proposed one-line **test** fix (await one process frame after setting `Engine.time_scale`; not delivered) | **0 of 8**: every measured wait within the test's 0.15 s tolerance |

**Reading:**
- The guards' waits are correct on the Phase 6 code.
- Phase 6 makes the timing-dependent check fail more often here, probably because the larger `guard.gd` changes frame timing at start-up; it is not a behaviour change, since `checkpoint_snapshot` is off in the tutorial and only adds a group and new methods.
- The fix changes a tutorial test, so it needs your approval. Until then, the CI test job can go red at random.

**Escape suite results** (from `tests_final.log`):
- **A:** lockdown on entering; the reader refuses without the badge; locker 136 → badge; an interrupted override leaves it locked; a 4 s override opens it, and the lobby camera raises an alarm during it; without the manuscript the exit refuses; with it, escaped and the route recorded.
- **B:** the control refuses without power, then with the release jammed; the release refuses without the tool kit; OPEN opens the shutter; SERVICE off/on closes and reopens it; escaped and the route recorded.
- **C:** the panel has no prompt and stays locked until the plan is read; the latch opens it; the grate stays jammed until the pump drains the culvert; escaped and the route recorded.
- **Checkpoints:**
  - before any checkpoint → back on the porch with the entrance open, and the lockdown engages again on re-entering;
  - caught screen 2.5 s; position and facing; full stamina; detection reset;
  - items, objectives, puzzles, circuits, exits and the hidden panel as stored; the override cancelled; journal kept; HUD in sync;
  - 5 captures with item totals unchanged; still escaped afterwards.
- **Guards:** 7 of 7 back at their stored spots on PATROL with detection 0; the investigating guard back on PATROL; the clearance rule.

**Profiler:** not re-measured in this phase. The per-frame additions are small: two badge/shutter scripts, three exit `_process` checks and one fixed camera (Phase 5 measured four cameras at about +0.1–0.3 ms).

## 6. Evidence

Screenshots (xvfb, OpenGL 3, 1600×1000; [`phase-6/screens/`](phase-6/screens/), sheet [`contact_escapes.png`](phase-6/contact_escapes.png)):

| Shot | Shows |
|---|---|
| e01 | the lockdown sign seen from the lobby |
| e02 | the reader refusing without the badge |
| e03 | the lockdown lifted |
| e04 | the entrance open: "Main entrance: open (the rare manuscript first)", and the lobby camera's alarm |
| e05 | the win screen: "Escape route: Main entrance" |
| e06 | the dock shutter down |
| e07 | the release freed |
| e08 | the shutter open |
| e09 | the win screen: "Escape route: Loading dock" |
| e10 | the hidden panel, looking like the wall |
| e11 | the culvert access plan in the journal |
| e12 | the panel found (green, latch prompt) |
| e13 | the passage open with the grate still jammed |
| e14 | the caught screen "CAUGHT · Back to Study Rooms…" |

## 7. Known limitations and risks

- **Not human-playtested.** The 4 s override with the camera on the reader and the hidden-panel discovery were judged from tests and screenshots only.
- **Lobby camera:** a full override with SURVEILLANCE on always raises an alarm (by design: "exposed"). Turning the cameras off first avoids it.
- **Guard snapshot:** a guard that was investigating at the checkpoint resumes its patrol from that spot instead of continuing the search (documented). In the measured run no guard needed the clearance fallback; the rule is tested directly.
- **The dock in `expanded_mission_tests`** keeps its old E-to-escape mode (documented in the test), so those tests keep covering doors and objective order. The walk-through dock is covered by the escape, puzzle and security suites.
- **`tools/expanded/playtest_bot.gd`** (a balance tool, not in CI) still follows the pre-Phase-4 mission. It has been outdated since Phase 4.
- **Tutorial guard-timing flake:** see §5; the fix needs your approval.
- **Debug label:** in debug builds a guard's debug label shows above it (visible in e14). This is existing behaviour.
- **Windows export:** built on Linux only.

## 8. Tutorial regression

The tutorial scene is unchanged. Its ExitDoor keeps E-to-escape (walk-through is off by default), and its guards keep `checkpoint_snapshot = false` (tested). Every tutorial suite passes except the known timing check (§5), which passes 8 of 8 runs with the proposed test fix. QA flow and map flow pass.

## 9. Git

Branch `Development`, at `7d73492`. Phases 1–6 are uncommitted in the working tree, delivered to `D:\gitclone\CampusEscape3D-2` for you to review, commit and push. Nothing was committed or pushed to your repository.

## 10. Recommendation

**PASS**, on the condition that you accept the pre-existing guard-timing flake (§5). I recommend approving its one-line test fix before Phase 7. Stop for approval before Phase 7.
