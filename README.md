# Campus Escape 3D

Campus Escape 3D is a low-poly, first-person 3D stealth game set in a university library. The MVP is one polished playable level, built in Godot with GDScript.

## Project details

- Engine: Godot 4.7.2 Stable (`ed1daf0bf`)
- Language: GDScript
- Target: Windows desktop
- Current phase: Phase 12 — Presentation polish

## Run the project

1. Install Godot 4.7.2 Stable.
2. Import `project.godot` in the Godot Project Manager.
3. Open the project and press **F5**. The game opens on the main menu: **Start game** loads the library. To jump straight into the level while developing, open `scenes/level/library_graybox.tscn` and press **F6**.

### Controls

| Action | Key |
|---|---|
| Move | **W A S D** |
| Sprint | hold **Shift** |
| Crouch (quieter, harder to see, slower) | hold **C** or **Ctrl** |
| Use (take the access card, open the exit) | **E** |
| Look | mouse |
| Pause / resume (shows the cursor and the pause menu) | **Escape** or **P** |
| Debug view: navigation, guard paths, routes, vision cones, detection, AI state, noise rings and hearing estimates (debug builds) | **F3** |

There is no jump: the library has no vertical routes, and jumping onto shelves would let the player skip sections or climb out. All keys are defined in **Project Settings → Input Map**.

### The level

The library level (`scenes/level/library_graybox.tscn`; the file name is kept from the graybox so references stay stable) is one small low-poly university library:

- **Entrance:** spawn, with a red rug, plants and a notice board.
- **Main Library Room:** four tall bookcases on the west side; on the east, a **Reading Area** with tables, green lamps, low 1.2 m bookcases (crouch cover) and the circulation desk with a globe. A wall clock on the north wall faces the entrance.
- **Hallway West** to the **Restricted Stacks** (the objective area: red carpet, red RESTRICTED signs on both doors, and the access card under a spotlight on the archive desk).
- **Back Corridor** with book carts and the **Staff Nook** checkpoint.
- **Hallway East** with a **study alcove** carrel.
- **Exit Area**, guarded, with crates, a rack and the exit door.

There are two routes to the card (west via Hallway West, east via Hallway East and the back corridor) and two ways from the card to the exit. Green EXIT signs mark both escape routes. How the level got here, with measurements and before/after pictures for each version, is in `docs/level/LEVEL_LOG.md`.

Three **guards** (dark blue) patrol the main room, the restricted stacks and the exit area (GuardEast is the exit warden). Each walks its own looping route with `NavigationAgent3D` and pauses at every patrol point. Guards **see**: each has a 90° vision cone reaching 14 m, blocked by walls and shelves. While a guard can see you, its detection meter (0–100) fills: fast up close, slowly at long range. Once you're out of sight it drains again. At 30 the guard becomes SUSPICIOUS, at 100 ALERTED. It remembers where it last saw you, and nothing else. Each guard runs an explicit state machine with three states:

- **PATROL:** walks its route.
- **INVESTIGATE:** walks to where it saw something suspicious (meter ≥ 30) or heard a noise, then searches there for 6 s before going back to patrol.
- **CHASE:** runs after you once the meter is full and it can see you. If it loses sight, it heads to where it last saw you and investigates there.

Guards also **hear**:

- Walking makes quiet footsteps, heard within about 5 m.
- Sprinting makes loud ones, heard within about 12 m.
- Walls halve those distances.
- A guard that hears you investigates where it *thinks* the noise came from. That estimate is always somewhat off, and the further away the noise, the worse the guess.

Seeing you always outranks hearing you, and a chasing guard ignores noise.

Crouching halves how fast a guard's meter fills, makes you a smaller target and makes your footsteps very quiet (about 2 m), at the cost of speed. Five **study carrels** (desk booths with 1.4 m panels) are hiding spots: crouch inside one and the panels block sight from the sides and back. Standing, your head shows over them.

**Detection UI.** A banner at the top tells you the most urgent situation: **CHASED — break line of sight!** (red), **YOU ARE BEING SEEN** (orange), **A guard is investigating** (yellow) or **HIDDEN** (blue). Triangles around the crosshair point to each guard that is noticing, investigating or chasing you, including guards behind you. Guards show a `?` or `!` above their heads. The bottom-left line shows your stance and noise level.

**Goal.** The objective panel (top right) walks you through the level:

1. Enter the library.
2. Reach the Restricted Stacks.
3. Take the access card from the archive desk at the back of the stacks (look at it and press **E**).
4. Reach the exit.
5. Escape through the exit door (**E**).

Objectives complete in order. The exit door stays locked (red) until you have the card. Trying it anyway rattles the door, which nearby guards can hear.

**Checkpoints.** Step onto a checkpoint pad (Hallway West, and the Staff Nook off the back corridor) to make it your respawn point. It turns green.

**Caught.** A chasing guard that reaches you catches you. After 2.5 s:

- you're back at your last checkpoint, or the entrance if you haven't reached one;
- every guard is back on patrol with no memory of you;
- objective progress goes back to what it was when you reached that checkpoint. If you took the card after the checkpoint, the card is back on the desk.

Checkpoints don't activate during a chase.

**Game flow.** The game has four game-level states, separate from the guards' AI:

- **PLAYING**
- **CAUGHT**: the short caught screen
- **PAUSED**
- **WIN**: escaped

What happens in each:

- **Pause** (Esc/P, or the window losing focus) freezes the whole level: guards, navigation, physics, noise and timers. The cursor appears and the pause menu offers **Resume**, **Restart level** and **Main menu**.
- **Caught:** after the caught screen the game respawns you and returns to PLAYING. You can't pause during the caught screen.
- **Win:** escaping shows your time and catches, with **Play again** and **Main menu**.

The mouse is captured only while playing.

Press **F3** to show the navigation mesh (cyan), each guard's current path (yellow), its route (coloured lines), its vision cone (green/yellow/red by awareness), a line to you while you're seen, the last-known-position marker, and a label with state and meter. A panel at the top left lists every guard's meter.

### Sound and presentation

- **Player:** footsteps on every stride (soft when crouched, heavier when sprinting), a gentle head bob, a slightly wider view while sprinting, and a tick when the use prompt appears.
- **Guards:** a low-poly jointed model with idle, walk, run (chase) and search (investigating) animations; 3D footsteps, keys jingling, radio chatter on patrol and a radio call when an investigation starts; the "?" / "!" icon pops when a guard's state changes.
- **Library:** room tone, the wall clock ticking, and page turns, a book being put down and a chair creaking now and then. These are decoration: guards don't hear them.
- **Stealth audio:** short stings when a guard notices you, starts investigating, starts a chase or loses you; tension music while you are seen or investigated, chase music during a chase.
- **UI:** detection meter under the status banner, key-cap use prompt, objective progress ("OBJECTIVE 2/5") with a flash on change, pause menu and button sounds, caught screen with vignette and respawn countdown, victory screen with stats.
- Volumes are on four buses (`default_bus_layout.tres`): Music, SFX, Ambience, UI.
- All sounds are generated by `tools/generate_audio.gd` (no external assets). Regenerate them with `godot --headless --path . --script res://tools/generate_audio.gd`; the four loops are set to loop in their `.import` files.
- `tools/capture_presentation.gd` renders the guard poses and HUD screenshots in `docs/presentation/`.

### Adding or changing a guard patrol

1. Add a `PatrolRoute` node (script `scripts/npc/patrol_route.gd`) under `Guards`. Untick **Loop** if the guard should stop at the last point.
2. Add `Marker3D` children with `scripts/npc/patrol_point.gd` attached, in the order to visit them, on walkable floor. Set **Wait Time** per point (-1 uses the guard's default).
3. Instance `scenes/npc/guard.tscn` under `Guards` and set its **Patrol Route** to the new route. Several guards can share one route.

The tests check that every patrol point in the library is on the navigation mesh and reachable.

### Level-design tools

Measure the level and record a version (run on the commit you want to record):

```
godot --path . --script res://tools/level_report.gd -- --out=docs/level/v5 --version=v5
godot --path . --resolution 1280x720 --script res://tools/capture_views.gd -- --out=docs/level/v5/views
godot --headless --path . --script res://tools/level_compare.gd -- --before=docs/level/v4 --after=docs/level/v5
```

What each one produces:

- `level_report.gd` writes `report.md`, `metrics.json` and, when run with a display, `map.png`. It measures:
  - exposure: how much of each guard's patrol loop a spot is inside its view cone;
  - cover;
  - patrol loops;
  - shortest and safest player routes;
  - hiding-spot and respawn-point exposure.
- `--scene=res://other.tscn` measures an experimental copy of the level instead.
- `capture_views.gd` renders the 8 fixed viewpoints and a top-down view, so versions can be compared shot for shot.
- `level_compare.gd` writes a before/after table, `compare.md`.

### Rebaking navigation after changing the level

Navigation is baked from the level's static collision into `scenes/level/library_navmesh.tres`. After moving walls, shelves or furniture, rebake using either of these:

- **Editor:** select `NavigationRegion3D` in the library scene, click **Bake NavigationMesh** in the toolbar, then save (Ctrl+S).
- **Command line:** `godot --headless --path . --script res://tools/bake_navigation.gd`

If you forget to rebake, the tests fail with "The saved navigation mesh is out of date".

## Run the tests

In the editor: open `res://tests/test_scene.tscn` and press **F6**. A successful run prints `All tests passed (Phase 1 setup, Phase 2 player, Phase 3 navigation, Phase 4 guards, Phase 5 vision, Phase 6 AI, Phase 7 hearing, Phase 8 stealth loop, Phase 9 objectives, Phase 10 game flow, Phase 11 level design, Phase 12 presentation).` to the Output panel and exits.

From a terminal (no window), with the Godot 4.7.2 executable on your `PATH`:

```
godot --headless --path . --editor --quit          # first run only: imports the project
godot --headless --path . res://tests/test_scene.tscn
```

The run exits with code `0` when every check passes and `1` otherwise, listing each failure as an error. It takes about two and a half to three minutes because the movement, navigation, guard and vision tests step real physics frames, mostly with time sped up 4–6×.

- `tests/test_scene.gd` — checks that every script compiles, Phase 1 setup checks (engine version, project settings, Windows export preset, folders, graybox) and the test runner.
- `tests/player_tests.gd` — Phase 2 player checks: InputMap bindings, movement maths, mouse-look clamping, and in-level movement (landing, walk and sprint speed, stopping, crate and wall collision, fall respawn).
- `tests/guard_tests.gd` — Phase 4 checks: patrol route logic, the guard scene, every library guard's points are walkable and reachable, every guard completes its loop in order, waits match the configured times, no teleporting or leaving the navmesh, guards never overlap, two guards pass head-on, a blocked guard skips its point, a guard without a route stands still, and a non-looping route stops at its end.
- `tests/ai_state_tests.gd` — Phase 6 state machine unit tests with a fake guard, so no physics: initial state, every allowed transition, priority (a confirmed sighting beats noise), rejected transitions, enter/exit order, repeated requests, a 2000-step random stress test, and no shared state.
- `tests/ai_behavior_tests.gd` — Phase 6 in the library: a guard goes PATROL → INVESTIGATE → CHASE → INVESTIGATE → PATROL against the real player, follows only the last known position once sight is lost, and investigates a noise.
- `tests/hearing_tests.gd` — Phase 7 checks:
  - noise presets and range; walls muffle
  - estimates are never exact, are deterministic, get worse with distance, and differ between guards
  - stale and expired events are ignored; duplicates are processed once; repeated footsteps merge
  - multiple guards; a guard ignores noise from other guards
  - player footsteps: walking gives WALK, sprinting gives RUN, standing still and teleporting give nothing
  - `NoiseMaker` makes interaction noise
  - in the library: walking behind a guard isn't heard, sprinting is (INVESTIGATE near an estimate, never the exact spot), and a chase ignores noise
- `tests/loop_tests.gd` — Phase 8 stealth loop checks:
  - status priority; crouch, including not standing up under a low beam
  - a carrel hides a crouched player from the side but not a standing one, and halves detection from the opening
  - a guard that loses a hidden player investigates and returns to patrol (`SPOTTED → INVESTIGATING → HIDDEN`)
  - crouch-walking is quiet
  - HUD direction indicators and stance text
  - a sprinting player can escape a chase; being caught freezes, then resets the level
- `tests/objective_tests.gd` — Phase 9 checks:
  - objective states and order, and progress snapshots
  - every objective, the card, the door and the checkpoints are reachable in order
  - interaction reach and walls
  - the exit rejects the player without the card; full flow to ESCAPED
  - checkpoints keep progress from before them and undo progress after them
  - all guards reset on respawn; no activation during a chase
  - no guard sees a checkpoint's respawn point during its patrol
- `tests/game_flow_tests.gd` — Phase 10 checks:
  - the game-state machine: allowed transitions only, no duplicates, 3000 random requests
  - main menu Start/Quit; Esc/P pause binding
  - pause and resume by key, button and focus loss, with the cursor right in each state
  - everything frozen while paused: guards, navigation, vision meters, player, noise clock, timers
  - caught → respawn; victory; restart and main menu, with only one scene change at a time
- `tests/level_design_tests.gd` — Phase 11 checks:
  - every required space exists
  - two independent routes to the card and two ways to the exit
  - carrels reachable, including the east-route alcove
  - RESTRICTED, room and EXIT signs; the card spotlight and clock landmark
  - decoration (books, signs, lights, ceilings) has no collision; ceilings on render layer 2
  - books generated the same way every time and kept inside their bookcase
- `tests/presentation_tests.gd` — Phase 12 checks:
  - every sound loads; loops loop and one-shots don't; the four buses exist
  - head bob, movement kind, guard animation choice and the prompt key split
  - the guard model has every animated joint, no collision, and the guard's capsule and speeds are unchanged
  - in the library: one footstep sound per stride; the camera settles when standing still
  - guards walk on patrol and search when investigating, with footsteps and radio
  - the AudioDirector reacts to stealth, objective, pause and door events, without repeating stings
  - UI sounds work while paused; the detection meter follows the most aware guard
- `tests/vision_tests.gd` — Phase 5 checks in a purpose-built arena: FOV and range maths, a player straight ahead is seen and the meter fills in the expected time, the meter holds then drains after losing sight, the last known position never updates while hidden, walls and tall shelves block sight but a low table doesn't, players outside the cone or out of range are not seen, far players fill the meter slowly, thresholds are configurable, and the debug cone stops at walls. In the library: every guard has vision, and no guard sees the spawn during a full patrol loop.
- `tests/navigation_tests.gd` — Phase 3 checks: every room exists, navigation covers open floor and none of the walls or furniture, nothing is baked outside the rooms or on furniture, every floor edge is walled, paths reach every room without crossing walls, a `NavigationAgent3D` probe walks from the entrance to the exit, the debug overlay draws the navmesh, and the saved navmesh matches a fresh bake.

## Documentation

- `docs/phase-1-setup.md`
- `docs/phase-2-first-person-player.md`
- `docs/phase-3-library-navigation.md`
- `docs/phase-4-npc-patrol.md`
- `docs/phase-5-npc-vision.md`
- `docs/phase-6-npc-ai-state-machine.md`
- `docs/phase-7-hearing-and-noise.md`
- `docs/phase-8-stealth-loop.md`
- `docs/phase-9-objectives-and-checkpoints.md`
- `docs/phase-10-game-flow.md`
- `docs/phase-11-final-level.md`
- `docs/level/LEVEL_LOG.md` (level-design versions v0–v4 with evidence)
- `docs/phase-12-presentation.md`
