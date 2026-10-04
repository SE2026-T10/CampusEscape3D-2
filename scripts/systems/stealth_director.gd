class_name StealthDirector
extends Node

## Ties the stealth loop together for the player:
##   - works out one player-facing status from all guards (for the HUD)
##   - catches the player when a chasing guard reaches them in sight
##   - after a short pause, resets the level: player back to their spawn point,
##     every guard back to its start in PATROL with a clear memory
##   - freezes everything when the level is finished (the player escaped)
## Where the player respawns, and what objective progress survives, is up to
## CheckpointManager (it gives the player its spawn point and listens to level_reset).

signal status_changed(previous: Status, current: Status)
signal player_caught(by: Guard)
signal level_reset

## Player-facing situation, most urgent last. ESCAPED: the level is finished.
enum Status { NONE, HIDDEN, INVESTIGATING, SPOTTED, CHASE, CAUGHT, ESCAPED }

## A chasing guard this close (metres, horizontal) with the player in sight catches them.
@export var catch_distance := 1.2
## Seconds the "caught" screen shows before the level resets.
@export var reset_delay := 2.5

var status: Status = Status.NONE
## Number of times the player has been caught (for tests and the HUD).
var catches := 0

var _reset_left := 0.0


func _ready() -> void:
	add_to_group("stealth_director")


static func find(node: Node) -> StealthDirector:
	return node.get_tree().get_first_node_in_group("stealth_director") as StealthDirector if node.is_inside_tree() else null


func _physics_process(delta: float) -> void:
	if status == Status.ESCAPED:
		return
	if status == Status.CAUGHT:
		_reset_left -= delta
		if _reset_left <= 0.0:
			reset_level()
		return
	var player := _player()
	if player == null:
		return
	var guards := _guards()
	for guard in guards:
		if is_catching(guard, player):
			_catch(guard)
			return
	_set_status(status_from(gather_flags(player, guards)))


## Facts about the current situation, from what the guards actually perceive.
func gather_flags(player: Node3D, guards: Array[Guard]) -> Dictionary:
	var flags := {"chase": false, "seen": false, "investigating": false, "hidden": false}
	for guard in guards:
		if guard.machine == null:
			continue
		match guard.machine.current:
			GuardStateMachine.CHASE:
				flags.chase = true
			GuardStateMachine.INVESTIGATE:
				flags.investigating = true
		if guard.vision and guard.vision.can_see_target:
			flags.seen = true
	var crouched: bool = player.get("is_crouching") == true
	flags.hidden = crouched and not flags.seen and _in_hiding_spot()
	return flags


## Status for a set of facts. Pure function, in priority order:
## CHASE > SPOTTED (a guard sees you) > INVESTIGATING > HIDDEN > NONE.
static func status_from(flags: Dictionary) -> Status:
	if flags.get("chase", false):
		return Status.CHASE
	if flags.get("seen", false):
		return Status.SPOTTED
	if flags.get("investigating", false):
		return Status.INVESTIGATING
	if flags.get("hidden", false):
		return Status.HIDDEN
	return Status.NONE


## A guard catches the player only while chasing, seeing them, and within catch_distance.
func is_catching(guard: Guard, player: Node3D) -> bool:
	if guard.machine == null or guard.machine.current != GuardStateMachine.CHASE:
		return false
	if guard.vision == null or not guard.vision.can_see_target:
		return false
	var d := Vector2(guard.global_position.x - player.global_position.x, guard.global_position.z - player.global_position.z)
	return d.length() <= catch_distance


## Puts the player back at their spawn point (the last checkpoint) and every
## guard back at its start on patrol with a clear memory.
func reset_level() -> void:
	# Move everyone first, then switch processing back on, so their bodies
	# rejoin the physics world at the new positions (not where they were caught,
	# which would briefly re-enter areas there, such as objective triggers).
	var player := _player()
	if player:
		if player.has_method("respawn"):
			player.respawn()
		player.process_mode = Node.PROCESS_MODE_INHERIT
	for guard in _guards():
		guard.reset_to_start()
		guard.process_mode = Node.PROCESS_MODE_INHERIT
	_set_status(Status.NONE)
	level_reset.emit()


## Ends the level after a successful escape: freezes the player and the guards.
func finish_level() -> void:
	_freeze_actors()
	_set_status(Status.ESCAPED)


func _catch(guard: Guard) -> void:
	catches += 1
	_reset_left = reset_delay
	# Freeze the scene's actors while the "caught" screen shows.
	_freeze_actors()
	_set_status(Status.CAUGHT)
	player_caught.emit(guard)


func _freeze_actors() -> void:
	var player := _player()
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	for g in _guards():
		g.process_mode = Node.PROCESS_MODE_DISABLED


func _set_status(value: Status) -> void:
	if value == status:
		return
	var previous := status
	status = value
	status_changed.emit(previous, value)


func _in_hiding_spot() -> bool:
	for spot in get_tree().get_nodes_in_group("hiding_spots"):
		if spot.contains_player():
			return true
	return false


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _guards() -> Array[Guard]:
	var guards: Array[Guard] = []
	for node in get_tree().get_nodes_in_group("guards"):
		guards.append(node)
	return guards
