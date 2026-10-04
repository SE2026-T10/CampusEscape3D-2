class_name GuardStateMachine
extends RefCounted

## Explicit state machine for a guard, with exactly three primary states:
## PATROL, INVESTIGATE and CHASE.
##
## Each tick:
##   1. Perception rules are checked in fixed priority order (below). The
##      first one that applies causes a transition, and nothing else runs.
##   2. Otherwise the current state's update() runs. It may request a
##      transition (timeout, lost sight), which is applied after update().
##
## Priority (highest first):
##   1. Confirmed sighting        PATROL/INVESTIGATE → CHASE
##   2. Suspicious sighting       PATROL → INVESTIGATE (at the sighting)
##   3. Noise                     PATROL → INVESTIGATE (at the noise)
##   4. State's own rules         INVESTIGATE → PATROL (search timed out)
##                                CHASE → INVESTIGATE (lost sight)
##
## Only the transitions in ALLOWED are legal; anything else (for example
## CHASE → PATROL, unknown ids, or a request while a transition is running)
## is rejected and reported. All state lives in this object and its three
## state objects: nothing is global.

signal transitioned(from: int, to: int, reason: String)
signal state_entered(state: int)
signal state_exited(state: int)
signal transition_rejected(from: int, to: int, reason: String)

const NONE := -1
const PATROL := 0
const INVESTIGATE := 1
const CHASE := 2
const NAMES := ["PATROL", "INVESTIGATE", "CHASE"]

## Legal transitions: from → allowed targets.
const ALLOWED := {
	PATROL: [INVESTIGATE, CHASE],
	INVESTIGATE: [CHASE, PATROL],
	CHASE: [INVESTIGATE],
}

var current: int = NONE
## Seconds spent in the current state.
var time_in_state := 0.0
## Reason given for the last transition (for the debug label).
var last_reason := ""
## Number of transitions made since start (for tests and debugging).
var transition_count := 0
## Print a warning when a transition is rejected (tests that do this on purpose turn it off).
var warn_on_reject := true

var _actor
var _states: Array[GuardState] = []
var _transitioning := false
var _in_update := false
var _pending := {}   # transition requested during update(): {to, reason, position}


func _init(actor, patrol := PatrolState.new(), investigate := InvestigateState.new(), chase := ChaseState.new()) -> void:
	_actor = actor
	_states = [patrol, investigate, chase]
	for state in _states:
		state.machine = self


## Enters the initial state, PATROL.
func start() -> void:
	if current != NONE:
		if warn_on_reject:
			push_warning("GuardStateMachine.start() called twice; ignored.")
		return
	_enter(PATROL, NONE, Vector3.ZERO, "start")


func get_state(id: int) -> GuardState:
	return _states[id] if is_valid_state(id) else null


func get_current_state() -> GuardState:
	return get_state(current)


func get_state_name(id: int = current) -> String:
	return NAMES[id] if is_valid_state(id) else "NONE"


static func is_valid_state(id: int) -> bool:
	return id >= 0 and id < NAMES.size()


func can_transition(from: int, to: int) -> bool:
	return ALLOWED.has(from) and to in ALLOWED[from]


## Runs one step: priority rules first, then the current state's update.
func tick(perception: GuardPerception, delta: float) -> void:
	if current == NONE:
		return
	time_in_state += delta
	var rule := choose_priority_transition(perception)
	if not rule.is_empty():
		request_transition(rule.to, rule.reason, rule.position)
		return
	_in_update = true
	_states[current].update(_actor, perception, delta)
	_in_update = false
	if not _pending.is_empty():
		var pending := _pending
		_pending = {}
		request_transition(pending.to, pending.reason, pending.position)


## The highest-priority perception rule that applies now, or {} if none.
## Pure function of the current state and the perception snapshot.
func choose_priority_transition(perception: GuardPerception) -> Dictionary:
	if perception.confirmed_sighting and current != CHASE:
		return {"to": CHASE, "reason": "confirmed sighting", "position": perception.sighting_position}
	if current == PATROL:
		if perception.suspicious_sighting and perception.has_sighting_position:
			return {"to": INVESTIGATE, "reason": "suspicious sighting", "position": perception.sighting_position}
		if perception.noise_heard:
			return {"to": INVESTIGATE, "reason": "noise", "position": perception.noise_position}
	return {}


## Asks for a transition. Returns true if it happened (or, during a state's
## update, was accepted to happen right after it). Same-state requests are
## ignored without side effects; illegal ones are rejected.
func request_transition(to: int, reason := "", position := Vector3.ZERO) -> bool:
	if not is_valid_state(to):
		_reject(to, "unknown state %d" % to)
		return false
	if current == NONE:
		_reject(to, "state machine not started")
		return false
	if to == current:
		return false  # Already there: nothing to do, no exit/enter.
	if _transitioning:
		_reject(to, "requested during a transition (from an enter/exit callback)")
		return false
	if not can_transition(current, to):
		_reject(to, "%s → %s is not an allowed transition" % [get_state_name(current), get_state_name(to)])
		return false
	if _in_update:
		if _pending.is_empty():
			_pending = {"to": to, "reason": reason, "position": position}
			return true
		_reject(to, "a transition was already requested this update")
		return false

	var from := current
	_transitioning = true
	_states[from].exit(_actor, to)
	state_exited.emit(from)
	_transitioning = false
	_enter(to, from, position, reason)
	transition_count += 1
	transitioned.emit(from, to, reason)
	return true


func _enter(to: int, from: int, position: Vector3, reason: String) -> void:
	current = to
	time_in_state = 0.0
	last_reason = reason
	_transitioning = true
	_states[to].enter(_actor, from, position)
	_transitioning = false
	state_entered.emit(to)


func _reject(to: int, why: String) -> void:
	if warn_on_reject:
		push_warning("GuardStateMachine: rejected transition to %s: %s" % [get_state_name(to) if is_valid_state(to) else str(to), why])
	transition_rejected.emit(current, to, why)


## One-line summary for debugging, e.g. "INVESTIGATE (searching 3.2s)".
func get_debug_text() -> String:
	if current == NONE:
		return "NONE"
	var detail := _states[current].get_debug_text()
	return get_state_name() + (" (%s)" % detail if detail != "" else "")
