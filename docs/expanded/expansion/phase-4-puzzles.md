# Expanded Library expansion — Phase 4: puzzles, journal and objectives

**Date:** 2026-10-16 · **Branch:** `Development` (at `7d73492`; Phases 1–4 uncommitted in the working tree) · **Engine:** Godot 4.7.2 stable · **Layout:** x3

**Owner decisions (asked before building):**
- the mission graph as proposed;
- extend `ObjectiveManager` with prerequisites and optional objectives (the tutorial keeps its linear flow);
- **puzzles follow checkpoints**;
- escapes: the loading dock and the storm drain, with the main entrance reserved behind a documented security interface.

## 1. Summary

**Mission.** Players explore freely, with clear mandatory prerequisites (graph: [`phase-4/objective_graph.png`](phase-4/objective_graph.png)):
1. Enter the library.
2. Take the staff access card and find the tool kit, in either order.
3. **P1** Open the electrical panel cover (it needs the tool kit).
4. **P2** Set the breakers (power).
5. **P3** Enter the vault keypad code (code and security; it needs the power, and the archive needs the carried card).
6. Take the rare manuscript from its fixed pedestal.
7. Escape by **either** the loading dock **or** the storm drain.

Optional:
- **O-A** the pump (crank, valves, START), which opens the storm drain;
- **O-B** the Office 1 security locker (a bottle and patrol notes);
- the back-gate shortcut (it is no longer mandatory).

**Puzzle interactions: 5.** Two mechanisms (P1, O-A), power (P2), code with security (P3), code (O-B). Full specification, with solutions, clues, wrong-attempt behaviour and persistence for each: [`phase-4/puzzle_specs.md`](phase-4/puzzle_specs.md).

**Clues** connect documents and the environment:
- the wiring chart (Book Processing), together with the circuit names on the breakers;
- the archivist's memo (Office 3, the rule) and the lobby plaque (the year, readable in the world);
- the pump room log;
- the night rota.

**Wrong attempts:**
- breakers: the main trips, with an alarm;
- vault keypad: an alarm each time, then a 20 s lockout after three;
- pump: a loud stall;
- locker: a small noise.

Alarms are noises the guards investigate, plus an "ALARM" banner. Feedback says that an attempt was wrong, never what is wrong. Nothing blocks progress for good.

**Journal (J)** shows:
- the mission (mandatory objectives);
- the discovered optional objectives;
- every clue;
- one document in full: J pages through the documents, or closes the journal after reading one.

It keeps everything after a respawn. Hidden optional objectives appear only once discovered (reading their clue) or completed.

**HUD:**
- "MISSION n/8";
- several objectives can be current at once ([>]);
- an OPTIONAL section;
- messages for every puzzle attempt.

**Interfaces left for later phases:**
- `PowerNetwork`;
- `SecurityAlarm` (`raise_alarm`, `main_entrance_lockdown`).

The full camera and power systems are not implemented.

## 2. Exact files changed

**New**
| File | What |
|---|---|
| `scripts/systems/puzzles/puzzle.gd` | `Puzzle` base: feedback, solved, objective link, checkpoint group |
| `scripts/systems/puzzles/puzzle_control.gd` | `PuzzleControl`: dial, breaker, valve or button (an `Interactable`) |
| `scripts/systems/puzzles/code_lock.gd` | `CodeLock`: keypad or combination, power, alarm, lockout, door, reveals |
| `scripts/systems/puzzles/breaker_panel.gd` | `BreakerPanel`: the power puzzle |
| `scripts/systems/puzzles/pump_control.gd` | `PumpControl`: the pump puzzle (grate, sign) |
| `scripts/systems/puzzles/power_network.gd` | `PowerNetwork`: power interface |
| `scripts/systems/puzzles/security_alarm.gd` | `SecurityAlarm`: alarm interface |
| `tests/expanded_puzzle_tests.gd` | the Phase 4 suite |
| `tools/expanded/expansion/mission_x3.py` | minimal, idempotent patch of `expanded_library.tscn` (objectives, dock exit) |
| `tools/expanded/expansion/capture_puzzles.gd` | screenshot tool |
| `docs/expanded/expansion/phase-4-puzzles.md`, `docs/expanded/expansion/phase-4/` | this report, the graph, the specifications and the evidence |
| `.uid` files | created by Godot |

**Modified**
| File | Change |
|---|---|
| `scripts/systems/objectives/objective_manager.gd` | graph mode (`requires`, `optional`, `hidden`, `discover`, `try_complete`); linear mode untouched |
| `scripts/systems/objectives/exit_door.gd` | optional `extra_key_objective_id` (the storm drain) |
| `scripts/systems/inventory/tool_mechanism.gd` | optional `objective_id`; a removed cover hides and stops catching the interaction ray |
| `scripts/systems/inventory/item_pickup.gd` | optional `objective_id` (the tool kit) and `available` (locker contents) |
| `scripts/systems/inventory/document_pickup.gd` | `kind` (document or clue), `model` (plaque), `display_text`, `discovers_objective`, `available` |
| `scripts/player/player_inventory.gd` | journal entries carry a kind |
| `scripts/ui/objective_hud.gd` | graph checklist and header, OPTIONAL section, discovery and puzzle messages, the new journal |
| `scripts/ui/stealth_hud.gd` | ALARM banner |
| `scripts/ui/game_menus.gd` | win text counts mandatory and optional objectives |
| `scenes/level/expanded_library.tscn` | **two existing nodes:** the ObjectiveManager's `objectives` (the graph) and the dock ExitDoor's key, prompt and message |
| `scenes/level/expanded_library_expansion.tscn` | rebuilt with x3 (ids kept): `Mission`, `VaultDoor`, new documents, the locker bottle; geometry identical |
| `tools/expanded/expansion/expansion_layout.gd`, `build_expansion.gd` | x3 data and builder |
| `tests/expanded_mission_tests.gd` | the original mission tests moved onto the graph (see section 5) |
| `tests/expanded_baseline_tests.gd` | the approved new objective list (old list kept in a comment) |
| `tests/test_scene.gd` | runs the new suite; pass line |
| `tools/map_flow.gd` | its progress check accepts at least 2 completed objectives (opening the back gate now also completes the optional shortcut) |
| `README.md`, `docs/expanded/LAYOUT.md`, `docs/expanded/LEVEL_LOG.md`, `docs/qa/REGRESSION_CHECKLIST.md` | mission, tests, layout x3, log, checklist row |

**Not changed:**
- the tutorial scene;
- the navmeshes;
- geometry, guards and routes;
- the frozen builder.

## 3. Existing systems reused

| Existing system | How Phase 4 reuses it |
|---|---|
| `ObjectiveManager` | Extended in place (owner decision). No second mission tracker. |
| `Interactable` / `PlayerInteractor` (E) | Every control is an `Interactable`. |
| `AccessDoor` | The Vault Door, keyed to `open_vault`. Guards pass it, as they pass every door. |
| `AccessCard` | The manuscript, unchanged. |
| `ExitDoor` | Both escapes. |
| `ToolMechanism` | The cover and the crank. |
| `ItemPickup` / `DocumentPickup` / `PlayerInventory` journal | Items, clues and journal entries. |
| `CheckpointManager` (`checkpoint_state`) | Persistence. |
| `NoiseSystem` and guard hearing | Alarm and stall responses. |
| `ObjectiveHud`, `StealthHud`, `GameMenus` | Extended in place. |
| Expansion sub-scene, layout data and builder | Placements. |

## 4. Acceptance criteria

| Criterion | Result | Evidence |
|---|---|---|
| Mandatory progression has no unresolved dependencies | **PASS** | All prerequisites exist; a topological order exists (no cycle); every mandatory objective has a node that completes it; two full routes reach WIN with real input |
| The archive can't be accessed without its prerequisites | **PASS** | G2 needs the carried card; the Vault Door can't be opened by hand and physically stops the player; the keypad needs power, which needs the cover, which needs the tool kit |
| The mission item can't be collected before its puzzle is solved | **PASS** | "Rare manuscript (not yet)" inside the vault until `open_vault` is done, and the door is closed |
| At least four meaningful puzzle interactions work | **PASS** | Five: cover, breakers, vault keypad, pump, locker, each solved in tests with real E presses |
| Wrong attempts don't permanently block critical progress | **PASS** | Breakers: trip, then retry works. Keypad: three wrong codes give three alarms and a 20 s lockout, then the right code works. Pump: stall, then retry works. A respawn resets tries and lockouts |
| Optional objectives don't become mandatory gates | **PASS** | No mandatory objective requires an optional one; route 1 wins with 0/3 optional done; the back gate opened early completes only the optional shortcut |
| Journal and objective state consistent after revisiting areas | **PASS** | Re-reading documents adds nothing; puzzle and objective states agree after each of three captures; the journal and discoveries are kept |
| Relevant puzzle and objective tests pass | **PASS** | The final full suite passed, with only the 8 expected warnings (section 5) |

**Additional:**
- clues never state a code outright, and no hint, title or message contains a code;
- hidden optional objectives stay hidden until their clue is read.

## 5. Tests actually run (Linux VM, Godot 4.7.2 official)

**New suite:** `tests/expanded_puzzle_tests.gd`. Its sections:
- the graph data;
- graph-mode unit checks;
- route 1 (loading dock);
- route 2 (storm drain);
- invalid sequences;
- the optional locker;
- persistence.

**Changed existing tests** (because of the approved mission change):
- **`expanded_mission_tests.gd`:**
  - the objective list comes from the layout;
  - "exactly one ACTIVE" became "ACTIVE exactly when the prerequisites are done";
  - expected current objectives were updated, and the HUD headers are now "MISSION n/8";
  - the dock opens with the manuscript; the back gate is optional;
  - where the manuscript is needed, `_prepare_vault()` solves the puzzles through their own interactions;
  - all door, item, capture and guard-reset checks are kept.
- **`expanded_baseline_tests.gd`:** the new objective list.

**Results** (logs in `phase-4/logs/`):

| Run | Result |
|---|---|
| `tools/ci/validate.sh` | VALIDATION PASSED (117 scripts) |
| Full suite, final run (`tools/ci/run_tests.sh`) | **All tests passed**, 8 expected warnings, 0 errors. The pre-existing tutorial guard timing check also passed this time |
| Full suite, earlier run (before the final HUD and journal tweaks) | All tests passed |
| QA FLOW | PASSED (15) |
| MAP FLOW, first run | **3 failures:** "Expanded Library — progress made before restarting". The tool completes two objectives and opens every door; opening the back gate now also completes its optional shortcut, so it counted 3 where it expected exactly 2 |
| MAP FLOW, after the fix | PASSED (52). `tools/map_flow.gd` now accepts "at least 2" (commented) |
| `tools/ci/export_windows.sh` | EXPORT PASSED |

**Fix outside the planned files:** `tools/map_flow.gd`, the one-line check described above.

**Deliberate-break checks** ([`phase-4/mutation_checks.txt`](phase-4/mutation_checks.txt)): each break made the suite fail.
- M1: the keypad works without power;
- M2: the keypad accepts any code;
- M3: optional objectives needed to finish;
- M4: a respawn keeps the lockout.

**Manual tests:** none (no access to your editor). The steps are in the regression checklist, row "Expanded Library puzzles, journal and objectives".

## 6. Evidence

All in `docs/expanded/expansion/phase-4/`:
- `objective_graph.png` (and its `.dot` source): the objective dependency graph;
- `puzzle_specs.md`: the puzzle specifications;
- `screens/`: 13 screenshots, all on one sheet in `contact_puzzles.png`:
  - plaque clue;
  - cover locked without the tool kit;
  - wrong breakers (trip and ALARM);
  - wiring chart in the journal;
  - power restored;
  - wrong code (alarm);
  - keypad lockout;
  - code accepted, vault open;
  - pump stall;
  - pump drained, grate gone;
  - locker open with its reward;
  - journal with mission, clues and memo;
  - objective panel with the OPTIONAL section;
- `logs/`: test, flow and export logs.

## 7. Known limitations and risks

- **Graybox look:** the puzzle visuals are simple boxes and labels.
- **Locker cabinet:** a dark box without collision, so it can be walked into.
- **Placement:** clue and puzzle placement is checked by the tests' reach checks and the screenshots, not by playtesting. The 20–30 minute pacing hasn't been re-measured.
- **Mission length and difficulty:** a longer mission (basement, electrical room, archive) without new checkpoints. Since puzzles follow checkpoints, a capture can undo several puzzle steps. Checkpoints near the puzzles may belong in the balance phase.
- **Main entrance escape:** reserved only.
- **Power interface:** `PowerNetwork` powers one circuit and switches no lights.
- **Alarm:** a noise and a banner only; no cameras.
- **Playtest bot not updated:** `tools/expanded/playtest_bot.gd` (the old Phase 5 balance tool, not run by CI) still follows the old five-step mission.
- **Not verified on Windows.**
- **Editor re-save:** don't re-save `expanded_library.tscn` in the editor.
- **Old tutorial test:** the pre-existing tutorial guard timing test (Phase 3 report) can still fail at random. Its fix still waits for your approval.

## 8. Tutorial regression

The tutorial scene is unchanged. `ObjectiveManager` runs it in linear mode, which is unchanged (the unit check and every tutorial suite confirm it). The tutorial has no puzzles, no journal and no alarm.

## 9. Git

`Development` at `7d73492`, with Phases 1–4 uncommitted. Commit each phase separately after checking `git status`.

## 10. Recommendation

**PASS.** Every acceptance criterion is met with executed evidence. Manual play in the editor and on Windows remain open.

Stop for approval before Phase 5.
