extends "res://maps/isg_museum/tools/verify_blockout.gd"

func _run() -> void:
	level = load("res://maps/isg_museum/scenes/museum_editing.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(10)
	var player := level.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.position = Vector3(34,0,10.2)
	check(level.get_node("Interactables/Key").interact(player),"Collect K normally for stair carry fixture")
	player.position = Vector3(34.3,4.5,10)
	check(level.get_node("Interactables/Painting_T2").interact(player),"Pick up full T2 visual before stair traversal")
	for mirror in [false,true]:
		var points := [Vector3(7.4,0,28.25),Vector3(1.2,2.25,28.25),Vector3(1.2,2.25,25.75),Vector3(7.5,4.5,25.75)]
		if mirror:
			for i in points.size():
				points[i] = Vector3(36-points[i].x,points[i].y,points[i].z-24)
		player.position = points[0]
		player.velocity = Vector3.ZERO
		check(await walk(player,points.slice(1)) and player.is_carrying(),"Actual carry walks up stair "+("B" if mirror else "A"))
		points.reverse()
		check(await walk(player,points.slice(1)) and player.is_carrying(),"Actual carry walks down stair "+("B" if mirror else "A"))
	current_scene = null
	level.free()
	await process_frame
	print("Stair carry: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
