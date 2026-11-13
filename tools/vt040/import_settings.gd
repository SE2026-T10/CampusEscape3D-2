extends SceneTree

const Importer := preload("res://features/settings_import/settings_batch_import.gd")
const Settings := preload("res://shared/scripts/game/game_settings.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or args.size() > 2:
		printerr("Usage: godot --headless --path . --script res://tools/vt040/import_settings.gd -- <batch.json> [settings.cfg]")
		quit(2)
		return
	var destination := args[1] if args.size() == 2 else Settings.DEFAULT_PATH
	var result := Importer.import_file(args[0], destination)
	print(JSON.stringify(result))
	quit(0 if result.saved > 0 else 1)
