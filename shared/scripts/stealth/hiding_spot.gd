class_name HidingSpot
extends Area3D

## Marks the inside of a hiding place (e.g. a study carrel). It grants no
## invisibility: the carrel's partitions block guards' line of sight on their
## own. This area only tells the HUD and StealthDirector that the player is
## tucked into cover, so "HIDDEN" can be shown when, in addition, no guard
## currently sees the player and they are crouched.

## Expanded security (expansion Phase 5; used only by guards with
## expanded_security): whether the player came in while no guard saw them and
## none was chasing. Only then does the spot hide them (see conceals_from()).
var entered_unseen := false

var _player_inside := false


func _ready() -> void:
	add_to_group("hiding_spots")
	collision_layer = 0
	collision_mask = 2  # player
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(func(body): if body.is_in_group("player"): _player_inside = false)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		entered_unseen = not _player_observed()


func contains_player() -> bool:
	return _player_inside


## True while the player is inside, crouched, and came in unseen.
func is_concealing() -> bool:
	if not (_player_inside and entered_unseen):
		return false
	var player := get_tree().get_first_node_in_group("player")
	return player != null and player.get("is_crouching") == true


## True if the spot hides the player from `guard`: concealing, and the guard is
## not standing right at the spot (a guard checking the spot finds them).
func conceals_from(guard: Node3D) -> bool:
	if not is_concealing():
		return false
	var reach: float = guard.get("hiding_check_reach") if guard.get("hiding_check_reach") != null else 1.6
	return Vector2(guard.global_position.x - global_position.x, guard.global_position.z - global_position.z).length() > reach


## A guard sees the player or is chasing them right now.
func _player_observed() -> bool:
	for guard in get_tree().get_nodes_in_group("guards"):
		if guard.vision and guard.vision.can_see_target:
			return true
		if guard.machine and guard.machine.current == GuardStateMachine.CHASE:
			return true
	return false

