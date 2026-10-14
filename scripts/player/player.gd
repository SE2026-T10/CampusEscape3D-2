class_name FirstPersonPlayer
extends CharacterBody3D

## Grounded first-person controller: walk, sprint, crouch, mouse look and gravity.
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

@export_group("Crouch")
## Speed while crouched. Sprinting is not possible while crouched.
@export var crouch_speed := 1.8
## Body height standing and crouched, in metres.
@export var stand_height := 1.8
@export var crouch_height := 1.0
## Eye height standing and crouched.
@export var stand_eye_height := 1.6
@export var crouch_eye_height := 0.95
## How quickly the camera moves between standing and crouched eye height.
@export var crouch_camera_speed := 10.0
## Guards' detection meters fill this much slower while the player is crouched (multiplier).
@export_range(0.0, 1.0) var crouch_visibility := 0.5

@export_group("Look")
## Radians of rotation per pixel of mouse movement.
@export var mouse_sensitivity := 0.0025
## Highest angle the camera can look up or down.
@export_range(10.0, 89.0) var max_pitch_degrees := 85.0

@export_group("Safety")
## If the player ever drops below this height they are returned to their spawn point.
@export var fall_limit_y := -10.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## True while crouched (holding the crouch action, or held down by something overhead).
var is_crouching := false

var _spawn_transform: Transform3D
var _capsule: CapsuleShape3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("player")  # NPC perception looks for this group.
	_spawn_transform = global_transform
	# Own copy of the capsule so crouching never changes a shared resource.
	_capsule = (_collision.shape as CapsuleShape3D).duplicate()
	_collision.shape = _capsule
	# The mouse is captured by GameFlow when play starts (and released for menus).


func _unhandled_input(event: InputEvent) -> void:
	# Escape is the pause action, handled by GameFlow. While playing, a click
	# takes the mouse back if it was freed some other way (e.g. by the OS).
	if event is InputEventMouseButton and event.pressed and not is_mouse_captured():
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

	_update_crouch(delta)
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
	var speed := walk_speed
	if is_crouching:
		speed = crouch_speed
	elif sprinting:
		speed = sprint_speed
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


## Where respawn() puts the player: the level start until a checkpoint sets a new one.
func set_spawn_transform(spawn: Transform3D) -> void:
	_spawn_transform = spawn


func get_spawn_transform() -> Transform3D:
	return _spawn_transform


func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	head.rotation = Vector3.ZERO
	set_crouching(false)
	head.position.y = stand_eye_height


## Crouches or stands up. Standing up is refused if something is overhead.
func set_crouching(crouch: bool) -> void:
	if crouch == is_crouching:
		return
	if not crouch and not _can_stand():
		return
	is_crouching = crouch
	var height := crouch_height if crouch else stand_height
	_capsule.height = height
	_collision.position.y = height / 2.0


func _update_crouch(delta: float) -> void:
	set_crouching(Input.is_action_pressed("crouch"))
	var eye := crouch_eye_height if is_crouching else stand_eye_height
	head.position.y = move_toward(head.position.y, eye, crouch_camera_speed * delta)


func _can_stand() -> bool:
	var from := global_position + Vector3(0, crouch_height, 0)
	var to := global_position + Vector3(0, stand_height + 0.05, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Current body height in metres.
func get_body_height() -> float:
	return crouch_height if is_crouching else stand_height


## World points NPC vision aims at: head, chest and knees for the current stance.
func get_visibility_points() -> PackedVector3Array:
	var h := get_body_height()
	return PackedVector3Array([global_position + Vector3(0, h * 0.85, 0),
		global_position + Vector3(0, h * 0.5, 0), global_position + Vector3(0, h * 0.17, 0)])


## Multiplier for how fast guards notice the player (1 standing, crouch_visibility crouched).
func get_visibility_factor() -> float:
	return crouch_visibility if is_crouching else 1.0


## How much noise the current movement makes, for the HUD: "SILENT", "QUIET", "NORMAL" or "LOUD".
## Matches PlayerNoise: crouch-walking 2 m, walking 5 m, sprinting 12 m.
func get_noise_level() -> String:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.5 or not is_on_floor():
		return "SILENT"
	if is_crouching:
		return "QUIET"
	return "LOUD" if speed > 4.5 else "NORMAL"


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
