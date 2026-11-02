extends RefCounted

## Expanded Library improvements approved by the owner on 2026-10-31. Called from
## tests/test_scene.gd.
##
##   A. Ambience: every Layout.AMBIENCE emitter is an AmbientEmitter on the Ambience
##      bus with a sound that loads; the four new loops are imported looping and play.
##   B. Archive emergency lighting: without archive_access the archive's lamps are out
##      and the red beacons on; power on flickers the lamps back and puts the beacons
##      out; a restored "off" is immediate; the beacons never take a mesh over the
##      renderer's 8 lights (the polish suite checks the whole level).
##   C. Windows stay removed (the night view was taken out again on request): no window
##      is visible, the night texture and the outside rain (the porch loop) are gone.
##   D. Wayfinding: the directory stand is solid and clear of the entrance and the
##      lobby guard's loop; the floor inlays and hanging signs have no collision; the
##      hanging signs are above the doorway height.
##   E. Staff-corridor guard: GuardStaff on P6_StaffCorridor (3 points, the corridor
##      and Office 2), its loop away from the Office 1 door; it walks the whole loop;
##      no point of the loop can see the Staff Offices respawn.
##   F. Reserve shelf: the objective in the scene is the layout's; the three books lie
##      where a player can reach them; the slip and the memo discover the objective;
##      a wrong book is refused quietly; the right ones are shelved; the third opens
##      the cabinet, reveals the key and completes the objective; a checkpoint restore
##      takes back what was shelved since; the key opens the dock shutter by hand
##      without power, the HUD names the key, and a restore closes it again.
##   G. Study 4 (requested 2026-10-31): the reserve slip (and the Office 1 memo, on its east
##      wall) is a clue board with its lamp,
##      on the wall clear of the whiteboard; the Study 4 storage shelf is in the room, starts empty, and takes a
##      reserve book and gives it back.
##   H. Reserve shelf with real aiming (fixed 2026-11-02): standing in front of the
##      bookcase, the player's interaction ray reaches each gap and the dock key in the
##      cabinet (the bookcase's solid collider used to stop it), and a book is shelved
##      and the key taken through the ray, as a player does it.
##   I. Cameras (2026-11-02, on request): all five are stationary; every ray end of every
##      view cone can be seen from its lens (nothing of a cone is behind a wall or floor);
##      the staff corridor camera's cone stays above the upper floor (it used to show in
##      Study 4 below); a wall put in front of a camera cuts its cone, which comes back
##      when the wall is gone.
##   J. Item models (2026-11-02, on request): every carried item's model is several parts
##      resting on the floor within about its size; the pickups in the level use them; the
##      staff card on its desk and the rare manuscript build their new models (glowing, on
##      render layer 8) and their old boxes are gone.
##   K. Item "!" (2026-11-02, on request): every item lying in the level has a "!" that
##      shows while it is there and goes with it when taken (and comes back on a restore);
##      the dock key's and the locker items' float in front of the cabinet and the locker;
##      an item put on a storage shelf has none; the staff card on its desk and the rare
##      manuscript show one above their labels.
##   L. No guard snags (2026-11-02, a guard got stuck on Office 2's bin): the navmesh bake
##      ignores solid props lower than 0.5 m, so every such prop must stand out of a
##      guard's reach (0.4 m) of the walkable area; the office bins are on the back walls;
##      the other low props (Book Processing bins, step stools, mop bucket, porch benches)
##      have 0.5 m collision, so the walkable area keeps 0.5 m clear of them.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const Layout := preload("res://maps/library/tools/expanded_layout.gd")
const X := preload("res://maps/library/tools/expansion/expansion_layout.gd")
const TestUtils := preload("res://tests/test_utils.gd")
const M := "Expansion/Gameplay/Mission/"
const NEW_LOOPS := ["amb_basement_hum", "amb_electrical_buzz", "amb_drips", "amb_air_handling"]

var failures: Array[String] = []
var _host: Node
var _level: Node
var _player: FirstPersonPlayer
var _inventory: PlayerInventory


func run(host: Node) -> Array[String]:
	_host = host
	await _load(true)
	await _check_ambience()
	await _check_archive_lights()
	_check_windows()
	_check_wayfinding()
	await _check_reserve_shelf()
	await _check_study4()
	await _check_reserve_aim()
	await _check_cameras()
	_check_item_models()
	await _check_item_markers()
	_check_guard_snags()
	await _load(false)
	await _check_staff_guard()
	await _unload()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[expanded-improvements] " + message)


# --- A. Ambience -----------------------------------------------------------------------------

func _check_ambience() -> void:
	var root := _level.get_node_or_null("Expansion/Ambience")
	_expect(root != null, "Expansion/Ambience exists.")
	if root == null:
		return
	for a in X.AMBIENCE:
		var e := root.get_node_or_null(a.name) as AmbientEmitter
		_expect(e != null, "Ambient emitter %s exists." % a.name)
		if e == null:
			continue
		_expect(e.bus == &"Ambience", "%s plays on the Ambience bus." % a.name)
		_expect(e.global_position.distance_to(a.pos) < 0.01, "%s is where the layout puts it." % a.name)
		if a.has("loop"):
			_expect(e.loop_sound == a.loop and e.stream != null, "%s loops %s." % [a.name, a.loop])
		else:
			for s in a.sounds:
				_expect(SoundBank.pick(s) != null, "%s's sound %s loads." % [a.name, s])
	for name in NEW_LOOPS:
		_expect(name in SoundBank.LOOPED, "%s is a looped sound." % name)
		var stream := SoundBank.pick(name) as AudioStreamWAV
		_expect(stream != null and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED, "%s is imported looping." % name)
		_expect(stream != null and stream.get_length() > 7.0, "%s is a long loop (%.1f s)." % [name, stream.get_length() if stream else 0.0])


# --- B. Archive emergency lighting -----------------------------------------------------------

func _check_archive_lights() -> void:
	var lights := _level.get_node_or_null("Expansion/Gameplay/ArchiveLights") as ArchivePowerLights
	_expect(lights != null, "ArchiveLights exists.")
	if lights == null:
		return
	var network := PowerNetwork.find(_level)
	var lamps: Array[Light3D] = []
	for name in X.ARCHIVE_LAMPS:
		lamps.append(_level.get_node("Dressing/Lights/%s/Light" % name) as Light3D)
	var beacons := lights.find_children("Light", "OmniLight3D", true, false)
	_expect(beacons.size() == X.ARCHIVE_BEACONS.size(), "%d emergency beacons (%d)." % [X.ARCHIVE_BEACONS.size(), beacons.size()])
	_expect(not network.is_powered(&"archive_access") and not lights.lit, "The archive starts without power, its lamps out.")
	_expect(lamps.all(func(l): return not l.visible), "Every archive lamp is out before the power puzzle.")
	_expect(beacons.all(func(b): return (b as Node3D).is_visible_in_tree()), "The emergency beacons glow before the power puzzle.")
	_expect(_lights_per_mesh() == "", "At most 8 lights reach a mesh with the archive dark: %s" % _lights_per_mesh())
	network.set_powered(&"archive_access", true)
	_expect(lights.flickers == 1, "Power on starts one flicker.")
	await _wait(1.2)
	_expect(lights.lit and lamps.all(func(l): return l.visible), "The archive lamps are on after the flicker.")
	_expect(beacons.all(func(b): return not (b as Node3D).is_visible_in_tree()), "The beacons are out with the power on.")
	_expect(_lights_per_mesh() == "", "At most 8 lights reach a mesh with the archive lit: %s" % _lights_per_mesh())
	network.restore_checkpoint_state({"powered": {&"archive_access": false, &"surveillance": true, &"service_exit": false}})
	_expect(not lights.lit and lamps.all(func(l): return not l.visible), "A restored 'off' puts the lamps out at once.")
	_expect(lights.flickers == 1, "A restore to off does not flicker.")


## "" if no mesh in the archive beacons' reach is reached by more than 8 visible omni
## lights, else the first few that are (the whole level is checked by the polish suite).
func _lights_per_mesh() -> String:
	var near: Array[AABB] = []
	for b in _level.get_node("Expansion/Gameplay/ArchiveLights").find_children("Light", "OmniLight3D", true, false):
		var o := b as OmniLight3D
		near.append(AABB(o.global_position - Vector3.ONE * o.omni_range, Vector3.ONE * o.omni_range * 2.0))
	var lights := []
	for l in _level.find_children("*", "OmniLight3D", true, false):
		var o := l as OmniLight3D
		if o.is_visible_in_tree():
			var beacon := _level.get_node("Expansion/Gameplay/ArchiveLights").is_ancestor_of(o)
			lights.append([AABB(o.global_position - Vector3.ONE * o.omni_range, Vector3.ONE * o.omni_range * 2.0), o.light_cull_mask, beacon])
	var over: Array[String] = []
	for gi in _level.find_children("*", "GeometryInstance3D", true, false):
		var box := AABB()
		if gi is BatchedBoxes:
			var b := gi as BatchedBoxes
			if b.box_count() == 0:
				continue
			box = b.global_transform * (b.box_transform(0) * AABB(-Vector3.ONE / 2.0, Vector3.ONE))
			for i in b.box_count():
				box = box.merge(b.global_transform * (b.box_transform(i) * AABB(-Vector3.ONE / 2.0, Vector3.ONE)))
		elif gi is MeshInstance3D and (gi as MeshInstance3D).mesh and gi.is_visible_in_tree():
			box = gi.global_transform * (gi as MeshInstance3D).get_aabb()
		else:
			continue
		if not near.any(func(a): return (a as AABB).intersects(box)):
			continue
		var n := 0
		var from_beacons := 0
		for l in lights:
			if (l[1] & gi.layers) != 0 and (l[0] as AABB).intersects(box):
				n += 1
				if l[2]:
					from_beacons += 1
		# Over 8 only because of the beacons (meshes already over without them are not theirs).
		if n > 8 and n - from_beacons <= 8 and from_beacons > 0 and over.size() < 4:
			over.append("%s (%d)" % [_level.get_path_to(gi), n])
	return ", ".join(over)


# --- C. Windows stay removed ------------------------------------------------------------------

## The windows were brought back with a night view and taken out again the same day, on
## request (2026-10-31): no window glass, frame or sill is visible, and the night view and
## the outside rain are gone.
func _check_windows() -> void:
	var glass := 0
	for b in _level.find_children("*_window_*", "BatchedBoxes", true, false):
		if (b as Node3D).is_visible_in_tree():
			glass += (b as BatchedBoxes).box_count()
	_expect(glass == 0, "No window glass is visible (%d panes)." % glass)
	var windows := _level.get_node_or_null("Dressing/Windows") as Node3D
	_expect(windows == null or not windows.is_visible_in_tree(), "The Windows group is hidden.")
	_expect(not ResourceLoader.exists("res://maps/library/assets/textures/night_sky.png"), "The night view texture is gone.")
	_expect(not "amb_rain" in SoundBank.LOOPED and not "amb_rain" in SoundBank.SINGLE, "The outside rain loop is gone.")
	for a in X.AMBIENCE:
		_expect(a.get("loop", "") != "amb_rain" and not "amb_rain" in a.get("sounds", []), "Ambient emitter %s plays no outside rain." % a.name)
	_expect(_level.get_node_or_null("Expansion/Ambience/PorchRain") == null, "The porch rain emitter is gone.")

# --- D. Wayfinding ---------------------------------------------------------------------------

func _check_wayfinding() -> void:
	var stand := _level.get_node_or_null("Expansion/Geometry/A_LobbyProps/DirectoryStand") as Node3D
	_expect(stand != null, "The directory stand exists.")
	if stand:
		_expect(stand.find_children("*", "CollisionShape3D", true, false).size() > 0, "The directory stand is solid.")
		var p := stand.global_position
		_expect(Vector2(p.x, p.z).distance_to(Vector2(0, 27.5)) > 4.0, "The stand is clear of the main entrance.")
		var lobby: Dictionary = Layout.PATROLS[0]
		for k in lobby.points.size():
			var a: Array = lobby.points[k]
			var b: Array = lobby.points[(k + 1) % lobby.points.size()]
			var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(a[0], a[1]), Vector2(b[0], b[1]))
			_expect(q.distance_to(Vector2(p.x, p.z)) > 1.0, "The stand is off the lobby guard's loop (leg %d)." % k)
	var way := _level.get_node_or_null("Expansion/Dressing/Wayfinding")
	_expect(way != null and way.find_children("*", "CollisionShape3D", true, false).is_empty(), "The inlays and hanging signs have no collision.")
	if way:
		for name in ["HangingStacks", "HangingStair"]:
			var s := way.get_node_or_null(name) as Node3D
			_expect(s != null and s.global_position.y - 0.25 > X.DOOR_HEIGHT, "%s hangs above the doorway height." % name)
		_expect(way.find_children("Text*", "Label3D", true, false).size() >= 6, "The inlays and signs are lettered.")


# --- E. Staff-corridor guard -----------------------------------------------------------------

func _check_staff_guard() -> void:
	var guard := _level.get_node_or_null("Guards/GuardStaff") as Guard
	var route := _level.get_node_or_null("Guards/P6_StaffCorridor") as Node3D
	_expect(guard != null and route != null, "GuardStaff and P6_StaffCorridor exist.")
	if guard == null or route == null:
		return
	var points: Array[Vector3] = []
	for p in route.get_children():
		if p is Marker3D:
			points.append((p as Node3D).global_position)
	_expect(points.size() == 3, "P6 has 3 points (%d)." % points.size())
	var office1_door := Vector2(-3.0, -14.0)
	for p in points:
		_expect(p.y > 4.0 and p.x > -1.0 and p.x < 12.0 and p.z > -19.0 and p.z < -8.0, "P6 point %s is in the staff corridor or Office 2." % p)
		_expect(Vector2(p.x, p.z).distance_to(office1_door) > 3.0, "P6 point %s keeps off the Office 1 door." % p)
	# No point of the loop can see the Staff Offices respawn (eye to the player's eye height).
	var spawn := (_level.get_node("Gameplay/CheckpointStaffOffices") as Checkpoint).get_spawn_transform().origin
	var space := (_level as Node3D).get_world_3d().direct_space_state
	for p in points:
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.6, 0), spawn + Vector3(0, 1.5, 0), 1)
		_expect(not space.intersect_ray(q).is_empty(), "The respawn in Office 1 is out of sight from P6 point %s." % p)
	# It walks its whole loop.
	var reached := {}
	guard.patrol_point_reached.connect(func(i): reached[i] = true)
	var stuck := [0]
	guard.got_stuck.connect(func(_i): stuck[0] += 1)
	for i in 50 * 60:
		await _host.get_tree().physics_frame
		if reached.size() == points.size() and i > 600:
			break
	_expect(reached.size() == points.size(), "GuardStaff reached every point of its loop (%s)." % [reached.keys()])
	_expect(stuck[0] == 0, "GuardStaff never got stuck (%d)." % stuck[0])


# --- F. Reserve shelf ------------------------------------------------------------------------

func _check_reserve_shelf() -> void:
	var objectives := ObjectiveManager.find(_level)
	var layout: Dictionary = X.MISSION_OBJECTIVES.filter(func(o): return o.id == "reserve_shelf")[0]
	_expect(objectives.get_title(&"reserve_shelf") == layout.title, "The reserve_shelf objective is the layout's.")
	var shelf := _level.get_node_or_null(M + "ReserveShelf") as ReserveShelf
	_expect(shelf != null, "The reserve shelf exists.")
	if shelf == null:
		return
	var key := _level.get_node(X.MISSION.reserve_shelf.reveal[0].replace("Items/", "Expansion/Gameplay/Items/")) as ItemPickup
	_expect(not key.available and not key.visible, "The dock key is not there before the shelf is complete.")
	# The books lie where a player can reach them.
	var map := (_level as Node3D).get_world_3d().navigation_map
	for it in X.ITEMS:
		if String(it.item).begins_with("reserve_book"):
			var book := _level.get_node("Expansion/Gameplay/Items/" + it.name) as ItemPickup
			var c := NavigationServer3D.map_get_closest_point(map, book.global_position)
			_expect(Vector2(c.x - book.global_position.x, c.z - book.global_position.z).length() < 1.6 and book.global_position.y - c.y < 1.4,
				"%s is within reach of the navmesh (%.2f m)." % [it.name, Vector2(c.x - book.global_position.x, c.z - book.global_position.z).length()])
	# The slip and the memo discover the objective.
	_expect(not objectives.is_discovered(&"reserve_shelf"), "The objective starts hidden.")
	var slip := _level.get_node("Expansion/Gameplay/Documents/ReserveSlip") as DocumentPickup
	var memo := _level.get_node("Expansion/Gameplay/Documents/ReserveMemo") as DocumentPickup
	_expect(slip.discovers_objective == &"reserve_shelf" and memo.discovers_objective == &"reserve_shelf", "The slip and the memo discover it.")
	slip.interact(_player)
	await _frames(2)
	_expect(objectives.is_discovered(&"reserve_shelf"), "Reading the slip reveals the objective.")
	# Shelving.
	var noises := [0]
	NoiseSystem.find(_level).noise_emitted.connect(func(_e): noises[0] += 1)
	var gap0 := shelf.get_node("Gap0") as ReserveGap
	_expect(not gap0.interact(_player), "An empty-handed player is refused.")
	_inventory.add(ItemCatalog.RESERVE_BOOK_823)
	_expect(not gap0.interact(_player) and _inventory.has(ItemCatalog.RESERVE_BOOK_823), "A wrong book is refused and kept.")
	_expect(noises[0] == 0, "Refusals are quiet.")
	_expect((shelf.get_node("Gap1") as ReserveGap).interact(_player) and not _inventory.has(ItemCatalog.RESERVE_BOOK_823),
		"823.8 goes in the literature gap.")
	var saved := {}
	for node in _level.get_tree().get_nodes_in_group("checkpoint_state"):
		saved[node] = node.get_checkpoint_state()
	_inventory.add(ItemCatalog.RESERVE_BOOK_523)
	_inventory.add(ItemCatalog.RESERVE_BOOK_942)
	_expect(gap0.interact(_player), "523.8 goes in the science gap.")
	_expect((shelf.get_node("Gap2") as ReserveGap).interact(_player), "942.1 goes in the history gap.")
	await _frames(2)
	_expect(shelf.is_solved and key.available and key.visible, "The complete shelf reveals the dock key.")
	_expect(objectives.is_completed(&"reserve_shelf"), "The objective is completed.")
	await _wait(1.0)
	var door := shelf.get_node(shelf.cabinet_door_path) as Node3D
	_expect(absf(rad_to_deg(door.rotation.y) - shelf.door_open_angle) < 1.0, "The cabinet door swings open.")
	# A restore takes back what was shelved since the checkpoint.
	for node in saved:
		node.restore_checkpoint_state(saved[node])
	await _frames(2)
	_expect(shelf.filled == [false, true, false] and not key.available and absf(door.rotation.y) < 0.01,
		"A restore puts the shelf back to one book, the cabinet shut and the key gone.")
	# The dock key opens the shutter by hand.
	var shutter := _level.find_children("*", "DockShutter", true, false)[0] as DockShutter
	var exit := shutter.get_exit()
	shutter.get_release().is_operated = true
	_expect(not shutter.has_power(), "The dock has no power.")
	shutter.button.interact(_player)
	_expect(not exit.unlocked, "Without power or key the shutter stays shut.")
	var before := {}
	for node in [exit, shutter, _inventory]:
		before[node] = node.get_checkpoint_state()
	_inventory.add(ItemCatalog.DOCK_KEY)
	shutter.button.interact(_player)
	_expect(exit.unlocked and exit.hand_opened and exit.is_open(), "The dock key opens the shutter by hand, without power.")
	var routes := EscapeRoutes.find(_level)
	routes.learn(EscapeRoutes.CLUE_DOCK)
	var dock_route: Dictionary = routes.get_known_routes().filter(func(r): return r.id == &"loading_dock")[0]
	_expect(dock_route.requirements[1].text.contains("dock release key") and dock_route.requirements[1].met, "WAYS OUT names the dock key.")
	for node in before:
		node.restore_checkpoint_state(before[node])
	await _frames(2)
	_expect(not exit.unlocked and not exit.hand_opened and not exit.is_open(), "A restore shuts the hand-opened shutter again.")


# --- G. Study 4: the slip and the storage shelf -----------------------------------------------

func _check_study4() -> void:
	var study := Rect2(6.0, -28.0, 6.0, 14.0)
	# The reserve slip hangs on the wall beside the whiteboard, not on it.
	var slip := _level.get_node("Expansion/Gameplay/Documents/ReserveSlip") as Node3D
	var board := _level.find_child("Study4Board", true, false) as Node3D
	_expect(board != null, "Study 4's whiteboard exists.")
	if board:
		var gap := absf(slip.global_position.z - board.global_position.z)
		_expect(gap > 1.23 + 0.45 + 0.05, "The reserve slip's board is clear of the whiteboard (%.2f m from its centre)." % gap)
	# A clue board with its picture lamp, as the other wall clues (2026-11-02).
	_expect(slip.get_node_or_null("Model/BoardLight") is OmniLight3D, "The reserve slip is a clue board with its picture lamp.")
	# The Office 1 facilities memo too (2026-11-02), on the east wall (8 lights per mesh).
	var memo := _level.get_node("Expansion/Gameplay/Documents/ReserveMemo") as Node3D
	_expect(memo.get_node_or_null("Model/BoardLight") is OmniLight3D and memo.global_position.x > -0.5 and memo.global_position.y > 4.5,
		"The Office 1 facilities memo is a clue board with its picture lamp, on the east wall.")
	_expect(study.has_point(Vector2(slip.global_position.x, slip.global_position.z)), "The reserve slip is in Study 4.")
	# The storage shelf.
	var shelf := _level.get_node_or_null("Expansion/Gameplay/Storage/Study4Shelf") as ItemStorage
	_expect(shelf != null, "The Study 4 storage shelf exists.")
	if shelf == null:
		return
	var at := shelf.global_position
	_expect(study.has_point(Vector2(at.x, at.z)), "The Study 4 shelf is in Study 4 (%s)." % at)
	_expect(shelf.count() == 0 and shelf.storage_name == "Study 4 shelf", "The Study 4 shelf starts empty.")
	var front := at + shelf.global_basis.z * 0.9
	front.y = 0.0
	var map: RID = _player.get_world_3d().navigation_map
	var reach := NavigationServer3D.map_get_closest_point(map, front)
	_expect(Vector2(reach.x, reach.z).distance_to(Vector2(front.x, front.z)) < 0.3, "The floor in front of the Study 4 shelf is walkable (%s)." % reach)
	for i in _inventory.slot_count:
		_inventory.take_from_slot(i)
	_inventory.add(ItemCatalog.RESERVE_BOOK_942)
	_expect(shelf.interact(_player) and shelf.count() == 1 and not _inventory.has(ItemCatalog.RESERVE_BOOK_942),
		"A reserve book can be left on the Study 4 shelf.")
	await _frames(3)
	var stored := shelf.get_node_or_null("Stored0") as ItemPickup
	_expect(stored != null and stored.interact(_player), "The stored book can be taken back.")
	await _frames(3)
	_expect(shelf.count() == 0 and _inventory.has(ItemCatalog.RESERVE_BOOK_942), "Taken back: the shelf is empty and the book carried.")
	_inventory.take_from_slot(_inventory.slots.find(ItemCatalog.RESERVE_BOOK_942))


# --- Helpers ---------------------------------------------------------------------------------

# --- H. Reserve shelf with real aiming ----------------------------------------------------------

func _check_reserve_aim() -> void:
	var shelf := _level.get_node(M + "ReserveShelf") as ReserveShelf
	var key := _level.get_node("Expansion/Gameplay/Items/DockKey") as ItemPickup
	var interactor := _player.find_children("*", "PlayerInteractor", true, false)[0] as PlayerInteractor
	for i in _inventory.slot_count:
		_inventory.take_from_slot(i)
	shelf.restore_checkpoint_state({"filled": [false, false, false]})
	await _frames(2)
	for i in 3:
		var gap := shelf.get_node("Gap%d" % i) as ReserveGap
		_expect(await _aim_at(interactor, gap, shelf.global_basis.z) == gap, "The player's aim reaches the reserve shelf's gap %d." % i)
	# Shelve a book through the ray, as a player does.
	_inventory.add(ItemCatalog.RESERVE_BOOK_523)
	var gap0 := shelf.get_node("Gap0") as ReserveGap
	if await _aim_at(interactor, gap0, shelf.global_basis.z) == gap0:
		_expect(interactor.try_interact() and shelf.filled[0] and not _inventory.has(ItemCatalog.RESERVE_BOOK_523),
			"Aiming at the science gap and pressing E shelves the book (filled %s)." % [shelf.filled])
	# The key in the opened cabinet, taken through the ray.
	shelf.restore_checkpoint_state({"filled": [true, true, true]})
	key.restore_checkpoint_state({"taken": false})
	await _frames(2)
	_expect(key.available, "The dock key is there once the shelf is complete.")
	var target := await _aim_at(interactor, key, shelf.global_basis.z)
	_expect(target == key, "The player's aim reaches the dock key in the cabinet (got %s)." % (target.name if target else "nothing"))
	if target == key:
		_expect(interactor.try_interact() and _inventory.has(ItemCatalog.DOCK_KEY), "Aiming at the key and pressing E takes it.")
	for i in _inventory.slot_count:
		_inventory.take_from_slot(i)
	key.restore_checkpoint_state({"taken": false})
	shelf.restore_checkpoint_state({"filled": [false, false, false]})


## Stands the player on the walkable floor about 1.1 m in front of `t` (along `front`),
## aims the camera at its interaction box and returns what the player's ray finds.
func _aim_at(interactor: PlayerInteractor, t: Interactable, front: Vector3) -> Interactable:
	var shape := t.get_node("Shape") as Node3D
	var aim := shape.global_position
	var flat := Vector3(front.x, 0.0, front.z).normalized()
	var want := Vector3(aim.x, 0.0, aim.z) + flat * 1.1
	var map: RID = _player.get_world_3d().navigation_map
	var at := NavigationServer3D.map_get_closest_point(map, want)
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	await _frames(2)
	_player.rotation.y = atan2(-(aim.x - at.x), -(aim.z - at.z))
	var eye: float = _player.global_position.y + _player.stand_eye_height
	_player.head.rotation.x = atan2(aim.y - eye, Vector2(aim.x - at.x, aim.z - at.z).length())
	await _frames(4)
	return interactor.find_target()


# --- I. Stationary cameras, cones stopped by walls ---------------------------------------------

func _check_cameras() -> void:
	var cams := _level.get_tree().get_nodes_in_group("security_cameras")
	_expect(cams.size() == 5, "Five security cameras (%d)." % cams.size())
	var before := {}
	for c in cams:
		before[c] = (c as SecurityCamera).look_direction()
	await _wait(2.0)
	var space := _player.get_world_3d().direct_space_state
	for c in cams:
		var cam := c as SecurityCamera
		_expect(cam.is_powered(), "%s is powered at the start." % cam.name)
		_expect(cam.sweep_angle == 0.0 and cam.look_direction().angle_to(before[cam]) < 0.001, "%s is stationary." % cam.name)
		cam.update_cone()
		var xf := cam._head.global_transform
		var lens := xf * SecurityCamera.LENS
		var through := 0
		for i in cam._cone_dirs.size():
			var end := xf * (SecurityCamera.LENS + cam._cone_dirs[i] * cam._cone_lengths[i])
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(lens, end, 1)).is_empty():
				through += 1
		_expect(through == 0, "%s's cone shows through nothing solid (%d ray ends behind a wall or floor)." % [cam.name, through])
	# The staff corridor camera (upper floor) no longer reaches into Study 4 below.
	var staff := _level.get_node("Expansion/Gameplay/Security/Cameras/CameraStaffCorridor") as SecurityCamera
	var xs := staff._head.global_transform
	var lowest := INF
	for i in staff._cone_dirs.size():
		lowest = minf(lowest, (xs * (SecurityCamera.LENS + staff._cone_dirs[i] * staff._cone_lengths[i])).y)
	_expect(lowest > X.UY - 0.05, "The staff corridor camera's cone stays above the upper floor (lowest %.2f m)." % lowest)
	# A wall put 2 m in front of the lens cuts the cone; taken away, the cone comes back.
	var full := staff.cone_axis_length()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 0.2)
	shape.shape = box
	wall.add_child(shape)
	_level.add_child(wall)
	wall.global_transform = Transform3D(xs.basis, xs * (SecurityCamera.LENS + Vector3(0, 0, -2.0)))
	for i in 3:
		await _host.get_tree().physics_frame
	staff.update_cone()
	_expect(staff.cone_axis_length() < 2.0, "A wall 2 m ahead cuts the staff corridor camera's cone (%.2f m)." % staff.cone_axis_length())
	wall.queue_free()
	for i in 3:
		await _host.get_tree().physics_frame
	staff.update_cone()
	_expect(absf(staff.cone_axis_length() - full) < 0.02, "Without the wall the cone reaches as far as before (%.2f m, was %.2f m)." % [staff.cone_axis_length(), full])


# --- J. Item models ------------------------------------------------------------------------------

func _check_item_models() -> void:
	for id in ItemCatalog.ITEMS:
		var model := ItemCatalog.make_model(id)
		var parts := model.find_children("*", "MeshInstance3D", true, false)
		var box := _parts_box(model)
		var size: Vector3 = ItemCatalog.ITEMS[id].size
		_expect(model.name == "Model" and parts.size() >= 3, "%s's model has its parts (%d)." % [id, parts.size()])
		_expect(box.position.y > -0.002, "%s's model rests on the floor (bottom %.3f)." % [id, box.position.y])
		var room := size * 1.4 + Vector3(0.05, 0.06, 0.05)
		_expect(box.size.x <= room.x and box.size.y <= room.y and box.size.z <= room.z, "%s's model is about its size (%s for %s)." % [id, box.size, size])
		model.free()
	for p in _level.get_tree().get_nodes_in_group("item_pickups"):
		var model := (p as Node).get_node_or_null("Model")
		_expect(model != null and model.find_children("*", "MeshInstance3D", true, false).size() >= 3, "%s shows its new model." % (p as Node).name)
	for name in ["StaffAccessCard", "RareManuscript"]:
		var card := _level.get_node("Gameplay/" + name) as AccessCard
		_expect(card.get_node_or_null("Model/Mesh") == null, "%s's old box is gone." % name)
		var built := card.get_node_or_null("Model/Built") as Node3D
		_expect(built != null, "%s builds its new model." % name)
		if built == null:
			continue
		var parts := built.find_children("*", "MeshInstance3D", true, false)
		var glowing := parts.filter(func(m): return (m as MeshInstance3D).layers == 8 and ((m as MeshInstance3D).material_override as StandardMaterial3D).emission_enabled)
		_expect(parts.size() >= 5 and glowing.size() == parts.size(), "%s's model: %d parts, all glowing on layer 8 (%d)." % [name, parts.size(), glowing.size()])


## The box around a model's parts, in the model's frame.
func _parts_box(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var mi := part as MeshInstance3D
		var b := mi.transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# --- K. Item "!" ---------------------------------------------------------------------------------

func _check_item_markers() -> void:
	for i in _inventory.slot_count:
		_inventory.take_from_slot(i)
	for p in _level.get_tree().get_nodes_in_group("item_pickups"):
		var item := p as ItemPickup
		var marker := item.get_node_or_null("Marker") as PickupMarker
		_expect(marker != null, "%s has a \"!\"." % item.name)
		if marker:
			_expect(marker.is_visible_in_tree() == (item.available and not item.taken), "%s's \"!\" shows only while it is there to take." % item.name)
	var key := _level.get_node("Expansion/Gameplay/Items/DockKey") as ItemPickup
	_expect((key.get_node("Marker") as Node3D).global_position.x < 11.35, "The dock key's \"!\" floats in front of the cabinet.")
	for n in ["LockerBottle", "LockerBadge"]:
		var m := _level.get_node("Expansion/Gameplay/Items/%s/Marker" % n) as Node3D
		_expect(m.global_position.x > -5.3, "%s's \"!\" floats in front of the locker (x %.2f)." % [n, m.global_position.x])
	# Taken: the "!" goes; restored: it comes back.
	var book := _level.get_node("Expansion/Gameplay/Items/ReserveBook823") as ItemPickup
	var saved := book.get_checkpoint_state()
	_expect(book.interact(_player) and not (book.get_node("Marker") as Node3D).is_visible_in_tree(), "Taking an item takes its \"!\" with it.")
	book.restore_checkpoint_state(saved)
	_expect((book.get_node("Marker") as Node3D).is_visible_in_tree(), "Restored, the item shows its \"!\" again.")
	# On a storage shelf: none.
	var shelf := _level.get_node("Expansion/Gameplay/Storage/Study4Shelf") as ItemStorage
	_expect(shelf.interact(_player), "The reserve book can be left on the Study 4 shelf.")
	await _frames(3)
	var stored := shelf.get_node_or_null("Stored0") as ItemPickup
	_expect(stored != null and stored.get_node_or_null("Marker") == null, "An item left on a storage shelf has no \"!\".")
	if stored:
		stored.interact(_player)
		await _frames(3)
	for i in _inventory.slot_count:
		_inventory.take_from_slot(i)
	book.restore_checkpoint_state(saved)
	# The staff card and the rare manuscript: a "!" above their labels.
	for name in ["StaffAccessCard", "RareManuscript"]:
		var card := _level.get_node("Gameplay/" + name) as AccessCard
		var marker := card.get_node_or_null("Marker") as PickupMarker
		var label := card.get_node_or_null("Label") as Node3D
		_expect(marker != null and label != null and marker.position.y > label.position.y + 0.2, "%s shows a \"!\" above its label." % name)


# --- L. No guard snags ---------------------------------------------------------------------------

const GUARD_REACH := 0.4
const RAISED_PROPS := ["WorkstationBin0", "WorkstationBin1", "WorkstationBin2", "WorkstationBin3", "StepStool2", "StepStool15",
	"StepStool21", "MopBucket", "PorchBench0", "PorchBench1", "PorchBench2", "PorchBench3"]


func _check_guard_snags() -> void:
	var map: RID = _player.get_world_3d().navigation_map
	var low := 0
	for b in _level.find_children("*", "StaticBody3D", true, false):
		var body := b as StaticBody3D
		if (body.collision_layer & 1) == 0 or String(body.name).begins_with("Floor_"):
			continue
		for c in body.get_children():
			var cs := c as CollisionShape3D
			if cs == null or cs.disabled or not (cs.shape is BoxShape3D):
				continue
			var size: Vector3 = (cs.shape as BoxShape3D).size
			var box: AABB = cs.global_transform * AABB(-size / 2.0, size)
			# Floors and slabs (wide, the walkable area on top of them) are not props.
			if box.size.y < 0.05 or box.size.y >= 0.5 or box.size.x > 2.5 or box.size.z > 2.5:
				continue
			low += 1
			var near := _walkable_within(map, box, GUARD_REACH)
			_expect(near < 0.0, "%s (%.2f m tall, below what the navmesh bake avoids) is out of a guard's reach of the walkable area (walkable %.2f m from it)." % [_level.get_path_to(body), box.size.y, near])
	_expect(low >= 3, "The low props are found (%d)." % low)
	for n in ["Office1Bin", "Office2Bin", "Office3Bin"]:
		var bin := _level.find_child(n, true, false) as Node3D
		_expect(bin != null and bin.global_position.z < -27.4, "%s stands against the back wall (z %.2f)." % [n, bin.global_position.z if bin else 0.0])
	for n in RAISED_PROPS:
		var body := _level.find_child(n, true, false) as StaticBody3D
		var shape := body.get_child(0) as CollisionShape3D if body else null
		for c in (body.get_children() if body else []):
			if c is CollisionShape3D:
				shape = c
		_expect(shape != null and (shape.shape as BoxShape3D).size.y >= 0.5, "%s's collision is 0.5 m tall." % n)
		if shape:
			var size: Vector3 = (shape.shape as BoxShape3D).size
			var box: AABB = shape.global_transform * AABB(-size / 2.0, size)
			var near := _walkable_within(map, box, 0.3)
			_expect(near < 0.0, "The walkable area keeps clear of %s (walkable %.2f m from it)." % [n, near])


## The distance from `box`'s footprint to the nearest walkable navmesh point on its floor
## within `reach`, or −1 if there is none.
func _walkable_within(map: RID, box: AABB, reach: float) -> float:
	var best := -1.0
	var k := 12
	for i in k + 1:
		for j in k + 1:
			var x := box.position.x - reach + (box.size.x + 2.0 * reach) * i / float(k)
			var z := box.position.z - reach + (box.size.z + 2.0 * reach) * j / float(k)
			var d := Vector2(maxf(maxf(box.position.x - x, x - box.end.x), 0.0), maxf(maxf(box.position.z - z, z - box.end.z), 0.0)).length()
			if d > reach:
				continue
			var q := NavigationServer3D.map_get_closest_point(map, Vector3(x, box.position.y + 0.3, z))
			if Vector2(q.x, q.z).distance_to(Vector2(x, z)) < 0.03 and q.y > box.position.y - 0.2 and q.y < box.position.y + 0.8:
				best = d if best < 0.0 else minf(best, d)
	return best


func _load(no_guards: bool) -> void:
	await _unload()
	_level = (load(SCENE) as PackedScene).instantiate()
	if no_guards:
		for g in _level.get_node("Guards").get_children():
			if g is Guard:
				g.get_parent().remove_child(g)
				g.free()
	else:
		for g in _level.get_node("Guards").get_children():
			if g is Guard and g.name != "GuardStaff":
				g.get_parent().remove_child(g)
				g.free()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, Layout.SPAWN), "Navigation never became ready.")
	_player = _level.get_node("Player")
	_inventory = PlayerInventory.find(_level)
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


func _wait(seconds: float) -> void:
	await _frames(int(seconds * 60.0))
