class_name GameFlow
extends Node

## Runs the game-level state machine (PLAYING / CAUGHT / PAUSED / WIN) for a
## level, and everything that depends on it:
##   - pausing: the whole scene tree pauses (guards, navigation, physics, noise,
##     timers), except this node and the menus, which run with PROCESS_MODE_ALWAYS
##   - the mouse: captured while playing (and on the short caught screen),
##     visible in the pause menu and on the win screen
##   - caught and respawn: follows StealthDirector (player_caught, level_reset)
##   - victory: follows ObjectiveManager.level_completed
##   - restart and return to the main menu (scene changes)
## The pause action is Escape (or P). Losing window focus while playing pauses too.

signal state_changed(from: GameStateMachine.State, to: GameStateMachine.State)

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

## Level loaded by restart() when this node's scene has no file path.
@export_file("*.tscn") var fallback_level_scene := "res://scenes/level/library_graybox.tscn"

var machine := GameStateMachine.new()
## Seconds spent in PLAYING (not paused, not on the caught screen).
var play_time := 0.0
## The mouse mode this node last set (Input.mouse_mode can't be read back in a headless run).
var applied_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
## How scenes are changed. Tests replace it to record requests instead.
var change_scene: Callable
## Scene changes requested so far (at most one: the level is being left after it).
var scene_requests: Array[String] = []

var state: GameStateMachine.State:
	get:
		return machine.current


func _init() -> void:
	change_scene = _change_scene


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_flow")
	machine.state_changed.connect(_on_machine_state_changed)
	get_tree().paused = false
	_apply_mouse(mouse_mode_for(state))
	_connect_systems.call_deferred()


static func find(node: Node) -> GameFlow:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("game_flow") as GameFlow


func _connect_systems() -> void:
	var director := StealthDirector.find(self)
	if director:
		director.player_caught.connect(_on_player_caught)
		director.level_reset.connect(_on_level_reset)
	var objectives := ObjectiveManager.find(self)
	if objectives:
		objectives.level_completed.connect(_on_level_completed)


func _process(delta: float) -> void:
	if state == GameStateMachine.State.PLAYING:
		play_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and state == GameStateMachine.State.PLAYING:
		pause()


# --- Requests -------------------------------------------------------------------------

func pause() -> bool:
	return machine.request(GameStateMachine.State.PAUSED)


func resume() -> bool:
	return state == GameStateMachine.State.PAUSED and machine.request(GameStateMachine.State.PLAYING)


func toggle_pause() -> bool:
	if state == GameStateMachine.State.PLAYING:
		return pause()
	if state == GameStateMachine.State.PAUSED:
		return resume()
	return false


## Loads the level again from the start. Returns false if a scene change is already under way.
func restart() -> bool:
	var path := owner.scene_file_path if owner and owner.scene_file_path != "" else fallback_level_scene
	return _leave_to(path)


func go_to_main_menu() -> bool:
	return _leave_to(MAIN_MENU_SCENE)


func is_leaving() -> bool:
	return not scene_requests.is_empty()


# --- Reactions --------------------------------------------------------------------------

func _on_player_caught(_by: Node) -> void:
	machine.request(GameStateMachine.State.CAUGHT)


func _on_level_reset() -> void:
	if state == GameStateMachine.State.CAUGHT:
		machine.request(GameStateMachine.State.PLAYING)


func _on_level_completed() -> void:
	machine.request(GameStateMachine.State.WIN)


func _on_machine_state_changed(from: GameStateMachine.State, to: GameStateMachine.State) -> void:
	get_tree().paused = to == GameStateMachine.State.PAUSED
	_apply_mouse(mouse_mode_for(to))
	state_changed.emit(from, to)


static func mouse_mode_for(game_state: GameStateMachine.State) -> Input.MouseMode:
	if game_state == GameStateMachine.State.PAUSED or game_state == GameStateMachine.State.WIN:
		return Input.MOUSE_MODE_VISIBLE
	return Input.MOUSE_MODE_CAPTURED


func _apply_mouse(mode: Input.MouseMode) -> void:
	applied_mouse_mode = mode
	Input.mouse_mode = mode


func _leave_to(path: String) -> bool:
	if is_leaving():
		return false
	scene_requests.append(path)
	get_tree().paused = false
	_apply_mouse(Input.MOUSE_MODE_VISIBLE)
	change_scene.call(path)
	return true


func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)
