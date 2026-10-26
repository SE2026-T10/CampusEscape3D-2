extends Node

## Project test runner: Phase 1 setup checks, then the Phase 2 player tests
## (tests/player_tests.gd), Phase 3 navigation tests (tests/navigation_tests.gd)
## Phase 4 guard tests (tests/guard_tests.gd), Phase 5 vision tests (tests/vision_tests.gd)
## Phase 6 AI tests (tests/ai_state_tests.gd unit tests, tests/ai_behavior_tests.gd in the level)
## Phase 7 hearing tests (tests/hearing_tests.gd), Phase 8 stealth-loop tests (tests/loop_tests.gd), Phase 9 objective and checkpoint tests (tests/objective_tests.gd), Phase 10 game-flow tests (tests/game_flow_tests.gd), Phase 11 level-design tests (tests/level_design_tests.gd), Phase 12 presentation tests (tests/presentation_tests.gd), Phase 13 performance checks (tests/performance_tests.gd) Phase 14 QA playthroughs and regression tests (tests/qa_playthrough_tests.gd, tests/qa_regression_tests.gd) the Expanded Library graybox tests (maps/library/tests/expanded_graybox_tests.gd), the map selection tests (tests/map_selection_tests.gd), the Expanded Library navigation and guard tests (maps/library/tests/expanded_ai_tests.gd) the Expanded Library mission tests (maps/library/tests/expanded_mission_tests.gd), the Expanded Library expansion layout tests (maps/library/tests/expanded_layout_expansion_tests.gd), the Expanded Library expansion stamina and inventory tests (maps/library/tests/expanded_mechanics_tests.gd), the Expanded Library expansion puzzle, journal and objective tests (maps/library/tests/expanded_puzzle_tests.gd), the Expanded Library expansion security tests (maps/library/tests/expanded_security_tests.gd), the Expanded Library expansion escape and checkpoint tests (maps/library/tests/expanded_escape_tests.gd), the Expanded Library expansion HUD and accessibility tests (maps/library/tests/expanded_hud_tests.gd), the Expanded Library expansion end-to-end tests (maps/library/tests/expanded_e2e_tests.gd), the Expanded Library expansion polish tests (maps/library/tests/expanded_polish_tests.gd) and the Expanded Library expansion baseline tests (maps/library/tests/expanded_baseline_tests.gd). Run this scene directly in Godot (F6), or headless:
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
const GameFlowTests := preload("res://tests/game_flow_tests.gd")
const LevelDesignTests := preload("res://tests/level_design_tests.gd")
const PresentationTests := preload("res://tests/presentation_tests.gd")
const PerformanceTests := preload("res://tests/performance_tests.gd")
const QAPlaythroughTests := preload("res://tests/qa_playthrough_tests.gd")
const QARegressionTests := preload("res://tests/qa_regression_tests.gd")
const ExpandedGrayboxTests := preload("res://maps/library/tests/expanded_graybox_tests.gd")
const MapSelectionTests := preload("res://tests/map_selection_tests.gd")
const ExpandedAITests := preload("res://maps/library/tests/expanded_ai_tests.gd")
const ExpandedMissionTests := preload("res://maps/library/tests/expanded_mission_tests.gd")
const ExpandedBaselineTests := preload("res://maps/library/tests/expanded_baseline_tests.gd")
const ExpandedLayoutExpansionTests := preload("res://maps/library/tests/expanded_layout_expansion_tests.gd")
const ExpandedMechanicsTests := preload("res://maps/library/tests/expanded_mechanics_tests.gd")
const ExpandedPuzzleTests := preload("res://maps/library/tests/expanded_puzzle_tests.gd")
const ExpandedSecurityTests := preload("res://maps/library/tests/expanded_security_tests.gd")
const ExpandedEscapeTests := preload("res://maps/library/tests/expanded_escape_tests.gd")
const ExpandedHudTests := preload("res://maps/library/tests/expanded_hud_tests.gd")
const ExpandedE2ETests := preload("res://maps/library/tests/expanded_e2e_tests.gd")
const ExpandedPolishTests := preload("res://maps/library/tests/expanded_polish_tests.gd")
const K17MissionTests := preload("res://maps/intelligence/tests/k17_mission_tests.gd")
const HoldInteractionTests := preload("res://tests/hold_interaction_tests.gd")
const K17SecurityTests := preload("res://maps/intelligence/tests/k17_security_tests.gd")
const TestUtils := preload("res://tests/test_utils.gd")
const MAIN_MENU_SCENE := "res://shared/scenes/ui/main_menu.tscn"
const LIBRARY_SCENE := "res://maps/tutorial/scenes/library_graybox.tscn"
const REQUIRED_DIRS := [
	"res://shared/scenes/player", "res://shared/scenes/npc",
	"res://shared/scenes/ui", "res://maps/tutorial/scenes", "res://maps/library/scenes",
	"res://shared/scripts/player", "res://shared/scripts/npc", "res://shared/scripts/interaction",
	"res://features", "res://maps/library/tests",
	"res://shared/scripts/utilities",
	"res://shared/assets/models", "res://shared/assets/materials", "res://shared/assets/audio",
	"res://shared/assets/textures",
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
	_failures.append_array(await GameFlowTests.new().run(self))
	_failures.append_array(await LevelDesignTests.new().run(self))
	_failures.append_array(await PresentationTests.new().run(self))
	_failures.append_array(PerformanceTests.new().run(self))
	_failures.append_array(await QAPlaythroughTests.new().run(self))
	_failures.append_array(await QARegressionTests.new().run(self))
	_failures.append_array(await ExpandedGrayboxTests.new().run(self))
	_failures.append_array(await MapSelectionTests.new().run(self))
	_failures.append_array(await ExpandedAITests.new().run(self))
	_failures.append_array(await ExpandedMissionTests.new().run(self))
	_failures.append_array(await ExpandedLayoutExpansionTests.new().run(self))
	_failures.append_array(await ExpandedMechanicsTests.new().run(self))
	_failures.append_array(await ExpandedPuzzleTests.new().run(self))
	_failures.append_array(await ExpandedSecurityTests.new().run(self))
	_failures.append_array(await ExpandedEscapeTests.new().run(self))
	_failures.append_array(await ExpandedHudTests.new().run(self))
	_failures.append_array(await ExpandedE2ETests.new().run(self))
	_failures.append_array(await ExpandedPolishTests.new().run(self))
	_failures.append_array(await ExpandedBaselineTests.new().run(self))
	_failures.append_array(await K17MissionTests.new().run(self))
	_failures.append_array(await HoldInteractionTests.new().run(self))
	_failures.append_array(await K17SecurityTests.new().run(self))
	await TestUtils.settle_async_audio(get_tree())

	if _failures.is_empty():
		print("All tests passed (Phase 1 setup, Phase 2 player, Phase 3 navigation, Phase 4 guards, Phase 5 vision, Phase 6 AI, Phase 7 hearing, Phase 8 stealth loop, Phase 9 objectives, Phase 10 game flow, Phase 11 level design, Phase 12 presentation, Phase 13 performance, Phase 14 QA, Expanded Library graybox, map selection, Expanded Library guards, Expanded Library mission, Expanded Library expansion layout, Expanded Library expansion stamina and inventory, Expanded Library expansion puzzles, Expanded Library expansion security, Expanded Library expansion escapes and checkpoints, Expanded Library expansion HUD and accessibility, Expanded Library expansion end to end, Expanded Library expansion polish and performance, Expanded Library expansion baseline).")
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
	_expect(ProjectSettings.get_setting("application/run/main_scene") == MAIN_MENU_SCENE,
		"Main scene is not the main menu.")
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
	for folder in ["res://shared", "res://features", "res://maps", "res://tests", "res://tools"]:
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
		if sub.begins_with(".") or FileAccess.file_exists(folder.path_join(sub).path_join(".gdignore")):
			continue
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
