# Regression Test Checklist — Campus Escape 3D

Run this before every release or after any change to gameplay, the level, AI or presentation.

**Part 1 — automated (run every time):**

| # | Command | Pass condition | Time |
|---|---|---|---|
| A0 | GitHub Actions **Build** workflow on the commit (`.github/workflows/build.yml`; locally: `tools/ci/validate.sh`, `run_tests.sh`, `export_windows.sh`) | all jobs green; the `CampusEscape3D-<version>-windows-x64` artifact is uploaded | ~10 min |
| A1 | `godot --headless --path . res://tests/test_scene.tscn` (or open `tests/test_scene.tscn`, F6) | prints `All tests passed (… Phase 14 QA).`, exit 0, only the 8 expected warnings listed below | ~3.5 min |
| A2 | `godot --path . --script res://tools/qa_flow.gd -- --out=docs/qa/flow_check` (`--headless` also works, without screenshots) | prints `QA FLOW PASSED (15 checks, 4 levels loaded)`, exit 0 | ~1 min |
| A3 | `godot --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --scenario=normal --out=…`, then the same with `--scenario=stress` | no script errors; `caught` 0; compare FPS with the last recorded run on the same machine (`docs/phase-13-performance.md`) | ~1 min each |
| A4 | `godot --path . --resolution 1280x720 --script res://tools/capture_views.gd -- --out=…` | the 9 views match the last recorded set (`docs/performance/visual/after_2splits_2048/`) unless the level was changed on purpose | ~20 s |

**The 8 expected warnings in A1.** They come from tests that build broken setups on purpose:
- GuardA, GuardB and VisionTestGuard: "no navigation mesh found nearby" and "has no patrol route".
- NoRouteGuard: "has no patrol route".
- StuckGuard: "is stuck … moving on".

Any other warning or error is a failure.

**Part 2 — manual, on the Windows target (Godot 4.7.2, F5 from the main menu).** Tick each line; write the date and build next to the release.

Legend: **Auto** = which automated check covers it (file → check). **Manual** = what to look at by hand.

## Player

| ✓ | Item | Auto | Manual: do this → expect this |
|---|---|---|---|
| ☐ | Movement (WASD) | `player_tests` → `_check_movement_math`, `_check_movement_in_level` (walk 3.5 m/s); `qa_playthrough` → full route walked | Walk around every room → smooth, no sliding after release, diagonal not faster |
| ☐ | Camera (mouse look) | `player_tests` → pitch clamp, yaw turns body | Look around → no inverted axes, can't flip over the top, sensitivity comfortable; head bob gentle |
| ☐ | Collision | `player_tests` → stops at crate and wall; `navigation_tests` → `_check_level_sealed`; `qa_playthrough` → route has no invisible blockers | Push into walls, shelves, tables, plants → never pass through; no snagging in doorways |
| ☐ | Sprint (Shift) | `player_tests` → 5.5 m/s; `hearing_tests` → RUN noise | Sprint → faster, FOV widens slightly, footsteps louder, guards hear it |
| ☐ | Crouch (C / Ctrl) | `loop_tests` → `_check_crouch`, `_check_crouch_walking_is_quiet` | Crouch under nothing and under a carrel → slower, quieter; can't stand up under something low |
| ☐ | Jump | `player_tests` → no `jump` action (out of scope) | Press Space while playing → nothing happens |
| ☐ | Fall safety | `player_tests` → falling below the level respawns | — |

## Navigation

| ✓ | Item | Auto | Manual |
|---|---|---|---|
| ☐ | NavigationMesh | `navigation_tests` → saved bake = fresh bake (224 polygons), coverage, inside floors, sealed | After moving any level geometry: rebake (README), then run A1 |
| ☐ | NPC pathfinding | `navigation_tests` → paths between all areas, probe walks entrance → exit; `guard_tests` → all 3 patrols complete loops | F3 debug view → guard paths follow corridors, never cut through walls |
| ☐ | Obstacles | `navigation_tests` → 97 obstacle samples not walkable; `guard_tests` → head-on guards pass, blocked guard moves on | Stand in a doorway on a patrol route → the guard waits/steers, then skips the point after ~5 s |

## AI

| ✓ | Item | Auto | Manual |
|---|---|---|---|
| ☐ | Patrol | `guard_tests` → `_check_level_patrols`, waits at points | Watch each guard for two loops → no stopping or jitter |
| ☐ | Investigate | `ai_behavior_tests` → `_check_noise_investigation`; `presentation_tests` → walk then search animation | Sprint behind a guard → "?", radio call, walks to the noise, searches, returns |
| ☐ | Chase | `ai_behavior_tests` → `_check_detection_cycle`; `loop_tests` → `_check_escape_by_sprinting`; `qa_playthrough` → real chase (run animation, chase music) | Get spotted → "!", alarm, guard runs; break line of sight → guard investigates then gives up |
| ☐ | Vision | `vision_tests` (cone, range, walls, cover, meter timing); `level_design` / `objective_tests` → spawn and checkpoints unseen | Walk into a guard's view → meter fills faster when close; walls and tall shelves block it |
| ☐ | Hearing | `hearing_tests` (range, walls muffle, estimates never exact, footsteps) | Crouch-walk near a guard → not heard; sprint → heard |
| ☐ | Detection | `vision_tests`, `loop_tests` → status priority, carrel hides crouched player; `presentation_tests` → meter follows the most aware guard | Detection meter rises and falls with what the guard sees |
| ☐ | State transitions | `ai_state_tests` (2000-operation random storm, only legal transitions); `ai_behavior_tests` → full cycle | — |

## Gameplay

| ✓ | Item | Auto | Manual |
|---|---|---|---|
| ☐ | Objectives | `objective_tests` → `_check_flow_rules`, `_check_card_and_escape`; `qa_playthrough` → all 5 by walking | Panel shows the current objective and "n/5"; it flashes when it changes |
| ☐ | Interaction | `objective_tests` → `_check_interaction` (reach, line of sight, prompts); `qa_playthrough` → E key | Look at the card / door → key-cap prompt; look away → it fades |
| ☐ | Access item (card) | `objective_tests` → can't take it before the stacks; taking it unlocks the door | Card glows under its spotlight; taking it plays the pickup sound |
| ☐ | Checkpoints | `objective_tests` → `_check_checkpoints_are_safe`, progress kept / undone; `qa_playthrough` → activated by walking | Step on each pad → message and chime once |
| ☐ | Respawn | `objective_tests` → respawn at the right checkpoint, guards reset; `qa_playthrough` → after a real catch | Get caught after each checkpoint → back at that pad, guards on patrol |
| ☐ | Escape | `objective_tests` → exit rejects without the card, opens with it | Try the door without the card → "locked" message and rattle; with the card → door opens |
| ☐ | Victory | `game_flow_tests` → `_check_victory`; `qa_regression` → QA-1 title pop; `qa_flow` → real win screen | Win screen: title pops in, time, catches, 5/5, Play again focused |

## Game flow

| ✓ | Item | Auto | Manual |
|---|---|---|---|
| ☐ | Pause (Esc / P, focus loss) | `game_flow_tests` → `_check_pause_and_resume`, everything frozen while paused; `qa_flow` | Esc → menu fades in, cursor visible, world frozen, room tone quieter; Alt-Tab → pauses |
| ☐ | Resume | same | Resume button and Esc both resume; mouse captured again |
| ☐ | Caught | `loop_tests` → `_check_caught_and_reset`; `game_flow_tests` → pause refused on the caught screen; `qa_flow` | Red vignette, "Back to …", countdown bar, caught sound; Esc does nothing |
| ☐ | Restart | `game_flow_tests` → `_check_restart_and_menu_from_pause`; `qa_flow` → real reload | Pause → Restart → fresh level, objectives reset, music off |
| ☐ | Win | `game_flow_tests`; `qa_flow` → Play again / Main menu | Play again → fresh level; Main menu → title screen; Quit → closes |

## Presentation

| ✓ | Item | Auto | Manual |
|---|---|---|---|
| ☐ | UI | `presentation_tests` (meter, header, prompt split); `qa_regression` → QA-1; `qa_flow` screenshots at 1280×720, 1920×1080 and 1024×576 | Readable at your monitor's resolution; nothing overlaps |
| ☐ | Audio | `presentation_tests` → all 32 sounds load, loops loop, buses, director events, UI sounds while paused; `qa_playthrough` → sounds of a real playthrough and chase | **Listen**: footsteps, stings, music loops without clicks, ambience, menu clicks; volumes balanced |
| ☐ | Animation | `presentation_tests` → every animated joint exists, walk / search in the level; `qa_playthrough` → run in a real chase | Guards: idle, walk, run and search look right; little foot sliding |
| ☐ | Lighting | `performance_tests` → sun shadows on, 2 cascades, 2048 atlas; A4 view comparison | No light leaks; shadows don't flicker; signs readable |

## Performance

| ✓ | Item | Auto | Manual |
|---|---|---|---|
| ☐ | Normal scenario (3 guards) | A3; `docs/phase-13-performance.md` (test VM: 11.6 FPS on software rendering) | Run A3 on the Windows PC and record FPS / 1% low; Debugger → Monitors while playing |
| ☐ | Stress scenario (24 guards) | A3; headless CPU 2.1 ms per frame on the test VM | Same; check no script errors and no runaway memory |

## Last run

| Date | Build | Part 1 (automated) | Part 2 (manual, Windows) | By |
|---|---|---|---|---|
| 2026-10-05 | commit "Phase 14: final QA pass" | A1 pass (exit 0, 211 s); A2 pass (headless and at 3 resolutions); A3 pass (normal 12.0 FPS, stress 10.4 FPS, llvmpipe); A4 identical to Phase 13 | not run (no Windows machine in the QA environment) | Claude (automated) |
