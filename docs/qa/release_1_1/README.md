# Release 1.1.0 — automated run

2026-10-12, development VM (Linux, Godot 4.7.2 stable official), on commit `484761d` plus the release changes (benchmark `--level`, its test, version 1.1.0, the export's both-maps check). Commands: `tools/ci/validate.sh`, `tools/ci/run_tests.sh`, `tools/ci/export_windows.sh`, exactly as CI runs them.

| Step | Result | Log |
|---|---|---|
| Validate | `CHECK SCRIPTS PASSED (91 scripts)`, `Project version: 1.1.0`, `VALIDATION PASSED`, exit 0 | `check_scripts.log` |
| Test suite | `All tests passed (Phase 1 setup, … Expanded Library graybox, map selection, Expanded Library guards, Expanded Library mission).`; exactly the 8 expected warnings; no errors; about 11 min | `tests.log` |
| Game flow | `QA FLOW PASSED (15 checks, 4 levels loaded)` | `qa_flow.log` |
| Map flow | `MAP FLOW PASSED (52 checks, 12 levels loaded, 3 cycles)`, no errors or warnings | `map_flow.log` |
| Windows export | `EXPORT PASSED: dist/CampusEscape3D-1.1.0-windows-x64.zip` (38.5 MB; `.exe` 109 MB, `.pck` 0.9 MB); both maps, both navmeshes, `LevelCatalog`, the props and the Expanded Library's scripts found in the pack; no tests or tools in it; the `.exe` carries file version 1.1.0.0 | `export_checks.log`, `export_tail.log` |

Not covered here: running the exported `.exe` (it needs Windows; under Wine 9.0 on this VM the Godot runtime crashes at start-up even with `--headless`, so Wine can't stand in for it).
