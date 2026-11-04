class_name K17ProjectionRig
extends CharacterBody3D
## Opaque movable equipment. Camouflage hides evidence of the equipment from
## one calibrated observer; it never grants invisibility to the player.
const Config := preload("res://maps/intelligence/resources/layout/k17_projection.gd")
const RigControl := preload("res://maps/intelligence/scripts/projection_control.gd")
var deployed := false
var powered := false
var holder: FirstPersonPlayer
var pushed_distance := 0.0
var bumps := 0
var projection_updates := 0
var _shape: CollisionShape3D
var _upright: Node3D
var _handle: Interactable
var _viewport: SubViewport
var _projector: Camera3D
var _image: ShaderMaterial
var _render_clock := 0.0
var _noise_clock := 0.0
var _bump_clock := 0.0
var _actor_clock := 0.0
var _has_calibrated_image := false
var _flow: GameFlow
var _mission: K17MissionController
var _viewer: FirstPersonPlayer
var _wheel_audio: AudioStreamPlayer3D
var _bump_audio: AudioStreamPlayer3D
var _signal_audio: AudioStreamPlayer
var _last_calibration_valid := false
var _clearing := false

func _ready() -> void:
	add_to_group("k17_projection_rigs")
	add_to_group("checkpoint_state")
	process_mode = Node.PROCESS_MODE_ALWAYS
	collision_layer = 1
	collision_mask = 23
	_build_model()
	_build_audio()
	_flow = GameFlow.find(self)
	_mission = MapHudProvider.find_for(self) as K17MissionController
	_connect_flow.call_deferred()
	if DisplayServer.get_name()!="headless": _build_projection()
	_set_deployed(false)

func _connect_flow() -> void:
	_flow=GameFlow.find(self)
	_viewer=get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	if _flow: _flow.state_changed.connect(func(_from,_to): release_grip())

func deploy() -> bool:
	if deployed or not _can_play(): return false
	# Check the full raised panel, excluding only our own folded body.
	var query := PhysicsShapeQueryParameters3D.new()
	var full := BoxShape3D.new()
	full.size = Vector3(Config.SOLID_WIDTH,Config.SCREEN_HEIGHT-.04,.28)
	query.shape = full
	query.transform = global_transform*Transform3D(Basis.IDENTITY,Vector3(0,Config.SCREEN_HEIGHT/2,0))
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	var obstructed := get_world_3d().direct_space_state.intersect_shape(query)
	if not obstructed.is_empty():
		for obstacle in obstructed: print("[K17 projection clearance] ",obstacle.collider.get_path())
		_notify("Không đủ khoảng trống để dựng màn.")
		return false
	_set_deployed(true)
	powered = true
	_signal_audio.stream=SoundBank.pick("reader_beep")
	_signal_audio.play()
	_mission.queue_radio("Lam: Hình chiếu chỉ khớp từ chốt cuối hành lang. E nắm tay đẩy, WASD tiến/lùi; nhìn và nghe cửa tuần tra bên hông.",4,"projection_ready")
	return true

func fold() -> bool:
	if holder!=null or not deployed or not _can_play(): return false
	_set_deployed(false)
	powered = false
	return true

func begin_grip(by: Node) -> bool:
	if not by is FirstPersonPlayer or holder!=null or not deployed or not _can_play(): return false
	var actor := by as FirstPersonPlayer
	var grip := to_global(Config.GRIP_OFFSET)
	if Vector2(actor.global_position.x-grip.x,actor.global_position.z-grip.z).length()>.8:
		_notify("Đứng sau tay đẩy để điều khiển màn.")
		return false
	holder = actor
	holder.set("projection_rig",self)
	add_collision_exception_with(holder)
	holder.add_collision_exception_with(self)
	var surveillance:=get_tree().get_first_node_in_group("k17_b1_surveillance")
	if surveillance: surveillance.show_front_on_grip()
	return true

func release_grip() -> void:
	if is_instance_valid(holder):
		holder.set("projection_rig",null)
		holder.velocity.x = 0
		holder.velocity.z = 0
		remove_collision_exception_with(holder)
		holder.remove_collision_exception_with(self)
	holder = null
	velocity = Vector3.ZERO
	if _wheel_audio: _wheel_audio.stop()

func drive(input: Vector2,delta: float) -> Vector3:
	if not is_instance_valid(holder) or not _can_play():
		release_grip()
		return Vector3.ZERO
	var speed := Config.PUSH_SPEED if input.y<=0 else Config.REVERSE_SPEED
	var local := Vector3(input.x*Config.SIDE_SPEED,0,input.y*speed)
	var motion := global_basis*local*delta
	# Real swept guide assistance; only lateral correction when not entering a bay.
	if absf(input.x)<.05 and absf(global_position.z-Config.HALL_Z)<.07:
		motion.z=clampf(Config.HALL_Z-global_position.z,-.15*delta,.15*delta)
	if motion.length_squared()<.0000001:
		_wheel_audio.stop()
		return Vector3.ZERO
	# Both sweeps pass before either body changes position.
	if test_move(global_transform,motion) or holder.test_move(holder.global_transform,motion):
		_wheel_audio.stop()
		if _bump_clock<=0:
			_bump_clock = 2.0
			bumps += 1
			_emit_noise(.5,8.0,"Va khung màn vào vật cản")
		return Vector3.ZERO
	var before := global_position
	move_and_collide(motion)
	var actual := global_position-before
	pushed_distance += actual.length()
	if _noise_clock<=0:
		_noise_clock = 1.2
		_emit_noise(.18,3.5,"Bánh xe màn chiếu")
	return actual/maxf(delta,.001)

func clear_by_guard(guard: Guard) -> bool:
	if guard==null or guard.global_position.distance_to(global_position)>1.9 or not _mission.has_file: return false
	release_grip()
	# Fold in place: guard still collides with the real, knee-high case.
	_set_deployed(false)
	powered=false
	(_shape.shape as BoxShape3D).size=Vector3(.75,.5,1.9)
	get_node("FoldedCase").scale=Vector3(.75/1.9,1,1.9/.8)
	_clearing=true
	_bump_audio.play()
	return true

func _physics_process(delta: float) -> void:
	if not _can_play(): release_grip()
	if not _can_play(): return
	if _clearing:
		var shift:=clampf(-47.8-global_position.z,-delta*.8,delta*.8)
		move_and_collide(Vector3(0,0,shift))
		if absf(global_position.z+47.8)<.03: _clearing=false
	_noise_clock = maxf(0,_noise_clock-delta)
	_bump_clock = maxf(0,_bump_clock-delta)
	if holder and holder.global_position.distance_to(to_global(Config.GRIP_OFFSET))>1.3: release_grip()

func _process(delta: float) -> void:
	if _viewport==null: return
	_actor_clock -= delta
	if _actor_clock<=0:
		_actor_clock = .5
		# Include appearance parts and reinforcements added after scene ready.
		for actor in get_tree().get_nodes_in_group("guards")+get_tree().get_nodes_in_group("player"):
			for mesh in actor.find_children("*","VisualInstance3D",true,false): mesh.layers=2
	if not deployed or not powered or not _can_play():
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if _image: _image.set_shader_parameter("enabled",false)
		return
	# Preserve the last image while left behind, without rendering an unseen
	# secondary camera throughout the outdoor extraction.
	if (_mission and _mission.has_file) or (is_instance_valid(_viewer) and _viewer.global_position.distance_to(global_position)>24):
		_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	_render_clock -= delta
	if _render_clock>0: return
	_render_clock = .08
	var eye := observer_eye()
	var valid := calibration_valid(eye)
	if holder and _last_calibration_valid and not valid:
		# This signal is in An's headset; unlike the physical cart impact,
		# it intentionally does not emit a world noise for guards to hear.
		_signal_audio.stream=SoundBank.pick("puzzle_wrong")
		_signal_audio.play()
	_last_calibration_valid=valid
	# Outside the calibrated view the old image remains, producing real
	# parallax error. Do not secretly track an observer who left the post.
	if not valid:
		_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		_image.set_shader_parameter("enabled",_has_calibrated_image)
		return
	var center := to_global(Config.SCREEN_CENTER)
	_projector.global_position = eye
	_projector.look_at(center,Vector3.UP)
	_projector.fov = clampf(rad_to_deg(2.0*atan(1.45/maxf(eye.distance_to(center),1.0))),9,65)
	_image.set_shader_parameter("projector_view",_projector.global_transform.affine_inverse())
	_image.set_shader_parameter("projector_projection",_projector.get_camera_projection())
	_image.set_shader_parameter("enabled",true)
	_has_calibrated_image=true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	projection_updates+=1

func observer_eye() -> Vector3:
	var guard := get_tree().get_first_node_in_group("k17_projection_post")
	return guard.vision.global_position if guard and guard.vision else Config.POST_EYE

func camouflages_observer(observer: Guard) -> bool:
	if observer==null or observer.vision==null or observer.get("posted")!=true or not deployed or not powered: return false
	return calibration_valid(observer.vision.global_position)

func calibration_valid(eye: Vector3) -> bool:
	if not deployed or not powered or eye.distance_to(Config.POST_EYE)>Config.MAX_REFERENCE_SHIFT: return false
	var local_eye := to_local(eye)
	if local_eye.z>=-.5: return false
	var angle := rad_to_deg(atan2(absf(local_eye.x),-local_eye.z))
	if angle>Config.ANGLE_LIMIT or eye.distance_to(to_global(Config.SCREEN_CENTER))<4.5: return false
	# Every exposed physical part must fit behind the projected surface.
	for point in hardware_points():
		var local_point := to_local(point)
		var fraction := (-.12-local_eye.z)/(local_point.z-local_eye.z)
		var on_screen := local_eye.lerp(local_point,fraction)
		if absf(on_screen.x)>Config.SCREEN_SIZE.x/2 or on_screen.y<.0 or on_screen.y>Config.SCREEN_HEIGHT: return false
	return true

func hardware_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for point in [Vector3(-.92,.12,.1),Vector3(.92,.12,.1),Vector3(-1.02,2.12,.1),Vector3(1.02,2.12,.1),Vector3(0,1.3,.55),Vector3(0,.3,.55)]: points.append(to_global(point))
	return points

func hardware_visible_to(observer: Guard) -> bool:
	if not deployed or observer.vision==null: return false
	var space := get_world_3d().direct_space_state
	for point in hardware_points():
		if not observer.vision.is_in_view(point): continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(observer.vision.global_position,point,1,[get_rid(),observer.get_rid()]))
		if hit.is_empty(): return true
	return false

func inspection_point_for(observer: Guard) -> Vector3:
	# Approach one side of the screen, never the solid center; this can expose
	# the actual player through ordinary vision while the shared AI searches.
	var side := -1.0 if to_local(observer.global_position).x<0 else 1.0
	var desired := to_global(Vector3(side*1.65,0,.65))
	return NavigationServer3D.map_get_closest_point(observer.agent.get_navigation_map(),desired)

func status_text() -> String:
	if not deployed: return "MÀN CHIẾU · Giữ E tại tay cầm để dựng và hiệu chỉnh"
	if not powered: return "TẮT HÌNH · Tấm màn lộ rõ sẽ khiến lính tới kiểm tra"
	if calibration_valid(observer_eye()) and near_calibration_limit(): return "GẦN LỆCH · Đưa màn vào đúng hướng trước khi ra khỏi vật che"
	if calibration_valid(observer_eye()): return "KHỚP HÌNH · Chỉ che hướng chốt chính · chú ý tuần tra bên hông"
	return "LỆCH HÌNH · Tìm vật che hoặc đưa màn về hướng hiệu chỉnh"

func near_calibration_limit() -> bool:
	var local_eye := to_local(observer_eye())
	return rad_to_deg(atan2(absf(local_eye.x),maxf(.01,-local_eye.z)))>Config.ANGLE_LIMIT*.75 or observer_eye().distance_to(Config.POST_EYE)>.35

func get_checkpoint_state() -> Dictionary:
	# No moving pose/timer here: a checkpoint always restores a safe setup.
	return {"equipment_issued":true}

func restore_checkpoint_state(_saved: Dictionary) -> void:
	release_grip()
	collision_layer=1
	_clearing=false
	global_position = Config.HOME
	global_rotation = Vector3(0,Config.YAW,0)
	_set_deployed(false)
	powered = false
	_noise_clock = 0
	_bump_clock = 0
	_has_calibrated_image=false
	_last_calibration_valid=false
	if _bump_audio: _bump_audio.stop()
	if _signal_audio: _signal_audio.stop()
	if _viewport: _viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED

func _can_play() -> bool:
	return _flow!=null and _flow.state==GameStateMachine.State.PLAYING and not _flow.is_leaving() and not get_tree().paused

func _emit_noise(loudness: float,radius: float,title: String) -> void:
	var system := NoiseSystem.find(self)
	if system: system.emit_noise(global_position+Vector3(0,.2,0),NoiseEvent.Type.INTERACTION,&"projection_rig",loudness,radius,-1,title)
	if loudness>.4:
		_bump_audio.play()
	elif not _wheel_audio.playing:
		_wheel_audio.play()

func _build_audio() -> void:
	# Reuse the project's generated, freely editable mechanical Foley.
	_wheel_audio=_audio_3d("WheelAudio","shutter_rattle",-31.0,1.2,10.0)
	_bump_audio=_audio_3d("BumpAudio","mech_clunk",-17.0,1.0,16.0)
	_signal_audio=AudioStreamPlayer.new()
	_signal_audio.name="HeadsetSignal"
	_signal_audio.volume_db=-24
	_signal_audio.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(_signal_audio)

func _audio_3d(title: String,sound: String,volume: float,pitch: float,range_: float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.name=title
	audio.position=Vector3(0,.2,.1)
	audio.stream=SoundBank.pick(sound)
	audio.volume_db=volume
	audio.pitch_scale=pitch
	audio.unit_size=3.0
	audio.max_distance=range_
	audio.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(audio)
	return audio

func _notify(text: String) -> void:
	var hud := owner.get_node_or_null("ObjectiveHud") if owner else null
	if hud: hud.show_message(text)

func _set_deployed(value: bool) -> void:
	deployed = value
	_upright.visible = value
	(_shape.shape as BoxShape3D).size = Vector3(Config.SOLID_WIDTH,Config.SCREEN_HEIGHT-.04,.28) if value else Vector3(1.9,.5,.8)
	_shape.position = Vector3(0,Config.SCREEN_HEIGHT/2,0) if value else Vector3(0,.25,.2)
	_handle.position = Vector3(0,1.05,.64) if value else Vector3(0,.55,.64)
	get_node("PowerControl").enabled=value
	get_node("FoldControl").enabled=value
	get_node("FoldedCase").visible = not value
	get_node("FoldedCase").scale=Vector3.ONE
	for button in ["FeedControl","CallControl"]: _upright.get_node(button).enabled=value

func _build_model() -> void:
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	add_child(_shape)
	_box(self,"FoldedCase",Vector3(0,.25,.2),Vector3(1.9,.5,.8),Color("344342"))
	_upright = Node3D.new()
	_upright.name = "Upright"
	add_child(_upright)
	_box(_upright,"Backing",Vector3(0,Config.SCREEN_HEIGHT/2,-.04),Vector3(Config.SOLID_WIDTH,Config.SCREEN_HEIGHT-.04,.12),Color("182626"))
	for x in [-1.20,1.20]: _box(_upright,"Frame",Vector3(x,1.23,.08),Vector3(.10,2.4,.15),Color("43534e"))
	_box(_upright,"TopRail",Vector3(0,2.44,.08),Vector3(2.50,.09,.15),Color("43534e"))
	_box(_upright,"Axle",Vector3(0,.13,.22),Vector3(1.85,.10,.55),Color("141b1b"))
	for x in [-.82,.82]:
		var wheel := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius=.12
		cylinder.bottom_radius=.12
		cylinder.height=.09
		wheel.mesh=cylinder
		wheel.position=Vector3(x,.12,.18)
		wheel.rotation.z=PI/2
		wheel.material_override=_material(Color("0e1414"))
		wheel.layers=4
		_upright.add_child(wheel)
	_box(_upright,"Battery",Vector3(0,.5,.3),Vector3(.75,.65,.45),Color("2b3937"))
	for x in [-.55,.55]: _box(_upright,"HandleSupport",Vector3(x,.85,.36),Vector3(.07,.7,.5),Color("43534e"))
	_box(_upright,"Handle",Vector3(0,1.17,.6),Vector3(1.2,.08,.10),Color("1b2625"))
	_box(_upright,"Console",Vector3(.66,1.52,.20),Vector3(.5,.52,.22),Color("344342"))
	_box(_upright,"ConsoleGlass",Vector3(.66,1.58,.319),Vector3(.40,.20,.018),Color("5ba597"))
	var label := Label3D.new()
	label.name="ConsoleLabel"
	label.text="K17 / LAM\nHIỆU CHỈNH 01"
	label.position=Vector3(.66,1.58,.335)
	label.pixel_size=.0009
	label.font_size=24
	label.outline_size=0
	label.layers=4
	_upright.add_child(label)
	_handle = _control("HandleControl",Vector3(0,.55,.64),Vector3(1.35,.6,.18),"grip")
	_control("PowerControl",Vector3(.66,1.30,.34),Vector3(.20,.14,.04),"power")
	_control("FoldControl",Vector3(-.68,1.07,.64),Vector3(.18,.2,.06),"fold")
	_box(_upright,"FrontCamera",Vector3(0,1.65,-.17),Vector3(.12,.10,.10),Color("131d21"))
	for entry in [["FeedControl",Vector3(.3,1.3,.34),"feed"],["CallControl",Vector3(-.05,1.3,.34),"call"]]:
		var button:=preload("res://maps/intelligence/scripts/b1_console.gd").new()
		button.name=entry[0]
		button.position=entry[1]
		button.action=entry[2]
		var hit:=CollisionShape3D.new()
		var box:=BoxShape3D.new()
		box.size=Vector3(.18,.15,.08)
		hit.shape=box
		button.add_child(hit)
		_upright.add_child(button)
		_box(_upright,str(entry[0])+"Button",entry[1],Vector3(.18,.15,.06),Color("91b7b0"))
	_box(_upright,"PowerButton",Vector3(.66,1.3,.32),Vector3(.20,.14,.04),Color("b39e5f"))
	_box(_upright,"FoldSwitch",Vector3(-.68,1.07,.60),Vector3(.18,.2,.1),Color("b39e5f"))

func _control(title: String,p: Vector3,size_: Vector3,action: String) -> Interactable:
	var control := RigControl.new()
	control.name=title
	control.position=p
	control.action=action
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=size_
	collision.shape=shape
	control.add_child(collision)
	add_child(control)
	return control

func _box(parent: Node,title: String,p: Vector3,size_: Vector3,colour: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name=title
	instance.position=p
	var mesh := BoxMesh.new()
	mesh.size=size_
	instance.mesh=mesh
	instance.material_override=_material(colour)
	instance.layers=4
	parent.add_child(instance)
	return instance

func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color=colour
	material.roughness=.72
	return material

func _build_projection() -> void:
	_viewport = SubViewport.new()
	_viewport.name="ProjectionView"
	_viewport.size=Vector2i(512,512)
	_viewport.world_3d=get_world_3d()
	_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	_viewport.audio_listener_enable_3d=false
	add_child(_viewport)
	_projector=Camera3D.new()
	_projector.name="CalibratedEye"
	_projector.cull_mask=1
	_projector.near=.1
	_projector.far=100
	# The main camera applies the filmic curve once. The intermediate view
	# must stay linear, or a second tone-map brightens the apparent wall.
	if get_world_3d().environment:
		var capture_environment := get_world_3d().environment.duplicate() as Environment
		capture_environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
		_projector.environment=capture_environment
	_viewport.add_child(_projector)
	_projector.current=true
	_image=ShaderMaterial.new()
	_image.shader=load("res://maps/intelligence/resources/projection_screen.gdshader")
	_image.set_shader_parameter("image",_viewport.get_texture())
	var face := MeshInstance3D.new()
	face.name="ProjectedFace"
	var quad := QuadMesh.new()
	quad.size=Config.SCREEN_SIZE
	face.mesh=quad
	face.material_override=_image
	face.position=Config.SCREEN_CENTER
	face.rotation.y=PI
	face.layers=4
	_upright.add_child(face)
