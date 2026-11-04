extends SceneTree

## Delta round trips, retained fields, pending points and failure-safe atomic saves.

const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Saves = preload("res://games/puppy_kraft/sim/world_save.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")

var _failures := PackedStringArray()
var _directory := ""
var _saves: Saves


func _initialize() -> void:
	_directory = "user://puppy_kraft_save_test_%d" % OS.get_process_id()
	_saves = Saves.new(_directory)
	_test_round_trip()
	_test_transient_sniff_state()
	_test_bark_state_and_legacy()
	_test_rejected_bark_state()
	_test_atomic_write()
	_test_rejected_versions_and_corruption()
	_cleanup()
	if _failures.is_empty():
		print("Puppy Kraft world-save tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_round_trip() -> void:
	var world := World.new(-92733528913, "Scout", 42)
	_expect(int(_saves.create_slot(1, world)["error"]) == OK, "A new world must save immediately.")
	var fresh_bytes := FileAccess.get_file_as_bytes(_saves.slot_path(1)).size()
	_expect(fresh_bytes < 4096, "A fresh world must be a few KB, not serialized generated chunks.")
	for row in range(120, 130):
		assert(world.grid.set_block(Vector2i(790, row), Blocks.AIR) == OK)
	assert(world.grid.set_block(Vector2i(790, 120), Blocks.WOOD, Chunk.BACK) == OK)
	var restored := Vector2i(789, 125)
	var baseline := world.grid.get_block(restored)
	assert(world.grid.set_block(restored, Blocks.WOOD) == OK)
	assert(world.grid.set_block(restored, baseline) == OK)
	world.inventory[Blocks.STONE] = 55
	world.selected_block = Blocks.LADDER
	world.points_pending = 73
	world.blocks_dug = 8
	world.blocks_placed = 4
	world.retained_fields = {"future_neighbours": {"friendship": {"rabbit": 2}}}
	var held := Frame.new()
	held.move = 0.5
	world.advance(Body.STEP * 1.5, held)
	_expect(int(_saves.write_slot(1, world)["error"]) == OK,
		"An existing world must be atomically replaceable on Windows.")
	var result := _saves.read_slot(1)
	_expect(int(result["error"]) == OK, "A saved edited world must be readable.")
	if int(result["error"]) != OK:
		return
	var loaded: World = result["world"]
	_expect(loaded.grid.edits == world.grid.edits and loaded.inventory == world.inventory,
		"Both changed layers and building materials must round-trip exactly.")
	_expect(loaded.body.snapshot() == world.body.snapshot()
		and absf(loaded.accumulator - world.accumulator) < 0.00000001,
		"The pup and fixed-step remainder must round-trip, including midair/moving state.")
	_expect(loaded.pup_name == "Scout" and loaded.points_pending == 73
		and loaded.blocks_dug == 8 and loaded.blocks_placed == 4 and loaded.outing_open,
		"Quitting must retain the named pup, unpaid points and unfinished outing totals.")
	_expect(loaded.retained_fields["future_neighbours"]["friendship"] == {"rabbit": 2},
		"Reading a same-format save must retain unknown additive world state.")
	world.advance(Body.STEP, held)
	loaded.advance(Body.STEP, held)
	_expect(loaded.body.snapshot() == world.body.snapshot() and loaded.ticks == world.ticks,
		"Continuing a loaded fixed-step world must match uninterrupted play.")
	_expect(int(_saves.write_slot(1, loaded)["error"]) == OK,
		"A loaded world's retained fields must survive its next autosave.")
	var config := ConfigFile.new()
	assert(config.load(_saves.slot_path(1)) == OK)
	_expect(config.get_value("future_neighbours", "friendship") == {"rabbit": 2},
		"Autosaving must not discard newer same-format fields.")
	_expect(int(_saves.create_slot(1, World.new(7))["error"]) == ERR_ALREADY_EXISTS,
		"New-world creation must never overwrite an occupied slot.")
	print("Fresh world bytes: ", fresh_bytes,
		"; edited world bytes: ", FileAccess.get_file_as_bytes(_saves.slot_path(1)).size())


func _test_atomic_write() -> void:
	var path := _saves.slot_path(1)
	var before := FileAccess.get_file_as_bytes(path)
	var result := _saves.read_slot(1)
	if int(result["error"]) != OK:
		_expect(false, "Atomic-write fixture must first load its successful world.")
		return
	var world: World = result["world"]
	world.points_pending += 100
	var temporary := path.get_basename() + ".tmp"
	assert(DirAccess.make_dir_absolute(temporary) == OK)
	_expect(int(_saves.write_slot(1, world)["error"]) != OK
		and FileAccess.get_file_as_bytes(path) == before,
		"A failed temporary write must explicitly fail and preserve the old file byte-for-byte.")
	assert(DirAccess.remove_absolute(temporary) == OK)
	var orphan := ConfigFile.new()
	orphan.set_value("header", "seed", 999)
	assert(orphan.save(temporary) == OK)
	result = _saves.read_slot(1)
	_expect(int(result["error"]) == OK and (result["world"] as World).points_pending < 100,
		"An interrupted temporary save must never replace the last complete world on load.")
	assert(DirAccess.remove_absolute(temporary) == OK)


func _test_transient_sniff_state() -> void:
	var result := _saves.read_slot(1)
	assert(int(result["error"]) == OK)
	var world: World = result["world"]
	world.set_sniff_mode(true)
	var frame := Frame.new()
	frame.sniff_pressed = true
	world.advance(Body.STEP, frame)
	_expect(world.sniffing, "The persistence fixture must save a genuinely active sniff toggle.")
	_expect(int(_saves.write_slot(1, world)["error"]) == OK,
		"Sniffing must not prevent ordinary world autosaving.")
	result = _saves.read_slot(1)
	_expect(int(result["error"]) == OK and not (result["world"] as World).sniffing
		and (result["world"] as World).grid.edits == world.grid.edits
		and (result["world"] as World).inventory == world.inventory,
		"Loading old-format worlds must preserve terrain and materials without latching sniff input.")


func _test_rejected_versions_and_corruption() -> void:
	var config := ConfigFile.new()
	assert(config.load(_saves.slot_path(1)) == OK)
	config.set_value("header", "format_version", Saves.FORMAT_VERSION + 1)
	assert(config.save(_saves.slot_path(2)) == OK)
	var before := FileAccess.get_file_as_bytes(_saves.slot_path(2))
	var result := _saves.read_slot(2)
	_expect(int(result["error"]) != OK and not result.has("world")
		and str(result["message"]).contains("format"),
		"A newer save format must be refused with a reason, never become a fresh world.")
	_expect(FileAccess.get_file_as_bytes(_saves.slot_path(2)) == before,
		"Refusing an unsupported save must leave its original bytes intact.")
	assert(config.load(_saves.slot_path(1)) == OK)
	config.set_value("header", "generator_version", "PK99")
	assert(config.save(_saves.slot_path(3)) == OK)
	result = _saves.read_slot(3)
	_expect(int(result["error"]) != OK and str(result["message"]).contains("generator"),
		"A world must never silently generate unexplored cells with a different version.")
	assert(config.load(_saves.slot_path(1)) == OK)
	var section := ""
	for candidate in config.get_sections():
		if candidate.begins_with("chunk/"):
			section = candidate
			break
	_expect(not section.is_empty(), "The edited fixture must contain a compressed delta.")
	if section.is_empty():
		return
	config.set_value(section, "raw_size", Saves.MAX_DELTA_BYTES + 12)
	assert(config.save(_saves.slot_path(2)) == OK)
	result = _saves.read_slot(2)
	_expect(int(result["error"]) != OK and str(result["message"]).contains("size"),
		"Untrusted delta sizes must be bounded before decompression.")
	var invalid := PackedInt32Array([0, Chunk.CELLS * 3, Blocks.WOOD]).to_byte_array()
	config.set_value(section, "raw_size", invalid.size())
	config.set_value(section, "data", invalid.compress(FileAccess.COMPRESSION_DEFLATE))
	config.set_value(section, "sha256", invalid.hex_encode().sha256_text())
	assert(config.save(_saves.slot_path(2)) == OK)
	result = _saves.read_slot(2)
	_expect(int(result["error"]) != OK and str(result["message"]).contains("run"),
		"A well-compressed but out-of-bounds run must not edit arbitrary cells.")


func _test_bark_state_and_legacy() -> void:
	var original := _saves.read_slot(1)
	assert(int(original["error"]) == OK)
	var world: World = original["world"]
	world.needs.energy = 18.5
	world.needs.rest_ticks = 59
	world.abilities.cooldown_ticks = 37
	assert(int(_saves.write_slot(3, world)["error"]) == OK)
	var result := _saves.read_slot(3)
	_expect(int(result["error"]) == OK, "A world with basic bark state must load.")
	if int(result["error"]) != OK:
		return
	var loaded: World = result["world"]
	_expect(loaded.needs.energy == 18.5 and loaded.needs.rest_ticks == 59
		and loaded.abilities.cooldown_ticks == 37,
		"Energy, partial rest delay and the remaining Ruff cooldown must round-trip exactly.")
	world.advance(Body.STEP, Frame.new())
	loaded.advance(Body.STEP, Frame.new())
	_expect(world.needs.energy == loaded.needs.energy
		and world.needs.rest_ticks == loaded.needs.rest_ticks
		and world.abilities.cooldown_ticks == loaded.abilities.cooldown_ticks,
		"Reloading must not restart rest recovery or bypass a running bark cooldown.")
	world.abilities.cooldown_ticks = 0
	var frame := Frame.new()
	frame.bark = true
	frame.bark_edges.append(true)
	world.advance(Body.STEP * 31.0, frame)
	_expect(world.abilities.charge_level == 2,
		"The save fixture must use a real live Woof charge rather than assigned input state.")
	assert(int(_saves.write_slot(3, world)["error"]) == OK)
	result = _saves.read_slot(3)
	assert(int(result["error"]) == OK)
	loaded = result["world"]
	loaded.advance(Body.STEP * 90.0, Frame.new())
	_expect(loaded.abilities.charge_level == 0 and loaded.abilities.emitted_total == 0,
		"Loading during a charge must not persist held input or emit an unrequested bark.")
	var config := ConfigFile.new()
	assert(config.load(_saves.slot_path(1)) == OK)
	for key in ["energy", "energy_rest_ticks", "bark_cooldown_ticks"]:
		config.erase_section_key("pup", key)
	assert(config.save(_saves.slot_path(3)) == OK)
	result = _saves.read_slot(3)
	_expect(int(result["error"]) == OK, "Pre-bark format-1 worlds must remain readable.")
	if int(result["error"]) != OK:
		return
	loaded = result["world"]
	_expect(loaded.needs.energy == 100.0 and loaded.needs.rest_ticks == 0
		and loaded.abilities.cooldown_ticks == 0 and loaded.grid.edits == world.grid.edits
		and loaded.points_pending == world.points_pending,
		"Missing additive fields must receive explicit legacy defaults without losing world state.")
	assert(int(_saves.write_slot(3, loaded)["error"]) == OK)
	assert(config.load(_saves.slot_path(3)) == OK)
	_expect(config.get_value("pup", "energy") == 100.0
		and config.get_value("future_neighbours", "friendship") == {"rabbit": 2},
		"A legacy world's next autosave must add bark state and retain unknown additive fields.")


func _test_rejected_bark_state() -> void:
	for example: Array in [
		["energy", -1.0], ["energy", 100.1], ["energy", INF], ["energy", "full"],
		["energy_rest_ticks", 61], ["energy_rest_ticks", 1.5],
		["bark_cooldown_ticks", -1], ["bark_cooldown_ticks", 61],
		["bark_cooldown_ticks", true],
	]:
		var config := ConfigFile.new()
		assert(config.load(_saves.slot_path(1)) == OK)
		config.set_value("pup", str(example[0]), example[1])
		assert(config.save(_saves.slot_path(3)) == OK)
		var before := FileAccess.get_file_as_bytes(_saves.slot_path(3))
		var result := _saves.read_slot(3)
		_expect(int(result["error"]) != OK and not result.has("world")
			and FileAccess.get_file_as_bytes(_saves.slot_path(3)) == before,
			"Malformed %s must fail explicitly without replacing the saved world." % str(example[0]))


func _cleanup() -> void:
	for slot in range(1, Saves.SLOT_COUNT + 1):
		var path := _saves.slot_path(slot)
		if FileAccess.file_exists(path):
			assert(DirAccess.remove_absolute(path) == OK)
	assert(DirAccess.remove_absolute(_directory) == OK)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
