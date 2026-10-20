extends RefCounted

## Expanded Library expansion Phase 5: security systems tests. Called from
## tests/test_scene.gd.
##
## The guards keep the existing AI (PATROL / INVESTIGATE / CHASE); the
## Expanded Library's guards turn on `expanded_security` (hiding, search and
## alarm rules), the tutorial's don't. These tests check:
##   A. Scope: all seven Expanded Library guards use the rules, the tutorial's
##      three don't; a tutorial-default guard ignores hiding spots and alarms.
##   B. States: noise → INVESTIGATE → PATROL; sight → CHASE → (lost)
##      INVESTIGATE at the last known position → PATROL.
##   C. Distraction: a thrown item draws a patrolling guard to where it
##      landed, it searches there and goes back to its patrol.
##   D. Hiding: entered unseen (crouched) hides the player; entered while seen
##      does not; a guard that searches nearby checks the hiding spot and
##      finds the player.
##   E. Alarms: guards hear an alarm and investigate it; while it sounds the
##      detection meter fills faster and searches last longer; never a capture.
##   F. Cameras: a powered camera fills its meter (slower crouched, slower far
##      away) and raises the alarm at the player's position (HUD message,
##      guards nearby investigate, no capture); surveillance off: dark, no
##      meter, and guards still see as before.
##   G. Circuits: every combination of the three circuits powers exactly its
##      own devices (vault keypad, cameras, dock shutter); each switch changes
##      only its circuit (service ON also reboots surveillance, as designed).
##   H. Service power: the reboot locks the surveillance switch for 30 s, then
##      it works again; the dock exit needs the manuscript and service power,
##      the storm drain does not care about power; from every combination the
##      mission can still be finished (no softlock).
##   I. Checkpoints: the circuits follow the checkpoint (being caught restores
##      them and ends a reboot lock).
##   J. The basement guard patrols the service tunnel and east basement;
##      a basement guard chases up the east service stair to the electrical
##      room, searches, and walks back down.

const SCENE := "res://scenes/level/expanded_library.tscn"
const TUTORIAL := "res://scenes/level/library_graybox.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const Layout := preload("res://tools/expanded/expanded_layout.gd")
const Expansion := preload("res://tools/expanded/expansion/expansion_layout.gd")
const TestUtils := preload("res://tests/test_utils.gd")
const PATROL := GuardStateMachine.PATROL
const INVESTIGATE := GuardStateMachine.INVESTIGATE
const CHASE := GuardStateMachine.CHASE
const S := StealthDirector.Status
const U := Layout.UPPER_Y
const BF := Expansion.BF
const SEC := "Expansion/Gameplay/Security/"
const MISSION := "Expansion/Gameplay/Mission/"

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _player: FirstPersonPlayer
var _power: PowerNetwork
var _alarm: SecurityAlarm
var _director: StealthDirector
var _objectives: ObjectiveManager
var _hud: ObjectiveHud
var _surveillance: CircuitSwitch
var _service: CircuitSwitch
var _cameras: Array = []
var _keypad: CodeLock
var _dock: ExitDoor
var _drain: ExitDoor
var _noises: Array[NoiseEvent] = []


func run(host: Node) -> Array[String]:
	_host = host
	_check_scope()
	await _load(false)
	await _check_states()
	await _check_distraction()
	await _check_hiding()
	await _check_alarm_attention()
	await _check_cameras()
	await _check_circuits()
	await _check_service_power()
	await _check_checkpoints()
	await _check_stair_chase()
	await _unload()
	await _load(true)
	await _check_basement_patrol()
	await _unload()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[expanded-security] " + message)


# --- A. Scope -------------------------------------------------------------------------------------

func _check_scope() -> void:
	var level := (load(SCENE) as PackedScene).instantiate()
	var guards := level.get_node("Guards").get_children().filter(func(g): return g is Guard)
	_expect(guards.size() == 7 and guards.all(func(g): return g.expanded_security), "All seven Expanded Library guards should use the expanded security rules.")
	level.free()
	var tutorial := (load(TUTORIAL) as PackedScene).instantiate()
	var tguards := tutorial.get_node("Guards").get_children().filter(func(g): return g is Guard)
	_expect(tguards.size() == 3 and tguards.all(func(g): return not g.expanded_security), "The tutorial's three guards must keep the default rules.")
	_expect(not tutorial.has_node("Expansion") and tutorial.find_children("*", "SecurityCamera", true, false).is_empty(), "The tutorial has no cameras or switches.")
	tutorial.free()
	var plain: Guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	_expect(not plain.expanded_security and plain.find_hiding_spot_to_check(Vector3.ZERO, []) == null, "A default guard never checks hiding spots.")
	plain.free()
	print("  [expanded-security] scope: 7 Expanded Library guards with the expanded rules; the tutorial's 3 guards and the guard scene keep the defaults")


# --- B. States -------------------------------------------------------------------------------------

func _check_states() -> void:
	_park_player()
	var guard := await _spawn_guard("StateGuard", [Vector3(-24, 0, -9), Vector3(-30, 0, -9)], Vector3(1, 0, 0))
	var states: Array[int] = []
	guard.ai_state_changed.connect(func(_f, to, _r): states.append(to))
	var noise := NoiseSystem.find(_level)
	noise.emit_noise(Vector3(-17, 0, -9), NoiseEvent.Type.RUN, "player")
	_expect(await _wait_state(guard, INVESTIGATE, 2.0), "States: a sprint 7 m away should be investigated.")
	_expect(await _wait_state(guard, PATROL, 30.0), "States: after the search the guard should go back to PATROL.")
	# Sight → chase → lost → last known position → patrol.
	var seen_at := Vector3(-18, 0, -9)
	_player.global_position = seen_at + Vector3(0, 0.05, 0)
	guard.global_position = Vector3(-26, 0.05, -9)
	guard.rotation.y = atan2(-1.0, 0.0)   # facing +x
	_expect(await _wait_state(guard, CHASE, 8.0), "States: a player 8 m ahead in the cross aisle should be chased.")
	_park_player()
	_expect(await _wait_state(guard, INVESTIGATE, 12.0), "States: losing the player should start a search.")
	var target: Vector3 = (guard.machine.get_state(INVESTIGATE) as InvestigateState).target
	_expect(target.distance_to(seen_at) < 5.0, "States: the guard should search near the last known position %s (target %s)." % [seen_at, target])
	_expect(await _wait_state(guard, PATROL, 40.0), "States: after searching the last known position the guard should return to PATROL.")
	var from_chase := states.slice(states.find(CHASE)) if states.has(CHASE) else []
	_expect(from_chase.slice(0, 3) == [CHASE, INVESTIGATE, PATROL], "States: from the chase on CHASE → INVESTIGATE → PATROL (got %s)." % [states])
	await _free_guard(guard)
	print("  [expanded-security] states: noise → INVESTIGATE → PATROL; sight → CHASE → lost → INVESTIGATE at the last known position → PATROL")


# --- C. Distraction --------------------------------------------------------------------------------

func _check_distraction() -> void:
	_park_player()
	var guard := await _spawn_guard("DistractGuard", [Vector3(-26, 0, -9), Vector3(-32, 0, -9)], Vector3(-1, 0, 0))
	var landing := Vector3(-19, 0.0, -9)
	var item := ThrownItem.new()
	item.setup(ItemCatalog.BOTTLE, landing + Vector3(-1, 1.5, 0), landing, 0.3)
	_level.add_child(item)
	_expect(await _wait_state(guard, INVESTIGATE, 3.0), "Distraction: a thrown item landing 7 m behind a patrolling guard should be investigated.")
	var closest := INF
	var back := false
	var made_noise := false
	for i in 60 * 40:
		await _host.get_tree().physics_frame
		if is_instance_valid(item) and item.landed and item.noise != null and item.noise.source_group == "distraction":
			made_noise = true
		closest = minf(closest, _flat(guard.global_position, landing))
		if closest < 3.0 and guard.machine.current == PATROL:
			back = true
			break
	_expect(made_noise, "Distraction: the item should land and make a 'distraction' noise.")
	_expect(closest < 3.0, "Distraction: the guard should walk to where it landed (closest %.1f m)." % closest)
	_expect(back, "Distraction: after searching there the guard should go back to its patrol.")
	await _free_guard(guard)
	print("  [expanded-security] distraction: thrown item → the guard walked to %.1f m of the landing spot, searched, back to PATROL" % closest)


# --- D. Hiding -------------------------------------------------------------------------------------

func _check_hiding() -> void:
	var spot := _spot("Reading table")
	_expect(spot != null, "Hiding: the reading table hiding spot is missing.")
	if spot == null:
		return
	var post := spot.global_position + Vector3(0, 0, 9.0)   # 9 m south of the table, in the reading hall
	var guard := await _spawn_guard("HideGuard", [post], Vector3(0, 0, 1))   # facing away (south)
	guard.set_physics_process(false)   # stands still; its vision keeps working
	Input.action_press("crouch")
	await _frames(4)
	# 1. Slip in unseen (the guard faces away), then the guard turns round.
	_player.global_position = spot.global_position + Vector3(0, 0.05, 0)
	await _frames(6)
	_expect(spot.contains_player() and spot.entered_unseen, "Hiding: entering while no guard sees the player should count as unseen.")
	guard.rotation.y = atan2(0.0, 1.0)   # facing north, toward the table
	await _frames(6)
	var sight := guard.vision._check_sight()
	_expect(sight, "Hiding: the test needs the guard to have a line of sight to the crouched player at the table.")
	_expect(spot.is_concealing() and not guard.vision.can_see_target, "Hiding: entered unseen and crouched, the expanded guard should not see the player.")
	guard.expanded_security = false
	await _frames(4)
	_expect(guard.vision.can_see_target, "Hiding: a guard with the default rules still sees the player there (the spot grants no invisibility).")
	guard.expanded_security = true
	# 2. Entered while seen: leave, then walk in in plain view.
	_player.global_position = post + Vector3(0, 0.05, 30)
	await _frames(6)
	guard.vision.detection = 0.0
	_player.global_position = spot.global_position + Vector3(0, 0.05, 1.6)
	await _frames(6)
	_expect(guard.vision.can_see_target, "Hiding: the guard should see the player next to the table first.")
	_player.global_position = spot.global_position + Vector3(0, 0.05, 0)
	await _frames(6)
	_expect(spot.contains_player() and not spot.entered_unseen and guard.vision.can_see_target,
		"Hiding: a player seen going in is not hidden (entered unseen %s, seen %s)." % [spot.entered_unseen, guard.vision.can_see_target])
	await _free_guard(guard)
	# 3. A guard searching nearby checks the hiding spot and finds the player.
	_player.global_position = post + Vector3(0, 0.05, 30)
	await _frames(6)
	var searcher := await _spawn_guard("SearchGuard", [Vector3(0, 0, -6)], Vector3(1, 0, 0))   # reading hall, facing east
	_player.global_position = spot.global_position + Vector3(0, 0.05, 0)
	await _frames(6)
	_expect(spot.entered_unseen and spot.is_concealing(), "Hiding: the searcher test starts with the player hidden unseen.")
	NoiseSystem.find(_level).emit_noise(spot.global_position + Vector3(2.5, 0, 0), NoiseEvent.Type.RUN, "player")
	var checked := false
	var found := false
	for i in 60 * 25:
		await _host.get_tree().physics_frame
		if searcher.machine.current == INVESTIGATE and _checking(searcher) == spot:
			checked = true
		if searcher.vision.can_see_target:
			found = true
			break
	_expect(checked, "Hiding: the investigating guard should go and check the hiding spot near the noise.")
	_expect(found and _flat(searcher.global_position, spot.global_position) <= searcher.hiding_check_reach + 0.3,
		"Hiding: at the spot the guard should find the player (found %s at %.1f m)." % [found, _flat(searcher.global_position, spot.global_position)])
	Input.action_release("crouch")
	await _free_guard(searcher)
	_park_player()
	await _frames(10)
	print("  [expanded-security] hiding: unseen + crouched → hidden from the expanded guard (a default guard still sees); seen going in → not hidden; a search near the spot checks it and finds the player")


func _checking(guard: Guard) -> Node3D:
	return (guard.machine.get_state(INVESTIGATE) as InvestigateState).checking_spot


# --- E. Alarm attention -------------------------------------------------------------------------------

func _check_alarm_attention() -> void:
	_park_player()
	var guard := await _spawn_guard("AlarmGuard", [Vector3(-26, 0, -9)], Vector3(1, 0, 0))
	# Detection rise over 0.5 s, without and with an alarm.
	var calm := await _rise(guard, Vector3(-14, 0, -9))
	_alarm.raise_alarm(Vector3(60, 0, 60), "test", 1.0)   # far away, inaudible: attention only
	_expect(guard.is_alarm_attentive() and is_equal_approx(guard.get_search_duration(), guard.investigate_search_duration * guard.alarm_search_multiplier),
		"Alarm: while it sounds, searches last %.1f× longer." % guard.alarm_search_multiplier)
	var alert := await _rise(guard, Vector3(-14, 0, -9))
	var ratio := alert / maxf(calm, 0.001)
	_expect(absf(ratio - guard.alarm_detection_multiplier) < 0.2, "Alarm: the meter should fill %.1f× faster (calm %.1f, alarm %.1f, ×%.2f)." % [
		guard.alarm_detection_multiplier, calm, alert, ratio])
	_alarm.clear()
	_expect(not guard.is_alarm_attentive() and is_equal_approx(guard.get_search_duration(), guard.investigate_search_duration), "Alarm: back to normal once it stops.")
	# An alarm within earshot is investigated; it never catches the player.
	_park_player()
	await _frames(10)
	var catches := _director.catches
	_alarm.raise_alarm(Vector3(-18, 0, -9), "test alarm", 22.0)
	_expect(await _wait_state(guard, INVESTIGATE, 2.0), "Alarm: a guard within its radius should investigate it.")
	await _frames(30)
	_expect(_director.catches == catches and _director.status != S.CAUGHT, "Alarm: an alarm never catches the player.")
	var plain := await _spawn_guard("PlainGuard", [Vector3(-26, 0, -6)], Vector3(1, 0, 0))
	plain.expanded_security = false
	_alarm.raise_alarm(Vector3(60, 0, 60), "test", 1.0)
	_expect(not plain.is_alarm_attentive() and is_equal_approx(plain.get_search_duration(), plain.investigate_search_duration), "Alarm: default guards keep their tuning.")
	_alarm.clear()
	await _free_guard(plain)
	await _free_guard(guard)
	print("  [expanded-security] alarm: meter ×%.2f faster (calm %.1f → %.1f in 0.5 s), searches ×%.1f, heard and investigated within its radius, no capture; default guards unchanged" % [
		ratio, calm, alert, 1.5])


## How much `guard`'s detection meter rises in 0.5 s with the player standing at `at`.
func _rise(guard: Guard, at: Vector3) -> float:
	_park_player()
	await _frames(4)
	guard.vision.detection = 0.0
	guard.machine.request_transition(PATROL, "test") if guard.machine.current != PATROL else null
	_player.global_position = at + Vector3(0, 0.05, 0)
	await _frames(1)
	var start := guard.vision.detection
	await _frames(30)
	var gain := guard.vision.detection - start
	_park_player()
	await _frames(30)
	guard.vision.detection = 0.0
	return gain


# --- F. Cameras ------------------------------------------------------------------------------------------

func _check_cameras() -> void:
	_expect(_cameras.size() == Expansion.SECURITY.cameras.size() and Expansion.SECURITY.cameras.size() == 5,
		"Expected 5 cameras (4 from Phase 5, the lobby camera from Phase 6), found %d." % _cameras.size())
	_expect(_power.is_powered(&"surveillance") and _cameras.all(func(c): return c.is_powered()), "Surveillance starts ON and the cameras with it.")
	var cam: SecurityCamera = _level.get_node(SEC + "Cameras/CameraArchiveHall")
	cam.sweep_speed = 0.0
	cam._sweep = 0.0
	await _frames(3)
	var near := _in_view(cam, 6.0)
	var far := _in_view(cam, 11.5)
	var standing := await _camera_gain(cam, near, false)
	var crouched := await _camera_gain(cam, near, true)
	var distant := await _camera_gain(cam, far, false)
	_expect(standing > 0.0, "Camera: a player 6 m in front of the archive hall camera should fill its meter (%s at %s)." % [standing, near])
	_expect(crouched > 0.0 and crouched < standing * 0.7, "Camera: crouched fills slower (standing %.1f, crouched %.1f)." % [standing, crouched])
	_expect(distant > 0.0 and distant < standing * 0.8, "Camera: far away fills slower (6 m %.1f, 11.5 m %.1f)." % [standing, distant])
	# Full meter: the alarm, at the player's position; guards nearby hear it; no capture.
	var guard := await _spawn_guard("CamGuard", [near + Vector3(-6, 0, -4)], Vector3(0, 0, -1))
	var raised := _alarm.alarms_raised
	var catches := _director.catches
	_noises.clear()
	_player.global_position = near + Vector3(0, 0.05, 0)
	var t := 0.0
	while cam.alarms == 0 and t < 6.0:
		await _host.get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	await _frames(2)
	var alarm_noise := _noises.filter(func(e: NoiseEvent): return e.source_group == "alarm")
	_expect(cam.alarms == 1 and _alarm.alarms_raised == raised + 1 and _alarm.last_reason.contains("archive hall"), "Camera: a full meter raises the alarm (after %.1f s)." % t)
	_expect(not alarm_noise.is_empty() and alarm_noise[0].position.distance_to(_player.global_position) < 1.0, "Camera: the alarm sounds at the player's position.")
	_expect(_hud.get_message_text().begins_with("ALARM: Camera (archive hall)"), "Camera: the HUD says why (%s)." % _hud.get_message_text())
	_park_player()
	_expect(await _wait_state(guard, INVESTIGATE, 2.0), "Camera: a guard near the alarm investigates it.")
	_expect(_director.catches == catches, "Camera: the camera never catches the player.")
	await _free_guard(guard)
	_alarm.clear()
	# Surveillance OFF: dark, nothing, and the guards still see.
	_surveillance.interact(_player)
	await _frames(3)
	_expect(not _power.is_powered(&"surveillance") and _cameras.all(func(c): return not c.is_powered()), "Camera: the surveillance switch turns all four cameras off.")
	_expect(_hud.get_message_text().contains("cameras go dark"), "Camera: switching off says so (%s)." % _hud.get_message_text())
	var dark := await _camera_gain(cam, near, false, 120)
	_expect(dark == 0.0 and cam.alarms == 1 and cam._lens_material.emission_energy_multiplier == 0.0 and not cam._cone.visible, "Camera: an unpowered camera is dark and sees nothing.")
	var watcher := await _spawn_guard("Watcher", [Vector3(-26, 0, -9)], Vector3(1, 0, 0))
	var unaffected := await _rise(watcher, Vector3(-14, 0, -9))
	_expect(unaffected > 0.0, "Camera: with surveillance off the guards still see and detect as before.")
	await _free_guard(watcher)
	_surveillance.interact(_player)
	await _frames(3)
	_expect(_cameras.all(func(c): return c.is_powered()), "Camera: back ON.")
	cam.sweep_speed = 18.0
	print("  [expanded-security] cameras: meter in 0.5 s standing %.1f, crouched %.1f, far %.1f; full → alarm at the player in %.1f s, HUD 'ALARM', guard investigated, no capture; surveillance OFF → 4 dark, no meter, guards unaffected" % [
		standing, crouched, distant, t])


## A floor point `distance` m out along the camera's resting direction.
func _in_view(cam: SecurityCamera, distance: float) -> Vector3:
	var forward := -cam.global_basis.z
	forward.y = 0.0
	var p := cam.global_position + forward.normalized() * distance
	var down := _level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 6.0, 1))
	return down.position if not down.is_empty() else Vector3(p.x, 0, p.z)


func _camera_gain(cam: SecurityCamera, at: Vector3, crouch: bool, frames := 30) -> float:
	_park_player()
	await _frames(4)
	cam.meter = 0.0
	cam.cooldown_left = 0.0
	if crouch:
		Input.action_press("crouch")
	_player.global_position = at + Vector3(0, 0.05, 0)
	await _frames(frames)
	var gain := cam.meter
	Input.action_release("crouch")
	_park_player()
	await _frames(4)
	cam.meter = 0.0
	return gain


# --- G. Circuits -----------------------------------------------------------------------------------------

func _check_circuits() -> void:
	var combos := 0
	for mask in 8:
		var archive := mask & 1 != 0
		var surveillance := mask & 2 != 0
		var service := mask & 4 != 0
		_power.set_powered(&"archive_access", archive)
		_power.set_powered(&"surveillance", surveillance)
		_power.set_powered(&"service_exit", service)
		await _frames(2)
		var label := "archive %s, surveillance %s, service %s" % [archive, surveillance, service]
		_expect(_keypad.has_power() == archive, "%s: the vault keypad must follow ARCHIVE ACCESS only." % label)
		_expect(_cameras.all(func(c): return c.is_powered() == surveillance), "%s: the cameras must follow SURVEILLANCE only." % label)
		_expect(_dock._has_power() == service, "%s: the dock shutter must follow SERVICE EXIT only." % label)
		_expect(_drain._has_power(), "%s: the storm drain needs no power." % label)
		_expect(_surveillance.index == int(surveillance) and _service.index == int(service), "%s: the switches show the real state." % label)
		combos += 1
	# Each switch changes only its own circuit (service ON also reboots surveillance, by design).
	_power.set_powered(&"archive_access", true)
	_power.set_powered(&"surveillance", true)
	_power.set_powered(&"service_exit", false)
	_noises.clear()
	_surveillance.interact(_player)
	_expect(not _power.is_powered(&"surveillance") and _power.is_powered(&"archive_access") and not _power.is_powered(&"service_exit"), "The surveillance switch changes only surveillance.")
	_expect(_noises.any(func(e: NoiseEvent): return e.source_group == "environment"), "A switch makes a clunk guards can hear.")
	_service.interact(_player)
	_expect(_power.is_powered(&"service_exit") and _power.is_powered(&"surveillance") and _power.is_powered(&"archive_access"), "Service ON powers the dock and reboots surveillance (archive untouched).")
	_service.interact(_player)
	_expect(not _power.is_powered(&"service_exit") and _power.is_powered(&"surveillance") and _power.is_powered(&"archive_access"), "Service OFF changes only the service circuit.")
	_surveillance.lock(0.0)
	_power.set_powered(&"archive_access", false)
	_power.set_powered(&"surveillance", true)
	print("  [expanded-security] circuits: all %d combinations power exactly their own devices (keypad / 4 cameras / dock shutter; the drain needs none); each switch changes only its circuit, service ON reboots surveillance" % combos)


# --- H. Service power, reboot and no softlock ----------------------------------------------------------------

func _check_service_power() -> void:
	_surveillance.interact(_player)   # surveillance OFF
	_expect(not _power.is_powered(&"surveillance"), "Reboot setup: surveillance off.")
	_service.interact(_player)   # service ON → reboot
	await _frames(2)
	_expect(_power.is_powered(&"surveillance") and _cameras.all(func(c): return c.is_powered()), "Reboot: service ON brings the cameras back ON.")
	_expect(_hud.get_message_text().contains("rebooted") and _hud.get_message_text().contains("30 s") and _hud.get_message_text().length() <= 80, "Reboot: the HUD explains it (%s)." % _hud.get_message_text())
	_expect(_surveillance.lock_left > 29.0 and _surveillance.get_prompt(_player).contains("rebooting"), "Reboot: the surveillance switch is locked for 30 s (%s)." % _surveillance.get_prompt(_player))
	_expect(not _surveillance.interact(_player) and _power.is_powered(&"surveillance"), "Reboot: a locked switch does nothing.")
	_expect(_hud.get_message_text().contains("Try again in"), "Reboot: and says when to try again (%s)." % _hud.get_message_text())
	# 30 s later (time sped up) it works again.
	Engine.time_scale = 6.0
	var waited := 0.0
	while _surveillance.lock_left > 0.0 and waited < 40.0:
		await _host.get_tree().process_frame
		waited += _host.get_process_delta_time()
	Engine.time_scale = 1.0
	_expect(_surveillance.lock_left == 0.0 and _surveillance.interact(_player) and not _power.is_powered(&"surveillance") and _power.is_powered(&"service_exit"),
		"Reboot: after the lock the cameras can be switched off again with the dock still powered (recoverable).")
	_expect(waited > 29.0 and waited < 31.5, "Reboot: the lock lasted about 30 s of game time (%.1f s)." % waited)
	# The dock: manuscript + service power. The storm drain: manuscript + drained culvert, any power.
	for id in [&"enter_library", &"take_card", &"find_toolkit", &"open_panel", &"restore_power", &"open_vault", &"take_manuscript"]:
		_objectives.complete(id)
	_expect(_objectives.current() == &"escape", "Setup: escape is the current objective.")
	# Phase 6: the dock also needs its shutter opened (release + OPEN; tested in
	# tests/expanded_escape_tests.gd). Opened here, only the power decides.
	_dock.unlock()
	_service.interact(_player)   # service OFF
	_expect(not _dock.is_unlocked() and _dock.rejection_reason().contains("SERVICE EXIT"), "Dock: without service power it stays shut and says why (%s)." % _dock.rejection_reason())
	await _frames(2)
	_expect(_dock._sign == null or _dock._sign.text == "SHUTTER · NO POWER", "Dock: its sign says NO POWER.")
	_dock.interact(_player)
	_expect(_hud.get_message_text().contains("SERVICE EXIT"), "Dock: using it explains it (%s)." % _hud.get_message_text())
	_expect(_director.status != S.ESCAPED, "Dock: no escape without power.")
	# No softlock: from every combination, the switches (no one-way) reach a winning state.
	var reachable := 0
	for mask in 8:
		_power.set_powered(&"archive_access", mask & 1 != 0)
		_power.set_powered(&"surveillance", mask & 2 != 0)
		_power.set_powered(&"service_exit", mask & 4 != 0)
		_surveillance.lock(0.0)
		var presses := 0
		while not _power.is_powered(&"service_exit") and presses < 2:
			_service.interact(_player)
			presses += 1
		if _dock.is_unlocked():
			reachable += 1
		# And back: every switch can be undone.
		_service.interact(_player)
		_surveillance.lock(0.0)
		var undone := not _power.is_powered(&"service_exit")
		_surveillance.interact(_player)
		_surveillance.interact(_player)
		_expect(undone, "Switches: service ON can always be turned OFF again.")
	_expect(reachable == 8, "No softlock: from all 8 combinations one press of SERVICE EXIT opens the dock (%d/8)." % reachable)
	_expect(_drain.objective_id == &"escape" and _drain.extra_key_objective_id == &"drain_culvert" and _drain.power_circuit == &"", "The storm drain stays the power-free alternative.")
	_service.interact(_player) if not _power.is_powered(&"service_exit") else null
	# Phase 6: walked through (real input).
	_player.global_position = Vector3(34.6, 0.05, 24)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = -PI / 2.0   # facing +x
	Input.action_press("move_forward")
	for i in 120:
		await _host.get_tree().physics_frame
		if _director.status == S.ESCAPED:
			break
	Input.action_release("move_forward")
	await _frames(2)
	_expect(_director.status == S.ESCAPED and _objectives.is_finished(), "Dock: with the manuscript and service power, the dock exit finishes the level.")
	print("  [expanded-security] service: reboot → cameras ON + surveillance switch locked %.1f s (refused with a message), then switchable again; dock refused without SERVICE EXIT ('SHUTTER · NO POWER'), opens with it; from all 8 combinations the dock is reachable; storm drain power-free" % waited)
	# Reload for the next checks (the level is finished).
	await _unload()
	await _load(false)


# --- I. Checkpoints ----------------------------------------------------------------------------------------

func _check_checkpoints() -> void:
	var checkpoints := CheckpointManager.find(_level)
	var cp: Checkpoint = _level.get_tree().get_nodes_in_group("checkpoints")[0]
	checkpoints.activate(cp)   # stored: surveillance ON, service OFF
	_surveillance.interact(_player)
	_service.interact(_player)   # service ON, surveillance rebooted ON and locked
	_surveillance.lock(30.0)
	_expect(_power.is_powered(&"service_exit") and _surveillance.lock_left > 0.0, "Checkpoint setup.")
	var at := Vector3(-18, 0, -9)
	_player.global_position = at + Vector3(0, 0.05, 0)
	var guard := await _spawn_guard("Catcher", [at + Vector3(-1.0, 0, 0)], Vector3(1, 0, 0))
	var caught := false
	for i in 60 * 10:
		await _host.get_tree().physics_frame
		if _director.status == S.CAUGHT:
			caught = true
		if caught and _director.status != S.CAUGHT:
			break
	await _frames(5)
	_expect(caught, "Checkpoint: the test guard should catch the player.")
	_expect(_power.is_powered(&"surveillance") and not _power.is_powered(&"service_exit") and _service.index == 0 and _surveillance.index == 1,
		"Checkpoint: caught → the circuits are back as stored (surveillance ON, service OFF).")
	_expect(_surveillance.lock_left == 0.0, "Checkpoint: a respawn ends the reboot lock.")
	await _free_guard(guard)
	print("  [expanded-security] checkpoints: caught → circuits restored to the checkpoint (service OFF, surveillance ON, switches agree), reboot lock cleared")


# --- J. Basement guard and stairs ------------------------------------------------------------------------------

func _check_stair_chase() -> void:
	# A guard at the bottom of the east service stair (basement, z -8) sees the player at the top
	# (ground, z -17, the electrical room's doorway), chases up, loses them, searches, walks back down.
	var post := Vector3(44.2, BF, -6.8)
	var guard := await _spawn_guard("EastStairGuard", [post], Vector3(0, 0, -1))
	var top := Vector3(44.2, 0, -19.5)
	_player.global_position = top + Vector3(0, 0.05, 0)
	var chased := await _wait_state(guard, CHASE, 10.0)
	_expect(chased, "Stairs: a guard at the foot of the east service stair should see and chase the player at the top.")
	_player.global_position = Vector3(38.5, 0.05, -25.5)   # into the electrical room, out of sight
	var highest := -INF
	var back := false
	for i in 60 * 80:
		await _host.get_tree().physics_frame
		highest = maxf(highest, guard.global_position.y)
		if highest > -0.4:
			_park_player()
		if highest > -0.4 and guard.machine.current == PATROL and guard.global_position.distance_to(post) < 1.6:
			back = true
			break
	_expect(highest > -0.4, "Stairs: the guard should run up to the ground floor (highest y %.2f)." % highest)
	_expect(back, "Stairs: after searching it should walk back down to its basement post (at %s, %s)." % [guard.global_position, GuardStateMachine.NAMES[guard.machine.current]])
	await _free_guard(guard)
	print("  [expanded-security] stairs: chased up the east service stair to the electrical room (y %.1f), searched, walked back down to the basement post" % highest)


func _check_basement_patrol() -> void:
	var guard: Guard = _level.get_node("Guards/GuardBasement")
	_park_player()
	var reached := []
	var stuck := [0]
	guard.patrol_point_reached.connect(func(i): reached.append(i))
	guard.got_stuck.connect(func(_i): stuck[0] += 1)
	var ymin := INF
	var ymax := -INF
	var xmin := INF
	var xmax := -INF
	Engine.time_scale = 3.0
	var game_time := 0.0
	var count := guard.patrol_route.get_point_count()
	while game_time < 200.0:
		await _host.get_tree().physics_frame
		game_time += 3.0 / Engine.physics_ticks_per_second
		ymin = minf(ymin, guard.global_position.y)
		ymax = maxf(ymax, guard.global_position.y)
		xmin = minf(xmin, guard.global_position.x)
		xmax = maxf(xmax, guard.global_position.x)
		if _full_loop(reached, count):
			break
	Engine.time_scale = 1.0
	_expect(count == 5, "GuardBasement: 5 patrol points (%d)." % count)
	_expect(_full_loop(reached, count), "GuardBasement: should complete its loop in order (reached %s in %.0f s)." % [reached, game_time])
	_expect(stuck[0] == 0 and guard.machine.current == PATROL, "GuardBasement: never stuck, stays on patrol.")
	_expect(ymax < BF + 0.6 and ymin > BF - 0.3, "GuardBasement: stays in the basement (y %.2f…%.2f)." % [ymin, ymax])
	_expect(xmin < -28.0 and xmax > 37.0, "GuardBasement: covers the tunnel from the west end to the east basement (x %.1f…%.1f)." % [xmin, xmax])
	print("  [expanded-security] basement guard: %d-point loop in order in %.0f s game time, 0 stuck, y %.2f…%.2f, x %.1f…%.1f" % [count, game_time, ymin, ymax, xmin, xmax])


# --- Helpers -----------------------------------------------------------------------------------------------

func _load(keep_guards: bool) -> void:
	_level = (load(SCENE) as PackedScene).instantiate()
	if not keep_guards:
		for g in _level.get_node("Guards").get_children():
			if g is Guard:
				g.get_parent().remove_child(g)
				g.free()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, Layout.SPAWN), "Navigation never became ready.")
	_player = _level.get_node("Player")
	GameFlow.find(_level).change_scene = func(_path: String): pass
	_power = PowerNetwork.find(_level)
	_alarm = SecurityAlarm.find(_level)
	_director = StealthDirector.find(_level)
	_objectives = ObjectiveManager.find(_level)
	_hud = _level.get_node("ObjectiveHud")
	_surveillance = _level.get_node(SEC + "SurveillanceSwitch")
	_service = _level.get_node(SEC + "ServiceExitSwitch")
	_cameras = _level.get_tree().get_nodes_in_group("security_cameras")
	_keypad = _level.get_node(MISSION + "VaultKeypad")
	_dock = _level.get_node("Gameplay/ExitDoor")
	_drain = _level.get_node(MISSION + "StormDrainExit")
	_noises.clear()
	NoiseSystem.find(_level).noise_emitted.connect(func(e: NoiseEvent): _noises.append(e))
	await _frames(10)


func _unload() -> void:
	Engine.time_scale = 1.0
	Input.action_release("crouch")
	_level.queue_free()
	await _frames(30)


func _park_player() -> void:
	_player.global_position = Vector3(0, 0.05, 32)   # outside the doors, out of everyone's way
	_player.velocity = Vector3.ZERO


func _spot(spot_name: String) -> HidingSpot:
	for spot in _level.get_tree().get_nodes_in_group("hiding_spots"):
		if spot.name == spot_name.replace(" ", "") or String(spot.get_meta("display_name", "")) == spot_name or String(spot.name).to_lower().replace("_", " ") == spot_name.to_lower():
			return spot
	# Fall back to the layout position.
	for h in Layout.HIDING:
		if h.name == spot_name:
			for spot in _level.get_tree().get_nodes_in_group("hiding_spots"):
				if _flat(spot.global_position, h.pos) < 0.5:
					return spot
	return null


## A test guard with the expanded rules, its own route through `points`, facing `facing`.
func _spawn_guard(guard_name: String, points: Array, facing: Vector3) -> Guard:
	var route := PatrolRoute.new()
	route.name = guard_name + "Route"
	for p in points:
		var marker := PatrolPoint.new()
		marker.position = p
		route.add_child(marker)
	_level.add_child(route)
	var guard: Guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	guard.name = guard_name
	guard.patrol_route = route
	guard.expanded_security = true
	guard.position = points[0] + Vector3(0, 0.05, 0)
	if facing.length_squared() > 0.001:
		guard.rotation.y = atan2(-facing.x, -facing.z)
	_level.add_child(guard)
	for i in 30:
		await _host.get_tree().physics_frame
		if guard.machine != null and guard.machine.current != GuardStateMachine.NONE:
			break
	return guard


func _free_guard(guard: Guard) -> void:
	var route := guard.patrol_route
	guard.queue_free()
	if route:
		route.queue_free()
	await _frames(3)


func _wait_state(guard: Guard, state: int, seconds: float) -> bool:
	for i in int(seconds * 60):
		if guard.machine.current == state:
			return true
		await _host.get_tree().physics_frame
	return guard.machine.current == state


## True once `reached` holds every point 0…count-1 in order, followed by 0 again.
func _full_loop(reached: Array, count: int) -> bool:
	var expect := 0
	var done := 0
	for i in reached:
		if i == expect:
			expect = (expect + 1) % count
			done += 1
	return done >= count + 1


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
