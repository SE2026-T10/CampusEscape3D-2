class_name PlayerFeedback
extends Node

## Presentation for the first-person player (a child of Player named "Feedback"):
##   - footstep sounds on every stride PlayerNoise reports: quiet and soft when
##     crouch-walking, louder and brighter when sprinting
##   - head bob: the camera sways a little while moving, more when sprinting,
##     less when crouched, and settles back to rest when standing still
##   - sprint FOV: the view widens slightly while sprinting
##   - a soft tick when the interaction prompt appears on something new
## Only the Camera3D's local position and FOV are touched; movement, noise,
## the head (crouch height) and the body are left alone.

const BASE_FOV := 75.0
const SPRINT_FOV := 80.0
## Bob height / sideways sway in metres, per movement kind.
const BOB := {&"crouch": Vector2(0.012, 0.008), &"walk": Vector2(0.025, 0.014), &"run": Vector2(0.04, 0.02)}
## Footstep volume (dB) and base pitch per movement kind.
const STEP_VOLUME := {&"crouch": -20.0, &"walk": -11.0, &"run": -5.0}
const STEP_PITCH := {&"crouch": 0.85, &"walk": 1.0, &"run": 1.08}

@export var head_bob_enabled := true

## Footstep sounds played so far (for tests).
var steps_played := 0
## Last movement kind seen: &"idle", &"crouch", &"walk" or &"run".
var movement := &"idle"

var _player: FirstPersonPlayer
var _camera: Camera3D
var _steps: AudioStreamPlayer3D
var _phase := 0.0
var _bob_amount := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_player = get_parent() as FirstPersonPlayer
	if _player == null:
		return
	# The player's own @onready variables aren't set yet (children are ready first).
	_camera = _player.get_node("Head/Camera3D")
	_steps = AudioStreamPlayer3D.new()
	_steps.name = "Footsteps"
	_steps.bus = &"SFX"
	_steps.position = Vector3(0, 0.05, 0)
	_steps.unit_size = 4.0
	_player.add_child.call_deferred(_steps)
	var noise := _player.get_node_or_null("Noise") as PlayerNoise
	if noise:
		noise.footstep.connect(_on_footstep)
	var interactor := _player.get_node_or_null("Interactor") as PlayerInteractor
	if interactor:
		interactor.focus_changed.connect(_on_focus_changed)


func _process(delta: float) -> void:
	if _player == null or _camera == null:
		return
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	movement = movement_kind(speed, _player.is_crouching, _player.is_on_floor())
	var target_amount := 0.0 if movement == &"idle" else 1.0
	_bob_amount = move_toward(_bob_amount, target_amount, delta * 4.0)
	_phase = fmod(_phase + delta * speed * 2.2, TAU)
	var bob: Vector2 = BOB.get(movement, BOB[&"walk"])
	_camera.position = bob_offset(_phase, bob, _bob_amount) if head_bob_enabled else Vector3.ZERO
	var fov_target := SPRINT_FOV if movement == &"run" else BASE_FOV
	_camera.fov = move_toward(_camera.fov, fov_target, delta * 20.0)


## What the player is doing, for bob and FOV.
static func movement_kind(speed: float, crouching: bool, on_floor: bool) -> StringName:
	if not on_floor or speed < 0.5:
		return &"idle"
	if crouching:
		return &"crouch"
	return &"run" if speed > 4.5 else &"walk"


## The camera's local offset: a figure-of-eight sway (up/down twice per side-to-side).
static func bob_offset(phase: float, bob: Vector2, amount: float) -> Vector3:
	return Vector3(sin(phase) * bob.y, absf(sin(phase)) * bob.x - bob.x * 0.5, 0.0) * amount


func _on_footstep(kind: StringName) -> void:
	if _steps == null:
		return
	_steps.stream = SoundBank.pick("player_step")
	_steps.volume_db = STEP_VOLUME.get(kind, -11.0)
	_steps.pitch_scale = STEP_PITCH.get(kind, 1.0) * _rng.randf_range(0.93, 1.07)
	if _steps.is_inside_tree():
		_steps.play()
	steps_played += 1


func _on_focus_changed(target: Interactable) -> void:
	if target == null:
		return
	var audio := AudioDirector.find(_player)
	if audio:
		audio.play_sfx("ui_hover", -10.0)


func _notification(what: int) -> void:
	# If the player was freed before the deferred add_child ran, free the orphan.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_steps) and not _steps.is_inside_tree() and _steps.get_parent() == null:
		_steps.free()
