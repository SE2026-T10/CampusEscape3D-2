# Expanded Library expansion — Phase 7: HUD and accessibility improvements

**Date:** 2026-10-16 · **Branch:** `Development` (at `7d73492`; Phases 1–7 uncommitted in the working tree) · **Engine:** Godot 4.7.2 stable · **Layout:** x6

**Owner decisions (asked before building):**
- **Settings in a config file:** a static `GameSettings` helper saving `user://settings.cfg`; a Settings screen in the main menu and the pause menu; interface size 90 / 100 / 110 / 125 %, master volume 0–100 %, sound captions on/off; both maps.
- **Captions on both maps:** built into the shared StealthHud, so the tutorial gets them with no tutorial scene edit.
- **Routes learned and kept in the journal:** a route or requirement appears only once the player has met it; what was learned is a journal clue, so it survives a capture; exit messages name only known requirements; the hidden passage stays off the list until its plan is read.

## 1. Summary

Every element reads the authoritative game state each frame or on its signal; none keeps its own copy.

| Element | Where | Reads |
|---|---|---|
| Stamina bar + exhaustion | bottom left (StealthHud, Phase 3 bar) | `PlayerStamina`: the bar turns orange and reads **EXHAUSTED · let go of Shift** with a pulsing outline while `is_exhausted()`; a "You're out of breath" caption when it runs dry |
| Three item slots | bottom centre (ObjectiveHud, Phase 3) | `PlayerInventory`; a long name now gets a smaller font instead of being cut ("Security master badge") |
| Journal (J) | left | `PlayerInventory.documents`: **documents and clues only** (the Phase 4 journal also repeated the mission). The document first, then the clues newest first. Clues that do not fit above the captions go on the next J page ("… 5 more clues: press J") |
| Objective tracker | top right (Phase 4) | `ObjectiveManager`: mandatory and optional objectives, unchanged |
| Interaction prompts | centre (Phase 1–6) | the focused interactable, unchanged |
| **WAYS OUT / POWER / Checkpoint** (new) | top left; hidden while the journal is open | the new `EscapeRoutes` node (below), the `PowerNetwork` and the `CheckpointManager` |
| Power and checkpoint feedback | the panel above, plus the existing "Checkpoint reached" and switch messages | as above |
| Completion screen | GameMenus win panel (Phase 6) | time and catches (GameFlow), objectives with **"Optional: <titles>"** (new) and "Escape route: <route>" |
| **Sound captions** (new) | bottom left, above the stamina bar; both maps | `NoiseSystem` events that carry a caption, the audio director's stingers, guard footsteps and radios, exhaustion |
| **Settings** (new) | main menu and pause menu | `GameSettings` (`user://settings.cfg`) |

**What the player knows (EscapeRoutes).** It stores nothing; it combines two sources:
- *Met or not* comes from the game every time: the manuscript objective, the carried badge, each exit's `unlocked`, the PowerNetwork, the hidden panel, the drained culvert.
- *Known or not* is the journal: the culvert access plan, plus short clues it adds when the player meets something.

| Event | Learned (journal clue) |
|---|---|
| Entering the library (enter_library done) | Main entrance (lockdown, override with the master badge) · Loading dock (needs power) |
| Opening the Office 1 locker | Master badge kept in the locker |
| Using the dock shutter control | Dock shutter control; plus "no power" → Dock power; "jammed" → Shutter release |
| Using the release, or walking into the closed dock | Shutter release / Dock shutter control |
| Using any electrical-room switch or the breaker panel | Electrical room (the POWER line appears); the SERVICE EXIT switch → Dock power |
| Reading the culvert access plan (Phase 6 document) | the Hidden maintenance passage appears |

**Exit messages** (`EscapeRoutes.refusal_for`, used by the walk-through exits):
1. without the manuscript: "You can't leave without the rare manuscript.";
2. else the first known requirement still missing, e.g. "Loading dock: free the release (tool kit) needed.";
3. else a hint that names nothing: "The loading dock won't open yet. Look around it for a way."

Puzzle answers never appear: no code, breaker setting or valve setting is on the HUD (tested).

**Captions.**
- Each caption has a direction arrow from the player's view (↑ ↓ ← →), plus "above" or "below" for another floor.
- Repeats of the same sound merge into one line; at most 4 lines; each lasts 3.5 s.
- Only sounds within earshot are shown, and never the player's own footsteps.

| Sound | Caption |
|---|---|
| Alarm | ALARM ringing |
| Thrown bottle / hardback | Glass smashes / Heavy thud |
| Keypad wrong code | Keypad buzzes |
| Breaker or switch | Breaker clunk |
| Pump stall | Pump stalls with a bang |
| Badge reader / bolts | Badge reader beeps / Door bolts bang open |
| Dock shutter | Shutter rattles up |
| Stingers | A guard notices you · A guard heard something · Guard shouts: you've been spotted! · The guards lose your trail |
| A guard nearby (9 m) | Footsteps / Running footsteps |
| A guard's radio (14 m) | Guard radio crackles |
| Running dry | You're out of breath |

**Settings.**
- Interface size uses the root window's `content_scale_factor` (stretch mode canvas_items, base 1280×720), so every 2D element scales together.
- Master volume sets the Master bus (0 % mutes it). Captions toggle the caption panel.
- Changes apply at once and are saved. Broken or missing values fall back to the defaults (100 %, 100 %, captions on).
- Esc closes the Settings screen; in the pause menu it stays paused.

## 2. Exact files changed

**New:**
- `scripts/game/game_settings.gd`: GameSettings, static load / save / apply.
- `scripts/ui/settings_panel.gd`: SettingsPanel, the shared Settings screen.
- `scripts/ui/sound_captions.gd`: SoundCaptions, the caption panel.
- `scripts/systems/escape/escape_routes.gd`: EscapeRoutes.
- `tests/expanded_hud_tests.gd`: the Phase 7 suite.
- `tools/expanded/expansion/capture_hud.gd`: screenshot tool (xvfb), not in CI.
- The `.uid` files of the above.

**Modified (game):**
- `scripts/ui/objective_hud.gd`:
  - journal of documents and clues only, with clue paging and fitting;
  - the WAYS OUT / POWER / Checkpoint status panel;
  - slot font fitting;
  - `get_status_lines()`, `get_layout_controls()` and `next_journal_page()` for tests.
- `scripts/ui/stealth_hud.gd`: the captions child; the EXHAUSTED state; stamina bar 200 px wide (was 220).
- `scripts/ui/main_menu.gd`, `scripts/ui/game_menus.gd`: Settings buttons and screens; the win screen lists the optional objectives completed.
- `scripts/game/game_flow.gd`: applies the settings at start; Esc does not toggle the pause while the Settings screen is open.
- `scripts/player/player_stamina.gd`: `is_exhausted()`.
- Caption text on existing noises:
  - the noise data path: `scripts/systems/noise/noise_event.gd`, `noise_system.gd` (optional `caption` argument, defaults keep old calls unchanged), `noise_maker.gd`;
  - the noise sources: `scripts/systems/puzzles/code_lock.gd`, `pump_control.gd`; `scripts/systems/escape/badge_reader.gd`, `dock_shutter.gd`; `scripts/systems/security/circuit_switch.gd`; `scripts/systems/inventory/thrown_item.gd`, `item_catalog.gd`;
  - stingers, footsteps and radios: `scripts/presentation/audio_director.gd`, `guard_presentation.gd`.
- `scripts/systems/objectives/exit_door.gd`: walk-through exits ask EscapeRoutes for their refusal message when one exists (the tutorial has none, so it is unchanged).

**Modified (scene):** `scenes/level/expanded_library_expansion.tscn`, rebuilt with `build_expansion.gd` + `keep_ids.py`. The diff is the EscapeRoutes node, its script resource and the layout version x6. The main scene `expanded_library.tscn` and the tutorial scene are not changed.

**Modified (tools):** `tools/expanded/expansion/build_expansion.gd` (adds EscapeRoutes), `expansion_layout.gd` (version x6).

**Modified (tests), fallout from the agreed changes:**
- `tests/test_scene.gd`: registers the HUD suite.
- `tests/map_selection_tests.gd`: keyboard order now tutorial → expanded → **Settings** → Quit.
- `tests/expanded_mechanics_tests.gd`: the "one journal entry" checks count documents only (entering now adds two route clues).
- `tests/expanded_puzzle_tests.gd`:
  - the journal check expects no MISSION section;
  - the drain's refusal before its plan is now the hint (it used to say the culvert is flooded).

**Docs:** this report; `phase-7/` evidence; `README.md`; `docs/expanded/LEVEL_LOG.md`, `LAYOUT.md`; `docs/qa/REGRESSION_CHECKLIST.md`.

## 3. Existing systems reused

- **HUD:** the Phase 1–6 ObjectiveHud and StealthHud, extended in place. No second HUD; MenuStyle for the Settings screen.
- **Stamina and items:** the Phase 3 stamina, inventory and journal (`PlayerInventory.documents`, kind "clue").
- **Objectives:** the ObjectiveManager graph (Phase 4) for the checklist, the manuscript and the drained culvert.
- **Security:** PowerNetwork and the circuit switches (Phase 5).
- **Escape routes:** the Phase 6 exits, badge reader, dock shutter and release, the hidden panel and the locker.
- **Checkpoints:** the CheckpointManager.
- **Sound:** the NoiseSystem (captions ride on its existing events); the AudioDirector's stingers and the guard presentation's footsteps and radio.

No new player, guard, inventory, checkpoint or menu system.

## 4. Acceptance criteria

| Criterion | Result | Evidence |
|---|---|---|
| All UI elements accurately reflect game state | **PASS** | HUD suite B–D, H: stamina, slots, checklist, journal, ways out, power, checkpoint, completion read from the game |
| Journal and objective updates stay correct after capture | **PASS** | HUD suite E: journal and clues kept; ways out and power recomputed from the restored state; objectives as stored. Phase 6 escape suite: journal kept over 5 captures |
| Exit prompts reveal only known requirements | **PASS** | HUD suite D (manuscript first, then known requirements, unknown ones as a nameless hint, the drain silent before its plan, no codes); mutations M2–M4 |
| Important sound cues have accessible feedback | **PASS** | HUD suite F: real switch, bottle, alarm, stingers, guard footsteps, direction, floor, earshot, off |
| Settings work and persist per the existing architecture | **PASS** | HUD suite A: defaults, broken values, saved and loaded back, applied to the scale and the Master bus, menu and pause screens; mutation M6 |
| UI readable at supported resolutions | **PASS (automated + screenshots)** | HUD suite G: 1280×720, 1920×1080, 1024×768, 2560×1440 × 90/100/110/125 %, on screen, no overlaps, every journal entry reachable; 17 layout screenshots. Not judged by a human |
| The original tutorial UI still works | **PASS (behaviour)**, with the known flaky timing check | HUD suite I; tutorial suites, QA flow, map flow (§5, §8) |

## 5. Tests actually run (Linux VM, Godot 4.7.2 official)

| Run | Result |
|---|---|
| `tools/ci/validate.sh` | `CHECK SCRIPTS PASSED (131 scripts)` · `VALIDATION PASSED` ([`logs/validate.log`](phase-7/logs/validate.log)) |
| `tools/ci/run_tests.sh`, run 1 | 8 failures ([`logs/tests_run1_failures.log`](phase-7/logs/tests_run1_failures.log)): the 3 known guard-timing checks, and 5 Phase 7 fallout checks in older suites. These were the menu order with Settings (2), the journal counts with route clues (2) and the drain's hint text (1); the test expectations were updated (§2) |
| `tools/ci/run_tests.sh`, final | **Suite FAILED with 3 checks, all the known tutorial `guard_tests` first-wait timing** ("GuardMain waited 3.20s at point 1, expected 3.00s", and 2.20 vs 2.00 s for GuardRestricted and GuardEast). Every other check passed, including every Expanded Library suite and the new HUD suite; exactly the 8 expected warnings; 0 script errors ([`logs/tests_final.log`](phase-7/logs/tests_final.log)) |
| `tools/qa_flow.gd`, `tools/map_flow.gd`, run directly (run_tests.sh stops after the suite) | `QA FLOW PASSED (15 checks, 4 levels loaded)`; `MAP FLOW PASSED (52 checks, 12 levels loaded, 3 cycles)`, 0 ERROR/WARNING lines |
| `tools/ci/export_windows.sh` | `EXPORT PASSED: dist/CampusEscape3D-1.1.0-windows-x64.zip` (not run on Windows) |
| `guard_tests` alone, 8 fresh runs each ([`guard_timing_flake.txt`](phase-7/guard_timing_flake.txt)) | Phase 7 as delivered: **2 of 8 failed** (the same first-wait check). With the proposed one-line test fix applied temporarily (then restored): **0 of 8** |

**HUD suite results** (from `tests_final.log`):
- **A Settings:** defaults without a file; 125 % / 40 % / captions off saved and loaded back; 0 % mutes; broken values → defaults; the menu's screen changes and saves them; Back returns focus.
- **B Reads the game:** stamina bar; EXHAUSTED plus the caption while Shift is held after running dry; slots = inventory; checklist = objectives; journal = clues and documents only.
- **C Ways out:**
  - none before entering; the main entrance and the dock on entering;
  - the badge's place after the locker, [x] when carried;
  - dock power, control and release only once met;
  - POWER after the switch; the passage after its plan; the checkpoint name.
- **D Exit messages:**
  - the manuscript first, then only known requirements;
  - unknown ones as a hint without names; the badge without its place;
  - the drain silent before its plan; no codes on the HUD.
- **E After a capture:** journal and clues kept; ways out and power recomputed from the restored state; objectives as stored.
- **F Captions:**
  - directions: alarm ↓, distraction ←, switch ↑, another floor "above";
  - real sources: a switch, a bottle, guard footsteps and being noticed;
  - nothing out of earshot, nothing for your own steps, nothing when off.
- **G Layout:** 16 resolution × interface size combinations, on screen, no overlaps, the journal and status panel taking turns, every journal entry reachable with J (2 pages at 1024×768 125 %).
- **H Completion:** "Mission objectives 8/8 complete · optional 1/3 | Optional: Open the security locker | Escape route: Loading dock". The test's time reads 0:00 because the test teleports.
- **I Tutorial:** no stamina, slots or ways-out panel; the checklist as before; captions shown; Settings in the pause menu; Esc closes it and stays paused.

**HUD suite:** 0 failures in 7 of 7 runs after its last change (5 runs alone, plus both full-suite runs).
- One intermittent failure was found and fixed on the way. The layout check waited for physics frames, and several can pass within one rendered frame, so the HUD had sometimes not updated yet (1 of 3 runs).
- It now waits for rendered frames. This was a test-timing problem, not a HUD bug.

**Deliberate breaks (9), each running the HUD suite** — all caught ([`phase-7/mutation_checks.txt`](phase-7/mutation_checks.txt)):

| # | Break | Failures |
|---|---|---|
| M0 | the journal shows the mission again | 2 |
| M1 | the hidden passage listed without its plan | 3 |
| M2 | the release requirement shown before it is known | 5 |
| M3 | a refusal names an unknown requirement | 1 |
| M4 | captions ignore the setting | 1 |
| M5 | settings not saved | 2 |
| M6 | the status panel stays up under the journal | 1 |
| M7 | clues that do not fit are unreachable | 1 |
| M8 | exhaustion not shown | 1 |

**Manual tests by a person:** **none were run.** I cannot play the game; there was no human playtest of readability, caption usefulness or the settings screen on a real monitor. The checklist below is for you, or whoever plays it next. It is also in `docs/qa/REGRESSION_CHECKLIST.md`.

| # | Do | Expect |
|---|---|---|
| 1 | Main menu → Settings: 125 %, volume 40 %, captions off; quit; start again | kept; the menu is bigger, quieter |
| 2 | Pause (Esc) → Settings; change the size; Esc | the HUD resizes at once; Esc closes Settings and stays paused |
| 3 | Expanded Library: walk in | WAYS OUT (top left): main entrance and loading dock with what you know; no passage |
| 4 | Open the Office 1 locker (136) and take the badge | "master badge (Office 1 locker)" turns [x] |
| 5 | Use the dock shutter control without power; the release; flip SERVICE EXIT | each requirement appears when met in the world; POWER line after the switch |
| 6 | Read the culvert access plan | the hidden passage appears with its two steps |
| 7 | Walk into each closed exit | the message names only what you have learned |
| 8 | Throw a bottle; let a guard walk behind you; trip an alarm; flip a switch | "← Glass smashes", "↓ Footsteps", "ALARM ringing", "Breaker clunk" with sensible arrows |
| 9 | Sprint until dry, keep holding Shift | EXHAUSTED · let go of Shift, orange bar, "You're out of breath" |
| 10 | J at 125 % on a small window | the document, then clues; "press J" for more |
| 11 | Get caught | WAYS OUT, POWER and the journal as before the capture |
| 12 | Escape | route, time, catches, optional objectives |
| 13 | Library Tutorial | captions and Settings work; no WAYS OUT, stamina or slots; objectives as before |

**Profiler:** not measured. The additions are UI text updates each frame (two RichTextLabels) and signal handlers.

## 6. Evidence

Screenshots (xvfb, OpenGL 3; sheets [`phase7_contact_sheet.png`](phase-7/phase7_contact_sheet.png), [`phase7_layout_sheet.png`](phase-7/phase7_layout_sheet.png)).

**Feature views at 1280×720, 100 %** ([`phase-7/screens/`](phase-7/screens/)):

| Shot | Shows |
|---|---|
| h01 / h02 | main menu with Settings; the Settings screen |
| h03 | WAYS OUT right after entering: main entrance and dock only |
| h04 | the journal: the culvert plan, then 7 clues |
| h05 | WAYS OUT with the passage, POWER and "Checkpoint: Storage" |
| h06 | captions: ↓ ALARM ringing, ← Glass smashes, ↑ Breaker clunk |
| h07 | → Footsteps, You're out of breath, EXHAUSTED |
| h08 | the completion screen: time, catches, optional objectives, route |
| h09 / h10 | the pause menu with Settings; its Settings screen |
| h11 | the tutorial HUD |

**Layouts** ([`phase-7/layout/`](phase-7/layout/)): the busiest Expanded Library state, its journal and the tutorial, at 1280×720 100 % and 125 %, 1920×1080 100 %, 1024×768 125 %, 2560×1440 90 %. At 125 % on 1280×720 and 1024×768 the journal takes two pages (`l_expanded_journal_p2_*`).

**Screenshot setup:**
- The tool removes the level's guards, and teleports and scripts the player.
- The h07 guard is a test guard with its vision range set to 0, so that it cannot catch the player during the shot; its footsteps are captioned as for any guard.
- h08's time is real (scripted play), not edited.

## 7. Known limitations and risks

- **Not human-tested** (§5): readability and caption wording are judged from screenshots only.
- **Interface size is 2D only:** it scales all HUD and menus; the 3D world-space signs and labels are unchanged.
- **Captions cover the sounds that matter for stealth** (listed in §1), not every ambient sound. Guard footsteps are captioned within 9 m; a guard right behind a wall still shows "Footsteps".
- **Clue order:** the journal lists clues newest first, so a long session pushes older clues to page 2 at large interface sizes.
- **Earlier test expectations changed** (§2). They are consequences of the agreed design, not weakened checks: the menu order with Settings; clues counted apart from documents; the drain's hint text.
- **Tutorial guard-timing flake:** still pending your approval of the one-line test fix (Phase 6 report §5). It was seen again in this phase's full runs (§5).
- **`.github/workflows/build.yml`:** the Phase 5 timeout change (40 → 55 min) is still not delivered, because that folder is write-protected on your computer. Please apply it by hand. The suite now takes about 20 min, more with the new HUD suite.
- **Windows export:** built on Linux only.

## 8. Tutorial regression

The tutorial scene is not edited. What changes there, by design:
- the captions (shared StealthHud);
- the Settings screen in the main menu and the pause menu;
- the win screen listing optional objectives (it has none, so the line is absent).

It shows no WAYS OUT panel, stamina bar or slots (HUD suite I). Its exit keeps E-to-escape and its own message, because the tutorial has no EscapeRoutes node. Tutorial suites, QA flow and map flow results are in §5.

## 9. Git

Branch `Development`, at `7d73492`. Phases 1–7 are uncommitted in the working tree, delivered to `D:\gitclone\CampusEscape3D-2` for you to review, commit and push. Nothing was committed or pushed to your repository.

## 10. Recommendation

**PASS**, on the same condition as Phase 6: that you accept the pre-existing tutorial guard-timing flake (§5). It failed 2 of 8 isolated runs on the Phase 7 code, and 0 of 8 with the proposed one-line test fix. Every Phase 7 criterion passes in automated tests and screenshots; no human manual test was run (§5 lists the checks to do).

I recommend:
1. approving the guard-test fix;
2. applying the `build.yml` timeout line by hand;
3. playing through the manual checklist once before Phase 8.

Stop for approval before Phase 8.
