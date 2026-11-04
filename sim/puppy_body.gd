extends RefCounted

## Axis-separated fixed-step contacts fit one-cell burrows without a physics server.

const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const STEP := 1.0 / 60.0
const SIZE := Vector2(0.9, 0.8)
const RUN_SPEED := 6.0
const ACCELERATION := 48.0
const GRAVITY := 25.0
const JUMP_SPEED := 10.6
const MAX_FALL_SPEED := 20.0
const CLIMB_SPEED := 3.5
const COYOTE_TICKS := 6
const JUMP_BUFFER_TICKS := 7
const CONTACT_EPSILON := Grid.CONTACT_EPSILON

var position := Vector2.ZERO
var velocity := Vector2.ZERO
var facing := 1
var grounded := false
var climbing := false
var coyote_ticks := 0
var jump_buffer_ticks := 0


func _init(at := Vector2.ZERO) -> void:
	position = at


func bounds() -> Rect2:
	return Rect2(position - SIZE * 0.5, SIZE)


func step(grid: Grid, frame: Frame) -> void:
	assert(is_finite(frame.move), "Puppy movement must be finite.")
	grounded = grid.overlaps_solid(Rect2(bounds().position + Vector2(0, 0.02), SIZE))
	coyote_ticks = COYOTE_TICKS if grounded else maxi(coyote_ticks - 1, 0)
	jump_buffer_ticks = JUMP_BUFFER_TICKS if frame.jump_pressed \
		else maxi(jump_buffer_ticks - 1, 0)
	var movement := clampf(frame.move, -1.0, 1.0)
	velocity.x = move_toward(velocity.x, movement * RUN_SPEED, ACCELERATION * STEP)
	if movement != 0.0:
		facing = 1 if movement > 0.0 else -1
	climbing = _touches_climbable(grid) and frame.aim.y != 0
	if climbing:
		velocity.y = frame.aim.y * CLIMB_SPEED
	if jump_buffer_ticks > 0 and (coyote_ticks > 0 or climbing):
		_jump()
	if not climbing:
		velocity.y = minf(velocity.y + GRAVITY * STEP, MAX_FALL_SPEED)
	_move_axis(grid, 0, velocity.x * STEP)
	_move_axis(grid, 1, velocity.y * STEP)
	grounded = grid.overlaps_solid(Rect2(bounds().position + Vector2(0, 0.02), SIZE)) \
		and velocity.y >= 0.0
	if grounded and jump_buffer_ticks > 0:
		_jump()


func snapshot() -> Dictionary:
	return {
		"position": position, "velocity": velocity, "facing": facing,
		"grounded": grounded, "climbing": climbing, "coyote_ticks": coyote_ticks,
		"jump_buffer_ticks": jump_buffer_ticks,
	}


func _jump() -> void:
	velocity.y = -JUMP_SPEED
	jump_buffer_ticks = 0
	coyote_ticks = 0
	grounded = false
	climbing = false


func _touches_climbable(grid: Grid) -> bool:
	var box := bounds()
	var first := Vector2i((box.position + Vector2.ONE * CONTACT_EPSILON).floor())
	var last := Vector2i((box.end - Vector2.ONE * CONTACT_EPSILON).floor())
	for row in range(first.y, last.y + 1):
		for column in range(first.x, last.x + 1):
			if Blocks.has_flag(grid.get_block(Vector2i(column, row)), Blocks.CLIMBABLE):
				return true
	return false


func _move_axis(grid: Grid, axis: int, distance: float) -> void:
	if distance == 0.0:
		return
	position[axis] += distance
	var box := bounds()
	var first := Vector2i((box.position + Vector2.ONE * CONTACT_EPSILON).floor())
	var last := Vector2i((box.end - Vector2.ONE * CONTACT_EPSILON).floor())
	var limit := position[axis]
	var collided := false
	for row in range(first.y, last.y + 1):
		for column in range(first.x, last.x + 1):
			var cell := Vector2i(column, row)
			if not grid.solid_at(cell):
				continue
			collided = true
			if distance > 0.0:
				limit = minf(limit, float(cell[axis]) - SIZE[axis] * 0.5)
			else:
				limit = maxf(limit, float(cell[axis] + 1) + SIZE[axis] * 0.5)
	if collided:
		position[axis] = limit
		velocity[axis] = 0.0
