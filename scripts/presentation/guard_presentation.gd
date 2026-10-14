class_name GuardPresentation
extends Node

## Presentation for a guard (a child of Guard named "Presentation"):
##   - animates the low-poly jointed model (Guard/Model) with four looping
##     animations built in code: idle (breathing, glancing around), walk
##     (patrol and investigation), run (chase: leaning forward, arms pumping)
##     and search (standing at a noise, turning head and shoulders)
##   - the animation follows the AI state and how fast the guard really moves,
##     and its speed follows the walking speed, so feet don't slide much
##   - 3D footsteps by distance walked (heavier and quicker in a chase)
##   - patrol audio: keys jingling on the belt while walking, radio chatter now
##     and then while patrolling, a radio call when an investigation starts
##   - the "?" / "!" alert icon pops when the guard's state changes
## Read-only towards the guard: it never changes movement, AI or perception.

const ANIMATIONS := ["idle", "walk", "run", "search"]
## Metres between footsteps when walking / running.
const WALK_STRIDE := 0.75
const RUN_STRIDE := 1.15
## Below this horizontal speed the guard counts as standing.
const STAND_SPEED := 0.3

## The animation playing now (for tests).
var current_animation := ""
var footsteps_played := 0
var radio_played := 0
var keys_played := 0

var _guard: Guard
var _anim: AnimationPlayer
var _steps: AudioStreamPlayer3D
var _gear: AudioStreamPlayer3D
var _distance := 0.0
var _last_position := Vector3.INF
var _last_state := GuardStateMachine.NONE
var _radio_wait := 0.0
var _step_count := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_guard = get_parent() as Guard
	if _guard == null or _guard.get_node_or_null("Model") == null:
		push_warning("GuardPresentation needs a Guard parent with a Model.")
		return
	_rng.seed = hash(_guard.name)
	_radio_wait = _rng.randf_range(6.0, 18.0)
	_anim = AnimationPlayer.new()
	_anim.name = "AnimationPlayer"
	add_child(_anim)
	_anim.root_node = _anim.get_path_to(_guard)
	_anim.add_animation_library(&"", build_library())
	_steps = _make_player("Footsteps", Vector3(0, 0.05, 0), 5.0)
	_gear = _make_player("Gear", Vector3(0, 1.0, 0), 3.0)
	_play("idle")


## The four animations, keyed on the model's joints (paths relative to the guard).
static func build_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", _idle())
	lib.add_animation(&"walk", _walk())
	lib.add_animation(&"run", _run())
	lib.add_animation(&"search", _search())
	return lib


## Which animation fits the AI state and the speed the guard actually moves at.
static func choose_animation(state: int, speed: float) -> String:
	if speed < STAND_SPEED:
		return "search" if state == GuardStateMachine.INVESTIGATE or state == GuardStateMachine.CHASE else "idle"
	if state == GuardStateMachine.CHASE or speed > 3.4:
		return "run"
	return "walk"


func _process(delta: float) -> void:
	if _guard == null or _guard.machine == null:
		return
	var state := _guard.machine.current
	var speed := Vector2(_guard.velocity.x, _guard.velocity.z).length()
	var wanted := choose_animation(state, speed)
	_play(wanted)
	match wanted:
		"walk":
			_anim.speed_scale = clampf(speed / 2.0, 0.6, 1.6)
		"run":
			_anim.speed_scale = clampf(speed / 4.2, 0.7, 1.3)
		_:
			_anim.speed_scale = 1.0
	if state != _last_state:
		_on_state_changed(_last_state, state)
		_last_state = state
	_update_footsteps(speed, state)
	if state == GuardStateMachine.PATROL:
		_radio_wait -= delta
		if _radio_wait <= 0.0:
			_radio_wait = _rng.randf_range(14.0, 30.0)
			_play_gear("guard_radio", -12.0)
			radio_played += 1


func _update_footsteps(speed: float, state: int) -> void:
	var position := _guard.global_position
	if _last_position == Vector3.INF:
		_last_position = position
		return
	var moved := Vector2(position.x - _last_position.x, position.z - _last_position.z).length()
	_last_position = position
	if speed < STAND_SPEED or moved > 2.0:  # standing still, or reset to the start
		return
	var running := state == GuardStateMachine.CHASE or speed > 3.4
	_distance += moved
	if _distance < (RUN_STRIDE if running else WALK_STRIDE):
		return
	_distance = 0.0
	_step_count += 1
	_steps.stream = SoundBank.pick("guard_step")
	_steps.volume_db = -3.0 if running else -8.0
	_steps.pitch_scale = (1.08 if running else 1.0) * _rng.randf_range(0.94, 1.06)
	_steps.play()
	footsteps_played += 1
	# The keys on the belt jingle every few steps.
	if _step_count % (2 if running else 4) == 0:
		_play_gear("guard_keys", -9.0 if running else -14.0)
		keys_played += 1


func _on_state_changed(previous: int, current: int) -> void:
	if current == GuardStateMachine.INVESTIGATE and previous == GuardStateMachine.PATROL:
		_play_gear("guard_radio", -8.0)  # calls it in
		radio_played += 1
	var icon := _guard.alert_icon
	if icon and (current == GuardStateMachine.INVESTIGATE or current == GuardStateMachine.CHASE):
		icon.scale = Vector3.ONE * 1.8
		var tween := create_tween()
		tween.tween_property(icon, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play(animation: String) -> void:
	if animation == current_animation:
		return
	current_animation = animation
	_anim.play(animation, 0.25)


func _play_gear(sound: String, volume_db: float) -> void:
	_gear.stream = SoundBank.pick(sound)
	_gear.volume_db = volume_db
	_gear.pitch_scale = _rng.randf_range(0.95, 1.05)
	_gear.play()


func _make_player(node_name: String, at: Vector3, unit_size: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = node_name
	p.bus = &"SFX"
	p.position = at
	p.unit_size = unit_size
	p.max_distance = 30.0
	add_child(p)
	return p


# --- animation data -------------------------------------------------------
# Joint rotations are around X (positive swings a limb forward, towards -Z)
# except where noted. Every animation keys the same joints so blends are clean.

const HIPS := "Model/Hips:position"
const TORSO := "Model/Hips/Torso:rotation"
const HEAD := "Model/Hips/Torso/Head:rotation"
const ARM_L := "Model/Hips/Torso/ArmL:rotation"
const ARM_R := "Model/Hips/Torso/ArmR:rotation"
const LEG_L := "Model/Hips/LegL:rotation"
const LEG_R := "Model/Hips/LegR:rotation"
const HIP_Y := 0.9


static func _idle() -> Animation:
	var a := _anim_of(4.0)
	_key(a, HIPS, [0.0, 2.0, 4.0], [Vector3(0, HIP_Y, 0), Vector3(0, HIP_Y - 0.012, 0), Vector3(0, HIP_Y, 0)])
	_key(a, TORSO, [0.0, 2.0, 4.0], [Vector3.ZERO, Vector3(0.03, 0, 0), Vector3.ZERO])
	_key(a, HEAD, [0.0, 1.0, 2.0, 3.0, 4.0], [Vector3.ZERO, Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(0, -0.25, 0), Vector3.ZERO])
	_key(a, ARM_L, [0.0, 2.0, 4.0], [Vector3(0, 0, -0.06), Vector3(0.04, 0, -0.08), Vector3(0, 0, -0.06)])
	_key(a, ARM_R, [0.0, 2.0, 4.0], [Vector3(0, 0, 0.06), Vector3(0.04, 0, 0.08), Vector3(0, 0, 0.06)])
	_key(a, LEG_L, [0.0, 4.0], [Vector3.ZERO, Vector3.ZERO])
	_key(a, LEG_R, [0.0, 4.0], [Vector3.ZERO, Vector3.ZERO])
	return a


static func _walk() -> Animation:
	# One cycle = two steps; 1.0 s at the 2 m/s patrol speed.
	var a := _anim_of(1.0)
	var t := [0.0, 0.25, 0.5, 0.75, 1.0]
	_key(a, HIPS, t, [Vector3(0, HIP_Y - 0.03, 0), Vector3(0, HIP_Y, 0), Vector3(0, HIP_Y - 0.03, 0), Vector3(0, HIP_Y, 0), Vector3(0, HIP_Y - 0.03, 0)])
	_key(a, TORSO, t, [Vector3(-0.04, 0.05, 0), Vector3(-0.04, 0, 0), Vector3(-0.04, -0.05, 0), Vector3(-0.04, 0, 0), Vector3(-0.04, 0.05, 0)])
	_key(a, HEAD, [0.0, 1.0], [Vector3.ZERO, Vector3.ZERO])
	_key(a, LEG_L, t, [Vector3(0.45, 0, 0), Vector3(0, 0, 0), Vector3(-0.45, 0, 0), Vector3(0, 0, 0), Vector3(0.45, 0, 0)])
	_key(a, LEG_R, t, [Vector3(-0.45, 0, 0), Vector3(0, 0, 0), Vector3(0.45, 0, 0), Vector3(0, 0, 0), Vector3(-0.45, 0, 0)])
	_key(a, ARM_L, t, [Vector3(-0.35, 0, -0.06), Vector3(0, 0, -0.06), Vector3(0.35, 0, -0.06), Vector3(0, 0, -0.06), Vector3(-0.35, 0, -0.06)])
	_key(a, ARM_R, t, [Vector3(0.35, 0, 0.06), Vector3(0, 0, 0.06), Vector3(-0.35, 0, 0.06), Vector3(0, 0, 0.06), Vector3(0.35, 0, 0.06)])
	return a


static func _run() -> Animation:
	# One cycle = two strides; 0.6 s at the 4.2 m/s chase speed.
	var a := _anim_of(0.6)
	var t := [0.0, 0.15, 0.3, 0.45, 0.6]
	_key(a, HIPS, t, [Vector3(0, HIP_Y - 0.06, 0), Vector3(0, HIP_Y + 0.02, 0), Vector3(0, HIP_Y - 0.06, 0), Vector3(0, HIP_Y + 0.02, 0), Vector3(0, HIP_Y - 0.06, 0)])
	_key(a, TORSO, t, [Vector3(-0.22, 0.08, 0), Vector3(-0.22, 0, 0), Vector3(-0.22, -0.08, 0), Vector3(-0.22, 0, 0), Vector3(-0.22, 0.08, 0)])
	_key(a, HEAD, [0.0, 0.6], [Vector3(0.15, 0, 0), Vector3(0.15, 0, 0)])  # looks ahead despite the lean
	_key(a, LEG_L, t, [Vector3(0.85, 0, 0), Vector3(0.1, 0, 0), Vector3(-0.6, 0, 0), Vector3(0.1, 0, 0), Vector3(0.85, 0, 0)])
	_key(a, LEG_R, t, [Vector3(-0.6, 0, 0), Vector3(0.1, 0, 0), Vector3(0.85, 0, 0), Vector3(0.1, 0, 0), Vector3(-0.6, 0, 0)])
	_key(a, ARM_L, t, [Vector3(-0.8, 0, -0.1), Vector3(0.2, 0, -0.1), Vector3(1.0, 0, -0.1), Vector3(0.2, 0, -0.1), Vector3(-0.8, 0, -0.1)])
	_key(a, ARM_R, t, [Vector3(1.0, 0, 0.1), Vector3(0.2, 0, 0.1), Vector3(-0.8, 0, 0.1), Vector3(0.2, 0, 0.1), Vector3(1.0, 0, 0.1)])
	return a


static func _search() -> Animation:
	# Standing at the noise, scanning left and right (Y rotations), hands raised a little.
	var a := _anim_of(2.4)
	var t := [0.0, 0.6, 1.2, 1.8, 2.4]
	_key(a, HIPS, [0.0, 2.4], [Vector3(0, HIP_Y - 0.02, 0), Vector3(0, HIP_Y - 0.02, 0)])
	_key(a, TORSO, t, [Vector3(-0.08, 0, 0), Vector3(-0.08, 0.3, 0), Vector3(-0.08, 0, 0), Vector3(-0.08, -0.3, 0), Vector3(-0.08, 0, 0)])
	_key(a, HEAD, t, [Vector3(0, 0, 0), Vector3(0, 0.5, 0), Vector3(0, 0, 0), Vector3(0, -0.5, 0), Vector3(0, 0, 0)])
	_key(a, ARM_L, [0.0, 2.4], [Vector3(0.35, 0, -0.25), Vector3(0.35, 0, -0.25)])
	_key(a, ARM_R, [0.0, 2.4], [Vector3(0.35, 0, 0.25), Vector3(0.35, 0, 0.25)])
	_key(a, LEG_L, [0.0, 2.4], [Vector3(0.1, 0, -0.05), Vector3(0.1, 0, -0.05)])
	_key(a, LEG_R, [0.0, 2.4], [Vector3(-0.1, 0, 0.05), Vector3(-0.1, 0, 0.05)])
	return a


static func _anim_of(length: float) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	return a


static func _key(a: Animation, path: String, times: Array, values: Array) -> void:
	var track := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(track, NodePath(path))
	a.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	for i in times.size():
		a.track_insert_key(track, times[i], values[i])
