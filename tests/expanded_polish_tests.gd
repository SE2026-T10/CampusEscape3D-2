extends RefCounted

## Expansion Phase 9: polish and performance. Called from tests/test_scene.gd.
##
##   A. Mechanism sounds (MechanismAudio, Expanded Library only): a dial turn
##      clicks; a wrong code and a code entered without power buzz; a solved
##      code chimes; an item taken chimes, a refused one doesn't; the panel
##      cover (tool kit) clunks; a circuit switch clunks; thrown items and the
##      badge reader play their sounds through their captions. Every new sound
##      file loads. The tutorial has no MechanismAudio.
##   B. Decor (Layout.DECOR, STAIR_STRIPES): no collision anywhere under
##      Dressing; every box is a floor decal, above head height, or off the
##      navmesh (nothing in walkable space); none is within 0.6 m of anything
##      the player uses or hides in; the new signs are built.
##   C. Readability: the storm drain's state label no longer overlaps the
##      wall's STORM DRAIN · SEALED sign.

const SCENE := "res://scenes/level/expanded_library.tscn"
const TUTORIAL := "res://scenes/level/library_graybox.tscn"
const Layout := preload("res://tools/expanded/expanded_layout.gd")
const X := preload("res://tools/expanded/expansion/expansion_layout.gd")
const TestUtils := preload("res://tests/test_utils.gd")
const M := "Expansion/Gameplay/Mission/"
const NEW_SOUNDS := ["mech_click", "mech_clunk", "puzzle_wrong", "puzzle_solved", "reader_beep", "shutter_rattle",
	"pump_stall", "glass_smash", "item_thud", "item_pickup"]
## Head height: decor whose bottom is at least this far above its floor is out of the way.
const HEAD := 2.3
const CLEARANCE := 0.6

var failures: Array[String] = []
var _host: Node
var _level: Node
var _player: FirstPersonPlayer
var _audio: MechanismAudio


func run(host: Node) -> Array[String]:
	_host = host
	await _load(SCENE)
	await _check_sounds()
	_check_decor()
	_check_drain_label()
	await _load(TUTORIAL)
	_expect(_level.find_children("*", "MechanismAudio", true, false).is_empty(), "The tutorial should have no MechanismAudio.")
	await _unload()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[expanded-polish] " + message)


# --- A. Sounds -------------------------------------------------------------------------------

func _check_sounds() -> void:
	for s in NEW_SOUNDS:
		_expect(SoundBank.pick(s) != null, "Sound %s should load." % s)
	_audio = _level.get_node_or_null("Expansion/Gameplay/MechanismAudio") as MechanismAudio
	_expect(_audio != null, "Expansion/Gameplay/MechanismAudio is missing.")
	if _audio == null:
		return
	# A code lock without a circuit (the security locker): dial, wrong code, right code.
	var lock := _level.get_node_or_null(M + X.MISSION.locker.name) as CodeLock
	_expect(lock != null, "Security locker missing.")
	if lock:
		await _heard(func(): lock.dials[0].interact(_player), "mech_click", "a dial turn")
		await _heard(func(): lock.set_entry("999"); lock.submit(), "puzzle_wrong", "a wrong code")
		await _heard(func(): lock.set_entry(X.MISSION.locker.code); lock.submit(), "puzzle_solved", "the right code")
	# The vault keypad without power buzzes.
	var vault := _level.get_node_or_null(M + X.MISSION.vault_keypad.name) as CodeLock
	if vault and not vault.has_power():
		await _heard(func(): vault.submit(), "puzzle_wrong", "a keypad without power")
	# The tool kit: taken (chime); a refused pickup (hands full) is silent.
	var kit := _level.get_node_or_null("Expansion/Gameplay/Items/ToolKit") as ItemPickup
	_expect(kit != null, "Tool kit missing.")
	if kit:
		await _heard(func(): kit.interact(_player), "item_pickup", "taking the tool kit")
	var inventory: PlayerInventory = _player.get_node("Inventory")
	while not inventory.is_full():
		inventory.add(ItemCatalog.HARDBACK)
	var bottle := _level.get_node_or_null("Expansion/Gameplay/Items/BottleTunnel") as ItemPickup
	if bottle:
		_audio.played.clear()
		bottle.interact(_player)
		await _frames(2)
		_expect(not _audio.played.has("item_pickup"), "A refused pickup (hands full) should not chime.")
	# The panel cover with the tool kit carried.
	var cover := _level.get_node_or_null(M + X.MISSION.panel_cover.name) as ToolMechanism
	if cover:
		await _heard(func(): cover.interact(_player), "mech_clunk", "the panel cover opening")
	# A circuit switch: a clunk if it switched, a buzz if it refused.
	var switches := _level.get_tree().get_nodes_in_group("circuit_switches")
	_expect(not switches.is_empty(), "No circuit switches.")
	if not switches.is_empty():
		_audio.played.clear()
		switches[0].interact(_player)
		await _frames(2)
		_expect(_audio.played.has("mech_clunk") or _audio.played.has("puzzle_wrong"), "A circuit switch should clunk or buzz (got %s)." % [_audio.played])
	# Captioned noises.
	var noise := NoiseSystem.find(_level)
	var at := Vector3(10, X.BF, -25)
	await _heard(func(): noise.emit_noise(at, NoiseEvent.Type.INTERACTION, "distraction", 1.0, 14.0, -1.0, "Glass smashes"), "glass_smash", "a smashed bottle")
	await _heard(func(): noise.emit_noise(at, NoiseEvent.Type.INTERACTION, "environment", 0.7, 8.0, -1.0, "Badge reader beeps"), "reader_beep", "the badge reader")
	# The sound plays where it happened.
	_audio.play_at("mech_clunk", at)
	var playing := 0
	for p in _audio.get_children():
		if p is AudioStreamPlayer3D and p.playing and p.global_position.distance_to(at) < 0.01:
			playing += 1
	_expect(playing >= 1, "MechanismAudio should play at the mechanism's position.")


func _heard(action: Callable, sound: String, what: String) -> void:
	_audio.played.clear()
	action.call()
	await _frames(2)
	_expect(_audio.played.has(sound), "%s should play %s (played %s)." % [what.capitalize(), sound, _audio.played])


# --- B. Decor --------------------------------------------------------------------------------

func _boxes() -> Array:
	var out: Array = []
	for d in X.DECOR:
		out.append({"name": d.name, "aabb": AABB(d.centre - d.size / 2.0, d.size)})
	for st in X.STAIR_STRIPES:
		out.append({"name": st.name, "aabb": AABB(Vector3(st.x0, st.y, st.z - 0.125), Vector3(st.x1 - st.x0, 0.012, 0.25))})
	return out


func _floor_of(y: float) -> float:
	if y < -0.5:
		return X.BF
	return X.UY if y > X.UY - 0.2 else 0.0


func _check_decor() -> void:
	var dressing := _level.get_node("Expansion/Dressing")
	_expect(dressing.find_children("*", "CollisionObject3D", true, false).is_empty(), "Nothing under Dressing should have collision.")
	_expect(dressing.get_node_or_null("Decor") != null, "Dressing/Decor missing.")
	var map: RID = _level.get_world_3d().navigation_map
	var used: Array[Node3D] = []
	for g in ["interactables", "hiding_spots"]:
		for n in _level.get_tree().get_nodes_in_group(g):
			if n is Node3D and n.is_inside_tree():
				used.append(n)
	for b in _boxes():
		var box: AABB = b.aabb
		var ground := _floor_of(box.position.y + 0.05)
		var decal := box.size.y <= 0.03 and absf(box.position.y - ground) < 0.02
		var high := box.position.y - ground >= HEAD
		if not decal and not high:
			# Off the navmesh: no point of its footprint is walkable.
			var walkable := Vector3.INF
			for i in 5:
				for k in 5:
					var p := Vector3(box.position.x + box.size.x * i / 4.0, ground, box.position.z + box.size.z * k / 4.0)
					var c := NavigationServer3D.map_get_closest_point(map, p)
					if absf(c.y - ground) < 0.6 and Vector2(c.x - p.x, c.z - p.z).length() < 0.05:
						walkable = p
			_expect(walkable == Vector3.INF, "Decor %s reaches into walkable space (e.g. at %s)." % [b.name, walkable])
		for n in used:
			var q := n.global_position
			var nearest := Vector3(clampf(q.x, box.position.x, box.end.x), clampf(q.y, box.position.y, box.end.y), clampf(q.z, box.position.z, box.end.z))
			if nearest.distance_to(q) < CLEARANCE:
				_expect(false, "Decor %s is %.2f m from %s (needs %.1f m)." % [b.name, nearest.distance_to(q), n.name, CLEARANCE])
	var signs := dressing.get_node("Signs")
	for s in X.SIGNS:
		var found := false
		for child in signs.get_children():
			var label := child.get_node_or_null("Text") as Label3D
			if label and label.text == s.text:
				found = true
		_expect(found, "Sign %s missing." % s.text)


# --- C. Readability --------------------------------------------------------------------------

func _check_drain_label() -> void:
	var label := _level.get_node_or_null(M + X.MISSION.drain_exit.name + "/Sign") as Label3D
	var wall: Vector3 = Vector3.ZERO
	for s in X.SIGNS:
		if String(s.text).begins_with("STORM DRAIN"):
			wall = s.pos
	_expect(label != null, "Storm drain label missing.")
	if label:
		_expect(wall.y - label.global_position.y >= 0.45, "The storm drain label (y %.2f) should sit clear below the wall sign (y %.2f)." % [label.global_position.y, wall.y])


# --- Helpers ---------------------------------------------------------------------------------

func _load(path: String) -> void:
	await _unload()
	_level = (load(path) as PackedScene).instantiate()
	for g in _level.get_node("Guards").get_children():
		if g is Guard:
			g.get_parent().remove_child(g)
			g.free()
	var probe := Layout.SPAWN if path == SCENE else Vector3(0, 0, 18)
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, probe), "Navigation never became ready.")
	_player = _level.get_node("Player")
	GameFlow.find(_level).change_scene = func(_p): pass
	await _frames(10)


func _unload() -> void:
	if _level and is_instance_valid(_level):
		_level.queue_free()
		await _frames(30)
	_level = null


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
