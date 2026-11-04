extends RefCounted

## PK1's small eager layout; later biomes require a new generator, not changed PK1.

const WIDTH := 1536
const HEIGHT := 320
const SURFACE_ROW := 100
const FLAT_RADIUS := 18

var seed_value := 0
var spawn_column := WIDTH / 2
var bed_cell := Vector2i.ZERO
var biome_bands: Array[Dictionary] = []
var structure_sites: Array[Dictionary] = []


func _init(seed: int = 0) -> void:
	seed_value = seed
	bed_cell = Vector2i(spawn_column - 6, SURFACE_ROW - 1)
	biome_bands = [{"id": "sunny_meadows", "from": 0, "to": WIDTH}]
	structure_sites = [
		{"id": "starting_kennel", "at": bed_cell},
		{"id": "pack_shrine", "at": Vector2i(spawn_column + 12, SURFACE_ROW - 1)},
	]


func spawn_position() -> Vector2:
	return Vector2(float(spawn_column) + 0.5, float(SURFACE_ROW) - 0.4)
