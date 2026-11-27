extends Interactable

## T2 is one scene instance throughout: wall -> hands -> floor -> depot.
## Only delivery completes take_t2. The dropped prop is not a world collider.
signal rejected(reason: String)
signal notice(message: String)

enum State { WALL, CARRIED, DROPPED, DELIVERED }

@export var depot_path: NodePath = ^"../T2Depot"
@export var drop_distance := 1.15

var state := State.WALL
var _carrier: FirstPersonPlayer

@onready var visual: Node3D = $Visual
@onready var label: Label3D = $Label3D


func get_prompt(_by: Node) -> String:
	var objectives := ObjectiveManager.find(self)
	if objectives == null or not objectives.is_completed(&"take_key"):
		return "Cần chìa K để lấy T2"
	return "Nhấc T2 — mang tới điểm tập kết trong kho" if state == State.WALL \
		else "Nhấc lại T2 — mang tới kho"


func can_interact(by: Node) -> bool:
	var objectives := ObjectiveManager.find(self)
	return super(by) and _playing() and by is FirstPersonPlayer \
		and by.has_method("begin_carry") and state in [State.WALL, State.DROPPED] \
		and objectives != null and objectives.get_state(&"take_t2") == ObjectiveManager.State.ACTIVE


func _on_interact(by: Node) -> bool:
	if not by.begin_carry(self):
		return false
	_carrier = by as FirstPersonPlayer
	state = State.CARRIED
	enabled = false
	collision_layer = 0
	label.hide()
	visual.reparent(_carrier.camera, false)
	visual.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.6), Vector3(0, -0.37, -0.95))
	notice.emit("Đang mang T2: đi chậm, không chạy nước rút. Q để đặt xuống; giao tại kho bằng E.")
	return true


func is_carried_by(by: Node) -> bool:
	return state == State.CARRIED and is_instance_valid(_carrier) and _carrier == by


func try_drop() -> bool:
	if not _playing() or state != State.CARRIED or not is_instance_valid(_carrier):
		return false
	var placement := _find_drop_transform()
	if placement.is_empty():
		rejected.emit("Chưa đủ chỗ đặt T2. Hãy chọn sàn phẳng, tránh tường, đồ đạc và mép cầu thang.")
		return false
	var player := _carrier
	visual.reparent(self, false)
	visual.transform = Transform3D.IDENTITY
	global_transform = placement.transform
	state = State.DROPPED
	enabled = true
	collision_layer = Interactable.LAYER
	label.text = "T2 · E: NHẤC LẠI"
	label.show()
	_carrier = null
	player.end_carry(self)
	notice.emit("Đã đặt T2 xuống. Có thể di chuyển bình thường; quay lại nhìn tranh và nhấn E để nhấc.")
	return true


func deliver(depot: Node3D) -> bool:
	if not _playing() or state != State.CARRIED or not is_instance_valid(_carrier) \
			or depot != get_node_or_null(depot_path):
		return false
	var target := depot.get_node("DepositPose") as Marker3D
	# Validate again here so delivery cannot be triggered remotely or through a wall.
	var reach: float = _carrier.get_node("Interactor").reach
	if _carrier.camera.global_position.distance_to(target.global_position) > reach:
		return false
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(_carrier.camera.global_position, target.global_position, 1)
	if not space.intersect_ray(ray).is_empty():
		return false
	var objectives := ObjectiveManager.find(self)
	if objectives == null or not objectives.complete(&"take_t2"):
		return false
	var player := _carrier
	visual.reparent(self, false)
	visual.transform = Transform3D.IDENTITY
	global_transform = target.global_transform
	state = State.DELIVERED
	enabled = false
	collision_layer = 0
	label.text = "T2 · ĐÃ TẬP KẾT"
	label.hide() # The depot has its own completion sign; avoid overlapping labels.
	_carrier = null
	player.end_carry(self)
	return true


func _find_drop_transform() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var yaw := Basis(Vector3.UP, _carrier.global_rotation.y)
	var candidate := _carrier.global_position - yaw.z * drop_distance
	var floor_hit := _floor_at(candidate)
	if floor_hit.is_empty() or floor_hit.normal.y < 0.98 \
			or absf(floor_hit.position.y - _carrier.global_position.y) > 0.35:
		return {}
	var floor_y: float = floor_hit.position.y
	# All four lower corners need support, so the frame cannot hang over a void.
	for x in [-0.78, 0.78]:
		for z in [-0.1, 0.1]:
			var support := _floor_at(candidate + yaw * Vector3(x, 0, z))
			if support.is_empty() or support.normal.y < 0.98 \
					or absf(support.position.y - floor_y) > 0.08:
				return {}
	var center := Vector3(candidate.x, floor_y + 0.65, candidate.z)
	var ray := PhysicsRayQueryParameters3D.create(
		_carrier.global_position + Vector3(0, 0.65, 0), center, 1)
	if not space.intersect_ray(ray).is_empty():
		return {}
	var box := BoxShape3D.new()
	box.size = Vector3(1.56, 1.18, 0.16)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(yaw, center)
	query.collision_mask = 5 # World and guards; ignore the player's own body.
	query.exclude = [_carrier.get_rid()]
	query.collide_with_areas = false
	if not space.intersect_shape(query, 1).is_empty():
		return {}
	return {"transform": Transform3D(yaw, center)}


func _floor_at(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		point + Vector3(0, 0.4, 0), point - Vector3(0, 0.45, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _playing() -> bool:
	var flow := GameFlow.find(self)
	return flow != null and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving()
