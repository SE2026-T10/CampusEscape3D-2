# Expanded Library — escape routes and checkpoints (expansion Phase 6, layout x5)

The source of truth is `tools/expanded/expansion/expansion_layout.gd` (`ESCAPES`, `DOORS`, `ITEMS`, `DOCUMENTS`, `SECURITY.cameras`) and `tools/expanded/expansion/escape_x5.py`. The scripts are `scripts/systems/objectives/exit_door.gd` (walk-through exits), `scripts/systems/escape/badge_reader.gd`, `scripts/systems/escape/dock_shutter.gd`, `scripts/systems/objectives/access_door.gd` (hidden doors), `scripts/npc/guard.gd` and `scripts/systems/checkpoints/checkpoint_manager.gd` (guard snapshots).

Only one route is needed; each needs the rare manuscript. Each exit is **walked through**: it opens when its own conditions hold, and the player escapes by walking into a trigger just past the door. Without the manuscript the trigger refuses with "You can't leave without the rare manuscript." E at an exit names the first thing missing (the manuscript first, then the route's own conditions). The route used is recorded (`ObjectiveManager.escape_route`) and shown on the win screen ("Escape route: …").

| | A · Main entrance | B · Loading dock | C · Hidden maintenance passage |
|---|---|---|---|
| Where | lobby, the existing main entrance (z 28) | service corridor, the existing dock exit (x 36, z 24) | basement tunnel's existing north gap (x −2…2, z −27) → storm drain → grate (z −37) |
| Closed by | a lockdown panel that closes once you are inside (enter_library); before that it is the way in | the existing dock door panel (ExitDoorPanel) | a false wall panel (hidden AccessDoor), then the jammed grate |
| Unique prerequisites | the **security master badge** (Office 1 security locker, code 136, from the night rota) + a **4 s override** at the lobby badge reader (stay within 2.5 m; walking away or being caught interrupts it) | **SERVICE EXIT power** (electrical room) + the **shutter release** freed with the tool kit + **OPEN** on the shutter control | the **culvert access plan** (maintenance bay wall) reveals the panel; its **hidden latch** opens it; the **pump** (crank with the tool kit, valves 1+3 OPEN, 2 SHUT, START) clears the grate |
| Exposure | direct but exposed: the reader beeps (12 m) and the bolts bang (16 m), both noises guards hear; a fixed lobby camera looks down at the reader (SURVEILLANCE circuit), so a full override with the cameras on raises an alarm | the shutter rattles up (14 m); the dock camera covers the approach | the pump's stall is loud (Phase 4); the basement guard patrols the tunnel |
| Feedback | reader screen LOCKDOWN / OVERRIDE n% / OPEN, prompt countdown, HUD messages; the enter_library message says the doors locked behind you; sign MAIN ENTRANCE · NIGHT LOCKDOWN / OPEN | control display NO POWER / RELEASE JAMMED / READY / OPEN with HUD messages; sign NO POWER / DOCK · OPEN | no prompt and the wall's colour until the plan is read; then "Work the hidden latch"; sign GRATE JAMMED / CLEAR |
| Recorded as | `main_entrance` · "Main entrance" | `loading_dock` · "Loading dock" | `maintenance_passage` · "Hidden maintenance passage" |

**No softlock.** Nothing is consumed (the badge and the tool kit are only checked). Every switch, door and puzzle can be redone after a respawn. The journal keeps the plan, so the hidden panel stays findable. Turning SERVICE EXIT off closes an open dock shutter, and turning it on reopens it (it stays unlocked). All three routes stay available whatever the player did first.

## Checkpoint snapshot

What a checkpoint stores, and what a capture restores:

| Part | Behaviour |
|---|---|
| Respawn position and facing | the checkpoint's spawn transform; the head is level |
| Mandatory and optional objective progress | as stored (ObjectiveManager.restore keeps only consistent progress) |
| Mission item and carried inventory, shelves, pickups | as stored (Phase 3); no duplicates (5 repeated captures tested) |
| Puzzles, circuits, doors, shortcut | as stored (Phases 3–5) |
| Exits | walk-through exits store `unlocked`; the dock release (ToolMechanism) and the hidden panel (AccessDoor) store their own state; the main entrance lockdown follows enter_library; a badge override in progress is cancelled (not stored) |
| Guards (Expanded Library only, `Guard.checkpoint_snapshot`) | position, facing and patrol point taken at the moment the checkpoint changed something; restored on PATROL with detection 0 (a guard investigating then patrols on). A guard whose stored spot is within 10 m of, or in sight of, the respawn point goes to its start instead |
| Stamina | full (not stored) |
| Detection | every guard's meter and memory cleared; status NONE |
| Journal | kept (knowledge; Phase 4 rule) |
| Escape route record | cleared |
| Not stored | attempts, lockouts, alarms, the reboot lock, a badge override in progress |

**Capture sequence:** the caught screen ("CAUGHT · Back to <checkpoint>…", 2.5 s, everything frozen) → respawn → the snapshot is restored → the HUD shows the restored state. Before any checkpoint the player respawns on the porch with the starting state, so the main entrance is open again and locks again on re-entering.
