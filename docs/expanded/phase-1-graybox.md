# Expanded Library — Phase 1: Design and Graybox

The first playable graybox of the Expanded Library, built as its own scene (`scenes/level/expanded_library.tscn`):
- two floors and six major zones;
- three stairs between the floors;
- planned locations for the five objectives, the exit, the progression gates, a shortcut, patrol loops and hiding spots.

The design is in [`LAYOUT.md`](LAYOUT.md) and the version history in [`LEVEL_LOG.md`](LEVEL_LOG.md).

**Not in this phase, as asked:**
- map selection: the main menu still starts the tutorial;
- the mission: no objective logic, locks, guards or checkpoints.

The tutorial scene, its navmesh and every game script are unchanged.

## What was built

1. **The layout as data.** `tools/expanded/expanded_layout.gd` holds:
   - zones and rooms;
   - floors;
   - walls with typed openings;
   - stairs;
   - cover;
   - objectives, gates, patrol loops, hiding spots, intended routes;
   - probe points for testing.
2. **Top-down plans, drawn before construction.** `draw_layout.gd` draws them from the data: [`v0/layout_ground.png`](v0/layout_ground.png) and [`v0/layout_upper.png`](v0/layout_upper.png). They mark:
   - room boundaries, corridors, stairs and entrances;
   - the exit, gates and the shortcut;
   - intended routes and alternatives;
   - patrol loops, hiding spots and objectives.
3. **The graybox scene, generated from the same data.** `build_expanded_graybox.gd` builds it with the tutorial's conventions:
   - StaticBody3D pieces on layer 1, each with a `Mesh` and a `Shape` child;
   - all geometry under `NavigationRegion3D`;
   - the existing player scene as an instance;
   - WorldEnvironment, KeyLight (2 shadow splits, as in Phase 13), PreviewCamera and NavigationDebug (F3);
   - GameFlow and GameMenus (pause, Restart and Main menu work).

   Planned gameplay is marked under `Layout/`:
   - objective markers with labels and beacons;
   - gate markers;
   - PatrolRoute nodes (no guards);
   - hiding-spot markers.
4. **The navmesh**, baked by the same tool with the tutorial's settings, saved to `scenes/level/expanded_library_navmesh.tres`.
5. **Tests**: `tests/expanded_graybox_tests.gd`, added to the suite.
6. **Screenshots**: `capture_graybox.gd` produces top views, navmesh views and 16 eye-height views.

### Files

| File | |
|---|---|
| `tools/expanded/expanded_layout.gd` (+ `.uid`) | new: layout data v0 |
| `tools/expanded/draw_layout.gd` (+ `.uid`) | new: design plans |
| `tools/expanded/build_expanded_graybox.gd` (+ `.uid`) | new: scene and navmesh builder |
| `tools/expanded/capture_graybox.gd` (+ `.uid`) | new: screenshots |
| `scenes/level/expanded_library.tscn` | new (generated) |
| `scenes/level/expanded_library_navmesh.tres` | new (generated) |
| `tests/expanded_graybox_tests.gd` (+ `.uid`) | new |
| `tests/test_scene.gd` | changed: runs the new tests; pass line ends "…, Phase 14 QA, Expanded Library graybox)." |
| `docs/expanded/LAYOUT.md`, `LEVEL_LOG.md`, `phase-0-audit.md`, `phase-1-graybox.md` | new |
| `docs/expanded/v0/` | new: plans, top and navmesh views, `views/` (16), `test_run.txt`, `mutation_checks.txt` |

`tools/` and `tests/` are excluded from the export, so the shipped game only gains the scene and its navmesh. The scene can't be reached from the menu yet.

## Decisions

- **Generated graybox instead of hand-placed zone sub-scenes.** The audit (R14) suggested one sub-scene per zone to keep scene diffs reviewable. A data file and a builder do that better while the level is a graybox:
  - each layout version is a readable diff of the data;
  - the plans, the scene and the tests can't disagree, because they all read the same data.

  The generated `.tscn` should not be hand-edited. Rebuild instead. The builder keeps the files' UIDs, but node ids in the `.tscn` are regenerated on each build, so the scene file's diff is large. Review the layout data's diff instead.
- **Ramps, not steps.** The player has no step-up, so stairs are 24° ramp colliders with ten stepped filler blocks underneath. The fillers seal the space under the ramp and look like steps from the side. Stair tops meet an upper-slab edge, so no hole is cut into the upper floor.
- **Gates are open doorways in the graybox,** with coloured headers (red = gate, amber = shortcut) and labelled markers. The tests rebake the level with them closed, to prove the planned progression and the alternative approaches.
- **The exit is a closed green door panel** in the east wall. The level stays sealed; escaping becomes an interaction in the mission phase.
- **No guards yet.** Patrol loops are planned PatrolRoute nodes that are checked for reachability. Guards, perception across floors (audit R5–R7) and locks (R8) come later.
- **Navmesh freshness.** The new test allows 0.5 m² between the saved navmesh and a fresh bake, not the tutorial test's 1%. The 1% margin let a moved wall through (mutation check 3).

## Tests

Run on the Linux cloud VM, headless, Godot 4.7.2.stable.official.ed1daf0bf. The full output is in [`v0/test_run.txt`](v0/test_run.txt).

| Command | Result |
|---|---|
| `bash tools/ci/validate.sh` | `CHECK SCRIPTS PASSED (76 scripts)`, `VALIDATION PASSED` |
| `bash tools/ci/run_tests.sh` | `All tests passed (… Phase 14 QA, Expanded Library graybox)`; `QA FLOW PASSED (15 checks, 4 levels loaded)`; exit 0; only the 8 expected warnings |
| `godot --headless --path . res://scenes/level/expanded_library.tscn --quit-after 600` | runs 600 frames with no errors or warnings: no parser or resource errors |

**What the new tests check:**

| Check | Result |
|---|---|
| A. Scene | separate scene; six zones (four ground, two upper), each with a floor and walls; three stairs; five objective locations; all solids on layer 1; main scene and `MainMenu.LEVEL_SCENE` still the menu and the tutorial |
| B. Dimensions | narrowest opening 2.0 m (≥ 1 m of navmesh); doors 2.6 m high; ceilings clear the agents; steepest stair 24.2°; 2.2 m headroom everywhere on all three ramps (raycasts) |
| C. Navmesh | 892 polygons; walkable ground 2,807 m², upper 1,660 m²; saved = fresh bake (4,518.1 m²); no polygons between floors except on the stairs (nothing baked on furniture) |
| D. Reachability | 141/141 planned locations reachable from the spawn: every room probe and shelf aisle, O1–O5, the exit, every hiding spot, every patrol point, both sides of every doorway. Main route 273 m |
| E. Stairs | S1, S2 and S3 each connect the floors directly, up and down |
| F. Gates and approaches | 19/19 checks over 12 rebakes with blockers. Progression stages (start → after O1 → after O2) leave only the intended areas reachable, so the archive is gated. Each of the upper floor, the staff wing and the archive has two approaches. The archive has a return route to the exit without the front gate or the public stairs. All stairs closed → the upper floor is cut off |
| G. Walk | the real player, with real input, walked the main route (sprinting) and both alternatives (walking): 494 m in 122 s, never stuck, never below 0 m, reached 4.51 m. It went up and down all three stairs and through G1a, G1b, G2, G3 and G4 |

**The tests catch real breakage** ([`v0/mutation_checks.txt`](v0/mutation_checks.txt)):
- an archive bypass door → the progression check fails;
- O1 boxed in → reachability, progression and the walk fail;
- a wall moved without rebaking → the navmesh check fails.

**Suite time:** 356 s, up from 232 s. The walk is 122 s of real-time play. The CI test step's timeout is 1,200 s.

## Manual tests still required (Godot 4.7.2 on Windows)

1. **Open the scene.** Open `scenes/level/expanded_library.tscn` in the editor. Check that the Output panel shows no errors, and that the scene tree shows `NavigationRegion3D/Ground` (A–D), `Upper` (E–F), `Stairs` and `Layout`.
2. **Play it.** Press **F6** (run current scene) and walk:
   - porch → lobby → reading hall → Study 3 (O1 beacon);
   - S1 up → balcony → G1a → Office 2 (O2);
   - G2 → archive → vault (O3);
   - G3 → landing → S2 down → storage → loading dock (O4) → exit door (O5).

   Then try:
   - S3 from the browsing hall;
   - G1b from the upper stacks;
   - G4 from the lobby into the service corridor;
   - SC1 from the corridor into the reading hall.
3. **Check** that:
   - the stairs feel walkable up and down, with no snagging at the top or bottom;
   - doorways and aisles feel wide enough;
   - you can't fall off ramp sides or balconies;
   - nothing blocks a required route;
   - you can't get under a ramp.
4. **Navmesh.** Press **F3** to show the navmesh and the planned patrol loops on both floors.
5. **Tutorial.** Run the game (F5) → Start → the tutorial plays as before.

These were not done here, because this environment has no Windows machine and no interactive editor. The automated checks above cover them without human judgement of feel.

## Acceptance criteria

| Criterion | Result | Evidence |
|---|---|---|
| A documented layout exists for both floors | **PASS** | `LAYOUT.md`; `v0/layout_ground.png`, `v0/layout_upper.png` |
| All six major zones are present | **PASS** | test A; `v0/top_*.png` |
| Both floors are connected | **PASS** | tests E and G (S1, S2, S3 walked up and down) |
| At least two approaches toward restricted progression | **PASS** | test F: archive via G2 or G3; staff wing via G1a or G1b; upper floor via S1, S3 or S2 |
| The intended exit and all objective locations are reachable | **PASS** | test D (navmesh) and test G (walked) |
| No mandatory route is accidentally blocked by geometry | **PASS** | tests D and G; 141 planned locations; both sides of every doorway |
| The new map is a separate scene | **PASS** | `scenes/level/expanded_library.tscn`, root `ExpandedLibrary` |
| The existing tutorial remains unchanged and playable | **PASS** | `git diff` shows no change to the tutorial scene, its navmesh or any script; full suite and `qa_flow` pass |
| No critical parser or runtime errors remain | **PASS** | `validate.sh`; scene run of 600 frames clean; suite clean |

## Known issues and limitations

- **Graybox only:** placeholder colours and boxes, no lighting pass. In top-down renders, the upper slab shows shadow banding from the directional light; it is cosmetic.
- **Linux only so far:** all results come from the Linux VM with software rendering. Windows behaviour (feel, the editor) is in the manual list above. A Windows bake should match the saved navmesh within 0.5 m², but that hasn't been verified on Windows yet.
- **The route and loop lines on the design plans are straight lines between waypoints.** Real walking follows the doorways (tests D and G).
- **Not designed yet:**
  - cross-floor sight lines over the balcony railing;
  - hearing through the slab;
  - the 20–30 minute pacing.

  These come in the guard and balancing phases.
- **Docs not updated:** `README.md` and `docs/qa/REGRESSION_CHECKLIST.md` still describe the MVP pass line ("… Phase 14 QA"). Your working copy has uncommitted edits in both files, so this phase didn't touch them. Update them when those edits are committed.

## Recommended next phase

**The mission.**
- Lock gates G1a, G1b, G4, G2 and G3 and the one-way shortcut SC1. This needs the access-door decision (audit R8).
- The five objectives as working gameplay, with ObjectiveManager configured per level (audit H2) and checkpoints.
- A test that walks the locked progression.

Map selection and the shared runtime sub-scene (audit H1, H6) can come before or with it.
