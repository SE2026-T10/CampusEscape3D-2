class_name AudioDirector
extends Node

## The level's non-positional sound: one place that turns game events into audio.
##   - stingers when the stealth situation changes: notice (a guard starts seeing
##     you), suspicious (an investigation starts), alarm (a chase starts),
##     lost track (the danger is over), caught
##   - music layers: a low tension drone while seen or investigated, a driving
##     loop during a chase, crossfaded; silent otherwise
##   - objectives: card pickup, objective complete, checkpoint, exit locked / open
##   - game flow: pause / resume, victory
##   - the library's room tone (it keeps playing, quieter, while paused)
## Positional sounds (footsteps, guards, the clock, page turns) are played by
## PlayerFeedback, GuardPresentation and AmbientEmitter.
## Nothing here changes gameplay: it only listens.

## Seconds before the same stinger may play again (stops rapid repeats when
## the situation flickers between two statuses).
const STING_COOLDOWN := 1.5
const MUSIC_FADE := 1.2
const S := StealthDirector.Status

## Every sound requested, in order (for tests and debugging).
var played: Array[String] = []
## Music now: "", "tension" or "chase".
var music_layer := ""

var _sfx: Array[AudioStreamPlayer] = []
var _ui: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _tension: AudioStreamPlayer
var _chase: AudioStreamPlayer
var _last_sting := {}
var _time := 0.0
var _music_suppressed := false


func _ready() -> void:
	add_to_group("audio_director")
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(p)
		_sfx.append(p)
	_ui = _player("UI", -4.0, Node.PROCESS_MODE_ALWAYS)
	_ambience = _player("Ambience", -14.0, Node.PROCESS_MODE_ALWAYS)
	_ambience.stream = SoundBank.pick("amb_room_tone")
	_tension = _player("Music", -80.0, Node.PROCESS_MODE_PAUSABLE)
	_tension.stream = SoundBank.pick("music_tension")
	_chase = _player("Music", -80.0, Node.PROCESS_MODE_PAUSABLE)
	_chase.stream = SoundBank.pick("music_chase")
	_ambience.play()
	_connect.call_deferred()


static func find(node: Node) -> AudioDirector:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("audio_director") as AudioDirector


func _connect() -> void:
	var director := StealthDirector.find(self)
	if director:
		director.status_changed.connect(_on_status_changed)
	var objectives := ObjectiveManager.find(self)
	if objectives:
		objectives.objective_completed.connect(_on_objective_completed)
	var checkpoints := CheckpointManager.find(self)
	if checkpoints:
		checkpoints.checkpoint_activated.connect(func(_cp): play_sfx("checkpoint", -6.0))
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.has_signal("rejected"):
			node.rejected.connect(func(_reason): play_sfx("door_locked", -2.0))
		if node is ExitDoor:
			node.escaped.connect(func(): play_sfx("door_open", -3.0))
		if node.has_signal("opened"):
			node.opened.connect(func(): play_sfx("door_open", -3.0))
	var flow := GameFlow.find(self)
	if flow:
		flow.state_changed.connect(_on_game_state_changed)


func _process(delta: float) -> void:
	_time += delta
	var paused := get_tree().paused
	_ambience.volume_db = move_toward(_ambience.volume_db, -22.0 if paused else -14.0, 30.0 * delta)
	if paused:
		return
	var target_tension := 0.0
	var target_chase := 0.0
	if not _music_suppressed:
		if music_layer == "chase":
			target_chase = 1.0
		elif music_layer == "tension":
			target_tension = 1.0
	_fade(_tension, target_tension, -12.0, delta)
	_fade(_chase, target_chase, -7.0, delta)


## Plays a one-shot on the SFX bus (paused with the game).
func play_sfx(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var stream := SoundBank.pick(sound)
	played.append(sound)
	if stream == null:
		return
	var player := _free_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Plays a UI sound (works while paused).
func play_ui(sound: String, volume_db := 0.0) -> void:
	var stream := SoundBank.pick(sound)
	played.append(sound)
	if stream == null:
		return
	_ui.stream = stream
	_ui.volume_db = -4.0 + volume_db
	_ui.play()


func set_music(layer: String) -> void:
	music_layer = layer


func _on_status_changed(previous: StealthDirector.Status, current: StealthDirector.Status) -> void:
	match current:
		S.CHASE:
			_sting("alarm", -2.0)
			set_music("chase")
		S.SPOTTED:
			if previous < S.SPOTTED:
				_sting("notice", -4.0)
			set_music("tension")
		S.INVESTIGATING:
			if previous < S.INVESTIGATING:
				_sting("suspicious", -4.0)
			set_music("tension")
		S.CAUGHT:
			play_sfx("caught", -1.0)
			set_music("")
		S.ESCAPED:
			set_music("")
		_:
			if previous == S.CHASE or previous == S.INVESTIGATING or previous == S.SPOTTED:
				_sting("lost_track", -8.0)
			set_music("")


func _on_objective_completed(id: StringName) -> void:
	if id == ObjectiveManager.TAKE_CARD:
		play_sfx("card_pickup", -2.0)
	elif id != ObjectiveManager.ESCAPE:
		play_sfx("objective_complete", -6.0)


func _on_game_state_changed(_from: GameStateMachine.State, to: GameStateMachine.State) -> void:
	match to:
		GameStateMachine.State.PAUSED:
			play_ui("ui_pause")
		GameStateMachine.State.PLAYING:
			if _from == GameStateMachine.State.PAUSED:
				play_ui("ui_resume")
		GameStateMachine.State.WIN:
			_music_suppressed = true
			set_music("")
			play_ui("victory", 2.0)


func _sting(sound: String, volume_db: float) -> void:
	if _time - _last_sting.get(sound, -INF) < STING_COOLDOWN:
		return
	_last_sting[sound] = _time
	play_sfx(sound, volume_db)


func _fade(player: AudioStreamPlayer, target: float, full_db: float, delta: float) -> void:
	var current := db_to_linear(player.volume_db) / db_to_linear(full_db)
	current = move_toward(current, target, delta / MUSIC_FADE)
	if current <= 0.001:
		player.volume_db = -80.0
		if player.playing:
			player.stop()
		return
	if not player.playing:
		player.play()
	player.volume_db = linear_to_db(current * db_to_linear(full_db))


func _free_player() -> AudioStreamPlayer:
	for p in _sfx:
		if not p.playing:
			return p
	return _sfx[0]


func _player(bus: String, volume_db: float, mode: Node.ProcessMode) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = StringName(bus)
	p.volume_db = volume_db
	p.process_mode = mode
	add_child(p)
	return p
