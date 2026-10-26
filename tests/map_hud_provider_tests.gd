extends RefCounted

## Proves a non-library map can supply HUD state and contextual exit hints.
const TUTORIAL := "res://maps/tutorial/scenes/library_graybox.tscn"
const TestUtils := preload("res://tests/test_utils.gd")

class DemoProvider extends MapHudProvider:
	func get_status_lines() -> Array[String]:
		return ["INTELLIGENCE", "File acquired: extraction pending"]

	func get_exit_hint(_exit: Node) -> String:
		return "Reach the extraction point with the intelligence file."


func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var level := (load(TUTORIAL) as PackedScene).instantiate()
	var ready: bool = await TestUtils.add_level_and_wait_for_navigation(host, level, Vector3(0, 0, 18))
	if not ready:
		failures.append("[map-contract] tutorial fixture navigation did not become ready")
	var provider := DemoProvider.new()
	level.add_child(provider)
	var hud := level.get_node("ObjectiveHud") as ObjectiveHud
	if MapHudProvider.find_for(level) != provider:
		failures.append("[map-contract] provider is not registered in the current scene")
	if hud.get_status_lines() != provider.get_status_lines():
		failures.append("[map-contract] custom status was replaced by library-specific text")
	if not hud._status_bbcode().contains("INTELLIGENCE"):
		failures.append("[map-contract] shared HUD did not render custom map status")
	var exit := level.get_node("Gameplay/ExitDoor") as ExitDoor
	# Query the configurable exit without changing the fixture's actual geometry.
	exit.walk_through = true
	if exit.rejection_reason() != provider.get_exit_hint(exit):
		failures.append("[map-contract] exit did not use the map-specific refusal hint")
	exit.walk_through = false
	provider.queue_free()
	await host.get_tree().process_frame
	if MapHudProvider.find_for(level) != null or not hud.get_status_lines().is_empty():
		failures.append("[map-contract] removed provider left stale status")
	level.queue_free()
	# AudioServer releases stopped streams asynchronously after the scene exits.
	for i in 30:
		await host.get_tree().process_frame
	if MapHudProvider.find_for(host) != null:
		failures.append("[map-contract] provider survived leaving the map")
	print("  [map-contract] independent status, exit hints and scene cleanup")
	return failures
