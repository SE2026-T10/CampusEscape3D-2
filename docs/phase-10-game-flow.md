# Phase 10 — Game Flow

The game now runs from start to finish: main menu → play → pause / caught / respawn → victory → play again or main menu. The game-level states live in their own state machine, separate from the guards' AI.

## Game states

`GameStateMachine` (`scripts/game/game_state_machine.gd`) has exactly four states: **PLAYING**, **CAUGHT**, **PAUSED**, **WIN**.

| From | Allowed to | When |
|---|---|---|
| PLAYING | CAUGHT | a chasing guard reaches the player (`StealthDirector.player_caught`) |
| PLAYING | PAUSED | Esc / P, or the game window loses focus |
| PLAYING | WIN | the last objective is completed at the exit (`ObjectiveManager.level_completed`) |
| CAUGHT | PLAYING | the respawn after the 2.5 s caught screen (`StealthDirector.level_reset`) |
| PAUSED | PLAYING | Esc / P again, or the Resume button |
| WIN | — | final. Play again loads the level fresh, with a new machine. |

- Requesting the current state, or anything not in the table, is refused, changes nothing, emits nothing and is counted in `rejected_count`. So no transition can happen twice.
- Pausing on the caught screen isn't allowed. It lasts 2.5 s and nothing can be done during it.
- These are not AI states. `GuardStateMachine` still has only PATROL / INVESTIGATE / CHASE (the Phase 6 tests check this), and no guard code refers to the game state.

## Delivered

| File | Purpose |
|---|---|
| `scripts/game/game_state_machine.gd` | `GameStateMachine`: the states, the allowed transitions, the history, the refused-request count |
| `scripts/game/game_flow.gd` | `GameFlow` (node in the level, runs while paused). It owns the machine and follows the director and the objectives. It handles pause / resume, the mouse, play time, restart and returning to the main menu. |
| `scripts/ui/game_menus.gd` | `GameMenus`: the pause menu (Resume / Restart level / Main menu, time played, controls) and the win screen (time, catches, Play again / Main menu). The first button has keyboard focus. |
| `scripts/ui/main_menu.gd`, `scenes/ui/main_menu.tscn` | `MainMenu`: title, Start game / Quit, controls. Now the project's **main scene**. |
| `scripts/ui/menu_style.gd` | `MenuStyle`: shared look for the menus |
| `scripts/player/player.gd` | Escape no longer frees the mouse (it pauses), and the player no longer captures the mouse on load; `GameFlow` does both. A click while playing still recaptures it. |
| `scripts/ui/objective_hud.gd` | the Phase 9 ESCAPED screen, its E-to-restart key and its timer were removed. The win screen and timer are now in `GameMenus` / `GameFlow`. |
| `scenes/level/library_graybox.tscn` | the `GameFlow` and `GameMenus` nodes; the controls sign says "Esc pause" |
| `project.godot` | main scene → main menu; the `release_mouse` action is replaced by `pause` (Escape and P) |
| `tests/game_flow_tests.gd` | game-flow tests |
| `tests/player_tests.gd`, `tests/test_scene.gd`, `tests/objective_tests.gd` | updated for the `pause` action, the main menu as main scene, and the win screen moving to `GameMenus` |

### Behaviour per state

| State | Scene tree | Mouse | On screen |
|---|---|---|---|
| PLAYING | running | captured | HUDs |
| CAUGHT | running. Player and guards are frozen by the director, which counts down to the respawn. | captured: no menu, and the cursor would flash for 2.5 s | the red CAUGHT screen, naming the respawn point |
| PAUSED | **paused** (`SceneTree.paused`) | visible | pause menu |
| WIN | running. Player and guards are frozen by the director. | visible | win screen |

**How pausing works:**

- `SceneTree.paused = true` stops every node set to inherit pausing, which is every gameplay node: guards and their AI, `NavigationAgent3D` avoidance, vision, hearing, the noise system's clock, the director's timers, the HUD message timers and the player.
- `GameFlow` and `GameMenus` use `PROCESS_MODE_ALWAYS`, so the menu and the Esc key keep working.
- The tests confirm nothing drifts while paused: positions, velocities and navigation targets stay exactly the same.
- The play-time clock only counts in PLAYING.

**Leaving the level** (Restart, Play again, Main menu):

- The tree is unpaused and the cursor freed first.
- One `change_scene_to_file` is requested. Any further presses are ignored (`is_leaving()`), so a double click can't load twice.
- Restart reloads the level's own scene file.
- The main menu always unpauses and shows the cursor when it opens.

## Automated tests (`tests/game_flow_tests.gd`)

| Requirement | Check |
|---|---|
| Game states, no duplicates | Exactly the four states. All 16 from→to pairs are allowed or refused as in the table, and a refusal changes nothing. Pause/resume duplicates are refused. One signal per accepted transition. Rejected requests are counted and not recorded. CAUGHT can't pause or win. WIN is final. **3000 random requests** over 242 games: 1226 transitions, 1774 refused, 0 duplicate or illegal, and every request is either one reported transition or refused. |
| Project | The main scene is the main menu. `pause` is bound to Escape and P. `release_mouse` is gone. |
| Start game | Main menu: Start and Quit exist, Start has focus, the tree isn't paused. Start loads the library once even if pressed twice. Quit quits. |
| Start state | The level starts PLAYING, unpaused, mouse captured, no menu. GameFlow and GameMenus run while paused. |
| Pause / resume | Escape (a real input event) pauses: tree paused, cursor visible, pause menu shown with Resume focused. Pausing again is refused. Escape again resumes: mouse captured, menu hidden. The Resume button resumes. Focus loss pauses, and a second focus loss doesn't pause again. History `PLAYING → PAUSED → PLAYING → …`. |
| NPC simulation paused | The real level, guards walking: 120 frames paused. Guard positions, velocities, AI states and navigation targets unchanged. Noise clock, play time and HUD message timer stopped. The player doesn't move even with W held. After resuming, guards move again and the clock runs. A guard's detection meter is frozen while paused and fills again after. |
| Caught → respawn | A test guard catches the player: CAUGHT, mouse captured, tree running. Escape is refused. The respawn returns to PLAYING. Exactly two transitions. |
| Victory | Objectives done and the door used: WIN, cursor visible, win screen with Play again focused, catches counted ("caught 1 time"). Escape doesn't pause. The door can't be used again. WIN entered once. The clock is stopped. |
| Restart / menu | From the pause menu, Restart requests the library scene, unpauses and frees the mouse. A second request is ignored. Main menu from a fresh pause requests the main menu. Play again on the win screen requests the level once, even with Main menu pressed straight after. |

## Verification record (2026-10-04)

All runs used the official Linux build of Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`).

| Check | Result |
|---|---|
| Project import | exit 0, no errors |
| Full test run | `All tests passed (Phase 1 setup … Phase 10 game flow).`, exit 0, about 2 min 30 s; no errors or leaks; the same 8 expected warnings as before |
| Main scene (main menu), 900 frames | exit 0, no errors |
| Library scene directly, 900 frames | exit 0, no errors |
| Real scene changes (a capture script under Xvfb, not part of the repo, with no test doubles) | main menu → **Start game** → library, `PLAYING`, mouse captured. Esc (`Input.parse_input_event`) → `PAUSED`, tree paused, cursor visible. **Restart level** → library reloaded, `PLAYING`, unpaused. Objectives done, door used → `WIN`, cursor visible. **Main menu** → main menu, unpaused. |

**Mutation checks.** Each was a copy of the code broken on purpose, run against the game-flow tests. All failed with exit 1:

| Mutation | Caught by |
|---|---|
| Pausing doesn't pause the tree | "Escape should pause the game and the scene tree", "Guards must not move while paused" (+6) |
| Duplicate transitions allowed | "PLAYING → PLAYING should be refused" (+14) |
| Pause allowed during CAUGHT | "CAUGHT → PAUSED should be refused" (+2) |
| Mouse always captured | "The cursor should be visible while paused / on the win screen" |
| Respawn doesn't return to PLAYING | "Respawning should switch the game back to PLAYING" (+6) |
| More than one scene change per exit | "Only one scene change may be requested" (+1) |
| GameFlow pauses along with the game | "GameFlow and the menus must keep running while paused", "Escape again should resume" (+3) |
| Focus loss ignored | "Losing window focus while playing should pause" (+2) |
| Victory doesn't enter WIN | "Escaping should switch the game to WIN" (+4) |

**Screenshots** in `docs/evidence/phase-10/` were rendered under a virtual display (Xvfb, Mesa llvmpipe software OpenGL), not on Windows hardware, by that capture script pressing the real buttons. For the win shot it removed the guards, completed the objectives and used the door directly.

| File | Shows |
|---|---|
| `main_menu.png` | title screen, Start game focused |
| `playing.png` | the level right after Start game |
| `paused.png` | pause menu over the frozen level, Resume focused, time played |
| `win.png` | ESCAPED screen with time and catches, Play again focused |

## Manual verification still required (Windows, Godot 4.7.2 editor, F5)

1. F5 opens the main menu with a visible cursor. Start game loads the library and the cursor disappears.
2. Esc: the pause menu shows with the cursor, and guards and noise rings (F3) stop. Esc again resumes, and so does the Resume button.
3. Alt-Tab out while playing: the game is paused on return.
4. While paused, hover and click the buttons. Use the keyboard (arrows / Tab, Enter) too.
5. Get caught: the caught screen shows, Esc does nothing, then you respawn and play continues.
6. Escape the library: the win screen shows with the cursor. Play again restarts, and Main menu returns to the title.
7. Pause → Main menu → Start game: a fresh level, not paused, cursor captured.

## Known limitations

- No settings menu (mouse sensitivity, volume, resolution) and no save game.
- Quit only exists on the main menu. The pause menu offers Main menu.
- The main menu has no background art; it's a styled panel.
- Focus loss pauses the game, but focus gain doesn't resume it. That's deliberate: the player resumes when ready.
