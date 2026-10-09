extends SceneTree

## Development tool: draws the Expanded Library's top-down design plans from
## the layout data (tools/expanded/expanded_layout.gd), one per floor:
## zones and rooms, walls and openings (doors, gates, shortcut, exit), stairs,
## cover, planned patrol loops, intended player routes, objectives, hiding
## spots, spawn and exit. North (−z) is up.
##
##   godot --path . --script res://tools/expanded/draw_layout.gd -- --out=docs/expanded/v0
##
## Needs a display (a virtual one works: xvfb-run). Writes layout_ground.png
## and layout_upper.png.

const Layout := preload("res://tools/expanded/expanded_layout.gd")
const SIZE := Vector2i(1900, 1300)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "docs/expanded/" + Layout.VERSION
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		push_error("draw_layout needs a display (run without --headless, e.g. under xvfb-run).")
		quit(1)
		return
	var dir := ProjectSettings.globalize_path("res://" + out)
	DirAccess.make_dir_recursive_absolute(dir)
	for floor_name in ["ground", "upper"]:
		var viewport := SubViewport.new()
		viewport.size = SIZE
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var canvas := MapCanvas.new()
		canvas.floor_name = floor_name
		viewport.add_child(canvas)
		root.add_child(viewport)
		for i in 4:
			await process_frame
		var path := dir.path_join("layout_%s.png" % floor_name)
		viewport.get_texture().get_image().save_png(path)
		print("Layout plan → %s" % path)
		viewport.queue_free()
		await process_frame
	quit(0)


class MapCanvas extends Node2D:
	const BG := Color(0.07, 0.08, 0.1)
	const WALL := Color(0.86, 0.88, 0.9)
	const OPENING_COLOURS := {
		"door": Color(0.6, 0.62, 0.66), "arch": Color(0.6, 0.62, 0.66), "entrance": Color(0.35, 0.65, 1.0),
		"gate": Color(1.0, 0.25, 0.2), "shortcut": Color(1.0, 0.75, 0.15), "exit": Color(0.3, 1.0, 0.45),
		"stair": Color(0.45, 0.7, 1.0),
	}
	const PATROL_COLOURS := [Color(1.0, 0.45, 0.1), Color(0.95, 0.25, 0.7), Color(1.0, 0.85, 0.15),
		Color(0.4, 0.9, 0.9), Color(0.6, 1.0, 0.4), Color(0.7, 0.6, 1.0), Color(1.0, 0.5, 0.5)]

	var floor_name := "ground"
	var _scale := 17.0
	var _offset := Vector2.ZERO
	var _font: Font

	func _ready() -> void:
		_font = ThemeDB.fallback_font
		var bounds := Rect2(-37, -29, 74, 64)
		var area := Vector2(SIZE.x - 630, SIZE.y - 110)
		_scale = minf(area.x / bounds.size.x, area.y / bounds.size.y)
		_offset = Vector2(30, 80) - bounds.position * _scale
		queue_redraw()

	func _p(x: float, z: float) -> Vector2:
		return Vector2(x, z) * _scale + _offset

	func _r(r: Array) -> Rect2:
		return Rect2(_p(r[0], r[1]), Vector2(r[2] - r[0], r[3] - r[1]) * _scale)

	func _on_floor(y: float) -> bool:
		return (y > Layout.UPPER_Y / 2.0) == (floor_name == "upper")

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE)), BG)
		var upper := floor_name == "upper"
		_text(Vector2(30, 40), "Expanded Library — %s floor plan (layout %s)" % ["UPPER (y = 4.5 m)" if upper else "GROUND (y = 0)", Layout.VERSION], 26, Color.WHITE)
		# The other floor, faintly, for orientation.
		for f in Layout.FLOORS:
			if (f.floor == "upper") != upper:
				draw_rect(_r(f.rect), Color(1, 1, 1, 0.05))
				if not upper:
					_dashed_rect(_r(f.rect), Color(0.7, 0.7, 1.0, 0.35))
		# Zones and rooms on this floor.
		for z in Layout.ZONES:
			if (z.floor == "upper") != upper:
				continue
			for r in z.rects:
				var c: Color = z.colour
				c.a = 0.32
				draw_rect(_r(r), c)
			for a in z.areas:
				var rr := _r(a.rect)
				draw_rect(rr, Color(z.colour, 0.6), false, 1.0)
				var label := "%s · %s" % [z.id, a.name]
				var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				_text(Vector2(rr.get_center().x - w / 2.0, rr.position.y + rr.size.y * 0.5 + 5), label, 13, z.colour.lightened(0.5))
		# Cover.
		for c in Layout.COVER:
			if (c.floor == "upper") != upper:
				continue
			var colour := Color(0.62, 0.42, 0.26) if c.h >= 1.8 else Color(0.85, 0.72, 0.45)
			for r in c.rects:
				draw_rect(_r(r), colour)
		# Stairs (on both plans).
		for s in Layout.STAIRS:
			var rr := _r([s.x0, minf(s.z_low, s.z_high), s.x1, maxf(s.z_low, s.z_high)])
			draw_rect(rr, Color(0.3, 0.5, 0.85, 0.55))
			draw_rect(rr, Color(0.55, 0.75, 1.0), false, 2.0)
			var xc: float = (s.x0 + s.x1) / 2.0
			_arrow(_p(xc, s.z_low - signf(s.z_high - s.z_low) * -0.5), _p(xc, s.z_high + signf(s.z_high - s.z_low) * 0.8), Color(0.75, 0.88, 1.0))
			_text(rr.position + Vector2(rr.size.x + 4, rr.size.y / 2.0), "%s up" % s.id, 15, Color(0.75, 0.88, 1.0))
		# Walls and openings on this floor.
		for wall in Layout.WALLS:
			if (wall.floor == "upper") != upper:
				continue
			var railing: bool = wall.get("kind", "wall") == "railing"
			_wall(wall, railing)
		# Patrol loops.
		for i in Layout.PATROLS.size():
			var p: Dictionary = Layout.PATROLS[i]
			if not _on_floor(p.y):
				continue
			var colour: Color = PATROL_COLOURS[i % PATROL_COLOURS.size()]
			var pts: Array = p.points
			for k in pts.size():
				var a: Vector2 = _p(pts[k][0], pts[k][1])
				var b: Vector2 = _p(pts[(k + 1) % pts.size()][0], pts[(k + 1) % pts.size()][1])
				_dashed_line(a, b, colour, 2.5)
				draw_circle(a, 4.5, colour)
			_text(_p(pts[0][0], pts[0][1]) + Vector2(6, -6), p.id, 15, colour)
		# Player routes: segments on this floor solid, floor changes dotted.
		for route in Layout.ROUTES:
			var pts: Array = route.points
			for k in pts.size() - 1:
				var a: Vector3 = pts[k]
				var b: Vector3 = pts[k + 1]
				var on_a := _on_floor(a.y)
				var on_b := _on_floor(b.y)
				if on_a and on_b:
					draw_line(_p(a.x, a.z), _p(b.x, b.z), route.colour, 3.0)
				elif on_a or on_b:
					_dashed_line(_p(a.x, a.z), _p(b.x, b.z), Color(route.colour, 0.7), 2.0)
		# Hiding spots, objectives, spawn, exit.
		for h in Layout.HIDING:
			if _on_floor(h.pos.y):
				var c := _p(h.pos.x, h.pos.z)
				draw_circle(c, 7, Color(0.3, 0.55, 1.0))
				_text(c + Vector2(-4, 5), "H", 13, Color.WHITE)
		for i in Layout.OBJECTIVES.size():
			var o: Dictionary = Layout.OBJECTIVES[i]
			if _on_floor(o.pos.y):
				var c := _p(o.pos.x, o.pos.z)
				draw_circle(c, 12, Color(1.0, 0.85, 0.15))
				_text(c + Vector2(-10, 5), "O%d" % (i + 1), 14, Color.BLACK)
				_text(c + Vector2(15, 5), o.title, 14, Color(1.0, 0.92, 0.5))
		if not upper:
			var s := _p(Layout.SPAWN.x, Layout.SPAWN.z)
			draw_colored_polygon(PackedVector2Array([s + Vector2(0, -12), s + Vector2(10, 8), s + Vector2(-10, 8)]), Color(0.3, 1.0, 0.45))
			_text(s + Vector2(14, 6), "Spawn", 14, Color(0.6, 1.0, 0.7))
		# Gates: labels next to the openings.
		for g in Layout.GATES:
			var found := Layout.find_opening(g.opening)
			if found.is_empty() or (found.wall.floor == "upper") != upper:
				continue
			var c := _p(found.centre.x, found.centre.z)
			_text(c + Vector2(8, -8), "%s — %s" % [String(g.opening).get_slice(" ", String(g.opening).get_slice_count(" ") - 1), g.needs], 13,
				OPENING_COLOURS[found.opening.type].lightened(0.2))
		_legend()
		_scale_bar()

	func _wall(wall: Dictionary, railing: bool) -> void:
		var along_x: bool = wall.a[1] == wall.b[1]
		var a := _p(wall.a[0], wall.a[1])
		var b := _p(wall.b[0], wall.b[1])
		var openings: Array = wall.get("openings", [])
		# Draw the solid parts.
		var lo: float = minf(wall.a[0], wall.b[0]) if along_x else minf(wall.a[1], wall.b[1])
		var hi: float = maxf(wall.a[0], wall.b[0]) if along_x else maxf(wall.a[1], wall.b[1])
		var cuts := []
		for o in openings:
			cuts.append([o.at - o.width / 2.0, o.at + o.width / 2.0, o])
		cuts.sort_custom(func(p, q): return p[0] < q[0])
		var pos := lo
		var fixed: float = wall.a[1] if along_x else wall.a[0]
		var width := 2.0 if railing else 4.0
		var colour := Color(0.75, 0.85, 1.0) if railing else WALL
		for c in cuts + [[hi, hi, null]]:
			if c[0] > pos:
				var p0 := _p(pos, fixed) if along_x else _p(fixed, pos)
				var p1 := _p(c[0], fixed) if along_x else _p(fixed, c[0])
				if railing:
					_dashed_line(p0, p1, colour, width)
				else:
					draw_line(p0, p1, colour, width)
			pos = maxf(pos, c[1])
			if c[2] != null:
				var o: Dictionary = c[2]
				var q0 := _p(c[0], fixed) if along_x else _p(fixed, c[0])
				var q1 := _p(c[1], fixed) if along_x else _p(fixed, c[1])
				var oc: Color = OPENING_COLOURS.get(o.type, Color.GRAY)
				if o.type in ["gate", "shortcut", "exit", "entrance"]:
					draw_line(q0, q1, oc, 7.0 if o.type != "exit" else 9.0)
				else:
					draw_line(q0, q1, Color(oc, 0.5), 1.5)

	func _legend() -> void:
		var x := SIZE.x - 390
		var y := 100
		_text(Vector2(x, y), "Legend", 20, Color.WHITE)
		y += 30
		var items := [
			["line", WALL, "Wall (ground 4.2 m / upper 3.5 m)"], ["dash", Color(0.75, 0.85, 1.0), "Railing 1.1 m (balcony edge)"],
			["thick", OPENING_COLOURS.gate, "Progression gate (planned lock)"], ["thick", OPENING_COLOURS.shortcut, "Shortcut (one-way, planned)"],
			["thick", OPENING_COLOURS.exit, "Exit door"], ["thick", OPENING_COLOURS.entrance, "Main entrance"],
			["box", Color(0.3, 0.5, 0.85), "Stair ramp (arrow = up, 24°)"], ["box", Color(0.62, 0.42, 0.26), "Full cover (shelf / rack ≥ 2 m)"],
			["box", Color(0.85, 0.72, 0.45), "Low cover (table / desk / crate)"], ["dot", Color(1.0, 0.85, 0.15), "Mandatory objective O1–O5"],
			["dot", Color(0.3, 0.55, 1.0), "Hiding opportunity (H)"], ["dash", PATROL_COLOURS[0], "Planned patrol loop P1–P7"],
		]
		for item in items:
			var at := Vector2(x, y)
			match item[0]:
				"line":
					draw_line(at + Vector2(0, -5), at + Vector2(30, -5), item[1], 4.0)
				"dash":
					_dashed_line(at + Vector2(0, -5), at + Vector2(30, -5), item[1], 2.5)
				"thick":
					draw_line(at + Vector2(0, -5), at + Vector2(30, -5), item[1], 7.0)
				"box":
					draw_rect(Rect2(at + Vector2(0, -12), Vector2(30, 14)), item[1])
				"dot":
					draw_circle(at + Vector2(15, -5), 8, item[1])
			_text(at + Vector2(42, 0), item[2], 15, Color(0.88, 0.9, 0.92))
			y += 26
		y += 12
		_text(Vector2(x, y), "Player routes", 18, Color.WHITE)
		y += 26
		for route in Layout.ROUTES:
			draw_line(Vector2(x, y - 5), Vector2(x + 30, y - 5), route.colour, 3.0)
			_text(Vector2(x + 42, y), route.name, 13, Color(0.88, 0.9, 0.92))
			y += 22
		y += 8
		_text(Vector2(x, y), "dotted = continues on the other floor", 13, Color(0.7, 0.72, 0.75))
		y += 20
		_text(Vector2(x, y), "Routes and loops are drawn as straight lines between", 13, Color(0.7, 0.72, 0.75))
		y += 18
		_text(Vector2(x, y), "waypoints; walking follows the doorways (navmesh).", 13, Color(0.7, 0.72, 0.75))
		y += 30
		_text(Vector2(x, y), "Zones", 18, Color.WHITE)
		y += 26
		for z in Layout.ZONES:
			draw_rect(Rect2(Vector2(x, y - 12), Vector2(30, 14)), Color(z.colour, 0.8))
			_text(Vector2(x + 42, y), "%s  %s (%s)" % [z.id, z.name, z.floor], 14, Color(0.88, 0.9, 0.92))
			y += 22

	func _scale_bar() -> void:
		var a := Vector2(40, SIZE.y - 30)
		draw_line(a, a + Vector2(10 * _scale, 0), Color.WHITE, 3.0)
		_text(a + Vector2(10 * _scale + 8, 5), "10 m      N ↑", 15, Color.WHITE)

	func _arrow(a: Vector2, b: Vector2, colour: Color) -> void:
		draw_line(a, b, colour, 2.5)
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([b, b - d * 14 + n * 7, b - d * 14 - n * 7]), colour)

	func _dashed_line(a: Vector2, b: Vector2, colour: Color, width: float) -> void:
		var length := a.distance_to(b)
		var d := (b - a) / maxf(length, 0.001)
		var s := 0.0
		while s < length:
			draw_line(a + d * s, a + d * minf(s + 9.0, length), colour, width)
			s += 15.0

	func _dashed_rect(r: Rect2, colour: Color) -> void:
		_dashed_line(r.position, r.position + Vector2(r.size.x, 0), colour, 1.5)
		_dashed_line(r.position + Vector2(r.size.x, 0), r.end, colour, 1.5)
		_dashed_line(r.end, r.position + Vector2(0, r.size.y), colour, 1.5)
		_dashed_line(r.position + Vector2(0, r.size.y), r.position, colour, 1.5)

	func _text(at: Vector2, text: String, size: int, colour: Color) -> void:
		draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
