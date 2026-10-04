# Campus Escape 3D

Campus Escape 3D is a low-poly, first-person 3D stealth game set in a university library. The MVP is one polished playable level, built in Godot with GDScript.

## Project details

- Engine: Godot 4.7.2 Stable (`ed1daf0bf`)
- Language: GDScript
- Target: Windows desktop
- Current phase: Phase 2 — First Person Player

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

There is no jump: the library has no vertical routes, and jumping onto shelves would let the player skip sections or climb out. All keys are defined in **Project Settings → Input Map**.

The player spawns in the **Player Test Area** on the left side of the library: a yellow sprint lane and a crate for checking collision. NPCs and stealth systems are not implemented yet.

## Run the tests

In the editor: open `res://tests/test_scene.tscn` and press **F6**. A successful run prints `All tests passed (Phase 1 setup, Phase 2 player).` to the Output panel and exits.

From a terminal (no window), with the Godot 4.7.2 executable on your `PATH`:

```
godot --headless --path . --editor --quit          # first run only: imports the project
godot --headless --path . res://tests/test_scene.tscn
```

The run exits with code `0` when every check passes and `1` otherwise, listing each failure as an error. It takes about 6 seconds because the player tests step real physics frames.

- `tests/test_scene.gd` — Phase 1 setup checks (engine version, project settings, Windows export preset, folders, graybox) and the test runner.
- `tests/player_tests.gd` — Phase 2 player checks: InputMap bindings, movement maths, mouse-look clamping, and in-level movement (landing, walk and sprint speed, stopping, crate and wall collision, fall respawn).

## Documentation

- `docs/phase-1-setup.md`
- `docs/phase-2-first-person-player.md`
