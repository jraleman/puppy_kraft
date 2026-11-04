extends RefCounted

## Only this adapter polls keys; held buttons produce one edge after release.

const Options = preload("res://games/puppy_kraft/puppy_kraft_options.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")

var _jump_down := false
var _dig_down := false
var _place_down := false
var _previous_down := false
var _next_down := false


func sample(mouse_cell: Vector2i, mouse_aim: bool, mouse_dig: bool,
	mouse_place: bool, wheel: int = 0) -> Frame:
	var frame := Frame.new()
	frame.move = Input.get_axis(Options.LEFT, Options.RIGHT)
	frame.aim = Vector2i(
		signi(int(Input.is_action_pressed(Options.RIGHT)) - int(Input.is_action_pressed(Options.LEFT))),
		int(Input.is_action_pressed(Options.DOWN)) - int(Input.is_action_pressed(Options.UP))
	)
	var jump := Input.is_action_pressed(Options.JUMP)
	var dig := Input.is_action_pressed(Options.DIG) or mouse_dig
	var place := Input.is_action_pressed(Options.PLACE) or mouse_place
	var previous := Input.is_action_pressed(Options.WHEEL_PREV)
	var next := Input.is_action_pressed(Options.WHEEL_NEXT)
	frame.jump_pressed = jump and not _jump_down
	frame.dig = dig
	frame.dig_pressed = dig and not _dig_down
	frame.place_pressed = place and not _place_down
	frame.back_wall = Input.is_action_pressed(Options.BACK_WALL)
	frame.wheel_delta = wheel + int(next and not _next_down) - int(previous and not _previous_down)
	frame.mouse_aim = mouse_aim
	frame.mouse_cell = mouse_cell
	_jump_down = jump
	_dig_down = dig
	_place_down = place
	_previous_down = previous
	_next_down = next
	return frame


func reset() -> void:
	_jump_down = Input.is_action_pressed(Options.JUMP)
	_dig_down = Input.is_action_pressed(Options.DIG)
	_place_down = Input.is_action_pressed(Options.PLACE)
	_previous_down = Input.is_action_pressed(Options.WHEEL_PREV)
	_next_down = Input.is_action_pressed(Options.WHEEL_NEXT)
