extends Node2D

## Draws the level map for tools/level_report.gd from its measured data:
## floors, walls and cover, the watched/unwatched floor, patrol routes with
## their waits, the player routes and the key points. North (−z) is up.

const BG := Color(0.07, 0.08, 0.1)
const FLOOR := Color(0.2, 0.22, 0.26)
const WALL := Color(0.75, 0.78, 0.82)
const FULL_COVER := Color(0.55, 0.38, 0.22)
const LOW_COVER := Color(0.85, 0.7, 0.42)
const WATCHED := Color(0.9, 0.2, 0.15, 0.32)
const CROUCH_SAFE := Color(0.25, 0.55, 1.0, 0.4)
const GUARD_COLOURS := [Color(1.0, 0.45, 0.1), Color(0.95, 0.25, 0.7), Color(1.0, 0.85, 0.15), Color(0.4, 0.9, 0.9)]
const ROUTE_SHORT := Color(0.2, 0.95, 0.95)
const ROUTE_ALT := Color(0.55, 0.75, 1.0)
const ROUTE_EXIT := Color(0.35, 1.0, 0.45)
const STEALTH := Color(1, 1, 1, 0.9)
const STEALTH_EXIT := Color(0.75, 1.0, 0.8, 0.9)

var data: Dictionary
var canvas_size := Vector2(1500, 1200)

var _scale := 20.0
var _offset := Vector2.ZERO
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	# Fit the floors into the left part of the canvas, leaving room for the legend.
	var bounds := Rect2()
	var first := true
	for f in data.floors:
		var r := Rect2(f.rect[0], f.rect[1], f.rect[2], f.rect[3])
		bounds = r if first else bounds.merge(r)
		first = false
	var area := Vector2(canvas_size.x - 360, canvas_size.y - 90)
	_scale = minf(area.x / bounds.size.x, area.y / bounds.size.y)
	_offset = Vector2(30, 70) - bounds.position * _scale
	queue_redraw()


func _p(v) -> Vector2:
	return Vector2(v[0], v[1]) * _scale + _offset


func _rect(r: Array) -> Rect2:
	return Rect2(Vector2(r[0], r[1]) * _scale + _offset, Vector2(r[2], r[3]) * _scale)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, canvas_size), BG)
	for f in data.floors:
		draw_rect(_rect(f.rect), FLOOR)
	# Exposure heat: transparent (safe) → yellow → red (watched most of the loop).
	# Blue: seen standing but never crouched (low cover works there).
	var half := Vector2.ONE * 0.5
	for s in data.samples:
		var r := Rect2((Vector2(s.x, s.z) - half) * _scale + _offset, Vector2.ONE * _scale)
		if s.standing <= 0.0:
			continue
		if s.crouched <= 0.0 and s.standing > 0.0:
			draw_rect(r, CROUCH_SAFE)
			continue
		var e: float = clampf(s.standing / 0.4, 0.0, 1.0)
		var colour := Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.15, 0.1), e)
		colour.a = 0.18 + 0.5 * e
		draw_rect(r, colour)
	for o in data.obstacles:
		var colour := WALL if o.kind == "wall" else (FULL_COVER if o.kind == "full" else LOW_COVER)
		draw_rect(_rect(o.rect), colour)
	# Player routes.
	_route("spawn_to_card_east_loop", ROUTE_ALT, 2.0)
	_route("card_to_exit_via_main_room", ROUTE_ALT, 2.0)
	_route("spawn_to_card_shortest", ROUTE_SHORT, 2.0)
	_route("card_to_exit_shortest", ROUTE_EXIT, 2.0)
	_route("stealth_spawn_to_card", STEALTH, 4.5)
	_route("stealth_card_to_exit", STEALTH_EXIT, 4.5)
	# Patrols.
	for i in data.patrol_paths.size():
		var p: Dictionary = data.patrol_paths[i]
		var colour: Color = GUARD_COLOURS[i % GUARD_COLOURS.size()]
		var line := PackedVector2Array(p.path.map(_p))
		if line.size() > 1:
			_dashed(line, colour, 3.0)
		for j in p.points.size():
			var at := _p(p.points[j])
			draw_circle(at, 7, colour)
			_text(at + Vector2(9, -6), "%s%d %ss" % [p.name.trim_prefix("Guard").left(1), j + 1, str(int(p.waits[j]))], 14, colour)
		_text(_p(p.points[0]) + Vector2(9, 12), p.name, 15, colour)
	# Key points.
	for k in data.key_points:
		var at := _p(data.key_points[k])
		if k == "spawn":
			_marker(at, "START", Color(1, 1, 1))
		elif k == "card":
			_marker(at, "CARD", Color(1.0, 0.82, 0.2))
		elif k == "exit_door":
			_marker(at, "EXIT", ROUTE_EXIT)
		elif k.begins_with("checkpoint"):
			_marker(at, "CP " + k.trim_prefix("checkpoint_").replace("_", " "), Color(0.4, 1.0, 0.6))
		elif k.begins_with("hiding"):
			draw_arc(at, 6, 0, TAU, 16, Color(0.6, 0.8, 1.0), 2.0)
	_legend()


func _route(name: String, colour: Color, width: float) -> void:
	if not data.routes.has(name):
		return
	var line := PackedVector2Array(data.routes[name].path.map(_p))
	if line.size() > 1:
		draw_polyline(line, colour, width, true)


func _dashed(line: PackedVector2Array, colour: Color, width: float) -> void:
	for i in range(1, line.size()):
		draw_dashed_line(line[i - 1], line[i], colour, width, 10.0)


func _marker(at: Vector2, label: String, colour: Color) -> void:
	draw_circle(at, 9, Color.BLACK)
	draw_circle(at, 7, colour)
	_text(at + Vector2(11, 5), label, 15, colour)


func _text(at: Vector2, text: String, size: int, colour: Color) -> void:
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


func _legend() -> void:
	var t: Dictionary = data.totals
	_text(Vector2(30, 40), "Campus Escape 3D — library level %s" % data.version, 26, Color.WHITE)
	var x := canvas_size.x - 330
	var y := 90.0
	var rows := [
		[Color(1.0, 0.9, 0.2, 0.25), "seen briefly (low exposure)"],
		[Color(1.0, 0.15, 0.1, 0.68), "watched ≥ 40% of the loop"],
		[CROUCH_SAFE, "seen standing, hidden crouched"],
		[FLOOR, "never seen"],
		[WALL, "walls"], [FULL_COVER, "full-height cover"], [LOW_COVER, "low cover (crouch)"],
		[ROUTE_SHORT, "route: start → card (shortest)"], [ROUTE_EXIT, "route: card → exit (shortest)"],
		[ROUTE_ALT, "alternative routes"],
		[STEALTH, "safest route: start → card"], [STEALTH_EXIT, "safest route: card → exit"],
	]
	for row in rows:
		draw_rect(Rect2(x, y - 13, 22, 16), row[0])
		_text(Vector2(x + 32, y), row[1], 15, Color(0.9, 0.9, 0.9))
		y += 26
	y += 6
	_text(Vector2(x, y), "dashed: guard patrols (point, wait)", 15, Color(0.9, 0.9, 0.9))
	y += 40
	var lines := [
		"Walkable samples: %d" % t.walkable,
		"Mean exposure: %.1f%% (crouched %.1f%%)" % [t.exposure_pct, t.exposure_crouched_pct],
		"Safe floor (< 5%%): %.0f%%" % t.safe_pct,
		"Near cover: %.0f%%" % t.near_cover_pct,
		"Cover props: %d (low %d)" % [t.cover_props, t.low_cover_props],
	]
	var short_names := {"spawn_to_card_shortest": "start→card", "spawn_to_card_east_loop": "start→card (east)",
		"card_to_exit_shortest": "card→exit", "card_to_exit_via_main_room": "card→exit (main room)",
		"stealth_spawn_to_card": "safest start→card", "stealth_spawn_to_card_east": "safest start→card (east)",
		"stealth_card_to_exit": "safest card→exit"}
	lines.append("Routes: length, mean / peak exposure")
	for name in data.routes:
		var r: Dictionary = data.routes[name]
		lines.append("  %s: %.0f m, %.0f%% / %.0f%%" % [short_names.get(name, name), r.length_m, r.mean_exposure_pct, r.peak_exposure_pct])
	lines.append("Patrol loops")
	for p in data.patrols:
		lines.append("  %s: %.0f m, %.0f s" % [p.name, p.length_m, p.loop_seconds])
	for line in lines:
		_text(Vector2(x, y), line, 14, Color(0.85, 0.88, 0.92))
		y += 22
	_text(Vector2(30, canvas_size.y - 20), "Exposure = share of patrol-loop time a guard's 90° / 14 m view cone has clear sight of the spot (head 1.5 m standing). North is up.", 14, Color(0.7, 0.72, 0.76))
