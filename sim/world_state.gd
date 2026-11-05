extends RefCounted

## One saved outing. The view can observe events but cannot decide model outcomes.

const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const Scent = preload("res://games/puppy_kraft/sim/scent.gd")
const Needs = preload("res://games/puppy_kraft/sim/needs.gd")
const Abilities = preload("res://games/puppy_kraft/sim/puppy_abilities.gd")
const FetchStick = preload("res://games/puppy_kraft/sim/fetch_stick.gd")
const Cycle = preload("res://games/puppy_kraft/sim/day_cycle.gd")
const Lighting = preload("res://games/puppy_kraft/sim/lighting.gd")
const FirstSteps = preload("res://games/puppy_kraft/sim/first_steps.gd")
const DIRECTIONAL_REACH := 1.5
const MOUSE_REACH := 3.0
const DAY_TICKS := 18 * 60 * 60
const NIGHT_START_TICKS := 12 * 60 * 60

var grid: Grid
var body: Body
var pup_name := "Pup"
var created_unix := 0
var ticks := 0
var points_pending := 0
var blocks_dug := 0
var blocks_placed := 0
var outing_open := true
var inventory := PackedInt32Array()
var selected_block := Blocks.MEADOW_SOIL
var target_cell := Vector2i.ZERO
var target_layer := Chunk.FRONT
var target_in_reach := true
var dig_progress := 0
var hint := ""
var events: Array[Dictionary] = []
var retained_fields: Dictionary[String, Dictionary] = {}
var accumulator := 0.0
var scent := Scent.new()
var sniffing := false
var sniff_toggle := false
var needs := Needs.new()
var abilities := Abilities.new()
var stick: FetchStick
var clock := Cycle.new()
var lighting := Lighting.new()
var first_steps := FirstSteps.new()
var _dig_cell := Vector2i(-1, -1)
var _dig_layer := Chunk.FRONT
var _jump_pending := false
var _dig_pressed_pending := false
var _place_pending := false
var _wheel_pending := 0
var _sniff_pressed_pending := false
var _scent_revision := -1
var _scent_night := false
var _bark_edges_pending: Array[bool] = []
var _carry_pending := false


func _init(seed: int = 0, name: String = "Pup", created: int = 0) -> void:
	grid = Grid.new(seed)
	body = Body.new(grid.generator.layout.spawn_position())
	restore_legacy_stick()
	pup_name = name.strip_edges().substr(0, 32)
	if pup_name.is_empty():
		pup_name = "Pup"
	created_unix = created
	inventory.resize(Blocks.COUNT)
	inventory[Blocks.MEADOW_SOIL] = 12
	inventory[Blocks.WOOD] = 8
	inventory[Blocks.LADDER] = 12
	target_cell = Vector2i(body.position.floor()) + Vector2i.RIGHT


func begin_outing() -> void:
	if not outing_open:
		blocks_dug = 0
		blocks_placed = 0
		accumulator = 0.0
	outing_open = true
	cancel_actions()


func advance(delta: float, frame: Frame) -> void:
	assert(is_finite(delta) and delta >= 0.0, "World time must be finite and nonnegative.")
	_jump_pending = _jump_pending or frame.jump_pressed
	_dig_pressed_pending = _dig_pressed_pending or frame.dig_pressed
	_place_pending = _place_pending or frame.place_pressed
	_bark_edges_pending.append_array(frame.bark_edges)
	_carry_pending = _carry_pending or frame.carry_pressed
	if frame.sniff_pressed:
		_sniff_pressed_pending = not _sniff_pressed_pending
	_wheel_pending += frame.wheel_delta
	accumulator += delta
	var tick_frame := Frame.new()
	tick_frame.move = frame.move
	tick_frame.aim = frame.aim
	tick_frame.dig = frame.dig
	tick_frame.sniff = frame.sniff
	tick_frame.bark = frame.bark
	tick_frame.back_wall = frame.back_wall
	tick_frame.mouse_aim = frame.mouse_aim
	tick_frame.mouse_cell = frame.mouse_cell
	while accumulator + 0.000000001 >= Body.STEP:
		tick_frame.jump_pressed = _jump_pending
		tick_frame.dig_pressed = _dig_pressed_pending
		tick_frame.place_pressed = _place_pending
		tick_frame.sniff_pressed = _sniff_pressed_pending
		tick_frame.bark_edges.assign(_bark_edges_pending)
		tick_frame.carry_pressed = _carry_pending
		_bark_edges_pending.clear()
		tick_frame.wheel_delta = _wheel_pending
		_jump_pending = false
		_dig_pressed_pending = false
		_place_pending = false
		_sniff_pressed_pending = false
		_carry_pending = false
		_wheel_pending = 0
		_step(tick_frame)
		accumulator = maxf(accumulator - Body.STEP, 0.0)
		tick_frame.without_edges()


func cancel_actions() -> void:
	_jump_pending = false
	_dig_pressed_pending = false
	_place_pending = false
	_sniff_pressed_pending = false
	_bark_edges_pending.clear()
	_carry_pending = false
	_wheel_pending = 0
	dig_progress = 0
	_dig_cell = Vector2i(-1, -1)
	sniffing = false
	scent.clear()
	abilities.cancel()
	stick.clear_caption()


func restore_legacy_stick() -> void:
	var at := Vector2(grid.generator.layout.bed_cell) + Vector2(1.5, 1.0 - FetchStick.SIZE.y * 0.5)
	# An old world may have built over the gift's new bedside spot.
	if grid.overlaps_solid(Rect2(at - FetchStick.SIZE * 0.5, FetchStick.SIZE)):
		at = body.position
	stick = FetchStick.new(at)


func set_sniff_mode(toggle: bool) -> void:
	if sniff_toggle != toggle:
		sniff_toggle = toggle
		cancel_actions()


func set_bark_mode(tap: bool) -> void:
	if abilities.tap_mode != tap:
		cancel_actions()
		abilities.set_tap_mode(tap)


func take_events() -> Array[Dictionary]:
	var result := events.duplicate()
	events.clear()
	return result


func day_number() -> int:
	return clock.day


func is_night() -> bool:
	return clock.is_night()


func near_bed() -> bool:
	return body.grounded and body.position.distance_to(
		Vector2(grid.generator.layout.bed_cell) + Vector2(0.5, 0.6)
	) <= 2.0


func dig_fraction() -> float:
	var required := Blocks.dig_ticks(grid.get_block(target_cell, target_layer))
	return clampf(float(dig_progress) / required, 0.0, 1.0) if required > 0 else 0.0


func placement_problem(cell: Vector2i, id: int, layer: int) -> String:
	if layer not in [Chunk.FRONT, Chunk.BACK]:
		return "That block layer is invalid."
	if not grid.contains(cell):
		return "That is outside the world."
	if id not in Blocks.BUILDING_BLOCKS:
		return "That block is not a building material."
	if grid.get_block(cell, layer) != Blocks.AIR:
		return "Dig out that layer first."
	if layer == Chunk.BACK and not Blocks.has_flag(id, Blocks.PLACEABLE_BACK):
		return "That material cannot be a back wall."
	if layer == Chunk.FRONT and body.bounds().intersects(Rect2(Vector2(cell), Vector2.ONE)):
		return "Leave room for the pup."
	if layer == Chunk.FRONT and not stick.carried and Blocks.has_flag(id, Blocks.SOLID) \
		and stick.bounds().intersects(Rect2(Vector2(cell), Vector2.ONE)):
		return "Leave room for the stick."
	if layer == Chunk.FRONT and Blocks.has_flag(id, Blocks.FREE_SUPPORT):
		return ""
	if layer == Chunk.FRONT and grid.get_block(cell, Chunk.BACK) != Blocks.AIR:
		return ""
	if layer == Chunk.BACK and grid.get_block(cell, Chunk.FRONT) != Blocks.AIR:
		return ""
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if grid.solid_at(cell + offset) or grid.get_block(cell + offset, Chunk.BACK) != Blocks.AIR:
			return ""
	return "Needs a neighbouring block or back wall."


func _step(frame: Frame) -> void:
	var old_day := day_number()
	var was_sniffing := sniffing
	ticks += 1
	clock.step()
	if sniff_toggle:
		if frame.sniff_pressed:
			sniffing = not sniffing
	else:
		sniffing = frame.sniff or frame.sniff_pressed
	var previous_x := body.position.x
	body.step(grid, frame, 0.5 if sniffing else 1.0)
	first_steps.walk(absf(body.position.x - previous_x))
	var was_carried := stick.carried
	stick.step(grid, body)
	if frame.carry_pressed:
		var running := not is_zero_approx(frame.move) \
			and body.velocity.x * body.facing >= FetchStick.RUN_THRESHOLD
		var action := stick.interact(grid, body, running)
		if not action.is_empty():
			events.append({"type": action, "position": stick.position, "tick": ticks})
	if frame.wheel_delta != 0:
		var index := Blocks.BUILDING_BLOCKS.find(selected_block)
		index = posmod(index + frame.wheel_delta, Blocks.BUILDING_BLOCKS.size())
		selected_block = Blocks.BUILDING_BLOCKS[index]
	target_layer = Chunk.BACK if frame.back_wall else Chunk.FRONT
	_resolve_target(frame)
	if not target_in_reach:
		dig_progress = 0
		hint = "Out of reach."
	elif frame.place_pressed:
		dig_progress = 0
		_place()
	elif sniffing:
		dig_progress = 0
		_dig_cell = Vector2i(-1, -1)
		hint = "End sniffing to dig, bark or use the bed."
	elif frame.dig or frame.dig_pressed:
		_dig(frame.dig_pressed)
	else:
		dig_progress = 0
		_dig_cell = Vector2i(-1, -1)
		hint = "Use the straw bed to call it a day." if near_bed() else ""
	if sniffing:
		if not was_sniffing or ticks % Scent.REFRESH_TICKS == 0 \
			or grid.revision != _scent_revision or is_night() != _scent_night \
			or was_carried != stick.carried:
			scent.scan(grid, body.position, is_night(), 1.0, stick)
			_scent_revision = grid.revision
			_scent_night = is_night()
		if not scent.trails.is_empty():
			first_steps.achieve(FirstSteps.Step.SNIFF)
	elif was_sniffing:
		scent.clear()
	var barks := abilities.step(frame, needs, not sniffing)
	for bark: Dictionary in barks:
		first_steps.achieve(FirstSteps.Step.BARK)
		bark["position"] = body.position
		bark["tick"] = ticks
		bark["leaves"] = _shake_leaves(float(bark["range"])) if int(bark["level"]) >= 2 else 0
		if int(bark["leaves"]) > 0:
			abilities.caption += " Gathered %d leaf %s." % [
				int(bark["leaves"]), "block" if int(bark["leaves"]) == 1 else "blocks"]
		events.append(bark)
	needs.step(body.grounded and not body.climbing and absf(body.velocity.x) < 0.05
		and is_zero_approx(frame.move) and not frame.dig and not frame.dig_pressed
		and not frame.place_pressed and not sniffing and not frame.bark
		and not frame.carry_pressed
		and frame.bark_edges.is_empty() and abilities.charge_level == 0 and barks.is_empty())
	if day_number() != old_day:
		events.append({"type": "dawn"})


func _resolve_target(frame: Frame) -> void:
	if frame.mouse_aim:
		target_cell = frame.mouse_cell
	else:
		var direction := Vector2(frame.aim)
		if direction == Vector2.ZERO:
			direction = Vector2(body.facing, 0)
		target_cell = Vector2i((body.position + direction.normalized() * 1.15).floor())
	var reach := MOUSE_REACH if frame.mouse_aim else DIRECTIONAL_REACH
	target_in_reach = grid.contains(target_cell) \
		and body.position.distance_to(Vector2(target_cell) + Vector2.ONE * 0.5) <= reach


func _dig(pressed: bool) -> void:
	var id := grid.get_block(target_cell, target_layer)
	if id == Blocks.BED and target_layer == Chunk.FRONT:
		dig_progress = 0
		hint = "A straw bed. Call it a day?"
		if pressed and near_bed():
			events.append({"type": "nap_requested"})
		return
	if stick.carried:
		dig_progress = 0
		hint = "Drop the stick before digging."
		return
	if id == Blocks.AIR or Blocks.has_flag(id, Blocks.UNBREAKABLE):
		dig_progress = 0
		hint = "Nothing to dig here." if id == Blocks.AIR else "The world boundary stays put."
		return
	if target_cell != _dig_cell or target_layer != _dig_layer:
		dig_progress = 0
		_dig_cell = target_cell
		_dig_layer = target_layer
	dig_progress += 1
	hint = "Digging %s / %d of 4" % [
		Blocks.title(id), mini(4, 1 + floori(dig_fraction() * 4.0)),
	]
	if dig_progress < Blocks.dig_ticks(id):
		return
	var error := _collect_block(target_cell, target_layer, id)
	if error != OK:
		hint = "Could not dig: %s." % error_string(error)
		events.append({"type": "error", "message": hint})
		return
	var drop := int(Blocks.DATA[id]["drops"])
	blocks_dug += 1
	first_steps.achieve(FirstSteps.Step.DIG)
	dig_progress = 0
	hint = "Gathered %s." % Blocks.title(drop)
	events.append({"type": "dug", "cell": target_cell, "block": id, "layer": target_layer})


func _collect_block(cell: Vector2i, layer: int, id: int) -> Error:
	var error := grid.set_block(cell, Blocks.AIR, layer)
	if error == OK:
		inventory[int(Blocks.DATA[id]["drops"])] += 1
	return error


func _shake_leaves(radius: float) -> int:
	var gathered := 0
	var first := Vector2i((body.position - Vector2.ONE * radius).floor())
	var last := Vector2i((body.position + Vector2.ONE * radius).floor())
	for row in range(maxi(0, first.y), mini(grid.height - 1, last.y) + 1):
		for column in range(maxi(0, first.x), mini(grid.width - 1, last.x) + 1):
			var cell := Vector2i(column, row)
			if body.position.distance_to(Vector2(cell) + Vector2.ONE * 0.5) > radius \
				or grid.get_block(cell) != Blocks.LEAVES \
				or not grid.clear_line(body.position, Vector2(cell) + Vector2.ONE * 0.5,
					Blocks.LEAVES):
				continue
			var error := _collect_block(cell, Chunk.FRONT, Blocks.LEAVES)
			if error != OK:
				events.append({"type": "error",
					"message": "Could not gather bark-loosened leaves: %s." % error_string(error)})
			else:
				gathered += 1
	return gathered


func _place() -> void:
	if stick.carried:
		hint = "Drop the stick before placing blocks."
		return
	var problem := placement_problem(target_cell, selected_block, target_layer)
	if problem.is_empty() and inventory[selected_block] <= 0:
		problem = "No %s in the building bag. Dig some first." % Blocks.title(selected_block)
	if not problem.is_empty():
		hint = problem
		return
	var error := grid.set_block(target_cell, selected_block, target_layer)
	if error != OK:
		hint = "Could not place: %s." % error_string(error)
		events.append({"type": "error", "message": hint})
		return
	inventory[selected_block] -= 1
	blocks_placed += 1
	hint = "Placed %s." % Blocks.title(selected_block)
	events.append({
		"type": "placed", "cell": target_cell, "block": selected_block, "layer": target_layer,
	})
