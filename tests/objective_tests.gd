extends RefCounted

## Phase 9 objective, interaction and checkpoint tests. Called from tests/test_scene.gd.
##   - ObjectiveManager rules, without a scene
##   - the library's objective setup: everything placed, on the navmesh and reachable in order
##   - interaction: aiming, reach, walls
##   - the full flow: enter → restricted stacks → card → exit area → door; the
##     door rejects the player before the card
##   - checkpoints: activation, respawn after being caught, which progress
##     survives, no activation during a chase, guards reset on respawn
##   - no guard can see a checkpoint's respawn point during its patrol
## The flow tests remove the level's guards and use one test guard to catch
## the player when needed, so they don't depend on patrol timing.

const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const TestUtils := preload("res://tests/test_utils.gd")
const S := StealthDirector.Status
## Standing spots used to interact.
const AT_CARD := Vector3(-14.2, 0.05, -24.9)
const AT_DOOR := Vector3(26.4, 0.05, -23)
## Inside the "reach" triggers.
const IN_MAIN_ROOM := Vector3(0, 0.05, 12.5)
const IN_RESTRICTED := Vector3(-9, 0.05, -19)

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _player: FirstPersonPlayer
var _interactor: PlayerInteractor
var _objectives: ObjectiveManager
var _checkpoints: CheckpointManager
var _director: StealthDirector
var _hud: ObjectiveHud
var _card: AccessCard
var _door: ExitDoor
var _guard: Guard
var _route: PatrolRoute


func run(host: Node) -> Array[String]:
	_host = host
	_check_flow_rules()
	_check_progress_snapshots()
	await _load_level(false)
	await _check_level_setup()
	await _check_interaction()
	await _check_exit_rejects_without_card()
	await _check_card_and_escape()
	await _load_level(false)
	await _check_checkpoint_keeps_progress_before_it()
	await _load_level(false)
	await _check_checkpoint_undoes_progress_after_it()
	await _load_level(true)
	await _check_guards_reset_on_respawn()
	await _load_level(true)
	await _check_checkpoints_are_safe()
	_unload()
	await _frames(2)
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[objectives] " + message)


# --- ObjectiveManager rules (no scene) ------------------------------------------------

func _check_flow_rules() -> void:
	var m := ObjectiveManager.new()
	m.setup(ObjectiveManager.MVP_OBJECTIVES)
	var changes: Array = []
	var finished := {"count": 0}
	m.objective_changed.connect(func(id, state): changes.append([id, state]))
	m.level_completed.connect(func(): finished.count += 1)
	_expect(m.get_ids() == [ObjectiveManager.ENTER_LIBRARY, ObjectiveManager.REACH_RESTRICTED, ObjectiveManager.TAKE_CARD, ObjectiveManager.REACH_EXIT, ObjectiveManager.ESCAPE],
		"The MVP flow should be enter → restricted stacks → card → exit → escape (got %s)." % [m.get_ids()])
	_expect(m.current() == ObjectiveManager.ENTER_LIBRARY and m.get_state(ObjectiveManager.ENTER_LIBRARY) == ObjectiveManager.State.ACTIVE, "The first objective should start ACTIVE.")
	for id in [ObjectiveManager.REACH_RESTRICTED, ObjectiveManager.TAKE_CARD, ObjectiveManager.REACH_EXIT, ObjectiveManager.ESCAPE]:
		_expect(m.get_state(id) == ObjectiveManager.State.LOCKED, "'%s' should start LOCKED." % id)
	# Out of order: refused, nothing changes.
	_expect(not m.complete(ObjectiveManager.TAKE_CARD) and not m.complete(ObjectiveManager.ESCAPE), "Locked objectives must not complete.")
	_expect(changes.is_empty() and m.completed_count() == 0, "A refused completion must change nothing.")
	_expect(not m.complete(&"nonsense"), "Unknown objectives must not complete.")
	# In order.
	_expect(m.complete(ObjectiveManager.ENTER_LIBRARY), "The active objective should complete.")
	_expect(m.get_state(ObjectiveManager.ENTER_LIBRARY) == ObjectiveManager.State.COMPLETED and m.current() == ObjectiveManager.REACH_RESTRICTED,
		"Completing one should activate the next.")
	_expect(changes == [[ObjectiveManager.ENTER_LIBRARY, ObjectiveManager.State.COMPLETED], [ObjectiveManager.REACH_RESTRICTED, ObjectiveManager.State.ACTIVE]],
		"Completing should report COMPLETED then the next ACTIVE (got %s)." % [changes])
	_expect(not m.complete(ObjectiveManager.ENTER_LIBRARY), "A completed objective must not complete again.")
	for id in [ObjectiveManager.REACH_RESTRICTED, ObjectiveManager.TAKE_CARD, ObjectiveManager.REACH_EXIT]:
		m.complete(id)
	_expect(not m.is_finished() and m.current() == ObjectiveManager.ESCAPE and finished.count == 0, "Escaping should be the last step.")
	_expect(m.complete(ObjectiveManager.ESCAPE) and m.is_finished() and m.current() == &"" and finished.count == 1,
		"Completing the last objective should finish the level once.")
	var active := 0
	for id in m.get_ids():
		if m.get_state(id) == ObjectiveManager.State.ACTIVE:
			active += 1
	_expect(active == 0, "Nothing should be ACTIVE once finished.")
	m.reset()
	_expect(m.current() == ObjectiveManager.ENTER_LIBRARY and m.completed_count() == 0, "reset() should start the flow again.")
	_expect(m.get_title(ObjectiveManager.TAKE_CARD) == "Take the access card" and m.get_hint(ObjectiveManager.TAKE_CARD) != "", "Objectives need a title and hint.")
	m.free()


func _check_progress_snapshots() -> void:
	var m := ObjectiveManager.new()
	m.setup(ObjectiveManager.MVP_OBJECTIVES)
	m.complete(ObjectiveManager.ENTER_LIBRARY)
	m.complete(ObjectiveManager.REACH_RESTRICTED)
	var snapshot := m.get_progress()
	m.complete(ObjectiveManager.TAKE_CARD)
	m.complete(ObjectiveManager.REACH_EXIT)
	m.restore(snapshot)
	_expect(m.completed_count() == 2 and m.current() == ObjectiveManager.TAKE_CARD, "restore() should go back to the snapshot (card not yet taken).")
	snapshot[ObjectiveManager.ENTER_LIBRARY] = ObjectiveManager.State.ACTIVE  # tamper with the copy
	_expect(m.is_completed(ObjectiveManager.ENTER_LIBRARY), "A snapshot must be a copy, not live state.")
	# An invalid snapshot (a later objective done without the earlier ones) is rebuilt as a valid flow.
	m.restore({ObjectiveManager.TAKE_CARD: ObjectiveManager.State.COMPLETED})
	_expect(m.completed_count() == 0 and m.current() == ObjectiveManager.ENTER_LIBRARY, "An invalid snapshot must not skip objectives.")
	m.restore({})
	_expect(m.current() == ObjectiveManager.ENTER_LIBRARY, "An empty snapshot is the level start.")
	m.free()


# --- The library ------------------------------------------------------------------------

func _check_level_setup() -> void:
	_expect(_objectives != null and _checkpoints != null and _hud != null and _interactor != null,
		"The library needs an ObjectiveManager, CheckpointManager, ObjectiveHud and the player's Interactor.")
	_expect(_card != null and _door != null, "The library needs the access card and the exit door.")
	if _card == null or _door == null or _objectives == null:
		return
	var triggers := _level.find_children("*", "ObjectiveTrigger", true, false)
	var trigger_ids: Array = triggers.map(func(t): return t.objective_id)
	_expect(trigger_ids.size() == 3 and ObjectiveManager.ENTER_LIBRARY in trigger_ids and ObjectiveManager.REACH_RESTRICTED in trigger_ids and ObjectiveManager.REACH_EXIT in trigger_ids,
		"There should be triggers for entering, the restricted stacks and the exit area (got %s)." % [trigger_ids])
	var checkpoints := _level.find_children("*", "Checkpoint", true, false)
	_expect(checkpoints.size() >= 2, "The library should have at least two checkpoints (found %d)." % checkpoints.size())
	_expect(_objectives.current() == ObjectiveManager.ENTER_LIBRARY and _hud.get_current_text() == "Enter the library",
		"The level should start on 'Enter the library'.")
	var lines := _hud.get_lines()
	_expect(lines.size() == 5 and lines[0] == "[>] Enter the library" and lines[2] == "[ ] Take the access card",
		"The checklist should mark the current objective and locked ones (got %s)." % [lines])
	# Everything is on the navmesh and reachable in the order the player needs it.
	var map := _level.get_world_3d().navigation_map
	var route := [["the spawn", _player.global_position], ["the library trigger", _trigger("EnterLibraryTrigger").global_position],
		["the Hallway West checkpoint", _checkpoint("CheckpointHallwayWest").get_spawn_transform().origin],
		["the restricted stacks", IN_RESTRICTED], ["the card", AT_CARD],
		["the Staff Nook checkpoint", _checkpoint("CheckpointStaffNook").get_spawn_transform().origin],
		["the exit door", AT_DOOR]]
	var total := 0.0
	for i in range(1, route.size()):
		var from: Vector3 = route[i - 1][1]
		var to: Vector3 = route[i][1]
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		var end_gap := INF if path.is_empty() else Vector2(path[-1].x - to.x, path[-1].z - to.z).length()
		_expect(end_gap < 0.6, "No navigation path from %s to %s (ends %.2f m away)." % [route[i - 1][0], route[i][0], end_gap])
		for j in range(1, path.size()):
			total += path[j - 1].distance_to(path[j])
	var card_reach := Vector2(AT_CARD.x - _card.global_position.x, AT_CARD.z - _card.global_position.z).length()
	_expect(card_reach < 1.6, "The card should be within reach of walkable floor (%.2f m)." % card_reach)
	print("  [objectives] route spawn → library → checkpoint → stacks → card → checkpoint → exit door: %.0f m of navigable path" % total)


func _check_interaction() -> void:
	# Looking straight at the card from 1.3 m: focused, but the card can't be
	# taken yet because its objective is still LOCKED.
	await _stand_and_look(AT_CARD, _card.global_position)
	_expect(_interactor.focused == _card, "Looking at the card within reach should focus it.")
	_expect(_hud.get_prompt_text() == "[E] Access card (not yet)", "Prompt for a card that can't be taken yet, got '%s'." % _hud.get_prompt_text())
	_expect(not _interactor.try_interact() and not _card.is_taken() and _card.visible, "The card must not be taken before its objective is ACTIVE.")
	# Looking away.
	_player.rotate_y(PI)
	await _frames(2)
	_expect(_interactor.focused == null and _hud.get_prompt_text() == "", "Looking away should clear the focus and the prompt.")
	# Out of reach.
	await _stand_and_look(AT_CARD + Vector3(2.0, 0, 0), _card.global_position)
	_expect(_interactor.focused == null, "The card 3.3 m away should be out of reach.")
	# Behind something solid.
	var screen := _box(Vector3(0.1, 2.5, 1.5), (AT_CARD + _card.global_position) / 2.0 + Vector3(0, 0.6, 0))
	await _stand_and_look(AT_CARD, _card.global_position)
	_expect(_interactor.focused == null, "Something solid between the player and the card should block interaction.")
	screen.free()
	await _stand_and_look(AT_CARD, _card.global_position)
	_expect(_interactor.focused == _card, "With the obstacle gone the card should be focused again.")


func _check_exit_rejects_without_card() -> void:
	# Reaching the restricted stacks before entering the library counts for nothing...
	await _teleport(IN_RESTRICTED)
	_expect(_objectives.get_state(ObjectiveManager.REACH_RESTRICTED) == ObjectiveManager.State.LOCKED
		and _objectives.current() == ObjectiveManager.ENTER_LIBRARY, "A LOCKED 'reach' objective must not complete early.")
	# ...but if that objective becomes ACTIVE while the player is still inside, it completes.
	_objectives.complete(ObjectiveManager.ENTER_LIBRARY)
	await _frames(3)
	_expect(_objectives.is_completed(ObjectiveManager.REACH_RESTRICTED) and _objectives.current() == ObjectiveManager.TAKE_CARD,
		"An objective that becomes ACTIVE while the player is inside its trigger should complete.")
	# Straight to the exit without the card.
	var noise := NoiseSystem.find(_level)
	var noises_before := noise.emitted_count
	await _stand_and_look(AT_DOOR, _door.global_position + Vector3(0, 0.2, 0))
	_expect(_objectives.get_state(ObjectiveManager.REACH_EXIT) == ObjectiveManager.State.LOCKED, "Reaching the exit area without the card must not count yet.")
	_expect(_interactor.focused == _door and _hud.get_prompt_text() == "[E] Exit locked (access card needed)",
		"Looking at the locked door should say it needs the card (got '%s')." % _hud.get_prompt_text())
	_expect(not _interactor.try_interact(), "Using the exit without the card must fail.")
	_expect(_door.rejections == 1 and not _objectives.is_finished() and _director.status != S.ESCAPED,
		"The exit must reject the player and not finish the level.")
	_expect(_player.process_mode != Node.PROCESS_MODE_DISABLED, "A rejected player keeps control.")
	_expect(_hud.get_message_text() == "The exit is locked. You need the access card.", "HUD should explain the rejection, got '%s'." % _hud.get_message_text())
	_expect(noise.emitted_count == noises_before + 1, "Rattling the locked door should make a noise guards can hear.")
	_expect(_door._sign.text.begins_with("LOCKED"), "The door sign should say LOCKED.")
	_expect(_door.door_mesh != null and _door._door_material.albedo_color.r > _door._door_material.albedo_color.g, "The locked door should be red.")


func _check_card_and_escape() -> void:
	await _stand_and_look(AT_CARD, _card.global_position)
	_expect(_interactor.focused == _card and _hud.get_prompt_text() == "[E] Take the access card", "Prompt to take the card, got '%s'." % _hud.get_prompt_text())
	_expect(_interactor.try_interact(), "Taking the card should succeed once it's the current objective.")
	await _frames(2)
	_expect(_card.is_taken() and not _card.visible and not _card.enabled, "A taken card disappears and can't be used again.")
	_expect(_objectives.current() == ObjectiveManager.REACH_EXIT, "After the card, the objective should be to reach the exit.")
	_expect(_hud.get_message_text() == "Access card taken", "HUD should confirm the card, got '%s'." % _hud.get_message_text())
	_expect(_interactor.focused == null, "The taken card should no longer be focused.")
	await _stand_and_look(AT_DOOR, _door.global_position + Vector3(0, 0.2, 0))
	_expect(_objectives.is_completed(ObjectiveManager.REACH_EXIT) and _objectives.current() == ObjectiveManager.ESCAPE, "Entering the exit area with the card should complete 'Reach the exit'.")
	_expect(_door.is_unlocked() and _hud.get_prompt_text() == "[E] Escape", "The door should now offer escape, got '%s'." % _hud.get_prompt_text())
	await _frames(1)
	_expect(_door._sign.text.contains("UNLOCKED"), "The door sign should say UNLOCKED.")
	_expect(_door._door_material.albedo_color.g > _door._door_material.albedo_color.r, "The unlocked door should be green.")
	var escaped := {"count": 0}
	_door.escaped.connect(func(): escaped.count += 1)
	_expect(_interactor.try_interact(), "Using the door with the card should escape.")
	await _frames(3)
	_expect(_objectives.is_finished() and escaped.count == 1, "Escaping should complete the last objective.")
	_expect(_director.status == S.ESCAPED and _player.process_mode == Node.PROCESS_MODE_DISABLED,
		"Escaping should end the level and freeze the player.")
	var flow: GameFlow = _level.get_node("GameFlow")
	var menus: GameMenus = _level.get_node("GameMenus")
	_expect(flow.state == GameStateMachine.State.WIN and menus.win_panel.visible and menus.get_win_text().begins_with("Time"),
		"Escaping should switch the game to WIN and show the ESCAPED screen.")
	var at := _player.global_position
	await _frames(20)
	_expect(_player.global_position.distance_to(at) < 0.01 and _director.catches == 0, "Nothing happens after escaping.")
	print("  [objectives] flow: %s; exit rejected %d time(s) before the card, escaped after" % [
		" → ".join(_objectives.get_ids()), _door.rejections])


# --- Checkpoints --------------------------------------------------------------------------

func _check_checkpoint_keeps_progress_before_it() -> void:
	var nook := _checkpoint("CheckpointStaffNook")
	var hallway := _checkpoint("CheckpointHallwayWest")
	await _teleport(IN_MAIN_ROOM)
	_expect(_objectives.is_completed(ObjectiveManager.ENTER_LIBRARY) and _objectives.current() == ObjectiveManager.REACH_RESTRICTED,
		"Walking into the main room should complete 'Enter the library'.")
	await _teleport(IN_RESTRICTED)
	_expect(_objectives.current() == ObjectiveManager.TAKE_CARD, "Reaching the restricted stacks should complete that objective.")
	await _stand_and_look(AT_CARD, _card.global_position)
	_interactor.try_interact()
	await _teleport(nook.global_position + Vector3(0, -0.95, 0))
	_expect(_checkpoints.active == nook and nook.is_active and not hallway.is_active, "Walking onto the Staff Nook checkpoint should activate it.")
	_expect(_checkpoints.saved_progress.get(ObjectiveManager.TAKE_CARD) == ObjectiveManager.State.COMPLETED, "The checkpoint should store progress including the card.")
	_expect(_player.get_spawn_transform().origin.distance_to(nook.get_spawn_transform().origin) < 0.01, "The checkpoint should become the respawn location.")
	var activations := _checkpoints.activations
	await _teleport(nook.global_position + Vector3(0, -0.95, 0.3))
	_expect(_checkpoints.activations == activations, "Re-entering the same checkpoint with the same progress changes nothing.")
	# A guard catches the player in the back corridor.
	await _catch_player_at(Vector3(3, 0.05, -22.5), Vector3(0.5, 0, -22.5))
	_expect(_director.catches == 1, "The test guard should have caught the player.")
	_expect(_hud_caught_text().contains("Staff Nook"), "The caught screen should name the checkpoint, got '%s'." % _hud_caught_text())
	await _until(func(): return _director.status != S.CAUGHT, int(_director.reset_delay * Engine.physics_ticks_per_second) + 30)
	await _frames(5)
	var spawn := nook.get_spawn_transform()
	_expect(_player.global_position.distance_to(spawn.origin) < 0.3, "After being caught the player should respawn at the Staff Nook (%.2f m away)." % _player.global_position.distance_to(spawn.origin))
	_expect((-_player.global_basis.z).dot(-spawn.basis.z) > 0.99, "The player should face the checkpoint's spawn direction.")
	_expect(_objectives.is_completed(ObjectiveManager.TAKE_CARD) and _objectives.current() == ObjectiveManager.REACH_EXIT and _card.is_taken() and not _card.visible,
		"Progress from before the checkpoint (the card) should be kept.")
	_expect(_checkpoints.activations == activations, "Respawning onto the checkpoint must not count as a new activation.")
	_expect(_guard.machine.current == GuardStateMachine.PATROL and not _guard.vision.has_last_known_position, "The guard should be reset to patrol.")
	# No checkpoint activation during a chase.
	await _spawn_guard(Vector3(22.5, 0, -6), 0.0)
	await _teleport(Vector3(22.5, 0.05, -12))
	await _until(func(): return _director.status == S.CHASE, 400)
	_expect(_director.status == S.CHASE, "Standing in front of the guard should start a chase.")
	_expect(not _checkpoints.activate(hallway) and _checkpoints.active == nook, "A checkpoint must not activate during a chase.")
	print("  [objectives] card taken before the checkpoint: caught → respawned at %s with the card kept (%s)" % [
		_checkpoints.get_respawn_name(), _objectives.current()])


func _check_checkpoint_undoes_progress_after_it() -> void:
	var hallway := _checkpoint("CheckpointHallwayWest")
	await _teleport(IN_MAIN_ROOM)
	await _teleport(hallway.global_position + Vector3(0, -0.95, 0))
	_expect(_checkpoints.active == hallway, "Walking onto the Hallway West checkpoint should activate it.")
	await _teleport(IN_RESTRICTED)
	await _stand_and_look(AT_CARD, _card.global_position)
	_interactor.try_interact()
	_expect(_card.is_taken(), "Card taken after the checkpoint.")
	# Caught inside the restricted-stacks trigger: after respawning, that
	# objective must stay ACTIVE (a stale "entered" there must not complete it).
	await _catch_player_at(Vector3(-9, 0.05, -19), Vector3(-6, 0, -19))
	await _until(func(): return _director.status != S.CAUGHT, int(_director.reset_delay * Engine.physics_ticks_per_second) + 30)
	await _frames(5)
	_expect(_player.global_position.distance_to(hallway.get_spawn_transform().origin) < 0.3, "The player should respawn at Hallway West.")
	_expect(_objectives.is_completed(ObjectiveManager.ENTER_LIBRARY) and _objectives.current() == ObjectiveManager.REACH_RESTRICTED,
		"Progress made after the checkpoint should be undone (current: %s)." % _objectives.current())
	_expect(not _card.is_taken() and _card.visible and _card.enabled, "The card taken after the checkpoint should be back on the desk.")
	# The flow can be finished again from here.
	await _teleport(IN_RESTRICTED)
	await _stand_and_look(AT_CARD, _card.global_position)
	_expect(_interactor.try_interact() and _objectives.current() == ObjectiveManager.REACH_EXIT, "The card can be taken again after respawning.")
	print("  [objectives] card taken after the checkpoint: caught in the stacks → respawned at %s, card back on the desk, then retaken" % _checkpoints.get_respawn_name())


func _check_guards_reset_on_respawn() -> void:
	var guards: Array[Guard] = []
	for node in _level.find_children("*", "Guard", true, false):
		guards.append(node)
	var main: Guard = _level.get_node("Guards/GuardMain")
	_expect(guards.size() == 3 and main != null, "The library should have its three guards.")
	if main == null:
		return
	# Let the patrols move away from their starts, then step into GuardMain's
	# view: 3 m in front of it, on walkable floor with a clear line of sight.
	Engine.time_scale = 4.0
	await _frames(240)
	var map := _level.get_world_3d().navigation_map
	var space := _level.get_world_3d().direct_space_state
	var spot := Vector3.INF
	for attempt in 40:
		var candidate := main.global_position - main.global_basis.z * 3.0
		var snapped := NavigationServer3D.map_get_closest_point(map, candidate)
		var eye := main.global_position + Vector3(0, 1.6, 0)
		var clear := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, candidate + Vector3(0, 1.2, 0), 1)).is_empty()
		if clear and Vector2(snapped.x - candidate.x, snapped.z - candidate.z).length() < 0.2:
			spot = candidate
			break
		await _frames(15)
	Engine.time_scale = 1.0
	_expect(spot != Vector3.INF, "Could not find a clear spot in front of GuardMain.")
	if spot == Vector3.INF:
		return
	await _teleport(spot + Vector3(0, 0.05, 0))
	await _until(func(): return _director.status == S.CAUGHT, 600)
	_expect(_director.status == S.CAUGHT, "A guard should catch a player standing 3 m in front of GuardMain.")
	await _until(func(): return _director.status != S.CAUGHT, int(_director.reset_delay * Engine.physics_ticks_per_second) + 30)
	await _frames(2)
	for guard in guards:
		var start: Vector3 = guard._start_transform.origin
		var moved := Vector2(guard.global_position.x - start.x, guard.global_position.z - start.z).length()
		_expect(moved < 0.5, "%s should be back at its start after the respawn (%.2f m away)." % [guard.name, moved])
		_expect(guard.machine.current == GuardStateMachine.PATROL and guard.vision.detection == 0.0
			and not guard.vision.has_last_known_position and not guard.hearing.has_report,
			"%s should be patrolling with a clear memory after the respawn." % guard.name)
	print("  [objectives] respawn reset all %d guards to their starts on patrol" % guards.size())


## No guard may notice a player standing on a checkpoint's respawn point during
## a full patrol loop of every guard (the longest loop takes about 36 s), so
## respawning is never an instant re-catch.
func _check_checkpoints_are_safe() -> void:
	var guards: Array[Guard] = []
	for node in _level.find_children("*", "Guard", true, false):
		guards.append(node)
	for cp in _level.find_children("*", "Checkpoint", true, false):
		_director.reset_level()
		_player.set_spawn_transform(cp.get_spawn_transform())
		_player.respawn()
		await _frames(3)
		Engine.time_scale = 6.0
		var noticed := ""
		var t := 0.0
		while t < 45.0 and noticed == "":
			await _host.get_tree().physics_frame
			t += Engine.time_scale / Engine.physics_ticks_per_second
			for guard in guards:
				if guard.vision.can_see_target or guard.vision.detection > 0.0:
					noticed = guard.name
		Engine.time_scale = 1.0
		_expect(noticed == "", "%s noticed the player standing at the %s checkpoint." % [noticed, cp.checkpoint_name])
		print("  [objectives] %s checkpoint: unseen by every guard for %.0f s of patrol" % [cp.checkpoint_name, t])


# --- Helpers --------------------------------------------------------------------------------

func _load_level(keep_guards: bool) -> void:
	_unload()
	await _frames(2)
	_level = (load(LIBRARY_SCENE) as PackedScene).instantiate()
	if not keep_guards:
		var guards := _level.get_node("Guards")
		_level.remove_child(guards)
		guards.free()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, Vector3(0, 0, 18)), "Library navigation never became ready.")
	await _frames(2)
	_player = _level.get_node("Player")
	_interactor = _player.get_node_or_null("Interactor")
	_objectives = _level.get_node_or_null("Gameplay/ObjectiveManager")
	_checkpoints = _level.get_node_or_null("Gameplay/CheckpointManager")
	_card = _level.get_node_or_null("Gameplay/AccessCard")
	_door = _level.get_node_or_null("Gameplay/ExitDoor")
	_director = _level.get_node("StealthDirector")
	_hud = _level.get_node_or_null("ObjectiveHud")
	_guard = null
	_route = null


func _unload() -> void:
	Engine.time_scale = 1.0
	if _level and is_instance_valid(_level):
		_level.queue_free()
	_level = null


func _trigger(name: String) -> ObjectiveTrigger:
	return _level.get_node("Gameplay/" + name)


func _checkpoint(name: String) -> Checkpoint:
	return _level.get_node("Gameplay/" + name)


func _teleport(at: Vector3) -> void:
	_player.global_position = at
	_player.velocity = Vector3.ZERO
	await _frames(4)


## Stands at `at` looking at `target` (body turned, head pitched).
func _stand_and_look(at: Vector3, target: Vector3) -> void:
	_player.global_position = at
	_player.velocity = Vector3.ZERO
	_player.look_at(Vector3(target.x, at.y, target.z), Vector3.UP)
	_player.rotation.x = 0
	_player.rotation.z = 0
	var eye := at.y + _player.stand_eye_height
	var flat := Vector2(target.x - at.x, target.z - at.z).length()
	_player.head.rotation.x = atan2(target.y - eye, flat)
	await _frames(4)


## Puts a test guard at `guard_at` facing the player at `at`, and waits for the catch.
func _catch_player_at(at: Vector3, guard_at: Vector3) -> void:
	var to_player := Vector2(at.x - guard_at.x, at.z - guard_at.z)
	await _spawn_guard(guard_at, atan2(-to_player.x, -to_player.y))
	await _teleport(at)
	await _until(func(): return _director.status == S.CAUGHT, 600)
	_expect(_director.status == S.CAUGHT, "The test guard should catch the player.")


func _spawn_guard(at: Vector3, yaw: float) -> void:
	if _guard and is_instance_valid(_guard):
		_guard.free()
	if _route and is_instance_valid(_route):
		_route.free()
	_route = PatrolRoute.new()
	var post := PatrolPoint.new()
	post.position = at
	post.wait_time = 300.0
	_route.add_child(post)
	_level.add_child(_route)
	_guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	_guard.name = "ObjectiveTestGuard"
	_guard.patrol_route = _route
	_guard.position = at + Vector3(0, 0.05, 0)
	_guard.rotation.y = yaw
	_level.add_child(_guard)
	await _frames(3)


func _hud_caught_text() -> String:
	var hud: StealthHud = _level.get_node("StealthHud")
	return hud.get_caught_text()


func _box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	body.position = at
	_level.add_child(body)
	return body


func _until(done: Callable, max_frames: int) -> void:
	for i in max_frames:
		if done.call():
			return
		await _host.get_tree().physics_frame


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
