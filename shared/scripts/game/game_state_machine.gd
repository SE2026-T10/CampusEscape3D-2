class_name GameStateMachine
extends RefCounted

## Game-level state: whether the game is being played, the player has just
## been caught, the game is paused, or the player has won. This is separate
## from the guards' AI states (GuardStateMachine: PATROL / INVESTIGATE / CHASE)
## and never touches them.
##
## Only the transitions in ALLOWED can happen, and requesting the state the
## machine is already in is refused, so no transition happens twice.

signal state_changed(from: State, to: State)

enum State { PLAYING, CAUGHT, PAUSED, WIN }

## Which states each state may go to.
##   PLAYING → CAUGHT (a guard caught the player), PAUSED, WIN (escaped)
##   CAUGHT  → PLAYING (respawned at the checkpoint)
##   PAUSED  → PLAYING (resumed)
##   WIN     → nothing: restarting loads the level again, with a fresh machine
## Pausing during the short CAUGHT screen is not allowed.
const ALLOWED := {
	State.PLAYING: [State.CAUGHT, State.PAUSED, State.WIN],
	State.CAUGHT: [State.PLAYING],
	State.PAUSED: [State.PLAYING],
	State.WIN: [],
}

var current: State = State.PLAYING
## Every state entered, in order, starting with PLAYING.
var history: Array[State] = [State.PLAYING]
## Requests that were refused (duplicates or not allowed).
var rejected_count := 0


func can_transition(to: State) -> bool:
	return to != current and to in ALLOWED[current]


## Moves to `to` if allowed. Returns false, and changes nothing, otherwise.
func request(to: State) -> bool:
	if not can_transition(to):
		rejected_count += 1
		return false
	var from := current
	current = to
	history.append(to)
	state_changed.emit(from, to)
	return true


static func name_of(state: State) -> String:
	return State.keys()[state]
