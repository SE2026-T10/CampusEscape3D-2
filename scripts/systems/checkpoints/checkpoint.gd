class_name Checkpoint
extends Area3D

## A checkpoint the player activates by walking onto it (checked geometrically
## every physics frame with AreaUtils, not body_entered). The optional child
## Marker3D "Spawn" is where (and which way facing) the player respawns; without
## it, the checkpoint's own transform is used. The optional "Pad" mesh and
## "Label" show whether this is the active checkpoint.
## CheckpointManager decides what activating means (see there).

const COLOUR_INACTIVE := Color(0.45, 0.5, 0.55)
const COLOUR_ACTIVE := Color(0.25, 0.95, 0.5)

## Name shown in the HUD, e.g. "Hallway West".
@export var checkpoint_name := "Checkpoint"

var is_active := false

var _material: StandardMaterial3D

@onready var _spawn: Node3D = get_node_or_null("Spawn")
@onready var _pad: MeshInstance3D = get_node_or_null("Pad")
@onready var _label: Label3D = get_node_or_null("Label")


func _ready() -> void:
	add_to_group("checkpoints")
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	if _pad:
		_material = StandardMaterial3D.new()
		_material.emission_enabled = true
		_pad.material_override = _material
	_update_visual()


func get_spawn_transform() -> Transform3D:
	return _spawn.global_transform if _spawn else global_transform


func set_active(active: bool) -> void:
	is_active = active
	_update_visual()


func _physics_process(_delta: float) -> void:
	if contains_player():
		var manager := CheckpointManager.find(self)
		if manager:
			manager.activate(self)


func contains_player() -> bool:
	return AreaUtils.contains_player(self)


func _update_visual() -> void:
	var colour := COLOUR_ACTIVE if is_active else COLOUR_INACTIVE
	if _material:
		_material.albedo_color = colour
		_material.emission = colour
		_material.emission_energy_multiplier = 1.2 if is_active else 0.15
	if _label:
		_label.text = "CHECKPOINT · ACTIVE" if is_active else "CHECKPOINT"
		_label.modulate = colour
