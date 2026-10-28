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
##   D. Follow-up (approved fixes): the pump's wrong setting plays its stall
##      bang, not the buzz; the tunnel niche and the balcony nook are hiding
##      spots the player can walk into; the maintenance bay checkpoint saves
##      when walked onto and respawns there; the Staff Offices respawn is in
##      Office 1 facing its door; no mesh is reached by more than 8 lights.
##   E. Electrical room (polish): A1–A4 are circuit breaker modules and MAIN a
##      wide main breaker, their levers following the state (and snapping down
##      on a trip); the two circuit switches are rotary isolators, the handle
##      up for ON, left for OFF, the lamp green / red, blinking amber while
##      locked; every breaker and switch has its name plate; the cover's
##      screws and sticker go with it; the dressing has no collision and
##      nothing of it stands between a player and a control or the status screen.
##   F. Code locks (polish): the vault keypad's keys show their digits on its
##      screen (dark without power), its try lamps go out one per wrong code
##      and its status lamp turns green when solved; the locker's wheels roll a
##      step per use, its lever springs back, the right code swings its door
##      open with the lock on it, a restore shuts or opens it at once; the
##      locker's contents sit on its shelves and can be taken once it's open;
##      nothing of the dressing stands between a player and a key, wheel or screen.
##   G. Pump room and storm drain (polish): the valves are handwheels turning a
##      quarter turn (flag along the pipe = OPEN), a seized one only jerks; the
##      crank's chain and SEIZED tag go when it is freed and its wheel turns
##      once; a wrong START stalls (STALL lamp, the lever springs back, the
##      screen says so until a valve turns); the right one holds the lever down,
##      lights RUN, raises the gauge needle, clears the grate body at once while
##      the grille slides up and the water drains, and the GRATE JAMMED tag
##      goes; a restore sets it all at once either way. The pump unit stands
##      inside its cover's collision box, which draws nothing else; the found
##      maintenance panel is a steel hatch. No collision in any of it, and
##      nothing between a player and a valve, START, the crank or the screen.
##   H. Loading dock (polish): the level's red panel, green header and floating
##      sign are hidden (the panel's collision unchanged); the release's bolt
##      and JAMMED tag go and its handle drops when freed; the station's OPEN is
##      a push button, its POWER lamp follows SERVICE EXIT, its screen the
##      state; OPEN clears the shutter's collision at once while the curtain
##      rolls up into the coil box (slats hidden above the opening), it rolls
##      down if the power goes, and a restore sets it at once. The new solid
##      props stay off the guard's route across the dock, clear of the release,
##      the control, the doorway and the hiding spot, and out of the dock
##      camera's view of its target; the yard outside has no collision, its own
##      render layer and light; nothing between a player and the controls.
##   I. Storage room (polish): the racks' old look is gone from the level's
##      batches (their four colliders unchanged) and their shelving stands
##      inside those colliders; the S2 stair's cream nosing is hidden and drawn
##      yellow with the same strips; the three wall shelves and the book
##      trolley are solid and stay
##      off the service guard's route and clear of the doors, the checkpoint,
##      the hiding spot and the stair foot; the decor has no collision; the
##      wall signs are gone (removed by request).
##   J. Book Processing (polish): the electrical room door draws two steel
##      leaves (not the panel), its reader LED and light strip are red without
##      the card and green with it; opening clears the panel's collision at once
##      while the leaves swing open, a restore shuts or opens them at once; the
##      workstation parts sit on the tables; the six solid props stay clear of
##      the three doors, the wiring chart and the tables, with paths between the
##      doors; the decor has no collision.
##   K. Lobby and reading hall (polish): the main entrance's panel draws nothing
##      and its grille drops for the lockdown and rolls up when the exit opens
##      (at once on a restore), its sign sits on the light box; the G4 staff
##      door draws its wooden leaves (the level's door points at them) and
##      swings open, at once on a restore; the S1 stair's nosing is redrawn in
##      brass strip for strip and its carpet is the level's ramp recoloured; the
##      reading hall's 24 solid props (11, plus the Kenney polish's 11 chair rows
##      and 2 plants) keep clear of every doorway, the
##      connector guard's route and the reading-table hiding spot, with paths
##      from the lobby doors to every exit of the hall; the decor has no collision.
##   C. Readability: the storm drain's state label no longer overlaps the
##      wall's STORM DRAIN · SEALED sign.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const TUTORIAL := "res://maps/tutorial/scenes/library_graybox.tscn"
const Layout := preload("res://maps/library/tools/expanded_layout.gd")
const X := preload("res://maps/library/tools/expansion/expansion_layout.gd")
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
	await _check_follow_up()
	await _check_electrical()
	await _check_code_locks()
	await _check_pump_room()
	await _check_dock()
	_check_storage()
	await _check_processing()
	await _check_lobby_hall()
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


# --- D. Follow-up --------------------------------------------------------------------------

func _check_follow_up() -> void:
	# The pump: no buzz on a stall (its bang plays through the caption).
	var pump := _level.get_node_or_null(M + X.MISSION.pump.name) as Puzzle
	_expect(pump != null and _audio != null, "Pump or MechanismAudio missing.")
	if pump and _audio:
		_audio.played.clear()
		pump.feedback.emit("The pump stalls with a loud bang: wrong valve setting.", false)
		NoiseSystem.find(_level).emit_noise(pump.global_position, NoiseEvent.Type.INTERACTION, "environment", 1.0, 12.0, -1.0, "Pump stalls with a bang")
		await _frames(2)
		_expect(_audio.played.has("pump_stall") and not _audio.played.has("puzzle_wrong"),
			"A pump stall should play pump_stall only (played %s)." % [_audio.played])
	# The new hiding spots: built, and walkable to from the entrance.
	var map: RID = _level.get_world_3d().navigation_map
	for name in ["Tunnelniche", "Balconynook"]:
		var spot := _level.get_node_or_null("Expansion/Gameplay/HidingSpots/" + name) as HidingSpot
		_expect(spot != null, "Hiding spot %s missing." % name)
		if spot:
			var floor_at := spot.global_position - Vector3(0, 0.6, 0)
			var path := NavigationServer3D.map_get_path(map, Layout.SPAWN, floor_at, true)
			_expect(path.size() > 0 and Vector2(path[-1].x - floor_at.x, path[-1].z - floor_at.z).length() < 0.5,
				"Hiding spot %s should be walkable from the entrance." % name)
	# The maintenance bay checkpoint: walking onto its pad saves; its respawn is on the navmesh.
	var cp := _level.get_node_or_null("Expansion/Gameplay/Checkpoints/" + X.CHECKPOINTS[0].node) as Checkpoint
	var manager := CheckpointManager.find(_level)
	_expect(cp != null and cp.checkpoint_name == X.CHECKPOINTS[0].name, "Maintenance bay checkpoint missing.")
	if cp and manager:
		_player.global_position = X.CHECKPOINTS[0].pos + Vector3(0, 0.05, 0)
		_player.velocity = Vector3.ZERO
		await _frames(6)
		_expect(manager.active == cp, "Walking onto the maintenance bay pad should activate it (active: %s)." % [manager.active.checkpoint_name if manager.active else "none"])
		var spawn := cp.get_spawn_transform()
		var c := NavigationServer3D.map_get_closest_point(map, spawn.origin)
		_expect(Vector2(c.x - spawn.origin.x, c.z - spawn.origin.z).length() < 0.1, "The bay respawn should be on the navmesh.")
		_expect(spawn.basis.z.dot(Vector3(0, 0, 1)) > 0.9, "The bay respawn should face the door (north).")
	# Staff Offices: the pad by the card desk, the respawn in Office 1 facing its door.
	var staff := _level.get_node("Gameplay/CheckpointStaffOffices") as Checkpoint
	var s := staff.get_spawn_transform()
	_expect(s.origin.x > -6.0 and s.origin.x < 0.0 and s.origin.z < -24.0 and s.basis.z.dot(Vector3(0, 0, 1)) > 0.9,
		"The Staff Offices respawn should be at the back of Office 1, facing the door (at %s)." % s.origin)
	# Lights per mesh: at most 8 omni lights reach any mesh (range cube and cull mask, as Godot pairs them).
	var lights := []
	for l in _level.find_children("*", "OmniLight3D", true, false):
		var o := l as OmniLight3D
		if o.is_visible_in_tree():
			lights.append([AABB(o.global_position - Vector3.ONE * o.omni_range, Vector3.ONE * o.omni_range * 2.0), o.light_cull_mask])
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
		var n := 0
		for l in lights:
			if (l[1] & gi.layers) != 0 and (l[0] as AABB).intersects(box):
				n += 1
		if n > 8:
			over.append("%s (%d)" % [_level.get_path_to(gi), n])
	_expect(over.is_empty(), "Meshes reached by more than 8 lights: %s" % ", ".join(over))


# --- E. Electrical room -------------------------------------------------------------------

func _check_electrical() -> void:
	var panel := _level.get_node(M + X.MISSION.breakers.name) as BreakerPanel
	var cover := _level.get_node(M + X.MISSION.panel_cover.name) as ToolMechanism
	var switches: Array[CircuitSwitch] = []
	for sw in X.SECURITY.switches:
		switches.append(_level.get_node("Expansion/Gameplay/Security/" + sw.name) as CircuitSwitch)
	_expect(panel.panel_style == "rail" and panel.breakers.all(func(b): return b.style == "breaker") and panel.main_switch.style == "main_breaker",
		"The breakers should be breaker modules and MAIN a main breaker.")
	_expect(switches.all(func(w): return w != null and w.style == "rotary"), "The circuit switches should be rotary isolators.")
	# Name plates: the breakers' full names and MAIN above the rail; each switch's name.
	var plates := []
	for c in panel.get_children():
		if c is Label3D and String(c.name).begins_with("Plate_"):
			plates.append(String(c.text).replace("\n", " "))
	for n in panel.breaker_names:
		_expect(n in plates, "Name plate %s missing (have %s)." % [n, plates])
	_expect("MAIN" in plates, "MAIN's name plate missing.")
	for w in switches:
		var name_label := w.get_node_or_null("Model/Name") as Label3D
		_expect(name_label != null and name_label.text == w.circuit_title, "%s should have its name plate." % w.name)
	# Open the cover (as the tool kit does): its screws and sticker go with it.
	var sticker := cover.get_node_or_null("Model/WarningSticker") as Node3D
	_expect(sticker != null and cover.get_node_or_null("Model/ScrewLT") != null, "The cover should carry its screws and warning sticker.")
	var inventory: PlayerInventory = _player.get_node("Inventory")
	if not inventory.has(ItemCatalog.TOOLKIT):
		inventory.take_from_slot(0)
		inventory.add(ItemCatalog.TOOLKIT)
	if not cover.is_operated:
		cover.interact(_player)
	await _frames(2)
	_expect(cover.is_operated and sticker and not sticker.is_visible_in_tree(), "With the cover off its sticker should be gone too.")
	# Breakers: the lever follows the state.
	var b := panel.breakers[0]
	panel.set_setting([false, false, false, false])
	await _wait(0.25)
	_expect(is_equal_approx(_lever(b), PuzzleControl.LEVER_DOWN), "A breaker OFF: lever down (%.2f)." % _lever(b))
	b.interact(_player)
	await _wait(0.25)
	_expect(b.index == 1 and is_equal_approx(_lever(b), PuzzleControl.LEVER_UP), "A breaker ON: lever up (%.2f)." % _lever(b))
	# A wrong setting trips the main: its lever and the breakers end down.
	if not panel.is_solved:
		panel.set_setting([true, true, true, true])
		panel.main_switch.interact(_player)
		await _wait(0.3)
		_expect(panel.breakers.all(func(x): return is_equal_approx(_lever(x), PuzzleControl.LEVER_DOWN)) and is_equal_approx(_lever(panel.main_switch), PuzzleControl.LEVER_DOWN),
			"After a trip every lever should be down.")
		panel.set_setting(X.MISSION.breakers.solution)
		panel.main_switch.interact(_player)
		await _wait(0.3)
		_expect(panel.is_solved and is_equal_approx(_lever(panel.main_switch), PuzzleControl.LEVER_UP), "Power on: MAIN's lever stays up.")
	# Rotary isolators: handle and lamp follow the circuit; amber blink while locked.
	var surveillance := switches[0]
	var service := switches[1]
	for w in switches:
		var lamp := (w.get_node("Model/Lamp") as MeshInstance3D).material_override as StandardMaterial3D
		var up := is_equal_approx(_handle(w), 0.0)
		_expect(up == (w.index == 1), "%s: handle %s while %s." % [w.name, "up" if up else "left", w.values[w.index]])
		_expect((lamp.albedo_color.g > lamp.albedo_color.r) == (w.index == 1), "%s: lamp green when ON, red when OFF." % w.name)
	if service.index == 0:
		service.interact(_player)   # ON: reboots surveillance and locks its switch
		await _wait(0.3)
		_expect(is_equal_approx(_handle(service), 0.0), "SERVICE EXIT ON: handle up.")
	var seen_amber := false
	var lamp_s := (surveillance.get_node("Model/Lamp") as MeshInstance3D).material_override as StandardMaterial3D
	for i in 60:
		await _frames(1)
		if surveillance.lock_left > 0.0 and lamp_s.albedo_color.is_equal_approx(CircuitSwitch.BLINK):
			seen_amber = true
	_expect(surveillance.lock_left > 0.0 and seen_amber, "A locked switch's lamp should blink amber.")
	surveillance.lock(0.0)
	await _frames(3)
	_expect(lamp_s.albedo_color.g > lamp_s.albedo_color.r, "After the lock the lamp is back to the circuit's state.")
	# The dressing: no collision, and nothing of it between a player in front and a control's face or the screen.
	var dressing := _level.get_node(M + "ElectricalDressing")
	_expect(dressing.find_children("*", "CollisionObject3D", true, false).is_empty(), "The electrical dressing should have no collision.")
	var targets: Array = []
	for c in panel.breakers + [panel.main_switch]:
		targets.append([c.name, c.global_position + Vector3(0, 0, c.size.z / 2.0 + 0.005)])
	for w in switches:
		targets.append([w.name, w.global_position + Vector3(0, 0, -w.size.z / 2.0 + 0.05)])
	var display := panel.get_node("Display") as Node3D
	targets.append(["status screen", display.global_position + Vector3(0, 0, 0.002)])
	var boxes := []
	for mi in dressing.find_children("*", "MeshInstance3D", true, false):
		boxes.append([mi.get_parent().name, mi.global_transform * (mi as MeshInstance3D).get_aabb()])
	for t in targets:
		for eye_x in [-0.4, 0.0, 0.4]:
			var eye: Vector3 = Vector3(t[1].x + eye_x, 1.6, t[1].z + 1.0)
			for bx in boxes:
				if (bx[1] as AABB).intersects_segment(eye, t[1]):
					_expect(false, "Dressing %s stands between the player and %s." % [bx[0], t[0]])
	_expect(display.global_position.y - X.MISSION.panel_cover.pos.y > X.MISSION.panel_cover.size.y / 2.0 + 0.05,
		"The status screen should be above the cover.")


# --- F. Code locks --------------------------------------------------------------------------

func _check_code_locks() -> void:
	var vault := _level.get_node(M + X.MISSION.vault_keypad.name) as CodeLock
	var locker := _level.get_node(M + X.MISSION.locker.name) as CodeLock
	_expect(vault.lock_style == "keypad" and vault.dials.all(func(d): return d.style == "key") and vault.enter.style == "key", "The vault keypad should be an electronic keypad.")
	_expect(locker.lock_style == "wheels" and locker.dials.all(func(d): return d.style == "wheel") and locker.enter.style == "lever", "The locker should have combination wheels and a lever.")
	# Vault keypad: digits on the screen, dark without power; try lamps; status lamp.
	var net := PowerNetwork.find(_level)
	var powered: bool = net.is_powered(vault.power_circuit)
	net.set_powered(vault.power_circuit, false)
	await _frames(2)
	var digit := vault.dials[0].get_node("Model/Digit") as Label3D
	_expect(not digit.visible, "Without power the keypad's digits are dark.")
	_expect(_lamp_on(vault, "NoPower") and not _lamp_on(vault, "Try1"), "Without power only the NO POWER lamp glows.")
	net.set_powered(vault.power_circuit, true)
	await _frames(2)
	if not vault.is_solved:
		vault.set_entry("0000")
		vault.dials[0].interact(_player)
		await _frames(2)
		_expect(digit.visible and digit.text == "1", "A key steps its digit on the screen (shows %s)." % digit.text)
		_expect(_lamp_on(vault, "Try3") and not _lamp_on(vault, "NoPower"), "Powered: three try lamps, NO POWER dark.")
		vault.set_entry("1111")
		vault.submit()
		await _frames(2)
		_expect(_lamp_on(vault, "Try2") and not _lamp_on(vault, "Try3"), "A wrong code puts out a try lamp.")
		vault.set_entry(X.MISSION.vault_keypad.code)
		vault.submit()
		await _frames(2)
		var status := (vault.get_node("Status") as MeshInstance3D).material_override as StandardMaterial3D
		_expect(vault.is_solved and status.albedo_color.g > status.albedo_color.r, "The right code: the status lamp turns green.")
	net.set_powered(vault.power_circuit, powered)
	# Locker: wheels roll, the lever springs back, the door swings open with the lock.
	if locker.is_solved:
		locker.restore_checkpoint_state({"solved": false})
		await _frames(2)
	var door := _level.get_node(M + "LockerDoor") as Node3D
	var shut := door.rotation.y
	var wheel := locker.dials[0]
	wheel.set_index(0)
	await _wait(0.25)
	var drum := wheel.get_node("Model/Drum") as Node3D
	var before := drum.rotation.x
	wheel.interact(_player)
	await _wait(0.25)
	_expect(wheel.index == 1 and absf(drum.rotation.x - before + TAU / 10.0) < 0.02 and (wheel.get_node("Model/Digit") as Label3D).text == "1",
		"A wheel rolls one step (36°) and shows its number.")
	locker.enter.interact(_player)
	await _wait(0.6)
	_expect(absf((locker.enter.get_node("Model/Lever") as Node3D).rotation.x) < 0.01, "The lever springs back.")
	var bottle := _level.get_node("Expansion/Gameplay/Items/LockerBottle") as ItemPickup
	_expect(not bottle.enabled, "The contents can't be taken while the locker is shut.")
	var at_rest := locker.global_position
	locker.set_entry(X.MISSION.locker.code)
	locker.submit()
	await _wait(0.8)
	_expect(locker.is_solved and absf(door.rotation.y - shut - deg_to_rad(locker.door_open_angle)) < 0.02, "The right code swings the door open (%.0f°)." % rad_to_deg(door.rotation.y - shut))
	_expect(locker.global_position.distance_to(at_rest) > 0.3, "The lock swings with the door.")
	var shelf_y: float = X.MISSION.locker.cabinet.shelves[1]
	_expect(bottle.enabled and absf(bottle.global_position.y - shelf_y) < 0.05, "The bottle sits on the middle shelf and can be taken.")
	locker.restore_checkpoint_state({"solved": false})
	_expect(absf(door.rotation.y - shut) < 0.01 and locker.global_position.distance_to(at_rest) < 0.01, "A restore shuts the door at once, the lock back on it.")
	locker.restore_checkpoint_state({"solved": true})
	_expect(absf(door.rotation.y - shut - deg_to_rad(locker.door_open_angle)) < 0.02, "A restore of an open locker opens it at once.")
	locker.restore_checkpoint_state({"solved": false})
	# Nothing of the dressing between a player in front and a key, wheel or the screen.
	var boxes := []
	for root in [_level.get_node(M + X.MISSION.vault_keypad.name + "Housing"), door, _level.get_node(M + "LockerCabinet")]:
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			boxes.append([mi.name, mi.global_transform * (mi as MeshInstance3D).get_aabb()])
	for lock in [vault, locker]:
		var forward: Vector3 = lock.global_transform.basis.z
		var targets: Array = []
		for c in lock.dials + [lock.enter]:
			targets.append(c.global_position + forward * 0.045)
		targets.append((lock.get_node("Display") as Node3D).global_position + forward * 0.002)
		for t in targets:
			var eye: Vector3 = t + forward * 1.0
			eye.y = lock.global_position.y - 1.35 + 1.6
			for bx in boxes:
				if (bx[1] as AABB).intersects_segment(eye, t):
					_expect(false, "%s's dressing %s stands between the player and %s." % [lock.name, bx[0], t])


func _lamp_on(lock: CodeLock, lamp_name: String) -> bool:
	var m := (lock.get_node(lamp_name) as MeshInstance3D).material_override as StandardMaterial3D
	return m.emission_energy_multiplier > 0.0


func _lever(c: PuzzleControl) -> float:
	return (c.get_node("Model/Lever") as Node3D).rotation.x


func _handle(c: PuzzleControl) -> float:
	return (c.get_node("Model/Handle") as Node3D).rotation.z


func _wait(seconds: float) -> void:
	await _host.get_tree().create_timer(seconds).timeout


# --- G. Pump room and storm drain -----------------------------------------------------------

func _check_pump_room() -> void:

	var pump := _level.get_node(M + X.MISSION.pump.name) as PumpControl
	var crank := _level.get_node(M + X.MISSION.pump_crank.name) as ToolMechanism
	var grate := _level.get_node("Expansion/Geometry/G_ServiceNetwork/" + X.GRATE.name) as StaticBody3D
	var grille := _level.get_node(M + "StormDrainGrille") as Node3D
	var water := _level.get_node(M + "CulvertWater") as Node3D
	var needle := _level.get_node(M + "PumpUnit/GaugeNeedle") as Node3D
	var tag := _level.get_node(M + X.MISSION.drain_exit.name + "/Sign") as Label3D
	_expect(pump.plant_style and pump.valves.all(func(v): return v.style == "handwheel") and pump.start_lever.style == "starter",
		"The pump's valves should be handwheels and START a starter lever.")
	_expect(grate.find_children("*", "MeshInstance3D", true, false).is_empty() and grate.get_node_or_null("Shape") != null,
		"The grate body is collision only (the grille is its look).")
	# The pump unit inside the PumpMachine cover's box; the cover draws nothing else.
	var cover_rect: Array = []
	for c in X.COVER:
		if c.name == "PumpMachine":
			cover_rect = c.rect
	var cover := _level.get_node("Expansion/Geometry/G_ServiceNetwork/Cover_PumpMachine") as StaticBody3D
	_expect(cover != null and cover.find_children("*", "MeshInstance3D", true, false).is_empty(), "The PumpMachine cover has no mesh of its own.")
	var box := AABB(Vector3(cover_rect[0] - 0.05, X.BF - 0.01, cover_rect[1] - 0.05), Vector3(cover_rect[2] - cover_rect[0] + 0.1, X._BC + 0.02, cover_rect[3] - cover_rect[1] + 0.1))
	for mi in _level.get_node(M + "PumpUnit").find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = mi.global_transform * (mi as MeshInstance3D).get_aabb()
		_expect(box.encloses(aabb), "Pump unit part %s (%s) should stand inside the cover's box." % [mi.name, aabb])
	for bb in _level.get_node("Expansion").find_children("*", "BatchedBoxes", true, false):
		var batch := bb as BatchedBoxes
		for i in batch.box_count():
			var centre: Vector3 = batch.global_transform * batch.box_transform(i).origin
			_expect(not box.grow(-0.1).has_point(centre), "A batched box (%s #%d) is drawn inside the pump's cover." % [batch.name, i])
	# No collision, nothing between the player and the controls.
	for root in [M + "PumpUnit", M + "PumpPanelDressing", M + "DrainDressing", M + "StormDrainGrille", M + "CulvertWater", M + X.MISSION.pump_crank.name + "/Model"]:
		var node := _level.get_node(root)
		_expect(node.find_children("*", "CollisionObject3D", true, false).is_empty() and node.find_children("*", "CollisionShape3D", true, false).is_empty(),
			"%s should have no collision." % root)
	var boxes := []
	for mi in _level.get_node(M + "PumpPanelDressing").find_children("*", "MeshInstance3D", true, false):
		boxes.append([mi.name, mi.global_transform * (mi as MeshInstance3D).get_aabb()])
	var forward: Vector3 = pump.global_transform.basis.z
	var targets: Array = []
	for c in pump.valves + [pump.start_lever]:
		targets.append(c.global_position + forward * 0.03)
	targets.append((pump.get_node("Display") as Node3D).global_position + forward * 0.002)
	targets.append(crank.global_position + forward * 0.03)
	for t in targets:
		var eye: Vector3 = t + forward * 1.0
		eye.y = X.BF + 1.6
		for bx in boxes:
			if (bx[1] as AABB).intersects_segment(eye, t):
				_expect(false, "The pump room's dressing %s stands between the player and %s." % [bx[0], t])
	# Start from a seized crank and an undrained culvert.
	crank.restore_checkpoint_state({"operated": false})
	pump.restore_checkpoint_state({"solved": false, "valves": [false, false, false]})
	await _frames(3)
	var grille_rest := grille.position
	var water_rest := water.position
	var chain := crank.get_node("Model/Chain") as Node3D
	_expect(chain.visible and (crank.get_node("Model/Tag") as Node3D).visible, "The seized crank is chained and tagged SEIZED.")
	_expect(tag.visible and tag.billboard == BaseMaterial3D.BILLBOARD_DISABLED, "The GRATE JAMMED tag hangs on the grille (not floating).")
	_expect(grille.visible and water.visible and absf(needle.rotation.z - PumpControl.GAUGE_ZERO) < 0.01, "Before: the grille down, the water in, the gauge at zero.")
	var valve := pump.valves[0]
	var wheel := valve.get_node("Model/Wheel") as Node3D
	valve.interact(_player)
	var jerk := 0.0   # the most the wheel moved while jerking (sampled each frame: frame times vary)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 250:
		jerk = maxf(jerk, absf(wheel.rotation.z))
		await _host.get_tree().process_frame
	_expect(valve.index == 0 and jerk > 0.01, "A seized valve doesn't turn, its wheel only jerks (index %d, moved %.3f)." % [valve.index, jerk])
	await _wait(0.15)
	_expect(absf(wheel.rotation.z) < 0.01, "The jerk ends where it began.")
	# Free the crank (as ToolMechanism does with the tool kit).
	crank.is_operated = true
	crank._apply()
	crank.operated.emit()
	await _wait(1.4)
	var crank_wheel := crank.get_node("Model/Wheel") as Node3D
	_expect(not chain.visible and absf(crank_wheel.rotation.z + TAU) < 0.02, "Freed: the chain is off and the crank's wheel turned once (%.2f)." % crank_wheel.rotation.z)
	valve.interact(_player)
	await _wait(0.4)
	var flag := valve.get_node("Model/Flag") as Node3D
	_expect(valve.index == 1 and absf(wheel.rotation.z - PI / 2.0) < 0.02 and absf(flag.rotation.z) < 0.02 and (valve.get_node("Model/State") as Label3D).text == "OPEN",
		"A valve turns a quarter turn to OPEN, its flag along the pipe.")
	# A wrong START: stall.
	pump.set_setting([true, true, false])
	pump.start_lever.interact(_player)
	await _wait(0.1)
	var lever := pump.start_lever.get_node("Model/Lever") as Node3D
	_expect(lever.rotation.x > 0.8, "START pulls the lever down.")
	_expect(pump.stalled and pump.get_display_text().contains("STALLED") and _lamp_lit(pump, "StallLamp") and not _lamp_lit(pump, "RunLamp"),
		"A wrong setting stalls: STALL lamp, the screen says so (%s)." % pump.get_display_text())
	await _wait(0.6)
	_expect(absf(lever.rotation.x) < 0.01, "After a stall the lever springs back.")
	pump.valves[1].interact(_player)
	await _frames(2)
	_expect(not pump.stalled and not _lamp_lit(pump, "StallLamp") and pump.get_display_text().contains("READY"), "Turning a valve clears the stall.")
	# The right START.
	pump.set_setting(X.MISSION.pump.solution)
	pump.start_lever.interact(_player)
	await _wait(0.2)
	_expect(pump.is_solved and not grate.visible and grate.collision_layer == 0, "Started: the grate body is cleared at once.")
	_expect(grille.visible, "The grille is still sliding.")
	await _wait(2.0)
	_expect(not grille.visible and absf(grille.position.y - grille_rest.y - PumpControl.GRILLE_LIFT) < 0.01, "The grille slid up into the ceiling.")
	_expect(lever.rotation.x > 1.1 and _lamp_lit(pump, "RunLamp") and pump.get_display_text().contains("RUNNING"), "Running: the lever held down, RUN lit.")
	_expect(absf(needle.rotation.z - PumpControl.GAUGE_RUN) < 0.06, "The gauge needle rose (%.2f)." % needle.rotation.z)
	_expect(not tag.visible, "The GRATE JAMMED tag is gone once the drain is open.")
	_expect(water.visible and water.position.y < water_rest.y - 0.01, "The water is draining.")
	await _wait(4.6)
	_expect(not water.visible, "The water has drained away.")
	# Restores, at once.
	pump.restore_checkpoint_state({"solved": false, "valves": [false, false, false]})
	await _frames(2)
	_expect(grille.visible and grille.position.distance_to(grille_rest) < 0.001 and water.visible and water.position.distance_to(water_rest) < 0.001,
		"A restore brings the grille down and the water back at once.")
	_expect(absf(lever.rotation.x) < 0.01 and not _lamp_lit(pump, "RunLamp") and absf(needle.rotation.z - PumpControl.GAUGE_ZERO) < 0.01,
		"A restore: the lever up, RUN dark, the gauge at zero.")
	pump.restore_checkpoint_state({"solved": true, "valves": X.MISSION.pump.solution})
	await _frames(2)
	_expect(not grille.visible and not water.visible and lever.rotation.x > 1.1, "A restore of a running pump: grille up, water gone, lever down, at once.")
	pump.restore_checkpoint_state({"solved": false, "valves": [false, false, false]})
	crank.restore_checkpoint_state({"operated": false})
	await _frames(2)
	_expect(chain.visible, "A restore of the crank puts the chain back.")
	# The maintenance panel: hidden as the wall, then a steel hatch.
	var panel := _level.get_node("Expansion/Gameplay/MaintenancePanel") as AccessDoor
	var hatch := panel.get_node("Panel/Hatch") as Node3D
	await _frames(2)
	_expect(not panel.is_discovered() and not hatch.visible, "Before the plan: no hatch on the panel.")
	(_player.get_node("Inventory") as PlayerInventory).add_document(&"culvert_access_plan", "Culvert access plan", "x")
	await _frames(3)
	var mat := (panel.get_node("Panel/Mesh") as MeshInstance3D).material_override as StandardMaterial3D
	_expect(hatch.visible and mat.albedo_color.is_equal_approx(panel.found_colour), "Found: a steel hatch (colour %s)." % mat.albedo_color)
	_expect(hatch.find_children("*", "CollisionShape3D", true, false).is_empty(), "The hatch dressing has no collision.")


# --- H. Loading dock -------------------------------------------------------------------------

func _check_dock() -> void:

	const E := "Expansion/Gameplay/Escape/"
	var shutter := _level.get_node(E + "DockShutterControl") as DockShutter
	var release := _level.get_node(E + "DockShutterRelease") as ToolMechanism
	var exit := _level.get_node("Gameplay/ExitDoor") as ExitDoor
	var panel := _level.get_node("NavigationRegion3D/Ground/D_ServiceCorridor/ExitDoorPanel") as StaticBody3D
	var curtain := _level.get_node(E + "ShutterCurtain") as Node3D
	var net := PowerNetwork.find(_level)
	var powered: bool = net.is_powered(shutter.power_circuit)
	# The level's own pieces, hidden by tools/expanded/expansion/fixes_x8.gd.
	_expect(not (panel.get_node("Mesh") as Node3D).visible and panel.get_node_or_null("Shape") != null, "The level's red shutter panel is hidden (its collision kept).")
	_expect(not (_level.get_node("NavigationRegion3D/Ground/Batched/Batch_6_4_exit_L4_S1") as Node3D).visible, "The green header over the dock door is hidden.")
	_expect(not exit.show_sign and not (exit.get_node("Sign") as Node3D).visible, "The dock exit's floating sign is hidden.")
	_expect(shutter.button.style == "push", "OPEN is a push button.")
	# Start: release jammed, no power, shut.
	release.restore_checkpoint_state({"operated": false})
	exit.restore_checkpoint_state({"unlocked": false})
	shutter.restore_checkpoint_state({})
	net.set_powered(shutter.power_circuit, false)
	await _frames(3)
	var bolt := release.get_node("Model/Bolt") as Node3D
	var handle := release.get_node("Model/Handle") as Node3D
	var handle_y := handle.position.y
	var lamp := (shutter.get_node("PowerLamp") as MeshInstance3D).material_override as StandardMaterial3D
	_expect(bolt.visible and (release.get_node("Model/Tag") as Node3D).visible, "The jammed release is bolted and tagged.")
	_expect(lamp.emission_energy_multiplier == 0.0 and shutter.get_display_text().contains("NO POWER"), "No power: POWER dark, the screen says so (%s)." % shutter.get_display_text())
	_expect(shutter.curtain_open == 0.0 and curtain.get_children().all(func(c): return (c as Node3D).visible), "Shut: the whole curtain shows.")
	# Free the release, power on.
	release.is_operated = true
	release._apply()
	release.operated.emit()
	net.set_powered(shutter.power_circuit, true)
	await _wait(0.6)
	_expect(not bolt.visible and not (release.get_node("Model/Tag") as Node3D).visible and absf(handle.position.y - handle_y + DockShutter.HANDLE_DROP) < 0.01,
		"Freed: the bolt and tag are gone, the handle dropped.")
	_expect(lamp.emission_energy_multiplier > 0.0 and shutter.get_display_text().contains("READY"), "Powered: POWER lit, READY (%s)." % shutter.get_display_text())
	# OPEN: collision clears at once, the curtain rolls up.
	var rest_y := curtain.position.y
	shutter.button.interact(_player)
	await _frames(3)
	_expect(exit.unlocked and panel.collision_layer == 0, "OPEN clears the shutter's collision at once.")
	await _wait(0.8)
	_expect(shutter.curtain_open > 0.05 and shutter.curtain_open < 0.95, "The curtain is rolling up (%.2f)." % shutter.curtain_open)
	await _wait(2.2)
	_expect(is_equal_approx(shutter.curtain_open, 1.0) and absf(curtain.position.y - rest_y - shutter.curtain_lift) < 0.01, "The curtain rolled up.")
	_expect(curtain.get_children().all(func(c): return not (c as Node3D).visible), "Rolled up: every slat is in the coil box.")
	# Power off: it rolls down again; a restore sets it at once.
	net.set_powered(shutter.power_circuit, false)
	await _wait(0.5)
	_expect(shutter.curtain_open < 1.0 and shutter.curtain_open > 0.0, "Without power the shutter comes down (%.2f)." % shutter.curtain_open)
	net.set_powered(shutter.power_circuit, true)
	exit.restore_checkpoint_state({"unlocked": false})
	shutter.restore_checkpoint_state({})
	await _frames(3)
	_expect(shutter.curtain_open == 0.0 and absf(curtain.position.y - rest_y) < 0.001, "A restore shuts it at once.")
	exit.restore_checkpoint_state({"unlocked": true})
	shutter.restore_checkpoint_state({})
	await _frames(3)
	_expect(shutter.curtain_open == 1.0, "A restore of an open shutter opens it at once.")
	# Back as it was.
	exit.restore_checkpoint_state({"unlocked": false})
	release.restore_checkpoint_state({"operated": false})
	shutter.restore_checkpoint_state({})
	net.set_powered(shutter.power_circuit, powered)
	await _frames(3)
	_expect(bolt.visible and absf(handle.position.y - handle_y) < 0.001, "A restore puts the bolt back and the handle up.")
	# The solid props: off the guard's route, clear of the controls, doorway and hiding spot.
	var props: Array = []
	for body in _level.get_node("Expansion/Geometry/D_LoadingDock").get_children():
		if body is StaticBody3D:
			var sh := (body.get_node("Shape") as CollisionShape3D)
			var size: Vector3 = (sh.shape as BoxShape3D).size
			props.append([body.name, AABB(body.global_position - size / 2.0, size)])
	_expect(props.size() == 10, "10 solid dock props (found %d)." % props.size())
	var map: RID = _level.get_world_3d().navigation_map
	var route: Array = []
	for p in Layout.PATROLS:
		if p.id == "P4":
			route = p.points
	var path := PackedVector3Array()
	for i in route.size():
		var a := Vector3(route[i][0], 0, route[i][1])
		var b := Vector3(route[(i + 1) % route.size()][0], 0, route[(i + 1) % route.size()][1])
		path.append_array(NavigationServer3D.map_get_path(map, a, b, true))
	_expect(path.size() > 4, "The service guard's route has a path.")
	var keep := {"release": release.global_position, "control": shutter.global_position, "hiding spot": Vector3(28, 0.6, 17.6)}
	for z in [22.5, 24.0, 25.5]:
		keep["doorway %.1f" % z] = Vector3(35.0, 1.0, z)
	for pr in props:
		var box: AABB = pr[1]
		for q in path:
			var flat := Vector2(clampf(q.x, box.position.x, box.end.x) - q.x, clampf(q.z, box.position.z, box.end.z) - q.z).length()
			if flat < 0.5:
				_expect(false, "Dock prop %s is %.2f m from the service guard's route (at %s)." % [pr[0], flat, q])
				break
		for k in keep:
			var q: Vector3 = keep[k]
			var flat := Vector2(clampf(q.x, box.position.x, box.end.x) - q.x, clampf(q.z, box.position.z, box.end.z) - q.z).length()
			if not String(pr[0]).begins_with("Bollard"):
				_expect(flat > 1.2, "Dock prop %s is %.2f m from the %s." % [pr[0], flat, k])
			elif String(k).begins_with("doorway"):
				_expect(box.end.z < 22.5 or box.position.z > 25.5, "Bollard %s stands in the doorway." % pr[0])
	var cam: Dictionary = {}
	for c in X.SECURITY.cameras:
		if c.name == "CameraLoadingDock":
			cam = c
	var hit: Dictionary = _level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cam.pos, cam.look + Vector3(0, 0.3, 0), 1))
	_expect(hit.is_empty() or not String(hit.collider.get_path()).contains("D_LoadingDock"), "The dock camera still sees its target (hit %s)." % hit.get("collider"))
	# The yard: no collision, its layer and light.
	var yard := _level.get_node(E + "DockYard")
	_expect(yard.find_children("*", "CollisionShape3D", true, false).is_empty(), "The yard has no collision.")
	for mi in yard.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).layers != 32:
			_expect(false, "Yard mesh %s should be on layer 32 (is %d)." % [mi.name, mi.layers])
			break
	_expect((yard.get_node("Streetlight") as OmniLight3D).light_cull_mask == 32, "The streetlight lights the yard only.")
	_expect(_level.get_node("Expansion/Dressing/DockDecor").find_children("*", "CollisionShape3D", true, false).is_empty(), "The dock decor has no collision.")
	# Nothing of the station between a player and its button or screen.
	var boxes := []
	for mi in _level.get_node(E + "DockShutterStation").find_children("*", "MeshInstance3D", true, false):
		boxes.append([mi.name, mi.global_transform * (mi as MeshInstance3D).get_aabb()])
	var forward: Vector3 = shutter.global_transform.basis.z
	for t in [shutter.button.global_position + forward * 0.05, (shutter.get_node("Display") as Node3D).global_position + forward * 0.002]:
		var eye: Vector3 = t + forward * 1.0
		eye.y = 1.6
		for bx in boxes:
			if (bx[1] as AABB).intersects_segment(eye, t):
				_expect(false, "The station's %s stands between the player and %s." % [bx[0], t])


# --- I. Storage room ------------------------------------------------------------------------

func _check_storage() -> void:
	var racks: Array[AABB] = []
	for n in ["Rack57", "Rack58", "Rack59", "Rack60"]:
		var body := _level.get_node_or_null("NavigationRegion3D/Ground/D_ServiceCorridor/" + n) as StaticBody3D
		_expect(body != null, "Rack collider %s missing." % n)
		if body:
			var size: Vector3 = ((body.get_node("Shape") as CollisionShape3D).shape as BoxShape3D).size
			_expect(size.is_equal_approx(Vector3(2, 2, 2)), "%s keeps its 2 m box (%s)." % [n, size])
			racks.append(AABB(body.global_position - size / 2.0, size))
	var old := 0
	for bb in _level.get_node("NavigationRegion3D").find_children("*", "BatchedBoxes", true, false):
		var batch := bb as BatchedBoxes
		for i in batch.box_count():
			if batch.box_color(i).to_html(false) in ["8c6b40", "9e7a4d", "6b7078"]:
				var c: Vector3 = batch.global_transform * batch.box_transform(i).origin
				if racks.any(func(r: AABB): return r.grow(0.1).has_point(c)):
					old += 1
	_expect(old == 0, "The racks' old boxes are gone from the level's batches (%d left)." % old)
	var decor := _level.get_node("Expansion/Dressing/StorageDecor")
	_expect(decor.find_children("*", "CollisionShape3D", true, false).is_empty(), "The storage decor has no collision.")
	var outside := 0
	for gi in decor.find_children("Shelving*", "Node3D", false, false):
		for mi in gi.find_children("*", "GeometryInstance3D", true, false):
			var aabb: AABB = (mi as Node3D).global_transform * (mi as GeometryInstance3D).get_aabb()
			if not racks.any(func(r: AABB): return r.grow(0.01).encloses(aabb)):
				outside += 1
	_expect(decor.find_children("Shelving*", "Node3D", false, false).size() == 4 and outside == 0, "The four shelving units stand inside the racks' colliders (%d parts outside)." % outside)
	var old_nosing := _level.get_node("NavigationRegion3D/Stairs/S2_S2StaffStair/Ramp/Nosing") as BatchedBoxes
	var nosing := decor.get_node("Nosing") as BatchedBoxes
	_expect(not old_nosing.visible and nosing.visible and nosing.box_count() == old_nosing.box_count() and nosing.global_transform.is_equal_approx(old_nosing.global_transform),
		"The S2 stair's nosing is redrawn yellow, strip for strip.")
	# The wall shelves: solid, off the guard's route, clear of the doors and the rest.
	var shelves: Array = []
	for body in _level.get_node("Expansion/Geometry/D_Storage").get_children():
		if body is StaticBody3D:
			var size: Vector3 = ((body.get_node("Shape") as CollisionShape3D).shape as BoxShape3D).size
			shelves.append([body.name, AABB(body.global_position - size / 2.0, size)])
	_expect(shelves.size() == 4, "3 solid wall shelves and the book trolley (found %d)." % shelves.size())
	var map: RID = _level.get_world_3d().navigation_map
	var route: Array = []
	for p in Layout.PATROLS:
		if p.id == "P4":
			route = p.points
	var path := PackedVector3Array()
	for i in route.size():
		path.append_array(NavigationServer3D.map_get_path(map, Vector3(route[i][0], 0, route[i][1]),
			Vector3(route[(i + 1) % route.size()][0], 0, route[(i + 1) % route.size()][1]), true))
	var keep := {"west door": Vector3(17, 0, 2), "dock door": Vector3(22, 0, 12), "processing door": Vector3(26, 0, -6),
		"checkpoint": Vector3(31, 0, 8.5), "hiding spot": Vector3(24, 0, 7), "stair foot": Vector3(34.35, 0, 4.5)}
	for sh in shelves:
		var box: AABB = sh[1]
		for q in path:
			var flat := Vector2(clampf(q.x, box.position.x, box.end.x) - q.x, clampf(q.z, box.position.z, box.end.z) - q.z).length()
			if flat < 0.5:
				_expect(false, "Wall shelf %s is %.2f m from the service guard's route (at %s)." % [sh[0], flat, q])
				break
		for k in keep:
			var q: Vector3 = keep[k]
			var flat := Vector2(clampf(q.x, box.position.x, box.end.x) - q.x, clampf(q.z, box.position.z, box.end.z) - q.z).length()
			_expect(flat > 1.2, "Wall shelf %s is %.2f m from the %s." % [sh[0], flat, k])
	_expect(_level.get_node("Expansion/Dressing/Signs").get_child_count() == 0, "No wall signs (removed by request).")


# --- J. Book Processing ----------------------------------------------------------------------

func _check_processing() -> void:
	var door := _level.get_node("Expansion/Gameplay/ElectricalRoomDoor") as AccessDoor
	var panel := door.get_node("Panel") as StaticBody3D
	var north := door.get_node("LeafNorth") as Node3D
	var south := door.get_node("LeafSouth") as Node3D
	var inventory := _player.get_node("Inventory") as PlayerInventory
	_expect(not (panel.get_node("Mesh") as Node3D).visible and north and south, "The electrical door draws its two leaves, not the panel.")
	door.restore_checkpoint_state({"open": false})
	var card: StringName = &"staff_card"
	var saved_slots := inventory.slots.duplicate()   # put back at the end
	for i in inventory.slots.size():
		inventory.take_from_slot(i)
	_player.global_position = Vector3(33, 0.05, -23)
	await _frames(3)
	var led := (door.get_node("CardReader/Led") as MeshInstance3D).material_override as StandardMaterial3D
	var strip := (door.get_node("StatusStrip") as MeshInstance3D).material_override as StandardMaterial3D
	_expect(led.albedo_color.r > led.albedo_color.g and strip.albedo_color.r > strip.albedo_color.g, "Without the card the reader LED and the strip are red.")
	inventory.add(card)
	await _frames(3)
	_expect(led.albedo_color.g > led.albedo_color.r and strip.albedo_color.g > strip.albedo_color.r, "With the card they turn green.")
	_expect(is_zero_approx(north.rotation.y) and is_zero_approx(south.rotation.y) and panel.collision_layer == 1, "Shut: the leaves closed, the panel solid.")
	door.interact(_player)
	await _frames(2)
	_expect(door.is_open and panel.collision_layer == 0, "Opening clears the panel's collision at once.")
	_expect(absf(north.rotation.y) < deg_to_rad(85.0), "The leaves are still swinging.")
	await _wait(0.8)
	_expect(absf(north.rotation_degrees.y - 90.0) < 1.0 and absf(south.rotation_degrees.y + 90.0) < 1.0, "Open: the leaves swung into the electrical room (%.0f°, %.0f°)." % [north.rotation_degrees.y, south.rotation_degrees.y])
	door.restore_checkpoint_state({"open": false})
	_expect(is_zero_approx(north.rotation.y) and is_zero_approx(south.rotation.y) and panel.collision_layer == 1, "A restore shuts the door at once.")
	door.restore_checkpoint_state({"open": true})
	_expect(absf(north.rotation_degrees.y - 90.0) < 0.5, "A restore of an open door opens it at once.")
	door.restore_checkpoint_state({"open": false})
	for i in inventory.slots.size():
		inventory.take_from_slot(i)
	for id in saved_slots:
		if id != &"":
			inventory.add(id)
	# The room: workstations on the tables, solid props clear of doors, chart and tables.
	var decor := _level.get_node("Expansion/Dressing/ProcessingDecor")
	_expect(decor.find_children("*", "CollisionShape3D", true, false).is_empty(), "The processing decor has no collision.")
	var tables: Array[AABB] = []
	for t in [Vector3(22, 0.9, -22), Vector3(22, 0.9, -12), Vector3(29, 0.9, -22), Vector3(29, 0.9, -12)]:
		tables.append(AABB(t - Vector3(1.5, 0.9, 0.6), Vector3(3.0, 0.9, 1.2)))
	for ws in decor.find_children("Workstation*", "Node3D", false, false):
		for mi in ws.find_children("*", "GeometryInstance3D", true, false):
			var aabb: AABB = (mi as Node3D).global_transform * (mi as GeometryInstance3D).get_aabb()
			var c := aabb.get_center()
			if not tables.any(func(t: AABB): return t.position.x <= aabb.position.x + 0.001 and t.end.x >= aabb.end.x - 0.001 and t.position.z <= aabb.position.z + 0.001 and t.end.z >= aabb.end.z - 0.001 and aabb.position.y >= t.end.y - 0.001):
				_expect(false, "Workstation part %s is not on a table (%s)." % [mi.name, aabb])
	var props: Array = []
	for body in _level.get_node("Expansion/Geometry/D_Processing").get_children():
		if body is StaticBody3D:
			var size: Vector3 = ((body.get_node("Shape") as CollisionShape3D).shape as BoxShape3D).size
			props.append([body.name, AABB(body.global_position - size / 2.0, size)])
	_expect(props.size() == 6, "6 solid processing props (found %d)." % props.size())
	var keep := {"west door": Vector3(17, 0, -17), "storage door": Vector3(26, 0, -6), "electrical door": Vector3(36, 0, -23), "wiring chart": Vector3(26, 0, -27.85)}
	for pr in props:
		var box: AABB = pr[1]
		for k in keep:
			var q: Vector3 = keep[k]
			var flat := Vector2(clampf(q.x, box.position.x, box.end.x) - q.x, clampf(q.z, box.position.z, box.end.z) - q.z).length()
			_expect(flat > 1.2, "Processing prop %s is %.2f m from the %s." % [pr[0], flat, k])
		for t in tables:
			var gap := maxf(maxf(t.position.x - box.end.x, box.position.x - t.end.x), maxf(t.position.z - box.end.z, box.position.z - t.end.z))
			_expect(gap >= 1.2, "Processing prop %s is %.2f m from a table." % [pr[0], gap])
	var map: RID = _level.get_world_3d().navigation_map
	for pair in [[Vector3(18, 0, -17), Vector3(34.5, 0, -23)], [Vector3(26, 0, -7), Vector3(34.5, 0, -23)], [Vector3(18, 0, -17), Vector3(26, 0, -7)]]:
		var path := NavigationServer3D.map_get_path(map, pair[0], pair[1], true)
		_expect(path.size() > 1 and path[path.size() - 1].distance_to(pair[1]) < 0.5, "A path between the doors (%s → %s)." % [pair[0], pair[1]])


# --- K. Lobby and reading hall ----------------------------------------------------------------

func _check_lobby_hall() -> void:
	var exit := _level.get_node("Expansion/Gameplay/Escape/MainEntranceExit") as ExitDoor
	var grille := _level.get_node("Expansion/Gameplay/Escape/MainEntranceDressing/EntranceGrille") as Node3D
	var panel := exit.get_node("Panel") as StaticBody3D
	var manager := ObjectiveManager.find(_level)
	_expect(panel.find_children("*", "MeshInstance3D", true, false).is_empty() and panel.get_node_or_null("Shape") != null, "The entrance panel is collision only (the grille is its look).")
	_expect((exit.get_node("Sign") as Label3D).billboard == BaseMaterial3D.BILLBOARD_DISABLED, "The entrance sign sits on its light box (not floating).")
	if not manager.is_completed(&"enter_library"):
		manager.complete(&"enter_library")
	exit.restore_checkpoint_state({"unlocked": false})
	await _frames(3)
	_expect(not exit.is_open() and exit.curtain_open == 0.0 and grille.get_children().all(func(r): return (r as Node3D).visible), "Lockdown: the grille is down.")
	exit.unlock()
	await _wait(0.6)
	_expect(exit.is_open() and exit.curtain_open > 0.05 and exit.curtain_open < 0.95, "Unlocked: the grille is rolling up (%.2f)." % exit.curtain_open)
	await _wait(2.0)
	_expect(is_equal_approx(exit.curtain_open, 1.0) and grille.get_children().all(func(r): return not (r as Node3D).visible), "The grille rolled up out of sight.")
	exit.restore_checkpoint_state({"unlocked": false})
	await _frames(2)
	_expect(exit.curtain_open == 0.0, "A restore drops the grille at once.")
	# G4: the level's door, the expansion's leaves.
	var g4 := _level.get_node("Gameplay/LobbyStaffDoorG4") as AccessDoor
	var north := _level.get_node("Expansion/Gameplay/LobbyStaffDoorDressing/LeafNorth") as Node3D
	var south := _level.get_node("Expansion/Gameplay/LobbyStaffDoorDressing/LeafSouth") as Node3D
	_expect(g4.leaf_paths.size() == 2 and g4.get_node_or_null(g4.leaf_paths[0]) == north and not (g4.get_node("Panel/Mesh") as Node3D).visible, "G4 draws its wooden leaves, not the panel.")
	g4.restore_checkpoint_state({"open": false})
	g4.open()
	await _frames(2)
	_expect(g4.get_node("Panel").collision_layer == 0, "G4 opens: its collision clears at once.")
	await _wait(0.8)
	_expect(absf(north.rotation_degrees.y - 90.0) < 1.0 and absf(south.rotation_degrees.y + 90.0) < 1.0, "G4's leaves swing into the service corridor.")
	g4.restore_checkpoint_state({"open": false})
	_expect(is_zero_approx(north.rotation.y) and g4.get_node("Panel").collision_layer == 1, "A restore shuts G4 at once.")
	# S1 (lobby polish): oak treads with a red runner in place of its nosing strips (the brass
	# strips of the earlier polish are gone too), its ramp body unchanged.
	var old_nosing := _level.get_node("NavigationRegion3D/Stairs/S1_S1MainStair/Ramp/Nosing") as BatchedBoxes
	_expect(not old_nosing.visible and _level.get_node_or_null("Expansion/Dressing/LobbyDecor/Nosing") == null, "S1's cream nosing stays hidden; no brass strips over the oak treads.")
	var ramp := _level.get_node("NavigationRegion3D/Stairs/S1_S1MainStair/Ramp") as StaticBody3D
	_expect(ramp.collision_layer == 1 and ramp.get_node("Shape") is CollisionShape3D, "S1's ramp still carries the walk.")
	for d in ["LobbyDecor", "HallDecor"]:
		_expect(_level.get_node("Expansion/Dressing/" + d).find_children("*", "CollisionShape3D", true, false).is_empty(), "%s has no collision." % d)
	# The reading hall's solid props.
	var props: Array = []
	for body in _level.get_node("Expansion/Geometry/C_ReadingHall").get_children():
		if body is StaticBody3D:
			var size: Vector3 = ((body.get_node("Shape") as CollisionShape3D).shape as BoxShape3D).size
			props.append([body.name, AABB(body.global_position - size / 2.0, size)])
	_expect(props.size() == 24, "24 solid reading hall props (found %d)." % props.size())
	# Doorways as [x0, z0, x1, z1] on the floor, grown 0.3 m into the room.
	var doorways := [[-10.3, -14.3, -7.7, -13.0], [-4.3, -14.3, -1.7, -13.0], [1.7, -14.3, 4.3, -13.0], [7.7, -14.3, 10.3, -13.0],
		[-12.3, -3.8, -11.0, -0.2], [11.0, 2.7, 12.3, 5.3], [-2.3, 9.0, 2.3, 10.3]]
	for pr in props:
		var box: AABB = pr[1]
		for dw in doorways:
			var r := Rect2(dw[0], dw[1], dw[2] - dw[0], dw[3] - dw[1])
			_expect(not r.intersects(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "Hall prop %s reaches into a doorway %s." % [pr[0], dw])
		var q := Vector3(-6, 0, -4.4)
		var flat := Vector2(clampf(q.x, box.position.x, box.end.x) - q.x, clampf(q.z, box.position.z, box.end.z) - q.z).length()
		_expect(flat > 1.2, "Hall prop %s is %.2f m from the reading-table hiding spot." % [pr[0], flat])
	var map: RID = _level.get_world_3d().navigation_map
	var route := NavigationServer3D.map_get_path(map, Vector3(0, 0, -5), Vector3(-3, 0, 15), true)
	for pr in props:
		var box: AABB = pr[1]
		for q in route:
			var flat := Vector2(clampf(q.x, box.position.x, box.end.x) - q.x, clampf(q.z, box.position.z, box.end.z) - q.z).length()
			if flat < 0.5:
				_expect(false, "Hall prop %s is %.2f m from the connector guard's route." % [pr[0], flat])
				break
	for goal in [Vector3(-9, 0, -13.2), Vector3(-3, 0, -13.2), Vector3(3, 0, -13.2), Vector3(9, 0, -13.2), Vector3(-11.3, 0, -2), Vector3(11.3, 0, 4)]:
		var path := NavigationServer3D.map_get_path(map, Vector3(0, 0, 8.5), goal, true)
		_expect(path.size() > 1 and path[path.size() - 1].distance_to(goal) < 0.6, "A path from the lobby doors to %s." % goal)


func _lamp_lit(pump: PumpControl, lamp_name: String) -> bool:
	var m := (pump.get_node(lamp_name) as MeshInstance3D).material_override as StandardMaterial3D
	return m.emission_energy_multiplier > 0.0


# --- C. Readability --------------------------------------------------------------------------

func _check_drain_label() -> void:
	var label := _level.get_node_or_null(M + X.MISSION.drain_exit.name + "/Sign") as Label3D
	var wall: Vector3 = Vector3.ZERO
	for s in X.SIGNS:
		if String(s.text).begins_with("STORM DRAIN"):
			wall = s.pos
	_expect(label != null, "Storm drain label missing.")
	if label and wall != Vector3.ZERO:   # (the wall signs were removed by request)
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
