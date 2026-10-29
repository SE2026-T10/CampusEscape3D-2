extends Interactable

## Museum doors stay open until the whole level reloads. Closed panels are baked
## into navigation, so a Passage link must bridge their gap only after opening.
## Unlike the shared library door, guards have no collision exception here.

signal rejected(reason: String)
signal opened

enum Mode { KEY, LATCH }

@export var mode := Mode.KEY
@export var door_name := "Cửa phòng B"
@export var key_objective_id: StringName = &"take_key"
## World direction from the door towards the side containing the latch.
@export var open_from := Vector3.FORWARD

var is_open := false

@onready var _panel: StaticBody3D = get_node_or_null("Panel")
@onready var _passage: NavigationLink3D = get_node_or_null("Passage")


func _ready() -> void:
	super()
	add_to_group("museum_doors")
	if _passage:
		_passage.enabled = false


func can_interact(by: Node) -> bool:
	var flow := GameFlow.find(self)
	return super(by) and not is_open and flow != null \
		and flow.state == GameStateMachine.State.PLAYING


func get_prompt(by: Node) -> String:
	if is_open:
		return ""
	var reason := _blocked_reason(by)
	return reason if not reason.is_empty() else "Mở " + door_name.to_lower()


func _on_interact(by: Node) -> bool:
	var reason := _blocked_reason(by)
	if not reason.is_empty():
		rejected.emit(reason)
		return false
	# Clear both collision filters: hidden bodies must not block movement, sight,
	# noise or another interaction ray. No mid-physics shape edits are needed.
	is_open = true
	enabled = false
	collision_layer = 0
	if _panel:
		_panel.collision_layer = 0
		_panel.collision_mask = 0
		_panel.hide()
	if _passage:
		_passage.enabled = true
	opened.emit()
	return true


func _blocked_reason(by: Node) -> String:
	if mode == Mode.KEY:
		var objectives := ObjectiveManager.find(self)
		if objectives == null or not objectives.is_completed(key_objective_id):
			return "Cần chìa K ở phòng nhân viên tầng 1"
	else:
		var actor := by as Node3D
		if actor == null:
			return "Chốt chỉ mở từ bên trong phòng B"
		var offset := actor.global_position - global_position
		offset.y = 0.0
		var side := Vector3(open_from.x, 0.0, open_from.z).normalized()
		if offset.dot(side) <= 0.1:
			return "Chốt chỉ mở từ bên trong phòng B"
	return ""
