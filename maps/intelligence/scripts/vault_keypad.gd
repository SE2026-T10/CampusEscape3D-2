extends CodeLock
## Reuses the common puzzle, while access policy and wording belong to K17.
const Mount := preload("res://maps/intelligence/resources/layout/k17_navigation.gd")

func _ready() -> void:
	super()
	_build_housing()
	_display.font_size=26
	_display.pixel_size=.0013
	_display.position=Vector3(0,.58,.012)
	_display.outline_size=2
	get_node("NoPowerTag").text="CHƯA CẤP QUYỀN"
	for mesh in find_children("*","GeometryInstance3D",true,false): mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
	for i in dials.size(): dials[i].control_name="Chữ số %d"%(i+1)
	enter.control_name="Xác nhận"
	enter.get_node("Model/Cap/Mark").text="XÁC NHẬN"
	enter.action_text="Xác nhận mã kho"

func _build_housing() -> void:
	var housing := Node3D.new()
	housing.name="Housing"
	add_child(housing)
	_box(housing,"Case",Mount.CASE_CENTER,Mount.CASE_SIZE,Color("293735"))
	_box(housing,"KeyboardFace",Vector3(0,.035,-.005),Vector3(1.02,.42,.02),Color("111b1e"))
	_box(housing,"DigitBezel",Vector3(0,.415,.004),Vector3(.96,.18,.009),Color("3e4f49"))
	_box(housing,"DigitScreen",Vector3(0,.415,.008),Vector3(.89,.135,.006),Color("080f13"))
	_box(housing,"StatusScreen",Vector3(0,.58,.008),Vector3(1.06,.115,.006),Color("080f13"))
	_box(housing,"Nameplate",Vector3(0,.735,.006),Vector3(1.02,.09,.004),Color("111b1e"))
	var label := Label3D.new()
	label.name="Name"
	label.text="KIỂM SOÁT KHO / B1"
	label.font_size=22
	label.pixel_size=.0016
	label.outline_size=0
	label.position=Vector3(0,.735,.009)
	label.modulate=Color("c5cdb9")
	housing.add_child(label)
	for x in [-.545,.545]:
		for y in [-.245,.765]:
			var bolt := MeshInstance3D.new()
			bolt.name="MountBolt"
			bolt.position=Vector3(x,y,.006)
			bolt.rotation.x=PI/2
			var cylinder := CylinderMesh.new()
			cylinder.top_radius=.013
			cylinder.bottom_radius=.013
			cylinder.height=.012
			cylinder.radial_segments=8
			bolt.mesh=cylinder
			var material := StandardMaterial3D.new()
			material.albedo_color=Color("78847a")
			material.roughness=.75
			bolt.material_override=material
			housing.add_child(bolt)
	_box(housing,"CableGland",Vector3(.43,-.30,-.096),Vector3(.065,.075,.04),Color("192325"))
	_box(housing,"Conduit",Vector3(.43,-.63,-.1),Vector3(.028,.65,.028),Color("444d48"))
	for y in [-.47,-.88]:
		_box(housing,"ConduitClamp",Vector3(.43,y,-.108),Vector3(.075,.035,.016),Color("293735"))

func _box(parent: Node,title: String,pos: Vector3,size_: Vector3,colour: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name=title
	mesh.position=pos
	var box := BoxMesh.new()
	box.size=size_
	mesh.mesh=box
	var material := StandardMaterial3D.new()
	material.albedo_color=colour
	material.roughness=.82
	mesh.material_override=material
	parent.add_child(mesh)

func has_power() -> bool:
	var objectives := ObjectiveManager.find(self)
	var inventory := PlayerInventory.find(self)
	return objectives != null and objectives.is_completed(K17MissionController.ARCHIVE) and inventory != null and inventory.has(ItemCatalog.STAFF_CARD)

func _on_objective_changed(id: StringName,state: ObjectiveManager.State) -> void:
	super(id,state)
	# Access policy depends on other objectives too, so controls must refresh
	# when the player reaches the checkpoint, not only after solving the lock.
	_refresh()

func _refresh() -> void:
	super()
	get_node("NoPowerTag").visible=not has_power()
	var reason: String="Đã mở" if is_solved else "Khóa tạm (%d giây)"%ceili(lockout_left) if lockout_left>0 else "Cần thẻ và checkpoint" if not has_power() else ""
	for control in dials+[enter]: control.blocked_reason=reason
	if is_solved: _set_display("KHO B1 / ĐÃ MỞ",Color(.4,1,.55))
	elif not has_power(): _set_display("KHO B1 / CẦN THẺ VÀ CHECKPOINT",Color(.9,.65,.3))
	elif lockout_left>0: _set_display("KHO B1 / KHÓA TẠM %d GIÂY"%ceili(lockout_left),Color(1,.35,.3))
	else: _set_display("KHO B1 / NHẬP MÃ · CÒN %d LẦN"%attempts_left)
