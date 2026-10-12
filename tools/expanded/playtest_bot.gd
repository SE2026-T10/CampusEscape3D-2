extends SceneTree

## Development tool: an automated playtester for the Expanded Library mission.
## It plays the real level, with the real guards, through the real player
## (input actions: move, crouch, sprint; the interact key through the
## PlayerInteractor), and records what happened.
##
##   godot --headless --path . --script res://tools/expanded/playtest_bot.gd -- \
##       --route=main --profile=careful --explore --seed=1 --runs=1 --scale=3 --out=docs/expanded/v3/playtests
##
## What the bot knows (what a player can know):
##   - the objective panel (the current objective) and its hint;
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
##   reckless ignores the guards until one chases it (then runs): a first-timer
##            who hasn't understood the stealth rules yet;
##   learner  plays hasty until it has been caught twice, then careful (a
##            first-timer who learns from being caught).
## After every capture the bot also checks the mission state the checkpoint
## restored (items shown exactly while their objective is open, card doors open
## only with the card, back gate and its objective agree, one objective active)
## and counts violations: repeated captures must never corrupt the state.
## --explore: a first-time player who doesn't know where things are. For each
## objective it searches the places the objective's hint points to, in a
## seeded order, until it sees the item. Without it, the bot goes straight
## to each objective (a player who knows the map).
## Routes: main (S1, staff wing door), stacks (S3, stacks staff door), early_gate
## (main, opening the back gate before taking the manuscript).
##
## Each run appends one JSON line to <out>/runs.jsonl and prints a summary:
## completion time (game time), captures (where, by whom, at which objective),
## times noticed / investigated / chased, time spent waiting, forced moves
## (waited too long and went anyway), stalls (no progress for 8 min = softlock).

const Layout := preload("res://tools/expanded/expanded_layout.gd")
const SCENE := "res://scenes/level/expanded_library.tscn"
const U := Layout.UPPER_Y
const S := StealthDirector.Status
const SIGHT_RANGE := 30.0
const MEMORY := 2.0
const WAIT_LIMIT := 45.0
const STALL_LIMIT := 480.0
const MAX_GAME_TIME := 2700.0

# Where things are (stand points on the floor), from the layout data.
var AT_CARD: Vector3 = Layout.OBJECTIVES[1].pos
var AT_ITEM: Vector3 = Layout.OBJECTIVES[2].pos
var AT_G3: Vector3 = Layout.OBJECTIVES[3].pos
var AT_EXIT := Vector3(34.3, 0, 24)

var _route := "main"
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
	_director.player_caught.connect(func(by: Guard):
		_event("CAUGHT by %s" % by.name)
		_log.captures.append({"t": snappedf(_t, 0.1), "objective": String(_objectives.current()), "guard": String(by.name),
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
	while not _objectives.is_finished() and _t < MAX_GAME_TIME and not _abort:
		await _do_objective()
	if _abort:
		_log.stalled = true
		_event("stalled at %s, objective %s" % [_v(_player.global_position), _objectives.current()])
	_release()
	Engine.time_scale = 1.0
	_log.completed = _objectives.is_finished()
	_log.time_s = snappedf(_t, 0.1)
	_log.walked_m = snappedf(_log.walked_m, 1.0)
	_log.wait_s = snappedf(_log.wait_s, 0.1)
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


## Plays the current objective until it changes (or the player is caught).
func _do_objective() -> void:
	var id := _objectives.current()
	var catches := _director.catches
	var plan := _plan(id)
	for step in plan:
		if _objectives.current() != id or _director.catches != catches or _abort:
			return
		var ok := true
		match step[0]:
			"go":
				ok = await _go(step[1])
			"search":
				ok = await _search(id, step[1], step[2])
			"use":
				ok = await _use(step[1], step[2])
		if not ok:
			break
	# Caught, or the step failed: wait for the reset, then plan again.
	await _wait_reset()


## The steps for objective `id`, skipping the leading waypoints a direct path makes unnecessary.
func _plan(id: StringName) -> Array:
	var card: Node3D = _level.get_node("Gameplay/StaffAccessCard")
	var item: Node3D = _level.get_node("Gameplay/RareManuscript")
	var g2: Node3D = _level.get_node("Gameplay/ArchiveFrontGateG2")
	var g3: Node3D = _level.get_node("Gameplay/ArchiveBackGateG3")
	var exit: Node3D = _level.get_node("Gameplay/ExitDoor")
	var upstairs: Array = [Vector3(-10.35, 0, 21.5), Vector3(-10.35, U, 8), Vector3(2, U, -2), Vector3(3, U, -8), Vector3(3, U, -11)]
	if _route == "stacks":
		upstairs = [Vector3(-12, 0, 24), Vector3(-20, 0, 19), Vector3(-34.35, 0, 21.5), Vector3(-34.35, U, 8),
			Vector3(-33.5, U, 5), Vector3(-13, U, 5), Vector3(-13, U, -10), Vector3(-6, U, -11), Vector3(0, U, -11)]
	var steps := []
	match id:
		&"enter_library":
			steps = [["go", Vector3(0, 0, 20)]]
		&"take_card":
			for p in upstairs:
				steps.append(["go", p])
			if _explore:
				var rooms := [Vector3(-3, U, -17), Vector3(9, U, -17), Vector3(3, U, -17)]
				_shuffle(rooms)
				steps.append(["search", rooms, card])
			steps.append(["use", AT_CARD, card])
		&"take_manuscript":
			steps.append(["go", Vector3(3, U, -11)])
			steps.append(["go", Vector3(10.6, U, -11)])
			if g2.get("is_open") == false:
				steps.append(["use", Vector3(10.6, U, -11), g2])
			if _route == "early_gate" and g3.get("is_open") == false:
				steps.append(["go", Vector3(26.5, U, -11)])
				steps.append(["use", AT_G3, g3])
			if _explore:
				var places := [Vector3(16, U, -21.5), Vector3(23, U, -17.5), Vector3(30, U, -21)]
				steps.append(["search", places, item])
			steps.append(["go", Vector3(26.5, U, -21)])
			steps.append(["use", AT_ITEM, item])
		&"unlock_shortcut":
			steps.append(["go", Vector3(26.5, U, -21)])
			steps.append(["go", Vector3(26.5, U, -9)])
			steps.append(["use", AT_G3, g3])
		&"escape":
			steps = [["go", Vector3(31.4, U, -9)], ["go", Vector3(34.35, U, -8.5)], ["go", Vector3(34.35, 0, 5.5)],
				["go", Vector3(29, 0, 10)], ["go", Vector3(22, 0, 12)], ["go", Vector3(27, 0, 20)], ["use", AT_EXIT, exit]]
	# After a respawn the player may be part-way along (a checkpoint): skip what is behind.
	return _trim(steps) if _respawned else steps


## Drops leading "go" steps when walking straight to a later step is no longer than following them.
func _trim(steps: Array) -> Array:
	var here := _player.global_position
	var best := 0
	var best_cost := INF
	for i in steps.size():
		var cost := _len(here, _target(steps[i])) + _plan_len(steps, i)
		if cost < best_cost - 0.5:
			best_cost = cost
			best = i
		if steps[i][0] != "go":
			break   # never skip a search or a use
	return steps.slice(best)


func _target(step: Array) -> Vector3:
	return step[1] if step[0] != "search" else step[1][0]


func _plan_len(steps: Array, from: int) -> float:
	var total := 0.0
	for k in range(from, steps.size() - 1):
		total += _len(_target(steps[k]), _target(steps[k + 1]))
	return total


func _len(a: Vector3, b: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(_map, a, b, true)
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total if not path.is_empty() else INF


# --- Steps ----------------------------------------------------------------------------------

## Walks to `target` along the navmesh with the profile's stealth rules. False if caught.
func _go(target: Vector3) -> bool:
	var catches := _director.catches
	var path := NavigationServer3D.map_get_path(_map, _player.global_position, target, true)
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
		# Stealth decisions.
		var noticed := _being_noticed()
		var ahead := _point_ahead(path, index, here, 2.5)
		var danger_here := _danger(here)
		var danger_ahead := _danger(ahead)
		if _director.status == S.CHASE:
			await _flee(catches)
			if _director.catches != catches:
				return false
			path = NavigationServer3D.map_get_path(_map, _player.global_position, target, true)
			index = 0
			continue
		if _profile == "careful" and (noticed or danger_here):
			await _retreat(catches)
			if _director.catches != catches:
				return false
			path = NavigationServer3D.map_get_path(_map, _player.global_position, target, true)
			index = 0
			waited = 0.0
			continue
		if _profile in ["hasty", "learner"] and noticed:
			await _retreat(catches)
			if _director.catches != catches:
				return false
			path = NavigationServer3D.map_get_path(_map, _player.global_position, target, true)
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
				path = NavigationServer3D.map_get_path(_map, _player.global_position, target, true)
				index = 0
			anchor = _player.global_position
			anchor_t = _t
	return false


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


## Visits `places` (the hint's candidate rooms) until `item` is seen, then returns.
func _search(id: StringName, places: Array, item: Node3D) -> bool:
	for p in places:
		if _sees_item(item):
			return true
		if not await _go(p):
			return false
		# Look around the room.
		for k in 8:
			_player.rotation.y += TAU / 8.0
			await _tick()
			if _sees_item(item):
				return true
	return true


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


## The invariants a checkpoint restore must keep (as in tests/expanded_mission_tests.gd).
func _check_state() -> void:
	var problems := []
	var active := 0
	for id in _objectives.get_ids():
		if _objectives.get_state(id) == ObjectiveManager.State.ACTIVE:
			active += 1
	if active != 1:
		problems.append("%d active objectives" % active)
	for item_name in ["StaffAccessCard", "RareManuscript"]:
		var item: AccessCard = _level.get_node("Gameplay/" + item_name)
		if item.visible == _objectives.is_completed(item.objective_id):
			problems.append("%s shown=%s but objective done=%s" % [item_name, item.visible, _objectives.is_completed(item.objective_id)])
	for door_name in ["ArchiveFrontGateG2", "LobbyStaffDoorG4"]:
		var door: AccessDoor = _level.get_node("Gameplay/" + door_name)
		if door.is_open and not _objectives.is_completed(door.key_objective_id):
			problems.append("%s open without the card" % door_name)
	var g3: AccessDoor = _level.get_node("Gameplay/ArchiveBackGateG3")
	if _objectives.is_completed(&"unlock_shortcut") != g3.is_open and not (g3.is_open and _objectives.get_state(&"unlock_shortcut") == ObjectiveManager.State.LOCKED):
		problems.append("back gate open=%s, objective %s" % [g3.is_open, _objectives.get_state(&"unlock_shortcut")])
	if _objectives.get_progress() != _level.get_node("Gameplay/CheckpointManager").saved_progress:
		problems.append("progress differs from the checkpoint's")
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
