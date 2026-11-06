extends Node3D
## Sole owner of the mission device. Visuals never decide objective success.
var armed := false
var detonated := false
var placements := 0
var detonations := 0

func _ready() -> void:
	add_to_group("checkpoint_state")
	_sync_visuals()

func mission() -> K17MissionController:
	return get_parent().get_node_or_null("Mission") as K17MissionController

func can_plant() -> bool:
	var m := mission()
	var flow := GameFlow.find(self)
	return m != null and m.has_file and not m.escaped and m.time_left > 0 \
		and not armed and not detonated and flow != null and not flow.is_leaving() \
		and flow.state == GameStateMachine.State.PLAYING \
		and StealthDirector.find(self).status != StealthDirector.Status.CAUGHT

func plant() -> bool:
	if not can_plant(): return false
	armed = true
	placements += 1
	_sync_visuals()
	mission().queue_radio("Lam: Thiết bị đã đặt. Rút về đèn tập kết trước khi hết giờ; chỉ kích hoạt khi anh đã ra ngoài!", 5, "device_armed")
	var audio := AudioDirector.find(self)
	if audio: audio.play_sfx("mech_clunk", -12)
	return true

func detonate() -> bool:
	var m := mission()
	if not armed or detonated or m == null or not m.escaped: return false
	detonated = true
	detonations += 1
	_sync_visuals()
	return true

func status_text() -> String:
	if detonated: return "hoàn tất"
	if armed: return "đã đặt · rút tới tập kết"
	return "tùy chọn · xưởng bảo trì" if mission() and mission().has_file else "tùy chọn · sau khi lấy hồ sơ"

func _sync_visuals() -> void:
	var intact := get_node_or_null("Intact") as Node3D
	var damaged := get_node_or_null("Damaged") as Node3D
	var device := get_node_or_null("Device") as Node3D
	if intact: intact.visible = not detonated
	if damaged: damaged.visible = detonated
	if device: device.visible = armed and not detonated
	var indicator := get_node_or_null("Status") as MeshInstance3D
	if indicator:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("e7a343") if armed else Color("62cfa3")
		if detonated: mat.albedo_color = Color("292b29")
		mat.emission_enabled = not detonated
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = .7
		indicator.material_override = mat

func get_checkpoint_state() -> Dictionary:
	# K17 checkpoints are pre-file. Device progress never becomes a new checkpoint.
	return {}

func restore_checkpoint_state(_saved: Dictionary) -> void:
	armed = false
	detonated = false
	placements = 0
	detonations = 0
	_sync_visuals()
