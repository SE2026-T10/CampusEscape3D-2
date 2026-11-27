extends GuardPresentation

## Reuse audio/caption/icon helpers only, never procedural Model/Hips tracks.
var skeleton: Skeleton3D
var visual: Node3D
var _phase: StringName = &""
var _transition: StringName = &""
var _seat_yaw := 0.0
var playback_changes := 0
var _speeds := {"walk":1.7,"run":5.62}

func _ready() -> void:
	bind_actor(get_parent() as Guard)

func bind_actor(actor: Guard) -> void:
	_guard = actor
	visual = actor.get_node("Model")
	skeleton = visual.get_node("VisualPivot/GuardRig/Skeleton3D")
	_anim = visual.get_node("AnimationPlayer")
	_rng.seed = hash(actor.name)
	_radio_wait = _rng.randf_range(6,18)
	_steps = _make_player("Footsteps",Vector3(0,.05,0),5)
	_gear = _make_player("Gear",Vector3(0,1,0),3)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/isg_museum/resources/guard_animation_manifest.json"))
	for clip in manifest.clips:
		if clip.name in _speeds: _speeds[clip.name] = clip.reference_speed
	_seat_yaw = actor.rotation.y
	reset_presentation()

func choose_visual_state(ai_state: int, speed: float, phase: StringName) -> StringName:
	if speed >= STAND_SPEED:
		return &"run" if ai_state == GuardStateMachine.CHASE or speed > 3.4 else &"walk"
	if phase in [&"sleeping",&"observing",&"settling"]:
		return &"sleep" if phase == &"sleeping" else &"sitting_idle"
	if ai_state in [GuardStateMachine.INVESTIGATE,GuardStateMachine.CHASE]: return &"look_around"
	if _guard.get("inspection_phase") == &"inspection": return &"look_around"
	return &"idle"

func _process(delta: float) -> void:
	if _guard == null or _guard.machine == null: return
	var state := _guard.machine.current
	var speed := Vector2(_guard.velocity.x,_guard.velocity.z).length()
	var phase: StringName = _guard.get("phase") if _guard.get("phase") != null else &""
	var wanted := choose_visual_state(state,speed,phase)
	var seated := wanted in [&"sleep",&"sitting_idle"]
	# Never delay AI: cancel the seated transition immediately on movement/chase.
	if speed >= STAND_SPEED or state == GuardStateMachine.CHASE:
		_transition = &""
	elif phase != _phase:
		if phase == &"settling": play_transition(&"sit_down",true)
		elif _phase in [&"sleeping",&"observing"] and phase == &"searching": play_transition(&"stand_up",true)
	_phase = phase
	if not _transition.is_empty() and (not _anim.is_playing() or _anim.current_animation_position >= _anim.current_animation_length-.02):
		_transition = &""
	if _transition.is_empty(): _play_skeletal(wanted)
	# AI may turn toward a sound; the seated body remains anchored to its chair.
	visual.rotation.y = _seat_yaw-_guard.rotation.y if seated or not _transition.is_empty() else 0.0
	update_locomotion(speed,delta)
	if seated:
		_steps.stop()
		_gear.stop()
		_last_position = _guard.global_position
		_distance = 0
		return
	if state != _last_state:
		_on_state_changed(_last_state,state)
		_last_state = state
	_update_footsteps(speed,state)
	if state == GuardStateMachine.PATROL:
		_radio_wait -= delta
		if _radio_wait <= 0:
			_radio_wait = _rng.randf_range(14,30)
			_play_gear("guard_radio",-12)
			radio_played += 1

func update_locomotion(speed: float, _delta: float) -> void:
	_anim.speed_scale = clampf(speed/float(_speeds[current_animation]),.5,1.8) if current_animation in _speeds else 1.0

func play_transition(name: StringName, _interruptible: bool) -> void:
	_transition = name
	_play_skeletal(name)

func _play_skeletal(name: StringName) -> void:
	if current_animation == name: return
	current_animation = name
	playback_changes += 1
	_anim.play(name,.18 if name not in [&"walk",&"run"] else .2)

func reset_presentation() -> void:
	_transition = &""
	_phase = &""
	current_animation = ""
	_distance = 0
	_last_position = Vector3.INF
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	_anim.stop()
	_play_skeletal(&"sleep" if _guard.get("phase") == &"sleeping" else &"idle")
	_anim.advance(0)

## Skeletal QA points include the model-facing pivot and actor transform.
func bone_position(name: String) -> Vector3:
	var index := skeleton.find_bone("mixamorig_"+name)
	skeleton.force_update_all_bone_transforms()
	return skeleton.global_transform*skeleton.get_bone_global_pose(index).origin
