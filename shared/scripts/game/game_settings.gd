class_name GameSettings
extends RefCounted

## Player settings (expansion Phase 7), kept in one place and saved to
## user://settings.cfg (a ConfigFile, section "settings"):
##   - hud_scale: the size of every 2D interface element (HUD and menus), one of
##     HUD_SCALES; applied as the window's content_scale_factor, so anchors and
##     layouts scale together and the 3D view is untouched
##   - master_volume: 0–1, the Master bus (0 mutes it)
##   - captions: on-screen captions for important sounds (SoundCaptions)
## A static helper like LevelCatalog and MenuStyle (no autoload): the main menu
## and every level (GameFlow) call apply() when they start, and SettingsPanel
## changes and saves them. Missing or broken files give the defaults.

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"
const HUD_SCALES := [0.9, 1.0, 1.1, 1.25]
const DEFAULTS := {"hud_scale": 1.0, "master_volume": 1.0, "captions": true}

## The file in use (tests point it elsewhere).
static var path := DEFAULT_PATH
static var hud_scale := 1.0
static var master_volume := 1.0
static var captions := true
static var _loaded := false


## Reads the file once (again with `force`). Unknown or out-of-range values fall back to the defaults.
static func load_settings(force := false) -> void:
	if _loaded and not force:
		return
	_loaded = true
	hud_scale = DEFAULTS.hud_scale
	master_volume = DEFAULTS.master_volume
	captions = DEFAULTS.captions
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	var scale = file.get_value(SECTION, "hud_scale", DEFAULTS.hud_scale)
	if (scale is float or scale is int) and HUD_SCALES.has(snappedf(float(scale), 0.01)):
		hud_scale = snappedf(float(scale), 0.01)
	var volume = file.get_value(SECTION, "master_volume", DEFAULTS.master_volume)
	if volume is float or volume is int:
		master_volume = clampf(float(volume), 0.0, 1.0)
	var on = file.get_value(SECTION, "captions", DEFAULTS.captions)
	if on is bool:
		captions = on


## Writes the current values. Returns false if the file could not be written.
static func save() -> bool:
	var file := ConfigFile.new()
	file.set_value(SECTION, "hud_scale", hud_scale)
	file.set_value(SECTION, "master_volume", master_volume)
	file.set_value(SECTION, "captions", captions)
	return file.save(path) == OK


## Loads (once) and applies the settings to the running game.
static func apply(tree: SceneTree) -> void:
	load_settings()
	if tree and tree.root:
		tree.root.content_scale_factor = hud_scale
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, master_volume <= 0.001)
		AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume, 0.001)))


static func set_hud_scale(tree: SceneTree, value: float) -> void:
	load_settings()
	var snapped := snappedf(value, 0.01)
	hud_scale = snapped if HUD_SCALES.has(snapped) else DEFAULTS.hud_scale
	apply(tree)
	save()


static func set_master_volume(tree: SceneTree, value: float) -> void:
	load_settings()
	master_volume = clampf(value, 0.0, 1.0)
	apply(tree)
	save()


static func set_captions(tree: SceneTree, on: bool) -> void:
	load_settings()
	captions = on
	apply(tree)
	save()


## Back to the defaults (tests), without touching the file.
static func reset_to_defaults() -> void:
	hud_scale = DEFAULTS.hud_scale
	master_volume = DEFAULTS.master_volume
	captions = DEFAULTS.captions
	_loaded = true
