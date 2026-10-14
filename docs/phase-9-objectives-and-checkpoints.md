# Phase 9 — Objectives and Checkpoints

The library now has a goal. The player enters, finds the access card in the Restricted Stacks and escapes through the exit, which stays locked without the card. Checkpoints decide where the player comes back after being caught, and which progress survives.

## Objective flow

| # | Objective | Completed by |
|---|---|---|
| 1 | **Enter the library** | walking through the entrance doors into the main room (`EnterLibraryTrigger`) |
| 2 | **Reach the Restricted Stacks** | being anywhere in the Restricted Stacks (`RestrictedStacksTrigger`) |
| 3 | **Take the access card** | using the card on the archive desk at the back of the stacks (E) |
| 4 | **Reach the exit** | being anywhere in the exit area (`ExitAreaTrigger`) |
| 5 | **Escape through the exit door** | using the exit door (E); only possible once 1–4 are done |

Each objective is **LOCKED**, **ACTIVE** or **COMPLETED**. Exactly one is ACTIVE until the last is done. An objective completes only while it is ACTIVE, so they happen in order:

- Walking into the exit area before having the card counts for nothing.
- If an objective becomes ACTIVE while the player is already standing in its area, it completes straight away.

## Delivered

| File | Purpose |
|---|---|
| `scripts/systems/objectives/objective_manager.gd` | `ObjectiveManager`: the ordered flow and the three states. Signals: `objective_changed`, `objective_completed`, `level_completed`. `get_progress()` / `restore()` snapshots for checkpoints. |
| `scripts/systems/objectives/objective_trigger.gd` | `ObjectiveTrigger`: "reach X" areas |
| `scripts/systems/interaction/interactable.gd` | `Interactable`: base class for usable objects (physics layer 4, "interactable"): prompt, `can_interact()`, `interact()` |
| `scripts/player/player_interactor.gd` | `PlayerInteractor` (child `Interactor` of the player): a camera-centre ray, 2.2 m reach, blocked by walls and furniture. **E** uses the focused object. |
| `scripts/systems/objectives/access_card.gd` | `AccessCard`: can only be taken while its objective is ACTIVE. Shown whenever that objective isn't COMPLETED. |
| `scripts/systems/objectives/exit_door.gd` | `ExitDoor`: escapes when the last objective is ACTIVE. Otherwise it rejects the player. Door and sign show red/LOCKED or green/UNLOCKED. |
| `scripts/systems/checkpoints/checkpoint.gd` | `Checkpoint`: activates when the player steps on it. Has a spawn marker, and a pad and label that light up when active. |
| `scripts/systems/checkpoints/checkpoint_manager.gd` | `CheckpointManager`: stores the respawn location and the objective progress, and restores progress after being caught |
| `scripts/utilities/area_utils.gd` | `AreaUtils`: geometric "is the player inside this area" check (see "Problems found and fixed") |
| `scripts/ui/objective_hud.gd` | `ObjectiveHud`: objective panel, interaction prompt, messages, ESCAPED screen |
| `scripts/systems/stealth_director.gd` | new `ESCAPED` status and `finish_level()`. The reset moves the actors before turning their processing back on. |
| `scripts/ui/stealth_hud.gd` | the caught screen names the respawn point ("Back to Staff Nook…") |
| `scripts/player/player.gd`, `scenes/player/player.tscn` | `set_spawn_transform()` / `get_spawn_transform()`, and the `Interactor` node |
| `scenes/level/library_graybox.tscn` | a `Gameplay` node holding: the managers, three triggers, the card, the exit door and two checkpoints. Also: an **archive desk** in the Restricted Stacks, a **Staff Nook** off the back corridor, the `ObjectiveHud`, and **E use** on the controls sign. |
| `scenes/level/library_navmesh.tres` | rebaked: 168 polygons, 661.9 m² |
| `project.godot` | `interact` action (**E**); physics layer 4 named `interactable` |
| `tests/objective_tests.gd` | objective, interaction and checkpoint tests |

### Level changes (level-design version)

- **Archive desk** (0.8 × 0.75 × 1.6 m) against the west wall at the south end of the Restricted Stacks, with the access card on it. It sits in the aisle south of the first shelf row, which the stacks guard doesn't walk. It can still be seen from the end of the patrolled aisle next to it.
- **Staff Nook**: a 2 × 3 m alcove south of the back corridor (x 7–9). The corridor's south wall is split around its opening. The nook is out of sight of both the exit-area guard and the stacks guard. It holds the second checkpoint.
- **Checkpoints:** **Hallway West** (before the stacks) and **Staff Nook** (on the back-corridor route to the exit, after the card). The level start is the implicit first respawn point.

### Checkpoint rules

| Rule | Behaviour |
|---|---|
| Activate | Step onto the pad. It turns green, the label says ACTIVE, and the HUD says "Checkpoint reached: …". Any previously active checkpoint goes back to grey. |
| Store | The checkpoint's spawn transform (position and facing) becomes the player's respawn point, and a snapshot of objective progress is saved. |
| Respawn after being caught | `StealthDirector` freezes everything for 2.5 s, moves the player to the respawn point and resets the guards, then emits `level_reset`. `CheckpointManager` then restores the snapshot. |
| Progress kept | Everything completed **before** the checkpoint was activated, e.g. the card if it was taken before reaching the Staff Nook. |
| Progress undone | Everything completed **after** it. If the card was taken after the last checkpoint, it goes back on the desk and the objective returns to "Reach the Restricted Stacks" or "Take the access card". The player's position and the world then agree again. |
| Guards | Every guard goes back to its start on patrol, with detection, memory, last known position and heard noises all cleared. |
| Not during a chase | Checkpoints don't activate while a guard is chasing, while caught, or after escaping, so a checkpoint can't save a lost situation. |
| Same checkpoint again | Stepping onto the active checkpoint with progress unchanged does nothing, including when the player respawns onto it. Stepping onto it with new progress saves again. |

### Exit condition

- Using the door before the card shows:
  - the prompt `[E] Exit locked (access card needed)`
  - the message "The exit is locked. You need the access card."
  - a rattle: an INTERACTION noise with a 6 m radius that guards can hear, so trying it carelessly has a cost
- The player keeps control, and the level doesn't end.
- With the card, entering the exit area completes "Reach the exit", the door turns green, and `[E] Escape` ends the level. Player and guards freeze, and the ESCAPED screen shows the time and the number of catches. **E** reloads the level.

### Objective UI

- **Panel**, top right: OBJECTIVE, the current title and a hint, then the checklist (`[x]` done in green, `[>]` current in white, `[ ]` locked in grey).
- **Prompt** under the crosshair: `[E] Take the access card`, `[E] Escape`, or a red locked prompt.
- **Messages** (3.5 s): objective done, checkpoint reached, exit locked.
- **ESCAPED screen.**

## Problems found and fixed

- **A checkpoint's restored progress was completed again straight away.** In the first version, triggers used `body_entered`. When the player was caught inside the Restricted Stacks and respawned at Hallway West, Godot reported a fresh "entered" for the stacks trigger: the frozen player's body rejoined the physics world, and the overlap was reported for where it had been caught. That re-completed the objective the checkpoint had just restored, so the card objective came back already unlocked. The automated test caught it ("Progress made after the checkpoint should be undone").
  - Triggers and checkpoints now test the player's position against their box shapes every physics frame (`AreaUtils`), widened by the player's radius.
  - The director also moves the actors before switching their processing back on.
  - A deliberate regression back to `body_entered` fails two tests (below).

## Automated tests (`tests/objective_tests.gd`)

| Requirement | Check |
|---|---|
| ObjectiveManager and states | The MVP order. The first ACTIVE, the rest LOCKED. Out-of-order, unknown and repeated completions are refused and change nothing. Change signals in the right order. Finishing emits `level_completed` once and leaves nothing ACTIVE. `reset()`. |
| Progress snapshots | Snapshot/restore. A snapshot is a copy. Invalid or empty snapshots rebuild a valid flow. |
| Level setup | Managers, HUD and interactor exist. Three triggers with the right ids, two checkpoints, the card and the door. The start state and checklist. A navigation path exists for each leg: spawn → library → Hallway West → stacks → card → Staff Nook → exit door (118 m). |
| Interaction | The card is focused when looked at within reach. Not when looking away, from 3.3 m, or with something solid in between. The prompt text. |
| Order | A LOCKED "reach" objective doesn't complete early. It completes once it becomes ACTIVE while the player is inside. |
| Exit rejects without the card | Locked prompt. Using the door fails. The level isn't finished and the player keeps control. The HUD message. One noise emitted. LOCKED sign, red door. |
| Card and escape | Taking the card hides and disables it, moves to "Reach the exit" and shows the HUD message. Entering the exit area completes that. The door offers Escape and turns green. Using it completes the flow, sets ESCAPED, freezes the player and shows the ESCAPED screen. |
| Checkpoint keeps earlier progress | Card taken → Staff Nook activated (progress and respawn stored; re-entering does nothing). Caught by a test guard: the caught screen names "Staff Nook". The player respawns there, facing the spawn direction, with the card kept. The guard is back on patrol. No activation during a chase. |
| Checkpoint undoes later progress | Hallway West activated → card taken → caught inside the stacks. Respawn at Hallway West: back to "Reach the Restricted Stacks", card back on the desk and usable again. Covers the stale-overlap bug above. |
| Guards reset on respawn | The real level: after patrols have moved, GuardMain catches the player. All three guards are back at their starts, on PATROL, with clear sight, memory and hearing. |
| Fair respawn | The real level: a player standing at each checkpoint's spawn point is not noticed by any guard over 45 s of patrol (every loop at least once). |

## Verification record (2026-10-04)

All runs used the official Linux build of Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`).

| Check | Result |
|---|---|
| Project import | exit 0, no errors |
| Navmesh rebake | `Baked 168 polygons`. The navigation tests confirm the saved navmesh matches a fresh bake (661.9 m²), coverage is 481 open samples with 0 missing and 79 obstacle samples with 0 walkable, the level is sealed (616 edge points, 0 open), and the probe walks entrance → exit. |
| Full test run | `All tests passed (Phase 1 setup … Phase 9 objectives).`, exit 0, about 2 min 20 s; no errors or leaks; the same 8 expected warnings as Phase 8 |
| Main scene | runs 900 frames with no script or engine errors |
| Measured values | route 118 m; exit rejected 1×, then escaped; respawns at Staff Nook (card kept) and Hallway West (card restored, then retaken); all 3 guards reset; both checkpoints unseen for 45 s each |

**Mutation checks.** Each was a copy of the code broken on purpose, run against the objective tests:

| Mutation | Result |
|---|---|
| Exit opens without the card | caught: "Using the exit without the card must fail" (+15) |
| Objectives complete in any order | caught: "Locked objectives must not complete" (+3) |
| `restore()` does nothing | caught: "restore() should go back to the snapshot" (+5) |
| Checkpoint doesn't set the respawn point | caught: "should respawn at the Staff Nook (47.48 m away)" (+3) |
| Progress not restored after being caught | caught: "Progress made after the checkpoint should be undone" (+2) |
| Interaction ignores walls | caught: "Something solid between the player and the card should block interaction" |
| Card ignores its objective state | caught: prompt check. The card still can't actually be taken, because the manager refuses the completion. |
| Checkpoints activate during a chase | caught: "A checkpoint must not activate during a chase" |
| Card doesn't react to objective changes | caught: "A taken card disappears…" (+2) |
| Progress snapshot is live state, not a copy | caught: "A snapshot must be a copy" (+4) |
| Triggers use `body_entered` (the original bug) | caught: "An objective that becomes ACTIVE while the player is inside…", "Progress made after the checkpoint should be undone" |
| Trigger ignores the objective's state | **not caught: equivalent.** `ObjectiveManager.complete()` refuses anything that isn't ACTIVE, so the trigger's own check is a shortcut, not the safeguard. |

**Screenshots** in `docs/evidence/phase-9/` were rendered under a virtual display (Xvfb, Mesa llvmpipe software OpenGL), not on Windows hardware. The level's guards were removed, and a capture script moved the player and called the interactor directly (the same call as pressing E), so time between shots is compressed. That is why the locked-door message is still showing in the card shot. The objective states, prompts and messages are the game's own.

| File | Shows |
|---|---|
| `start.png` | the spawn: objective panel on "Enter the library", the rest locked |
| `exit_locked.png` | at the exit without the card: red door, LOCKED sign, red prompt and rejection message |
| `card_prompt.png` | the card on the archive desk, `[E] Take the access card` |
| `card_taken.png` | card gone, "Access card taken", objective "Reach the exit" |
| `checkpoint_reached.png` | Staff Nook pad lit green, "CHECKPOINT · ACTIVE", "Checkpoint reached: Staff Nook" |
| `exit_unlocked.png` | green door, EXIT · UNLOCKED, `[E] Escape`, all but the last objective done |
| `escaped.png` | the ESCAPED screen |
| `topdown.png` | the level from above: the Staff Nook at the top of the back corridor, the checkpoint pads in Hallway West and the nook |

## Manual verification still required (Windows, Godot 4.7.2 editor, F5)

1. Play the whole route: the objective panel updates at each step, and the messages are readable.
2. Try the exit before the card: locked message and rattle, and the nearby guard may investigate.
3. Take the card with E. Check that the prompt appears only when looking at it closely, not through the desk or a shelf.
4. Step on Hallway West, take the card, get caught: you're back at Hallway West and the card is back on the desk.
5. Take the card, step on the Staff Nook, get caught: you're back in the nook with the card.
6. Escape: the ESCAPED screen shows, and E restarts the level.
7. Check the panel doesn't cover anything important at 1920×1080 and at the default window size.

## Known limitations

- One fixed objective flow, defined in `ObjectiveManager.MVP_OBJECTIVES`. Other levels or flows would call `setup()`, but there's no editor-side objective resource.
- No save or load between sessions. Checkpoints only last within a run, and E on the ESCAPED screen reloads the level from scratch.
- No main menu, pause menu or end credits. The ESCAPED screen is a simple placeholder end state.
- Only two placed checkpoints. The Hallway East route to the exit has none after the card.
- The access card has no carried-item display beyond the checklist.
- No sound for pickups, the door or checkpoints yet. The door rattle is a gameplay noise event only.
