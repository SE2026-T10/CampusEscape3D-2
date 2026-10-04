class_name PlayerNoise
extends Node

## Footstep noise for the player. Every stride on the floor emits a noise
## through the level's NoiseSystem: a quiet WALK when walking, a loud RUN when
## sprinting, nothing while standing still or in the air.

## Metres between footsteps when walking and when running.
@export var walk_stride := 0.8
@export var run_stride := 1.2
## Horizontal speed above which steps count as running (between walk 3.5 and sprint 5.5).
@export var run_speed_threshold := 4.5
## Below this speed no footsteps are made.
@export var min_speed := 0.5

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
	var running := speed > run_speed_threshold
	_distance += moved
	if _distance >= (run_stride if running else walk_stride):
		_distance = 0.0
		var system := NoiseSystem.find(_player)
		if system:
			system.emit_noise(position, NoiseEvent.Type.RUN if running else NoiseEvent.Type.WALK, "player")
			steps_emitted += 1
