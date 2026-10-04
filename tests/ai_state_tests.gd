extends RefCounted

## Phase 6 unit tests for GuardStateMachine. Pure logic: a fake actor and a
## fake route stand in for the guard, so no physics or scene is involved.
## Each mandatory test case has a function named after it.

var failures: Array[String] = []


func run(_host: Node) -> Array[String]:
	test_exactly_three_primary_states()
	test_initial_state_is_patrol()
	test_patrol_to_investigate()
	test_patrol_to_chase()
	test_noise_triggers_investigate()
	test_investigate_to_chase()
	test_investigate_to_patrol_after_timeout()
	test_investigate_moves_to_new_evidence()
	test_chase_to_investigate_after_losing_player()
	test_chase_follows_only_perception()
	test_confirmed_sighting_beats_noise()
	test_invalid_transitions_are_rejected()
	test_enter_exit_order_and_arguments()
	test_patrol_resumes_where_it_left_off()
	test_repeated_requests_do_not_corrupt()
	test_random_request_storm_keeps_invariants()
	test_no_shared_state_between_machines()
	print("  [ai] state machine unit tests: %d failure(s)" % failures.size())
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[ai] " + message)


# --- Test doubles ---------------------------------------------------------------

class FakeRoute:
	var points: Array[Vector3] = [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 10)]
	var loop := true
	func get_point_count() -> int: return points.size()
	func get_point_position(i: int) -> Vector3: return points[i]
	func get_wait_time(_i: int, fallback: float) -> float: return fallback
	func next_index(i: int) -> int:
		if i + 1 < points.size(): return i + 1
		return 0 if loop else -1


class FakeActor:
	var global_position := Vector3.ZERO
	var patrol_speed := 2.0
	var investigate_speed := 2.6
	var chase_speed := 4.2
	var default_wait_time := 1.0
	var investigate_search_duration := 3.0
	var chase_lose_sight_time := 2.0
	var patrol_route = FakeRoute.new()
	# What the states did:
	var nav_target := Vector3.INF
	var nav_speed := 0.0
	var nav_calls: Array[Vector3] = []
	var stops := 0
	var arrived := false
	var stuck := false
	var yaw := 0.0
	var forgets := 0
	var reached: Array[int] = []
	func navigate_to(p: Vector3, speed: float) -> void:
		nav_target = p
		nav_speed = speed
		nav_calls.append(p)
		arrived = false
	func stop_moving() -> void: stops += 1
	func has_arrived() -> bool: return arrived
	func is_stuck() -> bool: return stuck
	func face_yaw(y: float) -> void: yaw = y
	func get_yaw() -> float: return yaw
	func forget_suspicion() -> void: forgets += 1
	func notify_patrol_point_reached(i: int) -> void: reached.append(i)
	func notify_patrol_wait(_waiting: bool, _i: int) -> void: pass
	func notify_stuck(_i: int) -> void: pass


## A state that misbehaves by requesting transitions from enter() and exit().
class MeddlingPatrol extends PatrolState:
	var enter_result := true
	func enter(actor, previous: int, position: Vector3) -> void:
		super.enter(actor, previous, position)
		enter_result = machine.request_transition(GuardStateMachine.CHASE, "from enter")


const SIGHT := Vector3(4, 0, 6)
const NOISE := Vector3(-8, 0, 2)


func _machine(actor := FakeActor.new()) -> GuardStateMachine:
	var m := GuardStateMachine.new(actor)
	m.warn_on_reject = false
	m.start()
	return m


func _nothing() -> GuardPerception:
	return GuardPerception.new()


func _suspicious(at := SIGHT) -> GuardPerception:
	return GuardPerception.make(false, false, true, at)


func _confirmed(at := SIGHT) -> GuardPerception:
	return GuardPerception.make(true, true, true, at)


func _noise(at := NOISE) -> GuardPerception:
	return GuardPerception.make(false, false, false, Vector3.ZERO, true, at)


func _tick_for(m: GuardStateMachine, perception: GuardPerception, seconds: float, step := 0.1) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		m.tick(perception, step)
		t += step


# --- Tests ------------------------------------------------------------------------

func test_exactly_three_primary_states() -> void:
	_expect(GuardStateMachine.NAMES == ["PATROL", "INVESTIGATE", "CHASE"], "There must be exactly PATROL, INVESTIGATE and CHASE.")
	_expect(GuardStateMachine.ALLOWED.size() == 3, "Every primary state needs an entry in ALLOWED.")
	_expect(not GuardStateMachine.is_valid_state(3) and not GuardStateMachine.is_valid_state(-1), "Ids outside the three states must be invalid.")


func test_initial_state_is_patrol() -> void:
	var actor := FakeActor.new()
	var m := GuardStateMachine.new(actor)
	m.warn_on_reject = false
	_expect(m.current == GuardStateMachine.NONE, "Before start() there should be no state.")
	_expect(not m.request_transition(GuardStateMachine.CHASE), "Requests before start() must be rejected.")
	var entered: Array[int] = []
	m.state_entered.connect(func(s): entered.append(s))
	m.start()
	_expect(m.current == GuardStateMachine.PATROL, "Initial state must be PATROL (was %s)." % m.get_state_name())
	_expect(entered == [GuardStateMachine.PATROL], "start() should enter PATROL exactly once.")
	_expect(actor.nav_target == actor.patrol_route.get_point_position(0) and actor.nav_speed == actor.patrol_speed,
		"PATROL should start walking to the first patrol point at patrol speed.")
	m.start()
	_expect(entered == [GuardStateMachine.PATROL], "A second start() must not re-enter PATROL.")


func test_patrol_to_investigate() -> void:
	var actor := FakeActor.new()
	var m := _machine(actor)
	m.tick(_suspicious(), 0.1)
	_expect(m.current == GuardStateMachine.INVESTIGATE, "A suspicious sighting in PATROL should start INVESTIGATE.")
	_expect(m.last_reason == "suspicious sighting", "Reason should be 'suspicious sighting', was '%s'." % m.last_reason)
	_expect((m.get_current_state() as InvestigateState).target == SIGHT, "INVESTIGATE should target the sighting position.")
	_expect(actor.nav_target == SIGHT and actor.nav_speed == actor.investigate_speed, "INVESTIGATE should walk to the sighting at investigate speed.")


func test_patrol_to_chase() -> void:
	var actor := FakeActor.new()
	var m := _machine(actor)
	m.tick(_confirmed(), 0.1)
	_expect(m.current == GuardStateMachine.CHASE, "A confirmed sighting in PATROL should start CHASE.")
	_expect(actor.nav_target == SIGHT and actor.nav_speed == actor.chase_speed, "CHASE should run to the sighting at chase speed.")


func test_noise_triggers_investigate() -> void:
	var actor := FakeActor.new()
	var m := _machine(actor)
	m.tick(_noise(), 0.1)
	_expect(m.current == GuardStateMachine.INVESTIGATE and m.last_reason == "noise", "A noise in PATROL should start INVESTIGATE.")
	_expect(actor.nav_target == NOISE, "INVESTIGATE should walk to the noise.")
	# Noise does not interrupt a chase.
	var chase := _machine()
	chase.tick(_confirmed(), 0.1)
	chase.tick(_noise(), 0.1)
	_expect(chase.current == GuardStateMachine.CHASE, "Noise must not pull a guard out of CHASE.")


func test_investigate_to_chase() -> void:
	var m := _machine()
	m.tick(_suspicious(), 0.1)
	m.tick(_confirmed(Vector3(5, 0, 7)), 0.1)
	_expect(m.current == GuardStateMachine.CHASE and m.last_reason == "confirmed sighting", "A confirmed sighting in INVESTIGATE should start CHASE.")


func test_investigate_to_patrol_after_timeout() -> void:
	var actor := FakeActor.new()
	var m := _machine(actor)
	m.tick(_suspicious(), 0.1)
	_tick_for(m, _nothing(), 1.0)
	_expect(m.current == GuardStateMachine.INVESTIGATE and not (m.get_current_state() as InvestigateState).searching,
		"Before arriving, INVESTIGATE should still be travelling.")
	actor.arrived = true
	m.tick(_nothing(), 0.1)
	_expect((m.get_current_state() as InvestigateState).searching, "Arriving should start the search.")
	var forgets_before := actor.forgets
	_tick_for(m, _nothing(), actor.investigate_search_duration - 0.2)
	_expect(m.current == GuardStateMachine.INVESTIGATE, "INVESTIGATE should keep searching until the duration runs out.")
	_tick_for(m, _nothing(), 0.3)
	_expect(m.current == GuardStateMachine.PATROL and m.last_reason == "investigation timed out", "After the search times out the guard should return to PATROL.")
	_expect(actor.forgets == forgets_before + 1, "Returning to PATROL should forget the old evidence.")


func test_investigate_moves_to_new_evidence() -> void:
	var actor := FakeActor.new()
	var m := _machine(actor)
	var count := {"entered": 0}
	m.state_entered.connect(func(_s): count.entered += 1)
	m.tick(_suspicious(), 0.1)
	var elsewhere := Vector3(-3, 0, 9)
	m.tick(_suspicious(elsewhere), 0.1)
	var inv := m.get_current_state() as InvestigateState
	_expect(m.current == GuardStateMachine.INVESTIGATE and inv.target == elsewhere and actor.nav_target == elsewhere,
		"New suspicious evidence should move the investigation without leaving INVESTIGATE.")
	_expect(count.entered == 1, "Moving the investigation must not re-enter the state (entered %d times)." % count.entered)


func test_chase_to_investigate_after_losing_player() -> void:
	# Rule 1: sight lost for chase_lose_sight_time.
	var actor := FakeActor.new()
	var m := _machine(actor)
	m.tick(_confirmed(), 0.1)
	_tick_for(m, _nothing(), actor.chase_lose_sight_time - 0.2)
	_expect(m.current == GuardStateMachine.CHASE, "CHASE should keep going to the last known position for a while after losing sight.")
	_tick_for(m, _nothing(), 0.3)
	_expect(m.current == GuardStateMachine.INVESTIGATE and m.last_reason == "lost sight of the player", "Losing the player should lead to INVESTIGATE.")
	_expect((m.get_current_state() as InvestigateState).target == SIGHT, "The investigation should start at the last known position.")
	# Rule 2: reached the last known position without seeing the player.
	var actor2 := FakeActor.new()
	var m2 := _machine(actor2)
	m2.tick(_confirmed(), 0.1)
	m2.tick(_nothing(), 0.1)
	actor2.arrived = true
	m2.tick(_nothing(), 0.1)
	_expect(m2.current == GuardStateMachine.INVESTIGATE, "Reaching the last known position without seeing the player should lead to INVESTIGATE.")
	# Never straight back to PATROL.
	_expect(not m2.can_transition(GuardStateMachine.CHASE, GuardStateMachine.PATROL), "CHASE → PATROL must not be allowed.")


func test_chase_follows_only_perception() -> void:
	var actor := FakeActor.new()
	var m := _machine(actor)
	m.tick(_confirmed(Vector3(0, 0, 5)), 0.1)
	m.tick(GuardPerception.make(true, true, true, Vector3(3, 0, 5)), 0.1)
	_expect(actor.nav_target == Vector3(3, 0, 5), "While visible, the chase target should follow the sighting position.")
	var calls := actor.nav_calls.size()
	_tick_for(m, _nothing(), 1.0)
	_expect(actor.nav_calls.size() == calls and actor.nav_target == Vector3(3, 0, 5),
		"Without perception the chase target must stay at the last known position.")


func test_confirmed_sighting_beats_noise() -> void:
	var both := GuardPerception.make(true, true, true, SIGHT, true, NOISE)
	var actor := FakeActor.new()
	var m := _machine(actor)
	_expect(m.choose_priority_transition(both).to == GuardStateMachine.CHASE, "Priority: confirmed sighting must win over noise.")
	m.tick(both, 0.1)
	_expect(m.current == GuardStateMachine.CHASE and actor.nav_target == SIGHT, "With sighting and noise together the guard should chase the sighting.")
	# Suspicious sighting also beats noise for choosing where to investigate.
	var actor2 := FakeActor.new()
	var m2 := _machine(actor2)
	m2.tick(GuardPerception.make(false, false, true, SIGHT, true, NOISE), 0.1)
	_expect(m2.current == GuardStateMachine.INVESTIGATE and actor2.nav_target == SIGHT, "A suspicious sighting should beat noise as the investigation target.")


func test_invalid_transitions_are_rejected() -> void:
	var m := _machine()
	var rejected: Array[String] = []
	var count := {"entered": 0, "exited": 0}
	m.transition_rejected.connect(func(_f, _t, why): rejected.append(why))
	m.state_entered.connect(func(_s): count.entered += 1)
	m.state_exited.connect(func(_s): count.exited += 1)
	m.tick(_confirmed(), 0.1)  # → CHASE
	count.entered = 0
	count.exited = 0
	_expect(not m.request_transition(GuardStateMachine.PATROL, "skip investigate"), "CHASE → PATROL must be rejected.")
	_expect(not m.request_transition(7, "nonsense"), "An unknown state id must be rejected.")
	_expect(not m.request_transition(-1, "none"), "NONE must not be a transition target.")
	_expect(m.current == GuardStateMachine.CHASE and count.entered == 0 and count.exited == 0, "Rejected requests must not change state or run enter/exit.")
	_expect(rejected.size() == 3, "Each rejected request should be reported (%d reported)." % rejected.size())
	# A state that requests a transition from inside enter() is refused safely.
	var actor := FakeActor.new()
	var meddler := MeddlingPatrol.new()
	var m2 := GuardStateMachine.new(actor, meddler)
	m2.warn_on_reject = false
	m2.start()
	_expect(not meddler.enter_result and m2.current == GuardStateMachine.PATROL, "A transition requested from enter() must be rejected.")


func test_enter_exit_order_and_arguments() -> void:
	var m := _machine()
	var log: Array[String] = []
	m.state_exited.connect(func(s): log.append("exit " + GuardStateMachine.NAMES[s]))
	m.state_entered.connect(func(s): log.append("enter " + GuardStateMachine.NAMES[s]))
	m.transitioned.connect(func(f, t, _r): log.append("%s→%s" % [GuardStateMachine.NAMES[f], GuardStateMachine.NAMES[t]]))
	_tick_for(m, _nothing(), 0.5)
	_expect(m.time_in_state > 0.45, "time_in_state should accumulate.")
	m.tick(_suspicious(), 0.1)
	_expect(log == ["exit PATROL", "enter INVESTIGATE", "PATROL→INVESTIGATE"], "Expected exit, then enter, then transitioned; got %s." % [log])
	_expect(m.time_in_state == 0.0, "time_in_state should reset on entering a state.")
	log.clear()
	m.tick(_confirmed(), 0.1)
	_expect(log == ["exit INVESTIGATE", "enter CHASE", "INVESTIGATE→CHASE"], "Expected INVESTIGATE exit then CHASE enter; got %s." % [log])


func test_patrol_resumes_where_it_left_off() -> void:
	var actor := FakeActor.new()
	var m := _machine(actor)
	actor.arrived = true
	m.tick(_nothing(), 0.1)              # reached point 0, waiting
	_tick_for(m, _nothing(), actor.default_wait_time + 0.1)  # → walking to point 1
	var patrol := m.get_state(GuardStateMachine.PATROL) as PatrolState
	_expect(patrol.current_point == 1, "Patrol should be heading to point 2 (index 1).")
	m.tick(_noise(), 0.1)
	actor.arrived = true
	m.tick(_nothing(), 0.1)
	_tick_for(m, _nothing(), actor.investigate_search_duration + 0.2)
	_expect(m.current == GuardStateMachine.PATROL and patrol.current_point == 1 and actor.nav_target == actor.patrol_route.get_point_position(1),
		"After investigating, patrol should resume toward the same point.")


func test_repeated_requests_do_not_corrupt() -> void:
	var m := _machine()
	var count := {"entered": 0, "exited": 0}
	m.state_entered.connect(func(_s): count.entered += 1)
	m.state_exited.connect(func(_s): count.exited += 1)
	var accepted := 0
	for i in 5:
		if m.request_transition(GuardStateMachine.INVESTIGATE, "again", SIGHT):
			accepted += 1
	_expect(accepted == 1 and m.current == GuardStateMachine.INVESTIGATE and count.entered == 1 and count.exited == 1,
		"Five identical requests should cause exactly one transition (accepted %d, entered %d)." % [accepted, count.entered])
	for i in 20:
		m.tick(_suspicious(), 0.1)  # Same evidence every frame.
	_expect(m.current == GuardStateMachine.INVESTIGATE and count.entered == 1, "Repeating the same evidence must not re-enter INVESTIGATE.")
	for i in 3:
		m.tick(_confirmed(), 0.1)
	_expect(m.current == GuardStateMachine.CHASE and count.entered == 2 and m.transition_count == 2, "Repeated confirmed sightings should enter CHASE once.")


func test_random_request_storm_keeps_invariants() -> void:
	var actor := FakeActor.new()
	var m := _machine(actor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	# Counters live in a dictionary: lambdas capture plain ints by value.
	var c := {"enters": 1, "exits": 0, "signalled": 0, "illegal": 0}
	m.state_entered.connect(func(_s): c.enters += 1)
	m.state_exited.connect(func(_s): c.exits += 1)
	m.transitioned.connect(func(f, t, _r):
		c.signalled += 1
		# Checked against the table, not m.can_transition: a lambda capturing m,
		# connected to m's own signal, would form a reference cycle (a leak).
		if not (t in GuardStateMachine.ALLOWED.get(f, [])): c.illegal += 1)
	var perceptions := [_nothing(), _suspicious(), _confirmed(), _noise()]
	for i in 2000:
		match rng.randi_range(0, 3):
			0: m.request_transition(rng.randi_range(-2, 4), "random")
			1: actor.arrived = rng.randf() < 0.5
			_: m.tick(perceptions[rng.randi_range(0, 3)], rng.randf_range(0.01, 0.5))
		if not GuardStateMachine.is_valid_state(m.current) or c.enters - c.exits != 1:
			break
	_expect(GuardStateMachine.is_valid_state(m.current), "After 2000 random operations the state must still be valid.")
	_expect(c.enters - c.exits == 1, "Every exit must be paired with an enter (enters %d, exits %d)." % [c.enters, c.exits])
	_expect(c.illegal == 0, "%d illegal transitions happened." % c.illegal)
	_expect(c.signalled == m.transition_count and c.signalled > 50, "transition_count (%d) must match the signals emitted (%d)." % [m.transition_count, c.signalled])
	print("  [ai] random storm: 2000 operations, %d transitions, all legal, state valid" % c.signalled)


func test_no_shared_state_between_machines() -> void:
	var a := _machine()
	var b := _machine()
	a.tick(_confirmed(), 0.1)
	_expect(a.current == GuardStateMachine.CHASE and b.current == GuardStateMachine.PATROL, "Two guards' state machines must be independent.")
	# The AI scripts must not use static (shared) variables.
	for file in DirAccess.get_files_at("res://scripts/npc/ai"):
		if file.ends_with(".gd"):
			var source := FileAccess.get_file_as_string("res://scripts/npc/ai/" + file)
			_expect(not source.contains("static var"), "%s uses a static variable (hidden shared state)." % file)
