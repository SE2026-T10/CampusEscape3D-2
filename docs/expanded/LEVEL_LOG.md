# Expanded Library — design log

One entry per layout version, newest last. Each version is built from `tools/expanded/expanded_layout.gd` (its `VERSION`) and gets:
- **its own evidence folder** `docs/expanded/vN/`;
- **its own git commit(s)** on `Development`.

That way the history is in git as well as in the folders. The commits were planned as `level(expanded-vN): …`; on `Development` they landed under the names below (squashed per phase when pushed). v3 and v4 share one commit: v3's scene was never committed on its own, but its evidence folder `v3/` is kept unchanged.

| Version | Phase | Commit on `Development` |
|---|---|---|
| v0 | 1 (graybox) | `cce1e9a` Library expansion phase 1 |
| — | 2 (map selection; no layout change) | `36e0b8f` Library expansion phase 2 Multi-Map Integration |
| v1 | 3 (guards) | `3896e7c` Expanded library phase 3 navigation and guard |
| v2 | 4 (mission) | `8dd2d63` Expanded library Phase 4 Missions system |
| v3 | 5 (balance) | no commit of its own: pushed together with v4 |
| v4 | 6 (visual pass, door-frame fix) | `484761d` Expanded library phase 5 + 6 |

**Suggested tags** (not created; only the maintainer pushes): `expanded-v0` → `cce1e9a`, `expanded-v1` → `3896e7c`, `expanded-v2` → `8dd2d63`, `expanded-v4` → `484761d`, e.g. `git tag -a expanded-v1 3896e7c -m "Expanded Library v1"` then `git push origin --tags`. The tutorial's log records five versions that landed in one commit.

| Evidence | Made by |
|---|---|
| `vN/layout_ground.png`, `vN/layout_upper.png` (design plans) | `tools/expanded/draw_layout.gd` |
| `vN/top_*.png`, `vN/navmesh_*.png`, `vN/views/*.png` (the built level) | `tools/expanded/capture_graybox.gd` |
| `vN/test_run.txt` | the suite (`tests/expanded_graybox_tests.gd` lines) |
| `v4/views/`, `v4/compare/` (the same player views on any build) | `tools/expanded/capture_views.gd` |
| `v4/lighting.md`, `v4/profile/`, `v4/fingerprint/` | `tools/expanded/light_report.gd`, `profile_expanded.gd`, `collision_fingerprint.gd` |

Screenshots are rendered under a virtual display (Xvfb, Mesa llvmpipe software OpenGL), not on Windows hardware.

---

## v0 — First graybox (Expanded Library Phase 1, 2026-10-09)

Commit: `cce1e9a` (planned as `level(expanded-v0): layout design and floor plans` and `… graybox scene, navmesh and tests`).

**What:**
- Two floors and six zones:
  - ground: A Entrance & Lobby, B Main Book Stacks, C Reading Rooms & Study Wing, D Restricted Service Corridor;
  - upper: E Staff Offices & Upper Stacks, F Restricted Archive.
- Three ramp stairs (S1 lobby, S2 service, S3 stacks).
- Five planned objectives, five planned gates and one planned shortcut.
- Seven planned patrol loops and ten planned hiding spots.

The full design is in [`LAYOUT.md`](LAYOUT.md).

**Why:**
- The archive sits behind a keycard gate pair (front from the staff wing, back from the service stair), so it has a defined progression gate and two approaches.
- The upper floor has three stairs, so a guarded main stair always has a quieter alternative.
- The return route from the archive (back gate → S2 → loading dock) reuses the service corridor instead of adding a seventh zone.

**Metrics (measured on the built scene):**

| Metric | v0 |
|---|---|
| Walkable navmesh, ground / upper | 2,807 m² / 1,660 m² (tutorial: 800 sample metres, single floor) |
| Navmesh polygons | 892 (tutorial: 224) |
| Solid pieces | 215 |
| Main route along the navmesh (spawn → O1 → … → exit) | 273 m (tutorial's shortest spawn → card → exit: 102 m) |
| Planned locations reachable from the spawn | 141 / 141 |
| Gate and approach checks (rebaked with blockers) | 19 / 19 |
| Real-input walk (main route sprinting + 2 alternatives walking) | 494 m in 122 s, never stuck, never fell |

**Evidence:** [`v0/`](v0/)
- plans: `layout_ground.png`, `layout_upper.png`;
- top views: `top_ground.png`, `top_upper.png`;
- navmesh: `navmesh_ground.png`, `navmesh_upper.png`;
- 16 eye-height views in `views/`;
- `test_run.txt`, `mutation_checks.txt`.

**Open for later versions:**
- guards and their real coverage (the patrol loops are only planned);
- locks on the gates and the shortcut;
- cross-floor sight and hearing tuning;
- pacing toward the 20–30 minute target.

---

## v1 — Guards and patrols (Expanded Library Phase 3, 2026-10-09)

Commit: `3896e7c` (planned as `level(expanded-v1): guards, patrols and stair fixes`; one commit with the tests and the guard steering fix).

**What:**
- **Six guards on six loops,** using the existing guard scene and AI unchanged (PATROL / INVESTIGATE / CHASE):
  - lobby (P1);
  - two in the main stacks (P2 outer, P2b inner with the browsing hall);
  - upper stacks (P5, watching both stair tops);
  - archive (P7);
  - a connector (P8) that goes up S1 and down S3 through both staff doors.
- **Planned only:** P3, P4 and P6 have no guard yet.
- **Stair balustrades are now vertical panels.** The v0 panel was turned with the slope, leaned past the foot of the ramp and caught guards.
- **Navmesh rebaked:** 891 polygons; 2,805 m² on the ground floor and 1,663 m² upstairs.

**Why:**
- the suggested distribution: one lobby guard, two in the main stacks, one upstairs, one in the archive, and one connecting the floors;
- the spawn stays unseen;
- every route still has gaps between watches.

**Metrics:**

| Metric | v0 | v1 |
|---|---|---|
| Guards | 0 | 6 |
| Loop lengths | — | 51, 99, 76, 101, 59, 180 m |
| Main route along the navmesh | 273 m | 272 m |
| Main route ever seen by a guard (standing) | — | 81% of its metres |
| Main route watched < 5% of the time ("safe") | — | 40% |
| Mean / peak exposure along the main route | — | 8.5% / 27% (crouched 7.9%) |
| 900 s soak: stuck events / state changes | — | 0 / 0 |

**Evidence:** [`v1/`](v1/)
- plans with the guard loops: `layout_*.png`;
- top views: `top_*.png`; navmesh: `navmesh_*.png`;
- `views/`;
- `soak/report.md` and `soak/summary.json`;
- `test_run.txt`, `mutation_checks.txt`.

---

## v2 — The mission (Expanded Library Phase 4, 2026-10-09)

Commit: `8dd2d63` (planned as `level(expanded-v2): mission, access doors and checkpoints`; one commit with the mission systems and tests).

**What:**
- **Five objectives** in the existing ObjectiveManager: enter the library → take a staff access card (Office 2) → retrieve the rare manuscript (vault) → unlock the archive back gate → escape through the loading dock.
- **Access doors** (new `AccessDoor`, an `Interactable`):
  - card doors G2 (Archive Front Gate) and G4 (Lobby Staff Door);
  - one-way doors G3 (Archive Back Gate, the return shortcut; completes O4) and SC1 (Service Shortcut, optional).
  - A closed door is a solid world-layer panel that is not baked into the navmesh; guards pass it, the player and sight don't.
- **G1a and G1b are plain doors now.** The v0/v1 plan locked the staff wing behind a key code (O1); the mission's O1 is "enter the library" and the card in the staff wing is what unlocks the restricted areas.
- **The exit** is the existing ExitDoor, sealed until O4.
- **Three checkpoints:** Study Rooms, Staff Offices (back of Office 2), Storage. Being caught restores the mission state saved at the last checkpoint, doors included.
- **Connector patrol point** in the staff corridor moved from x 3 to x 6, off the line through G1a and the Office 2 door.
- **Layout markers** (`Layout/…`) are hidden in play and shown with the debug overlay (F3); the mission has its own pickups, doors and HUD.

**Why:**
- The card has to matter: it opens both restricted areas (the service corridor and the archive), and the archive has no other way in.
- The shortcut has to pay off: vault → exit is 66 m through G3 against 111 m the long way (41% shorter), past fewer guards; and the exit only opens once G3 is open.
- The Staff Offices checkpoint started at the office door, where the connector guard looked straight in through G1a (the AI test caught it: in view 7 s of the run). It moved to the back of the office, more than 14 m from the corridor.

**Metrics:**

| Metric | v1 | v2 |
|---|---|---|
| Mission | — | 5 objectives, 4 access doors, exit, 3 checkpoints |
| Main route along the navmesh | 272 m (via the old O1 in Study 3) | 197 m |
| Way out of the archive: shortcut / long way | — | 66 m / 111 m |
| Main route ever seen by a guard (standing) | 81% | 79% |
| Main route watched < 5% of the time ("safe") | 40% | 41% |
| Mean / peak exposure along the main route | 8.5% / 27% | 8.5% / 28% (crouched 7.9%) |
| Checkpoint respawn points ever watched (900 s soak) | — | 0% / 0% / 0% |
| 900 s soak: stuck events / state changes | 0 / 0 | 0 / 0 |
| Full mission with real input, no guards | — | 190 m walked, 5 interactions, WIN |

**Evidence:** [`v2/`](v2/)
- plans with doors and checkpoints: `layout_*.png`;
- top views: `top_*.png`; navmesh: `navmesh_*.png`; `views/` (18 eye-height views);
- the mission step by step with the HUD: `mission/01_start.png` … `mission/08_win.png`;
- `soak/report.md` and `soak/summary.json` (with checkpoint exposure);
- `test_run.txt`, `mutation_checks.txt`.

**Open for the balancing phase:**
- the service corridor (zone D) has no guard (P4 planned);
- the 20–30 minute target needs timed playtests;
- hiding spots are still markers.

---

## v3 — Stealth balance (Expanded Library Phase 5, 2026-10-10)

Commit: none of its own on `Development`; pushed in `484761d` with v4 (planned as `level(expanded-v3): stealth balance from playtests`; one commit with the balance tools and tests).

**What:**
- **Patrols:**
  - P2b's guard moved to **P4 Service Corridor** (zone D);
  - P5's S1-top point moved from 3 m to 9 m from the stair;
  - P7's hall leg turned away from the back gate;
  - P1's north leg moved off the main doors.
- **This level's guards:** detection meter rises at 20–80 per second (tutorial: 12–60), chase speed 5.6 m/s (tutorial: 4.2).
- **An entrance screen** (2.2 m) inside the main doors.
- **Hiding spots:** 13 real HidingSpots with floor marks (3 new).
- **14 signs**, red where restricted.
- **Staff Offices checkpoint:** the pad covers the front of the card desk; the respawn point stays at the back.
- **One-way doors** read red from their locked side.

**Why:** coverage maps and five rounds of automated playtests (about 110 runs). The full findings are in [`phase-5-balance.md`](phase-5-balance.md):
- zone D was never watched;
- the "quiet" stacks route was the noisier one;
- the S1 top and the back gate's landing were face-to-face encounters;
- a missed checkpoint, and then the entrance, sent players into capture loops;
- a player ignoring the guards finished faster than a careful one.

**Metrics:**

| Metric | v2 | v3 |
|---|---|---|
| Zone D watched (corridor / storage / dock) | 0.3% / 0% / 0% | 13.4% / 4.7% / 7.3% |
| Browsing hall / main stacks watched | 14.6% / 10.6% | 5.9% / 6.8% |
| Porch watched | 2.6% | 0.3% |
| Main route: mean exposure, exposed metres | 8.5%, 20.1 | 11.2%, 27.0 |
| Way out: shortcut / long way (exposed metres) | — / 13.7 | 7.9 / 20.4 |
| Careful playtester: completed, active time | 16/16, 1:25–6:16 (one run with 2 captures at the landing) | 18/18, 1:13–2:44 |
| Learner playtester (first-timer who learns) | 6/6, 4:12–7:02 | 6/6, 2:51–4:13, 2–3 captures |
| Reckless playtester (ignores guards) | 3/3 finish, 1:12–1:36 | 0/3 finish (30 captures) |
| Restored-state checks after captures | — | 107, 0 violations |
| Navmesh polygons | 891 | 898 (the screen) |

**Evidence:** [`v3/`](v3/)
- plans, views, `mission/` (11 views);
- `coverage/v2_before`, `coverage/v3_after`;
- `playtests/` (rounds 1–5);
- `test_run.txt`, `mutation_checks.txt`.

**Open:**
- human playtests (`PLAYTEST_PROTOCOL.md`);
- the 20–30 minute target (probably not reached; adjustment plan in the phase report).

---

## v4 — Visual pass (Expanded Library Phase 6, 2026-10-11)

Commit: `484761d` (planned as `level(expanded-v4): visual pass in the tutorial's style`; one commit with the visual-pass tools and tests).

**What:** the level dressed in the tutorial's low-poly library look on both floors, all of it decoration with no collision, built by the builder from the layout data (the data only gains a `look` per furniture group; no geometry changed):
- the tutorial's palette for walls, floors by room, wainscots (red in the restricted zones), door trims and headers;
- bookcases with books (`ShelfBooks`), tables with tops and chairs (`chair.tscn`), desks with monitors and lamps, the circulation desk with the globe, planters, racks with boxes, crates, the vault pedestal;
- stair stripes and landing strips, brass-capped balustrades; rugs, the archive runner, hazard stripes at the exit;
- windows, clocks, posters; ceilings, a roof, the outer walls above the double-height halls;
- 84 ceiling lights and pendants (`ceiling_light.tscn`) and accents on the card, the manuscript, the card gates and the exit; ambient 0.50, the tutorial's key light, sun shadows within 40 m.

**How it stays within the renderer** (Compatibility: 32 lights in view, 8 per mesh): shorter-range lights with distance fade, per-floor render layers and light masks, and the static boxes merged into `BatchedBoxes` MultiMeshes (new script), split where a batch would reach more than 8 lights. `ShelfBooks` gained two optional properties (`layers`, `draw_distance`) with defaults that keep the tutorial unchanged.

**Why:** Phase 6 (visual polish) without touching the tested layout and balance. The full report: [`phase-6-visual-polish.md`](phase-6-visual-polish.md).

**Metrics:**

| Metric | v3 | v4 |
|---|---|---|
| Navmesh file | — | byte-identical to v3 (898 polygons) |
| Collision fingerprint (263 collision objects, 6 guards, 41 patrol points) | — | identical to v3 |
| Playtest matrix (27 runs) | Phase 5 final | 25 identical; 2 run-to-run variations (same on both builds when re-run) |
| Decoration in the walkable space (suite check) | — | 0 |
| Lights in view / per mesh (limits 32 / 8) | no lamps | ≤ 25 / ≤ 8 |
| Light at a guard's chest on the routes | 0.55 (ambient) | 0.50–1.13 |
| Draw calls, mean / max (software renderer) | 345 / 772 | 408 / 877 |
| Frame time, mean (software renderer) | 95 ms | 186 ms (no GPU measurement possible) |
| Tutorial, 9 views | — | pixel-identical |

**Door-frame fix (after the visual pass, same commit):** the door posts and lintels overlapped the wall faces and flickered (z-fighting). 76 boxes in `scenes/level/expanded_library.tscn` were adjusted (50 posts 2 cm wider and 1 cm into the opening, 25 lintels 2 cm lower and 4 cm longer and deeper, 1 pedestal top 1 cm higher); decoration only, no collision changed. The builder (`tools/expanded/build_expanded_graybox.gd`) still generates the old sizes, so rebuilding the scene would bring the flicker back until the builder gets the same change.

**Evidence:** [`v4/`](v4/)
- `views/` (20 player views and 2 overviews), `compare/` (21 before/after pairs), `mission/` (11 views);
- `lighting.md`, `profile/` (v3, v4 and diagnostics), `playtests/`, `fingerprint/`;
- `test_run.txt`.

**Open:**
- performance on the target Windows hardware (not measurable here; the release 1.1.0 benchmark commands are in [`../performance/release_1_1/README.md`](../performance/release_1_1/README.md));
- a human look at readability and lighting;
- from v3: human playtests and the 20–30 minute target.


---

## Expansion (2026) — integration point (expansion Phase 1, 2026-10-15)

No new layout version: the layout data and the scene's existing content are unchanged (baseline digests in [`expansion/phase-1-baseline.md`](expansion/phase-1-baseline.md), checked by `tests/expanded_baseline_tests.gd`).

**What changed:**
- The level gained one child, `Expansion`, an instance of the new, empty `scenes/level/expanded_library_expansion.tscn`, placed right after `Gameplay`. New puzzles, mechanics and areas go into that sub-scene.
- **The builder is frozen** (owner decision, expansion Phase 1). `tools/expanded/build_expanded_graybox.gd` would revert the door-frame fix and drop `Expansion`, and the baseline tests fail if it is run. Changes to the existing level need approval and a new baseline.

**Why:** the expansion's rules require the existing scene, its geometry and its fixes to stay as they are; a sub-scene keeps new work in its own small file.

---

## Expansion layout x1 — seven zones and the basement network (expansion Phase 2, 2026-10-15)

**What:**
- Zone G (basement / service network: west and east service stairs, the service tunnel, maintenance bay, pump room, storm drain, cable bay) and the electrical room (zone D), in the Expansion sub-scene.
- Three doorways cut into existing walls: B west (z −9), D east (z −23, a staff-card door), B/C (z −21).
- The navmesh rebaked from both parts (1,020 polygons).

**Why:** the owner's seven-zone target with a compact service network and a stacks hub; reserved spaces for puzzles, security and the three escape routes.

**Approved changes to the existing scene:**
- the three cuts (3 wall bodies shortened, 3 pieces and 3 headers added, 12 decoration boxes split);
- the `NavigationRegion3D` joined the navmesh's bake group;
- the navmesh file was rebaked.

Guards, routes, mission and every other node are unchanged (baseline digests in `tests/expanded_baseline_tests.gd`).

**Evidence:** [`expansion/phase-2/`](expansion/phase-2/) (before/after views, plans, zone connections, navigation results); report [`expansion/phase-2-layout.md`](expansion/phase-2-layout.md).

---

## Expansion layout x2 — stamina, inventory, provisional items (expansion Phase 3, 2026-10-15)

**What:**
- Stamina (Expanded Library only): 100, sprint −20/s, +15/s after 1 s, 15 to start a sprint; `PlayerStamina` on the player, switched on by the level's `Player.use_stamina`.
- Inventory: three carried slots, a journal for clue documents, storage shelves as the only places to leave or swap items; `PlayerInventory` on the player (`Player.use_inventory`), with `ItemPickup`, `ItemStorage`, `DocumentPickup`, `ToolMechanism` and `ItemCatalog`.
- The staff card is a carried item; the staff doors (G2, G4, the electrical room door) check the carried card (`AccessDoor.key_item`).
- Provisional placements in the Expansion sub-scene: tool kit, three distractions, two shelves, two documents (see LAYOUT.md, layout x2).

**Why:** the owner's Phase 3 rules (stamina values; three slots; reusable tools and cards, single-use distractions, journal, drop/swap only at appropriate places, checkpoint restore).

**Approved changes to the existing scene (`tools/expanded/expansion/enable_items.py`):** five property lines: `use_stamina` and `use_inventory` on Player, `grants_item` on the staff card, `key_item` on G2 and G4. No geometry, navmesh, guard or route changed.

**Evidence:** [`expansion/phase-3/`](expansion/phase-3/); report [`expansion/phase-3-mechanics.md`](expansion/phase-3-mechanics.md).

---

## Expansion layout x3 — puzzles, journal and objectives (expansion Phase 4, 2026-10-16)

**What:**
- The mission is an objective graph (ObjectiveManager graph mode: prerequisites, optional and hidden objectives; the tutorial keeps the linear mode). 8 mandatory objectives, 3 optional ones; escape through the loading dock or the storm drain.
- Puzzles: the electrical panel cover (tool kit), the breaker panel (power), the vault keypad (code; wrong codes raise the security alarm, three lock it 20 s) opening a new Vault Door; optional: the pump (opens the storm drain), the Office 1 security locker; the back gate is now an optional shortcut.
- Clues: the wiring chart, the archivist's memo with the lobby plaque, the pump room log, the night rota; documents and clues in the journal, with the mission and the discovered optional objectives.
- Interfaces for later phases: `PowerNetwork`, `SecurityAlarm` (main entrance lockdown reserved).

**Why:** the owner's Phase 4 brief (explore freely, clear mandatory prerequisites, four or more puzzle interactions, fair clues, persistence defined); the owner approved the mission graph, extending ObjectiveManager, puzzles following checkpoints, escapes dock + storm drain.

**Approved changes to the existing scene (`tools/expanded/expansion/mission_x3.py`):** the ObjectiveManager's `objectives` (the graph) and the loading dock ExitDoor's key (the manuscript) with its prompt and message. No geometry, navmesh, guard or route changed.

**Evidence:** [`expansion/phase-4/`](expansion/phase-4/); report [`expansion/phase-4-puzzles.md`](expansion/phase-4-puzzles.md).


---

## Expansion layout x4 — security systems (expansion Phase 5, 2026-10-16)

**What:**
- Three circuits on the existing `PowerNetwork`: ARCHIVE ACCESS (the Phase 4 breaker puzzle; the vault keypad only), SURVEILLANCE (starts ON; the four cameras), SERVICE EXIT (starts OFF; the loading dock shutter). Two new switches in the electrical room (`CircuitSwitch`); SERVICE EXIT ON reboots the cameras and locks the surveillance switch for 30 s. No switch is one-way.
- Four security cameras (`SecurityCamera`): staff corridor, archive hall, loading dock approach, service tunnel. A full meter raises the existing `SecurityAlarm` at the player's position (guards investigate; never a capture). Off: dark lens, guards unaffected.
- Guards of this level use `expanded_security` (an off-by-default flag on the shared guard): hiding only hides a player who got in unseen; a searching guard checks the nearest hiding spot; during an alarm, detection ×1.6 and searches ×1.5. Same three states. The tutorial's guards keep the default.
- A seventh guard, GuardBasement, patrols the service tunnel and the east basement (route P9_Basement, 5 points).
- The loading dock exit needs SERVICE EXIT power as well as the manuscript; the storm drain needs no power.

**Why:** the owner's Phase 5 brief; the owner approved the circuits as proposed, the hiding and search rules for the Expanded Library only, and one basement guard.

**Approved changes to the existing scene (`tools/expanded/expansion/security_x4.py`):** `expanded_security = true` on the six existing guards; the new GuardBasement with its route P9_Basement (in `Guards`); `power_circuit`, `no_power_reason` and `no_power_sign` on the loading dock ExitDoor. No geometry, navmesh, existing route or existing guard placement changed (the baseline test proves it with the two new nodes left out).

**Evidence:** [`expansion/phase-5/`](expansion/phase-5/); report [`expansion/phase-5-security.md`](expansion/phase-5-security.md).

---

## Expansion layout x5 — escape routes and checkpoints (expansion Phase 6, 2026-10-16)

**What:**
- Three escape routes, each needing the manuscript and its own prerequisites:
  - **A main entrance:** a lockdown panel closes the existing entrance once the player is inside; the new security master badge (in the Office 1 security locker) and a 4 s override at a new badge reader open it; a new fixed lobby camera watches the reader.
  - **B loading dock:** the existing dock exit also needs a new shutter release (tool kit) and the OPEN button on a new shutter control, besides SERVICE EXIT power.
  - **C hidden maintenance passage:** a false wall panel in the tunnel's existing north gap, revealed by a new document (culvert access plan); the Phase 4 pump still clears the storm drain grate.
- Exits are walked through (a trigger past each door). The route used is recorded and shown on the win screen.
- Checkpoints also store the guards' positions, facing and patrol progress (Expanded Library only), restored on PATROL with a clear memory; a guard near or in sight of the respawn point goes to its start.

**Why:** the owner's Phase 6 brief; the owner approved the three routes as proposed, walk-through triggers, and guard positions in the snapshot.

**Approved changes to the existing scene:**
- `tools/expanded/expansion/escape_x5.py`:
  - `checkpoint_snapshot = true` on the seven guards;
  - walk-through properties on the loading dock ExitDoor (its trigger and panel, the unlock requirement, the route name, texts).
- `tools/expanded/expansion/mission_x3.py`: the enter_library, take_manuscript and escape texts (the objective graph is unchanged).

No geometry, navmesh, guard placement or route changed.

**Evidence:** [`expansion/phase-6/`](expansion/phase-6/); report [`expansion/phase-6-escapes.md`](expansion/phase-6-escapes.md).

---

## Expansion layout x6 — HUD and accessibility (expansion Phase 7, 2026-10-16)

**What:**
- A new `EscapeRoutes` node (`Expansion/Gameplay/Escape/EscapeRoutes`) that reads the three routes' requirements from the game and the player's journal, for the HUD's WAYS OUT list and the exits' refusal messages. What the player has learned is kept as journal clues, so it survives a capture.
- The journal now holds only documents and clues (the Phase 4 journal also repeated the mission; the objective panel shows it).
- No geometry, collision, navmesh, guard, route or existing node changed; the main scene is unchanged (the node is in the expansion sub-scene, rebuilt with `build_expansion.gd` and `keep_ids.py`).

**Why:** the owner's Phase 7 brief and answers (settings in a config file; captions on both maps; routes learned and kept in the journal).

**Evidence:** [`expansion/phase-7/`](expansion/phase-7/); report [`expansion/phase-7-hud.md`](expansion/phase-7-hud.md).

---

## Expansion — end-to-end testing (expansion Phase 8, 2026-10-17)

**What:** no layout change. One critical fix found by the end-to-end runs: with an exit open (dock shutter up, badge override done, or the grate cleared and the panel open) and no manuscript, walking into the exit's trigger showed "You can't leave without the rare manuscript." but nothing stopped the player; past the dock door there is no floor, so they fell out of the level and respawned at the last checkpoint. `scripts/systems/objectives/exit_door.gd` now adds an invisible wall at each walk-through exit's threshold, solid only while the way is open but leaving would be refused.

**Scene changes:** none (the wall is created at run time by the exit script).

**Evidence:** [`expansion/phase-8/`](expansion/phase-8/); report [`expansion/phase-8-e2e.md`](expansion/phase-8-e2e.md).

## Expansion — polish and performance (expansion Phase 9, 2026-10-18)

**What:** decorative only; no wall, floor, door, collision, navmesh or gameplay change. The expansion's static boxes (floors, walls, ramps, cover, ceilings, headers and the new decor) are merged into BatchedBoxes (one MultiMesh per 12 m cell, look kind and layer, split until at most 8 lights reach each piece), as the existing level's builder already does. New decor (no collision, flush with walls, above 2.3 m or flat on the floor): tunnel pipes and a cable tray, pump room pipes, a tool board in the maintenance bay, conduits and a DANGER · 400 V sign in the electrical room, a 2019 flood line, damp and puddles in the storm drain with a FLOOD LEVEL · 2019 sign, hazard stripes at both ends of both service stairs, emissive door lamps (no new lights), direction signs in the tunnel and a MAINTENANCE BAY sign. The storm drain's state label (GRATE JAMMED / CLEAR) moved 0.5 m down so it no longer overlaps the wall's SEALED sign. Ten synthesised mechanism sounds (MechanismAudio, 3D, listening to existing signals only). Per-frame work trimmed in the security cameras, access and exit doors, objective HUD and stealth HUD (no re-setting of unchanged text, colours and materials; cameras skip sight checks out of range).

**Scene changes:** `scenes/level/expanded_library_expansion.tscn` rebuilt by `build_expansion.gd` (Batched nodes under Geometry and Dressing groups, Dressing/Decor, five signs, Gameplay/MechanismAudio). `expanded_library.tscn` and the navmesh unchanged (collision fingerprint identical; a rebake gives a byte-identical navmesh).

**Evidence:** [`expansion/phase-9/`](expansion/phase-9/); report [`expansion/phase-9-polish-performance.md`](expansion/phase-9-polish-performance.md).

## Expansion — Phase 9 follow-up fixes (2026-10-19, approved by the owner)

**What:** fixes for the known issues the owner approved (items 2, 4, 7c+a, 8a, 9a, 11, 14b, 15 of the Phase 9 issue list):
- **P1:** the Staff Offices checkpoint keeps its pad by the card desk, but the respawn moved to the back of Office 1, facing its door (toward the stacks staff door G1b and the back stair S3); a hiding nook (carrel panel and low bench) on the staff balcony against the staff wing's wall, west of G1a.
- **P2:** a checkpoint pad inside the maintenance bay's door.
- **P3:** a niche with a hiding spot in the tunnel's north wall beside the west crate.
- **Lights per mesh:** two ground-floor batches split (no piece over 8 lights; every box kept); four upper-floor props moved to the upper floor's render layer. 0 meshes over 8 lights (was 7).
- **Decor:** the pump room risers and the two floor-to-ceiling electrical conduits moved into corners and slimmed to 0.12 m.
- **Sound:** a wrong pump setting plays only the stall bang (no buzz).
- **Tests:** the tutorial guard-timing test waits one frame after changing the time scale (the flake's cause); `run_tests.sh` gives the suite 2400 s.

**Scene changes:** `expanded_library.tscn` patched by `tools/expanded/expansion/fixes_x7.gd` (batches, prop layers, Staff Offices respawn; collision and guards unchanged); `expanded_library_expansion.tscn` rebuilt (niche walls and floor, nook cover, two hiding spots, the bay checkpoint); navmesh rebaked (1031 polygons, was 1020).

**Evidence:** report [`expansion/phase-9-followup-fixes.md`](expansion/phase-9-followup-fixes.md).

## Expansion — electrical room redesign (polish, 2026-10-22, approved by the owner)

**What:** looks only; the puzzle, the security system, positions, collision and interaction boxes are unchanged except the panel cover, which now fits the new panel.
- The cabinets became three grey-green electrical cabinets (door seams, handles, vents, plinth, top trim, status lamps).
- The breaker panel has a light steel frame, a backplate, a rail, a cable duct with the breakers' name plates, a copper bar and tidy black wiring, and a status screen above it. Its cover is a grey plate with four screws and a yellow warning sticker.
- A1–A4 are circuit breaker modules (toggle lever, green / red window, ON / OFF). MAIN is a wide main breaker at the rail's right end: its lever stays up with power on and snaps down with the breakers on a trip.
- SURVEILLANCE and SERVICE EXIT are rotary isolators (yellow plate, red handle up for ON and left for OFF, a name plate, a green / red lamp that blinks amber while the switch is locked after a reboot). The floating switch-board label is gone.
- A clipped black cable bundle runs from the panel to the ceiling tray, and a conduit from each switch to the wall conduits.
- Levers and handles snap in 0.15 s. The styles are optional (`PuzzleControl.style`, `BreakerPanel.panel_style`); the keypads, valves and pump keep their look.

**Scene changes:** `expanded_library_expansion.tscn` rebuilt (`Gameplay/Mission/ElectricalDressing`, the panel's `Display`, the cover's screws and sticker, the cabinets' look). Navmesh unchanged.

## Expansion — code locks redesign (polish, 2026-10-22, approved by the owner)

**What:** codes, tries, lockout, alarm and power rules unchanged.
- **Vault keypad** (archive): an electronic keypad in a steel housing.
  - The screen shows the four digits in green and the status line.
  - Each digit has a ▲ key under it (same interaction box as before); ENTER is a green key.
  - Three amber try lamps go out one per wrong code; a status lamp is red while locked and green when solved.
  - Without power, the screen and lamps are dark and only the NO POWER lamp glows.
- **Security locker** (Office 1): a grey steel locker with a door, handle, hinges, vents and a SECURITY plate.
  - The combination lock (three wheels that roll a step per E, a lever as ENTER that springs back) is on the door.
  - The right code swings the door open 100° with the lock on it; a checkpoint restore opens or shuts it at once.
  - The door has no collision (navmesh unchanged).
- **Moved (approved):**
  - the locker's lock, from the wall to the door, about 1.1 m: (−5.83, 5.85, −21.4) → (−5.3, 5.75, −22.55);
  - the badge and bottle onto the locker's middle shelf;
  - the patrol notes into its upper compartment.
- **Tests:** stand spots updated in `expanded_e2e_tests`, `expanded_puzzle_tests` and the playtest bot.
- **Wall text:** the floating status text is gone; each lock shows it on its own screen or tag.

**Scene changes:** `expanded_library_expansion.tscn` rebuilt (`VaultKeypadHousing`, `LockerCabinet`, `LockerDoor`, the locks' `Display`s). Navmesh unchanged.

## Expansion — pump room and storm drain redesign (polish, 2026-10-22, approved by the owner)

**What:** looks and animation only. The puzzle, the clue, the controls' positions and interaction boxes, the collision and the route are unchanged.
- **Pump unit** (inside the PumpMachine cover's collision box, which no longer draws a box):
  - a concrete plinth and base frame;
  - a blue motor with cooling fins, a fan cowl and a rating plate, and a yellow coupling guard;
  - the grey pump casing, with the suction pipe up to the east header and the discharge pipe (with a red valve) to the west header, flanged and bolted;
  - a pressure gauge facing the controls: its needle rises when the pump runs, kicks and falls on a stall. The motor hums (a slight shake) while it runs.
- **Valves:** red handwheels on a pipe manifold along the south wall, turning a quarter turn per use. An indicator flag on each bonnet lies along the pipe for OPEN (green) and across it for SHUT (red); a tag below shows V1 / V2 / V3 and the state. While the crank is seized a wheel only jerks.
- **START:** the green lever of the pump starter. It springs back after a stall and stays down while the pump runs. Beside it: a STALL lamp and a RUN lamp, and the starter's screen with the status (PUMP OFF · CRANK SEIZED / READY / STALLED · CHECK VALVES until a valve turns / RUNNING · CULVERT DRAINED). The floating status text is gone.
- **Crank:** a rusted handwheel on a gearbox, chained with a padlock and tagged SEIZED. Freeing it with the tool kit takes the chain and tag off and turns the wheel once.
- **Maintenance panel:** hidden as before. Once found, it is a grey steel hatch with a frame, ribs and rivets, hinges, a latch on the right-hand edge, a MAINTENANCE · CULVERT ACCESS stencil and a hazard kick plate (no more green slab).
- **Storm drain:**
  - The grate is a barred grille between steel guide channels, under a lintel with a ceiling slot, with water streaks on the floor in front.
  - When the pump starts, the grate's collision is cleared at once (as before) and the grille slides up into the slot (1.5 s).
  - Shallow water covers the drain floor and drains away in 6 s.
  - GRATE JAMMED is a tag on the grille, no longer floating, and goes once the drain is open.
  - A checkpoint restore sets the grille, the water, the lever and the gauge at once.
- **Note:** the pump unit is lower than its cover's collision (floor to ceiling, as before, so nothing is baked on top of it): there is an invisible wall above the motor, as there was a visible one.

**Scene changes:** `expanded_library_expansion.tscn` rebuilt (`Gameplay/Mission/PumpUnit`, `PumpPanelDressing`, `StormDrainGrille`, `DrainDressing`, `CulvertWater`, the crank's model, the pump's `Display`, `MaintenancePanel/Panel/Hatch`; the PumpMachine cover and the grate body without their meshes). Collision and navmesh unchanged.

## Expansion — loading dock redesign (polish, 2026-10-23, approved by the owner)

**What:** the escape rules (free the release with the tool kit, SERVICE EXIT power, OPEN), the release's and control's positions and interaction boxes, and the exit's trigger and barrier are unchanged.
- **Roller shutter:** galvanised slats, a bottom bar with a rubber seal, guide rails, a coil box with a motor and a LOADING BAY 1 plate, and a green EXIT sign above it. OPEN clears the shutter's collision at once (as before) while the curtain rolls up into the coil box in 2.5 s; it rolls down again if SERVICE EXIT goes off. A checkpoint restore sets it at once.
- **Shutter release:** a yellow MANUAL RELEASE box with a red pull handle, wedged by a rusty bolt and tagged JAMMED. Freed with the tool kit: the bolt and tag go and the handle drops.
- **Shutter control:** a yellow push-button station with the status on its screen (NO POWER / RELEASE JAMMED / READY / OPEN), a POWER lamp (lit while SERVICE EXIT is on), the green ▲ OPEN button and, for show, ▼ CLOSE and a red STOP.
- **Original level scene (approved patch):** `tools/expanded/expansion/fixes_x8.gd` hides the red shutter panel's mesh, the glowing green header over the door and the exit's floating sign (`ExitDoor.show_sign`). The panel's and the header's collision are unchanged; the expansion draws the wall over the door.
- **Dock room:**
  - Floor: a yellow bay box and a LOADING BAY 1 stencil in front of the shutter. Yellow-and-black bollards (solid) on the wall piers either side.
  - **Solid props** (like the crates; navmesh rebaked, 1031 → 1054 polygons):
    - a pallet rack along the north wall east of the storage door;
    - two pallets of book boxes on the south wall;
    - two shrink-wrapped pallets, east of the crates and by the south wall;
    - two roll cages of returned books in the north-west corner;
    - a parked forklift in the south-west corner.
  - They stay off the service guard's route across the dock, at least 1.2 m from the release, the control, the doorway and the hiding spot, and out of the dock camera's view of its target.
  - **Decor** (no collision): the forklift's forks, boxes on two crates, two pallets stood against the west wall, a hand truck and a pallet jack against the south wall.
- **Outside** (seen once the shutter is up; no collision, nobody walks out there): a night yard with a concrete apron, the dock leveller and bumpers, a brick face and a canopy round the door, a parked CITY LIBRARY DELIVERIES van, bay lines, a kerb, a fence and a streetlight. It has its own render layer (32) and light, so it adds no light to the dock.

**Scene changes:** `expanded_library.tscn` patched by `fixes_x8.gd` (three visibility lines); `expanded_library_expansion.tscn` rebuilt (`Geometry/D_LoadingDock`, `Dressing/DockDecor`, `Gameplay/Escape/ShutterCurtain`, `DockShutterFrame`, `DockShutterStation`, `DockYard`, the release's model, the control's `Display`; `DockShutterBackplate` removed); navmesh rebaked (1054 polygons).

## Expansion — storage room redesign (polish, 2026-10-23, approved by the owner)

**What:** the racks' and the S2 staff stair's collision, the guard's route, the checkpoint and the hiding spot are unchanged.
- **Racks** (Rack57–60): double-sided steel shelving inside each rack's 2 m collider:
  - blue uprights, orange beams, three shelves each side and a mesh back panel down the middle;
  - archive boxes, cardboard boxes and rows of books;
  - aisle tags A1–A4 on both ends.
- **S2 staff stair:**
  - grey steel with safety-yellow nosing (the same strips as before);
  - the side walls galvanised, with yellow caps as the rail;
  - a wire-mesh storage cage under it, with a padlocked door and boxes behind;
  - a STAFF STAIR S2 ↑ ARCHIVE sign on its side wall at the foot.
  - A separate handrail tube inside the stair was dropped: it would be decoration in the stair's walkway, which the level's dressing rule forbids.
- **Solid props** (navmesh rebaked, 1054 → 1057 polygons):
  - wall shelving of archive boxes along the north wall (west of the processing door), the west wall (south of the west door) and the south wall (east of the dock door), 0.6 m deep;
  - a book trolley against the east wall.
  - All stay off the service guard's route and at least 1.2 m from the doors, the checkpoint, the hiding spot and the stair foot.
- **Details:**
  - two hanging aisle signs above head height;
  - yellow walkway lines along the cross aisle and from the dock door;
  - a step ladder against the north wall;
  - STORAGE · STAFF ONLY signs outside the three doors.
- **Original level scene (approved patch):** `tools/expanded/expansion/fixes_x9.gd` removes the racks' old boxes (40) from the ground floor's batches, recolours the stair's boxes and hides its cream nosing. Collision is unchanged.

**Scene changes:** `expanded_library.tscn` patched by `fixes_x9.gd`; `expanded_library_expansion.tscn` rebuilt (`Geometry/D_Storage`, `Dressing/StorageDecor`, three signs); navmesh rebaked (1057 polygons).

## Expansion — Book Processing redesign (polish, 2026-10-23, approved by the owner)

**What:** the electrical room door's rules (the staff card), its panel's collision, the tables' collision, the wiring chart's place and the routes are unchanged. The room has no guard.
- **Electrical room door:**
  - two grey steel leaves with wired-glass vision panels, kick plates, push handles and hinges;
  - a DANGER · HIGH VOLTAGE / AUTHORISED STAFF ONLY plate and a warning sticker;
  - a steel frame and a card reader.
  - The reader's LED and a light strip over the door show what the red/green tint showed: green when the player could open it from where they are, red otherwise. The door itself stays grey.
  - It swings open into the electrical room (0.6 s) while the panel's collision clears at once. A checkpoint restore shuts or opens it at once.
  - `AccessDoor` gained optional `leaf_paths`, `leaf_open_angles` and `status_light_paths`; the other doors are unchanged.
- **Workstations** on the four tables: a cataloguing PC, a keyboard and mouse, a barcode scanner, a label printer, tape, and stacks of books being processed.
- **Noticeboard:** a cork board with staff notices round the wiring chart, which keeps its place and hit area.
- **Solid props** (navmesh rebaked, 1057 → 1077 polygons):
  - sorting shelves of books on the west wall (north of the west door) and the south wall (west of the storage door);
  - a returns island with pigeonholes A–X in the middle;
  - two book trolleys and a NEW ARRIVALS pallet.
  - All are at least 1.2 m from the three doors, the wiring chart and the tables, with paths between the doors.
- **Wall details:** a clock, HANDLE WITH CARE and NEW ARRIVALS posters, and a fire extinguisher beside the electrical door.

**Scene changes:** `expanded_library_expansion.tscn` rebuilt (`Geometry/D_Processing`, `Dressing/ProcessingDecor`, the electrical door's leaves, frame, reader and strip); navmesh rebaked (1077 polygons). The level's own scene is not touched.

## Expansion — lobby and reading hall redesign (polish, 2026-10-23, approved by the owner)

**What:** unchanged:
- every existing collider, the hiding spots, the guards' routes and the lobby camera;
- the main entrance's rules, barrier and timing;
- the G4 door's rules.

**Lobby** (no new collision):
- **Main entrance:**
  - wooden glass double doors, standing open on the porch;
  - a steel security grille that drops when the night lockdown starts and rolls up (2 s) when the exit opens (the badge override), set at once on a checkpoint restore;
  - the entrance sign on a LOCKDOWN light box over the doors instead of floating;
  - a steel housing and screen panel for the badge reader.
  - The exit's panel keeps its collision but draws nothing. `ExitDoor` gained optional `curtain_path` / `curtain_lift` / `curtain_time` / `curtain_top`.
- **Circulation desk:** panelled front, a raised ledge with a RETURNS slot, a second PC, a date stamp and ink pad, and a hanging INFORMATION · LOANS sign.
- **S1 main stair:** recoloured as a wooden stair with a red carpet, brass caps and brass nosing (the same strips), with moulded panels and a STORE cupboard on its open side.
- **G4 staff door:** wooden double leaves with glazed panels, brass and a STAFF ONLY plate, a frame, a card reader and a light strip (red/green, as the electrical door's). It swings into the service corridor.
- **Details:** a library map ("YOU ARE HERE") and a WHAT'S ON board on the north wall, taller plants in the two planters, an entrance mat, and WELCOME TO / CAMPUS LIBRARY banners either side of the clock.
- **Original level scene (approved patch):** `tools/expanded/expansion/fixes_x10.gd` recolours the S1 stair's boxes, hides its cream nosing, and points G4 (`leaf_paths`, `status_light_paths`) at the expansion's leaves. No collision changes.

**Reading hall:**
- **Tables:** a green banker's lamp, an open book, a notebook and a pencil on each of the six tables.
- **Centre bookcase:** a NEW BOOKS sign and face-out books on stands.
- **Solid props** (navmesh rebaked, 1077 → 1082 polygons):
  - nine wall bookcases (0.45 m deep, 2.6 m tall) between the doorways;
  - a newspaper rack and a globe.
  - All stay clear of every doorway (study doors, the stacks arch, SC1, the lobby doors), the connector guard's route and the reading-table hiding spot.
- **Details:** QUIET PLEASE signs and framed pictures above the bookcases.

**Scene changes:** `expanded_library.tscn` patched by `fixes_x10.gd`; `expanded_library_expansion.tscn` rebuilt (`Dressing/LobbyDecor`, `Dressing/HallDecor`, `Geometry/C_ReadingHall`, `Gameplay/Escape/MainEntranceDressing`, `BadgeReaderHousing`, `Gameplay/LobbyStaffDoorDressing`); navmesh rebaked (1082 polygons).

**Test change:** `expanded_polish_tests` G: the seized-valve check now samples the wheel each frame for 0.25 s instead of once at 0.03 s. With the heavier scene, frame times can exceed the 0.18 s jerk, so a single sample missed it.
