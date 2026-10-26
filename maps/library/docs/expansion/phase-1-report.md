# Expanded Library expansion: Phase 1, safe integration baseline

Date: 2026-10-15. Starting point: `Development` at **`7d73492`** (tag `v1.1.0`). Owner decisions for this phase:
- new content goes into an **expansion sub-scene** inside the existing map;
- the builder stays frozen;
- changes are written directly to `Development` in the owner's local folder;
- nothing is committed or pushed by me.

**Recommendation: PASS.**

## 1. Summary of changes

- **Baseline recorded** ([`phase-1-baseline.md`](phase-1-baseline.md), evidence in [`baseline/`](baseline)):
  - scenes, geometry, decoration, actors, file hashes, views;
  - working features and known defects;
  - shared systems and map-specific configuration;
  - rules for later phases.
- **One integration point, the smallest change possible:**
  - the new empty scene `scenes/level/expanded_library_expansion.tscn` (a `Node3D` named `Expansion`, no script);
  - instanced once into `scenes/level/expanded_library.tscn` right after `Gameplay`. The level file gains 3 lines: one resource reference, one node, one blank line. Nothing else in it changed.
- **New test suite** `tests/expanded_baseline_tests.gd`, run by the test scene:
  - the integration point exists once and only in the Expanded Library;
  - the existing level (geometry, door frames and other decoration, guards, routes, mission set-up, navmesh) still matches the baseline;
  - the two maps load alternately without sharing or leaving anything behind.
- **The export check** now also requires the sub-scene in the Windows pack.
- **Documentation:** README (architecture, tests, docs list), the regression checklist's pass line, and a `LEVEL_LOG.md` entry (builder frozen, integration point).

Not done, as required: no rebuild, no change to the player controller, no new gameplay.

## 2. Files changed

| File | Change |
|---|---|
| `scenes/level/expanded_library.tscn` | +3 lines: `ext_resource` for the sub-scene, node `Expansion` after `Gameplay` |
| `scenes/level/expanded_library_expansion.tscn` | **new**: empty `Node3D` "Expansion" with an editor description |
| `tests/expanded_baseline_tests.gd` (+ `.uid`) | **new**: the baseline suite |
| `tests/test_scene.gd` | runs the new suite; pass line ends "…, Expanded Library expansion baseline)." |
| `tools/ci/export_windows.sh` | +1 line: the sub-scene must be in the pack |
| `README.md` | architecture line, test description, pass line, docs list |
| `docs/qa/REGRESSION_CHECKLIST.md` | A1 pass line |
| `docs/expanded/LEVEL_LOG.md` | appended "Expansion (2026)" entry |
| `docs/expanded/expansion/phase-1-baseline.md`, `phase-1-report.md` | **new** |
| `docs/expanded/expansion/baseline/` | **new**: `geometry.txt`, `decoration.txt`, `actors.txt`, `manifest.sha256`, `views/` (22 PNG), `views_compare.txt`, `mutation_checks.txt`, `test_run.txt` |
| `docs/expanded/expansion/phase-1-logs/` | **new**: this phase's validate, test, flow and export logs |

## 3. Existing systems reused

- The level's own managers stay the only ones. The sub-scene adds no manager and no script; later content finds the existing ones through their groups.
- `LevelCatalog` and `MainMenu` are unchanged: map selection works exactly as before.
- `TestUtils.add_level_and_wait_for_navigation()` loads the maps in the new tests, with the same group checks as `map_selection_tests.gd`.
- `tools/expanded/collision_fingerprint.gd` and both `capture_views.gd` tools recorded the baseline.
- The CI scripts ran the regression unchanged.

## 4. Acceptance criteria

| Criterion | Result | Evidence |
|---|---|---|
| The existing Expanded Library scene remains the map being developed | **PASS** | same file, same `LevelCatalog` entry; the sub-scene is a child of it |
| No duplicate Expanded Library map is created | **PASS** | catalog still has 2 maps; the sub-scene is instanced exactly once (test A) and holds no map |
| Existing geometry, materials, textures and systems intact | **PASS** | collision, decoration and actor listings byte-identical before and after (digests equal on `7d73492` and the Phase 1 tree); fingerprint = v4; navmesh file untouched; materials untouched (the level file only gained 3 lines); 17/17 deterministic views and 9/9 tutorial views pixel-identical |
| Both maps load and remain separately selectable | **PASS** | `map_selection_tests` (menu buttons, each map loaded twice); new alternating loads (tutorial → expanded → tutorial → expanded); `MAP FLOW PASSED` with real scene changes |
| Existing tests pass, or pre-existing failures documented | **PASS** | full suite, `QA FLOW`, `MAP FLOW`, export all pass; 8 expected warnings, no errors; no pre-existing failure appeared |
| Baseline and changed files documented | **PASS** | this report and `phase-1-baseline.md` |

## 5. Tests actually performed

Linux VM, Godot 4.7.2 stable official, with the project's CI scripts:

| Run | Result |
|---|---|
| Baseline on unchanged `7d73492`: validate + suite + flows | all pass, 8 expected warnings (`baseline/test_run.txt`) |
| Phase 1 tree: `validate.sh` | `VALIDATION PASSED` (92 scripts: the 91 of the baseline + the new test; version 1.1.0) |
| Phase 1 tree: `run_tests.sh`, first run | all passed, but **9 warnings**: my new suite (the last one) freed the last map 3 frames before the run quit, so its room-tone sound was reported as leaked. **Fixed:** the suite now waits 30 frames at its end |
| Phase 1 tree: `run_tests.sh`, after the fix | `All tests passed (… Expanded Library mission, Expanded Library expansion baseline).`; exactly the 8 expected warnings; no errors; `QA FLOW PASSED (15 checks, 4 levels loaded)`; `MAP FLOW PASSED (52 checks, 12 levels loaded, 3 cycles)`, no warnings |
| Phase 1 tree: `export_windows.sh` | `EXPORT PASSED`; the sub-scene is in the pack |
| New suite alone, after the fix | passes, nothing leaked at exit |
| Mutation checks | sub-scene removed → 4 failures; level rebuilt by the builder → 5 failures (door frames caught) (`baseline/mutation_checks.txt`) |
| Views before vs after | Expanded 17/22 identical; the other 5 also differ between two captures of the unchanged commit (spinning card and manuscript); tutorial 9/9 identical (`baseline/views_compare.txt`) |

**Manual tests: none.** I can't run the game on your Windows PC from here. Please check in the editor:
1. **F5:** the menu shows both maps.
2. **Expanded Library:** play a minute, then Pause → Main menu.
3. **Library Tutorial:** it plays as before.
4. **Open `expanded_library.tscn`:** `Expansion` appears after `Gameplay`. **Don't save the scene if the editor offers to**: re-saving can rewrite the file.

## 6. Evidence

- `baseline/views/` (22 views of the baseline map);
- `baseline/views_compare.txt`;
- `baseline/mutation_checks.txt`;
- the listings and `manifest.sha256`;
- `phase-1-logs/`.

## 7. Known bugs, limitations, risks

- **Editor re-save:** opening `expanded_library.tscn` in the Godot editor and saving it may rewrite the file (it was generated by a script). The baseline test checks content, not bytes, so a harmless re-save still passes, but the Git diff would be large.
- **Digest strictness:** any approved change to the existing map (outside `Expansion`) needs new digests in `tests/expanded_baseline_tests.gd`, by design.
- **Capture noise:** 5 Expanded views vary from run to run, so future visual comparisons should use the 17 stable views.
- **Carried over from the baseline:** D2–D8 in `phase-1-baseline.md` (no positional ambience, the intermittent tutorial guard-timing test, nothing verified on Windows, shared-route stalls, Node 20 warning, pacing unconfirmed, unused rooms).

## 8. Tutorial regression

- All Phase 1–14 suites pass.
- `QA FLOW` (tutorial game flow) passes.
- The tutorial's 9 reference views are pixel-identical before and after, and to `docs/performance/visual/after_2splits_2048/`.
- `library_graybox.tscn` and every shared script are unchanged.

## 9. Git branch and working tree

- **Branch:** `Development`, starting from `7d73492`. No commits, pushes, merges or branch changes by me.
- **After delivery,** the owner's working tree should show:
  - **modified:** the 6 files listed as changed above (`expanded_library.tscn`, `test_scene.gd`, `export_windows.sh`, `README.md`, `REGRESSION_CHECKLIST.md`, `LEVEL_LOG.md`);
  - **untracked:** `scenes/level/expanded_library_expansion.tscn`, `tests/expanded_baseline_tests.gd` (+ `.uid`), `docs/expanded/expansion/`.
- I can't run `git status` on your PC: please run it to confirm.

## 10. Recommendation

**PASS.** All criteria are met with executed evidence. The only open items are your manual editor check above and the long-standing Windows checks.
