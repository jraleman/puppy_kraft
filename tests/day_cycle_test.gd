extends SceneTree

const Cycle = preload("res://games/puppy_kraft/sim/day_cycle.gd")
const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	for pace in 3:
		var clock := Cycle.new()
		clock.set_pace(pace)
		var duration: int = [12, 18, 30][pace] * 60 * 60
		for tick in duration - 1:
			clock.step()
		_expect(clock.day == 1 and clock.is_night(),
			"Every pace must keep the first night until its exact 12/18/30-minute boundary.")
		clock.step()
		_expect(clock.day == 2 and clock.phase_units == 0 and not clock.is_night(),
			"Every pace must wrap once to dawn without drift.")
	var clock := Cycle.new()
	clock.phase_units = Cycle.DUSK_START - 10
	clock.step()
	_expect(clock.phase() == Cycle.Phase.DUSK and clock.caption.contains("head home"),
		"Dusk must start at the designed boundary and produce a readable warning.")
	var state := clock.snapshot()
	clock.set_pace(Cycle.LONG)
	_expect(clock.day == state["day"] and clock.phase_units == state["phase_units"],
		"Live day-length changes must preserve the current day and exact phase.")
	for tick in Cycle.CAPTION_TICKS:
		clock.step()
	_expect(clock.caption.is_empty(), "Dusk feedback must expire on simulation time.")
	clock.phase_units = Cycle.NIGHT_START
	clock.day = 8
	_expect(clock.is_full_moon() and clock.phase_name() == "Full moon"
		and is_equal_approx(clock.daylight(), 0.4),
		"The eighth night must be visibly labelled and brighter, without inventing a howl event.")
	clock.day = 9
	_expect(not clock.is_full_moon() and clock.daylight() < 0.4,
		"Ordinary nights must not inherit the previous full moon.")
	clock.phase_units = 0
	_expect(is_equal_approx(clock.daylight(), 0.4),
		"Dawn must begin at the preceding full moon's brightness without a flash.")
	clock.restore_legacy(Cycle.NORMAL_TICKS * 7 + World.NIGHT_START_TICKS + 123)
	_expect(clock.day == 8 and clock.is_full_moon()
		and clock.phase_units == Cycle.NIGHT_START + 1230,
		"Pre-cycle ticks must restore the exact existing day and phase, not restart time.")
	_test_world_partition()
	if _failures.is_empty():
		print("Puppy Kraft day-cycle tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_world_partition() -> void:
	var fine := World.new(42)
	var coarse := World.new(42)
	for world in [fine, coarse]:
		world.clock.phase_units = Cycle.CYCLE_UNITS - 15
		world.clock.set_pace(Cycle.SHORT)
	for tick in 60:
		fine.advance(Body.STEP, Frame.new())
	coarse.advance(1.0, Frame.new())
	_expect(fine.clock.snapshot() == coarse.clock.snapshot()
		and fine.clock.day == 2 and fine.take_events() == coarse.take_events(),
		"Clock pacing and dawn autosave events must be independent of render-frame partitioning.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
