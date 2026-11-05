extends SceneTree

## Through-wall discovery, night range, edited-source invalidation and real sniff inputs.

const Scent = preload("res://games/puppy_kraft/sim/scent.gd")
const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const Fixture = preload("res://games/puppy_kraft/tests/world_fixture.gd")
const FetchStick = preload("res://games/puppy_kraft/sim/fetch_stick.gd")
const ORIGIN := Vector2(96.5, 96.5)

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_through_walls()
	_test_range_and_night()
	_test_edited_sources()
	_test_stable_ties()
	_test_hold_and_dig()
	_test_sniff_to_resource()
	_test_toggle_edges_and_cancel()
	_test_clock_transition()
	_test_stick_scent()
	if _failures.is_empty():
		print("Puppy Kraft scent tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_through_walls() -> void:
	var grid := _empty_grid()
	var crystal := Vector2i(100, 99)
	_bury(grid, crystal, Blocks.CRYSTAL)
	assert(grid.set_block(Vector2i(80, 96), Blocks.BED) == OK)
	assert(grid.set_block(Vector2i(96, 97), Blocks.GRASS) == OK)
	assert(grid.set_block(Vector2i(97, 96), Blocks.WOOD) == OK)
	var scent := Scent.new()
	scent.scan(grid, ORIGIN)
	_expect(scent.trails.size() == 2 and scent.trails[0]["cell"] == crystal,
		"Buried ore and home must be found through solid walls, not masked by ambient grass.")
	_expect(scent.caption(ORIGIN).contains("crystal, down and to the right"),
		"The strongest trail must name the actual resource and a non-visual direction.")
	_expect(scent.outlines.size() == 1 and scent.outlines[0]["cell"] == crystal,
		"A buried resource within six cells must receive an outline.")
	scent.scan(grid, Vector2(104.5, 101.5))
	_expect(scent.caption(Vector2(104.5, 101.5)).contains("up and to the left"),
		"Moving past a resource must update its caption rather than retaining the old direction.")


func _test_range_and_night() -> void:
	var grid := _empty_grid()
	var origin := Vector2(80.5, 96.5)
	var source := Vector2i(144, 96)
	assert(grid.set_block(source, Blocks.CRYSTAL) == OK)
	var scent := Scent.new()
	scent.scan(grid, origin)
	_expect(scent.trails.is_empty() and scent.caption(origin).contains("within 48 cells"),
		"Out-of-range resources must not leak into daytime captions or trails.")
	scent.scan(grid, origin, true)
	_expect(scent.trails.size() == 1 and scent.trails[0]["cell"] == source,
		"Night must double the actual discovery range, not only the drawn trail length.")
	scent.scan(grid, origin, false, 1.5)
	_expect(scent.trails.size() == 1,
		"An authored range multiplier must affect the real query without changing terrain.")
	assert(grid.set_block(source, Blocks.AIR) == OK)
	assert(grid.set_block(Vector2i(176, 96), Blocks.CRYSTAL) == OK)
	scent.scan(grid, origin, true)
	_expect(scent.trails.size() == 1, "The inclusive night range must reach a source 96 cells away.")
	assert(grid.set_block(Vector2i(176, 96), Blocks.AIR) == OK)
	assert(grid.set_block(Vector2i(177, 96), Blocks.CRYSTAL) == OK)
	scent.scan(grid, origin, true)
	_expect(scent.trails.is_empty(), "A source just beyond the doubled range must remain hidden.")
	scent.scan(grid, Vector2(-60, -60))
	_expect(scent.trails.is_empty(),
		"A sky or world-edge query must clip safely instead of loading an out-of-world chunk.")


func _test_edited_sources() -> void:
	var grid := _empty_grid()
	var front := Vector2i(100, 99)
	_bury(grid, front, Blocks.CRYSTAL)
	var scent := Scent.new()
	scent.scan(grid, ORIGIN)
	assert(grid.set_block(front, Blocks.AIR) == OK)
	var back := Vector2i(102, 96)
	assert(grid.set_block(back, Blocks.STONE) == OK)
	assert(grid.set_block(back, Blocks.GLOW_MOSS, Chunk.BACK) == OK)
	grid.mark_clean(Grid.chunk_coordinate(front))
	grid.mark_clean(Grid.chunk_coordinate(back))
	scent.scan(grid, ORIGIN)
	_expect(scent.trails.size() == 1 and scent.trails[0]["cell"] == back
		and int(scent.trails[0]["layer"]) == Chunk.BACK,
		"Collecting and placing resources must invalidate the scent index even after remeshing.")
	_expect(scent.caption(ORIGIN).contains("glow moss")
		and scent.caption(ORIGIN).contains("back wall")
		and scent.outlines.size() == 1,
		"A back-layer resource behind solid front terrain must be outlined and named honestly.")
	assert(grid.set_block(back, Blocks.AIR, Chunk.BACK) == OK)
	scent.scan(grid, ORIGIN)
	_expect(scent.trails.is_empty() and scent.outlines.is_empty(),
		"Removing the last source must remove its caption and outline, not leave a ghost trail.")


func _test_stable_ties() -> void:
	var grid := _empty_grid()
	assert(grid.set_block(Vector2i(100, 96), Blocks.CRYSTAL, Chunk.BACK) == OK)
	assert(grid.set_block(Vector2i(92, 96), Blocks.CRYSTAL) == OK)
	var scent := Scent.new()
	scent.scan(grid, ORIGIN)
	_expect(scent.trails.size() == 1 and scent.trails[0]["cell"] == Vector2i(92, 96),
		"Equal-strength sources must use a stable cell ordering, not edit or load order.")
	scent.scan(_empty_grid(), ORIGIN)
	_expect(scent.trails.is_empty(),
		"Reusing a query for another world must never retain the previous world's source index.")


func _test_hold_and_dig() -> void:
	var world := Fixture.world()
	var frame := Frame.new()
	frame.mouse_aim = true
	frame.mouse_cell = Vector2i(811, 100)
	frame.dig = true
	for tick in 7:
		world.advance(Body.STEP, frame)
	frame.sniff = true
	frame.move = 1.0
	for tick in 30:
		world.advance(Body.STEP, frame)
	_expect(world.sniffing and is_equal_approx(world.body.velocity.x, Body.RUN_SPEED * 0.5)
		and frame.move == 1.0,
		"Held sniffing must halve walking speed without mutating the caller's input frame.")
	_expect(world.dig_progress == 0 and world.blocks_dug == 0,
		"Starting sniffing must cancel a partial dig and prevent collection while held.")
	frame.sniff = false
	frame.move = 0.0
	for tick in Blocks.dig_ticks(Blocks.MEADOW_SOIL):
		world.advance(Body.STEP, frame)
	_expect(not world.sniffing and world.blocks_dug == 1
		and world.scent.trails.is_empty(),
		"Releasing Hold must clear sniff feedback and allow a fresh full dig.")


func _test_toggle_edges_and_cancel() -> void:
	var world := Fixture.world()
	world.set_sniff_mode(true)
	var frame := Frame.new()
	frame.sniff = true
	frame.sniff_pressed = true
	world.advance(Body.STEP * 0.5, frame)
	_expect(not world.sniffing, "A sub-tick press must wait for the real fixed-step simulation.")
	frame.sniff_pressed = false
	world.advance(Body.STEP * 0.5, frame)
	frame.sniff = false
	world.advance(Body.STEP * 3.0, frame)
	_expect(world.sniffing, "Toggle must retain one press across sub-tick frames and key release.")
	frame.sniff_pressed = true
	world.advance(Body.STEP * 4.0, frame)
	_expect(not world.sniffing,
		"A multi-tick advance must consume a toggle press once, not once per simulation tick.")
	world.advance(Body.STEP, frame)
	_expect(world.sniffing, "A second press must turn Toggle back on.")
	world.cancel_actions()
	world.advance(Body.STEP, Frame.new())
	_expect(not world.sniffing and world.scent.trails.is_empty(),
		"Menus and outing changes must cancel the toggle latch and all pending sniff input.")
	frame.sniff_pressed = true
	world.advance(0.0, frame)
	world.advance(0.0, Frame.new())
	world.advance(0.0, frame)
	world.advance(Body.STEP, Frame.new())
	_expect(not world.sniffing,
		"Two toggle presses before a fixed tick must cancel each other rather than collapse to one.")


func _test_sniff_to_resource() -> void:
	var world := Fixture.world()
	var resource := Vector2i(811, 101)
	_bury(world.grid, resource, Blocks.CRYSTAL)
	var frame := Frame.new()
	frame.mouse_aim = true
	frame.mouse_cell = resource
	frame.sniff = true
	world.advance(Body.STEP, frame)
	_expect(not world.scent.trails.is_empty() and world.scent.trails[0]["cell"] == resource
		and not world.scent.outlines.is_empty(),
		"A real world must reveal the nearby buried resource before the puppy digs it up.")
	frame.sniff = false
	frame.dig = true
	for tick in Blocks.dig_ticks(Blocks.CRYSTAL):
		world.advance(Body.STEP, frame)
	_expect(world.blocks_dug == 1 and world.inventory[Blocks.CRYSTAL] == 1
		and world.grid.get_block(resource) == Blocks.AIR,
		"Following a scent and finishing the real hardness hold must collect its actual material.")
	frame.dig = false
	frame.sniff = true
	world.advance(Body.STEP, frame)
	var stale := false
	for source: Dictionary in world.scent.trails:
		stale = stale or source["cell"] == resource
	_expect(not stale, "Sniffing again after collection must not point at the removed resource.")


func _test_clock_transition() -> void:
	var world := World.new(42)
	var frame := Frame.new()
	frame.sniff = true
	world.ticks = World.NIGHT_START_TICKS - 1
	world.clock.restore_legacy(world.ticks)
	var started := Time.get_ticks_usec()
	world.advance(Body.STEP, frame)
	var cold_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_expect(world.is_night() and world.scent.range_cells == Scent.BASE_RANGE * 2.0,
		"The saved world clock must switch discovery to night range at the designed phase.")
	started = Time.get_ticks_usec()
	for sample in 20:
		world.scent.scan(world.grid, world.body.position, true)
	var warm_ms := float(Time.get_ticks_usec() - started) / 20000.0
	print("Night scent query: ", cold_ms, " ms first activation; ", warm_ms, " ms warm mean.")
	world.ticks = World.DAY_TICKS - 1
	world.clock.restore_legacy(world.ticks)
	world.advance(Body.STEP, frame)
	_expect(not world.is_night() and world.scent.range_cells == Scent.BASE_RANGE
		and str(world.take_events()[0]["type"]) == "dawn",
		"Dawn must restore daytime scent range without losing the existing autosave event.")


func _empty_grid() -> Grid:
	var grid := Grid.new(42)
	grid.width = 192
	grid.height = 192
	for row in 6:
		for column in 6:
			var coordinate := Vector2i(column, row)
			grid.chunks[coordinate] = Chunk.new(coordinate)
	return grid


func _test_stick_scent() -> void:
	var grid := _empty_grid()
	var stick := FetchStick.new(Vector2(100.2, 96.8))
	var scent := Scent.new()
	scent.scan(grid, ORIGIN, false, 1.0, stick)
	_expect(scent.trails.size() == 1 and scent.trails[0]["kind"] == "stick"
		and scent.trails[0]["position"] == stick.position
		and scent.caption(ORIGIN).contains("your stick, to the right"),
		"A loose stick must supply its actual position and a named directional scent.")
	stick.position = ORIGIN + Vector2(64, 0)
	scent.scan(grid, ORIGIN, false, 1.0, stick)
	_expect(scent.trails.is_empty(), "A lost stick must respect the real daytime scent range.")
	scent.scan(grid, ORIGIN, true, 1.0, stick)
	_expect(scent.trails.size() == 1 and scent.trails[0]["position"] == stick.position,
		"Moving items must refresh without terrain edits and use the doubled night range.")
	stick.carried = true
	scent.scan(grid, ORIGIN, true, 1.0, stick)
	_expect(scent.trails.is_empty(), "A held stick must not leave a ghost lost-item trail.")
	var world := Fixture.world()
	world.stick.position = world.body.position + Vector2(0.8, 0.2)
	var frame := Frame.new()
	frame.sniff = true
	world.advance(Body.STEP, frame)
	_expect(world.scent.trails[0]["kind"] == "stick",
		"Sniffing in the real world must reveal a nearby dropped toy.")
	frame.carry_pressed = true
	world.advance(Body.STEP, frame)
	var stale := false
	for source: Dictionary in world.scent.trails:
		stale = stale or source["kind"] == "stick"
	_expect(world.stick.carried and not stale,
		"Picking up while sniffing must immediately remove the toy trail, even between refresh ticks.")


func _bury(grid: Grid, cell: Vector2i, block: int) -> void:
	assert(grid.set_block(cell, block) == OK)
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		assert(grid.set_block(cell + offset, Blocks.STONE) == OK)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
