extends Interactable
@export var action := "hack"

func system() -> Node:
	return get_tree().get_first_node_in_group("k17_b1_surveillance")

func get_prompt(_by: Node) -> String:
	var s:=system()
	if s==null: return "B1 / không có tín hiệu"
	if action=="hack": return "Camera trước đã bật · V xem C1" if s.hacked else "Chiếm kênh CCTV B1"
	if action=="feed": return "Đổi góc quan sát — V"
	return "Yêu cầu kiểm tra giả — R · "+s.call_status()

func can_interact(by: Node) -> bool:
	var s:=system()
	return super(by) and s!=null and s.can_play() and not s.revoked and (not s.hacked if action=="hack" else s.hacked)

func _on_interact(_by: Node) -> bool:
	var s:=system()
	if action=="hack": return s.hack()
	if action=="feed": s.cycle_feed(); return true
	return s.request_call()
