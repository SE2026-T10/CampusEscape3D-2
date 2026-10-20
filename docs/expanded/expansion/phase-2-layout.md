# Expanded Library expansion: Phase 2, layout expansion

Date: 2026-10-15. Starting point: `Development` at `7d73492` plus Phase 1 (delivered, not yet committed). Delivered to the owner's folder on `Development`; nothing committed or pushed by me.

**Recommendation: PASS** (details in sections 4 and 10).

## Owner decisions (asked before building)

| Decision | Answer |
|---|---|
| Layout as proposed ([`phase-2/phase2_proposal.png`](phase-2/phase2_proposal.png)): west and east annexes, a basement tunnel under the north side, a storm-drain branch | approved as drawn |
| Cut 3 doorways into existing walls (B west, D east, B / Study 1); edits outside the Expansion sub-scene; new baseline values | approved |
| Navigation | rebake one navmesh including the new areas |
| Escape route 3 | the main entrance (security lockdown, reserved) |

**Consequence handled without changing the agreed design:** zone D needed the staff card before (the mission and its tests rely on it). A plain doorway from the basement into Book Processing would have bypassed that. Cut 2 is therefore a staff-card door (the existing `AccessDoor`, like G2 and G4). The tests prove D is still cut off without the card.

## 1. Comparison with the target, and what was built

| Target zone | Before | Phase 2 |
|---|---|---|
| A Entrance & lobby | met | unchanged |
| B Main book stacks | 3 routes | **hub, 5 routes**: + west service door (cut 1, at the cross aisle), + Study 1 door (cut 3) |
| C Reading & study wing | met | Study 1 gains the door to the stacks |
| D Service & electrical | no electrical room | **+ Electrical Room** (annex east of Book Processing, card door) |
| E Staff offices & upper stacks | met | unchanged |
| F Restricted archive | met | unchanged |
| G Basement / service network | missing | **new**: west service stair, service tunnel (4 m × 90 m), maintenance bay, pump room, storm drain, east service stair, east corridor, cable bay |
| Three escape routes | 1 (the loading dock) | 1 dock (existing) + 2 storm drain + 3 main entrance, **reserved** (marked; the grate is closed) |

**As built:** [`phase-2/zone_connections_asbuilt.png`](phase-2/zone_connections_asbuilt.png) (plan and zone-connection diagram, drawn from the layout data).

**Added areas** (all in `scenes/level/expanded_library_expansion.tscn`):
- **West Service Stair annex:** a ground landing, then a 3.35 m ramp down 4 m (21.8°). The basement alcove sits beside it.
- **Service Tunnel:** under the north side (x −44…46, z −27…−23, y −4), with 2 crates.
- **Maintenance Bay:** off the tunnel; hiding spot.
- **Pump Room:** a full-height pump unit as cover; reserved for the pump puzzle.
- **Storm Drain:** north to a sealed grate; reserved as escape 2.
- **East Service Stair:** a 3.35 m ramp from the Electrical Room down to the east corridor and the cable bay (hiding spot).
- **Electrical Room:** cabinets along the north wall; staff-card door to Book Processing; reserved for the power / security puzzle.
- Overall: 3 new hiding spots; 17 lamps (the existing `ceiling_light.tscn`); signs; door headers.

**Modified areas (existing scene, approved):**

| Cut | Wall | Doorway | Scene changes |
|---|---|---|---|
| 1 | B west outer wall (`Wall05_0`) | z −10…−8, 2.0 × 2.6 m | body shortened; `Wall05_0_cut` and `Header_WestServiceDoor` added; 3 decoration boxes split |
| 2 | D east outer wall (`Wall06_0`) | z −24…−22, card door | body shortened; `Wall06_0_cut` and `Header_ElectricalRoomDoor` added; 4 decoration boxes split |
| 3 | B / C wall (`Wall07_0`) | z −22…−20 | body shortened; `Wall07_0_cut` and `Header_Study1StacksDoor` added; 5 decoration boxes split |

Also in the existing scene:
- the `NavigationRegion3D` joined the group `expanded_navigation_source`;
- three shape resources that are no longer used were dropped.

The navmesh file was rebaked: 898 → 1,020 polygons.

The listing diff against the Phase 1 baseline shows **nothing else changed**: the geometry differs only in these 9 bodies and the decoration only in the 7 batches holding the 12 split boxes; the actors digest (guards, routes, doors, checkpoints) is identical.

## 2. Files changed

| File | Change |
|---|---|
| `scenes/level/expanded_library.tscn` | the 3 cuts (above), the navigation region's group |
| `scenes/level/expanded_library_expansion.tscn` | generated: the new areas (was empty) |
| `scenes/level/expanded_library_navmesh.tres` | rebaked from the group (1,020 polygons) |
| `tools/expanded/expansion/expansion_layout.gd` | **new**: layout data (x1) |
| `tools/expanded/expansion/build_expansion.gd` | **new**: builds the sub-scene only |
| `tools/expanded/expansion/bake_navmesh.gd` | **new**: rebakes the level's navmesh from the group |
| `tools/expanded/expansion/cut_doorways.py` | **new**: the reviewable, idempotent patch that made the 3 cuts |
| `tools/expanded/expansion/compare_navmesh.gd` | **new**: compares with an older navmesh |
| `tools/expanded/expansion/capture_expansion.gd` | **new**: views and plans |
| `tests/expanded_layout_expansion_tests.gd` (+ `.uid`) | **new** suite (section 5) |
| `tests/test_scene.gd` | runs it; pass line "…, Expanded Library expansion layout, Expanded Library expansion baseline)." |
| `tests/expanded_baseline_tests.gd` | approved new baseline (geometry, decoration, 269 collision objects, 1,020 polygons); history in comments |
| `tests/expanded_graybox_tests.gd` | the electrical room door counts as a card door in the gates check; the expansion's gameplay and debug markers are skipped by the dressing check, as the level's are |
| `tests/expanded_ai_tests.gd` | the building's outline and depth include the annexes and the basement; outside test points moved off the annexes; 5 access doors in the tour |
| `docs/expanded/LAYOUT.md` | new section "Expansion (2026), layout x1" |
| `docs/expanded/LEVEL_LOG.md` | entry "x1" |
| `docs/expanded/expansion/phase-1-baseline.md` | note: baseline updated in Phase 2 |
| `docs/expanded/expansion/phase-2-layout.md` | **new**: this report |
| `docs/expanded/expansion/phase-2/` | **new**: evidence |
| `README.md`, `docs/qa/REGRESSION_CHECKLIST.md` | architecture line, test description, pass line, a checklist row |

## 3. Existing systems reused

- **Gameplay:**
  - `AccessDoor` for the card door: same set-up as G2 and G4; guards pass it, it blocks the player, sight and noise; checkpoints restore it.
  - `HidingSpot` and `NoiseMaker`.
  - The level's `ObjectiveManager`: the door's key is the existing `take_card` objective.
- **Look and lights:**
  - `scenes/props/ceiling_light.tscn` for every lamp.
  - The level's palette, read from the frozen builder's `LOOKS`, not copied.
  - The level's render-layer scheme (ground 4) plus one new layer for the basement.
- **Navigation:** the existing bake settings (static colliders on layer 1, agent height 1.75, region min size 8). Only the geometry source changed: from the region's children to a group holding the region and `Expansion/Geometry`.
- **Tests:** the real-input walk and guard-tour patterns of `expanded_graybox_tests` and `expanded_ai_tests`, and `TestUtils`. Map loading and switching are covered by the existing map-selection and flow tests.
- **No new runtime script.** The game code is unchanged; only scenes, the navmesh, tools and tests changed.

## 4. Acceptance criteria

| Criterion | Result | Evidence |
|---|---|---|
| The existing map is visibly expanded rather than replaced | **PASS** | before/after views of the 3 doorways; new areas; [`phase-2/`](phase-2/) |
| Existing rooms and assets remain, unless an approved change requires otherwise | **PASS** | listing diff: only the 9 cut-wall bodies and 7 decoration batches changed (the approved cuts); actors digest identical; every place of the v4 navmesh kept |
| All seven target zones exist | **PASS** | zone nodes A–G found (test A); table above |
| Critical paths connect across both floors and the service network | **PASS** | 15 places reached from the spawn, ground, basement and upper floor via existing stairs (test B); card rule (test G); the existing gates and mission tests pass |
| The player can navigate all intended routes | **PASS** | real-input walk: 14/14 places, 204 m, down the west and up the east service stair (test E); existing route walks pass |
| No critical area blocked by collision or navigation errors | **PASS** | doorways clear 2.0 × 2.6 m, stairs 3.35 m / 21.8° / 2.2 m+ headroom (test D); guard tour 13/13, 0 stuck (test F); no stray, roof or wall navmesh |
| The tutorial remains unchanged in behaviour | **PASS** | all tutorial suites, `QA FLOW PASSED`; tutorial scene and shared scripts untouched |

## 5. Tests actually performed (Linux VM, Godot 4.7.2 stable official)

| Run | Result |
|---|---|
| `validate.sh` | `VALIDATION PASSED` (98 scripts) |
| `run_tests.sh`, final | `All tests passed (… Expanded Library mission, Expanded Library expansion layout, Expanded Library expansion baseline).`; exactly the 8 expected warnings; no errors; `QA FLOW PASSED (15 checks, 4 levels loaded)`; `MAP FLOW PASSED (52 checks, 12 levels loaded, 3 cycles)` |
| `export_windows.sh` | `EXPORT PASSED` |
| One earlier full run of the same tree | **3 failures, all in the tutorial's `guard_tests`:** "GuardMain waited 3.20s at point 1, expected 3.00s" (and 2.20 vs 2.00 s for GuardRestricted and GuardEast). This is the known machine-timing failure documented in the original Phases 4–5 (reproduced there on unmodified code; baseline item D3). I was copying evidence files during that run. Re-run on an idle machine: all passed (the final row above). Both logs are in `phase-2/logs/` |
| `compare_navmesh.gd` against `7d73492` | 0 old places lost; new places only at the 3 doorways (16 / 11 / 16 samples), none elsewhere ([`phase-2/navmesh_compare.txt`](phase-2/navmesh_compare.txt)) |
| Deliberate-break checks | [`phase-2/mutation_checks.txt`](phase-2/mutation_checks.txt) |

**Failures found during the phase, and fixed:**
1. The first suite run on the new map had 13 failures, all from the approved changes: the baseline values (5), the AI test's outline and depth limits and an outside point that now lies in the annex (3), the 5th access door in the tour (1), the gates check not yet knowing the new card door (3), and debug labels in the dressing check (1). The tests were updated as listed in section 2. With the card door known, the gates check proves the card rule.
2. The dressing check found two real problems:
   - **The pump unit's top was walkable for the navmesh, under a lamp.** It's now a full-height column.
   - **The S2 stair-top navmesh ran onto the east wall.** Any geometry east of the building makes the bake treat that wall's top (at the stair's height) as walkable. Diagnosis: three in-memory bakes, then a test with one tiny box at different distances. Fix: an invisible cap on the wall top inside the existing decorative wall's volume (`SEALS`). A new test check keeps the navmesh off the outer walls.
3. **The new suite leaked navigation regions** (an `ERROR` line at exit). Fixed: it now frees them.

**Manual tests: none.** Please check in the editor (F5 → Expanded Library):
1. Walk from the lobby into the main stacks' cross aisle, west through the new service door and down the stair.
2. Follow the tunnel; look into the bay, the pump room and the drain (the grate is closed).
3. Take the east stair up into the electrical room. The card door to Book Processing refuses without the card.
4. Use the Study 1 door from the stacks.
5. Play the tutorial briefly.

**Don't save `expanded_library.tscn` in the editor**: re-saving can rewrite the whole file.

## 6. Evidence

[`phase-2/`](phase-2/):
- `before/` and `after/`: views of the 3 doorways and the ground plan, the same viewpoints on both builds;
- `after/`: 11 views of the new areas, plus the basement and ground plans;
- `zone_connections_asbuilt.png` and the approved `phase2_proposal.png`;
- `navmesh_compare.txt`, `mutation_checks.txt`;
- `logs/`: this phase's validate, test, flow and export logs.

## 7. Known bugs, limitations, risks

- **Graybox look:** walls, floors and ramps use the palette, but there are no trims, windows or props beyond crates and cabinets. Signs facing the stairs are seen at an angle, and two basement lamps hang in the open stairwell shafts. Visual polish is a later phase, as specified.
- **No guards in zone G yet.** It's reachable and tested for guards (the tour), but unpatrolled; patrols and balance belong to a later phase. The basement is a quieter route for now: B → G → D needs the card, and B → G only reaches the electrical room.
- **Reserved, not built:** the power / security and pump puzzles, escapes 2 and 3 (markers only, under `Expansion/Layout`, F3).
- **The seal (`S2WallTopCap`):** if the bake area ever changes again, re-run `compare_navmesh.gd`; the margin check in the new test guards the known spot.
- **Pacing (20–30 min) not re-measured;** the new areas only add optional routes so far.
- **Tutorial guard timing test (baseline D3) failed once this phase**, under extra load, with its known signature; the idle re-run passed. A one-line fix to that tutorial test was proposed in the original Phase 5 (wait one frame after changing the time scale). It still needs your approval, because it changes a tutorial test.
- **Nothing verified on Windows.**
- **Editor re-save** (see section 5).

## 8. Tutorial regression

- All tutorial suites (Phases 1–14) and `QA FLOW` (the tutorial game flow) pass.
- `library_graybox.tscn`, its navmesh and every shared script are unchanged.
- The map switching tests (`map_selection_tests`, `MAP FLOW`, the alternating loads in `expanded_baseline_tests`) pass.

## 9. Git branch and working tree

- **Branch:** `Development` (`7d73492`) plus Phase 1 and Phase 2, uncommitted in the owner's folder.
- **Phase 2 adds:**
  - **modified:** the files marked as modified in section 2 (3 scenes / navmesh, 4 tests, 5 docs);
  - **new:** `tools/expanded/expansion/`, `tests/expanded_layout_expansion_tests.gd` (+ `.uid`), `docs/expanded/expansion/phase-2-layout.md`, `docs/expanded/expansion/phase-2/`.
- Please run `git status`. Committing Phase 1 and Phase 2 separately keeps the history readable.

## 10. Recommendation

**PASS.** Every acceptance criterion is met with executed evidence. Manual play on Windows remains open, as in earlier phases.
