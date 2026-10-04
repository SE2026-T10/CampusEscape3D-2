# Phase 8 — Stealth Loop

This phase joins movement, vision, hearing and the three-state AI into one playable loop, and adds a detection UI so the player can always tell what the guards are doing. It adds no objectives, checkpoints or new guard state.

## The loop

| Step | How it works now |
|---|---|
| 1. Move through the library | Walk, sprint, and (new) **crouch** with **C** or **Ctrl** |
| 2. Avoid guards | Vision cones, shelves and walls (Phase 5), plus four new **study carrels** to duck into |
| 3. Be detected visually | Detection meter (Phase 5). Crouching halves the rate it fills, and a crouched player is a smaller target. |
| 4. Generate noise | Footsteps (Phase 7). Crouch-walking makes very quiet steps (2 m). |
| 5. Guards investigate | Suspicious sighting or noise → INVESTIGATE (Phase 6/7 rules, unchanged) |
| 6. Hide from guards | Crouch inside a carrel: its panels block sight from the sides and back, and the HUD shows **HIDDEN** |
| 7. Guards give up | An investigation that finds nothing searches for 6 s, then returns to PATROL |
| Fail state | A chasing guard that reaches you (≤ 1.2 m, in sight) **catches** you. The screen says CAUGHT for 2.5 s, then you go back to the entrance and every guard goes back to its start on patrol, with no memory of you. |

The caught/reset is a temporary fail state. Checkpoints and objectives come later.

## Delivered

| File | Purpose |
|---|---|
| `scripts/player/player.gd` | Crouch: lower capsule (1.0 m) and eye height (0.95 m), smooth camera, 1.8 m/s speed. Won't stand up under something low. Visibility points and visibility factor (0.5 crouched), noise level for the HUD. |
| `scripts/player/player_noise.gd` | Crouch steps: WALK type at intensity 0.2 and radius 2 m, every 0.9 m. No running while crouched. |
| `scripts/npc/guard_vision.gd` | Aims rays at the player's current body points, so a crouched player can hide behind lower cover. Fill rate × the player's visibility factor. `reset()`. |
| `scripts/npc/guard_hearing.gd` | `reset()` |
| `scripts/npc/guard.gd`, `scenes/npc/guard.tscn` | `reset_to_start()`. **Alert icon** above each guard: red **!** in CHASE, yellow **?** in INVESTIGATE, faint white **?** while its meter is rising. |
| `scripts/systems/hiding_spot.gd` | `HidingSpot` area inside each carrel |
| `scripts/systems/stealth_director.gd` | `StealthDirector`: one player-facing status from all guards, catching, and the level reset |
| `scripts/ui/stealth_hud.gd` | `StealthHud`: banner, direction indicators, stance/noise line, caught screen |
| `scenes/level/library_graybox.tscn` | Four carrels (main room west wall, reading area east wall, restricted stacks, exit area), the director and the HUD; crouch added to the controls sign |
| `scenes/level/library_navmesh.tres` | Rebaked around the carrels (164 polygons, 661.7 m²) |
| `project.godot` | `crouch` action: C and Ctrl |
| `tests/loop_tests.gd` | Stealth loop tests |

### Detection UI (production, not debug)

- **Banner** at the top centre. It shows the most urgent of:
  - **CHASED — break line of sight!** (red): a guard is chasing you
  - **YOU ARE BEING SEEN** (orange): a guard can see you and its meter is filling
  - **A guard is investigating** (yellow)
  - **HIDDEN** (blue): crouched in a carrel and nobody can see you
  - nothing at all when you're unnoticed
- **Direction indicators:** a triangle on a ring around the crosshair points to each guard that is noticing you, investigating or chasing. It's coloured by severity and labelled `?` or `!`. This works for guards behind you too.
- **Icons above guards** (`?` / `!`), visible in the world.
- **Stance line** at the bottom left, e.g. `CROUCHED · noise: QUIET`.
- **Caught screen:** red overlay with "CAUGHT — Back to the entrance…".

The F3 debug view (cones, meters, paths, noise rings) is unchanged and is still only in debug builds.

### Carrels

A carrel is a desk booth with a back panel and two side panels, 1.4 m tall, and one open side. A **standing** player's head shows over the panels. A **crouched** player is hidden from the sides and back. From in front of the opening they can still be seen, but only at half rate. Hiding works because the panels really block sight rays. The `HidingSpot` area only drives the HIDDEN banner. It never makes the player invisible.

## Problems found and fixed

- **The Phase 6/7 library tests started failing:** the new director caught the player in the middle of the chase they test. Those tests now remove the director. Catching has its own tests.
- **The half-rate test measured the wrong thing.** At first it compared the meter only up to the first sighting, which is mostly ray timing. It now measures 30 frames of gain from each position.

## Automated tests (`tests/loop_tests.gd`)

| Requirement | Check |
|---|---|
| Readable status | Status priority CHASE > SPOTTED > INVESTIGATING > HIDDEN > NONE, as a pure function |
| Crouch | Crouch lowers the body, eyes, speed and visibility. You can't stand up under a 1.3 m beam, and you stand once clear of it. |
| Hiding | Carrel in the library: a standing player is seen over the panel; crouched, hidden from the side; crouched in the opening, seen at roughly half rate (35–65% of standing) |
| Investigate then give up | A guard sees the player → the player crouches in a carrel. Statuses go `SPOTTED → INVESTIGATING → HIDDEN`, the guard returns to PATROL, and the player isn't caught. |
| Quiet movement | Crouch-walking past 3 m behind a guard isn't heard and it stays on PATROL. Walking the same line is heard and it investigates. |
| HUD | An indicator points to a guard ahead (≈0°), then to the left (≈-90°) after the player turns right. It fills with the meter, and is a yellow `?` while the guard investigates. The stance line reads STANDING / `CROUCHED · noise: SILENT`. |
| Fairness: escape | A chase started 4 m behind: sprinting away keeps the player ahead, and they are not caught |
| Caught and reset | A guard reaching the player catches them: actors freeze, the reset follows after `reset_delay`, the player is at the spawn, and guards are at their starts in PATROL with empty memory |

The test runner (`tests/test_scene.gd`) runs these after the hearing tests.

## Verification record (2026-10-04)

All runs used the official Linux build of Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`).

| Check | Result |
|---|---|
| Project import | exit 0, no errors |
| Full test run | `All tests passed (Phase 1 setup … Phase 8 stealth loop).`, exit 0, about 1 min 40 s; no leaks or errors; 8 warnings, all expected from earlier phases (test guards without routes or navigation, and the deliberately stuck guard) |
| Main scene | runs 900 frames with no script or engine errors |
| Measured values | carrel: standing seen, crouched hidden from the side; in front of the opening, crouched gained 13.6 vs 26.4 standing over 30 frames (52%). Give-up statuses: `SPOTTED, INVESTIGATING, HIDDEN`, guard back to PATROL, 0 catches. Escape: chase started 4.0 m behind, gap 5.9 m after 2 s, not caught. Catch: caught by the test guard, frozen 2.5 s, reset OK. Navmesh: 164 polygons, 661.7 m²; coverage 482 open samples (0 missing), 77 in obstacles (0 walkable). |

**Mutation checks.** Each was a copy of the code broken on purpose. Every one except the last made the run fail with exit 1:

| Mutation | Caught by |
|---|---|
| Crouch visibility factor ignored | half-rate check in the carrel opening |
| Guard reset keeps its memory | caught-and-reset check |
| Crouch steps as loud as walking | crouch-walking is quiet check |
| HUD angle flipped | HUD indicator check |
| Catch from any distance | escape-by-sprinting check |
| HIDDEN outranks INVESTIGATING | status priority check |
| Can always stand up | low-beam crouch check |
| Vision uses fixed sample heights instead of the player's body points | **not caught: equivalent.** A sight ray only counts if it hits the player's collider. Fixed heights above the crouched capsule hit nothing, so the two versions see the same thing. The change is kept because it stops wasting rays on empty space. |

**Screenshots** in `docs/evidence/phase-8/` were rendered under a virtual display (Xvfb, Mesa llvmpipe software OpenGL), not on Windows hardware. The player was teleported into position by a capture script. The guards, statuses and HUD are the game running normally.

- `hud_spotted.png`: GuardEast sees the player; orange banner, yellow `?` indicator.
- `hud_investigating.png`: the player round the corner, out of sight; the guard is investigating, and the indicator points to it.
- `hud_chase.png`: the guard is chasing, 3.9 m away, with a red `!` above it and the red banner.
- `hud_caught.png`: caught screen.
- `hud_hidden_in_carrel.png`: crouched in the restricted-stacks carrel; blue HIDDEN banner and the stance line.
- `topdown_carrels.png`: the level from above, showing the four carrels (brown).

## Manual verification still required (Windows, Godot 4.7.2 editor, F5)

1. Crouch with C and with Ctrl: the view lowers smoothly, you're slower, the stance line says CROUCHED.
2. Let a guard notice you: the banner and indicator appear, and the guard shows a `?`. Break sight: the banner changes to "A guard is investigating", and after a while it clears as the guard goes back to patrol.
3. Get spotted, then hide crouched in a carrel: HIDDEN shows, and the guard searches and leaves.
4. Get chased and sprint away round a corner: you can escape.
5. Get caught: CAUGHT for about 2.5 s, then you're at the entrance and the guards are back on patrol.
6. Check the HUD is readable at 1920×1080 and at the default window size.

## Known limitations

- The caught/reset is a placeholder fail state. It resets the whole level.
- The direction indicator for a guard straight ahead overlaps that guard's own `?`/`!` icon. It's readable, but redundant.
- Carrels are the only dedicated hiding spots. Crouching behind shelves and desks works because they block sight, but it gives no HIDDEN banner.
- Guards don't look inside carrels on purpose. A guard that walks to the opening can see a hidden player at half rate.
- No sound or animation for crouching, catching or alerts yet.
