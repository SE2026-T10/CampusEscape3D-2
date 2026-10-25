# Expanded Library — puzzle specifications (expansion Phase 4, layout x3)

The source of truth is `tools/expanded/expansion/expansion_layout.gd` (`MISSION`, `DOCUMENTS`, `MISSION_OBJECTIVES`). The scripts are in `scripts/systems/puzzles/`. The dependency graph is in [`objective_graph.png`](objective_graph.png).

**Persistence rule** (owner decision: *follow checkpoints*). A puzzle's solved state is part of the mission state (group `checkpoint_state`), stored when a checkpoint is activated:
- **Being caught** undoes what was solved since that checkpoint, together with the doors, items and objectives from the same snapshot.
- **Never stored:** attempt counters, lockouts and alarms. A respawn always gives fresh tries.
- **Kept after respawn:** the journal (documents and clues) and discovered optional objectives. They are knowledge.
- **Nothing is consumed**, and every reset returns to a solvable state, so a mandatory step can never become unreachable.

**Feedback rule:** every attempt gets a HUD message and a display on the puzzle itself. A wrong attempt says *that* it was wrong, never *what* is wrong.

| # | Puzzle | Kind | Where | Needs | Solution and clue | Wrong attempt | Stored at a checkpoint |
|---|---|---|---|---|---|---|---|
| P1 | **Electrical panel cover** (`ToolMechanism`) | mechanism | Electrical room, on the cabinets (41, 1.35, −26.9) | the tool kit, carried (it is checked, not used up) | E with the tool kit. Clue: the electrical room notice says the tool kit is in the maintenance bay | without the tool kit: "locked (tool kit needed)"; a rattle noise | cover on/off; completes `open_panel` |
| P2 | **Breaker panel** (`BreakerPanel`) | power | Behind the cover | P1 | Breakers A1 ON, A2 OFF, A3 ON, A4 ON, then MAIN. Clue: the wiring chart in Book Processing (A3 needs A4; A1 shares A3's feed; never A2), plus the circuit names on the breakers | the main trips: an alarm with radius 14 m (guards nearby investigate), the breakers drop to OFF, retry at once; "that circuit setting is wrong" | breaker positions, power on/off (and the `PowerNetwork`); completes `restore_power` |
| P3 | **Vault keypad** (`CodeLock`) | code + security | Archive stacks, beside the Vault Door (27.83, 5.85, −19.3) | power on `archive_vault` (P2); the archive needs the carried card (G2) | **2691**: the founding year 1962 reversed. Clue: the archivist's memo (Office 3) gives the rule; the lobby plaque gives the year (in the world, and as a journal clue) | "code rejected, N tries left" plus a security alarm (radius 22 m, banner, guards investigate); after 3 wrong codes, a 20 s lockout, then fresh tries. Without power: NO POWER | solved (the Vault Door stores its own open state); completes `open_vault` |
| — | **Rare manuscript** (existing `AccessCard`) | the mission item | Vault pedestal (fixed) | `open_vault` ACTIVE→COMPLETED, and the door physically open | E | "Rare manuscript (not yet)" | as before: shown while its objective is not done |
| O-A | **Pump** (`ToolMechanism` crank + `PumpControl`) | mechanism (optional) | Pump room, south wall | the tool kit (crank) | Free the crank; valves 1 and 3 OPEN, 2 SHUT; START. Clue: the pump room log, which also reveals the objective | a loud stall (noise radius 16 m, guards hear it); the valves stay as set, so retry | crank, valve positions, drained; when drained, the grate is clear and the storm drain exit opens; completes `drain_culvert` |
| O-B | **Security locker** (`CodeLock`) | code (optional) | Office 1, west wall | — | **136**: the last digit of each start hour on the night rota (21:00, 03:00, 06:00). Clue: the night rota (Office 2), which also reveals the objective | "code rejected, N tries left" plus a small noise (no alarm); after 3, a 10 s lockout | solved (and so its contents: a bottle and the patrol notes); completes `security_locker` |
| — | **Archive back gate G3** (existing one-way `AccessDoor`) | shortcut (optional) | Archive hall | inside the archive | E from the archive side | "only opens from the other side" | open/closed; completes `unlock_shortcut` |

**Escapes** (either one ends the level):
- **Loading dock exit** (`ExitDoor`): needs `take_manuscript`.
- **Storm drain exit** (`ExitDoor` with `extra_key_objective_id = drain_culvert`): needs the manuscript and the drained culvert.
- **Main entrance:** reserved. `SecurityAlarm.main_entrance_lockdown` stays true; the security phase will lift it.

**Interfaces for later phases** (documented in the scripts):
- **`PowerNetwork`:** `find(node)`, `is_powered(circuit)`, `set_powered(circuit, on)`, `power_changed(circuit, on)`. Circuit `archive_vault`.
- **`SecurityAlarm`:** `find(node)`, `raise_alarm(position, reason, radius)`, `is_active()`, `alarm_raised` / `alarm_cleared`, `main_entrance_lockdown`. It answers only with the existing systems: a noise that guards investigate, and a HUD banner.
- **`Puzzle`** (base): `feedback(text, good)`, `solved`, `objective_id`, checkpoint state.
- **`PuzzleControl`:** one dial, breaker, valve or button.
