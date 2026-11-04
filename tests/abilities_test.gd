extends SceneTree

## Dig holds, reversible building, support, reach and the starting-bed interaction.

const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Fixture = preload("res://games/puppy_kraft/tests/world_fixture.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_dig_and_undo()
	_test_dig_reset()
	_test_support_and_reach()
	_test_bed()
	_test_bark_hold()
	_test_bark_taps()
	_test_bark_energy_and_cooldown()
	_test_bark_cancellation()
	_test_bark_leaves()
	if _failures.is_empty():
		print("Puppy Kraft ability tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_dig_and_undo() -> void:
	var world := Fixture.world()
	var frame := Frame.new()
	frame.mouse_aim = true
	frame.mouse_cell = Vector2i(811, 100)
	frame.dig = true
	var before := world.inventory[Blocks.MEADOW_SOIL]
	for tick in Blocks.dig_ticks(Blocks.MEADOW_SOIL) - 1:
		world.advance(Body.STEP, frame)
	_expect(world.grid.get_block(frame.mouse_cell) == Blocks.MEADOW_SOIL,
		"A partial dig hold must not remove or award a block.")
	world.advance(Body.STEP, frame)
	_expect(world.grid.get_block(frame.mouse_cell) == Blocks.AIR
		and world.inventory[Blocks.MEADOW_SOIL] == before + 1 and world.blocks_dug == 1,
		"A completed dig must change the real grid and return exactly one material.")
	frame.dig = false
	frame.place_pressed = true
	world.advance(Body.STEP, frame)
	_expect(world.grid.get_block(frame.mouse_cell) == Blocks.MEADOW_SOIL
		and world.inventory[Blocks.MEADOW_SOIL] == before and world.blocks_placed == 1,
		"Placing a gathered block must be reversible without losing materials.")
	_expect(world.points_pending == 0, "Repeating dirt edits must not invent adventure rewards.")


func _test_dig_reset() -> void:
	var world := Fixture.world()
	var a := Vector2i(811, 99)
	var b := Vector2i(812, 99)
	assert(world.grid.set_block(a, Blocks.STONE) == OK)
	assert(world.grid.set_block(b, Blocks.MEADOW_SOIL) == OK)
	var frame := Frame.new()
	frame.mouse_aim = true
	frame.mouse_cell = a
	frame.dig = true
	for tick in 14:
		world.advance(Body.STEP, frame)
	frame.mouse_cell = b
	world.advance(Body.STEP, frame)
	_expect(world.dig_progress == 1 and world.grid.get_block(b) == Blocks.MEADOW_SOIL,
		"Changing targets must reset the hold, not transfer stone progress to soft soil.")
	frame.dig = false
	world.advance(Body.STEP, frame)
	_expect(world.dig_progress == 0, "Releasing Dig must clear its hold progress.")
	frame.mouse_cell = a
	frame.dig = true
	for tick in Blocks.dig_ticks(Blocks.STONE) - 1:
		world.advance(Body.STEP, frame)
	_expect(world.grid.get_block(a) == Blocks.STONE,
		"Stone must respect its own longer hold time after a cancelled dig.")
	world.advance(Body.STEP, frame)
	_expect(world.grid.get_block(a) == Blocks.AIR and world.inventory[Blocks.STONE] == 1,
		"A full stone hold must award its own drop.")


func _test_support_and_reach() -> void:
	var world := Fixture.world()
	var floating := Vector2i(810, 97)
	_expect(not world.placement_problem(floating, Blocks.WOOD, Chunk.FRONT).is_empty(),
		"Ordinary front blocks must reject unsupported floating placement.")
	_expect(world.placement_problem(floating, Blocks.LADDER, Chunk.FRONT).is_empty(),
		"Ladders must allow the documented support-free exception.")
	var frame := Frame.new()
	frame.mouse_aim = true
	frame.mouse_cell = floating
	frame.place_pressed = true
	world.selected_block = Blocks.LADDER
	world.advance(Body.STEP, frame)
	_expect(world.grid.get_block(floating) == Blocks.LADDER and world.blocks_placed == 1,
		"The support-free rule must work through the real input frame, not just its predicate.")
	_expect(world.placement_problem(Vector2i(810, 99), Blocks.WOOD, Chunk.FRONT)
		.contains("pup"), "Placement must never trap a pup inside its own solid block.")
	_expect(not world.placement_problem(Vector2i(811, 99), Blocks.LADDER, Chunk.BACK).is_empty(),
		"A ladder cannot become a back wall.")
	frame.mouse_cell = Vector2i(810, 100)
	frame.back_wall = true
	world.selected_block = Blocks.WOOD
	world.advance(Body.STEP, frame)
	_expect(world.grid.get_block(frame.mouse_cell, Chunk.BACK) == Blocks.WOOD
		and world.grid.get_block(frame.mouse_cell) == Blocks.MEADOW_SOIL,
		"Back-wall building must attach to front terrain without changing its collision.")
	frame.back_wall = false
	frame.mouse_cell = Vector2i(900, 90)
	var before := world.blocks_placed
	world.advance(Body.STEP, frame)
	_expect(world.blocks_placed == before and world.hint.contains("reach"),
		"Mouse targets beyond three cells must fail with a visible reason.")
	frame.mouse_cell = Vector2i(811, 99)
	world.selected_block = Blocks.STONE
	world.advance(Body.STEP, frame)
	_expect(world.blocks_placed == before and world.hint.contains("No Stone"),
		"An empty material count must fail explicitly, never create a free block.")


func _test_bed() -> void:
	var world := World.new(42)
	var bed := world.grid.generator.layout.bed_cell
	world.body.position = Vector2(bed) + Vector2(0.5, 0.6)
	var frame := Frame.new()
	frame.mouse_aim = true
	frame.mouse_cell = bed
	frame.dig = true
	frame.dig_pressed = true
	world.advance(Body.STEP, frame)
	var events := world.take_events()
	_expect(events.size() == 1 and str(events[0]["type"]) == "nap_requested",
		"Using the actual starting bed must request a nap rather than dig it away.")
	frame.dig_pressed = false
	for tick in 60:
		world.advance(Body.STEP, frame)
	_expect(world.take_events().is_empty() and world.grid.get_block(bed) == Blocks.BED,
		"A held bed interaction must not reopen dialogs or destroy the only prototype home.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _test_bark_hold() -> void:
	for example: Vector2i in [Vector2i(1, 1), Vector2i(29, 1), Vector2i(30, 2),
		Vector2i(71, 2), Vector2i(72, 3)]:
		var world := Fixture.world()
		var barks := _hold_bark(world, example.x)
		_expect(barks.size() == 1 and int(barks[0]["level"]) == example.y,
			"Hold %d ticks must emit exactly one level-%d bark on release." % [
				example.x, example.y])
		var expected_range: float = [4.0, 7.0, 10.0][example.y - 1]
		_expect(barks.size() == 1 and float(barks[0]["range"]) == expected_range
			and is_equal_approx(world.needs.energy, 100.0 - [0, 3, 8][example.y - 1]),
			"A fired bark must carry its real radius and spend its exact energy cost once.")


func _test_bark_taps() -> void:
	for taps in [1, 2]:
		var single := Fixture.world()
		single.set_bark_mode(true)
		var input := Frame.new()
		for tap in taps:
			input.bark_edges.append_array([true, false])
		single.advance(Body.STEP, input)
		single.advance(Body.STEP * 35.0, Frame.new())
		_expect(single.abilities.emitted_total == 1 and single.abilities.last_level == taps,
			"%d taps followed by a quiet window must emit the selected strength." % taps)
	var world := Fixture.world()
	world.set_bark_mode(true)
	var frame := Frame.new()
	frame.bark_edges.assign([true, false, true, false, true, false])
	world.advance(Body.STEP * 0.5, frame)
	frame.bark_edges.clear()
	world.advance(Body.STEP * 0.5, frame)
	_expect(world.abilities.charge_level == 3 and world.abilities.emitted_total == 0,
		"Three rapid taps must retain their order across sub-tick render frames.")
	world.advance(Body.STEP * 34.0, Frame.new())
	_expect(world.abilities.emitted_total == 0,
		"Tap-to-cycle must not fire before the full 0.6-second quiet window.")
	world.advance(Body.STEP, Frame.new())
	_expect(world.abilities.emitted_total == 1 and world.abilities.last_level == 3
		and is_equal_approx(world.needs.energy, 92.0),
		"The quiet window must emit one Ruff, not three Yips or repeated multi-tick barks.")
	world.cancel_actions()
	world.advance(Body.STEP * 60.0, Frame.new())
	frame.bark_edges.assign([true, false, true, false, true, false, true, false])
	world.advance(Body.STEP, frame)
	_expect(world.abilities.charge_level == 1,
		"A fourth tap must visibly cycle back to Yip rather than unlock the unbuilt Howl.")


func _test_bark_energy_and_cooldown() -> void:
	var world := Fixture.world()
	world.needs.energy = 2.0
	_expect(_hold_bark(world, 30).is_empty() and world.abilities.caption.contains("Need 3")
		and is_equal_approx(world.needs.energy, 2.0),
		"Insufficient energy must explicitly refuse a charged bark without spending or downgrading.")
	_expect(_hold_bark(world, 1).size() == 1,
		"Yip must remain usable without charged-bark energy.")
	world.needs.energy = 100.0
	assert(_hold_bark(world, 72).size() == 1)
	var emitted := world.abilities.emitted_total
	_expect(_hold_bark(world, 1).is_empty()
		and world.abilities.emitted_total == emitted
		and world.abilities.caption.contains("cooldown"),
		"Ruff must enforce its one-second cooldown even against an immediate Yip.")
	var cooldown := world.abilities.cooldown_ticks
	world.cancel_actions()
	_expect(world.abilities.cooldown_ticks == cooldown,
		"Opening a menu must cancel input without erasing a gameplay cooldown.")
	world.advance(Body.STEP * cooldown, Frame.new())
	_expect(_hold_bark(world, 1).size() == 1,
		"A fresh press after the cooldown must bark normally.")


func _test_bark_cancellation() -> void:
	var world := Fixture.world()
	var frame := Frame.new()
	frame.bark = true
	frame.bark_edges.append(true)
	world.advance(Body.STEP, frame)
	frame.bark_edges.clear()
	world.advance(Body.STEP * 35.0, frame)
	frame.sniff = true
	world.advance(Body.STEP, frame)
	frame.sniff = false
	frame.bark = false
	frame.bark_edges.append(false)
	world.advance(Body.STEP, frame)
	_expect(world.abilities.emitted_total == 0 and world.needs.energy == 100.0,
		"Sniffing must cancel a held charge so its later release cannot bark or spend energy.")
	frame.sniff = true
	frame.bark = true
	frame.bark_edges.assign([true])
	world.advance(Body.STEP, frame)
	frame.bark_edges.clear()
	world.advance(Body.STEP * 20.0, frame)
	_expect(world.abilities.caption.contains("End sniffing") and world.abilities.emitted_total == 0,
		"A refused bark must keep its reason readable rather than erase it on the next sniff tick.")
	world.set_bark_mode(true)
	frame.bark_edges.assign([true, false])
	world.advance(Body.STEP * 0.5, frame)
	world.cancel_actions()
	world.advance(Body.STEP * 40.0, Frame.new())
	_expect(world.abilities.emitted_total == 0,
		"Menus must clear a queued sub-tick tap as well as an already visible charge.")


func _test_bark_leaves() -> void:
	var world := Fixture.world()
	var open := Vector2i(814, 98)
	var canopy := Vector2i(815, 98)
	var sheltered := Vector2i(807, 99)
	var distant := Vector2i(819, 99)
	var back := Vector2i(813, 98)
	for cell: Vector2i in [open, canopy, sheltered, distant]:
		assert(world.grid.set_block(cell, Blocks.LEAVES) == OK)
	assert(world.grid.set_block(Vector2i(809, 99), Blocks.STONE) == OK)
	assert(world.grid.set_block(back, Blocks.LEAVES, Chunk.BACK) == OK)
	_hold_bark(world, 1)
	_expect(world.grid.get_block(open) == Blocks.LEAVES,
		"A greeting Yip must not collect building leaves.")
	var barks := _hold_bark(world, 30)
	_expect(barks.size() == 1 and int(barks[0]["leaves"]) == 2
		and world.grid.get_block(open) == Blocks.AIR
		and world.grid.get_block(canopy) == Blocks.AIR
		and world.inventory[Blocks.LEAVES] == 2,
		"Woof must gather reachable front foliage without one leaf shielding its canopy.")
	_expect(world.grid.get_block(sheltered) == Blocks.LEAVES
		and world.grid.get_block(distant) == Blocks.LEAVES
		and world.grid.get_block(back, Chunk.BACK) == Blocks.LEAVES
		and world.blocks_dug == 0 and world.points_pending == 0,
		"Barks must respect solid walls, range and back layers without inventing dig points.")
	barks = _hold_bark(world, 72)
	_expect(barks.size() == 1 and int(barks[0]["leaves"]) == 1
		and world.grid.get_block(distant) == Blocks.AIR
		and world.inventory[Blocks.LEAVES] == 3,
		"Ruff's larger real radius must reach leaves that Woof could not collect.")


func _hold_bark(world: World, ticks: int) -> Array[Dictionary]:
	var frame := Frame.new()
	frame.bark = true
	frame.bark_edges.append(true)
	world.advance(Body.STEP, frame)
	frame.bark_edges.clear()
	world.advance(Body.STEP * (ticks - 1), frame)
	frame.bark = false
	frame.bark_edges.append(false)
	world.advance(Body.STEP, frame)
	var result: Array[Dictionary] = []
	for event: Dictionary in world.take_events():
		if str(event["type"]) == "barked":
			result.append(event)
	return result
