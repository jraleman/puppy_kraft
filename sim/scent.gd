extends RefCounted

## Resource trails ignore walls; revisioned chunk indexes avoid rescanning every cell.

const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")
const BASE_RANGE := 48.0
const OUTLINE_RANGE := 6.0
const REFRESH_TICKS := 6
const KINDS: Array[String] = ["crystal", "home"]
const STYLES := {
	"crystal": {"icon": "ORE", "shape": "zigzag", "color": Color("85e5ee")},
	"home": {"icon": "HOME", "shape": "pawprints", "color": Color("ffd889")},
}

var trails: Array[Dictionary] = []
var outlines: Array[Dictionary] = []
var range_cells := BASE_RANGE
var _grid: Grid
var _indexes: Dictionary[Vector2i, Dictionary] = {}
var _block_kinds := PackedInt32Array()


func _init() -> void:
	for block: Dictionary in Blocks.DATA:
		_block_kinds.append(KINDS.find(str(block["scent"])))


func scan(grid: Grid, origin: Vector2, night: bool = false,
	range_multiplier: float = 1.0) -> void:
	assert(origin.is_finite() and is_finite(range_multiplier) and range_multiplier > 0.0,
		"Scent queries need a finite origin and a positive range multiplier.")
	if _grid != grid:
		_grid = grid
		_indexes.clear()
	clear()
	range_cells = BASE_RANGE * range_multiplier * (2.0 if night else 1.0)
	var first := Grid.chunk_coordinate(Vector2i((origin - Vector2.ONE * range_cells).floor()))
	var last := Grid.chunk_coordinate(Vector2i((origin + Vector2.ONE * range_cells).floor()))
	first = first.max(Vector2i.ZERO)
	last = last.min(Grid.chunk_coordinate(Vector2i(grid.width - 1, grid.height - 1)))
	var nearest: Dictionary[String, Dictionary] = {}
	var outlined: Dictionary[Vector2i, bool] = {}
	for row in range(first.y, last.y + 1):
		for column in range(first.x, last.x + 1):
			var coordinate := Vector2i(column, row)
			var chunk := grid.chunk_at(coordinate)
			for encoded: int in _sources(chunk):
				var layer := encoded / Chunk.CELLS
				var index := encoded % Chunk.CELLS
				var cell := coordinate * Chunk.SIZE + Vector2i(index % Chunk.SIZE,
					index / Chunk.SIZE)
				var distance := origin.distance_squared_to(Vector2(cell) + Vector2.ONE * 0.5)
				if not grid.contains(cell) or distance > range_cells * range_cells:
					continue
				var block := chunk.front[index] if layer == Chunk.FRONT else chunk.back[index]
				var kind := KINDS[_block_kinds[block]]
				var source := {
					"kind": kind, "cell": cell, "layer": layer, "block": block,
					"distance_squared": distance,
				}
				if not nearest.has(kind) or _nearer(source, nearest[kind]):
					nearest[kind] = source
				if kind == "crystal" and distance <= OUTLINE_RANGE * OUTLINE_RANGE \
					and not outlined.has(cell) and _buried(cell, layer):
					outlined[cell] = true
					outlines.append(source)
	for kind: String in KINDS:
		if nearest.has(kind):
			trails.append(nearest[kind])
	trails.sort_custom(_nearer)
	outlines.sort_custom(_nearer)


func clear() -> void:
	trails.clear()
	outlines.clear()


func caption(origin: Vector2) -> String:
	if trails.is_empty():
		return "Sniffing: no crystal, glow moss or home scent within %d cells." % range_cells
	var source := trails[0]
	var title := "home" if str(source["kind"]) == "home" \
		else Blocks.title(int(source["block"])).to_lower()
	var offset := Vector2(source["cell"]) + Vector2.ONE * 0.5 - origin
	var direction := direction_caption(offset)
	var layer := " / back wall" if int(source["layer"]) == Chunk.BACK else ""
	return "Strong scent: %s, %s%s." % [title, direction, layer]


static func direction_caption(offset: Vector2) -> String:
	var vertical := ""
	var horizontal := ""
	if absf(offset.y) > 0.75:
		vertical = "up" if offset.y < 0.0 else "down"
	if absf(offset.x) > 0.75:
		horizontal = "to the left" if offset.x < 0.0 else "to the right"
	if not vertical.is_empty() and not horizontal.is_empty():
		return vertical + " and " + horizontal
	if not vertical.is_empty():
		return vertical
	return horizontal if not horizontal.is_empty() else "right here"


func _sources(chunk: Chunk) -> PackedInt32Array:
	var coordinate := chunk.coordinate
	if not _indexes.has(coordinate) or int(_indexes[coordinate]["revision"]) != chunk.revision:
		var sources := PackedInt32Array()
		for layer in 2:
			var blocks := chunk.front if layer == Chunk.FRONT else chunk.back
			for index in Chunk.CELLS:
				if _block_kinds[blocks[index]] >= 0:
					sources.append(index + layer * Chunk.CELLS)
		_indexes[coordinate] = {"revision": chunk.revision, "sources": sources}
	return _indexes[coordinate]["sources"]


func _buried(cell: Vector2i, layer: int) -> bool:
	if layer == Chunk.BACK:
		return _grid.solid_at(cell)
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not _grid.solid_at(cell + offset):
			return false
	return true


static func _nearer(a: Dictionary, b: Dictionary) -> bool:
	if float(a["distance_squared"]) != float(b["distance_squared"]):
		return float(a["distance_squared"]) < float(b["distance_squared"])
	if str(a["kind"]) != str(b["kind"]):
		return KINDS.find(str(a["kind"])) < KINDS.find(str(b["kind"]))
	var a_cell: Vector2i = a["cell"]
	var b_cell: Vector2i = b["cell"]
	if a_cell.y != b_cell.y:
		return a_cell.y < b_cell.y
	if a_cell.x != b_cell.x:
		return a_cell.x < b_cell.x
	return int(a["layer"]) < int(b["layer"])
