extends RefCounted

## Cached, bounded light fields; neither mesh cleaning nor time-of-day changes erase them.

const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const MAX_LIGHT := 15
const NOSE_LIGHT := 3
const PADDING := MAX_LIGHT
const SIDE := Chunk.SIZE + PADDING * 2
const AREA := SIDE * SIDE
const OFFSETS: Array[int] = [-1, 1, -SIDE, SIDE]
const NEIGHBOURS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
]

var _chunks: Dictionary[Vector2i, Dictionary] = {}
var _columns: Dictionary[int, Dictionary] = {}
var _revision := -1
var _builds := 0
var _total_usec := 0
var _max_usec := 0


func changed_chunks(grid: Grid) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	if _revision == grid.revision:
		return changed
	_revision = grid.revision
	for coordinate: Vector2i in _chunks:
		if _chunks[coordinate]["signature"] != _signature(grid, coordinate):
			changed.append(coordinate)
	return changed


func retain_chunks(needed: Dictionary[Vector2i, bool]) -> void:
	var left := 2147483647
	var right := -1
	for coordinate: Vector2i in needed:
		left = mini(left, coordinate.x * Chunk.SIZE - PADDING)
		right = maxi(right, (coordinate.x + 1) * Chunk.SIZE + PADDING)
	for coordinate: Vector2i in _chunks.keys():
		if not needed.has(coordinate):
			_chunks.erase(coordinate)
	for column: int in _columns.keys():
		if column < left or column >= right:
			_columns.erase(column)


func mesh_codes(grid: Grid, coordinate: Vector2i,
	nose: Dictionary[Vector2i, int] = {}) -> PackedByteArray:
	var field := _field(grid, coordinate)
	var codes: PackedByteArray = field["codes"]
	if nose.is_empty():
		return codes
	codes = codes.duplicate()
	var solids: PackedByteArray = field["solid"]
	var origin := coordinate * Chunk.SIZE
	for cell: Vector2i in nose:
		var level := nose[cell]
		_raise_nose(codes, cell - origin, level)
		for offset: Vector2i in NEIGHBOURS:
			var local := cell + offset - origin
			if _inside(local) and solids[Chunk.index(local)] != 0:
				_raise_nose(codes, local, level)
	return codes


func level_at(grid: Grid, cell: Vector2i, daylight: float,
	nose: Dictionary[Vector2i, int] = {}) -> float:
	if cell.y < 0 and cell.x >= 0 and cell.x < grid.width:
		return MAX_LIGHT * daylight
	if not grid.contains(cell):
		return 0.0
	var coordinate := Grid.chunk_coordinate(cell)
	var field := _field(grid, coordinate)
	var index := Chunk.index(cell - coordinate * Chunk.SIZE)
	var sky: PackedByteArray = field["sky"]
	var block: PackedByteArray = field["block"]
	return maxf(sky[index] * daylight, maxi(block[index], nose.get(cell, 0)))


func nose_field(grid: Grid, cell: Vector2i) -> Dictionary[Vector2i, int]:
	var result: Dictionary[Vector2i, int] = {}
	if not grid.contains(cell):
		return result
	result[cell] = NOSE_LIGHT
	var queue: Array[Vector2i] = [cell]
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		var next_level := result[at] - 1
		if next_level <= 0:
			continue
		for offset: Vector2i in NEIGHBOURS:
			var next := at + offset
			if grid.contains(next) and not grid.solid_at(next) \
				and result.get(next, 0) < next_level:
				result[next] = next_level
				queue.append(next)
	return result


func metrics() -> Dictionary:
	return {"light_chunks": _chunks.size(), "light_columns": _columns.size(),
		"light_builds": _builds, "max_light_ms": float(_max_usec) / 1000.0,
		"mean_light_ms": float(_total_usec) / maxf(1, _builds) / 1000.0}


func version(coordinate: Vector2i) -> int:
	return int(_chunks[coordinate]["version"]) if _chunks.has(coordinate) else 0


func is_current(grid: Grid, coordinate: Vector2i) -> bool:
	return _chunks.has(coordinate) \
		and _chunks[coordinate]["signature"] == _signature(grid, coordinate)


func _field(grid: Grid, coordinate: Vector2i) -> Dictionary:
	var signature := _signature(grid, coordinate)
	if _chunks.has(coordinate) and _chunks[coordinate]["signature"] == signature:
		return _chunks[coordinate]
	var start := Time.get_ticks_usec()
	var field := _build(grid, coordinate)
	field["signature"] = signature
	field["version"] = _builds + 1
	_chunks[coordinate] = field
	var elapsed := Time.get_ticks_usec() - start
	_builds += 1
	_total_usec += elapsed
	_max_usec = maxi(_max_usec, elapsed)
	return field


func _signature(grid: Grid, coordinate: Vector2i) -> PackedInt32Array:
	var origin := coordinate * Chunk.SIZE - Vector2i.ONE * PADDING
	var signature := PackedInt32Array()
	for column in range(origin.x, origin.x + SIDE):
		signature.append(clampi(_sky_cutoff(grid, column), origin.y, origin.y + SIDE))
	var first := Grid.chunk_coordinate(origin)
	var last := Grid.chunk_coordinate(origin + Vector2i.ONE * (SIDE - 1))
	for row in range(first.y, last.y + 1):
		for column in range(first.x, last.x + 1):
			var chunk: Chunk = grid.chunks.get(Vector2i(column, row))
			signature.append(chunk.revision if chunk != null else 0)
	return signature


func _sky_cutoff(grid: Grid, column: int) -> int:
	if column < 0 or column >= grid.width:
		return 0
	var revision: int = grid.column_revisions.get(column, 0)
	if _columns.has(column) and _columns[column]["revision"] == revision:
		return _columns[column]["cutoff"]
	var cutoff := grid.height
	for row in grid.height:
		var cell := Vector2i(column, row)
		if grid.solid_at(cell) or grid.get_block(cell, Chunk.BACK) != Blocks.AIR:
			cutoff = row
			break
	_columns[column] = {"revision": revision, "cutoff": cutoff}
	return cutoff


func _build(grid: Grid, coordinate: Vector2i) -> Dictionary:
	var origin := coordinate * Chunk.SIZE - Vector2i.ONE * PADDING
	var solid := PackedByteArray()
	var sky := PackedByteArray()
	var block := PackedByteArray()
	solid.resize(AREA)
	sky.resize(AREA)
	block.resize(AREA)
	var terrain := _terrain(grid, origin)
	var front: PackedInt32Array = terrain[0]
	var back: PackedInt32Array = terrain[1]
	var flags := PackedByteArray()
	var emission := PackedByteArray()
	for id in Blocks.COUNT:
		flags.append(int(Blocks.has_flag(id, Blocks.SOLID)))
		emission.append(int(Blocks.DATA[id]["light"]))
	for column in SIDE:
		var cutoff := _sky_cutoff(grid, origin.x + column)
		for row in SIDE:
			var index := column + row * SIDE
			solid[index] = flags[front[index]]
			sky[index] = MAX_LIGHT if origin.y + row < cutoff and solid[index] == 0 else 0
			block[index] = emission[front[index]]
			if solid[index] == 0:
				block[index] = maxi(block[index], emission[back[index]])
	_flood(sky, solid)
	_flood(block, solid)
	var result_sky := PackedByteArray()
	var result_block := PackedByteArray()
	var result_solid := PackedByteArray()
	var codes := PackedByteArray()
	for row in Chunk.SIZE:
		for column in Chunk.SIZE:
			var index := column + PADDING + (row + PADDING) * SIDE
			result_sky.append(sky[index])
			result_block.append(block[index])
			result_solid.append(solid[index])
			var surface_sky := sky[index]
			var surface_block := block[index]
			if solid[index] != 0:
				for offset: int in OFFSETS:
					surface_sky = maxi(surface_sky, sky[index + offset])
					surface_block = maxi(surface_block, block[index + offset])
			codes.append(surface_sky * 16 + surface_block)
	return {"sky": result_sky, "block": result_block, "solid": result_solid, "codes": codes}


func _terrain(grid: Grid, origin: Vector2i) -> Array[PackedInt32Array]:
	var front := PackedInt32Array()
	var back := PackedInt32Array()
	front.resize(AREA)
	back.resize(AREA)
	front.fill(Blocks.BEDROCK)
	for row in mini(SIDE, maxi(0, -origin.y)):
		for column in SIDE:
			if origin.x + column >= 0 and origin.x + column < grid.width:
				front[column + row * SIDE] = Blocks.AIR
	var first := Grid.chunk_coordinate(origin)
	var last := Grid.chunk_coordinate(origin + Vector2i.ONE * (SIDE - 1))
	var boundary := Grid.chunk_coordinate(Vector2i(grid.width - 1, grid.height - 1))
	for row in range(maxi(0, first.y), mini(last.y, boundary.y) + 1):
		for column in range(maxi(0, first.x), mini(last.x, boundary.x) + 1):
			var coordinate := Vector2i(column, row)
			var chunk := grid.chunk_at(coordinate)
			var source_front := chunk.front
			var source_back := chunk.back
			var start := (coordinate * Chunk.SIZE).max(origin)
			var end := (coordinate * Chunk.SIZE + Vector2i.ONE * Chunk.SIZE) \
				.min(origin + Vector2i.ONE * SIDE).min(Vector2i(grid.width, grid.height))
			for y in range(start.y, end.y):
				var source := start.x - coordinate.x * Chunk.SIZE + (y - coordinate.y * Chunk.SIZE) * Chunk.SIZE
				var destination := start.x - origin.x + (y - origin.y) * SIDE
				for x in end.x - start.x:
					front[destination + x] = source_front[source + x]
					back[destination + x] = source_back[source + x]
	return [front, back]


func _flood(levels: PackedByteArray, solid: PackedByteArray) -> void:
	if levels.count(MAX_LIGHT) == AREA:
		return
	var queue := PackedInt32Array()
	for index in AREA:
		if levels[index] > 1:
			queue.append(index)
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var next_level := levels[index] - 1
		if next_level <= 0:
			continue
		var column := index % SIDE
		for offset: int in OFFSETS:
			if (offset == -1 and column == 0) or (offset == 1 and column == SIDE - 1):
				continue
			var next := index + offset
			if next >= 0 and next < AREA and solid[next] == 0 and levels[next] < next_level:
				levels[next] = next_level
				queue.append(next)


func _raise_nose(codes: PackedByteArray, local: Vector2i, level: int) -> void:
	if _inside(local):
		var index := Chunk.index(local)
		codes[index] = (codes[index] & 0xf0) | maxi(codes[index] & 0x0f, level)


static func _inside(local: Vector2i) -> bool:
	return local.x >= 0 and local.x < Chunk.SIZE and local.y >= 0 and local.y < Chunk.SIZE
