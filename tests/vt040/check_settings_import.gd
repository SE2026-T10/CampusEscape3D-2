extends SceneTree

const IMPORTER_PATH := "res://features/settings_import/settings_batch_import.gd"
const Settings := preload("res://shared/scripts/game/game_settings.gd")
const MENU := preload("res://shared/scenes/ui/main_menu.tscn")

var _folder := ""
var _source := ""
var _destination := ""
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_folder = OS.get_temp_dir().path_join("vt040-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	_check(DirAccess.make_dir_recursive_absolute(_folder) == OK, "test fixture directory")
	_source = _folder.path_join("batch.json")
	_destination = _folder.path_join("settings.cfg")
	await _menu_regression()
	if not ResourceLoader.exists(IMPORTER_PATH):
		_seed_destination()
		_write(_source, JSON.stringify([_row("hud_scale", 1.25), _row("captions", false)]))
		_check_first_batch()
		_finish()
		return
	var importer: GDScript = load(IMPORTER_PATH)
	_examples(importer)
	_property_cases(importer)
	await _menu_regression()
	_finish()


func _examples(importer: GDScript) -> void:
	_seed_destination()
	var result: Dictionary = _import(importer, [_row("hud_scale", 1.25), _row("captions", false)])
	_check(result.status == "success" and result.saved == 2 and result.rejected.is_empty(), "T01: both valid rows committed")
	_check_first_batch()
	var file := _read_destination()
	_check(is_equal_approx(file.get_value("settings", "master_volume", 0.0), 0.4) and file.get_value("other", "keep", "") == "yes", "T02: omitted values and other sections survive")

	_seed_destination()
	result = _import(importer, [_row("master_volume", 2.0), _row("captions", false), _row("captions", true), _row("unknown", 1), _row("master_volume", 0.6)])
	_check(result.status == "partial_success" and result.saved == 2, "T03: mixed batch writes valid rows only")
	_check(result.rejected == [{"row": 1, "reason": "invalid_value"}, {"row": 3, "reason": "duplicate_key"}, {"row": 4, "reason": "unknown_key"}], "T03/T04: rejected row indices and causes")
	file = _read_destination()
	_check(file.get_value("settings", "captions", true) == false and is_equal_approx(file.get_value("settings", "master_volume", 0.0), 0.6), "T04: first valid value wins and invalid rows do not reserve keys")
	var before := FileAccess.get_file_as_bytes(_destination)
	result = _import(importer, [false, {"key": "captions"}, _row("captions", "false"), _row("hud_scale", 1.11)])
	_check(result.status == "no_valid_records" and result.saved == 0 and result.rejected.size() == 4, "T05: all-invalid batch")
	_check(FileAccess.get_file_as_bytes(_destination) == before, "T05: all-invalid leaves destination byte-identical")
	result = _import(importer, [])
	_check(result.status == "no_valid_records" and FileAccess.get_file_as_bytes(_destination) == before, "T05: empty batch leaves destination intact")

	_write(_source, '{"broken":')
	result = importer.import_file(_source, _destination)
	_check(result.status == "invalid_input" and FileAccess.get_file_as_bytes(_destination) == before, "T06: malformed JSON leaves destination intact")
	_write(_source, '{"key":"captions","value":false}')
	result = importer.import_file(_source, _destination)
	_check(result.status == "invalid_input", "T06: root must be an array")
	result = _import(importer, [_row("captions", false)], _folder.path_join("missing").path_join("settings.cfg"))
	_check(result.status == "storage_error" and result.saved == 0 and result.get("error", OK) != OK, "T07: write failure must report storage_error and zero saved")
	_check(not FileAccess.file_exists(_folder.path_join("missing/settings.cfg")), "T07: failed write creates no destination")

	# A directory at the destination prevents replacement after the temporary file is written.
	var occupied := _folder.path_join("occupied")
	_check(DirAccess.make_dir_absolute(occupied) == OK, "T07: create occupied destination fixture")
	result = _import(importer, [_row("captions", false)], occupied)
	_check(result.status == "storage_error" and result.saved == 0 and DirAccess.dir_exists_absolute(occupied), "T07: replace failure reports zero and leaves destination intact")
	_check(DirAccess.get_files_at(_folder).size() == 2, "T07: temporary files are removed after failure")
	DirAccess.remove_absolute(occupied)

	_write(_destination, "[settings\ncorrupt\n")
	result = _import(importer, [_row("captions", false)])
	_check(result.status == "read_error" and FileAccess.get_file_as_string(_destination) == "[settings\ncorrupt\n", "T08: damaged existing file is not overwritten")
	DirAccess.remove_absolute(_destination)
	result = _import(importer, [_row("captions", false)])
	file = _read_destination()
	_check(result.status == "success" and file.get_value("settings", "captions", true) == false, "T09: destination can be created")
	before = FileAccess.get_file_as_bytes(_destination)
	var long_batch: Array = []
	long_batch.resize(1001)
	long_batch.fill(_row("captions", true))
	result = _import(importer, long_batch)
	_check(result.status == "invalid_input", "T10: reject more than 1000 rows")
	_write(_source, " ".repeat(262145))
	result = importer.import_file(_source, _destination)
	_check(result.status == "invalid_input" and FileAccess.get_file_as_bytes(_destination) == before, "T10: reject files over 256 KiB")


func _check_first_batch() -> void:
	var old_path := Settings.path
	Settings.path = _destination
	Settings.load_settings(true)
	_check(Settings.hud_scale == 1.25 and not Settings.captions,
		"T01: game must load HUD 1.25 and captions off from the imported batch (actual HUD=%s captions=%s)" % [Settings.hud_scale, Settings.captions])
	Settings.path = old_path
	Settings.reset_to_defaults()


func _property_cases(importer: GDScript) -> void:
	var rng := RandomNumberGenerator.new()
	var seeds: Array[int] = [40, 23001913, 20261114]
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		seeds = [int(args[0])]
	for seed_value in seeds:
		rng.seed = seed_value
		print("T11 property seed=%d examples=80" % seed_value)
		for index in range(80):
			var candidates := [
				_row("hud_scale", Settings.HUD_SCALES[rng.randi_range(0, 3)]),
				_row("master_volume", float(rng.randi_range(0, 100)) / 100.0),
				_row("captions", rng.randi_range(0, 1) == 1),
			]
			var valid_rows: Array = [candidates.pop_at(rng.randi_range(0, 2))]
			for candidate in candidates:
				if rng.randi_range(0, 1) == 1:
					valid_rows.append(candidate)
			var mixed: Array = valid_rows.duplicate()
			var invalid_rows := [_row("hud_scale", 4.0), _row("master_volume", -1.0), _row("captions", 1), null, _row("unrecognized", false)]
			var added := rng.randi_range(1, 12)
			for _index in range(added):
				mixed.insert(rng.randi_range(0, mixed.size()), invalid_rows[rng.randi_range(0, 4)])
			_seed_destination()
			var clean_result := _import(importer, valid_rows)
			var clean_file := FileAccess.get_file_as_bytes(_destination)
			_seed_destination()
			var mixed_result := _import(importer, mixed)
			_check(clean_result.status == "success" and mixed_result.status == "partial_success"
				and mixed_result.saved == valid_rows.size() and mixed_result.rejected.size() == added
				and FileAccess.get_file_as_bytes(_destination) == clean_file,
				"T11: insertion of invalid rows preserves committed data (seed=%d example=%d)" % [seed_value, index])


func _menu_regression() -> void:
	var old_path := Settings.path
	Settings.path = _destination
	if FileAccess.file_exists(_destination):
		DirAccess.remove_absolute(_destination)
	Settings.load_settings(true)
	_check(Settings.hud_scale == 1.0 and Settings.master_volume == 1.0 and Settings.captions, "T12: no file gives menu defaults")
	var menu: MainMenu = MENU.instantiate()
	root.add_child(menu)
	await process_frame
	menu.settings_button.pressed.emit()
	var panel := menu.settings_panel
	_check(panel.visible, "T12: Settings menu opens")
	panel.volume_slider.value = 55.0
	Settings.load_settings(true)
	_check(is_equal_approx(Settings.master_volume, 0.55), "T12: the existing slider saves and reloads")
	_check(is_equal_approx(Settings.hud_scale, 1.0) and Settings.captions, "T12: the slider preserves other options")
	panel.back_button.pressed.emit()
	await process_frame
	_check(not panel.visible and menu.settings_button.has_focus(), "T12: Back restores the Settings focus")
	menu.queue_free()
	await process_frame
	Settings.path = old_path
	Settings.reset_to_defaults()


func _seed_destination() -> void:
	var file := ConfigFile.new()
	file.set_value("settings", "hud_scale", 1.0)
	file.set_value("settings", "master_volume", 0.4)
	file.set_value("settings", "captions", true)
	file.set_value("other", "keep", "yes")
	if file.save(_destination) != OK:
		_check(false, "could not seed destination fixture")


func _read_destination() -> ConfigFile:
	var file := ConfigFile.new()
	if file.load(_destination) != OK:
		_check(false, "could not read destination fixture")
	return file


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "could not write source fixture")
		return
	file.store_string(content)
	file.close()


func _import(importer: GDScript, rows: Array, destination := "") -> Dictionary:
	_write(_source, JSON.stringify(rows))
	return importer.import_file(_source, _destination if destination.is_empty() else destination)


func _row(key: String, value: Variant) -> Dictionary:
	return {"key": key, "value": value}


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL ", message)


func _finish() -> void:
	for file in DirAccess.get_files_at(_folder):
		DirAccess.remove_absolute(_folder.path_join(file))
	DirAccess.remove_absolute(_folder)
	print("VT-040: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
