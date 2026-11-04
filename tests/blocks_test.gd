extends SceneTree

## Registry invariants and reversible cross-layer edits, including mesh neighbours.

const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	var ids := {}
	for id in Blocks.COUNT:
		var entry := Blocks.DATA[id]
		_expect(not ids.has(entry["id"]), "Block ids must not collide in saved terrain.")
		ids[entry["id"]] = true
		_expect(Blocks.is_valid(int(entry["drops"])), "Every drop must be a registered block.")
		_expect(int(entry["light"]) >= 0 and int(entry["light"]) <= 15,
			"Emitted light must fit the model's four-bit range.")
		if id != Blocks.AIR and not Blocks.has_flag(id, Blocks.UNBREAKABLE):
			_expect(Blocks.dig_ticks(id) >= 15 and Blocks.dig_ticks(id) <= 120,
				"Every breakable block must have a usable hold duration.")
	_test_layers_and_deltas()
	_finish()


func _test_layers_and_deltas() -> void:
	var grid := Grid.new(42)
	var cell := Vector2i(800, 127)
	var coordinate := Grid.chunk_coordinate(cell)
	var front := grid.get_block(cell)
	var back := grid.get_block(cell, Chunk.BACK)
	grid.mark_clean(coordinate)
	_expect(grid.set_block(cell, Blocks.WOOD) == OK, "A front edit must succeed.")
	_expect(grid.get_block(cell) == Blocks.WOOD and grid.get_block(cell, Chunk.BACK) == back,
		"Front edits must never overwrite the independent back layer.")
	_expect(grid.set_block(cell, Blocks.CLAY, Chunk.BACK) == OK,
		"A supported back-wall material must be stored separately.")
	_expect(grid.edits[coordinate].size() == 2,
		"A changed front and back cell must each appear once in the delta.")
	_expect(grid.dirty_chunks.has(coordinate + Vector2i.LEFT)
		and grid.dirty_chunks.has(coordinate + Vector2i.DOWN),
		"A chunk-edge edit must invalidate both exposed-face neighbours.")
	_expect(grid.set_block(cell, front) == OK and grid.set_block(cell, back, Chunk.BACK) == OK,
		"Both generated values must be restorable.")
	_expect(not grid.edits.has(coordinate), "Restoring terrain must erase its save delta entirely.")
	var before := grid.get_block(cell, Chunk.BACK)
	_expect(grid.set_block(cell, Blocks.LADDER, Chunk.BACK) == ERR_INVALID_PARAMETER
		and grid.get_block(cell, Chunk.BACK) == before,
		"Invalid back-wall blocks must fail explicitly without modifying terrain.")
	_expect(grid.solid_at(Vector2i(-1, 100)) and grid.solid_at(Vector2i(800, grid.height))
		and not grid.solid_at(Vector2i(800, -1)),
		"Side/bottom boundaries stop the pup, while the sky remains open.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Puppy Kraft block tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)
