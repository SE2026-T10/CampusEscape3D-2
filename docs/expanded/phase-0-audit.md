# Expanded Library — Phase 0: Repository Audit

Audit date: 2026-10-09. Audited working copy: `D:\gitclone\CampusEscape3D-2` (the user's computer), branch `Development`.
No project file was created, changed, staged or committed. Tests and the export were run on a separate checkout of the same commit in the cloud workspace.

---

## 1. Git state

| Item | Value |
|---|---|
| Current branch | `Development` (`.git/HEAD` → `refs/heads/Development`) |
| HEAD | `15b3ebf` "Phase 15: final report" (phatelab, 2026-10-05) |
| `origin/Development` | `15b3ebf`, so local is level with the remote |
| `main` | `177f42e` (local and remote) |
| Tags | none, locally or on the remote. **`v1.0.0` has not been created.** |
| Remote `origin` | `https://github.com/SE2026-T10/CampusEscape3D-2.git`. It was changed today; it was `phatelab/CampusEscape3D-2` before. `git ls-remote` shows the same refs. |
| Staged changes | none. The index (611 entries) matches HEAD's tree, with no merge conflicts. |

**Modified, not staged (7 files).** These are release-validation edits dated 2026-10-09:

| File | Change |
|---|---|
| `.gitattributes` | adds `* text=auto eol=lf` (all text files checked out with LF) |
| `README.md` | badge points to SE2026-T10; Windows performance table; CI Build #1 marked as passed; level-history wording |
| `docs/level/LEVEL_LOG.md` | note: the per-version `level(vN)` commits are not in history; all five versions arrived in `3320e45` |
| `docs/phase-13-performance.md` | Windows measurement addendum; note on the missing `perf:` commits |
| `docs/phase-15-build-pipeline.md` | status update: Build #1 passed, and the artifact was run on Windows |
| `docs/qa/REGRESSION_CHECKLIST.md` | adds the 2026-10-09 "Last run" row |
| `docs/release-notes/v1.0.0.md` | test-coverage wording |

**Untracked (22 files):**
- `docs/FINAL_REPORT.md`;
- `docs/performance/windows/`: 7 benchmark runs (render: normal r1–r3, stress r1–r2; headless: normal r1, stress r1), each with `frames.csv`, `summary.json` and, for render runs, `screenshot.png`;
- `docs/release/v1.0.0/exe_main_menu.png` and `exe_in_level.png`.

**Ignored:** `.godot/` (126 files).

**How this was checked.** This session has no shell on your computer. I read `.git/HEAD`, the refs and `.git/index` directly, and compared each index entry with the size and modification time of the file on disk. A file whose contents changed but whose size and modification time stayed the same would be missed. That is unlikely, but please confirm with `git status`.

**Recommendation (not done):** commit the release-validation files above, so the Expanded Library work starts from a clean tree. Note that committing the new `.gitattributes` rule may make Git renormalise line endings in other files.

### Documentation and release evidence already present

| Evidence | Where | Status |
|---|---|---|
| AI-state and navigation tests | `tests/ai_state_tests.gd`, `ai_behavior_tests.gd`, `navigation_tests.gd`, `guard_tests.gd` | present and passing (baseline below) |
| Profiler / performance | `docs/phase-13-performance.md`, `docs/performance/` (VM runs), `docs/performance/windows/` (Windows, untracked) | present; benchmark instrumentation, no editor Profiler screenshots |
| Level-design history | `docs/level/LEVEL_LOG.md`, `docs/level/v0`–`v4` | evidence folders exist, but **git holds all five versions in one commit (`3320e45`)** |
| Automated build | `.github/workflows/build.yml`, `tools/ci/*.sh`, `docs/BUILD.md` | your uncommitted docs record Build #1 (run 37272574230) as passed. **I could not verify this**: this session has no GitHub API access. |
| Exported artifact | your docs: `CampusEscape3D-1.0.0-windows-x64`, run on Windows 10 | screenshots untracked in `docs/release/v1.0.0/` |
| Phase docs | `docs/phase-1` … `phase-15`, `docs/qa/`, `docs/presentation/`, `docs/evidence/` | present |

The level-design history matters for the new map. The required GitHub evidence asks for meaningful level-design version history, and the tutorial only has it as folders. **The Expanded Library should get one commit per layout version.**

---

## 2. Project configuration

| Setting | Value | Check |
|---|---|---|
| Engine | `config/features = ("4.7", "GL Compatibility")`, `config/engine_version = "4.7.2 Stable [ed1daf0bf]"` | the binary used reports `4.7.2.stable.official.ed1daf0bf`; matches |
| Version | `config/version = "1.0.0"`; export preset `1.0.0.0` | consistent (`validate.sh` checks this) |
| Main scene | `res://scenes/ui/main_menu.tscn` | |
| Window | 1280×720, stretch `canvas_items` | |
| Autoloads | **none** | every system lives in the level scene |
| Input | `move_forward/backward/left/right` (WASD), `sprint` (Shift), `crouch` (C, Ctrl), `interact` (E), `pause` (Esc, P), `toggle_navigation_debug` (F3) | no `jump`, by design |
| Physics layers | 1 world, 2 player, 3 npc, 4 interactable | player mask = 1+3; guard mask = 1+2+3; vision sight mask = 1+2 |
| Rendering | `gl_compatibility` (desktop and mobile), directional shadow atlas 2048 | |
| Export | "Windows Desktop", `exclude_filter = "tests/*, tools/*"`, release export | |

**Compatibility issues found: none.** Validation and the import are clean. One minor item from your docs: the `@v4` actions in the workflow run on Node.js 20, which GitHub has deprecated. Runs still pass, with a warning.

---

## 3. Architecture (inspected, not only listed)

### 3.1 Scene structure of the tutorial

`scenes/level/library_graybox.tscn` (root `LibraryGraybox`, 626 nodes) contains every runtime system as a direct child:

```
LibraryGraybox (Node3D)
├─ WorldEnvironment, KeyLight, PreviewCamera (non-current)
├─ NavigationRegion3D  ← library_navmesh.tres (parses static colliders on layer 1)
│   ├─ Areas/ Entrance, MainRoom, ReadingArea, MainStacks, HallwayWest,
│   │         RestrictedStacks, BackCorridor, HallwayEast, ExitArea  (floors, walls, shelves)
│   ├─ Props/
│   └─ PlayerTestArea/
├─ NavigationDebug (F3 overlay, removed in release)
├─ Guards/ MainRoomRoute + GuardMain, RestrictedRoute + GuardRestricted, EastRoute + GuardEast
├─ Player (player.tscn)
├─ Gameplay/
│   ├─ ObjectiveManager, CheckpointManager
│   ├─ EnterLibraryTrigger, RestrictedStacksTrigger, ExitAreaTrigger (ObjectiveTrigger)
│   ├─ AccessCard, ExitDoor (+ Noise, Sign)
│   └─ CheckpointHallwayWest, CheckpointStaffNook (Checkpoint + Spawn/Pad/Label)
├─ StealthDirector, NoiseSystem
├─ StealthHud, ObjectiveHud, DetectionDebugHud, GameMenus (CanvasLayers)
├─ GameFlow
├─ AudioDirector, Ambience
└─ Dressing/ (props, signs, lights, ceilings, doorways, landmarks)
```

### 3.2 How the systems connect

- **Lookup.** Every manager adds itself to a group and exposes `static func find(node)`, which calls `get_first_node_in_group`. This applies to `stealth_director`, `noise_system`, `objective_manager`, `checkpoint_manager`, `game_flow` and `audio_director`. Scripts never use node paths to reach other systems. The only exception is `GameFlow.restart()`, which uses `owner`.
- **Connections** are made in deferred `_connect…()` calls after `_ready`, so order inside the scene does not matter.

| Signal / data | From | To |
|---|---|---|
| `player_caught`, `level_reset` | StealthDirector | GameFlow (CAUGHT ↔ PLAYING), CheckpointManager (restore progress) |
| `level_completed` | ObjectiveManager | GameFlow (WIN) |
| `objective_changed` / `objective_completed` | ObjectiveManager | ObjectiveHud, AudioDirector, AccessCard |
| `checkpoint_activated` / `respawned` | CheckpointManager | ObjectiveHud, AudioDirector |
| `rejected` | **ExitDoor only** (found by `is ExitDoor` in group `interactables`) | ObjectiveHud, AudioDirector |
| `state_changed` | GameFlow | GameMenus, AudioDirector |
| `receive(event)` | NoiseSystem → group `noise_listeners` | GuardHearing → `Guard.hear_noise()` |
| groups `player`, `guards`, `hiding_spots` | | StealthDirector, GuardVision, AreaUtils, HUD |

### 3.3 Systems

| System | Files | What it does | Tutorial coupling |
|---|---|---|---|
| **Main menu, scene loading** | `scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd`, `menu_style.gd` | UI built in code; `start_game()` calls `change_scene_to_file(LEVEL_SCENE)` once; `change_scene` and `quit_game` are replaceable for tests | `LEVEL_SCENE` const = tutorial; one Start button; tutorial tagline |
| **Player** | `player.tscn`, `player.gd`, `player_noise.gd`, `player_interactor.gd`, `player_feedback.gd` | CharacterBody3D: walk 3.5, sprint 5.5, crouch 1.8 m/s; capsule 0.35 × 1.8; `set_spawn_transform` / `respawn`; `fall_limit_y = -10`; visibility points follow crouch | none. **No step-up logic**, so stairs must be ramp colliders |
| **Interaction** | `interactable.gd`, `player_interactor.gd` | camera ray, 2.2 m reach, on layer 4; walls block it; prompts | none |
| **Guard actor** | `guard.tscn`, `guard.gd` | NavigationAgent3D (r 0.4, h 1.8, avoidance); horizontal-only steering; stuck after 5 s → skip point; `reset_to_start()` | none |
| **AI** | `scripts/npc/ai/*` | `GuardStateMachine`: exactly PATROL / INVESTIGATE / CHASE, explicit `ALLOWED` table, priority rules | none |
| **Vision** | `guard_vision.gd` | 90° cone, 14 m, 3D distance; rays on mask world+player; 0–100 meter, SUSPICIOUS 30 / ALERTED 100 | none. A floor slab blocks sight, but a stairwell or atrium opening does not. |
| **Hearing** | `guard_hearing.gd`, `noise_*.gd` | 3D distance against the event radius (WALK 5, RUN 12, INTERACTION 8 m); any layer-1 hit halves the radius ("wall"); the estimate is offset horizontally | none, but **a floor counts as a wall**. A sprint (12 m → 6 m) can be heard by a guard directly below. |
| **Navigation** | `NavigationRegion3D` + `library_navmesh.tres`, `navigation_utils.gd`, `tools/bake_navigation.gd` | one baked region, default cell 0.25, agent height 1.75, `region_min_size` 8; `wait_for_navigation()` before guards start | navmesh resource and bake tool are tutorial-specific |
| **Patrols** | `patrol_route.gd`, `patrol_point.gd` | ordered Marker3D children, per-point wait time, loop flag | none |
| **Hiding** | `hiding_spot.gd` | Area3D (layer mask player), group `hiding_spots`; no invisibility, the carrel geometry blocks sight; HUD shows HIDDEN when crouched, inside and unseen | none |
| **Detection meter, status** | `stealth_director.gd`, `stealth_hud.gd` | status priority CHASE > SPOTTED > INVESTIGATING > HIDDEN; HUD meter follows the most aware guard | `is_catching` uses **horizontal distance only** (1.2 m) and needs sight, so there is no vertical check |
| **Objectives** | `objective_manager.gd`, `objective_trigger.gd` | ordered list LOCKED / ACTIVE / COMPLETED; `setup(array)` is data-driven; `get_progress` / `restore` | `_ready()` falls back to the const `MVP_OBJECTIVES` (5 tutorial objectives), with **no per-level export**; ids are consts |
| **Access card** | `access_card.gd` | interactable that completes `objective_id` (default TAKE_CARD) while that objective is ACTIVE; there is **no inventory**: "has card" means the objective is completed | prompt text is fixed ("Take the access card") |
| **Doors** | `exit_door.gd` | Area3D interactable; escapes when the ESCAPE objective is active; rattles (noise) and emits `rejected` otherwise; tints and signs | **only an exit door exists.** There is no locked door that physically blocks a passage. |
| **Checkpoints** | `checkpoint.gd`, `checkpoint_manager.gd` | geometric activation; stores the spawn plus an **objective-progress snapshot**; disabled during chase, caught and escaped; on reset restores progress (the card goes back on the desk) | none, but the snapshot covers **objectives only** |
| **Game flow, pause** | `game_flow.gd`, `game_state_machine.gd`, `game_menus.gd` | PLAYING / CAUGHT / PAUSED / WIN with an `ALLOWED` table; pauses the tree; mouse mode; `restart()` reloads `owner.scene_file_path`; focus-loss pause | win text "…out of the library with the access card"; `restart()` relies on `owner` being the level root |
| **HUD** | `objective_hud.gd`, `stealth_hud.gd`, `detection_debug_hud.gd` | "OBJECTIVE n/N" counted from the manager; messages; prompts | listens to `ExitDoor.rejected` by class |
| **Audio** | `audio_director.gd`, `sound_bank.gd`, `ambient_emitter.gd`, `guard_presentation.gd` | buses, chase/tension music, stings; 32 generated sounds | card sound tied to `ObjectiveManager.TAKE_CARD`, finish to `ESCAPE` |
| **Tests** | `tests/test_scene.tscn` + 15 test modules | custom runner: each module returns failure strings; exit 0/1; no assert() | ~16 files hardcode `library_graybox.tscn` |
| **Tools** | `tools/benchmark.gd`, `level_report.gd`, `level_compare.gd`, `capture_*.gd`, `qa_flow.gd`, `bake_navigation.gd` | benchmark (normal/stress), level metrics and maps, flow run | all tutorial-specific paths |
| **CI** | `.github/workflows/build.yml`, `tools/ci/*.sh` | validate → tests (timeout 1200 s) + qa_flow (600 s) → Windows export → artifact; release on `v*.*.*` tags | the export check expects the tutorial's scenes in the pack |

---

## 4. Integration requirements for a second map

### 4.1 Already multi-level ready
- **No autoloads, everything per scene.** `change_scene_to_file` frees the whole old level, managers included, so there are no global duplicates and no stale references, provided each level contains exactly one of each manager.
- **`GameFlow.restart()` reloads the scene it belongs to**, so Play again and Restart return to the same map automatically, but see the risk in 4.3.
- **The objectives are data**: `ObjectiveManager.setup()` takes any list, and the HUD's n/N is computed.
- **Checkpoints, triggers, cards and the exit door are generic**: any number, configured through exports (`objective_id`, `key_objective_id`, `checkpoint_name`, Spawn marker).
- **Guards, routes, vision, hearing and hiding spots** are configured per instance.
- **`AreaUtils` box checks are 3D** (they include y), so triggers and checkpoints work on an upper floor.
- **Scripts don't depend on node paths** (`get_node` paths are used only for the node's own children).

### 4.2 Hardcoded to the tutorial (needs a change)

| # | Item | Smallest change |
|---|---|---|
| H1 | `MainMenu.LEVEL_SCENE`, single Start button | a map list; keep `start_button` / `start_game()` = tutorial, so the existing tests and `qa_flow` stay valid; add a second button and `start_level(path)` |
| H2 | `ObjectiveManager` falls back to `MVP_OBJECTIVES`, with no way to set a list from the scene | add an exported objective list (empty = MVP default, so the tutorial is unchanged) |
| H3 | No blocking locked door, only `ExitDoor` (non-blocking Area3D) | new `AccessDoor` interactable with a blocking body, unlocked by a completed objective; reuses `Interactable`, `NoiseMaker` and `rejected` |
| H4 | HUD and audio only hear `ExitDoor.rejected` | match any interactable with a `rejected` signal (behaviour unchanged for the tutorial) |
| H5 | Checkpoint snapshot covers objectives only | if every door and key is tied to an objective, nothing else needs saving. Optional shortcuts with their own state would need the snapshot extended. **Recommendation: shortcuts are one-way (opened from the far side) and stay open, so no extra save state.** |
| H6 | `GameFlow.restart()` uses `owner.scene_file_path` | if the shared systems become a sub-scene (4.3), `owner` would be that sub-scene; use the level root (`get_tree().current_scene`) and keep the fallback |
| H7 | `bake_navigation.gd`, `benchmark.gd`, `level_report.gd`, `capture_views.gd`, `qa_flow.gd` hardcode the tutorial | add a `--level=` argument, defaulting to the tutorial |
| H8 | Win and menu texts mention the tutorial's card | win text from the level (exported string), default = current text |
| H9 | AudioDirector plays the card sound only for id `take_card` | reuse the `take_card` id for the new map's card objectives where it fits, or add an exported "pickup objectives" list; decide in Phase 3 |

### 4.3 Avoiding duplicate managers and stale references

The tutorial embeds about 12 system nodes. Copying them into a second scene by hand duplicates configuration that would drift over time.

**Proposal:** a shared sub-scene `scenes/level/level_runtime.tscn` containing:
- StealthDirector, NoiseSystem, GameFlow, GameMenus, StealthHud, ObjectiveHud, DetectionDebugHud, AudioDirector.

The Expanded Library instances it once. `ObjectiveManager` and `CheckpointManager` stay in each level's `Gameplay/`, because they carry level data. **The tutorial keeps its inline nodes untouched**, so it isn't at risk; migrating it later is optional.

Guards against duplicates and stale references:
- a test that loads each level and asserts **exactly one** node in each manager group;
- a test that changes level → menu → other level and checks that the old level's managers are freed (`is_instance_valid` is false) and that each group has exactly one node.

**Critical dependency:** H6 must land with the sub-scene. Otherwise Restart in the new map would load the runtime sub-scene on its own.

---

## 5. Tests and CI baseline (run today)

Environment: Linux cloud VM, headless, Godot `4.7.2.stable.official.ed1daf0bf` (official Linux build, checksum-verified). Checkout of `15b3ebf`, the same code as your working copy; your uncommitted changes are documentation only.

| Command | Result | Time |
|---|---|---|
| `bash tools/ci/validate.sh` | `CHECK SCRIPTS PASSED (71 scripts)`, `VALIDATION PASSED`, exit 0 | 8 s |
| `bash tools/ci/run_tests.sh` (full suite + `qa_flow`) | `All tests passed (Phase 1 … Phase 14 QA)`; `QA FLOW PASSED (15 checks, 4 levels loaded)`; exit 0; exactly the 8 expected warnings (GuardA/B and VisionTestGuard: no navmesh / no route; NoRouteGuard: no route; StuckGuard: stuck) | 232 s |
| `bash tools/ci/export_windows.sh` | `EXPORT PASSED`: `.exe` 109,127,680 B, `.pck` 589,300 B, zip 38.4 MB | 17 s |

**Not run here:**
- **Windows:** this session has no Windows machine.
- **The editor UI:** this session has no display or editor.
- **The GitHub Actions status:** this session has no GitHub API access.
- **The benchmark:** it measures performance, which is not part of this audit.

Other commands available (from `docs/BUILD.md` and `REGRESSION_CHECKLIST.md`):

```
godot --headless --path . res://tests/test_scene.tscn                    # A1 suite
godot --path . --script res://tools/qa_flow.gd -- --out=docs/qa/flow_x   # A2 flow
godot --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --scenario=normal|stress --out=…   # A3
godot --path . --resolution 1280x720 --script res://tools/capture_views.gd -- --out=…                        # A4
godot --headless --path . --script res://tools/bake_navigation.gd        # navmesh rebake
```

**CI budget:** the suite takes 232 s against a 1200 s timeout. New Expanded Library tests must stay targeted. Real-time playthroughs of a 20–30 minute level cannot run in CI, so the route check uses a guard-free walk, as `qa_playthrough_tests` already does.

---

## 6. Technical risks and mitigations

| # | Risk | Impact | Mitigation |
|---|---|---|---|
| R1 | `GameFlow.restart()` reloads the wrong scene once systems sit in a sub-scene | Restart and Play again break on the new map | H6 fix + test "restart requests the expanded scene" |
| R2 | Duplicate or stale managers (a copied node, or a sub-scene instanced twice) | `find()` returns the first match; mixed signals | one-of-each test per level; level-change test |
| R3 | Stairs: the player has no step-up; the default navmesh climb is 0.25 m | player or guards stuck on steps | **ramp colliders ≤ 30°** with visual steps on top (not on layer 1); navigation test that walks floor 1 → floor 2 |
| R4 | Two-floor navmesh: a wrong cell height, or ceiling clearance under 1.75 m, merges or cuts floors | guards path through floors or can't reach floor 2 | floor-to-floor ≥ 4 m, slab ≥ 0.3 m; tests: path ground → upper exists **and goes via a stair**, closest-point queries snap to the right floor |
| R5 | Hearing through floors: a slab counts as one "wall", so a sprint upstairs is heard 6 m below | guards investigate the wrong floor; long detours | decide with you: (a) accept (realistic, measurable) or (b) a floor attenuation factor. Either way a test pins the behaviour |
| R6 | `StealthDirector.is_catching` ignores height | a caught signal across a stairwell or atrium edge | add a vertical limit (≤ 1.5 m). Tutorial behaviour is unchanged (single floor); needs your approval as a core-system change |
| R7 | Vision through atrium and stair openings (3D cone) | guards on floor 2 see the player on floor 1 | intended stealth gameplay, but must be tuned; railings / half-walls on layer 1 where line of sight is unwanted |
| R8 | Locked doors versus guards: a blocking door on layer 1 is baked into the navmesh, cutting guard routes | patrols break | blocker on a **new physics layer 5 "access_door"** that only the player collides with (guards have keys); the navmesh ignores it. Vision must still be blocked by a closed door: add layer 5 to `sight_mask` in the new level's guards. Approval needed (new layer). |
| R9 | Progress lost on capture in a 20–30 minute map | frustration | a checkpoint after each objective and at each zone entry; key items tied to objectives so restore stays consistent (H5) |
| R10 | 20–30 minute target can't be proven by automation | acceptance ambiguity | automated: route length and walk time without guards, every objective reachable; target confirmed by **timed human playtests**, recorded in docs |
| R11 | Performance: about 3× the geometry and 8–10 guards | FPS drop on the MX130 | the Phase 13 stress run (24 guards) is already 153 FPS on Windows; benchmark `--level=expanded` in the profiling phase; occlusion and visibility ranges only if measured to help |
| R12 | Test and CI time growth | CI over its timeout | new tests in their own module; no long real-time runs; watch the suite time |
| R13 | Tutorial regression from shared-code edits (H2, H4, H6, R6) | breaks the MVP | each edit defaults to current behaviour; the full existing suite and `qa_flow` must stay green in every phase |
| R14 | Large `.tscn` edits are hard to review and merge (the tutorial is 3,239 lines) | poor version history | build the new map from sub-scenes per zone (`scenes/level/expanded/zone_*.tscn`) and commit per layout version |

---

## 7. Proposed file and scene structure

```
scenes/level/
  library_graybox.tscn                   (unchanged)
  level_runtime.tscn                     NEW  shared systems sub-scene (4.3)
  expanded_library.tscn                  NEW  root: env, light, NavigationRegion3D, Guards, Player, Gameplay, LevelRuntime
  expanded_library_navmesh.tres          NEW  baked, two floors
  expanded/                              NEW  one sub-scene per zone, instanced under NavigationRegion3D
    zone_lobby.tscn, zone_reading_hall.tscn, zone_media_wing.tscn,
    zone_mezzanine_stacks.tscn, zone_rare_archive.tscn, zone_staff_wing.tscn,
    stair_*.tscn                         ramp collider + visual steps
scenes/props/access_door.tscn            NEW
scripts/game/level_catalog.gd            NEW  const list: id, title, description, scene path (data, not a manager)
scripts/systems/objectives/access_door.gd NEW
scripts/ui/main_menu.gd                  CHANGE  map selection
scripts/systems/objectives/objective_manager.gd  CHANGE  exported list (default MVP)
scripts/game/game_flow.gd                CHANGE  restart via level root
scripts/ui/objective_hud.gd, scripts/presentation/audio_director.gd  CHANGE  generic `rejected`
scripts/systems/stealth_director.gd      CHANGE (if R6 approved)
tests/level_framework_tests.gd           NEW  menu, catalog, one-of-each, restart, level change
tests/expanded_navigation_tests.gd       NEW  floors, stairs, zones reachable, sealed
tests/expanded_mission_tests.gd          NEW  5 objectives, doors, checkpoints, route walk
tests/expanded_ai_tests.gd               NEW  patrols complete, cross-floor perception rules
tools/*.gd                               CHANGE  --level= argument
docs/expanded/LEVEL_LOG.md + v0…vN/      NEW  per-version evidence, one commit per version
```

**Preliminary zone layout.** This is a proposal for you to approve in the layout phase:

| Floor | Zone | Role |
|---|---|---|
| Ground | 1. Lobby & Circulation | start, first checkpoint, staff office (key 1) |
| Ground | 2. Reading Hall (double-height atrium) | central hub, open sight lines to the mezzanine above |
| Ground | 3. Media & Periodicals wing | side route, carrels to hide in, a one-way shortcut back to the lobby |
| Upper | 4. Mezzanine Stacks | overlooks the atrium; main route; tall shelves |
| Upper | 5. Rare Books Archive (access-controlled) | key 1 to enter; mission item |
| Upper | 6. Staff Wing & Server Room (access-controlled) | key 2; staff stair down to the exit |

- **Stairs:** at least two staircases (a public stair in the hall, a staff stair in the staff wing), plus a service lift area as decoration.
- **Mission:** five mandatory objectives, for example: get the staff keycard → enter the archive → take the manuscript → reach the staff wing → escape via the loading dock.
- **Shortcuts** open from the far side and stay open.

---

## 8. Implementation phases (each waits for approval)

| Phase | Content | Depends on | Evidence |
|---|---|---|---|
| **1. Level framework** | `level_catalog.gd`; main-menu map selection; `level_runtime.tscn`; H2, H4, H6, H8; a stub `expanded_library.tscn` (floor, player, runtime) so selection is testable; `--level` in the bake and flow tools | — | `level_framework_tests`; full suite + `qa_flow` green |
| **2. Graybox v0: layout** | six zones on two floors, ramp stairs, routes and shortcuts as openings; two-floor navmesh; `level_report --level` metrics and map; commit `level(expanded-v0)` | 1 | `expanded_navigation_tests` (floor 1 ↔ 2 via stairs, every zone reachable, sealed, nav-mesh snapshot), maps and screenshots |
| **3. Mission and access (v1)** | `AccessDoor` (layer 5, approval), 5 objectives, keys, checkpoints, shortcuts | 2 | `expanded_mission_tests`: flow rules, door rejects and unlocks, checkpoint restore, guard-free route walk with real input |
| **4. Guards and hiding (v2)** | routes (8–10 guards, planned), hiding spots, sight-blocking pass; R5 and R6 decisions | 3 | `expanded_ai_tests` (patrol loops, no stuck events in an N-minute soak, cross-floor rules); AI-state tests unchanged |
| **5. Balancing (v3)** | tuning toward 20–30 minutes | 4 | metrics comparison v2 → v3; **human playtest times** (manual) |
| **6. Art and presentation (v4)** | low-poly dressing, lights, signage, ambience | 5 | view captures; presentation tests |
| **7. Performance, QA, release** | `benchmark --level=expanded`, profiling, regression checklist, CI including the new tests, the export, and a `v1.1.0` tag | 6 | benchmark runs (VM + Windows), green CI run, artifact |

---

## 9. Decisions needed before Phase 1

1. **Shared systems sub-scene** (`level_runtime.tscn`) for the new map, with the tutorial left inline. This is an architectural change.
2. **Edits to shared scripts**, each defaulting to current behaviour: ObjectiveManager export (H2), generic `rejected` (H4), the GameFlow restart root (H6), the level win text (H8).
3. **Menu design:** keep "Start game" for the tutorial and add an "Expanded Library" button, or a two-step "Start → choose map" screen. The first keeps every existing menu test unchanged.
4. **Later (Phases 3–4):** physics layer 5 for access doors (R8), the vertical catch limit (R6), hearing through floors (R5).
