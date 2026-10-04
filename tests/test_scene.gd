extends Node

## Project test runner: Phase 1 setup checks, then the Phase 2 player tests
## (tests/player_tests.gd), Phase 3 navigation tests (tests/navigation_tests.gd)
## Phase 4 guard tests (tests/guard_tests.gd), Phase 5 vision tests (tests/vision_tests.gd)
## Phase 6 AI tests (tests/ai_state_tests.gd unit tests, tests/ai_behavior_tests.gd in the level)
## Phase 7 hearing tests (tests/hearing_tests.gd), Phase 8 stealth-loop tests (tests/loop_tests.gd) and Phase 9 objective and checkpoint tests (tests/objective_tests.gd). Run this scene directly in Godot (F6), or headless:
##   godot --headless --path . res://tests/test_scene.tscn
## Exits with code 0 when every check passes and 1 otherwise, so it can be
## used by an automated build. Checks use explicit failures instead of
## assert(), because assert() is stripped from release builds and pauses a
## headless run in the debugger instead of failing it.

const EXPECTED_VERSION := "4.7.2"
const EXPECTED_HASH_PREFIX := "ed1daf0bf"
const PlayerTests := preload("res://tests/player_tests.gd")
const NavigationTests := preload("res://tests/navigation_tests.gd")
const GuardTests := preload("res://tests/guard_tests.gd")
const VisionTests := preload("res://tests/vision_tests.gd")
const AIStateTests := preload("res://tests/ai_state_tests.gd")
const AIBehaviorTests := preload("res://tests/ai_behavior_tests.gd")
const HearingTests := preload("res://tests/hearing_tests.gd")
const LoopTests := preload("res://tests/loop_tests.gd")
const ObjectiveTests := preload("res://tests/objective_tests.gd")
const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const REQUIRED_DIRS := [
	"res://scenes/player", "res://scenes/npc", "res://scenes/level",
	"res://scenes/ui", "res://scenes/systems",
	"res://scripts/player", "res://scripts/npc", "res://scripts/systems",
	"res://scripts/utilities",
	"res://assets/models", "res://assets/materials", "res://assets/audio",
	"res://assets/textures",
	"res://tests", "res://docs",
]

var _failures: Array[String] = []


func _ready() -> void:
	_check_engine_version()
	_check_project_settings()
	_check_windows_export_preset()
	_check_folder_structure()
	_check_all_scripts_compile()
	_check_library_graybox()
	# Pure state machine unit tests first: fast, no scene needed.
	_failures.append_array(AIStateTests.new().run(self))
	_failures.append_array(await PlayerTests.new().run(self))
	_failures.append_array(await NavigationTests.new().run(self))
	_failures.append_array(await GuardTests.new().run(self))
	_failures.append_array(await VisionTests.new().run(self))
	_failures.append_array(await AIBehaviorTests.new().run(self))
	_failures.append_array(await HearingTests.new().run(self))
	_failures.append_array(await LoopTests.new().run(self))
	_failures.append_array(await ObjectiveTests.new().run(self))

	if _failures.is_empty():
		print("All tests passed (Phase 1 setup, Phase 2 player, Phase 3 navigation, Phase 4 guards, Phase 5 vision, Phase 6 AI, Phase 7 hearing, Phase 8 stealth loop, Phase 9 objectives).")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		print("Tests FAILED (%d issue(s))." % _failures.size())
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _check_engine_version() -> void:
	var info := Engine.get_version_info()
	var version := "%d.%d.%d" % [info.major, info.minor, info.patch]
	_expect(version == EXPECTED_VERSION, "Engine version is %s, expected %s." % [version, EXPECTED_VERSION])
	_expect(info.status == "stable", "Engine build status is '%s', expected 'stable'." % info.status)
	_expect(String(info.hash).begins_with(EXPECTED_HASH_PREFIX),
		"Engine commit is '%s', expected %s." % [info.hash, EXPECTED_HASH_PREFIX])


func _check_project_settings() -> void:
	_expect(ProjectSettings.get_setting("application/config/name") == "Campus Escape 3D",
		"Project name is not 'Campus Escape 3D'.")
	_expect(ProjectSettings.get_setting("application/run/main_scene") == LIBRARY_SCENE,
		"Main scene is not the library graybox.")
	var features: PackedStringArray = ProjectSettings.get_setting("application/config/features")
	_expect(features.has("4.7"), "Project features do not declare Godot 4.7.")


func _check_windows_export_preset() -> void:
	var presets := ConfigFile.new()
	_expect(presets.load("res://export_presets.cfg") == OK, "export_presets.cfg could not be read.")
	_expect(presets.get_value("preset.0", "platform", "") == "Windows Desktop",
		"The first export preset is not 'Windows Desktop'.")


func _check_folder_structure() -> void:
	for path in REQUIRED_DIRS:
		_expect(DirAccess.dir_exists_absolute(path), "Missing folder %s." % path)


## Every GDScript in the project must load and compile. Without this, a parse
## error only prints to the log while dependent scenes quietly lose behaviour.
func _check_all_scripts_compile() -> void:
	var checked := 0
	for folder in ["res://scripts", "res://tests", "res://tools"]:
		for path in _find_scripts(folder):
			checked += 1
			var script := load(path) as GDScript
			_expect(script != null and script.can_instantiate(), "Script fails to compile: %s" % path)
	_expect(checked >= 10, "Expected to find the project's scripts, found %d." % checked)


func _find_scripts(folder: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_find_scripts(folder.path_join(sub)))
	return found


func _check_library_graybox() -> void:
	var library_scene := load(LIBRARY_SCENE) as PackedScene
	_expect(library_scene != null, "The library graybox scene must load.")
	if library_scene == null:
		return
	var library := library_scene.instantiate()
	_expect(library is Node3D, "The graybox root must be a Node3D.")
	_expect(library.name == "LibraryGraybox", "The graybox root must be named LibraryGraybox.")
	# Room-by-room layout is checked by tests/navigation_tests.gd.
	for node_name in ["WorldEnvironment", "KeyLight", "NavigationRegion3D", "Player"]:
		_expect(library.get_node_or_null(node_name) != null, "The graybox must include %s." % node_name)
	# The overview camera is kept for inspecting the level; the player camera is the active one.
	var camera := library.get_node_or_null("PreviewCamera") as Camera3D
	_expect(camera != null and not camera.current, "The graybox must keep a non-current PreviewCamera.")
	library.free()
