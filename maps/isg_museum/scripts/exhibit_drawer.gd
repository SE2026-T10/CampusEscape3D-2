extends Interactable

## Holding E opens the latch only while the player's camera still points at it.
## Releasing or moving away pauses progress; an opened drawer needs a new E.
@export var objective_id: StringName = &"take_h1"
@export var exhibit_name := "H1 · Huy chương bạc"
@export var open_duration := 2.5
var open_progress := 0.0
var is_open := false
var collected := false
var _holding := false
var _released_after_open := false
var _last_percent := -1


func get_open_progress() -> float:
	return clampf(open_progress/open_duration,0.0,1.0)


func can_interact(by: Node) -> bool:
	var flow := GameFlow.find(self)
	var objectives := ObjectiveManager.find(self)
	return super(by) and not collected and flow != null \
		and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving() \
		and objectives != null and objectives.get_state(objective_id) == ObjectiveManager.State.ACTIVE


func get_prompt(_by: Node) -> String:
	if is_open:
		return "Lấy " + exhibit_name + " · đối chiếu hợp đồng"
	return "Giữ E mở ngăn " + exhibit_name + " · %d%%" % roundi(open_progress/open_duration*100)


func _on_interact(_by: Node) -> bool:
	if not is_open:
		_holding = true
		return true
	if not _released_after_open:
		return false
	var objectives := ObjectiveManager.find(self)
	if objectives == null or not objectives.complete(objective_id):
		return false
	collected = true
	enabled = false
	collision_layer = 0
	$Artifact.hide()
	$Label3D.text = exhibit_name + "\nNgăn trống"
	return true


func _physics_process(delta: float) -> void:
	if collected:
		return
	if is_open:
		if not Input.is_action_pressed("interact"):
			_released_after_open = true
		return
	if not Input.is_action_pressed("interact"):
		_holding = false
		return
	var player := get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	if not _holding or player == null or not can_interact(player):
		return
	var interactor := player.get_node_or_null("Interactor") as PlayerInteractor
	if interactor == null or interactor.find_target() != self:
		return
	if bool(player.get("keypad_active")) or bool(player.get("modal_active")):
		return
	open_progress = minf(open_duration,open_progress+delta)
	var percent := roundi(open_progress/open_duration*100)
	if percent != _last_percent:
		$Label3D.text = exhibit_name + "\nGiữ E mở chốt: %d%%" % percent
		_last_percent = percent
	if open_progress >= open_duration:
		is_open = true
		$Lid.position.z += 0.45
		$Lid.position.y += 0.08
		$Artifact.show()
		$Label3D.text = exhibit_name + "\nĐã mở · thả E rồi nhấn lại để lấy"
