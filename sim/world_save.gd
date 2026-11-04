extends RefCounted

## Checked ConfigFile snapshots with bounded compressed deltas and atomic replacement.

const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")
const Generator = preload("res://games/puppy_kraft/sim/world_gen/world_generator.gd")
const Layout = preload("res://games/puppy_kraft/sim/world_gen/layout.gd")
const Seeds = preload("res://games/puppy_kraft/sim/seed_words.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const FORMAT_VERSION := 1
const SLOT_COUNT := 3
const MAX_FILE_BYTES := 8 * 1024 * 1024
const MAX_DELTA_BYTES := Chunk.CELLS * 2 * 12

var directory := "user://"


func _init(root: String = "user://") -> void:
	directory = root


func slot_path(slot: int) -> String:
	assert(slot >= 1 and slot <= SLOT_COUNT, "There are exactly three world slots.")
	return directory.path_join("puppy_kraft_world_%d.cfg" % slot)


func exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func create_slot(slot: int, world: World) -> Dictionary:
	if exists(slot):
		return _failure(ERR_ALREADY_EXISTS, "That world slot is already occupied.")
	return write_slot(slot, world)


func write_slot(slot: int, world: World) -> Dictionary:
	var path := slot_path(slot)
	if exists(slot):
		var existing := _read_config(path)
		if int(existing["error"]) != OK:
			return existing
		var config: ConfigFile = existing["config"]
		if int(config.get_value("header", "seed")) != world.grid.generator.layout.seed_value \
			or int(config.get_value("header", "created_unix")) != world.created_unix:
			return _failure(ERR_ALREADY_EXISTS, "This slot now contains a different world.")
	var snapshot := _snapshot(world)
	var text := snapshot.encode_to_text()
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return _failure(ERR_OUT_OF_MEMORY, "The world exceeds the save-file safety limit.")
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return _failure(error, "Could not create the world-save directory.")
	var temporary := path.get_basename() + ".tmp"
	error = snapshot.save(temporary)
	if error != OK:
		return _failure(error, "Could not write the temporary world file. The old save is intact.")
	error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		return _failure(error, "Could not replace the world file. The old save is intact.")
	return {"error": OK}


func read_slot(slot: int) -> Dictionary:
	var result := _read_config(slot_path(slot))
	if int(result["error"]) != OK:
		return result
	var config: ConfigFile = result["config"]
	var world := World.new(
		int(config.get_value("header", "seed")), str(config.get_value("pup", "name")),
		int(config.get_value("header", "created_unix"))
	)
	world.ticks = int(config.get_value("header", "ticks"))
	world.points_pending = int(config.get_value("header", "pending_points"))
	world.blocks_dug = int(config.get_value("outing", "blocks_dug"))
	world.blocks_placed = int(config.get_value("outing", "blocks_placed"))
	world.outing_open = bool(config.get_value("outing", "open"))
	world.selected_block = int(config.get_value("pup", "selected_block"))
	world.inventory = config.get_value("pup", "inventory")
	world.accumulator = float(config.get_value("world", "accumulator"))
	var body: Dictionary = config.get_value("pup", "body")
	world.body.position = body["position"]
	world.body.velocity = body["velocity"]
	world.body.facing = int(body["facing"])
	world.body.grounded = bool(body["grounded"])
	world.body.climbing = bool(body["climbing"])
	world.body.coyote_ticks = int(body["coyote_ticks"])
	world.body.jump_buffer_ticks = int(body["jump_buffer_ticks"])
	for section in config.get_sections():
		if section.begins_with("chunk/"):
			var problem := _restore_chunk(world.grid, config, section)
			if not problem.is_empty():
				return _failure(ERR_FILE_CORRUPT, problem)
		else:
			world.retained_fields[section] = {}
			for key in config.get_section_keys(section):
				world.retained_fields[section][key] = config.get_value(section, key)
	if world.grid.overlaps_solid(world.body.bounds()):
		return _failure(ERR_FILE_CORRUPT, "The saved pup is inside a solid block.")
	return {"error": OK, "world": world}


func summary(slot: int) -> Dictionary:
	if not exists(slot):
		return {"exists": false}
	var result := _read_config(slot_path(slot))
	if int(result["error"]) != OK:
		return {"exists": true, "valid": false, "message": str(result["message"])}
	var config: ConfigFile = result["config"]
	return {
		"exists": true, "valid": true, "pup_name": str(config.get_value("pup", "name")),
		"seed_words": str(config.get_value("header", "seed_words")),
		"generator": str(config.get_value("header", "generator_version")),
		"day": int(config.get_value("header", "day")),
		"play_seconds": float(config.get_value("header", "ticks")) * Body.STEP,
	}


func delete_slot(slot: int) -> Dictionary:
	var path := slot_path(slot)
	var error := DirAccess.remove_absolute(path)
	if error != OK:
		return _failure(error, "Could not delete the world.")
	var temporary := path.get_basename() + ".tmp"
	if FileAccess.file_exists(temporary):
		error = DirAccess.remove_absolute(temporary)
		if error != OK:
			return _failure(error, "The world was deleted, but its unfinished temporary file remains.")
	return {"error": OK}


func _snapshot(world: World) -> ConfigFile:
	var config := ConfigFile.new()
	# Retain unknown same-format fields rather than erasing later additive state.
	for section: String in world.retained_fields:
		for key: String in world.retained_fields[section]:
			config.set_value(section, key, world.retained_fields[section][key])
	config.set_value("header", "format_version", FORMAT_VERSION)
	config.set_value("header", "generator_version", Generator.VERSION)
	config.set_value("header", "seed", world.grid.generator.layout.seed_value)
	config.set_value("header", "seed_words", Seeds.to_words(world.grid.generator.layout.seed_value))
	config.set_value("header", "width", world.grid.width)
	config.set_value("header", "height", world.grid.height)
	config.set_value("header", "created_unix", world.created_unix)
	config.set_value("header", "ticks", world.ticks)
	config.set_value("header", "day", world.day_number())
	config.set_value("header", "pending_points", world.points_pending)
	config.set_value("pup", "name", world.pup_name)
	config.set_value("pup", "body", world.body.snapshot())
	config.set_value("pup", "inventory", world.inventory)
	config.set_value("pup", "selected_block", world.selected_block)
	config.set_value("world", "accumulator", world.accumulator)
	config.set_value("outing", "blocks_dug", world.blocks_dug)
	config.set_value("outing", "blocks_placed", world.blocks_placed)
	config.set_value("outing", "open", world.outing_open)
	var coordinates := world.grid.edits.keys()
	coordinates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for coordinate: Vector2i in coordinates:
		var encoded := _encode_delta(world.grid.edits[coordinate])
		var section := "chunk/%d/%d" % [coordinate.x, coordinate.y]
		config.set_value(section, "raw_size", encoded.size())
		config.set_value(section, "data", encoded.compress(FileAccess.COMPRESSION_DEFLATE))
		config.set_value(section, "sha256", encoded.hex_encode().sha256_text())
	return config


func _encode_delta(edits: Dictionary) -> PackedByteArray:
	var indices := edits.keys()
	indices.sort()
	var runs := PackedInt32Array()
	var offset := 0
	while offset < indices.size():
		var first := int(indices[offset])
		var id := int(edits[first])
		var length := 1
		while offset + length < indices.size() \
			and int(indices[offset + length]) == first + length \
			and int(edits[indices[offset + length]]) == id:
			length += 1
		runs.append(first)
		runs.append(length)
		runs.append(id)
		offset += length
	return runs.to_byte_array()


func _restore_chunk(grid: Grid, config: ConfigFile, section: String) -> String:
	var parts := section.split("/")
	if parts.size() != 3 or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return "Invalid chunk coordinates."
	var coordinate := Vector2i(int(parts[1]), int(parts[2]))
	if not grid.contains(coordinate * Chunk.SIZE):
		return "A saved chunk is outside the world."
	var raw_size: Variant = config.get_value(section, "raw_size", null)
	var compressed: Variant = config.get_value(section, "data", null)
	var checksum: Variant = config.get_value(section, "sha256", null)
	if typeof(raw_size) != TYPE_INT or typeof(compressed) != TYPE_PACKED_BYTE_ARRAY \
		or typeof(checksum) != TYPE_STRING:
		return "A chunk delta has invalid fields."
	var size := int(raw_size)
	var bytes: PackedByteArray = compressed
	if size <= 0 or size > MAX_DELTA_BYTES or size % 12 != 0 \
		or bytes.is_empty() or bytes.size() > MAX_DELTA_BYTES:
		return "A chunk delta has an invalid size."
	var decoded := bytes.decompress(size, FileAccess.COMPRESSION_DEFLATE)
	if decoded.size() != size or decoded.hex_encode().sha256_text() != str(checksum):
		return "A chunk delta failed its integrity check."
	var runs := decoded.to_int32_array()
	var previous_end := 0
	for offset in range(0, runs.size(), 3):
		var start := runs[offset]
		var length := runs[offset + 1]
		var id := runs[offset + 2]
		if start < previous_end or length <= 0 or start + length > Chunk.CELLS * 2 \
			or not Blocks.is_valid(id):
			return "A chunk delta contains an invalid run."
		previous_end = start + length
		for index in range(start, start + length):
			var layer := Chunk.FRONT if index < Chunk.CELLS else Chunk.BACK
			var local_index := index % Chunk.CELLS
			var cell := coordinate * Chunk.SIZE + Vector2i(
				local_index % Chunk.SIZE, floori(float(local_index) / Chunk.SIZE)
			)
			if grid.set_block(cell, id, layer) != OK:
				return "A chunk delta contains an invalid block layer."
	return ""


func _read_config(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(FileAccess.get_open_error(), "Could not open the world file.")
	var length := file.get_length()
	file.close()
	if length > MAX_FILE_BYTES:
		return _failure(ERR_FILE_CORRUPT, "The world file exceeds the safety limit.")
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		return _failure(error, "Could not read the world file.")
	var problem := _validate_header(config)
	if not problem.is_empty():
		return _failure(ERR_FILE_UNRECOGNIZED, problem)
	problem = _validate_state(config)
	if not problem.is_empty():
		return _failure(ERR_FILE_CORRUPT, problem)
	return {"error": OK, "config": config}


func _validate_header(config: ConfigFile) -> String:
	if typeof(config.get_value("header", "format_version", null)) != TYPE_INT \
		or int(config.get_value("header", "format_version")) != FORMAT_VERSION:
		return "This world uses an unsupported save format."
	var version: Variant = config.get_value("header", "generator_version", null)
	if typeof(version) != TYPE_STRING or not Generator.supports_version(str(version)):
		return "This world requires an unavailable generator version."
	for key in ["seed", "width", "height", "created_unix", "ticks", "day", "pending_points"]:
		if typeof(config.get_value("header", key, null)) != TYPE_INT:
			return "The world header has an invalid %s." % key
	if int(config.get_value("header", "width")) != Layout.WIDTH \
		or int(config.get_value("header", "height")) != Layout.HEIGHT:
		return "This generator does not support the saved world size."
	for key in ["created_unix", "ticks", "pending_points"]:
		if int(config.get_value("header", key)) < 0:
			return "The world header has a negative %s." % key
	var words: Variant = config.get_value("header", "seed_words", null)
	if typeof(words) != TYPE_STRING \
		or str(words) != Seeds.to_words(int(config.get_value("header", "seed"))):
		return "The seed words do not match the saved seed."
	var expected_day := 1 + floori(float(config.get_value("header", "ticks")) / World.DAY_TICKS)
	if int(config.get_value("header", "day")) != expected_day:
		return "The saved day does not match the world clock."
	return ""


func _validate_state(config: ConfigFile) -> String:
	var name: Variant = config.get_value("pup", "name", null)
	if typeof(name) != TYPE_STRING or str(name).strip_edges().is_empty() \
		or str(name).length() > 32:
		return "The pup's name is invalid."
	var inventory: Variant = config.get_value("pup", "inventory", null)
	if typeof(inventory) != TYPE_PACKED_INT32_ARRAY \
		or (inventory as PackedInt32Array).size() != Blocks.COUNT:
		return "The building bag has invalid contents."
	for count: int in inventory:
		if count < 0:
			return "The building bag has a negative material count."
	var selected: Variant = config.get_value("pup", "selected_block", null)
	if typeof(selected) != TYPE_INT or int(selected) not in Blocks.BUILDING_BLOCKS:
		return "The selected building block is invalid."
	var raw_body: Variant = config.get_value("pup", "body", null)
	if typeof(raw_body) != TYPE_DICTIONARY:
		return "The pup's body state is missing."
	var body: Dictionary = raw_body
	for key in ["position", "velocity"]:
		if typeof(body.get(key)) != TYPE_VECTOR2 or not (body[key] as Vector2).is_finite():
			return "The pup's %s is invalid." % key
	var position: Vector2 = body["position"]
	var velocity: Vector2 = body["velocity"]
	if position.x < Body.SIZE.x * 0.5 or position.x > Layout.WIDTH - Body.SIZE.x * 0.5 \
		or position.y < -Layout.HEIGHT or position.y > Layout.HEIGHT - Body.SIZE.y * 0.5:
		return "The pup's position is outside the world."
	if absf(velocity.x) > Body.RUN_SPEED + 0.01 \
		or velocity.y < -Body.JUMP_SPEED - 0.01 or velocity.y > Body.MAX_FALL_SPEED + 0.01:
		return "The pup's velocity is outside the supported limits."
	if typeof(body.get("facing")) != TYPE_INT or int(body["facing"]) not in [-1, 1]:
		return "The pup's facing direction is invalid."
	for key in ["grounded", "climbing"]:
		if typeof(body.get(key)) != TYPE_BOOL:
			return "The pup's contact state is invalid."
	for key in ["coyote_ticks", "jump_buffer_ticks"]:
		if typeof(body.get(key)) != TYPE_INT or int(body[key]) < 0 \
			or int(body[key]) > Body.JUMP_BUFFER_TICKS:
			return "The pup's jump timing is invalid."
	for key in ["blocks_dug", "blocks_placed"]:
		var value: Variant = config.get_value("outing", key, null)
		if typeof(value) != TYPE_INT or int(value) < 0:
			return "The outing's building totals are invalid."
	if typeof(config.get_value("outing", "open", null)) != TYPE_BOOL:
		return "The outing's state is invalid."
	var accumulator: Variant = config.get_value("world", "accumulator", null)
	if typeof(accumulator) not in [TYPE_FLOAT, TYPE_INT] \
		or not is_finite(float(accumulator)) or float(accumulator) < 0.0 \
		or float(accumulator) >= Body.STEP + 0.000000001:
		return "The world's fixed-step remainder is invalid."
	return ""


static func _failure(error: Error, message: String) -> Dictionary:
	return {"error": error, "message": "%s (%s)" % [message, error_string(error)]}
