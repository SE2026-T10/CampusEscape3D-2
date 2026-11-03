extends Interactable
## Panel stays on the fixed jamb. The leaf slides into its real overhead housing.
var is_open := false
var opening := 0.0
var _mission: K17MissionController
var _base_y:=0.0

func _ready() -> void:
	super()
	hold_duration=6.0
	add_to_group("checkpoint_state")
	_mission=MapHudProvider.find_for(self) as K17MissionController
	_base_y=$Leaf.position.y

func can_interact(by: Node) -> bool:
	var objectives:=ObjectiveManager.find(self)
	return super(by) and not is_open and objectives!=null and objectives.is_completed(K17MissionController.PASS) and objectives.is_completed(K17MissionController.VAULT)

func get_prompt(by: Node) -> String:
	if is_open: return "Hồ sơ / cửa đã mở hai chiều"
	return "Dùng thẻ + bộ giải mã — giữ E 6 giây" if can_interact(by) else "Cần giấy thông hành và mở kho B1"

func _on_interact(_by: Node) -> bool:
	is_open=true
	_mission.queue_radio("Lam: Khóa hồ sơ đã mở. Lấy tài liệu mới bắt đầu hai phút. Khi rút, ra chính cửa này rồi quay về sảnh.",4,"archive_unlocked")
	$Motor.play()
	return true

func _physics_process(delta: float) -> void:
	if is_open and opening<1.0:
		opening=minf(1,opening+delta*1.5)
		$Leaf.position.y=_base_y+opening*3.0
	if opening>=1: $Leaf.collision_layer=0

func get_checkpoint_state() -> Dictionary:
	return {"open":is_open}

func restore_checkpoint_state(saved: Dictionary) -> void:
	is_open=bool(saved.get("open",false))
	opening=1.0 if is_open else 0.0
	$Leaf.position.y=_base_y+opening*3.0
	$Leaf.collision_layer=0 if is_open else 1
	$Motor.stop()
