# Campus Escape 3D — Final MVP Report (v1.0.0)

Release validation date: **2026-10-09**. Commit validated: `15b3ebf` ("Phase 15: final report") on `Development`, plus the documentation-only corrections made during this validation.

Every figure below comes from a file in this repository, a test log, or the GitHub Actions run named. Where something was **not** verified, this report says so.

---

## 1. Project

| | |
|---|---|
| **Name** | Campus Escape 3D |
| **Description** | A low-poly, first-person 3D stealth game set in a university library at night. Sneak in, take an access card from the Restricted Stacks, and escape through the exit while three guards patrol, see, hear, investigate and chase. |
| **Engine / version** | Godot **4.7.2 stable**, official build `4.7.2.stable.official.ed1daf0bf` (checked by the test suite and by `tools/ci/validate.sh`). Renderer: Compatibility (OpenGL 3.3). |
| **Language** | GDScript (71 scripts, all compiled by `tools/ci/check_scripts.gd`) |
| **Genre** | First-person stealth |
| **Scope** | MVP: one polished level (the library), Windows x64 desktop. Main menu, pause, caught and win screens. No save game, no settings menu, no jump. |
| **Version** | `1.0.0` (`application/config/version` in `project.godot`; preset file/product version `1.0.0.0`) |

---

## 2. Gameplay

### Player mechanics (`scripts/player/player.gd`, `player_noise.gd`, `player_interactor.gd`)

| Mechanic | Value / behaviour |
|---|---|
| Walk (WASD) | 3.5 m/s — measured 3.50 m/s by `player_tests` |
| Sprint (Shift) | 5.5 m/s — measured 5.50 m/s; makes RUN noise (12 m radius) |
| Crouch (C / Ctrl) | 1.8 m/s, capsule 1.8 → 1.0 m, eye 1.6 → 0.95 m; halves how fast guards' meters fill; footsteps reach ~2 m; can't stand up under something low |
| Look | mouse, pitch clamped to ±85° |
| Use (E) | ray interaction: take the access card, open the exit door |
| Hide | crouch inside one of five study carrels (1.4 m panels block sight from the sides and back) |
| Fall safety | below y = −10 the player respawns |
| Jump | deliberately absent (no vertical routes; would allow skipping sections) |

### Objectives (`scripts/systems/objectives/`)

Completed strictly in order, shown in the objective panel as "OBJECTIVE n/5":

1. Enter the library.
2. Reach the Restricted Stacks.
3. Take the access card from the archive desk (E).
4. Reach the exit.
5. Escape through the exit door (E).

The exit door stays locked (red) until the card is taken; trying it makes an INTERACTION noise (8 m) that guards can hear.

### Checkpoints (`scripts/systems/checkpoints/`)

- Two pads: **Hallway West** and the **Staff Nook** (off the back corridor). Stepping on one makes it the respawn point; it turns green.
- Checkpoints don't activate during a chase.
- `objective_tests` checks that no guard sees either respawn point during 45 s of patrol.

**Caught → respawn:** a chasing guard within 1.2 m catches the player. After 2.5 s the player is back at the last checkpoint (or the entrance), every guard returns to patrol with no memory, and objective progress returns to what it was when the checkpoint was reached (a card taken after it goes back on the desk).

### Escape condition

Holding the access card and using the unlocked exit door completes objective 5. The game enters **WIN**: the victory screen shows time and number of catches, with **Play again** and **Main menu**.

Game-level states (`scripts/game/game_state_machine.gd`): PLAYING, PAUSED, CAUGHT, WIN. Only legal transitions are accepted (3,000 random requests in `game_flow_tests`: 0 illegal or duplicate).

---

## 3. AI

Each guard runs an explicit state machine (`scripts/npc/ai/guard_state_machine.gd`) with three states. Transitions are evaluated every physics tick in priority order; the first that applies wins, and anything else (e.g. CHASE → PATROL) is rejected.

| # | Trigger | Transition |
|---|---|---|
| 1 | confirmed sighting (meter 100 and player visible) | PATROL / INVESTIGATE → CHASE |
| 2 | suspicious sighting (meter ≥ 30) | PATROL → INVESTIGATE at the sighting |
| 3 | noise heard | PATROL → INVESTIGATE at the *estimated* position |
| 4 | search timed out (6 s) | INVESTIGATE → PATROL |
| 4 | lost sight (4 s) | CHASE → INVESTIGATE at the last known position |

| Area | Implementation | Key parameters |
|---|---|---|
| **Patrol** | `patrol_state.gd`, `PatrolRoute` / `PatrolPoint`, `NavigationAgent3D` | 2.0 m/s, default 2 s wait per point, skip a point after 5 s stuck; resumes where it left off |
| **Investigate** | `investigate_state.gd` | 2.6 m/s; walks to the evidence, sweeps ±60° every 1.5 s for 6 s; gives up travelling after 20 s; new evidence retargets it |
| **Chase** | `chase_state.gd` | 4.2 m/s (player sprint 5.5 m/s, so escape is possible); follows only what it perceives, repaths every 0.5 m |
| **Vision** | `guard_vision.gd` | 90° cone, 14 m; rays to the player at 1.5 / 0.9 / 0.3 m; blocked by walls and tall shelves, not low tables |
| **Hearing** | `guard_hearing.gd`, `noise_system.gd` | WALK 5 m, RUN 12 m, INTERACTION 8 m; walls halve range; position estimate error 0.4 m + 0.12 m/m (max 3 m), ×1.5 through walls; never exact; deterministic per guard; guards ignore other guards' noise |
| **Detection** | meter 0–100 in `guard_vision.gd` | rises 60/s up close (≤ 3 m) down to 12/s at range; holds 1 s then drains 15/s; SUSPICIOUS at 30, ALERTED at 100 (5-point hysteresis); crouching halves the rise rate |

Seeing always outranks hearing, and a chasing guard ignores noise. Measured in the library (`ai_behavior_tests`, this validation run): PATROL→INVESTIGATE at 0.8 s, →CHASE at 2.2 s, →INVESTIGATE at 3.5 s after sight was broken, →PATROL at 9.7 s.

---

## 4. Level

### Library layout (`scenes/level/library_graybox.tscn`)

- **Entrance** (spawn) → **Main Library Room**: four tall bookcases west; Reading Area east with tables, low 1.2 m bookcases (crouch cover) and the circulation desk.
- **Hallway West** (checkpoint) → **Restricted Stacks** (objective: red carpet, RESTRICTED signs, the access card under a spotlight).
- **Back Corridor** with book carts and the **Staff Nook** checkpoint.
- **Hallway East** with a study-alcove carrel.
- **Exit Area**: guarded by the exit warden, with crates, a rack and the exit door.

Two independent routes to the card (west 62 m, east 91 m) and two ways from the card to the exit (back corridor 41 m, long way 95 m) — measured by `level_design_tests` in this run. Navigation mesh: 224 polygons, 628.7 m², verified equal to a fresh bake.

### Level-design decisions

| Version | Decision | Measured reason / effect |
|---|---|---|
| v0 | Baseline measured with the new level tools | Crouch barely mattered (10.8% vs 10.9% exposure); Hallway East had no cover; east route 115 m and more exposed |
| v1 | Cover pass: 1.2 m low bookcases, catalogue cabinet, Hallway East alcove carrel, book carts, exit crates/rack | Gives crouch something to do; floor near cover up; navmesh 168 → 220 polygons |
| v2 | GuardEast becomes the exit warden; 6 candidate routes measured, **B2** chosen | Hallway East exposure 19.6% → 8.2%; east route to the card 117 → 104 m; exit becomes the climax |
| v3 | Readability: door frames, room / RESTRICTED / EXIT signs, clock and globe landmarks, card spotlight | Visual only; metrics identical to v2 by design |
| v4 | Low-poly art pass: palette per zone, generated books, ceilings, lights, props | Gameplay unchanged within 0.6 points; plants nudged navmesh to 224 polygons; lighting deliberately does not affect vision (no false "hide in shadow" cues) |

Overall v0 → v4: floor within 1.5 m of cover 33% → 42%; safest east route 115–117 m → 103 m and peak exposure 38% → 31%; spawn and both checkpoints stay at 0% exposure.

### Version history (evidence)

`docs/level/LEVEL_LOG.md` records each version with `vN/report.md`, `vN/metrics.json`, `vN/map.png`, `vN/views/` (8 fixed viewpoints + top-down), `vN/compare.md`, `v2/experiments/` (one report per candidate patrol) and `before_after/` (v0 beside v4). All were generated by `tools/level_report.gd`, `capture_views.gd` and `level_compare.gd`.

**Caveat found during validation:** the log names one `level(vN)` commit per version, but those commits are not in this repository — all five versions arrived in the single commit `3320e45`. The per-version history is the evidence folders, not git commits. A note has been added to the log.

---

## 5. Testing

### Automated tests

The suite (`tests/test_scene.tscn`) runs 15 test files plus setup checks, stepping real physics where needed:

| File | Covers | Checks (`_check_*` / `test_*` functions) |
|---|---|---|
| `ai_state_tests.gd` | **AI state machine unit tests** with a fake guard: every allowed transition, priority, rejected transitions, enter/exit order, 2,000-step random storm, no shared state | 17 |
| `ai_behavior_tests.gd` | full PATROL → INVESTIGATE → CHASE → INVESTIGATE → PATROL cycle against the real player in the library; noise investigation | 2 |
| `guard_tests.gd` | patrol routes, reachability, waits, no overlap, head-on passing, stuck handling | 8 |
| `vision_tests.gd` | FOV/range maths, meter timing, walls/shelves, debug cone | 10 |
| `hearing_tests.gd` | noise presets, wall muffling, estimate error, event expiry/merging, footsteps | 10 |
| `loop_tests.gd` | stealth status, crouch, carrels, escape by sprint, caught/reset | 8 |
| `objective_tests.gd` | order, card, door, checkpoints, respawn, checkpoint safety | 10 |
| `game_flow_tests.gd` | game-state machine, pause/resume, freeze while paused, win, restart | 11 |
| `navigation_tests.gd` | rooms, navmesh coverage and sealing, paths, probe walk, bake up to date | 8 |
| `player_tests.gd` | input map, movement maths, in-level movement and collision | 4 |
| `level_design_tests.gd` | required spaces, two routes, signs, decoration has no collision | 5 |
| `presentation_tests.gd` | sounds, buses, animation, audio director | 10 |
| `performance_tests.gd` | shadow settings stay as measured; benchmark statistics | 2 |
| `qa_playthrough_tests.gd` | whole route walked with real input; real chase and catch | 2 |
| `qa_regression_tests.gd` | one test per QA bug (QA-1, QA-2) | 2 |

Plus `tools/qa_flow.gd`: 15 checks of the real game flow with real scene changes (menu → play → pause → restart → caught → menu → win → play again → quit).

**Results:**

| Where | Result |
|---|---|
| GitHub Actions, Build #1 (`ubuntu-24.04`) | Validate and test: **passed** (4 m 16 s) |
| Windows 10, this validation (i5-8265U, Godot 4.7.2 win64) | import clean; `CHECK SCRIPTS PASSED (71 scripts)`; `All tests passed (Phase 1 … Phase 14 QA)`, exit 0, exactly the 8 documented expected warnings, 0 errors; `QA FLOW PASSED (15 checks, 4 levels loaded)`, exit 0 |
| Linux VM, Phase 14 (recorded in `docs/qa/full_test_run.txt`) | all passed, exit 0, 211 s |

The tests are shown to be able to fail: `docs/qa/mutation_checks.txt` and `docs/phase-13-performance.md` record deliberate breakages (card not interactable, checkpoints never activating, no chase music, 4 shadow cascades, etc.), each of which fails the suite.

### Manual tests

| Check | Status |
|---|---|
| CI-built `CampusEscape3D.exe` launched on Windows 10 | **passed**: main menu shown (`docs/release/v1.0.0/exe_main_menu.png`) |
| Start game → library level loads and renders in the exported build | **passed** on NVIDIA GeForce MX130 / OpenGL 3.3 (`docs/release/v1.0.0/exe_in_level.png`); objective panel 1/5 and stance HUD present |
| Pause in the exported build | not verified by hand (a synthetic Esc keypress did not reach the game); pause is covered by `game_flow_tests` and `qa_flow` |
| Full manual pass of `docs/qa/REGRESSION_CHECKLIST.md` Part 2 (feel, audio by ear, difficulty) | **not yet done** — to be completed by a human tester |

### Regression tests

- `docs/qa/REGRESSION_CHECKLIST.md`: Part 1 automated (A0 CI, A1 suite, A2 flow, A3 benchmark, A4 view comparison), Part 2 manual per system, each line mapped to the automated check that covers it.
- `tests/qa_regression_tests.gd`: one test per fixed QA bug — QA-1 (win title never animated) and QA-2 (benchmark spawned extra guards on top of level guards) — each failed before its fix.
- The CI workflow re-runs the whole suite and the flow on every push and pull request to `Development` / `main`.

---

## 6. Performance

### Benchmark setup (`tools/benchmark.gd`)

- Runs the real level with a fixed camera path through every room and a RUN noise every 4 s at six fixed points, so guards investigate.
- Scenarios: **normal** (3 guards), **several** (8), **stress** (24); also `--npcs=N`.
- 5 s warm-up, 30 s measured (simulated time); vsync off, uncapped frame rate; 1280×720.
- Per frame: frame time, script time, guard AI time, guard animation time, render CPU/GPU time, draw calls, objects, primitives, memory, nodes, orphans, physics and navigation counts. Written to `frames.csv` + `summary.json` (+ screenshot).
- Headless mode (`--headless --fixed-fps 60`) measures CPU only.

### Hardware

| | Development VM (Phases 13–14) | Windows target (this validation) |
|---|---|---|
| CPU | Intel Xeon @ 2.10 GHz, 2 vCPUs (KVM) | Intel Core i5-8265U @ 1.60 GHz, 4 cores / 8 threads |
| GPU | none — Mesa llvmpipe software OpenGL | NVIDIA GeForce MX130 (driver 466.11), OpenGL 3.3 |
| RAM | 8 GB | 7.9 GB |
| OS | Ubuntu 24.04 | Windows 10 Pro 10.0.19042 |
| Build | editor binary (debug build) | editor binary (debug build) |

### Measurements

**Development VM, software rendering** (`docs/performance/`, Phase 13; stress figures corrected in Phase 14):

| Scenario | Avg FPS before → after shadow optimisation | Mean frame ms | Headless CPU ms/frame |
|---|---|---|---|
| normal (3) | 8.37 → 11.61 (+39%) | 119.6 → 86.2 | 0.72 → 0.77 |
| stress (24) | 7.85 → 10.57 (+35%) | 127.3 → 94.6 | 2.33 → 2.14 |

The optimisation (sun shadow 4 → 2 cascades, directional shadow atlas 4096 → 2048) was chosen from diagnostic runs showing rendering at ~91% of the frame and the 4-cascade shadow as the largest cost; renders before/after differ by 0.1–0.6/255 mean (`docs/performance/visual/`).

**Windows target, real GPU** (`docs/performance/windows/`, this validation, current code):

Rendering at 1280×720, normal ×3 runs, stress ×2 runs (values are the mean of the runs; ranges in brackets). Headless CPU: one run per scenario.

| Scenario | Avg FPS | 1% low FPS | Frame ms mean / p95 / p99 | Render CPU / GPU ms | Scripts ms | Guard AI ms/tick | Draw calls | Static memory |
|---|---|---|---|---|---|---|---|---|
| normal (3) | **202.8** (197.0–212.7) | 62.1 | 4.94 / 6.81 / 16.1 | 1.77 / 3.67 | 0.56 | 0.052 | 311 | 70.2–70.8 MB |
| stress (24) | **153.2** (147.3–159.0) | 57.5 | 6.54 / 10.7 / 17.4 | 2.31 / 3.93 | 1.40 | 0.363 | 602 | 75.0 MB |

| Headless (CPU only) | CPU ms/frame mean / p95 | Guard AI ms/tick | Static memory |
|---|---|---|---|
| normal (3) | 0.85 / 1.03 | 0.097 | 66.2–66.3 MB |
| stress (24) | 2.93 / 3.71 | 0.623 | 70.3–70.6 MB |

Every run: 0 catches, 0 orphan nodes, memory flat within 0.3 MB. On real hardware the game runs at roughly 14–17× the VM's frame rate. In every run, 95% of frames took at most 12.4 ms (≥ 80 FPS) even with 24 guards; about 1% of frames take ~16–18 ms, which puts the 1% low at 57–64 FPS. These are single-machine figures on a laptop (power plan not controlled).

### Profiler evidence

- **Instrumented profiling:** `tools/benchmark.gd` places timing probes at the lowest and highest processing priority around all other nodes' `_physics_process` / `_process`, and around the guards' own priority band, and reads `RenderingServer` render times and Godot's performance monitors. This is how the time split was found (rendering ~91%, scripts ~1.4%, guard AI 0.067 ms/tick for 3 guards).
- **Raw data:** every run's per-frame `frames.csv` and `summary.json`; `docs/performance/results.md` and the charts (`chart_frame_breakdown.png`, `chart_diagnostics.png`, `chart_cpu_scaling.png`, `chart_frametime_series.png`, `chart_fps.png`) are generated from them by `docs/performance/analyse.py`. The headline figures in this report were re-checked against the `summary.json` files during validation.
- **Diagnostics:** `docs/performance/diag/` — one change at a time (shadows off, 640×360, decoration hidden, 2 cascades, omni lights off, …).
- **Memory:** 300 s run — static memory flat at 65.8–66.0 MB after warm-up, 0 orphan nodes.
- **Not included:** screenshots of the Godot editor's Profiler / Visual Profiler panels. The evidence is the benchmark's own instrumentation, not editor captures.

### Known limitations

- All measurements use the editor binary (debug build), not the exported release build.
- The development VM's absolute FPS reflects software rendering only; the Windows table is the one representative of real hardware, and only one laptop was measured.
- On Windows the headless CPU cost is higher than on the VM (normal 0.85 vs 0.77 ms, stress 2.93 vs 2.14 ms) — one run each on a 1.6 GHz-base laptop CPU, not investigated further.
- The 1% of frames at ~16–18 ms on Windows were not attributed (they appear in the normal and stress scenarios alike).
- Rare single-frame spikes (up to ~51 ms headless on the VM) were recorded but not attributed.
- Video memory saved by the smaller shadow atlas isn't visible in Godot's monitor on this renderer.

---

## 7. Build

### GitHub Actions (`.github/workflows/build.yml`)

| Trigger | Jobs |
|---|---|
| push / PR to `Development` or `main`, manual run | **Validate and test** (Godot 4.7.2 downloaded and SHA-512-verified → `validate.sh` → `run_tests.sh`) → **Export Windows x64** (`export_windows.sh`, uploads the build) |
| push of tag `vX.Y.Z` | the same, then **GitHub Release** with the zip and `docs/release-notes/vX.Y.Z.md` |

The export only runs if tests pass, and the release only if the export passes. The export step checks the `.exe` is a Windows (MZ) program, the main scenes are in the `.pck`, and no tests or tools were packed. No secrets: the release uses the job's `GITHUB_TOKEN`; default permissions are `contents: read`.

**First run:** [Build #1](https://github.com/SE2026-T10/CampusEscape3D-2/actions/runs/37272574230), commit `15b3ebf`, **success** in 5 m 03 s. Annotations: only GitHub's Node.js 20 deprecation warning for the `@v4` actions.

### Build artifact

| | |
|---|---|
| Name | `CampusEscape3D-1.0.0-windows-x64` |
| Contents | `CampusEscape3D.exe` (109,127,680 bytes), `CampusEscape3D.pck` (589,300 bytes), `README.txt` |
| Zip | 39,330,578 bytes; SHA-256 `06a855cc442f8989c5c67f11c3de8036d60b9bdb33c9d28fb8871e5c8c2d4aa7` — matches GitHub's artifact digest |
| Provenance | `README.txt` inside: commit `15b3ebffb830ff7bd1e5f846c619bbcee83724c5`, built 2026-10-05T06:33:01Z with `4.7.2.stable.official.ed1daf0bf` |
| Executed | yes, on Windows 10 — main menu and level (see Manual tests) |

### Release version

- Version **1.0.0**; release notes `docs/release-notes/v1.0.0.md`.
- **The `v1.0.0` tag has not been pushed yet**, so no GitHub Release exists. To publish (from `docs/BUILD.md`), after the documentation commit from this validation passes CI:

  ```
  git tag -a v1.0.0 -m "Campus Escape 3D 1.0.0 (MVP)"
  git push origin v1.0.0
  ```

---

## 8. Release validation checklist

| Requirement | Verdict | Evidence |
|---|---|---|
| AI state tests | **Present and passing** | `tests/ai_state_tests.gd` (17 unit tests, 2,000-step storm), `tests/ai_behavior_tests.gd`; passed on CI and on Windows |
| Profiler evidence | **Present (instrumented benchmark)** | `docs/performance/` raw per-frame data, charts, diagnostics, `docs/performance/windows/`; no editor Profiler screenshots |
| Level-design versioning | **Present as evidence folders**; not as per-version git commits | `docs/level/v0`–`v4`, `LEVEL_LOG.md` (caveat added) |
| Automated build | **Present and green** | `.github/workflows/build.yml`, Build #1 success, artifact verified |
| README complete | yes, after corrections (CI status, badge owner, commit claim, testing limits) | `README.md` |
| Repository clean | yes: working tree clean before validation; `.godot/`, `build/`, `dist/`, `ci-logs/` ignored; no editor caches tracked | `git status`, `.gitignore` |
| No temporary debug files | none: no `.tmp/.bak/.log/.orig`; no stray `print()` in runtime scripts; `*debug*` files are the intentional F3 overlays (freed in release builds via `OS.is_debug_build()`) and evidence screenshots | `git ls-files` scan |
| No secrets | none found in the tree or full history (API keys, tokens, private keys, `.env`) | pattern scan of `git grep` and `git log -p --all` |
| No fabricated evidence | headline numbers match raw `summary.json`; test logs reproduce on Windows. Two inaccurate claims corrected: per-version `level(vN)` / `perf:` commits that are not in history, and "CI has not run" (it has, and passed) | this report §4, `LEVEL_LOG.md`, `phase-13-performance.md` notes |
| Clone and open by another developer | yes: fresh `git clone` of `Development` from GitHub on Windows, no `.godot/` cache — import exit 0 with no errors, `CHECK SCRIPTS PASSED (71 scripts)`. One hygiene issue found and fixed: with Windows' `core.autocrlf=true` the first import rewrote all 32 `.import` files from CRLF to LF, so a new clone showed 32 modified files. `.gitattributes` now has `* text=auto eol=lf` (git already stored everything as LF); re-tested: 0 modified files after import | `.gitattributes` |
| Final Windows build executes | yes: CI artifact (hash-verified) runs on Windows 10 and loads the level | `docs/release/v1.0.0/` |

**Outstanding before calling the MVP fully released:** push the `v1.0.0` tag; complete the manual Part 2 checklist on Windows (audio by ear, feel, difficulty).
