extends RefCounted

const Settings := preload("res://shared/scripts/game/game_settings.gd")
const MAX_BYTES := 256 * 1024
const MAX_RECORDS := 1000


static func import_file(source_path: String, settings_path: String) -> Dictionary:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return _result("input_error", [], 0, FileAccess.get_open_error())
	var bytes := source.get_buffer(MAX_BYTES + 1)
	var input_error := source.get_error()
	source.close()
	if input_error != OK and input_error != ERR_FILE_EOF:
		return _result("input_error", [], 0, input_error)
	if bytes.size() > MAX_BYTES:
		return _result("invalid_input", [])
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Array:
		return _result("invalid_input", [])
	var records: Array = parser.data
	if records.size() > MAX_RECORDS:
		return _result("invalid_input", [])

	var accepted := {}
	var rejected: Array[Dictionary] = []
	for index in range(records.size()):
		var record: Variant = records[index]
		var reason := _reject_reason(record, accepted)
		if reason.is_empty():
			accepted[record.key] = record.value
		else:
			rejected.append({"row": index + 1, "reason": reason})
	if accepted.is_empty():
		return _result("no_valid_records", rejected)

	var config := ConfigFile.new()
	if FileAccess.file_exists(settings_path):
		var read_error := config.load(settings_path)
		if read_error != OK:
			return _result("read_error", rejected, 0, read_error)
	for key in accepted:
		config.set_value(Settings.SECTION, key, accepted[key])
	var write_error := _replace_config(config, settings_path)
	if write_error != OK:
		return _result("storage_error", rejected, 0, write_error)
	return _result("success" if rejected.is_empty() else "partial_success", rejected, accepted.size())


static func _reject_reason(record: Variant, accepted: Dictionary) -> String:
	if not record is Dictionary or not record.get("key") is String or not record.has("value"):
		return "invalid_record"
	var key: String = record.key
	var value: Variant = record.value
	match key:
		"hud_scale":
			if not _is_number(value) or not Settings.HUD_SCALES.has(float(value)):
				return "invalid_value"
		"master_volume":
			if not _is_number(value) or not is_finite(float(value)) or value < 0.0 or value > 1.0:
				return "invalid_value"
		"captions":
			if not value is bool:
				return "invalid_value"
		_:
			return "unknown_key"
	return "duplicate_key" if accepted.has(key) else ""


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _replace_config(config: ConfigFile, path: String) -> Error:
	var target := ProjectSettings.globalize_path(path)
	var suffix := Crypto.new().generate_random_bytes(12).hex_encode()
	var temporary := "%s.vt040-%s.tmp" % [target, suffix]
	var error := config.save(temporary)
	if error == OK:
		# ConfigFile.save() can return OK after opening the file even if writing failed.
		var written := ConfigFile.new()
		error = written.load(temporary)
		if error == OK and written.encode_to_text() != config.encode_to_text():
			error = ERR_FILE_CANT_WRITE
	if error == OK:
		error = _install_config(temporary, target)
	if error != OK and FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(temporary)
	return error


static func _install_config(temporary: String, target: String) -> Error:
	if not FileAccess.file_exists(target):
		return DirAccess.rename_absolute(temporary, target)
	# Godot's Windows rename can remove an existing destination before moving.
	# Keep the old file until the new one is installed.
	var backup := temporary + ".previous"
	var error := DirAccess.rename_absolute(target, backup)
	if error != OK:
		return error
	error = DirAccess.rename_absolute(temporary, target)
	if error != OK:
		if DirAccess.rename_absolute(backup, target) != OK:
			push_error("Could not restore the previous settings file. Backup: " + backup)
		return error
	if DirAccess.remove_absolute(backup) != OK:
		push_warning("Could not remove the previous settings backup: " + backup)
	return OK


static func _result(status: String, rejected: Array, saved := 0, error := OK) -> Dictionary:
	return {"status": status, "saved": saved, "rejected": rejected, "error": error}
