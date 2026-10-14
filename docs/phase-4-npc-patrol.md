# Phase 4 — NPC Patrol

A reusable guard NPC that patrols looping routes with Godot navigation. Patrolling only: no perception, investigate or chase.

## Delivered

| File | Purpose |
|---|---|
| `scenes/npc/guard.tscn` | Guard: `CharacterBody3D` (capsule, radius 0.35 m) with a body and cap mesh, `NavigationAgent3D` (avoidance on, radius 0.4, neighbour distance 6 m), and `DebugLabel` |
| `scripts/npc/guard.gd` | `class_name Guard`: patrol logic |
| `scripts/npc/patrol_route.gd` | `class_name PatrolRoute`: an ordered list of patrol points (its `Marker3D` children), a `loop` option, and a route line in the debug view |
| `scripts/npc/patrol_point.gd` | `class_name PatrolPoint` (`Marker3D`): per-point `wait_time` (-1 = guard default) |
| `scripts/utilities/navigation_utils.gd` | `NavigationUtils.wait_for_navigation()`: waits until the navigation map can answer queries near an NPC before it starts moving |
| `tests/guard_tests.gd`, `tests/test_utils.gd` | guard tests, plus a shared wait-for-fresh-navigation-map helper |

### Guard behaviour

- **States:**
  - `PATROL`: walking to the current point along the `NavigationAgent3D` path at `walk_speed` (2 m/s)
  - `WAIT`: standing at a point for its wait time
  - The enum is ready for `INVESTIGATE` and `CHASE` in later phases.
- **Movement:**
  - each physics frame the guard steers toward `agent.get_next_path_position()`
  - the avoidance system adjusts that velocity (`velocity_computed`), capped at `walk_speed`, then `move_and_slide()` runs
  - the guard turns smoothly to face where it's walking (`turn_speed`)
  - gravity applies
  - the guard is never placed directly at a position: it only moves by walking
- **Route:**
  - points are visited in scene-tree order
  - on arriving, the guard emits `patrol_point_reached(index)` and waits the point's `wait_time`, or `default_wait_time` (2 s) when the point has -1 or is a plain `Marker3D`
  - looping routes wrap to the first point; non-looping routes stop at the last point
- **Robustness:**
  - waits for the navigation map before starting (see the bug note below)
  - if real speed stays under 10% of `walk_speed` for `stuck_timeout` (5 s), for example because the player stands in a doorway, the guard emits `got_stuck(index)`, logs a warning and moves on to the next point
  - a guard with no route logs a warning and stands still (`IDLE`)
- **Multiple guards:**
  - any number of guard instances, each with its own route or a shared one
  - `NavigationAgent3D` avoidance steers guards around each other
  - guards also collide physically (npc layer)
- **Signals for later phases:** `state_changed(previous, current)`, `patrol_point_reached(index)`, `got_stuck(index)`.

### Physics layers (named in Project Settings)

| Layer | Name | Used by |
|---|---|---|
| 1 | world | level static geometry |
| 2 | player | player (mask: world + npc) |
| 3 | npc | guards (mask: world + player + npc), navigation probe (mask: world) |

The player moved from layer 1 to layer 2 so that NPCs and the player can be told apart later, for vision raycasts and catching. Navigation still bakes from layer 1 static colliders only.

### Guards in the library (`Guards` node)

| Guard | Route | Points (wait) |
|---|---|---|
| `GuardMain` | `MainRoomRoute` (orange): a rectangle around the stacks edge and reading area | 4 points (3 s, default 2 s, 1 s, default 2 s) |
| `GuardRestricted` | `RestrictedRoute` (red): through two aisles of the restricted stacks | 4 points (2 s, 1 s, 1 s, default 2 s) |
| `GuardEast` | `EastRoute` (green): east hallway, exit area, back-corridor door | 4 points (2 s, default 2 s, 3 s, 2 s) |

The entrance has no guard, so the player starts unseen.

### Debug information (debug builds only)

F3 toggles all of these together:

- the navigation mesh (cyan)
- every guard's current path (yellow)
- each `PatrolRoute` drawn as a line in its colour, with a post at each point
- a label above each guard with its name, state and point, for example `GuardMain / PATROL → point 2/4` or `WAIT 1.4s at point 3/4`. Labels draw through walls, so you can follow a guard you can't see.

Anything in the `debug_visuals` group follows the toggle. Labels and route lines are removed in release builds.

## Changes to earlier work

- **The level's walking `NavigationProbe` is gone.** The guards now show navigation working, and a magenta non-guard NPC walking around a stealth level would be confusing. The probe scene and script stay, because the navigation tests still use the probe for the entrance-to-exit walk.
- **`NavigationDebug`** draws paths for the `navigation_debug_agents` group (guards and probe). F3 now also toggles the `debug_visuals` group.
- **Probe start fix:** the probe uses the same navigation-ready wait as the guards.
- **Test isolation:** the player and navigation tests remove the guards before running. The navigation tests use the shared fresh-map wait instead of a fixed 3 frames.

### Bug found and fixed: starting before navigation is ready

When a level loads, the navigation map's first sync is empty: closest-point and path queries return nothing for about 4 physics frames. The guard (and the Phase 3 probe) started walking after 1 frame, so its first path was empty. `NavigationAgent3D` then reports "navigation finished" straight away, and the guard counted its first patrol point as reached without walking there. All three level guards start on their first point, so nobody noticed in play.

Both NPCs now wait with `NavigationUtils.wait_for_navigation()`. The non-looping-route test starts a guard 6 m from its first point and fails if the guard reports arriving faster than it could walk there.

The tests had the same problem, more visibly. Each test suite loads a fresh copy of the level into the same navigation map. For a few frames the map still held the previous copy's data, and then it was empty while it rebuilt. The fixed 3-frame wait in the Phase 3 tests only passed by luck of timing: one of the guard mutations below changed the timing and made them fail. `tests/test_utils.gd` now waits for a new map sync that includes the level.

## Automated tests (`tests/guard_tests.gd`)

| Requirement | Check |
|---|---|
| CharacterBody3D + NavigationAgent3D | scene structure, npc layer, world collision |
| Patrol points, route, looping | `PatrolRoute` order, wrap or stop, per-point and default waits, non-marker children ignored. Every library guard completes at least one full loop, visiting points strictly in order. |
| Moves between points via navigation, no teleporting | each physics step moves at most `walk_speed` × step × 1.25. The guard stays within 0.35 m of the navmesh the whole time. Every patrol point is on the navmesh and reachable from its guard. |
| Configurable waiting | every observed wait matches the configured time within 0.15 s of simulated time |
| Multiple guards | 3 library guards patrol at once and never come within 0.7 m of each other. Two extra guards walk the same corridor head-on and both keep patrolling without overlapping. |
| Robustness | a wall that navigation doesn't know about blocks a guard: it emits `got_stuck` and continues to its next point. A guard without a route stands still and shows `IDLE`. A non-looping route is walked once and stops, and its guard starts 6 m away and must actually walk to point 1. |
| Debug information | debug text names the guard and its state. The F3 toggle shows and hides guard labels. |

The behaviour tests run real physics with `Engine.time_scale = 6`. Each step then moves a guard at most 0.2 m, below the 0.3 m wall thickness.

## Verification record (2026-10-04)

All runs used the official Linux build of Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`).

| Check | Result |
|---|---|
| Project import | exit 0, no errors or warnings |
| Full test run | `All tests passed (Phase 1 setup, Phase 2 player, Phase 3 navigation, Phase 4 guards).`, exit 0, about 30 s; three consecutive runs, identical results |
| Measured values | `GuardMain` 1 loop, max step 0.200 m, max navmesh offset 0.15 m; `GuardRestricted` 2 loops, 0.200 m, 0.26 m; `GuardEast` 1 loop, 0.200 m, 0.05 m; crossing guards closest approach 0.81 m, about 9 s lost to sidestepping over two loops; blocked guard reported stuck after 8.2 s (2.9 s walk + 5 s timeout) and returned to point 1 |
| Expected warnings | "StuckGuard is stuck…" and "NoRouteGuard has no patrol route…" come from the robustness tests |

**Mutation checks.** Each copy was broken on purpose and tested. Every one failed with exit 1:

| Mutation | Caught by |
|---|---|
| Guard teleports to each patrol point | "GuardEast moved 26.12 m in one step (teleport?)" and the same for the other guards; the blocked guard was no longer stuck |
| Wait times ignored | "GuardMain waited 0.10s at point 2, expected 2.00s" and more |
| Routes never loop | route-logic check, plus "did not complete a patrol loop" for all guards |
| Guard walks straight at the target, ignoring the navigation path | "visited points out of order" and "got stuck" in the restricted stacks and east hallway |
| Avoidance off and guards don't collide with each other | "Crossing guards overlapped (closest 0.00 m)" |

**Screenshots** in `docs/evidence/phase-4/` were rendered under a virtual display (Xvfb, Mesa llvmpipe software OpenGL), not on Windows hardware.

- `topdown_patrols_debug.png`: all three routes, guards and paths with F3 on
- `guard_debug_label.png`: first-person view of `GuardMain` waiting, with its label
- `guard_plain.png`: the same view with F3 off

## Manual verification still required (Windows, Godot 4.7.2 editor, F5)

1. Watch each guard complete its loop. Check that it turns smoothly, pauses at points and never cuts through shelves or walls.
2. F3: labels, routes and paths appear and disappear together, and the label state matches what the guard is doing.
3. Stand in a guard's way: it pushes against you, then after about 5 s moves on to its next point. Guards don't detect the player yet, so that's expected.
4. Duplicate a guard onto an existing route in the editor and check that both patrol without getting tangled.

## Known limitations

- Guards don't perceive the player. Vision, hearing, investigate and chase are later phases.
- Guards don't look around at points. They wait facing the way they arrived.
- Head-on passing in narrow corridors works but costs time, as both guards sidestep.
- The stuck check uses real speed only. A guard sliding slowly along a wall counts as moving.
