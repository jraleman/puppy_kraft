extends RefCounted

## Lazy chunks and reversible edits; loading and meshing never change the terrain.

const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Generator = preload("res://games/puppy_kraft/sim/world_gen/world_generator.gd")
const Layout = preload("res://games/puppy_kraft/sim/world_gen/layout.gd")
# Vector2 precision at the far edge needs more than a 0.00001-cell contact inset.
const CONTACT_EPSILON := 0.001

var generator: Generator
var chunks: Dictionary[Vector2i, Chunk] = {}
var edits: Dictionary[Vector2i, Dictionary] = {}
var dirty_chunks: Dictionary[Vector2i, bool] = {}
var revision := 0
var column_revisions: Dictionary[int, int] = {}
var width := Layout.WIDTH
var height := Layout.HEIGHT


func _init(seed: int = 0) -> void:
	generator = Generator.new(seed)


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height


static func chunk_coordinate(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / Chunk.SIZE), floori(float(cell.y) / Chunk.SIZE))


func chunk_at(coordinate: Vector2i) -> Chunk:
	assert(coordinate.x >= 0 and coordinate.y >= 0
		and coordinate.x * Chunk.SIZE < width and coordinate.y * Chunk.SIZE < height,
		"Only in-world chunks may be loaded.")
	if not chunks.has(coordinate):
		chunks[coordinate] = generator.fill_chunk(coordinate)
		dirty_chunks[coordinate] = true
	return chunks[coordinate]


func get_block(cell: Vector2i, layer := Chunk.FRONT) -> int:
	if not contains(cell):
		if layer == Chunk.BACK:
			return Blocks.AIR
		if cell.x < 0 or cell.x >= width:
			return Blocks.BEDROCK
		return Blocks.AIR if cell.y < 0 else Blocks.BEDROCK
	var coordinate := chunk_coordinate(cell)
	return chunk_at(coordinate).get_block(cell - coordinate * Chunk.SIZE, layer)


func set_block(cell: Vector2i, id: int, layer := Chunk.FRONT) -> Error:
	if not contains(cell) or not Blocks.is_valid(id) or layer not in [Chunk.FRONT, Chunk.BACK]:
		return ERR_INVALID_PARAMETER
	if layer == Chunk.BACK and not Blocks.has_flag(id, Blocks.PLACEABLE_BACK):
		return ERR_INVALID_PARAMETER
	var coordinate := chunk_coordinate(cell)
	var local := cell - coordinate * Chunk.SIZE
	var chunk := chunk_at(coordinate)
	if chunk.get_block(local, layer) == id:
		return OK
	chunk.set_block(local, id, layer)
	revision += 1
	column_revisions[cell.x] = column_revisions.get(cell.x, 0) + 1
	var index := Chunk.index(local) + layer * Chunk.CELLS
	if id == generator.block_at(cell, layer):
		if edits.has(coordinate):
			edits[coordinate].erase(index)
			if edits[coordinate].is_empty():
				edits.erase(coordinate)
	else:
		if not edits.has(coordinate):
			edits[coordinate] = {}
		edits[coordinate][index] = id
	dirty_chunks[coordinate] = true
	if local.x == 0:
		_mark_dirty(coordinate + Vector2i.LEFT)
	if local.x == Chunk.SIZE - 1:
		_mark_dirty(coordinate + Vector2i.RIGHT)
	if local.y == 0:
		_mark_dirty(coordinate + Vector2i.UP)
	if local.y == Chunk.SIZE - 1:
		_mark_dirty(coordinate + Vector2i.DOWN)
	return OK


func solid_at(cell: Vector2i) -> bool:
	return Blocks.has_flag(get_block(cell), Blocks.SOLID)


func overlaps_solid(box: Rect2) -> bool:
	var first := Vector2i((box.position + Vector2.ONE * CONTACT_EPSILON).floor())
	var last := Vector2i((box.end - Vector2.ONE * CONTACT_EPSILON).floor())
	for row in range(first.y, last.y + 1):
		for column in range(first.x, last.x + 1):
			if solid_at(Vector2i(column, row)):
				return true
	return false


## Fixed actors move less than one cell per step, so contacts cannot skip a tile.
func move_box_axis(at: Vector2, size: Vector2, axis: int, distance: float) -> Vector2:
	assert(is_finite(distance) and absf(distance) < 1.0, "Use sub-cell collision steps.")
	if distance == 0.0:
		return at
	at[axis] += distance
	var box := Rect2(at - size * 0.5, size)
	var first := Vector2i((box.position + Vector2.ONE * CONTACT_EPSILON).floor())
	var last := Vector2i((box.end - Vector2.ONE * CONTACT_EPSILON).floor())
	var limit := at[axis]
	for row in range(first.y, last.y + 1):
		for column in range(first.x, last.x + 1):
			var cell := Vector2i(column, row)
			if not solid_at(cell):
				continue
			if distance > 0.0:
				limit = minf(limit, float(cell[axis]) - size[axis] * 0.5)
			else:
				limit = maxf(limit, float(cell[axis] + 1) + size[axis] * 0.5)
	at[axis] = limit
	return at


## Only barks ignore foliage; pickups use the default solid obstruction policy.
func clear_line(origin: Vector2, target: Vector2, transparent_block: int = Blocks.AIR) -> bool:
	var at := Vector2i(origin.floor())
	var last := Vector2i(target.floor())
	var ray := target - origin
	var step := Vector2i(int(signf(ray.x)), int(signf(ray.y)))
	var interval := Vector2(INF if ray.x == 0.0 else absf(1.0 / ray.x),
		INF if ray.y == 0.0 else absf(1.0 / ray.y))
	var next := Vector2(INF, INF)
	if step.x != 0:
		next.x = (float(at.x + 1) - origin.x) * interval.x if step.x > 0 \
			else (origin.x - float(at.x)) * interval.x
	if step.y != 0:
		next.y = (float(at.y + 1) - origin.y) * interval.y if step.y > 0 \
			else (origin.y - float(at.y)) * interval.y
	while true:
		if solid_at(at) and get_block(at) != transparent_block:
			return false
		if at == last:
			return true
		if next.x < next.y:
			at.x += step.x
			next.x += interval.x
		else:
			at.y += step.y
			next.y += interval.y
	return false


func mark_clean(coordinate: Vector2i) -> void:
	dirty_chunks.erase(coordinate)
	if chunks.has(coordinate):
		chunks[coordinate].dirty = false


func _mark_dirty(coordinate: Vector2i) -> void:
	if coordinate.x >= 0 and coordinate.y >= 0 and coordinate.x * Chunk.SIZE < width \
		and coordinate.y * Chunk.SIZE < height:
		dirty_chunks[coordinate] = true
		if chunks.has(coordinate):
			chunks[coordinate].dirty = true
