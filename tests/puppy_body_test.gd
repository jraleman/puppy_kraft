extends SceneTree

## Run, burrow, jump timing, climb and long falls through the real grid contacts.

const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Fixture = preload("res://games/puppy_kraft/tests/world_fixture.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_run_and_burrow()
	_test_jump()
	_test_coyote_and_buffer()
	_test_climb_and_fall()
	_test_determinism()
	if _failures.is_empty():
		print("Puppy Kraft body tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_run_and_burrow() -> void:
	var grid := Fixture.grid()
	var body := Body.new(Fixture.START)
	var frame := Frame.new()
	frame.move = 1.0
	for tick in 60:
		body.step(grid, frame)
	_expect(body.position.x > Fixture.START.x + 5.5 and body.grounded,
		"The pup must accelerate to six cells per second while staying on real terrain.")
	for column in range(800, 838):
		assert(grid.set_block(Vector2i(column, 98), Blocks.STONE) == OK)
	body = Body.new(Fixture.START)
	for tick in 120:
		body.step(grid, frame)
	_expect(body.position.x > Fixture.START.x + 11.0 and not grid.overlaps_solid(body.bounds()),
		"The unchanging 0.9 by 0.8 body must traverse a genuine one-cell tunnel.")
	assert(grid.set_block(Vector2i(824, 99), Blocks.STONE) == OK)
	for tick in 60:
		body.step(grid, frame)
	_expect(body.position.x <= 824.0 - Body.SIZE.x * 0.5 + 0.001,
		"The same body must stop at a solid tunnel wall, not tunnel through it: %s."
		% body.position)


func _test_jump() -> void:
	var grid := Fixture.grid()
	var body := Body.new(Fixture.START)
	var frame := Frame.new()
	body.step(grid, frame)
	frame.jump_pressed = true
	body.step(grid, frame)
	frame.jump_pressed = false
	var top := body.position.y
	for tick in 180:
		body.step(grid, frame)
		top = minf(top, body.position.y)
	var height := Fixture.START.y - top
	_expect(height >= 2.1 and height <= 2.3 and body.grounded,
		"A buffered jump must reach roughly 2.2 cells and land without damage: %.3f." % height)
	for row in [98, 99]:
		assert(grid.set_block(Vector2i(813, row), Blocks.STONE) == OK)
	body = Body.new(Fixture.START)
	frame.move = 1.0
	frame.jump_pressed = true
	for tick in 75:
		body.step(grid, frame)
		frame.jump_pressed = false
	_expect(body.position.x > 814.0,
		"A real jump must clear a two-block ledge, not merely hit the desired height.")


func _test_coyote_and_buffer() -> void:
	var grid := Fixture.grid()
	for row in range(100, 110):
		for column in range(813, 825):
			assert(grid.set_block(Vector2i(column, row), Blocks.AIR) == OK)
	var body := Body.new(Vector2(812.2, 99.6))
	var frame := Frame.new()
	frame.move = 1.0
	for tick in 20:
		body.step(grid, frame)
		if not body.grounded:
			break
	frame.jump_pressed = true
	body.step(grid, frame)
	_expect(body.velocity.y < -9.0, "Jumping just off a ledge must use coyote time.")
	body = Body.new(Vector2(812.2, 99.6))
	frame.jump_pressed = false
	for tick in 20:
		body.step(grid, frame)
		if not body.grounded:
			break
	for tick in Body.COYOTE_TICKS + 1:
		body.step(grid, frame)
	frame.jump_pressed = true
	body.step(grid, frame)
	_expect(body.velocity.y >= 0.0, "Coyote time must expire rather than granting midair jumps.")
	grid = Fixture.grid()
	body = Body.new(Vector2(810.5, 99.1))
	body.velocity.y = 5.0
	frame = Frame.new()
	frame.jump_pressed = true
	var bounced := false
	for tick in 10:
		body.step(grid, frame)
		frame.jump_pressed = false
		bounced = bounced or body.velocity.y < -9.0
	_expect(bounced, "A jump pressed shortly before landing must trigger on contact.")
	body = Body.new(Vector2(810.5, 96.0))
	frame.jump_pressed = true
	for tick in 120:
		body.step(grid, frame)
		frame.jump_pressed = false
	_expect(body.grounded and body.velocity.y == 0.0,
		"A long-expired jump buffer must not bounce on a later landing.")


func _test_climb_and_fall() -> void:
	var grid := Fixture.grid()
	for row in range(95, 100):
		assert(grid.set_block(Vector2i(810, row), Blocks.LADDER) == OK)
	var body := Body.new(Fixture.START)
	var frame := Frame.new()
	frame.aim = Vector2i.UP
	for tick in 45:
		body.step(grid, frame)
	_expect(body.climbing and body.position.y < Fixture.START.y - 2.5,
		"Holding up inside a ladder must climb without gravity pulling the pup down.")
	var previous := body.position.y
	frame.aim = Vector2i.DOWN
	for tick in 20:
		body.step(grid, frame)
	_expect(body.position.y > previous + 1.0, "Holding down must descend a ladder.")
	assert(grid.set_block(Vector2i(810, 97), Blocks.ROOT) == OK)
	body.position = Vector2(810.5, 97.5)
	frame.aim = Vector2i.UP
	body.step(grid, frame)
	_expect(body.climbing, "Roots must share the same node-free climbing contacts.")
	grid = Fixture.grid()
	body = Body.new(Vector2(810.5, 50.0))
	frame = Frame.new()
	for tick in 600:
		body.step(grid, frame)
	_expect(body.grounded and absf(body.position.y - Fixture.START.y) < 0.001,
		"A fifty-cell fall must land safely, never end the outing or lose terrain contact.")


func _test_determinism() -> void:
	var grid := Fixture.grid()
	var a := Body.new(Fixture.START)
	var b := Body.new(Fixture.START)
	for tick in 720:
		var frame := Frame.new()
		frame.move = 1.0 if tick % 240 < 120 else -1.0
		frame.jump_pressed = tick % 120 == 0
		a.step(grid, frame)
		b.step(grid, frame)
	_expect(a.snapshot() == b.snapshot(), "Identical fixed-tick inputs must give identical contacts.")
	var world := Fixture.world()
	var jump := Frame.new()
	jump.jump_pressed = true
	world.advance(Body.STEP * 0.25, jump)
	world.advance(Body.STEP * 0.75, Frame.new())
	_expect(world.body.velocity.y < 0.0 and jump.jump_pressed,
		"Render-frame edges must survive until a tick without mutating caller input.")
	var fine := Fixture.world()
	var coarse := Fixture.world()
	var held := Frame.new()
	held.move = 0.5
	for tick in 120:
		coarse.advance(Body.STEP, held)
		for substep in 4:
			fine.advance(Body.STEP * 0.25, held)
	_expect(fine.body.snapshot() == coarse.body.snapshot() and fine.ticks == coarse.ticks,
		"Render-frame subdivision must not change a fixed-step outing.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
