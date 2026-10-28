extends FirstPersonPlayer
## K17-only grip mode. The common controller still owns move_and_slide/gravity.
var projection_rig: CharacterBody3D

func _enter_tree() -> void:
	# Set child policies before their _ready; edits to children of an instanced
	# shared scene are not implicitly serialized by the map's PackedScene.
	get_node("Interactor").set_script(preload("res://maps/intelligence/scripts/projection_interactor.gd"))
	get_node("Inventory").set_script(preload("res://maps/intelligence/scripts/inventory.gd"))

func get_target_velocity(input_dir: Vector2,sprinting: bool) -> Vector3:
	if is_instance_valid(projection_rig):
		return projection_rig.drive(input_dir,get_physics_process_delta_time())
	return super(input_dir,sprinting)

func calculate_horizontal_velocity(current: Vector3,target: Vector3,delta: float) -> Vector3:
	if is_instance_valid(projection_rig): return target
	return super(current,target,delta)

func respawn() -> void:
	if is_instance_valid(projection_rig): projection_rig.release_grip()
	super()
