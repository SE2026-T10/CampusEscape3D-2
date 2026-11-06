extends Interactable
const Config := preload("res://maps/intelligence/resources/layout/k17_sabotage.gd")

func _ready() -> void:
	hold_duration = Config.HOLD_SECONDS
	super()

func can_interact(by: Node) -> bool:
	return super(by) and get_parent().can_plant()

func get_prompt(_by: Node) -> String:
	var controller := get_parent()
	if controller.detonated: return "Cụm tình báo đã bị phá hủy"
	if controller.armed: return "Đã đặt thiết bị — rút tới điểm tập kết"
	var m: K17MissionController = controller.mission()
	if m == null or not m.has_file: return "Cụm tình báo dự phòng — thu hồi hồ sơ trước"
	return "Đặt thiết bị phá hủy · tùy chọn"

func _on_interact(_by: Node) -> bool:
	return get_parent().plant()
