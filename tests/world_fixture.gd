extends RefCounted

## A flat, bounded test patch isolates contacts from generated hills and the kennel.

const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const START := Vector2(810.5, 99.6)


static func grid() -> Grid:
	var result := Grid.new(42)
	for row in range(78, 101):
		for column in range(792, 856):
			var cell := Vector2i(column, row)
			assert(result.set_block(cell, Blocks.AIR) == OK)
			assert(result.set_block(cell, Blocks.AIR, Chunk.BACK) == OK)
	for column in range(792, 856):
		assert(result.set_block(Vector2i(column, 100), Blocks.MEADOW_SOIL) == OK)
	return result


static func world() -> World:
	var result := World.new(42)
	result.grid = grid()
	result.body = Body.new(START)
	return result
