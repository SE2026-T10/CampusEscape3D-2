class_name SecurityAlarm
extends Node3D

## The building's security alarm (Expanded Library, expansion Phase 4).
##
## A documented interface, not the full security system: puzzles raise it on a
## wrong attempt, and it answers with the level's existing systems only:
##   - a loud noise at the source through the NoiseSystem (source "alarm"),
##     which guards hear and investigate like any other noise;
##   - `alarm_raised` and a few seconds of "alarm active" for the HUD banner.
## It never catches the player by itself and never locks anything for good.
## Callers: wrong puzzle attempts (Phase 4) and SecurityCamera (Phase 5). Guards
## with expanded_security also pay more attention while it sounds (Guard).
## Entry point:
##   SecurityAlarm.find(node)                       the level's alarm, or null
##   raise_alarm(position, reason, radius = -1)     -1: noise_radius
##   is_active() -> bool, time_left
##   signal alarm_raised(position, reason), signal alarm_cleared
##   main_entrance_lockdown (reserved: escape 3, the main entrance, stays shut
##   while true; nothing in Phase 4 lifts it)
##
## Persistence: not stored. A respawn clears an active alarm.

signal alarm_raised(position: Vector3, reason: String)
signal alarm_cleared

## Seconds the alarm stays active after it is raised.
@export var duration := 8.0
## Noise made at the source: radius (metres) and intensity (0–1).
@export var noise_radius := 22.0
@export var noise_intensity := 1.0
## Reserved for escape 3 (main entrance, security lockdown): no Phase 4 code lifts it.
@export var main_entrance_lockdown := true

var time_left := 0.0
## Times raised since the level started (for tests).
var alarms_raised := 0
var last_reason := ""


func _ready() -> void:
	add_to_group("security_alarm")
	_connect.call_deferred()


func _connect() -> void:
	# Cleared when the player respawns (CheckpointManager.respawned, which follows
	# the director's level_reset; level_reset itself keeps its two listeners).
	var checkpoints := CheckpointManager.find(self)
	if checkpoints and not checkpoints.respawned.is_connected(_on_respawned):
		checkpoints.respawned.connect(_on_respawned)


func _on_respawned(_checkpoint: Checkpoint) -> void:
	clear()


static func find(node: Node) -> SecurityAlarm:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("security_alarm") as SecurityAlarm


func raise_alarm(position: Vector3, reason: String, radius := -1.0) -> void:
	alarms_raised += 1
	last_reason = reason
	time_left = duration
	var system := NoiseSystem.find(self)
	if system:
		system.emit_noise(position, NoiseEvent.Type.INTERACTION, "alarm", noise_intensity, noise_radius if radius < 0.0 else radius)
	alarm_raised.emit(position, reason)


func is_active() -> bool:
	return time_left > 0.0


func clear() -> void:
	if time_left > 0.0:
		time_left = 0.0
		alarm_cleared.emit()


func _process(delta: float) -> void:
	if time_left > 0.0:
		time_left = maxf(time_left - delta, 0.0)
		if time_left == 0.0:
			alarm_cleared.emit()
