# Expanded Library — design log

One entry per layout version, newest last. Each version is built from `tools/expanded/expanded_layout.gd` (its `VERSION`) and gets:
- **its own evidence folder** `docs/expanded/vN/`;
- **its own git commit(s)**, named `level(expanded-vN): …`.

That way the history is in git as well as in the folders. The tutorial's log records five versions that landed in one commit; this log is kept one commit per version from the start.

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

Commits:
1. `level(expanded-v0): layout design and floor plans`
2. `level(expanded-v0): graybox scene, navmesh and tests`

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

Commit: `level(expanded-v1): guards, patrols and stair fixes` (one commit with the tests and the guard steering fix).

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

Commit: `level(expanded-v2): mission, access doors and checkpoints` (one commit with the mission systems and tests).

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

Commit: `level(expanded-v3): stealth balance from playtests` (one commit with the balance tools and tests).

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

Commit: `level(expanded-v4): visual pass in the tutorial's style` (one commit with the visual-pass tools and tests).

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

**Evidence:** [`v4/`](v4/)
- `views/` (20 player views and 2 overviews), `compare/` (21 before/after pairs), `mission/` (11 views);
- `lighting.md`, `profile/` (v3, v4 and diagnostics), `playtests/`, `fingerprint/`;
- `test_run.txt`.

**Open:**
- performance on the target Windows hardware (not measurable here);
- a human look at readability and lighting;
- from v3: human playtests and the 20–30 minute target.

