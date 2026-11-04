extends RefCounted

## Expanded Library expansion Phase 6: escape routes and checkpoint
## reliability. Called from tests/test_scene.gd.
##
##   A. Route A, the main entrance (fresh level): it locks behind the player
##      (night lockdown, with a message); the badge reader refuses without the
##      security master badge; the badge comes from the security locker; an
##      override interrupted by walking away does nothing; a full 4 s override
##      opens the entrance; walking out without the manuscript is refused; with
##      it, the player escapes and "Main entrance" is recorded. The other
##      routes stay closed throughout.
##   B. Route B, the loading dock (fresh level): no power → the control says
##      so; power but the release jammed → it says so; the release needs the
##      tool kit; OPEN unlocks the shutter; walking out without the manuscript
##      is refused; with it, escape, "Loading dock" recorded.
##   C. Route C, the hidden maintenance passage (fresh level): the false panel
##      shows no prompt and can't be used until the culvert access plan is
##      read; then its latch opens it; the grate stays jammed until the pump
##      drains the culvert; walking out without the manuscript is refused;
##      with it, escape, "Hidden maintenance passage" recorded.
##   D. Unique prerequisites: each route's own requirements don't open the
##      other two (all three exits checked after every route's set-up).
##   E. Checkpoints (fresh level): the snapshot restores the respawn position
##      and facing, objectives, carried items, puzzles, circuits, doors, the
##      hidden panel, exits; stamina full; detection 0; the caught screen
##      names the checkpoint; the HUD header matches; the journal keeps
##      documents; no duplicate items after 5 captures; the escape route
##      record is cleared; an override in progress is cancelled; a capture
##      before any checkpoint reopens the entrance (enter again → lockdown
##      again); routes opened before the checkpoint stay open, after it are
##      closed again; afterwards a route is still completed (no softlock).
##   F. Guard snapshot (level guards): guards go back to where they were when
##      the checkpoint was taken (position, facing, patrol point) on PATROL
##      with detection 0, also one that was investigating then; a guard whose
##      stored spot is near or in sight of the respawn point goes to its start;
##      tutorial guards keep resetting to their starts.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const TUTORIAL := "res://maps/tutorial/scenes/library_graybox.tscn"
const GUARD_SCENE := "res://shared/scenes/npc/guard.tscn"
const Layout := preload("res://maps/library/tools/expanded_layout.gd")
const X := preload("res://maps/library/tools/expansion/expansion_layout.gd")
const TestUtils := preload("res://tests/test_utils.gd")
const S := StealthDirector.Status
const ACTIVE := ObjectiveManager.State.ACTIVE
const U := Layout.UPPER_Y
const B := X.BF
const PATROL := GuardStateMachine.PATROL
const INVESTIGATE := GuardStateMachine.INVESTIGATE
const M := "Expansion/Gameplay/Mission/"
const E := "Expansion/Gameplay/Escape/"

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _player: FirstPersonPlayer
var _inventory: PlayerInventory
var _interactor: PlayerInteractor
var _objectives: ObjectiveManager
var _checkpoints: CheckpointManager
var _director: StealthDirector
var _hud: ObjectiveHud
var _power: PowerNetwork
var _main: ExitDoor
var _dock: ExitDoor
var _drain: ExitDoor
var _reader: BadgeReader
var _shutter: DockShutter
var _release: ToolMechanism
var _panel: AccessDoor
var _escapes := 0
var _guard: Guard
var _route: PatrolRoute


func run(host: Node) -> Array[String]:
	_host = host
	await _check_route_main()
	await _check_route_dock()
	await _check_route_passage()
	await _check_checkpoints()
	await _check_guard_snapshot()
	await _unload()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[expanded-escape] " + message)


# --- A. Main entrance ----------------------------------------------------------------------------

func _check_route_main() -> void:
	await _load(false)
	_expect(_main.is_open() and not _main.unlocked, "Before entering, the main entrance is open (the way in).")
	await _teleport(Vector3(0, 0, 20))   # into the lobby: enter_library
	await _frames(4)
	_expect(_objectives.is_completed(&"enter_library"), "Entering completes enter_library.")
	_expect(not _main.is_open() and _main.get_node("Panel").collision_layer == 1 and _main.get_node("Panel").visible,
		"Once inside, the main entrance is shut (lockdown panel solid).")
	_expect(_hud.get_message_text().contains("night lockdown"), "The lockdown is announced (%s)." % _hud.get_message_text())
	# Blocked physically: walking at the doors stops at the panel.
	await _walk_to(Vector3(0, 0, 26.6), Vector3(0, 0, 31.0), 2.0)
	_expect(_player.global_position.z < 27.9 and _escapes == 0, "The closed entrance stops the player (z %.2f)." % _player.global_position.z)
	# E at the exit names the manuscript first.
	await _use(_main, Vector3(0, 0, 26.6))
	_expect(_hud.get_message_text() == "You can't leave without the rare manuscript.", "Main entrance E without the manuscript: %s." % _hud.get_message_text())
	# The reader without the badge.
	await _use(_reader, Vector3(2.9, 0, 26.8))
	_expect(not _reader.overriding and _reader.rejections == 1 and _hud.get_message_text().contains("security master badge"),
		"The reader refuses without the badge (%s)." % _hud.get_message_text())
	_check_routes_closed("A, before the badge", [])
	# The badge from the security locker (code 136).
	var locker: CodeLock = _level.get_node(M + "SecurityLocker")
	locker.set_entry("136")
	locker.submit()
	await _frames(3)
	var badge: ItemPickup = _level.get_node("Expansion/Gameplay/Items/LockerBadge")
	_expect(locker.is_solved and badge.available, "The locker opens and the badge appears.")
	await _use(badge, Vector3(-4.2, U, -21.7))
	_expect(_inventory.has(ItemCatalog.SECURITY_BADGE), "The badge is carried.")
	# An interrupted override does nothing.
	await _use(_reader, Vector3(2.9, 0, 26.8))
	_expect(_reader.overriding, "With the badge, E starts the override.")
	await _frames(60)
	await _teleport(Vector3(0, 0, 20))
	await _frames(3)
	_expect(not _reader.overriding and not _main.unlocked and _reader.interruptions == 1, "Walking away interrupts the override.")
	_expect(_hud.get_message_text().contains("interrupted"), "The interruption is explained (%s)." % _hud.get_message_text())
	# A full override (4 s at the reader), watched by the lobby camera.
	var alarm := SecurityAlarm.find(_level)
	var alarms_before := alarm.alarms_raised
	await _use(_reader, Vector3(2.9, 0, 26.8))
	await _frames(int(_reader.hold_time * 60) + 10)
	_expect(alarm.alarms_raised > alarms_before and alarm.last_reason.contains("main entrance"),
		"Exposed: the lobby camera spots the player during the override (alarms %d → %d)." % [alarms_before, alarm.alarms_raised])
	_expect(_main.unlocked and _main.is_open() and _main.get_node("Panel").collision_layer == 0, "A full override opens the main entrance.")
	_expect(_hud.get_message_text().contains("Lockdown lifted"), "Override complete is announced (%s)." % _hud.get_message_text())
	alarm.clear()
	# The camera covers the reader only (no sweep, short range), not the doorway.
	var cam: SecurityCamera = _level.get_node("Expansion/Gameplay/Security/Cameras/CameraLobby")
	_expect(cam.sweep_angle == 0.0 and cam.view_range < 10.0 and cam.fov_degrees <= 30.0, "The lobby camera is fixed on the reader.")
	# Mounted on the east wall, not in mid-air; the doorway is out of its cone or range.
	_expect(cam.global_position.x > 11.0, "The lobby camera hangs on the lobby's east wall (%s)." % cam.global_position)
	for p in [Vector3(1.5, 1.5, 28.0), Vector3(0.0, 1.5, 28.0), Vector3(-1.5, 1.5, 28.0)]:
		var to: Vector3 = p - cam.get_node("Head").global_position
		_expect(to.length() > cam.view_range or rad_to_deg(cam.look_direction().angle_to(to)) > cam.fov_degrees / 2.0, "The lobby camera does not see the doorway at %s." % p)
	# Walking out without the manuscript: refused, no escape.
	await _walk_to(Vector3(0, 0, 26.8), Vector3(0, 0, 30.5), 1.5)
	_expect(_escapes == 0 and _director.status != S.ESCAPED and _main.rejections >= 1, "Walking out without the manuscript is refused.")
	_expect(_hud.get_message_text() == "You can't leave without the rare manuscript.", "The trigger says why (%s)." % _hud.get_message_text())
	_check_routes_closed("A, entrance open, no manuscript", [&"main_entrance"])
	# With the manuscript: escape through the trigger.
	await _get_manuscript()
	_check_routes_closed("A, with the manuscript", [&"main_entrance"])
	await _walk_to(Vector3(0, 0, 26.8), Vector3(0, 0, 30.5), 2.0)
	await _expect_escaped(&"main_entrance", "Main entrance")
	print("  [expanded-escape] route A (main entrance): lockdown on entering; reader refuses without badge; locker 136 → badge; interrupted override → still locked; 4 s override → open; no manuscript → refused at the trigger; with it → escaped, route recorded")


# --- B. Loading dock -----------------------------------------------------------------------------

func _check_route_dock() -> void:
	await _load(false)
	await _teleport(Vector3(0, 0, 20))
	_expect(not _dock.is_open() and _dock.get_node(_dock.panel_path).collision_layer == 1, "The dock shutter starts closed.")
	await _use(_shutter.button, Vector3(34.9, 0, 26.4))
	_expect(not _dock.unlocked and _shutter.refusals == 1 and _hud.get_message_text().contains("no power"), "No power: the control says so (%s)." % _hud.get_message_text())
	_expect(_shutter.get_display_text() == "SHUTTER · NO POWER", "Its display: %s." % _shutter.get_display_text())
	var service: CircuitSwitch = _level.get_node("Expansion/Gameplay/Security/ServiceExitSwitch")
	service.interact(_player)
	await _use(_shutter.button, Vector3(34.9, 0, 26.4))
	_expect(not _dock.unlocked and _shutter.refusals == 2 and _hud.get_message_text().contains("jammed"), "Release jammed: the control says so (%s)." % _hud.get_message_text())
	await _use(_release, Vector3(34.9, 0, 21.4))
	_expect(not _release.is_operated and _release.rejections == 1, "The release needs the tool kit.")
	_level.get_node("Expansion/Gameplay/Items/ToolKit").interact(_player)
	await _use(_release, Vector3(34.9, 0, 21.4))
	_expect(_release.is_operated, "The tool kit frees the release.")
	_check_routes_closed("B, before OPEN", [])
	await _use(_shutter.button, Vector3(34.9, 0, 26.4))
	_expect(_dock.unlocked and _dock.is_open() and _dock.get_node(_dock.panel_path).collision_layer == 0, "OPEN unlocks the shutter.")
	_expect(_shutter.get_display_text() == "SHUTTER · OPEN", "Its display: %s." % _shutter.get_display_text())
	await _walk_to(Vector3(34.6, 0, 24), Vector3(39, 0, 24), 1.5)
	_expect(_escapes == 0 and _dock.rejections >= 1 and _hud.get_message_text() == "You can't leave without the rare manuscript.",
		"Walking out of the dock without the manuscript is refused (%s)." % _hud.get_message_text())
	_check_routes_closed("B, shutter open, no manuscript", [&"loading_dock"])
	await _get_manuscript()
	# Turning the service power off closes it again; on again opens it (recoverable).
	service.interact(_player)
	_expect(not _dock.is_open(), "Service power off closes the open shutter.")
	service.interact(_player)
	_expect(_dock.is_open(), "Service power on again: open (it stays unlocked).")
	await _walk_to(Vector3(34.6, 0, 24), Vector3(39, 0, 24), 2.0)
	await _expect_escaped(&"loading_dock", "Loading dock")
	print("  [expanded-escape] route B (loading dock): control refuses without power, then with the release jammed; release refuses without the tool kit; tool kit → freed; OPEN → shutter open; no manuscript → refused; power off/on closes/reopens; with the manuscript → escaped, route recorded")


# --- C. Hidden maintenance passage ---------------------------------------------------------------------

func _check_route_passage() -> void:
	await _load(false)
	await _teleport(Vector3(0, 0, 20))
	var at_panel := Vector3(0, B, -25.4)
	await _stand_and_look(at_panel, _panel.global_position)
	await _frames(3)
	_expect(not _panel.is_discovered() and not _panel.enabled and _interactor.focused != _panel and _hud.get_prompt_text() == "",
		"Undiscovered, the false panel has no prompt (focused %s, prompt '%s')." % [_interactor.focused, _hud.get_prompt_text()])
	_expect(not _panel.interact(_player) and not _panel.is_open, "Undiscovered, it can't be opened.")
	await _walk_to(Vector3(0, B, -25.4), Vector3(0, B, -32), 1.5)
	_expect(_player.global_position.z > -26.9, "The closed panel blocks the passage (z %.2f)." % _player.global_position.z)
	var plan: DocumentPickup = _level.get_node("Expansion/Gameplay/Documents/CulvertAccessPlan")
	await _use(plan, Vector3(-23.5, B, -18.2))
	_expect(_inventory.has_document(&"culvert_access_plan"), "The culvert access plan is in the journal.")
	_level.get_node("ObjectiveHud").close_journal()
	_check_routes_closed("C, plan read", [])
	await _use(_panel, at_panel)
	_expect(_panel.is_open, "Once known, the hidden latch opens the panel.")
	# The grate is still jammed.
	await _walk_to(Vector3(0, B, -33), Vector3(0, B, -39.5), 1.5)
	_expect(_player.global_position.z > -37.0 and _escapes == 0, "The jammed grate blocks the drain (z %.2f)." % _player.global_position.z)
	await _use(_drain, Vector3(0, B, -34.0))
	_expect(_hud.get_message_text() == "You can't leave without the rare manuscript.", "E at the drain names the manuscript first (%s)." % _hud.get_message_text())
	# The pump clears the grate.
	_level.get_node("Expansion/Gameplay/Items/ToolKit").interact(_player)
	(_level.get_node(M + "PumpCrank") as ToolMechanism).interact(_player)
	var pump: PumpControl = _level.get_node(M + "PumpControl")
	pump.set_setting([true, false, true])
	pump.start()
	await _frames(3)
	_expect(pump.is_solved and _drain.is_open(), "The pump drains the culvert: the drain is open.")
	await _walk_to(Vector3(0, B, -35.0), Vector3(0, B, -39.5), 1.5)
	_expect(_escapes == 0 and _drain.rejections >= 1, "Walking into the drain without the manuscript is refused.")
	_check_routes_closed("C, drain clear, no manuscript", [&"maintenance_passage"])
	await _get_manuscript()
	await _walk_to(Vector3(0, B, -35.0), Vector3(0, B, -39.5), 2.0)
	await _expect_escaped(&"maintenance_passage", "Hidden maintenance passage")
	print("  [expanded-escape] route C (hidden passage): panel without prompt and locked until the culvert plan is read; latch opens it; grate jammed until the pump drains the culvert; no manuscript → refused; with it → escaped, route recorded")


## D. After each step: only the routes in `open_ok` may be open (all three checked).
func _check_routes_closed(label: String, open_ok: Array) -> void:
	for exit in [_main, _dock, _drain]:
		if open_ok.has(exit.route_id):
			continue
		_expect(not exit.is_unlocked() and not (exit.is_open() and exit._armed()), "%s: the %s must stay closed." % [label, exit.route_name])


func _expect_escaped(route: StringName, route_name: String) -> void:
	await _frames(3)
	var flow := GameFlow.find(_level)
	_expect(_escapes == 1 and _director.status == S.ESCAPED and _objectives.is_finished() and flow.state == GameStateMachine.State.WIN,
		"%s: walking out with the manuscript escapes (escapes %d, status %s, state %s)." % [route_name, _escapes, _director.status, flow.state])
	_expect(_objectives.escape_route == route and _objectives.escape_route_name == route_name, "%s: the route is recorded (%s)." % [route_name, _objectives.escape_route])
	var menus: GameMenus = _level.get_node("GameMenus")
	_expect(menus.get_objectives_text().ends_with("Escape route: %s" % route_name), "%s: the win screen names it (%s)." % [route_name, menus.get_objectives_text()])


# --- E. Checkpoints --------------------------------------------------------------------------------

func _check_checkpoints() -> void:
	await _load(false)
	# E1. Caught before any checkpoint, after entering: back on the porch, the entrance open again.
	await _teleport(Vector3(0, 0, 20))
	_expect(not _main.is_open(), "Inside: lockdown.")
	await _catch_and_respawn(Vector3(-8, 0, 16), Vector3(-8, 0, 14.5))
	_expect(_player.global_position.distance_to(Layout.SPAWN) < 0.3 and not _objectives.is_completed(&"enter_library") and _main.is_open(),
		"Caught before any checkpoint: back on the porch, enter_library undone, the entrance open.")
	await _teleport(Vector3(0, 0, 20))
	_expect(not _main.is_open() and _hud.get_message_text().contains("night lockdown"), "Entering again engages the lockdown again.")
	# Progress before the checkpoint: tool kit, card, panel cover, breakers, badge, plan read, panel open, service ON, release, shutter.
	_level.get_node("Expansion/Gameplay/Items/ToolKit").interact(_player)
	_level.get_node("Gameplay/StaffAccessCard").interact(_player)
	(_level.get_node(M + "ElectricalPanelCover") as ToolMechanism).interact(_player)
	var breakers: BreakerPanel = _level.get_node(M + "BreakerPanel")
	breakers.set_setting([true, false, true, true])
	breakers.engage()
	var locker: CodeLock = _level.get_node(M + "SecurityLocker")
	locker.set_entry("136")
	locker.submit()
	await _frames(2)
	_level.get_node("Expansion/Gameplay/Documents/CulvertAccessPlan").interact(_player)
	_level.get_node("ObjectiveHud").close_journal()
	await _frames(2)
	_panel.interact(_player)
	var service: CircuitSwitch = _level.get_node("Expansion/Gameplay/Security/ServiceExitSwitch")
	service.interact(_player)
	_release.interact(_player)
	_shutter.button.interact(_player)
	await _frames(3)
	_expect(_dock.unlocked and _panel.is_open and _power.is_powered(&"service_exit"), "Set-up before the checkpoint.")
	var cp := _checkpoint("Study Rooms")
	_checkpoints.activate(cp)
	var saved_items := _inventory.slots.duplicate()
	var saved_docs := _inventory.documents.size()
	# After the checkpoint: badge taken, override started, a document read, vault opened, manuscript taken, stamina drained.
	var badge: ItemPickup = _level.get_node("Expansion/Gameplay/Items/LockerBadge")
	_expect(badge.available, "The badge waits in the open locker.")
	badge.interact(_player)
	_expect(_inventory.has(ItemCatalog.SECURITY_BADGE), "Badge taken after the checkpoint.")
	_level.get_node("Expansion/Gameplay/Documents/PumpRoomLog").interact(_player)
	_level.get_node("ObjectiveHud").close_journal()
	var keypad: CodeLock = _level.get_node(M + "VaultKeypad")
	keypad.set_entry("2691")
	keypad.submit()
	await _frames(2)
	_level.get_node("Gameplay/RareManuscript").interact(_player)
	_expect(_objectives.is_completed(&"take_manuscript"), "Manuscript taken after the checkpoint.")
	await _teleport(Vector3(2.9, 0, 26.8))
	_reader.interact(_player)
	_expect(_reader.overriding, "Override in progress.")
	_player.stamina.stamina = 5.0
	var docs_before_catch := _inventory.documents.size()
	# Caught (a test guard right next to the reader).
	var caught_text := ""
	_spawn_guard(Vector3(1.4, 0, 26.6), atan2(-(2.9 - 1.4), -(26.8 - 26.6)))
	for i in 400:
		await _host.get_tree().physics_frame
		if _director.status == S.CAUGHT:
			caught_text = (_level.get_node("StealthHud") as StealthHud).get_caught_text()
			break
	_expect(caught_text == "CAUGHT\nBack to Study Rooms…", "The caught screen names the checkpoint (%s)." % caught_text)
	var caught_frames := 0
	while _director.status == S.CAUGHT and caught_frames < 600:
		await _host.get_tree().physics_frame
		caught_frames += 1
	_clear_guard()
	await _frames(5)
	_expect(absf(caught_frames / 60.0 - _director.reset_delay) < 0.3, "The caught screen shows briefly (%.1f s)." % (caught_frames / 60.0))
	# Respawn position and facing.
	var spawn := cp.get_spawn_transform()
	_expect(_player.global_position.distance_to(spawn.origin) < 0.1 and absf(angle_difference(_player.rotation.y, spawn.basis.get_euler().y)) < 0.01 and _player.head.rotation == Vector3.ZERO,
		"Respawn at the checkpoint's position and facing.")
	_expect(_player.stamina.stamina == _player.stamina.max_stamina, "Stamina full after the capture.")
	_expect(_director.status == S.NONE, "Detection reset (status %s)." % _director.status)
	# Restored: objectives, items, puzzles, circuits, doors, exits; journal kept.
	_expect(_inventory.slots == saved_items, "Carried items as at the checkpoint (%s, saved %s)." % [_inventory.slots, saved_items])
	_expect(badge.available and not _inventory.has(ItemCatalog.SECURITY_BADGE), "The badge is back in the locker, not carried.")
	_expect(not _objectives.is_completed(&"take_manuscript") and not _objectives.is_completed(&"open_vault") and _objectives.is_completed(&"restore_power"),
		"Objectives as at the checkpoint.")
	_expect(not keypad.is_solved and (_level.get_node("Gameplay/RareManuscript") as Node3D).visible, "Vault keypad and manuscript as at the checkpoint.")
	_expect(breakers.is_solved and _power.is_powered(&"archive_access") and _power.is_powered(&"service_exit"), "Puzzles and circuits from before the checkpoint kept.")
	_expect(_dock.unlocked and _dock.is_open() and _panel.is_open and _release.is_operated, "Exits and the hidden panel opened before the checkpoint stay open.")
	_expect(not _reader.overriding and not _main.unlocked, "The override in progress is cancelled; the entrance stays locked.")
	_expect(_inventory.documents.size() == docs_before_catch and docs_before_catch == saved_docs + 1, "The journal keeps every document (%d)." % _inventory.documents.size())
	_expect(_hud.get_header_text() == "MISSION %d/8" % _objectives.get_mandatory_ids().filter(func(id): return _objectives.is_completed(id)).size(), "HUD header in sync (%s)." % _hud.get_header_text())
	_expect(_objectives.escape_route == &"", "No escape route recorded.")
	# E2. Opened after the checkpoint → closed again; then 5 captures: no duplicates.
	var plan := _checkpoint("Staff Offices")
	# Off the Study Rooms pad first (standing on a pad keeps saving there).
	await _teleport(Vector3(-8, 0, -5))
	_expect(_checkpoints.activate(plan), "The second checkpoint activates.")   # stored: dock open, panel open, entrance locked
	_main.unlock()
	service.interact(_player)   # service OFF after the checkpoint
	_expect(_main.is_open() and not _dock.is_open(), "Changed after the second checkpoint.")
	var totals := _item_totals()
	for k in 5:
		await _catch_and_respawn(Vector3(-8, 0, -9), Vector3(-8, 0, -10.5))
		_expect(_item_totals() == totals, "Capture %d: item totals unchanged (%s vs %s)." % [k + 1, _item_totals(), totals])
	_expect(not _main.unlocked and not _main.is_open() and _dock.is_open() and _power.is_powered(&"service_exit"), "After the captures: entrance locked again, dock open, service ON (as stored): main unlocked %s open %s, dock open %s unlocked %s, service %s." % [
		_main.unlocked, _main.is_open(), _dock.is_open(), _dock.unlocked, _power.is_powered(&"service_exit")])
	# No softlock: the mission still finishes through a route.
	keypad.set_entry("2691")
	keypad.submit()
	await _frames(2)
	_level.get_node("Gameplay/RareManuscript").interact(_player)
	await _walk_to(Vector3(34.6, 0, 24), Vector3(39, 0, 24), 2.0)
	await _expect_escaped(&"loading_dock", "Loading dock")
	print("  [expanded-escape] checkpoints: before any checkpoint → porch, entrance open, lockdown again on entering; caught screen 'Back to Study Rooms' %.1f s; position/facing, stamina full, detection reset; items, objectives, puzzles, circuits, exits, hidden panel as stored; override cancelled; journal kept (%d docs); HUD in sync; 5 captures, item totals unchanged; still escaped afterwards" % [
		caught_frames / 60.0, _inventory.documents.size()])


## Every item id → how many exist (carried + on shelves + pickups available), to catch duplicates.
func _item_totals() -> Dictionary:
	var totals := {}
	for id in _inventory.slots:
		if id != &"":
			totals[id] = totals.get(id, 0) + 1
	for pickup in _level.find_children("*", "", true, false):
		# Shelf contents are shown as pickups too, so counting available pickups covers them.
		if pickup is ItemPickup and pickup.available and pickup.visible:
			totals[pickup.item_id] = totals.get(pickup.item_id, 0) + 1
	return totals


# --- F. Guard snapshot ------------------------------------------------------------------------------

func _check_guard_snapshot() -> void:
	await _load(true)
	var guards: Array = _level.get_node("Guards").get_children().filter(func(g): return g is Guard)
	_expect(guards.size() == 7 and guards.all(func(g): return g.checkpoint_snapshot), "All seven guards use the checkpoint snapshot.")
	var tutorial := (load(TUTORIAL) as PackedScene).instantiate()
	_expect(tutorial.get_node("Guards").get_children().filter(func(g): return g is Guard).all(func(g): return not g.checkpoint_snapshot),
		"Tutorial guards keep resetting to their starts.")
	tutorial.free()
	_park()
	await _frames(60 * 6)
	# One guard investigates a noise when the checkpoint is taken.
	var lobby: Guard = _level.get_node("Guards/GuardLobby")
	NoiseSystem.find(_level).emit_noise(lobby.global_position + Vector3(3, 0, 0), NoiseEvent.Type.RUN, "player")
	await _frames(3)
	_expect(lobby.machine.current == INVESTIGATE, "Set-up: GuardLobby is investigating.")
	var cp := _checkpoint("Storage")
	_expect(_checkpoints.activate(cp), "The checkpoint activates.")
	var snaps: Dictionary = _checkpoints.saved_guards.duplicate()
	_expect(snaps.size() == 7, "The checkpoint stored 7 guards (%d)." % snaps.size())
	await _frames(60 * 8)   # they move on
	# Where every guard is at the moment of the respawn (they walk on right after).
	var at_respawn := {}
	var record := func(_cp):
		for g in guards:
			at_respawn[g] = {"transform": g.global_transform, "state": g.machine.current,
				"point": (g.machine.get_state(PATROL) as PatrolState).current_point, "detection": g.vision.detection}
	_checkpoints.respawned.connect(record)
	await _catch_and_respawn(Vector3(0, 0, 31.5), Vector3(0, 0, 30.0))
	_checkpoints.respawned.disconnect(record)
	var restored := 0
	var to_start := 0
	var bad := []
	var respawn := cp.get_spawn_transform().origin
	for g in guards:
		var snap: Dictionary = snaps[String(_checkpoints.get_path_to(g))]
		var xf: Transform3D = snap.transform
		var now: Dictionary = at_respawn.get(g, {})
		if now.is_empty():
			bad.append("%s not recorded" % g.name)
			continue
		var t: Transform3D = now.transform
		var at_snap: bool = t.origin.distance_to(xf.origin) < 0.01 and absf(angle_difference(t.basis.get_euler().y, xf.basis.get_euler().y)) < 0.01
		var at_start: bool = t.origin.distance_to(g._start_transform.origin) < 0.01
		if at_snap and now.state == PATROL and now.point == snap.point and now.detection == 0.0:
			restored += 1
		elif at_start and (xf.origin.distance_to(respawn) < g.respawn_clearance or g._would_see(xf, respawn + Vector3(0, 1.5, 0))):
			to_start += 1
		else:
			bad.append("%s at %s (snap %s, start %s, state %s, point %s/%s)" % [g.name, t.origin, xf.origin, g._start_transform.origin, now.state, now.point, snap.point])
	_expect(bad.is_empty(), "Guards after the respawn: %s." % ", ".join(bad))
	_expect(restored == _checkpoints.guards_restored and restored >= 4, "Most guards back at their stored spots (%d restored, %d to start)." % [restored, to_start])
	var lobby_snap: Dictionary = snaps[String(_checkpoints.get_path_to(lobby))]
	_expect(lobby_snap.state == "INVESTIGATE" and at_respawn[lobby].state == PATROL, "The guard investigating at the checkpoint comes back on PATROL.")
	# A stored spot right at the respawn point (or in sight of it): back to the start.
	var near := {"transform": Transform3D(Basis(), respawn + Vector3(2, 0, 0)), "point": 0, "state": "PATROL"}
	_expect(not lobby.restore_checkpoint_snapshot(near, respawn), "A stored spot within the clearance is refused (the guard stays at its start).")
	print("  [expanded-escape] guard snapshot: 7 stored at the checkpoint; after the capture %d back at their stored spot/facing/patrol point on PATROL with detection 0, %d at their start (stored spot near or in sight of the respawn); the investigating guard back on PATROL; a spot inside the clearance refused" % [restored, to_start])
	_park()
	await _frames(5)


# --- Helpers ---------------------------------------------------------------------------------------

## The real route to the manuscript (tool kit, card, cover, breakers, keypad, pedestal), via the nodes' own interactions.
func _get_manuscript() -> void:
	var toolkit := _level.get_node("Expansion/Gameplay/Items/ToolKit") as ItemPickup
	if not _inventory.has(ItemCatalog.TOOLKIT) and toolkit.available:
		toolkit.interact(_player)
	var card := _level.get_node("Gameplay/StaffAccessCard")
	if not _objectives.is_completed(&"take_card"):
		card.interact(_player)
	var cover := _level.get_node(M + "ElectricalPanelCover") as ToolMechanism
	if not cover.is_operated:
		cover.interact(_player)
	var breakers: BreakerPanel = _level.get_node(M + "BreakerPanel")
	if not breakers.is_solved:
		breakers.set_setting([true, false, true, true])
		breakers.engage()
	var keypad: CodeLock = _level.get_node(M + "VaultKeypad")
	if not keypad.is_solved:
		keypad.set_entry("2691")
		keypad.submit()
	await _frames(3)
	_level.get_node("Gameplay/RareManuscript").interact(_player)
	await _frames(2)
	_expect(_objectives.is_completed(&"take_manuscript") and _objectives.get_state(&"escape") == ACTIVE, "Set-up: the manuscript is taken.")


func _checkpoint(cp_name: String) -> Checkpoint:
	for cp in _level.get_tree().get_nodes_in_group("checkpoints"):
		if cp.checkpoint_name == cp_name:
			return cp
	return null


func _load(keep_guards: bool) -> void:
	await _unload()
	_level = (load(SCENE) as PackedScene).instantiate()
	if not keep_guards:
		for g in _level.get_node("Guards").get_children():
			if g is Guard:
				g.get_parent().remove_child(g)
				g.free()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, Layout.SPAWN), "Navigation never became ready.")
	_player = _level.get_node("Player")
	_inventory = _player.get_node("Inventory")
	_interactor = _player.get_node("Interactor")
	_objectives = ObjectiveManager.find(_level)
	_checkpoints = CheckpointManager.find(_level)
	_director = StealthDirector.find(_level)
	_hud = _level.get_node("ObjectiveHud")
	_power = PowerNetwork.find(_level)
	_main = _level.get_node(E + "MainEntranceExit")
	_dock = _level.get_node("Gameplay/ExitDoor")
	_drain = _level.get_node(M + "StormDrainExit")
	_reader = _level.get_node(E + "BadgeReader")
	_shutter = _level.get_node(E + "DockShutterControl")
	_release = _level.get_node(E + "DockShutterRelease")
	_panel = _level.get_node("Expansion/Gameplay/MaintenancePanel")
	_escapes = 0
	for exit in [_main, _dock, _drain]:
		exit.escaped.connect(func(): _escapes += 1)
	_guard = null
	_route = null
	GameFlow.find(_level).change_scene = func(_path: String): pass
	await _frames(10)


func _unload() -> void:
	Engine.time_scale = 1.0
	for a in ["move_forward", "crouch", "sprint"]:
		Input.action_release(a)
	if _level and is_instance_valid(_level):
		_level.queue_free()
		await _frames(30)
	_level = null


func _park() -> void:
	_player.global_position = Vector3(0, 0.05, 31.5)
	_player.velocity = Vector3.ZERO


func _teleport(at: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	await _frames(4)


## Stands at `from`, faces `toward` and walks forward (real input) for up to `seconds`.
func _walk_to(from: Vector3, toward: Vector3, seconds: float) -> void:
	await _teleport(from)
	_player.rotation.y = atan2(-(toward.x - from.x), -(toward.z - from.z))
	_player.head.rotation.x = 0.0
	Input.action_press("move_forward")
	for i in int(seconds * 60):
		await _host.get_tree().physics_frame
		if _director.status == S.ESCAPED:
			break
	Input.action_release("move_forward")
	await _frames(4)


func _stand_and_look(at: Vector3, target: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	await _frames(2)
	var eye := at.y + _player.stand_eye_height
	_player.rotation.y = atan2(-(target.x - at.x), -(target.z - at.z))
	_player.head.rotation.x = atan2(target.y - eye, Vector2(target.x - at.x, target.z - at.z).length())
	await _frames(4)


## Stands at `at`, looks at `target`, checks it is focused and presses E (real input).
func _use(target: Node3D, at: Vector3) -> void:
	await _stand_and_look(at, target.global_position)
	_expect(_interactor.focused == target, "%s should be in reach from %s (focused %s, prompt %s)." % [
		target.name, at, _interactor.focused.name if _interactor.focused else "nothing", _hud.get_prompt_text()])
	await _press("interact")


func _press(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(3)


func _catch_and_respawn(at: Vector3, guard_at: Vector3) -> void:
	var to_player := Vector2(at.x - guard_at.x, at.z - guard_at.z)
	_spawn_guard(guard_at, atan2(-to_player.x, -to_player.y))
	await _frames(3)
	await _teleport(at)
	for i in 600:
		if _director.status == S.CAUGHT:
			break
		await _host.get_tree().physics_frame
	_expect(_director.status == S.CAUGHT, "The test guard should catch the player at %s." % at)
	for i in int(_director.reset_delay * 60) + 30:
		if _director.status != S.CAUGHT:
			break
		await _host.get_tree().physics_frame
	_clear_guard()
	await _frames(5)


func _spawn_guard(at: Vector3, yaw: float) -> void:
	_clear_guard()
	_route = PatrolRoute.new()
	var post := PatrolPoint.new()
	post.position = at
	post.wait_time = 300.0
	_route.add_child(post)
	_level.add_child(_route)
	_guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	_guard.name = "EscapeTestGuard"
	_guard.patrol_route = _route
	_guard.position = at + Vector3(0, 0.05, 0)
	_guard.rotation.y = yaw
	_level.add_child(_guard)


func _clear_guard() -> void:
	if _guard and is_instance_valid(_guard):
		_guard.get_parent().remove_child(_guard)
		_guard.free()
	if _route and is_instance_valid(_route):
		_route.get_parent().remove_child(_route)
		_route.free()
	_guard = null
	_route = null


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
