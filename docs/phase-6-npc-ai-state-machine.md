# Phase 6 — NPC AI State Machine

Guards now act on what they perceive, through an explicit state machine with exactly three primary states: **PATROL**, **INVESTIGATE** and **CHASE**. Catching the player has no consequence yet.

## Architecture

```
Guard (CharacterBody3D) = the actor: senses and moves
 ├─ Vision (GuardVision)        → can_see_target, detection, awareness, last_known_position
 ├─ hear_noise(position)        → hook for the hearing phase
 ├─ build_perception() ───────► GuardPerception snapshot (this frame only)
 │                                   │
 │                                   ▼
 └─ machine: GuardStateMachine ── tick(perception, delta)
        ├─ PatrolState       (route, current point, waiting sub-step)
        ├─ InvestigateState  (target, travel → search with look-around)
        └─ ChaseState        (target from sightings, time since seen)
              │ states act only through the actor:
              ▼ navigate_to(), stop_moving(), has_arrived(), is_stuck(), face_yaw() …
        Guard executes movement: NavigationAgent3D + avoidance + move_and_slide
```

| File | Role |
|---|---|
| `scripts/npc/ai/guard_state_machine.gd` | `GuardStateMachine` (RefCounted): states, allowed transitions, priority rules, lifecycle, signals |
| `scripts/npc/ai/guard_state.gd` | `GuardState` base class: `enter(actor, previous, position)`, `update(actor, perception, delta)`, `exit(actor, next)`, `get_debug_text()`; documents the actor interface |
| `scripts/npc/ai/patrol_state.gd` | PATROL |
| `scripts/npc/ai/investigate_state.gd` | INVESTIGATE |
| `scripts/npc/ai/chase_state.gd` | CHASE |
| `scripts/npc/ai/guard_perception.gd` | `GuardPerception`: the per-frame perception snapshot |
| `scripts/npc/guard.gd` | Guard as the actor: builds perception, runs the machine, carries out movement |
| `scripts/systems/detection_debug_hud.gd` | debug panel now shows each guard's AI state |

### No hidden global state

- All AI state lives in each guard's own `GuardStateMachine` and its three state objects.
- There are no singletons, autoloads or `static var`. A test checks the AI scripts contain no `static var`, and that two machines run independently.
- States hold the machine through a **weak reference**. With a strong one, the reference cycle leaked every guard's AI when the guard was freed (188 objects in the full suite). That leak was found and fixed in this phase.

## States

| State | Behaviour | Leaves when |
|---|---|---|
| **PATROL** | Walks the route at `patrol_speed` (2 m/s). Waiting at a point is a sub-step, not a state. Keeps its current point while away and resumes it on return. Forgets old evidence on re-entry. | the priority rules fire |
| **INVESTIGATE** | Walks to the target at `investigate_speed` (2.6 m/s). On arrival (or if stuck, or after 20 s of travel) it searches: stands and looks ±60° every 1.5 s for `investigate_search_duration` (6 s). New evidence moves the target (sighting beats noise) without re-entering the state. | confirmed sighting → CHASE; search timed out → PATROL |
| **CHASE** | Runs at `chase_speed` (4.2 m/s; the player walks at 3.5 and sprints at 5.5). While the player is visible, the target follows the sighting position, re-planning when it moves more than 0.5 m. After losing sight, it runs to the frozen last known position. | reached it, got stuck, or `chase_lose_sight_time` (4 s) without sight → INVESTIGATE at that position |

### Perception inputs (built by `Guard.build_perception()`)

| Field | Meaning |
|---|---|
| `confirmed_sighting` | the player is in view **and** awareness is ALERTED (meter = alert threshold, 100) |
| `suspicious_sighting` | awareness ≥ SUSPICIOUS (meter ≥ 30) **and** the player was seen within `suspicion_memory` (2 s), with a last known position |
| `can_see_player`, `sighting_position` | direct view this frame; the vision's last known position (updated only on seen frames) |
| `noise_heard`, `noise_position` | set for one frame by `hear_noise()` (the hearing system is a later phase) |

CHASE only ever navigates to `sighting_position`, which is the vision's last known position. It never reads the player node.

## Transitions

### Allowed transitions (`GuardStateMachine.ALLOWED`)

| From | To |
|---|---|
| PATROL | INVESTIGATE, CHASE |
| INVESTIGATE | CHASE, PATROL |
| CHASE | INVESTIGATE |

### Deterministic priority (checked first every tick, in this order)

1. **Confirmed sighting** → CHASE, from PATROL or INVESTIGATE.
2. **Suspicious sighting** → INVESTIGATE at the sighting position, from PATROL.
3. **Noise** → INVESTIGATE at the noise, from PATROL.
4. **Otherwise** the current state's `update()` runs and may request: INVESTIGATE → PATROL (search timed out) or CHASE → INVESTIGATE (lost sight).

If a rule fires, the state's `update()` is skipped for that tick. `choose_priority_transition(perception)` is a pure function, so the unit tests call it directly.

### Safety rules in `request_transition(to, reason, position)`

- **Rejected and reported** through the `transition_rejected` signal and a warning:
  - unknown ids
  - requests before `start()`
  - transitions not in `ALLOWED`, for example CHASE → PATROL
  - requests made from inside `enter()` or `exit()`, where a transition is already in progress
- **Same-state requests** return `false` with no side effects: no exit or enter runs.
- **During `update()`:** the first request is queued and applied right after `update()` returns; further requests in the same update are rejected.

### Lifecycle

On a transition: `exit(old, next)` → `state_exited` → `enter(new, previous, position)` → `state_entered` → `transitioned(from, to, reason)`. `time_in_state` resets on enter.

## Other changes

- **Old WAIT state:** the Phase 4 `PATROL`/`WAIT` enum is gone. Waiting is inside `PatrolState`, and the `patrol_wait_changed(waiting, index)` signal replaces `state_changed` for patrol waits. The guard tests were updated to use it.
- **Stuck detection** now measures progress: the remaining path length must shrink by 0.5 m within `stuck_timeout`. Low speed alone triggers the sidestep below.
- **"Keep right":** in testing, two guards meeting exactly head-on deadlocked, because avoidance pushed straight back and forth. A guard moving at under 25% of its intended speed for 0.6 s now steers 35° to its own right. Guards facing each other then separate, and the head-on test's two laps dropped from 34.7 s (Phase 4) to 21.5 s.
- **`NavigationUtils.wait_for_navigation()`** now also requires the map to contain a region. An empty map answers every query with (0, 0, 0), which made a guard standing at the origin think navigation was ready.
- **Debug:**
  - the guard label shows the state and its detail, e.g. `INVESTIGATE (searching 3.2s)`, and is tinted white (PATROL), yellow (INVESTIGATE) or red (CHASE)
  - the F3 panel lists every guard's state

## Automated tests

### Unit tests: `tests/ai_state_tests.gd` (fake actor and route, no physics)

| Mandatory test | Function | Check |
|---|---|---|
| Initial state is PATROL | `test_initial_state_is_patrol` | NONE before `start()`, PATROL after, entered once, walking to point 1; a second `start()` is ignored |
| PATROL → INVESTIGATE | `test_patrol_to_investigate`, `test_noise_triggers_investigate` | suspicious sighting and noise each start INVESTIGATE at the right position and speed; noise doesn't interrupt CHASE |
| PATROL → CHASE | `test_patrol_to_chase` | a confirmed sighting starts CHASE at chase speed |
| INVESTIGATE → CHASE | `test_investigate_to_chase` | — |
| INVESTIGATE → PATROL after timeout | `test_investigate_to_patrol_after_timeout` | travels, searches, is still INVESTIGATE 0.2 s before the timeout, PATROL just after, and forgets the evidence |
| CHASE → INVESTIGATE after losing the player | `test_chase_to_investigate_after_losing_player` | by the lose-sight timer and by arriving; investigation at the last known position; CHASE → PATROL not allowed |
| Confirmed sighting beats noise | `test_confirmed_sighting_beats_noise` | sighting + noise in the same frame → CHASE the sighting; suspicious sighting beats noise as the investigation target |
| Invalid transitions handled safely | `test_invalid_transitions_are_rejected` | CHASE → PATROL, id 7 and NONE are rejected and reported with no enter/exit; a request from inside `enter()` is rejected |
| Enter/exit behaviour | `test_enter_exit_order_and_arguments`, `test_patrol_resumes_where_it_left_off` | exit → enter → transitioned order; `time_in_state` resets; patrol resumes its point |
| Repeated requests don't corrupt | `test_repeated_requests_do_not_corrupt`, `test_random_request_storm_keeps_invariants` | 5 identical requests → 1 transition; the same evidence every frame doesn't re-enter; 2000 random requests and ticks (seeded) keep the state valid, enters and exits paired, and every transition legal |
| Also | `test_exactly_three_primary_states`, `test_investigate_moves_to_new_evidence`, `test_chase_follows_only_perception`, `test_no_shared_state_between_machines` | — |

### Behaviour tests: `tests/ai_behavior_tests.gd` (real library, player, vision, navigation)

- A guard posted in the main room, facing a player 7 m away, goes PATROL → INVESTIGATE (suspicious sighting) → CHASE (confirmed sighting) and closes in.
- The player then hides in the east hallway. The guard's navigation target stays at the last known position and more than 10 m from the real player. It goes CHASE → INVESTIGATE at that spot, searches, then INVESTIGATE → PATROL. The exact four-transition sequence is checked.
- `hear_noise()` sends a patrolling guard to the noise (it arrives within 1.2 m), searches for 6 s (±0.3), then returns to PATROL.

## Verification record (2026-10-04)

All runs used the official Linux build of Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`).

| Check | Result |
|---|---|
| Project import | exit 0, no errors or warnings |
| Full test run | `All tests passed (Phase 1 setup … Phase 6 AI).`, exit 0, about 45 s; three runs, identical results; no leaks; only the expected warnings (no-route and vision-arena guards, deliberate stuck guard) |
| Unit tests | 0 failures; random storm made 295 transitions in 2000 operations, all legal |
| Detection cycle (in the library) | 0.8 s PATROL→INVESTIGATE (suspicious sighting), 2.2 s INVESTIGATE→CHASE (confirmed sighting), 3.5 s CHASE→INVESTIGATE (lost sight), 9.7 s INVESTIGATE→PATROL (investigation timed out) |
| Noise investigation | arrived 0.4 m from the noise, searched 6.07 s, returned to PATROL |
| Main scene, 900 frames headless | no errors or warnings |

**Mutation checks.** Each copy was broken on purpose and tested:

| Mutation | Result |
|---|---|
| Noise checked before confirmed sighting | caught: 3 priority failures |
| CHASE → PATROL allowed | caught: "CHASE → PATROL must not be allowed / rejected" |
| Re-entrancy guard removed | caught: "A transition requested from enter() must be rejected" |
| Exit callbacks skipped | caught: order checks, "Every exit must be paired with an enter" |
| Investigation never times out | caught: unit timeout test and the in-level cycle |
| Guard uses the player's live position as the sighting | caught: "After losing sight the guard should go to the last known position", "target must not follow the hidden player" |
| Same-state check removed **and** self-transitions allowed | caught: "Five identical requests should cause exactly one transition (accepted 5, entered 5)" |
| Same-state check removed alone | **not caught, and harmless**: the `ALLOWED` table already rejects X → X, so behaviour is unchanged |

**Screenshots** in `docs/evidence/phase-6/` were rendered under a virtual display (Xvfb, Mesa llvmpipe software OpenGL), not on Windows hardware.

- `chase_topdown.png`: `GuardEast` in CHASE (red cone) with the player in sight; the panel shows `CHASE (pursuing)  ALERTED 100`
- `investigate_search_topdown.png`: after the player slipped away, `GuardEast` in `INVESTIGATE (searching 5.1s)` at the last known position

## Findings for the automated-build phase

- **A test runner that fails to compile hangs Godot instead of exiting.** A parse error in a test file made the headless run hang for 10 minutes. The Phase 5 compile check runs inside the runner, so it can't catch this. CI must wrap the test command in a timeout.
- **Leaks and engine errors don't fail the run.** CI should fail on `ObjectDB instances were leaked` and on `ERROR:` lines in the log.

## Manual verification still required (Windows, Godot 4.7.2 editor, F5)

1. Step into a guard's cone. Its label should turn yellow (INVESTIGATE) as it walks toward you, then red (CHASE) as it runs after you.
2. Break line of sight behind a wall. The guard goes to where it last saw you, looks around for about 6 s, then walks back to its route.
3. Sprint away: you should outpace a chasing guard (5.5 vs 4.2 m/s). Walking (3.5 m/s) shouldn't be enough.
4. The F3 panel and labels match what each guard is doing.

## Known limitations

- Being caught does nothing yet; catching the player and game over come later.
- No hearing yet. `hear_noise()` exists and is tested, but nothing in the game calls it.
- Search is a simple left/right look at one spot, with no wandering to nearby points.
- Guards don't alert each other.
