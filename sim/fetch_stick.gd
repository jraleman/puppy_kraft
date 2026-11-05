extends RefCounted

## One persistent toy; all flight and pickup decisions use the fixed-step grid.

const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const SIZE := Vector2(0.7, 0.2)
const PICKUP_REACH := 1.5
const THROW_SPEED := 9.0
const THROW_LIFT := 7.5
const RUN_THRESHOLD := 4.0
const GROUND_DRAG := 18.0
const CAPTION_TICKS := 120

var position := Vector2.ZERO
var velocity := Vector2.ZERO
var carried := false
var caption := ""
var _caption_ticks := 0


func _init(at := Vector2.ZERO) -> void:
	position = at


func bounds() -> Rect2:
	return Rect2(position - SIZE * 0.5, SIZE)


func step(grid: Grid, body: Body) -> void:
	_caption_ticks = maxi(_caption_ticks - 1, 0)
	if _caption_ticks == 0:
		caption = ""
	if carried:
		position = body.position
		velocity = Vector2.ZERO
		return
	if velocity.y >= 0.0 \
		and grid.overlaps_solid(Rect2(bounds().position + Vector2(0, 0.02), SIZE)):
		velocity.x = move_toward(velocity.x, 0.0, GROUND_DRAG * Body.STEP)
	velocity.y = minf(velocity.y + Body.GRAVITY * Body.STEP, Body.MAX_FALL_SPEED)
	for axis in 2:
		var destination := position
		destination[axis] += velocity[axis] * Body.STEP
		position = grid.move_box_axis(position, SIZE, axis, velocity[axis] * Body.STEP)
		if position != destination:
			velocity[axis] = 0.0


func interact(grid: Grid, body: Body, running: bool) -> String:
	if not carried:
		if body.position.distance_to(position) > PICKUP_REACH:
			_say("Move within 1.5 cells of the stick. Sniff to find it.")
			return ""
		if not grid.clear_line(body.position, position):
			_say("A solid block is between you and the stick.")
			return ""
		carried = true
		position = body.position
		velocity = Vector2.ZERO
		_say("Picked up the stick.")
		return "stick_picked_up"
	carried = false
	var offset := body.facing * (Body.SIZE.x * 0.5 + SIZE.x * 0.5 + 0.05)
	position = grid.move_box_axis(body.position + Vector2(0, -0.1), SIZE, 0, offset)
	velocity = Vector2(body.facing * THROW_SPEED, -THROW_LIFT) if running else Vector2.ZERO
	_say("Fetch! Follow your stick." if running else "Dropped the stick.")
	return "stick_thrown" if running else "stick_dropped"


func snapshot() -> Dictionary:
	return {"position": position, "velocity": velocity, "carried": carried}


func clear_caption() -> void:
	caption = ""
	_caption_ticks = 0


func _say(message: String) -> void:
	caption = message
	_caption_ticks = CAPTION_TICKS
