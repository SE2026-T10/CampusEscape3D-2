# Repository Guidelines

## Project Structure & Module Organization

Campus Escape 3D uses Godot 4.7.2 and GDScript. `project.godot` opens the shared main menu.

- `shared/`: reusable player, NPC AI, interaction, UI, scenes, and assets.
- `features/`: configurable inventory, stamina, objectives, checkpoints, puzzles, and security.
- `maps/<map_id>/`: map-specific `scenes/`, `scripts/`, `assets/`, `resources/`, `tests/`, `tools/`, and `docs/`.
- `tests/`: shared checks and the integrated test runner; `tools/ci/`: validation and packaging scripts.
- `templates/map/`: starting structure for new maps. Read `docs/architecture/MAP_LAYOUT.md` before adding one; register menu entries in `shared/scripts/game/level_catalog.gd`.

## Build, Test, and Development Commands

Use the official Godot **4.7.2 stable** build. Run commands from the repository root; `godot` must resolve to that executable.

- `godot --editor --path .`: open the editor; F5 runs the game, F6 runs the current scene.
- `godot --headless --path . --editor --quit`: import resources before automated checks.
- `godot --headless --path . res://tests/test_scene.tscn`: run the integrated suite.
- `python3 tools/ci/check_layout.py`: check layout and resource paths.

For CI parity, use Linux/WSL with `GODOT` set to the executable path:

- `bash tools/ci/validate.sh`: validate engine, imports, scripts, map contracts, and versions.
- `bash tools/ci/run_tests.sh`: run tests, scene-flow QA, and library rebuild checks after validation.
- `bash tools/ci/export_windows.sh`: package Windows builds into `build/` and `dist/`; requires matching export templates. See `docs/BUILD.md`.

## Coding Style & Naming Conventions

Match existing GDScript: tabs, typed declarations where practical, `snake_case` files/functions/variables, `PascalCase` classes, and `UPPER_SNAKE_CASE` constants. Prefix internal helpers with `_`. No dedicated formatter or linter is configured. Keep map-specific logic local and reuse shared controllers. Preserve `.gd.uid` files and resource references; exclude generated `.godot/` data.

## Testing Guidelines

Tests use a custom GDScript runner with explicit failure collection. Name suites `*_tests.gd`, place them in shared or map-local test directories, and register new suites in `tests/test_scene.gd`. Cover changed behavior and regressions; no numeric coverage threshold is configured. Passing runs exit zero and print `All tests passed`.

## Commit & Pull Request Guidelines

History mixes concise Vietnamese/English summaries and occasional `type(scope): description` messages; no uniform convention is enforced. Use focused, descriptive commits. PRs should explain affected maps, behavior changes, related issues, and validation results. Include screenshots or clips for visual/gameplay changes and ensure CI passes before merging.
