extends SceneTree

const Lighting = preload("res://games/puppy_kraft/sim/lighting.gd")
const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_sky()
	_test_sources_and_walls()
	_test_boundaries_and_invalidation()
	_test_nose()
	if _failures.is_empty():
		print("Puppy Kraft lighting tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_sky() -> void:
	var grid := _empty_grid()
	var light := Lighting.new()
	_expect(light.level_at(grid, Vector2i(96, 60), 1.0) == 15.0
		and light.level_at(grid, Vector2i(96, 60), 0.25) < 8.0,
		"Open columns must receive full daylight and fall below the future safe-spawn threshold at night.")
	for column in grid.width:
		assert(grid.set_block(Vector2i(column, 32), Blocks.STONE, Chunk.BACK) == OK)
	_expect(light.level_at(grid, Vector2i(96, 60), 1.0) == 0.0,
		"Back walls must stop direct skylight, including edits well above the sampled chunk.")
	for row in range(32, 61):
		assert(grid.set_block(Vector2i(96, row), Blocks.AIR, Chunk.BACK) == OK)
	_expect(light.level_at(grid, Vector2i(96, 60), 1.0) == 15.0,
		"Opening a sky shaft must restore sunlight after an already-cached roof.")
	assert(grid.set_block(Vector2i(96, 31), Blocks.STONE) == OK)
	_expect(light.level_at(grid, Vector2i(96, 60), 1.0) < 15.0,
		"Front solids must occlude a clear column too.")


func _test_sources_and_walls() -> void:
	var grid := _dark_grid()
	var light := Lighting.new()
	var source := Vector2i(96, 96)
	assert(grid.set_block(source, Blocks.CRYSTAL) == OK)
	_expect(light.level_at(grid, source, 0.0) == 9.0
		and light.level_at(grid, source + Vector2i.RIGHT, 0.0) == 8.0,
		"Existing crystal light must lose one level per air cell.")
	for row in range(80, 113):
		assert(grid.set_block(Vector2i(97, row), Blocks.STONE) == OK)
	_expect(light.level_at(grid, Vector2i(98, 96), 0.0) == 0.0,
		"Block light must not pass through solid walls or take an out-of-range detour.")
	assert(grid.set_block(Vector2i(100, 96), Blocks.GLOW_MOSS, Chunk.BACK) == OK)
	_expect(light.level_at(grid, Vector2i(100, 96), 0.0) == 6.0,
		"A visible back-wall emitter must illuminate its room.")
	assert(grid.set_block(Vector2i(100, 96), Blocks.STONE) == OK)
	_expect(light.level_at(grid, Vector2i(101, 96), 0.0) == 0.0,
		"An opaque front block must hide the emitter behind it.")


func _test_boundaries_and_invalidation() -> void:
	var grid := _dark_grid()
	var light := Lighting.new()
	var source := Vector2i(95, 96)
	assert(grid.set_block(source, Blocks.CRYSTAL) == OK)
	_expect(light.level_at(grid, Vector2i(94, 96), 0.0) == 8.0
		and light.level_at(grid, Vector2i(96, 96), 0.0) == 8.0,
		"An emitter on a chunk edge must illuminate both chunks without a seam.")
	light.level_at(grid, Vector2i(170, 170), 0.0)
	light.changed_chunks(grid)
	var builds := int(light.metrics()["light_builds"])
	light.mesh_codes(grid, Vector2i(2, 3))
	_expect(int(light.metrics()["light_builds"]) == builds,
		"An unchanged light field must be cached rather than flood-filled every frame.")
	assert(grid.set_block(source, Blocks.AIR) == OK)
	grid.mark_clean(Grid.chunk_coordinate(source))
	var dirty := light.changed_chunks(grid)
	_expect(dirty.has(Vector2i(2, 3)) and dirty.has(Vector2i(3, 3))
		and not dirty.has(Vector2i(5, 5))
		and light.level_at(grid, Vector2i(96, 96), 0.0) == 0.0,
		"Removing an emitter must invalidate its light neighbourhood, not distant chunks, even after meshing.")
	var keep: Dictionary[Vector2i, bool] = {Vector2i(3, 3): true}
	light.retain_chunks(keep)
	_expect(int(light.metrics()["light_chunks"]) == 1
		and int(light.metrics()["light_columns"]) <= Lighting.SIDE,
		"Travelling must not accumulate unbounded light fields or column caches.")


func _test_nose() -> void:
	var grid := _dark_grid()
	var light := Lighting.new()
	var at := Vector2i(96, 96)
	assert(grid.set_block(at + Vector2i.RIGHT, Blocks.STONE) == OK)
	var nose := light.nose_field(grid, at)
	_expect(nose[at] == 3 and nose[at + Vector2i.UP] == 2
		and not nose.has(at + Vector2i.RIGHT),
		"The level-three nose glow must move with the pup and respect solid front terrain.")
	var unlit := light.mesh_codes(grid, Vector2i(3, 3))
	var glowing := light.mesh_codes(grid, Vector2i(3, 3), nose)
	_expect((glowing[0] & 15) == 3 and (unlit[0] & 15) == 0
		and light.level_at(grid, at, 0.0, nose) == 3.0
		and light.mesh_codes(grid, Vector2i(3, 3)) == unlit,
		"Nose light must reach baked vertices without mutating cached static light.")


func _empty_grid() -> Grid:
	var grid := Grid.new(42)
	grid.width = 192
	grid.height = 192
	for row in 6:
		for column in 6:
			var coordinate := Vector2i(column, row)
			grid.chunks[coordinate] = Chunk.new(coordinate)
	return grid


func _dark_grid() -> Grid:
	var grid := _empty_grid()
	for column in grid.width:
		assert(grid.set_block(Vector2i(column, 8), Blocks.STONE, Chunk.BACK) == OK)
	return grid


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
