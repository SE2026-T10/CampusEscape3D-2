# Expanded Library expansion — Phase 9: polish and performance

Date: 2026-10-18. Branch for the owner's commit: `Development`. Godot 4.7.2 stable (official), GDScript.

Scope agreed with the owner before starting: **decorative only** (no wall, floor, door, collision or navmesh change); the Phase 8 balance proposals P1–P3 **deferred**; FPS **split**: CPU cost measured on the Linux VM here, the frame-rate targets measured by the owner on Windows (section 5.4).

## 1. Summary

- **Rendering:** the expansion's static boxes (floors, walls, ramps, cover, ceilings, headers, floor patches and the new decor) are merged into `BatchedBoxes` MultiMeshes, the way the existing level's builder already batches the original map: one batch per 12 m cell, look kind, render layer and shadow setting, split again until no more than 8 lights reach a piece (the Compatibility renderer's per-mesh limit; the main level's lamps near the expansion count too). Plain colours share one vertex-colour material. Draw calls on the benchmark's camera loop: mean **541 → 501**, p95 **1011 → 905**; meshes in the light report **735 → 646**.
- **CPU:** per-frame work removed where nothing changed: security cameras keep the player reference, skip sight rays for a player beyond range + 2 m and only touch lens and cone materials when the colour, power or meter (2 % steps) changes; access doors, exit doors, the objective HUD and the stealth HUD only set texts, colours, theme overrides and materials when they change; the stealth meter only redraws while it shows. Interleaved A/B on the VM: frame time median **2.23 → 1.98 ms** (normal, 7 guards) and **4.58 → 4.44 ms** (stress, 24 guards).
- **Decor (no collision):** pipes and a red fire main along the tunnel's north wall (with a gap at the culvert), a cable tray along its south wall (with a gap at the tunnel camera), pump room headers, cross pipes and risers, a tool board with tools above the maintenance bay crate, conduits and a cable tray in the electrical room, the 2019 flood line, damp and puddles in the storm drain, yellow and black hazard stripes at the top and bottom of both service stairs, and emissive door lamps beside the bay, pump room and electrical room doors (no new lights).
- **Signs:** MAINTENANCE BAY over its door, direction signs on the tunnel's north wall (← STACKS · PUMP ROOM →, ← PUMP ROOM · ELECTRICAL →), DANGER · 400 V above the electrical cabinets, FLOOD LEVEL · 2019 in the storm drain (only seen once the hidden panel is open).
- **Readability fix:** the storm drain's state label (GRATE JAMMED / CLEAR) overlapped the wall's STORM DRAIN · SEALED sign, so both were hard to read (it was like that before this phase; see the before column of `p9_before_after.png`, row v6). It now sits 0.5 m lower.
- **Audio cues:** ten new synthesised sounds (same generator, seed and style as the others) played in 3D where the mechanism is, by a new listener node, `MechanismAudio`: a click for keypad dials, ENTER, breakers, valves and the pump start; a buzz for a wrong code, or a keypad without power; a rising chime when a puzzle is solved; a clunk for circuit switches and tool mechanisms (panel cover, pump crank, dock release); a soft chime when an item is taken (none when refused); and, through their captions, the badge reader beep, the door bolts, the shutter, the pump stall, a smashed bottle and a thrown hardback. It only listens to existing signals; no mechanism script changed. Refusals (`door_locked`) and doors opening stay with `AudioDirector`, so nothing plays twice.
- **Unchanged (checked):** collision fingerprint identical; a navmesh rebake is byte-identical to the committed one; lights in view and lights per mesh as before; guards, routes, items, clues, hiding spots, puzzles and the tutorial untouched.

## 2. Exact files

| File | Change |
|---|---|
| `tools/expanded/expansion/build_expansion.gd` | `_batch_static_meshes()` and helpers (`_collect_batchable`, `_batch_host`, `_light_bounds`, `_split_for_lights`, `_items_aabb`, `_world_of`, `_world_in`, `_under`); `_add_decor()`; decor looks; empty decor holders removed after batching; `MechanismAudio` node; the drain state label 0.5 m lower |
| `tools/expanded/expansion/expansion_layout.gd` | `DECOR_LOOKS`, `DECOR`, `STAIR_STRIPES`; five signs appended to `SIGNS` |
| `scenes/level/expanded_library_expansion.tscn` | rebuilt by the builder (node ids kept with `keep_ids.py`) |
| `scripts/presentation/mechanism_audio.gd` (+ `.uid`) | new: the mechanism sound listener |
| `scripts/presentation/sound_bank.gd` | the ten new sounds registered |
| `tools/generate_audio.gd` | the ten new sounds, generated last |
| `assets/audio/{mech_click, mech_clunk, puzzle_wrong, puzzle_solved, reader_beep, shutter_rattle, pump_stall, glass_smash, item_thud, item_pickup}.wav` (+ `.import`) | new; import settings identical to the existing sounds |
| `scripts/systems/security/security_camera.gd` | cached player; no sight check out of range; visuals only on change |
| `scripts/systems/objectives/exit_door.gd` | material, sign text and modulate only on change |
| `scripts/systems/objectives/access_door.gd` | panel colour and sign tint only on change |
| `scripts/ui/objective_hud.gd` | `_set_text()` (no re-parse of unchanged BBCode); prompt colour only on change |
| `scripts/ui/stealth_hud.gd` | banner colour only on change; meter redraw only while shown |
| `tools/benchmark.gd` | `--disable=expansion` diagnostic (hides the expansion's visuals and lights) |
| `tests/expanded_polish_tests.gd` (+ `.uid`) | new suite (section 4) |
| `tests/test_scene.gd` | registers it; pass line adds "Expanded Library expansion polish and performance" |
| `tests/presentation_tests.gd` | sound file count 32 → 42 |
| `README.md`, `docs/qa/REGRESSION_CHECKLIST.md`, `docs/expanded/LEVEL_LOG.md` | the new suite, the checklist row, the log entry |
| `docs/expanded/expansion/phase-9-polish-performance.md`, `docs/expanded/expansion/phase-9/` | this report and its evidence |

Not changed: `scenes/level/expanded_library.tscn`, `scenes/level/expanded_library_navmesh.tres`, the tutorial, the guards, every mechanism and puzzle script, the existing 32 sound files.

## 3. Systems reused

`scripts/level/batched_boxes.gd` (the existing level's MultiMesh batching), the builder's palette (`build_expanded_graybox.gd` LOOKS) and `_add_visual_box` / `_add_sign`, `scenes/props/ceiling_light.tscn` (no new lamps), `tools/generate_audio.gd` and its building blocks, `SoundBank`, the `AudioStreamPlayer3D` set-up used by `GuardPresentation`, the SFX bus, existing signals (`PuzzleControl.changed / pressed`, `Puzzle.solved / feedback`, `ToolMechanism.operated`, `CircuitSwitch.feedback`, `PlayerInventory.notice`, `NoiseSystem.noise_emitted`), `tools/benchmark.gd`, `tools/expanded/collision_fingerprint.gd`, `tools/expanded/expansion/bake_navmesh.gd`, `tools/expanded/light_report.gd`, `keep_ids.py`.

## 4. Acceptance criteria

| Criterion | Result | Evidence |
|---|---|---|
| Layout and functional geometry intact | **PASS** | collision fingerprint (786 lines: every collision object, shape, transform, guard and patrol point) identical before and after; navmesh rebake byte-identical, 1020 polygons (was 1020) |
| Polish does not hide clues or break navigation | **PASS** | `expanded_polish_tests`: no collision under Dressing; every decor box is a floor decal, above 2.3 m or off the navmesh; every box at least 0.6 m from every interactable and hiding spot; mutation check: a tool board moved into the bay and a puddle raised onto the hiding spot were both caught. Screenshots: every clue, item and hiding spot visible as before |
| Performance documented against the targets | **PARTLY — targets NOT VERIFIED yet** | CPU cost measured here (section 5). This VM has no GPU, so 60 / 45 FPS can only be measured on the owner's PC (commands in 5.4) |
| Remaining issues have documented causes | **PASS** | section 7 |
| Tutorial regression tests pass | **PASS except the known guard-timing flake** (3 assertions, both full runs; 0/3 alone) | section 6, 7.3 |

## 5. Performance

### 5.1 Test machine and method

- **Machine:** cloud VM, Intel Xeon @ 2.80 GHz, **2 vCPUs**, 7 GB RAM, Linux 6.18, **no GPU**: rendering is Mesa llvmpipe (software OpenGL 4.5, Godot's Compatibility renderer). Debug build of the official Godot 4.7.2 binary (`debug_build: true`). Shared host, so run-to-run variance is about ±15 %.
- **Scene:** `scenes/level/expanded_library.tscn` (the full map: main level + expansion). Normal = the map's own 7 guards; stress = 24 guards on the same routes.
- **Method:** `tools/benchmark.gd`: a fixed camera loop along the mission's main route (up S1, staff wing, archive, down S2, lobby), a RUN noise every 4 s so guards investigate, **5 s warm-up then 30 s measured** (simulated time).
  - Headless, `--fixed-fps 60`: no rendering, every frame is one physics tick, run as fast as the CPU allows: the frame time is the whole CPU cost of a game frame (scripts, physics, navigation, AI, animation). 1800 frames per run.
  - Rendered, 1280×720, vsync off, uncapped (xvfb + llvmpipe): draw calls, objects, primitives and render CPU time. With software rendering the frame rate itself (about 5 FPS) only reflects llvmpipe, not a GPU.
- **Before:** the build before this phase (scratch HEAD `79a50aa` = Phase 8 + the later fixes). **Phase 9:** this delivery.

### 5.2 CPU (headless)

Interleaved A/B (before and Phase 9 alternately, three rounds, same machine, same minutes):

| Scenario | Frame time, median of 3 (runs) | p99 (median) | FPS (median) | All scripts | Guard AI (per tick) |
|---|---|---|---|---|---|
| Normal, before | **2.23 ms** (2.23, 2.19, 2.24) | 4.25 ms | 449 | 1.22 ms | 0.23 ms |
| Normal, Phase 9 | **1.98 ms** (1.70, 1.98, 2.29) | 3.58 ms | 505 | 1.09 ms | 0.23 ms |
| Stress, before | **4.58 ms** (4.60, 4.48, 4.58) | 9.02 ms | 218 | 2.46 ms | 0.73 ms |
| Stress, Phase 9 | **4.44 ms** (4.44, 4.51, 4.12) | 7.88 ms | 225 | 2.43 ms | 0.78 ms |

Frame breakdown (single runs; scripts in physics ticks / in process, guard AI, guard animation, "other" = physics engine step, navigation, scene tree), Phase 9: normal 0.49 / 0.64 / 0.24 / 0.12 / 0.89 ms; stress 1.23 / 1.20 / 0.77 / 0.45 / 2.02 ms. Physics: 8 bodies active (normal), 25 (stress), 30–55 collision pairs. Navigation: 7 / 24 agents; no guard got stuck in any run (`stuck_events` empty), nobody caught the benchmark camera. Tutorial normal for comparison: 1.20 → 1.05 ms.

Reading: the CPU budget for 60 FPS is 16.7 ms per frame; the whole game frame costs about 2 ms with 7 guards and 4.5 ms with 24 on this VM (debug build), so CPU is not what decides the 60 / 45 FPS targets. Guard AI scales linearly (≈ 0.03 ms per guard per tick) and is unchanged by this phase. The gains come from the HUD and camera changes (fewer theme and material updates, no BBCode re-parsing); they are modest and within the VM's noise for single runs, which is why the A/B was interleaved.

### 5.3 Rendering (llvmpipe, 1280×720)

| Run | Draw calls mean / p95 | Objects | Primitives | Render CPU | Frame | Nodes |
|---|---|---|---|---|---|---|
| Normal, before | 541 / 1011 | 1266 | 34 128 | 174 ms | 199 ms (5.0 FPS) | 2742 |
| Normal, batching only | 491 / 880 | 1216 | 34 375 | 181 ms | 209 ms (4.8 FPS) | 2627 |
| Normal, Phase 9 (with decor) | 501 / 905 | 1226 | 34 789 | 180 ms | 205 ms (4.9 FPS) | 2734* |
| Stress, before | 738 / 1316 | 1474 | 36 531 | 181 ms | 218 ms (4.6 FPS) | 3405 |
| Stress, Phase 9 | 697 / 1269 | 1433 | 37 104 | 189 ms | 228 ms (4.4 FPS) | 3397* |
| Normal, `--disable=expansion` (before) | 394 / 743 | 1119 | — | — | 5.1 FPS | — |

\* measured before the empty decor holders were removed from the scene (about 100 empty `Node3D`s, no visual or cost in rendering).

The expansion cost 147 draw calls on the loop before this phase (541 vs 394 with its visuals hidden); batching removes 50 of them and the decor adds 10 back. Under llvmpipe the frame rate does not follow draw calls: about 180 ms of each frame is software rasterising pixels, the same with fewer calls, so these FPS figures say nothing about a real GPU. Lights: most lights touching one view **32** (the renderer's limit, 0 views over it), unchanged; no expansion mesh is reached by more than 8 lights.

### 5.4 Frame-rate targets: to be measured on the owner's PC

Targets: about **60 FPS** in normal play and **at least 45 FPS** in the documented stress test. **NOT VERIFIED** — this VM has no GPU. Please run from the project folder (PowerShell; change the Godot path), with nothing else heavy running, laptop on mains power:

```
$G = "C:\path\to\Godot_v4.7.2-stable_win64.exe"
& $G --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --level=expanded --scenario=normal --out=docs/performance/windows/expanded_phase9/render/normal_r1 --label=expanded_normal_r1
& $G --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --level=expanded --scenario=normal --out=docs/performance/windows/expanded_phase9/render/normal_r2 --label=expanded_normal_r2
& $G --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --level=expanded --scenario=stress --out=docs/performance/windows/expanded_phase9/render/stress_r1 --label=expanded_stress_r1
& $G --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --level=expanded --scenario=stress --out=docs/performance/windows/expanded_phase9/render/stress_r2 --label=expanded_stress_r2
```

Each run takes about 40 s in a window; send the four `summary.json` files (or the folders). Pass if `fps_avg` ≥ 60 in normal and ≥ 45 in stress (I will also report `fps_1pct_low` and the frame-time p99). Optional, CPU only: the same with `--headless --fixed-fps 60` instead of `--resolution 1280x720`. For context only: the tutorial map on the GeForce MX130 laptop in `docs/performance/windows/` averaged 197–213 FPS (normal) and 147–159 FPS (stress) at 1280×720.

## 6. Tests actually run (Linux VM, Godot 4.7.2 official)

| Run | Result |
|---|---|
| `tools/ci/validate.sh` | exit 0 (11 s): engine version, import, every script compiles, version numbers |
| `tools/ci/run_tests.sh`, run 1 | 1516 s. Every suite passed (including the new `expanded_polish_tests`, `expanded_e2e_tests` and every tutorial suite) **except 3 assertions of the known tutorial guard-timing flake** in `guard_tests` (GuardEast / GuardMain / GuardRestricted "waited 2.20 s at point 1, expected 2.00 s"); 8 expected warnings, 0 script errors ([`phase-9/logs/tests_run1.log`](phase-9/logs/tests_run1.log)) |
| `tests/guard_tests.gd` alone, 3× | 0 failures each time |
| `tools/ci/run_tests.sh`, run 2 | 1517 s; the same result: everything passed except the same 3 guard-timing assertions ([`phase-9/logs/tests_run2.log`](phase-9/logs/tests_run2.log)) |
| `tools/qa_flow.gd` | QA FLOW PASSED (15 checks, 4 levels loaded) |
| `tools/map_flow.gd` | MAP FLOW PASSED (52 checks, 12 levels loaded, 3 cycles) |
| `tools/ci/export_windows.sh` | EXPORT PASSED: `dist/CampusEscape3D-1.1.0-windows-x64.zip` |
| `tests/expanded_polish_tests.gd` alone | 0 failures; mutation check (a dial hook removed, a board moved into walkable space, a puddle raised onto a hiding spot): all three caught |
| Collision fingerprint before / after | identical (786 lines) ([`phase-9/checks/collision_fingerprint.txt`](phase-9/checks/collision_fingerprint.txt)) |
| Navmesh rebake | "1020 polygons (was 1020)", file byte-identical to the committed navmesh (rebake not delivered: nothing to change) |
| Light report | 32 lights max in view (limit 32, 0 over); 7 meshes over 8 lights, all in the main level and the same 7 as before this phase ([`phase-9/checks/lighting_report.md`](phase-9/checks/lighting_report.md)) |
| Sound generation | the existing 32 sounds regenerated with identical samples (only the WAV headers' bytes differ), so the committed files were kept as they were; only the 10 new files are delivered. Read back from your folder, the 10 new WAVs carry an extra C2PA provenance chunk after the audio, added by the file transfer; the samples are identical and Godot imports them identically (same length and data size for all 10, checked by importing the transferred copies here) |
| Benchmarks | sections 5.2 and 5.3 ([`phase-9/benchmarks/`](phase-9/benchmarks)) |

## 7. Known issues, risks and their causes

1. **FPS targets not verified.** Cause: the VM has no GPU. The owner's run (5.4) decides them.
2. **Lights in view at the renderer's limit (32) and 7 main-level meshes reached by 9–11 lights.** Cause: the main level's own lamps (`expanded_library.tscn`, frozen in these phases); unchanged by this phase and with no view over the limit. If the owner's run shows lighting pops, the fix belongs to the main level, outside this phase.
3. **Tutorial guard-timing flake** fired once in the full run. Cause: under load a physics frame lands after the wait time (2.2 s vs 2.0 s); the one-line test fix from the Phase 6 report still awaits approval. It passed 3/3 alone but fired in both full runs here (the same 3 checks as in Phase 6's run 2). The tests that run before it (Phases 1–3) are untouched by this phase, so its frequency depends on start-up timing, not on these changes; still, until the fix is approved the CI test job will likely go red.
4. **Test time 1516 s** against `run_tests.sh`'s 1800 s timeout (and the workflow's 55 min). Cause: one more suite. Suggestion (not applied): raise the script's timeout to 2400 s; `.github/workflows/build.yml` is outside what I can write.
5. **Decor can clip a player pressed against a wall.** Cause: by design the decor has no collision and pipes stand up to 0.25 m off a wall face, inside the 0.5 m navmesh margin where only the player's body (radius 0.35) can reach. Visual only.
6. **Headless numbers vary ±15 % run to run** on this shared VM. Cause: noisy neighbours; hence the interleaved A/B with medians.
7. **Regenerating the sounds rewrites the old WAV files' headers** (samples identical). Cause: the WAV writer's header bytes; the committed originals were kept. Re-running `generate_audio.gd` later will show those 32 files as modified with identical audio.

## 8. Tutorial regression

The tutorial's scene, guards, scripts and sounds are not changed; `MechanismAudio` exists only in the expansion (the polish suite checks the tutorial has none). Tutorial suites (Phases 1–14 including presentation with the new sound count, performance checks, QA playthroughs, map selection) passed in both full runs except the 3 known guard-timing assertions (section 7.3); QA flow and map flow passed.

## 9. Git

Nothing committed or pushed in your repository. Files delivered to `D:\gitclone\CampusEscape3D-2` for you to review and commit on `Development`.

## 10. Recommendation

**HOLD**, for two owner-side items only:

1. The Windows benchmark (5.4): the 60 / 45 FPS targets are an acceptance criterion and can't be measured on this VM.
2. The tutorial guard-timing flake (7.3): approve the one-line test fix (await one process frame after setting `Engine.time_scale` in `tests/guard_tests.gd`), or accept it as a known flake.

Everything else in this phase meets its criteria. Phase 10 has not been started.
