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
