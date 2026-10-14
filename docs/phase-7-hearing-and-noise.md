# Phase 7 — Hearing and Noise Perception

A noise event system, player footsteps, and guard hearing that feeds the existing AI. No fourth state: a heard noise becomes INVESTIGATE through the Phase 6 priority rules.

## Delivered

| File | Purpose |
|---|---|
| `scripts/systems/noise/noise_event.gd` | `NoiseEvent`: id, type, position, intensity, radius, timestamp, lifetime, source group; per-type presets |
| `scripts/systems/noise/noise_system.gd` | `NoiseSystem`: per-level hub (a node in the library scene, not an autoload). `emit_noise()`, game-time clock, delivery to listeners, expiry, debug rings |
| `scripts/systems/noise/noise_maker.gd` | `NoiseMaker`: component for interactables (doors, exit, objects) to make INTERACTION noise |
| `scripts/player/player_noise.gd` | `PlayerNoise` (child `Noise` of the player): footsteps per stride |
| `scripts/npc/guard_hearing.gd` | `GuardHearing` (child `Hearing` of each guard, at ear height 1.6 m): range, walls, staleness, de-duplication, position estimate, report |
| `scripts/npc/guard.gd` | `hearing` reference; the label and HUD show the last heard noise |
| `tests/hearing_tests.gd` | hearing tests |

### Noise events

| Type | Radius | Intensity | Lifetime | Made by |
|---|---|---|---|---|
| WALK | 5 m | 0.4 | 0.5 s | player footstep every 0.8 m while walking |
| RUN | 12 m | 1.0 | 0.5 s | player footstep every 1.2 m while faster than 4.5 m/s (sprinting) |
| INTERACTION | 8 m | 0.7 | 1.0 s | `NoiseMaker.make_noise()` (for doors and other interactables when they exist) |

- **Footsteps** happen only on the floor and above 0.5 m/s. Standing still makes no noise, and neither does a teleport (a big jump in position with no velocity).
- **Loudness** at a distance d with effective radius R is `intensity × (1 − d/R)`, falling to 0 at R.
- **Ids and timestamps:** each event gets a unique id and a timestamp from the system's game-time clock, which is scaled physics time, so tests that speed up time stay consistent.
- **Source group:** events carry `source_group` (`"player"`, `"environment"`, …), never a node reference.

### How a guard hears (`GuardHearing`)

1. **Delivery:** `NoiseSystem.emit_noise()` calls `receive(event)` on every node in the `noise_listeners` group. `receive` drops:
   - ids already seen (duplicates)
   - ignored source groups (`"guards"`, so guards don't investigate other guards)
   - anything beyond `radius × sensitivity` even without walls

   Survivors are queued.
2. **Processing:** on the listener's next physics frame, loudest first:
   - **Stale:** dropped if the event's age exceeds `min(max_event_age = 0.75 s, lifetime)`. This happens if the listener was paused, or the event is old.
   - **Walls:** a ray against the world layer checks for one. If blocked, the effective radius is multiplied by `wall_factor` (0.5).
   - **Too quiet:** dropped if loudness is below `min_loudness` (0.02).
3. **Estimate, never the exact source:**
   - error = `min(0.4 + 0.12 × distance, 3)` m, ×1.5 through a wall
   - the estimate lands 60–100% of that error away from the source, in a direction fixed per listener and event
   - the guard's name and the event id are bit-mixed, so two guards get independent guesses
4. **Merge repeated noise:** if the estimate is within `merge_radius` (2.5 m) of this listener's last report and within `merge_window` (1 s), it's merged and not re-reported. A trail of footsteps makes one report per spot per second, not one per step.
5. **Report:** the `noise_reported(estimate, loudness, event)` signal fires and the guard's `hear_noise(estimate, loudness)` is called. The AI sees it as `GuardPerception.noise_heard` / `noise_position` on the next frame, loudest of the frame.

### Priority between sight and hearing

Hearing uses the Phase 6 rules unchanged:

| Situation | Result |
|---|---|
| Confirmed sighting and noise in the same frame | **CHASE** the sighting; the noise is ignored |
| Suspicious sighting and noise, in PATROL | **INVESTIGATE the sighting position**; sight beats sound as the target |
| Noise only, in PATROL | **INVESTIGATE** the *estimated* noise position |
| Noise during INVESTIGATE | moves the investigation to the new estimate, unless a fresh suspicious sighting is the target |
| Noise during CHASE | **ignored**: a chase follows sight and the last known position only |

The guard never learns the player's exact position from sound. Hearing only ever passes on an estimate, and CHASE never uses hearing.

### Debug (debug builds, F3)

- **Rings** at each noise's radius, fading over its lifetime: blue (WALK), orange (RUN), violet (INTERACTION).
- **Orange cross** at each guard's estimated position for 3 s after it reports a noise.
- **Guard label and HUD panel:** `heard RUN → (x, z)`.

## Problems found and fixed

- **Guards could ride the player like a moving platform.** In the first hearing arena run, a guard and the player overlapped for one physics step, and the guard was pushed onto the player's head. When the player was then moved, the guard was carried along. Godot was treating the player as a moving floor. Both guards and the player now set `platform_floor_layers = 1` (world only), and the tests place bodies before adding them to the tree.
- **Two guards made the same "independent" guess.** The estimate direction came from hashing strings like `"GuardA"` and `"GuardB"`, which differ by 1 under Godot's string hash, so the two estimates landed 2 mm apart. Values are now bit-mixed, and the same check shows the guards' estimates 2.05 m apart.

## Automated tests (`tests/hearing_tests.gd`)

| Requirement | Check |
|---|---|
| Event data and types | presets rank walk < interaction < run; loudness falls with distance; `NoiseMaker` emits INTERACTION with a timestamp and lifetime |
| Detects relevant noise within range | WALK at 4 m heard, at 6 m not; RUN at 11 m heard, at 13 m not |
| Walls | RUN 9 m away behind a wall: not heard. The same distance clear of the wall: heard. |
| Estimates the source | 40 estimates at 2 m and 10 m: none exact, all within 60–100% of the bound, deterministic, and less accurate far away. Two guards hearing one noise estimate it differently. |
| Triggers INVESTIGATE | in the library, sprinting behind a facing-away guard gives `PATROL→INVESTIGATE (noise)`, targeting an estimate 0.2–2 m from a footstep |
| Never the player's exact position | heard player footsteps: every estimate more than 0.2 m off. The library investigation target isn't the player's position. |
| Ignores stale events | a 2 s-old event is rejected; a real event processed 1 s late (listener paused) is dropped; expired events leave the system |
| Avoids duplicate processing | the same event delivered twice is processed once; 5 footsteps in one spot within 1 s give 1 report and 4 merges; a far-away noise in the window is still reported; the same spot after the window is reported again |
| Multiple guards | a run 11 m from both guards is heard by both; a walk near guard B is heard only by B; guard-made noise is ignored |
| Footsteps | walking 2 s gives 8 WALK and no RUN; sprinting 2 s gives 7 RUN (plus 2 WALK while speeding up); standing still and teleporting give none |
| Sight vs hearing priority | in the library, a guard chasing a visible player ignores a RUN and an INTERACTION noise elsewhere; its chase target stays on the player. Unit tests from Phase 6 cover sighting > noise. |

## Verification record (2026-10-04)

All runs used the official Linux build of Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`).

| Check | Result |
|---|---|
| Project import | exit 0, no errors or warnings |
| Full test run | `All tests passed (Phase 1 setup … Phase 7 hearing).`, exit 0, about 1 min; no leaks; only the expected warnings from test guards without routes or navigation, and the deliberate stuck guard |
| Measured values | estimate error: mean 0.52 m at 2 m and 1.25 m at 10 m, never exact; two guards' estimates 2.05 m apart; walking 2 s gave 8 WALK steps; sprinting 2 s gave 7 RUN and 2 WALK; sprint behind a guard gave `PATROL→INVESTIGATE (noise)` with the target 0.66 m from the nearest footstep |

**Mutation checks.** Each copy was broken on purpose and tested. Every one failed with exit 1:

| Mutation | Caught by |
|---|---|
| Estimate returns the exact source | "40 estimates were exactly the source position" |
| No staleness check | "A 2-second-old noise must be ignored as stale"; "processed 1 s late should be dropped" |
| No event-id de-duplication | "The same event delivered twice must be processed once" |
| No merging | "Five footsteps in one spot within 1 s should give 1 report (got 5, merged 0)" |
| Walls ignored | "A running step 9 m away behind a wall should be muffled out of range" |
| Unlimited hearing range | the wall/range checks |
| Noise can interrupt a chase | "Noise must not pull a guard out of CHASE"; "A suspicious sighting should beat noise as the investigation target" |
| Every footstep counts as running | "Walking 2 s … should make about 8 WALK steps and no RUN"; "Walking 7 m behind a guard should not be heard" |

**Screenshots** in `docs/evidence/phase-7/` were rendered under a virtual display (Xvfb, Mesa llvmpipe software OpenGL), not on Windows hardware.

- `footsteps_heard.png`: the player sprinting behind `GuardMain`, with orange 12 m RUN rings. The guard has switched to `INVESTIGATE (→ (-3.4, 0.9))` and the panel says `heard RUN → (-3.4, 0.9)`. The orange cross marks its estimate, offset from the true footsteps.
- `guard_investigates_noise.png`: after the player left, the guard walks to its estimate.

## Manual verification still required (Windows, Godot 4.7.2 editor, F5)

1. With F3 on, walk around: faint blue rings, small. Sprint: big orange rings.
2. Walk past behind a guard about 6 m away: it shouldn't react. Sprint past: it should turn and come to roughly where you were, not exactly.
3. Sprint on the other side of a wall near a guard: it should react only when you're quite close.
4. Let a guard see you and start chasing, then make noise elsewhere: it keeps chasing you.

## Known limitations

- Nothing in the game uses INTERACTION noise yet. `NoiseMaker` is ready for doors and the exit when interaction exists.
- Walls only reduce range. There's no sound propagation along corridors or around corners.
- Guards don't make noise and don't alert each other by sound.
- No crouch or sneak walk. The only quiet movement is walking.
