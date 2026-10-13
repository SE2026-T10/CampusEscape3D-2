# Expanded Library — Phase 7: Final QA, Performance and Release (1.1.0)

The release check for version **1.1.0**: the tutorial plus the Expanded Library. Release candidate: `484761d` ("Expanded library phase 5 + 6" on `Development`, including the door-frame fix) plus this phase's changes, listed at the end. Nothing was pushed from this phase; the maintainer commits and pushes.

**Short version:** every automated check passes on both maps, the Windows export contains both maps, and CI builds the artifact. What is still open is everything that needs Windows hardware or a person: launching the exported game, choosing both maps in it, playing the Expanded Library to the end, and the frame-rate targets. Those are listed below with exact steps. **Acceptance is therefore not complete:** see section 6.

## 1. Regression tests (automated)

Run on 2026-10-12 on the development VM with the CI scripts, on the release candidate with the version at 1.1.0. Logs: [`../qa/release_1_1/`](../qa/release_1_1/).

| Area | Covered by | Result |
|---|---|---|
| Project validity | `validate.sh`: exact Godot, clean import, 91 scripts compile, version 1.1.0 = preset 1.1.0.0 | **PASS** |
| AI states, vision, hearing (tutorial) | `ai_state_tests`, `ai_behavior_tests`, `vision_tests`, `hearing_tests`, `guard_tests` | **PASS** |
| AI, vision, hearing (Expanded) | `expanded_ai_tests`: six loops together with nothing stuck, vision through walls / shelves / slab / railing, hearing through walls and the slab, chase and loss, a chase up a stair, crossings in doors and on stairs | **PASS** |
| Navigation | `navigation_tests` (tutorial, saved bake = fresh bake); `expanded_graybox_tests` / `expanded_ai_tests` (both floors baked and sealed, every location reachable, each stair on its own, real-input route walks) | **PASS** |
| Objectives, access control | `objective_tests` (tutorial); `expanded_mission_tests`: the whole mission with real input, every bypass refused (card doors without the card, one-way doors from the wrong side, manuscript before card, exit before the back gate), closed doors block the player and sight | **PASS** |
| Checkpoints | `objective_tests`; `expanded_mission_tests`: captures before / after the card, after the manuscript, after the back gate, five in a row; mission state after each respawn equals the checkpoint snapshot | **PASS** |
| Game flow, scene changes | `game_flow_tests`; `qa_flow` (15 checks, real scene changes); `map_flow` (both maps chosen, restarted and left, 3 cycles, 52 checks, no node or connection growth) | **PASS** |
| Tutorial compatibility | Phase 1–14 tests unchanged and passing; `map_selection_tests`; the tutorial's benchmark scenarios unchanged | **PASS** |
| Performance tool | `performance_tests` (updated: both levels' scenarios, scenes, camera loops and noise points) | **PASS** |
| Export | `export_windows.sh` (strengthened: both maps and what they load must be in the pack) | **PASS** |

Suite line: `All tests passed (Phase 1 setup, … Expanded Library graybox, map selection, Expanded Library guards, Expanded Library mission).`; exactly the 8 expected warnings (broken setups built on purpose); no errors. Nothing failed.

**Tests added or changed in this phase:** `tests/performance_tests.gd` (the benchmark now has a level table; the test checks both). The export script's pack check now also requires `LevelCatalog`, both navmeshes, the Expanded Library's props and its door, decoration and book scripts.

## 2. Manual playtesting

| Check | Status | How it was covered so far |
|---|---|---|
| The game launches (editor) | covered by automation | `qa_flow` / `map_flow` start from the real main menu |
| Both maps selectable | covered by automation | `map_selection_tests`, `map_flow` (real menu buttons) |
| Tutorial playable to the end | covered by automation | `qa_playthrough` and `qa_flow` (real win screen) |
| Expanded Library completable | covered by automation | `expanded_mission_tests` (real input to the win screen); the playtester bot: 24 of 27 runs completed, the 3 failures are the deliberately reckless profile (`v4/playtests/summary.md`) |
| Gates work | covered by automation | `expanded_mission_tests` |
| Capture and checkpoint recovery | covered by automation | `expanded_mission_tests`, `objective_tests` |
| Menu, restart | covered by automation | `qa_flow`, `map_flow` |
| No softlocks | covered by automation, partly | every bypass and capture stage in `expanded_mission_tests`; no bot run stalled except the reckless profile, which is caught on purpose |
| **A person plays both maps on Windows** | **not done** | no Windows access and no human tester in this environment |

**Non-critical defects and observations** (none blocks play):
1. Stress benchmark: an added benchmark guard on a route shared with others is held up for about 5 s at the main stair (section 3). Known shared-route limitation; the level's own guards have one route each.
2. The playtester bot, which knows the routes, finishes the Expanded Library in 1:40–3:43. The 20–30 minute first completion is a target for a new human player and has not been measured.
3. The door-frame fix is in the scene file only; rebuilding the scene with the builder would bring the old frames back.

## 3. Performance

Full data: [`../performance/release_1_1/README.md`](../performance/release_1_1/README.md). Tool: `tools/benchmark.gd` (Phase 13), extended with `--level=expanded`.

**Environment:** Linux VM (Ubuntu 24.04), 2 vCPUs Intel Xeon 2.10 GHz, no GPU (Mesa llvmpipe), 1280×720, Compatibility renderer (OpenGL 3.3), Godot 4.7.2 debug build, vsync off.

| Scenario | Guards | Avg FPS (VM) | Frame ms mean | CPU only, ms per frame | Main cost |
|---|---|---|---|---|---|
| Tutorial normal | 3 | 9.3 | 107.2 | 0.81 | rendering (94 ms of software rasterising) |
| Expanded normal | 6 | 8.9 / 8.6 | 112.0 / 116.7 | 1.34 | rendering (98–102 ms) |
| Tutorial stress | 24 | 8.5 | 118.1 | 2.52 | rendering |
| Expanded stress | 24 | 7.9 / 7.8 | 127.2 / 128.5 | 2.50 | rendering (105 ms); guard AI 3.6 ms |

- The Expanded Library costs about 7% more per frame than the tutorial on the same machine; draw calls are similar (341 vs 302 normal, 550 vs 600 stress).
- Game logic is not a bottleneck: 24 guards take 2.5 ms of CPU per frame.
- Memory is flat (≤ 0.8 MB growth per run).
- No optimisation was needed or made in this phase. Phase 6's optimisations (batching, light budgets, shadow settings) are documented in `phase-6-visual-polish.md`.

**Targets (about 60 FPS normal, at least 45 FPS stress): NOT VERIFIED.** They apply to the Windows target, and the VM has no GPU. Reference only: the tutorial ran at 202.8 / 153.2 FPS on the v1.0.0 Windows laptop (`../performance/windows/`). The four Windows commands are in the performance README; each writes its results into `docs/performance/release_1_1/windows/`.

## 4. Level-design versioning

- All evidence folders `v0/`–`v4/` and `phase2/` are unchanged; this phase only added `docs/performance/release_1_1/` and `docs/qa/release_1_1/`.
- `LEVEL_LOG.md` claimed one `level(expanded-vN)` commit per version. That was wrong for `Development`, so it now maps each version to its real commit: v0 `cce1e9a`, v1 `3896e7c`, v2 `8dd2d63`, v4 `484761d`. v3 has no commit of its own (pushed with v4).
- Suggested tags (`expanded-v0` … `expanded-v4`, and `v1.1.0`) are listed in `LEVEL_LOG.md` and `BUILD.md`. None were created: only the maintainer pushes.

## 5. Build

| Check | Status | Evidence |
|---|---|---|
| CI validation and tests | **PASS** on `484761d` | GitHub Actions Build #5 (run 38188815204): Validate and test 11 m 59 s, Export Windows x64 42 s; builds #1–#5 all green. Annotations: Node.js 20 deprecation warnings only |
| Export includes both maps | **PASS** | local export of the release candidate: both level scenes, both navmeshes, `LevelCatalog`, props and scripts found in the `.pck`; now enforced by `export_windows.sh` |
| Usable artifact | **PASS** for `484761d` | Build #5 artifact `CampusEscape3D-1.0.0-windows-x64`, 37.6 MB. The 1.1.0 artifact will exist after the push; the local 1.1.0 zip is 38.5 MB |
| The `.exe` launches | **NOT VERIFIED** | needs Windows. Wine 9.0 on the VM crashes inside the Godot runtime at start-up, even headless, so it can't stand in |
| Both maps selectable in the exported build | **NOT VERIFIED** | needs Windows |

The workflow itself did not need changes; only `export_windows.sh` (which the workflow runs) gained the stricter pack check.

## 6. Acceptance

| Criterion | Result |
|---|---|
| Full automated regression on both maps | **PASS** |
| Manual playtesting list | **PARTIAL**: every item covered by automation; a human run on Windows not done |
| Performance profiled, normal and stress, both maps | **PASS** (on the VM) |
| 60 / 45 FPS targets measured | **NOT VERIFIED** (needs Windows) |
| Evidence and history preserved | **PASS** |
| CI validation and tests | **PASS** (Build #5) |
| Export contains both maps; artifact produced | **PASS** |
| Exported `.exe` launches; both maps selectable in it | **NOT VERIFIED** (needs Windows) |
| Documentation updated | **PASS** |
| **Overall** | **FAIL for now: not releasable until the Windows checks below pass.** Everything that can be checked without Windows passes |

**To close it (on the Windows laptop, after pushing these changes):**
1. Wait for the Build workflow on the pushed commit to go green; download `CampusEscape3D-1.1.0-windows-x64` from its Artifacts.
2. Unzip, run `CampusEscape3D.exe`. Expect the main menu with **Library Tutorial** and **Expanded Library**.
3. Play the tutorial to the exit; Main menu; play the Expanded Library to the loading dock (the regression checklist's Expanded rows list what to watch). Note the time of the first completion.
4. From the project folder, run the four benchmark commands in `docs/performance/release_1_1/README.md`. Pass: `fps_avg` about 60 or more in `expanded_normal`, 45 or more in `expanded_stress`.
5. If all pass, tag `v1.1.0` (`docs/BUILD.md`).

## 7. Known issues and limitations

- Windows launch, map selection in the exported build and Windows frame rates: not verified (above).
- No human playtests of the Expanded Library; the 20–30 minute target is unconfirmed.
- Stress benchmark: added guards on shared routes can stall about 5 s at the main stair (known shared-route limitation).
- The door-frame fix is not in the builder.
- The workflow's actions target Node.js 20 (deprecated by GitHub); runs pass with a warning.
- The `v1.0.0` tag was never pushed; no release exists on GitHub yet.
- Executable not code-signed; Windows x64 only.

## 8. Files changed in this phase

| File | Change |
|---|---|
| `tools/benchmark.gd` | `--level=tutorial|expanded`; per-level scenarios, camera loop and noise points; the tutorial's behaviour unchanged |
| `tests/performance_tests.gd` | checks both levels' benchmark data |
| `tools/ci/export_windows.sh` | the pack must contain everything both maps load |
| `project.godot`, `export_presets.cfg` | version 1.1.0 / 1.1.0.0 |
| `docs/performance/release_1_1/` | new: benchmark results (both maps, render and headless) and the Windows commands |
| `docs/qa/release_1_1/` | new: logs of the automated run |
| `docs/release-notes/v1.1.0.md` | new |
| `docs/expanded/phase-7-release.md` | new: this report |
| `README.md` | two maps, version, benchmark `--level`, performance, level history commits, known limitations, CI status, documentation list |
| `docs/BUILD.md` | version, export check, run time, release 1.1.0 steps |
| `docs/expanded/LEVEL_LOG.md` | real commits per version, suggested tags, door-frame fix note |
| `docs/qa/REGRESSION_CHECKLIST.md` | benchmark for both maps, exported-build row, Expanded performance rows, the 2026-10-12 run |
| `docs/FINAL_REPORT.md` | pointer to this report |
