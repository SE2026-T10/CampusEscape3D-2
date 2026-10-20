# Expanded Library expansion — Phase 5: security systems

**Date:** 2026-10-16 · **Branch:** `Development` (at `7d73492`; Phases 1–5 uncommitted in the working tree) · **Engine:** Godot 4.7.2 stable · **Layout:** x4

**Owner decisions (asked before building):**
- the circuits as proposed: ARCHIVE ACCESS (the Phase 4 breakers, vault keypad only), SURVEILLANCE (starts ON, 4 cameras), SERVICE EXIT (starts OFF, loading dock shutter only); SERVICE ON reboots the cameras and locks the surveillance switch for 30 s; cameras raise an alarm, never an instant fail; the dock needs SERVICE power, the storm drain stays the alternative; no switch is one-way;
- the new hiding and search rules for the **Expanded Library only** (tutorial guards unchanged);
- **one basement guard** (service tunnel, pump room side, east basement up to the electrical room stair).

## 1. Summary

**Guards** keep PATROL / INVESTIGATE / CHASE. A new off-by-default flag on the shared guard, `expanded_security`, is on for the Expanded Library's seven guards:
- **hiding** hides a crouched player only if they got in while no guard saw them or chased them; a guard right at the spot (1.6 m) finds them;
- **searching** (INVESTIGATE) first checks the nearest hiding spot within 7 m of the searched place, then searches as before;
- **alarms**: while the alarm sounds, detection ×1.6 and searches ×1.5.

Distractions, noises, alarms and switch clunks all reach guards through the existing NoiseSystem → hearing → INVESTIGATE path; losing the player still means a search at the last known position, then patrol.

**Cameras** (4: staff corridor, archive hall, loading dock, service tunnel) sweep and fill a meter (slower crouched or far away). At full they raise the existing `SecurityAlarm` at the player's position: an "ALARM: Camera (…) spotted you" banner, and guards nearby investigate. Never a capture. Without power: a dark lens, no cone, no effect on guards.

**Circuits** (the existing `PowerNetwork`, now three circuits) each power only their own devices. Two new switches sit in the electrical room beside the breaker panel. SERVICE EXIT ON gives the dock shutter power but reboots the cameras (surveillance switch locked 30 s, with a countdown and a message). Every switch use gives a HUD message and a clunk guards can hear; circuits follow checkpoints.

**Escapes:**
- the **loading dock** needs the manuscript **and** SERVICE EXIT power (it says which is missing, manuscript first);
- the **storm drain** never needs power;
- the **main entrance** stays reserved (unchanged).

**Basement guard:** GuardBasement patrols the service tunnel from its west end past the pump room to the east basement at the foot of the electrical room stair (5 points).

Full specification: [`phase-5/security_specs.md`](phase-5/security_specs.md).

## 2. Exact files changed

**Modified (27, of which 26 delivered):**
- `scenes/level/expanded_library.tscn`: by `security_x4.py` only:
  - `expanded_security = true` on the 6 existing guards;
  - the new `Guards/P9_Basement` (5 points) and `Guards/GuardBasement` (copied from GuardLobby's blocks, new unique ids);
  - `power_circuit`, `no_power_reason`, `no_power_sign` on the loading dock ExitDoor.
- `scenes/level/expanded_library_expansion.tscn`: rebuilt (layout x4) with ids preserved (`keep_ids.py`):
  - the keypad's circuit renamed `archive_vault` → `archive_access`;
  - new `Gameplay/Security` (2 switches, a label, 4 cameras).
- `scripts/npc/guard.gd`: the "Expanded security" export group and `is_alarm_attentive()`, `get_search_duration()`, `find_hiding_spot_to_check()`.
- `scripts/npc/ai/investigate_state.gd`: checks a hiding spot before searching; the alarm search duration.
- `scripts/npc/guard_vision.gd`: concealment (expanded guards only) and the alarm detection multiplier.
- `scripts/systems/hiding_spot.gd`: `entered_unseen`, `is_concealing()`, `conceals_from()`.
- `scripts/systems/objectives/exit_door.gd`: optional `power_circuit`; the rejection message order is manuscript first, then power.
- `scripts/systems/puzzles/power_network.gd`: three circuits.
- `scripts/systems/puzzles/breaker_panel.gd`: circuit name.
- `scripts/systems/puzzles/security_alarm.gd`: docs.
- `scripts/ui/objective_hud.gd`: the "ALARM: reason" message.
- `tools/expanded/expansion/expansion_layout.gd`: x4, `SECURITY`.
- `tools/expanded/expansion/build_expansion.gd`: `_add_security`.
- `tools/benchmark.gd`: the Expanded Library's "normal" scenario is its own 7 guards (was 6, which removed GuardBasement).
- `tools/ci/run_tests.sh`: suite timeout 1200 → 1800 s (the suite now takes about 17 min here).
- `.github/workflows/build.yml`: validate-and-test job timeout 40 → 55 min. **Not delivered:** the local folder's `.github/` is write-protected for remote tools. The owner applies it by hand (line 39: `timeout-minutes: 40` → `55`) or leaves it: 40 min still fits the measured run here (suite about 17 min).
- Tests:
  - `tests/test_scene.gd`: registers the new suite;
  - `tests/expanded_ai_tests.gd`: 7 guards;
  - `tests/expanded_baseline_tests.gd`: digests checked with the two new nodes left out, plus checks of the additions;
  - `tests/expanded_graybox_tests.gd`: 7 tuned guards;
  - `tests/expanded_mission_tests.gd`: the dock's power requirement taken out there, documented; it is covered elsewhere;
  - `tests/expanded_puzzle_tests.gd`: route 1 switches SERVICE EXIT on with real input;
  - `tests/performance_tests.gd`: the benchmark scenario count.
- Docs: `README.md`, `docs/expanded/LEVEL_LOG.md`, `docs/expanded/LAYOUT.md`, `docs/qa/REGRESSION_CHECKLIST.md`.

**New:**
- `scripts/systems/security/security_camera.gd` and `circuit_switch.gd` (+ `.uid`);
- `tests/expanded_security_tests.gd` (+ `.uid`);
- `tools/expanded/expansion/security_x4.py`;
- `tools/expanded/expansion/capture_security.gd` (+ `.uid`);
- `docs/expanded/expansion/phase-5-security.md` (this report) and `docs/expanded/expansion/phase-5/`:
  - `security_specs.md`, `contact_security.png`, `screens/` (10);
  - `profiler/` (9 benchmark summaries), `logs/`, `mutation_checks.txt`.

**Not changed:** the tutorial scene, the guard scene, the guard state machine and states other than INVESTIGATE's search target, the navmesh, geometry, every existing guard's placement and route.

## 3. Existing systems reused

| Need | Reused |
|---|---|
| Guard behaviour | the existing Guard, GuardStateMachine and its three states, GuardVision, GuardHearing; one flag gates every new rule |
| Reacting to sounds, distractions, alarms, switches | NoiseSystem → GuardHearing → INVESTIGATE (unchanged) |
| Alarm | Phase 4 `SecurityAlarm` (`raise_alarm`), now also raised by cameras |
| Power | Phase 4 `PowerNetwork` (more circuits, same API, already in checkpoints) |
| Switches | Phase 4 `PuzzleControl` (an Interactable: prompt, E, visual); feedback through ObjectiveHud's puzzle path |
| Hiding | the existing `HidingSpot` areas (no new ones) |
| Exits | the existing `ExitDoor` (an optional power requirement) |
| Checkpoints | `checkpoint_state` group and `CheckpointManager.respawned` |
| Guard model and tuning | GuardLobby's scene blocks, copied for GuardBasement |

## 4. Acceptance criteria

| Criterion | Result | Evidence |
|---|---|---|
| Existing guard states still work | **PASS** | security B (noise → INVESTIGATE → PATROL; sight → CHASE → lost → INVESTIGATE at the last known position → PATROL); the existing guard, AI, hearing, vision, loop and expanded-ai suites all pass |
| Guards respond to suspicious sounds and environmental changes | **PASS** | security B, E (alarm investigated), C (distraction); a switch clunk is a NoiseSystem "environment" noise (G) |
| Distractions attract guards to the source | **PASS** | security C: thrown bottle → the guard walked to 1.2 m of the landing spot, searched, back to PATROL |
| Lost player → search last known location → patrol | **PASS** | security B; expanded-ai E and F |
| Hiding breaks detection only if entered unseen; guards may check nearby spots | **PASS** | security D: unseen + crouched → not seen (a default guard still sees); seen going in → seen; a guard searching near the spot checks it and finds the player |
| Three circuits; each affects only its devices | **PASS** | security G: all 8 combinations; each switch changes only its circuit (SERVICE ON → surveillance reboot by design) |
| Cameras controlled by switches; disabling cameras doesn't disable guards | **PASS** | security F: OFF → 4 dark, no meter; a guard still detects |
| Alarms raise attention, no instant failure | **PASS** | security E (×1.60 detection, ×1.5 searches), F (no capture) |
| Restoring service power may reactivate cameras | **PASS** | security H (reboot, 30 s lock, then switchable) |
| Clear power feedback | **PASS** | HUD messages tested (switch, reboot, lock countdown, dock); screenshots s03, s06–s11 |
| No switch combination softlocks mandatory progression | **PASS** | security H: from all 8 combinations one press opens the dock; the storm drain power-free; every switch reversible; mutation M6 caught |
| Guards navigate the expanded map and stairs | **PASS** | expanded-ai: 7 guards complete their loops (GuardBasement y −4.0); security J: chase up the east service stair and back down; the existing stair, tour and layout guard tests pass |
| Power trade-offs understandable and recoverable | **PASS** (automated) / manual playtest pending | messages, sign, switch labels; reboot recoverable after 30 s; circuits follow checkpoints. Not human-playtested |
| No tutorial AI regressions | **PASS** | the tutorial's guards keep `expanded_security = false` (tested); all tutorial suites and QA/map flows pass |
| AI test results and profiler evidence | **PASS** | §5 |

## 5. Tests actually run (Linux VM, Godot 4.7.2 official, Xeon 2.8 GHz)

| Run | Result |
|---|---|
| `tools/ci/validate.sh` | `CHECK SCRIPTS PASSED (121 scripts)` · `VALIDATION PASSED` ([`logs/validate.log`](phase-5/logs/validate.log)) |
| `tools/ci/run_tests.sh` | `All tests passed (… Expanded Library expansion puzzles, Expanded Library expansion security, Expanded Library expansion baseline).`; exactly the 8 expected warnings; `QA FLOW PASSED (15 checks, 4 levels loaded)`; `MAP FLOW PASSED (52 checks, 12 levels loaded, 3 cycles)`; `TESTS PASSED` in 1096 s ([`logs/tests_final.log`](phase-5/logs/tests_final.log), [`logs/run_tests_console.log`](phase-5/logs/run_tests_console.log)) |
| `tools/ci/export_windows.sh` | `EXPORT PASSED: dist/CampusEscape3D-1.1.0-windows-x64.zip` ([`logs/export.log`](phase-5/logs/export.log)). Not run on Windows |
| Earlier full runs | one before the perf-test fix: only `[performance] Benchmark scenarios (Expanded Library) should be 6, 12 and 24` failed (fixed); one before message changes: all passed |
| Deliberate breaks (6), each running the security suite | all 6 caught ([`mutation_checks.txt`](phase-5/mutation_checks.txt)): M1 hiding never conceals (3 failures), M2 no reboot (8), M3 dock ignores power (9), M4 guards never check spots (2), M5 camera raises no alarm (4), M6 surveillance switch cuts service (5) |

**AI test results** (from `tests_final.log`):
- **patrols:** 7 guards completed their loops in order in 207 s game time, 0 stuck, all stayed in PATROL, spawn and checkpoint respawn points never seen; GuardBasement 5 points, y −4.0;
- **states:** noise → INVESTIGATE → PATROL; sight → CHASE → lost → INVESTIGATE at the last known position → PATROL;
- **distraction:** the guard walked to 1.2 m of the landing spot, searched, returned to PATROL;
- **hiding:** unseen + crouched → hidden from an expanded guard (a default guard still sees); seen going in → not hidden; a search near the spot checks it and finds the player;
- **alarm:** meter ×1.60 (10.4 → 16.6 in 0.5 s), searches ×1.5, investigated within its radius, no capture;
- **cameras:** meter in 0.5 s: 24.9 standing at 6 m, 12.4 crouched, 12.4 at 11.5 m; full → alarm at the player in 2.0 s; off → dark, guards unaffected;
- **stairs:** chase up the east service stair to the electrical room, search, walk back down;
- **basement loop:** 181 s game time, 0 stuck.

**Profiler evidence** (`tools/benchmark.gd`, headless `--fixed-fps 60`: CPU cost per game frame without rendering; Expanded Library; 30 s measured after 5 s warm-up; camera loop and scripted noises; "before" = the delivered Phase 4 tree, "after" = this phase). Summaries in [`phase-5/profiler/`](phase-5/profiler/).

| Run | Guards | Frame ms mean | p95 | p99 | Guard AI ms mean | Stuck | Caught |
|---|---|---|---|---|---|---|---|
| before normal r1 / r2 | 6 | 1.444 / 1.508 | 2.06 / 2.14 | 2.98 / 3.07 | 0.164 / 0.170 | 0 | 0 |
| after normal r1 / r2 / r3 | 7 | 1.606 / 1.636 / 1.770 | 2.26 / 2.36 / 2.64 | 2.93 / 3.26 / 4.00 | 0.174 / 0.182 / 0.194 | 0 | 0 |
| before stress r1 / r2 | 24 | 3.290 / 3.378 | 4.81 / 5.06 | 5.93 / 6.12 | 0.596 / 0.607 | 0 | 0 |
| after stress r1 / r2 | 24 | 3.414 / 3.634 | 5.09 / 5.60 | 6.20 / 6.66 | 0.590 / 0.628 | 0 | 0 |

**Reading:**
- normal is about +0.15–0.3 ms per frame (one more guard, four cameras, the new checks);
- stress (same 24 guards) is about +0.1–0.3 ms;
- guard AI per guard is unchanged (0.025–0.030 ms);
- run-to-run spread on this VM is about 5–10%;
- all frames are far below the 16.7 ms budget at 60 fps (worst p99 6.7 ms with 24 guards).

A rendering (GPU) run was **not** measured in this phase.

## 6. Evidence

Screenshots (xvfb, OpenGL 3, 1600×1000; [`phase-5/screens/`](phase-5/screens/), sheet [`contact_security.png`](phase-5/contact_security.png)):

| Shot | Shows |
|---|---|
| s01 | the basement guard on patrol in the service tunnel |
| s02 | the tunnel camera, powered |
| s03 | the electrical room: SURVEILLANCE ON, the breaker cover, SERVICE EXIT OFF, the board label |
| s05 | a camera alarm: "ALARM — guards are on their way" and "ALARM: Camera (archive hall) spotted you" |
| s06 | SURVEILLANCE OFF: "the cameras go dark. The guards are not affected." |
| s07 | the archive hall camera dark |
| s08 | the dock with the manuscript: "SHUTTER · NO POWER" and its message |
| s09 | SERVICE EXIT ON: "Service ON: dock powered. Security rebooted: cameras ON, switch locked 30 s." |
| s10 | the surveillance switch locked: countdown prompt and message |
| s11 | the dock "EXIT · UNLOCKED" |

## 7. Known limitations and risks

- **Not human-playtested.** Readability of the camera cones and the trade-off was judged from screenshots only. Cameras are small at distance; the cone is faint by design.
- **Tutorial guards:** `HidingSpot.entered_unseen` is computed everywhere, but only guards with `expanded_security` use it. The tutorial's guards are untested for any behaviour change beyond the existing suites, which pass.
- **Camera concealment is global:** any concealing hiding spot hides the player from all cameras (there is one player, so this is the same thing).
- **Mission tests:** `expanded_mission_tests` turns the dock's power requirement off (documented in the test) to keep testing doors and order. The requirement is covered with real switches in the puzzle and security suites.
- **Suite duration:** about 17 min here. The CI timeouts were raised (suite 30 min, job 55 min). A slower runner could still approach them.
- **Main entrance:** still reserved (`main_entrance_lockdown` true). Phase 4 had said "the security phase will lift it"; the Phase 5 brief did not ask for it, so nothing lifts it. It needs an owner decision.
- **Pre-existing flaky tutorial test:** the guard_tests first-wait timing failure (it fails identically on 7d73492) did not occur in these runs. Its fix still awaits approval.
- **Windows export:** built on Linux only; not run on Windows.

## 8. Tutorial regression

The tutorial scene is unchanged. Its three guards keep the defaults (tested in security A and the graybox test). Every tutorial suite passes:
- Phases 2–14;
- QA playthroughs and regressions;
- `QA FLOW PASSED` (4 levels);
- `MAP FLOW PASSED` (12 levels, 3 cycles).

## 9. Git

Branch `Development`, at `7d73492`. Phases 1–5 are uncommitted in the working tree, delivered to `D:\gitclone\CampusEscape3D-2` for the owner to review, commit and push. Nothing was committed or pushed to the owner's repository.

## 10. Recommendation

**PASS.** Stop for the owner's approval before Phase 6.
