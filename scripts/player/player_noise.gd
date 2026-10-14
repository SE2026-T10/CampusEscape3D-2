class_name PlayerNoise
extends Node

## Footstep noise for the player. Every stride on the floor emits a noise
## through the level's NoiseSystem: a loud RUN when sprinting, a WALK when
## walking, a very quiet WALK (small radius) when crouch-walking, and nothing
## while standing still or in the air.

## Metres between footsteps when walking and when running.
@export var walk_stride := 0.8
@export var run_stride := 1.2
## Crouch-walking footsteps: stride, radius and intensity (a muffled WALK).
@export var crouch_stride := 0.9
@export var crouch_radius := 2.0
@export var crouch_intensity := 0.2
## Horizontal speed above which steps count as running (between walk 3.5 and sprint 5.5).
@export var run_speed_threshold := 4.5
## Below this speed no footsteps are made.
@export var min_speed := 0.5

## Emitted for every footstep, for sound and camera feedback: &"crouch", &"walk" or &"run".
signal footstep(kind: StringName)

var steps_emitted := 0
var _distance := 0.0
var _last_position := Vector3.INF
var _player: CharacterBody3D


func _ready() -> void:
	_player = get_parent() as CharacterBody3D


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var position := _player.global_position
	if _last_position == Vector3.INF:
		_last_position = position
		return
	var moved := Vector2(position.x - _last_position.x, position.z - _last_position.z).length()
	_last_position = position
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	# Teleports (big jumps with no velocity) and standing still make no noise.
	if not _player.is_on_floor() or speed < min_speed or moved > 2.0:
		return
	var crouching: bool = _player.get("is_crouching") == true
	var running := speed > run_speed_threshold and not crouching
	var stride := crouch_stride if crouching else (run_stride if running else walk_stride)
	_distance += moved
	if _distance >= stride:
		_distance = 0.0
		footstep.emit(&"crouch" if crouching else (&"run" if running else &"walk"))
		var system := NoiseSystem.find(_player)
		if system == null:
			return
		if crouching:
			system.emit_noise(position, NoiseEvent.Type.WALK, "player", crouch_intensity, crouch_radius)
		else:
			system.emit_noise(position, NoiseEvent.Type.RUN if running else NoiseEvent.Type.WALK, "player")
		steps_emitted += 1
