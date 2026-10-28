extends RefCounted
## Real-scene fixtures: physical mounting, input rays and live transform/UI behaviour.
## These isolated fixtures are distinct from the full walking E2E.
const Utils := preload("res://tests/test_utils.gd")
const Mount := preload("res://maps/intelligence/resources/layout/k17_navigation.gd")
const Minimap := preload("res://maps/intelligence/scripts/minimap.gd")
const V4 := preload("res://maps/intelligence/resources/layout/k17_v4.gd")
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
var host: Node
var level: Node3D
var player: FirstPersonPlayer
var minimap: Minimap
var checks := 0
var failures: Array[String]=[]

func run(parent: Node) -> Array[String]:
	host=parent
	level=load("res://maps/intelligence/scenes/intelligence_k17_test.tscn").instantiate()
	host.add_child(level)
	await _frames(35)
	player=level.get_node("Player")
	player.set_physics_process(false)
	for camera in host.get_tree().get_nodes_in_group("security_cameras"): camera.set_physics_process(false)
	minimap=level.get_node("ObjectiveHud/Minimap")
	await _mount_and_input()
	await _map_and_actor()
	await _ui_states()
	await _v5_finale()
	host.get_tree().paused=false
	level.queue_free()
	await _frames(40)
	# The normal scene must use the very same runtime map and physical keypad.
	level=load("res://maps/intelligence/scenes/intelligence_k17.tscn").instantiate()
	host.add_child(level)
	await _frames(20)
	_expect(level.has_node("ObjectiveHud/Minimap/PlayerMarker") and level.has_node("Gameplay/VaultKeypad/Housing/Case"),"Normal mode has the same minimap and unified keypad")
	_expect(level.get_node("Gameplay/VaultKeypad").position.is_equal_approx(Mount.KEYPAD),"Normal mode uses the wall mounting configuration")
	level.queue_free()
	await _frames(40)
	print("K17 NAVIGATION CHECKS: %d checks; %d failures"%[checks,failures.size()])
	return failures

func _mount_and_input() -> void:
	var keypad: CodeLock=level.get_node("Gameplay/VaultKeypad")
	var casing: MeshInstance3D=keypad.get_node("Housing/Case")
	_expect(keypad.position.is_equal_approx(Mount.KEYPAD),"Keypad is mounted beside the door")
	var solid_bounds: AABB=casing.global_transform*casing.get_aabb()
	for x in [-.5,.5]:
		for y in [-.45,.45]:
			var back:=keypad.to_global(Mount.CASE_CENTER+Vector3(x,y,-Mount.CASE_SIZE.z/2))
			var ray:=PhysicsRayQueryParameters3D.create(back+Vector3(0,0,.004),back-Vector3(0,0,.025),1)
			var hit:=player.get_world_3d().direct_space_state.intersect_ray(ray)
			_expect(not hit.is_empty() and str(hit.collider.get_path()).ends_with("NavigationRegion3D/North1"),"Case back has fixed wall support: %s / %s"%[x,y])
	for control in keypad.dials+[keypad.enter]:
		var cap: MeshInstance3D=control.get_node("Model/Cap")
		var bounds: AABB=cap.global_transform*cap.get_aabb()
		var gap:=bounds.position.z-solid_bounds.end.z
		_expect(absf(gap)<=.002,"Resting key is seated in its housing: "+str(control.name))
		var start:=casing.to_local(cap.global_position+Vector3(0,0,.025))
		var end:=casing.to_local(cap.global_position-Vector3(0,0,.05))
		_expect(not casing.mesh.generate_triangle_mesh().intersect_segment(start,end).is_empty(),"Actual housing surface backs key: "+str(control.name))
	player.position=Mount.KEYPAD_STAND
	var objectives:=ObjectiveManager.find(level)
	PlayerInventory.find(level).add(ItemCatalog.STAFF_CARD)
	for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE]: objectives.complete(id)
	await _frames(5)
	for crouch in [false,true]:
		player.set_crouching(crouch)
		player.head.position.y=player.crouch_eye_height if crouch else player.stand_eye_height
		for control in keypad.dials+[keypad.enter]:
			player.camera.look_at(control.global_position)
			await _frames(3)
			_expect(player.get_node("Interactor").focused==control,"Real interaction ray reaches %s, crouch=%s"%[control.name,crouch])
			if control!=keypad.enter:
				var before:=int(control.get_value())
				_push("interact",true)
				await _frames(3)
				var cap: MeshInstance3D=control.get_node("Model/Cap")
				var pressed: AABB=cap.global_transform*cap.get_aabb()
				_expect(pressed.position.z<=solid_bounds.end.z+.002,"Pressed key stays seated: "+str(control.name))
				_push("interact",false)
				await _frames(12)
				_expect(int(control.get_value())==(before+1)%10,"E actually advances digit once: "+str(control.name))
	player.set_crouching(false)
	player.head.position.y=player.stand_eye_height
	keypad.set_entry(V4.VAULT_CODE)
	player.camera.look_at(keypad.enter.global_position)
	await _frames(3)
	var mount_pose:=keypad.global_transform
	_push("interact",true)
	await _frames(6)
	_push("interact",false)
	var door: AccessDoor=level.get_node("Gameplay/VaultDoor")
	var leaf: Node3D=door.get_node("DoorHinge")
	_expect(keypad.is_solved and door.is_open,"Real E confirmation opens vault")
	_expect(leaf.is_visible_in_tree() and leaf.rotation.y>0,"Opening leaf remains visible")
	await _frames(45)
	_expect(leaf.is_visible_in_tree() and absf(leaf.rotation_degrees.y-90)<.01,"Fully open leaf remains visible at its hinge")
	_expect(keypad.global_transform.is_equal_approx(mount_pose),"Wall-mounted keypad stays fixed when the door moves")
	var ray:=PhysicsRayQueryParameters3D.create(Vector3(4,1.2,-23),Vector3(4,1.2,-25),1)
	_expect(player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Open doorway is physically clear")
	door.restore_checkpoint_state({"open":false})
	_expect(leaf.is_visible_in_tree() and is_zero_approx(leaf.rotation.y),"Checkpoint closes the visible leaf")
	_expect(not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Restored closed door blocks the passage")

func _map_and_actor() -> void:
	var data:=minimap.layout
	_expect(data.ground_bounds.is_equal_approx(Rect2(-48,-53,96,108)),"Generated surface bounds match the compound")
	_expect(data.basement_bounds.is_equal_approx(Rect2(-21,-54.8,57,32.8)),"Generated underground frame includes both stairs")
	_expect(data.stairs.size()==2 and data.shapes_for(0,"walls").size()>50 and data.shapes_for(1,"walls").size()>10,"Generated plan has actual walls and both stairwells")
	_expect(not data.shapes_for(0,"floors").any(func(area: Rect2): return area.has_point(Vector2(4,-29))),"Ground plan preserves the stairwell hole")
	for point in [Vector3(-36,0,51),Vector3(36,0,51),Vector3(-36,0,4),Vector3(8,0,-20),Mount.KEYPAD_STAND,Vector3(4,-4,-35),Vector3(0,-4,-48.5),Vector3(30,-4,-38)]:
		player.position=point
		await _frames(2)
		_expect(minimap.marker_local.distance_to(point)<.0001,"Marker reads the live actor at "+str(point))
		_expect(minimap.marker.position.distance_to(minimap.project_local(point))<.01,"Rendered marker is at the projected live position")
	player.position=Vector3(0,0,1)
	await _frames(2)
	_expect(minimap.marker.position.distance_to(minimap.map_rect().get_center())<.01,"True compound centre is centred on the minimap")
	player.position=Vector3(-48,0,-53)
	await _frames(2)
	_expect(minimap.marker.position.y>=minimap.map_rect().position.y and minimap.marker.position.x<minimap.map_rect().get_center().x,"North-west boundary stays north-west without wrapping")
	for yaw in [0.0,PI/2,PI,-PI/2]:
		player.rotation.y=yaw
		await _frames(2)
		_expect(absf(angle_difference(minimap.marker_heading,-yaw))<.001,"Body heading matches arrow at yaw "+str(yaw))
	player.head.rotation.x=1.2
	await _frames(2)
	_expect(absf(angle_difference(minimap.marker_heading,PI/2))<.001,"Looking up does not change compass heading")
	player.position=Vector3(4,-2.5,-30)
	await _frames(2)
	_expect(minimap.floor_id==1,"Descending changes to B1")
	for height in [-2.1,-1.9,-2.2]:
		player.position.y=height
		await _frames(2)
		_expect(minimap.floor_id==1,"Stair hysteresis prevents floor flicker")
	player.position.y=-1.5
	await _frames(2)
	_expect(minimap.floor_id==0,"Ascending changes to ground")
	level.transform=Transform3D(Basis(Vector3.UP,.65),Vector3(17,5,-13))
	player.position=Vector3(30,-4,-38)
	player.rotation.y=.5
	await _frames(2)
	_expect(minimap.marker_local.distance_to(player.position)<.0001 and absf(angle_difference(minimap.marker_heading,-.5))<.001,"Translated/rotated map root preserves local position and heading")
	level.transform=Transform3D.IDENTITY
	player.respawn()
	await _frames(2)
	_expect(minimap.floor_id==0 and minimap.marker_local.distance_to(player.position)<.001,"Respawn immediately restores correct marker and floor")

func _ui_states() -> void:
	var hud:=level.get_node("ObjectiveHud") as ObjectiveHud
	var window:=host.get_window()
	var original_size:=window.size
	var original_scale:=GameSettings.hud_scale
	for size_ in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1920,1080)]:
		window.size=size_
		for scale_ in [1.0,1.25]:
			GameSettings.hud_scale=scale_
			GameSettings.apply(host.get_tree())
			hud.show_message("Đã nhận mục tiêu tùy chọn. Đặt thiết bị rồi tới tập kết trước khi hết 120 giây.")
			await _frames(6)
			var controls:=hud.get_layout_controls()
			var map_rect:=minimap.get_global_rect()
			_expect(hud.get_viewport().get_visible_rect().grow(1).encloses(map_rect),"Minimap fits viewport: %s / %s"%[size_,scale_])
			for id in ["objectives","status","slots","message","prompt"]:
				_expect(not map_rect.intersects(controls[id].get_global_rect()),"Minimap clears %s: %s / %s"%[id,size_,scale_])
	hud.open_journal(&"")
	await _frames(2)
	_expect(not minimap.visible,"Journal hides minimap")
	hud.close_journal()
	_push("k17_minimap",true)
	_push("k17_minimap",false)
	await _frames(2)
	_expect(not minimap.enabled and not minimap.visible,"M hides minimap")
	var flow:=GameFlow.find(level)
	flow.pause()
	await _frames(2)
	_expect(not minimap.visible,"Pause hides minimap")
	flow.resume()
	await _frames(2)
	_expect(not minimap.visible,"Resume preserves the hidden preference")
	_push("k17_minimap",true)
	_push("k17_minimap",false)
	await _frames(2)
	_expect(minimap.visible,"M restores minimap")
	hud.hide()
	await _frames(2)
	_expect(not minimap.is_visible_in_tree(),"V5 HUD suppression also hides minimap")
	hud.show()
	flow.fail("Navigation UI fixture")
	await _frames(2)
	_expect(not minimap.visible,"Terminal failure hides minimap")
	flow.retry_checkpoint()
	await _frames(3)
	_expect(minimap.visible and minimap.marker_local.distance_to(player.position)<.001,"Retry restores marker from the respawned player")
	flow.machine.request(GameStateMachine.State.CAUGHT)
	await _frames(2)
	_expect(not minimap.visible,"Caught screen hides minimap")
	flow.machine.request(GameStateMachine.State.PLAYING)
	window.size=original_size
	GameSettings.hud_scale=original_scale
	GameSettings.apply(host.get_tree())

func _v5_finale() -> void:
	for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE,M.VAULT,M.FILE]: ObjectiveManager.find(level).complete(id)
	var device:=level.get_node("Gameplay/Sabotage")
	_expect(device.plant(),"V5 fixture plants after acquiring the document")
	_expect(level.get_node("Gameplay/Mission").try_extract(&"maintenance","Bảo trì"),"V5 fixture begins armed extraction")
	await _frames(12)
	_expect(level.get_node("Gameplay/ExtractionFinale").active and not minimap.is_visible_in_tree(),"Actual V5 finale hides minimap with the mission HUD")
	await _frames(260)
	_expect(GameFlow.find(level).state==GameStateMachine.State.WIN and not minimap.is_visible_in_tree(),"Actual V5 victory keeps minimap hidden")

func _push(action: String,pressed: bool) -> void:
	var event:=InputEventAction.new()
	event.action=action
	event.pressed=pressed
	host.get_window().push_input(event)

func _frames(count: int) -> void:
	for i in count: await host.get_tree().physics_frame

func _expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append("[K17 navigation] "+message)
