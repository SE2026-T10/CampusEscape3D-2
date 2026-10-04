# Campus Escape 3D

Campus Escape 3D is a low-poly, first-person 3D stealth game set in a university library. The MVP is one polished playable level, built in Godot with GDScript.

## Project details

- Engine: Godot 4.7.2 Stable (`ed1daf0bf`)
- Language: GDScript
- Target: Windows desktop
- Current phase: Phase 4 — NPC Patrol

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
| Debug view: navigation, guard paths, routes and states (debug builds) | **F3** |

There is no jump: the library has no vertical routes, and jumping onto shelves would let the player skip sections or climb out. All keys are defined in **Project Settings → Input Map**.

### The level

The library graybox (`scenes/level/library_graybox.tscn`) has an **Entrance** (player spawn), the **Main Library Room** with shelf stacks, a **Reading Area** and circulation desk, **Hallway West** to the **Restricted Stacks**, a **Back Corridor**, and **Hallway East**, both leading to the **Exit Area**. There are two routes from the main room to the exit. The Phase 2 player test area (sprint lane and crate) is in the entrance.

Three **guards** (dark blue) patrol the main room, the restricted stacks and the east hallway/exit. Each walks its own looping route with `NavigationAgent3D` and pauses at every patrol point. Press **F3** to show the navigation mesh (cyan), each guard's current path (yellow), its route (coloured lines), and a label with its name, state and current point. Guards don't see or hear the player yet: perception, investigate and chase come in later phases.

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

In the editor: open `res://tests/test_scene.tscn` and press **F6**. A successful run prints `All tests passed (Phase 1 setup, Phase 2 player, Phase 3 navigation, Phase 4 guards).` to the Output panel and exits.

From a terminal (no window), with the Godot 4.7.2 executable on your `PATH`:

```
godot --headless --path . --editor --quit          # first run only: imports the project
godot --headless --path . res://tests/test_scene.tscn
```

The run exits with code `0` when every check passes and `1` otherwise, listing each failure as an error. It takes about 30 seconds because the player, navigation and guard tests step real physics frames. The guard tests speed up time 6×.

- `tests/test_scene.gd` — Phase 1 setup checks (engine version, project settings, Windows export preset, folders, graybox) and the test runner.
- `tests/player_tests.gd` — Phase 2 player checks: InputMap bindings, movement maths, mouse-look clamping, and in-level movement (landing, walk and sprint speed, stopping, crate and wall collision, fall respawn).
- `tests/guard_tests.gd` — Phase 4 checks: patrol route logic, the guard scene, every library guard's points are walkable and reachable, every guard completes its loop in order, waits match the configured times, no teleporting or leaving the navmesh, guards never overlap, two guards pass head-on, a blocked guard skips its point, a guard without a route stands still, and a non-looping route stops at its end.
- `tests/navigation_tests.gd` — Phase 3 checks: every room exists, navigation covers open floor and none of the walls or furniture, nothing is baked outside the rooms or on furniture, every floor edge is walled, paths reach every room without crossing walls, a `NavigationAgent3D` probe walks from the entrance to the exit, the debug overlay draws the navmesh, and the saved navmesh matches a fresh bake.

## Documentation

- `docs/phase-1-setup.md`
- `docs/phase-2-first-person-player.md`
- `docs/phase-3-library-navigation.md`
- `docs/phase-4-npc-patrol.md`
