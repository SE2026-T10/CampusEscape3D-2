class_name GuardPerception
extends RefCounted

## What a guard legitimately perceives this frame. The state machine decides
## only from this snapshot, never from the player node itself.

## The player is in direct, unobstructed view right now.
var can_see_player := false
## Visual detection is confirmed: in view AND the detection meter is at the alert threshold.
var confirmed_sighting := false
## Suspicious visual evidence: meter at or above the suspicious threshold and the
## player was seen within the evidence memory window.
var suspicious_sighting := false
## Where the player was last seen (valid when has_sighting_position).
var sighting_position := Vector3.ZERO
var has_sighting_position := false
## A noise was reported since the last frame (hearing comes in a later phase).
var noise_heard := false
var noise_position := Vector3.ZERO


static func make(can_see := false, confirmed := false, suspicious := false, position := Vector3.ZERO,
		noise := false, noise_at := Vector3.ZERO) -> GuardPerception:
	var p := GuardPerception.new()
	p.can_see_player = can_see
	p.confirmed_sighting = confirmed
	p.suspicious_sighting = suspicious
	p.sighting_position = position
	p.has_sighting_position = can_see or confirmed or suspicious
	p.noise_heard = noise
	p.noise_position = noise_at
	return p
