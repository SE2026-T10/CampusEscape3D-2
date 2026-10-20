extends SceneTree

## Development tool: screenshots of the Phase 3 mechanics (stamina and
## inventory) as the player sees them, HUD included:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x1000 \
##       --script res://tools/expanded/expansion/capture_mechanics.gd -- --out=docs/expanded/expansion/phase-3/screens
## Options: --out=PATH (relative to the project), --tutorial (only the
## tutorial's HUD, for the regression picture). Guards are frozen where they
## start (and kept out of the shots); real input drives the player.

const X := preload("res://tools/expanded/expansion/expansion_layout.gd")
const SCENE := "res://scenes/level/expanded_library.tscn"
const TUTORIAL := "res://scenes/level/library_graybox.tscn"
const B := X.BF

var _level: Node3D
var _player: FirstPersonPlayer
var _inventory: PlayerInventory
var _out := ""
var _shots := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_out = "docs/expanded/expansion/phase-3/screens"
	var tutorial := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a == "--tutorial":
			tutorial = true
	if DisplayServer.get_name() == "headless":
		push_error("capture_mechanics needs a display (run under xvfb-run).")
		quit(1)
		return
	var dir := ProjectSettings.globalize_path("res://" + _out)
	DirAccess.make_dir_recursive_absolute(dir)
	_level = (load(TUTORIAL if tutorial else SCENE) as PackedScene).instantiate()
	for g in _level.get_node("Guards").get_children():
		if g is Guard:
			g.get_parent().remove_child(g)
			g.free()
	root.add_child(_level)
	GameFlow.find(_level).change_scene = func(_path: String): pass
	_player = _level.get_node("Player")
	_inventory = _player.get_node_or_null("Inventory")
	var debug := _level.get_node_or_null("DetectionDebugHud")
	if debug:
		debug.visible = false
	await _wait(30)
	if tutorial:
		await _stand(Vector3(0, 0, 21), Vector3(0, 1.4, 12))
		await _hold(["sprint", "move_forward"], 40)
		await _shot(dir, "t01_tutorial_hud_unchanged")
		_release()
		await _finish(dir)
		return
	var objectives: ObjectiveManager = _level.get_node("Gameplay/ObjectiveManager")
	objectives.complete(&"enter_library")

	# 1. A tool kit on the maintenance bay crate, with its prompt.
	var kit: Node3D = _level.get_node("Expansion/Gameplay/Items/ToolKit")
	await _stand(Vector3(-24.8, B, -20.2), kit.global_position + Vector3(0, 0.12, 0))
	await _shot(dir, "m01_take_the_tool_kit")
	await _press("interact")
	# 2. Stamina while sprinting along the tunnel (about 3.5 s in), then nearly empty.
	await _stand(Vector3(-35.0, B, -24.8), Vector3(10.0, B + 1.5, -24.8))
	await _hold(["sprint", "move_forward"], 210)
	await _shot(dir, "m02_stamina_draining_while_sprinting")
	await _hold(["sprint", "move_forward"], 100)
	await _shot(dir, "m03_stamina_empty_walking")
	_release()
	# 3. Three items: hands full at the fourth.
	for item in [["BottleTunnel", Vector3(-14.0, B, -24.3)], ["HardbackTunnel", Vector3(19.0, B, -25.6)]]:
		var node: Node3D = _level.get_node("Expansion/Gameplay/Items/" + item[0])
		await _stand(item[1], node.global_position + Vector3(0, 0.12, 0))
		await _press("interact")
	var fourth: Node3D = _level.get_node("Expansion/Gameplay/Items/BottleCableBay")
	await _stand(Vector3(44.0, B, -19.2), fourth.global_position + Vector3(0, 0.12, 0))
	await _press("interact")
	await _shot(dir, "m04_hands_full_three_slots")
	# 4. A throw down the tunnel: the bottle in flight, then on the floor.
	await _press("item_slot_2")
	await _stand(Vector3(30.0, B, -25.0), Vector3(22.0, B, -25.0))
	await _press("use_item")
	await _wait(10)
	await _shot(dir, "m05_bottle_thrown")
	await _wait(40)
	await _shot(dir, "m06_bottle_landed_noise")
	# 5. The electrical room shelf: leave the hardback.
	await _press("item_slot_3")
	var shelf: Node3D = _level.get_node("Expansion/Gameplay/Storage/ElectricalShelf")
	var front := shelf.global_basis.z
	await _stand(Vector3(shelf.global_position.x + front.x * 1.3, 0, shelf.global_position.z + front.z * 1.3), shelf.global_position + Vector3(0, -0.1, 0))
	await _shot(dir, "m07_storage_shelf_prompt")
	await _press("interact")
	await _wait(5)
	await _shot(dir, "m08_item_left_on_shelf")
	# 6. A document: the journal.
	var notice: Node3D = _level.get_node("Expansion/Gameplay/Documents/ElectricalNotice")
	await _stand(Vector3(notice.global_position.x - 1.3, 0, notice.global_position.z), notice.global_position)
	await _shot(dir, "m09_read_the_notice_prompt")
	await _press("interact")
	await _wait(5)
	await _shot(dir, "m10_journal")
	await _press("journal")
	# 7. The staff card as a carried item and the card door from inside the electrical room.
	var card: AccessCard = _level.get_node("Gameplay/StaffAccessCard")
	card.interact(_player)
	var door: Node3D = _level.get_node("Expansion/Gameplay/ElectricalRoomDoor")
	await _stand(Vector3(37.6, 0, -23.0), door.global_position)
	await _shot(dir, "m11_card_carried_door_opens")
	await _finish(dir)


func _finish(dir: String) -> void:
	print("Captured %d views → %s" % [_shots, dir])
	_level.queue_free()
	for i in 30:
		await process_frame
	quit(0)


func _stand(at: Vector3, target: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = atan2(-(target.x - at.x), -(target.z - at.z))
	var eye := at.y + _player.stand_eye_height
	_player.head.rotation.x = atan2(target.y - eye, Vector2(target.x - at.x, target.z - at.z).length())
	await _wait(12)


func _hold(actions: Array, frames: int) -> void:
	for a in actions:
		Input.action_press(a)
	for i in frames:
		await physics_frame


func _release() -> void:
	for a in ["sprint", "move_forward", "crouch"]:
		Input.action_release(a)


func _press(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await _wait(2)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await _wait(3)


func _shot(dir: String, shot_name: String) -> void:
	await _wait(6)
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))
	_shots += 1


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
