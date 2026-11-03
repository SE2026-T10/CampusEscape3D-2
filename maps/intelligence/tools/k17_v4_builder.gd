extends RefCounted
const V4 := preload("res://maps/intelligence/resources/layout/k17_v4.gd")
const BASE := "res://maps/intelligence/"

func build(b: SceneTree, gameplay: Node3D) -> void:
	var spots: Node3D = b._group(gameplay,"HidingSpots")
	for title in V4.HIDING:
		var spot := preload("res://maps/intelligence/scripts/hiding_spot.gd").new()
		spot.name = title
		spot.position = V4.HIDING[title]+Vector3(0,.7,0)
		b._add(spots,spot)
		b._shape(spot,V4.HIDING_SIZE[title])
	var power: PowerNetwork = preload("res://maps/intelligence/scripts/power_network.gd").new()
	power.name="PowerNetwork"
	b._add(gameplay,power)
	var control: CircuitSwitch=preload("res://maps/intelligence/scripts/camera_switch.gd").new()
	control.name="CameraSwitch"
	control.position=V4.POWER_SWITCH
	control.rotation.y=-PI/2
	control.circuit_title="CAMERA / NGUỒN CHÍNH"
	control.on_text="Camera bật. Lính vẫn tuần tra theo vị trí và tiếng động."
	control.off_text="Camera mặt đất đã tắt. B1 dùng nguồn nội bộ riêng. Phá niêm phong khởi động dự phòng sau 15 giây."
	control.style="rotary"
	b._add(gameplay,control)
	var cameras: Node3D=b._group(gameplay,"Cameras")
	for entry in V4.CAMERAS:
		var camera: SecurityCamera=preload("res://maps/intelligence/scripts/security_camera.gd").new()
		camera.name=entry[0]
		camera.camera_name={"Command":"khối chỉ huy","Records":"khu hồ sơ","Service":"tuyến dịch vụ"}[entry[0]]
		camera.position=entry[1]
		var aim: Vector3=entry[2]-entry[1]
		camera.rotation.y=atan2(-aim.x,-aim.z)
		camera.pitch_degrees=rad_to_deg(atan2(-aim.y,Vector2(aim.x,aim.z).length()))
		camera.view_range=entry[3]
		camera.fov_degrees=40
		camera.sweep_angle=23
		camera.near_rise=45
		camera.far_rise=16
		b._add(cameras,camera)
	for entry in V4.NOTES:
		var note: DocumentPickup=preload("res://maps/intelligence/scripts/mission_note.gd").new()
		note.name=entry[0]
		note.document_id=StringName("k17_"+str(entry[0]))
		note.position=entry[1]
		note.title=entry[2]
		note.text=entry[3]
		note.set("instruction",entry[4])
		note.show_marker=true
		if entry[0]=="VaultCode": note.rotation.x=-PI/2
		elif entry[0]=="PowerMemo": note.rotation.y=-PI/2
		else: note.rotation.y=PI
		b._add(gameplay,note)
	var keypad: CodeLock=preload("res://maps/intelligence/scripts/vault_keypad.gd").new()
	keypad.name="VaultKeypad"
	keypad.position=V4.KEYPAD
	keypad.code=V4.VAULT_CODE
	keypad.puzzle_name="Khóa kho B1"
	keypad.lock_style="keypad"
	keypad.dial_spacing=.21
	keypad.door_path=NodePath("../VaultDoor")
	keypad.objective_id=K17MissionController.VAULT
	b._add(gameplay,keypad)
	for i in V4.BOTTLES.size():
		var item: ItemPickup=preload("res://maps/intelligence/scripts/item_pickup.gd").new()
		item.name="Bottle%d"%i
		item.position=V4.BOTTLES[i]
		item.item_id=ItemCatalog.BOTTLE
		b._add(gameplay,item)
	b._script(gameplay,"EquipmentPresentation",Node3D.new(),BASE+"scripts/equipment_presentation.gd")
