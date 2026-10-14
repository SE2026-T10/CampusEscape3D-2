# Phase 3 — Library Navigation

The first real graybox of the library, with Godot 4 navigation baked across it. No visual polish, and no NPC AI.

## Layout

```
          RESTRICTED STACKS ════ BACK CORRIDOR ════ EXIT AREA (exit door)
                 ║                                      ║
           HALLWAY WEST                           HALLWAY EAST
                 ║                                      ║
   ╔═══════ MAIN LIBRARY ROOM ═════════════════════════╝
   ║  stacks (4 shelf rows)     reading area (4 tables), circulation desk
   ╚════════════ ENTRANCE (player spawn, Phase 2 test lane + crate)
```

Footprint about 44 × 50 m. North is −Z. Walls are 3.5 m high and 0.3 m thick. Doorways are 3–4 m wide.

| Area (`NavigationRegion3D/Areas/…`) | Contents |
|---|---|
| `Entrance` | front doors (locked, visual only), Phase 2 test lane, crate and probe markers |
| `MainRoom` | 28 × 20 m main hall |
| `MainStacks` | 4 shelf rows, 2.2 m high, with 2.4 m aisles |
| `ReadingArea` | 4 reading tables and the circulation desk |
| `HallwayWest` | 3 m hallway to the restricted stacks |
| `RestrictedStacks` | secondary area, 3 long shelf rows |
| `BackCorridor` | 3 m corridor from the restricted stacks to the exit |
| `HallwayEast` | L-shaped hallway from the main room to the exit |
| `ExitArea` | exit door and floor marker on the east wall, two crates |

There are two routes to the exit: west through the restricted stacks, or east down the hallway. That loop is deliberate, to give guards and the player choices later.

Every area has a **floor slab**, **walls** and **props**. Each one is a `StaticBody3D` with `Mesh` and `Collision` children, so the collision shapes are never scaled. Every area also has a `NavPoint` marker and a floating label. Floor colour shows the area type: hallways dark, restricted stacks red, exit green. Decorations without collision (doors, markers, signs) are ignored by navigation.

## Navigation

- **`NavigationRegion3D`** holds all the level geometry. Its `NavigationMesh` is saved separately in `scenes/level/library_navmesh.tres`, so rebakes show up as their own diff.
- **Bake settings:**
  - baked from static colliders only
  - cell size and height 0.25 m, matching the navigation map
  - agent radius 0.5 m, height 1.75 m, max climb 0.25 m, max slope 45°
  - `region_min_size` 8
- **Floors exist only inside rooms,** so the navigation mesh cannot extend outside the building. Wall and shelf tops are too narrow to survive the 0.5 m agent-radius erosion. `region_min_size` stops any small island from appearing on top of furniture.
- **`NavigationAgent3D`** is used by `scenes/npc/navigation_probe.tscn` (`NavigationProbe`). This development stand-in NPC walks a looping route through the rooms. It has no AI states (patrol, investigate and chase come later) and frees itself in release builds.
- **Rebaking** (also in the README):
  - In the editor: select `NavigationRegion3D` → **Bake NavigationMesh** → Ctrl+S.
  - Headless: `godot --headless --path . --script res://tools/bake_navigation.gd`. It exits 1 if the bake is empty or can't be saved.
  - A test compares the saved navmesh with a fresh bake of the current level, so a forgotten rebake fails the tests.
- **Debug visualization** (`scripts/systems/navigation_debug.gd`, the `NavigationDebug` node):
  - F3 (`toggle_navigation_debug`) shows the baked mesh as a translucent cyan fill with outlined polygons, plus each probe's current path in yellow
  - redraws automatically after a rebake
  - hidden at start and removed from release builds
  - Godot's own **Debug → Visible Navigation** editor option also works alongside it

## Development tools and builds

- `tools/` (the bake script) and `tests/` are excluded from the Windows export preset (`exclude_filter`).
- `NavigationProbe` and `NavigationDebug` call `queue_free()` when `OS.is_debug_build()` is false.

## Changes to earlier work

- **`PlayerTestArea`** moved into the entrance lobby, under the navigation region so its crate blocks navigation. The movement tests now use `CrateProbe` and `WallProbe` markers. Each marker faces its obstacle and stores `distance_to_obstacle`, so the tests no longer depend on hard-coded room coordinates.
- **Phase 1 setup test:** checks the new top-level nodes. Room-by-room checks moved to the navigation tests.
- **`PreviewCamera`:** now an orthographic top-down camera above the whole level, for overview screenshots. It still isn't the active camera.

## Automated tests (`tests/navigation_tests.gd`)

Floor and obstacle footprints are read from the level's visible meshes, so the tests follow layout changes and still catch a prop that has lost its collision.

| Requirement | Check |
|---|---|
| Walkable areas correctly baked | 1 m grid over every floor: every point clear of walls and furniture is on the navmesh. Every NavPoint has a path from the entrance. |
| Walls and obstacles block navigation | No grid point inside a wall or prop is walkable. Every path segment is ray-checked at 0.5 m height and hits nothing. MainRoom→HallwayEast must detour through the doorway. |
| Navigation stays inside the playable area | Every navmesh vertex lies inside a room floor and below 0.5 m. Points outside the building snap to a point inside. The probe stays on room floors for the whole walk. Every floor edge without a doorway is closed by a collider, checked with physics rays. |
| NavigationAgent3D works | The probe walks Entrance → Exit (about 55 m) and arrives. |
| Easy to rebake | The saved navmesh must match a fresh in-memory bake (area within 1%). The CLI bake tool was run for real. |
| Debug visualization | The overlay is linked to the region and draws as many polygons as the navmesh has. |

## Verification record (2026-10-04)

All runs used the official Linux build of Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`).

| Check | Result |
|---|---|
| Project import | exit 0, no errors or warnings |
| `tools/bake_navigation.gd` | `Baked 156 polygons, 134 vertices`, exit 0, no warnings |
| Full test run | `All tests passed (Phase 1 setup, Phase 2 player, Phase 3 navigation).`, exit 0, about 10 s, no leaks |
| Measured values | navmesh 156 polygons / 676.3 m² (saved and fresh bake identical); 500 open-floor samples with 0 missing; 75 samples inside obstacles with 0 walkable; 604 floor-edge points with 0 open; MainRoom→HallwayEast path 32.5 m against 25.5 m straight; probe walked Entrance→Exit 55.1 m and stopped 0.42 m from the target; player travelled 1.647 m to the crate (1.65 expected) and 3.000 m to the wall (3.00 expected) |

**Mutation checks.** Each copy of the project was broken on purpose, rebaked unless noted, and tested. Every one failed with exit 1:

| Mutation | Caught by |
|---|---|
| Shelf collision removed | "10 points inside walls or furniture are walkable" |
| East wall collision removed (navmesh unchanged, since no floor lies beyond it) | "16 floor edges have no wall, so the player could walk off the floor" |
| Shelf moved, **not** rebaked | coverage failures, plus "path … passes through Shelf2" |
| Entrance doorway walled off | "path … stops short" to all 8 areas; probe failed to reach the exit |
| Agent radius 0.25 with `region_min_size` 1 (navmesh baked onto tables) | "28 navmesh vertices are above 0.5 m"; the probe also got stuck on corners |
| Floor slab outside the building | "navmesh vertices are outside the rooms' floors" |
| `node_paths` removed from the NavigationDebug node (overlay draws nothing) | "NavigationDebug draws 0 polygons, navmesh has 156" |

The last row was a real bug found while making the evidence screenshots. The test was added after fixing it.

**Screenshots** in `docs/evidence/phase-3/` were rendered by Godot under a virtual display (Xvfb, Mesa llvmpipe software OpenGL). They aren't captures from Windows hardware.

- `topdown_plain.png`: top-down layout from `PreviewCamera`
- `topdown_debug.png`: the same view with the navigation overlay (cyan) and the probe's path (yellow)
- `main_room_debug.png`, `restricted_debug.png`: first-person views with the overlay on

## Manual verification still required (Windows, Godot 4.7.2 editor)

1. F5: walk from the entrance to the exit by both routes. Check that no gap lets you out of the building and nothing blocks a doorway.
2. Watch the magenta probe complete its loop and turn corners without snagging.
3. F3 shows and hides the overlay, and the yellow path follows the probe.
4. Editor rebake: move a shelf, click **Bake NavigationMesh**, save, and confirm `library_navmesh.tres` changes and the tests pass. Then undo the move, rebake and save.

## Known limitations

- Graybox only: no ceilings, lighting pass, art or sound. Labels float above rooms.
- The front doors and exit door are visual markers only. Winning or losing comes in a later phase.
- One probe, no avoidance. `NavigationAgent3D` avoidance stays off until there are several guards.
- The navmesh `.tres` is a large generated text file. Review its diffs by checking that the polygon count and area changed as expected, not line by line.
