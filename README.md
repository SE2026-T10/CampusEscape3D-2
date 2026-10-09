# Campus Escape 3D

[![Build](https://github.com/SE2026-T10/CampusEscape3D-2/actions/workflows/build.yml/badge.svg?branch=Development)](https://github.com/SE2026-T10/CampusEscape3D-2/actions/workflows/build.yml)

## Project description

Campus Escape 3D is a low-poly, first-person 3D stealth game set in a university library at night. You sneak into the library, take an access card from the Restricted Stacks and get out through the exit. Three guards stand in your way, and they patrol, see, hear, investigate and chase.

The MVP is one polished level, built in Godot with GDScript, for Windows desktop. The current version is **1.0.0** (`application/config/version` in `project.godot`).

## Godot version

- **Engine:** Godot **4.7.2 Stable**, official build (`4.7.2.stable.official.ed1daf0bf`). Other versions are not supported. The test suite and the build pipeline both check the exact version.
- **Language:** GDScript.
- **Renderer:** Compatibility (OpenGL).
- **Target:** Windows desktop (x86_64).

## Installation

**To play:** download `CampusEscape3D-<version>-windows-x64.zip`, either from the repository's GitHub Releases or from a workflow run's artifacts (see Automated build). Unzip it anywhere and run `CampusEscape3D.exe`; keep `CampusEscape3D.pck` in the same folder. Nothing else needs installing. The executable is not code-signed, so Windows SmartScreen may ask for confirmation the first time.

**To develop:**
1. Install [Godot 4.7.2 Stable](https://godotengine.org/download/archive/4.7.2-stable/).
2. Clone the repository.
3. Import `project.godot` in the Godot Project Manager.

## How to run

- **From the editor:** open the project and press **F5**. The game starts on the main menu. Choose a map:
  - **Library Tutorial**: the original level, with its full mission.
  - **Expanded Library**: the two-floor map. Graybox with six patrolling guards; there is no mission yet.
- **Straight into a level** while developing: open `scenes/level/library_graybox.tscn` or `scenes/level/expanded_library.tscn` and press **F6**.
- **Exported build:** run `CampusEscape3D.exe`.

## Controls

| Action | Key |
|---|---|
| Move | **W A S D** |
| Sprint | hold **Shift** |
| Crouch (quieter, harder to see, slower) | hold **C** or **Ctrl** |
| Use (take the access card, open the exit) | **E** |
| Look | mouse |
| Pause / resume (shows the cursor and the pause menu) | **Escape** or **P** |
| Debug view: navigation, guard paths, routes, vision cones, detection, AI state, noise rings and hearing estimates (debug builds) | **F3** |

There is no jump: the library has no vertical routes, and jumping onto shelves would let the player skip sections or climb out. All keys are defined in **Project Settings → Input Map**.

## How to build

The full build and release guide is **[`docs/BUILD.md`](docs/BUILD.md)**.

**From the editor (Windows):**
1. Install the 4.7.2 export templates: Editor → Manage Export Templates.
2. Project → Export → **Windows Desktop** → Export Project → `build/CampusEscape3D.exe`, with debug unticked.
3. Ship `CampusEscape3D.exe` and `CampusEscape3D.pck` together.

**From a terminal (Linux or WSL), the same scripts the CI runs:**

```
export GODOT="$(bash tools/ci/setup_godot.sh | tail -n 1)"   # downloads Godot 4.7.2 + Windows templates, checksums verified
bash tools/ci/validate.sh        # exact Godot version, clean import, every script compiles, version numbers
bash tools/ci/run_tests.sh       # full test suite + game-flow run (about 4 minutes)
bash tools/ci/export_windows.sh  # → dist/CampusEscape3D-<version>-windows-x64.zip
```

## Automated build

GitHub Actions (`.github/workflows/build.yml`) runs on:
- every push to `Development` or `main`;
- every pull request into them;
- version tags `vX.Y.Z`;
- a manual **Run workflow**.

| Job | Steps | Result |
|---|---|---|
| Validate and test | set up Godot 4.7.2 (SHA-512 verified) → `validate.sh` → `run_tests.sh` | fails the workflow on any validation error, compile error, failing test or failed flow run |
| Export Windows x64 | only if the first job passed: set up → validate → `export_windows.sh` | uploads `CampusEscape3D-<version>-windows-x64` as a workflow artifact (30 days) |
| GitHub Release | tags only, only if the export passed | creates the release with the zipped build and `docs/release-notes/<tag>.md` |

**No secrets:** none are used or stored; the release uses the workflow's own `GITHUB_TOKEN`.

**Release process:** bump the version → write release notes → push to `Development` → green run → tag `vX.Y.Z` → push the tag. Details are in `docs/BUILD.md`. The MVP release is tag **`v1.0.0`**.

## Architecture

Each map is one level scene with its gameplay systems as nodes in it; the main menu picks the map from `LevelCatalog`, and leaving a map frees it with all its systems (there are no autoloads). Systems find each other through groups (`StealthDirector.find(node)` and similar), and talk through signals. Presentation code (sound, animation, UI) only listens to the gameplay code and never changes it.

```
scenes/ui/main_menu.tscn                 main scene: one button per map (LevelCatalog) / Quit
scenes/level/expanded_library.tscn       the Expanded Library (graybox; same runtime systems, no mission yet)
scenes/level/library_graybox.tscn        the Library Tutorial
├── NavigationRegion3D (+ library_navmesh.tres)   rooms, walls, shelves, furniture, carrels (HidingSpot)
├── Player (scenes/player/player.tscn)   FirstPersonPlayer + PlayerNoise + PlayerInteractor + PlayerFeedback
├── Guards                               PatrolRoute/PatrolPoint markers + Guard instances (scenes/npc/guard.tscn)
├── Gameplay                             ObjectiveManager, triggers, AccessCard, ExitDoor, CheckpointManager, Checkpoints
├── StealthDirector                      overall stealth status, catching, level reset
├── NoiseSystem                          noise events → guards' hearing
├── GameFlow                             game state PLAYING / CAUGHT / PAUSED / WIN, pause, restart, scene changes
├── StealthHud, ObjectiveHud, GameMenus  player-facing UI
├── AudioDirector, Ambience              music, stings, UI sounds, room tone, positional ambience
├── Dressing                             decoration only (no collision): signs, books, lights, props
└── NavigationDebug, DetectionDebugHud   F3 debug overlays (removed from release builds)
```

| Folder | Contents |
|---|---|
| `scripts/player/` | `FirstPersonPlayer` (movement, crouch, look, respawn), `PlayerNoise` (footstep noise), `PlayerInteractor` (E-key ray) |
| `scripts/npc/` | `Guard` (navigation, movement, perception snapshot), `GuardVision`, `GuardHearing`, `PatrolRoute`, `PatrolPoint` |
| `scripts/npc/ai/` | `GuardStateMachine` with `PatrolState`, `InvestigateState`, `ChaseState`; `GuardPerception` |
| `scripts/systems/` | `StealthDirector`, `HidingSpot`, objectives, checkpoints, interaction, noise, debug overlays |
| `scripts/game/` | `GameFlow`, `GameStateMachine`, `LevelCatalog` (the maps the menu offers) |
| `scripts/ui/` | `MainMenu`, `StealthHud`, `ObjectiveHud`, `GameMenus`, `MenuStyle` |
| `scripts/presentation/` | `AudioDirector`, `SoundBank`, `PlayerFeedback`, `GuardPresentation` (model animation), `AmbientEmitter` |
| `scripts/level/` | `ShelfBooks` (generated book MultiMeshes) |
| `tests/` | the automated test suite |
| `tools/` | level, benchmark, capture, QA and CI tools (excluded from the export) |

**Physics layers:**
1. world
2. player
3. npc
4. interactable

## AI states

Each guard runs an explicit state machine (`scripts/npc/ai/guard_state_machine.gd`) with three states. The tutorial has three guards; the Expanded Library has six, with the same scene and AI.

| State | Behaviour |
|---|---|
| **PATROL** | walks its looping route with `NavigationAgent3D`, waiting at each point |
| **INVESTIGATE** | walks to where it saw something suspicious or *thinks* it heard a noise, searches there (looking around) for 6 s, then returns to patrol |
| **CHASE** | runs after the player while it can see them; on losing sight it investigates the last known position |

**Transitions.** They are checked every physics tick in this priority order; the first that applies wins:

| # | Trigger | Transition |
|---|---|---|
| 1 | confirmed sighting (meter at 100 and the player visible) | PATROL / INVESTIGATE → CHASE |
| 2 | suspicious sighting (meter ≥ 30) | PATROL → INVESTIGATE, at the sighting |
| 3 | noise heard | PATROL → INVESTIGATE, at the estimated position |
| 4 | search timed out | INVESTIGATE → PATROL |
| 4 | lost sight | CHASE → INVESTIGATE |

Any other transition (for example CHASE → PATROL) is rejected.

**Perception:**
- **Vision:** a 90° cone reaching 14 m, blocked by walls and tall shelves.
- **Detection meter:** 0–100. It fills faster up close and drains when the player is out of sight; SUSPICIOUS at 30, ALERTED at 100.
- **Hearing:** walking is heard within about 5 m and sprinting within about 12 m; walls halve those distances. The guard's position estimate is always off, more so with distance.
- **Crouching:** halves how fast the meter fills and makes footsteps very quiet.
- **Carrels:** crouching inside one blocks sight from the sides and back.

## The game

The library level (`scenes/level/library_graybox.tscn`; the file name is kept from the graybox so references stay stable) is one small low-poly university library:

- **Entrance:** spawn, with a red rug, plants and a notice board.
- **Main Library Room:** four tall bookcases on the west side; on the east, a **Reading Area** with tables, green lamps, low 1.2 m bookcases (crouch cover) and the circulation desk with a globe. A wall clock on the north wall faces the entrance.
- **Hallway West** to the **Restricted Stacks** (the objective area: red carpet, red RESTRICTED signs on both doors, and the access card under a spotlight on the archive desk).
- **Back Corridor** with book carts and the **Staff Nook** checkpoint.
- **Hallway East** with a **study alcove** carrel.
- **Exit Area**, guarded, with crates, a rack and the exit door.

There are two routes to the card (west via Hallway West, east via Hallway East and the back corridor) and two ways from the card to the exit. Green EXIT signs mark both escape routes. How the level got here, with measurements and before/after pictures for each version, is in `docs/level/LEVEL_LOG.md`.

Three **guards** (dark blue) patrol the main room, the restricted stacks and the exit area (GuardEast is the exit warden). Each walks its own looping route with `NavigationAgent3D` and pauses at every patrol point. Guards **see**: each has a 90° vision cone reaching 14 m, blocked by walls and shelves. While a guard can see you, its detection meter (0–100) fills: fast up close, slowly at long range. Once you're out of sight it drains again. At 30 the guard becomes SUSPICIOUS, at 100 ALERTED. It remembers where it last saw you, and nothing else. Each guard runs an explicit state machine with three states:

- **PATROL:** walks its route.
- **INVESTIGATE:** walks to where it saw something suspicious (meter ≥ 30) or heard a noise, then searches there for 6 s before going back to patrol.
- **CHASE:** runs after you once the meter is full and it can see you. If it loses sight, it heads to where it last saw you and investigates there.

Guards also **hear**:

- Walking makes quiet footsteps, heard within about 5 m.
- Sprinting makes loud ones, heard within about 12 m.
- Walls halve those distances.
- A guard that hears you investigates where it *thinks* the noise came from. That estimate is always somewhat off, and the further away the noise, the worse the guess.

Seeing you always outranks hearing you, and a chasing guard ignores noise.

Crouching halves how fast a guard's meter fills, makes you a smaller target and makes your footsteps very quiet (about 2 m), at the cost of speed. Five **study carrels** (desk booths with 1.4 m panels) are hiding spots: crouch inside one and the panels block sight from the sides and back. Standing, your head shows over them.

**Detection UI.** A banner at the top tells you the most urgent situation: **CHASED — break line of sight!** (red), **YOU ARE BEING SEEN** (orange), **A guard is investigating** (yellow) or **HIDDEN** (blue). Triangles around the crosshair point to each guard that is noticing, investigating or chasing you, including guards behind you. Guards show a `?` or `!` above their heads. The bottom-left line shows your stance and noise level.

**Goal.** The objective panel (top right) walks you through the level:

1. Enter the library.
2. Reach the Restricted Stacks.
3. Take the access card from the archive desk at the back of the stacks (look at it and press **E**).
4. Reach the exit.
5. Escape through the exit door (**E**).

Objectives complete in order. The exit door stays locked (red) until you have the card. Trying it anyway rattles the door, which nearby guards can hear.

**Checkpoints.** Step onto a checkpoint pad (Hallway West, and the Staff Nook off the back corridor) to make it your respawn point. It turns green.

**Caught.** A chasing guard that reaches you catches you. After 2.5 s:

- you're back at your last checkpoint, or the entrance if you haven't reached one;
- every guard is back on patrol with no memory of you;
- objective progress goes back to what it was when you reached that checkpoint. If you took the card after the checkpoint, the card is back on the desk.

Checkpoints don't activate during a chase.

**Game flow.** The game has four game-level states, separate from the guards' AI:

- **PLAYING**
- **CAUGHT**: the short caught screen
- **PAUSED**
- **WIN**: escaped

What happens in each:

- **Pause** (Esc/P, or the window losing focus) freezes the whole level: guards, navigation, physics, noise and timers. The cursor appears and the pause menu offers **Resume**, **Restart level** and **Main menu**.
- **Caught:** after the caught screen the game respawns you and returns to PLAYING. You can't pause during the caught screen.
- **Win:** escaping shows your time and catches, with **Play again** and **Main menu**.

The mouse is captured only while playing.

Press **F3** to show the navigation mesh (cyan), each guard's current path (yellow), its route (coloured lines), its vision cone (green/yellow/red by awareness), a line to you while you're seen, the last-known-position marker, and a label with state and meter. A panel at the top left lists every guard's meter.

### Sound and presentation

- **Player:** footsteps on every stride (soft when crouched, heavier when sprinting), a gentle head bob, a slightly wider view while sprinting, and a tick when the use prompt appears.
- **Guards:** a low-poly jointed model with idle, walk, run (chase) and search (investigating) animations; 3D footsteps, keys jingling, radio chatter on patrol and a radio call when an investigation starts; the "?" / "!" icon pops when a guard's state changes.
- **Library:** room tone, the wall clock ticking, and page turns, a book being put down and a chair creaking now and then. These are decoration: guards don't hear them.
- **Stealth audio:** short stings when a guard notices you, starts investigating, starts a chase or loses you; tension music while you are seen or investigated, chase music during a chase.
- **UI:** detection meter under the status banner, key-cap use prompt, objective progress ("OBJECTIVE 2/5") with a flash on change, pause menu and button sounds, caught screen with vignette and respawn countdown, victory screen with stats.
- Volumes are on four buses (`default_bus_layout.tres`): Music, SFX, Ambience, UI.
- All sounds are generated by `tools/generate_audio.gd` (no external assets). Regenerate them with `godot --headless --path . --script res://tools/generate_audio.gd`; the four loops are set to loop in their `.import` files.
- `tools/capture_presentation.gd` renders the guard poses and HUD screenshots in `docs/presentation/`.

## Testing

**Run the tests.** In the editor, open `res://tests/test_scene.tscn` and press **F6**. A successful run prints `All tests passed (Phase 1 setup, … Phase 14 QA, Expanded Library graybox, map selection, Expanded Library guards).`. From a terminal:

```
godot --headless --path . --editor --quit          # first run only: imports the project
godot --headless --path . res://tests/test_scene.tscn
godot --headless --path . --script res://tools/qa_flow.gd   # real game flow with scene changes
godot --headless --path . --script res://tools/map_flow.gd  # both maps selected, restarted and left, 3 times
```

- **Exit code:** the suite exits `0` when every check passes and `1` otherwise, listing each failure. It takes about 9 minutes, because the movement, navigation, guard and vision tests step real physics frames.
- **Expected warnings:** 8, from tests that build broken setups on purpose.
- **In CI:** `tools/ci/run_tests.sh` runs the suite, the flow run and the map-selection run.

- `tests/test_scene.gd` — checks that every script compiles, Phase 1 setup checks (engine version, project settings, Windows export preset, folders, graybox) and the test runner.
- `tests/player_tests.gd` — Phase 2 player checks: InputMap bindings, movement maths, mouse-look clamping, and in-level movement (landing, walk and sprint speed, stopping, crate and wall collision, fall respawn).
- `tests/guard_tests.gd` — Phase 4 checks: patrol route logic, the guard scene, every library guard's points are walkable and reachable, every guard completes its loop in order, waits match the configured times, no teleporting or leaving the navmesh, guards never overlap, two guards pass head-on, a blocked guard skips its point, a guard without a route stands still, and a non-looping route stops at its end.
- `tests/ai_state_tests.gd` — Phase 6 state machine unit tests with a fake guard, so no physics: initial state, every allowed transition, priority (a confirmed sighting beats noise), rejected transitions, enter/exit order, repeated requests, a 2000-step random stress test, and no shared state.
- `tests/ai_behavior_tests.gd` — Phase 6 in the library: a guard goes PATROL → INVESTIGATE → CHASE → INVESTIGATE → PATROL against the real player, follows only the last known position once sight is lost, and investigates a noise.
- `tests/hearing_tests.gd` — Phase 7 checks:
  - noise presets and range; walls muffle
  - estimates are never exact, are deterministic, get worse with distance, and differ between guards
  - stale and expired events are ignored; duplicates are processed once; repeated footsteps merge
  - multiple guards; a guard ignores noise from other guards
  - player footsteps: walking gives WALK, sprinting gives RUN, standing still and teleporting give nothing
  - `NoiseMaker` makes interaction noise
  - in the library: walking behind a guard isn't heard, sprinting is (INVESTIGATE near an estimate, never the exact spot), and a chase ignores noise
- `tests/loop_tests.gd` — Phase 8 stealth loop checks:
  - status priority; crouch, including not standing up under a low beam
  - a carrel hides a crouched player from the side but not a standing one, and halves detection from the opening
  - a guard that loses a hidden player investigates and returns to patrol (`SPOTTED → INVESTIGATING → HIDDEN`)
  - crouch-walking is quiet
  - HUD direction indicators and stance text
  - a sprinting player can escape a chase; being caught freezes, then resets the level
- `tests/objective_tests.gd` — Phase 9 checks:
  - objective states and order, and progress snapshots
  - every objective, the card, the door and the checkpoints are reachable in order
  - interaction reach and walls
  - the exit rejects the player without the card; full flow to ESCAPED
  - checkpoints keep progress from before them and undo progress after them
  - all guards reset on respawn; no activation during a chase
  - no guard sees a checkpoint's respawn point during its patrol
- `tests/game_flow_tests.gd` — Phase 10 checks:
  - the game-state machine: allowed transitions only, no duplicates, 3000 random requests
  - main menu Start/Quit; Esc/P pause binding
  - pause and resume by key, button and focus loss, with the cursor right in each state
  - everything frozen while paused: guards, navigation, vision meters, player, noise clock, timers
  - caught → respawn; victory; restart and main menu, with only one scene change at a time
- `tests/level_design_tests.gd` — Phase 11 checks:
  - every required space exists
  - two independent routes to the card and two ways to the exit
  - carrels reachable, including the east-route alcove
  - RESTRICTED, room and EXIT signs; the card spotlight and clock landmark
  - decoration (books, signs, lights, ceilings) has no collision; ceilings on render layer 2
  - books generated the same way every time and kept inside their bookcase
- `tests/presentation_tests.gd` — Phase 12 checks:
  - every sound loads; loops loop and one-shots don't; the four buses exist
  - head bob, movement kind, guard animation choice and the prompt key split
  - the guard model has every animated joint, no collision, and the guard's capsule and speeds are unchanged
  - in the library: one footstep sound per stride; the camera settles when standing still
  - guards walk on patrol and search when investigating, with footsteps and radio
  - the AudioDirector reacts to stealth, objective, pause and door events, without repeating stings
  - UI sounds work while paused; the detection meter follows the most aware guard
- `tests/qa_playthrough_tests.gd` — Phase 14 playthroughs:
  - the whole route walked with real input (all objectives, checkpoints, E on the card and door, victory, sounds);
  - a real chase and catch (run animation, chase music, caught screen, respawn at the checkpoint).
- `tests/qa_regression_tests.gd` — one check per bug fixed in the QA pass (win title pop, benchmark guard placement)
- `tests/performance_tests.gd` — Phase 13 checks: the measured shadow settings stay (sun shadows on, 2 cascades, 2048 atlas); the benchmark's scenarios and statistics
- `tests/vision_tests.gd` — Phase 5 checks in a purpose-built arena: FOV and range maths, a player straight ahead is seen and the meter fills in the expected time, the meter holds then drains after losing sight, the last known position never updates while hidden, walls and tall shelves block sight but a low table doesn't, players outside the cone or out of range are not seen, far players fill the meter slowly, thresholds are configurable, and the debug cone stops at walls. In the library: every guard has vision, and no guard sees the spawn during a full patrol loop.
- `tests/navigation_tests.gd` — Phase 3 checks: every room exists, navigation covers open floor and none of the walls or furniture, nothing is baked outside the rooms or on furniture, every floor edge is walled, paths reach every room without crossing walls, a `NavigationAgent3D` probe walks from the entrance to the exit, the debug overlay draws the navmesh, and the saved navmesh matches a fresh bake.

- `tests/expanded_graybox_tests.gd` — Expanded Library graybox: scene structure, doorway and stair dimensions, navmesh on both floors, every planned location reachable, each stair on its own, planned gates and two approaches (rebaked with blockers), and a real-input walk of the main and alternative routes.
- `tests/expanded_ai_tests.gd` — Expanded Library navigation and guards: both floors baked and sealed, every patrol point clear of doorways and stairs, all six guards completing their loops together with nothing stuck, vision (walls, shelves, the slab, the balcony railing), hearing (open, through a wall, through the slab), chase and loss of contact, a chase up a stair and back, head-on crossings in a door and on a stair, and one guard touring every gate and stair.
- `tests/map_selection_tests.gd` — map selection: the catalog, one menu button per map with keyboard navigation, each button loading its map once, and for each map (loaded twice) one of each system, Restart → same map, Main menu → menu, signal connections made once, everything freed on leaving.

**Before a release:** work through `docs/qa/REGRESSION_CHECKLIST.md`: the automated part, plus the manual checks on Windows.

### QA tools

- `tools/qa_flow.gd` plays the real game flow with real scene changes and checks 15 steps:
  - main menu → start, pause, resume, restart;
  - caught → respawn, back to the menu and start again;
  - win, play again, quit.

  Run it with `godot --path . --script res://tools/qa_flow.gd -- --out=docs/qa/flow_check`; it prints `QA FLOW PASSED` and exits 0.
- `tools/map_flow.gd` selects each map from the real menu, restarts it and returns to the menu, three times over, with real scene changes. After every change it checks the right scene, the old one freed, one of each system, unchanged signal-connection counts, and no node growth. It prints `MAP FLOW PASSED` and exits 0.
- `docs/qa/REGRESSION_CHECKLIST.md` lists what to run and what to check by hand before a release.

## Performance evidence

Full method and data: **[`docs/phase-13-performance.md`](docs/phase-13-performance.md)**. Evidence is in `docs/performance/`: per-frame CSVs, summaries, charts and before/after renders.

**Benchmark:**
- `tools/benchmark.gd` replays a fixed scenario in the real level: the camera flies a fixed path and noise events happen on a fixed schedule.
- Scenarios: normal (3 guards), several (8) and stress (24).
- It records frame time, script, AI, animation and render time, draw calls, memory and stuck guards.

**Measured on a GPU-less Linux VM** (2 vCPUs, Mesa llvmpipe software rendering, 1280×720, debug build), where the optimisation was found and measured:

| | Normal (3 guards) | Stress (24 guards) |
|---|---|---|
| Avg FPS before → after the shadow optimisation | 8.37 → 11.61 | 7.85 → 10.57 |
| Mean frame time before → after | 119.6 → 86.2 ms | 127.3 → 94.6 ms |
| CPU per frame, headless (all game logic, physics, navigation) | 0.7 ms | 2.1 ms |

**Measured on Windows hardware** (release validation, 2026-10-09; Windows 10, Intel i5-8265U, NVIDIA GeForce MX130, 1280×720, debug build; evidence in `docs/performance/windows/`, details in `docs/FINAL_REPORT.md`):

| | Normal (3 guards) | Stress (24 guards) |
|---|---|---|
| Avg FPS (1% low) | 202.8 (62.1) | 153.2 (57.5) |
| Mean / p95 frame time | 4.94 / 6.81 ms | 6.54 / 10.7 ms |
| CPU per frame, headless | 0.85 ms | 2.93 ms |

**Findings:**
- Rendering was about 90% of the frame, and the sun's 4-cascade shadow map was the biggest single cost.
- **The fix:** 2 cascades and a 2048 shadow atlas, with no visible change (pixel-compared).
- The game logic is cheap: 48 guards cost 3.8 ms of CPU per frame.
- **Memory:** flat over a 5-minute run.
- The Phase 14 QA pass corrected the stress figures after fixing a benchmark bug.

### Performance benchmark

`tools/benchmark.gd` runs the real level in a fixed, repeatable scenario and records frame time, script, guard-AI, animation and render time, draw calls, memory and NPC counts:

```
godot --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --scenario=normal --out=docs/performance/my_run
godot --headless --fixed-fps 60 --path . --script res://tools/benchmark.gd -- --scenario=stress --out=docs/performance/my_run
```

- Scenarios: `normal` (3 guards), `several` (8), `stress` (24), or `--npcs=N`.
- The headless form measures CPU only (one physics tick per frame, no rendering).
- `python3 docs/performance/analyse.py` rebuilds the tables and charts (needs matplotlib).
- Results and method: `docs/phase-13-performance.md`.

## Level-design version history

The Expanded Library has its own log, one commit per version: **[`docs/expanded/LEVEL_LOG.md`](docs/expanded/LEVEL_LOG.md)** (design in [`docs/expanded/LAYOUT.md`](docs/expanded/LAYOUT.md)). The tutorial's history:

The level went through five measured versions, each recorded as an evidence folder (all five landed in git as one commit, `3320e45`). The full log, with what changed, why, the metrics and before/after pictures, is in **[`docs/level/LEVEL_LOG.md`](docs/level/LEVEL_LOG.md)**.

| Version | What changed | Evidence |
|---|---|---|
| v0 | baseline: the Phase 10 graybox measured with the new level tools | `docs/level/v0/` |
| v1 | cover and sightline pass: low bookcases, catalogue cabinet, Hallway East study alcove and carrel, book carts, exit-area crates and rack | `docs/level/v1/` (+ `compare.md`) |
| v2 | GuardEast's patrol becomes an exit-area warden (6 candidate routes measured, B2 chosen) | `docs/level/v2/` (+ `experiments/`) |
| v3 | readability: doors, room / RESTRICTED / EXIT signs, landmarks, card spotlight (visual only; metrics identical) | `docs/level/v3/` |
| v4 | low-poly art: palette, lighting, books, ceilings, chairs, plants, windows, posters, rugs | `docs/level/v4/`, `docs/level/before_after/` |

**Measured from v0 to v4:**
- Floor within 1.5 m of cover rose from 33% to 42%.
- The safest east route to the card got shorter (115–117 m → 103 m) and less exposed (38% → 31% peak).
- Spawn and both checkpoints stay at 0% exposure.

## Known limitations

**Scope:**
- One level.
- No save game.
- No settings menu (mouse sensitivity, volume, resolution).
- Quit only from the main menu.

**Testing:**
- The automated suite and the game-flow run pass on Linux (CI and the development VM) and on Windows 10 (release validation, 2026-10-09).
- The CI-built Windows executable was launched on Windows and played from the main menu into the level; a full manual playthrough of the checklist's Part 2 has not been recorded yet.
- The audio has not been judged by ear.
- The scripted playthroughs don't judge stealth difficulty; that needs human play.

**Level:**
- The scene file is still named `library_graybox.tscn` (kept so references stay stable).
- Only the exit door is interactive.
- Decoration (chairs, signs, books) has no collision; plants do.
- Windows are emissive panels.
- Only two checkpoints; none on the east route after the card.

**AI:**
- Guards sharing one patrol route can block each other at a narrow spot for about 5 s before skipping ahead. The level has one guard per route.
- Ambient sounds are decoration: guards don't hear them, and walls don't block them.

**Presentation:**
- The guard model is rigid box parts with code-built animations, about 20 draw calls per guard.
- The sounds are simple synthesised effects.

**Build:**
- Windows x64 only.
- The executable is not code-signed.
- Builds aren't byte-for-byte identical, because the pack records file times.
- The workflow's actions (`checkout`, `cache`, `upload-artifact` @v4) target Node.js 20, which GitHub has deprecated; runs pass, with a warning.

**CI status:** the first GitHub run, [Build #1](https://github.com/SE2026-T10/CampusEscape3D-2/actions/runs/37272574230) on commit `15b3ebf`, passed both jobs (validate and test 4 m 16 s, Windows export 39 s) and uploaded `CampusEscape3D-1.0.0-windows-x64` (37.5 MB).

## Development notes

### Adding or changing a guard patrol

1. Add a `PatrolRoute` node (script `scripts/npc/patrol_route.gd`) under `Guards`. Untick **Loop** if the guard should stop at the last point.
2. Add `Marker3D` children with `scripts/npc/patrol_point.gd` attached, in the order to visit them, on walkable floor. Set **Wait Time** per point (-1 uses the guard's default).
3. Instance `scenes/npc/guard.tscn` under `Guards` and set its **Patrol Route** to the new route. Several guards can share one route.

The tests check that every patrol point in the library is on the navigation mesh and reachable.

### Level-design tools

Measure the level and record a version (run on the commit you want to record):

```
godot --path . --script res://tools/level_report.gd -- --out=docs/level/v5 --version=v5
godot --path . --resolution 1280x720 --script res://tools/capture_views.gd -- --out=docs/level/v5/views
godot --headless --path . --script res://tools/level_compare.gd -- --before=docs/level/v4 --after=docs/level/v5
```

What each one produces:

- `level_report.gd` writes `report.md`, `metrics.json` and, when run with a display, `map.png`. It measures:
  - exposure: how much of each guard's patrol loop a spot is inside its view cone;
  - cover;
  - patrol loops;
  - shortest and safest player routes;
  - hiding-spot and respawn-point exposure.
- `--scene=res://other.tscn` measures an experimental copy of the level instead.
- `capture_views.gd` renders the 8 fixed viewpoints and a top-down view, so versions can be compared shot for shot.
- `level_compare.gd` writes a before/after table, `compare.md`.

### Rebaking navigation after changing the level

Navigation is baked from the level's static collision into `scenes/level/library_navmesh.tres`. After moving walls, shelves or furniture, rebake using either of these:

- **Editor:** select `NavigationRegion3D` in the library scene, click **Bake NavigationMesh** in the toolbar, then save (Ctrl+S).
- **Command line:** `godot --headless --path . --script res://tools/bake_navigation.gd`

If you forget to rebake, the tests fail with "The saved navigation mesh is out of date".

## Documentation

- `docs/phase-1-setup.md`
- `docs/phase-2-first-person-player.md`
- `docs/phase-3-library-navigation.md`
- `docs/phase-4-npc-patrol.md`
- `docs/phase-5-npc-vision.md`
- `docs/phase-6-npc-ai-state-machine.md`
- `docs/phase-7-hearing-and-noise.md`
- `docs/phase-8-stealth-loop.md`
- `docs/phase-9-objectives-and-checkpoints.md`
- `docs/phase-10-game-flow.md`
- `docs/phase-11-final-level.md`
- `docs/level/LEVEL_LOG.md` (level-design versions v0–v4 with evidence)
- `docs/phase-12-presentation.md`
- `docs/phase-13-performance.md` (benchmark, measurements, optimisation; evidence in `docs/performance/`)
- `docs/phase-14-qa.md` (final QA pass; checklist and evidence in `docs/qa/`)
- `docs/BUILD.md` (build, CI and release process)
- `docs/phase-15-build-pipeline.md`
- `docs/release-notes/v1.0.0.md`
- **[`docs/FINAL_REPORT.md`](docs/FINAL_REPORT.md)** (final MVP report and release validation)
- Expanded Library: `docs/expanded/phase-0-audit.md`, `docs/expanded/LAYOUT.md`, `docs/expanded/phase-1-graybox.md`, `docs/expanded/phase-2-map-selection.md`, `docs/expanded/phase-3-navigation-and-guards.md`, `docs/expanded/LEVEL_LOG.md`
