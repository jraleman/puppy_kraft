extends SceneTree

## Dig holds, reversible building, support, reach and the starting-bed interaction.

const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Fixture = preload("res://games/puppy_kraft/tests/world_fixture.gd")
const FetchStick = preload("res://games/puppy_kraft/sim/fetch_stick.gd")

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
	_test_carry_and_drop()
	_test_fetch_arcs()
	_test_carry_obstructions()
	_test_carry_cancellation()
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


func _test_carry_and_drop() -> void:
	var fresh := World.new(42)
	_expect(not fresh.stick.carried and fresh.grid.edits.is_empty()
		and fresh.stick.position.distance_to(Vector2(fresh.grid.generator.layout.bed_cell)) < 2.0
		and not fresh.grid.overlaps_solid(fresh.stick.bounds()),
		"A new world must supply one loose bedside stick without editing PK1 terrain.")
	var world := Fixture.world()
	world.stick.position = world.body.position + Vector2(0.8, 0.2)
	var carry := Frame.new()
	carry.carry_pressed = true
	world.advance(Body.STEP * 0.25, carry)
	_expect(not world.stick.carried and carry.carry_pressed,
		"A carry edge must wait for a tick without mutating its caller's frame.")
	world.advance(Body.STEP * 0.75, Frame.new())
	world.advance(Body.STEP * 8.0, Frame.new())
	_expect(world.stick.carried and world.stick.position == world.body.position
		and world.take_events().size() == 1,
		"A buffered press must pick up once and keep the single stick at the mouth.")
	world.advance(Body.STEP, carry)
	_expect(not world.stick.carried and world.stick.velocity == Vector2.ZERO
		and world.stick.caption.contains("Dropped")
		and not world.grid.overlaps_solid(world.stick.bounds()),
		"Carry while stopped must release the stick into free space without throwing it.")
	world.advance(Body.STEP * 8.0, carry)
	_expect(world.stick.carried,
		"A fresh carry edge in a multi-tick advance must pick up once, not repeatedly toggle.")
	var run := Frame.new()
	run.move = 1.0
	world.advance(Body.STEP * 12.0, run)
	world.advance(Body.STEP, carry)
	_expect(not world.stick.carried and world.stick.velocity == Vector2.ZERO,
		"Releasing movement must request a drop even while the puppy is still decelerating.")


func _test_fetch_arcs() -> void:
	for direction in [-1, 1]:
		var world := Fixture.world()
		if direction > 0:
			for row in range(96, 100):
				assert(world.grid.set_block(Vector2i(815, row), Blocks.WOOD, Chunk.BACK) == OK)
		var launch := _throw_stick(world, direction)
		_expect(not world.stick.carried
			and world.stick.velocity == Vector2(direction * FetchStick.THROW_SPEED,
				-FetchStick.THROW_LIFT),
			"Running Carry must launch once in the actual facing direction.")
		world.advance(Body.STEP * 12.0, Frame.new())
		_expect(world.stick.position.y < launch.y - 0.5,
			"A real throw must rise along an arc before gravity brings it down.")
		world.advance(Body.STEP * 180.0, Frame.new())
		_expect((world.stick.position.x - launch.x) * direction > 5.0
			and absf(world.stick.position.y - (100.0 - FetchStick.SIZE.y * 0.5)) < 0.001
			and world.stick.velocity == Vector2.ZERO
			and not world.grid.overlaps_solid(world.stick.bounds()),
			"A stick must pass back walls, land on front terrain and settle without tunnelling.")
	var blocked := Fixture.world()
	for row in range(96, 100):
		assert(blocked.grid.set_block(Vector2i(815, row), Blocks.STONE) == OK)
	_throw_stick(blocked, 1)
	blocked.advance(Body.STEP * 180.0, Frame.new())
	_expect(blocked.stick.position.x <= 815.0 - FetchStick.SIZE.x * 0.5 + 0.001
		and blocked.stick.velocity == Vector2.ZERO,
		"A tall solid wall must stop the actual projectile, not teleport it to the far side.")
	var fine := Fixture.world()
	var coarse := Fixture.world()
	_throw_stick(fine, -1)
	_throw_stick(coarse, -1)
	coarse.advance(Body.STEP * 180.5, Frame.new())
	for frame in 361:
		fine.advance(Body.STEP * 0.5, Frame.new())
	_expect(fine.stick.snapshot() == coarse.stick.snapshot()
		and fine.body.snapshot() == coarse.body.snapshot() and fine.ticks == coarse.ticks,
		"Flight and landing must be independent of render-frame subdivision.")


func _test_carry_obstructions() -> void:
	var world := Fixture.world()
	world.stick.position = world.body.position + Vector2(1.0, -1.0)
	assert(world.grid.set_block(Vector2i(811, 99), Blocks.LEAVES) == OK)
	var carry := Frame.new()
	carry.carry_pressed = true
	world.advance(Body.STEP, carry)
	_expect(not world.stick.carried and world.stick.caption.contains("solid block"),
		"Pickup must respect solid foliage rather than inherit a bark's leaf transparency.")
	assert(world.grid.set_block(Vector2i(811, 99), Blocks.AIR) == OK)
	world.advance(Body.STEP, carry)
	_expect(world.stick.carried, "Removing the obstruction must allow the nearby real pickup.")
	var build := Frame.new()
	build.mouse_aim = true
	build.mouse_cell = Vector2i(811, 100)
	build.dig = true
	world.advance(Body.STEP * 30.0, build)
	_expect(world.blocks_dug == 0 and world.dig_progress == 0 and world.hint.contains("Drop"),
		"Picking up a toy must leave only one mouth item, not dig with a second material or tool.")
	build.dig = false
	build.place_pressed = true
	build.mouse_cell = Vector2i(811, 99)
	var materials := world.inventory.duplicate()
	world.advance(Body.STEP, build)
	_expect(world.blocks_placed == 0 and world.inventory == materials and world.hint.contains("Drop"),
		"Placing while carrying must explain the refusal without spending building materials.")
	world.advance(Body.STEP, carry)
	var cell := Vector2i(world.stick.position.floor())
	_expect(world.placement_problem(cell, Blocks.WOOD, Chunk.FRONT).contains("stick")
		and world.placement_problem(cell, Blocks.WOOD, Chunk.BACK).is_empty()
		and world.placement_problem(cell, Blocks.LADDER, Chunk.FRONT).is_empty(),
		"Solid front placement must not bury a loose stick; non-solid and back layers remain usable.")


func _test_carry_cancellation() -> void:
	var world := Fixture.world()
	world.stick.position = world.body.position + Vector2(0.8, 0.2)
	var carry := Frame.new()
	carry.carry_pressed = true
	world.advance(Body.STEP * 0.5, carry)
	var before := world.stick.snapshot()
	world.cancel_actions()
	_expect(world.stick.snapshot() == before,
		"Opening a menu must not reset or recall the saved loose stick.")
	world.advance(Body.STEP * 0.5, Frame.new())
	_expect(not world.stick.carried, "A menu must cancel an unconsumed sub-tick pickup.")
	world.advance(Body.STEP, carry)
	before = world.stick.snapshot()
	world.cancel_actions()
	_expect(world.stick.snapshot() == before and world.stick.carried,
		"Cancelling input must not drop or duplicate the item already in the puppy's mouth.")


func _throw_stick(world: World, direction: int) -> Vector2:
	world.stick.position = world.body.position + Vector2(direction * 0.8, 0.2)
	var frame := Frame.new()
	frame.carry_pressed = true
	world.advance(Body.STEP, frame)
	frame.carry_pressed = false
	frame.move = direction
	world.advance(Body.STEP * 12.0, frame)
	frame.carry_pressed = true
	world.advance(Body.STEP, frame)
	return world.stick.position
