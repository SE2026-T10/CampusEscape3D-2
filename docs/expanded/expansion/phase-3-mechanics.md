# Expanded Library expansion — Phase 3: stamina and inventory

**Date:** 2026-10-15 · **Branch:** `Development` (at `7d73492`; Phases 1–3 uncommitted in the working tree) · **Engine:** Godot 4.7.2 stable · **Layout:** x2

Owner decisions for this phase (asked before building):
- stamina in the **Expanded Library only**;
- the staff card becomes a **carried item**;
- items can be left or swapped **only at storage points**;
- a **provisional set** of items is placed now.

## 1. Summary

**Stamina** (Expanded Library only; the tutorial keeps unlimited sprint):
- 100 maximum. Sprinting drains 20 per second; stamina refills at 15 per second, starting 1 s after the sprint ends.
- A sprint needs at least 15 to start and stops at 0. After running dry, the player has to release Shift before sprinting again, so holding it does not stutter on and off at 15.
- Respawning refills stamina.
- Only a moving, standing sprint costs stamina. Walking, standing, crouching, hiding, using things and being seen cost nothing.
- Everything is computed from the frame time. The part of a frame left over after the 1 s delay counts towards refilling, so timings do not depend on the frame rate.
- All values are settable on `Player/Stamina`.
- HUD: a stamina bar above the stance line. It turns orange ("catch your breath") until a sprint can start again.

**Inventory** (one system, `Player/Inventory`):
- **Three carried slots.** Keys 1–3 select a slot; F uses the selected item. A fourth item is refused with "hands full", and so is the staff card.
- **Reusable items:**
  - The **tool kit** works designated mechanisms (`ToolMechanism`). It is only checked, never used up.
  - The **staff card** still completes its objective. The Lobby Staff Door, the Archive Front Gate and the electrical room door now open while you carry it.
- **Single-use distractions** (glass bottle, heavy hardback):
  - F throws one where you aim. It is used up only when the throw has somewhere to land.
  - On landing it makes one noise, and guards investigate it like any other noise.
- **Clue documents** go to a separate **journal** (J), once each. The note itself stays where it is.
- **Storage shelves** are the only places to leave an item, take it back, or swap one when your hands are full. There is no drop-anywhere action.
- **Checkpoints:** being caught puts the carried slots, shelves and pickups back exactly as they were at the checkpoint, so nothing is duplicated or lost. Throws made since then are undone. The journal is kept.
- HUD: three slots at the bottom centre (the selected one outlined), item messages, a journal panel, and the item keys in the pause menu (Expanded Library only).

**Provisional placements** (new areas only; no geometry or navmesh change):
- the tool kit in the maintenance bay;
- three distractions: two bottles and a hardback, on the basement crates;
- two shelves, in the maintenance bay and the electrical room;
- two documents: the pump room log and the electrical room notice.

**No tool-kit mechanism is placed yet.** The Phase 4 puzzles will add them; the mechanism component itself is built and tested.

## 2. Exact files changed

**New**
| File | What |
|---|---|
| `scripts/player/player_stamina.gd` | `PlayerStamina`: the stamina rules |
| `scripts/player/player_inventory.gd` | `PlayerInventory`: slots, selection, use/throw, journal, checkpoint state |
| `scripts/systems/inventory/item_catalog.gd` | `ItemCatalog`: item ids, names, kinds, looks, distraction noise |
| `scripts/systems/inventory/item_pickup.gd` | `ItemPickup` (an `Interactable`): items in the level and on shelves |
| `scripts/systems/inventory/item_storage.gd` | `ItemStorage` (an `Interactable`): storage shelves |
| `scripts/systems/inventory/document_pickup.gd` | `DocumentPickup` (an `Interactable`): clue documents |
| `scripts/systems/inventory/tool_mechanism.gd` | `ToolMechanism` (an `Interactable`): mechanisms that need a tool |
| `scripts/systems/inventory/thrown_item.gd` | `ThrownItem`: a thrown distraction, which makes its noise on landing |
| `tests/expanded_mechanics_tests.gd` | the Phase 3 test suite |
| `tools/expanded/expansion/enable_items.py` | the minimal text patch of `expanded_library.tscn` (5 property lines) |
| `tools/expanded/expansion/keep_ids.py` | keeps node and resource ids stable when the sub-scene is rebuilt |
| `tools/expanded/expansion/capture_mechanics.gd` | the screenshot tool for this phase |
| `docs/expanded/expansion/phase-3-mechanics.md`, `docs/expanded/expansion/phase-3/` | this report and its evidence |
| `.uid` files of the new scripts | created by Godot |

**Modified**
| File | Change |
|---|---|
| `scripts/player/player.gd` | `use_stamina` / `use_inventory` exports; sprint goes through `Stamina`; `respawn()` refills stamina |
| `scenes/player/player.tscn` | two child nodes, `Stamina` and `Inventory` (off by default) |
| `scripts/systems/objectives/access_card.gd` | optional `grants_item` (the tutorial leaves it empty) |
| `scripts/systems/objectives/access_door.gd` | optional `key_item`: KEY doors check a carried item instead of the objective |
| `scripts/ui/objective_hud.gd` | slots, journal, item messages; "hands full" prompts shown as warnings |
| `scripts/ui/stealth_hud.gd` | the stamina bar |
| `scripts/ui/game_menus.gd` | the pause menu adds the item keys only when the level has an inventory |
| `project.godot` | input actions `use_item` (F), `item_slot_1..3` (1–3), `journal` (J) |
| `scenes/level/expanded_library.tscn` | **5 added lines:** `use_stamina` and `use_inventory` on Player; `grants_item` on StaffAccessCard; `key_item` on G2 and G4 |
| `scenes/level/expanded_library_expansion.tscn` | rebuilt with layout x2 (ids kept): `Items`, `Storage` and `Documents` groups added, and the electrical room door's `key_item`; geometry identical |
| `tools/expanded/expansion/expansion_layout.gd` | `VERSION "x2"`; ITEMS, STORAGE and DOCUMENTS tables; door `key_item` |
| `tools/expanded/expansion/build_expansion.gd` | builds the new groups |
| `tests/expanded_layout_expansion_tests.gd` | the electrical room door check now also expects `key_item = staff_card` |
| `tests/test_scene.gd` | runs the new suite; pass line |
| `README.md`, `docs/expanded/LAYOUT.md`, `docs/expanded/LEVEL_LOG.md`, `docs/qa/REGRESSION_CHECKLIST.md` | controls, architecture, tests, layout x2, log entry, checklist row |

**Not changed:**
- the tutorial scene;
- the navmeshes;
- geometry, guards and routes;
- the frozen builder;
- every other test.

`tests/expanded_baseline_tests.gd` still passes unchanged: its digests do not cover the five new property lines.

## 3. Existing systems reused

| Existing system | How Phase 3 reuses it |
|---|---|
| `FirstPersonPlayer` | Sprint speed, crouch and respawn are unchanged; stamina only decides whether this frame is a sprint. |
| `PlayerInteractor` / `Interactable` | Every pickup, shelf, document and mechanism is an `Interactable`, used with E and the same prompt. |
| `AccessCard` / `AccessDoor` | Extended with one property each instead of adding new card or door classes. |
| `CheckpointManager` (`checkpoint_state` group) | Inventory, pickups, shelves and mechanisms store and restore through it. No new save system. |
| `NoiseSystem` / guard hearing | Distractions are ordinary noises (source "distraction"), so the guards' existing investigate behaviour handles them. |
| `ObjectiveHud`, `StealthHud`, `GameMenus` | Extended in place; no new UI layer. |
| Expansion sub-scene, layout data and builder | Placements are data in `expansion_layout.gd`, built into the same sub-scene. |

## 4. Acceptance criteria

| Criterion | Result | Evidence |
|---|---|---|
| Stamina rules and timings as specified | **PASS** | Full sprint 5.000 s at 30/120/7 Hz, 5.017 s at 60 Hz and 5.007 s at 144 Hz (within one step). No refill during the 1 s delay, then exactly 15/s. Empty to full 7.667 s. 14.9 refused, 15 starts. Stops at 0. Respawn refills. No drain walking, standing (Shift held), crouching, hiding, using things or being seen (75 frames watched). |
| Sprint consistent at different frame rates | **PASS** | Real-input 6 s run down the tunnel: 30 Hz 5.000 s sprint, 30.40 m; 60 Hz 5.017 s, 30.41 m; 120 Hz 5.000 s, 30.36 m (spread 0.05 m). Uneven steps (4–50 ms) give 5 s ± 0.05. |
| Inventory never exceeds three slots | **PASS** | The 4th pickup is refused (prompt and message), the staff card too, and `add()` refuses at 3. Deliberate break M2 is caught. |
| Reusable items not consumed | **PASS** | The tool kit worked 2 mechanisms and F was pressed ×3: still carried. The card opened G4, the electrical room door and G2: still carried. Without the tool kit a mechanism refuses. M3 is caught. |
| Single-use distractions consumed exactly once per successful use | **PASS** | 2 throws → 2 used, 2 noises (one each). The guard 8 m away investigated. F on an empty slot and a throw with nowhere to land used nothing. |
| Documents separate from carried inventory | **PASS** | 2 documents in the journal; slots unchanged; reading twice gives one entry; J opens and closes the journal. |
| Respawn does not duplicate items | **PASS** | 3 catches in a row: slots `[toolkit, bottle, —]` and shelf `[hardback]` restored exactly, pickups restored, throws undone, item totals equal to the start. Card taken after the checkpoint goes back on the desk and out of the slots; taken before, it stays exactly once. M4 is caught. |
| Existing movement and tutorial interactions still work | **PASS** | All tutorial suites passed in run 2; in the other runs the only failure was the pre-existing guard timing check (section 5). Tutorial check: no stamina, inventory, item HUD or new pause-menu keys; card and doors keyed to objectives; 8 s of unlimited sprint. Tutorial screenshot before/after: the bottom HUD strip is pixel-identical. |
| Drop/swap only at appropriate locations (task list) | **PASS** | Leave, take back and swap only at shelves; no drop action; F never drops a tool. Totals unchanged. |

## 5. Tests actually run (Linux VM, Godot 4.7.2 official)

**Validation:** `tools/ci/validate.sh` passed (108 scripts compile).

**Full suite**, `tools/ci/run_tests.sh`, 4 runs:

| Run | Code | Result |
|---|---|---|
| 1 | before the slot-width tweak | 3 failures, all in the tutorial guard first-wait timing check |
| 2 | before the slot-width tweak | **All tests passed** (8 expected warnings, no errors); QA FLOW PASSED (15); MAP FLOW PASSED (52) |
| 3 | final | 3 failures, the same timing check only |
| 4 | final | 3 failures, the same timing check only |

- The only change between run 2 and the final code is the HUD slot width (150 → 184 px).
- Every other check passed in all 4 runs, including all 8 sections of the new suite.
- On the final code, QA FLOW PASSED (15) and MAP FLOW PASSED (52) were run separately, and the export was rerun: EXPORT PASSED.

**The timing failure is not a Phase 3 regression.** It reads "GuardMain waited 3.20–3.40s at point 1, expected 3.00s", with the same failure for GuardRestricted and GuardEast:
- It fails the same way, and as often, on the released `7d73492`: running the start of the suite on both builds gave 0, 0, 3 failures each.
- Run on their own, the guard tests fail 100% of the time on every build.
- The check runs before any Expanded Library code, and the tutorial's new player nodes are off.
- Details: `phase-3/guard_timing_flake.txt`.
- **Fixing it changes a tutorial test, so it needs your approval.** Until it is fixed, the CI test job can go red at random on any branch.

**Deliberate-break checks** (`phase-3/mutation_checks.txt`): each break makes the new suite fail.
- M1: no regeneration delay;
- M2: no slot limit;
- M3: the use key uses up tools;
- M4: slots not stored at checkpoints.

**Manual tests:** none were run (no access to your editor or display). Suggested checks are in `docs/qa/REGRESSION_CHECKLIST.md`, row "Expanded Library stamina and inventory".

## 6. Evidence

All in `docs/expanded/expansion/phase-3/`:
- `screens/`: 11 in-game screenshots with the HUD:
  - taking the tool kit;
  - stamina draining, then empty (orange);
  - hands full at the 4th item;
  - a bottle thrown, then landed;
  - the shelf prompt, then an item left on the shelf;
  - the document prompt, then the journal;
  - the card carried and the electrical room door green.
- `contact_mechanics.png`: all 11 on one sheet.
- `tutorial_before_after.png` (with `tutorial_before/` and `tutorial_after/`): the tutorial sprinting on the Phase 2 and Phase 3 builds, with no stamina bar and no slots.
- `mutation_checks.txt`, `guard_timing_flake.txt`, and `logs/` (test runs, export).

## 7. Known limitations and risks

- **Provisional placements:**
  - Items, shelves and documents may move with the Phase 4 puzzles.
  - The documents' texts are placeholders without real clues.
  - No tool-kit mechanism is placed yet.
- **Detours with full hands:** both shelves are in the new areas. A player carrying three items when reaching the staff card has to throw a distraction or walk back to a shelf. Not playtested for pacing.
- **Pacing:**
  - The 20–30 minute target has not been re-measured with stamina.
  - The guards' chase speed is unchanged, so long chases are harder now that sprints last 5 s.
- **Models made at run time:** item, shelf and clipboard models are built by their scripts at run time. In the editor these nodes show only their interaction boxes.
- **Throwing:**
  - A throw lands instantly where you aim, after a short arc; there is no physics bounce.
  - Thrown items are not stored at checkpoints: they are cleared when you are caught.
- **The journal** stays open until J is pressed again or the level ends. It does not pause the game.
- **Not verified on Windows**, and the editor was not opened.
- **Editor re-save:** don't re-save `expanded_library.tscn` in the editor; it may rewrite the whole file.

## 8. Tutorial regression

The tutorial scene is untouched, and its player has stamina and inventory switched off. The test suite checks this:
- sprint is unlimited for 8 s;
- no stamina bar, slots or new pause-menu keys;
- the card and doors still use objectives;
- its checkpoint snapshots do not include an inventory.

All tutorial suites passed in run 2. In runs 1, 3 and 4 the only failure was the pre-existing guard timing check described in section 5; everything else in the tutorial passed.

## 9. Git

`Development` at `7d73492`; Phases 1, 2 and 3 are uncommitted in the working tree. Suggested order: commit Phase 1, Phase 2 and Phase 3 separately, after checking `git status`.

## 10. Recommendation

**PASS** for Phase 3: every Phase 3 acceptance criterion passed in every run.

The full suite is not reliably green. The cause is the tutorial guard timing check described in section 5, which fails the same way on the released build. Approving its one-line fix would make the suite green.

Stop for approval before Phase 4.
