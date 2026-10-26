class_name MapHudProvider
extends Node

## Optional, scene-local bridge from a map's own rules to the shared HUD.
## Add one subclass to a map to supply its status and contextual exit hints.
## Maps without a provider keep the objective/interaction HUD as before.

func _ready() -> void:
	add_to_group("map_hud_provider")


static func find_for(node: Node) -> MapHudProvider:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("map_hud_provider") as MapHudProvider


func get_status_lines() -> Array[String]:
	return []


## Return BBCode for this map's extra status panel, without checkpoint text.
func get_status_bbcode(_accent: Color, _done: Color, _todo: Color) -> String:
	return "\n".join(get_status_lines())


## An empty string leaves the exit's own configured refusal message in use.
func get_exit_hint(_exit: Node) -> String:
	return ""
