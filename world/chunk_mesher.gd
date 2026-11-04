extends RefCounted

## Coplanar runs share quads; repeating world-space UVs preserve each visible toy tile.

const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")
const Builder = preload("res://games/puppy_kraft/world/mesh_builder.gd")
const CELL_METRES := 0.5
const FRONT_Z := 0.18
const REAR_Z := -0.18
const WALL_Z := -0.27
const PADDED_SIZE := Chunk.SIZE + 2
const COLORS: Array[Color] = [
	Color("ffffff"), Color("b98a60"), Color("8fb95b"), Color("c48c6c"),
	Color("85939b"), Color("cba873"), Color("a4c86c"), Color("a48456"),
	Color("9ac5de"), Color("bdd892"), Color("e6ce8b"), Color("d6b780"),
	Color("526571"),
]


static func build(grid: Grid, coordinate: Vector2i) -> ArrayMesh:
	var builder := Builder.new()
	var chunk := grid.chunk_at(coordinate)
	var origin := coordinate * Chunk.SIZE
	var front := chunk.front
	var back := chunk.back
	if front.count(Blocks.AIR) == Chunk.CELLS and back.count(Blocks.AIR) == Chunk.CELLS:
		return builder.finish()
	var solid := _solidity(grid, front, origin)
	for row in Chunk.SIZE:
		_front_runs(builder, front, back, solid, origin, row)
		_horizontal_runs(builder, front, solid, origin, row, true)
		_horizontal_runs(builder, front, solid, origin, row, false)
		for column in Chunk.SIZE:
			var id := front[column + row * Chunk.SIZE]
			var padded := column + 1 + (row + 1) * PADDED_SIZE
			if solid[padded] == 0 and id == Blocks.AIR:
				continue
			if solid[padded] != 0 and solid[padded - 1] != 0 and solid[padded + 1] != 0:
				continue
			var cell := origin + Vector2i(column, row)
			var left := float(cell.x) * CELL_METRES
			var right := left + CELL_METRES
			var top := -float(cell.y) * CELL_METRES
			var bottom := top - CELL_METRES
			if solid[padded] == 0:
				if id != Blocks.AIR:
					_detail(builder, id, Vector3((left + right) * 0.5, (top + bottom) * 0.5, 0))
				continue
			var color := _color(id, cell.y)
			if solid[padded - 1] == 0:
				builder.quad(Vector3(left, bottom, REAR_Z), Vector3(left, bottom, FRONT_Z),
					Vector3(left, top, FRONT_Z), Vector3(left, top, REAR_Z), color.darkened(0.08))
			if solid[padded + 1] == 0:
				builder.quad(Vector3(right, bottom, FRONT_Z), Vector3(right, bottom, REAR_Z),
					Vector3(right, top, REAR_Z), Vector3(right, top, FRONT_Z), color.darkened(0.08))
	return builder.finish()


static func _front_runs(builder: Builder, front: PackedInt32Array, back: PackedInt32Array,
	solidity: PackedByteArray, origin: Vector2i, row: int) -> void:
	var column := 0
	var top := -float(origin.y + row) * CELL_METRES
	var bottom := top - CELL_METRES
	while column < Chunk.SIZE:
		var index := column + row * Chunk.SIZE
		var solid := solidity[column + 1 + (row + 1) * PADDED_SIZE] != 0
		var id := front[index] if solid else back[index]
		if id == Blocks.AIR:
			column += 1
			continue
		var end := column + 1
		while end < Chunk.SIZE:
			var next := end + row * Chunk.SIZE
			var next_solid := solidity[end + 1 + (row + 1) * PADDED_SIZE] != 0
			if solid != next_solid or (front[next] if solid else back[next]) != id:
				break
			end += 1
		var left := float(origin.x + column) * CELL_METRES
		var right := float(origin.x + end) * CELL_METRES
		var z := FRONT_Z if solid else WALL_Z
		var color := _color(id, origin.y + row)
		if not solid:
			color = color.darkened(0.32)
		builder.quad(Vector3(left, bottom, z), Vector3(right, bottom, z),
			Vector3(right, top, z), Vector3(left, top, z), color)
		column = end


static func _horizontal_runs(builder: Builder, front: PackedInt32Array,
	solidity: PackedByteArray, origin: Vector2i, row: int, top_face: bool) -> void:
	var neighbour_offset := -PADDED_SIZE if top_face else PADDED_SIZE
	var row_start := (row + 1) * PADDED_SIZE + 1
	var column := 0
	while column < Chunk.SIZE:
		var id := front[column + row * Chunk.SIZE]
		if solidity[row_start + column] == 0 \
			or solidity[row_start + column + neighbour_offset] != 0:
			column += 1
			continue
		var end := column + 1
		while end < Chunk.SIZE and front[end + row * Chunk.SIZE] == id \
			and solidity[row_start + end + neighbour_offset] == 0:
			end += 1
		var left := float(origin.x + column) * CELL_METRES
		var right := float(origin.x + end) * CELL_METRES
		var y := -float(origin.y + row + (0 if top_face else 1)) * CELL_METRES
		var color := _color(id, origin.y + row)
		if top_face:
			builder.quad(Vector3(left, y, REAR_Z), Vector3(left, y, FRONT_Z),
				Vector3(right, y, FRONT_Z), Vector3(right, y, REAR_Z), color.lightened(0.10))
		else:
			builder.quad(Vector3(left, y, FRONT_Z), Vector3(left, y, REAR_Z),
				Vector3(right, y, REAR_Z), Vector3(right, y, FRONT_Z), color)
		column = end


static func _color(id: int, row: int) -> Color:
	return COLORS[id].darkened(0.18) if row > 140 else COLORS[id]


static func cell_centre(cell: Vector2i) -> Vector3:
	return Vector3((float(cell.x) + 0.5) * CELL_METRES,
		-(float(cell.y) + 0.5) * CELL_METRES, 0)


static func _solidity(grid: Grid, front: PackedInt32Array, origin: Vector2i) -> PackedByteArray:
	var flags := PackedByteArray()
	flags.resize(Blocks.COUNT)
	for id in Blocks.COUNT:
		flags[id] = int(Blocks.has_flag(id, Blocks.SOLID))
	var padded := PackedByteArray()
	padded.resize(PADDED_SIZE * PADDED_SIZE)
	for row in Chunk.SIZE:
		for column in Chunk.SIZE:
			padded[column + 1 + (row + 1) * PADDED_SIZE] = flags[front[column + row * Chunk.SIZE]]
	for offset in Chunk.SIZE:
		padded[offset + 1] = flags[grid.get_block(origin + Vector2i(offset, -1))]
		padded[offset + 1 + (PADDED_SIZE - 1) * PADDED_SIZE] \
			= flags[grid.get_block(origin + Vector2i(offset, Chunk.SIZE))]
		padded[(offset + 1) * PADDED_SIZE] = flags[grid.get_block(origin + Vector2i(-1, offset))]
		padded[(offset + 1) * PADDED_SIZE + PADDED_SIZE - 1] \
			= flags[grid.get_block(origin + Vector2i(Chunk.SIZE, offset))]
	return padded


static func _detail(builder: Builder, id: int, at: Vector3) -> void:
	if id == Blocks.LADDER or id == Blocks.ROOT:
		var color := COLORS[id]
		for side: float in [-0.12, 0.12]:
			builder.box(at + Vector3(side, 0, 0.12), Vector3(0.035, 0.5, 0.07), color)
		for rung: float in [-0.16, 0.0, 0.16]:
			builder.box(at + Vector3(0, rung, 0.13), Vector3(0.27, 0.035, 0.075), color)
	elif id == Blocks.BED:
		builder.box(at + Vector3(0, -0.16, 0.05), Vector3(0.48, 0.16, 0.38), COLORS[id])
		builder.box(at + Vector3(-0.14, -0.04, 0.05),
			Vector3(0.13, 0.10, 0.32), Color("f3e8c5"))
	elif id == Blocks.GLOW_MOSS:
		builder.box(at + Vector3(0, -0.20, 0.1), Vector3(0.36, 0.07, 0.28), COLORS[id])
