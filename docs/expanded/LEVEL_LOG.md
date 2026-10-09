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
