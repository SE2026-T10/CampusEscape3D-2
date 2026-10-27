extends RefCounted
## Explicit visual fixings. Anchor heights are in the sign parent's space.
static func mount(board: Node3D,size: Vector2,mode: String,anchor:=.08) -> void:
	board.set_meta("attachment_mode",mode)
	board.set_meta("attachment_size",size)
	board.set_meta("attachment_anchor",anchor)
	# Reuse the backplate material so fixings batch with existing geometry.
	var material: Material=(board.get_child(0) as MeshInstance3D).material_override
	for side in [-1.0,1.0]:
		var x: float=side*size.x*.32
		if mode=="wall":
			_box(board,"SignStandoff",Vector3(x,0,-anchor*.5),Vector3(.075,.08,anchor+.025),material)
		elif mode=="ceiling":
			var top: float=anchor-board.position.y
			var bottom: float=size.y*.45
			_box(board,"SignHanger",Vector3(x,(top+bottom)*.5,-.035),Vector3(.045,top-bottom+.02,.08),material)
			_box(board,"SignCeilingAnchor",Vector3(x,top,-.035),Vector3(.18,.04,.18),material)
		elif mode=="post":
			var bottom: float=anchor-board.position.y
			var top: float=size.y*.4
			_box(board,"SignPost",Vector3(x,(top+bottom)*.5,-.035),Vector3(.09,top-bottom+.02,.1),material)
			_box(board,"SignFoot",Vector3(x,bottom+.025,-.035),Vector3(.36,.05,.32),material)

static func _box(parent: Node3D,title: String,p: Vector3,size: Vector3,material: Material) -> void:
	var mesh:=MeshInstance3D.new()
	mesh.name=title
	mesh.position=p
	var box:=BoxMesh.new()
	box.size=size
	box.add_uv2=true
	mesh.mesh=box
	mesh.material_override=material
	mesh.gi_mode=GeometryInstance3D.GI_MODE_STATIC
	parent.add_child(mesh,true)
	mesh.owner=parent.owner
