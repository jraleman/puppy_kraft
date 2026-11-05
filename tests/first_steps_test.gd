extends SceneTree

const Progress = preload("res://games/puppy_kraft/sim/first_steps.gd")
const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_achieved_actions()
	_test_frame_partition()
	_test_skip()
	if _failures.is_empty():
		print("Puppy Kraft First Steps tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_achieved_actions() -> void:
	var world := World.new(42)
	var frame := Frame.new()
	frame.sniff = true
	world.advance(Body.STEP, frame)
	frame = Frame.new()
	frame.bark_edges.assign([true, false])
	world.advance(Body.STEP, frame)
	_expect(world.first_steps.step == Progress.Step.MOVE
		and world.abilities.emitted_total == 1,
		"Early actions stay available but must not bypass the current walking lesson.")
	var wall := Vector2i(world.body.position.floor()) + Vector2i.RIGHT
	assert(world.grid.get_block(wall) == Blocks.AIR)
	assert(world.grid.set_block(wall, Blocks.WOOD) == OK)
	frame = Frame.new()
	frame.move = 1.0
	world.advance(2.0, frame)
	_expect(world.first_steps.step == Progress.Step.MOVE and world.first_steps.walked < 1.0,
		"Running into terrain must count actual travel, not held movement keys or elapsed time.")
	assert(world.grid.set_block(wall, Blocks.AIR) == OK)
	world.advance(1.0, frame)
	_expect(world.first_steps.step == Progress.Step.DIG,
		"Walking four actual cells must reveal the digging prompt.")
	frame = Frame.new()
	frame.dig = true
	frame.mouse_aim = true
	frame.mouse_cell = Vector2i(world.body.position.floor()) + Vector2i.UP
	world.advance(Body.STEP * 30.0, frame)
	_expect(world.blocks_dug == 0 and world.first_steps.step == Progress.Step.DIG,
		"Digging empty air must not advance the lesson.")
	frame.mouse_cell = Vector2i(world.body.position.floor()) + Vector2i.DOWN
	var id := world.grid.get_block(frame.mouse_cell)
	assert(id != Blocks.AIR)
	world.advance(Body.STEP * Blocks.dig_ticks(id), frame)
	_expect(world.blocks_dug == 1 and world.first_steps.step == Progress.Step.SNIFF,
		"Only successful block removal must complete digging.")
	frame = Frame.new()
	frame.sniff = true
	frame.bark_edges.assign([true, false])
	world.advance(Body.STEP, frame)
	_expect(not world.scent.trails.is_empty() and world.first_steps.step == Progress.Step.BARK
		and world.abilities.emitted_total == 1,
		"A genuine scent trail completes sniffing; a sniff-suppressed bark must not count.")
	world.cancel_actions()
	_expect(world.first_steps.step == Progress.Step.BARK,
		"Menus and input cancellation must not erase achieved lessons.")
	frame = Frame.new()
	frame.bark_edges.assign([true, false])
	world.advance(Body.STEP, frame)
	_expect(world.first_steps.step == Progress.Step.HOME
		and world.abilities.emitted_total == 2,
		"A successful free Yip must reveal the home prompt.")
	world.begin_outing()
	world.advance(Body.STEP, Frame.new())
	_expect(world.first_steps.step == Progress.Step.HOME,
		"Reaching the last prompt or starting an outing must not pretend the bed diary was saved.")


func _test_frame_partition() -> void:
	var fine := World.new(42)
	var coarse := World.new(42)
	var frame := Frame.new()
	frame.move = 1.0
	for tick in 15:
		fine.advance(Body.STEP, frame)
	coarse.advance(Body.STEP * 15.0, frame)
	_expect(fine.first_steps.snapshot() == coarse.first_steps.snapshot()
		and fine.first_steps.step == Progress.Step.MOVE and fine.first_steps.walked > 0.0,
		"Partial walking progress must be independent of render-frame partitioning.")


func _test_skip() -> void:
	var progress := Progress.new()
	progress.walk(0.75)
	progress.skip()
	progress.walk(10.0)
	progress.achieve(Progress.Step.DIG)
	_expect(progress.step == Progress.Step.DONE
		and Progress.validate(progress.snapshot()).is_empty(),
		"Skipping a partial lesson must produce durable completed progress that later actions cannot restart.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
