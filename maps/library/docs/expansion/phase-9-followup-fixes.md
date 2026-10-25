# Expanded Library expansion — Phase 9 follow-up fixes

Date: 2026-10-19. Branch for the owner's commit: `Development`. Godot 4.7.2 stable (official).

The owner approved these items from the Phase 9 known-issues list: **2, 4, 7 (c + a), 8 (a), 9 (a), 11, 14 (b), 15, 16–17 (b)**. Not approved and not touched: 12 (A/B benchmark script) and 18 (Phase 9 report wording). Items 1, 3, 5, 6, 10 and 13 are the owner's to do, or need no change.

## 1. Summary

| # | Fix | Result |
|---|---|---|
| 2 | `tests/guard_tests.gd` waits one rendered frame after setting `Engine.time_scale`, before timing the guards' waits | the flake did not fire in either full run after the fix (it fired in both full runs before) |
| 4 | `tools/ci/run_tests.sh`: suite timeout 1800 → 2400 s | the suite takes about 1500 s |
| 7c | Staff Offices checkpoint: the pad stays in front of the card desk (taking the card still saves); the **respawn moves to the back of Office 1, facing its door** (−1.8, 4.5, −26.3) | Office 1's door is 3 m from the stacks staff door G1b, the way to the quiet back stair S3, away from the balcony and the archive gate; no guard sees it during the patrols |
| 7a | **Balcony nook**: a carrel panel (1.2 m) and a low bench (0.8 m) against the staff wing's south wall, west of G1a, open to the west, with a hiding spot inside (−3.1, 4.5, −7.05) | walkable from the entrance; off GuardConnector's legs |
| 8a | **Maintenance Bay checkpoint**: a pad inside the bay's door (−24, −4, −21.6), respawn (−22.6, −4, −19) facing the door | walking in, and out again with the tool kit, saves; a capture in the tunnel now keeps the tool kit |
| 9a | **Tunnel niche**: 2 m wide, 1.6 m deep, in the tunnel's north wall at x −12…−10 beside the west crate, with a hiding spot inside (−11, −4, −27.85) | walkable; the tunnel's width is unchanged |
| 11 | Meshes reached by more than 8 lights: two ground-floor batches split until no piece exceeds 8 (every box kept, checked); the staff card, the Staff Offices pad, the upper stacks hiding spot's floor mark and Office 2's chair moved to the upper floor's render layer (8), so the ground and basement lamps below no longer reach them | light report: **0 meshes over 8 lights (was 7)**; lights in view still at most 32, 0 views over the limit |
| 14b | The pump room's two risers and the electrical room's two floor-to-ceiling conduits moved into the room corners and slimmed to 0.12 m | still no collision; decor clearance test passes |
| 15 | `MechanismAudio`: a wrong pump setting plays only its stall bang (no buzz); every other puzzle keeps its buzz | tested |
| 16–17b | Owner's action: regenerate the sounds on your PC (section 8) | — |

Cause of the 9th light on the two batches (item 11): it was one of the expansion's own annex lamps (west landing, east annex), whose range cube reaches across the annex wall onto the original map's floor batches.

## 2. Exact files

| File | Change |
|---|---|
| `tests/guard_tests.gd` | one `await` (item 2) |
| `tools/ci/run_tests.sh` | 2400 s (item 4) |
| `scripts/presentation/mechanism_audio.gd` | no buzz for `PumpControl` (item 15) |
| `tools/expanded/expansion/expansion_layout.gd` | `TunnelNiche` floor, `TunnelNorthWest` split (+ `TunnelNorthMid`, `NicheWest/East/Back`), niche ceiling, `BalconyNookPanel` / `BalconyNookBench` cover (zone E, upper layer), two `HIDING` entries, new `CHECKPOINTS`, risers and conduits moved (item 14b) |
| `tools/expanded/expansion/build_expansion.gd` | `E_StaffBalcony` geometry group; cover `layers`; `_add_checkpoint()`; upper-floor hiding marks on the upper layer |
| `tools/expanded/expansion/fixes_x7.gd` (+ `.uid`) | new: idempotent patch of `expanded_library.tscn` (batch splits, prop layers, Staff Offices respawn) |
| `scenes/level/expanded_library.tscn` | patched by `fixes_x7.gd` (no collision, guard or route change) |
| `scenes/level/expanded_library_expansion.tscn` | rebuilt |
| `scenes/level/expanded_library_navmesh.tres` | rebaked: 1031 polygons (was 1020) |
| `tests/expanded_polish_tests.gd` | section D: pump sound, the two hiding spots walkable, the bay checkpoint saves and respawns facing its door, Staff Offices respawn in Office 1, no mesh over 8 lights |
| `tests/expanded_baseline_tests.gd` | the approved change recorded: decoration digest, batched nodes 295 → 307, navmesh 1031 polygons |
| `tests/expanded_ai_tests.gd`, `tests/expanded_mission_tests.gd` | count the expansion's checkpoint too (3 + 1) |
| `tests/expanded_e2e_tests.gd` | run B redoes the pump after a capture even when the tool kit is kept (the bay checkpoint now saves it) |
| `docs/expanded/LAYOUT.md`, `docs/expanded/LEVEL_LOG.md`, `README.md`, `docs/qa/REGRESSION_CHECKLIST.md` | the changes, the new checklist row |
| `docs/expanded/expansion/phase-9-followup-fixes.md`, `phase-9-followup/` | this report and its evidence |

## 3. Systems reused

`Checkpoint` / `CheckpointManager` (the new checkpoint is built exactly like the level's three: pad, spawn marker, label), `HidingSpot` and the builder's `_add_hiding_spot`, the builder's wall/floor/cover helpers and palette, `BatchedBoxes` (the split keeps each box's saved text), `tools/expanded/expansion/bake_navmesh.gd`, `tools/expanded/light_report.gd`, `tools/expanded/collision_fingerprint.gd`, the playtest bot.

## 4. Checks

| Check | Result |
|---|---|
| Collision fingerprint vs Phase 9 | only the intended additions: the niche's floor and three walls, the tunnel's north wall split in two, the nook's two cover bodies, two hiding spot areas and the bay checkpoint area ([`checks/collision_fingerprint_diff.txt`](phase-9-followup/checks/collision_fingerprint_diff.txt)); nothing in the original map |
| Batch split | 1769 batched boxes outside the expansion before and after, identical as world transform + colour + layer ([`checks/batch_split_check.txt`](phase-9-followup/checks/batch_split_check.txt)) |
| Light report | 0 meshes over 8 lights (was 7); max 32 lights in view, 0 views over ([`checks/lighting_report.md`](phase-9-followup/checks/lighting_report.md)) |
| Navmesh | rebaked 1031 polygons; the nook, the niche, the bay pad and both new respawns are on it and reachable from the entrance |
| Respawn points | `expanded_ai_tests`: Study Rooms, Staff Offices (Office 1), Storage and Maintenance Bay never in a guard's view during the full patrol run |
| Screenshots | [`screens/fix_views.png`](phase-9-followup/screens/fix_views.png): niche from the tunnel and from inside, the nook from the west and the east, the bay pad, the Office 1 respawn view, the pump risers, the electrical conduits |

## 5. Bot playtests (same settings as Phase 8: careful profile, seed 1, scale 3, 45 min cap)

| Route | Phase 8 | Now |
|---|---|---|
| passage | not completed; 34 captures (GuardConnector 28, GuardArchive 5, GuardLobby 1) | not completed; 21 captures, **all GuardBasement**, all but one at the same spot in the east basement (38.2, −4, −19.5) |
| dock | not completed; 14 captures (GuardBasement 14) | not completed; 45 captures (GuardConnector 39 in the reading hall at (−7.9, 0, 4.3), GuardLobby 3, GuardStacksOuter 2, GuardBasement 1) |
| main | completed in 40:21; 30 captures (GuardConnector 18, GuardArchive 6, GuardBasement 4, GuardLobby 2) | not completed; 37 captures (GuardLobby 36 in the lobby, GuardBasement 1) |

**What this shows, and what it doesn't:**
- The Phase 8 clusters on the upper floor (staff balcony, staff corridor, by GuardConnector and GuardArchive) are gone from these runs: **0 upper-floor captures by those two guards** (Phase 8, same seeds: 33 of 34 in the passage run, 21 of 30 in the main run).
- But no route completed, and every run ends in a loop. The bot is caught at one spot every 1–2 minutes, the same way each time. A logged rerun of the dock route confirms the respawn is the new Maintenance Bay checkpoint ([`bot/respawn_check_dock_seed1.txt`](phase-9-followup/bot/respawn_check_dock_seed1.txt)).
- **Cause, in the bot:** after a capture it marks the spot as a hard obstacle. From the bay, the spot it marked in the tunnel blocks the short way east to the electrical room. Its detour then climbs to the ground floor and crosses the reading hall or the lobby, where it is caught again. It never waits for the guard to pass or uses a hiding spot. The same "no detour avoids the spot" loop appears in its logs.
- **What a player can do there:** wait for GuardBasement to pass, using the new tunnel niche and the crates, then go east.
- So these runs **cannot measure** whether P1–P3 made the map easier or harder. Your timed playthrough (item 3) is the real check. A bot change that waits at a capture spot instead of routing around it would make the bot useful again; it is not done, since it was not part of the approved list.

## 6. Tests actually run (Linux VM, Godot 4.7.2 official)

| Run | Result |
|---|---|
| Full suite, first run after the changes | 8 failures, all expected consequences of the approved changes: two tests counted 3 checkpoints (now 4); e2e run B assumed a capture also undoes the tool kit; the baseline's decoration digest, batched-node count and navmesh polygon count. All fixed in the tests as described in section 2 ([`logs/tests_first_run.log`](phase-9-followup/logs/tests_first_run.log)). The guard-timing flake did not fire |
| `polish`, `baseline`, `mission`, `ai`, `e2e` suites alone, after the test updates | 0 failures each |
| `tools/ci/validate.sh` | exit 0 |
| `tools/ci/run_tests.sh` (now 2400 s) | **All tests passed**, 1537 s, including the tutorial `guard_tests`; the 8 expected warnings, 0 script errors ([`logs/tests.log`](phase-9-followup/logs/tests.log)) |
| `tools/qa_flow.gd` | QA FLOW PASSED (15 checks, 4 levels loaded) |
| `tools/map_flow.gd` | MAP FLOW PASSED (52 checks, 12 levels loaded, 3 cycles) |
| `tools/ci/export_windows.sh` | EXPORT PASSED: `dist/CampusEscape3D-1.1.0-windows-x64.zip` (not launched on Windows) |
| `fixes_x7.gd` run twice | the second run: "nothing to change" |
| Tutorial | unchanged scene; all tutorial suites, QA flow and map flow pass |

## 7. Known issues and risks

1. **Bot loops** (section 5): a bot limitation, made visible by the new basement respawn. Proposal, not applied: the bot waits at a remembered capture spot, or tries a hiding spot, before routing around it.
2. **The bay respawn is in the basement**, a tunnel's length from GuardBasement's patrol. That is the purpose of P2 (no more trips back from the porch), but a player respawning there must time that guard. The niche (P3) is 10 m west of the bay door.
3. **Draw calls:** the two split batches add 12 batch nodes on the ground floor (each drawn only when in view). Measured cost not re-run; the earlier Phase 9 numbers are from before this split.
4. **Frame-rate targets (item 1), your timed run (item 3), `build.yml` (item 5) and the Windows export test (item 6)** are still open on your side.
5. Items 12 and 18 were not approved and are unchanged.

## 8. Items 16–17: regenerate the sounds on your PC

From the project folder, with Godot 4.7.2 (PowerShell):

```
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tools/generate_audio.gd
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --headless --path . --import
```

Then `git status` shows the 42 files in `assets/audio/*.wav` as modified. Their audio is identical; only the transfer's provenance block is gone. Commit them on their own ("Regenerate sounds without transfer metadata"). The `.import` files should not change.

## 9. Git

Nothing committed or pushed in your repository. Files delivered to `D:\gitclone\CampusEscape3D-2` for you to review and commit on `Development`.
