# Phase 5 — NPC Vision and Detection

Guards see the player through a field-of-view cone with raycast line of sight, filling a 0–100 detection meter. No chase or investigate behaviour: guards keep patrolling, and detection is exposed for later phases.

## Delivered

| File | Purpose |
|---|---|
| `scripts/npc/guard_vision.gd` | `class_name GuardVision`: reusable perception component |
| `scenes/npc/guard.tscn` | new `Vision` child at eye height (1.6 m), facing the guard's forward (−Z) |
| `scripts/npc/guard.gd` | `vision` reference; the debug label adds the meter line |
| `scripts/player/player.gd` | the player joins the `player` group, which is how perception finds it |
| `scripts/systems/detection_debug_hud.gd` | on-screen debug panel listing every guard (`DetectionDebugHud` in the library) |
| `tests/vision_tests.gd` | vision tests |
| `tests/test_scene.gd` | new check that every project script compiles |

### How a guard sees

Each physics frame, for each of three points on the player (1.5 m head, 0.9 m chest, 0.3 m knees), all of these must pass:

1. **Distance:** within `detection_distance` (14 m).
2. **FOV:** angle from the eye's forward ≤ `fov_degrees` / 2 (90° cone). The cone turns with the guard.
3. **Line of sight:** a ray from the eye to the point, against the **world + player** layers with the guard excluded, must hit the player first. Walls, shelves and tables block it. Other guards (npc layer) don't.

The player counts as seen if any point passes. So a standing player behind a low table is still visible above it, while one behind a 2.2 m shelf is hidden.

### Detection meter

| Setting | Default | Meaning |
|---|---|---|
| `max_rise_rate` | 60 /s | gain at or inside `near_distance` (3 m): 0→100 in about 1.7 s |
| `min_rise_rate` | 12 /s | gain at `detection_distance`: 0→100 in about 8.3 s |
| (between) | linear | e.g. 46.9 /s at 6 m, so 100 in 2.13 s |
| `decay_delay` | 1.0 s | grace period after losing sight before draining |
| `decay_rate` | 15 /s | drain speed: 100→0 in about 6.7 s |
| `suspicious_threshold` | 30 | UNAWARE → SUSPICIOUS |
| `alert_threshold` | 100 | SUSPICIOUS → ALERTED |
| `hysteresis` | 5 | how far below a threshold the meter must fall before dropping a level |

- **The meter only rises on frames where the player is actually seen.** Distance scales the rate, so detection is never instant at range: one second at 13 m gives about 16.
- **Signals:** `awareness_changed(previous, current)`, `target_spotted`, `target_lost`.
- **Last known position** is written only on frames where the player is seen: their feet position, plus `has_last_known_position`. `forget_last_known_position()` clears it for later phases.
- **AI code reads only** `can_see_target`, `detection`, `awareness` and the last known position. `GuardVision` keeps a reference to the player for the geometric checks but never exposes its live position.

### Debug visualization (debug builds, F3)

- **Vision cone** on the floor:
  - 24 rays, so it's cut off where walls and shelves block sight
  - coloured green (UNAWARE), yellow (SUSPICIOUS) or red (ALERTED)
  - redrawn 10 times a second
- **Magenta line** from the eye to the player while visible.
- **Last-known-position marker:** a magenta cross with a post.
- **Guard label** gains a third line, e.g. `SUSPICIOUS [####------] 42  SEES PLAYER`.
- **`DetectionDebugHud`** panel at the top left: every guard's awareness, meter and last known position.

## Level change: GuardMain could see the spawn

Running the library for 60 s with the player standing at the spawn showed `GuardMain` spotting the player through the entrance doorway at about 9 s. That happens as it walks toward, and waits at, its second patrol point at (−2.5, 10), facing the doorway.

That point moved to (−6, 10). From there the south wall blocks the line to the spawn, and the rest of its loop is either out of range or facing away. A test now watches the spawn for 45 s, a full loop of every guard. Putting the old point back makes that test fail (see the mutation checks).

## Test runner change: scripts must compile

While building this phase, a GDScript type error in `guard_vision.gd` printed parse errors, yet **the suite still passed with exit 0**. The broken script simply never ran.

`tests/test_scene.gd` now loads every `.gd` file under `scripts/`, `tests/` and `tools/` and fails if any can't compile. I re-ran it against the broken file to confirm: "Script fails to compile: res://scripts/npc/guard_vision.gd", exit 1.

## Engine errors are not yet a test failure

A headless run of the main scene printed "No vertices were added, surface can't be created". The vision debug drawing opened an empty line surface when there was no sight line or marker to draw. That's fixed, and the main scene now runs 900 frames with no errors. The tests never noticed, because Godot engine errors (unlike script compile errors) don't change the exit code. The automated-build phase should fail a run whose log contains `ERROR:` lines.

## Automated tests (`tests/vision_tests.gd`)

Most checks run in an arena built by the test, with the real guard and player scenes:

- a floor
- a 6 m wall 5 m in front of one guard position
- a 0.75 m table
- a 2.2 m shelf

| Requirement | Check |
|---|---|
| Configurable distance and FOV | `is_in_view` inside the cone, at 44° (in), 46° (out), behind, and past range. A player beyond range isn't seen; just inside range is. |
| Inside the FOV | players 3 m to the side, 2 m behind and 50° off-axis aren't seen; 40° off-axis is. After the guard turns 90°, its new forward side is seen. |
| Raycast line of sight, walls block | a player 9 m ahead behind the wall is never seen, with no meter rise and no last known position. Control: the same distance just clear of the wall's edge is seen. A tall shelf hides; a low table doesn't. |
| Meter 0–100, rises while visible | 6 m straight ahead: seen on the first frames, rises monotonically, reaches 100 within 2 frames of the expected 2.13 s, signals spotted → SUSPICIOUS → ALERTED |
| Falls when not visible | holds for `decay_delay`, is about 70 after 2 s of decay, then reaches 0, signals lost → SUSPICIOUS → UNAWARE |
| Configurable thresholds | with thresholds 10/50, ALERTED triggers at a meter of about 50 |
| Last known position | equals the player's position when seen. Moving the player to three hidden spots doesn't change it. |
| No instant detection from range | one second at 13 m stays below SUSPICIOUS |
| Library | every guard has `Vision`; no guard detects the player at the spawn during 45 s; the HUD lists every guard |
| Debug | the cone outline straight ahead stops at the wall (4.85 m) while its edge clear of the wall reaches 14 m |

## Verification record (2026-10-04)

All runs used the official Linux build of Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`).

| Check | Result |
|---|---|
| Project import | exit 0, no errors or warnings |
| Full test run | `All tests passed (Phase 1 setup, Phase 2 player, Phase 3 navigation, Phase 4 guards, Phase 5 vision).`, exit 0, about 44 s; three consecutive runs, identical results |
| Measured values | player 6 m ahead: seen after 0.13 s, SUSPICIOUS at 0.73 s, 100 at 2.20 s (expected 2.13 s, within 2 steps of 0.067 s); after losing sight the meter held at 100 for 1.0 s and read 70.0 after 2 s of decay; 1 s at 13 m gave a meter of 16.4; nothing seen at 15.5 m |

**Mutation checks.** Each copy was broken on purpose and tested. Every one failed with exit 1:

| Mutation | Caught by |
|---|---|
| No raycast (see through walls) | "The guard saw the player through a wall", the tall-shelf check, and spawn detection |
| FOV ignored | 46° and behind checks; "A player behind the guard should not be visible" |
| Instant detection | "Meter reached 100 in 0.13s; expected 2.13s"; the 13 m check; the threshold check |
| No decay | "After 2 s of decay the meter should be about 70, was 100.0"; never returns to UNAWARE |
| Live position leaks into last known position | "Last known position changed while the player was hidden" |
| Distance ignored (always max rate) | rate checks; "At 13 m, one second of sight should not reach SUSPICIOUS (meter 60.0)" |
| Old GuardMain patrol point | "A guard detected the player standing at the spawn point within 45 s" |

**Screenshots** in `docs/evidence/phase-5/` were rendered under a virtual display (Xvfb, Mesa llvmpipe software OpenGL), not on Windows hardware.

- `topdown_vision_cones.png`: all three cones cut off by walls and shelves, `GuardRestricted` SUSPICIOUS (yellow) with a sight line, and the HUD panel
- `guard_sees_player.png`: first-person view of `GuardRestricted` looking at the player, with the label meter and HUD

## Manual verification still required (Windows, Godot 4.7.2 editor, F5)

1. Press F3. Walk into a guard's cone and watch the meter rise. Step behind a shelf and confirm it stops, holds for about 1 s, then drains.
2. Approach from behind and the side: no detection. Then try crossing the cone's far edge versus close up and feel the difference in fill speed.
3. Stand at the spawn for a minute: nobody notices you.
4. The cone visuals line up with what the guard can actually see. Guards keep patrolling regardless of detection, which is expected in this phase.

## Known limitations

- Guards don't react to detection yet. That comes with investigate and chase.
- No hearing yet: noise from sprinting is a later phase.
- No crouching or lighting modifiers. Every visible point counts the same.
- The cone is drawn at floor level, so it shows sight at eye height projected down. Low cover like tables doesn't cut it, matching the rule that a standing player is visible above tables.
- Perception finds the player through the `player` group, so only one player is supported.
