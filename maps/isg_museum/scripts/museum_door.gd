extends Interactable

## Closed panels block movement and sight. Links bridge baked gaps while open.
## Unlike the shared library door, guards have no collision exception here.

signal rejected(reason: String)
signal opened
signal closed

enum Mode { KEY, LATCH, FREE }

@export var mode := Mode.KEY
@export var door_name := "Cửa phòng B"
@export var key_objective_id: StringName = &"take_key"
## World direction from the door towards the side containing the latch.
@export var open_from := Vector3.FORWARD

var is_open := false
var unlocked := false

@onready var _panel: StaticBody3D = get_node_or_null("Panel")
@onready var _passage: NavigationLink3D = get_node_or_null("Passage")


func _ready() -> void:
	super()
	add_to_group("museum_doors")
	unlocked = mode == Mode.FREE
	if _passage:
		_passage.enabled = false


func can_interact(by: Node) -> bool:
	var flow := GameFlow.find(self)
	return super(by) and flow != null \
		and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving()


func get_prompt(by: Node) -> String:
	if is_open:
		return "Đóng " + door_name.to_lower()
	var reason := _blocked_reason(by)
	return reason if not reason.is_empty() else "Mở " + door_name.to_lower()


func _on_interact(by: Node) -> bool:
	if is_open:
		var shape_node := _panel.get_node("CollisionShape3D") as CollisionShape3D
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape_node.shape
		query.transform = shape_node.global_transform
		query.collision_mask = 6 # Player or guard in the closing panel volume.
		query.collide_with_areas = false
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			rejected.emit("Có người đứng ở cửa; hãy chờ lối trống để đóng.")
			return false
		is_open = false
		_panel.collision_layer = 1
		_panel.show()
		_passage.enabled = false
		closed.emit()
		return true
	var reason := _blocked_reason(by)
	if not reason.is_empty():
		rejected.emit(reason)
		return false
	# Clear both collision filters: hidden bodies must not block movement, sight,
	# noise or another interaction ray. No mid-physics shape edits are needed.
	is_open = true
	unlocked = true
	if _panel:
		_panel.collision_layer = 0
		_panel.collision_mask = 0
		_panel.hide()
	if _passage:
		_passage.enabled = true
	opened.emit()
	return true


func _blocked_reason(by: Node) -> String:
	if unlocked:
		return ""
	if mode == Mode.KEY:
		var objectives := ObjectiveManager.find(self)
		if objectives == null or not objectives.is_completed(key_objective_id):
			return "Cần chìa K ở phòng nhân viên tầng 1"
	elif mode == Mode.LATCH:
		var actor := by as Node3D
		if actor == null:
			return "Chốt chỉ mở từ bên trong phòng B"
		var offset := actor.global_position - global_position
		offset.y = 0.0
		var side := Vector3(open_from.x, 0.0, open_from.z).normalized()
		if offset.dot(side) <= 0.1:
			return "Chốt chỉ mở từ bên trong phòng B"
	return ""
