class_name ReserveGap
extends Interactable

## One gap on the Study 4 reserve shelf (see ReserveShelf, its parent): looking at it
## shows what it takes, E puts the matching reserve book from the inventory into it.

## Which gap of the shelf this is (left to right).
@export var index := 0


func get_prompt(_by: Node) -> String:
	var shelf := get_parent() as ReserveShelf
	return shelf.gap_prompt(index) if shelf else prompt


func _on_interact(_by: Node) -> bool:
	var shelf := get_parent() as ReserveShelf
	return shelf != null and shelf.use_gap(index)
