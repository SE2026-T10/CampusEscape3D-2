class_name K17LockdownGate
extends Interactable
## A solid gate and its off-mesh walking link always share the same state.
@export_enum("Courtyard","Maintenance") var route := 0
@export var release_duration := 8.0
@export var obstruction_grace := 3.0
var is_closed := false
var closing_pending := false
var obstruction_left := 0.0
var safety_aborts := 0
var _leaf_tween: Tween

func _ready() -> void:
	super()
	add_to_group("checkpoint_state")
	$Indicator.material_override = $Indicator.material_override.duplicate()
	_apply(false)

func request_close() -> void:
	if is_closed or closing_pending: return
	closing_pending = true
	obstruction_left = obstruction_grace

func _physics_process(delta: float) -> void:
	var flow := GameFlow.find(self)
	if flow == null or flow.state != GameStateMachine.State.PLAYING or not closing_pending: return
	var occupied := false
	for actor in get_tree().get_nodes_in_group("guards") + get_tree().get_nodes_in_group("player"):
		if AreaUtils.box_shapes_contain($Safety,actor.global_position+Vector3(0,.5,0),.55):
			occupied = true
			break
	if not occupied:
		closing_pending = false
		is_closed = true
		_apply(true)
		$Motor.play()
		return
	obstruction_left -= delta
	if obstruction_left <= 0.0:
		# Finite safety reversal: the rest of the lockdown schedule never waits here.
		closing_pending = false
		safety_aborts += 1
		var mission := MapHudProvider.find_for(self) as K17MissionController
		if mission: mission.queue_radio("Loa K17: Cổng gặp vật cản, dừng đóng. Các chốt khác tiếp tục phong tỏa.",5,"gate_safety")

func can_interact(by: Node) -> bool:
	var mission := MapHudProvider.find_for(self) as K17MissionController
	var flow := GameFlow.find(self)
	return super(by) and route == 1 and is_closed and mission != null and mission.has_file and flow != null and flow.state == GameStateMachine.State.PLAYING

func get_hold_duration(_by: Node) -> float:
	var mission := MapHudProvider.find_for(self) as K17MissionController
	return 0.0 if mission != null and mission.backdoor_prepared else release_duration

func get_prompt(_by: Node) -> String:
	if route == 0: return "Cổng sân đã phong tỏa · chuyển sang bảo trì phía đông"
	var mission := MapHudProvider.find_for(self) as K17MissionController
	return "Mở nhanh cửa hậu đã chuẩn bị" if mission != null and mission.backdoor_prepared else "Mở khóa cơ cửa hậu"

func _on_interact(_by: Node) -> bool:
	is_closed = false
	closing_pending = false
	_apply(true)
	$Motor.play()
	return true

func _apply(animate: bool) -> void:
	$Panel.collision_layer = 1 if is_closed else 0
	$WalkingLink.enabled = not is_closed
	enabled = is_closed
	if _leaf_tween: _leaf_tween.kill()
	var x := 0.0 if is_closed else 4.4
	if animate:
		_leaf_tween = create_tween()
		_leaf_tween.tween_property($Leaf,"position:x",x,.45)
	else:
		$Leaf.position.x = x
	var material := $Indicator.material_override as StandardMaterial3D
	material.albedo_color = Color("d44732") if is_closed else Color("62b998")
	material.emission = material.albedo_color

func get_checkpoint_state() -> Dictionary:
	return {"closed":is_closed}

func restore_checkpoint_state(saved: Dictionary) -> void:
	is_closed = bool(saved.get("closed",false))
	closing_pending = false
	obstruction_left = 0.0
	$Motor.stop()
	_apply(false)
