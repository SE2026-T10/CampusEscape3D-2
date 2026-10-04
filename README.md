# Campus Escape 3D

Campus Escape 3D is a low-poly, first-person 3D stealth game set in a university library. The MVP is one polished playable level, built in Godot with GDScript.

## Project details

- Engine: Godot 4.7.2 Stable (`ed1daf0bf`)
- Language: GDScript
- Target: Windows desktop
- Current phase: Phase 1 — Project Setup

## Run the project

1. Install Godot 4.7.2 Stable.
2. Import `project.godot` in the Godot Project Manager.
3. Open the project and press **F6** to run the open scene or **F5** to run the Library graybox.

The Phase 1 graybox is deliberately static: no player controller, NPCs, stealth systems, or gameplay has been added.

## Run the smoke test

In the editor: open `res://tests/test_scene.tscn` and press **F6**. A successful run prints `Phase 1 smoke test passed.` to the Output panel and exits.

From a terminal (no window), with the Godot 4.7.2 executable on your `PATH`:

```
godot --headless --path . --editor --quit          # first run only: imports the project
godot --headless --path . res://tests/test_scene.tscn
```

The test exits with code `0` when every check passes and `1` otherwise, listing each failure as an error. It checks the engine version and commit, key project settings, the Windows Desktop export preset, the folder layout, and the library graybox contents.
