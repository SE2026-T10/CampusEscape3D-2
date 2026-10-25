extends SceneTree

## Development tool: an automated playtester for the Expanded Library mission.
## It plays the real level, with the real guards, through the real player
## (input actions: move, crouch, sprint; the interact key through the
## PlayerInteractor), and records what happened.
##
##   godot --headless --path . --script res://maps/library/tools/playtest_bot.gd -- \
##       --route=dock --profile=careful --seed=1 --runs=1 --scale=3 --out=maps/library/docs/expansion/phase-8/playtests
##
## Expansion Phase 8: updated to the current mission (the Phase 4 objective
## graph, the Phase 5 circuits, the Phase 6 escape routes). It follows a route
## script: each step is skipped when the game already shows it done, so after a
## capture the bot carries on from what the checkpoint restored.
## Routes:
##   dock     mandatory objectives only, out by the loading dock;
##   main     the night rota and the security locker (optional) for the master
##            badge, the lobby reader's override, out by the main entrance;
##   passage  the pump (optional) and the culvert plan, the hidden panel, out
##            through the storm drain;
##   full     every optional objective (locker, pump, back gate shortcut), out
##            by the main entrance.
## The bot knows the map, the codes and the order (no searching, no time spent
## reading the documents it picks up): its times are a lower bound for a
## player who knows the level, not a first-time player's time.
##
## What the bot perceives (what a player can know):
##   - guards it can see: a guard counts as seen while there is a clear line of
##     sight from the player's eye to it within 30 m (a player looks around), and
##     its last seen position and heading are remembered for 2 s;
##   - the detection UI: whether a guard is noticing, investigating or chasing.
## It does not know where unseen guards are, their routes or their timers.
##
## Profiles:
##   careful  waits in cover until the path ahead is out of every seen guard's
##            view, backs off when noticed, crouches near guards, never sprints;
##   hasty    walks (sprints in the open), only reacts once a guard notices it;
##   reckless ignores the guards until one chases it (then runs);
##   learner  plays hasty until it has been caught twice, then careful.
## After every capture the bot checks that the objectives and the mission state
## (inventory, items, doors, puzzles, circuits, exits) equal what the checkpoint
## stored, and counts violations.
##
## Each run appends one JSON line to <out>/runs.jsonl and prints a summary:
## completion time (game time), captures (where, by whom, at which step),
## times noticed / investigated / chased, time spent waiting, forced moves
## (waited too long and went anyway), stalls (no progress for 8 min = softlock).

const Layout := preload("res://maps/library/tools/expanded_layout.gd")
const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const U := Layout.UPPER_Y
const S := StealthDirector.Status
const SIGHT_RANGE := 30.0
const MEMORY := 2.0
const WAIT_LIMIT := 45.0
const STALL_LIMIT := 480.0
const MAX_GAME_TIME := 2700.0

const B := -4.0
const VAULT_CODE := "2691"
const LOCKER_CODE := "136"
const M := "Expansion/Gameplay/Mission/"
const DOC := "Expansion/Gameplay/Documents/"
const ESC := "Expansion/Gameplay/Escape/"
# Stand points (on the floor, in reach), as maps/library/tests/expanded_e2e_tests.gd.
const IN_LOBBY := Vector3(0, 0, 20)
const AT_PLAQUE := Vector3(-10.6, 0, 20)
const AT_CARD := Vector3(4.9, U, -23.0)
const AT_MEMO := Vector3(10.6, U, -20.0)
const AT_ROTA := Vector3(4.6, U, -17.0)
const AT_LOCKER := Vector3(-4.7, U, -21.4)
const AT_BADGE := Vector3(-4.2, U, -21.7)
const G2_WEST := Vector3(10.6, U, -11)
const AT_KEYPAD := Vector3(26.7, U, -19.3)
const IN_VAULT := Vector3(32, U, -23.6)
const AT_G3 := Vector3(28.8, U, -9)
const AT_TOOLKIT := Vector3(-24.8, B, -20.2)
const AT_PANEL := Vector3(41.0, 0, -25.9)
const AT_NOTICE := Vector3(44.5, 0, -24.0)
const AT_CHART := Vector3(26.0, 0, -26.6)
const AT_SERVICE := Vector3(43.2, 0, -25.9)
const AT_RELEASE := Vector3(34.9, 0, 21.4)
const AT_CONTROL := Vector3(34.9, 0, 26.4)
const AT_READER := Vector3(2.9, 0, 26.8)
const AT_PUMP_LOG := Vector3(5.6, B, -17.0)
const AT_PUMP := Vector3(0.0, B, -15.5)
const AT_PLAN := Vector3(-23.5, B, -18.2)
const AT_HIDDEN_PANEL := Vector3(0.0, B, -25.4)

var _route := "dock"
var _profile := "careful"
var _profile_arg := "careful"
var _explore := false
var _verbose := false
var _seed := 1
var _scale := 3.0
var _out := ""
var _rng := RandomNumberGenerator.new()

var _level: Node3D
var _player: FirstPersonPlayer
var _interactor: PlayerInteractor
var _objectives: ObjectiveManager
var _director: StealthDirector
var _map: RID
var _space: PhysicsDirectSpaceState3D
var _guards: Array[Guard] = []
var _seen := {}          # guard -> {at, forward, t, velocity}
var _t := 0.0            # game time
var _log := {}
var _safe_trail: Array[Vector3] = []
var _status_prev := S.NONE
var _explored := {}      # objective id -> Array of points already searched
var _respawned := false
var _abort := false
var _last_progress_t := 0.0
var _doors: Array[AccessDoor] = []
## Where the player was caught (a player remembers where it went wrong).
var _catch_spots: Array[Vector3] = []
const HOT_RADIUS := 6.0
var _detours := {}
## Doors that refused the player, keyed by position (floor height).
var _blocked_doors := {}
var _step_label := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var runs := 1
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		match kv[0]:
			"route": _route = kv[1]
			"profile": _profile_arg = kv[1]
			"explore": _explore = true
			"verbose": _verbose = true
			"seed": _seed = int(kv[1])
			"runs": runs = int(kv[1])
			"scale": _scale = float(kv[1])
			"out": _out = kv[1]
	for r in runs:
		await _play(_seed + r)
	quit(0)


# --- One run --------------------------------------------------------------------------------

func _play(seed: int) -> void:
	_rng.seed = seed
	_profile = _profile_arg
	_level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_level)
	GameFlow.find(_level).change_scene = func(_p: String): pass
	for i in 30:
		await physics_frame
	_player = _level.get_node("Player")
	_interactor = _player.get_node("Interactor")
	_objectives = _level.get_node("Gameplay/ObjectiveManager")
	_director = _level.get_node("StealthDirector")
	_map = _level.get_world_3d().navigation_map
	_space = _level.get_world_3d().direct_space_state
	_guards.clear()
	_seen.clear()
	_explored.clear()
	for g in _level.get_node("Guards").get_children():
		if g is Guard:
			_guards.append(g)
	_t = 0.0
	_safe_trail = [_player.global_position]
	_status_prev = S.NONE
	_respawned = false
	_log = {"layout": Layout.VERSION, "route": _route, "profile": _profile, "explore": _explore, "seed": seed,
		"completed": false, "time_s": 0.0, "captures": [], "noticed": 0, "investigated": 0, "chased": 0,
		"wait_s": 0.0, "forced": 0, "stalled": false, "objective_times": {}, "walked_m": 0.0, "events": []}
	_catch_spots.clear()
	_detours.clear()
	_blocked_doors.clear()
	_director.player_caught.connect(func(by: Guard):
		_catch_spots.append(_player.global_position)
		_event("CAUGHT by %s" % by.name)
		_log.captures.append({"t": snappedf(_t, 0.1), "objective": _step_label, "guard": String(by.name),
			"at": _v(_player.global_position)}))
	_objectives.objective_completed.connect(func(id: StringName):
		_log.objective_times[String(id)] = snappedf(_t, 0.1)
		_last_progress_t = _t
		_respawned = false)
	Engine.time_scale = _scale
	# A player looks around at the start for a moment (seeded): this also varies
	# which part of their loops the guards are in when the player arrives.
	var delay := _rng.randf_range(0.0, 40.0)
	_log["start_delay_s"] = snappedf(delay, 0.1)
	while _t < delay:
		await _tick()
	_last_progress_t = _t
	_abort = false
	_doors.clear()
	for node in _level.get_tree().get_nodes_in_group("interactables"):
		if node is AccessDoor:
			_doors.append(node)
	var script := _script()
	while not _objectives.is_finished() and _t < MAX_GAME_TIME and not _abort:
		await _run_script(script)
	if _abort:
		_log.stalled = true
		_event("stalled at %s, objective %s" % [_v(_player.global_position), _objectives.current()])
	_release()
	Engine.time_scale = 1.0
	_log.completed = _objectives.is_finished()
	_log.time_s = snappedf(_t, 0.1)
	_log.walked_m = snappedf(_log.walked_m, 1.0)
	_log.wait_s = snappedf(_log.wait_s, 0.1)
	_log["route_name"] = String(_objectives.escape_route)
	_log["optional_done"] = [&"unlock_shortcut", &"drain_culvert", &"security_locker"].filter(func(id): return _objectives.is_completed(id)).size()
	print("RUN route=%s profile=%s explore=%s seed=%d: %s in %s, captures %d, noticed %d, investigated %d, chased %d, waited %.0f s, forced %d, state checks %d, violations %d%s" % [
		_route, _log.profile, _explore, seed, "completed" if _log.completed else "NOT completed", _clock(_t), _log.captures.size(),
		_log.noticed, _log.investigated, _log.chased, _log.wait_s, _log.forced, _log.get("state_checks", 0), _log.get("state_violations", 0), ", STALLED" if _log.stalled else ""])
	for c in _log.captures:
		print("    caught at %s (%s) by %s during %s" % [_clock(c.t), c.at, c.guard, c.objective])
	if _out != "":
		var dir := ProjectSettings.globalize_path("res://" + _out)
		DirAccess.make_dir_recursive_absolute(dir)
		var path := dir.path_join("runs.jsonl")
		var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
		f.seek_end()
		f.store_line(JSON.stringify(_log))
		f.close()
	_level.queue_free()
	for i in 30:
		await process_frame


## The route's steps: [label, kind, args, done]. Kinds: "go" (a point),
## "use" (node, stand, presses), "code" (lock, code, stand), "override" (the
## badge reader), "exit" (from, toward). `done` (a Callable, or null) tells
## when the game already shows the step done: it is then skipped.
func _script() -> Array:
	var n := func(path: String) -> Node3D: return _level.get_node(path)
	var obj := _objectives
	var inv: PlayerInventory = _player.get_node("Inventory")
	var has_doc := func(id: StringName) -> Callable: return func(): return inv.has_document(id)
	var done := func(id: StringName) -> Callable: return func(): return obj.is_completed(id)
	var carried := func(item: StringName, id: StringName) -> Callable: return func(): return inv.has(item) or (id != &"" and obj.is_completed(id))
	var breakers: BreakerPanel = n.call(M + "BreakerPanel")
	var pump: PumpControl = n.call(M + "PumpControl")
	var lobby := ["lobby", "go", [IN_LOBBY], null]
	var card := [["card", "use", [n.call("Gameplay/StaffAccessCard"), AT_CARD, 1], func(): return inv.has(ItemCatalog.STAFF_CARD)],
		["memo", "use", [n.call(DOC + "ArchivistMemo"), AT_MEMO, 1], has_doc.call(&"archivist_memo")],
		["archive gate", "use", [n.call("Gameplay/ArchiveFrontGateG2"), G2_WEST, 1], func(): return (n.call("Gameplay/ArchiveFrontGateG2") as AccessDoor).is_open]]
	var toolkit := [["tool kit", "use", [n.call("Expansion/Gameplay/Items/ToolKit"), AT_TOOLKIT, 1], carried.call(ItemCatalog.TOOLKIT, &"")]]
	var power := [["notice", "use", [n.call(DOC + "ElectricalNotice"), AT_NOTICE, 1], has_doc.call(&"electrical_notice")],
		["panel cover", "use", [n.call(M + "ElectricalPanelCover"), AT_PANEL, 1], done.call(&"open_panel")],
		["wiring chart", "use", [n.call(DOC + "WiringChart"), AT_CHART, 1], has_doc.call(&"wiring_chart")]]
	for i in 4:
		var want: bool = [true, false, true, true][i]
		power.append(["breaker %d" % (i + 1), "use", [breakers.breakers[i], AT_PANEL, 1],
			func(): return obj.is_completed(&"restore_power") or (breakers.breakers[i].index == 1) == want])
	power.append(["main breaker", "use", [breakers.main_switch, AT_PANEL, 1], done.call(&"restore_power")])
	var vault := [lobby, ["archive gate (west)", "go", [G2_WEST], done.call(&"open_vault")],
		["vault code", "code", [n.call(M + "VaultKeypad"), VAULT_CODE, AT_KEYPAD], done.call(&"open_vault")],
		["manuscript", "use", [n.call("Gameplay/RareManuscript"), IN_VAULT, 1], done.call(&"take_manuscript")]]
	var locker := [["rota", "use", [n.call(DOC + "NightRota"), AT_ROTA, 1], has_doc.call(&"night_rota")],
		["locker code", "code", [n.call(M + "SecurityLocker"), LOCKER_CODE, AT_LOCKER], done.call(&"security_locker")],
		["badge", "use", [n.call("Expansion/Gameplay/Items/LockerBadge"), AT_BADGE, 1], func(): return inv.has(ItemCatalog.SECURITY_BADGE)]]
	var pump_steps := [["pump log", "use", [n.call(DOC + "PumpRoomLog"), AT_PUMP_LOG, 1], has_doc.call(&"pump_room_log")],
		["pump crank", "use", [n.call(M + "PumpCrank"), AT_PUMP + Vector3(-3.4, 0, 0), 1], func(): return obj.is_completed(&"drain_culvert") or (n.call(M + "PumpCrank") as ToolMechanism).is_operated]]
	for i in 3:
		var want: bool = pump.solution[i]
		pump_steps.append(["valve %d" % (i + 1), "use", [pump.valves[i], AT_PUMP + Vector3(pump.valves[i].global_position.x, 0, 0), 1],
			func(): return obj.is_completed(&"drain_culvert") or (pump.valves[i].index == 1) == want])
	pump_steps.append(["pump start", "use", [pump.start_lever, AT_PUMP + Vector3(pump.start_lever.global_position.x, 0, 0), 1], done.call(&"drain_culvert")])
	var main_exit := [lobby, ["badge reader", "override", [n.call(ESC + "BadgeReader"), AT_READER], func(): return (n.call(ESC + "MainEntranceExit") as ExitDoor).unlocked],
		["main entrance", "exit", [Vector3(0, 0, 26.8), Vector3(0, 0, 31.0)], null]]
	var steps := [lobby, ["plaque", "use", [n.call(DOC + "LobbyPlaque"), AT_PLAQUE, 1], has_doc.call(&"lobby_plaque")]]
	match _route:
		"dock":
			steps += toolkit + power
			steps += [["service switch", "use", [n.call("Expansion/Gameplay/Security/ServiceExitSwitch"), AT_SERVICE, 1], func(): return _power().is_powered(&"service_exit")],
				["shutter release", "use", [n.call(ESC + "DockShutterRelease"), AT_RELEASE, 1], func(): return (n.call(ESC + "DockShutterRelease") as ToolMechanism).is_operated],
				["shutter control", "use", [(n.call(ESC + "DockShutterControl") as DockShutter).button, AT_CONTROL, 1], func(): return (n.call("Gameplay/ExitDoor") as ExitDoor).unlocked]]
			steps += card + vault
			steps += [lobby, ["loading dock", "exit", [Vector3(34.6, 0, 24), Vector3(39, 0, 24)], null]]
		"main":
			steps += locker + card + toolkit + power + vault + main_exit
		"passage":
			steps += card + toolkit + pump_steps + power + vault
			steps += [["culvert plan", "use", [n.call(DOC + "CulvertAccessPlan"), AT_PLAN, 1], has_doc.call(&"culvert_access_plan")],
				["hidden panel", "use", [n.call("Expansion/Gameplay/MaintenancePanel"), AT_HIDDEN_PANEL, 1], func(): return (n.call("Expansion/Gameplay/MaintenancePanel") as AccessDoor).is_open],
				["storm drain", "exit", [Vector3(0, B, -34.6), Vector3(0, B, -39.5)], null]]
		"full":
			steps += locker + card + toolkit + pump_steps + power + vault
			steps += [["back gate", "use", [n.call("Gameplay/ArchiveBackGateG3"), AT_G3, 1], done.call(&"unlock_shortcut")],
				["staff stair", "go", [Vector3(34.35, 0, 5.5)], null]]
			steps += main_exit
	return steps


## Runs the script from the top, skipping what is done, until a step fails
## (caught, or it did not work): then waits for the reset and returns.
func _run_script(steps: Array) -> void:
	var catches := _director.catches
	for st in steps:
		if _objectives.is_finished() or _abort or _director.catches != catches:
			break
		if st[3] != null and (st[3] as Callable).call():
			continue
		_step_label = st[0]
		var ok := true
		var args: Array = st[2]
		match st[1]:
			"go":
				ok = await _go(args[0])
			"use":
				for k in args[2]:
					ok = ok and await _use(args[1], args[0])
				_close_journal()
			"code":
				ok = await _code(args[0], args[1], args[2])
			"override":
				ok = await _override(args[0], args[1])
			"exit":
				ok = await _exit(args[0], args[1])
		if ok:
			_last_progress_t = _t
		if ok and st[3] != null and not (st[3] as Callable).call() and st[1] != "go":
			_event("step '%s' did not take effect" % st[0])
			ok = false
		if not ok:
			break
	await _wait_reset()


func _code(lock: CodeLock, code: String, stand: Vector3) -> bool:
	if lock.lockout_left > 0.0:
		return false
	for i in code.length():
		var dial := lock.dials[i]
		var turns := (int(code[i]) - dial.index + 10) % 10
		for k in turns:
			if not await _use(stand, dial):
				return false
	return await _use(stand, lock.enter)


## Starts the badge reader's override and stays until it completes.
func _override(reader: BadgeReader, stand: Vector3) -> bool:
	if not await _use(stand, reader):
		return false
	var catches := _director.catches
	var started := _t
	while reader.overriding and _t - started < reader.hold_time + 2.0:
		if _director.catches != catches:
			return false
		_stop(false)
		await _tick()
	return true


## Walks out through an exit's trigger.
func _exit(from: Vector3, toward: Vector3) -> bool:
	if not await _go(from):
		return false
	var to := toward - _player.global_position
	_player.rotation.y = atan2(-to.x, -to.z)
	_player.head.rotation.x = 0.0
	Input.action_press("move_forward")
	var started := _t
	while _t - started < 2.5 and _director.status != S.ESCAPED:
		await _tick()
	_release()
	return _director.status == S.ESCAPED


func _close_journal() -> void:
	var hud := _level.get_node_or_null("ObjectiveHud")
	if hud and hud.has_method("close_journal"):
		hud.close_journal()


func _power() -> PowerNetwork:
	return PowerNetwork.find(_level)


## The closed, discovered door within 1.6 m that the path goes through next.
func _closed_door_ahead(here: Vector3, path: PackedVector3Array, index: int) -> AccessDoor:
	for door in _doors:
		if door.is_open or not door.is_discovered() or not door.is_inside_tree():
			continue
		var d := door.global_position
		if Vector2(here.x - d.x, here.z - d.z).length() > 1.6 or absf(here.y - d.y) > 1.5:
			continue
		var prev := here
		for k in range(index, mini(index + 3, path.size())):
			if Geometry2D.get_closest_point_to_segment(Vector2(d.x, d.z), Vector2(prev.x, prev.z), Vector2(path[k].x, path[k].z)).distance_to(Vector2(d.x, d.z)) < 1.0:
				return door
			prev = path[k]
	return null


# --- Steps ----------------------------------------------------------------------------------

## Walks to `target` along the navmesh with the profile's stealth rules. False if caught.
func _go(target: Vector3) -> bool:
	var catches := _director.catches
	var path := _plan_path(_player.global_position, target)
	if path.is_empty():
		_event("no path to %s" % _v(target))
		return false
	var index := 0
	var unstuck := 0
	var waited := 0.0
	var safe_for := 0.0
	var anchor := _player.global_position
	var anchor_t := _t
	var last := _player.global_position
	while not _abort:
		await _tick()
		if _director.catches != catches or _director.status == S.CAUGHT:
			_release()
			return false
		var here := _player.global_position
		_log.walked_m += here.distance_to(last)
		last = here
		if Vector2(target.x - here.x, target.z - here.z).length() < 0.45 and absf(target.y - here.y) < 0.9:
			_release()
			return true
		while index < path.size() - 1 and Vector2(path[index].x - here.x, path[index].z - here.z).length() < 0.5:
			index += 1
		# A closed door in the way: E on it (a refusal ends the walk).
		var door := _closed_door_ahead(here, path, index)
		if door:
			_release()
			_look_at(door.global_position + Vector3(0, 1.0, 0))
			for i in 3:
				await _tick()
			if _interactor.focused == door:
				_interactor.try_interact()
				for i in 3:
					await _tick()
			if not door.is_open:
				_event("%s refused near %s: walking around it" % [door.door_name, _v(here)])
				_blocked_doors[Vector3(door.global_position.x, here.y, door.global_position.z)] = door
				return false
			path = _plan_path(_player.global_position, target)
			index = 0
			continue
		# Stealth decisions.
		var noticed := _being_noticed()
		var ahead := _point_ahead(path, index, here, 2.5)
		var danger_here := _danger(here)
		var danger_ahead := _danger(ahead)
		if _director.status == S.CHASE:
			await _flee(catches)
			if _director.catches != catches:
				return false
			path = _plan_path(_player.global_position, target)
			index = 0
			continue
		if _profile == "careful" and (noticed or danger_here):
			await _retreat(catches)
			if _director.catches != catches:
				return false
			path = _plan_path(_player.global_position, target)
			index = 0
			waited = 0.0
			continue
		if _profile in ["hasty", "learner"] and noticed:
			await _retreat(catches)
			if _director.catches != catches:
				return false
			path = _plan_path(_player.global_position, target)
			index = 0
			continue
		if _profile == "careful" and danger_ahead and waited < WAIT_LIMIT:
			_stop(true)
			waited += _dt()
			_log.wait_s += _dt()
			safe_for = 0.0
			anchor_t = _t
			continue
		if _profile == "careful" and waited > 0.0 and waited < WAIT_LIMIT:
			# Wait for the way to stay clear for a moment before going.
			safe_for += _dt()
			if safe_for < 0.6:
				_stop(true)
				waited += _dt()
				_log.wait_s += _dt()
				anchor_t = _t
				continue
		if waited >= WAIT_LIMIT:
			_log.forced += 1
			_event("forced move near %s" % _v(here))
			waited = 0.0
		waited = 0.0 if not danger_ahead else waited
		if not danger_here:
			if _safe_trail.is_empty() or _safe_trail[-1].distance_to(here) > 1.0:
				_safe_trail.append(here)
				if _safe_trail.size() > 60:
					_safe_trail.pop_front()
		# Move.
		var near_guard := _nearest_known_guard() < 12.0
		var sprint := _profile in ["hasty", "reckless", "learner"] and not near_guard
		_move_toward(path[index], _profile == "careful" and near_guard, sprint)
		if _t - anchor_t > 2.0:
			if here.distance_to(anchor) < 0.3:
				# Stuck on a corner: back off, step aside, plan again (a player would too).
				unstuck += 1
				_event("stuck at %s (try %d)" % [_v(here), unstuck])
				if unstuck > 4:
					_release()
					return false
				await _sidestep(unstuck)
				path = _plan_path(_player.global_position, target)
				index = 0
			anchor = _player.global_position
			anchor_t = _t
	return false


## A path to `target`. After two or more captures near the same spot, a
## player avoids it: if the direct path passes such a spot, the shortest path
## through one or two waypoints (stair ends, room centres) that avoids every
## such spot is used instead (worked out once per target and capture count).
func _plan_path(from: Vector3, target: Vector3, doors_only := false) -> PackedVector3Array:
	var direct := NavigationServer3D.map_get_path(_map, from, target, true)
	var hot := _hot_spots()
	if doors_only:
		hot = hot.filter(func(h): return _blocked_doors.has(h))
	if hot.is_empty() or not _passes(direct, hot):
		return direct
	var key := "%s|%d|%d|%s" % [_v(target), _catch_spots.size(), _blocked_doors.size(), doors_only]
	if _detours.has(key):
		var vias: Array = _detours[key]
		if vias.is_empty():
			return direct
		var path := PackedVector3Array()
		var at := from
		for v in vias + [target]:
			var leg := NavigationServer3D.map_get_path(_map, at, v, true)
			path += leg if path.is_empty() else leg.slice(1)
			at = v
		return path
	var points := _detour_points()
	var best: Array = []
	var best_len := INF
	var clear := {}   # point index -> path from `from` avoids the hot spots
	for i in points.size():
		var a := NavigationServer3D.map_get_path(_map, from, points[i], true)
		if a.is_empty() or _passes(a, hot):
			continue
		clear[i] = _path_length(a)
		var b := NavigationServer3D.map_get_path(_map, points[i], target, true)
		if not b.is_empty() and not _passes(b, hot) and clear[i] + _path_length(b) < best_len:
			best_len = clear[i] + _path_length(b)
			best = [points[i]]
	if best.is_empty():
		for i in clear:
			for j in points.size():
				if j == i:
					continue
				var mid := NavigationServer3D.map_get_path(_map, points[i], points[j], true)
				if mid.is_empty() or _passes(mid, hot):
					continue
				var b := NavigationServer3D.map_get_path(_map, points[j], target, true)
				if b.is_empty() or _passes(b, hot):
					continue
				var l: float = clear[i] + _path_length(mid) + _path_length(b)
				if l < best_len:
					best_len = l
					best = [points[i], points[j]]
	_detours[key] = best
	if best.is_empty():
		_event("no detour avoids the %d spot(s)%s" % [hot.size(), " (locked doors only)" if doors_only else ""])
		# A locked door cannot be walked through; capture spots are only avoided if possible.
		if not doors_only and hot.any(func(h): return _blocked_doors.has(h)):
			return _plan_path(from, target, true)
		return direct
	_event("detour via %s avoiding %d capture spot(s)" % [", ".join(best.map(func(p): return _v(p))), hot.size()])
	return _plan_path(from, target, doors_only)


func _hot_spots() -> Array[Vector3]:
	var hot: Array[Vector3] = []
	# Doors that refused the player (a staff door without the card): walk around.
	for d in _blocked_doors.keys():
		if not (_blocked_doors[d] as AccessDoor).is_open and (_blocked_doors[d] as AccessDoor)._refusal(_player) != "":
			hot.append(d)
	for p in _catch_spots:
		var n := 0
		for q in _catch_spots:
			if p.distance_to(q) < HOT_RADIUS:
				n += 1
		if n >= 2 and not hot.any(func(h): return h.distance_to(p) < HOT_RADIUS):
			hot.append(p)
	return hot


func _passes(path: PackedVector3Array, hot: Array[Vector3]) -> bool:
	for i in range(1, path.size()):
		for h in hot:
			var r := 1.2 if _blocked_doors.has(h) else HOT_RADIUS
			var c := Geometry3D.get_closest_point_to_segment(h, path[i - 1], path[i])
			if c.distance_to(h) < r:
				return true
	return false


func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


## The ends of every stair (the existing S1–S3 and the expansion's service
## stairs) and the centre of every area.
func _detour_points() -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for z in Layout.ZONES:
		for a in z.areas:
			var y := U if z.floor == "upper" else 0.0
			pts.append(NavigationServer3D.map_get_closest_point(_map, Vector3((a.rect[0] + a.rect[2]) / 2.0, y, (a.rect[1] + a.rect[3]) / 2.0)))
	for st in Layout.STAIRS:
		for e in Layout.stair_ends(st):
			pts.append(NavigationServer3D.map_get_closest_point(_map, e))
	for r in [[-42.2, -12.0, -22.0], [44.2, -18.0, -8.0]]:
		var dir := signf(r[2] - r[1])
		pts.append(NavigationServer3D.map_get_closest_point(_map, Vector3(r[0], 0, r[1] - dir * 1.5)))
		pts.append(NavigationServer3D.map_get_closest_point(_map, Vector3(r[0], B, r[2] + dir * 1.5)))
	return pts


## Backs off and steps sideways for a moment (alternating sides).
func _sidestep(n: int) -> void:
	Input.action_release("move_forward")
	Input.action_press("move_backward")
	for i in int(0.4 / _dt()):
		await _tick()
	Input.action_release("move_backward")
	var side := "move_left" if n % 2 == 1 else "move_right"
	Input.action_press(side)
	for i in int(0.5 / _dt()):
		await _tick()
	Input.action_release(side)


## Goes to `stand`, looks at `node` and presses the interact key. False if caught or it didn't work.
func _use(stand: Vector3, node: Node3D) -> bool:
	if not await _go(stand):
		return false
	for attempt in 4:
		_look_at(node.global_position)
		for i in 4:
			await _tick()
		if _interactor.focused == node:
			var before := _objectives.completed_count()
			var opened = node.get("is_open")
			if _interactor.try_interact():
				for i in 3:
					await _tick()
				return true
			if opened != node.get("is_open") or _objectives.completed_count() != before:
				return true
		# Not focused: shuffle a little closer.
		var to: Vector3 = node.global_position - _player.global_position
		to.y = 0
		_player.global_position += to.normalized() * 0.2
	_event("could not use %s from %s" % [node.name, _v(_player.global_position)])
	return false


## Backs off along the safe trail, crouched, until no guard notices the player.
func _retreat(catches: int) -> void:
	_event("retreat at %s" % _v(_player.global_position))
	var started := _t
	while _t - started < 20.0 and not _abort:
		if _director.catches != catches or _director.status == S.CAUGHT:
			_release()
			return
		if _director.status == S.CHASE:
			await _flee(catches)
			return
		var here := _player.global_position
		var target := here
		for k in range(_safe_trail.size() - 1, -1, -1):
			if _safe_trail[k].distance_to(here) > 2.0 and not _danger(_safe_trail[k]):
				target = _safe_trail[k]
				break
		if not _being_noticed() and not _danger(here):
			_stop(true)
			await _tick()
			_log.wait_s += _dt()
			if _t - started > 2.0:
				_release()
				return
			continue
		var path := NavigationServer3D.map_get_path(_map, here, target, true)
		if path.size() >= 2:
			_move_toward(path[1], true, false)
		await _tick()
	_release()


## Runs back along the trail (sprinting) to break line of sight during a chase.
func _flee(catches: int) -> void:
	_event("flee at %s" % _v(_player.global_position))
	var k := _safe_trail.size() - 1
	while _director.status == S.CHASE and _director.catches == catches and not _abort:
		var here := _player.global_position
		while k > 0 and _safe_trail[k].distance_to(here) < 1.0:
			k -= 1
		var path := NavigationServer3D.map_get_path(_map, here, _safe_trail[maxi(k, 0)], true)
		if path.size() >= 2:
			_move_toward(path[1], false, true)
		else:
			_stop(false)
		await _tick()
	_release()


func _wait_reset() -> void:
	_release()
	var caught := _director.status == S.CAUGHT
	while _director.status == S.CAUGHT:
		await _tick()
	for i in 5:
		await _tick()
	if caught:
		_check_state()
		if _profile == "learner" and _director.catches >= 2:
			_profile = "careful"
			_event("learner switches to careful play")
		_safe_trail = [_player.global_position]
		_seen.clear()
		_respawned = true


## After a capture: objectives and mission state as the checkpoint stored them.
func _check_state() -> void:
	var problems := []
	var cm: CheckpointManager = _level.get_node("Gameplay/CheckpointManager")
	if _objectives.get_progress() != cm.saved_progress:
		problems.append("objectives differ from the checkpoint's")
	var state := cm.get_mission_state()
	for key in cm.saved_state:
		if state.get(key) != cm.saved_state[key]:
			problems.append("%s differs" % key)
	_log["state_checks"] = _log.get("state_checks", 0) + 1
	if not problems.is_empty():
		_log["state_violations"] = _log.get("state_violations", 0) + 1
		_event("STATE VIOLATION after capture: %s" % ", ".join(problems))


# --- Perception (what the player can know) ---------------------------------------------------

func _tick() -> void:
	await physics_frame
	_t += _dt()
	if _t - _last_progress_t > STALL_LIMIT or _t > MAX_GAME_TIME:
		_abort = true
	if _verbose and int(_t / 20.0) != int((_t - _dt()) / 20.0):
		print("  t=%s at %s objective=%s status=%s catches=%d crouch=%s" % [_clock(_t), _v(_player.global_position),
			_objectives.current(), S.keys()[_director.status], _director.catches, _player.is_crouching])
	var eye := _player.camera.global_position
	for g in _guards:
		var chest := g.global_position + Vector3(0, 1.2, 0)
		if eye.distance_to(chest) > SIGHT_RANGE:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, chest, 1)
		if _space.intersect_ray(q).is_empty():
			var prev: Dictionary = _seen.get(g, {})
			var vel := Vector3.ZERO
			if not prev.is_empty() and _t - prev.t > 0.0 and _t - prev.t < 0.5:
				vel = (g.global_position - prev.at) / (_t - prev.t)
			_seen[g] = {"at": g.global_position, "forward": -g.global_basis.z, "t": _t, "vel": vel}
	# The detection UI.
	var status := _director.status
	if status != _status_prev:
		match status:
			S.SPOTTED:
				_log.noticed += 1
			S.INVESTIGATING:
				_log.investigated += 1
			S.CHASE:
				_log.chased += 1
		_status_prev = status


## Is a guard noticing the player right now (the HUD's "being seen" / chase)?
func _being_noticed() -> bool:
	return _director.status in [S.SPOTTED, S.CHASE]


## Would a guard the player knows about see a player standing (or crouched) at `p`, now or in 1.5 s?
func _danger(p: Vector3) -> bool:
	var head := p + Vector3(0, 1.0 if _player.is_crouching else 1.5, 0)
	for g in _seen:
		var s: Dictionary = _seen[g]
		if _t - s.t > MEMORY:
			continue
		for ahead in [0.0, 1.5]:
			var at: Vector3 = s.at + s.vel * ahead
			var eye := at + Vector3(0, 1.6, 0)
			var to := head - eye
			var dist := to.length()
			if dist > 16.0:
				continue
			var forward: Vector3 = s.forward if s.vel.length() < 0.2 or ahead == 0.0 else s.vel.normalized()
			var angle := rad_to_deg(Vector3(forward.x, 0, forward.z).angle_to(Vector3(to.x, 0, to.z)))
			if angle > 60.0 and dist > 2.5:
				continue
			if _space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, head, 1)).is_empty():
				return true
	return false


func _nearest_known_guard() -> float:
	var best := INF
	for g in _seen:
		if _t - _seen[g].t <= MEMORY:
			best = minf(best, _seen[g].at.distance_to(_player.global_position))
	return best


func _sees_item(item: Node3D) -> bool:
	if not item.visible:
		return true
	var eye := _player.camera.global_position
	if eye.distance_to(item.global_position) > 9.0:
		return false
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, item.global_position, 1)).is_empty()


# --- Control ----------------------------------------------------------------------------------

func _move_toward(p: Vector3, crouch: bool, sprint: bool) -> void:
	var here := _player.global_position
	var to := p - here
	_player.rotation.y = atan2(-to.x, -to.z)
	_player.head.rotation.x = 0.0
	Input.action_press("move_forward")
	_set_action("crouch", crouch)
	_set_action("sprint", sprint and not crouch)


func _stop(crouch: bool) -> void:
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_set_action("crouch", crouch)


func _release() -> void:
	for a in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "crouch"]:
		Input.action_release(a)


func _set_action(a: String, on: bool) -> void:
	if on:
		Input.action_press(a)
	else:
		Input.action_release(a)


func _look_at(target: Vector3) -> void:
	var at := _player.global_position
	_player.rotation.y = atan2(-(target.x - at.x), -(target.z - at.z))
	var eye := at.y + _player.stand_eye_height
	_player.head.rotation.x = atan2(target.y - eye, Vector2(target.x - at.x, target.z - at.z).length())


func _point_ahead(path: PackedVector3Array, index: int, here: Vector3, dist: float) -> Vector3:
	var left := dist
	var from := here
	for k in range(index, path.size()):
		var seg := path[k].distance_to(from)
		if seg >= left:
			return from.lerp(path[k], left / maxf(seg, 0.001))
		left -= seg
		from = path[k]
	return path[path.size() - 1]


# --- Helpers ----------------------------------------------------------------------------------

func _dt() -> float:
	return Engine.time_scale / Engine.physics_ticks_per_second


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


func _event(text: String) -> void:
	_log.events.append("%s %s" % [_clock(_t), text])
	if _verbose:
		print("    %s %s" % [_clock(_t), text])


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
