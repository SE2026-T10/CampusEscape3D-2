# Campus Escape 3D

Campus Escape 3D is a low-poly, first-person 3D stealth game set in a university library. The MVP is one polished playable level, built in Godot with GDScript.

## Project details

- Engine: Godot 4.7.2 Stable (`ed1daf0bf`)
- Language: GDScript
- Target: Windows desktop
- Current phase: Phase 6 — NPC AI State Machine

## Run the project

1. Install Godot 4.7.2 Stable.
2. Import `project.godot` in the Godot Project Manager.
3. Open the project and press **F5** to play the Library graybox.

### Controls

| Action | Key |
|---|---|
| Move | **W A S D** |
| Sprint | hold **Shift** |
| Look | mouse |
| Release the mouse cursor | **Escape** (click the game window to capture it again) |
| Debug view: navigation, guard paths, routes, vision cones, detection and AI state (debug builds) | **F3** |

There is no jump: the library has no vertical routes, and jumping onto shelves would let the player skip sections or climb out. All keys are defined in **Project Settings → Input Map**.

### The level

The library graybox (`scenes/level/library_graybox.tscn`) has an **Entrance** (player spawn), the **Main Library Room** with shelf stacks, a **Reading Area** and circulation desk, **Hallway West** to the **Restricted Stacks**, a **Back Corridor**, and **Hallway East**, both leading to the **Exit Area**. There are two routes from the main room to the exit. The Phase 2 player test area (sprint lane and crate) is in the entrance.

Three **guards** (dark blue) patrol the main room, the restricted stacks and the east hallway/exit. Each walks its own looping route with `NavigationAgent3D` and pauses at every patrol point. Guards **see**: each has a 90° vision cone reaching 14 m, blocked by walls and shelves. While a guard can see you, its detection meter (0–100) fills: fast up close, slowly at long range. Once you're out of sight it drains again. At 30 the guard becomes SUSPICIOUS, at 100 ALERTED. It remembers where it last saw you, and nothing else. Each guard runs an explicit state machine with three states:

- **PATROL:** walks its route.
- **INVESTIGATE:** walks to where it saw something suspicious (meter ≥ 30) or heard a noise, then searches there for 6 s before going back to patrol.
- **CHASE:** runs after you once the meter is full and it can see you. If it loses sight, it heads to where it last saw you and investigates there.

Being caught has no consequence yet; that comes in a later phase.

Press **F3** to show the navigation mesh (cyan), each guard's current path (yellow), its route (coloured lines), its vision cone (green/yellow/red by awareness), a line to you while you're seen, the last-known-position marker, and a label with state and meter. A panel at the top left lists every guard's meter.

### Adding or changing a guard patrol

1. Add a `PatrolRoute` node (script `scripts/npc/patrol_route.gd`) under `Guards`. Untick **Loop** if the guard should stop at the last point.
2. Add `Marker3D` children with `scripts/npc/patrol_point.gd` attached, in the order to visit them, on walkable floor. Set **Wait Time** per point (-1 uses the guard's default).
3. Instance `scenes/npc/guard.tscn` under `Guards` and set its **Patrol Route** to the new route. Several guards can share one route.

The tests check that every patrol point in the library is on the navigation mesh and reachable.

### Rebaking navigation after changing the level

Navigation is baked from the level's static collision into `scenes/level/library_navmesh.tres`. After moving walls, shelves or furniture, rebake using either of these:

- **Editor:** select `NavigationRegion3D` in the library scene, click **Bake NavigationMesh** in the toolbar, then save (Ctrl+S).
- **Command line:** `godot --headless --path . --script res://tools/bake_navigation.gd`

If you forget to rebake, the tests fail with "The saved navigation mesh is out of date".

## Run the tests

In the editor: open `res://tests/test_scene.tscn` and press **F6**. A successful run prints `All tests passed (Phase 1 setup, Phase 2 player, Phase 3 navigation, Phase 4 guards, Phase 5 vision, Phase 6 AI).` to the Output panel and exits.

From a terminal (no window), with the Godot 4.7.2 executable on your `PATH`:

```
godot --headless --path . --editor --quit          # first run only: imports the project
godot --headless --path . res://tests/test_scene.tscn
```

The run exits with code `0` when every check passes and `1` otherwise, listing each failure as an error. It takes about 45 seconds because the movement, navigation, guard and vision tests step real physics frames, mostly with time sped up 4–6×.

- `tests/test_scene.gd` — checks that every script compiles, Phase 1 setup checks (engine version, project settings, Windows export preset, folders, graybox) and the test runner.
- `tests/player_tests.gd` — Phase 2 player checks: InputMap bindings, movement maths, mouse-look clamping, and in-level movement (landing, walk and sprint speed, stopping, crate and wall collision, fall respawn).
- `tests/guard_tests.gd` — Phase 4 checks: patrol route logic, the guard scene, every library guard's points are walkable and reachable, every guard completes its loop in order, waits match the configured times, no teleporting or leaving the navmesh, guards never overlap, two guards pass head-on, a blocked guard skips its point, a guard without a route stands still, and a non-looping route stops at its end.
- `tests/ai_state_tests.gd` — Phase 6 state machine unit tests with a fake guard, so no physics: initial state, every allowed transition, priority (a confirmed sighting beats noise), rejected transitions, enter/exit order, repeated requests, a 2000-step random stress test, and no shared state.
- `tests/ai_behavior_tests.gd` — Phase 6 in the library: a guard goes PATROL → INVESTIGATE → CHASE → INVESTIGATE → PATROL against the real player, follows only the last known position once sight is lost, and investigates a noise.
- `tests/vision_tests.gd` — Phase 5 checks in a purpose-built arena: FOV and range maths, a player straight ahead is seen and the meter fills in the expected time, the meter holds then drains after losing sight, the last known position never updates while hidden, walls and tall shelves block sight but a low table doesn't, players outside the cone or out of range are not seen, far players fill the meter slowly, thresholds are configurable, and the debug cone stops at walls. In the library: every guard has vision, and no guard sees the spawn during a full patrol loop.
- `tests/navigation_tests.gd` — Phase 3 checks: every room exists, navigation covers open floor and none of the walls or furniture, nothing is baked outside the rooms or on furniture, every floor edge is walled, paths reach every room without crossing walls, a `NavigationAgent3D` probe walks from the entrance to the exit, the debug overlay draws the navmesh, and the saved navmesh matches a fresh bake.

## Documentation

- `docs/phase-1-setup.md`
- `docs/phase-2-first-person-player.md`
- `docs/phase-3-library-navigation.md`
- `docs/phase-4-npc-patrol.md`
- `docs/phase-5-npc-vision.md`
- `docs/phase-6-npc-ai-state-machine.md`
