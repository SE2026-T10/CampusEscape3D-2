extends SceneTree

## Development tool: writes a sorted text "fingerprint" of everything in the
## Expanded Library that affects play: every collision object (path, class,
## layers, global transform) with its shapes, every guard (position, facing,
## tuning) and every patrol point. Two builds with the same fingerprint have
## the same collision, sight blockers, triggers, guards and routes; diff the
## files to compare a visual pass against the build before it.
##
##   godot --headless --path . --script res://maps/library/tools/collision_fingerprint.gd -- --out=/tmp/fp.txt

const SCENE := "res://maps/library/scenes/expanded_library.tscn"

var _lines: PackedStringArray = []
var _root: Node


func _init() -> void:
	var out := "user://collision_fingerprint.txt"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	_root = (load(SCENE) as PackedScene).instantiate()
	_walk(_root)
	_lines.sort()
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	print("Fingerprint: %d lines -> %s" % [_lines.size(), out])
	_root.free()
	quit(0)


func _walk(node: Node) -> void:
	var path := String(_root.get_path_to(node))
	if node is CollisionObject3D:
		var c := node as CollisionObject3D
		_lines.append("body %s %s layer=%d mask=%d %s" % [path, c.get_class(), c.collision_layer, c.collision_mask, _xf(_global(c))])
	elif node is CollisionShape3D:
		var s := node as CollisionShape3D
		_lines.append("shape %s %s %s disabled=%s" % [path, _xf(s.transform), _shape(s.shape), s.disabled])
	if node is Guard:
		var v: Node = node.get_node("Vision")
		_lines.append("guard %s %s chase=%.3f vision=%.2f/%.2f route=%s" % [path, _xf(_global(node)), node.get("chase_speed"),
			v.get("min_rise_rate"), v.get("max_rise_rate"), _root.get_path_to(node.get("patrol_route")) if node.get("patrol_route") else "-"])
	if node.get_script() and String((node.get_script() as Script).resource_path).ends_with("patrol_point.gd"):
		_lines.append("point %s %s wait=%.2f" % [path, _v((node as Node3D).position), node.get("wait_time")])
	for child in node.get_children():
		_walk(child)


## Global transform without the tree (the scene is not added to it).
func _global(node: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n and n != _root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _xf(t: Transform3D) -> String:
	var b := t.basis
	return "o=%s x=%s y=%s z=%s" % [_v(t.origin), _v(b.x), _v(b.y), _v(b.z)]


func _v(v: Vector3) -> String:
	return "(%.4f,%.4f,%.4f)" % [v.x, v.y, v.z]


func _shape(shape: Shape3D) -> String:
	if shape is BoxShape3D:
		return "box%s" % _v((shape as BoxShape3D).size)
	if shape is CapsuleShape3D:
		return "capsule(r=%.3f,h=%.3f)" % [shape.radius, shape.height]
	if shape is CylinderShape3D:
		return "cylinder(r=%.3f,h=%.3f)" % [shape.radius, shape.height]
	if shape is SphereShape3D:
		return "sphere(r=%.3f)" % shape.radius
	return shape.get_class() if shape else "none"
