# Phase 2 — First Person Player

A reusable first-person player for the library level. No stealth AI, NPCs or perception.

## Delivered

- `scenes/player/player.tscn` — reusable `CharacterBody3D` player:
  - `CollisionShape3D`: capsule, radius 0.35 m, height 1.8 m
  - `Head` at 1.6 m eye height, with `Camera3D` (current, FOV 75, near plane 0.05 m)
- `scripts/player/player.gd` (`class_name FirstPersonPlayer`):
  - walking at 3.5 m/s and sprinting at 5.5 m/s
  - accelerates at 20 m/s² and decelerates at 25 m/s², so it reaches full speed in about 0.2 s and stops in about 0.2 s
  - gravity from Project Settings, with `move_and_slide()` collision
  - mouse look: the body turns left/right and the head tilts up/down, clamped to ±85°
  - the cursor is captured when play starts, Escape releases it, and clicking the window captures it again
  - fall safety: if the player drops below `fall_limit_y` (−10 m), they return to their spawn point
  - every tuning value is exported and grouped in the Inspector
- **InputMap** (`project.godot`): `move_forward` W, `move_backward` S, `move_left` A, `move_right` D, `sprint` Shift, `release_mouse` Escape. Bindings use physical keys, so they stay in the same place on AZERTY and other keyboard layouts.
- `scenes/level/library_graybox.tscn`:
  - a `StaticBody3D` + `CollisionShape3D` under the floor, all four walls, the three shelf rows and the reading table
  - the scaled shelf and table meshes were replaced by correctly sized box meshes, so the collision shapes are unscaled; the level looks the same
  - **PlayerTestArea** in the open left lane: a yellow 12 m sprint lane, a 1 m test crate, and a sign listing the controls
  - the Player is instanced at the start of the lane, facing down it
  - `PreviewCamera` is kept for overview inspection but is no longer current
- `tests/player_tests.gd`: player tests, run by `tests/test_scene.tscn`.
- `docs/.gdignore`: tells Godot to skip `docs/`, so the evidence images are not imported as game textures or included in builds.

## Design decisions

- **No jump.** The level is flat, with 2.8 m shelves and 4 m walls. A jump adds nothing to the stealth loop and would allow climbing onto shelves or out of the level. A test fails if a `jump` action is added to the InputMap.
- **Staying inside the playable area** has two layers. The walls block the player, and with no jump the player cannot climb them. If anything still goes wrong (for example a geometry gap added later), the fall-safety respawn catches it.
- **Diagonal movement** uses `limit_length(1)` instead of `normalized()`, so it isn't faster than straight movement and analog input still works if a gamepad is added later.
- **Mouse look** uses `InputEventMouseMotion.screen_relative`, so sensitivity doesn't change with the window's stretch scaling.
- Movement maths sits in small public functions (`get_target_velocity`, `calculate_horizontal_velocity`, `apply_look`) so the tests can check them directly.

## Automated tests (`tests/player_tests.gd`)

- **InputMap:** all six actions exist with the expected physical keys, and there is no `jump` action.
- **Player scene:** `CharacterBody3D` root, a collision shape, a current camera at `Head/Camera3D`, and sprint speed higher than walk speed.
- **Movement maths:** acceleration and deceleration step sizes, no overshoot, W maps to −Z, diagonals are no faster than walking, pitch is clamped both ways, and yaw turns the body.
- **In the level, using real physics frames and simulated InputMap presses:**
  - landing on the floor
  - walk speed reaches 3.5 m/s
  - sprint speed reaches 5.5 m/s
  - full stop within 20 frames
  - stopping at the crate face
  - stopping at the left wall, then at the back-left corner
  - respawn after falling below the level

## Verification record (2026-10-04)

All runs used the official Linux build of Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`).

| Check | Result |
|---|---|
| Project import (`--editor --quit`) | exit 0, no errors or warnings |
| Full test run (`res://tests/test_scene.tscn`) | `All tests passed (Phase 1 setup, Phase 2 player).`, exit 0, about 6 s |
| Values measured by the run | walk 3.50 m/s, sprint 5.50 m/s, stopped at crate x = −10.050 (expected crate face −10.05), stopped in corner at (−11.399, −8.400) (expected about −11.40, −8.40) |
| Main scene, 300 frames headless | no errors or warnings |
| Mutation: left-wall collision removed | caught: "Player went through the left wall (x=-16.540)", exit 1 |
| Mutation: crate collision removed | caught: "Player passed into the test crate", exit 1 |
| Mutation: acceleration set to 2 m/s² | caught: walk and sprint speed failures, exit 1 |
| Mutation: `jump` action added | caught, exit 1 |

The screenshots in `docs/evidence/phase-2/` were rendered by Godot under a virtual display (Xvfb, Mesa llvmpipe software OpenGL, GL Compatibility renderer). They show what the scene contains. They are not captures from Windows hardware.

- `player_spawn_view.png`: the first-person view from the spawn point, with the sprint lane, test crate, sign, and shelves on the right
- `level_overview.png`: the view from `PreviewCamera`. That camera sits outside the front wall, so the wall fills the bottom of the frame. It already did this in Phase 1.

## Manual verification still required (Windows, Godot 4.7.2 editor, F5)

Feel and input handling can't be tested without a real window and mouse:

1. The cursor is hidden and captured on start, and mouse movement turns the view smoothly in both directions.
2. You can't look past straight up or straight down.
3. Escape shows the cursor and stops the view turning. Clicking the game window captures the cursor again.
4. WASD moves relative to where you're looking. Holding Shift is clearly faster.
5. Movement starts and stops crisply without feeling icy.
6. You can't pass through walls, shelves, the reading table or the crate, including while sprinting into corners.
7. Alt-Tab away and back: the cursor behaves sensibly.

## Known limitations

- No head bob, footstep sound or crouch. Crouching and noise belong to the stealth phases.
- Mouse sensitivity is an exported value, with no in-game settings menu.
- `PreviewCamera` sits outside the room (inherited from Phase 1). It's only an inspection aid.
