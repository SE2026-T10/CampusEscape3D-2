# Phase 12 — Presentation Polish

This phase adds sound, animation and UI polish to the finished library level. No gameplay was added or changed. Two things on the gameplay side were touched:

- `PlayerNoise` gained a `footstep(kind)` signal, emitted on the strides it already counted.
- The guard's capsule mesh was replaced by a jointed low-poly model. Its collision, vision, hearing, speeds and AI are unchanged.

Everything else is new presentation components that only *read* game state.

## What was added

| Area | Feature | Where |
|---|---|---|
| Player | footsteps per stride: crouch soft and low, walk, sprint louder and brighter; random variation and pitch | `PlayerFeedback` |
| Player | movement feedback: head bob (walk / sprint / crouch amounts, settles to rest when idle), sprint FOV 75° → 80° | `PlayerFeedback` |
| Player | interaction feedback: key-cap prompt that fades in and out (red when refused), a tick when the prompt appears on a new object | `ObjectiveHud`, `PlayerFeedback` |
| Guards | footsteps in 3D by distance walked; heavier and quicker in a chase | `GuardPresentation` |
| Guards | patrol audio: keys jingle every few steps; radio chatter every 14–30 s on patrol | `GuardPresentation` |
| Guards | investigation feedback: radio call when an investigation starts, "suspicious" sting, search animation at the spot, "?" icon pop | `GuardPresentation`, `AudioDirector` |
| Guards | chase feedback: alarm sting, chase music, run animation, "!" icon pop, pulsing CHASED banner, full detection meter | `AudioDirector`, `GuardPresentation`, `StealthHud` |
| Guards | animation: idle (breathing, glancing), walk, run (lean, arms pumping), search (turning head and shoulders) | `GuardPresentation` + `guard.tscn` Model |
| Library | ambience: room tone (quieter while paused) and the wall clock ticking (positional) | `AudioDirector`, `AmbientEmitter` |
| Library | environmental sounds: page turns, a book put down, a chair creaking, at 4 places | `AmbientEmitter` ×4 |
| UI | objective display: "OBJECTIVE n/5" progress, panel flash when a new objective starts, sounds for objective, card and checkpoint | `ObjectiveHud`, `AudioDirector` |
| UI | detection meter: the most aware guard's meter, marks at suspicious (30) and alerted (100), fades out when nobody notices you | `StealthHud` |
| UI | pause menu: fade in, pause / resume sounds, button hover and click sounds (also on the main menu) | `GameMenus`, `MenuStyle` |
| UI | caught screen: fade in, red vignette, countdown bar to the respawn, caught sound | `StealthHud`, `AudioDirector` |
| UI | victory screen: fade in, title pop, objectives line, victory jingle; music stops | `GameMenus`, `AudioDirector` |
| Audio | 4 buses: Music −3 dB, SFX 0, Ambience −2, UI −2 | `default_bus_layout.tres` |

**Guard animation choice:**

| State | Standing (speed < 0.3 m/s) | Moving |
|---|---|---|
| Patrol | idle | walk |
| Investigate | search | walk |
| Chase | search | run |

- The walk speed scales with the guard's real speed (patrol 2.0 → ×1.0, investigation 2.6 → ×1.3).
- Animations blend over 0.25 s.

**Stealth audio:**

| Status change | Sting | Music |
|---|---|---|
| → INVESTIGATING (from calmer) | suspicious | tension |
| → SPOTTED (from calmer) | notice | tension |
| → CHASE | alarm | chase |
| → NONE / HIDDEN from a dangerous status | lost track | off |
| → CAUGHT | caught | off |

- The same sting won't repeat within 1.5 s, so a flickering status isn't noisy.
- Music layers crossfade over 1.2 s.

## Architecture

```
Level
├── AudioDirector (Node, group "audio_director", PROCESS_MODE_ALWAYS)
│     listens to StealthDirector.status_changed, ObjectiveManager.objective_completed,
│     CheckpointManager.checkpoint_activated, ExitDoor.rejected/escaped, GameFlow.state_changed
│     owns: 6 SFX players, UI player, room tone, tension + chase music
├── Ambience (Node3D)
│     ClockTick, ReadingPages, StacksBooks, ArchivePages, EntranceChair (AmbientEmitter)
├── Player
│     └── Feedback (PlayerFeedback) → creates Player/Footsteps (AudioStreamPlayer3D)
└── Guards/Guard*
      ├── Model (Hips → Pelvis, LegL/LegR, Torso → Chest, Belt, Badge, ArmL/ArmR, Head → Face, Eyes, Hair, Cap, Brim)
      └── Presentation (GuardPresentation) → AnimationPlayer, Footsteps, Gear (3D players)
SoundBank (static): name → stream, with random variations (player_step_1..4, guard_step_1..4)
```

- **Read-only:** presentation nodes never write to movement, AI, perception or objectives. They poll state (`guard.machine.current`, `velocity`, `vision.detection`) or listen to existing signals.
- **Guard state:** `machine` is polled every frame because the guard recreates it on reset.
- **Pausing:**
  - UI sounds, room tone and the menus keep running while paused.
  - SFX, music, guard sounds and ambient one-shots pause with the game.
- **Ambient one-shots are not `NoiseSystem` events,** so guards don't react to them.

## New and changed files

**New:**

- `scripts/presentation/`:
  - `sound_bank.gd`
  - `audio_director.gd`
  - `player_feedback.gd`
  - `guard_presentation.gd`
  - `ambient_emitter.gd`
- `assets/audio/` — 32 WAV files and their `.import` files (generated)
- `default_bus_layout.tres`
- `tools/generate_audio.gd` — synthesises every sound (seeded, reproducible)
- `tools/capture_presentation.gd` — guard pose sheet and HUD screenshots
- `tests/presentation_tests.gd`
- `docs/phase-12-presentation.md`, `docs/presentation/*.png`

**Changed:**

- `scripts/player/player_noise.gd` — `footstep` signal
- `scenes/npc/guard.tscn` — the jointed model replaces the capsule Body and Cap; Presentation node added
- `scenes/player/player.tscn` — Feedback node
- `scenes/level/library_graybox.tscn` — AudioDirector and Ambience nodes
- `scripts/ui/stealth_hud.gd` — detection meter, caught vignette and countdown, chase banner pulse
- `scripts/ui/objective_hud.gd` — key-cap prompt with fade, progress header, flash on change
- `scripts/ui/game_menus.gd` — fades, win title pop, objectives line
- `scripts/ui/menu_style.gd` — button sounds
- `tests/test_scene.gd`, `README.md`

## Sounds

All sounds are synthesised by `tools/generate_audio.gd`. Format: 22 050 Hz, 16-bit mono, 1.45 MB in total. The figures below were measured from the files.

| Sound | Length | Peak | | Sound | Length | Peak |
|---|---|---|---|---|---|---|
| player_step_1–4 | 0.15 s | 0.59–0.83 | | notice | 0.25 s | 0.29 |
| guard_step_1–4 | 0.20 s | 0.83–0.90 | | suspicious | 0.45 s | 0.38 |
| guard_keys | 0.19 s | 0.18 | | alarm | 0.70 s | 0.27 |
| guard_radio | 0.55 s | 0.25 | | lost_track | 0.58 s | 0.29 |
| card_pickup | 0.55 s | 0.69 | | caught | 1.10 s | 0.90 |
| objective_complete | 0.72 s | 0.69 | | victory | 1.92 s | 0.85 |
| checkpoint | 0.90 s | 0.65 | | ui_hover / ui_click | 0.03 / 0.08 s | 0.22 / 0.32 |
| door_locked | 0.38 s | 0.51 | | ui_pause / ui_resume | 0.25 s | 0.33 |
| door_open | 0.95 s | 0.58 | | amb_page_turn / book_thud / chair_creak | 0.45 / 0.44 / 0.50 s | 0.47 / 0.69 / 0.11 |
| amb_room_tone (loop) | 7.50 s | 0.37 | | music_tension (loop) | 7.50 s | 0.68 |
| amb_clock_tick (loop) | 2.00 s | 0.47 | | music_chase (loop) | 4.00 s | 0.52 |

## Evidence

Rendered by `tools/capture_presentation.gd`. Rendering used Xvfb with Mesa llvmpipe software OpenGL at 1280×720, not Windows hardware.

The UI shots come from real gameplay in the library:

- The player was teleported to each spot.
- The guard really detected and chased the player.
- A real noise started the investigation.
- The victory came from really using the exit door after the earlier objectives were completed in code.

| File | Shows |
|---|---|
| `presentation/guard_poses.png` | the guard model in idle, walk (2 moments), run (2), search (2) |
| `presentation/ui_01_prompt.png` | key-cap prompt (red: the card can't be taken yet), objective 1/5 |
| `presentation/ui_02_detection.png` | detection meter past the suspicious mark, "YOU ARE BEING SEEN", walk animation |
| `presentation/ui_03_chase.png` | chase: full red meter, CHASED banner, "!" icon, run animation |
| `presentation/ui_04_caught.png` | caught screen: vignette, respawn name, countdown bar |
| `presentation/ui_05_paused.png` | pause menu |
| `presentation/ui_06_investigating.png` | a guard investigating a noise ("?" icon, banner) |
| `presentation/ui_07_victory.png` | victory screen with time, catches and objectives |

No audio was heard: the container has no sound device, so Godot used its dummy audio driver. The tests check that the right sounds are *requested* at the right moments, and that the files load, have the measured lengths and peaks, and loop where they should. How they sound has to be judged by ear (see below).

## Verification record (2026-10-05)

Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`), Linux, headless unless noted.

| Check | Result |
|---|---|
| Project import | exit 0, no errors |
| `--check-only` on every new or changed script | no errors or warnings |
| Full test run | `All tests passed (… Phase 11 level design, Phase 12 presentation).`, exit 0, about 2 min 43 s; the same 8 expected warnings as Phase 11; no leaks |
| Presentation suite output | player: 4 footsteps over 4 strides, largest head bob 0.019 m. Guard while investigating: animations walk → search; 17 footsteps, 1 radio, 4 key jingles. |
| Library scene, 900 frames (`--quit-after`) | no script errors; see the shutdown note under Known limitations |
| Capture tool under Xvfb | 8 images, no script errors |

### Mutation checks (presentation suite)

Each mutation was applied on its own, the presentation suite was run, and the file was restored.

| Mutation | Caught by |
|---|---|
| player footsteps never connected | "Every stride should play one footstep (0 sounds, 4 noises)" |
| head bob never settles | "Standing still should settle the camera (0.0061 m)" |
| guards never search | "An investigating guard should search at the spot (saw walk, idle)" + the pure rule |
| guard footsteps removed | "A walking guard should make footstep sounds" |
| sting cooldown removed | "A flickering chase must not repeat the alarm within 1.5 s" |
| UI sounds pause with the game | "Hovering a pause-menu button should tick, even while paused" (test strengthened after this mutation first survived) |
| chase music no longer loops (`.import`) | "music_chase.wav should loop" |
| detection meter ignores chases | "The meter should be full during a chase" (test added after this mutation first survived) |
| a collider inside the guard model | "The guard model must not collide" |

## Manual verification still required (Windows, Godot 4.7.2, F5)

1. **Listen to everything with real audio:**
   - volumes between buses;
   - footsteps not tiring over a whole run;
   - stings readable but not startling;
   - music loops without clicks;
   - the room tone not hissy.
   The sounds are simple synthesis; replace any that don't hold up.
2. **3D sound:** guard footsteps should be audible early enough to be useful, but not through the whole library. The settings are unit_size 5 and max distance 30 m, with no occlusion by walls.
3. **Head bob comfort:** ±2–4 cm. Players sensitive to motion may want it off; `head_bob_enabled` exists, but there is no options menu yet.
4. **Guard animations in motion:** foot sliding at patrol, investigation and chase speeds; turning while walking; the blend into search.
5. **UI on a real monitor and at other resolutions:** meter and prompt placement, and caught / victory fades.
6. **Performance:** with the audio players added, frame time in the main room. This belongs to the profiling phase.

## Known limitations

- **Quitting while sounds play:** if the engine quits while sounds are still playing, a headless `--quit-after` run reports the playing streams as leaked ("ObjectDB instances leaked", "resources still in use"). This is how Godot tears down its audio server. Freeing the level and letting a few frames pass first gives a clean exit; the test suite does exactly that and is leak-free. Closing the game window in the middle of play may print the same message in the editor output.
- **Ambient sounds and guards:** ambient sounds are not occluded by walls, and guards don't hear them (by design).
- **Head bob and interaction:** the bob moves the camera up to about 2 cm. The interaction ray starts at the camera, so its origin moves by the same amount. Guard vision aims at fixed body points and is unaffected.
- **Guard model:** box primitives with rigid joints (no skinning). Animations are built in code, not in `.tres` files, so they are edited in `guard_presentation.gd`.
- **Main menu sounds:** the main menu has button sounds but no music.
