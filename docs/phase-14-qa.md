# Phase 14 — Final QA Pass

This was the final QA pass over every major system, done with automated tests, end-to-end playthroughs and exploratory runs. Only confirmed bugs were fixed, each with a regression test that failed before the fix. No gameplay features were added.

The pass found **two confirmed bugs, both fixed**:
- **QA-1:** a cosmetic UI bug — the win screen's title animation never played.
- **QA-2:** a benchmark tool bug that skewed the Phase 13 stress figures. The stress runs were re-measured and the Phase 13 page corrected.

No gameplay, AI, navigation or game-flow bugs were found. One AI behaviour that only appears in setups the shipped level doesn't use is recorded as an observation (O-1).

The regression checklist for future releases is **[`docs/qa/REGRESSION_CHECKLIST.md`](qa/REGRESSION_CHECKLIST.md)**.

## Environment

| Item | Value |
|---|---|
| Machine | Linux cloud VM: Intel Xeon @ 2.10 GHz, 2 vCPUs, 8 GB RAM, **no GPU**, no sound device |
| Godot | 4.7.2.stable.official.ed1daf0bf, editor binary (debug build) |
| Rendering | Xvfb + Mesa llvmpipe (software OpenGL), Compatibility renderer |
| Audio | Godot's dummy driver. Sounds are checked by what is played and when, **not heard**. The "ERROR: Condition status < 0" line at startup is the missing sound device. |
| Windows | **not available.** Everything marked "manual" in the checklist still needs a run on the target PC. |

## What was run

1. **The full automated suite** (`tests/test_scene.tscn`), before and after the QA work.
2. **New playthrough tests** (`tests/qa_playthrough_tests.gd`, part of the suite):
   - **Full route, real input:** the player walks the whole route with W held, turning toward the next path corner, in walking, sprinting and crouching segments, with the guards removed. The route goes spawn → main room → Hallway West checkpoint → Restricted Stacks → card (E key) → Staff Nook checkpoint → exit door (E key) → win screen. It checks every objective trigger, both checkpoints, interaction, victory, 5/5 on the win screen, and the sounds of the run.
   - **Real chase and catch:** with the level's guards, a guard spots the player and gives chase, then catches them. It checks the run animation, the notice / alarm / caught sounds and the chase music, the caught screen, the respawn at the touched checkpoint, every guard back on patrol, and the music stopping.
3. **Real game flow with real scene changes** (`tools/qa_flow.gd`, 15 checks). The automated tests stub scene changes, because a real change would end the test runner, so this tool does the scene changes for real:
   - main menu → Start → Esc → Resume → Esc → Restart (reload);
   - caught → respawn → Esc → Main menu → Start again;
   - win → Esc refused on the win screen → Play again (reload) → Main menu → Quit.

   It was run headless and with a window at 1280×720, 1920×1080 and 1024×576, with screenshots.
4. **Performance:**
   - the benchmark's normal and stress scenarios with rendering;
   - a 180 s headless stress soak;
   - normal and several runs (several 3×180 s, normal 9 × 180–300 s) to look for stuck guards.

   The benchmark now also records every time a guard gives up on a point because it is stuck.
5. **Lighting / visual regression:** the 9 fixed viewpoints compared pixel by pixel with Phase 13's: identical (difference 0.00).
6. **Debug view:** F3 overlay toggled during play, with a noise → no errors.
7. **Static checks:**
   - every input action the code uses is in the Input Map;
   - every sound name the code and level use exists in SoundBank (all 32 are referenced);
   - no `jump` action exists (jumping is out of scope).

## Results by area

| Area | Items | Result | Evidence |
|---|---|---|---|
| Player | movement, camera, collision, sprint, crouch, jump (off) | pass | `player_tests`; full route walked with real input in 33.4 s of play, no snags |
| Navigation | navmesh, NPC pathfinding, obstacles | pass | `navigation_tests` (bake = saved, sealed, probe walks entrance → exit); `guard_tests` |
| AI | patrol, investigate, chase, vision, hearing, detection, transitions | pass | `guard`, `vision`, `ai_state`, `ai_behavior`, `hearing`, `loop` tests; real chase in `qa_playthrough` (animations idle → walk → run, music → tension → chase) |
| Gameplay | objectives, interaction, card, checkpoints, respawn, escape, victory | pass | `objective_tests`; full route: checkpoints Hallway West and Staff Nook, 115 footsteps, sounds objective / checkpoint / card / door / victory |
| Game flow | pause, resume, caught, restart, win | pass | `game_flow_tests`; `qa_flow` 15/15 at 3 resolutions and headless (`docs/qa/flow_*`) |
| Presentation | UI, audio, animation, lighting | pass after fixing QA-1 | `presentation_tests`, `qa_regression_tests`, `qa_flow` screenshots, view comparison |
| Performance | normal, stress | pass: no errors, no catches, no memory growth | `docs/qa/perf/` — normal 11.99 FPS (1% low 8.12), stress 10.43 FPS (1% low 7.06) on llvmpipe at 1280×720; stress soak 2.2 ms CPU per frame for 24 guards |

**Full suite (final):** `All tests passed (Phase 1 setup … Phase 13 performance, Phase 14 QA).`, exit 0, 211 s, with the same 8 expected warnings (output in `docs/qa/full_test_run.txt`).

## Bugs found and fixed

### QA-1 — The win screen title never popped in (cosmetic, from Phase 12)

**Found by:** watching the win screen frame by frame. The title's scale stayed at 1.0 the whole time.

**Two causes:**
- The label sat directly in a VBoxContainer, and containers reset their children's scale.
- Its pivot was computed from the size it had before the panel was laid out: 120.5 px instead of 201.5 px.

**Fix** (`scripts/ui/game_menus.gd`):
- The title now sits in a plain Control holder that is sized to the title.
- The pop waits one frame, so the pivot is the real centre.
- The title is exposed as `win_title`.

The first attempt left the holder too short, so the title overlapped the line below. The screenshot showed it, and the test now checks the height too.

**Test:** `qa_regression_tests` QA-1 checks three things: the title is popping 0.12 s after the win, it scales around its centre, and it settles at 1.0 with a tall enough holder. It failed before the fix (scale 1.00, pivot off-centre).

### QA-2 — The benchmark started guards on top of each other (tool, from Phase 13)

**Found by:** the stress soak printed hundreds of "is stuck … moving on" warnings, always from the same six guards.

**Cause:** with 13 or more guards, the benchmark's start-placement arithmetic put some extra guards exactly where the level's own guards start. Each such pair blocked each other.

The Phase 13 stress and 16–48-guard scaling runs were affected; the normal and several runs were not.

**Fix** (`tools/benchmark.gd`):
- Every extra guard now gets its own start slot, at quarter steps along its route and never on point 0.
- The benchmark also records stuck events in `summary.json`.

**Impact:** stuck events in a 180 s stress soak went from about 230, nearly all from those six guards, to 20, spread across 13 guards (normal crowding with 8 guards per route).

**Re-measurement:**
- Stress was re-measured before and after the Phase 13 optimisation. "Before" was run on the pre-optimisation commit in a separate worktree, with the fixed tool.
- The CPU scaling runs for 16–48 guards were re-measured too.
- `docs/phase-13-performance.md` now has a correction section and the corrected figures:
  - stress: 7.85 → 10.57 FPS, +35% (was reported as 7.72 → 10.54);
  - 48 guards: 3.8 ms CPU per frame (was 3.1 ms, because the stuck guards weren't moving).
- The Phase 13 conclusions are unchanged.

**Test:** `qa_regression_tests` QA-2 checks that no two guards (and no level guard) share a start slot for 8, 24 and 48 guards, and that the tool uses that scheme.

### Test-harness issues found while writing the QA tests (not game bugs)

- The walking bot first judged "stuck" by straight-line distance to the goal. It reported a false stuck where the real path first goes away from the goal (stacks → card). The movement was traced frame by frame, the player walks freely there, and the bot now uses distance moved.
- The flow tool checked the caught overlay in the same frame the catch happened, before the HUD's next update. It now waits 0.1 s.

## Observation, not fixed

**O-1 — Guards sharing one patrol route can block each other for about 5 s.**

**What happens:**
- **Where:** in the "several" benchmark scenario (two guards on the main room route), GuardMain stopped at (−5.7, −2.1) on the way to point 0 in each of 3 runs, at the same moment (about 68 s), and then moved on.
- **Why:** two guards met head-on in a narrow spot.
- **The game's response:** after 5 s the guard skips to its next point, which is the designed fallback, so the game carries on.

**Why it wasn't fixed:**
- The shipped level has one guard per route.
- No stuck events in 9 runs (2,280 s) of the normal scenario.
- `guard_tests` shows two guards crossing head-on do pass each other in the tested corridor.

If more guards are added to the level, check this spot or give each guard its own route.

## Evidence (`docs/qa/`)

| Path | Content |
|---|---|
| `REGRESSION_CHECKLIST.md` | automated and manual regression checklist, with the last run |
| `full_test_run.txt` | the final suite output (results, measurement lines, warnings) |
| `mutation_checks.txt` | 7 deliberate breakages, each caught by the new tests |
| `flow_1280x720/`, `flow_1920x1080/`, `flow_1024x576/` | `qa_flow` screenshots: main menu, playing, paused, caught, win; `flow_1280x720/log.txt` is the run's output |
| `perf/normal`, `perf/stress`, `perf/stress_soak_180s` | benchmark runs from this pass (frames.csv, summary.json with stuck events, screenshots) |

## Manual verification still required (Windows, Godot 4.7.2, F5)

Work through Part 2 of `docs/qa/REGRESSION_CHECKLIST.md`. The items this environment can't cover are:

1. **Audio by ear:**
   - balance between music, stings, footsteps and ambience;
   - loops without clicks;
   - 3D distance of guard footsteps.
2. **Mouse and keyboard feel:**
   - mouse sensitivity, capture and release, and Alt-Tab pausing;
   - keyboard-only menu navigation.
3. **Real GPU:**
   - frame rate (run the benchmark);
   - shadow quality with the Phase 13 settings;
   - readability at your resolution.
4. **Exported release build:** debug overlays removed, no errors in the console. An export needs the export templates, which aren't in the QA environment.

## Known limitations

- **No Windows or real-GPU testing, and no listening.** Every result above comes from the Linux VM described under Environment.
- **The playthrough is scripted, not a human:**
  - the bot steers along navigation paths and teleports for the chase set-up;
  - it doesn't try to stealth past guards;
  - real stealth difficulty and fairness still need human play.
- **O-1** (guards sharing a route) is recorded, not fixed.
