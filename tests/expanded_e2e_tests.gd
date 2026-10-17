extends RefCounted

## Expansion Phase 8: the Expanded Library played end to end, from the porch to
## a successful escape, walked with real input (tests/e2e_walker.gd: the move
## keys along a navigation path, E on what the interactor focuses, F to throw,
## 1–3 to pick a slot; no teleporting during a run). Called from tests/test_scene.gd.
##
##   A. Mandatory-only run, out by the loading dock, in this order: card →
##      archive gate → tool kit → electrical room → wrong breakers (trip),
##      recovered → service power → dock shutter (walked into the dock exit
##      without the manuscript: refused) → wrong vault code, recovered →
##      manuscript → a tour of every area of every zone and every stair with
##      the manuscript carried (navigation and backtracking) → out by the dock.
##      0 of 3 optional objectives.
##   B. Every optional objective, out by the main entrance, in another order:
##      rota → locker (badge, bottle, patrol notes revealed) → badge override,
##      walked into the main entrance without the manuscript: refused → card →
##      pump log (optional revealed) → tool kit → pump (grate cleared) → a
##      capture: inventory, objectives and puzzles exactly as the checkpoint
##      stored them, the journal kept → power → vault → manuscript → back gate
##      (the shortcut) and down the staff stair it opens → out by the main
##      entrance. 3 of 3 optional objectives.
##   C. The hidden passage, with the circuits switched in another order, in a
##      third order: tool kit → electrical room by the basement stair without
##      the card → SURVEILLANCE off, SERVICE EXIT on (reboot), SERVICE off,
##      breakers → pump → culvert plan → hidden panel → walked into the storm
##      drain without the manuscript: refused → card → vault → manuscript → out
##      through the storm drain.
##   D. Distractions thrown (F) at a guard on PATROL (it investigates the
##      landing), during INVESTIGATE (the search moves to the new landing) and
##      during CHASE (ignored: it keeps chasing the player).
##   E. The original Library tutorial replayed afterwards, walked to its win.
## Guards are removed for A–C and E (determinism); D uses its own test guard.
## Real playtime with the level's guards is measured by
## tools/expanded/playtest_bot.gd, not here.

const SCENE := "res://scenes/level/expanded_library.tscn"
const TUTORIAL := "res://scenes/level/library_graybox.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const Layout := preload("res://tools/expanded/expanded_layout.gd")
const X := preload("res://tools/expanded/expansion/expansion_layout.gd")
const TestUtils := preload("res://tests/test_utils.gd")
const Walker := preload("res://tests/e2e_walker.gd")
const S := StealthDirector.Status
const U := Layout.UPPER_Y
const B := X.BF
const M := "Expansion/Gameplay/Mission/"
const D := "Expansion/Gameplay/Documents/"
const E := "Expansion/Gameplay/Escape/"
const SPEED := 3.0
const OPTIONAL := [&"unlock_shortcut", &"drain_culvert", &"security_locker"]
const VAULT_CODE := "2691"
const LOCKER_CODE := "136"

# Stand points (on the floor, in reach of the thing used).
const IN_LOBBY := Vector3(0, 0, 20)
const AT_PLAQUE := Vector3(-10.6, 0, 20)
const AT_CARD := Vector3(4.9, U, -23.0)
const AT_MEMO := Vector3(10.6, U, -20.0)
const AT_ROTA := Vector3(4.6, U, -17.0)
const AT_LOCKER := Vector3(-4.7, U, -21.4)
const AT_BADGE := Vector3(-4.2, U, -21.7)
const AT_LOCKER_BOTTLE := Vector3(-4.2, U, -22.4)
const G2_WEST := Vector3(10.6, U, -11)
const AT_KEYPAD := Vector3(26.7, U, -19.3)
const IN_VAULT := Vector3(32, U, -23.6)
const AT_G3 := Vector3(28.8, U, -9)
const AT_TOOLKIT := Vector3(-24.8, B, -20.2)
const AT_PANEL := Vector3(41.0, 0, -25.9)
const AT_NOTICE := Vector3(44.5, 0, -24.0)
const AT_CHART := Vector3(26.0, 0, -26.6)
const AT_SURVEILLANCE := Vector3(38.8, 0, -25.9)
const AT_SERVICE := Vector3(43.2, 0, -25.9)
const AT_RELEASE := Vector3(34.9, 0, 21.4)
const AT_CONTROL := Vector3(34.9, 0, 26.4)
const AT_READER := Vector3(2.9, 0, 26.8)
const AT_PUMP_LOG := Vector3(5.6, B, -17.0)
const AT_PUMP := Vector3(0.0, B, -15.5)
const AT_PLAN := Vector3(-23.5, B, -18.2)
const AT_HIDDEN_PANEL := Vector3(0.0, B, -25.4)
const EAST_STAIR_FOOT := Vector3(44.2, B, -6.8)

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _player: FirstPersonPlayer
var _inventory: PlayerInventory
var _objectives: ObjectiveManager
var _checkpoints: CheckpointManager
var _director: StealthDirector
var _power: PowerNetwork
var _hud: ObjectiveHud
var _w
var _section := ""
var _ok := true
var _guard: Guard
var _route: PatrolRoute
## Per run: [label, game seconds, metres walked] for the report.
var timings: Array = []


func run(host: Node) -> Array[String]:
	_host = host
	await _run_mandatory_dock()
	await _run_optional_main()
	await _run_passage_circuits()
	await _check_distractions()
	await _replay_tutorial()
	await _unload()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[expanded-e2e] %s: %s" % [_section, message])


## One step of a run: on failure, the rest of the run is skipped (no cascade).
func _step(label: String, ok: bool) -> bool:
	if _ok and not ok:
		_ok = false
		failures.append("[expanded-e2e] %s: step '%s' failed: %s" % [_section, label, _w.last_error])
	return _ok


func _begin(section: String) -> void:
	_section = section
	_ok = true


# --- A. Mandatory only, loading dock -----------------------------------------------------------

func _run_mandatory_dock() -> void:
	_begin("A mandatory-only run")
	await _load(SCENE)
	var steps: Array[String] = []
	if _step("into the lobby", await _w.walk_to(IN_LOBBY)):
		_expect(_objectives.is_completed(&"enter_library"), "Walking in completes enter_library.")
	if _step("plaque", await _w.use(_doc("LobbyPlaque"), AT_PLAQUE)):
		_hud.close_journal()
	if _step("card", await _w.use(_level.get_node("Gameplay/StaffAccessCard"), AT_CARD)):
		_expect(_objectives.is_completed(&"take_card") and _inventory.has(ItemCatalog.STAFF_CARD), "Card taken and carried.")
	if _step("memo", await _w.use(_doc("ArchivistMemo"), AT_MEMO)):
		_hud.close_journal()
	_step("archive gate", await _w.use(_level.get_node("Gameplay/ArchiveFrontGateG2"), G2_WEST))
	if _step("tool kit", await _w.use(_level.get_node("Expansion/Gameplay/Items/ToolKit"), AT_TOOLKIT)):
		_expect(_objectives.is_completed(&"find_toolkit"), "Tool kit found.")
	if _step("notice", await _w.use(_doc("ElectricalNotice"), AT_NOTICE)):
		_hud.close_journal()
	if _step("panel cover", await _w.use(_level.get_node(M + "ElectricalPanelCover"), AT_PANEL)):
		_expect(_objectives.is_completed(&"open_panel"), "The cover is off.")
	if _step("wiring chart", await _w.use(_doc("WiringChart"), AT_CHART)):
		_hud.close_journal()
	# A wrong breaker setting first (A1 + A2), then the right one.
	var breakers: BreakerPanel = _level.get_node(M + "BreakerPanel")
	var alarm := SecurityAlarm.find(_level)
	var alarms := [0]
	alarm.alarm_raised.connect(func(_at, _r): alarms[0] += 1)
	if _ok:
		for i in [0, 1]:
			_step("wrong breaker %d" % i, await _w.use(breakers.breakers[i], AT_PANEL))
		_step("main (wrong)", await _w.use(breakers.main_switch, AT_PANEL))
		_expect(breakers.trips == 1 and not breakers.is_solved and alarms[0] >= 1 and not _power.is_powered(&"archive_access"),
			"A wrong setting trips the main breaker and raises the alarm, no power (trips %d, alarms %d)." % [breakers.trips, alarms[0]])
		_expect(not breakers.get_setting().has(true), "The breakers drop back to OFF.")
		if _ok:
			await _set_breakers(breakers, [true, false, true, true])
		_step("main (right)", await _w.use(breakers.main_switch, AT_PANEL))
		_expect(breakers.is_solved and _power.is_powered(&"archive_access") and _objectives.is_completed(&"restore_power"), "The right setting restores the vault's power.")
	steps.append("breakers wrong → right")
	if _step("service switch", await _w.use(_level.get_node("Expansion/Gameplay/Security/ServiceExitSwitch"), AT_SERVICE)):
		_expect(_power.is_powered(&"service_exit"), "SERVICE EXIT is on.")
	_step("shutter release", await _w.use(_level.get_node(E + "DockShutterRelease"), AT_RELEASE))
	var dock: ExitDoor = _level.get_node("Gameplay/ExitDoor")
	if _step("shutter control", await _w.use((_level.get_node(E + "DockShutterControl") as DockShutter).button, AT_CONTROL)):
		_expect(dock.unlocked, "The shutter is open.")
	# The dock exit without the manuscript.
	if _ok:
		var refused := await _walk_into_exit(Vector3(34.6, 0, 24), Vector3(39, 0, 24))
		_expect(not refused[0] and refused[1] == "You can't leave without the rare manuscript.",
			"Walking out of the dock without the manuscript is refused (escaped %s, message '%s')." % [refused[0], refused[1]])
	# A wrong code, then the right one (back up through the archive's front gate).
	var keypad: CodeLock = _level.get_node(M + "VaultKeypad")
	# One-way doors from the wrong side: up the staff stair, the back gate refuses.
	var g3: AccessDoor = _level.get_node("Gameplay/ArchiveBackGateG3")
	if _step("staff stair to the back gate", await _w.walk_to(Vector3(31.2, U, -9.0), 180.0)):
		var opened: bool = await _w.use_door(g3)
		_expect(not opened and not g3.is_open and _w.refusals[-1].contains("only opens from the other side"),
			"From the staff stair landing the back gate refuses (%s)." % (_w.refusals[-1] if not _w.refusals.is_empty() else "opened"))
	if _ok:
		# Back by the lobby and the main stair (the staff stair ends at the one-way back gate).
		_step("to the lobby", await _w.walk_to(IN_LOBBY, 180.0))
		_step("up to the archive gate", await _w.walk_to(G2_WEST, 180.0))
		_step("wrong code", await _w.enter_code(keypad, "1234", AT_KEYPAD))
		_expect(not keypad.is_solved and keypad.attempts_left == keypad.max_attempts - 1, "A wrong code is refused (%d tries left)." % keypad.attempts_left)
		_step("right code", await _w.enter_code(keypad, VAULT_CODE, AT_KEYPAD))
		_expect(keypad.is_solved and _objectives.is_completed(&"open_vault"), "The right code opens the vault.")
	if _step("manuscript", await _w.use(_level.get_node("Gameplay/RareManuscript"), IN_VAULT)):
		_expect(_objectives.is_completed(&"take_manuscript") and _objectives.current() == &"escape", "Manuscript taken; escape is next.")
	var mission_time: float = _w.game_time
	var mission_walk: float = _w.walked
	_expect(OPTIONAL.all(func(id): return not _objectives.is_completed(id)), "The manuscript is reached with no optional objective done (%s; doors %s)." % [OPTIONAL.filter(func(id): return _objectives.is_completed(id)), _w.doors_opened])
	# The tour: every area, every stair, the manuscript carried, back again.
	if _ok:
		await _tour(["Porch", "Storm Drain"])
	# Out by the dock.
	if _ok:
		var out := await _walk_into_exit(Vector3(34.6, 0, 24), Vector3(39, 0, 24))
		_expect(out[0], "Walking out of the open dock with the manuscript escapes.")
		_expect(_objectives.is_finished() and GameFlow.find(_level).state == GameStateMachine.State.WIN, "The level is won.")
		# The tour walked through the back gate (E on the way), which opens the shortcut.
		_expect(OPTIONAL.all(func(id): return id == &"unlock_shortcut" or not _objectives.is_completed(id)), "No other optional objective was done on the way out.")
		_expect(_objectives.escape_route == &"loading_dock", "Route recorded: %s." % _objectives.escape_route)
	timings.append(["A mission (no guards)", mission_time, mission_walk])
	timings.append(["A with the tour", _w.game_time, _w.walked])
	print("  [expanded-e2e] A mandatory only (walked, real input): card → archive gate → tool kit → panel → breakers wrong (trip, alarm) → right → service → shutter → dock refused without the manuscript → code wrong → right → manuscript (%.0f s game time, %.0f m without guards) → tour of every area and stair with the manuscript → out by the dock: WIN, 0/3 optional; doors opened on the way: %s" % [
		mission_time, mission_walk, ", ".join(_w.doors_opened)])


## Walks to the centre of every area of every zone and both ends of every stair
## (nearest first), then checks each stair was walked from end to end.
func _tour(skip: Array) -> void:
	var targets := []   # [label, point]
	for z in Layout.ZONES:
		var y := U if z.floor == "upper" else 0.0
		for a in z.areas:
			if a.name in skip:
				continue
			targets.append([a.name, _closest(Vector3((a.rect[0] + a.rect[2]) / 2.0, y, (a.rect[1] + a.rect[3]) / 2.0))])
	for z in X.ZONES:
		for a in z.areas:
			if a.name in skip:
				continue
			targets.append([a.name, _closest(Vector3((a.rect[0] + a.rect[2]) / 2.0, a.y, (a.rect[1] + a.rect[3]) / 2.0))])
	var stairs := _stairs()
	for s in stairs:
		targets.append([s.name + " low", s.low])
		targets.append([s.name + " high", s.high])
	var trace_from: int = _w.trace.size()
	var visited := 0
	var failed: Array[String] = []
	while not targets.is_empty():
		var here := _player.global_position
		var best := 0
		var best_len := INF
		for i in targets.size():
			var l := _path_len(here, targets[i][1])
			if l < best_len:
				best_len = l
				best = i
		var t: Array = targets.pop_at(best)
		if await _w.walk_to(t[1], 150.0):
			visited += 1
		else:
			failed.append("%s (%s)" % [t[0], _w.last_error])
	_expect(failed.is_empty(), "Tour: every area and stair end reachable on foot; not reached: %s." % "; ".join(failed))
	var unwalked: Array[String] = []
	for s in stairs:
		if not _walked_stair(s, trace_from):
			unwalked.append(s.name)
	_expect(unwalked.is_empty(), "Tour: every stair walked end to end; not: %s." % ", ".join(unwalked))
	print("  [expanded-e2e] tour: %d areas and stair ends reached on foot, %d stairs walked end to end (%s), doors opened: %s" % [
		visited, stairs.size() - unwalked.size(), ", ".join(stairs.map(func(s): return s.name)), ", ".join(_w.doors_opened)])


## The stairs: the existing level's S1–S3 and the expansion's two service stairs,
## each {name, low, high, rect [x0, z0, x1, z1], y_low, y_high}.
func _stairs() -> Array:
	var out := []
	for st in Layout.STAIRS:
		var ends := Layout.stair_ends(st)
		out.append({"name": st.name, "low": _closest(ends[0]), "high": _closest(ends[1]),
			"rect": [st.x0, minf(st.z_low, st.z_high), st.x1, maxf(st.z_low, st.z_high)], "y_low": 0.0, "y_high": U})
	for r in X.RAMPS:
		var x: float = (r.x0 + r.x1) / 2.0
		var dir := signf(r.z_bottom - r.z_top)
		out.append({"name": r.name, "high": _closest(Vector3(x, 0, r.z_top - dir * 1.5)), "low": _closest(Vector3(x, B, r.z_bottom + dir * 1.5)),
			"rect": [r.x0, minf(r.z_top, r.z_bottom), r.x1, maxf(r.z_top, r.z_bottom)], "y_low": B, "y_high": 0.0})
	return out


## True if the trace went over the stair's lower and upper thirds.
func _walked_stair(s: Dictionary, from: int) -> bool:
	var low := false
	var high := false
	var span: float = s.y_high - s.y_low
	for k in range(from, _w.trace.size()):
		var p: Vector3 = _w.trace[k]
		if p.x < s.rect[0] - 0.5 or p.x > s.rect[2] + 0.5 or p.z < s.rect[1] - 0.5 or p.z > s.rect[3] + 0.5:
			continue
		var f: float = (p.y - s.y_low) / span
		if f > 0.1 and f < 0.4:
			low = true
		elif f > 0.6 and f < 0.9:
			high = true
	return low and high


# --- B. Every optional objective, main entrance ----------------------------------------------

func _run_optional_main() -> void:
	_begin("B optional run")
	await _load(SCENE)
	_step("into the lobby", await _w.walk_to(IN_LOBBY))
	# The rota reveals the locker; its code opens it.
	if _step("rota", await _w.use(_doc("NightRota"), AT_ROTA)):
		_hud.close_journal()
		_expect(_objectives.is_visible(&"security_locker"), "The rota reveals the optional locker.")
	var locker: CodeLock = _level.get_node(M + "SecurityLocker")
	if _step("locker code", await _w.enter_code(locker, LOCKER_CODE, AT_LOCKER)):
		_expect(locker.is_solved and _objectives.is_completed(&"security_locker"), "The locker opens (optional done).")
	var badge: ItemPickup = _level.get_node("Expansion/Gameplay/Items/LockerBadge")
	var bottle: ItemPickup = _level.get_node("Expansion/Gameplay/Items/LockerBottle")
	var notes: DocumentPickup = _doc("PatrolNotes")
	_expect(badge.available and bottle.available and notes.is_inside_tree() and notes.visible, "Effect: the locker reveals the badge, a bottle and the patrol notes.")
	_step("badge", await _w.use(badge, AT_BADGE))
	if _step("patrol notes", await _w.use(notes, AT_LOCKER_BOTTLE)):
		_hud.close_journal()
	# The bottle stays in the locker: badge, card and tool kit fill the three slots.
	_expect(_inventory.has(ItemCatalog.SECURITY_BADGE) and _inventory.has_document(&"patrol_notes"), "Badge carried, notes in the journal.")
	# The override, then the main entrance without the manuscript.
	var main: ExitDoor = _level.get_node(E + "MainEntranceExit")
	var reader: BadgeReader = _level.get_node(E + "BadgeReader")
	if _step("badge reader", await _w.use(reader, AT_READER)):
		await _game_seconds(reader.hold_time + 0.6)
		_expect(main.unlocked, "Effect: the badge's override lifts the lockdown.")
	if _ok:
		var refused := await _walk_into_exit(Vector3(0, 0, 26.8), Vector3(0, 0, 31.0))
		_expect(not refused[0] and refused[1] == "You can't leave without the rare manuscript.",
			"Walking out of the main entrance without the manuscript is refused (escaped %s, '%s')." % [refused[0], refused[1]])
	_step("card", await _w.use(_level.get_node("Gameplay/StaffAccessCard"), AT_CARD))
	if _step("memo", await _w.use(_doc("ArchivistMemo"), AT_MEMO)):
		_hud.close_journal()
	_step("archive gate", await _w.use(_level.get_node("Gameplay/ArchiveFrontGateG2"), G2_WEST))
	# The pump: its log reveals it; the crank needs the tool kit.
	if _step("pump log", await _w.use(_doc("PumpRoomLog"), AT_PUMP_LOG)):
		_hud.close_journal()
		_expect(_objectives.is_visible(&"drain_culvert"), "The pump log reveals the optional culvert objective.")
	_step("tool kit", await _w.use(_level.get_node("Expansion/Gameplay/Items/ToolKit"), AT_TOOLKIT))
	_expect(_inventory.has(ItemCatalog.TOOLKIT) and _inventory.count() == 3, "Badge, card and tool kit: hands full (%s)." % [_inventory.slots])
	await _run_pump()
	var grate := _level.get_node("Expansion/Geometry/G_ServiceNetwork/StormDrainGrate") as StaticBody3D
	_expect(_objectives.is_completed(&"drain_culvert") and not grate.visible and grate.collision_layer == 0, "Effect: the pump drains the culvert and clears the grate.")
	# A capture: everything back as the checkpoint stored it, the journal kept.
	if _ok:
		await _check_capture()
	# The capture undid the tool kit and the pump (taken after that checkpoint): again.
	if _ok and not _inventory.has(ItemCatalog.TOOLKIT):
		_step("tool kit again", await _w.use(_level.get_node("Expansion/Gameplay/Items/ToolKit"), AT_TOOLKIT))
		if not _objectives.is_completed(&"drain_culvert"):
			await _run_pump()
			_expect(_objectives.is_completed(&"drain_culvert"), "The pump can be done again after the capture.")
	# Power, vault, manuscript.
	_step("panel cover", await _w.use(_level.get_node(M + "ElectricalPanelCover"), AT_PANEL))
	var breakers: BreakerPanel = _level.get_node(M + "BreakerPanel")
	if _ok:
		await _set_breakers(breakers, [true, false, true, true])
	_step("main switch", await _w.use(breakers.main_switch, AT_PANEL))
	# Back up by the lobby and the main stair: the staff stair ends at the back
	# gate, which only opens from the archive.
	_step("to the lobby", await _w.walk_to(IN_LOBBY, 180.0))
	_step("up to the archive gate", await _w.walk_to(G2_WEST, 180.0))
	_step("code", await _w.enter_code(_level.get_node(M + "VaultKeypad"), VAULT_CODE, AT_KEYPAD))
	_step("manuscript", await _w.use(_level.get_node("Gameplay/RareManuscript"), IN_VAULT))
	# The back gate (shortcut) and down the staff stair it opens.
	var g3: AccessDoor = _level.get_node("Gameplay/ArchiveBackGateG3")
	if _step("back gate", await _w.use(g3, AT_G3)):
		_expect(g3.is_open and _objectives.is_completed(&"unlock_shortcut"), "Effect: the back gate opens (optional done).")
	var before: float = _w.walked
	_step("through the back gate", await _w.walk_to(Vector3(31.4, U, -9)))
	_step("down the staff stair", await _w.walk_to(Vector3(34.35, 0, 5.5)))
	_expect(_w.walked - before < 25.0, "The shortcut leads straight down to storage (%.0f m)." % (_w.walked - before))
	# Out by the main entrance.
	if _step("to the lobby", await _w.walk_to(Vector3(0, 0, 25.0), 200.0)):
		var out := await _walk_into_exit(Vector3(0, 0, 26.8), Vector3(0, 0, 31.0))
		_expect(out[0], "Walking out of the main entrance with the manuscript escapes.")
		_expect(_objectives.is_finished() and _objectives.escape_route == &"main_entrance", "Won by the main entrance (%s)." % _objectives.escape_route)
		_expect(OPTIONAL.all(func(id): return _objectives.is_completed(id)), "All 3 optional objectives done.")
		var menus: GameMenus = _level.get_node("GameMenus")
		_expect(menus.get_objectives_text().contains("optional 3/3") and menus.get_objectives_text().contains("Escape route: Main entrance"), "Win text: %s." % menus.get_objectives_text())
	timings.append(["B all optional (no guards)", _w.game_time, _w.walked])
	print("  [expanded-e2e] B optional (walked): rota → locker 136 (badge, bottle, notes) → override → main entrance refused without the manuscript → card → pump log → tool kit → pump (grate cleared) → capture (state as stored, journal kept) → power → vault → manuscript → back gate → staff stair → out by the main entrance: WIN, 3/3 optional (%.0f s, %.0f m)" % [_w.game_time, _w.walked])


func _run_pump() -> void:
	var crank: ToolMechanism = _level.get_node(M + "PumpCrank")
	var pump: PumpControl = _level.get_node(M + "PumpControl")
	_step("pump crank", await _w.use(crank, AT_PUMP + Vector3(-3.4, 0, 0)))
	for i in [0, 2]:
		_step("valve %d" % (i + 1), await _w.use(pump.valves[i], AT_PUMP + Vector3(pump.valves[i].global_position.x, 0, 0)))
	_step("pump start", await _w.use(pump.start_lever, AT_PUMP + Vector3(pump.start_lever.global_position.x, 0, 0)))
	_expect(pump.is_solved, "The pump runs.")


## Caught by a test guard after a checkpoint: inventory, objectives and every
## puzzle exactly as the checkpoint stored them; documents kept; still playable.
func _check_capture() -> void:
	var docs := _inventory.documents.size()
	var saved_progress := _checkpoints.saved_progress.duplicate(true)
	var saved_state := _checkpoints.saved_state.duplicate(true)
	_expect(_checkpoints.active != null, "A checkpoint was reached on the way (pads are walked over).")
	var here := _player.global_position
	_spawn_guard(here + Vector3(0, 0, -2.5), 0.0)
	_guard.rotation.y = atan2(-(here.x - _guard.position.x), -(here.z - _guard.position.z))
	for i in 600:
		if _director.status == S.CAUGHT:
			break
		await _w.frame()
	_expect(_director.status == S.CAUGHT, "The test guard catches the player.")
	for i in 900:
		if _director.status != S.CAUGHT:
			break
		await _w.frame()
	_clear_guard()
	await _w.frames(5)
	_expect(_objectives.get_progress() == saved_progress, "After the capture the objectives are as stored.")
	_expect(_checkpoints.get_mission_state() == saved_state, "After the capture inventory, items, doors and puzzles are as stored.")
	_expect(_inventory.documents.size() == docs, "The journal keeps every document and clue (%d → %d)." % [docs, _inventory.documents.size()])
	print("  [expanded-e2e] capture at %s: back at '%s', objectives and %d mission-state entries as stored, journal kept (%d)" % [
		_w._v(here), _checkpoints.get_respawn_name(), saved_state.size(), docs])


# --- C. Hidden passage, circuits in another order ----------------------------------------------

func _run_passage_circuits() -> void:
	_begin("C passage run")
	await _load(SCENE)
	_step("into the lobby", await _w.walk_to(IN_LOBBY))
	_step("tool kit", await _w.use(_level.get_node("Expansion/Gameplay/Items/ToolKit"), AT_TOOLKIT))
	# Up the east service stair into the electrical room (no card: that door stays shut).
	_step("east service stair", await _w.walk_to(EAST_STAIR_FOOT))
	var surveillance: CircuitSwitch = _level.get_node("Expansion/Gameplay/Security/SurveillanceSwitch")
	var service: CircuitSwitch = _level.get_node("Expansion/Gameplay/Security/ServiceExitSwitch")
	var cameras := _level.get_tree().get_nodes_in_group("security_cameras")
	if _step("surveillance off", await _w.use(surveillance, AT_SURVEILLANCE)):
		_expect(not _power.is_powered(&"surveillance") and cameras.all(func(c): return not c.is_powered()), "SURVEILLANCE off: every camera off.")
	if _step("service on", await _w.use(service, AT_SERVICE)):
		_expect(_power.is_powered(&"service_exit") and _power.is_powered(&"surveillance") and surveillance.lock_left > 0.0, "SERVICE EXIT on: the cameras reboot and the surveillance switch locks.")
	if _step("surveillance while locked", await _w.use(surveillance, AT_SURVEILLANCE)):
		_expect(_power.is_powered(&"surveillance"), "The locked surveillance switch refuses.")
	if _step("service off", await _w.use(service, AT_SERVICE)):
		_expect(not _power.is_powered(&"service_exit") and _power.is_powered(&"surveillance"), "SERVICE EXIT off: only the dock loses power.")
	_step("panel cover", await _w.use(_level.get_node(M + "ElectricalPanelCover"), AT_PANEL))
	var breakers: BreakerPanel = _level.get_node(M + "BreakerPanel")
	if _ok:
		await _set_breakers(breakers, [true, false, true, true])
	if _step("main switch", await _w.use(breakers.main_switch, AT_PANEL)):
		_expect(_power.is_powered(&"archive_access") and not _power.is_powered(&"service_exit"), "ARCHIVE on, SERVICE still off: each circuit on its own.")
	await _game_seconds(surveillance.lock_left + 0.5)
	if _step("surveillance off again", await _w.use(surveillance, AT_SURVEILLANCE)):
		_expect(not _power.is_powered(&"surveillance") and _power.is_powered(&"archive_access"), "After the reboot lock the surveillance switch works again.")
	# Out the way we came (the card door is still shut), to the pump and the passage.
	_step("back down the east stair", await _w.walk_to(EAST_STAIR_FOOT))
	_step("pump log", await _w.use(_doc("PumpRoomLog"), AT_PUMP_LOG))
	_hud.close_journal()
	await _run_pump()
	var panel: AccessDoor = _level.get_node("Expansion/Gameplay/MaintenancePanel")
	_expect(not panel.is_discovered(), "The hidden panel is not findable before its plan.")
	if _step("culvert plan", await _w.use(_doc("CulvertAccessPlan"), AT_PLAN)):
		_hud.close_journal()
	if _step("hidden panel", await _w.use(panel, AT_HIDDEN_PANEL)):
		_expect(panel.is_open, "The latch opens the panel.")
	if _ok:
		var refused := await _walk_into_exit(Vector3(0, B, -34.6), Vector3(0, B, -39.5))
		_expect(not refused[0] and refused[1] == "You can't leave without the rare manuscript.",
			"Walking out of the storm drain without the manuscript is refused (escaped %s, '%s')." % [refused[0], refused[1]])
	_step("card", await _w.use(_level.get_node("Gameplay/StaffAccessCard"), AT_CARD))
	_step("archive gate", await _w.use(_level.get_node("Gameplay/ArchiveFrontGateG2"), G2_WEST))
	_step("code", await _w.enter_code(_level.get_node(M + "VaultKeypad"), VAULT_CODE, AT_KEYPAD))
	_step("manuscript", await _w.use(_level.get_node("Gameplay/RareManuscript"), IN_VAULT))
	if _step("back to the drain", await _w.walk_to(Vector3(0, B, -33.5), 240.0)):
		var out := await _walk_into_exit(Vector3(0, B, -34.6), Vector3(0, B, -39.5))
		_expect(out[0] and _objectives.escape_route == &"maintenance_passage", "Out through the storm drain with the manuscript (route %s)." % _objectives.escape_route)
		_expect(_objectives.is_finished() and _objectives.is_completed(&"drain_culvert"), "Won, the culvert optional done.")
	timings.append(["C passage (no guards)", _w.game_time, _w.walked])
	print("  [expanded-e2e] C passage (walked): tool kit → east service stair → SURVEILLANCE off → SERVICE on (reboot, switch locked) → refused while locked → SERVICE off → breakers → unlocked again → pump → plan → hidden panel → drain refused without the manuscript → card → vault → manuscript → out through the storm drain: WIN (%.0f s, %.0f m)" % [_w.game_time, _w.walked])


# --- D. Distractions in each guard state -------------------------------------------------------

func _check_distractions() -> void:
	_begin("D distractions")
	await _load(SCENE)
	Engine.time_scale = 1.0
	# A guard patrolling west along the main stacks aisle; the player 13 m behind it.
	_spawn_guard(Vector3(-26, 0, -9), PI / 2.0, [Vector3(-26, 0, -9), Vector3(-32, 0, -9)])
	await _w.frames(30)
	_player.global_position = Vector3(-13, 0.05, -9)
	_inventory.add(ItemCatalog.BOTTLE)
	_inventory.add(ItemCatalog.BOTTLE)
	_inventory.add(ItemCatalog.HARDBACK)
	await _w.frames(5)
	var investigate: InvestigateState = _guard.machine.get_state(GuardStateMachine.INVESTIGATE)
	# PATROL → INVESTIGATE at the landing.
	_expect(_guard.machine.current == GuardStateMachine.PATROL, "The guard starts on PATROL.")
	var first := await _throw_at(Vector3(-20, 0, -7.5))
	var investigating := await _until(func(): return _guard.machine.current == GuardStateMachine.INVESTIGATE, 4.0)
	_expect(investigating and investigate.target.distance_to(first) < 1.5, "PATROL: the guard investigates where it landed (target %s, landing %s)." % [investigate.target, first])
	# INVESTIGATE: a second throw moves the search.
	var second := await _throw_at(Vector3(-23, 0, -12))
	var moved := await _until(func(): return investigate.target.distance_to(second) < 1.5, 3.0)
	_expect(_guard.machine.current == GuardStateMachine.INVESTIGATE and moved, "INVESTIGATE: a new landing moves the search there (target %s, landing %s)." % [investigate.target, second])
	# CHASE: the guard sees the player; a throw does not distract it.
	var at_guard := _guard.global_position
	_player.global_position = at_guard + Vector3(7.0, 0.05, 0)
	_guard.rotation.y = atan2(-1.0, 0.0)   # facing +x, at the player
	var chasing := await _until(func(): return _guard.machine.current == GuardStateMachine.CHASE, 4.0)
	_expect(chasing, "The guard sees the player and gives chase.")
	var chase: ChaseState = _guard.machine.get_state(GuardStateMachine.CHASE)
	var third := await _throw_at(_player.global_position + Vector3(7, 0, 0.5))
	await _w.frames(20)
	_expect(_guard.machine.current == GuardStateMachine.CHASE and chase.target.distance_to(third) > 3.0 and chase.target.distance_to(_player.global_position) < 3.0,
		"CHASE: the guard ignores the noise and keeps after the player (state %s, target %s, landing %s)." % [GuardStateMachine.NAMES[_guard.machine.current], chase.target, third])
	_clear_guard()
	print("  [expanded-e2e] distractions thrown with F: PATROL → investigates the landing; INVESTIGATE → the search moves to the new landing; CHASE → ignored, still chasing the player")


## Selects the first distraction slot (its number key), aims at `floor_point` and
## presses F. Returns where the throw lands.
func _throw_at(floor_point: Vector3) -> Vector3:
	var landing := [Vector3.INF]
	var on_thrown := func(_id, at: Vector3): landing[0] = at
	_inventory.thrown.connect(on_thrown)
	for i in _inventory.slot_count:
		if ItemCatalog.get_kind(_inventory.get_item(i)) == ItemCatalog.Kind.DISTRACTION:
			await _w.press("item_slot_%d" % (i + 1))
			break
	_w.look_at(floor_point)
	await _w.frames(2)
	await _w.press("use_item")
	_inventory.thrown.disconnect(on_thrown)
	_expect(landing[0] != Vector3.INF, "The throw at %s should land (player %s, message '%s', state %s)." % [floor_point, _player.global_position, _hud.get_message_text(), _director.status])
	await _w.frames(40)   # in flight, lands, makes its noise
	return landing[0]


# --- E. The tutorial, replayed ------------------------------------------------------------------

func _replay_tutorial() -> void:
	_begin("E tutorial replay")
	await _load(TUTORIAL)
	var card: Node3D = _level.get_node("Gameplay/AccessCard")
	var door: Node3D = _level.get_node("Gameplay/ExitDoor")
	_step("main room", await _w.walk_to(Vector3(0, 0, 12.5)))
	_step("Hallway West", await _w.walk_to(Vector3(-10.5, 0, -9.5)))
	_step("Restricted Stacks", await _w.walk_to(Vector3(-9, 0, -20)))
	_step("access card", await _w.use(card, Vector3(-14.2, 0, -24.9)))
	_step("Staff Nook", await _w.walk_to(Vector3(8, 0, -25.8)))
	_step("exit door", await _w.use(door, Vector3(26.4, 0, -23)))
	await _w.frames(10)
	_expect(_objectives.is_finished() and GameFlow.find(_level).state == GameStateMachine.State.WIN, "The tutorial is won after the Expanded Library runs.")
	_expect(not _inventory.enabled if _inventory else true, "The tutorial has no inventory.")
	timings.append(["E tutorial (no guards)", _w.game_time, _w.walked])
	print("  [expanded-e2e] E tutorial replayed after the Expanded Library runs (walked): main room → Hallway West → Restricted Stacks → card → Staff Nook → exit: WIN (%.0f s, %.0f m)" % [_w.game_time, _w.walked])


# --- Helpers -----------------------------------------------------------------------------------

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
	_inventory = _player.get_node_or_null("Inventory")
	_objectives = ObjectiveManager.find(_level)
	_checkpoints = _level.get_node("Gameplay/CheckpointManager")
	_director = StealthDirector.find(_level)
	_power = PowerNetwork.find(_level)
	_hud = _level.get_node("ObjectiveHud")
	GameFlow.find(_level).change_scene = func(_p): pass
	_w = Walker.new()
	_w.setup(_level, _host)

	Engine.time_scale = SPEED
	await _w.frames(10)


func _unload() -> void:
	Engine.time_scale = 1.0
	if _w:
		_w.release()
	_clear_guard()
	if _level and is_instance_valid(_level):
		_level.queue_free()
		_level = null
		for i in 30:
			await _host.get_tree().process_frame


func _doc(node_name: String) -> DocumentPickup:
	return _level.get_node(D + node_name)


## Flips each breaker with E until the panel shows `setting`.
func _set_breakers(panel: BreakerPanel, setting: Array) -> void:
	for i in setting.size():
		if (panel.breakers[i].index == 1) != setting[i]:
			_step("breaker %d" % (i + 1), await _w.use(panel.breakers[i], AT_PANEL))


## Walks from `from` toward `toward` through an exit's trigger. Returns
## [escaped, the HUD message at the end].
func _walk_into_exit(from: Vector3, toward: Vector3) -> Array:
	var respawns := [0]
	var on_respawn := func(_cp): respawns[0] += 1
	_checkpoints.respawned.connect(on_respawn)
	var escaped: bool = await _w.walk_through(from, toward, 2.5, func(): return _director.status == S.ESCAPED)
	_checkpoints.respawned.disconnect(on_respawn)
	if not escaped:
		var message := _hud.get_message_text()
		# Expansion Phase 8 fix: a refused player stays on the floor at the threshold
		# (before it, they walked on past the trigger, fell out of the level and respawned).
		var here := _player.global_position
		_expect(respawns[0] == 0 and absf(here.y - from.y) < 0.3 and Vector2(here.x - from.x, here.z - from.z).length() < 3.0,
			"Refused at the exit, the player stays on the floor at its threshold (at %s, respawns %d)." % [here, respawns[0]])
		# Step back out of the trigger.
		await _w.walk_to(from)
		return [false, message]
	return [true, ""]


func _game_seconds(seconds: float) -> void:
	var start: float = _w.game_time
	while _w.game_time - start < seconds:
		await _w.frame()


func _until(done: Callable, seconds: float) -> bool:
	var start: float = _w.game_time
	while _w.game_time - start < seconds:
		if done.call():
			return true
		await _w.frame()
	return done.call()


func _closest(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(_level.get_world_3d().navigation_map, p)


func _path_len(a: Vector3, b: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(_level.get_world_3d().navigation_map, a, b, true)
	if path.is_empty():
		return INF
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total + absf(path[-1].y - b.y) * 10.0 + Vector2(path[-1].x - b.x, path[-1].z - b.z).length()


func _spawn_guard(at: Vector3, yaw: float, points: Array = []) -> void:
	_clear_guard()
	_route = PatrolRoute.new()
	for p in (points if not points.is_empty() else [at]):
		var post := PatrolPoint.new()
		post.position = p
		post.wait_time = 300.0 if points.is_empty() else 0.5
		_route.add_child(post)
	_level.add_child(_route)
	_guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	_guard.name = "E2ETestGuard"
	_guard.patrol_route = _route
	_guard.expanded_security = true
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
