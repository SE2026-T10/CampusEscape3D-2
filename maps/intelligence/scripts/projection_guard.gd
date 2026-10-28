extends Guard
## Map-local roles and visual evidence. The shared three-state AI is unchanged.
const Config := preload("res://maps/intelligence/resources/layout/k17_projection.gd")
@export var posted := false
var rig_evidence := false
var rig_evidence_position := Vector3.ZERO
var rig_seen_seconds := 0.0
var _inspect_cooldown := 0.0
var _alarm_responded := false
var _hardware_exposed := false

func _ready() -> void:
	if posted: add_to_group("k17_projection_post")
	super()

class PostedPatrol extends PatrolState:
	var scan_time := 0.0
	func update(actor,_perception: GuardPerception,delta: float) -> void:
		# The shared agent considers a target reached at 0.5 m. Accept that
		# arrival before scanning, otherwise returning guards can keep trying
		# the same already-finished path without ever facing the corridor.
		if actor.global_position.distance_to(Config.POST)>.6:
			if not actor._navigating: actor.navigate_to(Config.POST,actor.patrol_speed)
			return
		actor.stop_moving()
		scan_time += delta
		actor.face_yaw(Config.POST_YAW+sin(scan_time*.55)*.10)
	func get_debug_text() -> String: return "giữ chốt / quan sát hành lang"

class EvidenceMachine extends GuardStateMachine:
	func choose_priority_transition(perception: GuardPerception) -> Dictionary:
		var rule := super(perception)
		if not rule.is_empty(): return rule
		if current == PATROL and _actor.rig_evidence:
			return {"to":INVESTIGATE,"reason":"thiết bị đáng ngờ","position":_actor.rig_evidence_position}
		return {}

func _create_machine() -> void:
	machine = EvidenceMachine.new(self,PostedPatrol.new() if posted else PatrolState.new())
	machine.transitioned.connect(func(from,to,reason): ai_state_changed.emit(from,to,reason))

func _physics_process(delta: float) -> void:
	_observe_rig(delta)
	var mission := MapHudProvider.find_for(self) as K17MissionController
	if posted and mission and mission.has_file and not _alarm_responded and machine.current==GuardStateMachine.PATROL:
		_alarm_responded = true
		# The alarm identifies the cabinet, not the player's current coordinates.
		machine.request_transition(GuardStateMachine.INVESTIGATE,"niêm phong hồ sơ báo động",Config.FILE-Vector3(0,1.15,0))
	super(delta)

func _observe_rig(delta: float) -> void:
	rig_evidence = false
	_hardware_exposed = false
	_inspect_cooldown = maxf(0,_inspect_cooldown-delta)
	var rig := get_tree().get_first_node_in_group("k17_projection_rigs")
	if rig==null or vision==null or not rig.deployed:
		rig_seen_seconds = 0.0
		return
	var visible_rig: bool = rig.hardware_visible_to(self)
	var fooled: bool = rig.camouflages_observer(self)
	_hardware_exposed = visible_rig and not fooled
	if visible_rig and not fooled:
		rig_seen_seconds += delta
		if rig_seen_seconds>=.7 and _inspect_cooldown<=0.0:
			rig_evidence = true
			rig_evidence_position = rig.inspection_point_for(self)
			if machine.current==GuardStateMachine.PATROL:
				_inspect_cooldown = 8.0
	else:
		rig_seen_seconds = maxf(0,rig_seen_seconds-delta*.5)

func _update_alert_icon() -> void:
	super()
	if alert_icon and machine.current==GuardStateMachine.PATROL and _hardware_exposed and rig_seen_seconds>.2:
		alert_icon.text="?"
		alert_icon.modulate=Color(1,.85,.2,clampf(rig_seen_seconds/.7,.3,1))
		alert_icon.visible=true

func reset_to_start() -> void:
	_clear_projection_memory()
	super()

func restore_checkpoint_snapshot(snapshot: Dictionary,respawn_point: Vector3) -> bool:
	_clear_projection_memory()
	return super(snapshot,respawn_point)

func _clear_projection_memory() -> void:
	rig_evidence = false
	rig_seen_seconds = 0.0
	_inspect_cooldown = 0.0
	_alarm_responded = false
	_hardware_exposed = false
