extends Area3D
## A positional room cue, played once per scene.
var rang := false


func _ready() -> void:
	body_entered.connect(_on_player_approached)


func _on_player_approached(body: Node3D) -> void:
	if rang or not body.is_in_group("player"):
		return
	rang = true
	$Ring.play()
