# Library level — design log

One entry per significant level change, newest last. Each entry links to that version's evidence folder. Every version's numbers and pictures come from the same tools, run on the commit itself:

| Evidence | Made by | What it shows |
|---|---|---|
| `vN/report.md`, `vN/metrics.json` | `tools/level_report.gd` | room exposure and cover, patrol loops (points, waits, length, time), player-route length and exposure, key points |
| `vN/map.png` | `tools/level_report.gd` (with a display) | top-down map: walls, cover, exposure heat, patrol routes with waits, shortest and alternative player routes, objective, checkpoints, exit |
| `vN/views/*.png` | `tools/capture_views.gd` | the same 8 first-person viewpoints plus a top-down render, so versions compare shot for shot |
| `vN/compare.md` | `tools/level_compare.gd` | before/after table against the previous version |

```
godot --path . --script res://tools/level_report.gd -- --out=docs/level/vN --version=vN
godot --path . --resolution 1280x720 --script res://tools/capture_views.gd -- --out=docs/level/vN/views
godot --headless --path . --script res://tools/level_compare.gd -- --before=docs/level/vM --after=docs/level/vN
```

**How to read the numbers**

- **Exposure** of a floor spot: the share of each guard's patrol loop during which that guard has the spot inside its 90° / 14 m view cone with a clear line of sight. Guards are combined as 1 − Π(1 − e).
- **Standing** uses head height 1.5 m and **crouched** 0.85 m, so the gap between them is what crouch-height cover adds.
- **Safe floor** is exposure below 5%.
- **Peak exposure** of a route is its most dangerous metre.
- **Safest route**: the least-exposed walk between two points, found by a grid search where each metre costs 1 + 20 × exposure. It's the route a careful player would take. "Shortest" is the plain navmesh path.
- The patrol timeline assumes guards face the way they walk and keep facing the way they arrived while waiting. That is what the PATROL state does.

Screenshots are rendered under a virtual display (Xvfb, Mesa llvmpipe software OpenGL), not on Windows hardware, with the HUD and guards hidden.

> **Note on commits (release validation, 2026-10-09).** The `Commit: level(vN): …` lines below name the commits each version was made in during development. Those commits are **not in this repository's history**: all five versions arrived in one commit, `3320e45` ("Phase 11 Library Level Design + Low-poly Art"). The record of each version is therefore its evidence folder (`vN/report.md`, `metrics.json`, `map.png`, `views/`, `compare.md`), produced by the level tools, not a separate git commit per version.

---

## v0 — Baseline (graybox after Phase 10)

Commit: `level(v0): level report tools and baseline evidence`. No level changes: this records the starting point. The report tool gained the peak location, safest routes and hiding-spot exposure while working on v1. `v0/` was then **re-measured with that final tool on the v0 commit itself** (a separate worktree), so v0 and v1 compare like for like.

**Layout:**

- Entrance (spawn) → Main Library Room (west stacks, east reading area with 4 tables and the circulation desk).
- Two ways north:
  - **West:** Hallway West → Restricted Stacks (access card) → Back Corridor (Staff Nook checkpoint) → Exit Area.
  - **East:** Hallway East → Exit Area, then the Back Corridor west to the stacks.
- Checkpoints in Hallway West and the Staff Nook. Four study carrels.

**Measured** (`v0/report.md`):

| | Value |
|---|---|
| Mean exposure, standing / crouched | 10.9% / 10.8% |
| Safe floor | 33% |
| Floor near cover | 33% |
| Start → card, shortest | 63.8 m, mean 4.5%, peak 42% at (-4.4, -20.0): the east end of the stacks, next to the guard's R2 stop |
| Start → card, safest | 53.4 m, mean 4.6%, peak 29% at (-13.5, -21.5), at the card |
| Start → card, safest via the east loop | 115.4 m, mean 6.1%, peak 38% at (-4.5, -19.5) |
| Card → exit, safest | 43.7 m, mean 7.4%, peak 26% |
| Hallway East / Exit Area exposure | 19.5% / 17.5%, with no cover in the hallway (0%) |
| Carrels, exposure crouched inside | 0% for West, Restricted and Exit; 14.8% for East (reading area) |

**Problems this shows** (the targets for the next versions):

1. **Crouching barely matters.** Crouched exposure is almost the same as standing (10.8% vs 10.9%), because the only low cover is 0.75 m tables, which don't hide a crouched head (0.85 m). The crouch mechanic from Phase 8 has almost nothing to work with.
2. **The east route is a gamble.** Hallway East is the most exposed room, with no cover at all, and GuardEast walks its whole length. As an alternative route it offers nothing to plan around.
3. **The east loop isn't a real alternative.** The safest east route is more than twice as long (115 m vs 53 m) and is more exposed. It still meets the stacks guard at the stacks' east entrance (peak 38%). It passes GuardEast's whole hallway, and the only hiding place on the way is the exit carrel.
4. **Graybox look.** Rooms are told apart only by floating labels. Nothing in the space itself says "objective here" or "exit this way".

---

## v1 — Cover and sightline pass

Commit: `level(v1): cover and sightline pass`. Evidence: `v1/report.md`, `v1/map.png`, `v1/compare.md`, `v1/views/`.

**What changed, and why:**

| Change | Where (x, z) | Why |
|---|---|---|
| 3 low bookcases, 1.2 m tall | Reading area: (6, 5), (10, 5), (8, -1.5) | Crouch-height cover (taller than a crouched head at 0.85 m, lower than a standing head at 1.5 m). This gives the Phase 8 crouch something to do in the busiest room (problem 1). |
| Catalogue cabinet, 1.6 m tall | Main room, north wall, (-6.5, -5.25) | Blocks the line from GuardMain's M1 stop to the Hallway West doorway. From M1's eye (1.6 m) to a standing head in the doorway, the line crosses x = −6.5 at about 1.55 m, below the cabinet top. |
| **Study alcove with a 5th carrel** | Hallway East, east side, (25.8, -10) | The east route had no cover and no hiding place (problem 3). The alcove is set into the wall, so a guard walking the hallway, facing along it, doesn't look into it. The east wall was split around the opening. |
| 2 book carts, 1.1 m tall | Back corridor: (13.5, -21.45), (5, -23.55) | The back corridor had 0% cover. They give crouch cover on the way from the card to the exit. |
| Crate stack, 1.2 m, and storage rack, 2 m | Exit area: (24.2, -21.2), (21, -25.2) | Cover on the last stretch to the exit door, which had only 10% safe floor. |
| Navmesh rebaked | — | 168 → 220 polygons. Every test passes, including navmesh coverage, sealing and the walking probe. |

**Measured effect** (`v1/compare.md`):

| | v0 | v1 |
|---|---|---|
| Mean exposure standing / crouched | 10.9% / 10.8% | 10.7% / 10.2% |
| Main room, standing / crouched | 10.6% / 10.4% | 10.2% / 9.5% |
| Floor near cover | 33% | 41% |
| Safe floor | 33% | 34% |
| Hiding place on the east route | none | CarrelHallway, 0.0% crouched |
| Safest start → card | 53.4 m, 4.6% | 53.4 m, 4.3% |
| Safest card → exit | 43.7 m, 7.4%, peak 26% | 46.7 m, 6.8%, peak 30% |
| Exit area, standing / crouched | 17.5% / 17.5% | 18.0% / 16.3% |
| Hallway East | 19.5% | 19.6% |

**What this did and didn't fix:**

- **Crouching now matters.** The gap between standing and crouched exposure appeared (main room 0.2 → 0.7 points; exit area 0 → 1.7).
- **Cover coverage is up.** Floor near cover went from 33% to 41%.
- **The east route has a hiding place.** The new alcove carrel is unseen even by guards walking past.
- **Hallway East is still the most exposed room (19.6%)**, because GuardEast walks its full length both ways. That's a patrol problem, not a geometry one, and is the target of v2.
- **The exit stretch got slightly worse in one respect.** The safest card→exit route peaks higher (26% → 30%), at (21.5, -19.5): the crate stack moved GuardEast's path out toward the exit-area entrance. This is also left for the patrol pass.

---

## v2 — Patrol pass: GuardEast becomes the exit warden

Commit: `level(v2): GuardEast patrol becomes an exit-area warden`. Evidence: `v2/report.md`, `v2/map.png`, `v2/compare.md`, and `v2/experiments/` (one report per candidate route). No geometry changed, so there are no new first-person views; the map shows the new patrol.

**Problem** (from v1): Hallway East was still the most exposed room (19.6%), because GuardEast walked its full 20 m length both ways. The east route therefore had no timing window, and the safest way to the card via the east was 117 m long.

**Candidates tried.** GuardMain and GuardRestricted were left as they are. Each candidate was a copy of the v1 level with only the east route changed, measured with `--scene=`:

| Candidate | GuardEast points (wait) | Hallway East | Exit area | Back corridor | Safest east route to card | Safest card → exit |
|---|---|---|---|---|---|---|
| A (v1, current) | (22.5,3.5)·2, (22.5,−15)·2, (25.5,−25)·3, (20,−22.5)·2 | 19.6% | 18.0% | 5.8% | 117.0 m, 6.2%, peak 38% | 46.7 m, 6.8%, peak 30% |
| B exit warden | (22.5,−16)·2, (26,−25.5)·3, (19.5,−22.5)·2, (24.5,−19.5)·2 | 7.8% | 22.0% | 10.8% | 103.0 m, 9.0%, peak 30% | 43.1 m, 11.6%, peak 29% |
| **B2 (chosen)** | as B, but a **1 s** stop at (19.5,−22.5) | **8.2%** | 22.9% | **8.8%** | **103.9 m, 8.6%, peak 31%** | 43.1 m, 10.8%, peak 30% |
| B3 door dwell | as B2, but 2 s at the door corner, 3 s at (24.5,−19.5) | 8.2% | 23.0% | 8.8% | 103.9 m, 8.6%, peak 31% | 43.1 m, 10.8%, peak 30% |
| C half hallway | (22.5,−5)·2, (22.5,−16)·1, (25.5,−25)·3, (20,−22.5)·2 | 18.6% | 22.0% | 7.4% | 117.0 m, 7.3%, peak 38% | 43.1 m, 10.0%, peak 30% |
| D long exit dwell | (22.5,0)·1, (25.5,−25)·4, (20,−22.5)·3 | 19.3% | 16.7% | 8.0% | 117.0 m, 7.2%, peak 38% | 43.1 m, 9.0%, peak 26% |

**Decision: B2.**

- **Why not C or D:** both still walk most of the hallway, so its exposure stays above 18%.
- **Why B2 over B:** the warden's stop at (19.5, −22.5) faces down the back corridor, because the guard keeps facing the way it arrived. Cutting that stop from 2 s to 1 s lowered back-corridor exposure from 10.8% to 8.8%, and the card→exit mean from 11.6% to 10.8%.
- **B3** measured the same as B2. B2 is simpler and keeps the longer dwell away from the door, so it was kept.

**What it changes for the player:**

- **The east route becomes a real alternative.** Hallway East drops to 8.2% exposure and 47% safe floor. The warden only glances up the hallway (2 s at (22.5, −16) facing north-west), so there's a timing window, and the alcove carrel to wait in. The safest east route to the card is 13 m shorter (117 → 104 m). Its worst point is now the exit area (31%), no longer the stacks guard's east entrance (38%).
- **The exit is now the climax.** A dedicated guard loops the exit area every 22 s. Exposure there is 22.9%, and no floor stays under 5% for the whole loop. The cover added in v1 (crate stack, rack, exit carrel at 0% crouched) becomes the way through. The 3 s stop at (26, −25.5), 2.5 m from the door, faces the south wall, so the door can be reached behind the warden's back.
- **Two ways to leave with the card.** The back corridor is short, with the warden glancing down it for 1 s each loop. Going back through the main room and Hallway East is long, but the hallway is quiet now.
- **Fairness is unchanged:**
  - every respawn point (spawn, Hallway West, Staff Nook) is still at 0% exposure;
  - the tests' 45-second patrol check still passes for both checkpoints;
  - the spawn check still passes.

**Watch in play-testing:** the exit area has no permanently safe floor any more. Whether that feels tense rather than unfair needs a human play-test, so it's listed as manual verification.

---

## v3 — Readability: doors, signs, wayfinding, landmarks

Commit: `level(v3): readability pass`. Evidence: `v3/views/` (compare with `v1/views/`), `v3/report.md`, `v3/compare.md`.

**Problem** (v0 problem 4): rooms were only told apart by large floating labels. Nothing in the space pointed to the objective or the exit.

**What changed, and why.** Everything is visual; no collision was added:

| Change | Why |
|---|---|
| **Doorways:** a wall header, wooden trim posts and lintel, and open double doors at the 7 room doorways, plus headers over the nook and alcove openings | Openings read as doors and room boundaries ("I'm leaving the reading room"), not as gaps in a wall. |
| **Restricted doorways in red:** both entrances to the Restricted Stacks (from Hallway West and from the back corridor) have red trim and a red "RESTRICTED · STAFF ONLY" sign | Objective readability: the objective room is recognisable from either approach, before you enter it. |
| **Room signs over doorways**, replacing the floating labels (now hidden): MAIN LIBRARY / ENTRANCE, HALLWAY WEST · STACKS, READING ROOM, HALLWAY EAST, STAFF ROOM, STUDY, ARCHIVE | Clear navigation in the world's own language, read where you make the choice. |
| **Green EXIT signs** with arrows: 2 in the back corridor, 2 in Hallway East, 1 at the reading-room east door, 1 over the exit door | Escape readability: both escape routes are signposted from where you'd be after taking the card. Arrow directions were checked against each sign's facing. |
| **Landmarks:** a large wall clock on the main room's north wall, seen through the entrance door; a globe on the circulation desk; green banker's lamps on the 4 reading tables | Orientation: the clock marks "north" from the first moment, and the globe and lamps make the reading area recognisable at a glance. |
| **Objective focus:** an ARCHIVE plaque and sign at the archive desk, and a warm spotlight on the access card | The card's spot reads as special before the HUD prompt appears. |
| **Coloured light at key places:** a green glow at the exit door, a dim red wash in the Restricted Stacks | Colour coding that matches the signs: green = out, red = restricted. |
| **Entrance:** the yellow Phase 2 sprint lane becomes a red entrance rug, the test crate a blue book-return bin, and the controls sign a notice board | Development-test props now fit the library. The nodes keep their names, so the Phase 2 tests are unchanged. |

**Measured effect:** none on gameplay, by design. `v3/compare.md` shows identical numbers. `metrics.json` was also checked field by field: the floor samples, routes, patrols, hiding spots, respawn points and obstacles all match v2 exactly. The map is unchanged (see `v2/map.png`). All tests pass.

**Before/after:** for example, `v1/views/01_entrance.png` shows an open gap in the wall under a floating "MAIN LIBRARY ROOM" label. `v3/views/01_entrance.png` shows a framed doorway with a MAIN LIBRARY sign, and the clock visible on the far wall.

---

## v4 — Low-poly art pass: materials, lighting, props

Commit: `level(v4): low-poly art pass`. Evidence: `v4/views/`, `v4/report.md`, `v4/map.png`, `v4/compare.md`, and `before_after/` (each viewpoint, v0 beside v4).

**Problem:** v3 was readable but still graybox: flat grey-blue surfaces, an open sky above the walls, and bare blocks for bookcases.

**What changed, and why:**

| Change | Details | Why |
|---|---|---|
| **Palette** | cream walls; oak floor in the main room; stone entrance; blue-grey tile corridors; burgundy carpet in the Restricted Stacks; concrete exit area; walnut bookcases; oak tables | Each zone has its own floor colour, so you can tell where you are from the floor alone, and red still means "restricted". One coherent warm library palette, flat-shaded low-poly. |
| **Books** | `scripts/level/shelf_books.gd` (`ShelfBooks`, `@tool`). One MultiMesh of coloured boxes per bookcase, with shelf boards, generated from a seed (the same every time and visible in the editor), with no collision. On all 7 tall bookcases and the 3 low ones. | Bookcases read as bookcases. The books aren't saved into the scene file, and since they have no collision they can't change sight lines or navigation. |
| **Ceilings** | a slab over every room on render layer 2, casting no shadow; the top-down preview and capture camera skip layer 2 | Indoors feels indoors (no black sky). The top-down evidence views still work. |
| **Lighting** | 15 ceiling lights (`scenes/props/ceiling_light.tscn`: an emissive fixture plus an omni light, no shadows), at most 4 reaching the big main-room floor; ambient light lowered and warmed; the sun dimmed to 0.4 | Warm interior light; the coloured lights from v3 (green exit, red restricted, card spotlight) now stand out. |
| **Props** | 16 chairs tucked into the reading tables (`scenes/props/chair.tscn`, decoration only); 7 potted plants in corners (`scenes/props/potted_plant.tscn`, with collision); 9 night-sky windows on outer walls; 7 posters in the corridors; a teal rug under the reading area; a red runner down the main aisle toward the clock; yellow/black hazard stripes in front of the exit door | Environmental detail. The runner leads the eye from the entrance doorway to the clock (north) and the stacks. The hazard stripes mark the exit. |
| **Exit sign** | the green EXIT sign over the exit door raised to 3.2 m | In v3 it overlapped the door's own LOCKED/UNLOCKED label (seen in the first v4 render). |
| **Navmesh rebaked for the plants** | 220 → 224 polygons | Only the plants have collision. They sit in room corners, out of the way of routes and patrols. |

**Fairness note:** lighting is cosmetic. Guard vision depends only on distance, line of sight and stance (Phase 5 and Phase 8), not on light. So the art pass deliberately avoids dark corners that would suggest you can hide in shadow.

**Measured effect** (`v4/compare.md`): gameplay is unchanged except where the plants nudged the navmesh.

- Mean exposure is 10.3% standing and 9.8% crouched, the same as v3.
- Every route, patrol, hiding spot and respawn point is within 0.6 points of v3 or identical.
- Hallway East is 7.8% (v3 8.2%), from a slightly different patrol path after the rebake.
- Respawn points are still at 0.0%.
- All tests pass, including the navmesh coverage and sealing checks, the 45-second checkpoint safety check and the spawn check.
