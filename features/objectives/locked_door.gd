class_name LockedDoor
extends Interactable

## A door that stays locked: aiming at it names it as locked, and using it is refused with
## a reason (the HUD shows it, the audio director plays the locked rattle, as for an
## AccessDoor that refuses). No noise for the guards, nothing opens. The Expanded Library's
## front doors to the street, behind the player's spawn (2026-11-02).

## Emitted when the player tries the door, with the reason shown on the HUD.
signal rejected(reason: String)

## Name shown in the prompt, e.g. "Front doors".
@export var door_name := "Door"
## Shown after the name in the prompt.
@export var lock_text := "locked"
## Shown on the HUD when the player tries it.
@export var reason := "It's locked."

## Times the player tried it.
var tries := 0


func get_prompt(_by: Node) -> String:
	return "%s · %s" % [door_name, lock_text]


func _on_interact(_by: Node) -> bool:
	tries += 1
	rejected.emit(reason)
	return false
