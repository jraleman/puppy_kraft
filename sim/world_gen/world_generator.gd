extends RefCounted

## The original meadow generator is immutable once worlds record version PK1.

const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Layout = preload("res://games/puppy_kraft/sim/world_gen/layout.gd")
const Terrain = preload("res://games/puppy_kraft/sim/world_gen/terrain.gd")
const VERSION := "PK1"

var layout: Layout
var terrain: Terrain


func _init(seed: int = 0) -> void:
	layout = Layout.new(seed)
	terrain = Terrain.new(layout)


static func supports_version(version: String) -> bool:
	return version == VERSION


func block_at(cell: Vector2i, layer := Chunk.FRONT) -> int:
	var bed := layout.bed_cell
	var offset := cell - bed
	if offset.x >= -3 and offset.x <= 3 and offset.y >= -3 and offset.y <= 0:
		if layer == Chunk.BACK:
			return Blocks.WOOD
		if offset.y == -3 or (offset.x == -3 and offset.y >= -2) \
			or (offset.x == 3 and offset.y == -2):
			return Blocks.WOOD
		if offset == Vector2i.ZERO:
			return Blocks.BED
		return Blocks.AIR
	var root_x := layout.spawn_column + 8
	if cell.x == root_x and cell.y >= Layout.SURFACE_ROW - 5 \
		and cell.y < Layout.SURFACE_ROW and layer == Chunk.FRONT:
		return Blocks.ROOT
	if cell.y == Layout.SURFACE_ROW - 6 and abs(cell.x - root_x) <= 2 \
		and layer == Chunk.FRONT:
		return Blocks.LEAVES
	return terrain.block_at(cell, layer)


func fill_chunk(coordinate: Vector2i) -> Chunk:
	var chunk := Chunk.new(coordinate)
	var origin := coordinate * Chunk.SIZE
	for row in Chunk.SIZE:
		for column in Chunk.SIZE:
			var local := Vector2i(column, row)
			var cell := origin + local
			var index := Chunk.index(local)
			chunk.front[index] = block_at(cell, Chunk.FRONT)
			chunk.back[index] = block_at(cell, Chunk.BACK)
	return chunk
