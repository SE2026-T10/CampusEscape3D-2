class_name HidingSpot
extends Area3D

## Marks the inside of a hiding place (e.g. a study carrel). It grants no
## invisibility: the carrel's partitions block guards' line of sight on their
## own. This area only tells the HUD and StealthDirector that the player is
## tucked into cover, so "HIDDEN" can be shown when, in addition, no guard
## currently sees the player and they are crouched.

var _player_inside := false


func _ready() -> void:
	add_to_group("hiding_spots")
	collision_layer = 0
	collision_mask = 2  # player
	monitoring = true
	body_entered.connect(func(body): if body.is_in_group("player"): _player_inside = true)
	body_exited.connect(func(body): if body.is_in_group("player"): _player_inside = false)


func contains_player() -> bool:
	return _player_inside
