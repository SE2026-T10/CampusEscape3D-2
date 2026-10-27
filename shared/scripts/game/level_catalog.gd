class_name LevelCatalog
extends RefCounted

## The maps the main menu offers, in menu order. Data only, not a manager:
## each map is a self-contained level scene with its own systems, and
## GameFlow restarts whichever level it belongs to, so nothing else needs this
## list. To add a map, add an entry here.

const TUTORIAL := &"library_tutorial"
const EXPANDED := &"expanded_library"
const INTELLIGENCE := &"intelligence_k17"

const LEVELS := [
	{"id": TUTORIAL, "title": "Library Tutorial", "scene": "res://maps/tutorial/scenes/library_graybox.tscn",
		"description": "The original library: one floor, one access card. Learn the ropes."},
	{"id": EXPANDED, "title": "Expanded Library", "scene": "res://maps/library/scenes/expanded_library.tscn",
		"description": "Two floors and a basement, seven guards, puzzles and three ways out. Retrieve the rare manuscript."},
	{"id": INTELLIGENCE, "title": "K17 — 120 giây cuối", "scene": "res://maps/intelligence/scenes/intelligence_k17.tscn",
		"description": "Thâm nhập cơ sở tình báo, lấy Mật lệnh 04 rồi rút lui trong 120 giây.",
		"test_scene": "res://maps/intelligence/scenes/intelligence_k17_test.tscn",
		"test_title": "K17 — Test map không lính gác",
		"test_description": "Tự do kiểm tra đường đi và tương tác. Cảm biến, checkpoint và đồng hồ vẫn hoạt động."},
]


## The entry for `id`, or {} if there is none.
static func get_level(id: StringName) -> Dictionary:
	for level in LEVELS:
		if level.id == id:
			return level
	return {}


## The scene path of `id`, or "" if there is none.
static func scene_of(id: StringName) -> String:
	return get_level(id).get("scene", "")


## An optional playable test variant of a map; empty for maps without one.
static func test_scene_of(id: StringName) -> String:
	return get_level(id).get("test_scene", "")


## The id of the map whose scene is `path`, or &"" if it is not in the catalog.
static func id_of_scene(path: String) -> StringName:
	for level in LEVELS:
		if level.scene == path:
			return level.id
	return &""


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for level in LEVELS:
		out.append(level.id)
	return out
