class_name FirstPersonPlayer
extends CharacterBody3D

## Grounded first-person controller: walk, sprint, mouse look and gravity.
##
## There is deliberately no jump. The library has no vertical routes, and
## jumping onto shelves or tables would let the player skip stealth sections
## or climb out of the level.

@export_group("Movement")
## Walking speed in metres per second.
@export var walk_speed := 3.5
## Sprinting speed in metres per second. Sprinting will be noisy once hearing exists.
@export var sprint_speed := 5.5
## How quickly the player reaches the target speed (m/s²).
@export var acceleration := 20.0
## How quickly the player stops after input is released (m/s²).
@export var deceleration := 25.0

@export_group("Look")
## Radians of rotation per pixel of mouse movement.
@export var mouse_sensitivity := 0.0025
## Highest angle the camera can look up or down.
@export_range(10.0, 89.0) var max_pitch_degrees := 85.0

@export_group("Safety")
## If the player ever drops below this height they are returned to their spawn point.
@export var fall_limit_y := -10.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _spawn_transform: Transform3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	_spawn_transform = global_transform
	capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		release_mouse()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not is_mouse_captured():
		# Clicking the game window takes control again after Escape.
		capture_mouse()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_mouse_captured():
		apply_look(event.screen_relative * mouse_sensitivity)


func _physics_process(delta: float) -> void:
	if global_position.y < fall_limit_y:
		respawn()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var target := get_target_velocity(input_dir, Input.is_action_pressed("sprint"))
	var horizontal := calculate_horizontal_velocity(Vector3(velocity.x, 0.0, velocity.z), target, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()


## Converts 2D input (x = right, y = back) into a horizontal world velocity
## relative to where the player is facing.
func get_target_velocity(input_dir: Vector2, sprinting: bool) -> Vector3:
	var direction := global_basis * Vector3(input_dir.x, 0.0, input_dir.y)
	direction.y = 0.0
	# limit_length keeps analog input proportional but stops diagonals being faster.
	direction = direction.limit_length(1.0)
	var speed := sprint_speed if sprinting else walk_speed
	return direction * speed


## Moves the current horizontal velocity toward the target at a fixed rate,
## using the slower deceleration rate when there is no input.
func calculate_horizontal_velocity(current: Vector3, target: Vector3, delta: float) -> Vector3:
	var rate := acceleration if target.length_squared() > 0.0 else deceleration
	return current.move_toward(target, rate * delta)


## Turns the body left/right and tilts the head up/down. Values are in radians.
func apply_look(look_delta: Vector2) -> void:
	rotate_y(-look_delta.x)
	var limit := deg_to_rad(max_pitch_degrees)
	head.rotation.x = clampf(head.rotation.x - look_delta.y, -limit, limit)


func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	head.rotation = Vector3.ZERO


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
