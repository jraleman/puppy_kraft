extends RefCounted

## Seeded noise samples are cell-local: generating neighbours first changes nothing.

const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Layout = preload("res://games/puppy_kraft/sim/world_gen/layout.gd")

var layout: Layout
var _surface := FastNoiseLite.new()
var _caves := FastNoiseLite.new()
var _ore := FastNoiseLite.new()


func _init(world_layout: Layout) -> void:
	layout = world_layout
	var folded_seed := int((layout.seed_value ^ (layout.seed_value >> 32)) & 0x7fffffff)
	_surface.seed = folded_seed
	_surface.frequency = 0.018
	_surface.fractal_octaves = 2
	_caves.seed = folded_seed ^ 0x51c37
	_caves.frequency = 0.065
	_caves.fractal_octaves = 2
	_ore.seed = folded_seed ^ 0x19ab3
	_ore.frequency = 0.16
	_ore.fractal_octaves = 1


func surface_row(column: int) -> int:
	var distance := absf(float(column - layout.spawn_column))
	var blend := clampf((distance - Layout.FLAT_RADIUS) / 24.0, 0.0, 1.0)
	return Layout.SURFACE_ROW + roundi(_surface.get_noise_1d(column) * 14.0 * blend)


func block_at(cell: Vector2i, layer: int) -> int:
	if cell.y == Layout.HEIGHT - 1 or cell.x == 0 or cell.x == Layout.WIDTH - 1:
		return Blocks.BEDROCK if layer == 0 else Blocks.AIR
	var surface := surface_row(cell.x)
	var depth := cell.y - surface
	if layer == 1:
		if depth < 0:
			return Blocks.AIR
		return Blocks.MEADOW_SOIL if depth < 8 else Blocks.STONE
	if depth < 0:
		return Blocks.AIR
	if depth == 0:
		return Blocks.GRASS
	if depth < 5:
		return Blocks.MEADOW_SOIL
	if depth < 9:
		return Blocks.CLAY
	if depth > 12 and _caves.get_noise_2d(cell.x, cell.y) > 0.24:
		return Blocks.AIR
	if cell.y >= 160 and _ore.get_noise_2d(cell.x, cell.y) > 0.45:
		return Blocks.CRYSTAL
	if depth > 12 and _caves.get_noise_2d(cell.x, cell.y) > 0.20 \
		and _ore.get_noise_2d(cell.x, cell.y) < -0.35:
		return Blocks.GLOW_MOSS
	return Blocks.STONE
