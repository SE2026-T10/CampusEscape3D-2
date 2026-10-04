# Phase 11 — Final Level

The graybox library is now the final playable level: one small, low-poly university library, built up over four measured design passes. The full design history, with what changed, why, the numbers and before/after pictures for each version, is in **[`docs/level/LEVEL_LOG.md`](level/LEVEL_LOG.md)**. This page summarises it.

## Level-design versions (Git history)

| Commit | Version | What changed | Evidence |
|---|---|---|---|
| `level(v0): level report tools and baseline evidence` | v0 | No level change: tools added and the Phase 10 graybox measured | `level/v0/` |
| `level(v1): cover and sightline pass` | v1 | low bookcases, catalogue cabinet, Hallway East study alcove + carrel, book carts, exit-area crates and rack | `level/v1/` (+ `compare.md`) |
| `level(v2): GuardEast patrol becomes an exit-area warden` | v2 | GuardEast's patrol route (6 candidates measured; B2 chosen) | `level/v2/` (+ `experiments/`) |
| `level(v3): readability pass …` | v3 | doors, room / RESTRICTED / EXIT signs, landmarks, card spotlight (visual only, metrics identical) | `level/v3/` |
| `level(v4): low-poly art pass …` | v4 | palette, lighting, books, ceilings, chairs, plants, windows, posters, rugs | `level/v4/`, `level/before_after/` |
| `docs: Phase 11 final level` | — | level-design tests, this page, README | — |

## Requirements

| Required | Where |
|---|---|
| Entrance | Entrance hall (spawn): red rug, plants, notice board, MAIN LIBRARY sign over the door |
| Main reading area | Reading Area: tables with chairs and green lamps, low bookcases, teal rug, circulation desk with globe |
| Bookshelves | 4 tall bookcases in the main room, 3 in the Restricted Stacks, 3 low bookcases, all filled with books |
| Corridors | Hallway West, Back Corridor, Hallway East |
| Objective area | Restricted Stacks: burgundy carpet, red-trimmed doors, archive desk with spotlight and ARCHIVE sign |
| Restricted / alternative route | West via Hallway West (62 m), or east via Hallway East and the back corridor (91 m); after the card, the back corridor (41 m) or the long way round (95 m) |
| Checkpoint locations | Hallway West and the Staff Nook; both 0% exposure and unseen in the 45-second test |
| Escape route | green EXIT signs in the back corridor and Hallway East, exit area with hazard stripes, green-lit exit door |
| Low-poly interior, furniture, shelves, tables, doors, props, lighting, materials, details | v3 and v4 |

### How the design goals are supported (measured on v4)

| Goal | How |
|---|---|
| 1. Clear navigation | Room signs over every doorway; zone floor colours; the aisle runner leads to the clock |
| 2. Cover | Floor within 1.5 m of cover: 33% (v0) → 42% (v4). There is crouch-height cover now: main-room crouched exposure is 9.5% vs 10.2% standing (v0: 10.4% vs 10.6%). |
| 3. Sightline control | Catalogue cabinet on the M1 → Hallway West line; carrels; alcove set into the wall; bookcases |
| 4. Alternative routes | 2 routes to the card, 2 to the exit. The safest east route to the card fell from 115–117 m to 103 m, and its peak exposure from 38% to 31% (v2). |
| 5. Patrol routes | 3 patrols: main room 63 m / 40 s, stacks 26 m / 19 s, exit warden 28 m / 22 s |
| 6. Interesting stealth decisions | short-but-guarded west route vs long-but-quieter east route; back corridor vs long way out; carrels to wait in; the warden's back is turned at the door corner |
| 7. Fair detection | spawn and both checkpoints at 0% exposure (report) and unseen for 45 s (tests); lighting doesn't affect detection, so there are no misleading shadows |
| 8. Clear landmarks | wall clock (north), globe, green lamps, red restricted zone, green exit |
| 9. Objective readability | red RESTRICTED doors from both sides, ARCHIVE sign, spotlight on the glowing card |
| 10. Escape readability | 6 EXIT signs with arrows checked against their facing; green exit light; door turns green when the card is taken |

## New files

- `tools/level_report.gd`, `tools/level_map_canvas.gd`, `tools/capture_views.gd`, `tools/level_compare.gd` — level measurement and evidence
- `scripts/level/shelf_books.gd` — `ShelfBooks`: `@tool` MultiMesh books, seeded, no collision
- `scenes/props/chair.tscn`, `potted_plant.tscn`, `ceiling_light.tscn`
- `tests/level_design_tests.gd`
- `docs/level/` — the log, v0–v4 evidence, before/after images

## Verification record (2026-10-04)

All runs used the official Linux build of Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`).

| Check | Result |
|---|---|
| Every level commit | the full test suite passed on v0, v1, v2, v3 and v4 before committing |
| Project import | exit 0, no errors |
| Full test run (final) | `All tests passed (… Phase 10 game flow, Phase 11 level design).`, exit 0, about 2 min 30 s; no errors or leaks; the same 8 expected warnings |
| Navigation (v4) | 224 polygons; saved bake matches a fresh bake; 429 open samples covered (0 missing); 97 obstacle samples (0 walkable); sealed (630 edge points, 0 open); probe walks entrance → exit |
| Main menu and library scenes, 900 frames | exit 0, no errors |
| Level-design tests, mutations | books ignoring the seed, a missing RESTRICTED sign, books sticking out of the bookcase, and a visible debug label each fail the suite |

**About the evidence:**

- All metrics come from `tools/level_report.gd` running against the scene, navmesh and colliders.
- v0 was re-measured with the final tool on the v0 commit (a separate worktree), so versions compare like for like.
- First-person views and the top-down render come from `tools/capture_views.gd` (HUD and guards hidden).
- `level/v4/gameplay_*.png` are in-game shots with the HUD and guards. The player was teleported there, which is why the objective panel still reads "Enter the library".
- Everything was rendered under Xvfb with Mesa llvmpipe software OpenGL, not on Windows hardware.

## Manual verification still required (Windows, Godot 4.7.2 editor, F5)

1. Play the whole level both ways (west and east routes, back corridor and long way out). Check that signs and landmarks make the way obvious without the HUD.
2. The exit area: the warden leaves no floor permanently safe (v2). Check it feels tense rather than unfair.
3. Lighting and readability on real hardware: brightness, signs readable, nothing that looks like a hiding shadow.
4. Performance: frame time in the main room. The level has 6,667 book and shelf-board instances in 10 MultiMeshes, and 19 lights: 15 ceiling omni lights, 2 coloured omni lights, 1 spotlight and the sun. Profiler evidence belongs to the profiling phase.
5. Walk through the decorative chairs at the tables: they have no collision by design. Decide whether that's acceptable.

## Known limitations

- The scene file is still named `library_graybox.tscn`, so tests, tools and the main menu keep working. Renaming it is a separate, mechanical change.
- The doors other than the exit are open, static props. Only the exit door is interactive.
- Chairs, signs and other decoration have no collision; plants do.
- The exposure measure is a model: guards facing their walking direction, 90° / 14 m cones, combined as independent. It ignores investigation and chase behaviour.
- Windows are emissive panels (night sky), not real openings. The ceiling doesn't block the dimmed sun.
