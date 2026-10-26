class_name ObjectiveTrigger
extends Area3D

## Completes an objective when the player is inside this area while that
## objective is ACTIVE ("reach X" objectives). Being there earlier, while the
## objective is still LOCKED, does nothing; if the objective becomes ACTIVE
## while the player is already inside, it completes then.
##
## The test is geometric (AreaUtils), checked every physics frame, and not
## body_entered. A stale "entered" reported after a respawn would otherwise
## complete an objective that a checkpoint had just restored.

@export var objective_id: StringName
## How far outside the box the player's centre may be and still count (the player's radius).
@export var player_radius := 0.35


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false


func _physics_process(_delta: float) -> void:
	var manager := ObjectiveManager.find(self)
	if manager and manager.get_state(objective_id) == ObjectiveManager.State.ACTIVE and contains_player():
		manager.complete(objective_id)


## True if the player is inside this trigger's box shapes right now.
func contains_player() -> bool:
	return AreaUtils.contains_player(self, player_radius)
