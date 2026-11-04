extends SceneTree

## Fifty seeds exercise lazy fill order, flat safe spawn and the immutable PK1 contract.

const Generator = preload("res://games/puppy_kraft/sim/world_gen/world_generator.gd")
const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")
const Layout = preload("res://games/puppy_kraft/sim/world_gen/layout.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	var coordinates: Array[Vector2i] = [
		Vector2i(23, 3), Vector2i(24, 3), Vector2i(24, 5), Vector2i(0, 0), Vector2i(47, 9),
	]
	for seed in 50:
		var a := Grid.new(seed)
		var b := Grid.new(seed)
		_expect(a.chunks.is_empty() and a.edits.is_empty(),
			"Creating the layout must not eagerly allocate the finite world.")
		for coordinate in coordinates:
			a.chunk_at(coordinate)
		var reverse := coordinates.duplicate()
		reverse.reverse()
		for coordinate in reverse:
			b.chunk_at(coordinate)
		for coordinate in coordinates:
			_expect(a.chunks[coordinate].front == b.chunks[coordinate].front
				and a.chunks[coordinate].back == b.chunks[coordinate].back,
				"Seed %d must have byte-identical layers regardless of lazy fill order." % seed)
		for column in range(Layout.WIDTH / 2 - Layout.FLAT_RADIUS,
			Layout.WIDTH / 2 + Layout.FLAT_RADIUS + 1):
			_expect(a.generator.terrain.surface_row(column) == Layout.SURFACE_ROW,
				"Every tested seed must have a flat starting meadow.")
		var body := Body.new(a.generator.layout.spawn_position())
		_expect(not a.overlaps_solid(body.bounds()),
			"Every tested spawn must leave room for the real puppy body.")
		_expect(a.generator.layout.bed_cell.distance_to(Vector2i(body.position.floor())) < 10,
			"The starting bed must remain close to spawn.")
		_expect(a.edits.is_empty(), "Generating and reading terrain must never create save deltas.")
	var original := Generator.new(42).fill_chunk(Vector2i(24, 3))
	var bytes := original.front.to_byte_array()
	bytes.append_array(original.back.to_byte_array())
	_expect(bytes.hex_encode().sha256_text()
		== "ec3862ecf6962fdd20ab5cba4d2e31f78931981ed8c97b554510a4ba24876b31",
		"PK1's saved-world terrain fingerprint must never change; add a new generator instead.")
	_expect(Generator.supports_version("PK1") and not Generator.supports_version("PK99"),
		"Unavailable generator versions must be refused, never interpreted as the latest one.")
	if _failures.is_empty():
		print("Puppy Kraft world-generation tests passed (50 seeds).")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
