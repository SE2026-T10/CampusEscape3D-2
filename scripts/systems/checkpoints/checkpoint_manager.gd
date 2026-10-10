class_name CheckpointManager
extends Node

## Remembers the last activated checkpoint and puts the player back there.
##
## Activating a checkpoint stores:
##   - the respawn location (the checkpoint's spawn transform, given to the player)
##   - a snapshot of objective progress at that moment
##   - a snapshot of the mission state of every node in the "checkpoint_state"
##     group (get_checkpoint_state() / restore_checkpoint_state(), e.g. which
##     access doors are open), keyed by node path
## Before any checkpoint, the level start (the player's own spawn) and the
## starting progress are used.
##
## When the player is caught, StealthDirector resets the level (player to the
## respawn location, guards back to their starts on patrol with clear memory)
## and emits level_reset. This then restores the stored mission state and then
## the objective progress, so progress made since the checkpoint is undone. For
## example, an access card taken after the last checkpoint goes back on its
## desk, and a door opened since then is closed again. Items follow their
## objective (shown while it is not completed), so an item and its objective
## can never disagree after a restore.
##
## Checkpoints do not activate during a chase, after being caught, or after
## escaping, so a checkpoint can't be used to save a lost situation.

signal checkpoint_activated(checkpoint: Checkpoint)
## The player was put back at the checkpoint (null = the level start).
signal respawned(checkpoint: Checkpoint)

## The active checkpoint, or null for the level start.
var active: Checkpoint = null
## Objective progress stored at the last activation (ObjectiveManager.get_progress()).
var saved_progress := {}
## Mission state stored at the last activation: node path -> that node's get_checkpoint_state().
var saved_state := {}
## Number of activations (for tests and the HUD).
var activations := 0


func _ready() -> void:
	add_to_group("checkpoint_manager")
	_connect.call_deferred()


static func find(node: Node) -> CheckpointManager:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("checkpoint_manager") as CheckpointManager


func _connect() -> void:
	var objectives := ObjectiveManager.find(self)
	if objectives:
		saved_progress = objectives.get_progress()
	saved_state = get_mission_state()
	var director := StealthDirector.find(self)
	if director and not director.level_reset.is_connected(restore_checkpoint):
		director.level_reset.connect(restore_checkpoint)


## Makes `checkpoint` the respawn point and stores the current objective
## progress. Returns false if nothing changed (same checkpoint and progress)
## or activation isn't allowed right now.
func activate(checkpoint: Checkpoint) -> bool:
	if not can_activate():
		return false
	var objectives := ObjectiveManager.find(self)
	var progress := objectives.get_progress() if objectives else {}
	var state := get_mission_state()
	if checkpoint == active and progress == saved_progress and state == saved_state:
		return false
	if active and active != checkpoint and is_instance_valid(active):
		active.set_active(false)
	active = checkpoint
	checkpoint.set_active(true)
	saved_progress = progress
	saved_state = state
	activations += 1
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_spawn_transform"):
		player.set_spawn_transform(checkpoint.get_spawn_transform())
	checkpoint_activated.emit(checkpoint)
	return true


## False while a guard is chasing, after being caught and after escaping.
func can_activate() -> bool:
	var director := StealthDirector.find(self)
	if director == null:
		return true
	return director.status not in [StealthDirector.Status.CHASE, StealthDirector.Status.CAUGHT,
		StealthDirector.Status.ESCAPED]


## Puts the mission state and objective progress back to the stored snapshot.
## Called on level_reset, after the player and guards have been reset.
func restore_checkpoint() -> void:
	# Mission state first: restoring never completes objectives, and objective
	# changes made by the restore (deferred reactions included) then see the
	# restored state.
	for node in get_tree().get_nodes_in_group("checkpoint_state"):
		var key := String(get_path_to(node))
		if node.has_method("restore_checkpoint_state") and saved_state.has(key):
			node.restore_checkpoint_state(saved_state[key])
	var objectives := ObjectiveManager.find(self)
	if objectives:
		objectives.restore(saved_progress)
	respawned.emit(active)


## The current mission state of every "checkpoint_state" node, keyed by node path.
func get_mission_state() -> Dictionary:
	var state := {}
	for node in get_tree().get_nodes_in_group("checkpoint_state"):
		if node.has_method("get_checkpoint_state"):
			state[String(get_path_to(node))] = node.get_checkpoint_state()
	return state


## Where the player will respawn, for the HUD.
func get_respawn_name() -> String:
	return active.checkpoint_name if active and is_instance_valid(active) else "the entrance"
