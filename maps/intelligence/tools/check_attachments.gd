extends SceneTree
## Inspect the real authoring geometry before batching, excluding each sign's
## own plate/struts. This catches unsupported signs rather than self-hits.
var level: Node3D
var failures: Array[String]=[]
var checks:=0
var surfaces: Array[Dictionary]=[]
var triangles: Dictionary={}
var materials: Dictionary={}

func _init() -> void: _run.call_deferred()

func _run() -> void:
	var shipped: Node3D=load("res://maps/intelligence/scenes/intelligence_k17.tscn").instantiate()
	level=Node3D.new()
	root.add_child(level)
	var region:=shipped.get_node("NavigationRegion3D").duplicate() as NavigationRegion3D
	region.enabled=false
	region.get_node("Sectors").free()
	level.add_child(region)
	preload("res://maps/intelligence/tools/k17_expansion_builder.gd").new().build(self,region)
	var art:=preload("res://maps/intelligence/tools/k17_art_builder.gd").new().build(region)
	level.add_child(art)
	shipped.free()
	for mesh in level.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree() or mesh.mesh==null: continue
		var id: int=mesh.mesh.get_instance_id()
		if not triangles.has(id): triangles[id]=mesh.mesh.generate_triangle_mesh()
		surfaces.append({"node":mesh,"triangles":triangles[id],"inverse":mesh.global_transform.affine_inverse(),"bounds":mesh.global_transform*mesh.get_aabb()})
	var signs:=0
	var pipes:=0
	var conduits:=0
	for node in level.find_children("*","Node3D",true,false):
		if node.has_meta("attachment_mode"):
			signs+=1
			_check_sign(node)
		for metadata in ["pipe_endpoints","conduit_endpoints","elbow_ports"]:
			if not node.has_meta(metadata): continue
			if metadata=="pipe_endpoints": pipes+=1
			elif metadata=="conduit_endpoints": conduits+=1
			for endpoint in node.get_meta(metadata):
				_expect(_connected(endpoint,node),"Connected %s endpoint %s on %s"%[metadata,endpoint,node.get_path()])
	_expect(signs>=50 and pipes>=26 and conduits>=20,"Whole compound attachments were examined")
	for failure in failures: printerr(failure)
	print("K17 ATTACHMENTS: %d signs, %d pipe modules, %d conduits; %d checks; %d failures"%[signs,pipes,conduits,checks,failures.size()])
	level.queue_free()
	for i in 40: await process_frame
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	quit(0 if failures.is_empty() else 1)

func _check_sign(sign: Node3D) -> void:
	var size: Vector2=sign.get_meta("attachment_size")
	var mode: String=sign.get_meta("attachment_mode")
	var anchor: float=sign.get_meta("attachment_anchor")
	for side in [-1.0,1.0]:
		var x: float=side*size.x*.32
		var backed:=false
		if mode=="wall":
			for y in [-.03,0.0,.03]:
				backed=backed or _surface_between(sign.to_global(Vector3(x,y,.03)),sign.to_global(Vector3(x,y,-anchor-.04)),sign)
		else:
			var p:=Vector3(x,anchor-sign.position.y,-.035)
			var direction:=Vector3.UP if mode=="ceiling" else Vector3.DOWN
			backed=_surface_between(sign.to_global(p-direction*.08),sign.to_global(p+direction*.08),sign)
		_expect(backed,"Sign %s has %s support on side %s: %s"%[sign.get_path(),mode,side,sign.position])

func _surface_between(a: Vector3,b: Vector3,exclude: Node) -> bool:
	for surface in surfaces:
		if exclude==surface.node or exclude.is_ancestor_of(surface.node): continue
		if not surface.bounds.grow(.005).intersects_segment(a,b): continue
		if not surface.triangles.intersect_segment(surface.inverse*a,surface.inverse*b).is_empty(): return true
	return false

func _connected(point: Vector3,exclude: Node) -> bool:
	for surface in surfaces:
		if exclude==surface.node or exclude.is_ancestor_of(surface.node): continue
		if surface.bounds.grow(.035).has_point(point): return true
	return false

func _expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

func _add(parent: Node,node: Node) -> void:
	parent.add_child(node,true)
	node.owner=level

func _group(parent: Node,title: String) -> Node3D:
	var node:=Node3D.new()
	node.name=title
	_add(parent,node)
	return node

func _shape(parent: Node,size: Vector3) -> void:
	var node:=CollisionShape3D.new()
	node.name="Shape"
	var shape:=BoxShape3D.new()
	shape.size=size
	node.shape=shape
	_add(parent,node)

func _box(parent: Node,title: String,p: Vector3,size: Vector3,colour: Color) -> StaticBody3D:
	var node:=StaticBody3D.new()
	node.name=title
	node.position=p
	_add(parent,node)
	_shape(node,size)
	_paint(node,"Mesh",Vector3.ZERO,size,colour)
	return node

func _paint(parent: Node,title: String,p: Vector3,size: Vector3,colour: Color) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.name=title
	node.position=p
	var mesh:=BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	if not materials.has(colour):
		var material:=StandardMaterial3D.new()
		material.albedo_color=colour
		materials[colour]=material
	node.material_override=materials[colour]
	_add(parent,node)
	return node
