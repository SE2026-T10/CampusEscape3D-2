# Expanded Library — security specifications (expansion Phase 5, layout x4)

The source of truth is `tools/expanded/expansion/expansion_layout.gd` (`SECURITY`) and `tools/expanded/expansion/security_x4.py`. The scripts are in `scripts/systems/security/` (new), `scripts/systems/puzzles/power_network.gd`, `scripts/npc/` and `scripts/systems/hiding_spot.gd`.

## Circuits (`PowerNetwork`)

| Circuit | Starts | Controlled by | Powers (only) | Without power |
|---|---|---|---|---|
| `archive_access` | OFF | the Phase 4 breaker panel (behind the cover) | the vault keypad | keypad shows NO POWER; a code does nothing |
| `surveillance` | ON | SURVEILLANCE switch | the 4 cameras | lenses dark, cones hidden, no meter, no alarm |
| `service_exit` | OFF | SERVICE EXIT switch | the loading dock shutter (ExitDoor) | with the manuscript the sign says SHUTTER · NO POWER and E explains it |

**Trade-off.** Turning SERVICE EXIT **ON** also turns SURVEILLANCE ON ("security reboot") and locks the SURVEILLANCE switch for 30 s (its prompt counts down; pressing it says when to try again). After that it works normally. Turning SERVICE EXIT OFF changes nothing else.

**No softlock.** Every switch toggles both ways. The vault keypad depends only on the breakers. The dock opens with the manuscript + SERVICE EXIT ON (one press from any state). The storm drain (manuscript + drained culvert) never needs power. All 8 combinations are tested.

**Feedback.** Every switch use shows a HUD message saying what changed (kept under 80 characters) and makes a breaker clunk (noise radius 9 m) that nearby guards can hear. The switches show their state (green ON / red OFF, label).

**Persistence.** Circuits are part of the checkpoint state: when caught, they go back to what they were at the checkpoint (switches follow). The 30 s reboot lock is not stored; a respawn clears it.

## Cameras (`SecurityCamera`, group `security_cameras`)

| Camera | Position | Watches |
|---|---|---|
| staff corridor | (11.6, 7.5, −13.6) | the upper staff corridor toward the offices |
| archive hall | (27.6, 7.5, −6.4) | the archive hall behind G2 |
| loading dock | (35.6, 3.5, 12.4) | the dock approach |
| service tunnel | (12, −0.7, −23.25) | the basement tunnel westward |

- Sweep ±35° at 18°/s, 50° field of view, 13 m range, pitched down toward the floor. A ray (world + player layers) must reach the player.
- Meter: rises 20–70 per second (far → near) × the player's visibility factor (crouched ×0.5); falls 25 per second out of view. A player concealed in a hiding spot is never seen.
- At 100: `SecurityAlarm.raise_alarm(player position, "Camera (name) spotted you", 25 m)`: a HUD banner "ALARM: Camera (…) spotted you", a noise guards investigate, then an 8 s cooldown. **Never a capture.**
- Lens: green scanning, yellow while the meter fills, red after an alarm, dark without power.

## Guards (`Guard.expanded_security`, on for the Expanded Library's 7 guards only)

| Rule | Behaviour | Defaults |
|---|---|---|
| Hiding | A hiding spot hides a crouched player only if no guard saw them and none was chasing when they got in (`HidingSpot.entered_unseen`). A guard within `hiding_check_reach` of the spot sees them anyway. | reach 1.6 m |
| Searching | In INVESTIGATE, on reaching the searched place, the guard first walks to the nearest unchecked hiding spot within `hiding_check_radius` (same floor), then searches as before. | radius 7 m |
| Alarm attention | While the `SecurityAlarm` sounds: detection meter × `alarm_detection_multiplier`, search time × `alarm_search_multiplier`. | ×1.6, ×1.5 |

States stay PATROL / INVESTIGATE / CHASE. Distractions, noises, alarms and switch clunks all reach guards through the existing NoiseSystem → GuardHearing → INVESTIGATE path. Losing the player still goes CHASE → INVESTIGATE (last known position) → PATROL.

**GuardBasement** (route P9_Basement): (−30, −4, −25) → (−10, −4, −24.8) → (14, −4, −25) → (39, −4, −21) → (39, −4, −10), looping. The same model and detection tuning as GuardLobby.

## Escapes

- **Loading dock:** the manuscript **and** SERVICE EXIT power. The message names the manuscript first, then the power.
- **Storm drain:** the manuscript and the drained culvert; no power needed.
- **Main entrance:** still reserved (`SecurityAlarm.main_entrance_lockdown` stays true; nothing lifts it).
