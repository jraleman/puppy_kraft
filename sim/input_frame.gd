extends RefCounted

## Edges survive render frames that do not yet have enough time for a fixed tick.

var move := 0.0
var aim := Vector2i.ZERO
var jump_pressed := false
var dig := false
var dig_pressed := false
var place_pressed := false
var back_wall := false
var wheel_delta := 0
var mouse_aim := false
var mouse_cell := Vector2i.ZERO


func without_edges() -> void:
	jump_pressed = false
	dig_pressed = false
	place_pressed = false
	wheel_delta = 0
