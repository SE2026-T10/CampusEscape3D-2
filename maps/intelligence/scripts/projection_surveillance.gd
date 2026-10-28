extends Node3D
## Real CCTV and front feeds are separate from the empty projection texture.
const C:=preload("res://maps/intelligence/resources/layout/k17_projection.gd")
var hacked:=false
var revoked:=false
var feed_mode:=0
var pending:=0.0
var cooldown:=0.0
var lockout:=0.0
var calls: Array[float]=[]
var clock:=0.0
var updates:=0
var _viewport: SubViewport
var _camera: Camera3D
var _layer: CanvasLayer
var _panel: PanelContainer
var _image: TextureRect
var _title: Label
var _status: Label
var _tick:=0.0
var _meter:=0.0
var _mission: K17MissionController

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_to_group("k17_b1_surveillance")
	add_to_group("checkpoint_state")
	_mission=MapHudProvider.find_for(self) as K17MissionController
	for entry in [[&"k17_b1_feed",KEY_V],[&"k17_b1_call",KEY_R]]:
		if not InputMap.has_action(entry[0]):
			InputMap.add_action(entry[0])
			var key:=InputEventKey.new()
			key.physical_keycode=entry[1]
			InputMap.action_add_event(entry[0],key)
	if DisplayServer.get_name()!="headless": _build_feed()

func can_play() -> bool:
	var flow:=GameFlow.find(self)
	return flow!=null and flow.state==GameStateMachine.State.PLAYING and not flow.is_leaving() and not get_tree().paused

func hack() -> bool:
	if hacked or revoked or not can_play(): return false
	hacked=true
	feed_mode=1
	_mission.queue_radio("Lam: Kênh B1 đã chiếm. V đổi camera trước/C1/ẩn; R gửi yêu cầu kiểm tra. Đợi chốt quay sang máy rồi mới rẽ vào hốc. W1 và W2 vẫn có lính quan sát.",5,"b1_hacked")
	return true

func cycle_feed() -> void:
	if hacked and not revoked and can_play(): feed_mode=(feed_mode+1)%3

func post() -> Node:
	return get_tree().get_first_node_in_group("k17_projection_post")

func call_status() -> String:
	if revoked: return "Kênh đã thu hồi"
	if not hacked: return "Chưa chiếm kênh"
	if pending>0: return "Đã gửi / đang chờ"
	var guard:=post()
	if guard and guard.check_left>0: return "Chốt kiểm tra máy / %d giây · nhìn C1"%ceili(guard.check_left)
	if lockout>0: return "Đối chiếu kênh / %d giây"%ceili(lockout)
	if cooldown>0: return "Hồi / %d giây"%ceili(cooldown)
	if guard==null: return "Bản thử không có chốt"
	return "R / gửi yêu cầu kiểm tra"

func request_call() -> bool:
	if not can_play() or not hacked or revoked or pending>0 or cooldown>0 or lockout>0: return false
	var guard:=post()
	if guard==null:
		_notify("Bản thử không có lính giữ chốt.")
		return false
	if not guard.can_check_terminal():
		_notify("Chốt đang bận kiểm tra/điều tra — yêu cầu bị từ chối.")
		return false
	while not calls.is_empty() and clock-calls[0]>C.CALL_WINDOW: calls.pop_front()
	if calls.size()>=2:
		lockout=C.CALL_LOCKOUT
		_notify("Máy trực đang đối chiếu nguồn yêu cầu. Chờ 45 giây.")
		return false
	pending=C.CALL_DELAY
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not can_play(): return
	var hud:=get_parent().get_parent().get_node_or_null("ObjectiveHud")
	if hud and hud.is_journal_open(): return
	if event.is_action_pressed(&"k17_b1_feed"):
		cycle_feed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"k17_b1_call"):
		request_call()
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not can_play():
		var flow:=GameFlow.find(self)
		if flow and flow.state not in [GameStateMachine.State.PLAYING,GameStateMachine.State.PAUSED]: pending=0
		return
	clock+=delta
	cooldown=maxf(0,cooldown-delta)
	lockout=maxf(0,lockout-delta)
	if _mission.has_file and not revoked:
		revoked=true
		pending=0
		feed_mode=0
		_notify("B1 / báo động niêm phong: kênh CCTV và yêu cầu giả đã bị thu hồi.")
	if pending>0:
		pending=maxf(0,pending-delta)
		if pending==0:
			var guard:=post()
			if guard and guard.begin_terminal_check(C.CALL_DURATION):
				calls.append(clock)
				cooldown=C.CALL_COOLDOWN
				if calls.size()==2: _notify("Máy trực: yêu cầu lặp — đang đối chiếu kênh.")
			else: _notify("Yêu cầu bị ngắt: chốt đã chuyển nhiệm vụ.")
	# Real unspoofed C1 sees exposed people, never through the screen.
	if not hacked or revoked:
		var player:=get_tree().get_first_node_in_group("player") as FirstPersonPlayer
		if cctv_sees(player):
			_meter+=delta*30
			if _meter>=100:
				_meter=0
				_mission.record_sensor_trip(C.CCTV)
		else: _meter=maxf(0,_meter-delta*20)

func cctv_sees(player: FirstPersonPlayer) -> bool:
	if player==null: return false
	for point in player.get_visibility_points():
		var direction: Vector3=point-C.CCTV
		if direction.length()>36 or Vector3.RIGHT.angle_to(direction)>deg_to_rad(40): continue
		var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(C.CCTV,point,3))
		if not hit.is_empty() and hit.collider==player: return true
	return false

func _build_feed() -> void:
	_viewport=SubViewport.new()
	_viewport.size=Vector2i(480,270)
	_viewport.world_3d=get_world_3d()
	_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	_viewport.audio_listener_enable_3d=false
	add_child(_viewport)
	_camera=Camera3D.new()
	_camera.near=.06
	_camera.far=70
	_camera.cull_mask=7
	_viewport.add_child(_camera)
	_camera.current=true
	_layer=CanvasLayer.new()
	_layer.layer=6
	add_child(_layer)
	_panel=PanelContainer.new()
	_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_panel)
	var column:=VBoxContainer.new()
	_panel.add_child(column)
	_title=Label.new()
	_title.add_theme_font_size_override("font_size",13)
	_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	_image=TextureRect.new()
	_image.texture=_viewport.get_texture()
	_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_image.custom_minimum_size=Vector2(256,144)
	column.add_child(_image)
	_status=Label.new()
	_status.add_theme_font_size_override("font_size",13)
	_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

func _process(delta: float) -> void:
	if _viewport==null: return
	var player:=get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	var hud:=get_parent().get_parent().get_node_or_null("ObjectiveHud")
	var shown: bool=can_play() and hacked and not revoked and feed_mode>0 and player!=null and player.global_position.y< -2 and not (hud and hud.is_journal_open())
	_panel.visible=shown
	_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if not shown: return
	var size_:=get_viewport().get_visible_rect().size
	var left:=350.0
	var right:=size_.x-390
	if hud:
		left=hud._status_panel.get_global_rect().end.x
		right=hud._panel.get_global_rect().position.x
	var width_:=minf(272,maxf(160,right-left-24))
	_panel.position=Vector2(left+12,20)
	_image.custom_minimum_size=Vector2(width_-16,(width_-16)*.5625)
	_panel.size=Vector2(width_,0)
	_title.text="CẢNH THẬT / "+("CAMERA TRƯỚC" if feed_mode==1 else "C1 / TRÊN CHỐT")+" · V đổi"
	_status.text=call_status()
	_tick-=delta
	if _tick>0: return
	_tick=.1
	var rig:=get_tree().get_first_node_in_group("k17_projection_rigs")
	if feed_mode==1 and rig:
		_camera.global_transform=rig.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,1.65,-.23))
	else:
		_camera.global_position=C.CCTV
		_camera.look_at(Vector3(0,-2.7,-47),Vector3.UP)
	_camera.fov=75
	_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	updates+=1

func _notify(message: String) -> void:
	var hud:=get_parent().get_parent().get_node_or_null("ObjectiveHud")
	if hud: hud.show_message(message)

func get_checkpoint_state() -> Dictionary:
	return {"hacked":hacked}

func restore_checkpoint_state(saved: Dictionary) -> void:
	hacked=bool(saved.get("hacked",false))
	revoked=false
	pending=0
	cooldown=0
	lockout=0
	calls.clear()
	clock=0
	_meter=0
	feed_mode=0
	if _panel: _panel.hide()
	if _viewport: _viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
