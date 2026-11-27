extends Node
## Use the solid wall and roof sections authored by K17's sector builder.

const BOX_INSET := Vector3.ONE * 0.08

var _viewport: Viewport
var _previous_setting: bool


func _enter_tree() -> void:
	_viewport = get_viewport()
	_previous_setting = _viewport.use_occlusion_culling
	_viewport.use_occlusion_culling = true


func _ready() -> void:
	for sector in $"../NavigationRegion3D/Sectors".get_children():
		if sector.name == &"perimeter":
			continue
		for body in sector.get_children():
			if not body is StaticBody3D or not _is_solid_section(body.name):
				continue
			var collider := body.get_node_or_null("Shape") as CollisionShape3D
			if collider == null or collider.disabled:
				continue
			var box := collider.shape as BoxShape3D
			if box == null or box.size[box.size.min_axis_index()] < 0.12 or box.size.length() < 3.0:
				continue

			# Leave space inside each face and keep the builder's door and window gaps.
			var occluder := BoxOccluder3D.new()
			occluder.size = box.size - BOX_INSET
			var instance := OccluderInstance3D.new()
			instance.occluder = occluder
			collider.add_child(instance)


func _exit_tree() -> void:
	_viewport.use_occlusion_culling = _previous_setting
	_viewport = null


func _is_solid_section(section_name: String) -> bool:
	return section_name in ["Wall", "Roof"] \
		or section_name.begins_with("Wall") and section_name.trim_prefix("Wall").is_valid_int() \
		or section_name.begins_with("Roof") and section_name.trim_prefix("Roof").is_valid_int()
