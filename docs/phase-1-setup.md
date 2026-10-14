# Phase 1 — Project Setup

This phase establishes the Godot 4.7.2 project, Windows desktop target, source layout, a static library graybox, and a lightweight scene smoke test. No gameplay is included.

## Delivered

- `project.godot`: project name, Godot 4.7 feature tag, GL Compatibility renderer (suits the low-poly style and older Windows GPUs), 1280×720 window, main scene set to the library graybox.
- `export_presets.cfg`: one **Windows Desktop** preset exporting to `build/CampusEscape3D.exe` (`build/` is git-ignored).
- Folder layout: `scenes/{player,npc,level,ui,systems}`, `scripts/{player,npc,systems,utilities}`, `assets/{models,materials,audio,textures}`, `tests/`, `docs/`, `.github/workflows/`. Empty folders hold a `.gitkeep` so Git tracks them.
- `scenes/level/library_graybox.tscn`: static library graybox — floor, four walls, three shelf rows, a reading table, a key light, an environment, and an elevated overview `PreviewCamera`. The first-person camera belongs to the player controller in a later phase; the overview camera is only for inspecting the graybox.
- `tests/test_scene.tscn` + `tests/test_scene.gd`: smoke test that exits `0` on success and `1` on failure (see README).

## Design notes

- The smoke test uses explicit checks rather than `assert()`. In Godot 4.7.2, a failing `assert()` in a headless debug run pauses in the debugger (the process hangs until killed) and asserts are removed from release builds, so they cannot fail an automated run.
- Gameplay folders are intentionally empty until their phases.

## Verification record (2026-10-04)

Automated, on Linux x86_64 with the official `Godot_v4.7.2-stable_linux.x86_64` build (`--version` → `4.7.2.stable.official.ed1daf0bf`):

| Check | Command | Result |
|---|---|---|
| Project import | `godot --headless --path . --editor --quit` | exit 0, no errors |
| Smoke test | `godot --headless --path . res://tests/test_scene.tscn` | `Phase 1 smoke test passed.`, exit 0 |
| Main scene runs | `godot --headless --path . --quit-after 120` | exit 0, no errors or warnings |
| Smoke test can fail | same test on a copy with `scripts/utilities` removed and `Floor` renamed | 2 failures reported, exit 1 |

## Manual verification still required

- Open the project in the Godot 4.7.2 Stable editor **on Windows** and press F5: the graybox should render from the overview camera with no errors in the Output panel. The headless runs above do not render anything, so they do not prove the visuals look right.
- A Windows export has not been produced. It needs the 4.7.2 export templates (Editor → Manage Export Templates). Automated builds are planned for a later phase.

No profiler capture, AI-state test, level-version history, or automated build is claimed in Phase 1; those are outside this phase's scope.
