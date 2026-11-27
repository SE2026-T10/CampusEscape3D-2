extends Node3D

func _ready() -> void:
	var ui := preload("res://maps/isg_museum/scripts/service_ui.gd").new()
	ui.name = "ServiceUi"
	add_child(ui)


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var ui := get_node_or_null("ServiceUi")
	var npc := get_node("Receptionist") as Node3D
	var watching: bool = ui != null and ui.cooldown_left > 0 and player != null \
		and player.global_position.distance_to(npc.global_position) < 5.0
	get_node("Receptionist/WatchNotice").visible = watching
	npc.get_node("Presentation").set_watching(player,watching)
