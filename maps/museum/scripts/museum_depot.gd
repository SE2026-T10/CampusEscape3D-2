extends Interactable

signal rejected(reason: String)

@export var painting_path: NodePath = ^"../Painting_T2"


func get_prompt(by: Node) -> String:
	var painting := get_node(painting_path)
	if painting.state == painting.State.DELIVERED:
		return "T2 đã được tập kết an toàn"
	if painting.is_carried_by(by):
		return "Đặt T2 vào điểm tập kết"
	return "Điểm tập kết — cần mang T2 tới đây"


func can_interact(by: Node) -> bool:
	var flow := GameFlow.find(self)
	return super(by) and flow != null and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving()


func _on_interact(by: Node) -> bool:
	var painting := get_node(painting_path)
	if not painting.is_carried_by(by):
		rejected.emit("Hãy mang tranh lớn T2 từ phòng B tới điểm tập kết này.")
		return false
	if not painting.deliver(self):
		rejected.emit("Hãy tới gần điểm tập kết và giữ lối đặt tranh thông thoáng.")
		return false
	enabled = false
	collision_layer = 0
	$Label3D.text = "ĐÃ TẬP KẾT T2"
	return true
