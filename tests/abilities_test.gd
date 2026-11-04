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
